# mql5-coding v2: design

Status: final draft. No skill code changes until this design is approved.

## 1. Summary

Rewrite the skill around four jobs: documentation-first answers, careful review, compilation and one Strategy Tester smoke run. One skill folder serves Claude Code and Codex. Everything else goes.

- v1 (the MQL5-Coding-Skill repository, v1.2.10): 41 files, about 11,300 lines, about 13,000 words of reference text.
- Target: 10 installed files, about 730 lines of installed code, about 2,500 words of text.

The skill is built for a test PC: no real-money accounts and no live trading. Compiling, backtesting and using any MT5 terminal or account on that PC need no confirmation. The scripts protect against mistakes, stale builds, conflicting runs and accidental deletion of the user's files. They do not try to defend against malicious local software or untrusted EAs, and they do not guard live accounts. The README says so for anyone who installs the public skill.

## 2. What stays and what goes

Stays, because each item makes results correct or protects the user's files:

- MQL5 docs (the `mql5-chm` MCP) first, the exact "Not verified in the installed MQL5 CHM" fallback, citations.
- Classify before fixing; read the evidence before diagnosing; the review checklist; never silently change strategy, risk or order logic.
- MetaEditor quoting (`/compile:"path"`, never the whole token quoted).
- Success only from this run's "Result: N errors, M warnings" line plus a freshly written .ex5.
- Testing only the exact build this run compiled.
- Refusing to start a terminal that is already running: MT5 cannot run two copies from one folder.
- Using the data folder MT5 really opens.
- `AllowLiveTrading=0`, `AllowDllImport=0`, `Optimization=0`, `UseCloud=0` in the startup file.
- Unique staged names, so the user's saved tester presets are never overwritten.
- Deciding pass or fail from this run's journal lines.
- Stopping the whole process tree on timeout.
- Each run removing its own staging files.

Goes:

| Removed | Why |
|---|---|
| Path-component handle locking, drive-remapping and reparse-point defenses (~2,000 lines) | Defends against a hostile local process, which is out of scope; it also blocks OneDrive and junction folders. |
| Saved-account gate and `-AcknowledgeSavedAccountRisk` | The skill is built for a test PC with no real accounts; the user wants no confirmation. The README warns other users. |
| Compilation receipts and the prebuilt `.ex5` mode (`-ExpertPath`, `-ExpectedExpertSha256`) | The tester always compiles the source itself. A vendor `.ex5` can be tested in MT5's own tester. |
| `-TerminalDataPath` | The data folder is always derived from `origin.txt`; the parameter could only produce a mismatch error. |
| Backup and restore of the old `.ex5` around a compile | It is a build file; the source is untouched, and MetaEditor deletes it on a failed compile just as the editor does. |
| Alias-proof checks: file-identity matching of process images and lock keys, `OriginalFilename` checks | Guard against junction or hard-link tricks that do not happen on a test PC. Plain path checks remain. |
| Second native C# helper and duplicate discovery code | One small shared helper. |
| Python toolkit and its `~/.codex` environment | No required job needs Python; unused in practice. |
| Project profiles, source snapshots, scenario batches, journal grouping | Unused in practice. |
| Marker files and marker lists | One optional marker covers the self-test case. |
| Generic journal redaction | Only a few matched system lines are kept, and they hold no account data. |
| `-SyntaxOnly`, `-WarningsAsErrors` | Success always means a real artifact; the report shows warnings and the model decides. |
| Verified GitHub updater, release manifests, rollback journal | A reviewed checkout plus a copy is enough for a personal skill. |
| Environment health checker | The tester's preflight checks local tools; the chat's tool list shows whether the MCP loaded. |
| Changelog-style references, focused-review, performance and refactoring notes | Their useful lines move into `SKILL.md`. |

## 3. Installed files

