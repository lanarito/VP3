import os, sys, subprocess, time, re
import urllib.request
import urllib.parse
import json
import traceback
import glob
from datetime import datetime

# ============================================================
# FORZAR DIRECTORIO DE TRABAJO Y BYPASS SSL
# ============================================================
import ssl
if getattr(sys, 'frozen', False):
    application_path = os.path.dirname(sys.executable)
else:
    application_path = os.path.dirname(os.path.abspath(__file__))
os.chdir(application_path)

try:
    ssl._create_default_https_context = ssl._create_unverified_context
    if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    if sys.stderr and hasattr(sys.stderr, 'reconfigure'):
        sys.stderr.reconfigure(encoding='utf-8')
except Exception:
    pass

# ============================================================
# CONFIGURACION PRINCIPAL Y SUPABASE
# ============================================================
NVRAM_PATH      = r"C:\vPinball\VisualPinball\VPinMAME\nvram"

SUPABASE_URL = "https://ckcjujadpmhdgcvyyahd.supabase.co/rest/v1/puntajes"
SUPABASE_KEY = "sb_publishable_COrjv6wdGvLMbtGETo3xCQ__-Wdys3L"

# Iniciales de fábrica conocidas (lista negra global) para bloquearlas de raíz en cualquier máquina
DEFAULT_INITIALS = {
    # Williams / Bally / Sega / Data East / Gottlieb / Stern defaults
    "TED", "PML", "XAQ", "TEX", "DEN", "MAB", "RRR", "ONE", "APR", "VLK",
    "EAE", "MAT", "POP", "DAD", "JBJ", "DRF", "CMP", "PDH", "GAG", "TMK",
    "ZAB", "LEU", "JON", "ROG", "FLI", "DAV", "NIK", "WMT", "JRP", "RFH",
    "BTB", "JEK", "EDC", "JLL", "RJD", "JAK", "KVD", "BLS", "NBW", "MDS",
    "BTA", "MDT", "MPE", "GTC", "WGP", "BEV", "BFW", "RAY", "GIL", "TWS",
    "ASR", "CJL", "LED", "DOA", "FEJ", "NTS", "TON", "VLD", "WAG", "XAQ", "TEX",
    "SAC", "GSC", "JWC", "BSO", "KGG", "DAY", "LFS", "KRT",
    # Genéricas o dummy
    "AAA", "BBB", "CCC", "DDD", "EEE", "FFF", "GGG", "HHH", "III", "JJJ",
    "KKK", "LLL", "MMM", "NNN", "OOO", "PPP", "QQQ", "RRR", "SSS", "TTT",
    "UUU", "VVV", "WWW", "XXX", "YYY", "ZZZ",
    "A A", "B B", "C C", "X Y", "WPC", "BLY", "ROM", "PIN", "GP ", "GP",
    "SYS", "BAM", "CPU", "AMD", "INT", "NV ", "NV", "HP ", "HP", "COM", "ARC"
}

# ============================================================
# CONFIGURACION DE ALERTAS (TELEGRAM - ¡Gratuito e ilimitado!)
# ============================================================
# Crea tu bot de Telegram usando @BotFather para conseguir el TOKEN.
# Crea un grupo de Telegram con tus amigos, añade al bot y obtén el CHAT_ID del grupo.
# Pega esos datos aquí abajo:
TELEGRAM_TOKEN = "8747156379:AAF3jffXhLFr4pVzh2Xx-iOj-a8DVxNZfnc"
TELEGRAM_CHAT_ID = "-5100440832"

def mandar_whatsapp(mensaje):
    """
    Envia alertas de récords. Redirigido a Telegram para ser gratis e ilimitado de por vida.
    """
    print(f"📢 Enviando alerta a Telegram: {mensaje}")
    if not TELEGRAM_TOKEN or TELEGRAM_TOKEN == "PONDRE_EL_TOKEN_AQUI" or not TELEGRAM_CHAT_ID or TELEGRAM_CHAT_ID == "PONDRE_EL_CHAT_ID_AQUI":
        print("⚠️ Telegram no configurado. Rellena las variables TELEGRAM_TOKEN y TELEGRAM_CHAT_ID al inicio de subir_puntajes.py")
        return
        
    try:
        # Codificar el texto para la URL
        texto_codificado = urllib.parse.quote(mensaje)
        url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage?chat_id={TELEGRAM_CHAT_ID}&text={texto_codificado}&parse_mode=Markdown"
        
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=15) as response:
            print("💬 Alerta enviada correctamente a Telegram.")
    except Exception as e:
        print(f"⚠️ Error enviando alerta a Telegram: {e}")

