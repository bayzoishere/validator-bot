#!/bin/bash
# ============================================================
# Mine Validator Setup Script
# ============================================================
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Mine Validator - Auto Setup Script${NC}"
echo -e "${GREEN}============================================${NC}"

# --- Check prerequisites ---
echo -e "\n${YELLOW}[1/6] Checking prerequisites...${NC}"

command_exists() { command -v "$1" >/dev/null 2>&1; }

if ! command_exists git; then
    echo "ERROR: git not found. Install: apt install git"
    exit 1
fi

if ! command_exists node; then
    echo "ERROR: Node.js not found. Install Node.js 20+ first."
    exit 1
fi

NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [[ "$NODE_VERSION" -lt 20 ]]; then
    echo "ERROR: Node.js 20+ required. Found v$NODE_VERSION"
    exit 1
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)
if [[ "$PYTHON_MAJOR" -lt 3 ]] || { [[ "$PYTHON_MAJOR" -eq 3 ]] && [[ "$PYTHON_MINOR" -lt 11 ]]; }; then
    echo "ERROR: Python 3.11+ required. Found $PYTHON_VERSION"
    exit 1
fi

echo -e "${GREEN}✓${NC} Prerequisites OK (git, node v$NODE_VERSION, python $PYTHON_VERSION)"

# --- Clone / update repo ---
echo -e "\n${YELLOW}[2/6] Cloning / updating mine-skill...${NC}"

REPO_DIR="${REPO_DIR:-/opt/mine-validator}"
if [[ -d "$REPO_DIR/mine-skill" ]]; then
    echo "  Updating existing mine-skill..."
    cd "$REPO_DIR/mine-skill" && git pull
else
    echo "  Cloning mine-skill to $REPO_DIR..."
    mkdir -p "$REPO_DIR"
    cd "$REPO_DIR"
    git clone https://github.com/awp-worknet/mine-skill.git
fi

cd "$REPO_DIR/mine-skill"
echo -e "${GREEN}✓${NC} mine-skill ready at $REPO_DIR/mine-skill"

# --- Bootstrap ---
echo -e "\n${YELLOW}[3/6] Running bootstrap...${NC}"
bash scripts/bootstrap.sh
echo -e "${GREEN}✓${NC} Bootstrap complete"

# --- Load .env ---
echo -e "\n${YELLOW}[4/6] Loading environment variables...${NC}"
ENV_FILE="${REPO_DIR}/.env"
if [[ -f "$ENV_FILE" ]]; then
    echo "  Loading from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
else
    echo -e "${RED}ERROR: $ENV_FILE not found${NC}"
    echo "  Create it with your VALIDATOR_PRIVATE_KEY and other vars."
    echo "  See .env.example for reference."
    exit 1
fi

if [[ -z "${VALIDATOR_PRIVATE_KEY:-}" ]]; then
    echo -e "${RED}ERROR: VALIDATOR_PRIVATE_KEY not set in .env${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Environment loaded"

# --- Health check ---
echo -e "\n${YELLOW}[5/6] Running validator doctor...${NC}"
source .venv/bin/activate
python scripts/run_tool.py validator-doctor 2>&1 | tail -20

# --- Start validator ---
echo -e "\n${YELLOW}[6/6] Starting validator...${NC}"
nohup python scripts/run_tool.py validator-start > "$REPO_DIR/validator.log" 2>&1 &
PID=$!
echo -e "${GREEN}✓${NC} Validator started (PID: $PID)"
echo -e "${GREEN}✓${NC} Log file: $REPO_DIR/validator.log"

echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo -e "\nCheck status:"
echo "  source .venv/bin/activate && python scripts/run_tool.py validator-control status"
echo -e "\nStop:"
echo "  python scripts/run_tool.py validator-control stop"
