import os, sys, subprocess, time, re
import urllib.request
import urllib.parse
import json
import glob
import configparser
import traceback
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
# INSTANCIA UNICA (MUTEX DE WINDOWS)
# Evita que se acumulen multiples copias en segundo plano
# que disparen mensajes repetidos a Telegram.
#
# BUG ENCONTRADO 1-sep-2026: el mutex se creaba con seguridad "por
# defecto" (CreateMutexW con el segundo parametro en None). Cuando la
# PRIMERA copia corre elevada (ej. arrancada por ACTUALIZAR_VP3.bat con
# permisos de administrador) y despues arranca una SEGUNDA copia SIN
# elevar (ej. PinUP Popper al iniciar, sin admin), esa segunda copia ni
# siquiera puede ABRIR el mutex de la primera: CreateMutexW no devuelve
# "ya existe" (codigo 183), devuelve "acceso denegado" (codigo 5) -- y
# el chequeo viejo solo sabia reconocer el 183. Confirmado con una
# prueba real: con una copia elevada corriendo, una copia sin elevar se
# colaba igual, sin que el mutex la frenara.
#
# Arreglo: crear el mutex con un descriptor de seguridad SIN
# restricciones (DACL nula = acceso para cualquiera, sea cual sea su
# nivel de privilegios). Es el patron estandar de Windows para objetos
# que se comparten entre procesos con distinta elevacion.
# ============================================================
_mutex_handle = None

def _crear_mutex_sin_restricciones(nombre):
    """Crea (o abre, si ya existe) un Mutex de Windows con un descriptor
    de seguridad permisivo, para que sirva de candado entre procesos sin
    importar el nivel de privilegios de cada uno. Devuelve (handle,
    codigo_de_error) -- handle es 0/None si fallo por completo."""
    import ctypes

    class SECURITY_ATTRIBUTES(ctypes.Structure):
        _fields_ = [
            ("nLength", ctypes.c_ulong),
            ("lpSecurityDescriptor", ctypes.c_void_p),
            ("bInheritHandle", ctypes.c_int),
        ]

    advapi32 = ctypes.windll.advapi32
    kernel32 = ctypes.windll.kernel32

    sd = ctypes.create_string_buffer(64)  # alcanza de sobra para un SECURITY_DESCRIPTOR
    SECURITY_DESCRIPTOR_REVISION = 1
    if not advapi32.InitializeSecurityDescriptor(sd, SECURITY_DESCRIPTOR_REVISION):
        return 0, kernel32.GetLastError()
    if not advapi32.SetSecurityDescriptorDacl(sd, True, None, False):
        return 0, kernel32.GetLastError()

    sa = SECURITY_ATTRIBUTES()
    sa.nLength = ctypes.sizeof(SECURITY_ATTRIBUTES)
    sa.lpSecurityDescriptor = ctypes.cast(sd, ctypes.c_void_p)
    sa.bInheritHandle = False

    handle = kernel32.CreateMutexW(ctypes.byref(sa), False, nombre)
    err = kernel32.GetLastError()
    return handle, err

def asegurar_instancia_unica():
    global _mutex_handle
    if os.name == 'nt':
        try:
            import ctypes
            mutex_name = "Global\\VP3_SubirPuntajes_SingleInstance_Mutex"
            handle, last_error = _crear_mutex_sin_restricciones(mutex_name)
            if not handle:
                # No se pudo ni crear el mutex con seguridad abierta (muy
                # raro). Mejor no bloquear el arranque del sistema por
                # esto -- intentar el modo simple de antes como ultimo
                # recurso, y si tampoco, seguir igual sin candado.
                handle = ctypes.windll.kernel32.CreateMutexW(None, False, mutex_name)
                last_error = ctypes.windll.kernel32.GetLastError()
            _mutex_handle = handle
            if last_error == 183:  # ERROR_ALREADY_EXISTS
                print("⚠️ Ya hay otra instancia de subir_puntajes corriendo. Saliendo para evitar duplicados.")
                sys.exit(0)
        except Exception:
            pass

# ============================================================
# CONFIGURACION — leída desde config.ini (nunca hardcodeada aquí)
# ============================================================
_cfg = configparser.ConfigParser()
_cfg.read(os.path.join(application_path, "config.ini"), encoding="utf-8")

