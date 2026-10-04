@echo off
rem Schnelle Variante von install.bat: identische robuste Logik, aber der ~33-MB-Download
rem laeuft ueber curl.exe statt Invoke-WebRequest. IWR rendert in Windows PowerShell 5.1
rem einen Fortschrittsbalken, der grosse Downloads massiv ausbremst (auch mit
rem -UseBasicParsing) -- curl ist da 10-50x schneller. curl ist in Win10 1803+/Win11
rem enthalten (die Einzeiler nutzen es ohnehin); faellt zur Sicherheit auf IWR zurueck.
rem Die alte install.bat bleibt unveraendert; dies ist der zusaetzliche "fast"-Weg.
rem Stabiler Link: https://raw.githubusercontent.com/hrmtm/garfield-releases/main/fast.bat
setlocal
set "DEST=%APPDATA%\garfield"
set "EXE=%DEST%\garfield.exe"
set "NEW=%DEST%\garfield.new.exe"
set "BAK=%DEST%\garfield.bak.exe"
set "LOG=%DEST%\update.log"
set "URL=https://github.com/hrmtm/garfield-releases/releases/latest/download/garfield.exe"

if not exist "%DEST%" mkdir "%DEST%"
echo [%date% %time%] Update/Install (fast) gestartet > "%LOG%"

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
rem der Download scheitert. Erst curl (schnell), nur bei Fehler PowerShell-Fallback.
echo [%time%] lade %URL% (curl) >> "%LOG%"
curl -sSL --fail -o "%NEW%" "%URL%" 2>> "%LOG%"
if errorlevel 1 (
  echo [%time%] curl fehlgeschlagen -- Fallback Invoke-WebRequest. >> "%LOG%"
  powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -Uri '%URL%' -OutFile '%NEW%' -UseBasicParsing; exit 0 } catch { exit 1 }" >> "%LOG%" 2>&1
)
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
