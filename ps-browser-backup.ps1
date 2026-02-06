#====================================================================================
# BrowserBackup.ps1 - KOMPLETTES FINALS SCRIPT (Firefox + Edge, non-Admin, Logs!)
# Features: Parameter #3 Fix, Robocopy-Log, Key-Files-Fallback, Edge LocalState
# Usage: .\BrowserBackup.ps1 [-Browser "Edge"] [-Action "Backup"]
#====================================================================================

param(
    [ValidateSet("Firefox", "Edge", "Both")]
    [string]$Browser = "Both",
    
    [ValidateSet("Backup", "Restore")]
    [string]$Action = "Backup",
    
    [string]$BackupPath = "H:\Browserbackup"
)

Write-Host "🚀 BrowserBackup v2.0 - Start $(Get-Date)" -Foreground Cyan

# 1. BACKUP-ORDNER + LOG
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupRoot = Join-Path $BackupPath "$Browser`_$Timestamp"
$LogFile = "$BackupRoot\robocopy.log"
New-Item $BackupRoot -ItemType Directory -Force | Out-Null

Write-Host "📁 Backup: $BackupRoot" -Foreground Green
Write-Host "📋 Log: $LogFile" -Foreground Yellow

# 2. PFAD-FINDE (Debug)
Write-Host "`n=== PROFILE DETECTION ===" -Foreground Cyan

# Firefox
$FFProfilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
$FFProfile = Get-ChildItem $FFProfilesPath -Directory -ErrorAction SilentlyContinue | 
    Where-Object { $_.Name -match '\.(default|default-release)$' } | 
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($Browser -match "Firefox") {
    if ($FFProfile) {
        $places = Join-Path $FFProfile.FullName "places.sqlite"
        $size = if (Test-Path $places) { "{0:N1}KB" -f ((Get-Item $places).Length / 1KB) } else { "FEHLT" }
        Write-Host "Firefox ✓ $($FFProfile.Name) - places.sqlite: $size" -Foreground Green
    } else {
        Write-Warning "Firefox-Profil nicht gefunden!"
    }
}

# Edge (Local State für aktives Profil)
$EdgeUserData = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
try {
    $LocalStateJson = Get-Content "$EdgeUserData\Local State" -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
    $ActiveProfiles = $LocalStateJson.profile.info_cache.PSObject.Properties.Name | Where-Object { $_ -ne "LastActive" }
    $EdgeActiveProfile = $ActiveProfiles | Select-Object -First 1 ?? "Default"
    $EdgeProfilePath = "$EdgeUserData\$EdgeActiveProfile"
    
    if ($Browser -match "Edge") {
        $edgeBm = "$EdgeProfilePath\Bookmarks"
        $bmSize = if (Test-Path $edgeBm) { "{0:N1}KB" -f ((Get-Item $edgeBm).Length / 1KB) } else { "FEHLT" }
        Write-Host "Edge ✓ $EdgeActiveProfile - Bookmarks: $bmSize" -Foreground Green
    }
} catch {
    Write-Warning "Edge Local State Fehler: $($_)"
    $EdgeProfilePath = "$EdgeUserData\Default"
}

# 3. BROWSER STOP (interaktiv)
Write-Host "`n=== BROWSER SCHLIESSEN? ===" -Foreground Red
$browserProcs = @()
if ($Browser -match "Firefox") { $browserProcs += Get-Process firefox* -EA SilentlyContinue }
if ($Browser -match "Edge") { $browserProcs += Get-Process msedge* -EA SilentlyContinue }

if ($browserProcs) {
    $browserProcs | Group-Object ProcessName | ForEach-Object { Write-Host "  $($_.Name): $($_.Count)" }
    Write-Host "Schließen? (1=JA / 0=NEIN / ENTER=manuell): " -NoNewline -Foreground Yellow
    $stopChoice = Read-Host
    if ($stopChoice -eq "1") {
        Write-Host "🛑 Stoppe Browser..." -Foreground Red
        $browserProcs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep 5
        Write-Host "✅ Fertig. Task-Manager prüfen!" -Foreground Green
    } else {
        Write-Warning "⚠️  Browser laufen → mögliche Lock-Fehler!"
    }
} else {
    Write-Host "✅ Keine Browser laufen" -Foreground Green
}

