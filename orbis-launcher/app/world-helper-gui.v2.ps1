Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

$scriptPath = $MyInvocation.MyCommand.Path
$scriptRootFromInvocation = $null
if (-not [string]::IsNullOrWhiteSpace($scriptPath)) {
    try {
        $scriptRootFromInvocation = Split-Path -Parent $scriptPath
    }
    catch {
    }
}

$scriptRootFromPSScriptRoot = $null
if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $scriptRootFromPSScriptRoot = $PSScriptRoot
}

$exeDir = $null
try {
    $exePath = [System.Windows.Forms.Application]::ExecutablePath
    if (-not [string]::IsNullOrWhiteSpace($exePath)) {
        $exeDir = Split-Path -Parent $exePath
    }
}
catch {
}

$scriptRoot = $null
if ($scriptRootFromPSScriptRoot -and (Test-Path -LiteralPath (Join-Path $scriptRootFromPSScriptRoot 'watch-latest-log.ps1'))) {
    $scriptRoot = $scriptRootFromPSScriptRoot
}
elseif ($scriptRootFromInvocation -and (Test-Path -LiteralPath (Join-Path $scriptRootFromInvocation 'watch-latest-log.ps1'))) {
    $scriptRoot = $scriptRootFromInvocation
}
elseif ($exeDir -and (Test-Path -LiteralPath (Join-Path $exeDir 'watch-latest-log.ps1'))) {
    $scriptRoot = $exeDir
}
elseif ($scriptRootFromPSScriptRoot) {
    $scriptRoot = $scriptRootFromPSScriptRoot
}
elseif ($scriptRootFromInvocation) {
    $scriptRoot = $scriptRootFromInvocation
}
elseif ($exeDir) {
    $scriptRoot = $exeDir
}
else {
    $scriptRoot = (Get-Location).Path
}

# Dot-source profile store (if available)
$profileStorePath = Join-Path $scriptRoot 'profile-store.v2.ps1'
if (Test-Path -LiteralPath $profileStorePath) {
    . $profileStorePath
}

$settingsPath = Join-Path $scriptRoot "world-helper-gui.settings.json"
$watchScriptPath = Join-Path $scriptRoot "watch-latest-log.ps1"

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

    return (Split-Path -Parent $scriptRoot)
}

$defaultUserDataPath = Get-DefaultUserDataPath

function Get-DefaultWorldPath {
    $savesRoot = Join-Path $defaultUserDataPath 'Saves'
    if (Test-Path -LiteralPath $savesRoot) {
        $worldDir = Get-ChildItem -LiteralPath $savesRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'logs') } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($worldDir) {
            return $worldDir.FullName
        }
    }

    $parent = Split-Path -Parent $scriptRoot
    $candidate = Join-Path $parent 'logs'
    if (Test-Path -LiteralPath $candidate) {
        return $parent
    }

    return ""
}

function Get-DefaultSettings {
    [pscustomobject]@{
        WorldPath = (Get-DefaultWorldPath)
        LogsPath = $defaultUserDataPath
        Tail = 80
        ImportantOnly = $true
        FilterPattern = ""
        LaunchCommand = ""
    }
}

function Get-Settings {
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        return Get-DefaultSettings
    }

    try {
        $raw = Get-Content -LiteralPath $settingsPath -Raw -ErrorAction Stop
        $json = $raw | ConvertFrom-Json -ErrorAction Stop
        $defaults = Get-DefaultSettings

        if ($null -eq $json.WorldPath) { $json | Add-Member -NotePropertyName WorldPath -NotePropertyValue $defaults.WorldPath }
        if ($null -eq $json.LogsPath) { $json | Add-Member -NotePropertyName LogsPath -NotePropertyValue $defaults.LogsPath }
        if (-not $json.Tail) { $json | Add-Member -NotePropertyName Tail -NotePropertyValue $defaults.Tail }
        if ($null -eq $json.ImportantOnly) { $json | Add-Member -NotePropertyName ImportantOnly -NotePropertyValue $defaults.ImportantOnly }
        if ($null -eq $json.FilterPattern) { $json | Add-Member -NotePropertyName FilterPattern -NotePropertyValue $defaults.FilterPattern }
        if ($null -eq $json.LaunchCommand) { $json | Add-Member -NotePropertyName LaunchCommand -NotePropertyValue $defaults.LaunchCommand }

        return $json
    }
    catch {
        return Get-DefaultSettings
    }
}

