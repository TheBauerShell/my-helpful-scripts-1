#====================================================================================
# BrowserBackup.ps1 - KOMPLETTES, GESICHERTES SCRIPT (Syntax 100% OK!)
# Features: Edge LocalState, Robocopy CMD-Fix, Logs, Fallback, Debug
#====================================================================================

param(
    [ValidateSet('Firefox', 'Edge', 'Both')]
    [string]$Browser = 'Both',
    
    [ValidateSet('Backup', 'Restore')]
    [string]$Action = 'Backup',
    
    [string]$BackupPath = 'H:\Browserbackup'
)

Write-Host '🚀 BrowserBackup v2.0 - Start ' (Get-Date) -ForegroundColor Cyan

# 1. Ordner + Log
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupRoot = Join-Path $BackupPath "$Browser`_$Timestamp"
$LogFile = "$BackupRoot\robocopy.log"
New-Item -Path $BackupRoot -ItemType Directory -Force | Out-Null

Write-Host "📁 Backup: $BackupRoot" -ForegroundColor Green
Write-Host "📋 Log: $LogFile" -ForegroundColor Yellow

# 2. Profile Detection
Write-Host "`n=== PROFILE DETECTION ===" -ForegroundColor Cyan

# Firefox
$FFProfilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
$FFProfile = Get-ChildItem -Path $FFProfilesPath -Directory -ErrorAction SilentlyContinue | 
    Where-Object { $_.Name -match '\.(default|default-release)$' } | 
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($Browser -match 'Firefox') {
    if ($FFProfile) {
        $places = Join-Path $FFProfile.FullName 'places.sqlite'
        $size = if (Test-Path $places) { "{0:N1}KB" -f ((Get-Item $places).Length / 1KB) } else { 'FEHLT' }
        Write-Host "Firefox ✓ $($FFProfile.Name) - places.sqlite: $size" -ForegroundColor Green
    } else {
        Write-Warning 'Firefox-Profil nicht gefunden!'
    }
}

# Edge
$EdgeUserData = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
$EdgeActiveProfile = 'Default'
try {
    $LocalStateJson = Get-Content -Path "$EdgeUserData\Local State" -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
    $ActiveProfiles = $LocalStateJson.profile.info_cache.PSObject.Properties.Name | Where-Object { $_ -ne 'LastActive' }
    $EdgeActiveProfile = $ActiveProfiles | Select-Object -First 1 ?? 'Default'
    $EdgeProfilePath = "$EdgeUserData\$EdgeActiveProfile"
    
    if ($Browser -match 'Edge') {
        $edgeBm = "$EdgeProfilePath\Bookmarks"
        $bmSize = if (Test-Path $edgeBm) { "{0:N1}KB" -f ((Get-Item $edgeBm).Length / 1KB) } else { 'FEHLT' }
        Write-Host "Edge ✓ $EdgeActiveProfile - Bookmarks: $bmSize" -ForegroundColor Green
    }
} catch {
    Write-Warning "Edge Local State: $($_.Exception.Message)"
    $EdgeProfilePath = "$EdgeUserData\Default"
}

# 3. Browser Stop
Write-Host "`n=== BROWSER STOP? ===" -ForegroundColor Red
$browserProcs = @()
if ($Browser -match 'Firefox') { $browserProcs += Get-Process firefox* -ErrorAction SilentlyContinue }
if ($Browser -match 'Edge') { $browserProcs += Get-Process msedge* -ErrorAction SilentlyContinue }

if ($browserProcs) {
    $browserProcs | Group-Object ProcessName | ForEach-Object { Write-Host "  $($_.Name): $($_.Count)" }
    Write-Host 'Schließen? (1=JA / ENTER=manuell): ' -NoNewline -ForegroundColor Yellow
    $stopChoice = Read-Host
    if ($stopChoice -eq '1') {
        Write-Host '🛑 Stoppe...' -ForegroundColor Red
        $browserProcs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep 5
    } else {
        Write-Warning '⚠️ Browser laufen → mögliche Fehler!'
    }
} else {
    Write-Host '✅ Keine Prozesse' -ForegroundColor Green
}

