import os, sys, subprocess, time, re
import urllib.request
import urllib.parse
import json
import glob
import configparser
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
# CONFIGURACION — leída desde config.ini (nunca hardcodeada aquí)
# ============================================================
_cfg = configparser.ConfigParser()
_cfg.read(os.path.join(application_path, "config.ini"), encoding="utf-8")

NVRAM_PATH   = _cfg.get("sistema", "nvram_path",  fallback=r"C:\vPinball\VisualPinball\VPinMAME\nvram")
SUPABASE_URL = _cfg.get("supabase", "url",         fallback="")
SUPABASE_KEY = _cfg.get("supabase", "key",         fallback="")
JUGADORES_AUTORIZADOS = set(
    j.strip() for j in _cfg.get("sistema", "jugadores_autorizados", fallback="HER,ARI,LAL,AGU").split(",") if j.strip()
)

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
    # Agregados 2026-06: detectados como fabrica en Back to the Future / Walking Dead / Indianapolis 500
    "NMI", "GLV", "MDX", "EFG", "JKL", "MNO", "PQR",
    # Agregado 2026-08: defaults de fabrica en Hook (tabla hook_408 y hook_501)
    "HEC", "CNH", "PUP", "UGR", "JAY", "LAR", "DAN",
    # Agregado 2026-08: default de fabrica en Last Action Hero (puntaje redondo)
    "LON",
    # Genéricas o dummy
    "AAA", "BBB", "CCC", "DDD", "EEE", "FFF", "GGG", "HHH", "III", "JJJ",
    "KKK", "LLL", "MMM", "NNN", "OOO", "PPP", "QQQ", "RRR", "SSS", "TTT",
    "UUU", "VVV", "WWW", "XXX", "YYY", "ZZZ",
    "A A", "B B", "C C", "X Y", "WPC", "BLY", "ROM", "PIN", "GP ", "GP",
    "SYS", "BAM", "CPU", "AMD", "INT", "NV ", "NV", "HP ", "HP", "COM", "ARC"
}

# ============================================================
# CONFIGURACION DE ALERTAS (TELEGRAM)
# ============================================================
TELEGRAM_TOKEN   = _cfg.get("telegram", "token",   fallback="")
TELEGRAM_CHAT_ID = _cfg.get("telegram", "chat_id", fallback="")

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
# ALIAS DE ROMS (VPMAlias.txt) - "origen,destino" por linea.
# pinemhi.exe NO conoce estas alias (son de VPinMAME), asi que si un
# .nv no tiene rom soportada pero SI tiene alias, se lee copiandolo
# con el nombre del rom destino que pinemhi si soporta.
#
# IMPORTANTE: esa copia se hace SIEMPRE en una carpeta temporal aparte,
# NUNCA dentro de la carpeta real de NVRAM. El rom destino de una alias
# suele ser una mesa que el usuario tambien juega (ej: hook_501 ->
# hook_408), asi que escribir ahi podia pisar el archivo real justo
# cuando el juego estaba guardando un puntaje, y perderlo.
# ============================================================
def cargar_alias_vpm():
    alias_map = {}
    try:
        with open("VPMAlias.txt", "r", encoding="utf-8", errors="ignore") as f:
            for linea in f:
                linea = linea.strip()
                if not linea or "," not in linea:
                    continue
                origen, destino = linea.split(",", 1)
                alias_map[origen.strip().lower()] = destino.strip()
    except Exception:
        pass
    return alias_map

ALIAS_VPM = cargar_alias_vpm()

_ALIAS_WORKSPACE = None

