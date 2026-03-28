# Statusline Setup

The Claude Code statusline is a persistent bar at the bottom of your terminal that updates after each assistant response. It runs a local bash script that receives JSON session data on stdin and outputs ANSI-colored text.

## My Setup

Two-line dashboard optimized for staying in flow:

```
orangepi:claude_plugins 🌿 main +3 ~2              ⏱ 14m
▓▓▓▓▓▓░░░░ 62%  │  🔵 Fix sidebar icons  │  +47 -12  │  2.2M tok
```

**Line 1:** hostname, git repo name (with subdirectory if nested), git branch with staged/modified file counts, session duration.

**Line 2:** Context window remaining (color-coded progress bar), active task title, lines added/removed this session, total tokens used (including all subagents).

### Why these fields?

| Field | Why it's there |
|-------|---------------|
| **Context bar** | Context depletion sneaks up on you. Green/yellow/red at a glance tells you when to wrap up or handoff. |
| **Active task** | Glancing down and seeing what I'm supposed to be working on keeps me on track. Pulls from my issue tracker ([beads](https://github.com/anthropics/claude-code/tree/main/.beads)). |
| **Git repo + branch** | Shows which repo you're in (not just the leaf directory) plus staged/modified counts so you know if you forgot to commit. |
| **Session duration** | "Take a break" signal. If it says 2h+, I've been at it too long. |
| **Lines changed** | Seeing `+147 -23` tells me the session was productive. |
| **Total tokens** | Cumulative across all subagents — the real measure of how much work this session did. Formatted as K/M for readability. |
| **No cost tracking** | I'm on the Max plan (unlimited). If you're on usage-based billing, swap in `cost.total_cost_usd` instead. |

### What I didn't include

- **Model name** — I know what model I'm using. Wasted space.
- **Rate limits** — Max plan, not relevant. Add `rate_limits.five_hour.used_percentage` if you're on Pro.
- **Kubernetes/Docker context** — Some devs love this. I don't switch clusters during coding sessions.

## Installation

### 1. Create the script

Save this to `~/.claude/statusline-command.sh`:

```bash
#!/bin/bash
# 2-line statusline dashboard
# Line 1: host:repo, git branch+status, session duration
# Line 2: context bar, active task, lines changed, total tokens
input=$(cat)

# --- Parse JSON input ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

host=$(hostname -s)

# Show repo name if in a git repo, otherwise just the directory basename
if git -C "$cwd" rev-parse --show-toplevel >/dev/null 2>&1; then
  repo=$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)")
  subdir=$(git -C "$cwd" rev-parse --show-prefix 2>/dev/null | sed 's:/$::')
  if [ -n "$subdir" ]; then
    dir="${repo}/${subdir}"
  else
    dir="$repo"
  fi
else
  dir=$(basename "$cwd")
fi

# --- Git info: branch +staged ~modified ---
git_info=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" -c gc.auto=0 symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$cwd" -c gc.auto=0 rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    staged=$(git -C "$cwd" -c gc.auto=0 diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    modified=$(git -C "$cwd" -c gc.auto=0 diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    counts=""
    [ "$staged" -gt 0 ] 2>/dev/null && counts=" +${staged}"
    [ "$modified" -gt 0 ] 2>/dev/null && counts="${counts} ~${modified}"
    git_info=$(printf " \033[32m🌿 %s\033[33m%s\033[0m" "$branch" "$counts")
  fi
fi

# --- Session duration ---
duration_info=""
if [ -n "$duration_ms" ] && [ "$duration_ms" != "null" ]; then
  total_s=$((duration_ms / 1000))
  hours=$((total_s / 3600))
  mins=$(( (total_s % 3600) / 60 ))
  if [ "$hours" -gt 0 ]; then
    duration_info=$(printf " \033[2m⏱ %dh %dm\033[0m" "$hours" "$mins")
  elif [ "$mins" -gt 0 ]; then
    duration_info=$(printf " \033[2m⏱ %dm\033[0m" "$mins")
  fi
fi

# --- Context bar (10 chars, color-coded) ---
ctx_bar=""
if [ -n "$remaining" ] && [ "$remaining" != "null" ]; then
  pct=${remaining%.*}
  [ -z "$pct" ] && pct=0
  filled=$((pct / 10))
  empty=$((10 - filled))
  if [ "$pct" -gt 30 ]; then
    color="32" # green
  elif [ "$pct" -gt 10 ]; then
    color="33" # yellow
  else
    color="31" # red
  fi
  bar=""
  for i in $(seq 1 $filled); do bar="${bar}▓"; done
  for i in $(seq 1 $empty); do bar="${bar}░"; done
  ctx_bar=$(printf "\033[${color}m${bar}\033[0m %d%%" "$pct")
fi

# --- Total tokens (input + output, formatted as K or M) ---
tokens_info=""
total_tokens=$((total_in + total_out))
if [ "$total_tokens" -gt 0 ]; then
  if [ "$total_tokens" -ge 1000000 ]; then
    tok_display=$(awk "BEGIN {printf \"%.1fM\", $total_tokens/1000000}")
  elif [ "$total_tokens" -ge 1000 ]; then
    tok_display=$(awk "BEGIN {printf \"%.0fK\", $total_tokens/1000}")
  else
    tok_display="${total_tokens}"
  fi
  tokens_info=$(printf " \033[2m│\033[0m \033[2m%s tok\033[0m" "$tok_display")
fi

# --- Lines changed ---
lines_info=""
if [ "$lines_added" -gt 0 ] || [ "$lines_removed" -gt 0 ]; then
  lines_info=$(printf " \033[2m│\033[0m \033[32m+%d\033[0m \033[31m-%d\033[0m" "$lines_added" "$lines_removed")
fi

# --- Output ---
printf "\033[1;31m%s\033[0m:\033[36m%s\033[0m%s%s\n" "$host" "$dir" "$git_info" "$duration_info"
printf "%s%s%s" "$ctx_bar" "$lines_info" "$tokens_info"
```

