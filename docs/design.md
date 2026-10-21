# mql5-coding v2: design

Status: final draft. No skill code changes until this design is approved.

## 1. Summary

Rewrite the skill around four jobs: documentation-first answers, careful review, compilation and one Strategy Tester smoke run. One skill folder serves Claude Code and Codex. Everything else goes.

- v1 (the MQL5-Coding-Skill repository, v1.2.10): 41 files, about 11,300 lines, about 13,000 words of reference text.
- Target: 10 installed files, about 755 lines of installed code, about 2,000 words of text.

The skill is built for a test PC: no real-money accounts and no live trading. Compiling, backtesting and using any MT5 terminal or account on that PC need no confirmation. The scripts protect against mistakes, stale builds, conflicting runs and accidental deletion of the user's files. The one exception is deliberate: a failed compile can delete the existing `.ex5` build output, just as compiling in MetaEditor does. The source is never touched, and the `.ex5` is rebuilt by the next successful compile. The scripts do not try to defend against malicious local software or untrusted EAs, and they do not guard live accounts. The README says so for anyone who installs the public skill.

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
| Preflight mode (`-PreflightOnly`, `-Execute`) | With no confirmations, a run's own gates stop it before anything is staged. |
| Generic journal redaction | Only the matched system lines, up to 20 error lines and up to 10 context records per failed check are kept, in a local `result.json` on a test PC. |
| `-SyntaxOnly`, `-WarningsAsErrors` | Success always means a real artifact; the report shows warnings and the model decides. |
| Verified GitHub updater, release manifests, rollback journal | A reviewed checkout plus a copy is enough for a personal skill. |
| Environment health checker | Each script checks its own tools before it starts; the chat's tool list shows whether the MCP loaded. |
| Changelog-style references, focused-review, performance and refactoring notes | Their useful lines move into `SKILL.md`. |

## 3. Installed files

| File | Job | Lines |
|---|---|---:|
| `SKILL.md` | Instructions for both clients | ~95 |
| `references/compile.md` | How to call compile: arguments, output fields, exit codes | ~25 |
| `references/strategy-tester.md` | How to call the tester: arguments, summary and `result.json` fields, exit codes, notes, bounded reading | ~60 |
| `scripts/Compile-Mql5.ps1` | Compile entrypoint: parameters, then one call into `Mql5Compile.ps1` | ~50 |
| `scripts/Invoke-Mt5TesterSmoke.ps1` | Tester entrypoint: parameters, then one call into `Mql5Tester.ps1` | ~60 |
| `scripts/Mql5Compile.ps1` | Installation discovery and validators, the compile function, keeping the log when anything was cut or a tool failure hit | ~210 |
| `scripts/Mql5Tester.ps1` | Data-folder binding, running check, default settings, staging, launch, journal rules, the summary line, headline values, error lines and failure context, cleanup; loads `Mql5Compile.ps1` | ~325 |
| `scripts/OwnedProcess.cs` | Start suspended, put in a kill-on-close Job Object, resume, wait, kill, confirm empty | ~110 |
| `agents/openai.yaml` | Codex display name and MCP dependency; Claude ignores it | ~12 |
| `version.json` | Installed version, for humans | 1 |

The dependency is one-way: the tester library loads the compile library, never the reverse. The native helper is loaded once. Result printing stays in the entrypoints.

The guides document every call as `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File <script> ...`:
- `-NoProfile` stops a heavy user profile slowing each call, and `-NonInteractive` stops anything waiting for input.
- `powershell.exe` is Windows PowerShell 5.1. It is always installed, and it measured faster here: about 0.3 s to start and 0.4 s for `Add-Type`, against 0.42 s and 1.0 s for PowerShell 7. The scripts also run under PowerShell 7.

Installed script total: about 755 lines.

In the repository, outside the installed folder:

- `install.ps1` (~70 lines) and `tests/Test-Safety.ps1` with its fake programs (~260 lines), so about 1,085 lines in all.
- One CI workflow, a short README and one nontrading test EA.

These are estimates, not acceptance criteria. Measure the implementation, and never weaken a check to meet a number.

## 4. SKILL.md

Frontmatter description, short and discriminating, with full trigger coverage:

> Write, review, explain, debug, compile and backtest MetaTrader 5 MQL5 code (EAs, indicators, scripts, services, libraries; .mq5/.mqh/.ex5) on Windows, checking MQL5 facts in the mql5-chm docs first. Not MQL4/MT4.

Body, in short plain sentences. Everything a pure review needs stays here; tester procedures live in the tester guide.

