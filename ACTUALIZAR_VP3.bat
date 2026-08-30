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
REM - Registra una sincronizacion final justo antes de apagar la PC
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

REM NOTA: El easter egg fue movido al FINAL del script (despues de LISTO)
REM Asi se garantiza que aparezca sin importar el timing del auto-reemplazo del bat
REM Ver seccion easter egg al final del archivo

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
echo [1/10] Cerrando procesos viejos...
REM Mata TODO lo relacionado (watchdogs + subir_puntajes.exe) y VERIFICA
REM que de verdad quedo limpio. Antes era un intento unico y silencioso: si
REM no llegaba a matar el watchdog viejo, quedaba corriendo PARA SIEMPRE, y
REM cada actualizacion sumaba una copia mas del sistema entero (varias
REM vigilando la NVRAM y mandando Telegram a la vez).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cerrar_procesos_viejos.ps1"
echo.

echo [2/10] Descargando ultima version desde GitHub...
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

echo [3/10] Extrayendo archivos...
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

echo [4/10] Copiando archivos nuevos...
REM Copia y VERIFICA por hash cada archivo, no solo si "algo" existe al
REM final. El xcopy viejo podia saltear un archivo suelto en silencio (un
REM antivirus que lo tiene agarrado un instante, por ejemplo): una maquina
REM quedo con un script de dos dias de atraso mientras el resto SI se
REM actualizaba, y nadie lo noto hasta que empezo a laguear.
REM Se usa el verificador que viene DENTRO del zip recien bajado (no el
REM que ya estaba en esta carpeta), asi funciona tambien la primerisima vez.
REM ACTUALIZAR_VP3.bat NO se copia aca (ver -Excluir mas abajo). Si un .bat
REM se sobrescribe a si mismo mientras cmd.exe lo esta interpretando, el
REM resultado es imprevisible: probado que puede cortar la ejecucion a
REM mitad de camino, o saltar a contenido que no corresponde a esa linea.
REM Eso explicaba los "exito" seguidos de un error sin relacion. Se guarda
REM aparte una copia fresca para reemplazarse recien al final del todo.
del "%TEMP%\VP3_TEMP\_copia_resultado.txt" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\VP3_TEMP\copiar_y_verificar.ps1" -Origen "%TEMP%\VP3_TEMP" -Destino "%~dp0." -Excluir "ACTUALIZAR_VP3.bat"
if exist "%TEMP%\VP3_TEMP\ACTUALIZAR_VP3.bat" copy /Y "%TEMP%\VP3_TEMP\ACTUALIZAR_VP3.bat" "%TEMP%\ACTUALIZAR_VP3_nuevo.bat" >nul 2>&1
REM No confiar solo en el codigo de salida de powershell.exe (puede fallar
REM en formas raras y poco confiables segun el contexto). Se confirma con
REM un archivo que el propio script deja escrito, sin ambiguedad posible.
REM Diagnostico completo a un archivo, para poder revisar despues sin
REM depender de una captura de pantalla recortada.
echo ===== %date% %time% ===== > "%~dp0debug_actualizacion.log"
echo TEMP resuelve a: %TEMP% >> "%~dp0debug_actualizacion.log"
echo dp0 resuelve a: %~dp0 >> "%~dp0debug_actualizacion.log"
if exist "%TEMP%\VP3_TEMP\_copia_resultado.txt" (
    echo El archivo _copia_resultado.txt SI existe >> "%~dp0debug_actualizacion.log"
    powershell -NoProfile -Command "$b = [System.IO.File]::ReadAllBytes('%TEMP%\VP3_TEMP\_copia_resultado.txt'); Write-Output ('bytes (' + $b.Length + '): ' + (($b | ForEach-Object { $_.ToString('X2') }) -join ' '))" >> "%~dp0debug_actualizacion.log"
) else (
    echo El archivo _copia_resultado.txt NO existe >> "%~dp0debug_actualizacion.log"
)
set COPIA_RESULTADO=
if exist "%TEMP%\VP3_TEMP\_copia_resultado.txt" (
    set /p COPIA_RESULTADO=<"%TEMP%\VP3_TEMP\_copia_resultado.txt"
)
echo COPIA_RESULTADO leido como: [%COPIA_RESULTADO%] >> "%~dp0debug_actualizacion.log"
if "%COPIA_RESULTADO%"=="OK" (echo la comparacion "==OK" dio VERDADERO >> "%~dp0debug_actualizacion.log") else (echo la comparacion "==OK" dio FALSO >> "%~dp0debug_actualizacion.log")
echo       (confirmacion: %COPIA_RESULTADO%)
if not "%COPIA_RESULTADO%"=="OK" (
    echo ENTRANDO AL BLOQUE DE ERROR >> "%~dp0debug_actualizacion.log"
    color 0C
    echo.
    echo    ***************************************************
    echo      NO SE PUDO ACTUALIZAR ALGUN ARCHIVO
    echo    ***************************************************
    echo.
    echo    Windows no dejo escribir todos los archivos en:
    echo    %~dp0
    echo    (mira arriba cual archivo fallo)
    echo.
    echo    QUE HACER:
    echo    Cerra todo lo que tengas abierto de VP3 y volve a intentar.
    echo    Si sigue igual: CLICK DERECHO sobre ACTUALIZAR_VP3
    echo    y elegi "Ejecutar como administrador".
    echo.
    pause
    exit /b 1
)
echo [5/10] Limpiando archivos temporales...
del "%TEMP%\MAQUINAS_VP3_NUEVO.zip" >nul 2>&1
rmdir /S /Q "%TEMP%\VP3_TEMP" >nul 2>&1
echo       OK
echo.

