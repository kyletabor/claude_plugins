---
name: review-escalations
description: |
  Review pending permission escalations from the OpenClaw broker. Use this skill when:
  - The user says "review escalations", "check escalations", or "pending permissions"
  - The user invokes /review-escalations
  - The user asks about broker escalations or permission requests needing review
---

# Review Escalations

Review and resolve pending permission escalations from the OpenClaw permissions broker.

## Paths

- Escalations: `/var/lib/openclaw-broker/escalations/`
- Responses: `/var/lib/openclaw-broker/responses/`
- Audit log: `/var/lib/openclaw-broker/data/audit.jsonl`
- OpenClaw config: `/home/openclaw/.openclaw/openclaw.json`
- Gateway restart: `sudo -u openclaw /home/openclaw/openclaw/openclaw.mjs gateway restart`

## Procedure

### 1. List Pending Escalations

```bash
sudo ls /var/lib/openclaw-broker/escalations/*.json 2>/dev/null
```

If no files, tell the user "No pending escalations" and stop.

### 2. For Each Escalation

Read the JSON file:
```bash
sudo cat /var/lib/openclaw-broker/escalations/{id}.json
```

Each file contains `{ request, decision }` where:
- `request`: the original PermissionRequest from the agent
- `decision`: the broker's assessment and recommendation

Present a compact summary to the user:

```
--- Escalation: {request.id} ---
Agent: {request.agent_name} ({request.agent_id})
Request: {request.permission_type} — {request.details}
Duration: {request.duration}
Agent's reason: {request.reason}

Broker assessment:
  Risk: {decision.risk_level}
  Recommendation: {decision.reason}
  Suggested changes: {decision.config_changes or "none"}
```

Then ask the user (one escalation at a time):

> **Action?** Approve / Deny / Modify / Skip

### 3. Handle User Response

#### Approve

1. **Validate config changes** against the schema before applying:
   - `network`: must be `none` or `host`
   - `workspaceAccess`: must be `none`, `ro`, or `rw`
   - `memory`: must be digits followed by `m` or `g` (e.g. `512m`, `2g`)
   - `tools.allow` values: must be known tool names (`read`, `write`, `edit`, `apply_patch`, `exec`, `process`, `web_search`, `web_fetch`, `memory_search`, `memory_get`, `memory_save`, `session_status`, `sessions_list`, `sessions_history`, `sessions_send`, `sessions_spawn`, `browser`, `canvas`, `image`, `message`, `nodes`) or group prefixes (`group:fs`, `group:web`, `group:runtime`, `group:memory`, `group:sessions`, `group:all`)
   - `capDrop`: must be valid Linux capabilities (e.g. `NET_RAW`, `SYS_ADMIN`, `ALL`)
   - If validation fails, tell the user and ask them to modify instead.

2. **Apply config changes** to openclaw.json. Use a Python one-liner for safe JSON editing:
   ```bash
   sudo python3 -c "
   import json, sys
   with open('/home/openclaw/.openclaw/openclaw.json') as f:
       config = json.load(f)
   # Apply each change from the decision's config_changes
   # For 'set': navigate path and set value
   # For 'add': navigate path and append to array if not present
   # For 'remove': navigate path and remove from array
   with open('/home/openclaw/.openclaw/openclaw.json', 'w') as f:
       json.dump(config, f, indent=2)
       f.write('\n')
   "
   ```

   Build the actual Python code dynamically based on the config_changes from the escalation. Navigate JSON paths like `agents.list[1].tools.sandbox.tools.allow` by splitting on `.` and handling `[N]` array indices.

3. **Determine if restart is needed**:
   - Sandbox changes (network, memory, workspaceAccess, capDrop) = restart required
   - Tool-only grants = restart gateway to be safe

4. **Restart the gateway**:
   ```bash
   sudo -u openclaw /home/openclaw/openclaw/openclaw.mjs gateway restart
   ```

5. **Write response file**:
   ```bash
   sudo tee /var/lib/openclaw-broker/responses/{request-id}.json << 'RESP'
   {
     "id": "{request.id}",
     "timestamp": "{ISO timestamp}",
     "decision": "approve",
     "reason": "Human approved via /review-escalations",
     "changes_applied": ["{change descriptions}"],
     "risk_level": "{decision.risk_level}",
     "revert_at": null,
     "reviewed_by": "human-kyle"
   }
   RESP
   ```

6. **Remove escalation file**:
   ```bash
   sudo rm /var/lib/openclaw-broker/escalations/{request-id}.json
   ```

7. **Append audit entry**:
   ```bash
   echo '{"timestamp":"'{ISO}'","event":"decision_made","request_id":"'{id}'","agent_id":"'{agent_id}'","details":{"decision":"approve","reason":"Human approved","reviewed_by":"human-kyle"}}' | sudo tee -a /var/lib/openclaw-broker/data/audit.jsonl > /dev/null
   ```

#### Deny

1. Write response with `"decision": "deny"` and the user's reason (ask if not provided).
2. Remove escalation file.
3. Append audit entry with `"decision": "deny"`.
4. No config changes. No restart needed.

#### Modify

1. Show the broker's suggested config_changes to the user.
2. Ask the user what they want to adjust (e.g., different scope, shorter duration, different tools).
3. Build the modified config_changes based on user input.
4. Validate the modified changes against the schema (same rules as Approve step 1).
5. Apply as if it were an Approve with the modified changes.

#### Skip

Move to the next escalation. Do not write any response or remove the file.

## Important Notes

- Always use `sudo` for file operations under `/var/lib/openclaw-broker/` and `/home/openclaw/`.
- Present ONE escalation at a time. Don't overwhelm the user with a wall of text.
- After processing all escalations, give a brief summary: "Reviewed N escalations: X approved, Y denied, Z skipped."
- If the config_changes array is empty but the decision is approve, just write the response and clean up — no config edit or restart needed.
