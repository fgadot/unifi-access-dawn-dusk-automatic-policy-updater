# UniFi Access Dawn/Dusk Policy Scheduler
**Made by Frank Gadot**

This container updates a **UniFi Access Policy schedule** daily so it opens at **dawn** and closes at **dusk**, based on your **latitude/longitude**.

✅ **Web UI** for first-time setup, live status, and on-demand runs (no command line needed)
✅ Updates **all 7 days of the week** every run — today + the next 6 days
✅ Runs automatically every day at **1:00 AM local time** (timezone is auto-detected from LAT/LNG)
✅ Persists your settings across restarts using a Docker **named volume**
✅ Works on **Windows / macOS / Linux** (Docker Desktop or Docker Engine)
✅ Supports **Intel (amd64)** and **Apple Silicon / ARM (arm64)**

---

## What's new in v2.0

- **Built-in web dashboard** at `http://<host>:8080` for setup, monitoring, and on-demand runs
- **Test & Load button** — validates your UniFi credentials and auto-populates the policy list
- **Run Now button** — trigger a schedule update on demand instead of waiting for the cron tick
- **Status banner** — see at a glance whether the last run succeeded, with today's dawn/dusk times
- **Recent activity log** — tail the last 200 lines of run history right in the browser
- **Backward compatible** — v1.x environment-variable configuration still works

---

## What does it do exactly?
Every day at **1:00 AM** (local time), it:
1. Calls the sunrise/sunset API for each of the next 7 days (today through 6 days ahead)
2. Converts dawn/dusk to 24h time for each day
3. Finds your UniFi Access policy by `POLICY_NAME`
4. Updates that policy's schedule for **all 7 weekday slots** in a single API call, using the correct dawn/dusk times for each specific date

> **Why 7 days?** If the container goes offline for any reason, your schedule stays accurate for up to a week — not just today. When it comes back online, it immediately re-syncs all 7 days.

> **Example:** If today is Wednesday, the schedule will be updated for Wednesday, Thursday, Friday, Saturday, Sunday, Monday, and Tuesday — each with their own correct dawn/dusk times.

---

## Requirements
- A machine that can reach your UniFi Access controller (same LAN or VLAN)
- A UniFi Access API token with permission to read policies and update schedules
- Docker Desktop (Windows/macOS) or Docker Engine (Linux)
- The latitude and longitude of the location you want sunrise and sunset times

### Get your latitude and longitude
-> Go to https://sunrisesunset.io
-> Enter your ZIP Code (USA) or address / town / country
-> Note your latitude and longitude in the top right, **including the minus sign `-` if there is one**

### Create a UniFi Access API Token
1. Login to your UniFi console
2. Go to the **ACCESS** application
3. Go to **Settings**, and where it says **API Token**, click **Create New**
4. Give your API a name, and save the token somewhere safe. **This is the only time you will see the full token.** Once you close the window, it is gone.

---

# Scenario Guide (Most Common Tasks)

## 1) First-time setup with the Web UI (recommended)

This is the easiest path — no environment variables, no command-line config, point-and-click.

### Step 1: Start the container

```bash
docker run -d --restart=unless-stopped \
  --name unifi-dawn-dusk \
  -p 8080:8080 \
  -v unifi-dawn-dusk-data:/data \
  fgc92/unifi-access-dawn-dusk:latest
```

### Step 2: Open the web UI

Open `http://<host>:8080` in any browser on the same network (replace `<host>` with the IP of the machine running Docker).

You'll see a setup form. Fill in:

| Field | Example |
|---|---|
| **UniFi Console URL** | `https://192.168.40.10:12445` |
| **UniFi API Token** | (your token) |
| **Policy Name** | `Swimming pool` |
| **Latitude / Longitude** | `27.26 / -82.22` |
| **Timezone** | `America/New_York` |

### Step 3: Test & Load (optional but recommended)

Click the **Test & Load** button next to the API Token field. The container will reach out to your UniFi controller, validate the credentials, and turn the Policy Name field into a dropdown of your real policies — no typos, no guessing.

### Step 4: Save and Run

Click **Save Configuration**. You'll land on the dashboard. Click **Run now** to trigger the first schedule update immediately, or wait for the daily 1:00 AM cron tick.

A green status banner means it worked. 🌅

---

