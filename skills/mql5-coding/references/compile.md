# Compile-Mql5.ps1

Compiles one `.mq5` with MetaEditor. It never starts a terminal.

```
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "<skill folder>\scripts\Compile-Mql5.ps1" -SourcePath <file.mq5> [-IncludePath <MQL5 folder>] [-MetaEditorPath <metaeditor64.exe> | -TerminalPath <terminal64.exe>] [-TimeoutSeconds 120]
```

- **Editor:** `-MetaEditorPath`, else the `metaeditor64.exe` next to `-TerminalPath`, else the only MT5 installation found. With several installations it stops with exit 2 and lists them; pass one.
- **Includes:** `-IncludePath` defaults to the nearest `MQL5` folder above the source. Without one, MetaEditor uses its own data folder's `MQL5`.
- **Paths** over 259 characters are refused: MetaEditor silently ignores them.

**Output:** the error and warning lines (at most 50, each cut at 300 characters, with a note when anything was cut), the `Result:` line, then one line `MQL5_RESULT {json}` with `status`, `exit_code`, `message`, `editor`, `editor_build`, `source`, `errors`, `warnings`, and on success `artifact` and `sha256`. When lines were cut, or on exit 2 or 3, the full log is kept and its path is printed and given as `log`.

| Exit | Status | Meaning |
|---:|---|---|
| 0 | `compiled` | A fresh, nonempty `.ex5` was written by this compile |
| 1 | `compile_errors` | The source has errors |
| 2 | `failed` | Input or tool failure, including a log without a `Result:` line or an `.ex5` that was not rewritten |
| 3 | `timeout` | MetaEditor and everything it started were stopped |

**Notes:**
- A failed compile deletes the existing `.ex5`, just as compiling in MetaEditor does; the source is never touched.
- Compiling a file inside a running terminal's `MQL5` folder makes that terminal reload any chart running it.
- Warnings never fail a compile; judge them in the report.
