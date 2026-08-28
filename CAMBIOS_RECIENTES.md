# 📋 CAMBIOS RECIENTES - VP3

**Última sesión: 27 de agosto 2026**

---

## 🔴 EL RECORD SUBE AL GRABAR LAS INICIALES (sin salir de la mesa)

### Lo que se pedía:
Que el puntaje suba apenas el jugador graba sus iniciales, sin esperar a salir
de la mesa ni a apagar la máquina. Así se ve al instante y no hay lugar a picardías.

### Por qué antes no se podía:
VPinMAME escribe el archivo `.nv` **recién cuando se cierra la mesa**. Mientras se
juega, el puntaje vive solo en la memoria. Se confirmó con dos pruebas reales:
HER actualizó a la versión nueva ANTES de jugar y aun así no subió nada hasta cerrar.

También se probó engancharse desde afuera por COM: imposible. `VPinMAME.dll` es un
servidor COM **in-process**, corre adentro del proceso de Visual Pinball.

### La solución: engancharse DESDE ADENTRO
`core.vbs` es un archivo compartido que cargan las 37 mesas, y tiene
`Sub PinMAMETimer_Timer`, que corre todo el tiempo mientras se juega. Ahí el objeto
`Controller` ya existe y expone la memoria en vivo.

**Lado mesa** (`activar_lectura_en_vivo.ps1`):
- Una sola línea al principio de `PinMAMETimer_Timer`, que llama a una rutina aislada
- Vuelca la memoria cada 3 segundos, **de a 256 bytes por vuelta** para no frenar el juego
- Solo escribe si el puntaje cambió de verdad
- Sale como texto hexadecimal a `C:\vPinball\VP3_LIVE\<rom>.hex`
  (escribir binario desde VBScript es frágil)

**Lado uploader** (`subir_puntajes.py`):
- `convertir_volcados_en_vivo()` pasa el `.hex` a un `.nv` que PINemHi entiende
- `archivos_de_la_mesa()` junta los `.nv` reales con el volcado en vivo
- El volcado en vivo **NUNCA crea línea base**. Si pudiera, el primer record de cada
  jugador quedaría marcado como "de fábrica" y no subiría nunca más.

### Para los chicos: nada nuevo
Se activa sola en el **paso 9 de 10** del `ACTUALIZAR_VP3.bat`. Un solo doble click.
La activación es idempotente: correrla mil veces no duplica nada, y si hay una versión
vieja del enganche la reemplaza.

`LECTURA_EN_VIVO.bat` queda por si alguna vez hay que activarla o desactivarla a mano.

### Probado antes de publicar:
- El código original de la mesa sigue corriendo: **300 de 300 vueltas**
- La mesa generó el volcado correcto (12.334 bytes, igual que el real de HER)
- El uploader lo leyó **byte por byte idéntico**
- Activar y desactivar deja `core.vbs` **idéntico al original** (mismo md5)
- Correr la activación 3 veces seguidas no duplica nada
- Siguen pasando los tests viejos: escaneo dirigido 4/4 y seguridad 4/4

---

## ⚡ SUBIDA INMEDIATA DE RECORDS (sin esperar a apagar)

### Problema:
Un jugador hacía un record, salía de la mesa y apagaba la máquina. El puntaje no llegaba
a subir y no se veía ni en la página ni en Telegram **hasta que la máquina se reiniciaba**.
Eso además abría la puerta a picardías: hasta el reinicio, nadie veía el record.

### Por qué pasaba:
El sistema ya vigilaba la NVRAM, pero con dos demoras encima:

1. Miraba si había cambios **cada 10 segundos**.
2. Cuando detectaba uno, volvía a escanear **las 37 mesas** con PINemHi (varios segundos).

Entre una cosa y la otra podían pasar 15 a 45 segundos desde que el `.nv` se escribía
hasta que el record llegaba a Supabase. Si apagaban en el medio, se perdía la subida.

### Solución (`subir_puntajes.py`):

