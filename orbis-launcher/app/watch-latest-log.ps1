param(
    [string]$WorldPath = "",
    [string]$LogsPath = "",
    [int]$Tail = 80,
    [switch]$OnlyImportant,
    [string]$FilterPattern = ""
)

$importantPattern = 'SEVERE|ERROR|AbstractMethodError|Exception|has crashed|Failed to dispatch event|FAIL:'

function Get-DefaultUserDataPath {
    $candidates = @()

    if (-not [string]::IsNullOrWhiteSpace($env:APPDATA)) {
        $candidates += (Join-Path $env:APPDATA 'Hytale\UserData')
    }

    $roamingAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
    if (-not [string]::IsNullOrWhiteSpace($roamingAppData)) {
        $candidates += (Join-Path $roamingAppData 'Hytale\UserData')
    }

    $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    if (-not [string]::IsNullOrWhiteSpace($localAppData)) {
        $candidates += (Join-Path $localAppData 'Hytale\UserData')
    }

    foreach ($path in ($candidates | Select-Object -Unique)) {
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path)) {
            return $path
        }
    }

    return $PSScriptRoot
}

$defaultUserDataPath = Get-DefaultUserDataPath

function Resolve-LogsPath {
    param(
        [string]$WorldPathValue,
        [string]$LogsPathValue
    )

    if (-not [string]::IsNullOrWhiteSpace($LogsPathValue)) {
        return $LogsPathValue
    }

    if (-not [string]::IsNullOrWhiteSpace($WorldPathValue)) {
        return (Join-Path $WorldPathValue 'logs')
    }

    if (Test-Path -LiteralPath $defaultUserDataPath) {
        return $defaultUserDataPath
    }

    return (Join-Path $PSScriptRoot 'logs')
}

function Get-LatestLogFile {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $item) {
        return $null
    }

    if (-not $item.PSIsContainer) {
        return $item
    }

    $direct = Get-ChildItem -LiteralPath $item.FullName -File -Filter '*_server.log' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($direct) {
        return $direct
    }

    $logsSub = Join-Path $item.FullName 'logs'
    if (Test-Path -LiteralPath $logsSub) {
        $fromLogs = Get-ChildItem -LiteralPath $logsSub -File -Filter '*_server.log' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($fromLogs) {
            return $fromLogs
        }
    }

    $recursive = Get-ChildItem -LiteralPath $item.FullName -File -Filter '*_server.log' -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($recursive) {
        return $recursive
    }

    return Get-ChildItem -LiteralPath $item.FullName -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

$resolvedLogsPath = Resolve-LogsPath -WorldPathValue $WorldPath -LogsPathValue $LogsPath

if (-not (Test-Path -LiteralPath $resolvedLogsPath)) {
    Write-Host "Path not found: $resolvedLogsPath" -ForegroundColor Red
    exit 1
}

if (-not [string]::IsNullOrWhiteSpace($FilterPattern)) {
    try {
        [void][regex]::new($FilterPattern)
    }
    catch {
        Write-Host "Invalid filter regex: $FilterPattern" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor DarkRed
        exit 1
    }
}

$latest = Get-LatestLogFile -Path $resolvedLogsPath

if (-not $latest) {
    Write-Host "No log files found under: $resolvedLogsPath" -ForegroundColor Yellow
    exit 1
}

Write-Host "Watching: $($latest.FullName)" -ForegroundColor Cyan
Write-Host "Mode: $(if ($OnlyImportant) { 'important-only' } else { 'full log' })" -ForegroundColor DarkCyan
if (-not [string]::IsNullOrWhiteSpace($FilterPattern)) {
    Write-Host "Filter: $FilterPattern" -ForegroundColor DarkCyan
}
Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray

Get-Content -LiteralPath $latest.FullName -Tail $Tail -Wait | ForEach-Object {
    $line = $_

    if (-not [string]::IsNullOrWhiteSpace($FilterPattern) -and ($line -notmatch $FilterPattern)) {
        return
    }

    if ($OnlyImportant -and ($line -notmatch $importantPattern)) {
        return
    }

    if ($line -match $importantPattern) {
        Write-Host $line -ForegroundColor Red
    }
    elseif ($line -match 'WARN') {
        Write-Host $line -ForegroundColor Yellow
    }
    else {
        Write-Host $line
    }
}