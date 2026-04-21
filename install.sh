#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  JACK-IN-A-BOX — All-in-One Hermes Stack Installer
# ══════════════════════════════════════════════════════════════════════════════
#
#  One command. Everything springs to life.
#
#  Components:
#    1. Hermes Agent (itsXactlY fork, dev/unified branch)
#    2. Neural Memory (itsXactlY/neural-memory — lite stack, local semantic memory)
#    3. PULSE (itsXactlY/pulse-hermes — autonomous social search engine)
#    4. Jackrabbit Wonderland (itsXactlY/Jackrabbit-wonderland — AES256 crypto layer)
#    5. JackrabbitDLM (rapmd73/JackrabbitDLM — volatile key vault)
#
#  Usage:
#    bash install.sh                    # Full install
#    bash install.sh --check            # Verify only (no changes)
#    bash install.sh --components X,Y   # Install specific components only
#    bash install.sh --skip-firewall    # Skip nftables rules
#    bash install.sh --lite             # Skip DLM + crypto (hermes + neural + pulse only)
#
#  Components: hermes, neural, pulse, dlm, crypto
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ─── Root check — NO EXCEPTIONS ─────────────────────────────────────────────
if [ "$(id -u)" -eq 0 ]; then
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║  DO NOT RUN AS ROOT.                             ║"
    echo "║                                                  ║"
    echo "║  Jack-in-a-box creates venvs and writes to       ║"
    echo "║  ~/.hermes/ and ~/jack-in-a-box/. Root would     ║"
    echo "║  break permissions and pip path detection.       ║"
    echo "║                                                  ║"
    echo "║  Run as normal user:  bash install.sh            ║"
    echo "╚══════════════════════════════════════════════════╝"
    exit 1
fi

# ─── Version ─────────────────────────────────────────────────────────────────
JIAB_VERSION="1.0.1"

# ─── Config ──────────────────────────────────────────────────────────────────
BASE_DIR="${JIAB_INSTALL_DIR:-$HOME/jack-in-a-box}"
HERMES_REPO="https://github.com/itsXactlY/hermes-agent.git"
HERMES_BRANCH="dev/unified"
NEURAL_REPO="https://github.com/itsXactlY/neural-memory.git"
NEURAL_BRANCH="main"
PULSE_REPO="https://github.com/itsXactlY/pulse-hermes.git"
PULSE_BRANCH="main"
JRWL_REPO="https://github.com/itsXactlY/Jackrabbit-wonderland.git"
JRWL_BRANCH="main"
DLM_REPO="https://github.com/rapmd73/JackrabbitDLM.git"

HERMES_DIR="$BASE_DIR/hermes-agent"
NEURAL_DIR="$BASE_DIR/neural-memory"
PULSE_DIR="$BASE_DIR/pulse"
JRWL_DIR="$BASE_DIR/jackrabbit-wonderland"
DLM_DIR="/home/JackrabbitDLM"

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
SKILLS_DIR="$HERMES_HOME/skills"
CONFIG_DIR="$HOME/.config/jack-in-a-box"

DLM_PORT=37373
GATEWAY_PORT=8080
RAW_TCP_PORT=37374

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

ok()      { echo -e "  ${GREEN}✓${NC} $1"; }
fail()    { echo -e "  ${RED}✗${NC} $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC} $1"; }
info()    { echo -e "  ${CYAN}→${NC} $1"; }
step()    { echo -e "\n${BOLD}${MAGENTA}[$1/$TOTAL_STEPS]${NC} ${BOLD}$2${NC}"; }
banner()  { echo -e "${BOLD}${CYAN}$1${NC}"; }

