import sys
import json
import urllib.request
import ssl

try:
    if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    if sys.stderr and hasattr(sys.stderr, 'reconfigure'):
        sys.stderr.reconfigure(encoding='utf-8')
except Exception:
    pass

SUPABASE_URL = "https://ckcjujadpmhdgcvyyahd.supabase.co/rest/v1/puntajes"
SUPABASE_KEY = "sb_publishable_COrjv6wdGvLMbtGETo3xCQ__-Wdys3L"

headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json"
}

try:
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    # 1. Descargar lo que hay actualmente en la nube (34 registros)
    print("☁️ Descargando registros actuales de la nube...")
    req_get = urllib.request.Request(f"{SUPABASE_URL}?select=*", headers=headers)
    with urllib.request.urlopen(req_get, context=ctx) as response:
        existentes_nube = json.loads(response.read().decode())
    print(f"✅ Registros descargados de la nube: {len(existentes_nube)}")

    # 2. Cargar el historial anterior de historial_nube.json (29 registros históricos)
    print("📋 Cargando historial_nube.json...")
    with open("historial_nube.json", "r") as f:
        historial_local = json.load(f)
    print(f"✅ Registros cargados de historial_nube.json: {len(historial_local)}")

    # 3. Combinar ambos conjuntos de datos de forma inteligente
    mapa_final = {}

    # Primero agregamos los de historial_nube.json (valores con fechas correctas de ayer o antes)
    for r in historial_local:
        id_rec = r["id_record"]
        mapa_final[id_rec] = {
            "ID_Record": id_rec,
            "Mesa": r["mesa"],
            "Jugador": r["jugador"],
            "Puntaje": int(r["puntaje"]),
            "Fecha": r["fecha"]
        }

    # Luego agregamos los que están en la nube hoy (si son nuevos, de mesas nuevas, o si preservamos su fecha)
    for r in existentes_nube:
        id_rec = r["id_record"]
        # Si no existía en nuestro historial local, lo añadimos (por ejemplo, nuevos récords de Hernán)
        if id_rec not in mapa_final:
            mapa_final[id_rec] = {
                "ID_Record": id_rec,
                "Mesa": r["mesa"],
                "Jugador": r["jugador"],
                "Puntaje": int(r["puntaje"]),
                "Fecha": r["fecha"]
            }
        else:
            # Si existía en ambos pero el de historial tiene la fecha antigua y el de la nube tiene la fecha de hoy modificada,
            # mantenemos el del historial (que tiene la fecha correcta).
            # Solo si el puntaje en la nube de hoy es mayor al histórico, actualizamos el puntaje y mantenemos la fecha de la nube.
            if int(r["puntaje"]) > mapa_final[id_rec]["Puntaje"]:
                mapa_final[id_rec]["Puntaje"] = int(r["puntaje"])
                mapa_final[id_rec]["Fecha"] = r["fecha"]

    # 4. Agrupar por mesa, ordenar de mayor a menor y obtener el Top 5 estricto por mesa
    mesas_agrupadas = {}
    for d in mapa_final.values():
        m = d["Mesa"]
        if m not in mesas_agrupadas:
            mesas_agrupadas[m] = []
        mesas_agrupadas[m].append(d)

    filas_finales = []
    for mesa_nombre, recs in mesas_agrupadas.items():
        recs.sort(key=lambda x: x["Puntaje"], reverse=True)
        for i, r in enumerate(recs[:5]): # Quedarnos con el Top 5
            pos = "Gran Campeon" if i == 0 else f"{i+1}ro"
            filas_finales.append({
                "id_record": r["ID_Record"],
                "mesa": r["Mesa"],
                "posicion": pos,
                "jugador": r["Jugador"],
                "puntaje": r["Puntaje"],
                "fecha": r["Fecha"]
            })

    print(f"📊 Total de registros unificados y consolidados (Top 5): {len(filas_finales)}")

    # 5. Borrar la base de datos actual de Supabase
    print("🧹 Borrando base de datos en Supabase para reescribir los datos consolidados...")
    req_del = urllib.request.Request(f"{SUPABASE_URL}?id_record=not.is.null", headers=headers, method="DELETE")
    urllib.request.urlopen(req_del, context=ctx)
    print("✅ Borrado completo exitoso.")

    # 6. Insertar los nuevos registros unificados con sus fechas históricas y correctas
    print("🚀 Insertando registros consolidados con fechas restauradas en Supabase...")
    data = json.dumps(filas_finales).encode("utf-8")
    req_ins = urllib.request.Request(SUPABASE_URL, data=data, headers=headers, method="POST")
    urllib.request.urlopen(req_ins, context=ctx)
    print("🎉 RESTAURACION COMPLETA Y EXITOSA!")

    # 7. Actualizar historial_nube.json local con la versión perfecta consolidada
    with open("historial_nube.json", "w") as f:
        json.dump(filas_finales, f, indent=4)
    print("💾 Archivo historial_nube.json actualizado localmente.")

except Exception as e:
    print(f"❌ Error en la restauración: {e}")