NVRAM_PATH   = _cfg.get("sistema", "nvram_path",  fallback=r"C:\vPinball\VisualPinball\VPinMAME\nvram")
# Carpeta donde el enganche de core.vbs deja la memoria de la mesa EN VIVO
# (mientras se juega, sin cerrarla). Ver LECTURA_EN_VIVO.bat.
LIVE_PATH    = _cfg.get("sistema", "live_path",   fallback=r"C:\vPinball\VP3_LIVE")
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
    # Agregado 2026-08-25: defaults de fabrica en Terminator 2 (maquina nueva)
    "JCS", "AJA", "DOC", "JAS",
    # Genéricas o dummy
    "AAA", "BBB", "CCC", "DDD", "EEE", "FFF", "GGG", "HHH", "III", "JJJ",
    "KKK", "LLL", "MMM", "NNN", "OOO", "PPP", "QQQ", "RRR", "SSS", "TTT",
    "UUU", "VVV", "WWW", "XXX", "YYY", "ZZZ",
    "A A", "B B", "C C", "X Y", "WPC", "BLY", "ROM", "PIN", "GP ", "GP",
    "SYS", "BAM", "CPU", "AMD", "INT", "NV ", "NV", "HP ", "HP", "COM", "ARC"
}

# Iniciales que en ESTE grupo nunca corresponden a un jugador real, sin
# importar si el puntaje es redondo o no. A diferencia de DEFAULT_INITIALS
# (que solo bloquea puntajes redondos, para no tapar a un invitado real que
# coincida con esas iniciales), estas se confirmaron manualmente como
# siempre-de-fabrica y se bloquean directo.
SIEMPRE_FABRICA = {
    "AAA", "SLL", "MAB", "CCC", "AII",
    "A", "NF", "YW", "EB", "L", "K O", "KO", "C G", "CG", "ES", "GG",
    "MW", "P G", "PG", "R+N", "L E", "LE", "LFS", "11:", "1:", "1", "2", "3", "4", "5",
    # TOY (Cactus Canyon) y ZAB (NBA Fastbreak) subieron el 31-ago-2026:
    # tabla de fabrica nunca antes leida por el camino de disco, capturada
    # primero por la lectura en vivo (que a proposito no arma linea base,
    # ver el fix de abajo en procesar_y_subir). Ver [[project_baseline_vivo_fabrica]].
    "TOY", "ZAB"
}

# Hasta que puesto de cada mesa se avisa por Telegram (1 = solo el Gran Campeon).
# Los que quedan mas abajo se suben igual y se ven en la pagina, pero no avisan.
TOPE_AVISO = 10

# ============================================================
# CONFIGURACION DE ALERTAS (TELEGRAM)
# ============================================================
TELEGRAM_TOKEN   = _cfg.get("telegram", "token",   fallback="")
TELEGRAM_CHAT_ID = _cfg.get("telegram", "chat_id", fallback="")

def mandar_whatsapp(mensaje):
    """
    Envia alertas de records a Telegram por HTTP POST con JSON (UTF-8).
    Devuelve True si el mensaje se envio correctamente, False si hubo error.
    """
    if not TELEGRAM_TOKEN or TELEGRAM_TOKEN == "PONDRE_EL_TOKEN_AQUI" or not TELEGRAM_CHAT_ID or TELEGRAM_CHAT_ID == "PONDRE_EL_CHAT_ID_AQUI":
        try:
            print("⚠️ Telegram no configurado. Rellena las variables TELEGRAM_TOKEN y TELEGRAM_CHAT_ID en config.ini")
        except Exception:
            pass
        return False
        
    try:
        url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
        payload = json.dumps({
            "chat_id": TELEGRAM_CHAT_ID,
            "text": mensaje,
            "parse_mode": "Markdown"
        }).encode("utf-8")
        
        req = urllib.request.Request(
            url,
            data=payload,
            headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}
        )
        with urllib.request.urlopen(req, timeout=15) as response:
            res_body = response.read().decode("utf-8", errors="replace")
            res_json = json.loads(res_body)
            if res_json.get("ok"):
                try:
                    print("💬 Alerta enviada correctamente a Telegram.")
                except Exception:
                    pass
                return True
            else:
                try:
                    print(f"⚠️ Telegram devolvio error: {res_body}")
                except Exception:
                    pass
                return False
    except Exception as e:
        try:
            print(f"⚠️ Error enviando alerta a Telegram: {e}")
        except Exception:
            pass
        return False

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
# LECTURA EN VIVO
# El enganche puesto en core.vbs (activar_lectura_en_vivo.ps1, motor
# nativo UseNVRAM/NVRAMCallback) deja la memoria de la mesa en LIVE_PATH
# mientras se juega, en texto hexadecimal (escribir binario desde VBScript
# es fragil). Aca se pasa a un .nv de verdad que PINemHi sabe leer.
#
# (Se probo tambien escanear la RAM del proceso de Visual Pinball desde
# afuera, buscando la NVRAM a fuerza bruta en todo el espacio de
# direcciones del proceso. Se saco: recorrer hasta 2GB de memoria cada
# pocos segundos compite por CPU con la mesa en vivo y era la causa de
# que la maquina se pusiera lenta / se tildara. El enganche nativo en
# core.vbs ya avisa apenas cambia un byte, sin escanear nada, y es lo
# que se usa.)
# ============================================================
def identificar_mesa_por_contenido(crudo):
    """Averigua de que mesa es un volcado comparando contra los .nv reales."""
    try:
        mejor, mejor_pct = None, 0.0
        for ruta in glob.glob(os.path.join(NVRAM_PATH, "*.nv")):
            try:
                if os.path.getsize(ruta) != len(crudo):
                    continue
                with open(ruta, "rb") as f:
                    otro = f.read()
                iguales = sum(1 for a, b in zip(crudo, otro) if a == b)
                pct = iguales / float(len(crudo))
                if pct > mejor_pct:
                    mejor, mejor_pct = os.path.basename(ruta), pct
            except Exception:
                continue
        if mejor and mejor_pct >= 0.60:
            return mejor
    except Exception as e:
        print("Aviso: no pude identificar la mesa del volcado: " + str(e))
    return None


