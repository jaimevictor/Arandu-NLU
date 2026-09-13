# P07 Pre-phase Requirements Analysis

- Role: `independent-requirements-analysis`
- Analysis instance: `88bdeb5d-046c-4ced-a306-3062b2d9a3c8`
- Input commit: `cd19bc128a52b235e30504c275aa35fd70696d25`
- Input tree: `c7bf603481967948fe0ca201596d68fb7241c5a1`
- Mode: read-only independent Git-object inspection
- Independence: no edits, network, sibling, internal, or Amazon sources
- Result: `ANALYSIS_COMPLETE_NO_BLOCKER`

## Mandatory Scope

P07 owns these exact requirements:

| ID | Minimum obligation |
| --- | --- |
| `P07-MOR-001` | Return every source-justified analysis, including all analyses of an ambiguous surface. |
| `P07-MOR-002` | Keep direct lexical evidence distinguishable from inference and preserve provenance. |
| `P07-MOR-003` | Return no invented lemma for an unknown surface. |
| `P07-MOR-004` | Return no invented morphological feature for an unknown surface. |
| `P07-MOR-005` | Bind evaluation to a versioned dataset and explicit frozen split. |
| `P07-MOR-006` | Reproduce declared metrics and a deterministically ordered confusion matrix. |
| `P07-MOR-007` | Keep evaluation data and oracle access outside production runtime behavior. |
| `P07-MOR-008` | Reproduce a versioned deterministic morphology error analysis. |

Applicable inherited rows include `GLB-LING-001..003`, `GLB-DATA-001`,
`GLB-EVAL-001..002`, `GLB-METRIC-001..005`, `ARC-LANG-001..002`,
`GLB-DET-001..003`, `GLB-SEM-001..007`, `GLB-SEC-009..011`,
`NFR-MEAS-017..019`, and the all-phase clean-room, build, dependency,
validation, review, and lifecycle contracts.

## Frozen Evidence

The only eligible language source is
`project-authored-synthetic-ptbr-v1` under `USR-016`:

- source manifest SHA-256
  `d9e1ca32ec0f92aa6b5fc6c1d4f232f93389e0bf8031267d23daddf7287006c5`;
- generator specification SHA-256
  `f72451f03d1a5e2e4955b5d2857bd7d33b3b012912d920e53a3d85719f14859d`;
- lexicon SHA-256
  `727e89195fc2ed16489c24b17841d58a2a9bb68c828769ece83ab70489316e4e`;
- morphology oracle SHA-256
  `ebee221611e4cbf6206a755022d163e4c96f7eb1a42626d7032773bfb8c793dc`;
- P06 package SHA-256
  `ec24f2335f64d694931450fb5ad6aefe3e924d1e29b23e046f128491dfe79e27`.

The frozen lexicon contains 33 analyses over 32 surfaces. Four analyses have
empty feature lists. The morphology artifact contains 29 expected analyses
over 28 surfaces and is exactly the feature-bearing lexicon subset. It has no
row-level split field, so P07 must freeze a sidecar evaluation manifest and
split without changing P02 bytes.

P05 UD material is ineligible for morphology training or evaluation. Rejected
P02 candidates and the corpus-free fallback remain exclusion evidence only.

Every P07 metric is internal source-replay conformance. It cannot establish
independent PT-BR morphology accuracy, representativeness, unseen-form
generalization, or Sophia equivalence.

## Minimum Acceptance

1. Freeze a P07 evaluation manifest binding all 29 case IDs, source/version,
   artifact hash, split ID, exact-surface grouping, metric algorithm,
   confusion labels, and error categories.
2. Production consumes only the P06 package and returns all 33 analyses over
   32 surfaces, including all empty-feature entries and both analyses of the
   repeated surface.
3. Output identifies lexical evidence explicitly. The current source portfolio
   justifies no productive inference.
4. Unknown input returns no lemma, category, or feature. Technical fixtures
   exercise structure only and never enter linguistic metrics.
5. The isolated runner unions expected analyses by exact surface and reports
   28/28 exact sets, 29 true analyses, zero missing or unexpected analyses,
   and 1/1 preserved ambiguous surfaces.
6. The confusion matrix has frozen `unknown`, `unique`, and `ambiguous`
   labels; the baseline is `[[0,0,0],[0,27,0],[0,0,1]]`.
7. Every metric records domain, dataset ID/version, split ID, claim scope, and
   limitations. Counts and fractions are integers.
8. Reports and error analysis are canonical and byte-stable. A zero-error
   baseline is accepted only after mutation tests reproduce nonzero errors.
9. Runtime code and release dependencies contain no morphology oracle path,
   case ID, expected label, evaluator, filesystem, network, time, locale,
   entropy, or mutable global input.
10. Existing P01-P06 gates, P07 gates, two-root replay, formatting,
    warnings-denied Clippy, tests, builds, distribution, and dependency checks
    pass one immutable candidate.

## Verification Matrix

| Gate | Required evidence |
| --- | --- |
| Source reconciliation | Strict join of all 29 expectations to P06 identities; four feature-empty entries reported as unscored. |
| Runtime completeness | Exact lookup, ambiguity, unknown, provenance kind, ordering, bounds, and no-partial-result tests. |
| Evaluation isolation | Cargo graph and source scans prove no production dependency on gold files or evaluator. |
| Reproduction | Two clean runner roots and input permutations emit identical report bytes. |
| Error behavior | Missing, extra, duplicate, and reordered admitted identities produce stable matrix/error records. |
| Common gates | Inherited validators and mutation suites plus P07 validator and test suite. |

## Bounded Convergence

One convergence pass is one selected and dispositioned integrated contract for
runtime evidence/inference separation, frozen evaluation split,
metric/confusion/error algorithms, isolation, and tests. P07 permits at most
three passes and three frozen candidate rounds. Candidate round 1 is the
complete implementation; rounds 2 and 3 are blocker-only. Freeze the first
minimum candidate immediately. Unused capacity is not refinement budget.

After three unsuccessful passes, or an open P0-P2 after round three, stop and
request explicit scope adjudication.

## Counterexample

`morphology.jsonl` has two singleton records for the repeated surface. A
per-record scorer either penalizes the correct two-analysis result as an extra
prediction or rewards winner selection. Gold must first be unioned by exact
surface and compared as one complete analysis set.

Primary evidence inspected: `AGENTS.md`, clean-room policy and decisions, P07
and inherited requirement rows, accepted ADRs, P02 source manifest,
specification, generator, morphology and lexicon artifacts, and the P06
runtime/package implementation and tests.
