-- CAPA Database Quick Queries
-- Usage: sqlite3 ~/.claude/capa/capa.db < query.sql
-- Or inline: sqlite3 ~/.claude/capa/capa.db "SELECT ..."

-- ============================================================
-- LISTING & STATUS
-- ============================================================

-- List all CAPAs (most recent first)
-- sqlite3 -header -column ~/.claude/capa/capa.db "SELECT * FROM capa_summary"

-- Open CAPAs only
-- sqlite3 -header -column ~/.claude/capa/capa.db "SELECT * FROM capa_summary WHERE status != 'closed'"

-- ============================================================
-- STATISTICS
-- ============================================================

-- Category breakdown
-- sqlite3 -header -column ~/.claude/capa/capa.db "SELECT * FROM category_stats"

-- Recurring root cause patterns (shows which failures keep happening)
-- sqlite3 -header -column ~/.claude/capa/capa.db "SELECT * FROM recurring_patterns"

-- Effectiveness of process changes
-- sqlite3 -header -column ~/.claude/capa/capa.db "SELECT * FROM effectiveness"

-- Overall stats
-- sqlite3 -header -column ~/.claude/capa/capa.db "
--   SELECT
--     COUNT(*) as total_capas,
--     SUM(CASE WHEN status = 'closed' THEN 1 ELSE 0 END) as closed,
--     SUM(CASE WHEN status != 'closed' THEN 1 ELSE 0 END) as open,
--     SUM(CASE WHEN process_fixed = 1 THEN 1 ELSE 0 END) as process_fixed,
--     SUM(CASE WHEN defect_fixed = 1 THEN 1 ELSE 0 END) as defect_fixed,
--     ROUND(AVG(CASE WHEN closed_at IS NOT NULL
--       THEN JULIANDAY(closed_at) - JULIANDAY(created_at) END), 1) as avg_days
--   FROM capa_records
-- "

-- ============================================================
-- ROOT CAUSE ANALYSIS
-- ============================================================

-- Most common root cause categories across all CAPAs
-- sqlite3 -header -column ~/.claude/capa/capa.db "
--   SELECT category, COUNT(*) as count,
--     GROUP_CONCAT(DISTINCT skill_that_failed) as failed_skills
--   FROM root_causes GROUP BY category ORDER BY count DESC
-- "

-- Skills that fail most often (which skills aren't working?)
-- sqlite3 -header -column ~/.claude/capa/capa.db "
--   SELECT skill_that_failed, COUNT(*) as fail_count,
--     GROUP_CONCAT(DISTINCT category) as failure_modes
--   FROM root_causes
--   WHERE skill_that_failed IS NOT NULL
--   GROUP BY skill_that_failed ORDER BY fail_count DESC
-- "

-- Full root cause detail for a specific CAPA
-- sqlite3 -header -column ~/.claude/capa/capa.db "
--   SELECT rc.*, r.title as capa_title
--   FROM root_causes rc JOIN capa_records r ON r.id = rc.capa_id
--   WHERE rc.capa_id = ?
-- "

-- ============================================================
-- RESEARCH & LEARNING
-- ============================================================

-- Applied vs unapplied research findings
-- sqlite3 -header -column ~/.claude/capa/capa.db "
--   SELECT source_type, COUNT(*) as total,
--     SUM(applied) as applied, SUM(1-applied) as not_applied
--   FROM research_findings GROUP BY source_type
-- "

-- ============================================================
-- CHANGELOG (audit trail)
-- ============================================================

-- Full changelog for a CAPA
-- sqlite3 -header -column ~/.claude/capa/capa.db "
--   SELECT * FROM changelog WHERE capa_id = ? ORDER BY timestamp
-- "

-- Recent activity across all CAPAs
-- sqlite3 -header -column ~/.claude/capa/capa.db "
--   SELECT c.*, r.title FROM changelog c
--   LEFT JOIN capa_records r ON r.id = c.capa_id
--   ORDER BY c.timestamp DESC LIMIT 20
-- "
