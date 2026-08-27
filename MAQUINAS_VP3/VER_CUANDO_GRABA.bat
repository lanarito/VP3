@echo off
REM Diagnostico para Luis (una sola vez) - NO es para los chicos.
REM Responde: VPinMAME graba el puntaje al poner las iniciales, o al salir de la mesa?
title VP3 - Cuando se graba el puntaje
color 0A
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ver_cuando_graba.ps1" %*
pause
