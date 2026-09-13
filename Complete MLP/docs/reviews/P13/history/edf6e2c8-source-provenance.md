# P13 Historical Source Provenance Review

- Role: `source-provenance`
- Subject commit: `edf6e2c888c841c423f42a19c110072f3b6f7ec7`
- Subject tree: `b71a4ba735aaaea6e12a349d0e55c8f9c8a3d652`
- Archive SHA-256:
  `1d0de0722ef7fb838c2c86029746e0027e7f5dc4a105be3558df30f266771afa`
- Mode: independent read-only review of the frozen subject
- Report status: historical report only
- Verdict: `FAIL`

## Scope

The review inspected only the frozen Git object, an isolated extraction of its
Git archive, and the exact hash-matched Rust source artifacts named by that
subject. It traced the selected compiler/Clippy path-source inventory, origin
witness vocabulary and digest, witness rejection behavior, source
dispositions, and the user-decision governance relation.

No current-worktree conclusion, network, sibling repository, Amazon or
internal material, Sophia or another closed engine, generated language, or
linguistic oracle was used. This report is not part of the reviewed subject.

## Identity And Baseline Checks

The following commands reproduced the subject:

```text
git rev-parse \
  edf6e2c888c841c423f42a19c110072f3b6f7ec7^{commit}
git show -s --format='%T' \
  edf6e2c888c841c423f42a19c110072f3b6f7ec7
git archive --format=tar \
  edf6e2c888c841c423f42a19c110072f3b6f7ec7 |
  shasum -a 256
git fsck --full --no-dangling
git diff --check \
  edf6e2c888c841c423f42a19c110072f3b6f7ec7^ \
  edf6e2c888c841c423f42a19c110072f3b6f7ec7
```

They produced the commit, tree, and archive hash above. `git fsck` and
`git diff --check` emitted no output. These syntax checks all returned
`Syntax OK`:

```text
ruby --disable-gems -c tools/p13-noise-evidence.rb
ruby --disable-gems -c tools/validate-governance.rb
ruby --disable-gems -c tools/test-p13-noise-evidence.rb
ruby --disable-gems -c tools/test-validate-governance.rb
```

The local primary artifacts reproduced the frozen identities:

```text
channel-rust-1.98.0.toml
bytes: 898637
sha256: 3f7d139b73bbbd0004ef6e58b430831c68cdad2b1f64ee2eb35d54c09199489a

rustc-1.98.0-src.tar.xz
bytes: 244440040
sha256: 271fa73d8174f53d713c46a8310da7bf7cfdcfb8b7cfd1c2b74b84a83ae9fb1e
```

`tools/p13-noise-evidence --skip-runtime` was also attempted in the isolated
Git-archive extraction. It stopped before source scanning with:

```text
P13_NOISE_EVIDENCE_FAIL: P13 complete Rust notice missing:
.../subject/.tools/rust-1.98.0/share/doc/rust/COPYRIGHT.html
```

The ignored local `.tools` installation is necessarily absent from a Git
archive. This isolated-export prerequisite failure is not classified as a
candidate finding, and this review does not claim the aggregate gate passed.

## Reproduced Origin Omission

ADR-0032 requires every bounded origin witness in the selected compiler and
Clippy roots to be hash-bound and dispositioned. ADR-0033 requires origin
discovery across every line. ADR-0034 specifically requires complete
reproduced current origin coverage.

The exact selected Rust archive member was extracted with:

```text
/usr/bin/tar -xOf \
  /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz \
  rustc-1.98.0-src/compiler/rustc_codegen_cranelift/src/debuginfo/emit.rs
```

It is 8,636 bytes with SHA-256
`2ba6e45e97cc8a963d0311dd487736d56c8069070a2f66d3661ff9e2d0547e33`.
Lines 188-191 contain:

```text
fn write_eh_pointer(&mut self, address: Address, eh_pe: gimli::DwEhPe, size: u8) -> Result<()> {
    match address {
        // Address::Constant arm copied from gimli
        Address::Constant(val) => {
```

The frozen scanner at `tools/p13-noise-evidence.rb:594` does not recognize
that concrete copied-source form. Its general multiline
`adapted|borrowed|copied|derived|extracted|taken` branch is also anchored to
`\A`, so equivalent non-first-line `Derived` and `Adapted` statements are
missed.

The focused command loaded the frozen scanner, called
`rust_registry_content_witness_rows` on the exact member and on the displayed
`FIXTURE_TECNICA` byte strings, and retained only `ORIGIN_*` rows. Exact
results:

```text
REAL_GIMLI=[]
NONFIRST_DERIVED=[]
NONFIRST_WRAPPED_ADAPTED=[]
```

The latter inputs were:

```text
FIXTURE_TECNICA_PRELUDE
// Derived from OpenBSD.
```

and:

```text
FIXTURE_TECNICA_PRELUDE
//! Adapted from
//! [styled_buffer]
```

As a positive control, `// Copied from OpenBSD.\n` returned:

```text
STANDALONE_OPENBSD=[[1, "ORIGIN_DERIVED_OR_COPIED"]]
```

The scanner therefore ran and can detect a nearby supported form. The frozen
ledger at `docs/evidence/P13-NOISE-SOURCES.yaml:22967` records 115 witnesses
in 96 compiler/Clippy files, but contains no disposition for
`compiler/rustc_codegen_cranelift/src/debuginfo/emit.rs`.

