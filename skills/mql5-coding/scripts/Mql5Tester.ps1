# Tester library: binds the terminal's data folder, stages one freshly compiled Expert Advisor
# under a unique name, runs the Strategy Tester once and decides pass or fail from this run's
# journal lines. Dot-sourced by Invoke-Mt5TesterSmoke.ps1; it prints nothing.

. (Join-Path $PSScriptRoot 'Mql5Compile.ps1')

function Format-TesterDate([datetime]$Date) { $Date.ToString('yyyy.MM.dd', [Globalization.CultureInfo]::InvariantCulture) }

# The last complete calendar month: in January that is December of the previous year.
function Get-DefaultTestDates([datetime]$Now) {
    $first = New-Object DateTime $Now.Year, $Now.Month, 1
    [ordered]@{ from = Format-TesterDate $first.AddMonths(-1); to = Format-TesterDate $first }
}

function ConvertTo-TesterDate([string]$Text, [string]$Name) {
    $date = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($Text, 'yyyy.MM.dd', [Globalization.CultureInfo]::InvariantCulture, 'None', [ref]$date)) {
        Stop-Mql5 "$Name must be a date like 2026.01.31, not '$Text'."
    }
    $date
}

# Parses invariant digits within a range; an empty value gives the default.
function ConvertTo-Bounded([string]$Text, [string]$Name, [decimal]$Min, [decimal]$Max, $Default, [switch]$Fraction) {
    if (-not $Text) { return $Default }
    # \z, not $: $ also matches before a final line break, which must never reach the ini.
    $pattern = if ($Fraction) { '^\d+(\.\d+)?\z' } else { '^-?\d+\z' }
    $value = [decimal]0
    if ($Text -notmatch $pattern -or -not [decimal]::TryParse($Text, 'Number', [Globalization.CultureInfo]::InvariantCulture, [ref]$value) -or
        $value -lt $Min -or $value -gt $Max) {
        Stop-Mql5 "$Name must be a number from $Min to $Max, not '$Text'."
    }
    $value
}

# The journal spells some periods out (D1 seen as Daily, W1 and MN1 measured).
function Get-JournalPeriod([string]$Period) {
    switch ($Period) { 'D1' { 'Daily' } 'W1' { 'Weekly' } 'MN1' { 'Monthly' } default { $Period } }
}