## 2) First-time setup with environment variables (v1.x compatible)

If you prefer to set everything up via `docker run`, this still works exactly like v1.x.

```bash
docker run -d --restart=unless-stopped \
  --name unifi-dawn-dusk \
  -p 8080:8080 \
  -e UNIFI_HOST="https://your_unifi_IP_Address:12445" \
  -e UNIFI_TOKEN="YOUR_API_TOKEN_HERE" \
  -e POLICY_NAME="YOUR_POLICY_NAME" \
  -e LAT="YOUR_LATITUDE" \
  -e LNG="YOUR_LONGITUDE" \
  -v unifi-dawn-dusk-data:/data \
  fgc92/unifi-access-dawn-dusk:latest
```

The first time the container starts, your env vars are written to `/data/config.env` and used from there onward.

> **Tip:** Even with env-var setup, the web UI at port 8080 is still available for monitoring and live runs. If you don't want it exposed, omit `-p 8080:8080`.

---

## 3) First-time setup with Docker Desktop UI

For users who prefer the Docker Desktop GUI over the command line.

1. Open **Docker Desktop**
2. Search Docker Hub for `fgc92/unifi-access-dawn-dusk`
3. Pull the image
4. Click **Run** with these settings:
   - **Container name**: `unifi-dawn-dusk`
   - **Ports**: Host port `8080` → Container port `8080`
   - **Volumes**: Host path `unifi-dawn-dusk-data` → Container path `/data`
   - **Restart policy**: `Unless stopped`
5. Click **Run** — no environment variables needed
6. Open `http://localhost:8080` in your browser and follow the web UI flow above

---

## Required configuration reference

These values must be provided at least once (via web UI or env vars). They will be saved persistently.

| Variable | Example | Notes |
|---|---|---|
| `UNIFI_HOST` | `https://your_unifi_ip_address:12445` | UniFi Access controller base URL |
| `UNIFI_TOKEN` | `xxxx` | UniFi Access API token |
| `POLICY_NAME` | `Swimming pool` | UniFi policy name **(CASE SENSITIVE)** |
| `LAT` | `##.#####` | Latitude **(include minus sign if negative)** |
| `LNG` | `##.#####` | Longitude **(include minus sign if negative)** |
| `TZ` | `America/New_York` | IANA timezone. Auto-detected if omitted in env-var setup |

---

## To validate immediately

The easiest way: click **Run now** in the web UI dashboard. Or from the shell:

```bash
docker exec -it unifi-dawn-dusk bash -lc '/app/run.sh'
```

A successful run will show dawn/dusk times for all 7 days, then print `SUCCESS` in the API response. Example:

```
Fetching dawn/dusk for 7 days starting 2026-03-30 (TZ=America/New_York)...
  2026-03-30 (monday):    dawn=06:28:11  dusk=19:42:05
  2026-03-31 (tuesday):   dawn=06:26:44  dusk=19:43:21
  2026-04-01 (wednesday): dawn=06:25:17  dusk=19:44:37
  2026-04-02 (thursday):  dawn=06:23:50  dusk=19:45:53
  2026-04-03 (friday):    dawn=06:22:23  dusk=19:47:09
  2026-04-04 (saturday):  dawn=06:20:57  dusk=19:48:25
  2026-04-05 (sunday):    dawn=06:18:55  dusk=19:48:44
Found policy 'Swimming pool' id=xxxxx-xxx-xx-xxxx schedule_id=yyyy-yy-yyy-yy
Updating schedule 'pool-schedule-example' (id=yyy-yyy-yyy) for all 7 days...
{
  "code": "SUCCESS",
  "data": {},
  "msg": "success"
}
```

---

# FAQ

### Stop the container
```bash
docker stop unifi-dawn-dusk
```

### Start the container
```bash
docker start unifi-dawn-dusk
```

### Restart the container (no need to re-enter parameters)
```bash
docker restart unifi-dawn-dusk
```

### Change any setting (API token, Policy Name, Lat/Lng)
Easiest: open `http://<host>:8080` and click **Edit** in the configuration card on the dashboard.