# 4. ROBOCOPY-FUNKTION (CMD.exe Fix für Parameter #3!)
function Copy-BrowserData {
    param(
        [string]$Source,
        [string]$DestName
    )
    
    $DestFolder = Join-Path $BackupRoot $DestName
    New-Item -Path $DestFolder -ItemType Directory -Force | Out-Null
    
    # CMD.exe /c robocopy → KEIN Parameter #3 Fehler! [web:130]
    $robocopyCmd = "/c `"robocopy `"$Source`" `"$DestFolder`" /E /COPY:DAT /R:3 /W:5 /MT:8 /LOG:`"$LogFile`" /TEE`""
    
    Write-Host "`n📤 Robocopy: $Source → $DestFolder" -Foreground Cyan
    Write-Host "CMD Args: $robocopyCmd" -Foreground Gray
    
    $process = Start-Process "cmd.exe" -ArgumentList $robocopyCmd -Wait -PassThru -NoNewWindow
    $exitCode = $process.ExitCode
    
    # Exit-Code Auswertung [web:47]
    if ($exitCode -le 7) {
        Write-Host "✅ Robocopy ERFOLG (Code $exitCode)" -Foreground Green
    } elseif ($exitCode -eq 16) {
        Write-Warning "⚠️  Code 16: Keine Dateien → Fallback Key-Files"
        Invoke-KeyFilesFallback $Source $DestFolder
    } else {
        Write-Error "❌ Robocopy Fehler Code $exitCode"
    }
    
    # LOG ANZEIGEN
    if (Test-Path $LogFile) {
        $logSize = "{0:N1}KB" -f ((Get-Item $LogFile).Length / 1KB)
        Write-Host "`n📋 LOG ($logSize):" -Foreground Cyan
        Get-Content $LogFile -Tail 8
        Write-Host "👆 Vollständiges Log: $LogFile (Notepad öffnet...)" -Foreground Yellow
        Start-Process notepad.exe $LogFile
    }
    
    # Backup-Größe
    $backupSize = (Get-ChildItem $DestFolder -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
    $fileCount = (Get-ChildItem $DestFolder -Recurse -File -ErrorAction SilentlyContinue).Count
    Write-Host "📊 $DestName: $([math]::Round($backupSize,1)) MB / $fileCount Dateien" -Foreground Green
}

# 5. KEY-FILES FALLBACK
function Invoke-KeyFilesFallback {
    param($Source, $Dest)
    
    Write-Host "🔄 Kopiere kritische Dateien..." -Foreground Yellow
    $keyFiles = @(
        "places.sqlite", "Bookmarks", "prefs.js", "key4.db", "logins.json",
        "cookies.sqlite", "formhistory.sqlite", "chrome.json", "Local State",
        "Preferences"
    )
    
    foreach ($file in $keyFiles) {
        $srcFile = Join-Path $Source $file
        if (Test-Path $srcFile) {
            Copy-Item $srcFile $Dest -Force -ErrorAction SilentlyContinue
            Write-Host "  ✓ $file" -Foreground Green
        }
    }
    
    # Erweiterungen/PWAs
    @("Extensions", "Web Applications") | ForEach-Object {
        $srcDir = Join-Path $Source $_
        if (Test-Path $srcDir) {
            Copy-Item $srcDir (Join-Path $Dest $_) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# 6. HAUPT-BACKUP
if ($Action -eq "Backup") {
    Write-Host "`n🚀 BACKUP START..." -Foreground Cyan
    
    if (($Browser -eq "Firefox" -or $Browser -eq "Both") -and $FFProfile) {
        Copy-BrowserData -Source $FFProfile.FullName -DestName "Firefox"
    }
    
    if (($Browser -eq "Edge" -or $Browser -eq "Both")) {
        Copy-BrowserData -Source $EdgeProfilePath -DestName "Edge"
    }
}

# 7. ZUSAMMENFASSUNG
Write-Host "`n" + "="*60 -Foreground Magenta
Write-Host "✅ BACKUP FERTIG: $BackupRoot" -Foreground Green
Write-Host "📁 Ordner: $(Get-ChildItem $BackupRoot -Directory | Measure-Object).Count Profile" -Foreground Cyan
$totalSize = (Get-ChildItem $BackupRoot -Recurse -File -EA SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB
Write-Host "💾 Gesamt: $([math]::Round($totalSize,2)) GB" -Foreground Cyan
Write-Host "="*60 -Foreground Magenta

Read-Host "ENTER zum Beenden (Log bleibt offen)"