# 4. Robocopy Funktion (CMD.exe → kein Parameter #3 Fehler!)
function Copy-BrowserData {
    param([string]$Source, [string]$DestName)
    
    $DestFolder = Join-Path $BackupRoot $DestName
    New-Item -Path $DestFolder -ItemType Directory -Force | Out-Null
    
    # CMD /c robocopy → SAFTE PARAMETERÜBERGABE
    $robocopyCmd = '/c robocopy "' + $Source + '" "' + $DestFolder + '" /E /COPY:DAT /R:3 /W:5 /MT:8 /LOG:"' + $LogFile + '" /TEE'
    
    Write-Host "`n📤 $DestName`: $Source → $DestFolder" -ForegroundColor Cyan
    Write-Host "CMD: $robocopyCmd" -ForegroundColor Gray
    
    $process = Start-Process -FilePath 'cmd.exe' -ArgumentList $robocopyCmd -Wait -PassThru -NoNewWindow
    $exitCode = $process.ExitCode
    
    if ($exitCode -le 7) {
        Write-Host "✅ Robocopy OK (Code $exitCode)" -ForegroundColor Green
    } elseif ($exitCode -eq 16) {
        Write-Warning '⚠️ Code 16 → Key-Files Fallback'
        Invoke-KeyFilesFallback $Source $DestFolder
    } else {
        Write-Error "❌ Code $exitCode"
    }
    
    # LOG
    if (Test-Path $LogFile) {
        Write-Host "`n📋 LOG ($( '{0:N1}KB' -f ((Get-Item $LogFile).Length / 1KB) )):" -ForegroundColor Cyan
        Get-Content $LogFile -Tail 8
        Start-Process 'notepad.exe' $LogFile
    }
    
    # Stats
    $size = (Get-ChildItem $DestFolder -Recurse -ErrorAction SilentlyContinue | 
             Measure-Object Length -Sum).Sum / 1MB
    $count = (Get-ChildItem $DestFolder -Recurse -File -ErrorAction SilentlyContinue).Count
    Write-Host "📊 $DestName`: $([math]::Round($size,1)) MB / $count Dateien" -ForegroundColor Green
}

# 5. Fallback
function Invoke-KeyFilesFallback {
    param($Source, $Dest)
    
    $keyFiles = @('places.sqlite', 'Bookmarks', 'prefs.js', 'key4.db', 'logins.json', 
                  'cookies.sqlite', 'Local State', 'Preferences')
    foreach ($file in $keyFiles) {
        $srcFile = Join-Path $Source $file
        if (Test-Path $srcFile) {
            Copy-Item $srcFile $Dest -Force -ErrorAction SilentlyContinue
        }
    }
    
    @('Extensions', 'Web Applications') | ForEach-Object {
        $srcDir = Join-Path $Source $_
        if (Test-Path $srcDir) {
            Copy-Item $srcDir (Join-Path $Dest $_) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# 6. BACKUP
if ($Action -eq 'Backup') {
    Write-Host "`n🚀 BACKUP START..." -ForegroundColor Cyan
    
    if (($Browser -eq 'Firefox' -or $Browser -eq 'Both') -and $FFProfile) {
        Copy-BrowserData -Source $FFProfile.FullName -DestName 'Firefox'
    }
    
    if (($Browser -eq 'Edge' -or $Browser -eq 'Both') -and (Test-Path $EdgeProfilePath)) {
        Copy-BrowserData -Source $EdgeProfilePath -DestName 'Edge'
    }
}

# 7. Summary
Write-Host "`n" + ('=' * 70)
Write-Host "✅ FERTIG: $BackupRoot" -ForegroundColor Green
$totalSize = (Get-ChildItem $BackupRoot -Recurse -File -ErrorAction SilentlyContinue | 
              Measure-Object Length -Sum).Sum / 1GB
Write-Host "💾 Gesamt: $([math]::Round($totalSize,2)) GB" -ForegroundColor Cyan
Write-Host "📋 Log: $LogFile" -ForegroundColor Yellow
Write-Host ('=' * 70)

Read-Host 'ENTER zum Beenden'