function Save-Settings([string]$worldPath, [string]$logsPath, [int]$tail, [bool]$importantOnly, [string]$filterPattern, [string]$launchCommand) {
    $obj = [pscustomobject]@{
        WorldPath = $worldPath
        LogsPath = $logsPath
        Tail = $tail
        ImportantOnly = $importantOnly
        FilterPattern = $filterPattern
        LaunchCommand = $launchCommand
    }

    $obj | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
}

function Resolve-LogsPath([string]$worldPath, [string]$logsPath) {
    if (-not [string]::IsNullOrWhiteSpace($logsPath)) {
        return $logsPath
    }

    if (-not [string]::IsNullOrWhiteSpace($worldPath)) {
        return (Join-Path $worldPath 'logs')
    }

    return ""
}

function Get-LatestLogFile {
    param(
        [string]$basePath
    )

    if ([string]::IsNullOrWhiteSpace($basePath) -or -not (Test-Path -LiteralPath $basePath)) {
        return $null
    }

    $item = Get-Item -LiteralPath $basePath -ErrorAction SilentlyContinue
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

function Expand-LaunchCommand([string]$launchCommand, [string]$worldPath, [string]$logsPath) {
    $worldToken = if ([string]::IsNullOrWhiteSpace($worldPath)) { "" } else { '"' + $worldPath + '"' }
    $logsToken = if ([string]::IsNullOrWhiteSpace($logsPath)) { "" } else { '"' + $logsPath + '"' }

    return $launchCommand.Replace('{WORLD}', $worldToken).Replace('{LOGS}', $logsToken)
}

function Get-AdjustedColor {
    param(
        [System.Drawing.Color]$Color,
        [int]$Delta
    )

    $r = [Math]::Max(0, [Math]::Min(255, $Color.R + $Delta))
    $g = [Math]::Max(0, [Math]::Min(255, $Color.G + $Delta))
    $b = [Math]::Max(0, [Math]::Min(255, $Color.B + $Delta))
    return [System.Drawing.Color]::FromArgb($r, $g, $b)
}

function Find-FirstAssetFile {
    param(
        [string[]]$Directories,
        [string[]]$Patterns
    )

    foreach ($dir in $Directories) {
        if ([string]::IsNullOrWhiteSpace($dir) -or -not (Test-Path -LiteralPath $dir)) {
            continue
        }

        foreach ($pattern in $Patterns) {
            $candidate = Get-ChildItem -LiteralPath $dir -File -Filter $pattern -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
            if ($candidate) {
                return $candidate.FullName
            }
        }
    }

    return $null
}

function Load-ThemeImage {
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    try {
        return [System.Drawing.Image]::FromFile($Path)
    }
    catch {
        return $null
    }
}

$watcherProcess = $null
$watcherPid = $null
$importantPattern = 'SEVERE|ERROR|AbstractMethodError|Exception|has crashed|Failed to dispatch event|FAIL:'
$watchTimer = New-Object System.Windows.Forms.Timer
$watchTimer.Interval = 700
$activeWatchRootPath = $null
$activeLogFilePath = $null
$activeLogReadPosition = 0L
$activeWatchImportantOnly = $false
$activeWatchFilterPattern = ""

function Get-RunningWatcher {
    if ($script:watcherProcess) {
        try {
            if (-not $script:watcherProcess.HasExited) {
                return $script:watcherProcess
            }
        }
        catch {
        }
    }

    if ($script:watcherPid) {
        $proc = Get-Process -Id $script:watcherPid -ErrorAction SilentlyContinue
        if ($proc) {
            $script:watcherProcess = $proc
            return $proc
        }
    }

    return $null
}

function Set-LiveLogState {
    param(
        [string]$watchRootPath,
        [string]$logFilePath,
        [bool]$importantOnly,
        [string]$filterPattern,
        [long]$position
    )

    $script:activeWatchRootPath = $watchRootPath
    $script:activeLogFilePath = $logFilePath
    $script:activeWatchImportantOnly = $importantOnly
    $script:activeWatchFilterPattern = $filterPattern
    $script:activeLogReadPosition = $position
}

function Should-IncludeLogLine {
    param(
        [string]$line,
        [bool]$importantOnly,
        [string]$filterPattern
    )

    if (-not [string]::IsNullOrWhiteSpace($filterPattern) -and ($line -notmatch $filterPattern)) {
        return $false
    }

    if ($importantOnly -and ($line -notmatch $importantPattern)) {
        return $false
    }

    return $true
}

function Append-LogLine {
    param(
        [string]$line
    )

    $lineColor = $themeText
    if ($line -match $importantPattern) {
        $lineColor = [System.Drawing.Color]::FromArgb(232, 126, 126)
    }
    elseif ($line -match 'WARN') {
        $lineColor = [System.Drawing.Color]::FromArgb(230, 196, 107)
    }

    $txtStatus.SelectionStart = $txtStatus.TextLength
    $txtStatus.SelectionColor = $lineColor
    $txtStatus.AppendText($line + "`r`n")
    $txtStatus.SelectionColor = $themeText
    $txtStatus.ScrollToCaret()
}

function Read-NewLogLines {
    param(
        [string]$logFilePath
    )

    $result = New-Object System.Collections.Generic.List[string]

    if ([string]::IsNullOrWhiteSpace($logFilePath) -or -not (Test-Path -LiteralPath $logFilePath)) {
        return $result
    }

    $fileInfo = Get-Item -LiteralPath $logFilePath -ErrorAction SilentlyContinue
    if (-not $fileInfo) {
        return $result
    }

    if ($script:activeLogReadPosition -gt $fileInfo.Length) {
        $script:activeLogReadPosition = 0L
    }

    try {
        $fs = [System.IO.File]::Open($logFilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            [void]$fs.Seek($script:activeLogReadPosition, [System.IO.SeekOrigin]::Begin)
            $sr = New-Object System.IO.StreamReader($fs)
            try {
                while (-not $sr.EndOfStream) {
                    $result.Add($sr.ReadLine())
                }
                $script:activeLogReadPosition = $fs.Position
            }
            finally {
                $sr.Dispose()
            }
        }
        finally {
            $fs.Dispose()
        }
    }
    catch {
    }

    return $result
}

$themeBg = [System.Drawing.Color]::FromArgb(20, 24, 30)
$themePanel = [System.Drawing.Color]::FromArgb(30, 36, 45)
$themePanelAlt = [System.Drawing.Color]::FromArgb(24, 30, 38)
$themeInput = [System.Drawing.Color]::FromArgb(16, 20, 25)
$themeText = [System.Drawing.Color]::FromArgb(230, 233, 237)
$themeMuted = [System.Drawing.Color]::FromArgb(160, 170, 185)
$themeGold = [System.Drawing.Color]::FromArgb(212, 172, 92)
$themeGoldDark = [System.Drawing.Color]::FromArgb(130, 102, 43)
$themeAccent = [System.Drawing.Color]::FromArgb(84, 176, 214)
$themeBorder = [System.Drawing.Color]::FromArgb(68, 76, 90)
$themeStatusBg = [System.Drawing.Color]::FromArgb(12, 16, 22)

$themeBtnWatch = [System.Drawing.Color]::FromArgb(39, 74, 59)
$themeBtnStop = [System.Drawing.Color]::FromArgb(78, 45, 45)
$themeBtnLaunch = [System.Drawing.Color]::FromArgb(32, 72, 88)
$themeBtnOpen = [System.Drawing.Color]::FromArgb(64, 64, 94)
$themeBtnExit = [System.Drawing.Color]::FromArgb(62, 62, 62)

$fontNormal = New-Object System.Drawing.Font("Segoe UI", 9)
$fontTitle = New-Object System.Drawing.Font("Segoe UI Semibold", 16)
$fontSubtitle = New-Object System.Drawing.Font("Segoe UI", 9.5)
$fontMono = New-Object System.Drawing.Font("Consolas", 9)

$assetUiDir = Join-Path $scriptRoot 'assets\ui'
$assetBrandDir = Join-Path $scriptRoot 'assets\branding'
$headerImagePath = Find-FirstAssetFile -Directories @($assetUiDir, $assetBrandDir) -Patterns @('*header*.png', '*banner*.png', '*hytale*.png')
$logoImagePath = Find-FirstAssetFile -Directories @($assetUiDir, $assetBrandDir) -Patterns @('*logo*.png', '*icon*.png', '*crest*.png')
$themeHeaderImage = Load-ThemeImage -Path $headerImagePath
$themeLogoImage = Load-ThemeImage -Path $logoImagePath

function Set-ButtonTheme([System.Windows.Forms.Button]$button, [System.Drawing.Color]$backColor) {
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.BorderColor = $themeGoldDark
    $button.BackColor = $backColor
    $button.ForeColor = $themeText
    $button.Font = $fontNormal
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand

    $hoverColor = Get-AdjustedColor -Color $backColor -Delta 18
    $pressedColor = Get-AdjustedColor -Color $backColor -Delta -12
    $button.Tag = [pscustomobject]@{
        Base = $backColor
        Hover = $hoverColor
        Pressed = $pressedColor
    }

    $button.Add_MouseEnter({
        param($sender, $args)
        if ($sender.Tag) { $sender.BackColor = $sender.Tag.Hover }
    })
    $button.Add_MouseLeave({
        param($sender, $args)
        if ($sender.Tag) { $sender.BackColor = $sender.Tag.Base }
    })
    $button.Add_MouseDown({
        param($sender, $args)
        if ($sender.Tag) { $sender.BackColor = $sender.Tag.Pressed }
    })
    $button.Add_MouseUp({
        param($sender, $args)
        if ($sender.Tag) { $sender.BackColor = $sender.Tag.Hover }
    })
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Hytale World Helper (Orbis v2 prototype)"
$form.Size = New-Object System.Drawing.Size(940, 660)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = $themeBg
$form.ForeColor = $themeText
$form.Font = $fontNormal

$form.Add_Paint({
    param($sender, $e)
    $linePen = New-Object System.Drawing.Pen($themeBorder)
    $e.Graphics.DrawRectangle($linePen, 6, 6, $sender.ClientSize.Width - 13, $sender.ClientSize.Height - 13)
    $linePen.Dispose()
})

$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(940, 96)
$headerPanel.BackColor = $themePanel
$form.Controls.Add($headerPanel)

if ($themeHeaderImage) {
    $headerPanel.BackgroundImage = $themeHeaderImage
    $headerPanel.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Stretch
}

$headerPanel.Add_Paint({
    param($sender, $e)
    $rect = $sender.ClientRectangle
    $overlay = [System.Drawing.Color]::FromArgb(145, 12, 15, 21)
    $brush = New-Object System.Drawing.SolidBrush($overlay)
    $e.Graphics.FillRectangle($brush, $rect)
    $brush.Dispose()

    $goldPen = New-Object System.Drawing.Pen($themeGoldDark, 2)
    $e.Graphics.DrawLine($goldPen, 0, $rect.Height - 2, $rect.Width, $rect.Height - 2)
    $goldPen.Dispose()
})

$picLogo = New-Object System.Windows.Forms.PictureBox
$picLogo.Location = New-Object System.Drawing.Point(16, 14)
$picLogo.Size = New-Object System.Drawing.Size(64, 64)
$picLogo.BackColor = [System.Drawing.Color]::Transparent
$picLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
if ($themeLogoImage) {
    $picLogo.Image = $themeLogoImage
}
$headerPanel.Controls.Add($picLogo)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "ORBIS LAUNCHER - HYTALE WORLD HELPER"
$lblTitle.Location = New-Object System.Drawing.Point(90, 16)
$lblTitle.AutoSize = $true
$lblTitle.Font = $fontTitle
$lblTitle.ForeColor = $themeGold
$lblTitle.BackColor = [System.Drawing.Color]::Transparent
$headerPanel.Controls.Add($lblTitle)

$lblSubtitle = New-Object System.Windows.Forms.Label
$lblSubtitle.Text = "Instance-style launcher: manage worlds, launch faster, and monitor logs in one place."
$lblSubtitle.Location = New-Object System.Drawing.Point(92, 50)
$lblSubtitle.AutoSize = $true
$lblSubtitle.Font = $fontSubtitle
$lblSubtitle.ForeColor = $themeMuted
$lblSubtitle.BackColor = [System.Drawing.Color]::Transparent
$headerPanel.Controls.Add($lblSubtitle)

# Profile controls (v2)
$lblProfile = New-Object System.Windows.Forms.Label
$lblProfile.Text = "Profile:"
$lblProfile.Location = New-Object System.Drawing.Point(720, 16)
$lblProfile.AutoSize = $true
$lblProfile.ForeColor = $themeText
$lblProfile.BackColor = [System.Drawing.Color]::Transparent
$headerPanel.Controls.Add($lblProfile)

$cmbProfiles = New-Object System.Windows.Forms.ComboBox
$cmbProfiles.Location = New-Object System.Drawing.Point(776, 13)
$cmbProfiles.Size = New-Object System.Drawing.Size(150, 24)
$cmbProfiles.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbProfiles.BackColor = $themeInput
$cmbProfiles.ForeColor = $themeText
$cmbProfiles.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$headerPanel.Controls.Add($cmbProfiles)

$btnProfileNew = New-Object System.Windows.Forms.Button
$btnProfileNew.Text = "New"
$btnProfileNew.Location = New-Object System.Drawing.Point(720, 50)
$btnProfileNew.Size = New-Object System.Drawing.Size(56, 28)
Set-ButtonTheme -button $btnProfileNew -backColor $themeGoldDark
$headerPanel.Controls.Add($btnProfileNew)

$btnProfileDup = New-Object System.Windows.Forms.Button
$btnProfileDup.Text = "Duplicate"
$btnProfileDup.Location = New-Object System.Drawing.Point(780, 50)
$btnProfileDup.Size = New-Object System.Drawing.Size(74, 28)
Set-ButtonTheme -button $btnProfileDup -backColor $themeGoldDark
$headerPanel.Controls.Add($btnProfileDup)

$btnProfileDelete = New-Object System.Windows.Forms.Button
$btnProfileDelete.Text = "Delete"
$btnProfileDelete.Location = New-Object System.Drawing.Point(860, 50)
$btnProfileDelete.Size = New-Object System.Drawing.Size(74, 28)
Set-ButtonTheme -button $btnProfileDelete -backColor $themeBtnExit
$headerPanel.Controls.Add($btnProfileDelete)

$controlsPanel = New-Object System.Windows.Forms.Panel
$controlsPanel.Location = New-Object System.Drawing.Point(12, 108)
$controlsPanel.Size = New-Object System.Drawing.Size(916, 236)
$controlsPanel.BackColor = $themePanelAlt
$form.Controls.Add($controlsPanel)

$controlsPanel.Add_Paint({
    param($sender, $e)
    $borderPen = New-Object System.Drawing.Pen($themeBorder)
    $e.Graphics.DrawRectangle($borderPen, 0, 0, $sender.ClientSize.Width - 1, $sender.ClientSize.Height - 1)
    $borderPen.Dispose()
})

$lblWorld = New-Object System.Windows.Forms.Label
$lblWorld.Text = "World folder:"
$lblWorld.Location = New-Object System.Drawing.Point(12, 18)
$lblWorld.AutoSize = $true
$lblWorld.ForeColor = $themeText
$controlsPanel.Controls.Add($lblWorld)

$txtWorld = New-Object System.Windows.Forms.TextBox
$txtWorld.Location = New-Object System.Drawing.Point(100, 14)
$txtWorld.Size = New-Object System.Drawing.Size(612, 23)
$txtWorld.BackColor = $themeInput
$txtWorld.ForeColor = $themeText
$txtWorld.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$controlsPanel.Controls.Add($txtWorld)

$btnBrowseWorld = New-Object System.Windows.Forms.Button
$btnBrowseWorld.Text = "Browse"
$btnBrowseWorld.Location = New-Object System.Drawing.Point(722, 12)
$btnBrowseWorld.Size = New-Object System.Drawing.Size(62, 26)
Set-ButtonTheme -button $btnBrowseWorld -backColor $themeGoldDark
$controlsPanel.Controls.Add($btnBrowseWorld)

$btnUseWorldLogs = New-Object System.Windows.Forms.Button
$btnUseWorldLogs.Text = "Use logs"
$btnUseWorldLogs.Location = New-Object System.Drawing.Point(790, 12)
$btnUseWorldLogs.Size = New-Object System.Drawing.Size(62, 26)
Set-ButtonTheme -button $btnUseWorldLogs -backColor $themeGoldDark
$controlsPanel.Controls.Add($btnUseWorldLogs)

... (truncated for brevity)