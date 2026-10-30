@echo off
rem Runs the exported build if present, otherwise runs the project with the installed Godot 4.7.
if exist "%~dp0build\Afterbloom.exe" (
  start "" "%~dp0build\Afterbloom.exe"
) else (
  start "" "C:\Users\adili\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" --path "%~dp0."
)
