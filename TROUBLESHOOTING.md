# 🔧 TROUBLESHOOTING VP3 - GUÍA RÁPIDA

**Cuando algo no funciona, mirá acá primero antes de pedir ayuda.**

---

## ⚡ DIAGNÓSTICO RÁPIDO (30 segundos)

### Paso 1: Verificar que el script está vivo

Abrir: `MAQUINAS_VP3/vp3_heartbeat.txt`

| Última actualización | Diagnóstico |
|----------------------|-------------|
| Hace <5 min | ✅ Script vivo |
| Hace 5-10 min | ⚠️ Esperar próximo ciclo |
| Hace +10 min | ❌ Algo pasó - ver Paso 2 |
| Archivo no existe | ❌ Watchdog no está configurado - ver Paso 4 |

### Paso 2: Revisar errores

Abrir: `MAQUINAS_VP3/vp3_script_log.txt`

Buscar líneas con `ERROR` o `FATAL`. Si hay muchas:
- Verificar conexión a internet
- Verificar que Supabase está online
- Verificar que `config.ini` tiene URL/KEY correctos

### Paso 3: Verificar reinicios del watchdog

Abrir: `MAQUINAS_VP3/watchdog_log.txt`

| Patrón | Diagnóstico |
|--------|-------------|
| 1-2 inicios al día | ✅ Normal |
| Reinicios cada pocos minutos | ❌ El script está crasheando |
| Sin reinicios después del inicio | ✅ Script estable |
| Archivo no existe | ❌ Watchdog no se está ejecutando |

### Paso 4: Verificar configuración inicial

**Si está configurado desde PinUP Popper (RECOMENDADO):**
1. Abrir PinUP Popper Setup
2. Ir a Other Settings → Startup Configurator
3. Verificar:
   - ✅ Debe haber UN solo programa: "VP3 Watchdog" apuntando a `WATCHDOG_invisible.vbs`
   - ❌ NO debe haber `subir_puntajes.exe` también (si está, BORRARLO - el watchdog ya lo ejecuta)

**Si está configurado desde Windows shell:startup:**
1. `Windows + R` → escribir `shell:startup` → Enter
2. Debe haber un acceso directo a `WATCHDOG_invisible.vbs`
3. **NO debe haber** acceso directo a `subir_puntajes.exe`

Si falta la configuración:
- Ver `MAQUINAS_VP3/INICIO AUTOMATICO SUBIR_PUNTAJE.txt` con los 3 métodos
- Configurar el preferido (PinUP Popper)
- Reiniciar la máquina

---

## 🚨 PROBLEMAS COMUNES Y SOLUCIONES

### ❌ "Los records no se actualizan automáticamente"

**Causa más probable:** El script no está corriendo.

**Solución:**
1. Verificar heartbeat (Paso 1)
2. Si está muerto:
   - Hacer doble-click en `WATCHDOG_invisible.vbs` manualmente
   - Esperar 30 segundos
   - Verificar que se generó nuevo heartbeat
3. Si el problema persiste:
   - Verificar configuración shell:startup (Paso 4)
   - Reiniciar la máquina

### ❌ "Tengo que ejecutar subir_puntajes.exe a mano"

**Causa:** Probablemente no tenés el watchdog configurado.

**Solución:** Configurar watchdog (Paso 4 arriba).

### ❌ "La página web está desactualizada"

**Causa:** Caché del navegador.

**Solución:**
1. `Ctrl + Shift + R` (recarga forzada)
2. Si persiste, abrir en modo incógnito
3. Verificar que `vp3_heartbeat.txt` está actualizado (datos sí llegan a Supabase)

### ❌ "Un record que hice no aparece"

**Verificaciones:**
1. ¿VP3 te pidió ingresar tus iniciales? Si NO → el puntaje no entró a ningún campo de hi-score, no se puede capturar.
2. ¿El script está corriendo? Ver Paso 1.
3. ¿Pasaron más de 10 minutos desde que jugaste? (espera la sync forzada)
4. Si pasaron horas y nada → ejecutar `WATCHDOG_invisible.vbs` manualmente

### ❌ "El desafío semanal no muestra a alguien"

**Verificaciones:**
1. ¿La fecha del record cae dentro de la semana actual?
2. ¿El record está en la mesa del desafío de esta semana?
3. Verificar en Supabase si el record existe

### ❌ "Mensajes de Telegram no llegan"

**Verificaciones:**
1. `config.ini` tiene `[telegram]` token y chat_id correctos
2. El bot de Telegram no fue bloqueado
3. Internet funciona en la máquina

### ❌ "Aparece error 0xc0000142 al apagar la máquina"

**Causa:** Cuando Windows se apaga, el `subir_puntajes.exe` se cierra. El watchdog detecta que se cerró e intenta reiniciarlo. Pero como Windows ya está apagándose, las DLLs no se pueden cargar → error 0xc0000142.

**Versión del watchdog:**

- **v1 (vieja):** Solo intentaba reiniciar - aparecía popup
- **v2:** Detectaba el código de error después del crash - aún podía aparecer popup brevemente
- **v3 (actual):** **Verifica si Windows está apagándose ANTES de iniciar el .exe** - no debería aparecer popup

