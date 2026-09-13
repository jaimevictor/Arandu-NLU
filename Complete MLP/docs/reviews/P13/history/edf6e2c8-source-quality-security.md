# P13 Historical Source Quality And Security Review

- Role: `source-quality-security`
- Review date: `2026-08-31`
- Subject commit: `edf6e2c888c841c423f42a19c110072f3b6f7ec7`
- Subject tree: `b71a4ba735aaaea6e12a349d0e55c8f9c8a3d652`
- Subject archive SHA-256:
  `1d0de0722ef7fb838c2c86029746e0027e7f5dc4a105be3558df30f266771afa`
- Mode: independent, offline, read-only frozen-subject review

This report records only the immutable subject above. Inspection and probes
used a `git archive` export in `/tmp`; no conclusion was taken from the current
worktree. The reviewer did not use network access, Amazon/internal material,
sibling repositories, Sophia or another closed engine, or unprovenanced
linguistic material. The only repository write is this retrospective report.

## Scope

The review inspected these primary frozen paths:

- `tools/p13-noise-evidence.rb`
- `tools/test-p13-noise-evidence.rb`
- `tools/validate-governance.rb`
- `tools/test-validate-governance.rb`

It targeted child-output bounds, both Rust archive extraction paths,
process-group containment, and YAML candidate amplification. This is
historical evidence for the failed subject, not a review of a replacement.

## Frozen Identity

Commands:

```sh
git rev-parse \
  'edf6e2c888c841c423f42a19c110072f3b6f7ec7^{commit}' \
  'edf6e2c888c841c423f42a19c110072f3b6f7ec7^{tree}'
git archive --format=tar \
  --output=/tmp/p13-edf6e2c8-subject.tar \
  edf6e2c888c841c423f42a19c110072f3b6f7ec7
shasum -a 256 /tmp/p13-edf6e2c8-subject.tar
stat -f '%z' /tmp/p13-edf6e2c8-subject.tar
git diff --check \
  edf6e2c888c841c423f42a19c110072f3b6f7ec7^ \
  edf6e2c888c841c423f42a19c110072f3b6f7ec7
ruby --disable-gems -c tools/p13-noise-evidence.rb
ruby --disable-gems -c tools/validate-governance.rb
```

Results:

- commit and tree matched the identities above;
- archive size was `36771840` bytes;
- archive SHA-256 matched the identity above;
- `git diff --check` emitted no diagnostics; and
- both Ruby syntax checks emitted `Syntax OK`.

## Reproductions

### Unbounded Extraction Output And Wait

The selected-member extraction at
`tools/p13-noise-evidence.rb:2100` and registry-content extraction at
`tools/p13-noise-evidence.rb:3533` call `Open3.capture3` directly. Both first
buffer all stdout and stderr and only then require the buffers to be empty at
lines 2117-2118 and 3550-3551. Neither call has an output limit, deadline, or
process-group containment option.

By contrast, archive listing calls `capture3_bounded` at line 3260. That helper
accepts explicit stdout, stderr, and deadline limits at lines 3287-3295.

The following probe preserved the two frozen extraction methods, stubbed only
their completed preflight and descriptor lookup, and recorded the exact
dispatcher and options selected by each extraction call:

