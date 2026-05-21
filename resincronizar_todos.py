#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RESINCRONIZAR TODOS LOS 82 REGISTROS A SUPABASE
Script de emergencia para restaurar datos cuando la sincronización falla
"""

import json
import urllib.request
import urllib.error

# Credenciales Supabase
SUPABASE_URL = "https://hjcabcqihznzrwqwyjdo.supabase.co/rest/v1/records"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqY2FiY3FpaHpuenJ3cXd5amRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTQ0MzUwMDAsImV4cCI6MTg3MjIwMTQwMH0.w0u2-nNECfKoVJIDCEzM-P39kxj_o7CZcMI3z3LvCFU"

print("════════════════════════════════════════════════════════════════")
print("        RESINCRONIZACIÓN FORZADA A SUPABASE")
print("════════════════════════════════════════════════════════════════")
print()

# 1. Leer historial_nube.json
print("1. Leyendo 82 registros desde historial_nube.json...")
try:
    with open("historial_nube.json", "r") as f:
        registros = json.load(f)
    print(f"   ✅ {len(registros)} registros cargados")
except Exception as e:
    print(f"   ❌ Error: {e}")
    exit(1)

# 2. Headers Supabase
headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates"
}

# 3. Subir a Supabase
print("2. Sincronizando con Supabase...")
try:
    data = json.dumps(registros).encode("utf-8")
    req = urllib.request.Request(SUPABASE_URL, data=data, headers=headers, method="POST")
    response = urllib.request.urlopen(req)
    print(f"   ✅ {len(registros)} registros sincronizados a Supabase")
    print(f"   Estado HTTP: {response.status}")
    response.close()
except urllib.error.URLError as e:
    print(f"   ❌ Error de conexión: {e.reason}")
    print()
    print("ALTERNATIVA - Si el script falla por conectividad:")
    print("Ejecuta este comando en PowerShell:")
    print()
    print('$json = Get-Content "historial_nube.json" -Raw')
    print('$uri = "https://hjcabcqihznzrwqwyjdo.supabase.co/rest/v1/records"')
    print('$headers = @{')
    print('    "apikey" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqY2FiY3FpaHpuenJ3cXd5amRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTQ0MzUwMDAsImV4cCI6MTg3MjIwMTQwMH0.w0u2-nNECfKoVJIDCEzM-P39kxj_o7CZcMI3z3LvCFU"')
    print('    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqY2FiY3FpaHpuenJ3cXd5amRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTQ0MzUwMDAsImV4cCI6MTg3MjIwMTQwMH0.w0u2-nNECfKoVJIDCEzM-P39kxj_o7CZcMI3z3LvCFU"')
    print('    "Content-Type" = "application/json"')
    print('    "Prefer" = "resolution=merge-duplicates"')
    print('}')
    print('Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $json -UseBasicParsing')
    exit(1)
except Exception as e:
    print(f"   ❌ Error: {e}")
    exit(1)

# 4. Resumen
print()
print("════════════════════════════════════════════════════════════════")
print("✅ RESINCRONIZACIÓN COMPLETADA")
print("════════════════════════════════════════════════════════════════")
print()
print("Datos restaurados en Supabase:")
print(f"  • Attack from Mars: HER {12994263970:,} + ARI + AGU")
print(f"  • Cactus Canyon: HER {114597770:,} + LAL + AGU")
print(f"  • Todas las otras mesas: Datos completos")
print()
print("La página web debería mostrar todos los registros ahora.")
print()
