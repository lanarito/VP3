@echo off
REM ============================================================
REM VP3 - DIAGNOSTICO (junta todo lo necesario en un solo archivo)
REM No cambia nada, solo lee y junta informacion.
REM ============================================================
setlocal enabledelayedexpansion
set "SALIDA=%USERPROFILE%\Desktop\diagnostico_vp3.txt"

echo ============================================================ > "%SALIDA%"
echo VP3 - DIAGNOSTICO - %date% %time% >> "%SALIDA%"
echo ============================================================ >> "%SALIDA%"

echo. >> "%SALIDA%"
echo === version del enganche en vivo (Scripts) === >> "%SALIDA%"
findstr /C:"LECTURA EN VIVO v" "C:\vPinball\VisualPinball\Scripts\core.vbs" >> "%SALIDA%" 2>&1

echo. >> "%SALIDA%"
echo === version del enganche en vivo (Tables) === >> "%SALIDA%"
findstr /C:"LECTURA EN VIVO v" "C:\vPinball\VisualPinball\Tables\core.vbs" >> "%SALIDA%" 2>&1

echo. >> "%SALIDA%"
echo === Scripts y Tables core.vbs, son identicos? === >> "%SALIDA%"
fc /B "C:\vPinball\VisualPinball\Scripts\core.vbs" "C:\vPinball\VisualPinball\Tables\core.vbs" >nul 2>&1
if errorlevel 1 (
    echo NO -- SON DISTINTOS >> "%SALIDA%"
) else (
    echo SI, son identicos >> "%SALIDA%"
)

echo. >> "%SALIDA%"
echo === parcheo v10 presente? (si no aparece nada, es v9 vieja) === >> "%SALIDA%"
findstr /C:"Mid(vp3_ult" "C:\vPinball\VisualPinball\Scripts\core.vbs" >> "%SALIDA%" 2>&1

echo. >> "%SALIDA%"
echo === procesos subir_puntajes.exe corriendo ahora === >> "%SALIDA%"
tasklist /FI "IMAGENAME eq subir_puntajes.exe" >> "%SALIDA%" 2>&1

echo. >> "%SALIDA%"
echo === ultimas 25 lineas del log del sistema === >> "%SALIDA%"
powershell -NoProfile -Command "Get-Content 'C:\MAQUINAS_VP3\vp3_script_log.txt' -Tail 25 -Encoding UTF8" >> "%SALIDA%" 2>&1

echo. >> "%SALIDA%"
echo === ultimas 15 lineas del log del watchdog === >> "%SALIDA%"
powershell -NoProfile -Command "Get-Content 'C:\MAQUINAS_VP3\watchdog_log.txt' -Tail 15 -Encoding UTF8" >> "%SALIDA%" 2>&1

echo. >> "%SALIDA%"
echo === heartbeat actual === >> "%SALIDA%"
type "C:\MAQUINAS_VP3\vp3_heartbeat.txt" >> "%SALIDA%" 2>&1

echo. >> "%SALIDA%"
echo === archivos en VP3_LIVE (lectura en vivo), con fecha === >> "%SALIDA%"
dir /O-D "C:\vPinball\VP3_LIVE\*.hex" >> "%SALIDA%" 2>&1

echo. >> "%SALIDA%"
echo === archivos .nv REALES de la NVRAM (se escriben recien al salir de la mesa), con fecha === >> "%SALIDA%"
echo (comparar esta hora contra la de arriba: si el .hex de VP3_LIVE es MAS TEMPRANO, el enganche en vivo llego primero de verdad) >> "%SALIDA%"
dir /O-D "C:\vPinball\VisualPinball\VPinMAME\nvram\*.nv" >> "%SALIDA%" 2>&1

echo. >> "%SALIDA%"
echo === registro de la ultima actualizacion (ACTUALIZAR_VP3.bat) === >> "%SALIDA%"
powershell -NoProfile -Command "Get-Content '%TEMP%\vp3_debug.log' -Tail 15 -Encoding UTF8" >> "%SALIDA%" 2>&1

echo. >> "%SALIDA%"
echo === fecha del subir_puntajes.exe actual === >> "%SALIDA%"
powershell -NoProfile -Command "(Get-Item 'C:\MAQUINAS_VP3\subir_puntajes.exe').LastWriteTime" >> "%SALIDA%" 2>&1

echo. >> "%SALIDA%"
echo === registro de errores que se escaparon (vp3_crash_log.txt) === >> "%SALIDA%"
if exist "C:\MAQUINAS_VP3\vp3_crash_log.txt" (
    powershell -NoProfile -Command "Get-Content 'C:\MAQUINAS_VP3\vp3_crash_log.txt' -Tail 80 -Encoding UTF8" >> "%SALIDA%" 2>&1
) else (
    echo No existe el archivo -- no hubo ningun error de este tipo registrado. >> "%SALIDA%"
)

echo. >> "%SALIDA%"
echo ============================================================ >> "%SALIDA%"
echo LISTO. Se genero el archivo diagnostico_vp3.txt en el Escritorio. >> "%SALIDA%"
echo Mandalo por WhatsApp tal cual (como texto/archivo, no como foto). >> "%SALIDA%"
echo ============================================================ >> "%SALIDA%"

cls
echo.
echo ============================================================
echo    DIAGNOSTICO LISTO
echo ============================================================
echo.
echo Se creo el archivo "diagnostico_vp3.txt" en el Escritorio.
echo Mandaselo a Luis tal cual, como archivo (no como foto).
echo.
pause
