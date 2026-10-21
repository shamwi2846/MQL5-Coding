# mql5-coding v2: design

Status: draft for review. No skill code changes until this design is approved.

## 1. Summary

Rewrite the skill around four jobs: documentation-first answers, careful review, compilation and one Strategy Tester smoke run. One skill folder serves Claude Code and Codex. Everything else goes.

- v1 (the MQL5-Coding-Skill repository, v1.2.10): 41 files, about 11,300 lines, about 13,000 words of reference text.
- Target: 9 installed files, about 800 lines of code, about 2,500 words of text.

The threat model is an ordinary single-user Windows PC. The scripts protect against mistakes, stale builds, conflicting runs, unsafe terminal startup and accidental deletion. They do not try to defend against malicious local software or untrusted EAs.

## 2. What stays and what goes

Stays, because each item protects money or makes results trustworthy:

- MQL5 docs (the `mql5-chm` MCP) first, the exact "Not verified in the installed MQL5 CHM" fallback, citations.
- Classify before fixing; the review checklist; never silently change strategy, risk or order logic.
- MetaEditor quoting (`/compile:"path"`, never the whole token quoted).
- Success only from this run's "Result: N errors, M warnings" line plus a freshly written .ex5.
- The saved-account gate and its switch `-AcknowledgeSavedAccountRisk`.
- Refusing to start a terminal that is already running.
- Using the data folder MT5 really opens.
- `AllowLiveTrading=0` in the startup file.
- Deciding pass or fail from this run's journal lines.
- Stopping the whole process tree on timeout.

Goes:

| Removed | Why |
|---|---|
| Path-component handle locking, drive-remapping and reparse-point defenses (~2,000 lines) | Defends against a hostile local process, which is out of scope; it also blocks OneDrive and junction folders. |
| Compilation receipts and their validator | The tester compiles the source itself, or checks an explicit hash. |
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
| `references/compile.md` | Compile parameters, output, exit codes | ~50 |
| `references/strategy-tester.md` | Tester gates, settings, evidence, exit codes | ~90 |
| `scripts/Compile-Mql5.ps1` | Compile entrypoint | ~60 |
| `scripts/Invoke-Mt5TesterSmoke.ps1` | Tester entrypoint: parameters, then one call into `Mql5Common.ps1` | ~80 |
| `scripts/Mql5Common.ps1` | Installation discovery and validation, data-folder binding, account state, the compile and tester functions, result printing | ~520 |
| `scripts/OwnedProcess.cs` | Start suspended, put in a kill-on-close Job Object, resume, wait, kill, confirm empty, file identity | ~140 |
| `agents/openai.yaml` | Codex display name and MCP dependency; Claude ignores it | ~12 |
| `version.json` | Installed version, for humans | 1 |

Installed script total about 800 lines. The review rounds added safety steps, so this is the honest estimate.

In the repository, outside the installed folder, there is about 270 more lines of tooling: `install.ps1` (~70) and `tests/Test-Safety.ps1` (~200). The repository also holds one CI workflow, a short README and one nontrading test EA.

If clear code needs more lines, report the excess. Never weaken a safety gate to meet a number.

## 4. SKILL.md

Order and content, in short plain sentences:

