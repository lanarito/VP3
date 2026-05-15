import urllib.request
import json
import ssl

SUPABASE_URL = "https://ckcjujadpmhdgcvyyahd.supabase.co/rest/v1/puntajes"
SUPABASE_KEY = "sb_publishable_COrjv6wdGvLMbtGETo3xCQ__-Wdys3L"

headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}"
}

try:
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    req_get = urllib.request.Request(f"{SUPABASE_URL}?select=*", headers=headers)
    with urllib.request.urlopen(req_get, context=ctx) as response:
        existentes = json.loads(response.read().decode())
    
    print(f"Total de registros en la nube: {len(existentes)}")
    players = set()
    for r in existentes:
        players.add(r['jugador'])
        print(f"ID: {r['id_record']} | Mesa: {r['mesa']} | Jugador: {r['jugador']} | Puntaje: {r['puntaje']} | Fecha: {r['fecha']}")
    print(f"Jugadores distintos: {len(players)}")
    print(list(players))
except Exception as e:
    print(f"Error: {e}")