# ─── Parse Args ──────────────────────────────────────────────────────────────
MODE="install"
SKIP_FIREWALL=false
LITE_MODE=false
COMPONENTS=""
SKIP_NEXT=false
for arg in "$@"; do
    if $SKIP_NEXT; then
        SKIP_NEXT=false
        continue
    fi
    case $arg in
        --check)          MODE="check" ;;
        --skip-firewall)  SKIP_FIREWALL=true ;;
        --lite)           LITE_MODE=true ;;
        --components)     SKIP_NEXT=true; COMPONENTS="$2" ;;
        --help|-h)
            echo ""
            banner "  ╔══════════════════════════════════════════════════════╗"
            banner "  ║  JACK-IN-A-BOX v$JIAB_VERSION — Hermes Stack Installer  ║"
            banner "  ╚══════════════════════════════════════════════════════╝"
            echo ""
            echo "  Usage: bash install.sh [OPTIONS]"
            echo ""
            echo "  Options:"
            echo "    --check            Verify installation (no changes)"
            echo "    --components X,Y   Install specific: hermes,neural,pulse,dlm,crypto"
            echo "    --skip-firewall    Skip nftables firewall rules"
            echo "    --lite             Skip DLM + crypto (hermes + neural + pulse only)"
            echo "    --help             Show this help"
            echo ""
            echo "  Components:"
            echo "    hermes   — Hermes Agent (itsXactlY fork, dev/unified)"
            echo "    neural   — Neural Memory (local semantic memory)"
            echo "    pulse    — PULSE (autonomous social search)"
            echo "    dlm      — JackrabbitDLM (volatile key vault)"
            echo "    crypto   — Jackrabbit Wonderland (AES256 crypto layer)"
            echo ""
            exit 0
            ;;
    esac
done

# Determine which components to install
if [ -n "$COMPONENTS" ]; then
    IFS=',' read -ra INSTALL_LIST <<< "$COMPONENTS"
else
    if $LITE_MODE; then
        INSTALL_LIST=(hermes neural pulse)
    else
        INSTALL_LIST=(hermes neural pulse dlm crypto)
    fi
fi

should_install() {
    local comp="$1"
    for item in "${INSTALL_LIST[@]}"; do
        [[ "$item" == "$comp" ]] && return 0
    done
    return 1
}

# Count steps
TOTAL_STEPS=0
should_install hermes && TOTAL_STEPS=$((TOTAL_STEPS + 1)) || true
should_install neural && TOTAL_STEPS=$((TOTAL_STEPS + 1)) || true
should_install pulse  && TOTAL_STEPS=$((TOTAL_STEPS + 1)) || true
should_install dlm    && TOTAL_STEPS=$((TOTAL_STEPS + 1)) || true
should_install crypto && TOTAL_STEPS=$((TOTAL_STEPS + 1)) || true
TOTAL_STEPS=$((TOTAL_STEPS + 1))  # verification step

# ─── Banner ──────────────────────────────────────────────────────────────────
echo ""
banner "    ╦╔═╗╔═╗╔═╗╦╔═╔═╗╔╦╗  ╦  ╔═╗╔╗╔"
banner "    ║╠═╣║ ╦║ ║╠╩╗║╣  ║║  ║  ║ ║║║║"
banner "    ╩╩ ╩╚═╝╚═╝╩ ╩╚═╝═╩╝  ╩═╝╚═╝╝╚╝"
banner "    ──────────────────────────────────"
banner "    v$JIAB_VERSION — The Hermes Stack"
echo ""
echo -e "  ${DIM}Hermes Agent • Neural Memory • PULSE • Jackrabbit Wonderland${NC}"
echo -e "  ${DIM}Everything springs to life from a single command.${NC}"
echo ""

if [ "$MODE" = "check" ]; then
    echo -e "  ${CYAN}Running verification only (--check)${NC}"
    echo ""
fi

# ─── Preflight ───────────────────────────────────────────────────────────────
step 0 "Preflight Checks"

# Python
PYTHON=$(command -v python3 || true)
if [ -z "$PYTHON" ]; then
    fail "Python 3 not found"
    exit 1
fi
PY_VERSION=$($PYTHON -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PY_MAJOR=$($PYTHON -c 'import sys; print(sys.version_info.major)')
PY_MINOR=$($PYTHON -c 'import sys; print(sys.version_info.minor)')
if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 10 ]; }; then
    fail "Python 3.10+ required (found $PY_VERSION)"
    exit 1
