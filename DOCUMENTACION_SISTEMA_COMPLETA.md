# 📚 DOCUMENTACIÓN COMPLETA DEL SISTEMA VP3

**Última actualización:** 2026-05-29
**Estado:** Sistema operativo con limitación técnica documentada

---

## 🏗️ ARQUITECTURA DEL SISTEMA

### Stack tecnológico:
- **Pinball:** Visual Pinball X (VP3) + VPinMAME
- **Lectura de puntajes:** PINemHi (lee archivos NVRAM)
- **Base de datos:** Supabase (PostgreSQL)
- **Frontend:** GitHub Pages (rama `main`)
- **Backend script:** Python compilado a EXE (PyInstaller)
- **Hosting web:** https://lanarito.github.io/VP3/
- **Repo:** https://github.com/lanarito/VP3.git

### Componentes principales:

```
┌─────────────────────┐
│   MÁQUINA VP3       │
│  ┌───────────────┐  │
│  │ Visual Pinball│  │
│  │     ↓          │  │
│  │   NVRAM       │  │ ← Solo guarda Top 5 por mesa
│  └───────────────┘  │
│         ↓            │
│  subir_puntajes.exe │ ← Lee NVRAM con pinemhi.exe
│         ↓            │
└─────────┼────────────┘
          ↓
    ┌─────────────┐
    │  SUPABASE   │ ← Tabla "puntajes" y "actualizaciones"
    └─────────────┘
          ↓
    ┌─────────────┐
    │ GITHUB PAGES│ ← Lee de Supabase y muestra
    │  (main)     │
    └─────────────┘
```

---

## 📁 ESTRUCTURA DE ARCHIVOS IMPORTANTES

```
c:\Github repos\VP3 COMPLETO\
├── index.html               ← Página principal (GitHub Pages sirve este)
├── subir_puntajes.py        ← Script principal de sincronización
├── config.ini               ← Configuración (Supabase, Telegram, NVRAM_PATH)
├── historial_nube.json      ← Backup local del estado de Supabase
├── base_records.json        ← Lista negra de records de fábrica
├── MAQUINAS_VP3/            ← Carpeta que se distribuye a máquinas
│   ├── subir_puntajes.exe   ← Ejecutable compilado
│   ├── pinemhi.exe          ← Lector de NVRAM
│   ├── pinemhi.ini          ← Config de pinemhi
│   ├── config.ini           ← Config local
│   ├── RESET_NUBE.exe       ← Utilidad para resetear Supabase
│   └── historial_nube.json  ← Sync local
└── MAQUINAS_VP3.zip         ← ZIP distribuible

c:\Github repos\_BACKUPS_TODOS_PROYECTOS\VP3\
└── backup_YYYYMMDD_HHmm/    ← Backups automáticos
```

---

## 🗄️ ESQUEMA DE SUPABASE

**Tabla `puntajes`:**
```
- id_record (string)    Ej: "AF-HER-12994263970"
- mesa (string)         Ej: "Attack from Mars"
- posicion (string)     Ej: "Gran Campeon", "2ro", "3ro", "4ro", "5ro"
- jugador (string)      Ej: "HER", "LAL", "ARI", "AGU"
- puntaje (integer)     Ej: 12994263970
- fecha (date)          Ej: "2026-05-07"
```

**Tabla `actualizaciones`:**
```
- nombre_archivo
- categoria             "Mesa VPX", "Sistema completo", "ROM / NVRAM", "Otro"
- descripcion
- version
- url_descarga
- subido_por            "Hernan", "Luis"
- fecha
```

---

## 🎮 FLUJO COMPLETO DE SINCRONIZACIÓN

### Cuando el usuario juega:

