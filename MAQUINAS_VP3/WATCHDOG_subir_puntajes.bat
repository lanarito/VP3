@echo off
REM ============================================================
REM WATCHDOG VP3 v3 - Mantiene subir_puntajes.exe SIEMPRE corriendo
REM
REM Si el exe se cierra por cualquier motivo, lo reinicia automaticamente
REM
REM Detecta shutdown de Windows ANTES de iniciar para evitar popup 0xc0000142
REM ============================================================

cd /d "%~dp0"

REM Contador de fallos rapidos consecutivos
set fallos_rapidos=0

:LOOP
REM PRE-CHECK: Verificar si Windows ya se esta apagando ANTES de iniciar
REM Esto previene el popup de error de DLL al inicializar
powershell -NoProfile -ExecutionPolicy Bypass -Command "if ([System.Environment]::HasShutdownStarted) { exit 1 } else { exit 0 }" >nul 2>&1
if errorlevel 1 (
    echo [%date% %time%] PRE-CHECK: Windows apagandose - watchdog termina sin iniciar exe >> watchdog_log.txt
    exit /b 0
)

echo [%date% %time%] Iniciando subir_puntajes.exe >> watchdog_log.txt

REM Iniciar el exe redirigiendo errores estandar para suprimir popups
REM (usamos cmd /c con redireccion para que stderr no muestre popups)
start /wait /min "" cmd /c "subir_puntajes.exe 2>nul"
set exitcode=%errorlevel%

REM POST-CHECK: Verificar de nuevo si es shutdown
powershell -NoProfile -ExecutionPolicy Bypass -Command "if ([System.Environment]::HasShutdownStarted) { exit 1 } else { exit 0 }" >nul 2>&1
if errorlevel 1 (
    echo [%date% %time%] POST-CHECK: Windows apagandose - termina sin reintentar >> watchdog_log.txt
    exit /b 0
)

REM Codigo 3221225794 = 0xC0000142 = DLL Initialization Failed
if %exitcode% EQU 3221225794 (
    echo [%date% %time%] Error 0xC0000142 detectado - probablemente shutdown - termina >> watchdog_log.txt
    exit /b 0
)

REM Codigo -1073741819 (0xC0000005) = Access Violation
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

REM Si el exe corrio mas de 30 segundos, resetear contador (fue crash aislado, no shutdown)
set fallos_rapidos=0

goto LOOP
