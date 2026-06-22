# ADR-0016: Proxy Domain Must Be Multi-Label; Default `localhost.scind.io`

**Status**: Accepted

## Context

[ADR-0009](0009-flexible-tls-configuration.md) established that `auto` mode
provisions a wildcard certificate covering `*.${XCIND_PROXY_DOMAIN}` plus the
bare domain, "so TLS Just Works for every generated hostname." In practice it
does not Just Work everywhere, because of a wildcard-matching rule ADR-0009 did
not account for.

The default proxy domain is `localhost` — `__xcind-proxy-write-config` and
`__xcind-proxy-ensure-certs` both fall back to
`${XCIND_PROXY_DOMAIN:-localhost}` (`lib/xcind/xcind-proxy-lib.bash:68,279`),
and the generated cert's SAN is `DNS:*.${domain},DNS:${domain}`
(`:367`). With the default domain, that is `*.localhost`.

**The symptom.** `curl https://proxenos.localhost` on macOS fails with:

```
subjectAltName does not match host name proxenos.localhost
SSL: no alternative certificate subject name matches target host name 'proxenos.localhost'
```

The served cert *does* contain `SAN: DNS:*.localhost, DNS:localhost` — the SAN
is present; the matcher rejects the wildcard.

**Root cause (verified empirically).** A wildcard `*.X` is only honored by
RFC 6125-strict TLS implementations when `X` contains at least one dot — i.e.
the wildcard sits under **two or more** labels. `localhost` is a single label,
so `*.localhost` is rejected by strict matchers but accepted by lenient ones,
which masked the bug:

- OpenSSL-based curl: `*.localhost` **matches** `proxenos.localhost` (lenient).
- LibreSSL (macOS system curl), Apple Secure Transport (Safari), Go
  `crypto/tls`: `*.localhost` is **rejected** (strict) — the failing case.
- `*.localhost.scind.io` (≥2-label base) **matches** `proxenos.localhost.scind.io`
  on every stack.
- Wildcards match exactly **one label deep**: `*.localhost.scind.io` does **not**
  cover `a.b.localhost.scind.io`.

This is independent of *trust*. Trust (a self-signed cert the OS does not trust)
is fixed by `mkcert` (`:345`) or by manually trusting the generated cert.
Wildcard validity is a separate problem: `mkcert` would still mint `*.localhost`,
so it does **not** fix the single-label rejection. Both must be addressed; this
ADR is about wildcard validity and the default domain.

A multi-label proxy domain has a consequence ADR-0009 did not face: `.localhost`
resolves to loopback for free (RFC 6761), but a public domain does not — DNS
resolution becomes the operator's responsibility (a wildcard `A`/`AAAA` record to
loopback, `dnsmasq`, or `/etc/hosts`). The domain to use therefore had to be
chosen, not just constrained.

## Decision

**1. The proxy domain must contain at least one dot (≥2 labels).** A
single-label proxy domain (e.g. `localhost`) yields a `*.singlelabel` wildcard
that strict TLS stacks refuse to match even though the SAN is present. This is a
documented constraint of `XCIND_PROXY_DOMAIN` and the basis for an advisory
startup warning (single-label domain under a non-`disabled` TLS mode → warn,
do not fail).

**2. The default `XCIND_PROXY_DOMAIN` changes from `localhost` to
`localhost.scind.io`.** `scind.io` is registered; `localhost.scind.io` is a
dedicated loopback subdomain with wildcard `*.localhost.scind.io`, published as:

```
localhost.scind.io.      A      127.0.0.1
localhost.scind.io.      AAAA   ::1
*.localhost.scind.io.    A      127.0.0.1
*.localhost.scind.io.    AAAA   ::1
```

The non-wildcard `localhost.scind.io` record is kept because a `*.X` wildcard
never covers the bare `X`; the cert SAN includes both. `AAAA ::1` is included
because IPv6-preferring clients (macOS) resolve `::1` first.

