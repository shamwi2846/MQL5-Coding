# Known gaps

Findings left unfixed on purpose. Entries are never deleted, only marked fixed.

## G1 · open · 2026-10-21 · LOW
- Task: -
- Where: docs/design.md
- Problem: All scripts together come to about 1,490 lines against the roughly-800 target in R8. Measured at v2.0.0: 971 installed script lines plus 521 for the installer, tests and fakes.
- Trigger: -
- Fix: -
- Log: recorded by hand
- Why skipped: Trimming would cut correctness checks or tests that protect the user's files; the estimate is provisional. The growth came from review fixes and their regression tests: atomic output claim, result-file failures, installer path and hidden-file handling, bracketed paths and input anchors.

## G2 · fixed · 2026-10-21 · MEDIUM
- Task: Implement the mql5-coding v2 skill from docs/design.md (new repository shamwi2846/MQL5-Coding)
- Where: -
- Problem: F3: Record the required real checks before release
- Trigger: The implementation is assessed for release using the frozen files and supplied evidence.
- Fix: Add the required real-check results to Notes. If Codex is permission-blocked, record that failure and the Claude-first release decision.
- Log: 20261021121726-9c5e32
- Why skipped: Fixed with G7: the real-check record is in docs/design.md section 10 ("Real check record, v2.0.0"), which also lists the Codex side as still to do under the Claude-first decision.

## G3 · fixed · 2026-10-21 · LOW
- Task: Implement the mql5-coding v2 skill from docs/design.md (new repository shamwi2846/MQL5-Coding)
- Where: skills/mql5-coding/scripts/Mql5Compile.ps1:175-178
- Problem: F4: Preserve the compile folder when containment is unconfirmed
- Trigger: The post-termination WaitForEmpty returns false during a tester's compilation.
- Fix: Return whether the compile job was confirmed empty. Have Save-CompileEvidence retain and record the temporary folder when it was not.
- Log: 20261021121726-9c5e32
- Why skipped: pair: confirmed by B

## G4 · fixed · 2026-10-21 · LOW
- Task: Implement the mql5-coding v2 skill from docs/design.md (new repository shamwi2846/MQL5-Coding)
- Where: skills/mql5-coding/scripts/OwnedProcess.cs:116-123
- Problem: F5: Confirm termination after job assignment fails
- Trigger: AssignProcessToJobObject fails, such as under an incompatible enclosing job restriction.
- Fix: Check termination and wait results before closing the handles; include the PID and containment failure when termination cannot be confirmed.
- Log: 20261021121726-9c5e32
- Why skipped: pair: confirmed by B

## G5 · fixed · 2026-10-21 · LOW
- Task: Implement the mql5-coding v2 skill from docs/design.md (new repository shamwi2846/MQL5-Coding)
- Where: skills/mql5-coding/scripts/Mql5Compile.ps1:57-65
- Problem: F6: Use the required tester exit code for terminal-selection gates
- Trigger: The tester finds zero or several terminal candidates, or its selected terminal fails executable validation.
- Fix: Translate terminal-selection failures to exit 4 in the tester while retaining exit 2 for compiler selection.
- Log: 20261021121726-9c5e32
- Why skipped: pair: confirmed by B

## G6 · fixed · 2026-10-21 · LOW
- Task: Implement the mql5-coding v2 skill from docs/design.md (new repository shamwi2846/MQL5-Coding)
- Where: tests/Test-Safety.ps1:188-191
- Problem: F8: Cover cleanup failure through the public tester
- Trigger: A report cannot be moved during cleanup.
- Fix: Add an end-to-end fake run with a report-move failure and assert exit 2, the preserved primary outcome, and cleanup.left in result.json.
- Log: 20261021121726-9c5e32
- Why skipped: pair: confirmed by A

## G7 · fixed · 2026-10-21 · MEDIUM
- Task: Implement the mql5-coding v2 skill from docs/design.md (new repository shamwi2846/MQL5-Coding)
- Where: docs/design.md:426-437
- Problem: F2: Record the required real checks before release
- Trigger: The implementation is assessed for release using the frozen project and supplied evidence.
- Fix: Add Notes recording the required real-check outcomes, settings, artifacts, cleanup, startup-key comparison and shell timings. If Codex is permission-blocked, record that failure and the agreed Claude-first release decision.
- Log: 20261021124511-852c9d
- Why skipped: pair: both

## G8 · fixed · 2026-10-21 · LOW
- Task: Implement the mql5-coding v2 skill from docs/design.md (new repository shamwi2846/MQL5-Coding)
- Where: install.ps1:45-49
- Problem: F4: Include hidden entries in installation cleanup
- Trigger: An existing installed skill contains an obsolete file or directory with the Windows Hidden attribute.
- Fix: Include hidden content in backups and recursive inventories using -Force, and use -Force when removing empty hidden directories. Include hidden entries in the inventory test.
- Log: 20261021124511-852c9d
- Why skipped: pair: confirmed by B

## G9 · fixed · 2026-10-21 · LOW
- Task: Implement the mql5-coding v2 skill from docs/design.md (new repository shamwi2846/MQL5-Coding)
- Where: KNOWN_GAPS.md:14-21
- Problem: F1: Mark the duplicate real-check gap fixed
- Trigger: A maintainer checks open gaps before release.
- Fix: Mark G2 fixed and reference G7 and the existing real-check record.
- Log: 20261021130614-d183b5
- Why skipped: pair: confirmed by A
