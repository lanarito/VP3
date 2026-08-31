# ============================================================
# VP3 - Cierra TODO lo viejo antes de actualizar (watchdog + subir_puntajes.exe)
# y VERIFICA que de verdad haya quedado limpio, reintentando si hace falta.
#
# Antes esto era un intento unico y silencioso dentro de ACTUALIZAR_VP3.bat.
# Si por lo que sea no alcanzaba a matar el watchdog viejo, ese watchdog
# quedaba corriendo PARA SIEMPRE, y cada actualizacion sumaba una copia mas
# del sistema entero: varias vigilando la NVRAM y mandando Telegram a la vez.
#
# BUG ENCONTRADO 31-ago-2026: aun matando TODO, quedaba una carrera de
# verdad. WATCHDOG_subir_puntajes.bat tiene su propio bucle: si nota que
# su subir_puntajes.exe murio, lo reinicia solo a los 5-10 segundos. Si
# esta rutina mata primero el .exe y todavia no llega a matar el .bat que
# lo vigila, ese .bat alcanza a levantar un subir_puntajes.exe NUEVO antes
# de que le toque el turno -- y justo en ese hueco arranca tambien el
# watchdog NUEVO (paso 10 del actualizador). Resultado: dos copias enteras
# del sistema corriendo a la vez. Confirmado en la maquina real: dos pares
# de subir_puntajes.exe, "Cambio detectado" repetido en el mismo segundo,
# Telegram duplicado, y el enganche en vivo compitiendo consigo mismo.
#
# Arreglo: escribir el archivo _DETENER_VP3_ ANTES de matar nada.
# WATCHDOG_subir_puntajes.bat v5 YA sabe mirar ese archivo en cada vuelta
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