def convertir_volcados_en_vivo():
    """Devuelve la lista de .nv que cambiaron. Vacia si no hay nada nuevo."""
    convertidos = []
    try:
        if not LIVE_PATH or not os.path.isdir(LIVE_PATH):
            return convertidos
        for ruta_hex in glob.glob(os.path.join(LIVE_PATH, "*.hex")):
            try:
                with open(ruta_hex, "r", encoding="ascii", errors="ignore") as f:
                    contenido = f.read()
                rom, datos = "", ""
                for linea in contenido.splitlines():
                    linea = linea.strip()
                    if linea.lower().startswith("rom="):
                        rom = linea[4:].strip().lower()
                    elif len(linea) >= 64 and len(linea) % 2 == 0:
                        try:
                            int(linea, 16)
                            datos = linea
                        except ValueError:
                            pass
                if not datos:
                    continue
                crudo = bytes.fromhex(datos)

                # El nombre de la mesa puede venir vacio: hay maquinas (las que
                # usan B2S) donde no se puede averiguar. Entonces lo deducimos
                # comparando el volcado con los .nv reales. Asi anda en todas.
                nombre_archivo = ""
                if rom and rom != "desconocido":
                    candidato = rom + ".nv"
                    if any(candidato.startswith(m["prefijo"]) for m in MESAS_CONFIG):
                        nombre_archivo = candidato
                if not nombre_archivo:
                    detectado = identificar_mesa_por_contenido(crudo)
                    if detectado:
                        nombre_archivo = detectado
                        print("Volcado identificado por contenido: " + detectado)
                if not nombre_archivo:
                    print("Aviso: no se de que mesa es el volcado " + os.path.basename(ruta_hex))
                    continue

                destino = os.path.join(LIVE_PATH, nombre_archivo)
                anterior = None
                if os.path.exists(destino):
                    with open(destino, "rb") as f:
                        anterior = f.read()
                if anterior != crudo:
                    with open(destino, "wb") as f:
                        f.write(crudo)
                    convertidos.append(destino)
                    print("Volcado EN VIVO recibido: " + nombre_archivo + " (" + str(len(crudo)) + " bytes)")
            except Exception as e:
                print("Aviso: no pude convertir el volcado " + os.path.basename(ruta_hex) + ": " + str(e))
    except Exception as e:
        print("Aviso: error revisando la carpeta de lectura en vivo: " + str(e))
    return convertidos


def archivos_de_la_mesa(mesa):
    """Todos los .nv de una mesa: los reales y el volcado en vivo si existe.
    Devuelve pares (ruta, carpeta_origen); carpeta_origen None = NVRAM real."""
    pares = [(fp, None) for fp in glob.glob(os.path.join(NVRAM_PATH, mesa["prefijo"] + "*.nv"))]
    if LIVE_PATH and os.path.isdir(LIVE_PATH):
        for fp in glob.glob(os.path.join(LIVE_PATH, mesa["prefijo"] + "*.nv")):
            pares.append((fp, LIVE_PATH))
    return pares


