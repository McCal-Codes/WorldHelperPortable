# profile-store.v2.ps1 (COPY)
# Simple profile store for WorldHelperPortable v2
# Does NOT assume anything about Hytale, only stores paths and preferences.

function Get-DefaultStoreV2 {
    return @{
        Version = 2
        ActiveProfileId = "default"
        Profiles = @(
            @{
                Id = "default"
                Name = "Default"
                WorldPath = ""
                LogsPath = ""
                LaunchCommand = ""
                Tail = 80
                ImportantOnly = $false
                FilterPattern = ""
            }
        )
    }
}

function Read-StoreV2([string]$Path) {
    if (-not (Test-Path $Path)) {
        return (Get-DefaultStoreV2)
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        $store = $raw | ConvertFrom-Json -ErrorAction Stop

        # Basic validation / upgrade path
        if ($null -eq $store.Version -or [int]$store.Version -lt 2) {
            # If user still has v1 style settings, migrate safely
            return (Migrate-V1ToV2 -V1Path $Path -V1Json $store)
        }

        # Ensure required fields
        if (-not $store.Profiles) { $store.Profiles = @() }
        if ([string]::IsNullOrWhiteSpace($store.ActiveProfileId)) {
            if ($store.Profiles.Count -gt 0) { $store.ActiveProfileId = $store.Profiles[0].Id } else { $store.ActiveProfileId = "default" }
        }

        return $store
    }
    catch {
        return (Get-DefaultStoreV2)
    }
}

function Write-StoreV2([string]$Path, $Store) {
    $json = $Store | ConvertTo-Json -Depth 10
    $json | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Migrate-V1ToV2([string]$V1Path, $V1Json) {
    # V1 expected keys: WorldPath, LogsPath, Tail, ImportantOnly, FilterPattern, LaunchCommand
    $store = Get-DefaultStoreV2

    $store.Profiles[0].WorldPath = ($V1Json.WorldPath  | ForEach-Object { "$_" })
    $store.Profiles[0].LogsPath  = ($V1Json.LogsPath   | ForEach-Object { "$_" })
    $store.Profiles[0].Tail      = [int]($V1Json.Tail  | ForEach-Object { "$_" })
    $store.Profiles[0].ImportantOnly = [bool]($V1Json.ImportantOnly | ForEach-Object { "$_" })
    $store.Profiles[0].FilterPattern = ($V1Json.FilterPattern | ForEach-Object { "$_" })
    $store.Profiles[0].LaunchCommand = ($V1Json.LaunchCommand | ForEach-Object { "$_" })

    return $store
}

function Get-ActiveProfile($Store) {
    $p = $Store.Profiles | Where-Object { $_.Id -eq $Store.ActiveProfileId } | Select-Object -First 1
    if ($null -eq $p) {
        $p = $Store.Profiles | Select-Object -First 1
        if ($null -eq $p) { $p = (Get-DefaultStoreV2).Profiles[0] }
        $Store.ActiveProfileId = $p.Id
    }
    return $p
}

function New-Profile([string]$Name) {
    $id = ([Guid]::NewGuid().ToString("N")).Substring(0, 10)
    return @{
        Id = $id
        Name = $Name
        WorldPath = ""
        LogsPath = ""
        LaunchCommand = ""
        Tail = 80
        ImportantOnly = $false
        FilterPattern = ""
    }
}
# profile-store.v2.ps1 (COPY)
# Simple profile store for WorldHelperPortable v2
# Does NOT assume anything about Hytale, only stores paths and preferences.

function Get-DefaultStoreV2 {
    return @{
        Version = 2
        ActiveProfileId = "default"
        Profiles = @(
            @{
                Id = "default"
                Name = "Default"
                WorldPath = ""
                LogsPath = ""
                LaunchCommand = ""
                Tail = 80
                ImportantOnly = $false
                FilterPattern = ""
            }
        )
    }
}

function Read-StoreV2([string]$Path) {
    if (-not (Test-Path $Path)) {
        return (Get-DefaultStoreV2)
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        $store = $raw | ConvertFrom-Json -ErrorAction Stop

        # Basic validation / upgrade path
        if ($null -eq $store.Version -or [int]$store.Version -lt 2) {
            # If user still has v1 style settings, migrate safely
            return (Migrate-V1ToV2 -V1Path $Path -V1Json $store)
        }

        # Ensure required fields
        if (-not $store.Profiles) { $store.Profiles = @() }
        if ([string]::IsNullOrWhiteSpace($store.ActiveProfileId)) {
            if ($store.Profiles.Count -gt 0) { $store.ActiveProfileId = $store.Profiles[0].Id } else { $store.ActiveProfileId = "default" }
        }

        return $store
    }
    catch {
        return (Get-DefaultStoreV2)
    }
}

function Write-StoreV2([string]$Path, $Store) {
    $json = $Store | ConvertTo-Json -Depth 10
    $json | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Migrate-V1ToV2([string]$V1Path, $V1Json) {
    # V1 expected keys: WorldPath, LogsPath, Tail, ImportantOnly, FilterPattern, LaunchCommand
    $store = Get-DefaultStoreV2

    $store.Profiles[0].WorldPath = ($V1Json.WorldPath  | ForEach-Object { "$_" })
    $store.Profiles[0].LogsPath  = ($V1Json.LogsPath   | ForEach-Object { "$_" })
    $store.Profiles[0].Tail      = [int]($V1Json.Tail  | ForEach-Object { "$_" })
    $store.Profiles[0].ImportantOnly = [bool]($V1Json.ImportantOnly | ForEach-Object { "$_" })
    $store.Profiles[0].FilterPattern = ($V1Json.FilterPattern | ForEach-Object { "$_" })
    $store.Profiles[0].LaunchCommand = ($V1Json.LaunchCommand | ForEach-Object { "$_" })

    return $store
}

function Get-ActiveProfile($Store) {
    $p = $Store.Profiles | Where-Object { $_.Id -eq $Store.ActiveProfileId } | Select-Object -First 1
    if ($null -eq $p) {
        $p = $Store.Profiles | Select-Object -First 1
        if ($null -eq $p) { $p = (Get-DefaultStoreV2).Profiles[0] }
        $Store.ActiveProfileId = $p.Id
    }
    return $p
}

function New-Profile([string]$Name) {
    $id = ([Guid]::NewGuid().ToString("N")).Substring(0, 10)
    return @{
        Id = $id
        Name = $Name
        WorldPath = ""
        LogsPath = ""
        LaunchCommand = ""
        Tail = 80
        ImportantOnly = $false
        FilterPattern = ""
    }
}
