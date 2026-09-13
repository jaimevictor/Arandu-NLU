# Local NLU for Home Assistant

A small, local, deterministic Brazilian Portuguese conversation agent for
Home Assistant.

The MLP understands exact commands to control lights, switches, and fan speed,
and to read device or sensor state. It supports both target chaining and
ordered action chaining:

```text
Apague a luz da sala e do quarto.
Apague a luz da sala e ligue a luz do quarto.
Coloque o ventilador do quarto em 50 por cento.
Qual é a temperatura da sala?
```

The add-on interprets. The companion integration resolves the complete plan
again and validates live state, services, exposure, and caller permissions
before it executes anything inside Home Assistant.

The engine abstains on unsupported, contradictory, or ambiguous input. It has
no cloud dependency, no Home Assistant credential in the add-on, no custom
cryptography, no persistent catalog, and no generic service passthrough.

See `docs/mlp/PRODUCT.md`, `docs/mlp/REQUIREMENTS.md`, and
`docs/mlp/INSTALL.md`.

Run the complete local gate with:

```sh
./tools/mlp-check
```

On Windows, run the same gate in the pinned Linux developer environment:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/mlp-dev.ps1 check
```

See `docs/mlp/BUILD-WINDOWS.md` for build, corpus regeneration, and image commands.

Project-authored code and documentation are Apache-2.0 licensed. Active
third-party dependencies and their purposes are listed in
`docs/mlp/DEPENDENCIES.md`.
