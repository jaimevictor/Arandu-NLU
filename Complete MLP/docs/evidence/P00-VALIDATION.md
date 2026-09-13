# P00 Validation Contract

- Pre-freeze execution: 2026-08-27T18:13:44Z
- Candidate identity: the commit containing this file
- Frozen-subject evidence location: exact independent review reports
- Pre-freeze result: `PASS`

## Entry points

The validator has one required runtime command. Its committed launcher invokes
`/usr/bin/env -i` before Ruby starts, fixes the security-relevant execution
environment, and disables RubyGems. macOS may inject
`__CF_USER_TEXT_ENCODING`; the CLI permits only that documented ambient key and
deletes it before validation:

```text
tools/validate-governance \
  --expected-commit <full-40-hex-subject-commit> \
  --expected-tree <full-40-hex-subject-tree> \
  --expected-normative-rows-sha256 <full-64-hex-digest> \
  --expected-validate-launcher-sha256 <full-64-hex-digest> \
  --expected-validator-source-sha256 <full-64-hex-digest> \
  --expected-test-launcher-sha256 <full-64-hex-digest> \
  --expected-test-source-sha256 <full-64-hex-digest>
```

The seven values form the reviewer-owned out-of-tree review tuple. Before
executing repository code, every reviewer uses the attested absolute Git and
Ruby tools in a private no-hardlink clone to check HEAD, tree, cleanliness,
index flags, the four committed modes and blob hashes, and byte equality with
the four regular worktree files. Candidate-controlled code cannot be its own
trust anchor; the in-repository checks repeat this external preflight only as
defense in depth. No external supervisor script is required.

The out-of-tree reviewer instruction defines the row digest without consulting
candidate code: for every requirement row in document order, serialize ID
without backticks, Source, Requirement, Owner, Verification, and Evidence as
UTF-8, join fields with byte `0x09`, terminate every row with byte `0x0a`, then
compute SHA-256. Status is excluded from this digest.

Direct invocation of `tools/validate-governance.rb` is rejected. The canonical
executing launcher and validator paths, modes, committed blobs, worktree bytes,
and externally frozen hashes are bound. `RUBYOPT`, `RUBYLIB`, gem, bundle, Git
configuration, locale, and path injection counterexamples are covered.

It rejects a different `HEAD`, a different tree, staged changes, unstaged
changes, and untracked files. Because a commit cannot contain its own object ID,
the exact invocation and output are produced after freeze and retained by every
reviewer. A pre-freeze worktree result is not accepted as frozen-subject proof.

This commit-bound command runs from a clean Git clone of the distributable
lineage. An extracted source tarball has no Git object database and is not
misrepresented as a review subject. The command creates a local no-hardlink
clone, generates the release tar archive there so repository-local attributes
cannot affect it, parses it, and proves exact path equality, license coverage,
and steering exclusion before that archive is accepted.

The regression suite constructs a temporary candidate commit from the current
worktree and mutates only that temporary repository:

```text
tools/test-validate-governance
```

After all five P00 reports pass, the unchanged candidate validator checks the
evidence-only child commit with the same tuple plus:

```text
  --checkpoint-subject-commit <reviewed-commit> \
  --checkpoint-subject-tree <reviewed-tree> \
  --expected-review-requirements-sha256 <reviewer-owned-sha256> \
  --expected-review-correctness-sha256 <reviewer-owned-sha256> \
  --expected-review-tests-sha256 <reviewer-owned-sha256> \
  --expected-review-risk-sha256 <reviewer-owned-sha256> \
  --expected-review-reproducibility-sha256 <reviewer-owned-sha256>
```

Checkpoint mode revalidates the subject, requires it as the sole parent,
enforces regular evidence-file modes and the exact evidence-only path set,
binds all five reports to external hashes and distinct independent reviewer
instances, rejects empty or contradictory report sections, limits every
non-report file to its canonical byte transformation, and checks the exact
P00-to-P01 state, queue, licensing, and requirement-status transitions.

## Pre-freeze results

| Check | Result |
| --- | --- |
| Ruby syntax for validator and regression suite | PASS |
| Strict parse of the requirement manifest | PASS |
| `tools/test-validate-governance` | PASS (492 cases) |
| `git diff --check` | PASS |

