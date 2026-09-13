# frozen_string_literal: true

require "digest"
require "fileutils"
require "rbconfig"
require "timeout"
require "tmpdir"
require_relative "p13-noise-evidence"
require_relative "validate-governance"

module P13NoiseEvidenceTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure(message = nil)
    yield
    raise "expected P13NoiseEvidence::Failure"
  rescue P13NoiseEvidence::Failure => error
    if message
      assert(error.message.include?(message), "failure message #{message.inspect}")
    end
    error
  end

  def deep_copy(value)
    Marshal.load(Marshal.dump(value))
  end

  def evidence
    P13NoiseEvidence.read_yaml(
      File.join(P13NoiseEvidence::ROOT, P13NoiseEvidence::EVIDENCE)
    )
  end

  def materials
    P13NoiseEvidence.read_yaml(
      File.join(P13NoiseEvidence::ROOT, P13NoiseEvidence::MATERIALS)
    )
  end

  def distribution
    P13NoiseEvidence.read_yaml(
      File.join(P13NoiseEvidence::ROOT, P13NoiseEvidence::DISTRIBUTION)
    )
  end

  def entry(contents, mode = "644")
    {"mode" => mode, "contents" => contents}
  end

  def rust_registry_fixture
    compiler_registry = {
      "name" => "colored",
      "version" => "3.1.1",
      "source" => P13NoiseEvidence::RUST_REGISTRY_SOURCE,
      "checksum" => "a" * 64
    }
    sysroot_registry = {
      "name" => "FIXTURE_TECNICA_sysroot",
      "version" => "1.0.0",
      "source" => P13NoiseEvidence::RUST_REGISTRY_SOURCE,
      "checksum" => "b" * 64
    }
    package_sets = {
      "compiler_and_clippy" => [
        {
          "name" => "FIXTURE_TECNICA_path",
          "version" => "0.0.0",
          "source" => nil,
          "checksum" => nil
        },
        compiler_registry
      ],
      "sysroot" => [
        {
          "name" => "FIXTURE_TECNICA_std_path",
          "version" => "0.0.0",
          "source" => nil,
          "checksum" => nil
        },
        sysroot_registry
      ]
    }
    entries = {
      "compiler_and_clippy" => {
        P13NoiseEvidence.rust_registry_identity(compiler_registry) =>
          rust_registry_fixture_entry(
            "vendor",
            compiler_registry,
            "MPL-2.0"
          )
      },
      "sysroot" => {
        P13NoiseEvidence.rust_registry_identity(sysroot_registry) =>
          rust_registry_fixture_entry(
            "library/vendor",
            sysroot_registry,
            "MIT"
          )
      }
    }
    record = {
      "registry_closures" => {
        "compiler_and_clippy" => rust_registry_fixture_closure(
          "compiler_and_clippy",
          package_sets.fetch("compiler_and_clippy"),
          entries.fetch("compiler_and_clippy")
        ),
        "sysroot" => rust_registry_fixture_closure(
          "sysroot",
          package_sets.fetch("sysroot"),
          entries.fetch("sysroot")
        )
      }
    }
    {
      "record" => record,
      "package_sets" => package_sets,
      "entries" => entries,
      "approved" => {
        "MIT" => "OSI_APPROVED",
        "MPL-2.0" => "OSI_APPROVED"
      }
    }
  end

  def rust_registry_fixture_entry(vendor_root, package, license)
    manifest = <<~TOML
      [package]
      name = "#{package.fetch('name')}"
      version = "#{package.fetch('version')}"
      license = "#{license}"
    TOML
    legal = "FIXTURE_TECNICA_LICENSE_#{package.fetch('name')}\n"
    content_files = {
      "Cargo.toml" => manifest,
      "LICENSE" => legal
    }
    checksum = JSON.generate(
      "$comment" =>
        "This file only protects against accidental modifications. " \
        "It is not a security mechanism and does not protect against " \
        "malicious changes.",
      "files" => content_files.transform_values do |bytes|
        Digest::SHA256.hexdigest(bytes)
      end,
      "package" => package.fetch("checksum")
    )
    directory =
      "#{vendor_root}/#{package.fetch('name')}-#{package.fetch('version')}"
    {
      "directory" => directory,
      "manifest" => manifest,
      "checksum" => checksum,
      "content_files" => content_files,
      "content_scan" => P13NoiseEvidence.rust_registry_content_scan(
        directory,
        content_files,
        P13NoiseEvidence.parse_json(
          checksum,
          "FIXTURE_TECNICA checksum"
        ).fetch("files")
      ),
      "legal_paths" => ["LICENSE"],
      "legal_files" => {"LICENSE" => legal}
    }
  end

  def rust_registry_fixture_closure(closure, packages, entries)
    registry = packages.select { |package| package.fetch("source") }
    vendor_root = P13NoiseEvidence::RUST_REGISTRY_ROOTS.fetch(closure)
    tuple_rows = registry.map do |package|
      package.values_at("name", "version", "source", "checksum")
    end.sort_by { |row| row.map(&:b) }
    manifests = []
    checksums = []
    legal = []
    legacy_legal = []
    expressions = Hash.new(0)
    registry.each do |package|
      item = entries.fetch(P13NoiseEvidence.rust_registry_identity(package))
      directory = item.fetch("directory")
      manifest = item.fetch("manifest")
      checksum = item.fetch("checksum")
      expression = P13NoiseEvidence.package_toml_string(
        manifest,
        "license",
        "FIXTURE_TECNICA registry"
      )
      expressions[expression] += 1
      manifests << [
        "#{directory}/Cargo.toml",
        manifest.bytesize,
        Digest::SHA256.hexdigest(manifest)
      ]
      checksums << [
        "#{directory}/.cargo-checksum.json",
        checksum.bytesize,
        Digest::SHA256.hexdigest(checksum)
      ]
      item.fetch("legal_files").each do |path, bytes|
        row = [
          "#{directory}/#{path}",
          bytes.bytesize,
          Digest::SHA256.hexdigest(bytes)
        ]
        legal << row
        legacy_legal << row if
          File.basename(path).match?(
            P13NoiseEvidence::ORIGIN_LEGAL_FILE_PATTERN
          )
      end
    end
    {
      "lock_path" =>
        closure == "compiler_and_clippy" ? "Cargo.lock" : "library/Cargo.lock",
      "vendor_root" => vendor_root,
      "package_count" => packages.length,
      "path_package_count" => packages.length - registry.length,
      "registry_package_count" => registry.length,
      "lock_tuple_inventory_sha256" => Digest::SHA256.hexdigest(
        tuple_rows.map { |row| row.join("\0") }.join("\n") + "\n"
      ),
      "cargo_manifest_inventory_sha256" =>
        P13NoiseEvidence.rust_file_inventory_digest(manifests),
      "cargo_checksum_inventory_sha256" =>
        P13NoiseEvidence.rust_file_inventory_digest(checksums),
      "legal_file_count" => legal.length,
      "legal_file_bytes" =>
        legal.inject(0) { |sum, row| sum + row.fetch(1) },
      "legal_file_inventory_sha256" =>
        P13NoiseEvidence.rust_file_inventory_digest(legal),
      "legacy_legal_file_count" => legacy_legal.length,
      "legacy_legal_file_bytes" =>
        legacy_legal.inject(0) { |sum, row| sum + row.fetch(1) },
      "legacy_legal_file_inventory_sha256" =>
        P13NoiseEvidence.rust_file_inventory_digest(legacy_legal),
      "content_discovery" =>
        rust_registry_fixture_content_discovery(entries),
      "license_expression_counts" => expressions
    }
  end

  def rust_registry_fixture_content_discovery(entries)
    file_rows = entries.values.flat_map do |item|
      item.fetch("content_scan").fetch("file_rows")
    end
    witness_rows = entries.values.flat_map do |item|
      item.fetch("content_scan").fetch("witness_rows")
    end
    witness_files = witness_rows.map { |row| row.values_at(0, 1, 2) }.uniq
    grouped = witness_rows.group_by { |row| row.fetch(0) }
    {
      "vocabulary_version" =>
        P13NoiseEvidence::RUST_REGISTRY_CONTENT_DISCOVERY_VERSION,
      "vocabulary_sha256" =>
        P13NoiseEvidence.rust_registry_content_vocabulary_sha256,
      "scope" => P13NoiseEvidence::RUST_REGISTRY_CONTENT_DISCOVERY_SCOPE,
      "limits" => P13NoiseEvidence::RUST_REGISTRY_CONTENT_LIMITS,
      "file_count" => file_rows.length,
      "file_bytes" => file_rows.sum { |row| row.fetch(1) },
      "file_inventory_sha256" =>
        P13NoiseEvidence.rust_file_inventory_digest(file_rows),
      "witness_count" => witness_rows.length,
      "witness_inventory_sha256" =>
        P13NoiseEvidence.rust_registry_content_witness_inventory_digest(
          witness_rows
        ),
      "witness_file_count" => witness_files.length,
      "witness_file_inventory_sha256" =>
        P13NoiseEvidence.rust_file_inventory_digest(witness_files),
      "witness_dispositions" => grouped.map do |path, rows|
        rules = rows.map { |row| row.fetch(5) }.uniq.sort_by(&:b)
        semantics =
          if rules.any? do |rule|
            rule.start_with?("RESTRICTIVE_") ||
              rule.start_with?("NONSTANDARD_")
          end
            %w[
              PACKAGE_OSI_ELECTION_OR_EXCLUDED_PATH
              REVIEWED_NO_NON_OSI_P13_LICENSE_ELECTION
              NON_OSI_WITNESS_RETAINED_WITH_NATIVE_FILE_ADMISSION_DEFERRED
            ]
          elsif rules.any? { |rule| rule.start_with?("ORIGIN_") }
            %w[
              PACKAGE_GRANT_AND_RETAINED_ORIGIN_NOTICE
              REVIEWED_PACKAGE_RIGHTS_WITH_EXACT_FILE_WITNESS
              ORIGIN_STATEMENT_RETAINED_UNDER_PACKAGE_GRANT
            ]
          elsif rules.any? { |rule| rule.start_with?("ALTERNATIVE_") }
            %w[
              PACKAGE_OSI_LICENSE_ELECTION
              REVIEWED_OSI_ELECTION_RETAINED
              ALTERNATIVE_GRANT_NOT_USED_AS_P13_LICENSE_ELECTION
            ]
          else
            %w[
              PERMISSIVE_GRANT_IN_CHECKSUM_BOUND_PACKAGE
              OSI_COMPATIBLE_GRANT_REVIEWED
              PERMISSIVE_GRANT_RETAINED_AND_ELECTION_BOUND
            ]
          end
        {
          "path" => path,
          "bytes" => rows.first.fetch(1),
          "sha256" => rows.first.fetch(2),
          "witness_rule_ids" => rules,
          "rights" => semantics.fetch(0),
          "rights_status" => semantics.fetch(1),
          "reachability" =>
            "ACTIVE_LOCK_GRAPH_ONLY_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14",
          "disposition" => semantics.fetch(2)
        }
      end.sort_by { |record| record.fetch("path").b }
    }
  end

  def refresh_fixture_checksum_inventory(fixture, closure)
    rows = fixture.fetch("entries").fetch(closure).values.map do |item|
      bytes = item.fetch("checksum")
      [
        "#{item.fetch('directory')}/.cargo-checksum.json",
        bytes.bytesize,
        Digest::SHA256.hexdigest(bytes)
      ]
    end
    fixture.fetch("record").fetch("registry_closures")
      .fetch(closure)["cargo_checksum_inventory_sha256"] =
        P13NoiseEvidence.rust_file_inventory_digest(rows)
  end

  def refresh_fixture_lock_tuple_inventory(fixture, closure)
    packages = fixture.fetch("package_sets").fetch(closure)
    registry = packages.select { |package| package.fetch("source") }
    rows = registry.map do |package|
      package.values_at("name", "version", "source", "checksum")
    end.sort_by { |row| row.map(&:b) }
    fixture.fetch("record").fetch("registry_closures")
      .fetch(closure)["lock_tuple_inventory_sha256"] = Digest::SHA256.hexdigest(
        rows.map { |row| row.join("\0") }.join("\n") + "\n"
      )
  end

  def refresh_fixture_legal_inventory(fixture, closure)
    rows = fixture.fetch("entries").fetch(closure).values.flat_map do |item|
      item.fetch("legal_files").map do |path, bytes|
        [
          "#{item.fetch('directory')}/#{path}",
          bytes.bytesize,
          Digest::SHA256.hexdigest(bytes)
        ]
      end
    end
    expected = fixture.fetch("record").fetch("registry_closures").fetch(closure)
    expected["legal_file_count"] = rows.length
    expected["legal_file_bytes"] =
      rows.inject(0) { |sum, row| sum + row.fetch(1) }
    expected["legal_file_inventory_sha256"] =
      P13NoiseEvidence.rust_file_inventory_digest(rows)
  end

  def refresh_fixture_content_scans(
    fixture,
    closure,
    refresh_witness_evidence: true
  )
    entries = fixture.fetch("entries").fetch(closure)
    entries.each_value do |item|
      checksums = P13NoiseEvidence.parse_json(
        item.fetch("checksum"),
        "FIXTURE_TECNICA checksum"
      ).fetch("files")
      item["content_scan"] = P13NoiseEvidence.rust_registry_content_scan(
        item.fetch("directory"),
        item.fetch("content_files"),
        checksums
      )
    end
    refreshed = rust_registry_fixture_content_discovery(entries)
    unless refresh_witness_evidence
      previous = fixture.fetch("record").fetch("registry_closures")
        .fetch(closure).fetch("content_discovery")
      %w[
        witness_count
        witness_dispositions
        witness_file_count
        witness_file_inventory_sha256
        witness_inventory_sha256
      ].each do |field|
        refreshed[field] = previous.fetch(field)
      end
    end
    fixture.fetch("record").fetch("registry_closures")
      .fetch(closure)["content_discovery"] = refreshed
  end

  def validate_rust_registry_fixture(fixture)
    P13NoiseEvidence.validate_rust_registry_licenses(
      fixture.fetch("record"),
      fixture.fetch("package_sets"),
      fixture.fetch("entries"),
      fixture.fetch("approved")
    )
  end

  def test_exact_baseline_passes_without_runtime
    assert(P13NoiseEvidence.validate(runtime: false), "exact non-runtime baseline")
  end

  def test_duplicate_yaml_and_aliases_are_rejected
    assert_failure("duplicate YAML key") do
      P13NoiseEvidence.parse_yaml(
        "FIXTURE_TECNICA: 1\nFIXTURE_TECNICA: 2\n",
        "FIXTURE_TECNICA duplicate YAML"
      )
    end
    assert_failure("aliases are prohibited") do
      P13NoiseEvidence.parse_yaml(
        "FIXTURE_TECNICA: &value 1\nSECOND: *value\n",
        "FIXTURE_TECNICA alias YAML"
      )
    end
  end

  def test_immutable_selection_and_scope_mutations_are_rejected
    mutations = [
      lambda do |changed|
        changed.fetch("selection")["protocol_profile"] =
          "Noise_NNpsk0_25519_AESGCM_SHA256"
      end,
      lambda do |changed|
        changed.fetch("selection").fetch("snow_features") << "use-getrandom"
      end,
      lambda do |changed|
        changed.fetch("selection").fetch("forced_cfg").delete("poly1305_force_soft")
      end,
      lambda do |changed|
        changed.fetch("scope")["runtime_admission"] = "GRANTED"
      end,
      lambda do |changed|
        changed.fetch("bounded_convergence")["maximum_passes"] = 4
      end,
      lambda do |changed|
        changed.fetch("review_state")["license"] = "PASS"
      end,
      lambda do |changed|
        changed.fetch("permanent_rejections").delete("OpenSSL_3.6.3")
      end
    ]
    mutations.each do |mutation|
      changed = deep_copy(evidence)
      mutation.call(changed)
      assert_failure("semantic digest differs") do
        P13NoiseEvidence.validate_evidence(changed)
      end
    end
  end

  def test_archive_hash_and_size_mutations_are_rejected
    Dir.mktmpdir("FIXTURE_TECNICA_p13_noise_archive") do |directory|
      path = File.join(directory, "FIXTURE_TECNICA.crate")
      original = "FIXTURE_TECNICA_ARCHIVE_A"
      File.binwrite(path, original)
      hash = Digest::SHA256.hexdigest(original)
      P13NoiseEvidence.verify_file(
        path,
        bytes: original.bytesize,
        sha256: hash,
        context: "FIXTURE_TECNICA archive"
      )

      File.binwrite(path, "FIXTURE_TECNICA_ARCHIVE_B")
      assert_failure("hash differs") do
        P13NoiseEvidence.verify_file(
          path,
          bytes: original.bytesize,
          sha256: hash,
          context: "FIXTURE_TECNICA archive"
        )
      end

      File.binwrite(path, "short")
      assert_failure("size differs") do
        P13NoiseEvidence.verify_file(
          path,
          bytes: original.bytesize,
          sha256: hash,
          context: "FIXTURE_TECNICA archive"
        )
      end
    end
  end

  def test_lock_mutations_and_duplicates_are_rejected
    bytes = File.binread(
      File.join(P13NoiseEvidence::ROOT, "tools/p13-noise-probe/Cargo.lock")
    )
    changed = bytes.sub(
      'checksum = "d122413f284cf2d62fb1b7db97e02edb8cda96d769b16e443a4f6195e35662b0"',
      'checksum = "0122413f284cf2d62fb1b7db97e02edb8cda96d769b16e443a4f6195e35662b0"'
    )
    assert_failure("lock hash differs") do
      P13NoiseEvidence.validate_lock(evidence, bytes: changed)
    end

    duplicate = bytes + <<~LOCK

      [[package]]
      name = "aead"
      version = "0.5.2"
    LOCK
    assert_failure("duplicate package identity") do
      P13NoiseEvidence.parse_lock_packages(duplicate)
    end
  end

  def test_license_inventory_mutations_are_rejected
    license = "FIXTURE_TECNICA_MIT_LICENSE"
    record = {
      "name" => "FIXTURE_TECNICA",
      "license_files" => {
        "LICENSE-MIT" => Digest::SHA256.hexdigest(license)
      }
    }
    entries = {
      "LICENSE-MIT" => entry(license),
      "AUTHORS" => entry("FIXTURE_TECNICA_AUTHORS"),
      "src/lib.rs" => entry("FIXTURE_TECNICA_SOURCE")
    }
    record.fetch("license_files")["AUTHORS"] =
      Digest::SHA256.hexdigest("FIXTURE_TECNICA_AUTHORS")
    assert(
      P13NoiseEvidence.validate_license_inventory(record, entries),
      "exact license inventory"
    )

    changed = deep_copy(entries)
    changed["LICENSE-EXTRA"] = entry("FIXTURE_TECNICA_EXTRA_LICENSE")
    assert_failure("license file inventory differs") do
      P13NoiseEvidence.validate_license_inventory(record, changed)
    end

    changed = deep_copy(entries)
    changed.fetch("LICENSE-MIT")["contents"] << "_MUTATED"
    assert_failure("license file inventory differs") do
      P13NoiseEvidence.validate_license_inventory(record, changed)
    end

    changed = deep_copy(entries)
    changed.delete("AUTHORS")
    assert_failure("license file inventory differs") do
      P13NoiseEvidence.validate_license_inventory(record, changed)
    end
  end

  def test_cacophony_git_tree_binding_mutations_are_rejected
    path = "vectors/cacophony.txt"
    blob = "b8a271ed1aba8b4a56bf429e559d7947827123b4"
    line = "100644 blob #{blob}\t#{path}\n"
    assert(
      P13NoiseEvidence.validate_git_tree_binding(line, path, blob),
      "exact Cacophony Git tree binding"
    )
    assert_failure("Git tree binding differs") do
      P13NoiseEvidence.validate_git_tree_binding(
        line.sub(blob, "08a271ed1aba8b4a56bf429e559d7947827123b4"),
        path,
        blob
      )
    end
  end

  def test_noise_and_cacophony_primary_origins_are_required
    paths = P13NoiseEvidence.source_paths(evidence)
    assert(
      P13NoiseEvidence.validate_noise_specification(evidence, paths),
      "exact Noise primary Git origin"
    )
    missing_noise = paths.merge(
      "noise_spec_origin" => "/private/tmp/FIXTURE_TECNICA_missing-noise-origin"
    )
    assert_failure("failed") do
      P13NoiseEvidence.validate_noise_specification(evidence, missing_noise)
    end
    changed_materials = deep_copy(materials)
    changed_materials.fetch("materials").find do |record|
      record.fetch("id") == "noise-protocol-revision-34-p13-transport"
    end["tree"] = "0" * 40
    assert_failure("Noise material evidence differs: tree") do
      P13NoiseEvidence.validate_material_closure_binding(
        changed_materials,
        evidence
      )
    end

    snow = evidence.fetch("closure").fetch("packages").find do |record|
      record.fetch("name") == "snow"
    end
    archive = File.join(
      paths.fetch("archive_root"),
      "snow-#{snow.fetch('version')}.crate"
    )
    entries = P13NoiseEvidence.crate_entries(
      archive,
      "snow-#{snow.fetch('version')}"
    )
    snow_path = evidence.fetch("removed_cacophony_vector")
      .fetch("snow_archive_path")
    validated = {
      "archive_sources" => {"snow" => entries},
      "origin_sources" => {"snow" => entries.reject { |path, _| path == snow_path }}
    }
    assert(
      P13NoiseEvidence.validate_cacophony_origin(
        evidence,
        materials,
        validated,
        paths
      ),
      "exact Cacophony primary Git origin and Snow deletion"
    )
    missing_cacophony = paths.merge(
      "cacophony_origin" =>
        "/private/tmp/FIXTURE_TECNICA_missing-cacophony-origin"
    )
    assert_failure("failed") do
      P13NoiseEvidence.validate_cacophony_origin(
        evidence,
        materials,
        validated,
        missing_cacophony
      )
    end
  end

  def test_git_evidence_never_lazy_fetches_missing_objects
    git = "/Library/Developer/CommandLineTools/usr/bin/git"
    Dir.mktmpdir("FIXTURE_TECNICA_git_lazy_fetch") do |directory|
      origin = File.join(directory, "origin.git")
      work = File.join(directory, "work")
      partial = File.join(directory, "partial")
      P13NoiseEvidence.command(git, "init", "--bare", origin)
      P13NoiseEvidence.command(
        git, "-C", origin, "config", "uploadpack.allowFilter", "true"
      )
      P13NoiseEvidence.command(git, "init", work)
      bytes = "FIXTURE_TECNICA_LAZY_BLOB\n"
      path = File.join(work, "evidence.txt")
      File.binwrite(path, bytes)
      commit_env = {
        "GIT_AUTHOR_NAME" => "FIXTURE_TECNICA",
        "GIT_AUTHOR_EMAIL" => "fixture@example.invalid",
        "GIT_COMMITTER_NAME" => "FIXTURE_TECNICA",
        "GIT_COMMITTER_EMAIL" => "fixture@example.invalid"
      }
      P13NoiseEvidence.command(git, "-C", work, "add", "evidence.txt")
      P13NoiseEvidence.command(
        git, "-C", work, "commit", "-m", "FIXTURE_TECNICA",
        env: commit_env
      )
      P13NoiseEvidence.command(
        git, "-C", work, "remote", "add", "origin", "file://#{origin}"
      )
      P13NoiseEvidence.command(git, "-C", work, "push", "origin", "HEAD:main")
      P13NoiseEvidence.command(
        git, "clone", "--filter=blob:none", "--no-checkout",
        "--branch", "main", "file://#{origin}", partial
      )

      commit = P13NoiseEvidence.command(
        git, "-C", partial, "rev-parse", "HEAD"
      ).strip
      blob = P13NoiseEvidence.command(
        git, "-C", partial, "ls-tree", "HEAD", "--", "evidence.txt",
        env: P13NoiseEvidence::GIT_ENVIRONMENT
      ).split.fetch(2)
      missing = lambda do
        _output, _error, status = Open3.capture3(
          P13NoiseEvidence::GIT_ENVIRONMENT,
          git, "-C", partial, "cat-file", "-e", blob
        )
        !status.success?
      end
      assert(missing.call, "partial clone starts without evidence blob")
      assert_failure("failed") do
        P13NoiseEvidence.git_object_file(
          root: partial,
          commit: commit,
          path: "evidence.txt",
          blob: blob,
          sha256: Digest::SHA256.hexdigest(bytes),
          context: "FIXTURE_TECNICA lazy object"
        )
      end
      assert(missing.call, "guarded Git read leaves evidence blob absent")
    end
  end

  def test_direct_compile_contract_mutations_are_rejected
    assert(
      P13NoiseEvidence.validate_direct_compile_contract(evidence),
      "exact direct compile contract"
    )

    changed = deep_copy(evidence)
    changed.fetch("runtime_isolation").fetch("direct_compile")["cargo_executed"] =
      true
    assert_failure("direct compile contract differs") do
      P13NoiseEvidence.validate_direct_compile_contract(changed)
    end

    changed = deep_copy(evidence)
    changed.fetch("runtime_isolation").fetch("direct_compile")
      .fetch("rejected_runtime_tool")["disposition"] = "EXECUTED"
    assert_failure("rejected Cargo runtime tool record differs") do
      P13NoiseEvidence.validate_direct_compile_contract(changed)
    end

    changed = deep_copy(evidence)
    changed.fetch("runtime_isolation").fetch("direct_compile")
      .fetch("packages").delete("zeroize")
    assert_failure("direct compile contract differs") do
      P13NoiseEvidence.validate_direct_compile_contract(changed)
    end

    changed = deep_copy(evidence)
    command_window = changed.fetch("runtime_isolation")
      .fetch("direct_compile").fetch("command_window_guard")
    command_window["preexisting_generated_artifacts_bound"] = false
    assert_failure("command-window guard contract differs") do
      P13NoiseEvidence.validate_direct_compile_contract(changed)
    end

    changed = deep_copy(evidence)
    changed.fetch("runtime_isolation").fetch("direct_compile")
      .fetch("command_window_guard").fetch("immutable_trees")
      .first["inventory_sha256"] = "0" * 64
    assert_failure("command-window guard contract differs") do
      P13NoiseEvidence.validate_direct_compile_contract(changed)
    end

    changed = deep_copy(evidence)
    changed.fetch("runtime_isolation").fetch("direct_compile")
      .fetch("command_window_guard").fetch("generated_files")
      .first["sha256"] = "0" * 64
    assert_failure("command-window guard contract differs") do
      P13NoiseEvidence.validate_direct_compile_contract(changed)
    end

    changed = deep_copy(evidence)
    changed.fetch("runtime_isolation").fetch("direct_compile")
      .fetch("toolchain_notice_files").first["sha256"] = "0" * 64
    assert_failure("toolchain notice inventory differs") do
      P13NoiseEvidence.validate_direct_compile_contract(changed)
    end

    changed = deep_copy(evidence)
    librustc_driver = changed.fetch("runtime_isolation")
      .fetch("direct_compile").fetch("command_window_guard")
      .fetch("immutable_files").find do |record|
        record.fetch("name") == "librustc_driver"
      end
    librustc_driver["sha256"] = "0" * 64
    assert_failure("command-window guard contract differs") do
      P13NoiseEvidence.validate_direct_compile_contract(changed)
    end
  end

  def test_probe_execution_fields_reject_stale_cargo_semantics
    probe = evidence.fetch("probe")
    assert(
      P13NoiseEvidence.validate_probe_execution_contract(probe),
      "exact direct probe execution contract"
    )

    changed = deep_copy(probe)
    changed["cargo_test"] = "offline_locked_exact_sources"
    assert_failure("probe evidence field set differs") do
      P13NoiseEvidence.validate_probe_execution_contract(changed)
    end

    changed = deep_copy(probe)
    changed["exact_local_snow_source"] =
      "/private/tmp/FIXTURE_TECNICA_stale_projection"
    assert_failure("probe evidence field set differs") do
      P13NoiseEvidence.validate_probe_execution_contract(changed)
    end

    changed = deep_copy(probe)
    changed["direct_clippy"] = "cargo_clippy"
    assert_failure("direct probe execution evidence differs") do
      P13NoiseEvidence.validate_probe_execution_contract(changed)
    end
  end

  def test_cargo_marker_rules_are_fail_closed
    archive = {"src/lib.rs" => entry("FIXTURE_TECNICA_SOURCE")}
    extracted = deep_copy(archive)
    extracted[".cargo-ok"] = entry("{\"v\":1}")
    assert(
      P13NoiseEvidence.validate_exact_extraction(
        archive,
        extracted,
        context: "FIXTURE_TECNICA registry",
        allow_cargo_ok: true
      ),
      "exact generated Cargo marker"
    )

    changed = deep_copy(extracted)
    changed.fetch(".cargo-ok")["contents"] = "{\"v\":2}"
    assert_failure("Cargo marker differs") do
      P13NoiseEvidence.validate_exact_extraction(
        archive,
        changed,
        context: "FIXTURE_TECNICA registry",
        allow_cargo_ok: true
      )
    end

    assert_failure("unrecorded Cargo marker") do
      P13NoiseEvidence.validate_exact_extraction(
        archive,
        extracted,
        context: "FIXTURE_TECNICA path dependency",
        allow_cargo_ok: false
      )
    end
  end

  def test_resolver_fixture_contract_is_compile_fail_and_bounded
    record = {
      "name" => "fixture-tecnica",
      "version" => "1.2.3",
      "required_features" => %w[full std],
      "required_dependencies" => [
        {"name" => "dependency-fixture", "version" => "2.3.4"}
      ]
    }
    entries = P13NoiseEvidence.resolver_fixture_entries(record)
    manifest = entries.fetch("Cargo.toml").fetch("contents")
    source = entries.fetch("src/lib.rs").fetch("contents")
    assert(manifest.include?('license = "Apache-2.0"'), "fixture license")
    assert(manifest.include?("full = []"), "fixture full feature")
    assert(manifest.include?("std = []"), "fixture std feature")
    assert(
      manifest.include?('dependency-fixture = "=2.3.4"'),
      "fixture dependency"
    )
    assert(source.include?("compile_error!"), "fixture compilation prohibition")

    changed = deep_copy(record)
    changed.fetch("required_features") << "../unsafe"
    assert_failure("feature is unsafe") do
      P13NoiseEvidence.resolver_fixture_entries(changed)
    end

    changed = deep_copy(record)
    changed.fetch("required_dependencies").first["name"] = "../unsafe"
    assert_failure("dependency name is unsafe") do
      P13NoiseEvidence.resolver_fixture_entries(changed)
    end
  end

  def with_compile_projection_paths(paths)
    original = P13NoiseEvidence::COMPILE_PROJECTION_PATHS
    replacement = paths.to_h do |name, retained_paths|
      [name, retained_paths.sort.freeze]
    end.freeze
    P13NoiseEvidence.send(:remove_const, :COMPILE_PROJECTION_PATHS)
    P13NoiseEvidence.const_set(:COMPILE_PROJECTION_PATHS, replacement)
    yield
  ensure
    if original
      P13NoiseEvidence.send(:remove_const, :COMPILE_PROJECTION_PATHS) if
        P13NoiseEvidence.const_defined?(:COMPILE_PROJECTION_PATHS, false)
      P13NoiseEvidence.const_set(:COMPILE_PROJECTION_PATHS, original)
    end
  end

  def compile_projection_record(
    package,
    archive,
    retained_paths,
    replacement: nil,
    additions: {}
  )
    projected = archive.select { |path, _value| retained_paths.include?(path) }
    deleted = archive.reject { |path, _value| retained_paths.include?(path) }
    replacement_actions = {}
    if replacement
      projected = deep_copy(projected)
      projected["src/backend/soft.rs"] = entry(replacement)
      replacement_actions["src/backend/soft.rs"] = "REPLACE_PROJECT_SOURCE"
      manifest = projected.fetch("Cargo.toml")
      projected_manifest = manifest.fetch("contents").sub(
        P13NoiseEvidence::POLY1305_ARCHIVE_LICENSE_LINE,
        P13NoiseEvidence::POLY1305_PROJECTED_LICENSE_BLOCK
      )
      projected["Cargo.toml"] = entry(
        projected_manifest,
        manifest.fetch("mode")
      )
      replacement_actions["Cargo.toml"] = "REPLACE_LICENSE_DECLARATION"
    end
    projected.merge!(additions)
    action_rows = archive.keys.sort_by(&:b).map do |path|
      input = archive.fetch(path)
      input_fields = [
        input.fetch("mode"),
        input.fetch("contents").bytesize.to_s,
        Digest::SHA256.hexdigest(input.fetch("contents"))
      ]
      if deleted.key?(path)
        [path, "DELETE_WHOLE_FILE", *input_fields, "-", "-", "-"].join("\0")
      elsif replacement_actions.key?(path)
        output = projected.fetch(path)
        output_fields = [
          output.fetch("mode"),
          output.fetch("contents").bytesize.to_s,
          Digest::SHA256.hexdigest(output.fetch("contents"))
        ]
        [
          path,
          replacement_actions.fetch(path),
          *input_fields,
          *output_fields
        ].join("\0")
      else
        [path, "RETAIN_EXACT", *input_fields, *input_fields].join("\0")
      end
    end
    action_rows.concat(additions.keys.sort_by(&:b).map do |path|
      output = additions.fetch(path)
      [
        path,
        "ADD_ORIGIN_NOTICE",
        "-",
        "-",
        "-",
        output.fetch("mode"),
        output.fetch("contents").bytesize.to_s,
        Digest::SHA256.hexdigest(output.fetch("contents"))
      ].join("\0")
    end)
    action_rows.sort_by! { |row| row.split("\0", 2).first.b }
    record = {
      "archive_file_count" => archive.length,
      "retained_file_count" => projected.length,
      "deleted_file_count" => deleted.length,
      "replacement_file_count" => replacement_actions.length,
      "retained_paths_sha256" =>
        Digest::SHA256.hexdigest(retained_paths.join("\n") + "\n"),
      "deleted_paths_sha256" =>
        P13NoiseEvidence.canonical_path_digest(deleted.keys.sort_by(&:b)),
      "action_inventory_sha256" =>
        Digest::SHA256.hexdigest(action_rows.join("\n") + "\n"),
      "added_notice_file_count" => additions.length,
      "added_notice_paths_sha256" =>
        P13NoiseEvidence.canonical_path_digest(additions.keys.sort_by(&:b)),
      "projected_tree_sha256" =>
        P13NoiseEvidence.entry_tree_digest(projected),
      "deleted_tree_sha256" => P13NoiseEvidence.entry_tree_digest(deleted),
      "mixed_file_byte_range_edits" => 0,
      "license_election" => P13NoiseEvidence.projection_license_election(package)
    }
    if replacement
      original = archive.fetch("src/backend/soft.rs").fetch("contents")
      manifest = archive.fetch("Cargo.toml").fetch("contents")
      projected_manifest = projected.fetch("Cargo.toml").fetch("contents")
      record.merge!(
        "replacement_input_bytes" => original.bytesize,
        "replacement_input_sha256" => Digest::SHA256.hexdigest(original),
        "replacement_bytes" => replacement.bytesize,
        "replacement_sha256" => Digest::SHA256.hexdigest(replacement),
        "license_replacement_path" => "Cargo.toml",
        "license_replacement_input_bytes" => manifest.bytesize,
        "license_replacement_input_sha256" => Digest::SHA256.hexdigest(manifest),
        "license_replacement_bytes" => projected_manifest.bytesize,
        "license_replacement_sha256" =>
          Digest::SHA256.hexdigest(projected_manifest)
      )
    end
    record
  end

  def compile_projection_inventory_record(
    sources,
    archive_file_count:,
    deleted_file_count:
  )
    rows = sources.keys.sort_by(&:b).flat_map do |package|
      sources.fetch(package).keys.sort_by(&:b).map do |path|
        source = sources.fetch(package).fetch(path)
        [
          package,
          path,
          source.fetch("mode"),
          source.fetch("contents").bytesize.to_s,
          Digest::SHA256.hexdigest(source.fetch("contents"))
        ].join("\0")
      end
    end
    text_paths = []
    binary_paths = []
    sources.each do |package, entries|
      entries.each do |path, source|
        qualified = "#{package}/#{path}"
        if P13NoiseEvidence.strict_text?(source.fetch("contents"))
          text_paths << qualified
        else
          binary_paths << qualified
        end
      end
    end
    text_paths.sort_by!(&:b)
    binary_paths.sort_by!(&:b)
    {
      "action_types" => %w[
        ADD_ORIGIN_NOTICE
        DELETE_WHOLE_FILE
        REPLACE_LICENSE_DECLARATION
        REPLACE_PROJECT_SOURCE
        RETAIN_EXACT
      ],
      "selected_package_count" => sources.length,
      "archive_file_count" => archive_file_count,
      "projected_file_count" => text_paths.length + binary_paths.length,
      "deleted_file_count" => deleted_file_count,
      "replacement_file_count" => 2,
      "added_notice_file_count" => 2,
      "text_file_count" => text_paths.length,
      "binary_file_count" => binary_paths.length,
      "text_paths_sha256" =>
        P13NoiseEvidence.canonical_path_digest(text_paths),
      "binary_paths_sha256" =>
        P13NoiseEvidence.canonical_path_digest(binary_paths),
      "inventory_sha256" =>
        Digest::SHA256.hexdigest(rows.join("\n") + "\n"),
      "native_linux_file_reachability" =>
        "DEFERRED_TO_P14_READ_ONLY_SNAPSHOT_BUILDS",
      "result" =>
        "EXACT_ADMITTED_PROJECTION_AND_CONSERVATIVE_INTENDED_LINUX_SOURCE_SET"
    }
  end

  def test_compile_projection_retained_deletion_and_action_mutations_are_rejected
    retained_paths = %w[LICENSE-MIT src/lib.rs]
    package = {
      "name" => "fixture-tecnica",
      "declared_license" => "MIT",
      "license_files" => {"LICENSE-MIT" => "FIXTURE_TECNICA_SHA256"}
    }
    archive = {
      "LICENSE-MIT" => entry("FIXTURE_TECNICA_MIT"),
      "src/lib.rs" => entry("FIXTURE_TECNICA_RETAINED"),
      "tests/vector.rs" => entry("FIXTURE_TECNICA_DELETED")
    }
    record = compile_projection_record(
      package,
      archive,
      retained_paths
    )

    with_compile_projection_paths("fixture-tecnica" => retained_paths) do
      projected, deleted = P13NoiseEvidence.validate_compile_projection(
        package,
        archive,
        record
      )
      assert(
        projected.keys.sort == retained_paths &&
          deleted.keys == ["tests/vector.rs"],
        "exact generic retain/delete projection"
      )

      changed = deep_copy(archive)
      changed.fetch("src/lib.rs")["contents"] << "_MUTATED"
      assert_failure("compile projection record differs") do
        P13NoiseEvidence.validate_compile_projection(package, changed, record)
      end

      changed = deep_copy(archive)
      changed["tests/renamed.rs"] = changed.delete("tests/vector.rs")
      assert_failure("compile projection record differs") do
        P13NoiseEvidence.validate_compile_projection(package, changed, record)
      end

      changed = deep_copy(record)
      changed["action_inventory_sha256"] = "0" * 64
      assert_failure("compile projection record differs") do
        P13NoiseEvidence.validate_compile_projection(package, archive, changed)
      end
    end
  end

  def test_compile_projection_replacement_source_and_input_mutations_are_rejected
    retained_paths = %w[Cargo.toml LICENSE-MIT src/backend/soft.rs]
    package = {
      "name" => "poly1305",
      "declared_license" => "Apache-2.0 OR MIT",
      "license_files" => {"LICENSE-MIT" => "FIXTURE_TECNICA_SHA256"}
    }
    archive = {
      "Cargo.toml" => entry(
        "[package]\n" \
        "license = \"Apache-2.0 OR MIT\"\n"
      ),
      "LICENSE-MIT" => entry("FIXTURE_TECNICA_MIT"),
      "src/backend/avx2.rs" => entry("FIXTURE_TECNICA_DELETED_AVX2"),
      "src/backend/soft.rs" => entry("FIXTURE_TECNICA_UPSTREAM_SOFT_A")
    }
    replacement = File.binread(
      File.join(
        P13NoiseEvidence::ROOT,
        P13NoiseEvidence::PROJECT_POLY1305_SOURCE
      )
    )
    record = compile_projection_record(
      package,
      archive,
      retained_paths,
      replacement: replacement
    )

    with_compile_projection_paths("poly1305" => retained_paths) do
      projected, = P13NoiseEvidence.validate_compile_projection(
        package,
        archive,
        record
      )
      assert(
        projected.fetch("src/backend/soft.rs").fetch("contents") == replacement &&
          projected.fetch("Cargo.toml").fetch("contents").include?(
            "license = \"Apache-2.0\"\n"
          ) &&
          projected.fetch("Cargo.toml").fetch("contents").include?(
            "NLU P13 modification notice"
          ) &&
          !projected.fetch("Cargo.toml").fetch("contents").include?(
            "Apache-2.0 OR MIT"
          ),
        "exact project source and license replacements"
      )

      changed = deep_copy(record)
      changed["replacement_sha256"] = "0" * 64
      assert_failure("project-authored Poly1305 backend hash differs") do
        P13NoiseEvidence.validate_compile_projection(package, archive, changed)
      end

      changed = deep_copy(archive)
      changed.fetch("src/backend/soft.rs")["contents"][-1] = "B"
      assert_failure("Poly1305 replacement input hash differs") do
        P13NoiseEvidence.validate_compile_projection(package, changed, record)
      end

      changed = deep_copy(archive)
      changed.fetch("Cargo.toml")["contents"].sub!("OR MIT", "MIT OR")
      assert_failure("license replacement input hash differs") do
        P13NoiseEvidence.validate_compile_projection(package, changed, record)
      end
    end
  end

  def test_compile_projection_aggregate_and_path_partition_mutations_are_rejected
    sources = {
      "fixture-a" => {
        "src/lib.rs" => entry("FIXTURE_TECNICA_TEXT")
      },
      "fixture-b" => {
        "assets/table.bin" => entry("FIXTURE_TECNICA\0BINARY")
      }
    }
    record = compile_projection_inventory_record(
      sources,
      archive_file_count: 3,
      deleted_file_count: 1
    )
    assert(
      P13NoiseEvidence.validate_compile_projection_inventory(
        record,
        sources,
        3,
        2,
        1
      ),
      "exact aggregate projection inventory and path partition"
    )

    changed = deep_copy(record)
    changed["inventory_sha256"] = "0" * 64
    assert_failure("compile projection aggregate differs") do
      P13NoiseEvidence.validate_compile_projection_inventory(
        changed,
        sources,
        3,
        2,
        1
      )
    end

    changed_sources = deep_copy(sources)
    changed_sources.fetch("fixture-b").fetch("assets/table.bin")["contents"] =
      "FIXTURE_TECNICA_NOW_TEXT"
    changed = deep_copy(record)
    changed["inventory_sha256"] = compile_projection_inventory_record(
      changed_sources,
      archive_file_count: 3,
      deleted_file_count: 1
    ).fetch("inventory_sha256")
    assert_failure("compile projection aggregate differs") do
      P13NoiseEvidence.validate_compile_projection_inventory(
        changed,
        changed_sources,
        3,
        2,
        1
      )
    end
  end

  def test_intended_linux_target_graph_mutations_are_rejected
    record = evidence.fetch("intended_linux_target_graphs")
    observed = record.fetch("targets").to_h do |target|
      [
        target,
        record.fetch("selected_external_packages_by_target").fetch(target).dup
      ]
    end
    assert(
      P13NoiseEvidence.validate_target_graph_record(evidence, observed),
      "exact intended Linux target graphs"
    )

    changed = deep_copy(observed)
    changed.fetch("aarch64-unknown-linux-gnu").delete("poly1305")
    assert_failure("target graph differs") do
      P13NoiseEvidence.validate_target_graph_record(evidence, changed)
    end

    changed_evidence = deep_copy(evidence)
    changed_evidence.fetch("intended_linux_target_graphs")
      .fetch("lock_resolution_only_packages")
      .push("libc")
    assert_failure("lock-only package disposition differs") do
      P13NoiseEvidence.validate_target_graph_record(changed_evidence, observed)
    end
  end

  def test_source_origin_notice_scan_is_fail_closed
    based_statement =
      "// This implementation is based on FIXTURE_TECNICA\n" \
      "// work with a wrapped source-origin statement.\n"
    thanks_statement =
      "//! Additionally, thanks to work by the FIXTURE_TECNICA\n" \
      "//! Working Group, this behavior is defined.\n"
    reference_statement =
      "//! The reference implementation of FIXTURE_TECNICA,\n" \
      "//! by the fixture authors, defines this strategy.\n"
    sources = {
      "fixture-tecnica" => {
        "metadata.fixture" => entry(
          "FIXTURE_TECNICA_HEADER.\n#{based_statement}" \
          "#{thanks_statement}#{reference_statement}FIXTURE_TECNICA_TRAILER\n"
        ),
        "negative.fixture" => entry(
          "// Selected based on the build target.\n" \
          "// Selected based on the package version.\n" \
          "// Detection is based on the current state.\n"
        ),
        "origin-vocabulary.fixture" => entry(
          "// Implementation inspired by FIXTURE_TECNICA.\n" \
          "// Code ported from FIXTURE_TECNICA.\n" \
          "// Test vectors extracted from FIXTURE_TECNICA.\n"
        ),
        "LICENSE" => entry(
          "Copyright (c) FIXTURE_TECNICA\n" \
          "Copied from FIXTURE_TECNICA legal boilerplate\n"
        ),
        "binary.fixture" => entry(
          "copied from FIXTURE_TECNICA_BINARY_EXCLUDED\0"
        )
      }
    }
    rows = P13NoiseEvidence.source_origin_notice_rows(sources)
    assert(rows.length == 6, "six exact source-origin notices")
    assert(
      rows.first.first(4) == ["fixture-tecnica", "metadata.fixture", 2, 3],
      "wrapped source-origin notice coordinates"
    )
    assert(
      rows.first.last == Digest::SHA256.hexdigest(based_statement),
      "wrapped source-origin statement digest"
    )
    assert(
      rows.fetch(1).first(4) == ["fixture-tecnica", "metadata.fixture", 4, 5],
      "wrapped acknowledgment coordinates"
    )
    assert(
      rows.fetch(2).first(4) == ["fixture-tecnica", "metadata.fixture", 6, 7],
      "wrapped reference-implementation coordinates"
    )
    assert(
      rows.fetch(3).first(4) ==
        ["fixture-tecnica", "origin-vocabulary.fixture", 1, 1],
      "inspired-by origin coordinates"
    )
    assert(
      rows.fetch(4).first(4) ==
        ["fixture-tecnica", "origin-vocabulary.fixture", 2, 2],
      "ported-from origin coordinates"
    )
    assert(
      rows.fetch(5).first(4) ==
        ["fixture-tecnica", "origin-vocabulary.fixture", 3, 3],
      "extracted-from origin coordinates"
    )
    assert(
      rows.none? { |row| row.fetch(1) == "negative.fixture" },
      "ordinary based-on target, version, and detection prose is excluded"
    )
    assert(
      rows.none? { |row| row.fetch(1) == "LICENSE" },
      "ordinary legal boilerplate is excluded"
    )

    changed = deep_copy(sources)
    changed.fetch("fixture-tecnica")["extra.fixture"] =
      entry("// copied from FIXTURE_TECNICA_ADDED_ORIGIN\n")
    assert(
      P13NoiseEvidence.source_origin_notice_rows(changed).length == 7,
      "added source-origin statement changes the inventory"
    )
  end

  def test_reproduced_origin_scan_preserves_exact_statement_boundaries
    hsalsa =
      "/// For more information on HSalsa on which HChaCha is based, see:\n" \
      "///\n" \
      "/// <https://FIXTURE_TECNICA.invalid/hsalsa>\n"
    hfs =
      "// From the HFS spec, Section 5:\n" \
      "//\n" \
      "//     FIXTURE_TECNICA_QUOTED_SOURCE\n"
    signal =
      "////////////////////////////////////////////////////////////\n" \
      "// Signal tests from                                      //\n" \
      "//     https://FIXTURE_TECNICA.invalid/signal/             //\n" \
      "////////////////////////////////////////////////////////////\n"
    sources = {
      "fixture-tecnica" => {
        "reproduced.rs" => entry(
          hsalsa +
          "FIXTURE_TECNICA_BOUNDARY_A\n" +
          hfs +
          "FIXTURE_TECNICA_BOUNDARY_B\n" +
          signal
        )
      }
    }

    rows = P13NoiseEvidence.source_origin_notice_rows(sources)
    assert(
      rows.length == 3,
      "three reproduced source-origin notices"
    )
    assert(
      rows.fetch(0).first(4) ==
        ["fixture-tecnica", "reproduced.rs", 1, 3],
      "HSalsa attribution starts after no synthetic separator"
    )
    assert(
      rows.fetch(0).last == Digest::SHA256.hexdigest(hsalsa),
      "HSalsa URL remains in the exact statement"
    )
    assert(
      rows.fetch(1).first(4) ==
        ["fixture-tecnica", "reproduced.rs", 5, 7],
      "HFS attribution includes quoted source payload"
    )
    assert(
      rows.fetch(1).last == Digest::SHA256.hexdigest(hfs),
      "HFS quoted payload remains in the exact statement"
    )
    assert(
      rows.fetch(2).first(4) ==
        ["fixture-tecnica", "reproduced.rs", 10, 12],
      "Signal attribution excludes the preceding separator"
    )
    assert(
      rows.fetch(2).last ==
        Digest::SHA256.hexdigest(signal.lines.drop(1).join),
      "Signal URL and closing separator remain in the statement"
    )
  end

  def test_typenum_origin_binding_is_fail_closed
    paths = P13NoiseEvidence.source_paths(evidence)
    package = evidence.fetch("closure").fetch("packages").find do |record|
      record.fetch("name") == "typenum"
    end
    archive = File.join(
      paths.fetch("archive_root"),
      "typenum-#{package.fetch('version')}.crate"
    )
    entries = P13NoiseEvidence.crate_entries(
      archive,
      "typenum-#{package.fetch('version')}"
    )
    assert(
      P13NoiseEvidence.validate_typenum_origin(evidence, entries),
      "exact typenum and rust-num origin binding"
    )
    notice = P13NoiseEvidence.projection_notice_entries(evidence, "typenum")
    assert(
      notice.fetch(P13NoiseEvidence::TYPENUM_NOTICE_PATH)
        .fetch("contents").include?(
          "Copyright 2014-2016 The Rust Project Developers"
        ),
      "typenum retains the exact rust-num source notice and MIT grant"
    )

    changed = deep_copy(evidence)
    changed.fetch("typenum_origin_review")["origin_git_blob"] = "0" * 40
    assert_failure("Git tree binding differs") do
      P13NoiseEvidence.validate_typenum_origin(changed, entries)
    end
  end

  def test_generic_array_origin_and_projected_notice_are_fail_closed
    paths = P13NoiseEvidence.source_paths(evidence)
    package = evidence.fetch("closure").fetch("packages").find do |record|
      record.fetch("name") == "generic-array"
    end
    archive = File.join(
      paths.fetch("archive_root"),
      "generic-array-#{package.fetch('version')}.crate"
    )
    entries = P13NoiseEvidence.crate_entries(
      archive,
      "generic-array-#{package.fetch('version')}"
    )
    additions = P13NoiseEvidence.projection_notice_entries(
      evidence,
      "generic-array"
    )
    entries.merge!(additions)
    assert(
      P13NoiseEvidence.validate_generic_array_origin(evidence, entries),
      "exact generic-array and Rust PR 49000 origin binding"
    )
    notice = additions.fetch(P13NoiseEvidence::GENERIC_ARRAY_NOTICE_PATH)
      .fetch("contents")
    assert(
      notice.include?("Copyright 2014 The Rust Project Developers") &&
        notice.include?("Permission is hereby granted"),
      "generic-array retains the Rust copyright and MIT permission"
    )

    changed = deep_copy(evidence)
    changed.fetch("generic_array_origin_review")["origin_git_blob"] = "0" * 40
    assert_failure("Git tree binding differs") do
      P13NoiseEvidence.projection_notice_entries(changed, "generic-array")
    end

    changed = deep_copy(evidence)
    changed.fetch("generic_array_origin_review")
      .fetch("projected_notice")["sha256"] = "0" * 64
    assert_failure("projected notice differs") do
      P13NoiseEvidence.projection_notice_entries(changed, "generic-array")
    end

    changed = deep_copy(evidence)
    changed.fetch("generic_array_origin_review")
      .fetch("adapted_regions").fetch("origin")["sha256"] = "0" * 64
    assert_failure("adapted origin identity differs") do
      P13NoiseEvidence.validate_generic_array_origin(changed, entries)
    end

    changed = deep_copy(evidence)
    changed.fetch("generic_array_origin_review")
      .fetch("adapted_regions").fetch("package")["end_line"] = 114
    assert_failure("adapted package region identity differs") do
      P13NoiseEvidence.validate_generic_array_origin(changed, entries)
    end

    changed = deep_copy(evidence)
    changed.fetch("generic_array_origin_review")
      .fetch("copyright_file")["git_blob"] = "0" * 40
    assert_failure("Git tree binding differs") do
      P13NoiseEvidence.validate_generic_array_origin(changed, entries)
    end
  end

  def test_advisory_omission_and_version_boundary_are_rejected
    records = evidence.fetch("advisory_review").fetch("matching_advisories")
    paths = records.map { |record| record.fetch("path") }.sort
    assert(
      P13NoiseEvidence.validate_advisory_match_set(paths, records),
      "exact advisory match set"
    )

    changed = deep_copy(records)
    changed.delete_if { |record| record.fetch("package") == "generic-array" }
    assert_failure("matching advisory set differs") do
      P13NoiseEvidence.validate_advisory_match_set(paths, changed)
    end
    assert(
      P13NoiseEvidence.version_at_least?("4.1.3", "4.1.3"),
      "patched boundary is included"
    )
    assert(
      !P13NoiseEvidence.version_at_least?("4.1.2", "4.1.3"),
      "pre-patch version is excluded"
    )
  end

  def test_probe_source_mutation_is_rejected
    source = File.join(P13NoiseEvidence::ROOT, P13NoiseEvidence::PROBE_ROOT)
    Dir.mktmpdir("FIXTURE_TECNICA_p13_noise_probe") do |directory|
      copy = File.join(directory, "probe")
      FileUtils.cp_r(source, copy)
      assert(
        P13NoiseEvidence.validate_probe_files(evidence, root: copy),
        "exact probe files"
      )
      path = File.join(copy, "src/lib.rs")
      File.binwrite(path, File.binread(path) + "\n// FIXTURE_TECNICA_MUTATION\n")
      assert_failure("size differs") do
        P13NoiseEvidence.validate_probe_files(evidence, root: copy)
      end
    end
  end

  def test_material_rejection_and_runtime_scope_mutations_are_rejected
    changed = deep_copy(materials)
    openssl = changed.fetch("materials").find do |record|
      record.fetch("id") == "openssl-3.6.3-p13-transport"
    end
    openssl["bundle_admission"] = "ADMITTED"
    assert_failure("material differs") do
      P13NoiseEvidence.validate_materials(changed)
    end

    changed = deep_copy(materials)
    snow = changed.fetch("materials").find do |record|
      record.fetch("id") == "snow-0.10.0-p13-transport-closure"
    end
    snow["runtime_admission"] = "GRANTED"
    assert_failure("material differs") do
      P13NoiseEvidence.validate_materials(changed)
    end

    changed = deep_copy(materials)
    origin = changed.fetch("materials").find do |record|
      record.fetch("id") == "rust-num-pow-origin-p13"
    end
    origin["source_sha256"] = "0" * 64
    assert_failure("material differs") do
      P13NoiseEvidence.validate_materials(changed)
    end
  end

  def test_material_closure_cross_ledger_mutations_are_rejected
    assert(
      P13NoiseEvidence.validate_material_closure_binding(materials, evidence),
      "exact material closure binding"
    )

    changed = deep_copy(materials)
    snow = changed.fetch("materials").find do |record|
      record.fetch("id") == "snow-0.10.0-p13-transport-closure"
    end
    snow["lock_sha256"] = "0" * 64
    assert_failure("lock identity differs") do
      P13NoiseEvidence.validate_material_closure_binding(changed, evidence)
    end

    changed = deep_copy(materials)
    snow = changed.fetch("materials").find do |record|
      record.fetch("id") == "snow-0.10.0-p13-transport-closure"
    end
    snow["lock_package_count_excluding_probe"] = 30
    assert_failure("lock identity differs") do
      P13NoiseEvidence.validate_material_closure_binding(changed, evidence)
    end

    changed = deep_copy(materials)
    legal_code = changed.fetch("materials").find do |record|
      record.fetch("id") == "creative-commons-by-4.0-legalcode-p13"
    end
    legal_code["status"] = "ADMITTED_AUTONOMOUS"
    assert_failure("admission state differs") do
      P13NoiseEvidence.validate_material_closure_binding(changed, evidence)
    end

    changed = deep_copy(materials)
    poly1305 = changed.fetch("materials").find do |record|
      record.fetch("id") == "project-poly1305-soft-p13"
    end
    poly1305["projected_tree_sha256"] = "0" * 64
    assert_failure("Poly1305 material binding differs") do
      P13NoiseEvidence.validate_material_closure_binding(changed, evidence)
    end

    changed = deep_copy(materials)
    rust_num = changed.fetch("materials").find do |record|
      record.fetch("id") == "rust-num-pow-origin-p13"
    end
    rust_num["source_sha256"] = "0" * 64
    assert_failure("rust-num material binding differs") do
      P13NoiseEvidence.validate_material_closure_binding(changed, evidence)
    end
  end

  def test_private_source_tree_post_command_mutations_are_rejected
    Dir.mktmpdir("FIXTURE_TECNICA_p13_private_source") do |directory|
      container = File.join(directory, "container")
      source = File.join(container, "source")
      begin
        FileUtils.mkdir_p(source)
        path = File.join(source, "lib.rs")
        File.binwrite(path, "FIXTURE_TECNICA_SOURCE_A")
        P13NoiseEvidence.seal_private_tree(source)
        File.chmod(0o555, container)
        expected = P13NoiseEvidence.tree_entries(source)
        identity = P13NoiseEvidence.private_tree_identity(container)
        assert(
          P13NoiseEvidence.validate_private_tree(
            expected,
            source,
            identity: identity,
            identity_root: container
          ),
          "exact sealed private source"
        )

        File.chmod(0o644, path)
        File.binwrite(path, "FIXTURE_TECNICA_SOURCE_B")
        assert_failure("private source tree") do
          P13NoiseEvidence.validate_private_tree(expected, source)
        end

        File.binwrite(path, "FIXTURE_TECNICA_SOURCE_A")
        File.chmod(0o444, path)
        assert(
          P13NoiseEvidence.validate_private_tree(expected, source),
          "restored bytes and mode pass content-only checks"
        )
        assert_failure("containing directory identity changed") do
          P13NoiseEvidence.validate_private_tree(
            expected,
            source,
            identity: identity,
            identity_root: container
          )
        end

        identity = P13NoiseEvidence.private_tree_identity(container)
        File.chmod(0o755, container)
        parked = File.join(container, "parked")
        File.rename(source, parked)
        FileUtils.mkdir_p(source)
        File.binwrite(File.join(source, "lib.rs"), "FIXTURE_TECNICA_SOURCE_A")
        P13NoiseEvidence.seal_private_tree(source)
        assert(
          P13NoiseEvidence.validate_private_tree(expected, source),
          "byte-identical substituted source passes content-only checks"
        )
        P13NoiseEvidence.unseal_private_tree(source)
        FileUtils.remove_entry(source)
        File.rename(parked, source)
        File.chmod(0o555, container)
        assert_failure("containing directory identity changed") do
          P13NoiseEvidence.validate_private_tree(
            expected,
            source,
            identity: identity,
            identity_root: container
          )
        end
      ensure
        P13NoiseEvidence.unseal_private_tree(container) if File.exist?(container)
      end
    end
  end

  def test_distribution_classification_mutation_is_rejected
    changed = deep_copy(distribution)
    rule = changed.fetch("path_rules").find do |candidate|
      candidate.fetch("origin_id") == "project-authored"
    end
    rule.fetch("path_prefixes").delete("tools/p13-noise-probe/")
    assert_failure("unclassified") do
      P13NoiseEvidence.validate_distribution(changed)
    end
  end

  def test_rust_registry_lock_tuple_source_and_checksum_mutations_are_rejected
    baseline = rust_registry_fixture
    assert(validate_rust_registry_fixture(baseline), "exact Rust registry fixture")

    mutations = [
      [
        "entry set differs",
        lambda do |changed|
          changed.fetch("package_sets").fetch("compiler_and_clippy")
            .last["version"] = "3.1.2"
        end
      ],
      [
        "registry source differs",
        lambda do |changed|
          changed.fetch("package_sets").fetch("compiler_and_clippy")
            .last["source"] = "registry+https://example.invalid/index"
        end
      ],
      [
        "tuple inventory differs",
        lambda do |changed|
          changed.fetch("package_sets").fetch("compiler_and_clippy")
            .last["checksum"] = "c" * 64
        end
      ],
      [
        "registry checksum is malformed",
        lambda do |changed|
          changed.fetch("package_sets").fetch("compiler_and_clippy")
            .last["checksum"] = nil
        end
      ],
      [
        "registry checksum is malformed",
        lambda do |changed|
          changed.fetch("package_sets").fetch("compiler_and_clippy")
            .first["source"] = P13NoiseEvidence::RUST_REGISTRY_SOURCE
        end
      ]
    ]
    mutations.each do |message, mutation|
      changed = deep_copy(baseline)
      mutation.call(changed)
      assert_failure(message) { validate_rust_registry_fixture(changed) }
    end
  end

  def test_rust_registry_cargo_license_mutation_is_rejected
    changed = rust_registry_fixture
    item = changed.fetch("entries").fetch("compiler_and_clippy").values.first
    manifest = item.fetch("manifest").sub(
      'license = "MPL-2.0"',
      'license = "BUSL-1.1"'
    )
    assert(manifest.include?("BUSL-1.1"), "BUSL mutation applied")
    checksum = P13NoiseEvidence.parse_json(
      item.fetch("checksum"),
      "FIXTURE_TECNICA checksum"
    )
    checksum.fetch("files").delete("Cargo.toml")
    checksum.fetch("files")["Cargo.toml"] = Digest::SHA256.hexdigest(manifest)
    item["manifest"] = manifest
    item["checksum"] = JSON.generate(checksum)
    assert_failure("license expression is not approved: BUSL-1.1") do
      validate_rust_registry_fixture(changed)
    end
  end

  def test_rust_registry_checksum_and_legal_file_mutations_are_rejected
    assert(
      P13NoiseEvidence.rust_registry_legal_file_path?(
        "bindings/vb6/Apache_2.0_License.txt"
      ),
      "nested legal keyword basename"
    )
    assert(
      P13NoiseEvidence.rust_registry_legal_file_path?(
        "curl/LICENSES/curl.txt"
      ),
      "exact legal directory component"
    )
    assert(
      P13NoiseEvidence.rust_registry_legal_file_path?(
        "libgit2/git.git-authors"
      ),
      "legal keyword within basename"
    )
    %w[
      THIRD_PARTY.txt
      docs/ACKNOWLEDGEMENTS.md
      docs/ATTRIBUTION
      docs/COPYLEFT.txt
      docs/CREDIT
      docs/LEGAL.md
      docs/PACKAGER
      docs/PATENT
      docs/RIGHTS.txt
      docs/THIRDPARTY.txt
      capstone/CREDITS.TXT
      xz-5.2/PACKAGERS
      xz-5.2/THANKS
    ].each do |path|
      assert(
        P13NoiseEvidence.rust_registry_legal_file_path?(path),
        "additional legal basename #{path}"
      )
    end
    assert(
      !P13NoiseEvidence.rust_registry_legal_file_path?(
        "src/FIXTURE_TECNICA_licensee.rs"
      ),
      "non-legal partial word"
    )
    assert(
      !P13NoiseEvidence.rust_registry_legal_file_path?(
        "curl/LICENSEISH/FIXTURE_TECNICA.txt"
      ),
      "nonexact legal directory"
    )

    %w[
      docs/ACKNOWLEDGEMENTS.md
      docs/THIRDPARTY.txt
    ].each do |path|
      coherent_alias = rust_registry_fixture
      item = coherent_alias.fetch("entries")
        .fetch("compiler_and_clippy").values.first
      notice = "FIXTURE_TECNICA_CONVENTIONAL_NOTICE\n"
      checksum = P13NoiseEvidence.parse_json(
        item.fetch("checksum"),
        "FIXTURE_TECNICA checksum"
      )
      checksum.fetch("files")[path] = Digest::SHA256.hexdigest(notice)
      item.fetch("legal_paths") << path
      item.fetch("legal_paths").sort_by!(&:b)
      item.fetch("legal_files")[path] = notice
      item.fetch("content_files")[path] = notice
      item["checksum"] = JSON.generate(checksum)
      refresh_fixture_checksum_inventory(coherent_alias, "compiler_and_clippy")
      refresh_fixture_legal_inventory(coherent_alias, "compiler_and_clippy")
      refresh_fixture_content_scans(coherent_alias, "compiler_and_clippy")
      assert_failure("reviewed legal delta differs") do
        validate_rust_registry_fixture(coherent_alias)
      end
    end

    unchecked = rust_registry_fixture
    item = unchecked.fetch("entries")
      .fetch("compiler_and_clippy").values.first
    item.fetch("legal_files")["LICENSE"] =
      item.fetch("legal_files").fetch("LICENSE").sub("LICENSE", "LICENSF")
    assert_failure("legal checksum differs") do
      validate_rust_registry_fixture(unchecked)
    end

    coherent = rust_registry_fixture
    item = coherent.fetch("entries")
      .fetch("compiler_and_clippy").values.first
    legal = item.fetch("legal_files").fetch("LICENSE").sub("LICENSE", "LICENSF")
    checksum = P13NoiseEvidence.parse_json(
      item.fetch("checksum"),
      "FIXTURE_TECNICA checksum"
    )
    checksum.fetch("files").delete("LICENSE")
    checksum.fetch("files")["LICENSE"] = Digest::SHA256.hexdigest(legal)
    item.fetch("legal_files")["LICENSE"] = legal
    item.fetch("content_files")["LICENSE"] = legal
    item["checksum"] = JSON.generate(checksum)
    refresh_fixture_checksum_inventory(coherent, "compiler_and_clippy")
    refresh_fixture_content_scans(coherent, "compiler_and_clippy")
    assert_failure("legal inventory differs") do
      validate_rust_registry_fixture(coherent)
    end

    added = rust_registry_fixture
    item = added.fetch("entries").fetch("compiler_and_clippy").values.first
    notice = "FIXTURE_TECNICA_NON_OSI_NOTICE\n"
    checksum = P13NoiseEvidence.parse_json(
      item.fetch("checksum"),
      "FIXTURE_TECNICA checksum"
    )
    checksum.fetch("files")["LICENSES/BUSL-1.1.txt"] =
      Digest::SHA256.hexdigest(notice)
    item.fetch("legal_paths") << "LICENSES/BUSL-1.1.txt"
    item.fetch("legal_paths").sort_by!(&:b)
    item.fetch("legal_files")["LICENSES/BUSL-1.1.txt"] = notice
    item.fetch("content_files")["LICENSES/BUSL-1.1.txt"] = notice
    item["checksum"] = JSON.generate(checksum)
    refresh_fixture_checksum_inventory(added, "compiler_and_clippy")
    refresh_fixture_legal_inventory(added, "compiler_and_clippy")
    refresh_fixture_content_scans(added, "compiler_and_clippy")
    assert_failure("reviewed legal delta differs") do
      validate_rust_registry_fixture(added)
    end

    legacy_added = rust_registry_fixture
    item = legacy_added.fetch("entries")
      .fetch("compiler_and_clippy").values.first
    busl = "FIXTURE_TECNICA_NON_OSI_LEGACY_LICENSE\n"
    checksum = P13NoiseEvidence.parse_json(
      item.fetch("checksum"),
      "FIXTURE_TECNICA checksum"
    )
    checksum.fetch("files")["nested/LICENSE-BUSL-1.1.txt"] =
      Digest::SHA256.hexdigest(busl)
    item.fetch("legal_paths") << "nested/LICENSE-BUSL-1.1.txt"
    item.fetch("legal_paths").sort_by!(&:b)
    item.fetch("legal_files")["nested/LICENSE-BUSL-1.1.txt"] = busl
    item.fetch("content_files")["nested/LICENSE-BUSL-1.1.txt"] = busl
    item["checksum"] = JSON.generate(checksum)
    refresh_fixture_checksum_inventory(legacy_added, "compiler_and_clippy")
    refresh_fixture_legal_inventory(legacy_added, "compiler_and_clippy")
    refresh_fixture_content_scans(legacy_added, "compiler_and_clippy")
    assert_failure("legacy legal inventory differs") do
      validate_rust_registry_fixture(legacy_added)
    end

    deleted = rust_registry_fixture
    item = deleted.fetch("entries").fetch("compiler_and_clippy").values.first
    checksum = P13NoiseEvidence.parse_json(
      item.fetch("checksum"),
      "FIXTURE_TECNICA checksum"
    )
    checksum.fetch("files").delete("LICENSE")
    item.fetch("legal_paths").delete("LICENSE")
    item.fetch("legal_files").delete("LICENSE")
    item.fetch("content_files").delete("LICENSE")
    item["checksum"] = JSON.generate(checksum)
    refresh_fixture_checksum_inventory(deleted, "compiler_and_clippy")
    refresh_fixture_content_scans(deleted, "compiler_and_clippy")
    assert_failure("legal count differs") do
      validate_rust_registry_fixture(deleted)
    end
  end

  def add_coherent_fixture_content(fixture, path, bytes)
    closure = "compiler_and_clippy"
    item = fixture.fetch("entries").fetch(closure).values.first
    package = fixture.fetch("package_sets").fetch(closure)
      .find { |candidate| candidate.fetch("source") }
    package_checksum = "c" * 64
    package["checksum"] = package_checksum
    checksum = P13NoiseEvidence.parse_json(
      item.fetch("checksum"),
      "FIXTURE_TECNICA checksum"
    )
    checksum.delete("package")
    checksum["package"] = package_checksum
    checksum.fetch("files")[path] = Digest::SHA256.hexdigest(bytes)
    item.fetch("content_files")[path] = bytes
    item["checksum"] = JSON.generate(checksum)
    refresh_fixture_lock_tuple_inventory(fixture, closure)
    refresh_fixture_checksum_inventory(fixture, closure)
  end

  def test_rust_registry_arbitrary_terms_content_is_discovered
    {
      "TERMS.md" =>
        "FIXTURE_TECNICA Business Source License 1.1 terms\n",
      "docs/FIXTURE_TECNICA_conditions.data" =>
        "FIXTURE_TECNICA licensed under BUSL-1.1\n",
      "docs/FIXTURE_TECNICA_permission.data" =>
        "Permission is hereby granted, free of charge, to any person obtaining a copy\n",
      "docs/FIXTURE_TECNICA_wrapped_permission.data" =>
        "Permission is hereby\n" \
        "granted, free of charge, to any person obtaining a copy\n",
      "docs/FIXTURE_TECNICA_redistribution.data" =>
        "Redistribution and use in source and binary forms, with or without modification, are permitted\n",
      "docs/FIXTURE_TECNICA_apache.data" =>
        "Licensed under the Apache License, Version 2.0 (the License)\n",
      "docs/FIXTURE_TECNICA_mpl.data" =>
        "Mozilla Public\nLicense, Version 2.0\n",
      "docs/FIXTURE_TECNICA_noncommercial.data" =>
        "Use is non-commercial and for research purposes only.\n",
      "docs/FIXTURE_TECNICA_no_derivatives.data" =>
        "No derivative works are permitted.\n"
    }.each do |path, bytes|
      assert(
        !P13NoiseEvidence.rust_registry_legal_file_path?(path),
        "arbitrary witness filename #{path}"
      )
      changed = rust_registry_fixture
      add_coherent_fixture_content(changed, path, bytes)
      refresh_fixture_content_scans(
        changed,
        "compiler_and_clippy",
        refresh_witness_evidence: false
      )
      assert_failure("content witness inventory differs") do
        validate_rust_registry_fixture(changed)
      end
    end
  end

  def test_rust_registry_current_witness_requires_exact_disposition
    changed = rust_registry_fixture
    add_coherent_fixture_content(
      changed,
      "src/FIXTURE_TECNICA_origin.rs",
      "// ported from FIXTURE_TECNICA source released to the public domain\n"
    )
    refresh_fixture_content_scans(changed, "compiler_and_clippy")
    assert(
      validate_rust_registry_fixture(changed),
      "exact content witness disposition"
    )

    disposition = changed.fetch("record").fetch("registry_closures")
      .fetch("compiler_and_clippy").fetch("content_discovery")
      .fetch("witness_dispositions").find do |record|
        record.fetch("path").end_with?(
          "/src/FIXTURE_TECNICA_origin.rs"
        )
      end
    assert(disposition, "injected origin disposition")
    disposition.fetch("witness_rule_ids").delete(
      "NONSTANDARD_PUBLIC_DOMAIN"
    )
    assert_failure("content disposition precedence differs") do
      validate_rust_registry_fixture(changed)
    end

    changed = rust_registry_fixture
    add_coherent_fixture_content(
      changed,
      "src/FIXTURE_TECNICA_origin.rs",
      "// ported from FIXTURE_TECNICA source released to the public domain\n"
    )
    refresh_fixture_content_scans(changed, "compiler_and_clippy")
    disposition = changed.fetch("record").fetch("registry_closures")
      .fetch("compiler_and_clippy").fetch("content_discovery")
      .fetch("witness_dispositions").find do |record|
        record.fetch("path").end_with?(
          "/src/FIXTURE_TECNICA_origin.rs"
        )
      end
    assert(disposition, "injected mixed-witness disposition")
    disposition["rights"] = "PACKAGE_GRANT_AND_RETAINED_ORIGIN_NOTICE"
    disposition["rights_status"] =
      "REVIEWED_PACKAGE_RIGHTS_WITH_EXACT_FILE_WITNESS"
    disposition["disposition"] =
      "ORIGIN_STATEMENT_RETAINED_UNDER_PACKAGE_GRANT"
    assert_failure("content disposition precedence differs") do
      validate_rust_registry_fixture(changed)
    end

    changed = rust_registry_fixture
    add_coherent_fixture_content(
      changed,
      "src/FIXTURE_TECNICA_origin.rs",
      "// ported from FIXTURE_TECNICA source released to the public domain\n"
    )
    refresh_fixture_content_scans(changed, "compiler_and_clippy")
    disposition = changed.fetch("record").fetch("registry_closures")
      .fetch("compiler_and_clippy").fetch("content_discovery")
      .fetch("witness_dispositions").find do |record|
        record.fetch("path").end_with?(
          "/src/FIXTURE_TECNICA_origin.rs"
        )
      end
    assert(disposition, "injected origin disposition")
    disposition["rights"] = "RIGHTS_ASSERTED_WITHOUT_LICENSE_BINDING"
    disposition["rights_status"] = "TECHNICAL_ATTESTATION_ONLY"
    disposition["reachability"] = "ARBITRARY_REACHABILITY_ASSERTION"
    disposition["disposition"] = "ACCEPT_WITHOUT_ENUMERATED_SEMANTICS"
    assert_failure("content disposition is unsupported") do
      validate_rust_registry_fixture(changed)
    end
  end

  def test_registry_dispositions_bind_copied_sources_and_reachability
    copied_cases = {
      "vendor/pulldown-cmark-0.11.3/src/utils.rs" => [
        "ALTERNATIVE_GPL_FAMILY",
        %w[
          PACKAGE_OSI_LICENSE_ELECTION
          REVIEWED_OSI_ELECTION_RETAINED
          ACTIVE_LOCK_GRAPH_ONLY_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14
          ALTERNATIVE_GRANT_NOT_USED_AS_P13_LICENSE_ELECTION
        ]
      ],
      "vendor/tracing-subscriber-0.3.20/src/registry/extensions.rs" => [
        "ORIGIN_DERIVED_OR_COPIED",
        %w[
          PACKAGE_GRANT_AND_RETAINED_ORIGIN_NOTICE
          REVIEWED_PACKAGE_RIGHTS_WITH_EXACT_FILE_WITNESS
          ACTIVE_LOCK_GRAPH_ONLY_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14
          ORIGIN_STATEMENT_RETAINED_UNDER_PACKAGE_GRANT
        ]
      ]
    }
    copied_cases.each do |path, (rule, weaker_tuple)|
      bytes = 64
      sha256 = Digest::SHA256.hexdigest(path)
      witness_rows = [[path, bytes, sha256, 1, "a" * 64, rule]]
      exact =
        P13NoiseEvidence::RUST_COPIED_SOURCE_DISPOSITIONS.fetch(path)
      disposition = {
        "path" => path,
        "bytes" => bytes,
        "sha256" => sha256,
        "witness_rule_ids" => [rule],
        "rights" => exact.fetch(0),
        "rights_status" => exact.fetch(1),
        "reachability" => exact.fetch(2),
        "disposition" => exact.fetch(3)
      }
      assert(
        P13NoiseEvidence.validate_rust_registry_content_dispositions(
          [disposition],
          witness_rows,
          "FIXTURE_TECNICA copied source"
        ),
        "exact copied-source tuple #{path}"
      )
      changed = deep_copy(disposition)
      changed["rights"] = weaker_tuple.fetch(0)
      changed["rights_status"] = weaker_tuple.fetch(1)
      changed["reachability"] = weaker_tuple.fetch(2)
      changed["disposition"] = weaker_tuple.fetch(3)
      assert_failure("copied-source disposition differs") do
        P13NoiseEvidence.validate_rust_registry_content_dispositions(
          [changed],
          witness_rows,
          "FIXTURE_TECNICA copied source"
        )
      end
    end

    directory = "vendor/FIXTURE_TECNICA-1.0.0"
    path = "#{directory}/LICENSE-MIT"
    bytes = 32
    sha256 = Digest::SHA256.hexdigest(path)
    witness_rows = [
      [
        path,
        bytes,
        sha256,
        1,
        "b" * 64,
        "PERMISSIVE_MIT_OR_UNICODE_GRANT"
      ]
    ]
    disposition = {
      "path" => path,
      "bytes" => bytes,
      "sha256" => sha256,
      "witness_rule_ids" => ["PERMISSIVE_MIT_OR_UNICODE_GRANT"],
      "rights" => "PERMISSIVE_GRANT_IN_CHECKSUM_BOUND_PACKAGE",
      "rights_status" => "OSI_COMPATIBLE_GRANT_REVIEWED",
      "reachability" =>
        "ACTIVE_LOCK_GRAPH_ONLY_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14",
      "disposition" => "PERMISSIVE_GRANT_RETAINED_AND_ELECTION_BOUND"
    }
    assert_failure("disposition reachability differs") do
      P13NoiseEvidence.validate_rust_registry_content_dispositions(
        [disposition],
        witness_rows,
        "FIXTURE_TECNICA reachability",
        expected_reachability: {
          directory => "UNREACHABLE_FROM_SELECTED_LOCK_GRAPH"
        }
      )
    end
  end

  def test_rust_registry_technical_derived_from_noise_is_not_an_origin
    definitions = Array.new(
      P13NoiseEvidence::RUST_REGISTRY_CONTENT_LIMITS.fetch(
        "max_witnesses_per_file"
      ) + 1,
      "FIXTURE_TECNICA compound derived from another compound\n"
    ).join
    witnesses = P13NoiseEvidence.rust_registry_content_witness_rows(
      "vendor/FIXTURE_TECNICA/benches/definitions",
      definitions,
      definitions.bytesize,
      Digest::SHA256.hexdigest(definitions)
    )
    assert(witnesses.empty?, "technical origin-word noise is excluded")

    provenance =
      "// FIXTURE_TECNICA implementation derived from OpenBSD source\n"
    witnesses = P13NoiseEvidence.rust_registry_content_witness_rows(
      "vendor/FIXTURE_TECNICA/src/lib.rs",
      provenance,
      provenance.bytesize,
      Digest::SHA256.hexdigest(provenance)
    )
    assert(
      witnesses.map { |row| row.fetch(5) } ==
        ["ORIGIN_DERIVED_OR_COPIED"],
      "commented source provenance remains discoverable"
    )
  end

  def test_path_source_origin_vocabulary_and_cc0_escape_are_exact
    bytes =
      "FIXTURE_TECNICA_PRELUDE\n" \
      "// Implementation based on FIXTURE_TECNICA source.\n" \
      "//! Mergesort inspired by FIXTURE_TECNICA source.\n" \
      "// Ported from FIXTURE_TECNICA source.\n" \
      "const FIXTURE: char = '\\u{cc0}';\n"
    rows = P13NoiseEvidence.rust_registry_content_witness_rows(
      "library/FIXTURE_TECNICA.rs",
      bytes,
      bytes.bytesize,
      Digest::SHA256.hexdigest(bytes)
    )
    assert(
      rows.map { |row| row.values_at(3, 5) } == [
        [2, "ORIGIN_BASED_OR_INSPIRED"],
        [3, "ORIGIN_BASED_OR_INSPIRED"],
        [4, "ORIGIN_TRANSLATED_OR_PORTED"]
      ],
      "based, inspired, and non-first-line ported origins are discovered"
    )

    cc0 = "# SPDX-License-Identifier: CC0-1.0\n"
    rows = P13NoiseEvidence.rust_registry_content_witness_rows(
      "library/FIXTURE_TECNICA_LICENSE",
      cc0,
      cc0.bytesize,
      Digest::SHA256.hexdigest(cc0)
    )
    assert(
      rows.any? { |row| row.fetch(5) == "NONSTANDARD_CC0" },
      "actual CC0 license text remains discoverable"
    )
  end

  def test_path_source_reviewer_origin_counterexamples_are_discovered
    {
      "wrapped based-on comment" => [
        "// Implementation based\n" \
          "// on FIXTURE_TECNICA source.\n",
        1,
        "ORIGIN_BASED_OR_INSPIRED"
      ],
      "non-first-line bare copied-from comment" => [
        "FIXTURE_TECNICA_PRELUDE\n" \
          "// Copied from FIXTURE_TECNICA source.\n",
        2,
        "ORIGIN_DERIVED_OR_COPIED"
      ],
      "bare based-on comment" => [
        "// Based on FIXTURE_TECNICA source.\n",
        1,
        "ORIGIN_BASED_OR_INSPIRED"
      ],
      "wrapped copied-from verb" => [
        "// Copied\n// from FIXTURE_TECNICA source.\n",
        1,
        "ORIGIN_DERIVED_OR_COPIED"
      ],
      "wrapped copied-from target" => [
        "// Copied from\n// FIXTURE_TECNICA source.\n",
        1,
        "ORIGIN_DERIVED_OR_COPIED"
      ],
      "non-first-line wrapped derived origin" => [
        "FIXTURE_TECNICA_PRELUDE\n" \
          "// Derived\n// from OpenBSD.\n",
        2,
        "ORIGIN_DERIVED_OR_COPIED"
      ],
      "non-first-line wrapped adapted origin" => [
        "FIXTURE_TECNICA_PRELUDE\n" \
          "//! Adapted from\n//! [styled_buffer]\n",
        2,
        "ORIGIN_DERIVED_OR_COPIED"
      ],
      "non-first-line wrapped copied origin" => [
        "FIXTURE_TECNICA_PRELUDE\n" \
          "// Copied\n// from OpenBSD.\n",
        2,
        "ORIGIN_DERIVED_OR_COPIED"
      ],
      "terse named origin" => [
        "// Copied from OpenBSD.\n",
        1,
        "ORIGIN_DERIVED_OR_COPIED"
      ],
      "qualified arm copied from lowercase project" => [
        "FIXTURE_TECNICA_PRELUDE\n" \
          "// Address::Constant arm copied from gimli\n",
        2,
        "ORIGIN_DERIVED_OR_COPIED"
      ],
      "reference-link origin" => [
        "//! Adapted from [styled_buffer]\n" \
          "//!\n" \
          "//! [styled_buffer]: https://example.invalid/source\n",
        1,
        "ORIGIN_DERIVED_OR_COPIED"
      ],
      "possessive file origin" => [
        "// Derived from object's round_trip.rs:\n" \
          "// https://example.invalid/source\n",
        1,
        "ORIGIN_DERIVED_OR_COPIED"
      ],
      "wrapped named source" => [
        "//! The following is derived from Rust's\n" \
          "//! library/std/src/io/mod.rs\n",
        1,
        "ORIGIN_DERIVED_OR_COPIED"
      ],
      "wrapped c-comment inspiration" => [
        "/* techniques heavily inspired\n" \
          "   by nmap and ncat (https://nmap.org/ncat/) */\n",
        1,
        "ORIGIN_BASED_OR_INSPIRED"
      ],
      "backticked module origin" => [
        "// FIXTURE_TECNICA implementation derived from `weak` in Rust's\n" \
          "// library/std/src/sys/unix/weak.rs at revision abcdef.\n",
        1,
        "ORIGIN_DERIVED_OR_COPIED"
      ],
      "named content origin" => [
        ";; Some FIXTURE_TECNICA content here is derived from " \
          "[CloudABI](https://example.invalid/source).\n",
        1,
        "ORIGIN_DERIVED_OR_COPIED"
      ],
      "bstr adapted origin" => [
        "// This is adapted from `fallback.rs` from rust-memchr. It's modified to return\n" \
          "// the 'inverse' query of memchr.\n",
        1,
        "ORIGIN_DERIVED_OR_COPIED"
      ],
      "fluent context origin" => [
        "The following context is extracted from\n" \
          "the `browser.xhtml` localization context\n" \
          "from mozilla-central rev 51efc4b931f7\n" \
          "from 2020-03-03.\n",
        1,
        "ORIGIN_DERIVED_OR_COPIED"
      ],
      "objc2 heavily copied origin" => [
        "//! Heavily copied from:\n" \
          "//! <https://github.com/rust-lang/rust/pull/138944>\n",
        1,
        "ORIGIN_DERIVED_OR_COPIED"
      ]
    }.each do |name, (bytes, line, rule)|
      rows = P13NoiseEvidence.rust_registry_content_witness_rows(
        "library/FIXTURE_TECNICA_#{name.tr(' ', '_')}.rs",
        bytes,
        bytes.bytesize,
        Digest::SHA256.hexdigest(bytes)
      )
      assert(
        rows.any? do |row|
          row.fetch(3) == line && row.fetch(5) == rule
        end,
        name
      )
    end

    [
      "/// copied from src to dst when a mask bit is not set.\n",
      "/// copied from source to destination when a mask bit is set.\n",
      "/// pointer derived from it. Use [`as_mut_ptr`] to mutate it.\n",
      "// copied from `eat_identifier`, but allows dots.\n",
      "// Based on whether the queue is empty.\n",
      "FIXTURE_TECNICA code cannot be divided based\n" \
        "on binary size and compile time goals.\n"
    ].each do |technical|
      rows = P13NoiseEvidence.rust_registry_content_witness_rows(
        "library/FIXTURE_TECNICA_avx.rs",
        technical,
        technical.bytesize,
        Digest::SHA256.hexdigest(technical)
      )
      assert(
        rows.none? { |row| row.fetch(5).start_with?("ORIGIN_") },
        "technical origin vocabulary is not external provenance: #{technical}"
      )
    end

    genuine_then_technical =
      "// Copied from OpenBSD.\n" \
      "// pointer derived from it. Use `as_mut_ptr` to mutate it.\n"
    rows = P13NoiseEvidence.rust_registry_content_witness_rows(
      "library/FIXTURE_TECNICA_statement_scope.rs",
      genuine_then_technical,
      genuine_then_technical.bytesize,
      Digest::SHA256.hexdigest(genuine_then_technical)
    )
    assert(
      rows.map { |row| row.values_at(3, 5) } ==
        [[1, "ORIGIN_DERIVED_OR_COPIED"]],
      "later technical prose cannot suppress an earlier origin witness"
    )

    genuine_then_technical_same_line =
      "// Copied from OpenBSD. pointer derived from it.\n"
    rows = P13NoiseEvidence.rust_registry_content_witness_rows(
      "library/FIXTURE_TECNICA_same_statement_scope.rs",
      genuine_then_technical_same_line,
      genuine_then_technical_same_line.bytesize,
      Digest::SHA256.hexdigest(genuine_then_technical_same_line)
    )
    assert(
      rows.map { |row| row.values_at(3, 5) } ==
        [[1, "ORIGIN_DERIVED_OR_COPIED"]],
      "later same-line technical prose cannot suppress an origin statement"
    )
  end

  def test_origin_rejection_regex_options_are_digest_bound
    bytes = "// BASED ON WHETHER FIXTURE_TECNICA source is selected.\n"
    baseline_rows = P13NoiseEvidence.rust_registry_content_witness_rows(
      "library/FIXTURE_TECNICA_rejection_options.rs",
      bytes,
      bytes.bytesize,
      Digest::SHA256.hexdigest(bytes)
    )
    assert(
      baseline_rows.none? { |row| row.fetch(5) == "ORIGIN_BASED_OR_INSPIRED" },
      "case-insensitive technical rejection is active"
    )

    original = P13NoiseEvidence::RUST_ORIGIN_REJECTION_PATTERNS
    original_digest =
      P13NoiseEvidence.rust_registry_content_vocabulary_sha256
    changed = original.merge(
      "ORIGIN_BASED_OR_INSPIRED" => Regexp.new(
        original.fetch("ORIGIN_BASED_OR_INSPIRED").source,
        original.fetch("ORIGIN_BASED_OR_INSPIRED").options &
          ~Regexp::IGNORECASE
      )
    ).freeze
    P13NoiseEvidence.send(:remove_const, :RUST_ORIGIN_REJECTION_PATTERNS)
    P13NoiseEvidence.const_set(:RUST_ORIGIN_REJECTION_PATTERNS, changed)
    assert(
      P13NoiseEvidence.rust_registry_content_vocabulary_sha256 !=
        original_digest,
      "rejection regex options change the vocabulary digest"
    )
    changed_rows = P13NoiseEvidence.rust_registry_content_witness_rows(
      "library/FIXTURE_TECNICA_rejection_options.rs",
      bytes,
      bytes.bytesize,
      Digest::SHA256.hexdigest(bytes)
    )
    assert(
      changed_rows.any? { |row| row.fetch(5) == "ORIGIN_BASED_OR_INSPIRED" },
      "removing IGNORECASE changes the technical control"
    )
  ensure
    if defined?(original) && original
      P13NoiseEvidence.send(:remove_const, :RUST_ORIGIN_REJECTION_PATTERNS)
      P13NoiseEvidence.const_set(
        :RUST_ORIGIN_REJECTION_PATTERNS,
        original
      )
    end
  end

  def test_user_decision_traceability_is_complete_and_contiguous
    decisions = File.binread(
      File.join(P13NoiseEvidence::ROOT, P13NoiseEvidence::USER_DECISIONS)
    )
    traceability = File.binread(
      File.join(
        P13NoiseEvidence::ROOT,
        P13NoiseEvidence::REQUIREMENTS_TRACEABILITY
      )
    )
    manifest = P13NoiseEvidence.read_yaml(
      File.join(
        P13NoiseEvidence::ROOT,
        P13NoiseEvidence::REQUIREMENTS_MANIFEST
      )
    )
    assert(
      P13NoiseEvidence.validate_user_decision_traceability_bytes(
        decisions,
        traceability,
        manifest
      ),
      "complete contiguous governance trace"
    )

    changed = decisions.sub(/^\| `USR-036` \|.*\n/, "")
    assert_failure("not contiguous or omit USR-039") do
      P13NoiseEvidence.validate_user_decision_traceability_bytes(
        changed,
        traceability,
        manifest
      )
    end

    changed = traceability.sub(/^\| `USR-039` \|.*\n/, "")
    assert_failure("traceability set differs") do
      P13NoiseEvidence.validate_user_decision_traceability_bytes(
        decisions,
        changed,
        manifest
      )
    end

    changed = deep_copy(manifest)
    changed.fetch("required_ids").delete("USR-039")
    assert_failure("manifest set differs") do
      P13NoiseEvidence.validate_user_decision_traceability_bytes(
        decisions,
        traceability,
        changed
      )
    end

    spaced = decisions.sub(
      /^\| `USR-039` \|/,
      " \t| `USR-039`  |"
    ).sub(
      /^\s*\| `USR-039` .*$/,
      "\\0 \t"
    )
    assert(
      P13NoiseEvidence.validate_user_decision_traceability_bytes(
        spaced,
        traceability,
        manifest
      ),
      "harmless decision-table delimiter whitespace is parsed"
    )
    governance_ids = GovernanceValidator.allocate.send(
      :user_decision_ids_from_bytes,
      spaced
    )
    assert(
      governance_ids.last == "USR-039" &&
        governance_ids.length == 39,
      "governance validator parses harmless decision-table whitespace"
    )

    future_decisions = decisions.sub(
      /^\| `USR-039` .*$/,
      "\\0\n| `USR-040` | FIXTURE_TECNICA future decision. | MUST | " \
        "P13-FINAL | FIXTURE_TECNICA future constraint. |"
    )
    future_traceability = traceability.sub(
      /^\| `USR-039` .*$/,
      "\\0\n| `USR-040` | User | FIXTURE_TECNICA future decision. | " \
        "P13, FINAL | FIXTURE_TECNICA verification | " \
        "FIXTURE_TECNICA evidence | PENDING |"
    )
    future_manifest = deep_copy(manifest)
    index = future_manifest.fetch("required_ids").index("USR-039")
    future_manifest.fetch("required_ids").insert(index + 1, "USR-040")
    assert(
      P13NoiseEvidence.validate_user_decision_traceability_bytes(
        future_decisions,
        future_traceability,
        future_manifest
      ),
      "future contiguous decision rows are not rejected by a fixed ceiling"
    )

    malformed_decisions = [
      "| `USR_039` | FIXTURE_TECNICA | MUST | P13 | consequence |\n",
      "| `USR-039X` | FIXTURE_TECNICA | MUST | P13 | consequence |\n",
      "| `USR-039 ` | FIXTURE_TECNICA | MUST | P13 | consequence |\n",
      "| `USR-039` |\n",
      "| `USR-039` | FIXTURE_TECNICA | MUST | P13 |\n",
      "| `USR-039` | FIXTURE_TECNICA | MUST | P13 | consequence | extra |\n",
      "| `USR-039` | | MUST | P13 | consequence |\n",
      "| **USR_039** | FIXTURE_TECNICA | MUST | P13 | consequence |\n",
      "| <code>USR_039</code> | FIXTURE_TECNICA | MUST | P13 | consequence |\n",
      "`USR-039` | FIXTURE_TECNICA | MUST | P13 | consequence |\n",
      "| `USR-039` | FIXTURE_TECNICA | MUST | P13 | consequence\n"
    ]
    malformed_decisions.each do |row|
      changed = decisions.sub(/^\| `USR-039` .*$/, "\\0\n#{row.rstrip}")
      assert_failure("malformed ID row") do
        P13NoiseEvidence.validate_user_decision_traceability_bytes(
          changed,
          traceability,
          manifest
        )
      end
      begin
        GovernanceValidator.allocate.send(
          :user_decision_ids_from_bytes,
          changed
        )
        raise "expected GovernanceError"
      rescue GovernanceError => error
        assert(
          error.message.include?("malformed user decision row"),
          "governance malformed-row failure"
        )
      end
    end

    malformed_trace = traceability.sub(
      /^\| `USR-039` .*$/,
      "\\0\n| `USR_039` | User | FIXTURE_TECNICA | P13 | test | " \
        "evidence | PENDING |"
    )
    assert_failure("malformed ID row") do
      P13NoiseEvidence.validate_user_decision_traceability_bytes(
        decisions,
        malformed_trace,
        manifest
      )
    end
  end

  def test_path_source_special_license_dispositions_are_fail_closed
    intel_fixture = <<~TEXT
      # FIXTURE_TECNICA license prelude.
      # Unless the License provides otherwise, you may not use, modify,
      # copy, publish, distribute, disclose or transmit this software or the
      # documents without the owner's prior written permission.
    TEXT
    intel_rows = P13NoiseEvidence.rust_registry_content_witness_rows(
      P13NoiseEvidence::RUST_PATH_SOURCE_INTEL_REJECTION.fetch("path"),
      intel_fixture,
      intel_fixture.bytesize,
      Digest::SHA256.hexdigest(intel_fixture)
    )
    assert(
      intel_rows.any? do |row|
        row.fetch(5) == "RESTRICTIVE_PRIOR_WRITTEN_PERMISSION"
      end,
      "comment-prefixed Intel restriction wording is discovered"
    )

    loongarch_fixture = <<~TEXT
      /* FIXTURE_TECNICA license prelude.
         This file is distributed under the terms of the GNU General Public License
         as published by the Free Software Foundation; either version 3, or (at your
         option) any later version.

         Under Section 7, additional permissions are described in the
         GCC Runtime Library Exception, version 3.1. */
    TEXT
    loongarch_rows = P13NoiseEvidence.rust_registry_content_witness_rows(
      P13NoiseEvidence::RUST_PATH_SOURCE_LOONGARCH_HEADERS.first.fetch("path"),
      loongarch_fixture,
      loongarch_fixture.bytesize,
      Digest::SHA256.hexdigest(loongarch_fixture)
    )
    assert(
      loongarch_rows.any? do |row|
        row.fetch(5) ==
          "ALTERNATIVE_GPL_3_OR_LATER_WITH_GCC_EXCEPTION_3_1"
      end,
      "GPL-3.0-or-later with GCC-exception-3.1 wording is discovered"
    )

    dispositions = evidence.fetch("toolchain_source_closure")
      .fetch("path_source_closures").fetch("sysroot")
      .fetch("witness_dispositions")
    rows = dispositions.flat_map do |record|
      record.fetch("witness_rule_ids").map do |rule|
        [
          record.fetch("path"),
          record.fetch("bytes"),
          record.fetch("sha256"),
          1,
          "0" * 64,
          rule
        ]
      end
    end
    assert(
      P13NoiseEvidence.validate_rust_path_source_dispositions(
        dispositions,
        rows,
        "sysroot"
      ),
      "exact Intel rejection and LoongArch exception dispositions"
    )

    changed = deep_copy(dispositions)
    changed.find do |record|
      record.fetch("path") ==
        P13NoiseEvidence::RUST_PATH_SOURCE_INTEL_REJECTION.fetch("path")
    end["rights_status"] = "SELECTED_PATH_SOURCE_RIGHTS_REVIEWED"
    assert_failure("Intel CPUID rejection disposition differs") do
      P13NoiseEvidence.validate_rust_path_source_dispositions(
        changed,
        rows,
        "sysroot"
      )
    end

    changed = deep_copy(dispositions)
    changed.find do |record|
      P13NoiseEvidence::RUST_PATH_SOURCE_LOONGARCH_HEADERS.any? do |header|
        header.fetch("path") == record.fetch("path")
      end
    end["rights"] = "RUST_SOURCE_OSI_ELECTION_OR_EXCEPTION"
    assert_failure("LoongArch GCC exception disposition differs") do
      P13NoiseEvidence.validate_rust_path_source_dispositions(
        changed,
        rows,
        "sysroot"
      )
    end
  end

  def test_rust_registry_witness_limit_is_enforced_during_scan
    grant = "Permission is hereby granted, free of charge\n"
    limit = P13NoiseEvidence::RUST_REGISTRY_CONTENT_LIMITS.fetch(
      "max_witnesses_per_file"
    )
    bytes = Array.new(limit + 1, grant).join
    assert_failure("file witness count is excessive") do
      P13NoiseEvidence.rust_registry_content_witness_rows(
        "vendor/FIXTURE_TECNICA/TERMS",
        bytes,
        bytes.bytesize,
        Digest::SHA256.hexdigest(bytes)
      )
    end
  end

  def test_rust_archive_extraction_is_nul_safe_and_bounded
    list = P13NoiseEvidence.rust_archive_member_list(
      ["root/FIXTURE_TECNICA\nname", "root/FIXTURE_TECNICA_other"],
      "FIXTURE_TECNICA extraction"
    )
    assert(
      list == "root/FIXTURE_TECNICA\nname\0root/FIXTURE_TECNICA_other\0",
      "newline-bearing archive paths remain one NUL-delimited member"
    )

    file_limit =
      P13NoiseEvidence::RUST_REGISTRY_CONTENT_LIMITS.fetch(
        "max_bytes_per_file"
      )
    closure_limit =
      P13NoiseEvidence::RUST_REGISTRY_CONTENT_LIMITS.fetch(
        "max_bytes_per_closure"
      )
    assert(
      P13NoiseEvidence.bounded_rust_extraction_bytes(
        closure_limit - file_limit,
        file_limit,
        "FIXTURE_TECNICA extraction"
      ) == closure_limit,
      "exact extraction byte limits are accepted"
    )
    assert_failure("excessive file") do
      P13NoiseEvidence.bounded_rust_extraction_bytes(
        0,
        file_limit + 1,
        "FIXTURE_TECNICA extraction"
      )
    end
    assert_failure("extraction is excessive") do
      P13NoiseEvidence.bounded_rust_extraction_bytes(
        closure_limit,
        1,
        "FIXTURE_TECNICA extraction"
      )
    end

    member_limit =
      P13NoiseEvidence::RUST_REGISTRY_CONTENT_LIMITS.fetch(
        "max_files_per_closure"
      )
    assert_failure("member inventory is excessive") do
      P13NoiseEvidence.rust_archive_member_list(
        Array.new(member_limit + 1) do |index|
          "root/FIXTURE_TECNICA_#{index}"
        end,
        "FIXTURE_TECNICA extraction"
      )
    end

    depth_limit = P13NoiseEvidence::RUST_REGISTRY_CONTENT_LIMITS.fetch(
      "max_archive_path_depth"
    )
    exact_depth = Array.new(depth_limit, "a").join("/")
    assert(
      P13NoiseEvidence.rust_archive_member_list(
        [exact_depth],
        "FIXTURE_TECNICA extraction"
      ) == "#{exact_depth}\0",
      "archive member at the exact path-depth limit is accepted"
    )
    assert_failure("path is too deeply nested") do
      P13NoiseEvidence.rust_archive_member_list(
        [Array.new(depth_limit + 1, "a").join("/")],
        "FIXTURE_TECNICA extraction"
      )
    end

    regular = P13NoiseEvidence.rust_archive_verbose_entry(
      "-rw-r--r--  0 0      0          12 Jul 23  2006 " \
        "FIXTURE_TECNICA/root/file\n",
      "FIXTURE_TECNICA",
      "FIXTURE_TECNICA archive"
    )
    assert(
      regular == {
        "path" => "root/file",
        "type" => "file",
        "bytes" => 12,
        "target" => nil
      },
      "regular archive metadata is parsed before extraction"
    )
    assert(
      P13NoiseEvidence.validate_rust_archive_regular_preflight(
        [regular],
        ["root/file"],
        "FIXTURE_TECNICA archive"
      ) == 12,
      "bounded regular metadata is accepted before extraction"
    )
    symlink = P13NoiseEvidence.rust_archive_verbose_entry(
      "lrwxr-xr-x  0 0      0           0 Jul 23  2006 " \
        "FIXTURE_TECNICA/root/link -> ../file\n",
      "FIXTURE_TECNICA",
      "FIXTURE_TECNICA archive"
    )
    assert_failure("member type is unsupported") do
      P13NoiseEvidence.validate_rust_archive_regular_preflight(
        [symlink],
        ["root/link"],
        "FIXTURE_TECNICA archive"
      )
    end
    oversized = regular.merge("bytes" => file_limit + 1)
    assert_failure("excessive file") do
      P13NoiseEvidence.validate_rust_archive_regular_preflight(
        [oversized],
        ["root/file"],
        "FIXTURE_TECNICA archive"
      )
    end
    assert_failure("preflight path set differs") do
      P13NoiseEvidence.validate_rust_archive_regular_preflight(
        [regular],
        ["root/other"],
        "FIXTURE_TECNICA archive"
      )
    end
    assert_failure("listing line is malformed") do
      P13NoiseEvidence.rust_archive_verbose_entry(
        "-rw-r--r--  0 0 0 12 Jul 23 2006 " \
          "FIXTURE_TECNICA/root/\ncontrol\n",
        "FIXTURE_TECNICA",
        "FIXTURE_TECNICA archive"
      )
    end
  end

  def test_child_output_is_bounded_while_it_is_consumed
    limit = 64
    exact = "X" * limit
    stdout, stderr, status = P13NoiseEvidence.capture3_bounded(
      {},
      [
        RbConfig.ruby,
        "--disable-gems",
        "-e",
        "STDOUT.binmode; STDOUT.write('X' * #{limit})"
      ],
      {close_others: true},
      stdin_data: nil,
      stdout_limit: limit,
      stderr_limit: limit,
      context: "FIXTURE_TECNICA bounded child",
      prohibit_descendants: true
    )
    assert(
      status.success? && stdout == exact && stderr.empty?,
      "exact child-output limit is accepted"
    )

    assert_failure("stdout is excessive") do
      Timeout.timeout(5) do
        P13NoiseEvidence.capture3_bounded(
          {},
          [
            RbConfig.ruby,
            "--disable-gems",
            "-e",
            "STDOUT.binmode; STDOUT.write('X' * #{limit + 1}); " \
              "STDOUT.flush; sleep 30"
          ],
          {close_others: true},
          stdin_data: nil,
          stdout_limit: limit,
          stderr_limit: limit,
          context: "FIXTURE_TECNICA bounded child",
          prohibit_descendants: true
        )
      end
    end

    assert_failure("stderr is excessive") do
      Timeout.timeout(5) do
        P13NoiseEvidence.capture3_bounded(
          {},
          [
            RbConfig.ruby,
            "--disable-gems",
            "-e",
            "STDERR.binmode; STDERR.write('X' * #{limit + 1}); " \
              "STDERR.flush; sleep 30"
          ],
          {close_others: true},
          stdin_data: nil,
          stdout_limit: limit,
          stderr_limit: limit,
          context: "FIXTURE_TECNICA bounded child",
          prohibit_descendants: true
        )
      end
    end

    assert_failure("deadline exceeded") do
      P13NoiseEvidence.capture3_bounded(
        {},
        [
          RbConfig.ruby,
          "--disable-gems",
          "-e",
          "sleep 30"
        ],
        {close_others: true},
        stdin_data: "X" * (1024 * 1024),
        stdout_limit: limit,
        stderr_limit: limit,
        context: "FIXTURE_TECNICA silent blocked child",
        prohibit_descendants: true,
        deadline_seconds: 0.2
      )
    end

    stdout, stderr, status = P13NoiseEvidence.capture3_bounded(
      {},
      [RbConfig.ruby, "--disable-gems", "-e", "exit 0"],
      {close_others: true},
      stdin_data: nil,
      stdout_limit: 0,
      stderr_limit: 0,
      context: "FIXTURE_TECNICA silent child",
      prohibit_descendants: true
    )
    assert(
      status.success? && stdout.empty? && stderr.empty?,
      "silent extraction child is accepted"
    )

    Dir.mktmpdir("p13-setsid-fixture-") do |directory|
      marker = File.join(directory, "escaped")
      code =
        "begin; child = fork do; Process.setsid; sleep 0.3; " \
        "File.binwrite(#{marker.dump}, Process.pid.to_s); end; " \
        "Process.wait(child); rescue Errno::EAGAIN; sleep 30; end"
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      assert_failure("deadline exceeded") do
        P13NoiseEvidence.capture3_bounded(
          {},
          [RbConfig.ruby, "--disable-gems", "-e", code],
          {close_others: true},
          stdin_data: nil,
          stdout_limit: 0,
          stderr_limit: 0,
          context: "FIXTURE_TECNICA setsid descendant",
          prohibit_descendants: true,
          deadline_seconds: 0.2
        )
      end
      sleep 0.3
      elapsed =
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      assert(!File.exist?(marker), "setsid descendant cannot escape containment")
      assert(elapsed < 1, "setsid descendant containment is bounded")
    end
  end

  def test_copied_source_byte_region_is_exact
    source = "FIXTURE_TECNICA_prefix_exact_region_suffix"
    start_byte = source.index("exact_region")
    region = "exact_region"
    record = {
      "start_byte" => start_byte,
      "end_byte" => start_byte + region.bytesize,
      "bytes" => region.bytesize,
      "sha256" => Digest::SHA256.hexdigest(region)
    }
    assert(
      P13NoiseEvidence.validate_exact_byte_region(
        source,
        record,
        "FIXTURE_TECNICA copied region"
      ) == region,
      "exact copied-source region"
    )
    changed = deep_copy(record)
    changed["end_byte"] += 1
    assert_failure("identity differs") do
      P13NoiseEvidence.validate_exact_byte_region(
        source,
        changed,
        "FIXTURE_TECNICA copied region"
      )
    end
    changed = deep_copy(record)
    changed["sha256"] = "0" * 64
    assert_failure("identity differs") do
      P13NoiseEvidence.validate_exact_byte_region(
        source,
        changed,
        "FIXTURE_TECNICA copied region"
      )
    end
  end

  def test_redwood_author_permission_identity_is_exact
    permission = evidence.fetch("toolchain_source_closure")
      .fetch("copied_source_origins")
      .fetch("pulldown_cmark_redwood")
      .fetch("author_permission")
    assert(
      P13NoiseEvidence.validate_redwood_relicense_grant(permission),
      "exact Redwood author permission"
    )

    changed = deep_copy(permission)
    changed["author_id"] = "FIXTURE_TECNICA_SUBSTITUTED_AUTHOR"
    assert_failure("fields differ") do
      P13NoiseEvidence.validate_redwood_relicense_grant(changed)
    end

    changed = deep_copy(permission)
    changed["body_sha256"] = "0" * 64
    assert_failure("fields differ") do
      P13NoiseEvidence.validate_redwood_relicense_grant(changed)
    end
  end

  def test_crate_replay_uses_the_bounded_acquisition_parser
    source = File.join(
      "/private/tmp/p13-snow-cargo-home/registry/cache",
      "index.crates.io-1949cf8c6b5b557f",
      "aead-0.5.2.crate"
    )
    entries = P13NoiseEvidence.crate_entries(source, "aead-0.5.2")
    assert(entries.key?("Cargo.toml"), "bounded parser returns crate files")
    assert(!entries.key?(".cargo-ok"), "synthetic extraction marker is omitted")
  end

  def test_excluded_notify_version_mutation_is_rejected
    closure = evidence.fetch("toolchain_source_closure")
    record = {
      "excluded_registry_package" =>
        deep_copy(closure.fetch("excluded_registry_package")),
      "excluded_rust_analyzer_notify_count" => 1
    }
    packages = [
      {
        "name" => "rust-analyzer",
        "version" => "0.0.0",
        "source" => nil,
        "checksum" => nil
      },
      deep_copy(record.fetch("excluded_registry_package")).reject do |key, _value|
        %w[component selected installed].include?(key)
      end
    ]
    assert(
      P13NoiseEvidence.validate_excluded_rust_analyzer_package(record, packages),
      "exact excluded notify identity"
    )
    packages.last["version"] = "8.2.1"
    assert_failure("excluded CC0 package segregation differs") do
      P13NoiseEvidence.validate_excluded_rust_analyzer_package(record, packages)
    end
  end

  def test_toolchain_provenance_llvm_license_mutation_is_rejected
    record = evidence.fetch("toolchain_source_closure")
    provenance = P13NoiseEvidence.read_yaml(
      File.join(
        P13NoiseEvidence::ROOT,
        P13NoiseEvidence::TOOLCHAIN_PROVENANCE
      )
    ).fetch("selected_build_toolchain_candidate")
    assert(
      P13NoiseEvidence.validate_toolchain_source_provenance(
        record,
        provenance: provenance
      ),
      "exact LLVM license provenance"
    )

    changed = deep_copy(provenance)
    changed.fetch("active_source_closure")["llvm_license"] = "BUSL-1.1"
    assert_failure("active source provenance differs") do
      P13NoiseEvidence.validate_toolchain_source_provenance(
        record,
        provenance: changed
      )
    end
  end

  def test_toolchain_provenance_duplicate_source_fields_are_bound
    record = evidence.fetch("toolchain_source_closure")
    provenance = P13NoiseEvidence.read_yaml(
      File.join(
        P13NoiseEvidence::ROOT,
        P13NoiseEvidence::TOOLCHAIN_PROVENANCE
      )
    ).fetch("selected_build_toolchain_candidate")
    mutations = [
      ->(item) { item["name"] = "FIXTURE_TECNICA_rust" },
      ->(item) { item["version"] = "0.0.0" },
      ->(item) { item["provider"] = "FIXTURE_TECNICA_provider" },
      ->(item) { item["license"] = "BUSL-1.1" },
      ->(item) { item["source_url"] = "https://example.invalid/rust" },
      ->(item) { item["source_commit"] = "0" * 40 },
      ->(item) { item["manifest_url"] = "https://example.invalid/manifest" },
      ->(item) { item["manifest_size"] += 1 },
      ->(item) { item["manifest_sha256"] = "0" * 64 },
      ->(item) { item["target"] = "FIXTURE_TECNICA-target" },
      ->(item) { item["archive_url"] = "https://example.invalid/archive" },
      ->(item) { item["archive_sha256"] = "0" * 64 },
      lambda do |item|
        item.fetch("manifest_verified")["observed_size"] += 1
      end,
      lambda do |item|
        item.fetch("manifest_verified")["observed_sha256"] = "0" * 64
      end,
      lambda do |item|
        item.fetch("archive_verified")["observed_sha256"] = "0" * 64
      end,
      lambda do |item|
        item.fetch("source_archive")["local_path"] =
          "/private/tmp/FIXTURE_TECNICA-rust-source.tar.xz"
      end,
      lambda do |item|
        item.fetch("source_archive")["manifest_relation"] =
          "FIXTURE_TECNICA_unbound"
      end
    ]
    mutations.each do |mutation|
      changed = deep_copy(provenance)
      mutation.call(changed)
      assert_failure("source provenance") do
        P13NoiseEvidence.validate_toolchain_source_provenance(
          record,
          provenance: changed
        )
      end
    end
  end

  def test_verified_large_file_descriptor_rejects_path_substitution
    Dir.mktmpdir("p13-archive-descriptor-") do |directory|
      path = File.join(directory, "FIXTURE_TECNICA-archive")
      displaced = File.join(directory, "FIXTURE_TECNICA-displaced")
      original = "FIXTURE_TECNICA_ORIGINAL_ARCHIVE\n"
      File.binwrite(path, original)
      assert_failure("path identity differs") do
        P13NoiseEvidence.with_verified_large_file(
          path,
          bytes: original.bytesize,
          sha256: Digest::SHA256.hexdigest(original),
          context: "FIXTURE_TECNICA archive"
        ) do |handle|
          File.rename(path, displaced)
          File.binwrite(path, "FIXTURE_TECNICA_REPLACEMENT\n")
          io = handle.fetch("io")
          io.rewind
          assert(io.read == original, "held descriptor retains original bytes")
        end
      end
    end
  end

  def test_verified_large_file_rejects_fifo_without_blocking
    Dir.mktmpdir("p13-archive-fifo-") do |directory|
      path = File.join(directory, "FIXTURE_TECNICA-fifo")
      File.mkfifo(path, 0o600)
      Timeout.timeout(1) do
        assert_failure("not a regular file") do
          P13NoiseEvidence.with_verified_large_file(
            path,
            bytes: 0,
            sha256: Digest::SHA256.hexdigest(""),
            context: "FIXTURE_TECNICA FIFO"
          ) { raise "FIFO must not reach the verifier block" }
        end
      end
    end
  rescue Timeout::Error
    raise "assertion failed: FIFO verification blocked"
  end

  def test_verified_archive_snapshot_blocks_same_inode_rewrite_during_extraction
    Dir.mktmpdir("p13-archive-rewrite-") do |directory|
      original_root = File.join(directory, "original")
      alternate_root = File.join(directory, "alternate")
      extraction_root = File.join(directory, "extracted")
      archive = File.join(directory, "FIXTURE_TECNICA-source.tar.xz")
      alternate_archive = File.join(
        directory,
        "FIXTURE_TECNICA-alternate.tar.xz"
      )
      member = "rustc-1.98.0-src/FIXTURE_TECNICA-payload"
      [
        [original_root, "A"],
        [alternate_root, "B"]
      ].each do |root, byte|
        path = File.join(root, member)
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, byte * (1024 * 1024))
        File.utime(0, 0, path)
        File.utime(0, 0, File.dirname(path))
      end
      [
        [original_root, archive],
        [alternate_root, alternate_archive]
      ].each do |root, output|
        stdout, stderr, status = Open3.capture3(
          "/usr/bin/bsdtar",
          "-cJf",
          output,
          "-C",
          root,
          "rustc-1.98.0-src"
        )
        assert(
          status.success? && stdout.empty? && stderr.empty?,
          "technical archive creation succeeds"
        )
      end

      original = File.binread(archive)
      alternate = File.binread(alternate_archive)
      assert(
        original.bytesize == alternate.bytesize,
        "race archives have equal sizes"
      )
      FileUtils.mkdir_p(extraction_root)
      P13NoiseEvidence.with_verified_large_file(
        archive,
        bytes: original.bytesize,
        sha256: Digest::SHA256.hexdigest(original),
        context: "FIXTURE_TECNICA archive"
      ) do |handle|
        File.binwrite(archive, alternate)
        io = handle.fetch("io")
        stdout, stderr, status = Open3.capture3(
          "/usr/bin/bsdtar",
          "-xJf",
          P13NoiseEvidence.rust_archive_descriptor_path(handle),
          "-C",
          extraction_root,
          member,
          io.fileno => io,
          close_others: true
        )
        File.binwrite(archive, original)
        assert(
          status.success? && stdout.empty? && stderr.empty?,
          "snapshot extraction succeeds"
        )
      end
      extracted = File.binread(File.join(extraction_root, member))
      assert(
        extracted == ("A" * (1024 * 1024)),
        "extraction consumes only the verified snapshot"
      )
    end
  end

  def test_verified_crate_bytes_survive_same_inode_path_rewrite
    paths = P13NoiseEvidence.source_paths(evidence)
    package = evidence.fetch("closure").fetch("packages").find do |record|
      record.fetch("name") == "aead"
    end
    identity = "#{package.fetch('name')}-#{package.fetch('version')}"
    source = File.join(paths.fetch("archive_root"), "#{identity}.crate")

    Dir.mktmpdir("p13-crate-rewrite-") do |directory|
      archive = File.join(directory, "#{identity}.crate")
      original = File.binread(source)
      File.binwrite(archive, original)
      verified = P13NoiseEvidence.verify_file(
        archive,
        bytes: original.bytesize,
        sha256: Digest::SHA256.hexdigest(original),
        context: "FIXTURE_TECNICA crate archive"
      )

      File.binwrite(archive, "\0" * original.bytesize)
      entries = P13NoiseEvidence.crate_entries_bytes(verified, identity)
      assert(
        entries.fetch("Cargo.toml").fetch("contents").include?(
          "name = \"aead\""
        ),
        "crate parsing consumes the verified bytes rather than reopening path"
      )
    end
  end

  def test_rust_notice_non_osi_addition_is_rejected
    closure = evidence.fetch("toolchain_source_closure")
    record = {
      "notice_inventories" =>
        deep_copy(closure.fetch("notice_inventories"))
    }
    whole = File.binread(
      File.join(
        P13NoiseEvidence::ROOT,
        ".tools/rust-1.98.0/share/doc/rust/COPYRIGHT.html"
      )
    )
    library = File.binread(
      File.join(
        P13NoiseEvidence::ROOT,
        ".tools/rust-1.98.0/share/doc/rust/COPYRIGHT-library.html"
      )
    )
    whole += <<~HTML

      <h3>FIXTURE_TECNICA-BUSL-1.1</h3>
      <p><b>License:</b> BUSL-1.1</p>
    HTML
    rows = P13NoiseEvidence.rust_notice_records(
      whole,
      "FIXTURE_TECNICA Rust notice"
    )
    expressions = Hash.new(0)
    rows.each { |row| expressions[row.fetch(2)] += 1 }
    complete = record.fetch("notice_inventories").fetch("complete_toolchain")
    complete["record_count"] = rows.length
    complete["inventory_sha256"] = Digest::SHA256.hexdigest(
      rows.map { |row| row.join("\0") }.join("\n") + "\n"
    )
    complete["license_expression_counts"] = expressions
    assert_failure("notice license is unsupported: BUSL-1.1") do
      P13NoiseEvidence.validate_rust_notice_inventories(
        record,
        whole,
        library
      )
    end
  end

  def test_spdx_osi_approval_flip_is_rejected
    closure = evidence.fetch("toolchain_source_closure")
    spdx = closure.fetch("spdx_license_evidence")
    file = spdx.fetch("files").find do |candidate|
      candidate.fetch("id") == "MIT"
    end
    contents = P13NoiseEvidence.git_evidence_file(
      root: spdx.fetch("local_origin_repository"),
      commit: spdx.fetch("commit"),
      tree: spdx.fetch("tree"),
      path: file.fetch("path"),
      blob: file.fetch("git_blob"),
      bytes: file.fetch("bytes"),
      sha256: file.fetch("sha256"),
      label: "FIXTURE_TECNICA SPDX MIT"
    )
    changed = contents.sub('isOsiApproved="true"', 'isOsiApproved="false"')
    assert(changed != contents, "SPDX OSI flag mutation applied")
    assert_failure("SPDX OSI approval differs") do
      P13NoiseEvidence.validate_spdx_approval_fields(
        [file],
        {file.fetch("path") => changed}
      )
    end

    rejected = P13NoiseEvidence::SPDX_REJECTED_LICENSE_FILES.find do |candidate|
      candidate.fetch("id") == "BSD-4-Clause-UC"
    end
    rejected_contents = P13NoiseEvidence.git_evidence_file(
      root: spdx.fetch("local_origin_repository"),
      commit: spdx.fetch("commit"),
      tree: spdx.fetch("tree"),
      path: rejected.fetch("path"),
      blob: rejected.fetch("git_blob"),
      bytes: rejected.fetch("bytes"),
      sha256: rejected.fetch("sha256"),
      label: "FIXTURE_TECNICA SPDX rejected license"
    )
    changed = rejected_contents.sub(
      'isOsiApproved="false"',
      'isOsiApproved="true"'
    )
    assert(changed != rejected_contents, "SPDX non-OSI flag mutation applied")
    assert_failure("rejected license evidence differs") do
      P13NoiseEvidence.validate_spdx_rejection_fields(
        [rejected],
        {rejected.fetch("path") => changed}
      )
    end

    exception = P13NoiseEvidence::SPDX_LICENSE_FILES.find do |candidate|
      candidate.fetch("id") == "GCC-exception-3.1"
    end
    exception_contents = P13NoiseEvidence.git_evidence_file(
      root: spdx.fetch("local_origin_repository"),
      commit: spdx.fetch("commit"),
      tree: spdx.fetch("tree"),
      path: exception.fetch("path"),
      blob: exception.fetch("git_blob"),
      bytes: exception.fetch("bytes"),
      sha256: exception.fetch("sha256"),
      label: "FIXTURE_TECNICA SPDX GCC exception"
    )
    changed = exception_contents.sub(
      'licenseId="GCC-exception-3.1"',
      'licenseId="FIXTURE_TECNICA-exception"'
    )
    assert(changed != exception_contents, "SPDX exception mutation applied")
    assert_failure("SPDX exception ID differs") do
      P13NoiseEvidence.validate_spdx_approval_fields(
        [exception],
        {exception.fetch("path") => changed}
      )
    end
  end

  def test_rust_lock_active_reachability_is_dependency_closed
    lock = <<~LOCK
      version = 4

      [[package]]
      name = "FIXTURE_TECNICA_root"
      version = "0.0.0"
      dependencies = [
       "FIXTURE_TECNICA_selected",
      ]

      [[package]]
      name = "FIXTURE_TECNICA_selected"
      version = "1.0.0"
      source = "#{P13NoiseEvidence::RUST_REGISTRY_SOURCE}"
      checksum = "#{"a" * 64}"

      [[package]]
      name = "FIXTURE_TECNICA_inactive"
      version = "1.0.0"
      source = "#{P13NoiseEvidence::RUST_REGISTRY_SOURCE}"
      checksum = "#{"b" * 64}"
    LOCK
    packages = P13NoiseEvidence.rust_lock_packages(
      lock,
      "FIXTURE_TECNICA active graph"
    )
    reachable = P13NoiseEvidence.rust_lock_reachable_packages(
      packages,
      ["FIXTURE_TECNICA_root"],
      "FIXTURE_TECNICA active graph"
    )
    assert(
      reachable.map { |package| package.fetch("name") } ==
        %w[FIXTURE_TECNICA_root FIXTURE_TECNICA_selected],
      "inactive lock package excluded from active graph"
    )

    packages.find do |package|
      package.fetch("name") == "FIXTURE_TECNICA_root"
    end.fetch("dependencies") <<
      "FIXTURE_TECNICA_inactive"
    reachable = P13NoiseEvidence.rust_lock_reachable_packages(
      packages,
      ["FIXTURE_TECNICA_root"],
      "FIXTURE_TECNICA active graph"
    )
    assert(
      reachable.any? do |package|
        package.fetch("name") == "FIXTURE_TECNICA_inactive"
      end,
      "newly reachable lock package detected"
    )
  end

  def run
    tests = public_methods(false).grep(/\Atest_/).sort
    tests.each { |test| public_send(test) }
    puts "P13_NOISE_EVIDENCE_TESTS_PASS"
  end
end

P13NoiseEvidenceTest.run
