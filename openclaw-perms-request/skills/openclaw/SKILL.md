---
name: openclaw
description: >
  Manage OpenClaw permissions system: broker status, agent config, escalation review,
  audit logs, and health checks. Use when working with OpenClaw agents, permissions,
  or the broker daemon.
---

# /openclaw -- OpenClaw Management

Manage the OpenClaw permissions broker and agent system. Route to the appropriate subcommand based on user input.

## Subcommands

### /openclaw status

Show overall system status at a glance.

```bash
# Broker container status
docker ps --filter name=openclaw-perms-broker --format "table {{.Status}}\t{{.Ports}}"

# Pending escalations count
sudo ls /var/lib/openclaw-broker/escalations/*.json 2>/dev/null | wc -l

# OpenClaw gateway status
sudo -u openclaw /home/openclaw/openclaw/openclaw.mjs gateway status

# Active agents (from config)
sudo cat /home/openclaw/.openclaw/openclaw.json | jq '.agents.list[] | {id, name}'
```

Present as a compact summary: broker up/down, N pending escalations, gateway status, N agents.

### /openclaw config

View or edit OpenClaw configuration.

**View:**
```bash
sudo cat /home/openclaw/.openclaw/openclaw.json | jq .
```

**Edit:** When the user wants to change config:
1. Show current relevant section
2. Validate changes against the schema:
   - `network`: `"none"` | `"host"`
   - `workspaceAccess`: `"none"` | `"ro"` | `"rw"`
   - `tools.allow` / `tools.deny`: arrays of tool glob patterns
   - `autoApprove`: array of tool glob patterns
3. Apply via: `sudo -u openclaw` or direct file edit with backup
4. Always create a `.bak` before modifying

### /openclaw agents

Manage OpenClaw agents.

**List agents with permissions:**
```bash
sudo cat /home/openclaw/.openclaw/openclaw.json | jq '.agents.list[] | {id, name, tools: .tools, network, workspaceAccess}'
```

**Send message to agent:**
```bash
sudo -u openclaw /home/openclaw/openclaw/openclaw.mjs agent --agent <agent-id> -m "message"
```

**Restart gateway:**
```bash
sudo -u openclaw /home/openclaw/openclaw/openclaw.mjs gateway restart
```

### /openclaw audit

View broker audit trail.

**Recent entries:**
```bash
sudo tail -20 /var/lib/openclaw-broker/data/audit.jsonl | jq .
```

**Search by pattern (request ID, agent ID, event type):**
```bash
sudo grep "pattern" /var/lib/openclaw-broker/data/audit.jsonl | jq .
```

**Filter by event type:**
```bash
sudo grep '"event":"escalation_created"' /var/lib/openclaw-broker/data/audit.jsonl | jq .
```

Present audit entries in a readable format: timestamp, event, agent, decision/reason.

### /openclaw health

Deep health check of the entire system.

```bash
# Broker daemon
docker ps --filter name=openclaw-perms-broker --format "{{.Status}}"
docker logs --tail 5 openclaw-perms-broker 2>&1

# Gateway
sudo -u openclaw /home/openclaw/openclaw/openclaw.mjs gateway status

# Disk usage
du -sh /var/lib/openclaw-broker/
du -sh /var/lib/openclaw-broker/data/audit.jsonl

# Directory permissions check
ls -la /var/lib/openclaw-broker/
```

Report any issues found (container down, gateway unreachable, permissions wrong, disk growing).

## Key Paths

| What | Path |
|------|------|
| OpenClaw config | `/home/openclaw/.openclaw/openclaw.json` |
| Broker requests | `/var/lib/openclaw-broker/requests/` |
| Broker responses | `/var/lib/openclaw-broker/responses/` |
| Escalations | `/var/lib/openclaw-broker/escalations/` |
| Audit log | `/var/lib/openclaw-broker/data/audit.jsonl` |
| Temp grants | `/var/lib/openclaw-broker/data/active-temps.json` |
| OpenClaw CLI | `/home/openclaw/openclaw/openclaw.mjs` |
| Broker source | `/home/orangepi/projects/openclaw-perms-broker/` |

## Default Behavior

If the user just says `/openclaw` with no subcommand, run `/openclaw status`.
