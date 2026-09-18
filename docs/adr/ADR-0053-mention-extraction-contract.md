# ADR-0053: Mention-extraction contract (Step 4)

- Status: `PROPOSED_NOT_ACCEPTED`
- Date: 2026-09-18
- Supplements: ADR-0051 (resolution), ADR-0052 (activation plan, Steps 4-6)
- Scope: normative contract only. No corpus files, no product code, no
  baseline, no freeze is created by this ADR. Implementation (corpus, oracle,
  freeze) follows only after acceptance, under the same preparation
  discipline as ADR-0051.

## 1. Extraction model

Extraction maps one utterance plus one ER snapshot reference into zero or
more operation segments with anchored mentions, or into nothing. It performs
no matching, no ranking, and no disambiguation: every admissible reading of
the text is emitted with its evidence, and resolution downstream decides.

Output record (`MentionExtraction`):

- `text`: original UTF-8 utterance, preserved byte-identically.
- `catalog_id`, `generation`: the snapshot the extraction was derived
  against. Extraction never invents snapshot content.
- `operation_segments`: 1..4 segments in spoken order. Each segment carries
  `verb_text` plus `verb_span` (the raw action starter as written, e.g.
  `apague`; action-enum mapping stays parser-side) and 1..4 mentions.
  Total mentions per request: at most 16.
- Each mention: `id` (0-based, unique per request), `text` (exact substring
  of `text`), `span` (half-open UTF-8 byte offsets with `slice == text`;
  never empty, never reversed, never out of range, never mid-character),
  optional `inherits`, `constraints` (possibly empty), and `unlinked`
  (possibly empty, see section 4).
- Each constraint: `type` (`area`, `domain`, `capability`), `value` (an ID
  present in the snapshot, never guessed), and `evidence`:
  - `mention_subspan`: the value is read off the mention's own span;
    carries `span`, which must lie inside the mention span and decode to
    the cited substring;
  - `inherited`: the value comes from another mention; carries
    `from_mention` (a valid sibling id). The referenced span lives in the
    sibling, never fabricated locally.

Bounds: text 1..2048 bytes / at most 512 chars / no control characters;
mention 1..255 bytes; segments at most 4; mentions per segment at most 4;
total mentions at most 16; spans are byte offsets into the original text.

## 2. Ellipsis without invented spans

Coordinated ellipsis (`X da sala e do quarto`) shares a noun across clauses.
The extractor must not reconstruct phantom strings such as `luz do quarto`
and must not assign them spans. Instead it separates three things:

- textual mention: exactly what is written (`do quarto`, span `[23,32]`);
- inherited context: the shared noun with its real span in the donor
  mention (`luz`, span `[9,12]`, `from_mention: 0`, `via: coordination`);
- constraint evidences: each typed value cites where it was read
  (`area_quarto` from subspan `[26,32]`).

Worked example, `Acenda a luz da sala e do quarto.` (33 bytes; offsets
machine-checked, slices equal the cited strings):

- mention 0: `text` = `luz da sala`, `span` = `[9,20]`; constraint
  `area=area_sala` with evidence
  `{kind: mention_subspan, span: [16,20]}` (`sala`);
- mention 1: `text` = `do quarto`, `span` = `[23,32]`;
  `inherits` = `{noun: luz, noun_span: [9,12], from_mention: 0,
  via: coordination}`; constraint `area=area_quarto` with evidence
  `{kind: mention_subspan, span: [26,32]}` (`quarto`).

Downstream use is layered, never string reconstruction: the Step 6 parser
feeds mention 1's area clause plus the inherited noun into the existing area
grammar (the same mechanism that resolves `luzes da sala e do quarto`
today); the single-mention resolver is called only for self-contained
mentions whose own text carries the full evidence (e.g. `abajur do quarto`).
No layer concatenates inherited nouns into new spans.

## 3. Native snapshot source rule

Extraction fixtures use the native ER snapshot shape (`registry_id`,
`entity_id`, `domain`, `area_id`, `display_name`, `aliases`,
`capabilities`, `generation`) with explicit synthetic provenance
(`PROJECT_AUTHORED_SYNTHETIC`, Apache-2.0). Reconstructing
display/aliases by splitting MLP `names` is forbidden wherever that
provenance does not exist, because the split is lossy and arbitrary
(sorting, article handling, and the display-vs-alias boundary cannot be
recovered). Where an MLP catalog is the only source, translation must go
through the Step 2 snapshot rule (normative display fallback order,
aliases exactly `entry.aliases`) and the translation itself is frozen as
a fixture input, never recomputed silently. The frozen fixture generation
is `gen-001`; real generations follow the SHA-256 lifecycle and are never
hardcoded in product paths.

## 4. Independent corpus (extraction now, v2 interpretation later)

The future corpus is independent from product output and serves both the
extraction gate and, later, v2 interpretation inputs. Required dimensions:

- acceptance: single self-contained mentions with exact spans and
  subspan constraint evidence;
