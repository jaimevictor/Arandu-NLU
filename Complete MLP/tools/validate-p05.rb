# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "psych"

module P05Validation
  class Failure < StandardError; end

  ROOT = File.expand_path("..", __dir__)
  SOURCE_LEDGER = "docs/evidence/P05-SOURCES.yaml"
  ARTIFACTS = {
    "data/unicode/17.0.0/ucd/UnicodeData.txt" => {
      "bytes" => 2_198_209,
      "sha256" => "2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c",
      "git_blob" => "fca68e3e154e62e49727ecf69f1df442582bfa96"
    },
    "data/tokenization/p05/ud-docs-bdd95cf/index.md" => {
      "bytes" => 4_880,
      "sha256" => "3dd5d99753e26737a2711e8b2ec692120d1b6c807b51ddb37bd73f33d9e71557",
      "git_blob" => "cfbb97a50509f0a8e4b3ca605520741956dcc1ac"
    },
    "data/tokenization/p05/ud-docs-bdd95cf/LICENSE.txt" => {
      "bytes" => 11_323,
      "sha256" => "6dc0e068dcf3a5bc8e054205b85b7720e1d49265bbc64bf515d2cf79197df69a",
      "git_blob" => "ad410e11302107da9aa47ce3d46bd5ad011c4c43"
    },
    "data/tokenization/p05/ud-docs-bdd95cf/PRON.md" => {
      "bytes" => 687,
      "sha256" => "85167e5613c5645ea0aaf7ed8d2058266afd857ef3bfb688ced525a7f04f3604",
      "git_blob" => "06a85d790fed94a42312a315d96935bb483a3dc3"
    },
    "data/tokenization/p05/cldr-48/pt.xml" => {
      "bytes" => 500_750,
      "sha256" => "0c27d3da189672618048c2fdb20659fa99b28509dde3cc8720d7331a32723bdf",
      "git_blob" => "c768ca559faf92f3fdb9c117de4cf43ebcb137d4"
    },
    "data/tokenization/p05/cldr-48/numberingSystems.xml" => {
      "bytes" => 11_834,
      "sha256" => "c5b9b208c6fe7bd3ce4e1c6cbb8f3337480aca620c9cf703ef3b6c74d4258c16",
      "git_blob" => "e0bdfe12b5c81f2ed94b3b5aa3001087f345801a"
    },
    "data/tokenization/p05/cldr-48/LICENSE-UNICODE" => {
      "bytes" => 2_033,
      "sha256" => "b4c0ae8ef04f7059f96ce5bbe0467f9fe6f6d81bbe13517701dfeb961fb4d0b6",
      "git_blob" => "861b74f3c812088755fd185d964e82a244503bbd"
    },
    "data/tokenization/p05/rules/ud-portuguese.tsv" => {
      "bytes" => 371,
      "sha256" => "4182e503edffca3b5c058c0ecc6e6164a09a732271e0bb56b9a1039ab6bff69e",
      "git_blob" => "b3a87990cd6138a275c48d5cc3cae95a480b2bd1"
    },
    "data/tokenization/p05/rules/cldr-portuguese.tsv" => {
      "bytes" => 210,
      "sha256" => "61b42a2e6a0eb7c3ecee0d5ecf0ed6a34a15ca90c6728fba5fada2e610e7f2e1",
      "git_blob" => "2edd4fc4d46cce05ba108ca8fe7818bcd0e5d9ba"
    }
  }.freeze
  EXPECTED_RULES = {
    "data/tokenization/p05/rules/ud-portuguese.tsv" => [
      ["ud.pt.do", "do", "contraction", "de|o"],
      ["ud.pt.pelo", "pelo", "contraction", "por|o"],
      ["ud.pt.dele", "dele", "contraction", "de|ele"],
      ["ud.pt.no", "no", "contraction", "em|o"],
      ["ud.pt.contar-lhe-ei", "contar-lhe-ei", "clitic", "contar|lhe|ei"],
      ["ud.pt.sentem-se", "sentem-se", "clitic", "sentem|se"],
      ["ud.pt.ie", "i.e.", "abbreviation", ""]
    ],
    "data/tokenization/p05/rules/cldr-portuguese.tsv" => [
      ["cldr48.pt.unit.quilometro", "quilômetro", "unit", ""],
      ["cldr48.pt.multiunit.km-per-h", "km/h", "multiunit", ""]
    ]
  }.freeze
  P05_REQUIREMENTS = (1..13).map { |number| format("P05-TOK-%03d", number) }.freeze
  EXPECTED_PUNCTUATION_CODE_POINTS = %w[
    0021 0022 0023 0025 0026 0027 0028 0029 002A 002C 002D 002E
    002F 003A 003B 003F 0040 005B 005C 005D 005F 007B 007D
  ].freeze
  EXPECTED_MATERIAL_USES = {
    "cldr-48-acd6d88" =>
      "P05_exact_bounded_decimal_time_unit_and_multiunit_rules_only",
    "ud-portuguese-docs-bdd95cf" =>
      "P05_exact_allowlisted_Portuguese_tokenization_examples_only",
    "unicode-character-database-17.0.0-p05-punctuation" =>
      "P05_exact_ASCII_P_general_category_punctuation_allowlist"
  }.freeze
  EXPECTED_REVIEW_DISPOSITION = {
    "discovery" => "PASS_round_2_exact_source_identity_and_support",
    "license" => "PASS_round_2_complete_permissive_terms_and_obligations",
    "provenance" => "PASS_round_2_immutable_paths_bytes_and_transformations",
    "quality" => "PASS_round_2_source_fitness_and_bounded_behavior",
    "adversarial" => "PASS_round_2_fail_closed_boundaries_and_validator_mutations"
  }.freeze
  REVIEW_REPORTS = EXPECTED_REVIEW_DISPOSITION.keys.to_h do |role|
    [role, "docs/reviews/P05/source-admission-#{role}.md"]
  end.freeze
  REVIEWED_SOURCE_LEDGER_SHA256 =
    "25cb4085df8eaf6fb0d8dd91ee4814a03586ed2e0268c93e0f64296a6208f9ff"
  REVIEWED_MATERIAL_PROJECTION_SHA256 =
    "d59c6d697b1939b75bb54120e383b52a221ab334758d056f83cc27fc699a823a"
  REVIEWED_DISTRIBUTION_PROJECTION_SHA256 =
    "ef8fe50ddc14b114ccc7c4ca1c8a43547302707fdc72ce1604d9101c7bdf2433"
  EXPECTED_P05_DATA_FILES = ARTIFACTS.keys
    .select { |path| path.start_with?("data/tokenization/p05/") }
    .sort
    .freeze

  module_function

  def run(arguments)
    arguments = arguments.dup
    no_cargo = arguments.delete("--no-cargo")
    review_candidate = arguments.delete("--review-candidate")
    raise Failure, "usage: tools/validate-p05 [--no-cargo] [--review-candidate]" unless
      arguments.empty?

    admission = review_candidate ? :candidate : :admitted
    validate(ROOT, run_cargo: !no_cargo && !review_candidate, admission: admission)
    puts(review_candidate ? "P05_REVIEW_CANDIDATE_PASS" : "P05_GATE_PASS")
  rescue Failure => error
    warn "P05_GATE_FAIL: #{error.message}"
    exit 1
  end

  def validate(root, run_cargo:, admission: :admitted)
    ledger = safe_yaml(File.join(root, SOURCE_LEDGER))
    validate_sources(root, ledger, admission: admission)
    validate_rules(root, ledger)
    validate_materials_and_distribution(root, admission: admission)
    validate_contract(root)
    validate_requirements(root, require_satisfied: admission == :admitted)
    run_cargo_test(root) if run_cargo
    true
  end

  def safe_yaml(path)
    value = Psych.safe_load(
      File.binread(path),
      permitted_classes: [],
      permitted_symbols: [],
      aliases: false,
      filename: path
    )
    raise Failure, "YAML root is not a mapping: #{path}" unless value.is_a?(Hash)

    value
  rescue Psych::Exception => error
    raise Failure, "invalid YAML #{path}: #{error.class}"
  end

  def validate_sources(root, ledger, admission: :admitted)
    raise Failure, "source ledger schema differs" unless ledger["schema_version"] == 1
    validate_reviewed_source_ledger(root, admission: admission)
    expected_ledger_status =
      admission == :admitted ? "ADMITTED_P05" : "QUARANTINED_CANDIDATE"
    raise Failure, "source ledger status differs" unless
      ledger["status"] == expected_ledger_status

    unicode = ledger.fetch("unicode_sources")
    expected_unicode_status =
      admission == :admitted ? "ADMITTED_AUTONOMOUS" : "QUARANTINED_CANDIDATE"
    raise Failure, "Unicode P05 source status differs" unless
      unicode["status"] == expected_unicode_status
    raise Failure, "Unicode source identity differs" unless
      unicode["id"] == "unicode-character-database-17.0.0" &&
        unicode["owner"] == "Unicode_Inc" &&
        unicode["archive_sha256"] ==
          "2066d1909b2ea93916ce092da1c0ee4808ea3ef8407c94b4f14f5b7eb263d28e" &&
        unicode["license"] == "Unicode-3.0" &&
        unicode["retained_license_path"] == "data/unicode/17.0.0/LICENSE-UNICODE"
    raise Failure, "Unicode word-boundary source hash differs" unless
      unicode.dig("word_boundary_file", "sha256") ==
        "1de23a75f37904abc7d206239ee8d34f8fdf0fb4ab32a7174dfbabbde25419b2"
    raise Failure, "Unicode punctuation source hash differs" unless
      unicode.dig("general_category_file", "sha256") ==
        "2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c"

    sources = ledger.fetch("sources").to_h { |source| [source.fetch("id"), source] }
    raise Failure, "source ID set differs" unless
      sources.keys.sort ==
        %w[cldr-48-acd6d88 ud-portuguese-docs-bdd95cf]
    expected_source_status =
      admission == :admitted ? "ADMITTED_AUTONOMOUS" : "QUARANTINED_CANDIDATE"
    sources.each_value do |source|
      raise Failure, "source is not admitted: #{source.fetch("id")}" unless
        source["status"] == expected_source_status
    end
    ud = sources.fetch("ud-portuguese-docs-bdd95cf")
    raise Failure, "UD source identity differs" unless
      ud["provider"] == "Universal_Dependencies" &&
        ud["upstream_owner"] == "UniversalDependencies" &&
        ud["commit"] == "bdd95cf20660e21a3f60bb84e2c93d1f3efcd74b" &&
        ud["tree"] == "135fab3f7da3052c4951568a416dca7b6a2bdd87" &&
        ud["source_path"] == "_pt/index.md" &&
        ud["source_git_blob"] == "cfbb97a50509f0a8e4b3ca605520741956dcc1ac" &&
        ud["source_sha256"] ==
          "3dd5d99753e26737a2711e8b2ec692120d1b6c807b51ddb37bd73f33d9e71557" &&
        ud["clitic_source_path"] == "_pt/pos/PRON.md" &&
        ud["clitic_source_git_blob"] == "06a85d790fed94a42312a315d96935bb483a3dc3" &&
        ud["clitic_source_sha256"] ==
          "85167e5613c5645ea0aaf7ed8d2058266afd857ef3bfb688ced525a7f04f3604" &&
        ud["license"] == "Apache-2.0" &&
        ud["license_git_blob"] == "ad410e11302107da9aa47ce3d46bd5ad011c4c43" &&
        ud["license_sha256"] ==
          "6dc0e068dcf3a5bc8e054205b85b7720e1d49265bbc64bf515d2cf79197df69a"
    cldr = sources.fetch("cldr-48-acd6d88")
    raise Failure, "CLDR source identity differs" unless
      cldr["provider"] == "Unicode_CLDR" &&
        cldr["upstream_owner"] == "unicode-org" &&
        cldr["release_tag"] == "release-48" &&
        cldr["release_tag_target"] ==
          "acd6d88ae493633240e19a87a721076a8a75c310" &&
        cldr["commit"] == "acd6d88ae493633240e19a87a721076a8a75c310" &&
        cldr["tree"] == "bafae8fc919257506cb84327781ce4912b9b0c0b" &&
        cldr["license"] == "Unicode-3.0" &&
        cldr["license_git_blob"] == "861b74f3c812088755fd185d964e82a244503bbd" &&
        cldr["license_sha256"] ==
          "b4c0ae8ef04f7059f96ce5bbe0467f9fe6f6d81bbe13517701dfeb961fb4d0b6"
    cldr_paths = cldr.fetch("source_paths").to_h do |record|
      [record.fetch("path"), record]
    end
    raise Failure, "CLDR source path set differs" unless
      cldr_paths.keys.sort ==
        %w[common/main/pt.xml common/supplemental/numberingSystems.xml]
    pt = cldr_paths.fetch("common/main/pt.xml")
    raise Failure, "CLDR Portuguese path metadata differs" unless
      pt["git_blob"] == "c768ca559faf92f3fdb9c117de4cf43ebcb137d4" &&
        pt["bytes"] == 500_750 &&
        pt["sha256"] ==
          "0c27d3da189672618048c2fdb20659fa99b28509dde3cc8720d7331a32723bdf"
    numbering = cldr_paths.fetch("common/supplemental/numberingSystems.xml")
    raise Failure, "CLDR numbering content binding differs" unless
      numbering["git_blob"] == "e0bdfe12b5c81f2ed94b3b5aa3001087f345801a" &&
        numbering["bytes"] == 11_834 &&
        numbering["sha256"] ==
          "c5b9b208c6fe7bd3ce4e1c6cbb8f3337480aca620c9cf703ef3b6c74d4258c16" &&
      numbering["commit_bound_content_api_url"] ==
        "https://api.github.com/repos/unicode-org/cldr/contents/common/supplemental/numberingSystems.xml?ref=acd6d88ae493633240e19a87a721076a8a75c310" &&
        numbering["content_metadata_response_sha256"] ==
          "df5fb7f878fd4eb288ed9d70af48f3b3ac20db54ce89a41c710856ac06d29573"
    history = ud.fetch("clitic_source_history")
    raise Failure, "UD clitic contributor history differs" unless
      history["current_path_api_url"] ==
        "https://api.github.com/repos/UniversalDependencies/docs/commits?path=_pt%2Fpos%2FPRON.md&sha=bdd95cf20660e21a3f60bb84e2c93d1f3efcd74b&per_page=100" &&
        history["current_path_response_bytes"] == 99_831 &&
        history["current_path_response_sha256"] ==
          "ce005d4cb2c93f6084dac6cc8bb7fc1d20da8aa7cc675b37e3e2b57fb4027549" &&
        history["migration_commit"] == "f36833b88c0142fa0f5463d89345b5414939584f" &&
        history["migration_commit_api_url"] ==
          "https://api.github.com/repos/UniversalDependencies/docs/commits/f36833b88c0142fa0f5463d89345b5414939584f" &&
        history["migration_commit_response_bytes"] == 204_646 &&
        history["migration_commit_response_sha256"] ==
          "8f8301a57ebcde72705f2a2b4942f56eb84fc4b701b42a7e8b6cddb4c82c33bd" &&
        history["migration_parent_commit"] ==
          "ab3945e15f6cbe8f77cc1e7c19cbe8c569a85901" &&
        history["migration_current_path_api_url"] ==
          "https://api.github.com/repos/UniversalDependencies/docs/contents/_pt/pos/PRON.md?ref=f36833b88c0142fa0f5463d89345b5414939584f" &&
        history["migration_current_path_response_bytes"] == 1_948 &&
        history["migration_current_path_response_sha256"] ==
          "b7c23404f8e0ab48743544d39039a7cd4776a099914a248485f142726d103048" &&
        history["previous_path"] == "_pt-pos/PRON.md" &&
        history["migration_previous_path_api_url"] ==
          "https://api.github.com/repos/UniversalDependencies/docs/contents/_pt-pos/PRON.md?ref=ab3945e15f6cbe8f77cc1e7c19cbe8c569a85901" &&
        history["migration_previous_path_response_bytes"] == 1_948 &&
        history["migration_previous_path_response_sha256"] ==
          "11e84579bf68869cee40de8b570c731a2067cd08b6445ab3aa3e5fcf042a779c" &&
        history["migration_shared_git_blob"] ==
          "aec5879dea549ca9e9b81bf0026e3c591fc03ddc" &&
        history["migration_shared_bytes"] == 609 &&
        history["migration_shared_sha256"] ==
          "2a752dd85896fe41f6eaff18fd07128c53b64c5ea6e5f6ec2e0e81b820f4ee71" &&
        history["previous_path_api_url"] ==
          "https://api.github.com/repos/UniversalDependencies/docs/commits?path=_pt-pos%2FPRON.md&sha=ab3945e15f6cbe8f77cc1e7c19cbe8c569a85901&per_page=100" &&
        history["previous_path_response_bytes"] == 35_968 &&
        history["previous_path_response_sha256"] ==
          "c8f05c058db0c8d3363a23622f5b1b253a213e3a929bf0ae01a82399d3511c94" &&
        history["file_contributors"] == %w[Alexandre_Rademaker Dan_Zeman]
    rejected = ledger.fetch("rejected_sources").to_h do |source|
      [source.fetch("id"), source]
    end
    raise Failure, "rejected source set differs" unless
      rejected.keys == ["spacy-portuguese-exceptions-26b4d1d"]
    spacy = rejected.fetch("spacy-portuguese-exceptions-26b4d1d")
    raise Failure, "spaCy pass-1 rejection differs" unless
      spacy["status"] == "REJECTED" &&
        spacy["retained_bytes"] == "removed" &&
        spacy["derivative_bytes"] == "removed" &&
        spacy["prohibited_use"] == "all_P05_runtime_rules_tests_and_source_claims"

    validate_review_disposition(root, ledger, admission: admission)
    validate_p05_data_inventory(root)
    ARTIFACTS.each do |relative, expected|
      verify_artifact(File.join(root, relative), expected)
    end
  rescue KeyError => error
    raise Failure, "source ledger missing key #{error.key}"
  end

  def verify_artifact(path, expected)
    raise Failure, "artifact is a symlink: #{path}" if File.symlink?(path)
    raise Failure, "artifact is not a regular file: #{path}" unless File.file?(path)
    bytes = File.binread(path)
    raise Failure, "artifact byte count differs: #{path}" unless
      bytes.bytesize == expected.fetch("bytes")
    raise Failure, "artifact hash differs: #{path}" unless
      Digest::SHA256.hexdigest(bytes) == expected.fetch("sha256")
    return unless expected.key?("git_blob")

    actual_blob = Digest::SHA1.hexdigest("blob #{bytes.bytesize}\0#{bytes}")
    raise Failure, "artifact Git blob differs: #{path}" unless
      actual_blob == expected.fetch("git_blob")
  end

  def parse_rules(bytes, require_notice: false)
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    raise Failure, "rule table is not UTF-8" unless text.valid_encoding?

    lines = text.lines(chomp: true)
    if require_notice
      raise Failure, "derivative notice missing" unless
        lines.first&.start_with?("# ") && lines.first.include?("NLU project")
    end
    rule_lines = lines.reject { |line| line.start_with?("#") }
    raise Failure, "comment after first rule" unless
      lines.drop_while { |line| line.start_with?("#") }.none? { |line| line.start_with?("#") }

    ids = {}
    surfaces = {}
    rows = rule_lines.map.with_index(1) do |line, line_number|
      fields = line.split("\t", -1)
      raise Failure, "rule field count differs at line #{line_number}" unless fields.length == 4
      id, surface, token_class, parts = fields
      raise Failure, "empty rule field at line #{line_number}" if
        id.empty? || surface.empty? || token_class.empty?
      raise Failure, "duplicate rule ID: #{id}" if ids.key?(id)
      raise Failure, "duplicate rule surface: #{surface}" if surfaces.key?(surface)

      ids[id] = true
      surfaces[surface] = true
      fields
    end
    raise Failure, "empty rule table" if rows.empty?

    rows
  end

  def validate_rules(root, ledger)
    actual = EXPECTED_RULES.to_h do |relative, expected|
      rows = parse_rules(File.binread(File.join(root, relative)), require_notice: true)
      raise Failure, "rule table differs: #{relative}" unless rows == expected
      [relative, rows]
    end

    extraction = ledger.fetch("literal_extraction")
    raise Failure, "rule extraction version differs" unless
      extraction["version"] == "p05-literal-extraction-v2"
    raise Failure, "rule ID algorithm missing" unless
      extraction["rule_id_algorithm"] == "explicit_source_scoped_allowlist_identifier"

    ledger_rows = {
      "data/tokenization/p05/rules/ud-portuguese.tsv" =>
        extraction.fetch("ud_portuguese_docs"),
      "data/tokenization/p05/rules/cldr-portuguese.tsv" =>
        extraction.fetch("cldr_portuguese")
    }.transform_values do |records|
      records.map do |record|
        raise Failure, "rule source locator missing: #{record.fetch("rule_id")}" unless
          record["source_locator"].is_a?(String) && !record["source_locator"].empty?
        [
          record.fetch("rule_id"),
          record.fetch("surface"),
          record.fetch("class"),
          record.fetch("parts").join("|")
        ]
      end
    end
    raise Failure, "ledger allowlist differs from rule tables" unless ledger_rows == actual

    ud_source = File.binread(
      File.join(root, "data/tokenization/p05/ud-docs-bdd95cf/index.md")
    ).force_encoding(Encoding::UTF_8)
    ud_pron_source = File.binread(
      File.join(root, "data/tokenization/p05/ud-docs-bdd95cf/PRON.md")
    ).force_encoding(Encoding::UTF_8)
    cldr_source = File.binread(
      File.join(root, "data/tokenization/p05/cldr-48/pt.xml")
    ).force_encoding(Encoding::UTF_8)
    actual.each do |relative, rows|
      source = relative.include?("/ud-") ? ud_source : cldr_source
      rows.each do |id, surface, token_class, parts|
        raise Failure, "surface absent from source: #{id}" unless source.include?(surface)
        next unless relative.include?("/ud-")

        parts.split("|").each do |part|
          raise Failure, "logical part absent from source: #{id}" unless source.include?(part)
        end
        if token_class == "clitic"
          supported = parts.split("|").any? do |part|
            ud_pron_source.include?("clitic pronouns: #{part}") ||
              ud_pron_source.include?(", #{part}")
          end
          raise Failure, "clitic class absent from source: #{id}" unless supported
        end
      end
    end

    numbering = File.binread(
      File.join(root, "data/tokenization/p05/cldr-48/numberingSystems.xml")
    )
    raise Failure, "CLDR latn digit source row missing" unless
      numbering.include?('id="latn" type="numeric" digits="0123456789"')
    raise Failure, "CLDR decimal-comma source row missing" unless
      cldr_source.include?("<decimal>,</decimal>")
    raise Failure, "CLDR HH:mm source row missing" unless
      cldr_source.include?('<dateFormatItem id="EHm">E, HH:mm</dateFormatItem>')

    unicode_data = File.binread(
      File.join(root, "data/unicode/17.0.0/ucd/UnicodeData.txt")
    )
    code_points = ledger.dig("unicode_sources", "general_category_file", "admitted_code_points")
    raise Failure, "Unicode punctuation allowlist missing" unless
      code_points == EXPECTED_PUNCTUATION_CODE_POINTS
    code_points.each do |code_point|
      row = unicode_data.lines.find { |line| line.start_with?("#{code_point};") }
      raise Failure, "Unicode punctuation row missing: #{code_point}" if row.nil?
      category = row.split(";")[2]
      raise Failure, "Unicode non-punctuation admitted: #{code_point}" unless
        category&.start_with?("P")
    end
  rescue KeyError => error
    raise Failure, "rule ledger missing key #{error.key}"
  end

  def validate_materials_and_distribution(root, admission: :admitted)
    materials = safe_yaml(File.join(root, "docs/clean-room/MATERIALS.yaml"))
    material_list = materials.fetch("materials")
    records = material_list.to_h { |record| [record.fetch("id"), record] }
    raise Failure, "duplicate material ID" unless records.length == material_list.length
    validate_material_projection(records)
    EXPECTED_MATERIAL_USES.each_key do |id|
      validate_material_record(records.fetch(id), id, admission: admission)
    end
    unicode = records.fetch("unicode-character-database-17.0.0-p05-punctuation")
    raise Failure, "Unicode material identity differs" unless
      unicode["provider"] == "Unicode_Inc" &&
        unicode["version"] == "17.0.0" &&
        unicode["source_sha256"] ==
          "2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c" &&
        unicode["license"] == "Unicode-3.0"
    ud = records.fetch("ud-portuguese-docs-bdd95cf")
    raise Failure, "UD material identity differs" unless
      ud["provider"] == "Universal_Dependencies" &&
        ud["upstream_owner"] == "UniversalDependencies" &&
        ud["commit"] == "bdd95cf20660e21a3f60bb84e2c93d1f3efcd74b" &&
        ud["tree"] == "135fab3f7da3052c4951568a416dca7b6a2bdd87" &&
        ud["license"] == "Apache-2.0"
    cldr = records.fetch("cldr-48-acd6d88")
    raise Failure, "CLDR material identity differs" unless
      cldr["provider"] == "Unicode_CLDR" &&
        cldr["upstream_owner"] == "unicode-org" &&
        cldr["commit"] == "acd6d88ae493633240e19a87a721076a8a75c310" &&
        cldr["tree"] == "bafae8fc919257506cb84327781ce4912b9b0c0b" &&
        cldr["license"] == "Unicode-3.0"
    spacy = records.fetch("spacy-portuguese-exceptions-26b4d1d")
    raise Failure, "spaCy material rejection differs" unless
      spacy["status"] == "REJECTED" &&
        spacy["allowed_use"] == "none" &&
        spacy["retained_bytes"] == "removed"

    distribution = safe_yaml(
      File.join(root, "docs/clean-room/DISTRIBUTION-LICENSES.yaml")
    )
    rules = distribution.fetch("path_rules")
    validate_distribution_projection(rules)
    required_origins = %w[
      cldr-48-acd6d88
      ud-portuguese-docs-bdd95cf
      unicode-character-database-17.0.0
    ]
    required_origins.each do |origin|
      matching = rules.select { |rule| rule["origin_id"] == origin }
      raise Failure, "distribution origin missing: #{origin}" if matching.empty?
    end
  rescue KeyError => error
    raise Failure, "material/distribution ledger missing key #{error.key}"
  end

  def validate_material_record(record, id, admission:)
    expected_status =
      admission == :admitted ? "ADMITTED_AUTONOMOUS" : "QUARANTINED_CANDIDATE"
    expected_use = EXPECTED_MATERIAL_USES.fetch(id)
    raise Failure, "material status differs: #{id}" unless
      record["status"] == expected_status
    raise Failure, "material evidence differs: #{id}" unless
      record["source_evidence"] == SOURCE_LEDGER
    raise Failure, "material proposed use differs: #{id}" unless
      record["proposed_use"] == expected_use
    allowed_use = admission == :admitted ? expected_use : "admission_review_only"
    raise Failure, "material allowed use differs: #{id}" unless
      record["allowed_use"] == allowed_use
  end

  def validate_material_projection(records)
    ids = (EXPECTED_MATERIAL_USES.keys + ["spacy-portuguese-exceptions-26b4d1d"]).sort
    selected = ids.map do |id|
      Marshal.load(Marshal.dump(records.fetch(id)))
    end
    selected.each do |record|
      next unless EXPECTED_MATERIAL_USES.key?(record.fetch("id"))

      record["status"] = "QUARANTINED_CANDIDATE"
      record["allowed_use"] = "admission_review_only"
    end
    digest = Digest::SHA256.hexdigest(JSON.generate(canonical_value(selected)))
    raise Failure, "reviewed material metadata differs" unless
      digest == REVIEWED_MATERIAL_PROJECTION_SHA256
  rescue KeyError => error
    raise Failure, "reviewed material missing key #{error.key}"
  end

  def validate_distribution_projection(rules)
    ids = %w[
      cldr-48-acd6d88
      ud-portuguese-docs-bdd95cf
      unicode-character-database-17.0.0
    ]
    selected = rules.select { |rule| ids.include?(rule["origin_id"]) }
      .sort_by { |rule| rule.fetch("origin_id") }
    raise Failure, "reviewed distribution rule set differs" unless
      selected.map { |rule| rule.fetch("origin_id") } == ids.sort
    digest = Digest::SHA256.hexdigest(JSON.generate(canonical_value(selected)))
    raise Failure, "reviewed distribution metadata differs" unless
      digest == REVIEWED_DISTRIBUTION_PROJECTION_SHA256
  rescue KeyError => error
    raise Failure, "reviewed distribution missing key #{error.key}"
  end

  def canonical_value(value)
    case value
    when Hash
      value.keys.sort.to_h { |key| [key, canonical_value(value.fetch(key))] }
    when Array
      value.map { |item| canonical_value(item) }
    else
      value
    end
  end

  def validate_reviewed_source_ledger(root, admission:)
    candidate = File.binread(File.join(root, SOURCE_LEDGER))
    if admission == :admitted
      replace_once!(
        candidate,
        "status: ADMITTED_P05\n",
        "status: QUARANTINED_CANDIDATE\n",
        "source ledger status"
      )
      status_pattern = /^(\s+)status: ADMITTED_AUTONOMOUS$/
      raise Failure, "source admission status count differs" unless
        candidate.scan(status_pattern).length == 3
      candidate.gsub!(
        status_pattern,
        '\1status: QUARANTINED_CANDIDATE'
      )
      EXPECTED_REVIEW_DISPOSITION.each do |role, disposition|
        replace_once!(
          candidate,
          "  #{role}: #{disposition}\n",
          "  #{role}: PENDING_PASS_2\n",
          "source review disposition #{role}"
        )
      end
    end
    raise Failure, "reviewed source ledger metadata differs" unless
      Digest::SHA256.hexdigest(candidate) == REVIEWED_SOURCE_LEDGER_SHA256
  end

  def replace_once!(bytes, original, replacement, label)
    raise Failure, "#{label} transition count differs" unless bytes.scan(original).length == 1

    bytes.sub!(original, replacement)
  end

  def validate_review_disposition(root, ledger, admission:)
    disposition = ledger.fetch("review_disposition")
    expected = if admission == :admitted
      EXPECTED_REVIEW_DISPOSITION
    else
      EXPECTED_REVIEW_DISPOSITION.transform_values { "PENDING_PASS_2" }
    end
    expected.each do |role, value|
      raise Failure, "source review disposition differs: #{role}" unless
        disposition[role] == value
    end
    raise Failure, "executor responsibility differs" unless
      disposition["executor_responsibility"] == "retained"
    return unless admission == :admitted

    REVIEW_REPORTS.each do |role, relative|
      path = File.join(root, relative)
      raise Failure, "source review report missing: #{role}" unless
        File.file?(path) && !File.symlink?(path)
      text = File.binread(path).force_encoding(Encoding::UTF_8)
      raise Failure, "source review report is not UTF-8: #{role}" unless text.valid_encoding?
      raise Failure, "source review role differs: #{role}" unless
        text.include?("Role: `#{role}`")
      raise Failure, "source review baseline differs: #{role}" unless
        text.include?("Source candidate SHA-256: `#{REVIEWED_SOURCE_LEDGER_SHA256}`")
      raise Failure, "material review baseline differs: #{role}" unless
        text.include?(
          "Material projection SHA-256: `#{REVIEWED_MATERIAL_PROJECTION_SHA256}`"
        )
      raise Failure, "distribution review baseline differs: #{role}" unless
        text.include?(
          "Distribution projection SHA-256: `#{REVIEWED_DISTRIBUTION_PROJECTION_SHA256}`"
        )
      verdicts = text.scan(/^Verdict: `(PASS|FAIL)`$/).flatten
      raise Failure, "source review verdict differs: #{role}" unless verdicts == ["PASS"]
    end
  rescue KeyError => error
    raise Failure, "source review disposition missing key #{error.key}"
  end

  def validate_p05_data_inventory(root)
    data_root = File.join(root, "data/tokenization/p05")
    entries = Dir.glob(File.join(data_root, "**/*"), File::FNM_DOTMATCH).reject do |path|
      %w[. ..].include?(File.basename(path))
    end
    symlink = entries.find { |path| File.symlink?(path) }
    raise Failure, "P05 data symlink present: #{symlink}" unless symlink.nil?
    files = entries.select { |path| File.file?(path) }.map do |path|
      path.delete_prefix("#{root}/")
    end.sort
    raise Failure, "P05 data file set differs" unless files == EXPECTED_P05_DATA_FILES
  end

  def validate_contract(root)
    source = File.binread(File.join(root, "crates/lang-ptbr/src/tokenizer.rs"))
    %w[
      BoundaryOperation
      LogicalPart
      TokenClass
      TokenRule
      Tokenization
      is_admitted_ascii_punctuation
      is_cldr_number
      is_cldr_time
      unsupported_connector_end
      validate_rule_tables
    ].each do |contract|
      raise Failure, "tokenizer contract missing: #{contract}" unless source.include?(contract)
    end
    EXPECTED_RULES.each_key do |relative|
      include_path = relative.delete_prefix("data/")
      raise Failure, "derived rule table is not included: #{relative}" unless
        source.include?(include_path)
    end
    raise Failure, "rejected spaCy source remains in tokenizer" if
      source.downcase.include?("spacy")

    manifest = File.binread(File.join(root, "crates/lang-ptbr/Cargo.toml"))
    dependency_lines = manifest.lines.drop_while { |line| line.strip != "[dependencies]" }.drop(1)
    dependency_lines = dependency_lines.take_while { |line| !line.start_with?("[") }
    expected_dependencies = %w[nlu-core unicode-normalization.workspace unicode-segmentation.workspace]
    expected_dependencies.each do |dependency|
      raise Failure, "lang-ptbr dependency missing: #{dependency}" unless
        dependency_lines.any? { |line| line.include?(dependency) }
    end
  end

  def validate_requirements(root, require_satisfied:)
    traceability = File.binread(
      File.join(root, "docs/evidence/REQUIREMENTS-TRACEABILITY.md")
    )
    P05_REQUIREMENTS.each do |id|
      row = traceability.lines.find { |line| line.start_with?("| `#{id}` |") }
      raise Failure, "requirement row missing: #{id}" if row.nil?
      if require_satisfied && !row.rstrip.end_with?("| SATISFIED |")
        raise Failure, "requirement is not satisfied: #{id}"
      end
    end
  end

  def run_cargo_test(root)
    tool_bin = File.join(root, ".tools/rust-1.98.0/bin")
    environment = {
      "HOME" => "/var/empty",
      "PATH" => "#{tool_bin}:/usr/bin:/bin",
      "LC_ALL" => "C",
      "LANG" => "C",
      "TZ" => "UTC",
      "SOURCE_DATE_EPOCH" => "0",
      "CARGO_NET_OFFLINE" => "true",
      "CARGO_INCREMENTAL" => "0",
      "CARGO_TARGET_DIR" => File.join(root, "target/p05-gate"),
      "RUSTC" => File.join(tool_bin, "rustc")
    }
    output, status = Open3.capture2e(
      environment,
      File.join(tool_bin, "cargo"),
      "test",
      "-p",
      "lang-ptbr",
      "--all-features",
      chdir: root
    )
    return if status.success?

    warn output
    raise Failure, "lang-ptbr Cargo test failed"
  end
end

P05Validation.run(ARGV) if $PROGRAM_NAME == __FILE__
