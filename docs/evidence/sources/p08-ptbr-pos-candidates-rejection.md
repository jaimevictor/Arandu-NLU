# P08 PT-BR POS Candidate Disposition

- Decision: `REJECTED`
- Decision date: `2026-08-28`
- Intended use: independent Brazilian Portuguese POS evaluation
- Allowed project use: `none`
- Search budget: one user-directed bounded source check, completed

## Scope

The user directed one additional public-source check after the P08
same-source implementation was ready. Three current Brazilian Portuguese
Universal Dependencies treebanks were inspected in isolated temporary
quarantine. No candidate byte entered this repository or influenced runtime
behavior, training, evaluation, vocabulary, rules, fixtures, or labels.

## Candidates

| Candidate | Commit and tree | Evidence | Disposition |
| --- | --- | --- | --- |
| UD Portuguese GSD | commit `c91edee46c9d096c684dda4848637dff5f4299e9`; tree `2d213f7a06a8ed8df9a01008bf6507bd8d792548` | README: 4,461 bytes, SHA-256 `a6068ed6d43c318b8ab836b4061bb6160137995494cec1aac7a4725f5fefd2fd`; license pointer: 202 bytes, SHA-256 `899b1804a12ebc090b96339614eede1b64b686721b650a71430b55b5235f7f79` | Rejected. The README says Google claims no ownership or copyright over the underlying text, warns it may be copyrighted, and relies on copyright exceptions or implied license. It licenses annotations but does not prove commercial modification and redistribution rights for the text. It also records automatic correction using a model trained on the already rejected Bosque corpus. |
| UD Portuguese PetroGold | commit `5814c7f92b88b64ccb9ba2d8ef33c64535dc881f`; tree `6cb9af95b9fd71713673054d82322f8e7c232f15` | README: 3,663 bytes, SHA-256 `7901f133a0f88b7158944a46b2995a6c52c98f620e14ad191538db0c8c7369ed`; license pointer: 202 bytes, SHA-256 `899b1804a12ebc090b96339614eede1b64b686721b650a71430b55b5235f7f79` | Rejected. The corpus contains 19 complete academic documents gathered from PDFs. The repository identifies only opaque document IDs and does not bind each document to its author, title, rightsholder, source license, or a grant covering commercial modification and redistribution. A general statement that the corpus was made public and a repository-level CC-BY-SA pointer do not establish rights over every underlying document. |
| UD Portuguese Porttinari | commit `87a07e1fb761d6d0a6e2a4d82b11b308344dabb9`; tree `476de76c8404287505fba48b13c2c83852876e59` | README: 4,821 bytes, SHA-256 `792c93a16a60136179e8e5bd76660d617fbb97892d03618aa903f87a963fde84`; license pointer: 188 bytes, SHA-256 `5cbfe2d4d12938f9961bf5a0028390f4b6b60749b075e228a5740848afcb4a9b` | Rejected. The README identifies Folha de S.Paulo newspaper articles obtained through Kaggle. Neither the repository nor its license pointer supplies an underlying-text grant from the newspaper or article rightsholders. Public availability is not redistribution authority. |

## Result

All three repositories carry permissive-looking data-license metadata, but
none proves that the license covers every underlying text. GSD and Porttinari
state the conflict directly. PetroGold lacks the per-document provenance and
rightsholder grant required to resolve it. Unknown rights fail closed under
the source policy.

The three temporary quarantine checkouts were removed after the immutable
metadata and rejection reasons above were recorded. A targeted check found no
remaining `nlu-p08-ud-*` path under `/private/tmp`.

The P08 project-authored source therefore remains the only eligible input. Its
results remain explicitly limited to same-source internal conformance. This
check does not establish independent accuracy and does not reopen optional
P08 refinement.
