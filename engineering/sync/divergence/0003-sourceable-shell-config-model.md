# Divergence 0003: Sourceable-shell config model

**Status**: Active
**Scind canon**: `docs/reference/configuration.md`, `docs/specs/configuration-schemas.md` (typed YAML; explicitly rejects env-var config)
**Xcind reality**: `.xcind.sh` sourced by the shell + `XCIND_*` env vars (arrays and scalars); `lib/xcind/xcind-config-lib.bash`
**Category**: Structural
**Origin**: P3 L-0023

## What differs
Scind expresses configuration as **typed, parsed, validated YAML** (`workspace.yaml`
/ `application.yaml`) and explicitly rejects environment-variable configuration.
Xcind makes `.xcind.sh` a **sourceable Bash file** and expresses most configuration
as `XCIND_*` environment variables (arrays and scalars).

## Why Xcind diverges
Bash has no typed-config story. A sourceable script is the idiomatic, dependency-
free way to configure a shell tool: no parser to write, arrays and command
substitution come for free, and it loads with a single `source`. The language
forced it.

## Why Scind should NOT simply adopt Xcind's approach
Scind targets a compiled language where a parsed, validated config object (Viper) is
strictly better than "eval a shell script." Adopting Xcind's model would make Scind
*worse*: it would give up schema validation, invite arbitrary code execution at
config-load time, and reintroduce the escaping/injection surface Xcind itself files
as divergence 0005. Scind already rejects env-var config on principle. This is the
canonical **implementation-shape** divergence (global-context §2a, Example A): it
changes *how config is expressed*, not *what the config system must guarantee*.

## Canon-change test (required)
**Strongest canon-change argument:** "A sourceable file is more flexible than static
YAML — Scind should allow it." **Why rejected:** flexibility here is *arbitrary
shell execution*, which is a security and validation liability, not a feature, for a
compiled tool. Scind's typed YAML is a deliberate, safer design choice, not an
oversight Xcind corrected. Matches global-context §2a Example A exactly — Structural,
low-risk, admitted on this justification, no adversarial re-check required.

## Revisit conditions
None foreseeable — this is a direct consequence of Bash vs Go (see 0001). Would only
reopen if Scind abandoned typed config entirely (it will not).

## Links
- Origin finding: P3 L-0023
- Related ADR(s): Xcind ADR-0006 (three configuration schemas — Bash-level);
  Scind ADR-0006 (three configuration schemas — YAML)
- Correspondence-map row(s): `reference/configuration.md` (PARTIAL),
  `specs/configuration-schemas.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off L-0023. Parent of 0004, 0005 (both ride
  on this config model).
