# 📋 CAMBIOS RECIENTES - VP3

**Última sesión: 31 de agosto / 1 de septiembre 2026**

## 🐛 11. Tildada suave detectada tras confirmar la v12 (1 septiembre 2026)

### Lo que pasó:
Luis, después de confirmar que la subida instantánea ya funcionaba, notó **una sola tildada muy suave**, sin identificar cuándo ni en qué mesa.

### Causa probable:
La v12 lee la memoria ENTERA de la mesa (`Controller.NVRAM`) una vez por segundo para comparar si cambió algo. En una mesa grande (Stern/SAM, ~130.000 bytes) esa lectura + comparación completa tiene un costo chico pero real, y a 1 vez por segundo alguna vez se puede llegar a notar.

### Arreglo (v13):
Se bajó el chequeo de 1 vez por segundo a **una vez cada 2 segundos** — la mitad de lecturas de memoria, mismo mecanismo. El aviso instantáneo sigue siendo prácticamente al toque (2 segundos como mucho, en vez de 1), y baja el riesgo de notarse.

De paso se corrigió un bug en el propio actualizador: al subir de v12 a v13 en una máquina que ya tenía v12 puesto, el chequeo "¿ya está activado?" no reconocía la llamada vieja (por el número de versión en el comentario) y la habría dejado duplicada dentro del timer de la mesa. Probado el caso exacto (v12 real → correr v13 encima) antes de publicar: quedó una sola llamada, limpia.

### Para los chicos: nada nuevo
Se corrige con `ACTUALIZAR_VP3.bat` de siempre.

---

## 🐛 12. La tildada seguía en Walking Dead con v13 → arreglo de fondo (v14, 1 septiembre 2026)

### Lo que pasó:
Luis probó específicamente Walking Dead (mesa Stern/SAM, memoria bien más grande que el resto — unos 130.000 bytes contra los 2.000-8.000 de la mayoría) y confirmó que ahí sí se notaba la traba, ni bien con el chequeo cada 2 segundos.

### Medido con un test real (no adivinado):
Cuando algo cambia, la v13 reconstruye el texto hexadecimal COMPLETO de la mesa con `Hex()` byte por byte. En una mesa chica, gratis (0ms medidos). En una mesa como Walking Dead, esa reconstrucción completa cuesta **~55 milisegundos** — bastante para sentirse como un salto, sobre todo porque en Walking Dead casi cualquier cosa que pasa jugando (un contador, un jackpot, un puntaje) dispara ese recálculo.

### Arreglo (v14) — parche real, no solo "chequear menos seguido":
Ahora se guarda el texto hexadecimal **ya convertido** de una vuelta a la otra, y cuando algo cambia, solo se recalculan los 2 caracteres de los bytes que en verdad cambiaron (no toda la mesa). Medido: de ~55ms a prácticamente 0 para el puñado de bytes que cambian por vez. Sumado a la comparación y al armado del texto final, el peor caso medido en Walking Dead bajó de **~90ms a ~35ms**.

(Esto es distinto del intento fallido de v10 — ver [[project_v10_multibola_lag]] — que usaba `Mid(...) = valor`, una sentencia que directamente no existe en VBScript. Acá se reasigna un ELEMENTO de un array, que sí existe y sí funciona.)

Probado antes de publicar con un test funcional de 5 casos (primera lectura, throttle bloqueando, parche de 1 byte, sin cambios reales, 2 bytes cambiados a la vez) — todos comparados contra el cálculo manual completo, byte a byte idénticos.

### Para los chicos: nada nuevo
Se corrige con `ACTUALIZAR_VP3.bat` de siempre.

---

## 🐛 13. Todavía algo en Walking Dead → intervalo adaptativo por tamaño de mesa (v15, 1 septiembre 2026)

### Lo que pasó:
Luis probó Walking Dead de nuevo con la v14 aplicada: mejoró bastante, pero "todavía tiene una pequeña tildada... le falta fluidez". Dato honesto y concreto, no una queja vaga.

### Por qué queda ese resto:
Con la v14 ya no se reconvierte la mesa entera a texto — pero **leer y comparar** la memoria completa sigue costando algo (~35ms medidos en el peor caso), y eso no se puede evitar del todo sin dejar de detectar cambios. Ese costo depende del tamaño de la mesa: en las mesas chicas de los 90s (la gran mayoría del catálogo) es prácticamente gratis; en Walking Dead o X-Men (Stern/SAM, +20.000 bytes de NVRAM) es donde se nota.

