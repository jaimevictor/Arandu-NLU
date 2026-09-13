# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "optparse"
require "tmpdir"

module P11Corpus
  class Failure < StandardError; end
  class DuplicateKey < StandardError; end

  class UniqueHash < Hash
    def []=(key, value)
      raise DuplicateKey, key if key?(key)

      super
    end
  end

  ROOT = File.expand_path("..", __dir__)
  DATA_ROOT = File.join(ROOT, "data/project-authored/p11-v1")
  SPEC_PATH = File.join(DATA_ROOT, "specification.json")
  GENERATOR_PATH = File.expand_path(__FILE__)
  SPLITS = %w[train development].freeze
  REQUIRED_STRATA = %w[
    clear_first_node_negation
    clear_second_node_negation
    ambiguous_shared_scope
  ].freeze
  OUTPUT_PATHS = SPLITS.map { |split| "#{split}.jsonl" }.freeze
  MANIFEST_PATH = "manifest.json"
  REGISTRY_NAMESPACE = "p11-negation-registry-v1"
  HEX_32 = /\A[0-9a-f]{32}\z/.freeze
  HEX_64 = /\A[0-9a-f]{64}\z/.freeze

  SPECIFICATION_CONTRACT = {
    "id" => "p11-multi-intent-negation-specification-v1",
    "version" => "1.0.0",
    "status" => "PRE_P11_COMPOSER_ORACLE",
    "specification_precedes_generated_rows" => true,
    "freeze_target" => "FROZEN_PRE_P11_COMPOSER"
  }.freeze
  LINEAGE_CONTRACT = {
    "source_id" => "project-authored-synthetic-ptbr-p11-negation-v1",
    "source_type" => "PROJECT_AUTHORED_SYNTHETIC",
    "corpus_id" => "project-authored-synthetic-ptbr-p11-negation-v1",
    "corpus_version" => "1.0.0",
    "generator_id" => "p11-negation-generator-v1",
    "oracle_origin" => "pre_p11_composer_generator_specification",
    "oracle_authorizations" => [
      "USR-016",
      "USER_EXPLICIT_2026-08-28"
    ],
    "oracle_derivation" => "specification_only_no_nlu_output",
    "license" => "Apache-2.0",
    "locale" => "pt-BR",
    "claim_scope" => "internal_conformance_only"
  }.freeze
  PLAN_CONTRACT = {
    "intent" => "HassTurnOn",
    "domain" => "light",
    "capability" => "ha:light_control",
    "operation" => "ha:turn_on",
    "entity_slot_id" => "ha:entity",
    "catalog_generation" => 1,
    "plan_schema" => "p11-semantic-plan-v1",
    "execution_class" => "non_executable",
    "surface_form_contract" => "p09_hass_turn_on_two_target"
  }.freeze
  SPLIT_POLICY_CONTRACT = {
    "splits" => SPLITS,
    "family_disjoint" => true,
    "text_disjoint" => true,
    "semantic_identity_disjoint" => true,
    "target_identity_disjoint" => true,
    "heldout_split_present" => false
  }.freeze

  RECORD_KEYS = %w[
    schema_version
    case_id
    generator_record_id
    canonical_semantic_id
    specification_id
    specification_version
    source_id
    source_type
    corpus_id
    corpus_version
    generator_id
    oracle_origin
    oracle_authorizations
    oracle_derivation
    license
    locale
    claim_scope
    split
    family
    stratum
    utterance
    utterance_sha256
    context
    expected
  ].freeze

  module_function

  def sha256(bytes)
    Digest::SHA256.hexdigest(bytes)
  end

  def canonical_sha(value)
    sha256(JSON.generate(value))
  end

  def exact_keys!(value, expected, context)
    raise Failure, "#{context} must be a mapping" unless value.is_a?(Hash)

    actual = value.keys.sort
    wanted = expected.sort
    return if actual == wanted

    raise Failure, "#{context} fields differ: #{actual.inspect}"
  end

  def utf8_string!(value, context)
    unless value.is_a?(String) &&
           value.encoding == Encoding::UTF_8 &&
           value.valid_encoding? &&
           !value.empty?
      raise Failure, "#{context} must be nonempty valid UTF-8"
    end

    value
  end

  def parse_json(bytes, context)
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    raise Failure, "#{context} is not valid UTF-8" unless text.valid_encoding?

    JSON.parse(text, object_class: UniqueHash, array_class: Array)
  rescue JSON::ParserError => error
    raise Failure, "#{context} is invalid JSON: #{error.class}"
  rescue DuplicateKey => error
    raise Failure, "#{context} has duplicate key #{error.message.inspect}"
  end

  def load_spec(path = SPEC_PATH)
    value = parse_json(File.binread(path), "specification")
    raise Failure, "specification root must be a mapping" unless value.is_a?(Hash)

    value
  end

  def occurrences(text, fragment)
    haystack = text.b
    needle = fragment.encode(Encoding::UTF_8).b
    result = []
    offset = 0
    while (index = haystack.index(needle, offset))
      result << {"begin_byte" => index, "end_byte" => index + needle.bytesize}
      offset = index + needle.bytesize
    end
    result
  end

  def exactly_one_span(text, fragment, context)
    spans = occurrences(text, fragment)
    raise Failure, "#{context} must occur exactly once" unless spans.length == 1

    spans.fetch(0)
  end

  def expected_polarities(stratum)
    case stratum
    when "clear_first_node_negation"
      %w[negated affirmed]
    when "clear_second_node_negation"
      %w[affirmed negated]
    when "ambiguous_shared_scope"
      []
    else
      raise Failure, "unknown negation stratum #{stratum.inspect}"
    end
  end

  def expected_surface(definition)
    first, second = definition.fetch("targets")
    core = case definition.fetch("stratum")
           when "clear_first_node_negation"
             "não ligue #{first} e ligue #{second}"
           when "clear_second_node_negation"
             "ligue #{first} e não ligue #{second}"
           when "ambiguous_shared_scope"
             "não ligue #{first} e #{second}"
           else
             raise Failure, "unknown negation stratum"
           end
    definition.fetch("split") == "development" ? "por favor #{core}" : core
  end

  def validate_target!(target, context)
    utf8_string!(target, context)
    tokens = target.split
    unless tokens.length == 5 && tokens.fetch(0) == "luz"
      raise Failure, "#{context} must be five tokens beginning with luz"
    end
  end

  def validate_case!(definition, index)
    context = "case #{index + 1}"
    exact_keys!(
      definition,
      %w[case_key split family stratum utterance targets expected],
      context
    )
    case_key = utf8_string!(definition.fetch("case_key"), "#{context} key")
    unless case_key.match?(/\A(?:train|development)-[a-z-]+\z/)
      raise Failure, "#{context} key is invalid"
    end

    split = definition.fetch("split")
    raise Failure, "#{context} split is invalid" unless SPLITS.include?(split)

    family = utf8_string!(definition.fetch("family"), "#{context} family")
    unless family.start_with?("p11-#{split}-") && family.end_with?("-v1")
      raise Failure, "#{context} family is not split-specific"
    end

    stratum = definition.fetch("stratum")
    unless REQUIRED_STRATA.include?(stratum)
      raise Failure, "#{context} negation stratum is invalid"
    end

    utterance = utf8_string!(
      definition.fetch("utterance"),
      "#{context} utterance"
    )
    targets = definition.fetch("targets")
    unless targets.is_a?(Array) && targets.length == 2
      raise Failure, "#{context} must contain exactly two targets"
    end
    targets.each_with_index do |target, target_index|
      validate_target!(target, "#{context} target #{target_index + 1}")
      exactly_one_span(
        utterance,
        target,
        "#{context} target #{target_index + 1}"
      )
    end
    raise Failure, "#{context} targets must differ" unless targets.uniq.length == 2
    raise Failure, "#{context} surface differs from specification template" unless
      utterance == expected_surface(definition)

    expected = definition.fetch("expected")
    exact_keys!(expected, %w[outcome polarities reason], "#{context} expected")
    polarities = expected.fetch("polarities")
    unless polarities == expected_polarities(stratum)
      raise Failure, "#{context} polarities differ from negation stratum"
    end

    if stratum == "ambiguous_shared_scope"
      unless expected.fetch("outcome") == "abstention" &&
             expected.fetch("reason") == "negation_scope"
        raise Failure, "#{context} ambiguous scope must abstain"
      end
      raise Failure, "#{context} must contain one predicate" unless
        occurrences(utterance, "ligue").length == 1
    else
      unless expected.fetch("outcome") == "plan" &&
             expected.fetch("reason").nil?
        raise Failure, "#{context} clear scope must encode a plan"
      end
      raise Failure, "#{context} must contain two predicates" unless
        occurrences(utterance, "ligue").length == 2
    end
    raise Failure, "#{context} must contain one negation cue" unless
      occurrences(utterance, "não").length == 1
  end

  def duplicate?(values)
    values.uniq.length != values.length
  end

  def validate_specification!(spec)
    exact_keys!(
      spec,
      %w[
        schema_version
        specification
        lineage
        contract
        split_policy
        required_strata
        cases
      ],
      "specification"
    )
    raise Failure, "unsupported specification schema" unless
      spec.fetch("schema_version") == 1

    metadata = spec.fetch("specification")
    exact_keys!(
      metadata,
      SPECIFICATION_CONTRACT.keys,
      "specification metadata"
    )
    raise Failure, "specification metadata differs" unless
      metadata == SPECIFICATION_CONTRACT

    lineage = spec.fetch("lineage")
    exact_keys!(lineage, LINEAGE_CONTRACT.keys, "lineage")
    unless lineage.fetch("oracle_origin") ==
             "pre_p11_composer_generator_specification" &&
           lineage.fetch("oracle_derivation") ==
             "specification_only_no_nlu_output"
      raise Failure, "NLU-derived oracle is forbidden"
    end
    raise Failure, "lineage contract differs" unless lineage == LINEAGE_CONTRACT

    contract = spec.fetch("contract")
    exact_keys!(contract, PLAN_CONTRACT.keys, "plan contract")
    raise Failure, "plan contract differs" unless contract == PLAN_CONTRACT

    split_policy = spec.fetch("split_policy")
    exact_keys!(split_policy, SPLIT_POLICY_CONTRACT.keys, "split policy")
    raise Failure, "split policy differs" unless
      split_policy == SPLIT_POLICY_CONTRACT

    required = spec.fetch("required_strata")
    raise Failure, "required negation strata differ" unless
      required == REQUIRED_STRATA

    cases = spec.fetch("cases")
    unless cases.is_a?(Array) &&
           cases.length == SPLITS.length * REQUIRED_STRATA.length
      raise Failure, "minimal case inventory must contain six cases"
    end
    cases.each_with_index { |definition, index| validate_case!(definition, index) }

    case_keys = cases.map { |definition| definition.fetch("case_key") }
    families = cases.map { |definition| definition.fetch("family") }
    utterances = cases.map { |definition| definition.fetch("utterance") }
    targets = cases.flat_map { |definition| definition.fetch("targets") }
    raise Failure, "case keys must be unique" if duplicate?(case_keys)
    raise Failure, "families must be unique" if duplicate?(families)
    raise Failure, "utterances must be text-disjoint" if duplicate?(utterances)
    raise Failure, "target identities must be disjoint" if duplicate?(targets)

    train_families = cases.select do |definition|
      definition.fetch("split") == "train"
    end.map { |definition| definition.fetch("family") }
    development_families = cases.select do |definition|
      definition.fetch("split") == "development"
    end.map { |definition| definition.fetch("family") }
    unless (train_families & development_families).empty?
      raise Failure, "train and development families overlap"
    end

    SPLITS.each do |split|
      REQUIRED_STRATA.each do |stratum|
        count = cases.count do |definition|
          definition.fetch("split") == split &&
            definition.fetch("stratum") == stratum
        end
        unless count == 1
          raise Failure,
                "missing required negation stratum #{split}/#{stratum}"
        end
      end
    end
    true
  end

  def registry_id(case_key, target_index)
    seed = [
      REGISTRY_NAMESPACE,
      case_key,
      "target-#{target_index + 1}"
    ].join("\0")
    sha256(seed)[0, 32]
  end

  def catalog_entity(definition, target_index)
    identifier = registry_id(definition.fetch("case_key"), target_index)
    {
      "registry_id" => identifier,
      "entity_id" => "ha_entity:id_#{identifier}",
      "catalog_generation" => 1,
      "mention" => definition.fetch("targets").fetch(target_index)
    }
  end

  def evidence_atom(kind, span, slot = nil)
    atom = {"kind" => kind}
    atom["slot"] = slot unless slot.nil?
    atom["begin_byte"] = span.fetch("begin_byte")
    atom["end_byte"] = span.fetch("end_byte")
    atom
  end

  def plan_node(contract, entity, node_index, polarity, predicate_span,
                argument_span, negation_span)
    evidence = [
      evidence_atom("predicate", predicate_span),
      evidence_atom(
        "argument",
        argument_span,
        contract.fetch("entity_slot_id")
      )
    ]
    if polarity == "negated"
      evidence << evidence_atom("negation", negation_span)
    end

    {
      "id" => "p11:node_#{node_index + 1}",
      "intent" => contract.fetch("intent"),
      "capability" => contract.fetch("capability"),
      "operation" => contract.fetch("operation"),
      "polarity" => polarity,
      "slots" => [
        {
          "id" => contract.fetch("entity_slot_id"),
          "kind" => "entity",
          "value" => {
            "id" => entity.fetch("entity_id"),
            "catalog_generation" => contract.fetch("catalog_generation")
          }
        }
      ],
      "evidence" => evidence
    }
  end

  def project_expected(spec, definition, entities)
    expected = definition.fetch("expected")
    if expected.fetch("outcome") == "abstention"
      return {
        "outcome" => "abstention",
        "reason" => "negation_scope"
      }
    end

    utterance = definition.fetch("utterance")
    predicate_spans = occurrences(utterance, "ligue")
    negation_span = exactly_one_span(
      utterance,
      "não",
      "#{definition.fetch('case_key')} negation"
    )
    argument_spans = definition.fetch("targets").map.with_index do |target, index|
      exactly_one_span(
        utterance,
        target,
        "#{definition.fetch('case_key')} target #{index + 1}"
      )
    end
    polarities = expected.fetch("polarities")
    nodes = entities.map.with_index do |entity, index|
      plan_node(
        spec.fetch("contract"),
        entity,
        index,
        polarities.fetch(index),
        predicate_spans.fetch(index),
        argument_spans.fetch(index),
        negation_span
      )
    end
    contract = spec.fetch("contract")
    {
      "outcome" => "plan",
      "intent" => contract.fetch("intent"),
      "plan" => {
        "schema_version" => contract.fetch("plan_schema"),
        "catalog_generation" => contract.fetch("catalog_generation"),
        "execution_class" => contract.fetch("execution_class"),
        "nodes" => nodes,
        "relations" => [],
        "independent_pairs" => [
          {
            "left" => "p11:node_1",
            "right" => "p11:node_2"
          }
        ],
        "argument_shares" => []
      }
    }
  end

  def project_case(spec, definition)
    metadata = spec.fetch("specification")
    lineage = spec.fetch("lineage")
    entities = 2.times.map do |target_index|
      catalog_entity(definition, target_index)
    end
    context = {
      "catalog_generation" => spec.fetch("contract").fetch("catalog_generation"),
      "entities" => entities
    }
    expected = project_expected(spec, definition, entities)
    semantic_payload = {"context" => context, "expected" => expected}
    case_id = "p11-v1-#{definition.fetch('case_key')}"
    utterance = definition.fetch("utterance")

    {
      "schema_version" => 1,
      "case_id" => case_id,
      "generator_record_id" => "generator-#{case_id}",
      "canonical_semantic_id" => canonical_sha(semantic_payload),
      "specification_id" => metadata.fetch("id"),
      "specification_version" => metadata.fetch("version"),
      "source_id" => lineage.fetch("source_id"),
      "source_type" => lineage.fetch("source_type"),
      "corpus_id" => lineage.fetch("corpus_id"),
      "corpus_version" => lineage.fetch("corpus_version"),
      "generator_id" => lineage.fetch("generator_id"),
      "oracle_origin" => lineage.fetch("oracle_origin"),
      "oracle_authorizations" => lineage.fetch("oracle_authorizations"),
      "oracle_derivation" => lineage.fetch("oracle_derivation"),
      "license" => lineage.fetch("license"),
      "locale" => lineage.fetch("locale"),
      "claim_scope" => lineage.fetch("claim_scope"),
      "split" => definition.fetch("split"),
      "family" => definition.fetch("family"),
      "stratum" => definition.fetch("stratum"),
      "utterance" => utterance,
      "utterance_sha256" => sha256(utterance.encode(Encoding::UTF_8)),
      "context" => context,
      "expected" => expected
    }
  end

  def validate_span!(utterance, atom, expected_text, context)
    keys = atom.fetch("kind") == "argument" ?
      %w[kind slot begin_byte end_byte] :
      %w[kind begin_byte end_byte]
    exact_keys!(atom, keys, context)
    begin_byte = atom.fetch("begin_byte")
    end_byte = atom.fetch("end_byte")
    unless begin_byte.is_a?(Integer) &&
           end_byte.is_a?(Integer) &&
           begin_byte >= 0 &&
           end_byte > begin_byte &&
           end_byte <= utterance.bytesize
      raise Failure, "#{context} has invalid half-open byte span"
    end

    bytes = utterance.b
    prefix_at_begin = bytes.byteslice(0, begin_byte)
    prefix_at_end = bytes.byteslice(0, end_byte)
    unless prefix_at_begin.dup.force_encoding(Encoding::UTF_8).valid_encoding? &&
           prefix_at_end.dup.force_encoding(Encoding::UTF_8).valid_encoding?
      raise Failure, "#{context} is not on UTF-8 boundaries"
    end

    extracted = bytes
      .byteslice(begin_byte, end_byte - begin_byte)
      .dup
      .force_encoding(Encoding::UTF_8)
    unless extracted.valid_encoding? && extracted == expected_text
      raise Failure, "#{context} text differs from byte span"
    end
  end

  def validate_entity!(entity, definition, target_index, context)
    exact_keys!(
      entity,
      %w[registry_id entity_id catalog_generation mention],
      context
    )
    identifier = entity.fetch("registry_id")
    raise Failure, "#{context} registry ID is not 32 lowercase hex" unless
      identifier.is_a?(String) && identifier.match?(HEX_32)
    unless identifier == registry_id(definition.fetch("case_key"), target_index)
      raise Failure, "#{context} registry ID is not deterministic"
    end
    unless entity.fetch("entity_id") == "ha_entity:id_#{identifier}"
      raise Failure, "#{context} core entity ID differs"
    end
    raise Failure, "#{context} catalog generation differs" unless
      entity.fetch("catalog_generation") == 1
    raise Failure, "#{context} mention differs" unless
      entity.fetch("mention") == definition.fetch("targets").fetch(target_index)
  end

  def validate_plan!(plan_expected, definition, context_record)
    exact_keys!(plan_expected, %w[outcome intent plan], "plan expected")
    raise Failure, "plan expected outcome differs" unless
      plan_expected.fetch("outcome") == "plan" &&
      plan_expected.fetch("intent") == "HassTurnOn"

    plan = plan_expected.fetch("plan")
    exact_keys!(
      plan,
      %w[
        schema_version
        catalog_generation
        execution_class
        nodes
        relations
        independent_pairs
        argument_shares
      ],
      "semantic plan"
    )
    unless plan.fetch("schema_version") == "p11-semantic-plan-v1" &&
           plan.fetch("catalog_generation") == 1 &&
           plan.fetch("execution_class") == "non_executable"
      raise Failure, "semantic plan contract differs"
    end
    raise Failure, "semantic plan must have no relations" unless
      plan.fetch("relations") == []
    raise Failure, "semantic plan must have no argument shares" unless
      plan.fetch("argument_shares") == []
    unless plan.fetch("independent_pairs") == [
      {"left" => "p11:node_1", "right" => "p11:node_2"}
    ]
      raise Failure, "semantic plan independent pair differs"
    end

    nodes = plan.fetch("nodes")
    raise Failure, "semantic plan must contain two nodes" unless
      nodes.is_a?(Array) && nodes.length == 2
    utterance = definition.fetch("utterance")
    targets = definition.fetch("targets")
    polarities = definition.fetch("expected").fetch("polarities")
    nodes.each_with_index do |node, index|
      exact_keys!(
        node,
        %w[id intent capability operation polarity slots evidence],
        "node #{index + 1}"
      )
      unless node.fetch("id") == "p11:node_#{index + 1}" &&
             node.fetch("intent") == "HassTurnOn" &&
             node.fetch("capability") == "ha:light_control" &&
             node.fetch("operation") == "ha:turn_on" &&
             node.fetch("polarity") == polarities.fetch(index)
        raise Failure, "node #{index + 1} semantics differ"
      end

      slots = node.fetch("slots")
      unless slots.is_a?(Array) && slots.length == 1
        raise Failure, "node #{index + 1} slot count differs"
      end
      slot = slots.fetch(0)
      exact_keys!(slot, %w[id kind value], "node #{index + 1} slot")
      exact_keys!(
        slot.fetch("value"),
        %w[id catalog_generation],
        "node #{index + 1} slot value"
      )
      entity = context_record.fetch("entities").fetch(index)
      unless slot.fetch("id") == "ha:entity" &&
             slot.fetch("kind") == "entity" &&
             slot.fetch("value") == {
               "id" => entity.fetch("entity_id"),
               "catalog_generation" => 1
             }
        raise Failure, "node #{index + 1} entity slot differs"
      end

      evidence = node.fetch("evidence")
      expected_count = polarities.fetch(index) == "negated" ? 3 : 2
      unless evidence.is_a?(Array) && evidence.length == expected_count
        raise Failure, "node #{index + 1} evidence count differs"
      end
      predicate = evidence.fetch(0)
      argument = evidence.fetch(1)
      unless predicate.fetch("kind") == "predicate" &&
             argument.fetch("kind") == "argument" &&
             argument.fetch("slot") == "ha:entity"
        raise Failure, "node #{index + 1} typed evidence differs"
      end
      validate_span!(utterance, predicate, "ligue", "node predicate evidence")
      validate_span!(
        utterance,
        argument,
        targets.fetch(index),
        "node argument evidence"
      )
      if expected_count == 3
        negation = evidence.fetch(2)
        raise Failure, "node negation evidence kind differs" unless
          negation.fetch("kind") == "negation"
        validate_span!(utterance, negation, "não", "node negation evidence")
      end
    end
  end

  def validate_record!(record, spec, definition)
    exact_keys!(record, RECORD_KEYS, "generated record")
    raise Failure, "generated record schema differs" unless
      record.fetch("schema_version") == 1
    utterance = record.fetch("utterance")
    utf8_string!(utterance, "generated utterance")
    unless record.fetch("utterance_sha256").is_a?(String) &&
           record.fetch("utterance_sha256").match?(HEX_64) &&
           record.fetch("utterance_sha256") == sha256(utterance)
      raise Failure, "utterance hash differs"
    end

    context_record = record.fetch("context")
    exact_keys!(context_record, %w[catalog_generation entities], "case context")
    raise Failure, "case catalog generation differs" unless
      context_record.fetch("catalog_generation") == 1
    entities = context_record.fetch("entities")
    unless entities.is_a?(Array) && entities.length == 2
      raise Failure, "case context must contain two entities"
    end
    entities.each_with_index do |entity, index|
      validate_entity!(entity, definition, index, "context entity #{index + 1}")
    end

    expected = record.fetch("expected")
    if definition.fetch("expected").fetch("outcome") == "plan"
      validate_plan!(expected, definition, context_record)
    else
      exact_keys!(expected, %w[outcome reason], "abstention expected")
      unless expected == {
        "outcome" => "abstention",
        "reason" => "negation_scope"
      }
        raise Failure, "ambiguous scope abstention differs"
      end
    end

    semantic_id = canonical_sha(
      {"context" => context_record, "expected" => expected}
    )
    unless record.fetch("canonical_semantic_id").is_a?(String) &&
           record.fetch("canonical_semantic_id").match?(HEX_64) &&
           record.fetch("canonical_semantic_id") == semantic_id
      raise Failure, "canonical semantic identity differs"
    end
    raise Failure, "record differs from specification projection" unless
      record == project_case(spec, definition)
  end

  def validate_records!(records, spec)
    validate_specification!(spec)
    unless records.is_a?(Array) &&
           records.length == spec.fetch("cases").length
      raise Failure, "generated record count differs"
    end

    definitions = spec.fetch("cases")
    records.each_with_index do |record, index|
      validate_record!(record, spec, definitions.fetch(index))
    end

    {
      "case IDs" => records.map { |record| record.fetch("case_id") },
      "generator record IDs" =>
        records.map { |record| record.fetch("generator_record_id") },
      "utterance texts" => records.map { |record| record.fetch("utterance") },
      "utterance hashes" =>
        records.map { |record| record.fetch("utterance_sha256") },
      "semantic identities" =>
        records.map { |record| record.fetch("canonical_semantic_id") },
      "registry IDs" => records.flat_map do |record|
        record.fetch("context").fetch("entities").map do |entity|
          entity.fetch("registry_id")
        end
      end
    }.each do |label, values|
      raise Failure, "#{label} must be disjoint" if duplicate?(values)
    end

    train_families = records.select do |record|
      record.fetch("split") == "train"
    end.map { |record| record.fetch("family") }
    development_families = records.select do |record|
      record.fetch("split") == "development"
    end.map { |record| record.fetch("family") }
    unless (train_families & development_families).empty?
      raise Failure, "generated split families overlap"
    end

    SPLITS.each do |split|
      REQUIRED_STRATA.each do |stratum|
        count = records.count do |record|
          record.fetch("split") == split &&
            record.fetch("stratum") == stratum
        end
        unless count == 1
          raise Failure,
                "missing generated negation stratum #{split}/#{stratum}"
        end
      end
    end
    true
  end

  def build_records(spec)
    validate_specification!(spec)
    records = spec.fetch("cases").map do |definition|
      project_case(spec, definition)
    end
    validate_records!(records, spec)
    records
  end

  def json_lines(records)
    records.map { |record| JSON.generate(record) }.join("\n") + "\n"
  end

  def parse_json_lines(bytes, context)
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    raise Failure, "#{context} is not valid UTF-8" unless text.valid_encoding?
    raise Failure, "#{context} must end with one newline" unless
      text.end_with?("\n") && !text.end_with?("\n\n")

    lines = text.lines
    raise Failure, "#{context} is empty" if lines.empty?
    lines.map.with_index do |line, index|
      parse_json(line, "#{context} line #{index + 1}")
    end
  end

  def output_artifacts(records)
    SPLITS.each_with_object({}) do |split, artifacts|
      split_records = records.select { |record| record.fetch("split") == split }
      artifacts["#{split}.jsonl"] = json_lines(split_records)
    end
  end

  def count_by(records, field, values)
    values.each_with_object({}) do |value, counts|
      counts[value] = records.count { |record| record.fetch(field) == value }
    end
  end

  def binding(path, bytes)
    {
      "path" => path,
      "bytes" => bytes.bytesize,
      "sha256" => sha256(bytes)
    }
  end

  def build_manifest(spec, artifacts, records)
    lineage = spec.fetch("lineage")
    specification = spec.fetch("specification")
    {
      "schema_version" => 1,
      "corpus" => {
        "id" => lineage.fetch("corpus_id"),
        "version" => lineage.fetch("corpus_version"),
        "status" => lineage.fetch("source_type"),
        "source_id" => lineage.fetch("source_id"),
        "generator_id" => lineage.fetch("generator_id"),
        "oracle_origin" => lineage.fetch("oracle_origin"),
        "oracle_authorizations" => lineage.fetch("oracle_authorizations"),
        "oracle_derivation" => lineage.fetch("oracle_derivation"),
        "license" => lineage.fetch("license"),
        "locale" => lineage.fetch("locale"),
        "claim_scope" => lineage.fetch("claim_scope")
      },
      "freeze" => {
        "state" => "FROZEN_PRE_P11_COMPOSER",
        "sequence" => "P11_NEGATION_SUPPLEMENT_PRE_COMPOSER",
        "before_p11_plan_composer_implementation" => true,
        "specification_precedes_generated_rows" =>
          specification.fetch("specification_precedes_generated_rows"),
        "nlu_output_used_as_oracle" => false,
        "family_disjoint" => true,
        "text_disjoint" => true,
        "semantic_identity_disjoint" => true,
        "target_identity_disjoint" => true
      },
      "bindings" => {
        "specification" => binding(
          "data/project-authored/p11-v1/specification.json",
          File.binread(SPEC_PATH)
        ),
        "generator" => binding(
          "tools/generate-p11-corpus.rb",
          File.binread(GENERATOR_PATH)
        )
      },
      "counts" => {
        "total_records" => records.length,
        "by_split" => count_by(records, "split", SPLITS),
        "by_outcome" => {
          "plan" => records.count do |record|
            record.fetch("expected").fetch("outcome") == "plan"
          end,
          "abstention" => records.count do |record|
            record.fetch("expected").fetch("outcome") == "abstention"
          end
        },
        "by_stratum" => count_by(records, "stratum", REQUIRED_STRATA)
      },
      "required_coverage" => {
        "strata" => REQUIRED_STRATA,
        "by_split" => SPLITS.each_with_object({}) do |split, result|
          result[split] = REQUIRED_STRATA
        end
      },
      "outputs" => OUTPUT_PATHS.map do |path|
        bytes = artifacts.fetch(path)
        {
          "path" => path,
          "bytes" => bytes.bytesize,
          "sha256" => sha256(bytes),
          "records" => bytes.lines.length
        }
      end
    }
  end

  def validate_manifest!(manifest, spec, artifacts, records)
    exact_keys!(
      manifest,
      %w[
        schema_version
        corpus
        freeze
        bindings
        counts
        required_coverage
        outputs
      ],
      "manifest"
    )
    exact_keys!(
      manifest.fetch("corpus"),
      %w[
        id
        version
        status
        source_id
        generator_id
        oracle_origin
        oracle_authorizations
        oracle_derivation
        license
        locale
        claim_scope
      ],
      "manifest corpus"
    )
    exact_keys!(
      manifest.fetch("freeze"),
      %w[
        state
        sequence
        before_p11_plan_composer_implementation
        specification_precedes_generated_rows
        nlu_output_used_as_oracle
        family_disjoint
        text_disjoint
        semantic_identity_disjoint
        target_identity_disjoint
      ],
      "manifest freeze"
    )
    exact_keys!(
      manifest.fetch("bindings"),
      %w[specification generator],
      "manifest bindings"
    )
    manifest.fetch("bindings").each do |name, value|
      exact_keys!(value, %w[path bytes sha256], "manifest #{name} binding")
    end
    exact_keys!(
      manifest.fetch("counts"),
      %w[total_records by_split by_outcome by_stratum],
      "manifest counts"
    )
    exact_keys!(
      manifest.fetch("required_coverage"),
      %w[strata by_split],
      "manifest required coverage"
    )
    outputs = manifest.fetch("outputs")
    unless outputs.is_a?(Array) && outputs.length == OUTPUT_PATHS.length
      raise Failure, "manifest output inventory differs"
    end
    outputs.each do |output|
      exact_keys!(output, %w[path bytes sha256 records], "manifest output")
      raise Failure, "manifest output hash is invalid" unless
        output.fetch("sha256").is_a?(String) &&
        output.fetch("sha256").match?(HEX_64)
    end

    expected = build_manifest(spec, artifacts, records)
    raise Failure, "manifest differs from bound inputs and outputs" unless
      manifest == expected
    true
  end

  def validate_artifacts!(artifacts, spec)
    records = OUTPUT_PATHS.flat_map do |path|
      parse_json_lines(artifacts.fetch(path), path)
    end
    expected_order = SPLITS.flat_map do |split|
      records.select { |record| record.fetch("split") == split }
    end
    raise Failure, "output split ordering differs" unless records == expected_order
    validate_records!(records, spec)
    records
  end

  def generate(output_root)
    spec = load_spec
    records = build_records(spec)
    artifacts = output_artifacts(records)
    validate_artifacts!(artifacts, spec)
    manifest = build_manifest(spec, artifacts, records)
    validate_manifest!(manifest, spec, artifacts, records)
    artifacts[MANIFEST_PATH] = JSON.pretty_generate(manifest) + "\n"

    artifacts.each do |relative, bytes|
      path = File.join(output_root, relative)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, bytes)
    end
    artifacts.keys.sort
  end

  def check_generated!
    Dir.mktmpdir("p11-corpus-check.") do |temporary|
      generated_paths = generate(temporary)
      expected_paths = (OUTPUT_PATHS + [MANIFEST_PATH]).sort
      raise Failure, "generated artifact path set differs" unless
        generated_paths == expected_paths

      expected_paths.each do |relative|
        committed = File.join(DATA_ROOT, relative)
        generated = File.join(temporary, relative)
        unless File.file?(committed) && !File.symlink?(committed)
          raise Failure, "missing committed artifact #{relative}"
        end
        unless File.binread(committed) == File.binread(generated)
          raise Failure, "generated artifact differs: #{relative}"
        end
      end

      spec = load_spec
      committed_artifacts = OUTPUT_PATHS.each_with_object({}) do |relative, result|
        result[relative] = File.binread(File.join(DATA_ROOT, relative))
      end
      records = validate_artifacts!(committed_artifacts, spec)
      manifest = parse_json(
        File.binread(File.join(DATA_ROOT, MANIFEST_PATH)),
        "committed manifest"
      )
      validate_manifest!(manifest, spec, committed_artifacts, records)
    end
    true
  end

  module GeneratorCLI
    module_function

    def run(arguments)
      options = {output: DATA_ROOT, check: false}
      parser = OptionParser.new do |opts|
        opts.on("--output PATH") do |path|
          options[:output] = File.expand_path(path)
        end
        opts.on("--check") { options[:check] = true }
      end
      parser.parse!(arguments)
      raise Failure, "unexpected arguments: #{arguments.join(' ')}" unless
        arguments.empty?
      if options[:check] && options[:output] != DATA_ROOT
        raise Failure, "--check cannot be combined with --output"
      end

      if options[:check]
        P11Corpus.check_generated!
        puts "P11_CORPUS_GENERATION_CHECK_PASS"
      else
        paths = P11Corpus.generate(options.fetch(:output))
        puts "P11_CORPUS_GENERATED #{paths.length}"
      end
    rescue Failure, OptionParser::ParseError, KeyError, TypeError => error
      warn "P11_CORPUS_GENERATION_FAIL: #{error.message}"
      exit 1
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  warn "invoke tools/generate-p11-corpus"
  exit 1
end
