@echo off
REM VP3 - Activar o desactivar la lectura en vivo a mano.
REM Normalmente NO hace falta: ACTUALIZAR_VP3.bat ya la deja activada.
title VP3 - Lectura en vivo
color 0A
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0activar_lectura_en_vivo.ps1"