| File | Job | Lines |
|---|---|---:|
| `SKILL.md` | Instructions for both clients | ~95 |
| `references/compile.md` | Compile parameters, output, exit codes | ~45 |
| `references/strategy-tester.md` | Tester gates, settings, evidence, notes, exit codes | ~90 |
| `scripts/Compile-Mql5.ps1` | Compile entrypoint: parameters, then one call into `Mql5Compile.ps1` | ~50 |
| `scripts/Invoke-Mt5TesterSmoke.ps1` | Tester entrypoint: parameters, then one call into `Mql5Tester.ps1` | ~70 |
| `scripts/Mql5Compile.ps1` | Installation discovery and validators, the compile function | ~200 |
| `scripts/Mql5Tester.ps1` | Data-folder binding, running check, staging, launch, journal rules, cleanup; loads `Mql5Compile.ps1` | ~300 |
| `scripts/OwnedProcess.cs` | Start suspended, put in a kill-on-close Job Object, resume, wait, kill, confirm empty | ~110 |
| `agents/openai.yaml` | Codex display name and MCP dependency; Claude ignores it | ~12 |
| `version.json` | Installed version, for humans | 1 |

The dependency is one-way: the tester library loads the compile library, never the reverse. The native helper is loaded once. Result printing stays in the entrypoints.

Installed script total: about 730 lines.

In the repository, outside the installed folder:

- `install.ps1` (~70 lines) and `tests/Test-Safety.ps1` with its fake programs (~250 lines), so about 1,050 lines in all.
- One CI workflow, a short README and one nontrading test EA.

These are estimates, not acceptance criteria. Measure the implementation, and never weaken a check to meet a number.

## 4. SKILL.md

Frontmatter description, short and discriminating:

> Write, review, explain, debug, compile and backtest MetaTrader 5 MQL5 programs (Expert Advisors, indicators, scripts, services, libraries; .mq5, .mqh, .ex5) on Windows, checking MQL5 facts in the mql5-chm docs first. Not for MQL4 or MetaTrader 4.

Body, in short plain sentences:

1. **Scope.** MT5 and MQL5 only; no MQL4. Scripts live in the `scripts` folder next to this file. Use the MCP tool names the client lists (Claude shows `mcp__mql5-chm__...`).
2. **Intent.** Review and explanation never edit. Diagnosis finds the evidenced cause and fixes only when asked. Changes are the smallest safe change. Never silently add or change entries, exits, stops, targets, sizing, retries, directions or position management. Never place trades outside the Strategy Tester (demo accounts included), move money or enter credentials.
3. **Docs first.**
   - Call `mql5_chm_status` once per task.
   - Use `mql5_chm_lookup_identifiers` for several names and `mql5_chm_search` for one. Only exact matches count.
   - Read the passage with `section_id` or `focus`, and reuse a verified passage instead of reading it again.
   - Cite the title, topic id, section id and revision.
   - When the docs cannot support a claim, write exactly `Not verified in the installed MQL5 CHM`, then use and cite official MetaQuotes pages. Never fill gaps from memory.
   - If no `mql5_chm_*` tools are listed, say so and carry on with the official pages, using the same exact phrase for API facts; a missing MCP does not stall review work.
   - Logs describe the local run, not the API.
4. **Evidence and classification.** Read the compiler log and the terminal, tester and Expert journals before diagnosing a runtime problem. When they are missing, report that gap instead of presenting a source-based guess as the cause. Classify the problem as one of: compilation, initialization/runtime, indicators/timeseries, trade execution, tester/environment, strategy logic. State symptom, cause, impact and evidence separately.
5. **Review checklist.** Event lifecycle; handle creation, readiness, counts and release; buffer direction and completed bars; volume min/max/step; digits, tick size, stop and freeze levels; trade results; netting versus hedging; symbol/magic/direction ownership filters; nothing unrelated renamed or reformatted.
6. **Validate.** Compile every affected `.mq5`, including consumers of a changed `.mqh`. Read `references/compile.md` before compiling and `references/strategy-tester.md` before a tester run. Compiling a file inside a running terminal's `MQL5` folder makes that terminal reload any chart running it (`REASON_RECOMPILE`).
7. **Testing.**
   - Never run an `.ex5` the user did not build or vouch for. Building it here does not make it trustworthy: the EA runs with the tester agent's file and network access.
   - Pass markers go only in a separate test EA. Never edit the user's EA just to test it, unless the user asks or it already has a self-test. A user's EA gets the plain engine smoke test.
   - If the selected terminal is already running, the tester refuses. Close it when the user's instructions allow; otherwise ask.
8. **Report.** Outcome first; files and behavior changed; evidenced cause; CHM citations; compile result with errors, warnings and artifact; tester settings, result and output folder; checks not run; remaining uncertainty. A smoke pass never implies profitability or live safety.