### Arreglo (v15) — intervalo adaptativo, no un cambio parejo para todas:
En vez de bajarle la velocidad a TODO el catálogo (perdiendo la subida casi instantánea en mesas donde no hace falta), ahora el sistema mide el tamaño real de la NVRAM en la primera lectura de cada mesa y decide solo, mesa por mesa:
- Mesa chica (menos de 20KB, la mayoría): sigue revisando cada 2 segundos, igual que antes.
- Mesa grande (Stern/SAM, tipo Walking Dead/X-Men): pasa a revisar cada 5 segundos — menos seguido, para que el costo por chequeo se sienta menos, pero sigue siendo un aviso rapidísimo comparado con la versión vieja (que solo subía al cerrar la mesa).

Probado antes de publicar con un test funcional dedicado: confirma que una mesa chica se queda en 2 segundos, que una mesa grande pasa sola a 5 segundos, que un cambio a los 3 segundos queda bloqueado por el intervalo largo, y que a los 6 segundos sí se detecta. Más el round-trip de siempre y el caso de actualizar la versión anterior sin duplicar la llamada.

### Para los chicos: nada nuevo
Se corrige con `ACTUALIZAR_VP3.bat` de siempre.

### ✅ CONFIRMADO (1 septiembre 2026):
Luis jugó Walking Dead de nuevo: "mejoró muchísimo... un diez". De paso probó Tortugas (TMNT), hizo record, y **subió enseguida**. Los dos frentes (subida instantánea + fluidez) quedaron cerrados con test real.

---

## 🔴 14. Encontrada la causa del lag en la máquina de Her — no era `core.vbs` (1 septiembre 2026)

### Lo que pasó:
Her actualizó, jugó Tortugas y notó micro-cortes; jugó Walking Dead y notó "un lagazo cada 10 segundos". Esto llamó la atención porque en la máquina de Luis, con la misma versión, ya había quedado fluido — así que mandó el diagnóstico para comparar con datos reales en vez de asumir que era lo mismo.

### El diagnóstico mostró algo distinto:
El log del sistema mostraba `"Cambio detectado en disco: Teenage Mutant Ninja Turtles"` **repetido cada 5-6 segundos, sin parar, durante los más de 2 minutos que duró la sesión**. Eso encendió una alarma: no puede ser que alguien haga un puntaje nuevo cada 5 segundos.

### La causa real (del lado del `.exe`, no de `core.vbs`):
La memoria de una mesa mientras se juega cambia todo el tiempo por cosas que **no son puntajes** — bolas jugadas, auditorías internas del ROM, contadores. El enganche en vivo (correcto) guarda esos cambios en un archivo. El problema estaba en `subir_puntajes.exe`: **trataba CUALQUIER cambio de ese archivo, aunque no tuviera nada que ver con un puntaje, como motivo para correr `PINemHi` (un programa aparte) y avisarle a Supabase (internet)**. Resultado: esos dos pasos pesados se repetían cada 5-6 segundos sin parar mientras alguien jugaba — el peso real detrás del "lagazo" que sintió Her.

Esto es un problema DISTINTO del que se venía afinando en `core.vbs` (fluidez de la mesa en sí) — está del lado del programa que sube los puntajes, y explica por qué en la máquina de Luis podía sentirse distinto según qué tan seguido cambiara la memoria de cada mesa en particular.

### Arreglo:
Ahora `subir_puntajes.exe` distingue dos tipos de cambio:
- Si cambió el archivo REAL de la NVRAM (la mesa se cerró de verdad) → sincroniza siempre al toque, como siempre. Es raro, y ahí sí importa no perder tiempo.
- Si solo cambió el volcado en vivo (mientras se juega) → respeta un mínimo de 5 segundos entre una sincronización y la siguiente. Si hay cambios de sobra en el medio, no se pierden — se juntan y se sincronizan apenas se puede, nunca se descartan.

Sigue siendo instantáneo para lo que importa (ver el puntaje al toque de poner las iniciales), pero deja de correr `PINemHi` y de golpear a Supabase varias veces por segundo mientras alguien está jugando sin haber hecho ningún record todavía.

### Probado antes de publicar:
Test aislado (sin tocar la Supabase real) simulando: varios cambios seguidos del volcado en vivo dentro de la ventana de 5 segundos (ninguno dispara de más), el cambio pendiente se sincroniza apenas pasa el enfriamiento, y un cambio del archivo REAL siempre sincroniza al toque sin importar el enfriamiento.

### Para los chicos: nada nuevo
Se corrige con `ACTUALIZAR_VP3.bat` de siempre — esta vez SÍ hace falta correrlo de nuevo (toca el `.exe`, no solo `core.vbs`, así que no alcanza con lo que ya está aplicado en la mesa).

### Resultado (parcial):
Her actualizó, probó Walking Dead de nuevo, y el lagazo cada ~10 segundos SEGUÍA ahí — casi igual que antes. El enfriamiento de 5 segundos no alcanzaba. Esto llevó a investigar más a fondo (ver el punto siguiente).

