# ============================================================
# VP3 - LECTURA EN VIVO (v14 - sondeo directo, sin ChangedNVRAM)
#
# HISTORIA (por que se llego a esta version):
#
# v9/v10: se enganchaban en el punto de extension nativo de VPinMAME
# (UseNVRAM + NVRAMCallback), que en cada vuelta del timer principal
# entrega Controller.ChangedNVRAM (los bytes que cambiaron desde el
# ULTIMO llamado). En teoria, event-driven de verdad y gratis cuando no
# hay cambios.
#
# PROBADO EN LA MAQUINA REAL EL 1-sep-2026 (con un registro de actividad
# que anotaba cada disparo con hora exacta): jugando de verdad, grabando
# un record y esperando PARADO frente a la mesa hasta 1 minuto entero
# sin salir, el enganche via ChangedNVRAM se quedaba MUDO todo ese
# tiempo, y recien disparaba una rafaga de decenas de veces junto,
# amontonada en el mismo segundo en que VPinMAME escribe el .nv real al
# cerrar la mesa. O sea: Controller.ChangedNVRAM en la practica no avisa
# cambios en vivo mientras se juega -- solo parece reflejar lo que
# VPinMAME ya volco a disco, no la memoria en caliente. Para lo que
# necesitamos (avisar ANTES de que la mesa se cierre) esa funcion nativa
# no sirve, por mas prolija que sea la teoria.
#
# v12: se abandona ChangedNVRAM/NVRAMCallback por completo. En cambio,
# se engancha UNA sola llamada dentro de Sub PinMAMETimer_Timer (el
# timer principal que ya corre siempre, en cada vuelta) a una rutina
# propia que:
#   - Se AUTO-LIMITA a revisar como mucho cada 2 segundos (con
#     Timer(), el reloj de VBScript) -- no hace nada el resto de las
#     vueltas del timer, que corre mucho mas seguido.
#   - Cuando le toca revisar, lee Controller.NVRAM (la memoria ENTERA,
#     pero es una lectura nativa de VPinMAME, no un bucle de VBScript:
#     rapida) y la compara byte a byte contra la copia que tiene
#     guardada.
#   - NO usa Mid(...) = valor para parchear en el lugar -- esa sentencia
#     NO EXISTE en VBScript (es de VBA/VB6 nada mas; probado 1-sep-2026
#     con On Error Resume Next puesto, fallaba en silencio con 'Type
#     mismatch' y el v10 viejo nunca patcheaba nada de verdad). Si hubo
#     cualquier cambio, reconstruye el texto hexadecimal COMPLETO con
#     Join una sola vez y listo.
#   - Solo escribe a disco si hubo algun cambio real.
# v13 (1-sep-2026): bajado el throttle de 1 a 2 segundos -- se noto una
# tildada suave en mesa grande. Aunque la mesa tenga 130KB de NVRAM
# (Stern/SAM), la comparacion completa tarda unos pocos milisegundos y
# ahora pasa como mucho una vez cada 2 segundos -- nada que ver con
# hacerlo en cada vuelta del timer (60 veces por segundo), que es lo que
# causaba la tildada de v9 en multibola.
#
# v14 (1-sep-2026): la tildada de v13 SEGUIA notandose jugando Walking
# Dead (Stern/SAM, ~130KB). Medido con un harness VBScript real: cuando
# cambia algo, reconstruir el texto hex ENTERO con Hex()+Right() byte a
# byte cuesta ~55ms en una mesa de ese tamaño -- suficiente para sentirse
# como un salto, sobre todo si pasa seguido mientras se juega (cada vez
# que cambia un puntaje o contador). Ahora se guarda el texto hex YA
# CONVERTIDO de una vuelta a la otra (vp3_bufHex) y solo se recalculan
# los 2 caracteres de los bytes que en verdad cambiaron -- de ~55ms a
# practicamente 0 para el puñado de bytes que cambian por vez. Solo
# queda el costo de Join() para juntar el texto final (~15-20ms medidos)
# mas la comparacion byte a byte (~15ms) -- de ~90ms a ~35ms en el peor
# caso medido, en la mesa mas grande que hay.
#
#   -Auto    : activa sin preguntar nada (lo usa ACTUALIZAR_VP3.bat)
#   -Quitar  : saca el enganche y deja core.vbs como estaba
#   sin nada : muestra un menu
#
# Es idempotente: si ya esta puesto y es la misma version, no hace nada.
# Si hay una version vieja (de cualquier version anterior, incluidas las
# que tocaban UseNVRAM/NVRAMCallback), la reemplaza por completo antes
# de poner la nueva -- y revierte esa vieja modificacion de
# UseNVRAM/NVRAMCallback a su valor de fabrica, porque v12+ ya no la usa.
# ============================================================
param([switch]$Auto, [switch]$Quitar)

