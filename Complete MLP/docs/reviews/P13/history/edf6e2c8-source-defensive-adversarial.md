# P13 Historical Defensive Adversarial Source Review

- Role: `source-defensive-adversarial`
- Review instance: `retrospective-executor-edf6e2c8-defensive`
- Subject commit: `edf6e2c888c841c423f42a19c110072f3b6f7ec7`
- Subject tree: `b71a4ba735aaaea6e12a349d0e55c8f9c8a3d652`
- Archive SHA-256: `1d0de0722ef7fb838c2c86029746e0027e7f5dc4a105be3558df30f266771afa`
- Mode: independent retrospective, offline primary-evidence inspection
- Verdict: `FAIL`

## Scope And Isolation

The reviewer extracted only the immutable subject with `git archive` into an
isolated temporary directory and ran every repository probe from that
directory. The live worktree and its conclusions were not used. The only
out-of-tree input inspected was the exact local Rust source archive named and
hashed by the subject's `docs/evidence/P13-NOISE-SOURCES.yaml`. No network,
sibling repository, Amazon or internal material, Sophia material, or current
remediation was used.

Commands and results:

```text
git show --no-patch --format='%H%n%T%n%P%n%s' \
  edf6e2c888c841c423f42a19c110072f3b6f7ec7
edf6e2c888c841c423f42a19c110072f3b6f7ec7
b71a4ba735aaaea6e12a349d0e55c8f9c8a3d652
240f64b26af530aadf5353ab973ceab99e265bc4
p13: close bounded source review findings

git archive --format=tar \
  edf6e2c888c841c423f42a19c110072f3b6f7ec7 | shasum -a 256
1d0de0722ef7fb838c2c86029746e0027e7f5dc4a105be3558df30f266771afa  -

shasum -a 256 \
  /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz \
  /private/tmp/p13-rust-source/channel-rust-1.98.0.toml
271fa73d8174f53d713c46a8310da7bf7cfdcfb8b7cfd1c2b74b84a83ae9fb1e  /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz
3f7d139b73bbbd0004ef6e58b430831c68cdad2b1f64ee2eb35d54c09199489a  /private/tmp/p13-rust-source/channel-rust-1.98.0.toml

ruby --disable-gems -c tools/p13-noise-evidence.rb
Syntax OK
ruby --disable-gems -c tools/validate-governance.rb
Syntax OK
```

## P2: Decision Rows Can Evade Both Parsers

`tools/p13-noise-evidence.rb:1656-1678` and
`tools/validate-governance.rb:916-937` first require a line to start and end
with `|`, then apply a narrow `USR(?:-|\b)` recognition gate. A row with
leading whitespace, trailing whitespace, or a malformed identifier such as
`USR_038` is skipped rather than rejected. The later set and contiguity checks
therefore see the unchanged 37-row ledger.

The focused probe appended each adversarial row to the subject's real decision
ledger, then invoked both production parsers. It also supplied a recognized
bad-shape control:

```text
ruby --disable-gems -Itools - <<'RUBY'
require File.expand_path("tools/p13-noise-evidence", Dir.pwd)
require File.expand_path("tools/validate-governance", Dir.pwd)
decisions = File.binread("docs/clean-room/USER-DECISIONS.md")
trace = File.binread("docs/evidence/REQUIREMENTS-TRACEABILITY.md")
manifest = P13NoiseEvidence.read_yaml(
  "docs/evidence/REQUIREMENTS-MANIFEST.yaml"
)
rows = {
  "leading_space" =>
    "  | `USR-038` | FIXTURE_TECNICA | MUST | P13 | consequence |\n",
  "trailing_space" =>
    "| `USR-038` | FIXTURE_TECNICA | MUST | P13 | consequence |  \n",
  "underscore_id" =>
    "| `USR_038` | FIXTURE_TECNICA | MUST | P13 | consequence |\n"
}
rows.each do |name, row|
  changed = decisions + row
  accepted = P13NoiseEvidence.validate_user_decision_traceability_bytes(
    changed, trace, manifest
  )
  ids = GovernanceValidator.allocate.send(
    :user_decision_ids_from_bytes, changed
  )
  puts "#{name} p13_accepted=#{accepted} " \
    "governance_count=#{ids.length} governance_last=#{ids.last}"
end
bad = decisions + "| `USR-038` | only-two-columns |\n"
begin
  P13NoiseEvidence.validate_user_decision_traceability_bytes(
    bad, trace, manifest
  )
rescue => error
  puts "recognized_bad_shape p13_error=#{error.message.inspect}"
end
begin
  GovernanceValidator.allocate.send(:user_decision_ids_from_bytes, bad)
rescue => error
  puts "recognized_bad_shape governance_error=#{error.message.inspect}"
end
RUBY
leading_space p13_accepted=true governance_count=37 governance_last=USR-037
trailing_space p13_accepted=true governance_count=37 governance_last=USR-037
underscore_id p13_accepted=true governance_count=37 governance_last=USR-037
recognized_bad_shape p13_error="P13 user decision ledger contains malformed ID row"
recognized_bad_shape governance_error="malformed user decision row"
```

