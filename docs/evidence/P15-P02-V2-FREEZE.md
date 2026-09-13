# P15 Replacement P02-v2 Evaluation Freeze

- Phase: `P15`
- Authorization: `USR-045`
- Governing decision: `ADR-0047`
- Chronology predecessor:
  `c93f0dc67103cb50383c03225463c8c32b07577a`
- Chronology predecessor tree:
  `54d27771c1300ba6a245ff96156c60b569d1d4c2`
- Freeze checkpoint: `SELF_AT_P15_PRE_IMPLEMENTATION_COMMIT`
- Corpus: `project-authored-synthetic-ptbr-p15-v2`
- Corpus version: `2.0.0`
- Generator: `p02-qualification-generator-v2`
- License: `Apache-2.0`
- Claim class: internal conformance only
- Result: `PASS`

## Chronology And Access

The specification, generator, expected typed semantics, split assignment,
families, and case identities were created after the explicit `USR-045`
authorization and before any remediation implementation. The predecessor
commit above contains no P02-v2 bytes. This freeze commit changes no
production, linguistic-runtime, policy, protocol, adapter, or companion
behavior.

Before this checkpoint, the executor inspected specification structure,
metadata, placeholder names, family identifiers, template counts, and
aggregate generalization properties. It did not display or inspect a new
held-out or performance utterance. The generator and validator mechanically
read all split bytes inside the pre-freeze generation boundary. No NLU engine
ran on the held-out or performance splits, and no case-level NLU output,
failure identity, or score exists.

The initial delegated writer produced only the specification and launchers
and was stopped without generating a corpus. During local implementation, one
validator invocation stopped before validation because of an internal method
dispatch error, and a later invocation detected a byte-string encoding
comparison defect before record validation. The generator source was then
corrected, all artifacts were regenerated, and the complete valid gate below
passed. These tooling failures did not disclose release-split content or
produce an NLU result.

After this checkpoint:

- `heldout.jsonl` and `performance.jsonl` are sealed;
- only the aggregate-only P15 release evaluator may read their record bytes;
- remediation may use only P02-v2 train and development, public contracts,
  admitted non-held-out evidence, and `FIXTURE_TECNICA`;
- old P02-v1 held-out and performance data remain permanently ineligible for
  the replacement release claim; and
- any post-freeze semantic inspection or case-level diagnostic invalidates
  the lineage.

## Frozen Inputs

| Input | Bytes | SHA-256 |
| --- | ---: | --- |
| `specification.json` | 40,511 | `3af92370fa0654c00f8a109c62ee15c97b9ff0eec86483de261216cb3905e7eb` |
| `manifest.json` | 13,989 | `f0b4a28b15496f65a71207e4129abc64bac25a2e45770157afd8f2f7866a20ae` |
| Generator launcher | 209 | `b8e757ae00151c7abcdf7eeafa5c3f8c422d92b514a270e448f9fc668e46e776` |
| Generator source | 30,141 | `fe7a5d6ed3ee1630d43998d9e37d987feb27289003da65e7fec984f41982da1e` |
| Validator launcher | 206 | `525a717f44f3f7c348cd31a3f1b4fe9bc84a41f7db3df840781616d35d3fd3e0` |
| Validator source | 17,240 | `007f0a98ca607c16b9a5ba796c4a49b23545b3ae0ac036346719a8f4a6e9f591` |
| Self-test launcher | 197 | `ad3a9d9d56b9a379363047b16a87e22bad9aa8b8ed96c866c33980e7f0529b45` |
| Self-test source | 4,074 | `83f0874c8376bd79f480f9fbfef9c16c584c930013f43a8419d35e7524e205da` |

## Frozen Artifact Inventory

| Artifact | Records | Bytes | SHA-256 |
| --- | ---: | ---: | --- |
| `train.jsonl` | 960 | 1,345,952 | `f15226a107c7bedb27b28e5880b65f24fb832a4b3d62ba67c6569a99b2aad183` |
| `development.jsonl` | 960 | 1,377,284 | `08d8b1d33bf551337a90bde94727964fbf8f7de54de32e646d1758ce58ab89f1` |
| `heldout.jsonl` | 4,800 | 6,752,632 | `9767b413bf1eff0e2e1ec97f94c39f9d89c8e65743d2f53d502c56dd60f9276d` |
| `performance.jsonl` | 4,800 | 6,863,752 | `2baef9e3a906848c32ae5a0586d7c09c62d5380b891972edb46797cd054e269f` |
| `suites/ambiguity.jsonl` | 5 | 3,996 | `4ac86651828f2a6b065eb6b65295031544b3da83a21abaa11a94142cbf9df13f` |
| `suites/contradiction.jsonl` | 5 | 4,092 | `bd2e8b0d3a0bb924fa8f862284131237e5b5848e171817d4681a8f28752ff645` |
| `suites/explicit-negative.jsonl` | 7 | 5,829 | `ed0b7ce78961ee34a6b9fe2597fcdd8e58e3a0638ce2ef5e25c0311779875ab8` |
| `suites/safety-sensitive.jsonl` | 5 | 4,156 | `5685f966384fd46451a2463e985f266d7abcf5b06a5608cbd7dc85f1a3340d28` |
| `suites/stale-state.jsonl` | 5 | 4,080 | `c93a360293907f96fb1e4522a7d558ea2cb5ca59abee7c8b989131550e179bbe` |

Each semantic split contains all 20 pinned Home Assistant intent families.
Train and development contain 48 records per intent; held-out and performance
contain 240 per intent. The five independent fail-closed suites contain
5, 5, 5, 5, and 7 records respectively.

## Executed Gate

The following commands completed successfully before the freeze:

```text
ruby -c tools/generate-p02-v2-corpus.rb
ruby -c tools/validate-p02-v2.rb
ruby -c tools/test-validate-p02-v2.rb
ruby -c tools/generate-p02-v2-corpus
ruby -c tools/validate-p02-v2
ruby -c tools/test-validate-p02-v2
tools/generate-p02-v2-corpus
tools/validate-p02-v2
tools/generate-p02-v2-corpus --check
tools/test-validate-p02-v2
```

The terminal sentinels were:

```text
P02_V2_CORPUS_GENERATED 10
P02_V2_VALIDATION_PASS
P02_V2_CORPUS_GENERATION_CHECK_PASS
P02_V2_VALIDATION_TESTS_PASS
```

The validator binds the specification and generator hashes, exact artifact
path set, byte sizes, record counts, whole-file hashes, source metadata,
typed expected plans, deterministic ordering, minimum quotas, and pairwise
separation of case IDs, generator record IDs, canonical semantic identities,
families, utterances, and semantic payloads. It also verifies that hidden
template static tokens are supported by train-observed function words and
declared inflectional paradigms, without comparing against the prior release
splits.

The ten self-tests use only `FIXTURE_TECNICA`. They cover strict JSON,
duplicate keys, invalid UTF-8, JSONL limits, partition collision, symlink
rejection, deterministic canonical hashing, placeholder exclusion, template
rendering, and release-split-loader source scanning.

## Next Boundary

The first behavior-affecting remediation commit must descend from this
checkpoint. It must bind its evaluator to the exact P02-v2 identities above
and may not expose held-out or performance records outside the sealed
aggregate-only runner.