# ============================================================
# MOTOR UNICO: PINemHi (El Salvador)
# ============================================================
def leer_con_pinemhi(nombre_archivo):
    scores = []
    try:
        if not os.path.exists("pinemhi.exe"):
            print("❌ ERROR CRITICO: ¡No encuentro pinemhi.exe en esta carpeta!")
            return scores

        rom_a_leer = nombre_archivo
        respaldo_hlywoodh = None
        creado_temporal = False

        # Si es el archivo de Tom y Jerry, hacemos el truco de pasarlo por Hollywood Heat (hlywoodh)
        if "tomjerry" in nombre_archivo.lower():
            import shutil
            orig_path = os.path.join(NVRAM_PATH, nombre_archivo)
            temp_path = os.path.join(NVRAM_PATH, "hlywoodh.nv")
            
            if os.path.exists(orig_path):
                # Si ya existe un hlywoodh.nv, lo respaldamos
                if os.path.exists(temp_path):
                    respaldo_hlywoodh = temp_path + ".bak"
                    shutil.copy2(temp_path, respaldo_hlywoodh)
                
                # Copiamos tomjerry.nv como hlywoodh.nv
                shutil.copy2(orig_path, temp_path)
                rom_a_leer = "hlywoodh.nv"
                creado_temporal = True

        startupinfo = None
        if os.name == 'nt':
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW

        result = subprocess.run(["pinemhi.exe", rom_a_leer], capture_output=True, text=True, startupinfo=startupinfo, timeout=5)
        texto_limpio = result.stdout
        
        # Limpieza del truco temporal de Tom y Jerry
        if creado_temporal:
            import shutil
            temp_path = os.path.join(NVRAM_PATH, "hlywoodh.nv")
            try:
                if os.path.exists(temp_path):
                    os.remove(temp_path)
                if respaldo_hlywoodh and os.path.exists(respaldo_hlywoodh):
                    shutil.move(respaldo_hlywoodh, temp_path)
            except Exception as e_limpieza:
                print(f"⚠️ Error limpiando alias temporal de Tom y Jerry: {e_limpieza}")

        vistos = set()
        for linea in texto_limpio.split('\n'):
            nombres = re.findall(r'\b[A-Z]{3}\b', linea)
            if nombres:
                nombre = nombres[-1]
                numeros = re.findall(r'[\d,\.]{2,}', linea)
                if numeros:
                    score_str = numeros[-1].replace(',', '').replace('.', '')
                    if score_str.isdigit():
                        val = int(score_str)
                        if val > 10 and val not in vistos:
                            scores.append({"jugador": nombre, "puntaje": val})
                            vistos.add(val)
    except Exception as e:
        print(f"⚠️ Error ejecutando PINemHi con {nombre_archivo}: {e}")
    return scores

