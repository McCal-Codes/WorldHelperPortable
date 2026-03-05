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

$lblLogs = New-Object System.Windows.Forms.Label
$lblLogs.Text = "Logs folder:"
$lblLogs.Location = New-Object System.Drawing.Point(12, 54)
$lblLogs.AutoSize = $true
$lblLogs.ForeColor = $themeText
$controlsPanel.Controls.Add($lblLogs)

$txtLogs = New-Object System.Windows.Forms.TextBox
$txtLogs.Location = New-Object System.Drawing.Point(100, 50)
$txtLogs.Size = New-Object System.Drawing.Size(612, 23)
$txtLogs.BackColor = $themeInput
$txtLogs.ForeColor = $themeText
$txtLogs.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$controlsPanel.Controls.Add($txtLogs)

$btnBrowseLogs = New-Object System.Windows.Forms.Button
$btnBrowseLogs.Text = "Browse"
$btnBrowseLogs.Location = New-Object System.Drawing.Point(722, 48)
$btnBrowseLogs.Size = New-Object System.Drawing.Size(62, 26)
Set-ButtonTheme -button $btnBrowseLogs -backColor $themeGoldDark
$controlsPanel.Controls.Add($btnBrowseLogs)

$btnLatestWorld = New-Object System.Windows.Forms.Button
$btnLatestWorld.Text = "Latest"
$btnLatestWorld.Location = New-Object System.Drawing.Point(790, 48)
$btnLatestWorld.Size = New-Object System.Drawing.Size(62, 26)
Set-ButtonTheme -button $btnLatestWorld -backColor $themeGoldDark
$controlsPanel.Controls.Add($btnLatestWorld)

$lblTail = New-Object System.Windows.Forms.Label
$lblTail.Text = "Tail lines:"
$lblTail.Location = New-Object System.Drawing.Point(12, 90)
$lblTail.AutoSize = $true
$lblTail.ForeColor = $themeText
$controlsPanel.Controls.Add($lblTail)

$numTail = New-Object System.Windows.Forms.NumericUpDown
$numTail.Location = New-Object System.Drawing.Point(100, 86)
$numTail.Size = New-Object System.Drawing.Size(90, 23)
$numTail.Minimum = 10
$numTail.Maximum = 2000
$numTail.BackColor = $themeInput
$numTail.ForeColor = $themeText
$controlsPanel.Controls.Add($numTail)

$chkImportant = New-Object System.Windows.Forms.CheckBox
$chkImportant.Text = "Important only (errors/crashes)"
$chkImportant.Location = New-Object System.Drawing.Point(210, 88)
$chkImportant.AutoSize = $true
$chkImportant.ForeColor = $themeAccent
$chkImportant.BackColor = $themePanel
$controlsPanel.Controls.Add($chkImportant)

$lblFilter = New-Object System.Windows.Forms.Label
$lblFilter.Text = "Filter regex:"
$lblFilter.Location = New-Object System.Drawing.Point(12, 126)
$lblFilter.AutoSize = $true
$lblFilter.ForeColor = $themeText
$controlsPanel.Controls.Add($lblFilter)

$txtFilter = New-Object System.Windows.Forms.TextBox
$txtFilter.Location = New-Object System.Drawing.Point(100, 122)
$txtFilter.Size = New-Object System.Drawing.Size(612, 23)
$txtFilter.BackColor = $themeInput
$txtFilter.ForeColor = $themeText
$txtFilter.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$controlsPanel.Controls.Add($txtFilter)

$lblLaunch = New-Object System.Windows.Forms.Label
$lblLaunch.Text = "Launch cmd:"
$lblLaunch.Location = New-Object System.Drawing.Point(12, 162)
$lblLaunch.AutoSize = $true
$lblLaunch.ForeColor = $themeText
$controlsPanel.Controls.Add($lblLaunch)

$txtLaunch = New-Object System.Windows.Forms.TextBox
$txtLaunch.Location = New-Object System.Drawing.Point(100, 158)
$txtLaunch.Size = New-Object System.Drawing.Size(612, 23)
$txtLaunch.BackColor = $themeInput
$txtLaunch.ForeColor = $themeText
$txtLaunch.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$controlsPanel.Controls.Add($txtLaunch)

