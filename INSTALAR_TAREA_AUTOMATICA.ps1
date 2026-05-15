# ============================================================
# INSTALADOR DE TAREA AUTOMATICA VP3
# Ejecutar UNA SOLA VEZ con clic derecho -> "Ejecutar como administrador"
# ============================================================

# Guardar log por si la ventana se cierra rapido
$logInstalador = "C:\Github repos\VP3 COMPLETO\instalar_log.txt"
Start-Transcript -Path $logInstalador -Force

Write-Host "============================================"
Write-Host "   VP3 - Instalando publicacion automatica"
Write-Host "============================================"
Write-Host ""

$accion = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument '-ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Github repos\VP3 COMPLETO\publicar.ps1"'

# Ejecutar cada 30 minutos
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 30) -Once -At (Get-Date)

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -RunOnlyIfNetworkAvailable `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName "VP3_Publicar_Automatico" `
    -Description "Detecta cambios en VP3, compila exe, reconstruye zip y sube a GitHub automaticamente" `
    -Action $accion `
    -Trigger $trigger `
    -Settings $settings `
    -RunLevel Highest `
    -Force | Out-Null

$tarea = Get-ScheduledTask -TaskName "VP3_Publicar_Automatico" -ErrorAction SilentlyContinue
if ($tarea) {
    Write-Host "LISTO! La tarea fue instalada correctamente."
    Write-Host ""
    Write-Host "De ahora en adelante, cada 30 minutos el sistema:"
    Write-Host "  - Detecta si hubo cambios"
    Write-Host "  - Compila los .exe si el codigo cambio"
    Write-Host "  - Reconstruye MAQUINAS_VP3.zip"
    Write-Host "  - Sube todo a GitHub automaticamente"
    Write-Host ""
    Write-Host "No tenes que hacer nada mas."
} else {
    Write-Host "ERROR: No se pudo instalar la tarea."
    Write-Host "Asegurate de haber ejecutado este archivo como Administrador."
}

Write-Host ""
Stop-Transcript
Write-Host "Log guardado en: $logInstalador"
Write-Host ""
Read-Host "Presiona Enter para cerrar"
