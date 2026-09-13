# frozen_string_literal: true

require "fileutils"
require "digest"
require "open3"

module P13RustcDriver
  class Failure < StandardError; end

  class CommandWindowGuard
    def initialize(
      invariant:,
      immutable_files:,
      immutable_trees: {},
      output_root:,
      ancestor_anchors:,
      expected_generated_files: nil
    )
      @invariant = invariant
      @immutable_files = immutable_files
      @immutable_trees = immutable_trees
      @output_root = File.expand_path(output_root)
      @ancestor_anchors = ancestor_anchors.map { |path| File.expand_path(path) }
      @expected_generated_files = expected_generated_files
      @active_output_identity = nil
      validate_output_root
      @invariant.call
      @immutable_identity = immutable_file_identity
      @immutable_tree_identity = immutable_tree_identity
      @ancestor_identity = ancestor_identity
      @stable_output_identity = output_tree_identity
      @expected_output_directories = output_directories(@stable_output_identity)
      validate_generated_files(@stable_output_identity, require_complete: false)
    end

    def before_command
      raise Failure, "P13 command-window guard is already active" if
        @active_output_identity

      validate_persistent_identity
      current = output_tree_identity
      validate_output_directory_layout(current)
      raise Failure, "P13 generated artifact changed between commands" unless
        current == @stable_output_identity
      validate_generated_files(current, require_complete: false)
      @active_output_identity = current
      true
    end

    def after_command
      raise Failure, "P13 command-window guard is not active" unless
        @active_output_identity

      expected_output = @active_output_identity
      @active_output_identity = nil
      validate_persistent_identity
      validate_existing_output_identity(expected_output)
      current = output_tree_identity
      validate_output_directory_layout(current)
      validate_generated_files(current, require_complete: false)
      @stable_output_identity = current
      true
    end

    def validate_now
      raise Failure, "P13 command-window guard remains active" if
        @active_output_identity

      validate_persistent_identity
      current = output_tree_identity
      validate_output_directory_layout(current)
      validate_generated_files(current, require_complete: true)
      raise Failure, "P13 generated artifact changed after command" unless
        current == @stable_output_identity
      true
    end

    private

    def validate_persistent_identity
      @invariant.call
      raise Failure, "P13 command-window immutable file identity changed" unless
        immutable_file_identity == @immutable_identity
      raise Failure, "P13 command-window immutable tree identity changed" unless
        immutable_tree_identity == @immutable_tree_identity
      raise Failure, "P13 command-window ancestor identity changed" unless
        ancestor_identity == @ancestor_identity
      true
    end

    def validate_output_root
      stat = File.lstat(@output_root)
      raise Failure, "P13 output root is not a private owned directory" unless
        stat.directory? && !stat.symlink? &&
        stat.uid == Process.euid && (stat.mode & 0o077).zero?
      true
    rescue Errno::ENOENT
      raise Failure, "P13 output root is missing"
    end

    def immutable_file_identity
      @immutable_files.keys.sort.to_h do |label|
        record = @immutable_files.fetch(label)
        path = File.expand_path(record.fetch(:path))
        stat = File.lstat(path)
        raise Failure, "P13 immutable file is not regular: #{label}" unless
          stat.file? && !stat.symlink? && stat.nlink == 1
        bytes = record.fetch(:bytes)
        sha256 = record.fetch(:sha256)
        raise Failure, "P13 immutable file size differs: #{label}" unless
          stat.size == bytes
        raise Failure, "P13 immutable file hash differs: #{label}" unless
          Digest::SHA256.file(path).hexdigest == sha256
        [label, path_identity(path, include_hash: true)]
      end
    rescue Errno::ENOENT
      raise Failure, "P13 immutable command-window file is missing"
    end

    def ancestor_identity
      anchors = @ancestor_anchors + @immutable_files.values.map do |record|
        File.dirname(File.expand_path(record.fetch(:path)))
      end
      anchors.concat(
        @immutable_trees.values.map do |record|
          File.expand_path(record.fetch(:root))
        end
      )
      anchors << File.dirname(@output_root)
      ancestor_paths(anchors).to_h do |path|
        [path, path_identity(path, include_hash: false)]
      end
    rescue Errno::ENOENT
      raise Failure, "P13 command-window ancestor is missing"
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

    def immutable_tree_identity
      @immutable_trees.keys.sort.to_h do |label|
        record = @immutable_trees.fetch(label)
        root = File.expand_path(record.fetch(:root))
        root_stat = File.lstat(root)
        raise Failure, "P13 immutable tree root is not a directory: #{label}" unless
          root_stat.directory? && !root_stat.symlink?

        paths = Dir.glob(
          File.join(root, "**", "*"),
          File::FNM_DOTMATCH
        ).reject { |path| [".", ".."].include?(File.basename(path)) }
          .sort_by(&:b)
        raise Failure, "P13 immutable tree contains a symlink: #{label}" if
          paths.any? { |path| File.symlink?(path) }
        raise Failure, "P13 immutable tree contains an unsupported path: #{label}" unless
          paths.all? { |path| File.file?(path) || File.directory?(path) }

        files = paths.select { |path| File.file?(path) }
        rows = files.map do |path|
          relative = path.delete_prefix("#{root}/")
          bytes = File.size(path)
          sha256 = Digest::SHA256.file(path).hexdigest
          [relative, bytes.to_s, sha256].join("\0")
        end
        raise Failure, "P13 immutable tree file count differs: #{label}" unless
          files.length == record.fetch(:file_count)
        raise Failure, "P13 immutable tree byte count differs: #{label}" unless
          files.sum { |path| File.size(path) } == record.fetch(:total_bytes)
        raise Failure, "P13 immutable tree manifest differs: #{label}" unless
          Digest::SHA256.hexdigest(rows.join("\n") + "\n") ==
            record.fetch(:inventory_sha256)

        identity = paths.to_h do |path|
          relative = path.delete_prefix("#{root}/")
          [relative, path_identity(path, include_hash: File.file?(path))]
        end
        [label, [path_identity(root, include_hash: false), identity]]
      end
    rescue Errno::ENOENT
      raise Failure, "P13 immutable command-window tree is missing"
    end

    def output_tree_identity
      validate_output_root
      output_paths.to_h do |path|
        stat = File.lstat(path)
        raise Failure, "P13 generated artifact is a symlink" if stat.symlink?
        raise Failure, "P13 generated artifact ownership differs" unless
          stat.uid == Process.euid
        if stat.file?
          raise Failure, "P13 generated artifact has another hard link" unless
            stat.nlink == 1
        elsif !stat.directory?
          raise Failure, "P13 generated artifact type is unsupported"
        end
        relative = path.delete_prefix("#{@output_root}/")
        [relative, path_identity(path, include_hash: stat.file?)]
      end
    end

    def validate_existing_output_identity(expected)
      expected.each do |relative, identity|
        path = File.join(@output_root, relative)
        raise Failure, "P13 generated artifact disappeared during command" unless
          File.exist?(path) || File.symlink?(path)
        raise Failure, "P13 generated artifact changed during command" unless
          path_identity(path, include_hash: identity.last.is_a?(String)) == identity
      end
      true
    end

    def validate_output_directory_layout(identity)
      raise Failure, "P13 generated output directory layout changed" unless
        output_directories(identity) == @expected_output_directories
      true
    end

    def output_directories(identity)
      identity.select { |_relative, fields| fields.first == "directory" }.keys
    end

    def validate_generated_files(identity, require_complete:)
      return true unless @expected_generated_files

      files = identity.select { |_relative, fields| fields.first == "file" }.keys
      unexpected = files - @expected_generated_files.keys
      raise Failure, "P13 generated artifact path is unexpected: #{unexpected.first}" unless
        unexpected.empty?
      missing = @expected_generated_files.keys - files
      if require_complete && !missing.empty?
        raise Failure, "P13 generated artifact is missing: #{missing.first}"
      end

      files.each do |relative|
        record = @expected_generated_files.fetch(relative)
        path = File.join(@output_root, relative)
        raise Failure, "P13 generated artifact size differs: #{relative}" unless
          File.size(path) == record.fetch(:bytes)
        raise Failure, "P13 generated artifact hash differs: #{relative}" unless
          Digest::SHA256.file(path).hexdigest == record.fetch(:sha256)
      end
      true
    end

    def output_paths
      Dir.glob(
        File.join(@output_root, "**", "*"),
        File::FNM_DOTMATCH
      ).reject { |path| [".", ".."].include?(File.basename(path)) }
        .sort_by(&:b)
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
      identity << Digest::SHA256.file(path).hexdigest if include_hash
      identity
    end
  end

  ROOT = File.expand_path("..", __dir__)
  TOOL_ROOT = File.join(ROOT, ".tools/rust-1.98.0")
  RUSTC = File.join(TOOL_ROOT, "bin/rustc")
  CLIPPY = File.join(TOOL_ROOT, "bin/clippy-driver")
  LINKER = File.join(
    TOOL_ROOT,
    "lib/rustlib/aarch64-apple-darwin/bin/gcc-ld/ld64.lld"
  )
  SDKROOT = "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
  TARGET = "aarch64-apple-darwin"

  GLOBAL_FLAGS = [
    "--target", TARGET,
    "--check-cfg", "cfg(chacha20_force_soft)",
    "--check-cfg", "cfg(chacha20_force_neon)",
    "--check-cfg", "cfg(chacha20_force_avx2)",
    "--check-cfg", "cfg(chacha20_force_sse2)",
    "--check-cfg", "cfg(poly1305_force_soft)",
    "--check-cfg",
    'cfg(curve25519_dalek_backend, values("auto", "fiat", "serial", "simd"))',
    "--check-cfg", 'cfg(curve25519_dalek_bits, values("32", "64"))',
    "--check-cfg", "cfg(nightly)",
    "--check-cfg", "cfg(allow_unused_unsafe)",
    "--check-cfg", "cfg(test)",
    "--cfg", "chacha20_force_soft",
    "--cfg", "poly1305_force_soft",
    "--cfg", 'curve25519_dalek_backend="serial"',
    "-C", "linker=#{LINKER}",
    "-C", "linker-flavor=ld",
    "-C", "debuginfo=0",
    "-C", "codegen-units=1"
  ].freeze

  PACKAGES = [
    {
      name: "cfg-if", version: "1.0.1", edition: "2018",
      dependencies: []
    },
    {
      name: "subtle", version: "2.6.1", edition: "2018",
      dependencies: []
    },
    {
      name: "typenum", version: "1.18.0", edition: "2018",
      dependencies: []
    },
    {
      name: "generic-array", version: "0.14.7", edition: "2015",
      features: %w[more_lengths],
      cfg: %w[relaxed_coherence],
      dependencies: %w[typenum]
    },
    {
      name: "crypto-common", version: "0.1.6", edition: "2018",
      dependencies: %w[generic-array typenum]
    },
    {
      name: "block-buffer", version: "0.10.4", edition: "2018",
      dependencies: %w[generic-array]
    },
    {
      name: "inout", version: "0.1.4", edition: "2021",
      dependencies: %w[generic-array]
    },
    {
      name: "zeroize", version: "1.8.1", edition: "2021",
      dependencies: []
    },
    {
      name: "cipher", version: "0.4.4", edition: "2021",
      features: %w[zeroize],
      dependencies: %w[crypto-common inout zeroize]
    },
    {
      name: "aead", version: "0.5.2", edition: "2021",
      dependencies: %w[crypto-common generic-array]
    },
    {
      name: "universal-hash", version: "0.5.1", edition: "2021",
      dependencies: %w[crypto-common subtle]
    },
    {
      name: "opaque-debug", version: "0.3.1", edition: "2018",
      dependencies: []
    },
    {
      name: "poly1305", version: "0.8.0", edition: "2021",
      source: "sources/poly1305",
      dependencies: %w[opaque-debug universal-hash]
    },
    {
      name: "chacha20", version: "0.9.1", edition: "2021",
      source: "sources/chacha20",
      features: %w[zeroize],
      dependencies: %w[cfg-if cipher]
    },
    {
      name: "chacha20poly1305", version: "0.10.1", edition: "2021",
      dependencies: %w[aead chacha20 cipher poly1305 zeroize]
    },
    {
      name: "digest", version: "0.10.7", edition: "2018",
      features: %w[block-buffer core-api default mac subtle],
      dependencies: %w[block-buffer crypto-common subtle]
    },
    {
      name: "blake2", version: "0.10.6", edition: "2018",
      dependencies: %w[digest]
    },
    {
      name: "curve25519-dalek", version: "4.1.3", edition: "2021",
      cfg: ['curve25519_dalek_bits="64"'],
      dependencies: %w[cfg-if subtle]
    },
    {
      name: "snow", version: "0.10.0", edition: "2024",
      source: "sources/snow",
      features: %w[
        blake2
        chacha20poly1305
        curve25519-dalek
        default-resolver
        use-blake2
        use-chacha20poly1305
        use-curve25519
      ],
      dependencies: %w[
        blake2
        chacha20poly1305
        curve25519-dalek
        subtle
      ]
    }
  ].freeze
  EXPECTED_PACKAGE_NAMES = %w[
    cfg-if
    subtle
    typenum
    generic-array
    crypto-common
    block-buffer
    inout
    zeroize
    cipher
    aead
    universal-hash
    opaque-debug
    poly1305
    chacha20
    chacha20poly1305
    digest
    blake2
    curve25519-dalek
    snow
  ].freeze
  PACKAGE_KEYS = %i[
    cfg
    dependencies
    edition
    features
    name
    source
    version
  ].freeze
  OUTPUT_DIRECTORY_NAMES = (
    PACKAGES.map { |package| package.fetch(:name) } +
    ["p13-snow-final-probe"]
  ).uniq.sort.freeze

  module_function

  def run(arguments)
    raise Failure, usage unless arguments.length == 2
    raise Failure, usage unless arguments.all? { |argument| argument.start_with?("/") }

    source_root = File.expand_path(arguments.fetch(0))
    output_root = File.expand_path(arguments.fetch(1))
    compile_and_test(source_root, output_root)
    puts "P13_DIRECT_RUSTC_BUILD_PASS"
    true
  end

  def compile_and_test(
    source_root,
    output_root,
    guard: nil,
    output_prepared: false
  )
    guard ||= lambda { true }
    validate_package_plan
    validate_roots(
      source_root,
      output_root,
      output_prepared: output_prepared
    )
    prepare_output_layout(output_root) unless output_prepared
    libraries = {}
    PACKAGES.each do |package|
      library = compile_package(
        package,
        source_root,
        output_root,
        libraries,
        guard: guard
      )
      libraries.fetch(package.fetch(:name)) { libraries[package.fetch(:name)] = library }
    end

    probe = File.join(source_root, "src/lib.rs")
    validate_regular_file(probe, "P13 probe source")
    test_binary = File.join(output_root, "p13-noise-probe-tests")
    probe_arguments = [
      probe,
      "--crate-name", "p13_snow_final_probe",
      "--edition", "2024",
      "--test",
      "-o", test_binary,
      "--extern", "snow=#{libraries.fetch('snow')}",
      "--extern", "poly1305=#{libraries.fetch('poly1305')}",
      "-L", "dependency=#{output_root}",
      "--remap-path-prefix", "#{source_root}=/p13-noise-source"
    ]
    invoke(RUSTC, probe_arguments, package_environment(
      name: "p13-snow-final-probe",
      version: "0.1.0",
      manifest_dir: source_root,
      output_root: output_root
    ), "P13 direct rustc probe test compilation", guard: guard)
    validate_regular_file(test_binary, "P13 probe test executable")
    invoke(
      test_binary,
      ["--test-threads=1"],
      runtime_environment,
      "P13 direct rustc probe tests",
      include_global_flags: false,
      guard: guard
    )

    clippy_arguments = probe_arguments.dup
    output_index = clippy_arguments.index("-o")
    clippy_arguments[output_index + 1] = File.join(output_root, "p13-noise-probe-clippy")
    clippy_arguments.concat(["--emit", "metadata", "-D", "warnings"])
    invoke(CLIPPY, clippy_arguments, package_environment(
      name: "p13-snow-final-probe",
      version: "0.1.0",
      manifest_dir: source_root,
      output_root: output_root
    ), "P13 direct clippy probe", guard: guard)
    guard.validate_now if guard.respond_to?(:validate_now)
    true
  end

  def compile_package(package, source_root, output_root, libraries, guard:)
    name = package.fetch(:name)
    crate_name = name.tr("-", "_")
    relative = package.fetch(:source, "vendor/#{name}-#{package.fetch(:version)}")
    package_root = File.join(source_root, relative)
    source = File.join(package_root, "src/lib.rs")
    validate_regular_file(source, "P13 #{name} source")
    output = File.join(output_root, "lib#{crate_name}.rlib")

    arguments = [
      source,
      "--crate-name", crate_name,
      "--edition", package.fetch(:edition),
      "--crate-type", "rlib",
      "--emit", "link",
      "-o", output,
      "-L", "dependency=#{output_root}",
      "--remap-path-prefix", "#{source_root}=/p13-noise-source",
      "--cap-lints", "allow"
    ]
    Array(package[:features]).sort.each do |feature|
      arguments.concat(["--cfg", %(feature="#{feature}")])
    end
    Array(package[:cfg]).each do |cfg|
      arguments.concat(["--cfg", cfg])
    end
    package.fetch(:dependencies).each do |dependency|
      dependency_crate = dependency.tr("-", "_")
      arguments.concat(
        ["--extern", "#{dependency_crate}=#{libraries.fetch(dependency)}"]
      )
    end

    invoke(RUSTC, arguments, package_environment(
      name: name,
      version: package.fetch(:version),
      manifest_dir: package_root,
      output_root: output_root
    ), "P13 direct rustc #{name}", guard: guard)
    validate_regular_file(output, "P13 #{name} library")
    output
  end

  def invoke(
    executable,
    arguments,
    environment,
    label,
    include_global_flags: true,
    guard: nil
  )
    guard ||= lambda { true }
    validate_regular_file(executable, label)
    command = [executable]
    command.concat(GLOBAL_FLAGS) if include_global_flags
    command.concat(arguments)
    run_guard_before(guard)
    begin
      stdout, stderr, status = Open3.capture3(
        environment,
        *command,
        unsetenv_others: true,
        chdir: "/"
      )
    ensure
      run_guard_after(guard)
    end
    return stdout if status.success?

    detail = (stdout + stderr).lines.last(40).join
    raise Failure, "#{label} failed: #{detail}"
  end

  def run_guard_before(guard)
    if guard.respond_to?(:before_command)
      guard.before_command
    else
      guard.call
    end
  end

  def run_guard_after(guard)
    if guard.respond_to?(:after_command)
      guard.after_command
    else
      guard.call
    end
  end

  def validate_package_plan(packages = PACKAGES)
    raise Failure, "P13 direct package plan is not an array" unless
      packages.is_a?(Array)

    names = packages.map { |package| package.fetch(:name) }
    raise Failure, "P13 direct package order or identity differs" unless
      names == EXPECTED_PACKAGE_NAMES && names.uniq.length == names.length

    available = []
    packages.each do |package|
      raise Failure, "P13 direct package fields differ" unless
        (package.keys - PACKAGE_KEYS).empty?
      name = package.fetch(:name)
      version = package.fetch(:version)
      edition = package.fetch(:edition)
      dependencies = package.fetch(:dependencies)
      source = package.fetch(:source, "vendor/#{name}-#{version}")
      raise Failure, "P13 direct package identity is unsafe" unless
        name.match?(/\A[a-z0-9][a-z0-9-]*\z/) &&
        version.match?(/\A[0-9]+\.[0-9]+\.[0-9]+\z/) &&
        %w[2015 2018 2021 2024].include?(edition)
      raise Failure, "P13 direct package source is unsafe" unless
        source.split("/").all? do |component|
          component.match?(/\A[a-zA-Z0-9][a-zA-Z0-9._-]*\z/)
        end
      raise Failure, "P13 direct dependency graph is not topological" unless
        dependencies.is_a?(Array) &&
        dependencies == dependencies.uniq &&
        dependencies.all? { |dependency| available.include?(dependency) }
      %i[features cfg].each do |key|
        values = Array(package[key])
        raise Failure, "P13 direct package #{key} differs" unless
          values.all? { |value| value.is_a?(String) && !value.empty? } &&
          values.uniq.length == values.length
      end
      available << name
    end
    true
  rescue KeyError => error
    raise Failure, "P13 direct package field is missing: #{error.key}"
  end

  def package_environment(name:, version:, manifest_dir:, output_root:)
    major, minor, patch = version.split(".", 3)
    runtime_environment.merge(
      "CARGO_CRATE_NAME" => name.tr("-", "_"),
      "CARGO_MANIFEST_DIR" => manifest_dir,
      "CARGO_PKG_AUTHORS" => "",
      "CARGO_PKG_DESCRIPTION" => "",
      "CARGO_PKG_HOMEPAGE" => "",
      "CARGO_PKG_LICENSE" => "",
      "CARGO_PKG_LICENSE_FILE" => "",
      "CARGO_PKG_NAME" => name,
      "CARGO_PKG_README" => "",
      "CARGO_PKG_REPOSITORY" => "",
      "CARGO_PKG_RUST_VERSION" => "",
      "CARGO_PKG_VERSION" => version,
      "CARGO_PKG_VERSION_MAJOR" => major,
      "CARGO_PKG_VERSION_MINOR" => minor,
      "CARGO_PKG_VERSION_PATCH" => patch,
      "CARGO_PKG_VERSION_PRE" => "",
      "OUT_DIR" => File.join(output_root, "out", name)
    ).tap do |environment|
      out_dir = environment.fetch("OUT_DIR")
      raise Failure, "P13 prepared OUT_DIR is missing: #{name}" unless
        File.directory?(out_dir) && !File.symlink?(out_dir)
    end
  end

  def runtime_environment
    {
      "HOME" => "/var/empty",
      "PATH" => "/usr/bin:/bin",
      "LC_ALL" => "C",
      "LANG" => "C",
      "TZ" => "UTC",
      "SOURCE_DATE_EPOCH" => "0",
      "DYLD_LIBRARY_PATH" => File.join(TOOL_ROOT, "lib"),
      "SDKROOT" => SDKROOT
    }
  end

  def validate_roots(source_root, output_root, output_prepared: false)
    raise Failure, "source root must be an absolute directory" unless
      source_root.start_with?("/") &&
      File.directory?(source_root) &&
      !File.symlink?(source_root)
    if output_prepared
      stat = File.lstat(output_root)
      raise Failure, "prepared output root is not a private directory" unless
        stat.directory? && !stat.symlink? &&
        stat.uid == Process.euid && (stat.mode & 0o077).zero?
      validate_output_layout(output_root)
    else
      raise Failure, "output root already exists" if File.exist?(output_root)

      FileUtils.mkdir_p(output_root, mode: 0o700)
    end
    true
  rescue Errno::ENOENT
    raise Failure, "prepared output root is missing"
  end

  def prepare_output_layout(output_root)
    out = File.join(output_root, "out")
    FileUtils.mkdir_p(out, mode: 0o700)
    File.chmod(0o700, out)
    OUTPUT_DIRECTORY_NAMES.each do |name|
      path = File.join(out, name)
      FileUtils.mkdir_p(path, mode: 0o700)
      File.chmod(0o700, path)
    end
    validate_output_layout(output_root)
  end

  def validate_output_layout(output_root)
    expected = ["out"] + OUTPUT_DIRECTORY_NAMES.map { |name| File.join("out", name) }
    actual = Dir.glob(
      File.join(output_root, "**", "*"),
      File::FNM_DOTMATCH
    ).reject { |path| [".", ".."].include?(File.basename(path)) }
      .map { |path| path.delete_prefix("#{output_root}/") }
      .sort_by(&:b)
    raise Failure, "prepared output layout differs" unless actual == expected.sort_by(&:b)
    expected.each do |relative|
      path = File.join(output_root, relative)
      stat = File.lstat(path)
      raise Failure, "prepared output directory differs: #{relative}" unless
        stat.directory? && !stat.symlink? &&
        stat.uid == Process.euid && (stat.mode & 0o077).zero?
    end
    true
  end

  def validate_regular_file(path, label)
    raise Failure, "#{label} is missing or not a regular file" unless
      File.file?(path) && !File.symlink?(path)
    true
  end

  def usage
    "usage: tools/p13-rustc-driver ABSOLUTE_SOURCE_ROOT ABSOLUTE_OUTPUT_ROOT"
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    P13RustcDriver.run(ARGV)
  rescue P13RustcDriver::Failure => error
    warn error.message
    exit 1
  end
end
