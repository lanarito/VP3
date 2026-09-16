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
# ============================================================
# IMPORTANTE - LECCION APRENDIDA 16-sep-2026 (leer antes de agregar
# cualquier parche nuevo a este archivo):
#
# Un .vpx NO es solo un contenedor de datos: adentro tiene un SELLO DE
# INTEGRIDAD (el stream "GameStg/MAC", un hash del contenido). Visual
# Pinball lo verifica al abrir la mesa. Si se cambia el script "a mano"
# sin recalcular ese sello, VPX abre igual pero tira el cartel:
#   "This file is corrupt and some data may be invalid or even
#    crashing VPX. Be careful, especially when re-saving this file."
#
# Eso fue exactamente lo que paso con "The Flintstones": el parche del
# script funciono (el cartel de PinCab_Blades se fue), pero aparecio ese
# cartel nuevo, peor que el original. Por eso ahora esta herramienta
# DESHACE ese parche en vez de aplicarlo: devuelve el script a su texto
# original, con lo cual el sello vuelve a coincidir solo y el archivo
# queda EXACTAMENTE como venia de fabrica.
#
# CONCLUSION: no volver a parchear el script de un .vpx por este camino
# hasta que se sepa recalcular el MAC. La via correcta para arreglar el
# script de una mesa es abrirla en el EDITOR de Visual Pinball y
# guardarla desde ahi -- el editor recalcula el sello solo.
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
            return "OK: ya estaba bien, no hizo falta tocar nada"

        if viejo not in script:
            return "SALTEADO: no se encontro el texto esperado (mesa distinta o ya estaba bien), no se toco nada"
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

        return f"OK: arreglado ({largo} -> {len(script_nuevo)} bytes)"
    except Exception as e:
        return f"ERROR al arreglar ({e}) -- puede haber quedado a medio hacer, revisar backup"


# ============================================================
# LISTA DE ARREGLOS
#
# Formato: (archivo, texto_a_buscar, texto_de_reemplazo)
#
# HOY esta lista tiene UNA sola entrada, y NO es un parche: es la
# MARCHA ATRAS del parche de Flintstones que se publico el 16-sep-2026
# y resulto tirar el cartel de "archivo corrupto" (ver explicacion
# arriba). Busca el texto parcheado y lo devuelve al original.
#
# Efecto en cada maquina:
#   - La que alcanzo a aplicar el parche  -> vuelve al original, el
#     cartel de "archivo corrupto" desaparece.
#   - La que nunca lo aplico              -> no encuentra el texto y no
#     toca nada (se saltea sola, sin error).
# ============================================================
PARCHES = [
    (
        "The Flintstones (Williams 1994).vpx",
        # Buscar: el script CON el parche que hay que deshacer.
        (
            b"Sub SetRails(Opt)\r\n\tSelect Case Opt\r\n\t\tCase 0:\r\n"
            b"\t\t\t'Ramp15.Visible = 0\r\n\t\t\t'Ramp16.Visible = 0\r\n"
            b"\t\t\tOn Error Resume Next\r\n\t\t\tPinCab_Blades.visible = 1\r\n"
            b"\t\t\tOn Error Goto 0\r\n\t\tCase 1:\r\n"
            b"\t\t\t'Ramp15.Visible = 1\r\n\t\t\t'Ramp16.Visible = 1\r\n"
            b"\t\t\tOn Error Resume Next\r\n\t\t\tPinCab_Blades.visible = 0\r\n"
            b"\t\t\tOn Error Goto 0\r\n\tEnd Select\r\nEnd Sub"
        ),
        # Reemplazar por: el texto ORIGINAL de fabrica de la mesa.
        (
            b"Sub SetRails(Opt)\r\n\tSelect Case Opt\r\n\t\tCase 0:\r\n"
            b"\t\t\t'Ramp15.Visible = 0\r\n\t\t\t'Ramp16.Visible = 0\r\n"
            b"\t\t\tPinCab_Blades.visible = 1\r\n\t\tCase 1:\r\n"
            b"\t\t\t'Ramp15.Visible = 1\r\n\t\t\t'Ramp16.Visible = 1\r\n"
            b"\t\t\tPinCab_Blades.visible = 0\r\n\tEnd Select\r\nEnd Sub"
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
