# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "psych"

module P04Validation
  class Failure < StandardError; end

  ROOT = File.expand_path("..", __dir__)
  SOURCE_LEDGER = "docs/evidence/P04-SOURCES.yaml"
  ARTIFACTS = {
    "data/unicode/17.0.0/LICENSE-UNICODE" => {
      "bytes" => 1_995,
      "sha256" => "e7a93b009565cfce55919a381437ac4db883e9da2126fa28b91d12732bc53d96",
      "rows" => nil
    },
    "data/unicode/17.0.0/ucd/ReadMe.txt" => {
      "bytes" => 740,
      "sha256" => "9fe1a90bd32659d7953616283dc2bffaa165518aae9ace026040c42c559ba606",
      "rows" => nil
    },
    "data/unicode/17.0.0/ucd/NormalizationTest.txt" => {
      "bytes" => 2_827_429,
      "sha256" => "5019ffd530751a741900c849c0e010332f142a3612234639bd200b82138a87db",
      "rows" => 20_034
    },
    "data/unicode/17.0.0/ucd/auxiliary/GraphemeBreakTest.txt" => {
      "bytes" => 126_570,
      "sha256" => "e2d134d2c52919bace503ebb6a551c1855fe1a1faec18478c78fff254a1793ec",
      "rows" => 766
    },
    "data/unicode/17.0.0/ucd/auxiliary/WordBreakTest.txt" => {
      "bytes" => 322_136,
      "sha256" => "1de23a75f37904abc7d206239ee8d34f8fdf0fb4ab32a7174dfbabbde25419b2",
      "rows" => 1_944
    }
  }.freeze
  PACKAGES = {
    "tinyvec" => [
      "1.12.0",
      "bb4ebadaa0af04fab11ae01eb5f9fdb5f9c5b875506e210e71c07873528baa7f"
    ],
    "tinyvec_macros" => [
      "0.1.1",
      "1f3ccbac311fea05f86f61904b462b55fb3df8837a366dfc601a0161d0532f20"
    ],
    "unicode-normalization" => [
      "0.1.25",
      "5fd4f6878c9cb28d874b009da9e8d183b5abc80117c40bbd187a1fde336be6e8"
    ],
    "unicode-segmentation" => [
      "1.13.3",
      "c6f5d3c3b1bf09027a88a6bc961fc00497d651009560b5463668dc81b0fa87a8"
    ]
  }.freeze

  module_function

  def run(arguments)
    arguments = arguments.dup
    no_cargo = arguments.delete("--no-cargo")
    raise Failure, "usage: tools/validate-p04 [--no-cargo]" unless arguments.empty?

    validate(ROOT, run_cargo: !no_cargo)
    puts "P04_GATE_PASS"
  rescue Failure => error
    warn "P04_GATE_FAIL: #{error.message}"
    exit 1
  end

  def validate(root, run_cargo:)
    validate_sources(root)
    validate_dependency_closure(root)
    validate_contract(root)
    run_cargo_test(root) if run_cargo
    true
  end

  def safe_yaml(path)
    value = Psych.safe_load(
      File.binread(path),
      permitted_classes: [],
      permitted_symbols: [],
      aliases: false,
      filename: path
    )
    raise Failure, "YAML root is not a mapping: #{path}" unless value.is_a?(Hash)

    value
  rescue Psych::Exception => error
    raise Failure, "invalid YAML #{path}: #{error.class}"
  end

  def validate_sources(root)
    ledger = safe_yaml(File.join(root, SOURCE_LEDGER))
    raise Failure, "source ledger schema differs" unless ledger["schema_version"] == 1
    raise Failure, "source ledger status differs" unless ledger["status"] == "ADMITTED_P04"
    unicode = ledger.fetch("unicode_standard_source")
    raise Failure, "Unicode version differs" unless unicode["version"] == "17.0.0"
    raise Failure, "Unicode archive hash differs" unless
      unicode["archive_sha256"] ==
        "2066d1909b2ea93916ce092da1c0ee4808ea3ef8407c94b4f14f5b7eb263d28e"
    raise Failure, "Unicode license differs" unless unicode["license"] == "Unicode-3.0"

    listed = unicode.fetch("extracted_files").to_h do |record|
      [record.fetch("path"), record]
    end
    expected_listed = ARTIFACTS.keys - ["data/unicode/17.0.0/LICENSE-UNICODE"]
    raise Failure, "Unicode extracted path set differs" unless
      listed.keys.sort == expected_listed.sort

    ARTIFACTS.each do |relative, expected|
      verify_artifact(File.join(root, relative), expected)
      unless expected["rows"].nil?
        actual_rows = conformance_rows(File.binread(File.join(root, relative)))
        raise Failure, "conformance row count differs: #{relative}" unless
          actual_rows == expected["rows"]
      end
      next unless listed.key?(relative)

      record = listed.fetch(relative)
      raise Failure, "ledger byte count differs: #{relative}" unless
        record["bytes"] == expected["bytes"]
      raise Failure, "ledger hash differs: #{relative}" unless
        record["sha256"] == expected["sha256"]
      raise Failure, "ledger row count differs: #{relative}" unless
        record["conformance_rows"] == (expected["rows"] || 0)
    end
  rescue KeyError => error
    raise Failure, "source ledger missing key #{error.key}"
  end

  def verify_artifact(path, expected)
    raise Failure, "artifact is a symlink: #{path}" if File.symlink?(path)
    raise Failure, "artifact is not a regular file: #{path}" unless File.file?(path)
    raise Failure, "artifact byte count differs: #{path}" unless
      File.size(path) == expected.fetch("bytes")
    raise Failure, "artifact hash differs: #{path}" unless
      Digest::SHA256.file(path).hexdigest == expected.fetch("sha256")
  end

  def conformance_rows(bytes)
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    raise Failure, "conformance source is not UTF-8" unless text.valid_encoding?

    text.each_line.count do |line|
      stripped = line.strip
      !stripped.empty? && !stripped.start_with?("#", "@")
    end
  end

  def parse_lock(bytes)
    bytes.scan(/^\[\[package\]\]\n(.*?)(?=^\[\[package\]\]|\z)/m).to_h do |match|
      block = match.first
      name = block[/^name = "([^"]+)"$/, 1]
      version = block[/^version = "([^"]+)"$/, 1]
      checksum = block[/^checksum = "([0-9a-f]{64})"$/, 1]
      [name, [version, checksum]]
    end
  end

  def validate_dependency_closure(root)
    lock = parse_lock(File.binread(File.join(root, "Cargo.lock")))
    PACKAGES.each do |name, expected|
      raise Failure, "lock package differs: #{name}" unless lock[name] == expected
      directory = File.join(root, "vendor", "#{name}-#{expected.first}")
      checksum_path = File.join(directory, ".cargo-checksum.json")
      checksum = JSON.parse(File.binread(checksum_path))
      raise Failure, "vendor package hash differs: #{name}" unless
        checksum.fetch("package") == expected.last
      checksum.fetch("files").each do |relative, digest|
        path = File.join(directory, relative)
        raise Failure, "vendored file missing: #{name}/#{relative}" unless File.file?(path)
        raise Failure, "vendored file hash differs: #{name}/#{relative}" unless
          Digest::SHA256.file(path).hexdigest == digest
      end
      raise Failure, "dependency has a build script: #{name}" if
        File.exist?(File.join(directory, "build.rs"))
    end
  rescue JSON::ParserError, KeyError => error
    raise Failure, "invalid dependency metadata: #{error.class}"
  end

  def validate_contract(root)
    manifest = File.binread(File.join(root, "crates/lang-ptbr/Cargo.toml"))
    %w[
      nlu-core
      unicode-normalization.workspace
      unicode-segmentation.workspace
    ].each do |dependency|
      raise Failure, "lang-ptbr dependency missing: #{dependency}" unless
        manifest.include?(dependency)
    end

    limits = File.binread(File.join(root, "crates/lang-ptbr/src/limits.rs"))
    raise Failure, "Unicode version constant differs" unless
      limits.include?('pub const UNICODE_VERSION: &str = "17.0.0";')
    raise Failure, "normalization form differs" unless
      limits.include?('pub const NORMALIZATION_FORM: &str = "NFC";')

    tests = File.binread(File.join(root, "crates/lang-ptbr/src/conformance_tests.rs"))
    ARTIFACTS.each_key do |relative|
      next if relative.end_with?("LICENSE-UNICODE", "ReadMe.txt")

      path = relative.delete_prefix("data/")
      raise Failure, "conformance source is not included: #{relative}" unless
        tests.include?(path)
    end
  end

  def run_cargo_test(root)
    tool_bin = File.join(root, ".tools/rust-1.98.0/bin")
    environment = {
      "HOME" => "/var/empty",
      "PATH" => "#{tool_bin}:/usr/bin:/bin",
      "LC_ALL" => "C",
      "LANG" => "C",
      "TZ" => "UTC",
      "SOURCE_DATE_EPOCH" => "0",
      "CARGO_NET_OFFLINE" => "true",
      "CARGO_INCREMENTAL" => "0",
      "CARGO_TARGET_DIR" => File.join(root, "target/p04-gate"),
      "RUSTC" => File.join(tool_bin, "rustc")
    }
    output, status = Open3.capture2e(
      environment,
      File.join(tool_bin, "cargo"),
      "test",
      "-p",
      "lang-ptbr",
      "--all-features",
      chdir: root
    )
    return if status.success?

    warn output
    raise Failure, "lang-ptbr Cargo test failed"
  end
end

P04Validation.run(ARGV) if $PROGRAM_NAME == __FILE__
