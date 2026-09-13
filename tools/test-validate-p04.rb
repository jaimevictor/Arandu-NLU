# frozen_string_literal: true

require "digest"
require "tmpdir"
require_relative "validate-p04"

module P04ValidationTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure
    yield
    raise "expected P04Validation::Failure"
  rescue P04Validation::Failure => error
    error
  end

  def test_repository_source_and_dependency_contract
    assert(
      P04Validation.validate(P04Validation::ROOT, run_cargo: false),
      "repository P04 source contract"
    )
  end

  def test_artifact_hash_rejects_mutation
    Dir.mktmpdir("FIXTURE_TECNICA_p04_hash") do |directory|
      path = File.join(directory, "FIXTURE_TECNICA.txt")
      File.binwrite(path, "FIXTURE_TECNICA_A")
      expected = {
        "bytes" => File.size(path),
        "sha256" => Digest::SHA256.file(path).hexdigest
      }
      P04Validation.verify_artifact(path, expected)
      File.binwrite(path, "FIXTURE_TECNICA_B")
      error = assert_failure do
        P04Validation.verify_artifact(path, expected)
      end
      assert(error.message.include?("hash differs"), "hash mutation rejection")
    end
  end

  def test_conformance_row_count_ignores_headers_and_sections
    fixture = <<~TEXT
      # FIXTURE_TECNICA header
      @Part0 # FIXTURE_TECNICA section

      0041;0041; # FIXTURE_TECNICA row
      0042;0042;
    TEXT
    assert(P04Validation.conformance_rows(fixture) == 2, "conformance row count")
  end

  def test_lock_parser_extracts_exact_registry_identity
    fixture = <<~LOCK
      [[package]]
      name = "FIXTURE_TECNICA"
      version = "1.2.3"
      source = "registry+https://example.invalid/index"
      checksum = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    LOCK
    assert(
      P04Validation.parse_lock(fixture)["FIXTURE_TECNICA"] ==
        ["1.2.3", "a" * 64],
      "lock identity"
    )
  end

  def run
    methods.grep(/^test_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P04_GATE_TESTS_PASS"
  end
end

P04ValidationTest.run
