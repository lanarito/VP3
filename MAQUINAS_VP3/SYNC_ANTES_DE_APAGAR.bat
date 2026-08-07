@echo off
REM ============================================================
REM Corre como script de APAGADO de Windows (Group Policy local).
REM Fuerza una ultima sincronizacion antes de que la maquina se
REM apague de verdad, para no perder el puntaje de la ultima partida.
REM
REM Tope duro de 25 segundos: si algo se cuelga (sin internet, etc.)
REM se corta solo y deja que Windows siga apagando normalmente.
REM ============================================================

cd /d "%~dp0"

echo [%date% %time%] Sync antes de apagar: iniciando >> watchdog_log.txt

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { $p = Start-Process -FilePath '%~dp0subir_puntajes.exe' -ArgumentList '--sync-once' -WindowStyle Hidden -PassThru; if (-not $p.WaitForExit(25000)) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; 'timeout (25s) - se corto' } else { 'completado' } } catch { \"error: $_\" }" >> watchdog_log.txt 2>&1

echo [%date% %time%] Sync antes de apagar: terminado >> watchdog_log.txt

exit /b 0
