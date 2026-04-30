# 📺 EPG Manager

A self-hosted web UI for fetching TV guide data via [zap2xml](https://github.com/jef/zap2xml) and generating XMLTV files for media servers like Jellyfin, Emby, Plex, or any IPTV player that accepts an XMLTV EPG feed.

![Docker Build](https://github.com/your-username/epg-manager/actions/workflows/docker-build.yml/badge.svg)

---

## Features

- **Web UI** — configure lineups, ZIP codes, and settings from the browser
- **Multi-lineup support** — fetch and merge multiple OTA / cable / satellite lineups into a single `xmltv.xml`
- **Scheduled runs** — automatically refreshes the EPG at 3:00 AM daily
- **HTTP endpoint** — serves the XMLTV file at `http://<host>:<HTTP_PORT>/xmltv`
- **Live log viewer** — watch the grabber run in real time from the UI

---

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/)

### 1. Clone the repo

```bash
git clone https://github.com/your-username/epg-manager.git
cd epg-manager
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env — set your timezone and ports
```

### 3. Start the container

```bash
docker compose up -d
```

### 4. Open the web UI

```
http://localhost:5000
```

Enter your lineup IDs and ZIP codes, then click **Run EPG Grabber** to generate your first `xmltv.xml`.

---

## Using the Pre-built Image

If you don't want to build locally, pull from the GitHub Container Registry:

```yaml
# docker-compose.yaml
services:
  tvguide:
    image: ghcr.io/n3o2345/EPG_Manager:latest
    # ... rest of config unchanged
```

Then run:

```bash
docker compose up -d
```

---

## Finding Your Lineup ID

1. Visit the [Retrieving Lineup ID guide](https://github.com/jef/zap2xml/wiki/Retrieving-Lineup-ID) on GitHub
2. Common format examples:
   - OTA (antenna): `USA-OTA65807`
   - DirecTV: `USA-DITV619-X`
   - Cable: `USA-MO61705-X`

---

## Directory Structure

```
epg-manager/
├── app.py                 # Flask web application
├── zap2xml.py             # EPG data fetcher (zap2xml port)
├── run-multi.sh           # Fetches + merges multiple lineups
├── scheduler.sh           # Runs the grabber daily at 3 AM
├── start.sh               # Container entrypoint
├── setup.sh               # TrueNAS SCALE setup helper
├── init-truenas.sh        # TrueNAS initialization script
├── Dockerfile
├── docker-compose.yaml
├── requirements.txt
├── .env.example           # Copy to .env and customize
├── templates/
│   └── index.html         # Web UI
├── config/                # Persisted settings (gitignored at runtime)
│   └── settings.json      # Created on first run
├── output/                # Generated XMLTV output (gitignored)
│   ├── xmltv.xml
│   └── logs/
└── data/                  # SQLite channel data (gitignored)
```

---

## Configuration

All settings can be managed through the web UI and are saved to `config/settings.json`.

| Setting | Default | Description |
|---|---|---|
| Lineups | — | Comma-separated lineup IDs |
| ZIP Codes | — | Comma-separated ZIP codes (one per lineup) |
| Country | `USA` | `USA` or `CAN` |
| Timespan | `72` | Hours of guide data to fetch (6–168) |
| Verbose | `1` | Logging level: `0` off, `1` normal, `2` debug |
| Output Dir | `/output` | Where `xmltv.xml` is written inside the container |
| HTTP Port | `8282` | Port for serving the XMLTV file |
| WebUI Port | `5000` | Port for the web UI |

---

## XMLTV Endpoint

Once generated, the XMLTV file is available at:

```
http://<your-host-ip>:<HTTP_PORT>/xmltv
```

Use this URL in Jellyfin, Emby, Plex, or your IPTV player as the EPG source.

---

## Environment Variables

Copy `.env.example` to `.env` and customize:

| Variable | Default | Description |
|---|---|---|
| `TZ` | `America/Chicago` | Container timezone |
| `WEBUI_PORT` | `5000` | Web UI port |
| `HTTP_PORT` | `8282` | XMLTV HTTP port |

---

## Updating

```bash
docker compose pull   # if using the pre-built image
docker compose up -d --build
```

---

## Logs

Live logs are visible in the web UI. You can also view them via Docker:

```bash
docker compose logs -f
```

Or find log files in `./output/logs/`.

---

## TrueNAS SCALE

A setup helper script (`setup.sh`) is included for TrueNAS SCALE deployments. Run it from your installation directory:

```bash
bash setup.sh
```

When deploying on TrueNAS SCALE, update `docker-compose.yaml` to use absolute paths for volumes:

```yaml
volumes:
  - /mnt/pool/appdata/epg-manager/data:/data
  - /mnt/pool/appdata/epg-manager/output:/output
  - /mnt/pool/appdata/epg-manager/config:/config
```

---

## Credits

- EPG data fetched via [zap2xml](https://github.com/jef/zap2xml) by [@jef](https://github.com/jef)
- TV schedule data provided by Gracenote / Zap2it

---

## License

MIT
