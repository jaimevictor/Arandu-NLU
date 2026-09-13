# frozen_string_literal: true

require_relative "validate-p06"

module P06ValidationTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure
    yield
    raise "expected P06Validation::Failure"
  rescue P06Validation::Failure => error
    error
  end

  def test_repository_candidate_contract
    assert(
      P06Validation.validate(
        P06Validation::ROOT,
        run_cargo: false,
        require_satisfied: false
      ),
      "repository P06 candidate"
    )
  end

  def test_duplicate_json_key_is_rejected
    error = assert_failure do
      P06Validation.parse_json(
        '{"FIXTURE_TECNICA":1,"FIXTURE_TECNICA":2}',
        "FIXTURE_TECNICA duplicate"
      )
    end
    assert(error.message.include?("DuplicateKey"), "duplicate-key diagnostic")
  end

  def test_package_corruption_is_rejected
    package = File.binread(
      File.join(P06Validation::ROOT, P06Validation::PACKAGE)
    )
    package.setbyte(7, 2)
    error = assert_failure { P06Validation.parse_package(package) }
    assert(error.message.include?("header differs"), "version mutation")
  end

  def test_lineage_substitution_is_rejected
    root = P06Validation::ROOT
    rows = P06Validation.source_rows(
      File.binread(File.join(root, P06Validation::SOURCE_LEXICON))
    )
    package = File.binread(File.join(root, P06Validation::PACKAGE))
    entry = JSON.parse(JSON.generate(P06Validation.parse_package(package).first))
    entry["source"]["source_license"] = "MIT"
    compiler_sha256 = Digest::SHA256.file(
      File.join(root, "crates/nlu-data/src/lexicon.rs")
    ).hexdigest
    error = assert_failure do
      P06Validation.validate_entry(entry, rows, compiler_sha256)
    end
    assert(error.message.include?("source lineage differs"), "lineage mutation")
  end

  def test_canonical_json_is_order_independent
    left = {"b" => [{"d" => 2, "c" => 1}], "a" => 0}
    right = {"a" => 0, "b" => [{"c" => 1, "d" => 2}]}
    assert(
      P06Validation.canonical_json(left) == P06Validation.canonical_json(right),
      "canonical object order"
    )
  end

  def run
    methods.grep(/^test_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P06_GATE_TESTS_PASS"
  end
end

P06ValidationTest.run
