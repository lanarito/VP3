@echo off
REM ============================================================
REM RESTAURAR LAS COPAS DE HERNAN A SUPABASE
REM Script simple - ejecuta desde CMD o PowerShell
REM ============================================================

cls
echo.
echo ════════════════════════════════════════════════════════════
echo   RESTAURANDO COPAS DE HERNAN A SUPABASE
echo ════════════════════════════════════════════════════════════
echo.

REM Verificar que estamos en el directorio correcto
if not exist "historial_nube.json" (
    echo [ERROR] No se encontro historial_nube.json
    echo.
    echo Ejecuta este script desde: c:\Github repos\VP3 COMPLETO
    echo.
    pause
    exit /b 1
)

echo [1/2] Leyendo 82 registros...
echo [OK] historial_nube.json cargado
echo.

echo [2/2] Sincronizando con Supabase...
echo.

REM Usar curl para hacer POST a Supabase
curl -X POST "https://hjcabcqihznzrwqwyjdo.supabase.co/rest/v1/records" ^
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqY2FiY3FpaHpuenJ3cXd5amRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTQ0MzUwMDAsImV4cCI6MTg3MjIwMTQwMH0.w0u2-nNECfKoVJIDCEzM-P39kxj_o7CZcMI3z3LvCFU" ^
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqY2FiY3FpaHpuenJ3cXd5amRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTQ0MzUwMDAsImV4cCI6MTg3MjIwMTQwMH0.w0u2-nNECfKoVJIDCEzM-P39kxj_o7CZcMI3z3LvCFU" ^
  -H "Content-Type: application/json" ^
  -H "Prefer: resolution=merge-duplicates" ^
  -d @historial_nube.json

echo.
echo ════════════════════════════════════════════════════════════
echo [OK] SINCRONIZACION COMPLETADA
echo ════════════════════════════════════════════════════════════
echo.
echo Datos restaurados:
echo   + Attack from Mars: HER 12.994.263.970 pts
echo   + Cactus Canyon: HER 114.597.770 pts
echo   + Todos los 82 registros sincronizados
echo.
echo Abre VP3-Web/index.html para verificar que las copas aparezcan
echo.
pause
