# Compile library: MT5 installation discovery, executable checks and the compile function.
# Dot-sourced by Compile-Mql5.ps1 and Mql5Tester.ps1. It prints nothing; callers print results.

$Mql5ScriptsFolder = $PSScriptRoot

function Stop-Mql5([string]$Message, [int]$ExitCode = 2) {
    $exception = New-Object InvalidOperationException $Message
    $exception.Data['exit_code'] = $ExitCode
    throw $exception
}

function Get-FailureExitCode($ErrorRecord) {
    $code = $ErrorRecord.Exception.Data['exit_code']
    if ($null -eq $code) { 2 } else { [int]$code }
}

function Import-OwnedProcess {
    if (-not ('OwnedProcess' -as [type])) { Add-Type -Path (Join-Path $Mql5ScriptsFolder 'OwnedProcess.cs') }
}

# MetaEditor silently does nothing with a path of 276 characters (measured); stay under MAX_PATH.
function Assert-ShortPath([string]$Path, [string]$Kind) {
    if ($Path.Length -gt 259) { Stop-Mql5 "The $Kind path has $($Path.Length) characters; MetaEditor ignores paths over 259: $Path" }
    $Path
}

# Relative paths resolve against PowerShell's location, which can differ from the process directory.
function Get-FullPath([string]$Path) {
    if (-not [IO.Path]::IsPathRooted($Path)) { $Path = Join-Path (Get-Location).ProviderPath $Path }
    [IO.Path]::GetFullPath($Path)
}

function Read-OriginFile([string]$Path) {
    ([IO.File]::ReadAllText($Path)).Trim([char]0xFEFF, [char]0, ' ', "`r", "`n", "`t").TrimEnd('\')
}

# The origin.txt of every MT5 data folder. The AppData part is escaped, so a user folder with
# brackets in its name is not read as a wildcard.
function Get-OriginFiles([string]$AppData) {
    @(Get-ChildItem -Path (Join-Path ([WildcardPattern]::Escape($AppData)) 'MetaQuotes\Terminal\*\origin.txt') -ErrorAction SilentlyContinue)
}

# Every MT5 install folder that holds $ExeName, from METAEDITOR_EXE, Program Files and AppData origin.txt files.
function Get-Mt5Candidates([string]$ExeName, [string]$AppData) {
    $folders = @()
    if ($env:METAEDITOR_EXE) { $folders += Split-Path -Parent $env:METAEDITOR_EXE }
    if ($env:ProgramFiles) { $folders += Join-Path $env:ProgramFiles 'MetaTrader 5' }
    foreach ($origin in Get-OriginFiles $AppData) {
        try { $folders += Read-OriginFile $origin.FullName } catch { }
    }
    $found = @{}
    foreach ($folder in $folders) {
        if (-not $folder) { continue }
        $exe = Join-Path $folder $ExeName
        if (Test-Path -LiteralPath $exe -PathType Leaf) {
            $full = [IO.Path]::GetFullPath($exe)
            $found[$full.ToLowerInvariant()] = $full
        }
    }
    @($found.Values | Sort-Object)
}

function Select-Mt5Executable([string]$Path, [string]$ExeName, [string]$AppData) {
    if (-not $Path) {
        $found = @(Get-Mt5Candidates $ExeName $AppData)
        if ($found.Count -ne 1) {
            Stop-Mql5 ("Found {0} MT5 installations with {1}; pass the path explicitly. Candidates: {2}" -f $found.Count, $ExeName, ($found -join '; '))
        }
        $Path = $found[0]
    }
    Assert-Mt5Executable $Path $ExeName
}

# Explicit or found, the file must be the named MT5 program, so a compile can never start a terminal.
function Assert-Mt5Executable([string]$Path, [string]$ExeName) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Stop-Mql5 "$ExeName not found: $Path" }
    $full = Get-FullPath $Path
    if ((Split-Path -Leaf $full) -ne $ExeName) { Stop-Mql5 "Expected a file named ${ExeName}: $full" }
    $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($full)
    if ($version.FileMajorPart -ne 5) { Stop-Mql5 "$full is not MetaTrader 5 (file version '$($version.FileVersion)')." }
    $full
}

