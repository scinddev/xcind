# Divergence Registry (Scind ↔ Xcind)

**Status**: Living registry. **Owner plan**: [P7](../07-divergence-registry.md).
**Read first**: [`00-global-context.md`](../00-global-context.md) §2 (operating
model), §2a (misclassification safeguard), §5 (Go/Bash).

This is the durable, machine-diffable record of **intentional, permanent
differences** between Scind (design canon) and Xcind (its Bash proof-of-concept).
An entry here says: *"Xcind knowingly differs from Scind and intends to keep
differing — this is expected, not drift."* On every sync round, a delta that
matches an **Active** entry is skipped as expected; a delta with **no** entry is
new and must be triaged (learning vs. new divergence).

---

## What a divergence is (and is NOT)

Scind is canon. Xcind's lessons *upgrade* the canon. A divergence is the **opposite
direction**: a place where Xcind's approach should **not** flow back into Scind.

- A **divergence** = Xcind does it differently *and Scind should not adopt that*.
- A **learning** (NOT here) = Xcind proved Scind's design wrong/incomplete →
  changes Scind. Learnings live in P3/P6, not this registry.

> **The dangerous failure mode** (§2a) is paving a real learning into a divergence:
> once mislabeled, the insight looks settled and future rounds skip it as expected.
> Every entry therefore carries a **Canon-change test** field recording the
> canon-change question it was tested against, so a later round can always reopen
> it. Nothing is ever discarded.

---

## The admission gate — a divergence must be *earned*

This registry is **not** a catch-all for "things that differ." An item is admitted
**only if it passes both tests**:

1. **Intent test** — the difference is either *forced* (Bash/structural) or a
   *deliberate product-scope choice*, statable in one sentence.
2. **Canon-neutrality test** — adopting Xcind's approach into Scind would **not**
   improve the design. You must be able to write the **"Why Scind should NOT simply
   adopt Xcind's approach"** field convincingly. **If you cannot, the item is a
   CANON-CHANGE (a learning), not a divergence** — route it back to P3/P6; do not
   admit it here.

**High-risk entries require an adversarial second opinion.** For any **Design** or
**Scope** entry, a second reviewer must attempt to prove it is a *mislabeled
learning* before admission; the entry is recorded only if that attempt fails.
**Structural** and **Process** entries (Bash vs Go, config-file format vs env-vars,
two-track docs) are low-risk and admitted on a one-line justification.

> Implementation-shape divergences are safe to record; **design-assumption
> divergences are where lost learnings hide** (§2a). That is why the label has to
> earn its place.

---

## Categories

| Category | Meaning | Typical fate | Admission |
|----------|---------|--------------|-----------|
| **Structural** | Language/build/packaging — permanent by nature (Bash vs Go). | Permanent. | One-line justification. |
| **Design** | A design choice Xcind made against canon on purpose. | Long-lived; re-audit each round. | **Adversarial re-check required.** |
| **Scope** | Xcind deliberately doesn't do something Scind specifies. | May resolve if Xcind catches up — or stay. | **Adversarial re-check required.** |
| **Process** | Docs/workflow/tooling difference. | Permanent-ish. | One-line justification. |

---

## How the registry stays alive

Wired into P6's standing process (`engineering/maintenance/cross-project-sync.md`):

- **Diff every round.** Observed deltas are diffed against `registry.json`. A delta
  matching an **Active** entry is *expected* — skip it. A delta with no entry is
  *new* → triage (learning vs. new divergence).
- **Re-audit Design/Scope entries each round (the reverse path).** Structural and
  Process divergences are stable. Design/Scope entries can turn out to be learnings
  as the Scind design matures or new Xcind evidence arrives. Each round re-runs the
  canon-neutrality test on every **Active** Design/Scope entry; if one no longer
  justifies itself, flip it to `CANON-CHANGE` and route to P6. This is the
  guaranteed **divergence → learning → canon** path — nothing stays paved over.
- **Resolve, don't delete.** When a divergence is resolved (Scind changed to match,
  or Xcind adopted canon), flip **Status** to `Resolved`/`Superseded` — keep the
  record for history.
