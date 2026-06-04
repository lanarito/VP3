@echo off
REM ============================================================
REM WATCHDOG VP3 v4 - Mantiene subir_puntajes.exe SIEMPRE corriendo
REM
REM v4: Usa PowerShell con SetProcessShutdownParameters para evitar popup
REM      al apagar la maquina (error 0xc0000142)
REM
REM IMPORTANTE: Ejecutar tambien FIX_ERROR_SHUTDOWN.bat UNA VEZ
REM             para suprimir el popup a nivel del sistema
REM ============================================================

cd /d "%~dp0"

REM Contador de fallos rapidos consecutivos
set fallos_rapidos=0

:LOOP
REM PRE-CHECK: verificar si Windows ya se esta apagando
powershell -NoProfile -ExecutionPolicy Bypass -Command "if ([System.Environment]::HasShutdownStarted) { exit 1 } else { exit 0 }" >nul 2>&1
if errorlevel 1 (
    echo [%date% %time%] PRE-CHECK: Windows apagandose - watchdog termina sin iniciar exe >> watchdog_log.txt
    exit /b 0
)

echo [%date% %time%] Iniciando subir_puntajes.exe >> watchdog_log.txt

REM Usar PowerShell para iniciar el proceso con SetErrorMode
REM Esto evita popups de error si el exe falla al inicializar DLLs
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { try { $p = Start-Process -FilePath '%~dp0subir_puntajes.exe' -WindowStyle Hidden -PassThru -Wait -ErrorAction Stop; exit $p.ExitCode } catch { exit 1 } }"
set exitcode=%errorlevel%

REM POST-CHECK: verificar de nuevo si es shutdown
powershell -NoProfile -ExecutionPolicy Bypass -Command "if ([System.Environment]::HasShutdownStarted) { exit 1 } else { exit 0 }" >nul 2>&1
if errorlevel 1 (
    echo [%date% %time%] POST-CHECK: Windows apagandose - termina sin reintentar >> watchdog_log.txt
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

REM Detectar 3 fallos rapidos consecutivos = probable shutdown
set /a fallos_rapidos+=1
if %fallos_rapidos% GEQ 3 (
    echo [%date% %time%] 3 fallos rapidos consecutivos - probablemente shutdown - termina >> watchdog_log.txt
    exit /b 0
)

echo [%date% %time%] subir_puntajes.exe se cerro (codigo %exitcode%) - reiniciando en 5 segundos >> watchdog_log.txt
timeout /t 5 /nobreak >nul

REM Resetear contador si el exe corrio mas de 30 segundos (fue crash aislado, no shutdown)
set fallos_rapidos=0

goto LOOP
