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
shell       = ["bash", "--noprofile", "--norc"]   # skip user rc for speed
symbol      = "⬡ "
style       = "bold cyan"
format      = "[$symbol$output]($style) "
```

Starship config is a single file with no `include` directive, so paste the block directly into `~/.config/starship.toml` — or, if you manage your dotfiles elsewhere, point `STARSHIP_CONFIG` at your managed file and add the block there. Starship auto-renders every `[custom.*]` module, so the segment appears without further wiring; to pin its position, reference `$custom.xcind` in your top-level `format`. The `when = "xcind-prompt --detect"` line is what makes the segment vanish outside an app — `--detect` exits non-zero when there's no Xcind context, so Starship skips the module.

## Showing the apex hostname

The apex hostname is **opt-in**. To enable it, swap the active `command` line for the commented variant the generator ships:

```toml
command = "xcind-prompt --apex"
```

With `--apex`, the output becomes `<display> <linked hostname>`: the names-only identity, followed by the apex hostname rendered as a clickable OSC 8 hyperlink.

One caveat worth understanding: the link is **declared, not live**. It points where the app *would* serve, read straight from your config — Xcind does not check whether anything is actually listening. Clicking the link while the app is down yields an ordinary connection error, and there is no up/down indication in the prompt (that's out of scope for this helper).

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
