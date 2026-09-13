# P05 Source Admission Adversarial Review

Role: `adversarial`
Reviewer instance: `01a04a90-e87c-7f20-824f-8ce2e7356746`
Independent context: separate read-only fail-closed robustness review
Base HEAD: `9ea869e20e2d69ba2f090773b978b50de6475a62`
Source candidate SHA-256: `25cb4085df8eaf6fb0d8dd91ee4814a03586ed2e0268c93e0f64296a6208f9ff`
Material projection SHA-256: `d59c6d697b1939b75bb54120e383b52a221ab334758d056f83cc27fc699a823a`
Distribution projection SHA-256: `ef8fe50ddc14b114ccc7c4ca1c8a43547302707fdc72ce1604d9101c7bdf2433`
Tokenizer SHA-256: `dc977f44120c34c476f06d6ed6deb3cf8c2e7fcd77b76aeb18e3df762b1238da`
Validator SHA-256: `6ce7e482b6cca6376e7315e8e2e389737c735deaf6f8fd03605defb05d554909`

## Scope

Paths: P05 tokenizer, source and material ledgers, distribution rules,
review transitions, data inventory, validator, and mutation tests.

## Reproduction

The candidate gate, all eight mutation tests, all 28 Rust tests, and
warnings-denied Clippy passed. Terminal plus, underscore boundaries, exact
prefixes, grouping, combined patterns, spans, idempotence, token limits, and
debug output were exercised. Repository state and supplied hashes were stable.

## Counterexample

A coordinated admitted-state substitution changed canonical URLs, uses,
prohibitions, redistribution and transformation claims, material metadata,
and distribution licenses. Exact source-byte reconstruction and complete
canonical projections rejected every change. A lifecycle-only admission
transition remained accepted.

## Findings

P0: none. P1: none. P2: none. P3: none.

Verdict: `PASS`
