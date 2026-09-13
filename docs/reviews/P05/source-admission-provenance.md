# P05 Source Admission Provenance Review

Role: `provenance`
Reviewer instance: `01a04a90-de60-76d2-96c1-42c0184ba687`
Independent context: separate read-only lineage and transformation review
Base HEAD: `9ea869e20e2d69ba2f090773b978b50de6475a62`
Source candidate SHA-256: `25cb4085df8eaf6fb0d8dd91ee4814a03586ed2e0268c93e0f64296a6208f9ff`
Material projection SHA-256: `d59c6d697b1939b75bb54120e383b52a221ab334758d056f83cc27fc699a823a`
Distribution projection SHA-256: `ef8fe50ddc14b114ccc7c4ca1c8a43547302707fdc72ce1604d9101c7bdf2433`
Tokenizer SHA-256: `dc977f44120c34c476f06d6ed6deb3cf8c2e7fcd77b76aeb18e3df762b1238da`
Validator SHA-256: `6ce7e482b6cca6376e7315e8e2e389737c735deaf6f8fd03605defb05d554909`

## Scope

Paths: `data/tokenization/p05/`, UnicodeData, source ledger, literal
extraction tables, immutable content metadata, and removal records.

## Reproduction

Every retained byte count, SHA-256, Git blob, commit, tree, tag, and path
binding reproduced. The UD migration commit directly parents the old-path
revision, and both path-bound responses decode to the same 609-byte PRON
blob. CLDR numbering metadata binds the exact path at the selected commit.
Both TSVs reproduced in declared order with unique IDs and notices.

## Counterexample

Malformed rules, duplicate IDs or surfaces, source-byte substitutions,
unreviewed admission, and an extra P05 data file were rejected. The admitted
lifecycle projection reconstructs the exact reviewed source candidate bytes.

## Findings

P0: none. P1: none. P2: none. P3: none.

Verdict: `PASS`
