@echo off
rem Laedt immer die neueste garfield.exe und startet sie direkt.
rem Stabiler Link fuer dieses Skript: https://raw.githubusercontent.com/hrmtm/garfield-releases/main/install.bat
setlocal
set "DEST=%APPDATA%\garfield"
set "EXE=%DEST%\garfield.exe"
set "URL=https://github.com/hrmtm/garfield-releases/releases/latest/download/garfield.exe"

if not exist "%DEST%" mkdir "%DEST%"

echo Beende laufende Instanz (falls vorhanden)...
taskkill /f /im garfield.exe >nul 2>&1

echo Lade neueste Version...
powershell -NoProfile -Command "Invoke-WebRequest -Uri '%URL%' -OutFile '%EXE%'"
if errorlevel 1 (
    echo Download fehlgeschlagen.
    pause
    exit /b 1
)

echo Starte garfield...
start "" "%EXE%"
