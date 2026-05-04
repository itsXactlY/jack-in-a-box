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
JIAB_VERSION="2.0.0-dev"

# ─── Config ──────────────────────────────────────────────────────────────────
BASE_DIR="${JIAB_INSTALL_DIR:-$HOME/jack-in-a-box}"
HERMES_REPO="https://github.com/itsXactlY/hermes-agent.git"
HERMES_BRANCH="dev/unified"
NEURAL_REPO="https://github.com/itsXactlY/neural-memory.git"
NEURAL_BRANCH="main"
MAZEMAKER_REPO="https://github.com/itsXactlY/mazemaker-v2-backend.git"
MAZEMAKER_BRANCH="main"
MAZEMAKER_ENGINE_REPO="https://github.com/itsXactlY/mazemaker.git"
MAZEMAKER_ENGINE_BRANCH="master"
PULSE_REPO="https://github.com/itsXactlY/pulse-hermes.git"
PULSE_BRANCH="main"
JRWL_REPO="https://github.com/itsXactlY/Jackrabbit-wonderland.git"
JRWL_BRANCH="main"
DLM_REPO="https://github.com/rapmd73/JackrabbitDLM.git"

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
# Hermes' canonical install layout: source repo at ~/.hermes/hermes-agent/,
# venv inside it, plugins + skills + config at ~/.hermes/. Migrating from
# the legacy jack-in-a-box layout ($BASE_DIR/hermes-agent) — see the
# auto-migration block below in the Hermes step.
HERMES_DIR="${HERMES_DIR:-$HERMES_HOME/hermes-agent}"
HERMES_DIR_LEGACY="$BASE_DIR/hermes-agent"
NEURAL_DIR="${NEURAL_DIR:-$BASE_DIR/neural-memory}"
MAZEMAKER_DIR="${MAZEMAKER_DIR:-$BASE_DIR/mazemaker-v2-stack}"
MAZEMAKER_ENGINE_DIR="${MAZEMAKER_ENGINE_DIR:-$HOME/mazemaker-engine}"
PULSE_DIR="${PULSE_DIR:-$BASE_DIR/pulse}"
JRWL_DIR="${JRWL_DIR:-$BASE_DIR/jackrabbit-wonderland}"
DLM_DIR="${DLM_DIR:-/home/JackrabbitDLM}"

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
            echo "    --components X,Y   Install specific: hermes,mazemaker,neural,pulse,dlm,crypto"
            echo "    --skip-firewall    Skip nftables firewall rules"
            echo "    --lite             Skip DLM + crypto (hermes + mazemaker + pulse only)"
            echo "    --help             Show this help"
            echo ""
            echo "  Components:"
            echo "    hermes     — Hermes Agent (itsXactlY fork, dev/unified)"
            echo "    mazemaker  — Mazemaker V2 customer pod (default semantic-memory backend)"
            echo "    neural     — Neural Memory V1 (legacy, opt-in only)"
            echo "    pulse      — PULSE (autonomous social search)"
            echo "    dlm        — JackrabbitDLM (volatile key vault)"
            echo "    crypto     — Jackrabbit Wonderland (AES256 crypto layer)"
            echo ""
            exit 0
            ;;
    esac
done

# Determine which components to install
if [ -n "$COMPONENTS" ]; then
    IFS=',' read -ra INSTALL_LIST <<< "$COMPONENTS"