# Gate 1: every setting is checked before anything is created. Invalid input stops with exit 2.
function Resolve-TesterSettings($Options, [datetime]$Now) {
    if (-not $Options.SourcePath) { Stop-Mql5 '-SourcePath is required.' }
    $source = Get-FullPath $Options.SourcePath
    if ([IO.Path]::GetExtension($source) -ne '.mq5' -or -not (Test-Path -LiteralPath $source -PathType Leaf)) {
        Stop-Mql5 "The source must be an existing .mq5 file: $source"
    }
    $symbol = [string]$Options.Symbol
    if (-not $symbol -or $symbol -match '[\p{Cc}=;\\/]') { Stop-Mql5 "-Symbol is required and must not contain line breaks, '=', ';' or path separators." }
    $period = ([string]$Options.Period).ToUpperInvariant()
    if ($period -notmatch '^[A-Z0-9_]+\z') { Stop-Mql5 '-Period is required and may contain only letters, digits and _.' }
    if ([bool]$Options.FromDate -ne [bool]$Options.ToDate) { Stop-Mql5 'Pass -FromDate and -ToDate together, or neither.' }
    $dates = Get-DefaultTestDates $Now
    if ($Options.FromDate) {
        $from = ConvertTo-TesterDate $Options.FromDate '-FromDate'
        $to = ConvertTo-TesterDate $Options.ToDate '-ToDate'
        if ($to -le $from) { Stop-Mql5 '-ToDate must be after -FromDate.' }
        $dates = [ordered]@{ from = Format-TesterDate $from; to = Format-TesterDate $to }
    }
    $currency = [string]$Options.Currency
    if ($currency -and $currency -cnotmatch '^[A-Z]{3,8}\z') { Stop-Mql5 "-Currency must be 3 to 8 uppercase letters, not '$currency'." }
    if ([bool]$Options.SetPath -eq [bool]$Options.UseExpertDefaults) { Stop-Mql5 'Pass exactly one of -SetPath and -UseExpertDefaults.' }
    $setPath = $null
    if ($Options.SetPath) {
        $setPath = Get-FullPath $Options.SetPath
        if (-not (Test-Path -LiteralPath $setPath -PathType Leaf)) { Stop-Mql5 "Set file not found: $setPath" }
    }
    if (-not $Options.OutputDirectory) { Stop-Mql5 '-OutputDirectory is required.' }
    $output = Get-FullPath $Options.OutputDirectory
    if (Test-Path -LiteralPath $output) { Stop-Mql5 "The output folder must not exist yet: $output" }
    if (-not (Test-Path -LiteralPath (Split-Path -Parent $output) -PathType Container)) { Stop-Mql5 "The output folder's parent folder does not exist: $output" }
    $marker = [string]$Options.ExpectedLogMarker
    if ($marker -and $marker -cnotmatch '^MQL5_CODING_PASS:[0-9A-Fa-f]{32,64}(:[A-Za-z0-9_.-]{1,64})?\z') {
        Stop-Mql5 '-ExpectedLogMarker must look like MQL5_CODING_PASS:<32 to 64 hex characters>[:label].'
    }
    $deposit = $null
    if ($Options.Deposit) { [void](ConvertTo-Bounded $Options.Deposit '-Deposit' 1 1000000000 $null -Fraction); $deposit = [string]$Options.Deposit }
    [ordered]@{
        source              = $source
        include             = if ($Options.IncludePath) { Get-FullPath $Options.IncludePath } else { $null }
        symbol              = $symbol
        period              = $period
        journal_period      = Get-JournalPeriod $period
        from                = $dates.from
        to                  = $dates.to
        model               = [int](ConvertTo-Bounded $Options.Model '-Model' 0 4 1)
        execution_mode      = [int](ConvertTo-Bounded $Options.ExecutionMode '-ExecutionMode' -1 600000 0)
        deposit             = $deposit
        currency            = if ($currency) { $currency } else { $null }
        leverage            = if ($Options.Leverage) { [int](ConvertTo-Bounded $Options.Leverage '-Leverage' 1 5000 $null) } else { $null }
        set_path            = $setPath
        use_expert_defaults = [bool]$Options.UseExpertDefaults
        timeout_seconds     = [int](ConvertTo-Bounded $Options.TimeoutSeconds '-TimeoutSeconds' 1 86400 300)
        marker              = if ($marker) { $marker } else { $null }
        output              = $output
    }
}

# Gate 3: MT5 started with /config opens the AppData folder whose origin.txt names its install folder.
function Get-Mt5DataFolder([string]$TerminalPath, [string]$AppData) {
    $install = Split-Path -Parent $TerminalPath
    $found = @()
    foreach ($origin in Get-OriginFiles $AppData) {
        try { $folder = Read-OriginFile $origin.FullName }
        catch { Stop-Mql5 "Cannot read $($origin.FullName), so the data folder is unknown." 4 }
        if ($folder -eq $install) { $found += $origin.DirectoryName }
    }
    if ($found.Count -ne 1) { Stop-Mql5 ("Expected one data folder for {0}, found {1}. Start the terminal once normally so it creates one." -f $install, $found.Count) 4 }
    $found[0]
}

# Gate 4: MT5 cannot run two copies from one install folder.
function Assert-TerminalNotRunning([string]$TerminalPath) {
    foreach ($process in @(Get-Process -Name terminal64 -ErrorAction SilentlyContinue)) {
        $path = $null
        try { $path = $process.Path } catch { }
        if (-not $path) { Stop-Mql5 "The path of terminal64.exe (PID $($process.Id)) cannot be read, so it may be the selected terminal." 4 }
        if ($path -eq $TerminalPath) { Stop-Mql5 "The selected terminal is already running (PID $($process.Id)). Close it and rerun." 4 }
    }
}

# The same lock file as v1, so old and new runners never share a data folder.
function Open-RunLock([string]$DataFolder) {
    $path = Join-Path $DataFolder '.mql5-coding-smoke.data-lock'
    try { [IO.FileStream]::new($path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None, 1, [IO.FileOptions]::DeleteOnClose) }
    catch [IO.IOException] { Stop-Mql5 "Another tester run holds $path; wait for it to finish and retry. Do not close its terminal." 4 }
}

function Copy-StagedExpert([string]$Source, [string]$Destination, [string]$ExpectedSha256) {
    Copy-Item -LiteralPath $Source -Destination $Destination -ErrorAction Stop
    if ((Get-FileSha256 $Destination) -ne $ExpectedSha256) { Stop-Mql5 'The staged copy does not match the build this run compiled.' }
}