$btnBrowseExe = New-Object System.Windows.Forms.Button
$btnBrowseExe.Text = "EXE"
$btnBrowseExe.Location = New-Object System.Drawing.Point(722, 156)
$btnBrowseExe.Size = New-Object System.Drawing.Size(130, 26)
Set-ButtonTheme -button $btnBrowseExe -backColor $themeGoldDark
$controlsPanel.Controls.Add($btnBrowseExe)

$lblTokenHelp = New-Object System.Windows.Forms.Label
$lblTokenHelp.Text = "Tip: Use {WORLD} and {LOGS} tokens in Launch cmd."
$lblTokenHelp.Location = New-Object System.Drawing.Point(100, 194)
$lblTokenHelp.AutoSize = $true
$lblTokenHelp.ForeColor = $themeMuted
$controlsPanel.Controls.Add($lblTokenHelp)

$actionsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$actionsPanel.Location = New-Object System.Drawing.Point(12, 356)
$actionsPanel.Size = New-Object System.Drawing.Size(916, 44)
$actionsPanel.BackColor = [System.Drawing.Color]::Transparent
$actionsPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$actionsPanel.WrapContents = $false
$actionsPanel.AutoSize = $false
$actionsPanel.Padding = New-Object System.Windows.Forms.Padding(6)
$form.Controls.Add($actionsPanel)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Save"
$btnSave.Size = New-Object System.Drawing.Size(110, 32)
Set-ButtonTheme -button $btnSave -backColor $themeGoldDark
$btnSave.Margin = New-Object System.Windows.Forms.Padding(6,4,6,4)
$actionsPanel.Controls.Add($btnSave)

$btnWatch = New-Object System.Windows.Forms.Button
$btnWatch.Text = "Start Watch"
$btnWatch.Size = New-Object System.Drawing.Size(110, 32)
Set-ButtonTheme -button $btnWatch -backColor $themeBtnWatch
$btnWatch.Margin = New-Object System.Windows.Forms.Padding(6,4,6,4)
$actionsPanel.Controls.Add($btnWatch)

$btnStopWatch = New-Object System.Windows.Forms.Button
$btnStopWatch.Text = "Stop Watch"
$btnStopWatch.Size = New-Object System.Drawing.Size(110, 32)
Set-ButtonTheme -button $btnStopWatch -backColor $themeBtnStop
$btnStopWatch.Margin = New-Object System.Windows.Forms.Padding(6,4,6,4)
$actionsPanel.Controls.Add($btnStopWatch)

$btnLaunch = New-Object System.Windows.Forms.Button
$btnLaunch.Text = "Launch + Watch"
$btnLaunch.Size = New-Object System.Drawing.Size(240, 32)
Set-ButtonTheme -button $btnLaunch -backColor $themeBtnLaunch
$btnLaunch.Margin = New-Object System.Windows.Forms.Padding(12,4,6,4)
$actionsPanel.Controls.Add($btnLaunch)

$btnOpenLatest = New-Object System.Windows.Forms.Button
$btnOpenLatest.Text = "Open Latest"
$btnOpenLatest.Size = New-Object System.Drawing.Size(110, 32)
Set-ButtonTheme -button $btnOpenLatest -backColor $themeBtnOpen
$btnOpenLatest.Margin = New-Object System.Windows.Forms.Padding(6,4,6,4)
$actionsPanel.Controls.Add($btnOpenLatest)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Exit"
$btnExit.Size = New-Object System.Drawing.Size(90, 32)
Set-ButtonTheme -button $btnExit -backColor $themeBtnExit
$btnExit.Margin = New-Object System.Windows.Forms.Padding(6,4,6,4)
$actionsPanel.Controls.Add($btnExit)

$txtStatus = New-Object System.Windows.Forms.RichTextBox
$txtStatus.Location = New-Object System.Drawing.Point(14, 398)
$txtStatus.Size = New-Object System.Drawing.Size(914, 210)
$txtStatus.ReadOnly = $true
$txtStatus.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
$txtStatus.BackColor = $themeStatusBg
$txtStatus.ForeColor = $themeText
$txtStatus.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$txtStatus.DetectUrls = $false
$txtStatus.Font = $fontMono
$form.Controls.Add($txtStatus)

