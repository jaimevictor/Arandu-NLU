# frozen_string_literal: true

require "open3"

module P12Validation
  class Failure < StandardError; end

  ROOT = File.expand_path("..", __dir__)

  SESSION_FILES = %w[
    crates/session-engine/Cargo.toml
    crates/session-engine/src/error.rs
    crates/session-engine/src/id.rs
    crates/session-engine/src/lib.rs
    crates/session-engine/src/store.rs
    crates/session-engine/tests/contract.rs
  ].freeze

  PLAN_ENGINE_SOURCE_FILES = %w[
    conflict
    core_adapter
    error
    internal_contract_tests
    lib
    model
    pattern
    resolution
    table
  ].map { |name| "crates/plan-engine/src/#{name}.rs" }.freeze

  REQUIREMENTS = (
    %w[
      GLB-SESSION-001
      GLB-SESSION-002
      GLB-SESSION-003
      ARC-DIALOG-001
    ] +
    (1..15).map { |number| format("P12-SES-%03d", number) }
  ).freeze

  FORBIDDEN_RUNTIME = {
    "unsafe code" =>
      /\bunsafe\s*(?:\{|fn\b|impl\b|trait\b|extern\b)/,
    "serde" =>
      /\bserde(?:_json)?\b/,
    "filesystem" =>
      /\bstd::(?:fs|io|path)\b|\b(?:File|OpenOptions)::(?:open|create|new)\b|\binclude_(?:bytes|str)!\s*\(/,
    "network" =>
      /\b(?:std|tokio)::net\b|\b(?:reqwest|socket2)::|\b(?:Tcp|Udp|Unix)(?:Listener|Socket|Stream)\b/,
    "process" =>
      /\bstd::process\b|\bCommand::new\b|\bChild::spawn\b/,
    "ambient environment" =>
      /\bstd::env\b|\benv!\s*\(|\boption_env!\s*\(/,
    "ambient time" =>
      /\bstd::time\b|\bSystemTime\b|\bInstant::(?:now|elapsed)\b/,
    "entropy" =>
      /\b(?:getrandom|thread_rng|fastrand|uuid|random)(?:::|\s*\()|\brand::/i,
    "unordered collection" =>
      /\bHashMap\b|\bHashSet\b/,
    "global mutable state" =>
      /\bstatic\s+mut\b|\b(?:OnceLock|LazyLock)\b|\bthread_local!\s*\(|\bstatic\b[^\n;=]*\b(?:Mutex|RwLock|Atomic\w*)\b/,
    "persistence" =>
      /\b(?:rusqlite|sqlite|sled|redb|rocksdb|database)::|\b(?:persist|persistence|serialize|deserialize)\w*\b/i,
    "protocol dependency" =>
      /\bprotocol(?:::|_v\d+\b)/,
    "policy authority" =>
      /\b(?:authoriz|confirmation|permission|policy|risk_class)\w*\b/i,
    "execution authority" =>
      /\b(?:service_call|call_service|execute|executor)\w*\b/i,
    "credential material" =>
      /\b(?:credential|password|access_token|api_key|secret_key)\w*\b/i,
    "logging API" =>
      /\b(?:println|eprintln|dbg)!\s*\(|\b(?:tracing|log|env_logger)::/
  }.freeze

  TEST_EVIDENCE = {
    "exact TTL boundary" => [
      /#\[test\]\s*fn\s+exact_ttl[[:alnum:]_]*\s*\(/m,
      /before deadline/,
      /exact deadline/
    ],
    "deadline overflow" => [
      /\bSessionErrorCode::DeadlineOverflow\b/,
      /\bu64::MAX\b/
    ],
    "clock rollback" => [
      /\bSessionErrorCode::ClockRollback\b/,
      /rollback_is_observed_before_deadline_overflow/,
      /rollback/
    ],
    "64/65 session boundary" => [
      /session_capacity_rejection_is_atomic/,
      /0\.\.MAX_ACTIVE_SESSIONS/,
      /\bSessionErrorCode::CapacityExceeded\b/,
      /one-over capacity/,
      /for\s*\(\s*index,\s*binding\s*\)\s*in\s*bindings\.iter\s*\(\s*\)\.enumerate\s*\(\s*\)/,
      /every original session survives capacity rejection/,
      /rejected session was never inserted/
    ],
    "16/17 referent boundary" => [
      /MAX_PENDING_REFERENTS\s*\+\s*1/,
      /assert_eq!\s*\(\s*MAX_PENDING_REFERENTS\s*,\s*16\s*\)/m
    ],
    "one-time replay" => [
      /completes_exactly_once/,
      /replay/
    ],
    "cross-session isolation" => [
      /sessions_are_isolated_and_identical_bindings_cannot_cross_sessions/,
      /identical-binding cross-session/,
      /session mismatch preserves addressed state/
    ],
    "session substitution" => [
      /session:\s*SessionId/,
      /if\s+&result\.session\s*!=\s*session/,
      /selected\s*\(\s*session_a\s*,\s*&binding_a/
    ],
    "origin substitution" => [
      /every_bound_field/,
      /ContinuationResult::new\s*\(\s*addressed_session,\s*origin\s*\(/m
    ],
    "capability substitution" => [
      /forged_capability/,
      /\bCapabilityId::new\b/
    ],
    "endpoint substitution" => [
      /forged_node/,
      /forged_slot/
    ],
    "generation substitution" => [
      /result_and_current_generation_substitutions_fail_independently/,
      /forged result generation/,
      /forged current generation/
    ],
    "unknown referent" => [
      /unknown_or_unresolved_referent/,
      /foreign_entity/
    ],
    "unresolved tie" => [
      /\bReferentResolution::UnresolvedTie\b/,
      /unknown_or_unresolved_referent/
    ],
    "cancellation" => [
      /cancellation_and_catalog_change/,
      /\bCancellationOutcome::Cancelled\b/
    ],
    "stale-generation purge" => [
      /catalog_change_purge/,
      /\binvalidate_catalog\b/
    ],
    "deterministic schedules" => [
      /deterministic_schedules_replay_exact_results_and_final_state/,
      /\breplay_schedule\b/,
      /\bpending_sessions\b/
    ],
    "real concurrency" => [
      /simultaneous_double_completion_is_atomic/,
      /\bBarrier::new\b/,
      /\bthread::spawn\b/
    ],
    "restart-empty behavior" => [
      /memory_only_restart_empty/,
      /\bdrop\s*\(\s*store\s*\)/m
    ],
    "privacy redaction" => [
      /diagnostics_are_redacted/,
      /private_origin_canary/,
      /assert!\s*\(\s*!.*contains/m
    ],
    "direct/resumed canonical equivalence" => [
      /exact_completion_matches_direct_composition_canonical_bytes/,
      /\.canonical_bytes\s*\(\s*\)/
    ]
  }.freeze

  module_function

  def run(arguments)
    arguments = arguments.dup
    no_cargo = arguments.delete("--no-cargo")
    review_candidate = arguments.delete("--review-candidate")
    unless arguments.empty?
      raise Failure, "usage: tools/validate-p12 [--no-cargo] [--review-candidate]"
    end

    validate(
      ROOT,
      run_cargo: !no_cargo && !review_candidate,
      require_satisfied: !review_candidate
    )
    puts(review_candidate ? "P12_REVIEW_CANDIDATE_PASS" : "P12_GATE_PASS")
  rescue Failure => error
    warn "P12_GATE_FAIL: #{error.message}"
    exit 1
  end

  def validate(root, run_cargo:, require_satisfied:)
    validate_inventory(root)
    validate_dependencies(root)

    session_files = production_files(root, SESSION_FILES.grep(%r{/src/}))
    plan_files = production_files(root, PLAN_ENGINE_SOURCE_FILES)
    validate_runtime_bytes(session_files.merge(plan_files))

    id_bytes = session_files.fetch("crates/session-engine/src/id.rs")
    store_bytes = session_files.fetch("crates/session-engine/src/store.rs")
    core_limits = File.binread(File.join(root, "crates/nlu-core/src/limits.rs"))
    validate_limit_contract(id_bytes, store_bytes, core_limits)
    validate_store_contract(store_bytes)
    validate_resumable_contract(plan_files.values.join("\n"))
    validate_protocol_boundary(root, session_files.values.join("\n"))
    validate_test_contract(read_test_bytes(root))
    validate_requirements(root, require_satisfied: require_satisfied)
    run_cargo_checks(root) if run_cargo
    true
  rescue Errno::ENOENT, Errno::EISDIR => error
    raise Failure, "P12 required file is missing or unreadable: #{error.message}"
  end

  def validate_inventory(root)
    actual_session = inventory(root, "crates/session-engine")
    validate_inventory_paths(
      actual_session,
      SESSION_FILES,
      "session-engine file inventory"
    )
    SESSION_FILES.each do |relative|
      path = File.join(root, relative)
      raise Failure, "session-engine inventory contains a symlink: #{relative}" if
        File.symlink?(path)
      raise Failure, "session-engine inventory entry is not a regular file: #{relative}" unless
        File.file?(path)
    end

    actual_plan_sources = inventory(root, "crates/plan-engine/src")
    validate_inventory_paths(
      actual_plan_sources,
      PLAN_ENGINE_SOURCE_FILES,
      "plan-engine source inventory"
    )
    plan_tests = inventory(root, "crates/plan-engine/tests")
    raise Failure, "plan-engine resumable tests are missing" if plan_tests.empty?
    raise Failure, "plan-engine test inventory contains a non-Rust file" unless
      plan_tests.all? { |path| path.end_with?(".rs") }
    true
  end

  def inventory(root, relative)
    base = File.join(root, relative)
    return [] unless Dir.exist?(base)

    Dir.glob(File.join(base, "**", "*"), File::FNM_DOTMATCH)
      .select { |path| File.file?(path) || File.symlink?(path) }
      .map { |path| path.delete_prefix("#{root}/") }
      .sort
  end

  def validate_inventory_paths(actual, expected, context)
    raise Failure, "#{context} differs" unless actual.sort == expected.sort

    true
  end

  def production_files(root, relatives)
    relatives.to_h do |relative|
      [relative, File.binread(File.join(root, relative))]
    end
  end

  def validate_dependencies(root)
    workspace = File.binread(File.join(root, "Cargo.toml"))
    member = '"crates/session-engine"'
    raise Failure, "session-engine workspace registration differs" unless
      workspace.scan(member).length == 1

    session_manifest = File.binread(
      File.join(root, "crates/session-engine/Cargo.toml")
    )
    validate_session_manifest(session_manifest)

    plan_manifest = File.binread(File.join(root, "crates/plan-engine/Cargo.toml"))
    raise Failure, "plan-engine must not depend on session-engine" if
      manifest_dependencies(plan_manifest, "dependencies").include?("session-engine")
    true
  end

  def validate_session_manifest(bytes)
    raise Failure, "session-engine package identity differs" unless
      bytes.match?(/^name = "session-engine"$/) &&
        bytes.match?(/^name = "session_engine"$/)
    raise Failure, "session-engine production dependency set differs" unless
      manifest_dependencies(bytes, "dependencies") == %w[nlu-core plan-engine]
    unsupported = dependency_sections(bytes) - %w[dependencies dev-dependencies]
    raise Failure, "session-engine has unsupported dependency sections" unless
      unsupported.empty?
    raise Failure, "session-engine defines a build script" if
      bytes.match?(/^build\s*=/) || bytes.match?(/^links\s*=/)
    true
  end

  def dependency_sections(bytes)
    bytes.scan(/^\[([^\]]*dependencies[^\]]*)\]$/).flatten
  end

  def manifest_dependencies(bytes, section)
    body = bytes[/^\[#{Regexp.escape(section)}\]\s*\n(.*?)(?=^\[|\z)/m, 1]
    return [] unless body

    body.lines.each_with_object([]) do |line, dependencies|
      stripped = line.sub(/#.*/, "").strip
      next if stripped.empty?

      name = stripped.split("=", 2).fetch(0).strip.sub(/\.workspace\z/, "")
      dependencies << name
    end.sort
  end

  def validate_runtime_bytes(files)
    files.each do |path, bytes|
      FORBIDDEN_RUNTIME.each do |name, pattern|
        raise Failure, "#{name} in #{path}" if bytes.match?(pattern)
      end
    end
    true
  end

  def validate_limit_contract(id_bytes, store_bytes, core_limits)
    raise Failure, "SessionId byte limit differs" unless
      integer_constant(id_bytes, "SESSION_ID_BYTES") == 32
    raise Failure, "SessionId is not a fixed byte array" unless
      id_bytes.match?(
        /pub struct SessionId\s*\(\s*\[u8;\s*SESSION_ID_BYTES\]\s*\)\s*;/
      )
    raise Failure, "SessionId constructor is not fixed-width" unless
      id_bytes.match?(
        /from_bytes\s*\(\s*bytes:\s*\[u8;\s*SESSION_ID_BYTES\]\s*\)/
      )
    raise Failure, "active-session limit differs" unless
      integer_constant(store_bytes, "MAX_ACTIVE_SESSIONS") == 64
    raise Failure, "maximum TTL differs" unless
      integer_constant(store_bytes, "MAX_TTL_TICKS") == 300_000

    referent_expression = constant_expression(store_bytes, "MAX_PENDING_REFERENTS")
    referent_limit = if referent_expression == "nlu_core::MAX_CLARIFICATION_OPTIONS"
                       integer_constant(core_limits, "MAX_CLARIFICATION_OPTIONS")
                     else
                       parse_integer(referent_expression)
                     end
    raise Failure, "pending-referent limit differs" unless referent_limit == 16
    true
  end

  def constant_expression(bytes, name)
    expression = bytes[
      /^\s*pub const #{Regexp.escape(name)}:\s*[A-Za-z0-9_:<>]+\s*=\s*([^;]+);$/,
      1
    ]
    raise Failure, "constant is missing or malformed: #{name}" unless expression

    expression.strip
  end

  def integer_constant(bytes, name)
    parse_integer(constant_expression(bytes, name))
  end

  def parse_integer(expression)
    return nil unless expression.match?(/\A[0-9][0-9_]*\z/)

    Integer(expression.delete("_"), 10)
  end

  def validate_store_contract(bytes)
    required = {
      "BTreeMap storage" => /\buse std::collections::BTreeMap\s*;/,
      "Mutex synchronization" => /\buse std::sync::Mutex\s*;/,
      "session-keyed state" =>
        /sessions:\s*BTreeMap\s*<\s*SessionId\s*,\s*PendingSession\s*>/,
      "result-session field" =>
        /pub struct ContinuationResult\s*\{[^}]*session:\s*SessionId/m,
      "result-session constructor binding" =>
        /pub const fn new\s*\(\s*session:\s*SessionId/m,
      "locked state" => /state:\s*Mutex\s*<\s*State\s*>/,
      "checked deadline arithmetic" => /\.checked_add\s*\(/,
      "exact deadline expiry" => /now\s*<\s*pending\.deadline/,
      "session capacity check" =>
        /sessions\.len\s*\(\s*\)\s*>=\s*MAX_ACTIVE_SESSIONS/,
      "referent capacity check" =>
        /count\s*>\s*MAX_PENDING_REFERENTS/
    }
    required.each do |name, pattern|
      raise Failure, "session store lacks #{name}" unless bytes.match?(pattern)
    end
    complete = method_slice(bytes, "pub fn complete")
    {
      "result-session mismatch check" =>
        /if\s+&result\.session\s*!=\s*session\s*\{/,
      "result generation binding" =>
        /pending\.generation\s*!=\s*result\.generation/,
      "current generation binding" =>
        /pending\.generation\s*!=\s*current_generation/
    }.each do |name, pattern|
      raise Failure, "session store lacks #{name}" unless complete.match?(pattern)
    end
    raise Failure, "session store uses non-checked deadline arithmetic" if
      bytes.match?(/\.(?:saturating|wrapping)_add\s*\(/)
    observe = bytes.index("state.observe(now)?")
    checked_add = bytes.index(".checked_add(")
    raise Failure, "clock rollback is not observed before deadline arithmetic" unless
      observe && checked_add && observe < checked_add
    reload_invalidation = method_slice(bytes, "pub fn invalidate_for_reload")
    raise Failure, "session store contains an unexpected destructive clear" unless
      bytes.scan(/sessions\.clear\s*\(\s*\)/).length == 2 &&
        reload_invalidation.scan(/state\.sessions\.clear\s*\(\s*\)/).length == 1
    raise Failure, "capacity rejection branch contains side effects" unless
      bytes.match?(
        /if state\.sessions\.len\(\) >= MAX_ACTIVE_SESSIONS \{\s*return Err\(SessionError::new\(SessionErrorCode::CapacityExceeded\)\);\s*\}/m
      )
    session_check = complete.index("if &result.session != session")
    session_remove = complete.index("state.sessions.remove(session)")
    raise Failure, "result session is not checked before state removal" unless
      session_check && session_remove && session_check < session_remove
    true
  end

  def method_slice(bytes, signature)
    start = bytes.index(signature)
    raise Failure, "session store lacks #{signature}" unless start

    finish = bytes.index("\n    pub fn ", start + signature.length)
    finish ||= bytes.index("\n}", start + signature.length)
    raise Failure, "session store method is unterminated: #{signature}" unless finish

    bytes.byteslice(start, finish - start)
  end

  def validate_resumable_contract(bytes)
    required = {
      "typed pending composition" =>
        /\bpub struct PendingEntityComposition\b/,
      "typed pending endpoint" =>
        /\bpub struct PendingEndpoint\b/,
      "resumable outcome" =>
        /\bpub enum ResumableCompositionOutcome\b/,
      "resumable entry point" =>
        /\bpub fn compose_resumable\s*\(/,
      "consuming completion" =>
        /\bpub fn complete\s*\(\s*self\s*,\s*selected:\s*EntityRef\s*\)/,
      "candidate membership check" =>
        /candidates\.(?:binary_search|contains)\s*\(/,
      "catalog-generation binding" =>
        /selected\.generation\s*\(\s*\)\s*!=\s*self\.catalog_generation/,
      "capability binding" =>
        /capability:\s*CapabilityId/,
      "endpoint binding" =>
        /endpoint:\s*PendingEndpoint/,
      "closed referent storage" =>
        /candidates:\s*Box\s*<\s*\[EntityRef\]\s*>/
    }
    required.each do |name, pattern|
      raise Failure, "plan-engine lacks #{name}" unless bytes.match?(pattern)
    end
    raise Failure, "pending composition is cloneable" if
      bytes.match?(
        /#\[derive\([^\]]*\bClone\b[^\]]*\)\]\s*pub struct PendingEntityComposition/m
      )
    true
  end

  def validate_protocol_boundary(root, session_bytes)
    manifest = File.binread(File.join(root, "crates/protocol/Cargo.toml"))
    raise Failure, "protocol production dependency set differs" unless
      manifest_dependencies(manifest, "dependencies") ==
        %w[nlu-core serde serde_json]
    raise Failure, "protocol depends on session-engine" if
      manifest.match?(/\bsession-engine\b|\bsession_engine\b/)

    v1 = File.binread(File.join(root, "crates/protocol/src/v1.rs"))
    validate_protocol_boundary_bytes(v1, session_bytes)
  end

  def validate_protocol_boundary_bytes(v1, session_bytes)
    raise Failure, "session-engine source references protocol" if
      session_bytes.match?(/\bprotocol\b/i)
    raise Failure, "protocol v1 version identity differs" unless
      v1.match?(/\bpub const VERSION:\s*u16\s*=\s*1\s*;/)
    raise Failure, "protocol v1 contains P12 continuation state" if
      v1.match?(
        /\bsession_engine\b|\bPendingEntityComposition\b|\bResumable\w*\b|\bContinuation\w*\b|\bSessionId\b/
      )
    true
  end

  def read_test_bytes(root)
    session = SESSION_FILES.grep(%r{/tests/|/src/}).map do |relative|
      File.binread(File.join(root, relative))
    end
    plan_paths = Dir[File.join(root, "crates/plan-engine/tests/**/*.rs")].sort
    plan_paths += [File.join(root, "crates/plan-engine/src/internal_contract_tests.rs")]
    (session + plan_paths.map { |path| File.binread(path) }).join("\n")
  end

  def validate_test_contract(bytes)
    raise Failure, "P12 tests lack FIXTURE_TECNICA labels" unless
      bytes.include?("FIXTURE_TECNICA")
    TEST_EVIDENCE.each do |name, patterns|
      patterns.each do |pattern|
        raise Failure, "P12 tests lack #{name}" unless bytes.match?(pattern)
      end
    end
    true
  end

  def validate_requirements(root, require_satisfied:)
    bytes = File.binread(
      File.join(root, "docs/evidence/REQUIREMENTS-TRACEABILITY.md")
    )
    validate_requirement_rows(bytes, require_satisfied: require_satisfied)
  end

  def validate_requirement_rows(bytes, require_satisfied:)
    REQUIREMENTS.each do |id|
      rows = bytes.lines.select { |line| line.start_with?("| `#{id}` |") }
      raise Failure, "requirement row count differs: #{id}" unless rows.length == 1
      status = rows.fetch(0)[/\| (PENDING|SATISFIED) \|\n\z/, 1]
      raise Failure, "requirement status is malformed: #{id}" unless status
      next unless require_satisfied

      raise Failure, "requirement remains pending: #{id}" unless status == "SATISFIED"
    end
    true
  end

  def run_cargo_checks(root)
    cargo = File.join(root, ".tools/rust-1.98.0/bin/cargo")
    commands = [
      [
        "focused format",
        %w[
          fmt
          --package nlu-core
          --package plan-engine
          --package protocol
          --package session-engine
          --
          --check
        ]
      ],
      [
        "strict clippy",
        %w[
          clippy
          --locked
          -p nlu-core
          -p plan-engine
          -p protocol
          -p session-engine
          --all-targets
          --all-features
          --
          -D warnings
        ]
      ],
      [
        "locked tests",
        %w[
          test
          --locked
          -p plan-engine
          -p protocol
          -p session-engine
          --all-features
        ]
      ],
      [
        "locked builds",
        %w[
          build
          --locked
          -p plan-engine
          -p protocol
          -p session-engine
          --all-targets
          --all-features
        ]
      ]
    ]
    commands.each do |label, arguments|
      run_checked(root, [cargo, *arguments], "P12 #{label}")
    end
    true
  end

  def run_checked(root, command, context)
    output, status = Open3.capture2e(
      deterministic_environment(root),
      *command,
      chdir: root
    )
    return output if status.success?

    warn output
    raise Failure, "#{context} failed: #{command.drop(1).join(' ')}"
  end

  def deterministic_environment(root)
    tool_bin = File.join(root, ".tools/rust-1.98.0/bin")
    {
      "HOME" => "/var/empty",
      "PATH" => "#{tool_bin}:/usr/bin:/bin",
      "LC_ALL" => "C",
      "LANG" => "C",
      "TZ" => "UTC",
      "SOURCE_DATE_EPOCH" => "0",
      "CARGO_NET_OFFLINE" => "true",
      "CARGO_INCREMENTAL" => "0",
      "CARGO_TARGET_DIR" => File.join(root, "target/p12-gate"),
      "RUSTC" => File.join(tool_bin, "rustc"),
      "RUSTDOC" => File.join(tool_bin, "rustdoc")
    }
  end
end
