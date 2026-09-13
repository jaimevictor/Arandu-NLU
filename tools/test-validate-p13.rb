# frozen_string_literal: true

require "fileutils"
require "rbconfig"
require "tmpdir"
require_relative "validate-p13"

module P13ValidationTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure
    yield
    raise "expected P13Validation::Failure"
  rescue P13Validation::Failure => error
    error
  end

  def read(relative)
    File.binread(File.join(P13Validation::ROOT, relative))
  end

  def policy_sources
    [
      read("crates/policy-engine/src/table.rs"),
      read("crates/policy-engine/src/engine.rs"),
      read("crates/policy-engine/src/lib.rs")
    ]
  end

  def protocol_sources
    [
      read("crates/protocol/src/lib.rs"),
      read("crates/protocol/src/preflight.rs"),
      read("crates/protocol/src/v2.rs"),
      read("schemas/protocol-v2-request.schema.json"),
      read("schemas/protocol-v2-response.schema.json")
    ]
  end

  def server_sources
    %w[
      config
      framing
      health
      server
      snapshot
      runtime
    ].map { |name| read("crates/nlu-server/src/#{name}.rs") }
  end

  def test_cargo_command_mutations_are_rejected
    commands = Marshal.load(Marshal.dump(P13Validation.cargo_commands))
    commands[2][1].delete("--offline")
    error = assert_failure do
      P13Validation.validate_cargo_command_contract(commands)
    end
    assert(error.message.include?("locked and offline"), "offline Cargo mutation")

    commands = Marshal.load(Marshal.dump(P13Validation.cargo_commands))
    commands[1][1].delete("warnings")
    error = assert_failure do
      P13Validation.validate_cargo_command_contract(commands)
    end
    assert(error.message.include?("strict"), "strict clippy mutation")

    commands = Marshal.load(Marshal.dump(P13Validation.cargo_commands))
    commands[2][1] << "--no-run"
    error = assert_failure do
      P13Validation.validate_cargo_command_contract(commands)
    end
    assert(error.message.include?("execute tests"), "no-run test mutation")
  end

  def test_closeout_git_subprocesses_disable_lazy_fetch
    output = P13Validation.run_checked(
      P13Validation::ROOT,
      [
        RbConfig.ruby,
        "-e",
        'STDOUT.write(ENV.fetch("GIT_NO_LAZY_FETCH"))'
      ],
      "FIXTURE_TECNICA closeout Git environment"
    )
    assert(output == "1", "run_checked lazy-fetch guard")
  end

  def test_p13_cargo_execution_is_unreachable
    assert(
      P13Validation.parse_arguments(["--no-cargo"]) == {
        review_candidate: false
      },
      "explicit no-Cargo gate arguments"
    )
    assert(
      P13Validation.parse_arguments(
        ["--no-cargo", "--review-candidate"]
      ) == {review_candidate: true},
      "explicit no-Cargo review arguments"
    )
    error = assert_failure do
      P13Validation.parse_arguments(["--review-candidate"])
    end
    assert(error.message.include?("--no-cargo is required"), "missing no-Cargo flag")

    error = assert_failure do
      P13Validation.validate(
        P13Validation::ROOT,
        run_cargo: true,
        require_satisfied: false,
        external_mode: :unit
      )
    end
    assert(error.message.include?("Cargo execution is prohibited"), "Cargo gate")

    error = assert_failure { P13Validation.run_cargo_checks(P13Validation::ROOT) }
    assert(error.message.include?("Cargo execution is prohibited"), "Cargo helper")
    assert(
      P13Validation::INHERITED_GATES.fetch("tools/validate-p07").first ==
        %w[--no-cargo --no-evaluator],
      "P07 evaluator is unreachable from P13"
    )
    assert(
      P13Validation::INHERITED_GATES.fetch("tools/validate-p09").first ==
        %w[--no-cargo --no-reproduction],
      "P09 Cargo reproduction is unreachable from P13"
    )
  end

  def test_dependency_direction_and_network_dependency_mutations_are_rejected
    manifests = Dir[File.join(P13Validation::ROOT, "crates/*/Cargo.toml")].sort.to_h do |path|
      bytes = File.binread(path)
      [P13Validation.manifest_package_name(bytes), bytes]
    end
    changed = manifests.transform_values(&:dup)
    changed["nlu-server"] = changed.fetch("nlu-server").sub(
      "session-engine = { path = \"../session-engine\" }",
      "session-engine = { path = \"../session-engine\" }\nreqwest = \"1\""
    )
    error = assert_failure do
      P13Validation.validate_dependency_bytes(
        read("Cargo.toml"),
        changed,
        read("Cargo.lock")
      )
    end
    assert(error.message.include?("dependency set"), "server dependency injection")

    changed_workspace = read("Cargo.toml").sub(
      'panic = "unwind"',
      'panic = "abort"'
    )
    error = assert_failure do
      P13Validation.validate_dependency_bytes(
        changed_workspace,
        manifests,
        read("Cargo.lock")
      )
    end
    assert(error.message.include?("panic strategy"), "release panic abort")

    changed = manifests.transform_values(&:dup)
    changed["session-engine"] = changed.fetch("session-engine").sub(
      "plan-engine = { path = \"../plan-engine\" }",
      "plan-engine = { path = \"../plan-engine\" }\nprotocol = { path = \"../protocol\" }"
    )
    error = assert_failure do
      P13Validation.validate_dependency_bytes(
        read("Cargo.toml"),
        changed,
        read("Cargo.lock")
      )
    end
    assert(error.message.include?("inverted"), "lower-layer protocol dependency")
  end

  def test_engine_owned_session_and_confirmation_mutations_are_rejected
    session = read("crates/session-engine/src/store.rs")
    policy = read("crates/policy-engine/src/engine.rs")
    runtime = read("crates/nlu-server/src/runtime.rs")

    changed = session.gsub(
      "state.sessions.remove(session)",
      "state.sessions.remove(&SessionId::from_bytes([0; 32]))"
    )
    error = assert_failure do
      P13Validation.validate_engine_owned_integration(changed, policy, runtime)
    end
    assert(error.message.include?("continuation API"), "stored continuation lookup")

    changed = policy.gsub(
      "self.take_confirmation(session, now)?",
      "self.take_confirmation(&SessionId::from_bytes([0; 32]), now)?"
    )
    error = assert_failure do
      P13Validation.validate_engine_owned_integration(session, changed, runtime)
    end
    assert(error.message.include?("confirmation API"), "stored confirmation lookup")

    changed = runtime.sub(".confirm_stored(", ".confirm(")
    error = assert_failure do
      P13Validation.validate_engine_owned_integration(session, policy, changed)
    end
    assert(error.message.include?("stored confirmation"), "server confirmation map bypass")
  end

  def test_external_subprocess_gates_are_required_and_marker_bound
    Dir.mktmpdir("FIXTURE_TECNICA_p13_gates") do |root|
      tools = File.join(root, "tools")
      FileUtils.mkdir_p(tools)
      P13Validation::EXTERNAL_GATES.each do |relative, markers|
        path = File.join(root, relative)
        File.write(
          path,
          "#!/bin/sh\nprintf '%s\\n' #{markers.map { |marker| "'#{marker}'" }.join(' ')}\n"
        )
        File.chmod(0o755, path)
      end
      P13Validation::INHERITED_GATES.each do |relative, contract|
        _arguments, marker = contract
        path = File.join(root, relative)
        File.write(path, "#!/bin/sh\nprintf '%s\\n' '#{marker}'\n")
        File.chmod(0o755, path)
      end
      assert(
        P13Validation.run_external_gates(root, allow_missing: false),
        "exact subprocess markers"
      )

      noise = File.join(root, "tools/p13-noise-evidence")
      File.write(
        noise,
        "#!/bin/sh\nprintf '%s\\n' 'P13_NOISE_SOURCE_EVIDENCE_PASS'\n"
      )
      File.chmod(0o755, noise)
      error = assert_failure do
        P13Validation.run_external_gates(root, allow_missing: false)
      end
      assert(
        error.message.include?("omitted required result"),
        "missing Noise admission marker"
      )
      noise_markers = P13Validation::EXTERNAL_GATES.fetch(
        "tools/p13-noise-evidence"
      )
      File.write(
        noise,
        "#!/bin/sh\nprintf '%s\\n' " \
        "#{noise_markers.map { |marker| "'#{marker}'" }.join(' ')}\n"
      )
      File.chmod(0o755, noise)

      evidence = File.join(root, "tools/p13-evidence")
      File.write(evidence, "#!/bin/sh\nprintf '%s\\n' 'P13_EXACT_SOURCE_COMPATIBILITY_PASS'\n")
      File.chmod(0o755, evidence)
      error = assert_failure do
        P13Validation.run_external_gates(root, allow_missing: false)
      end
      assert(error.message.include?("omitted required result"), "missing gate marker")

      FileUtils.rm_f(evidence)
      error = assert_failure do
        P13Validation.run_external_gates(root, allow_missing: false)
      end
      assert(error.message.include?("missing or not executable"), "missing real gate")
      assert(
        P13Validation.run_external_gates(root, allow_missing: true),
        "unit-level missing gate tolerance"
      )
    end
  end

  def test_inventory_mutations_are_rejected
    changed = P13Validation::SERVER_FILES + [
      "crates/nlu-server/src/FIXTURE_TECNICA_extra.rs"
    ]
    error = assert_failure do
      P13Validation.validate_inventory_paths(
        changed,
        P13Validation::SERVER_FILES,
        "FIXTURE_TECNICA server inventory"
      )
    end
    assert(error.message.include?("inventory"), "extra server file")

    changed = P13Validation::PROTOCOL_FILES - [
      "crates/protocol/src/v2.rs"
    ]
    error = assert_failure do
      P13Validation.validate_inventory_paths(
        changed,
        P13Validation::PROTOCOL_FILES,
        "FIXTURE_TECNICA protocol inventory"
      )
    end
    assert(error.message.include?("inventory"), "missing protocol file")
  end

  def test_network_and_privacy_mutations_are_rejected
    server = {
      "crates/nlu-server/src/server.rs" => read("crates/nlu-server/src/server.rs"),
      "crates/nlu-server/src/runtime.rs" => read("crates/nlu-server/src/runtime.rs")
    }
    policy = {
      "crates/policy-engine/src/lib.rs" => read("crates/policy-engine/src/lib.rs")
    }
    protocol = {
      "crates/protocol/src/lib.rs" => read("crates/protocol/src/lib.rs")
    }

    changed = server.transform_values(&:dup)
    changed["crates/nlu-server/src/runtime.rs"] +=
      "\nfn fixture_tecnica_outbound() { let _ = std::net::TcpStream::connect(\"127.0.0.1:1\"); }\n"
    error = assert_failure do
      P13Validation.validate_network_and_privacy(
        P13Validation::ROOT,
        policy,
        protocol,
        changed
      )
    end
    assert(error.message.include?("outbound"), "outbound connection")

    changed = server.transform_values(&:dup)
    changed["crates/nlu-server/src/runtime.rs"] +=
      "\nfn fixture_tecnica_process() { let _ = std::process::Command::new(\"/usr/bin/nc\"); }\n"
    error = assert_failure do
      P13Validation.validate_network_and_privacy(
        P13Validation::ROOT,
        policy,
        protocol,
        changed
      )
    end
    assert(error.message.include?("subprocess"), "process-backed outbound connection")

    changed = server.transform_values(&:dup)
    changed["crates/nlu-server/src/runtime.rs"] +=
      "\nfn fixture_tecnica_spaced_process() { " \
      "let _ = std :: process :: Command :: new(\"/bin/sh\"); }\n"
    error = assert_failure do
      P13Validation.validate_network_and_privacy(
        P13Validation::ROOT,
        policy,
        protocol,
        changed
      )
    end
    assert(error.message.include?("subprocess"), "spaced process API")

    changed = server.transform_values(&:dup)
    changed["crates/nlu-server/src/runtime.rs"] +=
      "\nuse std::{process::Command as FixtureTecnicaCommand};\n" \
      "fn fixture_tecnica_aliased_process() { " \
      "let _ = FixtureTecnicaCommand::new(\"/bin/sh\"); }\n"
    error = assert_failure do
      P13Validation.validate_network_and_privacy(
        P13Validation::ROOT,
        policy,
        protocol,
        changed
      )
    end
    assert(error.message.include?("subprocess"), "grouped aliased process API")

    changed = server.transform_values(&:dup)
    changed["crates/nlu-server/src/runtime.rs"] +=
      "\nconst FIXTURE_TECNICA_OUTBOUND: &str = \"/usr/bin/nc\";\n"
    error = assert_failure do
      P13Validation.validate_network_and_privacy(
        P13Validation::ROOT,
        policy,
        protocol,
        changed
      )
    end
    assert(error.message.include?("outbound"), "external outbound executable")

    changed = server.transform_values(&:dup)
    changed["crates/nlu-server/src/server.rs"] +=
      "\nfn fixture_tecnica_after_tests() { let _ = std::process::Command::new(\"/usr/bin/nc\"); }\n"
    error = assert_failure do
      P13Validation.validate_network_and_privacy(
        P13Validation::ROOT,
        policy,
        protocol,
        changed
      )
    end
    assert(error.message.include?("subprocess"), "production after cfg(test) module")

    changed = server.transform_values(&:dup)
    changed["crates/nlu-server/src/runtime.rs"] +=
      "\nconst FIXTURE_TECNICA: &str = \"supervisor_token\";\n"
    error = assert_failure do
      P13Validation.validate_network_and_privacy(
        P13Validation::ROOT,
        policy,
        protocol,
        changed
      )
    end
    assert(error.message.include?("credential"), "credential state")

    changed = server.transform_values(&:dup)
    changed["crates/nlu-server/src/runtime.rs"] +=
      "\nstatic FIXTURE_TECNICA_RETAINED: " \
      "std::sync::Mutex<Vec<Vec<u8>>> = std::sync::Mutex::new(Vec::new());\n" \
      "fn fixture_tecnica_retain(request: &[u8]) { " \
      "FIXTURE_TECNICA_RETAINED.lock().unwrap().push(request.to_vec()); }\n"
    error = assert_failure do
      P13Validation.validate_network_and_privacy(
        P13Validation::ROOT,
        policy,
        protocol,
        changed
      )
    end
    assert(error.message.include?("process-global"), "static request retention")

    changed = server.transform_values(&:dup)
    changed["crates/nlu-server/src/runtime.rs"] +=
      "\nfn fixture_tecnica_leak(request: &[u8]) { " \
      "let _ = Box::leak(request.to_vec().into_boxed_slice()); }\n"
    error = assert_failure do
      P13Validation.validate_network_and_privacy(
        P13Validation::ROOT,
        policy,
        protocol,
        changed
      )
    end
    assert(error.message.include?("retention primitive"), "leaked request storage")

    changed = server.transform_values(&:dup)
    changed["crates/nlu-server/src/runtime.rs"] +=
      "\nfn fixture_tecnica_log() { println!(\"FIXTURE_TECNICA\"); }\n"
    error = assert_failure do
      P13Validation.validate_network_and_privacy(
        P13Validation::ROOT,
        policy,
        protocol,
        changed
      )
    end
    assert(error.message.include?("logging"), "logging output")
  end

  def test_pending_requirement_is_candidate_only_and_count_is_exact
    assert(P13Validation::REQUIREMENTS.length == 28, "exact owned count")
    bytes = read("docs/evidence/REQUIREMENTS-TRACEABILITY.md")
    changed = bytes.lines.map do |line|
      id = P13Validation::REQUIREMENTS.find do |requirement|
        line.start_with?("| `#{requirement}` |")
      end
      next line unless id

      status = id == "P13-POL-001" ? "PENDING" : "SATISFIED"
      line.sub(/\| (?:PENDING|SATISFIED) \|\n\z/, "| #{status} |\n")
    end.join
    assert(
      P13Validation.validate_requirement_rows(changed, require_satisfied: false),
      "candidate permits pending owned rows"
    )
    error = assert_failure do
      P13Validation.validate_requirement_rows(changed, require_satisfied: true)
    end
    assert(error.message.include?("P13-POL-001"), "final pending row")
  end

  def test_satisfied_requirements_require_exact_closeout_evidence
    Dir.mktmpdir("FIXTURE_TECNICA_p13_closeout") do |root|
      evidence = File.join(root, "docs/evidence")
      FileUtils.mkdir_p(evidence)
      bytes = read("docs/evidence/REQUIREMENTS-TRACEABILITY.md")
      changed = bytes.lines.map do |line|
        id = P13Validation::REQUIREMENTS.find do |requirement|
          line.start_with?("| `#{requirement}` |")
        end
        id ? line.sub("| PENDING |\n", "| SATISFIED |\n") : line
      end.join
      File.binwrite(
        File.join(evidence, "REQUIREMENTS-TRACEABILITY.md"),
        changed
      )
      error = assert_failure do
        P13Validation.validate_requirements(root, require_satisfied: false)
      end
      assert(error.message.include?("closeout file"), "status-only promotion")
    end
  end

  def test_policy_contract_mutations_are_rejected
    table, engine, library = policy_sources

    changed = table.sub(
      "STANDARD_DESCRIPTOR_COUNT: usize = 21",
      "STANDARD_DESCRIPTOR_COUNT: usize = 20"
    )
    error = assert_failure do
      P13Validation.validate_policy_contract(changed, engine, library)
    end
    assert(error.message.include?("descriptor count"), "policy matrix count")

    changed = table.sub(
      "risk: RiskClass::Sensitive,\n        slots: BROADCAST",
      "risk: RiskClass::Observation,\n        slots: BROADCAST"
    )
    error = assert_failure do
      P13Validation.validate_policy_contract(changed, engine, library)
    end
    assert(error.message.include?("matrix cells"), "policy risk mutation")

    changed = engine.sub(
      "return Evaluation::Denied(PolicyDenialReason::MissingRule);",
      "continue;"
    )
    error = assert_failure do
      P13Validation.validate_policy_contract(table, changed, library)
    end
    assert(error.message.include?("missing rule"), "deny-first mutation")

    changed = engine.sub(
      "pub const fn authorizes_execution(self) -> bool {\n        false",
      "pub const fn authorizes_execution(self) -> bool {\n        true"
    )
    error = assert_failure do
      P13Validation.validate_policy_contract(table, changed, library)
    end
    assert(error.message.include?("authorize execution"), "authority mutation")

    changed = engine.sub(
      "    pub fn confirm_stored(",
      "    pub fn confirm(&self) {}\n\n    pub fn confirm_stored("
    )
    error = assert_failure do
      P13Validation.validate_policy_contract(table, changed, library)
    end
    assert(
      error.message.include?("omits the confirmation instance"),
      "ID-less public confirmation API"
    )
  end

  def test_protocol_contract_and_v1_freeze_mutations_are_rejected
    library, preflight, v2, request_schema, response_schema = protocol_sources
    changed = v2.sub(
      "pub const MAX_DIAGNOSTICS: usize = 8",
      "pub const MAX_DIAGNOSTICS: usize = 9"
    )
    error = assert_failure do
      P13Validation.validate_protocol_contract(
        library,
        preflight,
        changed,
        request_schema,
        response_schema
      )
    end
    assert(error.message.include?("MAX_DIAGNOSTICS"), "diagnostic limit")

    changed = v2.sub(
      "    Health,\n}",
      "    Execute { service_name: String },\n    Health,\n}"
    )
    error = assert_failure do
      P13Validation.validate_protocol_contract(
        library,
        preflight,
        changed,
        request_schema,
        response_schema
      )
    end
    assert(error.message.include?("request variants"), "authority-bearing request")

    changed_schema = response_schema.sub('"maxItems": 8', '"maxItems": 9')
    error = assert_failure do
      P13Validation.validate_protocol_contract(
        library,
        preflight,
        v2,
        request_schema,
        changed_schema
      )
    end
    assert(error.message.include?("diagnostic bound"), "schema limit")

    subjects = P13Validation::V1_HASHES.to_h { |path, _| [path, read(path)] }
    subjects["crates/protocol/src/v1.rs"] += "\n// FIXTURE_TECNICA_MUTATION\n"
    error = assert_failure do
      P13Validation.validate_v1_hash_bytes(subjects)
    end
    assert(error.message.include?("v1 bytes changed"), "v1 source freeze")
  end

  def test_server_bounds_socket_environment_runtime_and_snapshot_mutations_are_rejected
    config, framing, health, server, snapshot, runtime = server_sources

    changed = config.sub("MAX_WORKERS: u16 = 8", "MAX_WORKERS: u16 = 9")
    error = assert_failure do
      P13Validation.validate_server_contract(
        changed,
        framing,
        health,
        server,
        snapshot,
        runtime
      )
    end
    assert(error.message.include?("MAX_WORKERS"), "worker bound")

    changed = config.sub('("TZ", "UTC")', '("TOKEN", "FIXTURE_TECNICA")')
    error = assert_failure do
      P13Validation.validate_server_contract(
        changed,
        framing,
        health,
        server,
        snapshot,
        runtime
      )
    end
    assert(error.message.include?("allowlist"), "environment allowlist")

    changed = server.sub("Permissions::from_mode(0o600)", "Permissions::from_mode(0o666)")
    error = assert_failure do
      P13Validation.validate_server_contract(
        config,
        framing,
        health,
        changed,
        snapshot,
        runtime
      )
    end
    assert(error.message.include?("owner-only socket"), "socket mode")

    changed = server.sub("SanitizedEnvironment::validate_current()?;", "")
    error = assert_failure do
      P13Validation.validate_server_contract(
        config,
        framing,
        health,
        changed,
        snapshot,
        runtime
      )
    end
    assert(error.message.include?("live process environment"), "live environment validation")

    changed = server.sub(".set_nonblocking(false)", ".set_nonblocking(true)")
    error = assert_failure do
      P13Validation.validate_server_contract(
        config,
        framing,
        health,
        changed,
        snapshot,
        runtime
      )
    end
    assert(error.message.include?("blocking accepted"), "accepted stream blocking mode")

    changed = server.sub(
      "receiver.recv_timeout(",
      "receiver.recv("
    )
    error = assert_failure do
      P13Validation.validate_server_contract(
        config,
        framing,
        health,
        changed,
        snapshot,
        runtime
      )
    end
    assert(error.message.include?("bounded request deadline"), "handler request deadline")

    [
      [
        "    state: AtomicU8,\n    shutdown: Arc<AtomicBool>,\n",
        "    state: AtomicU8,\n",
        "deadline-bearing request admission",
        "shutdown-bound admission field"
      ],
      [
        "        if self.is_expired() {\n",
        "        if false {\n",
        "deadline checked before handling",
        "pre-admission deadline check"
      ],
      [
        "        if self.deadline_elapsed() {\n",
        "        if self.is_expired() {\n",
        "deadline-expiring active completion",
        "shutdown-independent completion deadline"
      ],
      [
        "        self.expire();\n",
        "        self.cancel();\n",
        "deadline-expiring active completion",
        "active expiry state transition"
      ],
      [
        "    if completed {\n        slot.admission.take();\n    }\n",
        "    slot.admission.take();\n",
        "lock-serialized active completion",
        "success-only active slot clearing"
      ],
      [
        "        state == REQUEST_EXPIRED_ACTIVE\n            || ",
        "        ",
        "expired-active deadline monitor",
        "expired active monitor visibility"
      ],
      [
        "                    admission.fatal.exit();\n",
        "                    fatal.exit();\n",
        "expired-active deadline monitor",
        "monitor admission fatal binding"
      ],
      [
        "    std::process::exit(FATAL_HANDLER_EXIT_CODE)\n",
        "    panic!(\"FIXTURE_TECNICA\")\n",
        "fatal process containment",
        "fatal exit primitive"
      ],
      [
        "        connection_workers.append(&mut request_monitors);\n",
        "",
        "deadline-triggered fatal shutdown",
        "request monitor join"
      ],
      [
        "join_workers_until(&mut connection_workers, shutdown_deadline, fatal.as_ref())",
        "join_workers_until(&mut request_workers, shutdown_deadline, fatal.as_ref())",
        "deadline-triggered fatal shutdown",
        "aggregate shutdown join target"
      ],
      [
        "WorkerFinished::new(",
        "WorkerFinished::fixture_tecnica_new(",
        "worker retirement guard installed",
        "worker retirement guard constructor"
      ],
      [
        "    if admission.expire() {\n",
        "    if false {\n",
        "fatal admitted-timeout settlement",
        "admitted expiration containment"
      ],
      [
        "        let completed = complete_active_request(active, &admission);\n",
        "        let completed = admission.try_complete();\n",
        "failed admitted completion is fatal",
        "active completion bypass"
      ],
      [
        "    if !workers.is_empty() {\n",
        "    if false {\n",
        "shutdown can leave admitted workers alive",
        "unfinished worker containment"
      ]
    ].each do |needle, replacement, expected, label|
      changed = server.sub(needle, replacement)
      assert(changed != server, "#{label} mutation applies")
      error = assert_failure do
        P13Validation.validate_server_contract(
          config,
          framing,
          health,
          changed,
          snapshot,
          runtime
        )
      end
      assert(error.message.include?(expected), label)
    end

    changed = server.sub(
      "#[cfg(test)]",
      "fn fixture_tecnica_remove_socket() {\n" \
      "    let _ = fs::remove_file(Path::new(\"/tmp/socket\"));\n" \
      "}\n\n#[cfg(test)]"
    )
    error = assert_failure do
      P13Validation.validate_server_contract(
        config,
        framing,
        health,
        changed,
        snapshot,
        runtime
      )
    end
    assert(error.message.include?("unsafe socket path retirement"), "socket retention")

    changed = snapshot.sub("*current = next;", "drop(next);")
    error = assert_failure do
      P13Validation.validate_server_contract(
        config,
        framing,
        health,
        server,
        changed,
        runtime
      )
    end
    assert(error.message.include?("single Arc exchange"), "atomic snapshot")

    changed = snapshot.sub(
      "        next.state().validate_snapshot_metadata(next.metadata())?;\n",
      ""
    )
    error = assert_failure do
      P13Validation.validate_server_contract(
        config,
        framing,
        health,
        server,
        changed,
        runtime
      )
    end
    assert(error.message.include?("validated before lock"), "semantic replacement validation")

    changed = snapshot.sub(
      "        current.state().invalidate_for_reload(now)?;\n",
      ""
    )
    error = assert_failure do
      P13Validation.validate_server_contract(
        config,
        framing,
        health,
        server,
        changed,
        runtime
      )
    end
    assert(error.message.include?("invalidation"), "retained snapshot invalidation")

    changed = runtime.sub("sessions: SessionStore,", "sessions: Vec<u8>,")
    error = assert_failure do
      P13Validation.validate_server_contract(
        config,
        framing,
        health,
        server,
        snapshot,
        changed
      )
    end
    assert(error.message.include?("session store"), "real runtime state")

    changed = runtime.sub("    request_order: Mutex<()>,\n", "")
    error = assert_failure do
      P13Validation.validate_server_contract(
        config,
        framing,
        health,
        server,
        snapshot,
        changed
      )
    end
    assert(error.message.include?("ordering state"), "request-order mutex")

    changed = runtime.sub(
      "        let _request_order = self\n" \
      "            .request_order\n" \
      "            .lock()\n" \
      "            .map_err(|_| ServerError::new(ServerErrorCode::LockPoisoned))?;\n",
      ""
    )
    error = assert_failure do
      P13Validation.validate_server_contract(
        config,
        framing,
        health,
        server,
        snapshot,
        changed
      )
    end
    assert(error.message.include?("request-order serialized"), "request-order lock")

    changed = runtime.sub("        snapshot.state().observe_time(now)?;\n", "")
    error = assert_failure do
      P13Validation.validate_server_contract(
        config,
        framing,
        health,
        server,
        snapshot,
        changed
      )
    end
    assert(error.message.include?("logical-time observation"), "all-request rollback observation")

    changed = runtime.sub(
      "        snapshot.state().observe_time(now)?;\n" \
      "        match detect_request_version(request) {",
      "        match detect_request_version(request) {"
    ).sub(
      "            Ok(RequestVersion::V1) => snapshot.state().dispatch_v1(request),",
      "            Ok(RequestVersion::V1) => {\n" \
      "                snapshot.state().observe_time(now)?;\n" \
      "                snapshot.state().dispatch_v1(request)\n" \
      "            }"
    )
    error = assert_failure do
      P13Validation.validate_server_contract(
        config,
        framing,
        health,
        server,
        snapshot,
        changed
      )
    end
    assert(error.message.include?("logical-time observation"), "observation after version detection")

    changed = runtime.sub(
      "        snapshot.state().observe_time(now)?;\n",
      ""
    ).sub(
      "    ) -> Result<Vec<u8>> {\n        let request = match v2::decode_request(request) {",
      "    ) -> Result<Vec<u8>> {\n" \
      "        self.observe_time(now)?;\n" \
      "        let request = match v2::decode_request(request) {"
    )
    error = assert_failure do
      P13Validation.validate_server_contract(
        config,
        framing,
        health,
        server,
        snapshot,
        changed
      )
    end
    assert(error.message.include?("logical-time observation"), "version-specific observation")

    changed = runtime.sub(".assess(&plan, self.policy_context())", ".evaluate_plan(&plan)")
    error = assert_failure do
      P13Validation.validate_server_contract(
        config,
        framing,
        health,
        server,
        snapshot,
        changed
      )
    end
    assert(error.message.include?("v1 policy assessment"), "v1 policy bypass")

    changed = runtime.sub("self.metadata != metadata", "false")
    error = assert_failure do
      P13Validation.validate_server_contract(
        config,
        framing,
        health,
        server,
        snapshot,
        changed
      )
    end
    assert(error.message.include?("exact metadata"), "runtime metadata binding")
  end

  def test_test_evidence_mutations_are_rejected
    policy = read("crates/policy-engine/tests/policy_contract.rs")
    protocol = P13Validation::PROTOCOL_FILES
      .select { |path| path.include?("/tests/") && path.end_with?(".rs") }
      .map { |path| read(path) }
      .join("\n")
    server = P13Validation::SERVER_FILES
      .select { |path| path.end_with?(".rs") }
      .map { |path| read(path) }
      .join("\n")

    changed = policy.sub(
      "fn standard_matrix_is_exact_exhaustive_and_evaluable",
      "fn fixture_tecnica_removed_policy_matrix"
    )
    error = assert_failure do
      P13Validation.validate_test_contracts(changed, protocol, server)
    end
    assert(error.message.include?("exhaustive policy"), "policy evidence")

    changed = protocol.sub(
      "fn round_trips_every_composed_plan_field_without_semantic_loss",
      "fn fixture_tecnica_removed_composed_plan"
    )
    error = assert_failure do
      P13Validation.validate_test_contracts(policy, changed, server)
    end
    assert(error.message.include?("complete composed"), "protocol evidence")

    changed = server.sub(
      "fn competing_reload_is_atomic_under_real_concurrency",
      "fn fixture_tecnica_removed_reload"
    )
    error = assert_failure do
      P13Validation.validate_test_contracts(policy, protocol, changed)
    end
    assert(error.message.include?("concurrent atomic"), "server reload evidence")

    [
      [
        "admitted_handler_overrun_exits_the_dedicated_process_without_late_mutation",
        "admitted overrun fatal containment"
      ],
      [
        "blocked_handler_shutdown_exits_the_dedicated_process_without_late_mutation",
        "shutdown fatal containment"
      ],
      [
        "handler_panic_exits_the_dedicated_process_and_retains_its_socket",
        "handler panic fatal containment"
      ],
      [
        "request_monitor_expires_only_an_admitted_active_request",
        "monitor admitted-state discrimination"
      ]
    ].each do |function, expected|
      changed = server.sub("fn #{function}", "fn fixture_tecnica_removed_#{function}")
      error = assert_failure do
        P13Validation.validate_test_contracts(policy, protocol, changed)
      end
      assert(error.message.include?(expected), "#{expected} evidence")
    end

    changed = policy.sub(
      /fn standard_matrix_is_exact_exhaustive_and_evaluable\s*\(\)\s*\{.*?^\}/m,
      "fn standard_matrix_is_exact_exhaustive_and_evaluable() {\n}\n"
    )
    error = assert_failure do
      P13Validation.validate_test_contracts(changed, protocol, server)
    end
    assert(error.message.include?("not substantive"), "empty required test body")

    changed = policy.sub(
      /fn standard_matrix_is_exact_exhaustive_and_evaluable\s*\(\)\s*\{.*?^\}/m,
      "fn standard_matrix_is_exact_exhaustive_and_evaluable() {\n    assert!(true);\n}\n"
    )
    error = assert_failure do
      P13Validation.validate_test_contracts(changed, protocol, server)
    end
    assert(error.message.include?("not substantive"), "trivial required test body")

    changed = policy.sub(
      "#[test]\nfn standard_matrix_is_exact_exhaustive_and_evaluable",
      "#[ignore]\n#[test]\nfn standard_matrix_is_exact_exhaustive_and_evaluable"
    )
    error = assert_failure do
      P13Validation.validate_test_contracts(changed, protocol, server)
    end
    assert(error.message.include?("noncanonical attributes"), "ignored required test")

    changed = policy.sub(
      "#[test]\nfn standard_matrix_is_exact_exhaustive_and_evaluable",
      "#[cfg(any())]\n#[test]\nfn standard_matrix_is_exact_exhaustive_and_evaluable"
    )
    error = assert_failure do
      P13Validation.validate_test_contracts(changed, protocol, server)
    end
    assert(error.message.include?("noncanonical attributes"), "disabled required test")

    body = P13Validation.required_test_body(
      policy,
      "standard_matrix_is_exact_exhaustive_and_evaluable"
    )
    changed = policy.sub(
      /fn standard_matrix_is_exact_exhaustive_and_evaluable\s*\(\)\s*\{.*?^\}/m,
      "fn standard_matrix_is_exact_exhaustive_and_evaluable() {\n" \
      "    if std::hint::black_box(false) {\n#{body}\n    }\n" \
      "    assert!(true);\n}\n"
    )
    error = assert_failure do
      P13Validation.validate_test_contracts(changed, protocol, server)
    end
    assert(error.message.include?("unreachable evidence"), "black-box unreachable test")

    changed = policy.sub(
      "fn standard_matrix_is_exact_exhaustive_and_evaluable() {",
      "fn standard_matrix_is_exact_exhaustive_and_evaluable() {\n" \
      "    if std::env::var_os(\"FIXTURE_TECNICA_SKIP\").is_some() { return; }"
    )
    error = assert_failure do
      P13Validation.validate_test_contracts(changed, protocol, server)
    end
    assert(error.message.include?("early return"), "conditionally skipped required test")

    changed = policy.sub(
      /fn standard_matrix_is_exact_exhaustive_and_evaluable\s*\(\)\s*\{.*?^\}/m,
      "fn standard_matrix_is_exact_exhaustive_and_evaluable() {\n" \
      "    let fixture_tecnica_uninvoked = || {\n#{body}\n    };\n" \
      "    assert!(true);\n}\n"
    )
    error = assert_failure do
      P13Validation.validate_test_contracts(changed, protocol, server)
    end
    assert(error.message.include?("uncalled closure"), "uncalled required-test closure")

    padding = "FIXTURE_TECNICA_PADDING_" * 20
    changed = policy.sub(
      /fn confirmation_rejects_source_text_substitution_with_equal_canonical_offsets\s*\(\)\s*\{.*?^\}/m,
      "fn confirmation_rejects_source_text_substitution_with_equal_canonical_offsets() {\n" \
      "    let _padding = r#\"assert_ne!(original, substituted); " \
      "ConfirmationRejectionReason::BindingMismatch #{padding}\"#;\n" \
      "    assert!(true);\n" \
      "}\n"
    )
    error = assert_failure do
      P13Validation.validate_test_contracts(changed, protocol, server)
    end
    assert(error.message.include?("only in padding"), "padded critical test")

    padding = "FIXTURE_TECNICA_CONCURRENCY_PADDING_" * 20
    changed = policy.sub(
      /fn concurrent_stored_confirmation_consumption_accepts_at_most_once\s*\(\)\s*\{.*?^\}/m,
      "fn concurrent_stored_confirmation_consumption_accepts_at_most_once() {\n" \
      "    let _padding = r#\"#{padding}\"#;\n" \
      "    assert!(true);\n" \
      "}\n"
    )
    error = assert_failure do
      P13Validation.validate_test_contracts(changed, protocol, server)
    end
    assert(
      error.message.include?("executable test body"),
      "weakened confirmation concurrency test"
    )

    padding = "FIXTURE_TECNICA_HOSTILE_PADDING_" * 20
    changed = protocol.sub(
      /fn fixed_hostile_byte_and_structural_corpus_is_bounded_and_panic_free\s*\(\)\s*\{.*?^\}/m,
      "fn fixed_hostile_byte_and_structural_corpus_is_bounded_and_panic_free() {\n" \
      "    let _padding = r#\"#{padding}\"#;\n" \
      "    assert!(true);\n" \
      "}\n"
    )
    error = assert_failure do
      P13Validation.validate_test_contracts(policy, changed, server)
    end
    assert(error.message.include?("executable test body"), "padded hostile corpus")

    changed = protocol +
      "\nfn fixture_tecnica_value(value: serde_json::Value) { drop(value); }\n"
    error = assert_failure do
      P13Validation.validate_test_contracts(policy, changed, server)
    end
    assert(error.message.include?("arbitrary serde_json::Value"), "arbitrary JSON test value")

    changed = protocol +
      "\nuse serde_json::{Value as FixtureTecnicaValue};\n"
    error = assert_failure do
      P13Validation.validate_test_contracts(policy, changed, server)
    end
    assert(error.message.include?("arbitrary serde_json::Value"), "aliased arbitrary JSON value")

    changed = policy.sub(
      "fixture_slots_from_schema(slots, index + 1)",
      "fixture_slots(_descriptor, index + 1)"
    )
    error = assert_failure do
      P13Validation.validate_test_contracts(changed, protocol, server)
    end
    assert(error.message.include?("slot expectations"), "production-derived slot oracle")
  end

  def test_z_repository_candidate_contract
    assert(
      P13Validation.validate(
        P13Validation::ROOT,
        run_cargo: false,
        require_satisfied: false,
        external_mode: :unit
      ),
      "repository P13 candidate"
    )
  end

  def run
    methods.grep(/^test_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P13_GATE_TESTS_PASS"
  end
end

P13ValidationTest.run
