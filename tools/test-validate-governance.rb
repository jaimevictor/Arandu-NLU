# frozen_string_literal: true

require "fileutils"
require "digest"
require "open3"
require "tmpdir"
require_relative "validate-governance"

class TestFailure < StandardError; end
PreflightStatus = Struct.new(:successful) do
  def success?
    successful
  end
end

# Synthetic mutation values are opaque FIXTURE_TECNICA or CANARY identifiers.
# They exercise governance structure only and contain no linguistic examples.
class GovernanceValidatorTests
  GIT_SUBPROCESS_ENVIRONMENT = {
    "HOME" => "/var/empty",
    "XDG_CONFIG_HOME" => "/var/empty",
    "GIT_CONFIG_NOSYSTEM" => "1",
    "GIT_CONFIG_SYSTEM" => nil,
    "GIT_CONFIG_GLOBAL" => "/dev/null",
    "GIT_CONFIG_COUNT" => nil,
    "GIT_CONFIG_PARAMETERS" => nil,
    "GIT_ATTR_NOSYSTEM" => "1",
    "GIT_OPTIONAL_LOCKS" => "0",
    "GIT_NO_REPLACE_OBJECTS" => "1",
    "GIT_DIR" => nil,
    "GIT_WORK_TREE" => nil,
    "GIT_INDEX_FILE" => nil,
    "GIT_OBJECT_DIRECTORY" => nil,
    "GIT_ALTERNATE_OBJECT_DIRECTORIES" => nil
  }.freeze

  def initialize
    @source = File.expand_path("..", __dir__)
    @git = GovernanceValidator::GIT_EXECUTABLE
    @passed = 0
    @trusted_normative_rows_sha256 = GovernanceValidator::NORMATIVE_ROWS_SHA256
    @trusted_review_file_sha256 = GovernanceValidator::REVIEW_FILE_MODES.keys.to_h do |path|
      [path, Digest::SHA256.file(File.join(@source, path)).hexdigest]
    end
  end

  def run
    Dir.mktmpdir("nlu-governance-tests.") do |temporary|
      @repository = File.join(temporary, "candidate")
      build_candidate
      @base_commit = git("rev-parse", "HEAD").strip
      @base_tree = git("rev-parse", "HEAD^{tree}").strip

      git_environment_isolation
      expect_success("clean exact subject")
      expect_failure("wrong expected commit", "does not match expected commit") do
        validate(commit: "0" * 40, tree: @base_tree)
      end
      expect_failure("wrong expected tree", "does not match expected tree") do
        validate(commit: @base_commit, tree: "0" * 40)
      end
      launcher_failures
      duplicate_cli_option_failures
      subject_binding_failures
      attested_git_path
      dirty_failures
      yaml_failures
      requirement_failures
      adr_failures
      material_and_tool_failures
      amazon_exclusion_failures
      yaml_extraction_boundary_regressions
      archive_and_secret_failures
      state_failures
      checkpoint_validation
      archive_and_worktree_successes
    end

    puts "governance validator tests passed (#{@passed} cases)"
  end

  private

  def command(
    *argv,
    chdir: @repository,
    allow_failure: false,
    env: {},
    stdin_data: nil
  )
    process_environment = { "LC_ALL" => "C", "LANG" => "C" }.merge(env)
    if argv.first == @git
      process_environment.merge!(GIT_SUBPROCESS_ENVIRONMENT)
    end
    stdout, stderr, status = Open3.capture3(
      process_environment,
      *argv,
      chdir: chdir,
      stdin_data: stdin_data.to_s
    )
    return [stdout, stderr, status] if allow_failure
    raise TestFailure, "#{argv.join(' ')} failed: #{stderr}#{stdout}" unless status.success?

    stdout
  end

  def git_environment_isolation
    config = File.join(File.dirname(@repository), "hostile-system-gitconfig")
    File.binwrite(
      config,
      "[commit]\n\tgpgSign = true\n[gpg]\n\tprogram = /definitely/missing-gpg\n"
    )
    stdout, stderr, status = command(
      @git,
      "config",
      "--get",
      "commit.gpgSign",
      allow_failure: true,
      env: {
        "GIT_CONFIG_NOSYSTEM" => nil,
        "GIT_CONFIG_SYSTEM" => config
      }
    )
    unless status.exitstatus == 1 && stdout.empty? && stderr.empty?
      raise TestFailure,
            "test Git subprocess retained host configuration: #{stderr}#{stdout}"
    end
    launcher = File.binread(File.join(@source, "tools/test-validate-governance"))
    %w[
      GIT_CONFIG_NOSYSTEM=1
      GIT_CONFIG_GLOBAL=/dev/null
      GIT_ATTR_NOSYSTEM=1
    ].each do |assignment|
      unless launcher.lines.first.include?(assignment)
        raise TestFailure,
              "test launcher lacks Git isolation assignment #{assignment}"
      end
    end
    @passed += 1
  ensure
    FileUtils.rm_f(config) if config
  end

  def git(*args, **options)
    command(@git, *args, **options)
  end

  def source_git(*args)
    command(@git, *args, chdir: @source)
  end

  def build_candidate
    command(
      @git,
      "clone",
      "--quiet",
      "--no-hardlinks",
      @source,
      @repository,
      chdir: File.dirname(@repository)
    )
    desired = source_git("ls-files", "--cached", "--others", "--exclude-standard", "-z")
      .split("\0")
      .select { |path| File.file?(File.join(@source, path)) }
    existing = git("ls-files", "-z").split("\0")

    (existing - desired).each { |path| FileUtils.rm_f(File.join(@repository, path)) }
    desired.each do |path|
      source_path = File.join(@source, path)
      target_path = File.join(@repository, path)
      FileUtils.mkdir_p(File.dirname(target_path))
      FileUtils.copy_file(source_path, target_path, true)
    end

    git("config", "user.name", "Governance Test")
    git("config", "user.email", "governance-test.invalid")
    git("add", "--all")
    _stdout, _stderr, clean_index = git("diff", "--cached", "--quiet", allow_failure: true)
    unless clean_index.success?
      git("commit", "--quiet", "-m", "test: construct remediation candidate")
    end
  end

  def validate(
    commit: nil,
    tree: nil,
    env: {},
    preflight: true,
    normative_rows_sha256: nil,
    review_file_sha256: nil,
    checkpoint_subject_commit: nil,
    checkpoint_subject_tree: nil,
    checkpoint_report_sha256: nil
  )
    commit ||= git("rev-parse", "HEAD").strip
    tree ||= git("rev-parse", "HEAD^{tree}").strip
    normative_rows_sha256 ||= @trusted_normative_rows_sha256
    review_file_sha256 ||= @trusted_review_file_sha256
    if preflight &&
       (failure = review_preflight(commit: commit, tree: tree))
      return ["", "governance preflight failed: #{failure}\n", PreflightStatus.new(false)]
    end

    arguments = validation_arguments(
      commit: commit,
      tree: tree,
      normative_rows_sha256: normative_rows_sha256,
      review_file_sha256: review_file_sha256
    )
    if checkpoint_subject_commit || checkpoint_subject_tree
      checkpoint_report_sha256 ||=
        GovernanceCheckpointValidator::REVIEW_PATHS.to_h do |role, path|
          [role, Digest::SHA256.file(File.join(@repository, path)).hexdigest]
        end
      arguments.concat(
        [
          "--checkpoint-subject-commit", checkpoint_subject_commit.to_s,
          "--checkpoint-subject-tree", checkpoint_subject_tree.to_s
        ]
      )
      GovernanceCLI::CHECKPOINT_REPORT_HASH_OPTIONS.each do |key, role|
        arguments.concat(
          [
            "--#{key.to_s.tr('_', '-')}",
            checkpoint_report_sha256.fetch(role)
          ]
        )
      end
    end
    command(
      *arguments,
      allow_failure: true,
      env: env
    )
  end

  def validation_arguments(
    commit:,
    tree:,
    normative_rows_sha256: @trusted_normative_rows_sha256,
    review_file_sha256: @trusted_review_file_sha256
  )
    [
      File.join(@repository, "tools/validate-governance"),
      "--root", @repository,
      "--expected-commit", commit,
      "--expected-tree", tree,
      "--expected-normative-rows-sha256", normative_rows_sha256,
      "--expected-validate-launcher-sha256",
      review_file_sha256.fetch("tools/validate-governance"),
      "--expected-validator-source-sha256",
      review_file_sha256.fetch("tools/validate-governance.rb"),
      "--expected-test-launcher-sha256",
      review_file_sha256.fetch("tools/test-validate-governance"),
      "--expected-test-source-sha256",
      review_file_sha256.fetch("tools/test-validate-governance.rb")
    ]
  end

  def checkpoint_arguments(
    checkpoint_commit:,
    checkpoint_tree:,
    subject_commit:,
    subject_tree:,
    report_sha256:
  )
    arguments = validation_arguments(
      commit: checkpoint_commit,
      tree: checkpoint_tree
    )
    arguments.concat(
      [
        "--checkpoint-subject-commit", subject_commit,
        "--checkpoint-subject-tree", subject_tree
      ]
    )
    GovernanceCLI::CHECKPOINT_REPORT_HASH_OPTIONS.each do |key, role|
      arguments.concat(
        [
          "--#{key.to_s.tr('_', '-')}",
          report_sha256.fetch(role)
        ]
      )
    end
    arguments
  end

  def review_preflight(commit:, tree:)
    head = git("rev-parse", "HEAD").strip
    return "HEAD #{head} does not match expected commit #{commit}" unless head == commit

    actual_tree = git("rev-parse", "HEAD^{tree}").strip
    return "tree #{actual_tree} does not match expected tree #{tree}" unless actual_tree == tree

    GovernanceValidator::REVIEW_FILE_MODES.each do |path, expected_mode|
      entry = git("ls-tree", commit, "--", path).strip
      match = entry.match(/\A(\d{6}) blob [0-9a-f]{40}\t(.+)\z/)
      return "review file is absent or malformed: #{path}" unless match && match[2] == path
      return "review file mode differs: #{path}" unless match[1] == expected_mode

      committed = git("show", "#{commit}:#{path}").b
      expected_hash = @trusted_review_file_sha256.fetch(path)
      return "committed review file differs from tuple: #{path}" unless
        Digest::SHA256.hexdigest(committed) == expected_hash

      worktree_path = File.join(@repository, path)
      begin
        stat = File.lstat(worktree_path)
        return "worktree review file is not regular: #{path}" unless stat.file? && !stat.symlink?
        canonical_worktree_path = File.join(File.realpath(@repository), path)
        return "worktree review file path differs: #{path}" unless
          File.realpath(worktree_path) == canonical_worktree_path
        worktree = File.binread(worktree_path)
      rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
        return "worktree review file cannot be read: #{path}"
      end
      return "worktree review file differs from tuple: #{path}" unless
        worktree == committed && Digest::SHA256.hexdigest(worktree) == expected_hash
    end
    nil
  end

  def expect_success(name)
    stdout, stderr, status = validate
    expected = /\Agovernance validation passed \(commit [0-9a-f]{40}, tree [0-9a-f]{40}, rows [0-9a-f]{64}, \d+ requirements\)\n\z/
    unless status.success? && stdout.match?(expected) && stderr.empty?
      raise TestFailure, "#{name} unexpectedly failed: #{stderr}#{stdout}"
    end
    @passed += 1
  end

  def expect_failure(name, expected_message)
    with_case_repository do
      result = block_given? ? yield : validate
      stdout, stderr, status = result
      if status.success?
        raise TestFailure, "#{name} unexpectedly passed: #{stdout}"
      end
      combined = "#{stderr}#{stdout}"
      unless combined.include?(expected_message)
        raise TestFailure, "#{name} failed for the wrong reason; expected #{expected_message.inspect}, got #{combined.inspect}"
      end
      @passed += 1
    end
  end

  def committed_failure(name, expected_message)
    with_case_repository do
      yield
      git("add", "--all")
      git("commit", "--quiet", "-m", "negative fixture: #{name}")
      stdout, stderr, status = validate
      if status.success?
        raise TestFailure, "#{name} unexpectedly passed: #{stdout}"
      end
      combined = "#{stderr}#{stdout}"
      unless combined.include?(expected_message)
        raise TestFailure, "#{name} failed for the wrong reason; expected #{expected_message.inspect}, got #{combined.inspect}"
      end
      @passed += 1
    end
  end

  def committed_distribution_scan_failure(name, expected_message)
    with_case_repository do
      yield
      distribution = Psych.safe_load(
        File.binread(
          File.join(
            @repository,
            "docs/clean-room/DISTRIBUTION-LICENSES.yaml"
          )
        ),
        [],
        [],
        false
      )
      distribution_digest =
        direct_validator.send(:canonical_digest, distribution)
      refresh_validator_digest_constant(
        "DISTRIBUTION_LICENSES_SHA256",
        distribution_digest
      )
      refresh_validator_digest_constant(
        "P00_NORMATIVE_FILES_SHA256",
        current_normative_files_digest
      )
      git("add", "--all")
      git("commit", "--quiet", "-m", "negative fixture: #{name}")
      review_hashes = GovernanceValidator::REVIEW_FILE_MODES.keys.to_h do |path|
        [path, Digest::SHA256.file(File.join(@repository, path)).hexdigest]
      end
      stdout, stderr, status = validate(
        preflight: false,
        review_file_sha256: review_hashes
      )
      if status.success?
        raise TestFailure, "#{name} unexpectedly passed: #{stdout}"
      end
      combined = "#{stderr}#{stdout}"
      unless combined.include?(expected_message)
        raise TestFailure,
              "#{name} failed for the wrong reason; " \
              "expected #{expected_message.inspect}, got #{combined.inspect}"
      end
      @passed += 1
    end
  end

  def committed_success(name)
    with_case_repository do
      yield
      git("add", "--all")
      git("commit", "--quiet", "-m", "positive fixture: #{name}")
      stdout, stderr, status = validate
      expected = /\Agovernance validation passed \(commit [0-9a-f]{40}, tree [0-9a-f]{40}, rows [0-9a-f]{64}, \d+ requirements\)\n\z/
      unless status.success? && stdout.match?(expected) && stderr.empty?
        raise TestFailure, "#{name} unexpectedly failed: #{stderr}#{stdout}"
      end
      @passed += 1
    end
  end

  def expect_direct_governance_failure(name, expected_message)
    yield
    raise TestFailure, "#{name} unexpectedly passed"
  rescue GovernanceError => error
    unless error.message.include?(expected_message)
      raise TestFailure,
            "#{name} failed for the wrong reason; " \
            "expected #{expected_message.inspect}, got #{error.message.inspect}"
    end
    @passed += 1
  rescue SystemStackError => error
    raise TestFailure, "#{name} leaked SystemStackError: #{error.message}"
  end

  def expect_direct_governance_success(name)
    yield
    @passed += 1
  rescue GovernanceError, SystemStackError => error
    raise TestFailure, "#{name} unexpectedly failed: #{error.message}"
  end

  def direct_validator(expected_commit: "0" * 40)
    GovernanceValidator.new(
      root: @repository,
      expected_commit: expected_commit,
      expected_tree: "0" * 40,
      expected_normative_rows_sha256: @trusted_normative_rows_sha256,
      expected_review_file_sha256: @trusted_review_file_sha256,
      launcher_path: File.join(@repository, "tools/validate-governance")
    )
  end

  def direct_checkpoint_validator
    GovernanceCheckpointValidator.new(
      root: @repository,
      expected_commit: "0" * 40,
      expected_tree: "0" * 40,
      subject_commit: "0" * 40,
      subject_tree: "0" * 40,
      expected_normative_rows_sha256: @trusted_normative_rows_sha256,
      expected_review_file_sha256: @trusted_review_file_sha256,
      expected_review_report_sha256: {},
      launcher_path: File.join(@repository, "tools/validate-governance")
    )
  end

  def with_psych_parse_stream_stack_error
    original = Psych.method(:parse_stream)
    Psych.singleton_class.send(:define_method, :parse_stream) do |*_arguments|
      raise SystemStackError, "FIXTURE_TECNICA_STACK_EXHAUSTION"
    end
    yield
  ensure
    Psych.singleton_class.send(:define_method, :parse_stream, original)
  end

  def with_psych_safe_load_stack_error
    original = Psych.method(:safe_load)
    Psych.singleton_class.send(:define_method, :safe_load) do |*_arguments, **_options|
      raise SystemStackError, "FIXTURE_TECNICA_STACK_EXHAUSTION"
    end
    yield
  ensure
    Psych.singleton_class.send(:define_method, :safe_load, original)
  end

  def sensitive_scan_success(name, content)
    scanner = direct_validator
    scanner.send(:scan_sensitive_content, name, content)
    @passed += 1
  rescue GovernanceError => error
    raise TestFailure, "#{name} unexpectedly failed: #{error.message}"
  end

  def with_case_repository
    base_repository = @repository
    Dir.mktmpdir("case.", File.dirname(base_repository)) do |temporary|
      case_repository = File.join(temporary, "repository")
      command(
        @git, "clone", "--quiet", "--no-hardlinks", base_repository, case_repository,
        chdir: temporary
      )
      @repository = case_repository
      git("config", "user.name", "Governance Test")
      git("config", "user.email", "governance-test.invalid")
      yield
    ensure
      @repository = base_repository
    end
  end

  def write(path, content)
    absolute = File.join(@repository, path)
    FileUtils.mkdir_p(File.dirname(absolute))
    File.binwrite(absolute, content)
  end

  def edit(path)
    content = File.binread(File.join(@repository, path))
    updated = yield(content)
    raise TestFailure, "fixture did not change #{path}" if updated == content

    write(path, updated)
  end

  def replace_once(path, before, after)
    edit(path) do |content|
      raise TestFailure, "fixture text not found in #{path}: #{before.inspect}" unless content.include?(before)

      content.sub(before, after)
    end
  end

  def conceal_same_size_worktree_change(path, before, after)
    unless before.bytesize == after.bytesize
      raise TestFailure, "same-size fixture replacements differ for #{path}"
    end

    git("config", "core.trustctime", "false")
    git("config", "core.checkStat", "minimal")

    absolute = File.join(@repository, path)
    committed = git("show", "HEAD:#{path}").b
    original = File.binread(absolute)
    unless original == committed && original.include?(before)
      raise TestFailure, "same-size fixture precondition differs for #{path}"
    end
    aged_time = Time.at(1_600_000_000)
    File.utime(aged_time, aged_time, absolute)
    git("update-index", "--refresh")
    original_stat = File.stat(absolute)

    changed = original.sub(before, after)
    unless changed.bytesize == original.bytesize && changed != original
      raise TestFailure, "same-size fixture did not mutate #{path}"
    end
    File.binwrite(absolute, changed)
    File.utime(original_stat.atime, original_stat.mtime, absolute)

    status = git("status", "--porcelain=v1", "--untracked-files=all")
    unless status.empty? && File.binread(absolute) != committed
      raise TestFailure, "Git did not conceal the same-size fixture for #{path}: #{status}"
    end
  end

  def refresh_requirement_manifest_digest(field)
    rows = []
    File.foreach(File.join(@repository, "docs/evidence/REQUIREMENTS-TRACEABILITY.md")) do |line|
      next unless line.start_with?("| `")

      columns = line.chomp.split("|", -1)[1..7].map(&:strip)
      id = columns.fetch(0).match(/\A`(.+)`\z/).captures.first
      rows << [id, *columns[1..6]]
    end
    payload = case field
              when "normative_rows_sha256"
                rows.map { |row| row[0, 6].join("\t") }.join("\n") + "\n"
              when "p00_statuses_sha256"
                rows.map { |row| [row[0], row[6]].join("\t") }.join("\n") + "\n"
              else
                raise TestFailure, "unknown requirement digest field #{field}"
              end
    digest = Digest::SHA256.hexdigest(payload)
    edit("docs/evidence/REQUIREMENTS-MANIFEST.yaml") do |content|
      content.sub(/^#{Regexp.escape(field)}: [0-9a-f]{64}$/, "#{field}: #{digest}")
    end
    digest
  end

  def refresh_validator_digest_constant(name, digest)
    edit("tools/validate-governance.rb") do |content|
      pattern = /(  #{Regexp.escape(name)} =\n    ")[0-9a-f]{64}(")/
      raise TestFailure, "validator digest constant not found: #{name}" unless content.match?(pattern)

      content.sub(pattern, "\\1#{digest}\\2")
    end
  end

  def current_normative_files_digest
    payload = GovernanceValidator::P00_NORMATIVE_FILES.sort.map do |path|
      "#{path}\0".b + File.binread(File.join(@repository, path)) + "\0".b
    end.join
    Digest::SHA256.hexdigest(payload)
  end

  def launcher_failures
    with_case_repository do
      temporary = File.dirname(@repository)
      marker = File.join(temporary, "rubyopt-preload-executed")
      preload = File.join(temporary, "rubyopt-preload.rb")
      File.binwrite(
        preload,
        <<~RUBY
          File.binwrite(#{marker.inspect}, "FIXTURE_TECNICA")
          at_exit do
            puts "governance validation passed (forged)"
            exit 0
          end
        RUBY
      )
      stdout, stderr, status = validate(
        commit: "0" * 40,
        tree: "0" * 40,
        env: { "RUBYOPT" => "-r#{preload}" },
        preflight: false
      )
      if status.success? || File.exist?(marker) ||
         !("#{stderr}#{stdout}".include?("does not match expected commit"))
        raise TestFailure, "sanitized launcher allowed Ruby startup preload: #{stderr}#{stdout}"
      end
      @passed += 1
    end

    committed_failure("validator launcher bytes changed", "committed review file differs from tuple") do
      edit("tools/validate-governance") { |content| "#{content}\n# altered launcher\n" }
    end

    committed_failure("test launcher bytes changed", "committed review file differs from tuple") do
      edit("tools/test-validate-governance") { |content| "#{content}\n# altered launcher\n" }
    end

    committed_failure("validator source bytes changed", "committed review file differs from tuple") do
      edit("tools/validate-governance.rb") { |content| "#{content}\n# altered source\n" }
    end

    committed_failure("test source bytes changed", "committed review file differs from tuple") do
      edit("tools/test-validate-governance.rb") { |content| "#{content}\n# altered source\n" }
    end

    GovernanceValidator::REVIEW_FILE_MODES.each do |path, mode|
      replacement = mode == "100755" ? 0o644 : 0o755
      committed_failure("#{path} mode changed", "review file mode differs") do
        File.chmod(replacement, File.join(@repository, path))
      end
    end

    required_options = %w[
      --expected-commit
      --expected-tree
      --expected-normative-rows-sha256
      --expected-validate-launcher-sha256
      --expected-validator-source-sha256
      --expected-test-launcher-sha256
      --expected-test-source-sha256
    ]
    required_options.each do |option|
      arguments = validation_arguments(commit: @base_commit, tree: @base_tree)
      index = arguments.index(option)
      arguments.slice!(index, 2)
      stdout, stderr, status = command(*arguments, allow_failure: true)
      unless !status.success? && "#{stderr}#{stdout}".include?("is required")
        raise TestFailure, "missing tuple option was accepted: #{option}"
      end
      @passed += 1
    end

    required_options.each do |option|
      arguments = validation_arguments(commit: @base_commit, tree: @base_tree)
      index = arguments.index(option)
      arguments[index + 1] = "malformed"
      stdout, stderr, status = command(*arguments, allow_failure: true)
      unless !status.success? &&
             "#{stderr}#{stdout}".match?(
               /invalid|must be (?:a full|64) lowercase/
             )
        raise TestFailure, "malformed tuple option was accepted: #{option}"
      end
      @passed += 1
    end

    GovernanceValidator::REVIEW_FILE_MODES.each_key do |path|
      with_case_repository do
        hashes = @trusted_review_file_sha256.merge(path => "0" * 64)
        stdout, stderr, status = validate(review_file_sha256: hashes)
        unless !status.success? &&
               "#{stderr}#{stdout}".include?(
                 "committed review file differs from the review tuple"
               )
          raise TestFailure, "substituted tuple hash was accepted for #{path}"
        end
        @passed += 1
      end
    end

    with_case_repository do
      stdout, stderr, status = validate(normative_rows_sha256: "0" * 64)
      unless !status.success? &&
             "#{stderr}#{stdout}".include?("tuple normative-row digest differs")
        raise TestFailure, "substituted normative-row digest was accepted"
      end
      @passed += 1
    end

    with_case_repository do
      stdout, stderr, status = command(
        "/usr/bin/ruby",
        "--disable-gems",
        File.join(@repository, "tools/validate-governance.rb"),
        allow_failure: true
      )
      if status.success? ||
         !("#{stderr}#{stdout}".include?("invoke tools/validate-governance"))
        raise TestFailure, "direct validator source invocation was not rejected"
      end
      @passed += 1
    end

    with_case_repository do
      copy_directory = File.join(File.dirname(@repository), "copied-validator")
      FileUtils.mkdir_p(copy_directory)
      copied_launcher = File.join(copy_directory, "validate-governance")
      copied_source = File.join(copy_directory, "validate-governance.rb")
      FileUtils.copy_file(
        File.join(@repository, "tools/validate-governance"),
        copied_launcher,
        true
      )
      FileUtils.copy_file(
        File.join(@repository, "tools/validate-governance.rb"),
        copied_source,
        true
      )

      arguments = validation_arguments(commit: @base_commit, tree: @base_tree)
      arguments[0] = copied_launcher
      stdout, stderr, status = command(*arguments, allow_failure: true)
      unless !status.success? &&
             "#{stderr}#{stdout}".include?("executing launcher path is not canonical")
        raise TestFailure,
              "copied validator launcher/source pair was accepted: #{stderr}#{stdout}"
      end

      source_arguments = validation_arguments(
        commit: @base_commit,
        tree: @base_tree
      ).drop(1)
      stdout, stderr, status = command(
        "/usr/bin/env",
        "-i",
        "HOME=/var/empty",
        "PATH=/usr/bin:/bin",
        "LC_ALL=C",
        "LANG=C",
        "TZ=UTC",
        "/usr/bin/ruby",
        "--disable-gems",
        "-e",
        "require ARGV.shift; launcher = ARGV.shift; " \
          "GovernanceCLI.run(ARGV, launcher_path: launcher)",
        copied_source,
        File.join(@repository, "tools/validate-governance"),
        *source_arguments,
        allow_failure: true
      )
      unless !status.success? &&
             "#{stderr}#{stdout}".include?("executing validator path is not canonical")
        raise TestFailure,
              "copied validator source was accepted: #{stderr}#{stdout}"
      end
      @passed += 1
    end

    %w[
      RUBYLIB
      GEM_HOME
      GEM_PATH
      BUNDLE_GEMFILE
    ].each do |key|
      with_case_repository do
        stdout, stderr, status = validate(
          env: { key => "/FIXTURE_TECNICA/#{key.downcase}" },
          preflight: false
        )
        unless status.success? && stderr.empty? &&
               stdout.start_with?("governance validation passed")
          raise TestFailure, "sanitized launcher retained #{key}: #{stderr}#{stdout}"
        end
        @passed += 1
      end
    end

    with_case_repository do
      injected = {
        "LC_ALL" => "FIXTURE_TECNICA_LOCALE",
        "LANG" => "FIXTURE_TECNICA_LOCALE",
        "TZ" => "FIXTURE_TECNICA_ZONE",
        "GIT_DIR" => "/FIXTURE_TECNICA/git",
        "GIT_WORK_TREE" => "/FIXTURE_TECNICA/worktree",
        "GIT_CONFIG_GLOBAL" => "/FIXTURE_TECNICA/config",
        "GIT_ALTERNATE_OBJECT_DIRECTORIES" => "/FIXTURE_TECNICA/objects"
      }
      stdout, stderr, status = validate(env: injected, preflight: false)
      unless status.success? && stderr.empty? &&
             stdout.start_with?("governance validation passed")
        raise TestFailure, "sanitized launcher retained locale or Git environment: #{stderr}#{stdout}"
      end
      @passed += 1
    end
  end

  def duplicate_cli_option_failures
    arguments = validation_arguments(commit: @base_commit, tree: @base_tree)
    option = "--expected-commit"
    index = arguments.index(option)
    duplicated = arguments.dup
    duplicated.insert(index, option, "0" * 40)
    stdout, stderr, status = command(*duplicated, allow_failure: true)
    unless !status.success? &&
           "#{stderr}#{stdout}".include?("#{option} specified more than once")
      raise TestFailure,
            "duplicate subject option was accepted: #{stderr}#{stdout}"
    end
    @passed += 1

    report_option = "--expected-review-risk-sha256"
    duplicated = arguments + [
      report_option, "0" * 64,
      report_option, "1" * 64
    ]
    stdout, stderr, status = command(*duplicated, allow_failure: true)
    unless !status.success? &&
           "#{stderr}#{stdout}".include?(
             "#{report_option} specified more than once"
           )
      raise TestFailure,
            "duplicate checkpoint option was accepted: #{stderr}#{stdout}"
    end
    @passed += 1
  end

  def subject_binding_failures
    expect_failure("replacement root subject", "clean root commit differs") do
      tree = git("rev-parse", "HEAD^{tree}").strip
      root = git("commit-tree", tree, "-m", "FIXTURE_TECNICA replacement root").strip
      subject = git(
        "commit-tree",
        tree,
        "-p",
        root,
        "-m",
        "FIXTURE_TECNICA replacement-root subject"
      ).strip
      git("update-ref", "HEAD", subject)
      validate(commit: subject, tree: tree)
    end

    expect_failure("skip-worktree cannot conceal committed bytes", "skip-worktree, assume-unchanged") do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Exclude Amazon-specific and Amazon-internal material.",
        "Require Amazon-specific and Amazon-internal material."
      )
      git("add", "docs/evidence/REQUIREMENTS-TRACEABILITY.md")
      git("commit", "--quiet", "-m", "negative fixture: committed bad requirement")
      bad_commit = git("rev-parse", "HEAD").strip
      bad_tree = git("rev-parse", "HEAD^{tree}").strip
      good_bytes = git(
        "show",
        "#{@base_commit}:docs/evidence/REQUIREMENTS-TRACEABILITY.md"
      )
      write("docs/evidence/REQUIREMENTS-TRACEABILITY.md", good_bytes)
      git("update-index", "--skip-worktree", "docs/evidence/REQUIREMENTS-TRACEABILITY.md")
      validate(commit: bad_commit, tree: bad_tree)
    end
  end

  def attested_git_path
    with_case_repository do
      fake_bin = File.join(File.dirname(@repository), "fake-bin")
      marker = File.join(File.dirname(@repository), "path-git-executed")
      FileUtils.mkdir_p(fake_bin)
      wrapper = <<~RUBY
        #!/usr/bin/ruby
        File.binwrite(#{marker.inspect}, "FIXTURE_TECNICA")
        exec("/usr/bin/git", *ARGV)
      RUBY
      wrapper_path = File.join(fake_bin, "git")
      File.binwrite(wrapper_path, wrapper)
      File.chmod(0o755, wrapper_path)

      stdout, stderr, status = validate(
        env: { "PATH" => "#{fake_bin}:#{ENV.fetch('PATH', '')}" }
      )
      unless status.success? && stdout.include?("governance validation passed")
        raise TestFailure, "attested Git path unexpectedly failed: #{stderr}#{stdout}"
      end
      raise TestFailure, "PATH Git wrapper was executed" if File.exist?(marker)

      @passed += 1
    end
  end

  def dirty_failures
    expect_failure("untracked file", "staged, unstaged, or untracked") do
      write("UNTRACKED", "fixture\n")
      validate(commit: @base_commit, tree: @base_tree)
    end
    expect_failure("unstaged file", "staged, unstaged, or untracked") do
      File.open(File.join(@repository, "README.md"), "ab") { |file| file.write("\nfixture\n") }
      validate(commit: @base_commit, tree: @base_tree)
    end
    expect_failure("staged file", "staged, unstaged, or untracked") do
      File.open(File.join(@repository, "README.md"), "ab") { |file| file.write("\nfixture\n") }
      git("add", "README.md")
      validate(commit: @base_commit, tree: @base_tree)
    end
    expect_failure("skip-worktree flag", "skip-worktree, assume-unchanged") do
      git("update-index", "--skip-worktree", "README.md")
      File.open(File.join(@repository, "README.md"), "ab") { |file| file.write("\nfixture\n") }
      validate(commit: @base_commit, tree: @base_tree)
    end
    expect_failure("assume-unchanged flag", "skip-worktree, assume-unchanged") do
      git("update-index", "--assume-unchanged", "README.md")
      File.open(File.join(@repository, "README.md"), "ab") { |file| file.write("\nfixture\n") }
      validate(commit: @base_commit, tree: @base_tree)
    end
    expect_failure(
      "same-size dirty subject hidden by minimal stat",
      "review subject worktree file differs from committed bytes or mode: README.md"
    ) do
      conceal_same_size_worktree_change(
        "README.md",
        "Deterministic PT-BR NLU",
        "deterministic PT-BR NLU"
      )
      validate(commit: @base_commit, tree: @base_tree)
    end
  end

  def yaml_failures
    committed_failure("malformed YAML", "invalid YAML") do
      write("docs/phases/PROJECT-STATUS.md", "mode: [unterminated\n")
    end
    committed_failure("duplicate YAML key", "duplicate YAML key") do
      edit("docs/phases/PROJECT-STATUS.md") { |content| "#{content}state: REVIEWING\n" }
    end
    committed_failure(
      "attributed backtick YAML fence",
      "duplicate YAML key"
    ) do
      write(
        "README.md",
        [
          "# FIXTURE_TECNICA",
          "",
          "```yaml title=FIXTURE_TECNICA",
          "provider: FIXTURE_TECNICA",
          "provider: FIXTURE_TECNICA",
          "```",
          ""
        ].join("\n")
      )
    end
    expect_direct_governance_failure(
      "lone-CR attributed YAML fence",
      "Amazon-owned provider metadata"
    ) do
      direct_validator.send(
        :scan_amazon_content,
        "FIXTURE_TECNICA.md",
        "```yaml title=FIXTURE_TECNICA\rprovider: A%57S\r```\r"
      )
    end
    committed_failure("tagged semantic duplicate YAML key", "tagged YAML mapping key") do
      edit("docs/phases/PROJECT-STATUS.md") do |content|
        "#{content}!!binary c3RhdGU=: REVIEWING\n"
      end
    end
    committed_failure("YAML merge key", "YAML merge keys are prohibited") do
      edit("docs/phases/PROJECT-STATUS.md") do |content|
        "#{content}<<: {fixture_key: FIXTURE_TECNICA}\n"
      end
    end
    committed_failure("YAML alias", "YAML aliases are prohibited") do
      edit("docs/phases/PROJECT-STATUS.md") do |content|
        "#{content}fixture_key: *undefined_fixture\n"
      end
    end
    committed_failure("semantic numeric YAML keys", "non-string-safe YAML key") do
      edit("docs/phases/PROJECT-STATUS.md") do |content|
        "#{content}1: blocked_fixture\n01: harmless_fixture\n"
      end
    end
    committed_failure("semantic boolean YAML keys", "non-string semantic YAML key") do
      edit("docs/phases/PROJECT-STATUS.md") do |content|
        "#{content}true: blocked_fixture\nTrue: colliding_fixture\n"
      end
    end
    committed_failure("deeply nested YAML", "YAML AST exceeds depth limit") do
      content = "leaf: FIXTURE_TECNICA\n"
      70.times do |index|
        content = "level#{index}:\n" +
          content.each_line.map { |line| "  #{line}" }.join
      end
      write("docs/phases/PROJECT-STATUS.md", content)
    end
    deeply_nested_value = "FIXTURE_TECNICA"
    65.times { deeply_nested_value = [deeply_nested_value] }
    expect_direct_governance_failure(
      "subject semantic YAML value depth",
      "YAML value exceeds depth limit"
    ) do
      direct_validator.send(
        :reject_non_string_yaml_keys,
        deeply_nested_value,
        "FIXTURE_TECNICA.yaml"
      )
    end
    expect_direct_governance_failure(
      "checkpoint semantic YAML value depth",
      "checkpoint YAML value exceeds depth limit"
    ) do
      direct_checkpoint_validator.send(
        :reject_non_string_yaml_keys,
        deeply_nested_value,
        "FIXTURE_TECNICA.yaml"
      )
    end
    expect_direct_governance_failure(
      "subject YAML parser stack exhaustion",
      "invalid YAML in docs/phases/PROJECT-STATUS.md: " \
      "FIXTURE_TECNICA_STACK_EXHAUSTION"
    ) do
      with_psych_parse_stream_stack_error do
        direct_validator(expected_commit: @base_commit).send(
          :strict_yaml,
          "docs/phases/PROJECT-STATUS.md"
        )
      end
    end
    expect_direct_governance_failure(
      "checkpoint YAML parser stack exhaustion",
      "invalid checkpoint YAML in docs/phases/PROJECT-STATUS.md: " \
      "FIXTURE_TECNICA_STACK_EXHAUSTION"
    ) do
      with_psych_parse_stream_stack_error do
        direct_checkpoint_validator.send(
          :yaml,
          @base_commit,
          "docs/phases/PROJECT-STATUS.md"
        )
      end
    end
    expect_direct_governance_failure(
      "embedded YAML parser stack exhaustion",
      "embedded YAML parser stack exhausted"
    ) do
      with_psych_parse_stream_stack_error do
        direct_validator.send(
          :parse_embedded_yaml,
          "---\nfixtureKey: FIXTURE_TECNICA\n",
          "FIXTURE_TECNICA.md",
          "$"
        )
      end
    end
    expect_direct_governance_failure(
      "YAML assignment parser stack exhaustion",
      "YAML assignment parser stack exhausted"
    ) do
      with_psych_parse_stream_stack_error do
        direct_validator.send(
          :exact_yaml_fixture_assignment?,
          ["entityId: FIXTURE_TECNICA\n"],
          0,
          0,
          "FIXTURE_TECNICA.md"
        )
      end
    end
    expect_direct_governance_failure(
      "whole-payload YAML parser stack exhaustion",
      "YAML payload parser stack exhausted"
    ) do
      with_psych_parse_stream_stack_error do
        direct_validator.send(
          :parsed_yaml_payloads,
          "---\nfixtureKey: FIXTURE_TECNICA\n",
          "FIXTURE_TECNICA.md"
        )
      end
    end
    expect_direct_governance_failure(
      "YAML mapping-key parser stack exhaustion",
      "YAML mapping-key parser stack exhausted"
    ) do
      with_psych_safe_load_stack_error do
        direct_validator.send(
          :decode_yaml_mapping_key,
          ["provider", nil, nil]
        )
      end
    end
    expect_direct_governance_failure(
      "malformed embedded YAML",
      "invalid embedded YAML payload"
    ) do
      direct_validator.send(
        :parse_embedded_yaml,
        "---\nfixtureKey: FIXTURE_TECNICA\n[\n",
        "FIXTURE_TECNICA.md",
        "$"
      )
    end
    committed_failure(
      "malformed explicit whole-document YAML",
      "invalid YAML payload"
    ) do
      write(
        "README.md",
        "---\n? entityId\n: CANARY_ENTITY_001\n[\n"
      )
    end
    {
      "malformed protected YAML mapping" => "provider: [\n",
      "malformed protected YAML sequence" => "- provider: [\n"
    }.each do |name, payload|
      committed_failure(name, "invalid YAML payload") do
        write("README.md", payload)
      end
    end
    committed_failure("unknown status field", "project status fields differ") do
      edit("docs/phases/PROJECT-STATUS.md") { |content| "#{content}unknown_field: true\n" }
    end
    committed_failure("reordered phase queue", "queued phases contradict") do
      edit("docs/phases/AUTONOMOUS-QUEUE.yaml") do |content|
        prefix, queue = content.split("queued_items:\n", 2)
        entries = queue&.lines
        unless prefix && entries&.first(2)&.all? { |line| line.start_with?("  - ") }
          raise TestFailure, "phase queue lacks two reorderable entries"
        end
        entries[0], entries[1] = entries[1], entries[0]
        "#{prefix}queued_items:\n#{entries.join}"
      end
    end
  end

  def requirement_failures
    expect_direct_governance_success(
      "user decision horizontal whitespace and escaped pipe"
    ) do
      ids = direct_validator.send(
        :user_decision_ids_from_bytes,
        " \t| `USR-001` | FIXTURE_TECNICA \\| retained | MUST | P13 | " \
          "FIXTURE_TECNICA | \t\n"
      )
      raise GovernanceError, "decision row parsed incorrectly" unless
        ids == ["USR-001"]
    end
    expect_direct_governance_success(
      "ordinary prose user decision references are not rows"
    ) do
      ids = direct_validator.send(
        :user_decision_ids_from_bytes,
        "FIXTURE_TECNICA prose cites USR_039 and USR-039.\n" \
          "| FIXTURE_TECNICA prose cites USR_039 | not a decision row |\n"
      )
      raise GovernanceError, "ordinary prose parsed as a decision row" unless
        ids.empty?
    end
    {
      "underscore user decision ID" => "USR_038",
      "suffixed user decision ID" => "USR-038X"
    }.each do |name, malformed_id|
      expect_direct_governance_failure(name, "malformed user decision row") do
        direct_validator.send(
          :user_decision_ids_from_bytes,
          " \t| `#{malformed_id}` | FIXTURE_TECNICA | MUST | P13 | " \
            "FIXTURE_TECNICA | \t\n"
        )
      end
    end
    {
      "bold decorated user decision ID" =>
        "| **USR_039** | FIXTURE_TECNICA | MUST | P13 | FIXTURE_TECNICA |\n",
      "double-backtick user decision ID" =>
        "| ``USR_039`` | FIXTURE_TECNICA | MUST | P13 | FIXTURE_TECNICA |\n",
      "HTML code user decision ID" =>
        "| <code>USR_039</code> | FIXTURE_TECNICA | MUST | P13 | FIXTURE_TECNICA |\n",
      "user decision row missing leading delimiter" =>
        "`USR-039` | FIXTURE_TECNICA | MUST | P13 | FIXTURE_TECNICA |\n",
      "user decision row missing trailing delimiter" =>
        "| `USR-039` | FIXTURE_TECNICA | MUST | P13 | FIXTURE_TECNICA\n"
    }.each do |name, row|
      expect_direct_governance_failure(name, "malformed user decision row") do
        direct_validator.send(:user_decision_ids_from_bytes, row)
      end
    end
    committed_failure(
      "user decision omitted from traceability",
      "user decision and traceability IDs differ"
    ) do
      edit("docs/evidence/REQUIREMENTS-TRACEABILITY.md") do |content|
        content.sub(/^\| `USR-037` \|.*\n/, "")
      end
      edit("docs/evidence/REQUIREMENTS-MANIFEST.yaml") do |content|
        content.sub(/^  - USR-037\n/, "")
      end
    end
    committed_failure(
      "noncontiguous user decision ledger",
      "user decision IDs are not contiguous"
    ) do
      edit("docs/clean-room/USER-DECISIONS.md") do |content|
        content.sub(/^\| `USR-035` \|.*\n/, "")
      end
      edit("docs/evidence/REQUIREMENTS-TRACEABILITY.md") do |content|
        content.sub(/^\| `USR-035` \|.*\n/, "")
      end
      edit("docs/evidence/REQUIREMENTS-MANIFEST.yaml") do |content|
        content.sub(/^  - USR-035\n/, "")
      end
    end
    committed_failure("missing requirement", "requirement IDs differ") do
      edit("docs/evidence/REQUIREMENTS-TRACEABILITY.md") do |content|
        content.lines.reject { |line| line.start_with?("| `ARC-CORE-001`") }.join
      end
    end
    committed_failure("wrong phase owner", "is not owned by its phase") do
      edit("docs/evidence/REQUIREMENTS-TRACEABILITY.md") do |content|
        content.sub(
          /(\| `P01-SPAN-001` \|[^|]+\|[^|]+\|) P01 \|/,
          "\\1 P02 |"
        )
      end
    end
    committed_failure("reversed user prohibition", "normative requirement text changed") do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Exclude Amazon-specific and Amazon-internal material.",
        "Require Amazon-specific and Amazon-internal material."
      )
    end
    committed_failure("critical text protection removed", "critical requirement text manifest differs") do
      edit("docs/evidence/REQUIREMENTS-MANIFEST.yaml") do |content|
        content.sub(/required_text:\n(?:  .+\n?)+\z/, "required_text: {}\n")
      end
    end
    committed_failure("execution-quality priority reversed", "normative requirement text changed") do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Give quality priority over cost, speed, and token volume.",
        "Give cost priority over quality."
      )
    end
    {
      "phase round cap removed" => [
        "Limit every phase to three substantive frozen candidate review rounds: one initial round and at most two blocker-remediation rounds.",
        "Permit unlimited candidate review rounds."
      ],
      "minimum acceptance removed" => [
        "Require the documented minimum acceptance contract for every phase.",
        "Permit phase completion without a minimum acceptance contract."
      ],
      "immediate checkpoint removed" => [
        "Checkpoint the first minimally acceptable baseline immediately without optional refinement.",
        "Continue optional refinement after minimum acceptance."
      ],
      "P3 deferral removed" => [
        "Defer eligible P3 improvements instead of extending a phase review loop.",
        "Extend every phase to remediate every P3."
      ],
      "round exhaustion handling removed" => [
        "Stop a phase as blocked for explicit user scope adjudication when its round budget is exhausted with a P0 through P2 blocker.",
        "Continue refinement after the round budget is exhausted."
      ],
      "remaining P00 cap removed" => [
        "Limit remaining P00 work from 2026-08-26 to the current candidate and at most one blocker-only replacement.",
        "Permit unlimited remaining P00 replacement candidates."
      ]
    }.each do |name, (required, replacement)|
      committed_failure(name, "normative requirement text changed") do
        replace_once(
          "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
          required,
          replacement
        )
      end
    end
    committed_failure(
      "decision precedence obligation removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Apply the documented precedence order before resolving a decision conflict.",
        "Ignore the documented precedence order."
      )
    end
    committed_failure(
      "same-level decision criteria weakened",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "For same-level conflicts choose the safer, fail-closed, licensed, correct, deterministic, simple, and reversible resolution.",
        "For same-level conflicts choose any convenient resolution."
      )
    end
    committed_failure(
      "response-rendering boundary removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Keep response rendering in a component boundary separate from interpretation, policy, and execution.",
        "Permit policy code to render responses directly."
      )
    end
    committed_failure(
      "global AI-origin language prohibition removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Reject model-generated, AI-translated, or unprovenanced language from linguistic artifacts except the exact provenance-bound `PROJECT_AUTHORED_SYNTHETIC` corpus authorized by `USR-016`.",
        "Permit unprovenanced language outside the authorized corpus."
      )
    end
    committed_failure(
      "global sibling implementation prohibition removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Prohibit inspection or use of prior implementations and sibling-directory material throughout every phase.",
        "Permit prior implementations after P00."
      )
    end
    committed_failure(
      "global closed-engine prohibition removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Prohibit inspection or use of a closed engine's code, binaries, models, vocabulary, private formats, traces, outputs, internal behavior, internal names, and heuristics throughout every phase.",
        "Permit closed-engine traces after P00."
      )
    end
    committed_failure(
      "manual edit-tool obligation removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Use `apply_patch` for every manual repository file edit.",
        "Use any file-editing command."
      )
    end
    committed_failure(
      "search fallback obligation removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Use `find` and `grep` for repository search when `rg` is unavailable.",
        "Stop repository search when `rg` is unavailable."
      )
    end
    committed_failure("noncritical normative row changed", "normative requirement rows differ") do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Trace every token to original bytes.",
        "Do not trace every token to original bytes."
      )
    end
    committed_failure("vacuous false-plan suite", "normative requirement rows differ") do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "every frozen coverage class to contain at least one distinct Apache-2.0 provenance-bound case",
        "every frozen coverage class to permit zero cases"
      )
    end
    committed_failure("HA typed-outcome oracle removed", "normative requirement rows differ") do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Exact clarification-or-abstention outcome plus no-effect test",
        "No-effect test"
      )
    end
    committed_failure("DTO privacy made overbroad", "normative requirement rows differ") do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Limit residential values in protocol DTOs to schema-authorized fields required for the current bounded request or typed outcome.",
        "Prevent residential values from entering protocol DTOs."
      )
    end
    committed_failure(
      "unlock sensitivity classification removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Classify every unlock operation as sensitive and require explicit policy confirmation.",
        "Permit unlock operations to remain unclassified."
      )
    end
    committed_failure(
      "source transformation lineage weakened",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Record ordered transformation lineage with immutable transform identities and output hashes.",
        "Record optional transformation notes."
      )
    end
    committed_failure(
      "derivative license lineage removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Record the license expression and obligations for every transformed output and derivative.",
        "Record only the original source license."
      )
    end
    committed_failure(
      "terminal verdict exception removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Permit only PASS or FAIL verdicts in phase review reports; terminal tribunal reports are governed separately.",
        "Permit only PASS or FAIL verdicts in every report."
      )
    end
    committed_failure(
      "semantic timestamp prohibition removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Exclude timestamps, including injected logical or monotonic time values, from semantic results and serialized semantic-result bytes.",
        "Permit explicit timestamps in semantic results."
      )
    end
    committed_failure(
      "semantic random-ID prohibition removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Exclude random identifiers from semantic results and serialized semantic-result bytes.",
        "Permit random identifiers in semantic results."
      )
    end
    committed_failure(
      "Sophia claim role expanded",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Classify every Sophia public product claim as untrusted comparison context and prohibit it from serving as linguistic, implementation, model, rule, gold, or evaluation input.",
        "Permit Sophia public product claims as evaluation inputs."
      )
    end
    committed_failure(
      "lexical transformation lineage removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Attach ordered immutable transformation lineage and derivative-license identity to every imported lexical entry.",
        "Attach only a source name to imported lexical entries."
      )
    end
    committed_failure(
      "YAML scalar-key decoding obligation removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Decode quoted YAML scalar mapping keys before canonical protected-key classification and never suppress structural parsing solely because a broader canonical key resembles a dedicated assignment.",
        "Inspect only literal YAML mapping keys."
      )
    end
    committed_failure(
      "nested malformed HTML obligation removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Preserve a malformed outer HTML tag when an unquoted nested opener appears before its close so the nested tag cannot consume a finding or verdict token.",
        "Strip malformed nested HTML as one tag."
      )
    end
    committed_failure(
      "lone-surrogate JSON obligation removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Classify a malformed JSON key containing a lone UTF-16 surrogate escape as protected when removing only invalid surrogate escapes yields a canonical protected key.",
        "Ignore malformed JSON keys containing lone surrogates."
      )
    end
    committed_failure(
      "angle-destination linearity obligation removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Terminate an unmatched Markdown angle destination at a nested opener or line ending and keep repeated malformed destinations linear.",
        "Permit unmatched angle destinations to rescan suffixes."
      )
    end
    committed_failure(
      "Markdown-versus-YAML classification obligation removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Do not classify a leading Markdown link, reference, image, or shortcut label as a strict whole YAML sequence solely because it begins with an opening bracket.",
        "Treat every leading opening bracket as strict whole YAML."
      )
    end
    committed_failure(
      "rendered structured-key obligation removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Normalize parsed structured keys through bounded rendered Markdown and HTML visibility before protected-key classification.",
        "Inspect only literal parsed structured keys."
      )
    end
    committed_failure(
      "YAML mapping-key stack guard obligation removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Convert YAML mapping-key safe-load stack exhaustion into a bounded governance validation failure.",
        "Permit YAML mapping-key stack exhaustion to escape validation."
      )
    end
    committed_failure(
      "copied validator path obligation removed",
      "normative requirement rows differ"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Reject copied validator launcher or source execution even when copied bytes match the frozen review tuple.",
        "Permit copied validator launcher and source execution."
      )
    end
    committed_failure("matrix and mutable manifest digest changed together", "validator's normative-row digest") do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Deliver a Home Assistant app/add-on.",
        "Do not deliver a Home Assistant app/add-on."
      )
      refresh_requirement_manifest_digest("normative_rows_sha256")
    end
    with_case_repository do
      marker = File.join(File.dirname(@repository), "rewritten-validator-executed")
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "Attack package substitution.",
        "Permit package substitution."
      )
      rows_digest = refresh_requirement_manifest_digest("normative_rows_sha256")
      refresh_validator_digest_constant("NORMATIVE_ROWS_SHA256", rows_digest)
      normative_files_digest = current_normative_files_digest
      refresh_validator_digest_constant(
        "P00_NORMATIVE_FILES_SHA256",
        normative_files_digest
      )
      edit("tools/validate-governance.rb") do |content|
        content.sub(
          "# frozen_string_literal: true\n",
          "# frozen_string_literal: true\nFile.binwrite(ENV.fetch(\"FIXTURE_TECNICA_MARKER\"), \"executed\")\n"
        )
      end
      git("add", "--all")
      git("commit", "--quiet", "-m", "negative fixture: coordinated validator rewrite")
      stdout, stderr, status = validate(env: { "FIXTURE_TECNICA_MARKER" => marker })
      if status.success? ||
         !("#{stderr}#{stdout}".include?("committed review file differs from tuple")) ||
         File.exist?(marker)
        raise TestFailure,
              "review tuple allowed a coordinated validator rewrite: #{stderr}#{stdout}"
      end
      @passed += 1
    end
    committed_failure("P00 review status and mutable status digest downgraded together", "validator's P00 status digest") do
      edit("docs/evidence/REQUIREMENTS-TRACEABILITY.md") do |content|
        content.sub(
          /(\| `P00-GOV-001` \|[^\n]*\|) SATISFIED \|/,
          "\\1 PENDING |"
        )
      end
      refresh_requirement_manifest_digest("p00_statuses_sha256")
    end
    committed_failure("blank verification oracle", "empty requirement column") do
      edit("docs/evidence/REQUIREMENTS-TRACEABILITY.md") do |content|
        content.sub(
          /(\| `P01-ID-001` \|[^|]+\|[^|]+\|[^|]+\|) [^|]+ \|/,
          "\\1  |"
        )
      end
    end
    committed_failure("undefined owner range", "undefined phase range") do
      edit("docs/evidence/REQUIREMENTS-TRACEABILITY.md") do |content|
        content.sub(
          /(\| `P01-SPAN-001` \|[^|]+\|[^|]+\|) P01 \|/,
          "\\1 P00-P99 |"
        )
      end
    end
    committed_failure("future requirement prematurely satisfied", "frozen status set") do
      edit("docs/evidence/REQUIREMENTS-TRACEABILITY.md") do |content|
        content.sub(
          /(\| `P16-RED-010` \|[^\n|]*\|[^\n|]*\|[^\n|]*\|[^\n|]*\|[^\n|]*\|) PENDING \|/,
          "\\1 SATISFIED |"
        )
      end
    end
    with_case_repository do
      edit("docs/evidence/REQUIREMENTS-TRACEABILITY.md") do |content|
        content.sub(
          /(\| `P00-GOV-001` \|[^\n]*\|) SATISFIED \|/,
          "\\1 REVIEW_PENDING |"
        )
      end
      status_digest = refresh_requirement_manifest_digest("p00_statuses_sha256")
      refresh_validator_digest_constant(
        "P00_REQUIREMENT_STATUSES_SHA256",
        status_digest
      )
      refresh_validator_digest_constant(
        "P00_NORMATIVE_FILES_SHA256",
        current_normative_files_digest
      )
      git("add", "--all")
      git("commit", "--quiet", "-m", "negative fixture: cross-phase P00 review")
      review_hashes = GovernanceValidator::REVIEW_FILE_MODES.keys.to_h do |path|
        [path, Digest::SHA256.file(File.join(@repository, path)).hexdigest]
      end
      stdout, stderr, status = validate(
        preflight: false,
        review_file_sha256: review_hashes
      )
      unless !status.success? &&
             "#{stderr}#{stdout}".include?(
               "REVIEW_PENDING outside its owner phase"
             )
        raise TestFailure,
              "cross-phase P00 review status was accepted: #{stderr}#{stdout}"
      end
      @passed += 1
    end
  end

  def adr_failures
    committed_failure("ADR status token smuggling", "status differs from index") do
      replace_once(
        "docs/adr/ADR-0002-product-scope-and-ha-coverage.md",
        "- Status: `ACCEPTED_AUTONOMOUS`",
        "- Status: `REJECTED`\n\nHistorical token: `ACCEPTED_AUTONOMOUS`"
      )
    end
    committed_failure("broken ADR index link", "ADR index does not exactly match") do
      replace_once(
        "docs/adr/README.md",
        "ADR-0008-deterministic-envelope.md",
        "ADR-0008-missing.md"
      )
    end
    committed_failure("contradictory accepted ADR prose", "normative governance files differ") do
      replace_once(
        "docs/adr/ADR-0007-home-assistant-integration-contract.md",
        "stops at the\nfirst failure or indeterminate result.",
        "continues after every failure or indeterminate result."
      )
    end
  end

  def material_and_tool_failures
    committed_failure("unknown material state", "unknown material state") do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "status: VERIFIED_REMOVED_NOT_ADMITTED",
        "status: FIXTURE_TECNICA_UNKNOWN"
      )
    end
    validator = GovernanceValidator.allocate
    unless !validator.send(:admitted_material_allowed?, "P00") &&
           validator.send(:admitted_material_allowed?, "P13")
      raise TestFailure, "admitted-material phase policy differs"
    end
    @passed += 1
    committed_failure("rejected material retains use", "must have allowed_use: none") do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "rejection_reason: mutable_channel_url\n    allowed_use: none",
        "rejection_reason: mutable_channel_url\n    allowed_use: build_input"
      )
    end
    committed_failure(
      "rejected material has two reason forms",
      "must have exactly one rejection reason field"
    ) do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "    rejection_reasons:\n" \
          "      - per_entry_non_AI_origin_and_licensor_authority_unprovable\n",
        "    rejection_reason: duplicate_form\n" \
          "    rejection_reasons:\n" \
          "      - per_entry_non_AI_origin_and_licensor_authority_unprovable\n"
      )
    end
    committed_failure(
      "rejected material has an empty plural reason",
      "rejection_reasons 0 must be a nonempty string"
    ) do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "      - per_entry_non_AI_origin_and_licensor_authority_unprovable\n",
        "      - \"\"\n"
      )
    end
    committed_failure("quarantined material declares runtime use", "declares a prohibited allowed use") do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "allowed_use: toolchain_selection_only",
        "allowed_use: runtime_linguistic_training"
      )
    end
    committed_failure("quarantined material declares hyphenated build input", "declares a prohibited allowed use") do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "allowed_use: toolchain_selection_only",
        "allowed_use: build-input"
      )
    end
    committed_failure("open reference missing commit", "lacks an immutable commit") do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "    commit: bf65f4e645770909a87c0e59010e0cc71631e4a5\n",
        ""
      )
    end
    committed_failure("noncommercial open reference", "has an ineligible license") do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "    status: EXPOSURE_REJECTED\n    provider: Home_Assistant_project\n    canonical_url: https://github.com/home-assistant/developers.home-assistant",
        "    status: OPEN_REFERENCE\n    provider: Home_Assistant_project\n    canonical_url: https://github.com/home-assistant/developers.home-assistant"
      )
    end
    committed_failure("custom restrictive open-reference license", "has an ineligible license") do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "    license: MIT\n" \
          "    license_rightsholder: Michael_Hansen\n" \
          "    license_file: LICENSE.md\n" \
          "    license_file_bytes: 1071\n" \
          "    license_file_sha256: 13746d509d74e55ea2265fbef204bb7cdbf84a8315b0207e988326cb54387028",
        "    license: LicenseRef-Internal-Use-Only\n" \
          "    license_rightsholder: Michael_Hansen\n" \
          "    license_file: LICENSE.md\n" \
          "    license_file_bytes: 1071\n" \
          "    license_file_sha256: 13746d509d74e55ea2265fbef204bb7cdbf84a8315b0207e988326cb54387028"
      )
    end
    committed_failure("malformed material hash", "has invalid SHA-256") do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "license_file_sha256: 13746d509d74e55ea2265fbef204bb7cdbf84a8315b0207e988326cb54387028",
        "license_file_sha256: malformed"
      )
    end
    committed_failure("malformed nested contract hash", "has invalid SHA-256") do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "sha256: 386731d5e857fd67f567eacfcc9d9a5a13c75b622d5341457e82de0c5b76fe35",
        "sha256: malformed"
      )
    end
    committed_failure("malformed hash-vector member", "has invalid SHA-256") do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "      - c2676c3afc71e3fd86abc3a653cbe273e8929e564f9f72efcfed27c9b416cd91\n",
        "      - malformed\n"
      )
    end
    committed_failure("invalid contract path byte count", "bytes is invalid") do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "bytes: 5302",
        "bytes: 0"
      )
    end
    committed_failure("material missing provider", "provider must be a nonempty string") do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "    provider: Aquila_Labs\n",
        ""
      )
    end
    committed_failure(
      "external material missing canonical source identity",
      "lacks a canonical source identity"
    ) do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "    canonical_url: https://git.cicero.sh/aquila/ha-voice-test-suite\n",
        ""
      )
    end
    committed_failure(
      "material missing primary license field",
      "must have exactly one primary license field"
    ) do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "    license: NOASSERTION\n",
        ""
      )
    end
    committed_failure("Amazon tool attestation true", "must be false") do
      replace_once(
        "docs/evidence/TOOLCHAIN-PROVENANCE.yaml",
        "amazon_internal_tools_used: false",
        "amazon_internal_tools_used: true"
      )
    end
    committed_failure("Amazon material provider", "Amazon-specific material") do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "    provider: Rhasspy_Open_Home_Foundation\n" \
          "    upstream_owner: rhasspy\n" \
          "    canonical_url: https://github.com/rhasspy/wyoming",
        "    provider: Amazon_Web_Services\n" \
          "    upstream_owner: rhasspy\n" \
          "    canonical_url: https://github.com/rhasspy/wyoming"
      )
    end
    committed_failure(
      "Amazon alias repository in open reference",
      "Amazon-specific material"
    ) do
      replace_once(
        "docs/clean-room/MATERIALS.yaml",
        "    provider: Rhasspy_Open_Home_Foundation\n" \
          "    upstream_owner: rhasspy\n" \
          "    canonical_url: https://github.com/rhasspy/wyoming",
        "    provider: Rhasspy_Open_Home_Foundation\n" \
          "    upstream_owner: rhasspy\n" \
          "    canonical_url: git@github.com:amazon-ion/ion-rust"
      )
    end
    committed_failure(
      "Amazon package alias in open reference",
      "Amazon-specific material"
    ) do
      edit("docs/clean-room/MATERIALS.yaml") do |content|
        content.sub(
          "    provider: Home_Assistant_project\n    upstream_owner: home-assistant\n    canonical_url: https://github.com/home-assistant/core",
          "    provider: Home_Assistant_project\n    upstream_owner: home-assistant\n    package: aws-types\n    canonical_url: https://github.com/home-assistant/core"
        )
      end
    end
    committed_failure("unreviewed harmless material identity", "material identities differ") do
      edit("docs/clean-room/MATERIALS.yaml") do |content|
        "#{content}\n  - id: fixture-extra\n    status: REJECTED\n    provider: Fixture_Project\n    canonical_url: https://example.invalid/fixture\n    license: MIT\n    rejection_reason: fixture_only\n    allowed_use: none\n"
      end
    end
    committed_failure("Amazon validator source", "Amazon-specific validator tool") do
      replace_once(
        "docs/evidence/TOOLCHAIN-PROVENANCE.yaml",
        "source_url: https://github.com/apple-oss-distributions/ruby",
        "source_url: https://github.com/aws/example"
      )
    end
    committed_failure("proprietary validator tool license", "does not use an approved software license") do
      replace_once(
        "docs/evidence/TOOLCHAIN-PROVENANCE.yaml",
        "    license: Ruby OR BSD-2-Clause",
        "    license: Proprietary-EULA"
      )
    end
    committed_failure(
      "validator tool redistribution rights missing",
      "rights evidence fields differ"
    ) do
      replace_once(
        "docs/evidence/TOOLCHAIN-PROVENANCE.yaml",
        "      obligations: preserve_applicable_source_headers_if_redistributed\n" \
          "      commercial_use_and_modification: permitted\n" \
          "      redistribution_rights: permitted\n",
        "      obligations: preserve_applicable_source_headers_if_redistributed\n" \
          "      commercial_use_and_modification: permitted\n"
      )
    end
    committed_failure(
      "validator tool redistribution rights denied",
      "lacks redistribution rights"
    ) do
      replace_once(
        "docs/evidence/TOOLCHAIN-PROVENANCE.yaml",
        "      redistribution_rights: permitted",
        "      redistribution_rights: denied"
      )
    end
    committed_failure("missing required tool", "inventory must be env, ruby, psych, libyaml, and git") do
      edit("docs/evidence/TOOLCHAIN-PROVENANCE.yaml") do |content|
        content.sub(/\n  - name: psych\n.*?(?=\n  - name: git\n)/m, "\n")
      end
    end
    committed_failure("scalar required tool record", "tool record 0 must be a mapping") do
      edit("docs/evidence/TOOLCHAIN-PROVENANCE.yaml") do |content|
        content.sub(
          "required_validation_tools:\n  - name: env\n",
          "required_validation_tools:\n  - CANARY_TOOL_RECORD_001\n  - name: env\n"
        )
      end
    end
    committed_failure("numeric tool source commit", "source_commit must be a nonempty string") do
      replace_once(
        "docs/evidence/TOOLCHAIN-PROVENANCE.yaml",
        "source_commit: 298787009e5432c5e4c378a077f98267077e3495",
        "source_commit: 1234567890123456789012345678901234567890"
      )
    end
    committed_failure("Git dispatch shim substituted for implementation", "attested Git path differs") do
      replace_once(
        "docs/evidence/TOOLCHAIN-PROVENANCE.yaml",
        "    executable_path: /Library/Developer/CommandLineTools/usr/bin/git\n    executable_sha256: be4afb2b003904725826250de9fb76567bbacf82323457b5a1ec26706b66bcae",
        "    executable_path: /usr/bin/git\n    executable_sha256: 44a68ddc1983d6cff3fd35ba3f9ba5f82004216f1dcde69892b3d1b06e408698"
      )
    end
    committed_failure("mutable build-tool candidate evidence", "candidate fields differ") do
      edit("docs/evidence/TOOLCHAIN-PROVENANCE.yaml") do |content|
        content.sub(/^\s+manifest_sha256: .+\n/, "")
      end
    end
  end

  def amazon_exclusion_failures
    {
      "amazonaws endpoint" => "https://s3.us-east-1.amazonaws.com/bucket",
      "uppercase Amazon endpoint" => "HTTPS://SERVICE.AMAZONAWS.COM/resource",
      "trailing-dot Amazon endpoint" => "https://service.amazonaws.com./resource",
      "Amazon GitHub owner" => "https://github.com/awslabs/example",
      "Amazon actions owner" => "https://github.com/aws-actions/configure-aws-credentials",
      "Amazon samples owner" => "https://github.com/aws-samples/serverless-patterns",
      "Amazon alternate owner" => "https://github.com/amazon-ion/ion-rust",
      "AmazonWebServices owner" => "https://github.com/AmazonWebServices/example",
      "Smithy Amazon owner" => "https://github.com/smithy-lang/smithy-rs",
      "www GitHub Amazon owner" => "https://www.github.com/aws/example",
      "fully encoded Amazon URL" => "https%3A%2F%2Fgithub.com%2Faws%2Fexample",
      "JSON escaped Amazon URL" => 'https:\\/\\/github.com\\/aws\\/example',
      "percent-encoded Amazon owner" => "https://github.com/%61ws/s2n-tls",
      "raw GitHub Amazon owner" => "https://raw.githubusercontent.com/aws/s2n-tls/main/README.md",
      "legacy raw GitHub Amazon owner" => "https://raw.github.com/aws/s2n-tls/main/README.md",
      "encoded raw GitHub Amazon owner" => "https://raw.githubusercontent.com/%2561ws/s2n-tls/main/README.md",
      "API GitHub Amazon owner" => "https://api.github.com/repos/aws/s2n-tls",
      "codeload GitHub Amazon owner" => "https://codeload.github.com/aws/s2n-tls/tar.gz/main",
      "SCP Amazon repository" => "git@github.com:aws/s2n-tls",
      "Amazon package coordinate" => "crate: aws-config",
      "encoded Amazon package coordinate" => "crate: %40aws-sdk%2Ffixture",
      "Amazon broad package coordinate" => "crate: aws-types",
      "Amazon CRT package" => "package: awscrt",
      "Amazon s2n package" => "package: s2n-tls",
      "Amazon Python package" => "python-package: boto3",
      "Amazon Maven namespace" => "maven: software.amazon.awssdk:s3"
    }.each do |name, value|
      committed_failure(name, "Amazon-") do
        edit("README.md") { |content| "#{content}\n#{value}\n" }
      end
    end
    committed_failure("unapproved repository owner", "unapproved repository owner") do
      edit("README.md") do |content|
        "#{content}\nhttps://github.com/fixture-unreviewed/project\n"
      end
    end
    committed_failure("deeply percent-encoded prohibited source", "Amazon-") do
      value = "https://github.com/aws/example"
      17.times { value = URI.encode_www_form_component(value) }
      edit("README.md") { |content| "#{content}\n#{value}\n" }
    end
    committed_failure(
      "encoded repository URI dot segments",
      "Amazon-owned repository organization"
    ) do
      edit("README.md") do |content|
        "#{content}\nhttps://github.com/home-assistant/%2e%2e/%61ws/example\n"
      end
    end
    committed_failure(
      "nested prohibited URL scheme start",
      "Amazon-owned repository organization"
    ) do
      edit("README.md") do |content|
        "#{content}\n" \
          "https://github.com/home-assistant/core?" \
          "next=https://github.com/aws/example\n"
      end
    end
    committed_failure(
      "multibyte prefix before prohibited URL",
      "Amazon-owned repository organization"
    ) do
      multibyte_prefix = [0x2603].pack("U")
      edit("README.md") do |content|
        "#{content}\n#{multibyte_prefix} https://github.com/aws/example\n"
      end
    end
    committed_failure(
      "default-ignorable prohibited package coordinate",
      "Amazon-specific package coordinate"
    ) do
      edit("README.md") do |content|
        "#{content}\ncrate: a\\u200Dws-types\n"
      end
    end
    committed_failure(
      "literal default-ignorable repository owner",
      "Amazon-owned repository organization"
    ) do
      invisible = [0x200D].pack("U")
      edit("README.md") do |content|
        "#{content}\nhttps://github.com/a#{invisible}ws/example\n"
      end
    end
    committed_failure(
      "structured encoded provider metadata",
      "Amazon-owned provider metadata"
    ) do
      edit("README.md") do |content|
        "#{content}\n{\"metadata\":{\"upstream\\u004fwner\":\"A%57S\"}}\n"
      end
    end
    {
      "inline-link provider key" => '{"[provider](fixture)":{}}',
      "reference-link provider key" => '{"[provider][ref]":{}}',
      "inline-image provider key" => '{"![provider](fixture)":{}}',
      "HTML-split provider key" => '{"pro<span>vid</span>er":{}}',
      "HTML-comment-split provider key" =>
        '{"pro<!--fixture-->vider":{}}'
    }.each do |name, payload|
      committed_failure(name, "must be a nonempty string") do
        edit("README.md") { |content| "#{content}\n#{payload}\n" }
      end
    end
    expect_direct_governance_success(
      "nested Markdown provider labels remain prose"
    ) do
      payload = JSON.generate(
        "inline" => "[provider: FIXTURE_TECNICA](fixture)",
        "reference" =>
          "[provider: FIXTURE_TECNICA][ref]\n[ref]: fixture",
        "shortcut" =>
          "[provider: FIXTURE_TECNICA]\n" \
          "[provider: FIXTURE_TECNICA]: fixture",
        "inline_image" => "![FIXTURE_TECNICA](fixture)",
        "reference_image" =>
          "![FIXTURE_TECNICA][ref]\n[ref]: fixture",
        "shortcut_image" =>
          "![FIXTURE_TECNICA]\n[FIXTURE_TECNICA]: fixture",
        "image_then_emphasis" =>
          "![FIXTURE_TECNICA](fixture)\n*FIXTURE_TECNICA*",
        "image_then_list" =>
          "![FIXTURE_TECNICA](fixture)\n* FIXTURE_TECNICA",
        "image_then_pipe" =>
          "![FIXTURE_TECNICA](fixture)\n| FIXTURE_TECNICA |"
      )
      scanner = direct_validator
      scanner.send(:scan_amazon_content, "FIXTURE_TECNICA.md", payload)
      scanner.send(:scan_sensitive_content, "FIXTURE_TECNICA.md", payload)
    end
    committed_failure(
      "Markdown image before nested provider payload",
      "Amazon-owned provider metadata"
    ) do
      payload = JSON.generate(
        "metadata" => "![FIXTURE_TECNICA][ref]\n" \
          "[ref]: fixture\nprovider: A%57S"
      )
      edit("README.md") { |content| "#{content}\n#{payload}\n" }
    end
    {
      "case-normalized image reference before provider payload" =>
        "![FIXTURE_TECNICA][Ref]\n[ref]: fixture\nprovider: A%57S",
      "space-normalized image reference before provider payload" =>
        "![FIXTURE_TECNICA][fixture   ref]\n" \
        "[fixture ref]: fixture\nprovider: A%57S",
      "continued image reference before provider payload" =>
        "![FIXTURE_TECNICA][ref]\n[ref]: fixture\n" \
        "  \"FIXTURE_TECNICA\"\nprovider: A%57S",
      "nested sequence after image before provider payload" =>
        "![FIXTURE_TECNICA](fixture)\n- - provider: A%57S",
      "explicit sequence key after image before provider payload" =>
        "![FIXTURE_TECNICA](fixture)\n- ? provider\n  : A%57S",
      "commented explicit key after image before provider payload" =>
        "![FIXTURE_TECNICA](fixture)\n? provider # fixture\n: A%57S",
      "standalone explicit key after image before provider payload" =>
        "![FIXTURE_TECNICA](fixture)\n?\n  provider\n: A%57S"
    }.each do |name, nested|
      committed_failure(name, "Amazon-owned provider metadata") do
        payload = JSON.generate("metadata" => nested)
        edit("README.md") { |content| "#{content}\n#{payload}\n" }
      end
    end
    {
      "anchored provider key after image" => [
        "![FIXTURE_TECNICA](fixture)\n&a provider: A%57S",
        "YAML anchors are prohibited"
      ],
      "tagged provider key after image" => [
        "![FIXTURE_TECNICA](fixture)\n!str provider: A%57S",
        "tagged YAML mapping key is prohibited"
      ],
      "aliased provider key after image" => [
        "![FIXTURE_TECNICA](fixture)\n" \
          "anchor: &a provider\n*a: A%57S",
        "YAML anchors are prohibited"
      ],
      "folded explicit provider key after image" => [
        "![FIXTURE_TECNICA](fixture)\n? >-\n  provider\n: A%57S",
        "Amazon-owned provider metadata"
      ],
      "continued quoted provider key after image" => [
        "![FIXTURE_TECNICA](fixture)\n" \
          "? \"pro\\\n  vider\"\n: A%57S",
        "Amazon-owned provider metadata"
      ],
      "standalone anchor after image" => [
        "![FIXTURE_TECNICA](fixture)\n" \
          "&FIXTURE_TECNICA\nprovider: FIXTURE_TECNICA",
        "YAML anchors are prohibited"
      ],
      "multiple standalone node properties after image" => [
        "![FIXTURE_TECNICA](fixture)\n" \
          "&FIXTURE_TECNICA !str\nprovider: FIXTURE_TECNICA",
        "YAML anchors are prohibited"
      ],
      "multiple node properties before flow mapping" => [
        "&FIXTURE_TECNICA !str {provider: FIXTURE_TECNICA}",
        "YAML anchors are prohibited"
      ],
      "anchored mapping and alias after image" => [
        "![FIXTURE_TECNICA](fixture)\n" \
          "fixtureKey: &FIXTURE_TECNICA {provider: FIXTURE_TECNICA}\n" \
          "fixtureValue: *FIXTURE_TECNICA",
        "YAML anchors are prohibited"
      ]
    }.each do |name, (nested, expected_message)|
      committed_failure(name, expected_message) do
        payload = JSON.generate("metadata" => nested)
        edit("README.md") { |content| "#{content}\n#{payload}\n" }
      end
    end
    expect_direct_governance_success(
      "allowed multiline explicit provider after image"
    ) do
      payload = JSON.generate(
        "metadata" => "![FIXTURE_TECNICA](fixture)\n" \
          "? >-\n  provider\n: FIXTURE_TECNICA"
      )
      direct_validator.send(
        :scan_amazon_content,
        "FIXTURE_TECNICA.md",
        payload
      )
    end
    {
      "Markdown image before nested credential payload" =>
        "![FIXTURE_TECNICA]\napi_key: CANARY_CREDENTIAL_001",
      "Markdown image before nested sequence credential payload" =>
        "![FIXTURE_TECNICA]\n- - api_key: CANARY_CREDENTIAL_001",
      "Markdown image before standalone explicit credential payload" =>
        "![FIXTURE_TECNICA]\n?\n  api_key\n: CANARY_CREDENTIAL_001"
    }.each do |name, nested|
      expect_direct_governance_failure(name, "credential field") do
        payload = JSON.generate("metadata" => nested)
        direct_validator.send(
          :scan_sensitive_content,
          "FIXTURE_TECNICA.md",
          payload
        )
      end
    end
    expect_direct_governance_success("Python runtime schema variables") do
      direct_validator.send(
        :scan_sensitive_content,
        "FIXTURE_TECNICA.py",
        "secret: bytearray\n" \
          "token = \"FIXTURE_TECNICA_TOKEN\"\n" \
          "display_name = entity.get(\"display_name\")\n" \
          "record = {\"entity_id\": \"light.fixture_tecnica_a\"}\n" \
          "device = {\"device_id\": \"33\" * 16}\n"
      )
    end
    expect_direct_governance_failure(
      "Python literal credential",
      "credential-like assignment"
    ) do
      direct_validator.send(
        :scan_sensitive_content,
        "FIXTURE_TECNICA.py",
        "token = \"not_a_fixture\"\n"
      )
    end
    expect_direct_governance_failure(
      "Python unlabeled residential literal",
      "residential-data assignment"
    ) do
      direct_validator.send(
        :scan_sensitive_content,
        "FIXTURE_TECNICA.py",
        "record = {\"entity_id\": \"light.private_home\"}\n"
      )
    end
    expect_direct_governance_success("vendored credential example") do
      direct_validator.send(
        :scan_sensitive_content,
        "vendor/FIXTURE_TECNICA/src/lib.rs",
        "let secret = \"upstream documentation example\";\n"
      )
    end
    committed_failure(
      "fenced YAML non-scalar provider metadata",
      "must be a nonempty string"
    ) do
      edit("README.md") do |content|
        content + [
          "",
          "```yaml",
          "provider:",
          "  name: FIXTURE_TECNICA",
          "```",
          ""
        ].join("\n")
      end
    end
    committed_failure(
      "blockquote YAML non-scalar provider metadata",
      "must be a nonempty string"
    ) do
      write(
        "README.md",
        "> provider:\n>   fixtureKey: FIXTURE_TECNICA\n"
      )
    end
    committed_failure(
      "no-space blockquote escaped provider metadata",
      "Amazon-owned provider metadata"
    ) do
      write("README.md", ">\"pro\\x76ider\": A%57S\n")
    end
    committed_failure(
      "serialized nested provider metadata",
      "Amazon-owned provider metadata"
    ) do
      nested = JSON.generate(
        "details" => JSON.generate("provider" => "AmazonWebServices")
      )
      payload = JSON.generate("metadata" => nested)
      edit("README.md") { |content| "#{content}\n#{payload}\n" }
    end
    committed_failure(
      "malformed embedded YAML provider payload",
      "invalid embedded YAML payload"
    ) do
      nested = "---\nprovider: A%57S\n[\n"
      payload = JSON.generate("metadata" => nested)
      edit("README.md") { |content| "#{content}\n#{payload}\n" }
    end
    committed_failure(
      "embedded YAML semantic provider-key collision",
      "non-string semantic YAML key"
    ) do
      nested =
        "true: {provider: A%57S}\n" \
        "True: {provider: FIXTURE_TECNICA}\n"
      payload = JSON.generate("metadata" => nested)
      edit("README.md") { |content| "#{content}\n#{payload}\n" }
    end
    committed_failure(
      "whole YAML duplicate provider-key collision",
      "duplicate YAML key"
    ) do
      write(
        "README.md",
        "metadata:\n" \
          "  details: {provider: A%57S, provider: FIXTURE_TECNICA}\n"
      )
    end
    committed_failure(
      "malformed JSON provider payload",
      "invalid JSON payload"
    ) do
      edit("README.md") do |content|
        "#{content}\n{\"provider\":\"A%57S\",}\n"
      end
    end
    {
      "truncated protected JSON provider payload" =>
        "Payload: {\"provider\":\"A%57S\"\n",
      "mismatched protected JSON provider payload" =>
        "Payload: {\"provider\":\"A%57S\"]\n"
    }.each do |name, payload|
      committed_failure(name, "invalid JSON payload") do
        write("README.md", payload)
      end
    end
    committed_failure(
      "malformed nested YAML provider payload",
      "invalid YAML payload"
    ) do
      write("README.md", "metadata:\n  provider: [\n")
    end
    committed_failure(
      "mixed-Markdown flow-YAML provider payload",
      "Amazon-owned provider metadata"
    ) do
      write(
        "README.md",
        "# FIXTURE_TECNICA\n\n" \
          "Role: `FIXTURE_TECNICA`\n" \
          "metadata: {provider: A%57S}\n" \
          "## Findings\n\nNone.\n"
      )
    end
    committed_failure(
      "mixed-Markdown explicit-YAML provider payload",
      "Amazon-owned provider metadata"
    ) do
      write(
        "README.md",
        "# FIXTURE_TECNICA\n\n" \
          "Role: `FIXTURE_TECNICA`\n" \
          "? provider\n" \
          ": A%57S\n" \
          "## Findings\n\nNone.\n"
      )
    end
    expect_direct_governance_success(
      "leading Markdown link is not strict whole YAML"
    ) do
      content =
        "[FIXTURE_TECNICA](fixture)\n\n" \
        "Example syntax: \"provider\": FIXTURE_TECNICA\n"
      direct_validator.send(
        :scan_amazon_content,
        "FIXTURE_TECNICA.md",
        content
      )
      direct_validator.send(
        :scan_blocked_provider_structure,
        content,
        "FIXTURE_TECNICA.md"
      )
    end
    expect_direct_governance_success(
      "mixed-Markdown scalar provider fixture"
    ) do
      direct_validator.send(
        :scan_amazon_content,
        "FIXTURE_TECNICA.md",
        "# FIXTURE_TECNICA\n\n" \
          "Role: `FIXTURE_TECNICA`\n" \
          "provider: FIXTURE_TECNICA\n" \
          "## Findings\n\nNone.\n"
      )
    end
    {
      "flow-YAML provider string" => "{provider: A%57S}",
      "sequence-YAML provider string" => "- provider: A%57S",
      "standalone-dash YAML provider string" => "-\n  provider: A%57S",
      "explicit-mapping YAML provider string" => "? provider\n: A%57S",
      "comment-prefixed YAML provider string" =>
        "# FIXTURE_TECNICA\nprovider: A%57S"
    }.each do |name, nested|
      committed_failure(name, "Amazon-owned provider metadata") do
        payload = JSON.generate("metadata" => nested)
        edit("README.md") { |content| "#{content}\n#{payload}\n" }
      end
    end
    {
      "whole flow-YAML provider" => "{provider: A%57S}",
      "whole sequence-YAML provider" => "- provider: A%57S",
      "whole standalone-dash YAML provider" => "-\n  provider: A%57S",
      "whole explicit-mapping YAML provider" => "? provider\n: A%57S",
      "whole comment-prefixed YAML provider" =>
        "# FIXTURE_TECNICA\nprovider: A%57S"
    }.each do |name, payload|
      committed_failure(name, "Amazon-owned provider metadata") do
        write("README.md", "#{payload}\n")
      end
    end
    committed_failure(
      "multi-document YAML provider string",
      "embedded YAML payload must contain exactly one document"
    ) do
      nested = "---\nfixtureKey: FIXTURE_TECNICA\n" \
        "---\nprovider: A%57S"
      payload = JSON.generate("metadata" => nested)
      edit("README.md") { |content| "#{content}\n#{payload}\n" }
    end
    {
      "mapping provider metadata" =>
        '{"metadata":{"provider":{"name":"FIXTURE_TECNICA"}}}',
      "array owner metadata" =>
        '{"metadata":{"owner":["FIXTURE_TECNICA"]}}',
      "boolean upstream owner metadata" =>
        '{"metadata":{"upstreamOwner":true}}'
    }.each do |name, payload|
      committed_failure(name, "must be a nonempty string") do
        edit("README.md") { |content| "#{content}\n#{payload}\n" }
      end
    end
    committed_failure(
      "provider payload traversal depth",
      "provider payload exceeds depth limit"
    ) do
      nested = { "provider" => "FIXTURE_TECNICA" }
      (GovernanceValidator::MAX_PROVIDER_PAYLOAD_DEPTH + 1).times do |index|
        nested = { "level#{index}" => nested }
      end
      edit("README.md") do |content|
        "#{content}\n#{JSON.generate(nested)}\n"
      end
    end
    committed_failure("URL candidate count limit", "URL candidate limit exceeded") do
      urls = Array.new(
        GovernanceValidator::MAX_URL_CANDIDATES + 1,
        "https://example.invalid/FIXTURE_TECNICA"
      ).join("\n")
      edit("README.md") { |content| "#{content}\n#{urls}\n" }
    end
    committed_failure("URL candidate byte limit", "URL candidate byte limit exceeded") do
      url = "https://example.invalid/" +
        ("x" * GovernanceValidator::MAX_URL_CANDIDATE_BYTES)
      edit("README.md") { |content| "#{content}\n#{url}\n" }
    end
    expect_direct_governance_success("nested badge URL query delimiter") do
      direct_validator.send(
        :scan_blocked_urls,
        "FIXTURE_TECNICA.rs",
        "https://example.invalid/?uri=" \
          "https://crates.io/api/v1/crates/FIXTURE_TECNICA/versions" \
          "&query=$.versions[0]"
      )
    end
    expect_direct_governance_failure(
      "blocked URL before query delimiter",
      "Amazon-owned endpoint"
    ) do
      direct_validator.send(
        :scan_blocked_urls,
        "FIXTURE_TECNICA.rs",
        "https://aws.amazon.com/FIXTURE_TECNICA&query=value"
      )
    end
    committed_failure("collapsed Amazon provider name", "Amazon-owned provider metadata") do
      edit("README.md") do |content|
        "#{content}\nprovider: AmazonWebServices\n"
      end
    end
    committed_failure("joined Amazon product provider name", "Amazon-owned provider metadata") do
      edit("README.md") do |content|
        "#{content}\nprovider: AmazonCorretto\n"
      end
    end
    committed_failure("arbitrary Amazon allowlist expansion", "allowlist differs from the fixed") do
      edit("README.md") do |content|
        "#{content}\nhttps://github.com/aws/aws-sdk-rust\n"
      end
      edit("docs/clean-room/AMAZON-EXCLUSION-ALLOWLIST.yaml") do |content|
        "#{content}  - path: README.md\n    reason: bypass_fixture\n"
      end
    end

    percent_64 = "%"
    64.times { percent_64 = URI.encode_www_form_component(percent_64) }
    expect_direct_governance_success("64-pass percent decoding") do
      result = direct_validator.send(:repeatedly_percent_decode, percent_64)
      raise TestFailure, "64-pass percent decoding returned wrong bytes" unless
        result == "%"
    end
    percent_65 = URI.encode_www_form_component(percent_64)
    expect_direct_governance_failure(
      "65-pass percent decoding",
      "percent-decoding limit exceeded"
    ) do
      direct_validator.send(:repeatedly_percent_decode, percent_65)
    end

    text_64 = "&"
    64.times { text_64 = CGI.escapeHTML(text_64) }
    expect_direct_governance_success("64-pass text decoding") do
      result = direct_validator.send(:repeatedly_decode_text, text_64)
      raise TestFailure, "64-pass text decoding returned wrong bytes" unless
        result == "&"
    end
    text_65 = CGI.escapeHTML(text_64)
    expect_direct_governance_failure(
      "65-pass text decoding",
      "text-decoding limit exceeded"
    ) do
      direct_validator.send(:repeatedly_decode_text, text_65)
    end

    markdown_64 = ("[" * GovernanceValidator::MAX_MARKDOWN_NESTING) +
      "FIXTURE_TECNICA" +
      ("]" * GovernanceValidator::MAX_MARKDOWN_NESTING) +
      "(fixture)"
    expect_direct_governance_success("Markdown nesting boundary") do
      result = direct_validator.send(:markdown_visible_text, markdown_64)
      unless result == "FIXTURE_TECNICA"
        raise TestFailure, "Markdown nesting boundary returned wrong text"
      end
    end
    markdown_65 = "[#{markdown_64}](fixture)"
    expect_direct_governance_failure(
      "Markdown nesting limit",
      "Markdown delimiter nesting limit exceeded"
    ) do
      direct_validator.send(:markdown_visible_text, markdown_65)
    end
    expect_direct_governance_failure(
      "unmatched Markdown nesting limit",
      "Markdown delimiter nesting limit exceeded"
    ) do
      direct_validator.send(
        :markdown_visible_text,
        "[" * (GovernanceValidator::MAX_MARKDOWN_NESTING + 1)
      )
    end
    expect_direct_governance_success(
      "escaped unmatched Markdown delimiters stay linear"
    ) do
      validator = direct_validator
      delimiter_calls = 0
      original = validator.method(:matching_markdown_delimiter)
      validator.define_singleton_method(:matching_markdown_delimiter) do |*args, **kwargs|
        delimiter_calls += 1
        original.call(*args, **kwargs)
      end
      validator.send(:markdown_visible_text, "\\[" * 8_192)
      unless delimiter_calls.zero?
        raise GovernanceError,
              "escaped Markdown invoked delimiter matching #{delimiter_calls} times"
      end
    end
    expect_direct_governance_success(
      "unmatched Markdown angle destinations stay linear"
    ) do
      validator = direct_validator
      input = " [x](<" * 2_048
      byte_reads = 0
      instrumented = {}
      original = validator.method(:matching_markdown_delimiter)
      validator.define_singleton_method(:matching_markdown_delimiter) do |bytes, *args, **kwargs|
        unless instrumented[bytes.object_id]
          raw_getbyte = bytes.method(:getbyte)
          bytes.define_singleton_method(:getbyte) do |index|
            byte_reads += 1
            if byte_reads > input.bytesize * 64
              raise GovernanceError,
                    "malformed Markdown exceeded linear byte-read budget"
            end
            raw_getbyte.call(index)
          end
          instrumented[bytes.object_id] = true
        end
        original.call(bytes, *args, **kwargs)
      end
      validator.send(:markdown_visible_text, input)
    end
    expect_direct_governance_success(
      "unmatched HTML autolink openers stay linear"
    ) do
      validator = direct_validator
      input = "<" * 8_192
      closing_searches = 0
      original = validator.method(:next_markdown_html_closing)
      validator.define_singleton_method(:next_markdown_html_closing) do |*args|
        closing_searches += 1
        original.call(*args)
      end
      result = validator.send(:strip_markdown_html, input)
      unless result == input && closing_searches == 1
        raise GovernanceError,
              "malformed HTML used #{closing_searches} closing searches"
      end
    end
    expect_direct_governance_success("JSON surrogate-pair text decoding") do
      decoded = direct_validator.send(
        :repeatedly_decode_text,
        '{"FIXTURE_TECNICA":"\\uD83D\\uDE00"}'
      )
      expected = "{\"FIXTURE_TECNICA\":\"#{[0x1F600].pack('U')}\"}"
      unless decoded == expected && decoded.valid_encoding?
        raise GovernanceError, "JSON surrogate pair decoded incorrectly"
      end
    end
  end

  def yaml_extraction_boundary_regressions
    count_collection = {
      candidates: [],
      seen: Set.new,
      count: 0,
      bytes: 0
    }
    validator = direct_validator
    repeated_mapping = "provider: FIXTURE_TECNICA\n" * 8
    repeated_blocks = validator.send(
      :protected_yaml_blocks,
      repeated_mapping,
      GovernanceValidator::PROTECTED_PROVIDER_KEYS,
      markdown_containers: true,
      include_node_properties: true
    ).to_a
    unless repeated_blocks.length == 8 &&
           repeated_blocks.map(&:object_id).uniq.length == 1
      raise TestFailure, "overlapping YAML blocks were not linearly reused"
    end
    @passed += 1

    GovernanceValidator::MAX_YAML_PAYLOAD_CANDIDATES.times do
      validator.send(
        :append_yaml_payload_candidate!,
        count_collection,
        "",
        true,
        nil,
        "FIXTURE_TECNICA.md"
      )
    end
    unless count_collection.fetch(:count) ==
           GovernanceValidator::MAX_YAML_PAYLOAD_CANDIDATES
      raise TestFailure, "YAML candidate exact count boundary was not retained"
    end
    @passed += 1
    expect_direct_governance_failure(
      "YAML candidate count one over",
      "YAML payload candidate limit exceeded"
    ) do
      validator.send(
        :append_yaml_payload_candidate!,
        count_collection,
        "",
        true,
        nil,
        "FIXTURE_TECNICA.md"
      )
    end

    byte_collection = {
      candidates: [],
      seen: Set.new,
      count: 0,
      bytes: 0
    }
    boundary = "F" * GovernanceValidator::MAX_YAML_PAYLOAD_AGGREGATE_BYTES
    validator.send(
      :append_yaml_payload_candidate!,
      byte_collection,
      boundary,
      true,
      nil,
      "FIXTURE_TECNICA.md"
    )
    unless byte_collection.fetch(:bytes) ==
           GovernanceValidator::MAX_YAML_PAYLOAD_AGGREGATE_BYTES
      raise TestFailure, "YAML candidate exact byte boundary was not retained"
    end
    @passed += 1
    expect_direct_governance_failure(
      "YAML candidate aggregate bytes one over",
      "YAML payload aggregate byte limit exceeded"
    ) do
      validator.send(
        :append_yaml_payload_candidate!,
        byte_collection,
        "F",
        true,
        nil,
        "FIXTURE_TECNICA.md"
      )
    end

    amplified = (
      "provider: FIXTURE_TECNICA\n" *
      (GovernanceValidator::MAX_YAML_PAYLOAD_CANDIDATES + 1)
    )
    expect_direct_governance_failure(
      "overlapping YAML block amplification",
      "YAML payload candidate limit exceeded"
    ) do
      validator.send(
        :parsed_yaml_payloads,
        amplified,
        "FIXTURE_TECNICA.md"
      )
    end

    {
      "flow-set provider key" => [
        :amazon,
        "{provider}\n",
        "must be a nonempty string"
      ],
      "slash-separated credential key" => [
        :sensitive,
        "api/key: FIXTURE_TECNICA\n",
        "non-string-safe YAML key"
      ],
      "brace-separated provider key" => [
        :amazon,
        "pro{vider}: A%57S\n",
        "non-string-safe YAML key"
      ],
      "brace-separated credential key" => [
        :sensitive,
        "to{ken}: CANARY_CREDENTIAL_001\n",
        "non-string-safe YAML key"
      ],
      "bracket-separated residential key" => [
        :sensitive,
        "entity[Id]: CANARY_ENTITY_001\n",
        "residential-data assignment"
      ],
      "comma-separated provider key" => [
        :amazon,
        "pro,vider: A%57S\n",
        "non-string-safe YAML key"
      ],
      "hash-separated provider key" => [
        :amazon,
        "pro#vider: A%57S\n",
        "non-string-safe YAML key"
      ],
      "hash-separated credential key" => [
        :sensitive,
        "to#ken: CANARY_CREDENTIAL_001\n",
        "non-string-safe YAML key"
      ],
      "hash-separated residential key" => [
        :sensitive,
        "entity#Id: CANARY_ENTITY_001\n",
        "non-string-safe YAML key"
      ],
      "tagged flow provider key" => [
        :amazon,
        "{!!str provider: A%57S}\n",
        "Amazon-owned provider metadata"
      ],
      "tagged flow credential key" => [
        :sensitive,
        "{!!str api/key: CANARY_CREDENTIAL_001}\n",
        "non-string-safe YAML key"
      ],
      "indentless sequence anchor after protected fixture" => [
        :sensitive,
        "entityId: FIXTURE_TECNICA\n" \
          "fixtureKey:\n" \
          "- &FIXTURE_TECNICA FIXTURE_TECNICA\n",
        "YAML anchors are prohibited"
      ],
      "explicit-key indentless sequence anchor" => [
        :sensitive,
        "entityId: FIXTURE_TECNICA\n" \
          "? fixtureKey\n" \
          ":\n" \
          "- &FIXTURE_TECNICA FIXTURE_TECNICA\n",
        "YAML anchors are prohibited"
      ],
      "directive and multiple YAML documents" => [
        :sensitive,
        "%YAML 1.2\n" \
          "---\n" \
          "entityId: FIXTURE_TECNICA\n" \
          "...\n" \
          "---\n" \
          "entityId: FIXTURE_TECNICA\n",
        "invalid YAML payload"
      ],
      "unknown YAML directive before protected fixture" => [
        :sensitive,
        "FIXTURE_TECNICA prose\n\n" \
          "%FOO bar\n" \
          "---\n" \
          "entityId: FIXTURE_TECNICA\n",
        "invalid YAML payload"
      ],
      "case-invalid YAML directive before protected fixture" => [
        :sensitive,
        "FIXTURE_TECNICA prose\n\n" \
          "%yaml 1.2\n" \
          "---\n" \
          "entityId: FIXTURE_TECNICA\n",
        "invalid YAML payload"
      ],
      "inline document anchor before protected fixture" => [
        :sensitive,
        "FIXTURE_TECNICA prose\n\n" \
          "--- &FIXTURE_TECNICA\n" \
          "entityId: FIXTURE_TECNICA\n",
        "YAML anchors are prohibited"
      ],
      "unsafe sibling before protected fixture" => [
        :sensitive,
        "fixtureKey: &FIXTURE_TECNICA FIXTURE_TECNICA\n" \
          "entityId: FIXTURE_TECNICA\n",
        "YAML anchors are prohibited"
      ],
      "complex sibling after protected fixture" => [
        :sensitive,
        "entityId: FIXTURE_TECNICA\n" \
          "? [fixtureKey]\n" \
          ": FIXTURE_TECNICA\n",
        "non-scalar YAML key"
      ],
      "merge sibling after protected fixture" => [
        :sensitive,
        "entityId: FIXTURE_TECNICA\n" \
          "<<: {fixtureKey: FIXTURE_TECNICA}\n",
        "YAML merge keys are prohibited"
      ],
      "merge after Markdown reference continuation" => [
        :sensitive,
        "[ref]: fixture\n" \
          "  \"title\"\n" \
          "  <<: {fixtureKey: FIXTURE_TECNICA}\n" \
          "entityId: FIXTURE_TECNICA\n",
        "invalid YAML payload"
      ]
    }.each do |name, (kind, content, expected_message)|
      expect_direct_governance_failure(name, expected_message) do
        scanner = direct_validator
        if kind == :amazon
          scanner.send(:scan_amazon_content, "FIXTURE_TECNICA.md", content)
        else
          scanner.send(:scan_sensitive_content, "FIXTURE_TECNICA.md", content)
        end
      end
    end

    {
      "base-aligned flow-sequence closer" =>
        "fixtureKey: [\n" \
          "provider: FIXTURE_TECNICA\n" \
          "]\n",
      "base-aligned flow-mapping closer" =>
        "fixtureKey: {\n" \
          "provider: FIXTURE_TECNICA\n" \
          "}\n",
      "clock text after provider fixture" =>
        "provider: FIXTURE_TECNICA\n" \
          "Time 12:34\n",
      "URL after provider fixture" =>
        "provider: FIXTURE_TECNICA\n" \
          "https://example.org/FIXTURE_TECNICA\n",
      "Markdown reference after provider fixture" =>
        "provider: FIXTURE_TECNICA\n" \
          "[ref]: fixture\n",
      "separate ordered Markdown list items" =>
        "1. provider: FIXTURE_TECNICA\n" \
          "2. fixtureKey: FIXTURE_TECNICA\n",
      "separate star Markdown list items" =>
        "* provider: FIXTURE_TECNICA\n" \
          "* fixtureKey: FIXTURE_TECNICA\n",
      "ordered Markdown list continuation" =>
        "1. fixtureKey: FIXTURE_TECNICA\n" \
          "   provider: FIXTURE_TECNICA\n",
      "nested blockquote provider fixture" =>
        "> > provider: FIXTURE_TECNICA\n" \
          "> > Time 12:34\n",
      "nested star-list provider fixture" =>
        "* provider: FIXTURE_TECNICA\n" \
          "  * fixtureKey: FIXTURE_TECNICA\n",
      "blank-separated indented Markdown code" =>
        "provider: FIXTURE_TECNICA\n\n" \
          "    example: value\n",
      "lone-CR shortcut Markdown label" =>
        "[provider: FIXTURE_TECNICA]\r" \
          "[provider: FIXTURE_TECNICA]: fixture\r"
    }.each do |name, content|
      expect_direct_governance_success(name) do
        direct_validator.send(
          :scan_amazon_content,
          "FIXTURE_TECNICA.md",
          content
        )
      end
    end
  end

  def all_ref_sensitive_failure(name, path, content, expected_message)
    with_case_repository do
      reviewed_commit = git("rev-parse", "HEAD").strip
      reviewed_tree = git("rev-parse", "HEAD^{tree}").strip
      git("checkout", "--quiet", "-b", "fixture-sensitive-ref")
      write(path, content)
      git("add", "--force", "--", path)
      git("commit", "--quiet", "-m", "negative fixture: alternate ref")
      git("checkout", "--quiet", "--detach", reviewed_commit)

      stdout, stderr, status = validate(
        commit: reviewed_commit,
        tree: reviewed_tree
      )
      combined = "#{stderr}#{stdout}"
      if status.success? || !combined.include?(expected_message)
        raise TestFailure,
              "#{name} was accepted from another ref: #{combined}"
      end
      @passed += 1
    end
  end

  def fixture_tree_with_path(base_tree, path, content)
    blob = git("hash-object", "-w", "--stdin", stdin_data: content).strip
    components = path.split("/")
    object = blob
    type = "blob"
    mode = "100644"

    while components.length > 1
      name = components.pop
      object = git(
        "mktree",
        stdin_data: "#{mode} #{type} #{object}\t#{name}\n"
      ).strip
      type = "tree"
      mode = "040000"
    end

    root_name = components.fetch(0)
    base_entries = git("ls-tree", base_tree)
    if base_entries.lines.any? { |line| line.end_with?("\t#{root_name}\n") }
      raise TestFailure, "fixture root path already exists: #{root_name}"
    end
    git(
      "mktree",
      stdin_data: "#{base_entries}#{mode} #{type} #{object}\t#{root_name}\n"
    ).strip
  end

  def archive_and_secret_failures
    with_case_repository do
      reviewed_commit = git("rev-parse", "HEAD").strip
      reviewed_tree = git("rev-parse", "HEAD^{tree}").strip
      sensitive_tree = fixture_tree_with_path(
        reviewed_tree,
        ".storage/core.entity_registry",
        "FIXTURE_TECNICA\n"
      )
      git(
        "update-ref",
        "refs/tags/fixture-sensitive-tree",
        sensitive_tree
      )
      stdout, stderr, status = validate(
        commit: reviewed_commit,
        tree: reviewed_tree
      )
      combined = "#{stderr}#{stdout}"
      expected = "sensitive file type is reachable from a project ref"
      if status.success? || !combined.include?(expected)
        raise TestFailure,
              "direct sensitive tree ref was accepted: #{combined}"
      end
      @passed += 1
    end

    with_case_repository do
      reviewed_commit = git("rev-parse", "HEAD").strip
      reviewed_tree = git("rev-parse", "HEAD^{tree}").strip
      sensitive_tree = fixture_tree_with_path(
        reviewed_tree,
        ".storage/core.entity_registry",
        "FIXTURE_TECNICA\n"
      )
      second_parent = git(
        "commit-tree",
        reviewed_tree,
        "-p", reviewed_commit,
        "-m", "FIXTURE_TECNICA merge parent"
      ).strip
      merge = git(
        "commit-tree",
        sensitive_tree,
        "-p", reviewed_commit,
        "-p", second_parent,
        "-m", "FIXTURE_TECNICA merge result"
      ).strip
      git("update-ref", "refs/heads/fixture-sensitive-merge", merge)
      stdout, stderr, status = validate(
        commit: reviewed_commit,
        tree: reviewed_tree
      )
      combined = "#{stderr}#{stdout}"
      expected = "sensitive file type is reachable from a project ref"
      if status.success? || !combined.include?(expected)
        raise TestFailure,
              "merge-result sensitive path was accepted: #{combined}"
      end
      @passed += 1
    end

    all_ref_sensitive_failure(
      "alternate-ref credential",
      "history-credential.yaml",
      "token: CANARY_CREDENTIAL_001\n",
      "credential field"
    )
    all_ref_sensitive_failure(
      "alternate-ref residential dump",
      "history-residential.yaml",
      "entity_id: CANARY_ENTITY_001\n",
      "residential-data field"
    )
    all_ref_sensitive_failure(
      "alternate-ref Home Assistant state path",
      ".storage/core.entity_registry",
      "FIXTURE_TECNICA\n",
      "sensitive file type is reachable from a project ref"
    )
    all_ref_sensitive_failure(
      "alternate-ref user utterance",
      "history-utterance.yaml",
      "utterance: CANARY_UTTERANCE_001\n",
      "residential-data field"
    )
    all_ref_sensitive_failure(
      "alternate-ref oversized privacy blob",
      "history-oversized.txt",
      "F" * (GovernanceValidator::MAX_REACHABLE_PRIVACY_BLOB_BYTES + 1),
      "Git blob reachable from a project ref exceeds privacy scan limit"
    )
    committed_failure("steering reintroduced", "steering path is reachable") do
      write("STEERING-NLU-PTBR-SOL-MAX.md", "unlicensed fixture\n")
      git("add", "--force", "STEERING-NLU-PTBR-SOL-MAX.md")
    end
    committed_failure("symlink introduced", "non-regular or symlink") do
      File.symlink("README.md", File.join(@repository, "README-LINK"))
    end
    committed_failure("gitlink introduced", "non-regular or symlink") do
      path = File.join(@repository, "vendor/FIXTURE_TECNICA-gitlink")
      FileUtils.mkdir_p(path)
      command(@git, "init", "--quiet", chdir: path)
      command(@git, "config", "user.name", "Governance Test", chdir: path)
      command(
        @git,
        "config",
        "user.email",
        "governance-test.invalid",
        chdir: path
      )
      command(
        @git,
        "commit",
        "--quiet",
        "--allow-empty",
        "-m",
        "negative fixture: gitlink target",
        chdir: path
      )
    end
    committed_distribution_scan_failure(
      "tracked secret file",
      "sensitive file type is tracked"
    ) do
      write("credentials.pem", "fixture\n")
      git("add", "--force", "credentials.pem")
      replace_once(
        "docs/clean-room/DISTRIBUTION-LICENSES.yaml",
        "      - .gitignore\n",
        "      - .gitignore\n      - credentials.pem\n"
      )
    end
    committed_failure("credential assignment", "credential-like assignment") do
      edit("README.md") do |content|
        "#{content}\nSUPERVISOR_TOKEN=CANARY_CREDENTIAL_001\n"
      end
    end
    {
      "Rust credential string assignment" => [
        "FIXTURE_TECNICA.rs",
        "let access_token = \"CANARY_CREDENTIAL_001\";\n",
        "credential-like assignment"
      ],
      "Ruby single-quoted credential assignment" => [
        "FIXTURE_TECNICA.rb",
        "api_key = 'CANARY_CREDENTIAL_001'\n",
        "credential-like assignment"
      ],
      "Ruby percent-literal credential assignment" => [
        "FIXTURE_TECNICA.rb",
        "secret = %q[CANARY_CREDENTIAL_001]\n",
        "credential-like assignment"
      ],
      "TOML credential assignment" => [
        "FIXTURE_TECNICA.toml",
        "token = 'CANARY_CREDENTIAL_001'\n",
        "credential-like assignment"
      ],
      "TOML residential assignment" => [
        "FIXTURE_TECNICA.toml",
        "room_name = 'CANARY_ROOM_001'\n",
        "residential-data assignment"
      ]
    }.each do |name, (path, content, expected)|
      expect_direct_governance_failure(name, expected) do
        direct_validator.send(:scan_sensitive_content, path, content)
      end
    end
    expect_direct_governance_success(
      "Rust protected-key field declarations are not values"
    ) do
      direct_validator.send(
        :scan_sensitive_content,
        "FIXTURE_TECNICA.rs",
        "pub authorization: String,\n" \
          "pub entity_id: String,\n" \
          "let fixture = Fixture { alias: \"FIXTURE_TECNICA\" };\n"
      )
    end
    committed_distribution_scan_failure(
      "Home Assistant storage",
      "sensitive file type is tracked"
    ) do
      path = ".storage/core.entity_registry"
      write(path, '{"resident":"FIXTURE_TECNICA","access_token":"CANARY_CREDENTIAL_001"}')
      replace_once(
        "docs/clean-room/DISTRIBUTION-LICENSES.yaml",
        "      - .gitignore\n",
        "      - .gitignore\n      - #{path}\n"
      )
    end
    committed_failure("generic access token assignment", "credential-like assignment") do
      edit("README.md") do |content|
        "#{content}\naccess_token: CANARY_CREDENTIAL_001\n"
      end
    end
    committed_failure("generic token assignment", "credential-like assignment") do
      edit("README.md") do |content|
        "#{content}\ntoken: CANARY_CREDENTIAL_001\n"
      end
    end
    committed_failure("percent-encoded unfenced credential key", "credential-like assignment") do
      write("README.md", "access%5Ftoken = CANARY_CREDENTIAL_001\n")
    end
    committed_failure("HTML-encoded unfenced credential key", "credential-like assignment") do
      write("README.md", "access&#95;token = CANARY_CREDENTIAL_001\n")
    end
    committed_failure("JSON-encoded unfenced credential key", "credential-like assignment") do
      write("README.md", "aP\\u0049Key = CANARY_CREDENTIAL_001\n")
    end
    committed_failure("YAML-escaped credential key", "credential field") do
      write(
        "README.md",
        "\"access\\x5ftoken\": CANARY_CREDENTIAL_001\n"
      )
    end
    committed_failure(
      "Markdown image before YAML-escaped credential key",
      "credential field"
    ) do
      write(
        "README.md",
        "![FIXTURE_TECNICA](fixture)\n" \
          "\"api\\x5fkey\": CANARY_CREDENTIAL_001\n"
      )
    end
    {
      "blockquote before YAML-escaped credential key" => "> ",
      "ordered list before YAML-escaped credential key" => "1. ",
      "unordered list before YAML-escaped credential key" => "* "
    }.each do |name, prefix|
      committed_failure(name, "credential field") do
        write(
          "README.md",
          "#{prefix}\"api\\x5fkey\": CANARY_CREDENTIAL_001\n"
        )
      end
    end
    committed_failure(
      "no-space blockquote before YAML-escaped credential key",
      "credential field"
    ) do
      write("README.md", ">\"api\\x5fkey\": CANARY_CREDENTIAL_001\n")
    end
    committed_failure(
      "YAML credential key with canonical separator",
      "non-string-safe YAML key"
    ) do
      write("README.md", "\"api/key\": CANARY_CREDENTIAL_001\n")
    end
    committed_failure(
      "default-ignorable unfenced credential key",
      "credential-like assignment"
    ) do
      write(
        "README.md",
        "# FIXTURE_TECNICA\n\naccess\\u200DToken = CANARY_CREDENTIAL_001\n"
      )
    end
    committed_failure(
      "inline-code credential assignment value",
      "credential-like assignment"
    ) do
      write(
        "README.md",
        "# FIXTURE_TECNICA\n\naccessToken: `CANARY_CREDENTIAL_001`\n"
      )
    end
    committed_failure(
      "Markdown-styled credential key",
      "credential-like assignment"
    ) do
      write(
        "README.md",
        "# FIXTURE_TECNICA\n\n**accessToken**: CANARY_CREDENTIAL_001\n"
      )
    end
    committed_failure(
      "balanced-link credential key",
      "credential-like assignment"
    ) do
      write(
        "README.md",
        "# FIXTURE_TECNICA\n\n" \
          "[accessT](fixture(one))oken: CANARY_CREDENTIAL_001\n"
      )
    end
    committed_failure(
      "nested-image credential key",
      "credential-like assignment"
    ) do
      write(
        "README.md",
        "# FIXTURE_TECNICA\n\n" \
          "[access![T](image)](fixture)oken: CANARY_CREDENTIAL_001\n"
      )
    end
    committed_failure(
      "reference-image credential key",
      "credential-like assignment"
    ) do
      write(
        "README.md",
        "# FIXTURE_TECNICA\n\n" \
          "[access![T][image]](fixture)oken: CANARY_CREDENTIAL_001\n\n" \
          "[image]: fixture\n"
      )
    end
    committed_failure(
      "shortcut-image credential key",
      "credential-like assignment"
    ) do
      write(
        "README.md",
        "# FIXTURE_TECNICA\n\n" \
          "[access![T]oken](fixture): CANARY_CREDENTIAL_001\n\n" \
          "[T]: fixture\n"
      )
    end
    expect_direct_governance_failure(
      "lone-CR styled credential key",
      "credential-like assignment"
    ) do
      direct_validator.send(
        :scan_sensitive_content,
        "FIXTURE_TECNICA.md",
        "# FIXTURE_TECNICA\r**accessToken**: CANARY_CREDENTIAL_001\r"
      )
    end
    committed_failure("folded YAML credential reaches structural scanner", "credential field") do
      write(
        "README.md",
        "\"access\\u005ftoken\": >-\n  CANARY_CREDENTIAL_001\n"
      )
    end
    committed_failure("folded YAML residential field reaches structural scanner", "residential-data field") do
      write(
        "README.md",
        "\"entity\\u005fid\": >-\n  CANARY_ENTITY_001\n"
      )
    end
    committed_failure("quoted JSON access token", "credential field") do
      write("README.md", "{\"access_token\":\"CANARY_CREDENTIAL_001\"}\n")
    end
    committed_failure("escaped JSON Supervisor token", "credential field") do
      write("README.md", "{\"SUPERVISOR\\u005fTOKEN\":\"CANARY_CREDENTIAL_001\"}\n")
    end
    committed_failure("residential JSON export", "residential-data field") do
      write(
        "README.md",
        "{\"entity_id\":\"CANARY_ENTITY_001\",\"area_id\":\"CANARY_AREA_001\",\"utterance\":\"CANARY_UTTERANCE_001\"}\n"
      )
    end
    committed_failure("residential JSON embedded in Markdown", "residential-data field") do
      write(
        "README.md",
        "# FIXTURE_TECNICA\n\nPayload: {\"entity_id\":\"CANARY_ENTITY_001\",\"utterance\":\"CANARY_UTTERANCE_001\"}\n"
      )
    end
    committed_failure("nested encoded JSON credential", "credential field") do
      write(
        "README.md",
        "Payload: {\"wrapper\":\"{\\\"access_token\\\":\\\"CANARY_CREDENTIAL_001\\\"}\"}\n"
      )
    end
    committed_failure(
      "standalone-dash YAML residential string",
      "residential-data field"
    ) do
      write(
        "README.md",
        JSON.generate(
          "metadata" => "-\n  entityId: CANARY_ENTITY_001"
        ) + "\n"
      )
    end
    committed_failure(
      "malformed outer protected JSON fails closed",
      "invalid JSON payload"
    ) do
      write(
        "README.md",
        "Payload: {\"\n{\"access_token\":\"CANARY_CREDENTIAL_001\"}\n\"}\n"
      )
    end
    committed_failure(
      "lone-surrogate protected JSON key fails closed",
      "invalid JSON payload"
    ) do
      write(
        "README.md",
        "{\"access_\\uD800token\":\"CANARY_CREDENTIAL_001\"}\n"
      )
    end
    committed_failure("canonicalized structured credential key", "credential field") do
      write(
        "README.md",
        "Payload: {\"api-key\":\"CANARY_CREDENTIAL_001\"}\n"
      )
    end
    committed_failure("camelCase structured credential key", "credential field") do
      write(
        "README.md",
        "Payload: {\"clientSecret\":\"CANARY_CREDENTIAL_001\"}\n"
      )
    end
    committed_failure("camelCase structured residential key", "residential-data field") do
      write(
        "README.md",
        "Payload: {\"entityId\":\"CANARY_ENTITY_001\"}\n"
      )
    end
    committed_failure(
      "Markdown link-wrapped residential key",
      "residential-data assignment"
    ) do
      write(
        "README.md",
        "# FIXTURE_TECNICA\n\n[**entityId**](#fixture): CANARY_ENTITY_001\n"
      )
    end
    committed_failure(
      "multiline technical fixture residential assignment",
      "residential-data assignment"
    ) do
      write(
        "README.md",
        "# FIXTURE_TECNICA\n\n" \
          "entityId: FIXTURE_TECNICA\n" \
          "  CANARY_ENTITY_001\n"
      )
    end
    committed_failure(
      "duplicate technical fixture residential assignment",
      "duplicate YAML key"
    ) do
      write(
        "README.md",
        "entity_id: FIXTURE_TECNICA\n" \
          "entity_id: FIXTURE_TECNICA\n"
      )
    end
    committed_failure(
      "blockquote duplicate technical fixture residential assignment",
      "duplicate YAML key"
    ) do
      write(
        "README.md",
        "> entity_id: FIXTURE_TECNICA\n" \
          "> entity_id: FIXTURE_TECNICA\n"
      )
    end
    committed_failure(
      "Markdown prose before duplicate technical fixture assignment",
      "duplicate YAML key"
    ) do
      write(
        "README.md",
        "FIXTURE_TECNICA prose\n\n" \
          "entity_id: FIXTURE_TECNICA\n" \
          "entity_id: FIXTURE_TECNICA\n"
      )
    end
    committed_failure(
      "ordinary sibling between equivalent protected YAML keys",
      "duplicate YAML key"
    ) do
      write(
        "README.md",
        "FIXTURE_TECNICA prose\n\n" \
          "\"entity\\u0049d\": FIXTURE_TECNICA\n" \
          "fixtureKey: FIXTURE_TECNICA\n" \
          "entityId: FIXTURE_TECNICA\n"
      )
    end
    committed_failure(
      "explicit sibling between equivalent protected YAML keys",
      "duplicate YAML key"
    ) do
      write(
        "README.md",
        "FIXTURE_TECNICA prose\n\n" \
          "\"entity\\u0049d\": FIXTURE_TECNICA\n" \
          "? fixtureKey\n" \
          ": FIXTURE_TECNICA\n" \
          "entityId: FIXTURE_TECNICA\n"
      )
    end
    committed_failure(
      "merge sibling after protected YAML key",
      "YAML merge keys are prohibited"
    ) do
      write(
        "README.md",
        "FIXTURE_TECNICA prose\n\n" \
          "entityId: FIXTURE_TECNICA\n" \
          "<<: {fixtureKey: FIXTURE_TECNICA}\n" \
          "entityId: FIXTURE_TECNICA\n"
      )
    end
    committed_failure(
      "YAML document marker between protected keys",
      "YAML payload must contain exactly one document"
    ) do
      write(
        "README.md",
        "FIXTURE_TECNICA prose\n\n" \
          "entityId: FIXTURE_TECNICA\n" \
          "---\n" \
          "entityId: FIXTURE_TECNICA\n"
      )
    end
    committed_failure(
      "technical fixture residential assignment with alias sibling",
      "YAML aliases are prohibited"
    ) do
      write(
        "README.md",
        "entity_id: FIXTURE_TECNICA\n" \
          "fixtureKey: *FIXTURE_TECNICA\n"
      )
    end
    committed_failure(
      "technical fixture assignment with flow alias sibling",
      "YAML aliases are prohibited"
    ) do
      write(
        "README.md",
        "entity_id: FIXTURE_TECNICA\n" \
          "fixtureKey: [*FIXTURE_TECNICA]\n"
      )
    end
    committed_failure(
      "technical fixture assignment with flow anchor and alias sibling",
      "YAML anchors are prohibited"
    ) do
      write(
        "README.md",
        "entity_id: FIXTURE_TECNICA\n" \
          "fixtureKey: [&FIXTURE_TECNICA value, *FIXTURE_TECNICA]\n"
      )
    end
    committed_failure(
      "Markdown prose before fixture assignment with flow sibling",
      "YAML anchors are prohibited"
    ) do
      write(
        "README.md",
        "FIXTURE_TECNICA prose\n\n" \
          "entity_id: FIXTURE_TECNICA\n" \
          "fixtureKey: [&FIXTURE_TECNICA value, *FIXTURE_TECNICA]\n"
      )
    end
    committed_failure(
      "blockquote technical fixture assignment with flow alias sibling",
      "YAML aliases are prohibited"
    ) do
      write(
        "README.md",
        "> entity_id: FIXTURE_TECNICA\n" \
          "> fixtureKey: [*FIXTURE_TECNICA]\n"
      )
    end
    committed_failure(
      "malformed technical fixture continuation",
      "residential-data assignment"
    ) do
      write(
        "README.md",
        "# FIXTURE_TECNICA\n\n" \
          "entityId: FIXTURE_TECNICA\n" \
          "  : CANARY_ENTITY_001\n"
      )
    end
    committed_failure("duplicate JSON key cannot hide residential data", "duplicate JSON key") do
      write(
        "README.md",
        "Payload: {\"resident\":\"CANARY_RESIDENT_001\",\"resident\":\"FIXTURE_TECNICA\"}\n"
      )
    end
    committed_failure("friendly name is residential data", "residential-data field") do
      write("README.md", "Payload: {\"friendly_name\":\"CANARY_NAME_001\"}\n")
    end
    committed_failure("room name is residential data", "residential-data field") do
      write("README.md", "Payload: {\"room_name\":\"CANARY_ROOM_001\"}\n")
    end
    committed_failure("fixture-prefixed residential canary", "residential-data assignment") do
      write("README.md", "entity_id = FIXTURE_TECNICA_CANARY_ENTITY_001\n")
    end
    committed_failure("fixture followed by residential comment", "residential-data assignment") do
      write("README.md", "entity_id = FIXTURE_TECNICA # CANARY_ENTITY_001\n")
    end
    committed_failure("mixed fixture residential array", "residential-data field") do
      write(
        "README.md",
        "{\"entity_id\":[\"FIXTURE_TECNICA\",\"CANARY_ENTITY_001\"]}\n"
      )
    end
    committed_failure("fixture-only residential array", "residential-data field") do
      write(
        "README.md",
        "{\"entity_id\":[\"FIXTURE_TECNICA\"]}\n"
      )
    end
    committed_failure(
      "embedded JSON nesting depth",
      "embedded JSON nesting depth limit exceeded"
    ) do
      nested = ("[" * (GovernanceValidator::MAX_EMBEDDED_JSON_DEPTH + 1)) +
        '{"access_token":"FIXTURE_TECNICA"}' +
        ("]" * (GovernanceValidator::MAX_EMBEDDED_JSON_DEPTH + 1))
      write("README.md", "Payload: #{nested}\n")
    end
    committed_failure(
      "embedded JSON candidate count",
      "embedded JSON candidate limit exceeded"
    ) do
      write(
        "README.md",
        "Payload: " \
          "#{'{]' * (GovernanceValidator::MAX_EMBEDDED_JSON_CANDIDATES + 1)}" \
          "{\"access_token\":\"FIXTURE_TECNICA\"}\n"
      )
    end
    committed_failure(
      "governed synthetic data hash mismatch",
      "governed synthetic data differs from its frozen hash"
    ) do
      replace_once(
        "data/project-authored/p02-v1/heldout.jsonl",
        "quero interruptor 1 do setor sala desligado",
        "CANARY_PRIVATE_UTTERANCE"
      )
    end
    committed_failure("RSA private key marker", "private key material") do
      write("README.md", "-----BEGIN RSA PRIVATE KEY-----\nFIXTURE_TECNICA\n")
    end
    committed_failure("OpenSSH private key marker", "private key material") do
      write("README.md", "-----BEGIN OPENSSH PRIVATE KEY-----\nFIXTURE_TECNICA\n")
    end
    committed_failure("binary NUL payload", "binary NUL byte") do
      write("README.md", "FIXTURE_TECNICA\0payload")
    end
    committed_failure("invalid UTF-8 payload", "not valid UTF-8") do
      write("README.md", "FIXTURE_TECNICA\xFF".b)
    end
    committed_failure("NOASSERTION tracked license", "tracked distribution paths must use Apache-2.0") do
      replace_once(
        "docs/clean-room/DISTRIBUTION-LICENSES.yaml",
        "    license: Apache-2.0",
        "    license: NOASSERTION"
      )
    end
    committed_failure("proprietary tracked license", "tracked distribution paths must use Apache-2.0") do
      replace_once(
        "docs/clean-room/DISTRIBUTION-LICENSES.yaml",
        "    license: Apache-2.0",
        "    license: Proprietary-EULA"
      )
    end
    committed_failure("unlicensed tracked payload", "distribution license paths differ") do
      write("docs/unlicensed-payload.txt", "fixture\n")
    end
    committed_failure(
      "arbitrary payload labeled project-authored",
      "distribution license manifest differs from canonical digest"
    ) do
      write("docs/labeled-payload.txt", "FIXTURE_TECNICA\n")
      replace_once(
        "docs/clean-room/DISTRIBUTION-LICENSES.yaml",
        "      - .gitignore\n",
        "      - .gitignore\n      - docs/labeled-payload.txt\n"
      )
    end
  end

  def state_failures
    validator = direct_validator
    clean_root = Psych.safe_load(
      File.binread(File.join(@repository, "docs/phases/PROJECT-STATUS.md")),
      [],
      [],
      false
    ).fetch("seed_commit")
    validator.instance_variable_set(:@clean_root_commit, clean_root)
    blocked_status = {
      "state" => "BLOCKED",
      "subject_baseline" => "SELF_AT_CANDIDATE_COMMIT",
      "evidence_checkpoint" => nil,
      "open_findings" => ["P1-FIXTURE_TECNICA_BLOCKER"]
    }
    blocked_queue = {
      "next_action" => GovernanceValidator::P00_BLOCKED_NEXT_ACTION,
      "waiting_internal_dependencies" => [
        GovernanceValidator::P00_BLOCKED_DEPENDENCY
      ],
      "last_checkpoint" => "clean_root_#{clean_root}"
    }
    expect_direct_governance_success("exhausted P00 blocked state") do
      validator.send(
        :validate_p00_lifecycle_state,
        blocked_status,
        blocked_queue
      )
    end
    expect_direct_governance_failure(
      "blocked P00 without retained finding",
      "must retain at least one open finding"
    ) do
      validator.send(
        :validate_p00_lifecycle_state,
        blocked_status.merge("open_findings" => []),
        blocked_queue
      )
    end
    expect_direct_governance_failure(
      "blocked P00 without scope-adjudication action",
      "must request explicit user scope adjudication"
    ) do
      validator.send(
        :validate_p00_lifecycle_state,
        blocked_status,
        blocked_queue.merge(
          "next_action" => GovernanceValidator::P00_NEXT_ACTION
        )
      )
    end
    expect_direct_governance_failure(
      "blocked P00 without user-decision dependency",
      "must wait only on an explicit user scope decision"
    ) do
      validator.send(
        :validate_p00_lifecycle_state,
        blocked_status,
        blocked_queue.merge("waiting_internal_dependencies" => [])
      )
    end

    post_p00_status = {
      "state" => "IMPLEMENTATION",
      "subject_baseline" => "P12_CANDIDATE_#{"a" * 40}",
      "evidence_checkpoint" => "SELF_AT_P13_PRE_IMPLEMENTATION_COMMIT",
      "open_findings" => []
    }
    post_p00_queue = {
      "next_action" => "admit_P13_sources_and_implement_P13_minimum",
      "waiting_internal_dependencies" => [],
      "last_checkpoint" => "SELF_AT_P13_PRE_IMPLEMENTATION_COMMIT"
    }
    expect_direct_governance_success("current P13 implementation lifecycle") do
      validator.send(
        :validate_post_p00_lifecycle_state,
        post_p00_status,
        post_p00_queue,
        "P13",
        13
      )
    end
    expect_direct_governance_success("future P14 pre-phase lifecycle") do
      validator.send(
        :validate_post_p00_lifecycle_state,
        post_p00_status.merge(
          "state" => "PRE_PHASE_ANALYSIS",
          "subject_baseline" => "P13_CANDIDATE_#{"b" * 40}",
          "evidence_checkpoint" => "SELF_AT_P13_CLOSEOUT_COMMIT"
        ),
        post_p00_queue.merge(
          "next_action" => "record_P14_pre_phase_analysis",
          "last_checkpoint" => "SELF_AT_P13_CLOSEOUT_COMMIT"
        ),
        "P14",
        14
      )
    end
    expect_direct_governance_success("current-phase P14 pre-phase checkpoint") do
      validator.send(
        :validate_post_p00_lifecycle_state,
        post_p00_status.merge(
          "state" => "PRE_PHASE_ANALYSIS",
          "subject_baseline" => "P13_CANDIDATE_#{"b" * 40}",
          "evidence_checkpoint" => "SELF_AT_P14_PRE_PHASE_COMMIT"
        ),
        post_p00_queue.merge(
          "next_action" => "record_P14_pre_phase_analysis",
          "last_checkpoint" => "SELF_AT_P14_PRE_PHASE_COMMIT"
        ),
        "P14",
        14
      )
    end
    expect_direct_governance_success("current P13 reviewing lifecycle") do
      validator.send(
        :validate_post_p00_lifecycle_state,
        post_p00_status.merge(
          "state" => "REVIEWING",
          "subject_baseline" => "SELF_AT_CANDIDATE_COMMIT"
        ),
        post_p00_queue.merge(
          "next_action" => "review_P13_candidate_round_2",
          "last_checkpoint" => "P13_CANDIDATE_2_READY"
        ),
        "P13",
        13
      )
    end
    passed_post_p00_status = post_p00_status.merge(
      "state" => "PHASE_PASSED",
      "subject_baseline" => "P13_CANDIDATE_#{"d" * 40}",
      "evidence_checkpoint" => "SELF_AT_P13_CLOSEOUT_COMMIT"
    )
    passed_post_p00_queue = post_p00_queue.merge(
      "next_action" => "checkpoint_P13_closeout",
      "last_checkpoint" => "SELF_AT_P13_CLOSEOUT_COMMIT"
    )
    expect_direct_governance_success("current P13 phase-passed lifecycle") do
      validator.send(
        :validate_post_p00_lifecycle_state,
        passed_post_p00_status,
        passed_post_p00_queue,
        "P13",
        13
      )
    end

    blocked_post_p00_status = post_p00_status.merge(
      "state" => "BLOCKED",
      "subject_baseline" => "P13_CANDIDATE_#{"c" * 40}",
      "open_findings" => ["P13-P2-FIXTURE_TECNICA_BLOCKER"]
    )
    blocked_post_p00_queue = post_p00_queue.merge(
      "next_action" =>
        "request_explicit_user_scope_decision_for_exhausted_P13_round_budget",
      "waiting_internal_dependencies" => [
        GovernanceValidator::P00_BLOCKED_DEPENDENCY
      ],
      "last_checkpoint" => "SELF_AT_P13_BLOCKER_COMMIT"
    )
    expect_direct_governance_success("coherent post-P00 blocked lifecycle") do
      validator.send(
        :validate_post_p00_lifecycle_state,
        blocked_post_p00_status,
        blocked_post_p00_queue,
        "P13",
        13
      )
    end
    {
      "post-P00 blocked without finding" => [
        blocked_post_p00_status.merge("open_findings" => []),
        blocked_post_p00_queue,
        "must retain at least one open finding"
      ],
      "post-P00 blocked with unrelated finding" => [
        blocked_post_p00_status.merge(
          "open_findings" => ["P12-P2-FIXTURE_TECNICA_BLOCKER"]
        ),
        blocked_post_p00_queue,
        "open finding must identify the current phase"
      ],
      "post-P00 blocked with embedded phase substring" => [
        blocked_post_p00_status.merge(
          "open_findings" => ["P12-P2-fooP13bar"]
        ),
        blocked_post_p00_queue.merge(
          "next_action" =>
            "request_explicit_user_scope_decision_for_fooP13bar"
        ),
        "next_action must identify the current phase"
      ],
      "post-P00 blocked with bare phase finding" => [
        blocked_post_p00_status.merge("open_findings" => ["P13"]),
        blocked_post_p00_queue,
        "must be severity-bearing and actionable"
      ],
      "post-P00 blocked with severity but no actionable detail" => [
        blocked_post_p00_status.merge("open_findings" => ["P13-P2"]),
        blocked_post_p00_queue,
        "must be severity-bearing and actionable"
      ],
      "post-P00 blocked with arbitrary subject" => [
        blocked_post_p00_status.merge("subject_baseline" => "ARBITRARY"),
        blocked_post_p00_queue,
        "subject baseline is not coherent"
      ],
      "post-P00 blocked with arbitrary evidence checkpoint" => [
        blocked_post_p00_status.merge(
          "evidence_checkpoint" => "SELF_AT_P13_ARBITRARY_COMMIT"
        ),
        blocked_post_p00_queue,
        "evidence checkpoint is not coherent"
      ],
      "post-P00 blocked with arbitrary queue checkpoint" => [
        blocked_post_p00_status,
        blocked_post_p00_queue.merge(
          "last_checkpoint" => "SELF_AT_P13_ARBITRARY_COMMIT"
        ),
        "queue checkpoint is not coherent"
      ],
      "post-P00 blocked without blocker checkpoint" => [
        blocked_post_p00_status,
        blocked_post_p00_queue.merge(
          "last_checkpoint" => "SELF_AT_P13_PRE_IMPLEMENTATION_COMMIT"
        ),
        "checkpoints must identify the active stage and current-phase blocker"
      ],
      "post-P00 blocked without scope action" => [
        blocked_post_p00_status,
        blocked_post_p00_queue.merge(
          "next_action" => "implement_P13_optional_refinement"
        ),
        "must request explicit user scope adjudication"
      ],
      "post-P00 blocked with wrong dependency" => [
        blocked_post_p00_status,
        blocked_post_p00_queue.merge("waiting_internal_dependencies" => []),
        "must wait only on an explicit user scope decision"
      ]
    }.each do |name, (candidate_status, candidate_queue, message)|
      expect_direct_governance_failure(name, message) do
        validator.send(
          :validate_post_p00_lifecycle_state,
          candidate_status,
          candidate_queue,
          "P13",
          13
        )
      end
    end
    expect_direct_governance_failure(
      "phase-passed prior subject and pre-implementation checkpoints",
      "PHASE_PASSED post-P00 subject baseline is not coherent"
    ) do
      validator.send(
        :validate_post_p00_lifecycle_state,
        post_p00_status.merge("state" => "PHASE_PASSED"),
        post_p00_queue,
        "P13",
        13
      )
    end
    expect_direct_governance_failure(
      "phase-passed pre-implementation evidence checkpoint",
      "PHASE_PASSED post-P00 checkpoints are not coherent"
    ) do
      validator.send(
        :validate_post_p00_lifecycle_state,
        passed_post_p00_status.merge(
          "evidence_checkpoint" => "SELF_AT_P13_PRE_IMPLEMENTATION_COMMIT"
        ),
        passed_post_p00_queue,
        "P13",
        13
      )
    end
    expect_direct_governance_failure(
      "phase-passed pre-implementation queue checkpoint",
      "PHASE_PASSED post-P00 checkpoints are not coherent"
    ) do
      validator.send(
        :validate_post_p00_lifecycle_state,
        passed_post_p00_status,
        passed_post_p00_queue.merge(
          "last_checkpoint" => "SELF_AT_P13_PRE_IMPLEMENTATION_COMMIT"
        ),
        "P13",
        13
      )
    end
    expect_direct_governance_failure(
      "reviewing without current candidate checkpoint",
      "REVIEWING post-P00 checkpoints must identify"
    ) do
      validator.send(
        :validate_post_p00_lifecycle_state,
        post_p00_status.merge(
          "state" => "REVIEWING",
          "subject_baseline" => "SELF_AT_CANDIDATE_COMMIT"
        ),
        post_p00_queue.merge("next_action" => "review_P13_candidate"),
        "P13",
        13
      )
    end

    committed_failure("terminal state contradiction", "nonterminal state is invalid") do
      edit("docs/phases/PROJECT-STATUS.md") do |content|
        content.sub(
          /^state: [A-Z_]+$/,
          "state: DEVELOPMENT_COMPLETE"
        )
      end
    end
    committed_failure("report status contradiction", "report status differs") do
      replace_once(
        "docs/phases/P00-REPORT.md",
        "Status: `PHASE_PASSED`",
        "Status: `IMPLEMENTING`"
      )
    end
    expect_direct_governance_failure(
      "coherent but stale P00 implementing state",
      "P00 state must be REVIEWING or BLOCKED"
    ) do
      validator.send(
        :validate_p00_lifecycle_state,
        blocked_status.merge("state" => "IMPLEMENTING"),
        blocked_queue
      )
    end
    expect_direct_governance_failure(
      "reviewing with open finding",
      "cannot retain open findings"
    ) do
      validator.send(
        :validate_post_p00_lifecycle_state,
        post_p00_status.merge(
          "state" => "REVIEWING",
          "subject_baseline" => "SELF_AT_CANDIDATE_COMMIT",
          "open_findings" => ["P13-P1-FIXTURE_TECNICA"]
        ),
        post_p00_queue.merge(
          "next_action" => "review_P13_candidate_round_2",
          "last_checkpoint" => "P13_CANDIDATE_2_READY"
        ),
        "P13",
        13
      )
    end
    committed_failure(
      "stale last validation timestamp",
      "last_validation phase marker is invalid"
    ) do
      edit("docs/phases/PROJECT-STATUS.md") do |content|
        content.sub(
          /^last_validation: "[^"]+"$/,
          'last_validation: "2000-01-01T00:00:00Z"'
        )
      end
    end
  end

  def build_p00_checkpoint(extra_change: false)
    subject_commit = git("rev-parse", "HEAD").strip
    subject_tree = git("rev-parse", "HEAD^{tree}").strip
    GovernanceCheckpointValidator::REVIEW_PATHS.each_with_index do |(role, path), index|
      write(
        path,
        <<~MARKDOWN
          # P00 #{role} review

          Role: `#{role}`
          Reviewer instance: `00000000-0000-4000-8000-#{format('%012x', index + 1)}`
          Independent context: `true`
          Report conclusion ignored: `true`
          Primary evidence inspected: `true`
          Read-only review: `true`
          Subject commit: `#{subject_commit}`
          Subject tree: `#{subject_tree}`

          ## Scope

          Paths: `docs/evidence/REQUIREMENTS-TRACEABILITY.md`
          FIXTURE_TECNICA_SCOPE_001

          ## Commands

          `tools/validate-governance`

          ## Positive Evidence

          Inputs: FIXTURE_TECNICA_INPUT_001
          Results: FIXTURE_TECNICA_EVIDENCE_001

          ## Counterexample Attempts

          FIXTURE_TECNICA_COUNTEREXAMPLE_001

          ## Findings

          None.

          Verdict: `PASS`
        MARKDOWN
      )
    end
    edit("docs/phases/PROJECT-STATUS.md") do |content|
      content
        .sub("current_phase: P00", "current_phase: P01")
        .sub("state: REVIEWING", "state: IMPLEMENTING")
        .sub("subject_baseline: SELF_AT_CANDIDATE_COMMIT", "subject_baseline: null")
        .sub("evidence_checkpoint: null", "evidence_checkpoint: SELF_AT_CHECKPOINT_COMMIT")
        .sub("completed_phases: []", "completed_phases:\n  - P00")
    end
    edit("docs/phases/AUTONOMOUS-QUEUE.yaml") do |content|
      content
        .sub("active_item: P00", "active_item: P01")
        .sub(
          "next_action: validate_exact_P00_candidate_commit_and_tree_then_run_reviews",
          "next_action: #{GovernanceCheckpointValidator::NEXT_ACTION}"
        )
        .sub("  - P01\n", "")
        .sub(
          /^last_checkpoint: .+$/,
          "last_checkpoint: P00_EVIDENCE_SELF_AT_CHECKPOINT_COMMIT"
        )
    end
    edit("docs/phases/P00-REPORT.md") do |content|
      content
        .sub("Status: `REVIEWING`", "Status: `PHASE_PASSED`")
        .concat(
          "\nReviewed subject commit: `#{subject_commit}`\n" \
          "Reviewed subject tree: `#{subject_tree}`\n"
        )
    end
    edit("docs/evidence/P00-VALIDATION.md") do |content|
      report_hashes = GovernanceCheckpointValidator::REVIEW_PATHS.map do |role, path|
        digest = Digest::SHA256.file(File.join(@repository, path)).hexdigest
        "- `#{role}`: `#{digest}`"
      end.join("\n")
      content +
        "\n## P00 Evidence Checkpoint\n\n" \
        "Reviewed subject commit: `#{subject_commit}`\n" \
        "Reviewed subject tree: `#{subject_tree}`\n\n" \
        "Reviewer-owned report SHA-256 values:\n\n#{report_hashes}\n"
    end
    edit("docs/evidence/REQUIREMENTS-TRACEABILITY.md") do |content|
      content.lines.map do |line|
        columns = line.chomp.split("|", -1)[1..7]&.map(&:strip)
        p00_review_pending = columns&.fetch(3, nil) == "P00" &&
          columns&.fetch(6, nil) == "REVIEW_PENDING"
        if p00_review_pending ||
           (line.start_with?("| `P00-REV-") && line.end_with?("| PENDING |\n"))
          line.sub(/\| (?:REVIEW_PENDING|PENDING) \|\n\z/, "| SATISFIED |\n")
        else
          line
        end
      end.join
    end
    refresh_requirement_manifest_digest("p00_statuses_sha256")
    review_license_paths = GovernanceCheckpointValidator::REVIEW_PATHS.values
      .map { |path| "      - #{path}\n" }
      .join
    edit("docs/clean-room/DISTRIBUTION-LICENSES.yaml") do |content|
      content.sub(
        "      - docs/reviews/P00/pre-phase-requirements.md\n",
        "      - docs/reviews/P00/pre-phase-requirements.md\n#{review_license_paths}"
      )
    end
    edit("README.md") { |content| "#{content}\nFIXTURE_TECNICA_EXTRA_SCOPE\n" } if extra_change
    yield(subject_commit, subject_tree) if block_given?
    git("add", "--all")
    git("commit", "--quiet", "-m", "evidence: checkpoint P00")
    [subject_commit, subject_tree]
  end

  def refresh_checkpoint_report_hashes
    edit("docs/evidence/P00-VALIDATION.md") do |content|
      GovernanceCheckpointValidator::REVIEW_PATHS.reduce(content) do |updated, (role, path)|
        digest = Digest::SHA256.file(File.join(@repository, path)).hexdigest
        pattern = /- `#{Regexp.escape(role)}`: `[0-9a-f]{64}`/
        replacement = "- `#{role}`: `#{digest}`"
        raise TestFailure, "checkpoint hash line not found for #{role}" unless
          updated.match?(pattern)

        updated.sub(pattern, replacement)
      end
    end
  end

  def checkpoint_failure(name, expected_message)
    with_case_repository do
      subject_commit, subject_tree = build_p00_checkpoint do
        yield if block_given?
      end
      stdout, stderr, status = validate(
        checkpoint_subject_commit: subject_commit,
        checkpoint_subject_tree: subject_tree
      )
      combined = "#{stderr}#{stdout}"
      if status.success? || !combined.include?(expected_message)
        raise TestFailure,
              "#{name} was not rejected for #{expected_message.inspect}: #{combined}"
      end
      @passed += 1
    end
  end

  def checkpoint_success(name)
    with_case_repository do
      subject_commit, subject_tree = build_p00_checkpoint do
        yield if block_given?
      end
      stdout, stderr, status = validate(
        checkpoint_subject_commit: subject_commit,
        checkpoint_subject_tree: subject_tree
      )
      unless status.success? && stderr.empty? &&
             stdout.start_with?("governance checkpoint validation passed")
        raise TestFailure, "#{name} unexpectedly failed: #{stderr}#{stdout}"
      end
      @passed += 1
    end
  end

  def checkpoint_validation
    current_status = Psych.safe_load(
      File.binread(File.join(@repository, "docs/phases/PROJECT-STATUS.md")),
      [],
      [],
      false
    )
    unless current_status.fetch("current_phase") == "P00"
      post_p00_checkpoint_validation
      return
    end

    with_case_repository do
      subject_commit, subject_tree = build_p00_checkpoint
      stdout, stderr, status = validate(
        checkpoint_subject_commit: subject_commit,
        checkpoint_subject_tree: subject_tree
      )
      unless status.success? && stderr.empty? &&
             stdout.start_with?("governance checkpoint validation passed")
        raise TestFailure, "valid P00 checkpoint failed: #{stderr}#{stdout}"
      end
      @passed += 1
    end

    with_case_repository do
      subject_commit, subject_tree = build_p00_checkpoint
      sensitive_tree = fixture_tree_with_path(
        subject_tree,
        "history-credential.yaml",
        "token: CANARY_CREDENTIAL_TAG_001\n"
      )
      sensitive_commit = git(
        "commit-tree",
        sensitive_tree,
        "-p", subject_commit,
        "-m", "negative fixture: checkpoint tag ref"
      ).strip
      git(
        "update-ref",
        "refs/tags/fixture-checkpoint-sensitive",
        sensitive_commit
      )
      stdout, stderr, status = validate(
        checkpoint_subject_commit: subject_commit,
        checkpoint_subject_tree: subject_tree
      )
      combined = "#{stderr}#{stdout}"
      if status.success? || !combined.include?("credential")
        raise TestFailure,
              "checkpoint omitted sensitive tag ref: #{combined}"
      end
      @passed += 1
    end

    with_case_repository do
      subject_commit, subject_tree = build_p00_checkpoint
      checkpoint_tree = git("rev-parse", "HEAD^{tree}").strip
      stdout, stderr, status = validate(
        commit: "0" * 40,
        tree: checkpoint_tree,
        preflight: false,
        checkpoint_subject_commit: subject_commit,
        checkpoint_subject_tree: subject_tree
      )
      combined = "#{stderr}#{stdout}"
      if status.success? ||
         !combined.include?("checkpoint HEAD differs from expected commit")
        raise TestFailure,
              "checkpoint identity error was preempted: #{combined}"
      end
      @passed += 1
    end

    with_case_repository do
      subject_commit, subject_tree = build_p00_checkpoint
      conceal_same_size_worktree_change(
        "README.md",
        "Deterministic PT-BR NLU",
        "deterministic PT-BR NLU"
      )
      stdout, stderr, status = validate(
        checkpoint_subject_commit: subject_commit,
        checkpoint_subject_tree: subject_tree
      )
      combined = "#{stderr}#{stdout}"
      expected =
        "checkpoint worktree file differs from committed bytes or mode: README.md"
      if status.success? || !combined.include?(expected)
        raise TestFailure,
              "same-size hidden checkpoint mutation was not rejected: #{combined}"
      end
      @passed += 1
    end

    checkpoint_failure(
      "substantive checkpoint change",
      "changed paths differ from the evidence-only set"
    ) do
      edit("README.md") { |content| "#{content}\nFIXTURE_TECNICA_EXTRA_SCOPE\n" }
    end

    checkpoint_failure(
      "checkpoint terminal guard change",
      "queue differs from the exact transition"
    ) do
      replace_once(
        "docs/phases/AUTONOMOUS-QUEUE.yaml",
        "terminal_guard: ARMED",
        "terminal_guard: DISARMED"
      )
    end

    checkpoint_failure(
      "checkpoint prematurely satisfies cross-phase requirement",
      "checkpoint requirement status differs for USR-002"
    ) do
      edit("docs/evidence/REQUIREMENTS-TRACEABILITY.md") do |content|
        content.sub(
          /(\| `USR-002` \|[^\n]*\|) PENDING \|/,
          "\\1 SATISFIED |"
        )
      end
      refresh_requirement_manifest_digest("p00_statuses_sha256")
    end

    checkpoint_failure(
      "checkpoint prematurely satisfies global no-supervisor requirement",
      "checkpoint requirement status differs for USR-001"
    ) do
      edit("docs/evidence/REQUIREMENTS-TRACEABILITY.md") do |content|
        content.sub(
          /(\| `USR-001` \|[^\n]*\|) PENDING \|/,
          "\\1 SATISFIED |"
        )
      end
      refresh_requirement_manifest_digest("p00_statuses_sha256")
    end

    checkpoint_failure(
      "checkpoint malformed requirement ID",
      "malformed checkpoint requirement ID"
    ) do
      replace_once(
        "docs/evidence/REQUIREMENTS-TRACEABILITY.md",
        "| `P00-ROOT-001` |",
        "| `P00 ROOT 001` |"
      )
    end

    with_case_repository do
      subject_commit, subject_tree = build_p00_checkpoint
      checkpoint_tree = git("rev-parse", "HEAD^{tree}").strip
      wrong_parent = git("rev-parse", "#{subject_commit}^").strip
      rewritten = git(
        "commit-tree",
        checkpoint_tree,
        "-p", wrong_parent,
        "-m", "negative fixture: wrong checkpoint parent"
      ).strip
      git("reset", "--hard", rewritten)
      stdout, stderr, status = validate(
        checkpoint_subject_commit: subject_commit,
        checkpoint_subject_tree: subject_tree
      )
      combined = "#{stderr}#{stdout}"
      if status.success? ||
         !combined.include?("must have the reviewed subject as its sole parent")
        raise TestFailure, "wrong-parent checkpoint was accepted: #{combined}"
      end
      @passed += 1
    end

    with_case_repository do
      subject_commit, subject_tree = build_p00_checkpoint
      checkpoint_tree = git("rev-parse", "HEAD^{tree}").strip
      second_parent = git("rev-parse", "#{subject_commit}^").strip
      rewritten = git(
        "commit-tree",
        checkpoint_tree,
        "-p", subject_commit,
        "-p", second_parent,
        "-m", "negative fixture: merge checkpoint"
      ).strip
      git("reset", "--hard", rewritten)
      stdout, stderr, status = validate(
        checkpoint_subject_commit: subject_commit,
        checkpoint_subject_tree: subject_tree
      )
      combined = "#{stderr}#{stdout}"
      if status.success? ||
         !combined.include?("must have the reviewed subject as its sole parent")
        raise TestFailure, "merge checkpoint was accepted: #{combined}"
      end
      @passed += 1
    end

    checkpoint_failure(
      "checkpoint duplicate queue key",
      "duplicate checkpoint YAML key"
    ) do
      edit("docs/phases/AUTONOMOUS-QUEUE.yaml") do |content|
        "#{content}active_item: FINAL\n"
      end
    end

    checkpoint_failure(
      "checkpoint deeply nested queue YAML",
      "checkpoint YAML AST exceeds depth limit"
    ) do
      content = "leaf: FIXTURE_TECNICA\n"
      70.times do |index|
        content = "level#{index}:\n" +
          content.each_line.map { |line| "  #{line}" }.join
      end
      write("docs/phases/AUTONOMOUS-QUEUE.yaml", content)
    end

    checkpoint_failure(
      "checkpoint release-rule weakening",
      "beyond the canonical evidence delta"
    ) do
      replace_once(
        "docs/clean-room/DISTRIBUTION-LICENSES.yaml",
        "reject_excluded_input_in_archive: true",
        "reject_excluded_input_in_archive: false"
      )
    end

    checkpoint_failure(
      "checkpoint empty command evidence",
      "empty Commands section"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-tests")
      replace_once(path, "`tools/validate-governance`", "")
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint report trusts the phase conclusion",
      "lacks Report conclusion ignored: `true`"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-requirements")
      replace_once(
        path,
        "Report conclusion ignored: `true`",
        "Report conclusion ignored: `false`"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint report skips primary evidence",
      "lacks Primary evidence inspected: `true`"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-correctness")
      replace_once(
        path,
        "Primary evidence inspected: `true`",
        "Primary evidence inspected: `false`"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint report edits during review",
      "lacks Read-only review: `true`"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "Read-only review: `true`",
        "Read-only review: `false`"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint report omits inspected path",
      "lacks an inspected path"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-tests")
      replace_once(
        path,
        "Paths: `docs/evidence/REQUIREMENTS-TRACEABILITY.md`",
        "Paths: FIXTURE_TECNICA_PATH_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint report omits cited inputs",
      "lacks cited inputs"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-tests")
      replace_once(path, "Inputs:", "Input:")
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint report omits reproducible results",
      "lacks reproducible results"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-reproducibility")
      replace_once(path, "Results:", "Result:")
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint unresolved report finding",
      "contains unresolved findings"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(path, "None.", "P1: FIXTURE_TECNICA_FINDING_001")
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint finding before canonical report body",
      "has a noncanonical prefix"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "# P00 review-risk review\n\n",
        "# P00 review-risk review\n\nP1: FIXTURE_TECNICA_FINDING_001\n\n"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint finding after verdict",
      "has a noncanonical suffix"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-tests")
      edit(path) do |content|
        "#{content}P1: FIXTURE_TECNICA_FINDING_001\n"
      end
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint finding outside Findings section",
      "contains unresolved findings"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_SCOPE_001",
        "P1: FIXTURE_TECNICA_FINDING_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint plus-list finding outside Findings section",
      "contains unresolved findings"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_SCOPE_001",
        "+ P1: FIXTURE_TECNICA_FINDING_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint blockquoted finding outside Findings section",
      "contains unresolved findings"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_SCOPE_001",
        "> P1: FIXTURE_TECNICA_FINDING_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint styled finding outside Findings section",
      "contains unresolved findings"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_SCOPE_001",
        "**P1:** FIXTURE_TECNICA_FINDING_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint Scope preamble",
      "lacks an inspected path"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "Paths: `docs/evidence/REQUIREMENTS-TRACEABILITY.md`",
        "FIXTURE_TECNICA_SCOPE_PREAMBLE\nPaths: `docs/evidence/REQUIREMENTS-TRACEABILITY.md`"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint Scope contains multiple code spans",
      "lacks an inspected path"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "Paths: `docs/evidence/REQUIREMENTS-TRACEABILITY.md`",
        "Paths: `docs/evidence/REQUIREMENTS-TRACEABILITY.md` `README.md`"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint Scope decodes to multiple code spans",
      "lacks an inspected path"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "Paths: `docs/evidence/REQUIREMENTS-TRACEABILITY.md`",
        "Paths: `docs/evidence/REQUIREMENTS-TRACEABILITY.md%60 %60README.md`"
      )
      refresh_checkpoint_report_hashes
    end

    {
      "literal carriage return" => "\r",
      "percent-encoded carriage return" => "%0D",
      "HTML-encoded carriage return" => "&#13;",
      "JSON-encoded carriage return" => "\\u000D"
    }.each do |name, encoded_carriage_return|
      checkpoint_failure(
        "checkpoint Scope #{name}",
        "lacks an inspected path"
      ) do
        path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
        replace_once(
          path,
          "Paths: `docs/evidence/REQUIREMENTS-TRACEABILITY.md`",
          "Paths: `docs/evidence/REQUIREMENTS-TRACEABILITY.md" \
            "#{encoded_carriage_return}README.md`"
        )
        refresh_checkpoint_report_hashes
      end
    end

    checkpoint_failure(
      "checkpoint reversed evidence fields",
      "has out-of-order evidence fields"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "Inputs: FIXTURE_TECNICA_INPUT_001\nResults: FIXTURE_TECNICA_EVIDENCE_001",
        "Results: FIXTURE_TECNICA_EVIDENCE_001\nInputs: FIXTURE_TECNICA_INPUT_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint percent-encoded contradictory verdict",
      "contradictory verdict"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-correctness")
      replace_once(
        path,
        "FIXTURE_TECNICA_SCOPE_001",
        "Verd%69ct%3A %60FAIL%60"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint JSON-encoded contradictory verdict",
      "contradictory verdict"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-correctness")
      replace_once(
        path,
        "FIXTURE_TECNICA_SCOPE_001",
        "Verd\\u0069ct\\u003a `FAIL`"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint HTML-encoded finding severity",
      "contains unresolved findings"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_SCOPE_001",
        "P&#49;&#58; FIXTURE_TECNICA_FINDING_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint HTML-comment finding severity",
      "contains unresolved findings"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-tests")
      replace_once(
        path,
        "FIXTURE_TECNICA_COUNTEREXAMPLE_001",
        "<!-- P1: CANARY_UNRESOLVED_001 -->"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint HTML declaration finding severity",
      "contains unresolved findings"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-tests")
      replace_once(
        path,
        "FIXTURE_TECNICA_COUNTEREXAMPLE_001",
        "P<!FIXTURE_TECNICA>1: CANARY_UNRESOLVED_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint HTML processing-instruction finding severity",
      "contains unresolved findings"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-tests")
      replace_once(
        path,
        "FIXTURE_TECNICA_COUNTEREXAMPLE_001",
        "P<?FIXTURE_TECNICA?>1: CANARY_UNRESOLVED_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint HTML CDATA finding severity",
      "contains unresolved findings"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-tests")
      replace_once(
        path,
        "FIXTURE_TECNICA_COUNTEREXAMPLE_001",
        "P<![CDATA[FIXTURE_TECNICA]]>1: CANARY_UNRESOLVED_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_success("checkpoint visible autolinks") do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-tests")
      replace_once(
        path,
        "FIXTURE_TECNICA_COUNTEREXAMPLE_001",
        "P<https://fixture.invalid>1 and P<fixture@example.invalid>2"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint quoted-attribute HTML finding severity",
      "contains unresolved findings"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-tests")
      replace_once(
        path,
        "FIXTURE_TECNICA_COUNTEREXAMPLE_001",
        "P<span title=\">\">1: CANARY_UNRESOLVED_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint multiline HTML finding severity",
      "contains unresolved findings"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-tests")
      replace_once(
        path,
        "FIXTURE_TECNICA_COUNTEREXAMPLE_001",
        "P<span\n title=\"FIXTURE_TECNICA\">1: CANARY_UNRESOLVED_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint nested malformed HTML finding severity",
      "contains unresolved findings"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-tests")
      replace_once(
        path,
        "FIXTURE_TECNICA_COUNTEREXAMPLE_001",
        "<x P<span>1: CANARY_UNRESOLVED_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint invalid-link finding severity",
      "contains unresolved findings"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-correctness")
      replace_once(
        path,
        "FIXTURE_TECNICA_COUNTEREXAMPLE_001",
        "[safe](fixture P1: CANARY_UNRESOLVED_001)"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint Markdown-encoded contradictory verdict",
      "contradictory verdict"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-correctness")
      replace_once(
        path,
        "FIXTURE_TECNICA_SCOPE_001",
        "V**er**dict: `FAIL`"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint Markdown autolink contradictory verdict",
      "contradictory verdict"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-correctness")
      replace_once(
        path,
        "FIXTURE_TECNICA_SCOPE_001",
        "<Verdict:FAIL>"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint default-ignorable contradictory verdict",
      "contradictory verdict"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-correctness")
      replace_once(
        path,
        "FIXTURE_TECNICA_SCOPE_001",
        "Ver\\u200Ddict: `FAIL`"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint contradictory verdict",
      "contradictory verdict"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-correctness")
      replace_once(
        path,
        "Verdict: `PASS`",
        "Verdict: `FAIL`\nVerdict: `PASS`"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint indented contradictory verdict",
      "contradictory verdict"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-correctness")
      replace_once(
        path,
        "Verdict: `PASS`",
        "  Verdict: `FAIL`\n\nVerdict: `PASS`"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint styled contradictory verdict",
      "contradictory verdict"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-correctness")
      replace_once(
        path,
        "Verdict: `PASS`",
        "**Verdict:** `FAIL`\n\nVerdict: `PASS`"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint balanced-link contradictory verdict",
      "contradictory verdict"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-correctness")
      replace_once(
        path,
        "Verdict: `PASS`",
        "[Ver](fixture(one))dict: `FAIL`\n\nVerdict: `PASS`"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint nested-image contradictory verdict",
      "contradictory verdict"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-correctness")
      replace_once(
        path,
        "Verdict: `PASS`",
        "[Ver![d](image)ict](fixture): `FAIL`\n\nVerdict: `PASS`"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint reference-image contradictory verdict",
      "contradictory verdict"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-correctness")
      replace_once(
        path,
        "Verdict: `PASS`",
        "[Ver![d][image]ict](fixture): `FAIL`\n\n" \
          "[image]: fixture\n\nVerdict: `PASS`"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint shortcut-image contradictory verdict",
      "contradictory verdict"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-correctness")
      replace_once(
        path,
        "Verdict: `PASS`",
        "[Ver![d]ict](fixture): `FAIL`\n\n" \
          "[d]: fixture\n\nVerdict: `PASS`"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint reused reviewer identity",
      "reuse reviewer instance"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-correctness")
      replace_once(
        path,
        "00000000-0000-4000-8000-000000000002",
        "00000000-0000-4000-8000-000000000001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint unfenced camelCase credential",
      "credential-like assignment"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        "accessToken: CANARY_CREDENTIAL_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint inline-code credential value",
      "credential-like assignment"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        "accessToken: `CANARY_CREDENTIAL_001`"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint Markdown-styled credential key",
      "credential-like assignment"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        "**accessToken**: CANARY_CREDENTIAL_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint unfenced camelCase residential assignment",
      "residential-data assignment"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        "entityId: CANARY_ENTITY_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint Markdown link-wrapped residential key",
      "residential-data assignment"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        "[**entityId**](#fixture): CANARY_ENTITY_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint multiline technical fixture residential assignment",
      "residential-data assignment"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "Results: FIXTURE_TECNICA_EVIDENCE_001",
        "Results: FIXTURE_TECNICA_EVIDENCE_001\n\n" \
          "entityId: FIXTURE_TECNICA\n" \
          "  CANARY_ENTITY_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint malformed technical fixture continuation",
      "residential-data assignment"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "Results: FIXTURE_TECNICA_EVIDENCE_001",
        "Results: FIXTURE_TECNICA_EVIDENCE_001\n\n" \
          "entityId: FIXTURE_TECNICA\n" \
          "  : CANARY_ENTITY_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint dotted residential equals assignment",
      "residential-data assignment"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        "entity.ID = CANARY_ENTITY_001"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint camelCase credential",
      "credential field"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        '{"accessToken":"CANARY_CREDENTIAL_001"}'
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint camelCase residential key",
      "residential-data field"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        '{"entityId":"CANARY_ENTITY_001"}'
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint escaped acronym credential key",
      "credential field"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        '{"aP\\u0049Key":"CANARY_CREDENTIAL_001"}'
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint escaped acronym residential key",
      "residential-data field"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        '{"eNTITY\\u0049d":"CANARY_ENTITY_001"}'
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint nested JSON fragment overflow",
      "embedded JSON fragment limit exceeded"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      fragments = (1..GovernanceValidator::MAX_EMBEDDED_JSON_FRAGMENTS).map do |index|
        JSON.generate("fixture#{index}" => "FIXTURE_TECNICA")
      end
      fragments << JSON.generate("accessToken" => "CANARY_CREDENTIAL_001")
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        JSON.generate("fixture" => fragments.join)
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint embedded JSON nesting depth",
      "embedded JSON nesting depth limit exceeded"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      nested = ("[" * (GovernanceValidator::MAX_EMBEDDED_JSON_DEPTH + 1)) +
        "0" +
        ("]" * (GovernanceValidator::MAX_EMBEDDED_JSON_DEPTH + 1))
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        nested
      )
      refresh_checkpoint_report_hashes
    end

    with_case_repository do
      report_hashes = nil
      subject_commit, subject_tree = build_p00_checkpoint do
        path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
        oversized =
          "X" * (GovernanceCheckpointValidator::MAX_REVIEW_REPORT_BYTES + 1)
        replace_once(
          path,
          "FIXTURE_TECNICA_SCOPE_001",
          "#{oversized} \nFIXTURE_TECNICA_SCOPE_001"
        )
        refresh_checkpoint_report_hashes
        report_hashes = GovernanceCheckpointValidator::REVIEW_PATHS.to_h do |role, report_path|
          [
            role,
            Digest::SHA256.file(File.join(@repository, report_path)).hexdigest
          ]
        end
      end
      check_stdout, check_stderr, check_status = git(
        "show",
        "--check",
        "--format=",
        "--no-renames",
        "HEAD",
        allow_failure: true
      )
      check_output = "#{check_stderr}#{check_stdout}"
      if check_status.success? || !check_output.include?("trailing whitespace")
        raise TestFailure,
              "oversized report fixture lacks a whitespace error: #{check_output}"
      end

      stdout, stderr, status = validate(
        checkpoint_subject_commit: subject_commit,
        checkpoint_subject_tree: subject_tree,
        checkpoint_report_sha256: report_hashes
      )
      combined = "#{stderr}#{stdout}"
      expected = "checkpoint review report exceeds byte limit"
      if status.success? || !combined.include?(expected)
        raise TestFailure,
              "checkpoint report size was not checked before whitespace: #{combined}"
      end
      @passed += 1
    end

    checkpoint_failure(
      "checkpoint NUL-bearing report",
      "NUL byte"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        "FIXTURE_TECNICA_EVIDENCE_001\0"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint deeply nested fenced YAML",
      "YAML AST exceeds depth limit"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      nested = "leaf: FIXTURE_TECNICA\n"
      70.times do |index|
        nested = "level#{index}:\n" +
          nested.each_line.map { |line| "  #{line}" }.join
      end
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        "FIXTURE_TECNICA_EVIDENCE_001\n\n```yaml\n#{nested}```"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint tilde-fenced duplicate YAML key",
      "duplicate YAML key"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        <<~YAML.chomp
          FIXTURE_TECNICA_EVIDENCE_001

          ~~~yaml
          "fixture\\u004bey": FIXTURE_TECNICA
          fixtureKey: FIXTURE_TECNICA
          ~~~
        YAML
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint indented four-backtick YAML fence",
      "duplicate YAML key"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      fenced = [
        "FIXTURE_TECNICA_EVIDENCE_001",
        "",
        "   ````yaml",
        "   fixtureKey: FIXTURE_TECNICA",
        "   fixtureKey: FIXTURE_TECNICA",
        "   `````"
      ].join("\n")
      replace_once(path, "FIXTURE_TECNICA_EVIDENCE_001", fenced)
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint indented five-tilde YAML fence",
      "duplicate YAML key"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      fenced = [
        "FIXTURE_TECNICA_EVIDENCE_001",
        "",
        "  ~~~~~ yml",
        "  fixtureKey: FIXTURE_TECNICA",
        "  fixtureKey: FIXTURE_TECNICA",
        "  ~~~~~~"
      ].join("\n")
      replace_once(path, "FIXTURE_TECNICA_EVIDENCE_001", fenced)
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint attributed tilde YAML fence",
      "duplicate YAML key"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      fenced = [
        "FIXTURE_TECNICA_EVIDENCE_001",
        "",
        "~~~~yml title=FIXTURE_TECNICA",
        "fixtureKey: FIXTURE_TECNICA",
        "fixtureKey: FIXTURE_TECNICA",
        "~~~~"
      ].join("\n")
      replace_once(path, "FIXTURE_TECNICA_EVIDENCE_001", fenced)
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint escaped duplicate YAML key",
      "duplicate YAML key"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "Results: FIXTURE_TECNICA_EVIDENCE_001",
        <<~YAML.chomp
          Results: FIXTURE_TECNICA_EVIDENCE_001

          ```yaml
          "entity\\u0049d": CANARY_RESIDENTIAL_001
          entityId: FIXTURE_TECNICA
          ```
        YAML
      )
      refresh_checkpoint_report_hashes
    end
    checkpoint_failure(
      "checkpoint escaped duplicate YAML key around ordinary sibling",
      "duplicate YAML key"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "Results: FIXTURE_TECNICA_EVIDENCE_001",
        <<~YAML.chomp
          Results: FIXTURE_TECNICA_EVIDENCE_001

          "entity\\u0049d": FIXTURE_TECNICA
          fixtureKey: FIXTURE_TECNICA
          entityId: FIXTURE_TECNICA
        YAML
      )
      refresh_checkpoint_report_hashes
    end
    checkpoint_failure(
      "checkpoint escaped duplicate YAML key around explicit sibling",
      "duplicate YAML key"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "Results: FIXTURE_TECNICA_EVIDENCE_001",
        <<~YAML.chomp
          Results: FIXTURE_TECNICA_EVIDENCE_001

          "entity\\u0049d": FIXTURE_TECNICA
          ? fixtureKey
          : FIXTURE_TECNICA
          entityId: FIXTURE_TECNICA
        YAML
      )
      refresh_checkpoint_report_hashes
    end
    checkpoint_failure(
      "checkpoint YAML document marker between protected keys",
      "YAML payload must contain exactly one document"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "Results: FIXTURE_TECNICA_EVIDENCE_001",
        <<~YAML.chomp
          Results: FIXTURE_TECNICA_EVIDENCE_001

          entityId: FIXTURE_TECNICA
          ---
          entityId: FIXTURE_TECNICA
        YAML
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint flow-set provider key",
      "must be a nonempty string"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "Results: FIXTURE_TECNICA_EVIDENCE_001",
        "Results: FIXTURE_TECNICA_EVIDENCE_001\n\n" \
          "```yaml\n" \
          "{provider}\n" \
          "```"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint slash-separated credential key",
      "non-string-safe YAML key"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "Results: FIXTURE_TECNICA_EVIDENCE_001",
        "Results: FIXTURE_TECNICA_EVIDENCE_001\n\n" \
          "api/key: FIXTURE_TECNICA"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint indentless sequence anchor after protected fixture",
      "YAML anchors are prohibited"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "Results: FIXTURE_TECNICA_EVIDENCE_001",
        <<~YAML.chomp
          Results: FIXTURE_TECNICA_EVIDENCE_001

          entityId: FIXTURE_TECNICA
          fixtureKey:
          - &FIXTURE_TECNICA FIXTURE_TECNICA
        YAML
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint unsafe sibling before protected fixture",
      "YAML anchors are prohibited"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "Results: FIXTURE_TECNICA_EVIDENCE_001",
        <<~YAML.chomp
          Results: FIXTURE_TECNICA_EVIDENCE_001

          fixtureKey: &FIXTURE_TECNICA FIXTURE_TECNICA
          entityId: FIXTURE_TECNICA
        YAML
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint complex sibling after protected fixture",
      "non-scalar YAML key"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "Results: FIXTURE_TECNICA_EVIDENCE_001",
        <<~YAML.chomp
          Results: FIXTURE_TECNICA_EVIDENCE_001

          entityId: FIXTURE_TECNICA
          ? [fixtureKey]
          : FIXTURE_TECNICA
        YAML
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint comment-prefixed YAML provider string",
      "Amazon-owned provider metadata"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      payload = JSON.generate(
        "metadata" => "# FIXTURE_TECNICA\nprovider: A%57S"
      )
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        payload
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint malformed embedded YAML payload",
      "invalid embedded YAML payload"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      payload = JSON.generate(
        "metadata" => "---\nprovider: A%57S\n[\n"
      )
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        payload
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint malformed JSON provider payload",
      "invalid JSON payload"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_EVIDENCE_001",
        '{"provider":"A%57S",}'
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint encoded prohibited URL",
      "Amazon-owned repository organization"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_COUNTEREXAMPLE_001",
        "https%3A%2F%2Fgithub.com%2Faws%2Ffixture"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint encoded prohibited package",
      "Amazon-specific package coordinate"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      replace_once(
        path,
        "FIXTURE_TECNICA_COUNTEREXAMPLE_001",
        "%40aws-sdk%2Ffixture"
      )
      refresh_checkpoint_report_hashes
    end

    checkpoint_failure(
      "checkpoint symlinked review report",
      "evidence file mode differs"
    ) do
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      absolute = File.join(@repository, path)
      FileUtils.rm_f(absolute)
      File.symlink("review-tests.md", absolute)
      refresh_checkpoint_report_hashes
    end

    with_case_repository do
      subject_commit, subject_tree = build_p00_checkpoint
      report_hashes = GovernanceCheckpointValidator::REVIEW_PATHS.to_h do |role, report_path|
        [role, Digest::SHA256.file(File.join(@repository, report_path)).hexdigest]
      end
      path = GovernanceCheckpointValidator::REVIEW_PATHS.fetch("review-risk")
      absolute = File.join(@repository, path)
      FileUtils.rm_f(absolute)
      FileUtils.mkdir_p(absolute)
      command(@git, "init", "--quiet", chdir: absolute)
      command(@git, "config", "user.name", "Governance Test", chdir: absolute)
      command(
        @git,
        "config",
        "user.email",
        "governance-test.invalid",
        chdir: absolute
      )
      command(
        @git,
        "commit",
        "--quiet",
        "--allow-empty",
        "-m",
        "negative fixture: gitlink target",
        chdir: absolute
      )
      git("rm", "--quiet", "--cached", "--force", path)
      git("add", path)
      git("commit", "--quiet", "-m", "negative fixture: checkpoint gitlink")
      gitlink_tree = git("rev-parse", "HEAD^{tree}").strip
      rewritten = git(
        "commit-tree",
        gitlink_tree,
        "-p", subject_commit,
        "-m", "negative fixture: checkpoint gitlink"
      ).strip
      git("reset", "--hard", rewritten)
      stdout, stderr, status = validate(
        checkpoint_subject_commit: subject_commit,
        checkpoint_subject_tree: subject_tree,
        checkpoint_report_sha256: report_hashes
      )
      combined = "#{stderr}#{stdout}"
      if status.success? || !combined.include?("evidence file mode differs")
        raise TestFailure, "gitlinked checkpoint report was accepted: #{combined}"
      end
      @passed += 1
    end

    with_case_repository do
      subject_commit, subject_tree = build_p00_checkpoint
      report_hashes = GovernanceCheckpointValidator::REVIEW_PATHS.to_h do |role, path|
        [role, Digest::SHA256.file(File.join(@repository, path)).hexdigest]
      end
      report_hashes["review-risk"] = "0" * 64
      stdout, stderr, status = validate(
        checkpoint_subject_commit: subject_commit,
        checkpoint_subject_tree: subject_tree,
        checkpoint_report_sha256: report_hashes
      )
      if status.success? ||
         !("#{stderr}#{stdout}".include?("differs from the external tuple"))
        raise TestFailure, "checkpoint report substitution was accepted: #{stderr}#{stdout}"
      end
      @passed += 1
    end

    with_case_repository do
      subject_commit, subject_tree = build_p00_checkpoint
      checkpoint_commit = git("rev-parse", "HEAD").strip
      checkpoint_tree = git("rev-parse", "HEAD^{tree}").strip
      report_hashes = GovernanceCheckpointValidator::REVIEW_PATHS.to_h do |role, path|
        [role, Digest::SHA256.file(File.join(@repository, path)).hexdigest]
      end
      GovernanceCLI::CHECKPOINT_REPORT_HASH_OPTIONS.each_key do |key|
        option = "--#{key.to_s.tr('_', '-')}"
        arguments = checkpoint_arguments(
          checkpoint_commit: checkpoint_commit,
          checkpoint_tree: checkpoint_tree,
          subject_commit: subject_commit,
          subject_tree: subject_tree,
          report_sha256: report_hashes
        )
        index = arguments.index(option)
        arguments.slice!(index, 2)
        stdout, stderr, status = command(*arguments, allow_failure: true)
        unless !status.success? &&
               "#{stderr}#{stdout}".include?("is required for checkpoint validation")
          raise TestFailure, "missing checkpoint report hash was accepted: #{option}"
        end
        @passed += 1

        arguments = checkpoint_arguments(
          checkpoint_commit: checkpoint_commit,
          checkpoint_tree: checkpoint_tree,
          subject_commit: subject_commit,
          subject_tree: subject_tree,
          report_sha256: report_hashes
        )
        index = arguments.index(option)
        arguments[index + 1] = "malformed"
        stdout, stderr, status = command(*arguments, allow_failure: true)
        unless !status.success? &&
               "#{stderr}#{stdout}".include?("invalid for")
          raise TestFailure, "malformed checkpoint report hash was accepted: #{option}"
        end
        @passed += 1
      end
    end
  end

  def post_p00_checkpoint_validation
    with_case_repository do
      subject_commit = git("rev-parse", "HEAD").strip
      subject_tree = git("rev-parse", "HEAD^{tree}").strip
      edit("README.md") do |content|
        "#{content}\nFIXTURE_TECNICA_POST_P00_CHECKPOINT\n"
      end
      git("add", "README.md")
      git("commit", "--quiet", "-m", "negative fixture: post-P00 checkpoint")
      report_hashes = GovernanceCheckpointValidator::REVIEW_PATHS.to_h do |role, _path|
        [role, "0" * 64]
      end
      stdout, stderr, status = validate(
        preflight: false,
        checkpoint_subject_commit: subject_commit,
        checkpoint_subject_tree: subject_tree,
        checkpoint_report_sha256: report_hashes
      )
      combined = "#{stderr}#{stdout}"
      if status.success? ||
         !combined.include?("checkpoint subject phase must be P00")
        raise TestFailure,
              "post-P00 checkpoint was not rejected by phase: #{combined}"
      end
      @passed += 1
    end
  end

  def archive_and_worktree_successes
    sensitive_scan_success(
      "exact technical residential fixture",
      "entity_id: FIXTURE_TECNICA\n"
    )
    sensitive_scan_success(
      "exact technical fixture with YAML sibling",
      "- entityId: FIXTURE_TECNICA\n" \
        "  fixtureKey: FIXTURE_TECNICA\n"
    )
    sensitive_scan_success(
      "exact technical fixture in flow YAML",
      "{entityId: FIXTURE_TECNICA, fixtureKey: FIXTURE_TECNICA}\n"
    )
    sensitive_scan_success(
      "quoted technical fixture with YAML comment",
      "entityId: \"FIXTURE_TECNICA\" # fixture\n"
    )
    sensitive_scan_success(
      "folded technical fixture",
      "entityId: >-\n  FIXTURE_TECNICA\n"
    )
    sensitive_scan_success(
      "literal technical fixture",
      "entityId: |-\n  FIXTURE_TECNICA\n"
    )
    sensitive_scan_success(
      "escaped multiline quoted technical fixture",
      "entityId: \"FIXTURE_\\\n  TECNICA\"\n"
    )
    sensitive_scan_success(
      "multiline flow technical fixture",
      "{entityId:\n  FIXTURE_TECNICA,\n" \
        " fixtureKey: FIXTURE_TECNICA}\n"
    )

    with_case_repository do
      path = "docs/#{"x" * 110}/a.txt"
      write(path, "FIXTURE_TECNICA\n")
      git("add", path)
      git("commit", "--quiet", "-m", "fixture: PAX long directory path")
      archive = git("archive", "--format=tar", "HEAD").b
      validator = GovernanceValidator.new(
        root: @repository,
        expected_commit: "0" * 40,
        expected_tree: "0" * 40,
        expected_normative_rows_sha256: @trusted_normative_rows_sha256,
        expected_review_file_sha256: @trusted_review_file_sha256,
        launcher_path: File.join(@repository, "tools/validate-governance")
      )
      parsed = validator.send(:parse_tar_regular_paths, archive)
      expected = git("ls-tree", "-r", "--name-only", "HEAD").lines.map(&:strip)
      unless parsed.sort == expected.sort
        raise TestFailure, "PAX state leaked across a nonregular entry"
      end
      @passed += 1
    end

    with_case_repository do
      info_attributes = File.join(@repository, ".git/info/attributes")
      File.open(info_attributes, "ab") do |file|
        file.write("README.md export-ignore\n")
      end
      stdout, stderr, status = validate
      unless status.success? && stdout.include?("governance validation passed")
        raise TestFailure, "repository-local attributes affected isolated archive: #{stderr}#{stdout}"
      end
      @passed += 1
    end

    with_case_repository do
      ignored_path = "docs/adr/ADR-9999-ignored.md"
      File.open(File.join(@repository, ".git/info/exclude"), "ab") do |file|
        file.write("/#{ignored_path}\n")
      end
      write(ignored_path, "# FIXTURE_TECNICA ignored local ADR\n")
      stdout, stderr, status = validate
      unless status.success? && stdout.include?("governance validation passed")
        raise TestFailure, "ignored local ADR affected subject: #{stderr}#{stdout}"
      end
      @passed += 1
    end
  end
end

begin
  GovernanceValidatorTests.new.run
rescue TestFailure => error
  warn "governance validator tests failed: #{error.message}"
  exit 1
end
