' ============================================================
' WATCHDOG INVISIBLE - Lanza WATCHDOG_subir_puntajes.bat en silencio
' Pone un acceso directo a este .vbs en shell:startup
' (Reemplaza el acceso directo viejo de subir_puntajes.exe)
'
' ENCONTRADO 16-oct-2026: POR QUE SE LANZA DE ESTA FORMA RARA
'
' Antes esto usaba WScript.Shell.Run, que crea el watchdog como HIJO de
' quien lo llamo. Y a este .vbs lo llama PinUP Popper al arrancar (esta
' configurado en su StartupBatch). Resultado: toda la cadena del watchdog
' colgaba de Popper, asi que al salir del VP3 -- cuando Popper se cierra --
' Windows mataba el arbol entero: se morian el watchdog Y
' subir_puntajes.exe juntos.
'
' Eso explicaba el retraso del Telegram que reportaron los tres: el
' puntaje subia bien a la nube, pero el proceso moria antes de mandar el
' aviso, el aviso quedaba en la cola, y salia recien al volver a prender
' el VP3 (a veces al dia siguiente). La prueba estaba en el log del
' watchdog: tenia lineas de "Iniciando subir_puntajes.exe" pero NINGUNA
' de "se cerro" -- no registro la muerte porque murio junto con el.
'
' Ahora el proceso se crea a traves de WMI (Win32_Process.Create). Lo que
' cambia es quien queda como padre: el servicio de Windows (WmiPrvSE), no
' Popper ni la ventana que lo disparo. Asi el watchdog SOBREVIVE a que se
' cierre el VP3 y sigue mandando los avisos pendientes.
'
' Funciona igual venga de donde venga (Popper, ACTUALIZAR_VP3.bat o un
' doble click), y el mutex del supervisor sigue garantizando que nunca
' haya dos watchdogs a la vez.
' ============================================================

Dim objShell, strScriptPath, strCarpeta
Set objShell = CreateObject("WScript.Shell")
strCarpeta = Replace(WScript.ScriptFullName, WScript.ScriptName, "")
strScriptPath = strCarpeta & "WATCHDOG_subir_puntajes.bat"

Dim lanzado
lanzado = False

On Error Resume Next
Dim objWMI, objProceso, objConfig, idNuevo
Set objWMI = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
If Err.Number = 0 And Not objWMI Is Nothing Then
    Set objProceso = objWMI.Get("Win32_Process")
    ' Sin ventana: el watchdog tiene que ser invisible, como su nombre dice
    Set objConfig = objWMI.Get("Win32_ProcessStartup").SpawnInstance_
    objConfig.ShowWindow = 0
    If Err.Number = 0 Then
        Dim resultado
        resultado = objProceso.Create("cmd /c " & Chr(34) & Chr(34) & strScriptPath & Chr(34) & Chr(34), _
                                      strCarpeta, objConfig, idNuevo)
        If Err.Number = 0 And resultado = 0 Then lanzado = True
    End If
End If
Err.Clear
On Error Goto 0

' Si WMI no esta disponible por lo que sea, se lanza como antes. Queda
' colgando de quien llamo (el problema de arriba), pero es preferible a
' que el watchdog no arranque: el sistema sigue andando igual, solo que
' los avisos pueden demorar si se cierra el VP3 en el momento justo.
If Not lanzado Then
    objShell.Run Chr(34) & strScriptPath & Chr(34), 0, False
End If