$VERSION = "v14"
$ini = "' ===== VP3 LECTURA EN VIVO $VERSION INICIO ====="
$fin = "' ===== VP3 LECTURA EN VIVO $VERSION FIN ====="
$carpetaLive = "C:\vPinball\VP3_LIVE"
$marcaLlamada = "	VP3EnVivoTick ' VP3 lectura en vivo (v14)"

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
# Por eso esta funcion, ademas de tocar $archivo (el que encuentre
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

# Saca CUALQUIER version del enganche: el bloque marcado (cualquier
# version), la llamada dentro de PinMAMETimer_Timer (v12+, cualquier
# numero de version en el comentario -- BUG encontrado 1-sep-2026 al
# subir v12->v13: si esto solo matcheaba el texto exacto de la version
# ACTUAL, la llamada vieja con otro numero de version en el comentario
# quedaba huerfana y el enganche nuevo se agregaba igual, duplicando la
# llamada dentro del timer), la linea de UseNVRAM/NVRAMCallback forzada
# (v9/v10/v11diag, se revierte a fabrica porque v12+ no la usa), y
# cualquier resto viejo de v8 (Gemini, 9 llamadas sueltas tipo
# "On Error Resume Next : VPxxx : On Error Goto 0").
function Quitar-Enganche($texto) {
    # 1) el bloque marcado con comentarios INICIO/FIN (cualquier version)
    $texto = [regex]::Replace($texto, "(?s)\r?\n?' ===== VP3 LECTURA EN VIVO.*?FIN =====", "")
    # 2) la llamada dentro de PinMAMETimer_Timer, CUALQUIER version (v12, v13, ...)
    $texto = [regex]::Replace($texto, "(?m)^[ \t]*VP3EnVivoTick ' VP3 lectura en vivo \(v[0-9]+\)[ \t]*\r?\n", "")
    # 3) restos viejos de v8 (Gemini): llamadas sueltas tipo
    #    "On Error Resume Next : VPxxx Null : On Error Goto 0"
    $texto = [regex]::Replace($texto, "(?m)^[ \t]*On Error Resume Next : VP3[A-Za-z_]* [A-Za-z]*[ \t]*: On Error Goto 0[ \t]*\r?\n", "")
    # 4) la linea de UseNVRAM/NVRAMCallback forzada por v9/v10/v11diag
    #    (v12 no la toca, asi que si aparece hay que devolverla a fabrica)
    $original = 'Dim UseNVRAM:If IsEmpty(Eval("UseVPMNVRAM"))=true Then UseNVRAM=false Else UseNVRAM = UseVPMNVRAM' + "`r`n" + 'Dim NVRAMCallback'
    $texto = [regex]::Replace($texto, '(?m)^Dim UseNVRAM:If IsEmpty\(Eval\("UseVPMNVRAM"\)\)=true Then UseNVRAM=(?:True|true|False|false) Else UseNVRAM = UseVPMNVRAM\r?\nDim NVRAMCallback(?::Set NVRAMCallback = GetRef\("[A-Za-z0-9_]*"\))?\r?\n', $original + "`r`n")
    return $texto
}

$codigo = @"

$ini
' VP3 - Lectura en vivo (v$VERSION). Sondeo propio de Controller.NVRAM,
' NO usa Controller.ChangedNVRAM (comprobado que no avisa cambios en
' vivo durante el juego, solo cuando VPinMAME ya escribio a disco).
' Se saca solo con activar_lectura_en_vivo.ps1 -Quitar.
Dim vp3_nv, vp3_iniciado, vp3_ult, vp3_rom, vp3_fso, vp3_ultimo_chequeo, vp3_bufHex