# ============================================================
# MESAS CONFIGURADAS (32)
# ============================================================
MESAS_CONFIG = [
    {"prefijo": "afm_",  "nombre": "Attack from Mars"},
    {"prefijo": "cc_",   "nombre": "Cactus Canyon"},
    {"prefijo": "congo_", "nombre": "Congo"},
    {"prefijo": "cftbl_", "nombre": "Creature from the Black Lagoon"},
    {"prefijo": "dh_",    "nombre": "Dirty Harry"},
    {"prefijo": "i500_",  "nombre": "Indianapolis 500"},
    {"prefijo": "jm_",    "nombre": "Johnny Mnemonic"},
    {"prefijo": "jy_",    "nombre": "Junk Yard"},
    {"prefijo": "mb_",    "nombre": "Monster Bash"},
    {"prefijo": "nbaf_",  "nombre": "NBA Fastbreak"},
    {"prefijo": "rs_",    "nombre": "Red & Ted's Road Show"},
    {"prefijo": "ss_",    "nombre": "Scared Stiff"},
    {"prefijo": "taf_",   "nombre": "The Addams Family"},
    {"prefijo": "fs_",    "nombre": "The Flintstones"},
    {"prefijo": "tz_",    "nombre": "Twilight Zone"},
    {"prefijo": "wcs_",   "nombre": "World Cup Soccer"},
    {"prefijo": "bttf_",  "nombre": "Back to the Future"},
    {"prefijo": "gldneye", "nombre": "Goldeneye"},
    {"prefijo": "gnr_",   "nombre": "Guns N' Roses"},
    {"prefijo": "hook_",  "nombre": "Hook"},
    {"prefijo": "ij",     "nombre": "Indiana Jones"},
    {"prefijo": "lah_",   "nombre": "Last Action Hero"},
    {"prefijo": "lw3_",   "nombre": "Lethal Weapon 3"},
    {"prefijo": "frankst", "nombre": "Mary Shelley's Frankenstein"},
    {"prefijo": "phantom_", "nombre": "Phantom of the Opera"},
    {"prefijo": "tmnt_",  "nombre": "Teenage Mutant Ninja Turtles"},
    {"prefijo": "fh_",    "nombre": "Funhouse"},
    {"prefijo": "pf_",    "nombre": "Police Force"},
    {"prefijo": "rescu911", "nombre": "Rescue 911"},
    {"prefijo": "tomjerry", "nombre": "Tom & Jerry"},
    {"prefijo": "mousn_",  "nombre": "Mousin'"},
    {"prefijo": "ft_",    "nombre": "Fish Tales"},
    {"prefijo": "t2_",    "nombre": "Terminator 2"},
    {"prefijo": "twd_",   "nombre": "The Walking Dead"},
    {"prefijo": "xmn_",   "nombre": "X-Men"},
    {"prefijo": "gw_",    "nombre": "The Getaway: High Speed II"},
    {"prefijo": "cycln_",  "nombre": "Cyclone"},
]

