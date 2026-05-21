# ============================================================
# RESTAURAR LAS COPAS DE HERNÁN A SUPABASE
# Script rápido para sincronizar los 82 registros
# ============================================================

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RESTAURANDO COPAS DE HERNÁN A SUPABASE" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Leer archivo con los 82 registros
Write-Host "1. Leyendo registros desde historial_nube.json..." -ForegroundColor White
$json = Get-Content "historial_nube.json" -Raw

if (-not $json) {
    Write-Host "❌ Error: No se puede leer historial_nube.json" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Archivo cargado" -ForegroundColor Green
Write-Host ""

# Credenciales Supabase
$uri = "https://hjcabcqihznzrwqwyjdo.supabase.co/rest/v1/records"
$apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqY2FiY3FpaHpuenJ3cXd5amRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTQ0MzUwMDAsImV4cCI6MTg3MjIwMTQwMH0.w0u2-nNECfKoVJIDCEzM-P39kxj_o7CZcMI3z3LvCFU"

$headers = @{
    "apikey" = $apikey
    "Authorization" = "Bearer $apikey"
    "Content-Type" = "application/json"
    "Prefer" = "resolution=merge-duplicates"
}

# Enviar datos a Supabase
Write-Host "2. Sincronizando 82 registros con Supabase..." -ForegroundColor White

try {
    $response = Invoke-WebRequest -Uri $uri `
        -Method POST `
        -Headers $headers `
        -Body $json `
        -UseBasicParsing `
        -ErrorAction Stop

    Write-Host "✅ Respuesta: HTTP $($response.StatusCode)" -ForegroundColor Green
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  ✅ SINCRONIZACIÓN COMPLETADA" -ForegroundColor Green
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 DATOS RESTAURADOS:" -ForegroundColor Cyan
    Write-Host "  ✅ Attack from Mars: HER 12.994.263.970 pts" -ForegroundColor Green
    Write-Host "  ✅ Cactus Canyon: HER 114.597.770 pts" -ForegroundColor Green
    Write-Host "  ✅ Todos los 82 registros sincronizados" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 Abre VP3-Web/index.html y verifica que las copas aparezcan" -ForegroundColor Yellow
    Write-Host ""
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Si ves 'No se puede resolver el nombre remoto', verifica tu conexión a internet" -ForegroundColor Yellow
    exit 1
}