1. **Scope.** MT5 and MQL5 only (EAs, indicators, scripts, services, libraries, `.mq5`, `.mqh`, `.ex5`); no MQL4. Scripts live in the `scripts` folder next to this file. Use the MCP tool names the client lists (Claude shows `mcp__mql5-chm__...`).
2. **Intent.** Review and explanation never edit. Diagnosis finds the evidenced cause and fixes only when asked. Changes are the smallest safe change. Never silently add or change entries, exits, stops, targets, sizing, retries, directions or position management. Never place live trades, move money or enter credentials.
3. **Docs first.** `mql5_chm_status` once per task; `mql5_chm_lookup_identifiers` for several names, `mql5_chm_search` for one; only exact matches count; read the passage with `section_id` or `focus`; reuse verified passages; cite title, topic id, section id, revision. Otherwise write exactly `Not verified in the installed MQL5 CHM`, then use and cite official MetaQuotes pages. Never fill gaps from memory. Logs describe the local run, not the API. If no `mql5_chm_*` tools are listed, say so and ask the user to enable or reload the MCP.
4. **Classify.** Compilation, initialization/runtime, indicators/timeseries, trade execution, tester/environment, strategy logic. State symptom, cause, impact and evidence separately.
5. **Review checklist.** Event lifecycle; handle creation, readiness, counts and release; buffer direction and completed bars; volume min/max/step; digits, tick size, stop and freeze levels; trade results; netting versus hedging; symbol/magic/direction ownership filters; nothing unrelated renamed or reformatted.
6. **Validate.** Compile every affected `.mq5`, including consumers of a changed `.mqh`. Read `references/compile.md` before compiling and `references/strategy-tester.md` before a tester run.
7. **Startup permission.** Pass `-AcknowledgeSavedAccountRisk` only with the user's explicit confirmation for this run, or a standing confirmation in the user's instructions that covers it. A general request to test is not confirmation. Ask again if the user adds a real-money account.
8. **Report.** Outcome first; files and behavior changed; evidenced cause; CHM citations; compile result with errors, warnings and artifact; tester settings, result and output folder; checks not run; remaining uncertainty. A smoke pass never implies profitability or live safety.

`references/` files hold only how to call the scripts and how to read their results. No history.

## 5. Compilation

**Command:** `Compile-Mql5.ps1 -SourcePath <file.mq5> [-IncludePath <MQL5 root>] [-MetaEditorPath <exe> | -TerminalPath <terminal64.exe>] [-TimeoutSeconds 120]`

**Choosing MetaEditor:**

- An explicit `-MetaEditorPath` wins.
- `-TerminalPath` selects the `metaeditor64.exe` next to it.
- Otherwise, collect MT5 installations from `METAEDITOR_EXE`, `C:\Program Files\MetaTrader 5`, and the install folders named in AppData `origin.txt` files, and drop duplicates.
- Use the installation only if exactly one is found. Otherwise list the candidates and ask for a path. Never take the first of several.
- Every selection, explicit or found, passes one validator before anything starts. The file must be named `metaeditor64.exe`, its version resource's `OriginalFilename` must be `metaeditor64.exe` (verified on build 6258), and its file major version must be 5. A selection that fails stops with exit 2 and has no fallback; that covers `terminal64.exe` given by mistake and a terminal copied under the editor's name. Compilation can therefore never start a terminal. The terminal validator mirrors this check with `terminal64.exe`.

**Steps:**

1. Require an existing `.mq5`. Reject any source, log or include path over 259 characters: MetaEditor silently does nothing at 276 (verified).
2. Use the `-IncludePath` given, or an `MQL5` ancestor folder of the source when there is one.
3. Take a named mutex, held until step 11 finishes, so two clients cannot compile the same output at once. Its key is the output folder's file identity plus the lower-case `.ex5` name, so a junction or short-path spelling of the same folder gets the same lock.
4. Create a temporary folder. Record the existing `.ex5` state: exists, last-write time, length and SHA-256. Copy the `.ex5` into the temporary folder and check that the copy's hash matches. Only a verified copy can be used as a restore source. If the copy fails, stop with exit 2 before MetaEditor starts and leave the original untouched.
5. Launch MetaEditor through `OwnedProcess` with `/compile:"<src>" /log:"<temp>\compile.log"` and `/include:"<root>"` when set. `/log:<path>` writes the log there (verified), so nothing extra lands next to the source.
6. Wait until the whole job is empty, MetaEditor and anything it started, within the deadline. On timeout, kill the job, confirm it is empty, and return 3. Nothing is read before the job is empty.
7. Read the UTF-16 log. Take the last `Result:` line. If there is no log or no `Result:` line, return 2.
8. Errors above zero return 1.
9. Zero errors still require a nonempty `.ex5` whose last-write time changed from step 4, or that is new. Otherwise return 2.
10. Hash the `.ex5` and print the result.
11. In `finally`, once the job is confirmed empty, handle any compile that did not succeed (exit 1, 2 or 3):
    - If an `.ex5` existed before and the current file is missing or differs from the saved copy, copy the saved one back.
    - If none existed before, delete any `.ex5` that is now present, since it is rejected output.
    - The restored file is never reported as this run's artifact.
    - If restoring fails, keep the temporary folder, print the backup's path and return 2.

    After any outcome, success included, delete the temporary folder, unless a restore failed.

