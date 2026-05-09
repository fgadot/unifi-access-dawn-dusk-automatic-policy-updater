# UniFi Access Dawn/Dusk Policy Scheduler
**Made by Frank Gadot**

This container updates a **UniFi Access Policy schedule** daily so it opens at **dawn** and closes at **dusk**, based on your **latitude/longitude**.

✅ Updates **all 7 days of the week** every run — today + the next 6 days  
✅ Runs automatically every day at **1:00 AM local time** (timezone is auto-detected from LAT/LNG)  
✅ Persists your settings across restarts using a Docker **named volume**  
✅ Works on **Windows / macOS / Linux** (Docker Desktop or Docker Engine)  
✅ Supports **Intel (amd64)** and **Apple Silicon / ARM (arm64)**

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
- A machine that can reach your UniFi Access controller (same LAN or VPN)
- A UniFi Access API token with permission to read policies and update schedules
- Docker Desktop (Windows/macOS) or Docker Engine (Linux)
- The latitude and longitude of the location you want sunrise and sunset times

### Get your latitude and longitude
-> Go to https://sunrisesunset.io  
-> Enter your ZIP Code (USA) or address / town / country  
-> Note your latitude and longitude in the top right, **including the minus sign `-` if there is one**

---

## Configuration (required)
These must be provided at least once (first run). They will be saved persistently.

| Variable | Example | Notes |
|---|---|---|
| `UNIFI_HOST` | `https://your_unifi_ip_address:12445` | UniFi Access controller base URL |
| `UNIFI_TOKEN` | `xxxx` | UniFi Access API token |
| `POLICY_NAME` | `Swimming pool` | UniFi policy name **(CASE SENSITIVE)** |
| `LAT` | `##.#####` | Latitude **(include minus sign if negative)** |
| `LNG` | `##.#####` | Longitude **(include minus sign if negative)** |

---

# Scenario Guide (Most Common Tasks)

## Create a UniFi Access API Token
1. Login to your UniFi console
2. Go to the **ACCESS** application
3. Go to **Settings**, and where it says **API Token**, click **Create New**
4. Give your API a name, and save the token somewhere safe. **This is the only time you will see the full token.** Once you close the window, it is gone.

---

## 1) First-time start (Docker Desktop UI — no file editing, no console needed)
This is the easiest path for most admins.

### Step-by-step (Docker Desktop)
1. Open **Docker Desktop**
2. Go to **Docker Hub**
3. Pull: `fgc92/unifi-access-dawn-dusk:latest`
4. After it appears in Images, click **Run**
5. In the Run settings, configure the following:

### A) Environment Variables
Add each of these as a separate environment variable:
- `UNIFI_HOST` = `https://your_unifi_IP_Address:12445`
- `UNIFI_TOKEN` = `YOUR_API_TOKEN_HERE`
- `POLICY_NAME` = `YOUR_POLICY_NAME`
- `LAT` = `YOUR_LATITUDE`
- `LNG` = `YOUR_LONGITUDE`

### B) Persistent Storage
In Docker Desktop Run settings, find **Volumes**:
- Host path: `unifi-dawn-dusk-data`
- Container path: `/data`

### C) Restart Policy
- Set Restart policy: **Unless stopped**

6. Click **Run**

✅ Your container is now running and will execute daily at **1:00 AM local time**.

---

## 2) First-time start (Command line)

```bash
docker run -d --restart=unless-stopped \
  --name unifi-dawn-dusk \
  -e UNIFI_HOST="https://your_unifi_IP_Address:12445" \
  -e UNIFI_TOKEN="YOUR_API_TOKEN_HERE" \
  -e POLICY_NAME="YOUR_POLICY_NAME" \
  -e LAT="YOUR_LATITUDE" \
  -e LNG="YOUR_LONGITUDE" \
  -v unifi-dawn-dusk-data:/data \
  fgc92/unifi-access-dawn-dusk:latest
```

---

## To validate immediately
Run the following command from your shell:
```bash
docker exec -it CONTAINER_NAME bash -lc '/app/run.sh'
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
docker stop YOUR_CONTAINER_NAME
```

### Start the container
```bash
docker start YOUR_CONTAINER_NAME
```

### Restart the container (no need to re-enter parameters)
```bash
docker restart YOUR_CONTAINER_NAME
```

### Change any setting (API token, Policy Name, Lat/Lng)
```bash
docker rm -f unifi-dawn-dusk
```
then re-run with the new values:
```bash
docker run -d --restart=unless-stopped \
  --name unifi-dawn-dusk \
  -e UNIFI_HOST="https://your_unifi_ip_address:12445" \
  -e UNIFI_TOKEN="NEW_API_TOKEN_HERE" \
  -e POLICY_NAME="NEW_POLICY_NAME_HERE" \
  -e LAT="YOUR_LAT" \
  -e LNG="YOUR_LONG" \
  -v unifi-dawn-dusk-data:/data \
  fgc92/unifi-access-dawn-dusk:latest
```

### Edit the configuration directly (Advanced)
Configuration is stored in `/data/config.env`

View config:
```bash
docker exec -it unifi-dawn-dusk bash -lc 'cat /data/config.env'
```

Edit config inside container:
```bash
docker exec -it unifi-dawn-dusk bash -lc 'nano /data/config.env'
```

Apply changes:
```bash
docker restart unifi-dawn-dusk
```

### What if I delete the volume?
All settings will be deleted. You will need to restart from scratch.

---

# Troubleshooting

**Policy not found**  
`POLICY_NAME` is case sensitive. Make sure the policy exists in UniFi Access and matches exactly.

**Unauthorized / no permission**  
Generate a new API token and update `UNIFI_TOKEN`. Ensure the token has permission to read policies and update schedules.

**Controller HTTPS / self-signed cert**  
This container uses `curl -k` to allow HTTPS connections to private controllers with self-signed certificates.

**Timezone looks wrong**  
Timezone is auto-detected from LAT/LNG. Verify your coordinates (including minus signs) and restart/recreate the container to regenerate the config.

**Schedule stopped updating for a few days**  
Because each run updates all 7 days ahead, your pool schedule will remain accurate for up to a week even if the container is offline. Once it comes back online, all 7 days are re-synced automatically.

---

# Notes / Security
Your token is stored inside the Docker volume (`/data/config.env`). Treat it like a password.  
If you share the host machine, protect Docker access to prevent others from reading the volume.

---

# VERSIONS
1.3.0 - Migrated build to GitHub Actions for automated multi-arch (amd64 + arm64) Docker Hub publishing  
1.2 - Update all 7 days of the week (today + next 6 days) on every run for resilience against downtime  
1.1 - Fix persistent data, so if docker is deleted, a new one will use old data unless overwritten  
1.0.1 - Initial commit
