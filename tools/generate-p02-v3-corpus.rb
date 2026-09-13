# frozen_string_literal: true
# SPDX-License-Identifier: Apache-2.0

require "digest"
require "fileutils"
require "json"
require "optparse"
require "set"
require "tmpdir"

module P02V3Corpus
  RELEASE_LOADER_BOUNDARY = "P02V3_RELEASE_LOADER_BOUNDARY_V1"
  MUTABLE_SOURCE_BOUNDARY =
    "P02V3_FUTURE_MUTABLE_SOURCE_BOUNDARY_V1"

  class Failure < StandardError; end
  class DuplicateKeyError < StandardError; end

  class DuplicateRejectingHash < Hash
    def []=(key, value)
      raise DuplicateKeyError, key if key?(key)

      super
    end
  end

  ROOT = File.expand_path("..", __dir__)
  DATA_ROOT = File.join(ROOT, "data/project-authored/p02-v3")
  SPEC_PATH = File.join(DATA_ROOT, "specification.json")
  GENERATOR_PATH = File.expand_path(__FILE__)
  MANIFEST_PATH = "manifest.json"
  MAX_SPEC_BYTES = 2 * 1024 * 1024
  MAX_GENERATOR_BYTES = 2 * 1024 * 1024

  SPLITS = %w[train development heldout performance].freeze
  SUITE_IDS = %w[
    safety_sensitive
    contradiction
    ambiguity
    stale_state
    explicit_negative
  ].freeze
  PARTITIONS = (
    SPLITS + SUITE_IDS.map { |suite_id| "suite:#{suite_id}" }
  ).freeze
  SUITE_PATHS = SUITE_IDS.each_with_object({}) do |suite_id, result|
    result[suite_id] = "suites/#{suite_id.tr('_', '-')}.jsonl"
  end.freeze
  ARTIFACT_PARTITIONS = begin
    values = SPLITS.each_with_object({}) do |split, result|
      result["#{split}.jsonl"] = split
    end
    SUITE_PATHS.each do |suite_id, path|
      values[path] = "suite:#{suite_id}"
    end
    values.freeze
  end
  ARTIFACT_PATHS = ARTIFACT_PARTITIONS.keys.sort.freeze

  OFFICIAL_INTENTS = %w[
    HassTurnOff
    HassTurnOn
    HassToggle
    HassGetState
    HassNevermind
    HassSetPosition
    HassStopMoving
    HassStartTimer
    HassCancelTimer
    HassCancelAllTimers
    HassIncreaseTimer
    HassDecreaseTimer
    HassPauseTimer
    HassUnpauseTimer
    HassTimerStatus
    HassGetCurrentDate
    HassGetCurrentTime
    HassRespond
    HassBroadcast
    HassClimateGetTemperature
  ].freeze

  EXPECTED_CORPUS = {
    "id" => "project-authored-synthetic-ptbr-p15-v3-qf",
    "version" => "3.0.0",
    "status" => "PROJECT_AUTHORED_SYNTHETIC",
    "authorization" => "ADR-0048_USER_AUTHORIZED",
    "authorization_parent_commit" =>
      "d2c34476f660f6bcaf0f193fca67d084b4b4a0b2",
    "locale" => "pt-BR",
    "license" => "Apache-2.0",
    "claim_scope" => "internal_conformance_only",
    "generator_id" => "p02-qualification-generator-v3-qf",
    "generator_version" => "3.0.0",
    "oracle_origin" => "pre_engine_deterministic_generator_specification",
    "self_oracle_allowed" => false
  }.freeze

  EXPECTED_FREEZE = {
    "state" => "FROZEN_PRE_REMEDIATION",
    "sequence" => "P15_P02_V3_PRE_REMEDIATION_FREEZE",
    "checkpoint" => "SELF_AT_P15_PRE_IMPLEMENTATION_COMMIT",
    "authorization_parent_commit" =>
      "d2c34476f660f6bcaf0f193fca67d084b4b4a0b2",
    "authorization_parent_tree" =>
      "d16c656666e4d46d653479e86e16e8a94079f2cf",
    "chronology" =>
      "AFTER_ADR_0048_AUTHORIZATION_BEFORE_REMEDIATION_IMPLEMENTATION",
    "behavior_change_boundary" => "BEFORE_REMEDIATION_IMPLEMENTATION",
    "heldout_access_after_freeze" => "SEALED_AGGREGATE_RUNNER_ONLY",
    "performance_access_after_freeze" => "SEALED_AGGREGATE_RUNNER_ONLY",
    "suite_access_after_freeze" => "SEALED_AGGREGATE_RUNNER_ONLY",
    "executor_release_record_access" => "PROHIBITED",
    "remediation_agent_release_record_access" => "PROHIBITED",
    "follow_up_governance_binding" =>
      "EXECUTOR_RECORDS_RESULTING_EXACT_COMMIT_AND_TREE_WITHOUT_SUBJECT_CHANGE",
    "prior_release_record_access" => "PROHIBITED_AGGREGATES_ONLY",
    "self_oracle_allowed" => false
  }.freeze

  EXPECTED_ACCESS_POLICY = {
    "inspectable_partitions" => %w[train development],
    "aggregate_only_partitions" => [
      "heldout",
      "performance",
      "suite:safety_sensitive",
      "suite:contradiction",
      "suite:ambiguity",
      "suite:stale_state",
      "suite:explicit_negative"
    ],
    "writer_release_access" =>
      "GENERATOR_AND_AGGREGATE_VALIDATOR_BOUNDARY_ONLY",
    "executor_release_record_access" => "PROHIBITED",
    "remediation_agent_release_record_access" => "PROHIBITED",
    "release_record_reporting" =>
      "COUNTS_BYTES_SHA256_AND_WHOLE_ARTIFACT_IDENTITIES_ONLY",
    "self_test_data" => "FIXTURE_TECNICA_ONLY"
  }.freeze

  EXPECTED_LOADER_CONFINEMENT = {
    "current_allowed_source_paths" => [
      "tools/generate-p02-v3-corpus.rb",
      "tools/validate-governance.rb",
      "tools/validate-p02-v3.rb"
    ],
    "future_allowed_source_paths" => [
      "crates/release-eval/src/frozen.rs"
    ],
    "future_mutable_source_paths" => [
      "crates/intent-engine/src/engine.rs",
      "crates/intent-engine/src/generic.rs",
      "crates/intent-engine/src/lib.rs",
      "crates/intent-eval/src/evaluator.rs",
      "crates/plan-engine/src/internal_contract_tests.rs",
      "crates/plan-engine/src/lib.rs",
      "crates/plan-engine/src/pattern.rs",
      "crates/plan-engine/src/table.rs",
      "crates/plan-engine/tests/contract.rs",
      "crates/plan-engine/tests/resumable.rs",
      "crates/plan-eval/src/catalog.rs",
      "crates/plan-eval/src/evaluator.rs",
      "crates/plan-eval/src/oracle/frozen.rs",
      "crates/plan-eval/src/oracle/gold.rs",
      "crates/plan-eval/src/oracle/templates.rs",
      "crates/release-eval/src/lib.rs",
      "crates/release-eval/src/oracle.rs",
      "crates/release-eval/src/runtime.rs",
      "crates/release-eval/src/schema.rs",
      "custom_components/local_nlu/__init__.py",
      "custom_components/local_nlu/config_flow.py",
      "custom_components/local_nlu/executor.py",
      "custom_components/local_nlu/helper_process.py",
      "custom_components/local_nlu/ledger.py",
      "custom_components/local_nlu/restart_journal.py",
      "tests/p14_companion/test_execution.py",
      "tests/p14_companion/test_helper_process.py",
      "tests/p14_companion/test_integration_contract.py",
      "tests/p14_companion/test_ledger.py",
      "tests/p14_companion/test_setup_lifecycle.py",
      "tests/p16_companion/test_red_team.py",
      "tests/p16_release/test_red_team.py",
      "tools/test-generate-p02-v3-corpus.rb",
      "tools/test-validate-p02-v3.rb",
      "tools/test-validate-p14.rb",
      "tools/test-validate-p15.rb",
      "tools/test-validate-p16.rb",
      "tools/validate-p14.rb",
      "tools/validate-p15.rb",
      "tools/validate-p16.rb"
    ],
    "source_io_baseline_commit" =>
      "d2c34476f660f6bcaf0f193fca67d084b4b4a0b2",
    "release_artifact_paths" => [
      "data/project-authored/p02-v3/heldout.jsonl",
      "data/project-authored/p02-v3/performance.jsonl",
      "data/project-authored/p02-v3/suites/ambiguity.jsonl",
      "data/project-authored/p02-v3/suites/contradiction.jsonl",
      "data/project-authored/p02-v3/suites/explicit-negative.jsonl",
      "data/project-authored/p02-v3/suites/safety-sensitive.jsonl",
      "data/project-authored/p02-v3/suites/stale-state.jsonl"
    ],
    "source_inventory_executable" => "/usr/bin/git",
    "source_inventory_environment" => {
      "GIT_CONFIG_GLOBAL" => "/dev/null",
      "GIT_CONFIG_NOSYSTEM" => "1",
      "GIT_CONFIG_SYSTEM" => "/dev/null",
      "GIT_NO_REPLACE_OBJECTS" => "1",
      "GIT_OPTIONAL_LOCKS" => "0",
      "GIT_TERMINAL_PROMPT" => "0",
      "LANG" => "C",
      "LC_ALL" => "C",
      "PATH" => "/usr/bin:/bin",
      "TMPDIR" => "/tmp",
      "TZ" => "UTC"
    },
    "source_inventory_maximum_bytes" => 4 * 1024 * 1024,
    "source_inventory_maximum_paths" => 50_000,
    "source_inventory_maximum_stderr_bytes" => 64 * 1024,
    "source_inventory_excluded_pathspecs" => [
      ".DS_Store",
      ".cargo-home/**",
      ".mypy_cache/**",
      ".pytest_cache/**",
      ".tools/**",
      "**/.DS_Store",
      "**/__pycache__/**",
      "**/*.pyc",
      "STEERING-NLU-PTBR-SOL-MAX.md",
      "data/**",
      "docs/**",
      "release/**",
      "target/**"
    ],
    "source_inventory_capture" =>
      "STREAMING_DUAL_PIPE_LIMIT_PLUS_ONE_TERMINATE_AND_REAP",
    "source_inventory_repository_binding" =>
      "EXPLICIT_DOT_GIT_DIRECTORY_AND_ROOT_WORK_TREE",
    "source_change_policy" =>
      "EVERY_INVENTORIED_PROJECT_PATH_BLOB_BOUND_AND_EVERY_CHANGE_PREDECLARED",
    "mutable_source_capability_policy" =>
      "ALL_MUTABLE_PATHS_TREATED_AS_IO_CAPABLE_WITHOUT_SYNTAX_CLASSIFICATION",
    "recognized_project_read_abstractions" => %w[
      read_bounded_root_file
      read_verified
    ],
    "path_containment" =>
      "REJECT_SYMLINK_COMPONENTS_AND_REQUIRE_RESOLVED_ROOT_CONTAINMENT",
    "source_scan_scope" =>
      "ALL_TRACKED_AND_UNTRACKED_PROJECT_PATHS_OUTSIDE_EXACT_NON_SOURCE_ROOTS",
    "unauthorized_loader_policy" => "FAIL_CLOSED",
    "boundary_marker" => RELEASE_LOADER_BOUNDARY,
    "mutable_source_boundary_marker" => MUTABLE_SOURCE_BOUNDARY
  }.freeze

  EXPECTED_HOME_ASSISTANT_CONTRACT = {
    "source_id" => "home-assistant-core-2026.8.3",
    "commit" => "759e4658f40b3ccb671d418b8a0ed95224bf4561",
    "path" => "homeassistant/helpers/intent.py",
    "sha256" =>
      "8a62d1ab08d66a60a6c397bbb4d0b0ef12770c924ef8fd4ecffd690143703f9f",
    "allowed_use" => "public_intent_contract_only"
  }.freeze

  EXPECTED_SEMANTIC_CONTRACT = {
    "catalog_generation" => 37,
    "node_namespace" => "p02v3qf",
    "identifier_namespace" => "p02v3qf",
    "expected_plan_outcome" => "plan",
    "semantic_payload_identity" => "SHA256_CANONICAL_JSON_V1"
  }.freeze

  EXPECTED_QUOTAS = {
    "minimum_scored_cases" => 3715,
    "minimum_per_supported_stratum" => 237,
    "train_per_intent" => 48,
    "development_per_intent" => 48,
    "heldout_per_intent" => 240,
    "performance_per_intent" => 240,
    "weighting" => "unweighted",
    "suite_counts" => {
      "safety_sensitive" => 5,
      "contradiction" => 5,
      "ambiguity" => 5,
      "stale_state" => 5,
      "explicit_negative" => 7
    }
  }.freeze

  DIMENSIONS = %w[
    source
    family
    intent
    domain
    slot_kind
    graph_shape
    outcome
    ambiguity
    noise
    target_cardinality
  ].freeze

  TEMPLATE_COUNTS = {
    "train" => 4,
    "development" => 2,
    "heldout" => 1,
    "performance" => 1
  }.freeze

  PLACEHOLDERS = {
    "entity" => %w[lineage target],
    "entity_pair" => %w[lineage target target2],
    "display" => %w[lineage target],
    "timer" => %w[lineage target],
    "pending_action" => %w[lineage pending],
    "position" => %w[lineage position target],
    "timer_duration_ordered" => %w[lineage seconds target],
    "timer_area" => %w[lineage scope],
    "timer_delta" => %w[lineage seconds target],
    "response" => %w[lineage message],
    "broadcast" => %w[lineage message target]
  }.freeze

  PARTITION_CODES = {
    "train" => "trn",
    "development" => "dev",
    "heldout" => "hld",
    "performance" => "prf",
    "suite:safety_sensitive" => "ssf",
    "suite:contradiction" => "ctr",
    "suite:ambiguity" => "amb",
    "suite:stale_state" => "stl",
    "suite:explicit_negative" => "neg"
  }.freeze

  AREAS = [
    "átrio",
    "mezanino",
    "sala de leitura",
    "sala de música",
    "cozinha auxiliar",
    "quarto leste",
    "quarto oeste",
    "galeria",
    "terraço coberto",
    "pátio interno",
    "depósito",
    "vestíbulo",
    "sala de jogos",
    "sala de costura",
    "sala de estudos",
    "jardim de inverno",
    "varanda norte",
    "varanda sul",
    "garagem lateral",
    "garagem dos fundos",
    "lavabo",
    "banheiro social",
    "banheiro de apoio",
    "copa térrea",
    "copa superior",
    "oficina de reparos",
    "estúdio acústico",
    "academia interna",
    "corredor leste",
    "corredor oeste",
    "escadaria central"
  ].freeze

  PRIOR_V2_ARTIFACT_HASHES = {
    "development.jsonl" =>
      "08d8b1d33bf551337a90bde94727964fbf8f7de54de32e646d1758ce58ab89f1",
    "heldout.jsonl" =>
      "9767b413bf1eff0e2e1ec97f94c39f9d89c8e65743d2f53d502c56dd60f9276d",
    "performance.jsonl" =>
      "2baef9e3a906848c32ae5a0586d7c09c62d5380b891972edb46797cd054e269f",
    "suites/ambiguity.jsonl" =>
      "4ac86651828f2a6b065eb6b65295031544b3da83a21abaa11a94142cbf9df13f",
    "suites/contradiction.jsonl" =>
      "bd2e8b0d3a0bb924fa8f862284131237e5b5848e171817d4681a8f28752ff645",
    "suites/explicit-negative.jsonl" =>
      "ed0b7ce78961ee34a6b9fe2597fcdd8e58e3a0638ce2ef5e25c0311779875ab8",
    "suites/safety-sensitive.jsonl" =>
      "5685f966384fd46451a2463e985f266d7abcf5b06a5608cbd7dc85f1a3340d28",
    "suites/stale-state.jsonl" =>
      "c93a360293907f96fb1e4522a7d558ea2cb5ca59abee7c8b989131550e179bbe",
    "train.jsonl" =>
      "f15226a107c7bedb27b28e5880b65f24fb832a4b3d62ba67c6569a99b2aad183"
  }.freeze

  PRIOR_LINEAGE_FORBIDDEN_RECORD_STRINGS = [
    "p02v2",
    "project-authored-synthetic-ptbr-p15-v2",
    "p02-qualification-generator-v2",
    "na morada Aurora Violeta"
  ].freeze

  module_function

  def path_beneath?(candidate, root)
    candidate == root ||
      candidate.start_with?("#{root}#{File::SEPARATOR}")
  end

  def validate_relative_path!(relative, context)
    raise Failure, "#{context} path must be a string" unless
      relative.is_a?(String)
    raise Failure, "#{context} path is not valid UTF-8" unless
      relative.valid_encoding?
    raise Failure, "#{context} path contains NUL" if relative.include?("\0")
    raise Failure, "#{context} path must be relative" if
      relative.empty? || relative.start_with?("/")
    components = relative.split("/", -1)
    raise Failure, "#{context} path traversal is prohibited" if
      components.any? do |component|
        component.empty? || component == "." || component == ".."
      end

    relative
  end

  def resolved_root(root, context)
    expanded = File.expand_path(root)
    raise Failure, "#{context} root is missing" unless File.directory?(expanded)
    raise Failure, "#{context} root must not be a symlink" if
      File.symlink?(expanded)

    [expanded, File.realpath(expanded)]
  rescue SystemCallError => error
    raise Failure, "#{context} root cannot be resolved: #{error.class}"
  end

  def assert_contained_regular_file!(root, path, context)
    root_expanded, root_resolved = resolved_root(root, context)
    expanded = File.expand_path(path)
    raise Failure, "#{context} escapes the selected root" unless
      expanded != root_expanded && path_beneath?(expanded, root_expanded)

    relative = expanded.delete_prefix("#{root_expanded}#{File::SEPARATOR}")
    validate_relative_path!(relative, context)
    components = relative.split("/")
    current = root_expanded
    components.each_with_index do |component, index|
      current = File.join(current, component)
      stat = File.lstat(current)
      raise Failure, "#{context} contains a symlink component" if
        stat.symlink?
      if index == components.length - 1
        raise Failure, "#{context} is not a regular file" unless stat.file?
      else
        raise Failure, "#{context} ancestor is not a directory" unless
          stat.directory?
      end
    end

    resolved = File.realpath(expanded)
    raise Failure, "#{context} resolves outside the selected root" unless
      path_beneath?(resolved, root_resolved)

    expanded
  rescue Errno::ENOENT
    raise Failure, "#{context} is missing"
  rescue SystemCallError => error
    raise Failure, "#{context} cannot be resolved: #{error.class}"
  end

  def read_regular(path, maximum, context, root: nil)
    raise Failure, "#{context} byte limit is invalid" unless
      maximum.is_a?(Integer) && maximum >= 0
    selected_root = root || File.dirname(File.expand_path(path))
    checked = assert_contained_regular_file!(
      selected_root,
      path,
      context
    )
    bytes = File.open(checked, "rb") do |file|
      raise Failure, "#{context} is not a regular file" unless
        file.stat.file?
      file.read(maximum + 1) || "".b
    end
    raise Failure, "#{context} exceeds the byte limit" if
      bytes.bytesize > maximum

    bytes
  rescue SystemCallError => error
    raise Failure, "#{context} cannot be read: #{error.class}"
  end

  def prepare_output_root!(root)
    expanded = File.expand_path(root)
    if File.exist?(expanded) || File.symlink?(expanded)
      raise Failure, "output root must not be a symlink" if
        File.symlink?(expanded)
      raise Failure, "output root is not a directory" unless
        File.directory?(expanded)
    else
      FileUtils.mkdir_p(expanded)
    end
    resolved_root(expanded, "output")
    expanded
  rescue SystemCallError => error
    raise Failure, "output root cannot be prepared: #{error.class}"
  end

  def prepare_contained_output_path!(root, relative)
    validate_relative_path!(relative, "output")
    root_expanded, root_resolved = resolved_root(root, "output")
    components = relative.split("/")
    current = root_expanded
    components[0...-1].each do |component|
      current = File.join(current, component)
      if File.exist?(current) || File.symlink?(current)
        stat = File.lstat(current)
        raise Failure, "output contains a symlink component" if stat.symlink?
        raise Failure, "output ancestor is not a directory" unless
          stat.directory?
      else
        Dir.mkdir(current)
      end
    end

    path = File.join(root_expanded, relative)
    if File.exist?(path) || File.symlink?(path)
      stat = File.lstat(path)
      raise Failure, "output file must not be a symlink" if stat.symlink?
      raise Failure, "output path is not a regular file" unless stat.file?
    end
    parent_resolved = File.realpath(File.dirname(path))
    raise Failure, "output resolves outside the selected root" unless
      path_beneath?(parent_resolved, root_resolved)

    path
  rescue SystemCallError => error
    raise Failure, "output path cannot be prepared: #{error.class}"
  end

  def parse_json(bytes, context)
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    raise Failure, "#{context} is not valid UTF-8" unless text.valid_encoding?

    JSON.parse(
      text,
      object_class: DuplicateRejectingHash,
      array_class: Array,
      create_additions: false,
      max_nesting: 64
    )
  rescue JSON::ParserError, DuplicateKeyError => error
    raise Failure, "invalid #{context}: #{error.class}"
  end

  def load_spec(path = SPEC_PATH, root: nil)
    selected_root = root ||
      (File.expand_path(path) == SPEC_PATH ? DATA_ROOT : File.dirname(path))
    value = parse_json(
      read_regular(
        path,
        MAX_SPEC_BYTES,
        "specification",
        root: selected_root
      ),
      "specification JSON"
    )
    raise Failure, "specification root must be a mapping" unless value.is_a?(Hash)

    value
  end

  def exact_keys!(mapping, keys, context)
    raise Failure, "#{context} must be a mapping" unless mapping.is_a?(Hash)
    return if mapping.keys.sort == keys.sort

    raise Failure, "#{context} fields differ"
  end

  def sha256(bytes)
    Digest::SHA256.hexdigest(bytes)
  end

  def canonicalize(value)
    case value
    when Hash
      value.keys.sort.each_with_object({}) do |key, result|
        result[key] = canonicalize(value.fetch(key))
      end
    when Array
      value.map { |item| canonicalize(item) }
    else
      value
    end
  end

  def canonical_json(value)
    JSON.generate(canonicalize(value))
  end

  def canonical_sha(value)
    sha256(canonical_json(value))
  end

  def slug(value)
    value
      .gsub(/([a-z0-9])([A-Z])/, '\1_\2')
      .downcase
      .gsub(/[^a-z0-9]+/, "_")
      .gsub(/\A_+|_+\z/, "")
  end

  def partition_code(partition)
    PARTITION_CODES.fetch(partition)
  end

  def case_count(spec, split)
    spec.fetch("quotas").fetch("#{split}_per_intent")
  end

  def template_placeholders(template)
    template.scan(/%\{([a-z][a-z0-9_]*)\}/).flatten.sort
  end

  def static_tokens(template)
    template
      .gsub(/%\{[a-z][a-z0-9_]*\}/, " ")
      .downcase
      .scan(/\p{L}+/u)
      .uniq
      .sort
  end

  def valid_seed?(value)
    value.is_a?(String) && value.match?(/\A[0-9a-f]{16}\z/)
  end

  def counter_u64(seed, *parts)
    raise Failure, "deterministic seed is invalid" unless valid_seed?(seed)

    material = ([seed] + parts.map(&:to_s)).join("\0").encode(Encoding::UTF_8)
    Digest::SHA256.hexdigest(material)[0, 16].to_i(16)
  end

  def permutation_ordinal(seed, label, ordinal, modulus = 997)
    raise Failure, "ordinal is out of range" unless
      ordinal.is_a?(Integer) && ordinal.positive? && ordinal <= modulus

    multiplier = 1 + (counter_u64(seed, label, "multiplier") % (modulus - 1))
    offset = counter_u64(seed, label, "offset") % modulus
    (((ordinal - 1) * multiplier + offset) % modulus) + 1
  end

  def deterministic_parameters(spec, partition, intent_ordinal, intent, ordinal)
    deterministic = spec.fetch("deterministic_generation")
    seed = deterministic.fetch("partition_seeds").fetch(partition)
    global_seed = deterministic.fetch("global_seed")
    templates = intent.fetch("templates").fetch(partition)
    template_ordinal =
      (counter_u64(
        seed,
        global_seed,
        intent.fetch("intent"),
        ordinal,
        "template"
      ) %
       templates.length) + 1
    target_ordinal = permutation_ordinal(
      seed,
      "#{global_seed}:#{intent.fetch('intent')}:primary",
      ordinal
    )
    secondary_target_ordinal = ((target_ordinal - 1 + 499) % 997) + 1
    {
      "algorithm" =>
        spec.fetch("deterministic_generation").fetch("algorithm"),
      "partition_seed" => seed,
      "intent_ordinal" => intent_ordinal,
      "record_ordinal" => ordinal,
      "template_ordinal" => template_ordinal,
      "target_ordinal" => target_ordinal,
      "secondary_target_ordinal" => secondary_target_ordinal
    }
  end

  def suite_deterministic_parameters(spec, suite_id, suite_ordinal, ordinal)
    partition = "suite:#{suite_id}"
    deterministic = spec.fetch("deterministic_generation")
    seed = deterministic.fetch("partition_seeds").fetch(partition)
    global_seed = deterministic.fetch("global_seed")
    {
      "algorithm" =>
        deterministic.fetch("algorithm"),
      "partition_seed" => seed,
      "suite_ordinal" => suite_ordinal,
      "record_ordinal" => ordinal,
      "definition_selector" =>
        counter_u64(seed, global_seed, suite_id, ordinal, "definition")
    }
  end

  def forbidden_language?(spec, value)
    markers = spec.fetch("language_contract").fetch("forbidden_record_markers")
    markers.any? { |marker| value.downcase.include?(marker.downcase) }
  end

  def each_string(value, &block)
    case value
    when Hash
      value.each_value { |item| each_string(item, &block) }
    when Array
      value.each { |item| each_string(item, &block) }
    when String
      yield value
    end
  end

  def validate_generalization!(spec, intent)
    templates = intent.fetch("templates")
    contract = spec.fetch("generalization_contract")
    observed = templates.fetch("train").flat_map do |template|
      static_tokens(template)
    end
    observed.concat(
      contract.fetch("generic_ptbr_function_words").flat_map do |word|
        static_tokens(word)
      end
    )
    observed.uniq!

    hidden = templates.fetch("heldout") + templates.fetch("performance")
    unseen = hidden.flat_map { |template| static_tokens(template) }.uniq -
      observed
    raise Failure, "hidden template has undeclared static vocabulary" unless
      unseen.empty?

    inspectable =
      templates.fetch("train") + templates.fetch("development")
    raise Failure, "hidden template duplicates an inspectable template" unless
      (hidden & inspectable).empty?
    raise Failure, "intent templates are not unique" unless
      templates.values.flatten.uniq.length == templates.values.flatten.length
  end

  def validate_specification!(spec)
    exact_keys!(
      spec,
      %w[
        schema_version
        corpus
        freeze
        access_policy
        loader_confinement
        home_assistant_contract
        semantic_contract
        quotas
        dimensions
        split_policy
        deterministic_generation
        language_contract
        generalization_contract
        intents
        fail_closed_suites
        prior_lineage_aggregate_exclusions
      ],
      "specification"
    )
    raise Failure, "unsupported specification version" unless
      spec.fetch("schema_version") == 3
    raise Failure, "corpus contract differs" unless
      spec.fetch("corpus") == EXPECTED_CORPUS
    raise Failure, "freeze contract differs" unless
      spec.fetch("freeze") == EXPECTED_FREEZE
    raise Failure, "access policy differs" unless
      spec.fetch("access_policy") == EXPECTED_ACCESS_POLICY
    raise Failure, "loader confinement differs" unless
      spec.fetch("loader_confinement") == EXPECTED_LOADER_CONFINEMENT
    raise Failure, "Home Assistant contract differs" unless
      spec.fetch("home_assistant_contract") ==
        EXPECTED_HOME_ASSISTANT_CONTRACT
    raise Failure, "semantic contract differs" unless
      spec.fetch("semantic_contract") == EXPECTED_SEMANTIC_CONTRACT
    raise Failure, "quota contract differs" unless
      spec.fetch("quotas") == EXPECTED_QUOTAS
    raise Failure, "dimension contract differs" unless
      spec.fetch("dimensions") == DIMENSIONS

    split_policy = spec.fetch("split_policy")
    exact_keys!(
      split_policy,
      %w[
        partitions
        case_id_disjoint
        generator_record_id_disjoint
        canonical_semantic_id_disjoint
        family_partition_disjoint
        text_disjoint
        semantic_payload_disjoint
        performance_derived_from_heldout_coverage_only
        freeze_before_remediation_implementation
        text_lineage_marker
        identifier_namespace
        prior_lineage_separation
      ],
      "split policy"
    )
    raise Failure, "partition taxonomy differs" unless
      split_policy.fetch("partitions") == PARTITIONS
    %w[
      case_id_disjoint
      generator_record_id_disjoint
      canonical_semantic_id_disjoint
      family_partition_disjoint
      text_disjoint
      semantic_payload_disjoint
      performance_derived_from_heldout_coverage_only
      freeze_before_remediation_implementation
    ].each do |field|
      raise Failure, "split policy #{field} differs" unless
        split_policy.fetch(field) == true
    end
    raise Failure, "split namespace differs" unless
      split_policy.fetch("identifier_namespace") == "p02v3qf"
    raise Failure, "prior lineage separation differs" unless
      split_policy.fetch("prior_lineage_separation") ==
        "V2_AGGREGATES_ONLY_WITHOUT_RELEASE_RECORD_ACCESS"
    marker = split_policy.fetch("text_lineage_marker")
    raise Failure, "text lineage marker is invalid" unless
      marker.is_a?(String) && !marker.empty? && marker.valid_encoding?

    deterministic = spec.fetch("deterministic_generation")
    exact_keys!(
      deterministic,
      %w[
        algorithm
        canonical_json
        global_seed
        partition_seeds
        template_selection
        target_selection
        generator_parameter_fields
      ],
      "deterministic generation"
    )
    raise Failure, "deterministic algorithm differs" unless
      deterministic.fetch("algorithm") ==
        "P02V3_SHA256_COUNTER_PERMUTATION_V1"
    raise Failure, "canonical JSON contract differs" unless
      deterministic.fetch("canonical_json") ==
        "RECURSIVE_LEXICOGRAPHIC_KEYS_UTF8_JSON_V1"
    raise Failure, "global seed is invalid" unless
      valid_seed?(deterministic.fetch("global_seed"))
    seeds = deterministic.fetch("partition_seeds")
    exact_keys!(seeds, PARTITIONS, "partition seeds")
    raise Failure, "partition seed is invalid" unless
      seeds.values.all? { |seed| valid_seed?(seed) }
    raise Failure, "partition seeds are not unique" unless
      seeds.values.uniq.length == seeds.length
    raise Failure, "template selection contract differs" unless
      deterministic.fetch("template_selection") ==
        "SHA256_SEED_INTENT_CASE_MODULO_TEMPLATE_COUNT"
    raise Failure, "target selection contract differs" unless
      deterministic.fetch("target_selection") ==
        "AFFINE_PERMUTATION_OVER_PRIME_997"
    raise Failure, "generator parameter fields differ" unless
      deterministic.fetch("generator_parameter_fields") == %w[
        algorithm
        partition_seed
        intent_or_suite_ordinal
        record_ordinal
        template_or_definition_selector
        target_ordinal
        secondary_target_ordinal
      ]

    language = spec.fetch("language_contract")
    exact_keys!(
      language,
      %w[
        corpus_language
        template_counts
        required_lineage_placeholder
        forbidden_record_markers
        technical_fixture_label
        technical_fixture_excluded_from_corpus
      ],
      "language contract"
    )
    raise Failure, "corpus language contract differs" unless
      language.fetch("corpus_language") ==
        "PROJECT_AUTHORED_SYNTHETIC_PTBR"
    raise Failure, "template count contract differs" unless
      language.fetch("template_counts") == TEMPLATE_COUNTS
    raise Failure, "lineage placeholder contract differs" unless
      language.fetch("required_lineage_placeholder") == true
    forbidden = language.fetch("forbidden_record_markers")
    raise Failure, "forbidden marker inventory is invalid" unless
      forbidden.is_a?(Array) && !forbidden.empty? &&
      forbidden.all? { |value| value.is_a?(String) && !value.empty? } &&
      forbidden.uniq.length == forbidden.length
    raise Failure, "fixture label contract differs" unless
      language.fetch("technical_fixture_label") == "FIXTURE_TECNICA" &&
      language.fetch("technical_fixture_excluded_from_corpus") == true

    generalization = spec.fetch("generalization_contract")
    exact_keys!(
      generalization,
      %w[
        minimum_train_templates_per_intent
        hidden_static_tokens_must_be_train_observed_or_declared
        hidden_templates_must_be_distinct_from_inspectable_templates
        slot_generation_contract_shared_across_splits
        no_unseen_hidden_synonym
        generic_ptbr_function_words
      ],
      "generalization contract"
    )
    raise Failure, "generalization policy differs" unless
      generalization.fetch("minimum_train_templates_per_intent") == 4 &&
      %w[
        hidden_static_tokens_must_be_train_observed_or_declared
        hidden_templates_must_be_distinct_from_inspectable_templates
        slot_generation_contract_shared_across_splits
        no_unseen_hidden_synonym
      ].all? { |field| generalization.fetch(field) == true }
    generic_words = generalization.fetch("generic_ptbr_function_words")
    raise Failure, "generic function-word inventory is invalid" unless
      generic_words.is_a?(Array) && !generic_words.empty? &&
      generic_words.all? do |word|
        word.is_a?(String) && !word.empty? && word.valid_encoding?
      end &&
      generic_words.uniq.length == generic_words.length

    intents = spec.fetch("intents")
    raise Failure, "intent taxonomy differs" unless
      intents.is_a?(Array) &&
      intents.map { |intent| intent.fetch("intent") } == OFFICIAL_INTENTS

    family_ids = []
    intents.each do |intent|
      exact_keys!(
        intent,
        %w[
          intent
          domain
          capability
          operation
          secondary_operation
          primary_slot_kind
          case_kind
          target_noun
          graph_shape
          families
          templates
        ],
        "intent"
      )
      %w[
        intent
        domain
        capability
        operation
        primary_slot_kind
        case_kind
        target_noun
        graph_shape
      ].each do |field|
        value = intent.fetch(field)
        raise Failure, "intent #{field} is invalid" unless
          value.is_a?(String) && !value.empty? && value.valid_encoding?
      end
      if intent.fetch("case_kind") == "timer_duration_ordered"
        secondary = intent.fetch("secondary_operation")
        raise Failure, "ordered timer secondary operation is invalid" unless
          secondary.is_a?(String) && !secondary.empty?
      elsif !intent.fetch("secondary_operation").nil?
        raise Failure, "unexpected secondary operation"
      end
      raise Failure, "unknown case kind" unless
        PLACEHOLDERS.key?(intent.fetch("case_kind"))
      raise Failure, "target noun contains prohibited language" if
        forbidden_language?(spec, intent.fetch("target_noun"))

      families = intent.fetch("families")
      exact_keys!(families, SPLITS, "intent families")
      families.each do |split, family_id|
        expected = [
          "p02v3qf-family",
          partition_code(split),
          slug(intent.fetch("intent")).tr("_", "-"),
          "g37"
        ].join("-")
        raise Failure, "family identity differs" unless family_id == expected
        family_ids << family_id
      end

      templates = intent.fetch("templates")
      exact_keys!(templates, SPLITS, "intent templates")
      templates.each do |split, values|
        raise Failure, "template count differs" unless
          values.is_a?(Array) && values.length == TEMPLATE_COUNTS.fetch(split)
        values.each do |template|
          raise Failure, "template must be nonempty UTF-8" unless
            template.is_a?(String) && !template.empty? &&
            template.valid_encoding?
          raise Failure, "template lacks the lineage placeholder" unless
            template.include?("%{lineage}")
          raise Failure, "template placeholders differ" unless
            template_placeholders(template) ==
              PLACEHOLDERS.fetch(intent.fetch("case_kind"))
          raise Failure, "template contains prohibited language" if
            forbidden_language?(spec, template)
        end
      end
      validate_generalization!(spec, intent)
    end

    suites = spec.fetch("fail_closed_suites")
    exact_keys!(suites, SUITE_IDS, "fail-closed suites")
    suite_utterances = []
    suite_families = []
    suites.each do |suite_id, definitions|
      expected_count = EXPECTED_QUOTAS.fetch("suite_counts").fetch(suite_id)
      raise Failure, "suite count differs" unless
        definitions.is_a?(Array) && definitions.length == expected_count
      classes = []
      definitions.each do |definition|
        exact_keys!(
          definition,
          %w[coverage_class expected_outcome family reason utterance],
          "suite definition"
        )
        %w[coverage_class family reason utterance].each do |field|
          value = definition.fetch(field)
          raise Failure, "suite #{field} is invalid" unless
            value.is_a?(String) && !value.empty? && value.valid_encoding?
        end
        raise Failure, "suite expected outcome is invalid" unless
          %w[clarification abstention].include?(
            definition.fetch("expected_outcome")
          )
        expected_prefix =
          "p02v3qf-family-#{partition_code("suite:#{suite_id}")}-"
        raise Failure, "suite family identity differs" unless
          definition.fetch("family").start_with?(expected_prefix) &&
          definition.fetch("family").end_with?("-g37")
        raise Failure, "suite utterance contains prohibited language" if
          forbidden_language?(spec, definition.fetch("utterance"))
        classes << definition.fetch("coverage_class")
        suite_utterances << definition.fetch("utterance")
        suite_families << definition.fetch("family")
      end
      raise Failure, "suite classes are not unique" unless
        classes.uniq.length == classes.length
    end

    family_ids.concat(suite_families)
    raise Failure, "family identities are not globally unique" unless
      family_ids.uniq.length == family_ids.length
    raise Failure, "suite utterances are not unique" unless
      suite_utterances.uniq.length == suite_utterances.length

    prior = spec.fetch("prior_lineage_aggregate_exclusions")
    exact_keys!(
      prior,
      %w[
        source_id
        corpus_version
        record_access
        artifact_sha256
      ],
      "prior lineage aggregate exclusions"
    )
    raise Failure, "prior source identity differs" unless
      prior.fetch("source_id") ==
        "project-authored-synthetic-ptbr-p15-v2" &&
      prior.fetch("corpus_version") == "2.0.0" &&
      prior.fetch("record_access") ==
        "PROHIBITED_MANIFEST_AGGREGATES_ONLY"
    raise Failure, "prior artifact identities differ" unless
      prior.fetch("artifact_sha256") == PRIOR_V2_ARTIFACT_HASHES
  end

  def area_for(ordinal)
    AREAS.fetch((ordinal - 1) % AREAS.length)
  end

  def target_values(spec, intent, partition, ordinal)
    area = area_for(ordinal)
    number = ((ordinal - 1) / AREAS.length) + 1
    intent_slug = slug(intent.fetch("intent"))
    generation = spec.fetch("semantic_contract").fetch("catalog_generation")
    code = partition_code(partition)
    {
      "text" =>
        "#{intent.fetch('target_noun')} #{number} do ambiente #{area}",
      "entity_id" => [
        intent.fetch("domain"),
        "p02v3qf_#{code}_#{intent_slug}_#{format('%04d', ordinal)}"
      ].join("."),
      "area" => area,
      "number" => number,
      "catalog_generation" => generation
    }
  end

  def text_slot(id, value)
    {"id" => id, "kind" => "text", "value" => value}
  end

  def integer_slot(id, value)
    {"id" => id, "kind" => "integer", "value" => value}
  end

  def entity_slot(id, target)
    {
      "id" => id,
      "kind" => "entity",
      "value" => {
        "id" => target.fetch("entity_id"),
        "catalog_generation" => target.fetch("catalog_generation")
      }
    }
  end

  def node(id, capability, operation, slots)
    {
      "id" => id,
      "capability" => capability,
      "operation" => operation,
      "slots" => slots.sort_by { |slot| slot.fetch("id") }
    }
  end

  def build_case_values(spec, intent, partition, parameters)
    target = target_values(
      spec,
      intent,
      partition,
      parameters.fetch("target_ordinal")
    )
    target2 = target_values(
      spec,
      intent,
      partition,
      parameters.fetch("secondary_target_ordinal")
    )
    marker = spec.fetch("split_policy").fetch("text_lineage_marker")
    ordinal = parameters.fetch("target_ordinal")
    area = target.fetch("area")
    seconds = 10 + ((ordinal * 37) % 7_190)
    values = {
      lineage: marker,
      target: target.fetch("text"),
      target2: target2.fetch("text"),
      position: ordinal % 101,
      seconds: seconds,
      scope: "ambiente #{area} do agrupamento #{format('%03d', target.fetch('number'))}",
      pending: "solicitação #{format('%04d', ordinal)} referente ao ambiente #{area}",
      message: "recado #{format('%04d', ordinal)} referente ao ambiente #{area}"
    }
    [target, target2, values]
  end

  def expected_plan(spec, intent, target, target2, parameters)
    capability = intent.fetch("capability")
    operation = intent.fetch("operation")
    namespace = spec.fetch("semantic_contract").fetch("node_namespace")
    node_1 = "#{namespace}:node_1"
    node_2 = "#{namespace}:node_2"
    generation = spec.fetch("semantic_contract").fetch("catalog_generation")
    nodes = []
    relations = []

    case intent.fetch("case_kind")
    when "entity", "display", "timer"
      nodes << node(node_1, capability, operation, [
        entity_slot("ha:entity", target)
      ])
    when "entity_pair"
      nodes << node(node_1, capability, operation, [
        entity_slot("ha:entity", target)
      ])
      nodes << node(node_2, capability, operation, [
        entity_slot("ha:entity", target2)
      ])
    when "pending_action"
      nodes << node(node_1, capability, operation, [
        text_slot("ha:pending_action", parameters.fetch(:pending))
      ])
    when "position"
      nodes << node(node_1, capability, operation, [
        entity_slot("ha:entity", target),
        integer_slot("ha:position", parameters.fetch(:position))
      ])
    when "timer_duration_ordered"
      timer_slot = entity_slot("ha:timer", target)
      nodes << node(node_1, capability, operation, [
        timer_slot,
        integer_slot("ha:duration_seconds", parameters.fetch(:seconds))
      ])
      nodes << node(
        node_2,
        capability,
        intent.fetch("secondary_operation"),
        [timer_slot]
      )
      relations << {"from" => node_1, "to" => node_2, "kind" => "precedes"}
    when "timer_area"
      nodes << node(node_1, capability, operation, [
        text_slot("ha:area", parameters.fetch(:scope))
      ])
    when "timer_delta"
      nodes << node(node_1, capability, operation, [
        entity_slot("ha:timer", target),
        integer_slot(
          "ha:duration_delta_seconds",
          parameters.fetch(:seconds)
        )
      ])
    when "response"
      nodes << node(node_1, capability, operation, [
        text_slot("ha:response_text", parameters.fetch(:message))
      ])
    when "broadcast"
      nodes << node(node_1, capability, operation, [
        entity_slot("ha:entity", target),
        text_slot("ha:message", parameters.fetch(:message))
      ])
    else
      raise Failure, "unknown case kind"
    end

    {
      "outcome" => "plan",
      "intent" => intent.fetch("intent"),
      "catalog_generation" => generation,
      "nodes" => nodes,
      "relations" => relations
    }
  end

  def target_cardinality(intent)
    case intent.fetch("case_kind")
    when "entity_pair"
      "two"
    when "response", "pending_action", "timer_area"
      "zero"
    else
      "one"
    end
  end

  def render_template(template, parameters)
    format(template, parameters)
  rescue KeyError, ArgumentError => error
    raise Failure, "template rendering failed: #{error.class}"
  end

  def case_identity(seed, partition, intent, ordinal)
    suffix = Digest::SHA256.hexdigest(
      [seed, partition, intent, ordinal, "case"].join("\0")
    )[0, 12]
    [
      "p02v3qf-case",
      partition_code(partition),
      slug(intent).tr("_", "-"),
      format("%04d", ordinal),
      suffix
    ].join("-")
  end

  def generator_record_identity(seed, partition, intent, ordinal)
    suffix = Digest::SHA256.hexdigest(
      [seed, partition, intent, ordinal, "generator-record"].join("\0")
    )[0, 12]
    [
      "p02v3qf-genrec",
      partition_code(partition),
      slug(intent).tr("_", "-"),
      format("%04d", ordinal),
      suffix
    ].join("-")
  end

  def build_semantic_case(spec, intent, intent_ordinal, split, ordinal)
    corpus = spec.fetch("corpus")
    parameters =
      deterministic_parameters(spec, split, intent_ordinal, intent, ordinal)
    target, target2, template_values =
      build_case_values(spec, intent, split, parameters)
    templates = intent.fetch("templates").fetch(split)
    template = templates.fetch(parameters.fetch("template_ordinal") - 1)
    utterance = render_template(template, template_values)
    namespace = spec.fetch("semantic_contract").fetch("identifier_namespace")
    intent_slug = slug(intent.fetch("intent"))
    family_id = intent.fetch("families").fetch(split)
    seed = parameters.fetch("partition_seed")
    context = {
      "catalog_generation" =>
        spec.fetch("semantic_contract").fetch("catalog_generation"),
      "session_snapshot_id" => [
        namespace,
        partition_code(split),
        intent_slug,
        format("%04d", ordinal),
        Digest::SHA256.hexdigest(
          [seed, intent.fetch("intent"), ordinal, "snapshot"].join("\0")
        )[0, 12]
      ].join(":")
    }
    expected = expected_plan(spec, intent, target, target2, template_values)
    semantic_payload = {
      "partition" => split,
      "family_id" => family_id,
      "context" => context,
      "expected" => expected
    }
    semantic_payload_sha256 = canonical_sha(semantic_payload)
    {
      "schema_version" => 2,
      "case_id" => case_identity(
        seed,
        split,
        intent.fetch("intent"),
        ordinal
      ),
      "generator_record_id" => generator_record_identity(
        seed,
        split,
        intent.fetch("intent"),
        ordinal
      ),
      "canonical_semantic_id" =>
        "p02v3qf-sem-#{semantic_payload_sha256}",
      "semantic_payload_sha256" => semantic_payload_sha256,
      "family_id" => family_id,
      "source_id" => corpus.fetch("id"),
      "corpus_version" => corpus.fetch("version"),
      "generator_id" => corpus.fetch("generator_id"),
      "generator_version" => corpus.fetch("generator_version"),
      "oracle_origin" => corpus.fetch("oracle_origin"),
      "license" => corpus.fetch("license"),
      "locale" => corpus.fetch("locale"),
      "split" => split,
      "generator_parameters" => parameters,
      "utterance" => utterance,
      "utterance_sha256" => sha256(utterance.encode(Encoding::UTF_8)),
      "context" => context,
      "dimensions" => {
        "source" => corpus.fetch("id"),
        "family" => family_id,
        "intent" => intent.fetch("intent"),
        "domain" => intent.fetch("domain"),
        "slot_kind" => intent.fetch("primary_slot_kind"),
        "graph_shape" => intent.fetch("graph_shape"),
        "outcome" => "plan",
        "ambiguity" => "unambiguous",
        "noise" => "clean_text",
        "target_cardinality" => target_cardinality(intent)
      },
      "expected" => expected
    }
  end

  def build_semantic_records(spec, split)
    spec.fetch("intents").each_with_index.flat_map do |intent, index|
      (1..case_count(spec, split)).map do |ordinal|
        build_semantic_case(spec, intent, index + 1, split, ordinal)
      end
    end
  end

  def build_suite_records(spec, suite_id, suite_ordinal)
    corpus = spec.fetch("corpus")
    generation = spec.fetch("semantic_contract").fetch("catalog_generation")
    partition = "suite:#{suite_id}"
    spec.fetch("fail_closed_suites").fetch(suite_id)
      .each_with_index.map do |definition, offset|
      ordinal = offset + 1
      parameters = suite_deterministic_parameters(
        spec,
        suite_id,
        suite_ordinal,
        ordinal
      )
      seed = parameters.fetch("partition_seed")
      expected = {
        "outcome" => definition.fetch("expected_outcome"),
        "reason" => definition.fetch("reason")
      }
      context = {
        "condition" => definition.fetch("coverage_class"),
        "catalog_generation" =>
          suite_id == "stale_state" ? generation + 1 : generation,
        "session_snapshot_id" => [
          "p02v3qf",
          partition_code(partition),
          format("%03d", ordinal),
          Digest::SHA256.hexdigest(
            [seed, suite_id, ordinal, "suite-snapshot"].join("\0")
          )[0, 12]
        ].join(":")
      }
      family_id = definition.fetch("family")
      semantic_payload = {
        "partition" => partition,
        "family_id" => family_id,
        "coverage_class" => definition.fetch("coverage_class"),
        "context" => context,
        "expected" => expected
      }
      semantic_payload_sha256 = canonical_sha(semantic_payload)
      utterance = definition.fetch("utterance")
      {
        "schema_version" => 2,
        "suite_id" => suite_id,
        "partition" => partition,
        "case_id" => case_identity(seed, partition, suite_id, ordinal),
        "generator_record_id" =>
          generator_record_identity(seed, partition, suite_id, ordinal),
        "canonical_semantic_id" =>
          "p02v3qf-sem-#{semantic_payload_sha256}",
        "semantic_payload_sha256" => semantic_payload_sha256,
        "family_id" => family_id,
        "coverage_class" => definition.fetch("coverage_class"),
        "source_id" => corpus.fetch("id"),
        "corpus_version" => corpus.fetch("version"),
        "generator_id" => corpus.fetch("generator_id"),
        "generator_version" => corpus.fetch("generator_version"),
        "oracle_origin" => corpus.fetch("oracle_origin"),
        "license" => corpus.fetch("license"),
        "locale" => corpus.fetch("locale"),
        "generator_parameters" => parameters,
        "utterance" => utterance,
        "utterance_sha256" => sha256(utterance.encode(Encoding::UTF_8)),
        "context" => context,
        "expected" => expected
      }
    end
  end

  def partition_identity_sets(records)
    {
      "utterance" => records.map { |row| row.fetch("utterance") }.to_set,
      "case_id" => records.map { |row| row.fetch("case_id") }.to_set,
      "generator_record_id" =>
        records.map { |row| row.fetch("generator_record_id") }.to_set,
      "canonical_semantic_id" =>
        records.map { |row| row.fetch("canonical_semantic_id") }.to_set,
      "family_id" => records.map { |row| row.fetch("family_id") }.to_set,
      "semantic_payload_sha256" =>
        records.map { |row| row.fetch("semantic_payload_sha256") }.to_set
    }
  end

  def validate_partition_separation!(records_by_partition)
    raise Failure, "partition record taxonomy differs" unless
      records_by_partition.keys == PARTITIONS

    identities = {}
    records_by_partition.each do |partition, records|
      sets = partition_identity_sets(records)
      sets.each do |field, values|
        raise Failure, "#{partition} contains duplicate #{field}" unless
          values.length == records.length ||
          field == "family_id"
      end
      identities[partition] = sets
    end

    identities.each do |left_partition, left_sets|
      identities.each do |right_partition, right_sets|
        next unless PARTITIONS.index(left_partition) <
          PARTITIONS.index(right_partition)

        left_sets.each_key do |field|
          next if (left_sets.fetch(field) & right_sets.fetch(field)).empty?

          raise Failure, "#{field} crosses partitions"
        end
      end
    end
  end

  def validate_record_language!(spec, records_by_partition)
    records_by_partition.each_value do |records|
      records.each do |record|
        each_string(record) do |value|
          raise Failure, "corpus record contains prohibited language" if
            forbidden_language?(spec, value)
          raise Failure, "corpus record contains prior lineage material" if
            PRIOR_LINEAGE_FORBIDDEN_RECORD_STRINGS.any? do |prior|
              value.include?(prior)
            end
        end
      end
    end
  end

  def json_lines(records)
    records.map { |record| JSON.generate(record) }.join("\n") + "\n"
  end

  def dimension_counts(records)
    DIMENSIONS.each_with_object({}) do |dimension, result|
      counts = Hash.new(0)
      records.each do |record|
        counts[record.fetch("dimensions").fetch(dimension)] += 1
      end
      result[dimension] = counts.keys.sort.each_with_object({}) do |value, ordered|
        ordered[value] = counts.fetch(value)
      end
    end
  end

  def build_artifacts(spec)
    artifacts = {}
    records_by_partition = {}
    SPLITS.each do |split|
      records = build_semantic_records(spec, split)
      records_by_partition[split] = records
      artifacts["#{split}.jsonl"] = json_lines(records)
    end
    SUITE_IDS.each_with_index do |suite_id, index|
      partition = "suite:#{suite_id}"
      records = build_suite_records(spec, suite_id, index + 1)
      records_by_partition[partition] = records
      artifacts[SUITE_PATHS.fetch(suite_id)] = json_lines(records)
    end
    validate_partition_separation!(records_by_partition)
    validate_record_language!(spec, records_by_partition)
    [artifacts, records_by_partition]
  end

  def artifact_record_count(bytes)
    bytes.lines.length
  end

  def artifact_entry(path, bytes)
    digest = sha256(bytes)
    {
      "path" => path,
      "partition" => ARTIFACT_PARTITIONS.fetch(path),
      "records" => artifact_record_count(bytes),
      "bytes" => bytes.bytesize,
      "sha256" => digest,
      "artifact_id" => "p02v3qf-artifact-#{digest}"
    }
  end

  def build_manifest(spec, artifacts, records_by_partition)
    corpus = spec.fetch("corpus")
    spec_bytes = read_regular(
      SPEC_PATH,
      MAX_SPEC_BYTES,
      "specification",
      root: DATA_ROOT
    )
    generator_bytes = read_regular(
      GENERATOR_PATH,
      MAX_GENERATOR_BYTES,
      "generator",
      root: ROOT
    )
    artifact_entries = artifacts.keys.sort.map do |path|
      artifact_entry(path, artifacts.fetch(path))
    end
    artifact_entries.each do |entry|
      prior_hash = PRIOR_V2_ARTIFACT_HASHES.fetch(entry.fetch("path"))
      raise Failure, "artifact matches the prior lineage identity" if
        entry.fetch("sha256") == prior_hash
    end

    {
      "schema_version" => 3,
      "corpus" => {
        "id" => corpus.fetch("id"),
        "version" => corpus.fetch("version"),
        "status" => corpus.fetch("status"),
        "authorization" => corpus.fetch("authorization"),
        "authorization_parent_commit" =>
          corpus.fetch("authorization_parent_commit"),
        "locale" => corpus.fetch("locale"),
        "license" => corpus.fetch("license"),
        "claim_scope" => corpus.fetch("claim_scope"),
        "generator_id" => corpus.fetch("generator_id"),
        "generator_version" => corpus.fetch("generator_version"),
        "oracle_origin" => corpus.fetch("oracle_origin"),
        "specification_sha256" => sha256(spec_bytes),
        "specification_id" => "p02v3qf-spec-#{sha256(spec_bytes)}",
        "generator_sha256" => sha256(generator_bytes),
        "generator_artifact_id" =>
          "p02v3qf-generator-#{sha256(generator_bytes)}"
      },
      "contract" => spec.fetch("home_assistant_contract"),
      "semantic_contract" => spec.fetch("semantic_contract"),
      "freeze" => spec.fetch("freeze"),
      "access_policy" => spec.fetch("access_policy"),
      "loader_confinement" => spec.fetch("loader_confinement"),
      "split_policy" => spec.fetch("split_policy"),
      "deterministic_generation_sha256" =>
        canonical_sha(spec.fetch("deterministic_generation")),
      "generalization_contract_sha256" =>
        canonical_sha(spec.fetch("generalization_contract")),
      "quotas" => spec.fetch("quotas"),
      "taxonomies" => {
        "dimensions" => spec.fetch("dimensions"),
        "intents" => spec.fetch("intents").map do |intent|
          intent.fetch("intent")
        end,
        "partition_record_counts" =>
          PARTITIONS.each_with_object({}) do |partition, result|
            result[partition] = records_by_partition.fetch(partition).length
          end,
        "heldout_counts" =>
          dimension_counts(records_by_partition.fetch("heldout")),
        "performance_counts" =>
          dimension_counts(records_by_partition.fetch("performance")),
        "suite_classes" =>
          SUITE_IDS.each_with_object({}) do |suite_id, result|
            result[suite_id] =
              spec.fetch("fail_closed_suites").fetch(suite_id).map do |definition|
                definition.fetch("coverage_class")
              end
          end,
        "suite_families" =>
          SUITE_IDS.each_with_object({}) do |suite_id, result|
            result[suite_id] =
              spec.fetch("fail_closed_suites").fetch(suite_id).map do |definition|
                definition.fetch("family")
              end
          end
      },
      "partition_separation" => {
        "status" => "VERIFIED",
        "partition_count" => PARTITIONS.length,
        "fields" => %w[
          utterance
          case_id
          generator_record_id
          canonical_semantic_id
          family_id
          semantic_payload_sha256
        ]
      },
      "prior_lineage_aggregate_exclusions" =>
        spec.fetch("prior_lineage_aggregate_exclusions"),
      "artifacts" => artifact_entries
    }
  end

  def generated_bytes
    spec = load_spec
    validate_specification!(spec)
    artifacts, records_by_partition = build_artifacts(spec)
    manifest = build_manifest(spec, artifacts, records_by_partition)
    artifacts.merge(MANIFEST_PATH => JSON.pretty_generate(manifest) + "\n")
  end

  def generate(output_root)
    artifacts = generated_bytes
    prepared_root = prepare_output_root!(output_root)
    prepared_paths = artifacts.keys.sort.each_with_object({}) do |relative, result|
      result[relative] =
        prepare_contained_output_path!(prepared_root, relative)
    end
    artifacts.each do |relative, bytes|
      File.binwrite(prepared_paths.fetch(relative), bytes)
    end
    artifacts
  end

  def check_generated!
    expected = generated_bytes
    Dir.mktmpdir("p02-v3-corpus-check.") do |temporary|
      generated = generate(temporary)
      raise Failure, "generated path set differs" unless
        generated.keys.sort == expected.keys.sort
      expected.keys.sort.each do |relative|
        committed = File.join(DATA_ROOT, relative)
        generated_path = File.join(temporary, relative)
        committed_bytes = read_regular(
          committed,
          [expected.fetch(relative).bytesize, 1].max,
          "committed artifact #{relative}",
          root: DATA_ROOT
        )
        generated_artifact_bytes = read_regular(
          generated_path,
          [expected.fetch(relative).bytesize, 1].max,
          "generated artifact #{relative}",
          root: temporary
        )
        raise Failure, "generated artifact differs: #{relative}" unless
          committed_bytes.b == generated_artifact_bytes.b
      end
    end
    expected
  end

  def aggregate_rows(bytes_by_path)
    manifest = parse_json(
      bytes_by_path.fetch(MANIFEST_PATH),
      "generated manifest"
    )
    artifact_rows = manifest.fetch("artifacts").map do |entry|
      {
        "path" => entry.fetch("path"),
        "records" => entry.fetch("records"),
        "bytes" => entry.fetch("bytes"),
        "sha256" => entry.fetch("sha256"),
        "artifact_id" => entry.fetch("artifact_id")
      }
    end
    manifest_bytes = bytes_by_path.fetch(MANIFEST_PATH)
    manifest_sha = sha256(manifest_bytes)
    artifact_rows + [
      {
        "path" => MANIFEST_PATH,
        "records" => 1,
        "bytes" => manifest_bytes.bytesize,
        "sha256" => manifest_sha,
        "artifact_id" => "p02v3qf-manifest-#{manifest_sha}"
      }
    ]
  end

  def print_aggregate_report(bytes_by_path)
    aggregate_rows(bytes_by_path).each do |row|
      puts "P02_V3_ARTIFACT #{JSON.generate(row)}"
    end
    manifest = parse_json(
      bytes_by_path.fetch(MANIFEST_PATH),
      "generated manifest"
    )
    corpus = manifest.fetch("corpus")
    puts "P02_V3_IDENTITY #{JSON.generate({
      "source_id" => corpus.fetch("id"),
      "corpus_version" => corpus.fetch("version"),
      "generator_id" => corpus.fetch("generator_id"),
      "generator_version" => corpus.fetch("generator_version"),
      "specification_sha256" => corpus.fetch("specification_sha256"),
      "specification_id" => corpus.fetch("specification_id"),
      "generator_sha256" => corpus.fetch("generator_sha256"),
      "generator_artifact_id" => corpus.fetch("generator_artifact_id")
    })}"
  end

  module CLI
    module_function

    def run(arguments)
      options = {
        output: DATA_ROOT,
        check: false,
        aggregate_report: false
      }
      parser = OptionParser.new do |opts|
        opts.on("--output PATH") do |path|
          options[:output] = File.expand_path(path)
        end
        opts.on("--check") { options[:check] = true }
        opts.on("--aggregate-report") { options[:aggregate_report] = true }
      end
      parser.parse!(arguments)
      raise Failure, "unexpected arguments" unless arguments.empty?
      raise Failure, "--check cannot be combined with --output" if
        options[:check] && options[:output] != DATA_ROOT

      bytes = if options[:check]
                P02V3Corpus.check_generated!
              else
                P02V3Corpus.generate(options.fetch(:output))
              end
      P02V3Corpus.print_aggregate_report(bytes) if
        options[:aggregate_report]
      puts(
        options[:check] ?
          "P02_V3_CORPUS_GENERATION_CHECK_PASS" :
          "P02_V3_CORPUS_GENERATED"
      )
    rescue Failure, OptionParser::ParseError, KeyError, TypeError => error
      warn "P02_V3_CORPUS_GENERATION_FAIL: #{error.message}"
      exit 1
    end
  end
end

P02V3Corpus::CLI.run(ARGV) if __FILE__ == $PROGRAM_NAME
