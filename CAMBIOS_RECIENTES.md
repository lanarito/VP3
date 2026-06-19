# 📋 CAMBIOS RECIENTES - VP3

**Última sesión: 4 de junio 2026**

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

## 🚫 Archivos eliminados (ya no existen)

- `FIX_ERROR_SHUTDOWN.bat` → integrado en ACTUALIZAR_VP3.bat

---

**Última actualización:** 4 junio 2026
**Filosofía:** Un solo doble click + un solo UAC = TODO resuelto
