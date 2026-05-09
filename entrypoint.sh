#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${CONFIG_FILE:-/data/config.env}"
mkdir -p /data

# 1) Load existing config from volume (if present)
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

# 2) Apply env overrides (only if user provided them)
#    Using ${VAR+x} lets us detect "unset" vs "set to empty"
if [[ -n "${UNIFI_HOST+x}" ]]; then CFG_UNIFI_HOST="$UNIFI_HOST"; fi
if [[ -n "${UNIFI_TOKEN+x}" ]]; then CFG_UNIFI_TOKEN="$UNIFI_TOKEN"; fi
if [[ -n "${POLICY_NAME+x}" ]]; then CFG_POLICY_NAME="$POLICY_NAME"; fi
if [[ -n "${LAT+x}" ]]; then CFG_LAT="$LAT"; fi
if [[ -n "${LNG+x}" ]]; then CFG_LNG="$LNG"; fi

# Backfill CFG_* from sourced config if not overridden
CFG_UNIFI_HOST="${CFG_UNIFI_HOST:-${UNIFI_HOST:-}}"
CFG_UNIFI_TOKEN="${CFG_UNIFI_TOKEN:-${UNIFI_TOKEN:-}}"
CFG_POLICY_NAME="${CFG_POLICY_NAME:-${POLICY_NAME:-}}"
CFG_LAT="${CFG_LAT:-${LAT:-}}"
CFG_LNG="${CFG_LNG:-${LNG:-}}"

# 3) Validate we have the required values (from config OR env)
: "${CFG_UNIFI_HOST:?Missing UNIFI_HOST (env) and not found in /data/config.env}"
: "${CFG_UNIFI_TOKEN:?Missing UNIFI_TOKEN (env) and not found in /data/config.env}"
: "${CFG_POLICY_NAME:?Missing POLICY_NAME (env) and not found in /data/config.env}"
: "${CFG_LAT:?Missing LAT (env) and not found in /data/config.env}"
: "${CFG_LNG:?Missing LNG (env) and not found in /data/config.env}"

# 4) Auto-detect timezone (only if TZ not already in config/env)
if [[ -z "${TZ:-}" ]]; then
  TZ_API="https://timeapi.io/api/Time/current/coordinate?latitude=${CFG_LAT}&longitude=${CFG_LNG}"
  tz="$(wget -qO- "$TZ_API" | jq -r '.timeZone // empty' 2>/dev/null || true)"
  if [[ -z "${tz:-}" || "$tz" == "null" ]]; then
    tz="UTC"
  fi
  TZ="$tz"
fi
export TZ

# 5) Export final values for run.sh
export UNIFI_HOST="$CFG_UNIFI_HOST"
export UNIFI_TOKEN="$CFG_UNIFI_TOKEN"
export POLICY_NAME="$CFG_POLICY_NAME"
export LAT="$CFG_LAT"
export LNG="$CFG_LNG"

# 6) Persist config only when needed:
#    - if file doesn't exist, write it
#    - OR if user passed any override env vars, update it
overrode=0
[[ -n "${UNIFI_HOST+x}" ]] && overrode=1
[[ -n "${UNIFI_TOKEN+x}" ]] && overrode=1
[[ -n "${POLICY_NAME+x}" ]] && overrode=1
[[ -n "${LAT+x}" ]] && overrode=1
[[ -n "${LNG+x}" ]] && overrode=1

if [[ ! -f "$CONFIG_FILE" || "$overrode" -eq 1 ]]; then
  tmp="$(mktemp)"
  {
    printf 'UNIFI_HOST=%q\n' "$UNIFI_HOST"
    printf 'UNIFI_TOKEN=%q\n' "$UNIFI_TOKEN"
    printf 'POLICY_NAME=%q\n' "$POLICY_NAME"
    printf 'LAT=%q\n' "$LAT"
    printf 'LNG=%q\n' "$LNG"
    printf 'TZ=%q\n' "$TZ"
  } > "$tmp"
  mv "$tmp" "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE" || true
fi

echo "Using timezone: $TZ"
echo "Starting scheduler..."
exec /usr/local/bin/supercronic /app/crontab