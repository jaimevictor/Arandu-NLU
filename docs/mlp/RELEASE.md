# MLP release

## Release subject

- Version: `0.1.0`
- Commit: `86e19910481c4d0b3b008002728938b3ad3a9fd3`
- Tree: `624dd3cc70d13280deb37ab189bd9923e6104632`
- Date: 2026-09-12

## Delivered behavior

- lights, switches, and fans can be turned on or off;
- fan percentage can be set from 0 through 100;
- light, switch, fan, sensor, and binary-sensor state can be read;
- coordinated targets such as `apaga a luz da sala e do quarto` are
  supported; and
- ordered mixed actions such as `apague X e ligue Y` are preserved and
  executed in order after complete-plan preflight.

Matching is deterministic and exact after case, punctuation, and diacritic
normalization. Unsupported, ambiguous, contradictory, stale, unauthorized,
or oversized requests fail closed.

## Validation

The exact subject passed `./tools/mlp-check`:

- 21 Python integration/protocol tests;
- 13 Rust unit, corpus, protocol, and HTTP tests;
- frozen-corpus reproducibility and conformance;
- formatting and clippy with warnings denied;
- exact vendored-source and package checks;
- offline release build; and
- black-box release-binary health and mixed-action smoke tests.

Two independent read-only reviews of the same subject passed:

- `docs/reviews/MLP/correctness.md`
- `docs/reviews/MLP/security-package.md`

An exact Git archive of the add-on directory also built successfully offline
as a standalone Cargo package.

## Installation and limitation

Follow `docs/mlp/INSTALL.md`. This host does not have Docker, Podman, or
Buildah, so the final OCI image was not executed locally. Its immutable build
inputs, scratch runtime, non-root user, license payload, and package structure
were statically validated.
