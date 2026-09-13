# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "validate-p08"

module P08ValidationTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure
    yield
    raise "expected P08Validation::Failure"
  rescue P08Validation::Failure => error
    error
  end

  def with_temp_copies(*relatives)
    Dir.mktmpdir("p08-validator-mutation-") do |root|
      relatives.each do |relative|
        source = File.join(P08Validation::ROOT, relative)
        destination = File.join(root, relative)
        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.cp(source, destination)
      end
      yield root
    end
  end

  def read_json(root, relative)
    value = P08Validation.parse_json(
      File.binread(File.join(root, relative)),
      relative
    )
    JSON.parse(JSON.generate(value))
  end

  def write_canonical(root, relative, value)
    File.binwrite(
      File.join(root, relative),
      P08Validation.canonical_json(value) + "\n"
    )
  end

  def mutate_model_hash_chain(field_path, value)
    with_temp_copies(
      P08Validation::MODEL_MANIFEST,
      P08Validation::EVALUATION_MANIFEST,
      P08Validation::EVALUATION_REPORT,
      P08Validation::MODEL_PACKAGE
    ) do |root|
      model = read_json(root, P08Validation::MODEL_MANIFEST)
      target = field_path[0...-1].reduce(model) { |item, field| item.fetch(field) }
      target[field_path.fetch(-1)] = value
      write_canonical(root, P08Validation::MODEL_MANIFEST, model)
      model_hash = Digest::SHA256.file(
        File.join(root, P08Validation::MODEL_MANIFEST)
      ).hexdigest

      evaluation = read_json(root, P08Validation::EVALUATION_MANIFEST)
      evaluation.fetch("model")["manifest_sha256"] = model_hash
      write_canonical(root, P08Validation::EVALUATION_MANIFEST, evaluation)
      evaluation_hash = Digest::SHA256.file(
        File.join(root, P08Validation::EVALUATION_MANIFEST)
      ).hexdigest

      report = read_json(root, P08Validation::EVALUATION_REPORT)
      report["manifest_sha256"] = evaluation_hash
      write_canonical(root, P08Validation::EVALUATION_REPORT, report)
      package = P08Validation.parse_pos_package(
        File.binread(File.join(root, P08Validation::MODEL_PACKAGE))
      )

      assert(
        evaluation.dig("model", "manifest_sha256") == model_hash &&
          report["manifest_sha256"] == evaluation_hash,
        "recomputed outer hash chain"
      )
      yield model, evaluation, report, package
    end
  end

  def test_split_bytes_and_identity_mutations_are_rejected
    with_temp_copies(
      P08Validation::TRAIN,
      P08Validation::SPLIT_MANIFEST
    ) do |root|
      train = File.binread(File.join(root, P08Validation::TRAIN))
      train.setbyte(0, train.getbyte(0) ^ 1)
      error = assert_failure do
        P08Validation.validate_artifact_bytes(P08Validation::TRAIN, train)
      end
      assert(error.message.include?("hash differs"), "split byte mutation")

      manifest = read_json(root, P08Validation::SPLIT_MANIFEST)
      manifest["compiler_id"] = "FIXTURE_TECNICA"
      write_canonical(root, P08Validation::SPLIT_MANIFEST, manifest)
      error = assert_failure do
        P08Validation.validate_split_manifest(manifest)
      end
      assert(error.message.include?("compiler_id differs"), "split identity mutation")
    end
  end

  def test_model_package_mutation_is_rejected
    with_temp_copies(P08Validation::MODEL_PACKAGE) do |root|
      package = File.binread(File.join(root, P08Validation::MODEL_PACKAGE))
      package.setbyte(7, 2)
      error = assert_failure do
        P08Validation.validate_artifact_bytes(P08Validation::MODEL_PACKAGE, package)
      end
      assert(error.message.include?("hash differs"), "model package hash mutation")
      error = assert_failure { P08Validation.parse_pos_package(package) }
      assert(error.message.include?("version differs"), "model package version mutation")
    end
  end

  def test_model_source_mutation_with_recomputed_hashes_is_rejected
    mutate_model_hash_chain(
      %w[source source_id],
      "FIXTURE_TECNICA"
    ) do |model, _evaluation, _report, package|
      error = assert_failure do
        P08Validation.validate_model_manifest(model, package)
      end
      assert(error.message.include?("source differs"), "model source mutation")
    end
  end

  def test_model_config_mutation_with_recomputed_hashes_is_rejected
    mutate_model_hash_chain(
      %w[identity config_id],
      "FIXTURE_TECNICA"
    ) do |model, _evaluation, _report, package|
      error = assert_failure do
        P08Validation.validate_model_manifest(model, package)
      end
      assert(error.message.include?("identity differs"), "model config mutation")
    end
  end

  def test_model_seed_mutation_with_recomputed_hashes_is_rejected
    mutate_model_hash_chain(
      ["random_seed"],
      1
    ) do |model, _evaluation, _report, package|
      error = assert_failure do
        P08Validation.validate_model_manifest(model, package)
      end
      assert(error.message.include?("random_seed differs"), "model seed mutation")
    end
  end

  def test_report_metric_and_reconciliation_mutations_are_rejected
    with_temp_copies(
      P08Validation::EVALUATION_REPORT,
      P08Validation::EVALUATION_MANIFEST
    ) do |root|
      manifest = read_json(root, P08Validation::EVALUATION_MANIFEST)
      report = read_json(root, P08Validation::EVALUATION_REPORT)
      report.dig("results", "selected", "exact_token_sets")["numerator"] = 561
      write_canonical(root, P08Validation::EVALUATION_REPORT, report)
      error = assert_failure do
        P08Validation.validate_report(report, manifest)
      end
      assert(error.message.include?("reconciliation differs"), "metric reconciliation")

      report.dig("results", "selected", "error_categories")[
        "exact_set_mismatch"
      ] = 82
      error = assert_failure do
        P08Validation.validate_report(report, manifest)
      end
      assert(error.message.include?("frozen result"), "reconciled metric mutation")
    end
  end

  def test_evaluation_manifest_mutation_is_rejected
    with_temp_copies(P08Validation::EVALUATION_MANIFEST) do |root|
      manifest = read_json(root, P08Validation::EVALUATION_MANIFEST)
      manifest["runner_id"] = "FIXTURE_TECNICA"
      write_canonical(root, P08Validation::EVALUATION_MANIFEST, manifest)
      error = assert_failure do
        P08Validation.validate_evaluation_manifest(manifest)
      end
      assert(error.message.include?("runner_id differs"), "evaluation manifest mutation")
    end
  end

  def test_production_oracle_token_mutation_is_rejected
    with_temp_copies("crates/lang-ptbr/src/pos.rs") do |root|
      relative = "crates/lang-ptbr/src/pos.rs"
      path = File.join(root, relative)
      File.binwrite(
        path,
        File.binread(path) +
          "\nconst FIXTURE_TECNICA: &str = \"heldout\";\n"
      )
      error = assert_failure do
        P08Validation.validate_pos_runtime_bytes(
          relative => File.binread(path)
        )
      end
      assert(error.message.include?("heldout"), "production oracle mutation")
    end
  end

  def test_pending_p08_requirement_is_rejected
    relative = "docs/evidence/REQUIREMENTS-TRACEABILITY.md"
    with_temp_copies(relative) do |root|
      path = File.join(root, relative)
      bytes = File.binread(path)
      id = P08Validation::REQUIREMENTS.fetch(0)
      lines = bytes.lines
      index = lines.index { |line| line.start_with?("| `#{id}` |") }
      raise "fixture requirement row missing" unless index

      cells = lines.fetch(index).split("|", -1)
      cells[-2] = " PENDING "
      lines[index] = cells.join("|")
      File.binwrite(path, lines.join)
      error = assert_failure do
        P08Validation.validate_requirement_rows(
          File.binread(path),
          require_satisfied: true
        )
      end
      assert(error.message.include?(id), "pending P08 requirement")
    end
  end

  def test_duplicate_json_key_is_rejected
    error = assert_failure do
      P08Validation.parse_json(
        '{"FIXTURE_TECNICA":1,"FIXTURE_TECNICA":2}',
        "FIXTURE_TECNICA duplicate"
      )
    end
    assert(error.message.include?("DuplicateKey"), "duplicate JSON key")
  end

  def test_repository_candidate_contract
    assert(
      P08Validation.validate(
        P08Validation::ROOT,
        run_cargo: false,
        require_satisfied: false,
        run_reproduction: false
      ),
      "repository P08 candidate"
    )
  end

  def run
    methods.grep(/^test_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P08_GATE_TESTS_PASS"
  end
end

P08ValidationTest.run
