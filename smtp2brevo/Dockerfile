FROM node:24-alpine

LABEL org.opencontainers.image.title="smtp2brevo" \
      org.opencontainers.image.description="Authenticated TLS SMTP relay for the Brevo HTTPS API" \
      org.opencontainers.image.source="https://github.com/CyrusAuyeung/Blindot-API" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts \
    && npm cache clean --force

COPY --chown=node:node server.js healthcheck.js ./

EXPOSE 8025

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["node", "healthcheck.js"]

CMD ["node", "server.js"]
