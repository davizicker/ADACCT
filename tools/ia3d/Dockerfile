# Fábrica 3D na nuvem (Render). Contexto de build: tools/ia3d (veja render.yaml na raiz do repositório).
FROM python:3.13-slim
ENV PYTHONUNBUFFERED=1 MODO_NUVEM=1 DATA_DIR=/tmp/modelos FABRICA_BACKEND=hf
# bibliotecas que o Blender (pacote bpy) precisa mesmo sem tela
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 libegl1 libxi6 libxrender1 libxkbcommon0 libsm6 libxxf86vm1 libxfixes3 libgomp1 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements-nuvem.txt .
# o bpy exige numpy<2 (1.26.4), que NÃO tem pacote pronto para Python 3.13: precisa compilar (uns 5-10 min).
# As ferramentas de compilação entram e saem na mesma camada para a imagem não engordar.
RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
    && pip install --no-cache-dir -r requirements-nuvem.txt \
    && apt-get purge -y build-essential && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*
COPY . .
ENV PYTHONPATH=/app/site:/app
# 1 processo + várias threads: os trabalhos ficam na memória do processo
CMD gunicorn app:app --bind 0.0.0.0:${PORT:-10000} --workers 1 --threads 8 --timeout 900
