# frozen_string_literal: true

require "json"
require_relative "validate-p10"

module P10ValidationTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure
    yield
    raise "expected P10Validation::Failure"
  rescue P10Validation::Failure => error
    error
  end

  def deep_copy(value)
    JSON.parse(JSON.generate(value))
  end

  def read_coverage
    P10Validation.read_canonical_json(P10Validation::ROOT, P10Validation::COVERAGE)
  end

  def read_source
    P10Validation.read_yaml(P10Validation::ROOT, P10Validation::SOURCE_EVIDENCE)
  end

  def read_materials
    P10Validation.read_yaml(P10Validation::ROOT, P10Validation::MATERIALS)
  end

  def test_artifact_byte_mutation_is_rejected
    bytes = File.binread(File.join(P10Validation::ROOT, P10Validation::COVERAGE))
    changed = bytes.dup
    changed.setbyte(0, changed.getbyte(0) ^ 1)
    error = assert_failure do
      P10Validation.validate_artifact_bytes(P10Validation::COVERAGE, changed)
    end
    assert(error.message.include?("hash differs"), "coverage hash mutation")
  end

  def test_source_identity_and_path_mutations_are_rejected
    source = deep_copy(read_source)
    source.fetch("home_assistant_catalog_contract")["commit"] = "0" * 40
    error = assert_failure { P10Validation.validate_source_evidence(source) }
    assert(error.message.include?("source identity"), "source commit mutation")

    source = deep_copy(read_source)
    source
      .fetch("home_assistant_catalog_contract")
      .fetch("selected_paths")
      .fetch(0)["sha256"] = "0" * 64
    error = assert_failure { P10Validation.validate_source_evidence(source) }
    assert(error.message.include?("path inventory"), "source path mutation")
  end

  def test_material_record_mutation_is_rejected
    materials = deep_copy(read_materials)
    record = materials.fetch("materials").find do |item|
      item.fetch("id") == P10Validation::SOURCE_ID
    end
    record["observed_generated_entity_platform_domains"] = 44
    error = assert_failure { P10Validation.validate_materials(materials) }
    assert(error.message.include?("material identity"), "material denominator")
  end

  def test_coverage_domain_and_disposition_mutations_are_rejected
    coverage = deep_copy(read_coverage)
    coverage.fetch("domains").pop
    error = assert_failure { P10Validation.validate_coverage(coverage) }
    assert(error.message.include?("domain coverage"), "missing domain")

    coverage = deep_copy(read_coverage)
    coverage
      .fetch("domains")
      .fetch(0)
      .fetch("operations")
      .fetch("action")["disposition"] = "supported"
    error = assert_failure { P10Validation.validate_coverage(coverage) }
    assert(error.message.include?("operation dispositions"), "action overclaim")
  end

  def test_coverage_intent_and_prerequisite_mutations_are_rejected
    coverage = deep_copy(read_coverage)
    coverage.fetch("intent_families").fetch(0)["intent"] = "HassFixtureTecnica"
    error = assert_failure { P10Validation.validate_coverage(coverage) }
    assert(error.message.include?("intent coverage"), "intent substitution")

    coverage = deep_copy(read_coverage)
    coverage.fetch("action_contract_prerequisites").pop
    error = assert_failure { P10Validation.validate_coverage(coverage) }
    assert(error.message.include?("prerequisite"), "action prerequisite deletion")
  end

  def test_duplicate_json_and_yaml_keys_are_rejected
    error = assert_failure do
      P10Validation.parse_json(
        '{"FIXTURE_TECNICA":1,"FIXTURE_TECNICA":2}',
        "FIXTURE_TECNICA duplicate JSON"
      )
    end
    assert(error.message.include?("DuplicateKey"), "duplicate JSON key")

    error = assert_failure do
      P10Validation.parse_yaml(
        "FIXTURE_TECNICA: 1\nFIXTURE_TECNICA: 2\n",
        "FIXTURE_TECNICA duplicate YAML"
      )
    end
    assert(error.message.include?("duplicate YAML key"), "duplicate YAML key")
  end

  def test_production_authority_mutations_are_rejected
    error = assert_failure do
      P10Validation.validate_runtime_bytes(
        "FIXTURE_TECNICA.rs" => "use std::net::TcpStream;"
      )
    end
    assert(error.message.include?("network"), "network authority")

    error = assert_failure do
      P10Validation.validate_runtime_bytes(
        "FIXTURE_TECNICA.rs" => "let value = include_str!(\"FIXTURE_TECNICA\");"
      )
    end
    assert(error.message.include?("runtime artifact"), "runtime file artifact")
  end

  def test_pending_requirement_is_rejected
    path = File.join(
      P10Validation::ROOT,
      "docs/evidence/REQUIREMENTS-TRACEABILITY.md"
    )
    bytes = File.binread(path)
    changed = bytes.lines.map do |line|
      if line.start_with?("| `P10-HA-001` |")
        line.sub(/\| (?:PENDING|SATISFIED) \|\n\z/, "| PENDING |\n")
      else
        line
      end
    end.join
    error = assert_failure do
      P10Validation.validate_requirement_rows(changed, require_satisfied: true)
    end
    assert(error.message.include?("P10-HA-001"), "pending requirement")
  end

  def test_z_repository_candidate_contract
    assert(
      P10Validation.validate(
        P10Validation::ROOT,
        run_cargo: false,
        require_satisfied: false
      ),
      "repository P10 candidate"
    )
  end

  def run
    methods.grep(/^test_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P10_GATE_TESTS_PASS"
  end
end

P10ValidationTest.run
