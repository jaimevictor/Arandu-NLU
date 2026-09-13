# frozen_string_literal: true

require "digest"
require "json"
require "open3"

module P06Validation
  class Failure < StandardError; end
  class DuplicateKey < StandardError; end

  class DuplicateRejectingHash < Hash
    def []=(key, value)
      raise DuplicateKey, key if key?(key)

      super
    end
  end

  ROOT = File.expand_path("..", __dir__)
  SOURCE_ID = "project-authored-synthetic-ptbr-v1"
  SOURCE_MANIFEST = "data/manifests/project-authored-synthetic-ptbr-v1.json"
  SOURCE_LEXICON = "data/project-authored/p02-v1/lexicon.jsonl"
  PACKAGE = "data/lexicon/p06/package.bin"
  PACKAGE_MANIFEST = "data/lexicon/p06/package-manifest.json"
  ENTRY_SCHEMA = "schemas/lexicon-entry-v1.schema.json"
  MANIFEST_SCHEMA = "schemas/lexicon-package-manifest-v1.schema.json"
  SOURCE_MANIFEST_SHA256 =
    "d9e1ca32ec0f92aa6b5fc6c1d4f232f93389e0bf8031267d23daddf7287006c5"
  SOURCE_LEXICON_SHA256 =
    "727e89195fc2ed16489c24b17841d58a2a9bb68c828769ece83ab70489316e4e"
  SPECIFICATION_SHA256 =
    "f72451f03d1a5e2e4955b5d2857bd7d33b3b012912d920e53a3d85719f14859d"
  GENERATOR_SHA256 =
    "ff8817afc2c2f13d539ab7d10720cab407d769ca3a6189dcc55d43ea052689d1"
  LICENSE_SHA256 =
    "c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4"
  PACKAGE_SHA256 =
    "ec24f2335f64d694931450fb5ad6aefe3e924d1e29b23e046f128491dfe79e27"
  PACKAGE_MANIFEST_SHA256 =
    "f8f69336c9c682c225f7b972d56a66d1818e0f9c5fcf39455d38a636b38bb68b"
  ARTIFACTS = {
    SOURCE_MANIFEST => [6_204, SOURCE_MANIFEST_SHA256],
    SOURCE_LEXICON => [9_835, SOURCE_LEXICON_SHA256],
    "data/project-authored/p02-v1/specification.yaml" =>
      [18_201, SPECIFICATION_SHA256],
    "tools/generate-p02-corpus.rb" => [24_477, GENERATOR_SHA256],
    "LICENSE" => [11_357, LICENSE_SHA256],
    PACKAGE => [65_886, PACKAGE_SHA256],
    PACKAGE_MANIFEST => [390, PACKAGE_MANIFEST_SHA256],
    ENTRY_SCHEMA =>
      [4_277, "a875c1a5f4dfc1cf51f7fb1aa48da43c8c85631164c89cc4223915a30a4d6f90"],
    MANIFEST_SCHEMA =>
      [1_302, "220600b95d60066469ffb9e86df30262a2a8327ea844449ad79573e25b9be2b2"]
  }.freeze
  ENTRY_FIELDS = %w[
    schema_version analysis_id surface lemma pos features source generation
    transformations derivative_license
  ].freeze
  MANIFEST_FIELDS = %w[
    schema_version format transform_id input_sha256 package_sha256
    package_bytes entry_count source_ids derivative_licenses
  ].freeze
  REQUIREMENTS = (
    (1..8).map { |number| format("P06-LEX-%03d", number) } +
    %w[ARC-DATA-001 DAT-REMOVE-001]
  ).freeze

  module_function

  def run(arguments)
    arguments = arguments.dup
    no_cargo = arguments.delete("--no-cargo")
    review_candidate = arguments.delete("--review-candidate")
    unless arguments.empty?
      raise Failure,
            "usage: tools/validate-p06 [--no-cargo] [--review-candidate]"
    end

    validate(
      ROOT,
      run_cargo: !no_cargo && !review_candidate,
      require_satisfied: !review_candidate
    )
    puts(review_candidate ? "P06_REVIEW_CANDIDATE_PASS" : "P06_GATE_PASS")
  rescue Failure => error
    warn "P06_GATE_FAIL: #{error.message}"
    exit 1
  end

  def validate(root, run_cargo:, require_satisfied:)
    validate_artifacts(root)
    validate_source_manifest(root)
    rows = source_rows(File.binread(File.join(root, SOURCE_LEXICON)))
    package = File.binread(File.join(root, PACKAGE))
    entries = parse_package(package)
    manifest = parse_json(
      File.binread(File.join(root, PACKAGE_MANIFEST)),
      "lexicon package manifest"
    )
    validate_package(root, package, entries, manifest, rows)
    validate_schemas(root, entries.first, manifest)
    validate_runtime_contract(root)
    validate_requirements(root, require_satisfied: require_satisfied)
    run_cargo_tests(root) if run_cargo
    true
  end

  def validate_artifacts(root)
    ARTIFACTS.each do |relative, (bytes, sha256)|
      path = File.join(root, relative)
      raise Failure, "artifact is a symlink: #{relative}" if File.symlink?(path)
      raise Failure, "artifact is not a regular file: #{relative}" unless File.file?(path)
      raise Failure, "artifact byte count differs: #{relative}" unless File.size(path) == bytes
      raise Failure, "artifact hash differs: #{relative}" unless
        Digest::SHA256.file(path).hexdigest == sha256
    end
  end

  def validate_source_manifest(root)
    manifest = parse_json(
      File.binread(File.join(root, SOURCE_MANIFEST)),
      "source manifest"
    )
    source = manifest.fetch("source")
    expected = {
      "id" => SOURCE_ID,
      "admission_status" => "PROJECT_AUTHORED_SYNTHETIC",
      "authorization" => "USR-016",
      "claim_scope" => "internal_conformance_only",
      "immutable_version" => "1.0.0",
      "license" => "Apache-2.0",
      "license_sha256" => LICENSE_SHA256,
      "intended_use" => "deterministic_internal_conformance_and_language_package"
    }
    expected.each do |field, value|
      raise Failure, "source manifest #{field} differs" unless source[field] == value
    end
    artifacts = manifest.fetch("artifacts").to_h do |artifact|
      [artifact.fetch("path"), artifact]
    end
    lexicon = artifacts.fetch(SOURCE_LEXICON)
    raise Failure, "source lexicon descriptor differs" unless
      lexicon["role"] == "lexicon" &&
        lexicon["bytes"] == 9_835 &&
        lexicon["records"] == 33 &&
        lexicon["sha256"] == SOURCE_LEXICON_SHA256
  rescue KeyError => error
    raise Failure, "source manifest missing key #{error.key}"
  end

  def source_rows(bytes)
    raise Failure, "source lexicon lacks final newline" unless bytes.end_with?("\n")

    rows = {}
    bytes.lines(chomp: true).each_with_index do |line, index|
      record = parse_json(line, "source row #{index + 1}")
      id = record.fetch("analysis_id")
      raise Failure, "duplicate source analysis ID" if rows.key?(id)

      rows[id] = {record: record, bytes: line.b}
    end
    raise Failure, "source row count differs" unless rows.length == 33

    rows
  rescue KeyError => error
    raise Failure, "source row missing key #{error.key}"
  end

  def parse_package(bytes)
    raise Failure, "package header differs" unless bytes.start_with?("NLULEX\0\x01".b)
    raise Failure, "package is truncated" if bytes.bytesize < 16

    count = bytes.byteslice(8, 8).unpack1("Q>")
    raise Failure, "package entry count exceeds limit" if count > 20_000

    entries = []
    offset = 16
    count.times do |index|
      raise Failure, "truncated entry length" if offset + 4 > bytes.bytesize

      length = bytes.byteslice(offset, 4).unpack1("N")
      raise Failure, "invalid entry length" if length.zero? || length > 1_048_576

      offset += 4
      payload = bytes.byteslice(offset, length)
      raise Failure, "truncated entry payload" if payload.nil? || payload.bytesize != length

      entry = parse_json(payload, "package entry #{index + 1}")
      raise Failure, "noncanonical package entry" unless canonical_json(entry) == payload

      entries << entry
      offset += length
    end
    raise Failure, "trailing package bytes" unless offset == bytes.bytesize

    entries
  end

  def validate_package(root, package, entries, manifest, rows)
    compiler_sha256 = Digest::SHA256.file(
      File.join(root, "crates/nlu-data/src/lexicon.rs")
    ).hexdigest
    raise Failure, "entry count differs" unless entries.length == 33

    entries.each do |entry|
      validate_entry(entry, rows, compiler_sha256)
    end
    keys = entries.map { |entry| entry_key(entry) }
    raise Failure, "entry order is not strict" unless
      keys.each_cons(2).all? { |left, right| (left <=> right) == -1 }

    conflicts = entries.group_by { |entry| entry.fetch("surface") }
      .values.select { |group| group.length > 1 }
    raise Failure, "source conflict inventory differs" unless
      conflicts.length == 1 &&
        conflicts.first.length == 2 &&
        conflicts.first.map { |entry| entry.fetch("pos") }.sort == %w[NOUN VERB]

    expected_manifest = {
      "schema_version" => 1,
      "format" => "nlu-lexicon-package-v1",
      "transform_id" => "ptbr-lexicon-compile-v1",
      "input_sha256" => SOURCE_LEXICON_SHA256,
      "package_sha256" => Digest::SHA256.hexdigest(package),
      "package_bytes" => package.bytesize,
      "entry_count" => entries.length,
      "source_ids" => [SOURCE_ID],
      "derivative_licenses" => ["Apache-2.0"]
    }
    raise Failure, "package manifest differs" unless manifest == expected_manifest
    raise Failure, "package manifest is not canonical" unless
      canonical_json(manifest) + "\n" == File.binread(File.join(root, PACKAGE_MANIFEST))
  end

  def validate_entry(entry, rows, compiler_sha256)
    raise Failure, "entry fields differ" unless entry.keys.sort == ENTRY_FIELDS.sort
    raise Failure, "technical fixture entered package" if
      JSON.generate(entry).include?("FIXTURE_TECNICA")

    id = entry.fetch("analysis_id")
    row = rows.fetch(id)
    source_record = row.fetch(:record)
    %w[schema_version analysis_id surface lemma pos features].each do |field|
      raise Failure, "entry changed source field #{field}" unless
        entry[field] == source_record[field]
    end

    record_sha256 = Digest::SHA256.hexdigest(row.fetch(:bytes))
    source = entry.fetch("source")
    expected_source = {
      "source_id" => SOURCE_ID,
      "admission_status" => "PROJECT_AUTHORED_SYNTHETIC",
      "corpus_version" => "1.0.0",
      "locale" => "pt-BR",
      "source_license" => "Apache-2.0",
      "partition" => "shared",
      "source_manifest_sha256" => SOURCE_MANIFEST_SHA256,
      "artifact_path" => SOURCE_LEXICON,
      "artifact_sha256" => SOURCE_LEXICON_SHA256,
      "record_id" => id,
      "record_sha256" => record_sha256
    }
    raise Failure, "entry source lineage differs" unless source == expected_source

    generation = entry.fetch("generation")
    expected_parameters = [
      {"name" => "surface", "values" => [entry.fetch("surface")]},
      {"name" => "lemma", "values" => [entry.fetch("lemma")]},
      {"name" => "pos", "values" => [entry.fetch("pos")]},
      {"name" => "features", "values" => entry.fetch("features")}
    ]
    expected_generation = {
      "generator_id" => "p02-generator-v1",
      "generator_implementation_sha256" => GENERATOR_SHA256,
      "specification_path" => "data/project-authored/p02-v1/specification.yaml",
      "specification_sha256" => SPECIFICATION_SHA256,
      "family" => "p02-generator-v1/build_lexicon_records",
      "parameters" => expected_parameters,
      "canonical_identity_sha256" => Digest::SHA256.hexdigest(
        canonical_json(
          [entry.fetch("surface"), entry.fetch("lemma"), entry.fetch("pos"),
           entry.fetch("features")]
        )
      )
    }
    raise Failure, "entry generation lineage differs" unless
      generation == expected_generation

    payload = entry.reject { |field, _value| field == "transformations" }
    expected_transformations = [
      {
        "transform_id" => "p02-generator-v1",
        "implementation_sha256" => GENERATOR_SHA256,
        "input_sha256" => SPECIFICATION_SHA256,
        "output_sha256" => record_sha256
      },
      {
        "transform_id" => "ptbr-lexicon-compile-v1",
        "implementation_sha256" => compiler_sha256,
        "input_sha256" => record_sha256,
        "output_sha256" => Digest::SHA256.hexdigest(canonical_json(payload))
      }
    ]
    raise Failure, "entry transformation lineage differs" unless
      entry.fetch("transformations") == expected_transformations
    raise Failure, "entry derivative license differs" unless
      entry.fetch("derivative_license") == "Apache-2.0"
  rescue KeyError => error
    raise Failure, "entry missing key #{error.key}"
  end

  def entry_key(entry)
    [
      entry.fetch("surface"),
      entry.fetch("pos"),
      entry.fetch("lemma"),
      entry.fetch("features"),
      entry.fetch("source").fetch("source_id"),
      entry.fetch("analysis_id")
    ]
  end

  def validate_schemas(root, entry, manifest)
    schemas = [
      [
        parse_json(File.binread(File.join(root, ENTRY_SCHEMA)), ENTRY_SCHEMA),
        "https://nlu.local/schemas/lexicon-entry-v1.schema.json",
        ENTRY_FIELDS,
        entry
      ],
      [
        parse_json(File.binread(File.join(root, MANIFEST_SCHEMA)), MANIFEST_SCHEMA),
        "https://nlu.local/schemas/lexicon-package-manifest-v1.schema.json",
        MANIFEST_FIELDS,
        manifest
      ]
    ]
    schemas.each do |schema, id, fields, emitted|
      raise Failure, "schema dialect differs" unless
        schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
      raise Failure, "schema ID differs" unless schema["$id"] == id
      raise Failure, "schema is not a closed object" unless
        schema["type"] == "object" && schema["additionalProperties"] == false
      raise Failure, "schema required fields differ" unless
        schema.fetch("required").sort == fields.sort
      raise Failure, "schema and emitted fields differ" unless
        emitted.keys.sort == fields.sort
    end
  rescue KeyError => error
    raise Failure, "schema missing key #{error.key}"
  end

  def validate_runtime_contract(root)
    runtime = File.binread(File.join(root, "crates/lang-ptbr/src/lexicon.rs"))
    %w[
      BTreeMap
      Lexicon::bundled
      LexicalLookup::Unknown
      LexicalLookup::Unique
      LexicalLookup::Conflict
      lookup_token
      by_surface
      by_identity
    ].each do |token|
      raise Failure, "runtime contract missing #{token}" unless runtime.include?(token)
    end
    raise Failure, "runtime exposes caller artifact constructor" if
      runtime.match?(/pub\s+fn\s+from_artifact/)
    cli = File.binread(File.join(root, "crates/nlu-data/src/cli.rs"))
    %w[compile-lexicon remove-lexicon-source].each do |command|
      raise Failure, "CLI command missing #{command}" unless cli.include?(command)
    end
  end

  def validate_requirements(root, require_satisfied:)
    traceability = File.binread(
      File.join(root, "docs/evidence/REQUIREMENTS-TRACEABILITY.md")
    )
    REQUIREMENTS.each do |id|
      row = traceability.lines.find { |line| line.start_with?("| `#{id}` |") }
      raise Failure, "requirement row missing: #{id}" if row.nil?
      if require_satisfied && !row.rstrip.end_with?("| SATISFIED |")
        raise Failure, "requirement is not satisfied: #{id}"
      end
    end
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

  def run_cargo_tests(root)
    tool_bin = File.join(root, ".tools/rust-1.98.0/bin")
    environment = {
      "HOME" => "/var/empty",
      "PATH" => "#{tool_bin}:/usr/bin:/bin",
      "LC_ALL" => "C",
      "LANG" => "C",
      "TZ" => "UTC",
      "SOURCE_DATE_EPOCH" => "0",
      "CARGO_NET_OFFLINE" => "true",
      "CARGO_INCREMENTAL" => "0",
      "CARGO_TARGET_DIR" => File.join(root, "target/p06-gate"),
      "RUSTC" => File.join(tool_bin, "rustc")
    }
    output, status = Open3.capture2e(
      environment,
      File.join(tool_bin, "cargo"),
      "test",
      "-p",
      "nlu-data",
      "-p",
      "lang-ptbr",
      "--all-features",
      chdir: root
    )
    return if status.success?

    warn output
    raise Failure, "P06 Cargo tests failed"
  end
end

P06Validation.run(ARGV) if $PROGRAM_NAME == __FILE__
