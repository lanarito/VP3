@echo off
REM ============================================================
REM ACTUALIZADOR AUTOMATICO VP3
REM
REM UN SOLO doble-click y se actualiza todo:
REM - Cierra procesos viejos
REM - Descarga ultima version
REM - Reemplaza archivos
REM - Reinicia el sistema
REM ============================================================

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
echo [1/6] Cerrando procesos viejos...
taskkill /F /IM subir_puntajes.exe /T >nul 2>&1
taskkill /F /IM cmd.exe /FI "WINDOWTITLE eq VP3*" >nul 2>&1
timeout /t 2 /nobreak >nul
echo       OK
echo.

echo [2/6] Descargando ultima version desde GitHub...
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

echo [3/6] Extrayendo archivos...
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

echo [4/6] Copiando archivos nuevos...
xcopy /Y /E /Q "%TEMP%\VP3_TEMP\*" "%~dp0" >nul 2>&1
echo       OK
echo.

echo [5/6] Limpiando archivos temporales...
del "%TEMP%\MAQUINAS_VP3_NUEVO.zip" >nul 2>&1
rmdir /S /Q "%TEMP%\VP3_TEMP" >nul 2>&1
echo       OK
echo.

echo [6/6] Iniciando watchdog actualizado...
start "" wscript.exe "%~dp0WATCHDOG_invisible.vbs"
timeout /t 3 /nobreak >nul
echo       OK
echo.

echo ===============================================
echo    LISTO! Actualizacion completada
echo ===============================================
echo.
echo El sistema VP3 esta corriendo con la ultima version.
echo Ya podes cerrar esta ventana y seguir jugando.
echo.
echo Esta ventana se cierra sola en 10 segundos...
timeout /t 10 /nobreak >nul
exit /b 0
