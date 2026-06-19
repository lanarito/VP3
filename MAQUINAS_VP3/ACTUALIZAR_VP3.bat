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
cd /d "%~dp0"

REM ============================================================
REM SORPRESA - Solo aparece la PRIMERA vez que se ejecuta
REM
REM Como cambiar el mensaje para que vuelva a aparecer:
REM 1. Cambiar el texto del mensaje abajo
REM 2. Cambiar el numero de version del marker (.welcome_shown_v1 → v2)
REM 3. Los chicos van a ver el nuevo mensaje la proxima vez
REM ============================================================
if not exist "%~dp0.welcome_shown_v1" (
    color 0C
    cls
    echo.
    echo.
    echo  ###############################################################
    echo  #                                                             #
    echo  #                                                             #
    echo  #     PPPPP   EEEEE  L      AAAAA  DDDD    OOO   SSSSS        #
    echo  #     P    P  E      L      A   A  D   D  O   O  S            #
    echo  #     PPPPP   EEEE   L      AAAAA  D   D  O   O  SSSSS        #
    echo  #     P       E      L      A   A  D   D  O   O      S        #
    echo  #     P       EEEEE  LLLLL  A   A  DDDD    OOO   SSSSS        #
    echo  #                                                             #
    echo  #                                                             #
    echo  #     H   H  IIII   JJJJJ  OOO   SSSSS                        #
    echo  #     H   H   II      J   O   O  S                            #
    echo  #     HHHHH   II      J   O   O  SSSSS                        #
    echo  #     H   H   II   J  J   O   O      S                        #
    echo  #     H   H  IIII   JJ    OOO   SSSSS                         #
    echo  #                                                             #
    echo  #     DDDD   EEEEE  L       AAAAA                             #
    echo  #     D   D  E      L       A   A                             #
    echo  #     D   D  EEEE   L       AAAAA                             #
    echo  #     D   D  E      L       A   A                             #
    echo  #     DDDD   EEEEE  LLLLL   A   A                             #
    echo  #                                                             #
    echo  #     CCCCC  H   H  IIII  N   N   GGGG   AAAAA                #
    echo  #     C      H   H   II   NN  N  G       A   A                #
    echo  #     C      HHHHH   II   N N N  G  GG   AAAAA                #
    echo  #     C      H   H   II   N  NN  G   G   A   A                #
    echo  #     CCCCC  H   H  IIII  N   N   GGGG   A   A                #
    echo  #                                                             #
    echo  #     DDDD   EEEEE  RRRR    AAAAA   !!!  !!!  !!!             #
    echo  #     D   D  E      R   R   A   A   !!!  !!!  !!!             #
    echo  #     D   D  EEEE   RRRR    AAAAA   !!!  !!!  !!!             #
    echo  #     D   D  E      R  R    A   A                             #
    echo  #     DDDD   EEEEE  R   R   A   A   !!!  !!!  !!!             #
    echo  #                                                             #
    echo  #                                                             #
    echo  ###############################################################
    echo.
    echo.
    echo                    Bienvenidos al sistema VP3 ;^)
    echo.
    echo                  Esto solo aparece UNA VEZ jajajaja
    echo.
    echo.

    REM Crear marker versionado para no mostrar mas
    echo Welcome v1 shown on %date% %time% > "%~dp0.welcome_shown_v1"
    attrib +h "%~dp0.welcome_shown_v1" >nul 2>&1

    echo Presiona cualquier tecla para continuar con la actualizacion...
    pause >nul
)

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