function New-TesterIni($Settings, [string]$Staged) {
    $lines = @('[Common]', 'NewsEnable=0', '[Experts]', 'AllowLiveTrading=0', 'AllowDllImport=0', '[Tester]', "Expert=Mql5Smoke\$Staged.ex5")
    if (-not $Settings.use_expert_defaults) { $lines += "ExpertParameters=$Staged.set" }
    $lines += "Symbol=$($Settings.symbol)", "Period=$($Settings.period)", "Model=$($Settings.model)",
        "ExecutionMode=$($Settings.execution_mode)", "FromDate=$($Settings.from)", "ToDate=$($Settings.to)"
    if ($Settings.deposit) { $lines += "Deposit=$($Settings.deposit)" }
    if ($Settings.currency) { $lines += "Currency=$($Settings.currency)" }
    # MT5 ignores a bare Leverage=<n> and keeps the previous run's value (measured).
    if ($Settings.leverage) { $lines += "Leverage=1:$($Settings.leverage)" }
    $lines += 'Optimization=0', 'ForwardMode=0', "Report=$Staged", 'ReplaceReport=1', 'ShutdownTerminal=1',
        'UseLocal=1', 'UseRemote=0', 'UseCloud=0', 'Visual=0'
    if ($Settings.use_expert_defaults) { $lines += '[TesterInputs]' }
    ($lines -join "`r`n") + "`r`n"
}

