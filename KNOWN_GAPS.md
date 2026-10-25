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

## G10 · open · 2026-10-22 · LOW
- Task: -
- Where: tests/fakes/FakeTerminal.cs:72
- Problem: CodeRabbit (PR 6): File.Move of the PID file would throw if FAKE_PIDS already existed.
- Trigger: -
- Fix: -
- Log: recorded by hand
- Why skipped: Cannot happen in the suite: every run builds a fresh temporary fixture and the two hang-mode tests use different PID file names; a replace branch would be code for a case that does not occur.

## G11 · fixed · 2026-10-22 · LOW
- Task: Point the mql5-coding skill at the MQL5 Docs MCP
- Where: docs/design.md:582
- Problem: F1: Remove the remaining retired lookup procedure
- Trigger: A maintainer follows the token-budget section's current documentation lookup rules.
- Fix: Replace the obsolete procedure and lean-argument claims with a reference to the server's tool descriptions and instructions.
- Log: 20261022102929-904171
- Why skipped: labelled GAP by the reviewer; harm: The design still directs readers to an obsolete procedure that the new server does not support.

## G12 · fixed · 2026-10-23 · LOW
- Task: Implement the mql5-coding v2 skill from docs/design.md (new repository shamwi2846/MQL5-Coding)
- Where: docs/design.md:96
- Problem: F1: Align the design’s citation rule with the revised skill
- Trigger: A maintainer rebuilds or checks SKILL.md against design section 4, as R1 directs.
- Fix: Update the design’s citation bullet to require page titles and give page IDs only when asked.
- Log: 20261023000324-63557c
- Why skipped: pair: both

## G13 · fixed · 2026-10-23 · MEDIUM
- Task: Implement the mql5-coding v2 skill from docs/design.md (new repository shamwi2846/MQL5-Coding)
- Where: -
- Problem: F2: R12 is PARTIAL
- Trigger: the task as asked
- Fix: -
- Log: 20261023000324-63557c
- Why skipped: pair: disputed by A: skills/mql5-coding/scripts/Mql5Tester.ps1:400 implements the lock ordering; skills/mql5-coding/scripts/Mql5Compile.ps1:119 implements .NET hashing; skills/mql5-coding/version.json:1 specifies 2.1.1. Pending merge, reinstall and tagging are release-status limitations, not a reachable failure causing the concrete harm required for a BUG.

## G14 · fixed · 2026-10-23 · MEDIUM
- Task: Implement the mql5-coding v2 skill from docs/design.md (new repository shamwi2846/MQL5-Coding)
- Where: -
- Problem: F1: R12 is PARTIAL
- Trigger: the task as asked
- Fix: -
- Log: 20261023001301-8cd3ed
- Why skipped: all R12 code, docs and tests are implemented and acknowledged; what remains are the post-review release steps (commit, PR, merge when green, reinstall into both clients, tag v2.1.1), which cannot precede the review and are done next.

## G15 · open · 2026-10-23 · LOW
- Task: -
- Where: skills/mql5-coding/scripts/Mql5Compile.ps1:121
- Problem: CodeRabbit (PR 8): if File.Open throws, the SHA256 provider in Get-FileSha256 is not disposed explicitly.
- Trigger: -
- Fix: -
- Log: recorded by hand
- Why skipped: No harm: each compile or tester call is a short-lived process, so the provider is released when it ends; a locked file already fails the hash as tested. Not worth another change to reviewed code.

## G16 · fixed · 2026-10-23 · LOW
- Task: Point the mql5-coding skill at the MQL5 Docs MCP
- Where: skills/mql5-coding/SKILL.md:27
- Problem: F1: Citations give page ids only when asked, while an earlier task note (its requirement R4, not part of this repository) asked for them every time
- Trigger: -
- Fix: none needed: page ids only when asked is the current rule on purpose (see G12 and PR #8: answers under a no-internal-ids chat rule were dropping the page entirely); the earlier task note is superseded
- Log: 20261023004453-1a38db
- Why skipped: not a gap; closed so it matches the rule G12 records

## G17 · fixed · 2026-10-23 · LOW
- Task: Implement the mql5-coding v2 skill from docs/design.md (new repository shamwi2846/MQL5-Coding)
- Where: skills/mql5-coding/version.json:1
- Problem: F1: Record the changed release target
- Trigger: Preparing the release requested by R13, which names v2.1.2.
- Fix: Record in Notes that v2.1.2 was already released and this fix will ship as v2.1.3, then tag the fix accordingly.
- Log: 20261023180355-814060
- Why skipped: pair: confirmed by B

## G18 · fixed · 2026-10-23 · LOW
- Task: Implement the mql5-coding v2 skill from docs/design.md (new repository shamwi2846/MQL5-Coding)
- Where: skills/mql5-coding/version.json:1
- Problem: F1: Record why the release target changed to 2.1.3
- Trigger: Preparing this fix for release under R13, which specifies v2.1.2.
- Fix: Add a Notes entry explaining that v2.1.2 already exists and this fix will ship as v2.1.3.
- Log: 20261023181359-1a8d52
- Why skipped: labelled GAP by the reviewer; harm: The release metadata and authoritative release requirement disagree without an explanation in Notes.

## G19 · open · 2026-10-23 · LOW
- Task: -
- Where: skills/mql5-coding/references/strategy-tester.md:47
- Problem: CodeRabbit (PR 10): treat a /config terminal as another test run only when its ini matches this skill's staging; otherwise close it.
- Trigger: -
- Fix: -
- Log: recorded by hand
- Why skipped: Declined: since 2.1.1 this skill's own runs show as the held run lock, never as 'already running', so a /config terminal behind 'already running' is always another runner (for example a project's own test runner). Closing it would interrupt that run; waiting is the safe default.

## G20 · fixed · 2026-10-24 · LOW
- Task: Implement the mql5-coding v2 skill from docs/design.md (new repository shamwi2846/MQL5-Coding)
- Where: skills/mql5-coding/scripts/Mql5Tester.ps1:122-130
- Problem: F2: Check all process paths before reporting a busy terminal
- Trigger: Get-Process returns the running selected terminal before another terminal whose Path cannot be read.
- Fix: Remember the selected running process, finish checking every process path, then report busy only if all paths were readable.
- Log: 20261024235205-515631
- Why skipped: pair: both

## G21 · fixed · 2026-10-24 · LOW
- Task: Implement the mql5-coding v2 skill from docs/design.md (new repository shamwi2846/MQL5-Coding)
- Where: skills/mql5-coding/references/strategy-tester.md:47
- Problem: F3: Include waiting time in the client timeout guidance
- Trigger: Follow the recommended -WaitSeconds 900 example and give the client call a timeout slightly longer than the default -TimeoutSeconds 300.
- Fix: Tell callers to allow WaitSeconds plus TimeoutSeconds, with additional time for compilation and cleanup, or use a background command.
- Log: 20261024235205-515631
- Why skipped: pair: confirmed by B
