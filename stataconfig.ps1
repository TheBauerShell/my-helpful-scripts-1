# StataConfig-GUI.ps1 - Erweiterte Version mit Ordner-Suche
# WICHTIG: Als UTF-8 mit BOM speichern!

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName Microsoft.VisualBasic  # Für FolderBrowserDialog

# UTF8-Encoding für PowerShell 5.1
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Erweiterte XAML mit Ordner-Such-Buttons
$XAML = @"
<Window xml:lang="de-DE" 
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Stata Konfiguration (User)" Height="420" Width="580"
        WindowStartupLocation="CenterScreen" ShowInTaskbar="True"
        ResizeMode="NoResize">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Grid.Row="0" Text="Stata User-Konfiguration" FontSize="18" 
                   FontWeight="Bold" HorizontalAlignment="Center" Margin="0,0,0,25"/>
        
        <GroupBox Grid.Row="1" Header="Pfade konfigurieren" Margin="0,0,0,20">
            <StackPanel>
                <StackPanel Orientation="Horizontal" Margin="5">
                    <Label Content="Temp-Ordner (STATATMP):" Width="150"/>
                    <TextBox Name="txtTempPath" Width="320" Margin="5,0" VerticalContentAlignment="Center"/>
                    <Button Name="btnBrowseTemp" Content="📁" Width="30" Height="25" Margin="5,0"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="5">
                    <Label Content="Arbeitsverzeichnis:" Width="150"/>
                    <TextBox Name="txtWorkDir" Width="320" Margin="5,0" VerticalContentAlignment="Center"/>
                    <Button Name="btnBrowseWork" Content="📁" Width="30" Height="25" Margin="5,0"/>
                </StackPanel>
            </StackPanel>
        </GroupBox>
        
        <TextBlock Grid.Row="2" Name="txtStatus" TextWrapping="Wrap" 
                   Margin="0,0,0,20" Foreground="Blue" Text="Statusbereich"/>
        
        <StackPanel Grid.Row="3" Orientation="Horizontal" 
                    HorizontalAlignment="Center" VerticalAlignment="Center" Margin="0,0,0,10">
            <Button Name="btnConfig" Content="🔧 Konfigurieren" Width="110" Height="38" 
                    Margin="8,0" Cursor="Hand"/>
            <Button Name="btnTest" Content="📄 Test öffnen" Width="110" Height="38" 
                    Margin="8,0" Cursor="Hand" IsEnabled="False"/>
            <Button Name="btnClose" Content="❌ Schließen" Width="110" Height="38" 
                    Margin="8,0" Cursor="Hand"/>
        </StackPanel>
        
        <TextBlock Grid.Row="4" Text="💡 Hinweis: Nach Konfiguration Stata neustarten" 
                   FontSize="11" HorizontalAlignment="Center" Foreground="Gray" 
                   Margin="0,5,0,0"/>
    </Grid>
</Window>
"@

# Fenster laden
[xml]$XamlReader = $XAML
$Reader = (New-Object System.Xml.XmlNodeReader $XamlReader)
$Reader.XmlResolver = $null
$Wi
