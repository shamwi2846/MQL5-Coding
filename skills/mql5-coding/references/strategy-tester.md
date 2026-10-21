# Invoke-Mt5TesterSmoke.ps1

Compiles one Expert Advisor with the selected terminal's own MetaEditor and runs it once in the Strategy Tester. It runs without asking: the skill is built for a test PC.

```
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "<skill folder>\scripts\Invoke-Mt5TesterSmoke.ps1" -SourcePath <file.mq5> [-IncludePath <MQL5 folder>] -Symbol <symbol> -Period <period> [-FromDate <YYYY.MM.DD> -ToDate <YYYY.MM.DD>] [-Model <0-4>] [-Deposit <amount>] [-Currency <code>] [-Leverage <n>] [-ExecutionMode <n>] (-SetPath <file.set> | -UseExpertDefaults) -OutputDirectory <new folder> [-TerminalPath <terminal64.exe>] [-TimeoutSeconds 300] [-ExpectedLogMarker <MQL5_CODING_PASS:hex>]
```

**Settings:**
- `-OutputDirectory` must not exist yet; its parent must.
- `-TerminalPath`, else the only MT5 installation found. That terminal must not be running.
- `-IncludePath` defaults to the nearest `MQL5` folder above the source; without one, MetaEditor uses its own data folder's `MQL5`.
- Dates default to the last complete calendar month; `-Model` to 1 (1-minute OHLC); `-ExecutionMode` to 0 (normal; -1 random delay; n > 0 a delay in ms up to 600000; model 2 ignores delays).
- `-Deposit`, `-Currency` and `-Leverage` (an integer n, written as `1:n`) default to MT5's own tester values; `headline` shows what MT5 used.
- `-SetPath` takes the EA inputs from a `.set` file; `-UseExpertDefaults` uses the compiled defaults.
- `-ExpectedLogMarker` requires the EA to print exactly that line during the test. Test EAs only.

**Engine smoke defaults.** When the user asks only whether an EA starts, runs and finishes, omit the dates, model, execution mode, deposit, currency and leverage: the run is fast and uses the last complete month. Never judge strategy behavior or results with these defaults; a backtest the user asks for uses their settings.

**Output:** one line, `MQL5_RESULT {json}`: `status`, `exit_code`, `message`, `compile` (errors, warnings, sha256), `settings`, `failed_checks`, `cleanup` (`ok` or `<n> left`), `headline` (key English-report values, including the deposit, currency and leverage MT5 used), `report` and `result_json`. A pass without compile warnings needs nothing more; with warnings, read `compile.diagnostics` in `result.json` (`compile.log` in chunks if `truncated`) and report them.

**result.json** (output folder; open only when needed): settings, terminal, data folder, staged name; `checks` (true or false each); `matched_lines`; `failure_context` (up to 10 records near the failed checks); `error_lines` (up to 20 lines with error, failed, cannot or critical); `journals` (path plus this run's start and end byte); `compile` (diagnostics; `log` when kept as `compile.log`); `cleanup` (moved, removed, left); `primary_status` when cleanup turned the result into exit 2.

| Exit | Status | Meaning |
|---:|---|---|
| 0 | `engine_smoke_passed`, `application_marker_passed` | The tester started, ran and finished this build (and saw the marker, when given) |
| 1 | `failed_checks` | It ran, but a pass rule failed; see `failed_checks` |
| 2 | `failed`, `journal_phrases_not_found`, `cleanup_failed` | Input, compile, tool, evidence or cleanup failure |
| 3 | `timeout` | The terminal and its agents were stopped |
| 4 | `blocked` | No usable terminal (missing, several found, or running), no single data folder, or another run holds the lock; nothing was created |

A pass never proves strategy correctness, profitability or full-date coverage.

**Reading more, bounded:**
- One more report value: extract just that cell with a regex capture and print the capture, never the matching line, which can be the whole file.
- Journals: read only this run's byte range from `journals`, in chunks of at most 8 KB, decoded as UTF-16LE.
- `compile.log`, when kept: read it in chunks.

**Notes:**
- A failed compile deletes the `.ex5` next to the source, as in MetaEditor; the source is never touched.
- The EA runs as `<name>-s<10 hex>` (`MQL_PROGRAM_NAME`), which changes name-based licensing and file or global-variable prefixes.
- Only the `.ex5` is copied: libraries and `MQL5\Files` data the EA needs must already be in the selected terminal.
- A first run on a new symbol or date range may need longer for history sync: raise `-TimeoutSeconds` instead of retrying.
- MT5 must run in English: the pass rules match English journal phrases. Otherwise the run ends with `journal_phrases_not_found`.
- Do not open the selected terminal by hand during a run.
- Start a long test as a background command, or give the call a timeout longer than `-TimeoutSeconds`. If the client kills the runner, MT5 stops with it, but that run's staging stays behind.
- **Closing a running terminal (exit 4), when the user's instructions allow it:** close it gracefully with `CloseMainWindow()` and wait up to 30 s (usually 1-3 s). Only if it is still running, use `Stop-Process`; a hard kill can damage history files. Then wait up to 30 s until no `terminal64.exe` at that path and no `metatester64.exe` from that install folder remain. If any remain, report the run as blocked and do not rerun.
- For users who keep a terminal open: a second MT5 install just for testing, selected with `-TerminalPath` and started once with a demo login.
