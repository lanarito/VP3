# ============================================================
# Registra SYNC_ANTES_DE_APAGAR.bat como script de APAGADO de
# Windows (Group Policy local de la maquina), sin necesitar
# gpedit.msc (funciona tambien en Windows Home).
#
# Es aditivo e idempotente: nunca borra scripts.ini/gpt.ini si
# ya existen por otro motivo, solo agrega nuestra entrada si
# todavia no esta. Si algo falla, no corta el actualizador.
# ============================================================

$ErrorActionPreference = "Stop"

try {
    $gpRoot         = "$env:WINDIR\System32\GroupPolicy"
    $machineScripts = "$gpRoot\Machine\Scripts"
    $shutdownDir    = "$machineScripts\Shutdown"
    $scriptsIni     = "$machineScripts\scripts.ini"
    $gptIni         = "$gpRoot\gpt.ini"
    $guidPair       = "[{42B5FAAE-6536-11D2-AE5A-0000F87571E3}{40B6664F-4972-11D1-A7CA-0000F87571E3}]"
    $sourceScript   = Join-Path $PSScriptRoot "SYNC_ANTES_DE_APAGAR.bat"

    if (-not (Test-Path $sourceScript)) {
        Write-Host "No se encontro SYNC_ANTES_DE_APAGAR.bat, se omite el registro."
        exit 0
    }

    New-Item -ItemType Directory -Force -Path $shutdownDir | Out-Null
    Copy-Item -Path $sourceScript -Destination (Join-Path $shutdownDir "SYNC_ANTES_DE_APAGAR.bat") -Force

    # --- scripts.ini ---
    $entryLine = "0CmdLine=SYNC_ANTES_DE_APAGAR.bat"
    $yaRegistrado = $false
    if (Test-Path $scriptsIni) {
        $contenido = Get-Content $scriptsIni -Raw -ErrorAction SilentlyContinue
        if ($contenido -and $contenido.Contains($entryLine)) {
            $yaRegistrado = $true
        }
    }
    if (-not $yaRegistrado) {
        $ini = "[Shutdown]`r`n0CmdLine=SYNC_ANTES_DE_APAGAR.bat`r`n0Parameters=`r`n"
        Set-Content -Path $scriptsIni -Value $ini -Encoding ASCII -Force
    }

    # --- gpt.ini (necesario para que Windows sepa que hay scripts que correr) ---
    if (-not (Test-Path $gptIni)) {
        $gpt = "[General]`r`ngPCMachineExtensionNames=$guidPair`r`nVersion=1`r`n"
        Set-Content -Path $gptIni -Value $gpt -Encoding ASCII -Force
    } else {
        $lineas = Get-Content $gptIni
        $nuevasLineas = @()
        $encontroLineaExt = $false
        foreach ($linea in $lineas) {
            if ($linea -match '^gPCMachineExtensionNames=(.*)$') {
                $encontroLineaExt = $true
                $valorActual = $Matches[1]
                if (-not $valorActual.Contains($guidPair)) {
                    $linea = "gPCMachineExtensionNames=$valorActual$guidPair"
                }
            }
            $nuevasLineas += $linea
        }
        if (-not $encontroLineaExt) {
            $nuevasLineas += "gPCMachineExtensionNames=$guidPair"
        }
        Set-Content -Path $gptIni -Value $nuevasLineas -Encoding ASCII -Force
    }

    gpupdate /target:computer /force 2>&1 | Out-Null

    Write-Host "Sincronizacion antes de apagar: registrada correctamente."
    exit 0
} catch {
    Write-Host "No se pudo registrar la sincronizacion antes de apagar: $_"
    exit 0
}
