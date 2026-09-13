# frozen_string_literal: true
# P02V3_FUTURE_MUTABLE_SOURCE_BOUNDARY_V1: fixture-only generator tests
# SPDX-License-Identifier: Apache-2.0

require "fileutils"
require "tmpdir"

require_relative "generate-p02-v3-corpus"

module P02V3CorpusTests
  module_function

  def assert(condition, message)
    raise message unless condition
  end

  def assert_failure(fragment)
    yield
    raise "expected failure containing #{fragment.inspect}"
  rescue P02V3Corpus::Failure => error
    raise "unexpected failure: #{error.message}" unless
      error.message.include?(fragment)
  end

  def fixture_language_spec
    {
      "language_contract" => {
        "forbidden_record_markers" => [
          "FIXTURE_TECNICA",
          "<placeholder>"
        ]
      }
    }
  end

  def test_strict_json_accepts_fixture
    parsed = P02V3Corpus.parse_json(
      "{\"fixture\":\"FIXTURE_TECNICA\"}\n",
      "FIXTURE_TECNICA JSON"
    )
    assert(
      parsed == {"fixture" => "FIXTURE_TECNICA"},
      "fixture JSON differs"
    )
  end

  def test_duplicate_json_key_is_rejected
    assert_failure("invalid") do
      P02V3Corpus.parse_json(
        "{\"fixture\":1,\"fixture\":2}\n",
        "FIXTURE_TECNICA duplicate"
      )
    end
  end

  def test_invalid_utf8_is_rejected
    bytes = "{\"fixture\":\"".b + "\xff".b + "\"}\n".b
    assert_failure("not valid UTF-8") do
      P02V3Corpus.parse_json(bytes, "FIXTURE_TECNICA encoding")
    end
  end

  def test_regular_reader_enforces_bounds_and_symlinks
    Dir.mktmpdir("p02-v3-generator-fixture.") do |root|
      target = File.join(root, "FIXTURE_TECNICA-target")
      link = File.join(root, "FIXTURE_TECNICA-link")
      File.binwrite(target, "FIXTURE_TECNICA\n")
      bytes = P02V3Corpus.read_regular(
        target,
        64,
        "FIXTURE_TECNICA regular"
      )
      assert(bytes == "FIXTURE_TECNICA\n", "fixture bytes differ")
      assert_failure("exceeds the byte limit") do
        P02V3Corpus.read_regular(
          target,
          1,
          "FIXTURE_TECNICA bounded"
        )
      end
      File.symlink(target, link)
      assert_failure("symlink component") do
        P02V3Corpus.read_regular(
          link,
          64,
          "FIXTURE_TECNICA symlink"
        )
      end
    end
  end

  def test_regular_reader_rejects_ancestor_symlink_escape
    Dir.mktmpdir("p02-v3-generator-fixture.") do |parent|
      root = File.join(parent, "FIXTURE_TECNICA-root")
      outside = File.join(parent, "FIXTURE_TECNICA-outside")
      FileUtils.mkdir_p(root)
      FileUtils.mkdir_p(outside)
      File.binwrite(
        File.join(outside, "FIXTURE_TECNICA-record"),
        "FIXTURE_TECNICA\n"
      )
      File.symlink(outside, File.join(root, "suites"))
      assert_failure("symlink component") do
        P02V3Corpus.read_regular(
          File.join(root, "suites", "FIXTURE_TECNICA-record"),
          64,
          "FIXTURE_TECNICA ancestor symlink",
          root: root
        )
      end
    end
  end

  def test_canonical_hash_ignores_mapping_insertion_order
    left = {
      "fixture_b" => 2,
      "fixture_a" => {"fixture_d" => 4, "fixture_c" => 3}
    }
    right = {
      "fixture_a" => {"fixture_c" => 3, "fixture_d" => 4},
      "fixture_b" => 2
    }
    assert(
      P02V3Corpus.canonical_sha(left) ==
        P02V3Corpus.canonical_sha(right),
      "canonical fixture hash differs"
    )
  end

  def test_counter_is_deterministic_and_domain_separated
    seed = "0123456789abcdef"
    first = P02V3Corpus.counter_u64(
      seed,
      "FIXTURE_TECNICA",
      1
    )
    second = P02V3Corpus.counter_u64(
      seed,
      "FIXTURE_TECNICA",
      1
    )
    different = P02V3Corpus.counter_u64(
      seed,
      "FIXTURE_TECNICA",
      2
    )
    assert(first == second, "fixture counter is not deterministic")
    assert(first != different, "fixture counter lacks domain separation")
    assert_failure("seed is invalid") do
      P02V3Corpus.counter_u64("FIXTURE_TECNICA", 1)
    end
  end

  def test_permutation_has_no_fixture_collisions
    seed = "fedcba9876543210"
    values = (1..97).map do |ordinal|
      P02V3Corpus.permutation_ordinal(
        seed,
        "FIXTURE_TECNICA",
        ordinal,
        997
      )
    end
    assert(values.uniq.length == values.length, "fixture permutation collides")
  end

  def test_template_rendering_is_exact
    rendered = P02V3Corpus.render_template(
      "FIXTURE_TECNICA %{value}",
      {value: "resultado"}
    )
    assert(
      rendered == "FIXTURE_TECNICA resultado",
      "fixture template rendering differs"
    )
    assert_failure("template rendering failed") do
      P02V3Corpus.render_template(
        "FIXTURE_TECNICA %{missing}",
        {value: "resultado"}
      )
    end
  end

  def test_static_token_projection_excludes_placeholders
    tokens = P02V3Corpus.static_tokens(
      "FIXTURE_TECNICA faça %{target} agora"
    )
    assert(tokens.include?("faça"), "fixture static token is missing")
    assert(!tokens.include?("target"), "fixture placeholder leaked")
  end

  def test_json_lines_are_lf_terminated
    records = [
      {"fixture" => "FIXTURE_TECNICA_A"},
      {"fixture" => "FIXTURE_TECNICA_B"}
    ]
    bytes = P02V3Corpus.json_lines(records)
    assert(bytes.end_with?("\n"), "fixture JSONL lacks final LF")
    assert(bytes.lines.length == 2, "fixture JSONL count differs")
    assert(!bytes.include?("\r"), "fixture JSONL contains CR")
  end

  def test_forbidden_fixture_marker_is_detected
    assert(
      P02V3Corpus.forbidden_language?(
        fixture_language_spec,
        "FIXTURE_TECNICA"
      ),
      "fixture marker was not detected"
    )
    assert(
      !P02V3Corpus.forbidden_language?(
        fixture_language_spec,
        "conteúdo técnico permitido"
      ),
      "fixture marker produced a false positive"
    )
  end

  def test_self_test_source_has_no_release_record_loader
    source = P02V3Corpus.read_regular(
      __FILE__,
      1024 * 1024,
      "FIXTURE_TECNICA self-test source",
      root: P02V3Corpus::ROOT
    )
    prohibited = [
      "P02V3Corpus::" + "DATA_ROOT",
      "P02V3Corpus." + "generated_bytes",
      "P02V3Corpus." + "build_artifacts",
      ["data/project-authored", "p02-v3", "heldout" + ".jsonl"].join("/"),
      ["data/project-authored", "p02-v3", "performance" + ".jsonl"].join("/")
    ]
    assert(
      prohibited.none? { |needle| source.include?(needle) },
      "self-test source references a release record loader"
    )
  end

  def run
    methods.grep(/\Atest_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P02_V3_CORPUS_TESTS_PASS"
  end
end

P02V3CorpusTests.run
