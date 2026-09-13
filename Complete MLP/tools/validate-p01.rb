# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "psych"

module P01Gate
  class Failure < StandardError; end

  PACKAGE_NAMES = %w[
    itoa
    memchr
    proc-macro2
    quote
    ryu
    serde
    serde_core
    serde_derive
    serde_json
    syn
    tinyvec
    tinyvec_macros
    unicode-ident
    unicode-normalization
    unicode-segmentation
  ].freeze

  CARGO_COMMANDS = [
    %w[fmt --all -- --check],
    %w[clippy --workspace --all-targets --all-features -- -D warnings],
    %w[test --workspace --all-features],
    %w[build --workspace --all-targets --all-features]
  ].freeze

  TOOL_HASHES = {
    "cargo" => "1de2e84c15443b70444eecfa959ff9099dd8c1a5606b6d9ef5bc0ea9c25bc7f9",
    "rustc" => "a11618eca0956a8aa4372c2bc898690b513cbdfa2cb9125b2a5301e360ed5b49",
    "rustfmt" => "ca9cbe15a4add6baf62d8ce177015c9c48f209ebcf4364416b1953142e8701f8",
    "cargo-clippy" => "bf89162b33afa0518da4004ab5f0e13f5b5cd143e6349a1720a003944910837b",
    "ld64.lld" => "910ef9bb07e4f137121da153c4267ebc3d3f30f88a9ee1e397f117402ec96640"
  }.freeze

  CORE_FORBIDDEN = {
    "environment" => /\bstd::env\b|\benv!\s*\(/,
    "filesystem" => /\bstd::fs\b|\bread_dir\s*\(/,
    "network" => /\bstd::net\b|TcpStream|UdpSocket/,
    "wall_time" => /SystemTime|Instant::now/,
    "entropy" => /\brand(?:om)?\b|thread_rng|getrandom/,
    "unordered_collection" => /HashMap|HashSet/,
    "global_mutable_state" => /static\s+mut|OnceLock|LazyLock/,
    "protocol_dependency" => /\bserde(?:_json)?\b/
  }.freeze

  PROTOCOL_FORBIDDEN = {
    "arbitrary_json_value" => /serde_json::Value/,
    "floating_point" => /\bf32\b|\bf64\b/,
    "unordered_collection" => /HashMap|HashSet/,
    "network" => /\bstd::net\b|TcpStream|UdpSocket/,
    "process" => /\bstd::process\b|Command::new/,
    "authority" => /\bcredential\b|\bpassword\b|service_data|execution_callback/
  }.freeze

  DATA_FORBIDDEN = {
    "network" => /\bstd::net\b|TcpStream|UdpSocket/,
    "process" => /\bstd::process\b|Command::new/,
    "ambient_environment" => /\bstd::env\b|\benv!\s*\(|\boption_env!\s*\(/,
    "wall_time" => /SystemTime|Instant::now/,
    "entropy" => /\brand(?:om)?\b|thread_rng|getrandom/,
    "unordered_collection" => /HashMap|HashSet/,
    "global_mutable_state" => /static\s+mut|OnceLock|LazyLock/
  }.freeze

  LANGUAGE_FORBIDDEN = {
    "network" => /\bstd::net\b|TcpStream|UdpSocket/,
    "process" => /\bstd::process\b|Command::new/,
    "ambient_environment" => /\bstd::env\b|\benv!\s*\(|\boption_env!\s*\(/,
    "filesystem" => /\bstd::fs\b|\bread_dir\s*\(/,
    "wall_time" => /SystemTime|Instant::now/,
    "entropy" => /\brand(?:om)?\b|thread_rng|getrandom/,
    "unordered_collection" => /HashMap|HashSet/,
    "global_mutable_state" => /static\s+mut|OnceLock|LazyLock/
  }.freeze

  EVALUATION_FORBIDDEN = {
    "network" => /\bstd::net\b|TcpStream|UdpSocket/,
    "subprocess" => /(?:std::)?process::Command|Command::new/,
    "ambient_environment" => /\bstd::env\b|\benv!\s*\(|\boption_env!\s*\(/,
    "wall_time" => /SystemTime|Instant::now/,
    "entropy" => /\brand(?:om)?\b|thread_rng|getrandom/,
    "unordered_collection" => /HashMap|HashSet/,
    "global_mutable_state" => /static\s+mut|OnceLock|LazyLock/
  }.freeze

  DATA_SCHEMA_IDS = {
    "data-source-manifest-v1.schema.json" =>
      "https://nlu.local/schemas/data-source-manifest-v1.schema.json",
    "data-stage-manifest-v1.schema.json" =>
      "https://nlu.local/schemas/data-stage-manifest-v1.schema.json",
    "data-package-manifest-v1.schema.json" =>
      "https://nlu.local/schemas/data-package-manifest-v1.schema.json",
    "lexicon-entry-v1.schema.json" =>
      "https://nlu.local/schemas/lexicon-entry-v1.schema.json",
    "lexicon-package-manifest-v1.schema.json" =>
      "https://nlu.local/schemas/lexicon-package-manifest-v1.schema.json",
    "morphology-evaluation-manifest-v1.schema.json" =>
      "https://nlu.local/schemas/morphology-evaluation-manifest-v1.schema.json",
    "morphology-evaluation-report-v1.schema.json" =>
      "https://nlu.local/schemas/morphology-evaluation-report-v1.schema.json",
    "pos-evaluation-manifest-v1.schema.json" =>
      "https://nlu.local/schemas/pos-evaluation-manifest-v1.schema.json",
    "pos-evaluation-report-v1.schema.json" =>
      "https://nlu.local/schemas/pos-evaluation-report-v1.schema.json",
    "pos-model-manifest-v1.schema.json" =>
      "https://nlu.local/schemas/pos-model-manifest-v1.schema.json",
    "pos-split-manifest-v1.schema.json" =>
      "https://nlu.local/schemas/pos-split-manifest-v1.schema.json"
  }.freeze

  module_function

  def run(arguments)
    root = File.expand_path("..", __dir__)
    no_cargo = arguments.delete("--no-cargo")
    raise Failure, "usage: tools/validate-p01 [--no-cargo]" unless arguments.empty?

    validate(root, run_cargo: !no_cargo)
    puts "P01_GATE_PASS"
  rescue Failure => error
    warn "P01_GATE_FAIL: #{error.message}"
    exit 1
  end

  def validate(root, run_cargo:)
    validate_toolchain(root)
    ledger = safe_yaml(File.join(root, "docs/evidence/P01-DEPENDENCIES.yaml"))
    packages = validate_lock(root, ledger)
    validate_vendor(root, packages)
    validate_manifests(root)
    validate_distribution(root)
    validate_source_boundaries(root)
    validate_schemas(root)
    run_cargo_commands(root) if run_cargo
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

  def validate_toolchain(root)
    tool_root = File.join(root, ".tools/rust-1.98.0")
    paths = {
      "cargo" => File.join(tool_root, "bin/cargo"),
      "rustc" => File.join(tool_root, "bin/rustc"),
      "rustfmt" => File.join(tool_root, "bin/rustfmt"),
      "cargo-clippy" => File.join(tool_root, "bin/cargo-clippy"),
      "ld64.lld" => File.join(
        tool_root,
        "lib/rustlib/aarch64-apple-darwin/bin/gcc-ld/ld64.lld"
      )
    }
    paths.each do |name, path|
      raise Failure, "missing tool #{name}" unless File.file?(path) && !File.symlink?(path)
      actual = Digest::SHA256.file(path).hexdigest
      raise Failure, "tool hash mismatch: #{name}" unless actual == TOOL_HASHES.fetch(name)
    end

    version, status = Open3.capture2e(paths.fetch("rustc"), "--version")
    raise Failure, "rustc version command failed" unless status.success?
    raise Failure, "unexpected rustc version" unless version.strip == "rustc 1.98.0 (88d9e12ae 2026-08-18)"

    toolchain = File.binread(File.join(root, "rust-toolchain.toml"))
    raise Failure, "Rust channel is not exactly 1.98.0" unless toolchain.include?('channel = "1.98.0"')
  end

  def parse_lock(bytes)
    bytes.scan(/^\[\[package\]\]\n(.*?)(?=^\[\[package\]\]|\z)/m).each_with_object([]) do |match, packages|
      block = match.first
      name = block[/^name = "([^"]+)"$/, 1]
      version = block[/^version = "([^"]+)"$/, 1]
      checksum = block[/^checksum = "([0-9a-f]{64})"$/, 1]
      next if checksum.nil?

      packages << {"name" => name, "version" => version, "checksum" => checksum}
    end
  end

  def validate_lock(root, ledger)
    lock_packages = parse_lock(File.binread(File.join(root, "Cargo.lock")))
    records = ledger.fetch("packages")
    raise Failure, "dependency ledger packages are not an array" unless records.is_a?(Array)
    raise Failure, "dependency ledger package count differs" unless records.length == PACKAGE_NAMES.length

    ledger_names = records.map { |record| record.fetch("name") }
    raise Failure, "dependency ledger names differ" unless ledger_names.sort == PACKAGE_NAMES.sort
    raise Failure, "lockfile dependency names differ" unless
      lock_packages.map { |record| record.fetch("name") }.sort == PACKAGE_NAMES.sort

    records.each do |record|
      lock = lock_packages.find { |candidate| candidate.fetch("name") == record.fetch("name") }
      raise Failure, "missing lock package #{record.fetch('name')}" if lock.nil?
      raise Failure, "version mismatch #{record.fetch('name')}" unless
        lock.fetch("version") == record.fetch("version").to_s
      raise Failure, "archive checksum mismatch #{record.fetch('name')}" unless
        lock.fetch("checksum") == record.fetch("archive_sha256")
    end
    records
  rescue KeyError => error
    raise Failure, "dependency ledger missing key #{error.key}"
  end

  def validate_vendor(root, packages)
    expected_directories = packages.map { |record| "#{record.fetch('name')}-#{record.fetch('version')}" }
    actual_directories = Dir.children(File.join(root, "vendor")).sort
    raise Failure, "vendor directory set differs" unless actual_directories == expected_directories.sort

    packages.each do |record|
      directory = File.join(root, record.fetch("vendored_path"))
      checksum_path = File.join(directory, ".cargo-checksum.json")
      checksum = JSON.parse(File.binread(checksum_path))
      raise Failure, "package checksum mismatch #{record.fetch('name')}" unless
        checksum.fetch("package") == record.fetch("archive_sha256")
      verify_checksum_manifest(directory, checksum)

      record.fetch("license_files").each do |license|
        path = File.join(root, license.fetch("path"))
        raise Failure, "missing license #{license.fetch('path')}" unless File.file?(path)
        raise Failure, "license hash mismatch #{license.fetch('path')}" unless
          Digest::SHA256.file(path).hexdigest == license.fetch("sha256")
      end
    end
  rescue JSON::ParserError, KeyError => error
    raise Failure, "invalid vendor metadata: #{error.class}"
  end

  def verify_checksum_manifest(directory, checksum)
    checksum.fetch("files").each do |relative, expected|
      path = File.join(directory, relative)
      raise Failure, "missing vendored file #{path}" unless File.file?(path)
      raise Failure, "vendored file hash mismatch #{path}" unless
        Digest::SHA256.file(path).hexdigest == expected
    end
  end

  def validate_manifests(root)
    workspace = File.binread(File.join(root, "Cargo.toml"))
    raise Failure, "workspace edition differs" unless workspace.include?('edition = "2024"')
    raise Failure, "workspace rust-version differs" unless workspace.include?('rust-version = "1.98"')
    raise Failure, "workspace resolver differs" unless workspace.include?('resolver = "3"')
    raise Failure, "nlu-data is not a workspace member" unless
      workspace.include?('"crates/nlu-data"')
    raise Failure, "lang-ptbr is not a workspace member" unless
      workspace.include?('"crates/lang-ptbr"')
    raise Failure, "morphology-eval is not a workspace member" unless
      workspace.include?('"crates/morphology-eval"')
    raise Failure, "pos-eval is not a workspace member" unless
      workspace.include?('"crates/pos-eval"')

    core = File.binread(File.join(root, "crates/nlu-core/Cargo.toml"))
    dependencies = core.split("[dependencies]", 2).fetch(1)
    raise Failure, "nlu-core has an external dependency" unless dependencies.strip.empty?

    protocol = File.binread(File.join(root, "crates/protocol/Cargo.toml"))
    expected = [
      'nlu-core = { path = "../nlu-core" }',
      "serde.workspace = true",
      "serde_json.workspace = true"
    ]
    expected.each do |line|
      raise Failure, "protocol dependency differs: #{line}" unless protocol.include?(line)
    end

    data = File.binread(File.join(root, "crates/nlu-data/Cargo.toml"))
    validate_exact_dependencies(
      data,
      "nlu-data",
      ["serde.workspace = true", "serde_json.workspace = true"]
    )

    language = File.binread(File.join(root, "crates/lang-ptbr/Cargo.toml"))
    validate_exact_dependencies(
      language,
      "lang-ptbr",
      [
        'nlu-core = { path = "../nlu-core" }',
        'nlu-data = { path = "../nlu-data" }',
        "unicode-normalization.workspace = true",
        "unicode-segmentation.workspace = true"
      ]
    )

    evaluation = File.binread(File.join(root, "crates/morphology-eval/Cargo.toml"))
    validate_exact_dependencies(
      evaluation,
      "morphology-eval",
      [
        'lang-ptbr = { path = "../lang-ptbr" }',
        'nlu-data = { path = "../nlu-data" }',
        "serde.workspace = true",
        "serde_json.workspace = true"
      ]
    )
    pos_evaluation = File.binread(File.join(root, "crates/pos-eval/Cargo.toml"))
    validate_exact_dependencies(
      pos_evaluation,
      "pos-eval",
      [
        'lang-ptbr = { path = "../lang-ptbr", optional = true }',
        'nlu-data = { path = "../nlu-data" }',
        "serde.workspace = true",
        "serde_json.workspace = true"
      ]
    )
    [core, protocol, data, language].each do |manifest|
      raise Failure, "production package depends on morphology-eval" if
        manifest.include?("morphology-eval")
      raise Failure, "production package depends on pos-eval" if
        manifest.include?("pos-eval")
    end
  rescue IndexError
    raise Failure, "crate manifest lacks a dependencies section"
  end

  def validate_exact_dependencies(manifest, package, expected)
    match = manifest.match(/^\[dependencies\]\s*\n(.*?)(?=^\[|\z)/m)
    raise Failure, "#{package} lacks a dependencies section" if match.nil?

    actual = match[1]
      .lines
      .map(&:strip)
      .reject { |line| line.empty? || line.start_with?("#") }
    raise Failure, "#{package} dependency set differs" unless actual == expected
  end

  def validate_distribution(root)
    manifest = safe_yaml(File.join(root, "docs/clean-room/DISTRIBUTION-LICENSES.yaml"))
    raise Failure, "distribution schema differs" unless manifest.fetch("schema_version") == 4
    rules = manifest.fetch("path_rules")
    raise Failure, "distribution rules are empty" unless rules.is_a?(Array) && !rules.empty?

    git = "/Library/Developer/CommandLineTools/usr/bin/git"
    output, status = Open3.capture2e(
      git,
      "-C",
      root,
      "ls-files",
      "--cached",
      "--others",
      "--exclude-standard"
    )
    raise Failure, "cannot enumerate distribution paths" unless status.success?
    paths = output.lines.map(&:strip).reject(&:empty?).sort
    raise Failure, "excluded steering input is distributable" if
      paths.include?("STEERING-NLU-PTBR-SOL-MAX.md")

    rules.each do |rule|
      raise Failure, "distribution rule has no origin" if rule.fetch("origin_id").to_s.empty?
      raise Failure, "distribution rule has ineligible license" if
        rule.fetch("license").to_s.empty? || rule.fetch("license") == "NOASSERTION"
      rule.fetch("license_files").each do |license|
        raise Failure, "distribution license file missing: #{license}" unless
          File.file?(File.join(root, license))
      end
      rule.fetch("path_prefixes").each do |prefix|
        raise Failure, "distribution prefix is not canonical: #{prefix}" unless
          prefix.end_with?("/") && !prefix.start_with?("/")
      end
    end

    paths.each do |path|
      matches = rules.select { |rule| distribution_rule_matches?(rule, path) }
      raise Failure, "unlicensed distribution path: #{path}" if matches.empty?
      raise Failure, "multiply licensed distribution path: #{path}" unless matches.length == 1
    end

    exact_paths = rules.flat_map { |rule| rule.fetch("paths") }
    extras = exact_paths - paths
    raise Failure, "distribution manifest names absent paths: #{extras.join(',')}" unless extras.empty?
    rules.each do |rule|
      rule.fetch("path_prefixes").each do |prefix|
        raise Failure, "distribution prefix matches no paths: #{prefix}" unless
          paths.any? { |path| path.start_with?(prefix) }
      end
    end
  rescue KeyError => error
    raise Failure, "distribution manifest missing key #{error.key}"
  end

  def distribution_rule_matches?(rule, path)
    rule.fetch("paths").include?(path) ||
      rule.fetch("path_prefixes").any? { |prefix| path.start_with?(prefix) }
  end

  def validate_source_boundaries(root)
    core_paths = Dir[File.join(root, "crates/nlu-core/{src,tests}/**/*.rs")].sort
    protocol_paths = Dir[File.join(root, "crates/protocol/{src,tests}/**/*.rs")].sort
    data_paths = Dir[File.join(root, "crates/nlu-data/src/**/*.rs")].sort
    language_paths = Dir[File.join(root, "crates/lang-ptbr/{src,tests}/**/*.rs")].sort
    evaluation_paths = (
      Dir[File.join(root, "crates/morphology-eval/src/**/*.rs")] +
      Dir[File.join(root, "crates/pos-eval/src/**/*.rs")]
    ).sort
    scan_forbidden(core_paths, CORE_FORBIDDEN, allowed: ["#![forbid(unsafe_code)]"])
    scan_forbidden(protocol_paths, PROTOCOL_FORBIDDEN, allowed: [])
    scan_forbidden(
      data_paths,
      DATA_FORBIDDEN,
      allowed: ["std::env::args_os().skip(1)", "std::process::exit(2)"]
    )
    scan_forbidden(language_paths, LANGUAGE_FORBIDDEN, allowed: [])
    scan_forbidden(
      evaluation_paths,
      EVALUATION_FORBIDDEN,
      allowed: [
        'env!("CARGO_MANIFEST_DIR")',
        "std::env::args_os()"
      ]
    )

    (core_paths + protocol_paths).select { |path| path.include?("/tests/") }.each do |path|
      bytes = File.binread(path)
      raise Failure, "technical test file lacks FIXTURE_TECNICA label: #{path}" unless
        bytes.include?("FIXTURE_TECNICA")
    end
  end

  def scan_forbidden(paths, patterns, allowed:)
    paths.each do |path|
      File.binread(path).each_line.with_index(1) do |line, number|
        next if allowed.any? { |text| line.include?(text) }

        patterns.each do |name, pattern|
          raise Failure, "#{name} boundary violation at #{path}:#{number}" if line.match?(pattern)
        end
      end
    end
  end

  def validate_schemas(root)
    request = JSON.parse(File.binread(File.join(root, "schemas/protocol-v1-request.schema.json")))
    response = JSON.parse(File.binread(File.join(root, "schemas/protocol-v1-response.schema.json")))
    [
      [request, "urn:nlu-ptbr:protocol:v1:request"],
      [response, "urn:nlu-ptbr:protocol:v1:response"]
    ].each do |schema, id|
      raise Failure, "schema ID differs" unless schema.fetch("$id") == id
      raise Failure, "schema version differs" unless schema.fetch("x-protocolVersion") == 1
      raise Failure, "schema wire limit differs" unless schema.fetch("x-maxWireBytes") == 65_536
      raise Failure, "schema permits top-level unknown fields" unless
        schema.fetch("additionalProperties") == false
    end

    DATA_SCHEMA_IDS.each do |name, id|
      schema = JSON.parse(File.binread(File.join(root, "schemas", name)))
      validate_data_schema(schema, id)
    end
  rescue JSON::ParserError, KeyError => error
    raise Failure, "invalid schema: #{error.class}"
  end

  def validate_data_schema(schema, id)
    raise Failure, "data schema dialect differs" unless
      schema.fetch("$schema") == "https://json-schema.org/draft/2020-12/schema"
    raise Failure, "data schema ID differs" unless schema.fetch("$id") == id
    raise Failure, "data schema root type differs" unless schema.fetch("type") == "object"
    raise Failure, "data schema permits top-level unknown fields" unless
      schema.fetch("additionalProperties") == false
    raise Failure, "data schema version differs" unless
      schema.fetch("properties").fetch("schema_version").fetch("const") == 1
  end

  def run_cargo_commands(root)
    tool_bin = File.join(root, ".tools/rust-1.98.0/bin")
    cargo = File.join(tool_bin, "cargo")
    environment = {
      "HOME" => "/var/empty",
      "PATH" => "#{tool_bin}:/usr/bin:/bin",
      "LC_ALL" => "C",
      "LANG" => "C",
      "TZ" => "UTC",
      "SOURCE_DATE_EPOCH" => "0",
      "CARGO_NET_OFFLINE" => "true",
      "CARGO_INCREMENTAL" => "0",
      "CARGO_TARGET_DIR" => File.join(root, "target/p01-gate"),
      "RUSTC" => File.join(tool_bin, "rustc"),
      "RUSTFMT" => File.join(tool_bin, "rustfmt")
    }

    CARGO_COMMANDS.each do |arguments|
      output, status = Open3.capture2e(environment, cargo, *arguments, chdir: root)
      next if status.success?

      warn output
      raise Failure, "Cargo gate failed: cargo #{arguments.join(' ')}"
    end
  end
end

P01Gate.run(ARGV) if $PROGRAM_NAME == __FILE__
