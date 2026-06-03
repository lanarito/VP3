# 📚 DOCUMENTACIÓN COMPLETA DEL SISTEMA VP3

**Última actualización:** 2026-05-30
**Estado:** ✅ Sistema operativo con watchdog automático
**Total records en Supabase:** 145
**Total actualizaciones:** 3

---

## 📑 ÍNDICE

1. [Arquitectura del sistema](#arquitectura)
2. [Estructura de archivos](#estructura)
3. [Esquema de Supabase](#esquema-supabase)
4. [Flujo completo de sincronización](#flujo-sincronizacion)
5. [Sistema Watchdog (a prueba de fallos)](#watchdog)
6. [Logs y monitoreo](#logs)
7. [Lógica del desafío semanal](#desafio-semanal)
8. [Cómo VP3 captura records (corrección importante)](#captura-records)
9. [Configuración admin](#admin)
10. [Jugadores autorizados](#jugadores)
11. [Cronología de cambios](#cronologia)
12. [Proceso de trabajo automatizado](#proceso-trabajo)
13. [Problemas conocidos y soluciones](#problemas)
14. [Endpoints Supabase](#endpoints)
15. [Lecciones aprendidas](#lecciones)
16. [Troubleshooting](#troubleshooting)

---

<a name="arquitectura"></a>
## 🏗️ ARQUITECTURA DEL SISTEMA

### Stack tecnológico:
- **Pinball:** Visual Pinball X (VP3) + VPinMAME
- **Lectura de puntajes:** PINemHi 1.3.1 (lee archivos NVRAM)
- **Base de datos:** Supabase (PostgreSQL)
- **Frontend:** GitHub Pages (rama `main`)
- **Backend script:** Python 3.14 compilado a EXE (PyInstaller)
- **Watchdog:** Batch + VBScript
- **Hosting web:** https://lanarito.github.io/VP3/
- **Repo:** https://github.com/lanarito/VP3.git

### Diagrama del sistema:

```
┌────────────────────────────────────────────┐
│           MÁQUINA VP3 (Windows)            │
│                                            │
│  Al encender Windows → shell:startup      │
│            ↓                               │
│  WATCHDOG_invisible.vbs (silencioso)      │
│            ↓                               │
│  WATCHDOG_subir_puntajes.bat              │
│            ↓                               │
│  ┌──────────────────────────────────┐    │
│  │   subir_puntajes.exe (loop)      │    │
│  │   - Sincronizacion inicial        │    │
│  │   - Monitoreo cada 10 seg         │    │
│  │   - Sync forzada cada 10 min      │    │
│  │   - Heartbeat cada 5 min          │    │
│  └──────────────────────────────────┘    │
│            ↑ (si crashea, reinicia)       │
│                                            │
│  ┌──────────────────────────────────┐    │
│  │ Visual Pinball X + VPinMAME       │    │
│  │   ↓                                │    │
│  │ NVRAM (.nv por mesa)              │    │
│  │ - Top 5 visual                    │    │
│  │ - Buy-in champions                │    │
│  │ - Loop champions                  │    │
│  │ - Multiples campos                │    │
│  └──────────────────────────────────┘    │
│            ↑                               │
│            │ pinemhi.exe lee todo          │
└────────────┼───────────────────────────────┘
             ↓ HTTPS
       ┌─────────────┐
       │  SUPABASE   │
       │  Postgres   │
       │             │
       │ - puntajes  │
       │ - actualizac│
       └─────────────┘
             ↑
             │ fetch cada 60 seg
             ↓
       ┌─────────────┐
       │GITHUB PAGES │
       │ index.html  │
       │ (rama main) │
       └─────────────┘
             ↑
             │ Telegram Bot
             ↓
       ┌─────────────┐
       │  TELEGRAM   │
       │  Alertas    │
       └─────────────┘
```

---

<a name="estructura"></a>
## 📁 ESTRUCTURA DE ARCHIVOS

### En el repo:

```
c:\Github repos\VP3 COMPLETO\
├── index.html                          ← Página principal (GitHub Pages sirve este)
├── subir_puntajes.py                   ← Script principal (lee NVRAM, sube a Supabase)
├── config.ini                          ← Configuración (Supabase, Telegram, NVRAM_PATH)
├── historial_nube.json                 ← Backup local del estado de Supabase
├── base_records.json                   ← Lista negra de records de fábrica
├── DOCUMENTACION_SISTEMA_COMPLETA.md   ← Este documento
│
├── MAQUINAS_VP3/                       ← Carpeta que se distribuye a máquinas
│   ├── subir_puntajes.exe              ← Ejecutable compilado
│   ├── WATCHDOG_subir_puntajes.bat     ← Wrapper que mantiene exe vivo
│   ├── WATCHDOG_invisible.vbs          ← Lanza watchdog en silencio
│   ├── pinemhi.exe                     ← Lector NVRAM (de Dna Disturber)
│   ├── pinemhi.ini                     ← Config pinemhi (mesa → archivo .nv)
│   ├── config.ini                      ← Config local
│   ├── RESET_NUBE.exe                  ← Utilidad para resetear Supabase
│   ├── VPMAlias.txt                    ← Alias de ROMs para Visual Pinball
│   ├── historial_nube.json             ← Sync local
│   ├── INICIO AUTOMATICO ...txt        ← Instrucciones de instalación
│   ├── LEEME.txt
│   └── LEEME_INSTALACION_COMPLETA.txt
│
├── MAQUINAS_VP3.zip                    ← ZIP distribuible (todo lo de MAQUINAS_VP3)
│
├── VP3-Web/                            ← Backup web (NO usado en producción)
│   └── index.html
│
└── BACKUPS_20260520_154028/            ← Backup del sistema viejo
```

### Backups centralizados:

```
c:\Github repos\_BACKUPS_TODOS_PROYECTOS\VP3\
└── backup_YYYYMMDD_HHmm/    ← Backup automático con timestamp en cada cambio
```

---

<a name="esquema-supabase"></a>
## 🗄️ ESQUEMA DE SUPABASE

**URL Supabase:** https://ckcjujadpmhdgcvyyahd.supabase.co
**Key pública:** En `index.html` línea ~669 y en `config.ini`

### Tabla `puntajes`:
```
- id_record (string PK)    Ej: "AF-HER-12994263970"
- mesa (string)            Ej: "Attack from Mars"
- posicion (string)        Ej: "Gran Campeon", "2ro", "3ro"...hasta "14to" o más
- jugador (string)         Ej: "HER", "LAL", "ARI", "AGU"
- puntaje (integer)        Ej: 12994263970
- fecha (date)             Ej: "2026-05-07"
```

**Posiciones posibles:** "Gran Campeon", "2ro", "3ro", "4ro", "5ro", "6to", "7to", "8to", "9to", "10to", "11to", "12to", "13to", "14to" y más.

### Tabla `actualizaciones`:
```
- nombre_archivo (string)  Ej: "MAQUINAS_VP3.zip"
- categoria (string)       "Mesa VPX", "Sistema completo", "ROM / NVRAM", "Otro"
- descripcion (text)
- version (string)         Ej: "v2.5.2"
- url_descarga (string)
- subido_por (string)      "Hernan", "Luis"
- fecha (timestamp)
```

---

<a name="flujo-sincronizacion"></a>
## 🔄 FLUJO COMPLETO DE SINCRONIZACIÓN

### Cuando el usuario juega:

```
1. JUEGA partida en mesa VP3 (ej: Black Lagoon)
   ↓
2. TERMINA con puntaje X
   ↓
3. VP3 compara X con TODOS los campos de hi-score de esa mesa:
   - Grand Champion
   - High Scores (Top 5 visual)
   - Buy-in champions
   - Loop champions
   - Trip champions / Track champions
   - Combo champions
   - Etc.
   ↓
4. Si X mejora ALGÚN campo → VP3 pide iniciales → guarda en NVRAM
5. Si X no mejora ningún campo → descarta el puntaje
```

### Cuando se ejecuta `subir_puntajes.exe`:

```
INICIO:
1. Se inicia mediante WATCHDOG (al prender Windows)
2. Loguea evento "Script iniciado" en vp3_script_log.txt
3. Escribe heartbeat "STARTING" en vp3_heartbeat.txt
4. Copia VPMAlias.txt a su lugar (si hace falta)
5. Hace primera sincronización completa: procesar_y_subir()
6. Escribe heartbeat "INITIAL_SYNC_OK"

procesar_y_subir():
1. Carga config.ini
2. Carga base_records.json (lista negra)
3. Detecta si es clon de otra máquina (machine_user)
4. Para cada mesa configurada:
   a. Busca archivo .nv en NVRAM_PATH
   b. Ejecuta pinemhi.exe sobre el archivo
   c. Parsea TODOS los puntajes que pinemhi devuelve
      (Top 5 + buy-in + loops + trips + etc.)
5. Filtra:
   - Ignora records de fábrica (DEFAULT_INITIALS)
   - Ignora records en lista negra
   - Mantiene records de jugadores autorizados (HER, ARI, LAL, AGU)
6. Lee historial_nube.json y records actuales de Supabase
7. Detecta records eliminados manualmente de Supabase
   (los agrega a blacklist EXCEPTO jugadores autorizados)
8. Combina: records existentes + records nuevos
9. Ordena por puntaje y asigna posiciones
10. Sube TODOS los records a Supabase (UPSERT)
11. Si hay nuevos en Top 5 → manda mensaje Telegram
12. Actualiza historial_nube.json

BUCLE DE MONITOREO (cada 10 segundos):
1. Para cada mesa: chequea si mtime del .nv cambió
2. Si cambió → procesar_y_subir() + heartbeat "SYNCED"
3. Cada 30 ciclos (5 min) → heartbeat "ALIVE"
4. Cada 60 ciclos (10 min) → sync forzada + heartbeat "PERIODIC_SYNC_OK"
   (red de seguridad por si NVRAM cambia sin actualizar mtime)
5. Si hay error → loguea pero NO muere, sigue
```

### Cuando se carga la página web:

```
1. GitHub Pages sirve index.html (rama main)
2. JavaScript ejecuta fetchData()
3. Pide a Supabase:
   - GET /puntajes?select=*
   - GET /actualizaciones?select=*
4. Renderiza vistas:
   - 👑 Salón de la Fama: 1 card por mesa (Gran Campeón)
   - 🔥 Desafío Semanal: Top 5 de mesa que toca esa semana
   - 📊 Ranking por Mesa: Top 5 con filtro por mesa
   - 📥 Descargas: actualizacionesData
   - 🏆 Salón de Campeones Semanales: histórico de ganadores
5. setInterval(fetchData, 60000) - refresca cada 60 segundos
```

---

<a name="watchdog"></a>
## 🛡️ SISTEMA WATCHDOG (A PRUEBA DE FALLOS)

**Implementado:** 2026-05-30
**Razón:** El usuario reportó que HER tenía que ejecutar `subir_puntajes.exe` a mano porque a veces no se actualizaba solo.

### Causa raíz:
El script entraba en bucle de monitoreo después de iniciar. Si por cualquier motivo el proceso se cerraba (crash, error, cierre accidental, no inició al prender), nada lo reiniciaba.

### Solución implementada:

#### 1. WATCHDOG_subir_puntajes.bat (versión 2 - detecta shutdown)
```batch
@echo off
cd /d "%~dp0"
set fallos_rapidos=0

:LOOP
echo [%date% %time%] Iniciando subir_puntajes.exe >> watchdog_log.txt
start /wait /min "" subir_puntajes.exe
set exitcode=%errorlevel%

REM Detectar shutdown de Windows
if %exitcode% EQU 3221225794 (
    echo [%date% %time%] Windows apagandose - watchdog termina >> watchdog_log.txt
    exit /b 0
)
if %exitcode% EQU -1073741819 (
    echo [%date% %time%] Acceso violado durante shutdown - termina >> watchdog_log.txt
    exit /b 0
)

REM Detectar 3 fallos rapidos consecutivos = probable shutdown
set /a fallos_rapidos+=1
if %fallos_rapidos% GEQ 3 (
    echo [%date% %time%] 3 fallos consecutivos - probable shutdown - termina >> watchdog_log.txt
    exit /b 0
)

echo [%date% %time%] Se cerro (codigo %exitcode%) - reiniciando >> watchdog_log.txt
timeout /t 5 /nobreak >nul
set fallos_rapidos=0
goto LOOP
```

**Comportamiento:**
- Lanza `subir_puntajes.exe` en modo minimizado
- Espera (`/wait`) hasta que el proceso termine
- Captura el código de salida (`%errorlevel%`)
- **Detecta shutdown de Windows** (códigos `0xC0000142` y `0xC0000005`)
- **Detecta 3 fallos rápidos consecutivos** = probable shutdown
- Si detecta shutdown → sale limpiamente sin reintentar (evita popup de error)
- Si no es shutdown → espera 5 segundos → reinicia
- **Garantiza que el script SIEMPRE esté corriendo durante uso normal**
- **NO molesta al apagar la máquina**

#### 2. WATCHDOG_invisible.vbs
```vbscript
Set objShell = CreateObject("WScript.Shell")
strScriptPath = Replace(WScript.ScriptFullName, WScript.ScriptName, "") & "WATCHDOG_subir_puntajes.bat"
objShell.Run Chr(34) & strScriptPath & Chr(34), 0, False
```

**Comportamiento:**
- Lanza el watchdog SIN ventana visible (modo silencio)
- Este es el archivo que va en `shell:startup`

#### 3. Mejoras al script Python

**Sincronización forzada cada 10 minutos:**
```python
contador_sync_periodico += 1
if contador_sync_periodico >= 60:  # 60 ciclos × 10 seg = 10 min
    log_evento("Sincronizacion periodica de seguridad (cada 10 min)")
    procesar_y_subir()
    escribir_heartbeat("PERIODIC_SYNC_OK")
    contador_sync_periodico = 0
```

**Heartbeat cada 5 minutos:**
```python
contador_heartbeat += 1
if contador_heartbeat >= 30:  # 30 ciclos × 10 seg = 5 min
    escribir_heartbeat("ALIVE")
    contador_heartbeat = 0
```

**Manejo de errores robusto:**
```python
try:
    # ... toda la lógica del script
except Exception as e:
    log_evento(f"ERROR FATAL: {e}")
    escribir_heartbeat(f"FATAL_ERROR: {e}")
    time.sleep(30)
    # No muere - el watchdog lo reinicia
```

### Configuración requerida (UNA VEZ por máquina):

#### MÉTODO 1: Desde PinUP Popper (RECOMENDADO):

1. Descargar `MAQUINAS_VP3.zip` actualizado de GitHub
2. Extraer en su carpeta habitual (ej: `C:\VP3\MAQUINAS_VP3\`)
3. Abrir PinUP Popper Setup
4. Ir a `Other Settings` → `Startup Configurator` (o similar)
5. **🚨 IMPORTANTE: Si existe `subir_puntajes.exe` como Startup App → BORRARLO**
   (Si quedan los dos, se ejecutan en paralelo y rompen la sincronización)
6. Agregar nuevo Startup App:
   - Nombre: VP3 Watchdog
   - Archivo: ruta completa a `WATCHDOG_invisible.vbs`
   - Modo: Hidden / Silent
   - Wait: NO
7. Guardar
8. Reiniciar PinUP Popper

**REGLA DE ORO:** Solo debe quedar `WATCHDOG_invisible.vbs` en el Startup. **NUNCA dejar también `subir_puntajes.exe`** (el watchdog ya lo ejecuta).

#### MÉTODO 2: Editando PinUPSystem (manual):

Editar: `C:\PinUPSystem\PinUPMenu\GlobalSettings.txt`

Agregar en la sección `[StartupApps]`:
```
StartApp0=C:\VP3\MAQUINAS_VP3\WATCHDOG_invisible.vbs
```

#### MÉTODO 3: shell:startup de Windows (BACKUP):

Solo si los otros métodos no funcionan:
1. Presionar `Windows + R` → escribir `shell:startup` → Enter
2. Borrar el acceso directo viejo de `subir_puntajes.exe` (si existe)
3. Crear acceso directo a `WATCHDOG_invisible.vbs`
4. Pegar en la carpeta de inicio

---

<a name="logs"></a>
## 📋 LOGS Y MONITOREO

### Archivos de log generados automáticamente:

#### `vp3_heartbeat.txt`
- Se actualiza cada 5 minutos mientras el script esté vivo
- Formato: `2026-05-30 14:35:22 | ALIVE`
- Estados posibles: `STARTING`, `INITIAL_SYNC_OK`, `ALIVE`, `SYNCED`, `PERIODIC_SYNC_OK`, `ERROR: ...`, `FATAL_ERROR: ...`, `STOPPED_BY_USER`

#### `vp3_script_log.txt`
- Eventos importantes con timestamp
- Inicios, sincronizaciones, errores
- Ejemplo:
  ```
  [2026-05-30 14:30:00] Script iniciado
  [2026-05-30 14:30:01] Sincronizacion inicial
  [2026-05-30 14:30:05] Entrando en modo monitoreo
  [2026-05-30 14:35:00] Cambio detectado en NVRAM - sincronizando
  [2026-05-30 14:45:00] Sincronizacion periodica de seguridad (cada 10 min)
  ```

#### `watchdog_log.txt`
- Cada vez que el exe se inicia o se reinicia
- Permite detectar si hay crashes frecuentes
- Ejemplo:
  ```
  [Sat 30/05/2026 14:00:00,00] Iniciando subir_puntajes.exe
  [Sat 30/05/2026 16:30:15,12] subir_puntajes.exe se cerro - reiniciando
  [Sat 30/05/2026 16:30:20,33] Iniciando subir_puntajes.exe
  ```

### Cómo verificar si el sistema está sano:

1. Abrir `MAQUINAS_VP3/vp3_heartbeat.txt`
2. Mirar la fecha/hora del último heartbeat
3. Si pasaron <5 minutos → script vivo y funcionando
4. Si pasaron 5-10 minutos → puede estar entre ciclos, esperar
5. Si pasaron +10 minutos → algo pasó, revisar `vp3_script_log.txt`

---

<a name="desafio-semanal"></a>
## 🔥 LÓGICA DEL DESAFÍO SEMANAL

### Cómo se calcula:

```javascript
const baseDate = new Date('2026-05-06T00:00:00-03:00');  // Miércoles de inicio
const msPerWeek = 7 * 24 * 60 * 60 * 1000;
const currentWeekIndex = Math.floor((now - baseDate) / msPerWeek);
const challengeTable = ALL_TABLES[currentWeekIndex % ALL_TABLES.length];
```

### Calendario de mesas por semana:

**Lógica:** Usa array `CHALLENGE_TABLES` con rotación variada de mesas de los 90s y 2010s.

| Semana | Fechas | Mesa | Año |
|--------|--------|------|-----|
| 1 | 06-12 mayo | Attack from Mars | 1996 - histórico |
| 2 | 13-19 mayo | Cactus Canyon | 1998 - histórico |
| 3 | 20-26 mayo | Congo | 1995 - histórico |
| 4 | 27 may - 02 jun | Creature from the Black Lagoon | 1992 - YA PASÓ |
| **5** | **03-09 jun** | **The Addams Family** | **1992 (90s) - ACTUAL** ⭐ |
| 6 | 10-16 jun | The Walking Dead | 2014 (2010s) |
| 7 | 17-23 jun | Twilight Zone | 1993 (90s) |
| 8 | 24-30 jun | Goldeneye | 1996 (90s) |
| 9 | 01-07 jul | X-Men | 2012 (2010s) |
| 10 | 08-14 jul | Junk Yard | 1996 (90s) |
| 11 | 15-21 jul | Indiana Jones | 1993 (90s) |
| 12 | 22-28 jul | The Walking Dead | 2014 (2010s) |
| 13 | 29 jul - 04 ago | Lethal Weapon 3 | 1992 (90s) |
| 14 | 05-11 ago | Monster Bash | 1998 (90s) |
| 15 | 12-18 ago | X-Men | 2012 (2010s) |
| ... | ... | (rotación variada hasta semana 44) | |

**Patrón:** Cada 3 semanas hay 2 mesas de 90s + 1 de 2010s. Sin mesas de 80s. Después de semana 44 vuelve a ciclar.

**Mesas usadas en el desafío:**
- **90s** (28 mesas variadas)
- **2010s** (2 mesas que rotan): X-Men (2012), The Walking Dead (2014)
- **80s**: NO se usan (Cyclone, Mousin', Police Force quedan fuera)
- **2000s y 2020s:** No hay mesas instaladas actualmente

### Filtro del desafío:
```javascript
const weekScores = allData.filter(r =>
    r.table === challengeTable &&
    r.date >= startStr &&
    r.date < endStr
);
const winner = weekScores[0];  // El de mayor puntaje
```

**IMPORTANTE:** El desafío semanal NO es una tabla separada. Es un filtro sobre la tabla `puntajes`. Como el sistema captura muchos campos de hi-score por mesa, hay suficientes records para que el desafío funcione bien.

---

<a name="captura-records"></a>
## ✅ CÓMO VP3 CAPTURA RECORDS (CORRECCIÓN IMPORTANTE)

### Lo que SÍ hace el sistema (verificado el 30 mayo 2026):

**El script captura MUCHO MÁS que el Top 5 visual de la mesa.**

Cada mesa de pinball tiene múltiples campos de hi-scores en NVRAM:
- **Grand Champion** (1 record)
- **High Scores** (típicamente 5 records - el Top 5 visual)
- **Buy-in Scores** (champions que pagaron para continuar)
- **Loop Champions** (mejor en loops/orbits)
- **Trip Champions / Track Champions** (mejor en ciertos modos)
- **Combo Champions**
- Y muchos más según la mesa específica

**pinemhi.exe lee TODOS estos campos** y el script `subir_puntajes.py` sube TODOS los puntajes que detecta a Supabase.

### Evidencia (verificado 30 mayo 2026):
**Black Lagoon tenía 14 records en Supabase**:
- Posición "Gran Campeon" hasta "14to"
- Puntajes desde 57M hasta 202M
- Múltiples jugadores en distintas posiciones
- Todos capturados automáticamente

### Lo que pasa cuando jugás:
1. Hacés un puntaje (cualquiera)
2. VP3 lo compara con todos los campos de hi-score de la mesa
3. Si mejora algún campo → VP3 lo guarda en NVRAM
4. Al ejecutarse `subir_puntajes.exe`, pinemhi lee TODOS los campos
5. El script sube todos esos puntajes a Supabase
6. La página web muestra Top 5 visualmente, pero TODOS los records existen

### Por qué algunos records "no aparecen":
Si un puntaje no mejora **NINGÚN** campo de hi-score de la mesa (ni Grand Champion, ni Top 5, ni Buy-in, ni Loops, ni nada), VP3 lo descarta. Pero esto es raro porque las mesas modernas tienen muchos campos.

---

<a name="admin"></a>
## 🔐 CONFIGURACIÓN ADMIN

### Credenciales página web:
- **Usuario:** `admin` (también funcionan `vp3` y `usuario vp3`)
- **Contraseña:** `vp3`

### Para qué se usa el login:
- Subir actualizaciones (botón "⚡ SUBIR ACTUALIZACIÓN")
- Botón BORRAR de archivos aparece siempre pero pide login al usarlo

### Credenciales Supabase:
- **URL:** https://ckcjujadpmhdgcvyyahd.supabase.co
- **Key pública:** Definida en `index.html` línea ~669 y en `config.ini`
- (La key es pública porque es la `anon key`, las restricciones están en las RLS policies)

### Telegram (alertas de records):
- **Token:** En `config.ini` sección `[telegram]`
- **Chat ID:** En `config.ini`

---

<a name="jugadores"></a>
## 🏆 JUGADORES AUTORIZADOS

```python
JUGADORES_AUTORIZADOS = {"HER", "ARI", "LAL", "AGU"}
```

| Inicial | Nombre | Color | Hex |
|---------|--------|-------|-----|
| **HER** | Hernán (Nacho) | Rosa | #ff007f |
| **ARI** | Ariel | Verde | #00ff66 |
| **LAL** | Luis | Azul | #00c3ff |
| **AGU** | Agus | Amarillo | #ffcc00 |

**IMPORTANTE:** Cualquier otro jugador puede subir records si no está en `base_records.json`. Los jugadores autorizados están protegidos de ser agregados automáticamente a la lista negra.

---

<a name="cronologia"></a>
## 📅 CRONOLOGÍA DE CAMBIOS

### Mayo 2026:

| Fecha | Cambio |
|-------|--------|
| 08/05 | Sistema inicial funcionando |
| 20/05 | Restauración de records de ARI (12 records perdidos) |
| 20/05 | Bug crítico arreglado: script sobrescribía `historial_nube.json` |
| 21/05 | Restauradas copas de HER en Attack from Mars y Cactus Canyon |
| 21/05 | Agregada zona de descargas con botón BORRAR (login admin/vp3) |
| 21/05 | Botón BORRAR siempre visible, pide login al usarlo |
| 21/05 | Removido botón "SUBIR MI RECORD" manual (usuario quería todo automático) |
| 29/05 | Restauración masiva de fechas originales desde backup 8 mayo |
| 30/05 | **Descubierto:** sistema captura múltiples campos de hi-score (no solo Top 5) |
| 30/05 | **Implementado:** WATCHDOG para mantener subir_puntajes.exe siempre vivo |
| 30/05 | **Implementado:** Sync forzada cada 10 min como red de seguridad |
| 30/05 | **Implementado:** Logs persistentes (heartbeat, eventos, watchdog) |
| 30/05 | **Implementado:** Manejo de errores robusto (no muere por excepciones) |

### Records destacados actuales:
- **Attack from Mars:** HER 12,994,263,970 (Gran Campeón)
- **Cactus Canyon:** HER 114,597,770 (Gran Campeón)
- **Black Lagoon:** HER 202,538,520 (Gran Campeón actual)
- **Congo:** HER 2,081,717,530 (Gran Campeón)

### Cambio en notificaciones Telegram (30 mayo 2026):
**Versión 1 (mediodía):** Solo notificaba Top 5 visual.

**Versión 2 (tarde):** Notificaba todos los records de jugadores autorizados (HER, ARI, LAL, AGU).

**Versión 3 (FINAL - vigente):** Notifica TODOS los records nuevos sin importar quién sea el jugador (autorizados + invitados).

**Razón del cambio final:** El usuario quiere que cuando venga cualquier amigo o invitado a jugar y haga un record nuevo, también llegue notificación a Telegram. Así toda la actividad del arcade queda registrada.

**Lógica vigente (subir_puntajes.py línea 432):**
```python
# Notificar TODOS los records nuevos (autorizados + invitados)
if r["ID_Record"] not in ids_nube:
    nuevos_top5.append((r, pos))
```

**Resultado:**
- TODO record nuevo se notifica (HER, ARI, LAL, AGU + invitados como TOM, MIG, etc.)
- Sin importar la posición (Top 5, 6to, 11to, buy-in, loop champion, etc.)
- Records de fábrica (DEFAULT_INITIALS) y los de blacklist NO notifican (se filtran antes)
- Records que ya estaban antes en la nube NO se renotifican (solo los nuevos)

---

<a name="proceso-trabajo"></a>
## 🤖 PROCESO DE TRABAJO AUTOMATIZADO

Cada cambio en el sistema se propaga automáticamente a:

1. **Código fuente** (`*.py`, `*.html`, `*.json`, `*.bat`, `*.vbs`)
2. **MAQUINAS_VP3/** (ejecutables compilados con PyInstaller)
3. **MAQUINAS_VP3.zip** (regenerado)
4. **_BACKUPS_TODOS_PROYECTOS/VP3/** (backup centralizado con timestamp)
5. **GitHub rama `main`** (commit + push)
6. **GitHub Pages** (deploy automático en ~1-3 minutos)

### Sin intervención manual del usuario:
- Las máquinas VP3 ejecutan `WATCHDOG_invisible.vbs` al encender
- El watchdog inicia `subir_puntajes.exe`
- El script sincroniza records sin intervención
- Si el script crashea → watchdog lo reinicia
- Cada 10 min hace sync forzada como seguridad
- Solo encender + jugar

### Cómo actualizar el .exe en máquinas con watchdog ya configurado:

#### 🥇 OPCIÓN AUTOMÁTICA (recomendada): ACTUALIZAR_VP3.bat

**Para usuarios que no saben de tecnología (Hernán, Ariel, etc.):**

1. Tener `ACTUALIZAR_VP3.bat` en el escritorio (descargado una vez de GitHub)
2. **DOBLE CLICK** al archivo
3. Esperar a que diga "LISTO!" (1-2 minutos)
4. La ventana se cierra sola

**Lo que hace automáticamente:**
- Cierra `subir_puntajes.exe` viejo
- Descarga ZIP de GitHub
- Extrae y reemplaza archivos
- Arranca el watchdog nuevo

**Distribución por WhatsApp:**
Como WhatsApp bloquea archivos .bat, se manda el LINK de descarga:
```
https://github.com/lanarito/VP3/raw/main/MAQUINAS_VP3/ACTUALIZAR_VP3.bat
```

**Rutina recomendada:** doble click 1 vez por semana. Es idempotente (seguro hacerlo aunque no haya cambios).

#### 🥈 OPCIÓN MANUAL (para usuarios técnicos):

1. Cerrar el .exe viejo:
   - Administrador de tareas → buscar `subir_puntajes.exe`
   - Click derecho → Finalizar tarea

2. Reemplazar el archivo:
   - Pegar el nuevo `subir_puntajes.exe` en la carpeta VP3
   - Sobrescribir el viejo

3. Esperar 5 segundos:
   - El watchdog (que sigue corriendo) detecta que se cerró
   - Arranca el nuevo .exe automáticamente
   - Verificar `vp3_heartbeat.txt` con fecha reciente

**NUNCA:**
- ❌ Ejecutar `subir_puntajes.exe` a mano (doble-click)
- ❌ Dejar dos instancias corriendo en paralelo
- ❌ Bypasear el watchdog

---

<a name="problemas"></a>
## 🚨 PROBLEMAS CONOCIDOS Y SUS SOLUCIONES

### ❌ Problema: Records desaparecen de Supabase
**Causa:** Bug en `subir_puntajes.py` que sobrescribía historial.
**Solución aplicada (20/05):** Modificado para preservar registros históricos (líneas 456-475).

### ❌ Problema: Copas semanales aparecen como "VACANTE"
**Causa:** Fechas de records restaurados quedaron como fecha de restauración, fuera de la semana correcta.
**Solución aplicada (29/05):** PATCH masivo en Supabase para restaurar fechas originales desde backup.

### ❌ Problema: HER tuvo que ejecutar exe a mano
**Causa:** El script se cerraba a veces (crash, accidental) y no había watchdog.
**Solución aplicada (30/05):** Implementado WATCHDOG + sync forzada cada 10 min + logs.

### ❌ Problema: GitHub Pages no muestra cambios
**Causa:** GitHub Pages sirve desde rama `main`, no `master`. Tiene caché de 1-5 minutos.
**Solución:** Push a `main` y esperar deploy. `Ctrl+Shift+R` para forzar recarga.

### ❌ Problema: Records de jugadores no aparecen en desafío
**Causa:** El sistema SÍ captura múltiples campos de hi-score. Si el record no mejora ningún campo, no se captura.
**Solución:** Actualmente las mesas modernas tienen suficientes campos para capturar la mayoría de puntajes.

---

<a name="endpoints"></a>
## 📡 ENDPOINTS DE SUPABASE

### Leer todos los puntajes:
```bash
curl "https://ckcjujadpmhdgcvyyahd.supabase.co/rest/v1/puntajes?select=*" \
  -H "apikey: {SUPABASE_KEY}"
```

### Leer puntajes de una mesa:
```bash
curl "https://.../puntajes?mesa=eq.Black%20Lagoon&order=puntaje.desc" \
  -H "apikey: {KEY}"
```

### Subir nuevo puntaje:
```bash
curl -X POST "https://.../puntajes" \
  -H "apikey: {KEY}" \
  -H "Authorization: Bearer {KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{
    "id_record": "CF-LAL-50000000",
    "mesa": "Creature from the Black Lagoon",
    "jugador": "LAL",
    "puntaje": 50000000,
    "posicion": "5ro",
    "fecha": "2026-05-30"
  }'
```

### Actualizar puntaje (cambiar fecha por ejemplo):
```bash
curl -X PATCH "https://.../puntajes?id_record=eq.CF-LAL-50000000" \
  -H "apikey: {KEY}" -H "Authorization: Bearer {KEY}" \
  -H "Content-Type: application/json" \
  -d '{"fecha":"2026-05-07"}'
```

### Borrar puntaje:
```bash
curl -X DELETE "https://.../puntajes?id_record=eq.CF-LAL-50000000" \
  -H "apikey: {KEY}" -H "Authorization: Bearer {KEY}"
```

### Verificar cantidad de records:
```bash
curl -I "https://.../puntajes?select=count" \
  -H "apikey: {KEY}" -H "Prefer: count=exact"
# Buscar header "Content-Range: 0-0/{TOTAL}"
```

---

<a name="lecciones"></a>
## 🚨 LECCIONES APRENDIDAS

### ❌ ERROR DEL 29-30 MAYO 2026: Asumir limitaciones sin verificar

**Qué pasó:**
Insistí repetidamente que "VP3 solo guarda Top 5 por mesa". El usuario me decía una y otra vez que el sistema funcionaba diferente. Yo seguía teorizando con explicaciones técnicas.

**Resultado:** Le hice perder MUCHO tiempo al usuario.

**La verdad descubierta tras verificar Supabase:**
- Cada mesa tiene MÚLTIPLES campos de hi-score
- pinemhi.exe captura TODOS esos campos
- Black Lagoon tenía 14 records en Supabase
- El "57 millones" de ARI sí existía (CF-ARI-57695590, posición 14to)
- El sistema funcionaba bien todo el tiempo

### ❌ ERROR DEL 30 MAYO 2026: No detectar problema de robustez

**Qué pasó:**
HER tuvo que ejecutar `subir_puntajes.exe` a mano. Pensé que era casi imposible que el script se cerrara, sin considerar crashes, errores no manejados o cierre accidental.

**Resultado:** Records no se sincronizaban hasta intervención manual.

**Solución:** Watchdog + sync periódica + logs.

### 📋 PROTOCOLO PARA EL FUTURO:

**Cuando hay conflicto entre teoría técnica y observación del usuario:**

1. **DETENERSE inmediatamente** de explicar la teoría
2. **VERIFICAR con datos reales:**
   ```bash
   # Para ver TODOS los records de una mesa:
   curl "https://ckcjujadpmhdgcvyyahd.supabase.co/rest/v1/puntajes?mesa=eq.NOMBRE&order=puntaje.desc" -H "apikey: $KEY"
   ```
3. **Aceptar la posibilidad de estar equivocado**
4. **El usuario conoce su sistema mejor que yo**

**Reglas de oro:**
- ❌ "El sistema solo puede X" → MAL, verificá primero
- ❌ "Eso no es técnicamente posible" → MAL, verificá primero
- ✅ "Déjame verificar con datos reales" → SIEMPRE
- ✅ Si el usuario insiste 2+ veces → cambiar de estrategia

**Cuando un proceso "debería" estar corriendo siempre:**
- Implementar watchdog desde el día 1
- Agregar logs persistentes
- Manejo de errores robusto (no morir por excepciones)
- Sync periódica como red de seguridad

---

<a name="troubleshooting"></a>
## 🔧 TROUBLESHOOTING

### "Los records no se actualizan automáticamente"

**Verificar:**
1. `MAQUINAS_VP3/vp3_heartbeat.txt` - ¿Cuándo fue el último heartbeat?
   - <5 min → script vivo, esperar próxima sync (10 min)
   - 5-10 min → puede estar entre ciclos
   - +10 min → revisar logs

2. `MAQUINAS_VP3/vp3_script_log.txt` - ¿Hay errores?
   - Buscar líneas con "ERROR" o "FATAL"

3. `MAQUINAS_VP3/watchdog_log.txt` - ¿Cuántos reinicios?
   - Muchos reinicios seguidos → script está crasheando, hay bug
   - Pocos reinicios → normal

4. Verificar que el watchdog está configurado:
   - Windows + R → `shell:startup`
   - Debe haber acceso directo a `WATCHDOG_invisible.vbs`
   - NO debe haber acceso directo a `subir_puntajes.exe` (eso es lo viejo)

### "La página web no muestra cambios"

**Verificar:**
1. ¿Está apuntando a `lanarito.github.io/VP3/`?
2. Forzar recarga: `Ctrl + Shift + R`
3. Modo incógnito para descartar caché
4. Verificar deploy en GitHub Actions del repo

### "Records desaparecieron"

**Verificar:**
1. Consultar Supabase directamente:
   ```bash
   curl "https://.../puntajes?jugador=eq.HER&order=fecha.desc" -H "apikey: $KEY"
   ```
2. Si están en Supabase pero no en la página → caché del navegador
3. Si no están en Supabase → revisar logs del script

### "El desafío semanal no muestra a un jugador"

**Verificar:**
1. ¿Tiene record en esa mesa con fecha dentro de la semana?
2. ¿Su puntaje mejoró algún campo de hi-score de la mesa?
3. Si jugó pero VP3 no le pidió iniciales → el puntaje no entró a ningún campo

### "El sistema fue clonado a otra máquina (clon detectado)"

**Comportamiento:**
- El script detecta cambio en `machine_user` de `base_records.json`
- Resetea la base local
- Re-baselinea desde cero
- Bloquea records actuales para evitar subir records del dueño anterior

**Esto es normal y esperado.**

---

## 🎯 CHECKLIST DE INSTALACIÓN EN UNA MÁQUINA NUEVA

- [ ] Descargar `MAQUINAS_VP3.zip` de GitHub
- [ ] Extraer en una carpeta (ej: `C:\VP3\`)
- [ ] Editar `config.ini` con paths correctos (NVRAM_PATH)
- [ ] Crear acceso directo a `WATCHDOG_invisible.vbs`
- [ ] Pegar acceso directo en `shell:startup`
- [ ] Verificar que NO hay acceso directo viejo de `subir_puntajes.exe`
- [ ] Reiniciar máquina
- [ ] Verificar `vp3_heartbeat.txt` se actualiza
- [ ] Jugar una partida y verificar que el record sube a Supabase
- [ ] Verificar mensaje Telegram (si está configurado)

---

**Última verificación del sistema:** 2026-05-30
**Estado:** ✅ Operativo con watchdog
**Total records en Supabase:** 145
**Total actualizaciones:** 3
**Próxima sync programada:** Automática cada 10 segundos (cambios) + 10 minutos (forzada)
