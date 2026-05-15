# ============================================================
# SCRIPT DE COPIA DE SEGURIDAD SEMANAL AUTOMÁTICA - VP3 SYSTEM
# ============================================================

$sourceDir = "C:\Github repos\VP3 COMPLETO"
$backupsDir = "C:\Github repos\BACKUPS_SISTEMA"

# Crear carpeta de backups si no existe
if (!(Test-Path -Path $backupsDir)) {
    New-Item -ItemType Directory -Path $backupsDir -Force | Out-Null
}

# Obtener fecha actual en formato YYYY-MM-DD
$dateStr = Get-Date -Format "yyyy-MM-dd"
$zipFile = Join-Path -Path $backupsDir -ChildPath "BACKUP_VP3_COMPLETO_$dateStr.zip"

try {
    # Comprimir la carpeta del sistema completo (excluyendo archivos ZIP temporales del propio directorio si existiesen)
    Compress-Archive -Path "$sourceDir\*" -DestinationPath $zipFile -Force
    
    # Mantener solo los últimos 4 backups semanales (1 mes de historial) para proteger el almacenamiento del disco duro
    $backupsExistentes = Get-ChildItem -Path $backupsDir -Filter "BACKUP_VP3_COMPLETO_*.zip" | Sort-Object LastWriteTime -Descending
    if ($backupsExistentes.Count -gt 4) {
        $backupsParaEliminar = $backupsExistentes | Select-Object -Skip 4
        foreach ($b in $backupsParaEliminar) {
            Remove-Item -Path $b.FullName -Force
        }
    }
} catch {
    # Registrar error si ocurriese
    $errorLog = Join-Path -Path $backupsDir -ChildPath "backup_error_log.txt"
    $timeStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $errorLog -Value "[$timeStr] Error en backup: $_"
}
