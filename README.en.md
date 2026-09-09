# claude-code-pet-setup

> Wire a desktop pet into what your Claude Code session is *actually* doing — all 15 hook events.

[中文](./README.md) · macOS · MIT

<p align="center">
  <img src="assets/permission-bubble-en.png" alt="Clawd's permission card with a destructive-action warning" width="340">
</p>
<p align="center">
  <sub>The card that pops up when Claude Code wants to run <code>rm -rf</code>. <code>Cmd+Shift+Y</code> to allow, <code>Cmd+Shift+N</code> to deny — <b>without switching windows</b></sub>
</p>

## What this is

[Clawd on Desk](https://github.com/rullerzhou-afk/clawd-on-desk) is a desktop pet
that watches AI coding agents. It works out of the box — but the default setup
wires up only a subset of events.

This repo is the full wiring I settled on after three months of daily use: all
**15 Claude Code lifecycle hook events**, plus a small notification script I wrote.

The difference: by default the pet roughly knows whether you're *busy or idle*.
With all 15 events it knows you're **running a tool**, that a **tool just failed**,
that **subagents are running**, that **context is being compacted** — or that it's
**blocked on a permission prompt waiting for you**.

**That last one is the whole point.**

## The problem it actually solves

During long runs you leave the terminal — docs, messages, coffee. You come back
and find it stopped three minutes ago waiting for you to click "allow."

This config cuts those three minutes to zero:

- Permission requests surface as a desktop card: `Cmd+Shift+Y` to allow,
  `Cmd+Shift+N` to deny — **no window switching**
- The card **never auto-dismisses** (`permissionBubbleAutoCloseSeconds: 0`).
  Auto-dismiss is the worst default here: you think you denied it, but it just
  timed out and fell back to the terminal prompt
- Dock flash + sound on completion, so you catch it from another app
- Tool failures change the pet's state immediately — no scrolling back to find
  which step blew up

<p align="center">
  <img src="assets/elicitation-with-pet.png" alt="Clawd's follow-up question card above the pet" width="340">
</p>
<p align="center">
  <sub>When Claude Code asks you to pick between options, the card lands on the desktop and the
  pet switches to its lightbulb "needs input" pose. (Card language follows Clawd's own setting.)</sub>
</p>

## Quick start

```bash
# 1. Install Clawd on Desk itself (not bundled or redistributed here)
#    https://github.com/rullerzhou-afk/clawd-on-desk/releases

# 2. Apply this config
git clone https://github.com/ssssssanjiu/claude-code-pet-setup.git
cd claude-code-pet-setup
bash install.sh
```

The script auto-detects the Clawd and node paths, backs up your existing
`settings.json`, and merges in the hook config. **Safe to re-run** — it replaces
only its own entries, never duplicates, and leaves your other hooks alone.

Start a new Claude Code session to pick it up.

## What's inside

```
├── install.sh                        # path detection + idempotent merge
├── uninstall.sh                      # clean removal, keeps your other hooks
├── settings/
│   └── clawd-hooks.template.json     # all 15 events, paths as placeholders
├── hooks/
│   └── notify-input-needed.py        # mine: macOS banner + Glass sound
└── docs/
    ├── hook-events.md                # every event explained, and why absolute paths
    └── recommended-prefs.md          # the Clawd settings I actually run, with reasons
```

## About the notification script

`hooks/notify-input-needed.py` is the only original code here — about 20 lines.

On a Claude Code `Notification` event it reads the event JSON from stdin, pulls
out the message, and fires a system banner with the Glass sound via `osascript`.

It **complements** Clawd's own bubble rather than replacing it: Clawd's bubble is
on-screen and interactive; the system banner lands in Notification Center and
reaches you inside fullscreen apps. Run both and you miss the least.

Skip it with `INSTALL_NOTIFY=0 bash install.sh`.

## Uninstall

```bash
bash uninstall.sh
```

Removes the hook config only; leaves the Clawd app untouched. Backs up first.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `CLAWD_APP` | auto-detected | Path to Clawd.app |
| `NODE_BIN` | auto-detected | Path to the node binary |
| `CLAUDE_SETTINGS` | `~/.claude/settings.json` | Point at a different settings file |
| `CLAUDE_HOOK_DIR` | `~/.claude/hooks` | Point at a different hooks dir |
| `INSTALL_NOTIFY` | `1` | Set `0` to skip the notification script |

## Credits & license

The pet itself — **[Clawd on Desk](https://github.com/rullerzhou-afk/clawd-on-desk)** —
is built by [@rullerzhou-afk](https://github.com/rullerzhou-afk) under **AGPL-3.0-only**.
Every animation, interaction, and the local permission service are their work.
This repo is just configuration that wires it into Claude Code.

This repository **bundles and redistributes none** of Clawd's code or binaries —
only config templates, install scripts, and docs, under **MIT**.
See [NOTICE.md](./NOTICE.md).

If this setup helps you, go star [the upstream repo](https://github.com/rullerzhou-afk/clawd-on-desk).
