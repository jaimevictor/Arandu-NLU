# P15 Final-Evaluation Access Chronology

- Phase: `P15`
- Date: 2026-09-10
- Pre-implementation commit: `a055a847d22575fba8350d9e05fd8aff3797ece9`
- Pre-implementation tree: `24ac05687083a8fe8adb11e960a9e91bda158053`
- Corpus class: `PROJECT_AUTHORED_SYNTHETIC`
- Claim class: internal conformance only

## Recorded Access

Before P15 implementation began, feasibility inspection displayed the first
eight records of each frozen P02 `heldout` and `performance` file to the
executor. No engine output, failure identity, per-case score, or targeted
diagnostic was produced. The access occurred after the NLU implementation and
all linguistic inputs had already been written.

The executor did not change, and P15 must not change, any interpretation,
linguistic-data, semantic-plan, catalog-resolution, policy, session, or
protocol behavior in response to those records. P15 implementation is limited
to sealed evaluation, deterministic packaging, validation, evidence, and
phase-state code. This chronology is not an assertion of independent
evaluation: the corpus remains project-authored internal conformance data
under `USR-016`.

## Freeze Guard

The final P15 validator must prove byte identity from the pre-implementation
tree through the evaluated release candidate for every behavior-affecting
path, including:

- frozen P02 specification, manifests, projections, corpora, and suites;
- language, morphology, intent, plan, catalog, policy, session, protocol,
  server, adapter, and companion production code;
- model and compiled runtime data; and
- all thresholds, weights, aliases, lexicons, grammars, and rules.

Any change to one of those paths invalidates the current held-out result. It
must not be repaired by inspecting case-level outcomes or tuning against the
same corpus.

## Sealed Execution

After this record:

- only the P15 sealed runner may read held-out or performance record bytes;
- the runner may emit whole-run identities, canonical aggregates, raw timing
  samples, stable error codes, and whole-run digests only;
- utterances, case identifiers, semantic identifiers, expected values,
  mismatches, and per-case diagnostics are prohibited from output, errors,
  logs, tests, and evidence;
- tests may use only `FIXTURE_TECNICA` mechanical records; and
- a failed aggregate is a failed gate, not permission to inspect cases or tune
  the product.

ASR-noise accuracy has no eligible frozen stratum and must be reported as
`INSUFFICIENTLY_EVALUATED` with denominator zero and no support claim.

## Disposition

The recorded access does not by itself establish tuning leakage because no
behavior-affecting byte may change after it. The byte-identity guard and
aggregate-only runner are mandatory acceptance conditions. If either
condition fails, `P15-EVAL-012` fails closed.