1. **Vigilancia cada 2 segundos** en vez de 10.
2. **Sincronización dirigida:** cuando cambia una mesa, se escanea **solo esa mesa**,
   no las 37. `procesar_y_subir()` ahora acepta `solo_mesas=[...]`.
3. Se mantiene la **pasada completa cada 10 minutos** como red de seguridad, y la
   sincronización al apagar.

**Resultado medido:** de hasta 45 segundos a **1 segundo** de reacción.

### Por qué es seguro:
La sincronización dirigida **no borra nada**. Los records de las demás mesas se leen igual
de la nube y todo se sube con *upsert*. Probado con dos tests automatizados antes de publicar:

- `test_dirigida`: al cambiar Hook lee únicamente `hook_408.nv` y `hook_501.nv`,
  y no toca Twilight Zone ni Terminator 2.
- `test_seguridad`: con Supabase simulada, al sincronizar solo Hook sobreviven los records
  de Twilight Zone, Attack from Mars y Terminator 2, y sube el nuevo de Hook.
- Prueba en vivo del `.exe` compilado: detectó el cambio del `.nv` en **1,0 segundos**.

### Límite que queda (importante):
El puntaje llega al archivo `.nv` cuando **VPinMAME lo escribe**, o sea al salir de la mesa.
No existe forma de subirlo antes de eso. Lo que se arregló es todo lo que viene después:
apenas el archivo se escribe, en un par de segundos ya está en la web y en Telegram.

### Para las máquinas:
Nada especial. El "Actualizar VP3" de siempre.

---

## 🗂️ CONTEXTO PERMANENTE ENTRE CHATS

- `CLAUDE.md` — se carga solo en cada chat nuevo: reglas, arquitectura, reglas de oro y flujo.
- `HISTORIAL_CHATS.md` — todo lo hablado desde el 20 de mayo de 2026, día por día.
- `actualizar_historial.py` — regenera ese historial desde las transcripciones.

---

## 🎯 FILOSOFÍA DEL SISTEMA (NUEVA)

**Toda solución técnica DEBE integrarse en `ACTUALIZAR_VP3.bat`**

Un solo doble click hace TODO. Si requiere admin, se auto-eleva (un solo UAC). No hay archivos separados para descargar ni pasos manuales adicionales.

### Lo que significa esto:

**Para los chicos siempre va a ser:**
```
1. Doble click "Actualizar VP3"
2. Click "SÍ" en UAC
3. Esperar "LISTO!"
4. Listo - nada más que hacer
```

**No se hacen más:**
- ❌ Archivos .bat separados (FIX_X.bat, ACTUALIZAR_Y.bat)
- ❌ Pedir descargar varios archivos
- ❌ Instrucciones "primero esto, después esto"
- ❌ Múltiples UAC popups

---

## 🛡️ 1. Watchdog v4 + Fix Error 0xc0000142 INTEGRADO

### Problema:
Al apagar la máquina aparecía popup de error 0xc0000142.

### Solución FINAL (todo en `ACTUALIZAR_VP3.bat`):

El `ACTUALIZAR_VP3.bat` ahora hace **8 pasos automáticos**:

```
[Auto-eleva a admin con UAC]
[1/8] Cierra procesos viejos
[2/8] Descarga ZIP de GitHub
[3/8] Extrae archivos
[4/8] Copia archivos nuevos
[5/8] Limpia temporales
[6/8] Aplica fix de registro Windows (HKLM y HKCU)
[7/8] Configura Windows Error Reporting
[8/8] Arranca watchdog v4
"LISTO!"
```

### Watchdog v4 (cambios):
- Usa PowerShell `Start-Process -WindowStyle Hidden` en lugar de `start /min`
- Mejor manejo de procesos sin shell visible
- Pre-check y post-check de shutdown con HasShutdownStarted
- Detecta códigos 0xC0000142 y 0xC0000005

