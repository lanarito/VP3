# ============================================================
# VP3 - Cierra TODO lo viejo antes de actualizar (watchdog + subir_puntajes.exe)
# y VERIFICA que de verdad haya quedado limpio, reintentando si hace falta.
#
# Antes esto era un intento unico y silencioso dentro de ACTUALIZAR_VP3.bat.
# Si por lo que sea no alcanzaba a matar el watchdog viejo, ese watchdog
# quedaba corriendo PARA SIEMPRE, y cada actualizacion sumaba una copia mas
# del sistema entero: varias vigilando la NVRAM y mandando Telegram a la vez.
#
# BUG ENCONTRADO 31-ago-2026 (y arreglado dos veces): aun matando TODO,
# quedaba una carrera de verdad. Primero: WATCHDOG_subir_puntajes.bat
# reiniciaba su subir_puntajes.exe solo si lo mataban primero a el sin
# llegar a tiempo a matar el .bat que lo vigila. Se arreglo con el
# _DETENER_VP3_ de aca abajo. Despues aparecio una carrera mas de fondo,
# en la maquina de Her: PinUP Popper tiene SU PROPIO arranque automatico
# (configurado en su base de datos, StartupBatch) que lanza el watchdog
# cada vez que arranca Popper -- un tercer camino ademas de
# ACTUALIZAR_VP3.bat, totalmente fuera de este script. El watchdog ahora
# (v6) usa un MUTEX real de Windows para que sea imposible que dos
# copias corran juntas sin importar quien las dispare (ver
# WATCHDOG_supervisor.ps1), asi que ese problema de fondo ya no depende
# de este script para evitarse. Este script sigue sirviendo para la
# limpieza ANTES de actualizar: mata cualquier watchdog/exe que haya
# quedado de antes para que la copia nueva arranque de cero.
#
# Arreglo del _DETENER_VP3_: se escribe ANTES de matar nada.
# WATCHDOG_subir_puntajes.bat ya sabe mirar ese archivo en cada vuelta
# de su bucle (antes Y despues de lanzar el exe): si lo encuentra, se
# apaga solo en vez de reiniciar. Asi, aunque un watchdog viejo sobreviva
# un instante a la primera tanda de kills, en su proximo chequeo se apaga
# el solo, sin importar el orden en que lo vayamos matando. El archivo se
# borra al final para no bloquear el watchdog NUEVO que arranca despues.
# ============================================================

$sentinel = Join-Path $PSScriptRoot "_DETENER_VP3_"
"DETENER" | Set-Content -Path $sentinel -Encoding ASCII -Force

function Buscar-Viejos {
    Get-CimInstance Win32_Process | Where-Object {
        $_.CommandLine -like '*WATCHDOG_subir_puntajes*' -or
        $_.CommandLine -like '*WATCHDOG_supervisor*' -or
        $_.CommandLine -like '*WATCHDOG_invisible*' -or
        $_.Name -eq 'subir_puntajes.exe' -or
        $_.CommandLine -like '*subir_puntajes.exe*'
    }
}

$intentos = 0
do {
    $vivos = Buscar-Viejos
    if (-not $vivos) { break }
    # Los watchdogs (.bat/cmd.exe/powershell que los lanza) primero: asi se
    # corta el bucle que podria reiniciar el .exe antes de que le toque el
    # turno. El _DETENER_VP3_ ya escrito arriba cubre igual cualquier
    # instante intermedio, pase lo que pase con el orden real de Windows.
    foreach ($p in ($vivos | Where-Object { $_.Name -ne 'subir_puntajes.exe' })) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        & taskkill /F /PID $p.ProcessId /T >$null 2>&1
    }
    foreach ($p in ($vivos | Where-Object { $_.Name -eq 'subir_puntajes.exe' })) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        & taskkill /F /PID $p.ProcessId /T >$null 2>&1
    }
    Start-Sleep -Milliseconds 700
    $intentos++
} while ($intentos -lt 6)

Remove-Item -Path $sentinel -Force -ErrorAction SilentlyContinue

$quedaron = Buscar-Viejos
if ($quedaron) {
    Write-Host ("      AVISO: quedaron " + ($quedaron | Measure-Object).Count + " procesos viejos que no se pudieron cerrar")
    exit 1
} else {
    Write-Host "      OK (nada quedo corriendo de antes)"
    exit 0
}
