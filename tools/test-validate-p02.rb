# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"
require_relative "validate-p02"

module P02ValidationTests
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure(fragment)
    yield
    raise "expected validation failure containing #{fragment.inspect}"
  rescue P02Validation::Failure => error
    assert(
      error.message.include?(fragment),
      "expected #{fragment.inspect}, got #{error.message.inspect}"
    )
  end

  def with_data_copy
    Dir.mktmpdir("p02-validation-test.") do |temporary|
      root = File.join(temporary, "p02-v1")
      FileUtils.mkdir_p(root)
      FileUtils.cp_r("#{P02Corpus::DATA_ROOT}/.", root)
      yield root
    end
  end

  def validate_copy(root)
    P02Validation::Validator.new(
      data_root: root,
      check_generation: false
    ).validate
  end

  def rewrite_record(path, index)
    lines = File.binread(path).lines
    record = JSON.parse(lines.fetch(index))
    yield record
    lines[index] = JSON.generate(record) + "\n"
    File.binwrite(path, lines.join)
  end

  def test_clean_corpus_passes
    assert(
      P02Validation::Validator.new.validate,
      "clean corpus validation"
    )
  end

  def test_generation_is_byte_reproducible
    Dir.mktmpdir("p02-generation-a.") do |first|
      Dir.mktmpdir("p02-generation-b.") do |second|
        first_paths = P02Corpus.generate(first)
        second_paths = P02Corpus.generate(second)
        assert(first_paths == second_paths, "generated path sets")
        first_paths.each do |relative|
          assert(
            File.binread(File.join(first, relative)) ==
              File.binread(File.join(second, relative)),
            "reproducible #{relative}"
          )
        end
      end
    end
  end

  def test_duplicate_case_identity_is_rejected
    with_data_copy do |root|
      path = File.join(root, "heldout.jsonl")
      first = JSON.parse(File.binread(path).lines.first)
      rewrite_record(path, 1) do |record|
        record["context"] = first.fetch("context")
        record["expected"] = first.fetch("expected")
        record["canonical_semantic_id"] =
          first.fetch("canonical_semantic_id")
      end
      assert_failure("duplicate semantic identity") { validate_copy(root) }
    end
  end

  def test_duplicate_json_key_is_rejected
    with_data_copy do |root|
      path = File.join(root, "heldout.jsonl")
      lines = File.binread(path).lines
      lines[0] = lines[0].sub(
        /\A\{/,
        '{"schema_version":1,'
      )
      File.binwrite(path, lines.join)
      assert_failure("invalid JSON") { validate_copy(root) }
    end
  end

  def test_underfilled_intent_is_rejected
    with_data_copy do |root|
      path = File.join(root, "heldout.jsonl")
      lines = File.binread(path).lines
      File.binwrite(path, lines.first(lines.length - 5).join)
      assert_failure("heldout record count differs") { validate_copy(root) }
    end
  end

  def test_self_oracle_is_rejected
    with_data_copy do |root|
      path = File.join(root, "heldout.jsonl")
      rewrite_record(path, 0) do |record|
        record["oracle_origin"] = "project_nlu_output"
      end
      assert_failure("self-derived oracle") { validate_copy(root) }
    end
  end

  def test_family_leakage_is_rejected
    with_data_copy do |root|
      path = File.join(root, "heldout.jsonl")
      rewrite_record(path, 0) do |record|
        record.fetch("dimensions")["family"] =
          "train-hass_turn_off-family-v1"
      end
      assert_failure("family crosses semantic splits") { validate_copy(root) }
    end
  end

  def test_fail_closed_suite_plan_is_rejected
    with_data_copy do |root|
      path = File.join(root, "suites/safety-sensitive.jsonl")
      rewrite_record(path, 0) do |record|
        record.fetch("expected")["outcome"] = "plan"
      end
      assert_failure("permits a plan") { validate_copy(root) }
    end
  end

  def test_pos_span_corruption_is_rejected
    with_data_copy do |root|
      path = File.join(root, "pos-context.jsonl")
      rewrite_record(path, 0) do |record|
        record.fetch("tokens").first["end_byte"] += 1
      end
      assert_failure("token span text differs") { validate_copy(root) }
    end
  end

  def test_language_record_license_change_is_rejected
    with_data_copy do |root|
      path = File.join(root, "lexicon.jsonl")
      rewrite_record(path, 0) do |record|
        record["license"] = "NOASSERTION"
      end
      assert_failure("license differs") { validate_copy(root) }
    end
  end

  def test_external_accuracy_claim_is_rejected
    with_data_copy do |root|
      path = File.join(root, "manifest.json")
      manifest = JSON.parse(File.binread(path))
      manifest.fetch("corpus")["claim_scope"] = "independent_accuracy"
      File.binwrite(path, JSON.pretty_generate(manifest) + "\n")
      assert_failure("claim_scope differs") { validate_copy(root) }
    end
  end

  def test_invalid_utf8_is_rejected
    with_data_copy do |root|
      path = File.join(root, "suites/explicit-negative.jsonl")
      bytes = File.binread(path)
      bytes.setbyte(10, 0xff)
      File.binwrite(path, bytes)
      assert_failure("invalid UTF-8") { validate_copy(root) }
    end
  end

  def run
    methods.grep(/^test_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P02_VALIDATION_TESTS_PASS"
  end
end

P02ValidationTests.run
