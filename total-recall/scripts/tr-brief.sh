#!/usr/bin/env bash
# tr-brief.sh — Cold-start briefing for Total Recall plugin (R6).
#
# Read-only. Fail-soft on every data source. Output <= 15 lines.
# Honors TR_FORCE_OFFLINE=1 to simulate TR backend down.
#
# Sources (each may be skipped if unavailable):
#   1. Beads (in_progress + ready) — falls back to central kyle-dev-infra/.beads
#   2. capture-mcp inbox (5 most recent)
#   3. TR backend (docker ps + last ingest timestamp)
#   4. Pending handoff files in ~/.claude/projects/-home-orangepi/handoffs/

set -u  # NOT pipefail — fail-soft is the design
# (intentionally no `set -e` — we want to keep producing output even if one
# section fails)

CENTRAL_BEADS_DIR="${HOME}/projects/kyle-dev-infra"
# Handoff dir: /mnt/pi-data/claude-workspace/handoffs is the real one used by
# the handoff plugin. The task spec mentioned ~/.claude/projects/.../handoffs
# but that dir does not exist on this system. Verified Apr 16 2026.
HANDOFF_DIR="${HANDOFF_DIR:-/mnt/pi-data/claude-workspace/handoffs}"
CAPTURE_DB="${CAPTURE_DB:-${HOME}/.local/share/capture-mcp/capture.db}"
TR_CONTAINER="${TR_CONTAINER:-total-recall}"

# ---- helpers ---------------------------------------------------------------

# Trim a string. Echos the trimmed result.
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Truncate to N chars, add ellipsis if cut.
truncate_str() {
    local s="$1" n="$2"
    if [ "${#s}" -gt "$n" ]; then
        printf '%s...' "${s:0:$((n-3))}"
    else
        printf '%s' "$s"
    fi
}

# Resolve the beads working dir. Prefers $PWD if it has .beads, else central.
# Echos a path or empty if nothing usable.
resolve_beads_dir() {
    if [ -d "${PWD}/.beads" ]; then
        printf '%s' "$PWD"
    elif [ -d "${CENTRAL_BEADS_DIR}/.beads" ]; then
        printf '%s' "$CENTRAL_BEADS_DIR"
    else
        printf ''
    fi
}

# ---- date header -----------------------------------------------------------
TODAY="$(date '+%b %d %Y %H:%M')"

# ---- last session ----------------------------------------------------------
LAST_SESSION_LINE="(no handoffs)"
if [ -d "$HANDOFF_DIR" ]; then
    # shellcheck disable=SC2012  # ls -t is fine for a small dir of named files
    latest_handoff="$(ls -1t "$HANDOFF_DIR" 2>/dev/null | head -n 1)"
    if [ -n "$latest_handoff" ]; then
        # Strip leading timestamp like "2026-04-14T1315-" and trailing ".md"
        slug="${latest_handoff%.md}"
        slug="$(printf '%s' "$slug" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{4}-//')"
        # Also strip any leading project prefix like "kyle-dev-infra-bx3-"
        # (keep it — context is useful) — no, leave whole slug for clarity.
        LAST_SESSION_LINE="$(truncate_str "$slug" 70)"
    fi
fi

# ---- handoff count ---------------------------------------------------------
HANDOFF_COUNT=0
if [ -d "$HANDOFF_DIR" ]; then
    HANDOFF_COUNT="$(find "$HANDOFF_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
fi

# ---- beads: in flight + ready ---------------------------------------------
IN_FLIGHT_LINE="beads unavailable"
NEEDS_YOU_LINE="beads unavailable"
BEADS_DIR="$(resolve_beads_dir)"

if [ -n "$BEADS_DIR" ] && command -v bd >/dev/null 2>&1; then
    in_flight_json="$(cd "$BEADS_DIR" && bd list --status=in_progress --json 2>/dev/null)"
    ready_json="$(cd "$BEADS_DIR" && bd ready --limit=3 --json 2>/dev/null)"

    # In flight — count + first 2 ids/titles
    if [ -n "$in_flight_json" ] && printf '%s' "$in_flight_json" | jq empty >/dev/null 2>&1; then
        in_count="$(printf '%s' "$in_flight_json" | jq 'length' 2>/dev/null)"
        in_count="${in_count:-0}"
        if [ "$in_count" = "0" ]; then
            IN_FLIGHT_LINE="none in progress"
        else
            ids="$(printf '%s' "$in_flight_json" | jq -r '.[:3] | map(.id) | join(", ")' 2>/dev/null)"
            IN_FLIGHT_LINE="($in_count) $(truncate_str "$ids" 80)"
        fi
    fi

    # Ready — top 3 with brief titles
    if [ -n "$ready_json" ] && printf '%s' "$ready_json" | jq empty >/dev/null 2>&1; then
        ready_count="$(printf '%s' "$ready_json" | jq 'length' 2>/dev/null)"
        ready_count="${ready_count:-0}"
        if [ "$ready_count" = "0" ]; then
            NEEDS_YOU_LINE="none ready"
        else
            # Format: "id (first-3-words-of-title), id (...), ..."
            ready_summary="$(printf '%s' "$ready_json" \
                | jq -r '.[:3] | map("\(.id|sub("^.*-"; "")) (\(.title|split(" ")[:4]|join(" ")))") | join(", ")' \
                2>/dev/null)"
            NEEDS_YOU_LINE="($ready_count) $(truncate_str "$ready_summary" 100)"
        fi
    fi
