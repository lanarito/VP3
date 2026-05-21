#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Restaurar TODOS los registros desde historial_nube.json a Supabase
Esto desice el daño del Upsert fallido
"""

import json
import urllib.request
import os
import sys

# Credenciales Supabase (deben estar configuradas)
SUPABASE_URL = "https://hjcabcqihznzrwqwyjdo.supabase.co/rest/v1/records"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqY2FiY3FpaHpuenJ3cXd5amRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTQ0MzUwMDAsImV4cCI6MTg3MjIwMTQwMH0.w0u2-nNECfKoVJIDCEzM-P39kxj_o7CZcMI3z3LvCFU"

def restaurar_supabase():
    """Restaurar registros de MAQUINAS_VP3/historial_nube.json a Supabase"""

    # Leer archivo de respaldo
    archivo_backup = "MAQUINAS_VP3/historial_nube.json"
    if not os.path.exists(archivo_backup):
        print(f"❌ Error: No se encontró {archivo_backup}")
        return False

    with open(archivo_backup, "r") as f:
        registros = json.load(f)

    print(f"📋 Restaurando {len(registros)} registros desde backup...")

    if not registros:
        print("⚠️ Archivo de backup vacío")
        return False

    # Headers Supabase
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }

    # Subir a Supabase
    try:
        data = json.dumps(registros).encode("utf-8")
        req = urllib.request.Request(SUPABASE_URL, data=data, headers=headers, method="POST")
        response = urllib.request.urlopen(req)
        print(f"✅ Supabase restaurado con {len(registros)} registros")
        response.close()
        return True
    except Exception as e:
        print(f"❌ Error subiendo a Supabase: {e}")
        return False

if __name__ == "__main__":
    os.chdir("c:\\Github repos\\VP3 COMPLETO")
    if restaurar_supabase():
        print("\n✅ RESTAURACIÓN COMPLETADA")
        sys.exit(0)
    else:
        print("\n❌ RESTAURACIÓN FALLIDA")
        sys.exit(1)
