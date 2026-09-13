# frozen_string_literal: true
# P02V3_FUTURE_MUTABLE_SOURCE_BOUNDARY_V1

require "fileutils"
require "open3"
require "stringio"
require "tmpdir"
require_relative "promote-p14-noise-sources"
require_relative "validate-p14"

module P14ValidationTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure(message)
    yield
    raise "expected P14Validation::Failure"
  rescue P14Validation::Failure => error
    assert(error.message.include?(message), "failure message #{message.inspect}")
  end

  def assert_noise_failure(message)
    yield
    raise "expected P14NoiseSourcePromotion::Failure"
  rescue P14NoiseSourcePromotion::Failure => error
    assert(error.message.include?(message), "failure message #{message.inspect}")
  end

  def capture_streams
    original_stdout = $stdout
    original_stderr = $stderr
    captured_stdout = StringIO.new
    captured_stderr = StringIO.new
    $stdout = captured_stdout
    $stderr = captured_stderr
    result = yield
    [result, captured_stdout.string, captured_stderr.string]
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end

  def unittest_output(results, reported: results.length, completion: "OK")
    evidence = results.map do |identity, status|
      "#{identity} ... #{status}\n"
    end.join
    evidence +
      "----------------------------------------------------------------------\n" \
      "Ran #{reported} tests in 0.25s\n\n#{completion}\n"
  end

  def expected_companion_results
    P14Validation::EXPECTED_COMPANION_TEST_IDENTITIES.map do |identity|
      owner, separator, method = identity.rpartition(".")
      raise "invalid companion identity fixture" if separator.empty?

      ["#{method} (#{owner})", "ok"]
    end
  end

  def run_process(command, chdir:)
    stdout, stderr, status = Open3.capture3(
      P14Validation::BASE_ENVIRONMENT,
      *command,
      unsetenv_others: true,
      chdir: chdir
    )
    return stdout if status.success?

    raise "fixture command failed: #{command.join(' ')}: #{stderr.strip}"
  end

  def git(root, *arguments)
    run_process(["/usr/bin/git", *arguments], chdir: root)
  end

  def create_git_subject(parent)
    root = File.join(parent, "subject")
    FileUtils.mkdir_p(root)
    git(root, "init", "--quiet")
    File.binwrite(File.join(root, "fixture.txt"), "FIXTURE_TECNICA\n")
    git(root, "add", "fixture.txt")
    git(
      root,
      "-c",
      "user.name=FIXTURE_TECNICA",
      "-c",
      "user.email=fixture@example.invalid",
      "commit",
      "--quiet",
      "-m",
      "fixture"
    )
    [
      root,
      git(root, "rev-parse", "HEAD").strip,
      git(root, "rev-parse", "HEAD^{tree}").strip
    ]
  end

  def tar_string(header, offset, length)
    header.byteslice(offset, length).split("\0", 2).first.to_s
  end

  def tar_octal(header, offset, length)
    value = tar_string(header, offset, length).strip
    raise "invalid tar numeric fixture" unless value.match?(/\A[0-7]+\z/)

    value.to_i(8)
  end

  def extract_git_tar(archive, destination)
    bytes = File.binread(archive)
    offset = 0
    directory_modes = []
    loop do
      header = bytes.byteslice(offset, 512)
      raise "truncated tar fixture" unless header&.bytesize == 512
      break if header == ("\0" * 512)

      name = tar_string(header, 0, 100)
      prefix = tar_string(header, 345, 155)
      name = "#{prefix}/#{name}" unless prefix.empty?
      size = tar_octal(header, 124, 12)
      mode = tar_octal(header, 100, 8)
      type = header.byteslice(156, 1)
      payload = bytes.byteslice(offset + 512, size)
      raise "truncated tar payload fixture" unless payload&.bytesize == size
      offset += 512 + ((size + 511) / 512 * 512)

      next if %w[g x].include?(type)
      components = name.split("/")
      if name.start_with?("/") || components.any? { |part| part == ".." }
        raise "unsafe tar path fixture"
      end
      target = File.join(destination, name)
      case type
      when "5"
        FileUtils.mkdir_p(target)
        directory_modes << [target, mode]
      when "0", "\0"
        FileUtils.mkdir_p(File.dirname(target))
        File.binwrite(target, payload)
        File.chmod(mode, target)
      else
        raise "unsupported tar entry fixture: #{type.inspect}"
      end
    end
    directory_modes.reverse_each { |path, mode| File.chmod(mode, path) }
    true
  end

  def direct_summary(
    binaries: 28,
    harness_binaries: 27,
    tests: 225,
    passed: 222,
    ignored: 3,
    measured: 0,
    filtered_out: 0,
    harnessless: 1,
    failed_binaries: 0,
    clippy_targets: 38
  )
    source_root = P14Validation::ROOT
    targets = P14RustcDriver.test_targets(source_root)
    harness_targets = targets.select { |target| target.fetch(:harness) }
    first_passed = passed - (harness_targets.length - 1)
    raise "invalid fixture pass count" if first_passed.negative?

    rust_evidence = targets.map do |target|
      prefix =
        "P14_RUST_TEST_RESULT package=#{target.fetch(:package)} " \
        "target=#{target.fetch(:id)} harness=#{target.fetch(:harness)}"
      if target.fetch(:harness)
        index = harness_targets.index(target)
        target_passed = index.zero? ? first_passed : 1
        target_ignored = index.zero? ? ignored : 0
        target_measured = index.zero? ? measured : 0
        target_filtered = index.zero? ? filtered_out : 0
        "#{prefix} passed=#{target_passed} ignored=#{target_ignored} " \
          "measured=#{target_measured} filtered_out=#{target_filtered}\n"
      else
        "#{prefix} status=ok\n"
      end
    end.join
    clippy_evidence = P14RustcDriver.owned_lint_targets(source_root).map do |target|
      "P14_CLIPPY_RESULT target=#{target} status=pass\n"
    end.join
    rust_evidence + clippy_evidence +
      "P14_DIRECT_RUST_TEST_SUMMARY binaries=#{binaries} " \
      "harness_binaries=#{harness_binaries} tests=#{tests} " \
      "passed=#{passed} ignored=#{ignored} measured=#{measured} " \
      "filtered_out=#{filtered_out} harnessless=#{harnessless} " \
      "failed_binaries=#{failed_binaries}\n" \
      "P14_DIRECT_CLIPPY_PASS targets=#{clippy_targets}\n" \
      "P14_DIRECT_RUSTC_BUILD_PASS\n"
  end

  def test_unittest_count_is_dynamic_and_closed
    results = [
      ["test_alpha (test_fixture.FixtureTests)", "ok"],
      ["test_beta (test_fixture.FixtureTests)", "ok"]
    ]
    output = unittest_output(results)
    assert(P14Validation.parse_unittest_count(output) == 2, "dynamic count")
    assert(
      P14Validation.validate_companion_evidence(
        P14Validation.parse_unittest_evidence(
          unittest_output(expected_companion_results)
        )
      ) == P14Validation::EXPECTED_COMPANION_TESTS,
      "exact companion identity set"
    )
    vacuous = P14Validation::EXPECTED_COMPANION_TESTS.times.map do |index|
      [
        format(
          "test_vacuous_%03d (test_vacuous.VacuousTests)",
          index
        ),
        "ok"
      ]
    end
    assert_failure("identities differ") do
      P14Validation.validate_companion_evidence(
        P14Validation.parse_unittest_evidence(unittest_output(vacuous))
      )
    end
    wrong = expected_companion_results
    wrong[-1] = [
      "test_count_correct_but_wrong (test_vacuous.VacuousTests)",
      "ok"
    ]
    assert_failure("identities differ") do
      P14Validation.validate_companion_evidence(
        P14Validation.parse_unittest_evidence(unittest_output(wrong))
      )
    end
    assert_failure("machine-verifiable PASS") do
      P14Validation.parse_unittest_count(
        unittest_output(results, completion: "FAILED")
      )
    end
    assert_failure("machine-verifiable PASS") do
      P14Validation.parse_unittest_count(output + output)
    end
    assert_failure("duplicate tests") do
      duplicate = [
        ["test_alpha (test_fixture.FixtureTests)", "ok"],
        ["test_alpha (test_fixture.FixtureTests)", "ok"]
      ]
      P14Validation.parse_unittest_count(unittest_output(duplicate))
    end
    assert_failure("skipped or failed") do
      skipped = [
        ["test_alpha (test_fixture.FixtureTests)", "skipped 'fixture'"]
      ]
      P14Validation.parse_unittest_count(
        unittest_output(skipped, completion: "OK (skipped=1)") + "OK\n"
      )
    end
    assert_failure("count differs") do
      P14Validation.parse_unittest_count(
        unittest_output(results, reported: 76)
      )
    end
    assert_failure("diagnostic text") do
      P14Validation.parse_unittest_count(
        output.sub("\nOK\n", "\nOK\nFIXTURE_TECNICA_DIAGNOSTIC\n")
      )
    end
    first_identities = P14Validation.parse_unittest_evidence(
      unittest_output(expected_companion_results)
    )
    second_identities = P14Validation.parse_unittest_evidence(
      unittest_output(expected_companion_results).sub(
        "in 0.25s",
        "in 91.75s"
      )
    )
    first_marker = P14Validation.companion_execution_marker(
      first_identities
    )
    second_marker = P14Validation.companion_execution_marker(
      second_identities
    )
    assert(first_marker == second_marker, "timing-free companion marker")
    assert(!first_marker.include?("0.25"), "elapsed time is not replayed")
  end

  def test_direct_summary_rejects_failures_and_count_regression
    passing = direct_summary
    result = P14Validation.parse_direct_summary(passing)
    assert(result.fetch(:passed) == 222, "Rust passed count")
    assert(result.fetch(:clippy_targets) == 38, "Clippy target count")

    assert_failure("differs from target evidence") do
      P14Validation.parse_direct_summary(
        passing.sub("failed_binaries=0", "failed_binaries=1")
      )
    end
    assert_failure("pass count differs") do
      P14Validation.parse_direct_summary(
        direct_summary(tests: 224, passed: 221)
      )
    end
  end

  def test_direct_summary_rejects_duplicates_and_impossible_counts
    passing = direct_summary
    summary_line = passing.lines.find do |line|
      line.start_with?("P14_DIRECT_RUST_TEST_SUMMARY ")
    end
    assert_failure("not unique") do
      P14Validation.parse_direct_summary(passing + summary_line)
    end
    assert_failure("duplicate keys") do
      P14Validation.parse_direct_summary(
        passing.sub(
          "failed_binaries=0",
          "passed=999 failed_binaries=0"
        )
      )
    end
    assert_failure("duplicate keys") do
      P14Validation.parse_direct_summary(
        passing.sub(
          "filtered_out=0 harnessless=",
          "filtered_out=0 filtered_out=0 harnessless="
        )
      )
    end
    assert_failure("differs from target evidence") do
      P14Validation.parse_direct_summary(
        direct_summary(
          binaries: 0,
          harness_binaries: 0,
          tests: 205
        )
      )
    end
    assert_failure("skipped or filtered") do
      P14Validation.parse_direct_summary(
        direct_summary(tests: 1_204, filtered_out: 999)
      )
    end
    assert_failure("Clippy target count differs") do
      P14Validation.parse_direct_summary(
        direct_summary(clippy_targets: 999)
      )
    end
    assert_failure("not unique") do
      P14Validation.parse_direct_summary(
        passing + "P14_DIRECT_CLIPPY_PASS targets=38\n"
      )
    end
    assert_failure("not unique") do
      P14Validation.parse_direct_summary(
        passing + "P14_DIRECT_RUSTC_BUILD_PASS\n"
      )
    end
  end

  def test_direct_summary_requires_bijective_target_records
    passing = direct_summary
    rust_line = passing.lines.find do |line|
      line.start_with?("P14_RUST_TEST_RESULT ")
    end
    clippy_line = passing.lines.find do |line|
      line.start_with?("P14_CLIPPY_RESULT ")
    end
    assert_failure("missing a target") do
      P14Validation.parse_direct_summary(passing.sub(rust_line, ""))
    end
    assert_failure("duplicated") do
      P14Validation.parse_direct_summary(passing + rust_line)
    end
    assert_failure("missing a target") do
      P14Validation.parse_direct_summary(passing.sub(clippy_line, ""))
    end
    assert_failure("duplicated") do
      P14Validation.parse_direct_summary(passing + clippy_line)
    end
  end

  def test_metadata_evidence_rejects_duplicate_skip_and_wrong_identity
    passing = P14Validation::EXPECTED_METADATA_TESTS.sort.map do |name|
      "PASS #{name}\n"
    end.join + "P14_ADDON_METADATA_TESTS_PASS\n"
    assert(
      P14Validation.parse_metadata_count(passing) == 8,
      "exact metadata evidence"
    )
    duplicate = ("PASS test_addon_manifest\n" * 8) +
      "P14_ADDON_METADATA_TESTS_PASS\n"
    assert_failure("duplicate tests") do
      P14Validation.parse_metadata_count(duplicate)
    end
    assert_failure("skipped test") do
      P14Validation.parse_metadata_count(passing + "SKIP test_fixture\n")
    end
    assert_failure("identities differ") do
      P14Validation.parse_metadata_count(
        passing.sub("PASS test_addon_manifest", "PASS test_unbound")
      )
    end
    assert_failure("output differs") do
      P14Validation.parse_metadata_count(
        passing + "FIXTURE_TECNICA_DIAGNOSTIC\n"
      )
    end
    assert_failure("output differs") do
      reordered = passing.lines
      reordered[0], reordered[1] = reordered[1], reordered[0]
      P14Validation.parse_metadata_count(reordered.join)
    end
    assert_failure("output differs") do
      P14Validation.parse_metadata_count("\n" + passing)
    end
    assert_failure("output differs") do
      P14Validation.parse_metadata_count(
        passing.sub("PASS test_addon_manifest", " PASS test_addon_manifest")
      )
    end
    assert_failure("output differs") do
      P14Validation.parse_metadata_count(passing.gsub("\n", "\r\n"))
    end
  end

  def test_host_python_identity_rejects_warning_and_extra_output
    passing = [
      "(3, 9, 6)",
      P14Validation::PYTHON_RUNTIME,
      File.dirname(P14Validation::PYTHON_FRAMEWORK)
    ].join("\n") + "\n"
    assert(
      P14Validation.validate_host_python_identity_output(passing),
      "exact host Python identity"
    )
    assert(
      P14Validation.python_environment.fetch("TMPDIR") == "/private/tmp",
      "host Python has an explicit private temporary directory"
    )
    warning =
      "python3: warning: confstr() failed with code 5: couldn't get path of " \
      "DARWIN_USER_TEMP_DIR; using /tmp instead\n"
    assert_failure("runtime identity differs") do
      P14Validation.validate_host_python_identity_output(passing + warning)
    end
    assert_failure("runtime identity differs") do
      P14Validation.validate_host_python_identity_output(
        passing + "FIXTURE_TECNICA_DIAGNOSTIC\n"
      )
    end
  end

  def test_success_output_rejects_credential_canaries
    assert(
      P14Validation.validate_no_credential_canary(
        "FIXTURE_TECNICA_PUBLIC",
        "fixture",
        "stdout"
      ),
      "noncredential fixture output"
    )
    assert_failure("credential canary on stdout") do
      P14Validation.validate_no_credential_canary(
        "FIXTURE_TECNICA_CREDENTIAL_00000",
        "fixture",
        "stdout"
      )
    end
    assert_failure("credential canary on stderr") do
      P14Validation.validate_no_credential_canary(
        "FIXTURE_TECNICA_CREDENTIAL_00000",
        "fixture",
        "stderr"
      )
    end
    [0, 7].each do |status|
      %w[STDOUT STDERR].each do |stream|
        error = nil
        _result, outer_stdout, outer_stderr = capture_streams do
          begin
            P14Validation.run_command(
              [
                "/usr/bin/ruby",
                "--disable-gems",
                "-e",
                "#{stream}.write(" \
                "'#{P14Validation::CREDENTIAL_CANARY}'); exit #{status}"
              ],
              "canary mutation"
            )
          rescue P14Validation::Failure => captured
            error = captured
          end
        end
        assert(error, "canary command fails closed")
        assert(
          error.message.include?("credential canary on #{stream.downcase}"),
          "safe canary failure identifies the stream"
        )
        assert(
          !error.message.include?(P14Validation::CREDENTIAL_CANARY),
          "canary is absent from the validator error"
        )
        assert(
          !outer_stdout.include?(P14Validation::CREDENTIAL_CANARY),
          "canary is absent from validator stdout"
        )
        assert(
          !outer_stderr.include?(P14Validation::CREDENTIAL_CANARY),
          "canary is absent from validator stderr"
        )
      end
    end
  end

  def test_file_identity_rejects_size_and_hash_substitution
    Dir.mktmpdir("FIXTURE_TECNICA_p14_validator", "/private/tmp") do |directory|
      path = File.join(directory, "FIXTURE_TECNICA_input")
      File.binwrite(path, "FIXTURE_TECNICA")
      digest = Digest::SHA256.file(path).hexdigest
      assert(P14Validation.validate_file(path, digest, 15), "exact file")
      assert_failure("size differs") do
        P14Validation.validate_file(path, digest, 14)
      end
      assert_failure("SHA-256 differs") do
        P14Validation.validate_file(path, "0" * 64, 15)
      end
    end
  end

  def test_governance_gate_is_exact_and_mandatory
    subject = {
      commit: "a" * 40,
      tree: "b" * 40
    }
    passing_output =
      "governance validation passed " \
      "(commit #{subject.fetch(:commit)}, tree #{subject.fetch(:tree)}, " \
      "rows #{P14Validation::GOVERNANCE_NORMATIVE_ROWS_SHA256}, " \
      "1 requirements)\n"
    assert(
      P14Validation.validate_governance_output(passing_output, subject),
      "exact governance child output"
    )
    hostile_output =
      passing_output + "FIXTURE_TECNICA_GOVERNANCE_DIAGNOSTIC\n"
    _result, outer_stdout, outer_stderr = capture_streams do
      assert_failure("validation marker differs") do
        output = P14Validation.run_command(
          [
            "/usr/bin/ruby",
            "--disable-gems",
            "-e",
            "STDOUT.write(ARGV.fetch(0))",
            hostile_output
          ],
          "FIXTURE_TECNICA governance child",
          emit: false
        )
        P14Validation.validate_governance_output(output, subject)
      end
    end
    assert(outer_stdout.empty?, "hostile governance output is not re-emitted")
    assert(outer_stderr.empty?, "governance rejection has no stderr output")
    assert_failure("validation marker differs") do
      P14Validation.validate_governance_output(
        passing_output.delete_suffix("\n"),
        subject
      )
    end

    command = P14Validation.governance_validation_command(subject)
    expected = [
      File.join(P14Validation::ROOT, "tools/validate-governance"),
      "--root", P14Validation::ROOT,
      "--expected-commit", subject.fetch(:commit),
      "--expected-tree", subject.fetch(:tree),
      "--expected-normative-rows-sha256",
      P14Validation::GOVERNANCE_NORMATIVE_ROWS_SHA256,
      "--expected-validate-launcher-sha256",
      P14Validation::GOVERNANCE_FILE_SHA256.fetch(
        "tools/validate-governance"
      ),
      "--expected-validator-source-sha256",
      P14Validation::GOVERNANCE_FILE_SHA256.fetch(
        "tools/validate-governance.rb"
      ),
      "--expected-test-launcher-sha256",
      P14Validation::GOVERNANCE_FILE_SHA256.fetch(
        "tools/test-validate-governance"
      ),
      "--expected-test-source-sha256",
      P14Validation::GOVERNANCE_FILE_SHA256.fetch(
        "tools/test-validate-governance.rb"
      )
    ]
    assert(command == expected, "exact governance subject and review tuple")
    assert(
      P14Validation.validate_governance_local_tuple,
      "governance tuple reproduces current protected files"
    )
    Dir.mktmpdir(
      "FIXTURE_TECNICA_p14_governance_tuple",
      "/private/tmp"
    ) do |root|
      tools = File.join(root, "tools")
      FileUtils.mkdir_p(tools)
      P14Validation::GOVERNANCE_FILE_SHA256.each_key do |path|
        FileUtils.cp(
          File.join(P14Validation::ROOT, path),
          File.join(root, path)
        )
      end
      substituted = File.join(root, "tools/validate-governance.rb")
      File.binwrite(
        substituted,
        File.binread(substituted) + "\n# FIXTURE_TECNICA_SUBSTITUTION\n"
      )
      assert_failure("review tuple file differs") do
        P14Validation.validate_governance_local_tuple(root)
      end
    end

    missing = P14Validation::GOVERNANCE_FILE_SHA256.dup
    missing.delete("tools/test-validate-governance.rb")
    assert_failure("file SHA-256 tuple is incomplete") do
      P14Validation.validate_governance_bindings(
        P14Validation::GOVERNANCE_NORMATIVE_ROWS_SHA256,
        missing
      )
    end
    changed = P14Validation::GOVERNANCE_FILE_SHA256.merge(
      "tools/validate-governance.rb" => "0" * 64
    )
    assert_failure("file SHA-256 tuple differs") do
      P14Validation.validate_governance_bindings(
        P14Validation::GOVERNANCE_NORMATIVE_ROWS_SHA256,
        changed
      )
    end
    assert_failure("normative-row SHA-256 differs") do
      P14Validation.validate_governance_bindings(
        "0" * 64,
        P14Validation::GOVERNANCE_FILE_SHA256
      )
    end

    source = File.binread(File.join(__dir__, "validate-p14.rb"))
    assert(
      source.scan(/^\s{4}run_governance_gate\(subject\)$/).length == 1,
      "P14 run path invokes exact governance once"
    )
  end

  def test_host_tool_evidence_requires_rights_and_independent_reviews
    evidence = P14Validation.load_host_tool_evidence
    assert(
      P14Validation.validate_host_tool_evidence(evidence),
      "complete exact host-tool evidence"
    )

    missing_rights = Marshal.load(Marshal.dump(evidence))
    missing_rights.fetch("companion_test_runtime")
      .fetch("source")
      .delete("rights_evidence")
    assert_failure("companion Python rights evidence differs") do
      P14Validation.validate_host_tool_evidence(missing_rights)
    end

    missing_review = Marshal.load(Marshal.dump(evidence))
    missing_review.fetch("home_assistant_gate_runtime")
      .fetch("tools")
      .fetch("ruby")
      .delete("independent_review_roles")
    assert_failure("Home Assistant gate Ruby evidence differs") do
      P14Validation.validate_host_tool_evidence(missing_review)
    end

    missing_component_review = Marshal.load(Marshal.dump(evidence))
    missing_component_review.fetch("validation_ruby_components")
      .fetch("components")
      .fetch("psych")
      .delete("independent_review_roles")
    assert_failure("Ruby component rights evidence differs") do
      P14Validation.validate_host_tool_evidence(missing_component_review)
    end

    shell = Marshal.load(Marshal.dump(evidence))
    shell.fetch("home_assistant_gate_runtime")
      .fetch("tools")["shell"] = { "path" => "/bin/sh" }
    assert_failure("Home Assistant gate tool set differs") do
      P14Validation.validate_host_tool_evidence(shell)
    end

    Dir.mktmpdir("FIXTURE_TECNICA_p14_host_yaml", "/private/tmp") do |root|
      duplicate = File.join(root, "duplicate.yaml")
      File.binwrite(duplicate, "schema_version: 2\nschema_version: 2\n")
      assert_failure("duplicate YAML keys") do
        P14Validation.load_yaml_document(
          duplicate,
          "FIXTURE_TECNICA host evidence"
        )
      end
    end
  end

  def test_home_assistant_launcher_is_admitted_ruby_without_shell_helpers
    source = File.binread(
      File.join(P14Validation::ROOT, "tools/validate-p14-ha")
    )
    assert(
      P14Validation.validate_ha_launcher_source(source),
      "admitted Ruby Home Assistant launcher"
    )
    assert_failure("launcher must use the admitted Ruby shebang") do
      P14Validation.validate_ha_launcher_source(
        source.sub(/\A[^\n]+/, "#!/bin/sh")
      )
    end
    assert_failure("launcher selects a prohibited shell helper") do
      P14Validation.validate_ha_launcher_source(
        source + "\n# /usr/bin/dirname\n"
      )
    end
  end

  def test_home_assistant_child_output_grammars_are_closed
    passing = P14Validation.home_assistant_success_output
    assert(
      P14Validation.validate_home_assistant_success_output(passing, ""),
      "exact Home Assistant success output"
    )
    assert_failure("identity gate output differs") do
      P14Validation.validate_home_assistant_success_output(
        passing + "FIXTURE_TECNICA_HA_DIAGNOSTIC\n",
        ""
      )
    end
    malformed = passing.sub(
      "P14_HA_SOURCE_IDENTITY_PASS ",
      "P14_HA_SOURCE_IDENTITY_PASS_MALFORMED "
    )
    assert_failure("identity gate output differs") do
      P14Validation.validate_home_assistant_success_output(malformed, "")
    end
    assert_failure("identity gate output differs") do
      P14Validation.validate_home_assistant_success_output(
        passing,
        "FIXTURE_TECNICA_HA_STDERR\n"
      )
    end

    fallback = P14Validation::FROZEN_HA_RESPONSE_FAILURES.fetch(0)
    assert(
      P14Validation.validate_home_assistant_fallback_failure(
        "",
        "#{fallback}\n"
      ),
      "exact Home Assistant fallback failure output"
    )
    host_warning =
      "git: warning: confstr() failed with code 5: couldn't get path of " \
      "DARWIN_USER_TEMP_DIR; using /tmp instead\n"
    assert_failure("identity gate failed") do
      P14Validation.validate_home_assistant_fallback_failure(
        "",
        host_warning + "#{fallback}\n"
      )
    end
    assert_failure("identity gate failed") do
      P14Validation.validate_home_assistant_fallback_failure(
        "FIXTURE_TECNICA_HA_STDOUT\n",
        "#{fallback}\n"
      )
    end
    assert_failure("identity gate failed") do
      P14Validation.validate_home_assistant_fallback_failure(
        "",
        "#{fallback}\nFIXTURE_TECNICA_HA_DIAGNOSTIC\n"
      )
    end
  end

  def test_noise_evidence_binds_historical_and_current_schema_tuples
    evidence = P14Validation.load_noise_identity_evidence
    assert(
      P14Validation.validate_noise_identity_evidence(evidence),
      "exact historical and current Noise identity tuples"
    )

    historical = Marshal.load(Marshal.dump(evidence))
    historical.fetch("historical")["manifest_blob"] = "0" * 40
    assert_failure("historical Noise identity tuple differs") do
      P14Validation.validate_noise_identity_evidence(historical)
    end

    current = Marshal.load(Marshal.dump(evidence))
    current.fetch("current")["tree_digest_domain"] = "P14_NOISE_TREE_V2"
    assert_failure("current Noise identity tuple differs") do
      P14Validation.validate_noise_identity_evidence(current)
    end

    aggregate = Marshal.load(Marshal.dump(evidence))
    aggregate.fetch("current")["aggregate_package_tree_sha256"] = "0" * 64
    assert_failure("current Noise identity tuple differs") do
      P14Validation.validate_noise_identity_evidence(aggregate)
    end

    assert_failure("duplicate JSON keys") do
      P14Validation.parse_unique_json(
        "{\"schema_version\":1,\"schema_version\":3}",
        "FIXTURE_TECNICA Noise evidence"
      )
    end

    candidate = P14Validation.git_output(
      P14Validation::ROOT,
      "rev-parse",
      "HEAD^{commit}"
    ).strip
    assert(
      P14Validation.validate_noise_identity_history(
        root: P14Validation::ROOT,
        candidate_commit: candidate,
        evidence: evidence
      ),
      "Noise evidence resolves to exact Git objects"
    )
    assert_failure("current Noise manifest blob differs") do
      P14Validation.validate_noise_identity_history(
        root: P14Validation::ROOT,
        candidate_commit:
          P14Validation::HISTORICAL_NOISE_IDENTITY.fetch("commit"),
        evidence: evidence
      )
    end
  end

  def test_noise_source_child_output_grammar_is_closed
    passing =
      "P14_NOISE_SOURCE_PROMOTION_PASS\n" \
      "P14_NOISE_SOURCE_PACKAGE_COUNT=23\n"
    assert(
      P14Validation.parse_noise_source_output(passing) == 23,
      "exact Noise source child output"
    )
    assert_failure("promotion output differs") do
      P14Validation.parse_noise_source_output(
        passing + "FIXTURE_TECNICA_NOISE_DIAGNOSTIC\n"
      )
    end
    assert_failure("promotion output differs") do
      P14Validation.parse_noise_source_output(
        passing + "P14_NOISE_SOURCE_PROMOTION_PASS\n"
      )
    end
    assert_failure("promotion output differs") do
      P14Validation.parse_noise_source_output(
        passing.delete_suffix("\n")
      )
    end
  end

  def test_noise_promotion_staging_does_not_require_build_output
    observed = nil
    P14NoiseSourcePromotion.with_staging_directory do |directory|
      observed = directory
      assert(
        File.dirname(directory) == "/private/tmp",
        "Noise staging uses admitted temporary root"
      )
    end
    assert(!File.exist?(observed), "Noise staging is removed after use")
  end

  def test_repository_noise_check_binds_cargo_checksum_manifest
    Dir.mktmpdir("FIXTURE_TECNICA_p14_checksum", "/private/tmp") do |directory|
      source = File.join(directory, "lib.rs")
      checksum = File.join(directory, ".cargo-checksum.json")
      contents = "FIXTURE_TECNICA\n"
      File.binwrite(source, contents)
      entries = {
        "lib.rs" => {
          "mode" => "644",
          "contents" => contents
        }
      }
      package = {
        "archive_sha256" => "a" * 64,
        "name" => "aead"
      }
      File.binwrite(
        checksum,
        P13NoiseEvidence.cargo_checksum_manifest(
          entries,
          package.fetch("archive_sha256")
        )
      )
      assert(
        P14NoiseSourcePromotion.validate_cargo_checksum(directory, package),
        "exact promoted Cargo checksum"
      )
      File.binwrite(source, "FIXTURE_TECNICX\n")
      assert_noise_failure("Cargo checksum manifest differs") do
        P14NoiseSourcePromotion.validate_cargo_checksum(directory, package)
      end
      File.binwrite(source, contents)
      File.chmod(0o755, checksum)
      assert_noise_failure("missing or executable") do
        P14NoiseSourcePromotion.validate_cargo_checksum(directory, package)
      end
    end
  end

  def test_repository_noise_check_binds_p13_projected_tree
    Dir.mktmpdir("FIXTURE_TECNICA_p14_projection", "/private/tmp") do |directory|
      source = File.join(directory, "lib.rs")
      File.binwrite(source, "FIXTURE_TECNICA\n")
      File.chmod(0o644, source)
      projection = {
        "name" => "FIXTURE_TECNICA",
        "projected_tree_sha256" =>
          "a92dc6a759b7673295dc64070ce65c44d5da0cca2bbb588c642d3c2102513991"
      }
      assert(
        P14NoiseSourcePromotion.validate_promoted_projection(
          directory,
          projection
        ),
        "exact P13 projected-tree witness"
      )
      File.binwrite(source, "FIXTURE_TECNICX\n")
      assert_noise_failure("P13 projected tree differs") do
        P14NoiseSourcePromotion.validate_promoted_projection(
          directory,
          projection
        )
      end
      File.binwrite(source, "FIXTURE_TECNICA\n")
      File.chmod(0o755, source)
      assert_noise_failure("P13 projected tree differs") do
        P14NoiseSourcePromotion.validate_promoted_projection(
          directory,
          projection
        )
      end
    end
  end

  def test_noise_promotion_binds_complete_entry_identity
    Dir.mktmpdir("FIXTURE_TECNICA_p14_modes", "/private/tmp") do |directory|
      expected = File.join(directory, "expected")
      actual = File.join(directory, "actual")
      Dir.mkdir(expected)
      Dir.mkdir(actual)
      File.chmod(0o750, expected)
      File.chmod(0o700, actual)
      expected_file = File.join(expected, "fixture.rs")
      actual_file = File.join(actual, "fixture.rs")
      File.binwrite(expected_file, "FIXTURE_TECNICA")
      File.binwrite(actual_file, "FIXTURE_TECNICA")
      File.chmod(0o400, expected_file)
      File.chmod(0o600, actual_file)
      assert(
        P14NoiseSourcePromotion.check_directory(expected, actual).nil?,
        "non-Git permission residue is ignored"
      )

      baseline_digest = P14NoiseSourcePromotion.tree_sha256(actual)
      File.chmod(0o700, actual_file)
      assert_noise_failure("identity differs") do
        P14NoiseSourcePromotion.check_directory(expected, actual)
      end
      File.chmod(0o600, actual_file)
      assert(
        P14NoiseSourcePromotion.tree_sha256(actual) == baseline_digest,
        "non-executable Git mode is restored"
      )

      expected_subdirectory = File.join(expected, "nested")
      actual_subdirectory = File.join(actual, "nested")
      Dir.mkdir(expected_subdirectory, 0o750)
      Dir.mkdir(actual_subdirectory, 0o700)
      assert(
        P14NoiseSourcePromotion.check_directory(expected, actual).nil?,
        "directory permission residue is ignored"
      )
      directory_digest = P14NoiseSourcePromotion.tree_sha256(actual)
      File.chmod(0o755, actual_subdirectory)
      assert(
        P14NoiseSourcePromotion.tree_sha256(actual) == directory_digest,
        "Noise digest excludes untracked directory permissions"
      )
      actual_only_directory = File.join(actual, "empty")
      Dir.mkdir(actual_only_directory, 0o700)
      assert(
        P14NoiseSourcePromotion.tree_sha256(actual) == directory_digest,
        "untracked empty directories are excluded from Noise identity"
      )
      assert(
        P14NoiseSourcePromotion.check_directory(expected, actual).nil?,
        "empty directory residue does not change Git identity"
      )

      executable_expected = File.join(expected, "tool")
      executable_actual = File.join(actual, "tool")
      File.binwrite(executable_expected, "FIXTURE_TECNICA")
      File.binwrite(executable_actual, "FIXTURE_TECNICA")
      File.chmod(0o500, executable_expected)
      File.chmod(0o755, executable_actual)
      assert(
        P14NoiseSourcePromotion.check_directory(expected, actual).nil?,
        "executable permission residue is ignored"
      )
      executable_digest = P14NoiseSourcePromotion.tree_sha256(actual)
      File.chmod(0o644, executable_actual)
      assert(
        P14NoiseSourcePromotion.tree_sha256(actual) != executable_digest,
        "Noise digest binds executable versus non-executable Git mode"
      )
      File.chmod(0o755, executable_actual)

      File.binwrite(actual_file, "FIXTURE_TECNICX")
      assert_noise_failure("identity differs") do
        P14NoiseSourcePromotion.check_directory(expected, actual)
      end
      File.binwrite(actual_file, "FIXTURE_TECNICA")

      renamed = File.join(actual, "renamed.rs")
      File.rename(actual_file, renamed)
      assert_noise_failure("identity differs") do
        P14NoiseSourcePromotion.check_directory(expected, actual)
      end
      File.rename(renamed, actual_file)

      assert(
        P14NoiseSourcePromotion.check_directory(expected, actual).nil?,
        "matching Noise paths, bytes, and Git modes"
      )

      actual_symlink = File.join(actual, "linked.rs")
      File.symlink("fixture.rs", actual_symlink)
      assert_noise_failure("symlink prohibited") do
        P14NoiseSourcePromotion.check_directory(expected, actual)
      end
      File.unlink(actual_symlink)

      actual_fifo = File.join(actual, "pipe")
      File.mkfifo(actual_fifo, 0o600)
      assert_noise_failure("unsupported entry") do
        P14NoiseSourcePromotion.check_directory(expected, actual)
      end
      File.unlink(actual_fifo)

      expected_hardlink = File.join(expected, "second.rs")
      actual_hardlink = File.join(actual, "second.rs")
      File.binwrite(expected_hardlink, "FIXTURE_TECNICA")
      File.chmod(0o400, expected_hardlink)
      File.link(actual_file, actual_hardlink)
      assert_noise_failure("hard-linked file prohibited") do
        P14NoiseSourcePromotion.check_directory(expected, actual)
      end
    end
  end

  def test_noise_identity_reproduces_in_checkout_and_git_archive
    Dir.mktmpdir("FIXTURE_TECNICA_p14_git_modes", "/private/tmp") do |directory|
      repository = File.join(directory, "repository")
      package = File.join(repository, "package")
      FileUtils.mkdir_p(package)
      git(repository, "init", "--quiet")
      regular = File.join(package, "regular.rs")
      executable = File.join(package, "tool")
      File.binwrite(regular, "FIXTURE_TECNICA_REGULAR\n")
      File.binwrite(executable, "FIXTURE_TECNICA_EXECUTABLE\n")
      File.chmod(0o644, regular)
      File.chmod(0o755, executable)
      git(repository, "add", "package")
      git(
        repository,
        "-c",
        "user.name=FIXTURE_TECNICA",
        "-c",
        "user.email=fixture@example.invalid",
        "commit",
        "--quiet",
        "-m",
        "fixture"
      )

      File.chmod(0o700, package)
      File.chmod(0o400, regular)
      File.chmod(0o500, executable)
      assert(
        git(repository, "status", "--porcelain=v1").empty?,
        "permission residue does not change the Git subject"
      )
      source_digest = P14NoiseSourcePromotion.tree_sha256(package)

      checkout = File.join(directory, "checkout")
      run_process(
        [
          "/usr/bin/git",
          "clone",
          "--quiet",
          "--no-hardlinks",
          repository,
          checkout
        ],
        chdir: directory
      )
      checkout_package = File.join(checkout, "package")
      checkout_digest = P14NoiseSourcePromotion.tree_sha256(checkout_package)
      assert(checkout_digest == source_digest, "no-hardlink checkout identity")
      Dir.glob(File.join(checkout_package, "**", "*")).each do |path|
        next unless File.file?(path)

        assert(File.lstat(path).nlink == 1, "checkout file is not hard-linked")
      end

      archive = File.join(directory, "subject.tar")
      git(
        repository,
        "archive",
        "--format=tar",
        "--output=#{archive}",
        "HEAD"
      )
      extraction = File.join(directory, "archive")
      FileUtils.mkdir_p(extraction)
      extract_git_tar(archive, extraction)
      archive_package = File.join(extraction, "package")
      archive_digest = P14NoiseSourcePromotion.tree_sha256(archive_package)
      assert(archive_digest == source_digest, "git-archive identity")
      assert(
        P14NoiseSourcePromotion.check_directory(package, checkout_package).nil?,
        "checkout reproduces complete Noise identity"
      )
      assert(
        P14NoiseSourcePromotion.check_directory(package, archive_package).nil?,
        "archive reproduces complete Noise identity"
      )

      File.chmod(0o755, File.join(checkout_package, "regular.rs"))
      assert(
        P14NoiseSourcePromotion.tree_sha256(checkout_package) != source_digest,
        "checkout executable-mode mutation is detected"
      )
      File.chmod(0o644, File.join(archive_package, "tool"))
      assert(
        P14NoiseSourcePromotion.tree_sha256(archive_package) != source_digest,
        "archive non-executable-mode mutation is detected"
      )
    end
  end

  def test_subject_arguments_and_invocation_are_exact
    commit = "a" * 40
    tree = "2" * 40
    parsed = P14Validation.parse_subject_arguments(
      ["--expected-tree", tree, "--expected-commit", commit]
    )
    assert(parsed == { commit: commit, tree: tree }, "exact subject arguments")
    assert_failure("--expected-commit is required") do
      P14Validation.parse_subject_arguments(["--expected-tree", tree])
    end
    assert_failure("specified more than once") do
      P14Validation.parse_subject_arguments(
        [
          "--expected-commit",
          commit,
          "--expected-commit",
          commit,
          "--expected-tree",
          tree
        ]
      )
    end
    assert_failure("full lowercase 40-hex") do
      P14Validation.parse_subject_arguments(
        ["--expected-commit", commit.upcase, "--expected-tree", tree]
      )
    end
    assert_failure("launcher invocation is not canonical") do
      P14Validation.validate_invocation(
        File.expand_path("test-validate-p14", __dir__),
        File.expand_path("validate-p14.rb", __dir__)
      )
    end
    Dir.mktmpdir("FIXTURE_TECNICA_p14_imports", "/private/tmp") do |root|
      File.binwrite(File.join(root, "unittest.pyc"), "FIXTURE_TECNICA")
      assert_failure("import roots contain ignored bytecode") do
        P14Validation.validate_python_import_roots(root)
      end
    end
    command = P14Validation.companion_test_command(
      "/private/tmp/FIXTURE_TECNICA_cache"
    )
    assert(command.include?("-I"), "isolated Python mode")
    assert(command.include?("-B"), "bytecode writes disabled")
    assert(
      command.none? { |argument| argument == "-m" },
      "unittest is imported before project paths"
    )
  end

  def test_resumed_p14_remediation_scope_contract_is_exact
    assert(
      P14Validation::FINAL_REMEDIATION_BASE ==
        "24be5d64282cc2226b870709f960110656cee008",
      "resumed P14 remediation base"
    )
    assert(
      P14Validation::FINAL_REMEDIATION_PARENT ==
        "24be5d64282cc2226b870709f960110656cee008",
      "resumed P14 remediation parent"
    )
    assert(
      P14Validation::FINAL_REMEDIATION_PATHS == %w[
        custom_components/local_nlu/__init__.py
        custom_components/local_nlu/executor.py
        custom_components/local_nlu/restart_journal.py
        custom_components/local_nlu/runtime.py
        tests/p14_companion/test_ha_runtime.py
        tests/p14_companion/test_setup_lifecycle.py
        tools/test-validate-p14.rb
        tools/validate-p14.rb
      ],
      "resumed P14 remediation path set"
    )
  end

  def test_git_subject_rejects_wrong_identity_and_dirty_state
    Dir.mktmpdir("FIXTURE_TECNICA_p14_subject", "/private/tmp") do |directory|
      root, commit, tree = create_git_subject(directory)
      assert(
        P14Validation.validate_git_subject(
          root: root,
          expected_commit: commit,
          expected_tree: tree
        ) == { commit: commit, tree: tree },
        "clean exact Git subject"
      )
      assert_failure("commit differs") do
        P14Validation.validate_git_subject(
          root: root,
          expected_commit: "0" * 40,
          expected_tree: tree
        )
      end
      assert_failure("tree differs") do
        P14Validation.validate_git_subject(
          root: root,
          expected_commit: commit,
          expected_tree: "0" * 40
        )
      end

      fixture = File.join(root, "fixture.txt")
      File.binwrite(fixture, "FIXTURE_TECNICX\n")
      assert_failure("staged, unstaged, or untracked") do
        P14Validation.validate_git_subject(
          root: root,
          expected_commit: commit,
          expected_tree: tree
        )
      end
      File.binwrite(fixture, "FIXTURE_TECNICA\n")
      untracked = File.join(root, "untracked.txt")
      File.binwrite(untracked, "FIXTURE_TECNICA\n")
      assert_failure("staged, unstaged, or untracked") do
        P14Validation.validate_git_subject(
          root: root,
          expected_commit: commit,
          expected_tree: tree
        )
      end
      File.unlink(untracked)

      git(root, "update-index", "--assume-unchanged", "fixture.txt")
      assert_failure("concealed or unsupported index flags") do
        P14Validation.validate_git_subject(
          root: root,
          expected_commit: commit,
          expected_tree: tree
        )
      end
      git(root, "update-index", "--no-assume-unchanged", "fixture.txt")

      nested = File.join(root, "nested")
      Dir.mkdir(nested)
      assert_failure("root differs from the invocation subject") do
        P14Validation.validate_git_subject(
          root: nested,
          expected_commit: commit,
          expected_tree: tree
        )
      end

      File.binwrite(fixture, "FIXTURE_TECNICA_CHANGED\n")
      git(root, "add", "fixture.txt")
      git(
        root,
        "-c",
        "user.name=FIXTURE_TECNICA",
        "-c",
        "user.email=fixture@example.invalid",
        "commit",
        "--quiet",
        "-m",
        "candidate"
      )
      candidate = git(root, "rev-parse", "HEAD").strip
      git(root, "replace", commit, candidate)
      assert(
        P14Validation.git_output(
          root,
          "rev-parse",
          "#{commit}^{tree}"
        ).strip == tree,
        "Git replacement objects are disabled"
      )
      git(root, "replace", "-d", commit)
      assert(
        P14Validation.validate_final_remediation_scope(
          root: root,
          candidate_commit: candidate,
          authorized_base: commit,
          authorized_parent: commit,
          allowed_paths: ["fixture.txt"]
        ) == {
          base: commit,
          parent: commit,
          changed_paths: ["fixture.txt"]
        },
        "final remediation parent and paths"
      )
      assert_failure("parent differs from authorization") do
        P14Validation.validate_final_remediation_scope(
          root: root,
          candidate_commit: candidate,
          authorized_base: commit,
          authorized_parent: "0" * 40,
          allowed_paths: ["fixture.txt"]
        )
      end
      assert_failure("changed paths exceed authorization") do
        P14Validation.validate_final_remediation_scope(
          root: root,
          candidate_commit: candidate,
          authorized_base: commit,
          authorized_parent: commit,
          allowed_paths: []
        )
      end

      second_fixture = File.join(root, "second-fixture.txt")
      File.binwrite(second_fixture, "FIXTURE_TECNICA_SECOND\n")
      git(root, "add", "second-fixture.txt")
      git(
        root,
        "-c",
        "user.name=FIXTURE_TECNICA",
        "-c",
        "user.email=fixture@example.invalid",
        "commit",
        "--quiet",
        "-m",
        "replacement"
      )
      replacement = git(root, "rev-parse", "HEAD").strip
      assert(
        P14Validation.validate_final_remediation_scope(
          root: root,
          candidate_commit: replacement,
          authorized_base: commit,
          authorized_parent: candidate,
          allowed_paths: ["fixture.txt", "second-fixture.txt"]
        ) == {
          base: commit,
          parent: candidate,
          changed_paths: ["fixture.txt", "second-fixture.txt"]
        },
        "replacement scope spans authorization base and immediate parent"
      )
    end
  end

  def test_frozen_home_assistant_evidence_reuse_is_history_bound
    candidate = P14Validation.git_output(
      P14Validation::ROOT,
      "rev-parse",
      "HEAD^{commit}"
    ).strip
    assert(
      P14Validation.validate_frozen_ha_history(
        root: P14Validation::ROOT,
        candidate_commit: candidate
      ),
      "frozen Home Assistant history binding"
    )
    changed = P14Validation::FROZEN_HA_BLOBS.merge(
      "tools/validate-p14-ha" => "0" * 40
    )
    assert_failure("evidence blob differs") do
      P14Validation.validate_frozen_ha_history(
        root: P14Validation::ROOT,
        candidate_commit: candidate,
        expected_blobs: changed
      )
    end
  end

  def test_noise_manifest_schema_is_closed
    manifest = P14NoiseSourcePromotion.promotion_manifest([])
    assert(
      manifest.fetch("schema_version") ==
        P14NoiseSourcePromotion::MANIFEST_SCHEMA_VERSION,
      "current Noise manifest schema"
    )
    changed = Marshal.load(Marshal.dump(manifest))
    changed["schema_version"] =
      P14NoiseSourcePromotion::MANIFEST_SCHEMA_VERSION - 1
    assert_noise_failure("schema differs") do
      P14NoiseSourcePromotion.validate_promotion_manifest(changed)
    end
  end

  def run
    public_methods(false).grep(/\Atest_/).sort.each { |test| public_send(test) }
    puts "P14_VALIDATOR_TESTS_PASS"
  end
end

P14ValidationTest.run