- **Link both ways.** Every entry links its origin finding (L-/XA-/SA-xxxx), related
  ADR(s), and correspondence-map row(s), so a reader landing on either finds the
  exception.

---

## Relationship to `engineering/decisions/` (ADRs)

An **ADR** records *why Xcind decided something*. A **divergence entry** records
*why that decision differs from Scind and stays that way*. Xcind-only ADRs (e.g.
`0014-two-track-documentation`) each have a corresponding divergence entry that
links to the ADR — the ADR is the decision, the divergence entry is the standing
exception to canon.

---

## Files in this registry

- **[`TEMPLATE.md`](./TEMPLATE.md)** — copy this to start a new `NNNN-{slug}.md`.
- **[`registry.json`](./registry.json)** — machine-readable roll-up mirroring every
  entry's frontmatter. This is what the sync procedure diffs against.
- **`NNNN-{slug}.md`** — one file per divergence, IDs from a single sequence.

### Index

IDs are assigned from a single sequence. **Seed** entries (0001–0002) were certain
before P3–P5 finished; the rest are **populated** from P3/P4/P5 findings.

| ID | Title | Category | Status | Origin |
|----|-------|----------|--------|--------|
| [0001](./0001-bash-vs-go-tech-stack.md) | Bash vs Go tech stack | Structural | Active | pre-existing (§5) |
| [0002](./0002-two-track-documentation.md) | Two-track documentation | Process | Active | pre-existing (ADR-0014) |
| [0003](./0003-sourceable-shell-config-model.md) | Sourceable-shell config model | Structural | Active | L-0023 |
| [0004](./0004-env-specific-file-pattern-expansion.md) | Env-specific file-pattern expansion | Structural | Active | L-0024 |
| [0005](./0005-config-shell-injection-surface.md) | Config shell-injection/escaping surface | Structural | Active | L-0025 |
| [0006](./0006-own-app-service-discovery-scope.md) | Own-app-only service-discovery scope | Design | Active | L-0026 |
| [0007](./0007-single-file-config-model.md) | Single-file config model (workspace+app) | Design | Active | L-0027 |
| [0008](./0008-runtime-dependency-checker.md) | `--check` runtime dependency checker | Structural | Active | XA-0036 |
| [0009](./0009-config-trust-security-warning.md) | `.xcind.sh` trust/security warning | Structural | Active | XA-0037 |
| [0010](./0010-starship-nix-format.md) | `--generate-starship --format nix` output | Structural | Active | XA-0038 |
| [0011](./0011-preview-resolved-command-flag.md) | `--preview` resolved-command flag | Structural | Active | XA-0039 |
| [0012](./0012-shell-expansion-in-file-patterns.md) | Shell expansion in file patterns | Structural | Active | XA-0040 |
| [0013](./0013-per-file-override-sibling.md) | Per-file `.override` sibling auto-derivation | Structural | Active | XA-0041 |
| [0014](./0014-additional-config-files-includes.md) | `XCIND_ADDITIONAL_CONFIG_FILES` includes | Structural | Active | XA-0042 |
| [0015](./0015-default-domain-scind-io.md) | Default domain `localhost.scind.io` | Design | Active | XA-0034 |
| [0016](./0016-assigned-port-sticky-trust.md) | Assigned-port sticky-trust allocation | Design | Active | XA-0035 |
| [0017](./0017-stateless-identity-registry.md) | Stateless identity/registry (TSV) | Design | Active | XA-0033 |
| [0018](./0018-per-hook-overlay-split.md) | Concern-split per-hook overlays | Scope | Active | XA-0030 |
| [0019](./0019-hook-phase-vocabulary.md) | Internal 4-phase hook vocabulary | Design | Active | XA-0031 |
| [0020](./0020-per-app-sha-config-json.md) | Per-app SHA-keyed `config.json` | Design | Active | XA-0032 |
| [0021](./0021-options-based-targeting-by-name.md) | Options-based targeting by name | Scope | Active | SA-0001 |
| [0022](./0022-host-gateway-env-var-injection.md) | `*_HOST_GATEWAY` env-var injection | Scope | Active | SA-0002 |
| [0023](./0023-generated-manifest.md) | Computed generated manifest | Design | Active | SA-0007 |
| [0024](./0024-flavors-variant-configs.md) | Flavors (variant configs) | Scope | Active | SA-0008 |
| [0025](./0025-port-inventory-status-model.md) | `port_inventory` status model | Design | Active | SA-0009 |
| [0026](./0026-workspace-state-machine.md) | Workspace state machine | Design | Active | SA-0010 |
| [0027](./0027-port-scan-gc-commands.md) | `port scan` / `port gc` | Scope | Active | SA-0011 |
| [0028](./0028-workspace-orchestration-up-down.md) | Workspace-wide up/down/restart | Scope | Active | SA-0013 |
| [0029](./0029-workspace-clone-repo-urls.md) | `workspace clone` from repo URLs | Scope | Active | SA-0014 |
| [0030](./0030-port-type-plugins-tcp-sni.md) | Port-type plugins + tcp/SNI routing | Scope | Active | SA-0015 |
| [0031](./0031-shared-volumes.md) | Shared volumes | Scope | Active | SA-0017 |
| [0032](./0032-visibility-access-control-labels.md) | Visibility (public/protected) labels | Scope | Active | SA-0019 |
| [0033](./0033-explicit-workspace-generate.md) | Explicit `workspace generate` | Design | Active | SA-0023 |
| [0034](./0034-explicit-workspace-destroy.md) | Explicit `workspace destroy` | Design | Active | SA-0024 |
| [0035](./0035-reference-appendices-presentation.md) | Reference-appendices presentation | Process | Active | SA-0025 |

