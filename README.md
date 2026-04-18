# JACK-IN-A-BOX v1.0.0

> **THE HERMES STACK — Everything springs to life from a single command.**

A standalone all-in-one installer that clones, installs, and wires together the complete Hermes ecosystem into a working system.

---

## What's Inside

| Component | Repository | Purpose |
|-----------|-----------|---------|
| **Hermes Agent** | [itsXactlY/hermes-agent](https://github.com/itsXactlY/hermes-agent) (`dev/unified`) | The autonomous AI agent framework |
| **Neural Memory** | [itsXactlY/neural-memory](https://github.com/itsXactlY/neural-memory) | Local semantic memory with knowledge graph |
| **PULSE** | [itsXactlY/pulse-hermes](https://github.com/itsXactlY/pulse-hermes) | Autonomous social search engine (15+ sources, stdlib-only) |
| **Jackrabbit Wonderland** | [itsXactlY/Jackrabbit-wonderland](https://github.com/itsXactlY/Jackrabbit-wonderland) | AES256-GCM encrypted sessions + LAN gateway |
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

### Skip Firewall Rules

```bash
bash install.sh --skip-firewall
```

## After Installation

```bash
jack-in-a-box              # Launch everything
hermes                     # Start hermes CLI directly
pulse "AI video tools"     # Run PULSE search
```

### Services (if DLM + crypto installed)

```bash
sudo systemctl start jackrabbit-dlm@$USER
sudo systemctl start hermes-gateway@$USER
```

### Health Check

```bash
bash install.sh --check
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
├── jackrabbit-wonderland/     # Crypto layer
├── launch.sh                  # Quick launcher
└── README.md
```

### Other Locations

```
~/.hermes/                     # Hermes config & data
~/.hermes/skills/              # Skills directory (PULSE, JRWL linked)
~/.config/jack-in-a-box/       # Jack-in-a-box config
/home/JackrabbitDLM/           # DLM volatile vault
/opt/hermes-crypto/            # JRWL deployed files
```

## Requirements

- **Python 3.10+**
- **git**
- **Linux** (tested on Garuda/Arch)
- **sudo** access (for DLM + crypto services only)
- Internet connection (for cloning + pip installs)

## Components Detail

### Hermes Agent

The fork from itsXactlY on the `dev/unified` branch. This is the core agent framework — conversation loop, tool orchestration, plugin system, gateway for Discord/Telegram/etc.

### Neural Memory

Local, offline semantic memory with knowledge graph. No API keys needed. Stores memories as embeddings, connects them via similarity, supports spreading activation for related ideas.

**Plugin mode:** Automatically installed into `hermes-agent/plugins/memory/neural/` so Hermes discovers it at startup.

### PULSE

Autonomous social search engine. 15+ sources (Reddit, Hacker News, Polymarket, YouTube, arXiv, GitHub, RSS...). Pure Python stdlib — zero dependencies. Scored by real engagement, not SEO.

**Skill mode:** Linked into `~/.hermes/skills/devops/pulse/` for Hermes to use autonomously.

### Jackrabbit Wonderland

AES256-GCM encrypted sessions. Protects against log scraping and casual surveillance (not cryptographic security — the provider sees the key in system prompt, but automated scanners don't flag it).

Includes:
- `remember::` protocol (base64 transport for LLMs)
- LAN gateway (HTTP :8080 + raw TCP :37374)
- Systemd services for auto-start
- nftables rules for LAN-only access

### JackrabbitDLM

Volatile key vault. Runs on port 37373. Keys exist only in memory — when DLM stops, keys vanish. Used by Jackrabbit Wonderland for session key management.

---

## Troubleshooting

### DLM won't start
```bash
# Check if port is in use
ss -tlnp | grep 37373

# Start manually
cd /home/JackrabbitDLM && python3 JackrabbitDLM 0.0.0.0 37373
```

### Neural Memory not discovered
```bash
# Check plugin exists
ls ~/.hermes/hermes-agent/plugins/memory/neural/

# Re-run installer
cd ~/jack-in-a-box/neural-memory && bash install.sh ~/.hermes/hermes-agent
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
systemctl status jackrabbit-dlm@$USER
systemctl status hermes-gateway@$USER

# Check nftables
sudo nft list ruleset | grep 8080
```

---

## Philosophy

> **The human built the floor. The agent builds the rest.**

Jack-in-a-Box is not a finished product. It's a foundation — four systems wired together that should evolve autonomously. The installer gets you to the starting line. What happens next is up to Hermes.

---

## License

Each component retains its original license. See individual repositories for details.
Jack-in-a-Box installer itself is MIT.
