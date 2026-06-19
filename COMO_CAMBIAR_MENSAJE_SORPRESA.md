# 🥚 Cómo cambiar el mensaje sorpresa de ACTUALIZAR_VP3.bat

## 🎯 Cómo funciona el sistema:

El `ACTUALIZAR_VP3.bat` muestra un mensaje sorpresa SOLO la primera vez que se ejecuta. Usa un sistema de versiones para que puedas hacer aparecer mensajes NUEVOS en el futuro.

### Funcionamiento técnico:
1. Al ejecutarse, busca un archivo marker oculto: `.welcome_shown_v1`
2. Si NO existe → muestra el mensaje y crea el marker
3. Si SÍ existe → salta el mensaje y sigue con la actualización

---

## 🔄 Para hacer aparecer un mensaje NUEVO:

### Paso 1: Editar `MAQUINAS_VP3/ACTUALIZAR_VP3.bat`

Buscar esta sección:

```bat
if not exist "%~dp0.welcome_shown_v1" (
    color 0C
    cls
    echo.
    echo  ###############################################################
    ... (cartel actual) ...
    ###############################################################
    echo.

    REM Crear marker versionado para no mostrar mas
    echo Welcome v1 shown on %date% %time% > "%~dp0.welcome_shown_v1"
    attrib +h "%~dp0.welcome_shown_v1" >nul 2>&1
```

### Paso 2: Cambiar el número de versión

Cambiar **TODOS los `_v1` por `_v2`** (o el número siguiente que toque):

```bat
if not exist "%~dp0.welcome_shown_v2" (
    ...
    echo Welcome v2 shown on %date% %time% > "%~dp0.welcome_shown_v2"
    attrib +h "%~dp0.welcome_shown_v2" >nul 2>&1
```

### Paso 3: Cambiar el mensaje

Editar el texto del cartel entre los `###` con el nuevo mensaje que quieras.

Tip: usar generadores online de ASCII art tipo:
- https://patorjk.com/software/taag/ (poner el texto y elegir fuente)

### Paso 4: Subir cambios

```bash
git add .
git commit -m "Easter egg v2: nuevo mensaje sorpresa"
git push origin main
```

Los chicos hacen doble click en ACTUALIZAR_VP3.bat y ven el mensaje nuevo (solo una vez).

---

## 📋 Historial de mensajes:

| Versión | Fecha | Mensaje |
|---------|-------|---------|
| v1 | 19 jun 2026 | "PELADOS HIJOS DE LA CHINGADERA!!!" |
| v2 | (próximo) | ??? |

---

## 🐛 Para volver a ver un mensaje viejo:

Si querés que VOS también veas el mensaje (para testear), borrar el archivo marker:

```cmd
del MAQUINAS_VP3\.welcome_shown_v1
```

(Tener en cuenta que es archivo oculto, hay que mostrar archivos ocultos en el explorador)

---

## 💡 Ideas para próximos mensajes:

- "JUEGUEN MAS, PERDEDORES!"
- "NACHO YA TE GANO!"
- "LOS RECORDS SE BORRARON" (broma) y abajo "MENTIRA jaja"
- Mensaje motivacional fake
- ASCII art de un pinball
- Lo que se les ocurra

**Última actualización:** 19 junio 2026
