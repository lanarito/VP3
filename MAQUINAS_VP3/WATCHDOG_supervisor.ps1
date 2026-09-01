# ============================================================
# VP3 - SUPERVISOR DEL WATCHDOG (v6, mutex real)
#
# BUG ENCONTRADO 31-ago-2026 en la maquina de Her: el chequeo anterior
# (verificar_unico_watchdog.ps1) es una FOTO de un instante -- mira que
# procesos hay corriendo AHORA y decide. Eso tiene una carrera real: si
# dos watchdogs arrancan casi al mismo tiempo, los dos pueden sacar la
# foto ANTES de que el otro se haya registrado, y los dos pasan el
# chequeo. Esto pasa de verdad: ademas de ACTUALIZAR_VP3.bat (paso 10),
# se encontro que PinUP Popper tiene su PROPIO arranque automatico
# (GlobalSettings.StartupBatch en su base de datos) que lanza
# WATCHDOG_invisible.vbs cada vez que arranca Popper -- un tercer camino
# totalmente independiente del actualizador. Con eso, "reiniciar la PC y
# actualizar" puede terminar dos veces casi juntas sin que ninguna se
# entere de la otra a tiempo.
#
# Arreglo: un MUTEX de Windows de verdad (el mismo mecanismo que ya
# protege a subir_puntajes.exe), sostenido durante TODA la vida del
# supervisor -- no una foto, un candado real. Solo UN proceso en toda
# la maquina puede tenerlo tomado a la vez; el segundo que lo intenta se
# entera al instante (WaitOne con timeout 0) y se cierra solo, sin
# ventana de carrera posible, sin importar quien lo haya disparado.
#
# Ademas arregla un bug chico que traia el v5: el contador de "fallos
# rapidos consecutivos" se reseteaba a 0 en CADA vuelta del bucle, asi
# que en la practica nunca llegaba a 3 y el watchdog podia reintentar
# para siempre ante un crash-loop real. Ahora el contador solo se
# resetea si el programa estuvo corriendo un rato largo (30s o mas)
# antes de cerrarse -- si se cierra rapido tres veces seguidas, se
# frena de verdad (protege de un bucle de reinicios sin fin).
#
# BUG ENCONTRADO 1-sep-2026: el mutex de arriba, aunque real, se creaba
# con seguridad "por defecto" (New-Object System.Threading.Mutex sin mas
# parametros). Confirmado en la maquina real: cuando la PRIMERA copia
# corre elevada (ACTUALIZAR_VP3.bat con permisos de administrador) y
# despues arranca una SEGUNDA sin elevar (ej. PinUP Popper al iniciar,
# normalmente sin admin), esa segunda ni siquiera puede ABRIR el mutex
# de la primera -- exactamente el mismo problema que se encontro y
# arreglo en subir_puntajes.py el mismo dia. Arreglado creando el mutex
# con un MutexSecurity que da control total a "Everyone" (SID
# WorldSid), asi da igual el nivel de privilegios de quien lo cree o lo
# busque despues.
# ============================================================

$carpeta = $PSScriptRoot
Set-Location $carpeta
$logFile = Join-Path $carpeta "watchdog_log.txt"
$sentinel = Join-Path $carpeta "_DETENER_VP3_"
$exeSubir = Join-Path $carpeta "subir_puntajes.exe"

function Log($msg) {
    $linea = "[$(Get-Date -Format 'ddd. dd/MM/yyyy HH:mm:ss,ff')] $msg"
    Add-Content -Path $logFile -Value $linea -Encoding UTF8 -ErrorAction SilentlyContinue
}

$mutexName = "Global\VP3_Watchdog_SingleInstance_Mutex"
$mutex = $null
try {
    $seguridad = New-Object System.Security.AccessControl.MutexSecurity
    $sidTodos = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::WorldSid, $null)
    $regla = New-Object System.Security.AccessControl.MutexAccessRule($sidTodos, [System.Security.AccessControl.MutexRights]::FullControl, [System.Security.AccessControl.AccessControlType]::Allow)
    $seguridad.AddAccessRule($regla)
    $creadoNuevo = $false
    $mutex = New-Object System.Threading.Mutex($false, $mutexName, [ref]$creadoNuevo, $seguridad)
} catch {
    # Si por lo que sea la version con seguridad abierta falla, caer al
    # modo simple de antes (mejor eso que no arrancar nada).
    $mutex = New-Object System.Threading.Mutex($false, $mutexName)
}
$adquirido = $false
try {
    $adquirido = $mutex.WaitOne(0)
} catch [System.Threading.AbandonedMutexException] {
    # El watchdog anterior murio sin soltar el mutex prolijo (ej. lo mataron
    # a la fuerza). .NET igual nos lo entrega a nosotros en ese caso.
    $adquirido = $true
}

if (-not $adquirido) {
    Log "Ya hay otro watchdog corriendo (mutex ocupado). Saliendo de esta copia duplicada."
    exit 0
}

try {
    $fallosRapidos = 0
    while ($true) {
        if ([System.Environment]::HasShutdownStarted) {
            Log "PRE-CHECK: Windows apagandose - watchdog termina sin iniciar exe"
            break
        }
        if (Test-Path $sentinel) {
            Log "Detencion manual solicitada - watchdog termina"
            Remove-Item $sentinel -Force -ErrorAction SilentlyContinue
            break
        }

        Log "Iniciando subir_puntajes.exe"
        $inicio = Get-Date
        $exitcode = 1
        try {
            $p = Start-Process -FilePath $exeSubir -WindowStyle Hidden -PassThru -Wait -ErrorAction Stop
            $exitcode = $p.ExitCode
        } catch {
            $exitcode = 1
        }
        $duracionSeg = ((Get-Date) - $inicio).TotalSeconds

        if ([System.Environment]::HasShutdownStarted) {
            Log "POST-CHECK: Windows apagandose - termina sin reintentar"
            break
        }
        if (Test-Path $sentinel) {
            Log "Detencion manual confirmada"
            Remove-Item $sentinel -Force -ErrorAction SilentlyContinue
            break
        }

        if ($exitcode -eq 3221225794 -or $exitcode -eq -1073741819) {
            Log "Error de shutdown detectado (codigo $exitcode) - termina"
            break
        }

        if ($exitcode -eq 0) {
            Log "subir_puntajes.exe cerro con codigo 0 (ej. duplicado de mutex) - esperando 10 segundos"
            Start-Sleep -Seconds 10
            continue
        }

        if ($duracionSeg -ge 30) {
            # Corrio un buen rato antes de morir: no cuenta como "fallo rapido"
            $fallosRapidos = 0
        } else {
            $fallosRapidos++
        }

        if ($fallosRapidos -ge 3) {
            Log "3 fallos rapidos consecutivos (menos de 30s cada uno) - probablemente shutdown o error fatal - termina"
            break
        }

        Log "subir_puntajes.exe se cerro (codigo $exitcode, corrio $([int]$duracionSeg)s) - reiniciando en 5 segundos"
        Start-Sleep -Seconds 5
    }
} finally {
    $mutex.ReleaseMutex() | Out-Null
    $mutex.Dispose()
}
