# BrowserBackup.ps1 - PARAMETER #3 FIX (CMD.exe Aufruf statt Start-Process!)
param(
    [ValidateSet("Firefox", "Edge", "Both")] [string]$Browser = "Both",
    [ValidateSet("Backup", "Restore")] [string]$Action = "Backup",
    [string]$BackupPath = "H:\Browserbackup"
)

# Ordner + Log
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir = Join-Path $BackupPath "$Browser`_$Timestamp"
$LogFile = "$BackupDir\robocopy.log"
New-Item $BackupDir -ItemType Directory -Force | Out-Null

Write-Host "Backup: $BackupDir" -Foreground Cyan
Write-Host "Log: $LogFile" -Foreground Yellow

# Browser Stop
Write-Host "`nProzesse stoppen... (1=fortfahren)"
$procs = Get-Process firefox*,msedge* -EA SilentlyContinue
if ($procs) { $procs.Name | Sort | Get-Unique }
Read-Host "Browser manuell schließen? ENTER"

# Firefox Profil
$FFPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
$FFProfile = Get-ChildItem $FFPath -Directory | Where Name -match '\.default' | Sort LastWriteTime -Desc | Select -First 1

# Edge Profil (LocalState)
$EdgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
$LocalState = Get-Content "$EdgePath\Local State" -Raw -EA SilentlyContinue | ConvertFrom-Json -EA SilentlyContinue
$EdgeProfileName = ($LocalState.profile.info_cache.PSObject.Properties | Where Name -ne "LastActive" | Select -First 1).Name ?? "Default"
$EdgeProfile = "$EdgePath\$EdgeProfileName"

# === ROBOCOPY CMD.EXE (Parameter #3 SAFE!) ===
function Backup-WithRobocopy {
    param($Source, $Dest)
    
    # CMD.exe für korrekte Parameter-Parsing
    $cmdArgs = "/c `"robocopy `"$Source`" `"$Dest`" /E /COPY:DAT /R:3 /LOG:`"$LogFile`" /TEE`""
    Write-Host "CMD: $cmdArgs" -Foreground Gray
    
    $proc = Start-Process cmd.exe -ArgumentList $cmdArgs -Wait -PassThru -NoNewWindow
    $exit = $proc.ExitCode
    
    if ($exit -le 7) {
        Write-Host "✓ Robocopy OK (Code $exit)" -Foreground Green
    } elseif ($exit -eq 16) {
        Write-Warning "Code 16: Keine Dateien → Fallback"
        # Fallback Key-Dateien
        @("Bookmarks", "places.sqlite", "prefs.js", "Local State") | % {
            $f = Join-Path $Source $_
            if (Test-Path $f) { Copy-Item $f $Dest -Force; Write-Host "✓ $_" }
        }
    } else {
        Write-Error "Fehler $exit"
    }
    
    # Log zeigen
    if (Test-Path $LogFile) {
        Write-Host "`n=== LOG (letzte 10 Zeilen) ===" -Foreground Cyan
        Get-Content $LogFile -Tail 10
        notepad $LogFile  # ÖFFNET!
    }
}

# BACKUP
if ($Action -eq "Backup") {
    if ($Browser -match "Firefox" -and $FFProfile) {
        Backup-WithRobocopy $FFProfile.FullName $BackupDir\Firefox
    }
    if ($Browser -match "Edge") {
        Backup-WithRobocopy $EdgeProfile $BackupDir\Edge
    }
}

Write-Host "`n📁 Backup: $BackupDir" -Foreground Green
Get-ChildItem $BackupDir -Recurse -File | Measure Length -Sum | % { "Größe: $([math]::Round($_.Sum/1MB,1)) MB" }
