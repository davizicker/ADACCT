@echo off
REM Abre a Fábrica 3D no seu PC (dê dois cliques). Precisa de Python 3.13 instalado.
cd /d "%~dp0"
if not exist .venv_fabrica (
  echo Primeira vez: instalando (uns 5 minutos)...
  py -3.13 -m venv .venv_fabrica || python -m venv .venv_fabrica
  call .venv_fabrica\Scripts\activate
  pip install -r tools\ia3d\requirements-nuvem.txt
) else (
  call .venv_fabrica\Scripts\activate
)
REM Sem GPU/TripoSR no PC? Use a GPU grátis do Hugging Face:  set FABRICA_BACKEND=hf
if "%FABRICA_BACKEND%"=="" set FABRICA_BACKEND=hf
start http://127.0.0.1:5000
python tools\ia3d\site\app.py
pause
