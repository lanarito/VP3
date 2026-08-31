# ============================================================
# VP3 - LECTURA EN VIVO (v9 - motor nativo, un solo enganche)
#
# El propio core.vbs de VPinMAME YA trae un punto de extension pensado
# para exactamente esto: la variable UseNVRAM y el objeto NVRAMCallback
# (declarados en la linea ~37-38 del core.vbs original). Si UseNVRAM es
# True, en CADA vuelta del timer principal VPinMAME llama solo a
# Controller.ChangedNVRAM (los bytes que cambiaron, no la memoria
# entera) y nos lo pasa. Es nativo, event-driven de verdad: cuando no
# hay cambios, el costo es el de comprobar una condicion, nada mas.
#
# Version anterior (v8) tenia dos problemas:
#   1. El patron de -replace para "respaldar" el enganche en otras subs
#      (Update, PinMAMETimer_Timer) usaba -replace sin anclar bien el
#      texto, y esos nombres se repiten varias veces en las ~2500
#      lineas de core.vbs: termino inyectando la llamada en 9 lugares
#      distintos del archivo compartido por las 37 mesas.
#   2. La funcion igual hacia Controller.NVRAM (la memoria ENTERA) en
#      cada llamada, en vez de usar el delta (aChg) que ya le llega
#      como parametro. Es el mismo error de la v3 vieja: recorrer y
#      convertir ~12000 bytes en cada disparo en vez de solo los pocos
#      que cambiaron.
#
# v9: UN SOLO punto de enganche (el nativo, ya presente en el archivo
# original), y la funcion usa el delta real para actualizar un buffer
# propio (una sola lectura completa la primera vez, nada mas).
#
#   -Auto    : activa sin preguntar nada (lo usa ACTUALIZAR_VP3.bat)
#   -Quitar  : saca el enganche y deja core.vbs como estaba
#   sin nada : muestra un menu
#
# Es idempotente: si ya esta puesto y es la misma version, no hace nada.
# Si hay una version vieja (de cualquier version anterior), la reemplaza
# por completo antes de poner la nueva.
# ============================================================
param([switch]$Auto, [switch]$Quitar)

$VERSION = "v9"
$ini = "' ===== VP3 LECTURA EN VIVO $VERSION INICIO ====="
$fin = "' ===== VP3 LECTURA EN VIVO $VERSION FIN ====="
$carpetaLive = "C:\vPinball\VP3_LIVE"

function Buscar-Core {
    $cand = @(
        "C:\vPinball\VisualPinball\Scripts\core.vbs",
        "C:\vPinball\VisualPinball\Tables\core.vbs",
        "C:\Visual Pinball\Scripts\core.vbs",
        "C:\Visual Pinball\Tables\core.vbs"
    )
    if ($env:VP3_TEST_CORE -and (Test-Path $env:VP3_TEST_CORE)) { return $env:VP3_TEST_CORE }
    foreach ($c in $cand) { if (Test-Path $c) { return $c } }
    $b = Get-ChildItem "C:\vPinball" -Filter "core.vbs" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($b) { return $b.FullName }
    return $null
}

# BUG ENCONTRADO 31-ago-2026: GetTextFile("core.vbs") -- la funcion nativa
# de VPX que carga el script -- busca primero en la carpeta de la mesa
# (Tables\core.vbs) y SOLO si no esta ahi cae a la carpeta compartida
# (Scripts\core.vbs). En esta maquina hay una copia vieja de core.vbs dentro
# de Tables\, y CADA mesa cargaba ESA (con el enganche viejo o directamente
# sin enganche), sin importar lo que se cambiara en Scripts\core.vbs.
# Confirmado con un diagnostico puesto adentro del propio core.vbs mientras
# se jugaba de verdad: cero enganche disparaba hasta sincronizar las dos
# copias. Por eso esta funcion, ademas de tocar $archivo (el que encuentre
# primero Buscar-Core), replica el resultado final a CUALQUIER otra copia
# de core.vbs que exista al lado (incluida la vieja de Tables\), para que
# no vuelva a pasar esto de nuevo silenciosamente.
function Copias-Hermanas($archivoPrincipal) {
    $hermanas = @()
    $raiz = Split-Path (Split-Path $archivoPrincipal -Parent) -Parent
    foreach ($sub in @("Scripts", "Tables")) {
        $candidata = Join-Path $raiz "$sub\core.vbs"
        if ((Test-Path $candidata) -and ($candidata -ne $archivoPrincipal)) { $hermanas += $candidata }
    }
    return $hermanas
}