function Set-Status([string]$message) {
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    $line = "[$timestamp] $message`r`n"
    $lineColor = $themeText

    if ($message -match 'failed|error|not found|could not|invalid') {
        $lineColor = [System.Drawing.Color]::FromArgb(232, 126, 126)
    }
    elseif ($message -match 'started|ready|saved|stopped|launched|resolved') {
        $lineColor = [System.Drawing.Color]::FromArgb(126, 201, 140)
    }

    $txtStatus.SelectionStart = $txtStatus.TextLength
    $txtStatus.SelectionColor = $lineColor
    $txtStatus.AppendText($line)
    $txtStatus.SelectionColor = $themeText
    $txtStatus.ScrollToCaret()
}

function Start-Watcher {
    param(
        [string]$worldPath,
        [string]$logsPath,
        [int]$tail,
        [bool]$importantOnly,
        [string]$filterPattern,
        [switch]$RestartIfRunning
    )

    if (-not (Test-Path -LiteralPath $watchScriptPath)) {
        Set-Status "watch-latest-log.ps1 not found in app folder."
        return
    }

    if ($watchTimer.Enabled) {
        if (-not $RestartIfRunning) {
            Set-Status "Watcher is already running in this window."
            return
        }

        $watchTimer.Stop()
        Set-Status "Restarting in-app watcher..."
    }

    $running = Get-RunningWatcher
    if ($running) {
        try {
            Stop-Process -Id $running.Id -Force
            Set-Status "Stopped old external watcher (PID $($running.Id))."
        }
        catch {
        }

        $script:watcherProcess = $null
        $script:watcherPid = $null
    }

    $resolvedLogsPath = Resolve-LogsPath -worldPath $worldPath -logsPath $logsPath
    if ([string]::IsNullOrWhiteSpace($resolvedLogsPath)) {
        Set-Status "No logs folder resolved. Set World folder or Logs folder."
        return
    }

    if (-not (Test-Path -LiteralPath $resolvedLogsPath)) {
        Set-Status "Logs folder not found: $resolvedLogsPath"
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($filterPattern)) {
        try {
            [void][regex]::new($filterPattern)
        }
        catch {
            Set-Status "Invalid filter regex: $($_.Exception.Message)"
            return
        }
    }

    $latest = Get-LatestLogFile -basePath $resolvedLogsPath
    if (-not $latest) {
        Set-Status "No log file found under: $resolvedLogsPath"
        return
    }

    $tailLines = Get-Content -LiteralPath $latest.FullName -Tail $tail -ErrorAction SilentlyContinue
    foreach ($line in $tailLines) {
        if (Should-IncludeLogLine -line $line -importantOnly $importantOnly -filterPattern $filterPattern) {
            Append-LogLine -line $line
        }
    }

    $currentLength = 0L
    try {
        $currentLength = (Get-Item -LiteralPath $latest.FullName -ErrorAction Stop).Length
    }
    catch {
    }

    Set-LiveLogState -watchRootPath $resolvedLogsPath -logFilePath $latest.FullName -importantOnly $importantOnly -filterPattern $filterPattern -position $currentLength
    $watchTimer.Start()

    $suffix = ""
    if (-not [string]::IsNullOrWhiteSpace($filterPattern)) {
        $suffix = " | filter: $filterPattern"
    }

    Set-Status "Started live watcher in-app for logs: $resolvedLogsPath$suffix"
    Set-Status "Streaming from: $($latest.Name)"
}

function Stop-Watcher {
    if ($watchTimer.Enabled) {
        $watchTimer.Stop()
        Set-Status "Stopped in-app watcher."
    }

    Set-LiveLogState -watchRootPath $null -logFilePath $null -importantOnly $false -filterPattern "" -position 0

    $running = Get-RunningWatcher
    if ($running) {
        try {
            Stop-Process -Id $running.Id -Force
            Set-Status "Stopped watcher (PID $($running.Id))."
            $script:watcherProcess = $null
            $script:watcherPid = $null
        }
        catch {
            Set-Status "Failed to stop watcher: $($_.Exception.Message)"
        }
    }
    else {
        Set-Status "No watcher process running."
    }
}