Alternatively, recreate the container with new env vars:
```bash
docker rm -f unifi-dawn-dusk
docker run -d --restart=unless-stopped \
  --name unifi-dawn-dusk \
  -p 8080:8080 \
  -e UNIFI_HOST="https://your_unifi_ip_address:12445" \
  -e UNIFI_TOKEN="NEW_API_TOKEN_HERE" \
  -e POLICY_NAME="NEW_POLICY_NAME_HERE" \
  -e LAT="YOUR_LAT" \
  -e LNG="YOUR_LONG" \
  -v unifi-dawn-dusk-data:/data \
  fgc92/unifi-access-dawn-dusk:latest
```

### Edit the configuration directly (Advanced)
Configuration is stored in `/data/config.env`.

View config:
```bash
docker exec -it unifi-dawn-dusk bash -lc 'cat /data/config.env'
```

Edit config inside the container:
```bash
docker exec -it unifi-dawn-dusk bash -lc 'apk add --no-cache nano && nano /data/config.env'
```

Apply changes:
```bash
docker restart unifi-dawn-dusk
```

### What if I delete the volume?
All settings will be deleted. You will need to restart from scratch via the web UI or env vars.

### Can I run multiple instances for different policies?
Yes. Use different container names, different host ports, and different volumes:
```bash
docker run -d --name dawn-dusk-pool   -p 8080:8080 -v pool-data:/data   fgc92/unifi-access-dawn-dusk:latest
docker run -d --name dawn-dusk-gate   -p 8081:8080 -v gate-data:/data   fgc92/unifi-access-dawn-dusk:latest
```

---

# Troubleshooting

**Web UI is unreachable**
Confirm the container is running with `docker ps`. Make sure you exposed port 8080 with `-p 8080:8080`. From the Docker host, try `curl http://localhost:8080/healthz` — it should return `ok`.

**Test & Load button fails or times out**
The container can't reach your UniFi controller. Check the controller IP/port are correct, that the container's network can route to it (in UniFi multi-VLAN setups, you may need a firewall rule allowing the container's VLAN to reach the UniFi VLAN), and that the API token is valid.

**Policy not found**
`POLICY_NAME` is case sensitive. Use **Test & Load** to populate a dropdown of your real policies and avoid typos.

**Unauthorized / no permission**
Generate a new API token and update `UNIFI_TOKEN`. Ensure the token has permission to read policies and update schedules.

**Controller HTTPS / self-signed cert**
The container uses `curl -k` and Python `requests(verify=False)` to allow HTTPS connections to private controllers with self-signed certificates.

**Timezone looks wrong**
Timezone is auto-detected from LAT/LNG when using env-var setup. With the web UI, you set it explicitly. Verify your coordinates (including minus signs) and re-save.

**Schedule stopped updating for a few days**
Because each run updates all 7 days ahead, your pool schedule will remain accurate for up to a week even if the container is offline. Once it comes back online, all 7 days are re-synced automatically.

---

# Notes / Security

Your token is stored inside the Docker volume (`/data/config.env`) with file mode `0600`. Treat it like a password.

The web UI on port 8080 has **no authentication** and exposes the masked last 4 characters of your token in the dashboard. It's intended for trusted LAN deployments only. If you need to expose the UI externally, put it behind a reverse proxy (Nginx, Caddy, Traefik) with HTTP basic auth or your SSO of choice.

---

# Architecture (v2.0)

The container runs two processes managed by `supervisord`:

1. **Web UI** — Flask app served by gunicorn on port 8080. Handles configuration, status display, and on-demand `Run now` invocations.
2. **Cron daemon** — supercronic reads `/app/crontab` and executes `run.sh` daily at 1:00 AM local time.

Both processes share `/data/config.env` (settings) and `/data/last_run.json` (status), plus a rolling log at `/data/logs/run.log` capped at ~1000 lines.

---

# VERSIONS
2.0.2 - Updated README for v2.0 features
2.0.1 - Added coreutils to fix GNU date support on busybox-based Alpine
2.0.0 - Web UI for setup and monitoring; Run Now button; status dashboard; Test & Load for live UniFi validation; new docker run command (`-p 8080:8080`)
1.3.0 - Migrated build to GitHub Actions for automated multi-arch (amd64 + arm64) Docker Hub publishing
1.2 - Update all 7 days of the week (today + next 6 days) on every run for resilience against downtime
1.1 - Fix persistent data, so if docker is deleted, a new one will use old data unless overwritten
1.0.1 - Initial commit
