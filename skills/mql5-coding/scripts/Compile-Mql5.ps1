# Compiles one MQL5 source with MetaEditor and prints only errors, warnings, the Result line
# and one MQL5_RESULT {json} line. Exit codes: 0 fresh .ex5, 1 compile errors, 2 input or tool
# failure, 3 timeout. See references/compile.md.
[CmdletBinding()]
param(
    [string]$SourcePath,
    [string]$IncludePath,
    [string]$MetaEditorPath,
    [string]$TerminalPath,
    [string]$TimeoutSeconds = '120',
    [Parameter(ValueFromRemainingArguments = $true)][object[]]$UnknownArguments
)

. (Join-Path $PSScriptRoot 'Mql5Compile.ps1')

if ($UnknownArguments) {
    $result = [ordered]@{ status = 'failed'; exit_code = 2; message = "Unknown arguments: $($UnknownArguments -join ' '). See references/compile.md." }
}
else {
    $result = Invoke-Mql5Compile -SourcePath $SourcePath -IncludePath $IncludePath -MetaEditorPath $MetaEditorPath `
        -TerminalPath $TerminalPath -TimeoutSeconds $TimeoutSeconds
    foreach ($line in $result.diagnostics) { $line }
    if ($result.truncated) { "Showing $(@($result.diagnostics).Count) of $($result.diagnostic_total) diagnostic lines, some shortened (truncated)." }
    if ($result.result_line) { $result.result_line }
    if ($result.log) { "Full compile log kept: $($result.log)" }
}

$summary = [ordered]@{}
foreach ($key in 'status', 'exit_code', 'message', 'editor', 'editor_build', 'source', 'errors', 'warnings', 'artifact', 'sha256', 'log') {
    if ($null -ne $result[$key]) { $summary[$key] = $result[$key] }
}
'MQL5_RESULT ' + ($summary | ConvertTo-Json -Compress)
exit $result.exit_code
