@echo off
REM ============================================================
REM WATCHDOG VP3 v6 - Mantiene 1 SOLA copia de subir_puntajes.exe
REM
REM Toda la logica real vive en WATCHDOG_supervisor.ps1, que usa un
REM MUTEX de Windows de verdad (no una foto de "quien esta corriendo"),
REM asi que da lo mismo quien dispare este .bat -- PinUP Popper al
REM arrancar (esta configurado en su StartupBatch), ACTUALIZAR_VP3.bat,
REM o un doble click a mano -- nunca pueden quedar dos supervisores
REM corriendo a la vez, sin ventana de carrera posible.
REM ============================================================
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WATCHDOG_supervisor.ps1"
exit /b 0
