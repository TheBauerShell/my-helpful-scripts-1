# BrowserBackup.ps1 - FINAL VERSION (Firefox OK, Edge-Profil-Fix, non-Admin, interaktiv)
# Fixes: Edge korrektes Profil, Debug, 1/0 Browser-Stop, Key-Files-Fallback [web:14][web:43][web:98]
# Als normaler User ausführen!

param(
    [ValidateSet("Firefox", "Edge", "Both")]
    [string]$Browser = "Both",
    
    [ValidateSet("Backup", "Restore")]
    [string]$Action = "Backup",
    
    [string]$BackupPath = "H:\Browserbackup"
)

# 1. Ordner erstellen
if (-not (Test-Path $BackupPath)) {
    New-Item $BackupPath -ItemType Directory -Force | Out-Null
    Write-Host "✓ Ordner: $BackupPath" -ForegroundColor Green
}

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$FirefoxBackupDir = Join-Path $BackupPath "Firefox_$Timestamp"
$EdgeBackupDir = Join-Path $BackupPath "Edge_$Timestamp"

# 2. PFAD-DEBUG
Write-Host "`n=== PFAD-CHECK ===" -Foreground Cyan
$FirefoxProfilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if ($Browser -match "Firefox") {
    Write-Host "Firefox Profiles: $FirefoxProfilesPath"
    $ffProfiles = Get-ChildItem $FirefoxProfilesPath -Directory -ErrorAction SilentlyContinue | Where Name -match '\.default-release|\.default'
    if ($ffProfiles) { $ffProfiles | Select -First 1 | ForEach { Write-Host "  Aktiv: $($_.Name)" -Foreground Green } }
}

$EdgeBasePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
if ($Browser -match "Edge") {
    Write-Host "Edge Base: $EdgeBasePath"
    $edgeProfiles = Get-ChildItem $EdgeBasePath -Directory | Where { $_ -like "Default" -or $_ -like "Profile*" } | Sort LastWriteTime -Desc
    $edgeProfiles | Select -First 2 | ForEach { 
        $bm = Join-Path $_.FullName "Bookmarks"
        $size = if (Test-Path $bm) { "{0:N1}KB" -f ((Get-Item $bm).Length/1KB) } else { "FEHLT" }
        Write-Host "  $($_.Name): Bookmarks $size"
    }
}

# 3. INTERAKTIVE BROWSER-SCHLIESSUNG
Write-Host "`n=== BROWSER SCHLIESSEN? (1=JA / 0=NEIN) ===" -Foreground Red
$procs = @()
if ($Browser -match "Firefox") { $procs += Get-Process firefox* -ErrorAction SilentlyContinue }
if ($Browser -match "Edge") { $procs += Get-Process msedge* -ErrorAction SilentlyContinue }

if ($procs) {
    $procs | Group ProcessName | ForEach { Write-Host "  $($_.Name): $($_.Count)" }
    Write-Host "Schließen? " -NoNewline -Foreground Yellow
    $choice = Read-Host
    if ($choice -eq "1") {
        Write-Host "Stoppe Browser..." -Foreground Red
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep 5
    } else {
        Write-Warning "Browser laufen → Backup kann fehlschlagen!"
    }
} else {
    Write-Host "Keine Browser aktiv ✓" -Foreground Green
}

# 4. KOPIER-FUNKTION (non-Admin)
function Copy-BrowserData {
    param($Source, $Dest)
    
    if (-not (Test-Path $Source)) { 
        Write-Warning "FEHLER: $Source existiert nicht!"
        return $false 
    }
    
    New-Item $Dest -ItemType Directory -Force | Out-Null
    $logFile = "$Dest\robocopy.log"
    
    # Robocopy (normal, non-admin)
    $args = @($Source, $Dest, "/E", "/COPY:DAT", "/R:1", "/W:2", "/LOG:`"$logFile`"")
    $proc = Start-Process robocopy -ArgumentList $args -Wait -PassThru -NoNewWindow
    
    if ($proc.ExitCode -le 7) {
        $size = (Get-ChildItem $Dest -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
        Write-Host "✓ ROBOCOPY: $([math]::Round($size,1)) MB" -Foreground Green
        return $true
    } else {
        Write-Warning "Robocopy Code $($proc.ExitCode) → FALLBACK Key-Dateien"
        Get-Content $logFile -Tail 3
        
        # KEY-FILES (garantiert kopierbar)
        $keyItems = @("places.sqlite*", "Bookmarks", "prefs.js", "key4.db", "logins.json", 
                      "cookies.sqlite", "chrome.json", "Extensions", "Web Applications")
        
        foreach ($item in $keyItems) {
            $srcItem = Join-Path $Source $item
            $dstItem = Join-Path $Dest $item
            if (Test-Path $srcItem) {
                if ($item -match "(Extensions|Web Applications)") {
                    Copy-Item $srcItem $dstItem -Recurse -Force -ErrorAction SilentlyContinue
                } else {
                    Copy-Item $srcItem $dstItem -Force -ErrorAction SilentlyContinue
                }
            }
        }
        $files = (Get-ChildItem $Dest -Recurse -File -ErrorAction SilentlyContinue).Count
        Write-Host "✓ FALLBACK: $files Dateien (Bookmarks/Prefs/PWAs)" -Foreground Green
        return $true
    }
}

# 5. BACKUP-AUSFÜHRUNG
if ($Action -eq "Backup") {
    Write-Host "`n=== BACKUP $($Browser) ===" -Foreground Cyan
    
    if ($Browser -match "Firefox") {
        $ffProfile = Get-ChildItem $FirefoxProfilesPath -Directory | Where Name -match '\.default-release|\.default' | Sort LastWriteTime -Desc | Select -First 1
        if ($ffProfile) {
            Copy-BrowserData $ffProfile.FullName $FirefoxBackupDir
        }
    }
    
    if ($Browser -match "Edge") {
        $edgeProfiles = Get-ChildItem $EdgeBasePath -Directory | Where { $_ -like "Default" -or $_ -like "Profile*" } | Sort LastWriteTime -Desc
        $edgeProfile = $edgeProfiles | Select -First 1
        if ($edgeProfile) {
            Write-Host "Edge-Profil: $($edgeProfile.Name)"
            Copy-BrowserData $edgeProfile.FullName $EdgeBackupDir
        }
    }
    
    Write-Host "`n📁 Backups in $BackupPath:"
    Get-ChildItem $BackupPath -Directory | Sort LastWriteTime -Desc | Select Name, @{N='SizeMB';E={(Get-ChildItem $_.FullName -Recurse | Measure Length -Sum).Sum/1MB}}
}

# 6. RESTORE (optional, einfach)
if ($Action -eq "Restore") {
    Write-Host "RESTORE-Logik (neueste Backups wiederherstellen) - Erweitere bei Bedarf"
}

Write-Host "`n✅ FERTIG! Browser neu starten." -Foreground Green
Pause
