# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

module P08Validation
  class Failure < StandardError; end
  class DuplicateKey < StandardError; end

  class DuplicateRejectingHash < Hash
    def []=(key, value)
      raise DuplicateKey, key if key?(key)

      super
    end
  end

  ParsedRow = Struct.new(:value, :bytes, keyword_init: true)

  ROOT = File.expand_path("..", __dir__)
  SOURCE_ID = "project-authored-synthetic-ptbr-v1"
  SOURCE_MANIFEST = "data/manifests/project-authored-synthetic-ptbr-v1.json"
  CORPUS_MANIFEST = "data/project-authored/p02-v1/manifest.json"
  SPECIFICATION = "data/project-authored/p02-v1/specification.yaml"
  GENERATOR = "tools/generate-p02-corpus.rb"
  SOURCE_POS = "data/project-authored/p02-v1/pos-context.jsonl"

  SPLIT_DIRECTORY = "data/evaluation/p08/pos-v1/splits"
  TRAIN = "#{SPLIT_DIRECTORY}/train.jsonl"
  DEVELOPMENT = "#{SPLIT_DIRECTORY}/development.jsonl"
  HELDOUT = "#{SPLIT_DIRECTORY}/heldout.jsonl"
  SPLIT_MANIFEST = "#{SPLIT_DIRECTORY}/split-manifest.json"
  MODEL_PACKAGE = "data/pos/p08/package.bin"
  MODEL_MANIFEST = "data/pos/p08/package-manifest.json"
  EVALUATION_MANIFEST = "data/evaluation/p08/pos-v1/manifest.json"
  EVALUATION_REPORT = "data/evaluation/p08/pos-v1/report.json"

  SPLIT_SCHEMA = "schemas/pos-split-manifest-v1.schema.json"
  MODEL_SCHEMA = "schemas/pos-model-manifest-v1.schema.json"
  EVALUATION_MANIFEST_SCHEMA =
    "schemas/pos-evaluation-manifest-v1.schema.json"
  EVALUATION_REPORT_SCHEMA =
    "schemas/pos-evaluation-report-v1.schema.json"

  SOURCE_MANIFEST_SHA256 =
    "d9e1ca32ec0f92aa6b5fc6c1d4f232f93389e0bf8031267d23daddf7287006c5"
  CORPUS_MANIFEST_SHA256 =
    "a251485ba2f8d5032603200b7e171954213383aeceac9a8f394edb09a265e72a"
  SPECIFICATION_SHA256 =
    "f72451f03d1a5e2e4955b5d2857bd7d33b3b012912d920e53a3d85719f14859d"
  GENERATOR_SHA256 =
    "ff8817afc2c2f13d539ab7d10720cab407d769ca3a6189dcc55d43ea052689d1"
  SOURCE_POS_SHA256 =
    "85ad18caf3ae749d3ec0135c3c01ce6d754f831d395abdc44ff1c3643a18fac8"
  TRAIN_SHA256 =
    "b78d4b79350638da0cacf2c6c027d07b37919a9e3bc82de654b4f1c0f0984461"
  DEVELOPMENT_SHA256 =
    "50df080f1d0f5e4d22dab1fd1221eb3aac61a3152afbfb759f0a728da1072880"
  HELDOUT_SHA256 =
    "876e85049fb391b5171641e206b7bc2b4ae2bb4e1d58f36858bf1b5c91812dd7"
  SPLIT_MANIFEST_SHA256 =
    "bd6ef5cf79e188d43eb6b6ecddd4de7e5f767aab14316a3a4b677a04d9c2fb5c"
  MODEL_PACKAGE_SHA256 =
    "23beb6dd464c4bd03d69bb374be210fd3a187661c37673194f466b4270b8020c"
  MODEL_MANIFEST_SHA256 =
    "f89eaa786f37456d5e1d47e522ceea7bd96f41b272bdc9a6ca99407d7cc2b0bc"
  EVALUATION_MANIFEST_SHA256 =
    "c4ca9531c45eaff9df8a79f48a060f7a1716c3102b37b4caa24a5cba708ff048"
  EVALUATION_REPORT_SHA256 =
    "ffc8ea80508d1bd7505e73eefb26969babac9d4de9ba7b4014cc52a78c913982"
  ORIGINS_SHA256 =
    "7c9b3c0943f43dcc2327fcaec2edc61ff2eedc8e5a2c62f714c1c07cb388b757"

  ARTIFACTS = {
    SOURCE_MANIFEST => [6_204, SOURCE_MANIFEST_SHA256],
    CORPUS_MANIFEST => [11_091, CORPUS_MANIFEST_SHA256],
    SPECIFICATION => [18_201, SPECIFICATION_SHA256],
    GENERATOR => [24_477, GENERATOR_SHA256],
    SOURCE_POS => [222_999, SOURCE_POS_SHA256],
    TRAIN => [70_382, TRAIN_SHA256],
    DEVELOPMENT => [73_262, DEVELOPMENT_SHA256],
    HELDOUT => [79_355, HELDOUT_SHA256],
    SPLIT_MANIFEST => [3_858, SPLIT_MANIFEST_SHA256],
    MODEL_PACKAGE => [47, MODEL_PACKAGE_SHA256],
    MODEL_MANIFEST => [1_617, MODEL_MANIFEST_SHA256],
    EVALUATION_MANIFEST => [2_355, EVALUATION_MANIFEST_SHA256],
    EVALUATION_REPORT => [3_271, EVALUATION_REPORT_SHA256],
    SPLIT_SCHEMA => [
      6_462,
      "e5c510bd9ee57a7c1bd80ca765023defac10cd19e12722c5846b8e40df46e3bf"
    ],
    MODEL_SCHEMA => [
      3_889,
      "106ccf2648242304523bfdf9abe1ad9c8af24fb7c45c1e2be2455a4d0f92a0dd"
    ],
    EVALUATION_MANIFEST_SCHEMA => [
      5_104,
      "1332a49a432f8faa2656e9d74979389763026e489e2155d4f857e362dc1462de"
    ],
    EVALUATION_REPORT_SCHEMA => [
      10_928,
      "f93701e7c8714d76f1860b5c99fe32671b4e7765ee0d71bf825bdb120ca4d9cb"
    ]
  }.freeze

  SPLITS = %w[train development heldout].freeze
  POS_LABELS = %w[ADJ ADP DET NOUN NUM VERB X].freeze
  MODEL_LABELS = %w[ADP DET NOUN NUM VERB].freeze
  CONFUSION_LABELS = %w[unknown unique ambiguous].freeze
  ERROR_TAXONOMY = %w[
    exact_set_mismatch
    missing_expected_candidate
    unexpected_candidate
    unexpected_unknown
    unresolved_ambiguity
  ].freeze
  LIMITATIONS = %w[
    project_authored_labels_share_generator_with_runtime_lexicon
    single_source_origin_not_origin_disjoint
    templatic_internal_conformance_not_independent_accuracy
    heldout_unknown_subset_contains_four_expected_x_tokens
    no_unseen_language_or_cross_origin_generalization_claim
  ].freeze

  MODEL_ID = "p08-pos-transition-model-v1"
  ALGORITHM_ID = "adjacent-singleton-presence-noncascading-v1"
  MODEL_COMPILER_ID = "nlu-data-pos-transition-compiler-v1"
  MODEL_CONFIG_ID = "p08-pos-config-v1"
  BASELINE_ID = "lang-ptbr-independent-evidence-pos-baseline-v1"
  SELECTED_ID = "lang-ptbr-adjacent-transition-pos-v1"
  DATASET_ID = "p08-pos-internal-conformance"
  METRIC_SPEC = "exact-pos-candidate-set-aggregate-v1"

  RECORD_FIELDS = %w[
    schema_version case_id source_id corpus_version generator_id license locale
    split family document_id text text_sha256 tokens
  ].freeze
  TOKEN_FIELDS = %w[text begin_byte end_byte allowed_pos].freeze
  IDENTIFIER = /\A[a-z0-9][a-z0-9._-]*\z/
  SHA256 = /\A[0-9a-f]{64}\z/

  SPLIT_CONTRACTS = {
    "train" => {
      "path" => TRAIN,
      "bytes" => 70_382,
      "sha256" => TRAIN_SHA256,
      "records" => 80,
      "documents" => 8,
      "tokens" => 560,
      "case_ids_sha256" =>
        "2d19927df47be5f79b98ee6efffa290b512633682b2635dbe7de265653a4f481",
      "document_ids_sha256" =>
        "31548f0c55c3c66d2560a46b1567a4a197c1cf443ddecbc8d1f502fd3a8e3ce8",
      "text_sha256s_sha256" =>
        "af7d475417506b366b6eb226524f25b29bafb84d25f4dd9e39adfe8c6e1b7e2a",
      "origins_sha256" => ORIGINS_SHA256,
      "origin_count" => 1,
      "families" => ["pos-command-train-v1"],
      "label_counts" => {
        "ADP" => 80, "DET" => 80, "NOUN" => 160, "NUM" => 160, "VERB" => 80
      },
      "ambiguity_records" => 0
    },
    "development" => {
      "path" => DEVELOPMENT,
      "bytes" => 73_262,
      "sha256" => DEVELOPMENT_SHA256,
      "records" => 80,
      "documents" => 8,
      "tokens" => 560,
      "case_ids_sha256" =>
        "829b57ba407eda545d6643f7c3299eaef1d54908e16e76bafea9f80556c1d730",
      "document_ids_sha256" =>
        "fb7a90200770594266dec6b3ba0ca69ec07841bf2dfadad246313182a5e6c8a4",
      "text_sha256s_sha256" =>
        "1988b9ae8328899203310ab7c25bba24bca66a2ca5acedfb6222cff5a8f17db4",
      "origins_sha256" => ORIGINS_SHA256,
      "origin_count" => 1,
      "families" => ["pos-query-development-v1"],
      "label_counts" => {
        "ADP" => 80, "DET" => 80, "NOUN" => 160, "NUM" => 160, "VERB" => 80
      },
      "ambiguity_records" => 0
    },
    "heldout" => {
      "path" => HELDOUT,
      "bytes" => 79_355,
      "sha256" => HELDOUT_SHA256,
      "records" => 81,
      "documents" => 9,
      "tokens" => 643,
      "case_ids_sha256" =>
        "273c254d3dd18c2f296330f6affbd8e4f33bbc0ed35bb2c2de38480a9c5bf93f",
      "document_ids_sha256" =>
        "26ed164850cb01339215158824eb5c2f2f832b9516abad1cbe13326aeae1926b",
      "text_sha256s_sha256" =>
        "b1dc1f1aa9598155c783b43871136ba64b9959996d0972e464840f8975c970c4",
      "origins_sha256" => ORIGINS_SHA256,
      "origin_count" => 1,
      "families" => [
        "pos-ambiguity-heldout-v1",
        "pos-state-heldout-v1"
      ],
      "label_counts" => {
        "ADJ" => 80, "ADP" => 80, "DET" => 81, "NOUN" => 157,
        "NUM" => 160, "VERB" => 81, "X" => 4
      },
      "ambiguity_records" => 1
    }
  }.freeze

  PARTITION_CONTRACT = {
    "split_order" => SPLITS,
    "records" => 241,
    "documents" => 25,
    "tokens" => 1_763,
    "case_ids_sha256" =>
      "2bd856c701426893fc99cec421ef23c335ce62f390eb7c7fa47c45d3ef1dfa7c",
    "document_ids_sha256" =>
      "03fe393410fe4de1d4011d267c244bff82f93919d9af867f5e280ccf084938d7",
    "text_sha256s_sha256" =>
      "ebf82a790d2bfe50def2b0a6f69cd484fdbd46f1ace816344d577ba3f87213b4",
    "origins_sha256" => ORIGINS_SHA256,
    "origin_count" => 1,
    "families" => %w[
      pos-ambiguity-heldout-v1
      pos-command-train-v1
      pos-query-development-v1
      pos-state-heldout-v1
    ],
    "sentence_disjoint" => true,
    "document_disjoint" => true,
    "family_disjoint" => true,
    "complete" => true
  }.freeze

  EXPECTED_TRANSITIONS = [
    ["BOS", "VERB"],
    ["ADP", "NOUN"],
    ["DET", "NOUN"],
    ["NOUN", "NUM"],
    ["NUM", "ADP"],
    ["NUM", "EOS"],
    ["VERB", "DET"]
  ].freeze
  LABELS_SHA256 =
    "c122d646963857a97f12dba255a15d7213dbb1dcca45fb6bb003dbcbabccc9fa"
  TRANSITIONS_SHA256 =
    "2b336fcb85f5351fad17db5192312947cda76fdae816fa4ae5dfe7aaab8cf374"

  EXPECTED_RESULTS = {
    "baseline" => {
      "ambiguity" => {
        "compatible" => 2, "exact" => 0, "total" => 2, "unresolved" => 2
      },
      "candidate_counts" => {
        "false_negative" => 80, "false_positive" => 2, "true_positive" => 559
      },
      "confusion_matrix" => {
        "labels" => CONFUSION_LABELS,
        "matrix" => [[4, 0, 0], [80, 557, 2], [0, 0, 0]]
      },
      "document_exact" => {"denominator" => 9, "numerator" => 0},
      "error_categories" => {
        "exact_set_mismatch" => 82,
        "missing_expected_candidate" => 80,
        "unexpected_candidate" => 2,
        "unexpected_unknown" => 80,
        "unresolved_ambiguity" => 2
      },
      "exact_token_sets" => {"denominator" => 643, "numerator" => 561},
      "method_id" => BASELINE_ID,
      "origin_exact" => {"denominator" => 1, "numerator" => 0},
      "sentence_exact" => {"denominator" => 81, "numerator" => 0},
      "unknown" => {"correct" => 4, "expected" => 4, "unexpected" => 80}
    },
    "selected" => {
      "ambiguity" => {
        "compatible" => 2, "exact" => 1, "total" => 2, "unresolved" => 1
      },
      "candidate_counts" => {
        "false_negative" => 80, "false_positive" => 1, "true_positive" => 559
      },
      "confusion_matrix" => {
        "labels" => CONFUSION_LABELS,
        "matrix" => [[4, 0, 0], [80, 558, 1], [0, 0, 0]]
      },
      "document_exact" => {"denominator" => 9, "numerator" => 0},
      "error_categories" => {
        "exact_set_mismatch" => 81,
        "missing_expected_candidate" => 80,
        "unexpected_candidate" => 1,
        "unexpected_unknown" => 80,
        "unresolved_ambiguity" => 1
      },
      "exact_token_sets" => {"denominator" => 643, "numerator" => 562},
      "method_id" => SELECTED_ID,
      "origin_exact" => {"denominator" => 1, "numerator" => 0},
      "sentence_exact" => {"denominator" => 81, "numerator" => 0},
      "unknown" => {"correct" => 4, "expected" => 4, "unexpected" => 80}
    }
  }.freeze

  EXPECTED_DELTA = {
    "ambiguity_compatible" => 0,
    "ambiguity_exact" => 1,
    "ambiguity_unresolved" => -1,
    "candidate_false_negative" => 0,
    "candidate_false_positive" => -1,
    "candidate_true_positive" => 0,
    "direction" => "selected_minus_baseline",
    "document_exact" => 0,
    "exact_token_sets" => 1,
    "origin_exact" => 0,
    "sentence_exact" => 0,
    "unexpected_unknown" => 0,
    "unknown_correct" => 0
  }.freeze

  SPLIT_MANIFEST_FIELDS = %w[
    schema_version compiler_id dataset_id dataset_version digest_contract
    source partition splits
  ].freeze
  MODEL_MANIFEST_FIELDS = %w[
    schema_version format identity random_seed randomness_used source training
    label_count labels_sha256 transition_count transitions_sha256 package_bytes
    package_sha256
  ].freeze
  EVALUATION_MANIFEST_FIELDS = %w[
    schema_version domain runner_id dataset_id dataset_version split claim_scope
    locale source_id source_manifest_sha256 original_artifact_sha256
    split_manifest_path split_manifest_sha256 heldout model baseline_id
    selected_id metric_spec confusion_labels expected_labels error_taxonomy
    limitations
  ].freeze
  REPORT_FIELDS = %w[
    schema_version domain runner_id dataset_id dataset_version split claim_scope
    locale source_id source_manifest_sha256 original_artifact_sha256
    manifest_sha256 split_manifest_sha256 heldout_sha256 model_id
    model_package_sha256 baseline_id selected_id metric_spec confusion_labels
    error_taxonomy limitations results baseline_delta
  ].freeze
  METHOD_FIELDS = %w[
    method_id exact_token_sets candidate_counts sentence_exact document_exact
    origin_exact unknown ambiguity confusion_matrix error_categories
  ].freeze
  REQUIREMENTS = (1..6).map { |number| format("P08-POS-%03d", number) }.freeze
  PRODUCTION_CRATES = %w[lang-ptbr nlu-core nlu-data protocol].freeze
  POS_RUNTIME_FILES = %w[
    crates/lang-ptbr/src/pos.rs
    crates/nlu-data/src/pos.rs
  ].freeze
  EVALUATOR_LEAK_TOKENS = [
    "pos-eval",
    "pos_eval",
    "data/evaluation/p08",
    "pos-context.jsonl",
    DATASET_ID,
    METRIC_SPEC,
    "heldout_sha256",
    "baseline_delta",
    "error_taxonomy",
    "expected_labels",
    "exact_token_sets"
  ].freeze
  POS_RUNTIME_FORBIDDEN = [
    "pos-eval",
    "pos_eval",
    "pos-context",
    "split_manifest",
    "heldout",
    "oracle",
    "report",
    "expected_labels",
    "error_taxonomy",
    "baseline_delta",
    "std::fs",
    "std::net",
    "file::",
    "openoptions",
    "pathbuf",
    "read_bounded_root_file",
    "tcpstream",
    "udpsocket",
    "socketaddr",
    "reqwest",
    "hyper::",
    "curl"
  ].freeze

  module_function

  def run(arguments)
    arguments = arguments.dup
    no_cargo = arguments.delete("--no-cargo")
    review_candidate = arguments.delete("--review-candidate")
    unless arguments.empty?
      raise Failure,
            "usage: tools/validate-p08 [--no-cargo] [--review-candidate]"
    end

    validate(
      ROOT,
      run_cargo: !no_cargo && !review_candidate,
      require_satisfied: !review_candidate,
      run_reproduction: !no_cargo
    )
    puts(review_candidate ? "P08_REVIEW_CANDIDATE_PASS" : "P08_GATE_PASS")
  rescue Failure => error
    warn "P08_GATE_FAIL: #{error.message}"
    exit 1
  end

  def validate(root, run_cargo:, require_satisfied:, run_reproduction: true)
    validate_artifacts(root)

    source_rows = parse_pos_rows(
      File.binread(File.join(root, SOURCE_POS)),
      expected_split: nil,
      context: "P08 source POS"
    )
    split_manifest = read_canonical_json(
      root,
      SPLIT_MANIFEST,
      SPLIT_MANIFEST_SHA256
    )
    validate_split_artifacts(root, source_rows)
    validate_split_manifest(split_manifest)

    package_bytes = File.binread(File.join(root, MODEL_PACKAGE))
    package = parse_pos_package(package_bytes)
    model_manifest = read_canonical_json(
      root,
      MODEL_MANIFEST,
      MODEL_MANIFEST_SHA256
    )
    validate_model_manifest(model_manifest, package)

    evaluation_manifest = read_canonical_json(
      root,
      EVALUATION_MANIFEST,
      EVALUATION_MANIFEST_SHA256
    )
    validate_evaluation_manifest(evaluation_manifest)
    report = read_canonical_json(
      root,
      EVALUATION_REPORT,
      EVALUATION_REPORT_SHA256
    )
    validate_report(report, evaluation_manifest)

    validate_schemas(
      root,
      split_manifest,
      model_manifest,
      evaluation_manifest,
      report
    )
    validate_dependencies(root)
    validate_production_isolation(root)
    validate_requirements(root, require_satisfied: require_satisfied)

    if run_reproduction
      run_split_rebuild(root)
      run_training_reproduction(root)
      run_evaluator_reproduction(root)
    end
    run_cargo_tests(root) if run_cargo
    true
  end

  def validate_artifacts(root)
    ARTIFACTS.each_key do |relative|
      path = File.join(root, relative)
      raise Failure, "artifact is a symlink: #{relative}" if File.symlink?(path)
      raise Failure, "artifact is not a regular file: #{relative}" unless File.file?(path)

      validate_artifact_bytes(relative, File.binread(path))
    end
    true
  end

  def validate_artifact_bytes(relative, bytes)
    expected_bytes, expected_sha256 = ARTIFACTS.fetch(relative)
    raise Failure, "artifact byte count differs: #{relative}" unless
      bytes.bytesize == expected_bytes
    raise Failure, "artifact hash differs: #{relative}" unless
      Digest::SHA256.hexdigest(bytes) == expected_sha256

    true
  rescue KeyError
    raise Failure, "unrecognized pinned artifact: #{relative}"
  end

  def read_canonical_json(root, relative, expected_sha256)
    bytes = File.binread(File.join(root, relative))
    value = parse_json(bytes, relative)
    validate_canonical_bytes(bytes, value, relative, expected_sha256)
    value
  end

  def validate_canonical_bytes(bytes, value, context, expected_sha256 = nil)
    if expected_sha256 &&
       Digest::SHA256.hexdigest(bytes) != expected_sha256
      raise Failure, "#{context} hash differs"
    end
    raise Failure, "#{context} is not canonical with one final newline" unless
      bytes == canonical_json(value) + "\n"

    true
  end

  def parse_pos_rows(bytes, expected_split:, context:)
    raise Failure, "#{context} is empty or oversized" if
      bytes.empty? || bytes.bytesize > 1_048_576
    raise Failure, "#{context} lacks one final newline" unless
      bytes.end_with?("\n") && !bytes.end_with?("\r\n")

    rows = []
    bytes.each_line.with_index(1) do |line, line_number|
      raise Failure, "#{context} has an empty row" if line == "\n"
      raise Failure, "#{context} row exceeds byte limit" if line.bytesize > 32_768
      raise Failure, "#{context} row ending differs" unless
        line.end_with?("\n") && !line.end_with?("\r\n")

      row = parse_json(line, "#{context} row #{line_number}")
      validate_pos_row(row, expected_split, context)
      rows << ParsedRow.new(value: row, bytes: line.b)
    end
    raise Failure, "#{context} row count exceeds limit" if rows.length > 512

    rows
  end

  def validate_pos_row(row, expected_split, context)
    allowed_fields = RECORD_FIELDS + ["ambiguity_preserved"]
    raise Failure, "#{context} row fields differ" unless
      row.is_a?(Hash) &&
        (RECORD_FIELDS - row.keys).empty? &&
        (row.keys - allowed_fields).empty?
    raise Failure, "#{context} ambiguity marker differs" if
      row.key?("ambiguity_preserved") && row["ambiguity_preserved"] != true

    expected_lineage = {
      "schema_version" => 1,
      "source_id" => SOURCE_ID,
      "corpus_version" => "1.0.0",
      "generator_id" => "p02-generator-v1",
      "license" => "Apache-2.0",
      "locale" => "pt-BR"
    }
    expected_lineage.each do |field, expected|
      raise Failure, "#{context} row lineage differs: #{field}" unless
        row[field] == expected
    end
    split = row["split"]
    raise Failure, "#{context} split differs" unless
      SPLITS.include?(split) && (!expected_split || split == expected_split)
    %w[case_id family document_id].each do |field|
      value = row[field]
      raise Failure, "#{context} identifier differs: #{field}" unless
        value.is_a?(String) && value.bytesize <= 256 && value.match?(IDENTIFIER)
    end

    text = row["text"]
    text_sha256 = row["text_sha256"]
    raise Failure, "#{context} text differs" unless
      text.is_a?(String) && !text.empty? && text.valid_encoding? &&
        text.bytesize <= 32_768 && !text.include?("FIXTURE_TECNICA")
    raise Failure, "#{context} text identity differs" unless
      text_sha256.is_a?(String) && text_sha256.match?(SHA256) &&
        Digest::SHA256.hexdigest(text.b) == text_sha256

    tokens = row["tokens"]
    raise Failure, "#{context} token inventory differs" unless
      tokens.is_a?(Array) && !tokens.empty? && tokens.length <= 256
    previous_end = 0
    tokens.each do |token|
      raise Failure, "#{context} token fields differ" unless
        token.is_a?(Hash) && token.keys.sort == TOKEN_FIELDS.sort
      token_text = token["text"]
      begin_byte = token["begin_byte"]
      end_byte = token["end_byte"]
      raise Failure, "#{context} token span differs" unless
        token_text.is_a?(String) && !token_text.empty? &&
          !token_text.include?("FIXTURE_TECNICA") &&
          begin_byte.is_a?(Integer) && end_byte.is_a?(Integer) &&
          begin_byte >= previous_end && begin_byte < end_byte &&
          end_byte <= text.bytesize
      gap = text.byteslice(previous_end...begin_byte)
      slice = text.byteslice(begin_byte...end_byte)
      raise Failure, "#{context} token text differs" unless
        utf8_whitespace?(gap) &&
          slice == token_text &&
          text.byteslice(0...begin_byte).valid_encoding? &&
          text.byteslice(0...end_byte).valid_encoding?
      allowed_pos = token["allowed_pos"]
      raise Failure, "#{context} token POS set differs" unless
        allowed_pos.is_a?(Array) && allowed_pos.length == 1 &&
          POS_LABELS.include?(allowed_pos[0])
      previous_end = end_byte
    end
    raise Failure, "#{context} terminal token span differs" unless
      utf8_whitespace?(text.byteslice(previous_end..))
    true
  end

  def utf8_whitespace?(bytes)
    return false unless bytes

    value = bytes.dup.force_encoding(Encoding::UTF_8)
    value.valid_encoding? && value.match?(/\A[[:space:]]*\z/)
  end

  def validate_split_artifacts(root, source_rows)
    raise Failure, "source POS record inventory differs" unless source_rows.length == 241

    rows_by_split = {}
    SPLITS.each do |split|
      contract = SPLIT_CONTRACTS.fetch(split)
      bytes = File.binread(File.join(root, contract.fetch("path")))
      rows = parse_pos_rows(
        bytes,
        expected_split: split,
        context: "P08 #{split} split"
      )
      expected_bytes = source_rows
        .select { |row| row.value.fetch("split") == split }
        .map(&:bytes)
        .join
        .b
      raise Failure, "#{split} split did not preserve frozen source bytes" unless
        bytes == expected_bytes
      validate_split_inventory(split, rows, bytes)
      rows_by_split[split] = rows
    end
    validate_partition_inventory(source_rows, rows_by_split)
    true
  end

  def validate_split_inventory(split, rows, bytes)
    values = rows.map(&:value)
    origins = values.map { |row| origin(row) }
    label_counts = Hash.new(0)
    values.each do |row|
      row.fetch("tokens").each do |token|
        label_counts[token.fetch("allowed_pos").fetch(0)] += 1
      end
    end
    actual = {
      "path" => SPLIT_CONTRACTS.fetch(split).fetch("path"),
      "bytes" => bytes.bytesize,
      "sha256" => Digest::SHA256.hexdigest(bytes),
      "records" => values.length,
      "documents" => values.map { |row| row.fetch("document_id") }.uniq.length,
      "tokens" => values.sum { |row| row.fetch("tokens").length },
      "case_ids_sha256" =>
        collection_digest(values.map { |row| row.fetch("case_id") }),
      "document_ids_sha256" =>
        collection_digest(values.map { |row| row.fetch("document_id") }),
      "text_sha256s_sha256" =>
        collection_digest(values.map { |row| row.fetch("text_sha256") }),
      "origins_sha256" => collection_digest(origins),
      "origin_count" => origins.uniq.length,
      "families" => values.map { |row| row.fetch("family") }.uniq.sort,
      "label_counts" => label_counts.sort.to_h,
      "ambiguity_records" =>
        values.count { |row| row["ambiguity_preserved"] == true }
    }
    raise Failure, "#{split} split inventory differs" unless
      actual == SPLIT_CONTRACTS.fetch(split)
    true
  end

  def validate_partition_inventory(source_rows, rows_by_split)
    combined = SPLITS.flat_map { |split| rows_by_split.fetch(split) }
    raise Failure, "split partition is not complete" unless
      combined.map { |row| row.value.fetch("case_id") }.sort ==
        source_rows.map { |row| row.value.fetch("case_id") }.sort

    values = combined.map(&:value)
    case_ids = values.map { |row| row.fetch("case_id") }
    text_hashes = values.map { |row| row.fetch("text_sha256") }
    texts = values.map { |row| row.fetch("text") }
    raise Failure, "duplicate POS case identity" unless case_ids.uniq.length == 241
    raise Failure, "duplicate POS sentence hash" unless text_hashes.uniq.length == 241
    raise Failure, "duplicate POS sentence bytes" unless texts.uniq.length == 241
    validate_split_disjointness(rows_by_split, "document_id", "document")
    validate_split_disjointness(rows_by_split, "family", "family")

    origins = values.map { |row| origin(row) }
    actual = {
      "split_order" => SPLITS,
      "records" => values.length,
      "documents" => values.map { |row| row.fetch("document_id") }.uniq.length,
      "tokens" => values.sum { |row| row.fetch("tokens").length },
      "case_ids_sha256" => collection_digest(case_ids),
      "document_ids_sha256" =>
        collection_digest(values.map { |row| row.fetch("document_id") }),
      "text_sha256s_sha256" => collection_digest(text_hashes),
      "origins_sha256" => collection_digest(origins),
      "origin_count" => origins.uniq.length,
      "families" => values.map { |row| row.fetch("family") }.uniq.sort,
      "sentence_disjoint" => true,
      "document_disjoint" => true,
      "family_disjoint" => true,
      "complete" => true
    }
    raise Failure, "P08 partition inventory differs" unless
      actual == PARTITION_CONTRACT
    true
  end

  def validate_split_disjointness(rows_by_split, field, context)
    seen = {}
    rows_by_split.each do |split, rows|
      rows.each do |row|
        value = row.value.fetch(field)
        raise Failure, "#{context} intersects P08 splits" if
          seen.key?(value) && seen[value] != split
        seen[value] = split
      end
    end
  end

  def origin(row)
    %w[source_id corpus_version generator_id].to_h do |field|
      [field, row.fetch(field)]
    end
  end

  def collection_digest(values)
    encoded = values.map { |value| canonical_json(value) }.uniq.sort
    Digest::SHA256.hexdigest("[#{encoded.join(',')}]")
  end

  def expected_split_manifest
    split_entries = SPLITS.map do |split|
      contract = SPLIT_CONTRACTS.fetch(split)
      {
        "split" => split,
        "path" => contract.fetch("path"),
        "bytes" => contract.fetch("bytes"),
        "sha256" => contract.fetch("sha256"),
        "records" => contract.fetch("records"),
        "documents" => contract.fetch("documents"),
        "tokens" => contract.fetch("tokens"),
        "case_ids_sha256" => contract.fetch("case_ids_sha256"),
        "document_ids_sha256" => contract.fetch("document_ids_sha256"),
        "text_sha256s_sha256" => contract.fetch("text_sha256s_sha256"),
        "origins_sha256" => contract.fetch("origins_sha256"),
        "origin_count" => contract.fetch("origin_count"),
        "families" => contract.fetch("families")
      }
    end
    {
      "compiler_id" => "p08-pos-split-compiler-v1",
      "dataset_id" => "p08-pos-context-splits-v1",
      "dataset_version" => "1.0.0",
      "digest_contract" => {
        "algorithm" => "sha256",
        "collection_encoding" => "canonical-json-sorted-unique-array-v1",
        "origin_fields" => %w[source_id corpus_version generator_id]
      },
      "partition" => PARTITION_CONTRACT,
      "schema_version" => 1,
      "source" => {
        "artifact_bytes" => 222_999,
        "artifact_path" => SOURCE_POS,
        "artifact_records" => 241,
        "artifact_sha256" => SOURCE_POS_SHA256,
        "claim_scope" => "internal_conformance_only",
        "corpus_manifest_path" => CORPUS_MANIFEST,
        "corpus_manifest_sha256" => CORPUS_MANIFEST_SHA256,
        "corpus_version" => "1.0.0",
        "generator_id" => "p02-generator-v1",
        "generator_path" => GENERATOR,
        "generator_sha256" => GENERATOR_SHA256,
        "license" => "Apache-2.0",
        "locale" => "pt-BR",
        "source_id" => SOURCE_ID,
        "source_manifest_path" => SOURCE_MANIFEST,
        "source_manifest_sha256" => SOURCE_MANIFEST_SHA256,
        "specification_path" => SPECIFICATION,
        "specification_sha256" => SPECIFICATION_SHA256
      },
      "splits" => split_entries
    }
  end

  def validate_split_manifest(manifest)
    raise Failure, "split manifest fields differ" unless
      manifest.is_a?(Hash) &&
        manifest.keys.sort == SPLIT_MANIFEST_FIELDS.sort
    expected_split_manifest.each do |field, expected|
      raise Failure, "split manifest #{field} differs" unless
        manifest[field] == expected
    end
    true
  end

  def parse_pos_package(bytes)
    raise Failure, "POS package exceeds limit" if bytes.bytesize > 16_384
    raise Failure, "POS package header is truncated" if bytes.bytesize < 11
    raise Failure, "POS package magic differs" unless
      bytes.byteslice(0, 7) == "NLUPOS\0".b
    raise Failure, "POS package version differs" unless bytes.getbyte(7) == 1

    label_count = bytes.getbyte(8)
    transition_count = bytes.byteslice(9, 2).unpack1("n")
    raise Failure, "POS package label count differs" unless label_count == 5
    raise Failure, "POS package transition count differs" unless
      transition_count == 7

    offset = 11
    labels = []
    label_count.times do
      length = bytes.getbyte(offset)
      raise Failure, "POS package label length is truncated" unless length
      offset += 1
      payload = bytes.byteslice(offset, length)
      raise Failure, "POS package label is truncated" unless
        payload && payload.bytesize == length
      label = payload.dup.force_encoding(Encoding::UTF_8)
      raise Failure, "POS package label is invalid" unless
        label.valid_encoding? && label.match?(/\A[A-Z][A-Z0-9_]{0,31}\z/)
      labels << label
      offset += length
    end
    raise Failure, "POS package labels differ" unless labels == MODEL_LABELS

    encoded_transitions = []
    transition_count.times do
      payload = bytes.byteslice(offset, 2)
      raise Failure, "POS package transition is truncated" unless
        payload && payload.bytesize == 2
      encoded_transitions << payload.bytes
      offset += 2
    end
    raise Failure, "POS package has trailing bytes" unless offset == bytes.bytesize
    raise Failure, "POS package transition order differs" unless
      encoded_transitions.each_cons(2).all? do |left, right|
        (left <=> right) == -1
      end

    transitions = encoded_transitions.map do |from, to|
      [decode_endpoint(from, labels), decode_endpoint(to, labels)]
    end
    raise Failure, "POS package transition inventory differs" unless
      transitions == EXPECTED_TRANSITIONS
    raise Failure, "POS package boundary transition differs" if
      transitions.any? do |from, to|
        from == "EOS" || to == "BOS" || [from, to] == %w[BOS EOS]
      end
    used_labels = transitions.flatten & labels
    raise Failure, "POS package label coverage differs" unless
      used_labels.sort == labels
    raise Failure, "POS package boundary coverage differs" unless
      transitions.any? { |from, _to| from == "BOS" } &&
        transitions.any? { |_from, to| to == "EOS" }

    label_bytes = [labels.length].pack("C") +
      labels.map { |label| [label.bytesize].pack("C") + label.b }.join
    transition_bytes = [encoded_transitions.length].pack("n") +
      encoded_transitions.flatten.pack("C*")
    result = {
      "labels" => labels,
      "transitions" => transitions,
      "label_count" => labels.length,
      "labels_sha256" => Digest::SHA256.hexdigest(label_bytes),
      "transition_count" => transitions.length,
      "transitions_sha256" => Digest::SHA256.hexdigest(transition_bytes),
      "package_bytes" => bytes.bytesize,
      "package_sha256" => Digest::SHA256.hexdigest(bytes)
    }
    raise Failure, "POS package label digest differs" unless
      result["labels_sha256"] == LABELS_SHA256
    raise Failure, "POS package transition digest differs" unless
      result["transitions_sha256"] == TRANSITIONS_SHA256
    result
  end

  def decode_endpoint(code, labels)
    return "BOS" if code.zero?
    return "EOS" if code == labels.length + 1

    labels.fetch(code - 1)
  rescue IndexError
    raise Failure, "POS package endpoint is invalid"
  end

  def expected_model_manifest
    {
      "format" => "nlu-pos-transition-package-v1",
      "identity" => {
        "algorithm_id" => ALGORITHM_ID,
        "compiler_id" => MODEL_COMPILER_ID,
        "config_id" => MODEL_CONFIG_ID,
        "model_id" => MODEL_ID
      },
      "label_count" => 5,
      "labels_sha256" => LABELS_SHA256,
      "package_bytes" => 47,
      "package_sha256" => MODEL_PACKAGE_SHA256,
      "random_seed" => 0,
      "randomness_used" => false,
      "schema_version" => 1,
      "source" => {
        "corpus_version" => "1.0.0",
        "generator_id" => "p02-generator-v1",
        "generator_sha256" => GENERATOR_SHA256,
        "locale" => "pt-BR",
        "original_pos_artifact_sha256" => SOURCE_POS_SHA256,
        "source_id" => SOURCE_ID,
        "source_license" => "Apache-2.0",
        "source_manifest_sha256" => SOURCE_MANIFEST_SHA256,
        "specification_sha256" => SPECIFICATION_SHA256
      },
      "training" => {
        "physical_train_slice_sha256" => TRAIN_SHA256,
        "train_case_digest_sha256" =>
          SPLIT_CONTRACTS.fetch("train").fetch("case_ids_sha256"),
        "train_document_count" => 8,
        "train_document_digest_sha256" =>
          SPLIT_CONTRACTS.fetch("train").fetch("document_ids_sha256"),
        "train_origin_digest_sha256" => ORIGINS_SHA256,
        "train_sentence_count" => 80,
        "train_token_count" => 560
      },
      "transition_count" => 7,
      "transitions_sha256" => TRANSITIONS_SHA256
    }
  end

  def validate_model_manifest(manifest, package)
    raise Failure, "model manifest fields differ" unless
      manifest.is_a?(Hash) &&
        manifest.keys.sort == MODEL_MANIFEST_FIELDS.sort
    expected_model_manifest.each do |field, expected|
      raise Failure, "model manifest #{field} differs" unless
        manifest[field] == expected
    end
    %w[
      label_count labels_sha256 transition_count transitions_sha256
      package_bytes package_sha256
    ].each do |field|
      raise Failure, "model package/manifest linkage differs: #{field}" unless
        manifest[field] == package[field]
    end
    true
  end

  def expected_evaluation_manifest
    heldout = SPLIT_CONTRACTS.fetch("heldout")
    {
      "baseline_id" => BASELINE_ID,
      "claim_scope" => "internal_conformance_only",
      "confusion_labels" => CONFUSION_LABELS,
      "dataset_id" => DATASET_ID,
      "dataset_version" => "1.0.0",
      "domain" => "pos",
      "error_taxonomy" => ERROR_TAXONOMY,
      "expected_labels" => POS_LABELS,
      "heldout" => {
        "case_ids_sha256" => heldout.fetch("case_ids_sha256"),
        "document_ids_sha256" => heldout.fetch("document_ids_sha256"),
        "documents" => 9,
        "origin_count" => 1,
        "origins_sha256" => ORIGINS_SHA256,
        "path" => HELDOUT,
        "records" => 81,
        "sha256" => HELDOUT_SHA256,
        "text_sha256s_sha256" => heldout.fetch("text_sha256s_sha256"),
        "tokens" => 643
      },
      "limitations" => LIMITATIONS,
      "locale" => "pt-BR",
      "metric_spec" => METRIC_SPEC,
      "model" => {
        "algorithm_id" => ALGORITHM_ID,
        "compiler_id" => MODEL_COMPILER_ID,
        "config_id" => MODEL_CONFIG_ID,
        "manifest_path" => MODEL_MANIFEST,
        "manifest_sha256" => MODEL_MANIFEST_SHA256,
        "model_id" => MODEL_ID,
        "package_bytes" => 47,
        "package_path" => MODEL_PACKAGE,
        "package_sha256" => MODEL_PACKAGE_SHA256
      },
      "original_artifact_sha256" => SOURCE_POS_SHA256,
      "runner_id" => "pos-eval-v1",
      "schema_version" => 1,
      "selected_id" => SELECTED_ID,
      "source_id" => SOURCE_ID,
      "source_manifest_sha256" => SOURCE_MANIFEST_SHA256,
      "split" => "heldout",
      "split_manifest_path" => SPLIT_MANIFEST,
      "split_manifest_sha256" => SPLIT_MANIFEST_SHA256
    }
  end

  def validate_evaluation_manifest(manifest)
    raise Failure, "evaluation manifest fields differ" unless
      manifest.is_a?(Hash) &&
        manifest.keys.sort == EVALUATION_MANIFEST_FIELDS.sort
    expected_evaluation_manifest.each do |field, expected|
      raise Failure, "evaluation manifest #{field} differs" unless
        manifest[field] == expected
    end
    true
  end

  def expected_report_scalars
    {
      "schema_version" => 1,
      "domain" => "pos",
      "runner_id" => "pos-eval-v1",
      "dataset_id" => DATASET_ID,
      "dataset_version" => "1.0.0",
      "split" => "heldout",
      "claim_scope" => "internal_conformance_only",
      "locale" => "pt-BR",
      "source_id" => SOURCE_ID,
      "source_manifest_sha256" => SOURCE_MANIFEST_SHA256,
      "original_artifact_sha256" => SOURCE_POS_SHA256,
      "manifest_sha256" => EVALUATION_MANIFEST_SHA256,
      "split_manifest_sha256" => SPLIT_MANIFEST_SHA256,
      "heldout_sha256" => HELDOUT_SHA256,
      "model_id" => MODEL_ID,
      "model_package_sha256" => MODEL_PACKAGE_SHA256,
      "baseline_id" => BASELINE_ID,
      "selected_id" => SELECTED_ID,
      "metric_spec" => METRIC_SPEC,
      "confusion_labels" => CONFUSION_LABELS,
      "error_taxonomy" => ERROR_TAXONOMY,
      "limitations" => LIMITATIONS
    }
  end

  def validate_report(report, manifest)
    raise Failure, "evaluation report fields differ" unless
      report.is_a?(Hash) && report.keys.sort == REPORT_FIELDS.sort
    expected_report_scalars.each do |field, expected|
      raise Failure, "evaluation report #{field} differs" unless
        report[field] == expected
    end
    {
      "dataset_id" => "dataset_id",
      "dataset_version" => "dataset_version",
      "split" => "split",
      "claim_scope" => "claim_scope",
      "locale" => "locale",
      "source_id" => "source_id",
      "source_manifest_sha256" => "source_manifest_sha256",
      "original_artifact_sha256" => "original_artifact_sha256",
      "split_manifest_sha256" => "split_manifest_sha256",
      "baseline_id" => "baseline_id",
      "selected_id" => "selected_id",
      "metric_spec" => "metric_spec",
      "confusion_labels" => "confusion_labels",
      "error_taxonomy" => "error_taxonomy",
      "limitations" => "limitations"
    }.each do |report_field, manifest_field|
      raise Failure, "report/manifest linkage differs: #{report_field}" unless
        report[report_field] == manifest[manifest_field]
    end
    raise Failure, "report heldout linkage differs" unless
      report["heldout_sha256"] == manifest.dig("heldout", "sha256")
    raise Failure, "report model linkage differs" unless
      report["model_id"] == manifest.dig("model", "model_id") &&
        report["model_package_sha256"] ==
          manifest.dig("model", "package_sha256")

    results = report["results"]
    raise Failure, "evaluation result inventory differs" unless
      results.is_a?(Hash) && results.keys.sort == %w[baseline selected]
    validate_method(results.fetch("baseline"), BASELINE_ID, "baseline")
    validate_method(results.fetch("selected"), SELECTED_ID, "selected")
    raise Failure, "evaluation metrics differ from frozen result" unless
      results == EXPECTED_RESULTS

    delta = report["baseline_delta"]
    raise Failure, "baseline delta reconciliation differs" unless
      delta == calculated_delta(results)
    raise Failure, "baseline delta differs from frozen result" unless
      delta == EXPECTED_DELTA
    reject_floats(report, "P08 evaluation report")
    true
  rescue KeyError => error
    raise Failure, "evaluation report missing key #{error.key}"
  end

  def validate_method(method, expected_id, context)
    raise Failure, "#{context} metric fields differ" unless
      method.is_a?(Hash) && method.keys.sort == METHOD_FIELDS.sort
    raise Failure, "#{context} method identity differs" unless
      method["method_id"] == expected_id

    exact = validate_fraction(method["exact_token_sets"], 643, context)
    sentence = validate_fraction(method["sentence_exact"], 81, context)
    document = validate_fraction(method["document_exact"], 9, context)
    origin_metric = validate_fraction(method["origin_exact"], 1, context)

    counts = method["candidate_counts"]
    validate_integer_object(
      counts,
      %w[true_positive false_positive false_negative],
      "#{context} candidate counts"
    )
    unknown = method["unknown"]
    validate_integer_object(
      unknown,
      %w[expected correct unexpected],
      "#{context} unknown metrics"
    )
    ambiguity = method["ambiguity"]
    validate_integer_object(
      ambiguity,
      %w[exact compatible unresolved total],
      "#{context} ambiguity metrics"
    )
    errors = method["error_categories"]
    validate_integer_object(errors, ERROR_TAXONOMY, "#{context} errors")

    confusion = method["confusion_matrix"]
    raise Failure, "#{context} confusion matrix fields differ" unless
      confusion.is_a?(Hash) &&
        confusion.keys.sort == %w[labels matrix] &&
        confusion["labels"] == CONFUSION_LABELS
    matrix = confusion["matrix"]
    raise Failure, "#{context} confusion matrix shape differs" unless
      matrix.is_a?(Array) && matrix.length == 3 &&
        matrix.all? do |row|
          row.is_a?(Array) && row.length == 3 &&
            row.all? { |value| nonnegative_integer?(value) }
        end

    raise Failure, "#{context} metric reconciliation differs" unless
      exact.fetch("numerator") <= 643 &&
        sentence.fetch("numerator") <= 81 &&
        document.fetch("numerator") <= 9 &&
        origin_metric.fetch("numerator") <= 1 &&
        matrix.flatten.sum == 643 &&
        matrix.map(&:sum) == [4, 639, 0] &&
        exact.fetch("numerator") + errors.fetch("exact_set_mismatch") == 643 &&
        counts.fetch("true_positive") + counts.fetch("false_negative") == 639 &&
        errors.fetch("missing_expected_candidate") ==
          counts.fetch("false_negative") &&
        errors.fetch("unexpected_candidate") ==
          counts.fetch("false_positive") &&
        unknown.fetch("expected") == 4 &&
        unknown.fetch("correct") <= 4 &&
        unknown.fetch("correct") == matrix[0][0] &&
        unknown.fetch("unexpected") == matrix[1][0] + matrix[2][0] &&
        errors.fetch("unexpected_unknown") == unknown.fetch("unexpected") &&
        ambiguity.fetch("total") == 2 &&
        ambiguity.fetch("exact") <= ambiguity.fetch("compatible") &&
        ambiguity.fetch("compatible") <= 2 &&
        ambiguity.fetch("unresolved") <= 2 &&
        errors.fetch("unresolved_ambiguity") ==
          ambiguity.fetch("unresolved")
    true
  end

  def validate_fraction(value, denominator, context)
    validate_integer_object(value, %w[numerator denominator], "#{context} fraction")
    raise Failure, "#{context} denominator differs" unless
      value["denominator"] == denominator
    value
  end

  def validate_integer_object(value, fields, context)
    raise Failure, "#{context} fields differ" unless
      value.is_a?(Hash) && value.keys.sort == fields.sort
    raise Failure, "#{context} contains invalid count" unless
      value.values.all? { |item| nonnegative_integer?(item) }
    true
  end

  def nonnegative_integer?(value)
    value.is_a?(Integer) && value >= 0
  end

  def calculated_delta(results)
    baseline = results.fetch("baseline")
    selected = results.fetch("selected")
    {
      "ambiguity_compatible" =>
        selected.dig("ambiguity", "compatible") -
          baseline.dig("ambiguity", "compatible"),
      "ambiguity_exact" =>
        selected.dig("ambiguity", "exact") -
          baseline.dig("ambiguity", "exact"),
      "ambiguity_unresolved" =>
        selected.dig("ambiguity", "unresolved") -
          baseline.dig("ambiguity", "unresolved"),
      "candidate_false_negative" =>
        selected.dig("candidate_counts", "false_negative") -
          baseline.dig("candidate_counts", "false_negative"),
      "candidate_false_positive" =>
        selected.dig("candidate_counts", "false_positive") -
          baseline.dig("candidate_counts", "false_positive"),
      "candidate_true_positive" =>
        selected.dig("candidate_counts", "true_positive") -
          baseline.dig("candidate_counts", "true_positive"),
      "direction" => "selected_minus_baseline",
      "document_exact" =>
        selected.dig("document_exact", "numerator") -
          baseline.dig("document_exact", "numerator"),
      "exact_token_sets" =>
        selected.dig("exact_token_sets", "numerator") -
          baseline.dig("exact_token_sets", "numerator"),
      "origin_exact" =>
        selected.dig("origin_exact", "numerator") -
          baseline.dig("origin_exact", "numerator"),
      "sentence_exact" =>
        selected.dig("sentence_exact", "numerator") -
          baseline.dig("sentence_exact", "numerator"),
      "unexpected_unknown" =>
        selected.dig("unknown", "unexpected") -
          baseline.dig("unknown", "unexpected"),
      "unknown_correct" =>
        selected.dig("unknown", "correct") -
          baseline.dig("unknown", "correct")
    }
  end

  def reject_floats(value, context)
    case value
    when Float
      raise Failure, "#{context} contains floating-point value"
    when Hash
      value.each_value { |child| reject_floats(child, context) }
    when Array
      value.each { |child| reject_floats(child, context) }
    end
  end

  def validate_schemas(root, split_manifest, model_manifest, eval_manifest, report)
    split_schema = parse_schema(root, SPLIT_SCHEMA)
    model_schema = parse_schema(root, MODEL_SCHEMA)
    eval_schema = parse_schema(root, EVALUATION_MANIFEST_SCHEMA)
    report_schema = parse_schema(root, EVALUATION_REPORT_SCHEMA)

    validate_closed_schema(
      split_schema,
      "https://nlu.local/schemas/pos-split-manifest-v1.schema.json",
      SPLIT_MANIFEST_FIELDS,
      split_manifest
    )
    validate_closed_schema(
      model_schema,
      "https://nlu.local/schemas/pos-model-manifest-v1.schema.json",
      MODEL_MANIFEST_FIELDS,
      model_manifest
    )
    validate_closed_schema(
      eval_schema,
      "https://nlu.local/schemas/pos-evaluation-manifest-v1.schema.json",
      EVALUATION_MANIFEST_FIELDS,
      eval_manifest
    )
    validate_closed_schema(
      report_schema,
      "https://nlu.local/schemas/pos-evaluation-report-v1.schema.json",
      REPORT_FIELDS,
      report
    )

    raise Failure, "split schema source identity differs" unless
      split_schema.dig(
        "properties", "source", "properties", "artifact_sha256", "const"
      ) == SOURCE_POS_SHA256
    raise Failure, "model schema configuration differs" unless
      model_schema.dig(
        "properties", "identity", "properties", "config_id", "const"
      ) == MODEL_CONFIG_ID &&
        model_schema.dig("properties", "random_seed", "const") == 0 &&
        model_schema.dig("properties", "package_sha256", "const") ==
          MODEL_PACKAGE_SHA256
    raise Failure, "evaluation schema linkage differs" unless
      eval_schema.dig("properties", "split_manifest_sha256", "const") ==
        SPLIT_MANIFEST_SHA256 &&
        eval_schema.dig(
          "$defs", "heldout", "properties", "sha256", "const"
        ) == HELDOUT_SHA256 &&
        eval_schema.dig(
          "$defs", "model", "properties", "manifest_sha256", "const"
        ) == MODEL_MANIFEST_SHA256

    result_schema = report_schema.fetch("$defs").fetch("results")
    baseline_const = result_schema
      .fetch("properties")
      .fetch("baseline")
      .fetch("allOf")
      .fetch(1)
      .fetch("const")
    selected_const = result_schema
      .fetch("properties")
      .fetch("selected")
      .fetch("allOf")
      .fetch(1)
      .fetch("const")
    raise Failure, "report schema result constants differ" unless
      baseline_const == EXPECTED_RESULTS.fetch("baseline") &&
        selected_const == EXPECTED_RESULTS.fetch("selected")
    delta_properties = report_schema
      .fetch("$defs")
      .fetch("baselineDelta")
      .fetch("properties")
    schema_delta = EXPECTED_DELTA.to_h do |field, _value|
      [field, delta_properties.fetch(field).fetch("const")]
    end
    raise Failure, "report schema delta constants differ" unless
      schema_delta == EXPECTED_DELTA
    true
  rescue KeyError => error
    raise Failure, "P08 schema missing key #{error.key}"
  end

  def parse_schema(root, relative)
    parse_json(File.binread(File.join(root, relative)), relative)
  end

  def validate_closed_schema(schema, id, fields, emitted)
    raise Failure, "schema dialect differs: #{id}" unless
      schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    raise Failure, "schema ID differs: #{id}" unless schema["$id"] == id
    raise Failure, "schema is not a closed object: #{id}" unless
      schema["type"] == "object" && schema["additionalProperties"] == false
    raise Failure, "schema required fields differ: #{id}" unless
      schema.fetch("required").sort == fields.sort
    raise Failure, "schema property fields differ: #{id}" unless
      schema.fetch("properties").keys.sort == fields.sort
    raise Failure, "schema/emitted fields differ: #{id}" unless
      emitted.keys.sort == fields.sort
    true
  end

  def validate_dependencies(root)
    evaluator = File.binread(File.join(root, "crates/pos-eval/Cargo.toml"))
    expected_dependencies = {
      "lang-ptbr" => '{ path = "../lang-ptbr", optional = true }',
      "nlu-data" => '{ path = "../nlu-data" }',
      "serde" => "workspace = true",
      "serde_json" => "workspace = true"
    }
    raise Failure, "POS evaluator dependencies differ" unless
      dependency_entries(evaluator) == expected_dependencies
    sections = evaluator.lines.map do |line|
      match = line.strip.match(/\A\[(dependencies(?:\..+)?)\]\z/)
      match && match[1]
    end.compact
    raise Failure, "POS evaluator dependency section differs" unless
      sections == ["dependencies"]

    workspace = File.binread(File.join(root, "Cargo.toml"))
    raise Failure, "workspace POS evaluator membership differs" unless
      workspace.scan(%r{"crates/pos-eval"}).length == 1
    lang = dependency_entries(
      File.binread(File.join(root, "crates/lang-ptbr/Cargo.toml"))
    )
    data = dependency_entries(
      File.binread(File.join(root, "crates/nlu-data/Cargo.toml"))
    )
    raise Failure, "lang-ptbr/nlu-data dependency direction differs" unless
      lang.key?("nlu-data") && !data.key?("lang-ptbr")
    true
  end

  def dependency_entries(bytes)
    section = nil
    entries = {}
    bytes.lines.each do |line|
      stripped = line.sub(/#.*\z/, "").strip
      next if stripped.empty?
      if (match = stripped.match(/\A\[(.+)\]\z/))
        section = match[1]
        next
      end
      next unless section == "dependencies"

      match = stripped.match(/\A([A-Za-z0-9_-]+)(\.workspace)?\s*=\s*(.+)\z/)
      raise Failure, "unparseable dependency declaration" unless match
      raise Failure, "duplicate dependency declaration: #{match[1]}" if
        entries.key?(match[1])
      entries[match[1]] = if match[2]
                            "workspace = #{match[3]}"
                          else
                            match[3]
                          end
    end
    entries
  end

  def validate_production_isolation(root)
    manifests = PRODUCTION_CRATES.to_h do |crate|
      relative = "crates/#{crate}/Cargo.toml"
      [relative, File.binread(File.join(root, relative))]
    end
    manifests.each do |relative, bytes|
      raise Failure, "production crate depends on pos-eval: #{relative}" if
        dependency_entries(bytes).key?("pos-eval")
    end

    sources = {}
    PRODUCTION_CRATES.each do |crate|
      pattern = File.join(root, "crates", crate, "src", "**", "*.rs")
      Dir.glob(pattern).sort.each do |path|
        relative = path.delete_prefix("#{root}/")
        sources[relative] = File.binread(path)
      end
    end
    validate_production_bytes(
      manifests.merge(sources),
      EVALUATOR_LEAK_TOKENS,
      "P08 evaluator"
    )

    runtime = POS_RUNTIME_FILES.to_h do |relative|
      path = File.join(root, relative)
      raise Failure, "P08 runtime file missing: #{relative}" unless File.file?(path)
      [relative, File.binread(path)]
    end
    validate_pos_runtime_bytes(runtime)
    true
  end

  def validate_production_bytes(files, forbidden, context)
    files.each do |relative, bytes|
      lowered = bytes.downcase
      forbidden.each do |token|
        next unless lowered.include?(token.downcase)

        raise Failure, "production source leaks #{context} token #{token}: #{relative}"
      end
    end
    true
  end

  def validate_pos_runtime_bytes(files)
    validate_production_bytes(
      files,
      POS_RUNTIME_FORBIDDEN,
      "oracle/filesystem/network"
    )
  end

  def validate_requirements(root, require_satisfied:)
    traceability = File.binread(
      File.join(root, "docs/evidence/REQUIREMENTS-TRACEABILITY.md")
    )
    validate_requirement_rows(
      traceability,
      require_satisfied: require_satisfied
    )
  end

  def validate_requirement_rows(traceability, require_satisfied:)
    REQUIREMENTS.each do |id|
      row = traceability.lines.find { |line| line.start_with?("| `#{id}` |") }
      raise Failure, "requirement row missing: #{id}" unless row

      status = row.split("|")[-2]&.strip
      allowed = require_satisfied ? ["SATISFIED"] : %w[PENDING SATISFIED]
      raise Failure, "requirement status differs: #{id}" unless
        allowed.include?(status)
    end
    true
  end

  def run_split_rebuild(root)
    inputs = [
      "tools/compile-p08-pos-splits",
      "tools/compile-p08-pos-splits.rb",
      SOURCE_MANIFEST,
      CORPUS_MANIFEST,
      SPECIFICATION,
      GENERATOR,
      SOURCE_POS
    ]
    Dir.mktmpdir("p08-split-rebuild-") do |temporary|
      inputs.each { |relative| copy_relative(root, temporary, relative) }
      command = File.join(temporary, "tools/compile-p08-pos-splits")
      stdout, stderr, status = Open3.capture3(
        deterministic_environment(root),
        "/usr/bin/ruby",
        "--disable-gems",
        command,
        chdir: temporary
      )
      raise Failure, "P08 split compiler exited nonzero: #{stderr.strip}" unless
        status.success?
      raise Failure, "P08 split compiler wrote diagnostics: #{stderr.strip}" unless
        stderr.empty?
      raise Failure, "P08 split compiler output differs" unless
        stdout == "P08_POS_SPLITS_COMPILED\n"
      [TRAIN, DEVELOPMENT, HELDOUT, SPLIT_MANIFEST].each do |relative|
        rebuilt = File.binread(File.join(temporary, relative))
        tracked = File.binread(File.join(root, relative))
        raise Failure, "P08 split rebuild differs: #{relative}" unless
          rebuilt == tracked
      end
    end
    true
  end

  def run_training_reproduction(root)
    first = run_training_once(root)
    second = run_training_once(root)
    raise Failure, "P08 training summary is not deterministic" unless
      first.fetch("summary") == second.fetch("summary")
    %w[package manifest].each do |artifact|
      raise Failure, "P08 training is not byte-identical: #{artifact}" unless
        first.fetch(artifact) == second.fetch(artifact)
    end
    raise Failure, "P08 trained package differs from tracked artifact" unless
      first.fetch("package") == File.binread(File.join(root, MODEL_PACKAGE))
    raise Failure, "P08 trained manifest differs from tracked artifact" unless
      first.fetch("manifest") == File.binread(File.join(root, MODEL_MANIFEST))
    true
  end

  def run_training_once(root)
    Dir.mktmpdir("p08-training-root-") do |temporary|
      [SPLIT_MANIFEST, TRAIN].each do |relative|
        copy_relative(root, temporary, relative)
      end
      output = File.join(temporary, "output")
      tool_bin = File.join(root, ".tools/rust-1.98.0/bin")
      stdout, stderr, status = Open3.capture3(
        deterministic_environment(root),
        File.join(tool_bin, "cargo"),
        "run",
        "--quiet",
        "--locked",
        "-p",
        "pos-eval",
        "--bin",
        "pos-train",
        "--",
        "--root",
        temporary,
        "--split-manifest",
        SPLIT_MANIFEST,
        "--output",
        output,
        chdir: root
      )
      raise Failure, "P08 trainer exited nonzero: #{stderr.strip}" unless
        status.success?
      raise Failure, "P08 trainer wrote diagnostics: #{stderr.strip}" unless
        stderr.empty?
      summary = parse_json(stdout, "P08 training summary")
      validate_canonical_bytes(stdout, summary, "P08 training summary")
      expected_summary = {
        "algorithm_id" => ALGORITHM_ID,
        "compiler_id" => MODEL_COMPILER_ID,
        "config_id" => MODEL_CONFIG_ID,
        "manifest_bytes" => 1_617,
        "manifest_file" => "package-manifest.json",
        "manifest_sha256" => MODEL_MANIFEST_SHA256,
        "model_id" => MODEL_ID,
        "operation" => "train",
        "package_bytes" => 47,
        "package_file" => "package.bin",
        "package_sha256" => MODEL_PACKAGE_SHA256,
        "schema_version" => 1,
        "split_manifest_sha256" => SPLIT_MANIFEST_SHA256,
        "train_sha256" => TRAIN_SHA256
      }
      raise Failure, "P08 training summary differs" unless summary == expected_summary
      {
        "summary" => stdout,
        "package" => File.binread(File.join(output, "package.bin")),
        "manifest" => File.binread(File.join(output, "package-manifest.json"))
      }
    end
  end

  def run_evaluator_reproduction(root)
    expected = File.binread(File.join(root, EVALUATION_REPORT))
    first = run_evaluator_once(root)
    second = run_evaluator_once(root)
    raise Failure, "P08 evaluator is not byte-deterministic" unless first == second
    raise Failure, "P08 evaluator output differs from tracked report" unless
      first == expected
    true
  end

  def run_evaluator_once(root)
    inputs = [
      EVALUATION_MANIFEST,
      SPLIT_MANIFEST,
      HELDOUT,
      MODEL_PACKAGE,
      MODEL_MANIFEST
    ]
    Dir.mktmpdir("p08-evaluator-root-") do |temporary|
      inputs.each { |relative| copy_relative(root, temporary, relative) }
      tool_bin = File.join(root, ".tools/rust-1.98.0/bin")
      stdout, stderr, status = Open3.capture3(
        deterministic_environment(root),
        File.join(tool_bin, "cargo"),
        "run",
        "--quiet",
        "--locked",
        "-p",
        "pos-eval",
        "--features",
        "evaluator",
        "--bin",
        "pos-eval",
        "--",
        "--root",
        temporary,
        "--manifest",
        EVALUATION_MANIFEST,
        chdir: root
      )
      raise Failure, "P08 evaluator exited nonzero: #{stderr.strip}" unless
        status.success?
      raise Failure, "P08 evaluator wrote diagnostics: #{stderr.strip}" unless
        stderr.empty?
      stdout
    end
  end

  def copy_relative(source_root, destination_root, relative)
    source = File.join(source_root, relative)
    destination = File.join(destination_root, relative)
    FileUtils.mkdir_p(File.dirname(destination))
    FileUtils.cp(source, destination)
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
      "CARGO_TARGET_DIR" => File.join(root, "target/p08-gate"),
      "RUSTC" => File.join(tool_bin, "rustc"),
      "RUSTDOC" => File.join(tool_bin, "rustdoc")
    }
  end

  def run_cargo_tests(root)
    tool_bin = File.join(root, ".tools/rust-1.98.0/bin")
    output, status = Open3.capture2e(
      deterministic_environment(root),
      File.join(tool_bin, "cargo"),
      "test",
      "--locked",
      "-p",
      "nlu-data",
      "-p",
      "lang-ptbr",
      "-p",
      "pos-eval",
      "--all-features",
      chdir: root
    )
    return true if status.success?

    warn output
    raise Failure, "P08 Cargo tests failed"
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
end

P08Validation.run(ARGV) if $PROGRAM_NAME == __FILE__
