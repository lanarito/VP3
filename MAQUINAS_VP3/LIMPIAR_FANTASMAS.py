# ============================================================
# VP3 - LIMPIAR JUGADORES FANTASMA (uso unico, 16-sep-2026)
#
# Borra de la nube los 43 records que NO son de ningun jugador real.
# La lista esta escrita a mano aca adentro, ya revisada uno por uno:
# este programa NO decide nada por su cuenta, solo borra exactamente
# estos 43 y nada mas.
#
# De donde salieron:
#  - 36 son tablas de FABRICA que se colaron el 3 y 4 de septiembre,
#    cuando se agregaron 59 mesas nuevas (el filtro de entonces no
#    contemplaba puntajes chicos tipo 20, 25, 40 -- ya esta arreglado
#    en subir_puntajes.py, no vuelven a entrar).
#  - 7 eran partidas REALES pero con las iniciales mal grabadas
#    (E//, K;;, ASI, #4, AC, A__). Luis decidio borrarlas igual porque
#    no se puede saber de quien eran. Tambien quedaron bloqueadas en
#    subir_puntajes.py para que no vuelvan a subir.
#
# Antes de borrar pide confirmacion y guarda una copia de todo lo que
# saca, en un archivo con fecha, por si hubiera que devolver algo.
# ============================================================
import json
import os
import sys
import urllib.request
import urllib.parse
import urllib.error
import configparser
from datetime import datetime

# OJO: compilado con PyInstaller, __file__ apunta a una carpeta temporal
# (_MEI...), NO a donde esta el .exe. Por eso hay que usar sys.executable
# cuando corre congelado -- si no, no encuentra config.ini. Mismo criterio
# que usa subir_puntajes.py para su application_path.
if getattr(sys, "frozen", False):
    carpeta = os.path.dirname(sys.executable)
else:
    carpeta = os.path.dirname(os.path.abspath(__file__))

# Modo automatico: lo usa ACTUALIZAR_VP3.bat. Sin preguntas ni ENTER final,
# para que el actualizador no se quede esperando a nadie.
AUTO = "--auto" in sys.argv
_cfg = configparser.ConfigParser()
_cfg.read(os.path.join(carpeta, "config.ini"), encoding="utf-8")
SUPABASE_URL = _cfg.get("supabase", "url", fallback="").rstrip("/")
SUPABASE_KEY = _cfg.get("supabase", "key", fallback="")

# OJO: en config.ini la "url" YA es la direccion completa de la tabla
# (termina en /rest/v1/puntajes), igual que la usa subir_puntajes.py. La
# primera version de este programa le pegaba "/rest/v1/puntajes" otra vez
# y quedaba una direccion invalida: todas las consultas fallaban, la lista
# de pendientes quedaba vacia y el programa avisaba "ya estaban borrados"
# sin haber borrado nada. Por las dudas se contempla que alguna vez la url
# venga solo con el dominio.
if "/rest/v1/" in SUPABASE_URL:
    TABLA = SUPABASE_URL
else:
    TABLA = SUPABASE_URL + "/rest/v1/puntajes"

