# Historical P02 Source Admission Blocker Report

- Phase: `P02`
- Historical state: `BLOCKED`
- Resolution: `RESOLVED_BY_USR_016`
- Input baseline: `533796e4173c0128e452c22cc60606c32be3fe81`
- Recovery input baseline: `c5f34a11447e8081218f3e04db81ae444c853d07`
- Pre-candidate passes: `3/3 consumed`
- User-directed recovery passes: `1/1 consumed`
- Candidate rounds: `0/3 consumed`
- Result: `PRESERVED_CONTRACT_SOURCE_RECOVERY_EXHAUSTED`

## User-Authorized Resolution

After the bounded recovery pass failed, the user explicitly authorized the
project to create the corpus. `USR-016` permits a deterministic Apache-2.0
`PROJECT_AUTHORED_SYNTHETIC` PT-BR conformance corpus whose labels are fixed by
the generator specification before NLU implementation. It supersedes the P02
external-source obligation and the independent-accuracy claim, but retains the
3,715-case minimum, 237-case supported-stratum floor, frozen splits, duplicate
controls, five fail-closed suites, and prohibition on NLU-derived labels.

`P02-ORACLE-001` is resolved by this scope decision. Measurements from the
replacement corpus may be called only internal conformance; they cannot
establish independent linguistic accuracy or Sophia equivalence.

## Completed Work

P02 inspected and dispositioned two integrated public-source portfolios:

1. Home Assistant PT-BR intents with UD Portuguese Bosque;
2. LibreOffice VERO with the official Rhasspy PT-BR profile family.

All four source families were rejected for recorded provenance, rightsholder,
license, lineage, or mandatory-coverage failures. No payload was admitted, and
all quarantine copies were removed.

The third and final pass implemented and measured a corpus-free exact UTF-8
byte matcher. Its fixture-only tests pass and its fixed five-run benchmark is
recorded in `docs/evidence/P02-CORPUS-FREE-FALLBACK.md`. It avoids frequency
ranking but provides no morphology, contextual POS, semantics, evaluation
labels, or independent oracle.

The user explicitly selected the preserve-ADR-0005 source-search route. One
bounded recovery pass then screened OpenVoiceOS source families, MInDS-14,
EVA-FMRP, XTREME-UP MTOP++, MultiATIS++, and focused academic/dataset indexes.
XTREME-UP is the strongest human PT-BR partial source, but it has only 3,576
distinct semantic targets, only six intents with at least 237 rows, and none of
the mandatory Home Assistant device-control, multi-intent, or five fail-closed
suite coverage. Its canonical official archive is also unavailable and the
third-party mirror does not prove complete underlying data rights. Full
evidence is in `docs/evidence/P02-SOURCE-DISCOVERY.md`.

## Historical Blockers

- `P02-ORACLE-001` (`P0`, resolved by `USR-016`): no eligible inspected source or recovery portfolio
  provides the mandatory
  3,715 distinct independently labeled PT-BR Home Assistant scored cases,
  237 distinct cases per supported stratum, separate fail-closed suites, and
  independent oracle lineage. Project output, executor judgment, generated
  language, and technical fixtures cannot supply or validate those labels.
- `P02-PRE-001` (`P1`, waived for P02 closeout): eligible independent
  pre-phase analysis instances were unavailable. The executor syntheses are
  retained and are not represented as independent reviews. The user's
  direction to skip the final P02 review and move on applies to this
  unavailable-review blocker for this closeout only.

These blockers historically prevented a candidate. `USR-016` supplied the
source-origin scope decision, and the successful replacement-corpus run
produced candidate round one.

## Convergence Decision

ADR-0006 and `AGENTS.md` cap pre-candidate convergence at three integrated
passes. Starting a fourth source search or another redesign is prohibited.
Weakening licensing, provenance, clean-room, safety, or independent-oracle
requirements autonomously is also prohibited.

The explicit user choice authorized one recovery pass while preserving the
contract. That exception is now consumed and did not produce a candidate.

P02 was therefore blocked before candidate freeze until `USR-016`. P00 and
P01 remained complete during that interval.

## Replacement Route

No additional external-source search or refinement pass will run. P02 resumed
within candidate round `1/3` by defining, generating, freezing, and validating
the smallest corpus that satisfies the retained conformance controls. The
passing result is recorded in `docs/evidence/P02-VALIDATION.md`.
