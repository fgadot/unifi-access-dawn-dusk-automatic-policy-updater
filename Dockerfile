FROM alpine:3.22

# ---------------------------------------------------------------------------
# Runtime dependencies:
#   - bash, curl, jq, wget       core scripting
#   - tzdata, ca-certificates    HTTPS + timezone support
#   - python3 + flask            web UI
#   - gunicorn                   production WSGI server
#   - requests + urllib3         UniFi API calls from Flask
#   - supervisor                 process manager (gunicorn + cron in one container)
# ---------------------------------------------------------------------------
RUN apk add --no-cache \
      bash \
      coreutils \
      curl \
      wget \
      jq \
      tzdata \
      ca-certificates \
      python3 \
      py3-flask \
      py3-gunicorn \
      py3-requests \
      py3-urllib3 \
      supervisor \
 && apk upgrade --no-cache

# supercronic (cron runner) — download correct binary for arch
RUN arch="$(uname -m)" ; \
    case "$arch" in \
      x86_64)         url="https://github.com/aptible/supercronic/releases/download/v0.2.43/supercronic-linux-amd64" ;; \
      aarch64|arm64)  url="https://github.com/aptible/supercronic/releases/download/v0.2.43/supercronic-linux-arm64" ;; \
      *)              echo "Unsupported arch: $arch" >&2; exit 1 ;; \
    esac ; \
    curl -fsSL "$url" -o /usr/local/bin/supercronic \
 && chmod +x /usr/local/bin/supercronic

RUN mkdir -p /data /data/logs /app /app/web
WORKDIR /app

# Application files
COPY entrypoint.sh    /app/entrypoint.sh
COPY run.sh           /app/run.sh
COPY crontab          /app/crontab
COPY supervisord.conf /etc/supervisord.conf
COPY web/             /app/web/

RUN chmod +x /app/entrypoint.sh /app/run.sh

VOLUME ["/data"]
EXPOSE 8080

# Container is healthy if the web UI responds on /healthz
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS http://localhost:8080/healthz || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