# Saca CUALQUIER version del enganche (bloque marcado Y la linea que
# fuerza UseNVRAM/NVRAMCallback), para poder reemplazarla limpio.
# Version-agnostico: saca v4, v8, v9, la que sea.
function Quitar-Enganche($texto) {
    # 1) el bloque marcado con comentarios INICIO/FIN (cualquier version)
    $texto = [regex]::Replace($texto, "(?s)\r?\n?' ===== VP3 LECTURA EN VIVO.*?FIN =====", "")
    # 2) cualquier llamada manual vieja tipo "On Error Resume Next : VP3... : On Error Goto 0"
    #    (de la v8, que quedo pegada en 9 lugares distintos)
    $texto = [regex]::Replace($texto, "(?m)^[ \t]*On Error Resume Next : VP3[A-Za-z_]* [A-Za-z]*[ \t]*: On Error Goto 0[ \t]*\r?\n", "")
    # 3) la linea de UseNVRAM/NVRAMCallback forzada (si la v8 la dejo activada)
    #    la volvemos a su forma original de fabrica
    $original = 'Dim UseNVRAM:If IsEmpty(Eval("UseVPMNVRAM"))=true Then UseNVRAM=false Else UseNVRAM = UseVPMNVRAM' + "`r`n" + 'Dim NVRAMCallback'
    $texto = [regex]::Replace($texto, '(?m)^Dim UseNVRAM:If IsEmpty\(Eval\("UseVPMNVRAM"\)\)=true Then UseNVRAM=(?:True|true|False|false) Else UseNVRAM = UseVPMNVRAM\r?\nDim NVRAMCallback(?::Set NVRAMCallback = GetRef\("[A-Za-z0-9_]*"\))?\r?\n', $original + "`r`n")
    return $texto
}

$codigo = @"

$ini
' VP3 - Lectura en vivo (v$VERSION), motor nativo de VPinMAME.
' Se engancha UNA SOLA VEZ en el punto de extension que ya trae el
' core.vbs original (UseNVRAM + NVRAMCallback). Nada mas.
' Se saca solo con LECTURA_EN_VIVO.bat opcion 2 / activar_lectura_en_vivo.ps1 -Quitar.
Dim vp3_nv, vp3_iniciado, vp3_ult, vp3_rom, vp3_fso

