# frozen_string_literal: true

require "fileutils"
require "open3"
require "tmpdir"
require_relative "p13-evidence"

module P13EvidenceTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure
    yield
    raise "expected P13Evidence::Failure"
  rescue P13Evidence::Failure => error
    error
  end

  def deep_copy(value)
    Marshal.load(Marshal.dump(value))
  end

  def evidence
    P13Evidence.read_yaml(File.join(P13Evidence::ROOT, P13Evidence::EVIDENCE))
  end

  def materials
    P13Evidence.read_yaml(File.join(P13Evidence::ROOT, P13Evidence::MATERIALS))
  end

  def test_archive_byte_and_size_mutations_are_rejected
    Dir.mktmpdir("FIXTURE_TECNICA_p13_archive") do |directory|
      path = File.join(directory, "FIXTURE_TECNICA_archive.bin")
      File.binwrite(path, "FIXTURE_TECNICA_ARCHIVE_A")
      original = File.binread(path)
      expected = Digest::SHA256.hexdigest(original)
      P13Evidence.verify_file(
        path,
        bytes: original.bytesize,
        sha256: expected,
        context: "FIXTURE_TECNICA archive"
      )

      File.binwrite(path, "FIXTURE_TECNICA_ARCHIVE_B")
      error = assert_failure do
        P13Evidence.verify_file(
          path,
          bytes: original.bytesize,
          sha256: expected,
          context: "FIXTURE_TECNICA archive"
        )
      end
      assert(error.message.include?("hash differs"), "archive hash mutation")

      File.binwrite(path, "FIXTURE_TECNICA_SHORT")
      error = assert_failure do
        P13Evidence.verify_file(
          path,
          bytes: original.bytesize,
          sha256: expected,
          context: "FIXTURE_TECNICA archive"
        )
      end
      assert(error.message.include?("size differs"), "archive size mutation")
    end
  end

  def test_archive_parsing_consumes_verified_bytes
    Dir.mktmpdir("FIXTURE_TECNICA_p13_verified_archive") do |directory|
      root = File.join(directory, "FIXTURE_TECNICA_root")
      Dir.mkdir(root, 0o755)
      member = File.join(root, "FIXTURE_TECNICA_member")
      File.binwrite(member, "FIXTURE_TECNICA_VERIFIED_BYTES")
      File.chmod(0o644, member)
      archive = File.join(directory, "FIXTURE_TECNICA.tar")
      _stdout, stderr, status = Open3.capture3(
        "/usr/bin/tar",
        "-cf",
        archive,
        "-C",
        directory,
        File.basename(root)
      )
      assert(status.success?, "fixture tar creation failed: #{stderr.lines.first}")
      original = File.binread(archive)
      verified = P13Evidence.read_verified_file(
        archive,
        bytes: original.bytesize,
        sha256: Digest::SHA256.hexdigest(original),
        context: "FIXTURE_TECNICA verified archive"
      )
      File.binwrite(archive, "FIXTURE_TECNICA_PATH_REPLACEMENT")
      paths = P13Evidence.archive_file_paths(
        verified,
        "#{File.basename(root)}/",
        "FIXTURE_TECNICA verified archive"
      )
      assert(
        paths == ["FIXTURE_TECNICA_member"],
        "archive paths come from verified bytes"
      )
      assert(
        P13Evidence.archive_mode_inventory(
          verified,
          "FIXTURE_TECNICA verified archive"
        ) == {"644" => 1},
        "archive modes come from verified bytes"
      )
    end
  end

  def test_command_disables_git_lazy_fetch
    settings = P13Evidence.command("/usr/bin/env").lines.to_h do |line|
      key, value = line.chomp.split("=", 2)
      [key, value]
    end
    assert(
      settings.fetch("GIT_NO_LAZY_FETCH", nil) == "1",
      "subprocess environment disables Git lazy fetch"
    )
  end
  def test_archive_tree_path_set_rejects_generated_and_missing_files
    Dir.mktmpdir("FIXTURE_TECNICA_p13_path_set") do |directory|
      first = File.join(directory, "FIXTURE_TECNICA_first")
      second = File.join(directory, "FIXTURE_TECNICA_second")
      File.binwrite(first, "FIXTURE_TECNICA_FIRST")
      File.binwrite(second, "FIXTURE_TECNICA_SECOND")
      expected = %w[FIXTURE_TECNICA_first FIXTURE_TECNICA_second]
      assert(
        P13Evidence.validate_tree_path_set(
          directory,
          expected,
          context: "FIXTURE_TECNICA"
        ),
        "exact archive/tree path set"
      )

      generated = File.join(directory, "FIXTURE_TECNICA_generated.pyc")
      File.binwrite(generated, "FIXTURE_TECNICA_GENERATED")
      error = assert_failure do
        P13Evidence.validate_tree_path_set(
          directory,
          expected,
          context: "FIXTURE_TECNICA"
        )
      end
      assert(error.message.include?("unexpected path"), "generated path")

      FileUtils.rm_f(generated)
      FileUtils.rm_f(second)
      error = assert_failure do
        P13Evidence.validate_tree_path_set(
          directory,
          expected,
          context: "FIXTURE_TECNICA"
        )
      end
      assert(error.message.include?("missing path"), "missing archive path")
    end
  end

  def test_archive_tree_mode_transition_mutations_are_rejected
    assert(
      P13Evidence.validate_mode_transition(
        {"664" => 14},
        {"644" => 14},
        {"664" => 14},
        {"644" => 14},
        context: "FIXTURE_TECNICA"
      ),
      "exact mode transition"
    )

    error = assert_failure do
      P13Evidence.validate_mode_transition(
        {"664" => 13, "775" => 1},
        {"644" => 14},
        {"664" => 14},
        {"644" => 14},
        context: "FIXTURE_TECNICA"
      )
    end
    assert(error.message.include?("archive mode inventory"), "archive mode mutation")

    error = assert_failure do
      P13Evidence.validate_mode_transition(
        {"664" => 14},
        {"644" => 13, "755" => 1},
        {"664" => 14},
        {"644" => 14},
        context: "FIXTURE_TECNICA"
      )
    end
    assert(error.message.include?("tree mode inventory"), "tree mode mutation")
  end

  def test_compatibility_predicate_mutation_is_rejected
    source_paths = P13Evidence.source_paths
    Dir.mktmpdir("FIXTURE_TECNICA_p13_compatibility") do |directory|
      ha_root = File.join(directory, "FIXTURE_TECNICA_ha")
      wyoming_root = File.join(directory, "FIXTURE_TECNICA_wyoming")
      ha_paths = %w[
        homeassistant/components/wyoming/conversation.py
        homeassistant/components/conversation/models.py
        homeassistant/helpers/intent.py
      ]
      wyoming_paths = %w[wyoming/intent.py wyoming/handle.py]
      copy_selected(source_paths.fetch("ha_tree"), ha_root, ha_paths)
      copy_selected(source_paths.fetch("wyoming_tree"), wyoming_root, wyoming_paths)
      paths = source_paths.merge("ha_tree" => ha_root, "wyoming_tree" => wyoming_root)
      assert(
        P13Evidence.validate_compatibility_contracts(paths),
        "exact compatibility predicates"
      )

      bridge = File.join(
        ha_root,
        "homeassistant/components/wyoming/conversation.py"
      )
      bytes = File.binread(bridge).sub(
        "async with asyncio.TaskGroup() as task_group:",
        "async with FIXTURE_TECNICA_SERIAL_GROUP() as task_group:"
      )
      File.binwrite(bridge, bytes)
      error = assert_failure do
        P13Evidence.validate_compatibility_contracts(paths)
      end
      assert(error.message.include?("concurrent"), "ordering predicate mutation")
    end
  end

  def test_duplicate_yaml_and_disposition_mutations_are_rejected
    error = assert_failure do
      P13Evidence.parse_yaml(
        "FIXTURE_TECNICA: 1\nFIXTURE_TECNICA: 2\n",
        "FIXTURE_TECNICA duplicate YAML"
      )
    end
    assert(error.message.include?("duplicate YAML key"), "duplicate YAML key")

    changed = deep_copy(evidence)
    changed
      .fetch("compatibility")
      .fetch("properties")
      .fetch(0)["disposition"] = "FIXTURE_TECNICA_ALLOW"
    error = assert_failure { P13Evidence.validate_evidence(changed) }
    assert(
      error.message.include?("compatibility dispositions"),
      "compatibility overclaim"
    )

    %w[observed reason].each do |field|
      changed = deep_copy(evidence)
      property = changed
        .fetch("compatibility")
        .fetch("properties")
        .fetch(0)
      property[field] = field == "observed" ? true : "FIXTURE_TECNICA_REASON"
      error = assert_failure { P13Evidence.validate_evidence(changed) }
      assert(
        error.message.include?("compatibility dispositions"),
        "compatibility #{field} mutation"
      )
    end

    changed = deep_copy(evidence)
    changed.fetch("transport")["candidate"] = "FIXTURE_TECNICA_SUBSTITUTION"
    error = assert_failure { P13Evidence.validate_evidence(changed) }
    assert(error.message.include?("transport disposition"), "candidate substitution")

    changed = deep_copy(evidence)
    changed.fetch("transport").fetch("probe_required").pop
    error = assert_failure { P13Evidence.validate_evidence(changed) }
    assert(error.message.include?("transport disposition"), "probe deletion")
  end

  def test_git_blob_binding_rejects_selected_path_mutation
    source_paths = P13Evidence.source_paths
    Dir.mktmpdir("FIXTURE_TECNICA_p13_git_blob") do |directory|
      copy_selected(
        source_paths.fetch("ha_tree"),
        directory,
        P13Evidence::HA_FILES.keys
      )
      assert(
        P13Evidence.validate_ha_git_blobs(
          source_paths.fetch("ha_git"),
          directory
        ),
        "exact selected Git blobs"
      )

      path = File.join(
        directory,
        "homeassistant/components/wyoming/conversation.py"
      )
      File.binwrite(path, File.binread(path) + "\n# FIXTURE_TECNICA_MUTATION\n")
      error = assert_failure do
        P13Evidence.validate_ha_git_blobs(
          source_paths.fetch("ha_git"),
          directory
        )
      end
      assert(error.message.include?("Git blob differs"), "Git blob mutation")
    end
  end

  def test_evidence_source_runtime_and_review_mutations_are_rejected
    changed = deep_copy(evidence)
    changed.fetch("evidence_policy")["generated_linguistic_evidence_used"] = true
    error = assert_failure { P13Evidence.validate_evidence(changed) }
    assert(error.message.include?("technical fixture policy"), "generated language evidence")

    changed = deep_copy(evidence)
    changed.fetch("sources").fetch("home_assistant")["use"] = "linguistic_gold"
    error = assert_failure { P13Evidence.validate_evidence(changed) }
    assert(error.message.include?("Home Assistant evidence"), "HA linguistic use")

    changed = deep_copy(evidence)
    changed.fetch("compatibility")["authority"] = "linguistic_gold"
    error = assert_failure { P13Evidence.validate_evidence(changed) }
    assert(error.message.include?("compatibility provenance"), "compatibility authority")

    changed = deep_copy(evidence)
    changed
      .fetch("sources")
      .fetch("cpython")
      .fetch("license")["spdx"] = "FIXTURE_TECNICA_LICENSE"
    error = assert_failure { P13Evidence.validate_evidence(changed) }
    assert(error.message.include?("CPython evidence"), "source license mutation")

    [
      ["cpython", "version_fact", "sha256"],
      ["cpython", "api_facts", "source_path"],
      ["openssl", "version_fact", "sha256"]
    ].each do |source, section, field|
      changed = deep_copy(evidence)
      changed
        .fetch("sources")
        .fetch(source)
        .fetch(section)[field] = "FIXTURE_TECNICA_SUBSTITUTION"
      error = assert_failure { P13Evidence.validate_evidence(changed) }
      assert(
        error.message.include?(source == "cpython" ? "CPython evidence" : "OpenSSL evidence"),
        "#{source} #{section} #{field} mutation"
      )
    end

    changed = deep_copy(evidence)
    changed
      .fetch("build_and_runtime")
      .fetch("exact_homebrew_runtime")["ssl_extension_sha256"] = "0" * 64
    error = assert_failure { P13Evidence.validate_evidence(changed) }
    assert(error.message.include?("Homebrew runtime"), "runtime hash mutation")

    changed = deep_copy(evidence)
    changed.fetch("review_state")["license"] = "FIXTURE_TECNICA_PASS"
    error = assert_failure { P13Evidence.validate_evidence(changed) }
    assert(error.message.include?("review state"), "review overclaim")

    %w[commercial_use modification redistribution obligations].each do |field|
      changed = deep_copy(evidence)
      changed.fetch("sources").fetch("cpython").fetch("license").delete(field)
      error = assert_failure { P13Evidence.validate_evidence(changed) }
      assert(
        error.message.include?("CPython evidence"),
        "CPython license obligation deletion: #{field}"
      )
    end

    changed = deep_copy(evidence)
    changed
      .fetch("sources")
      .fetch("openssl")
      .fetch("bundled_build_tools")
      .clear
    error = assert_failure { P13Evidence.validate_evidence(changed) }
    assert(
      error.message.include?("OpenSSL evidence"),
      "OpenSSL build-tool license deletion"
    )

    changed = deep_copy(evidence)
    changed
      .fetch("sources")
      .fetch("openssl")
      .fetch("known_non_osi_rejection_witnesses")
      .clear
    error = assert_failure { P13Evidence.validate_evidence(changed) }
    assert(
      error.message.include?("OpenSSL evidence"),
      "OpenSSL non-OSI component deletion"
    )

    [
      ["cpython", "path"],
      ["cpython", "bytes"],
      ["openssl", "path"],
      ["openssl", "bytes"],
      ["home_assistant", "path"],
      ["home_assistant", "bytes"],
      ["wyoming", "path"],
      ["wyoming", "bytes"]
    ].each do |source, field|
      changed = deep_copy(evidence)
      changed
        .fetch("sources")
        .fetch(source)
        .fetch("license")[field] = "FIXTURE_TECNICA_SUBSTITUTION"
      error = assert_failure { P13Evidence.validate_evidence(changed) }
      expected = {
        "cpython" => "CPython evidence",
        "openssl" => "OpenSSL evidence",
        "home_assistant" => "Home Assistant evidence",
        "wyoming" => "Wyoming evidence"
      }.fetch(source)
      assert(
        error.message.include?(expected),
        "#{source} license #{field} mutation"
      )
    end

    changed = deep_copy(evidence)
    changed
      .fetch("sources")
      .fetch("openssl")
      .fetch("license")["archive_bundle_admission"] = "ADMITTED"
    error = assert_failure { P13Evidence.validate_evidence(changed) }
    assert(
      error.message.include?("OpenSSL evidence"),
      "OpenSSL archive admission overclaim"
    )

    %w[home_assistant wyoming].each do |source|
      changed = deep_copy(evidence)
      changed
        .fetch("sources")
        .fetch(source)
        .delete("extraction_mode_transform")
      error = assert_failure { P13Evidence.validate_evidence(changed) }
      assert(
        error.message.include?("P13 evidence field missing"),
        "#{source} extraction transform deletion"
      )
    end
  end

  def test_material_hash_and_commit_mutations_are_rejected
    changed = deep_copy(materials)
    home_assistant = changed.fetch("materials").find do |record|
      record["id"] == "home-assistant-core-2026.8.3"
    end
    home_assistant["commit"] = "FIXTURE_TECNICA_SUBSTITUTED_COMMIT"
    error = assert_failure { P13Evidence.validate_materials(changed) }
    assert(
      error.message.include?("Home Assistant material identity"),
      "Home Assistant commit mutation"
    )

    changed = deep_copy(materials)
    wyoming = changed.fetch("materials").find do |record|
      record["id"] == "wyoming-protocol"
    end
    wyoming.fetch("contract_paths").fetch(0)["sha256"] = "0" * 64
    error = assert_failure { P13Evidence.validate_materials(changed) }
    assert(error.message.include?("Wyoming material paths"), "Wyoming path mutation")

    changed = deep_copy(materials)
    home_assistant = changed.fetch("materials").find do |record|
      record["id"] == "home-assistant-core-2026.8.3"
    end
    home_assistant["allowed_use"] = "FIXTURE_TECNICA_UNRESTRICTED"
    error = assert_failure { P13Evidence.validate_materials(changed) }
    assert(
      error.message.include?("Home Assistant material identity"),
      "Home Assistant allowed-use mutation"
    )

    changed = deep_copy(materials)
    wyoming = changed.fetch("materials").find do |record|
      record["id"] == "wyoming-protocol"
    end
    wyoming.delete("prohibited_use")
    error = assert_failure { P13Evidence.validate_materials(changed) }
    assert(
      error.message.include?("Wyoming material identity"),
      "Wyoming prohibited-use deletion"
    )

    %w[
      cpython-3.14.6-p13-transport
      openssl-3.6.3-p13-transport
      home-assistant-core-2026.8.3
      wyoming-protocol
    ].each do |id|
      changed = deep_copy(materials)
      record = changed.fetch("materials").find { |item| item["id"] == id }
      record["canonical_url"] = "https://FIXTURE_TECNICA.invalid/"
      error = assert_failure { P13Evidence.validate_materials(changed) }
      assert(
        error.message.include?("material") ||
          error.message.include?("disposition"),
        "#{id} canonical URL mutation"
      )
    end
  end

  def test_material_duplicate_ids_and_semantic_extensions_are_rejected
    changed = deep_copy(materials)
    record = changed.fetch("materials").find do |item|
      item["id"] == "cpython-3.14.6-p13-transport"
    end
    changed.fetch("materials") << deep_copy(record)
    error = assert_failure { P13Evidence.validate_materials(changed) }
    assert(error.message.include?("duplicate material id"), "duplicate material id")

    changed = deep_copy(materials)
    record = changed.fetch("materials").find do |item|
      item["id"] == "openssl-3.6.3-p13-transport"
    end
    record["FIXTURE_TECNICA_extra"] = false
    error = assert_failure { P13Evidence.validate_materials(changed) }
    assert(
      error.message.include?("material record semantic digest"),
      "material semantic extension"
    )

    changed = deep_copy(evidence)
    changed["FIXTURE_TECNICA_extra"] = false
    error = assert_failure { P13Evidence.validate_evidence(changed) }
    assert(
      error.message.include?("evidence semantic digest"),
      "evidence semantic extension"
    )
  end

  def test_material_runtime_prohibition_mutations_are_rejected
    cpython_id = "cpython-3.14.6-p13-transport"
    openssl_id = "openssl-3.6.3-p13-transport"

    changed = deep_copy(materials)
    changed.fetch("materials").find do |record|
      record["id"] == cpython_id
    end.delete("prohibited_use")
    error = assert_failure { P13Evidence.validate_materials(changed) }
    assert(
      error.message.include?("CPython material disposition"),
      "CPython prohibition deletion"
    )

    changed = deep_copy(materials)
    changed.fetch("materials").find do |record|
      record["id"] == openssl_id
    end.delete("prohibited_use")
    error = assert_failure { P13Evidence.validate_materials(changed) }
    assert(
      error.message.include?("OpenSSL material disposition"),
      "OpenSSL prohibition deletion"
    )

    changed = deep_copy(materials)
    changed.fetch("materials").find do |record|
      record["id"] == openssl_id
    end["allowed_use"] = "distributed_runtime"
    error = assert_failure { P13Evidence.validate_materials(changed) }
    assert(
      error.message.include?("OpenSSL material disposition"),
      "OpenSSL runtime-use overclaim"
    )
  end

  def test_secret_memory_overclaim_is_rejected
    changed = deep_copy(evidence)
    changed
      .fetch("transport")
      .fetch("secret_memory")["per_copy_locking_proven"] = true
    error = assert_failure { P13Evidence.validate_evidence(changed) }
    assert(error.message.include?("transport disposition"), "locking overclaim")

    changed = deep_copy(evidence)
    changed
      .fetch("transport")
      .fetch("secret_memory")["immediate_zeroization_proven"] = true
    error = assert_failure { P13Evidence.validate_evidence(changed) }
    assert(error.message.include?("transport disposition"), "zeroization overclaim")

    [
      ["cpython", "callback_secret_copy_to_openssl_buffer"],
      ["openssl", "session_master_key_copy"],
      ["openssl", "derived_secret_storage"]
    ].each do |source, field|
      changed = deep_copy(evidence)
      changed
        .fetch("sources")
        .fetch(source)
        .fetch("api_facts")[field] = "FIXTURE_TECNICA_SUBSTITUTION"
      error = assert_failure { P13Evidence.validate_evidence(changed) }
      expected = source == "cpython" ? "CPython evidence" : "OpenSSL evidence"
      assert(error.message.include?(expected), "#{source} security fact mutation")
    end
  end

  def test_semantic_digest_is_order_independent_and_type_sensitive
    first = {
      "FIXTURE_TECNICA_b" => [true, 1, "1"],
      "FIXTURE_TECNICA_a" => false
    }
    reordered = {
      "FIXTURE_TECNICA_a" => false,
      "FIXTURE_TECNICA_b" => [true, 1, "1"]
    }
    changed_type = deep_copy(first)
    changed_type.fetch("FIXTURE_TECNICA_b")[1] = "1"
    assert(
      P13Evidence.semantic_digest(first) ==
        P13Evidence.semantic_digest(reordered),
      "mapping order independence"
    )
    assert(
      P13Evidence.semantic_digest(first) !=
        P13Evidence.semantic_digest(changed_type),
      "semantic type distinction"
    )
  end

  def test_transport_probe_passes_both_exact_runtimes
    probe = File.join(P13Evidence::ROOT, "tools/p13-transport-probe.py")
    runtimes = {
      "FIXTURE_TECNICA_runtime_homebrew" => "/opt/homebrew/bin/python3.14",
      "FIXTURE_TECNICA_runtime_source_build" =>
        "/private/tmp/p13-python-install/bin/python3.14"
    }
    runtimes.each do |expected_runtime, python|
      stdout, stderr, status = Open3.capture3(
        {"LC_ALL" => "C", "LANG" => "C", "TZ" => "UTC"},
        python,
        probe
      )
      assert(status.success?, "transport probe failed: #{stderr.lines.first}")
      assert(stdout.include?("PASS #{expected_runtime}"), "exact runtime profile")
      assert(stdout.include?("P13_TRANSPORT_PROBE_PASS"), "transport probe pass")
      assert(
        stdout.include?("P13_SECRET_MEMORY_CONDITIONAL"),
        "secret memory disposition"
      )
    end
  end

  def test_tree_digest_rejects_byte_and_symlink_mutations
    Dir.mktmpdir("FIXTURE_TECNICA_p13_tree") do |directory|
      file = File.join(directory, "FIXTURE_TECNICA_file")
      File.binwrite(file, "FIXTURE_TECNICA_TREE_A")
      original = P13Evidence.tree_digest(directory)
      File.binwrite(file, "FIXTURE_TECNICA_TREE_B")
      changed = P13Evidence.tree_digest(directory)
      assert(original["sha256"] != changed["sha256"], "tree byte mutation")

      link = File.join(directory, "FIXTURE_TECNICA_link")
      File.symlink("FIXTURE_TECNICA_file", link)
      error = assert_failure { P13Evidence.tree_digest(directory) }
      assert(error.message.include?("unsupported symlink"), "tree symlink mutation")
    end
  end

  def test_z_repository_evidence_and_runtime_contract
    assert(
      P13Evidence.validate(paths: P13Evidence.source_paths, runtime: true),
      "repository P13 evidence contract"
    )
  end

  def copy_selected(source_root, destination_root, paths)
    paths.each do |relative|
      source = File.join(source_root, relative)
      destination = File.join(destination_root, relative)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source, destination)
    end
  end

  def run
    methods.grep(/^test_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P13_EVIDENCE_TESTS_PASS"
  end
end

P13EvidenceTest.run
