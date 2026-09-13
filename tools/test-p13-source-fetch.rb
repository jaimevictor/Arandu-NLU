# frozen_string_literal: true

require "digest"
require "fileutils"
require "open3"
require "stringio"
require "tmpdir"
require "zlib"
require_relative "p13-source-fetch"
require_relative "p13-noise-evidence"

module P13SourceFetchTest
  PREFIX = "FIXTURE_TECNICA-1.0.0"
  URL = "https://static.crates.io/crates/FIXTURE_TECNICA/source.crate"
  TMP_ROOT = File.realpath(Dir.tmpdir)
  TOOL = File.expand_path("p13-source-fetch", __dir__)

  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_equal(expected, actual, message)
    raise(
      "assertion failed: #{message}: " \
      "expected #{expected.inspect}, got #{actual.inspect}"
    ) unless expected == actual
  end

  def assert_failure(message = nil)
    yield
    raise "expected P13SourceFetch::Failure"
  rescue P13SourceFetch::Failure => error
    if message
      assert(
        error.message.include?(message),
        "failure message includes #{message.inspect}: #{error.message.inspect}"
      )
    end
    error
  end

  def with_tmpdir
    Dir.mktmpdir("FIXTURE_TECNICA_p13_source_fetch_", TMP_ROOT) do |directory|
      File.chmod(0o700, directory)
      yield directory
    end
  end

  def cleanup_quarantines(directory)
    Dir.children(directory).select do |name|
      name.start_with?(".p13-cleanup-") && name.end_with?(".quarantine")
    end.sort.map { |name| File.join(directory, name) }
  end

  def sole_cleanup_quarantine(directory)
    quarantines = cleanup_quarantines(directory)
    assert_equal(
      1,
      quarantines.length,
      "one retained cleanup quarantine"
    )
    quarantines.fetch(0)
  end

  def fetch_arguments(bytes, destination)
    [
      URL,
      bytes.bytesize.to_s,
      Digest::SHA256.hexdigest(bytes),
      destination
    ]
  end

  def extraction_arguments(archive, bytes, destination, prefix = PREFIX)
    [
      "extract-crate",
      archive,
      bytes.bytesize.to_s,
      Digest::SHA256.hexdigest(bytes),
      prefix,
      destination
    ]
  end

  def injected_fetch(chunks)
    lambda do |uri, &receiver|
      assert_equal("static.crates.io", uri.host, "injected fetch host")
      chunks.each { |chunk| receiver.call(chunk) }
      true
    end
  end

  def tar_octal(value, length)
    format("%0#{length - 1}o", value) + "\0"
  end

  def tar_header(path, contents, mode: 0o644, type: "0", linkname: "")
    prefix, name = ustar_path_fields(path)
    header = ("\0" * 512).b
    set_tar_field(header, 0, 100, name)
    set_tar_field(header, 100, 8, tar_octal(mode, 8))
    set_tar_field(header, 108, 8, tar_octal(0, 8))
    set_tar_field(header, 116, 8, tar_octal(0, 8))
    set_tar_field(header, 124, 12, tar_octal(contents.bytesize, 12))
    set_tar_field(header, 136, 12, tar_octal(0, 12))
    set_tar_field(header, 148, 8, " " * 8)
    set_tar_field(header, 156, 1, type)
    set_tar_field(header, 157, 100, linkname)
    set_tar_field(header, 257, 6, "ustar\0")
    set_tar_field(header, 263, 2, "00")
    set_tar_field(header, 345, 155, prefix)
    checksum = header.bytes.sum
    set_tar_field(header, 148, 8, format("%06o\0 ", checksum))
    header
  end

  def ustar_path_fields(path)
    return ["", path] if path.bytesize <= 100

    split = path.enum_for(:scan, "/").map { Regexp.last_match.begin(0) }
      .reverse
      .find do |index|
        index <= 155 && path.bytesize - index - 1 <= 100
      end
    raise "FIXTURE_TECNICA tar path overflow" unless split

    [
      path.byteslice(0, split),
      path.byteslice(split + 1, path.bytesize - split - 1)
    ]
  end

  def set_tar_field(header, offset, length, value)
    raise "FIXTURE_TECNICA tar field overflow" if value.bytesize > length

    header[offset, length] = value.b.ljust(length, "\0")
  end

  def tar_entry(path, contents = "", mode: 0o644, type: "0", linkname: "")
    bytes = contents.b
    padding = (512 - (bytes.bytesize % 512)) % 512
    tar_header(
      path,
      bytes,
      mode: mode,
      type: type,
      linkname: linkname
    ) + bytes + ("\0" * padding)
  end

  def with_zero_tar_owner_fields(entry)
    changed = entry.dup
    set_tar_field(changed, 108, 8, "\0" * 8)
    set_tar_field(changed, 116, 8, "\0" * 8)
    set_tar_field(changed, 148, 8, " " * 8)
    checksum = changed.byteslice(0, 512).bytes.sum
    set_tar_field(changed, 148, 8, format("%06o\0 ", checksum))
    changed
  end

  def tar_bytes(entries, end_blocks: 2)
    entries.join + (P13SourceFetch::ZERO_TAR_BLOCK * end_blocks)
  end

  def gzip_bytes(tar)
    output = StringIO.new(String.new(encoding: Encoding::BINARY))
    writer = Zlib::GzipWriter.new(output)
    writer.mtime = 0
    writer.write(tar)
    writer.finish
    output.string
  end

  def valid_entries
    [
      tar_entry(
        "#{PREFIX}/FIXTURE_TECNICA.txt",
        "FIXTURE_TECNICA_SOURCE\n",
        mode: 0o644
      ),
      tar_entry(
        "#{PREFIX}/nested/FIXTURE_TECNICA.sh",
        "# FIXTURE_TECNICA\n",
        mode: 0o755
      ),
      tar_entry(
        "#{PREFIX}/nested/FIXTURE_TECNICA_UTF8.bin",
        "FIXTURE_TECNICA_UTF8_".b + [0xc3, 0xa7].pack("C*"),
        mode: 0o644
      )
    ]
  end

  def valid_crate
    gzip_bytes(tar_bytes(valid_entries))
  end

  def write_archive(directory, bytes, name = "FIXTURE_TECNICA.crate")
    path = File.join(directory, name)
    File.binwrite(path, bytes)
    File.chmod(0o444, path)
    path
  end

  def run_extract(directory, bytes, destination_name = "extracted")
    archive = write_archive(directory, bytes)
    destination = File.join(directory, destination_name)
    output = StringIO.new
    P13SourceFetch.run(
      extraction_arguments(archive, bytes, destination),
      output: output
    )
    [destination, output.string]
  end

  def verify_existing_tree(path, manifest)
    flags = File::RDONLY | File::NOFOLLOW |
      P13SourceFetch::DIRECTORY_OPEN_FLAG
    File.open(path, flags) do |root|
      P13SourceFetch.verify_tree(root, manifest)
    end
  end

  def test_valid_fetch_flow_uses_injected_chunks
    with_tmpdir do |directory|
      bytes = "FIXTURE_TECNICA_FETCH_BYTES"
      destination = File.join(directory, "nested", "source.bin")
      output = StringIO.new
      result = P13SourceFetch.run(
        fetch_arguments(bytes, destination),
        fetcher: injected_fetch(
          [
            "FIXTURE_TECNICA_",
            "FETCH_",
            "BYTES"
          ]
        ),
        output: output
      )
      assert(result, "fetch result")
      assert_equal(bytes, File.binread(destination), "fetched bytes")
      assert_equal(0o444, File.stat(destination).mode & 0o777, "fetched mode")
      assert_equal("P13_SOURCE_FETCH_PASS\n", output.string, "fetch marker")
    end
  end

  def test_existing_exact_and_mismatch
    with_tmpdir do |directory|
      bytes = "FIXTURE_TECNICA_EXISTING"
      destination = File.join(directory, "source.bin")
      File.binwrite(destination, bytes)
      output = StringIO.new
      result = P13SourceFetch.run(
        fetch_arguments(bytes, destination),
        fetcher: lambda { |_uri| raise "network must not run" },
        output: output
      )
      assert(result, "existing exact result")
      assert_equal(
        "P13_SOURCE_ALREADY_EXACT\n",
        output.string,
        "existing exact marker"
      )

      arguments = fetch_arguments(bytes, destination)
      arguments[2] = Digest::SHA256.hexdigest("FIXTURE_TECNICA_OTHER")
      assert_failure("SHA-256 differs") do
        P13SourceFetch.run(
          arguments,
          fetcher: lambda { |_uri| raise "network must not run" }
        )
      end
      assert_equal(bytes, File.binread(destination), "mismatch does not clobber")
    end
  end

  def test_existing_source_name_replacement_fails
    with_tmpdir do |directory|
      bytes = "FIXTURE_TECNICA_EXISTING_REBIND"
      replacement = "FIXTURE_TECNICA_REPLACEMENT"
      destination = File.join(directory, "source.bin")
      displaced = File.join(directory, "displaced.bin")
      File.binwrite(destination, bytes)
      original = P13SourceFetch.method(:verify_relative_file_identity)
      swapped = false
      P13SourceFetch.define_singleton_method(
        :verify_relative_file_identity
      ) do |parent, name, expected|
        unless swapped
          File.rename(destination, displaced)
          File.binwrite(destination, replacement)
          swapped = true
        end
        original.call(parent, name, expected)
      end

      begin
        assert_failure("source name identity changed") do
          P13SourceFetch.run(
            fetch_arguments(bytes, destination),
            fetcher: lambda { |_uri| raise "network must not run" }
          )
        end
      ensure
        P13SourceFetch.define_singleton_method(
          :verify_relative_file_identity,
          original
        )
      end
      assert(swapped, "existing source replacement hook ran")
      assert_equal(replacement, File.binread(destination), "replacement retained")
      assert_equal(bytes, File.binread(displaced), "verified source retained")
    end
  end

  def test_existing_fifo_fails_without_blocking
    with_tmpdir do |directory|
      bytes = "FIXTURE_TECNICA_FIFO_EXPECTED"
      destination = File.join(directory, "source.fifo")
      File.mkfifo(destination, 0o600)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      assert_failure("regular file") do
        P13SourceFetch.run(
          fetch_arguments(bytes, destination),
          fetcher: lambda { |_uri| raise "network must not run" }
        )
      end
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      assert(elapsed < 1, "FIFO rejection is nonblocking")
      assert_equal("fifo", File.lstat(destination).ftype, "FIFO retained")
    end
  end

  def test_cli_preserves_fetch_form_and_adds_extract_form
    with_tmpdir do |directory|
      fetched = "FIXTURE_TECNICA_CLI_FETCH"
      fetched_path = File.join(directory, "FIXTURE_TECNICA_FETCH.bin")
      File.binwrite(fetched_path, fetched)
      stdout, stderr, status = Open3.capture3(
        TOOL,
        *fetch_arguments(fetched, fetched_path)
      )
      assert(status.success?, "legacy CLI exits successfully")
      assert_equal(
        "P13_SOURCE_ALREADY_EXACT\n",
        stdout,
        "legacy CLI marker"
      )
      assert_equal("", stderr, "legacy CLI stderr")

      archive_bytes = valid_crate
      archive = write_archive(directory, archive_bytes)
      destination = File.join(directory, "FIXTURE_TECNICA_CLI_EXTRACTED")
      stdout, stderr, status = Open3.capture3(
        TOOL,
        *extraction_arguments(archive, archive_bytes, destination)
      )
      assert(status.success?, "extract CLI exits successfully")
      assert_equal(
        "P13_CRATE_EXTRACT_PASS\n",
        stdout,
        "extract CLI marker"
      )
      assert_equal("", stderr, "extract CLI stderr")
      assert_equal(
        "FIXTURE_TECNICA_SOURCE\n",
        File.binread(File.join(destination, "FIXTURE_TECNICA.txt")),
        "extract CLI content"
      )
    end
  end

  def test_malformed_fetch_arguments
    with_tmpdir do |directory|
      destination = File.join(directory, "source.bin")
      bytes = "FIXTURE_TECNICA_ARGUMENTS"
      exact = fetch_arguments(bytes, destination)
      mutations = [
        [["http://static.crates.io/source", *exact.drop(1)], "HTTPS"],
        [["not a URL", *exact.drop(1)], "invalid acquisition"],
        [
          ["https://static.crates.io.invalid/source", *exact.drop(1)],
          "not admitted"
        ],
        [[exact[0], "0", exact[2], exact[3]], "positive"],
        [
          [
            exact[0],
            (P13SourceFetch::MAX_FETCH_BYTES + 1).to_s,
            exact[2],
            exact[3]
          ],
          "acquisition limit"
        ],
        [[exact[0], "FIXTURE_TECNICA", exact[2], exact[3]], "invalid"],
        [[exact[0], exact[1], "A" * 64, exact[3]], "malformed"],
        [[exact[0], exact[1], "0" * 63, exact[3]], "malformed"],
        [[exact[0], exact[1], exact[2], "relative/path"], "absolute"]
      ]
      mutations.each do |arguments, message|
        assert_failure(message) do
          P13SourceFetch.run(
            arguments,
            fetcher: lambda { |_uri| raise "network must not run" }
          )
        end
      end
    end
  end

  def test_official_rust_source_host_is_admitted
    uri = P13SourceFetch.parse_source_uri(
      "https://static.rust-lang.org/dist/2026-08-20/" \
      "rustc-1.98.0-src.tar.xz"
    )
    assert_equal(
      "static.rust-lang.org",
      uri.host,
      "official Rust source host"
    )
  end

  def test_real_ledger_crates_replay_exactly
    evidence = P13NoiseEvidence.read_yaml(
      File.join(
        P13NoiseEvidence::ROOT,
        P13NoiseEvidence::EVIDENCE
      )
    )
    closure = evidence.fetch("closure")
    archives = closure.fetch("local_archive_root")
    extracted = closure.fetch("local_registry_source_root")
    compared = 0

    Dir.mktmpdir("FIXTURE_TECNICA_p13_real_crates_", TMP_ROOT) do |directory|
      closure.fetch("packages").each do |package|
        identity = "#{package.fetch('name')}-#{package.fetch('version')}"
        archive = File.join(archives, "#{identity}.crate")
        destination = File.join(directory, identity)
        P13SourceFetch.run(
          extraction_arguments(
            archive,
            File.binread(archive),
            destination,
            identity
          ),
          output: StringIO.new
        )

        expected = P13NoiseEvidence.crate_entries(archive, identity)
        expected[".cargo-ok"] = {
          "mode" => "644",
          "contents" => "{\"v\":1}".b
        }
        actual = P13NoiseEvidence.tree_entries(destination)
        assert_equal(expected, actual, "#{identity} archive replay")

        existing = File.join(extracted, identity)
        next unless File.directory?(existing)

        assert_equal(
          P13NoiseEvidence.tree_entries(existing),
          actual,
          "#{identity} existing Cargo extraction"
        )
        compared += 1
      end
    end
    assert_equal(23, closure.fetch("packages").length, "real archive count")
    assert_equal(22, compared, "existing Cargo extraction comparison count")
  end

  def test_fetch_overrun_underrun_and_hash_mismatch
    with_tmpdir do |directory|
      expected = "FIXTURE_TECNICA_EXPECTED"
      destination = File.join(directory, "source.bin")
      arguments = fetch_arguments(expected, destination)
      assert_failure("exceeds") do
        P13SourceFetch.run(
          arguments,
          fetcher: injected_fetch([expected, "_OVERRUN"])
        )
      end
      assert(!File.exist?(destination), "overrun leaves no destination")

      assert_failure("size differs") do
        P13SourceFetch.run(
          arguments,
          fetcher: injected_fetch(["FIXTURE_TECNICA"])
        )
      end
      assert(!File.exist?(destination), "underrun leaves no destination")

      wrong = "FIXTURE_TECNICA_EXPECTEX"
      assert_equal(expected.bytesize, wrong.bytesize, "hash fixture length")
      assert_failure("SHA-256 differs") do
        P13SourceFetch.run(
          arguments,
          fetcher: injected_fetch([wrong])
        )
      end
      assert(!File.exist?(destination), "hash mismatch leaves no destination")
    end
  end

  def test_fetch_publication_does_not_clobber_late_destination
    [
      [
        "regular file",
        lambda do |destination, _directory|
          File.binwrite(destination, "FIXTURE_TECNICA_LATE_FILE")
        end
      ],
      [
        "symlink",
        lambda do |destination, directory|
          target = File.join(directory, "FIXTURE_TECNICA_TARGET")
          File.binwrite(target, "FIXTURE_TECNICA_SYMLINK_TARGET")
          File.symlink(target, destination)
        end
      ]
    ].each do |label, create_destination|
      with_tmpdir do |directory|
        bytes = "FIXTURE_TECNICA_FETCH_RACE"
        destination = File.join(directory, "source.bin")
        fetcher = lambda do |uri, &receiver|
          assert_equal("static.crates.io", uri.host, "#{label} fetch host")
          create_destination.call(destination, directory)
          receiver.call(bytes)
          true
        end
        assert_failure("destination appeared") do
          P13SourceFetch.run(
            fetch_arguments(bytes, destination),
            fetcher: fetcher,
            output: StringIO.new
          )
        end

        stat = File.lstat(destination)
        if label == "regular file"
          assert(stat.file?, "late regular file remains a file")
          assert_equal(
            "FIXTURE_TECNICA_LATE_FILE",
            File.binread(destination),
            "late regular file is not clobbered"
          )
        else
          assert(stat.symlink?, "late symlink remains a symlink")
          assert_equal(
            "FIXTURE_TECNICA_SYMLINK_TARGET",
            File.binread(destination),
            "late symlink target is not clobbered"
          )
        end
      end
    end
  end

  def test_fetch_cleanup_retains_temporary_name_replacement
    with_tmpdir do |directory|
      bytes = "FIXTURE_TECNICA_CLEANUP_EXPECTED"
      replacement = "FIXTURE_TECNICA_CLEANUP_REPLACEMENT"
      destination = File.join(directory, "source.bin")
      displaced = File.join(directory, "displaced.part")
      temporary_name = nil
      fetcher = lambda do |_uri, &_receiver|
        temporary_name = Dir.children(directory).find do |name|
          name.start_with?(".p13-source-")
        end
        original = File.join(directory, temporary_name)
        File.rename(original, displaced)
        File.binwrite(original, replacement)
        raise P13SourceFetch::Failure, "injected transfer failure"
      end

      assert_failure("cleanup source identity changed") do
        P13SourceFetch.run(
          fetch_arguments(bytes, destination),
          fetcher: fetcher,
          output: StringIO.new
        )
      end
      assert(
        !File.exist?(File.join(directory, temporary_name)),
        "replaced temporary name is vacated"
      )
      assert_equal(
        replacement,
        File.binread(sole_cleanup_quarantine(directory)),
        "replacement retained in quarantine"
      )
      assert(File.exist?(displaced), "original temporary inode retained")
    end
  end

  def test_fetch_cleanup_retains_published_name_replacement
    with_tmpdir do |directory|
      bytes = "FIXTURE_TECNICA_PUBLISHED_EXPECTED"
      replacement = "FIXTURE_TECNICA_PUBLISHED_REPLACEMENT"
      destination = File.join(directory, "source.bin")
      displaced = File.join(directory, "published.bin")
      original = P13SourceFetch.method(:open_relative_file)
      swapped = false
      P13SourceFetch.define_singleton_method(
        :open_relative_file
      ) do |parent, name, allow_missing:|
        if !swapped && name == File.basename(destination) && File.exist?(destination)
          File.rename(destination, displaced)
          File.binwrite(destination, replacement)
          swapped = true
        end
        original.call(parent, name, allow_missing: allow_missing)
      end

      begin
        assert_failure("cleanup source identity changed") do
          P13SourceFetch.run(
            fetch_arguments(bytes, destination),
            fetcher: injected_fetch([bytes]),
            output: StringIO.new
          )
        end
      ensure
        P13SourceFetch.define_singleton_method(:open_relative_file, original)
      end
      assert(swapped, "published source replacement hook ran")
      assert(!File.exist?(destination), "replacement public name is vacated")
      assert_equal(
        replacement,
        File.binread(sole_cleanup_quarantine(directory)),
        "published replacement retained in quarantine"
      )
      assert_equal(bytes, File.binread(displaced), "published source retained")
    end
  end

  def test_fetch_terminal_published_name_replacement_fails
    with_tmpdir do |directory|
      bytes = "FIXTURE_TECNICA_TERMINAL_EXPECTED"
      replacement = "FIXTURE_TECNICA_TERMINAL_REPLACEMENT"
      destination = File.join(directory, "source.bin")
      displaced = File.join(directory, "terminal-original.bin")
      original = P13SourceFetch.method(:assert_current_parent_identity)
      swapped = false
      P13SourceFetch.define_singleton_method(
        :assert_current_parent_identity
      ) do |path, expected|
        result = original.call(path, expected)
        if !swapped && path == destination && File.exist?(destination)
          File.rename(destination, displaced)
          File.binwrite(destination, replacement)
          swapped = true
        end
        result
      end

      output = StringIO.new
      begin
        assert_failure("cleanup source identity changed") do
          P13SourceFetch.run(
            fetch_arguments(bytes, destination),
            fetcher: injected_fetch([bytes]),
            output: output
          )
        end
      ensure
        P13SourceFetch.define_singleton_method(
          :assert_current_parent_identity,
          original
        )
      end
      assert(swapped, "terminal source replacement hook ran")
      assert_equal("", output.string, "terminal substitution has no PASS marker")
      assert(!File.exist?(destination), "terminal replacement name is vacated")
      assert_equal(
        replacement,
        File.binread(sole_cleanup_quarantine(directory)),
        "terminal replacement retained in quarantine"
      )
      assert_equal(bytes, File.binread(displaced), "verified source retained")
    end
  end

  def test_fetch_rejects_destination_ancestor_replacement
    with_tmpdir do |directory|
      bytes = "FIXTURE_TECNICA_ANCESTOR_REPLACEMENT"
      parent = File.join(directory, "acquisition")
      displaced = File.join(directory, "displaced")
      destination = File.join(parent, "source.bin")
      Dir.mkdir(parent, 0o700)

      fetcher = lambda do |uri, &receiver|
        assert_equal(
          "static.crates.io",
          uri.host,
          "ancestor replacement fetch host"
        )
        temporary_name = Dir.children(parent).fetch(0)
        assert(
          temporary_name.start_with?(".p13-source-") &&
            temporary_name.end_with?(".part"),
          "private acquisition filename"
        )

        File.rename(parent, displaced)
        Dir.mkdir(parent, 0o700)
        decoy = File.join(parent, temporary_name)
        File.binwrite(decoy, bytes)
        File.chmod(0o444, decoy)
        receiver.call(bytes)
        true
      end

      assert_failure("parent identity changed") do
        P13SourceFetch.run(
          fetch_arguments(bytes, destination),
          fetcher: fetcher,
          output: StringIO.new
        )
      end
      assert(
        !File.exist?(destination),
        "replacement parent receives no destination"
      )
      assert(
        !File.exist?(File.join(displaced, "source.bin")),
        "validated parent receives no destination after displacement"
      )
      assert_equal(
        bytes,
        File.binread(sole_cleanup_quarantine(displaced)),
        "private acquisition file is retained through held parent descriptor"
      )
    end
  end

  def test_nested_parent_creation_is_deterministic
    with_tmpdir do |directory|
      bytes = "FIXTURE_TECNICA_NESTED"
      first = File.join(directory, "level_a")
      second = File.join(first, "level_b")
      destination = File.join(second, "source.bin")
      P13SourceFetch.run(
        fetch_arguments(bytes, destination),
        fetcher: injected_fetch([bytes]),
        output: StringIO.new
      )
      [first, second].each do |path|
        stat = File.lstat(path)
        assert(stat.directory?, "created parent is directory")
        assert_equal(Process.euid, stat.uid, "created parent owner")
        assert_equal(0o700, stat.mode & 0o7777, "created parent mode")
      end
    end
  end

  def test_symlink_and_insecure_parent_are_rejected
    with_tmpdir do |directory|
      bytes = "FIXTURE_TECNICA_PARENT"
      real = File.join(directory, "real")
      link = File.join(directory, "link")
      Dir.mkdir(real, 0o700)
      File.symlink(real, link)
      assert_failure("not a directory") do
        P13SourceFetch.run(
          fetch_arguments(bytes, File.join(link, "source.bin")),
          fetcher: injected_fetch([bytes])
        )
      end

      insecure = File.join(directory, "insecure")
      Dir.mkdir(insecure, 0o777)
      File.chmod(0o777, insecure)
      assert_failure("insecurely writable") do
        P13SourceFetch.run(
          fetch_arguments(bytes, File.join(insecure, "source.bin")),
          fetcher: injected_fetch([bytes])
        )
      end
    end

    fake = Struct.new(:directory?, :symlink?, :uid, :mode).new(
      true,
      false,
      Process.euid + 1,
      0o755
    )
    assert_failure("untrusted owner") do
      P13SourceFetch.validate_directory_stat(
        fake,
        "/FIXTURE_TECNICA_unowned"
      )
    end
  end

  def test_exact_crate_extraction
    with_tmpdir do |directory|
      destination, output = run_extract(directory, valid_crate)
      assert_equal(
        "P13_CRATE_EXTRACT_PASS\n",
        output,
        "crate extraction marker"
      )
      assert_equal(
        "FIXTURE_TECNICA_SOURCE\n",
        File.binread(File.join(destination, "FIXTURE_TECNICA.txt")),
        "top-level extracted content"
      )
      marker = File.join(destination, ".cargo-ok")
      assert_equal("{\"v\":1}", File.binread(marker), "Cargo marker content")
      assert_equal(0o644, File.stat(marker).mode & 0o777, "Cargo marker mode")
      nested = File.join(destination, "nested", "FIXTURE_TECNICA.sh")
      assert_equal(
        "# FIXTURE_TECNICA\n",
        File.binread(nested),
        "nested extracted content"
      )
      assert_equal(0o755, File.stat(destination).mode & 0o777, "root mode")
      assert_equal(
        0o755,
        File.stat(File.dirname(nested)).mode & 0o777,
        "implicit directory mode"
      )
      assert_equal(0o755, File.stat(nested).mode & 0o777, "file mode")
      assert_equal(
        "FIXTURE_TECNICA_UTF8_".b + [0xc3, 0xa7].pack("C*"),
        File.binread(
          File.join(destination, "nested", "FIXTURE_TECNICA_UTF8.bin")
        ),
        "non-ASCII archive bytes"
      )
    end
  end

  def test_extract_accepts_crates_io_zero_owner_fields
    bytes = gzip_bytes(
      tar_bytes(
        [
          with_zero_tar_owner_fields(
            tar_entry(
              "#{PREFIX}/FIXTURE_TECNICA.txt",
              "FIXTURE_TECNICA_ZERO_OWNER\n"
            )
          )
        ]
      )
    )
    with_tmpdir do |directory|
      destination, = run_extract(directory, bytes)
      assert_equal(
        "FIXTURE_TECNICA_ZERO_OWNER\n",
        File.binread(File.join(destination, "FIXTURE_TECNICA.txt")),
        "all-NUL crates.io UID and GID fields"
      )
    end
  end

  def test_extract_repeat_and_no_clobber
    with_tmpdir do |directory|
      bytes = valid_crate
      archive = write_archive(directory, bytes)
      destination = File.join(directory, "extracted")
      arguments = extraction_arguments(archive, bytes, destination)
      P13SourceFetch.run(arguments, output: StringIO.new)

      output = StringIO.new
      assert(
        P13SourceFetch.run(arguments, output: output),
        "exact repeated extraction"
      )
      assert_equal(
        "P13_CRATE_ALREADY_EXACT\n",
        output.string,
        "repeat extraction marker"
      )

      path = File.join(destination, "FIXTURE_TECNICA.txt")
      File.chmod(0o644, path)
      File.binwrite(path, "FIXTURE_TECNICA_CHANGED\n")
      before = File.binread(path)
      assert_failure("content differs") do
        P13SourceFetch.run(arguments, output: StringIO.new)
      end
      assert_equal(before, File.binread(path), "mismatch remains untouched")
    end

    with_tmpdir do |directory|
      bytes = valid_crate
      archive = write_archive(directory, bytes)
      destination = File.join(directory, "occupied")
      Dir.mkdir(destination, 0o755)
      marker = File.join(destination, "FIXTURE_TECNICA_KEEP")
      File.binwrite(marker, "FIXTURE_TECNICA_KEEP")
      assert_failure("paths differ") do
        P13SourceFetch.run(
          extraction_arguments(archive, bytes, destination),
          output: StringIO.new
        )
      end
      assert_equal(
        "FIXTURE_TECNICA_KEEP",
        File.binread(marker),
        "occupied destination is not clobbered"
      )
    end
  end

  def test_existing_tree_enforces_path_depth_boundary
    limit = P13SourceFetch::MAX_ARCHIVE_PATH_DEPTH

    with_tmpdir do |directory|
      root = File.join(directory, "exact-depth")
      Dir.mkdir(root, 0o700)
      current = root
      entries = {}
      components = (["d"] * (limit - 1)) + ["FIXTURE_TECNICA"]
      components.each_with_index do |component, index|
        relative = components.first(index + 1).join("/")
        if index == components.length - 1
          File.binwrite(
            File.join(current, component),
            "FIXTURE_TECNICA_DEPTH\n"
          )
          File.chmod(0o644, File.join(current, component))
          entries[relative] = {
            "type" => :file,
            "mode" => 0o644,
            "contents" => "FIXTURE_TECNICA_DEPTH\n".b
          }
        else
          current = File.join(current, component)
          Dir.mkdir(current, 0o755)
          File.chmod(0o755, current)
          entries[relative] = {
            "type" => :directory,
            "mode" => 0o755
          }
        end
      end
      manifest = {
        "root_mode" => 0o700,
        "entries" => entries
      }
      assert(
        verify_existing_tree(root, manifest),
        "existing path at the depth limit is accepted"
      )
    end

    with_tmpdir do |directory|
      root = File.join(directory, "depth-plus-one")
      Dir.mkdir(root, 0o700)
      current = root
      entries = {}
      components = ["d"] * (limit + 1)
      components.each_with_index do |component, index|
        current = File.join(current, component)
        Dir.mkdir(current, 0o755)
        File.chmod(0o755, current)
        next if index >= limit

        relative = components.first(index + 1).join("/")
        entries[relative] = {
          "type" => :directory,
          "mode" => 0o755
        }
      end
      manifest = {
        "root_mode" => 0o700,
        "entries" => entries
      }
      assert_failure("path is too deeply nested") do
        verify_existing_tree(root, manifest)
      end
    end
  end

  def test_existing_tree_enforces_entry_bounds
    with_tmpdir do |directory|
      root = File.join(directory, "enumeration")
      Dir.mkdir(root, 0o700)
      %w[FIXTURE_TECNICA_A FIXTURE_TECNICA_B].each do |name|
        Dir.mkdir(File.join(root, name), 0o755)
      end
      flags = File::RDONLY | File::NOFOLLOW |
        P13SourceFetch::DIRECTORY_OPEN_FLAG
      File.open(root, flags) do |descriptor|
        assert_failure("entry limit exceeded") do
          P13SourceFetch.directory_entry_names(
            descriptor,
            maximum_entries: 1
          )
        end
      end
    end

    entries = {}
    P13SourceFetch::MAX_MANIFEST_ENTRIES.times do |index|
      entries[format("FIXTURE_TECNICA_%05d", index)] = {
        "type" => :directory,
        "mode" => 0o755
      }
    end
    manifest = {
      "root_mode" => 0o700,
      "entries" => entries
    }
    _root_mode, accepted = P13SourceFetch.validate_verification_manifest(
      manifest
    )
    assert_equal(
      P13SourceFetch::MAX_MANIFEST_ENTRIES,
      accepted.length,
      "manifest entry limit is accepted"
    )
    entries["FIXTURE_TECNICA_OVER_LIMIT"] = {
      "type" => :directory,
      "mode" => 0o755
    }
    assert_failure("manifest entry limit exceeded") do
      P13SourceFetch.validate_verification_manifest(manifest)
    end
  end

  def test_existing_tree_rejects_unexpected_large_file_before_open
    with_tmpdir do |directory|
      root = File.join(directory, "unexpected-large")
      Dir.mkdir(root, 0o700)
      name = "!FIXTURE_TECNICA_UNEXPECTED_LARGE"
      path = File.join(root, name)
      File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o644) do |file|
        file.truncate(P13SourceFetch::MAX_TAR_BYTES + 1)
      end
      File.chmod(0o644, path)

      original = P13SourceFetch.method(:open_tree_file)
      opened = false
      P13SourceFetch.define_singleton_method(:open_tree_file) do |parent, child|
        opened = true if child == name
        original.call(parent, child)
      end
      begin
        assert_failure("paths differ") do
          verify_existing_tree(
            root,
            {
              "root_mode" => 0o700,
              "entries" => {}
            }
          )
        end
      ensure
        P13SourceFetch.define_singleton_method(:open_tree_file, original)
      end
      assert(!opened, "unexpected large file is rejected before open or read")
    end
  end

  def test_existing_tree_rejects_known_size_mismatch_before_read
    with_tmpdir do |directory|
      root = File.join(directory, "known-size-mismatch")
      Dir.mkdir(root, 0o700)
      name = "FIXTURE_TECNICA_SIZE"
      path = File.join(root, name)
      File.binwrite(path, "XX")
      File.chmod(0o644, path)
      manifest = {
        "root_mode" => 0o700,
        "entries" => {
          name => {
            "type" => :file,
            "mode" => 0o644,
            "contents" => "X".b
          }
        }
      }

      original = P13SourceFetch.method(:open_tree_file)
      read = false
      P13SourceFetch.define_singleton_method(:open_tree_file) do |parent, child|
        file = original.call(parent, child)
        if child == name
          file.define_singleton_method(:read) do |*_arguments|
            read = true
            raise "FIXTURE_TECNICA unexpected content read"
          end
        end
        file
      end
      begin
        assert_failure("content differs") do
          verify_existing_tree(root, manifest)
        end
      ensure
        P13SourceFetch.define_singleton_method(:open_tree_file, original)
      end
      assert(!read, "known size mismatch is rejected before content read")
    end
  end

  def test_existing_valid_extraction_passes_bounded_verification
    with_tmpdir do |directory|
      bytes = valid_crate
      archive = write_archive(directory, bytes)
      destination = File.join(directory, "bounded-existing")
      arguments = extraction_arguments(archive, bytes, destination)
      P13SourceFetch.run(arguments, output: StringIO.new)

      output = StringIO.new
      assert(
        P13SourceFetch.run(arguments, output: output),
        "bounded existing extraction verification"
      )
      assert_equal(
        "P13_CRATE_ALREADY_EXACT\n",
        output.string,
        "bounded existing extraction marker"
      )
    end
  end

  def test_existing_exact_extraction_revalidates_name_after_parent
    with_tmpdir do |directory|
      bytes = valid_crate
      archive = write_archive(directory, bytes)
      destination = File.join(directory, "extracted")
      displaced = File.join(directory, "displaced-existing")
      marker_name = "FIXTURE_TECNICA_EXISTING_REPLACEMENT"
      arguments = extraction_arguments(archive, bytes, destination)
      P13SourceFetch.run(arguments, output: StringIO.new)

      original = P13SourceFetch.method(:assert_current_parent_identity)
      swapped = false
      P13SourceFetch.define_singleton_method(
        :assert_current_parent_identity
      ) do |path, expected|
        result = original.call(path, expected)
        if !swapped && path == destination
          File.rename(destination, displaced)
          Dir.mkdir(destination, 0o700)
          File.binwrite(
            File.join(destination, marker_name),
            "FIXTURE_TECNICA_EXISTING_REPLACEMENT\n"
          )
          swapped = true
        end
        result
      end

      output = StringIO.new
      begin
        assert_failure("extraction directory identity changed") do
          P13SourceFetch.run(arguments, output: output)
        end
      ensure
        P13SourceFetch.define_singleton_method(
          :assert_current_parent_identity,
          original
        )
      end

      assert(swapped, "existing extraction replacement hook ran")
      assert_equal("", output.string, "terminal substitution has no PASS marker")
      assert_equal(
        "FIXTURE_TECNICA_EXISTING_REPLACEMENT\n",
        File.binread(File.join(destination, marker_name)),
        "replacement destination remains untouched"
      )
      assert_equal(
        "FIXTURE_TECNICA_SOURCE\n",
        File.binread(File.join(displaced, "FIXTURE_TECNICA.txt")),
        "verified existing extraction remains untouched"
      )
      assert_equal(
        [],
        cleanup_quarantines(directory),
        "unowned existing extraction race creates no quarantine"
      )
    end
  end

  def test_extract_cleanup_retains_staging_name_replacement
    with_tmpdir do |directory|
      bytes = valid_crate
      archive = write_archive(directory, bytes)
      destination = File.join(directory, "extracted")
      displaced = File.join(directory, "displaced-stage")
      marker_name = "FIXTURE_TECNICA_REPLACEMENT"
      original = P13SourceFetch.method(:materialize_manifest)
      swapped = false
      P13SourceFetch.define_singleton_method(
        :materialize_manifest
      ) do |root, manifest|
        original.call(root, manifest)
        staging_name = Dir.children(directory).find do |name|
          name.start_with?(".p13-crate-stage-")
        end
        raise "FIXTURE_TECNICA staging directory missing" unless staging_name

        staging_path = File.join(directory, staging_name)
        File.rename(staging_path, displaced)
        Dir.mkdir(staging_path, 0o700)
        File.binwrite(
          File.join(staging_path, marker_name),
          "FIXTURE_TECNICA_REPLACEMENT\n"
        )
        swapped = true
        raise P13SourceFetch::Failure, "injected materialization failure"
      end

      begin
        assert_failure("cleanup extraction identity changed") do
          P13SourceFetch.run(
            extraction_arguments(archive, bytes, destination),
            output: StringIO.new
          )
        end
      ensure
        P13SourceFetch.define_singleton_method(:materialize_manifest, original)
      end
      assert(swapped, "staging replacement hook ran")
      assert(
        Dir.children(directory).none? do |name|
          name.start_with?(".p13-crate-stage-")
        end,
        "replaced staging name is vacated"
      )
      assert_equal(
        "FIXTURE_TECNICA_REPLACEMENT\n",
        File.binread(File.join(sole_cleanup_quarantine(directory), marker_name)),
        "replacement staging directory retained in quarantine"
      )
      assert(File.directory?(displaced), "original staging inode retained")
    end
  end

  def test_extract_cleanup_retains_published_destination_replacement
    with_tmpdir do |directory|
      bytes = valid_crate
      archive = write_archive(directory, bytes)
      destination = File.join(directory, "extracted")
      displaced = File.join(directory, "displaced-published")
      marker = File.join(destination, "FIXTURE_TECNICA_REPLACEMENT")
      original = P13SourceFetch.method(:open_extracted_directory)
      swapped = false
      P13SourceFetch.define_singleton_method(
        :open_extracted_directory
      ) do |parent, name, allow_missing:|
        if !swapped && !allow_missing && name == File.basename(destination)
          File.rename(destination, displaced)
          Dir.mkdir(destination, 0o700)
          File.binwrite(marker, "FIXTURE_TECNICA_REPLACEMENT\n")
          swapped = true
        end
        original.call(parent, name, allow_missing: allow_missing)
      end

      begin
        assert_failure("cleanup extraction identity changed") do
          P13SourceFetch.run(
            extraction_arguments(archive, bytes, destination),
            output: StringIO.new
          )
        end
      ensure
        P13SourceFetch.define_singleton_method(
          :open_extracted_directory,
          original
        )
      end
      assert(swapped, "published destination replacement hook ran")
      assert(!File.exist?(destination), "replacement destination name is vacated")
      assert_equal(
        "FIXTURE_TECNICA_REPLACEMENT\n",
        File.binread(
          File.join(
            sole_cleanup_quarantine(directory),
            File.basename(marker)
          )
        ),
        "replacement destination retained in quarantine"
      )
      assert_equal(
        "FIXTURE_TECNICA_SOURCE\n",
        File.binread(File.join(displaced, "FIXTURE_TECNICA.txt")),
        "published extraction inode retained"
      )
    end
  end

  def test_extract_terminal_published_name_replacement_fails
    with_tmpdir do |directory|
      bytes = valid_crate
      archive = write_archive(directory, bytes)
      destination = File.join(directory, "extracted")
      displaced = File.join(directory, "terminal-extraction-original")
      marker_name = "FIXTURE_TECNICA_TERMINAL_REPLACEMENT"
      original = P13SourceFetch.method(:assert_current_parent_identity)
      swapped = false
      P13SourceFetch.define_singleton_method(
        :assert_current_parent_identity
      ) do |path, expected|
        result = original.call(path, expected)
        if !swapped && path == destination && File.directory?(destination)
          File.rename(destination, displaced)
          Dir.mkdir(destination, 0o700)
          File.binwrite(
            File.join(destination, marker_name),
            "FIXTURE_TECNICA_TERMINAL_REPLACEMENT\n"
          )
          swapped = true
        end
        result
      end

      output = StringIO.new
      begin
        assert_failure("cleanup extraction identity changed") do
          P13SourceFetch.run(
            extraction_arguments(archive, bytes, destination),
            output: output
          )
        end
      ensure
        P13SourceFetch.define_singleton_method(
          :assert_current_parent_identity,
          original
        )
      end
      assert(swapped, "terminal extraction replacement hook ran")
      assert_equal("", output.string, "terminal substitution has no PASS marker")
      assert(!File.exist?(destination), "terminal extraction name is vacated")
      quarantine = sole_cleanup_quarantine(directory)
      assert_equal(
        "FIXTURE_TECNICA_TERMINAL_REPLACEMENT\n",
        File.binread(File.join(quarantine, marker_name)),
        "terminal extraction replacement retained in quarantine"
      )
      assert_equal(
        "FIXTURE_TECNICA_SOURCE\n",
        File.binread(File.join(displaced, "FIXTURE_TECNICA.txt")),
        "verified extraction retained"
      )
    end
  end

  def test_extract_rejects_destination_ancestor_replacement
    with_tmpdir do |directory|
      bytes = valid_crate
      archive = write_archive(directory, bytes)
      parent = File.join(directory, "acquisition")
      displaced = File.join(directory, "displaced")
      destination = File.join(parent, "extracted")
      Dir.mkdir(parent, 0o700)

      original_publication = P13SourceFetch.method(
        :atomic_publish_directory
      )
      swapped = false
      P13SourceFetch.define_singleton_method(
        :atomic_publish_directory
      ) do |source, target, parent_directory|
        unless swapped
          File.rename(parent, displaced)
          Dir.mkdir(parent, 0o700)
          FileUtils.cp_r(
            File.join(displaced, File.basename(source)),
            File.join(parent, File.basename(target)),
            preserve: true
          )
          swapped = true
        end
        original_publication.call(source, target, parent_directory)
      end

      begin
        assert_failure("parent identity changed") do
          P13SourceFetch.run(
            extraction_arguments(archive, bytes, destination),
            output: StringIO.new
          )
        end
      ensure
        P13SourceFetch.define_singleton_method(
          :atomic_publish_directory,
          original_publication
        )
      end

      assert(swapped, "ancestor replacement hook ran")
      assert(
        !File.exist?(File.join(displaced, "extracted")),
        "descriptor-bound publication name is vacated after parent replacement"
      )
      assert_equal(
        "FIXTURE_TECNICA_SOURCE\n",
        File.binread(
          File.join(
            sole_cleanup_quarantine(displaced),
            "FIXTURE_TECNICA.txt"
          )
        ),
        "descriptor-bound publication is retained in quarantine"
      )
      assert_equal(
        "FIXTURE_TECNICA_SOURCE\n",
        File.binread(File.join(destination, "FIXTURE_TECNICA.txt")),
        "replacement-path decoy remains distinct from held-parent output"
      )
    end
  end

  def test_atomic_publication_rejects_late_empty_destination
    with_tmpdir do |directory|
      source = File.join(directory, "FIXTURE_TECNICA_staging")
      destination = File.join(directory, "FIXTURE_TECNICA_destination")
      Dir.mkdir(source, 0o700)
      source_file = File.join(source, "FIXTURE_TECNICA_SOURCE")
      File.binwrite(source_file, "FIXTURE_TECNICA_SOURCE")
      Dir.mkdir(destination, 0o700)
      P13SourceFetch.with_directory_lock(directory) do |parent|
        assert_failure("destination appeared") do
          P13SourceFetch.atomic_publish_directory(source, destination, parent)
        end
      end
      assert(File.directory?(source), "staging directory survives collision")
      assert(
        File.directory?(destination),
        "late destination survives collision"
      )
      assert_equal(
        "FIXTURE_TECNICA_SOURCE",
        File.binread(source_file),
        "staged bytes survive collision"
      )
      assert_equal([], Dir.children(destination), "destination is untouched")
    end
  end

  def test_extract_rejects_archive_identity_mismatch
    with_tmpdir do |directory|
      bytes = valid_crate
      archive = write_archive(directory, bytes)
      destination = File.join(directory, "extracted")
      size_arguments = extraction_arguments(archive, bytes, destination)
      size_arguments[2] = (bytes.bytesize + 1).to_s
      assert_failure("size differs") do
        P13SourceFetch.run(size_arguments, output: StringIO.new)
      end

      hash_arguments = extraction_arguments(archive, bytes, destination)
      hash_arguments[3] = Digest::SHA256.hexdigest(
        "FIXTURE_TECNICA_WRONG_ARCHIVE"
      )
      assert_failure("SHA-256 differs") do
        P13SourceFetch.run(hash_arguments, output: StringIO.new)
      end
      assert(!File.exist?(destination), "identity mismatch has no output")
    end
  end

  def test_extract_rejects_wrong_prefix_and_traversal
    wrong_prefix = gzip_bytes(
      tar_bytes(
        [
          tar_entry(
            "FIXTURE_TECNICA_OTHER/FIXTURE_TECNICA.txt",
            "FIXTURE_TECNICA_SOURCE"
          )
        ]
      )
    )
    traversal = gzip_bytes(
      tar_bytes(
        [
          tar_entry(
            "#{PREFIX}/../FIXTURE_TECNICA_ESCAPE",
            "FIXTURE_TECNICA_ESCAPE"
          )
        ]
      )
    )
    [wrong_prefix, traversal].each_with_index do |bytes, index|
      with_tmpdir do |directory|
        archive = write_archive(
          directory,
          bytes,
          "FIXTURE_TECNICA_#{index}.crate"
        )
        message = index.zero? ? "prefix differs" : "path is unsafe"
        assert_failure(message) do
          P13SourceFetch.run(
            extraction_arguments(
              archive,
              bytes,
              File.join(directory, "extracted")
            ),
            output: StringIO.new
          )
        end
      end
    end
  end

  def test_extract_rejects_derived_manifest_amplification
    entries = 500.times.map do |index|
      nested = (["a"] * 32).join("/")
      path = "#{PREFIX}/#{format('%04x', index)}/#{nested}/file"
      tar_entry(path, "X")
    end
    bytes = gzip_bytes(tar_bytes(entries))
    assert(
      bytes.bytesize < P13SourceFetch::MAX_ARCHIVE_BYTES,
      "amplification fixture is below the compressed archive limit"
    )
    assert_failure("derived entry limit exceeded") do
      P13SourceFetch.parse_crate_archive(bytes, PREFIX)
    end
  end

  def test_extract_enforces_archive_path_depth_boundary
    limit = P13SourceFetch::MAX_ARCHIVE_PATH_DEPTH
    paths = [limit, limit + 1].map do |depth|
      ([PREFIX] + (["a"] * (depth - 2)) + ["file"]).join("/")
    end
    paths.each do |path|
      assert(path.bytesize > 100, "depth fixture uses the USTAR prefix field")
      assert(path.bytesize <= 256, "depth fixture fits the USTAR path fields")
    end

    accepted = gzip_bytes(
      tar_bytes(
        [tar_entry(paths.fetch(0), "FIXTURE_TECNICA_DEPTH_LIMIT\n")]
      )
    )
    with_tmpdir do |directory|
      destination, output = run_extract(directory, accepted)
      relative = paths.fetch(0).delete_prefix("#{PREFIX}/")
      assert_equal(
        "P13_CRATE_EXTRACT_PASS\n",
        output,
        "archive path at the depth limit is accepted"
      )
      assert_equal(
        "FIXTURE_TECNICA_DEPTH_LIMIT\n",
        File.binread(File.join(destination, relative)),
        "depth-limit archive reaches materialization"
      )
    end

    rejected = gzip_bytes(
      tar_bytes(
        [tar_entry(paths.fetch(1), "FIXTURE_TECNICA_DEPTH_LIMIT_PLUS_ONE\n")]
      )
    )
    with_tmpdir do |directory|
      archive = write_archive(directory, rejected)
      destination = File.join(directory, "extracted")
      assert_failure("path is too deeply nested") do
        P13SourceFetch.run(
          extraction_arguments(archive, rejected, destination),
          output: StringIO.new
        )
      end
      assert(
        !File.exist?(destination),
        "archive path above the depth limit has no extraction output"
      )
    end
  end

  def test_extract_rejects_duplicate_paths
    duplicate = gzip_bytes(
      tar_bytes(
        [
          tar_entry(
            "#{PREFIX}/FIXTURE_TECNICA.txt",
            "FIXTURE_TECNICA_A"
          ),
          tar_entry(
            "#{PREFIX}/FIXTURE_TECNICA.txt",
            "FIXTURE_TECNICA_B"
          )
        ]
      )
    )
    with_tmpdir do |directory|
      archive = write_archive(directory, duplicate)
      assert_failure("duplicate path") do
        P13SourceFetch.run(
          extraction_arguments(
            archive,
            duplicate,
            File.join(directory, "extracted")
          ),
          output: StringIO.new
        )
      end
    end
  end

  def test_extract_rejects_archive_supplied_cargo_marker
    marker = gzip_bytes(
      tar_bytes(
        [
          tar_entry(
            "#{PREFIX}/.cargo-ok",
            "{\"v\":1}"
          )
        ]
      )
    )
    with_tmpdir do |directory|
      archive = write_archive(directory, marker)
      assert_failure("reserved Cargo marker") do
        P13SourceFetch.run(
          extraction_arguments(
            archive,
            marker,
            File.join(directory, "extracted")
          ),
          output: StringIO.new
        )
      end
    end
  end

  def test_extract_rejects_links_and_unsupported_types
    fixtures = [
      [
        tar_entry(
          "#{PREFIX}/FIXTURE_TECNICA_LINK",
          "",
          type: "2",
          linkname: "FIXTURE_TECNICA_TARGET"
        ),
        "links are prohibited"
      ],
      [
        tar_entry(
          "#{PREFIX}/FIXTURE_TECNICA_FIFO",
          "",
          type: "6"
        ),
        "type is unsupported"
      ]
    ]
    fixtures.each_with_index do |(entry, message), index|
      bytes = gzip_bytes(tar_bytes([entry]))
      with_tmpdir do |directory|
        archive = write_archive(
          directory,
          bytes,
          "FIXTURE_TECNICA_TYPE_#{index}.crate"
        )
        assert_failure(message) do
          P13SourceFetch.run(
            extraction_arguments(
              archive,
              bytes,
              File.join(directory, "extracted")
            ),
            output: StringIO.new
          )
        end
      end
    end
  end

  def test_extract_rejects_unsafe_archive_modes
    fixtures = [
      [
        tar_entry(
          "#{PREFIX}/FIXTURE_TECNICA_WRITABLE_FILE",
          "FIXTURE_TECNICA",
          mode: 0o666
        ),
        "world-writable file"
      ],
      [
        tar_entry(
          "#{PREFIX}/FIXTURE_TECNICA_UNREADABLE_FILE",
          "FIXTURE_TECNICA",
          mode: 0o244
        ),
        "owner-unreadable file"
      ],
      [
        tar_entry(
          "#{PREFIX}/FIXTURE_TECNICA_WRITABLE_DIRECTORY",
          "",
          mode: 0o777,
          type: "5"
        ),
        "world-writable directory"
      ],
      [
        tar_entry(
          "#{PREFIX}/FIXTURE_TECNICA_UNSEARCHABLE_DIRECTORY",
          "",
          mode: 0o455,
          type: "5"
        ),
        "owner-unsearchable directory"
      ]
    ]
    fixtures.each_with_index do |(entry, label), index|
      bytes = gzip_bytes(tar_bytes([entry, valid_entries.first]))
      with_tmpdir do |directory|
        archive = write_archive(
          directory,
          bytes,
          "FIXTURE_TECNICA_MODE_#{index}.crate"
        )
        assert_failure("mode is insecure or unsupported") do
          P13SourceFetch.run(
            extraction_arguments(
              archive,
              bytes,
              File.join(directory, "extracted")
            ),
            output: StringIO.new
          )
        end
        assert(
          !File.exist?(File.join(directory, "extracted")),
          "#{label} has no extraction output"
        )
      end
    end
  end

  def test_extract_rejects_bad_checksum_and_malformed_tar
    valid_tar = tar_bytes(valid_entries)
    bad_checksum_tar = valid_tar.dup
    bad_checksum_tar.setbyte(10, bad_checksum_tar.getbyte(10) ^ 1)
    bad_checksum = gzip_bytes(bad_checksum_tar)
    incomplete_end = gzip_bytes(tar_bytes(valid_entries, end_blocks: 1))
    truncated_entry = gzip_bytes(valid_tar.byteslice(0, 700))
    fixtures = [
      [bad_checksum, "checksum differs"],
      [incomplete_end, "complete end marker"],
      [truncated_entry, "truncated"]
    ]
    fixtures.each_with_index do |(bytes, message), index|
      with_tmpdir do |directory|
        archive = write_archive(
          directory,
          bytes,
          "FIXTURE_TECNICA_MALFORMED_#{index}.crate"
        )
        assert_failure(message) do
          P13SourceFetch.run(
            extraction_arguments(
              archive,
              bytes,
              File.join(directory, "extracted")
            ),
            output: StringIO.new
          )
        end
      end
    end
  end

  def test_extract_rejects_truncated_gzip
    bytes = valid_crate
    truncated = bytes.byteslice(0, bytes.bytesize - 4)
    with_tmpdir do |directory|
      archive = write_archive(directory, truncated)
      assert_failure("gzip is malformed or truncated") do
        P13SourceFetch.run(
          extraction_arguments(
            archive,
            truncated,
            File.join(directory, "extracted")
          ),
          output: StringIO.new
        )
      end
    end
  end

  def test_extract_rejects_concatenated_gzip
    bytes = valid_crate + gzip_bytes(
      tar_bytes(
        [
          tar_entry(
            "#{PREFIX}/FIXTURE_TECNICA_SECOND",
            "FIXTURE_TECNICA_SECOND"
          )
        ]
      )
    )
    with_tmpdir do |directory|
      archive = write_archive(directory, bytes)
      assert_failure("trailing or concatenated") do
        P13SourceFetch.run(
          extraction_arguments(
            archive,
            bytes,
            File.join(directory, "extracted")
          ),
          output: StringIO.new
        )
      end
    end
  end

  def run
    tests = public_methods(false).grep(/\Atest_/).sort
    tests.each { |test| public_send(test) }
    puts "P13_SOURCE_FETCH_TESTS_PASS"
  end
end

P13SourceFetchTest.run
