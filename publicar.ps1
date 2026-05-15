# ============================================================
# PUBLICADOR AUTOMATICO VP3
# Detecta cambios, compila exe, reconstruye zip y sube a GitHub
# ============================================================

$carpeta = "c:\Github repos\VP3 COMPLETO"
$logFile = "$carpeta\publicar_log.txt"

function Log($msg) {
    $linea = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $msg"
    Add-Content -Path $logFile -Value $linea
    # Mantener solo las ultimas 200 lineas del log
    $contenido = Get-Content $logFile -ErrorAction SilentlyContinue
    if ($contenido.Count -gt 200) {
        $contenido | Select-Object -Last 200 | Set-Content $logFile
    }
}

Set-Location $carpeta

# ---- 1. Ver si hay cambios para publicar ----
$cambios = git status --porcelain 2>&1
if (-not $cambios) {
    exit 0  # Nada nuevo, salir silenciosamente
}

Log "Cambios detectados. Iniciando publicacion..."

# ---- 2. Si cambiaron los .py, compilar exe ----
$pyModificados = git status --porcelain | Where-Object { $_ -match "subir_puntajes\.py|RESET_NUBE\.py" }
if ($pyModificados) {
    Log "Compilando subir_puntajes.exe..."
    pyinstaller --onefile --console --name subir_puntajes subir_puntajes.py --distpath dist_auto 2>&1 | Out-Null
    Log "Compilando RESET_NUBE.exe..."
    pyinstaller --onefile --console --name RESET_NUBE RESET_NUBE.py --distpath dist_auto 2>&1 | Out-Null

    Copy-Item "dist_auto\subir_puntajes.exe" "MAQUINAS_VP3\subir_puntajes.exe" -Force
    Copy-Item "dist_auto\RESET_NUBE.exe"     "MAQUINAS_VP3\RESET_NUBE.exe"     -Force

    Remove-Item "dist_auto" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "build"     -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "*.spec"               -Force -ErrorAction SilentlyContinue
    Log "Exe compilados y copiados a MAQUINAS_VP3."
}

# ---- 3. Reconstruir MAQUINAS_VP3.zip ----
Log "Reconstruyendo MAQUINAS_VP3.zip..."
Remove-Item "$carpeta\MAQUINAS_VP3.zip" -Force -ErrorAction SilentlyContinue
Compress-Archive -Path "$carpeta\MAQUINAS_VP3\*" -DestinationPath "$carpeta\MAQUINAS_VP3.zip" -Force
Log "MAQUINAS_VP3.zip actualizado."

# ---- 4. Subir todo a GitHub ----
Log "Subiendo a GitHub..."
git add -A

$fecha = Get-Date -Format "yyyy-MM-dd HH:mm"
$mensajeCommit = "Actualizacion automatica $fecha"
git commit -m $mensajeCommit 2>&1 | Out-Null

git push origin HEAD:main 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Log "Push a GitHub exitoso."
} else {
    Log "ERROR: Fallo el push a GitHub."
}
