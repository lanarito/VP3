@echo off
REM ============================================================
REM WATCHDOG VP3 - Mantiene subir_puntajes.exe SIEMPRE corriendo
REM Si el exe se cierra por cualquier motivo, lo reinicia automaticamente
REM ============================================================

cd /d "%~dp0"

:LOOP
echo [%date% %time%] Iniciando subir_puntajes.exe >> watchdog_log.txt
start /wait /min "" subir_puntajes.exe
echo [%date% %time%] subir_puntajes.exe se cerro - reiniciando en 5 segundos >> watchdog_log.txt
timeout /t 5 /nobreak >nul
goto LOOP
