@echo off
REM ============================================================
REM WATCHDOG VP3 v5 - Mantiene 1 SOLA copia de subir_puntajes.exe
REM ============================================================
cd /d "%~dp0"

REM Prevenir multiples watchdogs corriendo a la vez
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { `$otros = (Get-CimInstance Win32_Process | Where-Object { `$_.CommandLine -like '*WATCHDOG_subir_puntajes.bat*' -and `$_.ProcessId -ne `$PID }); if (`$otros) { exit 1 } else { exit 0 } }" >nul 2>&1
if errorlevel 1 (
    echo [%date% %time%] Ya hay otro watchdog corriendo. Saliendo de esta copia duplicada. >> watchdog_log.txt
    exit /b 0
)

set fallos_rapidos=0

:LOOP
REM PRE-CHECK: verificar si Windows ya se esta apagando
powershell -NoProfile -ExecutionPolicy Bypass -Command "if ([System.Environment]::HasShutdownStarted) { exit 1 } else { exit 0 }" >nul 2>&1
if errorlevel 1 (
    echo [%date% %time%] PRE-CHECK: Windows apagandose - watchdog termina sin iniciar exe >> watchdog_log.txt
    exit /b 0
)

REM Detencion manual solicitada
if exist "%~dp0_DETENER_VP3_" (
    echo [%date% %time%] Detencion manual solicitada - watchdog termina >> watchdog_log.txt
    del "%~dp0_DETENER_VP3_" >nul 2>&1
    exit /b 0
)

echo [%date% %time%] Iniciando subir_puntajes.exe >> watchdog_log.txt

powershell -NoProfile -ExecutionPolicy Bypass -Command "& { try { $p = Start-Process -FilePath '%~dp0subir_puntajes.exe' -WindowStyle Hidden -PassThru -Wait -ErrorAction Stop; exit $p.ExitCode } catch { exit 1 } }"
set exitcode=%errorlevel%

REM POST-CHECK: verificar de nuevo si es shutdown
powershell -NoProfile -ExecutionPolicy Bypass -Command "if ([System.Environment]::HasShutdownStarted) { exit 1 } else { exit 0 }" >nul 2>&1
if errorlevel 1 (
    echo [%date% %time%] POST-CHECK: Windows apagandose - termina sin reintentar >> watchdog_log.txt
    exit /b 0
)

REM Si se pidio detener
if exist "%~dp0_DETENER_VP3_" (
    echo [%date% %time%] Detencion manual confirmada >> watchdog_log.txt
    del "%~dp0_DETENER_VP3_" >nul 2>&1
    exit /b 0
)

REM Codigos de error de shutdown
if %exitcode% EQU 3221225794 (
    echo [%date% %time%] Error 0xC0000142 detectado - probablemente shutdown - termina >> watchdog_log.txt
    exit /b 0
)
if %exitcode% EQU -1073741819 (
    echo [%date% %time%] Acceso violado durante shutdown - termina >> watchdog_log.txt
    exit /b 0
)

REM Si salio limpio (codigo 0, ej por duplicado de mutex), esperar 10 segundos antes de reintentar
if %exitcode% EQU 0 (
    echo [%date% %time%] subir_puntajes.exe cerro con codigo 0 - esperando 10 segundos >> watchdog_log.txt
    timeout /t 10 /nobreak >nul
    goto LOOP
)

set /a fallos_rapidos+=1
if %fallos_rapidos% GEQ 3 (
    echo [%date% %time%] 3 fallos rapidos consecutivos - probablemente shutdown o error fatal - termina >> watchdog_log.txt
    exit /b 0
)

echo [%date% %time%] subir_puntajes.exe se cerro (codigo %exitcode%) - reiniciando en 5 segundos >> watchdog_log.txt
timeout /t 5 /nobreak >nul
set fallos_rapidos=0
goto LOOP