def tiempos_mesa(archivos):
    """Separa el mtime mas reciente de una mesa en real / en vivo / total.
    Se usa para poder tratar distinto un cambio del .nv REAL (la mesa se
    cerro, evento raro, sincronizar siempre al toque) de un cambio que
    viene SOLO del volcado en vivo (ver COOLDOWN_VIVO en el loop principal)."""
    reales = [fp for fp, origen in archivos if origen is None]
    vivos = [fp for fp, origen in archivos if origen is not None]
    t_real = max((os.path.getmtime(fp) for fp in reales), default=None)
    t_vivo = max((os.path.getmtime(fp) for fp in vivos), default=None)
    candidatos = [t for t in (t_real, t_vivo) if t is not None]
    t_total = max(candidatos) if candidatos else None
    return t_real, t_vivo, t_total


# ============================================================
# MOTOR UNICO: PINemHi (El Salvador)
# ============================================================
def leer_con_pinemhi(nombre_archivo, carpeta_origen=None):
    """Lee los puntajes de un .nv con PINemHi.

    carpeta_origen: si viene, el archivo se toma de ahi. Se usa para el
    volcado EN VIVO que deja la mesa mientras se juega. Se copia siempre al
    area temporal; la NVRAM real no se toca nunca.
    """
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

    # Se copia al area temporal si hay alias, o si viene de otra carpeta
    # (el volcado en vivo). En los dos casos, la NVRAM real ni se toca.
    if rom_destino or carpeta_origen:
        orig_path = os.path.join(carpeta_origen or NVRAM_PATH, nombre_archivo)
        workspace = obtener_workspace_alias()
        nombre_en_workspace = (rom_destino + ".nv") if rom_destino else nombre_archivo
        if workspace and os.path.exists(orig_path):
            try:
                # La copia va al workspace temporal, NO a la carpeta de NVRAM
                copia_temporal = os.path.join(workspace, nombre_en_workspace)
                shutil.copy2(orig_path, copia_temporal)
                rom_a_leer = nombre_en_workspace
                cwd_pinemhi = workspace
                print(f"🔀 Alias: {nombre_archivo} se lee como {nombre_en_workspace} (en carpeta temporal)")
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
        IGNORAR_PALABRAS = {
            "SCORES", "CHAMPION", "BELT", "HERO", "RECORD", "GRAND", "HIGH",
            "TOP", "ACE", "BLACK", "BROWN", "BLUE", "PURPLE", "ORANGE", "YELLOW",
            "CHIEF", "DEPUTY", "SERGEANT", "PATROLMAN", "SUPER", "COMMANDER", "LIEUTENANT"
        }
        for linea in texto_limpio.splitlines():
            linea = linea.strip()
            if not linea:
                continue
            # Ignorar lineas de estadisticas secundarias (combos, loops, etc.)
            if any(linea.upper().endswith(suffix) for suffix in ["COMBOS", "WALKERS", "LOOPS", "BOATS", "TALES", "RECORD", "MULTIBALL"]):
                continue

            # Buscar patron: (Posicion opcional) (Iniciales 1 a 5 chars) (Puntaje con puntos/comas)
            m = re.search(r'^(?:(?:#|\b)?\d+[\)\.\s]+)?\s*([A-Za-z0-9_\+\.\-\s]{1,5}?)\s+([\d\.\,]{2,})\s*$', linea)
            if m:
                jugador = m.group(1).strip().upper()
                score_str = m.group(2).replace(',', '').replace('.', '').strip()
                if score_str.isdigit():
                    val = int(score_str)
                    if val > 10 and val not in vistos and jugador:
                        if jugador not in IGNORAR_PALABRAS:
                            scores.append({"jugador": jugador, "puntaje": val})
                            vistos.add(val)
                            continue

            # Fallback general si no coincidio con el regex estricto
            numeros = re.findall(r'[\d,\.]{2,}', linea)
            if numeros:
                score_str = numeros[-1].replace(',', '').replace('.', '')
                if score_str.isdigit():
                    val = int(score_str)
                    if val > 10 and val not in vistos:
                        prefix = linea[:linea.rfind(numeros[-1])].strip()
                        prefix = re.sub(r'^(?:#|\b)?\d+[\)\.\s]+', '', prefix).strip()
                        if prefix:
                            jugador = prefix.split()[-1].upper()
                            if len(jugador) <= 5 and jugador not in IGNORAR_PALABRAS:
                                scores.append({"jugador": jugador, "puntaje": val})
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
def procesar_y_subir(solo_mesas=None):
    """Escanea la NVRAM y sincroniza con Supabase.

    solo_mesas: lista de nombres de mesa. Si viene, se escanean SOLO esas
    (sincronizacion dirigida: tarda ~1 segundo en vez de recorrer las 37).
    Es seguro: los records de las demas mesas no se pierden porque igual se
    leen de la nube y todo se sube con upsert, nunca se borra nada.
    """
    if solo_mesas:
        print("\n--- ESCANEO RAPIDO: " + ", ".join(solo_mesas) + " ---")
    else:
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
    mesas_a_revisar = MESAS_CONFIG
    if solo_mesas:
        mesas_a_revisar = [m for m in MESAS_CONFIG if m["nombre"] in solo_mesas]
    for mesa in mesas_a_revisar:
        archivos = archivos_de_la_mesa(mesa)
        if archivos:
            # Puede haber mas de un archivo .nv para la misma mesa (distintas
            # versiones de ROM instaladas, ej: hook_408.nv, hook_500.nv, hook_501.nv).
            # Se leen TODOS, no solo el de fecha de modificacion mas reciente,
            # porque el puntaje real puede haber quedado grabado en cualquiera.
            archivos_encontrados += 1
            mesa_ya_baselineada = mesa["nombre"] in base_records.get("baselined_tables", [])
            scores = []
            for filepath, carpeta_origen in archivos:
                archivo_base = os.path.basename(filepath)
                scores_archivo = leer_con_pinemhi(archivo_base, carpeta_origen)
                if not scores_archivo:
                    print(f"⚠️ Pinemhi no devolvio puntajes para: {archivo_base}")
                    continue

                clave_archivo = archivo_base.lower()
                # BUG ENCONTRADO 1-sep-2026 (records "TOY"/"ZAB" que subieron
                # sin ser de nadie): antes esto decia "if carpeta_origen is
                # None" -- la linea base SOLO se establecia leyendo del .nv
                # real, nunca desde el volcado en vivo. La idea original era
                # buena (si el volcado en vivo pudiera armar linea base, el
                # primer record de un jugador real quedaria blacklisteado
                # para siempre) pero tenia un agujero: con la lectura en vivo
                # ya andando de verdad, una mesa que NUNCA se habia leido del
                # disco podia ser leida por PRIMERA VEZ por el camino en
                # vivo -- y como ese camino no arma linea base, su tabla de
                # fabrica (nombres tipo "TOY", puntajes redondos) pasaba de
                # largo sin filtrar.
                #
                # Arreglo: la linea base se arma sin importar el camino
                # (disco o vivo), pero protegiendo lo mismo que protegia
                # antes: nunca blacklistear a JUGADORES_AUTORIZADOS (records
                # reales de HER/ARI/LAL/AGU), Y ADEMAS nunca blacklistear un
                # puntaje que NO sea redondo (mismo criterio ya usado mas
                # abajo para invitados con DEFAULT_INITIALS): un numero
                # especifico es mucho mas senal de una partida real jugada
                # de verdad que de un valor de fabrica.
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
                                es_puntaje_redondo = (
                                    s['puntaje'] % 1000000 == 0 or
                                    s['puntaje'] % 500000 == 0 or
                                    s['puntaje'] % 100000 == 0
                                )
                                if not es_puntaje_redondo:
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

                # FILTRO 1.5: Iniciales confirmadas manualmente como SIEMPRE de fabrica
                # (a diferencia de FILTRO 2, bloquea sin importar si el puntaje es redondo)
                if s['jugador'] in SIEMPRE_FABRICA:
                    if firma not in base_records.get("signatures", []):
                        if "signatures" not in base_records:
                            base_records["signatures"] = []
                        base_records["signatures"].append(firma)
                        modificado_base_records = True
                    continue

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

    # ENCONTRADO 1-sep-2026 con el diagnostico real de Her (lagazo cada
    # ~10s jugando Walking Dead): esta funcion, aunque no hubiera NINGUN
    # puntaje nuevo, SIEMPRE hacia un viaje completo a Supabase -- traia
    # la tabla ENTERA de puntajes (GET) y la volvia a subir ENTERA
    # (upsert), solo para terminar sin cambiar nada. Con el enganche en
    # vivo disparando una sincronizacion dirigida (solo_mesas) cada pocos
    # segundos mientras se juega -- la mayoria de las veces por un
    # contador interno del ROM, no por un puntaje -- eso significaba un
    # ida y vuelta de red completo (GET + POST de TODA la tabla) cada
    # pocos segundos sin parar, aunque no hubiera nada que subir. Eso es
    # lo que muy probablemente generaba el lagazo periodico, mas que
    # cualquier cosa del lado de core.vbs.
    #
    # Si esto es una sincronizacion DIRIGIDA (solo_mesas, la que dispara
    # el enganche en vivo o el cierre de una mesa) y no se encontro NINGUN
    # puntaje nuevo localmente, no hace falta tocar la nube para nada --
    # se corta aca. La sincronizacion COMPLETA (solo_mesas=None: al
    # arrancar, cada 10 minutos, al apagar) sigue haciendo el viaje
    # completo siempre, como red de seguridad (detecta records borrados a
    # mano en la web, etc.).
    if solo_mesas and not nuevos_puntajes:
        print("☁️ Nada nuevo para subir -- no hace falta tocar la nube esta vez.")
        log_evento("  -> nada nuevo, NO se toco la nube (solo PINemHi local)")
        return

    if solo_mesas:
        log_evento("  -> SI hay algo nuevo, sincronizando con Supabase (GET + upsert)")

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
                # Avisar por Telegram solo hasta el puesto 10 de la mesa.
                # Mas abajo igual se sube y se ve en la pagina, pero no se
                # anuncia: si no, cualquier partida floja llena el grupo.
                # No importa quien sea el jugador (autorizados e invitados).
                if i < TOPE_AVISO and r["ID_Record"] not in ids_nube:
                    nuevos_top5.append((r, pos))
        
        # Los avisos de Telegram NO van aca: primero se guarda en Supabase
        # y recien despues se avisa. Ver mas abajo.

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

            # Ahora si: el record ya esta guardado, se puede avisar tranquilo.
            avisar_records_nuevos(nuevos_top5, not existentes, len(filas_finales))
            
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

