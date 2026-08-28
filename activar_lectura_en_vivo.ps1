# ============================================================
# VP3 - LECTURA EN VIVO
# Engancha en core.vbs para que la mesa pase el puntaje a VP3
# apenas se graban las iniciales, sin salir de la mesa.
#
#   -Auto    : activa sin preguntar nada (lo usa ACTUALIZAR_VP3.bat)
#   -Quitar  : saca el enganche y deja core.vbs como estaba
#   sin nada : muestra un menu
#
# Es idempotente: si ya esta puesto y es la misma version, no hace nada.
# Si hay una version vieja, la reemplaza.
# ============================================================
param([switch]$Auto, [switch]$Quitar)

$VERSION = "v1"
$ini = "' ===== VP3 LECTURA EN VIVO $VERSION INICIO ====="
$fin = "' ===== VP3 LECTURA EN VIVO $VERSION FIN ====="
$llamada = "    On Error Resume Next : VP3EnVivo : On Error Goto 0"
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

# Saca CUALQUIER version del enganche (para poder reemplazarla)
function Quitar-Enganche($texto) {
    $texto = [regex]::Replace($texto, "(?s)\r?\n?' ===== VP3 LECTURA EN VIVO.*?FIN =====", "")
    $texto = [regex]::Replace($texto, "(?m)^[ \t]*On Error Resume Next : VP3EnVivo : On Error Goto 0[ \t]*\r?\n", "")
    return $texto
}

$codigo = @"

$ini
' Pasa el puntaje a VP3 apenas se graban las iniciales, sin salir de la mesa.
' Lo pone y lo saca ACTUALIZAR_VP3.bat / LECTURA_EN_VIVO.bat. No editar a mano.
'
' Trabaja de a pedacitos (256 bytes por vuelta) para no frenar el juego,
' y solo escribe cuando el puntaje cambio de verdad.
Dim vp3rom, vp3ult, vp3buf, vp3pos, vp3nv, vp3reloj, vp3activo
Sub VP3EnVivo()
    On Error Resume Next
    Dim i, hasta, txt, fso, arch, carpeta
    carpeta = "$carpetaLive"

    If vp3activo <> True Then
        If vp3reloj <> Empty Then
            If Timer - vp3reloj < 3 And Timer >= vp3reloj Then Exit Sub
        End If
        vp3nv = Controller.NVRAM
        If Err.Number <> 0 Then Err.Clear : vp3reloj = Timer : Exit Sub
        If Not IsArray(vp3nv) Then vp3reloj = Timer : Exit Sub
        If vp3rom = "" Then
            vp3rom = Controller.GameName
            If Err.Number <> 0 Or vp3rom = "" Then Err.Clear : vp3rom = cGameName
            If Err.Number <> 0 Then Err.Clear
        End If
        If vp3rom = "" Then vp3reloj = Timer : Exit Sub
        ReDim vp3buf(UBound(vp3nv))
        vp3pos = 0
        vp3activo = True
    End If

    hasta = vp3pos + 255
    If hasta > UBound(vp3nv) Then hasta = UBound(vp3nv)
    For i = vp3pos To hasta
        vp3buf(i) = Right("0" & Hex(vp3nv(i)), 2)
    Next
    vp3pos = hasta + 1
    If vp3pos <= UBound(vp3nv) Then Exit Sub

    vp3activo = False
    vp3reloj = Timer
    txt = Join(vp3buf, "")
    If txt = vp3ult Then Exit Sub
    vp3ult = txt

    Set fso = CreateObject("Scripting.FileSystemObject")
    If Not fso.FolderExists(carpeta) Then fso.CreateFolder carpeta
    Set arch = fso.CreateTextFile(carpeta & "\" & LCase(vp3rom) & ".hex", True)
    arch.WriteLine "VP3LIVE1"
    arch.WriteLine "rom=" & LCase(vp3rom)
    arch.WriteLine "bytes=" & (UBound(vp3nv) + 1)
    arch.WriteLine txt
    arch.Close
    Set arch = Nothing
    Set fso = Nothing
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

# ---------- menu ----------
if (-not $Auto -and -not $Quitar) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "   VP3 - LECTURA EN VIVO (subir sin salir de la mesa)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " Archivo: $archivo" -ForegroundColor Gray
    if ($yaEsta) { Write-Host " ESTADO: ACTIVADA" -ForegroundColor Green }
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

# ---------- backup (una sola vez por dia, para no llenar de copias) ----------
$backup = "$archivo.VP3BACKUP_$(Get-Date -Format 'yyyyMMdd')"
if (-not (Test-Path $backup)) { Copy-Item $archivo $backup -Force }

# ---------- quitar ----------
if ($Quitar) {
    $limpio = Quitar-Enganche $texto
    Set-Content $archivo $limpio -Encoding Default -NoNewline
    if (-not $Auto) {
        Write-Host ""; Write-Host " DESACTIVADA. core.vbs quedo como estaba." -ForegroundColor Green
        Read-Host " Enter para cerrar"
    }
    exit 0
}

# ---------- activar ----------
if ($yaEsta) {
    if (-not $Auto) { Write-Host ""; Write-Host " Ya estaba activada." -ForegroundColor Yellow; Read-Host " Enter" }
    else { Write-Host "      OK (ya estaba activada)" }
    exit 0
}

$patron = "(?m)^([ \t]*Sub[ \t]+PinMAMETimer_Timer)[ \t]*\r?$"
if ($texto -notmatch $patron) {
    if ($Auto) { Write-Host "      Aviso: no encontre PinMAMETimer_Timer, no se activo" }
    else { Write-Host " No encontre 'Sub PinMAMETimer_Timer'. No toco nada." -ForegroundColor Red; Read-Host " Enter" }
    exit 3
}

New-Item -ItemType Directory -Force -Path $carpetaLive | Out-Null

# limpiar cualquier version vieja antes de poner la nueva
$texto = Quitar-Enganche $texto
$texto = $texto -replace $patron, "`$1`r`n$llamada"
Set-Content $archivo ($texto + $codigo) -Encoding Default -NoNewline

if ($Auto) {
    Write-Host "      OK"
} else {
    Write-Host ""
    Write-Host " ACTIVADA." -ForegroundColor Green
    Write-Host " Ahora el record sube apenas grabas las iniciales." -ForegroundColor Cyan
    Write-Host ""
    Read-Host " Enter para cerrar"
}
exit 0
