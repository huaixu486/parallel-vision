param(
    [string]$ClaudeHome = (Join-Path $env:USERPROFILE '.claude'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillSource = Join-Path $repoRoot 'pasteimg'
$commandSource = Join-Path $repoRoot 'commands\pasteimg.md'

if (-not (Test-Path -LiteralPath $skillSource)) {
    throw "Missing skill folder: $skillSource"
}
if (-not (Test-Path -LiteralPath $commandSource)) {
    throw "Missing slash command: $commandSource"
}

$skillsDir = Join-Path $ClaudeHome 'skills'
$commandsDir = Join-Path $ClaudeHome 'commands'
$skillTarget = Join-Path $skillsDir 'pasteimg'
$commandTarget = Join-Path $commandsDir 'pasteimg.md'

New-Item -ItemType Directory -Force -Path $skillsDir, $commandsDir | Out-Null

if ((Test-Path -LiteralPath $skillTarget) -and -not $Force) {
    throw "Target already exists: $skillTarget. Re-run with -Force to overwrite."
}

Copy-Item -Recurse -Force -LiteralPath $skillSource -Destination $skillTarget
Copy-Item -Force -LiteralPath $commandSource -Destination $commandTarget

Write-Output "Installed pasteimg skill to: $skillTarget"
Write-Output "Installed /pasteimg command to: $commandTarget"
Write-Output 'Restart Claude Code before using /pasteimg.'