```sh
ruby --disable-gems -Itools -e '
require "./tools/p13-noise-evidence"
class AuditStop < StandardError; end
calls = []
Open3.singleton_class.send(:define_method, :capture3) do |*args, **options|
  calls << [args, options]
  raise AuditStop
end
P13NoiseEvidence.singleton_class.send(
  :define_method, :rust_archive_verbose_entries
) { |*| [{"path"=>"member", "type"=>"file", "bytes"=>1, "target"=>nil}] }
P13NoiseEvidence.singleton_class.send(
  :define_method, :validate_rust_archive_regular_preflight
) { |*| 1 }
P13NoiseEvidence.singleton_class.send(
  :define_method, :rust_archive_descriptor_path
) { |*| "/dev/fd/9" }
record = {
  "extraction_tool"=>{"path"=>"/FIXTURE_TECNICA/bsdtar"},
  "source_archive"=>{"archive_root"=>"root"},
  "selected_members"=>[{"path"=>"member"}]
}
File.open("/dev/null", "rb") do |io|
  handle = {"io"=>io}
  begin
    P13NoiseEvidence.extract_rust_source_members(record, handle)
  rescue AuditStop
  end
  begin
    P13NoiseEvidence.extract_rust_archive_files(
      record, handle, ["member"], "FIXTURE_TECNICA registry"
    )
  rescue AuditStop
  end
end
calls.each_with_index do |(args, options), index|
  controls = %i[stdout_limit stderr_limit deadline_seconds pgroup].select {
    |key| options.key?(key)
  }
  puts(
    "call=#{index + 1} api=Open3.capture3 " \
    "extraction=#{args.include?("-xJf")} " \
    "stdin_data=#{options.key?(:stdin_data)} controls=#{controls.inspect}"
  )
end
'
```

Result:

```text
call=1 api=Open3.capture3 extraction=true stdin_data=false controls=[]
call=2 api=Open3.capture3 extraction=true stdin_data=true controls=[]
```

As a counterexample, the frozen bounded helper was exercised at and one byte
over a 64-byte stdout limit:

```sh
ruby --disable-gems -Itools -e '
require "./tools/p13-noise-evidence"
[64, 65].each do |bytes|
  begin
    out, err, status = P13NoiseEvidence.capture3_bounded(
      {},
      [RbConfig.ruby, "--disable-gems", "-e",
       "STDOUT.write(\"X\" * #{bytes})"],
      {close_others: true},
      stdin_data: nil,
      stdout_limit: 64,
      stderr_limit: 64,
      context: "FIXTURE_TECNICA bounded control",
      deadline_seconds: 2
    )
    puts "bytes=#{bytes} accepted=#{status.success? && out.bytesize == bytes && err.empty?}"
  rescue P13NoiseEvidence::Failure => error
    puts "bytes=#{bytes} rejected=#{error.message}"
  end
end
'
```

Result:

```text
bytes=64 accepted=true
bytes=65 rejected=FIXTURE_TECNICA bounded control stdout is excessive
```

The counterexample confirms that the bounded primitive works for this limit;
the two extraction call sites bypass it. An extractor that emits indefinitely,
emits excessive diagnostics, or never exits can therefore consume unbounded
memory or block the validator indefinitely before the post-capture empty-output
check runs.

### Escaped Descendant

`capture3_bounded` starts only the direct child in a new process group at
`tools/p13-noise-evidence.rb:3304-3308`. On a stream failure its reader thread
kills `-pid` through `terminate_child_process_group` at lines 3323 and
3416-3423. A forked descendant is not the process-group leader and can call
`setsid`, leave that group, and continue after termination.

The probe forked such a descendant. It wrote an initial marker after `setsid`,
waited 300 ms after the direct parent emitted one byte over the output limit,
then appended a second marker:

```sh
ruby --disable-gems -Itools -e '
require "rbconfig"
require "tmpdir"
require "./tools/p13-noise-evidence"
Dir.mktmpdir("p13-setsid-audit-") do |directory|
  marker = File.join(directory, "escaped.marker")
  code = %q{
    marker = ARGV.fetch(0)
    fork do
      Process.setsid
      File.binwrite(
        marker, "started:#{Process.pid}:pgid=#{Process.getpgrp}"
      )
      STDOUT.close
      STDERR.close
      sleep 0.30
      File.open(marker, "ab") { |file| file.write(":after_group_kill") }
      sleep 0.30
    end
    sleep 0.001 until File.exist?(marker)
    STDOUT.write("X" * 65)
    STDOUT.flush
    sleep 30
  }
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  begin
    P13NoiseEvidence.capture3_bounded(
      {},
      [RbConfig.ruby, "--disable-gems", "-e", code, marker],
      {close_others: true},
      stdin_data: nil,
      stdout_limit: 64,
      stderr_limit: 64,
      context: "FIXTURE_TECNICA setsid escape",
      deadline_seconds: 3
    )
  rescue P13NoiseEvidence::Failure => error
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    puts(
      "result=#{error.message.inspect} marker=#{File.binread(marker).inspect} " \
      "seconds=#{format("%.3f", elapsed)}"
    )
  end
end
'
```

