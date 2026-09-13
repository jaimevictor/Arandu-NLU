# P02 Source Discovery

- Baseline start: `533796e4173c0128e452c22cc60606c32be3fe81`
- State: `BLOCKED_ELIGIBLE_EXTERNAL_ORACLE_REQUIRED`
- Pre-candidate pass budget: `3/3 consumed`
- User-directed recovery pass: `1/1 completed`
- Substantive candidate rounds: `0/3 consumed`

## Pass Definition

One P02 pre-candidate pass is an integrated source portfolio or corpus-free
fallback selected to cover the mandatory lexicon/morphology, contextual POS,
PT-BR Home Assistant semantics, and frequency needs. A pass ends when that
portfolio is admitted, rejected, or proven unable to meet minimum acceptance.
Routine acquisition retries and repositories inspected only to locate the
canonical payload do not create extra passes.

Minimum source acceptance is the smallest portfolio that proves eligible
rights and human provenance and can freeze 3,715 distinct PT-BR Home Assistant
semantic cases, 237 cases per supported stratum, all required fail-closed
suites, contextual POS evaluation, and an independently licensed frequency
source or measured corpus-free replacement.

On 2026-08-28 the user selected the first blocker-report option: preserve
ADR-0005 and search for an eligible source portfolio. That explicit decision
authorized one bounded recovery pass without reopening the ordinary `3/3`
pre-candidate budget. The recovery pass ends with one admitted integrated
portfolio or a recorded rejection and restored blocker. It does not authorize
another search or refinement pass.

## Completed Passes

| Pass | Portfolio | Result |
| ---: | --- | --- |
| 1 | Home Assistant PT-BR intents plus UD Portuguese Bosque | Rejected: intent origin/authority and coverage unprovable; Bosque underlying newspaper rights conflict |
| 2 | LibreOffice VERO PT-BR dictionary plus official Rhasspy PT-BR profile family | Rejected: dictionary license ambiguity and missing contextual labels; Rhasspy origin/frequency lineage absent and semantic coverage limited to at most 17 identities |
| 3 | Corpus-free exact-match and no-frequency fallback | Measured; no external semantic cases or oracle, so insufficient for phase acceptance |

No source has been admitted. Every acquired byte remained quarantined and was
removed after disposition.

## User-Directed Recovery Pass

The bounded recovery pass screened official repositories, dataset cards,
papers, and academic indexes. It found no admissible integrated portfolio.

| Candidate | Immutable evidence | Observed result | Disposition |
| --- | --- | --- | --- |
| OpenVoiceOS `intents-for-eval` | revision `fb95522c630ce56c9d405ff614452484f2716741`; PT-BR payload SHA-256 `aaf21e19837cd8caad419ea3fadc6a9a88bdc0e785dbf6a1abdb21358c8d89d0` | 1,750 PT-BR rows and 50 intents; the source specification says Claude Opus generated the multilingual data and no native-speaker review occurred | Rejected: model-generated language is prohibited |
| OpenVoiceOS `hass-intent-templates` | revision `6d2c98660596082a3c989a201d7fb56691103cda`; PT-BR payload SHA-256 `1568a273ac5885adf040751542a9e235b848c09c7763655453c8adcd742ce07e` | 3,522 templates and 41 intents derived from the already rejected Home Assistant intent source | Rejected: rejected lineage cannot be laundered, and the derivative license claim does not establish underlying content rights |
| Other OpenVoiceOS candidates | official dataset metadata | `ovos-intents-massive-subset` is derived from prohibited Amazon MASSIVE; `OVOSGitLocalize-Intents` does not establish complete origin or license scope | Exposure rejected |
| MInDS-14 | Hugging Face revision `40ce77cb32a384e4d50a568e1ec39ac804019d33`; card SHA-256 `3dd23ca4c7834f66ca043847996dbd7c9ca34c846749d86431a9fa19898f4f88` | only `pt-PT`, 604 examples, 14 banking intents, and no Home Assistant graph or fail-closed semantics | Rejected: wrong locale, domain, and cardinality |
| EVA-FMRP `eva-core` family | commit `b76062f531f5a12e2498258f68efa3e0af9ab6ab`; tree `392a4cdc845c368c003465581176ee0700959b45`; README SHA-256 `13d66db0a2444edc52bec1b618522a5f5a38ed9e11e3c74b1aca21c9198c3e4d` | a Mycroft application fork whose skills are downloaded from separate repositories; the immutable tree contains no PT-BR labeled intent corpus | Rejected: no candidate payload or oracle |
| XTREME-UP MTOP++ PT-BR | Hugging Face revision `535fcd6f3a36d6bf591ce36e8a175304907ffe9b`; official repository commit `26bb6d8b405cf1aeca84f54871ab5db4545d2604`; paper-source SHA-256 `d36ff208082b09b578117fed39e94fc7f2004a7cf0868cbc684c305131e67b1e` | professional human translation/localization; 4,223 rows, 4,198 distinct inputs, 3,576 distinct semantic targets, and 53 intents. Only 2,074 rows and 1,842 distinct targets belong to the six intents reaching 237 rows; 47 intents are under quota. It has no Home Assistant device-control denominator, independent multi-intent graphs, or safety, contradiction, ambiguity, stale-state, and negative suites | Rejected as a P02 portfolio: below distinct-case and per-intent floors, mandatory scope absent, and the official archive now returns HTTP 403 while the third-party mirror does not prove underlying data-license scope |
| MultiATIS++ | task-oriented-dialog dataset survey source SHA-256 `59464fbc11e293d1cd73e4ce4c5937f49e49545fca1d014b8592a6f2256f6533` | professional Portuguese translation of the ATIS aviation corpus; no Home Assistant semantics, multi-intent graph coverage, or fail-closed suites; the underlying ATIS source is LDC-licensed | Rejected before payload acquisition |
| `TAGuedes/1.000.000-nile-intents-pt-br` | revision `ec1a0b3af57f2c4f5113c569ae7246d97916c68c` | no credible complete license or human per-entry provenance | Rejected before payload acquisition |

