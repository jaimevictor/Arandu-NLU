# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "tmpdir"
require_relative "generate-p11-corpus"

class P11CorpusTest < Minitest::Test
  def deep_copy(value)
    JSON.parse(JSON.generate(value))
  end

  def generated_bytes(root, paths)
    paths.each_with_object({}) do |relative, result|
      result[relative] = File.binread(File.join(root, relative))
    end
  end

  def test_generation_is_byte_reproducible
    Dir.mktmpdir("p11-corpus-test-a.") do |first_root|
      Dir.mktmpdir("p11-corpus-test-b.") do |second_root|
        first_paths = P11Corpus.generate(first_root)
        second_paths = P11Corpus.generate(second_root)

        assert_equal first_paths, second_paths
        assert_equal(
          generated_bytes(first_root, first_paths),
          generated_bytes(second_root, second_paths)
        )
      end
    end
  end

  def test_nlu_derived_oracle_is_rejected
    spec = deep_copy(P11Corpus.load_spec)
    spec.fetch("lineage")["oracle_origin"] = "nlu_output"

    error = assert_raises(P11Corpus::Failure) do
      P11Corpus.validate_specification!(spec)
    end
    assert_includes error.message, "NLU-derived oracle"
  end

  def test_missing_required_negation_stratum_is_rejected
    spec = deep_copy(P11Corpus.load_spec)
    spec.fetch("required_strata").delete("clear_second_node_negation")

    error = assert_raises(P11Corpus::Failure) do
      P11Corpus.validate_specification!(spec)
    end
    assert_includes error.message, "required negation strata"
  end

  def test_multibyte_argument_span_mutation_is_rejected
    spec = deep_copy(P11Corpus.load_spec)
    records = P11Corpus.build_records(spec)
    development = records.find do |record|
      record.fetch("case_id") == "p11-v1-development-clear-first"
    end
    argument = development
      .fetch("expected")
      .fetch("plan")
      .fetch("nodes")
      .fetch(1)
      .fetch("evidence")
      .fetch(1)
    argument["end_byte"] -= 1

    error = assert_raises(P11Corpus::Failure) do
      P11Corpus.validate_records!(records, spec)
    end
    assert_match(/UTF-8 boundaries|text differs/, error.message)
  end

  def test_registry_id_mutation_is_rejected
    spec = deep_copy(P11Corpus.load_spec)
    records = P11Corpus.build_records(spec)
    entity = records
      .fetch(0)
      .fetch("context")
      .fetch("entities")
      .fetch(0)
    entity["registry_id"] = "0" * 32
    entity["entity_id"] = "ha_entity:id_#{"0" * 32}"

    error = assert_raises(P11Corpus::Failure) do
      P11Corpus.validate_records!(records, spec)
    end
    assert_includes error.message, "not deterministic"
  end

  def test_manifest_output_hash_mutation_is_rejected
    spec = deep_copy(P11Corpus.load_spec)
    records = P11Corpus.build_records(spec)
    artifacts = P11Corpus.output_artifacts(records)
    manifest = P11Corpus.build_manifest(spec, artifacts, records)
    manifest.fetch("outputs").fetch(0)["sha256"] = "0" * 64

    error = assert_raises(P11Corpus::Failure) do
      P11Corpus.validate_manifest!(manifest, spec, artifacts, records)
    end
    assert_includes error.message, "differs from bound inputs and outputs"
  end
end