def obtener_workspace_alias():
    """
    Prepara (una sola vez) una carpeta temporal con su propia copia de
    pinemhi.exe y de pinemhi.ini, con la ruta de NVRAM apuntando a esa
    misma carpeta temporal. Ahi se leen los archivos con alias, sin
    tocar jamas la carpeta real de NVRAM.
    Devuelve la ruta, o None si no se pudo preparar.
    """
    global _ALIAS_WORKSPACE
    if _ALIAS_WORKSPACE is not None:
        return _ALIAS_WORKSPACE or None

    try:
        import tempfile, shutil
        workspace = tempfile.mkdtemp(prefix="vp3_alias_")
        shutil.copy2("pinemhi.exe", os.path.join(workspace, "pinemhi.exe"))

        # pinemhi.ini propio, con VP= apuntando al workspace
        with open("pinemhi.ini", "r", encoding="utf-8", errors="ignore") as f:
            lineas = f.read().split("\n")
        salida = []
        for ln in lineas:
            if ln.startswith("VP="):
                ln = "VP=" + workspace + os.sep
            salida.append(ln)
        with open(os.path.join(workspace, "pinemhi.ini"), "w", encoding="utf-8", errors="ignore") as f:
            f.write("\n".join(salida))

        # Borrar la carpeta temporal al terminar, para no ir acumulando
        # una copia de pinemhi.exe por cada reinicio del watchdog
        import atexit
        atexit.register(lambda: shutil.rmtree(workspace, ignore_errors=True))

        _ALIAS_WORKSPACE = workspace
        return workspace
    except Exception as e:
        print(f"⚠️ No se pudo preparar el area temporal para alias: {e}")
        _ALIAS_WORKSPACE = False
        return None

