# Local HTTPS: certificates, trust, and domains

Xcind's Traefik proxy terminates TLS, so your apps are reachable at
`https://myapp.localhost.scind.io` without you running a CA by hand. For the
browser padlock to be green (and for `curl` to validate), **two** independent
things must hold:

1. The served certificate must be **trusted** by whatever client is validating.
2. The proxy domain must yield a **valid wildcard** — it must contain at least
   one dot.

This guide covers both, plus custom domains, bring-your-own certificates, and
the errors you'll hit when one of the two is missing.

> Background and rationale:
> [ADR-0016](../../engineering/decisions/0016-proxy-domain-wildcard-constraint.md)
> (domain constraint + default) and
> [ADR-0009](../../engineering/decisions/0009-flexible-tls-configuration.md)
> (TLS modes).

## How xcind provisions the certificate

TLS behavior is set by `XCIND_PROXY_TLS_MODE` in `~/.config/xcind/proxy/config.sh`:

| Mode | Behavior |
|------|----------|
| `auto` (default) | Provision a wildcard cert automatically (mkcert if available, else self-signed via openssl). |
| `custom` | Use your own cert/key (`XCIND_PROXY_TLS_CERT_FILE` / `XCIND_PROXY_TLS_KEY_FILE`). |
| `disabled` | HTTP only — no `:443`, no certs. |

In `auto` mode, `xcind-proxy up` resolves the certificate in this order:

1. **User-provided** wildcard at `~/.config/xcind/proxy/certs/wildcard.{crt,key}`
   — always wins; copied into the state cert when newer.
2. **Cached** state cert for the current domain (the fast path).
3. **mkcert**, if on `PATH` → a locally-trusted wildcard.
4. **openssl**, if on `PATH` → a self-signed wildcard (untrusted until you trust
   it — see below).
5. Otherwise, an error with installation guidance.

The generated cert lands at `~/.local/state/xcind/proxy/certs/wildcard.{crt,key}`,
alongside a `domain` marker. The SAN covers both `*.{domain}` and the bare
`{domain}`. If you change `XCIND_PROXY_DOMAIN`, the cert is regenerated on the
next `xcind-proxy up`.

## The proxy domain must contain a dot

A wildcard `*.X` is only honored by RFC 6125-**strict** TLS stacks when `X`
contains at least one dot — i.e. the wildcard sits under **two or more** labels.

- `localhost` is a single label, so `*.localhost` is **rejected** by strict
  clients: macOS system `curl` (LibreSSL), Safari (Secure Transport), and Go
  (`crypto/tls`). It is *accepted* by OpenSSL-based curl and Chrome/BoringSSL,
  which is why this bug hides easily.
- `localhost.scind.io` has two labels, so `*.localhost.scind.io` is valid
  **everywhere**. This is why it is the default `XCIND_PROXY_DOMAIN`.

Wildcards match exactly **one label deep**: `*.localhost.scind.io` covers
`api.localhost.scind.io` but **not** `a.b.localhost.scind.io`.

`localhost.scind.io` resolves to loopback (`127.0.0.1` / `::1`) via public DNS,
so no `/etc/hosts` entry is needed for the default domain.

## Trust the certificate

A self-signed cert (the openssl fallback) is valid but **not trusted** by your
OS until you say so. Trust it in the store used by **whatever client validates
TLS** — that is the most common point of confusion (the browser on your host and
`curl` inside WSL use different stores).

### Easiest: mkcert