function Get-JournalFiles([string]$Folder) {
    @(Get-ChildItem -LiteralPath $Folder -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{8}\.log$' } | Sort-Object Name)
}

function Get-JournalLengths([string]$DataFolder) {
    $lengths = @{}
    foreach ($folder in (Join-Path $DataFolder 'logs'), (Join-Path $DataFolder 'Tester\logs')) {
        foreach ($file in Get-JournalFiles $folder) { $lengths[$file.FullName] = $file.Length }
    }
    $lengths
}

function Read-FileRange([string]$Path, [long]$Start, [long]$End) {
    $stream = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite, Delete')
    try {
        [void]$stream.Seek($Start, 'Begin')
        $bytes = New-Object byte[] ($End - $Start)
        $read = 0
        while ($read -lt $bytes.Length) {
            $count = $stream.Read($bytes, $read, $bytes.Length - $read)
            if ($count -le 0) { break }
            $read += $count
        }
        [Text.Encoding]::Unicode.GetString($bytes, 0, $read)
    }
    finally { $stream.Dispose() }
}

# Journal lines are tab-separated: code, level, time, source, message.
function ConvertTo-JournalRecord([string]$Line) {
    $fields = $Line -split "`t", 5
    if ($fields.Count -lt 5) { return $null }
    $message = $fields[4]
    # Application output carries the simulated time; echoed inputs look like name=value, so a
    # string input can never pose as a status record.
    $kind = if ($message -match '^\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}') { 'app' }
            elseif ($message -match '^\s*[A-Za-z_]\w*=') { 'input' }
            else { 'system' }
    [pscustomobject]@{ kind = $kind; message = $message }
}

# Only the bytes appended since the run started; files new since then (midnight rollover) whole.
function Read-AppendedJournal([string]$Folder, $Lengths) {
    $records = New-Object Collections.Generic.List[object]
    $ranges = @()
    foreach ($file in Get-JournalFiles $Folder) {
        $start = if ($Lengths.ContainsKey($file.FullName)) { [long]$Lengths[$file.FullName] } else { 0L }
        if ($file.Length -lt $start) { Stop-Mql5 "The journal $($file.FullName) got shorter during the run." }
        if ($file.Length -eq $start) { continue }
        $ranges += [ordered]@{ path = $file.FullName; start = $start; end = $file.Length }
        foreach ($line in (Read-FileRange $file.FullName $start $file.Length).TrimStart([char]0xFEFF) -split "`r?`n") {
            $record = ConvertTo-JournalRecord $line
            if ($record) { $records.Add($record) }
        }
    }
    [ordered]@{ records = $records.ToArray(); ranges = $ranges }
}

# Index of the first system record at or after $From that starts with $Prefix and contains $Text.
function Find-SystemRecord($Records, [int]$From, [string]$Text, [string]$Prefix = '') {
    for ($i = [Math]::Max($From, 0); $i -lt $Records.Count; $i++) {
        $message = $Records[$i].message
        if ($Records[$i].kind -eq 'system' -and $message.StartsWith($Prefix, [StringComparison]::OrdinalIgnoreCase) -and
            $message.IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $i }
    }
    -1
}

function Get-LastSystemRecords($Records, [int]$From) {
    $system = @(for ($i = [Math]::Max($From, 0); $i -lt $Records.Count; $i++) { if ($Records[$i].kind -eq 'system') { $Records[$i].message } })
    (Get-CappedLines @($system | Select-Object -Last 10) 10).lines
}

# Pass rules: decides the outcome from this run's journal records and fills checks and evidence.
function Set-SmokeVerdict($Result, $Terminal, $Tester, $Settings, [string]$IniPath, [string]$Staged, [bool]$Exited) {
    $t = @($Terminal.records); $q = @($Tester.records)
    $checks = [ordered]@{}
    $configAt = Find-SystemRecord $t 0 "successfully initialized from start config `"$IniPath`""
    $startedAt = if ($configAt -ge 0) { Find-SystemRecord $t ($configAt + 1) 'automatic testing started' } else { -1 }
    $finishedAt = if ($startedAt -ge 0) { Find-SystemRecord $t ($startedAt + 1) 'last test passed with result "successfully finished"' } else { -1 }
    $checks.start_config_loaded = $configAt -ge 0
    $checks.testing_started = $startedAt -ge 0
    $checks.terminal_reported_pass = $finishedAt -ge 0

    $starts = @(for ($i = 0; $i -lt $q.Count; $i++) { if ($q[$i].kind -eq 'system' -and $q[$i].message -match 'testing of Experts\\.* started with inputs:') { $i } })
    $prefix = "$($Settings.symbol),$($Settings.journal_period): "
    $expected = "${prefix}testing of Experts\Mql5Smoke\$Staged.ex5 from $($Settings.from) 00:00 to $($Settings.to) 00:00 started with inputs:"
    $startAt = if ($starts.Count -eq 1 -and $q[$starts[0]].message.StartsWith($expected, [StringComparison]::OrdinalIgnoreCase)) { $starts[0] } else { -1 }
    $passAt = if ($startAt -ge 0) { Find-SystemRecord $q ($startAt + 1) 'Test passed in' $prefix } else { -1 }
    $checks.single_test_start = $starts.Count -eq 1
    $checks.expected_test_start = $startAt -ge 0
    $checks.test_passed = $passAt -ge 0
    $checks.no_oninit_failure = (Find-SystemRecord $q 0 'tester stopped because OnInit returns non-zero') -lt 0
    if ($Settings.marker) {
        $seen = $false
        for ($i = $startAt + 1; $startAt -ge 0 -and $i -lt $passAt; $i++) {
            if ($q[$i].kind -eq 'app' -and ($q[$i].message -replace '^\S+ \S+\s*', '').Trim() -ceq $Settings.marker) { $seen = $true }
        }
        $checks.marker_seen = $seen
    }
    $checks.terminal_exited_by_itself = $Exited

    $Result.checks = $checks
    # A negative index would read from the end of the array, so only found records are listed.
    $Result.matched_lines = @(
        foreach ($hit in @($t, $configAt), @($t, $startedAt), @($t, $finishedAt), @($q, $startAt), @($q, $passAt)) {
            if ($hit[1] -ge 0) { $hit[0][$hit[1]].message }
        })
    $failed = @($checks.Keys | Where-Object { -not $checks[$_] })
    $Result.failed_checks = $failed
    $context = @()
    $terminalFailed = @($failed | Where-Object { $_ -in 'start_config_loaded', 'testing_started', 'terminal_reported_pass' })
    if ($terminalFailed) { $context += [ordered]@{ journal = 'terminal'; checks = $terminalFailed; records = Get-LastSystemRecords $t 0 } }
    $testerFailed = @($failed | Where-Object { $_ -in 'single_test_start', 'expected_test_start', 'test_passed', 'no_oninit_failure', 'marker_seen' })
    if ($testerFailed) { $context += [ordered]@{ journal = 'tester'; checks = $testerFailed; records = Get-LastSystemRecords $q $startAt } }
    $Result.failure_context = $context
    $errors = Get-CappedLines @(($t + $q) | Where-Object { $_.message -match 'error|failed|cannot|critical' } | ForEach-Object { $_.message }) 20
    $Result.error_lines = $errors
    $Result.journals = @($Terminal.ranges) + @($Tester.ranges)

    $phraseSeen = $false
    foreach ($record in $t) {
        foreach ($phrase in 'successfully initialized from start config', 'automatic testing started', 'last test passed with result') {
            if ($record.kind -eq 'system' -and $record.message.Contains($phrase)) { $phraseSeen = $true }
        }
    }
    if (-not $phraseSeen) {
        return Set-Outcome $Result 2 'journal_phrases_not_found' 'No expected English phrase appeared in the terminal journal: MT5 must run in English, or the start config was not loaded.'
    }
    if ($failed.Count -eq 0) {
        $status = if ($Settings.marker) { 'application_marker_passed' } else { 'engine_smoke_passed' }
        return Set-Outcome $Result 0 $status $null
    }
    Set-Outcome $Result 1 'failed_checks' ('Failed checks: ' + ($failed -join ', '))
}

function Get-ReportHeadline([string]$ReportPath) {
    $labels = [ordered]@{
        initial_deposit = 'Initial Deposit'; currency = 'Currency'; leverage = 'Leverage'; total_net_profit = 'Total Net Profit'
        total_trades = 'Total Trades'; profit_factor = 'Profit Factor'; expected_payoff = 'Expected Payoff'
        balance_drawdown_maximal = 'Balance Drawdown Maximal'; equity_drawdown_relative = 'Equity Drawdown Relative'
    }
    $bytes = [IO.File]::ReadAllBytes($ReportPath)
    $html = if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { [Text.Encoding]::Unicode.GetString($bytes) } else { [Text.Encoding]::UTF8.GetString($bytes) }
    $values = [ordered]@{}
    foreach ($key in $labels.Keys) {
        $match = [regex]::Match($html, [regex]::Escape($labels[$key]) + ':</td>\s*<td[^>]*><b>([^<]*)</b>')
        $values[$key] = if ($match.Success) { $match.Groups[1].Value.Trim() } else { $null }
    }
    $values
}

function Get-ReportFiles($Staging) {
    foreach ($suffix in '.htm', '.png', '-hst.png', '-mfemae.png', '-holding.png') { Join-Path $Staging.data ($Staging.staged + $suffix) }
}

# Moves the reports without overwriting and deletes, by literal path, only files carrying the run id.
function Invoke-SmokeCleanup($Staging, [string]$OutputFolder, [bool]$JobEmpty) {
    $cleanup = [ordered]@{ ok = $true; moved = @(); removed = @(); left = @(); errors = @() }
    $reports = @(Get-ReportFiles $Staging)
    $owned = @($Staging.ex5, $Staging.set, $Staging.ini) + @(Get-ChildItem -LiteralPath (Join-Path $Staging.data 'Tester\cache') `
        -Filter "$($Staging.staged).*.tst" -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    if (-not $JobEmpty) {
        $cleanup.ok = $false
        $cleanup.left = @(($reports + $owned) | Where-Object { Test-Path -LiteralPath $_ })
        $cleanup.errors = @('MT5 processes were still running, so nothing was moved or deleted.')
        return $cleanup
    }
    foreach ($report in $reports) {
        if (-not (Test-Path -LiteralPath $report)) { continue }
        $target = Join-Path $OutputFolder (Split-Path -Leaf $report)
        try { Move-Item -LiteralPath $report -Destination $target -ErrorAction Stop; $cleanup.moved += $target }
        catch {
            $cleanup.ok = $false
            $cleanup.errors += $_.Exception.Message
            $cleanup.left += @(@($report, $target) | Where-Object { Test-Path -LiteralPath $_ })
        }
    }
    foreach ($file in $owned) {
        if (-not (Test-Path -LiteralPath $file)) { continue }
        try { Remove-Item -LiteralPath $file -Force -ErrorAction Stop; $cleanup.removed += $file }
        catch { $cleanup.ok = $false; $cleanup.errors += $_.Exception.Message; $cleanup.left += $file }
    }
    $folder = $Staging.smoke_folder
    if ($Staging.created_smoke_folder -and (Test-Path -LiteralPath $folder) -and -not (Get-ChildItem -LiteralPath $folder -Force)) {
        try { Remove-Item -LiteralPath $folder -ErrorAction Stop }
        catch { $cleanup.ok = $false; $cleanup.errors += $_.Exception.Message; $cleanup.left += $folder }
    }
    $cleanup
}

function Save-CompileEvidence($Compile, [string]$OutputFolder) {
    $evidence = [ordered]@{}
    foreach ($key in 'status', 'exit_code', 'message', 'errors', 'warnings', 'sha256', 'diagnostics', 'diagnostic_total', 'truncated') { $evidence[$key] = $Compile[$key] }
    $evidence.log = $null
    if ($Compile.log) {
        $evidence.log = Join-Path $OutputFolder 'compile.log'
        Copy-Item -LiteralPath $Compile.log -Destination $evidence.log -ErrorAction Stop
    }
    # Unless MetaEditor's processes were confirmed stopped, its folder stays for recovery.
    if ($Compile.temp_folder -and $Compile.contained) { Remove-Item -LiteralPath $Compile.temp_folder -Recurse -Force -ErrorAction SilentlyContinue }
    elseif ($Compile.temp_folder) { $evidence.temp_folder = $Compile.temp_folder }
    $evidence
}

# Claims the output folder for this run alone: creating result.json create-only is atomic, so two
# runs given the same new folder can never share it.
function New-OutputFolder([string]$Path) {
    [void][IO.Directory]::CreateDirectory($Path)
    try { [IO.File]::Open((Join-Path $Path 'result.json'), [IO.FileMode]::CreateNew, [IO.FileAccess]::Write).Dispose() }
    catch [IO.IOException] { Stop-Mql5 "Another run already uses the output folder: $Path" }
}

# A result.json that cannot be written turns the run into exit 2 instead of pointing at a missing file.
function Save-SmokeResult($Result) {
    $Result.result_json = Join-Path $Result.output_folder 'result.json'
    try { [IO.File]::WriteAllText($Result.result_json, ($Result | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding $false)) }
    catch {
        $Result.result_json = $null
        if (-not $Result.Contains('primary_status')) { $Result.primary_status = $Result.status; $Result.primary_exit_code = $Result.exit_code }
        [void](Set-Outcome $Result 2 'failed' "result.json could not be written: $($_.Exception.Message)")
    }
}

# One smoke run. Exit codes: 0 passed, 1 a pass rule failed, 2 input, compile, tool, evidence or
# cleanup failure, 3 timeout, 4 blocked by a gate before launch. Returns the ordered result.
function Invoke-Mt5Smoke {
    param(
        [string]$SourcePath, [string]$IncludePath, [string]$Symbol, [string]$Period, [string]$FromDate, [string]$ToDate,
        [string]$Model, [string]$Deposit, [string]$Currency, [string]$Leverage, [string]$ExecutionMode,
        [string]$SetPath, [switch]$UseExpertDefaults, [string]$OutputDirectory, [string]$TerminalPath,
        [string]$TimeoutSeconds, [string]$ExpectedLogMarker, [string]$AppData = $env:APPDATA, [datetime]$Now = (Get-Date)
    )
    $result = [ordered]@{
        status = 'failed'; exit_code = 2; message = $null; run_id = $null; settings = $null; terminal = $null
        terminal_build = $null; data_folder = $null; output_folder = $null; compile = $null; artifact = $null; sha256 = $null
        staged_name = $null; terminal_exit_code = $null; checks = $null; failed_checks = @(); matched_lines = @()
        failure_context = @(); error_lines = $null; journals = @(); headline = $null; report = $null; cleanup = $null; result_json = $null
    }
    $lock = $null; $job = $null; $jobEmpty = $true; $staging = $null
    try {
        $settings = Resolve-TesterSettings $PSBoundParameters $Now
        $result.settings = $settings
        try { $terminal = Select-Mt5Executable $TerminalPath 'terminal64.exe' $AppData }
        catch { Stop-Mql5 $_.Exception.Message 4 }
        $result.terminal = $terminal
        $result.terminal_build = [Diagnostics.FileVersionInfo]::GetVersionInfo($terminal).FilePrivatePart
        $data = Get-Mt5DataFolder $terminal $AppData
        $result.data_folder = $data
        # Lock first: a terminal started by another run (from any chat) then reports as that run's
        # held lock, meaning wait, rather than as a running terminal the caller might close.
        $lock = Open-RunLock $data
        Assert-TerminalNotRunning $terminal
        if (Test-Path -LiteralPath $settings.output) { Stop-Mql5 "The output folder must not exist yet: $($settings.output)" }
        New-OutputFolder $settings.output
        $result.output_folder = $settings.output

        $editor = Join-Path (Split-Path -Parent $terminal) 'metaeditor64.exe'
        $compile = Invoke-Mql5Compile -SourcePath $settings.source -IncludePath $settings.include -MetaEditorPath $editor -AppData $AppData
        $result.compile = Save-CompileEvidence $compile $settings.output
        if ($compile.exit_code -ne 0) { Stop-Mql5 "The compile did not succeed ($($compile.status)): $($compile.message)" }
        $result.artifact = $compile.artifact
        $result.sha256 = $compile.sha256

        $runId = 's' + [Guid]::NewGuid().ToString('N').Substring(0, 10)
        $staged = [IO.Path]::GetFileNameWithoutExtension($settings.source) + '-' + $runId
        $result.run_id = $runId
        $result.staged_name = $staged
        $smokeFolder = Join-Path $data 'MQL5\Experts\Mql5Smoke'
        $staging = [ordered]@{
            data = $data; staged = $staged; smoke_folder = $smokeFolder; created_smoke_folder = $false
            ex5 = Join-Path $smokeFolder "$staged.ex5"; set = Join-Path $data "MQL5\Profiles\Tester\$staged.set"; ini = Join-Path $data "$staged.ini"
        }
        if (-not (Test-Path -LiteralPath $smokeFolder)) { [void][IO.Directory]::CreateDirectory($smokeFolder); $staging.created_smoke_folder = $true }
        Copy-StagedExpert $compile.artifact $staging.ex5 $compile.sha256
        if ($settings.set_path) {
            [void][IO.Directory]::CreateDirectory((Split-Path -Parent $staging.set))
            Copy-Item -LiteralPath $settings.set_path -Destination $staging.set -ErrorAction Stop
        }
        [IO.File]::WriteAllText($staging.ini, (New-TesterIni $settings $staged), [Text.Encoding]::Unicode)
        Copy-Item -LiteralPath $staging.ini -Destination (Join-Path $settings.output "$staged.ini") -ErrorAction Stop
        $lengths = Get-JournalLengths $data
        Assert-TerminalNotRunning $terminal

        Import-OwnedProcess
        $job = [OwnedProcess]::Start($terminal, "/config:`"$($staging.ini)`"", (Split-Path -Parent $terminal))
        $exited = $job.WaitForExit($settings.timeout_seconds * 1000)
        if ($exited) { $result.terminal_exit_code = $job.ExitCode }
        # Stop anything still in the job, such as a lingering tester agent, before reading evidence.
        $job.Kill()
        $jobEmpty = $job.WaitForEmpty(30000)
        if (-not $jobEmpty) { Stop-Mql5 ('MT5 processes could not be stopped: ' + ($job.RemainingProcessIds() -join ', ')) }

        $terminalJournal = Read-AppendedJournal (Join-Path $data 'logs') $lengths
        $testerJournal = Read-AppendedJournal (Join-Path $data 'Tester\logs') $lengths
        [void](Set-SmokeVerdict $result $terminalJournal $testerJournal $settings $staging.ini $staged $exited)
        if (-not $exited) { [void](Set-Outcome $result 3 'timeout' "MT5 did not finish within $($settings.timeout_seconds) s; its process tree was stopped.") }
    }
    catch {
        $code = Get-FailureExitCode $_
        [void](Set-Outcome $result $code $(if ($code -eq 4) { 'blocked' } else { 'failed' }) $_.Exception.Message)
    }
    finally {
        try {
            if ($staging) {
                $result.cleanup = Invoke-SmokeCleanup $staging $settings.output $jobEmpty
                if (-not $result.cleanup.ok) {
                    $result.primary_status = $result.status
                    $result.primary_exit_code = $result.exit_code
                    [void](Set-Outcome $result 2 'cleanup_failed' 'Cleanup left files behind; they are listed in cleanup.left.')
                }
                $report = @(@($result.cleanup.moved) + @(Get-ReportFiles $staging) | Where-Object { $_ -like '*.htm' -and (Test-Path -LiteralPath $_) })
                if ($report) {
                    $result.report = $report[0]
                    try { $result.headline = Get-ReportHeadline $report[0] } catch { }
                }
            }
            if ($job) { $job.Dispose() }
            if ($result.output_folder) { Save-SmokeResult $result }
        }
        finally { if ($lock) { $lock.Dispose() } }
    }
    $result
}
