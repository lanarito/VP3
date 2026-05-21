#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import json
import urllib.request

SUPABASE_URL = "https://hjcabcqihznzrwqwyjdo.supabase.co/rest/v1/records"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqY2FiY3FpaHpuenJ3cXd5amRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTQ0MzUwMDAsImV4cCI6MTg3MjIwMTQwMH0.w0u2-nNECfKoVJIDCEzM-P39kxj_o7CZcMI3z3LvCFU"

with open("MAQUINAS_VP3/historial_nube.json") as f:
    registros = json.load(f)

headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates"
}

try:
    data = json.dumps(registros).encode("utf-8")
    req = urllib.request.Request(SUPABASE_URL, data=data, headers=headers, method="POST")
    urllib.request.urlopen(req)
    print(f"✅ OK: {len(registros)} registros restaurados a Supabase")
except Exception as e:
    print(f"❌ Error: {e}")