---

## 🔴 15. LA CAUSA DE FONDO DEL LAGAZO: se re-subía la base de datos ENTERA cada vez (1 septiembre 2026)

### Lo que pasó:
El enfriamiento de 5 segundos del punto anterior no resolvió nada de verdad — el segundo diagnóstico de Her mostró el mismo patrón, "Cambio detectado en disco" cada 6-7 segundos sin parar jugando Walking Dead. Eso significaba que la primera teoría (demasiados chequeos) estaba incompleta: el problema no era CUÁNTAS VECES se disparaba la sincronización, sino **cuánto pesaba cada una**.

### La causa real, encontrada leyendo el código con lupa:
`procesar_y_subir()` — la función que sincroniza con Supabase — tenía un defecto de diseño: **aunque no hubiera NINGÚN puntaje nuevo para subir, siempre hacía el viaje completo a la nube**: bajaba la tabla ENTERA de puntajes (todas las mesas, todos los jugadores) y la volvía a subir ENTERA, aunque no hubiera cambiado nada. Con el enganche en vivo disparando una sincronización dirigida cada pocos segundos mientras se juega — la mayoría de las veces por un contador interno del juego, no por un puntaje real — eso significaba **una ida y vuelta completa a internet cada 5-7 segundos sin parar, aunque no hubiera nada que subir**. Esto es mucho más pesado que solo correr PINemHi, y depende de qué tan buena sea la conexión a internet de cada máquina — lo que también explica por qué en la máquina de Luis no se notaba tanto como en la de Her.

### Arreglo:
Ahora, si la sincronización es "dirigida" (la dispara el enganche en vivo o el cierre de una mesa, no la pasada completa de cada 10 minutos) y no se encontró NINGÚN puntaje nuevo de verdad, **se corta ahí mismo, sin tocar internet para nada**. La pasada completa (al arrancar, cada 10 minutos, al apagar) sigue haciendo el viaje entero siempre, como red de seguridad.

Esto es mucho más importante que el enfriamiento del punto anterior — mientras el enfriamiento solo bajaba cuántas veces se repetía el trabajo pesado, esto hace que la enorme mayoría de esas veces (cuando no hay nada nuevo) **no pese casi nada**.

### Probado antes de publicar:
Test aislado que bloquea cualquier llamada de red real (para no arriesgar la Supabase real) y confirma dos cosas: sin puntajes nuevos, la función NO intenta ninguna llamada de red; con un puntaje nuevo de verdad, SÍ la intenta (nada se rompió para el caso real).

### Para los chicos: nada nuevo
Se corrige con `ACTUALIZAR_VP3.bat` de siempre.

### Resultado:
Her actualizó (confirmado: `.exe` con este arreglo puesto) y probó Walking Dead de nuevo. **Seguía trabándose.** Con este segundo intento tampoco alcanzó — señal de que hay que dejar de adivinar y medir directamente qué está pasando en su máquina en concreto.

---

## 🔍 16. Instrumentación de tiempos reales (1 septiembre 2026) — dejar de adivinar

### Lo que pasó:
Dos arreglos seguidos del lado del `.exe` (enfriamiento de 5s, y no tocar la nube si no hay nada nuevo) y Her seguía sintiendo el lagazo en Walking Dead. En vez de seguir probando teorías a ciegas, se agregó una medición directa al programa: ahora **cada vez que se sincroniza, el log dice cuánto tardó realmente** (en segundos) y si tocó o no la nube.

Con esto, el próximo diagnóstico va a mostrar la respuesta sin adivinar:
- Si el ciclo tarda poco (medio segundo o menos) y dice "no se tocó la nube" → el problema ya NO está en `subir_puntajes.exe`, y hay que mirar del lado de `core.vbs` (posible que la máquina de Her sea más lenta que la de Luis, y el mismo costo que ahí no se nota, en la de Her sí).
- Si el ciclo sigue tardando varios segundos → el problema sigue estando acá, y ahora se sabe si es PINemHi el que tarda o si la nube se sigue tocando de más.

### Para los chicos: nada nuevo
Se corrige con `ACTUALIZAR_VP3.bat` de siempre.

### Resultado — LA RESPUESTA DEFINITIVA:
Her actualizó, probó Walking Dead, mandó el diagnóstico con los tiempos. Y ahí quedó clarísimo: **cada uno de los ciclos, uno atrás del otro sin excepción, decía "SI hay algo nuevo, sincronizando con Supabase"**. El arreglo de "no tocar la nube si no hay nada nuevo" nunca se activaba en esta mesa — porque el programa creía que SIEMPRE había un puntaje nuevo. Eso llevó al hallazgo real (ver el punto siguiente).

---

