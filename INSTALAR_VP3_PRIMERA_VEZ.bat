@echo off
REM ============================================================
REM INSTALADOR VP3 - PRIMERA VEZ
REM
REM Para maquinas que NO tienen VP3 instalado aun
REM Hace TODO automaticamente:
REM - Pide permisos admin (UAC)
REM - Crea carpeta C:\VP3
REM - Descarga la ultima version
REM - Extrae los archivos
REM - Configura inicio automatico
REM - Aplica fix de error al apagar
REM - Arranca el watchdog
REM
REM Solo doble-click y listo
REM ============================================================

REM Verificar si esta corriendo como admin
net session >nul 2>&1
if errorlevel 1 (
    REM No es admin - relanzarse con permisos elevados
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b 0
)

title VP3 - Instalador Primera Vez
color 0A
cls

echo.
echo ===================================================
echo    INSTALADOR AUTOMATICO VP3 - PRIMERA INSTALACION
echo ===================================================
echo.
echo Este programa instala VP3 desde cero.
echo NO toques nada hasta que diga "LISTO!"
echo.
echo Carpeta de instalacion: C:\VP3\MAQUINAS_VP3\
echo.
echo Empezando en 5 segundos...
echo (Cerra esta ventana ahora si NO queres instalar)
timeout /t 5 /nobreak >nul

set INSTALL_DIR=C:\VP3\MAQUINAS_VP3

echo.
echo [1/7] Creando carpeta de instalacion...
if not exist "C:\VP3" mkdir "C:\VP3"
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
echo       OK
echo.

echo [2/7] Descargando ultima version desde GitHub...
powershell -Command "& {try {Invoke-WebRequest -Uri 'https://lanarito.github.io/VP3/MAQUINAS_VP3.zip' -OutFile '%TEMP%\MAQUINAS_VP3.zip' -UseBasicParsing; exit 0} catch {exit 1}}"
if errorlevel 1 (
    echo       ERROR: No se pudo descargar
    echo Verifica tu conexion a internet
    pause
    exit /b 1
)
echo       OK
echo.

echo [3/7] Extrayendo en %INSTALL_DIR%...
powershell -Command "& {try {Expand-Archive -Path '%TEMP%\MAQUINAS_VP3.zip' -DestinationPath '%INSTALL_DIR%' -Force; exit 0} catch {exit 1}}"
if errorlevel 1 (
    echo       ERROR: No se pudo extraer
    pause
    exit /b 1
)
del "%TEMP%\MAQUINAS_VP3.zip" >nul 2>&1
echo       OK
echo.

echo [4/7] Configurando inicio automatico (shell:startup)...
set STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup

REM Borrar acceso directo viejo si existe
if exist "%STARTUP_FOLDER%\subir_puntajes.exe.lnk" del "%STARTUP_FOLDER%\subir_puntajes.exe.lnk"
if exist "%STARTUP_FOLDER%\subir_puntajes.lnk" del "%STARTUP_FOLDER%\subir_puntajes.lnk"

REM Crear acceso directo a WATCHDOG_invisible.vbs
powershell -Command "& {$ws = New-Object -ComObject WScript.Shell; $sc = $ws.CreateShortcut('%STARTUP_FOLDER%\VP3_Watchdog.lnk'); $sc.TargetPath = '%INSTALL_DIR%\WATCHDOG_invisible.vbs'; $sc.WorkingDirectory = '%INSTALL_DIR%'; $sc.WindowStyle = 7; $sc.Save()}"
echo       OK
echo.

echo [5/7] Aplicando fix de error al apagar (registro Windows)...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Windows" /v "ErrorMode" /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" /v "ErrorMode" /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v "Disabled" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\Windows Error Reporting" /v "DontShowUI" /t REG_DWORD /d 1 /f >nul 2>&1
echo       OK
echo.

echo [6/7] Creando acceso directo en escritorio...
powershell -Command "& {$ws = New-Object -ComObject WScript.Shell; $sc = $ws.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\Actualizar VP3.lnk'); $sc.TargetPath = '%INSTALL_DIR%\ACTUALIZAR_VP3.bat'; $sc.WorkingDirectory = '%INSTALL_DIR%'; $sc.IconLocation = 'C:\Windows\System32\shell32.dll,238'; $sc.Save()}"
echo       OK
echo.

echo [7/7] Iniciando watchdog ahora...
start "" wscript.exe "%INSTALL_DIR%\WATCHDOG_invisible.vbs"
timeout /t 3 /nobreak >nul
echo       OK
echo.

echo ===================================================
echo    LISTO! VP3 INSTALADO Y CORRIENDO
echo ===================================================
echo.
echo Ubicacion: %INSTALL_DIR%
echo Inicio automatico: configurado
echo Watchdog: corriendo
echo Fix de error al apagar: aplicado
echo Acceso directo en escritorio: "Actualizar VP3"
echo.
echo Cosas que tenes que hacer despues:
echo  1. Editar %INSTALL_DIR%\config.ini
echo  2. Configurar la ruta NVRAM_PATH a tu instalacion VP3
echo  3. Configurar token Telegram si queres notificaciones
echo.
echo Esta ventana se cierra sola en 15 segundos...
timeout /t 15 /nobreak >nul
exit /b 0
