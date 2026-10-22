# Safety tests for the mql5-coding scripts. Fake MetaEditor and MT5 programs (tests/fakes, built with
# the .NET Framework csc.exe) stand in for the real ones, so no MT5, account or network is needed.
# Run under both shells: powershell -File tests/Test-Safety.ps1 and pwsh -File tests/Test-Safety.ps1
$ErrorActionPreference = 'Stop'
$scripts = Join-Path (Split-Path -Parent $PSScriptRoot) 'skills\mql5-coding\scripts'
. (Join-Path $scripts 'Mql5Tester.ps1')

$failures = 0
function Check([string]$Name, [bool]$Condition) {
    if ($Condition) { Write-Host "ok   $Name" } else { Write-Host "FAIL $Name"; $script:failures++ }
}

# Fixture: an install folder and an AppData data folder bound to it by origin.txt, all with spaces;
# the AppData name also has brackets, which PowerShell would otherwise read as a wildcard.
$root = Join-Path ([IO.Path]::GetTempPath()) ('mql5 safety ' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$install = Join-Path $root 'MT5 Install'
$appData = Join-Path $root 'App Data [1]'
$data = Join-Path $appData 'MetaQuotes\Terminal\FAKE0001'
$project = Join-Path $root 'My Project'
foreach ($folder in $install, $project, "$data\MQL5\Profiles\Tester", "$data\MQL5\Experts", "$data\logs", "$data\Tester\logs") {
    [void][IO.Directory]::CreateDirectory($folder)
}
[IO.File]::WriteAllText("$data\origin.txt", $install, [Text.Encoding]::Unicode)
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$editor = "$install\metaeditor64.exe"
$terminal = "$install\terminal64.exe"
& $csc /nologo /out:"$editor" (Join-Path $PSScriptRoot 'fakes\FakeMetaEditor.cs') | Out-Null
& $csc /nologo /out:"$terminal" (Join-Path $PSScriptRoot 'fakes\FakeTerminal.cs') | Out-Null
$source = "$project\Smoke EA.mq5"
$ex5 = "$project\Smoke EA.ex5"
[IO.File]::WriteAllText($source, '// fake source')
$setFile = "$project\inputs.set"
[IO.File]::WriteAllText($setFile, "InpMarker=x`r`n", [Text.Encoding]::Unicode)
$userPreset = "$data\MQL5\Profiles\Tester\Smoke EA.set"
[IO.File]::WriteAllText($userPreset, 'user preset')
$marker = 'MQL5_CODING_PASS:' + ('ab' * 16)
$editorCount = "$root\editor-count.txt"
$terminalCount = "$root\terminal-count.txt"
$env:FAKE_DATA_FOLDER = $data
$env:FAKE_EDITOR_COUNTER = $editorCount
$env:FAKE_TERMINAL_COUNTER = $terminalCount

function Get-Count([string]$Path) { if (Test-Path -LiteralPath $Path) { (Get-Content -LiteralPath $Path -Raw).Length } else { 0 } }
function Reset-Fakes([string]$EditorMode = 'ok', [string]$TerminalMode = 'pass') {
    $env:FAKE_EDITOR_MODE = $EditorMode
    $env:FAKE_TERMINAL_MODE = $TerminalMode
    Remove-Item -LiteralPath $editorCount, $terminalCount -ErrorAction SilentlyContinue
}
$runs = 0
function Invoke-Smoke([hashtable]$Extra = @{}) {
    $script:runs++
    $options = @{ SourcePath = $source; Symbol = 'EURUSD'; Period = 'H1'; UseExpertDefaults = $true; TerminalPath = $terminal
        OutputDirectory = "$root\out$($script:runs)"; TimeoutSeconds = '20'; AppData = $appData }
    foreach ($key in $Extra.Keys) { $options[$key] = $Extra[$key] }
    Invoke-Mt5Smoke @options
}
function Get-LastOutput { "$root\out$($script:runs)" }
function Get-SmokeFiles { @(Get-ChildItem -LiteralPath "$data\MQL5\Experts\Mql5Smoke" -File -ErrorAction SilentlyContinue | Where-Object Name -ne 'user.ex5') }

try {
    # Group 2: startup ini and editor selection
    $plain = Resolve-TesterSettings @{ SourcePath = $source; Symbol = 'EURUSD'; Period = 'h1'; UseExpertDefaults = $true; OutputDirectory = "$root\never" } (Get-Date)
    $ini = New-TesterIni $plain 'Smoke EA-s0123456789'
    Check 'ini: live trading, DLLs, optimization and cloud are off' (($ini -match '(?m)^AllowLiveTrading=0\r$') -and ($ini -match '(?m)^AllowDllImport=0\r$') -and
        ($ini -match '(?m)^Optimization=0\r$') -and ($ini -match '(?m)^UseCloud=0\r$'))
    Check 'ini: no account keys, empty [TesterInputs] for defaults' (($ini -notmatch '(?mi)^(Login|Password|Server)=') -and ($ini -match '(?m)^\[TesterInputs\]\r$'))
    Check 'ini: omitted deposit, currency and leverage are absent; execution mode 0; period upper-cased' (($ini -notmatch '(?m)^(Deposit|Currency|Leverage)=') -and
        ($ini -match '(?m)^ExecutionMode=0\r$') -and ($ini -match '(?m)^Period=H1\r$'))
    $leveraged = Resolve-TesterSettings @{ SourcePath = $source; Symbol = 'EURUSD'; Period = 'H1'; SetPath = $setFile; OutputDirectory = "$root\never"; Leverage = '100' } (Get-Date)
    Check 'ini: -Leverage 100 is written as Leverage=1:100' ((New-TesterIni $leveraged 'x') -match '(?m)^Leverage=1:100\r$')
    $jan = Get-DefaultTestDates (Get-Date -Year 2026 -Month 1 -Day 15)
    $mar = Get-DefaultTestDates (Get-Date -Year 2026 -Month 3 -Day 10)
    Check 'default dates: last complete month, January rollover' (($jan.from -eq '2025.12.01') -and ($jan.to -eq '2026.01.01') -and ($mar.from -eq '2026.02.01') -and ($mar.to -eq '2026.03.01'))

    Reset-Fakes
    $r = Invoke-Smoke @{ Symbol = "EURUSD`r`n[Experts]`r`nAllowLiveTrading=1`r`nAllowDllImport=1" }
    Check 'symbol with line breaks: exit 2 before anything starts or is created' (($r.exit_code -eq 2) -and ((Get-Count $editorCount) -eq 0) -and
        ((Get-Count $terminalCount) -eq 0) -and -not (Test-Path -LiteralPath (Get-LastOutput)) -and (@(Get-ChildItem -LiteralPath $data -Filter *.ini -File).Count -eq 0))
    Check 'symbol with = is rejected' ((Invoke-Smoke @{ Symbol = 'EUR=USD' }).exit_code -eq 2)
    Check 'period or deposit ending in a line break is rejected' (((Invoke-Smoke @{ Period = "H1`n" }).exit_code -eq 2) -and
        ((Invoke-Smoke @{ Deposit = "10000`n" }).exit_code -eq 2) -and ((Get-Count $editorCount) -eq 0))
    $c = Invoke-Mql5Compile -SourcePath $source -MetaEditorPath $terminal
    Check '-MetaEditorPath pointing at a terminal: exit 2, nothing starts' (($c.exit_code -eq 2) -and ((Get-Count $terminalCount) -eq 0))

    # Group 3: stale artifact and compile results
    Reset-Fakes 'nolog'
    Check 'editor that writes no log: exit 2' ((Invoke-Mql5Compile -SourcePath $source -MetaEditorPath $editor).exit_code -eq 2)
    [IO.File]::WriteAllText($ex5, 'old build')
    (Get-Item -LiteralPath $ex5).LastWriteTimeUtc = Get-Date -Year 2020 -Month 1 -Day 1
    $oldHash = Get-FileSha256 $ex5
    Reset-Fakes 'stale'
    $c = Invoke-Mql5Compile -SourcePath $source -MetaEditorPath $editor
    Check 'clean log but untouched .ex5: exit 2, no artifact' (($c.exit_code -eq 2) -and -not $c.sha256)
    $r = Invoke-Smoke
    Check 'tester with an untouched .ex5: exit 2, terminal never starts, old build unchanged' (($r.exit_code -eq 2) -and ((Get-Count $terminalCount) -eq 0) -and
        ((Get-FileSha256 $ex5) -eq $oldHash) -and ((Get-SmokeFiles).Count -eq 0))
    Check 'tester with an untouched .ex5: result.json records the failed compile' (($r.compile.status -eq 'failed') -and
        ((Get-Content -LiteralPath "$(Get-LastOutput)\result.json" -Raw | ConvertFrom-Json).compile.status -eq 'failed'))
    Reset-Fakes 'child'
    $c = Invoke-Mql5Compile -SourcePath $source -MetaEditorPath $editor
    Check 'editor whose child writes the results later is waited for' (($c.exit_code -eq 0) -and ((Get-FileSha256 $ex5) -eq $c.sha256))
    $threw = try { Copy-StagedExpert $ex5 "$root\copy.ex5" ('0' * 64); $false } catch { (Get-FailureExitCode $_) -eq 2 }
    Check 'staged copy with another hash: exit 2' $threw
    Reset-Fakes 'errors'
    $c = Invoke-Mql5Compile -SourcePath $source -MetaEditorPath $editor
    Check 'compile errors: exit 1, both diagnostics shown, log deleted' (($c.exit_code -eq 1) -and (@($c.diagnostics).Count -eq 2) -and -not $c.log -and -not $c.temp_folder)
    Reset-Fakes 'many'
    $c = Invoke-Mql5Compile -SourcePath $source -MetaEditorPath $editor
    Check 'cut diagnostics: 50 of 60 shown, long line shortened, full log kept' (($c.exit_code -eq 1) -and (@($c.diagnostics).Count -eq 50) -and
        ($c.diagnostic_total -eq 60) -and ($c.diagnostics[0].Length -eq 300) -and $c.truncated -and (Test-Path -LiteralPath $c.log))
    Remove-Item -LiteralPath $c.temp_folder -Recurse -Force
    Reset-Fakes 'hang'
    $c = Invoke-Mql5Compile -SourcePath $source -MetaEditorPath $editor -TimeoutSeconds 2
    Check 'compile timeout: exit 3, log folder kept' (($c.exit_code -eq 3) -and (Test-Path -LiteralPath $c.temp_folder))
    Remove-Item -LiteralPath $c.temp_folder -Recurse -Force

    # Group 1: terminal gates and containment
    Reset-Fakes 'ok' 'idle'
    $idle = Start-Process -FilePath $terminal -PassThru
    try {
        Reset-Fakes
        $r = Invoke-Smoke
        Check 'running terminal: exit 4, nothing compiled or created' (($r.exit_code -eq 4) -and ((Get-Count $editorCount) -eq 0) -and -not (Test-Path -LiteralPath (Get-LastOutput)))
    }
    finally { Stop-Process -Id $idle.Id -Force; $idle.WaitForExit() }
    $lock = Open-RunLock $data
    try {
        $r = Invoke-Smoke
        Check 'held run lock: exit 4, nothing compiled or created' (($r.exit_code -eq 4) -and ((Get-Count $editorCount) -eq 0) -and -not (Test-Path -LiteralPath (Get-LastOutput)))
    }
    finally { $lock.Dispose() }
    $empty = Join-Path $root 'Empty AppData'
    [void][IO.Directory]::CreateDirectory($empty)
    Check 'no data folder for the install: exit 4' ((Invoke-Smoke @{ AppData = $empty }).exit_code -eq 4)
    Check 'no terminal at -TerminalPath: exit 4' ((Invoke-Smoke @{ TerminalPath = "$root\missing\terminal64.exe" }).exit_code -eq 4)
    $twin = Join-Path $appData 'MetaQuotes\Terminal\FAKE0002'
    [void][IO.Directory]::CreateDirectory($twin)
    [IO.File]::WriteAllText("$twin\origin.txt", $install, [Text.Encoding]::Unicode)
    Check 'two data folders for the install: exit 4' ((Invoke-Smoke).exit_code -eq 4)
    Remove-Item -LiteralPath $twin -Recurse -Force

    Reset-Fakes 'ok' 'hang'
    $env:FAKE_PIDS = "$root\pids.txt"
    [void][IO.Directory]::CreateDirectory("$data\MQL5\Experts\Mql5Smoke")
    [IO.File]::WriteAllText("$data\MQL5\Experts\Mql5Smoke\user.ex5", 'user file')
    $r = Invoke-Smoke @{ TimeoutSeconds = '3' }
    $ids = @((Get-Content -LiteralPath "$root\pids.txt") -split ' ' | ForEach-Object { [int]$_ })
    Check 'hanging terminal: exit 3' (($r.exit_code -eq 3) -and ($r.status -eq 'timeout'))
    Check 'hanging terminal: it and its child are gone' (@(Get-Process -Id $ids -ErrorAction SilentlyContinue).Count -eq 0)
    Check 'report held by the child is recovered into the output folder and recorded' ((Test-Path -LiteralPath "$($r.output_folder)\$($r.staged_name).htm") -and
        ($r.report -eq "$($r.output_folder)\$($r.staged_name).htm") -and ((Get-Content -LiteralPath $r.result_json -Raw | ConvertFrom-Json).status -eq 'timeout'))
    Check 'staging removed; user preset and user file kept' (((Get-SmokeFiles).Count -eq 0) -and ((Get-Content -LiteralPath $userPreset -Raw) -eq 'user preset') -and
        (Test-Path -LiteralPath "$data\MQL5\Experts\Mql5Smoke\user.ex5") -and -not (Test-Path -LiteralPath "$data\$($r.staged_name).ini"))
    Check 'run lock released after the run' $(try { (Open-RunLock $data).Dispose(); $true } catch { $false })

    # Group 4: end to end through the public scripts, cleanup and journal rules
    Reset-Fakes 'child'
    $env:FAKE_MARKER = $marker
    $env:FAKE_SEEN_HASH = "$root\seen.txt"
    $env:FAKE_SEEN_SET = "$root\seen-set.txt"
    $sourceHash = Get-FileSha256 $source
    $setHash = Get-FileSha256 $setFile
    # An earlier run's OnInit failure in today's journal must not count against this run.
    $journal = "$data\Tester\logs\$(Get-Date -Format yyyyMMdd).log"
    [IO.File]::AppendAllText($journal, "AB`t0`t11:00:00.000`tCore 01`ttester stopped because OnInit returns non-zero`r`n", [Text.Encoding]::Unicode)
    $journalBytes = [IO.File]::ReadAllBytes($journal)
    $shell = (Get-Process -Id $PID).Path
    $realAppData = $env:APPDATA
    $env:APPDATA = $appData
    try {
        $compileOutput = & $shell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$scripts\Compile-Mql5.ps1" -SourcePath $source -MetaEditorPath $editor
        $compileExit = $LASTEXITCODE
        $smokeOutput = & $shell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$scripts\Invoke-Mt5TesterSmoke.ps1" -SourcePath $source `
            -Symbol EURUSD -Period H1 -FromDate 2026.01.01 -ToDate 2026.02.01 -SetPath $setFile -Leverage 100 -OutputDirectory "$root\entry" `
            -TerminalPath $terminal -ExpectedLogMarker $marker -TimeoutSeconds 30 -Model 0 -ExecutionMode 0 -Deposit 10000 -Currency USD
        $smokeExit = $LASTEXITCODE
        Reset-Fakes 'child'
        $injected = & $shell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$scripts\Invoke-Mt5TesterSmoke.ps1" -SourcePath $source `
            -Symbol "EURUSD`r`n[Experts]`r`nAllowLiveTrading=1" -Period H1 -UseExpertDefaults -OutputDirectory "$root\injected" -TerminalPath $terminal
        $injectedExit = $LASTEXITCODE
    }
    finally { $env:APPDATA = $realAppData; Remove-Item Env:\FAKE_MARKER, Env:\FAKE_SEEN_HASH, Env:\FAKE_SEEN_SET }
    $compiled = (@($compileOutput) -like 'MQL5_RESULT *')[0].Substring(12) | ConvertFrom-Json
    $summary = (@($smokeOutput) -like 'MQL5_RESULT *')[0].Substring(12) | ConvertFrom-Json
    $saved = Get-Content -LiteralPath "$root\entry\result.json" -Raw | ConvertFrom-Json
    Check 'end to end: compile and tester exit 0, marker passed, result.json agrees' (($compileExit -eq 0) -and ($smokeExit -eq 0) -and
        ($summary.status -eq 'application_marker_passed') -and ($saved.status -eq $summary.status) -and ($summary.cleanup -eq 'ok'))
    Check 'end to end: the tester recompiled and staged exactly its own build' (((Get-Content -LiteralPath "$root\seen.txt") -eq $saved.sha256) -and ($saved.sha256 -ne $compiled.sha256))
    Check 'end to end: the terminal was given exactly the supplied .set' ((Get-Content -LiteralPath "$root\seen-set.txt") -eq $setHash)
    $badTimeout = & $shell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$scripts\Compile-Mql5.ps1" -SourcePath $source -MetaEditorPath $editor -TimeoutSeconds abc
    Check 'compile with a non-numeric -TimeoutSeconds: exit 2 with a summary line, never exit 1' (($LASTEXITCODE -eq 2) -and (@($badTimeout) -like 'MQL5_RESULT *'))
    $iniBytes = [IO.File]::ReadAllBytes("$root\entry\$($saved.staged_name).ini")
    $iniCopy = [Text.Encoding]::Unicode.GetString($iniBytes)
    Check 'end to end: the ini is UTF-16LE with BOM and CRLF, has the safety keys and Leverage=1:100' (($iniBytes[0] -eq 0xFF) -and ($iniBytes[1] -eq 0xFE) -and
        ($iniCopy -notmatch '[^\r]\n') -and ($iniCopy -match '(?m)^AllowLiveTrading=0\r$') -and ($iniCopy -match '(?m)^Leverage=1:100\r$'))
    Check 'end to end: the other settings pass through the public script unchanged' (($iniCopy -match '(?m)^Model=0\r$') -and
        ($iniCopy -match '(?m)^ExecutionMode=0\r$') -and ($iniCopy -match '(?m)^Deposit=10000\r$') -and ($iniCopy -match '(?m)^Currency=USD\r$'))
    Check 'public script: a symbol with injected lines gives exit 2, nothing starts or is created' (($injectedExit -eq 2) -and
        (@($injected) -like 'MQL5_RESULT *') -and ((Get-Count $editorCount) -eq 0) -and -not (Test-Path -LiteralPath "$root\injected"))
    $after = [IO.File]::ReadAllBytes($journal)
    Check 'end to end: an older OnInit failure is ignored and the existing journal bytes are intact' (($after.Length -gt $journalBytes.Length) -and
        ([Convert]::ToBase64String($after, 0, $journalBytes.Length) -eq [Convert]::ToBase64String($journalBytes)))
    Check 'end to end: reports moved, staging gone, source, set and user preset unchanged' ((Test-Path -LiteralPath "$root\entry\$($saved.staged_name)-hst.png") -and
        ((Get-SmokeFiles).Count -eq 0) -and -not (Test-Path -LiteralPath "$data\MQL5\Profiles\Tester\$($saved.staged_name).set") -and
        (@(Get-ChildItem -LiteralPath "$data\Tester\cache" -File).Count -eq 0) -and ((Get-FileSha256 $source) -eq $sourceHash) -and
        ((Get-FileSha256 $setFile) -eq $setHash) -and ((Get-Content -LiteralPath $userPreset -Raw) -eq 'user preset'))

    Reset-Fakes
    $env:FAKE_OCCUPY = "$root\out$($runs + 1)"
    try { $r = Invoke-Smoke } finally { Remove-Item Env:\FAKE_OCCUPY }
    $savedResult = Get-Content -LiteralPath "$($r.output_folder)\result.json" -Raw | ConvertFrom-Json
    Check 'report that cannot move: exit 2 cleanup_failed, first outcome kept, file listed in result.json' (($r.exit_code -eq 2) -and
        ($r.status -eq 'cleanup_failed') -and ($savedResult.primary_status -eq 'engine_smoke_passed') -and
        (@($savedResult.cleanup.left) -contains "$data\$($r.staged_name).png") -and ((Get-Content -LiteralPath "$($r.output_folder)\$($r.staged_name).png" -Raw) -eq 'occupied'))
    Remove-Item -LiteralPath "$data\$($r.staged_name).png"

    [void][IO.Directory]::CreateDirectory("$root\claimed")
    New-OutputFolder "$root\claimed"
    $threw = try { New-OutputFolder "$root\claimed"; $false } catch { (Get-FailureExitCode $_) -eq 2 }
    Check 'an output folder already claimed by another run cannot be claimed again' $threw
    $unsaved = [ordered]@{ status = 'engine_smoke_passed'; exit_code = 0; message = $null; output_folder = "$root\claimed"; result_json = $null }
    $holder = [IO.File]::Open("$root\claimed\result.json", 'Open', 'Read', 'None')
    try { Save-SmokeResult $unsaved } finally { $holder.Dispose() }
    Check 'result.json that cannot be written: exit 2, no result_json path, first outcome kept' (($unsaved.exit_code -eq 2) -and
        ($null -eq $unsaved.result_json) -and ($unsaved.primary_status -eq 'engine_smoke_passed'))

    $staged = 'Held-s0000000001'
    $staging = [ordered]@{ data = $data; staged = $staged; smoke_folder = "$data\MQL5\Experts\Mql5Smoke"; created_smoke_folder = $false
        ex5 = "$data\MQL5\Experts\Mql5Smoke\$staged.ex5"; set = "$data\MQL5\Profiles\Tester\$staged.set"; ini = "$data\$staged.ini" }
    foreach ($file in $staging.ex5, $staging.set, $staging.ini, "$data\$staged.htm", "$data\$staged.png") { [IO.File]::WriteAllText($file, 'run file') }
    $held = "$root\held"
    [void][IO.Directory]::CreateDirectory($held)
    [IO.File]::WriteAllText("$held\$staged.png", 'already here')
    $holder = [IO.File]::Open("$data\$staged.htm", 'Open', 'Read', 'Read')
    try { $cleanup = Invoke-SmokeCleanup $staging $held $true } finally { $holder.Dispose() }
    Check 'report held open: stays in place, listed, cleanup fails' ((-not $cleanup.ok) -and ($cleanup.left -contains "$data\$staged.htm") -and (Test-Path -LiteralPath "$data\$staged.htm"))
    Check 'a report already at the destination is not overwritten' ((Get-Content -LiteralPath "$held\$staged.png" -Raw) -eq 'already here')
    Check 'the other owned files are still removed' (-not (Test-Path -LiteralPath $staging.ex5) -and -not (Test-Path -LiteralPath $staging.set) -and -not (Test-Path -LiteralPath $staging.ini))

    $verdictSettings = Resolve-TesterSettings @{ SourcePath = $source; Symbol = 'EURUSD'; Period = 'H1'; UseExpertDefaults = $true; OutputDirectory = "$root\never"
        FromDate = '2026.01.01'; ToDate = '2026.02.01'; ExpectedLogMarker = $marker } (Get-Date)
    function Line([string]$Message) { ConvertTo-JournalRecord "AB`t0`t12:00:00.000`tCore 01`t$Message" }
    function Get-Verdict($TerminalRecords, $TesterRecords) {
        $result = [ordered]@{ status = $null; exit_code = $null; message = $null }
        Set-SmokeVerdict $result @{ records = @($TerminalRecords); ranges = @() } @{ records = @($TesterRecords); ranges = @() } $verdictSettings 'C:\d\E-s1.ini' 'E-s1' $true
    }
    $term = @((Line 'successfully initialized from start config "C:\d\E-s1.ini"'), (Line 'automatic testing started'), (Line 'last test passed with result "successfully finished"'))
    $start = Line 'EURUSD,H1: testing of Experts\Mql5Smoke\E-s1.ex5 from 2026.01.01 00:00 to 2026.02.01 00:00 started with inputs:'
    $markerLine = Line "2026.01.01 00:00:00   $marker"
    $pass = Line 'EURUSD,H1: 100 ticks, 10 bars generated. Test passed in 0:00:00.010.'
    Check 'journal: a clean run with the marker passes' ((Get-Verdict $term @($start, $markerLine, $pass)).exit_code -eq 0)
    Check 'journal: a second test start fails (exit 1)' ((Get-Verdict $term @($start, $markerLine, $start, $pass)).exit_code -eq 1)
    Check 'journal: an OnInit failure record fails (exit 1)' ((Get-Verdict $term @($start, $markerLine, (Line 'tester stopped because OnInit returns non-zero'), $pass)).exit_code -eq 1)
    Check 'journal: a required marker that never appears fails (exit 1)' ((Get-Verdict $term @($start, $pass)).exit_code -eq 1)
    Check 'journal: an echoed input cannot fake an OnInit failure' ((Get-Verdict $term @($start, (Line '  x=tester stopped because OnInit returns non-zero'), $markerLine, $pass)).exit_code -eq 0)
    $foreign = Get-Verdict @(Line 'configuration chargee') @($start, $markerLine, $pass)
    Check 'journal: no English phrase gives journal_phrases_not_found (exit 2)' (($foreign.exit_code -eq 2) -and ($foreign.status -eq 'journal_phrases_not_found'))

    # Install: both clients, with backups outside skills, and nothing else touched
    $skill = Join-Path (Split-Path -Parent $PSScriptRoot) 'skills\mql5-coding'
    function Get-Inventory([string]$Folder) {
        @(Get-ChildItem -LiteralPath $Folder -Recurse -File -Force | Sort-Object FullName | ForEach-Object { $_.FullName.Substring($Folder.Length + 1) + '=' + (Get-FileSha256 $_.FullName) })
    }
    function Test-Same($Left, $Right) { (@($Left) -join "`n") -eq (@($Right) -join "`n") }
    $homes = [ordered]@{ Claude = "$root\claude home"; Codex = "$root\codex home" }
    foreach ($clientHome in $homes.Values) {
        [void][IO.Directory]::CreateDirectory("$clientHome\skills\mql5-coding\scripts\old")
        [void][IO.Directory]::CreateDirectory("$clientHome\skills\other-skill")
        [IO.File]::WriteAllText("$clientHome\skills\mql5-coding\SKILL.md", "v1 in $clientHome")
        [IO.File]::WriteAllText("$clientHome\skills\mql5-coding\scripts\old\TesterPathIntegrity.ps1", 'obsolete')
        [IO.File]::WriteAllText("$clientHome\skills\other-skill\SKILL.md", 'sibling skill')
        $hiddenFolder = New-Item -ItemType Directory -Path "$clientHome\skills\mql5-coding\.cache" -Force
        [IO.File]::WriteAllText("$($hiddenFolder.FullName)\old.txt", 'hidden obsolete')
        (Get-Item -LiteralPath "$($hiddenFolder.FullName)\old.txt" -Force).Attributes = 'Hidden'
        $hiddenFolder.Attributes = 'Directory, Hidden'
    }
    [IO.File]::WriteAllText("$($homes.Claude)\CLAUDE.md", 'standing instructions')
    [IO.File]::WriteAllText("$($homes.Codex)\AGENTS.md", 'standing instructions')
    $before = @{}
    foreach ($name in $homes.Keys) { $before[$name] = Get-Inventory $homes[$name] }
    $checkout = Get-Inventory $skill
    $saved = @{ CLAUDE_CONFIG_DIR = $env:CLAUDE_CONFIG_DIR; CODEX_HOME = $env:CODEX_HOME; LOCALAPPDATA = $env:LOCALAPPDATA }
    # A trailing '\.' and a relative home, run after Set-Location, so PowerShell's location differs
    # from the process directory: both must still land in the intended folders.
    $env:CLAUDE_CONFIG_DIR = "$($homes.Claude)\."
    $env:CODEX_HOME = 'codex home'
    $env:LOCALAPPDATA = "$root\local app data"
    $installer = Join-Path (Split-Path -Parent $PSScriptRoot) 'install.ps1'
    try {
        & $shell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Set-Location -LiteralPath '$root'; & '$installer'; exit `$LASTEXITCODE" | Out-Null
        $installExit = $LASTEXITCODE
    }
    finally { foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key, $saved[$key]) } }
    Check 'install: exit 0; the checkout holds the ten installed files' (($installExit -eq 0) -and ($checkout.Count -eq 10))
    foreach ($name in $homes.Keys) {
        $clientHome = $homes[$name]
        $backup = @(Get-ChildItem -LiteralPath "$root\local app data\mql5-coding\backups" -Directory -Filter "$name-*")
        $kept = @($before[$name] | Where-Object { $_ -like 'skills\mql5-coding\*' } | ForEach-Object { $_.Substring('skills\mql5-coding\'.Length) })
        Check "install ${name}: the old install is backed up byte for byte outside skills" (($backup.Count -eq 1) -and
            (Test-Same $kept (Get-Inventory $backup[0].FullName)))
        Check "install ${name}: exactly the checkout's files, obsolete files gone" (Test-Same $checkout (Get-Inventory "$clientHome\skills\mql5-coding"))
        $others = @(Get-Inventory $clientHome | Where-Object { $_ -notlike 'skills\mql5-coding\*' })
        Check "install ${name}: sibling skill and instruction file unchanged" (Test-Same @($before[$name] | Where-Object { $_ -notlike 'skills\mql5-coding\*' }) $others)
    }
    Check 'install: the checkout is unchanged' (Test-Same $checkout (Get-Inventory $skill))

    # Last, because it leaves that run's staging behind: when the runner itself is killed, the
    # kill-on-close job must stop MT5 and its children, and the run lock must be released.
    Reset-Fakes 'ok' 'hang'
    $env:FAKE_PIDS = "$root\killed-pids.txt"
    $env:APPDATA = $appData
    try {
        $runner = Start-Process -FilePath $shell -PassThru -WindowStyle Hidden -ArgumentList @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
            '-File', "`"$scripts\Invoke-Mt5TesterSmoke.ps1`"", '-SourcePath', "`"$source`"", '-Symbol', 'EURUSD', '-Period', 'H1', '-UseExpertDefaults',
            '-OutputDirectory', "`"$root\killed`"", '-TerminalPath', "`"$terminal`"", '-TimeoutSeconds', '120')
    }
    finally { $env:APPDATA = $realAppData }
    $deadline = (Get-Date).AddSeconds(30)
    while (-not (Test-Path -LiteralPath "$root\killed-pids.txt") -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 200 }
    $killedIds = @((Get-Content -LiteralPath "$root\killed-pids.txt" -ErrorAction SilentlyContinue) -split ' ' | Where-Object { $_ } | ForEach-Object { [int]$_ })
    Stop-Process -Id $runner.Id -Force
    $deadline = (Get-Date).AddSeconds(15)
    while ($killedIds.Count -and @(Get-Process -Id $killedIds -ErrorAction SilentlyContinue).Count -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 200 }
    Check 'killing the runner stops the terminal and its child, and frees the run lock' (($killedIds.Count -eq 2) -and
        (@(Get-Process -Id $killedIds -ErrorAction SilentlyContinue).Count -eq 0) -and $(try { (Open-RunLock $data).Dispose(); $true } catch { $false }))
}
finally {
    Get-Process -Name terminal64, metaeditor64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($install) } | Stop-Process -Force
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures) { Write-Host "$failures check(s) failed."; exit 1 }
Write-Host 'All checks passed.'
