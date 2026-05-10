#!/usr/bin/env bash
set -euo pipefail

# v2.0 entrypoint
# - Web UI handles config writing now, so this script is mostly cleanup +
#   backward compatibility for users upgrading from v1.x who still pass env vars.

CONFIG_FILE="${CONFIG_FILE:-/data/config.env}"
mkdir -p /data /data/logs

# ---------------------------------------------------------------------------
# Backward compatibility: if env vars were provided AND no config file exists,
# write them to /data/config.env (the legacy v1.x flow)
# ---------------------------------------------------------------------------
if [[ ! -f "$CONFIG_FILE" ]] \
   && [[ -n "${UNIFI_HOST:-}" ]] \
   && [[ -n "${UNIFI_TOKEN:-}" ]] \
   && [[ -n "${POLICY_NAME:-}" ]] \
   && [[ -n "${LAT:-}" ]] \
   && [[ -n "${LNG:-}" ]]; then

  # Auto-detect timezone if not provided (same logic as v1.x)
  if [[ -z "${TZ:-}" ]]; then
    TZ_API="https://timeapi.io/api/Time/current/coordinate?latitude=${LAT}&longitude=${LNG}"
    tz="$(wget -qO- "$TZ_API" | jq -r '.timeZone // empty' 2>/dev/null || true)"
    TZ="${tz:-UTC}"
  fi

  echo "Migrating environment variables to ${CONFIG_FILE}..."
  {
    echo "# Migrated from environment variables on $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'export UNIFI_HOST=%q\n'   "$UNIFI_HOST"
    printf 'export UNIFI_TOKEN=%q\n'  "$UNIFI_TOKEN"
    printf 'export POLICY_NAME=%q\n'  "$POLICY_NAME"
    printf 'export LAT=%q\n'          "$LAT"
    printf 'export LNG=%q\n'          "$LNG"
    printf 'export TZ=%q\n'           "$TZ"
  } > "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE" || true
fi

if [[ -f "$CONFIG_FILE" ]]; then
  echo "Configuration file present at ${CONFIG_FILE}"
else
  echo "No configuration yet — open http://<host>:8080 to set up."
fi

echo "Starting supervisord (web UI on :8080 + cron daemon)..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
