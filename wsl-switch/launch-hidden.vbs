' launch-hidden.vbs — run wsl-tray.ps1 fully hidden (no console flash)
' Uses WScript.ScriptFullName so this works from any directory — portable.
Dim scriptDir
scriptDir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
CreateObject("WScript.Shell").Run _
  "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptDir & "wsl-tray.ps1""", 0, False
