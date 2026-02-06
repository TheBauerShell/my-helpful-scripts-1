param(
    [ValidateSet('Firefox', 'Edge', 'Both')]
    [string]$Browser = 'Both',
    
    [ValidateSet('Backup', 'Restore')]
    [string]$Action = 'Backup',
    
    [string]$BackupPath = 'H:\Browserbackup'
)

Write-Host 'BrowserBackup v2.0 gestartet' -ForegroundColor Cyan

$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupRoot = Join-Path $BackupPath "$Browser`_$Timestamp"
$LogFile = "$BackupRoot\robocopy.log"
New-Item -Path $BackupRoot -ItemType Directory -Force | Out-Null

Write-Host "Backup-Ordner: $BackupRoot"
Write-Host "Log-Datei: $LogFile"

$FFProfilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
$FFProfile = Get-ChildItem -Path $FFProfilesPath -Directory -ErrorAction SilentlyContinue | 
    Where-Object { $_.Name -match '\.(default|default-release)$' } | 
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

Write-Host 'Firefox-Profil: ' -NoNewline
if ($FFProfile) {
    Write-Host $FFProfile.Name -ForegroundColor Green
} else {
    Write-Warning 'Nicht gefunden'
}

$EdgeUserData = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
$EdgeActiveProfile = 'Default'
try {
    $LocalStateJson = Get-Content -Path "$EdgeUserData\Local State" -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
    $ActiveProfiles = $LocalStateJson.profile.info_cache.PSObject.Properties.Name | Where-Object { $_ -ne 'LastActive' }
    $EdgeActiveProfile = $ActiveProfiles | Select-Object -First 1 ?? 'Default'
    $EdgeProfilePath = "$EdgeUserData\$EdgeActiveProfile"
    Write-Host "Edge-Profil: $EdgeActiveProfile" -ForegroundColor Green
} catch {
    Write-Warning "Edge Local State: $($_.Exception.Message)"
    $EdgeProfilePath = "$EdgeUserData\Default"
}

Write-Host "`nBrowser-Prozesse stoppen? (1=Ja)"
$procs = Get-Process firefox*,msedge* -ErrorAction SilentlyContinue
if ($procs) {
    $procs | Group-Object ProcessName | ForEach-Object { Write-Host "  $($_.Name): $($_.Count)" }
    $choice = Read-Host
    if ($choice -eq '1') {
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep 5
    }
}

function Copy-BrowserData {
    param([string]$Source, [string]$DestName)
    
    $DestFolder = Join-Path $BackupRoot $DestName
    New-Item -Path $DestFolder -ItemType Directory -Force | Out-Null
    
    $robocopyCmd = '/c robocopy "' + $Source + '" "' + $DestFolder + '" /E /COPY:DAT /R:3 /W:5 /LOG:"' + $LogFile + '" /TEE'
    
    Write-Host "Robocopy: $Source nach $DestFolder"
    $process = Start-Process -FilePath 'cmd.exe' -ArgumentList $robocopyCmd -Wait -PassThru -NoNewWindow
    $exitCode = $process.ExitCode
    
    Write-Host "Robocopy Exit-Code: $exitCode"
    
    if (Test-Path $LogFile) {
        Write-Host "Log erstellt ($( (Get-Item $LogFile).Length ) Bytes)"
        Get-Content $LogFile -Tail 5
        Start-Process notepad.exe $LogFile
    }
    
    $size = (Get-ChildItem $DestFolder -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
    Write-Host "$DestName Backup: $([math]::Round($size,1)) MB"
}

if ($Action -eq 'Backup') {
    if (($Browser -eq 'Firefox' -or $Browser -eq 'Both') -and $FFProfile) {
        Copy-BrowserData -Source
