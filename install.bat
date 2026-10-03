@echo off
rem Laedt die neueste garfield.exe und startet sie. Wird sowohl zum Erstinstallieren
rem benutzt als auch von ".update" (dann unsichtbar/ohne Konsole gestartet).
rem Stabiler Link: https://raw.githubusercontent.com/hrmtm/garfield-releases/main/install.bat
rem
rem Robust: KEIN pause (wuerde unsichtbar ewig haengen), wartet aufs echte Ende der
rem alten Instanz (Datei-Handle frei), laedt in eine temporaere Datei, prueft die
rem Groesse, tauscht mit Backup und startet bei JEDEM Fehler die alte Version wieder,
rem damit der Bot nie tot zurueckbleibt. Alles wird nach update.log protokolliert.
setlocal
set "DEST=%APPDATA%\garfield"
set "EXE=%DEST%\garfield.exe"
set "NEW=%DEST%\garfield.new.exe"
set "BAK=%DEST%\garfield.bak.exe"
set "LOG=%DEST%\update.log"
set "URL=https://github.com/hrmtm/garfield-releases/releases/latest/download/garfield.exe"

if not exist "%DEST%" mkdir "%DEST%"
echo [%date% %time%] Update/Install gestartet > "%LOG%"

rem Laufende Instanz beenden und warten, bis sie wirklich weg ist (sonst ist die
rem .exe-Datei noch gesperrt und laesst sich nicht ueberschreiben).
taskkill /f /im garfield.exe >nul 2>&1
for /l %%i in (1,1,20) do (
  tasklist /fi "imagename eq garfield.exe" | find /i "garfield.exe" >nul || goto gone
  ping -n 2 127.0.0.1 >nul
)
:gone
echo [%time%] alte Instanz beendet >> "%LOG%"

rem Neue Version in temporaere Datei laden -- die alte bleibt unangetastet, falls
rem der Download scheitert.
echo [%time%] lade %URL% >> "%LOG%"
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%URL%' -OutFile '%NEW%' -UseBasicParsing; exit 0 } catch { exit 1 }" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo [%time%] FEHLER: Download fehlgeschlagen -- behalte alte Version. >> "%LOG%"
  del "%NEW%" >nul 2>&1
  goto restart_old
)

rem Sanity-Check: die .exe ist ~33 MB, alles unter 1 MB ist kaputt (z.B. HTML-Fehlerseite).
for %%f in ("%NEW%") do if %%~zf LSS 1000000 (
  echo [%time%] FEHLER: Download zu klein, nur %%~zf Bytes -- behalte alte Version. >> "%LOG%"
  del "%NEW%" >nul 2>&1
  goto restart_old
)

rem Tauschen: alte als Backup sichern, neue an ihren Platz.
if exist "%BAK%" del "%BAK%" >nul 2>&1
if exist "%EXE%" move /y "%EXE%" "%BAK%" >nul 2>&1
move /y "%NEW%" "%EXE%" >nul 2>&1
if not exist "%EXE%" (
  echo [%time%] FEHLER: Tausch fehlgeschlagen -- stelle Backup wieder her. >> "%LOG%"
  if exist "%BAK%" move /y "%BAK%" "%EXE%" >nul 2>&1
  goto restart_old
)
echo [%time%] neue Version installiert >> "%LOG%"

powershell -NoProfile -Command "Start-Process -FilePath '%EXE%'"
echo [%time%] neue Version gestartet >> "%LOG%"
exit /b 0

:restart_old
rem Nach einem Fehler die vorhandene .exe wieder starten, damit der Bot online kommt.
if exist "%EXE%" (
  powershell -NoProfile -Command "Start-Process -FilePath '%EXE%'"
  echo [%time%] alte Version wieder gestartet >> "%LOG%"
) else (
  echo [%time%] keine .exe zum Starten vorhanden. >> "%LOG%"
)
exit /b 1