A_BORRAR = [
    {
        "id": "A-#4-4294967295",
        "j": "#4",
        "m": "AC/DC",
        "p": 4294967295
    },
    {
        "id": "A-ABC-20",
        "j": "ABC",
        "m": "AC/DC",
        "p": 20
    },
    {
        "id": "AF-LFS --20",
        "j": "LFS -",
        "m": "Attack from Mars",
        "p": 20
    },
    {
        "id": "A-G S-7000000",
        "j": "G S",
        "m": "Avengers",
        "p": 7000000
    },
    {
        "id": "A-L R-5000000",
        "j": "L R",
        "m": "Avengers",
        "p": 5000000
    },
    {
        "id": "A-J R-4000000",
        "j": "J R",
        "m": "Avengers",
        "p": 4000000
    },
    {
        "id": "A-D T-3000000",
        "j": "D T",
        "m": "Avengers",
        "p": 3000000
    },
    {
        "id": "A-P P-2000000",
        "j": "P P",
        "m": "Avengers",
        "p": 2000000
    },
    {
        "id": "BT-A__-10542090",
        "j": "A__",
        "m": "Back to the Future",
        "p": 10542090
    },
    {
        "id": "BB-SPK-40",
        "j": "SPK",
        "m": "Big Bang Bar",
        "p": 40
    },
    {
        "id": "BB-PFZ-35",
        "j": "PFZ",
        "m": "Big Bang Bar",
        "p": 35
    },
    {
        "id": "BB-TON-30",
        "j": "TON",
        "m": "Big Bang Bar",
        "p": 30
    },
    {
        "id": "BB-MNY-25",
        "j": "MNY",
        "m": "Big Bang Bar",
        "p": 25
    },
    {
        "id": "BB-BBB-20",
        "j": "BBB",
        "m": "Big Bang Bar",
        "p": 20
    },
    {
        "id": "BH-=-20",
        "j": "=",
        "m": "Big Hurt",
        "p": 20
    },
    {
        "id": "CP-22,-2026",
        "j": "22,",
        "m": "Champion Pub",
        "p": 2026
    },
    {
        "id": "FA-CIN --40",
        "j": "CIN -",
        "m": "Freddy: A Nightmare on Elm Street",
        "p": 40
    },
    {
        "id": "F-J K-900000",
        "j": "J K",
        "m": "Funhouse",
        "p": 900000
    },
    {
        "id": "GN-ASI-894934710",
        "j": "ASI",
        "m": "Guns N' Roses",
        "p": 894934710
    },
    {
        "id": "GN-E//-669782920",
        "j": "E//",
        "m": "Guns N' Roses",
        "p": 669782920
    },
    {
        "id": "GN-K;;-636229200",
        "j": "K;;",
        "m": "Guns N' Roses",
        "p": 636229200
    },
    {
        "id": "GN-#4-234196930",
        "j": "#4",
        "m": "Guns N' Roses",
        "p": 234196930
    },
    {
        "id": "H-AC-52071780",
        "j": "AC",
        "m": "Hook",
        "p": 52071780
    },
    {
        "id": "MM-0:-37",
        "j": "0:",
        "m": "Medieval Madness",
        "p": 37
    },
    {
        "id": "MM-JCD --20",
        "j": "JCD -",
        "m": "Medieval Madness",
        "p": 20
    },
    {
        "id": "PO-KEF-25",
        "j": "KEF",
        "m": "Pirates of the Caribbean",
        "p": 25
    },
    {
        "id": "PO-B-15",
        "j": "B",
        "m": "Pirates of the Caribbean",
        "p": 15
    },
    {
        "id": "RA-TO-1593",
        "j": "TO",
        "m": "Rocky and Bullwinkle",
        "p": 1593
    },
    {
        "id": "S-DGH-25",
        "j": "DGH",
        "m": "Spider-Man",
        "p": 25
    },
    {
        "id": "SM-CGB-25",
        "j": "CGB",
        "m": "Super Mario Bros",
        "p": 25
    },
    {
        "id": "TO-KOZ-9250000",
        "j": "KOZ",
        "m": "Tales of the Arabian Nights",
        "p": 9250000
    },
    {
        "id": "TO-MAX-8750000",
        "j": "MAX",
        "m": "Tales of the Arabian Nights",
        "p": 8750000
    },
    {
        "id": "TM-A__-1358470",
        "j": "A__",
        "m": "Teenage Mutant Ninja Turtles",
        "p": 1358470
    },
    {
        "id": "TW-JDB-75000000",
        "j": "JDB",
        "m": "The Walking Dead",
        "p": 75000000
    },
    {
        "id": "TW-T-40000000",
        "j": "T",
        "m": "The Walking Dead",
        "p": 40000000
    },
    {
        "id": "TW-MDK-30000000",
        "j": "MDK",
        "m": "The Walking Dead",
        "p": 30000000
    },
    {
        "id": "TW-TEK-25000000",
        "j": "TEK",
        "m": "The Walking Dead",
        "p": 25000000
    },
    {
        "id": "TW-JOS-15000000",
        "j": "JOS",
        "m": "The Walking Dead",
        "p": 15000000
    },
    {
        "id": "TW-BFB-10000000",
        "j": "BFB",
        "m": "The Walking Dead",
        "p": 10000000
    },
    {
        "id": "TW-EPC-7500000",
        "j": "EPC",
        "m": "The Walking Dead",
        "p": 7500000
    },
    {
        "id": "TW-RON-5000000",
        "j": "RON",
        "m": "The Walking Dead",
        "p": 5000000
    },
    {
        "id": "VN-ION-80",
        "j": "ION",
        "m": "Viper Night Drivin'",
        "p": 80
    },
    {
        "id": "W-=-20",
        "j": "=",
        "m": "WaterWorld",
        "p": 20
    }
]


