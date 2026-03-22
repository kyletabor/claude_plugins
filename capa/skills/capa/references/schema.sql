-- CAPA Database Schema
-- Location: ~/.claude/capa/capa.db
-- Pattern: Append-only changelog (Ramsey pattern — upsert, never delete)

CREATE TABLE IF NOT EXISTS capa_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  trigger_description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'investigating', 'researching', 'designing', 'implementing', 'verifying', 're-executing', 'closed')),
  severity TEXT CHECK (severity IN ('critical', 'high', 'medium', 'low')),
  category TEXT CHECK (category IN (
    'spec_error',        -- spec targeted wrong thing
    'skill_not_invoked', -- skill existed but wasn't used
    'enforcement_gap',   -- no mechanism forced compliance
    'testing_gap',       -- tests didn't verify reality
    'verification_skip', -- "done" claimed without proof
    'data_path_error',   -- code targeted wrong data flow
    'delegation_failure',-- handoff lost context or requirements
    'other'
  )),
  trigger_session TEXT,          -- session ID or reference where failure was detected
  defect_fixed BOOLEAN DEFAULT 0,  -- was the original defect ultimately fixed?
  process_fixed BOOLEAN DEFAULT 0, -- was the process actually improved?
  created_at TEXT DEFAULT (datetime('now')),
  closed_at TEXT,
  outcome TEXT                   -- summary of what changed
);

CREATE TABLE IF NOT EXISTS root_causes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  capa_id INTEGER NOT NULL REFERENCES capa_records(id),
  description TEXT NOT NULL,
  skill_that_failed TEXT,        -- which skill/gate should have caught this
  why_it_failed TEXT,            -- why the skill/gate didn't fire
  category TEXT CHECK (category IN (
    'spec_written_from_memory',  -- spec didn't verify current state
    'wrong_code_path',           -- targeted dead/legacy code
    'mock_tested_not_real',      -- tests mocked the thing being tested
    'tests_never_ran',           -- tests in wrong dir or never executed
    'self_reported_verification',-- builder verified their own work
    'skill_not_available',       -- skill exists in wrong environment
    'skill_not_enforced',        -- skill available but not mandatory
    'no_acceptance_criteria',    -- success defined in prose not code
    'speed_over_correctness',    -- rushed implementation
    'other'
  )),
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS research_findings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  capa_id INTEGER NOT NULL REFERENCES capa_records(id),
  source_type TEXT NOT NULL CHECK (source_type IN (
    'perplexity',    -- external web research
    'github',        -- GitHub patterns/issues
    'memory',        -- Kyle's memory/preferences
    'article',       -- shared article or doc
    'previous_capa', -- pattern from past CAPA
    'skill_review',  -- review of existing skill gaps
    'other'
  )),
  finding TEXT NOT NULL,
  citation TEXT,                 -- URL, memory ID, or file path
  applied BOOLEAN DEFAULT 0     -- was this finding used in the fix?
);

CREATE TABLE IF NOT EXISTS process_changes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  capa_id INTEGER NOT NULL REFERENCES capa_records(id),
  change_type TEXT NOT NULL CHECK (change_type IN (
    'new_skill',
    'modified_skill',
    'new_gate',
    'new_enforcement',
    'config_change',
    'db_schema_change',
    'documentation',
    'other'
  )),
  description TEXT NOT NULL,
  files_changed TEXT,            -- JSON array of file paths
  verified BOOLEAN DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now'))
);

-- Append-only event log (Ramsey changelog pattern)
CREATE TABLE IF NOT EXISTS changelog (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  capa_id INTEGER REFERENCES capa_records(id),
  timestamp TEXT DEFAULT (datetime('now')),
  phase TEXT CHECK (phase IN (
    'detect', 'investigate', 'research', 'design',
    'implement', 'verify', 're-execute', 'close'
  )),
  action TEXT NOT NULL,
  details TEXT
);

-- Views for quick analysis

CREATE VIEW IF NOT EXISTS capa_summary AS
SELECT
  r.id,
  r.title,
  r.status,
  r.severity,
  r.category,
  r.created_at,
  r.closed_at,
  COUNT(DISTINCT rc.id) as root_cause_count,
  COUNT(DISTINCT pc.id) as process_change_count,
  r.process_fixed,
  r.defect_fixed
FROM capa_records r
LEFT JOIN root_causes rc ON rc.capa_id = r.id
LEFT JOIN process_changes pc ON pc.capa_id = r.id
GROUP BY r.id
ORDER BY r.created_at DESC;

CREATE VIEW IF NOT EXISTS recurring_patterns AS
SELECT
  rc.category,
  COUNT(*) as occurrence_count,
  GROUP_CONCAT(DISTINCT rc.skill_that_failed) as skills_involved,
  GROUP_CONCAT(DISTINCT r.title, ' | ') as capa_titles
FROM root_causes rc
JOIN capa_records r ON r.id = rc.capa_id
GROUP BY rc.category
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;

CREATE VIEW IF NOT EXISTS category_stats AS
SELECT
  category,
  COUNT(*) as total,
  SUM(CASE WHEN status = 'closed' THEN 1 ELSE 0 END) as closed,
  SUM(CASE WHEN process_fixed = 1 THEN 1 ELSE 0 END) as process_fixed,
  SUM(CASE WHEN defect_fixed = 1 THEN 1 ELSE 0 END) as defect_fixed,
  ROUND(AVG(JULIANDAY(closed_at) - JULIANDAY(created_at)), 1) as avg_days_to_close
FROM capa_records
GROUP BY category
ORDER BY total DESC;

CREATE VIEW IF NOT EXISTS effectiveness AS
SELECT
  pc.change_type,
  pc.description,
  r.title as capa_title,
  pc.verified,
  r.defect_fixed,
  r.process_fixed
FROM process_changes pc
JOIN capa_records r ON r.id = pc.capa_id
ORDER BY pc.created_at DESC;
