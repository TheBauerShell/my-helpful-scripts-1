# BrowserBackup.ps1 - Vollständiges Backup- und Restore-Script für Firefox und Edge
# Autor: Perplexity AI, basierend auf Standardpfaden [web:2][web:5][web:9][web:11]
# WICHTIG: Führen Sie das Script als Administrator aus. Schließen Sie die Browser vor dem Ausführen!
# Für Restore: Stoppen Sie die Browser-Prozesse (Task-Manager).

param(
    [ValidateSet("Firefox", "Edge", "Both")]
    [string]$Browser = "Both",
    
    [ValidateSet("Backup", "Restore")]
    [string]$Action = "Backup",
    
    [string]$BackupPath = "H:\Browserbackup"
)

# Schritt 1: Backup-Verzeichnis erstellen, falls nicht vorhanden
# Erklärung: Testet, ob H:\Browserbackup existiert. Wenn nicht, wird es mit New-Item erstellt. [web:16]
if (-not (Test-Path $BackupPath)) {
    New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
    Write-Host "Verzeichnis $BackupPath erstellt." -ForegroundColor Green
}

# Schritt 2: Pfade definieren
# Erklärung: Standardpfade für Firefox (AppData\Roaming) und Edge (AppData\Local). Firefox hat zufällige Profile-Namen, daher wird das aktuellste kopiert. Edge verwendet 'Default' als Standard-Profil. [web:2][web:3][web:5][web:9][web:11][web:14]
$FirefoxProfilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
$EdgeUserDataPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if ($Browser -eq "Firefox" -or $Browser -eq "Both") {
    $FirefoxBackupDir = Join-Path $BackupPath "Firefox_$Timestamp"
}

if ($Browser -eq "Edge" -or $Browser -eq "Both") {
    $EdgeBackupDir = Join-Path $BackupPath "Edge_$Timestamp"
}

# Schritt 3: Browser-Prozesse prüfen und warnen
# Erklärung: Überprüft laufende Prozesse mit Get-Process. Warnt den Benutzer, da Kopieren laufender Profile zu Korruption führen kann. [web:25][web:29]
if ($Action -eq "Backup") {
    $Processes = @()
    if ($Browser -eq "Firefox" -or $Browser -eq "Both") { $Processes += "firefox" }
    if ($Browser -eq "Edge" -or $Browser -eq "Both") { $Processes += "msedge" }
    foreach ($proc in $Processes) {
        if (Get-Process -Name $proc -ErrorAction SilentlyContinue) {
            Write-Warning "Schließen Sie $proc vor dem Backup! Drücken Sie eine Taste zum Fortfahren..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
}

# Schritt 4: Backup-Funktion
# Erklärung: Kopiert komplette Profile-Ordner mit Robocopy für Zuverlässigkeit (unterstützt Inkrementell, Fehlerbehandlung). /E = alle Unterordner, /COPYALL = alle Attribute, /R:3 = 3 Wiederholungen. [web:16][web:20][web:21][web:24][web:25]
function Backup-Browser {
    param($Source, $Dest)

    if (-not (Test-Path $Source)) {
        Write-Warning "Quelle nicht gefunden: $Source"
        return
    }

    New-Item -Path $Dest -ItemType Directory -Force | Out-Null

    # Robocopy für sicheres Kopieren (Exit-Code 0-7 = OK)
    $robocopyArgs = @($Source, $Dest, "/E", "/COPYALL", "/R:3", "/W:5", "/MT:8")
    $process = Start-Process robocopy -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -le 7) {
        Write-Host "Backup erfolgreich: $Dest" -ForegroundColor Green
    } else {
        Write-Error "Robocopy-Fehler (Code $($process.ExitCode)): $Dest"
    }
}

# Schritt 5: Restore-Funktion
# Erklärung: Für Restore wird der neueste Backup-Ordner verwendet. Bestehende Dateien werden überschrieben. Browser muss geschlossen sein. Nach Restore Browser neu starten für Anwendung. WARNUNG: Kann Daten überschreiben! [web:18][web:22][web:25][web:29]
function Restore-Browser {
    param($BackupRoot, $TargetRoot)

    $LatestBackup = Get-ChildItem $BackupRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $LatestBackup) {
        Write-Warning "Kein Backup gefunden in $BackupRoot"
        return
    }

    $Source = $LatestBackup.FullName
    Write-Host "Restore aus neuestem Backup: $Source -> $TargetRoot" -ForegroundColor Yellow
    $confirm = Read-Host "Fortfahren? (j/n)"
    if ($confirm -ne "j") { return }

    # Bestehendes Ziel sichern (optional)
    $TargetBackup = "$TargetRoot.backup_$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if (Test-Path $TargetRoot) {
        Rename-Item $TargetRoot $TargetBackup
        Write-Host "Aktuelles Profil gesichert als: $TargetBackup"
    }

    # Kopieren
    Backup-Browser $Source $TargetRoot  # Wiederverwendung der Backup-Funktion (umgekehrt)
}

# Schritt 6: Ausführung basierend auf Parametern
# Erklärung: Switch wählt Browser, Action bestimmt Backup/Restore. Flexibel für einzelne oder beide Browser.
switch ($Action) {
    "Backup" {
        if ($Browser -eq "Firefox" -or $Browser -eq "Both") {
            $LatestProfile = Get-ChildItem $FirefoxProfilesPath -Directory | 
                Where-Object { $_.Name -match '\.(default|default-release)$' } | 
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($LatestProfile) {
                Backup-Browser $LatestProfile.FullName $FirefoxBackupDir
            } else {
                Write-Warning "Firefox-Profil nicht gefunden in $FirefoxProfilesPath"
            }
        }
        if ($Browser -eq "Edge" -or $Browser -eq "Both") {
            $DefaultProfile = Join-Path $EdgeUserDataPath "Default"
            Backup-Browser $EdgeUserDataPath $EdgeBackupDir  # Voll User Data für alle Profile/Settings
        }
    }
    "Restore" {
        if ($Browser -eq "Firefox" -or $Browser -eq "Both") {
            Restore-Browser (Join-Path $BackupPath "Firefox_*") $FirefoxProfilesPath
            # Hinweis: Nach Restore profile.ini anpassen, falls nötig (manuell via about:profiles)
        }
        if ($Browser -eq "Edge" -or $Browser -eq "Both") {
            Restore-Browser (Join-Path $BackupPath "Edge_*") $EdgeUserDataPath
        }
    }
}

Write-Host "Fertig! Backup/Restore in $BackupPath. Für Restore neuesten Ordner verwenden." -ForegroundColor Green