Result:

```text
result="FIXTURE_TECNICA setsid escape stdout is excessive" marker="started:96954:pgid=96954:after_group_kill" seconds=0.620
```

The post-termination marker proves that the escaped descendant continued to
run. The process was finite and exited without reviewer signaling.

The counterexample removed only `Process.setsid` while retaining the fork,
marker delay, output violation, and process-group kill. After waiting 500 ms,
the result was:

```text
result="FIXTURE_TECNICA pgroup control stdout is excessive" marker="started:97043:pgid=97042" seconds=0.026
```

The ordinary descendant did not append `:after_group_kill`. Process-group
termination therefore handles descendants that remain in the group but does
not provide the claimed containment against an escaping descendant.

### Quadratic YAML Candidate Amplification

`protected_yaml_blocks` iterates every candidate start at
`tools/validate-governance.rb:3748`, scans backward and forward over sibling
rows at lines 3809-3991, and materializes a joined block for every start at
lines 3992-3996. `parsed_yaml_payloads` deduplicates only afterward at line
4209. There is no YAML block candidate-count or aggregate-candidate-byte bound.

This command supplied repeated protected mappings and measured the candidate
array returned before deduplication:

```sh
ruby --disable-gems -Itools -rbenchmark -e '
require "./tools/validate-governance"
validator = GovernanceValidator.allocate
key = "entity" + "_id"
[128, 256, 512, 1024].each do |rows|
  GC.start
  input = "#{key}: FIXTURE_TECNICA\n" * rows
  candidates = nil
  elapsed = Benchmark.realtime do
    candidates = validator.send(
      :protected_yaml_blocks,
      input,
      GovernanceValidator::PROTECTED_STRUCTURED_KEYS,
      markdown_containers: false,
      include_node_properties: false
    )
  end
  puts(
    "n=#{rows} input_bytes=#{input.bytesize} " \
    "candidates=#{candidates.length} " \
    "candidate_bytes=#{candidates.sum(&:bytesize)} " \
    "unique=#{candidates.uniq.length} " \
    "seconds=#{format("%.6f", elapsed)}"
  )
end
'
```

Results:

```text
n=128 input_bytes=3456 candidates=128 candidate_bytes=442368 unique=1 seconds=0.024061
n=256 input_bytes=6912 candidates=256 candidate_bytes=1769472 unique=1 seconds=0.079219
n=512 input_bytes=13824 candidates=512 candidate_bytes=7077888 unique=1 seconds=0.289022
n=1024 input_bytes=27648 candidates=1024 candidate_bytes=28311552 unique=1 seconds=1.090994
```

Doubling the input rows quadrupled materialized candidate bytes. The
deduplication counterexample produced only one unique block, but only after
all `n` copies of the `n`-row block existed. Thus 27,648 input bytes created
28,311,552 candidate bytes before parsing and deduplication, confirming
quadratic CPU and memory amplification in governance scanning.

## Findings

- P0: none.
- P1: none.
- P2: both Rust archive extraction paths use unbounded `Open3.capture3`, so
  child stdout, stderr, and runtime are unrestricted before validation.
- P2: `capture3_bounded` relies on process-group killing without preventing a
  forked descendant from using `setsid`; the descendant demonstrably continued
  after the triggering output violation and group termination.
- P2: protected YAML extraction materializes quadratic duplicate candidate
  bytes before deduplication and has no aggregate candidate bound, permitting
  deterministic validator resource exhaustion from a small repeated input.
- P3: none.

FAIL