1. **Scope.** MT5 and MQL5 only; no MQL4. Scripts live in the `scripts` folder next to this file. Use the MCP tool names the client lists (Claude shows `mcp__mql5-chm__...`).
2. **Intent.** Review and explanation never edit. Diagnosis finds the evidenced cause and fixes only when asked. Changes are the smallest safe change. Never silently add or change entries, exits, stops, targets, sizing, retries, directions or position management. Never place trades outside the Strategy Tester (demo accounts included), move money or enter credentials.
3. **Docs first.**
   - **Status.** Before the first MQL5 fact in a task, call `mql5_chm_status` once.
   - **Lookups.** For several names, make one `mql5_chm_lookup_identifiers` call with `source: "mql5"` and `limit: 1`. For one name, use `mql5_chm_search` with `source: "mql5"`, `limit: 1` and `expand: false`. Only an exact match whose passage contains the identifier as a whole token counts; approximate matches never do.
   - **Reads.** Use `mql5_chm_read` with `section_id` or `focus`, `max_chars` of 1500–3000, `include_related: false` and `include_images: false`. Follow `next_cursor` when the passage does not yet settle the claim; a small first excerpt is never a reason to stop.
   - **Reuse.** Keep a verified passage and never read it twice.
   - **Citations.** Give the title, topic id and section id, plus the revision once per answer.
   - **Fallback.** When the docs cannot support a claim, write exactly `Not verified in the installed MQL5 CHM`, then use and cite official MetaQuotes pages. Never fill gaps from memory. If no `mql5_chm_*` tools are listed, say so and carry on with the official pages, using the same exact phrase for API facts; a missing MCP does not stall review work.
   - **Logs.** They describe the local run, not the API.
4. **Evidence and classification.** Read the compiler log and the journals before diagnosing a runtime problem. When they are missing, report that gap instead of presenting a source-based guess as the cause. Classify the problem as one of: compilation, initialization/runtime, indicators/timeseries, trade execution, tester/environment, strategy logic. State symptom, cause, impact and evidence separately.
5. **Review checklist.** Event lifecycle; handle creation, readiness, counts and release; buffer direction and completed bars; volume min/max/step; digits, tick size, stop and freeze levels; trade results; netting versus hedging; symbol/magic/direction ownership filters; nothing unrelated renamed or reformatted.
6. **Validate.**
   - Compile every affected `.mq5`, including consumers of a changed `.mqh`.
     - Find them by searching the project for the include's file name. Repeat the search for each header that includes it, until every `.mq5` at the end of the chain is found.
     - Report any consumer you could not resolve.
   - When the task also needs a test, call the tester directly for the EA under test: it compiles that source itself, so do not compile it separately first. Compile every other affected `.mq5`, including indirect consumers, separately.
   - Recompile only after a change to the source, an include or another build input. Reuse files already read and run results until their inputs change.
   - Read only the guide for the script you call, once per task. `references/strategy-tester.md` covers a test, including its compile-result fields. Read `references/compile.md` only when calling `Compile-Mql5.ps1` on its own.
   - Compiling a file inside a running terminal's `MQL5` folder makes that terminal reload any chart running it (`REASON_RECOMPILE`).
7. **Testing.**
   - The tester runs Expert Advisors only. Indicators, scripts and services are validated by compiling.
   - Never run an `.ex5` the user did not build or vouch for. Building it here does not make it trustworthy: the EA runs with the tester agent's file and network access.
   - Pass markers go only in a separate test EA. Never edit the user's EA just to test it, unless the user asks or it already has a self-test. A user's EA gets the plain engine smoke test.
   - Use the tester's summary line first. Open `result.json` only when the summary is not enough. Never read a report or journal file whole: a report is about 500 KB, roughly 130,000 tokens. The tester guide gives the bounded way to get more.
   - If the selected terminal is already running, the tester refuses. When the user's instructions allow, close it gracefully and rerun; otherwise ask. The tester guide says how.
8. **Report.** Outcome first; files and behavior changed; evidenced cause; CHM citations; compile result with errors, warnings and artifact; tester settings, result and output folder; checks not run; remaining uncertainty. A smoke pass never implies profitability or live safety.

`references/` files are invocation and result guides only: arguments, defaults, exit codes, output fields and the caveats a caller needs. Mechanics stay in this design document. No history.

`references/strategy-tester.md` also holds the bounded-reading rules:
- For one more report value, extract just that cell with a regex capture and print the capture, never the matching line, which can be the whole file.
- For journals, read only this run's byte range from `result.json`, in chunks of at most 8 KB.

## 5. Compilation

**Command:** `Compile-Mql5.ps1 -SourcePath <file.mq5> [-IncludePath <MQL5 root>] [-MetaEditorPath <exe> | -TerminalPath <terminal64.exe>] [-TimeoutSeconds 120]`

**Choosing MetaEditor:**

- An explicit `-MetaEditorPath` wins.
- `-TerminalPath` selects the `metaeditor64.exe` next to it.
- Otherwise, collect MT5 installations from these sources and drop duplicates:
  - `METAEDITOR_EXE`
  - `C:\Program Files\MetaTrader 5`
  - the install folders named in AppData `origin.txt` files
- Use the installation only if exactly one is found. Otherwise stop with exit 2 and list the candidates, so the model can pass a path. Never take the first of several.
- Every selection, explicit or found, must be a file named `metaeditor64.exe` with file major version 5, checked before anything starts. A selection that fails stops with exit 2 and has no fallback, so compilation can never start a terminal by mistake.