fi
ok "Python $PY_VERSION"

# Git
if ! command -v git &>/dev/null; then
    fail "git not found"
    exit 1
fi
ok "git $(git --version | awk '{print $3}')"

# pip
PIP=$(command -v pip3 || command -v pip || true)
if [ -z "$PIP" ]; then
    warn "pip not found — trying python3 -m ensurepip..."
    $PYTHON -m ensurepip --upgrade 2>/dev/null || true
    PIP=$(command -v pip3 || command -v pip || echo "$PYTHON -m pip")
fi
ok "pip available ($PIP)"

# sudo (for DLM + crypto)
if should_install dlm || should_install crypto; then
    if ! sudo -n true 2>/dev/null; then
        warn "sudo access needed for DLM + crypto services"
        echo -e "  ${DIM}Tip: run with sudo or use --lite for hermes+neural+pulse only${NC}"
    fi
fi

# ─── Directory Structure ─────────────────────────────────────────────────────
if [ "$MODE" = "install" ]; then
    mkdir -p "$BASE_DIR" "$CONFIG_DIR" "$SKILLS_DIR"
    ok "Base directory: $BASE_DIR"
fi

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 1: HERMES AGENT
# ══════════════════════════════════════════════════════════════════════════════
CURRENT_STEP=1
if should_install hermes; then
    step $CURRENT_STEP "Hermes Agent (itsXactlY fork, dev/unified)"
    CURRENT_STEP=$((CURRENT_STEP + 1))

    if [ "$MODE" = "check" ]; then
        if [ -d "$HERMES_DIR/.git" ] && [ -f "$HERMES_DIR/run_agent.py" ]; then
            HERMES_CURRENT_BRANCH=$(cd "$HERMES_DIR" && git branch --show-current 2>/dev/null || echo "unknown")
            ok "Hermes installed at $HERMES_DIR (branch: $HERMES_CURRENT_BRANCH)"
            if [ -d "$HERMES_DIR/venv" ]; then
                ok "Virtual environment exists"
            else
                warn "No virtual environment found"
            fi
        else
            fail "Hermes not installed"
        fi
    else
        if [ -d "$HERMES_DIR/.git" ]; then
            info "Hermes already cloned — pulling latest..."
            cd "$HERMES_DIR"
            git fetch origin
            git checkout "$HERMES_BRANCH" 2>/dev/null || git checkout -b "$HERMES_BRANCH" "origin/$HERMES_BRANCH"
            git pull origin "$HERMES_BRANCH" --ff-only 2>/dev/null || warn "Could not fast-forward (local changes?)"
        else
            info "Cloning hermes-agent ($HERMES_BRANCH)..."
            git clone --branch "$HERMES_BRANCH" --single-branch "$HERMES_REPO" "$HERMES_DIR"
        fi
        ok "Hermes Agent at $HERMES_DIR"

        # Virtual environment
        if [ ! -d "$HERMES_DIR/venv" ]; then
            info "Creating virtual environment..."
            cd "$HERMES_DIR"
            $PYTHON -m venv venv
            ok "Virtual environment created"
        fi

        # Install dependencies
        info "Installing hermes dependencies..."
        cd "$HERMES_DIR"
        source venv/bin/activate
        # Ensure critical deps first (before requirements.txt)
        $PIP install python-dotenv --quiet 2>/dev/null || true
        if [ -f "requirements.txt" ]; then
            $PIP install -r requirements.txt --quiet 2>/dev/null || warn "Some deps may need manual install"
        fi
        deactivate
        ok "Hermes dependencies installed"

        # Setup hermes config
        mkdir -p "$HERMES_HOME"
        if [ ! -f "$HERMES_HOME/config.yaml" ]; then
            info "Creating default hermes config..."
            cat > "$HERMES_HOME/config.yaml" << 'HERMESCFG'
# Hermes Agent — Jack-in-a-Box default config
# Run 'hermes setup' or 'hermes model' to change provider/model.