- ellipsis: 2..4 coordinated area clauses sharing one noun, each with
  inherited context and local subspan evidence; multi-area chains;
- ambiguity preservation: two same-noun mentions in different areas are
  both emitted with their own spans; extraction never merges, ranks, or
  drops readings;
- partial-extraction rejection (atomicity): any structurally invalid
  clause (bad span, mention not a substring, over-limit counts, dangling
  `from_mention`) yields no extraction output at all, never a partial
  mention list;
- three-state constraints (security correction): every potential
  restriction is exactly one of absent (the user supplied no restriction),
  valid (identified and linked to a snapshot ID with verifiable evidence),
  or mentioned-but-unlinked (explicitly written but absent from the
  snapshot, emitted as `unlinked: [{kind, text, span}]` on the mention).
  Mentioned-but-unlinked poisons resolution: a mention carrying any
  `unlinked` entry is unresolvable, and plan atomicity propagates that to
  no plan. Constraint absence must never stand in for an interpretation
  failure: an explicitly mentioned `da copa` with no matching area yields
  `unlinked`, not an empty constraint list, so an alias or entity_id tier
  cannot resolve an entity from another environment past the unknown area.
  Precedence semantics are preserved wherever no contradiction or unlinked
  entry exists;
- multiple operations: `apague X e ligue Y` splits into two segments with
  correctly anchored verb spans and mentions; segment order preserved;
  more than four segments is rejected whole;
- UTF-8: multi-byte mentions with byte-exact spans (e.g. `lâmpada da
  sala` at `[8,24]` in `Ligue a lâmpada da sala.`, 25 bytes for 24
  chars), boundary-split and reversed-span rejections;
- malformed and bounds: empty mentions, over-limit texts/mentions/counts,
  control characters, all rejected whole;
- unlinked negatives (dedicated): alias plus unknown area, entity_id plus
  unknown area, unknown area alone, and unknown area in a later operation
  position must all yield no plan while precedence without contradiction
  still resolves.

## 5. How Step 5 compares without comparing incompatible structures

Resolver outcomes (`registry_id`s with evidence) and v1 plans (ordered
operations with target lists) share no structure, so Step 5 compares at
the target-set level only:

- universe comparison: the set of resolved `registry_id`s versus the set
  of all v1 plan targets across operations (order- and segment-insensitive);
- divergence taxonomy: equal sets; resolver subset/superset with direction
  recorded; `resolved`-where-v1-`ambiguous`/`no_match` (investigate);
  v1-target-without-resolver-counterpart (investigate, usually extraction
  coverage); action or ordering differences are explicitly out of scope
  (the resolver has no actions) and belong to the v1 parser domain;
- v1 `ambiguous`/`no_match` rows require no resolver `resolved`
  counterpart; any such counterpart is a mismatch, not a discovery.

## 6. JSON examples

Input (utterance plus snapshot reference; snapshot content travels with
Step 2/3 payloads and is elided here):

```json
{"text": "Acenda o abajur do quarto.", "catalog_id": "fixture-er-v1", "generation": "gen-001"}
```

Success output (single self-contained mention):

```json
{"text": "Acenda o abajur do quarto.", "catalog_id": "fixture-er-v1", "generation": "gen-001",
 "operation_segments": [{"verb_text": "Acenda", "verb_span": [0, 6], "mentions": [
   {"id": 0, "text": "abajur do quarto", "span": [9, 25],
    "constraints": [{"type": "area", "value": "area_quarto", "evidence": {"kind": "mention_subspan", "span": [19, 25]}}]}]}]}
```

Ellipsis output: the two mentions of section 2, with `inherits` on the
second and no fabricated spans anywhere.

Rejection output (structurally invalid input, e.g. a mention that is not a
substring, or five operation segments): no segments are published:

```json
{"text": "Acenda a luz da sala e do quarto e da cozinha e do banheiro e da varanda.",
 "catalog_id": "fixture-er-v1", "generation": "gen-001", "operation_segments": []}
```

An empty segment list is the only failure encoding; partial lists are
forbidden.

## 7. Acceptance criteria and rollback

Acceptance: frozen spec, deterministic generator, independent oracle, and
freeze under `evaluation/ptbr-independent/mention-extraction/`, following
the ADR-0051 discipline; oracle validates every row (span byte-validity,
mention equality, subspan containment, valid inheritance references,
snapshot-ID admissibility, unlinked span validity with three-state
consistency, bounds); `freeze --check` passes; gold labels
authored before any product use and never rewritten from product output;
no product code, no protocol change, no baseline change. Rollback: the
artifacts are inert without callers; remove the package directory.

## 8. Open product decisions

1. Segment-verb vocabulary: the starter list for segmentation (reuse the
   parser's effect starters or freeze an independent list).
2. Residential utterances for Step 5 replay: fixtures-only or approved
   ephemeral processing.
3. Whether ellipsis beyond coordinated areas (e.g. shared verbs with
   mixed nouns) belongs to extraction or stays parser-side.
