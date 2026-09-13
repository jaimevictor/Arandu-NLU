# frozen_string_literal: true

require "digest"
require "json"
require "open3"

module P07Validation
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
  MORPHOLOGY_ARTIFACT = "data/project-authored/p02-v1/morphology.jsonl"
  P06_PACKAGE = "data/lexicon/p06/package.bin"
  EVALUATION_MANIFEST = "data/evaluation/p07/morphology-v1/manifest.json"
  EVALUATION_REPORT = "data/evaluation/p07/morphology-v1/report.json"
  MANIFEST_SCHEMA = "schemas/morphology-evaluation-manifest-v1.schema.json"
  REPORT_SCHEMA = "schemas/morphology-evaluation-report-v1.schema.json"

  SOURCE_MANIFEST_SHA256 =
    "d9e1ca32ec0f92aa6b5fc6c1d4f232f93389e0bf8031267d23daddf7287006c5"
  MORPHOLOGY_ARTIFACT_SHA256 =
    "ebee221611e4cbf6206a755022d163e4c96f7eb1a42626d7032773bfb8c793dc"
  P06_PACKAGE_SHA256 =
    "ec24f2335f64d694931450fb5ad6aefe3e924d1e29b23e046f128491dfe79e27"
  EVALUATION_MANIFEST_SHA256 =
    "2a3ff2ffa947749010c735b1f45af31a9d2a477cdfefa7ed8f7cafabb288a0b7"
  EVALUATION_REPORT_SHA256 =
    "a383b8002b3125a048594f3c836835f3484e7b994da79bbf96756aa1340774d4"
  MANIFEST_SCHEMA_SHA256 =
    "13d7c5bb18d282b058ec6c0a8a459ea92ef135cdb78f8b5dde08cfb52e949161"
  REPORT_SCHEMA_SHA256 =
    "3e74f61aaf3fe6f7a44d7c41a77e3924253776c91ffad0858d89780f9cdfa8f4"
  CASE_IDS_SHA256 =
    "6e481a12ebd00c62635e0fc13381993f96256987fe37ee67f66efdac8b1131bf"

  ARTIFACTS = {
    SOURCE_MANIFEST => [6_204, SOURCE_MANIFEST_SHA256],
    MORPHOLOGY_ARTIFACT => [9_468, MORPHOLOGY_ARTIFACT_SHA256],
    P06_PACKAGE => [65_886, P06_PACKAGE_SHA256],
    EVALUATION_MANIFEST => [1_256, EVALUATION_MANIFEST_SHA256],
    EVALUATION_REPORT => [4_846, EVALUATION_REPORT_SHA256],
    MANIFEST_SCHEMA => [2_526, MANIFEST_SCHEMA_SHA256],
    REPORT_SCHEMA => [9_111, REPORT_SCHEMA_SHA256]
  }.freeze

  DATASET_ID = "p07-morphology-internal-conformance"
  DATASET_VERSION = "1.0.0"
  SPLIT_ID = "p07-morphology-internal-conformance-v1"
  CLAIM_SCOPE = "internal_conformance_only"
  DOMAIN = "morphology"
  LOCALE = "pt-BR"
  GROUPING = "exact-surface-analysis-set-v1"
  METRIC_SPEC = "exact-morphology-set-metrics-v1"
  RUNNER_ID = "morphology-eval-v1"
  ANALYZER_ID = "lang-ptbr-lexical-evidence-morphology-v1"
  CONFUSION_LABELS = %w[unknown unique ambiguous].freeze
  ERROR_TAXONOMY = %w[
    missing_analysis
    unexpected_analysis
    cardinality_mismatch
  ].freeze
  LIMITATIONS = %w[
    project_authored_labels_share_generator_with_runtime_lexicon
    feature_bearing_source_analyses_only
    four_featureless_lexicon_analyses_unscored
    no_expected_unknown_surfaces
    internal_conformance_not_independent_accuracy_or_generalization
  ].freeze
  CONTEXT = {
    "domain" => DOMAIN,
    "dataset_id" => DATASET_ID,
    "dataset_version" => DATASET_VERSION,
    "split_id" => SPLIT_ID,
    "claim_scope" => CLAIM_SCOPE,
    "limitations" => LIMITATIONS
  }.freeze

  MANIFEST_FIELDS = %w[
    schema_version dataset_id dataset_version split_id claim_scope locale
    source_id source_manifest_sha256 artifact_path artifact_sha256
    artifact_records surface_count analysis_count case_ids_sha256 grouping
    metric_spec confusion_labels error_taxonomy runner_id
    runtime_package_sha256 limitations
  ].freeze
  REPORT_FIELDS = %w[
    schema_version domain runner_id analyzer_id dataset_id dataset_version
    split_id claim_scope locale source_id source_manifest_sha256
    manifest_sha256 artifact_sha256 case_ids_sha256 runtime_package_sha256
    grouping metric_spec limitations metrics error_analysis
  ].freeze
  METRIC_FIELDS = %w[
    exact_surface_sets analysis_counts analysis_precision analysis_recall
    ambiguity_preservation confusion_matrix
  ].freeze
  ROW_FIELDS = %w[
    schema_version case_id source_id corpus_version generator_id license locale
    surface expected_analyses
  ].freeze
  ANALYSIS_FIELDS = %w[lemma pos features].freeze
  POS_LABELS = %w[ADJ ADP ADV CCONJ DET NOUN VERB].freeze
  REQUIREMENTS = (1..8).map { |number| format("P07-MOR-%03d", number) }.freeze
  PRODUCTION_CRATES = %w[lang-ptbr nlu-core nlu-data protocol].freeze

  EXPECTED_MANIFEST = {
    "schema_version" => 1,
    "dataset_id" => DATASET_ID,
    "dataset_version" => DATASET_VERSION,
    "split_id" => SPLIT_ID,
    "claim_scope" => CLAIM_SCOPE,
    "locale" => LOCALE,
    "source_id" => SOURCE_ID,
    "source_manifest_sha256" => SOURCE_MANIFEST_SHA256,
    "artifact_path" => MORPHOLOGY_ARTIFACT,
    "artifact_sha256" => MORPHOLOGY_ARTIFACT_SHA256,
    "artifact_records" => 29,
    "surface_count" => 28,
    "analysis_count" => 29,
    "case_ids_sha256" => CASE_IDS_SHA256,
    "grouping" => GROUPING,
    "metric_spec" => METRIC_SPEC,
    "confusion_labels" => CONFUSION_LABELS,
    "error_taxonomy" => ERROR_TAXONOMY,
    "runner_id" => RUNNER_ID,
    "runtime_package_sha256" => P06_PACKAGE_SHA256,
    "limitations" => LIMITATIONS
  }.freeze
  EXPECTED_REPORT_SCALARS = {
    "schema_version" => 1,
    "domain" => DOMAIN,
    "runner_id" => RUNNER_ID,
    "analyzer_id" => ANALYZER_ID,
    "dataset_id" => DATASET_ID,
    "dataset_version" => DATASET_VERSION,
    "split_id" => SPLIT_ID,
    "claim_scope" => CLAIM_SCOPE,
    "locale" => LOCALE,
    "source_id" => SOURCE_ID,
    "source_manifest_sha256" => SOURCE_MANIFEST_SHA256,
    "manifest_sha256" => EVALUATION_MANIFEST_SHA256,
    "artifact_sha256" => MORPHOLOGY_ARTIFACT_SHA256,
    "case_ids_sha256" => CASE_IDS_SHA256,
    "runtime_package_sha256" => P06_PACKAGE_SHA256,
    "grouping" => GROUPING,
    "metric_spec" => METRIC_SPEC
  }.freeze

  FORBIDDEN_PRODUCTION_TOKENS = [
    "morphology-eval",
    "morphology_eval",
    "morphology.jsonl",
    "data/evaluation/p07",
    "morphology-evaluation-manifest",
    "morphology-evaluation-report",
    DATASET_ID,
    SPLIT_ID,
    "p02-morphology-",
    "expected_analyses",
    "case_ids_sha256",
    METRIC_SPEC,
    "missing_analysis",
    "unexpected_analysis",
    "cardinality_mismatch",
    EVALUATION_MANIFEST_SHA256,
    EVALUATION_REPORT_SHA256,
    MORPHOLOGY_ARTIFACT_SHA256,
    CASE_IDS_SHA256
  ].freeze

  module_function

  def run(arguments)
    arguments = arguments.dup
    no_cargo = arguments.delete("--no-cargo")
    no_evaluator = arguments.delete("--no-evaluator")
    review_candidate = arguments.delete("--review-candidate")
    unless arguments.empty?
      raise Failure,
            "usage: tools/validate-p07 [--no-cargo] [--no-evaluator] " \
            "[--review-candidate]"
    end

    validate(
      ROOT,
      run_cargo: !no_cargo && !review_candidate,
      require_satisfied: !review_candidate,
      run_evaluator: !no_cargo && !no_evaluator && !review_candidate
    )
    puts(review_candidate ? "P07_REVIEW_CANDIDATE_PASS" : "P07_GATE_PASS")
  rescue Failure => error
    warn "P07_GATE_FAIL: #{error.message}"
    exit 1
  end

  def validate(root, run_cargo:, require_satisfied:, run_evaluator: true)
    validate_artifacts(root)
    validate_source_manifest(root)
    rows = morphology_rows(File.binread(File.join(root, MORPHOLOGY_ARTIFACT)))
    manifest_bytes = File.binread(File.join(root, EVALUATION_MANIFEST))
    manifest = parse_json(manifest_bytes, "P07 evaluation manifest")
    validate_manifest(manifest)
    validate_canonical_bytes(
      manifest_bytes,
      manifest,
      EVALUATION_MANIFEST,
      EVALUATION_MANIFEST_SHA256
    )
    report_bytes = File.binread(File.join(root, EVALUATION_REPORT))
    report = parse_json(report_bytes, "P07 evaluation report")
    validate_report(report, manifest)
    validate_report_bytes(report_bytes, report)
    validate_schemas(root, manifest, report)
    validate_dependencies(root)
    validate_production_isolation(root)
    validate_requirements(root, require_satisfied: require_satisfied)
    run_evaluator(root, report_bytes) if run_evaluator
    run_cargo_tests(root) if run_cargo
    rows
  end

  def validate_artifacts(root)
    ARTIFACTS.each do |relative, _identity|
      path = File.join(root, relative)
      raise Failure, "artifact is a symlink: #{relative}" if File.symlink?(path)
      raise Failure, "artifact is not a regular file: #{relative}" unless File.file?(path)

      validate_artifact_bytes(relative, File.binread(path))
    end
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

  def validate_source_manifest(root)
    manifest = parse_json(
      File.binread(File.join(root, SOURCE_MANIFEST)),
      "P07 source manifest"
    )
    source = manifest.fetch("source")
    expected_source = {
      "id" => SOURCE_ID,
      "admission_status" => "PROJECT_AUTHORED_SYNTHETIC",
      "authorization" => "USR-016",
      "claim_scope" => CLAIM_SCOPE,
      "immutable_version" => DATASET_VERSION,
      "license" => "Apache-2.0"
    }
    expected_source.each do |field, expected|
      raise Failure, "source manifest #{field} differs" unless
        source[field] == expected
    end
    descriptors = manifest.fetch("artifacts").to_h do |artifact|
      [artifact.fetch("path"), artifact]
    end
    morphology = descriptors.fetch(MORPHOLOGY_ARTIFACT)
    expected_descriptor = {
      "path" => MORPHOLOGY_ARTIFACT,
      "role" => "morphology",
      "content_type" => "application/x-ndjson",
      "bytes" => 9_468,
      "sha256" => MORPHOLOGY_ARTIFACT_SHA256,
      "records" => 29
    }
    raise Failure, "source morphology descriptor differs" unless
      morphology == expected_descriptor
  rescue KeyError => error
    raise Failure, "source manifest missing key #{error.key}"
  end

  def morphology_rows(bytes)
    raise Failure, "morphology artifact exceeds byte limit" if bytes.bytesize > 1_048_576
    raise Failure, "morphology artifact lacks final newline" unless bytes.end_with?("\n")

    lines = bytes.lines(chomp: true)
    raise Failure, "morphology row count exceeds limit" if lines.length > 20_000

    rows = []
    case_ids = {}
    tuples = {}
    analysis_count = 0
    lines.each_with_index do |line, index|
      raise Failure, "empty morphology row" if line.empty?
      raise Failure, "morphology row exceeds byte limit" if line.bytesize > 262_144

      row = parse_json(line, "morphology row #{index + 1}")
      raise Failure, "morphology row fields differ" unless
        row.keys.sort == ROW_FIELDS.sort
      expected_lineage = {
        "schema_version" => 1,
        "source_id" => SOURCE_ID,
        "corpus_version" => DATASET_VERSION,
        "generator_id" => "p02-generator-v1",
        "license" => "Apache-2.0",
        "locale" => LOCALE
      }
      expected_lineage.each do |field, expected|
        raise Failure, "morphology row lineage differs: #{field}" unless
          row[field] == expected
      end
      raise Failure, "technical fixture entered morphology artifact" if
        JSON.generate(row).include?("FIXTURE_TECNICA")

      case_id = row.fetch("case_id")
      surface = row.fetch("surface")
      analyses = row.fetch("expected_analyses")
      raise Failure, "invalid morphology case ID" unless
        case_id.is_a?(String) && case_id.match?(/\A[A-Za-z0-9._:-]{1,256}\z/)
      raise Failure, "duplicate morphology case ID" if case_ids.key?(case_id)
      raise Failure, "invalid morphology surface" unless
        surface.is_a?(String) && !surface.empty?
      raise Failure, "invalid expected analysis list" unless
        analyses.is_a?(Array) && !analyses.empty? && analyses.length <= 32

      case_ids[case_id] = true
      analyses.each do |analysis|
        validate_canonical_analysis(analysis, "expected morphology analysis")
        key = [surface, canonical_json(analysis)]
        raise Failure, "duplicate expected morphology tuple" if tuples.key?(key)

        tuples[key] = true
        analysis_count += 1
      end
      rows << row
    end
    surfaces = rows.map { |row| row.fetch("surface") }.uniq
    raise Failure, "morphology row inventory differs" unless
      rows.length == 29 &&
        case_ids.length == 29 &&
        surfaces.length == 28 &&
        analysis_count == 29
    raise Failure, "morphology case ID hash differs" unless
      Digest::SHA256.hexdigest(canonical_json(case_ids.keys.sort)) == CASE_IDS_SHA256

    rows
  rescue KeyError => error
    raise Failure, "morphology row missing key #{error.key}"
  end

  def validate_manifest(manifest)
    raise Failure, "evaluation manifest fields differ" unless
      manifest.keys.sort == MANIFEST_FIELDS.sort
    raise Failure, "evaluation manifest contract differs" unless
      manifest == EXPECTED_MANIFEST

    true
  end

  def validate_report(report, manifest)
    raise Failure, "evaluation report fields differ" unless
      report.keys.sort == REPORT_FIELDS.sort
    EXPECTED_REPORT_SCALARS.each do |field, expected|
      raise Failure, "evaluation report #{field} differs" unless
        report[field] == expected
    end
    raise Failure, "evaluation report limitations differ" unless
      report["limitations"] == LIMITATIONS
    %w[
      dataset_id dataset_version split_id claim_scope source_id
      source_manifest_sha256 artifact_sha256 case_ids_sha256 grouping
      metric_spec runner_id runtime_package_sha256
    ].each do |field|
      raise Failure, "report/manifest linkage differs: #{field}" unless
        report[field] == manifest[field]
    end

    metrics = report.fetch("metrics")
    raise Failure, "metric inventory differs" unless
      metrics.is_a?(Hash) && metrics.keys.sort == METRIC_FIELDS.sort
    validate_fraction(metrics.fetch("exact_surface_sets"), 28, 28, "exact surface sets")
    validate_counts(metrics.fetch("analysis_counts"), 29, 0, 0)
    validate_fraction(metrics.fetch("analysis_precision"), 29, 29, "analysis precision")
    validate_fraction(metrics.fetch("analysis_recall"), 29, 29, "analysis recall")
    validate_fraction(metrics.fetch("ambiguity_preservation"), 1, 1, "ambiguity preservation")
    validate_confusion_matrix(metrics.fetch("confusion_matrix"))

    error_analysis = report.fetch("error_analysis")
    validate_metric_context(
      error_analysis,
      %w[taxonomy errors],
      "error analysis"
    )
    raise Failure, "error taxonomy differs" unless
      error_analysis["taxonomy"] == ERROR_TAXONOMY
    validate_error_records(error_analysis.fetch("errors"))
    raise Failure, "baseline error analysis is not empty" unless
      error_analysis["errors"].empty?
    reject_floats(report, "evaluation report")
    true
  rescue KeyError => error
    raise Failure, "evaluation report missing key #{error.key}"
  end

  def validate_report_bytes(bytes, report)
    validate_canonical_bytes(
      bytes,
      report,
      EVALUATION_REPORT,
      EVALUATION_REPORT_SHA256
    )
  end

  def validate_canonical_bytes(bytes, value, context, expected_sha256)
    raise Failure, "#{context} hash differs" unless
      Digest::SHA256.hexdigest(bytes) == expected_sha256
    raise Failure, "#{context} is not canonical with one final newline" unless
      bytes == canonical_json(value) + "\n"

    true
  end

  def validate_fraction(metric, numerator, denominator, name)
    validate_metric_context(metric, %w[numerator denominator], name)
    raise Failure, "#{name} fraction differs" unless
      metric["numerator"] == numerator && metric["denominator"] == denominator
  end

  def validate_counts(metric, true_positive, false_positive, false_negative)
    validate_metric_context(
      metric,
      %w[true_positive false_positive false_negative],
      "analysis counts"
    )
    expected = {
      "true_positive" => true_positive,
      "false_positive" => false_positive,
      "false_negative" => false_negative
    }
    expected.each do |field, value|
      raise Failure, "analysis counts #{field} differs" unless metric[field] == value
    end
  end

  def validate_confusion_matrix(metric)
    validate_metric_context(metric, %w[labels matrix], "confusion matrix")
    raise Failure, "confusion labels differ" unless
      metric["labels"] == CONFUSION_LABELS
    raise Failure, "confusion matrix differs" unless
      metric["matrix"] == [[0, 0, 0], [0, 27, 0], [0, 0, 1]]
  end

  def validate_metric_context(metric, value_fields, name)
    raise Failure, "#{name} is not an object" unless metric.is_a?(Hash)
    expected_fields = CONTEXT.keys + value_fields
    raise Failure, "#{name} fields differ" unless
      metric.keys.sort == expected_fields.sort
    CONTEXT.each do |field, expected|
      raise Failure, "#{name} context differs: #{field}" unless
        metric[field] == expected
    end
  end

  def validate_error_records(errors)
    raise Failure, "error records are not an array" unless errors.is_a?(Array)

    errors.each do |issue|
      raise Failure, "error record is not an object" unless issue.is_a?(Hash)
      type = issue["error_type"]
      raise Failure, "unknown error taxonomy member" unless ERROR_TAXONOMY.include?(type)
      common = %w[error_type surface case_ids]
      specific = case type
                 when "missing_analysis"
                   %w[expected_analysis]
                 when "unexpected_analysis"
                   %w[observed_analysis]
                 when "cardinality_mismatch"
                   %w[expected observed]
                 end
      raise Failure, "error record fields differ: #{type}" unless
        issue.keys.sort == (common + specific).sort
      raise Failure, "invalid error surface" unless
        issue["surface"].is_a?(String) && !issue["surface"].empty?
      validate_case_ids(issue["case_ids"])
      case type
      when "missing_analysis"
        validate_canonical_analysis(issue["expected_analysis"], type)
      when "unexpected_analysis"
        validate_canonical_analysis(issue["observed_analysis"], type)
      when "cardinality_mismatch"
        expected = issue["expected"]
        observed = issue["observed"]
        raise Failure, "invalid cardinality mismatch" unless
          expected.is_a?(Integer) && expected >= 0 &&
            observed.is_a?(Integer) && observed >= 0 &&
            expected != observed
      end
    end
    serialized = errors.map { |issue| canonical_json(issue) }
    raise Failure, "duplicate error record" unless serialized.uniq.length == serialized.length
    expected_order = errors.sort_by { |issue| error_sort_key(issue) }
    raise Failure, "error records are not canonically ordered" unless
      errors == expected_order

    true
  end

  def validate_case_ids(case_ids)
    raise Failure, "invalid error case IDs" unless
      case_ids.is_a?(Array) && !case_ids.empty? &&
        case_ids.all? do |case_id|
          case_id.is_a?(String) &&
            case_id.match?(/\A[A-Za-z0-9._:-]{1,256}\z/)
        end &&
        case_ids == case_ids.sort &&
        case_ids.uniq.length == case_ids.length
  end

  def validate_canonical_analysis(analysis, context)
    raise Failure, "#{context} is not an object" unless analysis.is_a?(Hash)
    raise Failure, "#{context} fields differ" unless
      analysis.keys.sort == ANALYSIS_FIELDS.sort
    raise Failure, "#{context} lemma differs" unless
      analysis["lemma"].is_a?(String) && !analysis["lemma"].empty?
    raise Failure, "#{context} POS differs" unless
      POS_LABELS.include?(analysis["pos"])
    features = analysis["features"]
    raise Failure, "#{context} features differ" unless
      features.is_a?(Array) &&
        features.all? { |feature| feature.is_a?(String) && !feature.empty? } &&
        features == features.sort &&
        features.uniq.length == features.length

    true
  end

  def error_sort_key(issue)
    detail = case issue.fetch("error_type")
             when "missing_analysis"
               analysis_sort_key(issue.fetch("expected_analysis"))
             when "unexpected_analysis"
               analysis_sort_key(issue.fetch("observed_analysis"))
             when "cardinality_mismatch"
               [issue.fetch("expected"), issue.fetch("observed")]
             end
    [
      issue.fetch("surface"),
      ERROR_TAXONOMY.index(issue.fetch("error_type")),
      detail,
      issue.fetch("case_ids")
    ]
  end

  def analysis_sort_key(analysis)
    [
      analysis.fetch("lemma"),
      analysis.fetch("pos"),
      analysis.fetch("features")
    ]
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

  def validate_schemas(root, manifest, report)
    manifest_schema = parse_json(
      File.binread(File.join(root, MANIFEST_SCHEMA)),
      MANIFEST_SCHEMA
    )
    report_schema = parse_json(
      File.binread(File.join(root, REPORT_SCHEMA)),
      REPORT_SCHEMA
    )
    validate_closed_schema(
      manifest_schema,
      "https://nlu.local/schemas/morphology-evaluation-manifest-v1.schema.json",
      MANIFEST_FIELDS,
      manifest
    )
    properties = manifest_schema.fetch("properties")
    EXPECTED_MANIFEST.each do |field, expected|
      raise Failure, "manifest schema constant differs: #{field}" unless
        properties.fetch(field).fetch("const") == expected
    end

    validate_closed_schema(
      report_schema,
      "https://nlu.local/schemas/morphology-evaluation-report-v1.schema.json",
      REPORT_FIELDS,
      report
    )
    definitions = report_schema.fetch("$defs")
    raise Failure, "report schema limitations differ" unless
      definitions.fetch("limitations").fetch("const") == LIMITATIONS
    raise Failure, "report schema metric inventory differs" unless
      definitions.fetch("metrics").fetch("required").sort == METRIC_FIELDS.sort
    issue_types = definitions.fetch("issue").fetch("oneOf").map do |issue|
      issue.fetch("properties").fetch("error_type").fetch("const")
    end
    raise Failure, "report schema error taxonomy differs" unless
      issue_types == ERROR_TAXONOMY
    true
  rescue KeyError => error
    raise Failure, "evaluation schema missing key #{error.key}"
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
  end

  def validate_dependencies(root)
    evaluator = File.binread(
      File.join(root, "crates/morphology-eval/Cargo.toml")
    )
    expected_dependencies = {
      "lang-ptbr" => '{ path = "../lang-ptbr" }',
      "nlu-data" => '{ path = "../nlu-data" }',
      "serde" => "workspace = true",
      "serde_json" => "workspace = true"
    }
    raise Failure, "evaluator dependencies differ" unless
      dependency_entries(evaluator) == expected_dependencies
    dependency_sections = evaluator.lines.map do |line|
      match = line.strip.match(/\A\[(dependencies(?:\..+)?)\]\z/)
      match && match[1]
    end.compact
    raise Failure, "evaluator has noncanonical dependency section" unless
      dependency_sections == ["dependencies"]

    workspace = File.binread(File.join(root, "Cargo.toml"))
    raise Failure, "workspace evaluator membership differs" unless
      workspace.scan(%r{"crates/morphology-eval"}).length == 1
    lang_manifest = File.binread(File.join(root, "crates/lang-ptbr/Cargo.toml"))
    raise Failure, "lang-ptbr does not depend on nlu-data" unless
      dependency_entries(lang_manifest).key?("nlu-data")
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
      raise Failure, "unparseable dependency declaration" if match.nil?
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
    validate_production_bytes(manifests, "Cargo manifest")
    manifests.each do |relative, bytes|
      raise Failure, "production manifest depends on evaluator: #{relative}" if
        dependency_entries(bytes).key?("morphology-eval")
    end

    sources = {}
    PRODUCTION_CRATES.each do |crate|
      pattern = File.join(root, "crates", crate, "src", "**", "*.rs")
      Dir.glob(pattern).sort.each do |path|
        relative = path.delete_prefix("#{root}/")
        sources[relative] = File.binread(path)
      end
    end
    validate_production_bytes(sources, "Rust source")
    true
  end

  def validate_production_bytes(files, kind)
    files.each do |relative, bytes|
      lowered = bytes.downcase
      FORBIDDEN_PRODUCTION_TOKENS.each do |token|
        next unless lowered.include?(token.downcase)

        raise Failure, "production #{kind} leaks #{token}: #{relative}"
      end
    end
    true
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
      raise Failure, "requirement row missing: #{id}" if row.nil?

      status = row.split("|")[-2]&.strip
      allowed = require_satisfied ? ["SATISFIED"] : %w[PENDING SATISFIED]
      raise Failure, "requirement status differs: #{id}" unless allowed.include?(status)
    end
    true
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

  def tool_environment(root)
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
      "CARGO_TARGET_DIR" => File.join(root, "target/p07-gate"),
      "RUSTC" => File.join(tool_bin, "rustc"),
      "RUSTDOC" => File.join(tool_bin, "rustdoc")
    }
  end

  def run_evaluator(root, expected_report)
    tool_bin = File.join(root, ".tools/rust-1.98.0/bin")
    stdout, stderr, status = Open3.capture3(
      tool_environment(root),
      File.join(tool_bin, "cargo"),
      "run",
      "--quiet",
      "--locked",
      "-p",
      "morphology-eval",
      "--",
      "--root",
      root,
      "--manifest",
      EVALUATION_MANIFEST,
      chdir: root
    )
    raise Failure, "P07 evaluator exited nonzero: #{stderr.strip}" unless status.success?
    raise Failure, "P07 evaluator wrote diagnostics: #{stderr.strip}" unless stderr.empty?
    raise Failure, "P07 evaluator output differs from tracked report" unless
      stdout.b == expected_report

    true
  end

  def run_cargo_tests(root)
    tool_bin = File.join(root, ".tools/rust-1.98.0/bin")
    output, status = Open3.capture2e(
      tool_environment(root),
      File.join(tool_bin, "cargo"),
      "test",
      "--locked",
      "-p",
      "lang-ptbr",
      "-p",
      "morphology-eval",
      "--all-features",
      chdir: root
    )
    return if status.success?

    warn output
    raise Failure, "P07 Cargo tests failed"
  end
end

P07Validation.run(ARGV) if $PROGRAM_NAME == __FILE__