## 🎯 17. LA RESPUESTA: en Walking Dead, algo en la memoria "parece un puntaje nuevo" todo el tiempo sin serlo (1 septiembre 2026)

### El dato que lo destapó:
El log con tiempos mostró que en Walking Dead, CADA sincronización dirigida (una cada 6-7 segundos, sin parar) encontraba "algo nuevo" — nunca ni una sola vez decía "nada nuevo". Eso no puede ser gente terminando una partida cada 6 segundos. Tiene que haber algo en la memoria de esa mesa en particular que **parece** un puntaje distinto cada vez que se lee, sin serlo de verdad — lo más probable, algún valor "en vivo" de la partida en curso (no un record final grabado) que la herramienta que lee la memoria (PINemHi) también reporta como si fuera un puntaje de tabla.

### Por qué es difícil de resolver "mirando directo" el campo:
Meterse a averiguar EXACTAMENTE qué campo de la memoria de Walking Dead es el que hace esto requeriría estudiar la definición interna de esa mesa puntual en PINemHi — muy específico de esa ROM, frágil, y no se sabe si otras mesas grandes (X-Men, por ejemplo) tienen el mismo problema con otro campo distinto.

### La solución (más robusta, sirve para cualquier mesa con este problema):
Se agregó un filtro de estabilidad: un puntaje candidato **solo se sube si aparece igual dos veces seguidas** en la sincronización mientras se juega. Un puntaje real, una vez grabado en la memoria, se queda quieto — la segunda vez que se lee sigue siendo el mismo, así que se confirma y sube (con una demora extra de unos 5-7 segundos, nada grave). Un valor que cambia solo porque refleja la partida en curso nunca logra aparecer igual dos veces seguidas, así que nunca llega a subir ni a tocar la nube — se filtra solo, sin necesidad de saber qué campo puntual es.

### Probado antes de publicar:
Test aislado (con la nube bloqueada, para no arriesgar la real) con 4 casos: un valor nuevo no sube en su primera aparición, sube recién en la segunda aparición igual, un valor que cambia todo el tiempo nunca llega a subir (reproduce el problema real), y la sincronización completa de seguridad (arranque / cada 10 min / apagado) sigue subiendo directo sin esta demora, como siempre.

### Para los chicos: nada nuevo
Se corrige con `ACTUALIZAR_VP3.bat` de siempre.

### Resultado:
Her actualizó con este arreglo puesto (confirmado por la fecha del `.exe`) y el log SEGUÍA diciendo "SI hay algo nuevo" en el 100% de los ciclos. El filtro de estabilidad no alcanzaba — llevó al hallazgo final, más de fondo (ver el punto siguiente).

---

## ✅ 18. LA CAUSA REAL, DE FONDO: faltaba acordarse de lo que YA se había subido (1 septiembre 2026)

### Por qué el filtro de estabilidad no alcanzaba:
PINemHi vuelve a leer **todos** los puntajes válidos de la mesa en cada chequeo, no solo los que cambiaron. Eso significa que los puntajes REALES que ya existen en Walking Dead (el Top 1, el Grand Champion, etc.) también "aparecen iguales dos veces seguidas" — siempre, para siempre, porque nunca cambian. El filtro de estabilidad los confirmaba una y otra vez en cada ciclo, aunque ya estuvieran subidos hace rato. Faltaba la pieza que realmente importaba: **acordarse de lo que ya se subió**, para no repetirlo.

### El arreglo final:
Ahora, además de confirmar que un puntaje aparece igual dos veces seguidas, el programa recuerda cuáles ya subió en esta sesión. Un puntaje que ya se subió una vez **no vuelve a tocar la nube nunca más**, aunque PINemHi lo siga reportando siempre igual (que lo va a seguir haciendo, es como lee la memoria). Si en algún momento aparece un valor genuinamente distinto — un record nuevo de verdad — ese sí pasa por el mismo camino de siempre: confirmar dos veces, subir, y quedar marcado para no repetirse tampoco.

### Probado antes de publicar:
Se agregó el caso exacto que estaba fallando de verdad: un puntaje ya confirmado y subido que sigue apareciendo igual, ciclo tras ciclo, para siempre — y se confirmó que ya NO dispara la nube de nuevo. Junto con todos los casos anteriores (primera aparición no sube, confirmación sube, ruido constante nunca sube, un valor genuinamente nuevo sí sube, la sincronización completa de seguridad sigue funcionando igual).

### Para los chicos: nada nuevo
Se corrige con `ACTUALIZAR_VP3.bat` de siempre.

### Resultado — ¡LA GRAN NOTICIA!:
Her actualizó, jugó Walking Dead, y el log mostró exactamente lo esperado: cada ciclo bajó de ~1.3-1.5 segundos a **~0.27 segundos**, y ahora dice "nada nuevo, NO se tocó la nube" en la enorme mayoría de los casos. El lado del `.exe` quedó confirmado liviano.

