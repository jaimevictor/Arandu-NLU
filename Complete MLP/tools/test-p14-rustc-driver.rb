# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "p14-rustc-driver"

module P14RustcDriverTest
  module_function

  class RecordingGuard
    attr_reader :before_calls, :after_calls, :validate_calls

    def initialize
      @before_calls = []
      @after_calls = 0
      @validate_calls = 0
    end

    def before_command(command_files: {}, expected_output_paths: [])
      @before_calls << command_files.keys.sort
      true
    end

    def after_command
      @after_calls += 1
      true
    end

    def validate_now
      @validate_calls += 1
      true
    end
  end

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure(message)
    yield
    raise "expected P14RustcDriver::Failure"
  rescue P14RustcDriver::Failure => error
    assert(error.message.include?(message), "failure message #{message.inspect}")
  end

  def deep_copy(value)
    Marshal.load(Marshal.dump(value))
  end

  def fixture_roots(directory)
    source = File.join(directory, "source")
    output = File.join(directory, "output")
    toolchain = File.join(directory, "toolchain")
    sdk = File.join(directory, "sdk")
    FileUtils.mkdir_p(source)
    FileUtils.mkdir_p(File.join(toolchain, "bin"))
    FileUtils.mkdir_p(
      File.join(
        toolchain,
        "lib/rustlib",
        P14RustcDriver::TARGET,
        "bin/gcc-ld"
      )
    )
    FileUtils.mkdir_p(
      File.join(toolchain, "lib/rustlib", P14RustcDriver::TARGET, "lib")
    )
    FileUtils.mkdir_p(File.join(sdk, "usr/lib"))
    file_contents = {
      "bin/rustc" => "#!/bin/sh\nexit 0\n",
      "bin/clippy-driver" => "#!/bin/sh\nexit 0\n",
      "lib/rustlib/#{P14RustcDriver::TARGET}/bin/gcc-ld/ld64.lld" =>
        "FIXTURE_TECNICA_LINKER",
      "lib/libLLVM.dylib" => "FIXTURE_TECNICA_LLVM",
      "lib/librustc_driver-4031c0ff8e88f5d1.dylib" =>
        "FIXTURE_TECNICA_RUSTC_DRIVER"
    }
    file_contents.each do |relative, contents|
      path = File.join(toolchain, relative)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, contents)
      mode = relative.start_with?("bin/") || relative.end_with?("ld64.lld")
      File.chmod(mode ? 0o700 : 0o600, path)
    end
    sysroot_file = File.join(
      toolchain,
      "lib/rustlib",
      P14RustcDriver::TARGET,
      "lib/libfixture.rlib"
    )
    File.binwrite(sysroot_file, "FIXTURE_TECNICA_SYSROOT")
    File.chmod(0o600, sysroot_file)
    settings = File.join(sdk, "SDKSettings.json")
    File.binwrite(settings, "{\"CanonicalName\":\"FIXTURE_TECNICA\"}\n")
    File.chmod(0o600, settings)
    sdk_payload = File.join(sdk, "usr/lib/libSystem.B.tbd")
    File.binwrite(sdk_payload, "FIXTURE_TECNICA_LIBSYSTEM")
    File.chmod(0o600, sdk_payload)
    {
      "libSystem.tbd" => "libSystem.B.tbd",
      "libc.tbd" => "libSystem.tbd",
      "libm.tbd" => "libSystem.tbd"
    }.each do |name, target|
      File.symlink(target, File.join(sdk, "usr/lib", name))
    end
    identity = fixture_input_identity(toolchain, sdk, file_contents.keys)
    [source, output, toolchain, sdk, identity]
  end

  def fixture_input_identity(toolchain, sdk, relative_files)
    files = relative_files.to_h do |relative|
      path = File.join(toolchain, relative)
      [
        relative,
        {
          bytes: File.size(path),
          sha256: Digest::SHA256.file(path).hexdigest,
          executable: File.executable?(path)
        }
      ]
    end
    sysroot_relative = "lib/rustlib/#{P14RustcDriver::TARGET}/lib"
    sysroot = File.join(toolchain, sysroot_relative)
    sysroot_files = Dir.glob(File.join(sysroot, "**", "*"))
      .select { |path| File.file?(path) }
      .sort_by(&:b)
    rows = sysroot_files.map do |path|
      [
        path.delete_prefix("#{sysroot}/"),
        File.size(path).to_s,
        Digest::SHA256.file(path).hexdigest
      ].join("\0")
    end
    {
      toolchain_root: toolchain,
      sdk_root: sdk,
      files: files,
      sysroot: {
        path: sysroot_relative,
        file_count: sysroot_files.length,
        total_bytes: sysroot_files.sum { |path| File.size(path) },
        inventory_sha256:
          Digest::SHA256.hexdigest(rows.join("\n") + "\n")
      },
      sdk_settings: {
        path: "SDKSettings.json",
        sha256: Digest::SHA256.file(
          File.join(sdk, "SDKSettings.json")
        ).hexdigest
      },
      sdk_link_closure:
        P14RustcDriver::P14_AMBIENT_SDK_LINK_EVIDENCE.fetch(:inputs).map do |entry|
          path = File.join(sdk, entry.fetch(:path))
          stat = File.lstat(path)
          topology = entry.select do |key, _value|
            %i[path type target resolved_path].include?(key)
          end
          bytes = stat.symlink? ? File.readlink(path) : File.binread(path)
          topology.merge(
            bytes: stat.size,
            sha256: Digest::SHA256.hexdigest(bytes),
            mode: stat.mode & 0o7777,
            nlink: stat.nlink
          )
        end
    }
  end

  def refresh_file_identity(identity, toolchain, relative)
    path = File.join(toolchain, relative)
    identity.fetch(:files)[relative] = {
      bytes: File.size(path),
      sha256: Digest::SHA256.file(path).hexdigest,
      executable: File.executable?(path)
    }
  end

  def with_guard_fixture
    Dir.mktmpdir("FIXTURE_TECNICA_p14_guard", "/private/tmp") do |directory|
      source, output, toolchain, sdk, identity = fixture_roots(directory)
      File.binwrite(
        File.join(source, "fixture.rs"),
        "FIXTURE_TECNICA_SOURCE"
      )
      Dir.mkdir(output, 0o700)
      File.chmod(0o700, output)
      %w[home lib tmp].each do |name|
        Dir.mkdir(File.join(output, name), 0o700)
      end
      guard = P14RustcDriver.build_command_window_guard(
        source,
        output,
        toolchain,
        sdk,
        identity,
        selected_source_roots: [source]
      )
      yield directory, source, output, toolchain, sdk, identity, guard
    end
  end

  def rust_result_evidence(source_root)
    P14RustcDriver.test_targets(source_root).map do |target|
      prefix =
        "P14_RUST_TEST_RESULT package=#{target.fetch(:package)} " \
        "target=#{target.fetch(:id)} harness=#{target.fetch(:harness)}"
      if target.fetch(:harness)
        "#{prefix} passed=1 ignored=0 measured=0 filtered_out=0\n"
      else
        "#{prefix} status=ok\n"
      end
    end.join
  end

  def clippy_result_evidence(source_root)
    P14RustcDriver.owned_lint_targets(source_root).map do |target|
      "P14_CLIPPY_RESULT target=#{target} status=pass\n"
    end.join
  end

  def direct_result_evidence(source_root)
    rust_result_evidence(source_root) + clippy_result_evidence(source_root)
  end

  def test_exact_plans_and_closure
    assert(P14RustcDriver.validate_package_plan, "exact package plan")
    assert(P14RustcDriver.validate_owned_plan, "exact owned plan")
    names = P14RustcDriver::PACKAGES.map { |package| package.fetch(:name) }
    assert(names.length == 49, "direct package closure count")
    assert(!names.include?("cargo"), "Cargo is not a package")
    source_root = File.expand_path("..", __dir__)
    targets = P14RustcDriver.test_targets(source_root)
    assert(targets.length == 28, "all direct test binaries")
    session_targets = targets.select do |target|
      target.fetch(:package) == "session-engine"
    end
    assert(
      session_targets.map { |target| target.fetch(:id) } ==
        %w[session-engine__lib session-engine__integration__contract],
      "session-engine library and integration tests"
    )
    assert(
      P14RustcDriver.owned_lint_target_count(source_root) == 38,
      "all direct Clippy targets"
    )
    assert(
      P14RustcDriver.selected_source_trees(source_root).length == 49,
      "complete selected package source trees"
    )
  end

  def test_package_plan_mutations_fail_closed
    changed = deep_copy(P14RustcDriver::PACKAGES)
    changed.fetch(0)[:name] = "changed"
    assert_failure("order or identity differs") do
      P14RustcDriver.validate_package_plan(changed)
    end

    changed = deep_copy(P14RustcDriver::PACKAGES)
    changed.fetch(0)[:features] = ["unreviewed"]
    assert_failure("digest differs") do
      P14RustcDriver.validate_package_plan(changed)
    end

    changed = deep_copy(P14RustcDriver::PACKAGES)
    changed.fetch(1)[:dependencies] = ["snow"]
    assert_failure("digest differs") do
      P14RustcDriver.validate_package_plan(changed)
    end

    changed = deep_copy(P14RustcDriver::PACKAGES)
    changed.fetch(2)[:source] = "../escape"
    assert_failure("digest differs") do
      P14RustcDriver.validate_package_plan(changed)
    end
  end

  def test_owned_target_plan_mutation_fails_closed
    changed = deep_copy(P14RustcDriver::OWNED)
    changed.fetch(0).fetch(:integrations) << "unreviewed"
    assert_failure("digest differs") do
      P14RustcDriver.validate_owned_plan(changed)
    end

    changed = deep_copy(P14RustcDriver::OWNED)
    changed.find do |entry|
      entry.fetch(:name) == "session-engine"
    end.fetch(:test_dependencies) << "unreviewed"
    assert_failure("digest differs") do
      P14RustcDriver.validate_owned_plan(changed)
    end
  end

  def test_root_path_safety
    Dir.mktmpdir("FIXTURE_TECNICA_p14_roots", "/private/tmp") do |directory|
      source, output, toolchain, sdk, identity = fixture_roots(directory)
      assert(
        P14RustcDriver.validate_roots(
          source,
          output,
          toolchain,
          sdk_root: sdk,
          input_identity: identity
        ),
        "separate canonical roots"
      )

      link = File.join(directory, "source-link")
      File.symlink(source, link)
      assert_failure("root path must be absolute and normalized") do
        P14RustcDriver.validate_roots(
          "#{source}/..",
          output,
          toolchain,
          sdk_root: sdk,
          input_identity: identity
        )
      end
      assert_failure("source root is not a canonical directory") do
        P14RustcDriver.validate_roots(
          link,
          output,
          toolchain,
          sdk_root: sdk,
          input_identity: identity
        )
      end
      assert_failure("overlaps an input root") do
        P14RustcDriver.validate_roots(
          source,
          File.join(source, "output"),
          toolchain,
          sdk_root: sdk,
          input_identity: identity
        )
      end
      Dir.mkdir(output)
      assert_failure("output root already exists") do
        P14RustcDriver.validate_roots(
          source,
          output,
          toolchain,
          sdk_root: sdk,
          input_identity: identity
        )
      end
    end
  end

  def test_p13_input_identity_substitutions_fail_closed
    Dir.mktmpdir("FIXTURE_TECNICA_p14_identity", "/private/tmp") do |directory|
      source, output, toolchain, sdk, identity = fixture_roots(directory)
      assert(
        P14RustcDriver.validate_roots(
          source,
          output,
          toolchain,
          sdk_root: sdk,
          input_identity: identity
        ),
        "fixture input identity"
      )

      identity.fetch(:files).each_key do |relative|
        path = File.join(toolchain, relative)
        original = File.binread(path)
        mode = File.stat(path).mode & 0o7777
        changed = original.dup
        changed.setbyte(0, changed.getbyte(0) ^ 1)
        File.binwrite(path, changed)
        File.chmod(mode, path)
        assert_failure("SHA-256 differs") do
          P14RustcDriver.validate_toolchain_inputs(toolchain, sdk, identity)
        end
        File.binwrite(path, original)
        File.chmod(mode, path)
      end

      sysroot = File.join(toolchain, identity.fetch(:sysroot).fetch(:path))
      sysroot_file = File.join(sysroot, "libfixture.rlib")
      original = File.binread(sysroot_file)
      changed = original.dup
      changed.setbyte(0, changed.getbyte(0) ^ 1)
      File.binwrite(sysroot_file, changed)
      assert_failure("inventory differs") do
        P14RustcDriver.validate_toolchain_inputs(toolchain, sdk, identity)
      end
      File.binwrite(sysroot_file, original)

      settings = File.join(sdk, "SDKSettings.json")
      original = File.binread(settings)
      changed = original.dup
      changed.setbyte(0, changed.getbyte(0) ^ 1)
      File.binwrite(settings, changed)
      assert_failure("SHA-256 differs") do
        P14RustcDriver.validate_toolchain_inputs(toolchain, sdk, identity)
      end
      File.binwrite(settings, original)

      sdk_payload = File.join(sdk, "usr/lib/libSystem.B.tbd")
      original = File.binread(sdk_payload)
      changed = original.dup
      changed.setbyte(0, changed.getbyte(0) ^ 1)
      File.binwrite(sdk_payload, changed)
      assert_failure("SHA-256 differs") do
        P14RustcDriver.validate_toolchain_inputs(toolchain, sdk, identity)
      end
      File.binwrite(sdk_payload, original)
      File.chmod(0o700, sdk_payload)
      assert_failure("mode differs") do
        P14RustcDriver.validate_toolchain_inputs(toolchain, sdk, identity)
      end
      File.chmod(0o600, sdk_payload)
      sdk_hardlink = File.join(sdk, "usr/lib/FIXTURE_TECNICA_hardlink")
      File.link(sdk_payload, sdk_hardlink)
      assert_failure("link count differs") do
        P14RustcDriver.validate_toolchain_inputs(toolchain, sdk, identity)
      end
      File.unlink(sdk_hardlink)

      sdk_link = File.join(sdk, "usr/lib/libm.tbd")
      File.unlink(sdk_link)
      File.symlink("libSysten.tbd", sdk_link)
      assert_failure("symlink target differs") do
        P14RustcDriver.validate_toolchain_inputs(toolchain, sdk, identity)
      end
      File.unlink(sdk_link)
      File.symlink("libSystem.tbd", sdk_link)
    end
  end

  def test_command_window_rejects_restored_input_substitutions
    with_guard_fixture do |_directory, _source, _output, toolchain, _sdk, _identity, guard|
      linker = File.join(
        toolchain,
        "lib/rustlib",
        P14RustcDriver::TARGET,
        "bin/gcc-ld/ld64.lld"
      )
      guard.before_command
      File.chmod(0o600, linker)
      File.chmod(0o700, linker)
      assert_failure("immutable file identity changed") { guard.after_command }
    end

    with_guard_fixture do |_directory, _source, _output, toolchain, _sdk, _identity, guard|
      runtime = File.join(toolchain, "lib/libLLVM.dylib")
      original = File.binread(runtime)
      changed = original.dup
      changed.setbyte(0, changed.getbyte(0) ^ 1)
      guard.before_command
      File.binwrite(runtime, changed)
      File.binwrite(runtime, original)
      assert_failure("immutable file identity changed") { guard.after_command }
    end

    with_guard_fixture do |_directory, _source, _output, toolchain, _sdk, _identity, guard|
      rustc = File.join(toolchain, "bin/rustc")
      extra_link = File.join(toolchain, "bin/FIXTURE_TECNICA_rustc_link")
      guard.before_command
      File.link(rustc, extra_link)
      File.unlink(extra_link)
      assert_failure("immutable file identity changed") { guard.after_command }
    end

    with_guard_fixture do |_directory, _source, _output, toolchain, _sdk, identity, guard|
      sysroot_file = File.join(
        toolchain,
        identity.fetch(:sysroot).fetch(:path),
        "libfixture.rlib"
      )
      guard.before_command
      File.chmod(0o700, sysroot_file)
      File.chmod(0o600, sysroot_file)
      assert_failure("immutable tree identity changed") { guard.after_command }
    end

    with_guard_fixture do |_directory, _source, _output, _toolchain, sdk, _identity, guard|
      payload = File.join(sdk, "usr/lib/libSystem.B.tbd")
      original = File.binread(payload)
      changed = original.dup
      changed.setbyte(0, changed.getbyte(0) ^ 1)
      guard.before_command
      File.binwrite(payload, changed)
      File.binwrite(payload, original)
      assert_failure("SDK identity changed") { guard.after_command }
    end

    with_guard_fixture do |_directory, _source, _output, _toolchain, sdk, _identity, guard|
      link = File.join(sdk, "usr/lib/libc.tbd")
      guard.before_command
      File.unlink(link)
      File.symlink("libSystem.B.tbd", link)
      File.unlink(link)
      File.symlink("libSystem.tbd", link)
      assert_failure("SDK identity changed") { guard.after_command }
    end

    with_guard_fixture do |directory, _source, _output, _toolchain, _sdk, _identity, guard|
      parked = "#{directory}-parked"
      guard.before_command
      File.rename(directory, parked)
      File.rename(parked, directory)
      assert_failure("ancestor identity changed") { guard.after_command }
    end

    with_guard_fixture do |_directory, _source, _output, _toolchain, _sdk, _identity, guard|
      guard.before_command
      Dir.mktmpdir("FIXTURE_TECNICA_p14_shared_ancestor", "/private/tmp") do
        # The root-owned shared ancestor may gain unrelated children.
      end
      assert(guard.after_command, "shared ancestor child churn is irrelevant")
    end
  end

  def test_command_runner_guards_every_command_kind
    Dir.mktmpdir("FIXTURE_TECNICA_p14_runner", "/private/tmp") do |directory|
      source, output, toolchain, sdk, identity = fixture_roots(directory)
      %w[clippy home lib tests tmp].each do |name|
        FileUtils.mkdir_p(File.join(output, name), mode: 0o700)
      end
      test_binary = File.join(output, "tests/fixture")
      File.binwrite(
        test_binary,
        "#!/bin/sh\n" \
        "printf '%s\\n' 'test result: ok. 1 passed; 0 failed; " \
        "0 ignored; 0 measured; 0 filtered out; finished in 0.01s'\n"
      )
      File.chmod(0o700, test_binary)
      guard = RecordingGuard.new
      runner = P14RustcDriver::CommandRunner.new(
        source_root: source,
        output_root: output,
        toolchain_root: toolchain,
        sdk_root: sdk,
        input_identity: identity,
        guard: guard
      )
      runner.rustc(
        ["-o", File.join(output, "lib/fixture.rlib")],
        {},
        "fixture-rustc"
      )
      runner.clippy(
        ["-o", File.join(output, "clippy/fixture.rmeta")],
        {},
        "fixture-clippy"
      )
      _stdout, result = runner.test(
        test_binary,
        ["--test-threads=1"],
        "fixture-test"
      )
      assert(result.fetch(:passed) == 1, "guarded test command result")
      assert(guard.before_calls.length == 3, "guard before every command")
      assert(guard.after_calls == 3, "guard after every command")
      assert(guard.before_calls.fetch(0).empty?, "rustc uses persistent closure")
      assert(guard.before_calls.fetch(1).empty?, "Clippy uses persistent closure")
      assert(
        guard.before_calls.fetch(2) == ["P14 generated test executable"],
        "test executable is command-window bound"
      )
      runner.validate_now
      assert(guard.validate_calls == 1, "final command-window validation")
    end
  end

  def test_delegated_compiler_source_mutation_fails_closed
    Dir.mktmpdir("FIXTURE_TECNICA_p14_source_window", "/private/tmp") do |directory|
      source, output, toolchain, sdk, identity = fixture_roots(directory)
      source_file = File.join(source, "fixture.rs")
      File.binwrite(source_file, "FIXTURE_TECNICA_SOURCE")
      %w[clippy home lib tests tmp].each do |name|
        FileUtils.mkdir_p(File.join(output, name), mode: 0o700)
      end
      rustc = File.join(toolchain, "bin/rustc")
      File.binwrite(
        rustc,
        "#!/bin/sh\n" \
        "printf '%s' 'FIXTURE_TECNICA_CHANGED' > '#{source_file}'\n" \
        "printf '%s' 'FIXTURE_TECNICA_SOURCE' > '#{source_file}'\n" \
        "exit 0\n"
      )
      File.chmod(0o700, rustc)
      refresh_file_identity(identity, toolchain, "bin/rustc")
      runner = P14RustcDriver::CommandRunner.new(
        source_root: source,
        output_root: output,
        toolchain_root: toolchain,
        sdk_root: sdk,
        input_identity: identity,
        selected_source_roots: [source]
      )
      assert_failure("selected source identity changed") do
        runner.rustc(
          ["-o", File.join(output, "lib/fixture.rlib")],
          {},
          "fixture-source-mutation"
        )
      end
    end
  end

  def test_generated_tests_use_isolated_output_working_directories
    Dir.mktmpdir("FIXTURE_TECNICA_p14_test_cwd", "/private/tmp") do |directory|
      source, output, toolchain, sdk, identity = fixture_roots(directory)
      File.binwrite(
        File.join(source, "fixture.rs"),
        "FIXTURE_TECNICA_SOURCE"
      )
      Dir.mkdir(output, 0o700)
      %w[clippy home lib tests tmp].each do |name|
        Dir.mkdir(File.join(output, name), 0o700)
      end
      test_binary = File.join(output, "tests/fixture")
      File.binwrite(
        test_binary,
        "#!/bin/sh\n" \
        "test ! -e FIXTURE_TECNICA_relative_scratch || exit 9\n" \
        "printf '%s' 'FIXTURE_TECNICA_SCRATCH' > " \
        "FIXTURE_TECNICA_relative_scratch\n" \
        "printf '%s\\n' 'test result: ok. 1 passed; 0 failed; " \
        "0 ignored; 0 measured; 0 filtered out; finished in 0.01s'\n"
      )
      File.chmod(0o700, test_binary)
      runner = P14RustcDriver::CommandRunner.new(
        source_root: source,
        output_root: output,
        toolchain_root: toolchain,
        sdk_root: sdk,
        input_identity: identity,
        selected_source_roots: [source]
      )

      2.times do
        _stdout, result = runner.test(
          test_binary,
          ["--test-threads=1"],
          "fixture-relative-scratch"
        )
        assert(result.fetch(:passed) == 1, "isolated test command passed")
      end
      scratch_files = Dir.glob(
        File.join(
          output,
          "tmp",
          "*",
          "FIXTURE_TECNICA_relative_scratch"
        )
      )
      assert(scratch_files.length == 2, "each test has distinct output scratch")
      assert(
        !File.exist?(File.join(source, "FIXTURE_TECNICA_relative_scratch")),
        "relative test scratch is absent from selected sources"
      )
      assert(runner.validate_now, "source identity remains stable")
    end
  end

  def test_output_window_allows_only_declared_evolution
    with_guard_fixture do |_directory, _source, output, _toolchain, _sdk, _identity, guard|
      generated = File.join(output, "lib/generated.rlib")
      guard.before_command(expected_output_paths: [generated])
      File.binwrite(generated, "FIXTURE_TECNICA_GENERATED")
      assert(guard.after_command, "declared output is admitted")
      assert(guard.validate_now, "declared output becomes stable")

      guard.before_command
      File.binwrite(generated, "FIXTURE_TECNICA_GENERATED")
      assert_failure("preexisting generated output changed") do
        guard.after_command
      end
    end

    with_guard_fixture do |_directory, _source, output, _toolchain, _sdk, _identity, guard|
      guard.before_command
      File.binwrite(
        File.join(output, "lib/undeclared.rlib"),
        "FIXTURE_TECNICA_UNDECLARED"
      )
      assert_failure("undeclared output path") { guard.after_command }
    end
  end

  def test_command_policy_proves_cargo_absent
    Dir.mktmpdir("FIXTURE_TECNICA_p14_commands", "/private/tmp") do |directory|
      source, output, toolchain, _sdk, identity = fixture_roots(directory)
      FileUtils.mkdir_p(File.join(output, "tests"))
      test_binary = File.join(output, "tests", "fixture")
      File.binwrite(test_binary, "FIXTURE_TECNICA_TEST")
      rustc = File.join(toolchain, "bin/rustc")
      clippy = File.join(toolchain, "bin/clippy-driver")

      assert(
        P14RustcDriver.validate_command_executable(
          rustc,
          kind: :rustc,
          rustc: rustc,
          clippy: clippy,
          output_root: output,
          identity: identity.fetch(:files).fetch("bin/rustc")
        ),
        "exact rustc admitted"
      )
      assert(
        P14RustcDriver.validate_command_executable(
          clippy,
          kind: :clippy,
          rustc: rustc,
          clippy: clippy,
          output_root: output,
          identity: identity.fetch(:files).fetch("bin/clippy-driver")
        ),
        "exact Clippy admitted"
      )
      assert(
        P14RustcDriver.validate_command_executable(
          test_binary,
          kind: :test,
          rustc: rustc,
          clippy: clippy,
          output_root: output,
          identity: nil
        ),
        "generated test binary admitted"
      )
      cargo = File.join(directory, "cargo")
      File.binwrite(cargo, "FIXTURE_TECNICA_CARGO")
      assert_failure("Cargo execution is forbidden") do
        P14RustcDriver.validate_command_executable(
          cargo,
          kind: :rustc,
          rustc: rustc,
          clippy: clippy,
          output_root: output,
          identity: identity.fetch(:files).fetch("bin/rustc")
        )
      end
      assert_failure("outside the direct allowlist") do
        P14RustcDriver.validate_command_executable(
          test_binary,
          kind: :rustc,
          rustc: rustc,
          clippy: clippy,
          output_root: output,
          identity: identity.fetch(:files).fetch("bin/rustc")
        )
      end
      assert(!source.include?("cargo"), "fixture source is unrelated to Cargo")
    end
  end

  def test_machine_test_result_parser
    summary =
      "test result: ok. 17 passed; 0 failed; 2 ignored; 0 measured; " \
      "0 filtered out; finished in 0.02s\n"
    parsed = P14RustcDriver.parse_test_result(summary)
    assert(parsed.fetch(:passed) == 17, "single pass count parsed")
    assert(parsed.fetch(:ignored) == 2, "actual ignored count parsed")
    assert_failure("exactly one machine-verifiable result") do
      P14RustcDriver.parse_test_result("test output without a summary")
    end
    assert_failure("exactly one machine-verifiable result") do
      P14RustcDriver.parse_test_result(summary + summary)
    end
    nested =
      "test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; " \
      "10 filtered out; finished in 0.01s\n"
    expected_nested = [
      { passed: 1, ignored: 0, measured: 0, filtered_out: 10 }
    ]
    nested_result = P14RustcDriver.parse_test_result(
      nested + summary,
      nested_evidence: expected_nested
    )
    assert(nested_result.fetch(:passed) == 17, "top-level result is selected")
    assert_failure("companion evidence differs") do
      P14RustcDriver.parse_test_result(
        nested.sub("10 filtered out", "9 filtered out") + summary,
        nested_evidence: expected_nested
      )
    end
    assert_failure("exactly one machine-verifiable result") do
      P14RustcDriver.parse_test_result(
        nested + nested + summary,
        nested_evidence: expected_nested
      )
    end
    assert_failure("skipped selected tests") do
      P14RustcDriver.parse_test_result(
        "test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; " \
        "3 filtered out; finished in 0.01s\n"
      )
    end
    assert_failure("machine-verifiable PASS") do
      P14RustcDriver.parse_test_result(
        "test result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; " \
        "0 filtered out; finished in 0.01s\n"
      )
    end
  end

  def test_result_evidence_is_bijective
    source_root = File.expand_path("..", __dir__)
    passing = direct_result_evidence(source_root)
    parsed = P14RustcDriver.validate_result_evidence(passing, source_root)
    assert(parsed.fetch(:rust).fetch(:binaries) == 28, "all Rust records")
    assert(parsed.fetch(:rust).fetch(:harness_binaries) == 27, "all harnesses")
    assert(parsed.fetch(:clippy_targets) == 38, "all Clippy records")

    rust_line = passing.lines.find do |line|
      line.start_with?("P14_RUST_TEST_RESULT ")
    end
    assert_failure("duplicated") do
      P14RustcDriver.validate_result_evidence(
        passing + rust_line,
        source_root
      )
    end
    assert_failure("missing a target") do
      P14RustcDriver.validate_result_evidence(
        passing.sub(rust_line, ""),
        source_root
      )
    end
    assert_failure("extra target") do
      P14RustcDriver.validate_result_evidence(
        passing +
          "P14_RUST_TEST_RESULT package=ha-adapter target=extra " \
          "harness=true passed=1 ignored=0 measured=0 filtered_out=0\n",
        source_root
      )
    end
    assert_failure("duplicate keys") do
      P14RustcDriver.validate_result_evidence(
        passing.sub("passed=1", "passed=1 passed=2"),
        source_root
      )
    end
    assert_failure("duplicate keys") do
      P14RustcDriver.validate_result_evidence(
        passing.sub(
          "filtered_out=0",
          "filtered_out=0 filtered_out=0"
        ),
        source_root
      )
    end
    assert_failure("failed or skipped") do
      P14RustcDriver.validate_result_evidence(
        passing.sub(
          "passed=1 ignored=0 measured=0 filtered_out=0",
          "status=fail"
        ),
        source_root
      )
    end
    assert_failure("skipped or filtered") do
      P14RustcDriver.validate_result_evidence(
        passing.sub("filtered_out=0", "filtered_out=1"),
        source_root
      )
    end

    clippy_line = passing.lines.find do |line|
      line.start_with?("P14_CLIPPY_RESULT ")
    end
    assert_failure("duplicated") do
      P14RustcDriver.validate_result_evidence(
        passing + clippy_line,
        source_root
      )
    end
    assert_failure("missing a target") do
      P14RustcDriver.validate_result_evidence(
        passing.sub(clippy_line, ""),
        source_root
      )
    end
    assert_failure("extra target") do
      P14RustcDriver.validate_result_evidence(
        passing + "P14_CLIPPY_RESULT target=extra status=pass\n",
        source_root
      )
    end
    assert_failure("failed or skipped") do
      P14RustcDriver.validate_result_evidence(
        passing.sub("status=pass", "status=skip"),
        source_root
      )
    end
  end

  def test_success_output_rejects_credential_canaries
    assert(
      P14RustcDriver.validate_no_credential_canary(
        "FIXTURE_TECNICA_PUBLIC",
        "fixture",
        "stdout"
      ),
      "noncredential fixture output"
    )
    assert_failure("credential canary on stdout") do
      P14RustcDriver.validate_no_credential_canary(
        "FIXTURE_TECNICA_CREDENTIAL_00000",
        "fixture",
        "stdout"
      )
    end
    assert_failure("credential canary on stderr") do
      P14RustcDriver.validate_no_credential_canary(
        "FIXTURE_TECNICA_CREDENTIAL_00000",
        "fixture",
        "stderr"
      )
    end
  end

  def run
    public_methods(false).grep(/\Atest_/).sort.each { |test| public_send(test) }
    puts "P14_RUSTC_DRIVER_TESTS_PASS"
  end
end

P14RustcDriverTest.run
