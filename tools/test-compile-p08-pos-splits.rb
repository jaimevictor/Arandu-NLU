# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"
require_relative "compile-p08-pos-splits"

module P08PosSplitsTest
  FIXTURE_TECNICA = "FIXTURE_TECNICA"
  FIXTURE_PATHS = {
    source_manifest_path: "FIXTURE_TECNICA/source-manifest.json",
    corpus_manifest_path: "FIXTURE_TECNICA/corpus-manifest.json",
    specification_path: "FIXTURE_TECNICA/specification.txt",
    generator_path: "FIXTURE_TECNICA/generator.rb",
    source_artifact_path: "FIXTURE_TECNICA/pos-context.jsonl",
    corpus_artifact_path: "FIXTURE_TECNICA-pos-context.jsonl",
    output_directory: "FIXTURE_TECNICA/output"
  }.freeze
  FIXTURE_LINEAGE = {
    "source_id" => "FIXTURE_TECNICA_SOURCE",
    "corpus_version" => "FIXTURE_TECNICA_VERSION",
    "generator_id" => "FIXTURE_TECNICA_GENERATOR",
    "license" => "FIXTURE_TECNICA_LICENSE",
    "locale" => "FIXTURE_TECNICA_LOCALE",
    "claim_scope" => "FIXTURE_TECNICA_SCOPE"
  }.freeze
  FIXTURE_POS = ["FIXTURE_TECNICA_POS"].freeze
  FIXTURE_INVENTORIES = {
    "train" => {
      "records" => 1,
      "documents" => 1,
      "tokens" => 1,
      "families" => ["fixture_tecnica_family_train"]
    },
    "development" => {
      "records" => 1,
      "documents" => 1,
      "tokens" => 1,
      "families" => ["fixture_tecnica_family_development"]
    },
    "heldout" => {
      "records" => 1,
      "documents" => 1,
      "tokens" => 1,
      "families" => ["fixture_tecnica_family_heldout"]
    }
  }.freeze

  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure(fragment)
    yield
    raise "expected P08PosSplits::Failure containing #{fragment.inspect}"
  rescue P08PosSplits::Failure => error
    assert(
      error.message.include?(fragment),
      "expected #{fragment.inspect}, got #{error.message.inspect}"
    )
  end

  def deep_copy(value)
    JSON.parse(JSON.generate(value))
  end

  def fixture_record(split)
    text = "FIXTURE_TECNICA_TEXT_#{split}"
    record = {
      "schema_version" => 1,
      "case_id" => "fixture_tecnica_case_#{split}",
      "source_id" => FIXTURE_LINEAGE.fetch("source_id"),
      "corpus_version" => FIXTURE_LINEAGE.fetch("corpus_version"),
      "generator_id" => FIXTURE_LINEAGE.fetch("generator_id"),
      "license" => FIXTURE_LINEAGE.fetch("license"),
      "locale" => FIXTURE_LINEAGE.fetch("locale"),
      "split" => split,
      "family" => "fixture_tecnica_family_#{split}",
      "document_id" => "fixture_tecnica_document_#{split}",
      "text" => text,
      "text_sha256" => P08PosSplits.sha256(text),
      "tokens" => [
        {
          "text" => text,
          "begin_byte" => 0,
          "end_byte" => text.bytesize,
          "allowed_pos" => FIXTURE_POS
        }
      ]
    }
    record["ambiguity_preserved"] = true if split == "heldout"
    record
  end

  def fixture_records
    P08PosSplits::SPLITS.map { |split| fixture_record(split) }
  end

  def json_lines(records)
    records.map { |record| JSON.generate(record) + "\n" }.join
  end

  def write_relative(root, relative, bytes)
    path = File.join(root, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, bytes)
  end

  def fixture_compiler(
    root,
    records: fixture_records,
    artifact_bytes: nil,
    inventories: FIXTURE_INVENTORIES
  )
    source_artifact = artifact_bytes || json_lines(records)
    specification = "FIXTURE_TECNICA_SPECIFICATION\n"
    generator = "# FIXTURE_TECNICA_GENERATOR\n"
    source_hash = P08PosSplits.sha256(source_artifact)
    specification_hash = P08PosSplits.sha256(specification)
    generator_hash = P08PosSplits.sha256(generator)

    corpus_manifest = {
      "schema_version" => 1,
      "corpus" => {
        "id" => FIXTURE_LINEAGE.fetch("source_id"),
        "version" => FIXTURE_LINEAGE.fetch("corpus_version"),
        "generator_id" => FIXTURE_LINEAGE.fetch("generator_id"),
        "license" => FIXTURE_LINEAGE.fetch("license"),
        "locale" => FIXTURE_LINEAGE.fetch("locale"),
        "claim_scope" => FIXTURE_LINEAGE.fetch("claim_scope"),
        "specification_sha256" => specification_hash,
        "generator_sha256" => generator_hash
      },
      "artifacts" => [
        {
          "path" => FIXTURE_PATHS.fetch(:corpus_artifact_path),
          "bytes" => source_artifact.bytesize,
          "sha256" => source_hash,
          "records" => 3
        }
      ]
    }
    corpus_manifest_bytes = P08PosSplits.canonical_json_file(corpus_manifest)
    corpus_manifest_hash = P08PosSplits.sha256(corpus_manifest_bytes)

    source_manifest = {
      "schema_version" => 1,
      "source" => {
        "id" => FIXTURE_LINEAGE.fetch("source_id"),
        "immutable_version" => FIXTURE_LINEAGE.fetch("corpus_version"),
        "license" => FIXTURE_LINEAGE.fetch("license"),
        "claim_scope" => FIXTURE_LINEAGE.fetch("claim_scope")
      },
      "artifacts" => [
        {
          "path" => FIXTURE_PATHS.fetch(:corpus_manifest_path),
          "bytes" => corpus_manifest_bytes.bytesize,
          "sha256" => corpus_manifest_hash,
          "records" => nil
        },
        {
          "path" => FIXTURE_PATHS.fetch(:specification_path),
          "bytes" => specification.bytesize,
          "sha256" => specification_hash,
          "records" => nil
        },
        {
          "path" => FIXTURE_PATHS.fetch(:source_artifact_path),
          "bytes" => source_artifact.bytesize,
          "sha256" => source_hash,
          "records" => 3
        }
      ]
    }
    source_manifest_bytes = P08PosSplits.canonical_json_file(source_manifest)

    files = {
      FIXTURE_PATHS.fetch(:source_manifest_path) => source_manifest_bytes,
      FIXTURE_PATHS.fetch(:corpus_manifest_path) => corpus_manifest_bytes,
      FIXTURE_PATHS.fetch(:specification_path) => specification,
      FIXTURE_PATHS.fetch(:generator_path) => generator,
      FIXTURE_PATHS.fetch(:source_artifact_path) => source_artifact
    }
    files.each { |relative, bytes| write_relative(root, relative, bytes) }

    expected_hashes = {
      "source_manifest" => P08PosSplits.sha256(source_manifest_bytes),
      "corpus_manifest" => corpus_manifest_hash,
      "specification" => specification_hash,
      "generator" => generator_hash,
      "source_artifact" => source_hash
    }
    expected_file_bytes = {
      "source_manifest" => source_manifest_bytes.bytesize,
      "corpus_manifest" => corpus_manifest_bytes.bytesize,
      "specification" => specification.bytesize,
      "generator" => generator.bytesize,
      "source_artifact" => source_artifact.bytesize
    }
    configuration = FIXTURE_PATHS.merge(
      expected_hashes: expected_hashes,
      expected_file_bytes: expected_file_bytes,
      source_records: 3,
      lineage: FIXTURE_LINEAGE,
      inventories: inventories,
      allowed_pos: FIXTURE_POS
    )
    P08PosSplits::Compiler.new(root: root, configuration: configuration)
  end

  def with_fixture(**arguments)
    Dir.mktmpdir("FIXTURE_TECNICA_p08_pos_splits.") do |root|
      compiler = fixture_compiler(root, **arguments)
      yield root, compiler
    end
  end

  def mutate_record(records, split)
    copy = deep_copy(records)
    record = copy.fetch(P08PosSplits::SPLITS.index(split))
    yield record
    copy
  end

  def synchronize_text(record, text)
    record["text"] = text
    record["text_sha256"] = P08PosSplits.sha256(text)
    record["tokens"] = [
      {
        "text" => text,
        "begin_byte" => 0,
        "end_byte" => text.bytesize,
        "allowed_pos" => FIXTURE_POS
      }
    ]
  end

  def test_byte_preserving_canonical_deterministic_compile
    records = fixture_records
    lines = records.map { |record| JSON.generate(record) + "\n" }
    lines[0] = lines.fetch(0).sub(
      '"schema_version":1',
      '"schema_version" : 1'
    )
    source_artifact = lines.join
    with_fixture(records: records, artifact_bytes: source_artifact) do |root, compiler|
      first = compiler.compile
      second = compiler.compile
      assert(first == second, "repeat compile bytes")

      P08PosSplits::SPLITS.each_with_index do |split, index|
        relative = File.join(
          FIXTURE_PATHS.fetch(:output_directory),
          "#{split}.jsonl"
        )
        assert(first.fetch(relative) == lines.fetch(index), "#{split} slice bytes")
        assert(
          File.binread(File.join(root, relative)) == lines.fetch(index),
          "#{split} tracked output bytes"
        )
      end

      manifest_path = File.join(
        FIXTURE_PATHS.fetch(:output_directory),
        "split-manifest.json"
      )
      manifest_bytes = first.fetch(manifest_path)
      manifest = P08PosSplits.parse_json(
        manifest_bytes,
        "FIXTURE_TECNICA manifest"
      )
      assert(
        manifest_bytes == P08PosSplits.canonical_json_file(manifest),
        "canonical manifest bytes"
      )
      assert(manifest.fetch("partition").fetch("records") == 3, "record total")
      assert(manifest.fetch("partition").fetch("documents") == 3, "document total")
      assert(manifest.fetch("partition").fetch("tokens") == 3, "token total")
      assert(manifest.fetch("partition").fetch("origin_count") == 1, "origin total")
      assert(
        manifest.fetch("splits").map { |entry| entry.fetch("records") } ==
          [1, 1, 1],
        "split inventories"
      )
      assert(
        manifest.fetch("source").fetch("artifact_sha256") ==
          P08PosSplits.sha256(source_artifact),
        "source artifact binding"
      )
    end
  end

  def test_duplicate_json_keys_are_rejected_without_outputs
    lines = json_lines(fixture_records).lines
    lines[0] = lines.fetch(0).sub(/\A\{/, '{"schema_version":1,')
    with_fixture(artifact_bytes: lines.join) do |root, compiler|
      assert_failure("invalid JSON") { compiler.compile }
      assert(
        !File.exist?(File.join(root, FIXTURE_PATHS.fetch(:output_directory))),
        "failed compile emits no output directory"
      )
    end
  end

  def test_malformed_utf8_is_rejected
    bytes = json_lines(fixture_records).b
    bytes.setbyte(bytes.index("FIXTURE_TECNICA_TEXT"), 0xff)
    with_fixture(artifact_bytes: bytes) do |_root, compiler|
      assert_failure("not valid UTF-8") { compiler.compile(write: false) }
    end
  end

  def test_schema_lineage_text_hash_and_span_mutations_are_rejected
    records = mutate_record(fixture_records, "train") do |record|
      record["FIXTURE_TECNICA_EXTRA"] = true
    end
    with_fixture(records: records) do |_root, compiler|
      assert_failure("schema differs") { compiler.compile(write: false) }
    end

    records = mutate_record(fixture_records, "train") do |record|
      record["source_id"] = "FIXTURE_TECNICA_SUBSTITUTED_SOURCE"
    end
    with_fixture(records: records) do |_root, compiler|
      assert_failure("lineage differs") { compiler.compile(write: false) }
    end

    records = mutate_record(fixture_records, "train") do |record|
      record["text_sha256"] = "0" * 64
    end
    with_fixture(records: records) do |_root, compiler|
      assert_failure("text hash differs") { compiler.compile(write: false) }
    end

    records = mutate_record(fixture_records, "train") do |record|
      record.fetch("tokens").fetch(0)["end_byte"] -= 1
    end
    with_fixture(records: records) do |_root, compiler|
      assert_failure("token span text differs") { compiler.compile(write: false) }
    end
  end

  def test_unexpected_split_and_inventory_mutations_are_rejected
    records = mutate_record(fixture_records, "development") do |record|
      record["split"] = "FIXTURE_TECNICA_SPLIT"
    end
    with_fixture(records: records) do |_root, compiler|
      assert_failure("unexpected split") { compiler.compile(write: false) }
    end

    inventories = deep_copy(FIXTURE_INVENTORIES)
    inventories.fetch("heldout")["tokens"] = 2
    with_fixture(inventories: inventories) do |_root, compiler|
      assert_failure("heldout inventory differs") do
        compiler.compile(write: false)
      end
    end
  end

  def test_duplicate_case_and_sentence_identities_are_rejected
    records = mutate_record(fixture_records, "development") do |record|
      record["case_id"] = fixture_records.fetch(0).fetch("case_id")
    end
    with_fixture(records: records) do |_root, compiler|
      assert_failure("cross-split case identity") do
        compiler.compile(write: false)
      end
    end

    train_text = fixture_records.fetch(0).fetch("text")
    records = mutate_record(fixture_records, "development") do |record|
      synchronize_text(record, train_text)
    end
    with_fixture(records: records) do |_root, compiler|
      assert_failure("cross-split sentence identity") do
        compiler.compile(write: false)
      end
    end
  end

  def test_document_and_family_intersections_are_rejected
    records = mutate_record(fixture_records, "development") do |record|
      record["document_id"] =
        fixture_records.fetch(0).fetch("document_id")
    end
    with_fixture(records: records) do |_root, compiler|
      assert_failure("document intersects splits") do
        compiler.compile(write: false)
      end
    end

    records = mutate_record(fixture_records, "development") do |record|
      record["family"] = fixture_records.fetch(0).fetch("family")
    end
    with_fixture(records: records) do |_root, compiler|
      assert_failure("family intersects splits") do
        compiler.compile(write: false)
      end
    end
  end

  def test_source_artifact_and_manifest_bindings_are_rejected
    with_fixture do |root, compiler|
      artifact = File.join(
        root,
        FIXTURE_PATHS.fetch(:source_artifact_path)
      )
      File.binwrite(artifact, File.binread(artifact) + " ")
      assert_failure("source_artifact byte count differs") do
        compiler.compile(write: false)
      end
    end

    with_fixture do |root, compiler|
      source_manifest = File.join(
        root,
        FIXTURE_PATHS.fetch(:source_manifest_path)
      )
      bytes = File.binread(source_manifest)
      File.binwrite(source_manifest, bytes.sub('"records":3', '"records":2'))
      assert_failure("source_manifest hash differs") do
        compiler.compile(write: false)
      end
    end
  end

  def test_collection_digests_ignore_input_order_and_duplicates
    values = %w[
      FIXTURE_TECNICA_C
      FIXTURE_TECNICA_A
      FIXTURE_TECNICA_B
      FIXTURE_TECNICA_A
    ]
    assert(
      P08PosSplits.collection_digest(values) ==
        P08PosSplits.collection_digest(values.reverse.uniq),
      "canonical collection digest"
    )
  end

  def run
    methods.grep(/^test_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P08_POS_SPLIT_COMPILER_TESTS_PASS"
  end
end

P08PosSplitsTest.run
