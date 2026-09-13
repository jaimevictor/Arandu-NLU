# frozen_string_literal: true

require_relative "benchmark-p02-fallback"

module P02FallbackTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_raises(error_class)
    yield
    raise "expected #{error_class}"
  rescue error_class => error
    error
  end

  def matcher
    P02Fallback::ExactByteMatcher.new(
      [
        ["FIXTURE_TECNICA_C", 3],
        ["FIXTURE_TECNICA_A", 1],
        ["FIXTURE_TECNICA_B", 2]
      ]
    )
  end

  def test_exact_lookup_is_independent_of_table_order
    subject = matcher
    assert(subject.size == 3, "table size")
    assert(subject.lookup("FIXTURE_TECNICA_A") == 1, "first exact match")
    assert(subject.lookup("FIXTURE_TECNICA_B") == 2, "middle exact match")
    assert(subject.lookup("FIXTURE_TECNICA_C") == 3, "last exact match")
    assert(subject.lookup("FIXTURE_TECNICA_D").nil?, "exact miss")
  end

  def test_canonically_equivalent_bytes_are_not_normalized
    composed = "FIXTURE_TECNICA_" + [0x00e1].pack("U")
    decomposed = "FIXTURE_TECNICA_" + [0x0061, 0x0301].pack("U*")
    subject = P02Fallback::ExactByteMatcher.new([[composed, 1]])

    assert(subject.lookup(composed) == 1, "composed bytes match")
    assert(subject.lookup(decomposed).nil?, "different bytes do not match")
  end

  def test_duplicate_keys_are_rejected
    error = assert_raises(P02Fallback::InvalidTable) do
      P02Fallback::ExactByteMatcher.new(
        [
          ["FIXTURE_TECNICA_DUPLICATE", 1],
          ["FIXTURE_TECNICA_DUPLICATE", 2]
        ]
      )
    end
    assert(error.message.include?("duplicate"), "duplicate diagnostic")
  end

  def test_invalid_table_shapes_and_targets_are_rejected
    assert_raises(P02Fallback::InvalidTable) do
      P02Fallback::ExactByteMatcher.new("FIXTURE_TECNICA_NOT_AN_ARRAY")
    end
    assert_raises(P02Fallback::InvalidTable) do
      P02Fallback::ExactByteMatcher.new([["FIXTURE_TECNICA_ONLY_KEY"]])
    end
    assert_raises(P02Fallback::InvalidTable) do
      P02Fallback::ExactByteMatcher.new([["FIXTURE_TECNICA_TARGET", -1]])
    end
  end

  def test_empty_malformed_oversized_and_wrong_encoding_keys_are_rejected
    malformed = "\xff".b.force_encoding(Encoding::UTF_8)
    wrong_encoding = "FIXTURE_TECNICA_BINARY".b
    oversized = "F" * (P02Fallback::ExactByteMatcher::MAX_INPUT_BYTES + 1)

    [empty = "", malformed, oversized, wrong_encoding].each do |key|
      assert_raises(P02Fallback::InvalidTable) do
        P02Fallback::ExactByteMatcher.new([[key, 1]])
      end
    end
    assert(empty.empty?, "empty fixture retained")
  end

  def test_invalid_queries_are_rejected
    subject = matcher
    malformed = "\xff".b.force_encoding(Encoding::UTF_8)

    ["", malformed, "FIXTURE_TECNICA_BINARY".b].each do |query|
      assert_raises(P02Fallback::InvalidInput) { subject.lookup(query) }
    end
  end

  def test_table_owns_an_immutable_copy_of_input_bytes
    key = "FIXTURE_TECNICA_MUTABLE".dup
    subject = P02Fallback::ExactByteMatcher.new([[key, 7]])
    key.replace("FIXTURE_TECNICA_CHANGED")

    assert(subject.lookup("FIXTURE_TECNICA_MUTABLE") == 7, "original bytes retained")
    assert(subject.lookup("FIXTURE_TECNICA_CHANGED").nil?, "mutation is isolated")
  end

  def test_benchmark_workload_is_fixed_and_fixture_only
    entries, queries = P02FallbackBenchmark.workload
    assert(entries.length == P02FallbackBenchmark::ENTRY_COUNT, "entry count")
    assert(queries.length == P02FallbackBenchmark::ENTRY_COUNT * 2, "query count")
    assert(
      entries.all? { |key, _target| key.start_with?("FIXTURE_TECNICA_") },
      "entry fixture labels"
    )
    assert(
      queries.all? { |query| query.start_with?("FIXTURE_TECNICA_") },
      "query fixture labels"
    )
    assert(
      P02FallbackBenchmark.workload_sha256(entries, queries) ==
        P02FallbackBenchmark::EXPECTED_WORKLOAD_SHA256,
      "workload digest"
    )
  end

  def run
    methods.grep(/^test_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P02_FALLBACK_TESTS_PASS"
  end
end

P02FallbackTest.run
