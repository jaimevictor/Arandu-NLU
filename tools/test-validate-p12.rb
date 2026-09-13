# frozen_string_literal: true

require_relative "validate-p12"

module P12ValidationTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure
    yield
    raise "expected P12Validation::Failure"
  rescue P12Validation::Failure => error
    error
  end

  def read(relative)
    File.binread(File.join(P12Validation::ROOT, relative))
  end

  def test_dependency_mutations_are_rejected
    manifest = read("crates/session-engine/Cargo.toml")
    changed = manifest.sub(
      "plan-engine = { path = \"../plan-engine\" }",
      "plan-engine = { path = \"../plan-engine\" }\nserde.workspace = true"
    )
    error = assert_failure do
      P12Validation.validate_session_manifest(changed)
    end
    assert(error.message.include?("dependency set"), "serde production dependency")

    changed = manifest + "\n[build-dependencies]\nserde.workspace = true\n"
    error = assert_failure do
      P12Validation.validate_session_manifest(changed)
    end
    assert(error.message.include?("unsupported dependency"), "build dependency")
  end

  def test_forbidden_runtime_mutations_are_rejected
    samples = {
      "serde" => "use serde::Serialize;",
      "filesystem" => "use std::fs;",
      "network" => "use std::net::TcpStream;",
      "process" => "use std::process;",
      "ambient environment" => "let _ = std::env::var(\"FIXTURE_TECNICA\");",
      "ambient time" => "let _ = std::time::SystemTime::now();",
      "entropy" => "let _ = getrandom::fill(&mut value);",
      "unordered collection" => "let _ = HashMap::new();",
      "global mutable state" => "static mut FIXTURE_TECNICA: u8 = 0;",
      "persistence" => "fn persist_fixture_tecnica() {}",
      "protocol dependency" => "use protocol::v1;",
      "policy authority" => "fn authorize_fixture_tecnica() {}",
      "execution authority" => "fn execute_fixture_tecnica() {}",
      "credential material" => "let credential_fixture_tecnica = value;",
      "logging API" => "tracing::info!(\"FIXTURE_TECNICA\");",
      "unsafe code" => "unsafe { fixture_tecnica(); }"
    }
    assert(
      samples.keys.sort == P12Validation::FORBIDDEN_RUNTIME.keys.sort,
      "every forbidden runtime category has a mutation"
    )
    samples.each do |name, source|
      error = assert_failure do
        P12Validation.validate_runtime_bytes(
          "FIXTURE_TECNICA.rs" => source
        )
      end
      assert(error.message.include?(name), "forbidden #{name}")
    end
  end

  def test_inventory_mutation_is_rejected
    changed = P12Validation::SESSION_FILES + [
      "crates/session-engine/src/FIXTURE_TECNICA_extra.rs"
    ]
    error = assert_failure do
      P12Validation.validate_inventory_paths(
        changed,
        P12Validation::SESSION_FILES,
        "FIXTURE_TECNICA inventory"
      )
    end
    assert(error.message.include?("inventory"), "extra implementation file")
  end

  def test_limit_mutations_are_rejected
    id_bytes = read("crates/session-engine/src/id.rs")
    store_bytes = read("crates/session-engine/src/store.rs")
    core_limits = read("crates/nlu-core/src/limits.rs")

    changed = id_bytes.sub(
      "SESSION_ID_BYTES: usize = 32",
      "SESSION_ID_BYTES: usize = 31"
    )
    error = assert_failure do
      P12Validation.validate_limit_contract(changed, store_bytes, core_limits)
    end
    assert(error.message.include?("SessionId byte"), "SessionId width")

    changed = store_bytes.sub(
      "MAX_ACTIVE_SESSIONS: usize = 64",
      "MAX_ACTIVE_SESSIONS: usize = 63"
    )
    error = assert_failure do
      P12Validation.validate_limit_contract(id_bytes, changed, core_limits)
    end
    assert(error.message.include?("active-session"), "session limit")

    changed = store_bytes.sub(
      "MAX_TTL_TICKS: u64 = 300_000",
      "MAX_TTL_TICKS: u64 = 300_001"
    )
    error = assert_failure do
      P12Validation.validate_limit_contract(id_bytes, changed, core_limits)
    end
    assert(error.message.include?("maximum TTL"), "TTL limit")

    changed = store_bytes.sub(
      /^pub const MAX_PENDING_REFERENTS:[^\n]+$/,
      "pub const MAX_PENDING_REFERENTS: usize = 15;"
    )
    error = assert_failure do
      P12Validation.validate_limit_contract(id_bytes, changed, core_limits)
    end
    assert(error.message.include?("pending-referent"), "referent limit")
  end

  def test_pending_requirement_is_candidate_only
    bytes = read("docs/evidence/REQUIREMENTS-TRACEABILITY.md")
    changed = bytes.lines.map do |line|
      id = P12Validation::REQUIREMENTS.find do |requirement|
        line.start_with?("| `#{requirement}` |")
      end
      next line unless id

      status = id == "P12-SES-001" ? "PENDING" : "SATISFIED"
      line.sub(/\| (?:PENDING|SATISFIED) \|\n\z/, "| #{status} |\n")
    end.join

    assert(
      P12Validation.validate_requirement_rows(
        changed,
        require_satisfied: false
      ),
      "review candidate permits pending rows"
    )
    error = assert_failure do
      P12Validation.validate_requirement_rows(
        changed,
        require_satisfied: true
      )
    end
    assert(error.message.include?("P12-SES-001"), "final pending requirement")
  end

  def test_protocol_boundary_mutation_is_rejected
    session_bytes = read("crates/session-engine/src/lib.rs")
    protocol = read("crates/protocol/src/v1.rs")
    changed = protocol + "\nuse session_engine::SessionId;\n"
    error = assert_failure do
      P12Validation.validate_protocol_boundary_bytes(
        changed,
        session_bytes
      )
    end
    assert(error.message.include?("continuation state"), "protocol P12 state")
  end

  def test_resumable_contract_mutation_is_rejected
    bytes = P12Validation::PLAN_ENGINE_SOURCE_FILES.map { |path| read(path) }.join("\n")
    changed = bytes.sub(
      "pub fn complete(self, selected: EntityRef)",
      "pub fn complete(&self, selected: EntityRef)"
    )
    error = assert_failure do
      P12Validation.validate_resumable_contract(changed)
    end
    assert(error.message.include?("consuming completion"), "replayable pending value")
  end

  def test_storage_mutations_are_rejected
    bytes = read("crates/session-engine/src/store.rs")

    changed = bytes.sub(".checked_add(", ".wrapping_add(")
    error = assert_failure do
      P12Validation.validate_store_contract(changed)
    end
    assert(error.message.include?("checked deadline"), "unchecked deadline")

    changed = bytes.sub(
      "state.observe(now)?;",
      "let _ = now.ticks().checked_add(1);\n        state.observe(now)?;"
    )
    error = assert_failure do
      P12Validation.validate_store_contract(changed)
    end
    assert(error.message.include?("rollback"), "rollback masked by deadline arithmetic")

    changed = bytes.sub(
      "return Err(SessionError::new(SessionErrorCode::CapacityExceeded));",
      "state.sessions.clear();\n            return Err(SessionError::new(SessionErrorCode::CapacityExceeded));"
    )
    error = assert_failure do
      P12Validation.validate_store_contract(changed)
    end
    assert(error.message.include?("destructive clear"), "capacity eviction")

    changed = bytes.sub(
      "return Err(SessionError::new(SessionErrorCode::CapacityExceeded));",
      "state.sessions.pop_last();\n            return Err(SessionError::new(SessionErrorCode::CapacityExceeded));"
    )
    error = assert_failure do
      P12Validation.validate_store_contract(changed)
    end
    assert(error.message.include?("capacity rejection"), "capacity replacement")

    changed = bytes.sub(
      "if &result.session != session {",
      "if false {"
    )
    error = assert_failure do
      P12Validation.validate_store_contract(changed)
    end
    assert(error.message.include?("result-session"), "session substitution")

    changed = bytes.sub(
      "|| pending.generation != result.generation\n",
      ""
    )
    error = assert_failure do
      P12Validation.validate_store_contract(changed)
    end
    assert(error.message.include?("result generation"), "result generation binding")

    changed = bytes.sub(
      "|| pending.generation != current_generation\n",
      ""
    )
    error = assert_failure do
      P12Validation.validate_store_contract(changed)
    end
    assert(error.message.include?("current generation"), "current generation binding")

    changed = bytes.sub("BTreeMap", "HashMap")
    error = assert_failure do
      P12Validation.validate_store_contract(changed)
    end
    assert(error.message.include?("BTreeMap"), "unordered session state")

    changed = bytes.sub("Mutex<State>", "RwLock<State>")
    error = assert_failure do
      P12Validation.validate_store_contract(changed)
    end
    assert(error.message.include?("locked state"), "store synchronization")
  end

  def test_test_evidence_mutations_are_rejected
    bytes = P12Validation.read_test_bytes(P12Validation::ROOT)
    changed = bytes.sub(
      "fn exact_ttl_overflow_and_clock_rollback_fail_closed",
      "fn fixture_tecnica_removed_ttl_evidence"
    )
    error = assert_failure do
      P12Validation.validate_test_contract(changed)
    end
    assert(error.message.include?("exact TTL"), "TTL test evidence")

    changed = bytes.sub(
      "fn sessions_are_isolated_and_identical_bindings_cannot_cross_sessions",
      "fn fixture_tecnica_removed_cross_session_evidence"
    )
    error = assert_failure do
      P12Validation.validate_test_contract(changed)
    end
    assert(error.message.include?("cross-session"), "identical session binding")

    changed = bytes.sub(
      "fn result_and_current_generation_substitutions_fail_independently",
      "fn fixture_tecnica_removed_generation_evidence"
    )
    error = assert_failure do
      P12Validation.validate_test_contract(changed)
    end
    assert(error.message.include?("generation substitution"), "generation independence")

    changed = bytes.sub(
      "fn exact_completion_matches_direct_composition_canonical_bytes",
      "fn fixture_tecnica_removed_equivalence_evidence"
    )
    error = assert_failure do
      P12Validation.validate_test_contract(changed)
    end
    assert(error.message.include?("canonical equivalence"), "canonical equivalence evidence")
  end

  def test_z_repository_candidate_contract
    assert(
      P12Validation.validate(
        P12Validation::ROOT,
        run_cargo: false,
        require_satisfied: false
      ),
      "repository P12 candidate"
    )
  end

  def run
    methods.grep(/^test_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P12_GATE_TESTS_PASS"
  end
end

P12ValidationTest.run