### Registro modificado:
- `HKLM\SYSTEM\CurrentControlSet\Control\Windows\ErrorMode = 2`
- `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows\ErrorMode = 2`
- `HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\Disabled = 1`
- `HKCU\Software\Microsoft\Windows\Windows Error Reporting\DontShowUI = 1`

---

## 🏆 2. Desafío Semanal - Calendario corregido

### Calendario actualizado (semana actual y siguientes):

| Semana | Fecha | Mesa | Año |
|--------|-------|------|-----|
| 4 (ya pasó) | 27 may - 02 jun | Creature from the Black Lagoon | 1992 |
| **5 (ACTUAL)** | **03-09 jun** | **The Addams Family** ⭐ | 1992 |
| 6 | 10-16 jun | The Walking Dead | 2014 |
| 7 | 17-23 jun | Twilight Zone | 1993 |
| 8 | 24-30 jun | Goldeneye | 1996 |
| 9 | 01-07 jul | X-Men | 2012 |
| 10 | 08-14 jul | Junk Yard | 1996 |
| 11 | 15-21 jul | Indiana Jones | 1993 |
| 12 | 22-28 jul | The Walking Dead | 2014 |
| ... | ... | (rotación 90s + 2010s) | |
| 22 | 14-20 oct | Funhouse | 1990 |
| 27 | 18-24 nov | Creature from the Black Lagoon | 1992 (vuelve si arreglado) |

### Patrón:
**Cada 3 semanas: 2 mesas de 90s + 1 de 2010s**

### Mesas usadas:
- **90s** (28 mesas variadas)
- **2010s** (2 mesas que rotan): X-Men (2012), The Walking Dead (2014)

### Mesas NO usadas:
- **80s** (no se usan): Cyclone, Mousin', Police Force

---

## 🔔 3. Notificaciones Telegram - Todos los records

Notifica TODOS los records nuevos sin importar:
- Quién es el jugador (HER, ARI, LAL, AGU + invitados como TOM, MIG, etc.)
- Qué posición sea (Top 5, 6to, 11to, buy-in, loop champion, etc.)

---

## 📦 Distribución para los chicos

### Link único para WhatsApp:
```
https://github.com/lanarito/VP3/raw/main/MAQUINAS_VP3/ACTUALIZAR_VP3.bat
```

### Mensaje listo para mandar:
```
Te paso el actualizador (todo integrado, con fix de error al apagar).

Link:
https://github.com/lanarito/VP3/raw/main/MAQUINAS_VP3/ACTUALIZAR_VP3.bat

1. Click al link, se descarga
2. Lo movés al escritorio
3. Doble click cuando quieras actualizar
4. Click "SÍ" en los permisos
5. Esperás "LISTO!"

Una vez por semana lo hacés y queda siempre al día 🎮
```

### Para máquina nueva:
```
https://github.com/lanarito/VP3/raw/main/INSTALAR_VP3_PRIMERA_VEZ.bat
```

---

## 📚 Documentación disponible

| Archivo | Para qué |
|---------|----------|
| `DOCUMENTACION_SISTEMA_COMPLETA.md` | Documentación técnica completa |
| `TROUBLESHOOTING.md` | Cuándo algo falle |
| `COMO_ACTUALIZAR_FACIL.md` | Guía simple para los chicos |
| `MENSAJE_WHATSAPP_PARA_CHICOS.md` | Mensajes listos para copiar y pegar |
| `CAMBIOS_RECIENTES.md` | Este archivo |

---

## ✅ Estado actual del sistema

- ✅ Watchdog v4 funcionando
- ✅ Fix de registro INTEGRADO en ACTUALIZAR_VP3.bat
- ✅ Desafío semanal con rotación 90s + 2010s (Addams Family actual)
- ✅ Notificaciones Telegram universales
- ✅ Actualizador automático con auto-elevación admin
- ✅ Instalador automático para máquinas nuevas
- ✅ Filtro inteligente de iniciales de fábrica (permite invitados reales)
- ✅ Sistema 100% automático sin intervención manual

---

## 🧹 Limpieza de jugadores fantasma (19 junio 2026)