echo [6/10] Aplicando fix de error al apagar (registro Windows)...
REM ErrorMode = 2: no muestra popup de error general
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Windows" /v "ErrorMode" /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" /v "ErrorMode" /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\Windows Error Reporting" /v "DontShowUI" /t REG_DWORD /d 1 /f >nul 2>&1
echo       OK
echo.

echo [7/10] Configurando Windows Error Reporting para subir_puntajes.exe...
REM Suprimir errores especificos del .exe
reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v "Disabled" /t REG_DWORD /d 1 /f >nul 2>&1
echo       OK
echo.

echo [8/10] Registrando sincronizacion final antes de apagar...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0registrar_sync_apagado.ps1" >nul 2>&1
echo       OK
echo.

echo [9/10] Activando lectura en vivo (subir sin salir de la mesa)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0activar_lectura_en_vivo.ps1" -Auto
echo.

echo [10/10] Iniciando watchdog actualizado...
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
timeout /t 3 /nobreak >nul

REM ============================================================
REM EASTER EGG - Aparece al final de CADA actualizacion (una vez)
REM Para nuevo mensaje: cambiar .welcome_shown_v3 a v4, etc
REM ============================================================
if not exist "%~dp0.welcome_shown_v3" (
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
    echo             SI SI, USTEDES DOS! Nacho y Ariel!
    echo.
    echo         La actualizacion se hizo bien, tranqui.
    echo.
    echo               Pero antes de irte...
    echo.
    echo         Bienvenidos al sistema VP3 mi amor ;^)
    echo.
    echo               Esto no lo veras otra vez
    echo.
    echo.

    REM Crear marker para no mostrar mas
    echo Welcome v3 shown on %date% %time% > "%~dp0.welcome_shown_v3"
    attrib +h "%~dp0.welcome_shown_v3" >nul 2>&1

    echo Presiona cualquier tecla para cerrar la ventana...
    pause >nul
) else (
    echo Cambios aplicados:
    echo  - Subir_puntajes.exe actualizado a ultima version
    echo  - Watchdog v4 corriendo
    echo  - Popup de error al apagar SUPRIMIDO permanentemente
    echo  - Sincronizacion final antes de apagar ACTIVADA
    echo.
    echo Ya podes cerrar esta ventana y seguir jugando.
    echo.
    echo Esta ventana se cierra sola en 10 segundos...
    timeout /t 10 /nobreak >nul
)

REM Reemplazo del propio .bat, como ULTIMA accion de todas. Nada mas se lee
REM de este archivo despues de esta linea, asi que aunque cmd.exe se
REM confunda con el cambio, ya no importa: no hay nada mas por ejecutar.
if exist "%TEMP%\ACTUALIZAR_VP3_nuevo.bat" (
    copy /Y "%TEMP%\ACTUALIZAR_VP3_nuevo.bat" "%~dp0ACTUALIZAR_VP3.bat" >nul 2>&1
    del "%TEMP%\ACTUALIZAR_VP3_nuevo.bat" >nul 2>&1
)
exit /b 0
