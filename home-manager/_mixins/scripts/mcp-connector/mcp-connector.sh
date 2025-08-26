#!/usr/bin/env bash

# Script to run MCP Connector with Tailscale Serve
# Stops MCP when Tailscale Serve is interrupted

set -e

echo "TypingMind MCP Connector with Tailscale Serve"

# Optional: Quick environment verification
echo "Key tools available:"
echo "- Nodejs: $(node --version | sed 's/v//g')"
echo "- Python: $(python3 --version | head -n 1 | cut -d' ' -f2)"
echo "- GitHub (gh): $(gh --version | head -n 1 | cut -d' ' -f3)"
echo "- GitHub (MCP): $(github-mcp-server --version | grep ^Version | cut -d':' -f2 | sed 's/ //g')"

# Configuration
MCP_PORT=50880
MCP_HOSTNAME=127.0.0.1
MCP_AUTH_TOKEN=wibble
TAILSCALE_HTTPS_PORT=50443
PM2_APP_NAME="mcp-connector"
MCP_MEMORY_TARGET="${HOME}/Development/mcp-memory.json"

# Colours for output
RED='\033[0;31m';
GREEN='\033[0;32m';
YELLOW='\033[1;33m';
BLUE='\033[0;34m';
NC='\033[0m'

# Function to setup MCP memory persistence
setup_mcp_memory() {
    echo -e "${BLUE}Setting up MCP memory persistence...${NC}"

    # Ensure target directory exists
    mkdir -p "$(dirname "$MCP_MEMORY_TARGET")"

    # Find memory.json files in ~/.npm/
    local memory_files
    # Find only files that end exactly with "memory.json" (not containing backup)
    mapfile -t memory_files < <(fd -t f -e json "^memory\.json$" ~/.npm/ 2>/dev/null || true)


    if [ ${#memory_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}No memory.json files found in ~/.npm/ yet${NC}"
        echo -e "${YELLOW}Memory will be linked when MCP server creates the file${NC}"
        return 0
    fi

    # Process each found memory.json file
    for memory_file in "${memory_files[@]}"; do
        echo -e "${BLUE}Found memory file: ${memory_file}${NC}"

        # Check if it's already a symlink to our target
        if [ -L "$memory_file" ] && [ "$(readlink -f "$memory_file")" = "$MCP_MEMORY_TARGET" ]; then
            echo -e "${GREEN}✓ Already linked to persistent memory${NC}"
            continue
        fi

        # Create target file if it doesn't exist
        if [ ! -f "$MCP_MEMORY_TARGET" ]; then
            if [ -f "$memory_file" ]; then
                echo -e "${BLUE}Copying existing memory to persistent location${NC}"
                cp "$memory_file" "$MCP_MEMORY_TARGET"
            else
                echo -e "${BLUE}Creating empty persistent memory file${NC}"
                echo '{}' > "$MCP_MEMORY_TARGET"
            fi
        fi

        # Backup original if it exists and isn't a symlink
        if [ -f "$memory_file" ] && [ ! -L "$memory_file" ]; then
            echo -e "${YELLOW}Backing up original memory file${NC}"
            mv "$memory_file" "${memory_file}.backup.$(date +%Y%m%d-%H%M%S)"
        elif [ -L "$memory_file" ]; then
            echo -e "${YELLOW}Removing existing symlink${NC}"
            rm "$memory_file"
        fi

        # Create the symlink
        echo -e "${BLUE}Creating symlink: ${memory_file} → ${MCP_MEMORY_TARGET}${NC}"
        ln -sf "$MCP_MEMORY_TARGET" "$memory_file"
        echo -e "${GREEN}✓ Memory persistence configured${NC}"
    done
}

# Function to stop MCP Connector instances
stop_mcp_connector() {
    pm2 stop "$PM2_APP_NAME" 2>/dev/null || true
    pm2 delete "$PM2_APP_NAME" 2>/dev/null || true
}

# Cleanup function to stop MCP when script exits
cleanup() {
    echo -e "\n${YELLOW}Stopping MCP Connector...${NC}"
    stop_mcp_connector
    echo -e "${GREEN}MCP Connector stopped${NC}"
    exit 0
}

# Set up trap to catch Ctrl+C and other termination signals
trap cleanup INT TERM EXIT

# Stop any existing MCP Connector instance
echo -e "${YELLOW}Cleaning up any existing MCP Connector instances...${NC}"
stop_mcp_connector

# Setup MCP memory persistence
setup_mcp_memory

# Start MCP Connector with pm2
echo -e "${GREEN}Starting MCP Connector on port $MCP_PORT...${NC}"
PORT=$MCP_PORT HOSTNAME=$MCP_HOSTNAME MCP_AUTH_TOKEN=$MCP_AUTH_TOKEN pm2 start npx --name "$PM2_APP_NAME" --no-autorestart -- @typingmind/mcp

# Wait a moment for MCP to start
sleep 2

# Check if MCP started successfully
if pm2 list | grep -q "$PM2_APP_NAME.*online"; then
    echo -e "${GREEN}MCP Connector started successfully${NC}"

    # Re-check memory setup after MCP starts (in case it created new files)
    echo -e "${BLUE}Checking for any new memory files after startup...${NC}"
    setup_mcp_memory

    echo -e "${GREEN}Starting Tailscale Serve...${NC}"
    echo -e "${YELLOW}MCP Connector will be available at:${NC}"
    echo -e "  ${GREEN}https://$(tailscale status --json | jq -r '.Self.DNSName' | sed 's/\.$//'):$TAILSCALE_HTTPS_PORT${NC}"
    echo -e "${BLUE}Persistent memory location: ${MCP_MEMORY_TARGET}${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop both services${NC}\n"

    # Start Tailscale Serve in foreground
    # This will block until Ctrl+C is pressed
    tailscale serve --https=$TAILSCALE_HTTPS_PORT $MCP_PORT
else
    echo -e "${RED}Failed to start MCP Connector${NC}"
    pm2 logs "$PM2_APP_NAME" --nostream --lines 20
    exit 1
fi