function Select-MetaEditor([string]$MetaEditorPath, [string]$TerminalPath, [string]$AppData) {
    if ($MetaEditorPath -and $TerminalPath) { Stop-Mql5 'Pass -MetaEditorPath or -TerminalPath, not both.' }
    if ($TerminalPath) { $MetaEditorPath = Join-Path (Split-Path -Parent (Get-FullPath $TerminalPath)) 'metaeditor64.exe' }
    Select-Mt5Executable $MetaEditorPath 'metaeditor64.exe' $AppData
}

function Get-Mql5Root([string]$SourcePath) {
    $folder = Split-Path -Parent $SourcePath
    while ($folder) {
        if ((Split-Path -Leaf $folder) -eq 'MQL5') { return $folder }
        $folder = Split-Path -Parent $folder
    }
    $null
}

# Windows object names cannot hold backslashes, so the lock is named by a hash of the output path.
function Get-CompileLockName([string]$Ex5Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $bytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Ex5Path.ToLowerInvariant())) } finally { $sha.Dispose() }
    'Global\mql5-compile-' + (-join ($bytes[0..11] | ForEach-Object { $_.ToString('x2') }))
}

# The first $Max lines, each cut at 300 characters, with the total and whether anything was cut.
function Get-CappedLines([string[]]$Lines, [int]$Max) {
    $Lines = @($Lines)
    $shown = @($Lines | Select-Object -First $Max)
    [ordered]@{
        lines     = @($shown | ForEach-Object { if ($_.Length -gt 300) { $_.Substring(0, 300) } else { $_ } })
        total     = $Lines.Count
        truncated = ($Lines.Count -gt $Max) -or (@($shown | Where-Object { $_.Length -gt 300 }).Count -gt 0)
    }
}

function Get-FileSha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Set-Outcome($Result, [int]$ExitCode, [string]$Status, $Message) {
    $Result.exit_code = $ExitCode
    $Result.status = $Status
    $Result.message = $Message
    $Result
}

