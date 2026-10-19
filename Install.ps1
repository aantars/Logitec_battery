# Instala (o desinstala con -Uninstall) el inicio automatico de LogitechBattery.ps1 al iniciar sesion en Windows.
param([switch]$Uninstall)

$shortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'LogitechBattery.lnk'
$script = Join-Path $PSScriptRoot 'LogitechBattery.ps1'

if ($Uninstall) {
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
        Where-Object { $_.CommandLine -like '*LogitechBattery.ps1*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    Remove-Item $shortcut -ErrorAction SilentlyContinue
    'Desinstalado.'
    return
}

$launchArgs = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
$link = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcut)
$link.TargetPath = 'powershell.exe'
$link.Arguments = $launchArgs
$link.WorkingDirectory = $PSScriptRoot
$link.WindowStyle = 7
$link.Save()

Start-Process powershell.exe -ArgumentList $launchArgs -WindowStyle Hidden
'Instalado. Los iconos aparecen en la bandeja del sistema y se iniciaran con Windows.'