ARCHIVO_AVISOS = "avisos_enviados.json"

def avisos_ya_enviados():
    """IDs de records que ya se anunciaron por Telegram alguna vez."""
    try:
        with open(ARCHIVO_AVISOS, "r", encoding="utf-8") as f:
            return list(json.load(f))
    except Exception:
        return []

AVISOS_ENVIADOS_MEMORIA = set(avisos_ya_enviados())


def avisar_records_nuevos(nuevos, es_primera_carga, total_filas):
    """Manda el Telegram DESPUES de que el record quedo guardado en Supabase."""
    global AVISOS_ENVIADOS_MEMORIA
    # Sincronizar memoria con lo que haya en disco
    for id_ya in avisos_ya_enviados():
        AVISOS_ENVIADOS_MEMORIA.add(id_ya)

    salto = chr(10)

    if es_primera_carga:
        mandar_whatsapp("🚀 *VP3 System:* Base de datos inicializada. Se subieron "
                        + str(total_filas) + " records.")
        return

    enviados_ahora = []
    for r, pos in nuevos:
        id_rec = r["ID_Record"]
        if id_rec in AVISOS_ENVIADOS_MEMORIA:
            print("Ya se habia avisado " + id_rec + ", no lo repito.")
            continue

        # Reservar inmediatamente en memoria para evitar duplicados en rafagas
        AVISOS_ENVIADOS_MEMORIA.add(id_rec)

        pf = format(r["Puntaje"], ",").replace(",", ".")
        mensaje = ("🚨 *¡NUEVO RÉCORD VP3!* 🚨" + salto + salto
                   + "🎰 Mesa: *" + r["Mesa"] + "*" + salto
                   + "🏅 Posición: *" + pos + "*" + salto
                   + "👤 Jugador: *" + r["Jugador"] + "*" + salto
                   + "💥 Puntaje: *" + pf + "*")
        if mandar_whatsapp(mensaje):
            enviados_ahora.append(id_rec)
        else:
            # Si fallo el envio, permitir reintento
            AVISOS_ENVIADOS_MEMORIA.discard(id_rec)

    if enviados_ahora:
        try:
            lista_disco = avisos_ya_enviados()
            for x in enviados_ahora:
                if x not in lista_disco:
                    lista_disco.append(x)
            with open(ARCHIVO_AVISOS, "w", encoding="utf-8") as f:
                json.dump(lista_disco[-500:], f, indent=2)
        except Exception as e:
            print("Aviso: no pude guardar la lista de avisos: " + str(e))


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

