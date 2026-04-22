#!/usr/bin/env bash
# Jack-in-a-Box — Quick Launcher
# Starts all components in order.

set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}  ╦╔═╗╔═╗╔═╗╦╔═╔═╗╔╦╗  ╦  ╔═╗╔╗╔${NC}"
echo -e "${BOLD}${CYAN}  ║╠═╣║ ╦║ ║╠╩╗║╣  ║║  ║  ║ ║║║║${NC}"
echo -e "${BOLD}${CYAN}  ╩╩ ╩╚═╝╚═╝╩ ╩╚═╝═╩╝  ╩═╝╚═╝╝╚╝${NC}"
echo ""

# 1. Start DLM if available and not running
# DLM installs to /home/JackrabbitDLM (not $BASE_DIR)
DLM_LAUNCH_DIR=""
for d in /home/JackrabbitDLM "$HOME/jack-in-a-box/jackrabbit-dlm"; do
    [ -f "$d/JackrabbitDLM" ] && DLM_LAUNCH_DIR="$d" && break
done
if [ -n "$DLM_LAUNCH_DIR" ] && ! ss -tlnp 2>/dev/null | grep -q ":37373 "; then
    echo -e "  ${CYAN}→${NC} Starting JackrabbitDLM..."
    cd "$DLM_LAUNCH_DIR"
    python3 JackrabbitDLM 0.0.0.0 37373 &
    sleep 2
    echo -e "  ${GREEN}✓${NC} DLM running on port 37373"
fi

# 2. Start Hermes Agent
if [ -d "$BASE_DIR/hermes-agent" ]; then
    echo -e "  ${GREEN}✓${NC} Launching Hermes Agent..."
    # Try installed hermes command first, then python3 -m hermes_cli.main
    HERMES_BIN=""
    if command -v hermes &>/dev/null; then
        HERMES_BIN="hermes"
    elif [ -f "$BASE_DIR/hermes-agent/venv/bin/hermes" ]; then
        HERMES_BIN="$BASE_DIR/hermes-agent/venv/bin/hermes"
    fi
    cd "$BASE_DIR/hermes-agent"
    if [ -n "$HERMES_BIN" ]; then
        if [ $# -eq 0 ]; then
            $HERMES_BIN chat -m kilo-auto/free
        else
            $HERMES_BIN "$@"
        fi
    else
        source venv/bin/activate 2>/dev/null || true
        export PYTHONPATH="$BASE_DIR/hermes-agent:${PYTHONPATH:-}"
        if [ $# -eq 0 ]; then
            python3 -m hermes_cli.main chat -m kilo-auto/free
        else
            python3 -m hermes_cli.main "$@"
        fi
    fi
fi