```
1. JUEGA en mesa VP3 (ej: Black Lagoon)
   ↓
2. TERMINA partida con puntaje X
   ↓
3. VP3 COMPARA con Top 5 histórico de esa mesa
   ↓
4a. SI X > 5to lugar → VP3 pide iniciales → guarda en NVRAM
4b. SI X <= 5to lugar → VP3 DESCARTA el puntaje (no lo guarda)
   ↓
5. NVRAM tiene actualizado el Top 5 (solo si fue caso 4a)
```

### Cuando se ejecuta `subir_puntajes.exe`:

```
1. AL ENCENDER LA MÁQUINA (automático)
   ↓
2. Carga config.ini (URL Supabase, token Telegram, NVRAM path)
   ↓
3. Para cada mesa en MESAS_CONFIG:
   a. Busca archivo .nv en NVRAM_PATH
   b. Ejecuta pinemhi.exe sobre ese archivo
   c. Parsea Top 5 + iniciales
   ↓
4. Lee historial_nube.json y base_records.json
   ↓
5. Filtra:
   - Ignora records de fábrica (DEFAULT_INITIALS)
   - Ignora records en lista negra
   - Mantiene records de jugadores autorizados (HER, ARI, LAL, AGU)
   ↓
6. Combina con records existentes en Supabase
   ↓
7. Sube TODOS los records (no solo Top 5) a Supabase
   ↓
8. Si hay nuevos Top 5 → manda mensaje Telegram
   ↓
9. Actualiza historial_nube.json
```

### Cuando se carga la página web:

```
1. GitHub Pages sirve index.html (rama main)
   ↓
2. fetchData() llama a Supabase
   ↓
3. Carga allData (todos los puntajes) y actualizacionesData
   ↓
4. Renderiza vistas:
   - 👑 Salón de la Fama: 1 card por mesa (Gran Campeón)
   - 🔥 Desafío Semanal: Top 5 de mesa que toca esa semana
   - 📊 Ranking por Mesa: Top 5 con filtro por mesa
   - 📥 Descargas: actualizacionesData
   - 🏆 Salón de Campeones Semanales: histórico de ganadores
```

---

## 🔥 LÓGICA DEL DESAFÍO SEMANAL

### Cómo se calcula:

```javascript
const baseDate = '2026-05-06';                    // Miércoles de inicio
const msPerWeek = 7 * 24 * 60 * 60 * 1000;
const weekIndex = Math.floor((now - baseDate) / msPerWeek);
const challengeTable = ALL_TABLES[weekIndex % ALL_TABLES.length];
```

### Calendario de mesas por semana:
- **Semana 1** (06-12 mayo) → Attack from Mars
- **Semana 2** (13-19 mayo) → Cactus Canyon
- **Semana 3** (20-26 mayo) → Congo
- **Semana 4** (27 may - 02 jun) → Creature from the Black Lagoon
- ... y así sucesivamente recorriendo ALL_TABLES

### Filtro del desafío:
```javascript
const weekScores = allData.filter(r =>
    r.table === challengeTable &&
    r.date >= startStr &&
    r.date < endStr
);
const winner = weekScores[0];  // El de mayor puntaje
```

**El desafío semanal NO es una tabla separada.** Es un filtro sobre la misma tabla `puntajes`.

---

## ✅ COMPORTAMIENTO REAL DEL SISTEMA (CORRECCIÓN IMPORTANTE)

### Lo que SÍ hace el sistema:

**El script captura MUCHO MÁS que el Top 5 visual de la mesa.**

Cada mesa de pinball tiene múltiples campos de hi-scores en NVRAM:
- Grand Champion (1)
- High Scores (típicamente 5)
- Buy-in Scores
- Loop Champions
- Trip Champions / Track Champions
- Combo Champions
- Y muchos más según la mesa

**pinemhi.exe lee TODOS estos campos** y el script `subir_puntajes.py` sube TODOS los puntajes que detecta a Supabase, no solo el Top 5 visual.

### Evidencia (verificado 30 mayo 2026):
**Black Lagoon tiene 14 records en Supabase**, llegando hasta posición "14to":
- Records con puntajes desde 57M hasta 202M
- Múltiples jugadores en distintas posiciones
- Todos capturados automáticamente por el script al ejecutarse

