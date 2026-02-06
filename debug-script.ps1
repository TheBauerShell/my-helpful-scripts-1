# DEBUG-Script: Warum leer? Als normaler User ausführen
$BackupPath = "H:\Browserbackup\DEBUG_$(Get-Date -Format 'HHmmss')"
New-Item $BackupPath -ItemType Directory -Force

# 1. Browser stoppen?
Get-Process firefox,msedge -ErrorAction SilentlyContinue | ForEach { 
    Write-Host "LAUFEND: $($_.Id) $($_.ProcessName)" -Foreground Red 
}

# 2. Pfade + Dateigrößen prüfen
Write-Host "`nFIREFOX:"
$ffPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
$profiles = Get-ChildItem $ffPath -Directory -ErrorAction SilentlyContinue
$profiles | ForEach {
    Write-Host "Profil $($_.Name):"
    $places = Join-Path $_.FullName "places.sqlite"
    if (Test-Path $places) { 
        (Get-Item $places).Length /1KB | ForEach { Write-Host "  places.sqlite: $_ KB ✓" -Foreground Green }
    } else { Write-Host "  places.sqlite: FEHLT!" -Foreground Red }
}

Write-Host "`nEDGE:"
$edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
Write-Host "Default: $(Test-Path "$edgePath\Default")"
$bm = "$edgePath\Default\Bookmarks"
if (Test-Path $bm) { 
    (Get-Item $bm).Length /1KB | ForEach { Write-Host "  Bookmarks: $_ KB ✓" -Foreground Green }
} else { Write-Host "  Bookmarks: FEHLT!" -Foreground Red }

# 3. Manueller Test-Kopie
Write-Host "`nTEST-Kopie Firefox places.sqlite:"
$testDest = "$BackupPath\test_places.sqlite"
$srcPlaces = (Get-ChildItem "$ffPath\*\places.sqlite" -ErrorAction SilentlyContinue | Select -First 1).FullName
if ($srcPlaces -and (Copy-Item $srcPlaces $testDest -Force -ErrorAction SilentlyContinue)) {
    Write-Host "✓ Kopiert: $testDest ($(Get-Item $testDest).Length KB)" -Foreground Green
} else {
    Write-Error "✗ Kopierfehler! $($Error[0])"
}

Write-Host "`nBackup-Ordner: $BackupPath" -Foreground Cyan
Get-ChildItem $BackupPath
