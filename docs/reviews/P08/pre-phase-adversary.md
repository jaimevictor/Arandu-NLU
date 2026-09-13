# P08 Pre-phase Adversarial Analysis

- Role: `independent-adversarial-analysis`
- Analysis instance: `01a04b1c-336e-7b43-b4ca-d13773f5dc18`
- Input commit: `07317996f0c3e01eccc39f0b7ac607e284169c28`
- Input tree: `1e8c9638eb2a8b8b4a2dd85453063f9f870d2364`
- Mode: read-only independent primary-evidence inspection
- Independence: no edits, network, siblings, internal/Amazon, or closed engine
- Result: `ANALYSIS_COMPLETE`

## Baseline Facts

- The frozen POS artifact has 241 sentences split 80/80/81, 25 documents,
  four split-specific families, one source origin, 1,763 tokens, four
  expected-unknown tokens, and one ambiguity-marked heldout sentence.
- Only four tag-sequence patterns exist. The corpus is templatic same-source
  internal conformance, not independent evidence of Portuguese accuracy.
- P06/P07 exact lexical lookup covers much of heldout because labels and the
  runtime lexicon share the pre-engine P02 generator.
- P07 preserves a noun/verb conflict and has no package-order ranking.
- The P07 evaluator is a leaf; P08 must preserve that dependency direction.

## Threat Hypotheses

| Severity | ID | Hypothesis and required control |
| --- | --- | --- |
| P0 | `P08-A01` | Heldout labels, predictions, or project output train, select, repair, or validate the model. Freeze algorithm, configuration, seed, model, and scorer first; give the trainer only a physical train slice. |
| P0 | `P08-A02` | Exact sentence, hash, position, case, family, or document lookup is presented as contextual modeling. Forbid all such fields from model records and scan the package and production graph. |
| P1 | `P08-A03` | Mechanical split IDs conceal duplicate text or document leakage. Audit sentence bytes/hashes and document identities independently; do not use split-prefixed family names as proof. |
| P1 | `P08-A04` | One synthetic source is mislabeled origin-disjoint evaluation. Report the one origin and prohibit independent-origin or generalization claims. |
| P1 | `P08-A05` | Candidate order or an undocumented tie-break collapses P07 ambiguity. Unsupported or contradictory context must retain the complete canonical set. |
| P1 | `P08-A06` | Unknown context invents a tag or memorizes the four X rows. Unknown remains payload-free, acts as a barrier, and is evaluated separately. |
| P1 | `P08-A07` | Seed, configuration, row order, locale, threading, or floating point changes model bytes. Pin inputs and use sorted presence records and integer-only logic. |
| P1 | `P08-A08` | Token, sentence, document, origin, unknown, and ambiguity denominators are mixed or omitted. Freeze each unit and require independent reconciliation for baseline and selected output. |
| P1 | `P08-A09` | Evaluation paths or filesystem APIs become runtime reachable. Enforce a leaf evaluator and production dependency/source/archive scans. |
| P2 | `P08-A10` | Malformed or oversized JSONL/model input panics, truncates, or emits partial results. Use strict schemas, duplicate rejection, checked spans/arithmetic, exact limits, and whole-run invalidation. |
| P3 | `P08-A11` | Tiny templatic same-source data overstates practical usefulness. Admit only as an explicit internal-conformance limitation. |

## Concrete Counterexample

A table keyed by token count and position can memorize the three ordinary
templates and one special sentence. It could score perfectly while doing no
contextual inference. The model format therefore contains only POS transition
support and cannot encode text, positions, sentence lengths, or record
identities.

Direct lexical lookup also obtains many heldout labels because P06 and the POS
oracle share one generator. Reported results cannot establish unseen-language
or independent PT-BR accuracy.

## Required Mutations

1. Change a label, source, split, document, family, specification, generator,
   or case inventory and recompute outer hashes; require rejection.
2. Inject a heldout row into train or cross a sentence/document boundary;
   require rejection.
3. Insert heldout text/hash/ID or an evaluator dependency into the model or
   production graph; require rejection.
4. Delete, reorder, rank, or force-select ambiguous candidates; require the
   complete ambiguity or failure.
5. Make an unknown input emit any POS payload; require unknown.
6. Change seed/configuration or input order; rebuild under another root and
   require exact model and report bytes.
7. Mutate denominators, metric attribution, labels, counts, omitted sentences,
   or baseline/selected comparison; require reconciliation failure.
8. Exercise malformed UTF-8/JSON, duplicate keys, bad spans, traversal,
   symlinks, truncation, trailing bytes, and exact one-over limits.

## Fail-closed Contract

- Baseline and selected candidates are both constrained to admitted P07
  analyses plus the admitted numeric mapping.
- Context removes a candidate only under the frozen train transition rule.
- Context never supplies a candidate to unknown input.
- Selected results never cascade within a sentence.
- Any integrity, split, schema, provenance, limit, or reconciliation failure
  invalidates the whole run and emits no report.
- Heldout mismatches produce aggregate reproducible evidence but never trigger
  another refinement pass.

## Residual Risk

The one-origin, four-pattern corpus is an admissible P3 only while every result
is labeled same-source internal conformance and no generalization claim is
made. A P3 is otherwise admissible only if it cannot affect a requirement,
correctness, security, operation, licensing, provenance, determinism, or
clean-room integrity.

## Bounded Stop

One convergence pass is one selected tuple of split/access chronology,
baseline, model/configuration/artifact, runtime/evaluator boundary, metrics,
and mutation portfolio. At most three passes and three candidate rounds are
allowed. The first acceptable baseline is frozen immediately; rounds 2 and 3
are blocker-only.

If origin-disjoint evaluation were required instead of origin-level reporting,
the current corpus could not satisfy it. No such requirement exists. After
three unsuccessful passes, or with any remaining P0-P2, stop for explicit
scope adjudication rather than fabricating origins or weakening provenance.

Primary evidence inspected: P08 and inherited requirements, `AGENTS.md`,
clean-room policy, P02 admitted source manifest/specification/generator/POS
artifact, P06/P07 package and runtime code, and evaluation boundaries.
