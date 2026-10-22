# MQL5-Coding

A small skill for Claude Code and Codex that helps write, review, compile and smoke-test MetaTrader 5 (MQL5) code on Windows. It checks MQL5 facts in the installed [MQL5 Docs MCP](https://github.com/shamwi2846/MQL5-Docs-MCP) first, compiles with MetaEditor, and runs one Strategy Tester smoke test. The test refuses to start a terminal that is already running and only tests the build it just compiled.

**Built for test PCs.** The skill compiles and backtests without asking, and the Strategy Tester starts MT5 with whatever account is saved in it. Use it on a PC with no real-money accounts and no live trading.

## Install

From a checkout of this repository, in Windows PowerShell:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1            # both clients
powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Client Claude
```

It copies `skills/mql5-coding` to `%USERPROFILE%\.claude\skills` (or `%CLAUDE_CONFIG_DIR%\skills`) and `%USERPROFILE%\.codex\skills` (or `%CODEX_HOME%\skills`). Each existing install is backed up first to `%LOCALAPPDATA%\mql5-coding\backups`. Restart the client afterwards. In Codex, the scripts need permission to start processes (MetaEditor and the terminal).

Requirements: Windows, Windows PowerShell 5.1 (or PowerShell 7), MetaTrader 5 with MetaEditor, set to English, and the MQL5 Docs MCP (`mql5-docs`) for documentation lookups.

## What is inside

- `skills/mql5-coding/SKILL.md`: the instructions both clients load.
- `scripts/Compile-Mql5.ps1`: compiles one `.mq5`; see `references/compile.md`.
- `scripts/Invoke-Mt5TesterSmoke.ps1`: compiles an EA with the terminal's own MetaEditor and runs it once in the Strategy Tester; see `references/strategy-tester.md`.
- `tests/Test-Safety.ps1`: safety tests with fake MetaEditor and terminal programs; no MT5 needed.
- [docs/design.md](docs/design.md): the design and the decisions behind it.

This is version 2 of the `mql5-coding` skill, rewritten to be small. Version 1 (v1.2.10) remains in [MQL5-Coding-Skill](https://github.com/shamwi2846/MQL5-Coding-Skill).