### Problema:
Aparecieron jugadores fantasma en la página: AAA, BLS, GLV, NBW, NMI, RAY.

### Causa raíz:
`DEFAULT_INITIALS` estaba **definido pero NUNCA se usaba** en el filtro. Solo se chequeaba `base_records.signatures`.

### Solución FINAL (filtro inteligente):

El filtro ahora tiene 2 capas:

**Capa 1: Lista negra dinámica (signatures)**
- Si la combinación exacta `mesa-iniciales-puntaje` ya está en signatures → se ignora
- Esto captura los records de fábrica registrados al baselinear

**Capa 2: Iniciales de fábrica + puntaje sospechoso**
- Si las iniciales están en `DEFAULT_INITIALS` (BLS, NBW, RAY, AAA, etc.)
- Y el puntaje es "redondo" (múltiplo de 100K, 500K o 1M)
- → Se ignora y se agrega a signatures automáticamente
- Si el puntaje NO es redondo (ej: 3,458,950) → **se permite** (es probablemente un usuario real)

### Ejemplo práctico:

| Usuario | Mesa | Puntaje | ¿Se graba? | ¿Por qué? |
|---------|------|---------|------------|-----------|
| BLS (fábrica) | BTTF | 1,000,000 | ❌ No | Inicial fábrica + puntaje redondo |
| RAY (fábrica) | BTTF | 1,700,000 | ❌ No | Inicial fábrica + puntaje redondo |
| **RAY (real)** | BTTF | 3,458,950 | ✅ **Sí** | Inicial fábrica pero puntaje específico |
| MIK (invitado) | BTTF | 2,105,290 | ✅ Sí | No está en DEFAULT_INITIALS |
| HER | BTTF | 1,500,000 | ✅ Sí | Jugador autorizado |

### Jugadores eliminados:
AAA, BLS, GLV, NBW, NMI, RAY (todos con puntajes "redondos" típicos de fábrica)

### Mantenido:
MIK (invitado real con records específicos)

### Iniciales nuevas agregadas a DEFAULT_INITIALS:
NMI, GLV, MDX, EFG, JKL, MNO, PQR (detectadas como fábrica)

---

## 🥚 Easter Egg en ACTUALIZAR_VP3.bat (19 junio 2026)

### Qué hace:
La PRIMERA vez que cada usuario ejecuta `ACTUALIZAR_VP3.bat`, aparece un cartel grande en rojo con un mensaje sorpresa, después siguen con la actualización normal.

### Mensaje actual (v1):
**"PELADOS HIJOS DE LA CHINGADERA!!!"** en ASCII art grande

### Cómo funciona:
1. Verifica si existe archivo marker oculto `.welcome_shown_v1`
2. Si NO existe → muestra cartel + crea marker
3. Si SÍ existe → salta el cartel y continúa normal

### Sistema versionado:
Para poner mensajes nuevos en el futuro:
1. Cambiar versión del marker (`v1` → `v2`)
2. Cambiar texto del cartel
3. Los chicos verán el nuevo mensaje próxima vez que ejecuten

### Documentación dedicada:
`COMO_CAMBIAR_MENSAJE_SORPRESA.md` con instrucciones paso a paso

### Filosofía:
Es una broma interna divertida sin afectar la funcionalidad. Después del cartel sigue todo el flujo normal de actualización.

---

## 🚫 Archivos eliminados (ya no existen)

- `FIX_ERROR_SHUTDOWN.bat` → integrado en ACTUALIZAR_VP3.bat

---

## 💾 4. Sincronización forzada antes de apagar (6-11 agosto 2026)

### Problema:
Un jugador (LAL) apagaba la máquina justo después de terminar de jugar, y el puntaje nunca llegaba a subirse — `subir_puntajes.exe` quedaba cortado a mitad de la sincronización.

