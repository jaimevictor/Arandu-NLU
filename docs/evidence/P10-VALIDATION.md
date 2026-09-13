# P10 Home Assistant Catalog Validation Evidence

- Phase: `P10`
- Candidate: `b65e9bbbf0f0946f10ac8b0fc6a8239691d0047d`
- Candidate tree: `6a3256aedbe68d74410b5ccab89796ad0e2828a4`
- Convergence passes consumed: 1 of 3
- Candidate round: 1 of 3
- Validation date: `2026-08-29`
- Result: `PASS`

## Scope

P10 adds an authority-free `ha-catalog` crate for immutable,
generation-bound Home Assistant catalog snapshots, exact-evidence entity
resolution, conservative typed capability dispositions, and atomic snapshot
publication. It has no filesystem, network, persistence, policy, execution,
response-rendering, credential, clock, entropy, or Home Assistant authority.

Entity registry IDs remain distinct from mutable dotted entity IDs and map
injectively to core IDs as `ha_entity:id_<registry-id>`. Area and floor IDs
remain slug-derived registry strings; device and entity registry IDs remain
UUID-hex strings. The pinned device registry has no alias field. Explicit
conversation exposure remains authoritative for hidden entries, while
disabled or unexposed entries do not enter a snapshot.

`P10-HA-019..020` remain assigned to P14, `P10-HA-024` remains assigned to
P13, and `P10-HA-023` and `P10-HA-025` remain assigned to P15. P10 does not
claim live synchronization, persistence testing, actions, or release-level
intent coverage.

## Official Source

The official Home Assistant Core tag `2026.8.3` resolved directly to commit
`759e4658f40b3ccb671d418b8a0ed95224bf4561`. A temporary sparse checkout of
that tag reproduced every admitted path hash. The 14-path bundle is SHA-256
`4627587cd790e86e935c702e2f8e3c9dda48390ad639bb69cd7c7fba2fd0489e`.

The added registry-base, utility-wrapper, and `pyproject.toml` paths close the
source chain for slug-derived area/floor IDs and pin
`python-slugify==8.0.4`. No upstream source bytes or language data are copied
into the repository.

## Frozen Artifacts

- source evidence: 5,132 bytes, SHA-256
  `c434031775d365ce20c074c50e19f0dfe1980ae2696ab667bdf7d6718f758c17`;
- domain coverage: 15,885 bytes, SHA-256
  `042f3aa7afe27d9057f12107473e12a7819164b886d62e487eb9f00d58e9bf14`;
- coverage schema: 4,177 bytes, SHA-256
  `e3597603e65cb142345ea055550025ab4520392305dcefd24d5b8e158658c160`.

The coverage artifact contains all 45 pinned generated entity-platform
domains and all 20 built-in intent constants. Every domain supports catalog
presence and explicitly abstains from unreviewed state queries and actions.
Unknown domains remain catalogable but non-actionable.

## Verification

The candidate and closeout validation executed:

- `tools/validate-p10 --review-candidate`;
- `tools/test-validate-p10`;
- `tools/validate-p10`;
- locked Rust format, clippy with warnings denied, test, and all-target build;
- `git diff --check`;
- direct official-tag and admitted-path hash verification;
- inherited phase validators and mutation suites.

The Rust suite passed 27 tests. It covers stable identity, exact NFC matching,
non-equivalent case/accent/compatibility/confusable inputs, every typed
constraint and ranking factor, display-name abstention, alias clarification,
insertion permutations, dangling associations, exact one-over limits,
descriptor disable/narrow/extension, stale and concurrent publication,
retained snapshot coherence, source inventories, and privacy canaries.

The P10 validator mutation suite passed nine tests covering source and
artifact substitution, duplicate JSON/YAML keys, domain/intent/prerequisite
coverage mutations, runtime authority, and pending requirements. The first
P01 closeout invocation correctly rejected the two distribution-manifest
paths before this validation and phase report existed; its rerun after
closeout file creation passed.

## Completion

The first complete implementation met minimum acceptance in convergence pass
1 and was frozen as candidate round 1. The user directed the executor to skip
the post-candidate final review after successful mandatory validation. No
optional refinement or separate final phase review is claimed.