# ============================================================
# LOGICA DE SINCRONIZACION PRINCIPAL
# ============================================================
def procesar_y_subir():
    print("\n--- INICIANDO ESCANEO DE MEMORIA CON PINEMHI ---")
    nuevos_puntajes = []
    
    # Cargar récords base para ignorar (Formato nuevo/viejo auto-detectable)
    current_user = os.environ.get('USERNAME', '').lower()
    if not current_user:
        try:
            current_user = os.getlogin().lower()
        except Exception:
            current_user = "unknown"

    base_records = {"baselined_tables": [], "signatures": [], "machine_user": current_user}
    clon_detectado = False
    if os.path.exists("base_records.json"):
        try:
            with open("base_records.json", "r") as f:
                data = json.load(f)
                if isinstance(data, list):
                    base_records["signatures"] = data
                    # Convertir formato antiguo
                    mesas_con_firmas = set()
                    for sig in data:
                        partes = sig.split('-')
                        if partes:
                            mesas_con_firmas.add(partes[0])
                    base_records["baselined_tables"] = list(mesas_con_firmas)
                    base_records["machine_user"] = current_user
                    modificado_base_records = True
                elif isinstance(data, dict):
                    base_records = data
                    saved_user = base_records.get("machine_user")
                    if saved_user and saved_user != current_user:
                        print(f"🔄 ¡Detección de máquina clonada! El usuario anterior era '{saved_user}' y el actual es '{current_user}'.")
                        clon_detectado = True
                        base_records["machine_user"] = current_user
                        # Forzar re-baselineado completo: vaciamos las mesas registradas para que se registren todas de nuevo con sus valores actuales
                        base_records["baselined_tables"] = []
                        modificado_base_records = True
                    elif not saved_user:
                        base_records["machine_user"] = current_user
                        modificado_base_records = True
            if not clon_detectado:
                print(f"✅ Filtro activado: {len(base_records.get('baselined_tables', []))} mesas inicializadas, ignorando {len(base_records.get('signatures', []))} récords base.")
        except Exception as e:
            print(f"⚠️ Error al leer base_records.json, se creara uno nuevo: {e}")
    else:
        print("📋 No se encontro base_records.json. Se creara y actualizara automaticamente.")
    
    modificado_base_records = False
            
    # DIAGNOSTICO: Verificamos la carpeta base
    if not os.path.exists(NVRAM_PATH):
        print(f"⚠️ ATENCION: La carpeta {NVRAM_PATH} NO EXISTE en esta maquina.")
    
    archivos_encontrados = 0
    for mesa in MESAS_CONFIG:
        archivos = glob.glob(os.path.join(NVRAM_PATH, mesa["prefijo"] + "*.nv"))
        if archivos:
            filepath = max(archivos, key=os.path.getmtime)
            archivo_base = os.path.basename(filepath)
            archivos_encontrados += 1
            scores = leer_con_pinemhi(archivo_base) 
            if not scores:
                print(f"⚠️ Pinemhi no devolvio puntajes para: {archivo_base}")
                continue
                
            # Si esta mesa no ha sido baselineada, la registramos ahora mismo como línea base
            if mesa["nombre"] not in base_records.get("baselined_tables", []):
                print(f"📋 Registrando linea base automatica para la mesa: {mesa['nombre']}")
                for s in scores:
                    # Si es un clon detectado, bloqueamos ABSOLUTAMENTE TODOS los puntajes actuales (incluyendo reales)
                    # para evitar que la máquina clonada suba puntajes del dueño anterior.
                    if not clon_detectado:
                        if s["jugador"] in ["HER", "ARI", "LAL", "AGU"]:
                            continue
                    firma = f"{mesa['nombre']}-{s['jugador']}-{s['puntaje']}"
                    if firma not in base_records["signatures"]:
                        base_records["signatures"].append(firma)
                if "baselined_tables" not in base_records:
                    base_records["baselined_tables"] = []
                base_records["baselined_tables"].append(mesa["nombre"])
                modificado_base_records = True
            
            for s in scores:
                
                # 1. Filtrar iniciales de fábrica globalmente conocidas (lista negra)
                if s["jugador"] in DEFAULT_INITIALS:
                    continue
                
                # 2. Comprobar si es un récord de máquina baselined locally (por si acaso)
                firma = f"{mesa['nombre']}-{s['jugador']}-{s['puntaje']}"
                if firma in base_records.get("signatures", []):
                    continue # Lo ignoramos
                
                siglas = "".join([p[0].upper() for p in mesa["nombre"].split()][:2])
                id_unico = f"{siglas}-{s['jugador']}-{s['puntaje']}"
                nuevos_puntajes.append({
                    "ID_Record": id_unico, "Mesa": mesa["nombre"], 
                    "Jugador": s["jugador"], "Puntaje": s["puntaje"], "Fecha": datetime.now().strftime("%Y-%m-%d")
                })

    if modificado_base_records:
        try:
            with open("base_records.json", "w") as f:
                json.dump(base_records, f, indent=4)
            print("💾 Archivo base_records.json guardado de forma automatica.")
        except Exception as e:
            print(f"⚠️ No se pudo escribir base_records.json: {e}")

    if archivos_encontrados == 0:
        print("🤷‍♂️ No se encontro NINGUN archivo .nv de las mesas configuradas.")
    elif not nuevos_puntajes: 
        print("🤷‍♂️ No hay nuevos récords detectados localmente (todos pertenecen a la linea base).")

    try:
        print("\n☁️ Conectando a Supabase...")
        headers = {
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Content-Type": "application/json"
        }

        # 1. Leer lo que ya hay en la base de datos
        req_get = urllib.request.Request(f"{SUPABASE_URL}?select=*", headers=headers)
        with urllib.request.urlopen(req_get) as response:
            existentes = json.loads(response.read().decode())
        
        ids_nube = {r["id_record"] for r in existentes} if existentes else set()

        # --- DETECTAR ELIMINADOS DE LA NUBE PARA LISTA NEGRA AUTOMATICA ---
        historial_nube = []
        if os.path.exists("historial_nube.json"):
            try:
                with open("historial_nube.json", "r") as f:
                    historial_nube = json.load(f)
            except Exception as e:
                print(f"⚠️ Error al leer historial_nube.json: {e}")

        firmas_nuevas_blacklist = set()
        if historial_nube:
            ids_historial = {r["id_record"] for r in historial_nube}
            ids_eliminados = ids_historial - ids_nube
            
            # Evitar blacklisteado masivo si se hizo un RESET completo de la nube
            es_reset_total = (len(ids_eliminados) == len(ids_historial) and len(ids_historial) > 1)
            
            if ids_eliminados and not es_reset_total:
                print(f"🧹 Detectados {len(ids_eliminados)} récords eliminados manualmente de la nube.")
                modificado_base_records_local = False
                for r_hist in historial_nube:
                    if r_hist["id_record"] in ids_eliminados:
                        # Reconstruir la firma para la lista negra
                        mesa_nombre = r_hist.get("mesa")
                        jugador = r_hist.get("jugador")
                        puntaje = r_hist.get("puntaje")
                        if mesa_nombre and jugador and puntaje:
                            # Los jugadores reales autorizados NUNCA deben ser añadidos a la lista negra
                            if jugador in ["HER", "ARI", "LAL", "AGU"]:
                                continue
                            firma = f"{mesa_nombre}-{jugador}-{puntaje}"
                            firmas_nuevas_blacklist.add(firma)
                            if "signatures" not in base_records:
                                base_records["signatures"] = []
                            if firma not in base_records["signatures"]:
                                base_records["signatures"].append(firma)
                                print(f"🚫 Agregado a lista negra (base_records): {firma}")
                                modificado_base_records_local = True
                
                if modificado_base_records_local:
                    try:
                        with open("base_records.json", "w") as f:
                            json.dump(base_records, f, indent=4)
                        print("💾 Archivo base_records.json actualizado con la lista negra.")
                    except Exception as e:
                        print(f"⚠️ No se pudo guardar base_records.json: {e}")

        # (Se pospone la notificacion de WhatsApp hasta definir el Top 5 real)

        # 3. Combinar datos y filtrar el Top 5
        # Filtramos de nuevos_puntajes cualquier firma que esté en la lista negra o recién detectada
        nuevos_puntajes_filtrados = []
        for d in nuevos_puntajes:
            firma_d = f"{d['Mesa']}-{d['Jugador']}-{d['Puntaje']}"
            if firma_d in base_records.get("signatures", []) or firma_d in firmas_nuevas_blacklist:
                continue
            nuevos_puntajes_filtrados.append(d)

        mapa_existentes = {r["id_record"]: r for r in existentes} if existentes else {}
        mapa_final = {}
        for d in nuevos_puntajes_filtrados:
            id_rec = d["ID_Record"]
            if id_rec in mapa_existentes:
                d["Fecha"] = mapa_existentes[id_rec]["fecha"]
            mapa_final[id_rec] = d

        if existentes:
            for r in existentes:
                # Comprobar si por algún motivo está en la lista negra
                firma_r = f"{r['mesa']}-{r['jugador']}-{r['puntaje']}"
                if r["jugador"] in DEFAULT_INITIALS or firma_r in base_records.get("signatures", []) or firma_r in firmas_nuevas_blacklist:
                    continue
                if r["id_record"] not in mapa_final:
                    mapa_final[r["id_record"]] = {
                        "ID_Record": r["id_record"], "Mesa": r["mesa"], 
                        "Jugador": r["jugador"], "Puntaje": int(r["puntaje"]), "Fecha": r["fecha"]
                    }

        mesas_agrupadas = {}
        for d in mapa_final.values():
            m = d["Mesa"]
            if m not in mesas_agrupadas: mesas_agrupadas[m] = []
            mesas_agrupadas[m].append(d)

        filas_finales = []
        nuevos_top5 = [] # PARA NOTIFICAR
        for mesa_nombre, recs in mesas_agrupadas.items():
            recs.sort(key=lambda x: x["Puntaje"], reverse=True)
            for i, r in enumerate(recs[:5]): # LIMITADO AL TOP 5 GLOBAL
                pos = "Gran Campeon" if i == 0 else f"{i+1}ro"
                filas_finales.append({
                    "id_record": r["ID_Record"],
                    "mesa": r["Mesa"],
                    "posicion": pos,
                    "jugador": r["Jugador"],
                    "puntaje": r["Puntaje"],
                    "fecha": r["Fecha"]
                })
                # Notificar si este record entró al Top 5 y no estaba en la nube
                if r["ID_Record"] not in ids_nube:
                    nuevos_top5.append((r, pos))
        
        # 4. Notificar por WhatsApp de manera correcta
        if not existentes and filas_finales:
            mandar_whatsapp(f"🚀 *VP3 System:* ¡Base de datos inicializada/actualizada! Se subieron {len(filas_finales)} récords al Top 5 Global.")
        else:
            for r, pos in nuevos_top5:
                pf = f"{r['Puntaje']:,}".replace(',', '.')
                mandar_whatsapp(f"🚨 *¡NUEVO RÉCORD VP3!* 🚨\n\n🎰 Mesa: *{r['Mesa']}*\n🏅 Posición: *{pos}*\n👤 Jugador: *{r['Jugador']}*\n💥 Puntaje: *{pf}*")

        # 4. Actualizar Supabase (Borrar y reescribir para mantenerlo limpio)
        if filas_finales:
            try:
                # Intento de borrado
                req_del = urllib.request.Request(f"{SUPABASE_URL}?id_record=not.is.null", headers=headers, method="DELETE")
                urllib.request.urlopen(req_del)
            except: pass # Si la tabla estaba vacía o hay restricción, pasa largo
            
            # Inserción
            data = json.dumps(filas_finales).encode("utf-8")
            req_ins = urllib.request.Request(SUPABASE_URL, data=data, headers=headers, method="POST")
            urllib.request.urlopen(req_ins)
            
            # Guardar el nuevo estado de la nube en el historial local
            try:
                with open("historial_nube.json", "w") as f:
                    json.dump(filas_finales, f, indent=4)
                print("💾 Historial local de la nube guardado (historial_nube.json).")
            except Exception as e:
                print(f"⚠️ No se pudo guardar historial_nube.json: {e}")
        else:
            try:
                with open("historial_nube.json", "w") as f:
                    json.dump([], f, indent=4)
            except Exception as e:
                print(f"⚠️ No se pudo limpiar historial_nube.json: {e}")
        
        print(f"🚀 ¡Exito! Sincronización completa con el Top 5 Global en Supabase.")
    except Exception as e: 
        print(f"❌ Error crítico subiendo a Supabase: {e}")

