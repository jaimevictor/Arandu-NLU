# frozen_string_literal: true

require "digest"
require "fiddle"
require "net/http"
require "stringio"
require "uri"
require "zlib"

module P13SourceFetch
  class Failure < StandardError; end

  ALLOWED_HOSTS = %w[
    creativecommons.org
    static.crates.io
    static.rust-lang.org
  ].freeze
  COPY_BYTES = 64 * 1024
  MAX_FETCH_BYTES = 256 * 1024 * 1024
  MAX_ARCHIVE_BYTES = 128 * 1024 * 1024
  MAX_TAR_BYTES = 512 * 1024 * 1024
  MAX_TAR_ENTRIES = 100_000
  MAX_MANIFEST_ENTRIES = 16_384
  MAX_ARCHIVE_PATH_DEPTH = 64
  MAX_TAR_PATH_COMPONENTS = MAX_ARCHIVE_PATH_DEPTH
  TAR_BLOCK_BYTES = 512
  ZERO_TAR_BLOCK = ("\0" * TAR_BLOCK_BYTES).b.freeze
  DIRECTORY_OPEN_FLAG =
    case RUBY_PLATFORM
    when /darwin/
      0x0010_0000
    when /linux/
      0x0001_0000
    end
  TEMPORARY_NAME_ATTEMPTS = 32

  module_function

  def run(arguments, fetcher: nil, output: $stdout)
    if arguments.first == "extract-crate"
      run_extract(arguments.drop(1), output: output)
    else
      run_fetch(arguments, fetcher: fetcher, output: output)
    end
  rescue Failure
    raise
  rescue ArgumentError, URI::InvalidURIError => error
    raise Failure, "invalid acquisition argument: #{error.class}"
  rescue SystemCallError, IOError, Zlib::Error => error
    raise Failure, "source acquisition failed: #{error.class}"
  end

  def run_fetch(arguments, fetcher: nil, output: $stdout)
    raise Failure, usage unless arguments.length == 4

    url, expected_size_text, expected_sha256, destination = arguments
    expected_size = parse_expected_size(expected_size_text)
    raise Failure, "download exceeds acquisition limit" if
      expected_size > MAX_FETCH_BYTES
    validate_sha256(expected_sha256)
    uri = parse_source_uri(url)
    validate_absolute_path(destination, "destination")
    transfer = fetcher || method(:fetch)
    marker = with_secure_parent_descriptor(
      destination,
      create: true
    ) do |parent_directory, destination_name|
      existing = open_relative_file(
        parent_directory,
        destination_name,
        allow_missing: true
      )
      if existing
        begin
          verify_open_file(existing, expected_size, expected_sha256)
          assert_current_parent_identity(destination, parent_directory)
          verify_relative_file_identity(
            parent_directory,
            destination_name,
            existing
          )
        ensure
          existing.close
        end
        next "P13_SOURCE_ALREADY_EXACT"
      end

      temporary_name, file = create_relative_temporary_file(parent_directory)
      published = false
      completed = false
      begin
        digest = Digest::SHA256.new
        size = 0
        transfer.call(uri) do |chunk|
          raise Failure, "download chunk is not bytes" unless chunk.is_a?(String)

          bytes = chunk.b
          size += bytes.bytesize
          raise Failure, "download exceeds expected size" if
            size > expected_size

          digest.update(bytes)
          write_all(file, bytes)
        end
        raise Failure, "download size differs" unless size == expected_size
        raise Failure, "download SHA-256 differs" unless
          digest.hexdigest == expected_sha256

        file.flush
        file.fsync
        file.chmod(0o444)
        file.fsync
        verify_relative_file_identity(parent_directory, temporary_name, file)
        assert_current_parent_identity(destination, parent_directory)

        atomic_publish_file(
          temporary_name,
          destination_name,
          parent_directory
        )
        published = true
        temporary_name = nil

        acquired = open_relative_file(
          parent_directory,
          destination_name,
          allow_missing: false
        )
        begin
          raise Failure, "published source identity differs" unless
            same_file_identity?(file.stat, acquired.stat)
          verify_open_file(acquired, expected_size, expected_sha256)
        ensure
          acquired.close
        end
        assert_current_parent_identity(destination, parent_directory)
        verify_relative_file_identity(parent_directory, destination_name, file)
        completed = true
      ensure
        begin
          if temporary_name
            quarantine_relative_file_for_cleanup(
              parent_directory,
              temporary_name,
              file
            )
          elsif published && !completed
            quarantine_relative_file_for_cleanup(
              parent_directory,
              destination_name,
              file
            )
          end
        ensure
          file.close unless file.closed?
        end
      end
      "P13_SOURCE_FETCH_PASS"
    end
    output.puts marker
    true
  rescue Errno::EEXIST
    raise Failure, "destination appeared during acquisition"
  end

  def run_extract(arguments, output: $stdout)
    raise Failure, extract_usage unless arguments.length == 5

    archive, expected_size_text, expected_sha256, package_prefix, destination =
      arguments
    expected_size = parse_expected_size(expected_size_text)
    validate_sha256(expected_sha256)
    validate_package_prefix(package_prefix)
    validate_absolute_path(archive, "crate archive")
    validate_absolute_path(destination, "destination")
    secure_parent_directory(archive, create: false)
    raise Failure, "crate archive exceeds replay limit" if
      expected_size > MAX_ARCHIVE_BYTES
    archive_bytes = read_exact_file(
      archive,
      expected_size,
      expected_sha256,
      collect: true
    )

    manifest = parse_crate_archive(archive_bytes, package_prefix)
    marker = with_secure_parent_descriptor(
      destination,
      create: true
    ) do |parent_directory, destination_name|
      lock_directory_descriptor(parent_directory) do
        existing = open_extracted_directory(
          parent_directory,
          destination_name,
          allow_missing: true
        )
        if existing
          begin
            verify_tree(existing, manifest)
            verify_relative_directory_identity(
              parent_directory,
              destination_name,
              existing
            )
            assert_current_parent_identity(destination, parent_directory)
            verify_relative_directory_identity(
              parent_directory,
              destination_name,
              existing
            )
          ensure
            existing.close
          end
          next "P13_CRATE_ALREADY_EXACT"
        end

        staging_name, staging = create_relative_staging_directory(
          parent_directory
        )
        published = false
        completed = false
        acquired = nil
        begin
          materialize_manifest(staging, manifest)
          verify_tree(staging, manifest)
          verify_relative_directory_identity(
            parent_directory,
            staging_name,
            staging
          )
          assert_current_parent_identity(destination, parent_directory)

          staging_path = File.join(File.dirname(destination), staging_name)
          atomic_publish_directory(
            staging_path,
            destination,
            parent_directory
          )
          published = true
          staging_name = nil

          acquired = open_extracted_directory(
            parent_directory,
            destination_name,
            allow_missing: false
          )
          raise Failure, "published extraction identity differs" unless
            same_file_identity?(staging.stat, acquired.stat)
          verify_tree(acquired, manifest)
          verify_relative_directory_identity(
            parent_directory,
            destination_name,
            acquired
          )
          assert_current_parent_identity(destination, parent_directory)
          verify_relative_directory_identity(
            parent_directory,
            destination_name,
            staging
          )
          completed = true
        ensure
          acquired.close if acquired && !acquired.closed?
          begin
            if staging_name
              remove_staging_tree(parent_directory, staging_name, staging)
            elsif published && !completed
              remove_staging_tree(parent_directory, destination_name, staging)
            end
          ensure
            staging.close unless staging.closed?
          end
        end
        "P13_CRATE_EXTRACT_PASS"
      end
    end
    output.puts marker
    true
  end

  def parse_expected_size(text)
    size = Integer(text, 10)
    raise Failure, "expected size must be positive" unless size.positive?

    size
  end

  def validate_sha256(value)
    raise Failure, "expected SHA-256 is malformed" unless
      value.is_a?(String) && value.match?(/\A[0-9a-f]{64}\z/)

    true
  end

  def parse_source_uri(url)
    uri = URI.parse(url)
    raise Failure, "source URL must use HTTPS" unless
      uri.is_a?(URI::HTTPS) && uri.userinfo.nil? && uri.fragment.nil?
    raise Failure, "source host is not admitted" unless
      ALLOWED_HOSTS.include?(uri.host)

    uri
  end

  def fetch(uri)
    request = Net::HTTP::Get.new(uri.request_uri)
    request["Accept"] = "application/octet-stream"
    request["User-Agent"] = "NLU-P13-source-acquisition/1"
    Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: true,
      open_timeout: 30,
      read_timeout: 120
    ) do |http|
      http.request(request) do |response|
        raise Failure, "redirects are prohibited" if
          response.is_a?(Net::HTTPRedirection)
        raise Failure, "HTTPS response is not successful: #{response.code}" unless
          response.is_a?(Net::HTTPSuccess)
        response.read_body { |chunk| yield chunk }
      end
    end
    true
  end

  def validate_absolute_path(path, label)
    raise Failure, "#{label} must be absolute" unless
      path.is_a?(String) && path.start_with?("/")
    raise Failure, "#{label} contains an unsafe path component" if
      path.include?("\0") || path.bytes.any? { |byte| byte < 32 || byte == 127 }

    components = path.split("/", -1)
    raise Failure, "#{label} contains an unsafe path component" unless
      components.shift == "" &&
      !components.empty? &&
      components.none? { |part| part.empty? || part == "." || part == ".." }

    components
  end

  def secure_parent_directory(path, create:)
    components = validate_absolute_path(path, "path")
    parent_components = components[0...-1]
    current = "/"
    validate_directory_stat(File.lstat(current), current)
    parent_components.each do |component|
      current = current == "/" ? "/#{component}" : File.join(current, component)
      created = false
      begin
        stat = File.lstat(current)
      rescue Errno::ENOENT
        raise Failure, "required parent directory is missing" unless create

        begin
          Dir.mkdir(current, 0o700)
          created = true
        rescue Errno::EEXIST
          created = false
        end
        stat = File.lstat(current)
      end
      validate_directory_stat(stat, current)
      if created
        File.chmod(0o700, current)
        stat = File.lstat(current)
        validate_directory_stat(stat, current)
        raise Failure, "created parent directory mode differs" unless
          (stat.mode & 0o7777) == 0o700
      end
    end
    current
  end

  def with_secure_parent_descriptor(path, create:)
    components = validate_absolute_path(path, "path")
    destination_name = components.pop
    raise Failure, "descriptor-relative directory access is unavailable" unless
      DIRECTORY_OPEN_FLAG

    current_path = "/"
    directory = File.open("/", File::RDONLY | File::NOFOLLOW)
    directory.close_on_exec = true
    validate_directory_stat(directory.stat, current_path)
    components.each do |component|
      current_path =
        current_path == "/" ? "/#{component}" : File.join(current_path, component)
      created = false
      begin
        begin
          child = open_directory_at(directory, component)
        rescue Errno::ENOENT
          raise Failure, "required parent directory is missing" unless create

          begin
            mkdir_at(directory, component, 0o700)
            created = true
          rescue Errno::EEXIST
            created = false
          end
          child = open_directory_at(directory, component)
        end
      rescue Errno::ELOOP, Errno::ENOTDIR
        raise Failure, "path component is not a directory: #{current_path}"
      end

      begin
        validate_directory_stat(child.stat, current_path)
        if created
          child.chmod(0o700)
          stat = child.stat
          validate_directory_stat(stat, current_path)
          raise Failure, "created parent directory mode differs" unless
            (stat.mode & 0o7777) == 0o700
        end
      rescue StandardError
        child.close
        raise
      end
      directory.close
      directory = child
    end

    yield directory, destination_name
  ensure
    directory.close if directory && !directory.closed?
  end

  def open_directory_at(parent, name)
    flags = File::RDONLY | File::NOFOLLOW | DIRECTORY_OPEN_FLAG
    open_at(parent, name, flags, 0)
  end

  def open_extracted_directory(parent, name, allow_missing:)
    directory = open_directory_at(parent, name)
    begin
      validate_extracted_stat(directory.stat, :directory)
    rescue StandardError
      directory.close
      raise
    end
    directory
  rescue Errno::ENOENT
    raise unless allow_missing

    nil
  rescue Errno::ELOOP, Errno::ENOTDIR
    raise Failure, "extracted tree contains an unsupported entry"
  end

  def create_relative_staging_directory(parent)
    TEMPORARY_NAME_ATTEMPTS.times do
      name = ".p13-crate-stage-#{Random.urandom(16).unpack1('H*')}"
      begin
        mkdir_at(parent, name, 0o700)
      rescue Errno::EEXIST
        next
      end

      directory = nil
      begin
        directory = open_directory_at(parent, name)
        verify_private_staging_directory(directory)
        verify_relative_directory_identity(parent, name, directory)
        return [name, directory]
      rescue StandardError
        begin
          remove_staging_tree(parent, name, directory) if directory
        ensure
          directory.close if directory && !directory.closed?
        end
        raise
      end
    end
    raise Failure, "cannot allocate private extraction directory"
  end

  def verify_relative_directory_identity(parent, name, expected)
    acquired = open_extracted_directory(parent, name, allow_missing: false)
    begin
      raise Failure, "extraction directory identity changed" unless
        same_file_identity?(expected.stat, acquired.stat)
    ensure
      acquired.close
    end
    true
  end

  def lock_directory_descriptor(directory)
    raise Failure, "cannot lock destination parent" unless
      directory.flock(File::LOCK_EX)
    yield
  ensure
    directory.flock(File::LOCK_UN) if directory
  end

  def with_relative_directory(root, relative)
    directory = root.dup
    directory.close_on_exec = true
    unless relative.empty?
      relative.split("/").each do |component|
        child = open_directory_at(directory, component)
        begin
          validate_extracted_stat(child.stat, :directory)
        rescue StandardError
          child.close
          raise
        end
        directory.close
        directory = child
      end
    end

    yield directory
  ensure
    directory.close if directory && !directory.closed?
  end

  def open_relative_file(parent, name, allow_missing:)
    flags = File::RDONLY | File::BINARY | File::NOFOLLOW | File::NONBLOCK
    open_at(parent, name, flags, 0)
  rescue Errno::ENOENT
    raise unless allow_missing

    nil
  rescue Errno::ELOOP
    raise Failure, "source path is a symlink"
  end

  def create_relative_temporary_file(parent)
    TEMPORARY_NAME_ATTEMPTS.times do
      name = ".p13-source-#{Random.urandom(16).unpack1('H*')}.part"
      flags = File::WRONLY | File::CREAT | File::EXCL | File::BINARY |
        File::NOFOLLOW
      begin
        file = open_at(parent, name, flags, 0o600)
        file.chmod(0o600)
        return [name, file]
      rescue Errno::EEXIST
        next
      end
    end
    raise Failure, "cannot allocate private acquisition file"
  end

  def verify_relative_file_identity(parent, name, expected)
    acquired = open_relative_file(parent, name, allow_missing: false)
    begin
      validate_source_file_stat(acquired.stat)
      raise Failure, "source name identity changed" unless
        same_file_identity?(expected.stat, acquired.stat)
    ensure
      acquired.close
    end
    true
  end

  def quarantine_relative_file_for_cleanup(parent, name, expected)
    return true unless name

    quarantined = quarantine_cleanup_entry(
      parent,
      name,
      expected,
      directory: false,
      context: "cleanup source identity changed"
    )
    return true unless quarantined

    _quarantine_name, current = quarantined
    current.close
    true
  end

  def quarantine_cleanup_entry(parent, name, expected, directory:, context:)
    quarantine_name = quarantine_relative_name(parent, name)
    return nil unless quarantine_name

    current = nil
    begin
      current =
        if directory
          open_directory_at(parent, quarantine_name)
        else
          open_cleanup_file(parent, quarantine_name)
        end
      validate_extracted_stat(current.stat, :directory) if directory
      raise Failure, context unless
        expected && same_file_identity?(expected.stat, current.stat)
      [quarantine_name, current]
    rescue StandardError
      current.close if current && !current.closed?
      raise
    end
  rescue Errno::ELOOP, Errno::ENOTDIR, Errno::EISDIR
    raise Failure, context
  end

  def quarantine_relative_name(parent, name)
    TEMPORARY_NAME_ATTEMPTS.times do
      quarantine_name =
        ".p13-cleanup-#{Random.urandom(16).unpack1('H*')}.quarantine"
      begin
        exclusive_rename_at(
          parent,
          name,
          quarantine_name,
          "cleanup quarantine"
        )
        return quarantine_name
      rescue Failure => error
        raise unless
          error.message == "destination appeared during cleanup quarantine"
      rescue SystemCallError => error
        return nil if error.errno == Errno::ENOENT::Errno

        raise
      end
    end
    raise Failure, "cannot allocate cleanup quarantine name"
  end

  def assert_current_parent_identity(path, expected)
    with_secure_parent_descriptor(path, create: false) do |current, _name|
      validate_directory_stat(expected.stat, File.dirname(path))
      raise Failure, "destination parent identity changed" unless
        same_directory_identity?(expected.stat, current.stat)
    end
    true
  end

  def same_directory_identity?(left, right)
    left.dev == right.dev && left.ino == right.ino
  end

  def open_at(parent, name, flags, mode)
    function = native_function(
      "openat",
      [
        Fiddle::TYPE_INT,
        Fiddle::TYPE_VOIDP,
        Fiddle::TYPE_INT,
        Fiddle::TYPE_INT
      ]
    )
    descriptor = function.call(parent.fileno, name, flags, mode)
    raise_native_error("descriptor-relative open failed") if descriptor == -1

    io = File.new(descriptor, autoclose: true)
    io.binmode
    io.close_on_exec = true
    io
  end

  def mkdir_at(parent, name, mode)
    function = native_function(
      "mkdirat",
      [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT]
    )
    result = function.call(parent.fileno, name, mode)
    raise_native_error("descriptor-relative mkdir failed") if result == -1

    true
  end

  def native_function(name, arguments, return_type = Fiddle::TYPE_INT)
    @native_handle ||= Fiddle.dlopen(nil)
    @native_functions ||= {}
    key = [name, arguments, return_type]
    @native_functions[key] ||= Fiddle::Function.new(
      @native_handle[name],
      arguments,
      return_type
    )
  rescue Fiddle::DLError
    raise Failure, "required descriptor-relative operation is unavailable"
  end

  def raise_native_error(label)
    raise SystemCallError.new(label, Fiddle.last_error)
  end

  def directory_entry_names(
    directory,
    maximum_entries: MAX_MANIFEST_ENTRIES,
    overflow_message: "extracted tree entry limit exceeded"
  )
    raise Failure, "directory enumeration limit is malformed" unless
      maximum_entries.is_a?(Integer) && maximum_entries >= 0

    duplicate_function = native_function("dup", [Fiddle::TYPE_INT])
    duplicate = duplicate_function.call(directory.fileno)
    raise_native_error("directory descriptor duplication failed") if
      duplicate == -1

    fdopendir = native_function(
      "fdopendir",
      [Fiddle::TYPE_INT],
      Fiddle::TYPE_VOIDP
    )
    stream = fdopendir.call(duplicate)
    if !stream || stream.to_i.zero?
      error_number = Fiddle.last_error
      File.new(duplicate, autoclose: true).close
      raise SystemCallError.new("descriptor directory open failed", error_number)
    end

    readdir = native_function(
      "readdir",
      [Fiddle::TYPE_VOIDP],
      Fiddle::TYPE_VOIDP
    )
    closedir = native_function("closedir", [Fiddle::TYPE_VOIDP])
    errno_pointer = native_errno_pointer
    names = []
    begin
      loop do
        errno_pointer[0, Fiddle::SIZEOF_INT] = [0].pack("i")
        entry = readdir.call(stream)
        if !entry || entry.to_i.zero?
          error_number = errno_pointer[0, Fiddle::SIZEOF_INT].unpack1("i")
          unless error_number.zero?
            raise SystemCallError.new(
              "directory enumeration failed",
              error_number
            )
          end
          break
        end

        name = directory_entry_name(entry)
        next if name == "." || name == ".."

        raise Failure, overflow_message if names.length >= maximum_entries

        names << name
      end
    ensure
      active_error = $!
      result = closedir.call(stream)
      if result == -1 && !active_error
        raise_native_error("directory stream close failed")
      end
    end
    names
  end

  def directory_entry_name(entry)
    record_length = entry[16, 2].unpack1("S")
    if RUBY_PLATFORM.match?(/darwin/)
      name_offset = 21
      name_length = entry[18, 2].unpack1("S")
      valid = record_length >= name_offset &&
        name_length <= record_length - name_offset
      raise Failure, "directory entry record is malformed" unless valid

      name = entry[name_offset, name_length]
    elsif RUBY_PLATFORM.match?(/linux/)
      name_offset = 19
      raise Failure, "directory entry record is malformed" unless
        record_length > name_offset

      field = entry[name_offset, record_length - name_offset]
      terminator = field.index("\0")
      raise Failure, "directory entry record is malformed" unless terminator

      name = field.byteslice(0, terminator)
    else
      raise Failure, "directory entry layout is unavailable"
    end
    raise Failure, "directory entry name is malformed" if
      name.empty? || name.include?("/") || name.include?("\0")

    name
  end

  def native_errno_pointer
    symbol =
      if RUBY_PLATFORM.match?(/darwin/)
        "__error"
      elsif RUBY_PLATFORM.match?(/linux/)
        "__errno_location"
      else
        raise Failure, "native errno access is unavailable"
      end
    function = native_function(
      symbol,
      [],
      Fiddle::TYPE_VOIDP
    )
    pointer = function.call
    raise Failure, "native errno access failed" if
      !pointer || pointer.to_i.zero?

    pointer
  end

  def validate_directory_stat(stat, path)
    raise Failure, "path component is not a directory: #{path}" unless
      stat.directory? && !stat.symlink?
    raise Failure, "path component has an untrusted owner: #{path}" unless
      stat.uid == Process.euid || stat.uid.zero?

    writable = (stat.mode & 0o022) != 0
    sticky_root = stat.uid.zero? && (stat.mode & 0o1000) != 0
    raise Failure, "path component is insecurely writable: #{path}" if
      writable && !sticky_root

    true
  end

  def path_exists?(path)
    File.lstat(path)
    true
  rescue Errno::ENOENT
    false
  end

  def verify_file(path, expected_size, expected_sha256)
    read_exact_file(path, expected_size, expected_sha256, collect: false)
    true
  end

  def verify_open_file(file, expected_size, expected_sha256)
    before = file.stat
    validate_source_file_stat(before)
    raise Failure, "destination size differs" unless before.size == expected_size

    digest = Digest::SHA256.new
    size = 0
    file.rewind
    while (chunk = file.read(COPY_BYTES))
      size += chunk.bytesize
      raise Failure, "destination size differs" if size > expected_size

      digest.update(chunk)
    end
    after = file.stat
    raise Failure, "source identity changed during verification" unless
      same_file_identity?(before, after)
    raise Failure, "destination size differs" unless size == expected_size
    raise Failure, "destination SHA-256 differs" unless
      digest.hexdigest == expected_sha256

    true
  end

  def read_exact_file(path, expected_size, expected_sha256, collect:)
    secure_parent_directory(path, create: false)
    before = File.lstat(path)
    validate_source_file_stat(before)
    raise Failure, "destination size differs" unless before.size == expected_size

    contents = collect ? String.new(encoding: Encoding::BINARY) : nil
    digest = Digest::SHA256.new
    size = 0
    flags = File::RDONLY | File::BINARY | File::NOFOLLOW | File::NONBLOCK
    File.open(path, flags) do |file|
      opened = file.stat
      raise Failure, "source identity changed before verification" unless
        same_file_identity?(before, opened)
      while (chunk = file.read(COPY_BYTES))
        size += chunk.bytesize
        raise Failure, "destination size differs" if size > expected_size

        digest.update(chunk)
        contents << chunk if collect
      end
      after = file.stat
      raise Failure, "source identity changed during verification" unless
        same_file_identity?(opened, after)
    end
    raise Failure, "destination size differs" unless size == expected_size
    raise Failure, "destination SHA-256 differs" unless
      digest.hexdigest == expected_sha256

    contents
  rescue Errno::ELOOP
    raise Failure, "source path is a symlink"
  end

  def validate_source_file_stat(stat)
    raise Failure, "destination is missing or not a regular file" unless
      stat.file? && !stat.symlink?
    raise Failure, "destination has an untrusted owner" unless
      stat.uid == Process.euid
    raise Failure, "destination file mode is insecure" unless
      (stat.mode & 0o7022).zero?
    raise Failure, "destination has multiple hard links" unless stat.nlink == 1

    true
  end

  def same_file_identity?(left, right)
    %i[dev ino mode uid gid nlink size].all? do |field|
      left.public_send(field) == right.public_send(field)
    end &&
      left.mtime.to_i == right.mtime.to_i &&
      left.mtime.nsec == right.mtime.nsec &&
      left.ctime.to_i == right.ctime.to_i &&
      left.ctime.nsec == right.ctime.nsec
  end

  def validate_package_prefix(prefix)
    raise Failure, "package prefix is malformed" unless
      prefix.is_a?(String) &&
      prefix.ascii_only? &&
      prefix.bytesize <= 100 &&
      prefix.match?(/\A[A-Za-z0-9][A-Za-z0-9._+-]*\z/) &&
      prefix != "." &&
      prefix != ".."

    true
  end

  def parse_crate_archive(archive_bytes, package_prefix)
    tar_bytes = decompress_gzip(archive_bytes)
    parse_tar(tar_bytes, package_prefix)
  end

  def decompress_gzip(archive_bytes)
    input = StringIO.new(archive_bytes)
    reader = Zlib::GzipReader.new(input)
    tar_bytes = String.new(encoding: Encoding::BINARY)
    while (chunk = reader.read(COPY_BYTES))
      tar_bytes << chunk
      raise Failure, "crate tar exceeds replay limit" if
        tar_bytes.bytesize > MAX_TAR_BYTES
    end
    buffered_trailing = reader.unused || "".b
    reader.finish
    unread_trailing = input.read || "".b
    raise Failure, "crate gzip has trailing or concatenated bytes" unless
      buffered_trailing.empty? && unread_trailing.empty?

    tar_bytes
  rescue Zlib::GzipFile::Error, Zlib::DataError, Zlib::BufError
    raise Failure, "crate gzip is malformed or truncated"
  ensure
    begin
      reader.close if reader && !reader.closed?
    rescue IOError
      nil
    end
  end

  def parse_tar(tar_bytes, package_prefix)
    raise Failure, "crate tar is truncated" unless
      (tar_bytes.bytesize % TAR_BLOCK_BYTES).zero?

    manifest = {
      "root_mode" => 0o755,
      "entries" => {},
      "seen_headers" => {},
      "aliases" => {},
      "file_count" => 0
    }
    offset = 0
    zero_blocks = 0
    headers = 0
    while offset < tar_bytes.bytesize
      header = tar_bytes.byteslice(offset, TAR_BLOCK_BYTES)
      offset += TAR_BLOCK_BYTES
      if header == ZERO_TAR_BLOCK
        zero_blocks += 1
        if zero_blocks >= 2
          trailing = tar_bytes.byteslice(offset, tar_bytes.bytesize - offset)
          raise Failure, "crate tar has nonzero trailing bytes" unless
            trailing.bytes.all?(&:zero?)
          break
        end
        next
      end
      raise Failure, "crate tar has an incomplete end marker" if zero_blocks == 1

      headers += 1
      raise Failure, "crate tar has too many entries" if headers > MAX_TAR_ENTRIES
      entry = parse_tar_header(header)
      padded_size = round_tar_size(entry.fetch("size"))
      raise Failure, "crate tar entry is truncated" if
        offset + padded_size > tar_bytes.bytesize
      contents = tar_bytes.byteslice(offset, entry.fetch("size"))
      padding = tar_bytes.byteslice(
        offset + entry.fetch("size"),
        padded_size - entry.fetch("size")
      )
      raise Failure, "crate tar entry padding is malformed" unless
        padding.bytes.all?(&:zero?)
      offset += padded_size
      add_tar_entry(manifest, entry, contents, package_prefix)
    end
    raise Failure, "crate tar lacks a complete end marker" if zero_blocks < 2
    raise Failure, "crate tar contains no regular files" if
      manifest.fetch("file_count").zero?

    add_cargo_marker(manifest)
    manifest.delete("seen_headers")
    manifest.delete("aliases")
    manifest.delete("file_count")
    manifest
  end

  def add_cargo_marker(manifest)
    marker = ".cargo-ok"
    register_path_alias(manifest, marker)
    raise Failure, "crate tar contains reserved Cargo marker" if
      manifest.fetch("entries").key?(marker)

    store_manifest_entry(manifest, marker, {
      "type" => :file,
      "mode" => 0o644,
      "contents" => "{\"v\":1}".b
    })
    true
  end

  def parse_tar_header(header)
    stored_checksum = parse_tar_octal(
      header.byteslice(148, 8),
      "tar checksum"
    )
    checksum_header = header.dup
    checksum_header[148, 8] = " " * 8
    raise Failure, "crate tar checksum differs" unless
      checksum_header.bytes.sum == stored_checksum

    magic = header.byteslice(257, 6)
    version = header.byteslice(263, 2)
    valid_ustar =
      (magic == "ustar\0".b && version == "00".b) ||
      (magic == "ustar ".b && version == " \0".b)
    raise Failure, "crate tar format is unsupported" unless valid_ustar

    name = parse_tar_string(header.byteslice(0, 100), "tar name")
    prefix = parse_tar_string(
      header.byteslice(345, 155),
      "tar path prefix",
      allow_empty: true
    )
    full_name = prefix.empty? ? name : "#{prefix}/#{name}"
    mode = parse_tar_octal(header.byteslice(100, 8), "tar mode")
    parse_tar_octal(header.byteslice(108, 8), "tar uid")
    parse_tar_octal(header.byteslice(116, 8), "tar gid")
    size = parse_tar_octal(header.byteslice(124, 12), "tar size")
    parse_tar_octal(header.byteslice(136, 12), "tar mtime")
    typeflag = header.byteslice(156, 1)
    linkname = parse_tar_string(
      header.byteslice(157, 100),
      "tar link name",
      allow_empty: true
    )
    type =
      case typeflag
      when "\0".b, "0".b
        :file
      when "5".b
        :directory
      when "1".b, "2".b
        raise Failure, "crate tar links are prohibited"
      else
        raise Failure, "crate tar entry type is unsupported"
      end
    raise Failure, "crate tar link name is prohibited" unless linkname.empty?
    raise Failure, "crate tar directory has content" if
      type == :directory && !size.zero?
    validate_archive_mode(mode, type)

    {
      "path" => full_name,
      "mode" => mode,
      "size" => size,
      "type" => type
    }
  end

  def parse_tar_string(field, label, allow_empty: false)
    nul = field.index("\0")
    if nul
      tail = field.byteslice(nul, field.bytesize - nul)
      raise Failure, "#{label} has nonzero bytes after terminator" unless
        tail.bytes.all?(&:zero?)
      value = field.byteslice(0, nul)
    else
      value = field
    end
    raise Failure, "#{label} is empty" if value.empty? && !allow_empty

    value
  end

  def parse_tar_octal(field, label)
    match = /\A *([0-7]*)[\0 ]*\z/n.match(field)
    raise Failure, "#{label} is malformed" unless match

    match[1].empty? ? 0 : Integer(match[1], 8)
  end

  def validate_archive_mode(mode, type)
    raise Failure, "crate tar mode is insecure or unsupported" unless
      mode <= 0o777 &&
      (mode & 0o022).zero? &&
      (type != :directory || (mode & 0o500) == 0o500) &&
      (type != :file || (mode & 0o400) == 0o400)

    true
  end

  def round_tar_size(size)
    ((size + TAR_BLOCK_BYTES - 1) / TAR_BLOCK_BYTES) * TAR_BLOCK_BYTES
  end

  def add_tar_entry(manifest, entry, contents, package_prefix)
    raw_path = entry.fetch("path")
    if raw_path.end_with?("/")
      raise Failure, "regular tar path has a trailing slash" unless
        entry.fetch("type") == :directory
      raw_path = raw_path.byteslice(0, raw_path.bytesize - 1)
    end
    validate_archive_path(raw_path)
    unless raw_path == package_prefix ||
           raw_path.start_with?("#{package_prefix}/")
      raise Failure, "crate tar package prefix differs"
    end
    raise Failure, "crate tar contains a duplicate path" if
      manifest.fetch("seen_headers").key?(raw_path)
    manifest.fetch("seen_headers")[raw_path] = true

    if raw_path == package_prefix
      raise Failure, "crate package root is not a directory" unless
        entry.fetch("type") == :directory
      manifest["root_mode"] = entry.fetch("mode")
      return
    end

    relative = raw_path.byteslice(package_prefix.bytesize + 1, raw_path.bytesize)
    validate_archive_path(relative)
    register_path_alias(manifest, relative)
    ensure_manifest_parents(manifest, relative)
    entries = manifest.fetch("entries")
    existing = entries[relative]
    if existing
      unless existing.fetch("type") == :directory &&
             entry.fetch("type") == :directory &&
             !existing.fetch("explicit")
        raise Failure, "crate tar path conflicts with another entry"
      end
    end

    if entry.fetch("type") == :directory
      store_manifest_entry(manifest, relative, {
        "type" => :directory,
        "mode" => entry.fetch("mode"),
        "explicit" => true
      })
    else
      store_manifest_entry(manifest, relative, {
        "type" => :file,
        "mode" => entry.fetch("mode"),
        "contents" => contents
      })
      manifest["file_count"] += 1
    end
  end

  def validate_archive_path(path)
    raise Failure, "crate tar path is unsafe" unless
      path.is_a?(String) &&
      !path.empty? &&
      path.ascii_only? &&
      !path.start_with?("/") &&
      !path.include?("\\") &&
      !path.bytes.any? { |byte| byte < 32 || byte == 127 }
    components = path.split("/", -1)
    raise Failure, "crate tar path is too deeply nested" if
      components.length > MAX_ARCHIVE_PATH_DEPTH
    raise Failure, "crate tar path is unsafe" if
      components.any? do |part|
        part.empty? || part == "." || part == ".." || part.bytesize > 255
      end

    true
  end

  def register_path_alias(manifest, path)
    folded = path.downcase
    previous = manifest.fetch("aliases")[folded]
    raise Failure, "crate tar paths collide on a case-insensitive filesystem" if
      previous && previous != path
    manifest.fetch("aliases")[folded] = path
  end

  def ensure_manifest_parents(manifest, relative)
    parts = relative.split("/")
    entries = manifest.fetch("entries")
    1.upto(parts.length - 1) do |length|
      parent = parts.first(length).join("/")
      register_path_alias(manifest, parent)
      existing = entries[parent]
      raise Failure, "crate tar path descends through a file" if
        existing && existing.fetch("type") != :directory
      next if existing

      store_manifest_entry(manifest, parent, {
        "type" => :directory,
        "mode" => 0o755,
        "explicit" => false
      })
    end
  end

  def store_manifest_entry(manifest, path, entry)
    entries = manifest.fetch("entries")
    if !entries.key?(path) && entries.length >= MAX_MANIFEST_ENTRIES
      raise Failure, "crate tar derived entry limit exceeded"
    end

    entries[path] = entry
  end

  def with_directory_lock(path)
    before = File.lstat(path)
    validate_directory_stat(before, path)
    File.open(path, File::RDONLY | File::NOFOLLOW) do |directory|
      raise Failure, "destination parent identity changed" unless
        same_file_identity?(before, directory.stat)
      raise Failure, "cannot lock destination parent" unless
        directory.flock(File::LOCK_EX)
      yield directory
    ensure
      directory.flock(File::LOCK_UN) if directory
    end
  end

  def atomic_publish_directory(source, destination, parent_directory)
    raise Failure, "staging and destination parents differ" unless
      File.dirname(source) == File.dirname(destination)

    exclusive_rename_at(
      parent_directory,
      File.basename(source),
      File.basename(destination),
      "extraction"
    )
  end

  def atomic_publish_file(source_name, destination_name, parent_directory)
    exclusive_rename_at(
      parent_directory,
      source_name,
      destination_name,
      "acquisition"
    )
  end

  def exclusive_rename_at(
    parent_directory,
    source_name,
    destination_name,
    operation
  )
    function, exclusive_flag = exclusive_rename_function
    result = function.call(
      parent_directory.fileno,
      source_name,
      parent_directory.fileno,
      destination_name,
      exclusive_flag
    )
    return true if result.zero?

    error_number = Fiddle.last_error
    raise Failure, "destination appeared during #{operation}" if
      error_number == Errno::EEXIST::Errno ||
      error_number == Errno::ENOTEMPTY::Errno
    raise SystemCallError.new(
      "exclusive #{operation} publication failed",
      error_number
    )
  end

  def exclusive_rename_function
    handle = Fiddle.dlopen(nil)
    arguments = [
      Fiddle::TYPE_INT,
      Fiddle::TYPE_VOIDP,
      Fiddle::TYPE_INT,
      Fiddle::TYPE_VOIDP,
      Fiddle::TYPE_INT
    ]
    begin
      address = handle["renameatx_np"]
      return [
        Fiddle::Function.new(address, arguments, Fiddle::TYPE_INT),
        0x00000004
      ]
    rescue Fiddle::DLError
      nil
    end
    begin
      address = handle["renameat2"]
      return [
        Fiddle::Function.new(address, arguments, Fiddle::TYPE_INT),
        0x00000001
      ]
    rescue Fiddle::DLError
      raise Failure, "atomic no-clobber directory publication is unavailable"
    end
  end

  def verify_private_staging_directory(directory)
    stat = directory.stat
    raise Failure, "staging path is not a private owned directory" unless
      stat.directory? &&
      !stat.symlink? &&
      stat.uid == Process.euid &&
      (stat.mode & 0o7777) == 0o700

    true
  end

  def materialize_manifest(root, manifest)
    directories = manifest.fetch("entries").select do |_path, entry|
      entry.fetch("type") == :directory
    end
    directories.keys.sort_by { |path| [path.count("/"), path.b] }.each do |path|
      parent_path, name = split_relative_path(path)
      with_relative_directory(root, parent_path) do |parent|
        mkdir_at(parent, name, 0o700)
        created = open_directory_at(parent, name)
        begin
          stat = created.stat
          validate_extracted_stat(stat, :directory)
          raise Failure, "created extraction directory mode differs" unless
            (stat.mode & 0o7777) == 0o700
        ensure
          created.close
        end
      end
    end

    files = manifest.fetch("entries").select do |_path, entry|
      entry.fetch("type") == :file
    end
    files.keys.sort_by(&:b).each do |path|
      entry = files.fetch(path)
      parent_path, name = split_relative_path(path)
      with_relative_directory(root, parent_path) do |parent|
        flags = File::WRONLY | File::CREAT | File::EXCL | File::BINARY |
          File::NOFOLLOW
        file = open_at(parent, name, flags, 0o600)
        begin
          write_all(file, entry.fetch("contents"))
          file.flush
          file.fsync
          file.chmod(entry.fetch("mode"))
          file.fsync
        ensure
          file.close
        end
      end
    end

    directories.keys.sort_by { |path| [-path.count("/"), path.b] }.each do |path|
      with_relative_directory(root, path) do |directory|
        directory.chmod(directories.fetch(path).fetch("mode"))
      end
    end
    root.chmod(manifest.fetch("root_mode"))
    true
  end

  def split_relative_path(path)
    components = path.split("/")
    [components[0...-1].join("/"), components.fetch(-1)]
  end

  def write_all(file, bytes)
    offset = 0
    while offset < bytes.bytesize
      written = file.write(bytes.byteslice(offset, bytes.bytesize - offset))
      raise Failure, "short filesystem write" unless written && written.positive?

      offset += written
    end
    true
  end

  def verify_tree(root, manifest)
    root_mode, expected = validate_verification_manifest(manifest)
    root_stat = root.stat
    validate_extracted_stat(root_stat, :directory)
    raise Failure, "extracted root mode differs" unless
      (root_stat.mode & 0o777) == root_mode

    state = {
      "entry_count" => 0,
      "file_bytes" => 0
    }
    verify_tree_entries(root, expected, "", state)
    raise Failure, "extracted tree paths differ" unless
      state.fetch("entry_count") == expected.length
    true
  rescue Errno::ENOENT
    raise Failure, "extracted destination is missing"
  end

  def validate_verification_manifest(manifest)
    raise Failure, "extracted manifest is malformed" unless
      manifest.is_a?(Hash) &&
      manifest["root_mode"].is_a?(Integer) &&
      manifest["entries"].is_a?(Hash)

    root_mode = manifest.fetch("root_mode")
    validate_archive_mode(root_mode, :directory)
    entries = manifest.fetch("entries")
    raise Failure, "extracted manifest entry limit exceeded" if
      entries.length > MAX_MANIFEST_ENTRIES

    aggregate_bytes = 0
    entries.each do |path, entry|
      validate_archive_path(path)
      raise Failure, "extracted manifest entry is malformed" unless
        entry.is_a?(Hash) &&
        %i[directory file].include?(entry["type"]) &&
        entry["mode"].is_a?(Integer)

      type = entry.fetch("type")
      validate_archive_mode(entry.fetch("mode"), type)
      next if type == :directory

      contents = entry["contents"]
      raise Failure, "extracted manifest file is malformed" unless
        contents.is_a?(String)
      raise Failure, "extracted manifest file exceeds replay limit" if
        contents.bytesize > MAX_TAR_BYTES

      aggregate_bytes += contents.bytesize
      raise Failure, "extracted manifest aggregate exceeds replay limit" if
        aggregate_bytes > MAX_TAR_BYTES
    end
    [root_mode, entries]
  end

  def verify_tree_entries(root, expected, relative_parent, state)
    before = root.stat
    remaining = MAX_MANIFEST_ENTRIES - state.fetch("entry_count")
    names = directory_entry_names(root, maximum_entries: remaining)
    state["entry_count"] += names.length
    names.sort_by(&:b).each do |name|
      relative = relative_parent.empty? ? name : "#{relative_parent}/#{name}"
      validate_archive_path(relative)
      wanted = expected[relative]
      raise Failure, "extracted tree paths differ" unless wanted

      if wanted.fetch("type") == :directory
        verify_tree_directory(root, name, relative, wanted, expected, state)
      else
        verify_tree_file(root, name, relative, wanted, state)
      end
    end
    raise Failure, "extracted directory identity changed" unless
      same_file_identity?(before, root.stat)
    true
  end

  def verify_tree_directory(parent, name, path, wanted, expected, state)
    child = open_directory_at(parent, name)
    begin
      stat = child.stat
      validate_extracted_stat(stat, :directory)
      raise Failure, "extracted entry mode differs: #{path}" unless
        (stat.mode & 0o777) == wanted.fetch("mode")
      verify_tree_entries(child, expected, path, state)
    ensure
      child.close
    end
    true
  rescue Errno::ENOTDIR
    raise Failure, "extracted entry type differs: #{path}"
  rescue Errno::ELOOP
    raise Failure, "extracted tree contains an unsupported entry"
  end

  def verify_tree_file(parent, name, path, wanted, state)
    file = open_tree_file(parent, name)
    begin
      before = file.stat
      raise Failure, "extracted entry type differs: #{path}" unless
        before.file? && !before.symlink?
      validate_extracted_stat(before, :file)
      raise Failure, "extracted entry mode differs: #{path}" unless
        (before.mode & 0o777) == wanted.fetch("mode")

      expected_contents = wanted.fetch("contents")
      expected_size = expected_contents.bytesize
      raise Failure, "extracted entry content differs: #{path}" unless
        before.size == expected_size

      state["file_bytes"] += expected_size
      raise Failure, "extracted tree aggregate exceeds replay limit" if
        state.fetch("file_bytes") > MAX_TAR_BYTES

      offset = 0
      file.rewind
      while (chunk = file.read(COPY_BYTES))
        offset += chunk.bytesize
        raise Failure, "extracted entry size differs: #{path}" if
          offset > expected_size
        expected_chunk = expected_contents.byteslice(
          offset - chunk.bytesize,
          chunk.bytesize
        )
        raise Failure, "extracted entry content differs: #{path}" unless
          chunk == expected_chunk
      end
      raise Failure, "extracted entry size differs: #{path}" unless
        offset == expected_size
      raise Failure, "extracted file identity changed" unless
        same_file_identity?(before, file.stat)
    ensure
      file.close
    end
    true
  rescue Errno::EISDIR
    raise Failure, "extracted entry type differs: #{path}"
  rescue Errno::ELOOP
    raise Failure, "extracted tree contains an unsupported entry"
  end

  def open_tree_file(parent, name)
    flags = File::RDONLY | File::BINARY | File::NOFOLLOW | File::NONBLOCK
    open_at(parent, name, flags, 0)
  rescue Errno::ELOOP
    raise Failure, "extracted tree contains an unsupported entry"
  end

  def validate_extracted_stat(stat, type)
    valid_type =
      (type == :directory && stat.directory? && !stat.symlink?) ||
      (type == :file && stat.file? && !stat.symlink?)
    raise Failure, "extracted tree contains an unsupported entry" unless valid_type
    raise Failure, "extracted tree has an untrusted owner" unless
      stat.uid == Process.euid
    raise Failure, "extracted tree contains an insecure mode" unless
      (stat.mode & 0o7022).zero?
    raise Failure, "extracted file has multiple hard links" if
      type == :file && stat.nlink != 1

    true
  end

  def remove_staging_tree(parent, name, expected)
    return unless name

    quarantined = quarantine_cleanup_entry(
      parent,
      name,
      expected,
      directory: true,
      context: "cleanup extraction identity changed"
    )
    return true unless quarantined

    _quarantine_name, directory = quarantined
    directory.close
    true
  end


  def open_cleanup_file(parent, name)
    flags = File::RDONLY | File::BINARY | File::NOFOLLOW | File::NONBLOCK
    file = open_at(parent, name, flags, 0)
    unless file.stat.file? && !file.stat.symlink?
      file.close
      raise Failure, "cleanup extraction identity changed"
    end
    file
  rescue Errno::ELOOP, Errno::EISDIR
    raise Failure, "cleanup extraction identity changed"
  end

  def usage
    "usage: tools/p13-source-fetch URL BYTES SHA256 ABSOLUTE_DESTINATION"
  end

  def extract_usage
    "usage: tools/p13-source-fetch extract-crate " \
      "ABSOLUTE_CRATE BYTES SHA256 PACKAGE_PREFIX ABSOLUTE_DESTINATION"
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    P13SourceFetch.run(ARGV)
  rescue P13SourceFetch::Failure => error
    warn error.message
    exit 1
  end
end