`references/` files hold only how to call the scripts and how to read their results. No history.

## 5. Compilation

**Command:** `Compile-Mql5.ps1 -SourcePath <file.mq5> [-IncludePath <MQL5 root>] [-MetaEditorPath <exe> | -TerminalPath <terminal64.exe>] [-TimeoutSeconds 120]`

**Choosing MetaEditor:**

- An explicit `-MetaEditorPath` wins.
- `-TerminalPath` selects the `metaeditor64.exe` next to it.
- Otherwise, collect MT5 installations from these sources and drop duplicates:
  - `METAEDITOR_EXE`
  - `C:\Program Files\MetaTrader 5`
  - the install folders named in AppData `origin.txt` files
- Use the installation only if exactly one is found. Otherwise list the candidates and ask for a path. Never take the first of several.
- Every selection, explicit or found, must be a file named `metaeditor64.exe` with file major version 5, checked before anything starts. A selection that fails stops with exit 2 and has no fallback, so compilation can never start a terminal by mistake.

**Steps:**

1. Require an existing `.mq5`. Reject any source, log or include path over 259 characters: MetaEditor silently does nothing at 276 (verified).
2. Use the `-IncludePath` given, or an `MQL5` ancestor folder of the source when there is one.
3. Take a named mutex keyed by the lower-case full path of the output `.ex5`, held until step 11 finishes. Two clients therefore never compile the same output at once.
4. Create a temporary folder and record the existing `.ex5` state: exists, last-write time, length.
5. Launch MetaEditor through `OwnedProcess` with `/compile:"<src>" /log:"<temp>\compile.log"`, plus `/include:"<root>"` when set. `/log:<path>` writes the log there (verified), so nothing extra lands next to the source.
6. Wait until the whole job is empty, MetaEditor and anything it started, within the deadline. On timeout, kill the job, confirm it is empty, and return 3. Nothing is read before the job is empty.
7. Read the UTF-16 log and take the last `Result:` line. With no log or no `Result:` line, return 2.
8. Errors above zero return 1.
9. Zero errors still require a nonempty `.ex5` whose last-write time changed from step 4, or that is new. Otherwise return 2.
10. Hash the `.ex5`, print the result, and return the hash to a calling tester.
11. In `finally`, once the job is confirmed empty, delete the temporary folder. If the job cannot be confirmed empty, the step fails closed: it reports no artifact, keeps the temporary folder, prints the process IDs still running, and returns 2. The `.ex5` at the output path is then untrusted, and the tester never uses it, because it tests only the hash its own compile accepted.

**Freshness:** in the do-nothing case MetaEditor writes nothing, so there is no log and step 7 fails. The last-write check in step 9 is a second guard. A failed compile deletes the old `.ex5` (verified), just as compiling in the editor does; the source is never touched.

**Facts used:** MetaEditor's exit code is ignored, because it was 1 on success and 0 on failure (verified). A command-line compile works while a MetaEditor window is open (verified).

**Output:** the full compiler log, then one line, `MQL5_RESULT {json}`. The JSON holds status, editor path and build, source, errors, warnings, the artifact path and SHA-256 (only on success), and exit code.

**Exit codes:**

| Exit | Meaning |
|---:|---|
| 0 | Fresh artifact accepted |
| 1 | Compile errors |
| 2 | Input or tool failure |
| 3 | Timeout, process tree stopped |

## 6. Strategy Tester smoke run

**Command:** `Invoke-Mt5TesterSmoke.ps1 (-Execute | -PreflightOnly) -SourcePath <file.mq5> [-IncludePath ...] -Symbol -Period -FromDate -ToDate -Model -Deposit -Currency -Leverage -ExecutionMode (-SetPath <file.set> | -UseExpertDefaults) -OutputDirectory <new folder> [-TerminalPath] [-TimeoutSeconds 300] [-ExpectedLogMarker <MQL5_CODING_PASS:nonce>]`

The script name, `-Execute` and `-PreflightOnly` stay as in v1. Tests always start from source: the tester compiles it with the terminal's own `metaeditor64.exe`.

**Gates, in order. Each failure stops before anything is staged:**

