# P01 Dependency Advisory Audit

- Database owner: RustSec
- Canonical repository: `https://github.com/RustSec/advisory-db`
- Commit: `6420e39260b3d771b049954cf5d52b57e2118da4`
- Tree: `01794d45488a521b322b760b6bfdcd6e9f28932b`
- Snapshot date: 2026-08-27
- Result: `PASS_NO_MATCHING_ADVISORY_PACKAGES`

## Admission

The snapshot contains 1,206 advisory Markdown files totaling 1,256,065 bytes.
SHA-256 over each sorted relative path, one NUL byte, and its file bytes is
`26b7afd8690bdd0a743d7405a39e643ca95c05e1529a4c5c59f0e6ae9751eb67`.
No separator follows a file's bytes.

The root grant, SHA-256
`b342fe896e158b8c5a83e707446113f3a149fa0104d834afa78cd2a48eaf1906`,
places unmarked records under CC0-1.0 and explicitly places imported records
under CC-BY-4.0. The bundled file named `CC-BY-4.0.txt` instead contains
CC-BY-SA-4.0 and is rejected as legal terms. The authoritative Creative
Commons 4.0 legal code is independently bound at SHA-256
`9ba9550ad48438d0836ddab3da480b3b69ffa0aac7b7878b5a0039e7ab429411`.
CC0-1.0 and CC-BY-4.0 permit this validation use, modification,
redistribution, and commercial use. Database bytes are not copied into the
repository or product.

## Query

An admitted `/usr/bin/ruby` process read every `crates/**/*.md` file in sorted
path order, extracted an exact front-matter `package = "..."` line, and
compared it with:

`itoa`, `memchr`, `proc-macro2`, `quote`, `ryu`, `serde`, `serde_core`,
`serde_derive`, `serde_json`, `syn`, and `unicode-ident`.

The executed query returned `NO_MATCHING_ADVISORY_PACKAGES`. With no package
match, version-range evaluation was not applicable. The database owner,
repository, and scanned bytes are independent of every dependency owner in the
P01 closure, and no Amazon-specific or internal source was used.

## Limitation

This result means only that the immutable RustSec snapshot contains no
advisory naming a locked P01 package. It does not prove absence of undisclosed,
unreported, newly published, or package-name-mismatched vulnerabilities.
Future phases repeat the audit against a newly admitted immutable snapshot when
the dependency closure changes or before release.
