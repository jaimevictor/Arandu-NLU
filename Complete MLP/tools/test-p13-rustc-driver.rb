# frozen_string_literal: true

require "fileutils"
require "digest"
require "tmpdir"
require_relative "p13-rustc-driver"

module P13RustcDriverTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure(message)
    yield
    raise "expected P13RustcDriver::Failure"
  rescue P13RustcDriver::Failure => error
    assert(error.message.include?(message), "failure message #{message.inspect}")
  end

  def deep_copy(value)
    Marshal.load(Marshal.dump(value))
  end

  def test_exact_package_plan
    assert(P13RustcDriver.validate_package_plan, "exact direct package plan")
    names = P13RustcDriver::PACKAGES.map { |package| package.fetch(:name) }
    assert(names.length == 19, "direct package count")
    assert(!names.include?("cargo"), "Cargo is not a direct package")
  end

  def test_package_identity_and_order_mutations
    changed = deep_copy(P13RustcDriver::PACKAGES)
    changed.fetch(0)[:name] = "changed"
    assert_failure("order or identity differs") do
      P13RustcDriver.validate_package_plan(changed)
    end

    changed = deep_copy(P13RustcDriver::PACKAGES)
    changed.fetch(4)[:dependencies] = ["cipher"]
    assert_failure("not topological") do
      P13RustcDriver.validate_package_plan(changed)
    end

    changed = deep_copy(P13RustcDriver::PACKAGES)
    changed.fetch(0)[:source] = "../escape"
    assert_failure("source is unsafe") do
      P13RustcDriver.validate_package_plan(changed)
    end
  end

  def test_root_contract
    Dir.mktmpdir("FIXTURE_TECNICA_p13_rustc_roots") do |directory|
      source = File.join(directory, "source")
      output = File.join(directory, "output")
      FileUtils.mkdir_p(source)
      assert(
        P13RustcDriver.validate_roots(source, output),
        "fresh absolute roots"
      )
      assert(File.directory?(output), "output root created")
      assert_failure("output root already exists") do
        P13RustcDriver.validate_roots(source, output)
      end
      P13RustcDriver.prepare_output_layout(output)
      assert(
        P13RustcDriver.validate_roots(
          source,
          output,
          output_prepared: true
        ),
        "prepared private empty output root"
      )

      link = File.join(directory, "source-link")
      File.symlink(source, link)
      assert_failure("source root must be an absolute directory") do
        P13RustcDriver.validate_roots(link, File.join(directory, "other-output"))
      end
    end
  end

  def test_command_guard_runs_before_and_after
    calls = 0
    guard = lambda do
      calls += 1
      true
    end
    P13RustcDriver.invoke(
      "/usr/bin/ruby",
      ["--disable-gems", "-e", "exit 0"],
      {},
      "FIXTURE_TECNICA successful admitted Ruby",
      include_global_flags: false,
      guard: guard
    )
    assert(calls == 2, "successful command guard count")

    calls = 0
    assert_failure("failed") do
      P13RustcDriver.invoke(
        "/usr/bin/ruby",
        ["--disable-gems", "-e", "exit 7"],
        {},
        "FIXTURE_TECNICA failing admitted Ruby",
        include_global_flags: false,
        guard: lambda do
          calls += 1
          true
        end
      )
    end
    assert(calls == 2, "failed command guard count")
  end

  def test_post_command_guard_failure_wins
    calls = 0
    guard = lambda do
      calls += 1
      raise P13RustcDriver::Failure, "FIXTURE_TECNICA source changed" if
        calls == 2
      true
    end
    assert_failure("source changed") do
      P13RustcDriver.invoke(
        "/usr/bin/ruby",
        ["--disable-gems", "-e", "exit 0"],
        {},
        "FIXTURE_TECNICA guarded command",
        include_global_flags: false,
        guard: guard
      )
    end
  end

  def test_command_window_guards_ancestors_tools_and_generated_artifacts
    Dir.mktmpdir(
      "FIXTURE_TECNICA_p13_command_window",
      "/private/tmp"
    ) do |directory|
      workspace = File.join(directory, "workspace")
      source = File.join(workspace, "source")
      output = File.join(workspace, "output")
      tool = File.join(directory, "tool")
      sysroot = File.join(directory, "sysroot")
      FileUtils.mkdir_p(source)
      FileUtils.mkdir_p(output, mode: 0o700)
      FileUtils.mkdir_p(sysroot)
      File.binwrite(File.join(source, "lib.rs"), "FIXTURE_TECNICA_SOURCE")
      File.binwrite(tool, "FIXTURE_TECNICA_TOOL")
      sysroot_input = File.join(sysroot, "libfixture.rlib")
      File.binwrite(sysroot_input, "FIXTURE_TECNICA_SYSROOT")
      invariant = lambda do
        raise P13RustcDriver::Failure, "FIXTURE_TECNICA source changed" unless
          File.binread(File.join(source, "lib.rs")) == "FIXTURE_TECNICA_SOURCE"
        true
      end
      immutable = {
        "FIXTURE_TECNICA tool" => {
          path: tool,
          bytes: File.size(tool),
          sha256: Digest::SHA256.file(tool).hexdigest
        }
      }
      tree_rows = [
        [
          "libfixture.rlib",
          File.size(sysroot_input).to_s,
          Digest::SHA256.file(sysroot_input).hexdigest
        ].join("\0")
      ]
      immutable_trees = {
        "FIXTURE_TECNICA sysroot" => {
          root: sysroot,
          file_count: 1,
          total_bytes: File.size(sysroot_input),
          inventory_sha256: Digest::SHA256.hexdigest(tree_rows.join("\n") + "\n")
        }
      }
      artifact = File.join(output, "artifact")
      expected = {
        "artifact" => {
          bytes: "FIXTURE_TECNICA_ARTIFACT".bytesize,
          sha256: Digest::SHA256.hexdigest("FIXTURE_TECNICA_ARTIFACT")
        }
      }

      guard = P13RustcDriver::CommandWindowGuard.new(
        invariant: invariant,
        immutable_files: immutable,
        immutable_trees: immutable_trees,
        output_root: output,
        ancestor_anchors: [workspace],
        expected_generated_files: expected
      )
      guard.before_command
      File.binwrite(artifact, "FIXTURE_TECNICA_ARTIFACT")
      guard.after_command

      File.binwrite(artifact, "FIXTURE_TECNICA_ARTIFACX")
      assert_failure("changed between commands") { guard.before_command }
      File.binwrite(artifact, "FIXTURE_TECNICA_ARTIFACT")

      guard = P13RustcDriver::CommandWindowGuard.new(
        invariant: invariant,
        immutable_files: immutable,
        immutable_trees: immutable_trees,
        output_root: output,
        ancestor_anchors: [workspace],
        expected_generated_files: expected.merge(
          "second" => {
            bytes: "FIXTURE_TECNICA_SECOND".bytesize,
            sha256: Digest::SHA256.hexdigest("FIXTURE_TECNICA_SECOND")
          }
        )
      )
      guard.before_command
      File.binwrite(File.join(output, "second"), "FIXTURE_TECNICA_ATTACK")
      assert_failure("generated artifact hash differs") { guard.after_command }
      FileUtils.rm_f(File.join(output, "second"))

      guard = P13RustcDriver::CommandWindowGuard.new(
        invariant: invariant,
        immutable_files: immutable,
        immutable_trees: immutable_trees,
        output_root: output,
        ancestor_anchors: [workspace],
        expected_generated_files: expected
      )
      guard.before_command
      File.binwrite(artifact, "FIXTURE_TECNICA_CHANGED!")
      File.binwrite(artifact, "FIXTURE_TECNICA_ARTIFACT")
      assert_failure("generated artifact changed") { guard.after_command }

      guard = P13RustcDriver::CommandWindowGuard.new(
        invariant: invariant,
        immutable_files: immutable,
        immutable_trees: immutable_trees,
        output_root: output,
        ancestor_anchors: [workspace],
        expected_generated_files: expected
      )
      guard.before_command
      File.binwrite(tool, "FIXTURE_TECNICA_BAD!")
      File.binwrite(tool, "FIXTURE_TECNICA_TOOL")
      assert_failure("immutable file identity changed") { guard.after_command }

      guard = P13RustcDriver::CommandWindowGuard.new(
        invariant: invariant,
        immutable_files: immutable,
        immutable_trees: immutable_trees,
        output_root: output,
        ancestor_anchors: [workspace],
        expected_generated_files: expected
      )
      guard.before_command
      File.binwrite(sysroot_input, "FIXTURE_TECNICA_CHANGED")
      File.binwrite(sysroot_input, "FIXTURE_TECNICA_SYSROOT")
      assert_failure("immutable tree identity changed") { guard.after_command }

      guard = P13RustcDriver::CommandWindowGuard.new(
        invariant: invariant,
        immutable_files: immutable,
        immutable_trees: immutable_trees,
        output_root: output,
        ancestor_anchors: [workspace],
        expected_generated_files: expected
      )
      guard.before_command
      parked = File.join(directory, "parked")
      File.rename(workspace, parked)
      FileUtils.mkdir_p(File.join(workspace, "source"))
      FileUtils.mkdir_p(File.join(workspace, "output"), mode: 0o700)
      File.binwrite(
        File.join(workspace, "source/lib.rs"),
        "FIXTURE_TECNICA_SOURCE"
      )
      FileUtils.remove_entry(workspace)
      File.rename(parked, workspace)
      assert_failure("ancestor identity changed") { guard.after_command }
    end
  end

  def run
    public_methods(false).grep(/\Atest_/).sort.each { |test| public_send(test) }
    puts "P13_RUSTC_DRIVER_TESTS_PASS"
  end
end

P13RustcDriverTest.run