def pedir(url, metodo="GET"):
    req = urllib.request.Request(url, method=metodo, headers={
        "apikey": SUPABASE_KEY,
        "Authorization": "Bearer " + SUPABASE_KEY,
        "Prefer": "return=minimal",
    })
    return urllib.request.urlopen(req, timeout=20)


def cerrar(codigo=0):
    if not AUTO:
        input("Apreta ENTER para cerrar...")
    raise SystemExit(codigo)


if not AUTO:
    print("=" * 62)
    print(" VP3 - LIMPIAR JUGADORES FANTASMA")
    print("=" * 62)
    print()

if not SUPABASE_URL or not SUPABASE_KEY:
    print("ERROR: no encontre config.ini al lado de este programa.")
    cerrar(1)

# Primero fijarse cuales siguen estando de verdad en la nube. Asi esto se
# puede correr todas las veces que haga falta: si ya estan borrados (por
# ejemplo, porque otra maquina actualizo antes), no hace nada y listo.
pendientes = []
sin_revisar = []
for x in A_BORRAR:
    try:
        url = TABLA + "?id_record=eq." + urllib.parse.quote(x["id"], safe="") + "&select=*"
        with pedir(url) as r:
            filas = json.loads(r.read().decode("utf-8"))
        if filas:
            x["_fila"] = filas[0]
            pendientes.append(x)
    except Exception as e:
        sin_revisar.append((x, e))

if not pendientes:
    # Distinguir "ya estaba limpio" de "no pude ni consultar". Antes las dos
    # cosas mostraban el mismo mensaje tranquilizador, y una corrida que
    # fallo entera parecia exitosa.
    if sin_revisar:
        print("ERROR: no pude consultar la nube (" + str(len(sin_revisar)) + " de " + str(len(A_BORRAR)) + " consultas fallaron).")
        print("Motivo del primero: " + str(sin_revisar[0][1]))
        print("No se borro nada. Se vuelve a intentar en la proxima actualizacion.")
        cerrar(1)
    print("Los records fantasma ya estaban borrados, no hay nada que hacer.")
    cerrar(0)

if sin_revisar:
    print("Aviso: " + str(len(sin_revisar)) + " consultas fallaron, esos quedan para la proxima.")

if not AUTO:
    print("Se van a borrar " + str(len(pendientes)) + " records que no son de nadie:")
    print()
    for x in pendientes:
        print("   " + x["j"].ljust(8) + str(x["p"]).rjust(14) + "   " + x["m"])
    print()
    print("NO se toca ningun record de HER, ARI, LAL, AGU ni MIK.")
    print()
    respuesta = input("Escribi SI y apreta ENTER para borrarlos (cualquier otra cosa cancela): ")
    if respuesta.strip().upper() != "SI":
        print()
        print("Cancelado, no se borro nada.")
        cerrar(0)
    print()

# Copia de seguridad de lo que se va a sacar, siempre (tambien en automatico).
try:
    nombre_copia = os.path.join(carpeta, "respaldo_limpieza_" + datetime.now().strftime("%Y%m%d_%H%M%S") + ".json")
    with open(nombre_copia, "w", encoding="utf-8") as f:
        json.dump([x["_fila"] for x in pendientes], f, indent=2, ensure_ascii=False)
    if not AUTO:
        print("Copia de seguridad guardada en: " + os.path.basename(nombre_copia))
        print()
except Exception as e:
    print("Aviso: no pude guardar la copia de seguridad (" + str(e) + ")")

ok = 0
fallos = 0
for x in pendientes:
    try:
        pedir(TABLA + "?id_record=eq." + urllib.parse.quote(x["id"], safe=""), "DELETE")
        ok += 1
        if not AUTO:
            print("   borrado: " + x["j"] + " (" + x["m"] + ")")
    except Exception as e:
        fallos += 1
        print("   FALLO:   " + x["j"] + " (" + x["m"] + ") -> " + str(e))

if AUTO:
    print("Limpieza: " + str(ok) + " records fantasma borrados de la nube.")
else:
    print()
    print("=" * 62)
    print(" LISTO: " + str(ok) + " borrados, " + str(fallos) + " fallaron")
    if fallos:
        print(" Los que fallaron se arreglan corriendo esto de nuevo.")
    print(" Actualiza la pagina de VP3 para ver el resultado.")
    print("=" * 62)
cerrar(0)
