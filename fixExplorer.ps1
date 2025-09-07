# =====================================================================
# Ultimate Explorer Maintenance Script (Windows 11) - Parallel Version
# =====================================================================

# --- Self-elevation ---
function Elevate-Script {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}
Elevate-Script

# --- Logging setup ---
$LogPath = "C:\Temp"
$LogFile = Join-Path $LogPath "explorer-maintenance.log"
if (!(Test-Path $LogPath)) { New-Item -ItemType Directory -Path $LogPath | Out-Null }
Start-Transcript -Path $LogFile -Append
Write-Output "===== Explorer Maintenance Started: $(Get-Date) ====="

# --- Check if System Protection is enabled on C: and confirm with user if not ---
function Check-SystemProtection {
    try {
        $protection = Get-CimInstance -Namespace "root/default" -ClassName SystemRestore | Where-Object { $_.Drive -eq "C:" }
        if ($protection -and $protection.Disable -eq $false) {
            Write-Output "System Protection is enabled on C:. Proceeding to create a restore point."
            return $true
        } else {
            Write-Warning "System Protection is disabled on C:. System restore point cannot be created!"
            $response = Read-Host "System Protection is OFF. Do you want to continue anyway? (Y/N)"
            if ($response -notmatch '^[Yy]$') {
                Write-Output "User chose not to continue. Exiting script."
                Stop-Transcript
                exit
            }
            return $false
        }
    } catch {
        Write-Warning "Failed to check System Protection: $_"
        $response = Read-Host "Could not verify System Protection. Continue anyway? (Y/N)"
        if ($response -notmatch '^[Yy]$') {
            Write-Output "User chose not to continue. Exiting script."
            Stop-Transcript
            exit
        }
        return $false
    }
}

# --- Create a system restore point ---
function Create-SystemRestorePoint {
    if (Check-SystemProtection) {
        try {
            Write-Output "Creating system restore point..."
            $sr = New-Object -ComObject "SystemRestore"
            $description = "Explorer Maintenance Script Restore Point"
            $result = $sr.CreateRestorePoint($description, 0, 100)  # 0 = Application install, 100 = Restore point type
            if ($result -eq 0) {
                Write-Output "System restore point created successfully."
            } else {
                Write-Warning "System restore point creation returned code $result. It may have failed."
            }
        } catch {
            Write-Warning "Failed to create system restore point: $_"
        }
    } else {
        Write-Warning "Skipping restore point creation due to disabled System Protection."
    }
}

# --- Invoke restore point creation ---
Create-SystemRestorePoint

# --- Summary object ---
$Summary = [PSCustomObject]@{
    DeletedRecent      = 0
    DeletedCache       = 0
    DeletedQuick       = 0
    RecycleBinCleared  = $false
    TempCleaned        = $false
    IndexRebuilt       = $false
    ExplorerRestarted  = $false
}

# --- Paths ---
$AutomaticDestinations = Join-Path $env:APPDATA "Microsoft\Windows\Recent\AutomaticDestinations"
$CustomDestinations    = Join-Path $env:APPDATA "Microsoft\Windows\Recent\CustomDestinations"
$QuickAccessPath       = Join-Path $AutomaticDestinations "f01b4d95cf55d32a.automaticDestinations-ms"
$ThumbCachePath        = Join-Path $env:LocalAppData "Microsoft\Windows\Explorer"
$IconCachePath         = Join-Path $env:LocalAppData "IconCache.db"
$TempPath              = $env:TEMP

# --- Function: clear files older than X days ---
function Clear-OldFiles {
    param (
        [string]$Path,
        [int]$Days = 3
    )
    $deleted = 0
    if (Test-Path $Path) {
        Get-ChildItem -Path $Path -File -Recurse -Force | Where-Object {
            $_.LastWriteTime -lt (Get-Date).AddDays(-$Days)
        } | ForEach-Object {
            try { Remove-Item $_.FullName -Force -ErrorAction Stop; $deleted++ } catch {}
        }
    }
    return $deleted
}

