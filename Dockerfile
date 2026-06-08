# ─── Stage 1: Build node-pty (requires native compilation) ─────────────────
FROM node:22-bookworm-slim AS builder
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY package.json ./
RUN printf '[url "https://github.com/"]\n\tinsteadOf = ssh://git@github.com/\n\tinsteadOf = git@github.com:\n' > /root/.gitconfig
RUN npm install --omit=dev

# ─── Stage 2: Runtime ────────────────────────────────────────────────────────
FROM node:22-bookworm-slim
ARG OPENCLAW_VERSION=2026.5.2
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    procps \
    curl \
    git \
    ca-certificates \
    zip \
    && rm -rf /var/lib/apt/lists/*
RUN printf '[url "https://github.com/"]\n\tinsteadOf = ssh://git@github.com/\n\tinsteadOf = git@github.com:\n' > /root/.gitconfig \
    && npm install -g openclaw@${OPENCLAW_VERSION}
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY src/ ./src/
COPY public/ ./public/
COPY package.json ./

# ─── Persistent data dir ─────────────────────────────────────────────────────
RUN mkdir -p /data/.openclaw/nodes /data/.openclaw/workspace

# ─── Config do OpenClaw versionado no repositório ────────────────────────────
# Copia o openclaw.json para um path temporário.
# O entrypoint do server.js vai copiá-lo para /data/.openclaw/openclaw.json
# na inicialização, preservando credenciais do WhatsApp e outros dados do volume.
COPY config/openclaw.json /app/config/openclaw.json

ENV PATH="/app/node_modules/.bin:${PATH}"
ENV PORT=3000
ENV NODE_ENV=production
ENV OPENCLAW_DATA_DIR=/data
ENV OPENCLAW_ENTRY=/usr/local/lib/node_modules/openclaw/dist/entry.js
ENV OPENCLAW_NODE=node

EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:${PORT}/api/status || exit 1
CMD ["node", "src/server.js"]
