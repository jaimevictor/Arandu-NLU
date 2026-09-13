# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

module P11Validation
  class Failure < StandardError; end
  class DuplicateKey < StandardError; end

  class DuplicateRejectingHash < Hash
    def []=(key, value)
      raise DuplicateKey, key if key?(key)

      super
    end
  end

  ROOT = File.expand_path("..", __dir__)
  SEMANTIC_SCHEMA = "schemas/p11-semantic-plan-v1.schema.json"
  REPORT_SCHEMA = "schemas/p11-plan-evaluation-report-v1.schema.json"
  P09_PROJECTION = "data/evaluation/p09/intent-v1/projection.json"
  P11_PROJECTION = "data/evaluation/p11/plan-v1/projection.json"
  P02_MANIFEST = "data/project-authored/p02-v1/manifest.json"
  P11_MANIFEST = "data/project-authored/p11-v1/manifest.json"

  ARTIFACTS = {
    P09_PROJECTION => [
      8_275, "5f661bb96b85667a1d0c9ec4d85cb61c443e1b24ab4dfc6c1ab849c6df936ee4"
    ],
    P11_PROJECTION => [
      3_414, "581b852b8cd2ec24b4c02b8c68914b27a928d953470a10665357e50425783f75"
    ],
    "data/project-authored/p02-v1/train.jsonl" => [
      1_257_443, "23d2bc8c8fcde80d1a9560d42219484bc34e9198c791ccadf5d4b56413a81b64"
    ],
    "data/project-authored/p02-v1/development.jsonl" => [
      1_300_259, "75400570ddfc7196ed982da98dcf49c4e6bda5820200a2fefd93a8ea6f049161"
    ],
    P02_MANIFEST => [
      11_091, "a251485ba2f8d5032603200b7e171954213383aeceac9a8f394edb09a265e72a"
    ],
    "data/project-authored/p02-v1/suites/ambiguity.jsonl" => [
      3_663, "098051c102bfdf9ede0781d8c1069546cb2db1d9265b4d1e2b3d2123ea1c7721"
    ],
    "data/project-authored/p02-v1/suites/contradiction.jsonl" => [
      3_792, "9a2c53626b74ad0479fd81bd91d0a41a027db2eb53eb37b6efcc2066a67689a8"
    ],
    "data/project-authored/p11-v1/specification.json" => [
      4_780, "4fcb15395026ad4c543ba4739c48e2ebe371a959c546c7ced39c3010a7b34b7a"
    ],
    "tools/generate-p11-corpus.rb" => [
      36_199, "5180fc5020390846ac06a844a067f3b7f54ee7f78fccc3a2ba51744167e32735"
    ],
    "data/project-authored/p11-v1/train.jsonl" => [
      6_613, "8b00c1af9aedb2ff6c946bf24c0a538b97ee8f9f882a4da901b91ba9f4432b8d"
    ],
    "data/project-authored/p11-v1/development.jsonl" => [
      6_743, "daca8033117351caee07ac9697ab49877ca240f896985418c6c7325680772675"
    ],
    P11_MANIFEST => [
      2_513, "946c6b096a7d9040bb85c6419c91b64d950f39f25ea85433827b54455aaf8822"
    ],
    SEMANTIC_SCHEMA => [
      8_571, "612c12f58afbadf7bff54dcda31e1fd5278edad40506b5683e5fd2cb453351c7"
    ],
    REPORT_SCHEMA => [
      12_055, "018499a30b06233956d366f6b3eb72096047dc1d842f3909753bb99c4afbdd0c"
    ]
  }.freeze

  SPLITS = %w[train development].freeze
  FORBIDDEN_SPLITS = %w[heldout test validation holdout].freeze
  TOTAL_RECORDS = 963
  P02_RECORDS = 960
  P11_RECORDS = 3
  PLAN_RECORDS = 962
  MAX_REPORT_BYTES = 256 * 1024

  P02_HASHES = {
    "train" => "23d2bc8c8fcde80d1a9560d42219484bc34e9198c791ccadf5d4b56413a81b64",
    "development" =>
      "75400570ddfc7196ed982da98dcf49c4e6bda5820200a2fefd93a8ea6f049161"
  }.freeze
  P11_HASHES = {
    "train" => "8b00c1af9aedb2ff6c946bf24c0a538b97ee8f9f882a4da901b91ba9f4432b8d",
    "development" =>
      "daca8033117351caee07ac9697ab49877ca240f896985418c6c7325680772675"
  }.freeze

  PROJECTION_LIMITATIONS = %w[
    project_authored_internal_conformance_not_independent_accuracy
    typed_evidence_is_a_pre_composer_mechanical_projection
    development_results_do_not_authorize_runtime_rule_changes
    heldout_not_accessed
    graph_class_does_not_authorize_execution
  ].freeze
  REPORT_LIMITATIONS = %w[
    project_authored_internal_conformance_only
    not_independent_language_accuracy
    p02_and_p11_sources_reported_separately
    no_heldout_access
    graph_execution_class_is_not_execution_authority
    no_acceptance_threshold_defined
  ].freeze
  GRAPH_MATCH_FIELDS = %w[
    intent
    capability
    operation
    entity_slot_value
    integer_slot_value
    text_slot_value
    typed_evidence_span
    polarity
    relation_evidence
    independence
    argument_share
    execution_class
    canonical_bytes
  ].freeze
  GRAPH_STRATA = [
    ["p02", "ordered_pair", "ordered_pair", "plan", 48],
    ["p02", "parallel_pair", "parallel_pair", "plan", 48],
    ["p02", "single", "single", "plan", 864],
    [
      "p11_negation", "ambiguous_shared_scope", "negation_scope_abstention",
      "abstention", 1
    ],
    [
      "p11_negation", "clear_first_node_negation", "negated_parallel_pair",
      "plan", 1
    ],
    [
      "p11_negation", "clear_second_node_negation", "negated_parallel_pair",
      "plan", 1
    ]
  ].freeze
  CONTRADICTION_CLASSES = %w[
    opposite_actions_same_target
    incompatible_positions
    start_and_cancel_timer
    cyclic_order
    state_action_conflict
  ].freeze
  AMBIGUITY_CLASSES = %w[
    duplicate_entity_alias
    duplicate_area_alias
    unresolved_pronoun
    multiple_timers
    coordination_scope
  ].freeze
  COVERAGE_REQUIREMENT_BINDINGS = {
    "P11-MULTI-012" => {
      "evidence" => "p02_train_development_graph_strata",
      "graph_shapes" => %w[parallel_pair ordered_pair]
    },
    "P11-MULTI-013" => {
      "evidence" => "p02_ambiguity_suite_inventory",
      "classes" => %w[coordination_scope]
    },
    "P11-MULTI-015" => {
      "evidence" => "p02_contradiction_suite_inventory",
      "classes" => CONTRADICTION_CLASSES
    }
  }.freeze

  REQUIREMENTS = (
    %w[GLB-INTENT-002] +
    (1..15).map { |number| format("P11-MULTI-%03d", number) }
  ).freeze

  PLAN_ENGINE_FILES = %w[
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
  PLAN_EVAL_FILES = (
    %w[catalog engine_adapter error evaluator lib oracle schema].map do |name|
      "crates/plan-eval/src/#{name}.rs"
    end +
    %w[frozen gold templates].map { |name| "crates/plan-eval/src/oracle/#{name}.rs" } +
    %w[plan-evaluate].map { |name| "crates/plan-eval/src/bin/#{name}.rs" }
  ).freeze

  FORBIDDEN_RUNTIME = {
    "ambient environment" => /\bstd::env\b|\benv!\s*\(|\boption_env!\s*\(/,
    "filesystem" => /\bstd::fs\b|\bread_dir\s*\(|File::open/,
    "network" => /\bstd::net\b|TcpStream|UdpSocket/,
    "process" => /\bstd::process\b|Command::new/,
    "time" => /\bstd::time\b|SystemTime|Instant::now/,
    "entropy" => /\brand::|\bgetrandom\b|thread_rng/,
    "unordered collection" => /\bHashMap\b|\bHashSet\b/,
    "global mutable state" => /static\s+mut|OnceLock|LazyLock/,
    "serialization authority" => /\bserde(?:_json)?\b/,
    "runtime artifact import" => /include_(?:bytes|str)!\s*\(/,
    "protocol dependency" => /\bprotocol\b/,
    "evaluation dependency" => /\bplan[_-]eval\b/,
    "execution authority" => /\bservice_call\b|\bexecute_operation\b/,
    "credential material" => /\bcredential\b|\bpassword\b|\baccess_token\b|\bapi_key\b|\bsecret\b/,
    "diagnostic sink" => /\bprintln!\s*\(|\beprintln!\s*\(|\btracing::|\blog::/
  }.freeze

  SCHEMA_KEYWORDS = %w[
    $schema
    $id
    $ref
    $defs
    title
    type
    const
    enum
    required
    properties
    additionalProperties
    items
    minItems
    maxItems
    minLength
    maxLength
    pattern
    minimum
    maximum
    oneOf
  ].freeze

  module_function

  def run(arguments)
    arguments = arguments.dup
    no_cargo = arguments.delete("--no-cargo")
    review_candidate = arguments.delete("--review-candidate")
    unless arguments.empty?
      raise Failure, "usage: tools/validate-p11 [--no-cargo] [--review-candidate]"
    end

    validate(
      ROOT,
      run_cargo: !no_cargo && !review_candidate,
      require_satisfied: !review_candidate
    )
    puts(review_candidate ? "P11_REVIEW_CANDIDATE_PASS" : "P11_GATE_PASS")
  rescue Failure => error
    warn "P11_GATE_FAIL: #{error.message}"
    exit 1
  end

  def validate(root, run_cargo:, require_satisfied:)
    validate_frozen_artifacts(root)
    semantic_schema = read_json(root, SEMANTIC_SCHEMA)
    report_schema = read_json(root, REPORT_SCHEMA)
    validate_schema_document(
      semantic_schema,
      id: "https://local.invalid/schemas/p11-semantic-plan-v1.schema.json",
      context: "P11 semantic-plan schema"
    )
    validate_semantic_schema_contract(semantic_schema)
    validate_schema_document(
      report_schema,
      id: "https://local.invalid/schemas/p11-plan-evaluation-report-v1.schema.json",
      context: "P11 report schema"
    )
    validate_report_schema_contract(report_schema)

    projection = read_json(root, P11_PROJECTION)
    validate_projection(projection)
    validate_p02_suite_coverage(read_json(root, P02_MANIFEST), projection)
    validate_manifest(read_json(root, P11_MANIFEST))
    privacy_canaries = validate_supplement(root, semantic_schema)
    validate_dependencies(root)
    validate_production_isolation(root)
    validate_evaluator_source_contract(root)
    validate_requirements(root, require_satisfied: require_satisfied)
    run_cargo_checks(root, report_schema, privacy_canaries) if run_cargo
    true
  end

  def validate_frozen_artifacts(root)
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

  def validate_schema_document(schema, id:, context:)
    exact_fields(
      schema,
      %w[$schema $id title type additionalProperties required properties $defs],
      context
    )
    raise Failure, "#{context} draft differs" unless
      schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    raise Failure, "#{context} identity differs" unless schema["$id"] == id
    audit_schema_node(schema, schema, context)
    true
  end

  def audit_schema_node(node, root, context)
    raise Failure, "#{context} node is not an object" unless node.is_a?(Hash)
    unknown = node.keys - SCHEMA_KEYWORDS
    raise Failure, "#{context} has unsupported schema keywords" unless unknown.empty?

    if node.key?("$ref")
      raise Failure, "#{context} reference has sibling keywords" unless node.keys == ["$ref"]
      resolve_schema_ref(root, node.fetch("$ref"), context)
      return true
    end

    if node.key?("type")
      raise Failure, "#{context} type differs" unless
        %w[object array string integer boolean].include?(node["type"])
    end
    if node["type"] == "object"
      properties = node["properties"]
      required = node["required"]
      raise Failure, "#{context} object is open" unless
        node["additionalProperties"] == false
      raise Failure, "#{context} object properties are malformed" unless
        properties.is_a?(Hash) && required.is_a?(Array) &&
          required.sort == properties.keys.sort
      properties.each do |name, child|
        audit_schema_node(child, root, "#{context}.#{name}")
      end
    end
    if node["type"] == "array"
      raise Failure, "#{context} array bounds are malformed" unless
        node["items"].is_a?(Hash) &&
          node["minItems"].is_a?(Integer) &&
          node["maxItems"].is_a?(Integer) &&
          node["minItems"].between?(0, node["maxItems"])
      audit_schema_node(node["items"], root, "#{context}[]")
    end
    if node["type"] == "string" && !node.key?("const") && !node.key?("enum")
      raise Failure, "#{context} string bounds are malformed" unless
        node["minLength"].is_a?(Integer) &&
          node["maxLength"].is_a?(Integer) &&
          node["minLength"].between?(0, node["maxLength"])
    end
    if node["type"] == "integer"
      raise Failure, "#{context} integer bounds are malformed" unless
        node["minimum"].is_a?(Integer) &&
          node["maximum"].is_a?(Integer) &&
          node["minimum"] <= node["maximum"]
    end
    if node.key?("enum")
      raise Failure, "#{context} enum is malformed" unless
        node["enum"].is_a?(Array) && !node["enum"].empty? &&
          node["enum"].uniq.length == node["enum"].length
    end
    if node.key?("oneOf")
      raise Failure, "#{context} oneOf is malformed" unless
        node["oneOf"].is_a?(Array) && node["oneOf"].length >= 2
      node["oneOf"].each_with_index do |child, index|
        audit_schema_node(child, root, "#{context}.oneOf[#{index}]")
      end
    end
    if node.key?("$defs")
      raise Failure, "#{context} definitions are malformed" unless
        node["$defs"].is_a?(Hash) && !node["$defs"].empty?
      node["$defs"].each do |name, child|
        audit_schema_node(child, root, "#{context}.$defs.#{name}")
      end
    end
    true
  end

  def resolve_schema_ref(root, reference, context)
    prefix = "#/$defs/"
    raise Failure, "#{context} has a non-local reference" unless reference.start_with?(prefix)
    name = reference.delete_prefix(prefix)
    definition = root.fetch("$defs", {})[name]
    raise Failure, "#{context} has an unresolved reference" unless definition.is_a?(Hash)

    definition
  end

  def validate_semantic_schema_contract(schema)
    raise Failure, "semantic schema version contract differs" unless
      schema.dig("properties", "schema_version", "const") ==
        "p11-semantic-plan-v1"
    raise Failure, "semantic node limit differs" unless
      schema.dig("properties", "nodes", "minItems") == 1 &&
        schema.dig("properties", "nodes", "maxItems") == 64
    raise Failure, "semantic relation limits differ" unless
      schema.dig("properties", "relations", "maxItems") == 256 &&
        schema.dig("properties", "independent_pairs", "maxItems") == 256 &&
        schema.dig("properties", "argument_shares", "maxItems") == 256
    raise Failure, "semantic evidence limits differ" unless
      schema.dig("$defs", "node", "properties", "evidence", "maxItems") == 64 &&
        schema.dig("$defs", "relation", "properties", "evidence", "maxItems") == 64 &&
        schema.dig("$defs", "argument_share", "properties", "evidence", "maxItems") == 64
    raise Failure, "semantic execution classes differ" unless
      schema.dig("properties", "execution_class", "enum") ==
        %w[partial_safe atomic_only non_executable]
    true
  end

  def validate_report_schema_contract(schema)
    raise Failure, "report schema runner contract differs" unless
      schema.dig("properties", "schema_version", "const") == 1 &&
        schema.dig("properties", "runner_id", "const") == "plan-eval-v1"
    raise Failure, "report schema split contract differs" unless
      schema.dig("$defs", "split", "enum") == SPLITS
    raise Failure, "report schema denominator bound differs" unless
      schema.dig("$defs", "count", "maximum") == TOTAL_RECORDS
    raise Failure, "report schema stratum bound differs" unless
      schema.dig("$defs", "results", "properties", "graph_strata", "minItems") ==
        GRAPH_STRATA.length &&
        schema.dig("$defs", "results", "properties", "graph_strata", "maxItems") ==
          GRAPH_STRATA.length
    comparison = schema.dig("$defs", "comparison_contract", "properties")
    raise Failure, "report schema threshold contract differs" unless
      comparison.dig("acceptance_threshold", "const").nil? &&
        comparison.fetch("acceptance_threshold").key?("const") &&
        comparison.dig("canonical_bytes_required", "const") == true &&
        comparison.dig("full_graph_fields", "const") == GRAPH_MATCH_FIELDS
    raise Failure, "report schema limitations differ" unless
      schema.dig("properties", "limitations", "const") == REPORT_LIMITATIONS
    true
  end

  def validate_instance(value, schema, root_schema, context)
    if schema.key?("$ref")
      return validate_instance(
        value,
        resolve_schema_ref(root_schema, schema.fetch("$ref"), context),
        root_schema,
        context
      )
    end
    if schema.key?("oneOf")
      matches = schema.fetch("oneOf").count do |candidate|
        begin
          validate_instance(value, candidate, root_schema, context)
          true
        rescue Failure
          false
        end
      end
      raise Failure, "#{context} does not match exactly one schema branch" unless matches == 1
    end
    if schema.key?("const")
      raise Failure, "#{context} constant differs" unless value == schema["const"]
    end
    if schema.key?("enum")
      raise Failure, "#{context} is outside the closed enum" unless
        schema["enum"].include?(value)
    end

    case schema["type"]
    when "object"
      raise Failure, "#{context} is not an object" unless value.is_a?(Hash)
      missing = schema.fetch("required") - value.keys
      extra = value.keys - schema.fetch("properties").keys
      raise Failure, "#{context} fields differ" unless missing.empty? && extra.empty?
      schema.fetch("properties").each do |name, child|
        validate_instance(value.fetch(name), child, root_schema, "#{context}.#{name}")
      end
    when "array"
      raise Failure, "#{context} is not an array" unless value.is_a?(Array)
      raise Failure, "#{context} array length differs" unless
        value.length.between?(schema.fetch("minItems"), schema.fetch("maxItems"))
      value.each_with_index do |item, index|
        validate_instance(item, schema.fetch("items"), root_schema, "#{context}[#{index}]")
      end
    when "string"
      raise Failure, "#{context} is not a string" unless value.is_a?(String)
      if schema.key?("minLength")
        raise Failure, "#{context} string length differs" unless
          value.length.between?(schema.fetch("minLength"), schema.fetch("maxLength"))
      end
      if schema.key?("pattern")
        pattern = Regexp.new(schema.fetch("pattern"), Regexp::NOENCODING)
        raise Failure, "#{context} string pattern differs" unless pattern.match?(value)
      end
    when "integer"
      raise Failure, "#{context} is not an integer" unless value.is_a?(Integer)
      raise Failure, "#{context} integer range differs" unless
        value.between?(schema.fetch("minimum"), schema.fetch("maximum"))
    when "boolean"
      raise Failure, "#{context} is not a boolean" unless
        value == true || value == false
    end
    true
  end

  def validate_projection(projection)
    exact_fields(
      projection,
      %w[
        schema_version projection_id semantic_plan_schema source
        pre_resolution_projection catalog_projection evidence_projection
        graph_shapes limitations
      ],
      "P11 projection"
    )
    raise Failure, "P11 projection identity differs" unless
      projection["schema_version"] == 1 &&
        projection["projection_id"] == "p11-semantic-plan-oracle-projection-v1" &&
        projection["semantic_plan_schema"] == "p11-semantic-plan-v1" &&
        projection["limitations"] == PROJECTION_LIMITATIONS
    raise Failure, "P11 projection source differs" unless
      projection["source"] == {
        "source_id" => "project-authored-synthetic-ptbr-v1",
        "corpus_version" => "1.0.0",
        "generator_id" => "p02-generator-v1",
        "oracle_origin" => "pre_engine_generator_specification",
        "specification_sha256" =>
          "f72451f03d1a5e2e4955b5d2857bd7d33b3b012912d920e53a3d85719f14859d",
        "generator_sha256" =>
          "ff8817afc2c2f13d539ab7d10720cab407d769ca3a6189dcc55d43ea052689d1",
        "train_sha256" => P02_HASHES.fetch("train"),
        "development_sha256" => P02_HASHES.fetch("development"),
        "records_per_split" => P02_RECORDS,
        "claim_scope" => "internal_conformance_only"
      }
    raise Failure, "P11 pre-resolution binding differs" unless
      projection["pre_resolution_projection"] == {
        "path" => P09_PROJECTION,
        "sha256" => ARTIFACTS.fetch(P09_PROJECTION).fetch(1)
      }
    raise Failure, "P11 catalog projection differs" unless
      projection["catalog_projection"] == {
        "generation" => 1,
        "registry_id_algorithm" =>
          "sha256(p11-catalog-v1-nul || external_entity_id_utf8)[0:32]",
        "core_entity_id_prefix" => "ha_entity:id_",
        "mention_source" => "pre_resolution_parameter_exact_utf8_span",
        "display_matching_allowed" => false,
        "nlu_output_allowed" => false
      }
    raise Failure, "P11 evidence projection differs" unless
      projection["evidence_projection"] == {
        "argument" => "pre_resolution_parameter_exact_utf8_span",
        "single_predicate" => "trimmed_initial_template_literal_before_first_parameter",
        "parallel_predicate" => "shared_trimmed_initial_template_literal_before_first_parameter",
        "normalization_allowed" => false,
        "nlu_output_allowed" => false
      }
    validate_graph_shapes(projection.fetch("graph_shapes"))
    true
  rescue KeyError, TypeError => error
    raise Failure, "malformed P11 projection: #{error.class}"
  end

  def validate_graph_shapes(shapes)
    expected = [
      {
        "shape" => "single",
        "node_ids" => ["p11:node_1"],
        "execution_class" => "partial_safe",
        "relations" => [],
        "independent_pairs" => [],
        "argument_shares" => []
      },
      {
        "shape" => "parallel_pair",
        "required_external_intent" => "HassTurnOn",
        "node_ids" => %w[p11:node_1 p11:node_2],
        "slot_occurrences" => [0, 1],
        "execution_class" => "atomic_only",
        "relations" => [],
        "independent_pairs" => [
          {"left" => "p11:node_1", "right" => "p11:node_2"}
        ],
        "argument_shares" => []
      },
      {
        "shape" => "ordered_pair",
        "required_external_intent" => "HassStartTimer",
        "node_ids" => %w[p11:node_1 p11:node_2],
        "execution_class" => "partial_safe",
        "secondary_capability" => "ha:timer_control",
        "secondary_operation" => "ha:timer_status",
        "secondary_predicate_cues" => {
          "train" => "consulte o estado",
          "development" => "verifique o estado"
        },
        "relation_cues" => {
          "train" => "e consulte o estado depois",
          "development" => "e então verifique o estado"
        },
        "relations" => [
          {"from" => "p11:node_1", "to" => "p11:node_2", "kind" => "precedes"}
        ],
        "independent_pairs" => [],
        "argument_shares" => [
          {
            "from_node" => "p11:node_1",
            "from_slot" => "ha:timer",
            "to_node" => "p11:node_2",
            "to_slot" => "ha:timer",
            "evidence" => "source_argument"
          }
        ]
      }
    ]
    raise Failure, "P11 graph-shape projection differs" unless shapes == expected
    true
  end

  def validate_p02_suite_coverage(manifest, projection)
    exact_fields(
      manifest,
      %w[
        schema_version corpus contract freeze quotas taxonomies artifacts
      ],
      "P02 source manifest"
    )
    corpus = manifest.fetch("corpus")
    raise Failure, "P02 source identity differs" unless
      manifest["schema_version"] == 1 &&
        corpus["id"] == "project-authored-synthetic-ptbr-v1" &&
        corpus["version"] == "1.0.0" &&
        corpus["status"] == "PROJECT_AUTHORED_SYNTHETIC" &&
        corpus["authorization"] == "USR-016" &&
        corpus["license"] == "Apache-2.0" &&
        corpus["claim_scope"] == "internal_conformance_only" &&
        corpus["generator_id"] == "p02-generator-v1" &&
        corpus["oracle_origin"] == "pre_engine_generator_specification" &&
        corpus["specification_sha256"] ==
          "f72451f03d1a5e2e4955b5d2857bd7d33b3b012912d920e53a3d85719f14859d" &&
        corpus["generator_sha256"] ==
          "ff8817afc2c2f13d539ab7d10720cab407d769ca3a6189dcc55d43ea052689d1"
    freeze = manifest.fetch("freeze")
    raise Failure, "P02 source freeze differs" unless
      freeze["state"] == "FROZEN_PRE_IMPLEMENTATION" &&
        freeze["before_nlu_implementation"] == true &&
        freeze["self_oracle_allowed"] == false

    suite_classes = manifest.dig("taxonomies", "suite_classes")
    raise Failure, "P02 contradiction inventory differs" unless
      suite_classes.fetch("contradiction") == CONTRADICTION_CLASSES
    raise Failure, "P02 ambiguity inventory differs" unless
      suite_classes.fetch("ambiguity") == AMBIGUITY_CLASSES

    expected_artifacts = {
      "suites/ambiguity.jsonl" => {
        "path" => "suites/ambiguity.jsonl",
        "bytes" => 3_663,
        "sha256" =>
          "098051c102bfdf9ede0781d8c1069546cb2db1d9265b4d1e2b3d2123ea1c7721",
        "records" => 5
      },
      "suites/contradiction.jsonl" => {
        "path" => "suites/contradiction.jsonl",
        "bytes" => 3_792,
        "sha256" =>
          "9a2c53626b74ad0479fd81bd91d0a41a027db2eb53eb37b6efcc2066a67689a8",
        "records" => 5
      }
    }
    artifacts = manifest.fetch("artifacts")
    expected_artifacts.each do |relative, expected|
      matches = artifacts.select { |artifact| artifact["path"] == relative }
      raise Failure, "P02 suite artifact count differs: #{relative}" unless
        matches.length == 1
      raise Failure, "P02 suite artifact binding differs: #{relative}" unless
        matches.fetch(0) == expected
      validate_admitted_suite_path(
        "data/project-authored/p02-v1/#{relative}"
      )
    end

    graph_shapes = projection.fetch("graph_shapes").map { |shape| shape.fetch("shape") }
    bindings = COVERAGE_REQUIREMENT_BINDINGS
    raise Failure, "P11 coordination coverage binding differs" unless
      bindings.dig("P11-MULTI-012", "graph_shapes").all? do |shape|
        graph_shapes.include?(shape)
      end
    raise Failure, "P11 scope coverage binding differs" unless
      bindings.dig("P11-MULTI-013", "classes") == ["coordination_scope"] &&
        AMBIGUITY_CLASSES.include?("coordination_scope")
    raise Failure, "P11 conflict coverage binding differs" unless
      bindings.dig("P11-MULTI-015", "classes") == CONTRADICTION_CLASSES &&
        CONTRADICTION_CLASSES.include?("cyclic_order") &&
        CONTRADICTION_CLASSES.any? { |name| name.include?("conflict") } &&
        CONTRADICTION_CLASSES.any? { |name| name.include?("actions") }
    raise Failure, "P11 suite coverage requirement inventory differs" unless
      bindings.keys.sort == %w[P11-MULTI-012 P11-MULTI-013 P11-MULTI-015]
    true
  rescue KeyError, TypeError => error
    raise Failure, "malformed P02 suite coverage manifest: #{error.class}"
  end

  def validate_admitted_suite_path(path)
    admitted = %w[
      data/project-authored/p02-v1/suites/ambiguity.jsonl
      data/project-authored/p02-v1/suites/contradiction.jsonl
    ]
    raise Failure, "non-admitted P02 suite path: #{path}" unless admitted.include?(path)
    true
  end

  def validate_manifest(manifest)
    exact_fields(
      manifest,
      %w[
        schema_version corpus freeze bindings counts required_coverage outputs
      ],
      "P11 supplement manifest"
    )
    corpus = manifest.fetch("corpus")
    raise Failure, "P11 corpus identity differs" unless
      corpus == {
        "id" => "project-authored-synthetic-ptbr-p11-negation-v1",
        "version" => "1.0.0",
        "status" => "PROJECT_AUTHORED_SYNTHETIC",
        "source_id" => "project-authored-synthetic-ptbr-p11-negation-v1",
        "generator_id" => "p11-negation-generator-v1",
        "oracle_origin" => "pre_p11_composer_generator_specification",
        "oracle_authorizations" => %w[USR-016 USER_EXPLICIT_2026-08-28],
        "oracle_derivation" => "specification_only_no_nlu_output",
        "license" => "Apache-2.0",
        "locale" => "pt-BR",
        "claim_scope" => "internal_conformance_only"
      }
    freeze = manifest.fetch("freeze")
    raise Failure, "P11 pre-composer freeze differs" unless
      freeze["state"] == "FROZEN_PRE_P11_COMPOSER" &&
        freeze["before_p11_plan_composer_implementation"] == true &&
        freeze["specification_precedes_generated_rows"] == true &&
        freeze["nlu_output_used_as_oracle"] == false &&
        freeze["family_disjoint"] == true &&
        freeze["text_disjoint"] == true &&
        freeze["semantic_identity_disjoint"] == true &&
        freeze["target_identity_disjoint"] == true
    raise Failure, "P11 source bindings differ" unless
      manifest.fetch("bindings") == {
        "specification" => {
          "path" => "data/project-authored/p11-v1/specification.json",
          "bytes" => 4_780,
          "sha256" =>
            "4fcb15395026ad4c543ba4739c48e2ebe371a959c546c7ced39c3010a7b34b7a"
        },
        "generator" => {
          "path" => "tools/generate-p11-corpus.rb",
          "bytes" => 36_199,
          "sha256" =>
            "5180fc5020390846ac06a844a067f3b7f54ee7f78fccc3a2ba51744167e32735"
        }
      }
    raise Failure, "P11 supplement counts differ" unless
      manifest.fetch("counts") == {
        "total_records" => 6,
        "by_split" => {"train" => 3, "development" => 3},
        "by_outcome" => {"plan" => 4, "abstention" => 2},
        "by_stratum" => {
          "clear_first_node_negation" => 2,
          "clear_second_node_negation" => 2,
          "ambiguous_shared_scope" => 2
        }
      }
    required_strata = %w[
      clear_first_node_negation
      clear_second_node_negation
      ambiguous_shared_scope
    ]
    raise Failure, "P11 required coverage differs" unless
      manifest.fetch("required_coverage") == {
        "strata" => required_strata,
        "by_split" => {
          "train" => required_strata,
          "development" => required_strata
        }
      }
    expected_outputs = SPLITS.map do |split|
      relative = "data/project-authored/p11-v1/#{split}.jsonl"
      {
        "path" => "#{split}.jsonl",
        "bytes" => ARTIFACTS.fetch(relative).fetch(0),
        "sha256" => ARTIFACTS.fetch(relative).fetch(1),
        "records" => P11_RECORDS
      }
    end
    raise Failure, "P11 supplement outputs differ" unless
      manifest.fetch("outputs") == expected_outputs
    true
  rescue KeyError, TypeError => error
    raise Failure, "malformed P11 manifest: #{error.class}"
  end

  def validate_supplement(root, semantic_schema)
    privacy_canaries = []
    SPLITS.each do |split|
      relative = "data/project-authored/p11-v1/#{split}.jsonl"
      rows = parse_jsonl(File.binread(File.join(root, relative)), P11_RECORDS, relative)
      strata = []
      case_ids = []
      semantic_ids = []
      rows.each do |row|
        exact_fields(
          row,
          %w[
            schema_version case_id generator_record_id canonical_semantic_id
            specification_id specification_version source_id source_type corpus_id
            corpus_version generator_id oracle_origin oracle_authorizations
            oracle_derivation license locale claim_scope split family stratum
            utterance utterance_sha256 context expected
          ],
          "P11 supplement row"
        )
        raise Failure, "P11 supplement row identity differs" unless
          row["schema_version"] == 1 &&
            row["generator_record_id"] == "generator-#{row['case_id']}" &&
            sha256?(row["canonical_semantic_id"]) &&
            row["specification_id"] ==
              "p11-multi-intent-negation-specification-v1" &&
            row["specification_version"] == "1.0.0" &&
            row["source_id"] == "project-authored-synthetic-ptbr-p11-negation-v1" &&
            row["source_type"] == "PROJECT_AUTHORED_SYNTHETIC" &&
            row["corpus_id"] == row["source_id"] &&
            row["corpus_version"] == "1.0.0" &&
            row["generator_id"] == "p11-negation-generator-v1" &&
            row["oracle_origin"] == "pre_p11_composer_generator_specification" &&
            row["oracle_authorizations"] == %w[USR-016 USER_EXPLICIT_2026-08-28] &&
            row["oracle_derivation"] == "specification_only_no_nlu_output" &&
            row["license"] == "Apache-2.0" &&
            row["locale"] == "pt-BR" &&
            row["claim_scope"] == "internal_conformance_only" &&
            row["split"] == split &&
            row["family"].start_with?("p11-#{split}-") &&
            row["family"].end_with?("-v1") &&
            Digest::SHA256.hexdigest(row["utterance"].b) == row["utterance_sha256"]
        raise Failure, "P11 supplement text is not valid UTF-8" unless
          row["utterance"].encoding == Encoding::UTF_8 && row["utterance"].valid_encoding?
        raise Failure, "duplicate P11 supplement case" if case_ids.include?(row["case_id"])
        raise Failure, "duplicate P11 supplement semantic ID" if
          semantic_ids.include?(row["canonical_semantic_id"])
        case_ids << row["case_id"]
        semantic_ids << row["canonical_semantic_id"]
        strata << row["stratum"]
        privacy_canaries << row["utterance"]
        validate_supplement_context(row)
        validate_supplement_expected(row, semantic_schema)
      end
      raise Failure, "P11 supplement strata differ: #{split}" unless
        strata.sort == %w[
          ambiguous_shared_scope
          clear_first_node_negation
          clear_second_node_negation
        ]
    end
    privacy_canaries.freeze
  end

  def validate_supplement_context(row)
    context = row.fetch("context")
    exact_fields(context, %w[catalog_generation entities], "P11 supplement context")
    raise Failure, "P11 supplement catalog generation differs" unless
      context["catalog_generation"] == 1 &&
        context["entities"].is_a?(Array) &&
        context["entities"].length == 2
    registry_ids = []
    context["entities"].each do |entity|
      exact_fields(
        entity,
        %w[registry_id entity_id catalog_generation mention],
        "P11 supplement entity"
      )
      raise Failure, "P11 supplement entity differs" unless
        entity["registry_id"].match?(/\A[0-9a-f]{32}\z/) &&
          entity["entity_id"] == "ha_entity:id_#{entity['registry_id']}" &&
          entity["catalog_generation"] == 1 &&
          !entity["mention"].empty? &&
          row["utterance"].scan(entity["mention"]).length == 1
      raise Failure, "duplicate P11 supplement entity" if
        registry_ids.include?(entity["registry_id"])
      registry_ids << entity["registry_id"]
    end
    true
  rescue KeyError, TypeError => error
    raise Failure, "malformed P11 supplement context: #{error.class}"
  end

  def validate_supplement_expected(row, semantic_schema)
    expected = row.fetch("expected")
    case row.fetch("stratum")
    when "ambiguous_shared_scope"
      raise Failure, "P11 ambiguous-scope oracle differs" unless
        expected == {"outcome" => "abstention", "reason" => "negation_scope"}
    when "clear_first_node_negation", "clear_second_node_negation"
      exact_fields(expected, %w[outcome intent plan], "P11 plan oracle")
      raise Failure, "P11 plan outcome differs" unless
        expected["outcome"] == "plan" && expected["intent"] == "HassTurnOn"
      plan = expected.fetch("plan")
      validate_semantic_plan(
        plan,
        semantic_schema,
        "P11 supplement semantic plan",
        source: row.fetch("utterance")
      )
      entities = row.dig("context", "entities")
      values = plan.fetch("nodes").map do |node|
        node.fetch("slots").fetch(0).fetch("value").fetch("id")
      end
      raise Failure, "P11 semantic entity projection differs" unless
        values == entities.map { |entity| entity.fetch("entity_id") }
    else
      raise Failure, "P11 supplement has an unknown stratum"
    end
    true
  rescue KeyError, TypeError, NoMethodError => error
    raise Failure, "malformed P11 supplement expected value: #{error.class}"
  end

  def validate_semantic_plan(plan, schema, context, source: nil)
    validate_instance(plan, schema, schema, context)
    nodes = plan.fetch("nodes")
    node_ids = nodes.map { |node| node.fetch("id") }
    raise Failure, "#{context} node order or uniqueness differs" unless
      node_ids == node_ids.sort && node_ids.uniq.length == node_ids.length
    node_index = nodes.to_h { |node| [node.fetch("id"), node] }

    nodes.each do |node|
      slots = node.fetch("slots")
      slot_ids = slots.map { |slot| slot.fetch("id") }
      raise Failure, "#{context} slot order or uniqueness differs" unless
        slot_ids == slot_ids.sort && slot_ids.uniq.length == slot_ids.length
      slots.each do |slot|
        if slot["kind"] == "entity"
          raise Failure, "#{context} entity generation differs" unless
            slot.dig("value", "catalog_generation") == plan["catalog_generation"]
        end
      end

      evidence = node.fetch("evidence")
      keys = evidence.map do |atom|
        [
          {"predicate" => 0, "argument" => 1, "negation" => 2}.fetch(atom["kind"]),
          atom.fetch("slot", ""),
          atom.fetch("begin_byte"),
          atom.fetch("end_byte")
        ]
      end
      raise Failure, "#{context} evidence order or uniqueness differs" unless
        keys == keys.sort && keys.uniq.length == keys.length
      evidence.each do |atom|
        validate_span(atom, context, source)
        if atom["kind"] == "argument" && !slot_ids.include?(atom["slot"])
          raise Failure, "#{context} has dangling argument evidence"
        end
      end
      predicates = evidence.count { |atom| atom["kind"] == "predicate" }
      negations = evidence.count { |atom| atom["kind"] == "negation" }
      raise Failure, "#{context} predicate evidence differs" unless predicates >= 1
      raise Failure, "#{context} polarity evidence differs" unless
        (node["polarity"] == "negated" && negations >= 1) ||
          (node["polarity"] == "affirmed" && negations.zero?)
    end

    relations = plan.fetch("relations")
    relation_keys = relations.map { |value| [value["from"], value["to"], value["kind"]] }
    raise Failure, "#{context} relation order or uniqueness differs" unless
      relation_keys == relation_keys.sort && relation_keys.uniq.length == relation_keys.length
    relations.each do |relation|
      validate_node_endpoint(node_index, relation["from"], context)
      validate_node_endpoint(node_index, relation["to"], context)
      raise Failure, "#{context} has a self relation" if
        relation["from"] == relation["to"]
      relation["evidence"].each { |span| validate_span(span, context, source) }
    end

    pairs = plan.fetch("independent_pairs")
    pair_keys = pairs.map { |pair| [pair["left"], pair["right"]] }
    raise Failure, "#{context} independent-pair order or uniqueness differs" unless
      pair_keys == pair_keys.sort && pair_keys.uniq.length == pair_keys.length
    pairs.each do |pair|
      validate_node_endpoint(node_index, pair["left"], context)
      validate_node_endpoint(node_index, pair["right"], context)
      raise Failure, "#{context} independent pair is not canonical" unless
        pair["left"] < pair["right"]
      if relation_keys.any? do |from, to, _kind|
           [from, to].sort == [pair["left"], pair["right"]]
         end
        raise Failure, "#{context} pair is both related and independent"
      end
    end

    shares = plan.fetch("argument_shares")
    share_keys = shares.map do |share|
      [share["from_node"], share["from_slot"], share["to_node"], share["to_slot"]]
    end
    raise Failure, "#{context} share order or uniqueness differs" unless
      share_keys == share_keys.sort && share_keys.uniq.length == share_keys.length
    destinations = []
    shares.each do |share|
      from = validate_slot_endpoint(node_index, share["from_node"], share["from_slot"], context)
      to = validate_slot_endpoint(node_index, share["to_node"], share["to_slot"], context)
      raise Failure, "#{context} share value differs" unless from["value"] == to["value"]
      destination = [share["to_node"], share["to_slot"]]
      raise Failure, "#{context} duplicate share destination" if
        destinations.include?(destination)
      destinations << destination
      share["evidence"].each { |span| validate_span(span, context, source) }
    end

    nodes.each do |node|
      node["slots"].each do |slot|
        direct = node["evidence"].count do |atom|
          atom["kind"] == "argument" && atom["slot"] == slot["id"]
        end
        inbound = shares.count do |share|
          share["to_node"] == node["id"] && share["to_slot"] == slot["id"]
        end
        raise Failure, "#{context} slot support differs" unless
          (direct == 1 && inbound.zero?) || (direct.zero? && inbound == 1)
      end
    end

    node_ids.combination(2) do |left, right|
      related = relation_keys.any? do |from, to, _kind|
        [from, to].sort == [left, right]
      end
      independent = pair_keys.include?([left, right])
      raise Failure, "#{context} node pair classification differs" unless
        related ^ independent
    end
    validate_acyclic(node_ids, relation_keys.map { |from, to, _kind| [from, to] }, context)
    validate_acyclic(
      node_ids,
      shares.map { |share| [share["from_node"], share["to_node"]] },
      context
    )

    expected_class = if nodes.any? { |node| node["polarity"] == "negated" }
                       "non_executable"
                     elsif pairs.empty?
                       "partial_safe"
                     else
                       "atomic_only"
                     end
    raise Failure, "#{context} execution class differs" unless
      plan["execution_class"] == expected_class
    aggregate = nodes.length + nodes.sum { |node| node["slots"].length + node["evidence"].length }
    aggregate += relations.length + relations.sum { |value| value["evidence"].length }
    aggregate += pairs.length + shares.length + shares.sum { |value| value["evidence"].length }
    raise Failure, "#{context} aggregate limit exceeded" if aggregate > 4_096
    raise Failure, "#{context} encoded limit exceeded" if
      canonical_json(plan).bytesize + 1 > 65_536
    true
  end

  def validate_node_endpoint(index, node_id, context)
    raise Failure, "#{context} has a dangling node endpoint" unless index.key?(node_id)
    true
  end

  def validate_slot_endpoint(index, node_id, slot_id, context)
    validate_node_endpoint(index, node_id, context)
    slot = index.fetch(node_id).fetch("slots").find { |value| value["id"] == slot_id }
    raise Failure, "#{context} has a dangling slot endpoint" unless slot
    slot
  end

  def validate_span(span, context, source)
    start = span.fetch("begin_byte")
    finish = span.fetch("end_byte")
    raise Failure, "#{context} has an empty or reversed span" unless start < finish
    return true unless source

    bytes = source.b
    raise Failure, "#{context} span exceeds its source" unless finish <= bytes.bytesize
    prefix = bytes.byteslice(0, start).dup.force_encoding(Encoding::UTF_8)
    slice = bytes.byteslice(start, finish - start).dup.force_encoding(Encoding::UTF_8)
    raise Failure, "#{context} span is not on UTF-8 boundaries" unless
      prefix.valid_encoding? && slice.valid_encoding?
    true
  end

  def validate_acyclic(nodes, edges, context)
    outgoing = nodes.to_h { |node| [node, []] }
    edges.each { |from, to| outgoing.fetch(from) << to }
    state = {}
    visit = lambda do |node|
      raise Failure, "#{context} graph contains a cycle" if state[node] == :active
      return if state[node] == :done

      state[node] = :active
      outgoing.fetch(node).each { |target| visit.call(target) }
      state[node] = :done
    end
    nodes.each { |node| visit.call(node) }
    true
  end

  def validate_dependencies(root)
    workspace = File.binread(File.join(root, "Cargo.toml"))
    %w[plan-engine plan-eval].each do |name|
      member = %("#{File.join("crates", name)}")
      raise Failure, "#{name} workspace registration differs" unless
        workspace.scan(member).length == 1
    end

    engine_manifest = File.binread(File.join(root, "crates/plan-engine/Cargo.toml"))
    eval_manifest = File.binread(File.join(root, "crates/plan-eval/Cargo.toml"))
    raise Failure, "plan-engine package identity differs" unless
      engine_manifest.include?("name = \"plan-engine\"") &&
        engine_manifest.include?("name = \"plan_engine\"")
    raise Failure, "plan-eval package identity differs" unless
      eval_manifest.include?("name = \"plan-eval\"") &&
        eval_manifest.include?("name = \"plan_eval\"") &&
        eval_manifest.include?("name = \"plan-evaluate\"")
    raise Failure, "plan-engine dependency set differs" unless
      manifest_dependencies(engine_manifest) ==
        %w[ha-catalog intent-engine lang-ptbr nlu-core]
    raise Failure, "plan-eval dependency set differs" unless
      manifest_dependencies(eval_manifest) ==
        %w[ha-catalog intent-engine nlu-core nlu-data plan-engine serde serde_json]

    production_manifests = %w[
      ha-catalog
      intent-engine
      lang-ptbr
      nlu-core
      plan-engine
      protocol
    ].map { |name| "crates/#{name}/Cargo.toml" }
    production_manifests.each do |relative|
      bytes = File.binread(File.join(root, relative))
      raise Failure, "plan-eval is a production dependency: #{relative}" if
        bytes.match?(/\bplan-eval\b|\bplan_eval\b/)
    end

    lock = File.binread(File.join(root, "Cargo.lock"))
    raise Failure, "plan-engine lock dependency set differs" unless
      lock_dependencies(lock, "plan-engine") ==
        %w[ha-catalog intent-engine lang-ptbr nlu-core]
    raise Failure, "plan-eval lock dependency set differs" unless
      lock_dependencies(lock, "plan-eval") ==
        %w[ha-catalog intent-engine nlu-core nlu-data plan-engine serde serde_json]
    true
  rescue Errno::ENOENT, IndexError
    raise Failure, "P11 workspace manifest or lock is missing"
  end

  def manifest_dependencies(bytes)
    section = bytes.split("[dependencies]", 2).fetch(1, "")
    section = section.split(/^\[/, 2).fetch(0, "")
    section.lines.each_with_object([]) do |line, dependencies|
      stripped = line.sub(/#.*/, "").strip
      next if stripped.empty?

      dependencies << stripped.split("=", 2).fetch(0).strip.sub(/\.workspace\z/, "")
    end.sort
  end

  def lock_dependencies(bytes, package)
    section = bytes.split("[[package]]").find do |candidate|
      candidate.match?(/^name = "#{Regexp.escape(package)}"$/)
    end
    raise Failure, "lock package is missing: #{package}" unless section
    body = section[/dependencies = \[\n(.*?)\n\]/m, 1]
    return [] unless body

    body.lines.map { |line| line.strip.delete_prefix('"').delete_suffix('",') }.sort
  end

  def validate_production_isolation(root)
    actual = Dir[File.join(root, "crates/plan-engine/src/*.rs")].sort.map do |path|
      path.delete_prefix("#{root}/")
    end
    raise Failure, "plan-engine source inventory differs" unless actual == PLAN_ENGINE_FILES
    validate_runtime_bytes(
      actual.to_h { |relative| [relative, File.binread(File.join(root, relative))] }
    )
    test_paths = Dir[File.join(root, "crates/plan-engine/tests/**/*")].select do |path|
      File.file?(path)
    end.sort
    raise Failure, "plan-engine technical tests are missing" if test_paths.empty?
    raise Failure, "plan-engine fixture path has a non-Rust payload" unless
      test_paths.all? { |path| path.end_with?(".rs") }
    test_bytes = test_paths.map { |path| File.binread(path) }.join
    raise Failure, "plan-engine tests lack FIXTURE_TECNICA labels" unless
      test_bytes.include?("FIXTURE_TECNICA")
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

  def validate_evaluator_source_contract(root)
    actual = Dir[File.join(root, "crates/plan-eval/src/**/*.rs")].sort.map do |path|
      path.delete_prefix("#{root}/")
    end
    raise Failure, "plan-eval source inventory differs" unless actual == PLAN_EVAL_FILES.sort
    files = actual.to_h { |relative| [relative, File.binread(File.join(root, relative))] }
    bytes = files.values.join
    raise Failure, "plan-eval permits unsafe code" unless bytes.include?("#![forbid(unsafe_code)]")
    raise Failure, "plan-eval lacks strict JSON parsing" unless
      bytes.include?("parse_strict_json") && bytes.include?("deny_unknown_fields")
    raise Failure, "plan-eval report output can overwrite an existing file" unless
      bytes.include?(".create_new(true)")
    raise Failure, "plan-eval lacks closed split parsing" unless
      bytes.include?('"train" => Some(Self::Train)') &&
        bytes.include?('"development" => Some(Self::Development)') &&
        bytes.include?("invalid split")
    expected_paths = %w[
      data/project-authored/p02-v1/development.jsonl
      data/project-authored/p02-v1/train.jsonl
      data/project-authored/p11-v1/development.jsonl
      data/project-authored/p11-v1/train.jsonl
    ]
    paths = bytes.scan(%r{data/project-authored/p(?:02|11)-v1/[A-Za-z0-9_.-]+}).uniq.sort
    raise Failure, "plan-eval dataset path inventory differs" unless paths == expected_paths
    paths.each { |path| validate_admitted_dataset_path(path) }
    raise Failure, "plan-eval projection binding differs" unless
      bytes.include?(P09_PROJECTION) && bytes.include?(P11_PROJECTION)
    REPORT_LIMITATIONS.each do |limitation|
      raise Failure, "plan-eval limitation is missing: #{limitation}" unless
        bytes.include?(limitation)
    end
    true
  end

  def validate_admitted_dataset_path(path)
    admitted = SPLITS.flat_map do |split|
      [
        "data/project-authored/p02-v1/#{split}.jsonl",
        "data/project-authored/p11-v1/#{split}.jsonl"
      ]
    end
    raise Failure, "non-admitted evaluation dataset path: #{path}" unless
      admitted.include?(path)
    true
  end

  def validate_split_name(split)
    raise Failure, "non-admitted evaluation split: #{split}" unless SPLITS.include?(split)
    split
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

  def run_cargo_checks(root, report_schema, privacy_canaries)
    generator = File.join(root, "tools/generate-p11-corpus")
    run_checked(
      root,
      [generator, "--check"],
      "P11 frozen supplement reproduction"
    )
    cargo = File.join(root, ".tools/rust-1.98.0/bin/cargo")
    commands = [
      [
        "focused format",
        %w[
          fmt
          --package nlu-core
          --package protocol
          --package plan-engine
          --package plan-eval
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
          -p protocol
          -p plan-engine
          -p plan-eval
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
          -p nlu-core
          -p protocol
          -p plan-engine
          -p plan-eval
          --all-features
        ]
      ],
      [
        "locked builds",
        %w[
          build
          --locked
          -p nlu-core
          -p protocol
          -p plan-engine
          -p plan-eval
          --all-targets
          --all-features
        ]
      ]
    ]
    commands.each do |label, arguments|
      run_checked(root, [cargo, *arguments], "P11 #{label}")
    end
    run_evaluations(root, report_schema, privacy_canaries)
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

  def run_evaluations(root, report_schema, privacy_canaries)
    binary = File.join(root, "target/p11-gate/debug/plan-evaluate")
    raise Failure, "P11 evaluator binary is missing" unless File.file?(binary)
    reports = []
    Dir.mktmpdir("p11-reports-", File.join(root, "target")) do |directory|
      SPLITS.each do |split|
        first_path = File.join(directory, "#{split}-first.json")
        second_path = File.join(directory, "#{split}-second.json")
        run_evaluator(root, binary, split, first_path, expect_success: true)
        run_evaluator(root, binary, split, second_path, expect_success: true)
        first = File.binread(first_path)
        second = File.binread(second_path)
        raise Failure, "P11 report replay differs: #{split}" unless first == second
        report = validate_report_bytes(
          first,
          report_schema,
          split,
          privacy_canaries: privacy_canaries
        )
        reports << report
      end
      FORBIDDEN_SPLITS.each do |split|
        output = File.join(directory, "forbidden-#{split}.json")
        run_evaluator(root, binary, split, output, expect_success: false)
        raise Failure, "forbidden split created a report: #{split}" if File.exist?(output)
      end
    end
    first_identity = reports.fetch(0).fetch("recognizer")
    raise Failure, "recognizer identity differs by split" unless
      reports.all? { |report| report.fetch("recognizer") == first_identity }
    true
  end

  def run_evaluator(root, binary, split, output, expect_success:)
    arguments = [
      binary,
      "--root", root,
      "--split", split,
      "--output", output
    ]
    command_output, status = Open3.capture2e(
      deterministic_environment(root),
      *arguments,
      chdir: root
    )
    if expect_success
      raise Failure, "P11 evaluator failed for #{split}" unless status.success?
      raise Failure, "P11 evaluator success output differs" unless
        command_output == "PLAN_EVALUATE_PASS\n"
    else
      raise Failure, "P11 evaluator accepted forbidden split: #{split}" if status.success?
      raise Failure, "P11 evaluator rejection leaked private data" if
        command_output.bytesize > 1_024 || !command_output.ascii_only?
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
      "CARGO_TARGET_DIR" => File.join(root, "target/p11-gate"),
      "RUSTC" => File.join(tool_bin, "rustc"),
      "RUSTDOC" => File.join(tool_bin, "rustdoc")
    }
  end

  def validate_report_bytes(bytes, schema, split, privacy_canaries:)
    raise Failure, "P11 report exceeds its byte limit" if bytes.bytesize > MAX_REPORT_BYTES
    raise Failure, "P11 report lacks exactly one final newline" unless
      bytes.end_with?("\n") && !bytes.end_with?("\n\n")
    report = parse_json(bytes, "P11 #{split} evaluation report")
    raise Failure, "P11 report is not canonical" unless
      bytes == canonical_json(report) + "\n"
    validate_report(
      report,
      schema,
      split,
      privacy_canaries: privacy_canaries,
      encoded_bytes: bytes
    )
    report
  end

  def validate_report(report, schema, split, privacy_canaries:, encoded_bytes: nil)
    validate_split_name(split)
    validate_instance(report, schema, schema, "P11 evaluation report")
    raise Failure, "P11 report split differs" unless report["split"] == split
    expected_sources = [
      {
        "source_id" => "project-authored-synthetic-ptbr-v1",
        "source_type" => "PROJECT_AUTHORED_SYNTHETIC",
        "corpus_version" => "1.0.0",
        "generator_id" => "p02-generator-v1",
        "oracle_origin" => "pre_engine_generator_specification",
        "claim_scope" => "internal_conformance_only",
        "split" => split,
        "physical_sha256" => P02_HASHES.fetch(split),
        "records" => P02_RECORDS
      },
      {
        "source_id" => "project-authored-synthetic-ptbr-p11-negation-v1",
        "source_type" => "PROJECT_AUTHORED_SYNTHETIC",
        "corpus_version" => "1.0.0",
        "generator_id" => "p11-negation-generator-v1",
        "oracle_origin" => "pre_p11_composer_generator_specification",
        "claim_scope" => "internal_conformance_only",
        "split" => split,
        "physical_sha256" => P11_HASHES.fetch(split),
        "records" => P11_RECORDS
      }
    ]
    raise Failure, "P11 report source identities differ" unless
      report["sources"] == expected_sources
    raise Failure, "P11 report projection identities differ" unless
      report["projections"] == {
        "pre_resolution_projection_id" => "p09-pre-resolution-oracle-projection-v1",
        "pre_resolution_projection_sha256" => ARTIFACTS.fetch(P09_PROJECTION).fetch(1),
        "plan_projection_id" => "p11-semantic-plan-oracle-projection-v1",
        "plan_projection_sha256" => ARTIFACTS.fetch(P11_PROJECTION).fetch(1)
      }
    raise Failure, "P11 report comparison contract differs" unless
      report["comparison_contract"] == {
        "outcome_fields" => %w[outcome_kind abstention_reason],
        "full_graph_fields" => GRAPH_MATCH_FIELDS,
        "canonical_bytes_required" => true,
        "acceptance_threshold" => nil
      }
    raise Failure, "P11 report limitations differ" unless
      report["limitations"] == REPORT_LIMITATIONS
    validate_report_results(report.fetch("results"))
    validate_report_privacy(
      report,
      privacy_canaries,
      encoded_bytes || canonical_json(report)
    )
    true
  end

  def validate_report_results(results)
    raise Failure, "P11 report source counts differ" unless
      results["source_counts"] == {
        "p02" => P02_RECORDS,
        "p11_negation" => P11_RECORDS,
        "total" => TOTAL_RECORDS
      }
    raise Failure, "P11 expected-outcome counts differ" unless
      results["expected_outcomes"] == {
        "plans" => PLAN_RECORDS,
        "abstentions" => 1
      }
    validate_outcome_totals(results.fetch("recognizer_outcomes"), TOTAL_RECORDS, "recognizer")
    validate_outcome_totals(results.fetch("composer_outcomes"), TOTAL_RECORDS, "composer")
    {
      "intent_exact" => TOTAL_RECORDS,
      "outcome_exact" => TOTAL_RECORDS,
      "graph_exact" => PLAN_RECORDS,
      "canonical_bytes_exact" => PLAN_RECORDS,
      "exact_semantics" => TOTAL_RECORDS
    }.each do |name, denominator|
      metric = results.fetch(name)
      raise Failure, "P11 #{name} denominator differs" unless
        metric["denominator"] == denominator
      raise Failure, "P11 #{name} numerator exceeds its denominator" unless
        metric["numerator"].between?(0, denominator)
    end
    validate_report_strata(results)
    expected_reconciliation = {
      "records_expected" => TOTAL_RECORDS,
      "records_observed" => TOTAL_RECORDS,
      "source_total" => TOTAL_RECORDS,
      "expected_outcome_total" => TOTAL_RECORDS,
      "recognizer_outcome_total" => TOTAL_RECORDS,
      "composer_outcome_total" => TOTAL_RECORDS,
      "stratum_total" => TOTAL_RECORDS,
      "plan_graph_denominator" => PLAN_RECORDS,
      "graph_comparisons_accounted" => PLAN_RECORDS,
      "complete" => true
    }
    raise Failure, "P11 report reconciliation differs" unless
      results["reconciliation"] == expected_reconciliation
    true
  rescue KeyError, TypeError => error
    raise Failure, "malformed P11 report results: #{error.class}"
  end

  def validate_report_strata(results)
    strata = results.fetch("graph_strata")
    actual_keys = strata.map do |stratum|
      [
        stratum["source"],
        stratum["stratum"],
        stratum["graph_shape"],
        stratum["expected_outcome"],
        stratum["total"]
      ]
    end
    raise Failure, "P11 graph strata differ" unless actual_keys == GRAPH_STRATA
    metric_sums = Hash.new(0)
    recognizer_sums = Hash.new(0)
    composer_sums = Hash.new(0)
    strata.each do |stratum|
      total = stratum.fetch("total")
      %w[intent_exact outcome_exact graph_exact canonical_bytes_exact exact_semantics].each do |key|
        value = stratum.fetch(key)
        raise Failure, "P11 stratum metric exceeds its total" unless value.between?(0, total)
        metric_sums[key] += value
      end
      if stratum["expected_outcome"] == "abstention" &&
         (stratum["graph_exact"] != 0 || stratum["canonical_bytes_exact"] != 0)
        raise Failure, "P11 abstention stratum claims a graph comparison"
      end
      validate_outcome_totals(stratum.fetch("recognizer_outcomes"), total, "stratum recognizer")
      validate_outcome_totals(stratum.fetch("composer_outcomes"), total, "stratum composer")
      stratum["recognizer_outcomes"].each do |name, value|
        recognizer_sums[name] += value
      end
      stratum["composer_outcomes"].each do |name, value|
        composer_sums[name] += value
      end
    end
    %w[intent_exact outcome_exact graph_exact canonical_bytes_exact exact_semantics].each do |key|
      raise Failure, "P11 aggregate metric does not reconcile: #{key}" unless
        metric_sums[key] == results.dig(key, "numerator")
    end
    raise Failure, "P11 recognizer strata do not reconcile" unless
      recognizer_sums == results.fetch("recognizer_outcomes")
    raise Failure, "P11 composer strata do not reconcile" unless
      composer_sums == results.fetch("composer_outcomes")
    true
  end

  def validate_outcome_totals(counts, expected, context)
    raise Failure, "P11 #{context} outcomes do not reconcile" unless
      counts.values.all? { |value| value.is_a?(Integer) && value >= 0 } &&
        counts.values.sum == expected
    true
  end

  def validate_report_privacy(report, privacy_canaries, bytes)
    forbidden_keys = %w[
      utterance
      request_text
      mention
      alias
      display_name
      external_entity_id
      source_path
      timestamp
    ]
    walk = lambda do |value|
      case value
      when Hash
        raise Failure, "P11 report contains a private-data field" unless
          (value.keys & forbidden_keys).empty?
        value.each_value { |child| walk.call(child) }
      when Array
        value.each { |child| walk.call(child) }
      when String
        raise Failure, "P11 report contains non-ASCII text" unless value.ascii_only?
        raise Failure, "P11 report string exceeds its privacy bound" if value.bytesize > 256
      end
    end
    walk.call(report)
    privacy_canaries.each do |canary|
      raise Failure, "P11 report contains a source utterance" if bytes.include?(canary)
    end
    raise Failure, "P11 report contains the technical privacy canary" if
      bytes.include?("FIXTURE_TECNICA_PRIVATE_CANARY")
    true
  end

  def read_json(root, relative)
    parse_json(File.binread(File.join(root, relative)), relative)
  end

  def parse_json(bytes, context)
    JSON.parse(bytes, object_class: DuplicateRejectingHash, max_nesting: 128)
  rescue JSON::ParserError, JSON::NestingError, DuplicateKey => error
    raise Failure, "invalid JSON in #{context}: #{error.class}"
  end

  def parse_jsonl(bytes, expected_records, context)
    raise Failure, "#{context} lacks one final newline" unless
      bytes.end_with?("\n") && !bytes.end_with?("\n\n")
    lines = bytes.lines(chomp: true)
    raise Failure, "#{context} record count differs" unless lines.length == expected_records
    lines.map.with_index do |line, index|
      raise Failure, "#{context} has a blank row" if line.empty?
      parse_json(line, "#{context}:#{index + 1}")
    end
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

  def sha256?(value)
    value.is_a?(String) && value.match?(/\A[0-9a-f]{64}\z/)
  end

  def exact_fields(value, fields, context)
    raise Failure, "#{context} fields differ" unless
      value.is_a?(Hash) && value.keys.sort == fields.sort
    true
  end
end

P11Validation.run(ARGV) if $PROGRAM_NAME == __FILE__
