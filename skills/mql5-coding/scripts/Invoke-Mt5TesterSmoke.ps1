# Compiles one Expert Advisor with the terminal's own MetaEditor and runs it once in the Strategy
# Tester, then prints one MQL5_RESULT {json} line. Exit codes: 0 passed, 1 a pass rule failed,
# 2 input, compile, tool, evidence or cleanup failure, 3 timeout, 4 blocked before launch.
# See references/strategy-tester.md.
[CmdletBinding()]
param(
    [string]$SourcePath,
    [string]$IncludePath,
    [string]$Symbol,
    [string]$Period,
    [string]$FromDate,
    [string]$ToDate,
    [string]$Model,
    [string]$Deposit,
    [string]$Currency,
    [string]$Leverage,
    [string]$ExecutionMode,
    [string]$SetPath,
    [switch]$UseExpertDefaults,
    [string]$OutputDirectory,
    [string]$TerminalPath,
    [string]$TimeoutSeconds,
    [string]$WaitSeconds,
    [string]$ExpectedLogMarker,
    [Parameter(ValueFromRemainingArguments = $true)][object[]]$UnknownArguments
)

. (Join-Path $PSScriptRoot 'Mql5Tester.ps1')

$replaced = @{
    '-CompilationReceiptPath' = 'use -SourcePath'; '-ExpertPath' = 'use -SourcePath'; '-ExpectedExpertSha256' = 'use -SourcePath'
    '-ExpectedLogMarkerFile' = 'use -ExpectedLogMarker'; '-TerminalDataPath' = 'the data folder is now found automatically'
    '-AcknowledgeSavedAccountRisk' = 'no longer needed'; '-Execute' = 'no longer needed'; '-PreflightOnly' = 'no longer needed'
}
if ($UnknownArguments) {
    $notes = foreach ($argument in $UnknownArguments) {
        $name = ([string]$argument) -replace ':.*$', ''
        if ($replaced.ContainsKey($name)) { "$name was removed: $($replaced[$name])." }
        elseif ($name.StartsWith('-')) { "Unknown parameter $name." }
    }
    $result = [ordered]@{ status = 'failed'; exit_code = 2; message = (@($notes) + 'See references/strategy-tester.md.') -join ' ' }
}
else {
    $result = Invoke-Mt5Smoke @PSBoundParameters
}

$summary = [ordered]@{ status = $result.status; exit_code = $result.exit_code }
if ($result.message) { $summary.message = $result.message }
if ($result.compile) { $summary.compile = [ordered]@{ errors = $result.compile.errors; warnings = $result.compile.warnings; sha256 = $result.compile.sha256 } }
if ($result.settings) {
    $s = $result.settings
    $summary.settings = [ordered]@{ symbol = $s.symbol; period = $s.period; from = $s.from; to = $s.to; model = $s.model; execution_mode = $s.execution_mode }
}
if ($result.failed_checks) { $summary.failed_checks = $result.failed_checks }
if ($result.cleanup) { $summary.cleanup = if ($result.cleanup.ok) { 'ok' } else { "$(@($result.cleanup.left).Count) left" } }
if ($result.headline) { $summary.headline = $result.headline }
if ($result.report) { $summary.report = $result.report }
if ($result.result_json) { $summary.result_json = $result.result_json }
'MQL5_RESULT ' + ($summary | ConvertTo-Json -Compress -Depth 4)
exit $result.exit_code