Pero Her **todavía sintió la tildada jugando**. Eso apunta ahora al otro lado: el chequeo que hace la mesa (`core.vbs`) leyendo su propia memoria. En la máquina de referencia ese chequeo cuesta muy poco (~35ms), pero la de Her podría ser más lenta para ese mismo trabajo — sin poder medir en su máquina en persona, hace falta el mismo tipo de dato real que resolvió el lado del `.exe`.

---

## 📊 19. Medición real del lado de la mesa (v16, 2 septiembre 2026)

### Lo que se agregó:
Igual que se hizo con `subir_puntajes.exe` (medir en vez de adivinar), ahora `core.vbs` también anota cuánto tarda su propio chequeo — en un archivo nuevo, `VP3_LIVE\_tiempos.log`, con una línea por chequeo real: mesa, milisegundos, si hubo cambio, y tamaño de la memoria. `DIAGNOSTICO_VP3.bat` ya lo muestra (reemplazó a la sección vieja de `_actividad.log`, que ya no se usa desde hace varias versiones).

### Para qué sirve:
Con este dato de la máquina de Her en concreto, se va a saber si el chequeo ahí tarda parecido a lo medido en la máquina de referencia (y entonces el problema es otra cosa, no `core.vbs`) o si tarda bastante más (y entonces hay que ajustar el intervalo específicamente para máquinas más lentas, con el número real en la mano en vez de adivinar).

### Para los chicos: nada nuevo
Se corrige con `ACTUALIZAR_VP3.bat` de siempre.

### Pendiente de confirmar:
Falta que Her actualice, juegue Walking Dead un rato, y mande el diagnóstico — esta vez con los tiempos reales de su propia máquina.

---

---

## 🔴 PISTA FUERTE: EL ANTIVIRUS PUEDE ESTAR MATANDO EL PROGRAMA (sin confirmar aún)

### Lo que pasó:
Con el registro de errores nuevo ya puesto en la máquina de Her, siguió
cerrándose solo (una vez corrió limpio 26 minutos y se cayó) — pero el
registro quedó VACÍO. Eso descarta que sea un error del programa: algo
lo está matando desde AFUERA.

### La pista:
Docenas de carpetas temporales (`_MEIxxxxxx`) sin limpiar en Temp,
acumuladas desde hace días. Así queda un programa como éste cuando lo
matan de golpe en vez de cerrarse solo — es un problema conocido de los
`.exe` como el nuestro (sin firma digital): el antivirus de Windows
puede desconfiar y bloquear la carpeta temporal que se auto-extrae en
cada arranque.

### El arreglo (pendiente de confirmar):
Se agregó al actualizador una exclusión de Windows Defender para
`subir_puntajes.exe` y su carpeta. **No se pudo probar en vivo** porque
tocar configuración de antivirus necesita el permiso explícito de
ustedes vía el cartel de administrador — no algo que se pueda hacer
"por atrás". Va a tomar efecto en la próxima actualización.

### Para los chicos: nada nuevo
Se corrige con `ACTUALIZAR_VP3.bat`. Después de que Her actualice de
nuevo, mandar otro `DIAGNOSTICO_VP3.bat` para confirmar si las caídas
pararon.

---

## 🔴 DOS RECORDS DE FÁBRICA (TOY, ZAB) QUE NO ERAN DE NADIE

### Lo que pasó:
Subieron a la página `TOY` (Cactus Canyon, 30 millones justos) y `ZAB`
(NBA Fastbreak, 34 puntos) — ninguno de los dos es jugador nuestro. Ya
se borraron de la nube.

### Causa:
La lectura en vivo (recién arreglada hoy) trajo un efecto secundario: la
"línea base" de una mesa (su tabla de puntajes de fábrica, que nunca
debe subir) solo se armaba leyendo el archivo real del disco — nunca
desde la lectura en vivo, a propósito, para no perder el primer record
de un jugador real. El problema: con la lectura en vivo funcionando de
verdad, una mesa que **nunca se había leído del disco** podía tener su
primera lectura de todas por el camino en vivo — y ese camino no arma
línea base, así que su tabla de fábrica pasaba sin filtrar.

### Arreglo:
La línea base ahora se arma sin importar por qué camino llegó el dato,
protegiendo lo mismo que protegía antes (nunca bloquear a HER/ARI/LAL/AGU,
nunca bloquear un puntaje que no sea redondo — señal de que es una
partida real). Probado con un caso simulado antes de publicar.

### Para los chicos: nada nuevo
Se corrige con `ACTUALIZAR_VP3.bat`.

---

## 🔴 LA CAUSA DE FONDO DE LOS PROCESOS DUPLICADOS (encontrada con un diagnóstico real)

