# ============================================================
# COMPILADOR DE EXE - SISTEMA VP3
# Ejecutar este script para recompilar subir_puntajes.exe y RESET_NUBE.exe
# ============================================================

$carpetaProyecto = "c:\Github repos\VP3 COMPLETO"
Set-Location $carpetaProyecto

Write-Host "============================================"
Write-Host "   COMPILADOR VP3 - Generando .exe"
Write-Host "============================================"
Write-Host ""

# Compilar subir_puntajes.exe
Write-Host "1/2 Compilando subir_puntajes.exe..."
pyinstaller --onefile --console --name subir_puntajes subir_puntajes.py
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR compilando subir_puntajes.py"; pause; exit 1 }

Write-Host ""

# Compilar RESET_NUBE.exe
Write-Host "2/2 Compilando RESET_NUBE.exe..."
pyinstaller --onefile --console --name RESET_NUBE RESET_NUBE.py
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR compilando RESET_NUBE.py"; pause; exit 1 }

Write-Host ""
Write-Host "Copiando .exe a MAQUINAS_VP3..."

Copy-Item "dist\subir_puntajes.exe" "MAQUINAS_VP3\subir_puntajes.exe" -Force
Copy-Item "dist\RESET_NUBE.exe"    "MAQUINAS_VP3\RESET_NUBE.exe"    -Force

Write-Host ""
Write-Host "============================================"
Write-Host "   LISTO! Archivos actualizados:"
Write-Host "   - MAQUINAS_VP3\subir_puntajes.exe"
Write-Host "   - MAQUINAS_VP3\RESET_NUBE.exe"
Write-Host "============================================"
Write-Host ""

# Limpiar archivos temporales de PyInstaller
Remove-Item "dist"  -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "build" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "*.spec"               -Force -ErrorAction SilentlyContinue

Write-Host "Presiona Enter para cerrar..."
Read-Host
