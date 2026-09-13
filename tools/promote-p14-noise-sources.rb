# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "tmpdir"
require_relative "p13-noise-evidence"

module P14NoiseSourcePromotion
  class Failure < StandardError; end

  ROOT = File.expand_path("..", __dir__)
  EVIDENCE_PATH = File.join(ROOT, "docs/evidence/P13-NOISE-SOURCES.yaml")
  DESTINATION = File.join(ROOT, "vendor")
  MANIFEST = File.join(DESTINATION, "p14-noise-source-manifest.json")
  PATH_PACKAGES = %w[chacha20 poly1305 snow].freeze
  EXPECTED_PACKAGE_COUNT = 23
  MANIFEST_SCHEMA_VERSION = 3
  GIT_REGULAR_MODE = "100644"
  GIT_EXECUTABLE_MODE = "100755"

  module_function

  def run(arguments)
    mode = arguments.shift
    raise Failure, usage unless %w[--check --write].include?(mode) && arguments.empty?

    evidence = P13NoiseEvidence.read_yaml(EVIDENCE_PATH)
    P13NoiseEvidence.validate_evidence(evidence)
    materials = P13NoiseEvidence.read_yaml(
      File.join(ROOT, "docs/clean-room/MATERIALS.yaml")
    )
    P13NoiseEvidence.validate_materials(materials)
    P13NoiseEvidence.validate_material_closure_binding(materials, evidence)
    packages = evidence.fetch("closure").fetch("packages")
    projection_records = evidence.fetch("compile_projection")
      .fetch("packages")
      .to_h { |record| [record.fetch("name"), record] }
    validate_package_selection(packages, projection_records.keys)

    if mode == "--write"
      paths = P13NoiseEvidence.source_paths(evidence)
      P13NoiseEvidence.validate_noise_specification(evidence, paths)
      validated = P13NoiseEvidence.validate_source_closure(evidence, paths)
      P13NoiseEvidence.validate_cacophony_origin(
        evidence,
        materials,
        validated,
        paths
      )
      P13NoiseEvidence.validate_source_origin_review(evidence, validated)
      P13NoiseEvidence.validate_advisories(evidence, paths)
      source_entries = validated.fetch("origin_sources")
      validate_package_selection(packages, source_entries.keys)
      with_staging_directory do |temporary|
        staged_vendor = File.join(temporary, "vendor")
        FileUtils.mkdir_p(staged_vendor)
        package_rows = sorted_packages(packages).map do |package|
          stage_package(
            staged_vendor,
            package,
            source_entries.fetch(package.fetch("name"))
          )
        end
        staged_manifest = stage_manifest(staged_vendor, package_rows)
        promote_packages(staged_vendor, package_rows)
        promote_file(staged_manifest, MANIFEST)
      end
    else
      package_rows = sorted_packages(packages).map do |package|
        promoted_package_row(
          package,
          projection_records.fetch(package.fetch("name"))
        )
      end
      with_staging_directory do |temporary|
        staged_vendor = File.join(temporary, "vendor")
        FileUtils.mkdir_p(staged_vendor)
        staged_manifest = stage_manifest(staged_vendor, package_rows)
        check_file(staged_manifest, MANIFEST)
      end
    end

    puts "P14_NOISE_SOURCE_PROMOTION_PASS"
    puts "P14_NOISE_SOURCE_PACKAGE_COUNT=#{EXPECTED_PACKAGE_COUNT}"
    true
  rescue P13NoiseEvidence::Failure, KeyError, Errno::ENOENT, Failure => error
    warn "P14_NOISE_SOURCE_PROMOTION_FAIL: #{error.message}"
    exit 1
  end

  def usage
    "usage: tools/promote-p14-noise-sources (--check|--write)"
  end

  def with_staging_directory
    Dir.mktmpdir("p14-noise-promotion-", "/private/tmp") do |temporary|
      yield temporary
    end
  end

  def sorted_packages(packages)
    packages.sort_by do |package|
      [package.fetch("name").b, package.fetch("version").b]
    end
  end

  def validate_package_selection(packages, source_names = nil)
    names = packages.map { |package| package.fetch("name") }
    raise Failure, "selected package count differs" unless
      packages.length == EXPECTED_PACKAGE_COUNT &&
      names.uniq.length == names.length
    if source_names && names.sort != source_names.sort
      raise Failure, "selected package sources differ"
    end
    packages.each do |package|
      name = package.fetch("name")
      path_package = PATH_PACKAGES.include?(name)
      source_mode = package.fetch("source_mode")
      raise Failure, "path-package disposition differs: #{name}" unless
        path_package == (source_mode == "exact_projected_path_dependency")
    end
    true
  end

  def stage_package(staged_vendor, package, original_entries)
    name = package.fetch("name")
    version = package.fetch("version")
    source_mode = package.fetch("source_mode")
    path_package = PATH_PACKAGES.include?(name)
    raise Failure, "path-package disposition differs: #{name}" unless
      path_package == (source_mode == "exact_projected_path_dependency")

    entries = original_entries.transform_values(&:dup)
    checksum = path_package ? nil : package.fetch("archive_sha256")
    entries[".cargo-checksum.json"] = {
      "mode" => "644",
      "contents" => P13NoiseEvidence.cargo_checksum_manifest(entries, checksum)
    }
    identity = "#{name}-#{version}"
    destination = File.join(staged_vendor, identity)
    P13NoiseEvidence.materialize_entry_map(entries, destination)
    package_row(package, destination)
  end

  def promoted_package_row(package, projection_record)
    identity = "#{package.fetch("name")}-#{package.fetch("version")}"
    destination = File.join(DESTINATION, identity)
    validate_cargo_checksum(destination, package)
    validate_promoted_projection(destination, projection_record)
    package_row(package, destination)
  end

  def validate_promoted_projection(root, projection_record)
    files = tree_entries(root)
      .select { |entry| entry.fetch(:type) == "file" }
      .reject { |entry| entry.fetch(:path) == ".cargo-checksum.json" }
    entries = files.to_h do |entry|
      mode = entry.fetch(:mode) == GIT_EXECUTABLE_MODE ? "755" : "644"
      [
        entry.fetch(:path),
        {
          "mode" => mode,
          "contents" => entry.fetch(:bytes)
        }
      ]
    end
    unless projection_record.fetch("projected_tree_sha256") ==
           P13NoiseEvidence.entry_tree_digest(entries)
      raise Failure, "P13 projected tree differs: #{root}"
    end
    true
  end

  def package_row(package, destination)
    name = package.fetch("name")
    version = package.fetch("version")
    source_mode = package.fetch("source_mode")
    path_package = PATH_PACKAGES.include?(name)
    {
      "archive_sha256" => package.fetch("archive_sha256"),
      "identity" => "#{name}-#{version}",
      "license" => package.fetch("declared_license"),
      "name" => name,
      "path_dependency" => path_package,
      "projected_tree_sha256" => tree_sha256(destination),
      "source_mode" => source_mode,
      "version" => version
    }
  end

  def validate_cargo_checksum(root, package)
    entries = tree_entries(root)
    checksum = entries.find do |entry|
      entry.fetch(:path) == ".cargo-checksum.json"
    end
    unless checksum && checksum.fetch(:type) == "file" &&
           checksum.fetch(:mode) == GIT_REGULAR_MODE
      raise Failure, "Cargo checksum manifest is missing or executable: #{root}"
    end
    files = entries.select { |entry| entry.fetch(:type) == "file" }
      .reject { |entry| entry.fetch(:path) == ".cargo-checksum.json" }
      .sort_by { |entry| entry.fetch(:path).b }
      .to_h do |entry|
        [
          entry.fetch(:path),
          Digest::SHA256.hexdigest(entry.fetch(:bytes))
        ]
      end
    archive = if PATH_PACKAGES.include?(package.fetch("name"))
                nil
              else
                package.fetch("archive_sha256")
              end
    expected = JSON.generate("files" => files, "package" => archive)
    unless checksum.fetch(:bytes) == expected
      raise Failure, "Cargo checksum manifest differs: #{root}"
    end
    true
  end

  def stage_manifest(staged_vendor, package_rows)
    manifest = promotion_manifest(package_rows)
    staged_manifest = File.join(staged_vendor, File.basename(MANIFEST))
    File.binwrite(staged_manifest, JSON.pretty_generate(manifest) + "\n")
    File.chmod(0o644, staged_manifest)
    staged_manifest
  end

  def promotion_manifest(package_rows)
    aggregate = Digest::SHA256.new
    package_rows.each do |row|
      aggregate.update(row.fetch("identity"))
      aggregate.update("\0")
      aggregate.update(row.fetch("projected_tree_sha256"))
      aggregate.update("\0")
    end
    manifest = {
      "aggregate_package_tree_sha256" => aggregate.hexdigest,
      "package_count" => package_rows.length,
      "packages" => package_rows,
      "schema_version" => MANIFEST_SCHEMA_VERSION,
      "source_evidence" => "docs/evidence/P13-NOISE-SOURCES.yaml",
      "use" => "P14_PRODUCT_RUNTIME_SOURCE_CANDIDATE_PENDING_NATIVE_LINUX_GATE"
    }
    validate_promotion_manifest(manifest)
    manifest
  end

  def tree_sha256(root)
    digest = Digest::SHA256.new
    entries = tree_entries(root)
    raise Failure, "empty projected package: #{root}" unless
      entries.any? { |entry| entry.fetch(:type) == "file" }
    digest_field(digest, "P14_NOISE_TREE_V3")
    entries.each do |entry|
      digest_field(digest, entry.fetch(:path))
      digest_field(digest, entry.fetch(:type))
      digest_field(digest, entry.fetch(:mode))
      digest_field(digest, entry.fetch(:bytes) || "")
    end
    digest.hexdigest
  end

  def digest_field(digest, value)
    bytes = value.to_s.b
    digest.update(bytes.bytesize.to_s)
    digest.update(":")
    digest.update(bytes)
  end

  def tree_entries(root)
    root_stat = File.lstat(root)
    unless root_stat.directory? && !root_stat.symlink?
      raise Failure, "projected package root is not a directory: #{root}"
    end
    paths = Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH)
      .reject { |path| [".", ".."].include?(File.basename(path)) }
      .sort_by { |path| relative_path(root, path).b }
    entries = []
    paths.each do |path|
      stat = File.lstat(path)
      raise Failure, "symlink prohibited in projected package: #{path}" if
        stat.symlink?
      unless stat.file? || stat.directory?
        raise Failure, "unsupported entry in projected package: #{path}"
      end
      if stat.file? && stat.nlink != 1
        raise Failure, "hard-linked file prohibited in projected package: #{path}"
      end
      if stat.file?
        entries << {
          path: relative_path(root, path),
          stat: stat,
          source: path
        }
      end
    end
    entries.sort_by { |entry| entry.fetch(:path).b }.map do |entry|
      stat = entry.fetch(:stat)
      {
        path: entry.fetch(:path),
        type: stat.file? ? "file" : "directory",
        mode: git_mode(stat),
        bytes: stat.file? ? File.binread(entry.fetch(:source)) : nil
      }
    end
  rescue Errno::ENOENT
    raise Failure, "projected package is missing: #{root}"
  end

  def git_mode(stat)
    return GIT_EXECUTABLE_MODE if (stat.mode & 0o100).positive?

    GIT_REGULAR_MODE
  end

  def relative_path(root, path)
    prefix = "#{root}/"
    raise Failure, "path escaped package root: #{path}" unless path.start_with?(prefix)

    path.delete_prefix(prefix)
  end

  def promote_packages(staged_vendor, package_rows)
    package_rows.each do |row|
      identity = row.fetch("identity")
      promote_directory(
        File.join(staged_vendor, identity),
        File.join(DESTINATION, identity)
      )
    end
  end

  def check_packages(staged_vendor, package_rows)
    package_rows.each do |row|
      identity = row.fetch("identity")
      check_directory(
        File.join(staged_vendor, identity),
        File.join(DESTINATION, identity)
      )
    end
  end

  def promote_directory(source, destination)
    if File.exist?(destination) || File.symlink?(destination)
      check_directory(source, destination)
      return
    end
    FileUtils.cp_r(source, destination, preserve: true)
    check_directory(source, destination)
  end

  def check_directory(expected, actual)
    expected_identity = tree_entries(expected)
    actual_identity = tree_entries(actual)
    raise Failure, "promoted package identity differs: #{actual}" unless
      expected_identity == actual_identity
  end

  def promote_file(source, destination)
    FileUtils.cp(source, destination, preserve: true)
    check_file(source, destination)
  end

  def check_file(expected, actual)
    stat = File.lstat(actual)
    unless stat.file? && !stat.symlink? && stat.nlink == 1
      raise Failure, "promotion manifest is not a regular single-link file: #{actual}"
    end
    raise Failure, "promotion manifest differs: #{actual}" unless
      File.binread(expected) == File.binread(actual)
    raise Failure, "promotion manifest mode differs: #{actual}" unless
      file_mode(expected) == file_mode(actual)
    validate_promotion_manifest(JSON.parse(File.binread(actual)))
  rescue Errno::ENOENT
    raise Failure, "promotion manifest missing: #{actual}"
  rescue JSON::ParserError
    raise Failure, "promotion manifest is malformed: #{actual}"
  end

  def validate_promotion_manifest(manifest)
    required = %w[
      aggregate_package_tree_sha256 package_count packages schema_version
      source_evidence use
    ]
    raise Failure, "promotion manifest fields differ" unless
      manifest.is_a?(Hash) && manifest.keys.sort == required.sort
    unless manifest.fetch("schema_version") == MANIFEST_SCHEMA_VERSION
      raise Failure, "promotion manifest schema differs"
    end
    packages = manifest.fetch("packages")
    unless packages.is_a?(Array) &&
           manifest.fetch("package_count") == packages.length
      raise Failure, "promotion manifest package count differs"
    end
    digests = packages.map do |row|
      digest = row.fetch("projected_tree_sha256")
      raise Failure, "promotion manifest tree digest is malformed" unless
        digest.match?(/\A[0-9a-f]{64}\z/)

      [row.fetch("identity"), digest]
    end
    aggregate = Digest::SHA256.new
    digests.each do |identity, digest|
      aggregate.update(identity)
      aggregate.update("\0")
      aggregate.update(digest)
      aggregate.update("\0")
    end
    unless manifest.fetch("aggregate_package_tree_sha256") == aggregate.hexdigest
      raise Failure, "promotion manifest aggregate differs"
    end
    true
  rescue KeyError
    raise Failure, "promotion manifest field is missing"
  end

  def file_mode(path)
    git_mode(File.lstat(path))
  end
end
