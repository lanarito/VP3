# ============================================================
# DIAGNOSTICO VP3 - Cuando VPinMAME graba el puntaje en el .nv?
# Se lanza con VER_CUANDO_GRABA.bat (no hace falta tocar esto)
# ============================================================
param([string]$Carpeta = "C:\vPinball\VisualPinball\VPinMAME\nvram")

$log = Join-Path $PSScriptRoot "VER_CUANDO_GRABA_log.txt"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  VIGILANDO: $Carpeta" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Carpeta)) {
    Write-Host "ERROR: no existe la carpeta $Carpeta" -ForegroundColor Red
    Write-Host "Fijate que VP3 este instalado en esta maquina."
    Read-Host "Enter para cerrar"
    exit 1
}

$previo = @{}
Get-ChildItem $Carpeta -Filter *.nv | ForEach-Object { $previo[$_.Name] = $_.LastWriteTime }

Write-Host "Vigilando $($previo.Count) archivos .nv." -ForegroundColor Green
Write-Host ""
Write-Host "  1. Jugue una partida y GRABE LAS INICIALES." -ForegroundColor Yellow
Write-Host "  2. MIRE ESTA VENTANA SIN SALIR DE LA MESA." -ForegroundColor Yellow
Write-Host "     Si aparece una linea -> graba al poner las iniciales." -ForegroundColor Yellow
Write-Host "     Si no aparece nada   -> hay que salir de la mesa." -ForegroundColor Yellow
Write-Host "  3. Recien ahi salga de la mesa y mire de nuevo." -ForegroundColor Yellow
Write-Host ""
Write-Host "Para terminar: cerrar esta ventana." -ForegroundColor Gray
Write-Host "------------------------------------------------------------"

Add-Content $log "=== Arranque $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $($previo.Count) archivos vigilados"

while ($true) {
    Start-Sleep -Milliseconds 500
    Get-ChildItem $Carpeta -Filter *.nv | ForEach-Object {
        if (-not $previo.ContainsKey($_.Name) -or $previo[$_.Name] -ne $_.LastWriteTime) {
            $previo[$_.Name] = $_.LastWriteTime
            $linea = "$(Get-Date -Format 'HH:mm:ss')  GRABO -> $($_.Name)"
            Write-Host $linea -ForegroundColor Yellow
            Add-Content $log $linea
        }
    }
}