`.io` is not HSTS-preloaded, so `--tls-mode disabled` keeps working in browsers
(unlike `.dev`/`.app`). `localhost` remains fully supported and is documented as
the offline/private, browser-only, single-label-limited alternative.

*This ADR records the decision; the code change (the default in
`__xcind-proxy-write-config`, the `xcind-proxy init` help, completions, the
`(.localhost = zero DNS config, RFC 6761)` comment at `:81`, and the affected
tests) lands as follow-up implementation.*

**3. A dedicated subdomain, not the apex.** The loopback zone is
`localhost.scind.io`, deliberately **not** `scind.io` itself.

## Consequences

### Positive

- TLS Just Works on strict stacks (macOS curl/Safari, Go) as ADR-0009 intended,
  not only on lenient ones (OpenSSL, Chrome).
- The locally-trusted cert is scoped to `*.localhost.scind.io` and cannot
  impersonate anything in the real `scind.io` namespace.
- Scoping to a subdomain keeps the apex and the rest of the zone free (project
  site, email with normal implicit-MX), and contains the wildcard to a
  loopback-only zone instead of making it greedy over all of `scind.io`.
- `localhost` stays available for anyone who wants fully on-machine resolution.

### Negative

- A public loopback domain shifts DNS resolution onto the operator
  (wildcard record / `dnsmasq` / `/etc/hosts`), and networks with DNS-rebinding
  protection may refuse loopback answers for public names — a fallback to
  `/etc/hosts` or `dnsmasq` is then required.
- Privacy trade-off vs native `.localhost`: the first lookup of a never-cached
  hostname (e.g. `secret-project.localhost.scind.io`) reaches public recursive
  resolvers and the `scind.io` authoritative NS, so internal hostnames can
  surface in resolver/NS logs. `.localhost` leaks nothing off-machine.
- `scind.io` registration + NS become infrastructure to monitor (auto-renew).
  `.io`'s long-term ccTLD status has been under discussion (Chagos sovereignty);
  low near-term risk, noted because this underpins team-wide local dev.
- Changing a default is mildly disruptive for users who relied on the implicit
  `localhost`; mitigated by `localhost` remaining a supported value.

### Neutral

- Trust setup is orthogonal and unchanged: `mkcert -install` (or manual OS
  trust) is still required for a green padlock; this ADR does not alter the
  `auto`/`custom`/`disabled` mode design from ADR-0009.

## Rejected Alternatives

- **Point the apex at loopback** (`scind.io A 127.0.0.1` + `*.scind.io`). Works
  for cert matching but burns the apex (no project site; email needs explicit
  `MX`), makes the wildcard greedy over the entire `scind.io` zone (every real
  subdomain must be carved out or silently resolves to loopback), and forces a
  production-scope trusted cert (`*.scind.io`) onto every developer's machine —
  a leaked CA could then impersonate `api.scind.io`. Rejected for the
  dedicated-subdomain approach in Decision 3.
- **Ship a fixed cert + key with xcind.** Rejected: distributing a private key
  publicly is a security non-starter.
- **Rely on `.localhost` and document the limitation only.** Rejected as the
  *default*: it leaves the out-of-the-box experience broken on macOS/Safari/Go.
  `.localhost` is retained as an explicit opt-in alternative, not the default.
- **Fix trust with `mkcert` alone.** Rejected as a fix for *this* problem:
  `mkcert` addresses trust, not wildcard validity — it would still mint
  `*.localhost`.

## Related Documents

- [ADR-0009: Flexible TLS Configuration](0009-flexible-tls-configuration.md) -
  establishes the `auto`/`custom`/`disabled` modes and wildcard provisioning
  this ADR constrains and re-defaults.
- [ADR-0008: Traefik for Reverse Proxy](0008-traefik-reverse-proxy.md) - Traefik
  performs TLS termination.
