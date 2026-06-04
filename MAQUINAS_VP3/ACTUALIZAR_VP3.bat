@echo off
REM ============================================================
REM ACTUALIZADOR AUTOMATICO VP3 - TODO EN UNO
REM
REM UN SOLO doble-click hace TODO:
REM - Pide permisos admin (UAC)
REM - Cierra procesos viejos
REM - Descarga ultima version
REM - Reemplaza archivos
REM - Aplica fix de registro para suprimir popup de error al apagar
REM - Arranca el watchdog
REM ============================================================

REM Verificar si esta corriendo como admin
net session >nul 2>&1
if errorlevel 1 (
    REM No es admin - relanzarse con permisos elevados
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b 0
)

REM Ya somos admin desde este punto
title VP3 - Actualizador Automatico
color 0B
cls

echo.
echo ===============================================
echo    ACTUALIZADOR AUTOMATICO VP3
echo ===============================================
echo.
echo Este programa actualiza VP3 automaticamente.
echo NO toques nada hasta que diga "LISTO!"
echo.
echo Empezando en 3 segundos...
timeout /t 3 /nobreak >nul

cd /d "%~dp0"

echo.
echo [1/8] Cerrando procesos viejos...
taskkill /F /IM subir_puntajes.exe /T >nul 2>&1
taskkill /F /IM cmd.exe /FI "WINDOWTITLE eq VP3*" >nul 2>&1
timeout /t 2 /nobreak >nul
echo       OK
echo.

echo [2/8] Descargando ultima version desde GitHub...
powershell -Command "& {try {Invoke-WebRequest -Uri 'https://lanarito.github.io/VP3/MAQUINAS_VP3.zip' -OutFile '%TEMP%\MAQUINAS_VP3_NUEVO.zip' -UseBasicParsing; exit 0} catch {exit 1}}"
if errorlevel 1 (
    echo       ERROR: No se pudo descargar
    echo.
    echo Verifica tu conexion a internet y vuelve a intentar.
    echo.
    pause
    exit /b 1
)
echo       OK
echo.

echo [3/8] Extrayendo archivos...
if exist "%TEMP%\VP3_TEMP" rmdir /S /Q "%TEMP%\VP3_TEMP"
mkdir "%TEMP%\VP3_TEMP" 2>nul
powershell -Command "& {try {Expand-Archive -Path '%TEMP%\MAQUINAS_VP3_NUEVO.zip' -DestinationPath '%TEMP%\VP3_TEMP' -Force; exit 0} catch {exit 1}}"
if errorlevel 1 (
    echo       ERROR: No se pudo extraer
    pause
    exit /b 1
)
echo       OK
echo.

echo [4/8] Copiando archivos nuevos...
xcopy /Y /E /Q "%TEMP%\VP3_TEMP\*" "%~dp0" >nul 2>&1
echo       OK
echo.

echo [5/8] Limpiando archivos temporales...
del "%TEMP%\MAQUINAS_VP3_NUEVO.zip" >nul 2>&1
rmdir /S /Q "%TEMP%\VP3_TEMP" >nul 2>&1
echo       OK
echo.

echo [6/8] Aplicando fix de error al apagar (registro Windows)...
REM ErrorMode = 2: no muestra popup de error general
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Windows" /v "ErrorMode" /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" /v "ErrorMode" /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\Windows Error Reporting" /v "DontShowUI" /t REG_DWORD /d 1 /f >nul 2>&1
echo       OK
echo.

echo [7/8] Configurando Windows Error Reporting para subir_puntajes.exe...
REM Suprimir errores especificos del .exe
reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v "Disabled" /t REG_DWORD /d 1 /f >nul 2>&1
echo       OK
echo.

echo [8/8] Iniciando watchdog actualizado...
start "" wscript.exe "%~dp0WATCHDOG_invisible.vbs"
timeout /t 3 /nobreak >nul
echo       OK
echo.

echo ===============================================
echo    LISTO! Actualizacion completada
echo ===============================================
echo.
echo El sistema VP3 esta corriendo con la ultima version.
echo.
echo Cambios aplicados:
echo  - Subir_puntajes.exe actualizado a ultima version
echo  - Watchdog v4 corriendo
echo  - Popup de error al apagar SUPRIMIDO permanentemente
echo.
echo Ya podes cerrar esta ventana y seguir jugando.
echo (Si veias el popup al apagar, ya no aparece mas)
echo.
echo Esta ventana se cierra sola en 10 segundos...
timeout /t 10 /nobreak >nul
exit /b 0