fi

# Track which beads dir we used (for the footer)
BEADS_SOURCE_LABEL=""
if [ -n "$BEADS_DIR" ]; then
    if [ "$BEADS_DIR" = "$CENTRAL_BEADS_DIR" ] && [ "$PWD" != "$CENTRAL_BEADS_DIR" ]; then
        BEADS_SOURCE_LABEL=" [central]"
    fi
fi

# ---- captures: 5 most recent inbox items ----------------------------------
CAPTURES_LINE="captures unavailable"
CAPTURE_COUNT=0

query_captures() {
    sqlite3 -readonly "$CAPTURE_DB" \
        "SELECT substr(title, 1, 60) FROM items WHERE status='inbox' ORDER BY created_at DESC LIMIT 5" \
        2>/dev/null
}

if [ -f "$CAPTURE_DB" ] && command -v sqlite3 >/dev/null 2>&1; then
    capture_titles=""
    for attempt in 1 2; do
        capture_titles="$(query_captures)"
        if [ -n "$capture_titles" ] || [ "$attempt" -eq 2 ]; then
            break
        fi
        sleep 1
    done

    if [ -n "$capture_titles" ]; then
        # Count of inbox total (separate query so we can show "5 of 28")
        total_inbox="$(sqlite3 -readonly "$CAPTURE_DB" \
            "SELECT COUNT(*) FROM items WHERE status='inbox'" 2>/dev/null)"
        total_inbox="${total_inbox:-?}"
        # Show first capture title; mention total
        first_title="$(printf '%s' "$capture_titles" | head -n 1)"
        CAPTURES_LINE="(${total_inbox} inbox) $(truncate_str "$first_title" 80)"
        CAPTURE_COUNT="$total_inbox"
    else
        # File exists but query returned nothing — could be empty or locked.
        # Try a meta query to distinguish.
        meta="$(sqlite3 -readonly "$CAPTURE_DB" "SELECT 1" 2>/dev/null)"
        if [ "$meta" = "1" ]; then
            CAPTURES_LINE="inbox empty"
        fi
        # else leave as "captures unavailable"
    fi
fi

# ---- TR backend: container up + last ingest timestamp ---------------------
TR_LINE="TR offline"

if [ "${TR_FORCE_OFFLINE:-0}" = "1" ]; then
    TR_LINE="TR offline (forced via TR_FORCE_OFFLINE)"
elif command -v docker >/dev/null 2>&1; then
    container_status="$(docker ps --filter "name=^${TR_CONTAINER}\$" --format '{{.Status}}' 2>/dev/null)"
    if [ -n "$container_status" ]; then
        # Container is up. Try to read last-ingest timestamp from host-mounted
        # volume. This may need sudo on some systems; fall through silently.
        vol_path="$(docker volume inspect "${TR_CONTAINER}-data" \
            --format '{{.Mountpoint}}' 2>/dev/null)"
        last_ts=""
        if [ -n "$vol_path" ] && [ -r "${vol_path}/index.sqlite" ]; then
            last_ts="$(sqlite3 -readonly "${vol_path}/index.sqlite" \
                "SELECT MAX(modified_at) FROM documents" 2>/dev/null)"
        fi
        if [ -n "$last_ts" ]; then
            # Compress to date+time only (drop ms)
            last_ts="$(printf '%s' "$last_ts" | sed -E 's/\.[0-9]+Z?$//')"
            TR_LINE="up (last ingest ${last_ts})"
        else
            TR_LINE="up (ingest timestamp unreadable)"
        fi
    fi
fi

# ---- emit briefing --------------------------------------------------------
# Format: 1 header + 5 body lines = 6 total. Stays well under 15.
printf 'TR Brief - %s\n' "$TODAY"
printf 'Last session: %s\n' "$LAST_SESSION_LINE"
printf 'In flight: %s%s\n' "$IN_FLIGHT_LINE" "$BEADS_SOURCE_LABEL"
printf 'Needs you: %s\n' "$NEEDS_YOU_LINE"
printf 'New captures: %s\n' "$CAPTURES_LINE"
printf 'Handoffs pending: %s | TR: %s\n' "$HANDOFF_COUNT" "$TR_LINE"

exit 0
