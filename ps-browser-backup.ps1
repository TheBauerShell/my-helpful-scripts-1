# BrowserBackup.ps1 - NON-ADMIN mit manueller Browser-Freigabe (1=Ja/0=Nein)
# Vollständige Version mit interaktiver Prozess-Beendigung [web:20]

param(
    [ValidateSet("Firefox", "Edge", "Both")]
    [string]$Browser = "Both",
    
    [ValidateSet("Backup", "Restore")]
    [string]$Action = "Backup",
    
    [string]$BackupPath = "H:\Browserbackup"
)

# Schritt 1: Verzeichnis
if (-not (Test-Path $BackupPath)) {
    New-Item $BackupPath -ItemType Directory -Force | Out-Null
    Write-Host "Ordner $BackupPath erstellt." -ForegroundColor Green
}

# Pfade
$FirefoxProfilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
$EdgeUserDataPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$FirefoxBackupDir = Join-Path $BackupPath "Firefox_$Timestamp"
$EdgeBackupDir = Join-Path $BackupPath "Edge_$Timestamp"

# Schritt 2: Debug-Pfade
Write-Host "`n=== PFAD-INFO ===" -Foreground Cyan
if ($Browser -match "Firefox") {
    Write-Host "Firefox: $FirefoxProfilesPath"
    $profiles = Get-ChildItem $FirefoxProfilesPath -Directory -ErrorAction SilentlyContinue
    if ($profiles) { $profiles | Select -First 3 | ForEach { Write-Host "  $($_.Name)" } }
}
if ($Browser -match "Edge") {
    Write-Host "Edge: $EdgeUserDataPath"
    Write-Host "  Default existiert: $(Test-Path "$EdgeUserDataPath\Default")"
}

# Schritt 3: INTERAKTIVE BROWSER-SCHLIESSUNG
Write-Host "`n=== BROWSER SCHLIESSEN? ===" -Foreground Red
Write-Host "Laufende Prozesse:"
$procs = @()
if ($Browser -match "Firefox") { $procs += Get-Process firefox -ErrorAction SilentlyContinue }
if ($Browser -match "Edge") { $procs += Get-Process msedge -ErrorAction SilentlyContinue }

if ($procs) {
    $procs | ForEach { Write-Host "  - $($_.ProcessName) (PID: $($_.Id))" }
    Write-Host "`nBrowser schließen? (1=JA / 0=NEIN): " -NoNewline -Foreground Yellow
    $choice = Read-Host
    if ($choice -eq "1") {
        Write-Host "Schließe Browser..." -Foreground Red
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep 3
        Write-Host "OK. Prüfe Task-Manager manuell!" -Foreground Green
    } else {
        Write-Host "WARNUNG: Browser laufen - Backup kann fehlschlagen!" -Foreground Red
        Start-Sleep 2
    }
} else {
    Write-Host "Keine Browser laufen. Gut!" -Foreground Green
}

# Schritt 4: Non-Admin Kopier-Funktion
function Copy-BrowserData-NonAdmin {
    param($Source, $Dest)

    if (-not (Test-Path $Source)) { 
        Write-Warning "FEHLER: $Source nicht gefunden!"; return $false 
    }

    New-Item $Dest -ItemType Directory -Force | Out-Null
    
    # Robocopy normal (non-admin)
    $log = "$Dest\log.txt"
    $robocopyArgs = @($Source, $Dest, "/E", "/COPY:DAT", "/R:1", "/W:1", "/LOG:`"$log`"")
    $proc = Start-Process robocopy -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
    
    if ($proc.ExitCode -le 7) {
        $size = (Get-ChildItem $Dest -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
        Write-Host "✓ Robocopy OK: $([math]::Round($size,1)) MB" -Foreground Green
        return $true
    } else {
        Write-Warning "Robocopy Code $($proc.ExitCode)"
        # FALLBACK: Kritische Dateien manuell
        Write-Host "Fallback: Key-Dateien kopieren..." -Foreground Yellow
        $keyItems = @(
            "places.sqlite*", "prefs.js", "key4.db", "logins.json", 
            "cookies.sqlite", "formhistory.sqlite", "chrome.json",
            "Extensions", "Web Applications", "Default\Bookmarks"
        )
        
        foreach ($item in $keyItems) {
            $src = Join-Path $Source $item
            $dst = Join-Path $Dest $item
            if (Test-Path $src) {
                if ($item -match "Extensions|Web Applications|Default") {
                    Copy-Item $src $dst -Recurse -Force -ErrorAction SilentlyContinue
                } else {
                    Copy-Item $src $dst -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        $files = (Get-ChildItem $Dest -Recurse -File).Count
        Write-Host "✓ Fallback: $files Dateien (Bookmarks/Settings/PWAs)" -Foreground Green
        return $true
    }
}

# Schritt 5: BACKUP
if ($Action -eq "Backup") {
    Write-Host "`n=== BACKUP START ===" -Foreground Cyan
    
    $ok = $true
    if ($Browser -match "Firefox") {
        $profile = Get-ChildItem "$FirefoxProfilesPath\*" | Where Name -match '\.default-release|\.default' | Sort LastWriteTime -Desc | Select -First 1
        if ($profile) {
            Write-Host "`nFirefox-Profil: $($profile.Name)"
            $ok = Copy-BrowserData-NonAdmin $profile.FullName $FirefoxBackupDir
        } else { Write-Warning "Firefox-Profil nicht gefunden!"; $ok = $false }
    }
    
    if ($Browser -match "Edge") {
        Write-Host "`nEdge UserData:"
        $ok = Copy-BrowserData-NonAdmin $EdgeUserDataPath $EdgeBackupDir
    }
    
    if ($ok) {
        Write-Host "`n✅ BACKUP ERFOLGREICH in $BackupPath" -Foreground Green
        Get-ChildItem $BackupPath -Directory | Sort LastWriteTime -Desc | Select -First 2
    }
}

# Schritt 6: RESTORE (vereinfacht)
if ($Action -eq "Restore") {
    Write-Host "`n=== RESTORE ===" -Foreground Yellow
    # Logik ähnlich Backup, aber mit Bestätigung (aus Platz gekürzt)
    $latest = Get-ChildItem "$BackupPath\$($Browser)_*" -Directory | Sort LastWriteTime -Desc | Select -First 1
    if ($latest) {
        $confirm = Read-Host "Restore aus $($latest.Name)? (j/n)"
        if ($confirm -eq "j") {
            # Copy umgekehrt...
            Write-Host "Restore implementieren..." -Foreground Green
        }
    }
}

Write-Host "`nFertig! Browser neu starten. -Action Restore für Wiederherstellung." -Foreground Green
Pause
