# ADR-0001: Clean-room and FOSS-only policy

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-24
- Owners: P00, P02, P03, P06, P15

## Context

The implementation starts with only the user-provided steering document. The
user requires every project component to be free and open source and prohibits
Amazon-specific or internal material. Sophia is a closed reference product
whose public claims may inform acceptance targets but whose implementation must
not inform this project.

The steering's allowance for locally usable but non-redistributable data is
superseded by the stricter user requirement.

## Decision

All project-authored code, documentation, scripts, schemas, tests, and
configuration are Apache-2.0. Every shipped software dependency, build tool,
runtime tool, model, base image, and code generator must have an OSI-approved
license. Data must allow use, modification, and redistribution, including
commercial use. Attribution and share-alike obligations are allowed only when
they are compatible, isolated, and recorded.

The following are rejected:

- proprietary, source-available, non-commercial, no-derivatives,
  evaluation-only, research-only, click-through, or ambiguous terms;
- material without an identifiable owner, immutable version, complete license,
  and byte-level provenance;
- data inferred from model knowledge or generated/translated by an AI model;
- Amazon-specific or Amazon-internal sources, tools, packages, repositories,
  SDKs, data, documentation, services, endpoints, credentials, or guidance,
  even when a public component has an open-source license;
- Sophia or `cicero-sophia` code, binaries, models, vocabulary, private
  formats, internal behavior, or output-derived language data.

Public standards and public product documentation may be cited as non-shipped
contract references. Restrictively licensed documentation is never copied,
transformed into project data, or bundled. Executable compatibility tests and
openly licensed source are preferred as implementation evidence.

External candidates remain quarantined and unusable until the source-admission
protocol in steering section 8 passes. A public repository with a placeholder
or otherwise defective license is not admitted.

The user-provided agent/orchestration environment is out of tree. It is not a
project dependency, deliverable, data source, linguistic authority, or
validation oracle.

On 2026-08-28, after the bounded P02 external-source recovery found no eligible
portfolio, the user authorized the project to create the required corpus.
`PROJECT_AUTHORED_SYNTHETIC` is therefore a narrow exception to the general
AI-origin language prohibition. It permits Apache-2.0 PT-BR conformance
utterances and expected semantics generated together by a deterministic,
versioned specification frozen before NLU implementation. It does not permit
external model output, NLU-derived labels, laundering rejected sources,
post-freeze augmentation, or claims of independent accuracy, human
representativeness, or Sophia equivalence.

An operator-supplied host operating system, kernel, dynamic loader, and system
libraries are ambient platform prerequisites rather than project inputs. This
boundary does not permit the project to select proprietary tooling: every
executable intentionally invoked by a project validation, build, test,
packaging, or runtime procedure must still have an identified FOSS upstream,
license, immutable source identity, purpose, and exact executable attestation.
The project neither distributes the host OS nor claims that its complete binary
composition is open source or reproducible. P15 release builds must use only
admitted FOSS project tools and base images.

The user-owned steering has no asserted redistribution license. Its current
workspace copy and verified backup are outside the distributable Git lineage.
Its bytes are absent from source archives. Apache-2.0 project-owned requirement
records replace it as the normative distributed specification.

## Alternatives

1. Permit free-to-use but non-redistributable assets. Rejected because it
   prevents a complete open-source distribution and contradicts the user.
2. Permit any publicly visible source. Rejected because visibility does not
   grant modification or redistribution rights.
3. Admit only permissive licenses. Rejected as unnecessarily narrow; compatible
   open data with attribution or share-alike terms may be useful if segregated.

## Consequences

- Some high-quality Portuguese corpora may be unavailable.
- Source acquisition can fail without blocking the project; an independently
  designed rule-based fallback or the explicitly authorized project-authored
  conformance corpus may be evaluated.
- Every release needs a complete license inventory, source hashes, attribution,
  SBOM, and removal test.
- Every tracked release path must match the path-level distribution license
  manifest; `NOASSERTION` material is rejected from source archives.
- Suspected contamination invalidates affected data, rules, tests, and derived
  artifacts back to the last uncontaminated baseline.

## Rollback

This policy can only be strengthened without explicit user direction. A
weaker source policy requires a new explicit user instruction recorded in an
accepted ADR amendment or a superseding ADR.
