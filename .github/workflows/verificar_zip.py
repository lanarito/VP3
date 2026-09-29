"""Compara MAQUINAS_VP3.zip contra la carpeta MAQUINAS_VP3/.

Sin argumentos: informa si estan desincronizados (y avisa por que).
Con --regenerar: reconstruye el zip desde la carpeta.

Compara CONTENIDO (hash de cada archivo), no bytes del zip: dos zips con
los mismos archivos adentro pero hechos en Windows y en Linux no son
iguales byte a byte, y eso no es un problema. Asi el workflow no se pone
a regenerar el zip en cada push sin necesidad.

Se usa desde .github/workflows/verificar-zip.yml, pero tambien sirve a
mano: `python .github/workflows/verificar_zip.py` desde la raiz del repo.
"""
import hashlib
import os
import sys
import zipfile

CARPETA = "MAQUINAS_VP3"
ZIP = "MAQUINAS_VP3.zip"


def hash_bytes(datos):
    return hashlib.sha256(datos).hexdigest()


def archivos_de_la_carpeta():
    """{ruta relativa con / : hash} de todo lo que hay en MAQUINAS_VP3/."""
    salida = {}
    for raiz, _, archivos in os.walk(CARPETA):
        for a in archivos:
            completo = os.path.join(raiz, a)
            rel = os.path.relpath(completo, CARPETA).replace(os.sep, "/")
            with open(completo, "rb") as f:
                salida[rel] = hash_bytes(f.read())
    return salida


def archivos_del_zip():
    salida = {}
    if not os.path.exists(ZIP):
        return None
    with zipfile.ZipFile(ZIP) as z:
        for info in z.infolist():
            if info.is_dir():
                continue
            nombre = info.filename.replace("\\", "/")
            salida[nombre] = hash_bytes(z.read(info))
    return salida


def regenerar():
    if os.path.exists(ZIP):
        os.remove(ZIP)
    with zipfile.ZipFile(ZIP, "w", zipfile.ZIP_DEFLATED) as z:
        for raiz, _, archivos in os.walk(CARPETA):
            for a in sorted(archivos):
                completo = os.path.join(raiz, a)
                rel = os.path.relpath(completo, CARPETA).replace(os.sep, "/")
                z.write(completo, rel)
    print("Zip regenerado desde " + CARPETA + "/")


def avisar_github(clave, valor):
    """Deja el resultado para los pasos siguientes del workflow."""
    ruta = os.environ.get("GITHUB_OUTPUT")
    if ruta:
        with open(ruta, "a", encoding="utf-8") as f:
            f.write(clave + "=" + valor + "\n")


def main():
    if "--regenerar" in sys.argv:
        regenerar()
        return 0

    carpeta = archivos_de_la_carpeta()
    del_zip = archivos_del_zip()

    if del_zip is None:
        print("NO EXISTE " + ZIP)
        avisar_github("desincronizado", "true")
        return 0

    faltan = sorted(set(carpeta) - set(del_zip))
    sobran = sorted(set(del_zip) - set(carpeta))
    distintos = sorted(n for n in set(carpeta) & set(del_zip) if carpeta[n] != del_zip[n])

    if not (faltan or sobran or distintos):
        print("OK: el zip coincide con " + CARPETA + "/ (" + str(len(carpeta)) + " archivos)")
        avisar_github("desincronizado", "false")
        return 0

    print("DESINCRONIZADO: el zip no coincide con " + CARPETA + "/")
    for n in faltan:
        print("   falta en el zip     : " + n)
    for n in sobran:
        print("   sobra en el zip     : " + n)
    for n in distintos:
        print("   distinto contenido  : " + n)
    print()
    print("Esto significa que quien actualice bajaria una version vieja.")
    avisar_github("desincronizado", "true")
    return 0


if __name__ == "__main__":
    sys.exit(main())