### Rejected from the registry (bounced back as CANON-CHANGE)

Items evaluated for admission and **refused** because they failed the
canon-neutrality test (they are learnings, not divergences). Recorded here so the
decision stays auditable:

- **Apex URL designation (Scind ADR-0013 ↔ Xcind ADR-0017, P2 `DIVERGED`)** — the
  one genuinely-DIVERGED ADR row. Its P3 adversarial re-check + human product-call
  resolved it to **CANON-CHANGE** (L-0018 apex-eligibility scoped to proxied
  exports; L-0028 hybrid explicit-`primary:true`-else-positional). **Not admitted.**
- **`docker-labels` spec (P2 `DIVERGED`)** — resolved to CANON-CHANGE (L-0008
  redirect middleware, L-0011 preferred-scheme `.url`) + one ESCALATE (L-0034
  visibility → P5/P6). **Not admitted.**
- **P5 SA-0020 (customizable `%VAR%` template surface)** — proposed for admission as
  a Scope divergence, **REFUSED** by the P7 adversarial re-check. The reviewer showed
  the user-overridable template layer is *speculative generality in direct tension
  with Scind's own ADR-0004 (convention-based naming)*, and Xcind's hard-coded naming
  (`lib/xcind/xcind-naming-lib.bash`) is a clean existence proof that fixed
  conventions suffice — so the canon-neutrality test **fails** (Scind should *drop*
  the override surface, not keep it). **Routed to P6 as CANON-OVERREACH:** keep
  ADR-0004's default templates, drop the customizable template-override surface.
- **P5 SA-0016 (app dependencies) & SA-0018 (health checks)** — labeled
  DELIBERATELY-DEFERRED but retained on Xcind's roadmap (both projects still plan
  them). Not a permanent divergence — you cannot argue "Scind should not adopt"
  when Xcind itself intends to build it. **Xcind backlog, not a registry entry.**
- **P5 SA-0005 (fail-fast port-conflict at startup)** — already labeled
  CANON-OVERREACH in P5 (not DELIBERATELY-DEFERRED), routed to P6. Related to
  divergence [0016](./0016-assigned-port-sticky-trust.md), which was *narrowed* so it
  does not absorb this learning — the self-vs-foreign probing defect stays a P6
  canon-change.