else
    # mazemaker (V2) is the default semantic-memory backend. The legacy
    # `neural` (V1) component is opt-in only via --components for users
    # who want the in-process Mazemaker engine instead of the containerized
    # V2 customer pod.
    if $LITE_MODE; then
        INSTALL_LIST=(hermes mazemaker pulse)
    else
        INSTALL_LIST=(hermes mazemaker pulse dlm crypto)
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
should_install hermes    && TOTAL_STEPS=$((TOTAL_STEPS + 1)) || true
should_install mazemaker && TOTAL_STEPS=$((TOTAL_STEPS + 1)) || true
should_install neural    && TOTAL_STEPS=$((TOTAL_STEPS + 1)) || true
should_install pulse     && TOTAL_STEPS=$((TOTAL_STEPS + 1)) || true
should_install dlm       && TOTAL_STEPS=$((TOTAL_STEPS + 1)) || true
should_install crypto    && TOTAL_STEPS=$((TOTAL_STEPS + 1)) || true
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
# Hermes' upstream pyproject.toml currently pins requires-python = ">=3.14",
# which Debian 12 (Python 3.11) and even Debian 13 (3.13) don't satisfy
# without manual python3.14 install. The hermes step below will fail to
# `pip install -e .` on lower versions; the rest of the stack still works.
# Surface this loud + early so the user knows what to fix BEFORE blaming
# the installer.
if should_install hermes; then
    if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 14 ]; }; then
        info "Hermes-agent's pyproject.toml requires Python >=3.14, you have $PY_VERSION."
        info "  The Hermes step will pass --ignore-requires-python to pip + install"
        info "  the core deps (anthropic, openai, ...) explicitly — should work fine."
        info "  If you hit runtime issues, install python3.14 (deadsnakes / pyenv / uv)."
    fi
fi

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
        echo -e "  ${DIM}Tip: run with sudo or use --lite for hermes+mazemaker+pulse only${NC}"
    fi
fi

