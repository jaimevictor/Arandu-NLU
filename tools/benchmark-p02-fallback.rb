# frozen_string_literal: true

require "digest"
require "json"
require_relative "p02-fallback"

module P02FallbackBenchmark
  WORKLOAD_SCHEMA = "FIXTURE_TECNICA_P02_FALLBACK_WORKLOAD_V1"
  EXPECTED_WORKLOAD_SHA256 =
    "97a670c272a9ebc100d16b4eef33b5ec9a300524a5a543ff5eeefad28ad80ee6"
  ENTRY_COUNT = 4_096
  CYCLES_PER_RUN = 128
  WARMUP_RUNS = 3
  MEASURED_RUNS = 5

  module_function

  def workload
    entries = Array.new(ENTRY_COUNT) do |index|
      [format("FIXTURE_TECNICA_KEY_%04d", index), index]
    end
    queries = entries.each_with_index.flat_map do |entry, index|
      [
        entry.fetch(0).dup,
        format("FIXTURE_TECNICA_MISS_%04d", index)
      ]
    end
    [entries, queries]
  end

  def workload_sha256(entries, queries)
    digest = Digest::SHA256.new
    digest << [WORKLOAD_SCHEMA.bytesize].pack("N")
    digest << WORKLOAD_SCHEMA.b
    digest << [CYCLES_PER_RUN, WARMUP_RUNS, MEASURED_RUNS].pack("N3")
    digest << [entries.length].pack("N")
    entries.each do |key, target|
      digest << [key.bytesize].pack("N")
      digest << key.b
      digest << [target].pack("N")
    end
    digest << [queries.length].pack("N")
    queries.each do |query|
      digest << [query.bytesize].pack("N")
      digest << query.b
    end
    digest.hexdigest
  end

  def measure(matcher, queries)
    expected_hits = ENTRY_COUNT * CYCLES_PER_RUN
    expected_target_sum = ((ENTRY_COUNT - 1) * ENTRY_COUNT / 2) * CYCLES_PER_RUN
    hits = 0
    target_sum = 0

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    CYCLES_PER_RUN.times do
      queries.each do |query|
        target = matcher.lookup(query)
        next if target.nil?

        hits += 1
        target_sum += target
      end
    end
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    raise "FIXTURE_TECNICA hit count differs" unless hits == expected_hits
    raise "FIXTURE_TECNICA target sum differs" unless target_sum == expected_target_sum

    lookups = queries.length * CYCLES_PER_RUN
    {
      "lookups" => lookups,
      "hits" => hits,
      "target_sum" => target_sum,
      "elapsed_seconds" => elapsed.round(6),
      "lookups_per_second" => (lookups / elapsed).round(2),
      "nanoseconds_per_lookup" => ((elapsed * 1_000_000_000) / lookups).round(2)
    }
  end

  def median(values)
    sorted = values.sort
    sorted.fetch(sorted.length / 2)
  end

  def report
    entries, queries = workload
    workload_digest = workload_sha256(entries, queries)
    unless workload_digest == EXPECTED_WORKLOAD_SHA256
      raise "FIXTURE_TECNICA workload digest differs"
    end

    matcher = P02Fallback::ExactByteMatcher.new(entries)
    warmups = Array.new(WARMUP_RUNS) { measure(matcher, queries) }
    measured = Array.new(MEASURED_RUNS) { measure(matcher, queries) }
    rates = measured.map { |sample| sample.fetch("lookups_per_second") }

    {
      "schema_version" => 1,
      "prototype" => "exact_utf8_byte_match_v1",
      "fixture_class" => "FIXTURE_TECNICA",
      "algorithm" => "sorted_binary_search_without_normalization_or_ranking",
      "runtime" => {
        "engine" => RUBY_ENGINE,
        "version" => RUBY_VERSION,
        "platform" => RUBY_PLATFORM
      },
      "workload" => {
        "sha256" => workload_digest,
        "entries" => entries.length,
        "queries_per_cycle" => queries.length,
        "cycles_per_run" => CYCLES_PER_RUN,
        "warmup_runs" => WARMUP_RUNS,
        "measured_runs" => MEASURED_RUNS
      },
      "invariants" => {
        "external_linguistic_sources" => 0,
        "external_oracle_cases" => 0,
        "semantic_coverage_cases" => 0,
        "normalization" => false,
        "morphology" => false,
        "contextual_pos" => false,
        "fuzzy_matching" => false,
        "frequency_ranking" => false
      },
      "warmups" => warmups,
      "measurements" => measured,
      "median_lookups_per_second" => median(rates)
    }
  end

  def run(arguments)
    raise "usage: tools/benchmark-p02-fallback" unless arguments.empty?

    puts JSON.pretty_generate(report)
  rescue P02Fallback::InvalidTable, P02Fallback::InvalidInput, RuntimeError => error
    warn "P02_FALLBACK_BENCHMARK_FAIL: #{error.message}"
    exit 1
  end
end