# ============================================================
# MOTOR UNICO: PINemHi (El Salvador)
# ============================================================
def leer_con_pinemhi(nombre_archivo):
    scores = []
    if not os.path.exists("pinemhi.exe"):
        print("❌ ERROR CRITICO: ¡No encuentro pinemhi.exe en esta carpeta!")
        return scores

    import shutil
    # Por defecto: leer el archivo directo desde la carpeta real de NVRAM
    rom_a_leer = nombre_archivo
    cwd_pinemhi = None
    copia_temporal = None

    rom_origen = os.path.splitext(nombre_archivo)[0].lower()
    # Tom y Jerry se lee siempre via Hollywood Heat (no esta en VPMAlias.txt)
    rom_destino = "hlywoodh" if "tomjerry" in rom_origen else ALIAS_VPM.get(rom_origen)

    if rom_destino:
        orig_path = os.path.join(NVRAM_PATH, nombre_archivo)
        workspace = obtener_workspace_alias()
        if workspace and os.path.exists(orig_path):
            try:
                # La copia va al workspace temporal, NO a la carpeta de NVRAM
                copia_temporal = os.path.join(workspace, rom_destino + ".nv")
                shutil.copy2(orig_path, copia_temporal)
                rom_a_leer = rom_destino + ".nv"
                cwd_pinemhi = workspace
                print(f"🔀 Alias: {nombre_archivo} se lee como {rom_destino}.nv (en carpeta temporal)")
            except Exception as e_prep:
                print(f"⚠️ Error preparando alias ({nombre_archivo}): {e_prep}")
                copia_temporal = None
                cwd_pinemhi = None
                rom_a_leer = nombre_archivo

    try:
        startupinfo = None
        if os.name == 'nt':
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW

        if cwd_pinemhi:
            comando = [os.path.join(cwd_pinemhi, "pinemhi.exe"), rom_a_leer]
        else:
            comando = ["pinemhi.exe", rom_a_leer]

        result = subprocess.run(comando, capture_output=True, text=True, startupinfo=startupinfo, timeout=5, cwd=cwd_pinemhi)
        texto_limpio = result.stdout

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
    finally:
        # Borrar la copia temporal SIEMPRE, pase lo que pase arriba.
        # Vive en el workspace temporal, asi que aunque esto fallara no hay
        # ningun riesgo para los archivos reales de NVRAM.
        if copia_temporal:
            try:
                if os.path.exists(copia_temporal):
                    os.remove(copia_temporal)
            except Exception as e_limpieza:
                print(f"⚠️ Error limpiando copia temporal ({rom_a_leer}): {e_limpieza}")

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
    modificado_base_records = False
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
                        # Forzar re-baselineado completo: vaciamos las mesas y archivos registrados para que se registren todos de nuevo con sus valores actuales
                        base_records["baselined_tables"] = []
                        base_records["baselined_files"] = []
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
            
    # DIAGNOSTICO: Verificamos la carpeta base
    if not os.path.exists(NVRAM_PATH):
        print(f"⚠️ ATENCION: La carpeta {NVRAM_PATH} NO EXISTE en esta maquina.")
    
    # La linea base se registra por ARCHIVO, no por mesa. Antes era por mesa,
    # y eso dejaba un agujero: si aparecia un .nv nuevo de una mesa YA
    # inicializada (otra version de rom), su tabla de fabrica se salteaba el
    # filtro y entraba como records reales.
    # "migrando" = primera corrida con el esquema por archivo: los .nv que ya
    # existen se dan por cubiertos por la linea base vieja, para no volver a
    # blacklistear records de invitados que hoy son validos.
    migrando_a_por_archivo = "baselined_files" not in base_records
    if migrando_a_por_archivo:
        base_records["baselined_files"] = []
        modificado_base_records = True
    baselined_files = base_records["baselined_files"]

    archivos_encontrados = 0
    for mesa in MESAS_CONFIG:
        archivos = glob.glob(os.path.join(NVRAM_PATH, mesa["prefijo"] + "*.nv"))
        if archivos:
            # Puede haber mas de un archivo .nv para la misma mesa (distintas
            # versiones de ROM instaladas, ej: hook_408.nv, hook_500.nv, hook_501.nv).
            # Se leen TODOS, no solo el de fecha de modificacion mas reciente,
            # porque el puntaje real puede haber quedado grabado en cualquiera.
            archivos_encontrados += 1
            mesa_ya_baselineada = mesa["nombre"] in base_records.get("baselined_tables", [])
            scores = []
            for filepath in archivos:
                archivo_base = os.path.basename(filepath)
                scores_archivo = leer_con_pinemhi(archivo_base)
                if not scores_archivo:
                    print(f"⚠️ Pinemhi no devolvio puntajes para: {archivo_base}")
                    continue

                clave_archivo = archivo_base.lower()
                if clave_archivo not in baselined_files:
                    if migrando_a_por_archivo and mesa_ya_baselineada:
                        # Ya estaba cubierto por la linea base vieja (por mesa):
                        # solo lo registramos, sin volver a blacklistear nada.
                        pass
                    else:
                        # Archivo nuevo de verdad: su tabla de fabrica se
                        # registra como linea base y NO se sube como records.
                        print(f"📋 Registrando linea base automatica para: {archivo_base} ({mesa['nombre']})")
                        for s in scores_archivo:
                            # Si es un clon detectado, bloqueamos ABSOLUTAMENTE TODOS los puntajes actuales (incluyendo reales)
                            # para evitar que la máquina clonada suba puntajes del dueño anterior.
                            if not clon_detectado:
                                if s["jugador"] in JUGADORES_AUTORIZADOS:
                                    continue
                            firma = f"{mesa['nombre']}-{s['jugador']}-{s['puntaje']}"
                            if firma not in base_records["signatures"]:
                                base_records["signatures"].append(firma)
                    baselined_files.append(clave_archivo)
                    modificado_base_records = True

                scores.extend(scores_archivo)
            if not scores:
                continue

            # Se mantiene baselined_tables por compatibilidad con el formato viejo
            if not mesa_ya_baselineada:
                if "baselined_tables" not in base_records:
                    base_records["baselined_tables"] = []
                base_records["baselined_tables"].append(mesa["nombre"])
                modificado_base_records = True

            for s in scores:

                # FILTRO 1: Lista negra dinamica (records de fabrica ya identificados)
                firma = f"{mesa['nombre']}-{s['jugador']}-{s['puntaje']}"
                if firma in base_records.get("signatures", []):
                    continue # Es de fabrica conocido, lo ignoramos

                # FILTRO 2: Iniciales de fabrica con puntajes sospechosos
                # Solo bloquea si las iniciales son de fabrica Y el puntaje parece de fabrica
                # (numeros redondos como 1.000.000, 5.000.000, etc.)
                # Asi un invitado real con iniciales RAY/BLS/etc puede subir su record
                # con puntaje especifico (ej: 3.458.950) sin problema
                if s['jugador'] in DEFAULT_INITIALS:
                    # Detectar puntajes "redondos" tipicos de fabrica
                    es_puntaje_redondo = (
                        s['puntaje'] % 1000000 == 0 or  # Multiplo de 1M
                        s['puntaje'] % 500000 == 0 or   # Multiplo de 500K
                        s['puntaje'] % 100000 == 0      # Multiplo de 100K
                    )
                    if es_puntaje_redondo:
                        # Auto-agregar a signatures para futuro
                        if firma not in base_records.get("signatures", []):
                            if "signatures" not in base_records:
                                base_records["signatures"] = []
                            base_records["signatures"].append(firma)
                            modificado_base_records = True
                        continue # Es probablemente de fabrica
                    # Si NO es puntaje redondo, dejarlo pasar (probablemente jugador real)

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
        with urllib.request.urlopen(req_get, timeout=10) as response:
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
                            if jugador in JUGADORES_AUTORIZADOS:
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
                if firma_r in base_records.get("signatures", []) or firma_r in firmas_nuevas_blacklist:
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
            # SUBIR TODOS LOS REGISTROS VÁLIDOS (sin límite de Top 5)
            # El filtrado al Top 5 se hará en la web (JavaScript)
            for i, r in enumerate(recs):
                # Asignar posición: Top 5 obtiene posición en Supabase
                if i < 5:
                    pos = "Gran Campeon" if i == 0 else f"{i+1}ro"
                else:
                    # Registros fuera del Top 5 se guardan con su posición real pero son opcionales en la web
                    pos = f"{i+1}to"

                filas_finales.append({
                    "id_record": r["ID_Record"],
                    "mesa": r["Mesa"],
                    "posicion": pos,
                    "jugador": r["Jugador"],
                    "puntaje": r["Puntaje"],
                    "fecha": r["Fecha"]
                })
                # Notificar TODOS los records nuevos (autorizados + invitados)
                # sin importar posicion ni quien sea el jugador
                if r["ID_Record"] not in ids_nube:
                    nuevos_top5.append((r, pos))
        
        # 4. Notificar por WhatsApp de manera correcta
        if not existentes and filas_finales:
            mandar_whatsapp(f"🚀 *VP3 System:* ¡Base de datos inicializada/actualizada! Se subieron {len(filas_finales)} récords al Top 5 Global.")
        else:
            for r, pos in nuevos_top5:
                pf = f"{r['Puntaje']:,}".replace(',', '.')
                mandar_whatsapp(f"🚨 *¡NUEVO RÉCORD VP3!* 🚨\n\n🎰 Mesa: *{r['Mesa']}*\n🏅 Posición: *{pos}*\n👤 Jugador: *{r['Jugador']}*\n💥 Puntaje: *{pf}*")

        # 4. Actualizar Supabase (Upsert seguro: primero actualizar, luego limpiar sobrantes)
        if filas_finales:
            # Upsert: inserta o actualiza según id_record — si falla la limpieza posterior, no se pierde nada
            headers_upsert = {**headers, "Prefer": "resolution=merge-duplicates"}
            data = json.dumps(filas_finales).encode("utf-8")
            req_ups = urllib.request.Request(SUPABASE_URL, data=data, headers=headers_upsert, method="POST")
            urllib.request.urlopen(req_ups, timeout=10)

            # IMPORTANTE: Se suben TODOS los registros válidos a Supabase
            # El filtrado al Top 5 se realiza en el lado del cliente (web)
            # Esto asegura que no se pierdan registros de jugadores válidos
            print(f"✅ Supabase sincronizado con {len(filas_finales)} registros totales")
            
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