def log_crash_fatal(contexto=""):
    """Registra el traceback COMPLETO de un crash (no solo str(e), que
    puede quedar corto o incluso fallar al formatearse si el error trae
    algo raro adentro). Separado de log_evento a proposito: encontramos
    un caso real (maquina de Her, 31-ago/1-sep-2026) donde
    subir_puntajes.exe se cerraba solo con codigo de salida 1 cada tanto
    tiempo -- sin dejar NINGUN rastro en vp3_script_log.txt de por que --
    justo lo que hacia perder la subida instantanea de un record real.
    Esta funcion usa 'errors=replace' y traceback.format_exc() (siempre
    texto plano, nunca puede fallar al convertirse a string) para que el
    propio registro del error no pueda fallar tambien."""
    try:
        with open("vp3_crash_log.txt", "a", encoding="utf-8", errors="replace") as f:
            f.write("\n===== CRASH " + datetime.now().strftime('%Y-%m-%d %H:%M:%S') + " (" + str(contexto) + ") =====\n")
            f.write(traceback.format_exc())
            f.write("\n")
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

    # Evitar que se acumulen copias en memoria
    asegurar_instancia_unica()

    print("--- VP3 SYSTEM ONLINE (SUPABASE EDITION) ---")
    log_evento("Script iniciado")
    escribir_heartbeat("STARTING")

    try:
        copiar_vp_alias_automatico()
        tiempos_mod = {}
        tiempos_reales = {}
        vivo_ultimo_sync = {}

        # Sincronizacion inicial (procesar TODO al arrancar)
        log_evento("Sincronizacion inicial")
        procesar_y_subir()
        escribir_heartbeat("INITIAL_SYNC_OK")

        convertir_volcados_en_vivo()
        for m in MESAS_CONFIG:
            archivos = archivos_de_la_mesa(m)
            if archivos:
                # Se guarda el mtime mas reciente entre TODOS los .nv de la mesa
                # (puede haber varias versiones de ROM instaladas, y el volcado en vivo)
                t_real, _, t_total = tiempos_mesa(archivos)
                tiempos_mod[m["nombre"]] = t_total
                if t_real is not None:
                    tiempos_reales[m["nombre"]] = t_real

        print("👀 Monitoreando cambios en NVRAM... (Ctrl+C para salir)")
        log_evento("Entrando en modo monitoreo")

        # Heartbeat cada 5 minutos para verificar que esta vivo
        contador_heartbeat = 0
        # Sincronizacion forzada cada 10 minutos como red de seguridad
        contador_sync_periodico = 0

        # Cada cuanto se mira la NVRAM. El enganche nativo en core.vbs ya
        # empuja el cambio apenas se guardan las iniciales (instantaneo, sin
        # esperar este ciclo); este intervalo es solo la red de respaldo por
        # si la mesa no tiene el enganche activo o el jugador sale/apaga.
        INTERVALO = 2
        CICLOS_HEARTBEAT = 150      # 5 minutos
        CICLOS_SYNC_COMPLETO = 300  # 10 minutos

        # ENCONTRADO 1-sep-2026 con un diagnostico real de Her: mientras se
        # juega, la NVRAM de la mesa cambia todo el tiempo por cosas que NO
        # son records (bolas jugadas, auditorias, contadores internos del
        # ROM) -- no solo cuando alguien hace un puntaje nuevo. Como el
        # volcado en vivo (core.vbs) escribe cada vez que cambia CUALQUIER
        # byte, y este loop antes trataba CUALQUIER cambio del volcado en
        # vivo como motivo para correr PINemHi + Supabase, terminaba
        # sincronizando cada 5-6 segundos SIN PARAR mientras se jugaba
        # (confirmado en el log real: "Cambio detectado en disco" repetido
        # cada 5-6s durante minutos seguidos). Eso es peso real -- un
        # proceso externo (PINemHi) mas una llamada de red (Supabase) cada
        # pocos segundos -- y es lo mas probable detras del "lagazo"
        # periodico que reporto Her jugando Tortugas y Walking Dead.
        #
        # El cambio del .nv REAL (la mesa se cierra, VPinMAME escribe a
        # disco) sigue sincronizando SIEMPRE al toque -- es raro y es
        # cuando mas importa no perder tiempo. Solo el volcado EN VIVO
        # respeta un enfriamiento minimo entre sincronizaciones.
        COOLDOWN_VIVO = 5  # segundos minimos entre 2 sincronizaciones seguidas disparadas SOLO por el volcado en vivo

        while True:
            try:
                # --- 1. LECTURA EN VIVO (enganche nativo de core.vbs) ---
                convertir_volcados_en_vivo()

                # --- 2. LECTURA POR ARCHIVOS EN DISCO (SALIDA DE MESA / APAGADO) ---
                mesas_cambiadas = []
                ahora = time.time()
                for m in MESAS_CONFIG:
                    archivos = archivos_de_la_mesa(m)
                    if not archivos:
                        continue
                    t_real, _, t_total = tiempos_mesa(archivos)
                    if tiempos_mod.get(m["nombre"]) == t_total:
                        continue  # nada nuevo en esta mesa

                    cambio_real = (t_real is not None) and (tiempos_reales.get(m["nombre"]) != t_real)
                    if not cambio_real:
                        # Solo cambio el volcado en vivo: respeta el enfriamiento.
                        # Si todavia no paso, no se actualiza tiempos_mod a
                        # proposito -- asi se vuelve a intentar en el proximo
                        # ciclo (no se pierde el cambio, solo se demora un poco).
                        ultimo = vivo_ultimo_sync.get(m["nombre"], 0)
                        if (ahora - ultimo) < COOLDOWN_VIVO:
                            continue

                    mesas_cambiadas.append(m["nombre"])
                    tiempos_mod[m["nombre"]] = t_total
                    if t_real is not None:
                        tiempos_reales[m["nombre"]] = t_real
                    vivo_ultimo_sync[m["nombre"]] = ahora

                if mesas_cambiadas:
                    print("Cambio detectado en NVRAM de disco. Sincronizando...")
                    time.sleep(1)
                    # MEDIDO 1-sep-2026: se agrega el tiempo que tardo el ciclo
                    # completo al log, para saber de una vez si el peso real
                    # sigue estando aca (PINemHi + posible red) o si es otra
                    # cosa -- en vez de seguir adivinando con cada diagnostico.
                    t0 = time.time()
                    procesar_y_subir(solo_mesas=mesas_cambiadas)
                    duracion = time.time() - t0
                    log_evento(f"Cambio detectado en disco: {', '.join(mesas_cambiadas)} (tardo {duracion:.2f}s)")
                    for m_nombre in mesas_cambiadas:
                        m_cfg = next((m for m in MESAS_CONFIG if m["nombre"] == m_nombre), None)
                        if m_cfg:
                            archs = archivos_de_la_mesa(m_cfg)
                            if archs:
                                _, _, t_total = tiempos_mesa(archs)
                                tiempos_mod[m_nombre] = t_total
                    escribir_heartbeat("SYNCED")

                contador_heartbeat += 1
                if contador_heartbeat >= CICLOS_HEARTBEAT:
                    escribir_heartbeat("ALIVE")
                    contador_heartbeat = 0

                # Sincronizacion completa periodica: red de seguridad por si la
                # NVRAM cambia sin que se actualice la fecha de modificacion
                contador_sync_periodico += 1
                if contador_sync_periodico >= CICLOS_SYNC_COMPLETO:
                    log_evento("Sincronizacion periodica de seguridad (cada 10 min)")
                    procesar_y_subir()
                    escribir_heartbeat("PERIODIC_SYNC_OK")
                    contador_sync_periodico = 0

                time.sleep(INTERVALO)
            except KeyboardInterrupt:
                print("\n🛑 VP3 System detenido por el usuario.")
                log_evento("Detenido por usuario")
                escribir_heartbeat("STOPPED_BY_USER")
                break
            except BaseException:
                # BaseException (no solo Exception): asi tambien queda
                # registrado si algo raro se escapa (ver comentario en
                # log_crash_fatal). Cada paso en su propio try/except,
                # para que si UNO falla los demas igual se ejecuten.
                log_crash_fatal("bucle de monitoreo")
                try:
                    log_evento("Error en bucle de monitoreo (ver vp3_crash_log.txt)")
                except Exception:
                    pass
                try:
                    escribir_heartbeat("ERROR")
                except Exception:
                    pass
                time.sleep(10)
    except BaseException:
        log_crash_fatal("fuera del bucle (fatal)")
        try:
            print("❌ Error fatal (ver vp3_crash_log.txt)")
        except Exception:
            pass
        try:
            log_evento("ERROR FATAL (ver vp3_crash_log.txt)")
        except Exception:
            pass
        try:
            escribir_heartbeat("FATAL_ERROR")
        except Exception:
            pass
        # No salir - dormir e intentar reiniciar (el watchdog igual
        # relanza el programa apenas termine, esto es solo para no
        # reintentar en un bucle demasiado apretado)
        time.sleep(30)
