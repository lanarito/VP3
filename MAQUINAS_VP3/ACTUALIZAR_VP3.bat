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

REM Verificar si esta corriendo como admin.
REM Sin parentesis: un bloque if (...) largo con pause adentro ya se probo
REM que cuelga cmd.exe de forma imprevisible (ver el chequeo de copia mas
REM abajo). goto con comparacion simple es el patron confiable en todo
REM este archivo.
net session >nul 2>&1
if not errorlevel 1 goto ya_es_admin

REM No es admin - relanzarse con permisos elevados.
REM OJO: si el que hace doble click le dice que NO al cartel de Windows
REM (o lo cierra sin contestar), antes esta ventana se cerraba sola y SIN
REM AVISAR NADA: parecia que habia actualizado, pero no se toco ni un
REM archivo. Eso paso de verdad (HER y ARI creian que actualizaban y
REM quedaban atrasados hasta que alguien lo forzaba con click derecho >
REM Ejecutar como administrador). Ahora, si cancelan el permiso, se avisa
REM clarito y la ventana se queda quieta hasta que la cierren.
powershell -Command "try { Start-Process '%~f0' -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
if errorlevel 1 goto elevacion_cancelada
exit /b 0

:elevacion_cancelada
color 0C
cls
echo.
echo    ===============================================
echo       NO SE ACTUALIZO NADA
echo    ===============================================
echo.
echo    Windows te pidio permiso para actualizar y no
echo    se acepto ^(le dijiste que NO, o se cerro el
echo    cartel sin contestar^).
echo.
echo    Sin ese permiso, VP3 NO SE ACTUALIZA. Ningun
echo    archivo se toco todavia.
echo.
echo    QUE HACER: volve a hacer doble click en
echo    "Actualizar VP3", y cuando aparezca el cartel
echo    azul o gris de Windows preguntando permiso,
echo    apreta "SI".
echo.
pause
exit /b 1

:ya_es_admin

REM ============================================================
REM Relanzarse desde una carpeta TEMPORAL, fuera de la carpeta que se va
REM a actualizar. Windows Defender (proteccion en tiempo real, confirmada
REM activa) escanea los archivos que van cambiando durante el paso de
REM copia; aun sin tocar ESTE archivo directamente, ese escaneo de la
REM carpeta entera alcanzaba a interferir con la lectura que cmd.exe
REM hace de si mismo mientras sigue corriendo desde ahi adentro (probado:
REM mensajes de exito seguidos de un bloque de error sin relacion, pese
REM a que el archivo de confirmacion decia OK). Corriendo desde TEMP,
REM la carpeta real (MAQUINAS_VP3) puede escanearse, bloquearse o lo que
REM sea sin que le importe a la copia que sigue ejecutandose.
REM
REM setlocal enabledelayedexpansion: sin esto, un SET adentro de este
REM mismo bloque (...) no se ve con %VAR% hasta DESPUES de que el bloque
REM termina (se expande todo el bloque una sola vez, al leerlo). Con
REM !VAR! se lee el valor de verdad, en el momento. Probado que sin esto
REM VP3_DESTINO quedaba vacio y el relanzado fallaba en silencio.
REM ============================================================
setlocal enabledelayedexpansion
if not "%~1"=="_VP3ACTUALIZANDO" (
    set "VP3_DESTINO=%~dp0"
    copy /Y "%~f0" "%TEMP%\ACTUALIZAR_VP3_running.bat" >nul 2>&1
    REM "cmd /C" explicito: start, al lanzar un .bat directamente, abre la
    REM ventana con /K (la deja abierta esperando despues de terminar) en
    REM vez de cerrarla sola. /C fuerza que se cierre al terminar.
    start "VP3 - Actualizador Automatico" cmd /C ""%TEMP%\ACTUALIZAR_VP3_running.bat" _VP3ACTUALIZANDO "!VP3_DESTINO!""
    exit /b 0
)
set "VP3_DESTINO=%~2"
echo [%date% %time%] RELANZADO OK, VP3_DESTINO=!VP3_DESTINO! >> "%TEMP%\vp3_debug.log"

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

