# frozen_string_literal: true

require "digest"
require "tmpdir"
require_relative "validate-p01"

module P01GateTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure
    yield
    raise "expected P01Gate::Failure"
  rescue P01Gate::Failure => error
    error
  end

  def test_parse_lock_extracts_only_registry_packages
    lock = <<~LOCK
      version = 4

      [[package]]
      name = "fixture-workspace"
      version = "0.1.0"

      [[package]]
      name = "fixture-dependency"
      version = "1.2.3"
      source = "registry+https://example.invalid/index"
      checksum = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    LOCK
    expected = [
      {
        "name" => "fixture-dependency",
        "version" => "1.2.3",
        "checksum" => "a" * 64
      }
    ]
    assert(P01Gate.parse_lock(lock) == expected, "lock parsing")
  end

  def test_checksum_manifest_rejects_a_mutated_file
    Dir.mktmpdir("FIXTURE_TECNICA_p01_gate") do |directory|
      path = File.join(directory, "FIXTURE_TECNICA.txt")
      File.binwrite(path, "FIXTURE_TECNICA_A")
      checksum = {
        "files" => {
          "FIXTURE_TECNICA.txt" => Digest::SHA256.file(path).hexdigest
        }
      }
      P01Gate.verify_checksum_manifest(directory, checksum)
      File.binwrite(path, "FIXTURE_TECNICA_B")
      assert_failure do
        P01Gate.verify_checksum_manifest(directory, checksum)
      end
    end
  end

  def test_forbidden_source_scan_reports_the_boundary
    Dir.mktmpdir("FIXTURE_TECNICA_p01_gate") do |directory|
      path = File.join(directory, "FIXTURE_TECNICA.rs")
      File.binwrite(path, "std::net::TcpStream::connect(\"FIXTURE_TECNICA\")")
      error = assert_failure do
        P01Gate.scan_forbidden([path], {"network" => /std::net/}, allowed: [])
      end
      assert(error.message.include?("network"), "boundary name in failure")
    end
  end

  def test_nlu_data_dependency_set_rejects_an_extra_dependency
    manifest = <<~TOML
      [package]
      name = "FIXTURE_TECNICA"

      [dependencies]
      serde.workspace = true
      serde_json.workspace = true
      network-client = "1"
    TOML
    error = assert_failure do
      P01Gate.validate_exact_dependencies(
        manifest,
        "FIXTURE_TECNICA",
        ["serde.workspace = true", "serde_json.workspace = true"]
      )
    end
    assert(error.message.include?("dependency set differs"), "exact dependency rejection")
  end

  def test_language_source_scan_rejects_network_and_ambient_access
    Dir.mktmpdir("FIXTURE_TECNICA_p01_language_gate") do |directory|
      path = File.join(directory, "FIXTURE_TECNICA.rs")
      File.binwrite(path, "std::net::TcpStream::connect(std::env::var(\"FIXTURE_TECNICA\"));")
      error = assert_failure do
        P01Gate.scan_forbidden([path], P01Gate::LANGUAGE_FORBIDDEN, allowed: [])
      end
      assert(error.message.include?("network"), "language network boundary rejection")
    end
  end

  def test_evaluation_source_scan_rejects_network_process_and_ambient_access
    Dir.mktmpdir("FIXTURE_TECNICA_p01_evaluation_gate") do |directory|
      {
        "network" => "std::net::TcpStream::connect(\"FIXTURE_TECNICA\");",
        "subprocess" => "std::process::Command::new(\"FIXTURE_TECNICA\");",
        "ambient_environment" => "std::env::var(\"FIXTURE_TECNICA\");"
      }.each do |boundary, source|
        path = File.join(directory, "FIXTURE_TECNICA_#{boundary}.rs")
        File.binwrite(path, source)
        error = assert_failure do
          P01Gate.scan_forbidden(
            [path],
            P01Gate::EVALUATION_FORBIDDEN,
            allowed: []
          )
        end
        assert(error.message.include?(boundary), "#{boundary} boundary rejection")
      end
    end
  end

  def test_nlu_data_source_scan_rejects_ambient_and_process_access
    Dir.mktmpdir("FIXTURE_TECNICA_p01_gate") do |directory|
      ambient = File.join(directory, "FIXTURE_TECNICA_ambient.rs")
      File.binwrite(ambient, "std::env::var(\"FIXTURE_TECNICA\");")
      ambient_error = assert_failure do
        P01Gate.scan_forbidden([ambient], P01Gate::DATA_FORBIDDEN, allowed: [])
      end
      assert(
        ambient_error.message.include?("ambient_environment"),
        "ambient boundary rejection"
      )

      process = File.join(directory, "FIXTURE_TECNICA_process.rs")
      File.binwrite(process, "std::process::Command::new(\"FIXTURE_TECNICA\");")
      process_error = assert_failure do
        P01Gate.scan_forbidden([process], P01Gate::DATA_FORBIDDEN, allowed: [])
      end
      assert(process_error.message.include?("process"), "process boundary rejection")
    end
  end

  def test_data_schema_rejects_an_open_root
    schema = {
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "$id" => "https://nlu.local/schemas/FIXTURE_TECNICA.schema.json",
      "type" => "object",
      "additionalProperties" => true,
      "properties" => {"schema_version" => {"const" => 1}}
    }
    error = assert_failure do
      P01Gate.validate_data_schema(
        schema,
        "https://nlu.local/schemas/FIXTURE_TECNICA.schema.json"
      )
    end
    assert(error.message.include?("unknown fields"), "closed schema rejection")
  end

  def test_distribution_rule_matches_exact_paths_and_prefixes
    rule = {
      "paths" => ["FIXTURE_TECNICA_EXACT"],
      "path_prefixes" => ["FIXTURE_TECNICA_PREFIX/"]
    }
    assert(
      P01Gate.distribution_rule_matches?(rule, "FIXTURE_TECNICA_EXACT"),
      "exact distribution path"
    )
    assert(
      P01Gate.distribution_rule_matches?(rule, "FIXTURE_TECNICA_PREFIX/file"),
      "prefixed distribution path"
    )
    assert(
      !P01Gate.distribution_rule_matches?(rule, "FIXTURE_TECNICA_OTHER"),
      "unmatched distribution path"
    )
  end

  def run
    methods.grep(/^test_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P01_GATE_TESTS_PASS"
  end
end

P01GateTest.run