$watchTimer.Add_Tick({
    if ([string]::IsNullOrWhiteSpace($script:activeWatchRootPath)) {
        return
    }

    $latest = Get-LatestLogFile -basePath $script:activeWatchRootPath
    if (-not $latest) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($script:activeLogFilePath) -or ($latest.FullName -ne $script:activeLogFilePath)) {
        Set-Status "Switched to latest log: $($latest.Name)"
        $tailLines = Get-Content -LiteralPath $latest.FullName -Tail 25 -ErrorAction SilentlyContinue
        foreach ($line in $tailLines) {
            if (Should-IncludeLogLine -line $line -importantOnly $script:activeWatchImportantOnly -filterPattern $script:activeWatchFilterPattern) {
                Append-LogLine -line $line
            }
        }

        $newLen = 0L
        try {
            $newLen = (Get-Item -LiteralPath $latest.FullName -ErrorAction Stop).Length
        }
        catch {
        }

        Set-LiveLogState -watchRootPath $script:activeWatchRootPath -logFilePath $latest.FullName -importantOnly $script:activeWatchImportantOnly -filterPattern $script:activeWatchFilterPattern -position $newLen
        return
    }

    $lines = Read-NewLogLines -logFilePath $script:activeLogFilePath
    foreach ($line in $lines) {
        if (Should-IncludeLogLine -line $line -importantOnly $script:activeWatchImportantOnly -filterPattern $script:activeWatchFilterPattern) {
            Append-LogLine -line $line
        }
    }
})

$btnBrowseWorld.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.SelectedPath = $txtWorld.Text
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtWorld.Text = $dialog.SelectedPath
        $txtLogs.Text = (Join-Path $dialog.SelectedPath 'logs')
        Set-Status "World folder selected. Logs path set to world\logs."
    }
})

$btnUseWorldLogs.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtWorld.Text)) {
        Set-Status "Set a world folder first."
        return
    }

    $txtLogs.Text = (Join-Path $txtWorld.Text 'logs')
    Set-Status "Logs path resolved from world folder."
})

$btnLatestWorld.Add_Click({
    $latestWorld = Get-DefaultWorldPath
    if ([string]::IsNullOrWhiteSpace($latestWorld)) {
        Set-Status "No world with logs found under UserData\Saves."
        return
    }

    $txtWorld.Text = $latestWorld
    $txtLogs.Text = (Join-Path $latestWorld 'logs')
    Set-Status "Latest world selected: $latestWorld"
})

$btnBrowseLogs.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.SelectedPath = $txtLogs.Text
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtLogs.Text = $dialog.SelectedPath
    }
})

$btnBrowseExe.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Executable (*.exe)|*.exe|Batch (*.bat;*.cmd)|*.bat;*.cmd|All files (*.*)|*.*"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtLaunch.Text = '"' + $dialog.FileName + '"'
    }
})

# Save button will persist via profile store in v2
$btnSave.Add_Click({
    try {
        # update profile from UI
        $profile.WorldPath = $txtWorld.Text
        $profile.LogsPath = $txtLogs.Text
        $profile.Tail = [int]$numTail.Value
        $profile.ImportantOnly = $chkImportant.Checked
        $profile.FilterPattern = $txtFilter.Text
        $profile.LaunchCommand = $txtLaunch.Text

        Write-StoreV2 $settingsPathV2 $store
        Set-Status "Settings saved (profile: $($profile.Name))."
    }
    catch {
        Set-Status "Could not save settings: $($_.Exception.Message)"
    }
})

$btnWatch.Add_Click({
    Start-Watcher -worldPath $txtWorld.Text -logsPath $txtLogs.Text -tail ([int]$numTail.Value) -importantOnly $chkImportant.Checked -filterPattern $txtFilter.Text -RestartIfRunning
})

$btnStopWatch.Add_Click({
    Stop-Watcher
})

