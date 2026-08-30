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

$VERSION = "v7"
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
    $texto = [regex]::Replace($texto, "(?m)^[ \t]*On Error Resume Next : VP3EnVivo : On Error Goto 0[ \t]*\r?\n?", "")
    return $texto
}

$codigo = @"

$ini
' VP3 - Lectura en vivo sin lag (v7)
' Vuelca la memoria NVRAM a VP3_LIVE apenas hay cambios
Dim vp3rom, vp3ult, vp3reloj, vp3fso

Sub VP3EnVivo()
    On Error Resume Next
    Dim t
    t = Timer
    If vp3reloj <> 0 And (t - vp3reloj < 1.0) And (t >= vp3reloj) Then Exit Sub
    vp3reloj = t

    If IsEmpty(Controller) Or Controller Is Nothing Then Exit Sub

    Dim nv
    nv = Controller.NVRAM
    If Err.Number <> 0 Or IsEmpty(nv) Or IsNull(nv) Then
        Err.Clear
        Exit Sub
    End If

    Dim i, ub, hexArr()
    ub = -1
    ub = UBound(nv)
    If Err.Number <> 0 Or ub < 0 Then
        Err.Clear
        Exit Sub
    End If

    ReDim hexArr(ub)
    For i = 0 To ub
        hexArr(i) = Right("0" & Hex(nv(i)), 2)
    Next

    Dim txt
    txt = Join(hexArr, "")
    If txt = vp3ult Then Exit Sub
    vp3ult = txt

    If vp3rom = "" Then
        vp3rom = cGameName
        If Err.Number <> 0 Or vp3rom = "" Then
            Err.Clear
            vp3rom = Controller.GameName
            If Err.Number <> 0 Then vp3rom = ""
        End If
        If vp3rom = "" Then
            Err.Clear
            vp3rom = Controller.ROMName
            If Err.Number <> 0 Then vp3rom = ""
        End If
        If vp3rom = "" Then vp3rom = "desconocido"
        vp3rom = LCase(vp3rom)
    End If

    If vp3fso Is Nothing Then Set vp3fso = CreateObject("Scripting.FileSystemObject")
    If Not vp3fso.FolderExists("$carpetaLive") Then vp3fso.CreateFolder "$carpetaLive"

    Dim arch
    Set arch = vp3fso.CreateTextFile("$carpetaLive\" & vp3rom & ".hex", True)
    arch.WriteLine "VP3LIVE1"
    arch.WriteLine "rom=" & vp3rom
    arch.WriteLine "bytes=" & (ub + 1)
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

$patronUpdate = "(?m)^([ \t]*Public[ \t]+Sub[ \t]+Update[ \t]*)(\r?\n)"
$patronFast = "(?m)^([ \t]*Public[ \t]+Sub[ \t]+FastUpdate[ \t]*)(\r?\n)"
$patronPinMAME = "(?m)^([ \t]*Sub[ \t]+PinMAMETimer_Timer[ \t]*)(\r?\n)"

New-Item -ItemType Directory -Force -Path $carpetaLive | Out-Null

# limpiar cualquier version vieja antes de poner la nueva
$texto = Quitar-Enganche $texto
if ($texto -match $patronUpdate) {
    $texto = $texto -replace $patronUpdate, "`$1`$2$llamada`n"
}
if ($texto -match $patronFast) {
    $texto = $texto -replace $patronFast, "`$1`$2$llamada`n"
}
if ($texto -match $patronPinMAME) {
    $texto = $texto -replace $patronPinMAME, "`$1`$2$llamada`n"
}
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