# --- Start parallel cleanup jobs ---
$Jobs = @()

# Recent Items
$Jobs += Start-Job -ScriptBlock {
    $paths = @(
        "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations",
        "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"
    )
    $total = 0
    foreach ($p in $paths) { $total += (Clear-OldFiles -Path $p -Days 3) }
    return @{DeletedRecent=$total}
}

# Icon/Thumbnail cache
$Jobs += Start-Job -ScriptBlock {
    $count = 0
    $iconPath = Join-Path $env:LocalAppData "IconCache.db"
    if (Test-Path $iconPath -PathType Leaf -and (Get-Item $iconPath).LastWriteTime -lt (Get-Date).AddDays(-1)) {
        Remove-Item $iconPath -Force -ErrorAction SilentlyContinue
        $count++
    }
    $thumbPath = Join-Path $env:LocalAppData "Microsoft\Windows\Explorer"
    if (Test-Path $thumbPath) {
        Get-ChildItem $thumbPath -Include thumbcache*.db -File -Force -Recurse | Where-Object {
            $_.LastWriteTime -lt (Get-Date).AddDays(-1)
        } | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue; $count++ }
    }
    return @{DeletedCache=$count}
}

# Quick Access
$Jobs += Start-Job -ScriptBlock {
    $count = 0
    $qaPath = Join-Path $env:APPDATA "Microsoft\Windows\Recent\AutomaticDestinations\f01b4d95cf55d32a.automaticDestinations-ms"
    if (Test-Path $qaPath -PathType Leaf -and (Get-Item $qaPath).LastWriteTime -lt (Get-Date).AddDays(-2)) {
        Remove-Item $qaPath -Force -ErrorAction SilentlyContinue
        $count++
    }
    return @{DeletedQuick=$count}
}

# Temp files (exclude explorer-maintenance.log)
$Jobs += Start-Job -ScriptBlock {
    param($LogFilePath)
    $deleted = 0
    $tempPath = $env:TEMP
    Get-ChildItem $tempPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -ne $LogFilePath
    } | ForEach-Object {
        try { Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop; $deleted++ } catch {}
    }
    return @{TempCleaned=($deleted -gt 0)}
} -ArgumentList $LogFile

# Wait for all jobs and merge results
Receive-Job -Job $Jobs -Wait | ForEach-Object {
    foreach ($key in $_.Keys) { $Summary.$key = $_.$key }
}
# Remove completed jobs
$Jobs | Remove-Job

# --- Rebuild Windows Search Index ---
Write-Output "Restarting Windows Search service..."
if (Get-Service -Name "WSearch" -ErrorAction SilentlyContinue) {
    Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
    $IndexPath = "$env:ProgramData\Microsoft\Search\Data\Applications\Windows"
    if (Test-Path $IndexPath) { Remove-Item "$IndexPath\*" -Recurse -Force -ErrorAction SilentlyContinue }
    Start-Service -Name "WSearch"
    try {
        $sm = New-Object -ComObject Microsoft.Windows.Search.Manager
        $cm = $sm.GetCatalog("SystemIndex")
        $cm.Reindex()
        $Summary.IndexRebuilt = $true
    } catch {}
    finally { if ($sm) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sm) | Out-Null } }
}

# --- Restart SearchHost and ShellExperienceHost ---
foreach ($proc in @("SearchHost","ShellExperienceHost")) {
    Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    if ($proc -eq "ShellExperienceHost") { Start-Process "$env:Windir\System32\ShellExperienceHost.exe" }
}

# --- Empty Recycle Bin ---
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
$Summary.RecycleBinCleared = $true

# --- Restart Explorer ---
Stop-Process -Name explorer -Force
Start-Process explorer
$Summary.ExplorerRestarted = $true

# --- Summary ---
Write-Output "===== Summary ====="
$Summary | Format-List
Write-Output "===== Explorer Maintenance Completed: $(Get-Date) ====="
Stop-Transcript
