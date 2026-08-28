@echo off
REM Prueba para Luis: se puede leer el puntaje sin salir de la mesa?
REM IMPORTANTE: ejecutar CON UNA MESA ABIERTA Y JUGANDO.
title VP3 - Se puede leer sin salir de la mesa?
color 0B
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0probar_lectura_en_vivo.ps1"
