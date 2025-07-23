# Change app to detect [Application ID]
$AppToDetect = "Mozilla.Firefox"
$MinVersionToDetect = "128.0" # Specify the minimum version to detect

<# FUNCTIONS #>

Function Get-WingetCmd {

    $WingetCmd = $null

    #Get WinGet Path
    try {
        #Get Admin Context Winget Location
        $WingetInfo = (Get-Item "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_8wekyb3d8bbwe\winget.exe").VersionInfo | Sort-Object -Property FileVersionRaw
        #If multiple versions, pick most recent one
        $WingetCmd = $WingetInfo[-1].FileName
    }
    catch {
        #Get User context Winget Location
        if (Test-Path "$env:LocalAppData\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\winget.exe") {
            $WingetCmd = "$env:LocalAppData\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\winget.exe"
        }
    }

    return $WingetCmd
}

Function Compare-Version {
    param (
        [string]$Version1,
        [string]$Version2
    )
    if (![string]::IsNullOrEmpty($Version1) -and ![string]::IsNullOrEmpty($Version2)) {
        try {
            $v1 = [Version]$Version1
            $v2 = [Version]$Version2
            return $v1.CompareTo($v2)
        }
        catch {
            return -1
        }
    } else {
        return -1
    }
}

<# MAIN #>

# Get WinGet Location Function
$winget = Get-WingetCmd

# Set json export file
$JsonFile = "$env:TEMP\InstalledApps.json"

# Get installed apps and version in json file
& $winget export -o $JsonFile --accept-source-agreements | Out-Null

# Get json content
$Json = Get-Content $JsonFile -Raw | ConvertFrom-Json

# Get apps and version in hashtable
$Packages = $Json.Sources.Packages

# Remove json file
Remove-Item $JsonFile -Force

# Get installed apps and versions from winget list
$WingetList = & $winget list --accept-source-agreements | Out-String

# Parse winget list results
$InstalledApps = @()
foreach ($line in $WingetList -split "`n") {
    if ($line -match "^\s*Name\s*ID\s*Version\s*Verfügbar\s*Quelle") { continue }
    if ($line -match "^\s*-{5,}") { continue }
    if ($line -match "^\s*$") { continue }

    $parts = $line -split '\s{2,}'
    if ($parts.Count -ge 3) {
        $InstalledApps += [PSCustomObject]@{
            Name    = $parts[0].Trim()
            ID      = $parts[1].Trim()
            Version = $parts[2].Trim()
        }
    }
}

# Check only the specified application
$Package = $Packages | Where-Object { $_.PackageIdentifier -eq $AppToDetect }
if ($Package) {
    $InstalledApp = $InstalledApps | Where-Object { $_.ID -eq $AppToDetect }
    if ($InstalledApp) {
        $ComparisonResult = Compare-Version $InstalledApp.Version $MinVersionToDetect
        if ($ComparisonResult -ge 0) {
            Write-Host "Installed!"
            exit 0 # Installed and version matches or is greater
        }
    }
}
Write-Host "Not Installed or Version Mismatch!"
exit 1 # Not installed or version mismatch
