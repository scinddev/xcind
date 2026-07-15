# Divergence 0001: Bash vs Go tech stack

**Status**: Active
**Scind canon**: `docs/implementation/*` (Go Technology Stack, `cli-scaffolding.md`, `project-layout.md`, 16 `scaffold-*.go` appendices, `goreleaser.yaml`, Go `makefile`)
**Xcind reality**: `bin/xcind-*` + `lib/xcind/*.bash` (Bash 3.2+, yq/jq/sha256sum, npm/Nix packaging); `engineering/implementation/tech-stack.md`, `project-layout.md`
**Category**: Structural
**Origin**: pre-existing (global-context §5; correspondence-map §3 Q6 — "Scind commits to Go, unambiguously")

## What differs
Scind's entire `implementation/` layer targets **Go** — `tech-stack.md` is titled
"Go Technology Stack" and pins a real `go.mod` (`go 1.23`, Cobra/Viper/Afero/Sprig/
validator/docker SDK/testify); `cli-scaffolding.md` instructs `go mod init`; the
16 `scaffold-*.go` appendices are real Go source. Xcind is a **Bash** proof-of-
concept: three-plus `bin/` entrypoints and `lib/xcind/*.bash`, shelling out to
`yq`/`jq`, packaged via npm and Nix. This is the single largest structural
difference between the two projects and spans the whole implementation layer
(tech-stack, project layout, CLI scaffolding, build/release tooling, language
idioms, packaging).

## Why Xcind diverges
Xcind exists to *prototype* the Scind proposal quickly and dependency-free. Bash
was the fastest way to prove the design end-to-end on a developer workstation
without a build toolchain. Xcind is the prototype; it will not be rewritten in Go.

## Why Scind should NOT simply adopt Xcind's approach
Scind is the design that will be "built for real" and has committed to Go for
static-binary distribution, typed/validated config (Viper), a real filesystem
abstraction (Afero), and a testable command tree (Cobra). Adopting Bash would
throw away every one of those guarantees — typed config, single-binary shipping,
cross-platform robustness — and reintroduce the shell-isms (eval-able config,
runtime-dependency probing, escaping surfaces) that Xcind itself files as
divergences 0005/0008/0012. Bash is strictly worse for Scind's target.

## Canon-change test (required)
**Strongest canon-change argument:** "Xcind proved Bash is sufficient, so Scind is
over-engineering with Go." **Why rejected:** Xcind's Bash implementation repeatedly
*hit the walls* that motivate Go — no typed config (→ 0003/0007), a shell-injection
surface (→ 0005), runtime-dependency fragility (→ 0008), and no clean way to ship a
single binary. These are limitations Xcind works around, not evidence the design
should abandon Go. The language boundary is expected divergence, **not drift**
(global-context §5): design decisions, specs, naming, behaviors, and product
framing transfer across it; language/build/packaging do not. Low-risk Structural
entry — admitted on this one-line justification, no adversarial pass required.

## Revisit conditions
Effectively never. Would only reopen if Scind itself pivoted away from a Go target,
or if Xcind were re-platformed (out of scope — Xcind is the prototype).

## Links
- Origin finding: pre-existing (global-context §5)
- Related ADR(s): none directly — this is the language substrate beneath all ADRs
- Correspondence-map row(s): entire `implementation/` layer (`tech-stack.md`,
  `project-layout.md`, `cli-scaffolding.md` SCIND-ONLY, all `scaffold-*.go`,
  `goreleaser.yaml`, `makefile`); correspondence-map §3 Q6
- Reconciliation-ledger ID(s): n/a (permanent structural baseline)
