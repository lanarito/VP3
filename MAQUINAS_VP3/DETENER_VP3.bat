@echo off
title VP3 - Detener Sistema
color 0E
cls
echo ============================================================
echo           DETENER SISTEMA VP3 (SUBIR PUNTAJES)
echo ============================================================
echo.
echo Cerrando watchdog y procesos de monitoreo...
echo.

echo DETENER > "%~dp0_DETENER_VP3_"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cerrar_procesos_viejos.ps1"

echo.
echo ============================================================
echo   El sistema VP3 quedo TOTALMENTE DETENIDO.
echo   (No se volvera a abrir solo hasta que lo inicies)
echo ============================================================
echo.
pause
