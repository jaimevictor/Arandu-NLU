# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "set"
require "time"

module P15Validation
  class Failure < StandardError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message)
    end
  end

  class DuplicateJsonKey < StandardError; end

  class UniqueJsonObject < Hash
    def []=(key, value)
      raise DuplicateJsonKey, key if key?(key)

      super
    end
  end

  ROOT = File.expand_path("..", __dir__)
  LAUNCHER = File.join(ROOT, "tools/validate-p15")
  LAUNCHER_SHEBANG =
    "#!/usr/bin/env -S -i HOME=/var/empty PATH=/usr/bin:/bin LC_ALL=C " \
    "LANG=C TZ=UTC GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null " \
    "GIT_ATTR_NOSYSTEM=1 /usr/bin/ruby --disable-gems"

  BASE_ENVIRONMENT = {
    "GIT_ATTR_NOSYSTEM" => "1",
    "GIT_CONFIG_GLOBAL" => "/dev/null",
    "GIT_CONFIG_NOSYSTEM" => "1",
    "HOME" => "/var/empty",
    "LANG" => "C",
    "LC_ALL" => "C",
    "PATH" => "/usr/bin:/bin",
    "TZ" => "UTC"
  }.freeze
  GIT_HOST_TEMP_WARNING =
    "git: warning: confstr() failed with code 5: couldn't get path of " \
    "DARWIN_USER_TEMP_DIR; using /tmp instead"

  P14_SUBJECT = {
    "commit" => "93ed8d75a4cb35f80572f8207105929b0071f48e",
    "tree" => "896a220ebb3e18905c2fc79d18779eecf547931c"
  }.freeze

  EVALUATION_ACCESS_PATH = "docs/evidence/P15-EVALUATION-ACCESS.md"
  EVALUATION_ACCESS_BYTES = 2_802
  EVALUATION_ACCESS_SHA256 =
    "f037c75b0c97d72d42bb2af430554c7732d5470a16d7bcab3f9ebffca8538c55"
  PRE_IMPLEMENTATION_SUBJECT = {
    "commit" => "a055a847d22575fba8350d9e05fd8aff3797ece9",
    "tree" => "24ac05687083a8fe8adb11e960a9e91bda158053"
  }.freeze

  FROZEN_BEHAVIOR_CRATES = %w[
    addon-runtime
    ha-adapter
    ha-catalog
    intent-engine
    intent-eval
    lang-ptbr
    morphology-eval
    nlu-core
    nlu-data
    nlu-server
    noise-channel
    plan-engine
    plan-eval
    policy-engine
    pos-eval
    protocol
    runtime-security
    session-engine
    wyoming-runtime
  ].freeze

  HOME_ASSISTANT_RELEASES = {
    "2026.8.3" => {
      "commit" => "759e4658f40b3ccb671d418b8a0ed95224bf4561",
      "tree" => "f4a72534bb33abf8b5d183910a0c134b968af2f8"
    },
    "2026.9.1" => {
      "commit" => "fc034572d0216a04ed40a07154394908a594dfed",
      "tree" => "4b2a1cd29e3d85c43d791e03eb82a17244956fec"
    }
  }.freeze

  P02_FILES = {
    "manifest" => {
      "path" => "data/project-authored/p02-v1/manifest.json",
      "bytes" => 11_091,
      "sha256" =>
        "a251485ba2f8d5032603200b7e171954213383aeceac9a8f394edb09a265e72a"
    },
    "specification" => {
      "path" => "data/project-authored/p02-v1/specification.yaml",
      "bytes" => 18_201,
      "sha256" =>
        "f72451f03d1a5e2e4955b5d2857bd7d33b3b012912d920e53a3d85719f14859d"
    },
    "p09_projection" => {
      "path" => "data/evaluation/p09/intent-v1/projection.json",
      "sha256" =>
        "5f661bb96b85667a1d0c9ec4d85cb61c443e1b24ab4dfc6c1ab849c6df936ee4"
    },
    "p11_projection" => {
      "path" => "data/evaluation/p11/plan-v1/projection.json",
      "sha256" =>
        "581b852b8cd2ec24b4c02b8c68914b27a928d953470a10665357e50425783f75"
    },
    "heldout" => {
      "path" => "data/project-authored/p02-v1/heldout.jsonl",
      "bytes" => 6_389_947,
      "records" => 4_800,
      "sha256" =>
        "1b3e3669ba3e64193b769bccf90368f571daae5b4f3d9ed88724c99bec12c6da"
    },
    "performance" => {
      "path" => "data/project-authored/p02-v1/performance.jsonl",
      "bytes" => 6_461_467,
      "records" => 4_800,
      "sha256" =>
        "1c9fedff6a3bc7aa36e5f343eb85ce2f197ce0d5c44cd514fe1c5b08a03ba55b"
    }
  }.freeze

  SUITES = {
    "ambiguity" => {
      "path" => "data/project-authored/p02-v1/suites/ambiguity.jsonl",
      "records" => 5,
      "bytes" => 3_663,
      "sha256" =>
        "098051c102bfdf9ede0781d8c1069546cb2db1d9265b4d1e2b3d2123ea1c7721"
    },
    "contradiction" => {
      "path" => "data/project-authored/p02-v1/suites/contradiction.jsonl",
      "records" => 5,
      "bytes" => 3_792,
      "sha256" =>
        "9a2c53626b74ad0479fd81bd91d0a41a027db2eb53eb37b6efcc2066a67689a8"
    },
    "explicit_negative" => {
      "path" =>
        "data/project-authored/p02-v1/suites/explicit-negative.jsonl",
      "records" => 7,
      "bytes" => 5_350,
      "sha256" =>
        "9c90a3f399a988d3714a611cf04fda1d60cd5be2b311d06cf957915bb3f53ebb"
    },
    "safety_sensitive" => {
      "path" =>
        "data/project-authored/p02-v1/suites/safety-sensitive.jsonl",
      "records" => 5,
      "bytes" => 3_751,
      "sha256" =>
        "8d06bbfbcaf48cf729fd24fb7330c4b6a50a5d016addbf8517ae0356c5b5f261"
    },
    "stale_state" => {
      "path" => "data/project-authored/p02-v1/suites/stale-state.jsonl",
      "records" => 5,
      "bytes" => 3_749,
      "sha256" =>
        "1d5d8c8f490ee546ee6fd7d8e165bbb6d6d926ccaedaa8484a47546aa6b96e27"
    }
  }.freeze

  FROZEN_DIMENSIONS = %w[
    source family intent domain slot_kind graph_shape outcome ambiguity noise
  ].freeze
  SEMANTIC_METRICS = %w[
    intent_exact slot_exact entity_exact graph_exact final_outcome_exact
  ].freeze
  MINIMUM_SUPPORTED_STRATUM = 237
  MINIMUM_GLOBAL_CASES = 3_715
  REQUIRED_RATE_PPM = 984_000

  RELEASE_MANIFEST_PATH = "release/p15/release-manifest.json"
  RECONCILIATION_PATH = "release/p15/release-reconciliation.json"
  SBOM_PATH = "release/p15/sbom.spdx.json"
  NOTICES_PATH = "release/p15/THIRD-PARTY-NOTICES.txt"
  CHECKSUMS_PATH = "release/p15/SHA256SUMS"
  VALIDATION_REPORT_PATH = "docs/evidence/P15-VALIDATION.json"

  REPORT_PATHS = {
    "evaluation" => {
      "path" => "release/p15/evidence/evaluation-report.json",
      "missing_code" => "P15_EVALUATION_REPORT_MISSING"
    },
    "performance" => {
      "path" => "release/p15/evidence/performance-report.json",
      "missing_code" => "P15_PERFORMANCE_REPORT_MISSING"
    },
    "p14_debt" => {
      "path" => "release/p15/evidence/p14-debt-closure.json",
      "missing_code" => "P15_P14_DEBT_EVIDENCE_MISSING"
    },
    "native_linux" => {
      "path" => "release/p15/evidence/native-linux-proof.json",
      "missing_code" => "P15_NATIVE_LINUX_PROOF_MISSING"
    },
    "home_assistant_lifecycle" => {
      "path" =>
        "release/p15/evidence/home-assistant-lifecycle-proof.json",
      "missing_code" => "P15_HOME_ASSISTANT_LIFECYCLE_PROOF_MISSING"
    },
    "reproducibility" => {
      "path" => "release/p15/evidence/reproducibility-proof.json",
      "missing_code" => "P15_REPRODUCIBILITY_PROOF_MISSING"
    }
  }.freeze

  MANDATORY_RELEASE_PATHS = {
    "companion" =>
      "release/p15/artifacts/local_nlu_companion.posix-ustar",
    "amd64" =>
      "release/p15/artifacts/local_nlu_addon-linux-amd64.oci.tar",
    "aarch64" =>
      "release/p15/artifacts/local_nlu_addon-linux-arm64.oci.tar",
    "sbom" => SBOM_PATH,
    "notices" => NOTICES_PATH,
    "reconciliation" => RECONCILIATION_PATH
  }.freeze

  RELEASE_ENTRY_CONTRACT = {
    MANDATORY_RELEASE_PATHS.fetch("companion") => {
      "kind" => "companion_posix_ustar",
      "architecture" => "multi"
    },
    MANDATORY_RELEASE_PATHS.fetch("amd64") => {
      "kind" => "addon_oci_archive",
      "architecture" => "amd64"
    },
    MANDATORY_RELEASE_PATHS.fetch("aarch64") => {
      "kind" => "addon_oci_archive",
      "architecture" => "aarch64"
    },
    SBOM_PATH => {
      "kind" => "spdx_2_3_json",
      "architecture" => "all"
    },
    NOTICES_PATH => {
      "kind" => "third_party_notices",
      "architecture" => "all"
    },
    RECONCILIATION_PATH => {
      "kind" => "release_source_reconciliation",
      "architecture" => "all"
    }
  }.freeze

  ARCHITECTURES = {
    "aarch64" => {
      "oci_platform" => "linux/arm64",
      "kernel_machine" => "aarch64",
      "elf_machine" => "EM_AARCH64",
      "target_triple" => "aarch64-unknown-linux-musl",
      "artifact_path" => MANDATORY_RELEASE_PATHS.fetch("aarch64")
    },
    "amd64" => {
      "oci_platform" => "linux/amd64",
      "kernel_machine" => "x86_64",
      "elf_machine" => "EM_X86_64",
      "target_triple" => "x86_64-unknown-linux-musl",
      "artifact_path" => MANDATORY_RELEASE_PATHS.fetch("amd64")
    }
  }.freeze

  LIFECYCLE_GATES = %w[
    clean_dual_install
    helper_mode_and_architecture
    pair_and_recognize
    caller_authorized_operation
    restart_invalidates_epoch
    explicit_local_repair
    supported_upgrade
    companion_first_skew_fails_closed
    addon_first_skew_fails_closed
    rollback
    backup_restore_without_secrets
    complete_removal
    outbound_network_denied
    peer_credentials
    secret_memory_lock
    dump_prevention
    procfs_exposure_control
  ].freeze

  REVIEW_FILES = {
    "requirements" => "docs/reviews/P15/final-requirements.md",
    "correctness" => "docs/reviews/P15/final-correctness.md",
    "test-oracle" => "docs/reviews/P15/final-test-oracle.md",
    "risk" => "docs/reviews/P15/final-risk.md",
    "reproducibility" => "docs/reviews/P15/final-reproducibility.md",
    "runtime-adversarial" =>
      "docs/reviews/P15/final-runtime-adversarial.md"
  }.freeze

  P14_REVIEW_ROLES = REVIEW_FILES.keys.freeze

  EVIDENCE_DELTA_PATHS = (
    REVIEW_FILES.values +
    [
      "addon/build-contract.json",
      VALIDATION_REPORT_PATH,
      "docs/phases/AUTONOMOUS-QUEUE.yaml",
      "docs/phases/PROJECT-STATUS.md",
      "docs/phases/P15-REPORT.md"
    ]
  ).freeze

  SOURCE_TO_SUBJECT_PREFIXES = [
    "release/p15/"
  ].freeze

  DISABLED_BUILD_CONTRACT = {
    "architectures" => [
      {
        "home_assistant_arch" => "aarch64",
        "oci_platform" => "linux/arm64",
        "status" => "disabled_pending_admission"
      },
      {
        "home_assistant_arch" => "amd64",
        "oci_platform" => "linux/amd64",
        "status" => "disabled_pending_admission"
      }
    ],
    "artifact_build_allowed" => false,
    "container_recipe" => {
      "dockerfile_present" => false,
      "must_remain_absent_until_all_enablement_gates_pass" => true
    },
    "enablement_gates" => %w[
      admitted_foss_container_build_toolchain
      admitted_immutable_root_filesystem_per_architecture
      clean_home_assistant_install_tests
      exact_source_to_binary_closure
      native_linux_amd64_and_aarch64_read_only_source_builds
      reproducible_per_architecture_artifacts
    ],
    "network_fetch_allowed" => false,
    "reason_code" => "P15_CONTAINER_INPUTS_NOT_ADMITTED",
    "schema_version" => 1
  }.freeze

  ENABLED_BUILD_CONTRACT = {
    "architectures" => [
      {
        "home_assistant_arch" => "aarch64",
        "oci_platform" => "linux/arm64",
        "status" => "enabled"
      },
      {
        "home_assistant_arch" => "amd64",
        "oci_platform" => "linux/amd64",
        "status" => "enabled"
      }
    ],
    "artifact_build_allowed" => true,
    "container_recipe" => {
      "dockerfile_present" => false,
      "project_authored_oci_emitter" => true
    },
    "enablement_gates" => %w[
      inherited_p14_debt_closed
      aggregate_evaluation_passed
      performance_gates_passed
      admitted_foss_container_build_toolchain
      admitted_immutable_root_filesystem_per_architecture
      exact_source_to_binary_closure
      native_linux_amd64_and_aarch64_read_only_source_builds
      real_supported_home_assistant_lifecycle
      reproducible_per_architecture_artifacts
      sbom_notices_checksums_and_reconciliation
      mandatory_same_subject_reviews
    ],
    "network_fetch_allowed" => false,
    "reason_code" => "P15_RELEASE_GATES_PASSED",
    "schema_version" => 2
  }.freeze

  MAX_JSON_BYTES = 4 * 1024 * 1024
  MAX_SBOM_BYTES = 16 * 1024 * 1024
  MAX_NOTICE_BYTES = 4 * 1024 * 1024
  MAX_CHECKSUM_BYTES = 256 * 1024
  MAX_REVIEW_BYTES = 512 * 1024
  MAX_ARTIFACT_BYTES = 2 * 1024 * 1024 * 1024
  MAX_JSON_NODES = 100_000
  MAX_JSON_STRING_BYTES = 16 * 1024
  MAX_COMMAND_OUTPUT_BYTES = 8 * 1024 * 1024

  module_function

  def fail!(code, message)
    raise Failure.new(code, message)
  end

  def run(arguments, root: ROOT, command_runner: nil)
    identities = parse_subject_arguments(arguments)
    validate_invocation(root)
    runner = command_runner || method(:run_command)

    bundle = load_static_bundle(
      root,
      subject: {
        "commit" => identities.fetch(:subject_commit),
        "tree" => identities.fetch(:subject_tree)
      }
    )

    git_state = validate_git_state(
      root,
      identities,
      bundle,
      runner
    )
    verify_snapshot(root, bundle.fetch(:snapshot))

    puts(
      "P15_GIT_IDENTITIES_PASS " \
      "evidence_commit=#{identities.fetch(:expected_commit)} " \
      "evidence_tree=#{identities.fetch(:expected_tree)} " \
      "subject_commit=#{identities.fetch(:subject_commit)} " \
      "subject_tree=#{identities.fetch(:subject_tree)}"
    )
    puts(
      "P15_RELEASE_SET_PASS " \
      "sha256=#{bundle.fetch(:release_set_sha256)} " \
      "entries=#{bundle.fetch(:release_entries).length}"
    )
    puts "P15_P14_DEBT_PASS subject=#{P14_SUBJECT.fetch("commit")}"
    puts "P15_NATIVE_LINUX_PASS architectures=aarch64,amd64"
    puts(
      "P15_HOME_ASSISTANT_LIFECYCLE_PASS " \
      "versions=#{HOME_ASSISTANT_RELEASES.keys.sort.join(",")}"
    )
    puts "P15_REPRODUCIBILITY_PASS builds_per_architecture=2"
    puts(
      "P15_REVIEWS_PASS roles=#{REVIEW_FILES.keys.sort.join(",")} " \
      "instances=#{git_state.fetch(:review_instances).length}"
    )
    puts "P15_ARCHITECTURES_ENABLED aarch64,amd64"
    puts "P15_GATE_PASS"
    true
  end

  def parse_subject_arguments(arguments)
    fail!("P15_USAGE", subject_usage) if arguments.length > 8

    values = {}
    pending = arguments.dup
    until pending.empty?
      option = pending.shift
      key = {
        "--expected-commit" => :expected_commit,
        "--expected-tree" => :expected_tree,
        "--subject-commit" => :subject_commit,
        "--subject-tree" => :subject_tree
      }.fetch(option, nil)
      fail!("P15_USAGE", subject_usage) unless key && !pending.empty?
      if values.key?(key)
        fail!("P15_USAGE", "#{option} specified more than once")
      end
      values[key] = pending.shift
    end

    %i[expected_commit expected_tree subject_commit subject_tree].each do |key|
      unless values.key?(key)
        fail!("P15_USAGE", "--#{key.to_s.tr("_", "-")} is required")
      end
      unless full_sha1?(values.fetch(key))
        fail!(
          "P15_USAGE",
          "--#{key.to_s.tr("_", "-")} must be full lowercase 40-hex"
        )
      end
    end
    values
  end

  def subject_usage
    "usage: tools/validate-p15 --expected-commit COMMIT " \
      "--expected-tree TREE --subject-commit COMMIT --subject-tree TREE"
  end

  def validate_invocation(root)
    path = File.join(root, "tools/validate-p15")
    bytes = read_regular_file(
      path,
      max_bytes: 16 * 1024,
      code: "P15_INVOCATION_INVALID",
      label: "P15 launcher"
    )
    first_line = bytes.lines.first.to_s.chomp
    unless first_line == LAUNCHER_SHEBANG &&
           bytes.include?('require_relative "validate-p15"') &&
           bytes.include?('P15_GATE_FAIL[#{error.code}]') &&
           File.executable?(path)
      fail!(
        "P15_INVOCATION_INVALID",
        "launcher must use the admitted sanitized Ruby invocation"
      )
    end
    true
  end

  def load_static_bundle(root, subject:)
    build = load_json_path(
      root,
      "addon/build-contract.json",
      "P15_ARCHITECTURE_STATE_INVALID",
      "build contract"
    )
    build_state = classify_build_contract(build)

    missing = first_missing_required_path(root)
    if missing
      unless build_state == :disabled
        fail!(
          "P15_ARCHITECTURE_PREMATURE_ENABLEMENT",
          "release enablement precedes #{missing.fetch(:code)}"
        )
      end
      fail!(missing.fetch(:code), "#{missing.fetch(:path)} is missing")
    end

    begin
      evaluation_access = validate_evaluation_access_record(root)
      manifest = load_json_path(
        root,
        RELEASE_MANIFEST_PATH,
        "P15_RELEASE_MANIFEST_INVALID",
        "release manifest"
      )
      release = validate_release_manifest(root, manifest)
      reconciliation = load_json_path(
        root,
        RECONCILIATION_PATH,
        "P15_RECONCILIATION_INVALID",
        "release reconciliation"
      )
      reconciliation_state = validate_reconciliation(
        root,
        reconciliation,
        release
      )
      validate_sbom(
        load_json_path(
          root,
          SBOM_PATH,
          "P15_SBOM_INVALID",
          "SPDX SBOM",
          max_bytes: MAX_SBOM_BYTES
        ),
        release,
        reconciliation_state
      )
      validate_notices(
        read_relative(
          root,
          NOTICES_PATH,
          MAX_NOTICE_BYTES,
          "P15_NOTICES_INVALID",
          "third-party notices"
        ),
        release,
        reconciliation_state
      )
      validate_checksums(
        read_relative(
          root,
          CHECKSUMS_PATH,
          MAX_CHECKSUM_BYTES,
          "P15_CHECKSUMS_INVALID",
          "release checksums"
        ),
        root,
        release
      )

      frozen = validate_frozen_inputs(root)
      evaluation = load_json_path(
        root,
        REPORT_PATHS.fetch("evaluation").fetch("path"),
        "P15_EVALUATION_REPORT_INVALID",
        "evaluation report"
      )
      validate_evaluation_report(
        evaluation,
        frozen,
        release.fetch(:source)
      )
      performance = load_json_path(
        root,
        REPORT_PATHS.fetch("performance").fetch("path"),
        "P15_PERFORMANCE_REPORT_INVALID",
        "performance report"
      )
      validate_performance_report(
        performance,
        frozen,
        release.fetch(:source),
        release
      )
      p14 = load_json_path(
        root,
        REPORT_PATHS.fetch("p14_debt").fetch("path"),
        "P15_P14_DEBT_INVALID",
        "P14 debt closure"
      )
      validate_p14_debt(root, p14)
      native = load_json_path(
        root,
        REPORT_PATHS.fetch("native_linux").fetch("path"),
        "P15_NATIVE_LINUX_PROOF_INVALID",
        "native Linux proof"
      )
      native_state = validate_native_linux_proof(
        native,
        release.fetch(:source),
        release
      )
      lifecycle = load_json_path(
        root,
        REPORT_PATHS.fetch("home_assistant_lifecycle").fetch("path"),
        "P15_HOME_ASSISTANT_LIFECYCLE_PROOF_INVALID",
        "Home Assistant lifecycle proof"
      )
      validate_home_assistant_lifecycle(
        lifecycle,
        release.fetch(:source),
        release,
        native_state
      )
      reproducibility = load_json_path(
        root,
        REPORT_PATHS.fetch("reproducibility").fetch("path"),
        "P15_REPRODUCIBILITY_PROOF_INVALID",
        "reproducibility proof"
      )
      validate_reproducibility(
        reproducibility,
        release.fetch(:source),
        release,
        reconciliation_state.fetch(:inventory_sha256)
      )

      validation = load_json_path(
        root,
        VALIDATION_REPORT_PATH,
        "P15_VALIDATION_REPORT_INVALID",
        "P15 validation report"
      )
      review_state = validate_validation_and_reviews(
        root,
        validation,
        subject,
        release
      )

      unless build_state == :enabled
        fail!(
          "P15_ARCHITECTURE_STATE_INVALID",
          "complete evidence checkpoint must use the exact enabled contract"
        )
      end

      snapshot_paths = required_snapshot_paths(release, p14)
      {
        source: release.fetch(:source),
        evaluation_access: evaluation_access,
        release_entries: release.fetch(:entries),
        release_manifest_sha256: release.fetch(:manifest_sha256),
        release_set_sha256: release.fetch(:release_set_sha256),
        review_instances: review_state.fetch(:instances),
        snapshot: snapshot_files(root, snapshot_paths)
      }
    rescue Failure => error
      if build_state == :enabled &&
         error.code != "P15_ARCHITECTURE_PREMATURE_ENABLEMENT"
        fail!(
          "P15_ARCHITECTURE_PREMATURE_ENABLEMENT",
          "enabled contract is blocked by #{error.code}"
        )
      end
      raise
    end
  end

  def classify_build_contract(build)
    return :disabled if build == DISABLED_BUILD_CONTRACT
    return :enabled if build == ENABLED_BUILD_CONTRACT

    fail!(
      "P15_ARCHITECTURE_STATE_INVALID",
      "build contract is neither the exact disabled nor enabled state"
    )
  end

  def first_missing_required_path(root)
    ordered = [
      {
        "path" => EVALUATION_ACCESS_PATH,
        "missing_code" => "P15_EVAL_012_CHRONOLOGY_MISSING"
      }
    ] + REPORT_PATHS.values + [
      {
        "path" => RELEASE_MANIFEST_PATH,
        "missing_code" => "P15_RELEASE_MANIFEST_MISSING"
      },
      {
        "path" => RECONCILIATION_PATH,
        "missing_code" => "P15_RECONCILIATION_MISSING"
      },
      {
        "path" => SBOM_PATH,
        "missing_code" => "P15_SBOM_MISSING"
      },
      {
        "path" => NOTICES_PATH,
        "missing_code" => "P15_NOTICES_MISSING"
      },
      {
        "path" => CHECKSUMS_PATH,
        "missing_code" => "P15_CHECKSUMS_MISSING"
      },
      {
        "path" => VALIDATION_REPORT_PATH,
        "missing_code" => "P15_VALIDATION_REPORT_MISSING"
      }
    ]
    REVIEW_FILES.each do |role, path|
      ordered << {
        "path" => path,
        "missing_code" => "P15_MANDATORY_REVIEW_MISSING",
        "role" => role
      }
    end

    ordered.each do |entry|
      path = File.join(root, entry.fetch("path"))
      next if File.exist?(path) || File.symlink?(path)

      suffix = entry["role"] ? " role=#{entry.fetch("role")}" : ""
      return {
        code: entry.fetch("missing_code"),
        path: "#{entry.fetch("path")}#{suffix}"
      }
    end
    nil
  end

  def validate_evaluation_access_record(root)
    bytes = validate_file_identity(
      root,
      EVALUATION_ACCESS_PATH,
      EVALUATION_ACCESS_BYTES,
      EVALUATION_ACCESS_SHA256,
      "P15_EVAL_012_CHRONOLOGY_INVALID",
      "P15 evaluation-access chronology",
      return_bytes: true
    )
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    required = [
      "- Phase: `P15`",
      "- Pre-implementation commit: " \
        "`#{PRE_IMPLEMENTATION_SUBJECT.fetch("commit")}`",
      "- Pre-implementation tree: " \
        "`#{PRE_IMPLEMENTATION_SUBJECT.fetch("tree")}`",
      "- Corpus class: `PROJECT_AUTHORED_SYNTHETIC`",
      "- Claim class: internal conformance only",
      "## Freeze Guard",
      "## Sealed Execution",
      "`P15-EVAL-012` fails closed"
    ]
    unless text.valid_encoding? &&
           required.all? { |line| text.include?(line) }
      fail!(
        "P15_EVAL_012_CHRONOLOGY_INVALID",
        "P15 evaluation-access chronology identity differs"
      )
    end
    {
      "path" => EVALUATION_ACCESS_PATH,
      "bytes" => EVALUATION_ACCESS_BYTES,
      "sha256" => EVALUATION_ACCESS_SHA256,
      "pre_implementation" => PRE_IMPLEMENTATION_SUBJECT
    }
  end

  def validate_release_manifest(root, manifest)
    exact_keys!(
      manifest,
      %w[
        schema_version release_id version source source_date_epoch topology
        entries release_set_sha256 release_input_inventory_sha256
      ],
      "P15_RELEASE_MANIFEST_INVALID",
      "release manifest"
    )
    unless manifest.fetch("schema_version") == 1 &&
           manifest.fetch("release_id") == "ptbr-nlu-p15-v1" &&
           positive_bounded_integer?(manifest.fetch("source_date_epoch"),
                                     4_102_444_800)
      fail!(
        "P15_RELEASE_MANIFEST_INVALID",
        "release identity or SOURCE_DATE_EPOCH differs"
      )
    end

    addon = load_json_path(
      root,
      "addon/config.yaml",
      "P15_RELEASE_MANIFEST_INVALID",
      "add-on metadata"
    )
    unless manifest.fetch("version") == addon.fetch("version")
      fail!("P15_RELEASE_MANIFEST_INVALID", "release version differs")
    end

    source = manifest.fetch("source")
    exact_keys!(
      source,
      %w[commit tree],
      "P15_RELEASE_MANIFEST_INVALID",
      "release source identity"
    )
    unless full_sha1?(source.fetch("commit")) && full_sha1?(source.fetch("tree"))
      fail!(
        "P15_RELEASE_MANIFEST_INVALID",
        "release source identity is malformed"
      )
    end

    topology = manifest.fetch("topology")
    expected_topology = {
      "companion_archives" => 1,
      "companion_format" => "posix_ustar",
      "oci_archives" => 2,
      "oci_root_filesystem" => "scratch",
      "project_authored_packager" => true
    }
    unless topology == expected_topology
      fail!("P15_RELEASE_MANIFEST_INVALID", "release topology differs")
    end

    entries = manifest.fetch("entries")
    bounded_array!(
      entries,
      6,
      256,
      "P15_RELEASE_MANIFEST_INVALID",
      "release entries"
    )
    paths = []
    normalized = {}
    entries.each do |entry|
      exact_keys!(
        entry,
        %w[path kind architecture bytes sha256 mode media_type],
        "P15_RELEASE_MANIFEST_INVALID",
        "release entry"
      )
      path = entry.fetch("path")
      validate_release_path!(
        path,
        "P15_RELEASE_MANIFEST_INVALID",
        allow_license: true
      )
      if paths.include?(path)
        fail!("P15_RELEASE_MANIFEST_INVALID", "release entry is duplicated")
      end
      paths << path
      unless positive_bounded_integer?(entry.fetch("bytes"),
                                       MAX_ARTIFACT_BYTES) &&
             sha256?(entry.fetch("sha256")) &&
             entry.fetch("mode").is_a?(String) &&
             entry.fetch("mode").match?(/\A0[0-7]{3}\z/) &&
             safe_token?(entry.fetch("kind"), 64) &&
             safe_token?(entry.fetch("architecture"), 32) &&
             safe_media_type?(entry.fetch("media_type"))
        fail!(
          "P15_RELEASE_MANIFEST_INVALID",
          "release entry fields are malformed"
        )
      end
      validate_file_identity(
        root,
        path,
        entry.fetch("bytes"),
        entry.fetch("sha256"),
        "P15_RELEASE_MANIFEST_INVALID",
        "release entry"
      )
      normalized[path] = entry
    end
    unless paths == paths.sort
      fail!("P15_RELEASE_MANIFEST_INVALID", "release entries are not sorted")
    end

    RELEASE_ENTRY_CONTRACT.each do |path, expected|
      entry = normalized[path]
      unless entry &&
             entry.fetch("kind") == expected.fetch("kind") &&
             entry.fetch("architecture") == expected.fetch("architecture")
        fail!(
          "P15_RELEASE_MANIFEST_INVALID",
          "mandatory release entry differs: #{path}"
        )
      end
    end
    normalized.each do |path, entry|
      next if RELEASE_ENTRY_CONTRACT.key?(path)
      unless path.match?(
        %r{\Arelease/p15/licenses/[a-z0-9][a-z0-9._+-]*\.txt\z}
      ) &&
             entry.fetch("kind") == "license_text" &&
             entry.fetch("architecture") == "all"
        fail!(
          "P15_RELEASE_MANIFEST_INVALID",
          "unexpected release entry: #{path}"
        )
      end
    end

    computed_set = release_set_sha256(entries)
    unless manifest.fetch("release_set_sha256") == computed_set &&
           sha256?(manifest.fetch("release_input_inventory_sha256"))
      fail!(
        "P15_RELEASE_MANIFEST_INVALID",
        "release set or input inventory digest differs"
      )
    end
    manifest_bytes = read_relative(
      root,
      RELEASE_MANIFEST_PATH,
      MAX_JSON_BYTES,
      "P15_RELEASE_MANIFEST_INVALID",
      "release manifest"
    )
    {
      source: source,
      source_date_epoch: manifest.fetch("source_date_epoch"),
      entries: normalized,
      release_set_sha256: computed_set,
      inventory_sha256: manifest.fetch("release_input_inventory_sha256"),
      manifest_sha256: Digest::SHA256.hexdigest(manifest_bytes),
      manifest_bytes: manifest_bytes.bytesize
    }
  rescue KeyError, TypeError
    fail!("P15_RELEASE_MANIFEST_INVALID", "release manifest is incomplete")
  end

  def release_set_sha256(entries)
    material = entries.map do |entry|
      [
        entry.fetch("path"),
        entry.fetch("kind"),
        entry.fetch("architecture"),
        entry.fetch("bytes").to_s,
        entry.fetch("sha256"),
        entry.fetch("mode"),
        entry.fetch("media_type")
      ].join("\0")
    end.join("\n") + "\n"
    Digest::SHA256.hexdigest("P15_RELEASE_SET_V1\0#{material}")
  end

  def validate_reconciliation(root, report, release)
    exact_keys!(
      report,
      %w[
        schema_version algorithm release_set_sha256 release_paths sources
        mappings bidirectional_complete unadmitted_sources prohibited_sources
        release_input_inventory_sha256
      ],
      "P15_RECONCILIATION_INVALID",
      "release reconciliation"
    )
    unless report.fetch("schema_version") == 1 &&
           report.fetch("algorithm") ==
             "p15-release-byte-source-bidirectional-v1" &&
           report.fetch("release_set_sha256") ==
             release.fetch(:release_set_sha256) &&
           report.fetch("bidirectional_complete") == true &&
           report.fetch("unadmitted_sources") == [] &&
           report.fetch("prohibited_sources") == []
      fail!(
        "P15_RECONCILIATION_INVALID",
        "release reconciliation gate differs"
      )
    end

    release_paths = report.fetch("release_paths")
    bounded_array!(
      release_paths,
      release.fetch(:entries).length,
      release.fetch(:entries).length,
      "P15_RECONCILIATION_INVALID",
      "reconciled release paths"
    )
    unless release_paths == release.fetch(:entries).keys.sort
      fail!(
        "P15_RECONCILIATION_INVALID",
        "reconciled release path set differs"
      )
    end

    sources = report.fetch("sources")
    bounded_array!(
      sources,
      1,
      512,
      "P15_RECONCILIATION_INVALID",
      "release input sources"
    )
    source_by_id = {}
    sources.each do |source|
      exact_keys!(
        source,
        %w[
          id version owner license source_bytes source_sha256 purpose
          admission_record_path admission_record_sha256 rights_evidence_sha256
          notice_required license_file build_only
        ],
        "P15_RECONCILIATION_INVALID",
        "release input source"
      )
      id = source.fetch("id")
      if source_by_id.key?(id) || !safe_token?(id, 96) ||
         !safe_text?(source.fetch("version"), 128) ||
         !safe_text?(source.fetch("owner"), 256) ||
         !eligible_license?(source.fetch("license")) ||
         !positive_bounded_integer?(source.fetch("source_bytes"),
                                    MAX_ARTIFACT_BYTES) ||
         !sha256?(source.fetch("source_sha256")) ||
         !%w[build runtime data packaging legal project].include?(
           source.fetch("purpose")
         ) ||
         !sha256?(source.fetch("admission_record_sha256")) ||
         !sha256?(source.fetch("rights_evidence_sha256")) ||
         ![true, false].include?(source.fetch("notice_required")) ||
         ![true, false].include?(source.fetch("build_only"))
        fail!(
          "P15_RECONCILIATION_INVALID",
          "release input source is malformed"
        )
      end
      admission_path = source.fetch("admission_record_path")
      validate_repository_path!(
        admission_path,
        "P15_RECONCILIATION_INVALID",
        "admission record"
      )
      admission_bytes = read_relative(
        root,
        admission_path,
        MAX_JSON_BYTES,
        "P15_RECONCILIATION_INVALID",
        "admission record"
      )
      unless Digest::SHA256.hexdigest(admission_bytes) ==
             source.fetch("admission_record_sha256")
        fail!(
          "P15_RECONCILIATION_INVALID",
          "admission record digest differs"
        )
      end
      license_path = source.fetch("license_file")
      unless release.fetch(:entries).key?(license_path) &&
             release.fetch(:entries).fetch(license_path).fetch("kind") ==
               "license_text"
        fail!(
          "P15_RECONCILIATION_INVALID",
          "source license file is absent from the release set"
        )
      end
      reject_prohibited_material!(
        source,
        "P15_RECONCILIATION_INVALID",
        "release input source"
      )
      source_by_id[id] = source
    end
    unless source_by_id.keys == source_by_id.keys.sort
      fail!(
        "P15_RECONCILIATION_INVALID",
        "release input sources are not sorted"
      )
    end

    mappings = report.fetch("mappings")
    bounded_array!(
      mappings,
      release_paths.length,
      release_paths.length,
      "P15_RECONCILIATION_INVALID",
      "release mappings"
    )
    mapping_by_path = {}
    used_sources = Set.new
    mappings.each do |mapping|
      exact_keys!(
        mapping,
        %w[release_path source_ids],
        "P15_RECONCILIATION_INVALID",
        "release mapping"
      )
      path = mapping.fetch("release_path")
      ids = mapping.fetch("source_ids")
      if mapping_by_path.key?(path) || !release.fetch(:entries).key?(path)
        fail!(
          "P15_RECONCILIATION_INVALID",
          "release mapping path differs"
        )
      end
      bounded_array!(
        ids,
        1,
        128,
        "P15_RECONCILIATION_INVALID",
        "release mapping source IDs"
      )
      unless ids == ids.sort && ids.uniq.length == ids.length &&
             ids.all? { |id| source_by_id.key?(id) }
        fail!(
          "P15_RECONCILIATION_INVALID",
          "release mapping source IDs differ"
        )
      end
      ids.each { |id| used_sources.add(id) }
      mapping_by_path[path] = ids
    end
    unless mapping_by_path.keys.sort == release_paths
      fail!(
        "P15_RECONCILIATION_INVALID",
        "release mappings are not bidirectionally complete"
      )
    end
    source_by_id.each do |id, source|
      next if used_sources.include?(id) || source.fetch("build_only") == true

      fail!(
        "P15_RECONCILIATION_INVALID",
        "unused non-build-only source remains: #{id}"
      )
    end

    inventory = inventory_sha256(sources)
    unless report.fetch("release_input_inventory_sha256") == inventory &&
           inventory == release.fetch(:inventory_sha256)
      fail!(
        "P15_RECONCILIATION_INVALID",
        "release input inventory digest differs"
      )
    end
    {
      sources: source_by_id,
      mappings: mapping_by_path,
      inventory_sha256: inventory
    }
  rescue KeyError, TypeError
    fail!("P15_RECONCILIATION_INVALID", "release reconciliation is incomplete")
  end

  def inventory_sha256(sources)
    material = sources.map do |source|
      %w[
        id version owner license source_bytes source_sha256 purpose
        admission_record_path admission_record_sha256 rights_evidence_sha256
        notice_required license_file build_only
      ].map { |key| canonical_scalar(source.fetch(key)) }.join("\0")
    end.join("\n") + "\n"
    Digest::SHA256.hexdigest("P15_RELEASE_INPUT_INVENTORY_V1\0#{material}")
  end

  def validate_sbom(sbom, release, reconciliation)
    exact_keys!(
      sbom,
      %w[
        spdxVersion dataLicense SPDXID name documentNamespace creationInfo
        packages files relationships
      ],
      "P15_SBOM_INVALID",
      "SPDX SBOM"
    )
    expected_namespace =
      "https://local.invalid/ptbr-nlu/p15/" \
      "#{release.fetch(:release_set_sha256)}"
    unless sbom.fetch("spdxVersion") == "SPDX-2.3" &&
           sbom.fetch("dataLicense") == "CC0-1.0" &&
           sbom.fetch("SPDXID") == "SPDXRef-DOCUMENT" &&
           sbom.fetch("name") == "ptbr-nlu-p15-release" &&
           sbom.fetch("documentNamespace") == expected_namespace
      fail!("P15_SBOM_INVALID", "SPDX document identity differs")
    end
    creation = sbom.fetch("creationInfo")
    exact_keys!(
      creation,
      %w[created creators],
      "P15_SBOM_INVALID",
      "SPDX creation info"
    )
    expected_created =
      Time.at(release.fetch(:source_date_epoch)).utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    unless creation.fetch("created") == expected_created &&
           creation.fetch("creators") ==
             ["Tool: p15-project-authored-packager/1"]
      fail!("P15_SBOM_INVALID", "SPDX creation identity differs")
    end

    packages = sbom.fetch("packages")
    bounded_array!(
      packages,
      reconciliation.fetch(:sources).length,
      reconciliation.fetch(:sources).length,
      "P15_SBOM_INVALID",
      "SPDX packages"
    )
    package_ids = {}
    packages.each do |package|
      exact_keys!(
        package,
        %w[
          name SPDXID versionInfo downloadLocation filesAnalyzed
          licenseConcluded licenseDeclared copyrightText
        ],
        "P15_SBOM_INVALID",
        "SPDX package"
      )
      source = reconciliation.fetch(:sources)[package.fetch("name")]
      expected_id = "SPDXRef-Package-#{spdx_token(package.fetch("name"))}"
      unless source &&
             package.fetch("SPDXID") == expected_id &&
             package.fetch("versionInfo") == source.fetch("version") &&
             package.fetch("downloadLocation") == "NOASSERTION" &&
             package.fetch("filesAnalyzed") == false &&
             package.fetch("licenseConcluded") == source.fetch("license") &&
             package.fetch("licenseDeclared") == source.fetch("license") &&
             safe_text?(package.fetch("copyrightText"), 2_048)
        fail!("P15_SBOM_INVALID", "SPDX package differs")
      end
      package_ids[source.fetch("id")] = expected_id
    end
    unless package_ids.keys.sort == reconciliation.fetch(:sources).keys.sort
      fail!("P15_SBOM_INVALID", "SPDX package closure differs")
    end

    covered_paths = release.fetch(:entries).keys.reject do |path|
      path == SBOM_PATH
    end.sort
    files = sbom.fetch("files")
    bounded_array!(
      files,
      covered_paths.length,
      covered_paths.length,
      "P15_SBOM_INVALID",
      "SPDX files"
    )
    file_ids = {}
    files.each do |file|
      exact_keys!(
        file,
        %w[fileName SPDXID checksums licenseConcluded copyrightText],
        "P15_SBOM_INVALID",
        "SPDX file"
      )
      path = file.fetch("fileName")
      entry = release.fetch(:entries)[path]
      expected_id = "SPDXRef-File-#{Digest::SHA256.hexdigest(path)[0, 24]}"
      unless entry &&
             path != SBOM_PATH &&
             file.fetch("SPDXID") == expected_id &&
             file.fetch("checksums") == [
               {
                 "algorithm" => "SHA256",
                 "checksumValue" => entry.fetch("sha256")
               }
             ] &&
             file.fetch("licenseConcluded") != "NOASSERTION" &&
             safe_text?(file.fetch("copyrightText"), 2_048)
        fail!("P15_SBOM_INVALID", "SPDX file differs")
      end
      file_ids[path] = expected_id
    end
    unless file_ids.keys.sort == covered_paths
      fail!("P15_SBOM_INVALID", "SPDX file closure differs")
    end

    expected_relationships = []
    package_ids.each_value do |package_id|
      expected_relationships << {
        "spdxElementId" => "SPDXRef-DOCUMENT",
        "relationshipType" => "DESCRIBES",
        "relatedSpdxElement" => package_id
      }
    end
    reconciliation.fetch(:mappings).each do |path, ids|
      next if path == SBOM_PATH
      ids.each do |id|
        expected_relationships << {
          "spdxElementId" => file_ids.fetch(path),
          "relationshipType" => "GENERATED_FROM",
          "relatedSpdxElement" => package_ids.fetch(id)
        }
      end
    end
    expected_relationships.sort_by! do |relationship|
      [
        relationship.fetch("spdxElementId"),
        relationship.fetch("relationshipType"),
        relationship.fetch("relatedSpdxElement")
      ]
    end
    unless sbom.fetch("relationships") == expected_relationships
      fail!("P15_SBOM_INVALID", "SPDX relationships differ")
    end
    reject_prohibited_material!(sbom, "P15_SBOM_INVALID", "SPDX SBOM")
    true
  rescue KeyError, TypeError
    fail!("P15_SBOM_INVALID", "SPDX SBOM is incomplete")
  end

  def validate_notices(bytes, release, reconciliation)
    unless bytes.valid_encoding? && bytes.encoding == Encoding::UTF_8
      bytes = bytes.dup.force_encoding(Encoding::UTF_8)
    end
    unless bytes.valid_encoding?
      fail!("P15_NOTICES_INVALID", "notices are not valid UTF-8")
    end
    lines = bytes.lines.map(&:chomp)
    expected = [
      "PTBR-NLU THIRD-PARTY NOTICES V1",
      "Release-Set-SHA256: #{release.fetch(:release_set_sha256)}"
    ]
    reconciliation.fetch(:sources).keys.sort.each do |id|
      source = reconciliation.fetch(:sources).fetch(id)
      next unless source.fetch("notice_required")

      expected.concat(
        [
          "",
          "Component: #{id}",
          "Version: #{source.fetch("version")}",
          "Owner: #{source.fetch("owner")}",
          "License: #{source.fetch("license")}",
          "License-File: #{source.fetch("license_file")}",
          "Source-SHA256: #{source.fetch("source_sha256")}",
          "Rights-Evidence-SHA256: " \
            "#{source.fetch("rights_evidence_sha256")}"
        ]
      )
    end
    unless lines == expected
      fail!(
        "P15_NOTICES_INVALID",
        "notices do not exactly cover admitted release inputs"
      )
    end
    reject_prohibited_material!(
      bytes,
      "P15_NOTICES_INVALID",
      "third-party notices"
    )
    true
  end

  def validate_checksums(bytes, root, release)
    expected_paths = (
      release.fetch(:entries).keys + [RELEASE_MANIFEST_PATH]
    ).sort
    lines = bytes.lines.map(&:chomp)
    if lines.length != expected_paths.length || lines.any?(&:empty?)
      fail!("P15_CHECKSUMS_INVALID", "checksum entry count differs")
    end
    parsed = {}
    lines.each do |line|
      match = line.match(/\A([0-9a-f]{64})  ([a-zA-Z0-9._+\/-]+)\z/)
      fail!("P15_CHECKSUMS_INVALID", "checksum line is malformed") unless match
      path = match[2]
      validate_release_path!(
        path,
        "P15_CHECKSUMS_INVALID",
        allow_manifest: true,
        allow_license: true
      )
      if parsed.key?(path)
        fail!("P15_CHECKSUMS_INVALID", "checksum path is duplicated")
      end
      parsed[path] = match[1]
    end
    unless parsed.keys == expected_paths
      fail!("P15_CHECKSUMS_INVALID", "checksum path set differs")
    end
    expected_paths.each do |path|
      actual = Digest::SHA256.file(File.join(root, path)).hexdigest
      unless parsed.fetch(path) == actual
        fail!("P15_CHECKSUMS_INVALID", "checksum differs: #{path}")
      end
    end
    true
  rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
    fail!("P15_CHECKSUMS_INVALID", "checksummed file cannot be read")
  end

  def validate_frozen_inputs(root)
    P02_FILES.each_value do |identity|
      validate_file_identity(
        root,
        identity.fetch("path"),
        identity["bytes"],
        identity.fetch("sha256"),
        "P15_FROZEN_INPUT_IDENTITY_INVALID",
        "frozen P02 input"
      )
    end
    SUITES.each_value do |identity|
      validate_file_identity(
        root,
        identity.fetch("path"),
        identity.fetch("bytes"),
        identity.fetch("sha256"),
        "P15_FROZEN_INPUT_IDENTITY_INVALID",
        "frozen P02 suite"
      )
    end
    manifest = load_json_path(
      root,
      P02_FILES.fetch("manifest").fetch("path"),
      "P15_FROZEN_INPUT_IDENTITY_INVALID",
      "P02 manifest",
      max_bytes: 64 * 1024
    )
    taxonomies = manifest.fetch("taxonomies")
    dimensions = taxonomies.fetch("dimensions")
    unless dimensions == FROZEN_DIMENSIONS
      fail!(
        "P15_FROZEN_INPUT_IDENTITY_INVALID",
        "P02 frozen dimensions differ"
      )
    end
    heldout_counts = normalize_taxonomy_counts(
      taxonomies.fetch("heldout_counts"),
      "heldout"
    )
    performance_counts = normalize_taxonomy_counts(
      taxonomies.fetch("performance_counts"),
      "performance"
    )
    suite_classes = taxonomies.fetch("suite_classes")
    unless suite_classes.keys.sort == SUITES.keys.sort
      fail!(
        "P15_FROZEN_INPUT_IDENTITY_INVALID",
        "P02 suite taxonomy differs"
      )
    end
    classes = {}
    suite_classes.keys.sort.each do |suite|
      values = suite_classes.fetch(suite)
      bounded_array!(
        values,
        1,
        128,
        "P15_FROZEN_INPUT_IDENTITY_INVALID",
        "P02 suite classes"
      )
      unless values.uniq.length == values.length &&
             values.all? { |value| safe_token?(value, 128) }
        fail!(
          "P15_FROZEN_INPUT_IDENTITY_INVALID",
          "P02 suite classes differ"
        )
      end
      unless values.length == SUITES.fetch(suite).fetch("records")
        fail!(
          "P15_FROZEN_INPUT_IDENTITY_INVALID",
          "P02 suite class cardinality differs"
        )
      end
      classes[suite] = values
    end
    {
      heldout_counts: heldout_counts,
      performance_counts: performance_counts,
      suite_classes: classes
    }
  rescue KeyError, TypeError
    fail!(
      "P15_FROZEN_INPUT_IDENTITY_INVALID",
      "P02 manifest is incomplete"
    )
  end

  def normalize_taxonomy_counts(counts, label)
    expected_dimensions = FROZEN_DIMENSIONS + ["target_cardinality"]
    unless counts.is_a?(Hash) && counts.keys == expected_dimensions
      fail!(
        "P15_FROZEN_INPUT_IDENTITY_INVALID",
        "#{label} taxonomy dimensions differ"
      )
    end
    normalized = {}
    counts.each do |dimension, strata|
      unless strata.is_a?(Hash) && !strata.empty? && strata.length <= 256
        fail!(
          "P15_FROZEN_INPUT_IDENTITY_INVALID",
          "#{label} taxonomy is malformed"
        )
      end
      values = {}
      strata.each do |value, count|
        unless safe_text?(value, 256) &&
               positive_bounded_integer?(count, 4_800) &&
               count >= 240
          fail!(
            "P15_FROZEN_INPUT_IDENTITY_INVALID",
            "#{label} taxonomy quota differs"
          )
        end
        values[value] = count
      end
      unless values.values.sum == 4_800
        fail!(
          "P15_FROZEN_INPUT_IDENTITY_INVALID",
          "#{label} taxonomy denominator differs"
        )
      end
      normalized[dimension] = values
    end
    normalized.select { |dimension, _values| FROZEN_DIMENSIONS.include?(dimension) }
  end

  def validate_evaluation_report(report, frozen, source)
    exact_keys!(
      report,
      %w[
        schema_version report_kind source_subject runner isolation aggregate
        suite_classes
      ],
      "P15_EVALUATION_REPORT_INVALID",
      "evaluation report"
    )
    unless report.fetch("schema_version") == 1 &&
           report.fetch("report_kind") == "P15_RELEASE_EVALUATION_V1" &&
           report.fetch("source_subject") == source
      fail!(
        "P15_EVALUATION_REPORT_INVALID",
        "evaluation report identity differs"
      )
    end
    runner = report.fetch("runner")
    exact_keys!(
      runner,
      %w[id executable_path executable_bytes executable_sha256],
      "P15_EVALUATION_REPORT_INVALID",
      "evaluation runner"
    )
    unless runner.fetch("id") == "p15-release-eval-v1" &&
           safe_release_evidence_path?(runner.fetch("executable_path")) &&
           positive_bounded_integer?(runner.fetch("executable_bytes"),
                                     MAX_ARTIFACT_BYTES) &&
           sha256?(runner.fetch("executable_sha256"))
      fail!(
        "P15_EVALUATION_REPORT_INVALID",
        "evaluation runner identity differs"
      )
    end
    isolation = report.fetch("isolation")
    expected_isolation = {
      "access_chronology_sha256" => EVALUATION_ACCESS_SHA256,
      "aggregate_only" => true,
      "case_level_output" => false,
      "heldout_access" => "sealed_runner_only",
      "per_case_diagnostics" => false,
      "product_tuning_after_access" => false,
      "production_path" =>
        "nlu_server::NluRuntime::dispatch_at/protocol-v2",
      "protocol_version" => 2
    }
    unless isolation == expected_isolation
      fail!(
        "P15_EVALUATION_ISOLATION_INVALID",
        "held-out isolation contract differs"
      )
    end

    aggregate = report.fetch("aggregate")
    validate_aggregate_report(
      aggregate,
      "heldout",
      P02_FILES.fetch("heldout"),
      frozen.fetch(:heldout_counts)
    )
    classes = report.fetch("suite_classes")
    unless classes.is_a?(Hash) && classes.keys.sort == SUITES.keys.sort
      fail!(
        "P15_EVALUATION_REPORT_INVALID",
        "negative-suite class report set differs"
      )
    end
    classes.keys.sort.each do |suite|
      rows = classes.fetch(suite)
      expected_classes = frozen.fetch(:suite_classes).fetch(suite)
      bounded_array!(
        rows,
        expected_classes.length,
        expected_classes.length,
        "P15_EVALUATION_REPORT_INVALID",
        "negative-suite class rows"
      )
      observed_classes = rows.map do |row|
        exact_keys!(
          row,
          %w[
            coverage_class expected_records observed_records false_plans
            zero_false_plan_gate
          ],
          "P15_EVALUATION_REPORT_INVALID",
          "negative-suite class row"
        )
        unless row.fetch("expected_records") == 1 &&
               row.fetch("observed_records") == 1 &&
               row.fetch("false_plans") == 0 &&
               row.fetch("zero_false_plan_gate") == "pass"
          fail!(
            "P15_EVALUATION_GATE_FAILED",
            "negative-suite class gate failed"
          )
        end
        row.fetch("coverage_class")
      end
      unless observed_classes == expected_classes
        fail!(
          "P15_EVALUATION_REPORT_INVALID",
          "negative-suite class identity differs"
        )
      end
    end
    reject_case_level_fields!(
      report,
      "P15_EVALUATION_ISOLATION_INVALID"
    )
    true
  rescue KeyError, TypeError
    fail!("P15_EVALUATION_REPORT_INVALID", "evaluation report is incomplete")
  end

  def validate_aggregate_report(report, split, split_identity, expected_counts)
    exact_keys!(
      report,
      %w[
        schema_version runner_id metric_specification split source
        reconciliation overall outcomes dimensions macro_by_dimension
        negative_suites insufficiently_evaluated limitations
      ],
      "P15_EVALUATION_REPORT_INVALID",
      "aggregate evaluation"
    )
    unless report.fetch("schema_version") == 1 &&
           report.fetch("runner_id") == "p15-release-eval-v1" &&
           report.fetch("metric_specification") ==
             "p15-aggregate-intent-slot-entity-graph-outcome-wilson-v1" &&
           report.fetch("split") == split
      fail!(
        "P15_EVALUATION_REPORT_INVALID",
        "aggregate evaluation identity differs"
      )
    end
    source = report.fetch("source")
    exact_keys!(
      source,
      %w[
        source_id corpus_version claim_scope manifest_sha256
        specification_sha256 projection_sha256 split_sha256 records
      ],
      "P15_EVALUATION_REPORT_INVALID",
      "aggregate source"
    )
    unless source == {
      "source_id" => "project-authored-synthetic-ptbr-v1",
      "corpus_version" => "1.0.0",
      "claim_scope" => "internal_conformance_only",
      "manifest_sha256" =>
        P02_FILES.fetch("manifest").fetch("sha256"),
      "specification_sha256" =>
        P02_FILES.fetch("specification").fetch("sha256"),
      "projection_sha256" => {
        "p09_pre_resolution" =>
          P02_FILES.fetch("p09_projection").fetch("sha256"),
        "p11_semantic_plan" =>
          P02_FILES.fetch("p11_projection").fetch("sha256")
      },
      "split_sha256" => split_identity.fetch("sha256"),
      "records" => 4_800
    }
      fail!(
        "P15_EVALUATION_REPORT_INVALID",
        "aggregate frozen source identity differs"
      )
    end
    reconciliation = report.fetch("reconciliation")
    unless reconciliation == {
      "expected_records" => 4_800,
      "observed_records" => 4_800,
      "dimension_denominators_complete" => true,
      "negative_suite_denominators_complete" => true,
      "complete" => true
    }
      fail!(
        "P15_EVALUATION_GATE_FAILED",
        "aggregate denominator reconciliation failed"
      )
    end

    overall = validate_semantic_metric_set(
      report.fetch("overall"),
      "overall"
    )
    graph = overall.fetch("graph_exact")
    unless graph.fetch("denominator") >= MINIMUM_GLOBAL_CASES &&
           graph.fetch("wilson_95").fetch("lower_ppm") >= REQUIRED_RATE_PPM
      fail!(
        "P15_EVALUATION_GATE_FAILED",
        "global exact-semantic Wilson gate failed"
      )
    end

    outcomes = report.fetch("outcomes")
    exact_keys!(
      outcomes,
      %w[
        plans clarifications abstentions_or_denials errors
        clarification_exact abstention_exact false_plan_rate
      ],
      "P15_EVALUATION_REPORT_INVALID",
      "outcome metrics"
    )
    total_outcomes = %w[
      plans clarifications abstentions_or_denials errors
    ].map { |key| outcomes.fetch(key) }.sum
    unless total_outcomes == 4_800
      fail!(
        "P15_EVALUATION_REPORT_INVALID",
        "outcome denominator differs"
      )
    end
    clarification = validate_metric(
      outcomes.fetch("clarification_exact"),
      "clarification exact"
    )
    abstention = validate_metric(
      outcomes.fetch("abstention_exact"),
      "abstention exact"
    )
    false_plan = validate_metric(
      outcomes.fetch("false_plan_rate"),
      "false-plan rate"
    )
    unless clarification.fetch("numerator") == 5 &&
           clarification.fetch("denominator") == 5 &&
           abstention.fetch("numerator") == 22 &&
           abstention.fetch("denominator") == 22 &&
           false_plan.fetch("numerator") == 0 &&
           false_plan.fetch("denominator") == 27
      fail!(
        "P15_EVALUATION_GATE_FAILED",
        "clarification, abstention, or false-plan gate failed"
      )
    end

    dimensions = report.fetch("dimensions")
    macros = report.fetch("macro_by_dimension")
    unless dimensions.is_a?(Hash) &&
           dimensions.keys == FROZEN_DIMENSIONS &&
           macros.is_a?(Hash) &&
           macros.keys == FROZEN_DIMENSIONS
      fail!(
        "P15_EVALUATION_REPORT_INVALID",
        "frozen dimension report set differs"
      )
    end
    FROZEN_DIMENSIONS.each do |dimension|
      rows = dimensions.fetch(dimension)
      expected = expected_counts.fetch(dimension)
      bounded_array!(
        rows,
        expected.length,
        expected.length,
        "P15_EVALUATION_REPORT_INVALID",
        "stratum rows"
      )
      observed = {}
      metric_sets = []
      rows.each do |row|
        exact_keys!(
          row,
          %w[value records metrics],
          "P15_EVALUATION_REPORT_INVALID",
          "stratum row"
        )
        value = row.fetch("value")
        if observed.key?(value) || !expected.key?(value) ||
           row.fetch("records") != expected.fetch(value)
          fail!(
            "P15_EVALUATION_REPORT_INVALID",
            "stratum identity or denominator differs"
          )
        end
        metrics = validate_semantic_metric_set(
          row.fetch("metrics"),
          "#{dimension} stratum"
        )
        graph_metric = metrics.fetch("graph_exact")
        unless graph_metric.fetch("denominator") >=
               MINIMUM_SUPPORTED_STRATUM &&
               graph_metric.fetch("wilson_95").fetch("lower_ppm") >=
                 REQUIRED_RATE_PPM
          fail!(
            "P15_EVALUATION_GATE_FAILED",
            "#{dimension} stratum Wilson gate failed"
          )
        end
        observed[value] = row.fetch("records")
        metric_sets << metrics
      end
      unless observed.keys == expected.keys.sort
        fail!(
          "P15_EVALUATION_REPORT_INVALID",
          "#{dimension} stratum order differs"
        )
      end
      validate_macro_set(
        macros.fetch(dimension),
        metric_sets,
        dimension
      )
    end

    suites = report.fetch("negative_suites")
    bounded_array!(
      suites,
      SUITES.length,
      SUITES.length,
      "P15_EVALUATION_REPORT_INVALID",
      "negative suites"
    )
    observed_suites = suites.map do |suite|
      exact_keys!(
        suite,
        %w[
          suite expected_records observed_records false_plans
          zero_false_plan_gate
        ],
        "P15_EVALUATION_REPORT_INVALID",
        "negative suite"
      )
      name = suite.fetch("suite")
      identity = SUITES[name]
      unless identity &&
             suite.fetch("expected_records") == identity.fetch("records") &&
             suite.fetch("observed_records") == identity.fetch("records") &&
             suite.fetch("false_plans") == 0 &&
             suite.fetch("zero_false_plan_gate") == "pass"
        fail!(
          "P15_EVALUATION_GATE_FAILED",
          "negative-suite zero-false-plan gate failed"
        )
      end
      name
    end
    unless observed_suites == SUITES.keys.sort
      fail!(
        "P15_EVALUATION_REPORT_INVALID",
        "negative suite order differs"
      )
    end

    insufficient = report.fetch("insufficiently_evaluated")
    expected_insufficient = [
      {
        "metric" => "semantic_accuracy",
        "dimension" => "noise",
        "value" => "asr_noise",
        "eligible_records" => 0,
        "required_records" => 237,
        "disposition" => "insufficient_no_frozen_cases"
      },
      {
        "metric" => "abstention_exact",
        "dimension" => "outcome",
        "value" => "abstention",
        "eligible_records" => 22,
        "required_records" => 237,
        "disposition" => "insufficient_below_frozen_quota"
      },
      {
        "metric" => "clarification_exact",
        "dimension" => "outcome",
        "value" => "clarification",
        "eligible_records" => 5,
        "required_records" => 237,
        "disposition" => "insufficient_below_frozen_quota"
      }
    ].sort_by { |row| [row["dimension"], row["value"], row["metric"]] }
    unless insufficient == expected_insufficient
      fail!(
        "P15_EVALUATION_REPORT_INVALID",
        "insufficiently-evaluated strata differ"
      )
    end
    expected_limitations = %w[
      project_authored_internal_conformance_only
      not_independent_language_accuracy
      aggregate_only_no_case_level_output
      asr_noise_has_no_frozen_release_quota
      clarification_and_abstention_below_frozen_supported_quota
      policy_carried_complete_plans_are_semantically_scored_but_never_execution_authority
    ]
    unless report.fetch("limitations") == expected_limitations
      fail!(
        "P15_EVALUATION_REPORT_INVALID",
        "evaluation limitations differ"
      )
    end
    true
  rescue KeyError, TypeError
    fail!("P15_EVALUATION_REPORT_INVALID", "aggregate report is incomplete")
  end

  def validate_semantic_metric_set(metrics, label)
    exact_keys!(
      metrics,
      SEMANTIC_METRICS,
      "P15_EVALUATION_REPORT_INVALID",
      "#{label} metrics"
    )
    result = {}
    SEMANTIC_METRICS.each do |name|
      result[name] = validate_metric(metrics.fetch(name), "#{label} #{name}")
    end
    graph = result.fetch("graph_exact")
    %w[intent_exact slot_exact final_outcome_exact].each do |name|
      metric = result.fetch(name)
      if metric.fetch("denominator") == graph.fetch("denominator") &&
         metric.fetch("numerator") < graph.fetch("numerator")
        fail!(
          "P15_EVALUATION_REPORT_INVALID",
          "#{label} semantic metric ordering is impossible"
        )
      end
    end
    result
  end

  def validate_metric(metric, label)
    exact_keys!(
      metric,
      %w[
        numerator denominator rate_ppm wilson_95 support
        minimum_supported_denominator
      ],
      "P15_EVALUATION_REPORT_INVALID",
      label
    )
    numerator = metric.fetch("numerator")
    denominator = metric.fetch("denominator")
    unless numerator.is_a?(Integer) && denominator.is_a?(Integer) &&
           numerator >= 0 && denominator >= 0 &&
           numerator <= denominator && denominator <= 4_800 &&
           metric.fetch("minimum_supported_denominator") ==
             MINIMUM_SUPPORTED_STRATUM
      fail!(
        "P15_EVALUATION_REPORT_INVALID",
        "#{label} counts are malformed"
      )
    end
    expected_rate =
      denominator.zero? ? nil : ratio_ppm(numerator, denominator)
    expected_wilson =
      denominator.zero? ? nil : wilson_95(numerator, denominator)
    expected_support =
      denominator >= MINIMUM_SUPPORTED_STRATUM ? "sufficient" : "insufficient"
    unless metric.fetch("rate_ppm") == expected_rate &&
           metric.fetch("wilson_95") == expected_wilson &&
           metric.fetch("support") == expected_support
      fail!(
        "P15_EVALUATION_REPORT_INVALID",
        "#{label} derived values differ"
      )
    end
    metric
  end

  def validate_macro_set(macro_set, metric_sets, dimension)
    exact_keys!(
      macro_set,
      SEMANTIC_METRICS,
      "P15_EVALUATION_REPORT_INVALID",
      "#{dimension} macro metrics"
    )
    SEMANTIC_METRICS.each do |name|
      metric = macro_set.fetch(name)
      exact_keys!(
        metric,
        %w[strata_included mean_rate_ppm],
        "P15_EVALUATION_REPORT_INVALID",
        "#{dimension} macro metric"
      )
      rates = metric_sets.map { |set| set.fetch(name).fetch("rate_ppm") }
                         .compact
      expected_mean =
        if rates.empty?
          nil
        else
          (rates.sum + (rates.length / 2)) / rates.length
        end
      unless metric.fetch("strata_included") == rates.length &&
             metric.fetch("mean_rate_ppm") == expected_mean
        fail!(
          "P15_EVALUATION_REPORT_INVALID",
          "#{dimension} macro recomputation differs"
        )
      end
      if name == "graph_exact" &&
         (expected_mean.nil? || expected_mean < REQUIRED_RATE_PPM)
        fail!(
          "P15_EVALUATION_GATE_FAILED",
          "#{dimension} unweighted macro gate failed"
        )
      end
    end
    true
  end

  def ratio_ppm(numerator, denominator)
    ((numerator * 1_000_000) + (denominator / 2)) / denominator
  end

  def wilson_95(successes, total)
    z = 1.959_963_984_540_054
    n = total.to_f
    p = successes.to_f / n
    z2 = z * z
    denominator = 1.0 + (z2 / n)
    center = (p + (z2 / (2.0 * n))) / denominator
    margin =
      z * Math.sqrt((p * (1.0 - p) / n) + (z2 / (4.0 * n * n))) /
      denominator
    {
      "lower_ppm" => (((center - margin).clamp(0.0, 1.0)) * 1_000_000).round,
      "upper_ppm" => (((center + margin).clamp(0.0, 1.0)) * 1_000_000).round
    }
  end

  def validate_performance_report(report, frozen, source, release)
    exact_keys!(
      report,
      %w[
        schema_version report_kind source_subject corpus hardware thresholds
        semantic_preflight core warm_end_to_end resources
      ],
      "P15_PERFORMANCE_REPORT_INVALID",
      "performance report"
    )
    unless report.fetch("schema_version") == 1 &&
           report.fetch("report_kind") == "P15_PERFORMANCE_REPORT_V1" &&
           report.fetch("source_subject") == source
      fail!(
        "P15_PERFORMANCE_REPORT_INVALID",
        "performance report identity differs"
      )
    end
    corpus = report.fetch("corpus")
    unless corpus == {
      "path" => P02_FILES.fetch("performance").fetch("path"),
      "sha256" => P02_FILES.fetch("performance").fetch("sha256"),
      "records" => 4_800,
      "complete_canonical_cycles_only" => true
    }
      fail!(
        "P15_PERFORMANCE_REPORT_INVALID",
        "performance corpus identity differs"
      )
    end
    hardware = report.fetch("hardware")
    exact_keys!(
      hardware,
      %w[
        os kernel architecture cpu_model logical_cpus isolated_core
        memory_bytes compiler build_profile native_hardware emulator
      ],
      "P15_PERFORMANCE_REPORT_INVALID",
      "performance hardware"
    )
    unless hardware.fetch("os") == "Linux" &&
           safe_text?(hardware.fetch("kernel"), 256) &&
           %w[x86_64 aarch64].include?(hardware.fetch("architecture")) &&
           safe_text?(hardware.fetch("cpu_model"), 512) &&
           positive_bounded_integer?(hardware.fetch("logical_cpus"), 4_096) &&
           hardware.fetch("isolated_core").is_a?(Integer) &&
           hardware.fetch("isolated_core") >= 0 &&
           positive_bounded_integer?(hardware.fetch("memory_bytes"),
                                     (1 << 60)) &&
           hardware.fetch("compiler") == "rustc 1.98.0" &&
           hardware.fetch("build_profile") == "release" &&
           hardware.fetch("native_hardware") == true &&
           hardware.fetch("emulator") == false
      fail!(
        "P15_PERFORMANCE_REPORT_INVALID",
        "performance hardware is not exact native Linux evidence"
      )
    end
    thresholds = report.fetch("thresholds")
    unless thresholds == [
      {
        "requirement" => "ADR-0005-core-throughput",
        "boundary" => "core",
        "metric" => "words_per_second",
        "minimum_milli" => 20_000_000
      },
      {
        "requirement" => "ADR-0005-warm-end-to-end-throughput",
        "boundary" => "warm_end_to_end",
        "metric" => "utterances_per_second",
        "minimum_milli" => 400_000
      }
    ]
      fail!(
        "P15_PERFORMANCE_REPORT_INVALID",
        "performance threshold provenance differs"
      )
    end
    preflight = report.fetch("semantic_preflight")
    exact_keys!(
      preflight,
      %w[sha256 reconciled complete_corpus per_stratum],
      "P15_PERFORMANCE_REPORT_INVALID",
      "semantic preflight"
    )
    unless sha256?(preflight.fetch("sha256")) &&
           preflight.fetch("reconciled") == true &&
           preflight.fetch("complete_corpus") == "PASS" &&
           preflight.fetch("per_stratum") == "PASS"
      fail!(
        "P15_PERFORMANCE_GATE_FAILED",
        "semantic preflight failed"
      )
    end

    validate_benchmark_boundary(
      report.fetch("core"),
      "core",
      "words",
      20_000_000,
      frozen.fetch(:performance_counts),
      {
        "definition" =>
          "single_thread_complete_in_memory_pipeline_without_startup_io_or_adapter",
        "threads" => 1,
        "rust_adapter" => false,
        "python_companion" => false,
        "home_assistant_fixture" => false
      }
    )
    validate_benchmark_boundary(
      report.fetch("warm_end_to_end"),
      "warm_end_to_end",
      "utterances",
      400_000,
      frozen.fetch(:performance_counts),
      {
        "definition" =>
          "rust_adapter_protocol_v2_python_companion_and_in_process_non_residential_home_assistant_fixture",
        "threads" => 1,
        "rust_adapter" => true,
        "python_companion" => true,
        "home_assistant_fixture" => true
      }
    )
    resources = report.fetch("resources")
    exact_keys!(
      resources,
      %w[startup_ns peak_rss_bytes artifact_sizes artifact_size_total],
      "P15_PERFORMANCE_REPORT_INVALID",
      "performance resources"
    )
    unless positive_bounded_integer?(resources.fetch("startup_ns"), (1 << 63)) &&
           positive_bounded_integer?(resources.fetch("peak_rss_bytes"),
                                     (1 << 60)) &&
           resources.fetch("artifact_sizes").is_a?(Hash)
      fail!(
        "P15_PERFORMANCE_REPORT_INVALID",
        "performance resource evidence is malformed"
      )
    end
    expected_sizes = {}
    release.fetch(:entries).each do |path, entry|
      next unless RELEASE_ENTRY_CONTRACT.key?(path)
      expected_sizes[path] = entry.fetch("bytes")
    end
    unless resources.fetch("artifact_sizes") == expected_sizes &&
           resources.fetch("artifact_size_total") == expected_sizes.values.sum
      fail!(
        "P15_PERFORMANCE_REPORT_INVALID",
        "artifact size evidence differs"
      )
    end
    reject_case_level_fields!(
      report,
      "P15_PERFORMANCE_REPORT_INVALID"
    )
    true
  rescue KeyError, TypeError
    fail!(
      "P15_PERFORMANCE_REPORT_INVALID",
      "performance report is incomplete"
    )
  end

  def validate_benchmark_boundary(
    boundary,
    expected_name,
    unit,
    threshold_milli,
    expected_counts,
    expected_contract
  )
    exact_keys!(
      boundary,
      %w[
        boundary definition threads rust_adapter python_companion
        home_assistant_fixture fixture_label warmups measured complete strata
      ],
      "P15_PERFORMANCE_REPORT_INVALID",
      "#{expected_name} boundary"
    )
    unless boundary.fetch("boundary") == expected_name &&
           boundary.fetch("definition") == expected_contract.fetch("definition") &&
           boundary.fetch("threads") == expected_contract.fetch("threads") &&
           boundary.fetch("rust_adapter") ==
             expected_contract.fetch("rust_adapter") &&
           boundary.fetch("python_companion") ==
             expected_contract.fetch("python_companion") &&
           boundary.fetch("home_assistant_fixture") ==
             expected_contract.fetch("home_assistant_fixture") &&
           boundary.fetch("fixture_label") ==
             "FIXTURE_TECNICA_NON_RESIDENTIAL_HOME_ASSISTANT" &&
           boundary.fetch("warmups") == 3 &&
           boundary.fetch("measured") == 5
      fail!(
        "P15_PERFORMANCE_REPORT_INVALID",
        "#{expected_name} boundary contract differs"
      )
    end
    validate_benchmark_series(
      boundary.fetch("complete"),
      4_800,
      unit,
      threshold_milli,
      expected_name
    )
    strata = boundary.fetch("strata")
    unless strata.is_a?(Hash) && strata.keys == FROZEN_DIMENSIONS
      fail!(
        "P15_PERFORMANCE_REPORT_INVALID",
        "#{expected_name} stratum dimensions differ"
      )
    end
    FROZEN_DIMENSIONS.each do |dimension|
      rows = strata.fetch(dimension)
      expected = expected_counts.fetch(dimension)
      bounded_array!(
        rows,
        expected.length,
        expected.length,
        "P15_PERFORMANCE_REPORT_INVALID",
        "#{expected_name} stratum rows"
      )
      observed = rows.map do |row|
        exact_keys!(
          row,
          %w[value records series],
          "P15_PERFORMANCE_REPORT_INVALID",
          "#{expected_name} stratum"
        )
        value = row.fetch("value")
        unless expected[value] == row.fetch("records")
          fail!(
            "P15_PERFORMANCE_REPORT_INVALID",
            "#{expected_name} stratum identity differs"
          )
        end
        validate_benchmark_series(
          row.fetch("series"),
          row.fetch("records"),
          unit,
          threshold_milli,
          "#{expected_name} #{dimension}=#{value}"
        )
        value
      end
      unless observed == expected.keys.sort
        fail!(
          "P15_PERFORMANCE_REPORT_INVALID",
          "#{expected_name} stratum order differs"
        )
      end
    end
    true
  end

  def validate_benchmark_series(series, records, unit, threshold_milli, label)
    exact_keys!(
      series,
      %w[
        warmup_samples measured_samples p50_ns p95_ns p99_ns spread_ns
        median_throughput_milli semantic_exact
      ],
      "P15_PERFORMANCE_REPORT_INVALID",
      "#{label} benchmark series"
    )
    warmups = series.fetch("warmup_samples")
    measured = series.fetch("measured_samples")
    bounded_array!(
      warmups,
      3,
      3,
      "P15_PERFORMANCE_REPORT_INVALID",
      "#{label} warmups"
    )
    bounded_array!(
      measured,
      5,
      5,
      "P15_PERFORMANCE_REPORT_INVALID",
      "#{label} measured samples"
    )
    warmups.each_with_index do |sample, index|
      validate_benchmark_sample(sample, index + 1, records, unit, label)
    end
    measured.each_with_index do |sample, index|
      validate_benchmark_sample(sample, index + 1, records, unit, label)
    end
    durations = measured.map { |sample| sample.fetch("duration_ns") }.sort
    throughputs = measured.map do |sample|
      sample.fetch("throughput_per_second_milli")
    end.sort
    p50 = nearest_rank(durations, 50)
    p95 = nearest_rank(durations, 95)
    p99 = nearest_rank(durations, 99)
    median_throughput = nearest_rank(throughputs, 50)
    unless series.fetch("p50_ns") == p50 &&
           series.fetch("p95_ns") == p95 &&
           series.fetch("p99_ns") == p99 &&
           series.fetch("spread_ns") == durations.last - durations.first &&
           series.fetch("median_throughput_milli") == median_throughput &&
           series.fetch("semantic_exact") == true
      fail!(
        "P15_PERFORMANCE_REPORT_INVALID",
        "#{label} benchmark aggregate differs"
      )
    end
    if median_throughput < threshold_milli
      fail!(
        "P15_PERFORMANCE_GATE_FAILED",
        "#{label} throughput gate failed"
      )
    end
    true
  end

  def validate_benchmark_sample(sample, run, records, unit, label)
    exact_keys!(
      sample,
      %w[
        run duration_ns records counted_units unit
        throughput_per_second_milli semantic_exact
      ],
      "P15_PERFORMANCE_REPORT_INVALID",
      "#{label} benchmark sample"
    )
    duration = sample.fetch("duration_ns")
    counted = sample.fetch("counted_units")
    unless sample.fetch("run") == run &&
           positive_bounded_integer?(duration, (1 << 63)) &&
           sample.fetch("records") == records &&
           positive_bounded_integer?(counted, (1 << 63)) &&
           sample.fetch("unit") == unit &&
           sample.fetch("semantic_exact") == true
      fail!(
        "P15_PERFORMANCE_REPORT_INVALID",
        "#{label} benchmark sample differs"
      )
    end
    expected = ((counted * 1_000_000_000_000) + (duration / 2)) / duration
    unless sample.fetch("throughput_per_second_milli") == expected
      fail!(
        "P15_PERFORMANCE_REPORT_INVALID",
        "#{label} throughput recomputation differs"
      )
    end
    true
  end

  def nearest_rank(values, percentile)
    index = (((percentile * values.length) + 99) / 100) - 1
    values.fetch(index)
  end

  def validate_p14_debt(root, report)
    exact_keys!(
      report,
      %w[
        schema_version subject archive_sha256 exact_gate
        governance_mutation_suite reviews status
      ],
      "P15_P14_DEBT_INVALID",
      "P14 debt closure"
    )
    unless report.fetch("schema_version") == 1 &&
           report.fetch("subject") == P14_SUBJECT &&
           sha256?(report.fetch("archive_sha256")) &&
           report.fetch("status") == "PASS"
      fail!("P15_P14_DEBT_OPEN", "P14 debt closure status differs")
    end
    validate_transcript(
      root,
      report.fetch("exact_gate"),
      "tools/validate-p14 --expected-commit " \
        "#{P14_SUBJECT.fetch("commit")} --expected-tree " \
        "#{P14_SUBJECT.fetch("tree")}",
      "P14_GATE_PASS_WITH_ACCEPTED_TRANSFERS",
      "P15_P14_DEBT_INVALID",
      "P14 exact gate"
    )
    mutation = report.fetch("governance_mutation_suite")
    validate_transcript(
      root,
      mutation,
      "tools/test-validate-governance",
      /\Agovernance validator tests passed \([1-9][0-9]* cases\)\z/,
      "P15_P14_DEBT_INVALID",
      "P14 governance mutation suite"
    )
    reviews = report.fetch("reviews")
    bounded_array!(
      reviews,
      P14_REVIEW_ROLES.length,
      P14_REVIEW_ROLES.length,
      "P15_P14_DEBT_INVALID",
      "P14 debt reviews"
    )
    roles = []
    instances = []
    reviews.each do |entry|
      exact_keys!(
        entry,
        %w[role instance path bytes sha256 verdict],
        "P15_P14_DEBT_INVALID",
        "P14 debt review"
      )
      role = entry.fetch("role")
      unless P14_REVIEW_ROLES.include?(role) &&
             safe_instance?(entry.fetch("instance")) &&
             entry.fetch("verdict") == "PASS" &&
             positive_bounded_integer?(entry.fetch("bytes"), MAX_REVIEW_BYTES) &&
             sha256?(entry.fetch("sha256")) &&
             entry.fetch("path") ==
               "release/p15/evidence/p14/review-#{role}.md"
        fail!("P15_P14_DEBT_INVALID", "P14 debt review identity differs")
      end
      bytes = validate_file_identity(
        root,
        entry.fetch("path"),
        entry.fetch("bytes"),
        entry.fetch("sha256"),
        "P15_P14_DEBT_INVALID",
        "P14 debt review",
        return_bytes: true
      )
      validate_review_markdown(
        bytes,
        role,
        entry.fetch("instance"),
        P14_SUBJECT,
        nil,
        nil,
        "P15_P14_DEBT_INVALID",
        "P14"
      )
      roles << role
      instances << entry.fetch("instance")
    end
    unless roles == P14_REVIEW_ROLES.sort &&
           instances.uniq.length == instances.length
      fail!(
        "P15_P14_DEBT_INVALID",
        "P14 debt review role or instance set differs"
      )
    end
    true
  rescue KeyError, TypeError
    fail!("P15_P14_DEBT_INVALID", "P14 debt closure is incomplete")
  end

  def validate_transcript(
    root,
    evidence,
    expected_command,
    expected_marker,
    code,
    label
  )
    exact_keys!(
      evidence,
      %w[command status output_path output_bytes output_sha256],
      code,
      label
    )
    unless evidence.fetch("command") == expected_command &&
           evidence.fetch("status") == "PASS" &&
           evidence.fetch("output_path").match?(
             %r{\Arelease/p15/evidence/p14/[a-z0-9._-]+\.txt\z}
           ) &&
           positive_bounded_integer?(evidence.fetch("output_bytes"),
                                     MAX_JSON_BYTES) &&
           sha256?(evidence.fetch("output_sha256"))
      fail!(code, "#{label} identity differs")
    end
    bytes = validate_file_identity(
      root,
      evidence.fetch("output_path"),
      evidence.fetch("output_bytes"),
      evidence.fetch("output_sha256"),
      code,
      label,
      return_bytes: true
    )
    markers =
      if expected_marker.is_a?(Regexp)
        bytes.lines.map(&:strip).select { |line| line.match?(expected_marker) }
      else
        bytes.lines.map(&:strip).select { |line| line == expected_marker }
      end
    fail!(code, "#{label} PASS marker is not unique") unless markers.length == 1
    fail!(code, "#{label} contains a failure marker") if bytes.include?("FAIL")
    true
  end

  def validate_native_linux_proof(report, source, release)
    exact_keys!(
      report,
      %w[
        schema_version proof_kind source_subject release_set_sha256
        release_input_inventory_sha256 architectures
      ],
      "P15_NATIVE_LINUX_PROOF_INVALID",
      "native Linux proof"
    )
    unless report.fetch("schema_version") == 1 &&
           report.fetch("proof_kind") == "P15_NATIVE_LINUX_V1" &&
           report.fetch("source_subject") == source &&
           report.fetch("release_set_sha256") ==
             release.fetch(:release_set_sha256) &&
           report.fetch("release_input_inventory_sha256") ==
             release.fetch(:inventory_sha256)
      fail!(
        "P15_NATIVE_LINUX_PROOF_INVALID",
        "native Linux proof identity differs"
      )
    end
    rows = report.fetch("architectures")
    bounded_array!(
      rows,
      ARCHITECTURES.length,
      ARCHITECTURES.length,
      "P15_NATIVE_LINUX_PROOF_INVALID",
      "native architecture rows"
    )
    observed = {}
    rows.each do |row|
      exact_keys!(
        row,
        %w[
          home_assistant_arch oci_platform kernel build executable execution
          artifact
        ],
        "P15_NATIVE_LINUX_PROOF_INVALID",
        "native architecture row"
      )
      arch = row.fetch("home_assistant_arch")
      contract = ARCHITECTURES[arch]
      if !contract || observed.key?(arch) ||
         row.fetch("oci_platform") != contract.fetch("oci_platform")
        fail!(
          "P15_NATIVE_LINUX_PROOF_INVALID",
          "native architecture identity differs"
        )
      end
      kernel = row.fetch("kernel")
      unless kernel == {
        "sysname" => "Linux",
        "machine" => contract.fetch("kernel_machine"),
        "native_hardware" => true,
        "emulator" => false,
        "binfmt_misc" => false,
        "qemu" => false
      }
        fail!(
          "P15_NATIVE_SUBSTITUTION_REJECTED",
          "host-only, cross, emulated, or relabeled evidence is ineligible"
        )
      end
      build = row.fetch("build")
      exact_keys!(
        build,
        %w[
          mode host_machine target_triple compiler linker_sha256
          source_mount source_read_only network_allowed cross_compilation
          input_inventory_sha256 status
        ],
        "P15_NATIVE_LINUX_PROOF_INVALID",
        "native build proof"
      )
      unless build.fetch("mode") == "native_offline" &&
             build.fetch("host_machine") == contract.fetch("kernel_machine") &&
             build.fetch("target_triple") == contract.fetch("target_triple") &&
             build.fetch("compiler") == "rustc 1.98.0" &&
             sha256?(build.fetch("linker_sha256")) &&
             build.fetch("source_mount") == "kernel_enforced_read_only" &&
             build.fetch("source_read_only") == true &&
             build.fetch("network_allowed") == false &&
             build.fetch("cross_compilation") == false &&
             build.fetch("input_inventory_sha256") ==
               release.fetch(:inventory_sha256) &&
             build.fetch("status") == "PASS"
        fail!(
          "P15_NATIVE_SUBSTITUTION_REJECTED",
          "native build proof permits a substitution"
        )
      end
      executable = row.fetch("executable")
      unless executable == {
        "format" => "ELF",
        "machine" => contract.fetch("elf_machine"),
        "static_musl" => true
      }
        fail!(
          "P15_NATIVE_SUBSTITUTION_REJECTED",
          "ELF machine identity or static closure differs"
        )
      end
      execution = row.fetch("execution")
      unless execution == {
        "status" => "PASS",
        "matching_hardware" => true,
        "process_isolation" => "PASS",
        "read_only_source_enforced" => "PASS",
        "rejected_source_unreachable" => "PASS"
      }
        fail!(
          "P15_NATIVE_LINUX_PROOF_INVALID",
          "native execution controls did not pass"
        )
      end
      artifact = row.fetch("artifact")
      entry = release.fetch(:entries).fetch(contract.fetch("artifact_path"))
      unless artifact == {
        "path" => contract.fetch("artifact_path"),
        "bytes" => entry.fetch("bytes"),
        "sha256" => entry.fetch("sha256")
      }
        fail!(
          "P15_NATIVE_LINUX_PROOF_INVALID",
          "native artifact identity differs"
        )
      end
      observed[arch] = row
    end
    unless observed.keys == ARCHITECTURES.keys.sort
      fail!(
        "P15_NATIVE_LINUX_PROOF_INVALID",
        "native architecture order differs"
      )
    end
    observed
  rescue KeyError, TypeError
    fail!(
      "P15_NATIVE_LINUX_PROOF_INVALID",
      "native Linux proof is incomplete"
    )
  end

  def validate_home_assistant_lifecycle(
    report,
    source,
    release,
    native_state
  )
    exact_keys!(
      report,
      %w[
        schema_version proof_kind source_subject release_set_sha256
        runtime_closure_sha256 environments
      ],
      "P15_HOME_ASSISTANT_LIFECYCLE_PROOF_INVALID",
      "Home Assistant lifecycle proof"
    )
    unless report.fetch("schema_version") == 1 &&
           report.fetch("proof_kind") ==
             "P15_REAL_HOME_ASSISTANT_LIFECYCLE_V1" &&
           report.fetch("source_subject") == source &&
           report.fetch("release_set_sha256") ==
             release.fetch(:release_set_sha256) &&
           sha256?(report.fetch("runtime_closure_sha256"))
      fail!(
        "P15_HOME_ASSISTANT_LIFECYCLE_PROOF_INVALID",
        "Home Assistant lifecycle identity differs"
      )
    end
    rows = report.fetch("environments")
    expected_count = ARCHITECTURES.length * HOME_ASSISTANT_RELEASES.length
    bounded_array!(
      rows,
      expected_count,
      expected_count,
      "P15_HOME_ASSISTANT_LIFECYCLE_PROOF_INVALID",
      "Home Assistant lifecycle environments"
    )
    observed = []
    rows.each do |row|
      exact_keys!(
        row,
        %w[
          architecture oci_platform kernel_machine home_assistant
          substitution_guards actual_paths lifecycle installed_artifacts
        ],
        "P15_HOME_ASSISTANT_LIFECYCLE_PROOF_INVALID",
        "Home Assistant lifecycle environment"
      )
      arch = row.fetch("architecture")
      contract = ARCHITECTURES[arch]
      unless contract && native_state.key?(arch) &&
             row.fetch("oci_platform") == contract.fetch("oci_platform") &&
             row.fetch("kernel_machine") ==
               contract.fetch("kernel_machine")
        fail!(
          "P15_HOME_ASSISTANT_LIFECYCLE_PROOF_INVALID",
          "Home Assistant lifecycle architecture differs"
        )
      end
      ha = row.fetch("home_assistant")
      exact_keys!(
        ha,
        %w[
          version commit tree supported core_real supervisor_real
          python_version dependency_closure_sha256
        ],
        "P15_HOME_ASSISTANT_LIFECYCLE_PROOF_INVALID",
        "Home Assistant runtime identity"
      )
      version = ha.fetch("version")
      identity = HOME_ASSISTANT_RELEASES[version]
      unless identity &&
             ha.fetch("commit") == identity.fetch("commit") &&
             ha.fetch("tree") == identity.fetch("tree") &&
             ha.fetch("supported") == true &&
             ha.fetch("core_real") == true &&
             ha.fetch("supervisor_real") == true &&
             ha.fetch("python_version").match?(/\A3\.(?:13|14)\.[0-9]+\z/) &&
             sha256?(ha.fetch("dependency_closure_sha256"))
        fail!(
          "P15_HOME_ASSISTANT_LIFECYCLE_PROOF_INVALID",
          "Home Assistant supported runtime identity differs"
        )
      end
      guards = row.fetch("substitution_guards")
      unless guards == {
        "mock" => false,
        "patched_imports" => false,
        "fake_entry" => false,
        "fake_dispatch" => false,
        "source_identity_only" => false,
        "emulator" => false
      }
        fail!(
          "P15_FAKE_HOME_ASSISTANT_PROOF_REJECTED",
          "mock, patched, fake, source-only, or emulated runtime evidence is ineligible"
        )
      end
      paths = row.fetch("actual_paths")
      unless paths == {
        "loader" => true,
        "config_flow" => true,
        "authorization" => true,
        "service_dispatch" => true,
        "backup_restore" => true
      }
        fail!(
          "P15_FAKE_HOME_ASSISTANT_PROOF_REJECTED",
          "actual Home Assistant lifecycle paths were not traversed"
        )
      end
      lifecycle = row.fetch("lifecycle")
      exact_keys!(
        lifecycle,
        LIFECYCLE_GATES,
        "P15_HOME_ASSISTANT_LIFECYCLE_PROOF_INVALID",
        "lifecycle gates"
      )
      LIFECYCLE_GATES.each do |gate|
        expected =
          if gate.end_with?("_fails_closed")
            "FAIL_CLOSED"
          else
            "PASS"
          end
        unless lifecycle.fetch(gate) == expected
          fail!(
            "P15_HOME_ASSISTANT_LIFECYCLE_PROOF_INVALID",
            "lifecycle gate failed: #{gate}"
          )
        end
      end
      installed = row.fetch("installed_artifacts")
      companion = release.fetch(:entries).fetch(
        MANDATORY_RELEASE_PATHS.fetch("companion")
      )
      addon = release.fetch(:entries).fetch(contract.fetch("artifact_path"))
      unless installed == {
        "companion_sha256" => companion.fetch("sha256"),
        "addon_sha256" => addon.fetch("sha256")
      }
        fail!(
          "P15_HOME_ASSISTANT_LIFECYCLE_PROOF_INVALID",
          "installed artifact identity differs"
        )
      end
      observed << [arch, version]
    end
    expected = ARCHITECTURES.keys.sort.product(
      HOME_ASSISTANT_RELEASES.keys.sort
    )
    unless observed == expected
      fail!(
        "P15_HOME_ASSISTANT_LIFECYCLE_PROOF_INVALID",
        "Home Assistant lifecycle matrix differs"
      )
    end
    true
  rescue KeyError, TypeError
    fail!(
      "P15_HOME_ASSISTANT_LIFECYCLE_PROOF_INVALID",
      "Home Assistant lifecycle proof is incomplete"
    )
  end

  def validate_reproducibility(report, source, release, inventory_sha256)
    exact_keys!(
      report,
      %w[
        schema_version proof_kind source_subject source_date_epoch
        release_set_sha256 release_input_inventory_sha256 products
      ],
      "P15_REPRODUCIBILITY_PROOF_INVALID",
      "reproducibility proof"
    )
    unless report.fetch("schema_version") == 1 &&
           report.fetch("proof_kind") == "P15_REPRODUCIBILITY_V1" &&
           report.fetch("source_subject") == source &&
           report.fetch("source_date_epoch") ==
             release.fetch(:source_date_epoch) &&
           report.fetch("release_set_sha256") ==
             release.fetch(:release_set_sha256) &&
           report.fetch("release_input_inventory_sha256") ==
             inventory_sha256
      fail!(
        "P15_REPRODUCIBILITY_PROOF_INVALID",
        "reproducibility identity differs"
      )
    end
    expected_products = {
      "companion" => {
        "architecture" => "multi",
        "path" => MANDATORY_RELEASE_PATHS.fetch("companion")
      },
      "aarch64" => {
        "architecture" => "aarch64",
        "path" => MANDATORY_RELEASE_PATHS.fetch("aarch64")
      },
      "amd64" => {
        "architecture" => "amd64",
        "path" => MANDATORY_RELEASE_PATHS.fetch("amd64")
      }
    }
    products = report.fetch("products")
    bounded_array!(
      products,
      expected_products.length,
      expected_products.length,
      "P15_REPRODUCIBILITY_PROOF_INVALID",
      "reproducible products"
    )
    observed = []
    products.each do |product|
      exact_keys!(
        product,
        %w[
          product architecture artifact_path artifact_bytes artifact_sha256
          builds byte_identical
        ],
        "P15_REPRODUCIBILITY_PROOF_INVALID",
        "reproducible product"
      )
      name = product.fetch("product")
      expected = expected_products[name]
      entry = expected && release.fetch(:entries)[expected.fetch("path")]
      unless expected && entry &&
             product.fetch("architecture") ==
               expected.fetch("architecture") &&
             product.fetch("artifact_path") == expected.fetch("path") &&
             product.fetch("artifact_bytes") == entry.fetch("bytes") &&
             product.fetch("artifact_sha256") == entry.fetch("sha256") &&
             product.fetch("byte_identical") == true
        fail!(
          "P15_REPRODUCIBILITY_PROOF_INVALID",
          "reproducible product identity differs"
        )
      end
      builds = product.fetch("builds")
      bounded_array!(
        builds,
        2,
        2,
        "P15_REPRODUCIBILITY_PROOF_INVALID",
        "clean reproducibility builds"
      )
      roots = []
      builds.each_with_index do |build, index|
        exact_keys!(
          build,
          %w[
            ordinal root native_linux offline source_read_only network_allowed
            input_inventory_sha256 artifact_bytes artifact_sha256
          ],
          "P15_REPRODUCIBILITY_PROOF_INVALID",
          "reproducibility build"
        )
        root_path = build.fetch("root")
        unless build.fetch("ordinal") == index + 1 &&
               safe_absolute_linux_path?(root_path) &&
               build.fetch("native_linux") == true &&
               build.fetch("offline") == true &&
               build.fetch("source_read_only") == true &&
               build.fetch("network_allowed") == false &&
               build.fetch("input_inventory_sha256") ==
                 inventory_sha256 &&
               build.fetch("artifact_bytes") == entry.fetch("bytes") &&
               build.fetch("artifact_sha256") == entry.fetch("sha256")
          fail!(
            "P15_REPRODUCIBILITY_PROOF_INVALID",
            "reproducibility build differs"
          )
        end
        roots << root_path
      end
      unless roots.uniq.length == 2
        fail!(
          "P15_REPRODUCIBILITY_PROOF_INVALID",
          "reproducibility roots are not distinct"
        )
      end
      observed << name
    end
    unless observed == expected_products.keys.sort
      fail!(
        "P15_REPRODUCIBILITY_PROOF_INVALID",
        "reproducible product order differs"
      )
    end
    true
  rescue KeyError, TypeError
    fail!(
      "P15_REPRODUCIBILITY_PROOF_INVALID",
      "reproducibility proof is incomplete"
    )
  end

  def validate_validation_and_reviews(root, validation, subject, release)
    exact_keys!(
      validation,
      %w[
        schema_version phase subject release_manifest_sha256
        release_set_sha256 gates requirements residual_findings
        architecture_transition review_reports result
      ],
      "P15_VALIDATION_REPORT_INVALID",
      "P15 validation report"
    )
    expected_gates = {
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
    }
    unless validation.fetch("schema_version") == 1 &&
           validation.fetch("phase") == "P15" &&
           validation.fetch("subject") == subject &&
           validation.fetch("release_manifest_sha256") ==
             release.fetch(:manifest_sha256) &&
           validation.fetch("release_set_sha256") ==
             release.fetch(:release_set_sha256) &&
           validation.fetch("gates") == expected_gates &&
           validation.fetch("requirements") ==
             {
               "applicable" => 535,
               "mandatory_satisfied" => 535,
               "status" => "ALL_MANDATORY_SATISFIED"
             } &&
           validation.fetch("residual_findings") == [] &&
           validation.fetch("architecture_transition") ==
             "disabled_subject_to_enabled_evidence_checkpoint" &&
           validation.fetch("result") == "MINIMUM_ACCEPTABLE_PASS"
      fail!(
        "P15_VALIDATION_REPORT_INVALID",
        "P15 validation closeout differs"
      )
    end

    reports = validation.fetch("review_reports")
    bounded_array!(
      reports,
      REVIEW_FILES.length,
      REVIEW_FILES.length,
      "P15_MANDATORY_REVIEW_INVALID",
      "P15 review reports"
    )
    instances = []
    roles = []
    reports.each do |entry|
      exact_keys!(
        entry,
        %w[role instance path bytes sha256 verdict],
        "P15_MANDATORY_REVIEW_INVALID",
        "P15 review report identity"
      )
      role = entry.fetch("role")
      unless REVIEW_FILES[role] == entry.fetch("path") &&
             safe_instance?(entry.fetch("instance")) &&
             positive_bounded_integer?(entry.fetch("bytes"), MAX_REVIEW_BYTES) &&
             sha256?(entry.fetch("sha256")) &&
             entry.fetch("verdict") == "PASS"
        fail!(
          "P15_MANDATORY_REVIEW_INVALID",
          "P15 review report identity differs"
        )
      end
      bytes = validate_file_identity(
        root,
        entry.fetch("path"),
        entry.fetch("bytes"),
        entry.fetch("sha256"),
        "P15_MANDATORY_REVIEW_INVALID",
        "P15 review report",
        return_bytes: true
      )
      validate_review_markdown(
        bytes,
        role,
        entry.fetch("instance"),
        subject,
        release.fetch(:manifest_sha256),
        release.fetch(:release_set_sha256),
        "P15_MANDATORY_REVIEW_INVALID",
        "P15"
      )
      roles << role
      instances << entry.fetch("instance")
    end
    unless roles == REVIEW_FILES.keys.sort &&
           instances.uniq.length == instances.length
      fail!(
        "P15_MANDATORY_REVIEW_INVALID",
        "P15 review roles or instances differ"
      )
    end
    { instances: instances }
  rescue KeyError, TypeError
    fail!(
      "P15_VALIDATION_REPORT_INVALID",
      "P15 validation report is incomplete"
    )
  end

  def validate_review_markdown(
    bytes,
    role,
    instance,
    subject,
    manifest_sha256,
    release_set_sha256,
    code,
    phase
  )
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    fail!(code, "#{phase} review is not valid UTF-8") unless text.valid_encoding?
    required = [
      "- Role: `#{role}`",
      "- Review instance: `#{instance}`",
      "- Subject commit: `#{subject.fetch("commit")}`",
      "- Subject tree: `#{subject.fetch("tree")}`",
      "- Mode: independent read-only primary-evidence review",
      "- Verdict: `PASS`",
      "## Scope And Commands",
      "## Counterexample",
      "## Findings",
      "P0: none.",
      "P1: none.",
      "P2: none.",
      "P3: none."
    ]
    if manifest_sha256
      required << "- Release manifest SHA-256: `#{manifest_sha256}`"
      required << "- Release set SHA-256: `#{release_set_sha256}`"
    end
    unless required.all? { |value| text.include?(value) } &&
           text.rstrip.end_with?("`PASS`")
      fail!(code, "#{phase} review identity, findings, or verdict differs")
    end
    true
  end

  def validate_git_state(root, identities, bundle, runner)
    expected = {
      commit: identities.fetch(:expected_commit),
      tree: identities.fetch(:expected_tree)
    }
    subject = {
      commit: identities.fetch(:subject_commit),
      tree: identities.fetch(:subject_tree)
    }
    validate_worktree_identity(root, expected, runner)
    validate_commit_tree(root, subject, runner, "P15_SUBJECT_IDENTITY_INVALID")
    validate_commit_tree(
      root,
      {
        commit: bundle.fetch(:source).fetch("commit"),
        tree: bundle.fetch(:source).fetch("tree")
      },
      runner,
      "P15_RELEASE_SOURCE_IDENTITY_INVALID"
    )
    validate_commit_tree(
      root,
      {
        commit:
          bundle.fetch(:evaluation_access).fetch(
            "pre_implementation"
          ).fetch("commit"),
        tree:
          bundle.fetch(:evaluation_access).fetch(
            "pre_implementation"
          ).fetch("tree")
      },
      runner,
      "P15_EVAL_012_CHRONOLOGY_INVALID"
    )
    ensure_ancestor!(
      root,
      PRE_IMPLEMENTATION_SUBJECT.fetch("commit"),
      bundle.fetch(:source).fetch("commit"),
      runner,
      "P15_EVAL_012_CHRONOLOGY_INVALID"
    )
    validate_behavior_identity(
      root,
      PRE_IMPLEMENTATION_SUBJECT.fetch("commit"),
      bundle.fetch(:source).fetch("commit"),
      runner
    )
    ensure_ancestor!(
      root,
      bundle.fetch(:source).fetch("commit"),
      subject.fetch(:commit),
      runner,
      "P15_RELEASE_SOURCE_IDENTITY_INVALID"
    )
    ensure_ancestor!(
      root,
      subject.fetch(:commit),
      expected.fetch(:commit),
      runner,
      "P15_STALE_REVIEW_SUBJECT"
    )

    source_delta = git_changed_paths(
      root,
      bundle.fetch(:source).fetch("commit"),
      subject.fetch(:commit),
      runner
    )
    unless source_delta.all? do |path|
      SOURCE_TO_SUBJECT_PREFIXES.any? { |prefix| path.start_with?(prefix) }
    end
      fail!(
        "P15_RELEASE_SOURCE_IDENTITY_INVALID",
        "release subject changes more than generated release paths"
      )
    end

    evidence_delta = git_changed_paths(
      root,
      subject.fetch(:commit),
      expected.fetch(:commit),
      runner
    )
    validate_evidence_delta_paths(evidence_delta)

    subject_build_bytes = git_blob(
      root,
      subject.fetch(:commit),
      "addon/build-contract.json",
      runner
    )
    subject_build = parse_json(
      subject_build_bytes,
      "P15_SUBJECT_ARCHITECTURE_STATE_INVALID",
      "subject build contract"
    )
    unless subject_build == DISABLED_BUILD_CONTRACT
      fail!(
        "P15_SUBJECT_ARCHITECTURE_STATE_INVALID",
        "reviewed subject was not held in the exact disabled state"
      )
    end

    release_paths = bundle.fetch(:snapshot).keys.select do |path|
      path.start_with?("release/p15/")
    end
    release_paths.each do |path|
      subject_blob = git_blob_id(
        root,
        subject.fetch(:commit),
        path,
        runner
      )
      evidence_blob = git_blob_id(
        root,
        expected.fetch(:commit),
        path,
        runner
      )
      unless subject_blob == evidence_blob
        fail!(
          "P15_POST_REVIEW_ARTIFACT_MUTATION",
          "release evidence changed after review: #{path}"
        )
      end
    end

    archive = git_archive(
      root,
      P14_SUBJECT.fetch("commit"),
      runner
    )
    p14 = load_json_path(
      root,
      REPORT_PATHS.fetch("p14_debt").fetch("path"),
      "P15_P14_DEBT_INVALID",
      "P14 debt closure"
    )
    unless Digest::SHA256.hexdigest(archive) == p14.fetch("archive_sha256")
      fail!("P15_P14_DEBT_INVALID", "P14 subject archive digest differs")
    end
    { review_instances: bundle.fetch(:review_instances) }
  end

  def validate_worktree_identity(root, expected, runner)
    top = git_output(root, runner, "rev-parse", "--show-toplevel").strip
    unless File.realpath(top) == File.realpath(root)
      fail!(
        "P15_EVIDENCE_IDENTITY_INVALID",
        "validator root differs from Git worktree"
      )
    end
    inside = git_output(root, runner, "rev-parse", "--is-inside-work-tree").strip
    unless inside == "true"
      fail!("P15_EVIDENCE_IDENTITY_INVALID", "subject is not a Git worktree")
    end
    head = git_output(
      root,
      runner,
      "rev-parse",
      "--verify",
      "HEAD^{commit}"
    ).strip
    tree = git_output(
      root,
      runner,
      "rev-parse",
      "--verify",
      "HEAD^{tree}"
    ).strip
    unless head == expected.fetch(:commit)
      fail!(
        "P15_EVIDENCE_IDENTITY_INVALID",
        "evidence commit differs from expected commit"
      )
    end
    unless tree == expected.fetch(:tree)
      fail!(
        "P15_EVIDENCE_IDENTITY_INVALID",
        "evidence tree differs from expected tree"
      )
    end
    status = git_output(
      root,
      runner,
      "status",
      "--porcelain=v1",
      "-z",
      "--untracked-files=all",
      binary: true
    )
    unless status.empty?
      fail!(
        "P15_EVIDENCE_IDENTITY_INVALID",
        "evidence worktree has staged, unstaged, or untracked changes"
      )
    end
    flags = git_output(
      root,
      runner,
      "ls-files",
      "-v",
      "-z",
      binary: true
    ).split("\0").reject(&:empty?)
    unless flags.all? { |entry| entry.start_with?("H ") }
      fail!(
        "P15_EVIDENCE_IDENTITY_INVALID",
        "evidence worktree has concealed index flags"
      )
    end
    true
  rescue Errno::ENOENT, Errno::EACCES
    fail!("P15_EVIDENCE_IDENTITY_INVALID", "Git worktree cannot be read")
  end

  def validate_commit_tree(root, identity, runner, code)
    unless full_sha1?(identity.fetch(:commit)) &&
           full_sha1?(identity.fetch(:tree))
      fail!(code, "commit or tree identity is malformed")
    end
    tree = git_output(
      root,
      runner,
      "rev-parse",
      "--verify",
      "#{identity.fetch(:commit)}^{tree}"
    ).strip
    fail!(code, "commit identifies a different tree") unless
      tree == identity.fetch(:tree)
    true
  end

  def ensure_ancestor!(root, ancestor, descendant, runner, code)
    output, stderr, status = runner.call(
      ["/usr/bin/git", "merge-base", "--is-ancestor", ancestor, descendant],
      root,
      true,
      MAX_COMMAND_OUTPUT_BYTES
    )
    validate_git_stderr!(stderr)
    unless status.success? && output.empty?
      fail!(code, "required Git ancestry does not hold")
    end
    true
  end

  def git_changed_paths(root, from, to, runner)
    output = git_output(
      root,
      runner,
      "diff",
      "--name-only",
      "--no-renames",
      "#{from}..#{to}",
      binary: true
    )
    paths = output.lines.map(&:chomp)
    unless paths.length <= 10_000 &&
           paths.all? { |path| safe_repository_path?(path) } &&
           paths.uniq.length == paths.length
      fail!("P15_GIT_DELTA_INVALID", "Git delta path list is malformed")
    end
    paths
  end

  def validate_evidence_delta_paths(paths)
    paths.each do |path|
      next if EVIDENCE_DELTA_PATHS.include?(path)

      if path.start_with?("release/p15/")
        fail!(
          "P15_POST_REVIEW_ARTIFACT_MUTATION",
          "release artifact or evidence changed after review: #{path}"
        )
      end
      fail!(
        "P15_POST_REVIEW_SOURCE_MUTATION",
        "source changed after review: #{path}"
      )
    end
    true
  end

  def git_blob(root, commit, path, runner)
    validate_repository_path!(
      path,
      "P15_GIT_DELTA_INVALID",
      "Git blob path"
    )
    output = git_output(
      root,
      runner,
      "show",
      "#{commit}:#{path}",
      binary: true
    )
    if output.bytesize > MAX_JSON_BYTES
      fail!("P15_INPUT_LIMIT_EXCEEDED", "Git blob is too large")
    end
    output
  end

  def git_blob_id(root, commit, path, runner)
    validate_repository_path!(
      path,
      "P15_GIT_DELTA_INVALID",
      "Git blob path"
    )
    value = git_output(
      root,
      runner,
      "rev-parse",
      "--verify",
      "#{commit}:#{path}"
    ).strip
    unless full_sha1?(value)
      fail!("P15_GIT_DELTA_INVALID", "Git blob identity is malformed")
    end
    value
  end

  def git_archive(root, commit, runner)
    output = git_output(
      root,
      runner,
      "archive",
      "--format=tar",
      commit,
      binary: true,
      max_output: 512 * 1024 * 1024
    )
    fail!("P15_P14_DEBT_INVALID", "P14 archive is empty") if output.empty?
    output
  end

  def validate_behavior_identity(root, baseline_commit, candidate_commit, runner)
    baseline = git_tree_map(root, baseline_commit, runner)
    candidate = git_tree_map(root, candidate_commit, runner)
    validate_behavior_maps(baseline, candidate)
  end

  def validate_behavior_maps(baseline, candidate)
    baseline_frozen_paths = baseline.keys.select do |path|
      behavior_affecting_prefix?(path) ||
        path.start_with?("schemas/") ||
        path.start_with?("vendor/") ||
        path == "docs/adr/ADR-0005-quality-performance-contract.md"
    end
    candidate_frozen_paths = candidate.keys.select do |path|
      behavior_affecting_prefix?(path) ||
        baseline_frozen_paths.include?(path)
    end
    baseline_identity = baseline.select do |path, _identity|
      baseline_frozen_paths.include?(path)
    end
    candidate_identity = candidate.select do |path, _identity|
      candidate_frozen_paths.include?(path)
    end
    unless baseline_identity == candidate_identity
      changed = (
        baseline_identity.keys | candidate_identity.keys
      ).select do |path|
        baseline_identity[path] != candidate_identity[path]
      end.sort
      fail!(
        "P15_EVAL_012_BEHAVIOR_CHANGED",
        "behavior-affecting bytes changed after recorded access: " \
          "#{changed.first(8).join(",")}"
      )
    end
    true
  end

  def compare_behavior_maps_for_test(baseline, candidate)
    validate_behavior_maps(baseline, candidate)
  end

  def behavior_affecting_prefix?(path)
    return true if path.start_with?("data/")
    return true if path.start_with?("custom_components/local_nlu/")
    return true if %w[
      addon/config.yaml
      addon/runtime-contract.json
    ].include?(path)

    FROZEN_BEHAVIOR_CRATES.any? do |crate|
      path == "crates/#{crate}/Cargo.toml" ||
        path == "crates/#{crate}/build.rs" ||
        path.start_with?("crates/#{crate}/src/")
    end
  end

  def git_tree_map(root, commit, runner)
    output = git_output(
      root,
      runner,
      "ls-tree",
      "-r",
      "-z",
      "--full-tree",
      commit,
      binary: true,
      max_output: 256 * 1024 * 1024
    )
    entries = {}
    output.split("\0").reject(&:empty?).each do |entry|
      metadata, path = entry.split("\t", 2)
      mode, type, object = metadata.to_s.split(" ", 3)
      unless path && safe_repository_path?(path) &&
             type == "blob" &&
             %w[100644 100755].include?(mode) &&
             full_sha1?(object) &&
             !entries.key?(path)
        fail!(
          "P15_EVAL_012_CHRONOLOGY_INVALID",
          "behavior tree contains an unsupported entry"
        )
      end
      entries[path] = [mode, object]
    end
    entries
  end

  def git_output(
    root,
    runner,
    *arguments,
    binary: false,
    max_output: MAX_COMMAND_OUTPUT_BYTES
  )
    command = ["/usr/bin/git", *arguments]
    stdout, stderr, status = runner.call(command, root, binary, max_output)
    unless status.success?
      fail!(
        "P15_GIT_COMMAND_FAILED",
        "Git command failed without accepting its output"
      )
    end
    validate_git_stderr!(stderr)
    stdout
  end

  def validate_git_stderr!(stderr)
    lines = stderr.lines.map(&:strip).reject(&:empty?)
    unless lines.all? { |line| line == GIT_HOST_TEMP_WARNING }
      fail!(
        "P15_GIT_COMMAND_FAILED",
        "Git command emitted unexpected stderr"
      )
    end
    true
  end

  def run_command(command, root, binary = false, max_output = MAX_COMMAND_OUTPUT_BYTES)
    unless command.is_a?(Array) && command.first == "/usr/bin/git" &&
           command.all? { |part| part.is_a?(String) && part.bytesize <= 512 }
      fail!(
        "P15_UNTRUSTED_COMMAND_REJECTED",
        "validator command plan is not an allowlisted Git invocation"
      )
    end
    stdout, stderr, status = Open3.capture3(
      BASE_ENVIRONMENT,
      *command,
      unsetenv_others: true,
      chdir: root,
      binmode: binary
    )
    if stdout.bytesize + stderr.bytesize > max_output
      fail!("P15_INPUT_LIMIT_EXCEEDED", "command output exceeds its bound")
    end
    [stdout, stderr, status]
  rescue SystemCallError
    fail!("P15_GIT_COMMAND_FAILED", "allowlisted Git command could not execute")
  end

  def required_snapshot_paths(release, p14)
    paths = [
      "addon/build-contract.json",
      RELEASE_MANIFEST_PATH,
      RECONCILIATION_PATH,
      SBOM_PATH,
      NOTICES_PATH,
      CHECKSUMS_PATH,
      VALIDATION_REPORT_PATH,
      EVALUATION_ACCESS_PATH
    ]
    paths.concat(REPORT_PATHS.values.map { |entry| entry.fetch("path") })
    paths.concat(REVIEW_FILES.values)
    paths.concat(release.fetch(:entries).keys)
    paths << p14.fetch("exact_gate").fetch("output_path")
    paths << p14.fetch("governance_mutation_suite").fetch("output_path")
    p14.fetch("reviews").each { |entry| paths << entry.fetch("path") }
    paths.uniq.sort
  end

  def snapshot_files(root, paths)
    snapshot = {}
    paths.each do |path|
      validate_repository_path!(
        path,
        "P15_SNAPSHOT_INVALID",
        "snapshot path"
      )
      absolute = File.join(root, path)
      stat = File.lstat(absolute)
      unless stat.file? && !stat.symlink? && stat.nlink == 1
        fail!("P15_SNAPSHOT_INVALID", "snapshot file is unsafe: #{path}")
      end
      snapshot[path] = [stat.size, Digest::SHA256.file(absolute).hexdigest]
    end
    snapshot
  rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
    fail!("P15_SNAPSHOT_INVALID", "snapshot file cannot be read")
  end

  def verify_snapshot(root, snapshot)
    current = snapshot_files(root, snapshot.keys)
    unless current == snapshot
      fail!(
        "P15_VALIDATION_INPUT_MUTATED",
        "validated input changed while the gate was running"
      )
    end
    true
  end

  def load_json_path(root, relative, code, label, max_bytes: MAX_JSON_BYTES)
    bytes = read_relative(root, relative, max_bytes, code, label)
    parse_json(bytes, code, label)
  end

  def parse_json(bytes, code, label)
    value = JSON.parse(
      bytes,
      object_class: UniqueJsonObject,
      max_nesting: 64,
      allow_nan: false
    )
    validate_json_bounds!(value, code, label)
    value
  rescue JSON::ParserError, DuplicateJsonKey
    fail!(code, "#{label} is not strict unique-key JSON")
  end

  def validate_json_bounds!(value, code, label)
    nodes = 0
    walk = lambda do |current, depth|
      nodes += 1
      if nodes > MAX_JSON_NODES || depth > 64
        fail!("P15_INPUT_LIMIT_EXCEEDED", "#{label} exceeds JSON bounds")
      end
      case current
      when Hash
        if current.length > 2_048
          fail!("P15_INPUT_LIMIT_EXCEEDED", "#{label} object is too large")
        end
        current.each do |key, child|
          unless key.is_a?(String) && key.bytesize <= 256
            fail!("P15_INPUT_LIMIT_EXCEEDED", "#{label} key is too large")
          end
          walk.call(child, depth + 1)
        end
      when Array
        if current.length > 20_000
          fail!("P15_INPUT_LIMIT_EXCEEDED", "#{label} array is too large")
        end
        current.each { |child| walk.call(child, depth + 1) }
      when String
        if current.bytesize > MAX_JSON_STRING_BYTES || !current.valid_encoding?
          fail!("P15_INPUT_LIMIT_EXCEEDED", "#{label} string is too large")
        end
      when Integer, Float, TrueClass, FalseClass, NilClass
        nil
      else
        fail!(code, "#{label} contains an unsupported JSON value")
      end
    end
    walk.call(value, 0)
    true
  end

  def read_relative(root, relative, max_bytes, code, label)
    validate_repository_path!(relative, code, label)
    read_regular_file(
      File.join(root, relative),
      max_bytes: max_bytes,
      code: code,
      label: label
    )
  end

  def read_regular_file(path, max_bytes:, code:, label:)
    stat = File.lstat(path)
    unless stat.file? && !stat.symlink? && stat.nlink == 1
      fail!(code, "#{label} is not one regular non-hardlinked file")
    end
    if stat.size <= 0 || stat.size > max_bytes
      fail!("P15_INPUT_LIMIT_EXCEEDED", "#{label} size is outside its bound")
    end
    bytes = File.binread(path)
    unless bytes.bytesize == stat.size
      fail!(code, "#{label} changed while being read")
    end
    bytes
  rescue Errno::ENOENT
    fail!(code, "#{label} is missing")
  rescue Errno::EACCES, Errno::ELOOP
    fail!(code, "#{label} cannot be read safely")
  end

  def validate_file_identity(
    root,
    relative,
    expected_bytes,
    expected_sha256,
    code,
    label,
    return_bytes: false
  )
    validate_repository_path!(relative, code, label)
    absolute = File.join(root, relative)
    stat = File.lstat(absolute)
    unless stat.file? && !stat.symlink? && stat.nlink == 1
      fail!(code, "#{label} is not one regular non-hardlinked file")
    end
    if expected_bytes && stat.size != expected_bytes
      fail!(code, "#{label} byte count differs")
    end
    if stat.size <= 0 || stat.size > MAX_ARTIFACT_BYTES
      fail!("P15_INPUT_LIMIT_EXCEEDED", "#{label} size is outside its bound")
    end
    actual = Digest::SHA256.file(absolute).hexdigest
    fail!(code, "#{label} SHA-256 differs") unless actual == expected_sha256
    return File.binread(absolute) if return_bytes

    true
  rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
    fail!(code, "#{label} cannot be read safely")
  end

  def exact_keys!(object, keys, code, label)
    unless object.is_a?(Hash) && object.keys == keys
      fail!(code, "#{label} fields differ")
    end
    true
  end

  def bounded_array!(value, minimum, maximum, code, label)
    unless value.is_a?(Array) &&
           value.length >= minimum &&
           value.length <= maximum
      fail!(code, "#{label} count is outside its bound")
    end
    true
  end

  def validate_release_path!(
    path,
    code,
    allow_manifest: false,
    allow_license: false
  )
    validate_repository_path!(path, code, "release path")
    allowed = RELEASE_ENTRY_CONTRACT.key?(path)
    allowed ||= allow_manifest && path == RELEASE_MANIFEST_PATH
    allowed ||= allow_license &&
      path.match?(%r{\Arelease/p15/licenses/[a-z0-9][a-z0-9._+-]*\.txt\z})
    fail!(code, "release path is outside the exact topology") unless allowed
    true
  end

  def validate_repository_path!(path, code, label)
    unless safe_repository_path?(path)
      fail!(code, "#{label} is not a safe repository-relative path")
    end
    true
  end

  def safe_repository_path?(path)
    path.is_a?(String) &&
      path.bytesize.between?(1, 512) &&
      !path.start_with?("/") &&
      !path.include?("\0") &&
      !path.include?("\\") &&
      !path.split("/").any? { |part| part.empty? || part == "." || part == ".." } &&
      path.match?(/\A[a-zA-Z0-9._+\/-]+\z/)
  end

  def safe_release_evidence_path?(path)
    safe_repository_path?(path) &&
      path.match?(
        %r{\Arelease/p15/evidence/tools/[a-z0-9][a-z0-9._+-]*\z}
      )
  end

  def safe_absolute_linux_path?(path)
    path.is_a?(String) &&
      path.bytesize.between?(2, 512) &&
      path.start_with?("/") &&
      !path.include?("\0") &&
      !path.include?("\\") &&
      !path.split("/").any? { |part| part == "." || part == ".." } &&
      path.match?(%r{\A/[a-zA-Z0-9._+/-]+\z})
  end

  def safe_token?(value, maximum)
    value.is_a?(String) &&
      value.bytesize.between?(1, maximum) &&
      value.match?(/\A[a-zA-Z0-9][a-zA-Z0-9._+-]*\z/)
  end

  def safe_instance?(value)
    value.is_a?(String) &&
      value.bytesize.between?(8, 96) &&
      value.match?(/\A[a-zA-Z0-9][a-zA-Z0-9._:-]*\z/)
  end

  def safe_text?(value, maximum)
    value.is_a?(String) &&
      value.bytesize.between?(1, maximum) &&
      value.valid_encoding? &&
      !value.include?("\0") &&
      !value.match?(/[\r\n]/)
  end

  def safe_media_type?(value)
    safe_text?(value, 128) &&
      value.match?(/\A[a-z0-9.+-]+\/[a-zA-Z0-9.+-]+\z/)
  end

  def positive_bounded_integer?(value, maximum)
    value.is_a?(Integer) && value.positive? && value <= maximum
  end

  def full_sha1?(value)
    value.is_a?(String) && value.match?(/\A[0-9a-f]{40}\z/)
  end

  def sha256?(value)
    value.is_a?(String) && value.match?(/\A[0-9a-f]{64}\z/)
  end

  def eligible_license?(value)
    return false unless safe_text?(value, 256)

    prohibited = /\b(?:NC|ND|NONCOMMERCIAL|PROPRIETARY|RESEARCH|NOASSERTION|NONE)\b/i
    !value.match?(prohibited) && !value.include?("LicenseRef-")
  end

  def spdx_token(value)
    value.gsub(/[^A-Za-z0-9.-]/, "-")
  end

  def canonical_scalar(value)
    case value
    when String
      value
    when Integer
      value.to_s
    when true
      "true"
    when false
      "false"
    else
      fail!(
        "P15_RECONCILIATION_INVALID",
        "release input inventory scalar is unsupported"
      )
    end
  end

  def reject_prohibited_material!(value, code, label)
    serialized =
      value.is_a?(String) ? value : JSON.generate(value)
    if serialized.match?(/(?:amazon|aws)/i)
      fail!(code, "#{label} names prohibited Amazon-specific material")
    end
    true
  end

  def reject_case_level_fields!(value, code)
    forbidden = %w[
      case_id utterance generator_record_id canonical_semantic_id
      expected_value expected_plan per_case diagnostics
    ]
    walk = lambda do |current|
      case current
      when Hash
        current.each do |key, child|
          if forbidden.include?(key)
            fail!(code, "aggregate report contains case-level field #{key}")
          end
          walk.call(child)
        end
      when Array
        current.each { |child| walk.call(child) }
      end
    end
    walk.call(value)
    true
  end
end
