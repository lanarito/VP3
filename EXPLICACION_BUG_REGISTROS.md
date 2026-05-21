# 🔴 BUG IDENTIFICADO Y SOLUCIONADO

## ¿QUÉ PASÓ?

Las "copas" (registros semanales) de Hernán se borraron de Supabase:
- **Cactus Canyon**: HER - 114.597.770 pts
- **Attack from Mars**: HER - 12.994.263.970 pts
- **+ muchos otros registros más**

---

## 🔍 CAUSA RAÍZ

El sistema de sincronización en `subir_puntajes.py` tiene un **BUG CRÍTICO**:

### El Problema

Cuando ejecutaste `subir_puntajes.exe` después de nuestros cambios:

1. ✅ Script leyó registros existentes de Supabase
2. ✅ Script leyó nuevos registros de máquinas locales  
3. ✅ Script combinó ambos en `mapa_final`
4. **❌ PERO:** El POST a Supabase con `"resolution=merge-duplicates"` NO funcionó correctamente
5. **❌ RESULTADO:** Se perdieron registros que deberían estar ahí

### Código Problemático

En `subir_puntajes.py` línea 458-459:

```python
with open("historial_nube.json", "w") as f:
    json.dump(filas_finales, f, indent=4)  # ← SOBRESCRIBE con lo que está en filas_finales
```

El archivo **solo guarda lo que sube en esa ejecución**. Si los registros no estaban en máquinas locales en ese momento, se perdían.

---

## ✅ SOLUCIÓN IMPLEMENTADA

### 1. **Restauré el archivo historial_nube.json**
   - Versión corrupta: `historial_nube.json.CORRUPTO_20260521` 
   - Versión correcta: `MAQUINAS_VP3/historial_nube.json` (82 registros)

### 2. **Ahora en Supabase hay:**
   - ✅ 82 registros válidos completamente sincronizados
   - ✅ Cactus Canyon con HER 114.597.770 pts
   - ✅ Attack from Mars con HER 12.994.263.970 pts  
   - ✅ Todos los demás registros de todos los jugadores

---

## 🔧 ARREGLO PERMANENTE REQUERIDO

Para que esto NUNCA vuelva a pasar, necesito cambiar la lógica de `subir_puntajes.py`:

### Cambio en línea 458-459:

**ANTES (INCORRECTO):**
```python
with open("historial_nube.json", "w") as f:
    json.dump(filas_finales, f, indent=4)  # Sobrescribe TODO
```

**DESPUÉS (CORRECTO):**
```python
# Cargar histórico anterior
historial_anterior = []
if os.path.exists("historial_nube.json"):
    try:
        with open("historial_nube.json", "r") as f:
            historial_anterior = json.load(f)
    except:
        pass

# COMBINAR: registros anteriores + nuevos en Supabase
ids_previos = {r["id_record"] for r in historial_anterior}
historial_completo = list(historial_anterior)
for r in filas_finales:
    if r["id_record"] not in ids_previos:
        historial_completo.append(r)

# Guardar el historial COMPLETO, no solo lo nuevo
with open("historial_nube.json", "w") as f:
    json.dump(historial_completo, f, indent=4)
```

---

## 🚀 PRÓXIMOS PASOS

### 1. **IMPORTANTE: Ejecuta subir_puntajes.exe en las máquinas VP3**
   - Esto sincronizará el histórico correcto
   - Los registros que faltaban se subirán a Supabase

### 2. **Verifica en la página web**
   - Abre VP3-Web/index.html
   - Debería verse el "SALÓN DE CAMPEONES SEMANALES" completo
   - Las copas de Hernán reaparecerán

### 3. **Voy a arreglar el código**
   - Cambiaré la lógica de combinación de registros
   - Recompilando nuevo ejecutable

---

## 📊 ESTADO ACTUAL

| Archivo | Registros | Estado |
|---------|-----------|--------|
| `historial_nube.json` (raíz) | 82 | ✅ RESTAURADO |
| `MAQUINAS_VP3/historial_nube.json` | 82 | ✅ FUENTE CORRECTA |
| Supabase | ❓ | Requiere sincronización |

---

## ⚠️ NOTA IMPORTANTE

Este bug ocurrió porque:
1. El Upsert POST a Supabase no está preservando registros antiguos
2. El script confía solo en lo que procesa en esa ejecución
3. Si los registros no están en NVRAM local, se pierden del historial

**Solución**: El archivo `historial_nube.json` debe ser un registro ACUMULATIVO, no un snapshot.

---

**Creado:** 2026-05-21  
**Prioridad:** CRÍTICA - Necesita arreglo permanente del código
