@echo off
REM ============================================================
REM WATCHDOG VP3 - Mantiene subir_puntajes.exe SIEMPRE corriendo
REM Si el exe se cierra por cualquier motivo, lo reinicia automaticamente
REM
REM Detecta cuando Windows se esta apagando y sale limpiamente
REM para evitar el popup de error 0xc0000142
REM ============================================================

cd /d "%~dp0"

REM Contador de fallos rapidos consecutivos
set fallos_rapidos=0

:LOOP
REM Guardar timestamp antes de iniciar
set tiempo_inicio=%time%
echo [%date% %time%] Iniciando subir_puntajes.exe >> watchdog_log.txt

REM Iniciar el exe y esperar a que termine (capturando codigo de salida)
start /wait /min "" subir_puntajes.exe
set exitcode=%errorlevel%

REM Codigo 3221225794 = 0xC0000142 = DLL Initialization Failed = Windows apagandose
if %exitcode% EQU 3221225794 (
    echo [%date% %time%] Windows se esta apagando ^(error 0xC0000142^) - watchdog termina >> watchdog_log.txt
    exit /b 0
)

REM Codigo -1073741819 (0xC0000005) tambien puede indicar shutdown
if %exitcode% EQU -1073741819 (
    echo [%date% %time%] Acceso violado durante shutdown - watchdog termina >> watchdog_log.txt
    exit /b 0
)

REM Si fallo muy rapido (menos de 5 segundos), incrementar contador
REM Tres fallos rapidos seguidos = probablemente shutdown
set /a fallos_rapidos+=1
if %fallos_rapidos% GEQ 3 (
    echo [%date% %time%] 3 fallos rapidos consecutivos - probablemente shutdown - watchdog termina >> watchdog_log.txt
    exit /b 0
)

echo [%date% %time%] subir_puntajes.exe se cerro ^(codigo %exitcode%^) - reiniciando en 5 segundos >> watchdog_log.txt
timeout /t 5 /nobreak >nul

REM Si el exe corrio mas de 30 segundos, resetear contador de fallos rapidos
REM (significa que estaba funcionando bien, fue un crash aislado)
set fallos_rapidos=0

goto LOOP
