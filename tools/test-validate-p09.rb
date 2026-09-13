# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "validate-p09"

module P09ValidationTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure
    yield
    raise "expected P09Validation::Failure"
  rescue P09Validation::Failure => error
    error
  end

  def read_json(relative)
    P09Validation.parse_json(
      File.binread(File.join(P09Validation::ROOT, relative)),
      relative
    )
  end

  def test_artifact_byte_mutation_is_rejected
    bytes = File.binread(File.join(P09Validation::ROOT, P09Validation::PACKAGE))
    bytes.setbyte(0, bytes.getbyte(0) ^ 1)
    error = assert_failure do
      P09Validation.validate_artifact_bytes(P09Validation::PACKAGE, bytes)
    end
    assert(error.message.include?("hash differs"), "artifact mutation")
  end

  def test_package_version_and_trailing_bytes_are_rejected
    bytes = File.binread(File.join(P09Validation::ROOT, P09Validation::PACKAGE))
    changed = bytes.dup
    changed.setbyte(7, 2)
    error = assert_failure { P09Validation.parse_package(changed) }
    assert(error.message.include?("version differs"), "version mutation")

    error = assert_failure { P09Validation.parse_package(bytes + "\0") }
    assert(error.message.include?("framing differs"), "trailing mutation")
  end

  def test_schema_duplicate_capture_identity_is_rejected
    schema = JSON.parse(JSON.generate(read_json(P09Validation::SCHEMA_SOURCE)))
    slots = schema.fetch("intents")
      .find { |intent| intent.fetch("external_intent") == "HassTurnOn" }
      .fetch("slots")
    slots.fetch(1)["occurrence"] = 0
    error = assert_failure { P09Validation.validate_schema(schema) }
    assert(error.message.include?("duplicate slot identity"), "capture identity")
  end

  def test_projection_output_oracle_mutation_is_rejected
    schema = read_json(P09Validation::SCHEMA_SOURCE)
    projection = JSON.parse(JSON.generate(read_json(P09Validation::PROJECTION)))
    projection.fetch("span_derivation")["source_output_allowed"] = true
    error = assert_failure do
      P09Validation.validate_projection(projection, schema)
    end
    assert(error.message.include?("span derivation differs"), "output oracle")
  end

  def test_report_metric_and_denominator_mutations_are_rejected
    projection = read_json(P09Validation::PROJECTION)
    report = JSON.parse(JSON.generate(read_json(P09Validation::REPORT)))
    report.dig("results", "exact_semantics")["numerator"] = 385
    error = assert_failure do
      P09Validation.validate_report(report, projection)
    end
    assert(error.message.include?("exact result differs"), "metric mutation")

    report.dig("results", "exact_semantics")["numerator"] = 384
    report.dig("results", "reconciliation")["slot_strata_total"] = 1_247
    error = assert_failure do
      P09Validation.validate_report(report, projection)
    end
    assert(error.message.include?("reconciliation differs"), "denominator mutation")
  end

  def test_production_evaluator_and_network_mutations_are_rejected
    error = assert_failure do
      P09Validation.validate_intent_runtime_bytes(
        "FIXTURE_TECNICA.rs" =>
          "const FIXTURE_TECNICA: &str = \"intent-eval\";"
      )
    end
    assert(error.message.include?("intent-eval"), "evaluator leak")

    error = assert_failure do
      P09Validation.validate_intent_runtime_bytes(
        "FIXTURE_TECNICA.rs" => "use std::net::TcpStream;"
      )
    end
    assert(error.message.include?("std::net"), "network leak")
  end

  def test_pending_p09_requirement_is_rejected
    traceability = File.binread(
      File.join(
        P09Validation::ROOT,
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md"
      )
    )
    bytes = traceability.lines.map do |line|
      if line.start_with?("| `P09-INT-001` |")
        line.sub("| SATISFIED |", "| PENDING |")
      else
        line
      end
    end.join
    assert(bytes != traceability, "pending requirement mutation")
    error = assert_failure do
      P09Validation.validate_requirement_rows(
        bytes,
        require_satisfied: true
      )
    end
    assert(error.message.include?("P09-"), "pending requirement")
  end

  def test_duplicate_json_key_is_rejected
    error = assert_failure do
      P09Validation.parse_json(
        '{"FIXTURE_TECNICA":1,"FIXTURE_TECNICA":2}',
        "FIXTURE_TECNICA duplicate"
      )
    end
    assert(error.message.include?("DuplicateKey"), "duplicate JSON key")
  end

  def test_repository_candidate_contract
    assert(
      P09Validation.validate(
        P09Validation::ROOT,
        run_cargo: false,
        require_satisfied: false,
        run_reproduction: false
      ),
      "repository P09 candidate"
    )
  end

  def run
    methods.grep(/^test_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P09_GATE_TESTS_PASS"
  end
end

P09ValidationTest.run