model:
  api_key: ""
  base_url: https://api.kilo.ai/api/gateway
  default_model: kilo-auto/free
  provider: kilo

providers:
  kilo:
    api: https://api.kilo.ai/api/gateway
    api_key: ""
    default_model: kilo-auto/free
    name: Kilo Code
    transport: chat_completions

settings:
  default_model: kilo-auto/free
  max_iterations: 30
  skin: hermelin

display:
  skin: hermelin

memory:
  provider: neural
  neural:
    embedding_backend: fastembed
    use_cpp: false
HERMESCFG
            ok "Default config at $HERMES_HOME/config.yaml"
        else
            ok "Existing config preserved"
        fi

        # Create .env if not exists
        if [ ! -f "$HERMES_HOME/.env" ]; then
            info "Creating .env template..."
            cat > "$HERMES_HOME/.env" << 'ENVTEMPLATE'
# Hermes Agent — API Keys
# Fill in your keys. Never commit this file.

# ─── Model Providers ─────────────────────────────────────
# KILOCODE_API_KEY=
# OPENROUTER_API_KEY=
# OLLAMA_BASE_URL=http://localhost:11434

# ─── Neural Memory ───────────────────────────────────────
# MSSQL_SERVER=localhost
# MSSQL_DATABASE=NeuralMemory
# MSSQL_USERNAME=SA
# MSSQL_PASSWORD=

# ─── PULSE ───────────────────────────────────────────────
# BRAVE_API_KEY=
# GITHUB_TOKEN=
# NEWSAPI_KEY=

