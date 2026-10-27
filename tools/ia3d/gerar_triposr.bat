@echo off
REM Uso: gerar_triposr.bat minha_imagem.png
REM Rode DENTRO da pasta TripoSR, com o venv ativado (veja LEIA-ME.md).
python run.py %1 --output-dir saida --bake-texture --texture-resolution 2048
echo Pronto. Veja a pasta saida\0
pause
