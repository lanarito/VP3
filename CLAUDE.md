# 🎯 CONTEXTO PERMANENTE - VP3

> Este archivo se carga **automáticamente en cada chat nuevo** que se abra en esta carpeta.
> Sirve para que nunca haya que volver a explicar todo desde cero.

---

## 1. Reglas de trato

- **Hablar SIEMPRE en español.** Es obligatorio, sin excepciones.
- Trabajar de forma autónoma: no pedir confirmación para editar, compilar o publicar.
  Solo consultar si algo puede causar pérdida irreversible de datos.
- Explicar en criollo, sin jerga técnica innecesaria. Luis no es programador.

## 2. Filosofía del sistema (LA MÁS IMPORTANTE)

**Toda solución técnica DEBE integrarse en `ACTUALIZAR_VP3.bat`.**

Para los chicos siempre tiene que ser:
```
1. Doble click en "Actualizar VP3"
2. Click "SÍ" en el UAC
3. Esperar "LISTO!"
```

Nunca: archivos .bat sueltos, descargas extra, pasos manuales, ni varios popups de UAC.

## 3. Arquitectura

**Stack:** Visual Pinball X + VPinMAME → PINemHi.exe lee los `.nv` de NVRAM →
`subir_puntajes.exe` (Python + PyInstaller) → Supabase → página web en GitHub Pages → alertas por Telegram.

**Archivos críticos:**
| Archivo | Qué es |
|---|---|
| `index.html` (raíz) | Página web que sirve GitHub Pages |
| `subir_puntajes.py` / `.exe` | Sincronización de puntajes |
| `config.ini` | URLs, tokens, `NVRAM_PATH = C:\vPinball\VisualPinball\VPinMAME\nvram` |
| `base_records.json` | Línea base / lista negra de records de fábrica |
| `historial_nube.json` | Backup local de Supabase |
| `MAQUINAS_VP3/` + `.zip` | Lo que se distribuye a las máquinas |
| `ACTUALIZAR_VP3.bat` | El único botón que tocan los chicos (9 pasos) |

**Supabase:** `https://ckcjujadpmhdgcvyyahd.supabase.co` — tablas `puntajes` y `actualizaciones`.
**Web admin:** usuario `admin` (o `vp3`), password `vp3`.
**Rama de producción: `main`** (NO master). GitHub Pages sirve el `index.html` de la raíz.

**Jugadores reales:** HER (Hernán/Nacho, rosa) · ARI (Ariel, verde) · LAL (Luis, azul) · AGU (Agus, amarillo).
Cualquier otra inicial (AAA, SLL, MAB, CCC, AII, LON…) es record de fábrica → categoría `SIEMPRE_FABRICA`.

## 4. Reglas de oro (aprendidas a los golpes)

1. **NUNCA cambiar la mesa de una semana pasada o de la semana actual** en `CHALLENGE_TABLES` —
   desaparecen las copas ya ganadas. Solo semanas futuras. Las primeras 4 entradas son históricas.
2. **Nunca asumir limitaciones técnicas.** Si Luis dice algo distinto a mi análisis,
   verificar con datos reales (grep/curl/leer el archivo) antes de insistir. Él conoce su sistema.
3. **Testear antes de publicar** cualquier fix que escriba o copie archivos en la NVRAM real
   (test automatizado con hash + mtime) antes de compilar y subir.
4. **Verificar contexto antes de editar:** rama correcta, archivo correcto, hosting correcto.
5. Una mesa puede tener **varios `.nv`** (ej: `hook.nv` y `hook408.nv`). PINemHi no conoce los alias
   de VPinMAME: hay que aplicarlos a mano en una carpeta **temporal**, nunca sobre la NVRAM real.

## 5. Flujo de trabajo en cada cambio

1. Editar el fuente (`.py`, `.html`, …)
2. Recompilar el `.exe` si tocó Python
3. Actualizar `MAQUINAS_VP3/` y regenerar `MAQUINAS_VP3.zip`
4. Actualizar backup
5. `git commit` + `git push origin main`
6. Documentar en `CAMBIOS_RECIENTES.md`

## 6. Dónde está todo escrito

| Documento | Contenido |
|---|---|
| `HISTORIAL_CHATS.md` | **Todo lo hablado desde mayo 2026**, día por día |
| `CAMBIOS_RECIENTES.md` | Qué se cambió en las últimas sesiones y por qué |
| `DOCUMENTACION_SISTEMA_COMPLETA.md` | Documentación técnica del sistema |
| `TROUBLESHOOTING.md` | Problemas conocidos y sus soluciones |
| `COMO_ACTUALIZAR_FACIL.md` | Instructivo para los chicos |

Además hay memorias persistentes en
`C:\Users\luis\.claude\projects\c--Github-repos-VP3-COMPLETO\memory\` (índice en `MEMORY.md`).

---

*Si algo de acá quedó viejo, corregilo en este archivo — es la fuente de verdad de cada chat nuevo.*
