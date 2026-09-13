# PROJECT_AUTHORED_SYNTHETIC MLP corpus specification v1

- License: Apache-2.0
- Frozen: 2026-09-12, before the active MLP engine exists
- Purpose: internal deterministic conformance only
- Generator: `tools/generate-mlp-corpus.rb`
- Outputs:
  - `data/mlp/project-authored-synthetic-catalog-v1.json`
  - `data/mlp/project-authored-synthetic-v1.jsonl`

The generator emits fixed template families over fixed entity, area, action,
percentage, chaining, and expected-semantic parameters. It includes positive
single-target, homogeneous-chain, coordinated-ellipsis, fan-percentage,
read-only sensor, ambiguity, invalid-percentage, mixed-action, and unsupported
families.

Ordering is the declaration order in the generator. JSON keys are sorted and
each record is one UTF-8 line.

The corpus is not external linguistic evidence, does not measure independent
accuracy, and may not be relabeled from implementation output.
