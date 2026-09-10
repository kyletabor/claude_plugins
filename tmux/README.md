# Tmux

Let Claude drive tmux sessions safely: launch test sessions, send keystrokes, read output, clean up.

## What It Does

Gives Claude a disciplined recipe for controlling tmux. It is built for verification work -- for example, launching a fresh Claude Code session in tmux to confirm a plugin, skill, or hook actually loads -- and for driving any interactive terminal program.

Safety rules baked in:

- Claude only touches sessions it created in the current conversation
- Your own sessions (`claude`, `shell`, etc.) are hands-off unless you name one
- Every session is registered in `~/.local/share/tmux-skill/` and cleaned up before Claude reports "done"
- Mandatory waits between send and capture to avoid silent race conditions

## Components

- **Skills:** `tmux` -- create, send input, read output, and cleanup recipes with multi-agent safety

## Usage

Say:

- "Launch a test session"
- "Verify this in a fresh session"
- "Send this to tmux" / "Read the tmux output"
- "Clean up your sessions"

## Requirements

`tmux` and `openssl` on the PATH. `flock` (util-linux) for the session registry.

## Installation

```
/plugin marketplace add kyletabor/claude_plugins
/plugin install tmux@kyle-plugins
```
