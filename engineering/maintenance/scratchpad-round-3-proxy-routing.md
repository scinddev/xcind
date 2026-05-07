# Source Review Round 3 Scratchpad: Proxy and Routing

**Status**: Active
**Source of truth**: `engineering/maintenance/source-review-proxy-routing.md`
**Validation requirement**: `make check` for every code change; `make lint` for
doc-only changes.

## Backlog and Groups

### Group 1 — Config serialization (run first; affects all proxy init persistence)

- [x] `PROXY-ROUTING-002`: Proxy init writes unescaped CLI values into sourceable Bash config

### Group 2 — Strict CLI startup (independent of config serialization)

- [x] `PROXY-ROUTING-001`: Explicit `xcind-proxy up` can exit successfully when Traefik fails to start

### Group 3 — Input validation

- [x] `PROXY-ROUTING-003`: Proxy init accepts invalid port and boolean values
- [x] `PROXY-ROUTING-004`: Proxy export ports are not validated before Traefik labels are emitted

### Group 4 — Docs and spec drift (after implementation behavior is settled)

- [x] `PROXY-ROUTING-DOC-001`: Port type metadata spec omits `tls`
- [x] `PROXY-ROUTING-DOC-002`: Proxy init overwrite semantics differ between spec and implementation
- [x] `PROXY-ROUTING-DOC-003`: Generated override example is stale for default TLS behavior
- [x] `PROXY-ROUTING-DOC-004`: Proxy infrastructure appendices show stale paths and TLS snippets
- [x] `PROXY-ROUTING-DOC-005`: Traefik label behavior still assigns app labels to proxy hook
- [x] `PROXY-ROUTING-DOC-006`: Hostname behavior still assigns workspace labels to proxy hook
- [x] `PROXY-ROUTING-DOC-007`: Apex behavior expects HTTP preferred URL despite TLS auto default
- [x] `PROXY-ROUTING-DOC-008`: Architecture overview overstates proxy hook ownership

## Coordination Rules

- Write scope per group: Group 1 touches `lib/xcind/xcind-proxy-lib.bash` and
  `test/test-xcind-proxy.sh`. Group 2 touches `bin/xcind-proxy` and
  `test/test-xcind-proxy.sh`. Group 3 touches both and `test/test-xcind-proxy.sh`.
- Group 4 is docs-only; coordinate only to avoid conflicting edits to the
  same document from multiple passes.
- Update `source-review-proxy-routing.md` with resolution notes and validation
  results before marking a checkbox above.

## Progress Log

- Round started. Plan updated to mark Round 2 complete. Groups and todos created.
- Group 1 (`PROXY-ROUTING-002`): `__xcind-proxy-quote-value` helper + atomic write. Tests added. `make check` passed.
- Group 2 (`PROXY-ROUTING-001`): strict mode parameter in `__xcind-proxy-ensure-running`; `xcind-proxy up` passes `strict`. Tests added. `make check` passed.
- Group 3 (`PROXY-ROUTING-003`, `PROXY-ROUTING-004`): port + boolean validation in `bin/xcind-proxy`; port validation in proxy hook with protocol-suffix stripping. Tests added. `make check` passed (598).
- Group 4 (all `PROXY-ROUTING-DOC-*`): all 8 doc drift items resolved. `make check` passed.
- All 12 items closed in `source-review-proxy-routing.md`. Ready for branch + PR.