The cases include a clean positive subject; external tuple and coordinated
validator-rewrite rejection; sanitized-launcher preload, mode, direct-source,
copied-launcher/source, and byte mutations; replacement-root,
committed-byte, attested-Git-path, implementation-versus-shim, commit/tree,
dirty-tree, skip-worktree, and assume-unchanged checks; malformed, tagged,
duplicate, merged, aliased, semantic boolean/numeric, unknown, reordered, and
contradictory YAML, including bounded deeply nested subject and checkpoint
payloads; direct same-size worktree mutations hidden by weak Git stat settings;
deleted, jointly rewritten, unowned, prematurely satisfied,
downgraded, or unverifiable requirements; ADR status-token smuggling, broken
links, and contradictory normative prose; admitted or misused quarantined
material, including hyphenated build-input use; rejected material with allowed
use; unapproved material identities, owner-changing URI dot segments, and
repository owners;
missing source commits, malformed source hashes, mutable toolchain evidence,
ineligible licenses, providers, or tools; false Amazon attestations; fixed
allowlist enforcement; structured and encoded provider metadata; Amazon-owned,
alternate-host, trailing-dot, deeply encoded, and
aliased material/tool providers, endpoints, repositories, SCP identities,
actions, and package coordinates;
vacuous false-plan coverage, removed typed-outcome oracles, and overbroad DTO
privacy regressions;
stale validation timestamps; premature global-requirement completion;
reversed execution-quality priority; weakened named sensitive-operation,
source/lexical transformation-lineage, phase-versus-terminal verdict,
semantic-output, and Sophia-claim obligations;
weakened decision precedence or same-level criteria; removed response-rendering
separation or global AI-origin language, prior/sibling implementation, and
closed-engine prohibitions; removed edit/search fallback traceability;
removed phase-round, minimum-acceptance, immediate-checkpoint, P3-deferral,
budget-exhaustion, or remaining-P00 convergence obligations;
missing or denied validator-tool redistribution rights;
reintroduced steering paths; symlinks; Home Assistant storage, secret files,
generic, structurally decoded folded-YAML, quoted, escaped, nested, and
canonicalized credentials, including percent-, JSON-Unicode-, and HTML-encoded
unfenced keys plus YAML-escaped and canonical-separator keys; emphasis-,
balanced-link-, inline-image-, reference-image-, and
shortcut-image-wrapped keys; embedded and duplicate-key residential JSON;
exact technical fixture exemptions across block, flow, folded, literal,
quoted, multiline, sibling, and commented YAML plus prefixed and mixed
residential canaries;
expanded residential fields; private-key
variants, NUL and invalid UTF-8 payloads; unmatched or merely relabeled archive
paths; invalid distribution licenses; PAX state across long directories;
repository-local export attributes; invalid queue transitions; and ignored
local ADR isolation. Alternate-ref credential, residential, Home Assistant
state-path, and user-utterance payloads are rejected, including direct tree
refs, merge-result trees, and checkpoint-only tag refs. Checkpoint positives plus
wrong-parent, merge-parent,
gitlink, NUL-bearing report, hidden prefix/suffix/Markdown-prefixed or styled
finding, percent-, JSON-Unicode-, HTML-, or Markdown-encoded controls, indented
or styled verdict, raw HTML-comment, quoted-attribute, multiline, or nested
malformed HTML, and invalid-link findings, literal and encoded exact
single-code-span Scope syntax,
canonical field ordering, unfenced camel-case and dotted equals sensitive
assignments, malformed exact-fixture continuations, escaped acronym keys,
nested JSON fragment-overflow, malformed checkpoint requirement ID,
backtick- and tilde-fenced duplicate-YAML-key,
attributed and lone-CR YAML fences, pre-whitespace report-size rejection,
checkpoint identity precedence, reviewer-method, evidence-citation, and
substantive-change negatives are also covered. The suite also directly
exercises subject and checkpoint semantic
YAML-value depth guards and parser-stack rescue paths; exact 64-pass and
rejected 65-pass decoding; fail-closed embedded-YAML parse and stack errors;
assignment and whole-payload YAML stack errors; malformed explicit and
protected whole-payload YAML;
matched, unmatched, and escaped Markdown nesting limits plus linear unmatched
angle destinations; valid JSON surrogate pairs and fail-closed lone-surrogate
protected keys; default-ignorable controls,
packages, owners, and sensitive keys; overlapping and multibyte-prefixed URLs
plus URL limits;
scalar-only fixtures;
non-scalar and over-depth provider metadata; recursively serialized JSON and
inline, standalone, flow, explicit, comment-prefixed, and multi-document YAML
provider payloads; balanced, truncated, or mismatched protected JSON;
malformed nested, mixed-Markdown flow/explicit, and semantic or duplicate
embedded/whole-payload YAML keys;
leading Markdown-link versus YAML-sequence classification; rendered
inline-link, reference-link, image, HTML-tag, and HTML-comment structured keys;
nested inline, reference, and shortcut link/image prose positives; structured
payloads following exact, normalized, or continued reference images; nested
sequence, inline or standalone explicit scalar-key, anchor, tag, and alias
protected blocks following images, including an allowed-provider positive;
top-level escaped sensitive blocks following Markdown;
blockquote and ordered/unordered-list structured controls; standalone node
properties and alias-valued mappings after images; duplicate direct protected
assignments and alias siblings; no-space blockquotes, normalized duplicate
assignments, flow-wrapped assignment aliases and anchors, and repeated
standalone node properties; prose-prefixed protected blocks, adjacent
same-indent protected siblings, node properties before flow roots, and
equivalent protected keys separated by ordinary or explicit mapping siblings,
merge/complex sibling forms, YAML document boundaries, flow-set protected
keys, slash-, brace-, bracket-, comma-, and hash-separated protected keys,
indentless sequences, directives,
inline document anchors, unsafe preceding siblings, and base-aligned flow
closers; clock, URL, Markdown-reference, ordered/star-list, continuation, and
nested-blockquote, nested-list, indented-code, and CR-only shortcut-label
boundary positives;
mapping-key safe-load stack exhaustion;
linear JSON depth and harmless malformed-wrapper isolation; isolated regression Git
configuration; report byte limits; carriage returns in Scope; inline-code
credentials; bounded rendered Markdown normalization; declaration,
processing-instruction, and CDATA finding controls; visible URI and email
autolinks; duplicate subject and checkpoint options; and indented long-marker
YAML fences. Exhausted-round blocked-state positives and malformed transition
negatives plus instrumented unmatched-autolink linearity are covered.

