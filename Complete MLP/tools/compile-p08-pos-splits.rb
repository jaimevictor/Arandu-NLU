# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "tmpdir"

module P08PosSplits
  class Failure < StandardError; end
  class DuplicateKey < StandardError; end

  class DuplicateRejectingHash < Hash
    def []=(key, value)
      raise DuplicateKey, key if key?(key)

      super
    end
  end

  ROOT = File.expand_path("..", __dir__)
  SOURCE_MANIFEST_PATH =
    "data/manifests/project-authored-synthetic-ptbr-v1.json"
  CORPUS_MANIFEST_PATH = "data/project-authored/p02-v1/manifest.json"
  SPECIFICATION_PATH = "data/project-authored/p02-v1/specification.yaml"
  GENERATOR_PATH = "tools/generate-p02-corpus.rb"
  SOURCE_ARTIFACT_PATH = "data/project-authored/p02-v1/pos-context.jsonl"
  CORPUS_ARTIFACT_PATH = "pos-context.jsonl"
  OUTPUT_DIRECTORY = "data/evaluation/p08/pos-v1/splits"

  SPLITS = %w[train development heldout].freeze
  ORIGIN_FIELDS = %w[source_id corpus_version generator_id].freeze
  RECORD_FIELDS = %w[
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
  ].freeze
  OPTIONAL_RECORD_FIELDS = %w[ambiguity_preserved].freeze
  TOKEN_FIELDS = %w[text begin_byte end_byte allowed_pos].freeze
  POS_LABELS = %w[ADJ ADP DET NOUN NUM VERB X].freeze
  IDENTIFIER = /\A[a-z0-9][a-z0-9._-]*\z/
  SHA256 = /\A[0-9a-f]{64}\z/
  MAX_JSON_NESTING = 32
  MAX_SOURCE_BYTES = 1_048_576
  MAX_LINE_BYTES = 32_768
  MAX_TOKENS_PER_RECORD = 256

  LINEAGE = {
    "source_id" => "project-authored-synthetic-ptbr-v1",
    "corpus_version" => "1.0.0",
    "generator_id" => "p02-generator-v1",
    "license" => "Apache-2.0",
    "locale" => "pt-BR",
    "claim_scope" => "internal_conformance_only"
  }.freeze

  EXPECTED_HASHES = {
    "source_manifest" =>
      "d9e1ca32ec0f92aa6b5fc6c1d4f232f93389e0bf8031267d23daddf7287006c5",
    "corpus_manifest" =>
      "a251485ba2f8d5032603200b7e171954213383aeceac9a8f394edb09a265e72a",
    "specification" =>
      "f72451f03d1a5e2e4955b5d2857bd7d33b3b012912d920e53a3d85719f14859d",
    "generator" =>
      "ff8817afc2c2f13d539ab7d10720cab407d769ca3a6189dcc55d43ea052689d1",
    "source_artifact" =>
      "85ad18caf3ae749d3ec0135c3c01ce6d754f831d395abdc44ff1c3643a18fac8"
  }.freeze

  EXPECTED_FILE_BYTES = {
    "source_manifest" => 6_204,
    "corpus_manifest" => 11_091,
    "specification" => 18_201,
    "generator" => 24_477,
    "source_artifact" => 222_999
  }.freeze

  EXPECTED_INVENTORIES = {
    "train" => {
      "records" => 80,
      "documents" => 8,
      "tokens" => 560,
      "families" => ["pos-command-train-v1"]
    },
    "development" => {
      "records" => 80,
      "documents" => 8,
      "tokens" => 560,
      "families" => ["pos-query-development-v1"]
    },
    "heldout" => {
      "records" => 81,
      "documents" => 9,
      "tokens" => 643,
      "families" => [
        "pos-ambiguity-heldout-v1",
        "pos-state-heldout-v1"
      ]
    }
  }.freeze

  DEFAULT_CONFIGURATION = {
    source_manifest_path: SOURCE_MANIFEST_PATH,
    corpus_manifest_path: CORPUS_MANIFEST_PATH,
    specification_path: SPECIFICATION_PATH,
    generator_path: GENERATOR_PATH,
    source_artifact_path: SOURCE_ARTIFACT_PATH,
    corpus_artifact_path: CORPUS_ARTIFACT_PATH,
    output_directory: OUTPUT_DIRECTORY,
    expected_hashes: EXPECTED_HASHES,
    expected_file_bytes: EXPECTED_FILE_BYTES,
    source_records: 241,
    lineage: LINEAGE,
    inventories: EXPECTED_INVENTORIES,
    allowed_pos: POS_LABELS
  }.freeze

  ParsedRecord = Struct.new(:value, :bytes, keyword_init: true)

  module_function

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

  def canonical_json_file(value)
    canonical_json(value) + "\n"
  end

  def collection_digest(values)
    encoded = values.map { |value| canonical_json(value) }.uniq.sort
    sha256("[#{encoded.join(',')}]")
  end

  def parse_json(bytes, context)
    JSON.parse(
      bytes,
      object_class: DuplicateRejectingHash,
      max_nesting: MAX_JSON_NESTING
    )
  rescue JSON::ParserError, JSON::NestingError, DuplicateKey => error
    raise Failure, "invalid JSON in #{context}: #{error.class}"
  end

  class Compiler
    attr_reader :root, :configuration

    def initialize(root: ROOT, configuration: DEFAULT_CONFIGURATION)
      @root = File.expand_path(root)
      @configuration = configuration
      validate_configuration
    end

    def compile(write: true)
      inputs = validate_lineage_files
      records = parse_records(inputs.fetch("source_artifact"))
      partitions = validate_partition(records)
      outputs = build_outputs(partitions)
      write_outputs(outputs) if write
      outputs
    end

    private

    def validate_configuration
      required = %i[
        source_manifest_path
        corpus_manifest_path
        specification_path
        generator_path
        source_artifact_path
        corpus_artifact_path
        output_directory
        expected_hashes
        expected_file_bytes
        source_records
        lineage
        inventories
        allowed_pos
      ]
      missing = required.reject { |key| configuration.key?(key) }
      raise Failure, "compiler configuration fields differ" unless missing.empty?

      path_keys = %i[
        source_manifest_path
        corpus_manifest_path
        specification_path
        generator_path
        source_artifact_path
        output_directory
      ]
      path_keys.each { |key| validate_relative_path(configuration.fetch(key)) }
      validate_relative_path(configuration.fetch(:corpus_artifact_path))
      raise Failure, "configured split inventory differs" unless
        configuration.fetch(:inventories).keys == SPLITS
      raise Failure, "configured POS labels are invalid" unless
        valid_string_set?(configuration.fetch(:allowed_pos))
    end

    def validate_relative_path(path)
      valid = path.is_a?(String) &&
        !path.empty? &&
        path.valid_encoding? &&
        !path.start_with?("/") &&
        !path.include?("\0") &&
        path.split("/").none? { |part| part.empty? || %w[. ..].include?(part) }
      raise Failure, "compiler path is not a safe relative path" unless valid
    end

    def valid_string_set?(value)
      value.is_a?(Array) &&
        !value.empty? &&
        value.all? { |item| item.is_a?(String) && !item.empty? } &&
        value == value.uniq.sort
    end

    def full_path(relative)
      File.join(root, relative)
    end

    def read_verified(key, path)
      bytes = File.binread(full_path(path))
      expected_bytes = configuration.fetch(:expected_file_bytes).fetch(key)
      raise Failure, "#{key} byte count differs" unless
        bytes.bytesize == expected_bytes
      raise Failure, "#{key} hash differs" unless
        P08PosSplits.sha256(bytes) ==
        configuration.fetch(:expected_hashes).fetch(key)

      text = bytes.dup.force_encoding(Encoding::UTF_8)
      raise Failure, "#{key} is not valid UTF-8" unless text.valid_encoding?

      text
    rescue Errno::ENOENT, Errno::EACCES, Errno::EISDIR => error
      raise Failure, "cannot read #{key}: #{error.class}"
    end

    def validate_lineage_files
      source_manifest_bytes = read_verified(
        "source_manifest",
        configuration.fetch(:source_manifest_path)
      )
      corpus_manifest_bytes = read_verified(
        "corpus_manifest",
        configuration.fetch(:corpus_manifest_path)
      )
      read_verified("specification", configuration.fetch(:specification_path))
      read_verified("generator", configuration.fetch(:generator_path))
      source_artifact_bytes = read_verified(
        "source_artifact",
        configuration.fetch(:source_artifact_path)
      )

      source_manifest = parse_mapping(
        source_manifest_bytes,
        "source manifest"
      )
      corpus_manifest = parse_mapping(
        corpus_manifest_bytes,
        "corpus manifest"
      )
      validate_source_manifest(source_manifest)
      validate_corpus_manifest(corpus_manifest)

      {"source_artifact" => source_artifact_bytes}
    end

    def parse_mapping(bytes, context)
      value = P08PosSplits.parse_json(bytes, context)
      raise Failure, "#{context} root is not a mapping" unless value.is_a?(Hash)

      value
    end

    def validate_source_manifest(manifest)
      raise Failure, "source manifest schema differs" unless
        manifest["schema_version"] == 1
      source = mapping(manifest["source"], "source manifest source")
      lineage = configuration.fetch(:lineage)
      expected = {
        "id" => lineage.fetch("source_id"),
        "immutable_version" => lineage.fetch("corpus_version"),
        "license" => lineage.fetch("license"),
        "claim_scope" => lineage.fetch("claim_scope")
      }
      expected.each do |field, value|
        raise Failure, "source manifest lineage differs" unless
          source[field] == value
      end

      artifacts = array(manifest["artifacts"], "source manifest artifacts")
      validate_admitted_artifact(
        artifacts,
        configuration.fetch(:corpus_manifest_path),
        "corpus_manifest",
        nil
      )
      validate_admitted_artifact(
        artifacts,
        configuration.fetch(:specification_path),
        "specification",
        nil
      )
      validate_admitted_artifact(
        artifacts,
        configuration.fetch(:source_artifact_path),
        "source_artifact",
        configuration.fetch(:source_records)
      )
    end

    def validate_admitted_artifact(artifacts, path, key, records)
      matches = artifacts.select do |entry|
        entry.is_a?(Hash) && entry["path"] == path
      end
      raise Failure, "source manifest artifact binding differs" unless
        matches.length == 1
      entry = matches.fetch(0)
      expected = {
        "bytes" => configuration.fetch(:expected_file_bytes).fetch(key),
        "sha256" => configuration.fetch(:expected_hashes).fetch(key),
        "records" => records
      }
      expected.each do |field, value|
        raise Failure, "source manifest artifact binding differs" unless
          entry.key?(field) && entry[field] == value
      end
    end

    def validate_corpus_manifest(manifest)
      raise Failure, "corpus manifest schema differs" unless
        manifest["schema_version"] == 1
      corpus = mapping(manifest["corpus"], "corpus manifest corpus")
      lineage = configuration.fetch(:lineage)
      expected = {
        "id" => lineage.fetch("source_id"),
        "version" => lineage.fetch("corpus_version"),
        "generator_id" => lineage.fetch("generator_id"),
        "license" => lineage.fetch("license"),
        "locale" => lineage.fetch("locale"),
        "claim_scope" => lineage.fetch("claim_scope"),
        "specification_sha256" =>
          configuration.fetch(:expected_hashes).fetch("specification"),
        "generator_sha256" =>
          configuration.fetch(:expected_hashes).fetch("generator")
      }
      expected.each do |field, value|
        raise Failure, "corpus manifest lineage differs" unless
          corpus[field] == value
      end

      artifacts = array(manifest["artifacts"], "corpus manifest artifacts")
      matches = artifacts.select do |entry|
        entry.is_a?(Hash) &&
          entry["path"] == configuration.fetch(:corpus_artifact_path)
      end
      raise Failure, "corpus manifest artifact binding differs" unless
        matches.length == 1
      entry = matches.fetch(0)
      expected_artifact = {
        "bytes" =>
          configuration.fetch(:expected_file_bytes).fetch("source_artifact"),
        "sha256" =>
          configuration.fetch(:expected_hashes).fetch("source_artifact"),
        "records" => configuration.fetch(:source_records)
      }
      expected_artifact.each do |field, value|
        raise Failure, "corpus manifest artifact binding differs" unless
          entry[field] == value
      end
    end

    def mapping(value, context)
      raise Failure, "#{context} is not a mapping" unless value.is_a?(Hash)

      value
    end

    def array(value, context)
      raise Failure, "#{context} is not an array" unless value.is_a?(Array)

      value
    end

    def parse_records(bytes)
      raise Failure, "source artifact exceeds the byte limit" if
        bytes.bytesize > MAX_SOURCE_BYTES
      raise Failure, "source artifact lacks a final newline" unless
        bytes.end_with?("\n")

      records = []
      bytes.each_line.with_index(1) do |line, line_number|
        raise Failure, "blank source line at #{line_number}" if line.strip.empty?
        raise Failure, "source line exceeds the byte limit at #{line_number}" if
          line.bytesize > MAX_LINE_BYTES
        raise Failure, "source line ending differs at #{line_number}" unless
          line.end_with?("\n") && !line.end_with?("\r\n")

        value = P08PosSplits.parse_json(line, "source line #{line_number}")
        raise Failure, "source record is not a mapping at #{line_number}" unless
          value.is_a?(Hash)
        validate_record(value, line_number)
        records << ParsedRecord.new(value: value, bytes: line.b)
      end
      raise Failure, "source record count differs" unless
        records.length == configuration.fetch(:source_records)

      records
    end

    def validate_record(record, line_number)
      allowed_fields = RECORD_FIELDS + OPTIONAL_RECORD_FIELDS
      fields_valid =
        (RECORD_FIELDS - record.keys).empty? &&
        (record.keys - allowed_fields).empty?
      raise Failure, "source schema differs at record #{line_number}" unless
        fields_valid
      raise Failure, "source schema version differs at record #{line_number}" unless
        record["schema_version"] == 1
      if record.key?("ambiguity_preserved")
        raise Failure, "ambiguity flag differs at record #{line_number}" unless
          record["ambiguity_preserved"] == true
      end

      lineage = configuration.fetch(:lineage)
      %w[source_id corpus_version generator_id license locale].each do |field|
        raise Failure, "source lineage differs at record #{line_number}" unless
          record[field] == lineage.fetch(field)
      end
      identifier(record["case_id"], "case ID", line_number)
      identifier(record["family"], "family", line_number)
      identifier(record["document_id"], "document ID", line_number)
      raise Failure, "unexpected split at record #{line_number}" unless
        SPLITS.include?(record["split"])

      text = nonempty_string(record["text"], "text", line_number)
      text_hash = record["text_sha256"]
      raise Failure, "text hash schema differs at record #{line_number}" unless
        text_hash.is_a?(String) && text_hash.match?(SHA256)
      raise Failure, "text hash differs at record #{line_number}" unless
        P08PosSplits.sha256(text.b) == text_hash
      validate_tokens(record["tokens"], text, line_number)
    end

    def identifier(value, field, line_number)
      nonempty_string(value, field, line_number)
      raise Failure, "#{field} syntax differs at record #{line_number}" unless
        value.match?(IDENTIFIER)
    end

    def nonempty_string(value, field, line_number)
      valid = value.is_a?(String) && !value.empty? && value.valid_encoding?
      raise Failure, "#{field} is invalid at record #{line_number}" unless valid

      value
    end

    def validate_tokens(tokens, text, line_number)
      valid = tokens.is_a?(Array) &&
        !tokens.empty? &&
        tokens.length <= MAX_TOKENS_PER_RECORD
      raise Failure, "token array differs at record #{line_number}" unless valid

      previous_end = 0
      tokens.each_with_index do |token, index|
        token_number = index + 1
        raise Failure,
              "token schema differs at record #{line_number} token #{token_number}" unless
          token.is_a?(Hash) && token.keys.sort == TOKEN_FIELDS.sort
        token_text = nonempty_string(
          token["text"],
          "token text #{token_number}",
          line_number
        )
        begin_byte = token["begin_byte"]
        end_byte = token["end_byte"]
        valid_span = begin_byte.is_a?(Integer) &&
          end_byte.is_a?(Integer) &&
          begin_byte >= previous_end &&
          begin_byte < end_byte &&
          end_byte <= text.bytesize
        raise Failure,
              "token span differs at record #{line_number} token #{token_number}" unless
          valid_span
        gap = text.byteslice(previous_end...begin_byte)
        slice = text.byteslice(begin_byte...end_byte)
        boundaries_valid =
          utf8_whitespace?(gap) &&
          slice == token_text &&
          text.byteslice(0...begin_byte).valid_encoding? &&
          text.byteslice(0...end_byte).valid_encoding?
        raise Failure,
              "token span text differs at record #{line_number} token #{token_number}" unless
          boundaries_valid
        allowed_pos = token["allowed_pos"]
        raise Failure,
              "token POS set differs at record #{line_number} token #{token_number}" unless
          valid_string_set?(allowed_pos) &&
          (allowed_pos - configuration.fetch(:allowed_pos)).empty?
        previous_end = end_byte
      end
      raise Failure, "trailing token span differs at record #{line_number}" unless
        utf8_whitespace?(text.byteslice(previous_end..))
    end

    def utf8_whitespace?(bytes)
      value = bytes.dup.force_encoding(Encoding::UTF_8)
      value.valid_encoding? && value.match?(/\A[[:space:]]*\z/)
    end

    def validate_partition(records)
      partitions = SPLITS.to_h { |split| [split, []] }
      case_ids = {}
      text_ids = {}
      text_values = {}
      document_splits = {}
      family_splits = {}

      records.each_with_index do |parsed, index|
        record = parsed.value
        split = record.fetch("split")
        reject_duplicate_identity(
          case_ids,
          record.fetch("case_id"),
          "case identity",
          split
        )
        reject_text_identity(
          text_ids,
          text_values,
          record,
          split
        )
        reject_intersection(
          document_splits,
          record.fetch("document_id"),
          split,
          "document"
        )
        reject_intersection(
          family_splits,
          record.fetch("family"),
          split,
          "family"
        )
        partitions.fetch(split) << parsed
        raise Failure, "source partition overflow at record #{index + 1}" if
          partitions.fetch(split).length >
          configuration.fetch(:inventories).fetch(split).fetch("records")
      end

      SPLITS.each do |split|
        validate_inventory(split, partitions.fetch(split))
      end
      partitions
    end

    def reject_duplicate_identity(seen, value, context, split)
      previous = seen[value]
      if previous
        qualifier = previous == split ? "duplicate" : "cross-split"
        raise Failure, "#{qualifier} #{context}"
      end
      seen[value] = split
    end

    def reject_text_identity(text_ids, text_values, record, split)
      text_hash = record.fetch("text_sha256")
      text = record.fetch("text")
      previous_hash_split = text_ids[text_hash]
      previous_text_split = text_values[text]
      if previous_hash_split || previous_text_split
        previous_split = previous_hash_split || previous_text_split
        qualifier = previous_split == split ? "duplicate" : "cross-split"
        raise Failure, "#{qualifier} sentence identity"
      end
      text_ids[text_hash] = split
      text_values[text] = split
    end

    def reject_intersection(seen, value, split, context)
      previous = seen[value]
      raise Failure, "#{context} intersects splits" if previous && previous != split

      seen[value] = split
    end

    def validate_inventory(split, records)
      expected = configuration.fetch(:inventories).fetch(split)
      actual = {
        "records" => records.length,
        "documents" =>
          records.map { |parsed| parsed.value.fetch("document_id") }.uniq.length,
        "tokens" =>
          records.sum { |parsed| parsed.value.fetch("tokens").length },
        "families" =>
          records.map { |parsed| parsed.value.fetch("family") }.uniq.sort
      }
      raise Failure, "#{split} inventory differs" unless actual == expected
    end

    def build_outputs(partitions)
      split_outputs = {}
      split_entries = SPLITS.map do |split|
        records = partitions.fetch(split)
        bytes = records.map(&:bytes).join.b
        relative_path =
          File.join(configuration.fetch(:output_directory), "#{split}.jsonl")
        split_outputs[relative_path] = bytes
        split_manifest_entry(split, relative_path, bytes, records)
      end
      manifest = split_manifest(split_entries, partitions)
      manifest_path = File.join(
        configuration.fetch(:output_directory),
        "split-manifest.json"
      )
      split_outputs[manifest_path] = P08PosSplits.canonical_json_file(manifest)
      split_outputs
    end

    def split_manifest_entry(split, relative_path, bytes, records)
      values = records.map(&:value)
      origins = values.map { |record| origin(record) }
      {
        "split" => split,
        "path" => relative_path,
        "bytes" => bytes.bytesize,
        "sha256" => P08PosSplits.sha256(bytes),
        "records" => values.length,
        "documents" =>
          values.map { |record| record.fetch("document_id") }.uniq.length,
        "tokens" =>
          values.sum { |record| record.fetch("tokens").length },
        "case_ids_sha256" =>
          P08PosSplits.collection_digest(
            values.map { |record| record.fetch("case_id") }
          ),
        "document_ids_sha256" =>
          P08PosSplits.collection_digest(
            values.map { |record| record.fetch("document_id") }
          ),
        "text_sha256s_sha256" =>
          P08PosSplits.collection_digest(
            values.map { |record| record.fetch("text_sha256") }
          ),
        "origins_sha256" => P08PosSplits.collection_digest(origins),
        "origin_count" => origins.uniq.length,
        "families" =>
          values.map { |record| record.fetch("family") }.uniq.sort
      }
    end

    def split_manifest(split_entries, partitions)
      values = SPLITS.flat_map do |split|
        partitions.fetch(split).map(&:value)
      end
      origins = values.map { |record| origin(record) }
      lineage = configuration.fetch(:lineage)
      {
        "schema_version" => 1,
        "compiler_id" => "p08-pos-split-compiler-v1",
        "dataset_id" => "p08-pos-context-splits-v1",
        "dataset_version" => "1.0.0",
        "digest_contract" => {
          "algorithm" => "sha256",
          "collection_encoding" =>
            "canonical-json-sorted-unique-array-v1",
          "origin_fields" => ORIGIN_FIELDS
        },
        "source" => {
          "source_id" => lineage.fetch("source_id"),
          "corpus_version" => lineage.fetch("corpus_version"),
          "generator_id" => lineage.fetch("generator_id"),
          "license" => lineage.fetch("license"),
          "locale" => lineage.fetch("locale"),
          "claim_scope" => lineage.fetch("claim_scope"),
          "source_manifest_path" =>
            configuration.fetch(:source_manifest_path),
          "source_manifest_sha256" =>
            configuration.fetch(:expected_hashes).fetch("source_manifest"),
          "corpus_manifest_path" =>
            configuration.fetch(:corpus_manifest_path),
          "corpus_manifest_sha256" =>
            configuration.fetch(:expected_hashes).fetch("corpus_manifest"),
          "specification_path" =>
            configuration.fetch(:specification_path),
          "specification_sha256" =>
            configuration.fetch(:expected_hashes).fetch("specification"),
          "generator_path" => configuration.fetch(:generator_path),
          "generator_sha256" =>
            configuration.fetch(:expected_hashes).fetch("generator"),
          "artifact_path" => configuration.fetch(:source_artifact_path),
          "artifact_bytes" =>
            configuration.fetch(:expected_file_bytes).fetch("source_artifact"),
          "artifact_sha256" =>
            configuration.fetch(:expected_hashes).fetch("source_artifact"),
          "artifact_records" => configuration.fetch(:source_records)
        },
        "partition" => {
          "split_order" => SPLITS,
          "records" => values.length,
          "documents" =>
            values.map { |record| record.fetch("document_id") }.uniq.length,
          "tokens" =>
            values.sum { |record| record.fetch("tokens").length },
          "case_ids_sha256" =>
            P08PosSplits.collection_digest(
              values.map { |record| record.fetch("case_id") }
            ),
          "document_ids_sha256" =>
            P08PosSplits.collection_digest(
              values.map { |record| record.fetch("document_id") }
            ),
          "text_sha256s_sha256" =>
            P08PosSplits.collection_digest(
              values.map { |record| record.fetch("text_sha256") }
            ),
          "origins_sha256" => P08PosSplits.collection_digest(origins),
          "origin_count" => origins.uniq.length,
          "families" =>
            values.map { |record| record.fetch("family") }.uniq.sort,
          "sentence_disjoint" => true,
          "document_disjoint" => true,
          "family_disjoint" => true,
          "complete" => true
        },
        "splits" => split_entries
      }
    end

    def origin(record)
      ORIGIN_FIELDS.to_h { |field| [field, record.fetch(field)] }
    end

    def write_outputs(outputs)
      output_directory = full_path(configuration.fetch(:output_directory))
      raise Failure, "output directory is a symbolic link" if
        File.symlink?(output_directory)
      FileUtils.mkdir_p(output_directory)

      Dir.mktmpdir(".p08-pos-splits.", output_directory) do |temporary|
        staged = {}
        outputs.each do |relative, bytes|
          basename = File.basename(relative)
          path = File.join(temporary, basename)
          File.binwrite(path, bytes)
          staged[relative] = path
        end
        staged.each do |relative, path|
          target = full_path(relative)
          raise Failure, "output target is a symbolic link" if File.symlink?(target)
          raise Failure, "output target is not a regular file" if
            File.exist?(target) && !File.file?(target)
          File.rename(path, target)
        end
      end
    rescue Errno::EACCES, Errno::ENOENT, Errno::ENOTDIR, Errno::EISDIR,
           Errno::ENOSPC => error
      raise Failure, "cannot write split outputs: #{error.class}"
    end
  end

  module CLI
    module_function

    def run(arguments)
      raise Failure, "usage: tools/compile-p08-pos-splits" unless arguments.empty?

      Compiler.new.compile
      puts "P08_POS_SPLITS_COMPILED"
    rescue Failure => error
      warn "P08_POS_SPLITS_COMPILE_FAIL: #{error.message}"
      exit 1
    end
  end
end