Install [mkcert](https://github.com/FiloSottile/mkcert) and run its one-time
setup; xcind's `auto` mode then mints a cert mkcert's local CA already trusts:

```bash
mkcert -install        # once — installs mkcert's CA into your OS trust store
xcind-proxy up --force # re-mint + reload with the now-trusted cert
```

mkcert fixes **trust**. It does **not** change the domain rule — a single-label
domain still produces an untrusted-by-strict-matchers `*.localhost`.

Firefox uses its **own** trust store; mkcert needs `nss` (`certutil`) installed
to register its CA there.

### Manual trust, per OS

Point these at the generated cert: `~/.local/state/xcind/proxy/certs/wildcard.crt`.

- **macOS:**
  ```bash
  sudo security add-trusted-cert -d -r trustRoot \
    -k /Library/Keychains/System.keychain \
    ~/.local/state/xcind/proxy/certs/wildcard.crt
  ```
  A user-added trust anchor is exempt from the 398-day cert-lifetime limit.
- **Windows** (host browsers for WSL2 setups): import into the **Trusted Root**
  store via `Import-Certificate` or `certmgr` (the host is what validates TLS for
  a host-side browser).
- **Linux / WSL:** copy the cert into the CA store and refresh:
  ```bash
  sudo cp ~/.local/state/xcind/proxy/certs/wildcard.crt \
    /usr/local/share/ca-certificates/xcind-wildcard.crt
  sudo update-ca-certificates
  ```
  (covers `curl` and CLI tools inside WSL).
- **Firefox** (any OS): import the cert manually, or use `nss`/`certutil` — it
  ignores the OS store.

## Use a custom proxy domain

Set a different domain in `~/.config/xcind/proxy/config.sh` (or via
`xcind-proxy init --proxy-domain …`). Any domain **other than `.localhost`** is
a real, public name — so **DNS resolution becomes your responsibility**. In
preference order:

1. **Public wildcard record** — `*.{domain}` and `{domain}` → `127.0.0.1` /
   `::1` (the "works for everyone, everywhere" option, like `localtest.me`). This
   is how `localhost.scind.io` is published:
   ```
   localhost.scind.io.      A      127.0.0.1
   localhost.scind.io.      AAAA   ::1
   *.localhost.scind.io.    A      127.0.0.1
   *.localhost.scind.io.    AAAA   ::1
   ```
   Keep the non-wildcard record too — a `*.X` wildcard never covers the bare `X`.
   Include `AAAA ::1` so IPv6-preferring clients (macOS) resolve loopback.
2. **Local `dnsmasq`** mapping `*.{domain}` → loopback.
3. **Per-host `/etc/hosts`** entries (works, but you lose wildcard convenience —
   one line per hostname).

**DNS-rebinding caveat:** some resolvers and home routers refuse to return
loopback/private answers for public names (rebinding protection), which breaks
option 1 on those networks. `/etc/hosts` or `dnsmasq` is the fallback.

**Privacy trade-off.** With a public loopback domain, the first lookup of a
never-cached hostname (e.g. `secret-project.localhost.scind.io`) reaches public
recursive resolvers and the domain's authoritative nameservers, so internal
hostnames can surface in resolver/NS logs. Native `.localhost` resolves entirely
on-machine and leaks nothing — at the cost of being single-label (browser-only,
strict-stack-incompatible). Use `.localhost` if you need fully offline,
on-machine resolution and only browse from Chrome.

## Bring your own certificate

For an enterprise CA or a cert you mint yourself, switch to `custom` mode:

```bash
xcind-proxy init \
  --tls-mode custom \
  --tls-cert-file /abs/path/to/cert.pem \
  --tls-key-file  /abs/path/to/key.pem
xcind-proxy up --force
```

To generate one yourself with a portable, **LibreSSL-safe** config (macOS
`openssl` is LibreSSL, so avoid `-addext`):

```ini
# proxy-domain.cnf
[req]
distinguished_name = dn
x509_extensions    = v3
prompt             = no
[dn]
CN = localhost.scind.io
O  = xcind
[v3]
subjectAltName   = @san
basicConstraints = critical, CA:FALSE
keyUsage         = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
[san]
DNS.1 = localhost.scind.io
DNS.2 = *.localhost.scind.io
```

```bash
openssl req -x509 -newkey rsa:2048 -sha256 -days 825 -nodes \
  -keyout localhost.scind.io-key.pem -out localhost.scind.io-cert.pem \
  -config proxy-domain.cnf -extensions v3
```

You still need to **trust** the resulting cert (see above) unless it chains to a
CA your machines already trust.

## Troubleshooting

**`curl` fails with a SAN mismatch:**

```
subjectAltName does not match host name proxenos.localhost
SSL: no alternative certificate subject name matches target host name 'proxenos.localhost'
```

The cert *is* served and the SAN *is* present — a strict matcher is rejecting a
**single-label wildcard** (`*.localhost`). Fix: use a proxy domain with at least
one dot (the default `localhost.scind.io`, or your own ≥2-label domain), then
`xcind-proxy up --force`.

**Browser/curl warns the certificate is not trusted:** the cert is valid but
**untrusted**. Trust it in the failing client's store (see
[Trust the certificate](#trust-the-certificate)), or install `mkcert` and
`mkcert -install`. Remember browser-on-host vs `curl`-in-WSL use different
stores.

**A nested hostname (`a.b.{domain}`) fails:** wildcards are one label deep. Flatten
the hostname, or add a dedicated cert/SAN for the deeper name.

## Where to go next

- [Set up the Traefik proxy](./proxy-setup.md) — exports, ports, day-to-day commands.
- [Configuration reference](../reference/configuration.md) — `XCIND_PROXY_DOMAIN`
  and the TLS variables.
- [`engineering/specs/proxy-infrastructure.md`](../../engineering/specs/proxy-infrastructure.md)
  — full behavior spec.
