param(
    [switch]$SkipModuleInstall
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$inputFile = Join-Path $scriptRoot 'world-helper-gui.ps1'
$outputFile = Join-Path $scriptRoot 'WorldHelperPortable.exe'

if (-not (Test-Path -LiteralPath $inputFile)) {
    throw "Input file not found: $inputFile"
}

$invokePs2Exe = Get-Command Invoke-PS2EXE -ErrorAction SilentlyContinue
if (-not $invokePs2Exe) {
    if ($SkipModuleInstall) {
        throw 'Invoke-PS2EXE is not available and -SkipModuleInstall was used.'
    }

    Write-Host 'Installing ps2exe module (CurrentUser)...' -ForegroundColor Cyan
    Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
    Import-Module ps2exe -Force
}
else {
    Import-Module ps2exe -Force
}

Write-Host "Compiling $inputFile -> $outputFile" -ForegroundColor Cyan
Invoke-PS2EXE `
    -InputFile $inputFile `
    -OutputFile $outputFile `
    -NoConsole `
    -Title 'Hytale World Helper (Portable)' `
    -Description 'Watch world logs and launch any Hytale world.' `
    -Company 'Local Tools' `
    -Product 'WorldHelperPortable'

Write-Host "Done. EXE created at: $outputFile" -ForegroundColor Green