# frozen_string_literal: true

require "json"
require_relative "validate-p11"

module P11ValidationTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure
    yield
    raise "expected P11Validation::Failure"
  rescue P11Validation::Failure => error
    error
  end

  def deep_copy(value)
    JSON.parse(JSON.generate(value))
  end

  def semantic_schema
    @semantic_schema ||= P11Validation.read_json(
      P11Validation::ROOT,
      P11Validation::SEMANTIC_SCHEMA
    )
  end

  def report_schema
    @report_schema ||= P11Validation.read_json(
      P11Validation::ROOT,
      P11Validation::REPORT_SCHEMA
    )
  end

  def supplement_plan
    path = File.join(
      P11Validation::ROOT,
      "data/project-authored/p11-v1/train.jsonl"
    )
    rows = P11Validation.parse_jsonl(
      File.binread(path),
      P11Validation::P11_RECORDS,
      "FIXTURE_TECNICA P11 supplement"
    )
    deep_copy(rows.fetch(0).fetch("expected").fetch("plan"))
  end

  def empty_recognizer_outcomes(total)
    {
      "matches" => total,
      "clarifications" => 0,
      "abstentions" => 0,
      "errors" => 0
    }
  end

  def empty_composer_outcomes(total)
    {
      "plans" => total,
      "clarifications" => 0,
      "abstentions" => 0,
      "not_run" => 0,
      "errors" => 0
    }
  end

  def report_fixture(split = "train")
    graph_strata = P11Validation::GRAPH_STRATA.map do |source, stratum, shape, outcome, total|
      {
        "source" => source,
        "stratum" => stratum,
        "graph_shape" => shape,
        "expected_outcome" => outcome,
        "total" => total,
        "intent_exact" => 0,
        "outcome_exact" => 0,
        "graph_exact" => 0,
        "canonical_bytes_exact" => 0,
        "exact_semantics" => 0,
        "recognizer_outcomes" => empty_recognizer_outcomes(total),
        "composer_outcomes" => empty_composer_outcomes(total)
      }
    end
    {
      "schema_version" => 1,
      "runner_id" => "plan-eval-v1",
      "metric_specification" =>
        "exact-p11-outcome-full-graph-and-canonical-bytes-v1",
      "split" => split,
      "sources" => [
        {
          "source_id" => "project-authored-synthetic-ptbr-v1",
          "source_type" => "PROJECT_AUTHORED_SYNTHETIC",
          "corpus_version" => "1.0.0",
          "generator_id" => "p02-generator-v1",
          "oracle_origin" => "pre_engine_generator_specification",
          "claim_scope" => "internal_conformance_only",
          "split" => split,
          "physical_sha256" => P11Validation::P02_HASHES.fetch(split),
          "records" => P11Validation::P02_RECORDS
        },
        {
          "source_id" =>
            "project-authored-synthetic-ptbr-p11-negation-v1",
          "source_type" => "PROJECT_AUTHORED_SYNTHETIC",
          "corpus_version" => "1.0.0",
          "generator_id" => "p11-negation-generator-v1",
          "oracle_origin" => "pre_p11_composer_generator_specification",
          "claim_scope" => "internal_conformance_only",
          "split" => split,
          "physical_sha256" => P11Validation::P11_HASHES.fetch(split),
          "records" => P11Validation::P11_RECORDS
        }
      ],
      "projections" => {
        "pre_resolution_projection_id" =>
          "p09-pre-resolution-oracle-projection-v1",
        "pre_resolution_projection_sha256" =>
          P11Validation::ARTIFACTS.fetch(P11Validation::P09_PROJECTION).fetch(1),
        "plan_projection_id" => "p11-semantic-plan-oracle-projection-v1",
        "plan_projection_sha256" =>
          P11Validation::ARTIFACTS.fetch(P11Validation::P11_PROJECTION).fetch(1)
      },
      "recognizer" => {
        "schema_id" => "p09-intent-schema-v1",
        "algorithm_id" => "p09-exact-fixture-v1",
        "configuration_id" => "p09-fixture-config-v1",
        "package_sha256" => "1" * 64,
        "package_manifest_sha256" => "2" * 64
      },
      "composer" => {
        "schema_id" => "p11-semantic-plan-v1",
        "algorithm_id" => "p11-closed-train-template-composer-v1"
      },
      "comparison_contract" => {
        "outcome_fields" => %w[outcome_kind abstention_reason],
        "full_graph_fields" => P11Validation::GRAPH_MATCH_FIELDS.dup,
        "canonical_bytes_required" => true,
        "acceptance_threshold" => nil
      },
      "results" => {
        "source_counts" => {
          "p02" => P11Validation::P02_RECORDS,
          "p11_negation" => P11Validation::P11_RECORDS,
          "total" => P11Validation::TOTAL_RECORDS
        },
        "expected_outcomes" => {
          "plans" => P11Validation::PLAN_RECORDS,
          "abstentions" => 1
        },
        "recognizer_outcomes" =>
          empty_recognizer_outcomes(P11Validation::TOTAL_RECORDS),
        "composer_outcomes" =>
          empty_composer_outcomes(P11Validation::TOTAL_RECORDS),
        "intent_exact" => {
          "numerator" => 0,
          "denominator" => P11Validation::TOTAL_RECORDS
        },
        "outcome_exact" => {
          "numerator" => 0,
          "denominator" => P11Validation::TOTAL_RECORDS
        },
        "graph_exact" => {
          "numerator" => 0,
          "denominator" => P11Validation::PLAN_RECORDS
        },
        "canonical_bytes_exact" => {
          "numerator" => 0,
          "denominator" => P11Validation::PLAN_RECORDS
        },
        "exact_semantics" => {
          "numerator" => 0,
          "denominator" => P11Validation::TOTAL_RECORDS
        },
        "graph_strata" => graph_strata,
        "prediction_digest_sha256" => "3" * 64,
        "reconciliation" => {
          "records_expected" => P11Validation::TOTAL_RECORDS,
          "records_observed" => P11Validation::TOTAL_RECORDS,
          "source_total" => P11Validation::TOTAL_RECORDS,
          "expected_outcome_total" => P11Validation::TOTAL_RECORDS,
          "recognizer_outcome_total" => P11Validation::TOTAL_RECORDS,
          "composer_outcome_total" => P11Validation::TOTAL_RECORDS,
          "stratum_total" => P11Validation::TOTAL_RECORDS,
          "plan_graph_denominator" => P11Validation::PLAN_RECORDS,
          "graph_comparisons_accounted" => P11Validation::PLAN_RECORDS,
          "complete" => true
        }
      },
      "limitations" => P11Validation::REPORT_LIMITATIONS.dup
    }
  end

  def validate_fixture(report)
    P11Validation.validate_report(
      report,
      report_schema,
      report.fetch("split"),
      privacy_canaries: []
    )
  end

  def test_artifact_hash_mutation_is_rejected
    relative = P11Validation::P11_PROJECTION
    bytes = File.binread(File.join(P11Validation::ROOT, relative))
    changed = bytes.dup
    changed.setbyte(0, changed.getbyte(0) ^ 1)
    error = assert_failure do
      P11Validation.validate_artifact_bytes(relative, changed)
    end
    assert(error.message.include?("hash differs"), "frozen projection mutation")
  end

  def test_duplicate_json_keys_are_rejected
    error = assert_failure do
      P11Validation.parse_json(
        '{"FIXTURE_TECNICA":1,"FIXTURE_TECNICA":2}',
        "FIXTURE_TECNICA duplicate JSON"
      )
    end
    assert(error.message.include?("DuplicateKey"), "duplicate JSON key")

    report = P11Validation.canonical_json(report_fixture)
    duplicate = report.sub(
      '"composer":',
      '"schema_version":1,"composer":'
    )
    error = assert_failure do
      P11Validation.parse_json(duplicate, "FIXTURE_TECNICA duplicate report")
    end
    assert(error.message.include?("DuplicateKey"), "duplicate report key")
  end

  def test_schema_opening_and_threshold_schema_mutations_are_rejected
    schema = deep_copy(semantic_schema)
    schema["additionalProperties"] = true
    error = assert_failure do
      P11Validation.validate_schema_document(
        schema,
        id: schema.fetch("$id"),
        context: "FIXTURE_TECNICA semantic schema"
      )
    end
    assert(error.message.include?("open"), "open semantic schema")

    schema = deep_copy(report_schema)
    schema
      .fetch("$defs")
      .fetch("comparison_contract")
      .fetch("properties")
      .fetch("acceptance_threshold")["const"] = 95
    error = assert_failure do
      P11Validation.validate_report_schema_contract(schema)
    end
    assert(error.message.include?("threshold"), "threshold schema mutation")
  end

  def test_projection_and_manifest_lineage_mutations_are_rejected
    projection = P11Validation.read_json(
      P11Validation::ROOT,
      P11Validation::P11_PROJECTION
    )
    changed = deep_copy(projection)
    changed.fetch("catalog_projection")["nlu_output_allowed"] = true
    error = assert_failure { P11Validation.validate_projection(changed) }
    assert(error.message.include?("catalog projection"), "NLU oracle mutation")

    manifest = P11Validation.read_json(
      P11Validation::ROOT,
      P11Validation::P11_MANIFEST
    )
    changed = deep_copy(manifest)
    changed.fetch("freeze")["nlu_output_used_as_oracle"] = true
    error = assert_failure { P11Validation.validate_manifest(changed) }
    assert(error.message.include?("freeze"), "pre-composer freeze mutation")
  end

  def test_p02_conflict_and_scope_inventory_mutations_are_rejected
    manifest = P11Validation.read_json(
      P11Validation::ROOT,
      P11Validation::P02_MANIFEST
    )
    projection = P11Validation.read_json(
      P11Validation::ROOT,
      P11Validation::P11_PROJECTION
    )

    changed = deep_copy(manifest)
    changed
      .fetch("taxonomies")
      .fetch("suite_classes")
      .fetch("contradiction")
      .delete("cyclic_order")
    error = assert_failure do
      P11Validation.validate_p02_suite_coverage(changed, projection)
    end
    assert(error.message.include?("contradiction inventory"), "cycle coverage")

    changed = deep_copy(manifest)
    changed
      .fetch("taxonomies")
      .fetch("suite_classes")
      .fetch("ambiguity")
      .delete("coordination_scope")
    error = assert_failure do
      P11Validation.validate_p02_suite_coverage(changed, projection)
    end
    assert(error.message.include?("ambiguity inventory"), "scope coverage")

    changed = deep_copy(manifest)
    artifact = changed.fetch("artifacts").find do |entry|
      entry.fetch("path") == "suites/contradiction.jsonl"
    end
    artifact["sha256"] = "0" * 64
    error = assert_failure do
      P11Validation.validate_p02_suite_coverage(changed, projection)
    end
    assert(error.message.include?("artifact binding"), "suite hash binding")
  end

  def test_semantic_predicate_and_class_mutations_are_rejected
    plan = supplement_plan
    plan.fetch("nodes").fetch(0).fetch("evidence").reject! do |atom|
      atom["kind"] == "predicate"
    end
    error = assert_failure do
      P11Validation.validate_semantic_plan(
        plan,
        semantic_schema,
        "FIXTURE_TECNICA missing predicate"
      )
    end
    assert(error.message.include?("predicate"), "missing predicate")

    plan = supplement_plan
    plan["execution_class"] = "atomic_only"
    error = assert_failure do
      P11Validation.validate_semantic_plan(
        plan,
        semantic_schema,
        "FIXTURE_TECNICA class downgrade"
      )
    end
    assert(error.message.include?("execution class"), "class downgrade")
  end

  def test_semantic_dangling_endpoint_and_span_mutations_are_rejected
    plan = supplement_plan
    plan.fetch("independent_pairs").fetch(0)["right"] = "p11:node_9"
    error = assert_failure do
      P11Validation.validate_semantic_plan(
        plan,
        semantic_schema,
        "FIXTURE_TECNICA dangling pair"
      )
    end
    assert(error.message.include?("dangling"), "dangling pair")

    plan = supplement_plan
    atom = plan.fetch("nodes").fetch(0).fetch("evidence").fetch(0)
    atom["end_byte"] = atom["begin_byte"]
    error = assert_failure do
      P11Validation.validate_semantic_plan(
        plan,
        semantic_schema,
        "FIXTURE_TECNICA empty span"
      )
    end
    assert(error.message.include?("span"), "empty span")
  end

  def test_report_fixture_is_accepted
    assert(validate_fixture(report_fixture), "valid aggregate report fixture")
    bytes = P11Validation.canonical_json(report_fixture) + "\n"
    assert(
      P11Validation.validate_report_bytes(
        bytes,
        report_schema,
        "train",
        privacy_canaries: []
      ),
      "canonical report bytes"
    )
  end

  def test_report_denominator_and_source_mutations_are_rejected
    report = report_fixture
    report.fetch("results").fetch("graph_exact")["denominator"] = 963
    error = assert_failure { validate_fixture(report) }
    assert(error.message.include?("denominator"), "graph denominator")

    report = report_fixture
    report.fetch("sources").fetch(1)["records"] = 2
    error = assert_failure { validate_fixture(report) }
    assert(error.message.include?("source identities"), "source count")
  end

  def test_report_threshold_and_limitation_overclaims_are_rejected
    report = report_fixture
    report.fetch("comparison_contract")["acceptance_threshold"] = 95
    error = assert_failure { validate_fixture(report) }
    assert(
      error.message.include?("constant") || error.message.include?("comparison"),
      "threshold overclaim"
    )

    report = report_fixture
    report.fetch("limitations").pop
    error = assert_failure { validate_fixture(report) }
    assert(error.message.include?("constant"), "limitation deletion")
  end

  def test_report_stratum_and_outcome_reconciliation_mutations_are_rejected
    report = report_fixture
    report
      .fetch("results")
      .fetch("graph_strata")
      .fetch(0)["total"] = 47
    error = assert_failure { validate_fixture(report) }
    assert(error.message.include?("strata"), "stratum denominator")

    report = report_fixture
    report
      .fetch("results")
      .fetch("recognizer_outcomes")["matches"] = 962
    error = assert_failure { validate_fixture(report) }
    assert(error.message.include?("recognizer"), "recognizer reconciliation")
  end

  def test_report_privacy_canary_is_rejected
    report = report_fixture
    report.fetch("recognizer")["configuration_id"] =
      "FIXTURE_TECNICA_PRIVATE_CANARY"
    error = assert_failure { validate_fixture(report) }
    assert(error.message.include?("privacy canary"), "privacy canary")
  end

  def test_forbidden_splits_and_dataset_paths_are_rejected
    %w[heldout test ../heldout].each do |split|
      error = assert_failure { P11Validation.validate_split_name(split) }
      assert(error.message.include?("non-admitted"), "forbidden split #{split}")
    end
    error = assert_failure do
      P11Validation.validate_admitted_dataset_path(
        "data/project-authored/p02-v1/heldout.jsonl"
      )
    end
    assert(error.message.include?("non-admitted"), "held-out path")
  end

  def test_production_authority_mutations_are_rejected
    error = assert_failure do
      P11Validation.validate_runtime_bytes(
        "FIXTURE_TECNICA.rs" => "use std::net::TcpStream;"
      )
    end
    assert(error.message.include?("network"), "network authority")

    error = assert_failure do
      P11Validation.validate_runtime_bytes(
        "FIXTURE_TECNICA.rs" => "use serde::Serialize;"
      )
    end
    assert(error.message.include?("serialization"), "serialization authority")

    error = assert_failure do
      P11Validation.validate_runtime_bytes(
        "FIXTURE_TECNICA.rs" => "use plan_eval::evaluate;"
      )
    end
    assert(error.message.include?("evaluation"), "evaluation dependency")
  end

  def test_pending_requirement_is_rejected
    path = File.join(
      P11Validation::ROOT,
      "docs/evidence/REQUIREMENTS-TRACEABILITY.md"
    )
    bytes = File.binread(path)
    changed = bytes.lines.map do |line|
      id = P11Validation::REQUIREMENTS.find do |requirement|
        line.start_with?("| `#{requirement}` |")
      end
      next line unless id

      status = id == "P11-MULTI-001" ? "PENDING" : "SATISFIED"
      line.sub(/\| (?:PENDING|SATISFIED) \|\n\z/, "| #{status} |\n")
    end.join
    error = assert_failure do
      P11Validation.validate_requirement_rows(changed, require_satisfied: true)
    end
    assert(error.message.include?("P11-MULTI-001"), "pending P11 requirement")
  end

  def test_z_repository_candidate_contract
    assert(
      P11Validation.validate(
        P11Validation::ROOT,
        run_cargo: false,
        require_satisfied: false
      ),
      "repository P11 candidate"
    )
  end

  def run
    methods.grep(/^test_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P11_GATE_TESTS_PASS"
  end
end

P11ValidationTest.run