**Steps:**

1. Require an existing `.mq5`. Reject any source, log or include path over 259 characters: MetaEditor silently does nothing at 276 (verified).
2. Use the `-IncludePath` given, or an `MQL5` ancestor folder of the source when there is one.
3. Take a named mutex, held until step 11 finishes, so two clients never compile the same output at once. Windows object names cannot contain backslashes, so the name is `Global\mql5-compile-` plus the first 24 hex characters of the SHA-256 of the output `.ex5`'s lower-case full path, as v1 did.
4. Create a temporary folder and record the existing `.ex5` state: exists, last-write time, length.
5. Launch MetaEditor through `OwnedProcess` with `/compile:"<src>" /log:"<temp>\compile.log"`, plus `/include:"<root>"` when set. `/log:<path>` writes the log there (verified), so nothing extra lands next to the source.
6. Wait until the whole job is empty, MetaEditor and anything it started, within the deadline. On timeout, kill the job, confirm it is empty, and return 3. Nothing is read before the job is empty.
7. Read the UTF-16 log and take the last `Result:` line. With no log or no `Result:` line, return 2.
8. Errors above zero return 1.
9. Zero errors still require a nonempty `.ex5` whose last-write time changed from step 4, or that is new. Otherwise return 2.
10. Hash the `.ex5`, print the result, and return the hash to a calling tester.
11. In `finally`, once the job is confirmed empty:
    - Delete the temporary folder only after a success or an ordinary compile-error result (exit 0 or 1) whose diagnostics were all printed in full: no line left out and no line shortened.
    - Otherwise keep the folder and report the full log's path. `Compile-Mql5.ps1` prints it. When the tester calls the compile function, the path is returned to the tester, which copies the log into its output folder as `compile.log`, records it in `result.json` and prints nothing extra. Keeping the folder covers:
      - lines left out or shortened by the caps;
      - a tool or evidence failure (exit 2), such as a log with no `Result:` line.

      The log costs no context until it is needed, and no detail is lost to the caps.
    - After copying the kept log, the tester deletes the temporary folder.

    If the job cannot be confirmed empty, the step fails closed: it reports no artifact, keeps the temporary folder, prints the process IDs still running, and returns 2. The `.ex5` at the output path is then untrusted, and the tester never uses it, because it tests only the hash its own compile accepted.

**Freshness:** in the do-nothing case MetaEditor writes nothing, so there is no log and step 7 fails. The last-write check in step 9 is a second guard. A failed compile deletes the old `.ex5` (verified), just as compiling in the editor does; the source is never touched.

**Facts used:** MetaEditor's exit code is ignored, because it was 1 on success and 0 on failure (verified). A command-line compile works while a MetaEditor window is open (verified).

**Output:** only the log's error and warning lines, each with its file and line, then the `Result:` line, then one line `MQL5_RESULT {json}`.
- At most 50 diagnostic lines are printed, each cut at 300 characters, followed by the total count and a "truncated" note when lines were left out. The full log stays on disk whenever anything was cut or shortened, or a tool failure hit (step 11).
- The compile function also returns these diagnostics, so a calling tester can keep them in its `result.json`.
- The log's information lines are dropped: "compiling", "including" and about 35 "generating code n%" progress lines. A clean compile then prints about 100 tokens instead of 1,000 or more.
- The JSON holds status, editor path and build, source, errors, warnings, the artifact path and SHA-256 (only on success), and exit code.

**Exit codes:**

| Exit | Meaning |
|---:|---|
| 0 | Fresh artifact accepted |
| 1 | Compile errors |
| 2 | Input or tool failure |
| 3 | Timeout, process tree stopped |

## 6. Strategy Tester smoke run

**Command:** `Invoke-Mt5TesterSmoke.ps1 -SourcePath <file.mq5> [-IncludePath <MQL5 root>] -Symbol <symbol> -Period <period> [-FromDate <YYYY.MM.DD> -ToDate <YYYY.MM.DD>] [-Model <0-4>] [-Deposit <amount>] [-Currency <code>] [-Leverage <n>] [-ExecutionMode <n>] (-SetPath <file.set> | -UseExpertDefaults) -OutputDirectory <new folder> [-TerminalPath <terminal64.exe>] [-TimeoutSeconds 300] [-ExpectedLogMarker <MQL5_CODING_PASS:nonce>]`

Optional settings and what happens when they are left out:
- `-FromDate`/`-ToDate` come as a pair or not at all. When omitted, the run uses the last complete calendar month: `FromDate` is the 1st of the previous month and `ToDate` the 1st of the current month, so a run in January uses December of the previous year.
- `-Model` omitted uses model 1 (1-minute OHLC).
- `-ExecutionMode` omitted uses 0 (normal execution).
- `-Deposit`, `-Currency` and `-Leverage` omitted are left out of the startup file, so MT5 uses its own Strategy Tester values, as its documentation states. The summary then reports the values MT5 used, read from the report.

