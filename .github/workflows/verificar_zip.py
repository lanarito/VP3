"""Mantiene MAQUINAS_VP3.zip al dia con la carpeta MAQUINAS_VP3/.

Sin argumentos: informa si el zip quedo viejo (y avisa que archivo).
Con --regenerar: actualiza el zip.

DOS COSAS IMPORTANTES QUE HAY QUE SABER ANTES DE TOCAR ESTO
-----------------------------------------------------------
1) NO todo lo que va en el zip esta en el repositorio. Hay tres archivos
   que estan en .gitignore a proposito y que viven solo en la carpeta:
   config.ini (tiene los tokens), base_records.json e historial_nube.json.
   Cuando esto corre en GitHub (una copia limpia del repositorio) esos
   archivos NO existen. Por eso el zip NO se arma de cero: se toma el que
   ya esta publicado y se le actualizan SOLO los archivos versionados que
   quedaron viejos. Asi nunca se pierde lo que no esta en el repositorio.
   (La primera version armaba el zip de cero y los borraba.)

2) Se compara CONTENIDO (hash de cada archivo), no los bytes del zip: dos
   zips con los mismos archivos adentro, hechos en Windows y en Linux, no
   son iguales byte a byte y eso no es un problema. Asi no se regenera el
   zip en cada push al pedo.

Tambien sirve a mano, desde la raiz del repositorio:
    python .github/workflows/verificar_zip.py
"""
import hashlib
import os
import shutil
import subprocess
import sys
import zipfile

CARPETA = "MAQUINAS_VP3"
ZIP = "MAQUINAS_VP3.zip"


def hash_bytes(datos):
    return hashlib.sha256(datos).hexdigest()


def versionados():
    """Rutas (relativas a MAQUINAS_VP3/) que SI estan en el repositorio."""
    r = subprocess.run(["git", "ls-files", CARPETA],
                       capture_output=True, text=True, check=True)
    salida = set()
    for linea in r.stdout.splitlines():
        linea = linea.strip()
        if linea.startswith(CARPETA + "/"):
            salida.add(linea[len(CARPETA) + 1:])
    return salida


def hash_en_disco(rel):
    ruta = os.path.join(CARPETA, rel.replace("/", os.sep))
    if not os.path.exists(ruta):
        return None
    with open(ruta, "rb") as f:
        return hash_bytes(f.read())


def hashes_del_zip():
    if not os.path.exists(ZIP):
        return None
    salida = {}
    with zipfile.ZipFile(ZIP) as z:
        for info in z.infolist():
            if info.is_dir():
                continue
            salida[info.filename.replace("\\", "/")] = hash_bytes(z.read(info))
    return salida


def diferencias():
    """(faltan, distintos) mirando SOLO los archivos versionados."""
    del_zip = hashes_del_zip()
    if del_zip is None:
        return None, None
    faltan, distintos = [], []
    for rel in sorted(versionados()):
        en_disco = hash_en_disco(rel)
        if en_disco is None:
            continue  # esta en el repo pero no en el disco: no es asunto de aca
        if rel not in del_zip:
            faltan.append(rel)
        elif del_zip[rel] != en_disco:
            distintos.append(rel)
    return faltan, distintos


def regenerar(a_actualizar):
    """Reescribe el zip copiando TODO lo que ya tenia, y reemplazando solo
    los archivos de la lista con la version del disco."""
    a_actualizar = set(a_actualizar)
    tmp = ZIP + ".nuevo"
    con_zip_previo = os.path.exists(ZIP)

    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as nuevo:
        ya_puestos = set()
        if con_zip_previo:
            with zipfile.ZipFile(ZIP) as viejo:
                for info in viejo.infolist():
                    if info.is_dir():
                        continue
                    nombre = info.filename.replace("\\", "/")
                    if nombre in a_actualizar:
                        continue  # se escribe abajo, desde el disco
                    nuevo.writestr(info, viejo.read(info))
                    ya_puestos.add(nombre)
        for rel in sorted(a_actualizar):
            ruta = os.path.join(CARPETA, rel.replace("/", os.sep))
            if os.path.exists(ruta):
                nuevo.write(ruta, rel)
                ya_puestos.add(rel)

    shutil.move(tmp, ZIP)
    print("Zip actualizado (" + str(len(a_actualizar)) + " archivos reemplazados)")


def avisar_github(clave, valor):
    ruta = os.environ.get("GITHUB_OUTPUT")
    if ruta:
        with open(ruta, "a", encoding="utf-8") as f:
            f.write(clave + "=" + valor + "\n")


def main():
    if not os.path.exists(ZIP):
        print("NO EXISTE " + ZIP + " -- hay que generarlo a mano la primera vez")
        avisar_github("desincronizado", "false")
        return 1

    faltan, distintos = diferencias()

    if "--regenerar" in sys.argv:
        pendientes = faltan + distintos
        if not pendientes:
            print("No habia nada que actualizar")
            return 0
        regenerar(pendientes)
        # Confirmar que quedo bien
        faltan2, distintos2 = diferencias()
        if faltan2 or distintos2:
            print("ERROR: despues de actualizar sigue sin coincidir: " + str(faltan2 + distintos2))
            return 1
        print("Verificado: el zip quedo al dia")
        return 0

    if not (faltan or distintos):
        print("OK: el zip esta al dia con " + CARPETA + "/")
        avisar_github("desincronizado", "false")
        return 0

    print("EL ZIP QUEDO VIEJO: no coincide con " + CARPETA + "/")
    for n in faltan:
        print("   falta en el zip    : " + n)
    for n in distintos:
        print("   version vieja en el zip: " + n)
    print()
    print("Quien actualice se bajaria una version atrasada de esos archivos.")
    avisar_github("desincronizado", "true")
    return 0


if __name__ == "__main__":
    sys.exit(main())
