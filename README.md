<h1 align="center">🌊 TorrentBox</h1>
<p align="center">Blazing fast VPS torrent client — rTorrent · Flood · Filebrowser · Docker</p>

---

## Stack

| Service | Image | Role |
|---|---|---|
| **rTorrent** | `jesec/rtorrent:master` | C++ torrent engine — handles thousands of torrents |
| **Flood** | `jesec/flood:master` | Modern React web UI — dark mode, real-time stats |
| **Filebrowser** | `filebrowser/filebrowser` | Web file manager — browse & download completed files |
| **Nginx** | `nginx:alpine` | Reverse proxy — routes all traffic |

## Access

| URL | Service |
|---|---|
| `http://YOUR_VPS_IP/` | 🌊 Flood torrent UI |
| `http://YOUR_VPS_IP/files` | 📁 Filebrowser |

## Prerequisites (on VPS)

- Docker Engine 24+
- Docker Compose v2 (included in modern Docker)
- Git

```bash
# Install Docker on Ubuntu/Debian
curl -fsSL https://get.docker.com | sh
```

## Deployment

### 1. Clone

```bash
git clone https://github.com/YOUR_USERNAME/torrentbox.git
cd torrentbox
```

### 2. Deploy (one command)

```bash
bash scripts/deploy.sh
```

This will:
- Create `.env` with an auto-generated secret
- Create download directories (`./data/downloads`)
- Apply OS-level network tuning (file limits, TCP buffers)
- Pull Docker images and start all services

### 3. First-Time Flood Setup

1. Open `http://YOUR_VPS_IP/` in browser
2. Create your Flood account
3. **Client settings:**
   - Type: **rTorrent**
   - Socket: `/run/rtorrent/rtorrent.sock`
   - Base path: `/downloads`
4. Done — start adding torrents!

### 4. Filebrowser Login

- URL: `http://YOUR_VPS_IP/files`
- Default: **admin / admin** → **change on first login!**

## Manual Commands

```bash
# Start
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f

# View individual service
docker compose logs -f rtorrent
docker compose logs -f flood

# Update images
docker compose pull && docker compose up -d

# Restart a service
docker compose restart flood
```

## Configuration

### Environment Variables (`.env`)

| Variable | Default | Description |
|---|---|---|
| `FLOOD_SECRET` | auto-generated | JWT signing secret |
| `DOWNLOADS_PATH` | `./data/downloads` | Host path for downloads |
| `UID` / `GID` | `1000` / `1000` | Run containers as this user |

### rTorrent Tuning (`rtorrent/.rtorrent.rc`)

Key settings for 12GB RAM VPS:

| Setting | Value | Effect |
|---|---|---|
| `pieces.memory.max` | `6144M` | 6GB piece cache = max speed |
| `throttle.max_peers.normal` | `200` | 200 peers per torrent |
| `network.max_open_files` | `65536` | High FD limit |
| DHT / PEX | enabled | Better peer discovery |

### Custom Download Path

Edit `.env`:
```bash
DOWNLOADS_PATH=/mnt/volume/downloads
```

Then `docker compose up -d` — volumes update automatically.

## Architecture

```
Internet
    │
    ▼ :80
┌─────────┐
│  Nginx  │  Reverse proxy
└────┬────┘
     ├─── / ──────────────▶ Flood :3000
     └─── /files ─────────▶ Filebrowser :80
                                │
     Flood ──(unix socket)──▶ rTorrent
                                │
                           📁 /downloads
```

## Ports

| Port | Protocol | Purpose |
|---|---|---|
| `80` | TCP | Web UI (Nginx) |
| `6881` | TCP+UDP | BitTorrent |

## Troubleshooting

**Flood can't connect to rTorrent:**
```bash
docker compose logs rtorrent
# Check socket exists:
docker exec rtorrent ls -la /run/rtorrent/
```

**Permission errors:**
```bash
# Check UID/GID in .env matches your user:
id -u && id -g
```

**Downloads not visible in Filebrowser:**
- Ensure `DOWNLOADS_PATH` is correct in `.env`
- Both services mount the same `downloads` volume

---

<p align="center">Made with ⚡ — rTorrent + Flood + Docker</p>
