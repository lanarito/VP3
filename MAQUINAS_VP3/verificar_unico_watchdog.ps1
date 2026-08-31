# Verifica si ya hay OTRA instancia de cmd.exe ejecutando WATCHDOG_subir_puntajes.bat
$myParentPid = (Get-CimInstance Win32_Process -Filter "ProcessId = $PID").ParentProcessId
$otros = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq 'cmd.exe' -and
    $_.CommandLine -like '*WATCHDOG_subir_puntajes.bat*' -and
    $_.ProcessId -ne $myParentPid
}
if ($otros) { exit 1 } else { exit 0 }