def copiar_vp_alias_automatico():
    try:
        import shutil
        origen = "VPMAlias.txt"
        destino_dir = r"C:\vPinball\VisualPinball\VPinMAME"
        destino = os.path.join(destino_dir, "VPMAlias.txt")
        
        if os.path.exists(origen):
            if os.path.exists(destino_dir):
                shutil.copy2(origen, destino)
                print("📋 VPMAlias.txt copiado y actualizado automaticamente en VPinMAME.")
            else:
                print(f"⚠️ No se pudo copiar VPMAlias.txt porque la carpeta {destino_dir} no existe.")
    except Exception as e:
        print(f"⚠️ Error al copiar VPMAlias.txt automaticamente: {e}")

if __name__ == "__main__":
    print("--- VP3 SYSTEM ONLINE (SUPABASE EDITION) ---")
    copiar_vp_alias_automatico()
    tiempos_mod = {}
    procesar_y_subir()
    
    for m in MESAS_CONFIG:
        archivos = glob.glob(os.path.join(NVRAM_PATH, m["prefijo"] + "*.nv"))
        if archivos: 
            fp = max(archivos, key=os.path.getmtime)
            tiempos_mod[m["nombre"]] = os.path.getmtime(fp)
    
    while True:
        try:
            hubo_cambio = False
            for m in MESAS_CONFIG:
                archivos = glob.glob(os.path.join(NVRAM_PATH, m["prefijo"] + "*.nv"))
                if archivos:
                    fp = max(archivos, key=os.path.getmtime)
                    t = os.path.getmtime(fp)
                    if tiempos_mod.get(m["nombre"]) != t:
                        hubo_cambio = True
                        tiempos_mod[m["nombre"]] = t
            if hubo_cambio:
                print("Cambio detectado en NVRAM. Sincronizando...")
                time.sleep(2)
                procesar_y_subir()
            time.sleep(10)
        except Exception: time.sleep(10)