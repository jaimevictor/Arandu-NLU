# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "p13-noise-evidence"

module P14ResolverFixtures
  class Failure < StandardError; end

  ROOT = File.expand_path("..", __dir__)
  EVIDENCE = File.join(ROOT, "docs/evidence/P13-NOISE-SOURCES.yaml")
  DESTINATION = File.join(ROOT, "tools/p14-resolver-fixtures")

  module_function

  def run(arguments)
    mode = arguments.shift
    raise Failure, usage unless %w[--check --write].include?(mode) && arguments.empty?

    evidence = P13NoiseEvidence.read_yaml(EVIDENCE)
    records = evidence.fetch("runtime_isolation")
      .fetch("resolver_only_technical_fixtures")
    expected = records.map { |record| [record.fetch("name"), record.fetch("version")] }
    raise Failure, "fixture identities are not unique and sorted" unless
      expected == expected.sort && expected.uniq == expected

    Dir.mktmpdir("p14-resolver-fixtures-", File.join(ROOT, "target")) do |temporary|
      staged = File.join(temporary, "fixtures")
      FileUtils.mkdir_p(staged)
      records.each do |record|
        identity = "#{record.fetch('name')}-#{record.fetch('version')}"
        entries = P13NoiseEvidence.resolver_fixture_entries(record)
        bind_fixture_dependencies(entries, record)
        write_entries(
          File.join(staged, identity),
          entries
        )
      end
      mode == "--write" ? publish(staged) : compare(staged, DESTINATION)
    end

    puts "P14_RESOLVER_FIXTURES_PASS"
    puts "P14_RESOLVER_FIXTURE_COUNT=#{expected.length}"
    true
  rescue KeyError, Errno::ENOENT, P13NoiseEvidence::Failure, Failure => error
    warn "P14_RESOLVER_FIXTURES_FAIL: #{error.message}"
    exit 1
  end

  def usage
    "usage: tools/materialize-p14-resolver-fixtures (--check|--write)"
  end

  def write_entries(root, entries)
    entries.each do |relative, record|
      path = File.join(root, relative)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, record.fetch("contents"))
      File.chmod(Integer(record.fetch("mode"), 8), path)
    end
  end

  def bind_fixture_dependencies(entries, record)
    manifest = entries.fetch("Cargo.toml").fetch("contents")
    record.fetch("required_dependencies", []).each do |dependency|
      name = dependency.fetch("name")
      version = dependency.fetch("version")
      registry = "#{name} = \"=#{version}\""
      relative = "#{name} = { version = \"=#{version}\", path = \"../#{name}-#{version}\" }"
      raise Failure, "fixture dependency line missing: #{name}" unless
        manifest.sub!(registry, relative)
    end
    manifest.sub!(/\n+\z/, "\n")
  end

  def publish(staged)
    if File.exist?(DESTINATION)
      compare(staged, DESTINATION)
    else
      FileUtils.cp_r(staged, DESTINATION, preserve: true)
      compare(staged, DESTINATION)
    end
  end

  def compare(expected, actual)
    raise Failure, "fixture directory missing" unless File.directory?(actual)

    expected_files = files(expected)
    actual_files = files(actual)
    raise Failure, "fixture path set differs" unless expected_files == actual_files

    expected_files.each do |relative|
      expected_path = File.join(expected, relative)
      actual_path = File.join(actual, relative)
      raise Failure, "fixture symlink prohibited: #{relative}" if File.symlink?(actual_path)
      raise Failure, "fixture bytes differ: #{relative}" unless
        File.binread(expected_path) == File.binread(actual_path)
      raise Failure, "fixture mode differs: #{relative}" unless
        File.stat(expected_path).mode & 0o777 == File.stat(actual_path).mode & 0o777
    end
  end

  def files(root)
    Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH)
      .select { |path| File.file?(path) }
      .map { |path| path.delete_prefix("#{root}/") }
      .sort_by(&:b)
  end
end
