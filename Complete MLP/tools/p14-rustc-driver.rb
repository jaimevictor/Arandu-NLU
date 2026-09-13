# frozen_string_literal: true

require "digest"
require "fileutils"
require "open3"

module P14RustcDriver
  class Failure < StandardError; end

  class CommandWindowGuard
    def initialize(
      immutable_files:,
      immutable_trees:,
      immutable_paths:,
      source_trees:,
      ancestor_anchors:,
      output_root:,
      mutable_output_roots:
    )
      @immutable_files = immutable_files
      @immutable_trees = immutable_trees
      @immutable_paths = immutable_paths
      @source_trees = source_trees
      @ancestor_anchors = ancestor_anchors.map { |path| File.expand_path(path) }
      @output_root = File.expand_path(output_root)
      @mutable_output_roots = mutable_output_roots.map do |path|
        P14RustcDriver.output_relative_path(@output_root, path)
      end
      @active_command_files = nil
      @active_command_identity = nil
      @active_output_identity = nil
      @active_expected_outputs = nil
      @immutable_file_identity = immutable_file_identity
      @immutable_tree_identity = immutable_tree_identity
      @immutable_path_identity = immutable_path_identity
      @source_tree_identity = source_tree_identity
      @ancestor_identity = ancestor_identity
      @stable_output_identity = output_identity
    end

    def before_command(command_files: {}, expected_output_paths: [])
      raise Failure, "P14 command-window guard is already active" if
        @active_command_files

      validate_persistent_identity
      current_output = output_identity
      unless current_output == @stable_output_identity
        raise Failure, "P14 generated output changed between commands"
      end
      expected_outputs = expected_output_paths.map do |path|
        P14RustcDriver.output_relative_path(@output_root, path)
      end
      unless expected_outputs.uniq.length == expected_outputs.length
        raise Failure, "P14 command declares duplicate output paths"
      end
      if expected_outputs.any? do |relative|
        @mutable_output_roots.any? do |root|
          relative == root || relative.start_with?("#{root}/")
        end
      end
        raise Failure, "P14 declared output overlaps mutable scratch"
      end
      if expected_outputs.any? { |relative| current_output.key?(relative) }
        raise Failure, "P14 command output path already exists"
      end
      identity = command_file_identity(command_files)
      @active_command_files = command_files
      @active_command_identity = identity
      @active_output_identity = current_output
      @active_expected_outputs = expected_outputs
      true
    end

    def after_command
      raise Failure, "P14 command-window guard is not active" unless
        @active_command_files

      command_files = @active_command_files
      expected_identity = @active_command_identity
      expected_output = @active_output_identity
      expected_outputs = @active_expected_outputs
      @active_command_files = nil
      @active_command_identity = nil
      @active_output_identity = nil
      @active_expected_outputs = nil
      validate_persistent_identity
      unless command_file_identity(command_files) == expected_identity
        raise Failure, "P14 command-window executable identity changed"
      end
      current_output = output_identity
      validate_output_evolution(
        expected_output,
        current_output,
        expected_outputs
      )
      @stable_output_identity = current_output
      true
    end

    def validate_now
      raise Failure, "P14 command-window guard remains active" if
        @active_command_files

      validate_persistent_identity
      unless output_identity == @stable_output_identity
        raise Failure, "P14 generated output changed after command"
      end
      true
    end

    private

    def validate_persistent_identity
      unless immutable_file_identity == @immutable_file_identity
        raise Failure, "P14 command-window immutable file identity changed"
      end
      unless immutable_tree_identity == @immutable_tree_identity
        raise Failure, "P14 command-window immutable tree identity changed"
      end
      unless immutable_path_identity == @immutable_path_identity
        raise Failure, "P14 command-window SDK identity changed"
      end
      current_sources = source_tree_identity
      unless current_sources == @source_tree_identity
        changed_label =
          (@source_tree_identity.keys | current_sources.keys).find do |label|
            @source_tree_identity[label] != current_sources[label]
          end
        expected_tree = @source_tree_identity[changed_label]
        current_tree = current_sources[changed_label]
        changed_path = if expected_tree && current_tree
                         (expected_tree.keys | current_tree.keys).find do |path|
                           expected_tree[path] != current_tree[path]
                         end
                       end
        detail = [changed_label, changed_path].compact.join("/")
        raise Failure,
              "P14 command-window selected source identity changed: #{detail}"
      end
      current_ancestors = ancestor_identity
      unless current_ancestors == @ancestor_identity
        changed = (@ancestor_identity.keys | current_ancestors.keys).find do |path|
          @ancestor_identity[path] != current_ancestors[path]
        end
        raise Failure,
              "P14 command-window ancestor identity changed: #{changed}"
      end
      true
    end

    def immutable_file_identity
      @immutable_files.keys.sort.to_h do |label|
        record = @immutable_files.fetch(label)
        path = File.expand_path(record.fetch(:path))
        P14RustcDriver.validate_file_identity(path, record, label)
        [label, P14RustcDriver.path_identity(path, include_hash: true)]
      end
    rescue Errno::ENOENT
      raise Failure, "P14 immutable command-window file is missing"
    end

    def immutable_tree_identity
      @immutable_trees.keys.sort.to_h do |label|
        record = @immutable_trees.fetch(label)
        [
          label,
          P14RustcDriver.validated_tree_snapshot(
            record.fetch(:parent),
            record,
            label
          )
        ]
      end
    rescue Errno::ENOENT
      raise Failure, "P14 immutable command-window tree is missing"
    end

    def immutable_path_identity
      @immutable_paths.keys.sort.to_h do |label|
        record = @immutable_paths.fetch(label)
        path = File.expand_path(record.fetch(:path))
        P14RustcDriver.validate_bound_path(path, record, label)
        [
          label,
          P14RustcDriver.path_identity(
            path,
            include_hash: record.fetch(:type) == :file
          )
        ]
      end
    rescue Errno::ENOENT
      raise Failure, "P14 immutable SDK command-window path is missing"
    end

    def source_tree_identity
      @source_trees.keys.sort.to_h do |label|
        record = @source_trees.fetch(label)
        [
          label,
          P14RustcDriver.validated_tree_snapshot(
            record.fetch(:parent),
            record,
            label
          )
        ]
      end
    rescue Errno::ENOENT
      raise Failure, "P14 selected source command-window tree is missing"
    end

    def command_file_identity(command_files)
      command_files.keys.sort.to_h do |label|
        path = File.expand_path(command_files.fetch(label))
        P14RustcDriver.validate_regular_file(path, label)
        [label, P14RustcDriver.path_identity(path, include_hash: true)]
      end
    rescue Errno::ENOENT
      raise Failure, "P14 command-window executable is missing"
    end

    def ancestor_identity
      anchors = @ancestor_anchors.dup
      anchors.concat(
        @immutable_files.values.map do |record|
          File.dirname(File.expand_path(record.fetch(:path)))
        end
      )
      anchors.concat(
        @immutable_trees.values.map do |record|
          File.expand_path(record.fetch(:root))
        end
      )
      anchors.concat(
        @source_trees.values.map do |record|
          File.expand_path(record.fetch(:root))
        end
      )
      @immutable_paths.each_value do |record|
        anchors << File.dirname(File.expand_path(record.fetch(:path)))
        anchors << File.dirname(File.expand_path(record.fetch(:resolved_path))) if
          record[:resolved_path]
      end
      ancestor_paths(anchors).to_h do |path|
        [path, P14RustcDriver.ancestor_path_identity(path)]
      end
    rescue Errno::ENOENT
      raise Failure, "P14 command-window ancestor is missing"
    end

    def ancestor_paths(anchors)
      anchors.flat_map do |anchor|
        expanded = File.expand_path(anchor)
        real = File.realpath(expanded)
        [expanded, real].flat_map { |path| path_and_parents(path) }
      end.uniq.sort
    end

    def path_and_parents(path)
      paths = []
      current = path
      loop do
        paths << current
        parent = File.dirname(current)
        break if parent == current

        current = parent
      end
      paths
    end

    def output_identity
      snapshot = P14RustcDriver.output_tree_snapshot(@output_root)
      @mutable_output_roots.each do |relative|
        identity = snapshot[relative]
        raise Failure, "P14 mutable output root is missing" unless identity

        output_directory_identity(identity)
      end
      snapshot.each_with_object({}) do |(relative, identity), projected|
        mutable_root = @mutable_output_roots.find do |root|
          relative == root || relative.start_with?("#{root}/")
        end
        next if mutable_root && relative != mutable_root

        projected[relative] =
          mutable_root ? output_directory_identity(identity) : identity
      end
    end

    def validate_output_evolution(before, after, expected_outputs)
      allowed_directories = expected_outputs.flat_map do |relative|
        output_ancestor_paths(relative)
      end.uniq
      removed = before.keys - after.keys
      raise Failure, "P14 preexisting generated output disappeared" unless
        removed.empty?
      added = after.keys - before.keys
      unexpected = added - expected_outputs
      raise Failure, "P14 generated an undeclared output path" unless
        unexpected.empty?
      (before.keys & after.keys).each do |relative|
        if allowed_directories.include?(relative)
          unless output_directory_identity(before.fetch(relative)) ==
                 output_directory_identity(after.fetch(relative))
            raise Failure, "P14 generated output directory identity changed"
          end
        elsif before.fetch(relative) != after.fetch(relative)
          raise Failure, "P14 preexisting generated output changed"
        end
      end
      added.each do |relative|
        identity = after.fetch(relative)
        raise Failure, "P14 generated output is not a regular file" unless
          identity.fetch(0) == "file"
      end
      true
    end

    def output_ancestor_paths(relative)
      ancestors = []
      current = File.dirname(relative)
      loop do
        ancestors << current
        break if current == "."

        current = File.dirname(current)
      end
      ancestors
    end

    def output_directory_identity(identity)
      raise Failure, "P14 mutable output root is not a directory" unless
        identity.fetch(0) == "directory"

      identity[0, 6]
    end
  end

  ROOT = File.expand_path("..", __dir__)
  TARGET = "aarch64-apple-darwin"
  SDKROOT = "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
  REMAPPED_SOURCE = "/p14-source"
  REMAPPED_OUTPUT = "/p14-output"
  REMAPPED_TOOLCHAIN = "/p14-toolchain"
  CREDENTIAL_CANARY = "FIXTURE_TECNICA_CREDENTIAL_00000"
  NESTED_TEST_RESULT_EVIDENCE = {
    "run-nlu-server__lib" => Array.new(
      6,
      {
        passed: 1,
        ignored: 0,
        measured: 0,
        filtered_out: 28
      }.freeze
    ).freeze,
    "run-nlu-server__integration__runtime_contract" => [
      {
        passed: 1,
        ignored: 0,
        measured: 0,
        filtered_out: 10
      }.freeze
    ].freeze
  }.freeze

  P13_INPUT_IDENTITY = {
    toolchain_root: File.join(ROOT, ".tools/rust-1.98.0"),
    sdk_root: SDKROOT,
    files: {
      "bin/clippy-driver" => {
        bytes: 13_067_504,
        sha256: "6a1ccc398ad5466587424fd97625bad2a9296d4ef031a853b99eb80362f6e1e9",
        executable: true
      },
      "lib/rustlib/aarch64-apple-darwin/bin/gcc-ld/ld64.lld" => {
        bytes: 377_072,
        sha256: "910ef9bb07e4f137121da153c4267ebc3d3f30f88a9ee1e397f117402ec96640",
        executable: true
      },
      "lib/libLLVM.dylib" => {
        bytes: 139_564_208,
        sha256: "6da171ecd17bbe20b57b2e2d2e324b8fb2267117b504e864eb8b3012a71a6fec",
        executable: false
      },
      "lib/librustc_driver-4031c0ff8e88f5d1.dylib" => {
        bytes: 83_036_200,
        sha256: "275171d3d528b7f78bcad812a84658ec3bd756ce9792a329b6edefdf70884c63",
        executable: false
      },
      "bin/rustc" => {
        bytes: 412_504,
        sha256: "a11618eca0956a8aa4372c2bc898690b513cbdfa2cb9125b2a5301e360ed5b49",
        executable: true
      }
    }.freeze,
    sysroot: {
      path: "lib/rustlib/aarch64-apple-darwin/lib",
      file_count: 59,
      total_bytes: 146_749_407,
      inventory_sha256:
        "62ea43763461da5143769d101709c0f5dfa19b1407fc345c0b2070fc183bc7b6"
    }.freeze,
    sdk_settings: {
      path: "SDKSettings.json",
      sha256: "f8d005f09381389167f9e0aeaa169bc9e7dff162ef22ca2fd8e98df7ff1acafe"
    }.freeze
  }.freeze
  P14_AMBIENT_SDK_LINK_EVIDENCE = {
    classification: "P14_AMBIENT_HOST_BUILD_INPUT",
    sdk_root: SDKROOT,
    inputs: [
      {
        path: "SDKSettings.json",
        type: :file,
        bytes: 7_774,
        sha256:
          "f8d005f09381389167f9e0aeaa169bc9e7dff162ef22ca2fd8e98df7ff1acafe",
        mode: 0o644,
        nlink: 1
      },
      {
        path: "usr/lib/libSystem.tbd",
        type: :symlink,
        target: "libSystem.B.tbd",
        resolved_path: "usr/lib/libSystem.B.tbd",
        bytes: 15,
        sha256:
          "2e4a381a0a25f932a34fec49f9cb2ad1450d3a30ddea6aca26186238d5d1926b",
        mode: 0o755,
        nlink: 1
      },
      {
        path: "usr/lib/libc.tbd",
        type: :symlink,
        target: "libSystem.tbd",
        resolved_path: "usr/lib/libSystem.B.tbd",
        bytes: 13,
        sha256:
          "d3656b13d33cea9d8eee73f6cd8d72bca21daac1bc7a14c2ec3c9473482b36ff",
        mode: 0o755,
        nlink: 1
      },
      {
        path: "usr/lib/libm.tbd",
        type: :symlink,
        target: "libSystem.tbd",
        resolved_path: "usr/lib/libSystem.B.tbd",
        bytes: 13,
        sha256:
          "d3656b13d33cea9d8eee73f6cd8d72bca21daac1bc7a14c2ec3c9473482b36ff",
        mode: 0o755,
        nlink: 1
      },
      {
        path: "usr/lib/libSystem.B.tbd",
        type: :file,
        bytes: 334_178,
        sha256:
          "20cfce043f11a083e2eb6111efe3579919a8082fa4cc912a7bd839af2010ec57",
        mode: 0o644,
        nlink: 1
      }
    ].freeze
  }.freeze
  P14_INPUT_IDENTITY = P13_INPUT_IDENTITY.merge(
    sdk_link_closure: P14_AMBIENT_SDK_LINK_EVIDENCE.fetch(:inputs)
  ).freeze

  PACKAGES = [
    { name: "cfg-if", version: "1.0.1", edition: "2018", source: "vendor/cfg-if-1.0.1", dependencies: [] },
    { name: "subtle", version: "2.6.1", edition: "2018", source: "vendor/subtle-2.6.1", dependencies: [] },
    { name: "typenum", version: "1.18.0", edition: "2018", source: "vendor/typenum-1.18.0", dependencies: [] },
    { name: "generic-array", version: "0.14.7", edition: "2015", source: "vendor/generic-array-0.14.7", features: %w[more_lengths], cfg: %w[relaxed_coherence], dependencies: %w[typenum] },
    { name: "crypto-common", version: "0.1.6", edition: "2018", source: "vendor/crypto-common-0.1.6", dependencies: %w[generic-array typenum] },
    { name: "block-buffer", version: "0.10.4", edition: "2018", source: "vendor/block-buffer-0.10.4", dependencies: %w[generic-array] },
    { name: "inout", version: "0.1.4", edition: "2021", source: "vendor/inout-0.1.4", dependencies: %w[generic-array] },
    { name: "zeroize", version: "1.8.1", edition: "2021", source: "vendor/zeroize-1.8.1", dependencies: [] },
    { name: "cipher", version: "0.4.4", edition: "2021", source: "vendor/cipher-0.4.4", features: %w[zeroize], dependencies: %w[crypto-common inout zeroize] },
    { name: "aead", version: "0.5.2", edition: "2021", source: "vendor/aead-0.5.2", dependencies: %w[crypto-common generic-array] },
    { name: "universal-hash", version: "0.5.1", edition: "2021", source: "vendor/universal-hash-0.5.1", dependencies: %w[crypto-common subtle] },
    { name: "opaque-debug", version: "0.3.1", edition: "2018", source: "vendor/opaque-debug-0.3.1", dependencies: [] },
    { name: "poly1305", version: "0.8.0", edition: "2021", source: "vendor/poly1305-0.8.0", dependencies: %w[opaque-debug universal-hash] },
    { name: "chacha20", version: "0.9.1", edition: "2021", source: "vendor/chacha20-0.9.1", features: %w[zeroize], dependencies: %w[cfg-if cipher] },
    { name: "chacha20poly1305", version: "0.10.1", edition: "2021", source: "vendor/chacha20poly1305-0.10.1", dependencies: %w[aead chacha20 cipher poly1305 zeroize] },
    { name: "digest", version: "0.10.7", edition: "2018", source: "vendor/digest-0.10.7", features: %w[block-buffer core-api default mac subtle], dependencies: %w[block-buffer crypto-common subtle] },
    { name: "blake2", version: "0.10.6", edition: "2018", source: "vendor/blake2-0.10.6", dependencies: %w[digest] },
    { name: "curve25519-dalek", version: "4.1.3", edition: "2021", source: "vendor/curve25519-dalek-4.1.3", cfg: ['curve25519_dalek_bits="64"'], dependencies: %w[cfg-if subtle] },
    {
      name: "snow", version: "0.10.0", edition: "2024",
      source: "vendor/snow-0.10.0",
      features: %w[
        blake2 chacha20poly1305 curve25519-dalek default-resolver
        use-blake2 use-chacha20poly1305 use-curve25519
      ],
      dependencies: %w[blake2 chacha20poly1305 curve25519-dalek subtle]
    },
    { name: "unicode-ident", version: "1.0.24", edition: "2021", source: "vendor/unicode-ident-1.0.24", dependencies: [] },
    { name: "proc-macro2", version: "1.0.107", edition: "2021", source: "vendor/proc-macro2-1.0.107", features: %w[proc-macro], cfg: %w[wrap_proc_macro proc_macro_span_location proc_macro_span_file], dependencies: %w[unicode-ident] },
    { name: "quote", version: "1.0.47", edition: "2021", source: "vendor/quote-1.0.47", features: %w[proc-macro], dependencies: %w[proc-macro2] },
    { name: "syn", version: "2.0.119", edition: "2021", source: "vendor/syn-2.0.119", features: %w[clone-impls derive parsing printing proc-macro], dependencies: %w[proc-macro2 quote unicode-ident] },
    { name: "serde-derive", cargo_name: "serde_derive", crate_name: "serde_derive", version: "1.0.228", edition: "2021", source: "vendor/serde_derive-1.0.228", crate_type: "proc-macro", features: %w[default], dependencies: %w[proc-macro2 quote syn] },
    { name: "serde-core", cargo_name: "serde_core", crate_name: "serde_core", version: "1.0.228", edition: "2021", source: "vendor/serde_core-1.0.228", features: %w[result std], generated: "serde-core", dependencies: [] },
    { name: "serde", version: "1.0.228", edition: "2021", source: "vendor/serde-1.0.228", features: %w[default derive serde_derive std], cfg: %w[if_docsrs_then_no_serde_core], generated: "serde", dependencies: %w[serde-core serde-derive] },
    { name: "itoa", version: "1.0.18", edition: "2021", source: "vendor/itoa-1.0.18", dependencies: [] },
    { name: "memchr", version: "2.8.3", edition: "2021", source: "vendor/memchr-2.8.3", features: %w[alloc default std], dependencies: [] },
    { name: "ryu", version: "1.0.23", edition: "2021", source: "vendor/ryu-1.0.23", dependencies: [] },
    { name: "serde-json", cargo_name: "serde_json", crate_name: "serde_json", version: "1.0.145", edition: "2021", source: "vendor/serde_json-1.0.145", features: %w[default std], cfg: ['fast_arithmetic="64"'], dependencies: %w[itoa memchr ryu serde-core] },
    { name: "tinyvec-macros", cargo_name: "tinyvec_macros", crate_name: "tinyvec_macros", version: "0.1.1", edition: "2018", source: "vendor/tinyvec_macros-0.1.1", dependencies: [] },
    { name: "tinyvec", version: "1.12.0", edition: "2018", source: "vendor/tinyvec-1.12.0", features: %w[alloc default tinyvec_macros], dependencies: %w[tinyvec-macros] },
    { name: "unicode-normalization", crate_name: "unicode_normalization", version: "0.1.25", edition: "2018", source: "vendor/unicode-normalization-0.1.25", features: %w[default std], dependencies: %w[tinyvec] },
    { name: "unicode-segmentation", crate_name: "unicode_segmentation", version: "1.13.3", edition: "2018", source: "vendor/unicode-segmentation-1.13.3", dependencies: [] },
    { name: "nlu-core", version: "0.1.0", edition: "2024", source: "crates/nlu-core", dependencies: [] },
    { name: "nlu-data", version: "0.1.0", edition: "2024", source: "crates/nlu-data", dependencies: %w[serde serde-json] },
    { name: "lang-ptbr", version: "0.1.0", edition: "2024", source: "crates/lang-ptbr", dependencies: %w[nlu-core nlu-data unicode-normalization unicode-segmentation] },
    { name: "ha-catalog", version: "0.1.0", edition: "2024", source: "crates/ha-catalog", dependencies: %w[lang-ptbr nlu-core] },
    { name: "intent-engine", version: "0.1.0", edition: "2024", source: "crates/intent-engine", dependencies: %w[lang-ptbr nlu-core nlu-data serde serde-json] },
    { name: "plan-engine", version: "0.1.0", edition: "2024", source: "crates/plan-engine", dependencies: %w[ha-catalog intent-engine lang-ptbr nlu-core] },
    { name: "session-engine", version: "0.1.0", edition: "2024", source: "crates/session-engine", dependencies: %w[nlu-core plan-engine] },
    { name: "policy-engine", version: "0.1.0", edition: "2024", source: "crates/policy-engine", dependencies: %w[nlu-core session-engine] },
    { name: "protocol", version: "0.1.0", edition: "2024", source: "crates/protocol", dependencies: %w[nlu-core serde serde-json] },
    { name: "ha-adapter", version: "0.1.0", edition: "2024", source: "crates/ha-adapter", dependencies: [] },
    { name: "runtime-security", version: "0.1.0", edition: "2024", source: "crates/runtime-security", dependencies: [] },
    { name: "noise-channel", version: "0.1.0", edition: "2024", source: "crates/noise-channel", dependencies: %w[snow] },
    { name: "wyoming-runtime", version: "0.1.0", edition: "2024", source: "crates/wyoming-runtime", dependencies: %w[serde serde-json] },
    { name: "nlu-server", version: "0.1.0", edition: "2024", source: "crates/nlu-server", dependencies: %w[ha-catalog intent-engine nlu-core plan-engine policy-engine protocol session-engine] },
    { name: "addon-runtime", version: "0.1.0", edition: "2024", source: "crates/addon-runtime", dependencies: %w[ha-adapter ha-catalog nlu-core nlu-data nlu-server noise-channel policy-engine protocol runtime-security serde-json session-engine wyoming-runtime] }
  ].freeze

  OWNED = [
    {
      name: "ha-adapter",
      integrations: %w[bindings_and_ledger routing_contract schedule_snapshot_render],
      bins: [],
      harnessless: []
    },
    {
      name: "addon-runtime",
      integrations: %w[
        companion_wire helper_relay ipc_contract noise_stream pairing_bindings
        pairing_wire product_runtime_root supervisor_catalog supervisor_websocket
        wyoming_tcp
      ],
      bins: %w[companion-helper nlu-addon-adapter nlu-server],
      harnessless: []
    },
    {
      name: "runtime-security",
      integrations: %w[runtime_capability],
      bins: [],
      harnessless: %w[runtime_capability]
    },
    {
      name: "noise-channel",
      integrations: [],
      bins: [],
      harnessless: []
    },
    {
      name: "session-engine",
      integrations: %w[contract],
      bins: [],
      harnessless: [],
      test_dependencies: %w[ha-catalog intent-engine]
    },
    {
      name: "nlu-server",
      integrations: %w[runtime_contract],
      bins: [],
      harnessless: []
    },
    {
      name: "wyoming-runtime",
      integrations: %w[service_contract wire_contract],
      bins: [],
      harnessless: []
    }
  ].freeze

  PACKAGE_KEYS = %i[
    cargo_name cfg crate_name crate_type dependencies edition features generated
    name source version
  ].freeze
  EXPECTED_PACKAGE_NAMES = PACKAGES.map { |package| package.fetch(:name) }.freeze
  EXPECTED_PACKAGE_PLAN_SHA256 =
    "403eb0bd74e733ef027b339f90efb38b60136ff792a6e62c84ec8a2d121a6923"
      .freeze
  EXPECTED_OWNED_PLAN_SHA256 =
    "c16c305cef9a6b8f6a42649a4cfc12ad3bfaf9888be6b8ec90e7849c33c2e450"
      .freeze

  GLOBAL_CFG_FLAGS = [
    "--check-cfg", "cfg(chacha20_force_soft)",
    "--check-cfg", "cfg(chacha20_force_neon)",
    "--check-cfg", "cfg(chacha20_force_avx2)",
    "--check-cfg", "cfg(chacha20_force_sse2)",
    "--check-cfg", "cfg(poly1305_force_soft)",
    "--check-cfg",
    'cfg(curve25519_dalek_backend, values("auto", "fiat", "serial", "simd"))',
    "--check-cfg", 'cfg(curve25519_dalek_bits, values("32", "64"))',
    "--check-cfg", 'cfg(curve25519_dalek_diagnostics, values("build"))',
    "--check-cfg", "cfg(nightly)",
    "--check-cfg", "cfg(allow_unused_unsafe)",
    "--check-cfg", "cfg(fuzzing)",
    "--check-cfg", "cfg(test)",
    "--check-cfg", "cfg(feature, values(any()))",
    "--cfg", "chacha20_force_soft",
    "--cfg", "poly1305_force_soft",
    "--cfg", 'curve25519_dalek_backend="serial"'
  ].freeze

  module_function

  def run(arguments)
    raise Failure, usage unless arguments.length == 3
    raise Failure, usage unless arguments.all? { |argument| absolute_clean_path?(argument) }

    source_root, output_root, toolchain_root = arguments.map { |path| File.expand_path(path) }
    compile_and_test(source_root, output_root, toolchain_root)
    puts "P14_DIRECT_RUSTC_BUILD_PASS"
    true
  end

  def compile_and_test(source_root, output_root, toolchain_root, runner: nil)
    validate_package_plan
    validate_owned_plan
    validate_roots(source_root, output_root, toolchain_root)
    prepare_output(output_root)
    prepare_generated_sources(output_root)

    runner ||= CommandRunner.new(
      source_root: source_root,
      output_root: output_root,
      toolchain_root: toolchain_root,
      sdk_root: SDKROOT,
      input_identity: P14_INPUT_IDENTITY
    )
    validate_source_plan(source_root)
    libraries = compile_packages(source_root, output_root, runner)
    compile_owned_binaries(source_root, output_root, libraries, runner)
    test_failures = []
    summary = compile_and_run_tests(
      source_root,
      output_root,
      libraries,
      runner,
      test_failures
    )
    total_tests =
      summary.fetch(:passed) +
      summary.fetch(:ignored) +
      summary.fetch(:measured)
    puts(
      "P14_DIRECT_RUST_TEST_SUMMARY " \
      "binaries=#{summary.fetch(:binaries)} " \
      "harness_binaries=#{summary.fetch(:harness_binaries)} " \
      "tests=#{total_tests} " \
      "passed=#{summary.fetch(:passed)} " \
      "ignored=#{summary.fetch(:ignored)} " \
      "measured=#{summary.fetch(:measured)} " \
      "filtered_out=#{summary.fetch(:filtered_out)} " \
      "harnessless=#{summary.fetch(:harnessless)} " \
      "failed_binaries=#{summary.fetch(:failed_binaries)}"
    )
    clippy_failures = []
    lint_owned_libraries(
      source_root,
      output_root,
      libraries,
      runner,
      clippy_failures
    )
    lint_owned_binaries(
      source_root,
      output_root,
      libraries,
      runner,
      clippy_failures
    )
    lint_owned_tests(
      source_root,
      output_root,
      libraries,
      runner,
      clippy_failures
    )
    failures = test_failures + clippy_failures
    unless failures.empty?
      raise Failure,
            "P14 direct validation failures=" \
            "#{failures.length} test=#{test_failures.length} " \
            "clippy=#{clippy_failures.length}:\n" \
            "#{failures.join("\n---\n")}"
    end
    puts "P14_DIRECT_CLIPPY_PASS targets=#{owned_lint_target_count(source_root)}"
    runner.validate_now if runner.respond_to?(:validate_now)
    true
  end

  class CommandRunner
    attr_reader :commands

    def initialize(
      source_root:,
      output_root:,
      toolchain_root:,
      sdk_root: SDKROOT,
      input_identity: P14_INPUT_IDENTITY,
      selected_source_roots: nil,
      guard: nil
    )
      @source_root = source_root
      @output_root = output_root
      @toolchain_root = toolchain_root
      @sdk_root = sdk_root
      @input_identity = input_identity
      @rustc = File.join(toolchain_root, "bin/rustc")
      @clippy = File.join(toolchain_root, "bin/clippy-driver")
      @linker = File.join(
        toolchain_root,
        "lib/rustlib",
        TARGET,
        "bin/gcc-ld/ld64.lld"
      )
      @guard = guard || P14RustcDriver.build_command_window_guard(
        source_root,
        output_root,
        toolchain_root,
        sdk_root,
        input_identity,
        selected_source_roots: selected_source_roots
      )
      @commands = []
    end

    def rustc(arguments, environment, label)
      invoke(@rustc, arguments, environment, label, :rustc)
    end

    def clippy(arguments, environment, label)
      invoke(@clippy, arguments, environment, label, :clippy)
    end

    def test(executable, arguments, label)
      stdout = invoke(
        executable,
        arguments,
        runtime_environment,
        label,
        :test
      )
      [stdout, parse_test_result(stdout, label)]
    end

    def harnessless_test(executable, label)
      stdout = invoke(
        executable,
        [],
        runtime_environment,
        label,
        :test
      )
      [stdout, nil]
    end

    def validate_now
      @guard.validate_now
    end

    private

    def invoke(executable, arguments, environment, label, kind)
      P14RustcDriver.validate_command_executable(
        executable,
        kind: kind,
        rustc: @rustc,
        clippy: @clippy,
        output_root: @output_root,
        identity: command_identity(kind)
      )
      command = [executable]
      command.concat(compiler_flags) unless kind == :test
      command.concat(arguments)
      @commands << command.dup.freeze
      puts(
        "P14_DIRECT_COMMAND " \
        "index=#{@commands.length} tool=#{kind} target=#{machine_token(label)}"
      )
      effective_environment = runtime_environment.merge(environment)
      command_files =
        kind == :test ? { "P14 generated test executable" => executable } : {}
      working_directory = command_working_directory(kind, label)
      @guard.before_command(
        command_files: command_files,
        expected_output_paths: command_output_paths(arguments, kind)
      )
      begin
        stdout, stderr, status = Open3.capture3(
          effective_environment,
          *command,
          unsetenv_others: true,
          chdir: working_directory
        )
      ensure
        @guard.after_command
      end
      P14RustcDriver.validate_command_output(stdout, stderr, label)
      if status.success?
        return stdout
      end

      detail = (stdout + stderr).lines.last(60).join
      raise Failure, "#{label} failed: #{detail}"
    end

    def command_identity(kind)
      relative = case kind
                 when :rustc then "bin/rustc"
                 when :clippy then "bin/clippy-driver"
                 end
      relative ? @input_identity.fetch(:files).fetch(relative) : nil
    end

    def command_output_paths(arguments, kind)
      return [] if kind == :test

      indexes = arguments.each_index.select { |index| arguments[index] == "-o" }
      unless indexes.length == 1 && arguments[indexes.fetch(0) + 1]
        raise Failure, "P14 compiler command output plan differs"
      end
      output = File.expand_path(arguments.fetch(indexes.fetch(0) + 1))
      unless P14RustcDriver.within?(output, @output_root)
        raise Failure, "P14 compiler command output escapes the output root"
      end
      [output]
    end

    def command_working_directory(kind, label)
      return @source_root unless kind == :test

      directory = File.join(
        @output_root,
        "tmp",
        format("%03d-%s", @commands.length, machine_token(label))
      )
      if File.exist?(directory) || File.symlink?(directory)
        raise Failure, "P14 test working directory already exists"
      end
      Dir.mkdir(directory, 0o700)
      File.chmod(0o700, directory)
      P14RustcDriver.validate_canonical_directory(
        directory,
        "test working directory"
      )
      directory
    rescue SystemCallError
      raise Failure, "P14 test working directory could not be prepared"
    end

    def compiler_flags
      GLOBAL_CFG_FLAGS + [
        "--target", TARGET,
        "-C", "linker=#{@linker}",
        "-C", "linker-flavor=ld",
        "-C", "debuginfo=0",
        "-C", "codegen-units=1",
        "--remap-path-prefix", "#{@source_root}=#{REMAPPED_SOURCE}",
        "--remap-path-prefix", "#{@output_root}=#{REMAPPED_OUTPUT}",
        "--remap-path-prefix", "#{@toolchain_root}=#{REMAPPED_TOOLCHAIN}"
      ]
    end

    def runtime_environment
      P14RustcDriver.runtime_environment(
        @output_root,
        @toolchain_root,
        sdk_root: @sdk_root
      )
    end

    def parse_test_result(stdout, label)
      P14RustcDriver.parse_test_result(
        stdout,
        nested_evidence: NESTED_TEST_RESULT_EVIDENCE.fetch(label, [])
      )
    end

    def machine_token(label)
      P14RustcDriver.machine_token(label)
    end
  end

  def compile_packages(source_root, output_root, runner)
    libraries = {}
    PACKAGES.each do |package|
      source = File.join(source_root, package.fetch(:source), "src/lib.rs")
      output = package_output(output_root, package)
      arguments = crate_arguments(
        package,
        source,
        output,
        libraries,
        crate_type: package.fetch(:crate_type, "rlib"),
        emit: "link"
      )
      arguments.concat(["--cap-lints", "allow"])
      runner.rustc(
        arguments,
        package_environment(package, source_root, output_root),
        "lib-#{package.fetch(:name)}"
      )
      validate_regular_file(output, "P14 library output")
      libraries[package.fetch(:name)] = output
    end
    libraries
  end

  def lint_owned_libraries(
    source_root,
    output_root,
    libraries,
    runner,
    failures
  )
    OWNED.each do |owned|
      package = package_by_name(owned.fetch(:name))
      source = File.join(source_root, package.fetch(:source), "src/lib.rs")
      output = File.join(output_root, "clippy", "#{package.fetch(:name)}-lib.rmeta")
      arguments = crate_arguments(
        package,
        source,
        output,
        libraries,
        crate_type: "rlib",
        emit: "metadata"
      )
      arguments.concat(["-D", "warnings"])
      label = "clippy-#{package.fetch(:name)}-lib"
      run_clippy(failures, label) do
        runner.clippy(
          arguments,
          package_environment(package, source_root, output_root),
          label
        )
      end
    end
  end

  def compile_owned_binaries(source_root, output_root, libraries, runner)
    OWNED.each do |owned|
      package = package_by_name(owned.fetch(:name))
      owned.fetch(:bins).each do |name|
        source = File.join(source_root, package.fetch(:source), "src/bin/#{name}.rs")
        output = File.join(output_root, "bin", name)
        dependencies = package.fetch(:dependencies) + [package.fetch(:name)]
        arguments = target_arguments(
          source: source,
          crate_name: name.tr("-", "_"),
          edition: package.fetch(:edition),
          output: output,
          dependencies: dependencies,
          libraries: libraries,
          test_harness: false,
          cfg_test: false,
          emit: "link"
        )
        runner.rustc(
          arguments,
          package_environment(
            package,
            source_root,
            output_root,
            crate_name: name
          ),
          "bin-#{package.fetch(:name)}-#{name}"
        )
        validate_regular_file(output, "P14 binary output")
      end
    end
    true
  end

  def compile_and_run_tests(
    source_root,
    output_root,
    libraries,
    runner,
    failures
  )
    summary = {
      binaries: 0,
      harness_binaries: 0,
      passed: 0,
      ignored: 0,
      measured: 0,
      filtered_out: 0,
      harnessless: 0,
      failed_binaries: 0
    }
    test_targets(source_root).each do |target|
      package = package_by_name(target.fetch(:package))
      output = File.join(output_root, "tests", target.fetch(:id))
      arguments = target_arguments(
        source: target.fetch(:source),
        crate_name: target.fetch(:crate_name),
        edition: package.fetch(:edition),
        output: output,
        dependencies: target.fetch(:dependencies),
        libraries: libraries,
        test_harness: target.fetch(:harness),
        cfg_test: true,
        emit: "link"
      )
      runner.rustc(
        arguments,
        package_environment(
          package,
          source_root,
          output_root,
          crate_name: target.fetch(:crate_name)
        ),
        "test-build-#{target.fetch(:id)}"
      )
      validate_regular_file(output, "P14 test output")

      summary[:binaries] += 1
      if target.fetch(:harness)
        summary[:harness_binaries] += 1
        begin
          _stdout, result = runner.test(
            output,
            ["--test-threads=1"],
            "run-#{target.fetch(:id)}"
          )
        rescue Failure => error
          failures << error.message
          summary[:failed_binaries] += 1
          puts(
            "P14_RUST_TEST_RESULT " \
            "package=#{machine_token(target.fetch(:package))} " \
            "target=#{machine_token(target.fetch(:id))} " \
            "harness=true status=fail"
          )
          next
        end
        %i[passed ignored measured filtered_out].each do |key|
          summary[key] += result.fetch(key)
        end
        puts(
          "P14_RUST_TEST_RESULT " \
          "package=#{machine_token(target.fetch(:package))} " \
          "target=#{machine_token(target.fetch(:id))} " \
          "harness=true passed=#{result.fetch(:passed)} " \
          "ignored=#{result.fetch(:ignored)} " \
          "measured=#{result.fetch(:measured)} " \
          "filtered_out=#{result.fetch(:filtered_out)}"
        )
      else
        summary[:harnessless] += 1
        begin
          runner.harnessless_test(output, "run-#{target.fetch(:id)}")
        rescue Failure => error
          failures << error.message
          summary[:failed_binaries] += 1
          puts(
            "P14_RUST_TEST_RESULT " \
            "package=#{machine_token(target.fetch(:package))} " \
            "target=#{machine_token(target.fetch(:id))} " \
            "harness=false status=fail"
          )
          next
        end
        puts(
          "P14_RUST_TEST_RESULT " \
          "package=#{machine_token(target.fetch(:package))} " \
          "target=#{machine_token(target.fetch(:id))} " \
          "harness=false status=ok"
        )
      end
    end
    summary
  end

  def lint_owned_binaries(
    source_root,
    output_root,
    libraries,
    runner,
    failures
  )
    OWNED.each do |owned|
      package = package_by_name(owned.fetch(:name))
      owned.fetch(:bins).each do |name|
        source = File.join(source_root, package.fetch(:source), "src/bin/#{name}.rs")
        dependencies = package.fetch(:dependencies) + [package.fetch(:name)]
        output = File.join(
          output_root,
          "clippy",
          "#{package.fetch(:name)}-bin-#{name}.rmeta"
        )
        arguments = target_arguments(
          source: source,
          crate_name: name.tr("-", "_"),
          edition: package.fetch(:edition),
          output: output,
          dependencies: dependencies,
          libraries: libraries,
          test_harness: false,
          cfg_test: false,
          emit: "metadata"
        )
        arguments.concat(["-D", "warnings"])
        label = "clippy-#{package.fetch(:name)}-bin-#{name}"
        run_clippy(failures, label) do
          runner.clippy(
            arguments,
            package_environment(
              package,
              source_root,
              output_root,
              crate_name: name
            ),
            label
          )
        end
      end
    end
    true
  end

  def lint_owned_tests(
    source_root,
    output_root,
    libraries,
    runner,
    failures
  )
    test_targets(source_root).each do |target|
      package = package_by_name(target.fetch(:package))
      output = File.join(output_root, "clippy", "#{target.fetch(:id)}.rmeta")
      arguments = target_arguments(
        source: target.fetch(:source),
        crate_name: target.fetch(:crate_name),
        edition: package.fetch(:edition),
        output: output,
        dependencies: target.fetch(:dependencies),
        libraries: libraries,
        test_harness: target.fetch(:harness),
        cfg_test: true,
        emit: "metadata"
      )
      arguments.concat(["-D", "warnings"])
      label = "clippy-test-#{target.fetch(:id)}"
      run_clippy(failures, label) do
        runner.clippy(
          arguments,
          package_environment(
            package,
            source_root,
            output_root,
            crate_name: target.fetch(:crate_name)
          ),
          label
        )
      end
    end
    true
  end

  def run_clippy(failures, label)
    yield
    puts "P14_CLIPPY_RESULT target=#{machine_token(label)} status=pass"
    true
  rescue Failure => error
    puts "P14_CLIPPY_RESULT target=#{machine_token(label)} status=fail"
    failures << error.message
    false
  end

  def owned_lint_target_count(source_root)
    owned_lint_targets(source_root).length
  end

  def owned_lint_targets(source_root)
    library_targets = OWNED.map do |owned|
      "clippy-#{owned.fetch(:name)}-lib"
    end
    binary_targets = OWNED.flat_map do |owned|
      owned.fetch(:bins).map do |name|
        "clippy-#{owned.fetch(:name)}-bin-#{name}"
      end
    end
    test_lint_targets = test_targets(source_root).map do |target|
      "clippy-test-#{target.fetch(:id)}"
    end
    library_targets + binary_targets + test_lint_targets
  end

  def crate_arguments(package, source, output, libraries, crate_type:, emit:)
    arguments = [
      source,
      "--crate-name", package_crate_name(package),
      "--edition", package.fetch(:edition),
      "--crate-type", crate_type,
      "--emit", emit,
      "-o", output,
      "-L", "dependency=#{File.dirname(output).sub(%r{/clippy\z}, "/lib")}",
      "-C", "metadata=p14_#{package_crate_name(package)}"
    ]
    Array(package[:features]).sort.each do |feature|
      arguments.concat(["--cfg", %(feature="#{feature}")])
    end
    Array(package[:cfg]).each { |cfg| arguments.concat(["--cfg", cfg]) }
    add_externs(arguments, package.fetch(:dependencies), libraries)
    arguments
  end

  def target_arguments(
    source:,
    crate_name:,
    edition:,
    output:,
    dependencies:,
    libraries:,
    test_harness:,
    cfg_test:,
    emit:
  )
    arguments = [
      source,
      "--crate-name", crate_name,
      "--edition", edition,
      "--emit", emit,
      "-o", output,
      "-L", "dependency=#{File.join(File.dirname(File.dirname(output)), "lib")}",
      "-C", "metadata=p14_#{crate_name}"
    ]
    if test_harness
      arguments << "--test"
    else
      arguments.concat(["--crate-type", "bin"])
      arguments.concat(["--cfg", "test"]) if cfg_test
    end
    add_externs(arguments, dependencies, libraries)
    arguments
  end

  def add_externs(arguments, dependencies, libraries)
    dependencies.each do |dependency|
      dependency_package = package_by_name(dependency)
      arguments.concat(
        [
          "--extern",
          "#{package_crate_name(dependency_package)}=#{libraries.fetch(dependency)}"
        ]
      )
    end
  end

  def test_targets(source_root)
    OWNED.flat_map do |owned|
      package = package_by_name(owned.fetch(:name))
      package_root = File.join(source_root, package.fetch(:source))
      dependencies =
        package.fetch(:dependencies) + Array(owned[:test_dependencies])
      targets = [
        {
          package: package.fetch(:name),
          id: "#{package.fetch(:name)}__lib",
          crate_name: package_crate_name(package),
          source: File.join(package_root, "src/lib.rs"),
          dependencies: dependencies,
          harness: true
        }
      ]
      owned.fetch(:bins).each do |name|
        targets << {
          package: package.fetch(:name),
          id: "#{package.fetch(:name)}__bin__#{name}",
          crate_name: name.tr("-", "_"),
          source: File.join(package_root, "src/bin/#{name}.rs"),
          dependencies: dependencies + [package.fetch(:name)],
          harness: true
        }
      end
      owned.fetch(:integrations).each do |name|
        targets << {
          package: package.fetch(:name),
          id: "#{package.fetch(:name)}__integration__#{name}",
          crate_name: name.tr("-", "_"),
          source: File.join(package_root, "tests/#{name}.rs"),
          dependencies: dependencies + [package.fetch(:name)],
          harness: !owned.fetch(:harnessless).include?(name)
        }
      end
      targets
    end
  end

  def validate_package_plan(packages = PACKAGES)
    raise Failure, "P14 package plan is not an array" unless packages.is_a?(Array)
    names = packages.map { |package| package.fetch(:name) }
    raise Failure, "P14 package plan order or identity differs" unless
      names == EXPECTED_PACKAGE_NAMES && names.uniq.length == names.length
    raise Failure, "P14 package plan digest differs" unless
      package_plan_digest(packages) == EXPECTED_PACKAGE_PLAN_SHA256

    available = []
    packages.each do |package|
      raise Failure, "P14 package plan fields differ" unless
        (package.keys - PACKAGE_KEYS).empty?
      validate_identifier(package.fetch(:name), "package")
      validate_identifier(package_crate_name(package), "crate", underscore: true)
      validate_relative_path(package.fetch(:source), "package source")
      raise Failure, "P14 package version is unsafe" unless
        package.fetch(:version).match?(/\A[0-9]+\.[0-9]+\.[0-9]+\z/)
      raise Failure, "P14 package edition is unsupported" unless
        %w[2015 2018 2021 2024].include?(package.fetch(:edition))
      raise Failure, "P14 package crate type is unsupported" unless
        %w[rlib proc-macro].include?(package.fetch(:crate_type, "rlib"))
      dependencies = package.fetch(:dependencies)
      raise Failure, "P14 package dependency graph is not topological" unless
        dependencies.is_a?(Array) &&
        dependencies == dependencies.uniq &&
        dependencies.all? { |dependency| available.include?(dependency) }
      %i[features cfg].each do |key|
        values = Array(package[key])
        raise Failure, "P14 package #{key} differs" unless
          values.all? { |value| value.is_a?(String) && !value.empty? } &&
          values.uniq.length == values.length
      end
      available << package.fetch(:name)
    end

    closure = dependency_closure(
      packages,
      OWNED.map { |owned| owned.fetch(:name) }
    )
    raise Failure, "P14 package plan is not the exact owned dependency closure" unless
      closure.sort == names.sort
    true
  rescue KeyError => error
    raise Failure, "P14 package plan field is missing: #{error.key}"
  end

  def validate_owned_plan(owned = OWNED)
    raise Failure, "P14 owned target plan is not an array" unless owned.is_a?(Array)
    raise Failure, "P14 owned target plan digest differs" unless
      owned_plan_digest(owned) == EXPECTED_OWNED_PLAN_SHA256
    names = owned.map { |entry| entry.fetch(:name) }
    raise Failure, "P14 owned target identity differs" unless
      names == %w[
        ha-adapter addon-runtime runtime-security noise-channel session-engine
        nlu-server wyoming-runtime
      ]
    owned.each do |entry|
      %i[integrations bins harnessless test_dependencies].each do |key|
        next if key == :test_dependencies && !entry.key?(key)

        values = entry.fetch(key)
        raise Failure, "P14 owned #{key} plan differs" unless
          values.is_a?(Array) &&
          values == values.uniq &&
          values.all? { |value| value.match?(/\A[a-z0-9][a-z0-9_-]*\z/) }
      end
      raise Failure, "P14 harnessless target is not an integration test" unless
        (entry.fetch(:harnessless) - entry.fetch(:integrations)).empty?
      unless Array(entry[:test_dependencies]).all? do |dependency|
        EXPECTED_PACKAGE_NAMES.include?(dependency)
      end
        raise Failure, "P14 owned test dependency is absent from package plan"
      end
    end
    true
  rescue KeyError => error
    raise Failure, "P14 owned target field is missing: #{error.key}"
  end

  def validate_roots(
    source_root,
    output_root,
    toolchain_root,
    sdk_root: SDKROOT,
    input_identity: P14_INPUT_IDENTITY
  )
    [source_root, output_root, toolchain_root, sdk_root].each do |path|
      raise Failure, "P14 root path must be absolute and normalized" unless
        absolute_clean_path?(path)
    end
    validate_canonical_directory(source_root, "source root")
    validate_canonical_directory(toolchain_root, "toolchain root")
    validate_canonical_directory(sdk_root, "SDK root")
    raise Failure, "P14 output root already exists" if
      File.exist?(output_root) || File.symlink?(output_root)
    parent = File.dirname(output_root)
    validate_canonical_directory(parent, "output parent")
    [source_root, toolchain_root, sdk_root].each do |protected_root|
      raise Failure, "P14 output root overlaps an input root" if
        within?(output_root, protected_root) || within?(protected_root, output_root)
    end
    validate_toolchain_inputs(
      toolchain_root,
      sdk_root,
      input_identity
    )
    true
  end

  def validate_source_plan(source_root)
    PACKAGES.each do |package|
      root = File.join(source_root, package.fetch(:source))
      validate_canonical_directory(root, "package root #{package.fetch(:name)}")
      validate_regular_file(
        File.join(root, "src/lib.rs"),
        "package source #{package.fetch(:name)}"
      )
    end
    validate_local_manifests(source_root)
    validate_owned_sources(source_root)
    true
  end

  def validate_local_manifests(source_root)
    PACKAGES.select { |package| package.fetch(:source).start_with?("crates/") }
      .each do |package|
        manifest = File.join(source_root, package.fetch(:source), "Cargo.toml")
        validate_regular_file(manifest, "local manifest #{package.fetch(:name)}")
        actual = manifest_dependencies(File.binread(manifest))
        expected = package.fetch(:dependencies).map do |dependency|
          package_by_name(dependency).fetch(:name)
        end
        raise Failure, "P14 local dependency plan differs: #{package.fetch(:name)}" unless
          actual.sort == expected.sort
      end
    true
  end

  def validate_owned_sources(source_root)
    OWNED.each do |owned|
      package = package_by_name(owned.fetch(:name))
      root = File.join(source_root, package.fetch(:source))
      actual_bins = Dir.glob(File.join(root, "src/bin/*.rs"))
        .map { |path| File.basename(path, ".rs") }
        .sort
      actual_integrations = Dir.glob(File.join(root, "tests/*.rs"))
        .map { |path| File.basename(path, ".rs") }
        .sort
      raise Failure, "P14 owned binary target plan differs: #{package.fetch(:name)}" unless
        actual_bins == owned.fetch(:bins).sort
      raise Failure, "P14 owned integration target plan differs: #{package.fetch(:name)}" unless
        actual_integrations == owned.fetch(:integrations).sort
      actual_test_dependencies = manifest_dependencies(
        File.binread(File.join(root, "Cargo.toml")),
        section_name: "dev-dependencies"
      )
      unless actual_test_dependencies.sort ==
             Array(owned[:test_dependencies]).sort
        raise Failure,
              "P14 owned test dependency plan differs: #{package.fetch(:name)}"
      end
      (actual_bins.map { |name| File.join(root, "src/bin/#{name}.rs") } +
        actual_integrations.map { |name| File.join(root, "tests/#{name}.rs") })
        .each { |path| validate_regular_file(path, "owned target source") }
    end
    true
  end

  def validate_command_executable(
    executable,
    kind:,
    rustc:,
    clippy:,
    output_root:,
    identity:
  )
    expanded = File.expand_path(executable)
    raise Failure, "P14 Cargo execution is forbidden" if
      File.basename(expanded).downcase == "cargo"
    allowed = case kind
              when :rustc then expanded == File.expand_path(rustc)
              when :clippy then expanded == File.expand_path(clippy)
              when :test then within?(expanded, File.join(output_root, "tests"))
              else false
              end
    raise Failure, "P14 command executable is outside the direct allowlist" unless allowed
    validate_regular_file(expanded, "P14 command executable")
    if %i[rustc clippy].include?(kind)
      raise Failure, "P14 command executable identity is missing" unless identity

      validate_file_identity(
        expanded,
        identity,
        "P14 command executable"
      )
    elsif identity
      raise Failure, "P14 generated test executable has an external identity"
    end
    true
  end

  def prepare_output(output_root)
    Dir.mkdir(output_root, 0o700)
    %w[bin clippy home lib out tests tmp].each do |name|
      path = File.join(output_root, name)
      Dir.mkdir(path, 0o700)
      File.chmod(0o700, path)
    end
    PACKAGES.each do |package|
      path = File.join(output_root, "out", package.fetch(:name))
      Dir.mkdir(path, 0o700)
      File.chmod(0o700, path)
    end
    File.chmod(0o700, output_root)
    true
  end

  def prepare_generated_sources(output_root)
    serde_core = <<~RUST
      #[doc(hidden)]
      pub mod __private228 {
          #[doc(hidden)]
          pub use crate::private::*;
      }
    RUST
    serde = <<~RUST
      #[doc(hidden)]
      pub mod __private228 {
          #[doc(hidden)]
          pub use crate::private::*;
      }
      use serde_core::__private228 as serde_core_private;
    RUST
    File.binwrite(
      File.join(output_root, "out", "serde-core", "private.rs"),
      serde_core
    )
    File.binwrite(
      File.join(output_root, "out", "serde", "private.rs"),
      serde
    )
    true
  end

  def package_environment(package, source_root, output_root, crate_name: nil)
    version = package.fetch(:version)
    major, minor, patch = version.split(".", 3)
    runtime_environment(output_root, nil).merge(
      "CARGO_CRATE_NAME" => (crate_name || package_crate_name(package)).tr("-", "_"),
      "CARGO_MANIFEST_DIR" => File.join(
        source_root,
        package.fetch(:source)
      ),
      "CARGO_PKG_AUTHORS" => "",
      "CARGO_PKG_DESCRIPTION" => "",
      "CARGO_PKG_HOMEPAGE" => "",
      "CARGO_PKG_LICENSE" => "",
      "CARGO_PKG_LICENSE_FILE" => "",
      "CARGO_PKG_NAME" => package.fetch(:cargo_name, package.fetch(:name)),
      "CARGO_PKG_README" => "",
      "CARGO_PKG_REPOSITORY" => "",
      "CARGO_PKG_RUST_VERSION" => "",
      "CARGO_PKG_VERSION" => version,
      "CARGO_PKG_VERSION_MAJOR" => major,
      "CARGO_PKG_VERSION_MINOR" => minor,
      "CARGO_PKG_VERSION_PATCH" => patch,
      "CARGO_PKG_VERSION_PRE" => "",
      "OUT_DIR" => File.join(output_root, "out", package.fetch(:name))
    )
  end

  def runtime_environment(output_root, toolchain_root, sdk_root: SDKROOT)
    environment = {
      "HOME" => File.join(output_root, "home"),
      "PATH" => "/usr/bin:/bin",
      "LC_ALL" => "C",
      "LANG" => "C",
      "TZ" => "UTC",
      "SOURCE_DATE_EPOCH" => "0",
      "SDKROOT" => sdk_root,
      "TMPDIR" => File.join(output_root, "tmp")
    }
    if toolchain_root
      environment["DYLD_LIBRARY_PATH"] = [
        File.join(toolchain_root, "lib"),
        File.join(toolchain_root, "lib/rustlib", TARGET, "lib")
      ].join(":")
    end
    environment
  end

  def package_plan_digest(packages)
    rows = packages.map do |package|
      [
        package.fetch(:name),
        package.fetch(:cargo_name, package.fetch(:name)),
        package_crate_name(package),
        package.fetch(:version),
        package.fetch(:edition),
        package.fetch(:source),
        package.fetch(:crate_type, "rlib"),
        Array(package[:features]).join(","),
        Array(package[:cfg]).join(","),
        package.fetch(:generated, ""),
        package.fetch(:dependencies).join(",")
      ].join("\0")
    end
    Digest::SHA256.hexdigest(rows.join("\n") + "\n")
  end

  def owned_plan_digest(owned)
    rows = owned.map do |entry|
      [
        entry.fetch(:name),
        entry.fetch(:integrations).join(","),
        entry.fetch(:bins).join(","),
        entry.fetch(:harnessless).join(","),
        Array(entry[:test_dependencies]).join(",")
      ].join("\0")
    end
    Digest::SHA256.hexdigest(rows.join("\n") + "\n")
  end

  def dependency_closure(packages, roots)
    by_name = packages.to_h { |package| [package.fetch(:name), package] }
    visited = {}
    visit = lambda do |name|
      return if visited[name]

      package = by_name.fetch(name)
      visited[name] = true
      package.fetch(:dependencies).each { |dependency| visit.call(dependency) }
    end
    roots.each { |root| visit.call(root) }
    visited.keys
  rescue KeyError => error
    raise Failure, "P14 package closure is missing: #{error.key}"
  end

  def manifest_dependencies(bytes, section_name: "dependencies")
    section = nil
    dependencies = []
    bytes.each_line do |line|
      stripped = line.strip
      if (match = stripped.match(/\A\[([^\]]+)\]\z/))
        section = match[1]
        next
      end
      next unless section == section_name
      next if stripped.empty? || stripped.start_with?("#")

      match = stripped.match(/\A([a-zA-Z0-9_-]+)(?:\.workspace)?\s*=/)
      dependencies << match[1].tr("_", "-") if match
    end
    dependencies
  end

  def parse_test_result(stdout, nested_evidence: [])
    result_lines = stdout.lines.map(&:strip).select do |line|
      line.start_with?("test result:")
    end
    unless result_lines.length == nested_evidence.length + 1
      raise Failure,
            "P14 test binary did not emit exactly one machine-verifiable result"
    end
    results = result_lines.map { |line| parse_test_summary_line(line) }
    unless results.first(nested_evidence.length) == nested_evidence
      raise Failure, "P14 nested test companion evidence differs"
    end
    result = results.fetch(-1)
    unless result.fetch(:measured).zero? && result.fetch(:filtered_out).zero?
      raise Failure, "P14 test binary skipped selected tests"
    end
    result
  rescue ArgumentError
    raise Failure, "P14 test binary result is malformed"
  end

  def parse_test_summary_line(line)
    match = line.match(
      %r{\Atest result: ok\. ([0-9]+) passed; 0 failed; ([0-9]+) ignored; ([0-9]+) measured; ([0-9]+) filtered out; finished in [^;\r\n]+\z}
    )
    raise Failure, "P14 test binary result is not a machine-verifiable PASS" unless
      match

    {
      passed: Integer(match[1], 10),
      ignored: Integer(match[2], 10),
      measured: Integer(match[3], 10),
      filtered_out: Integer(match[4], 10)
    }
  end

  def validate_result_evidence(output, source_root)
    {
      rust: parse_rust_result_evidence(output, source_root),
      clippy_targets: parse_clippy_result_evidence(output, source_root)
    }
  end

  def parse_rust_result_evidence(output, source_root)
    expected_targets = test_targets(source_root)
    expected = expected_targets.to_h do |target|
      [target.fetch(:id), target]
    end
    raise Failure, "P14 Rust target plan contains duplicate identities" unless
      expected.length == expected_targets.length

    lines = output.lines.map(&:strip).select do |line|
      line.start_with?("P14_RUST_TEST_RESULT")
    end
    records = {}
    totals = {
      binaries: 0,
      harness_binaries: 0,
      passed: 0,
      ignored: 0,
      measured: 0,
      filtered_out: 0,
      harnessless: 0,
      failed_binaries: 0
    }
    lines.each do |line|
      fields = parse_machine_fields(line, "P14_RUST_TEST_RESULT")
      target_id = fields["target"]
      raise Failure, "P14 Rust result target is missing" unless target_id
      raise Failure, "P14 Rust result target is duplicated: #{target_id}" if
        records.key?(target_id)
      target = expected[target_id]
      raise Failure, "P14 Rust result contains an extra target: #{target_id}" unless
        target
      unless fields["package"] == target.fetch(:package)
        raise Failure, "P14 Rust result package identity differs: #{target_id}"
      end
      expected_harness = target.fetch(:harness) ? "true" : "false"
      unless fields["harness"] == expected_harness
        raise Failure, "P14 Rust result harness identity differs: #{target_id}"
      end

      if target.fetch(:harness)
        if fields.keys == %w[package target harness status]
          raise Failure, "P14 Rust result contains a failed or skipped target"
        end
        unless fields.keys ==
               %w[
                 package target harness passed ignored measured filtered_out
               ]
          raise Failure, "P14 Rust result fields are malformed"
        end
        counts = %w[passed ignored measured filtered_out].to_h do |key|
          [key, parse_machine_count(fields.fetch(key), "P14 Rust result")]
        end
        unless counts.fetch("measured").zero? &&
               counts.fetch("filtered_out").zero?
          raise Failure, "P14 Rust result contains skipped or filtered tests"
        end
        totals[:harness_binaries] += 1
        %w[passed ignored measured filtered_out].each do |key|
          totals[key.to_sym] += counts.fetch(key)
        end
      else
        unless fields.keys == %w[package target harness status] &&
               fields.fetch("status") == "ok"
          raise Failure, "P14 Rust result contains a failed or skipped target"
        end
        totals[:harnessless] += 1
      end
      totals[:binaries] += 1
      records[target_id] = true
    end
    missing = expected.keys - records.keys
    raise Failure, "P14 Rust result is missing a target: #{missing.first}" unless
      missing.empty?
    totals[:tests] =
      totals.fetch(:passed) +
      totals.fetch(:ignored) +
      totals.fetch(:measured)
    totals
  end

  def parse_clippy_result_evidence(output, source_root)
    expected_targets = owned_lint_targets(source_root)
    raise Failure, "P14 Clippy target plan contains duplicate identities" unless
      expected_targets.uniq.length == expected_targets.length
    expected = expected_targets.to_h { |target| [target, true] }
    lines = output.lines.map(&:strip).select do |line|
      line.start_with?("P14_CLIPPY_RESULT")
    end
    records = {}
    lines.each do |line|
      fields = parse_machine_fields(line, "P14_CLIPPY_RESULT")
      unless fields.keys == %w[target status]
        raise Failure, "P14 Clippy result fields are malformed"
      end
      target = fields.fetch("target")
      raise Failure, "P14 Clippy result target is duplicated: #{target}" if
        records.key?(target)
      raise Failure, "P14 Clippy result contains an extra target: #{target}" unless
        expected.key?(target)
      unless fields.fetch("status") == "pass"
        raise Failure, "P14 Clippy result contains a failed or skipped target"
      end
      records[target] = true
    end
    missing = expected.keys - records.keys
    raise Failure, "P14 Clippy result is missing a target: #{missing.first}" unless
      missing.empty?
    records.length
  end

  def parse_machine_fields(line, marker)
    prefix = "#{marker} "
    raise Failure, "#{marker} record is malformed" unless line.start_with?(prefix)

    pairs = line.delete_prefix(prefix).split.map do |token|
      match = token.match(/\A([a-z_]+)=([a-zA-Z0-9_.-]+)\z/)
      raise Failure, "#{marker} record is malformed" unless match

      [match[1], match[2]]
    end
    keys = pairs.map(&:first)
    raise Failure, "#{marker} record contains duplicate keys" unless
      keys.uniq.length == keys.length
    pairs.to_h
  end

  def parse_machine_count(value, label)
    raise Failure, "#{label} count is malformed" unless
      value.match?(/\A(?:0|[1-9][0-9]*)\z/)

    Integer(value, 10)
  end

  def package_output(output_root, package)
    extension = package.fetch(:crate_type, "rlib") == "proc-macro" ? "dylib" : "rlib"
    File.join(output_root, "lib", "lib#{package_crate_name(package)}.#{extension}")
  end

  def package_by_name(name)
    PACKAGES.find { |package| package.fetch(:name) == name } ||
      raise(Failure, "P14 package is absent from plan: #{name}")
  end

  def package_crate_name(package)
    package.fetch(:crate_name, package.fetch(:name).tr("-", "_"))
  end

  def validate_toolchain_inputs(toolchain_root, sdk_root, identity)
    raise Failure, "P14 toolchain root identity differs" unless
      toolchain_root == identity.fetch(:toolchain_root)
    raise Failure, "P14 SDK root identity differs" unless
      sdk_root == identity.fetch(:sdk_root)

    identity.fetch(:files).each do |relative, file_identity|
      validate_relative_path(relative, "toolchain input")
      validate_file_identity(
        File.join(toolchain_root, relative),
        file_identity,
        "P14 admitted toolchain file"
      )
    end
    validate_tree_identity(
      toolchain_root,
      identity.fetch(:sysroot),
      "P14 admitted target sysroot"
    )
    validate_sdk_link_closure(sdk_root, identity)
    true
  rescue KeyError => error
    raise Failure, "P14 input identity field is missing: #{error.key}"
  end

  def build_command_window_guard(
    source_root,
    output_root,
    toolchain_root,
    sdk_root,
    identity,
    selected_source_roots: nil
  )
    validate_toolchain_inputs(toolchain_root, sdk_root, identity)
    immutable_files = identity.fetch(:files).to_h do |relative, record|
      [
        "P14 admitted toolchain file #{relative}",
        record.merge(path: File.join(toolchain_root, relative))
      ]
    end
    sysroot = identity.fetch(:sysroot)
    immutable_trees = {
      "P14 admitted target sysroot" => sysroot.merge(
        parent: toolchain_root,
        root: File.join(toolchain_root, sysroot.fetch(:path))
      )
    }
    CommandWindowGuard.new(
      immutable_files: immutable_files,
      immutable_trees: immutable_trees,
      immutable_paths: sdk_link_inputs(sdk_root, identity),
      source_trees: selected_source_trees(
        source_root,
        selected_source_roots
      ),
      ancestor_anchors: [
        source_root,
        toolchain_root,
        sdk_root,
        File.dirname(output_root)
      ],
      output_root: output_root,
      mutable_output_roots: %w[home tmp].map do |name|
        File.join(output_root, name)
      end
    )
  rescue KeyError => error
    raise Failure, "P14 command-window identity field is missing: #{error.key}"
  end

  def selected_source_trees(source_root, selected_source_roots = nil)
    roots = selected_source_roots || PACKAGES.map do |package|
      File.join(source_root, package.fetch(:source))
    end
    expanded_roots = roots.map { |path| File.expand_path(path) }
    unless expanded_roots.uniq.length == expanded_roots.length &&
           expanded_roots.all? { |path| within?(path, source_root) }
      raise Failure, "P14 selected source root plan differs"
    end
    expanded_roots.to_h do |root|
      relative =
        root == source_root ? "." : root.delete_prefix("#{source_root}/")
      [
        "P14 selected source tree #{relative}",
        {
          parent: File.dirname(root),
          path: File.basename(root),
          root: root
        }
      ]
    end
  end

  def sdk_link_inputs(sdk_root, identity)
    settings = identity.fetch(:sdk_settings)
    unless settings.fetch(:path) == "SDKSettings.json"
      raise Failure, "P14 admitted SDK settings path differs"
    end
    entries = identity.fetch(:sdk_link_closure)
    expected_topology =
      P14_AMBIENT_SDK_LINK_EVIDENCE.fetch(:inputs).map do |entry|
        entry.values_at(:path, :type, :target, :resolved_path)
      end
    actual_topology = entries.map do |entry|
      entry.values_at(:path, :type, :target, :resolved_path)
    end
    unless actual_topology == expected_topology &&
           actual_topology.uniq.length == actual_topology.length
      raise Failure, "P14 SDK link closure topology differs"
    end
    entries.to_h do |entry|
      relative = entry.fetch(:path)
      validate_relative_path(relative, "SDK link input")
      record = entry.merge(path: File.join(sdk_root, relative))
      if relative == settings.fetch(:path) &&
         record.fetch(:sha256) != settings.fetch(:sha256)
        raise Failure, "P14 SDK settings identity differs from P13 evidence"
      end
      if entry[:resolved_path]
        record = record.merge(
          resolved_path: File.join(sdk_root, entry.fetch(:resolved_path))
        )
      end
      ["P14 SDK link input #{relative}", record]
    end
  end

  def validate_sdk_link_closure(sdk_root, identity)
    sdk_link_inputs(sdk_root, identity).each do |label, record|
      validate_bound_path(record.fetch(:path), record, label)
    end
    true
  end

  def validate_file_identity(path, identity, label)
    validate_regular_file(path, label)
    if identity.key?(:bytes) && File.size(path) != identity.fetch(:bytes)
      raise Failure, "#{label} size differs"
    end
    unless Digest::SHA256.file(path).hexdigest == identity.fetch(:sha256)
      raise Failure, "#{label} SHA-256 differs"
    end
    if identity.fetch(:executable, false) != File.executable?(path)
      raise Failure, "#{label} executable mode differs"
    end
    true
  end

  def validate_tree_identity(parent, identity, label)
    validated_tree_snapshot(parent, identity, label)
    true
  end

  def validated_tree_snapshot(parent, identity, label)
    root = identity.fetch(:root, File.join(parent, identity.fetch(:path)))
    validate_canonical_directory(root, label)
    paths = Dir.glob(
      File.join(root, "**", "*"),
      File::FNM_DOTMATCH
    ).reject { |path| [".", ".."].include?(File.basename(path)) }
      .sort_by(&:b)
    entries = paths.map { |path| [path, File.lstat(path)] }
    raise Failure, "#{label} contains a symlink" if
      entries.any? { |_path, stat| stat.symlink? }
    unless entries.all? { |_path, stat| stat.file? || stat.directory? }
      raise Failure, "#{label} contains an unsupported path"
    end
    files = entries.select { |_path, stat| stat.file? }
    unless files.all? { |_path, stat| stat.nlink == 1 }
      raise Failure, "#{label} contains a hard-linked file"
    end
    rows = files.map do |path, stat|
      [
        path.delete_prefix("#{root}/"),
        stat.size.to_s,
        Digest::SHA256.file(path).hexdigest
      ].join("\0")
    end
    manifest_fields = %i[file_count total_bytes inventory_sha256]
    present_fields = manifest_fields.select { |field| identity.key?(field) }
    unless present_fields.empty? || present_fields == manifest_fields
      raise Failure, "#{label} manifest identity is incomplete"
    end
    unless present_fields.empty?
      raise Failure, "#{label} file count differs" unless
        files.length == identity.fetch(:file_count)
      raise Failure, "#{label} byte count differs" unless
        files.sum { |_path, stat| stat.size } == identity.fetch(:total_bytes)
      unless Digest::SHA256.hexdigest(rows.join("\n") + "\n") ==
             identity.fetch(:inventory_sha256)
        raise Failure, "#{label} inventory differs"
      end
    end
    snapshot = {
      "." => path_identity(root, include_hash: false)
    }
    entries.each do |path, stat|
      relative = path.delete_prefix("#{root}/")
      snapshot[relative] = path_identity(path, include_hash: stat.file?)
    end
    snapshot
  end

  def output_tree_snapshot(output_root)
    root_stat = File.lstat(output_root)
    unless root_stat.directory? && !root_stat.symlink? &&
           root_stat.uid == Process.euid && (root_stat.mode & 0o077).zero?
      raise Failure, "P14 output root is not a private owned directory"
    end
    paths = Dir.glob(
      File.join(output_root, "**", "*"),
      File::FNM_DOTMATCH
    ).reject { |path| [".", ".."].include?(File.basename(path)) }
      .sort_by(&:b)
    snapshot = {
      "." => path_identity(output_root, include_hash: false)
    }
    paths.each do |path|
      stat = File.lstat(path)
      raise Failure, "P14 generated output contains a symlink" if stat.symlink?
      unless stat.file? || stat.directory?
        raise Failure, "P14 generated output type is unsupported"
      end
      unless stat.uid == Process.euid
        raise Failure, "P14 generated output ownership differs"
      end
      if stat.file? && stat.nlink != 1
        raise Failure, "P14 generated output has another hard link"
      end
      relative = path.delete_prefix("#{output_root}/")
      snapshot[relative] = path_identity(path, include_hash: stat.file?)
    end
    snapshot
  rescue Errno::ENOENT
    raise Failure, "P14 generated output path is missing"
  end

  def output_relative_path(output_root, path)
    expanded_root = File.expand_path(output_root)
    expanded = File.expand_path(path)
    unless expanded != expanded_root && within?(expanded, expanded_root)
      raise Failure, "P14 command output path escapes its root"
    end
    expanded.delete_prefix("#{expanded_root}/")
  end

  def validate_bound_path(path, record, label)
    stat = File.lstat(path)
    unless stat.size == record.fetch(:bytes)
      raise Failure, "#{label} size differs"
    end
    unless (stat.mode & 0o7777) == record.fetch(:mode)
      raise Failure, "#{label} mode differs"
    end
    unless stat.nlink == record.fetch(:nlink)
      raise Failure, "#{label} link count differs"
    end
    case record.fetch(:type)
    when :file
      unless stat.file? && !stat.symlink?
        raise Failure, "#{label} is not a regular single-link file"
      end
      if Digest::SHA256.file(path).hexdigest != record.fetch(:sha256)
        raise Failure, "#{label} SHA-256 differs"
      end
    when :symlink
      unless stat.symlink?
        raise Failure, "#{label} is not a single-link symlink"
      end
      target = File.readlink(path)
      unless target == record.fetch(:target)
        raise Failure, "#{label} symlink target differs"
      end
      unless Digest::SHA256.hexdigest(target) == record.fetch(:sha256)
        raise Failure, "#{label} symlink SHA-256 differs"
      end
      unless File.realpath(path) == record.fetch(:resolved_path)
        raise Failure, "#{label} resolved target differs"
      end
    else
      raise Failure, "#{label} has an unsupported identity type"
    end
    true
  rescue Errno::ENOENT
    raise Failure, "#{label} is missing"
  end

  def path_identity(path, include_hash:)
    stat = File.lstat(path)
    identity = [
      stat.ftype,
      stat.dev,
      stat.ino,
      stat.mode,
      stat.uid,
      stat.gid,
      stat.nlink,
      stat.size,
      stat.ctime.to_i,
      stat.ctime.nsec
    ]
    identity << File.readlink(path) if stat.symlink?
    identity << Digest::SHA256.file(path).hexdigest if include_hash
    identity
  end

  def ancestor_path_identity(path)
    stat = File.lstat(path)
    identity = [
      stat.ftype,
      stat.dev,
      stat.ino,
      stat.mode,
      stat.uid,
      stat.gid
    ]
    if stat.uid == Process.euid
      identity.concat(
        [
          stat.nlink,
          stat.size,
          stat.ctime.to_i,
          stat.ctime.nsec
        ]
      )
    end
    identity << File.readlink(path) if stat.symlink?
    identity
  end

  def validate_command_output(stdout, stderr, label)
    validate_no_credential_canary(stdout, label, "stdout")
    validate_no_credential_canary(stderr, label, "stderr")
    true
  end

  def validate_no_credential_canary(output, label, stream)
    return true unless output.include?(CREDENTIAL_CANARY)

    raise Failure, "#{label} emitted a credential canary on #{stream}"
  end

  def validate_canonical_directory(path, label)
    stat = File.lstat(path)
    raise Failure, "P14 #{label} is not a canonical directory" unless
      stat.directory? && !stat.symlink? && File.realpath(path) == path
    true
  rescue Errno::ENOENT
    raise Failure, "P14 #{label} is missing"
  end

  def validate_regular_file(path, label)
    stat = File.lstat(path)
    raise Failure, "#{label} is not a regular single-link file" unless
      stat.file? && !stat.symlink? && stat.nlink == 1
    true
  rescue Errno::ENOENT
    raise Failure, "#{label} is missing"
  end

  def validate_relative_path(path, label)
    components = path.split("/")
    raise Failure, "P14 #{label} is unsafe" unless
      !path.start_with?("/") &&
      components.all? { |component| component.match?(/\A[a-zA-Z0-9][a-zA-Z0-9._-]*\z/) }
    true
  end

  def validate_identifier(value, label, underscore: false)
    pattern = underscore ? /\A[a-z][a-z0-9_]*\z/ : /\A[a-z0-9][a-z0-9-]*\z/
    raise Failure, "P14 #{label} identity is unsafe" unless value.match?(pattern)
    true
  end

  def absolute_clean_path?(path)
    path.is_a?(String) &&
      path.start_with?("/") &&
      File.expand_path(path) == path
  end

  def within?(candidate, root)
    expanded_candidate = File.expand_path(candidate)
    expanded_root = File.expand_path(root)
    expanded_candidate == expanded_root ||
      expanded_candidate.start_with?("#{expanded_root}/")
  end

  def machine_token(value)
    token = value.to_s
    raise Failure, "P14 machine result token is unsafe" unless
      token.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_.-]*\z/)
    token
  end

  def usage
    "usage: tools/p14-rustc-driver " \
      "ABSOLUTE_SOURCE_ROOT ABSOLUTE_OUTPUT_ROOT ABSOLUTE_TOOLCHAIN_ROOT"
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    P14RustcDriver.run(ARGV)
  rescue P14RustcDriver::Failure => error
    warn error.message
    exit 1
  end
end
