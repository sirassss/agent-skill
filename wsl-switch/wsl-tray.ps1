# wsl-tray.ps1 — WSL system tray switch
# Linux icon in tray. Right-click menu shows green/red status dot at the top.
# Start spawns a hidden keepalive (sleep infinity) to hold WSL up until Stop is clicked.

$ErrorActionPreference = 'Stop'

# --- Config ---
$Distro = 'Ubuntu-24.04'
$env:WSL_UTF8 = 1            # force UTF-8 output from WSL (avoids UTF-16/null-byte on PS 5.1)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Linux icon extracted from wsl.exe (available on any machine with WSL) ---
$linuxIcon = [System.Drawing.Icon]::ExtractAssociatedIcon("$env:SystemRoot\System32\wsl.exe")

# --- Coloured dot bitmaps for the menu status item ---
function New-DotBitmap {
    param([System.Drawing.Color]$Color)
    $bmp = New-Object System.Drawing.Bitmap 16, 16
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $brush = New-Object System.Drawing.SolidBrush $Color
    $g.FillEllipse($brush, 2, 2, 12, 12)
    $brush.Dispose()
    $g.Dispose()
    return $bmp
}

$bmpGreen = New-DotBitmap ([System.Drawing.Color]::FromArgb(46, 204, 113))   # green
$bmpRed   = New-DotBitmap ([System.Drawing.Color]::FromArgb(231, 76, 60))    # red

# --- Detect WSL state ---
function Test-WslRunning {
    try {
        $out = & wsl.exe --list --running --quiet 2>$null
    } catch {
        return $false
    }
    if (-not $out) { return $false }
    foreach ($line in $out) {
        if ($line.Trim() -eq $Distro) { return $true }
    }
    return $false
}

# --- Actions ---
function Start-Wsl {
    # Spawn a hidden keepalive that holds the distro alive until terminated.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'wsl.exe'
    $psi.Arguments = "-d $Distro --exec sleep infinity"
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    [System.Diagnostics.Process]::Start($psi) | Out-Null
}

function Stop-Wsl {
    Start-Process -FilePath 'wsl.exe' -ArgumentList "--terminate", $Distro -WindowStyle Hidden -Wait
}

function Restart-Wsl {
    Stop-Wsl
    Start-Sleep -Milliseconds 800
    Start-Wsl
}

function Open-WslTerminal {
    $wt = Get-Command wt.exe -ErrorAction SilentlyContinue
    if ($wt) {
        Start-Process -FilePath 'wt.exe' -ArgumentList "-d", $Distro
    } else {
        Start-Process -FilePath 'wsl.exe' -ArgumentList "-d", $Distro
    }
}

# --- NotifyIcon ---
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon    = $linuxIcon
$notify.Text    = "WSL: checking..."
$notify.Visible = $true

# --- Context menu ---
$menu = New-Object System.Windows.Forms.ContextMenuStrip

# Status item at the top (non-clickable, updated by Update-Status)
$miStatus  = New-Object System.Windows.Forms.ToolStripMenuItem
$miStatus.Enabled = $false
$null = $menu.Items.Add($miStatus)
$null = $menu.Items.Add('-')

$miStart   = $menu.Items.Add("Start WSL")
$miStop    = $menu.Items.Add("Stop WSL")
$null      = $menu.Items.Add('-')
$miTerm    = $menu.Items.Add("Open Terminal")
$miRestart = $menu.Items.Add("Restart WSL")
$null      = $menu.Items.Add('-')
$miExit    = $menu.Items.Add("Exit")

$notify.ContextMenuStrip = $menu

# --- Update icon + tooltip + menu status to reflect current state ---
function Update-Status {
    $running = Test-WslRunning
    if ($running) {
        $notify.Text         = "WSL ($Distro): running"
        $miStatus.Image      = $bmpGreen
        $miStatus.Text       = "  WSL: Running"
        $miStart.Enabled     = $false
        $miStop.Enabled      = $true
        $miRestart.Enabled   = $true
    } else {
        $notify.Text         = "WSL ($Distro): stopped"
        $miStatus.Image      = $bmpRed
        $miStatus.Text       = "  WSL: Stopped"
        $miStart.Enabled     = $true
        $miStop.Enabled      = $false
        $miRestart.Enabled   = $false
    }
}

# --- Wire events ---
$miStart.Add_Click(   { Start-Wsl;   Start-Sleep -Milliseconds 500; Update-Status })
$miStop.Add_Click(    { Stop-Wsl;    Update-Status })
$miTerm.Add_Click(    { Open-WslTerminal })
$miRestart.Add_Click( { Restart-Wsl; Start-Sleep -Milliseconds 500; Update-Status })

# Left double-click = quick open terminal
$notify.Add_MouseDoubleClick({
    param($sender, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Open-WslTerminal }
})

$appContext = New-Object System.Windows.Forms.ApplicationContext

$miExit.Add_Click({
    $timer.Stop()
    $notify.Visible = $false
    $notify.Dispose()
    $appContext.ExitThread()
})

# --- Polling timer ---
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 4000
$timer.Add_Tick({ Update-Status })
$timer.Start()

Update-Status
[System.Windows.Forms.Application]::Run($appContext)
