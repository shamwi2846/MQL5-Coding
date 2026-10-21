---
name: mql5-coding
description: Write, review, explain, debug, compile and backtest MetaTrader 5 MQL5 code (EAs, indicators, scripts, services, libraries; .mq5/.mqh/.ex5) on Windows, checking MQL5 facts in the mql5-chm docs first. Not MQL4/MT4.
---

# MQL5 Coding

## Scope

MetaTrader 5 and MQL5 only: Expert Advisors, indicators, scripts, services, libraries, `.mq5`, `.mqh`, `.ex5`. MQL4, MT4, `.mq4` and `.ex4` are out of scope. The scripts live in the `scripts` folder next to this file. Use the MCP tool names your client lists (Claude Code shows them as `mcp__mql5-chm__...`).

## Intent

- Review and explanation never edit files.
- Diagnosis finds the evidenced cause; fix only when asked.
- A change is the smallest safe change. Keep behavior, public inputs, names and layout unless the task needs otherwise.
- Never silently add or change entries, exits, stops, targets, sizing, retries, directions or position management.
- Never place trades outside the Strategy Tester (demo accounts included), move money or enter credentials.

## Docs first

Before asserting or using an MQL5 API, language, event, error, trade-retcode, symbol-property or Strategy Tester fact:

1. **Status.** Call `mql5_chm_status` once, before the first MQL5 fact in a task.
2. **Lookups.** For several names, make one `mql5_chm_lookup_identifiers` call with `source: "mql5"` and `limit: 1`. For one name, use `mql5_chm_search` with `source: "mql5"`, `limit: 1` and `expand: false`. Only an exact match whose passage contains the identifier as a whole token counts; approximate, prefix or `non_exact` results never do.
3. **Reads.** `mql5_chm_read` with `section_id` or `focus`, `max_chars` 1500-3000, `include_related: false`, `include_images: false`. Follow `next_cursor` (same `topic_id` and `section_id`, no `focus`) until the passage settles the claim; a short first excerpt is never a reason to stop.
4. **Reuse.** Keep a verified passage for the rest of the task; never read it twice.
5. **Citations.** Give the title, topic id and section id, plus the corpus or index revision once per answer.
6. **Fallback.** When the docs cannot support a claim, write exactly `Not verified in the installed MQL5 CHM`, then use and cite official MetaQuotes pages (mql5.com, metatrader5.com). Never fill gaps from memory. The CHM covers the MQL5 reference and books, not terminal settings or startup `.ini` keys. If no `mql5_chm_*` tools are listed, say so and use the official pages the same way; a missing MCP never stalls review work.
7. **Logs** describe the local program and run, not the API.

## Evidence and classification

Read the compiler output and the journals before diagnosing a runtime problem. When they are missing, report that gap instead of presenting a guess from source as the cause. Classify first:

- **Compilation:** syntax, types, overloads, includes, declarations, warnings.
- **Initialization/runtime:** event-handler contract, init return, `_LastError`, invalid handles, array bounds, object lifetime.
- **Indicators/timeseries:** handle creation, `BarsCalculated`, `CopyBuffer` counts, buffer direction, current versus completed bars, history sync.
- **Trade execution:** request fields, retcode, deal result, permissions, volume limits, price and tick alignment, stops, account mode, ownership filters.
- **Tester/environment:** symbol, period, dates, model, inputs, history, terminal and agent state.
- **Strategy logic:** signal state, bar timing, position state, branch conditions, after the platform facts are verified.

State symptom, cause, impact and evidence separately.

## Review checklist

- Event lifecycle for the program type.
- Every handle: creation failure, readiness, returned counts, release.
- Buffer direction and bar index; index 0 is not a completed bar by default.
- `SYMBOL_VOLUME_MIN`, `SYMBOL_VOLUME_MAX`, `SYMBOL_VOLUME_STEP`, without silently changing a requested volume.
- Digits, tick size, stop and freeze levels, trade permissions and trade-server results.
- Netting versus hedging; positions, orders and deals kept apart.
- Symbol, magic number, direction and owner filters, so unrelated and manual trades are left alone.
- Diagnostics and test-only code that cannot place unintended trades.
- Nothing unrelated renamed, reformatted or restructured in a fix.

## Validate

- Compile every affected `.mq5`, including consumers of a changed `.mqh`. Find them by searching the project for the include's file name, then repeat the search for each header that includes it, until every `.mq5` at the end of the chain is found. Report any consumer you could not resolve.
- When the task also needs a test, call the tester for the EA under test directly: it compiles that source itself, so do not compile it first. Compile every other affected `.mq5` separately.
- Recompile only after a change to the source, an include or another build input. Reuse files already read and run results until their inputs change.
- Read only the guide for the script you call, once per task: [strategy-tester.md](references/strategy-tester.md) for a test (it covers the compile fields too), [compile.md](references/compile.md) only when calling `Compile-Mql5.ps1` on its own.
- Compiling a file inside a running terminal's `MQL5` folder makes that terminal reload any chart running it (`REASON_RECOMPILE`).

## Testing

- The tester runs Expert Advisors only. Indicators, scripts and services are validated by compiling.
- Never run an `.ex5` the user did not build or vouch for. Building it here does not make it trustworthy: the EA runs with the tester agent's file and network access.
- Pass markers go only in a separate test EA. Never edit the user's EA just to test it, unless the user asks or it already has a self-test. A user's EA gets the plain engine smoke test.
- Use the tester's `MQL5_RESULT` summary line first; open `result.json` only when it is not enough. Never read a report or journal file whole: a report is about 500 KB (roughly 130,000 tokens). The tester guide gives the bounded way to read more.
- If the selected terminal is already running, the tester refuses (exit 4). When the user's instructions allow, close it gracefully and rerun; otherwise ask. The tester guide says how.

## Report

Lead with the outcome, then: files and behavior changed; the evidenced cause; CHM citations; the compile result with errors, warnings and artifact; tester settings, result and output folder; checks not run; remaining uncertainty. A smoke pass never implies profitability or live safety.
