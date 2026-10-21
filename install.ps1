# Installs skills\mql5-coding from this checkout into Claude Code and/or Codex.
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1 [-Client Claude|Codex|Both]
# Each existing install is first backed up to %LOCALAPPDATA%\mql5-coding\backups. If a step fails,
# run the script again; the backup allows a manual restore.
[CmdletBinding()]
param([ValidateSet('Claude', 'Codex', 'Both')][string]$Client = 'Both')
$ErrorActionPreference = 'Stop'

$source = Join-Path $PSScriptRoot 'skills\mql5-coding'

# Full, normalized paths, because the stale-file check below compares paths by their length. A
# relative home resolves against PowerShell's location, which can differ from the process directory.
function Get-SkillFolder([string]$ClientHome) {
    $folder = Join-Path $ClientHome 'skills\mql5-coding'
    if (-not [IO.Path]::IsPathRooted($folder)) { $folder = Join-Path (Get-Location).ProviderPath $folder }
    [IO.Path]::GetFullPath($folder)
}

$destinations = [ordered]@{}
if ($Client -ne 'Codex') {
    $destinations.Claude = Get-SkillFolder $(if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' })
}
if ($Client -ne 'Claude') {
    $destinations.Codex = Get-SkillFolder $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' })
}
$files = @(Get-ChildItem -LiteralPath $source -Recurse -File | ForEach-Object { $_.FullName.Substring($source.Length + 1) })
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$allMatch = $true

foreach ($name in $destinations.Keys) {
    $target = $destinations[$name]
    # A backup under skills would load as a second mql5-coding skill, so it goes to LOCALAPPDATA.
    if (Test-Path -LiteralPath $target) {
        $backup = Join-Path $env:LOCALAPPDATA "mql5-coding\backups\$name-$stamp"
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $backup))
        # -Force here and below includes hidden files and folders.
        Copy-Item -LiteralPath $target -Destination $backup -Recurse -Force
        "${name}: backed up the current install to $backup"
    }
    foreach ($file in $files) {
        $to = Join-Path $target $file
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $to))
        Copy-Item -LiteralPath (Join-Path $source $file) -Destination $to -Force
    }
    # The root folder stays (an open client may hold it); only files outside the new set go.
    foreach ($installed in @(Get-ChildItem -LiteralPath $target -Recurse -File -Force)) {
        if ($files -notcontains $installed.FullName.Substring($target.Length + 1)) { Remove-Item -LiteralPath $installed.FullName -Force }
    }
    foreach ($folder in @(Get-ChildItem -LiteralPath $target -Recurse -Directory -Force | Sort-Object { $_.FullName.Length } -Descending)) {
        if (-not (Get-ChildItem -LiteralPath $folder.FullName -Force)) { Remove-Item -LiteralPath $folder.FullName -Force }
    }
    $different = @($files | Where-Object { (Get-FileHash -LiteralPath (Join-Path $source $_)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $target $_)).Hash })
    if ($different) { "${name}: these files do not match the checkout: $($different -join ', ')"; $allMatch = $false }
    else { "${name}: installed $($files.Count) files to $target; all match the checkout." }
}
'Restart the client so new chats load the skill.'
if (-not $allMatch) { exit 1 }
