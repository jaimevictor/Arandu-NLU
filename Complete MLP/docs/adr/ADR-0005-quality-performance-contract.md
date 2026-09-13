# ADR-0005: Quality and performance contract

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-24
- Owners: P00, P02, P09-P16

## Context

The user requires speed and accuracy comparable to Sophia NLU. Public Sophia
materials report 98.4% on an English Home Assistant suite and approximately
20,000 words/s for a separate parser claim. The workloads, languages, hardware,
oracles, and timing boundaries are not equivalent or fully documented.

## Decision

Adopt the numerical targets as internal conformance targets without claiming
independent accuracy or direct product equivalence:

- a two-sided 95% Wilson lower confidence bound of at least 98.4% for exact
  semantic success on a frozen Apache-2.0 project-authored PT-BR Home Assistant
  conformance evaluation containing at least 3,715 scored cases;
- zero false plans on safety-sensitive, contradiction, ambiguity, stale-state,
  and explicit negative suites;
- a median of at least 20,000 words/s across five measured runs of the complete
  single-thread in-memory core pipeline on documented reference hardware;
- a median of at least 400 utterances/s across five measured runs of the warm
  end-to-end NLU path with an in-process deterministic Home Assistant mock.

The held-out set is isolated before implementation tuning, split by corpus
version and utterance family, and contains no Sophia-derived language. Under
`USR-016`, it consists of `PROJECT_AUTHORED_SYNTHETIC` cases generated under a
versioned pre-engine specification. P02 freezes a scored-case identity and
coverage manifest before implementation sees results. Two cases cannot share
either the same generator record identity or the same canonical semantic case
identity. The manifest records corpus source, generator lineage, utterance
family, intent, Home Assistant domain, slot kinds, target cardinality, graph
shape, expected outcome, ambiguity class, and noise stratum. It must cover
every declared supported intent and domain plus every typed slot, entity,
clarification, abstention, negative, and graph class used by the release.
Quotas and weighting are frozen with the split and cannot be changed in
response to model results.

Every expected outcome records the generator specification and review lineage
that established it before NLU implementation. Output from this project's NLU
cannot establish, correct, select, filter, or validate a label. A case whose
expected result depends on project output is rejected from train, development,
held-out, performance, and zero-false-plan suites. These cases measure
conformance to the frozen project specification, not independent linguistic
accuracy or representativeness.

Abstention on supported in-domain input counts as an exact-semantic failure.
Results report sample count, the two-sided 95% Wilson interval, point estimate,
unweighted macro results, and results per frozen source, family, intent,
domain, slot, graph, outcome, ambiguity, and noise stratum. P02 must define a
valid dataset and freeze at least 3,715 distinct scored held-out cases before
implementation tuning. No alternate sample-size justification can lower that
minimum, and no duplicate can increase the scored count.

The global Wilson gate is necessary but not sufficient. Every declared
supported source, utterance family, intent, Home Assistant domain, slot kind,
graph shape, outcome, ambiguity class, and noise stratum must contain at least
237 distinct scored cases and must independently reach a two-sided 95% Wilson
lower confidence bound of at least 98.4%. The 237-case floor is the minimum
that can attain that lower bound even with zero failures. The unweighted macro
result for each frozen dimension must also reach at least 98.4%. A stratum
lacking pre-implementation frozen quota and coverage evidence is reported as
insufficiently evaluated and cannot be declared supported. Zero false-plan
gates remain separate and cannot be averaged away.

P02 also freezes separate safety-sensitive, contradiction, ambiguity,
stale-state, and explicit-negative suite manifests before implementation
tuning. Every manifest records immutable suite and case IDs, generator record
identity, canonical semantic case identity, expected non-plan outcome, frozen
coverage class, provenance, and license. The five suite taxonomies are derived
respectively from the release risk/confirmation model, graph-contradiction
model, supported ambiguity model, stale-state acceptance boundaries, and
unsupported/out-of-domain/denied semantic families. Their completeness is
reviewed against the typed outcomes, supported capability set, and threat model
before freeze.

No suite or frozen coverage class may be empty. Each class needs at least one
distinct provenance-bound Apache-2.0 case; one canonical semantic identity
cannot satisfy two classes in the same suite. P15/P16 report exact suite and
per-class cardinalities, coverage, and false-plan counts. Changing an identity,
oracle, taxonomy, or quota after tuning invalidates the affected suite and
results and requires a new reviewed freeze. A runner result without the
matching frozen nonempty manifest cannot satisfy a zero-false-plan gate.

Performance uses a separate frozen representative corpus derived from the
held-out coverage manifest without exposing held-out text to implementation.
Every corpus item has an expected exact semantic outcome and the untimed
preflight must pass before a run is eligible. The timed runner counts words or
utterances only for outcomes that match that oracle; fast abstention, error, or
partial output cannot contribute unless that exact outcome is the frozen
expected result. A run may repeat the complete corpus in canonical cycles to
reach one second, but cannot repeat one easy item or omit a stratum.

P02 freezes performance strata on the same nine mandatory dimensions as the
accuracy manifest: source, family, intent, domain, slot, graph, outcome,
ambiguity, and noise. Every performance stratum contains at least 237 distinct
items with frozen exact-semantic outcomes. Items may belong to one stratum in
each dimension, but duplicates cannot satisfy a quota. The complete corpus and
every stratum pass the untimed semantic preflight.

Both throughput thresholds apply to the complete corpus and independently to
every frozen performance stratum in every mandatory dimension: each core
stratum must have a five-run median of at least 20,000 words/s, and each warm
end-to-end stratum must have a five-run median of at least 400 utterances/s. A
fast stratum cannot compensate for a slow one. P02 freezes all strata, item
identities, and quotas before implementation tuning.

Reports include CPU model, architecture, core allocation, OS, compiler, build
profile, package/data version, corpus identity, three warmup runs, five
measured runs, p50/p95/p99, throughput, peak RSS, startup, and artifact size.
Core timing excludes startup, configuration loading, I/O, and the Home
Assistant adapter. End-to-end timing states every included boundary. Word
counting follows a versioned independent Unicode word-boundary implementation
and is fixed before measurement.

The public 98.4% accuracy, 24 MB binary, 160 MB RAM, and 106,322-word
vocabulary claims are tracked as non-gating context until an eligible,
independently labeled, reproducible like-for-like workload exists. The
project-authored conformance gate cannot satisfy that independent comparison.

## Alternatives

1. Reuse Sophia's English suite as the release oracle. Rejected because it is
   English, author-controlled, permissively scored in places, and has defective
   license metadata.
2. Treat 20,000 words/s and 10.1 seconds as one benchmark. Rejected because the
   observed Home Assistant run is about 3,200 words/s and the vendor describes
   a separate core-parser claim.
3. Optimize only average latency. Rejected because tails, startup, memory, and
   false plans matter operationally.

## Consequences

- A high abstention rate cannot hide poor semantic coverage.
- Duplicate or majority-class cases cannot inflate the release sample count or
  hide a failing supported stratum.
- A trivial repeated input or fast failure cannot satisfy a throughput gate.
- Aggregate throughput cannot hide a failing performance stratum.
- A fast core cannot hide slow integration behavior.
- Conformance work cannot inspect the held-out set after freeze except through
  aggregate release-gate results and controlled error-analysis protocol.

## Rollback

Thresholds may only become stricter. A dataset or oracle defect invalidates
affected results and requires a new reviewed, frozen evaluation version.