# ─── Jackrabbit Wonderland ───────────────────────────────
# DLM_HOST=127.0.0.1
# DLM_PORT=37373
ENVTEMPLATE
            chmod 600 "$HERMES_HOME/.env"
            ok "Env template at $HERMES_HOME/.env"
        else
            ok "Existing .env preserved"
        fi
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 2: NEURAL MEMORY
# ══════════════════════════════════════════════════════════════════════════════
if should_install neural; then
    step $CURRENT_STEP "Neural Memory (lite stack)"
    CURRENT_STEP=$((CURRENT_STEP + 1))

    if [ "$MODE" = "check" ]; then
        if [ -d "$NEURAL_DIR/.git" ] && [ -f "$NEURAL_DIR/install.sh" ]; then
            ok "Neural Memory at $NEURAL_DIR"
            if [ -d "$HERMES_DIR/plugins/memory/neural" ]; then
                ok "Neural Memory plugin installed in hermes-agent"
            else
                warn "Neural Memory plugin not linked to hermes-agent"
            fi
        else
            fail "Neural Memory not installed"
        fi
    else
        if [ -d "$NEURAL_DIR/.git" ]; then
            info "Neural Memory already cloned — pulling latest..."
            cd "$NEURAL_DIR"
            git fetch origin
            git pull origin main --ff-only 2>/dev/null || git pull origin master --ff-only 2>/dev/null || warn "Could not fast-forward"
        else
            info "Cloning neural-memory..."
            git clone "$NEURAL_REPO" "$NEURAL_DIR"
        fi
        ok "Neural Memory at $NEURAL_DIR"

        # Install into hermes-agent using the built-in installer (symlink-based)
        if [ -f "$NEURAL_DIR/install.sh" ] && [ -d "$HERMES_DIR" ]; then
            info "Installing Neural Memory plugin into hermes-agent..."
            cd "$NEURAL_DIR"
            bash install.sh install || warn "Neural installer had issues — manual setup may be needed"
            ok "Neural Memory plugin installed"
        else
            warn "Neural Memory installer not found — manual plugin copy needed"
        fi

        # Python deps are handled by the neural-memory install.sh
        # (FastEmbed, numpy, torch if CUDA detected — all automatic)
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 3: PULSE
# ══════════════════════════════════════════════════════════════════════════════
if should_install pulse; then
    step $CURRENT_STEP "PULSE (autonomous social search)"
    CURRENT_STEP=$((CURRENT_STEP + 1))

    if [ "$MODE" = "check" ]; then
        if [ -d "$PULSE_DIR/.git" ] && [ -f "$PULSE_DIR/install.sh" ]; then
            ok "PULSE at $PULSE_DIR"
            if [ -L "$SKILLS_DIR/devops/pulse" ] || [ -d "$SKILLS_DIR/devops/pulse" ]; then
                ok "PULSE skill linked"
            else
                warn "PULSE skill not linked"
            fi
            if [ -L "$HOME/.local/bin/pulse" ]; then
                ok "PULSE CLI available"
            else
                warn "PULSE CLI not linked"
            fi
        else
            fail "PULSE not installed"
        fi
    else
        if [ -d "$PULSE_DIR/.git" ]; then
            info "PULSE already cloned — pulling latest..."
            cd "$PULSE_DIR"
            git fetch origin
            git pull origin main --ff-only 2>/dev/null || warn "Could not fast-forward"
        else
            info "Cloning PULSE..."
            git clone "$PULSE_REPO" "$PULSE_DIR"
        fi
        ok "PULSE at $PULSE_DIR"

        # Run the PULSE installer (links skill + CLI)
        if [ -f "$PULSE_DIR/install.sh" ]; then
            info "Running PULSE installer..."
            cd "$PULSE_DIR"
            bash install.sh || warn "PULSE installer had issues — check output above"
            ok "PULSE installed (skill + CLI)"
        fi
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 4: JACKRABBIT DLM
# ══════════════════════════════════════════════════════════════════════════════
if should_install dlm; then
    step $CURRENT_STEP "JackrabbitDLM (volatile key vault)"
    CURRENT_STEP=$((CURRENT_STEP + 1))

    if [ "$MODE" = "check" ]; then
        if [ -d "$DLM_DIR" ]; then
            ok "DLM at $DLM_DIR"
            if systemctl is-active --quiet "jackrabbit-dlm@$USER" 2>/dev/null; then
                ok "DLM service running"
            else
                warn "DLM service not running"
            fi
            if ss -tlnp 2>/dev/null | grep -q ":$DLM_PORT "; then
                ok "DLM port $DLM_PORT listening"
            else
                warn "DLM port $DLM_PORT not listening"
            fi
        else
            fail "DLM not installed"
        fi
    else
        if [ -d "$DLM_DIR/.git" ]; then
            info "DLM already cloned"
        else
            info "Cloning JackrabbitDLM..."
            sudo git clone "$DLM_REPO" "$DLM_DIR" 2>/dev/null || git clone "$DLM_REPO" "$DLM_DIR"
            sudo chmod -R 755 "$DLM_DIR" 2>/dev/null || true
        fi
        ok "DLM at $DLM_DIR"

        # Start DLM as a background process if not running
        if ! ss -tlnp 2>/dev/null | grep -q ":$DLM_PORT "; then
            info "Starting JackrabbitDLM on port $DLM_PORT..."
            cd "$DLM_DIR"
            $PYTHON JackrabbitDLM 0.0.0.0 $DLM_PORT &
            DLM_PID=$!
            sleep 2
            if ss -tlnp 2>/dev/null | grep -q ":$DLM_PORT "; then
                ok "DLM running (PID $DLM_PID, port $DLM_PORT)"
            else
                warn "DLM may not have started — check manually"
            fi
        else
            ok "DLM already running on port $DLM_PORT"
        fi

        # Systemd service (if not exists)
        if [ ! -f "/etc/systemd/system/jackrabbit-dlm@$USER.service" ]; then
            info "Creating systemd service for DLM..."
            sudo tee /etc/systemd/system/jackrabbit-dlm@.service > /dev/null << DLMSVC
[Unit]
Description=JackrabbitDLM Volatile Key Vault (%i)
After=network.target

