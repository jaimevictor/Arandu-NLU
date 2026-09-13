# Rhasspy Official PT-BR Source Family Rejection

- Source ID: `rhasspy-official-pt-br-profile`
- Decision: `REJECTED`
- Decision time: `2026-08-28T01:20:01Z`
- Intended review use: PT-BR assistant intents, slots, and frequency
- Allowed project use after decision: `none`

## Official Discovery Path

The following exact official repositories were inspected in isolated,
detached quarantine checkouts:

| Repository | Commit | Tree | Result |
| --- | --- | --- | --- |
| `rhasspy/rhasspy3` | `11e8d3016d323a2ab1756dc68b4ba8a9f75f22a6` | `015b66da7a8e3dae6033abfcf05d301c79e9e2c6` | No Portuguese language payload |
| `rhasspy/rhasspy` | `083721a92a9a12396c794003a7f9ebcdd8dffa60` | `2edecdce331ec96f7fcddf88207b70d4257e2856` | English example only; points to profiles |
| `rhasspy/rhasspy-nlu` | `06d118c0ff92cec95e0e70a9c08b12b7f5202f46` | `4896d1d3fe9dd3947db91a462fc2838d57c61614` | Parser code; no Portuguese data |
| `synesthesiam/voice2json` | `03996c94113a615182adbbb1c83834124833579a` | `77780dd924e6da6ed32969c0344657e6d1821120` | PT-BR ASR download metadata; no PT-BR intent data |
| `rhasspy/rhasspy-profile` | `cd45d1ad6158e7f8113c5c75e74b9e61afa1823a` | `99af04ae708d58db4e44445fb36a982071e4cfd3` | Contains the canonical PT-BR profile |

All worktrees were clean. The core code repositories use complete MIT license
texts, but they contain no relevant Portuguese language data. They were
discovery steps only and were not dependency candidates.

## Profile Identity And Provenance

The exact `rhasspy-profile` PT subtree plus `LICENSE` forms a deterministic
112,640-byte tar archive with SHA-256
`7c33bf0a769a283d33c439d6f025e82a8ba00893787e0e163358a53db4dc37c3`.
The complete MIT license is 1,071 bytes with SHA-256
`273c11fe9a995c66456f36e10ff6b4c234d104c4f175db39c8f25aa5123f70c0`.
The 420-byte sentence grammar has SHA-256
`f38dc44ffabdaf310af6d26f80c57d4e353e36e298ff1b4144b85337566f8e62`.

The entire Portuguese profile was introduced by Michael Hansen in one bulk
commit, `495922a9cb9c5db8a958e53e60349dfbc5d7815e`, on 2020-02-20 with subject
`Add profiles for other languages`. No Portuguese author, translator,
upstream record, or origin declaration accompanies the sentence grammar.
The date makes modern generative-model origin unlikely, but it does not prove
human authorship, translation authority, or source ownership.

The profile's 10,000-entry `frequent_words.txt` has SHA-256
`4e5b6781446bac85321ea7ee27701a598ec9f4384900f899198b460804ae41b9`.
It was replaced in a 2021 all-language bulk update. No corpus identity,
license, extraction recipe, or per-entry provenance is recorded, so it cannot
be used as a frequency oracle.

## Semantic Coverage

The sentence grammar has five intents and expands to 32 surface strings.
Ignoring optional articles and equivalent surface variants leaves at most 17
distinct intent-plus-slot labels. It has no multi-intent graph, clarification,
abstention, contradiction, ambiguity, stale-state, safety-sensitive,
explicit-negative, or broad Home Assistant domain coverage.

It is therefore far below the mandatory 3,715 distinct scored cases and every
237-case supported-stratum floor. Expanding optional words cannot create new
canonical semantic identities.

## Decision And Removal

The profile is rejected for unprovenanced Portuguese language and frequency
origins and independently insufficient semantic coverage. No inspected byte
entered the project tree, runtime, vocabulary, rule set, fixture, training
set, or evaluation. All six Rhasspy/voice2json quarantine checkouts were
deleted, and targeted post-removal checks found no remaining path.

Commands used: official-repository resolution; exact-commit Git fetch and
detached checkout; filtered history fetch; `git rev-parse`, `git status`,
`git log`, `git diff`, `git archive`, `find`, `grep`, `sed`, `wc`, and
SHA-256.
