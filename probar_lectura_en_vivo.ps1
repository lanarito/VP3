# ============================================================
# PRUEBA VP3 - Se puede leer el puntaje MIENTRAS jugas?
#
# VPinMAME expone la memoria de la mesa por COM (propiedad NVRAM).
# Si podemos engancharnos a la mesa que esta corriendo, se puede subir
# el record apenas grabas las iniciales, sin salir de la mesa.
# Esta prueba NO cambia nada: solo mira.
# ============================================================

$ErrorActionPreference = "Continue"
$log = Join-Path $PSScriptRoot "PROBAR_LECTURA_EN_VIVO_log.txt"

function Anotar($texto, $color = "Gray") {
    Write-Host $texto -ForegroundColor $color
    Add-Content $log "$(Get-Date -Format 'HH:mm:ss')  $texto"
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  PRUEBA: leer el puntaje sin salir de la mesa" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Anotar "=== Prueba iniciada $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

$ok = $false
foreach ($nombre in @("VPinMAME.Controller", "B2S.Server", "VPinMAME.Controller.1")) {
    Write-Host "Probando enganchar con $nombre ..." -ForegroundColor Gray
    try {
        $obj = [System.Runtime.InteropServices.Marshal]::GetActiveObject($nombre)
        Anotar "ENGANCHADO a $nombre" "Green"
        try {
            $rom = $obj.GameName
            Anotar "  ROM en ejecucion: $rom" "Green"
        } catch { Anotar "  (no pude leer GameName: $($_.Exception.Message))" }
        try {
            $nv = $obj.NVRAM
            if ($nv -and $nv.Length -gt 0) {
                Anotar "  NVRAM EN VIVO LEIDA: $($nv.Length) bytes" "Green"
                $destino = Join-Path $PSScriptRoot "nvram_en_vivo.bin"
                [System.IO.File]::WriteAllBytes($destino, [byte[]]$nv)
                Anotar "  Guardada en: $destino" "Green"
                $ok = $true
            } else {
                Anotar "  La propiedad NVRAM vino vacia" "Yellow"
            }
        } catch {
            Anotar "  NO pude leer NVRAM: $($_.Exception.Message)" "Yellow"
        }
        break
    } catch {
        Anotar "  no habia ninguna instancia de $nombre corriendo" "DarkGray"
    }
}

Write-Host ""
Write-Host "------------------------------------------------------------"
if ($ok) {
    Write-Host "  RESULTADO: SE PUEDE." -ForegroundColor Green
    Write-Host "  Se leyo la memoria de la mesa sin cerrarla." -ForegroundColor Green
} else {
    Write-Host "  RESULTADO: no se pudo enganchar esta vez." -ForegroundColor Yellow
    Write-Host "  Ojo: hay que correr esto CON UNA MESA ABIERTA Y JUGANDO." -ForegroundColor Yellow
}
Write-Host "------------------------------------------------------------"
Write-Host ""
Write-Host "Quedo todo anotado en PROBAR_LECTURA_EN_VIVO_log.txt" -ForegroundColor Cyan
Write-Host ""
Read-Host "Enter para cerrar"
