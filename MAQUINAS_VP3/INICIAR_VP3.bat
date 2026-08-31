@echo off
title VP3 - Iniciar Sistema
color 0A
cls
echo ============================================================
echo           INICIAR SISTEMA VP3 (SUBIR PUNTAJES)
echo ============================================================
echo.
echo Iniciando watchdog y servicio de monitoreo en segundo plano...
echo.

if exist "%~dp0_DETENER_VP3_" del "%~dp0_DETENER_VP3_" >nul 2>&1
start "" wscript.exe "%~dp0WATCHDOG_invisible.vbs"
timeout /t 2 /nobreak >nul

echo.
echo ============================================================
echo   El sistema VP3 esta INICIADO y corriendo.
echo ============================================================
echo.
timeout /t 3 /nobreak >nul
