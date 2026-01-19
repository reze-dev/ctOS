#!/usr/bin/env bash
#
# Snowflake Remote Installer
# Usage: bash <(curl -sL https://raw.githubusercontent.com/atomiksan/snowflake/main/remote-install.sh)
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << 'EOF'
  ❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️
  
     _____ _   _  _____  _    _ ______ _            _  _______
    / ____| \ | |/ __ \ \ \  / /  ____| |          | |/ / ____|
   | (___ |  \| | |  | \ \ \/ /| |__  | |     __ _ | ' /| |___
    \___ \| . ` | |  | |\ \  / |  __| | |    / _` ||  < |  ___|
    ____) | |\  | |__| | \  /  | |    | |___| (_| || . \| |___
   |_____/|_| \_|\____/   \/   |_|    |______\__,_||_|\_\_____|
  
     NixOS Distribution - Remote Installer
  
  ❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️❄️
EOF
echo -e "${NC}"

# Check for root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root.${NC}"
    echo "Usage: sudo bash <(curl -sL https://raw.githubusercontent.com/atomiksan/snowflake/main/remote-install.sh)"
    exit 1
fi

# Check for git and nix
for cmd in git nix; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: '$cmd' is not installed.${NC}"
        echo "This script is designed to run from a NixOS install ISO."
        exit 1
    fi
done

# Configuration
REPO_URL="${SNOWFLAKE_REPO:-https://github.com/atomiksan/snowflake.git}"
BRANCH="${SNOWFLAKE_BRANCH:-main}"
TEMP_DIR=$(mktemp -d -t snowflake-install.XXXXXX)

cleanup() {
    echo -e "\n${YELLOW}Cleaning up temporary files...${NC}"
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo -e "${GREEN}Cloning Snowflake repository...${NC}"
echo "Repository: $REPO_URL"
echo "Branch: $BRANCH"
echo ""

git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TEMP_DIR/snowflake"

cd "$TEMP_DIR/snowflake"

# Export work directory for the install script
export SNOWFLAKE_REMOTE="$TEMP_DIR/snowflake"

echo -e "${GREEN}Starting installation...${NC}"
echo ""

# Make install script executable and run it
chmod +x install.sh
./install.sh

echo -e "\n${GREEN}Remote installation complete!${NC}"
echo -e "The temporary clone at ${CYAN}$TEMP_DIR${NC} will be cleaned up."
echo -e "Your configuration has been installed to the target system."
