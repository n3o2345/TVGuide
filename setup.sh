#!/bin/bash
set -euo pipefail

# TrueNAS SCALE Zap2XML Setup Script
echo "========================================="
echo "TrueNAS SCALE - Zap2XML TVGuide Setup"
echo "========================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on TrueNAS SCALE
if [ ! -f /etc/version ]; then
    echo -e "${YELLOW}Warning: This doesn't appear to be TrueNAS SCALE${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Get installation directory
DEFAULT_DIR="/mnt/$(ls /mnt | head -1)/appdata/zap2xml"
echo -e "${GREEN}Where would you like to install?${NC}"
read -p "Installation directory [$DEFAULT_DIR]: " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-$DEFAULT_DIR}

# Create directories
echo -e "\n${GREEN}Creating directories...${NC}"
mkdir -p "$INSTALL_DIR"/{config,output,data,output/logs}
chmod -R 755 "$INSTALL_DIR"

cd "$INSTALL_DIR"

# Create .env file
echo -e "\n${GREEN}Configuring environment...${NC}"
read -p "WebUI port [5000]: " WEBUI_PORT
WEBUI_PORT=${WEBUI_PORT:-5000}

read -p "XMLTV HTTP port [8282]: " HTTP_PORT
HTTP_PORT=${HTTP_PORT:-8282}

read -p "Your timezone [America/Chicago]: " TZ
TZ=${TZ:-America/Chicago}

cat > .env <<EOF
HTTP_PORT=$HTTP_PORT
WEBUI_PORT=$WEBUI_PORT
TZ=$TZ
LOG_DIR=/output/logs
PYTHONUNBUFFERED=1
EOF

echo -e "${GREEN}Created .env file${NC}"

# Check if files exist
if [ ! -f "docker-compose.yml" ]; then
    echo -e "\n${YELLOW}Docker Compose files not found in current directory${NC}"
    echo "Please ensure the following files are in $INSTALL_DIR:"
    echo "  - docker-compose.yml"
    echo "  - Dockerfile"
    echo "  - requirements.txt"
    echo "  - app.py"
    echo "  - zap2xml.py"
    echo "  - run-multi.sh"
    echo "  - scheduler.sh"
    echo "  - index.html"
    echo ""
    read -p "Press Enter after copying files..."
fi

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker not found${NC}"
    echo "Docker should be installed with TrueNAS SCALE"
    exit 1
fi

# Check for Docker Compose
if ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose not found${NC}"
    exit 1
fi

# Build the image
echo -e "\n${GREEN}Building Docker image...${NC}"
docker build -t zap2xml:latest . || {
    echo -e "${RED}Build failed!${NC}"
    exit 1
}

echo -e "${GREEN}Build successful!${NC}"

# Start the container
echo -e "\n${GREEN}Starting container...${NC}"
docker compose up -d || {
    echo -e "${RED}Failed to start container${NC}"
    exit 1
}

# Wait for container to be healthy
echo -e "\n${GREEN}Waiting for container to be ready...${NC}"
sleep 10

# Check container status
if docker compose ps | grep -q "Up"; then
    echo -e "\n${GREEN}=========================================${NC}"
    echo -e "${GREEN}Installation Complete!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo -e "WebUI:    ${GREEN}http://$(hostname -I | awk '{print $1}'):$WEBUI_PORT${NC}"
    echo -e "XMLTV:    ${GREEN}http://$(hostname -I | awk '{print $1}'):$HTTP_PORT/xmltv${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Open the WebUI in your browser"
    echo "2. Configure your lineup IDs and ZIP codes"
    echo "3. Click 'Run EPG Grabber Now' to test"
    echo ""
    echo "View logs:"
    echo "  docker compose logs -f"
    echo ""
    echo "Stop container:"
    echo "  docker compose down"
    echo ""
else
    echo -e "${RED}Container failed to start!${NC}"
    echo "Check logs with: docker compose logs"
    exit 1
fi

# Create systemd service (optional)
read -p "Create systemd service for auto-start? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cat > /etc/systemd/system/zap2xml.service <<EOF
[Unit]
Description=Zap2XML TVGuide
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable zap2xml.service
    echo -e "${GREEN}Systemd service created and enabled${NC}"
fi

echo -e "\n${GREEN}Setup complete!${NC}"