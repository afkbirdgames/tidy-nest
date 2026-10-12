@echo off
rem Double-click to install or update Tidy Nest. Close Minecraft first.
rem For a server: put this file and update-tidynest.ps1 in the server folder (next to "mods").
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-tidynest.ps1" %*