Sub VP3EnVivoTick
    On Error Resume Next
    Err.Clear

    If IsEmpty(Controller) Or Controller Is Nothing Then Exit Sub

    ' Auto-limite: como mucho cada 2 segundos. Se usa Now + DateDiff (no la
    ' funcion Timer) para evitar cualquier choque de nombre con objetos de la
    ' mesa -- varias mesas VPX traen elementos propios llamados "Timer" que
    ' pueden tapar la funcion intrinseca.
    Dim ahora, transcurrido
    ahora = Now
    If Not IsEmpty(vp3_ultimo_chequeo) Then
        transcurrido = DateDiff("s", vp3_ultimo_chequeo, ahora)
        If transcurrido < 2 And transcurrido >= 0 Then Exit Sub
    End If
    vp3_ultimo_chequeo = ahora

    Dim nvActual
    nvActual = Controller.NVRAM
    If Err.Number <> 0 Or Not IsArray(nvActual) Then Err.Clear : Exit Sub

    Dim hayCambios, i

    If vp3_iniciado <> True Then
        vp3_nv = nvActual
        vp3_iniciado = True
        hayCambios = True
        ' Primera lectura: arma el array de texto hex completo, una unica vez.
        ReDim vp3_bufHex(UBound(vp3_nv))
        For i = 0 To UBound(vp3_nv)
            vp3_bufHex(i) = Right("0" & Hex(vp3_nv(i)), 2)
        Next
    ElseIf UBound(nvActual) = UBound(vp3_nv) Then
        ' PROBADO 1-sep-2026: VBScript NO tiene la sentencia Mid(...) =
        ' valor para parchear un string en el lugar (eso es de VBA/VB6
        ' nada mas). Con On Error Resume Next puesto, tirar esa linea
        ' fallaba con 'Type mismatch' en silencio -- por eso nunca se vio
        ' ningun cambio real durante el juego en la version vieja.
        '
        ' v14 (1-sep-2026): medido en una mesa de 130KB (tipo Walking Dead)
        ' que reconstruir el texto hex ENTERO con Hex()+Right() cuesta unos
        ' 55ms, notandose como tildada cuando cambia algo mientras se juega.
        ' Ahora se guarda el texto hex YA CONVERTIDO (vp3_bufHex) de una
        ' vuelta a la otra, y solo se recalculan los 2 caracteres de los
        ' bytes que en verdad cambiaron -- practicamente gratis para el
        ' puñado de bytes que cambian por vez. Reasignar UN ELEMENTO de un
        ' array (vp3_bufHex(i) = ...) es distinto de la sentencia Mid rota:
        ' esto si existe y funciona en VBScript.
        hayCambios = False
        For i = 0 To UBound(nvActual)
            If vp3_nv(i) <> nvActual(i) Then
                hayCambios = True
                vp3_nv(i) = nvActual(i)
                vp3_bufHex(i) = Right("0" & Hex(nvActual(i)), 2)
            End If
        Next
    End If

    If Not hayCambios Then Exit Sub

    vp3_ult = Join(vp3_bufHex, "")

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

    If vp3_fso Is Nothing Then Set vp3_fso = CreateObject("Scripting.FileSystemObject")
    If Not vp3_fso.FolderExists("$carpetaLive") Then vp3_fso.CreateFolder "$carpetaLive"
    Dim arch
    Set arch = vp3_fso.CreateTextFile("$carpetaLive\" & vp3_rom & ".hex", True)
    arch.WriteLine "VP3LIVE1"
    arch.WriteLine "rom=" & vp3_rom
    arch.WriteLine "bytes=" & (UBound(vp3_nv) + 1)
    arch.WriteLine vp3_ult
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
    # (Tables\core.vbs) haya quedado vieja o distinta.
    foreach ($hermana in (Copias-Hermanas $archivo)) {
        $textoHermana = Get-Content $hermana -Raw -ErrorAction SilentlyContinue
        if ($textoHermana -ne $texto) { Set-Content $hermana $texto -Encoding Default -NoNewline }
    }
    if (-not $Auto) { Write-Host ""; Write-Host " Ya estaba activada ($VERSION)." -ForegroundColor Yellow; Read-Host " Enter" }
    else { Write-Host "      OK (ya estaba activada)" }
    exit 0
}

New-Item -ItemType Directory -Force -Path $carpetaLive | Out-Null

# Limpia CUALQUIER version vieja (v4, v8, v9, v10, v11diag, lo que sea)
# antes de poner v12 -- incluye revertir la linea de
# UseNVRAM/NVRAMCallback a su valor de fabrica, porque v12 no la usa.
$texto = Quitar-Enganche $texto

# Enganche v12: UNA sola llamada agregada DENTRO de Sub
# PinMAMETimer_Timer, justo antes de su End Sub. Anclado al nombre
# exacto de la Sub (no un patron generico como el bug de v8): busca
# "Sub PinMAMETimer_Timer" y el PRIMER "End Sub" despues de eso -- en
# VBScript los Sub no se anidan, asi que ese primer "End Sub" es
# necesariamente el cierre de esta Sub y de ninguna otra.
$patronTimer = '(?s)(Sub PinMAMETimer_Timer.*?)(\r?\nEnd Sub)'
if ($texto -notmatch $patronTimer) {
    if ($Auto) { Write-Host "      Aviso: no encontre Sub PinMAMETimer_Timer en core.vbs, no se activo" }
    else { Write-Host " No encontre el punto de enganche esperado (PinMAMETimer_Timer) en core.vbs. No toco nada." -ForegroundColor Red; Read-Host " Enter" }
    exit 3
}
$texto = [regex]::Replace($texto, $patronTimer, { param($m) $m.Groups[1].Value + "`r`n" + $marcaLlamada + $m.Groups[2].Value }, 1)

$textoFinal = $texto + $codigo
Set-Content $archivo $textoFinal -Encoding Default -NoNewline
foreach ($hermana in (Copias-Hermanas $archivo)) {
    Set-Content $hermana $textoFinal -Encoding Default -NoNewline
}

if ($Auto) {
    Write-Host "      OK"
} else {
    Write-Host ""
    Write-Host " ACTIVADA ($VERSION, sondeo directo cada 2 segundos)." -ForegroundColor Green
    Write-Host " Ahora el record sube unos segundos despues de grabarlo, sin lag." -ForegroundColor Cyan
    Write-Host ""
    Read-Host " Enter para cerrar"
}
exit 0