The control proves malformed rows are rejected only after entering the narrow
recognition path. This is a false acceptance in both governance authorities.

## P2: Origin Discovery Has Reproducible False Negatives

The generic wrapped derived/copied branch at
`tools/p13-noise-evidence.rb:594` is anchored to `\A`, while the specialized
non-first-line branches cover only narrower copied forms. It misses
non-first-line wrapped `Derived` and `Adapted` statements and the real
Rust-arm attribution.

Synthetic controls and counterexamples against
`P13NoiseEvidence.rust_registry_content_witness_rows` produced:

```text
control_terse origin_count=1 coordinates=[[1, "ORIGIN_DERIVED_OR_COPIED"]]
nonfirst_wrapped_derived origin_count=0 coordinates=[]
nonfirst_wrapped_adapted origin_count=0 coordinates=[]
nonfirst_rust_arm_origin origin_count=0 coordinates=[]
control_then_later_noise origin_count=0 coordinates=[]
technical_copy origin_count=0 coordinates=[]
technical_based origin_count=0 coordinates=[]
```

The inputs, in order, were:

```text
// Copied from OpenBSD.

FIXTURE_TECNICA_PRELUDE
// Derived
// from OpenBSD.

FIXTURE_TECNICA_PRELUDE
//! Adapted from
//! [styled_buffer]

FIXTURE_TECNICA_PRELUDE
// Address::Constant arm copied from gimli

// Copied from OpenBSD.
// pointer derived from it.

/// copied from src to dst when a mask bit is not set.

// Based on whether the queue is empty.
```

The positive terse control and both negative technical controls show that the
counterexample is not a universally enabled or disabled scanner. The exact
pinned Rust archive independently contains the missed attribution:

```text
/usr/bin/bsdtar -xJOf \
  /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz \
  rustc-1.98.0-src/compiler/rustc_codegen_cranelift/src/debuginfo/emit.rs |
  nl -ba | sed -n '187,193p'
   187
   188	    fn write_eh_pointer(&mut self, address: Address, eh_pe: gimli::DwEhPe, size: u8) -> Result<()> {
   189	        match address {
   190	            // Address::Constant arm copied from gimli
   191	            Address::Constant(val) => {
   192	                // Indirect doesn't matter here.
   193	                let val = match eh_pe.application() {
```

Scanning all 8,636 bytes of that exact member gave:

```text
bytes=8636
sha256=2ba6e45e97cc8a963d0311dd487736d56c8069070a2f66d3661ff9e2d0547e33
origin_count=0
```

This leaves an actual external-source attribution absent from the committed
path-source witness closure.

## P2: Rejection Scope Can Suppress An Earlier Valid Witness

`tools/p13-noise-evidence.rb:3736-3750` applies each rejection regex to as
many as 1,024 bytes and 16 normalized lines beginning at a match. Consequently,
the valid first line `Copied from OpenBSD.` was found when alone but disappeared
when followed by the unrelated technical line `pointer derived from it`, as
shown by the preceding probe. A rejection intended for the later line can
therefore suppress a genuine earlier origin witness. Reversing or removing the
later line restores the witness, so this is specifically an over-wide
rejection window rather than failure of the positive OpenBSD rule.

## P2: The Vocabulary Digest Omits Rejection-Regexp Options

`tools/p13-noise-evidence.rb:3618-3627` binds each positive regex's source and
options, but binds only each rejection regex's source. The reviewer replaced
the case-insensitive `ORIGIN_BASED_OR_INSPIRED` rejection with the same source
and no `IGNORECASE` option in memory, then rescanned the mixed-case technical
control:

```text
before_digest=36a731c8a33eb520a9297697c15a5df1a05c8f4e8d244e68813c40da903a1f13
after_digest=36a731c8a33eb520a9297697c15a5df1a05c8f4e8d244e68813c40da903a1f13
digest_equal=true
before_origin_count=0 after_origin_count=1
before_options=1 after_options=0
```

The semantic classifier changed while its committed vocabulary identity did
not. This breaks the audit binding for origin-witness evidence.

## P2: Extraction Is Unbounded And Process-Group Containment Is Escapable

The two archive extraction paths use unbounded `Open3.capture3` directly:

