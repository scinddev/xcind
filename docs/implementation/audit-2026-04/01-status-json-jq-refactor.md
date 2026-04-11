# 01 — Convert `xcind-proxy status --json` to `jq -n`

**Scope:** Small (one function, ~40 lines changed)
**Risk:** Low
**Depends on:** nothing
**Blocks:** nothing
**Conflicts with:** #05 (both touch `bin/xcind-proxy`; do one at a time)

---

## Problem

`bin/xcind-proxy` emits the JSON body of `xcind-proxy status --json` with a
hand-rolled `printf` template that interpolates user-controlled and
operationally-sourced values directly into a JSON string. Any value
containing `"`, `\`, or a newline will produce invalid JSON. The same
function already uses `jq -n` for the assigned-ports array, so the fix is to
extend that pattern to the top-level object.

The deep Bash audit flagged this as the single most likely-to-misbehave
path in the whole project. It hasn't bitten yet only because the current
default values (`traefik:v3`, `localhost`, etc.) don't contain any
problematic characters.

## Evidence

**`bin/xcind-proxy:207-208`** — the problematic block:

```bash
if [ "$json_mode" = true ]; then
  local assigned_json
  assigned_json=$(__xcind-proxy-status-assigned-json)
  printf '{"initialized":true,"status":"%s","config":"%s","image":"%s","http_port":%s,"dashboard_enabled":%s,"dashboard_url":"%s","network_name":"%s","network_exists":%s,"assigned_ports":%s}\n' \
    "$running_status" "$config_status" "$image" "$http_port" "$dashboard_enabled" "$dashboard_url" "$network_name" "$network_exists" "$assigned_json"
```

Concrete failure cases:

1. **User-controlled `XCIND_PROXY_IMAGE`** — a user could set
   `XCIND_PROXY_IMAGE="traefik:\"v3\""` in `~/.config/xcind/proxy/config.sh`
   (contrived but legal) and break every subsequent `status --json` call.
2. **Boolean-as-string drift** — `dashboard_enabled` is the literal shell
   string `"true"` or `"false"`, not a JSON boolean. Passing those through
   `%s` into a position the schema advertises as a boolean works today
   because bash happens to hold `true`/`false` as-is. If anyone renames the
   value (`yes`/`no`, `1`/`0`), the output becomes `"dashboard_enabled":yes`
   — invalid JSON.
3. **No escaping of `network_name`** — if a future release reads this from
   an environment variable or a config field, the same problem surfaces.

## Precedent in the same file

`__xcind-proxy-status-assigned-json` at `bin/xcind-proxy:251-275` already
demonstrates the right pattern:

```bash
json=$(printf '%s' "$json" | jq \
  --argjson port "$L_port" \
  --arg app "$L_app" \
  ...
  '. + [{host_port: $port, app: $app, ...}]')
```

This package extends that pattern to the outer object.

## Proposed fix

Replace the `printf` with a `jq -n` call. All current fields become typed
(`--arg` for strings, `--argjson` for booleans and numbers), and
`assigned_json` (already a JSON array) is injected via `--argjson`.

```bash
if [ "$json_mode" = true ]; then
  local assigned_json
  assigned_json=$(__xcind-proxy-status-assigned-json)
  jq -n \
    --arg status "$running_status" \
    --arg config "$config_status" \
    --arg image "$image" \
    --argjson http_port "$http_port" \
    --argjson dashboard_enabled "$dashboard_enabled" \
    --arg dashboard_url "$dashboard_url" \
    --arg network_name "$network_name" \
    --argjson network_exists "$network_exists" \
    --argjson assigned_ports "$assigned_json" \
    '{
      initialized: true,
      status: $status,
      config: $config,
      image: $image,
      http_port: $http_port,
      dashboard_enabled: $dashboard_enabled,
      dashboard_url: $dashboard_url,
      network_name: $network_name,
      network_exists: $network_exists,
      assigned_ports: $assigned_ports
    }'
