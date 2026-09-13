# frozen_string_literal: true

require "digest"
require "json"
require "optparse"
require "set"

require_relative "generate-p02-v2-corpus"

module P02V2Validation
  class Failure < StandardError; end
  class DuplicateKeyError < StandardError; end

  class DuplicateRejectingHash < Hash
    def []=(key, value)
      raise DuplicateKeyError, key if key?(key)

      super
    end
  end

  MAX_ARTIFACT_BYTES = 16 * 1024 * 1024
  MAX_MANIFEST_BYTES = 512 * 1024
  MAX_ROW_BYTES = 16 * 1024
  MAX_SEMANTIC_RECORDS = 4_800
  MAX_SUITE_RECORDS = 7

  module_function

  def strict_json(bytes, context)
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
    raise Failure, "#{context} is invalid JSON: #{error.class}"
  end

  def read_regular(path, maximum, context)
    raise Failure, "#{context} is missing" unless File.file?(path)
    raise Failure, "#{context} must not be a symlink" if File.symlink?(path)
    size = File.size(path)
    raise Failure, "#{context} exceeds the byte limit" if size > maximum

    File.binread(path)
  rescue SystemCallError => error
    raise Failure, "#{context} cannot be read: #{error.class}"
  end

  def parse_jsonl(bytes, expected_count, maximum_count, context)
    raise Failure, "#{context} must end with a newline" unless bytes.end_with?("\n")
    rows = []
    bytes.each_line.with_index(1) do |line, line_number|
      raise Failure, "#{context} contains a blank row" if line == "\n"
      raise Failure, "#{context} row exceeds the byte limit" if
        line.bytesize > MAX_ROW_BYTES
      raise Failure, "#{context} exceeds the record limit" if
        rows.length >= maximum_count
      row = strict_json(line, "#{context} row #{line_number}")
      raise Failure, "#{context} row is not an object" unless row.is_a?(Hash)
      rows << row
    end
    raise Failure, "#{context} record count differs" unless
      rows.length == expected_count

    rows
  end

  def assert_disjoint!(sets, context)
    sets.each_with_index do |left, left_index|
      sets.each_with_index do |right, right_index|
        next unless left_index < right_index
        next if (left & right).empty?

        raise Failure, "#{context} crosses partitions"
      end
    end
  end

  def validate_integrity_entries!(root, entries)
    paths = entries.map { |entry| entry.fetch("path") }
    raise Failure, "manifest artifact paths are not sorted and unique" unless
      paths == paths.sort && paths.uniq.length == paths.length
    expected = P02V2Corpus::ARTIFACT_PATHS.sort
    raise Failure, "manifest artifact path set differs" unless paths == expected

    entries.each do |entry|
      P02V2Corpus.exact_keys!(
        entry,
        %w[path bytes sha256 records],
        "manifest artifact"
      )
      path = entry.fetch("path")
      bytes = read_regular(
        File.join(root, path),
        MAX_ARTIFACT_BYTES,
        "artifact #{path}"
      )
      raise Failure, "artifact byte count differs" unless
        entry.fetch("bytes") == bytes.bytesize
      raise Failure, "artifact SHA-256 differs" unless
        entry.fetch("sha256") == Digest::SHA256.hexdigest(bytes)
      raise Failure, "artifact record count differs" unless
        entry.fetch("records") == bytes.lines.length
    end
  end

  class Validator
    def initialize(data_root)
      @data_root = File.expand_path(data_root)
      @spec = P02V2Corpus.load_spec
      P02V2Corpus.validate_specification!(@spec)
    end

    def validate
      expected_bytes = P02V2Corpus.generated_bytes
      validate_path_set(expected_bytes.keys)
      expected_bytes.each do |relative, bytes|
        actual = P02V2Validation.read_regular(
          File.join(@data_root, relative),
          relative == P02V2Corpus::MANIFEST_PATH ?
            MAX_MANIFEST_BYTES : MAX_ARTIFACT_BYTES,
          relative
        )
        raise Failure, "generated artifact differs: #{relative}" unless
          actual.b == bytes.b
      end

      manifest_bytes = P02V2Validation.read_regular(
        File.join(@data_root, P02V2Corpus::MANIFEST_PATH),
        MAX_MANIFEST_BYTES,
        "manifest"
      )
      manifest = P02V2Validation.strict_json(manifest_bytes, "manifest")
      validate_manifest(manifest)
      P02V2Validation.validate_integrity_entries!(
        @data_root,
        manifest.fetch("artifacts")
      )
      semantic = validate_semantic_splits
      validate_partition_separation(semantic)
      validate_suites(semantic)
      true
    end

    private

    def validate_path_set(expected_paths)
      actual = Dir.glob("**/*", File::FNM_DOTMATCH, base: @data_root)
        .reject { |path| path == "." || path == ".." }
        .select { |path| File.file?(File.join(@data_root, path)) }
        .sort
      required = (expected_paths + ["specification.json"]).sort
      raise Failure, "tracked corpus path set differs" unless actual == required
      actual.each do |relative|
        raise Failure, "corpus path contains a symlink" if
          File.symlink?(File.join(@data_root, relative))
      end
    end

    def validate_manifest(manifest)
      P02V2Corpus.exact_keys!(
        manifest,
        %w[
          schema_version
          corpus
          contract
          semantic_contract
          freeze
          split_policy
          generalization_contract_sha256
          quotas
          taxonomies
          artifacts
        ],
        "manifest"
      )
      raise Failure, "manifest schema differs" unless
        manifest.fetch("schema_version") == 2
      corpus = manifest.fetch("corpus")
      P02V2Corpus.exact_keys!(
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
      expected_corpus = P02V2Corpus::EXPECTED_CORPUS.reject do |key, _value|
        key == "self_oracle_allowed"
      end
      expected_corpus.each do |field, value|
        raise Failure, "manifest corpus #{field} differs" unless
          corpus.fetch(field) == value
      end
      raise Failure, "manifest specification hash differs" unless
        corpus.fetch("specification_sha256") ==
          Digest::SHA256.file(P02V2Corpus::SPEC_PATH).hexdigest
      raise Failure, "manifest generator hash differs" unless
        corpus.fetch("generator_sha256") ==
          Digest::SHA256.file(P02V2Corpus::GENERATOR_PATH).hexdigest
      raise Failure, "manifest external contract differs" unless
        manifest.fetch("contract") == @spec.fetch("home_assistant_contract")
      raise Failure, "manifest semantic contract differs" unless
        manifest.fetch("semantic_contract") ==
          @spec.fetch("semantic_contract")
      raise Failure, "manifest freeze differs" unless
        manifest.fetch("freeze") == @spec.fetch("freeze")
      raise Failure, "manifest split policy differs" unless
        manifest.fetch("split_policy") == @spec.fetch("split_policy")
      raise Failure, "manifest generalization identity differs" unless
        manifest.fetch("generalization_contract_sha256") ==
          P02V2Corpus.canonical_sha(
            @spec.fetch("generalization_contract")
          )
      raise Failure, "manifest quotas differ" unless
        manifest.fetch("quotas") == @spec.fetch("quotas")

      taxonomies = manifest.fetch("taxonomies")
      P02V2Corpus.exact_keys!(
        taxonomies,
        %w[
          dimensions
          intents
          heldout_counts
          performance_counts
          suite_classes
          suite_families
        ],
        "manifest taxonomies"
      )
      raise Failure, "manifest dimensions differ" unless
        taxonomies.fetch("dimensions") == P02V2Corpus::DIMENSIONS
      raise Failure, "manifest intent taxonomy differs" unless
        taxonomies.fetch("intents") == P02V2Corpus::OFFICIAL_INTENTS
    end

    def validate_semantic_splits
      result = {}
      P02V2Corpus::SPLITS.each do |split|
        expected = P02V2Corpus.build_semantic_records(@spec, split)
        bytes = P02V2Validation.read_regular(
          File.join(@data_root, "#{split}.jsonl"),
          MAX_ARTIFACT_BYTES,
          "#{split} corpus"
        )
        rows = P02V2Validation.parse_jsonl(
          bytes,
          P02V2Corpus.case_count(@spec, split) *
            P02V2Corpus::OFFICIAL_INTENTS.length,
          MAX_SEMANTIC_RECORDS,
          "#{split} corpus"
        )
        raise Failure, "#{split} corpus differs from specification" unless
          rows == expected
        validate_semantic_row_inventory(rows, split)
        result[split] = rows
      end

      manifest = P02V2Validation.strict_json(
        P02V2Validation.read_regular(
          File.join(@data_root, P02V2Corpus::MANIFEST_PATH),
          MAX_MANIFEST_BYTES,
          "manifest"
        ),
        "manifest"
      )
      taxonomies = manifest.fetch("taxonomies")
      raise Failure, "held-out dimension counts differ" unless
        taxonomies.fetch("heldout_counts") ==
          P02V2Corpus.dimension_counts(result.fetch("heldout"))
      raise Failure, "performance dimension counts differ" unless
        taxonomies.fetch("performance_counts") ==
          P02V2Corpus.dimension_counts(result.fetch("performance"))
      minimum = @spec.fetch("quotas").fetch("minimum_scored_cases")
      %w[heldout performance].each do |split|
        raise Failure, "#{split} corpus is below the scored minimum" unless
          result.fetch(split).length >= minimum
      end
      result
    end

    def validate_semantic_row_inventory(rows, split)
      case_ids = Set.new
      generator_ids = Set.new
      semantic_ids = Set.new
      utterances = Set.new
      families = Set.new
      rows.each do |row|
        raise Failure, "semantic row schema differs" unless
          row.fetch("schema_version") == 1
        raise Failure, "semantic source identity differs" unless
          row.fetch("source_id") ==
            P02V2Corpus::EXPECTED_CORPUS.fetch("id") &&
          row.fetch("corpus_version") ==
            P02V2Corpus::EXPECTED_CORPUS.fetch("version") &&
          row.fetch("generator_id") ==
            P02V2Corpus::EXPECTED_CORPUS.fetch("generator_id") &&
          row.fetch("oracle_origin") ==
            P02V2Corpus::EXPECTED_CORPUS.fetch("oracle_origin") &&
          row.fetch("license") == "Apache-2.0" &&
          row.fetch("locale") == "pt-BR" &&
          row.fetch("split") == split
        raise Failure, "semantic utterance hash differs" unless
          row.fetch("utterance_sha256") ==
            Digest::SHA256.hexdigest(row.fetch("utterance"))
        raise Failure, "semantic case identity is duplicated" unless
          case_ids.add?(row.fetch("case_id"))
        raise Failure, "generator record identity is duplicated" unless
          generator_ids.add?(row.fetch("generator_record_id"))
        raise Failure, "canonical semantic identity is duplicated" unless
          semantic_ids.add?(row.fetch("canonical_semantic_id"))
        raise Failure, "semantic utterance is duplicated" unless
          utterances.add?(row.fetch("utterance"))
        families.add(row.fetch("dimensions").fetch("family"))
        raise Failure, "semantic expected outcome differs" unless
          row.fetch("expected").fetch("outcome") == "plan" &&
          row.fetch("dimensions").fetch("outcome") == "plan"
      end
      raise Failure, "semantic family count differs" unless
        families.length == P02V2Corpus::OFFICIAL_INTENTS.length
    end

    def validate_partition_separation(semantic)
      fields = %w[case_id generator_record_id canonical_semantic_id utterance]
      fields.each do |field|
        sets = P02V2Corpus::SPLITS.map do |split|
          semantic.fetch(split).map { |row| row.fetch(field) }.to_set
        end
        P02V2Validation.assert_disjoint!(sets, field)
      end
      family_sets = P02V2Corpus::SPLITS.map do |split|
        semantic.fetch(split).map do |row|
          row.fetch("dimensions").fetch("family")
        end.to_set
      end
      P02V2Validation.assert_disjoint!(family_sets, "family")
      payload_sets = P02V2Corpus::SPLITS.map do |split|
        semantic.fetch(split).map do |row|
          P02V2Corpus.canonical_sha(
            {
              "context" => row.fetch("context"),
              "expected" => row.fetch("expected")
            }
          )
        end.to_set
      end
      P02V2Validation.assert_disjoint!(payload_sets, "semantic payload")

      all_case_ids = semantic.values.flatten.map { |row| row.fetch("case_id") }
      raise Failure, "new lineage case namespace differs" unless
        all_case_ids.all? { |identity| identity.start_with?("p02-v2-") }
      raise Failure, "new lineage source namespace differs" unless
        semantic.values.flatten.all? do |row|
          row.fetch("source_id") == "project-authored-synthetic-ptbr-p15-v2"
        end
    end

    def validate_suites(semantic)
      positive_utterances =
        semantic.values.flatten.map { |row| row.fetch("utterance") }.to_set
      suite_case_ids = Set.new
      suite_generator_ids = Set.new
      suite_semantic_ids = Set.new
      suite_utterances = Set.new
      manifest = P02V2Validation.strict_json(
        P02V2Validation.read_regular(
          File.join(@data_root, P02V2Corpus::MANIFEST_PATH),
          MAX_MANIFEST_BYTES,
          "manifest"
        ),
        "manifest"
      )

      P02V2Corpus::SUITE_IDS.each do |suite_id|
        expected = P02V2Corpus.build_suite_records(@spec, suite_id)
        path = "suites/#{suite_id.tr('_', '-')}.jsonl"
        bytes = P02V2Validation.read_regular(
          File.join(@data_root, path),
          MAX_ARTIFACT_BYTES,
          path
        )
        rows = P02V2Validation.parse_jsonl(
          bytes,
          @spec.fetch("quotas").fetch("suite_counts").fetch(suite_id),
          MAX_SUITE_RECORDS,
          path
        )
        raise Failure, "suite differs from specification" unless rows == expected
        rows.each do |row|
          raise Failure, "suite identity differs" unless
            row.fetch("schema_version") == 1 &&
            row.fetch("suite_id") == suite_id &&
            row.fetch("source_id") ==
              P02V2Corpus::EXPECTED_CORPUS.fetch("id") &&
            row.fetch("corpus_version") == "2.0.0" &&
            row.fetch("generator_id") ==
              "p02-qualification-generator-v2" &&
            row.fetch("oracle_origin") ==
              "pre_engine_generator_specification" &&
            row.fetch("license") == "Apache-2.0" &&
            row.fetch("locale") == "pt-BR"
          raise Failure, "suite utterance hash differs" unless
            row.fetch("utterance_sha256") ==
              Digest::SHA256.hexdigest(row.fetch("utterance"))
          raise Failure, "suite case identity is duplicated" unless
            suite_case_ids.add?(row.fetch("case_id"))
          raise Failure, "suite generator identity is duplicated" unless
            suite_generator_ids.add?(row.fetch("generator_record_id"))
          raise Failure, "suite semantic identity is duplicated" unless
            suite_semantic_ids.add?(row.fetch("canonical_semantic_id"))
          raise Failure, "suite utterance is duplicated" unless
            suite_utterances.add?(row.fetch("utterance"))
          raise Failure, "suite produced a plan oracle" if
            row.fetch("expected").fetch("outcome") == "plan"
        end
        definitions =
          @spec.fetch("fail_closed_suites").fetch(suite_id)
        taxonomy = manifest.fetch("taxonomies")
        raise Failure, "suite class taxonomy differs" unless
          taxonomy.fetch("suite_classes").fetch(suite_id) ==
            definitions.map { |definition| definition.fetch("coverage_class") }
        raise Failure, "suite family taxonomy differs" unless
          taxonomy.fetch("suite_families").fetch(suite_id) ==
            definitions.map { |definition| definition.fetch("family") }
      end
      raise Failure, "suite utterance overlaps a semantic split" unless
        (positive_utterances & suite_utterances).empty?
    end
  end

  module CLI
    module_function

    def run(arguments)
      options = {data_root: P02V2Corpus::DATA_ROOT}
      parser = OptionParser.new do |opts|
        opts.on("--data-root PATH") do |path|
          options[:data_root] = File.expand_path(path)
        end
      end
      parser.parse!(arguments)
      raise Failure, "unexpected arguments: #{arguments.join(' ')}" unless
        arguments.empty?

      Validator.new(options.fetch(:data_root)).validate
      puts "P02_V2_VALIDATION_PASS"
    rescue Failure, P02V2Corpus::Failure, KeyError, TypeError => error
      warn "P02_V2_VALIDATION_FAIL: #{error.message}"
      exit 1
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  warn "invoke tools/validate-p02-v2"
  exit 1
end