```text
grep -n 'Open3.capture3' tools/p13-noise-evidence.rb
2100:      stdout, stderr, status = Open3.capture3(
3533:      stdout, stderr, status = Open3.capture3(
8018:    stdout, stderr, status = Open3.capture3(env, *arguments, options)
```

At `tools/p13-noise-evidence.rb:2100-2118` and `:3533-3551`, there is no
deadline and no stdout or stderr byte cap. Output is tested for emptiness only
after `capture3` has buffered it and the child has exited. A direct API control
confirmed full buffering:

```text
status=true stdout_bytes=8388608 stderr_bytes=0 elapsed_seconds=0.023
```

The separate bounded helper at `tools/p13-noise-evidence.rb:3287-3424` is used
for archive listing, not either extraction. It creates a process group and
kills `-pid`. A same-group fork control was terminated promptly:

```text
error_class=P13NoiseEvidence::Failure
error="FIXTURE_TECNICA same-group descendant stdout is excessive"
elapsed_seconds=0.117
```

The adversarial child then forked, called `Process.setsid`, reported its PID
through a separately inherited pipe, slept for a finite 1.2 seconds, and had
the direct child exceed the 64-byte stdout limit. A monitor checked the escaped
PID 0.5 seconds after the direct process group had been killed:

```text
error_class=P13NoiseEvidence::Failure
error="FIXTURE_TECNICA escaped descendant stdout is excessive"
escaped_pid_reported=true alive_after_group_kill=true
elapsed_seconds=1.224
```

The escaped child self-terminated; the probe did not signal a reported PID.
This control/counterexample pair proves that ordinary descendants are covered
but a `setsid` descendant survives the helper's process-group kill and keeps
inherited descriptors open. The direct extraction calls have neither this
partial containment nor bounded output/deadlines.

## P2: Protected YAML Candidate Extraction Is Quadratic

For every protected mapping, `tools/validate-governance.rb:3748-3997` scans
backward and forward across sibling mappings and materializes the resulting
block. `parsed_yaml_payloads` appends every block at `:4154-4190` and deduplicates
only later at `:4209`, after the repeated full-size strings exist.

The production `protected_yaml_blocks` method was called with repeated rows
whose key was assembled from `"pro" + "vider"`, and with that same protected
key:

```text
ruby --disable-gems -Itools - <<'RUBY'
require File.expand_path("tools/validate-governance", Dir.pwd)
validator = GovernanceValidator.allocate
key = "pro" + "vider"
keys = Set.new([key])
[64, 128, 256, 512].each do |rows|
  content = "#{key}: x\n" * rows
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  blocks = validator.send(
    :protected_yaml_blocks,
    content,
    keys,
    markdown_containers: false,
    include_node_properties: false
  )
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  bytes = blocks.sum(&:bytesize)
  puts "rows=#{rows} input_bytes=#{content.bytesize} " \
    "blocks=#{blocks.length} block_bytes=#{bytes} " \
    "ratio=#{bytes / content.bytesize} " \
    "elapsed_ms=#{format('%.3f', elapsed * 1000)}"
end
control = "fixture: x\n" * 512
blocks = validator.send(
  :protected_yaml_blocks,
  control,
  keys,
  markdown_containers: false,
  include_node_properties: false
)
puts "unprotected_control_rows=512 blocks=#{blocks.length} " \
  "block_bytes=#{blocks.sum(&:bytesize)}"
RUBY
rows=64 input_bytes=768 blocks=64 block_bytes=49152 ratio=64 elapsed_ms=8.128
rows=128 input_bytes=1536 blocks=128 block_bytes=196608 ratio=128 elapsed_ms=24.700
rows=256 input_bytes=3072 blocks=256 block_bytes=786432 ratio=256 elapsed_ms=78.958
rows=512 input_bytes=6144 blocks=512 block_bytes=3145728 ratio=512 elapsed_ms=286.801
unprotected_control_rows=512 blocks=0 block_bytes=0
```

Each doubling quadrupled materialized candidate bytes. The unprotected control
produced no blocks, confirming a protected-YAML amplification path rather than
constant harness overhead. A small committed Markdown payload can therefore
force quadratic work and allocation in the governance validator.

## Findings

P0: none.

P1: none.

P2:

- Leading/trailing row whitespace and malformed `USR_038` identifiers evade
  both decision-row parsers instead of failing closed.
- Wrapped and non-first-line origin statements, including an attribution in
  the exact admitted Rust archive, are absent from the origin inventory.
- Unrelated later technical prose can suppress a genuine earlier origin
  witness.
- Rejection-regexp options affect classification but are omitted from the
  vocabulary digest.
- Archive extraction has no output or time bound, and the available
  process-group termination can be escaped with `setsid`.
- Protected YAML candidate extraction materializes quadratic data before
  deduplication.

P3: none.

FAIL
