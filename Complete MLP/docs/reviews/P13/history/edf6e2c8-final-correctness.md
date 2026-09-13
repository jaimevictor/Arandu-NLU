# P13 Historical Final Correctness Review

- Role: `correctness`
- Review instance: `historical-final-correctness-edf6e2c8`
- Review date: `2026-08-31`
- Subject commit: `edf6e2c888c841c423f42a19c110072f3b6f7ec7`
- Subject tree: `b71a4ba735aaaea6e12a349d0e55c8f9c8a3d652`
- Archive SHA-256:
  `1d0de0722ef7fb838c2c86029746e0027e7f5dc4a105be3558df30f266771afa`
- Mode: independent, read-only, offline historical final-correctness review
- Historical status: this report records the immutable subject above; it is
  not a review of the replacement worktree
- Verdict: `FAIL`

## Scope

This review inspected only blobs reachable from the subject commit and
reproduced the decision-row and post-P00 `BLOCKED` lifecycle findings. It did
not use the current worktree as evidence. Primary paths were:

- `AGENTS.md`
- `docs/adr/ADR-0006-baseline-and-review-evidence.md`
- `docs/adr/ADR-0034-bounded-source-review-closeout.md`
- `docs/clean-room/USER-DECISIONS.md`
- `docs/evidence/REQUIREMENTS-MANIFEST.yaml`
- `docs/evidence/REQUIREMENTS-TRACEABILITY.md`
- `docs/phases/AUTONOMOUS-QUEUE.yaml`
- `docs/phases/PROJECT-STATUS.md`
- `tools/validate-governance.rb`
- `tools/test-validate-governance.rb`
- `tools/p13-noise-evidence.rb`
- `tools/test-p13-noise-evidence.rb`

No network, Amazon or internal tool, sibling repository, closed-engine input,
or linguistic data was used. Counterexample strings were labeled
`FIXTURE_TECNICA`. Temporary files were created only by `Dir.mktmpdir` and
removed when each focused harness exited.

## Subject Identity

Commands:

```sh
git show -s \
  --format='commit=%H%ntree=%T%nparent=%P%nsubject=%s' \
  edf6e2c888c841c423f42a19c110072f3b6f7ec7
git archive --format=tar \
  edf6e2c888c841c423f42a19c110072f3b6f7ec7 |
  shasum -a 256
git diff --check \
  edf6e2c888c841c423f42a19c110072f3b6f7ec7^ \
  edf6e2c888c841c423f42a19c110072f3b6f7ec7
```

Results:

```text
commit=edf6e2c888c841c423f42a19c110072f3b6f7ec7
tree=b71a4ba735aaaea6e12a349d0e55c8f9c8a3d652
parent=240f64b26af530aadf5353ab973ceab99e265bc4
subject=p13: close bounded source review findings
archive_sha256=1d0de0722ef7fb838c2c86029746e0027e7f5dc4a105be3558df30f266771afa
git_diff_check=PASS
```

Each relevant frozen Ruby blob also passed:

```sh
git show edf6e2c888c841c423f42a19c110072f3b6f7ec7:tools/validate-governance.rb |
  ruby --disable-gems -c
git show edf6e2c888c841c423f42a19c110072f3b6f7ec7:tools/test-validate-governance.rb |
  ruby --disable-gems -c
git show edf6e2c888c841c423f42a19c110072f3b6f7ec7:tools/p13-noise-evidence.rb |
  ruby --disable-gems -c
git show edf6e2c888c841c423f42a19c110072f3b6f7ec7:tools/test-p13-noise-evidence.rb |
  ruby --disable-gems -c
```

Result: four `Syntax OK` responses.

## Decision-Row Counterexample

The frozen implementations use equivalent discovery predicates:

- `tools/validate-governance.rb:916-953`
- `tools/p13-noise-evidence.rb:1656-1695`

`markdown_table_columns` returns `nil` unless the first byte is `|` and the
last byte after `chomp` is `|`. The subsequent candidate prefilter requires
`USR-` or a word boundary after `USR`. Consequently, outer horizontal
whitespace hides an otherwise valid row, and `_` prevents `USR_038` from ever
reaching malformed-ID rejection.

A focused Ruby 2.6 harness loaded the four exact tool blobs through:

```sh
/Library/Developer/CommandLineTools/usr/bin/git archive --format=tar \
  edf6e2c888c841c423f42a19c110072f3b6f7ec7 \
  tools/p13-rustc-driver.rb tools/p13-source-fetch.rb \
  tools/p13-noise-evidence.rb tools/validate-governance.rb \
  docs/clean-room/USER-DECISIONS.md \
  docs/evidence/REQUIREMENTS-TRACEABILITY.md \
  docs/evidence/REQUIREMENTS-MANIFEST.yaml
```

For each row below, it appended the bytes to the exact decision ledger and
called:

```ruby
GovernanceValidator.allocate.send(:user_decision_ids_from_bytes, changed)
P13NoiseEvidence.user_requirement_ids(
  changed,
  expected_columns: 5,
  context: "probe"
)
P13NoiseEvidence.validate_user_decision_traceability_bytes(
  changed,
  frozen_traceability,
  frozen_manifest
)
```

It also called `GovernanceValidator#validate_requirements` with only the
decision-ledger read replaced by those changed bytes; every other read came
from `git show edf6e2c8:<path>`.

Inputs:

```text
  | `USR-038` | FIXTURE_TECNICA | MUST | P13 | FIXTURE_TECNICA |
| `USR-038` | FIXTURE_TECNICA | MUST | P13 | FIXTURE_TECNICA | <space><tab>
| `USR_038` | FIXTURE_TECNICA | MUST | P13 | FIXTURE_TECNICA |
```

Results:

```text
leading_space: governance_count=37 governance_last=USR-037 p13_count=37 p13_last=USR-037 complete_trace_accepted=true
trailing_space: governance_count=37 governance_last=USR-037 p13_count=37 p13_last=USR-037 complete_trace_accepted=true
malformed_underscore: governance_count=37 governance_last=USR-037 p13_count=37 p13_last=USR-037 complete_trace_accepted=true
leading_space: governance_validate_requirements=accepted
trailing_space: governance_validate_requirements=accepted
malformed_underscore: governance_validate_requirements=accepted
```

Thus both mandatory paths silently treated each appended candidate as prose.
The P13 completeness relation still returned `true` against the unchanged
37-row traceability and manifest, and governance requirement validation also
accepted it.

The subject's positive tests at
`tools/test-p13-noise-evidence.rb:2396-2483` cover whitespace inside a parsed
cell and malformed forms such as `USR-038X`; they do not cover whitespace
outside the table delimiters or an underscore after `USR`.

Counterexample controls were attempted. A canonical `USR-038` row was
discovered by both parsers, while the already-covered `USR-038X` form failed:

```text
control_valid: governance_last=USR-038 p13_last=USR-038
control_malformed_governance=GovernanceError:malformed user decision row
control_malformed_p13=P13NoiseEvidence::Failure:probe contains malformed ID row
```

This contradicts the fail-closed malformed-input rule and the explicit
ADR-0034 requirement at lines 38-41 to discover whitespace-tolerant rows and
reject malformed candidate IDs.

## Lifecycle Counterexample

The frozen `GovernanceValidator#validate_state` at
`tools/validate-governance.rb:1807-1913` permits `BLOCKED` generally, but calls
`validate_p00_lifecycle_state` only when `current_phase == "P00"`. The
coherence checks at lines 1915-1946 therefore do not apply to P01 through P16.

The focused harness loaded `tools/validate-governance.rb` from the subject,
parsed the exact subject status and queue with `Psych.safe_load`, and changed
only these in-memory fields:

```yaml
state: BLOCKED
open_findings: []
next_action: continue_FIXTURE_TECNICA_without_scope_decision
waiting_internal_dependencies: []
```

It then called:

```ruby
validator.send(:validate_state)
```

Every file read by that method came from
`git show edf6e2c888c841c423f42a19c110072f3b6f7ec7:<path>`.

Result:

```text
post_p00_blocked: accepted=true phase=P13 findings=0 next_action=continue_FIXTURE_TECNICA_without_scope_decision waiting=[]
```

The accepted state says P13 is blocked while retaining no blocker, continuing
without scope adjudication, and waiting on no explicit user decision. This is
incoherent with `AGENTS.md:158-160`, `USR-014`, and
`docs/adr/ADR-0006-baseline-and-review-evidence.md:108-111`.

As counterexample controls, the same frozen implementation rejected each
equivalent P00 defect:

```text
control_p00_empty_findings=GovernanceError:blocked P00 must retain at least one open finding
control_p00_wrong_action=GovernanceError:blocked P00 next_action must request explicit user scope adjudication
control_p00_missing_dependency=GovernanceError:blocked P00 must wait only on an explicit user scope decision
```

The tests at `tools/test-validate-governance.rb:3435-3495` exercise those P00
checks only. No post-P00 `BLOCKED` lifecycle regression exists in the subject.
The actual subject remains in P13 `IMPLEMENTATION`; this finding concerns the
mandatory validator's ability to accept a future contradictory transition,
not a claim that the subject already records that transition.

## Findings

P0: none.

P1: none.

P2:

- `P13-COR-EDF6-001`: outer horizontal whitespace and malformed identifiers
  such as `USR_038` evade both decision-row parsers, allowing an additional
  persistent user-decision candidate to be omitted from traceability while
  both completeness checks accept.
- `P13-COR-EDF6-002`: post-P00 `BLOCKED` state has no enforced lifecycle
  coherence; P13 can be marked blocked with no retained finding, no explicit
  scope-decision dependency, and a continue action.

P3: none.

Both P2 findings remain open on the frozen subject. ADR-0034 requires no open
P0 through P2 finding and unanimous mandatory review passage on one immutable
baseline, so this subject cannot checkpoint P13.

FAIL
