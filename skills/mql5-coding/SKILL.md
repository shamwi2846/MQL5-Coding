---
name: mql5-coding
description: Write, review, explain, debug, compile and backtest MetaTrader 5 MQL5 code (EAs, indicators, scripts, services, libraries; .mq5/.mqh/.ex5) on Windows, checking MQL5 facts in the mql5-docs MCP first. Not MQL4/MT4.
---

# MQL5 Coding

## Scope

MT5/MQL5 only: Expert Advisors, indicators, scripts, services and libraries (`.mq5`, `.mqh`, `.ex5`); not MQL4/MT4 (`.mq4`, `.ex4`). The scripts are in the `scripts` folder next to this file. Use the MCP tool names your client lists (Claude Code: `mcp__mql5-docs__mql5_find`; Codex: `mcp__mql5_docs__mql5_find`).

## Intent

- Review and explanation never edit files.
- Diagnosis finds the evidenced cause; fix only when asked.
- A change is the smallest safe change. Keep behavior, public inputs, names and layout unless the task needs otherwise.
- Never silently add or change entries, exits, stops, targets, sizing, retries, directions or position management.
- Never place trades outside the Strategy Tester (demo accounts included), move money or enter credentials.

## Docs first

Before asserting or using an MQL5 API, language, event, error, trade-retcode, symbol-property or Strategy Tester fact:

1. **Find.** Call `mql5_find` once with every name you need: up to 16 API names, exact page titles or short questions. When an answer is brief or cut, make the call it names before relying on what it leaves out.
2. **Evidence.** Base each claim on returned text that states it. `=` proves only that the name matched; `~` is a search result and never identifies an API.
3. **Reuse.** Keep text already read for the rest of the task while the index tag is unchanged; never read it twice.
4. **Citations.** Name the docs page title, plus the docs version (download date and index tag) once per answer; give page ids only when asked.
5. **Fallback.** When the docs cannot support a claim, write exactly `Not verified in the installed MQL5 docs`, then use and cite official MetaQuotes pages (mql5.com, metatrader5.com); check them too when freshness matters. Never fill gaps from memory. The docs cover the MQL5 reference and books, not terminal settings or startup `.ini` keys. If no `mql5_find` tool is listed, say so and use the official pages the same way; a missing MCP never stalls review work.
6. **Logs** describe the local program and run, not the API.

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

- Compile every affected `.mq5`. For a changed `.mqh`, search the project for its file name, then repeat for each header that includes it, until every `.mq5` consumer is found; report any you could not resolve.
- For a test, call the tester directly on the EA under test (it compiles that source itself); compile the other affected `.mq5` files separately.
- Recompile only after a build input changes (source, include or other input). Reuse files read and run results until their inputs change.
- Read each guide once per task, only for the script you call: [strategy-tester.md](references/strategy-tester.md) for a test, [compile.md](references/compile.md) for `Compile-Mql5.ps1` on its own.
- Compiling inside a running terminal's `MQL5` folder reloads any chart running that program (`REASON_RECOMPILE`).

## Testing

- The tester runs Expert Advisors only. Indicators, scripts and services are validated by compiling.
- Never run an `.ex5` the user did not build or vouch for. Building it here does not make it trustworthy: the EA runs with the tester agent's file and network access.
- Pass markers go only in a separate test EA. Never edit the user's EA just to test it, unless the user asks or it already has a self-test. A user's EA gets the plain engine smoke test.
- Start with the `MQL5_RESULT` line; open `result.json` only when it is not enough. Never read a report (about 130,000 tokens) or a journal whole; use the tester guide's bounded reads.
- Exit 4 because another tester run holds the lock: that run, perhaps from another chat, is still going; wait and retry, never close its terminal. Exit 4 because the selected terminal is already running: when the user's instructions allow, close it gracefully as the tester guide says and rerun; otherwise ask.

## Report

Lead with the outcome, then: files and behavior changed; the evidenced cause; docs citations; the compile result with errors, warnings and artifact; tester settings, result and output folder; checks not run; remaining uncertainty. A smoke pass never implies profitability or live safety.
