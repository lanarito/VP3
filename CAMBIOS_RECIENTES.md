# 📋 CAMBIOS RECIENTES - VP3

**Sesión: 3 de junio 2026**

---

## 🛡️ 1. Watchdog v3 - Solución definitiva al error 0xc0000142

### Problema:
Al apagar la máquina aparecía un popup de error:
```
subir_puntajes.exe - Error de la aplicación
La aplicación no se pudo iniciar correctamente (0xc0000142)
```

### Versiones del watchdog:
- **v1:** Bucle simple sin detección → siempre aparecía popup
- **v2:** Detectaba error después del crash → popup aparecía brevemente
- **v3:** ✅ Verifica si Windows se está apagando ANTES de iniciar el .exe → no aparece popup

### Cómo funciona el v3:
```batch
:LOOP
REM PRE-CHECK: verificar si Windows ya se está apagando
powershell -Command "if ([System.Environment]::HasShutdownStarted) { exit 1 }"
if errorlevel 1 (
    REM Windows se está apagando → no intentamos iniciar el .exe
    exit /b 0
)

REM Iniciar el .exe (solo si Windows NO se está apagando)
start /wait /min "" cmd /c "subir_puntajes.exe 2>nul"
...
```

### Para que tome efecto en las máquinas:
**Doble click en `ACTUALIZAR_VP3.bat`** → todo se actualiza solo.

---

## 🏆 2. Desafío Semanal - Rotación variada (solo 90s y 2010s)

### Problema:
El desafío semanal recorría las mesas en orden alfabético (de `ALL_TABLES`). El usuario quería variedad de épocas pero sin 80s.

### Solución:
Nuevo array `CHALLENGE_TABLES` en `index.html` con 44 entradas:
- **Semanas 1-4:** Históricas (Attack from Mars, Cactus Canyon, Congo, Black Lagoon) - no se tocan
- **Semanas 5+:** Rotación variada solo entre **90s y 2010s**

### Patrón:
**Cada 3 semanas:** 2 mesas de los 90s + 1 mesa de los 2010s

### Calendario nuevo (desde 3 junio):

| Semana | Fecha | Mesa | Año |
|--------|-------|------|-----|
| 5 | 03-09 jun | Funhouse | 1990 |
| 6 | 10-16 jun | The Walking Dead | 2014 |
| 7 | 17-23 jun | Twilight Zone | 1993 |
| 8 | 24-30 jun | Goldeneye | 1996 |
| 9 | 01-07 jul | X-Men | 2012 |
| 10 | 08-14 jul | Junk Yard | 1996 |
| 11 | 15-21 jul | Indiana Jones | 1993 |
| 12 | 22-28 jul | The Walking Dead | 2014 |
| 13 | 29 jul - 04 ago | Lethal Weapon 3 | 1992 |
| 14 | 05-11 ago | Monster Bash | 1998 |
| 15 | 12-18 ago | X-Men | 2012 |
| 16 | 19-25 ago | Scared Stiff | 1996 |
| ... | ... | (44 semanas en total, después cicla) | |

### Mesas que NO entran (80s):
- Cyclone (1988)
- Mousin' (1989)
- Police Force (1989)

(Siguen siendo válidas para records normales, solo no salen en el desafío semanal)

### Para que tome efecto:
**Recargar VP3-Web con Ctrl+Shift+R** - el cambio está en la página, no en las máquinas. No hace falta actualizar nada en las máquinas.

---

## 🔔 3. Notificaciones Telegram - Todos los records nuevos

### Cambio anterior (sesión previa):
Antes solo notificaba records Top 5. Cambiado para notificar **TODOS los records nuevos** sin importar:
- Quién sea el jugador (HER, ARI, LAL, AGU + invitados)
- Qué posición sea (Top 5, 6to, 11to, buy-in, loop champion, etc.)

---

## 📦 Actualizadores automáticos

### Para máquinas YA instaladas:
**Link para WhatsApp:**
```
https://github.com/lanarito/VP3/raw/main/MAQUINAS_VP3/ACTUALIZAR_VP3.bat
```

El chico hace click → se descarga → doble click → todo se actualiza solo en 1-2 minutos.

### Para máquinas NUEVAS (primera instalación):
**Link para WhatsApp:**
```
https://github.com/lanarito/VP3/raw/main/INSTALAR_VP3_PRIMERA_VEZ.bat
```

Hace doble click → crea carpeta `C:\VP3` → instala todo → configura inicio automático.

---

## 📚 Documentación disponible

| Archivo | Para qué |
|---------|----------|
| `DOCUMENTACION_SISTEMA_COMPLETA.md` | Documentación técnica completa |
| `TROUBLESHOOTING.md` | Cuándo algo falle |
| `COMO_ACTUALIZAR_FACIL.md` | Guía simple para los chicos |
| `MENSAJE_WHATSAPP_PARA_CHICOS.md` | Mensajes listos para copiar y pegar |
| `MAQUINAS_VP3/INICIO AUTOMATICO SUBIR_PUNTAJE.txt` | Instrucciones de instalación |
| `CAMBIOS_RECIENTES.md` | Este archivo - resumen de cambios |

---

## ✅ Estado actual del sistema

- ✅ Watchdog v3 funcionando (no aparece más error al apagar)
- ✅ Desafío semanal con rotación variada (90s + 2010s, sin 80s)
- ✅ Notificaciones Telegram de TODOS los records
- ✅ Actualizador automático para máquinas existentes
- ✅ Instalador automático para máquinas nuevas
- ✅ Watchdog v3 detecta shutdown y sale limpiamente
- ✅ 145+ records en Supabase
- ✅ Sistema 100% automático sin intervención manual

**Última actualización:** 3 junio 2026
