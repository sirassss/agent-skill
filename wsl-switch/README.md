# WSL Switch — system tray toggle for WSL

A small system tray app that shows WSL status at a glance and lets you
Start / Stop without opening a terminal.

- Tray icon: Linux penguin (from `wsl.exe`)
- Hover: tooltip shows `WSL (Ubuntu-24.04): running` or `stopped`
- Right-click → status line at top with 🟢 green (running) or 🔴 red (stopped)

## Install (new machine)

```
git clone <repo-url>
cd wsl-switch
powershell -ExecutionPolicy Bypass -File install.ps1
```

`install.ps1` creates two shortcuts:
- **Startup folder** — tray icon appears automatically on every login
- **Desktop** — launch manually or pin to taskbar

> **Windows 11:** new icons land in the overflow area (click `^` in the tray).
> Drag it out to keep it always visible.

## Usage

| Action | Result |
|--------|--------|
| Right-click → **Start WSL** | Starts distro + spawns a hidden `sleep infinity` keepalive so WSL stays up |
| Right-click → **Stop WSL** | `wsl --terminate Ubuntu-24.04` — stops the distro |
| Right-click → **Open Terminal** | Opens Windows Terminal (or `wsl`) into the distro |
| Right-click → **Restart WSL** | Stop then Start |
| Right-click → **Exit** | Closes the tray app (does NOT stop WSL) |
| Left double-click | Open Terminal shortcut |

## Re-launch (if you closed it)

Double-click **WSL Switch** on the Desktop, or:

```
wscript "C:\path\to\wsl-switch\launch-hidden.vbs"
```

## Customise

| What | Where |
|------|-------|
| Distro name | `$Distro` at the top of `wsl-tray.ps1` |
| Poll interval | `$timer.Interval` in `wsl-tray.ps1` (milliseconds) |
| Full VM shutdown instead of distro-only stop | Change `--terminate $Distro` → `--shutdown` in `Stop-Wsl` |

## Uninstall

1. Right-click tray icon → **Exit**
2. Delete the shortcuts:
   - `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\WSL Switch.lnk`
   - Desktop `WSL Switch.lnk`
3. Delete the repo folder