**Restore:** MetaEditor build 6258 deletes the old `.ex5` on a failed compile (verified), and a timed-out compile can leave a partial file. Without the restore, a terminal that restarts later could lose an EA that was running from that file.

**Freshness:** this never relies on the restore. In the no-op case nothing is written, so there is no log and the run fails at step 7. The last-write check is a second guard.

**Facts used:** MetaEditor's exit code is ignored, because it was 1 on success and 0 on failure (verified). A command-line compile works while a MetaEditor window is open (verified), so there is no refusal for that.

**Output:** the full compiler log, then one line, `MQL5_RESULT {json}`. The JSON holds status, editor path and build, source, errors, warnings, the artifact path and SHA-256 (only on success), and exit code.

**Exit codes:**

| Exit | Meaning |
|---:|---|
| 0 | Fresh artifact accepted |
| 1 | Compile errors |
| 2 | Input or tool failure |
| 3 | Timeout, process tree stopped |

## 6. Strategy Tester smoke run

**Command:** `Invoke-Mt5TesterSmoke.ps1 (-Execute | -PreflightOnly) (-SourcePath <file.mq5> [-IncludePath ...] | -ExpertPath <file.ex5> -ExpectedExpertSha256 <hex>) -Symbol -Period -FromDate -ToDate -Model -Deposit -Currency -Leverage -ExecutionMode (-SetPath <file.set> | -UseExpertDefaults) -OutputDirectory <new folder> [-TerminalPath] [-TerminalDataPath] [-TimeoutSeconds 300] [-ExpectedLogMarker <MQL5_CODING_PASS:nonce>] [-AcknowledgeSavedAccountRisk]`

The script name, `-Execute`, `-PreflightOnly` and `-AcknowledgeSavedAccountRisk` stay the same as in v1. Standing instructions in a user's Claude or Codex instruction files that name them therefore keep working unchanged.

**Gates, in order. Each failure stops before anything is staged:**

1. **Inputs.** Validate every setting. Symbol, period and currency must hold no line breaks, `=`, `;` or path separators. Dates use `YYYY.MM.DD` with to after from. Exactly one EA input choice is allowed. Then claim the output folder by creating it with a create-only call that fails if it already exists. A run that cannot claim it stops with exit 2, so two runs never share an output folder.
2. **Terminal.** Take `-TerminalPath` if given. Otherwise use the unique installation, as for compilation. It must be `terminal64.exe` with major version 5.
3. **Data folder.** MT5 started with `/config` opens the AppData folder whose `origin.txt` (UTF-16) names its install folder. Exactly one such folder must exist. A given `-TerminalDataPath` must equal it. Zero matches, several matches or an unreadable `origin.txt` block the run.
4. **Lock.** Hold `<data>\.mql5-coding-smoke.data-lock`, created exclusively with delete-on-close, for the whole run. This keeps two clients from testing on one terminal. It is the same file name v1 uses, so an old and a new runner also exclude each other during migration.
5. **Saved account.** Check `<data>\config\accounts.dat`. Missing or empty means `none`, non-empty means `present`, unreadable means `unknown`. For `present` or `unknown`, `-Execute` requires `-AcknowledgeSavedAccountRisk`, else exit 4. The message explains that startup may log in to a saved, possibly live, account and resume Signals copying. The file is never read or printed.
6. **Already running.** Every running process whose image can be read is checked by file identity, whatever its file name: the volume serial number and file index of its image, compared with the selected `terminal64.exe`. A match blocks with exit 4, so a junction, hard-link or short-path alias of the same file cannot slip through. A process named `terminal64.exe` whose image cannot be read also blocks. The script never closes a process it did not start.
7. **Artifact.** In source mode, call the shared compile function with this terminal's `metaeditor64.exe`; anything but exit 0 stops here with exit 2. In prebuilt mode, the file's SHA-256 must equal `-ExpectedExpertSha256`.

`-PreflightOnly` runs gates 1–6 and reports the account state. It compiles nothing, stages nothing and launches nothing. Exit 0 means "ready", and the output says whether `-Execute` will need the acknowledgement.

**Run:**