The model omits these only for a pure engine smoke check (see "Engine smoke defaults" below). A backtest the user asks for always passes the user's settings.

The script name stays as in v1. There is no preflight mode: with no confirmations, a run performs its gates first and stops before staging anything when one fails. Invalid input gives exit 2. A blocking condition gives exit 4: the terminal is running, there is no single data folder, or another run holds the run lock. Tests always start from source: the tester compiles it with the terminal's own `metaeditor64.exe`.

**Gates, in order. Each failure stops before anything is staged:**

1. **Inputs.** Validate every setting.
   - Symbol and period must hold no line breaks, `=`, `;` or path separators. The period uses only letters, digits and `_`.
   - When given, each value must fit its range, as in v1:
     - `-Model` is an integer from 0 to 4.
     - `-Deposit` uses invariant digits with an optional `.` fraction, from 1 to 1,000,000,000.
     - `-Currency` is 3 to 8 uppercase letters.
     - `-Leverage` is an integer from 1 to 5000.
     - `-ExecutionMode` is an integer from −1 to 600,000: −1 is a random delay, 0 normal, and a positive value a delay in milliseconds, with MT5's documented maximum of 600,000.
   - Any invalid value stops with exit 2 before the startup file is written.
   - Dates use `YYYY.MM.DD`, with to after from. Both are given or neither is; when neither is given, the defaults above apply.
   - Exactly one EA input choice is allowed.
   - The output folder must not exist, and its parent must be writable.
2. **Terminal.** Take `-TerminalPath` if given; otherwise use the unique installation, as for compilation. It must be a file named `terminal64.exe` with major version 5.
3. **Data folder.** MT5 started with `/config` opens the AppData folder whose `origin.txt` (UTF-16) names its install folder. Exactly one such folder must exist. Zero matches, several matches or an unreadable `origin.txt` block the run.
4. **Already running.** Any `terminal64.exe` process whose image path equals the selected terminal's full path (case-insensitive) blocks with exit 4. So does a `terminal64.exe` process whose path cannot be read.
   - Use `Get-Process -Name terminal64` (about 20 ms), not CIM (about 150 ms), and inspect every matching process.
   - An access error or a missing path counts as "cannot be read". It never becomes an empty result.
   - The script never closes a process. The model closes the terminal gracefully when the user's instructions allow, then reruns (see the notes below).

**Run:**

1. Acquire `<data>\.mql5-coding-smoke.data-lock`, created exclusively with delete-on-close, and hold it for the whole run. It is the same file name v1 uses, so old and new runners exclude each other. If another runner holds it, stop with exit 4; nothing is created, so a retry with the same output folder works. Then claim the output folder with a create-only call that fails if it already exists; failure stops with exit 2, so two runs never share an output folder.
2. Compile the source through the shared compile function with this terminal's `metaeditor64.exe`. Any compile result other than 0 stops here with tester exit 2, including a compile timeout (compile exit 3). `result.json` records the compile's own exit code and status in its compile section. Tester exit 3 is reserved for a timeout after MT5 is launched. Keep the hash the compile returned.
3. Create a run id: `s` plus 10 random hex characters. The staged name is `<name>-<run-id>`. The tester saves the last inputs used to `MQL5\Profiles\Tester\<expert name>.set`; a v1 run, staged under the real name, was seen overwriting a user's preset this way. A unique staged name leaves the user's presets alone.
4. Copy the `.ex5` to `MQL5\Experts\Mql5Smoke\<staged>.ex5`. The copy's hash must equal the hash from step 2, otherwise stop with exit 2. Create `Mql5Smoke` if it is missing, and note that this run created it.
5. Copy the `.set`, when one is given, to `MQL5\Profiles\Tester\<staged>.set`. This is the same file the tester's own auto-save writes, so the run owns exactly one preset file.
6. Write `<data>\<staged>.ini` as UTF-16LE with a BOM and CRLF line endings, the format v1 used for about 40 real launches (29 of them passed), with these settings:
   - `[Common]`: `NewsEnable=0`.
   - `[Experts]`: `AllowLiveTrading=0`, `AllowDllImport=0`.
   - `[Tester]`:
     - `Expert=Mql5Smoke\<staged>`, then `ExpertParameters=<staged>.set`, or an empty `[TesterInputs]` for the compiled defaults.
     - The symbol, period, dates, model and execution mode, given or defaulted. Deposit, currency and leverage are written only when given.
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
- In both of those records, `<period>` uses the journal's spelling. The journal writes `D1` as `Daily`, seen in hundreds of real journal records. `W1` is expected to map to `Weekly` and `MN1` to `Monthly`, but neither is verified yet; the real check confirms or corrects them. Minute and hour periods are spelled as given (`M1`, `H1`).
- No system record containing `tester stopped because OnInit returns non-zero`.
- With `-ExpectedLogMarker`: an application line whose message after the timestamp is exactly the marker. It must come after the test-start record and before the pass record.
- The terminal exited by itself before the deadline.