echo.
echo [1/10] Cerrando procesos viejos...
echo [%date% %time%] llegue a 1/10 >> "%TEMP%\vp3_debug.log"
REM Mata TODO lo relacionado (watchdogs + subir_puntajes.exe) y VERIFICA
REM que de verdad quedo limpio. Antes era un intento unico y silencioso: si
REM no llegaba a matar el watchdog viejo, quedaba corriendo PARA SIEMPRE, y
REM cada actualizacion sumaba una copia mas del sistema entero (varias
REM vigilando la NVRAM y mandando Telegram a la vez).
powershell -NoProfile -ExecutionPolicy Bypass -File "%VP3_DESTINO%cerrar_procesos_viejos.ps1"
echo.

echo [2/10] Descargando ultima version desde GitHub...
echo [%date% %time%] llegue a 2/10 >> "%TEMP%\vp3_debug.log"
powershell -Command "& {try {Invoke-WebRequest -Uri 'https://lanarito.github.io/VP3/MAQUINAS_VP3.zip' -OutFile '%TEMP%\MAQUINAS_VP3_NUEVO.zip' -UseBasicParsing; exit 0} catch {exit 1}}"
if not errorlevel 1 goto descarga_ok
echo       ERROR: No se pudo descargar
echo.
echo Verifica tu conexion a internet y vuelve a intentar.
echo.
pause
exit /b 1
:descarga_ok
echo       OK
echo.

echo [3/10] Extrayendo archivos...
echo [%date% %time%] llegue a 3/10 >> "%TEMP%\vp3_debug.log"
if exist "%TEMP%\VP3_TEMP" rmdir /S /Q "%TEMP%\VP3_TEMP"
mkdir "%TEMP%\VP3_TEMP" 2>nul
powershell -Command "& {try {Expand-Archive -Path '%TEMP%\MAQUINAS_VP3_NUEVO.zip' -DestinationPath '%TEMP%\VP3_TEMP' -Force; exit 0} catch {exit 1}}"
if not errorlevel 1 goto extraccion_ok
echo       ERROR: No se pudo extraer
pause
exit /b 1
:extraccion_ok
echo       OK
echo.

echo [4/10] Copiando archivos nuevos...
echo [%date% %time%] llegue a 4/10 >> "%TEMP%\vp3_debug.log"
REM Copia y VERIFICA por hash cada archivo, no solo si "algo" existe al
REM final. El xcopy viejo podia saltear un archivo suelto en silencio (un
REM antivirus que lo tiene agarrado un instante, por ejemplo): una maquina
REM quedo con un script de dos dias de atraso mientras el resto SI se
REM actualizaba, y nadie lo noto hasta que empezo a laguear.
REM Se usa el verificador que viene DENTRO del zip recien bajado (no el
REM que ya estaba en esta carpeta), asi funciona tambien la primerisima vez.
REM Esta corriendo desde TEMP (ver arriba), asi que ahora SI se puede
REM copiar ACTUALIZAR_VP3.bat con todo lo demas, sin peligro de auto-
REM sobrescribirse: el archivo que cmd.exe esta leyendo en este momento
REM es el de TEMP, no el de VP3_DESTINO.
del "%TEMP%\VP3_TEMP\_copia_resultado.txt" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\VP3_TEMP\copiar_y_verificar.ps1" -Origen "%TEMP%\VP3_TEMP" -Destino "%VP3_DESTINO%."
set "COPIA_RESULTADO="
if exist "%TEMP%\VP3_TEMP\_copia_resultado.txt" set /p COPIA_RESULTADO=<"%TEMP%\VP3_TEMP\_copia_resultado.txt"
echo       (confirmacion: %COPIA_RESULTADO%)
REM Sin parentesis multilinea para esta comparacion critica: un bloque
REM (...) largo con "if not X==Y (" se trabo en la practica de forma
REM imprevisible (confirmado con logs: el archivo decia OK, pero igual
REM se metia ahi). "goto" con comparacion simple es un patron mas viejo
REM y mas confiable en cmd.exe, sin esa fragilidad.
if "%COPIA_RESULTADO%"=="OK" goto copia_ok
color 0C
echo.
echo    ***************************************************
echo      NO SE PUDO ACTUALIZAR ALGUN ARCHIVO
echo    ***************************************************
echo.
echo    Windows no dejo escribir todos los archivos en:
echo    %VP3_DESTINO%
echo    (mira arriba cual archivo fallo)
echo.
echo    QUE HACER:
echo    Cerra todo lo que tengas abierto de VP3 y volve a intentar.
echo    Si sigue igual: CLICK DERECHO sobre ACTUALIZAR_VP3
echo    y elegi "Ejecutar como administrador".
echo.
pause
exit /b 1
:copia_ok
echo [%date% %time%] copia OK, llegue a copia_ok >> "%TEMP%\vp3_debug.log"
echo [5/10] Limpiando archivos temporales...
del "%TEMP%\MAQUINAS_VP3_NUEVO.zip" >nul 2>&1
rmdir /S /Q "%TEMP%\VP3_TEMP" >nul 2>&1
echo       OK
echo.

