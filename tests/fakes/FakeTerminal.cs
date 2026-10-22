// Stands in for terminal64.exe in tests/Test-Safety.ps1. It reads the /config ini and writes what
// the real tester writes: journal lines, a report with companions, the auto-saved preset and a cache
// file. FAKE_TERMINAL_MODE: pass, hang (spawns a child that holds the report open, then never
// exits), idle (an already running terminal), hold (that child).
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading;

[assembly: System.Reflection.AssemblyFileVersion("5.0.0.4000")]

static class FakeTerminal
{
    static string Env(string name) { return Environment.GetEnvironmentVariable(name); }

    static string Sha256(string path)
    {
        using (var sha = SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(path))).Replace("-", "").ToLowerInvariant();
    }

    static void Journal(string folder, string source, string message)
    {
        Directory.CreateDirectory(folder);
        string path = Path.Combine(folder, DateTime.Now.ToString("yyyyMMdd") + ".log");
        File.AppendAllText(path, "AB\t0\t12:00:00.000\t" + source + "\t" + message + "\r\n", Encoding.Unicode);
    }

    static int Main(string[] args)
    {
        string mode = Env("FAKE_TERMINAL_MODE") ?? "pass";
        if (mode == "hold")
        {
            using (File.Open(args[0], FileMode.Open, FileAccess.Read, FileShare.Read)) Thread.Sleep(Timeout.Infinite);
        }
        if (Env("FAKE_TERMINAL_COUNTER") != null) File.AppendAllText(Env("FAKE_TERMINAL_COUNTER"), "x");
        if (mode == "idle") Thread.Sleep(Timeout.Infinite);

        string ini = args[0].Substring("/config:".Length).Trim('"');
        var tester = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (string line in File.ReadAllLines(ini))
        {
            int equals = line.IndexOf('=');
            if (equals > 0) tester[line.Substring(0, equals)] = line.Substring(equals + 1);
        }
        string data = Env("FAKE_DATA_FOLDER");
        string staged = Path.GetFileNameWithoutExtension(tester["Expert"]);
        // Record what the tester was given, before the auto-saved preset replaces the staged one.
        if (Env("FAKE_SEEN_HASH") != null) File.WriteAllText(Env("FAKE_SEEN_HASH"), Sha256(Path.Combine(data, @"MQL5\Experts", tester["Expert"])));
        if (Env("FAKE_SEEN_SET") != null && tester.ContainsKey("ExpertParameters"))
            File.WriteAllText(Env("FAKE_SEEN_SET"), Sha256(Path.Combine(data, @"MQL5\Profiles\Tester", tester["ExpertParameters"])));

        File.WriteAllText(Path.Combine(data, @"MQL5\Profiles\Tester", staged + ".set"), "; saved automatically\r\n", Encoding.Unicode);
        Directory.CreateDirectory(Path.Combine(data, @"Tester\cache"));
        File.WriteAllText(Path.Combine(data, @"Tester\cache", staged + "." + tester["Symbol"] + "." + tester["Period"] + ".0.tst"), "cache");
        string report = Path.Combine(data, tester["Report"]);
        File.WriteAllText(report + ".htm", "<table><tr><td>Initial Deposit:</td><td><b>10 000.00</b></td></tr>" +
            "<tr><td>Leverage:</td><td><b>1:100</b></td></tr><tr><td>Total Trades:</td><td><b>3</b></td></tr></table>", Encoding.Unicode);
        foreach (string suffix in new[] { ".png", "-hst.png", "-mfemae.png", "-holding.png" }) File.WriteAllText(report + suffix, "png");
        // FAKE_OCCUPY names an output folder; a file already there makes one report move fail.
        if (Env("FAKE_OCCUPY") != null) File.WriteAllText(Path.Combine(Env("FAKE_OCCUPY"), tester["Report"] + ".png"), "occupied");

        if (mode == "hang")
        {
            var start = new ProcessStartInfo(Process.GetCurrentProcess().MainModule.FileName, "\"" + report + ".htm\"") { UseShellExecute = false };
            start.EnvironmentVariables["FAKE_TERMINAL_MODE"] = "hold";
            Process child = Process.Start(start);
            // Written aside, then renamed, so the file only ever appears complete.
            File.WriteAllText(Env("FAKE_PIDS") + ".tmp", Process.GetCurrentProcess().Id + " " + child.Id);
            File.Move(Env("FAKE_PIDS") + ".tmp", Env("FAKE_PIDS"));
            Thread.Sleep(Timeout.Infinite);
        }

        string terminalLogs = Path.Combine(data, "logs"), testerLogs = Path.Combine(data, @"Tester\logs");
        string chart = tester["Symbol"] + "," + tester["Period"] + ": ";
        Journal(terminalLogs, "Startup", "successfully initialized from start config \"" + ini + "\"");
        Journal(terminalLogs, "Tester", "automatic testing started");
        Journal(testerLogs, "Core 01", chart + "testing of Experts\\" + tester["Expert"] + " from " + tester["FromDate"] + " 00:00 to " +
            tester["ToDate"] + " 00:00 started with inputs:");
        Journal(testerLogs, "Core 01", "  InpMarker=" + (Env("FAKE_MARKER") ?? ""));
        if (Env("FAKE_MARKER") != null) Journal(testerLogs, "Core 01", tester["FromDate"] + " 00:00:00   " + Env("FAKE_MARKER"));
        Journal(testerLogs, "Core 01", chart + "100 ticks, 10 bars generated. Test passed in 0:00:00.010.");
        Journal(terminalLogs, "Tester", "last test passed with result \"successfully finished\" in 0:00:00.010");
        return 0;
    }
}