def escribir_heartbeat(estado="ALIVE"):
    """Escribe archivo de heartbeat para saber que el script esta vivo"""
    try:
        with open("vp3_heartbeat.txt", "w") as f:
            f.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | {estado}\n")
    except Exception:
        pass

def log_evento(mensaje):
    """Loguea eventos importantes con timestamp en archivo persistente"""
    try:
        with open("vp3_script_log.txt", "a", encoding="utf-8") as f:
            f.write(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {mensaje}\n")
    except Exception:
        pass

if __name__ == "__main__":
    if "--sync-once" in sys.argv:
        # Modo usado por el script de apagado de Windows: una sola pasada
        # de sincronizacion y listo (sin loop), para no demorar el apagado.
        log_evento("Sincronizacion forzada antes de apagar (shutdown script)")
        try:
            procesar_y_subir()
            escribir_heartbeat("SHUTDOWN_SYNC_OK")
        except Exception as e:
            log_evento(f"Error en sincronizacion de apagado: {e}")
            escribir_heartbeat(f"SHUTDOWN_SYNC_ERROR: {e}")
        sys.exit(0)

    print("--- VP3 SYSTEM ONLINE (SUPABASE EDITION) ---")
    log_evento("Script iniciado")
    escribir_heartbeat("STARTING")

    try:
        copiar_vp_alias_automatico()
        tiempos_mod = {}

        # Sincronizacion inicial (procesar TODO al arrancar)
        log_evento("Sincronizacion inicial")
        procesar_y_subir()
        escribir_heartbeat("INITIAL_SYNC_OK")

        for m in MESAS_CONFIG:
            archivos = glob.glob(os.path.join(NVRAM_PATH, m["prefijo"] + "*.nv"))
            if archivos:
                # Se guarda el mtime mas reciente entre TODOS los .nv de la mesa
                # (puede haber varias versiones de ROM instaladas)
                tiempos_mod[m["nombre"]] = max(os.path.getmtime(fp) for fp in archivos)

        print("👀 Monitoreando cambios en NVRAM... (Ctrl+C para salir)")
        log_evento("Entrando en modo monitoreo")

        # Heartbeat cada 5 minutos para verificar que esta vivo
        contador_heartbeat = 0
        # Sincronizacion forzada cada 10 minutos como red de seguridad
        contador_sync_periodico = 0

        while True:
            try:
                hubo_cambio = False
                for m in MESAS_CONFIG:
                    archivos = glob.glob(os.path.join(NVRAM_PATH, m["prefijo"] + "*.nv"))
                    if archivos:
                        t = max(os.path.getmtime(fp) for fp in archivos)
                        if tiempos_mod.get(m["nombre"]) != t:
                            hubo_cambio = True
                            tiempos_mod[m["nombre"]] = t

                if hubo_cambio:
                    print("Cambio detectado en NVRAM. Sincronizando...")
                    log_evento("Cambio detectado en NVRAM - sincronizando")
                    time.sleep(2)
                    procesar_y_subir()
                    escribir_heartbeat("SYNCED")

                # Heartbeat cada 30 ciclos (5 minutos aprox)
                contador_heartbeat += 1
                if contador_heartbeat >= 30:
                    escribir_heartbeat("ALIVE")
                    contador_heartbeat = 0

                # Sincronizacion forzada cada 60 ciclos (10 minutos aprox)
                # Red de seguridad por si NVRAM cambia sin actualizar mtime
                contador_sync_periodico += 1
                if contador_sync_periodico >= 60:
                    log_evento("Sincronizacion periodica de seguridad (cada 10 min)")
                    procesar_y_subir()
                    escribir_heartbeat("PERIODIC_SYNC_OK")
                    contador_sync_periodico = 0

                time.sleep(10)
            except KeyboardInterrupt:
                print("\n🛑 VP3 System detenido por el usuario.")
                log_evento("Detenido por usuario")
                escribir_heartbeat("STOPPED_BY_USER")
                break
            except Exception as e:
                log_evento(f"Error en bucle de monitoreo: {e}")
                escribir_heartbeat(f"ERROR: {e}")
                time.sleep(10)
    except Exception as e:
        print(f"❌ Error fatal: {e}")
        log_evento(f"ERROR FATAL: {e}")
        escribir_heartbeat(f"FATAL_ERROR: {e}")
        # No salir - dormir e intentar reiniciar
        time.sleep(30)
