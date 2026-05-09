#!/usr/bin/env bash
set -euo pipefail

# Made by Frank Gadot (https://github.com/fgadot)
# Updates the UniFi Access policy schedule with dawn/dusk times for TODAY + the next 6 days.
# This ensures all 7 weekday slots are always current, so the schedule remains valid
# even if the container is offline for several days.


need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
need curl
need jq
need date


CONFIG_FILE="${CONFIG_FILE:-/data/config.env}"

# Load persisted config (written by entrypoint.sh)
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

: "${UNIFI_HOST:?Missing UNIFI_HOST}"
: "${UNIFI_TOKEN:?Missing UNIFI_TOKEN}"
: "${POLICY_NAME:?Missing POLICY_NAME}"
: "${LAT:?Missing LAT}"
: "${LNG:?Missing LNG}"
: "${TZ:?Missing TZ}"

# ----------------------------
# 1) Fetch dawn/dusk for today + next 6 days from Sun API
#    Build a bash associative array: day_name -> "dawn|dusk"
# ----------------------------
declare -A week_times   # e.g. week_times[monday]="06:40:14|18:48:09"

today_date="$(date "+%Y-%m-%d")"
echo "Fetching dawn/dusk for 7 days starting $today_date (TZ=$TZ)..."

for offset in 0 1 2 3 4 5 6; do
  target_date="$(date -d "${today_date} + ${offset} days" "+%Y-%m-%d")"
  weekday="$(date -d "$target_date" "+%A" | tr '[:upper:]' '[:lower:]')"

  sun_json="$(curl -fsS "https://api.sunrisesunset.io/json?lat=${LAT}&lng=${LNG}&time_format=24&date=${target_date}")"

  status="$(jq -r '.status // empty' <<<"$sun_json")"
  if [[ "$status" != "OK" ]]; then
    echo "Sun API returned status='${status}' for date=${target_date}" >&2
    echo "$sun_json" >&2
    exit 1
  fi

  dawn="$(jq -r '.results.dawn' <<<"$sun_json")"
  dusk="$(jq -r '.results.dusk' <<<"$sun_json")"

  # If this weekday appears more than once in the 7-day window (can't happen, but
  # defensive: later offset wins — i.e. the further-out day overwrites the earlier one.
  # We actually want the CLOSER day to win, so only set if not already present.)
  if [[ -z "${week_times[$weekday]:-}" ]]; then
    week_times[$weekday]="${dawn}|${dusk}"
    echo "  $target_date ($weekday): dawn=$dawn  dusk=$dusk"
  else
    echo "  $target_date ($weekday): skipped (already set from earlier this week)"
  fi
done

# ----------------------------
# 2) Fetch access policies and locate policy + schedule id
# ----------------------------
policies_json="$(
  curl -fsS -k \
    -H "Authorization: Bearer ${UNIFI_TOKEN}" \
    -H "accept: application/json" \
    "${UNIFI_HOST}/api/v1/developer/access_policies"
)"

policy_id="$(
  jq -r --arg n "$POLICY_NAME" '.data[]? | select(.name==$n) | (.id // empty)' \
  <<<"$policies_json" | head -n1
)"

schedule_id="$(
  jq -r --arg n "$POLICY_NAME" '
    .data[]?
    | select(.name==$n)
    | (
        .schedule_id
        // .schedule?.id
        // (.schedules[0]?.id)
        // (.schedule_ids[0])
        // empty
      )
  ' <<<"$policies_json" | head -n1
)"

if [[ -z "${policy_id:-}" ]]; then
  echo "Policy not found: '${POLICY_NAME}'" >&2
  echo "Available policies:" >&2
  jq -r '.data[]? | "- \(.name)  (\(.id))"' <<<"$policies_json" >&2
  exit 1
fi

if [[ -z "${schedule_id:-}" ]]; then
  echo "Found policy '${POLICY_NAME}' (id=${policy_id}) but could not locate schedule id." >&2
  echo "Policy object:" >&2
  jq --arg n "$POLICY_NAME" '.data[]? | select(.name==$n)' <<<"$policies_json" >&2
  exit 1
fi

echo "Found policy '${POLICY_NAME}' id=${policy_id} schedule_id=${schedule_id}"

# ----------------------------
# 3) Fetch schedule details by ID
# ----------------------------
schedule_full="$(
  curl -fsS -k \
    -H "Authorization: Bearer ${UNIFI_TOKEN}" \
    -H "accept: application/json" \
    "${UNIFI_HOST}/api/v1/developer/access_policies/schedules/${schedule_id}"
)"

sched_name="$(jq -r '.data.name // empty' <<<"$schedule_full")"
holiday_group_id="$(jq -r '.data.holiday_group_id // ""' <<<"$schedule_full")"
holiday_schedule="$(jq -c '.data.holiday_schedule // []' <<<"$schedule_full")"

if [[ -z "$sched_name" ]]; then
  echo "Could not read schedule name for id=$schedule_id" >&2
  echo "$schedule_full" | jq . >&2
  exit 1
fi

# ----------------------------
# 4) Build payload: all 7 days populated from week_times[]
#    Days with no entry in the 7-day window (shouldn't happen) get an empty slot.
# ----------------------------

# Helper: extract dawn or dusk from "dawn|dusk" string
get_dawn() { echo "${week_times[$1]:-|}" | cut -d'|' -f1; }
get_dusk() { echo "${week_times[$1]:-|}" | cut -d'|' -f2; }

make_slot() {
  local day="$1"
  local dawn dusk
  dawn="$(get_dawn "$day")"
  dusk="$(get_dusk "$day")"
  if [[ -n "$dawn" && -n "$dusk" ]]; then
    jq -n --arg s "$dawn" --arg e "$dusk" '[{start_time:$s, end_time:$e}]'
  else
    echo "[]"
  fi
}

sun_monday="$(make_slot monday)"
sun_tuesday="$(make_slot tuesday)"
sun_wednesday="$(make_slot wednesday)"
sun_thursday="$(make_slot thursday)"
sun_friday="$(make_slot friday)"
sun_saturday="$(make_slot saturday)"
sun_sunday="$(make_slot sunday)"

payload="$(
  jq -n \
    --arg  name    "$sched_name" \
    --arg  hgid    "$holiday_group_id" \
    --argjson hs   "$holiday_schedule" \
    --argjson mon  "$sun_monday" \
    --argjson tue  "$sun_tuesday" \
    --argjson wed  "$sun_wednesday" \
    --argjson thu  "$sun_thursday" \
    --argjson fri  "$sun_friday" \
    --argjson sat  "$sun_saturday" \
    --argjson sun  "$sun_sunday" '
  {
    name: $name,
    holiday_group_id: $hgid,
    week_schedule: {
      monday:    $mon,
      tuesday:   $tue,
      wednesday: $wed,
      thursday:  $thu,
      friday:    $fri,
      saturday:  $sat,
      sunday:    $sun
    },
    holiday_schedule: $hs
  }
'
)"

echo "Updating schedule '${sched_name}' (id=${schedule_id}) for all 7 days..."
update_json="$(
  curl -fsS -k -X PUT \
    -H "Authorization: Bearer ${UNIFI_TOKEN}" \
    -H "accept: application/json" \
    -H "content-type: application/json" \
    --data-raw "$payload" \
    "${UNIFI_HOST}/api/v1/developer/access_policies/schedules/${schedule_id}"
)"

echo "$update_json" | jq .