## Rejection-Scope Counterexample

`rust_origin_witness_rejected?` at
`tools/p13-noise-evidence.rb:3736-3750` starts a 1,024-byte, up-to-16-line
window at a match and applies technical-noise rejection to that entire
normalized tail. Unrelated later prose can therefore suppress an earlier
genuine source-origin statement.

The same focused scanner command returned:

```text
STANDALONE_OPENBSD=[[1, "ORIGIN_DERIVED_OR_COPIED"]]
OPENBSD_THEN_TECHNICAL=[]
```

The second input differed only by the following later line:

```text
/// pointer derived from it. Use as_mut_ptr to mutate it.
```

The line is an intended technical-noise negative when scanned alone, but it is
not part of the preceding sentence. Its presence erases the valid OpenBSD
origin witness and consequently removes that file from the exact disposition
set.

## Vocabulary-Digest Counterexample

`rust_registry_content_vocabulary_sha256` at
`tools/p13-noise-evidence.rb:3618-3629` binds each positive regex's source and
options, but binds only `.source` for each rejection regex. The review replaced
the `ORIGIN_BASED_OR_INSPIRED` rejection regex in memory with a regex having
the identical source and no `IGNORECASE` option, then rescanned
`// Based on whether the queue is empty.\n`.

Exact result:

```text
REJECTION_SOURCE_EQUAL=true
REJECTION_OPTIONS=1->0
BASELINE_DIGEST=36a731c8a33eb520a9297697c15a5df1a05c8f4e8d244e68813c40da903a1f13
CHANGED_DIGEST=36a731c8a33eb520a9297697c15a5df1a05c8f4e8d244e68813c40da903a1f13
DIGEST_EQUAL=true
BASELINE_CONTROL_ROWS=[]
CHANGED_CONTROL_ROWS=[[1, "ORIGIN_BASED_OR_INSPIRED"]]
```

Thus the evidence's vocabulary hash can remain unchanged while the exact
source-origin classification behavior changes.

## Governance Counterexample

The normative decision relation controls which post-budget source correction
is authorized. ADR-0033 requires every `USR-*` decision row to have an ordered
traceability and manifest row. ADR-0034 requires whitespace-tolerant decision
discovery and malformed candidate-ID rejection.

Both frozen parsers first call `markdown_table_columns`, which requires the
first byte to be `|` and the final byte before newline to be `|`
(`tools/validate-governance.rb:933-938` and
`tools/p13-noise-evidence.rb:1674-1678`). Their candidate-ID prefilter also
silently skips `` `USR_038` `` rather than rejecting it.

The review appended each of these five-column rows to the frozen
`USER-DECISIONS.md` bytes:

```text
 | `USR-038` | FIXTURE_TECNICA | MUST | P13 | FIXTURE_TECNICA |
| `USR-038` | FIXTURE_TECNICA | MUST | P13 | FIXTURE_TECNICA |<SPACE>
| `USR_038` | FIXTURE_TECNICA | MUST | P13 | FIXTURE_TECNICA |
```

`<SPACE>` denotes one literal trailing U+0020 byte in the exercised input; it
is not part of the stored report line.

It called `GovernanceValidator#user_decision_ids_from_bytes`,
`P13NoiseEvidence.user_requirement_ids`, and the complete
`validate_user_decision_traceability_bytes` relation against the unchanged
traceability and manifest. Exact results:

```text
BASELINE_GOVERNANCE_LAST=USR-037;COUNT=37
BASELINE_P13_LAST=USR-037;COUNT=37
LEADING_SPACE_GOVERNANCE_UNCHANGED=true
LEADING_SPACE_P13_UNCHANGED=true
LEADING_SPACE_P13_TRACE_RESULT=true
TRAILING_SPACE_GOVERNANCE_UNCHANGED=true
TRAILING_SPACE_P13_UNCHANGED=true
TRAILING_SPACE_P13_TRACE_RESULT=true
MALFORMED_UNDERSCORE_GOVERNANCE_UNCHANGED=true
MALFORMED_UNDERSCORE_P13_UNCHANGED=true
MALFORMED_UNDERSCORE_P13_TRACE_RESULT=true
```

The positive control returned the exact ordered `USR-001..USR-037` set from
both parsers. The mutations show that a new or malformed source-correction
authority can remain outside the enforced provenance relation without making
either gate fail.

## Findings

- P0: none.
- P1: none.
- P2: the selected compiler/Clippy source-origin inventory is incomplete. It
  omits a concrete `copied from gimli` statement in an exact selected archive
  member and reproducibly misses non-first-line `Derived` and wrapped
  `Adapted` forms, contrary to ADR-0032 through ADR-0034.
- P2: origin rejection is scoped to unrelated later lines rather than the
  matched statement, allowing genuine origin evidence to disappear from the
  mandatory disposition inventory.
- P2: the recorded vocabulary digest omits rejection-regex options, so
  classification semantics can change without changing the hash asserted by
  `P13-NOISE-SOURCES.yaml`.
- P2: both governance parsers silently omit leading-space, trailing-space, and
  malformed-underscore decision rows; the complete P13 trace relation accepts
  those omissions, leaving source-correction authority unbound.
- P3: none.

FAIL