**Si seguís viendo el popup:**
1. Probablemente tenés el watchdog v1 o v2 todavía
2. Ejecutar `ACTUALIZAR_VP3.bat` para tener la versión nueva
3. Reiniciar Windows para que use el nuevo watchdog

**Es solo cosmético:** Aunque aparezca el popup, no afecta nada del sistema. Los records se siguen sincronizando bien cuando prendés la máquina.

### ❌ "Records duplicados o conflictos de sincronización"

**Causa probable:** Tienen `subir_puntajes.exe` Y `WATCHDOG_invisible.vbs` configurados al mismo tiempo en el Startup.

**Por qué pasa:**
- El watchdog ya ejecuta `subir_puntajes.exe` por dentro
- Si además ponés `subir_puntajes.exe` directo en Startup
- Se ejecutan 2 instancias del mismo programa
- Pelean por el mismo archivo (NVRAM, historial_nube.json)
- Pueden subir records duplicados o pisarse

**Solución:**
1. Abrir PinUP Popper Setup → Startup Configurator
2. Borrar el `subir_puntajes.exe` (si está)
3. Dejar SOLO `WATCHDOG_invisible.vbs`
4. Verificar también `shell:startup` de Windows (no debe estar ahí tampoco)
5. Reiniciar máquina

---

## 📊 COMANDOS DE DIAGNÓSTICO

### Verificar conexión a Supabase
```bash
curl -I "https://ckcjujadpmhdgcvyyahd.supabase.co/rest/v1/puntajes?select=count" -H "apikey: YOUR_KEY"
```

### Ver últimos records subidos
```bash
curl "https://.../puntajes?select=*&order=fecha.desc&limit=10" -H "apikey: YOUR_KEY"
```

### Ver records de un jugador específico
```bash
curl "https://.../puntajes?jugador=eq.HER&order=fecha.desc" -H "apikey: YOUR_KEY"
```

### Ver records de una mesa
```bash
curl "https://.../puntajes?mesa=eq.Cactus%20Canyon&order=puntaje.desc" -H "apikey: YOUR_KEY"
```

---

## 🔄 CÓMO ACTUALIZAR EL .EXE (CUANDO YA TENÉS WATCHDOG)

### Opción A: Reemplazar solo el .exe (recomendado)

1. **Cerrar el .exe viejo:**
   - Abrir Administrador de tareas (`Ctrl + Shift + Esc`)
   - Pestaña "Procesos"
   - Buscar `subir_puntajes.exe`
   - Click derecho → **Finalizar tarea**

2. **Reemplazar el archivo:**
   - Pegar el nuevo `subir_puntajes.exe` en la carpeta VP3
   - Sobrescribir el viejo

3. **Esperar 5 segundos:**
   - El watchdog detecta que se cerró el viejo
   - Lo reinicia automáticamente con el nuevo
   - Verificar `vp3_heartbeat.txt` - debe tener fecha/hora reciente

4. **Listo** - No hay que hacer nada más

### Opción B: Bajar el ZIP completo y reemplazar todo

1. Cerrar el .exe viejo (Administrador de tareas)
2. Extraer el ZIP nuevo
3. Pegar TODOS los archivos en la carpeta VP3 (sobrescribir)
4. El watchdog reinicia el .exe nuevo automáticamente

### ⚠️ Lo que NO hay que hacer:

- ❌ **NO** ejecutar `subir_puntajes.exe` a mano (doble-click)
- ❌ **NO** dejar el watchdog viejo Y el .exe nuevo corriendo en paralelo
- ❌ **NO** ejecutar dos instancias del .exe al mismo tiempo

### ¿Cómo sé si el watchdog está corriendo?

Abrir Administrador de tareas → buscar:
- ✅ `cmd.exe` (es el watchdog)
- ✅ `subir_puntajes.exe`

Si están los dos juntos → todo bien funcionando.

Si solo está `subir_puntajes.exe` pero NO `cmd.exe` → el watchdog no se está ejecutando, hay que reconfigurarlo.

---

## 🛠️ ACCIONES DE EMERGENCIA

### Reiniciar el script sin reiniciar Windows
1. Abrir Administrador de Tareas
2. Buscar `subir_puntajes.exe` → Finalizar tarea
3. El watchdog lo reiniciará en 5 segundos
4. Verificar heartbeat

### Forzar sincronización ahora
1. Hacer doble-click en `subir_puntajes.exe` (no el watchdog)
2. Hará una sincronización completa al inicio
3. Cerrar la ventana cuando termine

### Resetear el sistema (CUIDADO)
- `MAQUINAS_VP3/RESET_NUBE.exe` borra TODO de Supabase
- Solo usar en casos extremos
- Los records se perderán

---

## 📞 DÓNDE PEDIR AYUDA

Si nada de esto funciona:
1. Capturar pantalla del problema
2. Copiar contenido de:
   - `vp3_heartbeat.txt`
   - `vp3_script_log.txt` (últimas 50 líneas)
   - `watchdog_log.txt` (últimas 20 líneas)
3. Reportar el problema con esa info

---

**Última actualización:** 2026-05-30
