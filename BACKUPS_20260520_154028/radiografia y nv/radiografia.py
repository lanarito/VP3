import glob

# Busca todos los archivos .nv en la carpeta
archivos_nv = glob.glob("*.nv")

print("Copianos esto en el chat de VP3:\n")

for archivo in archivos_nv:
    print(f"\n{'='*50}")
    print(f" RADIOGRAFIA DE: {archivo}")
    print(f"{'='*50}\n")
    
    with open(archivo, "rb") as f:
        data = f.read()
        
    for i in range(0, len(data), 16):
        pedazo = data[i:i+16]
        hex_str = " ".join(f"{b:02X}" for b in pedazo)
        ascii_str = "".join(chr(b) if 32 <= b <= 126 else "." for b in pedazo)
        print(f"{i:04X} | {hex_str:<47} | {ascii_str}")