Sub VP3EnVivo(aChg)
    On Error Resume Next
    Err.Clear

    If IsEmpty(Controller) Or Controller Is Nothing Then Exit Sub

    Dim hayCambios, i, n, idx, val
    hayCambios = False

    If vp3_iniciado <> True Then
        ' Primera vez: UNA lectura completa (necesaria para tener una
        ' imagen de referencia). De ahi en mas, solo se usan los deltas
        ' que ya llegan por parametro: nunca mas se vuelve a leer todo.
        vp3_nv = Controller.NVRAM
        If Err.Number <> 0 Or Not IsArray(vp3_nv) Then Err.Clear : Exit Sub
        vp3_iniciado = True
        hayCambios = True
    ElseIf IsArray(aChg) Then
        n = -1
        n = UBound(aChg, 1)
        If Err.Number = 0 And n >= 0 Then
            For i = 0 To n
                idx = aChg(i, 0)
                val = aChg(i, 1)
                If Err.Number = 0 And idx >= 0 And idx <= UBound(vp3_nv) Then
                    vp3_nv(idx) = val
                    hayCambios = True
                End If
            Next
        End If
        Err.Clear
    End If

    If Not hayCambios Then Exit Sub

    If vp3_rom = "" Then
        vp3_rom = cGameName
        If Err.Number <> 0 Or vp3_rom = "" Then
            Err.Clear
            vp3_rom = Controller.GameName
            If Err.Number <> 0 Then vp3_rom = ""
        End If
        If vp3_rom = "" Then
            Err.Clear
            vp3_rom = Controller.ROMName
            If Err.Number <> 0 Then vp3_rom = ""
        End If
        If vp3_rom = "" Then vp3_rom = "desconocido"
        vp3_rom = LCase(vp3_rom)
    End If

    Dim buf(), txt
    ReDim buf(UBound(vp3_nv))
    For i = 0 To UBound(vp3_nv)
        buf(i) = Right("0" & Hex(vp3_nv(i)), 2)
    Next
    txt = Join(buf, "")
    If txt = vp3_ult Then Exit Sub
    vp3_ult = txt

    If vp3_fso Is Nothing Then Set vp3_fso = CreateObject("Scripting.FileSystemObject")
    If Not vp3_fso.FolderExists("$carpetaLive") Then vp3_fso.CreateFolder "$carpetaLive"
    Dim arch
    Set arch = vp3_fso.CreateTextFile("$carpetaLive\" & vp3_rom & ".hex", True)
    arch.WriteLine "VP3LIVE1"
    arch.WriteLine "rom=" & vp3_rom
    arch.WriteLine "bytes=" & (UBound(vp3_nv) + 1)
    arch.WriteLine txt
    arch.Close
    Set arch = Nothing
    Err.Clear
End Sub
$fin
"@

$archivo = Buscar-Core
if (-not $archivo) {
    if (-not $Auto) { Write-Host " No encontre core.vbs en esta maquina." -ForegroundColor Red; Read-Host " Enter" }
    exit 2
}

$texto = Get-Content $archivo -Raw
$yaEsta = $texto -like "*$ini*"

if (-not $Auto -and -not $Quitar) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "   VP3 - LECTURA EN VIVO (subir sin salir de la mesa)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " Archivo: $archivo" -ForegroundColor Gray
    if ($yaEsta) { Write-Host " ESTADO: ACTIVADA ($VERSION)" -ForegroundColor Green }
    else         { Write-Host " ESTADO: desactivada" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "   1 = ACTIVAR" -ForegroundColor Green
    Write-Host "   2 = DESACTIVAR (deja todo como estaba)" -ForegroundColor Yellow
    Write-Host "   3 = Salir" -ForegroundColor Gray
    Write-Host ""
    $op = Read-Host " Que hago? (1/2/3)"
    if ($op -eq "2") { $Quitar = $true }
    elseif ($op -ne "1") { exit 0 }
}

$backup = "$archivo.VP3BACKUP_$(Get-Date -Format 'yyyyMMdd')"
if (-not (Test-Path $backup)) { Copy-Item $archivo $backup -Force }

if ($Quitar) {
    $limpio = Quitar-Enganche $texto
    Set-Content $archivo $limpio -Encoding Default -NoNewline
    foreach ($hermana in (Copias-Hermanas $archivo)) {
        Set-Content $hermana $limpio -Encoding Default -NoNewline
    }
    if (-not $Auto) {
        Write-Host ""; Write-Host " DESACTIVADA. core.vbs quedo como estaba." -ForegroundColor Green
        Read-Host " Enter para cerrar"
    }
    exit 0
}

if ($yaEsta) {
    # Igual hay que revisar las copias hermanas: puede que $archivo ya
    # estuviera activado de una vuelta anterior pero una copia al lado
    # (Tables\core.vbs) haya quedado vieja o distinta (el bug de fondo
    # que causaba que el enganche nunca disparara, ver nota arriba).
    foreach ($hermana in (Copias-Hermanas $archivo)) {
        $textoHermana = Get-Content $hermana -Raw -ErrorAction SilentlyContinue
        if ($textoHermana -ne $texto) { Set-Content $hermana $texto -Encoding Default -NoNewline }
    }
    if (-not $Auto) { Write-Host ""; Write-Host " Ya estaba activada ($VERSION)." -ForegroundColor Yellow; Read-Host " Enter" }
    else { Write-Host "      OK (ya estaba activada)" }
    exit 0
}

New-Item -ItemType Directory -Force -Path $carpetaLive | Out-Null

# Limpia CUALQUIER version vieja (v4, v8, lo que sea) antes de poner v9
$texto = Quitar-Enganche $texto

# UN SOLO cambio de "cableado": forzar UseNVRAM=True y apuntar
# NVRAMCallback a nuestra funcion. Nada mas se toca en el resto del
# archivo (nada de respaldos en Update/PinMAMETimer_Timer: el punto
# nativo ya se llama en cada vuelta del timer principal, siempre).
$patronCableado = '(?m)^Dim UseNVRAM:If IsEmpty\(Eval\("UseVPMNVRAM"\)\)=true Then UseNVRAM=false Else UseNVRAM = UseVPMNVRAM\r?\nDim NVRAMCallback\r?\n'
$nuevoCableado = 'Dim UseNVRAM:If IsEmpty(Eval("UseVPMNVRAM"))=true Then UseNVRAM=True Else UseNVRAM = UseVPMNVRAM' + "`r`n" + 'Dim NVRAMCallback:Set NVRAMCallback = GetRef("VP3EnVivo")' + "`r`n"

if ($texto -notmatch $patronCableado) {
    if ($Auto) { Write-Host "      Aviso: no encontre el punto de enganche nativo (UseNVRAM/NVRAMCallback), no se activo" }
    else { Write-Host " No encontre el punto de enganche esperado en core.vbs. No toco nada." -ForegroundColor Red; Read-Host " Enter" }
    exit 3
}
$texto = $texto -replace $patronCableado, $nuevoCableado

$textoFinal = $texto + $codigo
Set-Content $archivo $textoFinal -Encoding Default -NoNewline
foreach ($hermana in (Copias-Hermanas $archivo)) {
    Set-Content $hermana $textoFinal -Encoding Default -NoNewline
}

if ($Auto) {
    Write-Host "      OK"
} else {
    Write-Host ""
    Write-Host " ACTIVADA ($VERSION, motor nativo)." -ForegroundColor Green
    Write-Host " Ahora el record sube apenas grabas las iniciales, sin lag." -ForegroundColor Cyan
    Write-Host ""
    Read-Host " Enter para cerrar"
}
exit 0