$btnLaunch.Add_Click({
    $resolvedLogsPath = Resolve-LogsPath -worldPath $txtWorld.Text -logsPath $txtLogs.Text
    $launchCommand = $txtLaunch.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($launchCommand)) {
        Start-Watcher -worldPath $txtWorld.Text -logsPath $txtLogs.Text -tail ([int]$numTail.Value) -importantOnly $chkImportant.Checked -filterPattern $txtFilter.Text -RestartIfRunning
        Set-Status "No launch command set; watcher started only."
        return
    }

    $expandedLaunch = Expand-LaunchCommand -launchCommand $launchCommand -worldPath $txtWorld.Text -logsPath $resolvedLogsPath

    try {
        Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $expandedLaunch | Out-Null
        Set-Status "Launch command started."
    }
    catch {
        Set-Status "Launch failed: $($_.Exception.Message)"
        return
    }

    Start-Sleep -Milliseconds 700
    Start-Watcher -worldPath $txtWorld.Text -logsPath $txtLogs.Text -tail ([int]$numTail.Value) -importantOnly $chkImportant.Checked -filterPattern $txtFilter.Text -RestartIfRunning
})

$btnOpenLatest.Add_Click({
    $resolvedLogsPath = Resolve-LogsPath -worldPath $txtWorld.Text -logsPath $txtLogs.Text
    if ([string]::IsNullOrWhiteSpace($resolvedLogsPath) -or -not (Test-Path -LiteralPath $resolvedLogsPath)) {
        Set-Status "Logs path is not valid: $resolvedLogsPath"
        return
    }

    $latest = Get-LatestLogFile -basePath $resolvedLogsPath
    if (-not $latest) {
        Set-Status "No log file found under: $resolvedLogsPath"
        return
    }

    try {
        Start-Process -FilePath $latest.FullName | Out-Null
        Set-Status "Opened latest log: $($latest.Name)"
    }
    catch {
        Set-Status "Could not open latest log: $($_.Exception.Message)"
    }
})

$btnExit.Add_Click({
    Stop-Watcher
    $form.Close()
})

$form.Add_FormClosing({
    Stop-Watcher

    if ($watchTimer) {
        $watchTimer.Stop()
        $watchTimer.Dispose()
    }

    if ($themeHeaderImage) {
        $themeHeaderImage.Dispose()
    }
    if ($themeLogoImage) {
        $themeLogoImage.Dispose()
    }
})

# --- v2 profile-backed settings initialization ---
$settingsPathV2 = if ($exeDir) { Join-Path $exeDir "world-helper-gui.settings.v2.json" } else { Join-Path $scriptRoot "world-helper-gui.settings.v2.json" }
$store = Read-StoreV2 $settingsPathV2
$profile = Get-ActiveProfile $store

# Populate profile list
$cmbProfiles.DisplayMember = 'Name'
function Refresh-ProfileCombo {
    $cmbProfiles.Items.Clear()
    for ($i = 0; $i -lt $store.Profiles.Count; $i++) {
        $cmbProfiles.Items.Add($store.Profiles[$i]) | Out-Null
    }

    $selectedIndex = -1
    for ($i = 0; $i -lt $store.Profiles.Count; $i++) {
        if ($store.Profiles[$i].Id -eq $store.ActiveProfileId) { $selectedIndex = $i; break }
    }

    if ($selectedIndex -ge 0) { $cmbProfiles.SelectedIndex = $selectedIndex }
    elseif ($cmbProfiles.Items.Count -gt 0) { $cmbProfiles.SelectedIndex = 0; $store.ActiveProfileId = ($cmbProfiles.SelectedItem).Id; $profile = Get-ActiveProfile $store }
}

Refresh-ProfileCombo

# Map active profile to UI
$txtWorld.Text = [string]$profile.WorldPath
$txtLogs.Text = [string]$profile.LogsPath

if ([string]::IsNullOrWhiteSpace($txtLogs.Text) -and -not [string]::IsNullOrWhiteSpace($txtWorld.Text)) {
    $txtLogs.Text = (Join-Path $txtWorld.Text 'logs')
}

$savedTail = [int]$profile.Tail
if ($savedTail -lt [int]$numTail.Minimum) { $savedTail = [int]$numTail.Minimum }
if ($savedTail -gt [int]$numTail.Maximum) { $savedTail = [int]$numTail.Maximum }
$numTail.Value = [decimal]$savedTail
$chkImportant.Checked = [bool]$profile.ImportantOnly
$txtFilter.Text = [string]$profile.FilterPattern
$txtLaunch.Text = [string]$profile.LaunchCommand

