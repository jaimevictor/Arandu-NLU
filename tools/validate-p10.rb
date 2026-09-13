# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "psych"

module P10Validation
  class Failure < StandardError; end
  class DuplicateKey < StandardError; end

  class DuplicateRejectingHash < Hash
    def []=(key, value)
      raise DuplicateKey, key if key?(key)

      super
    end
  end

  ROOT = File.expand_path("..", __dir__)
  SOURCE_EVIDENCE = "docs/evidence/P10-SOURCES.yaml"
  MATERIALS = "docs/clean-room/MATERIALS.yaml"
  COVERAGE = "data/home-assistant/p10/domain-coverage.json"
  COVERAGE_SCHEMA = "schemas/ha-domain-coverage-v1.schema.json"

  SOURCE_ID = "home-assistant-core-2026.8.3-p10-catalog"
  SOURCE_TAG = "2026.8.3"
  SOURCE_COMMIT = "759e4658f40b3ccb671d418b8a0ed95224bf4561"
  SOURCE_TREE = "f4a72534bb33abf8b5d183910a0c134b968af2f8"
  LICENSE_SHA256 =
    "c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4"
  BUNDLE_SHA256 =
    "4627587cd790e86e935c702e2f8e3c9dda48390ad639bb69cd7c7fba2fd0489e"

  SOURCE_PATHS = {
    "homeassistant/components/config/area_registry.py" => [
      5_302, "356960ec6113d34a7dd8d502f11e26559f6c5ccac43563f4b467cb7c7823a031"
    ],
    "homeassistant/components/config/device_registry.py" => [
      7_399, "a9bb2aa98cc630a237fea96421bad98c892ce425d6f61473304ac4f83638332b"
    ],
    "homeassistant/components/config/entity_registry.py" => [
      13_605, "f1ff1de9175a7474e54691d8e716c2f68502525a7133df033c86f70f05d56eb0"
    ],
    "homeassistant/components/config/floor_registry.py" => [
      5_092, "2f6039a3b284b910c08adb3c667dbad652606850759986e5ebd1a5468708a7d4"
    ],
    "homeassistant/components/homeassistant/exposed_entities.py" => [
      18_197, "b41137bde06e72f43b648ea1fbad4ac0e21640e86492ec872a35ea29f46f26ad"
    ],
    "homeassistant/generated/entity_platforms.py" => [
      1_329, "fc8e6bbbdf4ea942dc31759142d12d805021c19eb71a1aac02438bb3fd6ad332"
    ],
    "homeassistant/helpers/area_registry.py" => [
      21_446, "81893d7e9c30b8906bb09496f16eee39116040986cffc2d9cd6b7abcc529a241"
    ],
    "homeassistant/helpers/device_registry.py" => [
      146_097, "9aa4429a2d23a4fcda33cbbf153237b1f4fa179cafaa3ba14ef26198ee0e4727"
    ],
    "homeassistant/helpers/entity_registry.py" => [
      108_162, "7f3238f6107c3081650483a6358b33fe9260a88787b4c774c78dbc9005e6bac7"
    ],
    "homeassistant/helpers/floor_registry.py" => [
      11_660, "3d11830d03f0f7bb1e1ca0389b7e80ee6e0d1492adafb52d1738ef0f874bb50f"
    ],
    "homeassistant/helpers/intent.py" => [
      48_467, "8a62d1ab08d66a60a6c397bbb4d0b0ef12770c924ef8fd4ecffd690143703f9f"
    ],
    "homeassistant/helpers/normalized_name_base_registry.py" => [
      2_540, "f19655c00442efb25a479ac7a338d0730b4deffda6c8febdd65cac9dfa78d0cf"
    ],
    "homeassistant/util/__init__.py" => [
      6_848, "f615e88bfb040f1b83538da590ac1aad4b8170d3dd687c670ff8ff64fd4ef967"
    ],
    "pyproject.toml" => [
      41_098, "2618b6f740c5f55e48eeb2204661f841ea53ff9bf99edd0632879b0edf693642"
    ]
  }.freeze

  DOMAINS = %w[
    ai_task
    air_quality
    alarm_control_panel
    assist_satellite
    binary_sensor
    button
    calendar
    camera
    climate
    conversation
    cover
    date
    datetime
    device_tracker
    event
    fan
    geo_location
    humidifier
    image
    image_processing
    infrared
    lawn_mower
    light
    lock
    media_player
    notify
    number
    radio_frequency
    remote
    scene
    select
    sensor
    siren
    stt
    switch
    text
    time
    todo
    tts
    update
    vacuum
    valve
    wake_word
    water_heater
    weather
  ].freeze

  INTENTS = %w[
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

  ACTION_PREREQUISITES = %w[
    typed_operation_schema
    capability_check
    risk_policy_mapping
    adapter_mapping
  ].freeze

  LIMITATIONS = %w[
    catalog_presence_is_not_state_query_or_action_support
    state_queries_require_a_reviewed_typed_descriptor
    actions_require_all_four_reviewed_contracts
    intent_release_coverage_is_verified_in_P15
    source_identifiers_are_not_linguistic_data
  ].freeze

  ARTIFACTS = {
    SOURCE_EVIDENCE => [
      5_132, "c434031775d365ce20c074c50e19f0dfe1980ae2696ab667bdf7d6718f758c17"
    ],
    COVERAGE => [
      15_885, "042f3aa7afe27d9057f12107473e12a7819164b886d62e487eb9f00d58e9bf14"
    ],
    COVERAGE_SCHEMA => [
      4_177, "e3597603e65cb142345ea055550025ab4520392305dcefd24d5b8e158658c160"
    ]
  }.freeze

  REQUIREMENTS = (
    (1..18).map { |number| format("P10-HA-%03d", number) } +
    (21..22).map { |number| format("P10-HA-%03d", number) } +
    (26..32).map { |number| format("P10-HA-%03d", number) } +
    %w[GLB-ENTITY-001 GLB-ENTITY-002]
  ).freeze

  FORBIDDEN_RUNTIME = {
    "ambient environment" => /\bstd::env\b|\benv!\s*\(|\boption_env!\s*\(/,
    "filesystem" => /\bstd::fs\b|\bread_dir\s*\(|File::open/,
    "network" => /\bstd::net\b|TcpStream|UdpSocket/,
    "process" => /\bstd::process\b|Command::new/,
    "time" => /\bstd::time\b|SystemTime|Instant::now/,
    "entropy" => /\brand(?:om)?\b|thread_rng|getrandom/,
    "unordered collection" => /\bHashMap\b|\bHashSet\b/,
    "global mutable state" => /static\s+mut|OnceLock|LazyLock/,
    "serialization authority" => /\bserde(?:_json)?\b/,
    "runtime artifact import" => /include_(?:bytes|str)!\s*\(/,
    "protocol dependency" => /\bprotocol\b/,
    "execution authority" => /\bservice_call\b|\bexecute_operation\b/,
    "credential material" => /\bcredential\b|\bpassword\b|\btoken\b/,
    "diagnostic sink" => /\bprintln!\s*\(|\beprintln!\s*\(|\btracing::|\blog::/
  }.freeze

  module_function

  def run(arguments)
    arguments = arguments.dup
    no_cargo = arguments.delete("--no-cargo")
    review_candidate = arguments.delete("--review-candidate")
    unless arguments.empty?
      raise Failure, "usage: tools/validate-p10 [--no-cargo] [--review-candidate]"
    end

    validate(
      ROOT,
      run_cargo: !no_cargo && !review_candidate,
      require_satisfied: !review_candidate
    )
    puts(review_candidate ? "P10_REVIEW_CANDIDATE_PASS" : "P10_GATE_PASS")
  rescue Failure => error
    warn "P10_GATE_FAIL: #{error.message}"
    exit 1
  end

  def validate(root, run_cargo:, require_satisfied:)
    validate_artifacts(root)
    source = read_yaml(root, SOURCE_EVIDENCE)
    validate_source_evidence(source)
    materials = read_yaml(root, MATERIALS)
    validate_materials(materials)
    coverage = read_canonical_json(root, COVERAGE)
    validate_coverage(coverage)
    validate_schema(read_json(root, COVERAGE_SCHEMA))
    validate_dependencies(root)
    validate_production_isolation(root)
    validate_fixture_policy(root)
    validate_requirements(root, require_satisfied: require_satisfied)
    run_cargo_checks(root) if run_cargo
    true
  end

  def validate_artifacts(root)
    ARTIFACTS.each do |relative, (expected_bytes, expected_hash)|
      path = File.join(root, relative)
      raise Failure, "artifact is a symlink: #{relative}" if File.symlink?(path)
      raise Failure, "artifact is not a regular file: #{relative}" unless File.file?(path)

      validate_artifact_bytes(
        relative,
        File.binread(path),
        expected_bytes: expected_bytes,
        expected_hash: expected_hash
      )
    end
    true
  end

  def validate_artifact_bytes(relative, bytes, expected_bytes: nil, expected_hash: nil)
    expected_bytes, expected_hash = ARTIFACTS.fetch(relative) unless
      expected_bytes && expected_hash
    raise Failure, "artifact byte count differs: #{relative}" unless
      bytes.bytesize == expected_bytes
    raise Failure, "artifact hash differs: #{relative}" unless
      Digest::SHA256.hexdigest(bytes) == expected_hash

    true
  rescue KeyError
    raise Failure, "unrecognized pinned artifact: #{relative}"
  end

  def validate_source_evidence(document)
    exact_fields(
      document,
      %w[
        schema_version as_of status home_assistant_catalog_contract
        review_disposition
      ],
      "P10 source evidence"
    )
    raise Failure, "P10 source evidence header differs" unless
      document["schema_version"] == 1 &&
        document["as_of"] == "2026-08-28" &&
        document["status"] == "OPEN_REFERENCE_P10_SELECTED"

    source = document.fetch("home_assistant_catalog_contract")
    raise Failure, "source identity differs" unless
      source["source_id"] == SOURCE_ID &&
        source["provider"] == "Home_Assistant_project" &&
        source["upstream_owner"] == "home-assistant" &&
        source["canonical_url"] == "https://github.com/home-assistant/core" &&
        source["tag"] == SOURCE_TAG &&
        source["commit"] == SOURCE_COMMIT &&
        source["tree"] == SOURCE_TREE &&
        source["license"] == "Apache-2.0" &&
        source["license_file"] == "LICENSE.md" &&
        source["license_bytes"] == 11_357 &&
        source["license_sha256"] == LICENSE_SHA256 &&
        source["selected_path_bundle_algorithm"] ==
          "sha256(sorted(path + NUL + bytes + NUL))" &&
        source["selected_path_bundle_sha256"] == BUNDLE_SHA256

    paths = source.fetch("selected_paths")
    actual_paths = paths.to_h do |record|
      exact_fields(record, %w[path bytes sha256], "selected source path")
      [record.fetch("path"), [record.fetch("bytes"), record.fetch("sha256")]]
    end
    raise Failure, "selected source path inventory differs" unless
      actual_paths == SOURCE_PATHS && paths.map { |record| record.fetch("path") }.sort ==
        paths.map { |record| record.fetch("path") }

    observed = source.fetch("observed_contract")
    raise Failure, "observed source contract differs" unless
      observed["stable_entity_identity"] == "registry_entry_id" &&
        observed["external_entity_identity"] == "dotted_domain_object_id" &&
        observed["area_identity"] == "slug_derived_registry_id" &&
        observed["floor_identity"] == "slug_derived_registry_id" &&
        observed["device_alias_field"] == "absent" &&
        observed["exposure_scope"] == "conversation_assistant" &&
        observed["explicit_exposure_precedes_default_hidden_filter"] == true &&
        observed["generated_entity_platform_domains"] == DOMAINS.length &&
        observed["built_in_intent_constants"] == INTENTS.length
    raise Failure, "source transformation permits copied bytes" unless
      source.dig("transformation", "source_bytes_copied") == false

    review = document.fetch("review_disposition")
    raise Failure, "source admission class differs" unless
      review["admission_class"] == "OPEN_REFERENCE_not_data_or_dependency_admission"
    true
  rescue KeyError, TypeError => error
    raise Failure, "malformed P10 source evidence: #{error.class}"
  end

  def validate_materials(document)
    records = document.fetch("materials")
    matches = records.select { |record| record["id"] == SOURCE_ID }
    raise Failure, "P10 material record count differs" unless matches.length == 1

    record = matches.fetch(0)
    raise Failure, "P10 material identity differs" unless
      record["status"] == "OPEN_REFERENCE" &&
        record["provider"] == "Home_Assistant_project" &&
        record["upstream_owner"] == "home-assistant" &&
        record["tag"] == SOURCE_TAG &&
        record["commit"] == SOURCE_COMMIT &&
        record["tree"] == SOURCE_TREE &&
        record["license"] == "Apache-2.0" &&
        record["license_file_sha256"] == LICENSE_SHA256 &&
        record["selected_path_bundle_sha256"] == BUNDLE_SHA256 &&
        record["observed_generated_entity_platform_domains"] == DOMAINS.length &&
        record["observed_built_in_intent_constants"] == INTENTS.length &&
        record["source_evidence"] == SOURCE_EVIDENCE

    actual_paths = record.fetch("contract_paths").to_h do |path|
      [path.fetch("path"), [path.fetch("bytes"), path.fetch("sha256")]]
    end
    raise Failure, "P10 material path inventory differs" unless actual_paths == SOURCE_PATHS
    true
  rescue KeyError, TypeError => error
    raise Failure, "malformed P10 material record: #{error.class}"
  end

  def validate_coverage(coverage)
    exact_fields(
      coverage,
      %w[
        schema_version baseline action_contract_prerequisites domains
        intent_families unknown_domain limitations
      ],
      "coverage"
    )
    raise Failure, "coverage schema version differs" unless coverage["schema_version"] == 1
    raise Failure, "coverage baseline differs" unless coverage.fetch("baseline") == {
      "claim_scope" => "public_contract_coverage_only",
      "commit" => SOURCE_COMMIT,
      "license" => "Apache-2.0",
      "selected_path_bundle_sha256" => BUNDLE_SHA256,
      "source_id" => SOURCE_ID,
      "tag" => SOURCE_TAG,
      "tree" => SOURCE_TREE
    }
    raise Failure, "action prerequisite contract differs" unless
      coverage.fetch("action_contract_prerequisites") == ACTION_PREREQUISITES

    domains = coverage.fetch("domains")
    raise Failure, "domain coverage inventory differs" unless
      domains.is_a?(Array) && domains.length == DOMAINS.length &&
        domains.map { |record| record.fetch("domain") } == DOMAINS
    domains.each do |record|
      exact_fields(record, %w[domain operations], "domain coverage row")
      validate_operations(record.fetch("operations"))
    end

    intents = coverage.fetch("intent_families")
    raise Failure, "intent coverage inventory differs" unless
      intents.is_a?(Array) && intents.length == INTENTS.length &&
        intents.map { |record| record.fetch("intent") } == INTENTS
    intents.each do |record|
      raise Failure, "intent disposition differs" unless record == {
        "disposition" => "pinned_minimum_pending_P15_verification",
        "intent" => record.fetch("intent")
      }
    end

    validate_operations(coverage.fetch("unknown_domain"))
    raise Failure, "coverage limitations differ" unless
      coverage.fetch("limitations") == LIMITATIONS
    true
  rescue KeyError, TypeError => error
    raise Failure, "malformed coverage: #{error.class}"
  end

  def validate_operations(operations)
    raise Failure, "coverage operation dispositions differ" unless operations == {
      "action" => {
        "capability" => nil,
        "disposition" => "abstain_without_required_action_contracts"
      },
      "catalog_presence" => {
        "capability" => "ha_catalog:presence",
        "disposition" => "supported"
      },
      "state_query" => {
        "capability" => nil,
        "disposition" => "abstain_without_reviewed_descriptor"
      }
    }
    true
  end

  def validate_schema(schema)
    raise Failure, "coverage schema identity differs" unless
      schema["$schema"] == "https://json-schema.org/draft/2020-12/schema" &&
        schema["$id"] ==
          "https://local.invalid/schemas/ha-domain-coverage-v1.schema.json" &&
        schema["type"] == "object" &&
        schema["additionalProperties"] == false &&
        schema.dig("properties", "schema_version", "const") == 1 &&
        schema.dig("properties", "domains", "minItems") == DOMAINS.length &&
        schema.dig("properties", "domains", "maxItems") == DOMAINS.length &&
        schema.dig("properties", "intent_families", "minItems") == INTENTS.length &&
        schema.dig("properties", "intent_families", "maxItems") == INTENTS.length
    true
  end

  def validate_dependencies(root)
    workspace = File.binread(File.join(root, "Cargo.toml"))
    raise Failure, "ha-catalog is absent from workspace" unless
      workspace.include?('"crates/ha-catalog"')

    manifest = File.binread(File.join(root, "crates/ha-catalog/Cargo.toml"))
    raise Failure, "ha-catalog package identity differs" unless
      manifest.include?('name = "ha-catalog"') &&
        manifest.include?('name = "ha_catalog"')
    dependencies = manifest
      .split("[dependencies]", 2)
      .fetch(1, "")
      .lines
      .map(&:strip)
      .reject(&:empty?)
      .map { |line| line.split("=", 2).fetch(0).strip }
    raise Failure, "ha-catalog dependency set differs" unless
      dependencies.sort == %w[lang-ptbr nlu-core]
    true
  rescue Errno::ENOENT, IndexError
    raise Failure, "ha-catalog manifest is missing or malformed"
  end

  def validate_production_isolation(root)
    paths = Dir[File.join(root, "crates/ha-catalog/src/*.rs")].sort
    expected = %w[coverage error lib model resolve snapshot store].map do |name|
      File.join(root, "crates/ha-catalog/src/#{name}.rs")
    end
    raise Failure, "ha-catalog source module inventory differs" unless paths == expected

    validate_runtime_bytes(
      paths.to_h { |path| [path.delete_prefix("#{root}/"), File.binread(path)] }
    )
    true
  end

  def validate_runtime_bytes(files)
    files.each do |path, bytes|
      raise Failure, "unsafe code in #{path}" if
        bytes.match?(/\bunsafe\s*(?:\{|fn\b|impl\b|trait\b|extern\b)/)
      FORBIDDEN_RUNTIME.each do |name, pattern|
        raise Failure, "#{name} in #{path}" if bytes.match?(pattern)
      end
    end
    true
  end

  def validate_fixture_policy(root)
    test_paths = Dir[File.join(root, "crates/ha-catalog/tests/**/*")].select do |path|
      File.file?(path)
    end.sort
    raise Failure, "P10 technical tests are missing" if test_paths.empty?
    bytes = test_paths.map { |path| File.binread(path) }.join
    raise Failure, "P10 tests lack FIXTURE_TECNICA labels" unless
      bytes.include?("FIXTURE_TECNICA")
    raise Failure, "P10 fixture path has a non-Rust payload" unless
      test_paths.all? { |path| path.end_with?(".rs") }
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
      next unless require_satisfied

      raise Failure, "requirement remains pending: #{id}" unless
        rows.fetch(0).end_with?("| SATISFIED |\n")
    end
    true
  end

  def run_cargo_checks(root)
    commands = [
      %w[fmt --all -- --check],
      %w[clippy -p ha-catalog --all-targets --all-features -- -D warnings],
      %w[test --locked -p ha-catalog --all-features],
      %w[build --locked -p ha-catalog --all-targets --all-features]
    ]
    tool_bin = File.join(root, ".tools/rust-1.98.0/bin")
    commands.each do |arguments|
      output, status = Open3.capture2e(
        deterministic_environment(root),
        File.join(tool_bin, "cargo"),
        *arguments,
        chdir: root
      )
      next if status.success?

      warn output
      raise Failure, "P10 Cargo check failed: cargo #{arguments.join(' ')}"
    end
    true
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
      "CARGO_TARGET_DIR" => File.join(root, "target/p10-gate"),
      "RUSTC" => File.join(tool_bin, "rustc"),
      "RUSTDOC" => File.join(tool_bin, "rustdoc")
    }
  end

  def read_canonical_json(root, relative)
    bytes = File.binread(File.join(root, relative))
    value = parse_json(bytes, relative)
    raise Failure, "#{relative} is not canonical with one final newline" unless
      bytes == canonical_json(value) + "\n"
    value
  end

  def read_json(root, relative)
    parse_json(File.binread(File.join(root, relative)), relative)
  end

  def read_yaml(root, relative)
    parse_yaml(File.binread(File.join(root, relative)), relative)
  end

  def parse_json(bytes, context)
    JSON.parse(bytes, object_class: DuplicateRejectingHash, max_nesting: 64)
  rescue JSON::ParserError, JSON::NestingError, DuplicateKey => error
    raise Failure, "invalid JSON in #{context}: #{error.class}"
  end

  def parse_yaml(bytes, context)
    stream = Psych.parse_stream(bytes, context)
    raise Failure, "YAML document count differs: #{context}" unless
      stream.children.length == 1
    reject_yaml_aliases_and_duplicates(stream, context)
    value = Psych.safe_load(
      bytes,
      permitted_classes: [],
      permitted_symbols: [],
      aliases: false,
      filename: context
    )
    raise Failure, "YAML root is not a mapping: #{context}" unless value.is_a?(Hash)
    value
  rescue Psych::Exception, SystemStackError => error
    raise Failure, "invalid YAML in #{context}: #{error.class}"
  end

  def reject_yaml_aliases_and_duplicates(node, context, depth = 0)
    raise Failure, "YAML nesting is excessive: #{context}" if depth > 64
    raise Failure, "YAML aliases are prohibited: #{context}" if
      node.is_a?(Psych::Nodes::Alias)
    if node.is_a?(Psych::Nodes::Mapping)
      keys = {}
      node.children.each_slice(2) do |key, value|
        raise Failure, "non-scalar YAML key: #{context}" unless
          key.is_a?(Psych::Nodes::Scalar)
        raise Failure, "duplicate YAML key: #{context}" if keys.key?(key.value)
        keys[key.value] = true
        reject_yaml_aliases_and_duplicates(value, context, depth + 1)
      end
    elsif node.respond_to?(:children)
      Array(node.children).each do |child|
        reject_yaml_aliases_and_duplicates(child, context, depth + 1)
      end
    end
    true
  end

  def canonical_json(value)
    JSON.generate(canonicalize(value))
  end

  def canonicalize(value)
    case value
    when Hash
      value.keys.sort.to_h { |key| [key, canonicalize(value.fetch(key))] }
    when Array
      value.map { |item| canonicalize(item) }
    else
      value
    end
  end

  def exact_fields(value, fields, context)
    raise Failure, "#{context} fields differ" unless
      value.is_a?(Hash) && value.keys.sort == fields.sort
    true
  end
end

P10Validation.run(ARGV) if $PROGRAM_NAME == __FILE__
