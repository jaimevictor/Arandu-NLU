# Arandu NLU

**Sua língua. Sua casa. Seu controle.**

**Versão 0.3.0 — motor NLU 2.0 contextual:** [arquitetura](docs/nlu-2.0/ARCHITECTURE.md), [contratos HA](docs/nlu-2.0/API-CONTRACTS.md), [implantação e rollback](docs/nlu-2.0/DEPLOYMENT.md), [validação e cobertura](docs/nlu-2.0/REPORT.md).

Local, deterministic Brazilian Portuguese conversation agent for Home Assistant.

## Overview

Arandu is a local, deterministic Portuguese NLU engine with semantic device aliases, spatial context, bounded conversation sessions, typed control and sensor queries. The Rust add-on never receives Home Assistant credentials; the Python integration is the sole authorized executor.

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
| Control | Lights, fans, climate, covers, media, helpers and capability-specific HA adapters |
| Queries | Current states, environmental measurements, presence/location, aggregates, calendar/weather/todo |
| Conditional features | Music Assistant, configured remote commands, exposed script/button bindings, indoor person trackers |
| Plan size | Up to 4 ordered operations |
| Targets | Up to 32 authorized resolved entities per contextual operation |
| Context | Origin area, explicit area precedence, recent targets, clarification and expiring confirmation |
| Matching | Deterministic names/aliases, semantic domain/class/capability evidence; ties ask for clarification |
| Compatibility | v1/v2/v3 preserved; contextual v4 enabled by default, configurable rollback |

## Limits

No arbitrary service calls, generative model, fuzzy authorization, inferred indoor identity, fabricated readings or assumed atomic HA transactions. Unsupported conditions/exceptions abstain. Sensitive access/protection operations need policy and confirmation; entity PIN requirements remain enforced. Backends and authenticated `context.user_id` are required. Real residential HA and ARM64 have not been tested here; coverage uses the real executor with simulated HA. See the report for exact counts and remaining interpretation failures.

## Installation

See [installation and rollback](docs/nlu-2.0/DEPLOYMENT.md) for the local source package, integration, Assist agent and optional adapters.

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

See [deployment/build instructions](docs/nlu-2.0/DEPLOYMENT.md) and [pinned developer dependencies](tools/dev/DEPENDENCIES.md).

## Documentation

- [Architecture](docs/nlu-2.0/ARCHITECTURE.md)
- [Measured coverage and limitations](docs/nlu-2.0/REPORT.md)
- [Release reviews](docs/nlu-2.0/REVIEWS.md)
- [Contextual scope decision](docs/adr/0056-contextual-nlu-2.md)

## License

Apache-2.0. See [LICENSE](LICENSE), [third-party notices](addon/THIRD_PARTY_NOTICES.md) and [STT provenance](data/contextual/provenance.json).

## Project Name

**Arandu** /a.ɾɐ̃.ˈdu/ - From Tupi-Guarani: "wisdom, knowledge, understanding"

A fitting name for a local NLU that understands your language and respects your privacy.