# Compiles one .mq5 and returns an ordered result. Exit codes: 0 fresh artifact, 1 compile errors,
# 2 input or tool failure, 3 timeout. The full log is kept (result.log) whenever any diagnostic was
# cut or the result is a failure; otherwise the temporary folder is deleted.
function Invoke-Mql5Compile {
    param(
        [string]$SourcePath,
        [string]$IncludePath,
        [string]$MetaEditorPath,
        [string]$TerminalPath,
        [int]$TimeoutSeconds = 120,
        [string]$AppData = $env:APPDATA
    )
    $result = [ordered]@{
        status = 'failed'; exit_code = 2; message = $null; source = $SourcePath; editor = $null; editor_build = $null
        errors = $null; warnings = $null; artifact = $null; sha256 = $null
        diagnostics = @(); diagnostic_total = 0; truncated = $false; result_line = $null; log = $null; temp_folder = $null; contained = $true
    }
    $mutex = $null; $held = $false; $job = $null; $jobEmpty = $true; $temp = $null; $log = $null
    try {
        if (-not $SourcePath) { Stop-Mql5 '-SourcePath is required.' }
        $source = Assert-ShortPath (Get-FullPath $SourcePath) 'source'
        $result.source = $source
        if ([IO.Path]::GetExtension($source) -ne '.mq5' -or -not (Test-Path -LiteralPath $source -PathType Leaf)) {
            Stop-Mql5 "The source must be an existing .mq5 file: $source"
        }
        if ($TimeoutSeconds -lt 1) { Stop-Mql5 '-TimeoutSeconds must be at least 1.' }
        $editor = Select-MetaEditor $MetaEditorPath $TerminalPath $AppData
        $result.editor = $editor
        $result.editor_build = [Diagnostics.FileVersionInfo]::GetVersionInfo($editor).FilePrivatePart
        # A trailing backslash would turn /include:"...\" into an escaped quote.
        $include = if ($IncludePath) { (Get-FullPath $IncludePath).TrimEnd('\') } else { Get-Mql5Root $source }
        if ($include) {
            if (-not (Test-Path -LiteralPath $include -PathType Container)) { Stop-Mql5 "Include folder not found: $include" }
            $include = Assert-ShortPath $include 'include'
        }
        $ex5 = [IO.Path]::ChangeExtension($source, '.ex5')

        $mutex = [Threading.Mutex]::new($false, (Get-CompileLockName $ex5))
        try { $held = $mutex.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds)) } catch [Threading.AbandonedMutexException] { $held = $true }
        if (-not $held) { Stop-Mql5 "Another compile of $ex5 is still running." }

        $temp = Join-Path ([IO.Path]::GetTempPath()) ('mql5-compile-' + [Guid]::NewGuid().ToString('N').Substring(0, 12))
        New-Item -ItemType Directory -Path $temp | Out-Null
        $result.temp_folder = $temp
        $log = Assert-ShortPath (Join-Path $temp 'compile.log') 'log'
        $before = Get-Item -LiteralPath $ex5 -ErrorAction SilentlyContinue
        $beforeWrite = if ($before) { $before.LastWriteTimeUtc } else { $null }

        $arguments = "/compile:`"$source`" /log:`"$log`""
        if ($include) { $arguments += " /include:`"$include`"" }
        Import-OwnedProcess
        $job = [OwnedProcess]::Start($editor, $arguments, (Split-Path -Parent $editor))
        # Wait for MetaEditor and anything it started; nothing is read before the job is empty.
        if (-not $job.WaitForEmpty($TimeoutSeconds * 1000)) {
            $job.Kill()
            $jobEmpty = $job.WaitForEmpty(10000)
            if (-not $jobEmpty) { Stop-Mql5 ("MetaEditor processes could not be stopped: " + ($job.RemainingProcessIds() -join ', ')) }
            return Set-Outcome $result 3 'timeout' "MetaEditor did not finish within $TimeoutSeconds s; its process tree was stopped."
        }

        if (-not (Test-Path -LiteralPath $log -PathType Leaf)) { Stop-Mql5 'MetaEditor wrote no log, so nothing was compiled.' }
        $lines = [IO.File]::ReadAllText($log, [Text.Encoding]::Unicode) -split "`r?`n"
        $diagnostics = Get-CappedLines @($lines | Where-Object { $_.Trim() -and $_ -notmatch ' : information: ' -and $_ -notmatch '^Result:' }) 50
        $result.diagnostics = $diagnostics.lines
        $result.diagnostic_total = $diagnostics.total
        $result.truncated = $diagnostics.truncated
        $resultLine = @($lines | Where-Object { $_ -match '^Result:' } | Select-Object -Last 1)
        $counts = [regex]::Match([string]($resultLine -join ''), '^Result:\s*(\d+)\s+errors?,\s*(\d+)\s+warnings?')
        if (-not $counts.Success) { Stop-Mql5 'The compile log has no Result line.' }
        $result.result_line = $resultLine[0].Trim()
        $result.errors = [int]$counts.Groups[1].Value
        $result.warnings = [int]$counts.Groups[2].Value
        if ($result.errors -gt 0) { return Set-Outcome $result 1 'compile_errors' "$($result.errors) compile error(s)." }

        # MetaEditor's exit code means nothing (1 on success); trust only a fresh, nonempty .ex5.
        $after = Get-Item -LiteralPath $ex5 -ErrorAction SilentlyContinue
        if (-not $after -or $after.Length -eq 0 -or ($null -ne $beforeWrite -and $after.LastWriteTimeUtc -eq $beforeWrite)) {
            Stop-Mql5 "MetaEditor reported success but did not write a fresh $ex5."
        }
        $result.artifact = $ex5
        $result.sha256 = Get-FileSha256 $ex5
        return Set-Outcome $result 0 'compiled' $null
    }
    catch {
        return Set-Outcome $result (Get-FailureExitCode $_) 'failed' $_.Exception.Message
    }
    finally {
        $result.contained = $jobEmpty
        if ($job) { $job.Dispose() }
        if ($temp -and (Test-Path -LiteralPath $temp)) {
            if ($jobEmpty -and $result.exit_code -le 1 -and -not $result.truncated) {
                Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
                $result.temp_folder = $null
            }
            elseif ($log -and (Test-Path -LiteralPath $log)) { $result.log = $log }
        }
        if ($held) { $mutex.ReleaseMutex() }
        if ($mutex) { $mutex.Dispose() }
    }
}
