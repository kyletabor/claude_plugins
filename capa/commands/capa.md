---
name: capa
description: "Start a Corrective and Preventive Action investigation. Fixes broken processes first, then uses the fixed process to fix the original defect."
arguments:
  - name: description
    description: "What's broken — describe the failure, the feature that doesn't work, or the process that failed"
    required: true
---

Invoke the `capa` skill with the following context:

**Trigger:** The user has identified something that isn't working right and wants to investigate why the process failed, fix the process, and then re-execute.

**Description:** $ARGUMENTS

Start at Phase 1 (DETECT). Create the CAPA record in the database immediately.
