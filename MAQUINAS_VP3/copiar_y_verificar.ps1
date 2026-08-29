# ============================================================
# VP3 - Copia una carpeta y VERIFICA que cada archivo haya
# quedado igual al original (por hash), reintentando los que
# fallen. xcopy puede saltear archivos sueltos en silencio (por
# ejemplo si el antivirus lo tiene bloqueado un instante) sin que
# nadie se entere: un archivo se actualiza y el de al lado no.
# Eso paso de verdad: activar_lectura_en_vivo.ps1 quedo con dos
# dias de atraso en una maquina, con la mesa laggeando de mas,
# mientras el resto de los archivos si se habian actualizado.
# ============================================================
param(
    [Parameter(Mandatory=$true)][string]$Origen,
    [Parameter(Mandatory=$true)][string]$Destino
)

function Hash-De($ruta) {
    if (-not (Test-Path $ruta)) { return $null }
    try { return (Get-FileHash -Path $ruta -Algorithm SHA256 -ErrorAction Stop).Hash }
    catch { return $null }
}

$archivos = Get-ChildItem -Path $Origen -Recurse -File
$total = $archivos.Count
Write-Host ("      Copiando " + $total + " archivos...")

# Copia masiva inicial (rapida)
try { Copy-Item -Path (Join-Path $Origen '*') -Destination $Destino -Recurse -Force -ErrorAction Stop } catch { }

# Verificar archivo por archivo, reintentando los que no coincidan
for ($intento = 1; $intento -le 4; $intento++) {
    $fallados = @()
    foreach ($f in $archivos) {
        $rel = $f.FullName.Substring($Origen.Length).TrimStart('\')
        $destinoArchivo = Join-Path $Destino $rel
        $hOrigen = Hash-De $f.FullName
        $hDestino = Hash-De $destinoArchivo
        if ($hOrigen -ne $hDestino) {
            $fallados += @{ origen = $f.FullName; destino = $destinoArchivo; rel = $rel }
        }
    }
    if ($fallados.Count -eq 0) {
        Write-Host ("      Verificado: los " + $total + " archivos quedaron identicos.")
        exit 0
    }
    if ($intento -lt 4) {
        Write-Host ("      " + $fallados.Count + " archivo(s) no coincidieron todavia, reintentando (" + $intento + "/3)...")
        Start-Sleep -Milliseconds 800
        foreach ($fa in $fallados) {
            $carpetaDestino = Split-Path $fa.destino -Parent
            if (-not (Test-Path $carpetaDestino)) { New-Item -ItemType Directory -Force -Path $carpetaDestino | Out-Null }
            try { Copy-Item -Path $fa.origen -Destination $fa.destino -Force -ErrorAction Stop } catch { }
        }
    }
}

Write-Host ""
Write-Host ("      AVISO: " + $fallados.Count + " archivo(s) NO se pudieron copiar bien:")
foreach ($fa in $fallados) { Write-Host ("        - " + $fa.rel) }
exit 1