**Unrecognized journal.** The terminal journal can gain records that contain none of the expected English terminal phrases. In that case the status is `journal_phrases_not_found`, exit 2, with a hint that MT5 must run in English or the start config was not loaded. It is never reported as a failed strategy test (exit 1). No pre-launch language check exists: MT5's config `.ini` files hold no readable language setting (checked on build 6258).

The run id sits in both the ini path and the expert path, and the lock plus the running check keep other terminals of this install out. So the appended lines belong to this run. No time-window logic is needed.

**Result status:**

- Pass without a marker is `engine_smoke_passed`.
- Pass with a marker is `application_marker_passed`.
- Neither proves strategy correctness, profitability or full-date coverage.
- A report file or terminal exit code 0 alone never counts as a pass.

**Cleanup:** it runs in `finally`, after the job is confirmed empty.

1. Move `<staged>.htm` and its companions (`.png`, `-hst.png`, `-mfemae.png`, `-holding.png`, names verified on real runs) into the output folder.
   - Move one file at a time with `Move-Item -LiteralPath ... -ErrorAction Stop` and no `-Force`, so nothing is ever overwritten. Writers have stopped by then, so a successful move needs no hash check.
   - The set is not one atomic operation, especially across drives. Record each destination that succeeded.
   - On a failure, record where the file now is (source, destination or both), list it in the result, and make the exit code 2. A report that did not move is never deleted.
   - The other cleanup steps still run.
2. Delete, by literal path, only the files this run created:
   - the staged `.ex5`
   - `MQL5\Profiles\Tester\<staged>.set`
   - the `.ini`
   - the tester cache files `Tester\cache\<staged>.*.tst`. The cache is keyed by expert name (verified), so these belong to this run alone.
3. Remove `Mql5Smoke` only if this run created it and it is now empty.

Never delete recursively, never touch the journals, and never touch any file whose name lacks the run id. If the job could not be confirmed empty, leave the files in place and list them. Any cleanup failure turns the exit code into 2 and keeps the original outcome in the result.

**What a run leaves behind:**

- A run blocked before the output folder is claimed leaves nothing; the reason is printed.
- Otherwise the output folder holds:
  - `result.json`, holding:
    - settings, terminal path and build, data folder, and artifact path and hash;
    - each check true/false, the matched system lines, the cleanup list, status and exit code;
    - **headline values** read from the report: Initial Deposit, Currency and Leverage (the settings MT5 actually used), then Total Net Profit, Total Trades, Profit Factor, Expected Payoff, Balance Drawdown Maximal and Equity Drawdown Relative. Each is the raw text of the cell after its label, or null when the label is missing. The labels are the English report's, as v1's report reader used; a terminal in another language gives nulls. They are best-effort and never affect pass or fail.
    - **error lines:** up to 20 lines from this run's appended journals whose message contains `error`, `failed`, `cannot` or `critical`, each cut at 300 characters, so a failure can be read without opening megabyte-sized journals. With them go the total number of matches, a `truncated` flag, and each journal's path with this run's start and end byte. The model can then read more of exactly this run's records in bounded chunks when the summary is not enough. The list is for reading only: pass and fail are decided by the rules above, not by this filtered list.
    - **compile diagnostics:** in the same bounded form as the compile output: at most 50 lines with the total count. Whenever the compile kept its log (section 5, step 11), it is kept beside `result.json` as `compile.log`.
    - **context for each failed check:** up to 10 nearby system records from this run, each cut at 300 characters, with the check that failed. For example, the last records after the test start when no pass record came. A failure explained by a message without an error keyword, such as missing history or an early stop, is therefore still visible. The keyword error lines are only a convenience.
  - a copy of the `.ini`;
  - the moved reports;
  - `compile.log`, only when the compile kept its log: diagnostics were cut or shortened, or the compile hit a tool failure.
- Anything kept for recovery is listed by path in `result.json` and left where it is, such as a report that did not move or files left because the job could not be confirmed empty. It is never deleted to tidy up.

The console prints one structured summary line, `MQL5_RESULT {json}`, and nothing else. It is enough to report a clean run without opening `result.json`, and it holds:
- status and exit code;
- compile errors, warnings and the artifact hash;
- symbol, period, dates, model and execution mode, plus the deposit, currency and leverage MT5 used;
- the failed checks;
- cleanup ok or the number of leftovers;
- the headline values;
- the report and `result.json` paths.

Field names stay readable, not abbreviated. Matched journal records, failure context and recovery details stay in `result.json`, which is opened only when the summary is not enough.

**Notes for `references/strategy-tester.md`:**

