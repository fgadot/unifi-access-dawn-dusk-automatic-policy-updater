FROM alpine:3.22

RUN apk add --no-cache \
  bash \
  curl \
  jq \
  tzdata \
  ca-certificates \
 && apk upgrade --no-cache

# supercronic (cron runner) - download correct binary for arch
RUN arch="$(uname -m)" ; \
  case "$arch" in \
    x86_64)  url="https://github.com/aptible/supercronic/releases/download/v0.2.43/supercronic-linux-amd64" ;; \
    aarch64|arm64) url="https://github.com/aptible/supercronic/releases/download/v0.2.43/supercronic-linux-arm64" ;; \
    *) echo "Unsupported arch: $arch" >&2; exit 1 ;; \
  esac ; \
  curl -fsSL "$url" -o /usr/local/bin/supercronic && chmod +x /usr/local/bin/supercronic

RUN mkdir -p /data /app
WORKDIR /app

COPY entrypoint.sh /app/entrypoint.sh
COPY run.sh /app/run.sh
COPY crontab /app/crontab
RUN chmod +x /app/entrypoint.sh /app/run.sh

VOLUME ["/data"]

ENTRYPOINT ["/app/entrypoint.sh"]
