# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "optparse"
require "tmpdir"

module P02V2Corpus
  class Failure < StandardError; end
  class DuplicateKeyError < StandardError; end

  class DuplicateRejectingHash < Hash
    def []=(key, value)
      raise DuplicateKeyError, key if key?(key)

      super
    end
  end

  ROOT = File.expand_path("..", __dir__)
  DATA_ROOT = File.join(ROOT, "data/project-authored/p02-v2")
  SPEC_PATH = File.join(DATA_ROOT, "specification.json")
  GENERATOR_PATH = File.expand_path(__FILE__)
  SPLITS = %w[train development heldout performance].freeze
  SUITE_IDS = %w[
    safety_sensitive
    contradiction
    ambiguity
    stale_state
    explicit_negative
  ].freeze
  ARTIFACT_PATHS = (
    SPLITS.map { |split| "#{split}.jsonl" } +
    SUITE_IDS.map { |suite| "suites/#{suite.tr('_', '-')}.jsonl" }
  ).freeze
  MANIFEST_PATH = "manifest.json"
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
  AREAS = %w[
    sala
    cozinha
    quarto
    escritorio
    corredor
    varanda
    garagem
    lavanderia
    biblioteca
    atelie
    copa
    despensa
    banheiro
    suite
    jardim
    porao
    sotao
    oficina
    estudio
    academia
  ].freeze
  EXPECTED_CORPUS = {
    "id" => "project-authored-synthetic-ptbr-p15-v2",
    "version" => "2.0.0",
    "status" => "PROJECT_AUTHORED_SYNTHETIC",
    "authorization" => "USR-045",
    "locale" => "pt-BR",
    "license" => "Apache-2.0",
    "claim_scope" => "internal_conformance_only",
    "generator_id" => "p02-qualification-generator-v2",
    "oracle_origin" => "pre_engine_generator_specification",
    "self_oracle_allowed" => false
  }.freeze
  EXPECTED_FREEZE = {
    "state" => "FROZEN_PRE_REMEDIATION",
    "sequence" => "P15_P02_V2_PRE_REMEDIATION_FREEZE",
    "authorized_after_commit" => "c93f0dc67103cb50383c03225463c8c32b07577a",
    "authorized_after_tree" => "54d27771c1300ba6a245ff96156c60b569d1d4c2",
    "chronology" => "AFTER_AUTHORIZATION_COMMIT_BEFORE_REMEDIATION_IMPLEMENTATION",
    "behavior_change_boundary" => "BEFORE_REMEDIATION_IMPLEMENTATION",
    "heldout_access_after_freeze" => "SEALED_AGGREGATE_RUNNER_ONLY",
    "performance_access_after_freeze" => "SEALED_AGGREGATE_RUNNER_ONLY",
    "prior_release_split_access" => "PROHIBITED",
    "self_oracle_allowed" => false
  }.freeze
  EXPECTED_SEMANTIC_CONTRACT = {
    "catalog_generation" => 22,
    "node_namespace" => "p02v2",
    "identifier_namespace" => "p02v2",
    "expected_plan_outcome" => "plan"
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

  module_function

  def parse_json(bytes, context)
    raise Failure, "#{context} is not valid UTF-8" unless
      bytes.dup.force_encoding(Encoding::UTF_8).valid_encoding?

    JSON.parse(
      bytes,
      object_class: DuplicateRejectingHash,
      array_class: Array,
      create_additions: false,
      max_nesting: 64
    )
  rescue JSON::ParserError, DuplicateKeyError => error
    raise Failure, "invalid #{context}: #{error.class}"
  end

  def load_spec(path = SPEC_PATH)
    value = parse_json(File.binread(path), "specification JSON")
    raise Failure, "specification root must be a mapping" unless value.is_a?(Hash)

    value
  end

  def exact_keys!(mapping, keys, context)
    raise Failure, "#{context} must be a mapping" unless mapping.is_a?(Hash)
    return if mapping.keys.sort == keys.sort

    raise Failure, "#{context} fields differ: #{mapping.keys.sort.inspect}"
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

  def canonical_sha(value)
    sha256(JSON.generate(canonicalize(value)))
  end

  def slug(value)
    value
      .gsub(/([a-z0-9])([A-Z])/, '\1_\2')
      .downcase
      .gsub(/[^a-z0-9]+/, "_")
      .gsub(/\A_+|_+\z/, "")
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

  def validate_generalization!(spec, intent)
    templates = intent.fetch("templates")
    contract = spec.fetch("generalization_contract")
    train_tokens = templates.fetch("train").flat_map do |template|
      static_tokens(template)
    end
    generic_tokens = contract.fetch("generic_ptbr_function_words").flat_map do |word|
      static_tokens(word)
    end
    paradigm_tokens = contract
      .fetch("intent_inflectional_paradigms")
      .fetch(intent.fetch("intent"))
      .flat_map { |word| static_tokens(word) }
    observed = (train_tokens + generic_tokens + paradigm_tokens).uniq
    hidden = templates.fetch("heldout") + templates.fetch("performance")
    unseen = hidden.flat_map { |template| static_tokens(template) }.uniq - observed
    raise Failure, "hidden template has unseen static tokens" unless unseen.empty?

    train = templates.fetch("train")
    raise Failure, "hidden template duplicates a train template" unless
      (hidden & train).empty?
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
        home_assistant_contract
        semantic_contract
        quotas
        dimensions
        split_policy
        generalization_contract
        intents
        fail_closed_suites
      ],
      "specification"
    )
    raise Failure, "unsupported specification version" unless
      spec.fetch("schema_version") == 2
    raise Failure, "corpus contract differs" unless
      spec.fetch("corpus") == EXPECTED_CORPUS
    raise Failure, "freeze contract differs" unless
      spec.fetch("freeze") == EXPECTED_FREEZE
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
        case_id_disjoint
        generator_record_id_disjoint
        canonical_semantic_id_disjoint
        family_partition_disjoint
        text_disjoint
        semantic_payload_disjoint
        performance_derived_from_heldout_coverage_only
        freeze_before_remediation_implementation
        heldout_access_after_freeze
        performance_access_after_freeze
        text_lineage_marker
        identifier_namespace
        prior_lineage_separation
      ],
      "split policy"
    )
    boolean_fields = %w[
      case_id_disjoint
      generator_record_id_disjoint
      canonical_semantic_id_disjoint
      family_partition_disjoint
      text_disjoint
      semantic_payload_disjoint
      performance_derived_from_heldout_coverage_only
      freeze_before_remediation_implementation
    ]
    raise Failure, "split disjointness contract differs" unless
      boolean_fields.all? { |field| split_policy.fetch(field) == true }
    raise Failure, "split access contract differs" unless
      split_policy.fetch("heldout_access_after_freeze") ==
        "SEALED_AGGREGATE_RUNNER_ONLY" &&
      split_policy.fetch("performance_access_after_freeze") ==
        "SEALED_AGGREGATE_RUNNER_ONLY" &&
      split_policy.fetch("identifier_namespace") == "p02v2" &&
      split_policy.fetch("prior_lineage_separation") ==
        "CONSTRUCTION_WITHOUT_PRIOR_RELEASE_SPLIT_ACCESS"
    marker = split_policy.fetch("text_lineage_marker")
    raise Failure, "text lineage marker is invalid" unless
      marker.is_a?(String) && !marker.empty? && marker.valid_encoding?

    generalization = spec.fetch("generalization_contract")
    exact_keys!(
      generalization,
      %w[
        template_selection
        minimum_train_templates_per_intent
        hidden_template_static_tokens_must_be_train_observed
        hidden_template_must_not_equal_train_template
        slot_generation_contract_shared_across_splits
        no_unseen_synonym_in_hidden_splits
        generic_ptbr_function_words
        intent_inflectional_paradigms
      ],
      "generalization contract"
    )
    raise Failure, "generalization policy differs" unless
      generalization.fetch("template_selection") ==
        "DETERMINISTIC_INDEX_MODULO_TEMPLATE_COUNT" &&
      generalization.fetch("minimum_train_templates_per_intent") == 4 &&
      %w[
        hidden_template_static_tokens_must_be_train_observed
        hidden_template_must_not_equal_train_template
        slot_generation_contract_shared_across_splits
        no_unseen_synonym_in_hidden_splits
      ].all? { |field| generalization.fetch(field) == true }
    generic_words = generalization.fetch("generic_ptbr_function_words")
    raise Failure, "generic function-word inventory is invalid" unless
      generic_words.is_a?(Array) && !generic_words.empty? &&
      generic_words.all? { |word| word.is_a?(String) && !word.empty? }

    intents = spec.fetch("intents")
    raise Failure, "intent taxonomy differs" unless
      intents.is_a?(Array) &&
      intents.map { |intent| intent.fetch("intent") } == OFFICIAL_INTENTS
    raise Failure, "intent taxonomy contains duplicate IDs" unless
      OFFICIAL_INTENTS.uniq.length == OFFICIAL_INTENTS.length
    paradigms = generalization.fetch("intent_inflectional_paradigms")
    raise Failure, "inflectional taxonomy differs" unless
      paradigms.keys == OFFICIAL_INTENTS

    families = []
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
      %w[intent domain capability operation primary_slot_kind case_kind
         target_noun graph_shape].each do |field|
        value = intent.fetch(field)
        raise Failure, "intent #{field} is invalid" unless
          value.is_a?(String) && !value.empty? && value.valid_encoding?
      end
      if intent.fetch("case_kind") == "timer_duration_ordered"
        raise Failure, "ordered timer secondary operation is invalid" unless
          intent.fetch("secondary_operation").is_a?(String) &&
          !intent.fetch("secondary_operation").empty?
      elsif !intent.fetch("secondary_operation").nil?
        raise Failure, "unexpected secondary operation"
      end
      raise Failure, "unknown case kind" unless
        PLACEHOLDERS.key?(intent.fetch("case_kind"))

      family_map = intent.fetch("families")
      exact_keys!(family_map, SPLITS, "intent families")
      family_map.each do |split, family|
        expected = "p02v2-#{split}-#{slug(intent.fetch('intent')).tr('_', '-')}-family"
        raise Failure, "family identity differs" unless family == expected
        families << family
      end

      templates = intent.fetch("templates")
      exact_keys!(templates, SPLITS, "intent templates")
      templates.each do |split, values|
        raise Failure, "template count differs" unless
          values.is_a?(Array) && values.length == TEMPLATE_COUNTS.fetch(split)
        values.each do |template|
          raise Failure, "template must be nonempty UTF-8" unless
            template.is_a?(String) && !template.empty? && template.valid_encoding?
          raise Failure, "template placeholders differ" unless
            template_placeholders(template) ==
              PLACEHOLDERS.fetch(intent.fetch("case_kind"))
        end
      end
      validate_generalization!(spec, intent)
    end
    raise Failure, "family identities are not globally unique" unless
      families.uniq.length == families.length

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
        classes << definition.fetch("coverage_class")
        suite_utterances << definition.fetch("utterance")
        suite_families << definition.fetch("family")
      end
      raise Failure, "suite classes are not unique" unless
        classes.uniq.length == classes.length
    end
    raise Failure, "suite utterances are not unique" unless
      suite_utterances.uniq.length == suite_utterances.length
    raise Failure, "suite families are not unique" unless
      suite_families.uniq.length == suite_families.length
  end

  def area_for(index)
    AREAS.fetch((index - 1) % AREAS.length)
  end

  def target_values(spec, intent, split, index, offset = 0)
    maximum = EXPECTED_QUOTAS.fetch("heldout_per_intent")
    adjusted = ((index - 1 + offset) % maximum) + 1
    area = area_for(adjusted)
    number = ((adjusted - 1) / AREAS.length) + 1
    intent_slug = slug(intent.fetch("intent"))
    generation = spec.fetch("semantic_contract").fetch("catalog_generation")
    {
      "text" => "#{intent.fetch('target_noun')} #{number} do setor #{area}",
      "entity_id" =>
        "#{intent.fetch('domain')}.p02v2_#{split}_#{intent_slug}_#{format('%03d', adjusted)}",
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

  def build_case_values(spec, intent, split, index)
    target = target_values(spec, intent, split, index)
    target2 = target_values(spec, intent, split, index, 120)
    marker = spec.fetch("split_policy").fetch("text_lineage_marker")
    pending = "pedido #{format('%03d', index)} do setor #{target.fetch('area')}"
    scope = "setor #{target.fetch('area')} #{format('%03d', index)}"
    message = "aviso #{format('%03d', index)} do setor #{target.fetch('area')}"
    parameters = {
      lineage: marker,
      target: target.fetch("text"),
      target2: target2.fetch("text"),
      position: (index - 1) % 101,
      seconds: index,
      scope: scope,
      pending: pending,
      message: message
    }
    [target, target2, parameters]
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
        integer_slot("ha:duration_delta_seconds", parameters.fetch(:seconds))
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
      raise Failure, "unknown case kind #{intent.fetch('case_kind')}"
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

  def build_semantic_case(spec, intent, split, index)
    corpus = spec.fetch("corpus")
    target, target2, parameters =
      build_case_values(spec, intent, split, index)
    templates = intent.fetch("templates").fetch(split)
    template = templates.fetch((index - 1) % templates.length)
    utterance = render_template(template, parameters)
    namespace = spec.fetch("semantic_contract").fetch("identifier_namespace")
    intent_slug = slug(intent.fetch("intent"))
    context = {
      "catalog_generation" =>
        spec.fetch("semantic_contract").fetch("catalog_generation"),
      "session_snapshot_id" =>
        "#{namespace}:#{split}_#{intent_slug}_#{format('%03d', index)}"
    }
    expected = expected_plan(spec, intent, target, target2, parameters)
    identity_payload = {"context" => context, "expected" => expected}
    record_id =
      "p02-v2-#{split}-#{intent_slug.tr('_', '-')}-#{format('%03d', index)}"

    {
      "schema_version" => 1,
      "case_id" => record_id,
      "generator_record_id" => "generator-#{record_id}",
      "canonical_semantic_id" => canonical_sha(identity_payload),
      "source_id" => corpus.fetch("id"),
      "corpus_version" => corpus.fetch("version"),
      "generator_id" => corpus.fetch("generator_id"),
      "oracle_origin" => corpus.fetch("oracle_origin"),
      "license" => corpus.fetch("license"),
      "locale" => corpus.fetch("locale"),
      "split" => split,
      "utterance" => utterance,
      "utterance_sha256" => sha256(utterance.encode(Encoding::UTF_8)),
      "context" => context,
      "dimensions" => {
        "source" => corpus.fetch("id"),
        "family" => intent.fetch("families").fetch(split),
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
    spec.fetch("intents").flat_map do |intent|
      (1..case_count(spec, split)).map do |index|
        build_semantic_case(spec, intent, split, index)
      end
    end
  end

  def build_suite_records(spec, suite_id)
    corpus = spec.fetch("corpus")
    generation = spec.fetch("semantic_contract").fetch("catalog_generation")
    spec.fetch("fail_closed_suites").fetch(suite_id).each_with_index.map do |definition, offset|
      index = offset + 1
      expected = {
        "outcome" => definition.fetch("expected_outcome"),
        "reason" => definition.fetch("reason")
      }
      context = {
        "condition" => definition.fetch("coverage_class"),
        "catalog_generation" =>
          suite_id == "stale_state" ? generation + 1 : generation
      }
      record_id =
        "p02-v2-suite-#{suite_id.tr('_', '-')}-#{format('%03d', index)}"
      utterance = definition.fetch("utterance")
      {
        "schema_version" => 1,
        "suite_id" => suite_id,
        "case_id" => record_id,
        "generator_record_id" => "generator-#{record_id}",
        "canonical_semantic_id" => canonical_sha(
          {
            "suite_id" => suite_id,
            "family" => definition.fetch("family"),
            "coverage_class" => definition.fetch("coverage_class"),
            "utterance" => utterance,
            "context" => context,
            "expected" => expected
          }
        ),
        "coverage_class" => definition.fetch("coverage_class"),
        "source_id" => corpus.fetch("id"),
        "corpus_version" => corpus.fetch("version"),
        "generator_id" => corpus.fetch("generator_id"),
        "oracle_origin" => corpus.fetch("oracle_origin"),
        "license" => corpus.fetch("license"),
        "locale" => corpus.fetch("locale"),
        "utterance" => utterance,
        "utterance_sha256" => sha256(utterance.encode(Encoding::UTF_8)),
        "context" => context,
        "expected" => expected
      }
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
    semantic_records = {}
    SPLITS.each do |split|
      records = build_semantic_records(spec, split)
      semantic_records[split] = records
      artifacts["#{split}.jsonl"] = json_lines(records)
    end
    SUITE_IDS.each do |suite_id|
      path = "suites/#{suite_id.tr('_', '-')}.jsonl"
      artifacts[path] = json_lines(build_suite_records(spec, suite_id))
    end
    [artifacts, semantic_records]
  end

  def artifact_record_count(bytes)
    bytes.lines.length
  end

  def build_manifest(spec, artifacts, semantic_records)
    corpus = spec.fetch("corpus")
    suites = spec.fetch("fail_closed_suites")
    {
      "schema_version" => 2,
      "corpus" => {
        "id" => corpus.fetch("id"),
        "version" => corpus.fetch("version"),
        "status" => corpus.fetch("status"),
        "authorization" => corpus.fetch("authorization"),
        "locale" => corpus.fetch("locale"),
        "license" => corpus.fetch("license"),
        "claim_scope" => corpus.fetch("claim_scope"),
        "generator_id" => corpus.fetch("generator_id"),
        "oracle_origin" => corpus.fetch("oracle_origin"),
        "specification_sha256" => sha256(File.binread(SPEC_PATH)),
        "generator_sha256" => sha256(File.binread(GENERATOR_PATH))
      },
      "contract" => spec.fetch("home_assistant_contract"),
      "semantic_contract" => spec.fetch("semantic_contract"),
      "freeze" => spec.fetch("freeze"),
      "split_policy" => spec.fetch("split_policy"),
      "generalization_contract_sha256" =>
        canonical_sha(spec.fetch("generalization_contract")),
      "quotas" => spec.fetch("quotas"),
      "taxonomies" => {
        "dimensions" => spec.fetch("dimensions"),
        "intents" => spec.fetch("intents").map { |intent| intent.fetch("intent") },
        "heldout_counts" => dimension_counts(semantic_records.fetch("heldout")),
        "performance_counts" =>
          dimension_counts(semantic_records.fetch("performance")),
        "suite_classes" => SUITE_IDS.each_with_object({}) do |suite_id, result|
          result[suite_id] = suites.fetch(suite_id).map do |definition|
            definition.fetch("coverage_class")
          end
        end,
        "suite_families" => SUITE_IDS.each_with_object({}) do |suite_id, result|
          result[suite_id] = suites.fetch(suite_id).map do |definition|
            definition.fetch("family")
          end
        end
      },
      "artifacts" => artifacts.keys.sort.map do |path|
        bytes = artifacts.fetch(path)
        {
          "path" => path,
          "bytes" => bytes.bytesize,
          "sha256" => sha256(bytes),
          "records" => artifact_record_count(bytes)
        }
      end
    }
  end

  def generated_bytes
    spec = load_spec
    validate_specification!(spec)
    artifacts, semantic_records = build_artifacts(spec)
    manifest = build_manifest(spec, artifacts, semantic_records)
    artifacts.merge(MANIFEST_PATH => JSON.pretty_generate(manifest) + "\n")
  end

  def generate(output_root)
    artifacts = generated_bytes
    artifacts.each do |relative, bytes|
      path = File.join(output_root, relative)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, bytes)
    end
    artifacts.keys.sort
  end

  def check_generated!
    Dir.mktmpdir("p02-v2-corpus-check.") do |temporary|
      generated_paths = generate(temporary)
      expected_paths = (ARTIFACT_PATHS + [MANIFEST_PATH]).sort
      raise Failure, "generated artifact path set differs" unless
        generated_paths == expected_paths
      expected_paths.each do |relative|
        committed = File.join(DATA_ROOT, relative)
        generated = File.join(temporary, relative)
        raise Failure, "missing committed artifact #{relative}" unless
          File.file?(committed) && !File.symlink?(committed)
        raise Failure, "generated artifact differs: #{relative}" unless
          File.binread(committed).b == File.binread(generated).b
      end
    end
  end

  module CLI
    module_function

    def run(arguments)
      options = {output: DATA_ROOT, check: false}
      parser = OptionParser.new do |opts|
        opts.on("--output PATH") { |path| options[:output] = File.expand_path(path) }
        opts.on("--check") { options[:check] = true }
      end
      parser.parse!(arguments)
      raise Failure, "unexpected arguments: #{arguments.join(' ')}" unless
        arguments.empty?
      raise Failure, "--check cannot be combined with --output" if
        options[:check] && options[:output] != DATA_ROOT

      if options[:check]
        P02V2Corpus.check_generated!
        puts "P02_V2_CORPUS_GENERATION_CHECK_PASS"
      else
        paths = P02V2Corpus.generate(options.fetch(:output))
        puts "P02_V2_CORPUS_GENERATED #{paths.length}"
      end
    rescue Failure, OptionParser::ParseError, KeyError, TypeError => error
      warn "P02_V2_CORPUS_GENERATION_FAIL: #{error.message}"
      exit 1
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  warn "invoke tools/generate-p02-v2-corpus"
  exit 1
end
