# ============================================================
# VP3 - ARREGLAR MESAS (v1)
#
# Aplica parches puntuales al SCRIPT interno de mesas .vpx que ya se
# encontraron rotas -- sin tocar el archivo .vpx entero (pesan cientos
# de MB, no tiene sentido distribuirlos por el actualizador). Un .vpx es
# un contenedor OLE (formato viejo, el mismo que usaban los .doc de
# Word); esto usa las mismas APIs de Windows que usa Visual Pinball para
# leer/escribir el archivo (StgOpenStorage via pythoncom), no
# manipulacion de bytes a mano sobre el contenedor.
#
# Cada parche busca un bloque de texto EXACTO dentro del script de una
# mesa puntual y lo reemplaza por una version corregida. Es
# IDEMPOTENTE y SEGURO por diseno:
#   - Si la mesa no esta instalada en esta maquina, se saltea sola.
#   - Si el parche ya esta aplicado (el texto nuevo ya esta ahi), se
#     saltea sola -- no lo aplica dos veces.
#   - Si el texto viejo no aparece EXACTO (o aparece mas de una vez),
#     se saltea con un aviso -- nunca adivina ni fuerza un cambio sobre
#     una version de mesa distinta a la que se probo.
#   - Antes de tocar el archivo real, se guarda un backup con fecha
#     (una sola vez por dia).
#
# ENCONTRADO 16-sep-2026: "The Flintstones" tira un cartel de error
# ("PinCab_Blades ... unavailable") porque su script usa un objeto de
# luces de cabinet (PinCab_Blades) sin fijarse primero si existe. La
# mayoria de las maquinas no tiene ese hardware, asi que explota.
# Probado en una copia antes de tocar el archivo real; el arreglo solo
# agrega un manejo de error alrededor de esas 2 lineas, no cambia nada
# del juego.
# ============================================================
import os
import struct
import sys
import shutil
from datetime import datetime

try:
    import pythoncom
except ImportError:
    pythoncom = None

CARPETA_TABLES = os.environ.get("VP3_TEST_TABLES") or r"C:\vPinball\VisualPinball\Tables"

STGM_READWRITE = 0x00000002
STGM_SHARE_EXCLUSIVE = 0x00000010


def parchear(ruta_vpx, viejo, nuevo):
    """Devuelve un mensaje describiendo que paso. Nunca lanza excepcion
    hacia afuera (todo queda atrapado y reportado como texto)."""
    if not os.path.exists(ruta_vpx):
        return "SALTEADO: no esta instalada en esta maquina"

    try:
        storage = pythoncom.StgOpenStorage(ruta_vpx, None, STGM_READWRITE | STGM_SHARE_EXCLUSIVE)
        gamestg = storage.OpenStorage("GameStg", None, STGM_READWRITE | STGM_SHARE_EXCLUSIVE)
        stream = gamestg.OpenStream("GameData", None, STGM_READWRITE | STGM_SHARE_EXCLUSIVE, 0)
    except Exception as e:
        return f"ERROR abriendo el archivo ({e}) -- puede estar en uso, no se toco nada"

    try:
        stat = stream.Stat(0)
        total = stat[2]
        stream.Seek(0, 0)
        data = stream.Read(total)

        idx = data.find(b"CODE")
        if idx == -1:
            return "ERROR: no se encontro el bloque CODE -- no se toco nada"
        largo = struct.unpack_from("<I", data, idx + 4)[0]
        inicio_script = idx + 8
        script = data[inicio_script:inicio_script + largo]

        # Idempotente: si el texto NUEVO ya esta, no hacer nada.
        if nuevo in script:
            return "OK: ya estaba aplicado"

        if viejo not in script:
            return "SALTEADO: no se encontro el texto esperado (version de mesa distinta), no se toco nada"
        if script.count(viejo) != 1:
            return "SALTEADO: el texto aparece mas de una vez, no se toca por seguridad"

        # Backup con fecha, una sola vez por dia, antes de tocar el archivo real.
        backup = ruta_vpx + ".VP3BACKUP_" + datetime.now().strftime("%Y%m%d")
        if not os.path.exists(backup):
            shutil.copy2(ruta_vpx, backup)

        script_nuevo = script.replace(viejo, nuevo, 1)
        nuevo_data = (
            data[:idx] + b"CODE" + struct.pack("<I", len(script_nuevo))
            + script_nuevo + data[inicio_script + largo:]
        )

        stream.SetSize(len(nuevo_data))
        stream.Seek(0, 0)
        stream.Write(nuevo_data)
        stream.Commit(0)
        gamestg.Commit(0)
        storage.Commit(0)

        return f"OK: parche aplicado ({largo} -> {len(script_nuevo)} bytes)"
    except Exception as e:
        return f"ERROR aplicando el parche ({e}) -- puede haber quedado a medio aplicar, revisar backup"


# ============================================================
# LISTA DE PARCHES CONOCIDOS
# ============================================================
PARCHES = [
    (
        "The Flintstones (Williams 1994).vpx",
        (
            b"Sub SetRails(Opt)\r\n\tSelect Case Opt\r\n\t\tCase 0:\r\n"
            b"\t\t\t'Ramp15.Visible = 0\r\n\t\t\t'Ramp16.Visible = 0\r\n"
            b"\t\t\tPinCab_Blades.visible = 1\r\n\t\tCase 1:\r\n"
            b"\t\t\t'Ramp15.Visible = 1\r\n\t\t\t'Ramp16.Visible = 1\r\n"
            b"\t\t\tPinCab_Blades.visible = 0\r\n\tEnd Select\r\nEnd Sub"
        ),
        (
            b"Sub SetRails(Opt)\r\n\tSelect Case Opt\r\n\t\tCase 0:\r\n"
            b"\t\t\t'Ramp15.Visible = 0\r\n\t\t\t'Ramp16.Visible = 0\r\n"
            b"\t\t\tOn Error Resume Next\r\n\t\t\tPinCab_Blades.visible = 1\r\n"
            b"\t\t\tOn Error Goto 0\r\n\t\tCase 1:\r\n"
            b"\t\t\t'Ramp15.Visible = 1\r\n\t\t\t'Ramp16.Visible = 1\r\n"
            b"\t\t\tOn Error Resume Next\r\n\t\t\tPinCab_Blades.visible = 0\r\n"
            b"\t\t\tOn Error Goto 0\r\n\tEnd Select\r\nEnd Sub"
        ),
    ),
]


if __name__ == "__main__":
    if pythoncom is None:
        print("ERROR CRITICO: falta el modulo pythoncom (pywin32) en este .exe")
        sys.exit(1)

    print("=== VP3 - Arreglar mesas conocidas ===")
    for nombre_archivo, viejo, nuevo in PARCHES:
        ruta = os.path.join(CARPETA_TABLES, nombre_archivo)
        resultado = parchear(ruta, viejo, nuevo)
        print(f"{nombre_archivo}: {resultado}")
    print("Listo.")
