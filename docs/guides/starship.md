# Starship prompt

Xcind ships a helper that prints a compact workspace/app segment for a [Starship](https://starship.rs) custom module, so your current Xcind context shows up right in your prompt.

## What it shows

The segment is your current Xcind identity, names-only: `<workspace>/<app>` inside a workspace, or just `<app>` for a workspaceless app. When you run outside any app the helper prints nothing, so the segment disappears the moment you leave a project — no stray symbol cluttering an unrelated directory.

It can optionally append the apex hostname as a clickable link with `--apex` (opt-in — see [Showing the apex hostname](#showing-the-apex-hostname) below).

## Setup

The easiest way to install the module is to let `xcind-config` emit it for you, the same way completions ship via `xcind-config completion`:

```bash
xcind-config --generate-starship
```

That prints the `[custom.xcind]` block below. Paste it into your `~/.config/starship.toml`:

```toml
# ~/.config/starship.toml
[custom.xcind]
description = "Xcind workspace/app context"
command     = "xcind-prompt"
# command   = "xcind-prompt --apex"   # opt-in: append the apex hostname as a clickable OSC 8 link
when        = "xcind-prompt --detect"
shell       = ["bash", "--noprofile", "--norc", "-c"]   # skip user rc for speed
symbol      = "⬡ "
style       = "bold cyan"
format      = "[$symbol$output]($style) "
```

Starship config is a single file with no `include` directive, so paste the block directly into `~/.config/starship.toml` — or, if you manage your dotfiles elsewhere, point `STARSHIP_CONFIG` at your managed file and add the block there. Starship auto-renders every `[custom.*]` module, so the segment appears without further wiring; to pin its position, reference `$custom.xcind` in your top-level `format`. The `when = "xcind-prompt --detect"` line is what makes the segment vanish outside an app — `--detect` exits non-zero when there's no Xcind context, so Starship skips the module.

### Home Manager (Nix)

If you manage Starship through [Home Manager](https://nix-community.github.io/home-manager/), pass `--format nix` to get the same module as a Nix attrset instead of TOML:

```bash
xcind-config --generate-starship --format nix
```

That prints a bare `{ … }` attrset (preceded by a one-line splice hint). Assign it under your starship settings:

```nix
programs.starship.settings.custom.xcind = {
  # …the emitted attrset…
};
```

The default (`--format toml`, or no `--format`) is unchanged. A file path still works in either argument order: `xcind-config --generate-starship --format nix ~/starship-xcind.nix`.

## Showing the apex hostname

The apex hostname is **opt-in**. To enable it, swap the active `command` line for the commented variant the generator ships:

```toml
command = "xcind-prompt --apex"
```

With `--apex`, the output becomes `<display> <linked hostname>`: the names-only identity, followed by the apex hostname rendered as a clickable OSC 8 hyperlink.

One caveat worth understanding: the link is **declared, not live**. It points where the app *would* serve, read straight from your config — Xcind does not check whether anything is actually listening. Clicking the link while the app is down yields an ordinary connection error, and there is no up/down indication in the prompt (that's out of scope for this helper).

## Splitting the segment into per-field modules

The single `[custom.xcind]` module above prints the whole segment in one style. If you want each field styled independently — say the workspace in magenta, the app in cyan, and the apex dimmed — print one field per module with `--print` and gate each with its own field-aware `--detect`:

```toml
# Three independently-styled modules off one helper.
[custom.xcind_workspace]
command = "xcind-prompt --print workspace"
when    = "xcind-prompt --detect --print workspace"
shell   = ["bash", "--noprofile", "--norc", "-c"]
symbol  = "⬡ "
style   = "bold magenta"
format  = "[$symbol$output]($style) "

[custom.xcind_app]
command = "xcind-prompt --print app"
when    = "xcind-prompt --detect --print app"
shell   = ["bash", "--noprofile", "--norc", "-c"]
style   = "bold cyan"
format  = "[$output]($style) "

[custom.xcind_apex]
command = "xcind-prompt --print apex"
when    = "xcind-prompt --detect --print apex"
shell   = ["bash", "--noprofile", "--norc", "-c"]
style   = "dimmed white"
format  = "[$output]($style) "
```

`--print` selects a single field — `workspace`, `app`, `apex`, or `apex-url` (the default `both` is what the single-module recipe prints). Each module auto-hides via its own `when` gate: the workspace module vanishes in a workspaceless app (where `--print workspace` is empty), and the apex module vanishes when the app declares no apex. The app module shows whenever you're inside any Xcind app.

The apex field here is the same OSC 8-linked hostname as `--apex` above, so the [terminal-support / plain-text fallback](#terminal-support-and-plain-text-fallback) (`--no-hyperlink`, `XCIND_PROMPT_HYPERLINKS=0`) and the [declared-not-live caveat](#showing-the-apex-hostname) apply unchanged — add `--no-hyperlink` to the `xcind_apex` `command` if your terminal can't render OSC 8.

`--print apex-url` prints the apex **URL** (`<scheme>://<hostname>`) as **plain text** — no OSC 8 hyperlink, so `--no-hyperlink` / `XCIND_PROMPT_HYPERLINKS=0` have no effect on it. Use it when you want the full clickable-by-your-terminal URL (or to feed another tool) rather than the linked hostname `--print apex` emits.

**Performance note (the honest cost).** Field-aware detection is not free. Plain `--detect` is a fast stat-walk; `--detect --print workspace|apex` sources config to know availability (no jq/Docker/hooks; within Starship's 500ms budget) — it must, because whether a workspace or apex exists is only knowable after resolving the config. The single-module recipe draws with one cheap `--detect`; this three-module recipe runs up to three `--detect` plus three `--print` invocations per prompt draw. That's still well under the budget and still jq/Docker/hook-free, but it is heavier than the one-module recipe — choose it deliberately when you want the per-field styling, and stay with the single module otherwise. As with the single-module setup, do **not** raise Starship's `command_timeout` to accommodate it (see [A note on prompt width](#a-note-on-prompt-width)).

## Terminal support and plain-text fallback

OSC 8 hyperlinks render as clickable text in terminals that support them — Windows Terminal and recent JetBrains terminals among them. Older terminal emulators don't recognize the escape sequence and will show the raw escape bytes around the hostname instead.

If your terminal is in that group, drop the hyperlink and emit the bare apex hostname as plain text. Either set the command to use the flag:

```toml
command = "xcind-prompt --apex --no-hyperlink"
```

…or set `XCIND_PROMPT_HYPERLINKS=0` in your environment, which has the same effect (plain hostname, no escape sequences).

## A note on prompt width

OSC 8 escape bytes should be zero-width, but whether Starship accounts for them correctly when measuring the prompt is not guaranteed across versions and terminals. If you turn on `--apex` and the prompt mis-wraps or the cursor jumps — especially alongside a right prompt — fall back to `--no-hyperlink`. **Test `--apex` on your real terminal before relying on it.**

Do **not** raise Starship's `command_timeout` to accommodate the helper. It is fast by design and runs well under the default 500 ms; a timeout bump only masks an unrelated problem.

## Where to go next

- [IDE and tool integration](./tools-ide-integration.md) — completions, the JetBrains plugin, and devcontainers.
- [`xcind-config` reference](../reference/cli.md#xcind-config) — `--json`, `--preview`, `doctor`, completion and generator targets.
