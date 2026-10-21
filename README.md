# MQL5-Coding

A small skill for Claude Code and Codex that helps write, review, compile and smoke-test MetaTrader 5 (MQL5) code on Windows. It checks MQL5 facts in the installed [MQL5 CHM MCP](https://github.com/shamwi2846/MQL5-CHM-MCP) first, compiles with MetaEditor, and runs one Strategy Tester smoke test. The test refuses to start a terminal that is already running and only tests the build it just compiled.

**Status:** design stage. Read the design in [docs/design.md](docs/design.md). No skill code yet.

**Built for test PCs.** The skill compiles and backtests without asking, and the Strategy Tester starts MT5 with whatever account is saved in it. Use it on a PC with no real-money accounts and no live trading.

This is version 2 of the `mql5-coding` skill, rewritten to be small. Version 1 (v1.2.10) remains in [MQL5-Coding-Skill](https://github.com/shamwi2846/MQL5-Coding-Skill).