1. Create a run id: `s` plus 10 random hex characters. The staged name is `<name>-<run-id>`.
   - The tester saves the last inputs used to `MQL5\Profiles\Tester\<expert name>.set`. A v1 smoke run, which staged the EA under its real name, was seen overwriting a user's saved preset this way. A unique staged name means the user's preset for the real EA is never touched.
   - Side effect: during the smoke run, `MQL_PROGRAM_NAME` is the staged name.
2. Copy the `.ex5` to `MQL5\Experts\Mql5Smoke\<staged>.ex5` and check the copy's hash. Create `Mql5Smoke` if it is missing, and note that this run created it.
3. Copy the `.set`, when one is given, to `MQL5\Profiles\Tester\<staged>.set`. This is the same file the tester's own auto-save writes, so the run owns exactly one preset file.
4. Write `<data>\<staged>.ini` with these settings:
   - `[Common]`: `NewsEnable=0`.
   - `[Experts]`: `AllowLiveTrading=0`, `AllowDllImport=0`.
   - `[Tester]`: `Expert=Mql5Smoke\<staged>`, then `ExpertParameters=<staged>.set` or an empty `[TesterInputs]` for the compiled defaults; symbol, period, model, execution mode, dates, `Optimization=0`, `ForwardMode=0`, `Report=<staged>`, `ReplaceReport=1`, `ShutdownTerminal=1`, deposit, currency, leverage, `UseLocal=1`, `UseRemote=0`, `UseCloud=0`, `Visual=0`.

   No login, password or server key is ever written. These keys do not stop Signals copying; that is what the account gate is for.
5. Record each journal file's length in `<data>\logs` and `<data>\Tester\logs`.
6. Right before launch, repeat gates 5 and 6. Compilation and staging take time, and an account may have been saved meanwhile.
7. Launch `terminal64.exe /config:"<ini>"` through `OwnedProcess` and wait for the deadline. On timeout, kill the job and confirm it is empty (exit 3). After a normal exit, do the same: kill any processes still in the job (such as a lingering tester agent) and confirm it is empty. Only then read evidence and clean up.

**Pass rules.** Read only the bytes appended to each journal since step 5. Files that are new since then (midnight rollover) are read whole. A file that got shorter is an evidence error (exit 2). Each line is tab-separated: code, level, time, source, message.

Records are classified as follows:

- A message that starts with a simulated `YYYY.MM.DD hh:mm:ss` timestamp is application output.
- A message of the form `name=value` is an echoed EA input and is ignored, so a string input can never look like a status record.
- Anything else is a system record.

All of these must hold:

- Terminal log, in order: `successfully initialized from start config "<our ini>"`, then `automatic testing started`, then `last test passed with result "successfully finished"`.
- Tester log: exactly one system test-start record (`testing of Experts\... started with inputs:`) for any expert in the appended evidence. It must start with `<symbol>,<period>: testing of Experts\Mql5Smoke\<staged>.ex5 from <from> 00:00 to <to> 00:00 started with inputs:`.
- After that record: a system record that starts with `<symbol>,<period>: ` and contains `Test passed in`.
- In both of those records, `<period>` is the journal's spelling of the period. The journal writes `D1` as `Daily`, seen in hundreds of real journal records. `W1` maps to `Weekly` and `MN1` to `Monthly`; those two spellings are confirmed in the real check. Minute and hour periods are spelled as given (`M1`, `H1`).
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
   - the tester cache files `Tester\cache\<staged>.*.tst`; the cache is keyed by expert name (verified), so these belong to this run alone
3. Remove `Mql5Smoke` only if this run created it and it is now empty. Never delete recursively, never touch the journals, and never touch any file whose name lacks the run id.

If the job could not be confirmed empty, leave the files in place and list them. Any cleanup failure turns the exit code into 2 and keeps the original outcome in the result.

**Output folder:** `result.json` (settings, terminal path and build, data folder, account state and acknowledgement, artifact path and hash, each check true/false, matched system lines, cleanup list, status, exit code), a copy of the `.ini`, and the report. The console prints a short summary and `MQL5_RESULT {json}`.

**Exit codes:**

| Exit | Meaning |
|---:|---|
| 0 | Smoke passed, or preflight ready |
| 1 | Ran, but a pass rule failed |
| 2 | Input, compile, tool, evidence or cleanup failure |
| 3 | Timeout, process tree stopped |
| 4 | Blocked by a safety gate before launch |