### Solución:
`ACTUALIZAR_VP3.bat` ahora registra un **script de apagado de Windows** (mecanismo nativo, sin necesitar `gpedit.msc` — funciona también en Windows Home). Windows lo ejecuta automáticamente antes de terminar de apagar la PC, y **espera** a que termine (con un tope de 25 segundos para nunca colgar el apagado).

Funciona sin importar cómo se dispare el apagado — desde PinUP Popper ("salir, salir") o desde el menú de Windows — porque ambos caminos terminan en el mismo mecanismo de apagado del sistema operativo.

### Archivos nuevos:
- `subir_puntajes.exe --sync-once`: una sola pasada de sincronización, sin loop
- `SYNC_ANTES_DE_APAGAR.bat`: la ejecuta con tope de 25s
- `registrar_sync_apagado.ps1`: registra el script de apagado (via `scripts.ini`/`gpt.ini`, sin gpedit)

De paso: las llamadas a Supabase ahora tienen timeout de 10s (antes podían quedar colgadas sin límite si fallaba la red).

`ACTUALIZAR_VP3.bat` pasó de 8 a **9 pasos** (nuevo paso: "Registrando sincronización final antes de apagar").

---

## 🐛 5. El watchdog revivía el .exe viejo durante la actualización (11 agosto 2026)

### Problema:
Un fix en el código no se reflejaba en la máquina de un jugador aunque corriera "Actualizar VP3" varias veces. El `.exe` quedaba siempre con la misma fecha vieja.

### Causa raíz:
El actualizador mataba `subir_puntajes.exe`, pero **no mataba al watchdog** — que lo revivía solo en segundos, dejando el archivo trabado justo cuando el paso de copia intentaba reemplazarlo. La copia fallaba en silencio (xcopy no revisa el resultado) y el script terminaba diciendo "LISTO!" con la versión vieja todavía corriendo.

### Solución:
`ACTUALIZAR_VP3.bat` ahora mata primero al watchdog (busca por línea de comando con PowerShell/CIM, ya que corre oculto sin título de ventana) y recién después reemplaza el `.exe`.

---

## 🎰 6. Mesas con varias versiones de ROM instaladas (11 agosto 2026)

### Problema:
Una máquina tenía **3 archivos `.nv` de Hook** (`hook_408`, `hook_500`, `hook_501` — distintas versiones de rom). El sistema solo leía el de fecha de modificación más reciente; si la partida real quedaba grabada en otro, nunca se subía.

### Solución:
`subir_puntajes.py` ahora lee y combina **todos** los `.nv` que matcheen el prefijo de una mesa, no solo el más nuevo. La detección de cambios en NVRAM también usa el mtime más reciente entre todos los archivos.

### Alias de VPinMAME (VPMAlias.txt) generalizadas:
Algunas versiones de rom no son reconocidas por `pinemhi.exe` directamente, pero SÍ tienen una alias en `VPMAlias.txt` (le dice a VPinMAME "tratá esta rom igual que esta otra"). Como `pinemhi.exe` no conoce esas alias por su cuenta, ahora `subir_puntajes.py` las lee de `VPMAlias.txt` y las aplica él mismo (antes solo existía este truco hardcodeado para un caso: Tom & Jerry → Hollywood Heat).

**Alias agregadas:** `hook_501,hook_408` y `hook_500,hook_408`.

### 🔴 Bug crítico que esto introdujo, y su fix:
El truco de alias funciona copiando el archivo con el nombre del rom "destino" para que `pinemhi` lo pueda leer. La primera versión de este código **copiaba directo en la carpeta real de NVRAM**, pisando temporalmente el archivo del rom destino. Si ese rom destino es una mesa que el usuario también juega (como pasaba con `hook_408`), y algo fallaba a mitad de camino (timeout de pinemhi, por ejemplo), el archivo real **quedaba pisado para siempre** con el contenido de otra mesa — pérdida real de puntajes.

