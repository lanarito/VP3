# ============================================================
# VP3 - Cierra TODO lo viejo antes de actualizar (watchdog + subir_puntajes.exe)
# y VERIFICA que de verdad haya quedado limpio, reintentando si hace falta.
#
# Antes esto era un intento unico y silencioso dentro de ACTUALIZAR_VP3.bat.
# Si por lo que sea no alcanzaba a matar el watchdog viejo, ese watchdog
# quedaba corriendo PARA SIEMPRE, y cada actualizacion sumaba una copia mas
# del sistema entero: varias vigilando la NVRAM y mandando Telegram a la vez.
# ============================================================

function Buscar-Viejos {
    Get-CimInstance Win32_Process | Where-Object {
        $_.CommandLine -like '*WATCHDOG_subir_puntajes.bat*' -or
        $_.CommandLine -like '*WATCHDOG_invisible.vbs*' -or
        $_.Name -eq 'subir_puntajes.exe'
    }
}

$intentos = 0
do {
    $vivos = Buscar-Viejos
    if (-not $vivos) { break }
    foreach ($p in $vivos) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 700
    $intentos++
} while ($intentos -lt 6)

$quedaron = Buscar-Viejos
if ($quedaron) {
    Write-Host ("      AVISO: quedaron " + ($quedaron | Measure-Object).Count + " procesos viejos que no se pudieron cerrar")
    exit 1
} else {
    Write-Host "      OK (nada quedo corriendo de antes)"
    exit 0
}