## 7. OwnedProcess.cs

One C# class, loaded with `Add-Type` and shared by compile and tester:

- `CreateProcessW` suspended, with no handle inheritance.
- `AssignProcessToJobObject` on a job with kill-on-close. If assignment fails, kill the suspended child, confirm it is gone, and fail.
- `ResumeThread`, `WaitForExit(ms)`, `TerminateJob`, `WaitForEmpty(ms)` (the job's active-process count is 0).
- `FileId(path)`: opens the file or folder for attributes only and returns the volume serial number plus file index from `GetFileInformationByHandle`. It is used by the running-terminal gate and the compile lock key.

This is the one piece of the old native code that is worth keeping. `taskkill /T` misses descendants whose parent already exited, such as tester agents.

## 8. Both clients: install and update

The same files go to both clients:

- `%USERPROFILE%\.claude\skills\mql5-coding`
- `%CODEX_HOME%\skills\mql5-coding` (default `%USERPROFILE%\.codex`)

`SKILL.md` has only `name` and `description` frontmatter. Scripts are found next to `SKILL.md`; no client path is hard-coded. `agents/openai.yaml` adds the Codex display name and the `mql5-chm` dependency. In Codex, the scripts need permission to start processes, either through full access or through the client's approval prompt, to launch MetaEditor and the terminal.

`install.ps1 [-Client Claude|Codex|Both]`, default `Both`, run from a reviewed checkout:

0. Resolve the destinations:
   - Claude: `%CLAUDE_CONFIG_DIR%\skills\mql5-coding` when that variable is set, else `%USERPROFILE%\.claude\skills\mql5-coding`.
   - Codex: `%CODEX_HOME%\skills\mql5-coding` when set, else `%USERPROFILE%\.codex\skills\mql5-coding`.
   - All later steps use these resolved paths.
1. Back up the current installed folder to `%LOCALAPPDATA%\mql5-coding\backups\<client>-<timestamp>`. The backup must not go under `skills`: a copy there would load as a second `mql5-coding` skill.
2. Copy the new files over the installed folder, then delete installed files that are not in the new set. It does not rename the root folder, because an open client may hold it.
3. Compare every installed file's hash to the checkout and report per client.

If a step fails, run it again. The backup allows a manual restore. There are no downloads, GitHub calls, manifests or MCP changes. The script ends with: restart the client so new chats load the skill.

## 9. Migration

- **New repository.** v2 lives in this repository, `MQL5-Coding`. The installed skill keeps its name, `mql5-coding`, so both clients and any standing instructions find it as before.
- **The old repository stays as it is.** `MQL5-Coding-Skill` remains unchanged at v1.2.10 as the fallback, so nothing has to be deleted there. The MQL5 CHM MCP repository has a compatibility workflow that reads the old repository; it keeps working because the old repository does not change. Pointing that workflow at this repository, or retiring it, is a separate change that needs the user's OK.
- **Installing.** Install v2 into both clients with this repository's `install.ps1`. It replaces the v1 files in both installed copies, including every obsolete script.
- **Standing instructions.** These may name `Invoke-Mt5TesterSmoke.ps1 -Execute` and `-AcknowledgeSavedAccountRisk`, and both names survive. Wording that mentions v1-only features, such as project-profile or scenario-batch runs, becomes stale; update it with the user's OK.
- **Removed parameters.** They fail with a clear message naming the replacement: `-CompilationReceiptPath` points to `-SourcePath`, and `-ExpectedLogMarkerFile` points to `-ExpectedLogMarker`.
- **Leftovers from v1.** New staging uses `Mql5Smoke`. v1 left its `CodexSmoke` staging files, reports and compile receipts in place. v2 does not touch them; cleaning them is a separate job that needs the user's OK.
- **Versions.** Use git tags, starting at `v2.0.0`.

## 10. Tests

At most five automated cases, all in `tests/Test-Safety.ps1`, plain PowerShell with no framework. They run on both PowerShell 5.1 and 7 in one Windows CI workflow, with no MT5 and no credentials:

1. **Saved account:**
   - `present` and `unknown` block `-Execute` (exit 4) without the switch; `none` passes. Nothing is staged when blocked.
   - A fake compiler that creates a non-empty `accounts.dat` mid-run is still blocked by the recheck before launch, with no terminal started and no staging left.
2. **Terminal gates and containment:**
   - A running fake terminal blocks (exit 4) when started through its real path and when started through a hard link with a different file name.
   - Zero, several or mismatched `origin.txt` folders block.
   - A fake terminal that spawns a child and never exits is timed out (exit 3), and both processes are gone before cleanup runs.
3. **Startup ini and editor selection:**
   - The ini has `AllowLiveTrading=0`, no `Login`, `Password` or `Server`, and an empty `[TesterInputs]` for defaults.
   - A symbol containing a line break or `=` is rejected.
   - `-MetaEditorPath` pointing at a terminal fake returns exit 2, and nothing starts.
   - A terminal fake named `metaeditor64.exe` but carrying terminal metadata returns exit 2 with nothing started, whether selected explicitly or found automatically.
4. **Stale artifact:**
   - A fake editor that writes no log returns 2 and never stages. So does one that writes a valid UTF-16 `Result: 0 errors, 0 warnings` line but leaves the `.ex5` untouched.
   - Two restore cases: a failed compile that deletes the old `.ex5`, and a fake that overwrites it with partial bytes and hangs until timed out. Both end with the original bytes restored, no artifact reported, and every owned process stopped.
   - A fake editor that exits after starting a child that writes the log and `.ex5` later is waited for. The result is read only after the child ends.
   - A prebuilt `.ex5` whose hash differs from `-ExpectedExpertSha256` returns 2 before anything is staged or launched.
5. **Cleanup and journal:**
   - After a fake run, only files carrying the run id are gone.
   - A user's `<name>.set` sentinel keeps its exact bytes, and a user file in the same folders survives.
   - A tester log with a second test-start record fails.
   - An echoed input `x=tester stopped because OnInit returns non-zero` does not change the result.

**Fakes.** They are tiny console programs built with the Windows .NET Framework `csc.exe`, the method v1's tests used; PowerShell 7's `Add-Type` cannot build executables (verified). They stand in for `metaeditor64.exe` and `terminal64.exe` and carry matching `OriginalFilename` metadata. They run in a temporary folder tree that mimics an install plus an AppData data folder.

**Test root.** The entrypoint scripts have no AppData parameter and always use the real `%APPDATA%`. The tester and compile logic live in functions in `Mql5Common.ps1`, and the tests dot-source it and call those functions with a test root. So a production run can never be pointed at an empty fake account store.

**Real check before release:** on a PC with MT5 (build 6258 at design time), compile and run the nontrading test EA from a folder whose path has spaces, with a fresh marker, in both Claude Code and Codex. Confirm the following, and record the build, settings and result:

- pass status
- the staging gone
- no new files next to the source
- the report copied

Repeat after any terminal upgrade.

## 11. Decisions and open points

- **Kept GPT's advice:** source mode compiles with the terminal's own MetaEditor; the script and switch names stay; a small Job Object helper stays; portable mode is only a later option (under Program Files it needs admin rights and UAC off).
- **Freshness:** decided against GPT's move-aside-and-require-absence. The run's own temporary log plus the last-write check prove freshness.
- **The old `.ex5`:** a hash-verified copy is kept. After any unsuccessful compile, it is restored if the `.ex5` went missing or changed (review finding).
- **Unique staged names instead of unique folders:** these protect the user's saved tester presets, which v1 could overwrite (review finding, verified on a real preset).
- **Journal checks:** decided against prefix hashing. Only one terminal of this install can run, and that run's id is in every path it logs.
- **Test count:** decided against GPT's larger test matrix. The five cases above are the ways to lose money or data; the real check covers the rest.
- **Leverage format (open):** the docs show `Leverage=1:100`; v1 writes `Leverage=100` and passed many real runs. Keep the proven form and confirm in the real check that the report shows the requested leverage.
- **CI against MT5 (open):** none. Hosted CI has no MT5. The real check is manual and recorded.
- **Script size (gap, LOW):** about 800 installed lines plus about 270 lines of repository tooling, so about 1,070 in total against a rough 800 target. Recheck the real size during implementation.