Dos arreglos, verificados con test automatizado antes de publicar:
1. La copia ahora se hace en una **carpeta temporal aparte** (con su propia copia de `pinemhi.exe` y `pinemhi.ini` apuntando ahí), nunca en la carpeta real de NVRAM. Riesgo cero para los archivos reales.
2. La restauración quedaba fuera del `try/finally` que envuelve la llamada a `pinemhi.exe` — si pinemhi se colgaba, la excepción saltaba directo al error y la restauración nunca corría. Ahora está en un `finally`, se ejecuta siempre.

### Línea base ahora es por ARCHIVO, no por mesa:
Antes, si una mesa ya estaba "inicializada" (aunque fuera por un solo archivo), un `.nv` nuevo de esa misma mesa (otra versión de rom) se saltaba el filtro de línea base y sus valores de fábrica entraban como records reales. Ahora cada archivo se registra por separado.

---

## 🧹 7. Nuevas limpiezas de jugadores fantasma (agosto 2026)

Mismo patrón que la limpieza de junio, aplicado a mesas nuevas:

| Mesa | Iniciales de fábrica agregadas |
|------|-------------------------------|
| Hook | HEC, CNH, PUP, UGR, JAY, LAR, DAN |
| Last Action Hero | LON |
| Terminator 2 | JCS, AJA, DOC, JAS |

### Categoría nueva: `SIEMPRE_FABRICA`
Se encontraron 5 iniciales (`AAA`, `SLL`, `MAB`, `CCC`, `AII`) con puntajes **NO redondos** que igual eran de fábrica — el filtro normal (`DEFAULT_INITIALS`) las dejaba pasar porque asumía que un puntaje específico significaba jugador real. El usuario confirmó que en este grupo esas iniciales puntuales nunca son reales, tengan el puntaje que tengan.

`SIEMPRE_FABRICA` bloquea sin mirar el puntaje. Es distinto de `DEFAULT_INITIALS` (que sigue dejando pasar puntajes no redondos, para no tapar a un invitado real como RAY/BLS/etc). **`MIK` se dejó afuera a propósito** — sigue confirmado como invitado real desde junio 2026.

---

## 🔧 8. Publicador automático (`publicar.ps1`) mandaba el .exe viejo

### Problema:
El script que auto-compila y publica a GitHub llamaba a `pyinstaller` a secas, que no está en el PATH — fallaba siempre, en silencio, y el script seguía igual: armaba el ZIP y lo subía **con el `.exe` viejo adentro**. Resultado: código nuevo publicado con ejecutable desactualizado, sin ningún aviso de error.

### Solución:
Ahora usa `python -m PyInstaller` (el módulo, con mayúsculas) y revisa que el `.exe` realmente se haya generado. Si la compilación falla, **aborta la publicación** en vez de subir algo a medias.

---

## 📥 9. ACTUALIZAR_VP3.bat ahora también en la Zona de Descargas de la web

Antes solo se conseguía por el link de WhatsApp o el acceso directo del escritorio. Ahora también aparece como descarga independiente en la web (categoría "Sistema completo"), como backup por si se pierde el acceso directo o para instalarlo en otra máquina.

---

## ✅ Estado actual del sistema (25 agosto 2026)

- ✅ Watchdog v4 funcionando, y ya no revive el .exe durante una actualización
- ✅ Sincronización forzada antes de apagar (paso 9 de `ACTUALIZAR_VP3.bat`)
- ✅ Lee todas las versiones de ROM instaladas por mesa, no solo la más nueva
- ✅ Alias de VPMAlias.txt aplicadas automáticamente, en carpeta temporal segura
- ✅ Línea base por archivo (no por mesa) — sin agujeros al agregar una ROM nueva
- ✅ Filtro de fábrica con 2 niveles: `DEFAULT_INITIALS` (solo puntaje redondo) y `SIEMPRE_FABRICA` (siempre)
- ✅ Publicador automático aborta si falla la compilación, no publica .exe viejo
- ✅ Notificaciones Telegram universales
- ✅ Actualizador disponible también en la Zona de Descargas de la web

---

**Última actualización:** 25 agosto 2026
**Filosofía:** Un solo doble click + un solo UAC = TODO resuelto
