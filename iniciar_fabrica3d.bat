@echo off
chcp 65001 >nul
REM FABRICA 3D - DE DOIS CLIQUES. Instala o Python sozinho se faltar e abre o site no navegador.
cd /d "%~dp0"
title Fabrica 3D (feche esta janela para desligar)

REM 1) acha o Python 3.13 (ou instala)
set PY=
py -3.13 --version >nul 2>&1 && set PY=py -3.13
if "%PY%"=="" (
  echo Python 3.13 nao encontrado. Instalando sozinho pelo Windows ^(winget^)...
  winget install -e --id Python.Python.3.13 --silent --accept-package-agreements --accept-source-agreements
  py -3.13 --version >nul 2>&1 && set PY=py -3.13
)
if "%PY%"=="" (
  echo.
  echo Nao consegui instalar o Python sozinho.
  echo Instale em https://www.python.org/downloads/release/python-3139/ marcando "Add python.exe to PATH"
  echo e de dois cliques neste arquivo de novo.
  pause
  exit /b 1
)

REM 2) token opcional do Hugging Face: crie um arquivo "token.txt" nesta pasta com o texto hf_...
if exist token.txt set /p HF_TOKEN=<token.txt

REM 3) instala so na primeira vez
if not exist .venv_fabrica\Scripts\python.exe (
  echo Primeira vez: instalando ^(5 a 10 minutos, so uma vez^)...
  %PY% -m venv .venv_fabrica || goto erro
  .venv_fabrica\Scripts\python -m pip install -r tools\ia3d\requirements-nuvem.txt || goto erro
)

REM 4) abre
if "%FABRICA_BACKEND%"=="" set FABRICA_BACKEND=hf
start "" http://127.0.0.1:5000
.venv_fabrica\Scripts\python tools\ia3d\site\app.py
pause
exit /b 0

:erro
echo.
echo DEU ERRO na instalacao. Tire uma foto/copie o texto acima e mande para mim.
pause
exit /b 1
