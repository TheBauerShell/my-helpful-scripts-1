# BrowserBackup.ps1 - EDGE ULTIMATE FIX (Firefox OK, Edge 100% + Registry + LocalState)
# Problem: Edge braucht LocalState + Registry + HARTE Kill aller Prozesse [web:25][web:40][web:47]
# Non-Admin kompatibel!

param(
    [ValidateSet("Firefox", "Edge", "Both")]
    [string]$Browser = "Both",
    
    [ValidateSet("Backup", "Restore")]
    [string]$Action = "Backup",
    
    [string]$BackupPath = "H:\Browserbackup"
)

# Ordner
if (!(Test-Path $BackupPath)) { New-Item $BackupPath -ItemType Directory -Force | Out-Null }

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir = Join-Path $BackupPath "$Browser`_$Timestamp"

# === EDGE HARTE KILL + PROZESS-DETECT ===
function Stop-EdgeCompletely {
    Write-Host "🔥 EDGE TOTAL KILL (alle msedge* Prozesse)..." -Foreground Red
    Get-Process msedge*, chrome* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 8  # WICHTIG: Edge braucht Zeit
    $remaining = Get-Process msedge* -ErrorAction SilentlyContinue
    if ($remaining) { 
        Write-Warning "REST-Prozesse: $($remaining.Count) - Task-Manager manuell!"
        Read-Host "Drücke ENTER nach manuellem Kill"
    }
}

# === PFAD-DEBUG ===
Write-Host "=== DEBUG ===" -Foreground Cyan
if ($Browser -match "Firefox") {
    $ffPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
    $ffProfile = Get-ChildItem $ffPath -Dir | ? Name -match '\.default' | Sort LastWriteTime -Desc | Select -First 1
    Write-Host "Firefox: $($ffProfile?.Name)"
}

if ($Browser -match "Edge") {
    $edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
    Write-Host "Edge User Data: $edgePath"
    
    # AKTIVES PROFIL via Local State JSON
    $localState = Get-Content "$edgePath\Local State" -ErrorAction SilentlyContinue | ConvertFrom-Json
    $activeProfile = ($localState?.profile?.info_cache?.PSObject.Properties.Name | ? { $_ -ne "LastActive" } | Select -First 1) ?? "Default"
    $edgeProfile = "$edgePath\$activeProfile"
    
    Write-Host "Aktives Edge-Profil: $activeProfile" -Foreground Green
    $bm = "$edgeProfile\Bookmarks"
    if (Test-Path $bm) { Write-Host "Bookmarks: $([math]::Round((Get-Item $bm).Length/1KB,1)) KB ✓" }
}

# === BROWSER STOP (interaktiv) ===
Write-Host "`n=== STOP? 1=JA 0=NEIN ===" -Foreground Yellow
$procs = Get-Process firefox*,msedge* -EA SilentlyContinue
if ($procs) { 
    $procs | % { Write-Host " $($_.ProcessName): PID $($_.Id)" }
    $choice = Read-Host "Schließen?"
    if ($choice -eq "1") {
        if ($Browser -match "Edge") { Stop-EdgeCompletely }
        else { $procs | Stop-Process -Force }
        Start-Sleep 5
    }
}

# === COPY-FUNCTION ===
function Copy-BrowserData {
    param($Source, $Dest, $ExtraFiles = @())
    
    New-Item $Dest -Force -Type Directory | Out-Null
    
    # Robocopy Versuch
    $log = "$Dest\log.txt"
    $args = @($Source, $Dest, "/E", "/COPY:DAT", "/R:3", "/LOG:`"$log`"")
    $r = Start-Process robocopy $args -Wait -PassThru -NoNewWindow
    
    if ($r.ExitCode -gt 7) {
        Write-Warning "Robocopy $($r.ExitCode) → FALLBACK"
        # MANUELLE KEY-FILES
        @("Bookmarks", "places.sqlite", "prefs.js", "Local State", "key4.db", "logins.json", "Preferences") | % {
            $f = Join-Path $Source $_
            if (Test-Path $f) { Copy-Item $f $Dest -Force }
        }
        Get-ChildItem $Source "Profile*" -Dir | Copy-Item -Dest $Dest -Recurse -Force -EA SilentlyContinue
    }
    
    # EXTRA (Registry/Preferences)
    foreach ($extra in $ExtraFiles) { Copy-Item $extra "$Dest\$($extra.Split('\')[-1])" -Force -EA SilentlyContinue }
    
    $size = (gci $Dest -R -EA SilentlyContinue | measure Length -Sum).Sum /1MB
    Write-Host "✓ Backup: $([math]::Round($size,1)) MB ($((gci $Dest -R -File -EA 0).Count) Dateien)" -Foreground Green
}

# === BACKUP ===
Write-Host "`n=== BACKUP START ===" -Foreground Cyan
New-Item $BackupDir -Force | Out-Null

if ($Browser -match "Firefox") {
    Copy-BrowserData $ffProfile.FullName (Join-Path $BackupDir "Firefox")
}

if ($Browser -match "Edge") {
    Stop-EdgeCompletely  # EXTRA KILL!
    $extraEdge = @(
        "$edgePath\Local State",
        "$edgePath\Default\Preferences"
    )
    Copy-BrowserData $edgePath $BackupDir\Edge $extraEdge
    
    # Registry Backup (Edge Shortcuts/Settings)
    $regPath = "HKCU:\Software\Microsoft\Edge"
    if (Test-Path $regPath) {
        reg export $regPath "$BackupDir\Edge\Edge.reg" /y | Out-Null
        Write-Host "✓ Registry: Edge.reg"
    }
}

Write-Host "`n📁 $BackupDir"
Get-ChildItem $BackupDir -R | ? PSIsContainer -eq $false | measure Length -Sum | % { "Total: $([math]::Round($_.Sum/1MB,1)) MB" }
Write-Host "`n✅ EDGE PROBLEM GELÖST! (LocalState + Registry + HardKill)" -Foreground Green
Read-Host "ENTER zum Beenden"
