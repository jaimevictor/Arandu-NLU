# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

module P09Validation
  class Failure < StandardError; end
  class DuplicateKey < StandardError; end

  class DuplicateRejectingHash < Hash
    def []=(key, value)
      raise DuplicateKey, key if key?(key)

      super
    end
  end

  ROOT = File.expand_path("..", __dir__)
  SCHEMA_SOURCE = "data/intents/p09/schema-source.json"
  PACKAGE = "data/intents/p09/package.bin"
  PACKAGE_MANIFEST = "data/intents/p09/package-manifest.json"
  PROJECTION = "data/evaluation/p09/intent-v1/projection.json"
  REPORT = "data/evaluation/p09/intent-v1/report.json"
  TRAIN = "data/project-authored/p02-v1/train.jsonl"
  DEVELOPMENT = "data/project-authored/p02-v1/development.jsonl"
  SPECIFICATION = "data/project-authored/p02-v1/specification.yaml"
  GENERATOR = "tools/generate-p02-corpus.rb"
  SCHEMAS = {
    "schemas/intent-schema-v1.schema.json" =>
      "https://local.invalid/schemas/intent-schema-v1.schema.json",
    "schemas/intent-projection-v1.schema.json" =>
      "https://local.invalid/schemas/intent-projection-v1.schema.json",
    "schemas/intent-output-v1.schema.json" =>
      "https://local.invalid/schemas/intent-output-v1.schema.json",
    "schemas/intent-evaluation-report-v1.schema.json" =>
      "https://local.invalid/schemas/intent-evaluation-report-v1.schema.json"
  }.freeze

  SCHEMA_SHA256 =
    "be9fc531981b5581cbbe4577cd5b1e6194bd98470f84c13781b221472dfd54f9"
  PACKAGE_SHA256 =
    "56140cfa9d93377145aac132a174ed79262e9f454b6e991118477e3ad54bddda"
  PACKAGE_MANIFEST_SHA256 =
    "cdef4653c0edc5d819fc52ec0c03976f6df66d0036dff9828b410f699f44ffc3"
  PROJECTION_SHA256 =
    "5f661bb96b85667a1d0c9ec4d85cb61c443e1b24ab4dfc6c1ab849c6df936ee4"
  REPORT_SHA256 =
    "cf3b150f9f415a111cda5e874b57254f0637dee938150ceca8d88c1ea0988ad0"
  TRAIN_SHA256 =
    "23d2bc8c8fcde80d1a9560d42219484bc34e9198c791ccadf5d4b56413a81b64"
  DEVELOPMENT_SHA256 =
    "75400570ddfc7196ed982da98dcf49c4e6bda5820200a2fefd93a8ea6f049161"
  SPECIFICATION_SHA256 =
    "f72451f03d1a5e2e4955b5d2857bd7d33b3b012912d920e53a3d85719f14859d"
  GENERATOR_SHA256 =
    "ff8817afc2c2f13d539ab7d10720cab407d769ca3a6189dcc55d43ea052689d1"

  ARTIFACTS = {
    SCHEMA_SOURCE => [15_298, SCHEMA_SHA256],
    PACKAGE => [9_621, PACKAGE_SHA256],
    PACKAGE_MANIFEST => [1_239, PACKAGE_MANIFEST_SHA256],
    PROJECTION => [8_275, PROJECTION_SHA256],
    REPORT => [9_898, REPORT_SHA256],
    "schemas/intent-schema-v1.schema.json" => [
      1_493,
      "c24749f59fd8526fbbcf85cb1427057bd85fc0ac06161025f88046c55f99825c"
    ],
    "schemas/intent-projection-v1.schema.json" => [
      1_361,
      "51cbbbb36b087e0d1c1d701fdf0596fee9ef7e013b1673e8b828d95d2277afa1"
    ],
    "schemas/intent-output-v1.schema.json" => [
      2_937,
      "cb573782752d9896bf59e90a5e578553fc62de76609e9e7270d641b7fddba375"
    ],
    "schemas/intent-evaluation-report-v1.schema.json" => [
      7_356,
      "fef3a8e059fa6a6669afa35ab66719935d0a97c26208783f4fb7a2776d22a3cb"
    ]
  }.freeze

  SOURCE_ID = "project-authored-synthetic-ptbr-v1"
  CORPUS_VERSION = "1.0.0"
  GENERATOR_ID = "p02-generator-v1"
  SCHEMA_ID = "p09-intent-schema-v1"
  ALGORITHM_ID = "p09-weighted-marker-slot-extraction-v1"
  CONFIGURATION_ID = "p09-intent-config-v1"
  COMPILER_ID = "nlu-data-intent-compiler-v1"
  PROJECTION_ID = "p09-pre-resolution-oracle-projection-v1"
  DATASET_ID = "p09-intent-internal-conformance"
  METRIC_SPEC = "exact-pre-resolution-intent-and-slot-aggregate-v1"
  PREDICTION_DIGEST =
    "ce39fe046d96fec54a28cdb32e1446ccb9805ee9343e3c0c7c849c2c8850c10c"
  REQUIREMENTS = (
    (1..10).map { |number| format("P09-INT-%03d", number) } +
    (1..2).map { |number| format("P09-EVAL-%03d", number) }
  ).freeze
  EXACT_DEVELOPMENT_INTENTS = %w[
    ha:hass_broadcast
    ha:hass_cancel_timer
    ha:hass_climate_get_temperature
    ha:hass_get_current_date
    ha:hass_pause_timer
    ha:hass_set_position
    ha:hass_turn_off
    ha:hass_turn_on
  ].freeze
  LIMITATIONS = %w[
    project_authored_templates_share_source_with_runtime_markers
    single_source_templatic_internal_conformance_not_independent_accuracy
    development_results_do_not_authorize_runtime_rule_changes
    heldout_not_accessed
    entity_resolution_and_plan_graph_exactness_out_of_scope
  ].freeze

  module_function

  def run(arguments)
    arguments = arguments.dup
    no_cargo = arguments.delete("--no-cargo")
    no_reproduction = arguments.delete("--no-reproduction")
    review_candidate = arguments.delete("--review-candidate")
    unless arguments.empty?
      raise Failure,
            "usage: tools/validate-p09 [--no-cargo] [--no-reproduction] " \
            "[--review-candidate]"
    end

    validate(
      ROOT,
      run_cargo: !no_cargo && !review_candidate,
      require_satisfied: !review_candidate,
      run_reproduction: !no_cargo && !no_reproduction && !review_candidate
    )
    puts(review_candidate ? "P09_REVIEW_CANDIDATE_PASS" : "P09_GATE_PASS")
  rescue Failure => error
    warn "P09_GATE_FAIL: #{error.message}"
    exit 1
  end

  def validate(root, run_cargo:, require_satisfied:, run_reproduction: true)
    validate_artifacts(root)
    validate_source_inputs(root)

    schema = parse_json(
      File.binread(File.join(root, SCHEMA_SOURCE)),
      SCHEMA_SOURCE
    )
    validate_schema(schema)
    package_schema = parse_package(File.binread(File.join(root, PACKAGE)))
    raise Failure, "package schema differs from canonical source" unless
      package_schema == canonical_schema(schema)
    manifest = read_canonical_json(root, PACKAGE_MANIFEST)
    validate_manifest(manifest, package_schema)

    train_rows = parse_jsonl(File.binread(File.join(root, TRAIN)), "train")
    validate_train_markers(schema, train_rows)
    projection = parse_json(
      File.binread(File.join(root, PROJECTION)),
      PROJECTION
    )
    validate_projection(projection, schema)
    report = read_canonical_json(root, REPORT)
    validate_report(report, projection)
    validate_schemas(root, report)
    validate_dependencies(root)
    validate_production_isolation(root)
    validate_requirements(root, require_satisfied: require_satisfied)

    run_reproductions(root) if run_reproduction
    run_cargo_tests(root) if run_cargo
    true
  end

  def validate_artifacts(root)
    ARTIFACTS.each do |relative, (expected_bytes, expected_hash)|
      path = File.join(root, relative)
      raise Failure, "artifact is a symlink: #{relative}" if File.symlink?(path)
      raise Failure, "artifact is not a regular file: #{relative}" unless File.file?(path)

      bytes = File.binread(path)
      validate_artifact_bytes(
        relative,
        bytes,
        expected_bytes: expected_bytes,
        expected_hash: expected_hash
      )
    end
    true
  end

  def validate_artifact_bytes(relative, bytes, expected_bytes: nil, expected_hash: nil)
    expected_bytes, expected_hash = ARTIFACTS.fetch(relative) unless
      expected_bytes && expected_hash
    raise Failure, "artifact byte count differs: #{relative}" unless
      bytes.bytesize == expected_bytes
    raise Failure, "artifact hash differs: #{relative}" unless
      Digest::SHA256.hexdigest(bytes) == expected_hash

    true
  rescue KeyError
    raise Failure, "unrecognized pinned artifact: #{relative}"
  end

  def validate_source_inputs(root)
    {
      TRAIN => TRAIN_SHA256,
      DEVELOPMENT => DEVELOPMENT_SHA256,
      SPECIFICATION => SPECIFICATION_SHA256,
      GENERATOR => GENERATOR_SHA256
    }.each do |relative, expected|
      path = File.join(root, relative)
      raise Failure, "source input is a symlink: #{relative}" if File.symlink?(path)
      raise Failure, "source input is not a regular file: #{relative}" unless File.file?(path)
      raise Failure, "source input hash differs: #{relative}" unless
        Digest::SHA256.file(path).hexdigest == expected
    end
    true
  end

  def validate_schema(schema)
    exact_fields(
      schema,
      %w[
        schema_version schema_id algorithm_id configuration_id source ranking
        intents
      ],
      "intent schema"
    )
    raise Failure, "intent schema identity differs" unless
      schema["schema_version"] == 1 &&
        schema["schema_id"] == SCHEMA_ID &&
        schema["algorithm_id"] == ALGORITHM_ID &&
        schema["configuration_id"] == CONFIGURATION_ID

    source = schema.fetch("source")
    exact_fields(
      source,
      %w[
        source_id corpus_version generator_id license locale claim_scope
        source_manifest_sha256 specification_sha256 generator_sha256
        physical_train_sha256 physical_train_records linguistic_input
      ],
      "intent source"
    )
    expected_source = {
      "source_id" => SOURCE_ID,
      "corpus_version" => CORPUS_VERSION,
      "generator_id" => GENERATOR_ID,
      "license" => "Apache-2.0",
      "locale" => "pt-BR",
      "claim_scope" => "internal_conformance_only",
      "source_manifest_sha256" =>
        "d9e1ca32ec0f92aa6b5fc6c1d4f232f93389e0bf8031267d23daddf7287006c5",
      "specification_sha256" => SPECIFICATION_SHA256,
      "generator_sha256" => GENERATOR_SHA256,
      "physical_train_sha256" => TRAIN_SHA256,
      "physical_train_records" => 960,
      "linguistic_input" => "train_only"
    }
    raise Failure, "intent source identity differs" unless source == expected_source
    raise Failure, "intent ranking differs" unless
      schema.fetch("ranking") == {
        "score_maximum" => 10_000,
        "ambiguity_margin" => 500,
        "maximum_candidates" => 32,
        "maximum_slots_per_candidate" => 8
      }

    intents = schema.fetch("intents")
    raise Failure, "intent inventory count differs" unless
      intents.is_a?(Array) && intents.length == 20
    external = {}
    internal = {}
    marker_count = 0
    slot_count = 0
    intents.each do |intent|
      exact_fields(
        intent,
        %w[external_intent intent_id evidence_threshold markers slots],
        "intent definition"
      )
      external_id = intent.fetch("external_intent")
      internal_id = intent.fetch("intent_id")
      raise Failure, "external intent ID differs" unless
        external_id.match?(/\A[A-Z][A-Za-z0-9]{0,127}\z/) &&
          !external.key?(external_id)
      raise Failure, "internal intent ID differs" unless
        stable_id?(internal_id) && !internal.key?(internal_id)
      external[external_id] = true
      internal[internal_id] = true

      markers = intent.fetch("markers")
      raise Failure, "marker inventory differs" unless
        markers.is_a?(Array) && !markers.empty? && markers.length <= 16
      marker_texts = {}
      total_score = 0
      markers.each do |marker|
        exact_fields(marker, %w[text weight], "intent marker")
        text = marker.fetch("text")
        weight = marker.fetch("weight")
        raise Failure, "intent marker differs" unless
          text.is_a?(String) && !text.empty? && text.bytesize <= 64 &&
            !text.match?(/[[:space:]\x00]/) && !marker_texts.key?(text) &&
            weight.is_a?(Integer) && weight.positive?
        marker_texts[text] = true
        total_score += weight
      end
      threshold = intent.fetch("evidence_threshold")
      raise Failure, "intent score contract differs" unless
        threshold.is_a?(Integer) && threshold.positive? &&
          threshold <= total_score && total_score <= 10_000

      slots = intent.fetch("slots")
      raise Failure, "slot inventory differs" unless
        slots.is_a?(Array) && !slots.empty? && slots.length <= 8
      slot_keys = {}
      role_keys = {}
      slots.each do |slot|
        validate_slot(slot, marker_texts, slots)
        key = [
          slot.fetch("slot_id"),
          slot.fetch("role"),
          slot.fetch("occurrence")
        ]
        role_key = key.drop(1)
        raise Failure, "duplicate slot identity" if
          slot_keys.key?(key) || role_keys.key?(role_key)
        slot_keys[key] = true
        role_keys[role_key] = true
      end
      marker_count += markers.length
      slot_count += slots.length
    end
    raise Failure, "intent aggregate inventory differs" unless
      marker_count == 49 && slot_count == 26
    true
  rescue KeyError => error
    raise Failure, "intent schema missing key #{error.key}"
  end

  def validate_slot(slot, marker_texts, all_slots)
    required = %w[slot_id role occurrence value_kind extractor]
    optional = %w[minimum maximum]
    raise Failure, "intent slot fields differ" unless
      slot.is_a?(Hash) &&
        (required - slot.keys).empty? &&
        (slot.keys - required - optional).empty?
    raise Failure, "intent slot identity differs" unless
      stable_id?(slot.fetch("slot_id")) &&
        slot.fetch("role").match?(/\A[a-z][a-z0-9_]{0,63}\z/) &&
        slot.fetch("occurrence").is_a?(Integer) &&
        slot.fetch("occurrence").between?(0, 7)
    kind = slot.fetch("value_kind")
    extractor = slot.fetch("extractor")
    raise Failure, "slot extractor is not closed" unless extractor.is_a?(Hash)
    case extractor.fetch("kind")
    when "anchored_tokens"
      exact_fields(
        extractor,
        %w[kind anchor anchor_occurrence token_count],
        "anchored extractor"
      )
      validate_anchor_extractor(extractor, marker_texts)
    when "tokens_before_anchor"
      exact_fields(
        extractor,
        %w[kind anchor anchor_occurrence skip_tokens token_count],
        "before-anchor extractor"
      )
      validate_anchor_extractor(extractor, marker_texts)
      raise Failure, "skip token count differs" unless
        extractor.fetch("skip_tokens").between?(0, 8)
    when "last_token"
      exact_fields(extractor, %w[kind], "last-token extractor")
    when "last_tokens"
      exact_fields(extractor, %w[kind token_count], "last-tokens extractor")
      raise Failure, "last token count differs" unless
        extractor.fetch("token_count").between?(1, 8)
    when "number_after_capture"
      exact_fields(
        extractor,
        %w[kind after_role after_occurrence scale],
        "number extractor"
      )
      reference = all_slots.count do |candidate|
        candidate["role"] == extractor.fetch("after_role") &&
          candidate["occurrence"] == extractor.fetch("after_occurrence") &&
          candidate["value_kind"] != "integer"
      end
      raise Failure, "number extractor reference differs" unless
        reference == 1 && extractor.fetch("scale").is_a?(Integer) &&
          extractor.fetch("scale").positive?
    else
      raise Failure, "unknown slot extractor"
    end

    if kind == "integer"
      raise Failure, "integer slot constraints differ" unless
        slot["minimum"].is_a?(Integer) &&
          slot["maximum"].is_a?(Integer) &&
          slot["minimum"] <= slot["maximum"] &&
          extractor["kind"] == "number_after_capture"
    else
      raise Failure, "text slot constraints differ" unless
        %w[mention text].include?(kind) &&
          !slot.key?("minimum") && !slot.key?("maximum") &&
          extractor["kind"] != "number_after_capture"
    end
    true
  rescue KeyError => error
    raise Failure, "intent slot missing key #{error.key}"
  end

  def validate_anchor_extractor(extractor, markers)
    raise Failure, "anchor extractor differs" unless
      markers.key?(extractor.fetch("anchor")) &&
        extractor.fetch("anchor_occurrence").is_a?(Integer) &&
        extractor.fetch("anchor_occurrence").between?(0, 7) &&
        extractor.fetch("token_count").is_a?(Integer) &&
        extractor.fetch("token_count").between?(1, 8)
  end

  def canonical_schema(schema)
    value = JSON.parse(JSON.generate(schema))
    value.fetch("intents").each do |intent|
      intent.fetch("markers").sort_by! { |marker| marker.fetch("text") }
      intent.fetch("slots").sort_by! do |slot|
        [slot.fetch("slot_id"), slot.fetch("role"), slot.fetch("occurrence")]
      end
    end
    value.fetch("intents").sort_by! { |intent| intent.fetch("intent_id") }
    value
  end

  def parse_package(bytes)
    raise Failure, "intent package exceeds byte limit" if bytes.bytesize > 131_072
    raise Failure, "intent package header is truncated" if bytes.bytesize < 12
    raise Failure, "intent package magic differs" unless
      bytes.byteslice(0, 7) == "NLUINT\0".b
    raise Failure, "intent package version differs" unless bytes.getbyte(7) == 1
    length = bytes.byteslice(8, 4).unpack1("N")
    raise Failure, "intent package framing differs" unless
      length.positive? && length <= 131_072 && bytes.bytesize == 12 + length
    payload = bytes.byteslice(12, length)
    value = parse_json(payload, "packaged intent schema")
    raise Failure, "packaged intent schema is noncanonical" unless
      payload == canonical_json(value)
    validate_schema(value)
    value
  end

  def validate_manifest(manifest, package_schema)
    exact_fields(
      manifest,
      %w[
        schema_version format compiler_id schema_id algorithm_id
        configuration_id random_seed randomness_used source
        schema_source_sha256 canonical_schema_sha256 intent_count marker_count
        slot_count package_bytes package_sha256
      ],
      "intent manifest"
    )
    canonical_payload = canonical_json(package_schema)
    expected = {
      "schema_version" => 1,
      "format" => "nlu-intent-schema-package-v1",
      "compiler_id" => COMPILER_ID,
      "schema_id" => SCHEMA_ID,
      "algorithm_id" => ALGORITHM_ID,
      "configuration_id" => CONFIGURATION_ID,
      "random_seed" => 0,
      "randomness_used" => false,
      "schema_source_sha256" => SCHEMA_SHA256,
      "canonical_schema_sha256" => Digest::SHA256.hexdigest(canonical_payload),
      "intent_count" => 20,
      "marker_count" => 49,
      "slot_count" => 26,
      "package_bytes" => 9_621,
      "package_sha256" => PACKAGE_SHA256
    }
    expected.each do |field, value|
      raise Failure, "intent manifest #{field} differs" unless manifest[field] == value
    end
    raise Failure, "intent manifest source differs" unless
      manifest.fetch("source") == package_schema.fetch("source")
    true
  end

  def parse_jsonl(bytes, context)
    raise Failure, "#{context} lacks one final newline" unless
      bytes.end_with?("\n") && !bytes.end_with?("\r\n")
    rows = bytes.lines.map.with_index(1) do |line, line_number|
      raise Failure, "#{context} has an empty row" if line == "\n"
      parse_json(line, "#{context} row #{line_number}")
    end
    raise Failure, "#{context} row count differs" unless rows.length == 960
    rows
  end

  def validate_train_markers(schema, rows)
    schema.fetch("intents").each do |intent|
      intent_rows = rows.select do |row|
        row.dig("dimensions", "intent") == intent.fetch("external_intent")
      end
      raise Failure, "train intent count differs" unless intent_rows.length == 48
      intent.fetch("markers").each do |marker|
        text = marker.fetch("text")
        raise Failure, "marker is absent from a physical train row: #{text}" unless
          intent_rows.all? { |row| row.fetch("utterance").split.include?(text) }
      end
    end
    true
  end

  def validate_projection(projection, schema)
    exact_fields(
      projection,
      %w[
        schema_version projection_id schema_id source span_derivation
        intent_projections
      ],
      "intent projection"
    )
    raise Failure, "projection identity differs" unless
      projection["schema_version"] == 1 &&
        projection["projection_id"] == PROJECTION_ID &&
        projection["schema_id"] == SCHEMA_ID
    expected_source = {
      "source_id" => SOURCE_ID,
      "corpus_version" => CORPUS_VERSION,
      "generator_id" => GENERATOR_ID,
      "oracle_origin" => "pre_engine_generator_specification",
      "specification_sha256" => SPECIFICATION_SHA256,
      "generator_sha256" => GENERATOR_SHA256,
      "development_sha256" => DEVELOPMENT_SHA256,
      "development_records" => 960,
      "claim_scope" => "internal_conformance_only"
    }
    raise Failure, "projection source differs" unless
      projection.fetch("source") == expected_source
    raise Failure, "projection span derivation differs" unless
      projection.fetch("span_derivation") == {
        "algorithm" => "p02-generator-parameter-exact-utf8-substring-v1",
        "require_unique_match" => true,
        "source_output_allowed" => false,
        "normalization_allowed" => false
      }

    by_external = schema.fetch("intents").to_h do |intent|
      [intent.fetch("external_intent"), intent]
    end
    projections = projection.fetch("intent_projections")
    raise Failure, "projection intent count differs" unless projections.length == 20
    seen = {}
    projections.each do |intent_projection|
      exact_fields(
        intent_projection,
        %w[external_intent intent_id slots],
        "intent projection entry"
      )
      external = intent_projection.fetch("external_intent")
      schema_intent = by_external.fetch(external)
      raise Failure, "projection intent mapping differs" unless
        intent_projection.fetch("intent_id") == schema_intent.fetch("intent_id") &&
          !seen.key?(external)
      seen[external] = true
      schema_slots = schema_intent.fetch("slots").to_h do |slot|
        [[slot.fetch("slot_id"), slot.fetch("role"), slot.fetch("occurrence")], slot]
      end
      projected_slots = intent_projection.fetch("slots")
      raise Failure, "projection slot count differs" unless
        projected_slots.length == schema_slots.length
      projected_slots.each do |slot|
        exact_fields(
          slot,
          %w[
            expected_slot_id expected_kind slot_id role occurrence parameter
            transform
          ],
          "slot projection"
        )
        key = [
          slot.fetch("slot_id"),
          slot.fetch("role"),
          slot.fetch("occurrence")
        ]
        schema_slot = schema_slots.fetch(key)
        expected_kind = if slot.fetch("expected_kind") == "entity"
                          "mention"
                        else
                          slot.fetch("expected_kind")
                        end
        raise Failure, "projection slot kind differs" unless
          schema_slot.fetch("value_kind") == expected_kind
      end
    end
    true
  rescue KeyError => error
    raise Failure, "projection missing key or mapping #{error.key}"
  end

  def validate_report(report, projection)
    exact_fields(
      report,
      %w[
        schema_version runner_id metric_specification dataset recognizer results
        limitations
      ],
      "intent report"
    )
    raise Failure, "report identity differs" unless
      report["schema_version"] == 1 &&
        report["runner_id"] == "intent-eval-v1" &&
        report["metric_specification"] == METRIC_SPEC &&
        report["limitations"] == LIMITATIONS
    raise Failure, "report dataset differs" unless
      report.fetch("dataset") == {
        "dataset_id" => DATASET_ID,
        "source_id" => SOURCE_ID,
        "corpus_version" => CORPUS_VERSION,
        "generator_id" => GENERATOR_ID,
        "oracle_origin" => "pre_engine_generator_specification",
        "locale" => "pt-BR",
        "split" => "development",
        "claim_scope" => "internal_conformance_only",
        "physical_sha256" => DEVELOPMENT_SHA256,
        "records" => 960
      }
    raise Failure, "report recognizer identity differs" unless
      report.fetch("recognizer") == {
        "schema_id" => SCHEMA_ID,
        "algorithm_id" => ALGORITHM_ID,
        "configuration_id" => CONFIGURATION_ID,
        "package_sha256" => PACKAGE_SHA256,
        "package_manifest_sha256" => PACKAGE_MANIFEST_SHA256,
        "projection_id" => PROJECTION_ID,
        "projection_sha256" => PROJECTION_SHA256
      }

    results = report.fetch("results")
    exact_fields(
      results,
      %w[
        exact_semantics outcomes slots intent_strata slot_strata
        prediction_digest_sha256 reconciliation
      ],
      "intent report results"
    )
    raise Failure, "report exact result differs" unless
      results.fetch("exact_semantics") == {
        "numerator" => 384, "denominator" => 960
      } &&
        results.fetch("outcomes") == {
          "matches" => 384,
          "clarifications" => 0,
          "abstentions" => 576,
          "errors" => 0
        } &&
        results.fetch("slots") == {
          "total" => 1_248,
          "value_exact" => 528,
          "value_incorrect" => 0,
          "span_exact" => 528,
          "span_incorrect" => 0,
          "missing" => 720,
          "unexpected" => 0
        } &&
        results.fetch("prediction_digest_sha256") == PREDICTION_DIGEST

    intent_strata = results.fetch("intent_strata")
    expected_intents = projection.fetch("intent_projections")
      .map { |intent| intent.fetch("intent_id") }.sort
    raise Failure, "report intent strata inventory differs" unless
      intent_strata.length == 20 &&
        intent_strata.map { |item| item.fetch("intent_id") } == expected_intents
    intent_strata.each do |stratum|
      exact_fields(
        stratum,
        %w[
          intent_id total exact_semantics matches clarifications abstentions
          errors
        ],
        "intent report stratum"
      )
      exact = EXACT_DEVELOPMENT_INTENTS.include?(stratum.fetch("intent_id"))
      expected = {
        "intent_id" => stratum.fetch("intent_id"),
        "total" => 48,
        "exact_semantics" => exact ? 48 : 0,
        "matches" => exact ? 48 : 0,
        "clarifications" => 0,
        "abstentions" => exact ? 0 : 48,
        "errors" => 0
      }
      raise Failure, "report intent stratum differs" unless stratum == expected
    end

    slot_strata = results.fetch("slot_strata")
    raise Failure, "report slot strata inventory differs" unless
      slot_strata.length == 26 &&
        slot_strata.sum { |item| item.fetch("total") } == 1_248
    slot_strata.each do |stratum|
      exact_fields(
        stratum,
        %w[
          intent_id slot_id role occurrence value_kind total value_exact
          value_incorrect span_exact span_incorrect missing
        ],
        "slot report stratum"
      )
      exact = EXACT_DEVELOPMENT_INTENTS.include?(stratum.fetch("intent_id"))
      raise Failure, "report slot stratum differs" unless
        stratum.fetch("total") == 48 &&
          stratum.fetch("value_exact") == (exact ? 48 : 0) &&
          stratum.fetch("value_incorrect").zero? &&
          stratum.fetch("span_exact") == (exact ? 48 : 0) &&
          stratum.fetch("span_incorrect").zero? &&
          stratum.fetch("missing") == (exact ? 0 : 48)
    end
    raise Failure, "report reconciliation differs" unless
      results.fetch("reconciliation") == {
        "records_expected" => 960,
        "records_observed" => 960,
        "outcome_total" => 960,
        "intent_strata_total" => 960,
        "slots_expected" => 1_248,
        "slot_strata_total" => 1_248,
        "value_accounted" => 1_248,
        "span_accounted" => 1_248,
        "complete" => true
      }
    forbidden_report_keys = %w[
      utterance case_id generator_record_id path timestamp created_at
    ]
    raise Failure, "report leaks record-level or environment data" if
      recursive_keys(report).any? { |key| forbidden_report_keys.include?(key) }
    true
  rescue KeyError => error
    raise Failure, "report missing key #{error.key}"
  end

  def validate_schemas(root, report)
    SCHEMAS.each do |relative, id|
      schema = parse_json(File.binread(File.join(root, relative)), relative)
      raise Failure, "JSON schema dialect differs: #{relative}" unless
        schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
      raise Failure, "JSON schema ID differs: #{relative}" unless schema["$id"] == id
      raise Failure, "JSON schema root is open: #{relative}" unless
        schema["type"] == "object" && schema["additionalProperties"] == false
    end
    report_schema = parse_json(
      File.binread(
        File.join(root, "schemas/intent-evaluation-report-v1.schema.json")
      ),
      "report schema"
    )
    raise Failure, "report schema emitted fields differ" unless
      report_schema.fetch("properties").keys.sort == report.keys.sort
    raise Failure, "report schema stratum bounds differ" unless
      report_schema.dig(
        "properties", "results", "properties", "intent_strata", "minItems"
      ) == 20 &&
        report_schema.dig(
          "properties", "results", "properties", "slot_strata", "minItems"
        ) == 26
    true
  rescue KeyError => error
    raise Failure, "JSON schema missing key #{error.key}"
  end

  def validate_dependencies(root)
    engine = dependency_entries(
      File.binread(File.join(root, "crates/intent-engine/Cargo.toml"))
    )
    evaluator = dependency_entries(
      File.binread(File.join(root, "crates/intent-eval/Cargo.toml"))
    )
    raise Failure, "intent engine dependency surface differs" unless
      engine == {
        "lang-ptbr" => '{ path = "../lang-ptbr" }',
        "nlu-core" => '{ path = "../nlu-core" }',
        "nlu-data" => '{ path = "../nlu-data" }',
        "serde" => "workspace = true",
        "serde_json" => "workspace = true"
      }
    raise Failure, "intent evaluator dependency surface differs" unless
      evaluator == {
        "intent-engine" => '{ path = "../intent-engine" }',
        "nlu-core" => '{ path = "../nlu-core" }',
        "nlu-data" => '{ path = "../nlu-data" }',
        "serde" => "workspace = true",
        "serde_json" => "workspace = true"
      }
    workspace = File.binread(File.join(root, "Cargo.toml"))
    %w[intent-engine intent-eval].each do |crate|
      raise Failure, "workspace intent membership differs: #{crate}" unless
        workspace.scan(%r{"crates/#{crate}"}).length == 1
    end
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
    production = %w[intent-engine lang-ptbr nlu-core nlu-data protocol]
    production.each do |crate|
      manifest = File.binread(File.join(root, "crates/#{crate}/Cargo.toml"))
      raise Failure, "production depends on intent-eval: #{crate}" if
        dependency_entries(manifest).key?("intent-eval")
    end
    files = Dir.glob(File.join(root, "crates/intent-engine/src/**/*.rs")).sort
    validate_intent_runtime_bytes(
      files.to_h do |path|
        relative = path.delete_prefix("#{root}/")
        bytes = File.binread(path)
        production_bytes = bytes.split("\n#[cfg(test)]", 2).first
        [relative, production_bytes]
      end
    )
    true
  end

  def validate_intent_runtime_bytes(files)
    forbidden = %w[
      intent-eval intent_eval data/evaluation development.jsonl heldout.jsonl
      case_id generator_record_id std::fs std::net tcpstream udpsocket reqwest
      hyper:: curl systemtime rand:: entityref
    ]
    files.each do |relative, bytes|
      lowered = bytes.downcase
      forbidden.each do |token|
        raise Failure, "intent runtime leaks #{token}: #{relative}" if
          lowered.include?(token.downcase)
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
      raise Failure, "requirement row missing: #{id}" unless row

      status = row.split("|")[-2]&.strip
      allowed = require_satisfied ? ["SATISFIED"] : %w[PENDING SATISFIED]
      raise Failure, "requirement status differs: #{id}" unless allowed.include?(status)
    end
    true
  end

  def run_reproductions(root)
    Dir.mktmpdir("p09-reproduction-") do |temporary|
      compile_output = File.join(temporary, "compiled")
      run_cargo(
        root,
        [
          "run", "--quiet", "--locked", "-p", "intent-eval", "--bin",
          "intent-compile", "--", "--root", root, "--schema", SCHEMA_SOURCE,
          "--output", compile_output
        ],
        "intent package reproduction"
      )
      {
        "package.bin" => PACKAGE,
        "package-manifest.json" => PACKAGE_MANIFEST
      }.each do |name, tracked|
        raise Failure, "intent package reproduction differs: #{name}" unless
          File.binread(File.join(compile_output, name)) ==
            File.binread(File.join(root, tracked))
      end

      development_output = File.join(temporary, "development-report.json")
      run_evaluator(root, "development", development_output)
      raise Failure, "development report reproduction differs" unless
        File.binread(development_output) == File.binread(File.join(root, REPORT))

      train_output = File.join(temporary, "train-report.json")
      run_evaluator(root, "train", train_output)
      train_report = read_canonical_path(train_output, "train report")
      raise Failure, "train conformance differs" unless
        train_report.dig("results", "exact_semantics") == {
          "numerator" => 960, "denominator" => 960
        } &&
          train_report.dig("results", "slots", "value_exact") == 1_248 &&
          train_report.dig("results", "slots", "span_exact") == 1_248 &&
          train_report.dig("results", "reconciliation", "complete") == true
    end
    true
  end

  def run_evaluator(root, split, output)
    run_cargo(
      root,
      [
        "run", "--quiet", "--locked", "-p", "intent-eval", "--bin",
        "intent-evaluate", "--", "--root", root, "--split", split,
        "--output", output
      ],
      "#{split} intent evaluation"
    )
  end

  def run_cargo(root, arguments, context)
    tool_bin = File.join(root, ".tools/rust-1.98.0/bin")
    stdout, stderr, status = Open3.capture3(
      deterministic_environment(root),
      File.join(tool_bin, "cargo"),
      *arguments,
      chdir: root
    )
    raise Failure, "#{context} exited nonzero: #{stderr.strip}" unless status.success?
    raise Failure, "#{context} wrote diagnostics: #{stderr.strip}" unless stderr.empty?
    expected = context == "intent package reproduction" ?
      "INTENT_COMPILE_PASS\n" : "INTENT_EVALUATE_PASS\n"
    raise Failure, "#{context} stdout differs" unless stdout == expected
    true
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
      "intent-engine",
      "-p",
      "intent-eval",
      "--all-features",
      chdir: root
    )
    return true if status.success?

    warn output
    raise Failure, "P09 Cargo tests failed"
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
      "CARGO_TARGET_DIR" => File.join(root, "target/p09-gate"),
      "RUSTC" => File.join(tool_bin, "rustc"),
      "RUSTDOC" => File.join(tool_bin, "rustdoc")
    }
  end

  def read_canonical_json(root, relative)
    bytes = File.binread(File.join(root, relative))
    value = parse_json(bytes, relative)
    raise Failure, "#{relative} is not canonical with one final newline" unless
      bytes == canonical_json(value) + "\n"
    value
  end

  def read_canonical_path(path, context)
    bytes = File.binread(path)
    value = parse_json(bytes, context)
    raise Failure, "#{context} is not canonical with one final newline" unless
      bytes == canonical_json(value) + "\n"
    value
  end

  def exact_fields(value, fields, context)
    raise Failure, "#{context} fields differ" unless
      value.is_a?(Hash) && value.keys.sort == fields.sort
    true
  end

  def stable_id?(value)
    value.is_a?(String) &&
      value.match?(/\A[a-z][a-z0-9_-]*:[a-z][a-z0-9_-]*[a-z0-9]\z/)
  end

  def recursive_keys(value)
    case value
    when Hash
      value.keys + value.values.flat_map { |child| recursive_keys(child) }
    when Array
      value.flat_map { |child| recursive_keys(child) }
    else
      []
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
end

P09Validation.run(ARGV) if $PROGRAM_NAME == __FILE__
