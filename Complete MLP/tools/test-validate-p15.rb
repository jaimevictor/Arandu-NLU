# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "tmpdir"
require_relative "validate-p15"

module P15ValidationTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure(code)
    yield
    raise "expected P15Validation::Failure"
  rescue P15Validation::Failure => error
    assert(error.code == code, "expected #{code}, got #{error.code}")
    error
  end

  def write_json(path, value)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, JSON.generate(value))
  end

  def disabled_contract
    Marshal.load(Marshal.dump(P15Validation::DISABLED_BUILD_CONTRACT))
  end

  def enabled_contract
    Marshal.load(Marshal.dump(P15Validation::ENABLED_BUILD_CONTRACT))
  end

  def sample_metric(numerator, denominator)
    {
      "numerator" => numerator,
      "denominator" => denominator,
      "rate_ppm" =>
        denominator.zero? ? nil :
          P15Validation.ratio_ppm(numerator, denominator),
      "wilson_95" =>
        denominator.zero? ? nil :
          P15Validation.wilson_95(numerator, denominator),
      "support" =>
        denominator >= P15Validation::MINIMUM_SUPPORTED_STRATUM ?
          "sufficient" : "insufficient",
      "minimum_supported_denominator" =>
        P15Validation::MINIMUM_SUPPORTED_STRATUM
    }
  end

  def semantic_metrics(records = 240)
    {
      "intent_exact" => sample_metric(records, records),
      "slot_exact" => sample_metric(records, records),
      "entity_exact" => sample_metric(records, records),
      "graph_exact" => sample_metric(records, records),
      "final_outcome_exact" => sample_metric(records, records)
    }
  end

  def sample_native(release)
    {
      "schema_version" => 1,
      "proof_kind" => "P15_NATIVE_LINUX_V1",
      "source_subject" => release.fetch(:source),
      "release_set_sha256" => release.fetch(:release_set_sha256),
      "release_input_inventory_sha256" => release.fetch(:inventory_sha256),
      "architectures" => P15Validation::ARCHITECTURES.keys.sort.map do |arch|
        contract = P15Validation::ARCHITECTURES.fetch(arch)
        entry = release.fetch(:entries).fetch(contract.fetch("artifact_path"))
        {
          "home_assistant_arch" => arch,
          "oci_platform" => contract.fetch("oci_platform"),
          "kernel" => {
            "sysname" => "Linux",
            "machine" => contract.fetch("kernel_machine"),
            "native_hardware" => true,
            "emulator" => false,
            "binfmt_misc" => false,
            "qemu" => false
          },
          "build" => {
            "mode" => "native_offline",
            "host_machine" => contract.fetch("kernel_machine"),
            "target_triple" => contract.fetch("target_triple"),
            "compiler" => "rustc 1.98.0",
            "linker_sha256" => "1" * 64,
            "source_mount" => "kernel_enforced_read_only",
            "source_read_only" => true,
            "network_allowed" => false,
            "cross_compilation" => false,
            "input_inventory_sha256" => release.fetch(:inventory_sha256),
            "status" => "PASS"
          },
          "executable" => {
            "format" => "ELF",
            "machine" => contract.fetch("elf_machine"),
            "static_musl" => true
          },
          "execution" => {
            "status" => "PASS",
            "matching_hardware" => true,
            "process_isolation" => "PASS",
            "read_only_source_enforced" => "PASS",
            "rejected_source_unreachable" => "PASS"
          },
          "artifact" => {
            "path" => contract.fetch("artifact_path"),
            "bytes" => entry.fetch("bytes"),
            "sha256" => entry.fetch("sha256")
          }
        }
      end
    }
  end

  def sample_release
    entries = {}
    P15Validation::RELEASE_ENTRY_CONTRACT.each do |path, contract|
      entries[path] = {
        "path" => path,
        "kind" => contract.fetch("kind"),
        "architecture" => contract.fetch("architecture"),
        "bytes" => 32,
        "sha256" => Digest::SHA256.hexdigest(path),
        "mode" => path.include?("artifact") ? "0755" : "0644",
        "media_type" => "application/octet-stream"
      }
    end
    {
      source: {
        "commit" => "a" * 40,
        "tree" => "b" * 40
      },
      source_date_epoch: 1_788_739_200,
      entries: entries,
      release_set_sha256:
        P15Validation.release_set_sha256(entries.values.sort_by do |entry|
          entry.fetch("path")
        end),
      inventory_sha256: "c" * 64,
      manifest_sha256: "d" * 64
    }
  end

  def sample_review(role, instance, subject, release)
    <<~TEXT
      # P15 Final #{role} Review

      - Role: `#{role}`
      - Review instance: `#{instance}`
      - Subject commit: `#{subject.fetch("commit")}`
      - Subject tree: `#{subject.fetch("tree")}`
      - Release manifest SHA-256: `#{release.fetch(:manifest_sha256)}`
      - Release set SHA-256: `#{release.fetch(:release_set_sha256)}`
      - Mode: independent read-only primary-evidence review
      - Verdict: `PASS`

      ## Scope And Commands

      FIXTURE_TECNICA.

      ## Counterexample

      FIXTURE_TECNICA.

      ## Findings

      P0: none. P1: none. P2: none. P3: none.

      `PASS`
    TEXT
  end

  def test_arguments_are_exact_and_bounded
    values = P15Validation.parse_subject_arguments(
      [
        "--expected-commit", "a" * 40,
        "--expected-tree", "b" * 40,
        "--subject-commit", "c" * 40,
        "--subject-tree", "d" * 40
      ]
    )
    assert(values.fetch(:subject_tree) == "d" * 40, "subject tree")
    assert_failure("P15_USAGE") do
      P15Validation.parse_subject_arguments([])
    end
    assert_failure("P15_USAGE") do
      P15Validation.parse_subject_arguments(
        [
          "--expected-commit", "A" * 40,
          "--expected-tree", "b" * 40,
          "--subject-commit", "c" * 40,
          "--subject-tree", "d" * 40
        ]
      )
    end
  end

  def test_current_incomplete_shape_fails_before_commands
    Dir.mktmpdir("FIXTURE_TECNICA_p15_missing", "/private/tmp") do |root|
      FileUtils.mkdir_p(File.join(root, "addon"))
      FileUtils.mkdir_p(File.join(root, "tools"))
      FileUtils.mkdir_p(File.join(root, "docs/evidence"))
      write_json(File.join(root, "addon/build-contract.json"), disabled_contract)
      File.binwrite(
        File.join(root, P15Validation::EVALUATION_ACCESS_PATH),
        File.binread(
          File.join(
            P15Validation::ROOT,
            P15Validation::EVALUATION_ACCESS_PATH
          )
        )
      )
      launcher = File.join(root, "tools/validate-p15")
      File.binwrite(
        launcher,
        "#{P15Validation::LAUNCHER_SHEBANG}\n" \
        "require_relative \"validate-p15\"\n" \
        "warn \"P15_GATE_FAIL[\#{error.code}]\"\n"
      )
      File.chmod(0o755, launcher)
      calls = 0
      runner = lambda do |_command, _chdir, _binary, _maximum = nil|
        calls += 1
        raise "untrusted command executed"
      end
      assert_failure("P15_EVALUATION_REPORT_MISSING") do
        P15Validation.run(
          [
            "--expected-commit", "a" * 40,
            "--expected-tree", "b" * 40,
            "--subject-commit", "c" * 40,
            "--subject-tree", "d" * 40
          ],
          root: root,
          command_runner: runner
        )
      end
      assert(calls.zero?, "no command before static preflight")
    end
  end

  def test_premature_architecture_enablement_precedes_missing_evidence
    Dir.mktmpdir("FIXTURE_TECNICA_p15_enabled", "/private/tmp") do |root|
      FileUtils.mkdir_p(File.join(root, "addon"))
      write_json(File.join(root, "addon/build-contract.json"), enabled_contract)
      assert_failure("P15_ARCHITECTURE_PREMATURE_ENABLEMENT") do
        P15Validation.load_static_bundle(
          root,
          subject: {"commit" => "a" * 40, "tree" => "b" * 40}
        )
      end
    end
  end

  def test_duplicate_and_unbounded_json_fail_closed
    assert_failure("P15_FIXTURE_JSON") do
      P15Validation.parse_json(
        "{\"schema_version\":1,\"schema_version\":1}",
        "P15_FIXTURE_JSON",
        "FIXTURE_TECNICA"
      )
    end
    oversized = JSON.generate({"value" => "x" * 20_000})
    assert_failure("P15_INPUT_LIMIT_EXCEEDED") do
      P15Validation.parse_json(
        oversized,
        "P15_FIXTURE_JSON",
        "FIXTURE_TECNICA"
      )
    end
  end

  def test_frozen_inputs_and_access_chronology_are_exact
    chronology = P15Validation.validate_evaluation_access_record(
      P15Validation::ROOT
    )
    assert(
      chronology.fetch("pre_implementation") ==
        P15Validation::PRE_IMPLEMENTATION_SUBJECT,
      "recorded behavior-freeze identity"
    )
    frozen = P15Validation.validate_frozen_inputs(P15Validation::ROOT)
    assert(
      frozen.fetch(:heldout_counts).keys ==
        P15Validation::FROZEN_DIMENSIONS,
      "held-out dimensions"
    )
  end

  def test_release_set_rejects_substitution_and_omission
    release = sample_release
    entries = release.fetch(:entries).values.sort_by { |entry| entry.fetch("path") }
    first = P15Validation.release_set_sha256(entries)
    mutation = Marshal.load(Marshal.dump(entries))
    mutation.fetch(0)["sha256"] = "0" * 64
    refute = P15Validation.release_set_sha256(mutation)
    assert(first != refute, "artifact substitution changes release set")
    omission = entries[0...-1]
    assert(
      first != P15Validation.release_set_sha256(omission),
      "artifact omission changes release set"
    )
  end

  def test_native_architecture_relabel_and_emulation_are_rejected
    release = sample_release
    proof = sample_native(release)
    state = P15Validation.validate_native_linux_proof(
      proof,
      release.fetch(:source),
      release
    )
    assert(state.keys == %w[aarch64 amd64], "positive native schema")

    relabeled = Marshal.load(Marshal.dump(proof))
    relabeled.fetch("architectures").fetch(0).fetch("kernel")["machine"] =
      "x86_64"
    assert_failure("P15_NATIVE_SUBSTITUTION_REJECTED") do
      P15Validation.validate_native_linux_proof(
        relabeled,
        release.fetch(:source),
        release
      )
    end

    emulated = Marshal.load(Marshal.dump(proof))
    emulated.fetch("architectures").fetch(1).fetch("kernel")["emulator"] = true
    assert_failure("P15_NATIVE_SUBSTITUTION_REJECTED") do
      P15Validation.validate_native_linux_proof(
        emulated,
        release.fetch(:source),
        release
      )
    end
  end

  def test_fake_home_assistant_evidence_is_rejected
    release = sample_release
    native = P15Validation.validate_native_linux_proof(
      sample_native(release),
      release.fetch(:source),
      release
    )
    rows = P15Validation::ARCHITECTURES.keys.sort.product(
      P15Validation::HOME_ASSISTANT_RELEASES.keys.sort
    ).map do |arch, version|
      contract = P15Validation::ARCHITECTURES.fetch(arch)
      identity = P15Validation::HOME_ASSISTANT_RELEASES.fetch(version)
      companion = release.fetch(:entries).fetch(
        P15Validation::MANDATORY_RELEASE_PATHS.fetch("companion")
      )
      addon = release.fetch(:entries).fetch(contract.fetch("artifact_path"))
      lifecycle = {}
      P15Validation::LIFECYCLE_GATES.each do |gate|
        lifecycle[gate] =
          gate.end_with?("_fails_closed") ? "FAIL_CLOSED" : "PASS"
      end
      {
        "architecture" => arch,
        "oci_platform" => contract.fetch("oci_platform"),
        "kernel_machine" => contract.fetch("kernel_machine"),
        "home_assistant" => {
          "version" => version,
          "commit" => identity.fetch("commit"),
          "tree" => identity.fetch("tree"),
          "supported" => true,
          "core_real" => true,
          "supervisor_real" => true,
          "python_version" => "3.14.2",
          "dependency_closure_sha256" => "e" * 64
        },
        "substitution_guards" => {
          "mock" => false,
          "patched_imports" => false,
          "fake_entry" => false,
          "fake_dispatch" => false,
          "source_identity_only" => false,
          "emulator" => false
        },
        "actual_paths" => {
          "loader" => true,
          "config_flow" => true,
          "authorization" => true,
          "service_dispatch" => true,
          "backup_restore" => true
        },
        "lifecycle" => lifecycle,
        "installed_artifacts" => {
          "companion_sha256" => companion.fetch("sha256"),
          "addon_sha256" => addon.fetch("sha256")
        }
      }
    end
    report = {
      "schema_version" => 1,
      "proof_kind" => "P15_REAL_HOME_ASSISTANT_LIFECYCLE_V1",
      "source_subject" => release.fetch(:source),
      "release_set_sha256" => release.fetch(:release_set_sha256),
      "runtime_closure_sha256" => "f" * 64,
      "environments" => rows
    }
    assert(
      P15Validation.validate_home_assistant_lifecycle(
        report,
        release.fetch(:source),
        release,
        native
      ),
      "positive real runtime schema"
    )
    fake = Marshal.load(Marshal.dump(report))
    fake.fetch("environments").fetch(0).fetch(
      "substitution_guards"
    )["mock"] = true
    assert_failure("P15_FAKE_HOME_ASSISTANT_PROOF_REJECTED") do
      P15Validation.validate_home_assistant_lifecycle(
        fake,
        release.fetch(:source),
        release,
        native
      )
    end
  end

  def test_reproducibility_requires_distinct_native_offline_roots
    release = sample_release
    products = {
      "aarch64" => [
        "aarch64",
        P15Validation::MANDATORY_RELEASE_PATHS.fetch("aarch64")
      ],
      "amd64" => [
        "amd64",
        P15Validation::MANDATORY_RELEASE_PATHS.fetch("amd64")
      ],
      "companion" => [
        "multi",
        P15Validation::MANDATORY_RELEASE_PATHS.fetch("companion")
      ]
    }.map do |name, values|
      arch, path = values
      entry = release.fetch(:entries).fetch(path)
      builds = [1, 2].map do |ordinal|
        {
          "ordinal" => ordinal,
          "root" => "/build/FIXTURE_TECNICA/#{name}/#{ordinal}",
          "native_linux" => true,
          "offline" => true,
          "source_read_only" => true,
          "network_allowed" => false,
          "input_inventory_sha256" => release.fetch(:inventory_sha256),
          "artifact_bytes" => entry.fetch("bytes"),
          "artifact_sha256" => entry.fetch("sha256")
        }
      end
      {
        "product" => name,
        "architecture" => arch,
        "artifact_path" => path,
        "artifact_bytes" => entry.fetch("bytes"),
        "artifact_sha256" => entry.fetch("sha256"),
        "builds" => builds,
        "byte_identical" => true
      }
    end
    report = {
      "schema_version" => 1,
      "proof_kind" => "P15_REPRODUCIBILITY_V1",
      "source_subject" => release.fetch(:source),
      "source_date_epoch" => release.fetch(:source_date_epoch),
      "release_set_sha256" => release.fetch(:release_set_sha256),
      "release_input_inventory_sha256" => release.fetch(:inventory_sha256),
      "products" => products
    }
    assert(
      P15Validation.validate_reproducibility(
        report,
        release.fetch(:source),
        release,
        release.fetch(:inventory_sha256)
      ),
      "positive reproducibility schema"
    )
    duplicate = Marshal.load(Marshal.dump(report))
    duplicate.fetch("products").fetch(0).fetch("builds").fetch(1)["root"] =
      duplicate.fetch("products").fetch(0).fetch("builds").fetch(0).fetch("root")
    assert_failure("P15_REPRODUCIBILITY_PROOF_INVALID") do
      P15Validation.validate_reproducibility(
        duplicate,
        release.fetch(:source),
        release,
        release.fetch(:inventory_sha256)
      )
    end
  end

  def test_stale_review_subject_and_duplicate_instances_are_rejected
    release = sample_release
    subject = {"commit" => "1" * 40, "tree" => "2" * 40}
    Dir.mktmpdir("FIXTURE_TECNICA_p15_reviews", "/private/tmp") do |root|
      reports = P15Validation::REVIEW_FILES.keys.sort.map do |role|
        instance = "FIXTURE_TECNICA_#{role}"
        path = P15Validation::REVIEW_FILES.fetch(role)
        bytes = sample_review(role, instance, subject, release)
        absolute = File.join(root, path)
        FileUtils.mkdir_p(File.dirname(absolute))
        File.binwrite(absolute, bytes)
        {
          "role" => role,
          "instance" => instance,
          "path" => path,
          "bytes" => bytes.bytesize,
          "sha256" => Digest::SHA256.hexdigest(bytes),
          "verdict" => "PASS"
        }
      end
      validation = {
        "schema_version" => 1,
        "phase" => "P15",
        "subject" => subject,
        "release_manifest_sha256" => release.fetch(:manifest_sha256),
        "release_set_sha256" => release.fetch(:release_set_sha256),
        "gates" => {
          "evaluation_access_chronology" => "PASS",
          "evaluation" => "PASS",
          "performance" => "PASS",
          "p14_debt" => "PASS",
          "native_linux_amd64" => "PASS",
          "native_linux_aarch64" => "PASS",
          "real_home_assistant_lifecycle" => "PASS",
          "reproducibility" => "PASS",
          "sbom" => "PASS",
          "notices" => "PASS",
          "checksums" => "PASS",
          "reconciliation" => "PASS"
        },
        "requirements" => {
          "applicable" => 535,
          "mandatory_satisfied" => 535,
          "status" => "ALL_MANDATORY_SATISFIED"
        },
        "residual_findings" => [],
        "architecture_transition" =>
          "disabled_subject_to_enabled_evidence_checkpoint",
        "review_reports" => reports,
        "result" => "MINIMUM_ACCEPTABLE_PASS"
      }
      assert(
        P15Validation.validate_validation_and_reviews(
          root,
          validation,
          subject,
          release
        ).fetch(:instances).length == 6,
        "positive review schema"
      )
      stale = Marshal.load(Marshal.dump(validation))
      stale["subject"] = {"commit" => "3" * 40, "tree" => "4" * 40}
      assert_failure("P15_VALIDATION_REPORT_INVALID") do
        P15Validation.validate_validation_and_reviews(
          root,
          stale,
          subject,
          release
        )
      end
      duplicated = Marshal.load(Marshal.dump(validation))
      shared = duplicated.fetch("review_reports").fetch(0).fetch("instance")
      duplicated.fetch("review_reports").fetch(1)["instance"] = shared
      assert_failure("P15_MANDATORY_REVIEW_INVALID") do
        P15Validation.validate_validation_and_reviews(
          root,
          duplicated,
          subject,
          release
        )
      end
    end
  end

  def test_post_review_artifact_and_source_mutation_are_rejected
    assert(
      P15Validation.validate_evidence_delta_paths(
        [
          "addon/build-contract.json",
          "docs/reviews/P15/final-risk.md",
          "docs/evidence/P15-VALIDATION.json"
        ]
      ),
      "allowed evidence-only delta"
    )
    assert_failure("P15_POST_REVIEW_ARTIFACT_MUTATION") do
      P15Validation.validate_evidence_delta_paths(
        ["release/p15/artifacts/local_nlu_companion.posix-ustar"]
      )
    end
    assert_failure("P15_POST_REVIEW_SOURCE_MUTATION") do
      P15Validation.validate_evidence_delta_paths(
        ["crates/nlu-server/src/lib.rs"]
      )
    end
  end

  def test_evaluation_access_guard_rejects_behavior_changes
    baseline = {
      "crates/nlu-server/src/runtime.rs" => ["100644", "a" * 40],
      "data/project-authored/p02-v1/heldout.jsonl" =>
        ["100644", "b" * 40],
      "schemas/protocol-v2-request.schema.json" =>
        ["100644", "c" * 40],
      "tools/validate-p15.rb" => ["100644", "d" * 40]
    }
    unchanged = Marshal.load(Marshal.dump(baseline))
    assert(
      P15Validation.compare_behavior_maps_for_test(baseline, unchanged),
      "unchanged behavior map"
    )

    changed = Marshal.load(Marshal.dump(baseline))
    changed["crates/nlu-server/src/runtime.rs"] = ["100644", "e" * 40]
    assert_failure("P15_EVAL_012_BEHAVIOR_CHANGED") do
      P15Validation.compare_behavior_maps_for_test(baseline, changed)
    end

    added_release_schema = Marshal.load(Marshal.dump(baseline))
    added_release_schema["schemas/p15-new-release.schema.json"] =
      ["100644", "f" * 40]
    assert(
      P15Validation.compare_behavior_maps_for_test(
        baseline,
        added_release_schema
      ),
      "new release-only schema is not production behavior"
    )

    added_data = Marshal.load(Marshal.dump(baseline))
    added_data["data/intents/p15/package.bin"] = ["100644", "0" * 40]
    assert_failure("P15_EVAL_012_BEHAVIOR_CHANGED") do
      P15Validation.compare_behavior_maps_for_test(baseline, added_data)
    end

    added_test = Marshal.load(Marshal.dump(baseline))
    added_test["crates/nlu-server/tests/FIXTURE_TECNICA.rs"] =
      ["100644", "1" * 40]
    assert(
      P15Validation.compare_behavior_maps_for_test(baseline, added_test),
      "mechanical tests are outside production behavior bytes"
    )
  end

  def test_untrusted_command_fields_are_rejected_without_execution
    release = sample_release
    proof = sample_native(release)
    proof.fetch("architectures").fetch(0).fetch("build")["command"] =
      "/bin/sh -c touch /private/tmp/FIXTURE_TECNICA"
    assert_failure("P15_NATIVE_LINUX_PROOF_INVALID") do
      P15Validation.validate_native_linux_proof(
        proof,
        release.fetch(:source),
        release
      )
    end
    assert_failure("P15_UNTRUSTED_COMMAND_REJECTED") do
      P15Validation.run_command(
        ["/bin/sh", "-c", "touch /private/tmp/FIXTURE_TECNICA"],
        "/private/tmp"
      )
    end
  end

  def test_review_markdown_requires_same_subject_and_terminal_pass
    release = sample_release
    subject = {"commit" => "a" * 40, "tree" => "b" * 40}
    bytes = sample_review("risk", "FIXTURE_TECNICA_risk", subject, release)
    assert(
      P15Validation.validate_review_markdown(
        bytes,
        "risk",
        "FIXTURE_TECNICA_risk",
        subject,
        release.fetch(:manifest_sha256),
        release.fetch(:release_set_sha256),
        "P15_FIXTURE_REVIEW",
        "P15"
      ),
      "same-subject review"
    )
    assert_failure("P15_FIXTURE_REVIEW") do
      P15Validation.validate_review_markdown(
        bytes.sub(subject.fetch("commit"), "c" * 40),
        "risk",
        "FIXTURE_TECNICA_risk",
        subject,
        release.fetch(:manifest_sha256),
        release.fetch(:release_set_sha256),
        "P15_FIXTURE_REVIEW",
        "P15"
      )
    end
  end

  def run
    public_methods(false).grep(/\Atest_/).sort.each { |test| public_send(test) }
    puts "P15_VALIDATOR_TESTS_PASS"
  end
end

P15ValidationTest.run
