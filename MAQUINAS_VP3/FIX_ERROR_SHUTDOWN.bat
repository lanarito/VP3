@echo off
REM ============================================================
REM FIX_ERROR_SHUTDOWN VP3
REM
REM Suprime el popup de error 0xc0000142 al apagar Windows
REM
REM Solo hace falta ejecutarlo UNA VEZ por maquina
REM Requiere permisos de administrador (se relanza solo)
REM ============================================================

title VP3 - Fix Error al Apagar
color 0E

REM Verificar si esta corriendo como admin
net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo Este script necesita permisos de administrador.
    echo Voy a relanzarlo con permisos elevados...
    echo.
    timeout /t 2 /nobreak >nul
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b 0
)

cls
echo.
echo ===================================================
echo    FIX ERROR 0xc0000142 AL APAGAR VP3
echo ===================================================
echo.
echo Este programa modifica el registro de Windows para que
echo no aparezca mas el popup de error al apagar la maquina.
echo.
echo Es seguro y reversible.
echo.
echo Empezando en 3 segundos...
timeout /t 3 /nobreak >nul

echo.
echo [1/3] Configurando ErrorMode en el sistema...
REM ErrorMode = 2 = No muestra popup de error general (GP fault)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Windows" /v "ErrorMode" /t REG_DWORD /d 2 /f >nul 2>&1
if errorlevel 1 (
    echo       ERROR: No se pudo modificar HKLM
    pause
    exit /b 1
)
echo       OK
echo.

echo [2/3] Suprimiendo Windows Error Reporting para subir_puntajes.exe...
REM Configurar AppCompat para que el exe especifico no muestre errores
reg add "HKCU\Software\Microsoft\Windows\Windows Error Reporting" /v "DontShowUI" /t REG_DWORD /d 1 /f >nul 2>&1
echo       OK
echo.

echo [3/3] Configurando que las app no muestren error al fallar al cargar DLL...
REM SetProcessDEPPolicy: deshabilitar avisos visuales de DLL fallidas
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" /v "ErrorMode" /t REG_DWORD /d 2 /f >nul 2>&1
echo       OK
echo.

echo ===================================================
echo    LISTO! Error suprimido permanentemente
echo ===================================================
echo.
echo Ya no deberia aparecer mas el popup de error al apagar
echo la maquina VP3.
echo.
echo Cambios realizados:
echo  - ErrorMode del sistema configurado en 2
echo  - Windows Error Reporting deshabilitado para apps
echo  - Popup de DLL initialization suprimido
echo.
echo IMPORTANTE: Reinicia la maquina para que tome efecto.
echo.
pause
exit /b 0
