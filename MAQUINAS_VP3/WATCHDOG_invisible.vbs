' ============================================================
' WATCHDOG INVISIBLE - Lanza WATCHDOG_subir_puntajes.bat en silencio
' Pone un acceso directo a este .vbs en shell:startup
' (Reemplaza el acceso directo viejo de subir_puntajes.exe)
' ============================================================

Set objShell = CreateObject("WScript.Shell")
strScriptPath = Replace(WScript.ScriptFullName, WScript.ScriptName, "") & "WATCHDOG_subir_puntajes.bat"
objShell.Run Chr(34) & strScriptPath & Chr(34), 0, False
