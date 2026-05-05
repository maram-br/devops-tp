# ── Stage 1 : Build / Install ──────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

# Sécurité : pas de cache pip, pas de bytecode
COPY app/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2 : Runtime minimal ──────────────────────────────────────────────
FROM python:3.12-slim

# Métadonnées OCI
LABEL org.opencontainers.image.title="flask-devops-app" \
      org.opencontainers.image.description="Application support pour le TP DevOps" \
      org.opencontainers.image.version="1.0"

# Bonne pratique : utilisateur non-root
RUN useradd --no-create-home --shell /bin/false appuser

WORKDIR /app

# Copie des dépendances pré-installées
COPY --from=builder /install /usr/local

# Copie du code source
COPY app/ .

# Droits minimal
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 5000

# Utiliser gunicorn en prod (pas le serveur de dev Flask)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--threads", "2", "app:app"]