### Lo que pasó:
Her hizo un record de 1.926.680 y no subió instantáneo — volvió el
problema. Se armó un diagnóstico de un click (`DIAGNOSTICO_VP3.bat`,
ahora en `MAQUINAS_VP3`) para juntar toda la info de su máquina sin
adivinar con capturas sueltas. El archivo mostró algo grave:
`subir_puntajes.exe` se estaba **cerrando solo (código 1) cada tanto
tiempo**, incluida una vez que corrió limpio 18 minutos y se cayó justo
antes del horario del record.

### Dos causas de fondo, encontradas y arregladas:

**1. El mutex (el "candado" para que no se duplique el programa) era
invisible entre procesos con distinto nivel de permisos.** Cuando
`ACTUALIZAR_VP3.bat` corre con permisos de administrador (como corre
siempre, por el cartel de Windows) y después arranca otra copia SIN esos
permisos (como hace PinUP Popper al iniciar), esa segunda copia **ni
siquiera podía ver** el candado de la primera — Windows le devolvía
"acceso denegado", no "ya existe", y el chequeo no sabía reconocer esa
respuesta. Confirmado con una prueba directa en la máquina real. Se
arregló poniéndole al candado un permiso abierto para cualquiera, sin
importar su nivel — tanto en `subir_puntajes.exe` como en el watchdog.

**2. El programa se caía sin dejar ningún rastro de por qué.** Se agregó
un registro (`vp3_crash_log.txt`) que guarda el detalle completo de
cualquier error que se escape, para poder ver la próxima vez exactamente
qué pasó, en vez de solo saber que pasó algo.

### Para los chicos: nada nuevo
Se corrige con `ACTUALIZAR_VP3.bat` de siempre — pero esta vez, para que
tome efecto completo, hace falta que alguien lo corra CON el cartel de
Windows aceptado (el .exe viejo, si está corriendo con permisos de
administrador de una actualización anterior, no se puede reemplazar
hasta que el actualizador lo mate primero).

---

## 🔴 SE ENCONTRÓ POR QUÉ SE TILDABA LA MESA EN MULTIBOLA

### Lo que reportó Luis:
Mesas que "sacan multiball" y se traban — algo aparece de golpe en otro
lugar, como si saltara un frame. Preguntó si tenía que ver con los
cambios de esta sesión.

### Sí, tenía que ver — encontrado y medido:
El enganche en vivo (`core.vbs`) SÍ usaba el delta para actualizar la
memoria en sí, pero para armar el texto que se escribe a disco volvía a
**recorrer y convertir el buffer ENTERO de NVRAM con `Hex()`, byte por
byte, cada vez que cambiaba algo** — lento de por sí en VBScript. En una
mesa con NVRAM chica no se nota. En una Stern/SAM (The Walking Dead,
X-Men — unos 130.000 bytes) esa vuelta completa tarda de verdad, y
**multibola es justo cuando más bytes cambian por segundo** (varios
jugadores, jackpots, contadores todos a la vez).

Medido con una prueba real: simulando 200 disparos de multibola sobre
una mesa de ese tamaño, la versión vieja tardaba **18,7 segundos en
total** (unos 94 milisegundos por disparo — más que el tiempo entero de
un cuadro a 60 cuadros por segundo). Con eso alcanza y sobra para
sentirse como una tildada.

### El arreglo (v10):
Ahora se parchea DIRECTO el pedacito de texto que corresponde al byte
que cambió, sin tocar ni recorrer el resto. Mismo resultado final
(comprobado byte a byte, idéntico a la versión vieja), pero **23 veces
más rápido** en la prueba de arriba. Se sube sola en la próxima
actualización.

### Para los chicos: nada nuevo
Se corrige con `ACTUALIZAR_VP3.bat` de siempre.

---

## 🔴 EL WATCHDOG AHORA USA UN MUTEX REAL (Her confirmó el problema con un video)

### Lo que pasó:
Her mandó un video: en el Administrador de Tareas se veían **4 copias de
"subir_puntajes"** al mismo tiempo, la mesa tildándose, y al cerrar una
ventana se le volvía a abrir otra sola.

### La causa de fondo:
**PinUP Popper tiene su propio arranque automático**, guardado en su base
de datos (`PUPDatabase.db`, tabla `GlobalSettings`, columna
`StartupBatch`), que lanza el watchdog cada vez que arranca Popper —
totalmente aparte de `ACTUALIZAR_VP3.bat`. El chequeo que había
("¿hay otro watchdog corriendo ahora?") miraba una FOTO de los procesos
en ese instante: si Popper y el actualizador arrancan casi juntos, los
dos pueden sacar la foto antes de que el otro se registre, y los dos
pasan.

