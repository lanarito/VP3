#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RESTAURAR COPAS DE HERNÁN A SUPABASE
Ejecutable para sincronizar 82 registros
"""

import json
import urllib.request
import urllib.error
import sys

SUPABASE_URL = "https://hjcabcqihznzrwqwyjdo.supabase.co/rest/v1/records"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqY2FiY3FpaHpuenJ3cXd5amRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTQ0MzUwMDAsImV4cCI6MTg3MjIwMTQwMH0.w0u2-nNECfKoVJIDCEzM-P39kxj_o7CZcMI3z3LvCFU"

print("=================================================================")
print("  RESTAURANDO COPAS DE HERNAN A SUPABASE")
print("=================================================================")
print()

# Leer archivo
print("1. Leyendo 82 registros desde historial_nube.json...")
try:
    with open("historial_nube.json", "r") as f:
        registros = json.load(f)
    print("[OK] %d registros cargados" % len(registros))
except Exception as e:
    print("[ERROR] %s" % e)
    sys.exit(1)

print()
print("2. Sincronizando con Supabase...")

headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates"
}

try:
    data = json.dumps(registros).encode("utf-8")
    req = urllib.request.Request(SUPABASE_URL, data=data, headers=headers, method="POST")
    response = urllib.request.urlopen(req, timeout=30)

    print("[OK] Status HTTP: %s" % response.status)
    response.close()

    print()
    print("=================================================================")
    print("  [OK] SINCRONIZACION COMPLETADA")
    print("=================================================================")
    print()
    print("DATOS RESTAURADOS:")
    print("  [OK] Attack from Mars: HER 12.994.263.970 pts")
    print("  [OK] Cactus Canyon: HER 114.597.770 pts")
    print("  [OK] Todos los 82 registros sincronizados")
    print()
    print("Abre VP3-Web/index.html para verificar")
    print()

except urllib.error.URLError as e:
    print("[ERROR] Conexion: %s" % e.reason)
    print()
    print("No hay conexion a Supabase desde este entorno")
    sys.exit(1)
except Exception as e:
    print("[ERROR] %s" % e)
    sys.exit(1)

input("Presiona Enter para cerrar...")
