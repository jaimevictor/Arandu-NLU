# frozen_string_literal: true

require "digest"
require "json"
require "optparse"
require "set"
require_relative "generate-p02-corpus"

module P02Validation
  class Failure < StandardError; end
  class DuplicateKey < StandardError; end

  class DuplicateRejectingHash < Hash
    def []=(key, value)
      raise DuplicateKey, key if key?(key)

      super
    end
  end

  ROOT = P02Corpus::ROOT
  DATA_ROOT = P02Corpus::DATA_ROOT
  MAX_ARTIFACT_BYTES = 20 * 1024 * 1024
  MAX_LINE_BYTES = 256 * 1024
  MAX_RECORDS = 20_000
  IDENTIFIER = /\A[a-z0-9][a-z0-9._-]+\z/.freeze
  CORE_IDENTIFIER = /\A[a-z][a-z0-9_-]*:[a-z][a-z0-9_-]*\z/.freeze
  SHA256 = /\A[0-9a-f]{64}\z/.freeze
  SEMANTIC_FIELDS = %w[
    schema_version
    case_id
    generator_record_id
    canonical_semantic_id
    source_id
    corpus_version
    generator_id
    oracle_origin
    license
    locale
    split
    utterance
    utterance_sha256
    context
    dimensions
    expected
  ].freeze
  DIMENSION_FIELDS = %w[
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
  SUITE_FIELDS = %w[
    schema_version
    suite_id
    case_id
    generator_record_id
    canonical_semantic_id
    coverage_class
    source_id
    corpus_version
    generator_id
    oracle_origin
    license
    locale
    utterance
    utterance_sha256
    context
    expected
  ].freeze

  class Validator
    def initialize(data_root: DATA_ROOT, check_generation: true)
      @data_root = File.expand_path(data_root)
      @check_generation = check_generation
      @spec_path = File.join(@data_root, "specification.yaml")
    end

    def validate
      validate_path_set
      @spec = P02Corpus.load_spec(@spec_path)
      P02Corpus.validate_specification!(@spec)
      validate_schemas
      @manifest = parse_json_file(File.join(@data_root, "manifest.json"))
      validate_manifest_contract

      semantic = P02Corpus::SPLITS.each_with_object({}) do |split, records|
        records[split] = parse_json_lines(
          File.join(@data_root, "#{split}.jsonl")
        )
        validate_semantic_records(records.fetch(split), split)
      end
      validate_semantic_collections(semantic)
      validate_suites
      validate_lexicon
      validate_morphology
      validate_pos
      validate_artifact_bindings
      validate_generated_reproduction if @check_generation
      true
    rescue P02Corpus::Failure => error
      raise Failure, error.message
    end

    private

    def validate_path_set
      expected = (
        P02Corpus::ARTIFACT_PATHS +
        [P02Corpus::MANIFEST_PATH, "specification.yaml"]
      ).sort
      actual = Dir.glob(
        File.join(@data_root, "**/*"),
        File::FNM_DOTMATCH
      ).select { |path| File.file?(path) || File.symlink?(path) }
        .map { |path| path.delete_prefix("#{@data_root}/") }
        .reject { |path| %w[. ..].include?(path) }
        .sort
      raise Failure, "P02 data path set differs" unless actual == expected

      actual.each do |relative|
        path = File.join(@data_root, relative)
        raise Failure, "P02 artifact is a symlink: #{relative}" if
          File.symlink?(path)
        raise Failure, "P02 artifact is not a regular file: #{relative}" unless
          File.file?(path)
        raise Failure, "P02 artifact exceeds byte limit: #{relative}" if
          File.size(path) > MAX_ARTIFACT_BYTES
      end
    end

    def validate_schemas
      %w[
        schemas/p02-case-v1.schema.json
        schemas/p02-suite-case-v1.schema.json
        schemas/p02-corpus-manifest-v1.schema.json
      ].each do |relative|
        schema = parse_json_file(File.join(ROOT, relative))
        raise Failure, "schema is not a closed object schema: #{relative}" unless
          schema["type"] == "object" && schema["additionalProperties"] == false
        required = schema["required"]
        raise Failure, "schema has no required fields: #{relative}" unless
          required.is_a?(Array) && !required.empty? && required.uniq == required
      end
    end

    def read_utf8(path)
      bytes = File.binread(path)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      raise Failure, "invalid UTF-8: #{path}" unless text.valid_encoding?

      text
    end

    def parse_json(bytes, context)
      JSON.parse(
        bytes,
        object_class: DuplicateRejectingHash,
        max_nesting: 64
      )
    rescue JSON::ParserError, JSON::NestingError, DuplicateKey => error
      raise Failure, "invalid JSON in #{context}: #{error.class}"
    end

    def parse_json_file(path)
      value = parse_json(read_utf8(path), path)
      raise Failure, "JSON root is not a mapping: #{path}" unless
        value.is_a?(Hash)

      value
    end

    def parse_json_lines(path)
      records = []
      read_utf8(path).each_line.with_index(1) do |line, number|
        raise Failure, "blank JSONL line in #{path}:#{number}" if line.strip.empty?
        raise Failure, "oversized JSONL line in #{path}:#{number}" if
          line.bytesize > MAX_LINE_BYTES
        value = parse_json(line, "#{path}:#{number}")
        raise Failure, "JSONL record is not a mapping in #{path}:#{number}" unless
          value.is_a?(Hash)
        records << value
        raise Failure, "too many JSONL records in #{path}" if
          records.length > MAX_RECORDS
      end
      raise Failure, "empty JSONL artifact: #{path}" if records.empty?

      records
    end

    def exact_keys!(mapping, expected, context)
      raise Failure, "#{context} is not a mapping" unless mapping.is_a?(Hash)
      return if mapping.keys.sort == expected.sort

      raise Failure, "#{context} fields differ"
    end

    def string!(value, context)
      raise Failure, "#{context} must be a nonempty UTF-8 string" unless
        value.is_a?(String) && !value.empty? && value.valid_encoding?
    end

    def id!(value, context, pattern = IDENTIFIER)
      string!(value, context)
      raise Failure, "#{context} has invalid identifier syntax" unless
        value.match?(pattern)
    end

    def sha!(value, context)
      string!(value, context)
      raise Failure, "#{context} is not a SHA-256" unless value.match?(SHA256)
    end

    def common_provenance!(record, context)
      corpus = @spec.fetch("corpus")
      raise Failure, "#{context} source differs" unless
        record.fetch("source_id") == corpus.fetch("id")
      raise Failure, "#{context} corpus version differs" unless
        record.fetch("corpus_version") == corpus.fetch("version")
      raise Failure, "#{context} generator differs" unless
        record.fetch("generator_id") == corpus.fetch("generator_id")
      raise Failure, "#{context} has a self-derived oracle" unless
        record.fetch("oracle_origin") == "pre_engine_generator_specification"
      raise Failure, "#{context} license differs" unless
        record.fetch("license") == "Apache-2.0"
      raise Failure, "#{context} locale differs" unless
        record.fetch("locale") == "pt-BR"
    end

    def validate_manifest_contract
      exact_keys!(
        @manifest,
        %w[schema_version corpus contract freeze quotas taxonomies artifacts],
        "manifest"
      )
      raise Failure, "manifest schema differs" unless
        @manifest.fetch("schema_version") == 1

      corpus = @manifest.fetch("corpus")
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
          specification_sha256
          generator_sha256
        ],
        "manifest corpus"
      )
      spec_corpus = @spec.fetch("corpus")
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
      ].each do |field|
        raise Failure, "manifest corpus #{field} differs" unless
          corpus.fetch(field) == spec_corpus.fetch(field)
      end
      raise Failure, "manifest makes an external accuracy claim" unless
        corpus.fetch("claim_scope") == "internal_conformance_only"
      raise Failure, "specification hash differs" unless
        corpus.fetch("specification_sha256") ==
        Digest::SHA256.file(@spec_path).hexdigest
      raise Failure, "generator hash differs" unless
        corpus.fetch("generator_sha256") ==
        Digest::SHA256.file(P02Corpus::GENERATOR_PATH).hexdigest

      raise Failure, "Home Assistant contract identity differs" unless
        @manifest.fetch("contract") == @spec.fetch("home_assistant_contract")
      raise Failure, "quota manifest differs" unless
        @manifest.fetch("quotas") == @spec.fetch("quotas")

      freeze = @manifest.fetch("freeze")
      exact_keys!(
        freeze,
        %w[
          state
          sequence
          before_nlu_implementation
          family_disjoint
          text_disjoint
          semantic_identity_disjoint
          heldout_access_after_freeze
          self_oracle_allowed
        ],
        "freeze"
      )
      expected_freeze = {
        "state" => "FROZEN_PRE_IMPLEMENTATION",
        "sequence" => "P02_CANDIDATE_1_PRE_ENGINE",
        "before_nlu_implementation" => true,
        "family_disjoint" => true,
        "text_disjoint" => true,
        "semantic_identity_disjoint" => true,
        "heldout_access_after_freeze" => "aggregate_runner_only",
        "self_oracle_allowed" => false
      }
      raise Failure, "freeze contract differs" unless freeze == expected_freeze
    end

    def validate_semantic_records(records, split)
      records.each_with_index do |record, offset|
        context = "#{split} case #{offset + 1}"
        exact_keys!(record, SEMANTIC_FIELDS, context)
        raise Failure, "#{context} schema differs" unless
          record.fetch("schema_version") == 1
        id!(record.fetch("case_id"), "#{context} case ID")
        id!(record.fetch("generator_record_id"), "#{context} generator ID")
        sha!(record.fetch("canonical_semantic_id"), "#{context} semantic ID")
        common_provenance!(record, context)
        raise Failure, "#{context} split differs" unless
          record.fetch("split") == split
        utterance = record.fetch("utterance")
        string!(utterance, "#{context} utterance")
        raise Failure, "#{context} utterance hash differs" unless
          record.fetch("utterance_sha256") == Digest::SHA256.hexdigest(utterance)

        dimensions = record.fetch("dimensions")
        exact_keys!(dimensions, DIMENSION_FIELDS, "#{context} dimensions")
        dimensions.each do |name, value|
          string!(value, "#{context} dimension #{name}")
        end
        raise Failure, "#{context} source dimension differs" unless
          dimensions.fetch("source") == record.fetch("source_id")
        raise Failure, "#{context} outcome dimension differs" unless
          dimensions.fetch("outcome") == "plan"
        raise Failure, "#{context} ambiguity dimension differs" unless
          dimensions.fetch("ambiguity") == "unambiguous"
        raise Failure, "#{context} noise dimension differs" unless
          dimensions.fetch("noise") == "clean_text"

        validate_expected_plan(
          record.fetch("expected"),
          dimensions,
          context
        )
        computed_identity = P02Corpus.canonical_sha(
          {
            "context" => record.fetch("context"),
            "expected" => record.fetch("expected")
          }
        )
        raise Failure, "#{context} semantic identity differs" unless
          computed_identity == record.fetch("canonical_semantic_id")
      end
    end

    def validate_expected_plan(expected, dimensions, context)
      exact_keys!(
        expected,
        %w[outcome intent catalog_generation nodes relations],
        "#{context} expected"
      )
      raise Failure, "#{context} expected outcome is not plan" unless
        expected.fetch("outcome") == "plan"
      raise Failure, "#{context} expected intent differs" unless
        expected.fetch("intent") == dimensions.fetch("intent")
      raise Failure, "#{context} catalog generation differs" unless
        expected.fetch("catalog_generation") == 1

      nodes = expected.fetch("nodes")
      relations = expected.fetch("relations")
      raise Failure, "#{context} nodes must be nonempty" unless
        nodes.is_a?(Array) && !nodes.empty? && nodes.length <= 2
      raise Failure, "#{context} relations must be an array" unless
        relations.is_a?(Array)
      node_ids = nodes.map.with_index do |node, index|
        exact_keys!(
          node,
          %w[id capability operation slots],
          "#{context} node #{index + 1}"
        )
        id!(node.fetch("id"), "#{context} node ID", CORE_IDENTIFIER)
        id!(node.fetch("capability"), "#{context} capability", CORE_IDENTIFIER)
        id!(node.fetch("operation"), "#{context} operation", CORE_IDENTIFIER)
        slots = node.fetch("slots")
        raise Failure, "#{context} slots must be a nonempty array" unless
          slots.is_a?(Array) && !slots.empty?
        slot_ids = slots.map.with_index do |slot, slot_index|
          exact_keys!(
            slot,
            %w[id kind value],
            "#{context} slot #{slot_index + 1}"
          )
          id!(slot.fetch("id"), "#{context} slot ID", CORE_IDENTIFIER)
          string!(slot.fetch("kind"), "#{context} slot kind")
          slot.fetch("id")
        end
        raise Failure, "#{context} slot IDs are not unique and sorted" unless
          slot_ids == slot_ids.uniq.sort
        node.fetch("id")
      end
      raise Failure, "#{context} node IDs are not unique" unless
        node_ids.uniq.length == node_ids.length

      case dimensions.fetch("graph_shape")
      when "single"
        raise Failure, "#{context} single graph shape differs" unless
          nodes.length == 1 && relations.empty?
      when "parallel_pair"
        raise Failure, "#{context} parallel graph shape differs" unless
          nodes.length == 2 && relations.empty?
      when "ordered_pair"
        raise Failure, "#{context} ordered graph shape differs" unless
          nodes.length == 2 && relations.length == 1
        relation = relations.first
        exact_keys!(relation, %w[from to kind], "#{context} relation")
        raise Failure, "#{context} ordered relation differs" unless
          relation == {
            "from" => "p02:node_1",
            "to" => "p02:node_2",
            "kind" => "precedes"
          }
      else
        raise Failure, "#{context} graph shape is unsupported"
      end
    end

    def expected_strata(split, dimension)
      intents = @spec.fetch("intents")
      case dimension
      when "source"
        [@spec.fetch("corpus").fetch("id")]
      when "family"
        intents.map do |intent|
          "#{split}-#{P02Corpus.slug(intent.fetch('intent'))}-family-v1"
        end
      when "intent"
        P02Corpus::OFFICIAL_INTENTS
      when "domain"
        intents.map { |intent| intent.fetch("domain") }.uniq.sort
      when "slot_kind"
        intents.map { |intent| intent.fetch("primary_slot_kind") }.uniq.sort
      when "graph_shape"
        intents.map { |intent| intent.fetch("graph_shape") }.uniq.sort
      when "outcome"
        ["plan"]
      when "ambiguity"
        ["unambiguous"]
      when "noise"
        ["clean_text"]
      else
        raise Failure, "unknown mandatory dimension #{dimension}"
      end
    end

    def validate_quota(records, split)
      quota = @spec.fetch("quotas").fetch("minimum_per_supported_stratum")
      @spec.fetch("dimensions").each do |dimension|
        counts = Hash.new(0)
        records.each do |record|
          counts[record.fetch("dimensions").fetch(dimension)] += 1
        end
        expected = expected_strata(split, dimension)
        raise Failure, "#{split} #{dimension} strata differ" unless
          counts.keys.sort == expected.sort
        counts.each do |stratum, count|
          raise Failure, "#{split} #{dimension} stratum under quota: #{stratum}" if
            count < quota
        end
      end
    end

    def unique_values!(records, field, context)
      values = records.map { |record| record.fetch(field) }
      raise Failure, "duplicate #{context}" unless values.uniq.length == values.length
    end

    def validate_semantic_collections(collections)
      all = collections.values.flatten
      unique_values!(all, "case_id", "semantic case ID")
      unique_values!(all, "generator_record_id", "generator record ID")
      unique_values!(all, "canonical_semantic_id", "semantic identity")
      unique_values!(all, "utterance", "semantic utterance")

      family_splits = {}
      collections.each do |split, records|
        expected_count =
          @spec.fetch("intents").length * P02Corpus.case_count(@spec, split)
        raise Failure, "#{split} record count differs" unless
          records.length == expected_count
        records.each do |record|
          family = record.fetch("dimensions").fetch("family")
          previous = family_splits[family]
          raise Failure, "family crosses semantic splits: #{family}" if
            previous && previous != split
          family_splits[family] = split
        end
      end

      heldout = collections.fetch("heldout")
      minimum = @spec.fetch("quotas").fetch("minimum_scored_cases")
      raise Failure, "held-out scored corpus is below the global minimum" if
        heldout.length < minimum
      validate_quota(heldout, "heldout")
      validate_quota(collections.fetch("performance"), "performance")

      taxonomies = @manifest.fetch("taxonomies")
      exact_keys!(
        taxonomies,
        %w[
          dimensions
          intents
          heldout_counts
          performance_counts
          suite_classes
        ],
        "manifest taxonomies"
      )
      raise Failure, "manifest dimensions differ" unless
        taxonomies.fetch("dimensions") == @spec.fetch("dimensions")
      raise Failure, "manifest intent taxonomy differs" unless
        taxonomies.fetch("intents") == P02Corpus::OFFICIAL_INTENTS
      raise Failure, "held-out manifest counts differ" unless
        taxonomies.fetch("heldout_counts") ==
        P02Corpus.dimension_counts(heldout)
      raise Failure, "performance manifest counts differ" unless
        taxonomies.fetch("performance_counts") ==
        P02Corpus.dimension_counts(collections.fetch("performance"))
    end

    def validate_suites
      all = []
      expected_taxonomy = {}
      P02Corpus::SUITE_IDS.each do |suite_id|
        path = File.join(
          @data_root,
          "suites/#{suite_id.tr('_', '-')}.jsonl"
        )
        records = parse_json_lines(path)
        definitions =
          @spec.fetch("fail_closed_suites").fetch(suite_id)
        expected_classes =
          definitions.map { |definition| definition.fetch("coverage_class") }
        actual_classes = records.map { |record| record.fetch("coverage_class") }
        raise Failure, "suite #{suite_id} coverage differs" unless
          actual_classes == expected_classes
        raise Failure, "suite #{suite_id} has duplicate classes" unless
          actual_classes.uniq.length == actual_classes.length
        expected_taxonomy[suite_id] = expected_classes

        records.each_with_index do |record, index|
          context = "#{suite_id} suite case #{index + 1}"
          exact_keys!(record, SUITE_FIELDS, context)
          raise Failure, "#{context} schema differs" unless
            record.fetch("schema_version") == 1
          raise Failure, "#{context} suite ID differs" unless
            record.fetch("suite_id") == suite_id
          id!(record.fetch("case_id"), "#{context} case ID")
          id!(record.fetch("generator_record_id"), "#{context} generator ID")
          sha!(record.fetch("canonical_semantic_id"), "#{context} semantic ID")
          common_provenance!(record, context)
          utterance = record.fetch("utterance")
          string!(utterance, "#{context} utterance")
          raise Failure, "#{context} utterance hash differs" unless
            record.fetch("utterance_sha256") ==
            Digest::SHA256.hexdigest(utterance)
          expected = record.fetch("expected")
          exact_keys!(expected, %w[outcome reason], "#{context} expected")
          raise Failure, "#{context} permits a plan" unless
            %w[clarification abstention].include?(expected.fetch("outcome"))
          string!(expected.fetch("reason"), "#{context} reason")
          computed = P02Corpus.canonical_sha(
            {
              "suite_id" => suite_id,
              "coverage_class" => record.fetch("coverage_class"),
              "utterance" => utterance,
              "context" => record.fetch("context"),
              "expected" => expected
            }
          )
          raise Failure, "#{context} semantic identity differs" unless
            computed == record.fetch("canonical_semantic_id")
        end
        all.concat(records)
      end
      unique_values!(all, "case_id", "suite case ID")
      unique_values!(all, "generator_record_id", "suite generator record ID")
      unique_values!(all, "canonical_semantic_id", "suite semantic identity")
      unique_values!(all, "utterance", "suite utterance")
      raise Failure, "manifest suite taxonomy differs" unless
        @manifest.fetch("taxonomies").fetch("suite_classes") == expected_taxonomy
    end

    def validate_lexicon
      records = parse_json_lines(File.join(@data_root, "lexicon.jsonl"))
      triples = Set.new
      ids = Set.new
      analyses_by_surface = Hash.new { |hash, key| hash[key] = Set.new }
      records.each_with_index do |record, index|
        context = "lexicon record #{index + 1}"
        exact_keys!(
          record,
          %w[
            schema_version
            analysis_id
            source_id
            corpus_version
            generator_id
            license
            locale
            surface
            lemma
            pos
            features
          ],
          context
        )
        raise Failure, "#{context} schema differs" unless
          record.fetch("schema_version") == 1
        common_language_provenance!(record, context)
        id!(record.fetch("analysis_id"), "#{context} analysis ID")
        %w[surface lemma pos].each do |field|
          string!(record.fetch(field), "#{context} #{field}")
        end
        features = record.fetch("features")
        raise Failure, "#{context} features differ" unless
          features.is_a?(Array) &&
          features.all? { |feature| feature.is_a?(String) } &&
          features == features.uniq.sort
        raise Failure, "duplicate lexicon analysis ID" unless
          ids.add?(record.fetch("analysis_id"))
        triple = [
          record.fetch("surface"),
          record.fetch("lemma"),
          record.fetch("pos")
        ]
        raise Failure, "duplicate lexicon analysis" unless triples.add?(triple)
        analyses_by_surface[record.fetch("surface")].add(record.fetch("pos"))
      end
      raise Failure, "lexicon lacks preserved liga ambiguity" unless
        analyses_by_surface["liga"] == Set.new(%w[NOUN VERB])
    end

    def common_language_provenance!(record, context)
      corpus = @spec.fetch("corpus")
      raise Failure, "#{context} source differs" unless
        record.fetch("source_id") == corpus.fetch("id")
      raise Failure, "#{context} version differs" unless
        record.fetch("corpus_version") == corpus.fetch("version")
      raise Failure, "#{context} generator differs" unless
        record.fetch("generator_id") == corpus.fetch("generator_id")
      raise Failure, "#{context} license differs" unless
        record.fetch("license") == corpus.fetch("license")
      raise Failure, "#{context} locale differs" unless
        record.fetch("locale") == corpus.fetch("locale")
    end

    def validate_morphology
      records = parse_json_lines(File.join(@data_root, "morphology.jsonl"))
      ids = Set.new
      records.each_with_index do |record, index|
        context = "morphology record #{index + 1}"
        exact_keys!(
          record,
          %w[
            schema_version
            case_id
            source_id
            corpus_version
            generator_id
            license
            locale
            surface
            expected_analyses
          ],
          context
        )
        raise Failure, "#{context} schema differs" unless
          record.fetch("schema_version") == 1
        common_language_provenance!(record, context)
        id!(record.fetch("case_id"), "#{context} case ID")
        raise Failure, "duplicate morphology case ID" unless
          ids.add?(record.fetch("case_id"))
        string!(record.fetch("surface"), "#{context} surface")
        analyses = record.fetch("expected_analyses")
        raise Failure, "#{context} analyses must be nonempty" unless
          analyses.is_a?(Array) && !analyses.empty?
        analyses.each do |analysis|
          exact_keys!(analysis, %w[lemma pos features], "#{context} analysis")
          string!(analysis.fetch("lemma"), "#{context} lemma")
          string!(analysis.fetch("pos"), "#{context} POS")
          raise Failure, "#{context} analysis features must be nonempty" unless
            analysis.fetch("features").is_a?(Array) &&
            !analysis.fetch("features").empty?
        end
      end
    end

    def validate_pos
      records = parse_json_lines(File.join(@data_root, "pos-context.jsonl"))
      ids = Set.new
      texts = Set.new
      family_splits = {}
      split_counts = Hash.new(0)
      unknown_seen = false
      ambiguity_seen = false
      records.each_with_index do |record, index|
        context = "POS record #{index + 1}"
        required = %w[
          schema_version
          case_id
          source_id
          corpus_version
          generator_id
          license
          locale
          split
          family
          document_id
          text
          text_sha256
          tokens
        ]
        allowed = required + ["ambiguity_preserved"]
        raise Failure, "#{context} fields differ" unless
          (record.keys - allowed).empty? && (required - record.keys).empty?
        raise Failure, "#{context} schema differs" unless
          record.fetch("schema_version") == 1
        common_language_provenance!(record, context)
        id!(record.fetch("case_id"), "#{context} case ID")
        raise Failure, "duplicate POS case ID" unless ids.add?(record.fetch("case_id"))
        split = record.fetch("split")
        raise Failure, "#{context} split differs" unless
          %w[train development heldout].include?(split)
        family = record.fetch("family")
        string!(family, "#{context} family")
        if family_splits.key?(family) && family_splits.fetch(family) != split
          raise Failure, "POS family crosses splits"
        end
        family_splits[family] = split
        split_counts[split] += 1
        id!(record.fetch("document_id"), "#{context} document ID")
        text = record.fetch("text")
        string!(text, "#{context} text")
        raise Failure, "duplicate POS text" unless texts.add?(text)
        raise Failure, "#{context} text hash differs" unless
          record.fetch("text_sha256") == Digest::SHA256.hexdigest(text)
        validate_pos_tokens(record.fetch("tokens"), text, context)
        unknown_seen ||= record.fetch("tokens").any? do |token|
          token.fetch("allowed_pos") == ["X"]
        end
        ambiguity_seen ||= record["ambiguity_preserved"] == true
      end
      minimum = @spec.fetch("quotas").fetch("pos_per_split")
      %w[train development heldout].each do |split|
        raise Failure, "POS #{split} split is below quota" if
          split_counts.fetch(split, 0) < minimum
      end
      raise Failure, "POS corpus lacks unknown-token coverage" unless unknown_seen
      raise Failure, "POS corpus lacks preserved ambiguity coverage" unless ambiguity_seen
    end

    def validate_pos_tokens(tokens, text, context)
      raise Failure, "#{context} tokens must be nonempty" unless
        tokens.is_a?(Array) && !tokens.empty?
      previous_end = 0
      tokens.each_with_index do |token, index|
        exact_keys!(
          token,
          %w[text begin_byte end_byte allowed_pos],
          "#{context} token #{index + 1}"
        )
        begin_byte = token.fetch("begin_byte")
        end_byte = token.fetch("end_byte")
        raise Failure, "#{context} token span is invalid" unless
          begin_byte.is_a?(Integer) &&
          end_byte.is_a?(Integer) &&
          begin_byte >= previous_end &&
          begin_byte < end_byte &&
          end_byte <= text.bytesize
        slice = text.byteslice(begin_byte...end_byte)
        raise Failure, "#{context} token span text differs" unless
          slice == token.fetch("text")
        allowed = token.fetch("allowed_pos")
        raise Failure, "#{context} token POS set is invalid" unless
          allowed.is_a?(Array) &&
          !allowed.empty? &&
          allowed.all? { |tag| tag.is_a?(String) && !tag.empty? } &&
          allowed == allowed.uniq.sort
        previous_end = end_byte
      end
    end

    def validate_artifact_bindings
      entries = @manifest.fetch("artifacts")
      raise Failure, "manifest artifacts must be a nonempty array" unless
        entries.is_a?(Array) && !entries.empty?
      paths = entries.map { |entry| entry.fetch("path") }
      raise Failure, "manifest artifact paths differ" unless
        paths == P02Corpus::ARTIFACT_PATHS.sort
      entries.each do |entry|
        exact_keys!(entry, %w[path bytes sha256 records], "artifact entry")
        relative = entry.fetch("path")
        path = File.join(@data_root, relative)
        bytes = File.binread(path)
        raise Failure, "artifact byte size differs: #{relative}" unless
          entry.fetch("bytes") == bytes.bytesize
        raise Failure, "artifact hash differs: #{relative}" unless
          entry.fetch("sha256") == Digest::SHA256.hexdigest(bytes)
        raise Failure, "artifact record count differs: #{relative}" unless
          entry.fetch("records") == bytes.lines.length
      end
    end

    def validate_generated_reproduction
      P02Corpus.check_generated!
    end
  end

  module CLI
    module_function

    def run(arguments)
      options = {data_root: DATA_ROOT, check_generation: true}
      parser = OptionParser.new do |opts|
        opts.on("--data-root PATH") do |path|
          options[:data_root] = File.expand_path(path)
        end
        opts.on("--skip-generation-check") do
          options[:check_generation] = false
        end
      end
      parser.parse!(arguments)
      raise Failure, "unexpected arguments: #{arguments.join(' ')}" unless
        arguments.empty?
      if options[:data_root] != DATA_ROOT && options[:check_generation]
        raise Failure, "alternate data roots require --skip-generation-check"
      end

      Validator.new(**options).validate
      puts "P02_VALIDATION_PASS"
    rescue Failure, OptionParser::ParseError, KeyError, TypeError => error
      warn "P02_VALIDATION_FAIL: #{error.message}"
      exit 1
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  warn "invoke tools/validate-p02"
  exit 1
end
