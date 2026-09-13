# Arandu NLU

**Sua língua. Sua casa. Seu controle.**

Local, deterministic Brazilian Portuguese conversation agent for Home Assistant.

## Overview

Arandu is a small, privacy-focused NLU engine that understands exact Portuguese commands to control your smart home. It runs entirely locally—no cloud, no credentials in the add-on, no data collection.

The engine supports:

```text
Apague a luz da sala e do quarto.
Apague a luz da sala e ligue a luz do quarto.
Coloque o ventilador do quarto em 50 por cento.
Qual é a temperatura da sala?
```

## Architecture

**Two-part design:**

1. **Add-on** (Rust) - Passive interpreter. Receives utterance + catalog snapshot, returns typed plan or abstention. Never executes anything.
2. **Integration** (Python) - Execution boundary. Builds catalog, revalidates plan against live Home Assistant state/permissions, executes authorized operations.

The add-on never receives Home Assistant credentials. The integration is the sole execution boundary.

## Supported Commands

| Dimension | Support |
|-----------|---------|
| Language | Brazilian Portuguese |
| Effect domains | `light`, `switch`, `fan` |
| Read domains | effect domains + `sensor`, `binary_sensor` |
| Actions | `turn_on`, `turn_off`, `set_fan_percentage`, `get_state` |
| Plan size | Up to 4 ordered operations |
| Targets | Up to 4 exact entity or area clauses per operation |
| Chaining | Coordinated targets (`da sala e do quarto`) and mixed actions |
| Matching | Case/diacritic-insensitive exact aliases |

## Explicit Non-Goals

No mixed query/effect chains, contradictory target reuse, timers, follow-ups, sessions, toggle, fuzzy matching, whole-home broadcast, arbitrary service calls, cloud dependency, speech recognition, climate, covers, media, locks, scenes, or automation creation.

## Installation

See [`docs/mlp/INSTALL.md`](docs/mlp/INSTALL.md) for setup instructions.

## Development

**Prerequisites:**
- Rust 1.98+
- Python 3.11+
- Ruby (for corpus generation)

**Run full validation:**

```bash
./tools/mlp-check
```

**Windows developers:** Use pinned Linux environment:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/mlp-dev.ps1 check
```

See [`docs/mlp/BUILD-WINDOWS.md`](docs/mlp/BUILD-WINDOWS.md) for build, corpus, and container commands.

## Documentation

- [Product Overview](docs/mlp/PRODUCT.md)
- [Requirements](docs/mlp/REQUIREMENTS.md)
- [Dependencies](docs/mlp/DEPENDENCIES.md)
- [Architecture Decision Records](docs/adr/)

## License

Apache-2.0. See [LICENSE](LICENSE) and [`docs/mlp/DEPENDENCIES.md`](docs/mlp/DEPENDENCIES.md) for third-party licenses.

## Project Name

**Arandu** /a.ɾɐ̃.ˈdu/ - From Tupi-Guarani: "wisdom, knowledge, understanding"

A fitting name for a local NLU that understands your language and respects your privacy.
