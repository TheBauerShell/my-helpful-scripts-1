# StataConfig-GUI.ps1 - Umlaute-fähig für PowerShell 5.1
# WICHTIG: Als UTF-8 mit BOM speichern!

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# UTF8-Encoding explizit setzen
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# XAML mit UTF8-kompatiblen Umlauten (xml:space="preserve")
$XAML = @"
<Window xml:lang="de-DE" 
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Stata Konfiguration (User)" Height="380" Width="500"
        WindowStartupLocation="CenterScreen" ShowInTaskbar="True"
        ResizeMode="NoResize">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Grid.Row="0" Text="Stata User-Konfiguration" FontSize="18" 
                   FontWeight="Bold" HorizontalAlignment="Center" Margin="0,0,0,20"/>
        
        <GroupBox Grid.Row="1" Header="Pfade konfigurieren" Margin="0,0,0,15">
            <StackPanel>
                <StackPanel Orientation="Horizontal" Margin="5">
                    <Label Content="Temp-Ordner (STATATMP):" Width="140"/>
                    <TextBox Name="txtTempPath" Width="300" Margin="5,0"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="5">
                    <Label Content="Arbeitsverzeichnis:" Width="140"/>
                    <TextBox Name="txtWorkDir" Width="300" Margin="5,0"/>
                </StackPanel>
            </StackPanel>
        </GroupBox>
        
        <TextBlock Grid.Row="2" Name="txtStatus" TextWrapping="Wrap" 
                   Margin="0,0,0,20" Foreground="Blue"/>
        
        <StackPanel Grid.Row="3" Orientation="Horizontal" 
                    HorizontalAlignment="Center" VerticalAlignment="Center">
            <Button Name="btnConfig" Content="Konfigurieren" Width="100" Height="35" 
                    Margin="10,0" Cursor="Hand"/>
            <Button Name="btnTest" Content="Test öffnen" Width="100" Height="35" 
                    Margin="10,0" Cursor="Hand" IsEnabled="False"/>
            <Button Name="btnClose" Content="Schließen" Width="100" Height="35" 
                    Margin="10,0" Cursor="Hand"/>
        </StackPanel>
    </Grid>
</Window>
"@

# Fenster laden mit UTF8
[xml]$XamlReader = $XAML
$Reader = (New-Object System.Xml.XmlNodeReader $XamlReader)
$Reader.XmlResolver = $null  # Keine externen DTDs
$Window = [Windows.Markup.XamlReader]::Load($Reader)

# Controls binden
$txtTempPath = $Window.FindName("txtTempPath")
$txtWorkDir = $Window.FindName("txtWorkDir")
$txtStatus = $Window.FindName("txtStatus")
$btnConfig = $Window.FindName("btnConfig")
$btnTest = $Window.FindName("btnTest")
$btnClose = $Window.FindName("btnClose")

# Standardwerte setzen (UTF8-kompatibel)
$txtTempPath.Text = "$env:USERPROFILE\StataTemp"
$txtWorkDir.Text = "$env:USERPROFILE\Documents\Stata"

# Konfigurations-Funktion
$script:ConfigDone = $false
function Configure-Stata {
    $TempPath = $txtTempPath.Text
    $WorkDir = $txtWorkDir.Text
    
    try {
        # Ordner erstellen
        if (!(Test-Path $TempPath)) { 
            New-Item -ItemType Directory -Path $TempPath -Force | Out-Null 
        }
        if (!(Test-Path $WorkDir)) { 
            New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null 
        }
        
        # STATATMP User-Variable (UTF8)
        [Environment]::SetEnvironmentVariable("STATATMP", $TempPath, "User")
        $env:STATATMP = $TempPath
        
        # profile.do erstellen (UTF8)
        $profileDo = @"
cd "$WorkDir"
display "✓ Working Directory: " c(pwd)
display "✓ STATATMP: `"$STATATMP`"
display "Stata User-Konfiguration geladen!"
"@
        Set-Content -Path "$WorkDir\profile.do" -Value $profileDo -Encoding UTF8
        
        # Test-Datei (UTF8)
        $testDo = @"
sysuse auto, clear
describe
summarize price mpg weight
save "test_auto.dta", replace
tempfile tempcheck
display "✅ Dataset gespeichert: test_auto.dta"
display "✅ Temp-Pfad OK: " r(fn)
display "🎉 Stata voll funktionsfähig!"
"@
        Set-Content -Path "$WorkDir\test.do" -Value $testDo -Encoding UTF8
        
        $txtStatus.Text = "✅ Konfiguration erfolgreich!`nSTATATMP: $TempPath`nWorkingDir: $WorkDir`nDateien: profile.do, test.do erstellt`n💡 Stata neustarten!"
        $script:ConfigDone = $true
        $btnTest.IsEnabled = $true
        
    } catch {
        $txtStatus.Text = "❌ Fehler: $($_.Exception.Message)"
        $btnConfig.IsEnabled = $true
    }
}

# Event Handler
$btnConfig.Add_Click({
    $btnConfig.IsEnabled = $false
    $txtStatus.Text = "🔄 Konfiguriere..."
    Configure-Stata
})

$btnTest.Add_Click({
    if ($script:ConfigDone) {
        Start-Process notepad.exe "$($txtWorkDir.Text)\test.do"
    }
})

$btnClose.Add_Click({ $Window.Close() })

# Fenster anzeigen
$Window.ShowDialog() | Out-Null