## Validator scope

The validator checks:

- the expected commit/tree, sole clean root, committed validator bytes,
  cleanliness, index concealment flags, object integrity, and whitespace;
- exclusion of the known steering path and blob from every reachable candidate
  object, plus the steering SHA-256 when the ignored local file is present;
- all required paths, regular-file modes, tuple-bound launcher/source modes,
  committed hashes, canonical executing paths, and worktree bytes;
- depth-bounded, alias-, anchor-, merge-, semantic-key-, and duplicate-key-free
  strict YAML plus exact state/queue invariants;
- the complete ordered 1,486-requirement manifest, externally and
  validator-bound digest of every normative row, exact P00 lifecycle digest,
  row shape, bounded phase ownership, and enforced user/FOSS/Amazon wording;
- ADR index/file/status agreement;
- exact P00 material identities and canonical digest plus state, provider,
  quarantine, rejection, and admission invariants;
- exact FOSS validator-tool identity, pre-Ruby environment sanitization,
  invocation by attested path, approved license expressions, ambient host
  boundary, and negative supply-chain attestations;
- explicit Apache-2.0 path coverage for every current tracked/archive path;
- parsed, repeatedly decoded, dot-segment-normalized, alternate-host Amazon
  endpoints, overlapping URL starts, repository organizations, SCP identities,
  package coordinates, and string-only depth-bounded structured provider
  metadata, plus an exact approved repository-owner set;
- text-only P00 blobs, tracked Home Assistant storage/registries, sensitive
  filenames, private-key variants, raw/folded credential assignments,
  repeatedly decoded and Markdown-visible assignments, valid indented or
  attributed Markdown YAML fences with LF, CRLF, or CR line endings,
  single-pass bounded embedded JSON credential/residential fields,
  whole-block scalar-exact fixture exemptions, recursive bounded YAML/JSON
  strings, duplicate JSON keys, direct tracked-worktree byte equality, and
  metadata-first bounded checkpoint report bytes;
- PAX-aware isolated source-archive equality with the tracked tree and steering
  exclusion, independent of repository-local attributes.

Rust formatting, Clippy, build, and test commands are not applicable to P00
because no Cargo workspace or runtime code exists. Rust 1.98.0 installation and
verification is the first P01 environment task.

## User-Directed Closeout

The active regression run passed all 492 cases on 2026-08-27. Candidate
`93c2c1e493397c609b0554b54c79b92a15b3c7b8`, tree
`30917ab7c60a678527673e6c84e1b6b74106815f`, then passed exact governance
validation over 1486 requirements. At the user's explicit direction, the
remaining independent P00 review stage was waived and P00 advanced to P01.