1. **Inputs.** Validate every setting.
   - Symbol, period and currency must hold no line breaks, `=`, `;` or path separators.
   - Dates use `YYYY.MM.DD`, with to after from.
   - Exactly one EA input choice is allowed.
   - The output folder must not exist, and its parent must be writable.
2. **Terminal.** Take `-TerminalPath` if given; otherwise use the unique installation, as for compilation. It must be a file named `terminal64.exe` with major version 5.
3. **Data folder.** MT5 started with `/config` opens the AppData folder whose `origin.txt` (UTF-16) names its install folder. Exactly one such folder must exist. Zero matches, several matches or an unreadable `origin.txt` block the run.
4. **Already running.** Any `terminal64.exe` process whose image path equals the selected terminal's full path (case-insensitive) blocks with exit 4. So does a `terminal64.exe` process whose path cannot be read. The script never closes a process; the model closes the terminal when the user's instructions allow, then reruns.

`-PreflightOnly` runs gates 1–4 and creates nothing. Exit 0 means "ready". Its output lists what it did not check: compilation, staging and launch.

**Run (`-Execute`):**

1. Claim the output folder with a create-only call that fails if it already exists; failure stops with exit 2, so two runs never share an output folder. Hold `<data>\.mql5-coding-smoke.data-lock`, created exclusively with delete-on-close, for the whole run. It is the same file name v1 uses, so old and new runners exclude each other.
2. Compile the source through the shared compile function with this terminal's `metaeditor64.exe`. Anything but exit 0 stops here with exit 2. Keep the hash the compile returned.
3. Create a run id: `s` plus 10 random hex characters. The staged name is `<name>-<run-id>`. The tester saves the last inputs used to `MQL5\Profiles\Tester\<expert name>.set`; a v1 run, staged under the real name, was seen overwriting a user's preset this way. A unique staged name leaves the user's presets alone.
4. Copy the `.ex5` to `MQL5\Experts\Mql5Smoke\<staged>.ex5`. The copy's hash must equal the hash from step 2, otherwise stop with exit 2. Create `Mql5Smoke` if it is missing, and note that this run created it.
5. Copy the `.set`, when one is given, to `MQL5\Profiles\Tester\<staged>.set`. This is the same file the tester's own auto-save writes, so the run owns exactly one preset file.
6. Write `<data>\<staged>.ini` with these settings:
   - `[Common]`: `NewsEnable=0`.
   - `[Experts]`: `AllowLiveTrading=0`, `AllowDllImport=0`.
   - `[Tester]`:
     - `Expert=Mql5Smoke\<staged>`, then `ExpertParameters=<staged>.set`, or an empty `[TesterInputs]` for the compiled defaults.
     - The requested symbol, period, model, execution mode, dates, deposit, currency and leverage.
     - Fixed values: `Optimization=0`, `ForwardMode=0`, `Report=<staged>`, `ReplaceReport=1`, `ShutdownTerminal=1`, `UseLocal=1`, `UseRemote=0`, `UseCloud=0`, `Visual=0`.

   No login, password or server key is ever written.
7. Record each journal file's length in `<data>\logs` and `<data>\Tester\logs`.
8. Repeat gate 4 right before launch.
9. Launch `terminal64.exe /config:"<ini>"` through `OwnedProcess` and wait for the deadline.
   - On timeout, kill the job and confirm it is empty (exit 3).
   - After a normal exit, do the same: kill any processes still in the job, such as a lingering tester agent, and confirm it is empty.
   - Only then read evidence and clean up.

**Pass rules.** Read only the bytes appended to each journal since run step 7. Files that are new since then (midnight rollover) are read whole. A file that got shorter is an evidence error (exit 2). Each line is tab-separated: code, level, time, source, message.

Records are classified as follows:

- A message that starts with a simulated `YYYY.MM.DD hh:mm:ss` timestamp is application output.
- A message of the form `name=value` is an echoed EA input and is ignored, so a string input can never look like a status record.
- Anything else is a system record.

All of these must hold:

- Terminal log, in order: `successfully initialized from start config "<our ini>"`, then `automatic testing started`, then `last test passed with result "successfully finished"`.
- Tester log: exactly one system test-start record (`testing of Experts\... started with inputs:`) for any expert in the appended evidence. It must start with `<symbol>,<period>: testing of Experts\Mql5Smoke\<staged>.ex5 from <from> 00:00 to <to> 00:00 started with inputs:`.
- After that record: a system record that starts with `<symbol>,<period>: ` and contains `Test passed in`.
- In both of those records, `<period>` uses the journal's spelling. The journal writes `D1` as `Daily`, seen in hundreds of real journal records. `W1` maps to `Weekly` and `MN1` to `Monthly`; those two are confirmed in the real check. Minute and hour periods are spelled as given (`M1`, `H1`).
- No system record containing `tester stopped because OnInit returns non-zero`.
- With `-ExpectedLogMarker`: an application line whose message after the timestamp is exactly the marker. It must come after the test-start record and before the pass record.
- The terminal exited by itself before the deadline.

The run id sits in both the ini path and the expert path, and the lock plus the running check keep other terminals of this install out. So the appended lines belong to this run. No time-window logic is needed.

**Result status:**

- Pass without a marker is `engine_smoke_passed`.
- Pass with a marker is `application_marker_passed`.
- Neither proves strategy correctness, profitability or full-date coverage.
- A report file or terminal exit code 0 alone never counts as a pass.

**Cleanup:** it runs in `finally`, after the job is confirmed empty.

1. Copy `<staged>.htm` and its companions (`.png`, `-hst.png`, `-mfemae.png`, `-holding.png`, names verified on real runs) to the output folder.
   - Delete each original only after its copy's hash matches.
   - A report that could not be copied stays where it is, is listed in the result, and makes the exit code 2.
   - The other cleanup steps still run.
2. Delete, by literal path, only the files this run created:
   - the staged `.ex5`
   - `MQL5\Profiles\Tester\<staged>.set`
   - the `.ini`
   - the reports and companions already copied in step 1
   - the tester cache files `Tester\cache\<staged>.*.tst`. The cache is keyed by expert name (verified), so these belong to this run alone.
3. Remove `Mql5Smoke` only if this run created it and it is now empty.

Never delete recursively, never touch the journals, and never touch any file whose name lacks the run id. If the job could not be confirmed empty, leave the files in place and list them. Any cleanup failure turns the exit code into 2 and keeps the original outcome in the result.

**What a run leaves behind:**

- A run blocked before the output folder is claimed leaves nothing; the reason is printed.
- Otherwise the output folder holds:
  - `result.json` with settings, terminal path and build, data folder, artifact path and hash, each check true/false, matched system lines, cleanup list, status and exit code;
  - a copy of the `.ini`;
  - any copied reports.
- Anything kept for recovery, such as uncopied reports or files left because the job could not be confirmed empty, is listed by path in `result.json` and left where it is. It is never deleted to tidy up.

The console prints a short summary and `MQL5_RESULT {json}`.

**Notes for `references/strategy-tester.md`:**

- During a smoke run the EA's `MQL_PROGRAM_NAME` is the staged name `<name>-<run-id>`. An EA that checks its own name, for example for licensing or for file and global-variable prefixes, behaves differently.
- Only the `.ex5` is copied, so libraries and `MQL5\Files` data the EA needs must already be in the selected terminal.
- The default timeout is 300 seconds. A first run on a new symbol or date range may need longer while history synchronizes; raise `-TimeoutSeconds` rather than retrying blindly.
- Do not open the selected terminal by hand during a run. The running check is only a point-in-time observation.
- Recommended setup for people who keep a terminal open: a second MT5 install used only for testing, selected with `-TerminalPath`. Installing outside Program Files does not by itself make it portable, so the AppData binding still applies. Start it once normally and log in to a demo account, so `origin.txt` and history exist.

**Exit codes:**

| Exit | Meaning |
|---:|---|
| 0 | Smoke passed, or preflight ready |
| 1 | Ran, but a pass rule failed |
| 2 | Input, compile, tool, evidence or cleanup failure |
| 3 | Timeout, process tree stopped |
| 4 | Blocked by a gate before launch |

## 7. OwnedProcess.cs

One C# class, loaded once with `Add-Type` and shared by compile and tester:

- `CreateProcessW` suspended, with no handle inheritance.
- `AssignProcessToJobObject` on a job with kill-on-close. If assignment fails, kill the suspended child, confirm it is gone, and fail.
- `ResumeThread`, `WaitForExit(ms)`, `TerminateJob`, `WaitForEmpty(ms)` (the job's active-process count is 0).

This is the one piece of the old native code that is worth keeping. `taskkill /T` misses descendants whose parent already exited, such as tester agents.

## 8. Both clients: install and update

The same files go to both clients:

- `%USERPROFILE%\.claude\skills\mql5-coding`
- `%CODEX_HOME%\skills\mql5-coding` (default `%USERPROFILE%\.codex`)

`SKILL.md` has only `name` and `description` frontmatter. Scripts are found next to `SKILL.md`; no client path is hard-coded. `agents/openai.yaml` adds the Codex display name and the `mql5-chm` dependency. In Codex, the scripts need permission to start processes, either full access or the client's approval prompt, to launch MetaEditor and the terminal.

`install.ps1 [-Client Claude|Codex|Both]`, default `Both`, runs from a reviewed checkout:

0. Resolve the destinations:
   - Claude: `%CLAUDE_CONFIG_DIR%\skills\mql5-coding` when that variable is set, else `%USERPROFILE%\.claude\skills\mql5-coding`.
   - Codex: `%CODEX_HOME%\skills\mql5-coding` when set, else `%USERPROFILE%\.codex\skills\mql5-coding`.
   - All later steps use these resolved paths.
1. Back up the current installed folder to `%LOCALAPPDATA%\mql5-coding\backups\<client>-<timestamp>`. The backup must not go under `skills`, where it would load as a second `mql5-coding` skill.
2. Copy the new files over the installed folder, then delete installed files that are not in the new set. The root folder is not renamed, because an open client may hold it.
3. Compare every installed file's hash to the checkout and report per client.

If a step fails, run it again; the backup allows a manual restore. There are no downloads, GitHub calls, manifests or MCP changes. The script ends with: restart the client so new chats load the skill.

## 9. Migration

- **New repository.** v2 lives in this repository, `MQL5-Coding`. The installed skill keeps its name, `mql5-coding`, so both clients find it as before.
- **The old repository stays as it is.** `MQL5-Coding-Skill` remains at v1.2.10 as the fallback. The MQL5 CHM MCP repository has a compatibility workflow that reads it, and that keeps working because nothing there changes. Pointing that workflow at this repository, or retiring it, is a separate change that needs the user's OK.
- **Installing.** Install v2 into both clients with this repository's `install.ps1`. It replaces the v1 files in both installed copies, including every obsolete script.
- **Standing instructions.** The user's Claude `CLAUDE.md` and Codex `AGENTS.md` hold an MT5 standing-confirmation block that names `Invoke-Mt5TesterSmoke.ps1 -Execute` and `-AcknowledgeSavedAccountRisk`. v1 needs that block until v2 is installed. At install time, and with the user's OK, replace it in both files with one line: "This PC is a test environment: compile, backtest and use any MT5 terminal or account without asking. Never place trades outside the Strategy Tester (demo accounts included), move money or enter credentials."
- **Removed parameters.** They fail with a clear message naming what replaces them:
  - `-CompilationReceiptPath`, `-ExpertPath` and `-ExpectedExpertSha256` → `-SourcePath`
  - `-ExpectedLogMarkerFile` → `-ExpectedLogMarker`
  - `-TerminalDataPath` → derived automatically
  - `-AcknowledgeSavedAccountRisk` → no longer needed
- **README.** Say that the skill is built for test PCs and starts MT5 with whatever account is saved there.
- **Leftovers from v1.** New staging uses `Mql5Smoke`. v1 left its `CodexSmoke` staging files, reports and compile receipts in place. v2 does not touch them. Cleaning them is a separate job; prefer sending them to the Recycle Bin.
- **Versions.** Use git tags, starting at `v2.0.0`.

## 10. Tests

Four groups in `tests/Test-Safety.ps1`, plain PowerShell with no framework. They run on PowerShell 5.1 and 7 in one Windows CI workflow, with no MT5 and no credentials:

1. **Terminal gates and containment:**
   - A running fake terminal at the selected path blocks with exit 4 before anything is staged.
   - Zero or several `origin.txt` folders for the install block.
   - A fake terminal that spawns a child and never exits is timed out with exit 3, and both processes are gone before cleanup runs.
2. **Startup ini and editor selection:**
   - The ini has `AllowLiveTrading=0`, `AllowDllImport=0`, `Optimization=0` and `UseCloud=0`.
   - It has no `Login`, `Password` or `Server` key, and an empty `[TesterInputs]` for defaults.
   - A symbol containing a line break or `=` is rejected.
   - `-MetaEditorPath` pointing at a terminal fake returns exit 2, and nothing starts.
3. **Stale artifact:**
   - A fake editor that writes no log returns 2 and never stages. So does one that writes a valid UTF-16 `Result: 0 errors, 0 warnings` line but leaves the `.ex5` untouched.
   - A fake editor that exits after starting a child that writes the log and `.ex5` later is waited for. The result is read only after the child ends.
   - A staged copy whose hash differs from the compile's hash stops the run with exit 2.
4. **Cleanup and journal:**
   - After a fake run, only files carrying the run id are gone.
   - A user's `<name>.set` sentinel keeps its exact bytes, and a user file in the same folders survives.
   - A staged report held open by another process cannot be copied. It stays in place, is listed in `result.json` and gives exit 2, and the other owned files are still removed.
   - Each of these fails the run (exit 1):
     - a tester log with a second test-start record;
     - a real `tester stopped because OnInit returns non-zero` system record;
     - a required marker that never appears.
   - An echoed input `x=tester stopped because OnInit returns non-zero` does not change the result.

**Fakes:** tiny console programs built with the Windows .NET Framework `csc.exe`, the method v1's tests used. PowerShell 7's `Add-Type` cannot build executables (verified). They stand in for `metaeditor64.exe` and `terminal64.exe` in a temporary folder tree that mimics an install plus an AppData data folder.

**Test root:** the entrypoint scripts have no AppData parameter and always use the real `%APPDATA%`. The compile and tester logic live in functions in `Mql5Compile.ps1` and `Mql5Tester.ps1`; the tests dot-source them and call those functions with a test root, so the tests never touch the real AppData.

**Real check before release:** on a PC with MT5 (build 6258 at design time), compile and run the nontrading test EA from a folder whose path has spaces, with a fresh marker, in both Claude Code and Codex. Confirm and record:

- the pass status
- the staging gone
- no new files next to the source
- the report copied
- the build, settings and result
- `W1` and `MN1` journal spellings, and that the report shows the requested leverage
- whether `[Experts]` in the terminal's `config\common.ini` is the same before and after the run, which checks whether startup keys persist

Repeat after any terminal upgrade.

## 11. Decisions and open points

**Test-PC scope (user decision, 2026-10-20).** The PC is a test environment with no real accounts, money or live trading, and the user wants no confirmations. These were therefore dropped:

- the saved-account gate and its switch
- the live-reload compile guard (Fable 5.1's finding stays as a SKILL.md note)
- the `.ex5` backup and restore
- the alias-proof file-identity checks and the `OriginalFilename` check
- the pre-launch account recheck
- the terminal-scoped standing confirmation

**Adopted from GPT and Fable 5.1:**

- compile-to-stage hash binding
- a preflight that creates nothing and lists what it did not check
- source-only testing
- dropping `-TerminalDataPath`
- splitting the shared script by job
- the SKILL.md lines on untrusted EAs, test-only markers, evidence before diagnosis and the docs fallback
- the frontmatter description
- the tester notes (program name, dependencies, timeout, manual launch, test-terminal setup)
- the ini assertions for optimization and the cloud

**Decided against:**

- a larger matrix of recovery-failure tests, because those failures cannot really be produced and the tests would only test the fakes
- dropping the compile lock, because it is under ten lines and stops two clients compiling the same output at once

**Kept from earlier reviews:**

- source mode compiles with the terminal's own MetaEditor
- the script name and `-Execute`/`-PreflightOnly` stay
- a small Job Object helper
- unique staged names
- the v1-compatible lock file
- freshness from this run's own temporary log plus the last-write check
- prefix hashing of journals was not needed

**Open, to confirm in the real check:**

- the leverage format: the docs show `Leverage=1:100`, while v1 writes `Leverage=100` and passed many real runs, so keep the proven form and confirm the report shows the requested value
- the `W1`/`MN1` spellings
- whether startup keys persist

**CI against MT5:** none. Hosted CI has no MT5; the real check is manual and recorded.

**Size:** about 730 installed lines plus about 320 lines of repository tooling, around 1,050 in total. This is a provisional estimate, not a limit.