echo [%date% %time%] llegue a 5/10 >> "%TEMP%\vp3_debug.log"
echo [6/10] Aplicando fix de error al apagar (registro Windows)...
REM ErrorMode = 2: no muestra popup de error general
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Windows" /v "ErrorMode" /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" /v "ErrorMode" /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\Windows Error Reporting" /v "DontShowUI" /t REG_DWORD /d 1 /f >nul 2>&1
echo       OK
echo.

echo [%date% %time%] llegue a 6/10 >> "%TEMP%\vp3_debug.log"
echo [7/10] Configurando Windows Error Reporting y exclusiones del antivirus...
REM Suprimir errores especificos del .exe
reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v "Disabled" /t REG_DWORD /d 1 /f >nul 2>&1
REM Exclusion de Windows Defender para subir_puntajes.exe. Encontrado
REM 1-sep-2026: el .exe se cerraba solo (codigo 1) sin dejar NINGUN
REM rastro en el registro de errores nuevo (asi que no era una excepcion
REM de Python) -- y quedaban decenas de carpetas _MEI sin limpiar en
REM Temp (asi termina un PyInstaller onefile cuando lo matan de golpe en
REM vez de cerrarse solo). Es un problema conocido de los .exe hechos
REM con PyInstaller onefile: el antivirus escanea la carpeta temporal
REM que se auto-extrae en CADA arranque y puede interferir. Se excluye
REM tanto la carpeta real como el proceso, para cubrir los dos casos.
powershell -NoProfile -Command "try { Add-MpPreference -ExclusionPath '%VP3_DESTINO%' -ErrorAction Stop } catch {}" >nul 2>&1
powershell -NoProfile -Command "try { Add-MpPreference -ExclusionProcess 'subir_puntajes.exe' -ErrorAction Stop } catch {}" >nul 2>&1
REM Encontrado 2-sep-2026: la lectura en vivo (core.vbs) escribe un
REM archivo .hex de hasta 262KB en C:\vPinball\VP3_LIVE cada pocos
REM segundos mientras se juega una mesa grande. Confirmado con Her
REM desactivando la lectura en vivo por completo: la tildada
REM desaparecio del todo. Si el antivirus escanea cada escritura ahi
REM (carpeta nunca excluida hasta ahora), eso explicaria el costo real
REM que no aparecia en las mediciones de solo lectura+comparacion.
powershell -NoProfile -Command "try { Add-MpPreference -ExclusionPath 'C:\vPinball\VP3_LIVE' -ErrorAction Stop } catch {}" >nul 2>&1
echo       OK
echo.

echo [%date% %time%] llegue a 7/10 >> "%TEMP%\vp3_debug.log"
echo [8/10] Registrando sincronizacion final antes de apagar...
powershell -NoProfile -ExecutionPolicy Bypass -File "%VP3_DESTINO%registrar_sync_apagado.ps1" >nul 2>&1
echo       OK
echo.

echo [%date% %time%] llegue a 8/10 >> "%TEMP%\vp3_debug.log"
echo [9/10] Activando lectura en vivo (subir sin salir de la mesa)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%VP3_DESTINO%activar_lectura_en_vivo.ps1" -Auto
echo.

echo [%date% %time%] llegue a 9/10 >> "%TEMP%\vp3_debug.log"
echo [10/10] Iniciando watchdog actualizado...
start "" wscript.exe "%VP3_DESTINO%WATCHDOG_invisible.vbs"
timeout /t 3 /nobreak >nul
echo       OK
echo.

echo ===============================================
echo [%date% %time%] llegue a 10/10, LISTO >> "%TEMP%\vp3_debug.log"
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
if exist "%VP3_DESTINO%.welcome_shown_v3" goto ya_visto
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
echo Welcome v3 shown on %date% %time% > "%VP3_DESTINO%.welcome_shown_v3"
attrib +h "%VP3_DESTINO%.welcome_shown_v3" >nul 2>&1

echo Presiona cualquier tecla para cerrar la ventana...
pause >nul
goto fin

:ya_visto
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

:fin
exit /b 0
