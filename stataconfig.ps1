# StataConfig-GUI.ps1 - Mini GUI für Stata Konfiguration
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# XAML für einfache GUI
$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
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
                    <TextBox Name="txtTempPath" Text="{Binding TempPath}" Width="300" Margin="5,0"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="5">
                    <Label Content="Arbeitsverzeichnis:" Width="140"/>
                    <TextBox Name="txtWorkDir" Text="{Binding WorkDir}" Width="300" Margin="5,0"/>
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
                    Margin="10,0" Cursor="Hand"/>
            <Button Name="btnClose" Content="Schließen" Width="100" Height="35" 
                    Margin="10,0" Cursor="Hand"/>
        </StackPanel>
    </Grid>
</Window>
"@

# Fenster laden
$Reader = (New-Object System.Xml.XmlNodeReader ([xml]$XAML))
$Window = [Windows.Markup.XamlReader]::Load($Reader)

# Controls binden
$txtTempPath = $Window.FindName("txtTempPath")
$txtWorkDir = $Window.FindName("txtWorkDir")
$txtStatus = $Window.FindName("txtStatus")
$btnConfig = $Window.FindName("btnConfig")
$btnTest = $Window.FindName("btnTest")
$btnClose = $Window.FindName("btnClose")

# Standardwerte setzen
$txtTempPath.Text = "$env:USERPROFILE\StataTemp"
$txtWorkDir.Text = "$env:USERPROFILE\Documents\Stata"

# Konfigurations-Funktion
$script:ConfigDone = $false
function Configure-Stata {
    $TempPath = $txtTempPath.Text
    $WorkDir = $txtWorkDir.Text
    
    try {
        # Ordner erstellen
        if (!(Test-Path $TempPath)) { New-Item -ItemType Directory -Path $TempPath -Force | Out-Null }
        if (!(Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null }
        
        # STATATMP User-Variable
        [Environment]::SetEnvironmentVariable("STATATMP", $TempPath, "User")
        $env:STATATMP = $TempPath
        
        # profile.do erstellen
        $profileDo = @"
cd "$WorkDir"
display "✓ Working Directory: " c(pwd)
display "✓ STATATMP: `"`$STATATMP`""
"@
        Set-Content -Path "$WorkDir\profile.do" -Value $profileDo -Encoding UTF8
        
        # Test-Datei
        $testDo = @"
sysuse auto, clear
summarize price mpg
save "test.dta", replace
display "✅ Stata voll funktionsfähig!"
"@
        Set-Content -Path "$WorkDir\test.do" -Value $testDo -Encoding UTF8
        
        $txtStatus.Text = "✅ Konfiguration erfolgreich!`nSTATATMP: $TempPath`nWorkingDir: $WorkDir`nDateien: profile.do, test.do erstellt`nStata neustarten!"
        $script:ConfigDone = $true
        $btnTest.IsEnabled = $true
        
    } catch {
        $txtStatus.Text = "❌ Fehler: $($_.Exception.Message)"
    }
}

# Event Handler
$btnConfig.Add_Click({
    $btnConfig.IsEnabled = $false
    Configure-Stata
    $btnConfig.IsEnabled = $true
})

$btnTest.Add_Click({
    if ($script:ConfigDone) {
        Start-Process notepad.exe "$($txtWorkDir.Text)\test.do"
    }
})

$btnClose.Add_Click({ $Window.Close() })

# Fenster anzeigen
$Window.ShowDialog() | Out-Null
