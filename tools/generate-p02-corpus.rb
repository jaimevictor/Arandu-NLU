# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "optparse"
require "psych"
require "tmpdir"

module P02Corpus
  class Failure < StandardError; end

  ROOT = File.expand_path("..", __dir__)
  DATA_ROOT = File.join(ROOT, "data/project-authored/p02-v1")
  SPEC_PATH = File.join(DATA_ROOT, "specification.yaml")
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
    %w[lexicon.jsonl morphology.jsonl pos-context.jsonl] +
    SUITE_IDS.map { |suite| "suites/#{suite.tr('_', '-')}.jsonl" }
  ).freeze
  MANIFEST_PATH = "manifest.json"
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

  module_function

  def load_spec(path = SPEC_PATH)
    value = Psych.safe_load(
      File.binread(path),
      permitted_classes: [],
      permitted_symbols: [],
      aliases: false,
      filename: path
    )
    raise Failure, "specification root must be a mapping" unless value.is_a?(Hash)

    value
  rescue Psych::Exception => error
    raise Failure, "invalid specification YAML: #{error.class}"
  end

  def exact_keys!(mapping, keys, context)
    raise Failure, "#{context} must be a mapping" unless mapping.is_a?(Hash)

    actual = mapping.keys.sort
    expected = keys.sort
    return if actual == expected

    raise Failure, "#{context} fields differ: #{actual.inspect}"
  end

  def sha256(bytes)
    Digest::SHA256.hexdigest(bytes)
  end

  def slug(value)
    value
      .gsub(/([a-z0-9])([A-Z])/, '\1_\2')
      .downcase
      .gsub(/[^a-z0-9]+/, "_")
      .gsub(/\A_+|_+\z/, "")
  end

  def canonical_sha(value)
    sha256(JSON.generate(value))
  end

  def case_count(spec, split)
    spec.fetch("quotas").fetch("#{split}_per_intent")
  end

  def area_for(index)
    AREAS.fetch((index - 1) % AREAS.length)
  end

  def target_values(intent, split, index, offset = 0)
    adjusted = ((index - 1 + offset) % 240) + 1
    area = area_for(adjusted)
    number = ((adjusted - 1) / AREAS.length) + 1
    intent_slug = slug(intent.fetch("intent"))
    {
      "text" => "#{intent.fetch('target_noun')} #{number} do setor #{area}",
      "entity_id" =>
        "#{intent.fetch('domain')}.#{split}_#{intent_slug}_#{format('%03d', adjusted)}",
      "area" => area,
      "number" => number
    }
  end

  def text_slot(id, value)
    {"id" => id, "kind" => "text", "value" => value}
  end

  def integer_slot(id, value)
    {"id" => id, "kind" => "integer", "value" => value}
  end

  def entity_slot(id, entity_id)
    {
      "id" => id,
      "kind" => "entity",
      "value" => {
        "id" => entity_id,
        "catalog_generation" => 1
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

  def build_case_values(intent, split, index)
    target = target_values(intent, split, index)
    target2 = target_values(intent, split, index, 120)
    position = (index - 1) % 101
    minutes = index
    scope = format("%03d", index)
    message = "confirmacao #{index} do setor #{target.fetch('area')}"
    parameters = {
      target: target.fetch("text"),
      target2: target2.fetch("text"),
      position: position,
      minutes: minutes,
      scope: scope,
      message: message
    }
    [target, target2, parameters, message]
  end

  def expected_plan(intent, split, index, target, target2, message)
    capability = intent.fetch("capability")
    operation = intent.fetch("operation")
    nodes = []
    relations = []

    case intent.fetch("case_kind")
    when "entity", "display", "timer"
      nodes << node(
        "p02:node_1",
        capability,
        operation,
        [entity_slot("ha:entity", target.fetch("entity_id"))]
      )
    when "entity_pair"
      nodes << node(
        "p02:node_1",
        capability,
        operation,
        [entity_slot("ha:entity", target.fetch("entity_id"))]
      )
      nodes << node(
        "p02:node_2",
        capability,
        operation,
        [entity_slot("ha:entity", target2.fetch("entity_id"))]
      )
    when "pending_action"
      nodes << node(
        "p02:node_1",
        capability,
        operation,
        [text_slot("ha:pending_action", "#{split}_pending_#{format('%03d', index)}")]
      )
    when "position"
      nodes << node(
        "p02:node_1",
        capability,
        operation,
        [
          entity_slot("ha:entity", target.fetch("entity_id")),
          integer_slot("ha:position", (index - 1) % 101)
        ]
      )
    when "timer_duration_ordered"
      timer_slot = entity_slot("ha:timer", target.fetch("entity_id"))
      nodes << node(
        "p02:node_1",
        capability,
        operation,
        [timer_slot, integer_slot("ha:duration_seconds", index * 60)]
      )
      nodes << node(
        "p02:node_2",
        capability,
        intent.fetch("secondary_operation"),
        [timer_slot]
      )
      relations << {
        "from" => "p02:node_1",
        "to" => "p02:node_2",
        "kind" => "precedes"
      }
    when "timer_area"
      nodes << node(
        "p02:node_1",
        capability,
        operation,
        [text_slot("ha:area", "#{split}_sector_#{format('%03d', index)}")]
      )
    when "timer_delta"
      nodes << node(
        "p02:node_1",
        capability,
        operation,
        [
          entity_slot("ha:timer", target.fetch("entity_id")),
          integer_slot("ha:duration_delta_seconds", index * 60)
        ]
      )
    when "response"
      nodes << node(
        "p02:node_1",
        capability,
        operation,
        [text_slot("ha:response_text", "#{split}_#{message}")]
      )
    when "broadcast"
      nodes << node(
        "p02:node_1",
        capability,
        operation,
        [
          entity_slot("ha:entity", target.fetch("entity_id")),
          text_slot("ha:message", "#{split}_#{message}")
        ]
      )
    else
      raise Failure, "unknown case kind #{intent.fetch('case_kind')}"
    end

    {
      "outcome" => "plan",
      "intent" => intent.fetch("intent"),
      "catalog_generation" => 1,
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

  def build_semantic_case(spec, intent, split, index)
    corpus = spec.fetch("corpus")
    target, target2, parameters, message =
      build_case_values(intent, split, index)
    utterance = format(intent.fetch("templates").fetch(split), parameters)
    context = {
      "catalog_generation" => 1,
      "session_snapshot_id" =>
        "p02:#{split}_#{slug(intent.fetch('intent'))}_#{format('%03d', index)}"
    }
    expected = expected_plan(
      intent,
      split,
      index,
      target,
      target2,
      message
    )
    identity_payload = {"context" => context, "expected" => expected}
    record_id =
      "p02-v1-#{split}-#{slug(intent.fetch('intent'))}-#{format('%03d', index)}"

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
        "family" =>
          "#{split}-#{slug(intent.fetch('intent'))}-family-v1",
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
    cases = spec.fetch("fail_closed_suites").fetch(suite_id)
    cases.each_with_index.map do |definition, offset|
      index = offset + 1
      expected = {
        "outcome" => definition.fetch("expected_outcome"),
        "reason" => definition.fetch("reason")
      }
      context = {
        "condition" => definition.fetch("coverage_class"),
        "catalog_generation" => suite_id == "stale_state" ? 2 : 1
      }
      record_id =
        "p02-v1-suite-#{suite_id.tr('_', '-')}-#{format('%03d', index)}"
      utterance = definition.fetch("utterance")
      {
        "schema_version" => 1,
        "suite_id" => suite_id,
        "case_id" => record_id,
        "generator_record_id" => "generator-#{record_id}",
        "canonical_semantic_id" => canonical_sha(
          {
            "suite_id" => suite_id,
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

  def build_lexicon_records(spec)
    corpus = spec.fetch("corpus")
    spec.fetch("lexicon").each_with_index.map do |entry, index|
      %w[surface lemma pos].each do |field|
        raise Failure, "lexicon #{field} must be a nonempty string" unless
          entry[field].is_a?(String) && !entry[field].empty?
      end
      raise Failure, "lexicon features must be an array of strings" unless
        entry["features"].is_a?(Array) &&
        entry["features"].all? { |feature| feature.is_a?(String) }

      {
        "schema_version" => 1,
        "analysis_id" => "p02-lexicon-#{format('%03d', index + 1)}",
        "source_id" => corpus.fetch("id"),
        "corpus_version" => corpus.fetch("version"),
        "generator_id" => corpus.fetch("generator_id"),
        "license" => corpus.fetch("license"),
        "locale" => corpus.fetch("locale"),
        "surface" => entry.fetch("surface"),
        "lemma" => entry.fetch("lemma"),
        "pos" => entry.fetch("pos"),
        "features" => entry.fetch("features").sort
      }
    end.sort_by do |entry|
      [entry.fetch("surface"), entry.fetch("pos"), entry.fetch("lemma")]
    end
  end

  def build_morphology_records(spec)
    build_lexicon_records(spec).select do |entry|
      !entry.fetch("features").empty?
    end.map do |entry|
      {
        "schema_version" => 1,
        "case_id" => entry.fetch("analysis_id").sub("lexicon", "morphology"),
        "source_id" => entry.fetch("source_id"),
        "corpus_version" => entry.fetch("corpus_version"),
        "generator_id" => entry.fetch("generator_id"),
        "license" => entry.fetch("license"),
        "locale" => entry.fetch("locale"),
        "surface" => entry.fetch("surface"),
        "expected_analyses" => [
          {
            "lemma" => entry.fetch("lemma"),
            "pos" => entry.fetch("pos"),
            "features" => entry.fetch("features")
          }
        ]
      }
    end
  end

  def token_records(text, tags)
    binary = text.b
    tokens = []
    binary.scan(/\S+/n) do
      match = Regexp.last_match
      value = match[0].dup.force_encoding(Encoding::UTF_8)
      raise Failure, "POS token is not valid UTF-8" unless value.valid_encoding?

      tag = tags.fetch(tokens.length)
      allowed = tag.is_a?(Array) ? tag : [tag]
      tokens << {
        "text" => value,
        "begin_byte" => match.begin(0),
        "end_byte" => match.end(0),
        "allowed_pos" => allowed
      }
    end
    raise Failure, "POS tag count differs from token count" unless
      tokens.length == tags.length

    tokens
  end

  def build_pos_records(spec)
    corpus = spec.fetch("corpus")
    per_split = spec.fetch("quotas").fetch("pos_per_split")
    records = []

    %w[train development heldout].each do |split|
      template = spec.fetch("pos_templates").fetch(split)
      (1..per_split).each do |index|
        noun = "ventilador"
        tags = template.fetch("tags").dup
        if template.key?("unknown_every") &&
           (index % template.fetch("unknown_every")).zero?
          noun = template.fetch("unknown_token")
          tags[template.fetch("unknown_tag_index")] = "X"
        end
        text = format(
          template.fetch("text"),
          number: index,
          scope: format("%03d", index),
          noun: noun
        )
        records << {
          "schema_version" => 1,
          "case_id" => "p02-pos-#{split}-#{format('%03d', index)}",
          "source_id" => corpus.fetch("id"),
          "corpus_version" => corpus.fetch("version"),
          "generator_id" => corpus.fetch("generator_id"),
          "license" => corpus.fetch("license"),
          "locale" => corpus.fetch("locale"),
          "split" => split,
          "family" => template.fetch("family"),
          "document_id" => "p02-pos-#{split}-doc-#{format('%02d', ((index - 1) / 10) + 1)}",
          "text" => text,
          "text_sha256" => sha256(text.encode(Encoding::UTF_8)),
          "tokens" => token_records(text, tags)
        }
      end
    end

    spec.fetch("pos_special_cases").each_with_index do |definition, index|
      text = definition.fetch("text")
      records << {
        "schema_version" => 1,
        "case_id" => "p02-pos-special-#{format('%03d', index + 1)}",
        "source_id" => corpus.fetch("id"),
        "corpus_version" => corpus.fetch("version"),
        "generator_id" => corpus.fetch("generator_id"),
        "license" => corpus.fetch("license"),
        "locale" => corpus.fetch("locale"),
        "split" => definition.fetch("split"),
        "family" => definition.fetch("family"),
        "document_id" => "p02-pos-special-doc-#{format('%03d', index + 1)}",
        "text" => text,
        "text_sha256" => sha256(text.encode(Encoding::UTF_8)),
        "tokens" => token_records(text, definition.fetch("tags")),
        "ambiguity_preserved" => definition.fetch("ambiguity_preserved")
      }
    end
    records
  end

  def json_lines(records)
    records.map { |record| JSON.generate(record) }.join("\n") + "\n"
  end

  def dimension_counts(records)
    dimensions = records.first.fetch("dimensions").keys
    dimensions.each_with_object({}) do |dimension, result|
      counts = Hash.new(0)
      records.each do |record|
        counts[record.fetch("dimensions").fetch(dimension)] += 1
      end
      result[dimension] = counts.keys.sort.each_with_object({}) do |key, ordered|
        ordered[key] = counts.fetch(key)
      end
    end
  end

  def validate_specification!(spec)
    exact_keys!(
      spec,
      %w[
        schema_version
        corpus
        home_assistant_contract
        quotas
        dimensions
        split_policy
        intents
        fail_closed_suites
        lexicon
        pos_templates
        pos_special_cases
      ],
      "specification"
    )
    raise Failure, "unsupported specification version" unless
      spec.fetch("schema_version") == 1

    corpus = spec.fetch("corpus")
    exact_keys!(
      corpus,
      %w[
        id
        version
        status
        authorization
        locale
        license
        claim_scope
        generator_id
        oracle_origin
        self_oracle_allowed
      ],
      "corpus"
    )
    expected_corpus = {
      "id" => "project-authored-synthetic-ptbr-v1",
      "version" => "1.0.0",
      "status" => "PROJECT_AUTHORED_SYNTHETIC",
      "authorization" => "USR-016",
      "locale" => "pt-BR",
      "license" => "Apache-2.0",
      "claim_scope" => "internal_conformance_only",
      "generator_id" => "p02-generator-v1",
      "oracle_origin" => "pre_engine_generator_specification",
      "self_oracle_allowed" => false
    }
    raise Failure, "corpus contract differs" unless corpus == expected_corpus

    intents = spec.fetch("intents")
    raise Failure, "intent taxonomy differs from Home Assistant contract" unless
      intents.map { |intent| intent.fetch("intent") } == OFFICIAL_INTENTS
    raise Failure, "intent taxonomy contains duplicate IDs" unless
      intents.map { |intent| intent.fetch("intent") }.uniq.length == intents.length
    intents.each do |intent|
      templates = intent.fetch("templates")
      raise Failure, "intent templates do not cover every split" unless
        templates.keys == SPLITS
      templates.each_value do |template|
        raise Failure, "intent template must be nonempty UTF-8" unless
          template.is_a?(String) && !template.empty? && template.valid_encoding?
      end
    end

    suites = spec.fetch("fail_closed_suites")
    raise Failure, "suite taxonomy differs" unless suites.keys == SUITE_IDS
    suites.each do |suite_id, definitions|
      raise Failure, "suite #{suite_id} is empty" unless
        definitions.is_a?(Array) && !definitions.empty?
      classes = definitions.map { |definition| definition.fetch("coverage_class") }
      raise Failure, "suite #{suite_id} has duplicate classes" unless
        classes.uniq.length == classes.length
    end

    quota = spec.fetch("quotas").fetch("minimum_per_supported_stratum")
    raise Failure, "held-out quota is below per-stratum minimum" unless
      case_count(spec, "heldout") >= quota
    raise Failure, "performance quota is below per-stratum minimum" unless
      case_count(spec, "performance") >= quota
  end

  def build_artifacts(spec)
    artifacts = {}
    semantic_records = {}
    SPLITS.each do |split|
      records = build_semantic_records(spec, split)
      semantic_records[split] = records
      artifacts["#{split}.jsonl"] = json_lines(records)
    end
    artifacts["lexicon.jsonl"] = json_lines(build_lexicon_records(spec))
    artifacts["morphology.jsonl"] = json_lines(build_morphology_records(spec))
    artifacts["pos-context.jsonl"] = json_lines(build_pos_records(spec))
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
      "schema_version" => 1,
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
      "freeze" => {
        "state" => "FROZEN_PRE_IMPLEMENTATION",
        "sequence" => "P02_CANDIDATE_1_PRE_ENGINE",
        "before_nlu_implementation" => true,
        "family_disjoint" => true,
        "text_disjoint" => true,
        "semantic_identity_disjoint" => true,
        "heldout_access_after_freeze" => "aggregate_runner_only",
        "self_oracle_allowed" => false
      },
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

  def generate(output_root)
    spec = load_spec
    validate_specification!(spec)
    artifacts, semantic_records = build_artifacts(spec)
    manifest = build_manifest(spec, artifacts, semantic_records)
    artifacts[MANIFEST_PATH] = JSON.pretty_generate(manifest) + "\n"

    artifacts.each do |relative, bytes|
      path = File.join(output_root, relative)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, bytes)
    end
    artifacts.keys.sort
  end

  def check_generated!
    Dir.mktmpdir("p02-corpus-check.") do |temporary|
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
          File.binread(committed) == File.binread(generated)
      end
    end
  end

  module GeneratorCLI
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
        P02Corpus.check_generated!
        puts "P02_CORPUS_GENERATION_CHECK_PASS"
      else
        paths = P02Corpus.generate(options.fetch(:output))
        puts "P02_CORPUS_GENERATED #{paths.length}"
      end
    rescue Failure, OptionParser::ParseError, KeyError, TypeError => error
      warn "P02_CORPUS_GENERATION_FAIL: #{error.message}"
      exit 1
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  warn "invoke tools/generate-p02-corpus"
  exit 1
end
