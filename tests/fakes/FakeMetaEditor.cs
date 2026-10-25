// Stands in for metaeditor64.exe in tests/Test-Safety.ps1. FAKE_EDITOR_MODE picks the behavior:
// ok (fresh .ex5, clean log), errors, many (60 diagnostics, one very long), nolog, stale (clean log
// but the .ex5 untouched), child (exits at once; a child writes the results 1.5 s later), hang.
// FAKE_LOCK_PROBE names a run lock file: FAKE_PROBE_OUT then gets "<UTC ticks> locked|free" at compile start.
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;

[assembly: System.Reflection.AssemblyFileVersion("5.0.0.4000")]

static class FakeMetaEditor
{
    static string Value(string[] args, string prefix)
    {
        foreach (string arg in args)
            if (arg.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return arg.Substring(prefix.Length).Trim('"');
        return null;
    }

    static bool IsLocked(string path)
    {
        try { using (File.Open(path, FileMode.Open, FileAccess.ReadWrite, FileShare.None)) return false; }
        catch (FileNotFoundException) { return false; }
        catch (IOException) { return true; }
    }

    static int Main(string[] args)
    {
        string mode = Environment.GetEnvironmentVariable("FAKE_EDITOR_MODE") ?? "ok";
        string counter = Environment.GetEnvironmentVariable("FAKE_EDITOR_COUNTER");
        if (counter != null && mode != "late") File.AppendAllText(counter, "x");
        string probe = Environment.GetEnvironmentVariable("FAKE_LOCK_PROBE");
        if (probe != null) File.WriteAllText(Environment.GetEnvironmentVariable("FAKE_PROBE_OUT"), DateTime.UtcNow.Ticks + " " + (IsLocked(probe) ? "locked" : "free"));
        string source = Value(args, "/compile:"), log = Value(args, "/log:");
        string ex5 = Path.ChangeExtension(source, ".ex5");
        string ok = "Result: 0 errors, 0 warnings, 10 ms elapsed, cpu='X64 Regular'\r\n";

        switch (mode)
        {
            case "hang":
                Thread.Sleep(Timeout.Infinite);
                return 0;
            case "child":
                var start = new ProcessStartInfo(Process.GetCurrentProcess().MainModule.FileName,
                    "/compile:\"" + source + "\" /log:\"" + log + "\"") { UseShellExecute = false };
                start.EnvironmentVariables["FAKE_EDITOR_MODE"] = "late";
                Process.Start(start);
                return 0;
            case "late":
                Thread.Sleep(1500);
                break;
            case "nolog":
                return 0;
            case "stale":
                File.WriteAllText(log, ok, Encoding.Unicode);
                return 1;
            case "errors":
                if (File.Exists(ex5)) File.Delete(ex5);
                File.WriteAllText(log, source + " : information: compiling\r\n" + source + "(3,5) : error 256: undeclared identifier\r\n" +
                    "(1,1) : error 161: unexpected end of program\r\nResult: 2 errors, 0 warnings\r\n", Encoding.Unicode);
                return 0;
            case "many":
                if (File.Exists(ex5)) File.Delete(ex5);
                var text = new StringBuilder(source + "(1,1) : error 100: " + new string('x', 400) + "\r\n");
                for (int i = 2; i <= 60; i++) text.Append(source + "(" + i + ",1) : error 100: problem " + i + "\r\n");
                File.WriteAllText(log, text + "Result: 60 errors, 0 warnings\r\n", Encoding.Unicode);
                return 0;
        }
        File.WriteAllText(ex5, "EX5 " + Guid.NewGuid());
        File.WriteAllText(log, source + " : information: compiling\r\n : information: generating code 100%\r\n" + ok, Encoding.Unicode);
        return 1;
    }
}
