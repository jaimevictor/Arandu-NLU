# frozen_string_literal: true

require_relative "validate-p07"

module P07ValidationTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure
    yield
    raise "expected P07Validation::Failure"
  rescue P07Validation::Failure => error
    error
  end

  def read_json(relative)
    P07Validation.parse_json(
      File.binread(File.join(P07Validation::ROOT, relative)),
      relative
    )
  end

  def deep_copy(value)
    JSON.parse(JSON.generate(value))
  end

  def test_changed_metric_and_context_are_rejected
    manifest = read_json(P07Validation::EVALUATION_MANIFEST)
    report = read_json(P07Validation::EVALUATION_REPORT)

    changed_metric = deep_copy(report)
    changed_metric["metrics"]["exact_surface_sets"]["numerator"] = 27
    error = assert_failure do
      P07Validation.validate_report(changed_metric, manifest)
    end
    assert(error.message.include?("fraction differs"), "metric mutation")

    changed_context = deep_copy(report)
    changed_context["metrics"]["analysis_precision"]["dataset_id"] =
      "FIXTURE_TECNICA"
    error = assert_failure do
      P07Validation.validate_report(changed_context, manifest)
    end
    assert(error.message.include?("context differs"), "context mutation")
  end

  def test_duplicate_json_key_is_rejected
    error = assert_failure do
      P07Validation.parse_json(
        '{"FIXTURE_TECNICA":1,"FIXTURE_TECNICA":2}',
        "FIXTURE_TECNICA duplicate"
      )
    end
    assert(error.message.include?("DuplicateKey"), "duplicate-key diagnostic")
  end

  def test_manifest_and_hash_substitution_are_rejected
    manifest = deep_copy(read_json(P07Validation::EVALUATION_MANIFEST))
    manifest["artifact_sha256"] = "0" * 64
    error = assert_failure { P07Validation.validate_manifest(manifest) }
    assert(error.message.include?("contract differs"), "manifest substitution")

    artifact = File.binread(
      File.join(P07Validation::ROOT, P07Validation::MORPHOLOGY_ARTIFACT)
    )
    artifact.setbyte(0, artifact.getbyte(0) ^ 1)
    error = assert_failure do
      P07Validation.validate_artifact_bytes(
        P07Validation::MORPHOLOGY_ARTIFACT,
        artifact
      )
    end
    assert(error.message.include?("hash differs"), "artifact hash substitution")
  end

  def test_nonzero_error_taxonomy_is_deterministic
    rows = P07Validation.morphology_rows(
      File.binread(
        File.join(P07Validation::ROOT, P07Validation::MORPHOLOGY_ARTIFACT)
      )
    )
    first = rows.fetch(0)
    second = rows.fetch(1)
    case_ids = [first.fetch("case_id")]
    surface = first.fetch("surface")
    issues = [
      {
        "error_type" => "missing_analysis",
        "surface" => surface,
        "case_ids" => case_ids,
        "expected_analysis" => deep_copy(
          first.fetch("expected_analyses").fetch(0)
        )
      },
      {
        "error_type" => "unexpected_analysis",
        "surface" => surface,
        "case_ids" => case_ids,
        "observed_analysis" => deep_copy(
          second.fetch("expected_analyses").fetch(0)
        )
      },
      {
        "error_type" => "cardinality_mismatch",
        "surface" => surface,
        "case_ids" => case_ids,
        "expected" => 1,
        "observed" => 0
      }
    ]
    assert(P07Validation.validate_error_records(issues), "nonzero error records")
    first_bytes = P07Validation.canonical_json(issues)
    second_bytes = P07Validation.canonical_json(deep_copy(issues))
    assert(first_bytes == second_bytes, "deterministic nonzero errors")

    error = assert_failure do
      P07Validation.validate_error_records(issues.reverse)
    end
    assert(error.message.include?("canonically ordered"), "error ordering mutation")
  end

  def test_report_byte_drift_is_rejected
    report = read_json(P07Validation::EVALUATION_REPORT)
    bytes = File.binread(
      File.join(P07Validation::ROOT, P07Validation::EVALUATION_REPORT)
    )
    error = assert_failure do
      P07Validation.validate_report_bytes(bytes + " ", report)
    end
    assert(error.message.include?("hash differs"), "report byte drift")
  end

  def test_repository_candidate_contract
    rows = P07Validation.validate(
      P07Validation::ROOT,
      run_cargo: false,
      require_satisfied: false,
      run_evaluator: false
    )
    assert(rows.length == 29, "repository P07 candidate")
  end

  def test_runtime_source_leak_is_rejected
    files = {
      "crates/nlu-core/src/FIXTURE_TECNICA.rs" =>
        'const FIXTURE_TECNICA: &str = "morphology-eval";'
    }
    error = assert_failure do
      P07Validation.validate_production_bytes(files, "Rust source")
    end
    assert(error.message.include?("leaks morphology-eval"), "runtime leak")
  end

  def run
    methods.grep(/^test_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P07_GATE_TESTS_PASS"
  end
end

P07ValidationTest.run