The official 2022 task-oriented-dialog dataset survey identifies
MultiATIS++ as the only Portuguese joint intent/slot dataset in its
non-English inventory. Newer catalog searches found XTREME-UP, prohibited
MASSIVE derivatives, machine-translated `iva_mt_wslot`, the rejected
OpenVoiceOS family, private conversational corpora, speech-only corpora, and
small command sets. No additional human PT-BR Home Assistant source was
identified.

The principal discovery-response SHA-256 values are:

- Hugging Face intent index: `29d84cdc69d7970afb77059754af74d982de68890e0e754625557e173f796959`;
- OpenAlex voice-command search: `b57131db62bf263592b2c64c8e67fa0c3035eb7e99f1e16c31e561ad9c5ff5a6`;
- OpenAlex Portuguese-command search: `70dc06dc08556811daaeea56b0e8fdbaf90ae713eb845c7370f14e8111b22fae`;
- Zenodo PT-BR search: `2688b27a9640116160b7a703ad5386811ca01fe43deb1a2d32c8f9e74f29e828`;
- Zenodo voice-command search: `6dda33c12b5725a00039d2b095e3cc9668ee2e59d5cc716aa279cf21ff674045`.

Search results and candidate bytes remained outside the repository and could
not influence linguistic implementation or evaluation. Temporary recovery
quarantine removal was verified at `2026-08-28T17:55:57Z`.

## ASR Noise Decision

No ASR-noise corpus is required for the initial release. The NLU boundary
accepts text and does not own acoustic transcription. Noise handling remains
limited to explicit text-level classes supplied by an independently admitted
semantic evaluation source. Acquiring speech or residential transcripts would
add privacy and license risk without satisfying the blocked semantic oracle.

## Current Blocker

`P02-ORACLE-001`: no inspected eligible source or recovery portfolio supplies
the mandatory
independently labeled PT-BR Home Assistant evaluation cardinality and
fail-closed coverage. A corpus-free algorithm can provide deterministic
matching or ranking but cannot establish external gold outcomes. Project
output, executor judgment, and generated fixtures remain prohibited as
oracles.

## Final Fallback Result

The standard-library Ruby prototype in `tools/p02-fallback.rb` performs only
exact matching over unchanged valid UTF-8 bytes. It rejects invalid inputs and
duplicate keys and does not normalize, analyze morphology, label POS, perform
fuzzy matching, rank by frequency, or create semantics.

Eight fixture-only tests passed. A digest-bound workload with 4,096 entries,
three warmups, and five measured runs produced a median of `1,158,630.87`
exact lookups/second on the recorded host. The workload and all measurements
are in `docs/evidence/P02-CORPUS-FREE-FALLBACK.md`.

The prototype supplies zero external oracle cases and zero semantic coverage
cases. The external-oracle blocker remains. Pass `3/3` is consumed, no
candidate round was started, and P02 was placed in `BLOCKED` for the explicit
scope decision recorded in `docs/phases/P02-BLOCKER-REPORT.md`. No fourth
ordinary search or refinement pass was permitted.

The user then selected the preserve-contract source-search route. Its single
recovery pass also failed minimum acceptance, so P02 returns to `BLOCKED`.
Candidate rounds remain `0/3`; no further autonomous source search is
permitted.

## User-Authorized Corpus Replacement

After this recovery result, the user authorized creation of the corpus inside
the project. `USR-016` resolves `P02-ORACLE-001` by replacing the unavailable
external oracle with a deterministic, versioned
`PROJECT_AUTHORED_SYNTHETIC` conformance corpus. It does not reopen source
search and does not admit any rejected candidate.

The replacement retains the numerical cardinality, per-stratum quota,
anti-duplication, frozen-split, and fail-closed-suite controls. Generator
specifications establish expected semantics before NLU implementation, and
project NLU output remains prohibited as a label source. Results from this
corpus are internal conformance only and cannot support independent accuracy
or Sophia-equivalence claims.
