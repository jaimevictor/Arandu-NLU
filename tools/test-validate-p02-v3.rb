# frozen_string_literal: true
# SPDX-License-Identifier: Apache-2.0
# P02V3_FUTURE_MUTABLE_SOURCE_BOUNDARY_V1: fixture-only source capability tests

require "fileutils"
require "rbconfig"
require "set"
require "tmpdir"

require_relative "validate-p02-v3"

module P02V3ValidationTests
  module_function

  def assert(condition, message)
    raise message unless condition
  end

  def assert_failure(fragment)
    yield
    raise "expected failure containing #{fragment.inspect}"
  rescue P02V3Validation::Failure, P02V3Corpus::Failure => error
    raise "unexpected failure: #{error.message}" unless
      error.message.include?(fragment)
  end

  def fixture_release_root
    [
      [100, 97, 116, 97].pack("C*"),
      [112, 114, 111, 106, 101, 99, 116, 45, 97, 117, 116, 104, 111, 114, 101, 100].pack("C*"),
      [112, 48, 50, 45, 118, 51].pack("C*")
    ].join("/")
  end

  def test_strict_json_accepts_fixture
    parsed = P02V3Validation.strict_json(
      "{\"fixture\":\"FIXTURE_TECNICA\"}\n",
      "FIXTURE_TECNICA JSON"
    )
    assert(
      parsed == {"fixture" => "FIXTURE_TECNICA"},
      "fixture JSON differs"
    )
  end

  def test_duplicate_json_key_is_rejected
    assert_failure("invalid JSON") do
      P02V3Validation.strict_json(
        "{\"fixture\":1,\"fixture\":2}\n",
        "FIXTURE_TECNICA duplicate"
      )
    end
  end

  def test_invalid_utf8_is_rejected
    bytes = "{\"fixture\":\"".b + "\xff".b + "\"}\n".b
    assert_failure("not valid UTF-8") do
      P02V3Validation.strict_json(
        bytes,
        "FIXTURE_TECNICA encoding"
      )
    end
  end

  def test_jsonl_limits_and_count_are_enforced
    fixture = "{\"fixture\":\"FIXTURE_TECNICA\"}\n"
    rows = P02V3Validation.parse_jsonl(
      fixture,
      1,
      1,
      "FIXTURE_TECNICA JSONL"
    )
    assert(rows.length == 1, "fixture JSONL count differs")
    assert_failure("record count differs") do
      P02V3Validation.parse_jsonl(
        fixture,
        2,
        2,
        "FIXTURE_TECNICA JSONL"
      )
    end
    assert_failure("record limit") do
      P02V3Validation.parse_jsonl(
        fixture + fixture,
        2,
        1,
        "FIXTURE_TECNICA JSONL"
      )
    end
  end

  def test_jsonl_rejects_blank_cr_and_missing_lf
    assert_failure("blank row") do
      P02V3Validation.parse_jsonl(
        "{\"fixture\":\"FIXTURE_TECNICA\"}\n\n",
        2,
        2,
        "FIXTURE_TECNICA blank"
      )
    end
    assert_failure("CR bytes") do
      P02V3Validation.parse_jsonl(
        "{\"fixture\":\"FIXTURE_TECNICA\"}\r\n",
        1,
        1,
        "FIXTURE_TECNICA CR"
      )
    end
    assert_failure("end with LF") do
      P02V3Validation.parse_jsonl(
        "{\"fixture\":\"FIXTURE_TECNICA\"}",
        1,
        1,
        "FIXTURE_TECNICA LF"
      )
    end
  end

  def test_partition_collision_is_rejected
    P02V3Validation.assert_disjoint!(
      [Set["FIXTURE_TECNICA_A"], Set["FIXTURE_TECNICA_B"]],
      "FIXTURE_TECNICA"
    )
    assert_failure("crosses partitions") do
      P02V3Validation.assert_disjoint!(
        [Set["FIXTURE_TECNICA_A"], Set["FIXTURE_TECNICA_A"]],
        "FIXTURE_TECNICA"
      )
    end
  end

  def test_regular_reader_rejects_symlinks_and_large_input
    Dir.mktmpdir("p02-v3-validation-fixture.") do |root|
      target = File.join(root, "FIXTURE_TECNICA-target")
      link = File.join(root, "FIXTURE_TECNICA-link")
      File.binwrite(target, "FIXTURE_TECNICA\n")
      assert_failure("exceeds the byte limit") do
        P02V3Validation.read_regular(
          target,
          1,
          "FIXTURE_TECNICA bounded"
        )
      end
      File.symlink(target, link)
      assert_failure("symlink component") do
        P02V3Validation.read_regular(
          link,
          64,
          "FIXTURE_TECNICA symlink"
        )
      end
    end
  end

  def fixture_confinement(
    release_path,
    current_paths: ["tools/FIXTURE_TECNICA_ALLOWED.rb"],
    future_paths: []
  )
    {
      "current_allowed_source_paths" => current_paths,
      "future_allowed_source_paths" => future_paths,
      "future_mutable_source_paths" => [],
      "source_io_baseline_commit" => "0" * 40,
      "release_artifact_paths" => [release_path],
      "source_inventory_executable" => "/usr/bin/git",
      "source_inventory_environment" => {
        "GIT_CONFIG_GLOBAL" => "/dev/null",
        "GIT_CONFIG_NOSYSTEM" => "1",
        "GIT_CONFIG_SYSTEM" => "/dev/null",
        "GIT_NO_REPLACE_OBJECTS" => "1",
        "GIT_OPTIONAL_LOCKS" => "0",
        "GIT_TERMINAL_PROMPT" => "0",
        "LANG" => "C",
        "LC_ALL" => "C",
        "PATH" => "/usr/bin:/bin",
        "TMPDIR" => "/tmp",
        "TZ" => "UTC"
      },
      "source_inventory_maximum_bytes" => 4096,
      "source_inventory_maximum_paths" => 64,
      "source_inventory_maximum_stderr_bytes" => 1024,
      "source_inventory_excluded_pathspecs" => [
        ".DS_Store",
        ".cargo-home/**",
        ".mypy_cache/**",
        ".pytest_cache/**",
        ".tools/**",
        "**/.DS_Store",
        "**/__pycache__/**",
        "**/*.pyc",
        "STEERING-NLU-PTBR-SOL-MAX.md",
        "data/**",
        "docs/**",
        "release/**",
        "target/**"
      ],
      "source_inventory_capture" =>
        "STREAMING_DUAL_PIPE_LIMIT_PLUS_ONE_TERMINATE_AND_REAP",
      "source_inventory_repository_binding" =>
        "EXPLICIT_DOT_GIT_DIRECTORY_AND_ROOT_WORK_TREE",
      "source_change_policy" =>
        "EVERY_INVENTORIED_PROJECT_PATH_BLOB_BOUND_AND_EVERY_CHANGE_PREDECLARED",
      "mutable_source_capability_policy" =>
        "ALL_MUTABLE_PATHS_TREATED_AS_IO_CAPABLE_WITHOUT_SYNTAX_CLASSIFICATION",
      "recognized_project_read_abstractions" => [
        "read_bounded_root_file",
        "read_verified"
      ],
      "path_containment" =>
        "REJECT_SYMLINK_COMPONENTS_AND_REQUIRE_RESOLVED_ROOT_CONTAINMENT",
      "source_scan_scope" => "FIXTURE_TECNICA_ONLY",
      "unauthorized_loader_policy" => "FAIL_CLOSED",
      "boundary_marker" => "FIXTURE_TECNICA_BOUNDARY",
      "mutable_source_boundary_marker" =>
        "FIXTURE_TECNICA_MUTABLE_SOURCE_BOUNDARY"
    }
  end

  def fixture_command_environment
    {
      "LANG" => "C",
      "LC_ALL" => "C",
      "PATH" => "/usr/bin:/bin",
      "TMPDIR" => "/tmp",
      "TZ" => "UTC"
    }
  end

  def capture_fixture_command(code, stdout_limit:, stderr_limit:)
    P02V3Validation.capture_bounded_subprocess(
      File.expand_path(RbConfig.ruby),
      ["-e", code],
      fixture_command_environment,
      stdout_limit: stdout_limit,
      stderr_limit: stderr_limit
    )
  end

  def test_bounded_capture_rejects_stdout_one_over_limit
    assert_failure("stdout exceeds the byte limit") do
      capture_fixture_command(
        "STDOUT.binmode; STDOUT.write(\"O\" * 5)",
        stdout_limit: 4,
        stderr_limit: 64
      )
    end
  end

  def test_bounded_capture_rejects_stderr_one_over_limit
    assert_failure("stderr exceeds the byte limit") do
      capture_fixture_command(
        "STDERR.binmode; STDERR.write(\"E\" * 5)",
        stdout_limit: 64,
        stderr_limit: 4
      )
    end
  end

  def test_bounded_capture_rejects_nonzero_exit
    assert_failure("exited unsuccessfully") do
      capture_fixture_command(
        "exit 7",
        stdout_limit: 64,
        stderr_limit: 64
      )
    end
  end

  def test_bounded_capture_accepts_valid_nul_inventory
    fixture = "tools/FIXTURE_TECNICA.rb\0"
    stdout, stderr = capture_fixture_command(
      "STDOUT.binmode; STDOUT.write(#{fixture.inspect})",
      stdout_limit: fixture.bytesize,
      stderr_limit: 64
    )
    assert(stderr.empty?, "fixture command emitted stderr")
    assert(stdout == fixture, "fixture bounded stdout differs")
    assert(
      P02V3Validation.parse_source_inventory(stdout) ==
        ["tools/FIXTURE_TECNICA.rb"],
      "fixture bounded inventory differs"
    )
  end

  def test_bounded_capture_drains_both_streams_without_deadlock
    count = 128 * 1024
    stdout, stderr = capture_fixture_command(
      [
        "STDOUT.binmode",
        "STDERR.binmode",
        "a = Thread.new { STDOUT.write(\"O\" * #{count}) }",
        "b = Thread.new { STDERR.write(\"E\" * #{count}) }",
        "[a, b].each(&:join)"
      ].join("; "),
      stdout_limit: count,
      stderr_limit: count
    )
    assert(stdout.bytesize == count, "fixture stdout count differs")
    assert(stderr.bytesize == count, "fixture stderr count differs")
  end

  def test_source_inventory_overrides_repository_core_excludes_file
    Dir.mktmpdir("source-inventory-fixture.") do |root|
      environment = fixture_command_environment
      P02V3Validation.capture_bounded_subprocess(
        "/usr/bin/git",
        ["init", "--quiet", root],
        environment,
        stdout_limit: 1024,
        stderr_limit: 1024
      )
      relative = "tools/FIXTURE_TECNICA_HIDDEN.rs"
      info_relative = "tools/FIXTURE_TECNICA_INFO_HIDDEN.rs"
      FileUtils.mkdir_p(File.dirname(File.join(root, relative)))
      File.binwrite(File.join(root, relative), "// FIXTURE_TECNICA\n")
      File.binwrite(File.join(root, info_relative), "// FIXTURE_TECNICA\n")
      excludes = File.join(root, "FIXTURE_TECNICA.excludes")
      File.binwrite(excludes, "#{relative}\n")
      File.binwrite(
        File.join(root, ".git", "info", "exclude"),
        "#{info_relative}\n"
      )
      P02V3Validation.capture_bounded_subprocess(
        "/usr/bin/git",
        ["-C", root, "config", "--local", "core.excludesFile", excludes],
        environment,
        stdout_limit: 1024,
        stderr_limit: 1024
      )
      hidden, hidden_stderr =
        P02V3Validation.capture_bounded_subprocess(
          "/usr/bin/git",
          [
            "-C",
            root,
            "ls-files",
            "--others",
            "--exclude-standard",
            "-z"
          ],
          environment,
          stdout_limit: 4096,
          stderr_limit: 1024
        )
      assert(hidden_stderr.empty?, "fixture Git exclusion probe emitted stderr")
      assert(
        !P02V3Validation.parse_source_inventory(hidden).include?(relative),
        "fixture local excludes file did not hide the source"
      )
      assert(
        !P02V3Validation.parse_source_inventory(hidden).include?(info_relative),
        "fixture Git info exclude did not hide the source"
      )

      paths = P02V3Validation.repository_source_paths(
        root,
        fixture_confinement("#{fixture_release_root}/heldout.jsonl")
      )
      assert(
        paths.include?(relative),
        "repository-local core.excludesFile hid a source from inventory"
      )
      assert(
        paths.include?(info_relative),
        ".git/info/exclude hid a source from inventory"
      )
    end
  end

  def test_source_inventory_overrides_repository_core_worktree
    Dir.mktmpdir("source-inventory-fixture.") do |root|
      Dir.mktmpdir("source-inventory-alternate.") do |alternate|
        environment = fixture_command_environment
        P02V3Validation.capture_bounded_subprocess(
          "/usr/bin/git",
          ["init", "--quiet", root],
          environment,
          stdout_limit: 1024,
          stderr_limit: 1024
        )
        relative = "tools/FIXTURE_TECNICA_WORKTREE_HIDDEN.rs"
        FileUtils.mkdir_p(File.dirname(File.join(root, relative)))
        File.binwrite(File.join(root, relative), "// FIXTURE_TECNICA\n")
        P02V3Validation.capture_bounded_subprocess(
          "/usr/bin/git",
          ["-C", root, "config", "--local", "core.worktree", alternate],
          environment,
          stdout_limit: 1024,
          stderr_limit: 1024
        )
        hidden, hidden_stderr =
          P02V3Validation.capture_bounded_subprocess(
            "/usr/bin/git",
            ["-C", root, "ls-files", "--others", "-z"],
            environment,
            stdout_limit: 4096,
            stderr_limit: 1024
          )
        assert(
          hidden_stderr.empty?,
          "fixture Git worktree probe emitted stderr"
        )
        assert(
          !P02V3Validation.parse_source_inventory(hidden).include?(relative),
          "fixture local core.worktree did not hide the source"
        )

        paths = P02V3Validation.repository_source_paths(
          root,
          fixture_confinement("#{fixture_release_root}/heldout.jsonl")
        )
        assert(
          paths.include?(relative),
          "repository-local core.worktree redirected source inventory"
        )
      end
    end
  end

  def test_source_inventory_rejects_extensionless_project_source
    Dir.mktmpdir("source-inventory-fixture.") do |root|
      environment = fixture_command_environment
      P02V3Validation.capture_bounded_subprocess(
        "/usr/bin/git",
        ["init", "--quiet", root],
        environment,
        stdout_limit: 1024,
        stderr_limit: 1024
      )
      relative = "scripts/FIXTURE_TECNICA_LOADER"
      FileUtils.mkdir_p(File.dirname(File.join(root, relative)))
      release_path = "#{fixture_release_root}/heldout.jsonl"
      File.binwrite(
        File.join(root, relative),
        "File.binread(#{release_path.inspect})\n"
      )
      confinement = fixture_confinement(
        release_path,
        current_paths: [],
        future_paths: []
      )
      paths = P02V3Validation.repository_source_paths(root, confinement)
      assert(
        paths.include?(relative),
        "extensionless source is absent from repository inventory"
      )
      assert(
        P02V3Validation.source_candidate?(relative),
        "extensionless project path is not treated as source-capable"
      )
      assert_failure("outside the reviewed mutable inventory") do
        P02V3Validation.scan_loader_sources!(
          root,
          confinement,
          [relative]
        )
      end
    end
  end

  def test_source_inventory_parser_accepts_strict_nul_framing
    bytes = [
      "tools/FIXTURE_TECNICA.rb",
      "crates/FIXTURE_TECNICA/src/lib.rs",
      ""
    ].join("\0")
    paths = P02V3Validation.parse_source_inventory(bytes)
    assert(
      paths == [
        "crates/FIXTURE_TECNICA/src/lib.rs",
        "tools/FIXTURE_TECNICA.rb"
      ],
      "fixture source inventory differs"
    )
  end

  def test_source_inventory_parser_rejects_invalid_encoding_and_nul_framing
    assert_failure("not valid UTF-8") do
      P02V3Validation.parse_source_inventory(
        "tools/FIXTURE_".b + "\xff".b + "\0".b
      )
    end
    assert_failure("NUL framing") do
      P02V3Validation.parse_source_inventory(
        "tools/FIXTURE_TECNICA.rb"
      )
    end
    assert_failure("NUL framing") do
      P02V3Validation.parse_source_inventory(
        "tools/FIXTURE_TECNICA.rb\0\0"
      )
    end
  end

  def test_source_inventory_parser_rejects_traversal_and_duplicates
    assert_failure("path traversal") do
      P02V3Validation.parse_source_inventory(
        "../FIXTURE_TECNICA.rb\0"
      )
    end
    assert_failure("must be relative") do
      P02V3Validation.parse_source_inventory(
        "/FIXTURE_TECNICA.rb\0"
      )
    end
    assert_failure("duplicates") do
      P02V3Validation.parse_source_inventory(
        "tools/FIXTURE_TECNICA.rb\0tools/FIXTURE_TECNICA.rb\0"
      )
    end
  end

  def test_source_inventory_parser_enforces_byte_and_path_limits
    fixture = "tools/FIXTURE_TECNICA.rb\0"
    assert_failure("byte limit") do
      P02V3Validation.parse_source_inventory(
        fixture,
        maximum_bytes: 1
      )
    end
    assert_failure("path limit") do
      P02V3Validation.parse_source_inventory(
        fixture + "tools/FIXTURE_TECNICA_2.rb\0",
        maximum_paths: 1
      )
    end
  end

  def test_loader_confinement_accepts_marked_fixture_boundary
    Dir.mktmpdir("p02-v3-loader-fixture.") do |root|
      FileUtils.mkdir_p(File.join(root, "tools"))
      release_root = fixture_release_root
      release_path = [release_root, "heldout" + ".jsonl"].join("/")
      relative = "tools/FIXTURE_TECNICA_ALLOWED.rb"
      File.binwrite(
        File.join(root, relative),
        [
          "# FIXTURE_TECNICA_BOUNDARY",
          "File.binread(#{release_path.inspect})",
          ""
        ].join("\n")
      )
      assert(
        P02V3Validation.scan_loader_sources!(
          root,
          fixture_confinement(release_path),
          [relative]
        ),
        "fixture boundary scan did not pass"
      )
    end
  end

  def test_loader_confinement_rejects_rogue_fixture_source
    Dir.mktmpdir("p02-v3-loader-fixture.") do |root|
      FileUtils.mkdir_p(File.join(root, "tools"))
      release_root = fixture_release_root
      release_path = [release_root, "performance" + ".jsonl"].join("/")
      allowed = "tools/FIXTURE_TECNICA_ALLOWED.rb"
      rogue = "tools/FIXTURE_TECNICA_ROGUE.rb"
      File.binwrite(
        File.join(root, allowed),
        "# FIXTURE_TECNICA_BOUNDARY\n"
      )
      File.binwrite(
        File.join(root, rogue),
        "File.binread(#{release_path.inspect})\n"
      )
      assert_failure("outside the reviewed mutable inventory") do
        P02V3Validation.scan_loader_sources!(
          root,
          fixture_confinement(release_path),
          [allowed, rogue]
        )
      end
    end
  end

  def test_loader_confinement_rejects_missing_fixture_marker
    Dir.mktmpdir("p02-v3-loader-fixture.") do |root|
      FileUtils.mkdir_p(File.join(root, "tools"))
      release_root = fixture_release_root
      release_path = [release_root, "heldout" + ".jsonl"].join("/")
      relative = "tools/FIXTURE_TECNICA_ALLOWED.rb"
      File.binwrite(
        File.join(root, relative),
        "File.binread(#{release_path.inspect})\n"
      )
      assert_failure("boundary marker is missing") do
        P02V3Validation.scan_loader_sources!(
          root,
          fixture_confinement(release_path),
          [relative]
        )
      end
    end
  end

  def test_loader_confinement_rejects_unauthorized_rust_bounded_readers
    Dir.mktmpdir("p02-v3-loader-fixture.") do |root|
      relative = "crates/FIXTURE_TECNICA/src/rogue.rs"
      FileUtils.mkdir_p(File.dirname(File.join(root, relative)))
      release_root = fixture_release_root
      release_path = [release_root, "heldout" + ".jsonl"].join("/")
      File.binwrite(
        File.join(root, relative),
        [
          "let fixture_a = read_bounded_root_file(#{release_path.inspect});",
          "let fixture_b = read_verified(#{release_path.inspect});",
          ""
        ].join("\n")
      )
      assert_failure("outside the reviewed mutable inventory") do
        P02V3Validation.scan_loader_sources!(
          root,
          fixture_confinement(
            release_path,
            current_paths: [],
            future_paths: ["crates/release-eval/src/frozen.rs"]
          ),
          [relative]
        )
      end
    end
  end

  def test_loader_confinement_rejects_dynamic_rust_bounded_readers
    Dir.mktmpdir("p02-v3-loader-fixture.") do |root|
      relative = "crates/FIXTURE_TECNICA/src/dynamic_rogue.rs"
      FileUtils.mkdir_p(File.dirname(File.join(root, relative)))
      release_path = "#{fixture_release_root}/heldout.jsonl"
      parts = release_path.split("/")
      middle_parts = parts.fetch(1).split("-")
      label_parts = parts.fetch(2).split("-")
      File.binwrite(
        File.join(root, relative),
        [
          "let a = #{parts.fetch(0).inspect};",
          "let b = #{middle_parts.fetch(0).inspect};",
          "let c = #{middle_parts.fetch(1).inspect};",
          "let d = #{label_parts.fetch(0).inspect};",
          "let e = #{label_parts.fetch(1).inspect};",
          "let f = #{parts.fetch(3).inspect};",
          "/* #{"FIXTURE_TECNICA_" * 400} */",
          "let relative = [a, &format!(\"{}-{}\", b, c),",
          "  &format!(\"{}-{}\", d, e), f].join(\"/\");",
          "let fixture_a = read_bounded_root_file(root, &relative, 1);",
          "let fixture_b = read_verified(root, &relative, 1, hash, context);",
          ""
        ].join("\n")
      )
      assert_failure("outside the reviewed mutable inventory") do
        P02V3Validation.scan_loader_sources!(
          root,
          fixture_confinement(
            release_path,
            current_paths: [],
            future_paths: ["crates/release-eval/src/frozen.rs"]
          ),
          [relative]
        )
      end
    end
  end

  def test_io_capability_inventory_rejects_subtoken_path_reconstruction
    Dir.mktmpdir("p02-v3-loader-fixture.") do |root|
      relative = "crates/FIXTURE_TECNICA/src/subtoken_rogue.rs"
      FileUtils.mkdir_p(File.dirname(File.join(root, relative)))
      release_path = "#{fixture_release_root}/heldout.jsonl"
      parts = release_path.split("/")
      middle = parts.fetch(1)
      label = parts.fetch(2)
      fragments = [
        parts.fetch(0),
        middle[0, 3],
        middle[3, 4],
        middle[8, 4],
        middle[12, 4],
        label[0, 1],
        label[1, 2],
        label[4, 1],
        label[5, 1],
        parts.fetch(3)
      ]
      assignments = fragments.each_with_index.map do |fragment, index|
        "let x#{index} = #{fragment.inspect};"
      end
      File.binwrite(
        File.join(root, relative),
        [
          *assignments,
          "let relative = [x0, &format!(\"{}{}-{}{}\", x1, x2, x3, x4),",
          "  &format!(\"{}{}-{}{}\", x5, x6, x7, x8), x9].join(\"/\");",
          "let fixture_a = read_bounded_root_file(root, &relative, 1);",
          "let fixture_b = read_verified(root, &relative, 1, hash, context);",
          ""
        ].join("\n")
      )
      confinement = fixture_confinement(
        release_path,
        current_paths: [],
        future_paths: ["crates/release-eval/src/frozen.rs"]
      )
      source = File.binread(File.join(root, relative))
      assert(
        !P02V3Validation.release_reference?(source, confinement),
        "subtoken fixture unexpectedly matched lexical release references"
      )
      assert_failure("outside the reviewed mutable inventory") do
        P02V3Validation.scan_loader_sources!(
          root,
          confinement,
          [relative]
        )
      end
    end
  end

  def test_io_capability_inventory_rejects_modified_parent_blob
    Dir.mktmpdir("p02-v3-parent-blob-fixture.") do |root|
      environment = fixture_command_environment
      git = lambda do |*arguments|
        stdout, stderr = P02V3Validation.capture_bounded_subprocess(
          "/usr/bin/git",
          arguments,
          environment,
          stdout_limit: 16 * 1024,
          stderr_limit: 16 * 1024
        )
        assert(stderr.empty?, "fixture Git command emitted stderr")
        stdout
      end
      git.call("init", "--quiet", root)
      git.call("-C", root, "config", "user.name", "FIXTURE_TECNICA")
      git.call("-C", root, "config", "user.email", "fixture.invalid")
      relative = "crates/FIXTURE_TECNICA/src/existing.rs"
      FileUtils.mkdir_p(File.dirname(File.join(root, relative)))
      File.binwrite(File.join(root, relative), "// FIXTURE_TECNICA\n")
      git.call("-C", root, "add", relative)
      git.call("-C", root, "commit", "--quiet", "-m", "FIXTURE_TECNICA")
      baseline = git.call("-C", root, "rev-parse", "HEAD").strip

      codes = "#{fixture_release_root}/heldout.jsonl".bytes.join(",")
      File.binwrite(
        File.join(root, relative),
        [
          "let bytes = [#{codes}];",
          "let relative = String::from_utf8(bytes.to_vec()).unwrap();",
          "let fixture_a = read_bounded_root_file;",
          "let fixture_b = read_verified;",
          "let _ = fixture_a(root, &relative, 1);",
          "let _ = fixture_b(root, &relative, 1, hash, context);",
          ""
        ].join("\n")
      )
      confinement = fixture_confinement(
        "#{fixture_release_root}/heldout.jsonl",
        current_paths: [],
        future_paths: []
      )
      confinement["source_io_baseline_commit"] = baseline
      source = File.binread(File.join(root, relative))
      assert(
        !source.match?(P02V3Validation::IO_OPERATION_PATTERN),
        "aliased-reader fixture unexpectedly matched the I/O syntax scan"
      )
      assert_failure("authorization-parent source blob differs") do
        P02V3Validation.scan_loader_sources!(root, confinement)
      end
    end
  end

  def test_io_capability_inventory_accepts_unchanged_predeclared_parent_blob
    Dir.mktmpdir("p02-v3-parent-blob-fixture.") do |root|
      environment = fixture_command_environment
      git = lambda do |*arguments|
        stdout, stderr = P02V3Validation.capture_bounded_subprocess(
          "/usr/bin/git",
          arguments,
          environment,
          stdout_limit: 16 * 1024,
          stderr_limit: 16 * 1024
        )
        assert(stderr.empty?, "fixture Git command emitted stderr")
        stdout
      end
      git.call("init", "--quiet", root)
      git.call("-C", root, "config", "user.name", "FIXTURE_TECNICA")
      git.call("-C", root, "config", "user.email", "fixture.invalid")
      relative = "crates/FIXTURE_TECNICA/src/existing.rs"
      FileUtils.mkdir_p(File.dirname(File.join(root, relative)))
      File.binwrite(
        File.join(root, relative),
        "const FIXTURE_TECNICA: &str = \"UNCHANGED\";\n"
      )
      git.call("-C", root, "add", relative)
      git.call("-C", root, "commit", "--quiet", "-m", "FIXTURE_TECNICA")
      baseline = git.call("-C", root, "rev-parse", "HEAD").strip

      confinement = fixture_confinement(
        "#{fixture_release_root}/heldout.jsonl",
        current_paths: [],
        future_paths: []
      )
      confinement["source_io_baseline_commit"] = baseline
      confinement["future_mutable_source_paths"] = [relative]
      assert(
        P02V3Validation.scan_loader_sources!(root, confinement),
        "unchanged authorization-parent source did not pass"
      )
    end
  end

  def test_io_capability_inventory_requires_marker_for_changed_predeclared_blob
    Dir.mktmpdir("p02-v3-parent-blob-fixture.") do |root|
      environment = fixture_command_environment
      git = lambda do |*arguments|
        stdout, stderr = P02V3Validation.capture_bounded_subprocess(
          "/usr/bin/git",
          arguments,
          environment,
          stdout_limit: 16 * 1024,
          stderr_limit: 16 * 1024
        )
        assert(stderr.empty?, "fixture Git command emitted stderr")
        stdout
      end
      git.call("init", "--quiet", root)
      git.call("-C", root, "config", "user.name", "FIXTURE_TECNICA")
      git.call("-C", root, "config", "user.email", "fixture.invalid")
      relative = "crates/FIXTURE_TECNICA/src/existing.rs"
      FileUtils.mkdir_p(File.dirname(File.join(root, relative)))
      File.binwrite(
        File.join(root, relative),
        "const FIXTURE_TECNICA: &str = \"ORIGINAL\";\n"
      )
      git.call("-C", root, "add", relative)
      git.call("-C", root, "commit", "--quiet", "-m", "FIXTURE_TECNICA")
      baseline = git.call("-C", root, "rev-parse", "HEAD").strip

      File.binwrite(
        File.join(root, relative),
        "const FIXTURE_TECNICA: &str = \"CHANGED\";\n"
      )
      confinement = fixture_confinement(
        "#{fixture_release_root}/heldout.jsonl",
        current_paths: [],
        future_paths: []
      )
      confinement["source_io_baseline_commit"] = baseline
      confinement["future_mutable_source_paths"] = [relative]
      assert_failure("mutable source boundary marker is missing") do
        P02V3Validation.scan_loader_sources!(root, confinement)
      end

      File.binwrite(
        File.join(root, relative),
        [
          "# FIXTURE_TECNICA_MUTABLE_SOURCE_BOUNDARY",
          "const FIXTURE_TECNICA: &str = \"CHANGED\";",
          ""
        ].join("\n")
      )
      assert(
        P02V3Validation.scan_loader_sources!(root, confinement),
        "marked changed predeclared source did not pass"
      )
    end
  end

  def test_loader_confinement_accepts_marked_future_frozen_rust_reader
    Dir.mktmpdir("p02-v3-loader-fixture.") do |root|
      relative = "crates/release-eval/src/frozen.rs"
      FileUtils.mkdir_p(File.dirname(File.join(root, relative)))
      release_root = fixture_release_root
      release_path = [release_root, "performance" + ".jsonl"].join("/")
      File.binwrite(
        File.join(root, relative),
        [
          "// FIXTURE_TECNICA_BOUNDARY",
          "let fixture = read_bounded_root_file(#{release_path.inspect});",
          ""
        ].join("\n")
      )
      assert(
        P02V3Validation.scan_loader_sources!(
          root,
          fixture_confinement(
            release_path,
            current_paths: [],
            future_paths: [relative]
          ),
          [relative]
        ),
        "marked future frozen reader did not pass"
      )
    end
  end

  def test_loader_confinement_rejects_unmarked_future_frozen_rust_reader
    Dir.mktmpdir("p02-v3-loader-fixture.") do |root|
      relative = "crates/release-eval/src/frozen.rs"
      FileUtils.mkdir_p(File.dirname(File.join(root, relative)))
      release_root = fixture_release_root
      release_path = [release_root, "heldout" + ".jsonl"].join("/")
      File.binwrite(
        File.join(root, relative),
        "let fixture = read_verified(#{release_path.inspect});\n"
      )
      assert_failure("boundary marker is missing") do
        P02V3Validation.scan_loader_sources!(
          root,
          fixture_confinement(
            release_path,
            current_paths: [],
            future_paths: [relative]
          ),
          [relative]
        )
      end
    end
  end

  def test_loader_confinement_rejects_source_ancestor_symlink_escape
    Dir.mktmpdir("p02-v3-loader-fixture.") do |parent|
      root = File.join(parent, "FIXTURE_TECNICA-root")
      outside = File.join(parent, "FIXTURE_TECNICA-outside")
      relative = "crates/FIXTURE_TECNICA/src/rogue.rs"
      FileUtils.mkdir_p(root)
      FileUtils.mkdir_p(File.dirname(File.join(outside, relative)))
      File.binwrite(
        File.join(outside, relative),
        "// FIXTURE_TECNICA\n"
      )
      File.symlink(
        File.join(outside, "crates"),
        File.join(root, "crates")
      )
      release_root = fixture_release_root
      release_path = [release_root, "heldout" + ".jsonl"].join("/")
      assert_failure("symlink component") do
        P02V3Validation.scan_loader_sources!(
          root,
          fixture_confinement(
            release_path,
            current_paths: [],
            future_paths: []
          ),
          [relative]
        )
      end
    end
  end

  def test_self_test_source_has_no_release_record_loader
    source = P02V3Validation.read_regular(
      __FILE__,
      1024 * 1024,
      "FIXTURE_TECNICA self-test source",
      root: P02V3Corpus::ROOT
    )
    prohibited = [
      "P02V3Corpus::" + "DATA_ROOT",
      "P02V3Validation::" + "Validator.new",
      [fixture_release_root, "heldout" + ".jsonl"].join("/"),
      [fixture_release_root, "performance" + ".jsonl"].join("/")
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
    puts "P02_V3_VALIDATION_TESTS_PASS"
  end
end

P02V3ValidationTests.run