- During a smoke run the EA's `MQL_PROGRAM_NAME` is the staged name `<name>-<run-id>`. An EA that checks its own name, for example for licensing or for file and global-variable prefixes, behaves differently.
- Only the `.ex5` is copied, so libraries and `MQL5\Files` data the EA needs must already be in the selected terminal.
- The default timeout is 300 seconds. A first run on a new symbol or date range may need longer while history synchronizes; raise `-TimeoutSeconds` rather than retrying blindly.
- **MT5 must run in English.** The pass rules match English journal phrases such as `Test passed` and `successfully finished`. A terminal set to another language most likely writes them translated, so every run would fail with those checks false. The real check confirms the English phrases.
- **Engine smoke defaults, for speed.** These apply when the user asks only whether the EA starts, runs and finishes in the tester, and gives no such settings:
  - Omit the dates, model, execution mode, deposit, currency and leverage. The run then uses the last complete calendar month, model 1 (1-minute OHLC) and normal execution, which is far faster than a year of every-tick data, and MT5's own deposit, currency and leverage.
  - The symbol, period and EA inputs still come from the user or the project.
  - Report the settings actually used; the verdict stays `engine_smoke_passed`.
  - Never use these defaults to judge strategy behavior or results; a backtest the user asks for always uses their settings.
- Do not open the selected terminal by hand during a run. The running check is only a point-in-time observation.
- **Closing a running terminal, when the user's instructions allow it.** The user's standing instruction on this test PC covers both steps below.
  1. Close it gracefully with `CloseMainWindow()` and wait up to 30 seconds for the process to exit. This usually takes 1–3 seconds.
  2. Force it with `Stop-Process` only if it is still running then. A hard kill can damage the terminal's history files.

  Before rerunning, wait up to 30 more seconds until no `terminal64.exe` at that path and no `metatester64.exe` from that install folder remain. If any remain, report the run as blocked and do not rerun.
- Start a long test as a background command, or give the call a timeout longer than `-TimeoutSeconds`. If the client kills the runner, the Job Object stops MT5 and its agents with it, but that run's staging stays behind.
- Recommended setup for people who keep a terminal open: a second MT5 install used only for testing, selected with `-TerminalPath`. Installing outside Program Files does not by itself make it portable, so the AppData binding still applies. Start it once normally and log in to a demo account, so `origin.txt` and history exist.

**Exit codes:**

| Exit | Meaning |
|---:|---|
| 0 | Smoke passed |
| 1 | Ran, but a pass rule failed |
| 2 | Input, compile, tool, evidence or cleanup failure |
| 3 | Timeout, process tree stopped |
| 4 | Blocked by a gate before launch |

## 7. OwnedProcess.cs

One C# class, loaded once with `Add-Type` and shared by compile and tester:

