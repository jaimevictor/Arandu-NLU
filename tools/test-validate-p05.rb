# frozen_string_literal: true

require "digest"
require "fileutils"
require "tmpdir"
require_relative "validate-p05"

module P05ValidationTest
  module_function

  def assert(condition, message)
    raise "assertion failed: #{message}" unless condition
  end

  def assert_failure
    yield
    raise "expected P05Validation::Failure"
  rescue P05Validation::Failure => error
    error
  end

  def test_repository_source_and_rule_contract
    ledger = P05Validation.safe_yaml(
      File.join(P05Validation::ROOT, P05Validation::SOURCE_LEDGER)
    )
    admission =
      ledger["status"] == "QUARANTINED_CANDIDATE" ? :candidate : :admitted
    assert(
      P05Validation.validate(
        P05Validation::ROOT,
        run_cargo: false,
        admission: admission
      ),
      "repository P05 contract"
    )
  end

  def test_artifact_hash_and_git_blob_reject_substitution
    Dir.mktmpdir("FIXTURE_TECNICA_p05_artifact") do |directory|
      path = File.join(directory, "FIXTURE_TECNICA.txt")
      File.binwrite(path, "FIXTURE_TECNICA_A")
      bytes = File.binread(path)
      expected = {
        "bytes" => bytes.bytesize,
        "sha256" => Digest::SHA256.hexdigest(bytes),
        "git_blob" => Digest::SHA1.hexdigest("blob #{bytes.bytesize}\0#{bytes}")
      }
      P05Validation.verify_artifact(path, expected)
      File.binwrite(path, "FIXTURE_TECNICA_B")
      error = assert_failure do
        P05Validation.verify_artifact(path, expected)
      end
      assert(error.message.include?("hash differs"), "source substitution rejection")
    end
  end

  def test_rule_parser_rejects_duplicate_ids_and_surfaces
    duplicate_id = <<~TSV
      FIXTURE_TECNICA.a	FIXTURE_TECNICA_A	abbreviation	
      FIXTURE_TECNICA.a	FIXTURE_TECNICA_B	abbreviation	
    TSV
    error = assert_failure { P05Validation.parse_rules(duplicate_id) }
    assert(error.message.include?("duplicate rule ID"), "duplicate ID rejection")

    duplicate_surface = <<~TSV
      FIXTURE_TECNICA.a	FIXTURE_TECNICA_A	abbreviation	
      FIXTURE_TECNICA.b	FIXTURE_TECNICA_A	abbreviation	
    TSV
    error = assert_failure { P05Validation.parse_rules(duplicate_surface) }
    assert(error.message.include?("duplicate rule surface"), "duplicate surface rejection")
  end

  def test_rule_parser_rejects_malformed_utf8_and_field_count
    error = assert_failure { P05Validation.parse_rules("\xff".b) }
    assert(error.message.include?("not UTF-8"), "invalid UTF-8 rejection")

    error = assert_failure do
      P05Validation.parse_rules("FIXTURE_TECNICA.a\tFIXTURE_TECNICA_A\n")
    end
    assert(error.message.include?("field count"), "field-count rejection")
  end

  def test_rule_parser_requires_a_prominent_derivative_notice
    without_notice = "FIXTURE_TECNICA.a\tFIXTURE_TECNICA_A\tabbreviation\t\n"
    error = assert_failure do
      P05Validation.parse_rules(without_notice, require_notice: true)
    end
    assert(error.message.include?("notice missing"), "missing notice rejection")

    with_notice = <<~TSV
      # Modified by the NLU project: FIXTURE_TECNICA source extraction.
      FIXTURE_TECNICA.a	FIXTURE_TECNICA_A	abbreviation	
    TSV
    rows = P05Validation.parse_rules(with_notice, require_notice: true)
    assert(rows.length == 1, "notice excluded from runtime rows")
  end

  def test_source_identity_and_punctuation_inventory_reject_substitution
    ledger = P05Validation.safe_yaml(
      File.join(P05Validation::ROOT, P05Validation::SOURCE_LEDGER)
    )
    admission =
      ledger["status"] == "QUARANTINED_CANDIDATE" ? :candidate : :admitted

    substituted = Marshal.load(Marshal.dump(ledger))
    ud = substituted.fetch("sources").find do |source|
      source["id"] == "ud-portuguese-docs-bdd95cf"
    end
    ud["commit"] = "FIXTURE_TECNICA_SUBSTITUTED_COMMIT"
    ud["license"] = "FIXTURE_TECNICA_SUBSTITUTED_LICENSE"
    error = assert_failure do
      P05Validation.validate_sources(
        P05Validation::ROOT,
        substituted,
        admission: admission
      )
    end
    assert(error.message.include?("UD source identity differs"), "source identity pin")

    Dir.mktmpdir("FIXTURE_TECNICA_p05_source_metadata") do |root|
      path = File.join(root, P05Validation::SOURCE_LEDGER)
      FileUtils.mkdir_p(File.dirname(path))
      bytes = File.binread(
        File.join(P05Validation::ROOT, P05Validation::SOURCE_LEDGER)
      )
      bytes = bytes.sub(
        "https://github.com/UniversalDependencies/docs",
        "https://FIXTURE_TECNICA.invalid/substituted"
      )
      File.binwrite(path, bytes)
      error = assert_failure do
        P05Validation.validate_reviewed_source_ledger(root, admission: admission)
      end
      assert(
        error.message.include?("reviewed source ledger metadata differs"),
        "complete source metadata pin"
      )
    end

    duplicate_punctuation = Marshal.load(Marshal.dump(ledger))
    duplicate_punctuation
      .fetch("unicode_sources")
      .fetch("general_category_file")["admitted_code_points"] =
        Array.new(23, "0021")
    error = assert_failure do
      P05Validation.validate_rules(P05Validation::ROOT, duplicate_punctuation)
    end
    assert(
      error.message.include?("punctuation allowlist missing"),
      "exact punctuation inventory"
    )
  end

  def test_material_use_and_review_disposition_are_exact
    ledger = P05Validation.safe_yaml(
      File.join(P05Validation::ROOT, P05Validation::SOURCE_LEDGER)
    )
    admission =
      ledger["status"] == "QUARANTINED_CANDIDATE" ? :candidate : :admitted
    materials = P05Validation.safe_yaml(
      File.join(P05Validation::ROOT, "docs/clean-room/MATERIALS.yaml")
    )
    record = Marshal.load(
      Marshal.dump(
        materials.fetch("materials").find do |material|
          material["id"] == "cldr-48-acd6d88"
        end
      )
    )
    record["proposed_use"] = "FIXTURE_TECNICA_UNRESTRICTED_USE"
    record["allowed_use"] = "FIXTURE_TECNICA_UNRESTRICTED_USE"
    error = assert_failure do
      P05Validation.validate_material_record(
        record,
        "cldr-48-acd6d88",
        admission: admission
      )
    end
    assert(error.message.include?("proposed use differs"), "material use pin")

    records = materials.fetch("materials").to_h do |material|
      [material.fetch("id"), Marshal.load(Marshal.dump(material))]
    end
    records.fetch("cldr-48-acd6d88")["prohibited_use"] =
      "FIXTURE_TECNICA_CLEARED_PROHIBITIONS"
    error = assert_failure do
      P05Validation.validate_material_projection(records)
    end
    assert(
      error.message.include?("reviewed material metadata differs"),
      "complete material metadata pin"
    )

    distribution = P05Validation.safe_yaml(
      File.join(P05Validation::ROOT, "docs/clean-room/DISTRIBUTION-LICENSES.yaml")
    )
    rules = Marshal.load(Marshal.dump(distribution.fetch("path_rules")))
    rules.find { |rule| rule["origin_id"] == "cldr-48-acd6d88" }["license"] =
      "FIXTURE_TECNICA_SUBSTITUTED_LICENSE"
    error = assert_failure do
      P05Validation.validate_distribution_projection(rules)
    end
    assert(
      error.message.include?("reviewed distribution metadata differs"),
      "complete distribution metadata pin"
    )

    substituted = Marshal.load(Marshal.dump(ledger))
    substituted.fetch("review_disposition")["adversarial"] =
      "FIXTURE_TECNICA_UNREVIEWED"
    error = assert_failure do
      P05Validation.validate_review_disposition(
        P05Validation::ROOT,
        substituted,
        admission: admission
      )
    end
    assert(error.message.include?("review disposition differs"), "review state pin")
  end

  def test_p05_data_inventory_rejects_an_unexpected_file
    Dir.mktmpdir("FIXTURE_TECNICA_p05_inventory") do |root|
      P05Validation::EXPECTED_P05_DATA_FILES.each do |relative|
        path = File.join(root, relative)
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, "FIXTURE_TECNICA")
      end
      P05Validation.validate_p05_data_inventory(root)

      extra = File.join(
        root,
        "data/tokenization/p05/FIXTURE_TECNICA_rejected_source.py"
      )
      File.binwrite(extra, "FIXTURE_TECNICA")
      error = assert_failure do
        P05Validation.validate_p05_data_inventory(root)
      end
      assert(error.message.include?("file set differs"), "unexpected data rejection")
    end
  end

  def run
    methods.grep(/^test_/).sort.each do |test|
      public_send(test)
      puts "PASS #{test}"
    end
    puts "P05_GATE_TESTS_PASS"
  end
end

P05ValidationTest.run if $PROGRAM_NAME == __FILE__
