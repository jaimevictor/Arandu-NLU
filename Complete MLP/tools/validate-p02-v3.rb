# frozen_string_literal: true
# SPDX-License-Identifier: Apache-2.0

require "digest"
require "json"
require "open3"
require "optparse"
require "set"

require_relative "generate-p02-v3-corpus"

module P02V3Validation
  RELEASE_LOADER_BOUNDARY = "P02V3_RELEASE_LOADER_BOUNDARY_V1"

  class Failure < StandardError; end
  class DuplicateKeyError < StandardError; end

  class DuplicateRejectingHash < Hash
    def []=(key, value)
      raise DuplicateKeyError, key if key?(key)

      super
    end
  end

  MAX_ARTIFACT_BYTES = 24 * 1024 * 1024
  MAX_MANIFEST_BYTES = 1024 * 1024
  MAX_ROW_BYTES = 32 * 1024
  MAX_SEMANTIC_RECORDS = 5_000
  MAX_SUITE_RECORDS = 16
  MAX_SOURCE_BYTES = 2 * 1024 * 1024
  MAX_SOURCE_TOTAL_BYTES = 128 * 1024 * 1024
  MAX_SOURCE_INVENTORY_BYTES = 4 * 1024 * 1024
  MAX_SOURCE_INVENTORY_PATHS = 50_000
  MAX_SOURCE_INVENTORY_STDERR_BYTES = 64 * 1024
  GIT_EXECUTABLE = "/usr/bin/git"

  IO_OPERATION_PATTERN = Regexp.union(
    /File\.(?:binread|read|open|foreach|readlines)/,
    /IO\.(?:binread|read|open|foreach|readlines)/,
    /Path(?:name)?\([^)]*\)\.(?:read|read_text|read_bytes|open)/,
    /fs\.(?:readFile|readFileSync|createReadStream|open)/,
    /std::fs::(?:read|read_to_string|File::open)/,
    /\bread_bounded_root_file\s*\(/,
    /\bread_verified\s*\(/,
    /\b(?:open|read_to_string|read_bytes)\s*\(/
  ).freeze

  module_function

  def strict_json(bytes, context)
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    raise Failure, "#{context} is not valid UTF-8" unless text.valid_encoding?

    JSON.parse(
      text,
      object_class: DuplicateRejectingHash,
      array_class: Array,
      create_additions: false,
      max_nesting: 64
    )
  rescue JSON::ParserError, DuplicateKeyError => error
    raise Failure, "#{context} is invalid JSON: #{error.class}"
  end

  def read_regular(path, maximum, context, root: nil)
    P02V3Corpus.read_regular(
      path,
      maximum,
      context,
      root: root || File.dirname(File.expand_path(path))
    )
  rescue P02V3Corpus::Failure => error
    raise Failure, error.message
  end

  def parse_jsonl(bytes, expected_count, maximum_count, context)
    raise Failure, "#{context} is empty" if bytes.empty?
    raise Failure, "#{context} must end with LF" unless bytes.end_with?("\n")
    raise Failure, "#{context} contains CR bytes" if bytes.include?("\r")
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    raise Failure, "#{context} is not valid UTF-8" unless text.valid_encoding?

    rows = []
    text.each_line do |line|
      raise Failure, "#{context} contains a blank row" if line == "\n"
      raise Failure, "#{context} row exceeds the byte limit" if
        line.bytesize > MAX_ROW_BYTES
      raise Failure, "#{context} exceeds the record limit" if
        rows.length >= maximum_count
      row = strict_json(line, "#{context} row")
      raise Failure, "#{context} row is not an object" unless row.is_a?(Hash)
      rows << row
    end
    raise Failure, "#{context} record count differs" unless
      rows.length == expected_count

    rows
  end

  def assert_disjoint!(sets, context)
    sets.each_with_index do |left, left_index|
      sets.each_with_index do |right, right_index|
        next unless left_index < right_index
        next if (left & right).empty?

        raise Failure, "#{context} crosses partitions"
      end
    end
  end

  def source_candidate?(_relative)
    true
  end

  def normalize_source_paths!(paths, maximum_paths: MAX_SOURCE_INVENTORY_PATHS)
    raise Failure, "source path inventory must be an array" unless
      paths.is_a?(Array)
    raise Failure, "source path inventory exceeds the path limit" if
      paths.length > maximum_paths

    seen = Set.new
    normalized = paths.map do |relative|
      raise Failure, "source path is not valid UTF-8" unless
        relative.is_a?(String) && relative.valid_encoding?
      raise Failure, "source path contains NUL" if relative.include?("\0")
      raise Failure, "source path contains a line delimiter" if
        relative.include?("\n") || relative.include?("\r")
      begin
        P02V3Corpus.validate_relative_path!(relative, "source")
      rescue P02V3Corpus::Failure => error
        raise Failure, error.message
      end
      raise Failure, "source path inventory contains duplicates" unless
        seen.add?(relative)

      relative
    end
    normalized.sort
  end

  def parse_source_inventory(
    bytes,
    maximum_bytes: MAX_SOURCE_INVENTORY_BYTES,
    maximum_paths: MAX_SOURCE_INVENTORY_PATHS
  )
    raise Failure, "source inventory exceeds the byte limit" if
      bytes.bytesize > maximum_bytes
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    raise Failure, "source inventory is not valid UTF-8" unless
      text.valid_encoding?
    return [] if text.empty?
    raise Failure, "source inventory NUL framing is invalid" unless
      text.end_with?("\0")

    paths = text.split("\0", -1)
    trailing = paths.pop
    raise Failure, "source inventory NUL framing is invalid" unless
      trailing == "" && paths.none?(&:empty?)
    normalize_source_paths!(paths, maximum_paths: maximum_paths)
  end

  def close_quietly(io)
    io.close unless io.nil? || io.closed?
  rescue IOError, SystemCallError
    nil
  end

  def terminate_and_reap(wait_thread)
    return nil if wait_thread.nil?

    if wait_thread.alive?
      begin
        Process.kill("TERM", wait_thread.pid)
      rescue Errno::ESRCH
        nil
      end
      unless wait_thread.join(0.25)
        begin
          Process.kill("KILL", wait_thread.pid)
        rescue Errno::ESRCH
          nil
        end
        wait_thread.join
      end
    end
    wait_thread.value
  rescue Errno::ECHILD
    nil
  end

  def capture_bounded_subprocess(
    executable,
    arguments,
    environment,
    stdout_limit:,
    stderr_limit:
  )
    raise Failure, "bounded command executable must be absolute" unless
      executable.is_a?(String) &&
      File.expand_path(executable) == executable
    raise Failure, "bounded command executable is unavailable" unless
      File.file?(executable) && !File.symlink?(executable)
    raise Failure, "bounded command arguments must be an array" unless
      arguments.is_a?(Array) &&
      arguments.all? do |argument|
        argument.is_a?(String) && !argument.include?("\0")
      end
    raise Failure, "bounded command environment must be a mapping" unless
      environment.is_a?(Hash) &&
      environment.all? do |key, value|
        key.is_a?(String) && value.is_a?(String) &&
          !key.include?("\0") && !value.include?("\0")
      end
    [stdout_limit, stderr_limit].each do |limit|
      raise Failure, "bounded command limit is invalid" unless
        limit.is_a?(Integer) && limit >= 0
    end

    stdin = nil
    stdout = nil
    stderr = nil
    wait_thread = nil
    begin
      stdin, stdout, stderr, wait_thread = Open3.popen3(
        environment,
        executable,
        *arguments,
        unsetenv_others: true
      )
      close_quietly(stdin)
      stdout.binmode
      stderr.binmode
      stdout_state = {
        "name" => "stdout",
        "limit" => stdout_limit,
        "bytes" => "".b
      }
      stderr_state = {
        "name" => "stderr",
        "limit" => stderr_limit,
        "bytes" => "".b
      }
      streams = {
        stdout => stdout_state,
        stderr => stderr_state
      }

      until streams.empty?
        readable = IO.select(streams.keys)
        next if readable.nil?

        readable.first.each do |io|
          stream = streams.fetch(io)
          remaining =
            stream.fetch("limit") + 1 - stream.fetch("bytes").bytesize
          chunk = io.read_nonblock(remaining, exception: false)
          case chunk
          when :wait_readable
            next
          when nil
            streams.delete(io)
            close_quietly(io)
          else
            stream.fetch("bytes") << chunk
            if stream.fetch("bytes").bytesize > stream.fetch("limit")
              terminate_and_reap(wait_thread)
              raise Failure,
                    "bounded command #{stream.fetch('name')} exceeds the byte limit"
            end
          end
        end
      end

      status = wait_thread.value
      raise Failure, "bounded command exited unsuccessfully" unless
        status.success?

      [
        stdout_state.fetch("bytes"),
        stderr_state.fetch("bytes")
      ]
    rescue Failure
      terminate_and_reap(wait_thread)
      raise
    rescue SystemCallError, IOError => error
      terminate_and_reap(wait_thread)
      raise Failure, "bounded command failed: #{error.class}"
    ensure
      close_quietly(stdin)
      close_quietly(stdout)
      close_quietly(stderr)
    end
  end

  def repository_source_paths(root, confinement)
    executable = confinement.fetch("source_inventory_executable")
    environment = confinement.fetch("source_inventory_environment")
    maximum_bytes = confinement.fetch("source_inventory_maximum_bytes")
    maximum_paths = confinement.fetch("source_inventory_maximum_paths")
    maximum_stderr =
      confinement.fetch("source_inventory_maximum_stderr_bytes")
    raise Failure, "source inventory executable differs" unless
      executable == GIT_EXECUTABLE
    raise Failure, "source inventory executable is unavailable" unless
      File.file?(executable) && !File.symlink?(executable)
    begin
      root_expanded, _root_resolved =
        P02V3Corpus.resolved_root(root, "source inventory")
    rescue P02V3Corpus::Failure => error
      raise Failure, error.message
    end
    repository_arguments =
      explicit_repository_arguments(root_expanded, confinement)
    excluded_pathspecs =
      confinement.fetch("source_inventory_excluded_pathspecs")
    unless excluded_pathspecs == [
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
    ]
      raise Failure, "source inventory exclusions differ"
    end

    stdout, stderr = capture_bounded_subprocess(
      executable,
      repository_arguments + [
        "-c",
        "core.quotepath=false",
        "-c",
        "core.excludesFile=/dev/null",
        "-c",
        "core.bare=false",
        "ls-files",
        "--cached",
        "--others",
        "-z",
        "--",
        *excluded_pathspecs.map { |path| ":(exclude)#{path}" }
      ],
      environment,
      stdout_limit: maximum_bytes,
      stderr_limit: maximum_stderr
    )
    raise Failure, "source inventory emitted stderr" unless stderr.empty?

    parse_source_inventory(
      stdout,
      maximum_bytes: maximum_bytes,
      maximum_paths: maximum_paths
    )
  rescue SystemCallError => error
    raise Failure, "source inventory command failed: #{error.class}"
  end

  def explicit_repository_arguments(root_expanded, confinement)
    unless confinement.fetch("source_inventory_repository_binding") ==
           "EXPLICIT_DOT_GIT_DIRECTORY_AND_ROOT_WORK_TREE"
      raise Failure, "source inventory repository binding differs"
    end
    git_dir = File.join(root_expanded, ".git")
    unless File.directory?(git_dir) && !File.symlink?(git_dir)
      raise Failure, "source inventory Git directory is unavailable"
    end

    [
      "--git-dir=#{git_dir}",
      "--work-tree=#{root_expanded}"
    ]
  end

  def parse_baseline_inventory(bytes, maximum_bytes:, maximum_paths:)
    raise Failure, "source I/O baseline exceeds the byte limit" if
      bytes.bytesize > maximum_bytes
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    raise Failure, "source I/O baseline is not valid UTF-8" unless
      text.valid_encoding?
    return {} if text.empty?
    raise Failure, "source I/O baseline NUL framing is invalid" unless
      text.end_with?("\0")

    entries = text.split("\0", -1)
    entries.pop
    raise Failure, "source I/O baseline exceeds the path limit" if
      entries.length > maximum_paths
    entries.each_with_object({}) do |entry, result|
      match = entry.match(/\A([0-7]{6}) blob ([0-9a-f]{40})\t(.+)\z/)
      raise Failure, "source I/O baseline entry is malformed" unless match
      relative = match[3]
      P02V3Corpus.validate_relative_path!(relative, "source I/O baseline")
      raise Failure, "source I/O baseline contains duplicates" if
        result.key?(relative)
      result[relative] = {
        "mode" => match[1],
        "oid" => match[2]
      }
    end
  rescue P02V3Corpus::Failure => error
    raise Failure, error.message
  end

  def git_blob_oid(bytes)
    Digest::SHA1.hexdigest("blob #{bytes.bytesize}\0".b + bytes.b)
  end

  def repository_baseline_entries(root, confinement)
    commit = confinement.fetch("source_io_baseline_commit")
    raise Failure, "source I/O baseline commit is invalid" unless
      commit.match?(/\A[0-9a-f]{40}\z/)
    root_expanded, _root_resolved =
      P02V3Corpus.resolved_root(root, "source I/O baseline")
    repository_arguments =
      explicit_repository_arguments(root_expanded, confinement)
    stdout, stderr = capture_bounded_subprocess(
      confinement.fetch("source_inventory_executable"),
      repository_arguments + [
        "-c",
        "core.quotepath=false",
        "-c",
        "core.excludesFile=/dev/null",
        "-c",
        "core.bare=false",
        "ls-tree",
        "-r",
        "-z",
        commit
      ],
      confinement.fetch("source_inventory_environment"),
      stdout_limit: confinement.fetch("source_inventory_maximum_bytes"),
      stderr_limit:
        confinement.fetch("source_inventory_maximum_stderr_bytes")
    )
    raise Failure, "source I/O baseline inventory emitted stderr" unless
      stderr.empty?

    parse_baseline_inventory(
      stdout,
      maximum_bytes: confinement.fetch("source_inventory_maximum_bytes"),
      maximum_paths: confinement.fetch("source_inventory_maximum_paths")
    )
  rescue P02V3Corpus::Failure => error
    raise Failure, error.message
  end

  def release_reference?(source, confinement)
    full_paths = confinement.fetch("release_artifact_paths")
    return true if full_paths.any? { |path| source.include?(path) }

    release_roots = full_paths.map do |path|
      components = path.split("/")
      raise Failure, "release artifact path is outside the expected root" unless
        components.length >= 4 &&
        components.fetch(0) == "data"

      components.first(3)
    end.uniq
    raise Failure, "release artifact roots differ" unless release_roots.length == 1

    normalized_source = source.downcase.gsub(/[^a-z0-9]/, "")
    root_tokens = release_roots.fetch(0).drop(1).flat_map do |component|
      component.downcase.split(/[^a-z0-9]+/)
    end
    release_tokens = %w[
      heldout
      performance
      ambiguity
      contradiction
      explicitnegative
      safetysensitive
      stalestate
    ]
    root_tokens.all? do |token|
      !token.empty? && normalized_source.include?(token)
    end && release_tokens.any? { |token| normalized_source.include?(token) }
  end

  def scan_loader_sources!(root, confinement, source_paths = nil)
    maximum_paths = confinement.fetch("source_inventory_maximum_paths")
    paths = if source_paths
              normalize_source_paths!(
                source_paths,
                maximum_paths: maximum_paths
              )
            else
              repository_source_paths(root, confinement)
            end
    allowed_paths = normalize_source_paths!(
      confinement.fetch("current_allowed_source_paths") +
        confinement.fetch("future_allowed_source_paths"),
      maximum_paths: maximum_paths
    )
    allowed = allowed_paths.to_set
    future_mutable = normalize_source_paths!(
      confinement.fetch("future_mutable_source_paths"),
      maximum_paths: maximum_paths
    ).to_set
    unless (allowed & future_mutable).empty?
      raise Failure, "release and mutable source inventories overlap"
    end
    unless confinement.fetch("source_change_policy") ==
           "EVERY_INVENTORIED_PROJECT_PATH_BLOB_BOUND_AND_EVERY_CHANGE_PREDECLARED"
      raise Failure, "source change policy differs"
    end
    unless confinement.fetch("mutable_source_capability_policy") ==
           "ALL_MUTABLE_PATHS_TREATED_AS_IO_CAPABLE_WITHOUT_SYNTAX_CLASSIFICATION"
      raise Failure, "mutable source capability policy differs"
    end
    baseline = source_paths ?
      {} :
      repository_baseline_entries(root, confinement)
    total_bytes = 0

    paths.each do |relative|
      path = File.join(root, relative)
      bytes = read_regular(
        path,
        MAX_SOURCE_BYTES,
        "source file",
        root: root
      )
      total_bytes += bytes.bytesize
      raise Failure, "source scan exceeds the total byte limit" if
        total_bytes > MAX_SOURCE_TOTAL_BYTES

      entry = baseline[relative]
      differs_from_baseline =
        entry.nil? || git_blob_oid(bytes) != entry.fetch("oid")
      unless allowed.include?(relative) || future_mutable.include?(relative)
        if entry
          raise Failure, "authorization-parent source blob differs" if
            differs_from_baseline
          next
        end

        raise Failure, "source is outside the reviewed mutable inventory"
      end
      unless differs_from_baseline ||
             allowed.include?(relative) ||
             future_mutable.include?(relative)
        next
      end

      source = bytes.dup.force_encoding(Encoding::UTF_8)
      raise Failure, "changed source file is not valid UTF-8" unless
        source.valid_encoding?
      if allowed.include?(relative)
        if differs_from_baseline
          raise Failure, "release loader boundary marker is missing" unless
            source.include?(confinement.fetch("boundary_marker"))
        end
      elsif future_mutable.include?(relative)
        if differs_from_baseline
          raise Failure, "mutable source boundary marker is missing" unless
            source.include?(
              confinement.fetch("mutable_source_boundary_marker")
            )
        end
      end
    end

    confinement.fetch("current_allowed_source_paths").each do |relative|
      path = File.join(root, relative)
      source = read_regular(
        path,
        MAX_SOURCE_BYTES,
        "required loader boundary source",
        root: root
      )
      raise Failure, "required loader boundary marker is missing" unless
        source.include?(confinement.fetch("boundary_marker"))
    end
    confinement.fetch("future_allowed_source_paths").each do |relative|
      path = File.join(root, relative)
      next unless File.exist?(path)

      source = read_regular(
        path,
        MAX_SOURCE_BYTES,
        "future release boundary source",
        root: root
      )
      entry = baseline[relative]
      next if entry && git_blob_oid(source) == entry.fetch("oid")

      raise Failure, "release loader boundary marker is missing" unless
        source.include?(confinement.fetch("boundary_marker"))
    end
    future_mutable.each do |relative|
      path = File.join(root, relative)
      next unless File.exist?(path)

      source = read_regular(
        path,
        MAX_SOURCE_BYTES,
        "future mutable boundary source",
        root: root
      )
      entry = baseline[relative]
      next if entry && git_blob_oid(source) == entry.fetch("oid")

      raise Failure, "mutable source boundary marker is missing" unless
        source.include?(confinement.fetch("mutable_source_boundary_marker"))
    end
    true
  rescue SystemCallError => error
    raise Failure, "source loader scan failed: #{error.class}"
  end

  def validate_integrity_entries!(root, entries)
    paths = entries.map { |entry| entry.fetch("path") }
    raise Failure, "manifest artifact paths are not sorted and unique" unless
      paths == paths.sort && paths.uniq.length == paths.length
    raise Failure, "manifest artifact path set differs" unless
      paths == P02V3Corpus::ARTIFACT_PATHS

    entries.each do |entry|
      P02V3Corpus.exact_keys!(
        entry,
        %w[path partition records bytes sha256 artifact_id],
        "manifest artifact"
      )
      path = entry.fetch("path")
      raise Failure, "artifact partition differs" unless
        entry.fetch("partition") ==
          P02V3Corpus::ARTIFACT_PARTITIONS.fetch(path)
      bytes = read_regular(
        File.join(root, path),
        MAX_ARTIFACT_BYTES,
        "artifact #{path}",
        root: root
      )
      digest = Digest::SHA256.hexdigest(bytes)
      raise Failure, "artifact byte count differs" unless
        entry.fetch("bytes") == bytes.bytesize
      raise Failure, "artifact SHA-256 differs" unless
        entry.fetch("sha256") == digest
      raise Failure, "artifact identity differs" unless
        entry.fetch("artifact_id") == "p02v3qf-artifact-#{digest}"
      raise Failure, "artifact record count differs" unless
        entry.fetch("records") == bytes.lines.length
      raise Failure, "artifact matches a prior-lineage identity" if
        P02V3Corpus::PRIOR_V2_ARTIFACT_HASHES.values.include?(digest)
    end
    true
  end

  def contained_file_inventory(root, maximum_paths: 256)
    begin
      root_expanded, root_resolved =
        P02V3Corpus.resolved_root(root, "corpus inventory")
    rescue P02V3Corpus::Failure => error
      raise Failure, error.message
    end
    files = []
    pending = [["", root_expanded]]

    until pending.empty?
      relative_parent, absolute_parent = pending.shift
      Dir.children(absolute_parent).sort.each do |name|
        relative = relative_parent.empty? ?
          name : "#{relative_parent}/#{name}"
        begin
          P02V3Corpus.validate_relative_path!(relative, "corpus inventory")
        rescue P02V3Corpus::Failure => error
          raise Failure, error.message
        end
        absolute = File.join(root_expanded, relative)
        stat = File.lstat(absolute)
        raise Failure, "corpus inventory contains a symlink component" if
          stat.symlink?
        resolved = File.realpath(absolute)
        raise Failure, "corpus inventory resolves outside the selected root" unless
          P02V3Corpus.path_beneath?(resolved, root_resolved)

        if stat.directory?
          pending << [relative, absolute]
        elsif stat.file?
          files << relative
          raise Failure, "corpus inventory exceeds the path limit" if
            files.length > maximum_paths
        else
          raise Failure, "corpus inventory contains a non-file entry"
        end
      end
    end
    files.sort
  rescue SystemCallError => error
    raise Failure, "corpus inventory failed: #{error.class}"
  end

  class Validator
    def initialize(data_root)
      @data_root = File.expand_path(data_root)
      @spec = P02V3Corpus.load_spec
      P02V3Corpus.validate_specification!(@spec)
    end

    def validate
      expected_bytes = P02V3Corpus.generated_bytes
      validate_path_set(expected_bytes.keys)
      expected_bytes.each do |relative, bytes|
        actual = P02V3Validation.read_regular(
          File.join(@data_root, relative),
          relative == P02V3Corpus::MANIFEST_PATH ?
            MAX_MANIFEST_BYTES : MAX_ARTIFACT_BYTES,
          relative,
          root: @data_root
        )
        raise Failure, "generated artifact differs: #{relative}" unless
          actual.b == bytes.b
      end

      manifest_bytes = P02V3Validation.read_regular(
        File.join(@data_root, P02V3Corpus::MANIFEST_PATH),
        MAX_MANIFEST_BYTES,
        "manifest",
        root: @data_root
      )
      manifest = P02V3Validation.strict_json(manifest_bytes, "manifest")
      validate_manifest(manifest)
      P02V3Validation.validate_integrity_entries!(
        @data_root,
        manifest.fetch("artifacts")
      )
      records_by_partition = validate_semantic_splits(manifest)
      validate_suites(manifest, records_by_partition)
      P02V3Corpus.validate_partition_separation!(records_by_partition)
      P02V3Corpus.validate_record_language!(@spec, records_by_partition)
      P02V3Validation.scan_loader_sources!(
        P02V3Corpus::ROOT,
        @spec.fetch("loader_confinement")
      )
      manifest
    rescue P02V3Corpus::Failure => error
      raise Failure, error.message
    end

    private

    def validate_path_set(expected_paths)
      actual = P02V3Validation.contained_file_inventory(@data_root)
      required = (expected_paths + ["specification.json"]).sort
      raise Failure, "tracked corpus path set differs" unless actual == required
    end

    def validate_manifest(manifest)
      P02V3Corpus.exact_keys!(
        manifest,
        %w[
          schema_version
          corpus
          contract
          semantic_contract
          freeze
          access_policy
          loader_confinement
          split_policy
          deterministic_generation_sha256
          generalization_contract_sha256
          quotas
          taxonomies
          partition_separation
          prior_lineage_aggregate_exclusions
          artifacts
        ],
        "manifest"
      )
      raise Failure, "manifest schema differs" unless
        manifest.fetch("schema_version") == 3

      corpus = manifest.fetch("corpus")
      P02V3Corpus.exact_keys!(
        corpus,
        %w[
          id
          version
          status
          authorization
          authorization_parent_commit
          locale
          license
          claim_scope
          generator_id
          generator_version
          oracle_origin
          specification_sha256
          specification_id
          generator_sha256
          generator_artifact_id
        ],
        "manifest corpus"
      )
      expected_corpus = P02V3Corpus::EXPECTED_CORPUS.reject do |key, _value|
        key == "self_oracle_allowed"
      end
      expected_corpus.each do |field, value|
        raise Failure, "manifest corpus #{field} differs" unless
          corpus.fetch(field) == value
      end
      spec_sha = Digest::SHA256.hexdigest(
        P02V3Validation.read_regular(
          P02V3Corpus::SPEC_PATH,
          P02V3Corpus::MAX_SPEC_BYTES,
          "specification",
          root: P02V3Corpus::DATA_ROOT
        )
      )
      generator_sha = Digest::SHA256.hexdigest(
        P02V3Validation.read_regular(
          P02V3Corpus::GENERATOR_PATH,
          P02V3Corpus::MAX_GENERATOR_BYTES,
          "generator",
          root: P02V3Corpus::ROOT
        )
      )
      raise Failure, "manifest specification hash differs" unless
        corpus.fetch("specification_sha256") == spec_sha &&
        corpus.fetch("specification_id") == "p02v3qf-spec-#{spec_sha}"
      raise Failure, "manifest generator hash differs" unless
        corpus.fetch("generator_sha256") == generator_sha &&
        corpus.fetch("generator_artifact_id") ==
          "p02v3qf-generator-#{generator_sha}"

      {
        "contract" => "home_assistant_contract",
        "semantic_contract" => "semantic_contract",
        "freeze" => "freeze",
        "access_policy" => "access_policy",
        "loader_confinement" => "loader_confinement",
        "split_policy" => "split_policy",
        "quotas" => "quotas",
        "prior_lineage_aggregate_exclusions" =>
          "prior_lineage_aggregate_exclusions"
      }.each do |manifest_field, spec_field|
        raise Failure, "manifest #{manifest_field} differs" unless
          manifest.fetch(manifest_field) == @spec.fetch(spec_field)
      end
      raise Failure, "manifest deterministic identity differs" unless
        manifest.fetch("deterministic_generation_sha256") ==
          P02V3Corpus.canonical_sha(
            @spec.fetch("deterministic_generation")
          )
      raise Failure, "manifest generalization identity differs" unless
        manifest.fetch("generalization_contract_sha256") ==
          P02V3Corpus.canonical_sha(
            @spec.fetch("generalization_contract")
          )

      separation = manifest.fetch("partition_separation")
      P02V3Corpus.exact_keys!(
        separation,
        %w[status partition_count fields],
        "partition separation"
      )
      raise Failure, "manifest partition separation differs" unless
        separation.fetch("status") == "VERIFIED" &&
        separation.fetch("partition_count") == P02V3Corpus::PARTITIONS.length &&
        separation.fetch("fields") == %w[
          utterance
          case_id
          generator_record_id
          canonical_semantic_id
          family_id
          semantic_payload_sha256
        ]

      taxonomies = manifest.fetch("taxonomies")
      P02V3Corpus.exact_keys!(
        taxonomies,
        %w[
          dimensions
          intents
          partition_record_counts
          heldout_counts
          performance_counts
          suite_classes
          suite_families
        ],
        "manifest taxonomies"
      )
      raise Failure, "manifest dimensions differ" unless
        taxonomies.fetch("dimensions") == P02V3Corpus::DIMENSIONS
      raise Failure, "manifest intents differ" unless
        taxonomies.fetch("intents") == P02V3Corpus::OFFICIAL_INTENTS
    end

    def validate_semantic_splits(manifest)
      result = {}
      P02V3Corpus::SPLITS.each do |split|
        expected = P02V3Corpus.build_semantic_records(@spec, split)
        bytes = P02V3Validation.read_regular(
          File.join(@data_root, "#{split}.jsonl"),
          MAX_ARTIFACT_BYTES,
          "#{split} corpus",
          root: @data_root
        )
        rows = P02V3Validation.parse_jsonl(
          bytes,
          P02V3Corpus.case_count(@spec, split) *
            P02V3Corpus::OFFICIAL_INTENTS.length,
          MAX_SEMANTIC_RECORDS,
          "#{split} corpus"
        )
        raise Failure, "#{split} corpus differs from specification" unless
          rows == expected
        validate_semantic_inventory(rows, split)
        result[split] = rows
      end

      taxonomies = manifest.fetch("taxonomies")
      expected_partition_counts =
        P02V3Corpus::PARTITIONS.each_with_object({}) do |partition, counts|
          if P02V3Corpus::SPLITS.include?(partition)
            counts[partition] = result.fetch(partition).length
          else
            suite_id = partition.sub(/\Asuite:/, "")
            counts[partition] =
              @spec.fetch("quotas").fetch("suite_counts").fetch(suite_id)
          end
        end
      raise Failure, "manifest partition counts differ" unless
        taxonomies.fetch("partition_record_counts") ==
          expected_partition_counts
      raise Failure, "heldout dimension counts differ" unless
        taxonomies.fetch("heldout_counts") ==
          P02V3Corpus.dimension_counts(result.fetch("heldout"))
      raise Failure, "performance dimension counts differ" unless
        taxonomies.fetch("performance_counts") ==
          P02V3Corpus.dimension_counts(result.fetch("performance"))

      minimum = @spec.fetch("quotas").fetch("minimum_scored_cases")
      minimum_stratum =
        @spec.fetch("quotas").fetch("minimum_per_supported_stratum")
      %w[heldout performance].each do |split|
        raise Failure, "#{split} corpus is below the scored minimum" unless
          result.fetch(split).length >= minimum
        intent_counts = Hash.new(0)
        result.fetch(split).each do |row|
          intent_counts[row.fetch("dimensions").fetch("intent")] += 1
        end
        raise Failure, "#{split} intent stratum is below the minimum" unless
          P02V3Corpus::OFFICIAL_INTENTS.all? do |intent|
            intent_counts.fetch(intent, 0) >= minimum_stratum
          end
      end

      coverage_dimensions = P02V3Corpus::DIMENSIONS - ["family"]
      heldout_counts =
        P02V3Corpus.dimension_counts(result.fetch("heldout"))
      performance_counts =
        P02V3Corpus.dimension_counts(result.fetch("performance"))
      raise Failure, "performance coverage differs from heldout coverage" unless
        coverage_dimensions.all? do |dimension|
          heldout_counts.fetch(dimension) ==
            performance_counts.fetch(dimension)
        end
      result
    end

    def validate_semantic_inventory(rows, split)
      expected_keys = %w[
        schema_version
        case_id
        generator_record_id
        canonical_semantic_id
        semantic_payload_sha256
        family_id
        source_id
        corpus_version
        generator_id
        generator_version
        oracle_origin
        license
        locale
        split
        generator_parameters
        utterance
        utterance_sha256
        context
        dimensions
        expected
      ]
      case_ids = Set.new
      generator_ids = Set.new
      semantic_ids = Set.new
      payload_ids = Set.new
      utterances = Set.new
      families = Set.new

      rows.each do |row|
        P02V3Corpus.exact_keys!(row, expected_keys, "semantic row")
        raise Failure, "semantic row schema differs" unless
          row.fetch("schema_version") == 2
        raise Failure, "semantic source identity differs" unless
          row.fetch("source_id") ==
            P02V3Corpus::EXPECTED_CORPUS.fetch("id") &&
          row.fetch("corpus_version") ==
            P02V3Corpus::EXPECTED_CORPUS.fetch("version") &&
          row.fetch("generator_id") ==
            P02V3Corpus::EXPECTED_CORPUS.fetch("generator_id") &&
          row.fetch("generator_version") ==
            P02V3Corpus::EXPECTED_CORPUS.fetch("generator_version") &&
          row.fetch("oracle_origin") ==
            P02V3Corpus::EXPECTED_CORPUS.fetch("oracle_origin") &&
          row.fetch("license") == "Apache-2.0" &&
          row.fetch("locale") == "pt-BR" &&
          row.fetch("split") == split
        prefix = P02V3Corpus.partition_code(split)
        raise Failure, "semantic case namespace differs" unless
          row.fetch("case_id").start_with?("p02v3qf-case-#{prefix}-")
        raise Failure, "semantic generator namespace differs" unless
          row.fetch("generator_record_id")
            .start_with?("p02v3qf-genrec-#{prefix}-")
        raise Failure, "semantic utterance hash differs" unless
          row.fetch("utterance_sha256") ==
            Digest::SHA256.hexdigest(row.fetch("utterance"))

        family_id = row.fetch("family_id")
        dimensions = row.fetch("dimensions")
        P02V3Corpus.exact_keys!(
          dimensions,
          P02V3Corpus::DIMENSIONS,
          "semantic dimensions"
        )
        raise Failure, "semantic family projection differs" unless
          dimensions.fetch("family") == family_id
        payload = {
          "partition" => split,
          "family_id" => family_id,
          "context" => row.fetch("context"),
          "expected" => row.fetch("expected")
        }
        payload_sha = P02V3Corpus.canonical_sha(payload)
        raise Failure, "semantic payload identity differs" unless
          row.fetch("semantic_payload_sha256") == payload_sha &&
          row.fetch("canonical_semantic_id") ==
            "p02v3qf-sem-#{payload_sha}"

        parameters = row.fetch("generator_parameters")
        P02V3Corpus.exact_keys!(
          parameters,
          %w[
            algorithm
            partition_seed
            intent_ordinal
            record_ordinal
            template_ordinal
            target_ordinal
            secondary_target_ordinal
          ],
          "semantic generator parameters"
        )
        raise Failure, "semantic generator seed differs" unless
          parameters.fetch("partition_seed") ==
            @spec.fetch("deterministic_generation")
              .fetch("partition_seeds").fetch(split)

        raise Failure, "semantic case identity is duplicated" unless
          case_ids.add?(row.fetch("case_id"))
        raise Failure, "generator record identity is duplicated" unless
          generator_ids.add?(row.fetch("generator_record_id"))
        raise Failure, "canonical semantic identity is duplicated" unless
          semantic_ids.add?(row.fetch("canonical_semantic_id"))
        raise Failure, "semantic payload identity is duplicated" unless
          payload_ids.add?(row.fetch("semantic_payload_sha256"))
        raise Failure, "semantic utterance is duplicated" unless
          utterances.add?(row.fetch("utterance"))
        families.add(family_id)
        raise Failure, "semantic expected outcome differs" unless
          row.fetch("expected").fetch("outcome") == "plan" &&
          dimensions.fetch("outcome") == "plan"
      end
      raise Failure, "semantic family count differs" unless
        families.length == P02V3Corpus::OFFICIAL_INTENTS.length
    end

    def validate_suites(manifest, records_by_partition)
      taxonomy = manifest.fetch("taxonomies")
      P02V3Corpus::SUITE_IDS.each_with_index do |suite_id, index|
        partition = "suite:#{suite_id}"
        expected = P02V3Corpus.build_suite_records(@spec, suite_id, index + 1)
        path = P02V3Corpus::SUITE_PATHS.fetch(suite_id)
        bytes = P02V3Validation.read_regular(
          File.join(@data_root, path),
          MAX_ARTIFACT_BYTES,
          path,
          root: @data_root
        )
        rows = P02V3Validation.parse_jsonl(
          bytes,
          @spec.fetch("quotas").fetch("suite_counts").fetch(suite_id),
          MAX_SUITE_RECORDS,
          path
        )
        raise Failure, "suite differs from specification" unless
          rows == expected
        validate_suite_inventory(rows, suite_id, partition)
        records_by_partition[partition] = rows

        definitions =
          @spec.fetch("fail_closed_suites").fetch(suite_id)
        raise Failure, "suite class taxonomy differs" unless
          taxonomy.fetch("suite_classes").fetch(suite_id) ==
            definitions.map do |definition|
              definition.fetch("coverage_class")
            end
        raise Failure, "suite family taxonomy differs" unless
          taxonomy.fetch("suite_families").fetch(suite_id) ==
            definitions.map { |definition| definition.fetch("family") }
      end
    end

    def validate_suite_inventory(rows, suite_id, partition)
      expected_keys = %w[
        schema_version
        suite_id
        partition
        case_id
        generator_record_id
        canonical_semantic_id
        semantic_payload_sha256
        family_id
        coverage_class
        source_id
        corpus_version
        generator_id
        generator_version
        oracle_origin
        license
        locale
        generator_parameters
        utterance
        utterance_sha256
        context
        expected
      ]
      case_ids = Set.new
      generator_ids = Set.new
      semantic_ids = Set.new
      payload_ids = Set.new
      family_ids = Set.new
      utterances = Set.new

      rows.each do |row|
        P02V3Corpus.exact_keys!(row, expected_keys, "suite row")
        raise Failure, "suite identity differs" unless
          row.fetch("schema_version") == 2 &&
          row.fetch("suite_id") == suite_id &&
          row.fetch("partition") == partition &&
          row.fetch("source_id") ==
            P02V3Corpus::EXPECTED_CORPUS.fetch("id") &&
          row.fetch("corpus_version") == "3.0.0" &&
          row.fetch("generator_id") ==
            P02V3Corpus::EXPECTED_CORPUS.fetch("generator_id") &&
          row.fetch("generator_version") == "3.0.0" &&
          row.fetch("oracle_origin") ==
            P02V3Corpus::EXPECTED_CORPUS.fetch("oracle_origin") &&
          row.fetch("license") == "Apache-2.0" &&
          row.fetch("locale") == "pt-BR"
        prefix = P02V3Corpus.partition_code(partition)
        raise Failure, "suite case namespace differs" unless
          row.fetch("case_id").start_with?("p02v3qf-case-#{prefix}-")
        raise Failure, "suite generator namespace differs" unless
          row.fetch("generator_record_id")
            .start_with?("p02v3qf-genrec-#{prefix}-")
        raise Failure, "suite utterance hash differs" unless
          row.fetch("utterance_sha256") ==
            Digest::SHA256.hexdigest(row.fetch("utterance"))

        payload = {
          "partition" => partition,
          "family_id" => row.fetch("family_id"),
          "coverage_class" => row.fetch("coverage_class"),
          "context" => row.fetch("context"),
          "expected" => row.fetch("expected")
        }
        payload_sha = P02V3Corpus.canonical_sha(payload)
        raise Failure, "suite semantic payload identity differs" unless
          row.fetch("semantic_payload_sha256") == payload_sha &&
          row.fetch("canonical_semantic_id") ==
            "p02v3qf-sem-#{payload_sha}"

        parameters = row.fetch("generator_parameters")
        P02V3Corpus.exact_keys!(
          parameters,
          %w[
            algorithm
            partition_seed
            suite_ordinal
            record_ordinal
            definition_selector
          ],
          "suite generator parameters"
        )
        raise Failure, "suite generator seed differs" unless
          parameters.fetch("partition_seed") ==
            @spec.fetch("deterministic_generation")
              .fetch("partition_seeds").fetch(partition)

        raise Failure, "suite case identity is duplicated" unless
          case_ids.add?(row.fetch("case_id"))
        raise Failure, "suite generator identity is duplicated" unless
          generator_ids.add?(row.fetch("generator_record_id"))
        raise Failure, "suite semantic identity is duplicated" unless
          semantic_ids.add?(row.fetch("canonical_semantic_id"))
        raise Failure, "suite payload identity is duplicated" unless
          payload_ids.add?(row.fetch("semantic_payload_sha256"))
        raise Failure, "suite family identity is duplicated" unless
          family_ids.add?(row.fetch("family_id"))
        raise Failure, "suite utterance is duplicated" unless
          utterances.add?(row.fetch("utterance"))
        raise Failure, "suite produced a plan oracle" if
          row.fetch("expected").fetch("outcome") == "plan"
      end
    end
  end

  def aggregate_rows(data_root, manifest)
    rows = manifest.fetch("artifacts").map do |entry|
      {
        "path" => entry.fetch("path"),
        "records" => entry.fetch("records"),
        "bytes" => entry.fetch("bytes"),
        "sha256" => entry.fetch("sha256"),
        "artifact_id" => entry.fetch("artifact_id")
      }
    end

    manifest_bytes = read_regular(
      File.join(data_root, P02V3Corpus::MANIFEST_PATH),
      MAX_MANIFEST_BYTES,
      "manifest",
      root: data_root
    )
    manifest_sha = Digest::SHA256.hexdigest(manifest_bytes)
    rows << {
      "path" => P02V3Corpus::MANIFEST_PATH,
      "records" => 1,
      "bytes" => manifest_bytes.bytesize,
      "sha256" => manifest_sha,
      "artifact_id" => "p02v3qf-manifest-#{manifest_sha}"
    }

    spec_bytes = read_regular(
      P02V3Corpus::SPEC_PATH,
      P02V3Corpus::MAX_SPEC_BYTES,
      "specification",
      root: P02V3Corpus::DATA_ROOT
    )
    spec_sha = Digest::SHA256.hexdigest(spec_bytes)
    rows << {
      "path" => "specification.json",
      "records" => 1,
      "bytes" => spec_bytes.bytesize,
      "sha256" => spec_sha,
      "artifact_id" => "p02v3qf-spec-#{spec_sha}"
    }
    rows
  end

  def print_aggregate_report(data_root, manifest)
    aggregate_rows(data_root, manifest).each do |row|
      puts "P02_V3_ARTIFACT #{JSON.generate(row)}"
    end
    corpus = manifest.fetch("corpus")
    puts "P02_V3_IDENTITY #{JSON.generate({
      "source_id" => corpus.fetch("id"),
      "corpus_version" => corpus.fetch("version"),
      "generator_id" => corpus.fetch("generator_id"),
      "generator_version" => corpus.fetch("generator_version"),
      "specification_sha256" => corpus.fetch("specification_sha256"),
      "specification_id" => corpus.fetch("specification_id"),
      "generator_sha256" => corpus.fetch("generator_sha256"),
      "generator_artifact_id" => corpus.fetch("generator_artifact_id")
    })}"
  end

  module CLI
    module_function

    def run(arguments)
      options = {
        data_root: P02V3Corpus::DATA_ROOT,
        aggregate_report: false
      }
      parser = OptionParser.new do |opts|
        opts.on("--data-root PATH") do |path|
          options[:data_root] = File.expand_path(path)
        end
        opts.on("--aggregate-report") { options[:aggregate_report] = true }
      end
      parser.parse!(arguments)
      raise Failure, "unexpected arguments" unless arguments.empty?

      manifest = Validator.new(options.fetch(:data_root)).validate
      P02V3Validation.print_aggregate_report(
        options.fetch(:data_root),
        manifest
      ) if options[:aggregate_report]
      puts "P02_V3_VALIDATION_PASS"
    rescue Failure, P02V3Corpus::Failure, OptionParser::ParseError,
           KeyError, TypeError => error
      warn "P02_V3_VALIDATION_FAIL: #{error.message}"
      exit 1
    end
  end
end

P02V3Validation::CLI.run(ARGV) if __FILE__ == $PROGRAM_NAME
