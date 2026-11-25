@echo off
setlocal
cd /d "%~dp0"
python -u lab8_ensayo_sincronizado.py --expected-mode MONITOR --label monitor_lab8
set "CODIGO=%ERRORLEVEL%"
echo.
if "%CODIGO%"=="0" (
  echo Captura MONITOR completada y validada preliminarmente.
) else (
  echo Captura incompleta o no valida. Revise metadatos.json.
)
pause
exit /b %CODIGO%
