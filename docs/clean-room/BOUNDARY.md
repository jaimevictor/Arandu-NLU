# Clean-room Boundary

## Allowed inputs

- the user-provided steering document as a requirements source;
- the explicit user decisions recorded in `USER-DECISIONS.md`;
- public standards and public product contracts;
- source code, data, and tools admitted under `SOURCE-POLICY.md`;
- the `PROJECT_AUTHORED_SYNTHETIC` PT-BR conformance corpus authorized by
  `USR-016`, under its versioned pre-engine generator specification;
- non-linguistic technical fixtures labeled `FIXTURE_TECNICA`.

## Prohibited inputs

- any prior implementation or sibling-directory material;
- Sophia, `cicero-sophia`, or another closed NLU's code, binary, model,
  vocabulary, private data, formats, configuration, traces, live outputs,
  internal behavior, internal names, or heuristics;
- translated, paraphrased, or behaviorally reconstructed Sophia examples;
- benchmark adapter code or benchmark utterances as implementation material;
- Amazon-specific or Amazon-internal sources, tools, packages, repositories,
  SDKs, data, documentation, endpoints, services, models, or credentials;
- AI-generated, AI-translated, or unprovenanced words, aliases, morphology,
  grammar, examples, annotations, responses, templates, train/dev/test/gold
  items, or evaluation judgments outside the exact
  `PROJECT_AUTHORED_SYNTHETIC` exception;
- output from this project's NLU used as a gold label or evaluation oracle.

The model may write algorithms and non-linguistic code. It is not an authority
for independent Brazilian Portuguese language facts. A Portuguese-looking
literal is linguistic material even when placed in source code or a unit test
and must either have admitted external lineage or be explicitly identified as
`PROJECT_AUTHORED_SYNTHETIC`.

## Project-authored synthetic corpus

`USR-016` permits one bounded workaround after eligible external source
recovery was exhausted. Project-authored PT-BR templates, lexical parameters,
and semantic labels may be used only when:

1. a versioned generator specification defines the expected semantics before
   the NLU implementation under test;
2. every output has deterministic generator lineage and an Apache-2.0 license;
3. train, development, held-out, performance, and fail-closed identities are
   frozen before tuning and remain family-disjoint where required;
4. no project NLU output creates, corrects, filters, or validates a label; and
5. every metric is named internal conformance and expressly disclaims
   independent linguistic accuracy and Sophia equivalence.

External model output, generated source laundering, post-freeze case
augmentation, and unlabeled Portuguese literals remain prohibited.

## Technical fixtures

`FIXTURE_TECNICA` exists only to test structural behavior with synthetic,
non-language markers such as opaque IDs. It cannot contain natural-language
utterances, translations, aliases, response prose, or morphology. Removing
technical fixtures must not change the compiled language package, lexicon,
grammar, or linguistic quality metrics.

`PROJECT_AUTHORED_SYNTHETIC` is not a technical fixture. It is licensed,
versioned linguistic conformance material and is included in explicitly
limited internal metrics.

## Public reference products

Public Sophia claims may appear only in
`SOPHIA-REFERENCE-STUDY.md` and the material ledger. They are untrusted external
claims used to define independent acceptance thresholds. They cannot seed
rules, vocabulary, datasets, expected outputs, or error-specific tuning.

The public Aquila benchmark was examined only to audit the published aggregate
result and methodology. Its repository license contains unfilled copyright
placeholders, its English utterances are author-controlled, and it is not
admitted as code or data.

## Exposure and contamination response

Every external exposure is recorded in `MATERIALS.yaml` with allowed use.
Suspected contamination triggers:

1. isolate the source and all derived artifacts;
2. identify affected commits, data, rules, tests, and reports;
3. invalidate affected baselines and metrics;
4. remove the material by source ID;
5. independently rebuild from the last uncontaminated baseline;
6. repeat all affected reviews.

Uncertainty is resolved as contamination until evidence proves otherwise.