### El arreglo:
El watchdog (`WATCHDOG_supervisor.ps1`, v6) ahora usa un **Mutex real de
Windows** — el mismo tipo de candado que ya protegía a
`subir_puntajes.exe`, sostenido mientras dure el watchdog, no una foto de
un instante. Probado lanzando 5 copias exactamente en el mismo
milisegundo: siempre gana una sola, sin excepción. `WATCHDOG_subir_puntajes.bat`
sigue siendo el mismo archivo de siempre (así no hace falta tocar la
configuración de PinUP Popper), solo que ahora delega toda la lógica al
supervisor nuevo.

### Para los chicos: nada nuevo
Se corrige solo con `ACTUALIZAR_VP3.bat`. Da igual quién dispare el
watchdog primero (Popper o el actualizador) — nunca más van a quedar dos
corriendo juntas.

---

## 🔴 POR FIN: LA SUBIDA INSTANTÁNEA FUNCIONA DE VERDAD (y se arregló el mensaje doble)

### Los tres síntomas que reportó Luis:
1. Hizo un record y el mensaje de Telegram llegó recién al SALIR de la mesa, no al cargar las iniciales.
2. El mensaje llegó DOBLE.
3. Pidió revisar qué procesos había corriendo.

### Causa del mensaje doble (confirmada y arreglada):
Había **dos copias de `subir_puntajes.exe` corriendo a la vez** en la
máquina real (se vio en el Administrador de Tareas y en el log: "Cambio
detectado" aparecía dos veces, 1 segundo de diferencia). El motivo: el
watchdog viejo se reinicia solo si nota que su `.exe` murió, y si eso pasa
justo cuando arranca el watchdog nuevo (al actualizar), quedan dos sistemas
enteros corriendo, cada uno mandando su propio Telegram. Se arregló
`cerrar_procesos_viejos.ps1` para que escriba un archivo `_DETENER_VP3_`
ANTES de matar nada — el watchdog viejo ya sabe respetarlo y se apaga solo
en vez de revivir. Probado contra el desorden real que había: quedó en una
sola copia.

### Causa de "solo sube al salir de la mesa" (la más difícil de encontrar):
El enganche instantáneo vive en `core.vbs`. Se probó en vivo (lanzando
Teenage Mutant Ninja Turtles con diagnósticos puestos a mano DENTRO del
script mientras la mesa corría de verdad) y se confirmó: **Visual Pinball no
estaba leyendo el `core.vbs` que se venía arreglando** — leía una copia
vieja y separada que vivía directo en la carpeta de las mesas
(`Tables\core.vbs`), desincronizada desde antes de esta sesión. La función
nativa de VPX que carga el script (`GetTextFile`) prioriza la copia que está
al lado de la mesa por sobre la compartida, y nada lo avisaba.

Se arregló `activar_lectura_en_vivo.ps1` para que, de ahora en más, sincronice
SIEMPRE cualquier copia de `core.vbs` que encuentre al lado de la principal —
tanto al activar como al desactivar la lectura en vivo, y también si una
copia se desincroniza después. Confirmado en la máquina real: TMNT generó su
archivo de lectura en vivo apenas se cargó la mesa, sin necesidad de terminar
la partida.

### Para los chicos: nada nuevo
Se corrige solo con `ACTUALIZAR_VP3.bat`, doble click de siempre.

---

## 🔴 SE ARREGLÓ EL QUILOMBO QUE DEJÓ GEMINI (lag, cierres reiterados)

### Lo que pasó:
Mientras no estuve disponible, Luis probó con Gemini resolver lo mismo (subida
instantánea al grabar iniciales). Gemini reescribió `activar_lectura_en_vivo.ps1`
y `subir_puntajes.py` con dos problemas:

1. **El enganche en `core.vbs` quedó pegado en 9 lugares distintos** del archivo
   (en vez de uno solo), por un `-replace` que no estaba bien anclado y matcheaba
   de más en las ~2500 líneas compartidas por las 37 mesas.
2. **`subir_puntajes.py` escaneaba TODA la memoria RAM del proceso de Visual
   Pinball desde afuera** (hasta 2 GB de espacio de direcciones, con
   `VirtualQueryEx`/`ReadProcessMemory`), repitiendo el escaneo completo cada 4
   segundos mientras no encontraba la mesa, más una lectura de memoria cada 1
   segundo mientras se jugaba. Eso competía por CPU con la mesa en vivo, en la
   misma máquina — la causa real de que "se pusiera lenta la máquina y se
   tildara", exactamente lo que Luis reportó.

### Lo que se arregló:
- Se sacó el escaneo de RAM de `subir_puntajes.py` por completo (y el archivo
  huérfano `lector_memoria_vpx.py` que nadie llamaba). Se volvió al enganche
  nativo y liviano de `core.vbs` (v9): un solo punto de enganche, usa el motor
  `UseNVRAM`/`NVRAMCallback` que VPinMAME ya trae de fábrica, y solo aplica el
  delta que llega (`ChangedNVRAM`), nunca vuelve a leer la memoria entera.
- Se reescribió `activar_lectura_en_vivo.ps1` (v9) con un solo punto de
  enganche, probado a fondo: activar → desactivar deja `core.vbs` **byte por
  byte idéntico** al original (antes había un bug de regex — la función
  `VP3EnVivo` tiene un "3" y el patrón de desactivación no aceptaba dígitos, así
  que nunca revertía bien). Probado también con un motor VBScript real
  (`cscript`) simulando un `Controller` falso: baseline se lee una sola vez,
  los deltas se aplican bien, no reescribe el archivo si no cambió nada de
  verdad.
- Se restauró el `core.vbs` real de la máquina desde el backup limpio y se le
  aplicó el enganche correcto.
- Se mantuvo lo bueno que sí trajo Gemini: **mutex de instancia única** en
  `subir_puntajes.exe` (si ya hay una copia corriendo, la nueva se cierra sola
  en vez de duplicarse) y el watchdog v5 con chequeo anti-duplicados
  (`verificar_unico_watchdog.ps1`). Confirmado en la máquina real: un solo
  watchdog, un solo `subir_puntajes.exe` (el par proceso padre/hijo de
  PyInstaller es normal, no es un duplicado).
- Se sacaron `INICIAR_VP3.bat` y `DETENER_VP3.bat`: archivos sueltos que
  Gemini agregó fuera de `ACTUALIZAR_VP3.bat`, contra la filosofía del
  proyecto (todo pasa por el único botón).

### Para los chicos: nada nuevo
Se actualiza solo con `ACTUALIZAR_VP3.bat`, doble click de siempre.

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

## 🐛 10. El puntaje no se subía al momento de poner las iniciales, solo al salir de la mesa (31 agosto - 1 septiembre 2026)

### Síntoma:
Luis reportó varias veces lo mismo: se hacía un record, se ponían las iniciales, y el Telegram/la web **no se actualizaban hasta que el jugador salía de la mesa** (a veces varios minutos después). Se probó explícitamente parado frente a la máquina esperando 1 minuto sin salir — cero avisos hasta el cierre de la mesa.

### Causa real (no era lo que parecía):
La "lectura en vivo" (v9/v10) se apoyaba en `Controller.ChangedNVRAM`, el mecanismo nativo de VPinMAME que en teoría avisa "esto cambió" en tiempo real. **En la práctica no avisa nada durante el juego** — solo refleja el volcado que VPinMAME hace a disco al cerrar la mesa. Es decir, todo el enganche estaba escuchando un timbre que nunca suena hasta el final.

### Bug extra encontrado al reconstruirlo:
De paso se encontró que la v10 (el "parche" que arreglaba el cambio de a una posición para no reescribir todo el archivo) usaba `Mid(variable, posicion, largo) = valor` para modificar un string existente. **Esa instrucción no existe en VBScript** — es exclusiva de VBA/Visual Basic 6. VBScript solo tiene el `Mid` de lectura. El error quedaba tapado por `On Error Resume Next` (silencioso), así que el parche fallaba siempre sin ningún aviso, aunque el resto de la lógica (detectar que algo cambió) funcionaba bien.

### Solución — v12, rediseño completo del enganche:
Se abandonó `ChangedNVRAM` por completo. Ahora `VP3EnVivoTick` se cuelga directo del timer propio de la mesa (`PinMAMETimer_Timer`, que ya corre solo mientras la mesa está abierta) y **lee `Controller.NVRAM` directamente**, comparando byte a byte contra la última copia guardada, con un límite de 1 vez por segundo (usando `Now`/`DateDiff`, no la función `Timer` de VBScript, para evitar cualquier choque con objetos propios de algunas mesas que también se llaman "Timer"). Si hay cualquier cambio, se reescribe el archivo `.hex` completo (nunca se intenta parchear en el lugar).

Verificado con:
- Test funcional aislado (`cscript`) con los 5 casos: primera lectura, bloqueo dentro del segundo, permiso después de 1 segundo con contenido correcto, sin reescritura si no cambió nada, dos bytes cambiados a la vez.
- Test de ida y vuelta (activar → desactivar) contra el `core.vbs` original, confirmando que queda byte a byte igual al de fábrica.
- Test en vivo real: mesa recién abierta, se generó el `.hex` correcto sin tocar nada más.

### ✅ CONFIRMADO (1 septiembre 2026):
Luis jugó, hizo record, y el Telegram llegó **al poner las iniciales**, sin salir de la mesa. Cerrado de raíz.

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
