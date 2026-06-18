# install.ps1 — create WSL Switch shortcuts on this machine
# Run once after cloning. Works regardless of where the repo lives.

$vbs     = Join-Path $PSScriptRoot 'launch-hidden.vbs'
$startup = [Environment]::GetFolderPath('Startup')
$desktop = [Environment]::GetFolderPath('Desktop')
$wsh     = New-Object -ComObject WScript.Shell

foreach ($dir in @($startup, $desktop)) {
    $lnk = Join-Path $dir 'WSL Switch.lnk'
    $sc  = $wsh.CreateShortcut($lnk)
    $sc.TargetPath       = 'wscript.exe'
    $sc.Arguments        = '"' + $vbs + '"'
    $sc.WorkingDirectory = $PSScriptRoot
    $sc.IconLocation     = "$env:SystemRoot\System32\wsl.exe,0"
    $sc.Description      = 'WSL system tray switch'
    $sc.WindowStyle      = 7
    $sc.Save()
    Write-Host "Created: $lnk"
}

[System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh) | Out-Null
Write-Host ""
Write-Host "Done. WSL Switch will start automatically on next login."
Write-Host "To start it now: double-click 'WSL Switch' on your Desktop."
