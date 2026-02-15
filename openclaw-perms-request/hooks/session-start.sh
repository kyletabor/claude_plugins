#!/usr/bin/env bash
# SessionStart hook: notify if there are pending escalations
count=$(sudo ls /var/lib/openclaw-broker/escalations/ 2>/dev/null | grep -c '\.json$' || echo 0)
if [ "$count" -gt 0 ]; then
  echo "[openclaw] $count pending escalation(s) -- run /review-escalations to review."
fi