# Wire UI -> profile updates (keeps store in-memory updated)
$txtWorld.Add_TextChanged({ $profile.WorldPath = $txtWorld.Text })
$txtLogs.Add_TextChanged({ $profile.LogsPath = $txtLogs.Text })
$numTail.Add_ValueChanged({ $profile.Tail = [int]$numTail.Value })
$chkImportant.Add_CheckedChanged({ $profile.ImportantOnly = $chkImportant.Checked })
$txtFilter.Add_TextChanged({ $profile.FilterPattern = $txtFilter.Text })
$txtLaunch.Add_TextChanged({ $profile.LaunchCommand = $txtLaunch.Text })

# Profile combo handlers
$cmbProfiles.Add_SelectedIndexChanged({
    $sel = $cmbProfiles.SelectedItem
    if ($sel) {
        $store.ActiveProfileId = $sel.Id
        $profile = Get-ActiveProfile $store
        $txtWorld.Text = [string]$profile.WorldPath
        $txtLogs.Text = [string]$profile.LogsPath
        $numTail.Value = [decimal]$profile.Tail
        $chkImportant.Checked = [bool]$profile.ImportantOnly
        $txtFilter.Text = [string]$profile.FilterPattern
        $txtLaunch.Text = [string]$profile.LaunchCommand
    }
})

# Profile management buttons
$btnProfileNew.Add_Click({
    # simple name prompt
    [void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")
    $name = [Microsoft.VisualBasic.Interaction]::InputBox("Profile name:", "New Profile", "New Profile")
    if (-not [string]::IsNullOrWhiteSpace($name)) {
        $new = New-Profile -Name $name
        $store.Profiles += ,$new
        $store.ActiveProfileId = $new.Id
        $profile = Get-ActiveProfile $store
        Write-StoreV2 $settingsPathV2 $store
        Refresh-ProfileCombo
        Set-Status "Created profile: $name"
    }
})

$btnProfileDup.Add_Click({
    $cur = Get-ActiveProfile $store
    if ($cur) {
        $new = New-Profile -Name ($cur.Name + " Copy")
        $new.WorldPath = $cur.WorldPath
        $new.LogsPath = $cur.LogsPath
        $new.LaunchCommand = $cur.LaunchCommand
        $new.Tail = $cur.Tail
        $new.ImportantOnly = $cur.ImportantOnly
        $new.FilterPattern = $cur.FilterPattern
        $store.Profiles += ,$new
        $store.ActiveProfileId = $new.Id
        $profile = Get-ActiveProfile $store
        Write-StoreV2 $settingsPathV2 $store
        Refresh-ProfileCombo
        Set-Status "Duplicated profile: $($cur.Name) -> $($new.Name)"
    }
})

$btnProfileDelete.Add_Click({
    $cur = Get-ActiveProfile $store
    if (-not $cur) { return }
    $res = [System.Windows.Forms.MessageBox]::Show("Delete profile '$($cur.Name)'? This cannot be undone.", "Delete Profile", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($res -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $newList = @()
    foreach ($p in $store.Profiles) { if ($p.Id -ne $cur.Id) { $newList += $p } }
    if ($newList.Count -eq 0) {
        $newList += (Get-DefaultStoreV2).Profiles[0]
    }
    $store.Profiles = $newList
    if (-not ($store.Profiles | Where-Object { $_.Id -eq $store.ActiveProfileId })) {
        $store.ActiveProfileId = $store.Profiles[0].Id
    }
    $profile = Get-ActiveProfile $store
    Write-StoreV2 $settingsPathV2 $store
    Refresh-ProfileCombo
    Set-Status "Deleted profile: $($cur.Name)"
})

if ($themeHeaderImage -or $themeLogoImage) {
    Set-Status "Theme assets loaded. Header: $(if ($themeHeaderImage) { 'yes' } else { 'no' }), Logo: $(if ($themeLogoImage) { 'yes' } else { 'no' })."
}
else {
    Set-Status "No custom assets found in assets\\ui or assets\\branding. Using built-in Hytale-inspired theme."
}

Set-Status "GUI ready. QoL features: restart-safe watcher, regex filter, and Open Latest Log. Profiles enabled."
[void]$form.ShowDialog()
