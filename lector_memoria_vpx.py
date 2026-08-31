import ctypes
from ctypes import wintypes
import os, glob, time

PROCESS_VM_READ = 0x0010
PROCESS_QUERY_INFORMATION = 0x0400

kernel32 = ctypes.windll.kernel32

class MEMORY_BASIC_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("BaseAddress", wintypes.LPVOID),
        ("AllocationBase", wintypes.LPVOID),
        ("AllocationProtect", wintypes.DWORD),
        ("RegionSize", ctypes.c_size_t),
        ("State", wintypes.DWORD),
        ("Protect", wintypes.DWORD),
        ("Type", wintypes.DWORD),
    ]

MEM_COMMIT = 0x1000
PAGE_READWRITE = 0x04
PAGE_WRITECOPY = 0x08
PAGE_EXECUTE_READWRITE = 0x40

def encontrar_proceso_vpx():
    """Devuelve (pid, nombre) del proceso de Visual Pinball si esta corriendo."""
    import subprocess
    try:
        cmd = 'tasklist /FO CSV /NH /FI "IMAGENAME eq VPinball*"'
        out = subprocess.check_output(cmd, shell=True, text=True, errors='ignore')
        for linea in out.strip().splitlines():
            partes = [p.strip('"') for p in linea.split('","')]
            if len(partes) >= 2 and partes[0].lower().startswith("vpinball"):
                try:
                    return int(partes[1]), partes[0]
                except ValueError:
                    pass
    except Exception:
        pass
    return None, None

def buscar_nvram_en_ram(pid, lista_nvrams_referencia):
    """
    Escanea la RAM de VPinball buscando coincidencias con las NVRAMs conocidas.
    Retorna dict {rom_name: (address, size, current_bytes)}
    """
    h_process = kernel32.OpenProcess(PROCESS_VM_READ | PROCESS_QUERY_INFORMATION, False, pid)
    if not h_process:
        return {}

    referencias = {}
    for ruta in lista_nvrams_referencia:
        try:
            rom = os.path.splitext(os.path.basename(ruta))[0].lower()
            with open(ruta, "rb") as f:
                data = f.read()
            if len(data) >= 512:
                referencias[rom] = {
                    "data": data,
                    "len": len(data),
                    "header": data[:32],
                    "rom": rom
                }
        except Exception:
            continue

    if not referencias:
        kernel32.CloseHandle(h_process)
        return {}

    mbi = MEMORY_BASIC_INFORMATION()
    address = 0
    max_address = 0x7FFFFFFF # 32-bit user address space

    encontrados = {}

    while address < max_address:
        res = kernel32.VirtualQueryEx(h_process, ctypes.c_void_p(address), ctypes.byref(mbi), ctypes.sizeof(mbi))
        if not res:
            break

        is_readable = mbi.State == MEM_COMMIT and (mbi.Protect & (PAGE_READWRITE | PAGE_WRITECOPY | PAGE_EXECUTE_READWRITE))
        size = mbi.RegionSize

        if is_readable and size >= 512 and size < 32 * 1024 * 1024:
            buf = (ctypes.c_char * size)()
            bytes_read = ctypes.c_size_t()
            if kernel32.ReadProcessMemory(h_process, ctypes.c_void_p(address), buf, size, ctypes.byref(bytes_read)):
                chunk = bytes(buf[:bytes_read.value])
                for rom, info in referencias.items():
                    if rom in encontrados:
                        continue
                    pos = chunk.find(info["header"])
                    if pos != -1:
                        target_len = info["len"]
                        cand = chunk[pos : pos + target_len]
                        if len(cand) == target_len:
                            ref_data = info["data"]
                            matches = sum(1 for a, b in zip(cand, ref_data) if a == b)
                            ratio = matches / float(target_len)
                            if ratio >= 0.70:
                                encontrados[rom] = {
                                    "address": address + pos,
                                    "len": target_len,
                                    "data": cand,
                                    "rom": rom
                                }

        address += mbi.RegionSize

    kernel32.CloseHandle(h_process)
    return encontrados

def leer_memoria_direccion(pid, address, size):
    """Lee un bloque especifico de memoria directamente (ultra rapido, < 0.1ms)."""
    h_process = kernel32.OpenProcess(PROCESS_VM_READ, False, pid)
    if not h_process:
        return None

    buf = (ctypes.c_char * size)()
    bytes_read = ctypes.c_size_t()
    ok = kernel32.ReadProcessMemory(h_process, ctypes.c_void_p(address), buf, size, ctypes.byref(bytes_read))
    kernel32.CloseHandle(h_process)

    if ok and bytes_read.value == size:
        return bytes(buf[:size])
    return None