# ─── System packages (Debian-family fresh-VM defenses) ──────────────────────
# Truly-fresh Debian 12/13 minimal images don't have python3-venv (separate
# package!), curl, or build-essential. The downstream installers fail with
# obscure errors ("python3 -m venv ..." returns ensurepip is not available
# / "command not found: cc" / etc) without these. Try to detect + install
# automatically when sudo is sandbox-available; otherwise print the apt
# command the user needs to run.
ensure_apt_essentials() {
    [ -f /etc/os-release ] || return 0
    . /etc/os-release
    case "${ID:-}${ID_LIKE:-}" in
        debian*|ubuntu*|*debian*) ;;
        *) return 0 ;;  # skip on non-debian-family — those distros have
                        # different package names and the user is probably
                        # already past this if they got that far
    esac

    local needed=()
    # python3-venv → python3 -m venv (separate package on Debian!)
    dpkg -s python3-venv >/dev/null 2>&1 || needed+=(python3-venv)
    # python3-pip → for fallback paths
    dpkg -s python3-pip >/dev/null 2>&1 || needed+=(python3-pip)
    # curl → for source.tar.gz, node download
    command -v curl >/dev/null 2>&1 || needed+=(curl)
    # tar gzip — usually present but defensive
    command -v tar >/dev/null 2>&1 || needed+=(tar)
    # build toolchain for any pip sdist fallbacks (cryptography on non-x86_64,
    # etc). Cheap to install; skips if already present.
    dpkg -s build-essential >/dev/null 2>&1 || needed+=(build-essential)
    dpkg -s python3-dev     >/dev/null 2>&1 || needed+=(python3-dev)
    dpkg -s libssl-dev      >/dev/null 2>&1 || needed+=(libssl-dev)
    dpkg -s libffi-dev      >/dev/null 2>&1 || needed+=(libffi-dev)
    dpkg -s rsync           >/dev/null 2>&1 || needed+=(rsync)

    if [ ${#needed[@]} -eq 0 ]; then
        ok "apt essentials present"
        return 0
    fi

    warn "Missing system packages: ${needed[*]}"
    if sudo -n true 2>/dev/null; then
        info "Installing missing packages (sudo cached)..."
        if sudo apt-get update -qq && sudo apt-get install -y "${needed[@]}"; then
            ok "Installed: ${needed[*]}"
        else
            fail "apt install failed — install manually: sudo apt install ${needed[*]}"
            exit 1
        fi
    else
        warn "  Sudo not cached. Run this in another terminal, then re-run install.sh:"
        warn "  sudo apt update && sudo apt install -y ${needed[*]}"
        exit 1
    fi
}
ensure_apt_essentials

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

    # ── auto-migration: legacy $BASE_DIR/hermes-agent → ~/.hermes/hermes-agent
    # Older jack-in-a-box installs (≤ v1.x) put hermes at $BASE_DIR/hermes-agent.
    # The canonical layout has it under $HERMES_HOME/hermes-agent so config,
    # plugins, skills, and source all live in one tree. Migrate in place — never
    # leave duplicates lying around.
    if [ -d "$HERMES_DIR_LEGACY/.git" ] && [ ! -e "$HERMES_DIR" ]; then
        info "Migrating Hermes from legacy path → $HERMES_DIR"
        mkdir -p "$(dirname "$HERMES_DIR")"
        mv "$HERMES_DIR_LEGACY" "$HERMES_DIR"
        # The venv inside contains absolute path references — rebuild it.
        if [ -d "$HERMES_DIR/venv" ]; then
            warn "Removing pre-migration venv (absolute paths invalidated)"
            rm -rf "$HERMES_DIR/venv"
        fi
        ok "Migration done — old path retired"
    elif [ -d "$HERMES_DIR_LEGACY/.git" ] && [ -d "$HERMES_DIR/.git" ]; then
        warn "Both old ($HERMES_DIR_LEGACY) and new ($HERMES_DIR) Hermes installs exist."
        warn "Manual cleanup required — keep $HERMES_DIR, remove $HERMES_DIR_LEGACY when sure."
    fi

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
            # NOT --single-branch: hermes' OWN scripts/install.sh defaults
            # to `git checkout main` for self-update; if `main` isn't in
            # the local clone (--single-branch dev/unified would do that)
            # the user gets `error: pathspec 'main' did not match`. Full
            # clone keeps both jack-in-a-box's and hermes' updaters working.
            git clone --branch "$HERMES_BRANCH" "$HERMES_REPO" "$HERMES_DIR"
        fi
        ok "Hermes Agent at $HERMES_DIR"

        # Virtual environment
        if [ ! -d "$HERMES_DIR/venv" ]; then
            info "Creating virtual environment..."
            cd "$HERMES_DIR"
            $PYTHON -m venv venv
            ok "Virtual environment created"
        fi

        # Delegate to Hermes' OWN installer — it handles uv/Python/Node/
        # ripgrep/ffmpeg detection, system-package install, venv setup,
        # all dep installation (anthropic, openai, rich, httpx, ...),
        # and CLI wiring far more thoroughly than we can shadow here.
        # Pre-clone above made sure the dir + remote URL point at our
        # itsXactlY fork on the right branch; hermes' installer sees
        # the existing dir and runs its update path.
        info "Delegating to Hermes' own installer (handles uv, Node, deps, venv)..."
        if [ -x "$HERMES_DIR/scripts/install.sh" ]; then
            HERMES_INSTALL_OK=0
            if bash "$HERMES_DIR/scripts/install.sh" \
                    --branch "$HERMES_BRANCH" \
                    --dir "$HERMES_DIR" \
                    --skip-setup; then
                HERMES_INSTALL_OK=1
                ok "Hermes installer completed"
            else
                warn "Hermes' own installer reported issues — checking what we got"
            fi

            # Belt: even if hermes' installer failed mid-way, ensure the
            # core LLM SDKs are in the venv so any subsequent hermes call
            # at least imports. Cheap idempotent op.
            VENV_PIP=""
            for cand in \
                "$HERMES_DIR/.venv/bin/pip" \
                "$HERMES_DIR/venv/bin/pip"; do
                [ -x "$cand" ] && VENV_PIP="$cand" && break
            done
            if [ -n "$VENV_PIP" ]; then
                info "  belt-check: ensuring core LLM SDKs are present in $VENV_PIP"
                $VENV_PIP install --quiet --disable-pip-version-check \
                    --ignore-requires-python \
                    "openai>=2.21.0,<3" \
                    "anthropic>=0.39.0,<1" \
                    "python-dotenv>=1.2.1,<2" \
                    "httpx[socks]>=0.28.1,<1" \
                    "rich>=14.3.3,<15" \
                    "pydantic>=2.12.5,<3" \
                    "PyJWT[crypto]>=2.12.0,<3" \
                    2>&1 | tail -3 \
                    || warn "  belt-check pip install reported issues — non-fatal"
            else
                warn "No venv pip found (hermes' installer didn't create $HERMES_DIR/{.venv,venv})"
            fi
        else
            warn "$HERMES_DIR/scripts/install.sh not found — repo layout changed?"
            warn "  Falling back to manual venv + pip install. Some deps may be missing."
            cd "$HERMES_DIR"
            $PYTHON -m venv venv 2>/dev/null || true
            "$HERMES_DIR/venv/bin/pip" install --upgrade pip --quiet --disable-pip-version-check 2>/dev/null || true
            "$HERMES_DIR/venv/bin/pip" install --quiet --ignore-requires-python -e . 2>&1 | tail -3 \
                || warn "Fallback pip install -e . failed"
        fi

        # Wrapper at ~/.local/bin/hermes — hermes' own installer doesn't
        # create one (it expects either uv-managed PATH or `source venv/bin/activate`).
        # Make a portable wrapper that finds whichever venv hermes set up.
        mkdir -p "$HOME/.local/bin"
        cat > "$HOME/.local/bin/hermes" << HERMESCMD
#!/usr/bin/env bash
# Hermes Agent — quick launcher (works regardless of PATH)
HERMES_DIR="$HERMES_DIR"
# Try uv-style .venv first, fall back to plain venv
for venv_dir in "\$HERMES_DIR/.venv" "\$HERMES_DIR/venv"; do
    if [ -x "\$venv_dir/bin/hermes" ]; then
        exec "\$venv_dir/bin/hermes" "\$@"
    fi
    if [ -f "\$venv_dir/bin/activate" ]; then
        source "\$venv_dir/bin/activate"
        export PYTHONPATH="\$HERMES_DIR:\${PYTHONPATH:-}"
        cd "\$HERMES_DIR"
        exec python3 -m hermes_cli.main "\$@"
    fi
done
echo "ERROR: no Hermes venv found at \$HERMES_DIR/.venv or /venv" >&2
exit 1
HERMESCMD
        chmod +x "$HOME/.local/bin/hermes"
        ok "hermes wrapper at ~/.local/bin/hermes (handles both .venv + venv layouts)"

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
#  STEP 2: MAZEMAKER V2 CUSTOMER POD
# ══════════════════════════════════════════════════════════════════════════════
#
#  Replaces the V1 in-process neural-memory engine with the containerized
#  V2 customer pod (4 systemd-Quadlet services: license-client, mcp,
#  embedding-worker, wonderland). Speaks MCP over HTTP/SSE on
#  http://127.0.0.1:8765 and is wired into Hermes via two compat bridges
#  (Unix socket + stdio) so existing Hermes code paths work unchanged.
#
#  The V2 install.sh inside the cloned repo handles its own:
#    - host-Python-deps (cryptography auto-provisioned in venv)
#    - browser onboard wizard (requires email + captcha confirmation)
#    - license JWT issue + Quadlet unit install
#    - bge-m3 / FastEmbed model download
#    - import-grace marker (auto-pruning lockout for 7 days)
# ══════════════════════════════════════════════════════════════════════════════
if should_install mazemaker; then
    step $CURRENT_STEP "Mazemaker V2 customer pod"
    CURRENT_STEP=$((CURRENT_STEP + 1))

    if [ "$MODE" = "check" ]; then
        if [ -f "$MAZEMAKER_DIR/installer/linux/install.sh" ]; then
            ok "Mazemaker V2 stack at $MAZEMAKER_DIR"
        else
            fail "Mazemaker V2 stack not present"
        fi
        if systemctl --user is-active --quiet mazemaker-pod.service 2>/dev/null; then
            ok "mazemaker-pod.service active"
        else
            warn "mazemaker-pod.service not running (run install.sh without --check)"
        fi
        if [ -S "$HOME/.mazemaker/mcp.sock" ]; then
            ok "Hermes-compat socket bridge present at ~/.mazemaker/mcp.sock"
        else
            warn "Socket bridge not running (Hermes' memory plugin will be broken)"
        fi
    else
        # Source: the public source.tar.gz endpoint that the customer-facing
        # install.sh also uses. Contains the V2 backend AND `runtime-payload/
        # core/` (engine bundled by Hetzner's install-backend.sh) — so we
        # don't need to clone mazemaker-v2-backend OR mazemaker-engine
        # separately. Avoids the GitHub-private-repo auth prompt entirely.
        #
        # Devs who want a git working copy of either repo can opt-in via
        # JIAB_MAZEMAKER_USE_GIT=1 — falls back to git clone of both repos.
        SOURCE_URL="${JIAB_MAZEMAKER_SOURCE_URL:-https://api.mazemaker.dev/source.tar.gz}"
        if [ "${JIAB_MAZEMAKER_USE_GIT:-0}" = "1" ]; then
            info "JIAB_MAZEMAKER_USE_GIT=1 — cloning git repos (requires GitHub auth for the V2 backend)"
            if [ -d "$MAZEMAKER_ENGINE_DIR/.git" ]; then
                info "Mazemaker engine already cloned — pulling latest..."
                git -C "$MAZEMAKER_ENGINE_DIR" fetch origin && \
                    git -C "$MAZEMAKER_ENGINE_DIR" pull --ff-only origin "$MAZEMAKER_ENGINE_BRANCH" \
                    || warn "Could not fast-forward engine repo"
            else
                info "Cloning mazemaker engine ($MAZEMAKER_ENGINE_BRANCH)..."
                git clone --branch "$MAZEMAKER_ENGINE_BRANCH" --single-branch \
                    "$MAZEMAKER_ENGINE_REPO" "$MAZEMAKER_ENGINE_DIR"
            fi
            ok "Mazemaker engine at $MAZEMAKER_ENGINE_DIR"

            if [ -d "$MAZEMAKER_DIR/.git" ]; then
                info "Mazemaker V2 stack already cloned — pulling latest..."
                git -C "$MAZEMAKER_DIR" fetch origin && \
                    git -C "$MAZEMAKER_DIR" pull --ff-only origin "$MAZEMAKER_BRANCH" \
                    || warn "Could not fast-forward V2 stack repo"
            else
                info "Cloning Mazemaker V2 stack ($MAZEMAKER_BRANCH)..."
                git clone --branch "$MAZEMAKER_BRANCH" --single-branch \
                    "$MAZEMAKER_REPO" "$MAZEMAKER_DIR"
            fi
            ok "Mazemaker V2 stack at $MAZEMAKER_DIR"
        else
            # Tarball path — public, no auth, ships with runtime-payload/core/
            info "Downloading Mazemaker V2 source tarball from $SOURCE_URL"
            mkdir -p "$MAZEMAKER_DIR"
            TMP_TAR=$(mktemp --suffix=.tar.gz)
            if ! curl -fsSL --user-agent "jack-in-a-box/$JIAB_VERSION" \
                    "$SOURCE_URL" -o "$TMP_TAR"; then
                rm -f "$TMP_TAR"
                fail "Could not download $SOURCE_URL — check connectivity / DNS"
                exit 1
            fi
            # Tarball contains a single top-level dir like mazemaker-v2-backend/.
            # Extract, then move that dir's contents into $MAZEMAKER_DIR (idempotent).
            EXTRACT_TMP=$(mktemp -d)
            tar -xzf "$TMP_TAR" -C "$EXTRACT_TMP"
            INNER=$(find "$EXTRACT_TMP" -maxdepth 1 -mindepth 1 -type d | head -1)
            if [ -z "$INNER" ]; then
                rm -rf "$EXTRACT_TMP" "$TMP_TAR"
                fail "Tarball had no top-level directory"
                exit 1
            fi
            # Wipe the destination's tracked files (keep .last-import + data/
            # if a prior install left them) before re-staging.
            for entry in "$MAZEMAKER_DIR"/*; do
                [ -e "$entry" ] || continue
                base=$(basename "$entry")
                # Preserve user state from prior installs
                case "$base" in
                    data|.last-import) continue ;;
                esac
                rm -rf "$entry"
            done
            cp -r "$INNER"/* "$MAZEMAKER_DIR"/
            rm -rf "$EXTRACT_TMP" "$TMP_TAR"
            ok "Mazemaker V2 stack extracted to $MAZEMAKER_DIR (no GitHub auth required)"
        fi

        # Run the V2 customer-pod installer. Default to free-tier fastembed
        # via --embed-provider so the install is non-interactive (the user
        # can switch to sentence-transformers / BYOK later in the dashboard).
        # MAZEMAKER_DIR is intentionally left as default ~/.mazemaker so
        # the Quadlet templates' %h/.mazemaker mounts line up.
        info "Running V2 customer-pod installer (this fetches images, may take ~10min)..."
        info "  Browser will open for email + captcha onboarding — confirm there."
        bash "$MAZEMAKER_DIR/installer/linux/install.sh" \
            --remote https://api.mazemaker.dev \
            --embed-provider fastembed \
            || warn "V2 installer reported issues — check ~/.mazemaker/ + journal"

        # Hermes compat bridges. The V2 stack ships two daemons that proxy
        # legacy V1 wires (Unix socket + stdio) to the V2 wonderland HTTP
        # endpoint. Without these, Hermes' memory plugin and
        # mcp_servers.mazemaker spawn fall back to the V1 mcp_local.py
        # which writes to a stale, empty DB.
        BRIDGES_SRC="$MAZEMAKER_DIR/installer/linux/mcp-socket-bridge"
        if [ -d "$BRIDGES_SRC" ]; then
            info "Installing Hermes compat bridges (socket + stdio)..."
            # `install` doesn't create parent dirs — fresh VMs may not have
            # ~/.local/bin or ~/.config/systemd/user yet.
            mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
            install -m 755 "$BRIDGES_SRC/mazemaker-mcp-socket-bridge.py" \
                ~/.local/bin/mazemaker-mcp-socket-bridge.py
            install -m 755 "$BRIDGES_SRC/mazemaker-mcp-stdio-bridge.py" \
                ~/.local/bin/mazemaker-mcp-stdio-bridge.py
            install -m 644 "$BRIDGES_SRC/mazemaker-mcp-socket-bridge.service" \
                ~/.config/systemd/user/mazemaker-mcp-socket-bridge.service
            systemctl --user daemon-reload
            systemctl --user enable --now mazemaker-mcp-socket-bridge.service \
                || warn "Could not start socket bridge — check journalctl --user"
            ok "Bridges installed (socket on ~/.mazemaker/mcp.sock, stdio at ~/.local/bin/)"
        else
            warn "Bridge sources not in V2 repo — Hermes-compat path won't work"
        fi

        # ── Hermes ↔ Mazemaker wiring (both code paths) ─────────────────
        # Hermes talks to mazemaker through TWO independent paths in its
        # codebase. BOTH need to be configured for a fresh install:
        #
        # 1. memory: plugin (~/.hermes/plugins/memory/mcp/) — uses the
        #    Unix-socket protocol at ~/.mazemaker/mcp.sock. Speaks
        #    length-prefixed JSON-RPC. Bridged by mazemaker-mcp-socket-
        #    bridge.service which forwards to wonderland HTTP /mcp.
        #
        # 2. mcp_servers.mazemaker — Hermes spawns a stdio MCP process
        #    per session. Bridged by mazemaker-mcp-stdio-bridge.py which
        #    speaks newline-JSON and forwards to wonderland HTTP /mcp.
        #
        # Earlier patch only handled (2) AND only when an `mcp_servers:`
        # block already existed. On fresh installs Hermes' default config
        # has neither section → patch silently did nothing → Hermes had
        # ZERO mazemaker integration. Fixed below: idempotent, creates
        # both sections if absent, replaces existing entries if present.
        if [ -f "$HERMES_HOME/config.yaml" ]; then
            cp "$HERMES_HOME/config.yaml" "$HERMES_HOME/config.yaml.bak.pre-mazemaker-v2"
            info "Patching Hermes config.yaml — memory: + mcp_servers.mazemaker (both paths)"
            python3 - "$HERMES_HOME/config.yaml" <<'PYEOF' || warn "config.yaml patch failed — manual edit needed"
import os, re, sys, pathlib

p = pathlib.Path(sys.argv[1])
text = p.read_text()
home = os.path.expanduser("~")

# ─── Block 1: memory: section pointing at the socket bridge
memory_block = (
    "memory:\n"
    "  memory_enabled: true\n"
    "  user_profile_enabled: false\n"
    "  memory_char_limit: 5000\n"
    "  user_char_limit: 5\n"
    "  provider: mcp\n"
    "  mcp:\n"
    "    socket_path: ~/.mazemaker/mcp.sock\n"
    "    spawn_fallback: false\n"
    "    request_timeout: 30.0\n"
)

# ─── Block 2: mcp_servers: with mazemaker subkey using stdio bridge
mcp_servers_block = (
    "mcp_servers:\n"
    "  mazemaker:\n"
    "    command: python3\n"
    "    args:\n"
    "    - " + home + "/.local/bin/mazemaker-mcp-stdio-bridge.py\n"
    "    env:\n"
    "      MM_BRIDGE_URL: http://127.0.0.1:8765/mcp\n"
    "      MM_BRIDGE_TIMEOUT: '30'\n"
)

# Patch memory: section — replace if exists, prepend if not.
if re.search(r"^memory:\s*$", text, re.M):
    # Replace the entire memory: block (until next top-level key OR EOF)
    text = re.sub(
        r"^memory:\s*\n(?:[ \t]+.*\n|\s*\n)*",
        memory_block,
        text,
        count=1,
        flags=re.M,
    )
    print("[patch] memory: block replaced")
else:
    text = memory_block + "\n" + text
    print("[patch] memory: block prepended (none existed)")

# Patch mcp_servers section — same logic.
if re.search(r"^mcp_servers:\s*$", text, re.M):
    # Within mcp_servers, replace the mazemaker subkey
    if re.search(r"^  mazemaker:\s*$", text, re.M):
        text = re.sub(
            r"^  mazemaker:\s*\n(?:[ \t]+.*\n|\s*\n)*",
            mcp_servers_block.split("\n", 1)[1],  # everything after "mcp_servers:" line, but indented
            text,
            count=1,
            flags=re.M,
        )
        print("[patch] mcp_servers.mazemaker subkey replaced")
    else:
        # Append our mazemaker block right after the mcp_servers: line
        new_subkey = "  mazemaker:\n" + "\n".join(
            "  " + line for line in mcp_servers_block.split("\n")[2:] if line
        ) + "\n"
        text = re.sub(r"^(mcp_servers:\s*\n)", r"\1" + new_subkey, text, count=1, flags=re.M)
        print("[patch] mcp_servers.mazemaker subkey appended")
else:
    text = text.rstrip() + "\n\n" + mcp_servers_block
    print("[patch] mcp_servers: block appended (none existed)")

p.write_text(text)
print("[patch] config.yaml wired for both memory.mcp + mcp_servers.mazemaker")
PYEOF
            ok "Hermes config.yaml patched — both wiring paths active (backup at .bak.pre-mazemaker-v2)"
        else
            warn "$HERMES_HOME/config.yaml missing — skipping Hermes wiring (run hermes once first)"
        fi

        # Claude Code MCP — register if `claude` binary is in PATH. Idempotent:
        # `claude mcp add` errors if entry exists, so we remove first.
        if command -v claude >/dev/null 2>&1; then
            info "Registering 'neural-memory' with Claude Code (~/.claude.json)..."
            claude mcp remove neural-memory --scope user 2>/dev/null || true
            claude mcp add --transport http --scope user neural-memory \
                http://127.0.0.1:8765/mcp 2>&1 | tail -3 \
                || warn "Could not register Claude Code MCP — run manually"
            ok "Claude Code MCP wired (verify: claude mcp list)"
        else
            info "Claude Code (claude) not found in PATH — skipping; install separately + run:"
            info "  claude mcp add --transport http --scope user neural-memory http://127.0.0.1:8765/mcp"
        fi
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 2-LEGACY: NEURAL MEMORY V1 (opt-in only via --components neural)
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
            info "Running PULSE installer check..."
            (cd "$PULSE_DIR" && bash install.sh --check)
            ok "PULSE installer check passed"
        else
            fail "PULSE not installed"
        fi
    else
        if [ -d "$PULSE_DIR/.git" ]; then
            info "PULSE already cloned at $PULSE_DIR"
            cd "$PULSE_DIR"
            if git diff --quiet && git diff --cached --quiet; then
                info "PULSE clean — pulling latest..."
                git fetch origin
                git pull origin main --ff-only
            else
                warn "PULSE has local changes — skipping pull to avoid overwriting work"
            fi
        else
            info "Cloning PULSE..."
            git clone "$PULSE_REPO" "$PULSE_DIR"
        fi
        ok "PULSE at $PULSE_DIR"

        # Run the PULSE installer (links skill + CLI)
        if [ -f "$PULSE_DIR/install.sh" ]; then
            info "Running PULSE installer..."
            cd "$PULSE_DIR"
            bash install.sh
            ok "PULSE installed (skill + CLI)"
        else
            fail "PULSE installer missing at $PULSE_DIR/install.sh"
            exit 1
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
            # Fix ownership: sudo git clone creates root-owned files, but DLM runs as $USER
            sudo chown -R $(id -un):$(id -gn) "$DLM_DIR" 2>/dev/null || true
        fi
        ok "DLM at $DLM_DIR"

        # Install DLM dependencies (psutil) — must work on externally-managed Python (Debian 12)
        info "Installing DLM dependencies..."
        if [ -f "$DLM_DIR/requirements.txt" ]; then
            $PIP install --break-system-packages -r "$DLM_DIR/requirements.txt" 2>/dev/null \
                || $PYTHON -m pip install --break-system-packages -r "$DLM_DIR/requirements.txt" 2>/dev/null \
                || warn "Could not install DLM dependencies (psutil may already be installed)"
            ok "DLM dependencies installed"
        else
            # Fallback: just psutil if no requirements.txt
            $PIP install --break-system-packages psutil 2>/dev/null \
                || $PYTHON -m pip install --break-system-packages psutil 2>/dev/null \
                || true
        fi

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
        # Install pycryptodome into hermes-agent venv (bypass activation to avoid externally-managed issues)
        if [ -f "$HERMES_DIR/venv/bin/pip" ]; then
            $HERMES_DIR/venv/bin/pip install --quiet pycryptodome 2>/dev/null \
                || $HERMES_DIR/venv/bin/pip install pycryptodome
        else
            $PIP install --break-system-packages pycryptodome --quiet 2>/dev/null \
                || $PYTHON -m pip install --break-system-packages pycryptodome --quiet 2>/dev/null \
                || $PIP install pycryptodome --quiet 2>/dev/null
        fi
        ok "pycryptodome installed"
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
if should_install hermes; then
    if [ -d "$HERMES_DIR" ] && [ -f "$HERMES_DIR/run_agent.py" ]; then
        ok "Hermes Agent ✓"
    else
        fail "Hermes Agent ✗"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Mazemaker V2
if should_install mazemaker; then
    if [ -d "$MAZEMAKER_DIR/.git" ] && [ -d "$MAZEMAKER_ENGINE_DIR/.git" ]; then
        if systemctl --user is-active --quiet mazemaker-pod.service 2>/dev/null; then
            ok "Mazemaker V2 customer pod ✓ (5 services active)"
        else
            warn "Mazemaker V2 cloned but pod not running"
        fi
        if [ -S "$HOME/.mazemaker/mcp.sock" ]; then
            ok "Hermes-compat socket bridge ✓"
        else
            warn "Socket bridge missing"
        fi
    else
        fail "Mazemaker V2 ✗"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Neural Memory V1 (legacy)
if should_install neural; then
    if [ -d "$NEURAL_DIR" ] && [ -f "$NEURAL_DIR/install.sh" ]; then
        ok "Neural Memory V1 ✓ (legacy)"
    else
        fail "Neural Memory V1 ✗"
        ERRORS=$((ERRORS + 1))
    fi
fi

# PULSE
if should_install pulse; then
    if [ -d "$PULSE_DIR" ] && [ -f "$PULSE_DIR/install.sh" ]; then
        if [ -x "$HOME/.local/bin/pulse" ] && "$HOME/.local/bin/pulse" --diagnose >/dev/null 2>&1; then
            ok "PULSE ✓"
        else
            fail "PULSE ✗ (CLI diagnostics failed)"
            ERRORS=$((ERRORS + 1))
        fi
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

if [ $ERRORS -ne 0 ]; then
    exit 1
fi