- `CreateProcessW` suspended, with no handle inheritance.
- `AssignProcessToJobObject` on a job with kill-on-close. If assignment fails, kill the suspended child, confirm it is gone, and fail.
- `ResumeThread`, `WaitForExit(ms)`, `TerminateJob`, `WaitForEmpty(ms)` (the job's active-process count is 0).

This is the one piece of the old native code that is worth keeping, even on a test PC, for two reasons:

- `taskkill /T` misses descendants whose parent already exited, such as tester agents.
- When the client kills the runner itself, a kill-on-close job still stops MT5. Plain PowerShell cleanup never runs in that case, so an orphaned terminal would block the next run and could race its evidence or cleanup.

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
  - `-AcknowledgeSavedAccountRisk`, `-Execute` and `-PreflightOnly` → no longer needed; the script just runs
- **README.** Say that the skill is built for test PCs and starts MT5 with whatever account is saved there.
- **Leftovers from v1.** New staging uses `Mql5Smoke`. v1 left its `CodexSmoke` staging files, reports and compile receipts in place. v2 does not touch them. Cleaning them is a separate job; prefer sending them to the Recycle Bin.
- **Versions.** Use git tags, starting at `v2.0.0`.

## 10. Tests

Four groups in `tests/Test-Safety.ps1`, plain PowerShell with no framework. They run on PowerShell 5.1 and 7 in one Windows CI workflow, with no MT5 and no credentials:

1. **Terminal gates and containment:**
   - A running fake terminal at the selected path blocks with exit 4 before anything is staged.
   - A run lock already held by another runner blocks with exit 4, and nothing is staged.
   - Zero or several `origin.txt` folders for the install block.
   - A fake terminal that spawns a child and never exits is timed out with exit 3, and both processes are gone before cleanup runs.
2. **Startup ini and editor selection:**
   - The ini has `AllowLiveTrading=0`, `AllowDllImport=0`, `Optimization=0` and `UseCloud=0`.
   - It has no `Login`, `Password` or `Server` key, and an empty `[TesterInputs]` for defaults.
   - A symbol containing a line break or `=` is rejected.
   - `-MetaEditorPath` pointing at a terminal fake returns exit 2, and nothing starts.
   - Default dates with no dates given: on 2026-01-15 they are `2025.12.01` to `2026.01.01` (the January rollover); on 2026-03-10 they are `2026.02.01` to `2026.03.01`.
   - With deposit, currency and leverage omitted, the ini has none of those keys, and execution mode is `0`.
3. **Stale artifact:**
   - A fake editor that writes no log returns 2 and never stages. So does one that writes a valid UTF-16 `Result: 0 errors, 0 warnings` line but leaves the `.ex5` untouched.
   - A fake editor that exits after starting a child that writes the log and `.ex5` later is waited for. The result is read only after the child ends.
   - A staged copy whose hash differs from the compile's hash stops the run with exit 2.
4. **Cleanup and journal:**
   - After a fake run, only files carrying the run id are gone.
   - A user's `<name>.set` sentinel keeps its exact bytes, and a user file in the same folders survives.
   - A staged report held open without delete sharing cannot be moved. It stays in place, is listed in `result.json` and gives exit 2, and the other owned files are still removed. A report that already exists at the destination is not overwritten.
   - Each of these fails the run (exit 1):
     - a tester log with a second test-start record;
     - a real `tester stopped because OnInit returns non-zero` system record;
     - a required marker that never appears.
   - An echoed input `x=tester stopped because OnInit returns non-zero` does not change the result.
   - A terminal journal with new records but none of the expected English phrases gives `journal_phrases_not_found` with exit 2, not exit 1.

**Fakes:** tiny console programs built with the Windows .NET Framework `csc.exe`, the method v1's tests used. PowerShell 7's `Add-Type` cannot build executables (verified). They stand in for `metaeditor64.exe` and `terminal64.exe` in a temporary folder tree that mimics an install plus an AppData data folder.

**Test root:** the entrypoint scripts have no AppData parameter and always use the real `%APPDATA%`. The compile and tester logic live in functions in `Mql5Compile.ps1` and `Mql5Tester.ps1`; the tests dot-source them and call those functions with a test root, so the tests never touch the real AppData.

**Real check, required before release:** on a PC with MT5 (build 6258 at design time), compile and run the nontrading test EA from a folder whose path has spaces, with a fresh marker, in both Claude Code and Codex. The journal rules prove the engine finished; they do not prove every setting was applied, so these items are release requirements. Confirm and record:

- the pass status
- the staging gone
- no new files next to the source
- the report moved
- the build, settings and result
- `W1` and `MN1` journal spellings, and that the report shows the requested leverage
- the English journal phrases the pass rules match, on a terminal set to English
- that a run with deposit, currency and leverage omitted passes, and its summary shows the values MT5 used
- the v2 helper's `Add-Type` time, and total runtime under Windows PowerShell 5.1 against PowerShell 7
- whether `[Experts]` in the terminal's `config\common.ini` is the same before and after the run, which checks whether startup keys persist. If the values differ, restore the original values by hand and treat it as a release blocker. Before release, the tester then saves that section before launch and writes it back in cleanup, and a test covers it.

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
- no preflight mode at all (`-PreflightOnly` and `-Execute` dropped): with no confirmations, a run's own gates stop it before staging
- moving reports one at a time without overwriting, instead of copy, hash and delete
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
- replacing the Job Object helper with `taskkill /T` plus a sweep of tester agents (proposed by Claude, rejected after GPT's review). Only a kill-on-close job stops MT5 when the client kills the runner, and `taskkill /T` cannot reach descendants whose parent already exited. A leftover terminal would block the next run and could race evidence and cleanup.

**Kept from earlier reviews:**

- source mode compiles with the terminal's own MetaEditor
- the script name stays
- a small Job Object helper
- unique staged names
- the v1-compatible lock file
- freshness from this run's own temporary log plus the last-write check
- no prefix hashing of journals: the run id in every logged path ties lines to the run

**Open, to confirm in the real check:**

- the leverage format: the docs show `Leverage=1:100`, while v1 writes `Leverage=100` and passed many real runs, so keep the proven form and confirm the report shows the requested value
- the `W1`/`MN1` spellings
- whether startup keys persist

**CI against MT5:** none. Hosted CI has no MT5; the real check is manual and recorded.

**Speed (decided 2026-10-20, with GPT).** Measured on the user's PC:
- loading a C# helper with `Add-Type` costs about 1.0 s in PowerShell 7 and about 0.4 s in 5.1 (with v1's large helper);
- `Get-CimInstance` takes 150 ms against 20 ms for `Get-Process`;
- a one-year M1 smoke run takes about 24 s, of which about 8.5 s is terminal and agent startup and 5.5 s is the test.

Adopted:
- `Get-Process` for the running check;
- documented `-NoProfile -NonInteractive` calls;
- engine smoke defaults (last complete month, model 1) only for a pure start/run/finish check with no settings given;
- reading only the guide for the script being called;
- recompiling only after a change to any build input;
- running long tests in the background.

Rejected:
- skipping recompiles when the source looks unchanged, because includes can change;
- parallel tests on several terminals, which add no saving for one smoke run and too much complexity;
- caching the compiled helper as a DLL, for now. It adds persistent state and failure paths, and the saving is measured only on v1's 1,192-line helper. Measure v2's ~110-line helper first.

**Shell:** Windows PowerShell 5.1 (`powershell.exe`) is the documented default. It is always installed and measured faster on both startup and `Add-Type`. The real check confirms that 5.1 stays faster with v2's smaller helper. Switch the default to PowerShell 7 only if it does not, which needs no cache either way.

**Refinements after a full re-read (2026-10-20):**
- the compile-lock name is a hash, because Windows object names cannot contain backslashes;
- the startup ini is UTF-16LE with a BOM and CRLF line endings;
- MT5 must run in English for the pass rules;
- the tester covers Expert Advisors only;
- the default dates are defined exactly, including the January rollover, with a test;
- a held run lock gives exit 4;
- a running terminal is closed gracefully;
- the compile log is deleted only when every diagnostic was printed in full after a success or compile errors; it is kept otherwise, including on tool failures (GPT's follow-up);
- deposit, currency, leverage and execution mode are optional for smoke checks, and the summary reports the values MT5 used;
- searching for `.mqh` consumers is explained, following indirect includes up to each `.mq5` (GPT's follow-up);
- a second full read fixed eight small inconsistencies: stale wording, exit codes, a miscount of v1 runs and naming.

These add about 65 tokens per task and make runs slightly faster overall: fewer questions, the faster shell, no wasted indicator runs.

**Token efficiency (decided 2026-10-20).** The skill keeps what reaches the model's context small:

- **References.** Each is read once per task, and each is a short invocation and result guide.
- **Compile output.** Compile prints only errors, warnings and the result. The full log stays on disk whenever anything was cut or shortened, or the compile hit a tool failure.
- **Tester output.** The tester prints one structured summary line, which is enough for a clean run. `result.json` holds headline values, bounded error lines, the context for each failed check and journal byte ranges, and it is opened only when needed.
- **No whole files.** SKILL.md forbids reading a report or journal whole.
- **No repeated work.** The model calls the tester directly instead of compiling first, and reuses files, passages and results until their inputs change.
- **Lean lookups.** The docs-MCP calls use explicit lean arguments.

A second GPT pass on 2026-10-20 suggested these refinements, and none of them gives up evidence or checklist duties. Section 12 gives the numbers. The extra code is about 50 lines.

**Size:** about 755 installed lines plus about 330 lines of repository tooling, around 1,085 in total. This is a provisional estimate, not a limit.

## 12. Token budget

What reaches the model's context in one clean compile-and-test task. Estimates use about 4 characters per token. v1 figures come from the installed v1.2.10 files and 43 real `smoke-result.json` files.

| What the model sees | v1 | v2 |
|---|---:|---:|
| Skill description (always listed by both clients) | ~130 | ~60 |
| `SKILL.md`, when the skill is used | ~2,700 | ~1,340 |
| Compile guide (v1: read completely before every compile; v2: not read for a test, because the tester guide covers it) | ~1,000 | 0 |
| Tester guide, once per task (v1: read completely before every run) | ~3,900 | ~840 |
| Compile output (v1: full log with ~35 progress lines; v2: none, because the tester compiles and reports the counts in its summary) | ~1,000+ | ~0 |
| Tester console output | ~50 (a path) | ~260 (one summary line) |
| Run result read afterwards (v1: `smoke-result.json`, 18 KB on average and up to 37 KB; v2: not needed on a clean run) | ~4,600 | 0 |
| **Total, clean run** | **~13,000** | **~2,500** |

This table is the current v2 estimate. It supersedes the earlier figures of about 4,500, 2,800 and 2,450 tokens in this design's history.

A failed run adds about 800–1,500 tokens for v2, because the model then opens `result.json`. A compile on its own prints about 100 tokens when clean. The table leaves out docs-MCP responses, source-file reads and the model's own loops. The lean lookup arguments save roughly 300–1,500 tokens on a lookup-heavy task.

The v2 figures depend on these rules:

- **Capped output.** At most 50 compile lines; one tester summary line. Each diagnostic or error line is cut at 300 characters, with counts and a truncation flag. The full compile log stays on disk whenever anything was cut or shortened, or a tool failure hit.
- **`result.json`.** It carries:
  - the headline report values;
  - up to 20 error lines;
  - context for each failed check;
  - this run's journal byte ranges.

  So the model never needs the 500 KB report (~130,000 tokens) or the megabyte-sized journals.
- **No whole files.** SKILL.md forbids reading a report or journal whole. The tester guide allows only regex captures from a report, and only chunks of at most 8 KB from this run's journal range.
- **Frugal docs lookups.** Status before the first fact; batched lookups with `limit: 1`; focused reads of 1500–3000 characters with no related topics or images; reuse of verified passages.
- **No repeated work.** The tester compiles; there is no separate compile first. Results are reused until their inputs change.

Savings are never taken by dropping evidence or checklist duties: the checklist stays in SKILL.md, lookups still need a verified passage, and truncated diagnostics stay on disk. The report trap is unlikely but cannot be ruled out, because a model can still choose to open a file. During the real check, measure the clean, warning and failure paths separately with the clients' real token counts, and correct this table.