> **Note:** The script above omits the task tracker integration (beads) since that's specific to my setup. If you use a task tracker with a CLI, you can add a cached lookup — see the "Adding a task tracker" section below.

### 2. Make it executable

```bash
chmod +x ~/.claude/statusline-command.sh
```

### 3. Configure Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "command": "~/.claude/statusline-command.sh"
  }
}
```

## Customization Ideas

### Adding a task tracker

Cache the lookup so it doesn't slow down your statusline (it runs frequently):

```bash
# Cache task title every 10 seconds
task_cache="/tmp/.statusline-task-cache"
task_age=999
if [ -f "$task_cache" ]; then
  task_age=$(( $(date +%s) - $(stat -c %Y "$task_cache" 2>/dev/null || echo 0) ))
fi
if [ "$task_age" -gt 10 ]; then
  # Replace with your task tracker CLI
  task_title=$(your-cli current-task 2>/dev/null | head -1 | cut -c1-30)
  echo "$task_title" > "$task_cache" 2>/dev/null
else
  task_title=$(cat "$task_cache" 2>/dev/null)
fi
if [ -n "$task_title" ]; then
  printf " \033[2m│\033[0m \033[36m🔵 %s\033[0m" "$task_title"
fi
```

### Adding cost tracking (usage-based billing)

```bash
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
if [ "$(echo "$cost > 0" | bc 2>/dev/null)" = "1" ]; then
  printf " \033[2m│\033[0m $%.2f" "$cost"
fi
```

### Adding rate limit tracking (Pro plan)

```bash
rate=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
if [ -n "$rate" ]; then
  printf " \033[2m│\033[0m rate: %s%%" "$rate"
fi
```

## Available JSON Fields

The full list of data your script receives on stdin:

| Field | Description |
|-------|-------------|
| `workspace.current_dir` | Current working directory |
| `model.display_name` | Active model name |
| `context_window.remaining_percentage` | Context % remaining |
| `context_window.used_percentage` | Context % used |
| `context_window.context_window_size` | Total context size (200K or 1M) |
| `context_window.total_input_tokens` | Cumulative input tokens (all subagents) |
| `context_window.total_output_tokens` | Cumulative output tokens (all subagents) |
| `cost.total_cost_usd` | Session cost in USD |
| `cost.total_duration_ms` | Session wall-clock time |
| `cost.total_lines_added` | Lines added this session |
| `cost.total_lines_removed` | Lines removed this session |
| `rate_limits.five_hour.used_percentage` | 5-hour rate limit usage |
| `rate_limits.seven_day.used_percentage` | 7-day rate limit usage |
| `session_id` | Current session ID |
| `version` | Claude Code version |

## Performance Tips

- The script runs after every assistant message (~300ms debounce). Keep it fast.
- Cache expensive operations (git in large repos, CLI lookups) to temp files.
- `git -c gc.auto=0` prevents git from triggering garbage collection mid-render.
- Avoid network calls — they'll block the UI until they complete.
