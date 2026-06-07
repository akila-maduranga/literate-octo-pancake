#!/usr/bin/env bash
# ================================================================
# TorrentBox — VPS Deploy Script
# Run this ONCE on your VPS to bootstrap the entire stack
# Usage: bash scripts/deploy.sh
# ================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR]${NC}   $*"; exit 1; }

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════╗"
echo "║         TorrentBox — VPS Deploy          ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ── 1. Check prerequisites ────────────────────────────────────
info "Checking prerequisites..."
command -v docker      >/dev/null 2>&1 || error "Docker not installed. Install: https://docs.docker.com/engine/install/"
command -v git         >/dev/null 2>&1 || error "Git not installed. Run: apt-get install git"
docker compose version >/dev/null 2>&1 || error "Docker Compose v2 not found. Update Docker Desktop or install plugin."
success "All prerequisites met."

# ── 2. Setup .env ─────────────────────────────────────────────
if [ ! -f .env ]; then
  info "Creating .env from template..."
  cp .env.example .env

  # Auto-generate a secure FLOOD_SECRET
  SECRET=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 48)
  sed -i "s/change_me_to_a_long_random_secret_string_here/${SECRET}/" .env
  success ".env created with auto-generated secret."
else
  warn ".env already exists — skipping."
fi

# ── 3. Create download directories ───────────────────────────
DOWNLOADS_PATH=$(grep '^DOWNLOADS_PATH' .env | cut -d= -f2 | tr -d ' ')
DOWNLOADS_PATH="${DOWNLOADS_PATH:-./data/downloads}"

info "Creating directories: ${DOWNLOADS_PATH}, ${DOWNLOADS_PATH}/watch, ${DOWNLOADS_PATH}/incomplete"
mkdir -p "${DOWNLOADS_PATH}"
mkdir -p "${DOWNLOADS_PATH}/watch"
mkdir -p "${DOWNLOADS_PATH}/incomplete"

# Fix permissions (run as current user)
UID_VAL=$(id -u)
GID_VAL=$(id -g)
chown -R "${UID_VAL}:${GID_VAL}" "${DOWNLOADS_PATH}" 2>/dev/null || true
chmod -R 755 "${DOWNLOADS_PATH}"

# Update UID/GID in .env
sed -i "s/^UID=.*/UID=${UID_VAL}/" .env
sed -i "s/^GID=.*/GID=${GID_VAL}/" .env
success "Directories ready. UID=${UID_VAL} GID=${GID_VAL}"

# ── 4. OS-level tuning ────────────────────────────────────────
info "Applying OS performance tuning..."

# Increase open file limits
if ! grep -q "torrentbox" /etc/security/limits.conf 2>/dev/null; then
  cat >> /etc/security/limits.conf <<'EOF'
# TorrentBox
* soft nofile 65536
* hard nofile 65536
EOF
fi

# Kernel network tuning
sysctl -w net.core.rmem_max=16777216     >/dev/null 2>&1 || true
sysctl -w net.core.wmem_max=16777216     >/dev/null 2>&1 || true
sysctl -w net.core.netdev_max_backlog=65536 >/dev/null 2>&1 || true
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216" >/dev/null 2>&1 || true
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216" >/dev/null 2>&1 || true
success "OS tuning applied."

# ── 5. Pull images ────────────────────────────────────────────
info "Pulling Docker images (this may take a minute)..."
docker compose pull
success "Images pulled."

# ── 6. Start stack ────────────────────────────────────────────
info "Starting TorrentBox stack..."
docker compose up -d --remove-orphans
success "Stack started!"

# ── 7. Wait and verify ────────────────────────────────────────
info "Waiting for services to be healthy (up to 60s)..."
sleep 10

MAX_WAIT=60
WAITED=0
while ! docker compose ps | grep -q "healthy"; do
  sleep 5
  WAITED=$((WAITED + 5))
  if [ $WAITED -ge $MAX_WAIT ]; then
    warn "Services took longer than expected. Check: docker compose logs"
    break
  fi
done

echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}   ✅  TorrentBox is running!               ${NC}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════${NC}"

VPS_IP=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "YOUR_VPS_IP")
echo ""
echo -e "  🌊 Flood UI:     ${BOLD}http://${VPS_IP}/${NC}"
echo -e "  📁 Filebrowser:  ${BOLD}http://${VPS_IP}/files${NC}"
echo ""
echo -e "  First-time setup:"
echo -e "  1. Open Flood URL → Create account"
echo -e "  2. Client: rTorrent | Socket: ${CYAN}/run/rtorrent/rtorrent.sock${NC}"
echo -e "  3. Download path: ${CYAN}/downloads${NC}"
echo ""
echo -e "  Filebrowser default login: ${CYAN}admin / admin${NC} (change on first login!)"
echo ""
