@echo off
rem Double-click to open the mctl launcher (no console window, no execution-policy change needed).
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0mctl-launcher.ps1"
