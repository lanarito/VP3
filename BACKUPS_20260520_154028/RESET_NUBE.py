import urllib.request
import ssl
import os
import sys
import configparser

if getattr(sys, 'frozen', False):
    _app_path = os.path.dirname(sys.executable)
else:
    _app_path = os.path.dirname(os.path.abspath(__file__))

_cfg = configparser.ConfigParser()
_cfg.read(os.path.join(_app_path, "config.ini"), encoding="utf-8")

SUPABASE_URL = _cfg.get("supabase", "url", fallback="")
SUPABASE_KEY = _cfg.get("supabase", "key", fallback="")

print("========================================")
print("   SISTEMA DE RESETEO DE LA NUBE VP3")
print("========================================")
print("¡ATENCION! Esto borrara TODOS los records actuales de la nube.")
print("Solo debes usar esto cuando todas las maquinas esten reseteadas.")
print()

confirmacion = input("¿Estas seguro que quieres BORRAR TODO? Escribe SI para continuar: ")

if confirmacion.strip().upper() == "SI":
    print("\nBorrando base de datos...")
    try:
        headers = {
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}"
        }
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        
        req_del = urllib.request.Request(f"{SUPABASE_URL}?id_record=not.is.null", headers=headers, method="DELETE")
        urllib.request.urlopen(req_del, context=ctx)
        
        print("✅ ¡EXITO! La nube ha sido limpiada por completo.")
        print("Ahora la web mostrara VACANTE en todas las mesas.")
    except Exception as e:
        print(f"❌ Error al intentar limpiar la nube: {e}")
else:
    print("\nOperacion cancelada. No se borro nada.")

input("\nPresiona ENTER para salir...")