### Lo que pasa cuando jugás:
1. Hacés un puntaje (cualquiera, no necesariamente Top 5)
2. La mesa puede guardarlo en algún campo de high score (Top 5 general, buy-in, loop champion, etc.)
3. Al ejecutarse `subir_puntajes.exe`, pinemhi lee TODOS los campos
4. El script sube todos esos puntajes a Supabase
5. La página web muestra Top 5 visualmente pero TODOS los records existen

### Sistema del desafío semanal:
- Filtra de `allData` por mesa + fecha de la semana
- Como el sistema captura múltiples records por mesa, el desafío semanal funciona bien
- Si alguien hace un puntaje que cae en algún campo de high score, aparece

---

## 🛠️ SOLUCIONES DISPONIBLES PARA EL PROBLEMA TÉCNICO

### **Opción A: Sistema actual (status quo)**
- ✅ Funciona sin riesgo
- ✅ Top 5 histórico se preserva intacto
- ❌ Puntajes que no son Top 5 no cuentan para el desafío

### **Opción B: Reset NVRAM al inicio de cada semana** ⚠️
Cómo funcionaría:
1. **Miércoles 00:00:** Backup NVRAM completo de la mesa que toca esa semana → vaciar Top 5 de esa mesa
2. **Durante la semana:** Cualquier puntaje entra al Top 5 (mesa vacía) → script lo sube a Supabase → cuenta para el desafío
3. **Martes 23:59:** Lee Top 5 final del desafío → restaura NVRAM original desde backup → graba campeón semanal en histórico

Riesgos:
- ⚠️ Tocar NVRAM es delicado (binario, formato distinto por mesa)
- ⚠️ Si falla la restauración, podríamos perder el Top 5 histórico
- ⚠️ Necesita triple backup como protección

### **Opción C: Modificar mesas .vpx para que hookeen al final de partida**
- Complejo
- Requiere editar VBScript de cada mesa individualmente
- No es viable

---

## 🔧 CONFIGURACIÓN ADMIN

### Credenciales página web:
- **Usuario:** `admin` (o `vp3`, o `usuario vp3`)
- **Contraseña:** `vp3`
- **Uso:** Login para "SUBIR ACTUALIZACIÓN"
- **NOTA:** El botón "BORRAR" aparece siempre pero pide login al usarlo

### Credenciales Supabase:
- **URL:** https://ckcjujadpmhdgcvyyahd.supabase.co
- **Key pública:** En `index.html` línea ~669 y en `config.ini`

### Telegram (para alertas de records):
- **Token:** En `config.ini` sección `[telegram]`
- **Chat ID:** En `config.ini`

---

## 🏆 JUGADORES AUTORIZADOS

```python
JUGADORES_AUTORIZADOS = {"HER", "ARI", "LAL", "AGU"}
```

