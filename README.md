# JACK-IN-A-BOX v1.0.3

> **THE HERMES STACK — Everything springs to life from a single command.**

A standalone all-in-one installer that clones, installs, and wires together the complete Hermes ecosystem into a working system. VM-tested on Debian 12.

---

## What's Inside

| Component | Repository | Purpose |
|-----------|-----------|---------|
| **Hermes Agent** | [itsXactlY/hermes-agent](https://github.com/itsXactlY/hermes-agent) (`dev/unified`) | The autonomous AI agent framework |
| **Neural Memory** | [itsXactlY/neural-memory](https://github.com/itsXactlY/neural-memory) | Local semantic memory with knowledge graph |
| **PULSE** | [itsXactlY/pulse-hermes](https://github.com/itsXactlY/pulse-hermes) | Autonomous social search engine (15+ sources, stdlib-only) |
| **Jackrabbit Wonderland** | [itsXactlY/Jackrabbit-wonderland](https://github.com/itsXactlY/Jackrabbit-wonderland) | LAN gateway + AES256-GCM encrypted sessions |
| **JackrabbitDLM** | [rapmd73/JackrabbitDLM](https://github.com/rapmd73/JackrabbitDLM) | Volatile key vault (port 37373) |

## Installation

### Full Stack (everything)

```bash
git clone https://github.com/itsXactlY/jack-in-a-box.git
cd jack-in-a-box
bash install.sh
```

### Lite Mode (hermes + neural + pulse, no crypto)

```bash
bash install.sh --lite
```

### Specific Components

```bash
bash install.sh --components hermes,neural,pulse
bash install.sh --components hermes,pulse
```

### Verify Existing Installation

```bash
bash install.sh --check
```

## After Installation

```bash
jack-in-a-box              # Launch Hermes (auto-selects kilo-auto/free)
hermes                     # Start hermes CLI directly
hermes chat -q "hello" -m kilo-auto/free  # Quick query
pulse "AI video tools"     # Run PULSE search
```

### Provider Configuration

The installer configures [Kilo Code](https://kilo.ai) as the default provider with the `kilo-auto/free` model. To use your own API key:

```bash
hermes setup               # Interactive setup wizard
hermes model               # Select provider/model
```

Or edit `~/.hermes/config.yaml` directly:

```yaml
model:
  api_key: "YOUR_KILOCODE_API_KEY"
  base_url: https://api.kilo.ai/api/gateway
  default_model: kilo-auto/free
  provider: kilo
```

Set your API key in `~/.hermes/.env`:

```
KILOCODE_API_KEY=your_key_here
```

### Services (if DLM + crypto installed)

```bash
sudo systemctl start jackrabbit-dlm@$USER
sudo systemctl start hermes-gateway@$USER
```

### Health Check

```bash
hermes doctor
```

## Directory Structure

```
~/jack-in-a-box/
├── hermes-agent/              # Hermes Agent (itsXactlY fork)
│   ├── venv/                  # Python virtual environment
│   ├── plugins/memory/neural/ # Neural Memory plugin
│   └── ...
├── neural-memory/             # Neural Memory (source)
├── pulse/                     # PULSE search engine
├── jackrabbit-dlm/            # DLM volatile vault
├── jackrabbit-wonderland/     # LAN gateway + crypto layer
├── launch.sh                  # Quick launcher
└── README.md
```

### Other Locations

```
~/.hermes/                     # Hermes config & data
~/.hermes/skills/              # Skills directory (PULSE linked)
~/.config/jack-in-a-box/       # Jack-in-a-box config
~/.config/pulse/               # PULSE config
/home/JackrabbitDLM/           # DLM volatile vault
```

## Requirements

- **Python 3.10+**
- **git**
- **Linux** (tested on Debian 12 + Garuda/Arch)
- **sudo** access (for DLM services only)
- Internet connection (for cloning + pip installs)

## Components Detail

### Hermes Agent

The fork from itsXactlY on the `dev/unified` branch. Core agent framework — conversation loop, tool orchestration, plugin system, gateway for Discord/Telegram/etc.

Default model: `kilo-auto/free` (free tier). The CLI has a hardcoded default of `anthropic/claude-opus-4.6` — always pass `-m kilo-auto/free` or use the launcher which does this automatically.

### Neural Memory

Local, offline semantic memory with knowledge graph. No API keys needed. Stores memories as embeddings, connects them via similarity, supports spreading activation for related ideas.

**Plugin mode:** Automatically installed into `hermes-agent/plugins/memory/neural/` so Hermes discovers it at startup.

Backend: FastEmbed (ONNX) by default. Falls back to hash-based embeddings if FastEmbed unavailable.

### PULSE

Autonomous social search engine. 15+ sources (Reddit, Hacker News, Polymarket, YouTube, arXiv, GitHub, RSS, Bluesky, Dev.to, Lemmy, OpenAlex, Semantic Scholar, StackExchange, Manifold, Metaculus). Pure Python stdlib — zero dependencies. Scored by real engagement, not SEO.

**Skill mode:** Linked into `~/.hermes/skills/devops/pulse/` for Hermes to use autonomously.

### Jackrabbit Wonderland

LAN-based control system for your AI. Control Hermes from any device on your network — browser, curl, netcat, iOS Shortcuts.

Includes:
- `remember::` protocol (base64 transport that LLMs can decode)
- LAN gateway (HTTP :8080 + raw TCP)
- AES256-GCM for local storage encryption
- DLM volatile key management

### JackrabbitDLM

Volatile key vault by Robert APM Darin. Runs on port 37373. Keys exist only in memory — when DLM stops, keys vanish. JSON-over-TCP protocol, zero dependencies.

---

## VM Testing

Tested on Debian 12 (KVM, 2GB RAM, 2 cores). 5 snapshots available:

```
~/vm-test/
├── boot-vm.sh              # Start VM
├── restore.sh              # List/restore snapshots
├── jack-test.qcow2         # Working disk (COW)
├── debian-12-generic-amd64.qcow2  # Base image (424MB)
└── cloud-init.iso          # SSH key + user setup

Snapshots:
1. clean                    — fresh Debian 12
2. lite-installed-working   — Jack-in-a-Box lite
3. hermes-working           — Hermes + REST API
4. full-stack-working       — everything installed
5. wonderland-gateway-working — Gateway -> Hermes verified
```

### Verified Test Results

```
✓ REST API            -> kilo-auto/free -> "Hi"
✓ Hermes CLI          -> chat -m kilo-auto/free -q 'Say hi' -> works
✓ PULSE               -> 'Bitcoin halving' -> 6 Reddit results
✓ Neural Memory       -> remember + recall -> 2 results
✓ DLM                 -> port 37373, alphabet soup encoding
✓ Gateway             -> status, shell, hermes commands
✓ Desktop -> VM       -> Gateway + DLM reachable
✓ Wonderland chain    -> curl -> gateway -> hermes -> API -> response
```

---

## Troubleshooting

### Hermes uses wrong model

Hermes CLI has a hardcoded default (`anthropic/claude-opus-4.6`). Always specify model:

```bash
hermes chat -q "hello" -m kilo-auto/free
```

Or use the launcher which defaults to `kilo-auto/free`.

### DLM won't start

```bash
# Check if port is in use
ss -tlnp | grep 37373

# Start manually
cd ~/jack-in-a-box/jackrabbit-dlm && python3 JackrabbitDLM 0.0.0.0 37373
```

### Neural Memory not discovered

```bash
# Check plugin exists
ls ~/jack-in-a-box/hermes-agent/plugins/memory/neural/

# Re-run installer
cd ~/jack-in-a-box/neural-memory && bash install.sh ~/jack-in-a-box/hermes-agent
```

### PULSE not found

```bash
# Check skill link
ls -la ~/.hermes/skills/devops/pulse

# Re-link
cd ~/jack-in-a-box/pulse && bash install.sh
```

### Gateway not reachable

```bash
# Check services
ss -tlnp | grep 8080

# Start manually
cd ~/jack-in-a-box/jackrabbit-wonderland && python3 lan_gateway.py --port 8080
```

### FastEmbed test fails during install

The model (intfloat/multilingual-e5-large, ~500MB) may timeout during download. It downloads automatically on first use. This is normal for slow connections or VMs.

### NumPy x86_v2 error in VM

QEMU's default CPU doesn't support x86_v2 instructions needed by NumPy 2.x. Use `-cpu host` when booting the VM:

```bash
qemu-system-x86_64 -enable-kvm -cpu host ...
```

---

## Changelog

### v1.0.3
- Config: `kilo` provider, `kilo-auto/free` model, `KILOCODE_API_KEY` env var
- Launcher: auto `chat -m kilo-auto/free` when no args passed
- Proper provider alias mapping (`kilo` -> `kilocode`)

### v1.0.2
- `python-dotenv` pre-install for hermes deps
- `PYTHONPATH` export in launcher for `hermes_cli` module discovery

### v1.0.1
- 11 installer bug fixes (arg parsing, DLM paths, fastembed, skill links, error handling, pip, config, env)

### v1.0.0
- Initial release

---

## Philosophy

> **The human built the floor. The agent builds the rest.**

Jack-in-a-Box is not a finished product. It's a foundation — five systems wired together that should evolve autonomously. The installer gets you to the starting line. What happens next is up to Hermes.

---

## License

Each component retains its original license. See individual repositories for details.
Jack-in-a-Box installer itself is MIT.