```

Also convert the `not_initialized` branch at `bin/xcind-proxy:161-162` for
consistency even though it's a constant:

```bash
if [ "$json_mode" = true ]; then
  jq -n '{initialized: false, status: "not_initialized", assigned_ports: []}'
```

## Things to watch for

1. **`jq` is optional, not required.** The function already requires `jq`
   when emitting JSON (the assigned-ports subroutine `echo "[]"`s and
   returns when `jq` is absent). The outer `jq -n` needs the same guard:
   if `jq` is missing, fall back to a minimal hand-rolled JSON or exit
   with a clear error.

   Recommended: if `jq` is missing AND `--json` was requested, fail loudly:

   ```bash
   if [ "$json_mode" = true ] && ! command -v jq >/dev/null 2>&1; then
     echo "Error: jq is required for --json output." >&2
     exit 1
   fi
   ```

   Add this at the top of `__xcind-proxy-status` (after `--json` flag
   parsing). `bin/xcind-workspace:258` already has exactly this check —
   copy that pattern.

2. **Trailing newline.** `jq -n` emits a trailing newline by default, which
   matches the current `printf '…\n'` behavior. No `-c` flag needed; the
   pretty-printed output is fine and more debuggable.

3. **`http_port` is currently interpolated as a number.** Confirm
   `XCIND_PROXY_HTTP_PORT` is always numeric before using `--argjson`. The
   init flow validates it implicitly via compose consumption, but a manually
   edited `config.sh` could set it to non-numeric. If that's a concern, use
   `--arg` instead and emit it as a string, or add an integer validation
   upstream.

## Acceptance criteria

- [ ] `bin/xcind-proxy status --json` produces valid JSON when
  `XCIND_PROXY_IMAGE='img:"weird"value'` is set in `config.sh`.
- [ ] New test in `test/test-xcind-proxy.sh` that sets a weird image name
  and pipes the output through `jq .` — should exit 0.
- [ ] Existing proxy status tests still pass unchanged.
- [ ] `--json` with `jq` missing returns a clear error (exit 1) instead of
  producing broken output.
- [ ] `make check` passes.

## Suggested new test

Add to `test/test-xcind-proxy.sh` in the status test section:

```bash
# ======================================================================
echo ""
echo "=== Test: xcind-proxy status --json with unusual image name ==="

# Set an image name that would break a hand-rolled printf template
printf 'XCIND_PROXY_IMAGE='\''my-registry/traefik:"tag with quote"'\''\n' \
  >"$XCIND_PROXY_CONFIG_DIR/config.sh"

json_out=$("$XCIND_ROOT/bin/xcind-proxy" status --json 2>/dev/null)

# Parse it — if the JSON is broken, jq exits non-zero and we fail
if printf '%s' "$json_out" | jq -e . >/dev/null 2>&1; then
  assert_eq "status --json parses as valid JSON" "0" "0"
else
  assert_eq "status --json parses as valid JSON" "0" "1"
fi

# Confirm the image field round-trips correctly
echoed=$(printf '%s' "$json_out" | jq -r '.image')
assert_eq "image field round-trips through JSON" \
  'my-registry/traefik:"tag with quote"' "$echoed"
```

Make sure the test block runs *inside* a mock HOME section so it doesn't
clobber real state — copy the surrounding pattern.

## Risk / rollback

- **Risk:** low. The change is scoped to one function, the new pattern is
  already used elsewhere in the same file, and the test suite exercises
  status --json.
- **Rollback:** `git revert` the commit; the hand-rolled printf is not
  referenced elsewhere.

## Scope estimate

~30 minutes of focused work:
- 10 minutes: write the `jq -n` replacement and confirm it runs
- 10 minutes: add the new test
- 10 minutes: run `make check`, adjust, commit

## Out of scope

- Do not rewrite `__xcind-proxy-status-assigned-json` — it's already correct.
- Do not refactor the *text* output path; only `--json` has the bug.
- Do not extract a shared "JSON builder" helper. One file, one function, no
  cross-cutting abstraction needed.