- **HER** = Hernán (Nacho) - color rosa (#ff007f)
- **ARI** = Ariel - color verde (#00ff66)
- **LAL** = Luis - color azul (#00c3ff)
- **AGU** = Agus - color amarillo (#ffcc00)

Cualquier otro jugador puede subir records si no está en lista negra (`base_records.json`).

---

## 📝 RESUMEN CRONOLÓGICO DE CAMBIOS RECIENTES

### Mayo 2026:
- **08/05:** Sistema inicial funcionando
- **20/05:** Restauración de records de ARI (12 records perdidos)
- **20/05:** Corregido bug crítico en `subir_puntajes.py` - el script sobrescribía `historial_nube.json` en lugar de preservar registros históricos
- **21/05:** Restauradas copas de HER en Attack from Mars y Cactus Canyon (fechas corregidas)
- **21/05:** Agregada zona de descargas con botón BORRAR (login admin/vp3)
- **21/05:** Botón BORRAR siempre visible, pide login al usarlo
- **21/05:** Removido botón "SUBIR MI RECORD" manual (el usuario quería todo automático)
- **29/05:** Investigación exhaustiva sobre desafío semanal - confirmado que NUNCA existió tabla separada
- **29/05:** Restauración masiva de fechas originales desde backup 8 mayo (14 registros corregidos)

### Records actuales destacados:
- **Attack from Mars:** HER 12,994,263,970 (Gran Campeón - Semana 1)
- **Cactus Canyon:** HER 114,597,770 (Gran Campeón - Semana 2)
- **Black Lagoon:** HER 156,286,230 (Gran Campeón - Semana 4 actual)

---

## 🤖 PROCESO DE TRABAJO ESTABLECIDO

Cada cambio en el sistema se propaga automáticamente a:

1. **Código fuente** (`*.py`, `*.html`, `*.json`)
2. **MAQUINAS_VP3/** (ejecutables compilados con PyInstaller)
3. **MAQUINAS_VP3.zip** (regenerado)
4. **_BACKUPS_TODOS_PROYECTOS/VP3/** (backup centralizado con timestamp)
5. **GitHub rama `main`** (commit + push)
6. **GitHub Pages** (deploy automático en ~1-3 minutos)

### Sin intervención manual del usuario:
- Las máquinas VP3 ejecutan `subir_puntajes.exe` automáticamente al encender
- El script sincroniza records sin que nadie haga nada
- Solo encender + jugar

---

## 🚨 PROBLEMAS CONOCIDOS Y SUS SOLUCIONES

### ❌ Problema: Records desaparecen de Supabase
**Causa:** Bug en `subir_puntajes.py` que sobrescribía historial.
**Solución aplicada:** Modificado para preservar registros históricos (líneas 456-475).

### ❌ Problema: Copas semanales aparecen como "VACANTE"
**Causa:** Fechas de records restaurados quedaron como fecha de restauración, fuera de la semana correcta.
**Solución aplicada:** PATCH masivo en Supabase para restaurar fechas originales desde backup.

### ❌ Problema: Puntajes que no son Top 5 no cuentan en el desafío
**Causa:** Limitación técnica de VP3 - NVRAM solo guarda Top 5.
**Estado:** Sin solución sin riesgo. Opciones documentadas en sección de Soluciones.

### ❌ Problema: GitHub Pages no muestra cambios
**Causa:** GitHub Pages sirve desde rama `main`, no `master`. Y tiene caché de 1-5 minutos.
**Solución:** Hacer push a `main` y esperar deploy. `Ctrl+Shift+R` para forzar recarga sin caché.

---

## 📡 ENDPOINTS DE SUPABASE

### Leer puntajes:
```
GET https://ckcjujadpmhdgcvyyahd.supabase.co/rest/v1/puntajes?select=*
Headers: apikey: {SUPABASE_KEY}
```

### Subir puntaje:
```
POST https://ckcjujadpmhdgcvyyahd.supabase.co/rest/v1/puntajes
Headers: apikey, Authorization Bearer, Content-Type: application/json
Body: { id_record, mesa, jugador, puntaje, posicion, fecha }
```

### Actualizar puntaje (PATCH):
```
PATCH https://.../puntajes?id_record=eq.{id}
Body: { "fecha": "2026-05-07" }
```

### Borrar puntaje:
```
DELETE https://.../puntajes?id_record=eq.{id}
```

---

## 🔮 PRÓXIMOS PASOS POSIBLES

1. **Decidir sobre Reset NVRAM:** Implementar o aceptar limitación
2. **Mejorar logs Telegram:** Diferenciar mensajes de ranking vs desafío
3. **Sistema de notificaciones:** Avisar cuando termina la semana
4. **Estadísticas avanzadas:** Por jugador, mejor mesa, racha, etc.

---

**Última verificación del sistema:** 2026-05-29
**Estado:** ✅ Operativo
**Total records en Supabase:** 86
**Total actualizaciones:** 3
