using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

// Starts a program inside a kill-on-close Job Object, so the program and everything it
// starts (tester agents included) stop together: on a timeout, and also when the runner
// itself is killed, because Windows then closes the job handle.
public sealed class OwnedProcess : IDisposable
{
    const uint CREATE_SUSPENDED = 0x4;
    const uint KILL_ON_JOB_CLOSE = 0x2000;
    const int ExtendedLimitInformation = 9;
    const int BasicAccountingInformation = 1;
    const int BasicProcessIdList = 3;

    [StructLayout(LayoutKind.Sequential)]
    struct BasicLimits
    {
        public long PerProcessUserTimeLimit, PerJobUserTimeLimit;
        public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize, MaximumWorkingSetSize;
        public uint ActiveProcessLimit;
        public UIntPtr Affinity;
        public uint PriorityClass, SchedulingClass;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct ExtendedLimits
    {
        public BasicLimits Basic;
        public ulong ReadOps, WriteOps, OtherOps, ReadBytes, WriteBytes, OtherBytes;
        public UIntPtr ProcessMemoryLimit, JobMemoryLimit, PeakProcessMemoryUsed, PeakJobMemoryUsed;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct Accounting
    {
        public long TotalUserTime, TotalKernelTime, ThisPeriodUserTime, ThisPeriodKernelTime;
        public uint TotalPageFaults, TotalProcesses, ActiveProcesses, TotalTerminatedProcesses;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct StartupInfo
    {
        public int cb;
        public string Reserved, Desktop, Title;
        public int X, Y, XSize, YSize, XCountChars, YCountChars, FillAttribute, Flags;
        public short ShowWindow, Reserved2;
        public IntPtr Reserved3, StdInput, StdOutput, StdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct ProcessInfo { public IntPtr Process, Thread; public int ProcessId, ThreadId; }

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr CreateJobObjectW(IntPtr attributes, string name);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool SetInformationJobObject(IntPtr job, int infoClass, ref ExtendedLimits info, int length);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool QueryInformationJobObject(IntPtr job, int infoClass, out Accounting info, int length, IntPtr returned);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool QueryInformationJobObject(IntPtr job, int infoClass, byte[] info, int length, IntPtr returned);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool TerminateJobObject(IntPtr job, uint exitCode);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool CreateProcessW(string application, StringBuilder commandLine, IntPtr processAttributes,
        IntPtr threadAttributes, bool inheritHandles, uint flags, IntPtr environment, string directory,
        ref StartupInfo startup, out ProcessInfo info);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool TerminateProcess(IntPtr process, uint exitCode);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool GetExitCodeProcess(IntPtr process, out uint exitCode);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr handle);

    IntPtr job, process;

    public static OwnedProcess Start(string application, string arguments, string directory)
    {
        var owned = new OwnedProcess();
        owned.job = CreateJobObjectW(IntPtr.Zero, null);
        if (owned.job == IntPtr.Zero) throw new Win32Exception();
        var limits = new ExtendedLimits();
        limits.Basic.LimitFlags = KILL_ON_JOB_CLOSE;
        if (!SetInformationJobObject(owned.job, ExtendedLimitInformation, ref limits, Marshal.SizeOf(limits)))
        {
            var error = new Win32Exception();
            owned.Dispose();
            throw error;
        }

        var startup = new StartupInfo();
        startup.cb = Marshal.SizeOf(startup);
        var commandLine = new StringBuilder("\"" + application + "\" " + arguments);
        ProcessInfo info;
        if (!CreateProcessW(application, commandLine, IntPtr.Zero, IntPtr.Zero, false, CREATE_SUSPENDED,
                IntPtr.Zero, directory, ref startup, out info))
        {
            var error = new Win32Exception();
            owned.Dispose();
            throw error;
        }
        owned.process = info.Process;
        try
        {
            if (!AssignProcessToJobObject(owned.job, info.Process))
            {
                // Never let a child run outside the job: stop it while it is still suspended.
                string reason = new Win32Exception().Message;
                bool stopped = TerminateProcess(info.Process, 1) && WaitForSingleObject(info.Process, 10000) == 0;
                owned.Dispose();
                throw new InvalidOperationException("Process " + info.ProcessId + " could not be put in a job (" + reason + "); " +
                    (stopped ? "it was stopped." : "it could not be confirmed stopped and may still be suspended."));
            }
            if (ResumeThread(info.Thread) == uint.MaxValue)
            {
                var error = new Win32Exception();
                owned.Kill();
                owned.Dispose();
                throw error;
            }
        }
        finally { CloseHandle(info.Thread); }
        return owned;
    }

    public bool WaitForExit(int milliseconds) { return WaitForSingleObject(process, (uint)milliseconds) == 0; }

    public int ExitCode
    {
        get { uint code; GetExitCodeProcess(process, out code); return unchecked((int)code); }
    }

    public void Kill() { TerminateJobObject(job, 1); }

    // True once no process is left in the job.
    public bool WaitForEmpty(int milliseconds)
    {
        DateTime deadline = DateTime.UtcNow.AddMilliseconds(milliseconds);
        while (true)
        {
            Accounting info;
            if (!QueryInformationJobObject(job, BasicAccountingInformation, out info, Marshal.SizeOf(typeof(Accounting)), IntPtr.Zero))
                throw new Win32Exception();
            if (info.ActiveProcesses == 0) return true;
            if (DateTime.UtcNow >= deadline) return false;
            Thread.Sleep(50);
        }
    }

    // Process IDs still in the job, for reporting when it could not be emptied.
    public int[] RemainingProcessIds()
    {
        const int capacity = 256;
        var buffer = new byte[8 + capacity * IntPtr.Size];
        if (!QueryInformationJobObject(job, BasicProcessIdList, buffer, buffer.Length, IntPtr.Zero)) return new int[0];
        int count = BitConverter.ToInt32(buffer, 4);
        var ids = new int[count];
        for (int i = 0; i < count; i++)
            ids[i] = IntPtr.Size == 8 ? (int)BitConverter.ToInt64(buffer, 8 + i * 8) : BitConverter.ToInt32(buffer, 8 + i * 4);
        return ids;
    }

    public void Dispose()
    {
        if (process != IntPtr.Zero) { CloseHandle(process); process = IntPtr.Zero; }
        if (job != IntPtr.Zero) { CloseHandle(job); job = IntPtr.Zero; }
    }
}
