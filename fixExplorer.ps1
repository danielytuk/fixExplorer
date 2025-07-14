# Self-elevate the script
function Elevate-Script {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

# Call the self-elevation function
Elevate-Script

# Define the paths to the folders
$automaticDestinationsPath = "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"
$customDestinationsPath = "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"

# Function to delete all files in a directory
function Clear-Directory {
    param (
        [string]$Path
    )
    if (Test-Path $Path) {
        Remove-Item "$Path\*" -Force
    }
}

# Clear the AutomaticDestinations and CustomDestinations folders
Clear-Directory -Path $automaticDestinationsPath
Clear-Directory -Path $customDestinationsPath

# Empty the Recycle Bin
Clear-RecycleBin -Force

# Clear DNS cache
ipconfig /flushdns

# Clean temporary files
$cleanmgr = New-Object -ComObject Shell.Application
$cleanmgr.NameSpace(0xA).Items() | ForEach-Object { $_.InvokeVerb('delete') }

# Restart File Explorer
Stop-Process -Name explorer -Force
Start-Process explorer

Write-Host "Temporary files cleared and Recycle Bin emptied."