[Service]
Type=simple
User=%i
WorkingDirectory=$DLM_DIR
ExecStart=/usr/bin/python3 $DLM_DIR/JackrabbitDLM 0.0.0.0 $DLM_PORT
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
DLMSVC
            sudo systemctl daemon-reload
            sudo systemctl enable "jackrabbit-dlm@$USER" 2>/dev/null || true
            ok "DLM systemd service created"
        else
            ok "DLM systemd service already exists"
        fi
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 5: JACKRABBIT WONDERLAND (CRYPTO)
# ══════════════════════════════════════════════════════════════════════════════
if should_install crypto; then
    step $CURRENT_STEP "Jackrabbit Wonderland (AES256 crypto layer)"
    CURRENT_STEP=$((CURRENT_STEP + 1))

    if [ "$MODE" = "check" ]; then
        if [ -d "$JRWL_DIR/.git" ] && [ -f "$JRWL_DIR/crypto_middleware.py" ]; then
            ok "JRWL at $JRWL_DIR"
            if [ -d "/opt/hermes-crypto" ]; then
                ok "Deployed to /opt/hermes-crypto"
            else
                warn "Not deployed to /opt/hermes-crypto"
            fi
            if systemctl is-active --quiet "hermes-gateway@$USER" 2>/dev/null; then
                ok "Hermes Gateway service running"
            else
                warn "Hermes Gateway service not running"
            fi
        else
            fail "JRWL not installed"
        fi
    else
        if [ -d "$JRWL_DIR/.git" ]; then
            info "JRWL already cloned — pulling latest..."
            cd "$JRWL_DIR"
            git fetch origin
            git pull origin main --ff-only 2>/dev/null || warn "Could not fast-forward"
        else
            info "Cloning Jackrabbit Wonderland..."
            git clone "$JRWL_REPO" "$JRWL_DIR"
        fi
        ok "JRWL at $JRWL_DIR"

        # Install pycryptodome
        info "Installing pycryptodome..."
        cd "$HERMES_DIR"
        source venv/bin/activate 2>/dev/null || true
        $PIP install pycryptodome --quiet 2>/dev/null || $PYTHON -m pip install pycryptodome --quiet
        deactivate 2>/dev/null || true
        ok "pycryptodome installed"

        # Deploy to /opt/hermes-crypto
        if [ -f "$JRWL_DIR/install.sh" ]; then
            info "Running JRWL installer..."
            cd "$JRWL_DIR"
            sudo bash install.sh --no-firewall || {
                warn "JRWL installer had issues — deploying manually..."
                sudo mkdir -p /opt/hermes-crypto
                sudo cp "$JRWL_DIR"/*.py /opt/hermes-crypto/ 2>/dev/null || true
                sudo cp "$JRWL_DIR"/install.sh /opt/hermes-crypto/ 2>/dev/null || true
                sudo chmod +x /opt/hermes-crypto/*.py 2>/dev/null || true
            }
            ok "JRWL deployed"
        else
            info "Deploying JRWL files manually..."
            sudo mkdir -p /opt/hermes-crypto
            sudo cp "$JRWL_DIR"/*.py /opt/hermes-crypto/
            ok "JRWL deployed to /opt/hermes-crypto"
        fi

        # nftables (unless skipped)
        if ! $SKIP_FIREWALL; then
            info "Configuring nftables rules..."
            if command -v nft &>/dev/null; then
                # Add JRWL ports to nftables if not already there
                if [ -f "/etc/nftables.conf" ]; then
                    if ! grep -q "37373" /etc/nftables.conf; then
                        info "Adding JRWL ports to nftables..."
                        sudo sed -i "/ip saddr.*tcp dport.*accept/{
                            s/tcp dport { [^}]* }/tcp dport { \0, $GATEWAY_PORT, $DLM_PORT, $RAW_TCP_PORT }/
                        }" /etc/nftables.conf 2>/dev/null || warn "Manual nftables edit needed"
                        ok "nftables configured"
                    else
                        ok "nftables already has JRWL ports"
                    fi
                fi
            fi
        fi
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
#  FINAL: VERIFICATION & LINKING
# ══════════════════════════════════════════════════════════════════════════════
step $((CURRENT_STEP)) "Verification & Integration"
echo ""

ERRORS=0

# Hermes
if [ -d "$HERMES_DIR" ] && [ -f "$HERMES_DIR/run_agent.py" ]; then
    ok "Hermes Agent ✓"
else
    fail "Hermes Agent ✗"
    ERRORS=$((ERRORS + 1))
fi

# Neural Memory
if should_install neural; then
    if [ -d "$NEURAL_DIR" ] && [ -f "$NEURAL_DIR/install.sh" ]; then
        ok "Neural Memory ✓"
    else
        fail "Neural Memory ✗"
        ERRORS=$((ERRORS + 1))
    fi
fi

# PULSE
if should_install pulse; then
    if [ -d "$PULSE_DIR" ] && [ -f "$PULSE_DIR/install.sh" ]; then
        ok "PULSE ✓"
    else
        fail "PULSE ✗"
        ERRORS=$((ERRORS + 1))
    fi
fi

# DLM
if should_install dlm; then
    if [ -d "$DLM_DIR" ]; then
        if ss -tlnp 2>/dev/null | grep -q ":$DLM_PORT "; then
            ok "JackrabbitDLM ✓ (port $DLM_PORT)"
        else
            warn "DLM installed but not running"
        fi
    else
        fail "JackrabbitDLM ✗"
        ERRORS=$((ERRORS + 1))
    fi
fi

# JRWL
if should_install crypto; then
    if [ -d "$JRWL_DIR" ] && [ -f "$JRWL_DIR/crypto_middleware.py" ]; then
        ok "Jackrabbit Wonderland ✓"
    else
        fail "Jackrabbit Wonderland ✗"
        ERRORS=$((ERRORS + 1))
    fi
fi

# ─── Integration: Link JRWL as Hermes skill ──────────────────────────────────
if should_install crypto && [ -d "$JRWL_DIR" ]; then
    JRWL_SKILL_DIR="$SKILLS_DIR/devops/jackrabbit-wonderland"
    if [ ! -L "$JRWL_SKILL_DIR" ] && [ ! -d "$JRWL_SKILL_DIR" ]; then
        info "Linking JRWL as Hermes skill..."
        ln -sf "$JRWL_DIR" "$JRWL_SKILL_DIR"
        ok "JRWL skill linked (jackrabbit-wonderland)"
    else
        ok "JRWL skill already linked"
    fi
fi

# ─── Integration: Create .env.example ────────────────────────────────────────
ENV_FILE="$CONFIG_DIR/.env.example"
if [ ! -f "$ENV_FILE" ] && [ "$MODE" = "install" ]; then
    cat > "$ENV_FILE" << 'ENVFILE'
# Jack-in-a-Box — Environment Variables
# Copy to .env and fill in your keys.

# ─── Hermes Agent ─────────────────────────────────────────────
# ANTHROPIC_API_KEY=sk-ant-...
# OPENROUTER_API_KEY=sk-or-...
# OLLAMA_BASE_URL=http://localhost:11434

# ─── PULSE ────────────────────────────────────────────────────
# PULSE_REDDIT_CLIENT_ID=...
# PULSE_REDDIT_CLIENT_SECRET=...

# ─── Neural Memory ───────────────────────────────────────────
# NEURAL_DB_PATH=$HOME/.hermes/neural_memory.db
# NEURAL_EMBED_MODEL=all-MiniLM-L6-v2

# ─── Jackrabbit Wonderland ───────────────────────────────────
# DLM_HOST=127.0.0.1
# DLM_PORT=37373
ENVFILE
    ok "Example .env at $CONFIG_DIR/.env.example"
fi

# ─── Integration: Create launch script ───────────────────────────────────────
LAUNCHER="$BASE_DIR/launch.sh"
if [ "$MODE" = "install" ]; then
    cat > "$LAUNCHER" << 'LAUNCHER'
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
if [ -d "$BASE_DIR/jackrabbit-dlm" ] && ! ss -tlnp 2>/dev/null | grep -q ":37373 "; then
    echo -e "  ${CYAN}→${NC} Starting JackrabbitDLM..."
    cd "$BASE_DIR/jackrabbit-dlm"
    python3 JackrabbitDLM 0.0.0.0 37373 &
    sleep 2
    echo -e "  ${GREEN}✓${NC} DLM running on port 37373"
fi

# 2. Start Hermes Agent
if [ -d "$BASE_DIR/hermes-agent" ]; then
    echo -e "  ${GREEN}✓${NC} Launching Hermes Agent..."
    cd "$BASE_DIR/hermes-agent"
    source venv/bin/activate 2>/dev/null || true
    export PYTHONPATH="$BASE_DIR/hermes-agent:${PYTHONPATH:-}"
    if [ $# -eq 0 ]; then
        python3 -m hermes_cli.main chat -m kilo-auto/free
    else
        python3 -m hermes_cli.main "$@"
    fi
fi
LAUNCHER
    chmod +x "$LAUNCHER"
    ok "Launcher at $BASE_DIR/launch.sh"
fi

# ─── Integration: Symlink to ~/.local/bin ────────────────────────────────────
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
if [ ! -L "$BIN_DIR/jack-in-a-box" ]; then
    ln -sf "$LAUNCHER" "$BIN_DIR/jack-in-a-box"
    ok "CLI command: jack-in-a-box"
fi

# ══════════════════════════════════════════════════════════════════════════════
#  DONE
# ══════════════════════════════════════════════════════════════════════════════
echo ""
if [ $ERRORS -eq 0 ]; then
    banner "  ╔══════════════════════════════════════════════════════╗"
    banner "  ║  ✓  JACK-IN-A-BOX — ALL SYSTEMS GO               ║"
    banner "  ╚══════════════════════════════════════════════════════╝"
else
    banner "  ╔══════════════════════════════════════════════════════╗"
    banner "  ║  ⚠  JACK-IN-A-BOX — $ERRORS issue(s) detected      ║"
    banner "  ╚══════════════════════════════════════════════════════╝"
fi

echo ""
echo -e "  ${BOLD}Installed Components:${NC}"
should_install hermes && echo -e "    ${GREEN}✓${NC} Hermes Agent      → $HERMES_DIR"
should_install neural && echo -e "    ${GREEN}✓${NC} Neural Memory     → $NEURAL_DIR"
should_install pulse  && echo -e "    ${GREEN}✓${NC} PULSE             → $PULSE_DIR"
should_install dlm    && echo -e "    ${GREEN}✓${NC} JackrabbitDLM     → $DLM_DIR (port $DLM_PORT)"
should_install crypto && echo -e "    ${GREEN}✓${NC} Jackrabbit WL     → $JRWL_DIR"

echo ""
echo -e "  ${BOLD}Quick Start:${NC}"
echo -e "    ${CYAN}jack-in-a-box${NC}                  # Launch everything"
echo -e "    ${CYAN}hermes${NC}                         # Start hermes CLI directly"
echo -e "    ${CYAN}pulse \"query\"${NC}                  # Run PULSE search"
echo -e "    ${CYAN}bash $BASE_DIR/launch.sh${NC}       # Full launcher"
echo ""
echo -e "  ${BOLD}Config:${NC}"
echo -e "    ${CYAN}$HERMES_HOME/config.yaml${NC}       # Hermes settings"
echo -e "    ${CYAN}$CONFIG_DIR/.env.example${NC}        # Environment variables template"
echo ""
echo -e "  ${BOLD}Services:${NC}"
if should_install dlm; then
    echo -e "    ${CYAN}sudo systemctl start jackrabbit-dlm@$USER${NC}   # Start DLM"
fi
if should_install crypto; then
    echo -e "    ${CYAN}sudo systemctl start hermes-gateway@$USER${NC}   # Start Gateway"
fi
echo ""
echo -e "  ${DIM}The human built the floor. The agent builds the rest.${NC}"
echo ""
