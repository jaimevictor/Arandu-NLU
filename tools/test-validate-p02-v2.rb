# frozen_string_literal: true

require "fileutils"
require "set"
require "tmpdir"

require_relative "validate-p02-v2"

module P02V2ValidationTests
  module_function

  def assert(condition, message)
    raise message unless condition
  end

  def assert_failure(fragment)
    yield
    raise "expected failure containing #{fragment.inspect}"
  rescue P02V2Validation::Failure, P02V2Corpus::Failure => error
    raise "unexpected failure: #{error.message}" unless
      error.message.include?(fragment)
  end

  def test_strict_json_accepts_fixture
    parsed = P02V2Validation.strict_json(
      "{\"fixture\":\"FIXTURE_TECNICA\"}\n",
      "FIXTURE_TECNICA JSON"
    )
    assert(parsed == {"fixture" => "FIXTURE_TECNICA"}, "fixture JSON differs")
  end

  def test_duplicate_json_key_is_rejected
    assert_failure("invalid JSON") do
      P02V2Validation.strict_json(
        "{\"fixture\":1,\"fixture\":2}\n",
        "FIXTURE_TECNICA duplicate"
      )
    end
  end

  def test_invalid_utf8_is_rejected
    bytes = "{\"fixture\":\"".b + "\xff".b + "\"}\n".b
    assert_failure("not valid UTF-8") do
      P02V2Validation.strict_json(bytes, "FIXTURE_TECNICA encoding")
    end
  end

  def test_jsonl_limits_and_count_are_enforced
    fixture = "{\"fixture\":\"FIXTURE_TECNICA\"}\n"
    rows = P02V2Validation.parse_jsonl(
      fixture,
      1,
      1,
      "FIXTURE_TECNICA JSONL"
    )
    assert(rows.length == 1, "fixture JSONL count differs")
    assert_failure("record count differs") do
      P02V2Validation.parse_jsonl(
        fixture,
        2,
        2,
        "FIXTURE_TECNICA JSONL"
      )
    end
  end

  def test_partition_collision_is_rejected
    P02V2Validation.assert_disjoint!(
      [Set["FIXTURE_TECNICA_A"], Set["FIXTURE_TECNICA_B"]],
      "FIXTURE_TECNICA"
    )
    assert_failure("crosses partitions") do
      P02V2Validation.assert_disjoint!(
        [Set["FIXTURE_TECNICA_A"], Set["FIXTURE_TECNICA_A"]],
        "FIXTURE_TECNICA"
      )
    end
  end

  def test_template_rendering_is_exact
    rendered = P02V2Corpus.render_template(
      "FIXTURE_TECNICA %{value}",
      {value: "resultado"}
    )
    assert(
      rendered == "FIXTURE_TECNICA resultado",
      "fixture template rendering differs"
    )
    assert_failure("template rendering failed") do
      P02V2Corpus.render_template(
        "FIXTURE_TECNICA %{missing}",
        {value: "resultado"}
      )
    end
  end

  def test_canonical_hash_ignores_mapping_insertion_order
    left = {"b" => 2, "a" => {"d" => 4, "c" => 3}}
    right = {"a" => {"c" => 3, "d" => 4}, "b" => 2}
    assert(
      P02V2Corpus.canonical_sha(left) == P02V2Corpus.canonical_sha(right),
      "canonical fixture hash differs"
    )
  end

  def test_static_token_projection_excludes_placeholders
    tokens = P02V2Corpus.static_tokens(
      "FIXTURE_TECNICA faça %{target} agora"
    )
    assert(tokens.include?("faça"), "static token is missing")
    assert(!tokens.include?("target"), "placeholder leaked into static tokens")
  end

  def test_regular_file_reader_rejects_symlinks
    Dir.mktmpdir("p02-v2-fixture.") do |root|
      target = File.join(root, "target")
      link = File.join(root, "link")
      File.binwrite(target, "FIXTURE_TECNICA\n")
      File.symlink(target, link)
      assert_failure("must not be a symlink") do
        P02V2Validation.read_regular(
          link,
          1024,
          "FIXTURE_TECNICA symlink"
        )
      end
    end
  end

  def test_test_source_has_no_release_split_loader
    source = File.binread(__FILE__)
    prohibited = [
      "data/project-authored/p02-v2/" + "heldout.jsonl",
      "data/project-authored/p02-v2/" + "performance.jsonl",
      "P02V2Corpus::DATA_" + "ROOT"
    ]
    assert(
      prohibited.none? { |needle| source.include?(needle) },
      "test source references a release split loader"
    )
  end

  def run
    methods.grep(/\Atest_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P02_V2_VALIDATION_TESTS_PASS"
  end
end

P02V2ValidationTests.run
