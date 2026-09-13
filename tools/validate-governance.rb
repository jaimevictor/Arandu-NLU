# frozen_string_literal: true
# P02V3_RELEASE_LOADER_BOUNDARY_V1: aggregate SHA-256 governance only

require "cgi"
require "digest"
require "json"
require "open3"
require "optparse"
require "psych"
require "rbconfig"
require "set"
require "tmpdir"
require "uri"

class GovernanceError < StandardError; end
class DuplicateJsonKeyError < StandardError; end

class DuplicateRejectingJsonObject < Hash
  def []=(key, value)
    raise DuplicateJsonKeyError, key if key?(key)

    super
  end
end

class GovernanceValidator
  ENV_EXECUTABLE = "/usr/bin/env"
  GIT_EXECUTABLE = "/Library/Developer/CommandLineTools/usr/bin/git"
  PHASES = (0..16).map { |number| format("P%02d", number) }.freeze
  TERMINAL_PHASE = "FINAL"
  STEERING_PATH = "STEERING-NLU-PTBR-SOL-MAX.md"
  STEERING_BLOB_OID = "b817259579808ce7f62291f6ab34cc5c7dda849d"
  STEERING_SHA256 =
    "15196e479bee08f117cdf92094381bf8423546a251c5c67e47c76c0a3dbf5539"
  LICENSE_SHA256 =
    "c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4"
  NORMATIVE_ROWS_SHA256 =
    "b31121a383ffa6c2a45841c6e4c94066cbbf7174047cfa1fbd2737bb0fb5e7da"
  P00_REQUIREMENT_STATUSES_SHA256 =
    "9bc1d6861e8410b019e2fdb2fdbb59c06b740efd9e0f205b6120e828d6f2c507"
  MATERIALS_SHA256 =
    "1fb5683beeeb648a5e34d164aa82a06f9ad42c54197b0d294e55267e8260b75a"
  TOOLCHAIN_SHA256 =
    "668839e7fe6fb79ec5ab33e297f14346005f0ee90bdc625b3d773b4dde99de01"
  DISTRIBUTION_LICENSES_SHA256 =
    "4559a8e542fbf4c7cd627c3dac04fdc054b9fc6ebd8049b7306dce9823ab1965"
  P00_NORMATIVE_FILES_SHA256 =
    "b702f600916907fa27101e4b0c3b8bd16637f73986dfa19738948d501ce4dc95"
  P00_NEXT_ACTION = "validate_exact_P00_candidate_commit_and_tree_then_run_reviews"
  P00_BLOCKED_NEXT_ACTION =
    "request_explicit_user_scope_decision_for_exhausted_P00_round_budget"
  P00_BLOCKED_DEPENDENCY = "explicit_user_scope_decision"
  MAX_EMBEDDED_JSON_FRAGMENTS = 80
  MAX_EMBEDDED_JSON_CANDIDATES = 80
  MAX_EMBEDDED_JSON_DEPTH = 64
  MAX_PROVIDER_PAYLOAD_DEPTH = 8
  MAX_URL_CANDIDATES = 115
  MAX_URL_CANDIDATE_BYTES = 8192
  MAX_DECODE_PASSES = 64
  MAX_MARKDOWN_NESTING = 64
  MAX_YAML_ASSIGNMENT_BYTES = 8192
  MAX_YAML_ASSIGNMENT_LINES = 64
  MAX_YAML_AST_DEPTH = 64
  MAX_YAML_PAYLOAD_CANDIDATES = 256
  MAX_YAML_PAYLOAD_AGGREGATE_BYTES = 8_388_608
  MAX_REACHABLE_PRIVACY_BLOB_BYTES = 1_446_280
  MAX_REACHABLE_PRIVACY_TREE_ENTRIES = 262_144
  MAX_REACHABLE_PRIVACY_PATH_BYTES = 16_777_216
  BINARY_PATH_SUFFIXES = %w[
    .bin
    .db
    .fst
    .gz
    .jpg
    .png
    .xz
    .zip
  ].freeze
  YAML_BLOCK_PLAIN_KEY_SOURCE =
    '[^#\r\n](?:[^#\r\n]|(?<![ \t])#)*?'
  YAML_FLOW_PLAIN_KEY_SOURCE =
    '[^#{}\[\],:\r\n](?:[^#{}\[\],:\r\n]|(?<![ \t])#)*?'
  REVIEW_FILE_MODES = {
    "tools/test-validate-governance" => "100755",
    "tools/test-validate-governance.rb" => "100644",
    "tools/validate-governance" => "100755",
    "tools/validate-governance.rb" => "100644"
  }.freeze

  REQUIRED_FILES = %w[
    .gitattributes
    .gitignore
    AGENTS.md
    LICENSE
    LICENSING.md
    README.md
    docs/adr/ADR-0001-clean-room-and-foss-policy.md
    docs/adr/ADR-0002-product-scope-and-ha-coverage.md
    docs/adr/ADR-0003-rust-core-architecture.md
    docs/adr/ADR-0004-versioned-json-protocol.md
    docs/adr/ADR-0005-quality-performance-contract.md
    docs/adr/ADR-0006-baseline-and-review-evidence.md
    docs/adr/ADR-0007-home-assistant-integration-contract.md
    docs/adr/ADR-0008-deterministic-envelope.md
    docs/adr/README.md
    docs/clean-room/AMAZON-EXCLUSION-ALLOWLIST.yaml
    docs/clean-room/BOUNDARY.md
    docs/clean-room/DISTRIBUTION-LICENSES.yaml
    docs/clean-room/MATERIALS.yaml
    docs/clean-room/ROOT-INVENTORY.md
    docs/clean-room/SOPHIA-REFERENCE-STUDY.md
    docs/clean-room/SOURCE-POLICY.md
    docs/clean-room/USER-DECISIONS.md
    docs/evidence/P00-ENVIRONMENT.md
    docs/evidence/P00-VALIDATION.md
    docs/evidence/REQUIREMENTS-MANIFEST.yaml
    docs/evidence/REQUIREMENTS-TRACEABILITY.md
    docs/evidence/TOOLCHAIN-PROVENANCE.yaml
    docs/phases/AUTONOMOUS-QUEUE.yaml
    docs/phases/OPEN-DECISIONS.md
    docs/phases/P00-REPORT.md
    docs/phases/PROJECT-STATUS.md
    docs/reviews/P00/pre-phase-adversary.md
    docs/reviews/P00/pre-phase-architecture.md
    docs/reviews/P00/pre-phase-requirements.md
    docs/security/TRUST-BOUNDARIES.md
    tools/test-validate-governance
    tools/test-validate-governance.rb
    tools/validate-governance
    tools/validate-governance.rb
  ].freeze

  YAML_FILES = %w[
    docs/clean-room/AMAZON-EXCLUSION-ALLOWLIST.yaml
    docs/clean-room/DISTRIBUTION-LICENSES.yaml
    docs/clean-room/MATERIALS.yaml
    docs/evidence/REQUIREMENTS-MANIFEST.yaml
    docs/evidence/TOOLCHAIN-PROVENANCE.yaml
    docs/phases/AUTONOMOUS-QUEUE.yaml
    docs/phases/PROJECT-STATUS.md
  ].freeze

  BLOCKED_HOST_SUFFIXES = %w[
    a2z.com
    amazon.com
    amazon.dev
    amazoncognito.com
    amazonlinux.com
    amazonaws.com
    amazontrust.com
    aws.dev
    awsapps.com
    awsstatic.com
    cloudfront.net
    ecr.aws
    elasticbeanstalk.com
    on.aws
  ].freeze

  BLOCKED_GITHUB_OWNERS = %w[
    amazon
    amazon-archives
    amazon-ion
    amazon-science
    amazonwebservices
    aws
    aws-actions
    aws-crt
    aws-samples
    awslabs
    smithy-lang
  ].freeze

  APPROVED_REPOSITORY_OWNERS = Set.new(%w[
    3hren
    agl
    ajtribick
    alexhuszagh
    apple-oss-distributions
    astral-sh
    benjaminri
    birkenfeld
    briansmith
    burntsushi
    callum-oakley
    canop
    cesarb
    cryptjar
    cuviper
    dalek-cryptography
    djc
    dtolnay
    dtolnay-contrib
    e00e
    eeeebbbbrrrr
    elomatreb
    enarx
    explosion
    fizyk20
    fuuzetsu
    google
    haskell-cryptography
    home-assistant
    hyperium
    i509vcb
    jamesmunns
    japaric
    jeffa5
    libreoffice
    lokathor
    lr-por
    madsmtm
    manishearth
    mcginty
    mit-plv
    mitsuhiko
    mongodb
    noiseprotocol
    not-a-seagull
    oxidecomputer
    p3ki
    paholg
    pulldown-cmark
    rhasspy
    roaringbitmap
    ron-rs
    rotty
    ruby
    rust-embedded-community
    rust-fuzz
    rust-lang
    rust-lang-nursery
    rust-num
    rust-random
    rustcrypto
    rustsec
    rwf2
    saethlin
    serde-rs
    sergiobenitez
    signalapp
    slightlyoutofphase
    softprops
    soveu
    spdx
    ulfjack
    unicode-org
    unicode-rs
    universaldependencies
    user-attachments
    veorq
    yaml
  ]).freeze

  MATERIAL_IDS = %w[
    steering-v3
    sophia-public-claims
    aquila-ha-voice-test-suite
    home-assistant-intents
    ud-portuguese-bosque
    libreoffice-pt-br-dictionary
    rhasspy-official-pt-br-profile
    home-assistant-core-2026.8.3
    home-assistant-core-2026.8.3-p10-catalog
    wyoming-protocol
    cpython-3.14.6-p13-transport
    openssl-3.6.3-p13-transport
    noise-protocol-revision-34-p13-transport
    snow-0.10.0-p13-transport-closure
    cacophony-vector-p13-snow-projection-removal
    project-poly1305-soft-p13
    rust-num-pow-origin-p13
    rust-pr49000-array-origin-p13
    pulldown-redwood-relicense-origin-p13
    tracing-hyperium-origin-p13
    chacha20-0.9.1-p13-source-projection
    home-assistant-official-addons
    home-assistant-addon-example
    home-assistant-developer-docs
    rust-stable-manifest-mutable
    rust-1.98.0-manifest
    rust-source-license-review
    rustc-1.98.0-source-p13
    spdx-license-list-xml-p13
    p01-rust-protocol-dependency-closure
    rustsec-advisory-db-p01
    creative-commons-by-4.0-legalcode-p13
    rustup-1.29.0
    ruby-2.6.10-source
    psych-3.1.0-source
    libyaml-0.2.1-source
    git-2.50.1-source
    shell-cmds-329-env
    unicode-character-database-17.0.0
    unicode-character-database-17.0.0-p05-punctuation
    p04-unicode-dependency-closure
    ud-portuguese-docs-bdd95cf
    spacy-portuguese-exceptions-26b4d1d
    cldr-48-acd6d88
    home-assistant-core-2026.9.1-p15-candidate
  ].freeze

  P00_NORMATIVE_FILES = (
    REQUIRED_FILES - ["tools/validate-governance.rb"]
  ).freeze

  CREDENTIAL_KEYS = Set.new(%w[
    access_token
    api_key
    api_token
    auth_token
    authorization
    bearer
    bearer_token
    client_secret
    hassio_token
    oauth_token
    password
    secret
    secret_key
    refresh_token
    supervisor_token
    token
  ]).freeze
  CANONICAL_CREDENTIAL_KEYS = Set.new(
    (CREDENTIAL_KEYS.to_a + %w[AWS_SECRET_ACCESS_KEY]).map do |key|
      key.downcase.gsub(/[^a-z0-9]/, "")
    end
  ).freeze

  RESIDENTIAL_KEYS = Set.new(%w[
    alias
    aliases
    area_id
    catalog
    device_id
    display_name
    entity_id
    floor_id
    friendly_name
    person_id
    resident
    resident_name
    room_name
    session_state
    transcript
    utterance
  ]).freeze
  CANONICAL_RESIDENTIAL_KEYS = Set.new(
    RESIDENTIAL_KEYS.map { |key| key.downcase.gsub(/[^a-z0-9]/, "") }
  ).freeze
  PROTECTED_PROVIDER_KEYS = Set.new(%w[provider owner upstreamowner]).freeze
  PROTECTED_STRUCTURED_KEYS = (
    CANONICAL_CREDENTIAL_KEYS |
    CANONICAL_RESIDENTIAL_KEYS |
    PROTECTED_PROVIDER_KEYS
  ).freeze
  SENSITIVE_CONTENT_EXEMPT_PATHS = Set.new(%w[
    tools/test-validate-governance.rb
    tools/validate-governance.rb
  ]).freeze
  REVIEWED_HISTORICAL_SENSITIVE_BLOB_SHA256 = {
    "538d3e94d2235e7665f6773525a38dfa1e1962cd" =>
      "2918feebc7c54e5694cb96455d37590ea18edd65a780b8038547cef37b6872bb",
    "9cb4e46d0d809171091ebbdc93cf9b39fdc540cd" =>
      "413ff6530828361f8f81deed06a71612709620c4bead2e3a9327783d61c8cb58"
  }.freeze
  GOVERNED_SYNTHETIC_DATA_SHA256 = {
    "data/manifests/project-authored-synthetic-ptbr-v1.json" =>
      "d9e1ca32ec0f92aa6b5fc6c1d4f232f93389e0bf8031267d23daddf7287006c5",
    "data/project-authored/p02-v1/manifest.json" =>
      "a251485ba2f8d5032603200b7e171954213383aeceac9a8f394edb09a265e72a",
    "data/project-authored/p02-v1/specification.yaml" =>
      "f72451f03d1a5e2e4955b5d2857bd7d33b3b012912d920e53a3d85719f14859d",
    "data/project-authored/p02-v1/development.jsonl" =>
      "75400570ddfc7196ed982da98dcf49c4e6bda5820200a2fefd93a8ea6f049161",
    "data/project-authored/p02-v1/heldout.jsonl" =>
      "1b3e3669ba3e64193b769bccf90368f571daae5b4f3d9ed88724c99bec12c6da",
    "data/project-authored/p02-v1/performance.jsonl" =>
      "1c9fedff6a3bc7aa36e5f343eb85ce2f197ce0d5c44cd514fe1c5b08a03ba55b",
    "data/project-authored/p02-v1/suites/ambiguity.jsonl" =>
      "098051c102bfdf9ede0781d8c1069546cb2db1d9265b4d1e2b3d2123ea1c7721",
    "data/project-authored/p02-v1/suites/contradiction.jsonl" =>
      "9a2c53626b74ad0479fd81bd91d0a41a027db2eb53eb37b6efcc2066a67689a8",
    "data/project-authored/p02-v1/suites/explicit-negative.jsonl" =>
      "9c90a3f399a988d3714a611cf04fda1d60cd5be2b311d06cf957915bb3f53ebb",
    "data/project-authored/p02-v1/suites/safety-sensitive.jsonl" =>
      "8d06bbfbcaf48cf729fd24fb7330c4b6a50a5d016addbf8517ae0356c5b5f261",
    "data/project-authored/p02-v1/suites/stale-state.jsonl" =>
      "1d5d8c8f490ee546ee6fd7d8e165bbb6d6d926ccaedaa8484a47546aa6b96e27",
    "data/project-authored/p02-v1/train.jsonl" =>
      "23d2bc8c8fcde80d1a9560d42219484bc34e9198c791ccadf5d4b56413a81b64",
    "data/project-authored/p02-v2/manifest.json" =>
      "f0b4a28b15496f65a71207e4129abc64bac25a2e45770157afd8f2f7866a20ae",
    "data/project-authored/p02-v2/specification.json" =>
      "3af92370fa0654c00f8a109c62ee15c97b9ff0eec86483de261216cb3905e7eb",
    "data/project-authored/p02-v2/development.jsonl" =>
      "08d8b1d33bf551337a90bde94727964fbf8f7de54de32e646d1758ce58ab89f1",
    "data/project-authored/p02-v2/heldout.jsonl" =>
      "9767b413bf1eff0e2e1ec97f94c39f9d89c8e65743d2f53d502c56dd60f9276d",
    "data/project-authored/p02-v2/performance.jsonl" =>
      "2baef9e3a906848c32ae5a0586d7c09c62d5380b891972edb46797cd054e269f",
    "data/project-authored/p02-v2/suites/ambiguity.jsonl" =>
      "4ac86651828f2a6b065eb6b65295031544b3da83a21abaa11a94142cbf9df13f",
    "data/project-authored/p02-v2/suites/contradiction.jsonl" =>
      "bd2e8b0d3a0bb924fa8f862284131237e5b5848e171817d4681a8f28752ff645",
    "data/project-authored/p02-v2/suites/explicit-negative.jsonl" =>
      "ed0b7ce78961ee34a6b9fe2597fcdd8e58e3a0638ce2ef5e25c0311779875ab8",
    "data/project-authored/p02-v2/suites/safety-sensitive.jsonl" =>
      "5685f966384fd46451a2463e985f266d7abcf5b06a5608cbd7dc85f1a3340d28",
    "data/project-authored/p02-v2/suites/stale-state.jsonl" =>
      "c93a360293907f96fb1e4522a7d558ea2cb5ca59abee7c8b989131550e179bbe",
    "data/project-authored/p02-v2/train.jsonl" =>
      "f15226a107c7bedb27b28e5880b65f24fb832a4b3d62ba67c6569a99b2aad183",
    "data/project-authored/p02-v3/manifest.json" =>
      "6f9e186db0dcda321cf7895b1043d98b1fa23dc5713537ab47154c0e28bec88d",
    "data/project-authored/p02-v3/specification.json" =>
      "32198119a097794a34e11637468e079d30c19f23f0b71a91ebf72b214c26d205",
    "data/project-authored/p02-v3/development.jsonl" =>
      "7852c0b1f7e7edc430bcff4107291e25c418993b38e190f8c47e098a45fc777c",
    "data/project-authored/p02-v3/heldout.jsonl" =>
      "f83aa6b2f8679419b1ee54eb61e636b6548315260c07a900162996f7c2252045",
    "data/project-authored/p02-v3/performance.jsonl" =>
      "da49417068d9982a8f422c4a09bf17a64a5c62caf4fae4bf7226fc5d33946b6a",
    "data/project-authored/p02-v3/suites/ambiguity.jsonl" =>
      "1a78a023a993432244ef1c36c9706274e2c912c1131822815863119c2386538e",
    "data/project-authored/p02-v3/suites/contradiction.jsonl" =>
      "d7e561f12a77c962c4b8133086730053458edd841dd3c02804880ef6cbce7e62",
    "data/project-authored/p02-v3/suites/explicit-negative.jsonl" =>
      "4808add1aa616036d2fb4082dcdd5cd77cd78feaeeed302793ff136d9997d15f",
    "data/project-authored/p02-v3/suites/safety-sensitive.jsonl" =>
      "bc52daa8c5035ccbd4eed0b6f51575d2d14cd03b64096e0868cabf02efabc9b5",
    "data/project-authored/p02-v3/suites/stale-state.jsonl" =>
      "429c73211cdaf3edc24e3a4d0721b9ce611ad6172540b54ff8e37ab4386f422c",
    "data/project-authored/p02-v3/train.jsonl" =>
      "076e4f58ed3f6d930c148ddc47943deb83a1501e2a942a80f1f9fad25465611d",
    "data/project-authored/p11-v1/development.jsonl" =>
      "daca8033117351caee07ac9697ab49877ca240f896985418c6c7325680772675",
    "data/project-authored/p11-v1/specification.json" =>
      "4fcb15395026ad4c543ba4739c48e2ebe371a959c546c7ced39c3010a7b34b7a",
    "data/project-authored/p11-v1/train.jsonl" =>
      "8b00c1af9aedb2ff6c946bf24c0a538b97ee8f9f882a4da901b91ba9f4432b8d",
    "schemas/data-source-manifest-v1.schema.json" =>
      "f4b4436e7a4301fe038fc93f635185b614a9171c82814651e541862bc594ef2d",
    "schemas/p02-case-v1.schema.json" =>
      "0bf2452e408225439b67e93030e90d864ea8d97dce74aa24b81c13a29f960bd2",
    "schemas/p02-suite-case-v1.schema.json" =>
      "1f7985604fb9908fdd6b2b4984ffc06e13002ec0f02e9d44825727f933afe0db"
  }.freeze

  APPROVED_SOFTWARE_LICENSES = Set.new([
    "Apache-2.0",
    "BSD-2-Clause",
    "BSD-2-Clause AND BSD-3-Clause",
    "GPL-2.0-only",
    "MIT",
    "MIT OR Apache-2.0",
    "Ruby OR BSD-2-Clause"
  ]).freeze

  CRITICAL_REQUIREMENT_TEXT = {
    "USR-001" => "Do not build or require an external supervisor script.",
    "USR-004" => "Obtain public requirements and contract evidence independently.",
    "USR-008" => "Use only free and open-source project inputs and dependencies.",
    "USR-009" => "Exclude Amazon-specific and Amazon-internal material.",
    "USR-010" =>
      "Limit every phase to three substantive frozen candidate review rounds: one initial round and at most two blocker-remediation rounds.",
    "USR-011" =>
      "Require the documented minimum acceptance contract for every phase.",
    "USR-012" =>
      "Checkpoint the first minimally acceptable baseline immediately without optional refinement.",
    "USR-013" =>
      "Defer eligible P3 improvements instead of extending a phase review loop.",
    "USR-014" =>
      "Stop a phase as blocked for explicit user scope adjudication when its round budget is exhausted with a P0 through P2 blocker.",
    "USR-015" =>
      "Limit remaining P00 work from 2026-08-26 to the current candidate and at most one blocker-only replacement.",
    "USR-016" =>
      "Permit a deterministic project-authored synthetic PT-BR conformance corpus with labels fixed before NLU implementation, while prohibiting independent-accuracy or Sophia-equivalence claims from it.",
    "USR-017" =>
      "Permit one P12 evidence-only proof candidate after the three substantive rounds, limited to independently proving the already-implemented generation bindings.",
    "USR-018" =>
      "Permit a documented feasible secret-memory compromise when an admitted FOSS runtime cannot prove that every transient transport-secret copy is individually locked and zeroized.",
    "USR-036" =>
      "Finish P13 through one minimum correction of the six source and governance defects reproduced on `a4a4f904b68447abcc6d24f00fc87b6aba8634f3`, then advance directly to P14 and continue to 100%.",
    "USR-037" =>
      "Finish P13 through one consolidated correction of the source-review defects reproduced on `89cb007efc15a67b3f2c9af1af8973a7026538fa`, then advance directly to P14 and continue to 100%.",
    "USR-038" =>
      "After mandatory review of `edf6e2c888c841c423f42a19c110072f3b6f7ec7` reproduced bounded validator and evidence defects, finish P13 through one minimum blocker-only correction and advance directly to P14.",
    "USR-039" =>
      "After mandatory review of `95d0eda79737d1be180f69f7560d51e619f84758` reproduced only final bounded source-discovery, governance, and existing-tree verification blockers, finish P13 immediately through one minimum correction and advance directly to P14.",
    "USR-040" =>
      "Keep P13 closed, stop all P13 patches, and advance immediately through the remaining project with the safest bounded workaround where the current host cannot execute a phase gate.",
    "USR-041" =>
      "After P14 exhausted its candidate budget with reproduced P0-P2 blockers, permit one exceptional integrated blocker-only correction and continue to 100%.",
    "USR-042" =>
      "After all six mandatory reviews of the `USR-041` subject failed, authorize one terminal integrated P14 correction and continue the project.",
    "USR-043" =>
      "After all six mandatory reviews of the `USR-042` subject failed, authorize one last integrated P14 blocker-remediation pass and then move on.",
    "USR-044" =>
      "Move to P15 now without claiming P14 passed.",
    "USR-045" =>
      "Reopen P14 and P15 after the blocked qualification checkpoint, freeze a fresh untouched project-authored synthetic evaluation lineage before behavior changes, correct the reproduced safety and zero-plan blockers, and continue through native release qualification.",
    "USR-046" =>
      "Invalidate P02-v2 after the recorded post-remediation performance-record exposure, freeze a clean P02-v3 lineage before reapplying remediation, and continue through P15, P16, and FINAL.",
    "USR-047" =>
      "Continue autonomously through P15, P16, and FINAL without further scope prompts; authorize the exhausted P02-v3 blocker-only replacement and all remaining in-scope blocker remediation.",
    "P00-CR-004" =>
      "Prohibit closed-engine code, binaries, models, vocabulary, private formats, traces, outputs, internal behavior, internal names, and heuristics.",
    "P00-FOSS-001" => "Require OSI-approved software licenses.",
    "P00-FOSS-002" => "Require modifiable and commercially redistributable data licenses.",
    "P00-AMZ-001" => "Reject Amazon-specific sources regardless of license.",
    "P00-AMZ-002" => "Reject Amazon-internal tools, endpoints, credentials, and data.",
    "RUN-QUAL-001" => "Give quality priority over cost, speed, and token volume.",
    "AGT-PROFILE-001" =>
      "Use the configured `gpt-5.6-sol` maximum-reasoning profile for the executor and substantial agents."
  }.freeze

  EXPECTED_AMAZON_ALLOWLIST = {
    "docs/clean-room/MATERIALS.yaml" => "structured_rejected_exposure_evidence",
    "docs/evidence/P00-ENVIRONMENT.md" => "rejected_package_attestation",
    "docs/evidence/P01-TOOLCHAIN.md" =>
      "public_toolchain_exclusion_attestation",
    "docs/evidence/P01-DEPENDENCIES.yaml" =>
      "public_dependency_exclusion_attestation",
    "docs/evidence/P01-ADVISORIES.md" =>
      "public_advisory_source_exclusion_attestation",
    "docs/evidence/TOOLCHAIN-PROVENANCE.yaml" => "structured_rejected_tool_evidence",
    "tests/p14_ha/test_real_ha_gate.py" => "prohibited_import_guard",
    "tools/test-validate-governance.rb" => "negative_regression_fixtures",
    "tools/validate-governance.rb" => "scanner_patterns"
  }.freeze

  REQUIREMENT_STATUSES = %w[REVIEW_PENDING PENDING SATISFIED WAIVED].freeze
  MATERIAL_STATES = %w[
    SEED_USER_SPECIFICATION
    OPEN_REFERENCE
    EXTERNAL_CLAIM_ONLY
    EXPOSURE_REJECTED
    QUARANTINED_CANDIDATE
    PROJECT_AUTHORED_QUARANTINED_CANDIDATE
    QUARANTINED_SOURCE_REVIEW_EVIDENCE
    REJECTED_SOURCE_PORTFOLIO
    VERIFIED_REMOVED_NOT_ADMITTED
    ADMITTED_AUTONOMOUS
    REJECTED
  ].freeze

  def initialize(
    root:,
    expected_commit:,
    expected_tree:,
    expected_normative_rows_sha256:,
    expected_review_file_sha256:,
    launcher_path:
  )
    @root = File.expand_path(root)
    @expected_commit = expected_commit
    @expected_tree = expected_tree
    @expected_normative_rows_sha256 = expected_normative_rows_sha256
    @expected_review_file_sha256 = expected_review_file_sha256
    @launcher_path = File.expand_path(launcher_path)
    @yaml = {}
  end

  def validate
    validate_arguments
    validate_git_subject
    validate_required_files
    load_yaml_documents
    validate_requirements
    validate_adrs
    validate_materials
    validate_toolchain
    validate_distribution_licenses
    validate_state
    validate_amazon_exclusion
    validate_sensitive_tree
    validate_p00_path_set
    validate_normative_files
    validate_archive

    puts(
      "governance validation passed " \
      "(commit #{@expected_commit}, tree #{@expected_tree}, " \
      "rows #{@expected_normative_rows_sha256}, " \
      "#{requirement_rows.length} requirements)"
    )
  rescue GovernanceError
    raise
  rescue StandardError => error
    fail!("unexpected internal error: #{error.class}")
  end

  private

  def fail!(message)
    raise GovernanceError, message
  end

  def validate_arguments
    fail!("repository root does not exist: #{@root}") unless Dir.exist?(@root)
    unless @expected_commit.is_a?(String) &&
           @expected_commit.match?(/\A[0-9a-f]{40}\z/)
      fail!("expected commit must be a full lowercase Git object ID")
    end
    unless @expected_tree.is_a?(String) &&
           @expected_tree.match?(/\A[0-9a-f]{40}\z/)
      fail!("expected tree must be a full lowercase Git object ID")
    end
    unless @expected_normative_rows_sha256.is_a?(String) &&
           @expected_normative_rows_sha256.match?(/\A[0-9a-f]{64}\z/)
      fail!("expected normative-row SHA-256 must be 64 lowercase hexadecimal characters")
    end
    unless @expected_review_file_sha256.is_a?(Hash) &&
           @expected_review_file_sha256.keys.sort == REVIEW_FILE_MODES.keys.sort
      fail!("expected review-file SHA-256 tuple is incomplete")
    end
    @expected_review_file_sha256.each do |path, digest|
      unless digest.is_a?(String) && digest.match?(/\A[0-9a-f]{64}\z/)
        fail!("expected review-file SHA-256 is invalid for #{path}")
      end
    end
  end

  def command(
    *argv,
    allow_failure: false,
    binary: false,
    chdir: @root,
    stdin_data: nil
  )
    stdout, stderr, status = Open3.capture3(
      {
        "HOME" => "/var/empty",
        "XDG_CONFIG_HOME" => "/var/empty",
        "LC_ALL" => "C",
        "LANG" => "C",
        "TZ" => "UTC",
        "RUBYOPT" => nil,
        "RUBYLIB" => nil,
        "GEM_HOME" => nil,
        "GEM_PATH" => nil,
        "BUNDLE_GEMFILE" => nil,
        "GIT_CONFIG_NOSYSTEM" => "1",
        "GIT_CONFIG_GLOBAL" => "/dev/null",
        "GIT_ATTR_NOSYSTEM" => "1",
        "GIT_OPTIONAL_LOCKS" => "0",
        "GIT_NO_REPLACE_OBJECTS" => "1",
        "GIT_DIR" => nil,
        "GIT_WORK_TREE" => nil,
        "GIT_INDEX_FILE" => nil,
        "GIT_OBJECT_DIRECTORY" => nil,
        "GIT_ALTERNATE_OBJECT_DIRECTORIES" => nil
      },
      *argv,
      chdir: chdir,
      stdin_data: stdin_data.to_s
    )
    stdout = stdout.b if binary
    return [stdout, stderr, status] if allow_failure

    unless status.success?
      detail = stderr.strip
      detail = stdout.strip if detail.empty?
      fail!("command failed (#{argv.join(' ')}): #{detail}")
    end
    stdout
  end

  def git(*args, **options)
    command(
      GIT_EXECUTABLE,
      "-c", "core.fsmonitor=false",
      "-c", "core.untrackedCache=false",
      *args,
      **options
    )
  end

  def validate_git_subject
    inside = git("rev-parse", "--is-inside-work-tree").strip
    fail!("root is not a Git worktree") unless inside == "true"

    head = git("rev-parse", "HEAD").strip
    tree = git("rev-parse", "HEAD^{tree}").strip
    fail!("HEAD #{head} does not match expected commit #{@expected_commit}") unless head == @expected_commit
    fail!("tree #{tree} does not match expected tree #{@expected_tree}") unless tree == @expected_tree

    status = git("status", "--porcelain=v1", "--untracked-files=all")
    fail!("review subject has staged, unstaged, or untracked changes") unless status.empty?

    index_entries = git("ls-files", "-v", "-z", binary: true).split("\0").reject(&:empty?)
    concealed = index_entries.reject { |entry| entry.start_with?("H ") }
    unless concealed.empty?
      paths = concealed.map { |entry| entry.byteslice(2..-1) }
      fail!("review subject has skip-worktree, assume-unchanged, or unsupported index flags: #{paths.join(', ')}")
    end
    validate_subject_worktree_bytes

    object_type = git("cat-file", "-t", @expected_commit).strip
    fail!("expected commit is not a commit object") unless object_type == "commit"

    roots = git("rev-list", "--max-parents=0", @expected_commit).lines.map(&:strip)
    fail!("candidate history must have exactly one clean root") unless roots.length == 1
    @clean_root_commit = roots.first

    reachable_entries = git("rev-list", "--objects", @expected_commit).lines.map do |line|
      line.strip.split(" ", 2)
    end
    reachable_objects = reachable_entries.map(&:first)
    if reachable_objects.include?(STEERING_BLOB_OID)
      fail!("NOASSERTION steering blob is reachable from the candidate history")
    end
    if reachable_entries.any? { |_object, path| path == STEERING_PATH }
      fail!("NOASSERTION steering path is reachable from the candidate history")
    end

    git("show", "--check", "--format=", "--no-renames", @expected_commit)
    git("fsck", "--full", "--strict")

    local_steering = File.join(@root, STEERING_PATH)
    if File.file?(local_steering)
      actual_hash = Digest::SHA256.file(local_steering).hexdigest
      fail!("local ignored steering hash changed") unless actual_hash == STEERING_SHA256
    end
  end

  def validate_subject_worktree_bytes
    canonical_root = File.realpath(@root)
    tracked_entries.each do |entry|
      next unless entry.fetch("type") == "blob" &&
                  %w[100644 100755].include?(entry.fetch("mode"))

      path = entry.fetch("path")
      worktree_path = File.join(@root, path)
      stat = File.lstat(worktree_path)
      expected_executable = entry.fetch("mode") == "100755"
      actual_executable = (stat.mode & 0o111).positive?
      unless stat.file? && !stat.symlink? &&
             File.realpath(worktree_path) == File.join(canonical_root, path) &&
             actual_executable == expected_executable &&
             File.binread(worktree_path) == read(path, binary: true)
        fail!("review subject worktree file differs from committed bytes or mode: #{path}")
      end
    end
  rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
    fail!("review subject worktree file cannot be read safely")
  end

  def tracked_entries
    @tracked_entries ||= begin
      output = git("ls-tree", "-r", "-z", "--full-tree", @expected_commit, binary: true)
      output.split("\0").reject(&:empty?).map do |entry|
        metadata, path = entry.split("\t", 2)
        mode, type, object = metadata.split(" ", 3)
        fail!("malformed git tree entry") unless path && mode && type && object
        { "mode" => mode, "type" => type, "object" => object, "path" => path }
      end
    end
  end

  def tracked_paths
    @tracked_paths ||= tracked_entries.map { |entry| entry.fetch("path") }
  end

  def validate_required_files
    missing = REQUIRED_FILES - tracked_paths
    fail!("missing required tracked files: #{missing.join(', ')}") unless missing.empty?
    fail!("steering file is present in current tracked tree") if tracked_paths.include?(STEERING_PATH)

    bad_modes = tracked_entries.reject do |entry|
      entry.fetch("type") == "blob" && %w[100644 100755].include?(entry.fetch("mode"))
    end
    unless bad_modes.empty?
      fail!("non-regular or symlink entries found: #{bad_modes.map { |entry| entry['path'] }.join(', ')}")
    end

    validate_review_file_bindings

    tracked_paths.each do |path|
      content = read(path, binary: true)
      if BINARY_PATH_SUFFIXES.any? { |suffix| path.end_with?(suffix) }
        next
      end
      fail!("binary NUL byte is prohibited in a text path: #{path}") if content.include?("\0")
      content.force_encoding(Encoding::UTF_8)
      fail!("file is not valid UTF-8: #{path}") unless content.valid_encoding?
    end
  end

  def read(path, binary: false)
    content = git("show", "#{@expected_commit}:#{path}", binary: true)
    return content if binary

    content.force_encoding(Encoding::UTF_8)
    fail!("file is not valid UTF-8: #{path}") unless content.valid_encoding?
    content
  end

  def validate_review_file_bindings
    canonical_launcher = File.join(@root, "tools/validate-governance")
    canonical_validator = File.join(@root, "tools/validate-governance.rb")
    unless File.realpath(@launcher_path) == File.realpath(canonical_launcher)
      fail!("executing launcher path is not canonical")
    end
    unless File.realpath(File.expand_path(__FILE__)) ==
           File.realpath(canonical_validator)
      fail!("executing validator path is not canonical")
    end

    REVIEW_FILE_MODES.each do |path, expected_mode|
      entry = tracked_entries.find { |candidate| candidate.fetch("path") == path }
      fail!("review file is absent from the subject: #{path}") unless entry
      unless entry.fetch("type") == "blob" && entry.fetch("mode") == expected_mode
        fail!("review file mode differs from the review tuple: #{path}")
      end

      committed = read(path, binary: true)
      expected_hash = @expected_review_file_sha256.fetch(path)
      unless Digest::SHA256.hexdigest(committed) == expected_hash
        fail!("committed review file differs from the review tuple: #{path}")
      end

      worktree_path = File.join(@root, path)
      stat = File.lstat(worktree_path)
      unless stat.file? && !stat.symlink?
        fail!("worktree review file is not a regular file: #{path}")
      end
      canonical_worktree_path = File.join(File.realpath(@root), path)
      unless File.realpath(worktree_path) == canonical_worktree_path
        fail!("worktree review file resolves outside its canonical path: #{path}")
      end
      worktree = File.binread(worktree_path)
      unless worktree == committed &&
             Digest::SHA256.hexdigest(worktree) == expected_hash
        fail!("worktree review file bytes differ from committed tuple bytes: #{path}")
      end
    rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
      fail!("worktree review file cannot be read safely: #{path}")
    end
  end

  def load_yaml_documents
    YAML_FILES.each { |path| @yaml[path] = strict_yaml(path) }
  end

  def strict_yaml(path)
    content = read(path)
    stream = Psych.parse_stream(content, path)
    fail!("YAML must contain exactly one document: #{path}") unless stream.children.length == 1
    reject_unsafe_yaml(stream, path)
    value = Psych.safe_load(content, [], [], false, path, symbolize_names: false)
    reject_non_string_yaml_keys(value, path)
    value
  rescue Psych::Exception, SystemStackError => error
    fail!("invalid YAML in #{path}: #{error.message}")
  end

  def reject_unsafe_yaml(
    node,
    path,
    depth = 0,
    extended_string_keys: false
  )
    fail!("YAML AST exceeds depth limit in #{path}") if depth > MAX_YAML_AST_DEPTH
    if node.is_a?(Psych::Nodes::Alias)
      fail!("YAML aliases are prohibited in #{path}")
    end
    if node.respond_to?(:anchor) && node.anchor
      fail!("YAML anchors are prohibited in #{path}")
    end

    if node.is_a?(Psych::Nodes::Mapping)
      keys = Set.new
      node.children.each_slice(2) do |key, value|
        fail!("non-scalar YAML key in #{path}") unless key.is_a?(Psych::Nodes::Scalar)
        fail!("YAML anchors are prohibited in #{path}") if key.anchor
        if key.tag && key.tag != "tag:yaml.org,2002:str"
          fail!("tagged YAML mapping key is prohibited in #{path}")
        end
        if key.value == "<<"
          fail!("YAML merge keys are prohibited in #{path}")
        end
        unless extended_string_keys ||
               key.value.match?(/\A[A-Za-z_][A-Za-z0-9_.-]*\z/)
          fail!("non-string-safe YAML key #{key.value.inspect} in #{path}")
        end
        fail!("duplicate YAML key #{key.value.inspect} in #{path}") unless keys.add?(key.value)
        reject_unsafe_yaml(
          value,
          path,
          depth + 1,
          extended_string_keys: extended_string_keys
        )
      end
    else
      if node.respond_to?(:children)
        Array(node.children).each do |child|
          reject_unsafe_yaml(
            child,
            path,
            depth + 1,
            extended_string_keys: extended_string_keys
          )
        end
      end
    end
  end

  def reject_non_string_yaml_keys(value, path, context = "$", depth = 0)
    fail!("YAML value exceeds depth limit in #{path}") if depth > MAX_YAML_AST_DEPTH
    case value
    when Hash
      value.each do |key, nested|
        unless key.is_a?(String)
          fail!("non-string semantic YAML key #{key.inspect} at #{context} in #{path}")
        end
        reject_non_string_yaml_keys(nested, path, "#{context}.#{key}", depth + 1)
      end
    when Array
      value.each_with_index do |nested, index|
        reject_non_string_yaml_keys(
          nested,
          path,
          "#{context}[#{index}]",
          depth + 1
        )
      end
    end
  end

  def exact_keys!(value, keys, context)
    fail!("#{context} must be a mapping") unless value.is_a?(Hash)
    actual = value.keys.map(&:to_s).sort
    expected = keys.map(&:to_s).sort
    return if actual == expected

    fail!("#{context} fields differ: expected #{expected.inspect}, got #{actual.inspect}")
  end

  def nonempty_string!(value, context)
    fail!("#{context} must be a nonempty string") unless value.is_a?(String) && !value.strip.empty?
  end

  def array_of_strings!(value, context)
    fail!("#{context} must be an array") unless value.is_a?(Array)
    value.each_with_index { |entry, index| nonempty_string!(entry, "#{context}[#{index}]") }
  end

  def requirement_rows
    @requirement_rows ||= begin
      rows = {}
      read("docs/evidence/REQUIREMENTS-TRACEABILITY.md").each_line.with_index(1) do |line, number|
        next unless line.start_with?("| `")

        columns = line.chomp.split("|", -1)
        fail!("malformed requirement row at line #{number}") unless columns.length == 9
        values = columns[1..7].map(&:strip)
        raw_id, source, requirement, owner, verification, evidence, status = values
        match = raw_id.match(/\A`([A-Z][A-Z0-9-]*-\d{3})`\z/)
        fail!("malformed requirement ID at line #{number}") unless match
        id = match[1]
        fail!("duplicate requirement ID #{id}") if rows.key?(id)

        [source, requirement, owner, verification, evidence].each_with_index do |value, index|
          fail!("empty requirement column #{index + 2} for #{id}") if value.empty?
        end
        fail!("invalid requirement status for #{id}: #{status}") unless REQUIREMENT_STATUSES.include?(status)
        validate_requirement_owner!(id, owner)

        phase = id[/\AP(\d{2})-/, 1]
        if phase && !owner.split(", ").any? { |part| owner_covers_phase?(part, "P#{phase}") }
          fail!("requirement #{id} is not owned by its phase: #{owner}")
        end
        if id.start_with?("FINAL-") && owner != "FINAL"
          fail!("final requirement #{id} must be owned by FINAL")
        end

        rows[id] = {
          "source" => source,
          "requirement" => requirement,
          "owner" => owner,
          "verification" => verification,
          "evidence" => evidence,
          "status" => status
        }
      end
      rows
    end
  end

  def user_decision_ids
    user_decision_ids_from_bytes(
      read("docs/clean-room/USER-DECISIONS.md")
    )
  end

  def user_decision_ids_from_bytes(bytes)
    ids = bytes.each_line.each_with_object([]) do |line, result|
      candidate_cell = user_decision_candidate_cell(line)
      next unless candidate_cell&.match?(
        /\A(?:(?:`+|\*+|_+|~+|<code(?:[ \t][^>]*)?>)[ \t]*)*USR(?=[-_0-9])/i
      )

      columns = markdown_table_columns(line)
      first = columns&.first&.strip
      match = first&.match(/\A`(USR-\d{3})`\z/)
      fail!("malformed user decision row") unless
        match &&
        columns.length == 5 &&
        columns.all? { |column| !column.strip.empty? }
      result << match[1]
    end
    fail!("duplicate user decision ID") unless ids.uniq.length == ids.length
    ids
  end

  def user_decision_candidate_cell(line)
    bytes = line.chomp.sub(/\A[ \t]*/, "").sub(/[ \t]*\z/, "")
    return nil unless bytes.start_with?("|") || bytes.end_with?("|")

    bytes = bytes.byteslice(1..) if bytes.start_with?("|")
    current = +""
    escaped = false
    bytes.each_char do |character|
      break if character == "|" && !escaped

      current << character
      escaped = character == "\\" && !escaped
      escaped = false unless character == "\\"
    end
    current.strip
  end

  def markdown_table_columns(line)
    bytes = line.chomp.sub(/\A[ \t]*/, "").sub(/[ \t]*\z/, "")
    return nil unless bytes.start_with?("|")
    return nil unless bytes.end_with?("|")

    columns = []
    current = +""
    escaped = false
    bytes.byteslice(1, bytes.bytesize - 2).each_char do |character|
      if character == "|" && !escaped
        columns << current
        current = +""
      else
        current << character
      end
      escaped = character == "\\" && !escaped
      escaped = false unless character == "\\"
    end
    columns << current
    columns
  end

  def owner_covers_phase?(owner, phase)
    return true if owner == "All" || owner == "all phases"
    return owner == phase unless owner.include?("-")

    first, last = owner.split("-", 2).map { |item| item.delete_prefix("P").to_i }
    number = phase.delete_prefix("P").to_i
    number.between?(first, last)
  end

  def validate_requirement_owner!(id, owner)
    parts = owner.split(", ")
    fail!("invalid owner syntax for #{id}: #{owner}") if parts.empty?
    parts.each do |part|
      next if %w[All all\ phases FINAL].include?(part)
      if part.match?(/\AP\d{2}\z/)
        fail!("undefined phase owner for #{id}: #{part}") unless PHASES.include?(part)
        next
      end
      range = part.match(/\A(P\d{2})-(P\d{2})\z/)
      fail!("invalid owner syntax for #{id}: #{owner}") unless range
      first = PHASES.index(range[1])
      last = PHASES.index(range[2])
      fail!("undefined phase range for #{id}: #{part}") unless first && last
      fail!("reversed phase range for #{id}: #{part}") if first > last
    end
  end

  def validate_requirements
    manifest = @yaml.fetch("docs/evidence/REQUIREMENTS-MANIFEST.yaml")
    exact_keys!(
      manifest,
      %w[
        schema_version
        required_ids
        normative_rows_sha256
        p00_statuses_sha256
        required_text
      ],
      "requirement manifest"
    )
    fail!("unsupported requirement manifest version") unless manifest["schema_version"] == 2
    array_of_strings!(manifest["required_ids"], "required_ids")
    fail!("duplicate IDs in requirement manifest") unless manifest["required_ids"].uniq.length == manifest["required_ids"].length

    actual_ids = requirement_rows.keys
    expected_ids = manifest["required_ids"]
    unless actual_ids == expected_ids
      missing = expected_ids - actual_ids
      extra = actual_ids - expected_ids
      fail!("requirement IDs differ (missing: #{missing.inspect}; extra: #{extra.inspect}; order changed: #{missing.empty? && extra.empty?})")
    end

    traced_user_ids = actual_ids.grep(/\AUSR-\d{3}\z/)
    decisions = user_decision_ids
    unless decisions == traced_user_ids
      missing = decisions - traced_user_ids
      extra = traced_user_ids - decisions
      fail!("user decision and traceability IDs differ (missing: #{missing.inspect}; extra: #{extra.inspect}; order changed: #{missing.empty? && extra.empty?})")
    end
    expected_user_ids = (1..decisions.length).map do |number|
      format("USR-%03d", number)
    end
    fail!("user decision IDs are not contiguous") unless
      decisions == expected_user_ids

    unless manifest["required_text"] == CRITICAL_REQUIREMENT_TEXT
      fail!("critical requirement text manifest differs from the enforced contract")
    end
    CRITICAL_REQUIREMENT_TEXT.each do |id, text|
      actual = requirement_rows.fetch(id).fetch("requirement")
      fail!("normative requirement text changed for #{id}") unless actual == text
    end

    canonical_rows = expected_ids.map do |id|
      row = requirement_rows.fetch(id)
      [
        id,
        row.fetch("source"),
        row.fetch("requirement"),
        row.fetch("owner"),
        row.fetch("verification"),
        row.fetch("evidence")
      ].join("\t")
    end.join("\n") + "\n"
    actual_digest = Digest::SHA256.hexdigest(canonical_rows)
    unless @expected_normative_rows_sha256 == NORMATIVE_ROWS_SHA256
      fail!("review tuple normative-row digest differs from the validator contract")
    end
    unless manifest["normative_rows_sha256"] == NORMATIVE_ROWS_SHA256
      fail!("requirement manifest differs from the validator's normative-row digest")
    end
    unless actual_digest == NORMATIVE_ROWS_SHA256
      fail!("normative requirement rows differ from the validator's frozen digest")
    end

    canonical_statuses = expected_ids.map do |id|
      "#{id}\t#{requirement_rows.fetch(id).fetch('status')}"
    end.join("\n") + "\n"
    actual_status_digest = Digest::SHA256.hexdigest(canonical_statuses)
    unless manifest["p00_statuses_sha256"] == P00_REQUIREMENT_STATUSES_SHA256
      fail!("requirement manifest differs from the validator's P00 status digest")
    end
    unless actual_status_digest == P00_REQUIREMENT_STATUSES_SHA256
      fail!("P00 requirement lifecycle statuses differ from the frozen status set")
    end

    current_phase = @yaml.fetch("docs/phases/PROJECT-STATUS.md").fetch("current_phase")
    requirement_rows.each do |id, row|
      status = row.fetch("status")
      if current_phase == "P00" && status == "SATISFIED"
        fail!("requirement #{id} cannot be SATISFIED during P00 review")
      end
      if status == "REVIEW_PENDING"
        owners = row.fetch("owner").split(", ")
        unless owners.any? { |owner| owner_covers_phase?(owner, current_phase) }
          fail!("requirement #{id} is REVIEW_PENDING outside its owner phase")
        end
        if current_phase == "P00" && owners != ["P00"]
          fail!("requirement #{id} is REVIEW_PENDING but not owned exclusively by P00")
        end
      end
      allowed_user_waivers = %w[USR-005 USR-006]
      if status == "WAIVED" &&
         !id.start_with?("P00-REV-") &&
         !allowed_user_waivers.include?(id)
        fail!("requirement is not eligible for an explicit user waiver: #{id}")
      end
      if status == "WAIVED" && current_phase == "P00"
        fail!("P00 review requirements cannot be waived before closeout")
      end
      if current_phase == "P00" &&
         status == "PENDING" &&
         row.fetch("owner") == "P00" &&
         !id.start_with?("P00-REV-")
        fail!("implemented P00 requirement #{id} is not awaiting review")
      end
    end
  end

  def validate_adrs
    index = read("docs/adr/README.md")
    indexed = {}
    index.each_line.with_index(1) do |line, number|
      next unless line.match?(/\A\| \[\d{4}\]/)

      columns = line.chomp.split("|", -1).map(&:strip)
      fail!("malformed ADR index row at line #{number}") unless columns.length == 5
      match = columns[1].match(/\A\[(\d{4})\]\((ADR-\1-[^)]+\.md)\)\z/)
      fail!("malformed ADR index link at line #{number}") unless match
      id = match[1]
      fail!("duplicate ADR index entry #{id}") if indexed.key?(id)
      indexed[id] = { "path" => "docs/adr/#{match[2]}", "status" => columns[3] }
    end

    files = tracked_paths.grep(%r{\Adocs/adr/ADR-[^/]+\.md\z}).sort
    indexed_paths = indexed.values.map { |entry| entry.fetch("path") }.sort
    fail!("ADR index does not exactly match ADR files") unless indexed_paths == files
    expected_ids = (1..indexed.length).map { |number| format("%04d", number) }
    fail!("ADR IDs are not contiguous from 0001") unless
      indexed.length >= 8 && indexed.keys == expected_ids

    indexed.each do |id, entry|
      statuses = read(entry.fetch("path")).scan(/^- Status: `([^`]+)`\s*$/).flatten
      fail!("ADR #{id} must have exactly one canonical status") unless statuses.length == 1
      status = statuses.first
      fail!("ADR #{id} status differs from index") unless status == entry.fetch("status")
      fail!("ADR #{id} is not accepted") unless status == "ACCEPTED_AUTONOMOUS"
    end
  end

  def validate_materials
    materials = @yaml.fetch("docs/clean-room/MATERIALS.yaml")
    current_phase =
      @yaml.fetch("docs/phases/PROJECT-STATUS.md").fetch("current_phase")
    exact_keys!(materials, %w[schema_version as_of materials], "materials ledger")
    fail!("unsupported materials schema") unless materials["schema_version"] == 1
    fail!("materials must be an array") unless materials["materials"].is_a?(Array)

    ids = Set.new
    materials["materials"].each_with_index do |material, index|
      fail!("material #{index} must be a mapping") unless material.is_a?(Hash)
      %w[id status provider allowed_use].each do |field|
        nonempty_string!(material[field], "material #{index} #{field}")
      end
      license_fields = %w[
        license
        repository_license_claim
        license_claim
        original_license
        license_text_rights
      ].select { |field| material.key?(field) }
      unless license_fields.length == 1
        fail!("material #{index} must have exactly one primary license field")
      end
      nonempty_string!(
        material.fetch(license_fields.first),
        "material #{index} #{license_fields.first}"
      )
      fail!("duplicate material ID #{material['id']}") unless ids.add?(material["id"])
      fail!("unknown material state #{material['status']}") unless MATERIAL_STATES.include?(material["status"])
      validate_material_identity_fields(
        material,
        "material #{material['id']}"
      )
      validate_contract_paths(material)

      if amazon_specific_record?(material) &&
         !%w[REJECTED EXPOSURE_REJECTED].include?(material["status"])
        fail!("Amazon-specific material is not in a rejected state: #{material['id']}")
      end
      unless %w[REJECTED EXPOSURE_REJECTED].include?(material["status"])
        validate_approved_repository_owners!(
          material,
          "material #{material['id']}"
        )
      end
      if material["status"] == "PROJECT_AUTHORED_QUARANTINED_CANDIDATE"
        nonempty_string!(
          material["source_path"],
          "project-authored material #{material['id']} source_path"
        )
      elsif material["status"] != "SEED_USER_SPECIFICATION"
        unless %w[canonical_url urls resources canonical_evidence].any? do |field|
                 material.key?(field)
               end
          fail!("external material #{material['id']} lacks a canonical source identity")
        end
      end
      if material.key?("resources")
        fail!("material #{material['id']} resources must be a nonempty array") unless material["resources"].is_a?(Array) && !material["resources"].empty?
        material["resources"].each_with_index do |resource, resource_index|
          exact_keys!(
            resource,
            %w[canonical_url retrieved_body_size retrieved_body_sha256],
            "material #{material['id']} resource #{resource_index}"
          )
          nonempty_string!(resource["canonical_url"], "material #{material['id']} resource URL")
          unless resource["retrieved_body_size"].is_a?(Integer) && resource["retrieved_body_size"].positive?
            fail!("material #{material['id']} resource size is invalid")
          end
          unless resource["retrieved_body_sha256"].is_a?(String) &&
                 resource["retrieved_body_sha256"].match?(/\A[0-9a-f]{64}\z/)
            fail!("material #{material['id']} resource hash is invalid")
          end
        end
      end
      if material["status"] == "OPEN_REFERENCE"
        if prohibited_open_license?(material["license"])
          fail!("open reference #{material['id']} has an ineligible license")
        end
        commit_fields = material.select { |field, _value| field == "commit" || field.end_with?("_commit") }
        fail!("open reference #{material['id']} lacks an immutable commit") if commit_fields.empty?
        license_hashes = material.select { |field, _value| field.include?("license") && field.end_with?("sha256") }
        fail!("open reference #{material['id']} lacks a full license hash") if license_hashes.empty?
      end
      if %w[REJECTED EXPOSURE_REJECTED].include?(material["status"])
        fail!("rejected material #{material['id']} must have allowed_use: none") unless material["allowed_use"] == "none"
        reason_fields = %w[rejection_reason rejection_reasons].select do |field|
          material.key?(field)
        end
        unless reason_fields.length == 1
          fail!(
            "rejected material #{material['id']} must have exactly one " \
            "rejection reason field"
          )
        end
        if reason_fields.first == "rejection_reason"
          nonempty_string!(
            material["rejection_reason"],
            "rejected material #{material['id']} rejection_reason"
          )
        else
          reasons = material["rejection_reasons"]
          unless reasons.is_a?(Array) && !reasons.empty?
            fail!(
              "rejected material #{material['id']} rejection_reasons " \
              "must be a nonempty array"
            )
          end
          reasons.each_with_index do |reason, index|
            nonempty_string!(
              reason,
              "rejected material #{material['id']} rejection_reasons #{index}"
            )
          end
        end
      end
      if material["status"] == "QUARANTINED_CANDIDATE"
        approved_quarantine_uses = %w[
          toolchain_selection_only
          P13_source_admission_review_and_isolated_candidate_probe_only
          P13_offline_toolchain_source_review_and_verification_only
          P13_selected_Rust_source_license_classification_only
          P15_source_and_license_admission_review_only
          authoritative_terms_for_RustSec_CC_BY_4_0_exception_resolution
        ]
        unless approved_quarantine_uses.include?(material["allowed_use"])
          fail!("quarantined material #{material['id']} declares a prohibited allowed use")
        end
      end
      if material["status"] == "ADMITTED_AUTONOMOUS" &&
         !admitted_material_allowed?(current_phase)
        fail!("P00 cannot contain admitted autonomous material")
      end
    end

    actual_ids = materials["materials"].map { |material| material.fetch("id") }
    unless actual_ids == MATERIAL_IDS
      fail!("material identities differ from the approved set")
    end
    unless canonical_digest(materials) == MATERIALS_SHA256
      fail!("material ledger differs from the approved canonical digest")
    end
  end

  def prohibited_open_license?(license)
    !license.is_a?(String) || !APPROVED_SOFTWARE_LICENSES.include?(license)
  end

  def admitted_material_allowed?(current_phase)
    current_phase != "P00"
  end

  def validate_material_identity_fields(value, context)
    case value
    when Hash
      value.each do |field, nested|
        name = field.to_s
        if name.end_with?("sha256")
          valid_hash =
            nested.is_a?(String) &&
            nested.match?(/\A[0-9a-f]{64}\z/)
          valid_hashes =
            nested.is_a?(Array) &&
            !nested.empty? &&
            nested.all? do |item|
              item.is_a?(String) && item.match?(/\A[0-9a-f]{64}\z/)
            end
          unless valid_hash || valid_hashes
            fail!("#{context} has invalid SHA-256 field #{name}")
          end
        end
        if (name == "commit" || name.end_with?("_commit")) &&
           (!nested.is_a?(String) || !nested.match?(/\A[0-9a-f]{40}\z/))
          fail!("#{context} has invalid commit field #{name}")
        end
        validate_material_identity_fields(nested, "#{context}.#{name}")
      end
    when Array
      value.each_with_index do |nested, index|
        validate_material_identity_fields(nested, "#{context}[#{index}]")
      end
    end
  end

  def validate_contract_paths(material)
    return unless material.key?("contract_paths")

    paths = material["contract_paths"]
    unless paths.is_a?(Array) && !paths.empty?
      fail!("material #{material['id']} contract_paths must be a nonempty array")
    end
    identities = Set.new
    paths.each_with_index do |entry, index|
      expected_fields =
        entry.is_a?(Hash) && entry.key?("bytes") ?
          %w[path bytes sha256] :
          %w[path sha256]
      exact_keys!(
        entry,
        expected_fields,
        "material #{material['id']} contract path #{index}"
      )
      nonempty_string!(
        entry["path"],
        "material #{material['id']} contract path #{index} path"
      )
      if entry.key?("bytes") &&
         (!entry["bytes"].is_a?(Integer) || !entry["bytes"].positive?)
        fail!("material #{material['id']} contract path #{index} bytes is invalid")
      end
      if entry["path"].start_with?("/") ||
         entry["path"].split("/").include?("..")
        fail!("material #{material['id']} has an unsafe contract path")
      end
      unless identities.add?(entry["path"])
        fail!("material #{material['id']} has duplicate contract paths")
      end
    end
  end

  def validate_toolchain
    toolchain = @yaml.fetch("docs/evidence/TOOLCHAIN-PROVENANCE.yaml")
    exact_keys!(
      toolchain,
      %w[
        schema_version
        observed_at
        required_validation_tools
        required_validation_command_set
        host_platform_boundary
        selected_build_toolchain_candidate
        rejected_tools
        constraints
      ],
      "toolchain provenance"
    )
    fail!("unsupported toolchain schema") unless toolchain["schema_version"] == 6
    fail!("required_validation_tools must be an array") unless toolchain["required_validation_tools"].is_a?(Array)

    tools = toolchain["required_validation_tools"]
    tools.each_with_index do |tool, index|
      fail!("tool record #{index} must be a mapping") unless tool.is_a?(Hash)
    end
    names = tools.map { |tool| tool["name"] }
    unless names == %w[env ruby psych libyaml git]
      fail!("validator tool inventory must be env, ruby, psych, libyaml, and git")
    end
    expected_commands = [
      "tools/validate-governance",
      "tools/test-validate-governance",
      ENV_EXECUTABLE,
      "/usr/bin/ruby",
      GIT_EXECUTABLE
    ]
    unless toolchain["required_validation_command_set"] == expected_commands
      fail!("validator command set must use the attested absolute Ruby and Git paths")
    end

    tools.each do |tool|
      %w[
        name
        type
        version
        provider
        source_url
        source_commit
        license
        purpose
        shipped
      ].each do |field|
        fail!("tool #{tool['name'] || '<unknown>'} lacks #{field}") unless tool.key?(field)
      end
      %w[name type version provider source_url source_commit license purpose].each do |field|
        nonempty_string!(tool[field], "tool #{tool['name'] || '<unknown>'} #{field}")
      end
      nonempty_string!(tool["provider"], "tool #{tool['name']} provider")
      nonempty_string!(tool["source_url"], "tool #{tool['name']} source_url")
      nonempty_string!(tool["license"], "tool #{tool['name']} license")
      unless APPROVED_SOFTWARE_LICENSES.include?(tool["license"])
        fail!("tool #{tool['name']} does not use an approved software license")
      end
      rights = tool["rights_evidence"]
      exact_keys!(
        rights,
        %w[
          upstream_owner
          rightsholders
          rightsholder_basis
          license_scope
          obligations
          commercial_use_and_modification
          redistribution_rights
        ],
        "tool #{tool['name']} rights evidence"
      )
      %w[
        upstream_owner
        rightsholder_basis
        license_scope
        obligations
        commercial_use_and_modification
        redistribution_rights
      ].each do |field|
        nonempty_string!(rights[field], "tool #{tool['name']} rights evidence #{field}")
      end
      array_of_strings!(rights["rightsholders"], "tool #{tool['name']} rightsholders")
      unless rights["commercial_use_and_modification"] == "permitted"
        fail!("tool #{tool['name']} lacks commercial modification rights")
      end
      unless rights["redistribution_rights"] == "permitted"
        fail!("tool #{tool['name']} lacks redistribution rights")
      end
      unless tool["independent_review_roles"] ==
             %w[review-requirements review-risk review-repro]
        fail!("tool #{tool['name']} independent review roles differ")
      end
      unless tool["source_commit"].is_a?(String) &&
             tool["source_commit"].match?(/\A[0-9a-f]{40}\z/)
        fail!("tool #{tool['name']} source_commit must be a full object ID")
      end
      license_hash_fields = %w[
        license_file_sha256
        license_header_bundle_sha256
      ].select { |field| tool.key?(field) }
      unless license_hash_fields.length == 1
        fail!("tool #{tool['name']} must have exactly one license evidence hash")
      end
      license_hash = tool.fetch(license_hash_fields.first)
      unless license_hash.is_a?(String) &&
             license_hash.match?(/\A[0-9a-f]{64}\z/)
        fail!("tool #{tool['name']} license hash must be a SHA-256")
      end
      fail!("validator tools are not shipped") unless tool["shipped"] == false
      if amazon_specific_record?(
        "name" => tool["name"],
        "provider" => tool["provider"],
        "source_url" => tool["source_url"]
      )
        fail!("Amazon-specific validator tool is prohibited: #{tool['name']}")
      end
      validate_approved_repository_owners!(tool, "validator tool #{tool['name']}")
    end

    env_tool = tools.fetch(0)
    ruby = tools.fetch(1)
    psych = tools.fetch(2)
    libyaml = tools.fetch(3)
    git_tool = tools.fetch(4)
    unless env_tool["executable_path"] == ENV_EXECUTABLE
      fail!("attested env path differs from the launcher env path")
    end
    validate_executable_hash(env_tool)
    identity_marker = env_tool["identity_marker"]
    nonempty_string!(identity_marker, "tool env identity_marker")
    unless File.binread(ENV_EXECUTABLE).include?(identity_marker)
      fail!("env executable identity marker differs from inventory")
    end
    validate_executable_identity(ruby, /^ruby #{Regexp.escape(ruby['version'].split('p').first)}/)
    validate_runtime_library_identity(
      ruby,
      "configured_runtime_path",
      "configured_runtime_sha256",
      expected_path: RbConfig.ruby
    )
    fail!("Psych runtime version differs from inventory") unless Psych::VERSION == psych["version"]
    psych_extension = $LOADED_FEATURES.find { |path| path.match?(/psych.*\.(?:bundle|so)\z/) }
    fail!("loaded Psych native extension cannot be identified") unless psych_extension
    validate_runtime_library_identity(
      psych,
      "extension_path",
      "extension_sha256",
      expected_path: psych_extension
    )
    actual_libyaml = Psych.libyaml_version.join(".")
    fail!("libyaml runtime version differs from inventory") unless actual_libyaml == libyaml["version"]
    validate_runtime_library_identity(
      libyaml,
      "embedded_binary_path",
      "embedded_binary_sha256",
      expected_path: psych_extension
    )
    unless git_tool["executable_path"] == GIT_EXECUTABLE
      fail!("attested Git path differs from the validator Git path")
    end
    validate_executable_identity(git_tool, /^git version #{Regexp.escape(git_tool['version'])}$/)
    validate_runtime_library_identity(
      git_tool,
      "dispatch_shim_path",
      "dispatch_shim_sha256",
      expected_path: "/usr/bin/git"
    )

    host = toolchain["host_platform_boundary"]
    exact_keys!(
      host,
      %w[
        classification
        operating_system
        product_version
        build_version
        architecture
        shipped
        project_dependency
        binary_source_correspondence_claimed
        dynamic_components
        statement
      ],
      "host platform boundary"
    )
    unless host["classification"] == "validation_host_prerequisite_not_project_input" &&
           host["shipped"] == false &&
           host["project_dependency"] == false &&
           host["binary_source_correspondence_claimed"] == false
      fail!("host platform boundary overstates project provenance")
    end
    array_of_strings!(host["dynamic_components"], "host dynamic components")

    constraints = toolchain["constraints"]
    expected_constraints = %w[
      amazon_specific_tools_used
      amazon_internal_tools_used
      private_registry_required
      ai_service_required_for_build_test_or_runtime
      credentials_required_for_build
    ]
    exact_keys!(constraints, expected_constraints, "toolchain constraints")
    constraints.each do |name, value|
      fail!("toolchain constraint #{name} must be false") unless value == false
    end

    candidate = toolchain["selected_build_toolchain_candidate"]
    fail!("selected build toolchain candidate must be a mapping") unless candidate.is_a?(Hash)
    exact_keys!(
      candidate,
      %w[
        name
        version
        provider
        license
        source_url
        source_commit
        manifest_url
        manifest_size
        manifest_sha256
        target
        archive_url
        archive_sha256
        install_method
        status
        admitted_at
        manifest_verified
        archive_verified
        source_archive
        installation
        active_source_closure
        installed_executables
        installed_runtime_libraries
        ambient_sdk_input
        p01_validation_runtime
        license_evidence
        invocation_policy
      ],
      "selected build toolchain candidate"
    )
    unless candidate["source_commit"].is_a?(String) &&
           candidate["source_commit"].match?(/\A[0-9a-f]{40}\z/)
      fail!("selected build toolchain source commit is invalid")
    end
    %w[manifest_sha256 archive_sha256].each do |field|
      unless candidate[field].is_a?(String) &&
             candidate[field].match?(/\A[0-9a-f]{64}\z/)
        fail!("selected build toolchain #{field} is invalid")
      end
    end
    unless candidate["manifest_size"].is_a?(Integer) && candidate["manifest_size"].positive?
      fail!("selected build toolchain manifest_size is invalid")
    end
    unless candidate["status"] == "ADMITTED_P01_BUILD_TOOLCHAIN"
      fail!("selected build toolchain admission status differs")
    end
    if amazon_specific_record?(candidate)
      fail!("selected build toolchain candidate is Amazon-specific")
    end
    validate_approved_repository_owners!(candidate, "selected build toolchain")
    unless APPROVED_SOFTWARE_LICENSES.include?(candidate["license"])
      fail!("selected build toolchain candidate license is not approved")
    end
    unless canonical_digest(toolchain) == TOOLCHAIN_SHA256
      fail!("toolchain ledger differs from the approved canonical digest")
    end
  end

  def validate_executable_identity(tool, version_pattern)
    validate_executable_hash(tool)
    path = tool["executable_path"]
    version = command(path, "--version").strip
    fail!("#{tool['name']} version differs from inventory: #{version}") unless version.match?(version_pattern)
  end

  def validate_executable_hash(tool)
    %w[executable_path executable_sha256].each do |field|
      nonempty_string!(tool[field], "tool #{tool['name']} #{field}")
    end
    path = tool["executable_path"]
    fail!("recorded executable is absent: #{path}") unless File.file?(path) && File.executable?(path)
    actual_hash = Digest::SHA256.file(path).hexdigest
    fail!("#{tool['name']} executable hash differs from inventory") unless actual_hash == tool["executable_sha256"]
  end

  def validate_runtime_library_identity(tool, path_field, hash_field, expected_path:)
    nonempty_string!(tool[path_field], "tool #{tool['name']} #{path_field}")
    nonempty_string!(tool[hash_field], "tool #{tool['name']} #{hash_field}")
    fail!("#{tool['name']} runtime path differs from inventory") unless tool[path_field] == expected_path
    fail!("#{tool['name']} runtime file is absent") unless File.file?(expected_path)
    actual_hash = Digest::SHA256.file(expected_path).hexdigest
    fail!("#{tool['name']} runtime hash differs from inventory") unless actual_hash == tool[hash_field]
  end

  def validate_distribution_licenses
    distribution = @yaml.fetch("docs/clean-room/DISTRIBUTION-LICENSES.yaml")
    exact_keys!(
      distribution,
      %w[schema_version path_rules excluded_inputs release_rules],
      "distribution license manifest"
    )
    fail!("unsupported distribution license schema") unless
      distribution["schema_version"] == 4

    rules = distribution["path_rules"]
    fail!("path_rules must be a nonempty array") unless rules.is_a?(Array) && !rules.empty?
    path_owners = Hash.new { |hash, path| hash[path] = [] }
    required_rule_fields = %w[
      classification
      origin_id
      license
      license_files
      copyright
      path_prefixes
      paths
    ]
    optional_rule_fields = %w[
      source_evidence
      additional_source_evidence
      compatibility_decision
    ]
    rules.each_with_index do |rule, index|
      exact_keys!(
        rule,
        required_rule_fields +
          optional_rule_fields.select { |field| rule.key?(field) },
        "distribution path rule #{index}"
      )
      nonempty_string!(rule["classification"], "distribution rule classification")
      nonempty_string!(rule["origin_id"], "distribution rule origin_id")
      nonempty_string!(rule["license"], "distribution rule license")
      if rule["classification"] == "project_authored" &&
         rule["license"] != "Apache-2.0"
        fail!("tracked distribution paths must use Apache-2.0")
      end
      array_of_strings!(rule["license_files"], "distribution rule license_files")
      fail!("distribution rule license_files must not be empty") if
        rule["license_files"].empty?
      array_of_strings!(
        rule["path_prefixes"],
        "distribution rule path_prefixes"
      )
      array_of_strings!(rule["paths"], "distribution rule paths")
      optional_rule_fields.each do |field|
        nonempty_string!(rule[field], "distribution rule #{field}") if
          rule.key?(field)
      end
      rule["path_prefixes"].each do |prefix|
        if prefix.start_with?("/") ||
           prefix.split("/").include?("..") ||
           !prefix.end_with?("/")
          fail!("distribution rule contains an unsafe path prefix")
        end
      end
      selected = Set.new(rule["paths"])
      rule["path_prefixes"].each do |prefix|
        tracked_paths.each do |path|
          selected << path if path.start_with?(prefix)
        end
      end
      selected.each { |path| path_owners[path] << index }
    end
    expected_origins = [
      %w[project_authored project-authored Apache-2.0],
      %w[
        third_party_documentation_and_derived_rules
        ud-portuguese-docs-bdd95cf
        Apache-2.0
      ],
      %w[
        third_party_locale_data_and_derived_rules
        cldr-48-acd6d88
        Unicode-3.0
      ],
      %w[
        third_party_unicode_conformance_data
        unicode-character-database-17.0.0
        Unicode-3.0
      ],
      %w[canonical_license_text apache-license-2.0-text Apache-2.0],
      ["third_party_vendored_source", "crates-io-itoa-1.0.18",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-memchr-2.8.3",
       "Unlicense OR MIT"],
      ["third_party_vendored_source", "crates-io-proc-macro2-1.0.107",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-quote-1.0.47",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-ryu-1.0.23",
       "Apache-2.0 OR BSL-1.0"],
      ["third_party_vendored_source", "crates-io-serde-1.0.228",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-serde-core-1.0.228",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-serde-derive-1.0.228",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-serde-json-1.0.145",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-syn-2.0.119",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-unicode-ident-1.0.24",
       "(MIT OR Apache-2.0) AND Unicode-3.0"],
      ["third_party_vendored_source", "crates-io-tinyvec-1.12.0",
       "Zlib OR Apache-2.0 OR MIT"],
      ["third_party_vendored_source", "crates-io-tinyvec-macros-0.1.1",
       "MIT OR Apache-2.0 OR Zlib"],
      ["third_party_vendored_source",
       "crates-io-unicode-normalization-0.1.25",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source",
       "crates-io-unicode-segmentation-1.13.3",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-aead-0.5.2",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-blake2-0.10.6",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-block-buffer-0.10.4",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-cfg-if-1.0.1",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-chacha20-0.9.1",
       "Apache-2.0 OR MIT"],
      ["third_party_vendored_source",
       "crates-io-chacha20poly1305-0.10.1", "Apache-2.0 OR MIT"],
      ["third_party_vendored_source", "crates-io-cipher-0.4.4",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-cpufeatures-0.2.17",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-crypto-common-0.1.6",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source",
       "crates-io-curve25519-dalek-4.1.3", "BSD-3-Clause"],
      ["third_party_vendored_source", "crates-io-digest-0.10.7",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-generic-array-0.14.7",
       "MIT"],
      ["third_party_vendored_source", "crates-io-inout-0.1.4",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-opaque-debug-0.3.1",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-poly1305-0.8.0",
       "Apache-2.0 OR MIT"],
      ["third_party_vendored_source", "crates-io-rustc-version-0.4.1",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-semver-1.0.26",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-snow-0.10.0",
       "Apache-2.0 OR MIT"],
      ["third_party_vendored_source", "crates-io-subtle-2.6.1",
       "BSD-3-Clause"],
      ["third_party_vendored_source", "crates-io-typenum-1.18.0",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-universal-hash-0.5.1",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-version-check-0.9.5",
       "MIT OR Apache-2.0"],
      ["third_party_vendored_source", "crates-io-zeroize-1.8.1",
       "Apache-2.0 OR MIT"]
    ]
    actual_origins = rules.map do |rule|
      rule.values_at("classification", "origin_id", "license")
    end
    fail!("distribution origins differ from the approved set") unless
      actual_origins == expected_origins
    duplicates = path_owners.select do |_path, owners|
      owners.length > 1
    end.keys
    fail!("paths have multiple distribution license rules: #{duplicates.inspect}") unless
      duplicates.empty?
    licensed_paths = path_owners.keys
    unless licensed_paths.sort_by(&:b) == tracked_paths.sort_by(&:b)
      missing = tracked_paths - licensed_paths
      extra = licensed_paths - tracked_paths
      fail!("distribution license paths differ from tracked tree (missing: #{missing.inspect}; extra: #{extra.inspect})")
    end

    excluded = distribution["excluded_inputs"]
    fail!("excluded_inputs must contain only the steering file") unless excluded.is_a?(Array) && excluded.length == 1
    steering = excluded.first
    fail!("excluded steering entry must be a mapping") unless steering.is_a?(Hash)
    fail!("excluded steering path differs") unless steering["path"] == STEERING_PATH
    fail!("excluded steering must remain NOASSERTION") unless steering["license"] == "NOASSERTION"
    fail!("excluded steering is tracked") if tracked_paths.include?(STEERING_PATH)

    release_rules = distribution["release_rules"]
    expected_rules = %w[
      reject_tracked_noassertion
      reject_unmatched_tracked_paths
      reject_unbound_origins
      reject_excluded_input_in_archive
    ]
    exact_keys!(release_rules, expected_rules, "distribution release rules")
    release_rules.each do |name, value|
      fail!("distribution release rule #{name} must be true") unless value == true
    end

    license_hash = Digest::SHA256.hexdigest(read("LICENSE", binary: true))
    fail!("project Apache-2.0 license bytes changed") unless license_hash == LICENSE_SHA256
    unless canonical_digest(distribution) == DISTRIBUTION_LICENSES_SHA256
      fail!("distribution license manifest differs from canonical digest")
    end
  end

  def validate_state
    status = @yaml.fetch("docs/phases/PROJECT-STATUS.md")
    queue = @yaml.fetch("docs/phases/AUTONOMOUS-QUEUE.yaml")
    exact_keys!(
      status,
      %w[
        mode
        bootstrap
        current_phase
        state
        seed_commit
        subject_baseline
        evidence_checkpoint
        completed_phases
        open_findings
        deferred_external_validations
        last_validation
        terminal_state
      ],
      "project status"
    )
    exact_keys!(
      queue,
      %w[
        goal
        terminal_guard
        active_item
        next_action
        queued_items
        waiting_internal_dependencies
        last_checkpoint
      ],
      "autonomous queue"
    )

    fail!("unexpected project mode") unless status["mode"] == "AUTONOMOUS_SOL_MAX"
    fail!("unexpected bootstrap mode") unless status["bootstrap"] == "FRESH_IMPLEMENTATION"
    fail!("clean root commit differs") unless status["seed_commit"] == @clean_root_commit
    fail!("unexpected queue goal") unless queue["goal"] == "DEVELOPMENT_COMPLETE"
    fail!("terminal guard must remain armed before terminal state") unless queue["terminal_guard"] == "ARMED"
    nonempty_string!(queue["next_action"], "queue next_action")
    array_of_strings!(status["completed_phases"], "completed_phases")
    array_of_strings!(status["open_findings"], "open_findings")
    fail!("deferred_external_validations must be an array") unless status["deferred_external_validations"].is_a?(Array)
    fail!("waiting_internal_dependencies must be an array") unless queue["waiting_internal_dependencies"].is_a?(Array)

    current = status["current_phase"]
    fail!("current phase is invalid") unless (PHASES + [TERMINAL_PHASE]).include?(current)
    fail!("queue active item differs from current phase") unless queue["active_item"] == current
    index = current == TERMINAL_PHASE ? PHASES.length : PHASES.index(current)
    expected_completed = PHASES.first(index)
    fail!("completed phases contradict current phase") unless status["completed_phases"] == expected_completed
    expected_queue = PHASES.drop(index + 1) + [TERMINAL_PHASE]
    fail!("queued phases contradict current phase") unless queue["queued_items"] == expected_queue

    allowed_states = %w[
      PRE_PHASE_ANALYSIS
      SOURCE_DISCOVERY
      SOURCE_FALLBACK_PROTOTYPE
      IMPLEMENTATION
      IMPLEMENTING
      REVIEWING
      REMEDIATING
      PHASE_PASSED
      BLOCKED
    ]
    fail!("nonterminal state is invalid") unless allowed_states.include?(status["state"])
    fail!("terminal_state must be null before FINAL") unless status["terminal_state"].nil?
    if current == "P00"
      validate_p00_lifecycle_state(status, queue)
    else
      validate_post_p00_lifecycle_state(status, queue, current, index)
    end
    if status["state"] == "REVIEWING"
      fail!("reviewing candidate must use self-resolving subject marker") unless status["subject_baseline"] == "SELF_AT_CANDIDATE_COMMIT"
      fail!("reviewing candidate cannot retain open findings") unless status["open_findings"].empty?
    end
    if current == "P00"
      validation_timestamp = read("docs/evidence/P00-VALIDATION.md")[
        /^- Pre-freeze execution: (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)$/,
        1
      ]
      unless validation_timestamp &&
             status["last_validation"] == validation_timestamp
        fail!("last_validation differs from P00 validation evidence")
      end
    else
      validation = status["last_validation"]
      match = validation&.match(
        /\AP(\d{2})_[A-Z0-9_]+_(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\z/
      )
      allowed_validation_phases = [index - 1, index].select do |number|
        number >= 0
      end
        .map { |number| format("%02d", number) }
      unless match && allowed_validation_phases.include?(match[1])
        fail!("last_validation phase marker is invalid")
      end
    end

    report_statuses = read("docs/phases/P00-REPORT.md").scan(/^Status: `([^`]+)`$/).flatten
    fail!("P00 report must contain one canonical status") unless report_statuses.length == 1
    expected_report_status = current == "P00" ? status["state"] : "PHASE_PASSED"
    unless report_statuses.first == expected_report_status
      fail!("P00 report status differs from project state")
    end
    decisions = read("docs/phases/OPEN-DECISIONS.md")
    fail!("P01 blocker remains open") unless decisions.include?("No unresolved decision blocks P01.")
  end

  def validate_p00_lifecycle_state(status, queue)
    fail!("P00 candidate cannot have an evidence checkpoint") unless
      status["evidence_checkpoint"].nil?
    unless queue["last_checkpoint"] == "clean_root_#{@clean_root_commit}"
      fail!("P00 queue checkpoint differs from the immutable clean root")
    end
    unless status["subject_baseline"] == "SELF_AT_CANDIDATE_COMMIT"
      fail!("P00 state must retain the self-resolving subject marker")
    end

    case status["state"]
    when "REVIEWING"
      unless queue["next_action"] == P00_NEXT_ACTION
        fail!("P00 queue next_action differs from the executable review transition")
      end
      unless queue["waiting_internal_dependencies"].empty?
        fail!("reviewing P00 candidate cannot wait on internal dependencies")
      end
    when "BLOCKED"
      unless queue["next_action"] == P00_BLOCKED_NEXT_ACTION
        fail!("blocked P00 next_action must request explicit user scope adjudication")
      end
      unless queue["waiting_internal_dependencies"] == [P00_BLOCKED_DEPENDENCY]
        fail!("blocked P00 must wait only on an explicit user scope decision")
      end
      if status["open_findings"].empty?
        fail!("blocked P00 must retain at least one open finding")
      end
    else
      fail!("P00 state must be REVIEWING or BLOCKED")
    end
  end

  def validate_post_p00_lifecycle_state(status, queue, current, index)
    previous = PHASES[index - 1]
    allowed_marker_phases = [previous, current].compact
    state = status.fetch("state")

    subject_binding = validate_phase_subject_baseline!(
      status["subject_baseline"],
      state,
      current,
      allowed_marker_phases
    )
    evidence_binding = validate_phase_checkpoint_marker!(
      status["evidence_checkpoint"],
      allowed_marker_phases,
      "evidence checkpoint",
      %i[closeout pre_phase pre_phase_decision pre_implementation]
    )
    queue_binding = validate_phase_checkpoint_marker!(
      queue["last_checkpoint"],
      allowed_marker_phases,
      "queue checkpoint",
      %i[
        blocker
        candidate
        closeout
        pre_phase
        pre_phase_decision
        pre_implementation
      ]
    )
    unless phase_token?(queue["next_action"], current)
      fail!("post-P00 next_action must identify the current phase")
    end
    status["open_findings"].each do |finding|
      unless phase_token?(finding, current)
        fail!("post-P00 open finding must identify the current phase")
      end
    end

    previous_candidate = [previous, :candidate]
    current_candidate = [current, :candidate]
    current_pre_implementation = [current, :pre_implementation]
    prior_closeout = [previous, :closeout]
    active_stages = [
      prior_closeout,
      [current, :pre_phase],
      [current, :pre_phase_decision],
      current_pre_implementation
    ]

    case state
    when "PRE_PHASE_ANALYSIS"
      require_lifecycle_subject!(subject_binding, [previous_candidate], state)
      require_lifecycle_checkpoint_pair!(
        evidence_binding,
        queue_binding,
        [prior_closeout, [current, :pre_phase]],
        state
      )
      require_no_lifecycle_findings!(status, state)
    when "SOURCE_DISCOVERY", "SOURCE_FALLBACK_PROTOTYPE"
      require_lifecycle_subject!(subject_binding, [previous_candidate], state)
      require_lifecycle_checkpoint_pair!(
        evidence_binding,
        queue_binding,
        active_stages.first(3),
        state
      )
    when "IMPLEMENTATION", "IMPLEMENTING"
      allowed_subjects = [
        previous_candidate,
        [current, :pre_implementation_self]
      ]
      allowed_subjects << [nil, :none] if current == "P01"
      require_lifecycle_subject!(subject_binding, allowed_subjects, state)
      require_lifecycle_checkpoint_pair!(
        evidence_binding,
        queue_binding,
        active_stages,
        state
      )
    when "REVIEWING"
      require_lifecycle_subject!(
        subject_binding,
        [[current, :self_candidate]],
        state
      )
      unless active_stages.include?(evidence_binding) &&
             queue_binding == current_candidate
        fail!("REVIEWING post-P00 checkpoints must identify the active stage and current-phase candidate")
      end
      require_no_lifecycle_findings!(status, state)
    when "REMEDIATING"
      require_lifecycle_subject!(subject_binding, [current_candidate], state)
      unless active_stages.include?(evidence_binding) &&
             queue_binding == current_candidate
        fail!("REMEDIATING post-P00 checkpoints must identify the active stage and current-phase candidate")
      end
      require_actionable_lifecycle_findings!(status, current, state)
    when "PHASE_PASSED"
      require_lifecycle_subject!(subject_binding, [current_candidate], state)
      require_lifecycle_checkpoint_pair!(
        evidence_binding,
        queue_binding,
        [[current, :closeout]],
        state
      )
      require_no_lifecycle_findings!(status, state)
    when "BLOCKED"
      require_lifecycle_subject!(
        subject_binding,
        [
          previous_candidate,
          current_candidate,
          [current, :pre_implementation_self]
        ],
        state
      )
      unless active_stages.include?(evidence_binding) &&
             queue_binding == [current, :blocker]
        fail!("blocked post-P00 checkpoints must identify the active stage and current-phase blocker")
      end
      require_actionable_lifecycle_findings!(status, current, state)
      unless queue["waiting_internal_dependencies"] == [P00_BLOCKED_DEPENDENCY]
        fail!("blocked post-P00 phase must wait only on an explicit user scope decision")
      end
      unless queue["next_action"].match?(
        /\Arequest_explicit_user_scope_decision_(?:on|for)_[A-Za-z0-9_]+\z/
      )
        fail!("blocked post-P00 next_action must request explicit user scope adjudication")
      end
      return
    else
      fail!("post-P00 lifecycle state has no coherent state matrix")
    end

    unless queue["waiting_internal_dependencies"].empty?
      fail!("active post-P00 phase cannot wait on internal dependencies")
    end
  end

  def validate_phase_subject_baseline!(
    subject,
    state,
    current,
    allowed_phases
  )
    if state == "REVIEWING"
      unless subject == "SELF_AT_CANDIDATE_COMMIT"
        fail!("reviewing candidate must use self-resolving subject marker")
      end
      return [current, :self_candidate]
    end

    if current == "P01" && state == "IMPLEMENTING" && subject.nil?
      return [nil, :none]
    end
    match = subject&.match(
      /\A(P\d{2})_(CANDIDATE_[0-9a-f]{40}|PRE_IMPLEMENTATION_SELF)\z/
    )
    unless match && allowed_phases.include?(match[1])
      fail!("post-P00 subject baseline is not coherent with the current phase")
    end
    kind = match[2] == "PRE_IMPLEMENTATION_SELF" ?
      :pre_implementation_self :
      :candidate
    [match[1], kind]
  end

  def validate_phase_checkpoint_marker!(
    marker,
    allowed_phases,
    context,
    allowed_kinds
  )
    parsed =
      case marker
      when /\ASELF_AT_(P\d{2})_CLOSEOUT_COMMIT\z/
        [Regexp.last_match(1), :closeout]
      when /\ASELF_AT_(P\d{2})_PRE_PHASE_COMMIT\z/
        [Regexp.last_match(1), :pre_phase]
      when /\ASELF_AT_(P\d{2})_PRE_PHASE_DECISION_COMMIT\z/
        [Regexp.last_match(1), :pre_phase_decision]
      when /\ASELF_AT_(P\d{2})_PRE_IMPLEMENTATION_COMMIT\z/
        [Regexp.last_match(1), :pre_implementation]
      when /\ASELF_AT_(P\d{2})_(?:[A-Z0-9]+_)*BLOCKER_COMMIT\z/
        [Regexp.last_match(1), :blocker]
      when /\A(P\d{2})_CANDIDATE_[1-9][0-9]*_READY\z/
        [Regexp.last_match(1), :candidate]
      when "P00_USER_WAIVER_AT_CLOSEOUT_COMMIT"
        ["P00", :closeout]
      end
    unless parsed &&
           allowed_phases.include?(parsed.fetch(0)) &&
           allowed_kinds.include?(parsed.fetch(1))
      fail!("post-P00 #{context} is not coherent with the current phase")
    end
    parsed
  end

  def require_lifecycle_subject!(actual, allowed, state)
    return if allowed.include?(actual)

    fail!("#{state} post-P00 subject baseline is not coherent with its stage")
  end

  def require_lifecycle_checkpoint_pair!(evidence, queue, allowed, state)
    return if evidence == queue && allowed.include?(evidence)

    fail!("#{state} post-P00 checkpoints are not coherent with its stage")
  end

  def require_no_lifecycle_findings!(status, state)
    return if status["open_findings"].empty?

    fail!("#{state} post-P00 phase cannot retain open findings")
  end

  def require_actionable_lifecycle_findings!(status, current, state)
    findings = status["open_findings"]
    if findings.empty?
      fail!("#{state.downcase} post-P00 phase must retain at least one open finding")
    end
    findings.each do |finding|
      tokens = finding.scan(/[A-Za-z0-9]+/)
      severity = tokens.any? { |token| token.match?(/\AP[0-3]\z/) }
      detail = tokens.any? do |token|
        token != current && !token.match?(/\AP[0-3]\z/)
      end
      unless severity && detail
        fail!("#{state.downcase} post-P00 open finding must be severity-bearing and actionable")
      end
    end
  end

  def phase_token?(value, phase)
    value.is_a?(String) &&
      value.match?(
        /(?:\A|[^A-Za-z0-9])#{Regexp.escape(phase)}(?:[^A-Za-z0-9]|\z)/
      )
  end

  def validate_amazon_exclusion
    allowlist = @yaml.fetch("docs/clean-room/AMAZON-EXCLUSION-ALLOWLIST.yaml")
    exact_keys!(allowlist, %w[schema_version allowed_governance_paths], "Amazon exclusion allowlist")
    fail!("unsupported Amazon allowlist schema") unless allowlist["schema_version"] == 1
    entries = allowlist["allowed_governance_paths"]
    fail!("allowed_governance_paths must be an array") unless entries.is_a?(Array)

    allowed = Set.new
    entries.each_with_index do |entry, index|
      exact_keys!(entry, %w[path reason], "Amazon allowlist entry #{index}")
      nonempty_string!(entry["path"], "Amazon allowlist path")
      nonempty_string!(entry["reason"], "Amazon allowlist reason")
      fail!("Amazon allowlist path is not tracked: #{entry['path']}") unless tracked_paths.include?(entry["path"])
      fail!("duplicate Amazon allowlist path: #{entry['path']}") unless allowed.add?(entry["path"])
    end
    actual_allowlist = entries.to_h { |entry| [entry["path"], entry["reason"]] }
    unless actual_allowlist == EXPECTED_AMAZON_ALLOWLIST
      fail!("Amazon exclusion allowlist differs from the fixed governance exemptions")
    end

    tracked_paths.each do |path|
      next if BINARY_PATH_SUFFIXES.any? { |suffix| path.end_with?(suffix) }

      content = read(path)
      next if governed_synthetic_data?(path, content)

      scan_views(content, path).each do |candidate, structured|
        unless %w[
          docs/clean-room/MATERIALS.yaml
          docs/evidence/TOOLCHAIN-PROVENANCE.yaml
          tools/test-validate-governance.rb
          tools/validate-governance.rb
        ].include?(path)
          scan_blocked_urls(path, candidate)
        end
        next if allowed.include?(path)

        scan_blocked_provider_payloads(path, candidate) if structured
        if candidate.match?(blocked_repository_pattern)
          fail!("Amazon-owned repository reference found in #{path}")
        end
        provider_values = candidate.scan(
          /^\s*(?:provider|owner|upstream[_.-]*owner):\s*["']?([^"'#\n]+)["']?\s*$/i
        ).flatten
        if provider_values.any? { |value| blocked_provider_identity?(value) }
          fail!("Amazon-owned provider metadata found in #{path}")
        end
        if candidate.match?(blocked_package_pattern)
          fail!("Amazon-specific package coordinate found in #{path}")
        end
      end
    end
  end

  def scan_amazon_content(path, content)
    scan_views(content, path).each do |candidate, structured|
      scan_blocked_urls(path, candidate)
      scan_blocked_provider_payloads(path, candidate) if structured
      if candidate.match?(blocked_repository_pattern)
        fail!("Amazon-owned repository reference found in #{path}")
      end
      provider_values = candidate.scan(
        /^\s*(?:provider|owner|upstream[_.-]*owner):\s*["']?([^"'#\n]+)["']?\s*$/i
      ).flatten
      if provider_values.any? { |value| blocked_provider_identity?(value) }
        fail!("Amazon-owned provider metadata found in #{path}")
      end
      if candidate.match?(blocked_package_pattern)
        fail!("Amazon-specific package coordinate found in #{path}")
      end
    end
  end

  def scan_blocked_provider_payloads(path, content)
    if embedded_protected_json_key_candidate_for?(
      content,
      PROTECTED_PROVIDER_KEYS,
      nested_strings:
        structured_document_path?(path) || path.end_with?(".json")
    )
      bounded_json_fragments(content, path).each do |fragment|
        parsed = parse_json(fragment, path, strict: false)
        scan_blocked_provider_structure(parsed, path) if parsed
      end
    end
    if structured_document_path?(path) &&
       protected_yaml_document_key_candidate?(
         content,
         path,
         PROTECTED_PROVIDER_KEYS
       )
      parsed_yaml_payloads(content, path).each_with_index do |parsed, index|
        scan_blocked_provider_structure(parsed, path, "$yaml[#{index}]")
      end
    end
  end

  def scan_blocked_provider_structure(value, path, context = "$", depth = 0)
    if depth > MAX_PROVIDER_PAYLOAD_DEPTH
      fail!("provider payload exceeds depth limit in #{path}")
    end

    case value
    when Hash
      value.each do |key, nested|
        normalized = canonical_sensitive_key(key)
        if %w[provider owner upstreamowner].include?(normalized)
          unless nested.is_a?(String) && !nested.strip.empty?
            fail!("provider metadata #{context}.#{key} must be a nonempty string in #{path}")
          end
          if blocked_provider_identity?(nested)
            fail!("Amazon-owned provider metadata found in #{path}")
          end
        end
        scan_blocked_provider_structure(
          nested,
          path,
          "#{context}.#{key}",
          depth + 1
        )
      end
    when Array
      value.each_with_index do |nested, index|
        scan_blocked_provider_structure(
          nested,
          path,
          "#{context}[#{index}]",
          depth + 1
        )
      end
    when String
      bounded_json_fragments(value, path).each_with_index do |fragment, index|
        parsed = parse_json(fragment, path, strict: false)
        next unless parsed && parsed != value

        scan_blocked_provider_structure(
          parsed,
          path,
          "#{context}#json[#{index}]",
          depth + 1
        )
      end
      embedded_yaml_values(
        value,
        path,
        context,
        protected_keys: PROTECTED_PROVIDER_KEYS
      ).each_with_index do |parsed_yaml, index|
        scan_blocked_provider_structure(
          parsed_yaml,
          path,
          "#{context}#yaml[#{index}]",
          depth + 1
        )
      end
    end
  end

  def scan_blocked_urls(path, content)
    url_candidates(content, path).each do |raw_url|
      uri = URI.parse(normalized_scanned_url(raw_url))
      host = normalized_host(uri.host)
      next unless host
      if blocked_host?(host)
        fail!("Amazon-owned endpoint #{host} found in #{path}")
      end
      owner = repository_owner(uri)
      validate_repository_owner!(owner, path) if owner
    rescue URI::InvalidURIError
      fail!("malformed URL in #{path}: #{raw_url}")
    end

    content.scan(%r{\bgit@(?:github\.com|gitlab\.com|bitbucket\.org|codeberg\.org):([^/\s]+)}i) do |match|
      owner = repeatedly_percent_decode(match.fetch(0)).downcase
      validate_repository_owner!(owner, path)
    end
  end

  def url_candidates(content, context)
    candidates = []
    bytes = content.b
    offset = 0
    scheme_pattern = /(?:https?|ssh|git):\/\//i
    while (match = scheme_pattern.match(bytes, offset))
      if candidates.length >= MAX_URL_CANDIDATES
        fail!("URL candidate limit exceeded in #{context}")
      end
      start = match.begin(0)
      finish = match.end(0)
      while finish < bytes.bytesize &&
            !url_terminator_byte?(bytes.getbyte(finish))
        if finish - start >= MAX_URL_CANDIDATE_BYTES
          fail!("URL candidate byte limit exceeded in #{context}")
        end
        finish += 1
      end
      candidate = bytes.byteslice(start, finish - start)
      candidate.force_encoding(content.encoding)
      candidates << candidate
      offset = match.end(0)
    end
    candidates
  end

  def url_terminator_byte?(byte)
    byte <= 32 || [34, 38, 39, 41, 60, 62, 93].include?(byte)
  end

  def blocked_host?(host)
    BLOCKED_HOST_SUFFIXES.any? { |suffix| host == suffix || host.end_with?(".#{suffix}") }
  end

  def normalized_host(host)
    return nil unless host

    normalized = repeatedly_percent_decode(host).downcase.sub(/\.+\z/, "")
    aliases = {
      "www.github.com" => "github.com",
      "raw.github.com" => "raw.githubusercontent.com"
    }
    aliases.fetch(normalized, normalized)
  end

  def repository_owner(uri)
    host = normalized_host(uri.host)
    segments = decoded_path_segments(uri.path)
    case host
    when "github.com", "gitlab.com", "bitbucket.org", "codeberg.org",
         "raw.githubusercontent.com", "codeload.github.com"
      segments.first
    when "api.github.com"
      segments.fetch(1, nil) if segments.first == "repos"
    end
  end

  def decoded_path_segments(path)
    decoded = repeatedly_percent_decode(path.to_s)
    decoded.split("/").each_with_object([]) do |segment, normalized|
      next if segment.empty? || segment == "."
      if segment == ".."
        if normalized.empty?
          fail!("repository URL path escapes its owner segment")
        end
        normalized.pop
      else
        normalized << segment.downcase
      end
    end
  end

  def repeatedly_percent_decode(value)
    repeatedly_transform(value, "percent-decoding limit exceeded") do |decoded|
      next_value = URI::DEFAULT_PARSER.unescape(decoded)
      fail!("percent-decoded text is not valid UTF-8") unless next_value.valid_encoding?
      next_value
    end
  end

  def repeatedly_decode_text(value)
    repeatedly_transform(value, "text-decoding limit exceeded") do |decoded|
      next_value = URI::DEFAULT_PARSER.unescape(decoded)
      fail!("decoded text is not valid UTF-8") unless next_value.valid_encoding?
      next_value = decode_json_unicode_escapes(next_value).gsub("\\/", "/")
      next_value = CGI.unescapeHTML(next_value)
      next_value.gsub(/\p{Default_Ignorable_Code_Point}/, "")
    end
  end

  def decode_json_unicode_escapes(value)
    paired = value.gsub(
      /\\u(d[89ab][0-9a-f]{2})\\u(d[c-f][0-9a-f]{2})/i
    ) do
      high = Regexp.last_match(1).to_i(16)
      low = Regexp.last_match(2).to_i(16)
      codepoint = 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)
      [codepoint].pack("U")
    end
    paired.gsub(/\\u([0-9a-fA-F]{4})/) do |escape|
      codepoint = Regexp.last_match(1).to_i(16)
      codepoint.between?(0xD800, 0xDFFF) ? escape : [codepoint].pack("U")
    end
  end

  def scan_views(content, path = nil)
    Enumerator.new do |views|
      decoded = repeatedly_decode_text(content)
      views << [decoded, true]
      views << [content, true] unless decoded == content
      next unless path&.end_with?(".md", ".markdown")

      visible = markdown_visible_text(decoded)
      unless visible == decoded || visible == content
        views << [visible, false]
      end
    end
  end

  def markdown_visible_text(content)
    text = strip_markdown_html(content.gsub(/\r\n?/, "\n"))
    text = normalize_inline_markdown_links(text)
    text = normalize_reference_markdown_links(text)
    text = normalize_shortcut_markdown_images(text)
    text = text.gsub(/\\([\\`*{}\[\]()#+\-.!_>~|:])/, '\1')
    text = text.gsub(/[`*~\[\]]/, "")
    [3, 2, 1].each do |length|
      marker = "_" * length
      text = text.gsub(
        /(?<![A-Za-z0-9])#{marker}([^\r\n]+?)#{marker}(?![A-Za-z0-9])/,
        '\1'
      )
    end
    text.each_line.map { |line| markdown_control_text(line) }.join("\n")
  end

  def next_markdown_html_closing(bytes, start)
    bytes.index(">".b, start)
  end

  def markdown_autolink_closing(bytes, opening, closing)
    return nil unless closing

    value = bytes.byteslice(opening + 1, closing - opening - 1).to_s
    return nil if value.empty? || value.match?(/[\x00-\x20<>]/)
    return closing if value.match?(
      /\A[A-Za-z][A-Za-z0-9+.-]{1,31}:[^\x00-\x20<>]*\z/
    )
    return closing if value.match?(
      /\A[A-Za-z0-9.!#$%&'*+\/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+\z/
    )

    nil
  end

  def strip_markdown_html(text)
    bytes = text.b
    output = String.new.b
    cursor = 0
    index = 0
    next_angle_closing = nil
    angle_closing_exhausted = false

    while index < bytes.bytesize
      unless bytes.getbyte(index) == 60
        index += 1
        next
      end

      if next_angle_closing && next_angle_closing < index
        next_angle_closing = nil
      end
      unless next_angle_closing || angle_closing_exhausted
        next_angle_closing = next_markdown_html_closing(bytes, index + 1)
        angle_closing_exhausted = true unless next_angle_closing
      end

      autolink_closing = markdown_autolink_closing(
        bytes,
        index,
        next_angle_closing
      )
      if autolink_closing
        index = autolink_closing + 1
        next
      end

      if bytes.byteslice(index, 4) == "<!--".b
        closing = bytes.index("-->".b, index + 4)
        unless closing
          break
        end
        output << bytes.byteslice(cursor, index - cursor)
        index = closing + 3
        cursor = index
        next
      end

      if bytes.byteslice(index, 2) == "<?".b
        closing = bytes.index("?>".b, index + 2)
        unless closing
          index += 1
          next
        end
        output << bytes.byteslice(cursor, index - cursor)
        index = closing + 2
        cursor = index
        next
      end

      if bytes.byteslice(index, 9) == "<![CDATA[".b
        closing = bytes.index("]]>".b, index + 9)
        unless closing
          index += 1
          next
        end
        output << bytes.byteslice(cursor, index - cursor)
        index = closing + 3
        cursor = index
        next
      end

      if bytes.byteslice(index, 2) == "<!".b
        declaration = bytes.getbyte(index + 2)
        if declaration&.between?(65, 90)
          closing = bytes.index(">".b, index + 3)
          unless closing
            index += 1
            next
          end
          output << bytes.byteslice(cursor, index - cursor)
          index = closing + 1
          cursor = index
          next
        end
      end

      scan = index + 1
      scan += 1 if bytes.getbyte(scan) == 47
      first = bytes.getbyte(scan)
      unless first &&
             ((first >= 65 && first <= 90) || (first >= 97 && first <= 122))
        index += 1
        next
      end

      quote = nil
      closing = nil
      nested_open = nil
      while scan < bytes.bytesize
        byte = bytes.getbyte(scan)
        if quote
          quote = nil if byte == quote
        elsif byte == 34 || byte == 39
          quote = byte
        elsif byte == 60
          nested_open = scan
          break
        elsif byte == 62
          closing = scan
          break
        end
        scan += 1
      end
      if nested_open
        index = nested_open
        next
      end
      unless closing
        break
      end

      output << bytes.byteslice(cursor, index - cursor)
      index = closing + 1
      cursor = index
    end

    output << bytes.byteslice(cursor, bytes.bytesize - cursor)
    output.force_encoding(text.encoding)
  end

  def normalize_inline_markdown_links(text)
    normalized = text
    MAX_MARKDOWN_NESTING.times do
      next_value = normalize_inline_markdown_links_once(normalized)
      return normalized if next_value == normalized

      normalized = next_value
    end
    return normalized if normalize_inline_markdown_links_once(normalized) == normalized

    fail!("Markdown link normalization limit exceeded")
  end

  def normalize_inline_markdown_links_once(text)
    bytes = text.b
    output = String.new.b
    cursor = 0
    index = 0

    while index < bytes.bytesize
      if bytes.getbyte(index) == 92
        index += 2
        next
      end
      marker_start = index
      label_open = if bytes.getbyte(index) == 33 &&
                      bytes.getbyte(index + 1) == 91
                     index + 1
                   elsif bytes.getbyte(index) == 91
                     index
                   end
      unless label_open
        index += 1
        next
      end

      label_match = matching_markdown_delimiter(
        bytes,
        label_open,
        91,
        93,
        quote_aware: false
      )
      label_close = label_match&.fetch(0)
      destination_open = label_close && label_close + 1
      unless destination_open &&
             bytes.getbyte(destination_open) == 40
        index = label_open + 1
        next
      end
      destination_match = matching_markdown_delimiter(
        bytes,
        destination_open,
        40,
        41,
        quote_aware: true
      )
      destination_close = destination_match&.fetch(0)
      unless destination_close
        index = destination_open + 1
        next
      end
      if label_match.fetch(1) > MAX_MARKDOWN_NESTING ||
         destination_match.fetch(1) > MAX_MARKDOWN_NESTING
        fail!("Markdown delimiter nesting limit exceeded")
      end

      output << bytes.byteslice(cursor, marker_start - cursor)
      output << bytes.byteslice(
        label_open + 1,
        label_close - label_open - 1
      )
      index = destination_close + 1
      cursor = index
    end

    output << bytes.byteslice(cursor, bytes.bytesize - cursor)
    output.force_encoding(text.encoding)
  end

  def normalize_reference_markdown_links(text)
    normalized = text
    MAX_MARKDOWN_NESTING.times do
      next_value = normalize_reference_markdown_links_once(normalized)
      return normalized if next_value == normalized

      normalized = next_value
    end
    return normalized if normalize_reference_markdown_links_once(normalized) == normalized

    fail!("Markdown reference normalization limit exceeded")
  end

  def normalize_reference_markdown_links_once(text)
    bytes = text.b
    output = String.new.b
    cursor = 0
    index = 0

    while index < bytes.bytesize
      if bytes.getbyte(index) == 92
        index += 2
        next
      end
      marker_start = index
      label_open = if bytes.getbyte(index) == 33 &&
                      bytes.getbyte(index + 1) == 91
                     index + 1
                   elsif bytes.getbyte(index) == 91
                     index
                   end
      unless label_open
        index += 1
        next
      end

      label_match = matching_markdown_delimiter(
        bytes,
        label_open,
        91,
        93,
        quote_aware: false
      )
      label_close = label_match&.fetch(0)
      reference_open = label_close && label_close + 1
      unless reference_open && bytes.getbyte(reference_open) == 91
        index = label_open + 1
        next
      end
      reference_match = matching_markdown_delimiter(
        bytes,
        reference_open,
        91,
        93,
        quote_aware: false
      )
      reference_close = reference_match&.fetch(0)
      unless reference_close
        index = reference_open + 1
        next
      end
      if label_match.fetch(1) > MAX_MARKDOWN_NESTING ||
         reference_match.fetch(1) > MAX_MARKDOWN_NESTING
        fail!("Markdown delimiter nesting limit exceeded")
      end

      output << bytes.byteslice(cursor, marker_start - cursor)
      output << bytes.byteslice(
        label_open + 1,
        label_close - label_open - 1
      )
      index = reference_close + 1
      cursor = index
    end

    output << bytes.byteslice(cursor, bytes.bytesize - cursor)
    output.force_encoding(text.encoding)
  end

  def normalize_shortcut_markdown_images(text)
    normalized = text
    MAX_MARKDOWN_NESTING.times do
      next_value = normalize_shortcut_markdown_images_once(normalized)
      return normalized if next_value == normalized

      normalized = next_value
    end
    return normalized if normalize_shortcut_markdown_images_once(normalized) == normalized

    fail!("Markdown image normalization limit exceeded")
  end

  def normalize_shortcut_markdown_images_once(text)
    bytes = text.b
    output = String.new.b
    cursor = 0
    index = 0

    while index < bytes.bytesize
      if bytes.getbyte(index) == 92
        index += 2
        next
      end
      unless bytes.getbyte(index) == 33 &&
             bytes.getbyte(index + 1) == 91
        index += 1
        next
      end
      label_open = index + 1
      label_match = matching_markdown_delimiter(
        bytes,
        label_open,
        91,
        93,
        quote_aware: false
      )
      label_close = label_match&.fetch(0)
      unless label_close
        index = label_open + 1
        next
      end
      if label_match.fetch(1) > MAX_MARKDOWN_NESTING
        fail!("Markdown delimiter nesting limit exceeded")
      end

      output << bytes.byteslice(cursor, index - cursor)
      output << bytes.byteslice(
        label_open + 1,
        label_close - label_open - 1
      )
      index = label_close + 1
      cursor = index
    end

    output << bytes.byteslice(cursor, bytes.bytesize - cursor)
    output.force_encoding(text.encoding)
  end

  def matching_markdown_delimiter(
    bytes,
    opening_index,
    opening_byte,
    closing_byte,
    quote_aware:
  )
    depth = 1
    maximum_depth = depth
    quote = nil
    angle_destination = false
    destination_started = false
    index = opening_index + 1
    while index < bytes.bytesize
      byte = bytes.getbyte(index)
      if byte == 92
        index += 2
        next
      end
      if quote
        quote = nil if byte == quote
        index += 1
        next
      end
      if angle_destination
        return nil if byte == 10 || byte == 13 || byte == 60

        angle_destination = false if byte == 62
        index += 1
        next
      end
      if quote_aware
        prior = index > opening_index + 1 ? bytes.getbyte(index - 1) : nil
        if (byte == 34 || byte == 39) &&
           prior && prior <= 32
          quote = byte
          destination_started = true
          index += 1
          next
        end
        if byte == 60 && !destination_started
          angle_destination = true
          destination_started = true
          index += 1
          next
        end
        destination_started = true if byte > 32
      end
      if byte == opening_byte
        depth += 1
        maximum_depth = depth if depth > maximum_depth
      elsif byte == closing_byte
        depth -= 1
        return [index, maximum_depth] if depth.zero?
      end
      index += 1
    end
    if maximum_depth > MAX_MARKDOWN_NESTING
      fail!("Markdown delimiter nesting limit exceeded")
    end
    nil
  end

  def markdown_control_text(line)
    text = line.chomp
    loop do
      before = text
      text = text.sub(/\A[ \t]{0,3}>[ \t]?/) do |prefix|
        " " * prefix.bytesize
      end
      text = text.sub(/\A[ \t]{0,3}(?:[-+*]|\d+[.)])[ \t]+/) do |prefix|
        " " * prefix.bytesize
      end
      return text if text == before
    end
  end

  def markdown_reference_labels(content)
    content.gsub(/\r\n?/, "\n").each_line.each_with_object(Set.new) do |line, labels|
      label = markdown_reference_definition_label(line)
      labels << label if label
    end
  end

  def markdown_reference_definition_label(line)
    text = markdown_control_text(line).strip
    return nil unless text.start_with?("[")

    label_match = matching_markdown_delimiter(
      text.b,
      0,
      91,
      93,
      quote_aware: false
    )
    return nil unless label_match

    closing = label_match.fetch(0)
    remainder = text.byteslice(
      closing + 1,
      text.bytesize - closing - 1
    ).to_s
    return nil unless remainder.match?(/\A:[ \t]*/)

    label = text.byteslice(1, closing - 1).to_s
    canonical_markdown_reference_label(label)
  end

  def markdown_reference_title_line?(line)
    text = markdown_control_text(line).strip
    return false if text.empty?

    (text.start_with?("\"") && text.end_with?("\"")) ||
      (text.start_with?("'") && text.end_with?("'")) ||
      (text.start_with?("(") && text.end_with?(")"))
  end

  def markdown_reference_destination_line?(line)
    text = markdown_control_text(line).strip
    return false if text.empty?
    return true if text.start_with?("<") && text.end_with?(">")
    return false if text.match?(
      /\A(?:<<\s*:|[?%&*!|>@`]|\.\.\.(?:\s|\z)|---(?:\s|\z)|-(?:\s|\z)|:(?:\s|\z))/
    )

    !text.match?(/[ \t]/)
  end

  def markdown_label_line?(line, reference_labels)
    text = markdown_control_text(line).strip
    image = text.start_with?("![")
    opening = image ? 1 : 0
    return false unless text.getbyte(opening) == 91

    label_match = matching_markdown_delimiter(
      text.b,
      opening,
      91,
      93,
      quote_aware: false
    )
    return false unless label_match

    closing = label_match.fetch(0)
    label = text.byteslice(opening + 1, closing - opening - 1).to_s
    remainder = text.byteslice(
      closing + 1,
      text.bytesize - closing - 1
    ).to_s
    return true if remainder.match?(/\A:[ \t]*/)
    return true if markdown_destination_suffix?(remainder, 40, 41)
    return true if markdown_destination_suffix?(remainder, 91, 93)
    return false unless remainder.strip.empty?

    image ||
      reference_labels.include?(canonical_markdown_reference_label(label))
  end

  def markdown_destination_suffix?(suffix, opening_byte, closing_byte)
    probe = suffix.lstrip
    return false unless probe.getbyte(0) == opening_byte

    delimiter = matching_markdown_delimiter(
      probe.b,
      0,
      opening_byte,
      closing_byte,
      quote_aware: opening_byte == 40
    )
    delimiter &&
      probe.byteslice(
        delimiter.fetch(0) + 1,
        probe.bytesize - delimiter.fetch(0) - 1
      ).to_s.strip.empty?
  end

  def canonical_markdown_reference_label(label)
    label.gsub(/[ \t\r\n]+/, " ").strip.downcase
  end

  def markdown_styled_protected_mapping_line?(line, protected_keys)
    text = markdown_control_text(line).chomp
    delimiters = []
    text.to_enum(:scan, /:(?=[ \t]|\z)/).each do
      delimiters << Regexp.last_match.begin(0)
    end
    return false if delimiters.empty?

    raw_key = text.byteslice(0, delimiters.last).to_s.strip
    visible_key = markdown_visible_text(raw_key).strip
    return false if raw_key == visible_key

    protected_keys.include?(canonical_sensitive_key(visible_key))
  end

  def repeatedly_transform(value, limit_error)
    decoded = value.to_s
    transform = proc { |candidate| yield(candidate) }
    MAX_DECODE_PASSES.times do
      next_value = transform.call(decoded)
      return decoded if next_value == decoded

      decoded = next_value
    end
    return decoded if transform.call(decoded) == decoded

    fail!(limit_error)
  end

  def blocked_repository_owner?(owner)
    return false unless owner
    return true if BLOCKED_GITHUB_OWNERS.include?(owner)

    owner == "awslabs" ||
      owner.start_with?("amazon-", "amazon_", "aws-", "aws_")
  end

  def validate_repository_owner!(owner, path)
    if blocked_repository_owner?(owner)
      fail!("Amazon-owned repository organization #{owner} found in #{path}")
    end
    return if APPROVED_REPOSITORY_OWNERS.include?(owner)

    fail!("unapproved repository owner #{owner} found in #{path}")
  end

  def validate_approved_repository_owners!(value, context)
    amazon_record_strings(value).each do |text|
      decoded_text = repeatedly_decode_text(text)
      url_candidates(decoded_text, context).each do |raw_url|
        uri = URI.parse(normalized_scanned_url(raw_url))
        owner = repository_owner(uri)
        validate_repository_owner!(owner, context) if owner
      rescue URI::InvalidURIError
        fail!("malformed repository URL in #{context}")
      end
      decoded_text.scan(%r{\bgit@(?:github\.com|gitlab\.com|bitbucket\.org|codeberg\.org):([^/\s]+)}i) do |match|
        owner = repeatedly_percent_decode(match.fetch(0)).downcase
        validate_repository_owner!(owner, context)
      end
    end
  end

  def amazon_specific_record?(value)
    provider_values = if value.is_a?(Hash)
                        value.each_with_object([]) do |(key, nested), result|
                          if %w[provider owner upstream_owner].include?(key.to_s) &&
                             nested.is_a?(String)
                            result << nested
                          end
                        end
                      else
                        []
                      end
    return true if provider_values.any? { |provider| blocked_provider_identity?(provider) }

    strings = case value
              when Hash
                value.flat_map { |key, nested| [key.to_s, *amazon_record_strings(nested)] }
              else
                amazon_record_strings(value)
              end

    strings.any? do |text|
      decoded_text = repeatedly_decode_text(text)
      blocked_url_in_string?(decoded_text) ||
        decoded_text.match?(blocked_repository_pattern) ||
        decoded_text.match?(blocked_package_pattern) ||
        decoded_text.match?(/\A(?:Amazon(?:WebServices)?|AWS)(?:\b|_)/i)
    end
  end

  def blocked_provider_identity?(value)
    canonical = repeatedly_decode_text(value.to_s).downcase.gsub(/[^a-z0-9]/, "")
    canonical.start_with?("amazon", "aws")
  end

  def blocked_repository_pattern
    owners = (
      BLOCKED_GITHUB_OWNERS.map { |owner| Regexp.escape(owner) } +
      ["amazon[-_][a-z0-9_.-]+", "aws[-_][a-z0-9_.-]+"]
    ).join("|")
    %r{(?:(?:www\.)?github\.com|gitlab\.com|bitbucket\.org|codeberg\.org|raw\.(?:github\.com|githubusercontent\.com)|codeload\.github\.com)(?::|/)(?:repos/)?(?:#{owners})(?:/|["'\s]|\z)}i
  end

  def blocked_package_pattern
    /(?:@aws-sdk\/|\b(?!amazon_or_aws_material_used\b)(?:aws|amazon)[-_.](?!(?:specific|internal|owned|authored|provided|related|exclusion)\b)[a-z0-9_.-]+|\baws_sdk_[a-z0-9_]*|\b(?:amazonwebservices|awscrt|boto3|botocore|s2n[-_.]tls|s3transfer|awscli)\b|\b(?:software\.amazon|com\.amazonaws)(?:\.|:))/i
  end

  def amazon_record_strings(value)
    case value
    when Hash
      value.flat_map { |key, nested| [key.to_s, *amazon_record_strings(nested)] }
    when Array
      value.flat_map { |nested| amazon_record_strings(nested) }
    when String
      [value]
    else
      []
    end
  end

  def blocked_url_in_string?(text)
    decoded_text = repeatedly_decode_text(text)
    url_candidates(decoded_text, "structured record").any? do |raw_url|
      uri = URI.parse(normalized_scanned_url(raw_url))
      host = normalized_host(uri.host)
      next false unless host
      next true if blocked_host?(host)

      blocked_repository_owner?(repository_owner(uri))
    rescue URI::InvalidURIError
      true
    end || decoded_text.scan(
      %r{\bgit@(?:github\.com|gitlab\.com|bitbucket\.org|codeberg\.org):([^/\s]+)}i
    ).any? do |match|
      blocked_repository_owner?(repeatedly_percent_decode(match.fetch(0)).downcase)
    end
  end

  def normalized_scanned_url(raw_url)
    raw_url
      .sub(/\\[nrt].*\z/, "")
      .sub(/[.,;:`}]+\z/, "")
      .gsub(/\\([._~-])/, '\1')
      .gsub(/\{(?:name|version|REVISION)\}/, "FIXTURE_TECNICA")
      .gsub(/%(?![0-9a-f]{2})/i, "%25")
      .gsub(/[^\x00-\x7f]/) do |text|
        text.bytes.map { |byte| format("%%%02X", byte) }.join
      end
  end

  def validate_sensitive_tree
    missing_governed = GOVERNED_SYNTHETIC_DATA_SHA256.keys - tracked_paths
    unless missing_governed.empty?
      fail!(
        "governed synthetic data paths are missing: " \
        "#{missing_governed.join(', ')}"
      )
    end
    tracked_paths.each do |path|
      if sensitive_path?(path)
        fail!("sensitive file type is tracked: #{path}")
      end
      next if SENSITIVE_CONTENT_EXEMPT_PATHS.include?(path)
      next if BINARY_PATH_SUFFIXES.any? { |suffix| path.end_with?(suffix) }

      content = read(path)
      next if governed_synthetic_data?(path, content)

      scan_sensitive_content(path, content)
    end
    validate_all_ref_sensitive_paths
    validate_all_ref_sensitive_blobs
  end

  def governed_synthetic_data?(path, content)
    governed_digest = GOVERNED_SYNTHETIC_DATA_SHA256[path]
    return false unless governed_digest

    unless Digest::SHA256.hexdigest(content.b) == governed_digest
      fail!("governed synthetic data differs from its frozen hash: #{path}")
    end
    true
  end

  def sensitive_path?(path)
    path.match?(/(?:^|\/)(?:secrets\.yaml|home-assistant_v2\.db)\z/i) ||
      path.match?(/\.(?:db|env|key|pem|sqlite|sqlite3)\z/i) ||
      path.match?(%r{(?:^|/)\.storage(?:/|\z)}) ||
      path.match?(
        %r{(?:^|/)(?:core\.)?(?:entity|device|area|floor)_registry\z}i
      )
  end

  def validate_all_ref_sensitive_paths
    inventory = all_ref_object_inventory
    tree_ids = inventory.fetch(:object_ids).select do |object|
      inventory.fetch(:metadata).fetch(object).fetch(:type) == "tree"
    end
    entry_count = 0
    path_bytes = 0

    read_git_objects(tree_ids, "tree").each_value do |content|
      cursor = 0
      while cursor < content.bytesize
        mode_end = content.index(" ".b, cursor)
        name_end = mode_end && content.index("\0".b, mode_end + 1)
        unless mode_end && name_end && name_end + 21 <= content.bytesize
          fail!("malformed Git tree reachable from a project ref")
        end
        mode = content.byteslice(cursor, mode_end - cursor)
        unless mode.match?(/\A(?:40000|100644|100755|120000|160000)\z/)
          fail!("unsupported Git tree mode reachable from a project ref")
        end
        name = content.byteslice(mode_end + 1, name_end - mode_end - 1)
        if name.empty? || name.include?("/".b)
          fail!("malformed Git tree path reachable from a project ref")
        end
        name.force_encoding(Encoding::UTF_8)
        unless name.valid_encoding?
          fail!("Git path reachable from a project ref is not valid UTF-8")
        end

        entry_count += 1
        path_bytes += name.bytesize
        if entry_count > MAX_REACHABLE_PRIVACY_TREE_ENTRIES ||
           path_bytes > MAX_REACHABLE_PRIVACY_PATH_BYTES
          fail!("Git paths reachable from project refs exceed privacy scan limits")
        end
        if sensitive_path?(name)
          fail!("sensitive file type is reachable from a project ref: #{name}")
        end
        cursor = name_end + 21
      end
    end
  end

  def validate_all_ref_sensitive_blobs
    inventory = all_ref_object_inventory
    object_paths = inventory.fetch(:object_paths)
    object_ids = inventory.fetch(:object_ids)
    metadata = inventory.fetch(:metadata)
    blob_ids = object_ids.select do |object|
      metadata.fetch(object).fetch(:type) == "blob"
    end

    current_blob_ids = tracked_entries.each_with_object([]) do |entry, result|
      result << entry.fetch("object") if entry.fetch("type") == "blob"
    end.to_set
    exempt_blob_ids = reviewed_sensitive_exempt_blob_ids(metadata)
    scan_ids = blob_ids.reject do |object|
      current_blob_ids.include?(object) || exempt_blob_ids.include?(object)
    end
    scan_ids.each do |object|
      size = metadata.fetch(object).fetch(:size)
      if size > MAX_REACHABLE_PRIVACY_BLOB_BYTES
        fail!("Git blob reachable from a project ref exceeds privacy scan limit")
      end
    end

    read_git_blobs(scan_ids).each do |object, content|
      path = object_paths[object]
      context = path ? "git-history/#{object}/#{path}" : "git-history/#{object}"
      if content.include?("\0")
        fail!("binary NUL byte found in #{context}")
      end
      content.force_encoding(Encoding::UTF_8)
      fail!("#{context} is not valid UTF-8") unless content.valid_encoding?
      scan_historical_sensitive_content(context, content)
    end
  end

  def all_ref_object_inventory
    @all_ref_object_inventory ||= begin
      object_lines = git("rev-list", "--objects", "--all", binary: true).lines
      object_paths = {}
      object_ids = object_lines.map do |line|
        object, path = line.chomp.split(" ", 2)
        unless object&.match?(/\A[0-9a-f]{40}\z/)
          fail!("malformed object reachable from a project ref")
        end
        object_paths[object] ||= path
        object
      end.uniq
      metadata = git_object_metadata(object_ids)
      {
        object_ids: object_ids,
        object_paths: object_paths,
        metadata: metadata
      }
    end
  end

  def reviewed_sensitive_exempt_blob_ids(all_metadata)
    lines = git(
      "rev-list",
      "--objects",
      @expected_commit,
      "--",
      *SENSITIVE_CONTENT_EXEMPT_PATHS.to_a.sort,
      binary: true
    ).lines
    object_ids = lines.each_with_object([]) do |line, result|
      object = line.byteslice(0, 40)
      result << object if object&.match?(/\A[0-9a-f]{40}\z/)
    end.uniq
    missing = object_ids - all_metadata.keys
    metadata = missing.empty? ? all_metadata : all_metadata.merge(
      git_object_metadata(missing)
    )
    exempt = object_ids.select do |object|
      metadata.fetch(object).fetch(:type) == "blob"
    end.to_set
    REVIEWED_HISTORICAL_SENSITIVE_BLOB_SHA256.each do |object, expected_sha256|
      unless all_metadata[object]&.fetch(:type) == "blob"
        fail!("reviewed historical sensitive blob is not reachable")
      end
      content = read_git_blobs([object]).fetch(object)
      unless Digest::SHA256.hexdigest(content) == expected_sha256
        fail!("reviewed historical sensitive blob differs from its frozen hash")
      end
      exempt << object
    end
    exempt
  end

  def git_object_metadata(object_ids)
    return {} if object_ids.empty?

    input = object_ids.join("\n") + "\n"
    output = git(
      "cat-file",
      "--batch-check=%(objectname) %(objecttype) %(objectsize)",
      stdin_data: input,
      binary: true
    )
    records = {}
    output.each_line do |line|
      match = line.match(/\A([0-9a-f]{40}) ([a-z]+) ([0-9]+)\n\z/)
      fail!("malformed Git object metadata") unless match
      records[match[1]] = {
        type: match[2],
        size: match[3].to_i
      }
    end
    unless records.keys == object_ids
      fail!("Git object metadata order or identity differs")
    end
    records
  end

  def read_git_blobs(object_ids)
    read_git_objects(object_ids, "blob")
  end

  def read_git_objects(object_ids, expected_type)
    return {} if object_ids.empty?

    output = git(
      "cat-file",
      "--batch",
      stdin_data: object_ids.join("\n") + "\n",
      binary: true
    )
    cursor = 0
    object_ids.each_with_object({}) do |object, records|
      line_end = output.index("\n".b, cursor)
      fail!("malformed Git object batch header") unless line_end
      header = output.byteslice(cursor, line_end - cursor)
      match = header.match(
        /\A#{Regexp.escape(object)} #{Regexp.escape(expected_type)} ([0-9]+)\z/
      )
      fail!("unexpected Git batch object") unless match
      size = match[1].to_i
      content_start = line_end + 1
      content = output.byteslice(content_start, size)
      terminator = output.getbyte(content_start + size)
      unless content&.bytesize == size && terminator == 10
        fail!("malformed Git object batch payload")
      end
      records[object] = content
      cursor = content_start + size + 1
    end.tap do
      fail!("Git object batch has trailing bytes") unless cursor == output.bytesize
    end
  end

  def scan_sensitive_content(path, content)
    scan_views(content, path).each do |candidate, structured|
      if candidate.match?(/-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----/)
        fail!("private key material found in #{path}")
      end
      if structured
        scan_json_payloads(candidate, path)
        scan_yaml_payloads(candidate, path)
      end
      if candidate.each_line.any? do |line|
           match = line.match(credential_assignment_pattern)
           match &&
             !rust_field_declaration?(path, line) &&
             source_assignment_requires_scan?(path, match[0]) &&
             !(
               source_code_path?(path) &&
               technical_source_fixture_assignment?(match[0])
             ) &&
             !governance_authorization_assignment?(match[0])
         end
        fail!("credential-like assignment found in #{path}")
      end

      scan_residential_assignments(candidate, path)
    end
  end

  def scan_historical_sensitive_content(path, content)
    scan_views(content, path).each do |candidate, structured|
      if candidate.match?(/-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----/)
        fail!("private key material found in #{path}")
      end
      if structured
        if path.end_with?(".json") || protected_json_key_candidate?(candidate)
          scan_json_payloads(candidate, path)
        end
        if protected_yaml_key_candidate?(candidate)
          scan_yaml_payloads(candidate, path)
        end
      end
      if candidate.each_line.any? do |line|
           match = line.match(credential_assignment_pattern)
           match &&
             !rust_field_declaration?(path, line) &&
             source_assignment_requires_scan?(path, match[0]) &&
             !(
               source_code_path?(path) &&
               technical_source_fixture_assignment?(match[0])
             ) &&
             !governance_authorization_assignment?(match[0])
         end
        fail!("credential-like assignment found in #{path}")
      end
      scan_residential_assignments(candidate, path)
    end
  rescue GovernanceError => error
    raise unless historical_markdown_limit_error?(error)
    raise if historical_markup_sensitive_assignment?(content)
  end

  def historical_markdown_limit_error?(error)
    error.message.match?(
      /\AMarkdown (?:delimiter nesting|image normalization|link normalization|reference normalization) limit exceeded\z/
    )
  end

  def historical_markup_sensitive_assignment?(content)
    privacy_keys = CANONICAL_CREDENTIAL_KEYS | CANONICAL_RESIDENTIAL_KEYS
    stripped = strip_markdown_html(repeatedly_decode_text(content))
    stripped.each_line.any? do |line|
      left = line.split(/[:=]/, 2).first
      next false if left == line

      canonical = canonical_sensitive_key(left)
      privacy_keys.any? { |key| canonical.include?(key) }
    end
  end

  def credential_assignment_pattern
    @credential_assignment_pattern ||= begin
      keys = assignment_key_pattern(CREDENTIAL_KEYS.to_a + %w[AWS_SECRET_ACCESS_KEY])
      value = /(?:(?:[>|][+-]?)\s*\r?\n[ \t]+)?\S{1,4096}/
      /(?<![A-Za-z0-9_])["']?(?:#{keys})(?![A-Za-z0-9_])["']?\s*(?::(?!:)|=(?!>))\s*#{value}/i
    end
  end

  def rust_field_declaration?(path, line)
    path.end_with?(".rs") &&
      line.match?(
        /\A[ \t]*pub(?:\([^)\r\n]+\))?[ \t]+[a-z_][a-z0-9_]*[ \t]*:[ \t]*[A-Z][A-Za-z0-9_:<>,\[\]()&' \t]*,[ \t]*(?:\/\/[^\r\n]*)?\r?\n?\z/
      )
  end

  def source_assignment_requires_scan?(path, matched_assignment)
    return false if path.match?(%r{(?:\A|/)vendor/}) &&
                    source_code_path?(path)
    return true unless source_code_path?(path)

    value = matched_assignment[
      /(?::(?!:)|=(?!>))[ \t]*(.*)\z/m,
      1
    ].to_s.lstrip
    if path.end_with?(".rs")
      value.match?(/\A(?:(?:b|c)?r\#*|b|c)?"/)
    elsif path.end_with?(".py")
      value.match?(/\A(?:[bfru]{0,3})?["']/i)
    elsif path.end_with?(".rb")
      value.match?(
        /\A(?:["']|%[qQwWiIxrs]?[^\w\s=]|<<[-~]?["']?[A-Za-z_])/
      )
    else
      value.match?(/\A["']/)
    end
  end

  def source_code_path?(path)
    path.end_with?(".py", ".rb", ".rs", ".toml") ||
      File.basename(path) == "Cargo.lock"
  end

  def technical_source_fixture_assignment?(assignment)
    value = assignment[
      /(?::(?!:)|=(?!>))[ \t]*(.*)\z/m,
      1
    ].to_s.lstrip
    match = value.match(/\A(?:[bfru]{0,3})?(["'])([^"']*)\1/i)
    return false unless match
    return true if match[2].match?(/fixture(?:_tecnica)?[_.]/i)
    return true if match[2].match?(/\A([0-9a-f]{2})\1{15}\z/i)

    match[2].match?(/\A[0-9a-f]{2}\z/i) &&
      value.match?(/\A(?:[bfru]{0,3})?(["'])[0-9a-f]{2}\1\s*\*\s*16\b/i)
  end

  def governance_authorization_assignment?(assignment)
    key, value = assignment.split(/(?::(?!:)|=(?!>))/, 2)
    canonical_sensitive_key(key) == "authorization" &&
      value.to_s.strip.match?(/\A[`"']?USR-\d{3}[`"']?\z/)
  end

  def scan_residential_assignments(content, path)
    return if path.end_with?(".rs")

    keys = assignment_key_pattern(RESIDENTIAL_KEYS)
    pattern =
      /(?<![A-Za-z0-9_])["']?(?:#{keys})(?![A-Za-z0-9_])["']?\s*(?::(?!:)|=(?!>))\s*(.*)$/i
    lines = content.each_line.to_a
    lines.each_with_index do |line, index|
      match = line.match(pattern)
      next unless match
      next if rust_field_declaration?(path, line)
      next unless source_assignment_requires_scan?(path, match[0])
      if source_code_path?(path)
        next if technical_source_fixture_assignment?(match[0])

        fail!("residential-data assignment found in #{path}")
      end
      if exact_yaml_fixture_assignment?(
        lines,
        index,
        match.begin(0),
        path
      )
        next
      end
      if technical_fixture_assignment?(match[1])
        base_indent = match.begin(0)
        continuation = lines[(index + 1)..]&.find do |candidate|
          stripped = candidate.strip
          !stripped.empty? && !stripped.start_with?("#")
        end
        if continuation &&
           continuation[/\A[ \t]*/].to_s.length > base_indent
          fail!("residential-data assignment found in #{path}")
        end
        next
      end

      fail!("residential-data assignment found in #{path}")
    end
  end

  def exact_yaml_fixture_assignment?(lines, start_index, base_indent, path)
    buffer = String.new
    last_parsed = nil
    parsed_once = false
    candidate_lines = lines.drop(start_index)
    block_complete = false

    candidate_lines.first(MAX_YAML_ASSIGNMENT_LINES).each_with_index do |line, offset|
      stripped = line.strip
      indentation = line[/\A[ \t]*/].to_s.length
      if offset.positive? && parsed_once &&
         !stripped.empty? && !stripped.start_with?("#") &&
         indentation <= base_indent
        block_complete = true
        break
      end

      buffer << line
      if buffer.bytesize > MAX_YAML_ASSIGNMENT_BYTES
        fail!("YAML assignment scan byte limit exceeded in #{path}")
      end
      begin
        stream = Psych.parse_stream(buffer, "#{path}#line")
        next unless stream.children.length == 1

        reject_unsafe_yaml(stream, path)
        parsed = Psych.safe_load(
          buffer,
          [],
          [],
          false,
          "#{path}#line",
          symbolize_names: false
        )
        reject_non_string_yaml_keys(parsed, path)
        last_parsed = parsed
        parsed_once = true
      rescue Psych::Exception
        last_parsed = nil
        next
      rescue SystemStackError
        fail!("YAML assignment parser stack exhausted in #{path}")
      end
    end
    if !block_complete &&
       candidate_lines.length > MAX_YAML_ASSIGNMENT_LINES
      next_line = candidate_lines.fetch(MAX_YAML_ASSIGNMENT_LINES)
      stripped = next_line.strip
      indentation = next_line[/\A[ \t]*/].to_s.length
      if !parsed_once || stripped.empty? || stripped.start_with?("#") ||
         indentation > base_indent
        fail!("YAML assignment scan line limit exceeded in #{path}")
      end
    end

    return false unless last_parsed &&
                        structured_exact_residential_fixture?(last_parsed)

    scan_sensitive_structure(last_parsed, path, "$line")
    true
  end

  def structured_exact_residential_fixture?(value)
    case value
    when Hash
      value.any? do |key, nested|
        (CANONICAL_RESIDENTIAL_KEYS.include?(canonical_sensitive_key(key)) &&
          technical_fixture_value?(nested)) ||
          structured_exact_residential_fixture?(nested)
      end
    when Array
      value.any? { |nested| structured_exact_residential_fixture?(nested) }
    else
      false
    end
  end

  def technical_fixture_assignment?(value)
    unquoted = value.strip.sub(/\A["']/, "").sub(/["']\z/, "")
    technical_fixture_value?(unquoted)
  end

  def assignment_key_pattern(keys)
    keys.map do |key|
      key.split("_").map { |part| Regexp.escape(part) }.join("[_.-]*")
    end.join("|")
  end

  def scan_json_payloads(content, path)
    protected_candidate =
      embedded_protected_json_key_candidate_for?(
        content,
        PROTECTED_STRUCTURED_KEYS,
        nested_strings:
          structured_document_path?(path) || path.end_with?(".json")
      )
    if path.end_with?(".json")
      parsed = parse_json(content, path, strict: true)
      scan_sensitive_structure(parsed, path) if protected_candidate
    end
    return unless protected_candidate
    return if source_code_path?(path)

    bounded_json_fragments(content, path).each_with_index do |fragment, index|
      parsed = parse_json(fragment, path, strict: false)
      next unless parsed

      scan_sensitive_structure(parsed, path, "$fragment[#{index}]")
    end
  end

  def parse_json(content, path, strict:)
    JSON.parse(content, object_class: DuplicateRejectingJsonObject)
  rescue DuplicateJsonKeyError
    fail!("duplicate JSON key found in #{path}")
  rescue JSON::ParserError => error
    if strict || protected_json_key_candidate?(content)
      fail!("invalid JSON payload in #{path}: #{error.message}")
    end
    nil
  end

  def protected_json_key_candidate?(content)
    protected_json_key_candidate_for?(content, PROTECTED_STRUCTURED_KEYS)
  end

  def embedded_protected_json_key_candidate_for?(
    content,
    protected_keys,
    nested_strings:
  )
    protected_json_key_candidate_for?(content, protected_keys) ||
      protected_json_key_candidate_for?(content.delete("\\"), protected_keys) ||
      (
        nested_strings &&
        protected_json_string_payload_candidate_for?(content, protected_keys)
      )
  end

  def protected_json_string_payload_candidate_for?(content, protected_keys)
    string_pattern =
      /"(?:\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})|[^"\\\x00-\x1f])*"/
    content.scan(string_pattern).any? do |literal|
      next false unless literal.include?(":")

      decoded = decode_json_key_candidate(literal)
      decoded &&
        (
          protected_json_key_candidate_for?(decoded, protected_keys) ||
          protected_yaml_key_candidate_for?(decoded, protected_keys) ||
          protected_key_name_candidate_for?(decoded, protected_keys)
        )
    end
  end

  def protected_json_key_candidate_for?(content, protected_keys)
    key_pattern =
      /("(?:\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})|[^"\\\x00-\x1f])*")\s*:/
    content.scan(key_pattern).flatten.any? do |literal|
      key = decode_json_key_candidate(literal)
      key && protected_keys.include?(canonical_sensitive_key(key))
    end
  end

  def decode_json_key_candidate(literal)
    JSON.parse(literal)
  rescue JSON::ParserError
    sanitized = literal.gsub(/\\u[dD][89a-fA-F][0-9a-fA-F]{2}/, "")
    begin
      JSON.parse(sanitized)
    rescue JSON::ParserError
      nil
    end
  end

  def reject_malformed_protected_flow_fragment(content, start_index, end_index, path)
    fragment = content.byteslice(start_index, end_index - start_index + 1)
    if protected_json_key_candidate?(fragment)
      fail!("invalid JSON payload in #{path}: malformed protected JSON fragment")
    end
    if protected_yaml_key_candidate?(fragment)
      fail!("invalid YAML payload in #{path}: malformed protected YAML fragment")
    end
  end

  def decode_yaml_mapping_key(captures)
    if captures.fetch(0)
      source = "\"#{captures.fetch(0)}\""
    elsif captures.fetch(1)
      source = "'#{captures.fetch(1)}'"
    else
      return captures.fetch(2).to_s
    end
    parsed = Psych.safe_load(
      source,
      [],
      [],
      false,
      "embedded YAML mapping key",
      symbolize_names: false
    )
    parsed.is_a?(String) ? parsed : captures.compact.first.to_s
  rescue Psych::Exception
    captures.compact.first.to_s
  rescue SystemStackError
    fail!("YAML mapping-key parser stack exhausted")
  end

  def protected_yaml_key_candidate?(content)
    protected_yaml_key_candidate_for?(content, PROTECTED_STRUCTURED_KEYS)
  end

  def protected_provider_yaml_key_candidate?(content)
    protected_yaml_key_candidate_for?(content, PROTECTED_PROVIDER_KEYS)
  end

  def protected_yaml_document_key_candidate?(content, path, protected_keys)
    return true if protected_yaml_key_candidate_for?(content, protected_keys)
    return false unless path.end_with?(".md", ".markdown")

    normalized = yaml_block_scan_lines(
      content,
      markdown_containers: true
    ).join
    protected_yaml_key_candidate_for?(normalized, protected_keys)
  end

  def protected_key_name_candidate_for?(content, protected_keys)
    normalized = content.gsub(/\\\r?\n[ \t]*/, "")
    normalized.scan(/[A-Za-z_][A-Za-z0-9_.-]*/).any? do |token|
      protected_keys.include?(canonical_sensitive_key(token))
    end
  end

  def protected_yaml_key_candidate_for?(content, protected_keys)
    mapping_keys = content.scan(
      /(?:[\[{,][ \t]*|^[ \t]*(?![\[{,])(?:-[ \t]+)*(?:\?[ \t]+)?)(?:(?:&|!)[^ \t\r\n,\[\]{}]+[ \t]+)*(?:"((?:\\.|[^"\\\r\n])*)"|'((?:''|[^'\r\n])*)'|(#{YAML_BLOCK_PLAIN_KEY_SOURCE}))\s*:(?=[ \t\r\n,\]}]|\z)/
    )
    explicit_keys = content.scan(
      /^[ \t]*\?[ \t]+(?:(?:&|!)[^ \t\r\n,\[\]{}]+[ \t]+)*(?:"((?:\\.|[^"\\\r\n])*)"|'((?:''|[^'\r\n])*)'|(#{YAML_BLOCK_PLAIN_KEY_SOURCE}))[ \t]*$/m
    )
    flow_set_keys = content.scan(
      /(?:\{|,)\s*(?:(?:&|!)[^ \t\r\n,\[\]{}]+[ \t]+)*(?:"((?:\\.|[^"\\\r\n])*)"|'((?:''|[^'\r\n])*)'|(#{YAML_FLOW_PLAIN_KEY_SOURCE}))\s*(?=,|\})/
    )
    (mapping_keys + explicit_keys + flow_set_keys).any? do |captures|
      raw = decode_yaml_mapping_key(captures)
      protected_keys.include?(canonical_sensitive_key(raw))
    end
  end

  def dedicated_sensitive_assignment_start?(content)
    keys = assignment_key_pattern(
      CREDENTIAL_KEYS.to_a +
      %w[AWS_SECRET_ACCESS_KEY] +
      RESIDENTIAL_KEYS.to_a
    )
    match = content.match(
      /\A["']?(?:#{keys})(?![A-Za-z0-9_])["']?\s*:\s*([^\r\n]*)/i
    )
    return false unless match

    !match[1].strip.match?(/\A[>|][+-]?(?:\s+#.*)?\z/)
  end

  def leading_protected_yaml_key_candidate?(content)
    match = content.match(yaml_mapping_pattern)
    return false unless match

    raw = decode_yaml_mapping_key(match.captures.drop(1))
    PROTECTED_STRUCTURED_KEYS.include?(canonical_sensitive_key(raw))
  end

  def yaml_mapping_pattern
    @yaml_mapping_pattern ||=
      /\A([ \t]*)(?:-[ \t]+)*(?:\?[ \t]+)?(?:(?:&|!)[^ \t\r\n]+[ \t]+)*(?:"((?:\\.|[^"\\\r\n])*)"|'((?:''|[^'\r\n])*)'|(#{YAML_BLOCK_PLAIN_KEY_SOURCE}))\s*:(?=[ \t\r\n]|\z)/
  end

  def yaml_block_scan_lines(content, markdown_containers: false)
    yaml_block_scan_records(
      content,
      markdown_containers: markdown_containers
    ).map { |record| record.fetch(:line) }
  end

  def yaml_block_scan_records(content, markdown_containers:)
    content.gsub(/\r\n?/, "\n").lines.map do |line|
      unless markdown_containers
        next {
          line: line,
          raw: line,
          quote_depth: 0,
          list_item: false
        }
      end
      normalized = line
      count = 0
      quote_depth = 0
      list_item = false
      loop do
        match = normalized.match(
          /\A[ \t]*(?:(>)[ \t]?|([0-9]{1,9}[.)])[ \t]+|([+*])[ \t]+)/
        )
        break unless match

        fail!("Markdown YAML container nesting limit exceeded") if
          count >= MAX_MARKDOWN_NESTING
        quote_depth += 1 if match[1]
        list_item = true if match[2] || match[3]
        prefix_bytes = match[0].bytesize
        normalized =
          (" " * prefix_bytes) +
          normalized.byteslice(prefix_bytes, normalized.bytesize - prefix_bytes)
        count += 1
      end
      {
        line: normalized,
        raw: line,
        quote_depth: quote_depth,
        list_item: list_item
      }
    end
  end

  def duplicate_protected_yaml_mapping_key?(content)
    seen = Set.new
    yaml_block_scan_lines(content).any? do |line|
      match = line.match(
        /\A[ \t]*(?:"((?:\\.|[^"\\\r\n])*)"|'((?:''|[^'\r\n])*)'|([A-Za-z_][A-Za-z0-9_.-]*))\s*:/
      )
      next false unless match

      raw = decode_yaml_mapping_key(match.captures)
      normalized = canonical_sensitive_key(raw)
      next false unless PROTECTED_STRUCTURED_KEYS.include?(normalized)

      !seen.add?(normalized)
    end
  end

  def protected_yaml_blocks(
    content,
    protected_keys,
    markdown_containers:,
    include_node_properties:
  )
    return enum_for(
      __method__,
      content,
      protected_keys,
      markdown_containers: markdown_containers,
      include_node_properties: include_node_properties
    ) unless block_given?

    node_property_pattern =
      /(?:&[^ \t\r\n,\[\]{}]+|![^ \t\r\n,\[\]{}]+|\*[^* \t\r\n,\[\]{}]+)/
    records = yaml_block_scan_records(
      content,
      markdown_containers: markdown_containers
    )
    lines = records.map { |record| record.fetch(:line) }
    mapping_pattern = yaml_mapping_pattern
    explicit_structure = lambda do |candidate|
      candidate.match(/\A([ \t]*)(?:-[ \t]+)*\?[ \t]+\S/) ||
        candidate.match(
          /\A([ \t]*)(?:-[ \t]+)*\?[ \t]*(?:#[^\r\n]*)?(?:\r?\n)?\z/
        )
    end
    document_control = lambda do |candidate|
      candidate.match?(
        /\A[ \t]*(?:%[^\r\n]*|---(?:[ \t]+[^\r\n]*)?|\.\.\.(?:[ \t]+[^\r\n]*)?)(?:\r?\n)?\z/
      )
    end
    flow_closer = lambda do |candidate|
      candidate.match?(
        /\A[ \t]*[\]}]+[ \t]*(?:,[ \t]*)?(?:#[^\r\n]*)?(?:\r?\n)?\z/
      )
    end
    indentless_sequence = lambda do |candidate|
      candidate.match?(/\A[ \t]*-(?:[ \t]+|(?:\r?\n)?\z)/)
    end
    empty_mapping_value = lambda do |candidate|
      candidate.match?(/:\s*(?:#[^\r\n]*)?(?:\r?\n)?\z/)
    end
    markdown_reference = lambda do |candidate|
      markdown_containers &&
        candidate.match?(/\A[ \t]*\[[^\]\r\n]+\]:[ \t]+/)
    end
    markdown_code_field = lambda do |candidate|
      markdown_containers &&
        candidate.match?(
          /\A[ \t]*[^#\[\]{},\r\n]+?:[ \t]*`[^`\r\n]+`[ \t]*(?:\r?\n)?\z/
        )
    end
    markdown_reference_labels =
      markdown_containers ? markdown_reference_labels(content) : Set.new
    markdown_reference_continuations = Set.new
    if markdown_containers
      definition_indent = nil
      continuation_stage = nil
      records.each_with_index do |record, record_index|
        candidate = record.fetch(:line)
        indentation = candidate[/\A[ \t]*/].to_s.length
        if markdown_reference_definition_label(record.fetch(:raw))
          definition_indent = indentation
          continuation_stage = :destination_or_title
        elsif definition_indent &&
              !candidate.strip.empty? &&
              indentation > definition_indent
          if markdown_reference_title_line?(record.fetch(:raw))
            markdown_reference_continuations << record_index
            definition_indent = nil
            continuation_stage = nil
          elsif continuation_stage == :destination_or_title &&
                markdown_reference_destination_line?(record.fetch(:raw))
            markdown_reference_continuations << record_index
            continuation_stage = :title
          else
            definition_indent = nil
            continuation_stage = nil
          end
        else
          definition_indent = nil
          continuation_stage = nil
        end
      end
    end

    block_cache = {}
    lines.each_with_index do |line, index|
      next if markdown_containers &&
              (
                markdown_label_line?(
                  records.fetch(index).fetch(:raw),
                  markdown_reference_labels
                ) ||
                markdown_code_field.call(line) ||
                markdown_styled_protected_mapping_line?(
                  records.fetch(index).fetch(:raw),
                  protected_keys
                )
              )

      mapping_match = line.match(mapping_pattern)
      explicit_structure_match = explicit_structure.call(line)
      alias_match = line.match(
        /\A([ \t]*)(?:-[ \t]+)*(?:\?[ \t]+)?\*[^* \t\r\n:]+[ \t]*:/
      )
      standalone_property_match =
        include_node_properties && line.match(
          /\A([ \t]*)(?:-[ \t]+)*(?:#{node_property_pattern}[ \t]*)+(?:#[^\r\n]*)?(?:\r?\n)?\z/
        )
      property_value_match =
        include_node_properties && line.match(
          /\A([ \t]*)(?:-[ \t]+)*(?:"(?:\\.|[^"\\\r\n])*"|'(?:''|[^'\r\n])*'|[A-Za-z_][A-Za-z0-9_.-]*)\s*:\s*(?:[\[{,][ \t]*)*(?:#{node_property_pattern}[ \t]*)+/
        )
      flow_property_match =
        include_node_properties && line.match(
          /\A([ \t]*)(?:-[ \t]+)*(?:#{node_property_pattern}[ \t]*)+[\[{]/
        )
      flow_set_match =
        line.match(/\A([ \t]*)(?:-[ \t]+)*[\[{]/) if
          protected_yaml_key_candidate_for?(line, protected_keys)
      match =
        mapping_match ||
        explicit_structure_match ||
        alias_match ||
        standalone_property_match ||
        property_value_match ||
        flow_property_match ||
        flow_set_match
      next unless match

      protected_mapping = false
      unless alias_match ||
             explicit_structure_match ||
             standalone_property_match ||
             property_value_match ||
             flow_property_match ||
             flow_set_match
        raw = decode_yaml_mapping_key(match.captures.drop(1))
        protected_mapping =
          protected_keys.include?(canonical_sensitive_key(raw))
        next unless protected_mapping
      end
      protected_mapping = true if flow_set_match

      base_indent = match[1].length
      base_quote_depth = records.fetch(index).fetch(:quote_depth)
      cache_key =
        [base_indent, base_quote_depth] if mapping_match && protected_mapping
      cached = block_cache[cache_key] if cache_key
      if cached &&
         index >= cached.fetch(:start) &&
         index < cached.fetch(:finish)
        yield cached.fetch(:block)
        next
      end
      start = index
      cursor = index - 1
      blank_between = false
      while cursor >= 0
        break if markdown_reference_continuations.include?(cursor)

        record = records.fetch(cursor)
        candidate = record.fetch(:line)
        stripped = candidate.strip
        indentation = candidate[/\A[ \t]*/].to_s.length
        container_boundary =
          markdown_containers &&
          !stripped.empty? &&
          !stripped.start_with?("#") &&
          (
            record.fetch(:quote_depth) != base_quote_depth ||
            record.fetch(:list_item)
          )
        break if container_boundary || indentation < base_indent
        break if markdown_code_field.call(candidate)
        break if markdown_containers &&
                 blank_between &&
                 indentation >= base_indent + 4

        structural =
          stripped.empty? ||
          stripped.start_with?("#") ||
          indentation > base_indent ||
          (
            indentation == base_indent &&
            (
              (
                candidate.match?(mapping_pattern) &&
                !markdown_reference.call(candidate)
              ) ||
              explicit_structure.call(candidate) ||
              candidate.match?(/\A[ \t]*:/) ||
              document_control.call(candidate) ||
              flow_closer.call(candidate) ||
              indentless_sequence.call(candidate) ||
              candidate.match?(
                /\A[ \t]*(?:#{node_property_pattern}[ \t]*)+(?:[\[{])?/
              )
            )
          )
        break unless structural

        start = cursor
        if stripped.empty?
          blank_between = true
        elsif !stripped.start_with?("#")
          blank_between = false
        end
        cursor -= 1
      end

      finish = index + 1
      explicit_value_indent =
        explicit_structure_match && line.index("?")
      include_next_node = !standalone_property_match.nil?
      expect_indentless_sequence = empty_mapping_value.call(line)
      in_indentless_sequence = false
      indented_value_expected =
        empty_mapping_value.call(line) ||
        line.match?(/:\s*[>|][+-]?\s*(?:#[^\r\n]*)?(?:\r?\n)?\z/) ||
        line.match?(/[\[{]\s*(?:#[^\r\n]*)?(?:\r?\n)?\z/)
      blank_since_content = false
      while finish < lines.length
        record = records.fetch(finish)
        candidate = lines.fetch(finish)
        stripped = candidate.strip
        indentation = candidate[/\A[ \t]*/].to_s.length
        container_boundary =
          markdown_containers &&
          !stripped.empty? &&
          !stripped.start_with?("#") &&
          (
            record.fetch(:quote_depth) != base_quote_depth ||
            record.fetch(:list_item)
          )
        break if container_boundary
        break if markdown_containers &&
                 blank_since_content &&
                 indentation >= base_indent + 4 &&
                 !indented_value_expected

        if include_next_node && !stripped.empty? && !stripped.start_with?("#")
          finish += 1
          include_next_node = false
          blank_since_content = false
          next
        end
        if explicit_value_indent &&
           indentation == explicit_value_indent &&
           candidate.match?(/\A[ \t]*:/)
          finish += 1
          explicit_value_indent = nil
          expect_indentless_sequence = empty_mapping_value.call(candidate)
          in_indentless_sequence = false
          indented_value_expected =
            expect_indentless_sequence ||
            candidate.match?(
              /:\s*[>|][+-]?\s*(?:#[^\r\n]*)?(?:\r?\n)?\z/
            ) ||
            candidate.match?(/[\[{]\s*(?:#[^\r\n]*)?(?:\r?\n)?\z/)
          blank_since_content = false
          next
        end
        sibling_mapping =
          candidate.match(mapping_pattern) unless
            markdown_reference.call(candidate) ||
            markdown_code_field.call(candidate)
        sibling_mapping_at_base =
          protected_mapping &&
          sibling_mapping &&
          indentation == base_indent
        if sibling_mapping_at_base
          finish += 1
          expect_indentless_sequence = empty_mapping_value.call(candidate)
          in_indentless_sequence = false
          indented_value_expected =
            expect_indentless_sequence ||
            candidate.match?(
              /:\s*[>|][+-]?\s*(?:#[^\r\n]*)?(?:\r?\n)?\z/
            ) ||
            candidate.match?(/[\[{]\s*(?:#[^\r\n]*)?(?:\r?\n)?\z/)
          blank_since_content = false
          next
        end
        sibling_explicit =
          protected_mapping &&
          indentation == base_indent &&
          explicit_structure.call(candidate)
        if sibling_explicit
          finish += 1
          explicit_value_indent = base_indent
          expect_indentless_sequence = false
          in_indentless_sequence = false
          indented_value_expected = false
          blank_since_content = false
          next
        end
        sibling_document_control =
          protected_mapping &&
          indentation == base_indent &&
          document_control.call(candidate)
        if sibling_document_control
          finish += 1
          expect_indentless_sequence = false
          in_indentless_sequence = false
          indented_value_expected = false
          blank_since_content = false
          next
        end
        if protected_mapping &&
           indentation == base_indent &&
           flow_closer.call(candidate)
          finish += 1
          indented_value_expected = false
          blank_since_content = false
          next
        end
        if protected_mapping &&
           indentation == base_indent &&
           indentless_sequence.call(candidate) &&
           (expect_indentless_sequence || in_indentless_sequence)
          finish += 1
          expect_indentless_sequence = false
          in_indentless_sequence = true
          indented_value_expected = false
          blank_since_content = false
          next
        end
        break if !stripped.empty? &&
                 !stripped.start_with?("#") &&
                 indentation <= base_indent

        finish += 1
        if stripped.empty?
          blank_since_content = true
        elsif !stripped.start_with?("#")
          blank_since_content = false
        end
      end
      block = lines[start...finish].map do |candidate|
        indentation = candidate[/\A[ \t]*/].to_s.length
        remove = [base_indent, indentation].min
        candidate.byteslice(remove, candidate.bytesize - remove)
      end.join
      if cache_key
        block_cache[cache_key] = {
          start: start,
          finish: finish,
          block: block
        }
      end
      yield block
    end
  end

  def bounded_json_fragments(content, path)
    balanced_json_fragments(content, path)
      .uniq
      .sort_by { |fragment| [-fragment.bytesize, fragment.b] }
  end

  def balanced_json_fragments(content, path)
    fragments = []
    candidates = []
    candidate_count = 0
    content.each_byte.with_index do |byte, index|
      candidates.each do |candidate|
        if candidate.fetch("in_string")
          if candidate.fetch("escaped")
            candidate["escaped"] = false
          elsif byte == 92
            candidate["escaped"] = true
          elsif byte == 34
            candidate["in_string"] = false
          end
          next
        end

        case byte
        when 34
          candidate["in_string"] = true
        when 123, 91
          stack = candidate.fetch("stack")
          if stack.length >= MAX_EMBEDDED_JSON_DEPTH
            fail!("embedded JSON nesting depth limit exceeded in #{path}")
          end
          stack << (byte == 123 ? 125 : 93)
        when 125, 93
          stack = candidate.fetch("stack")
          if stack.last != byte
            reject_malformed_protected_flow_fragment(
              content,
              candidate.fetch("start"),
              index,
              path
            )
            candidate["discard"] = true
            next
          end

          stack.pop
          if stack.empty?
            if fragments.length >= MAX_EMBEDDED_JSON_FRAGMENTS
              fail!("embedded JSON fragment limit exceeded in #{path}")
            end
            start = candidate.fetch("start")
            fragments << content.byteslice(start, index - start + 1)
            candidate["complete"] = true
          end
        end
      end
      candidates.reject! do |candidate|
        candidate["complete"] || candidate["discard"]
      end

      next unless byte == 123 || byte == 91

      if candidate_count >= MAX_EMBEDDED_JSON_CANDIDATES
        fail!("embedded JSON candidate limit exceeded in #{path}")
      end
      candidates << {
        "start" => index,
        "stack" => [byte == 123 ? 125 : 93],
        "in_string" => false,
        "escaped" => false,
        "complete" => false,
        "discard" => false
      }
      candidate_count += 1
    end
    candidates.each do |candidate|
      reject_malformed_protected_flow_fragment(
        content,
        candidate.fetch("start"),
        content.bytesize - 1,
        path
      )
    end
    fragments
  end

  def scan_yaml_payloads(content, path)
    return unless structured_document_path?(path)
    return unless
      protected_yaml_document_key_candidate?(
        content,
        path,
        PROTECTED_STRUCTURED_KEYS
      )

    parsed_yaml_payloads(
      content,
      path,
      protected_keys: PROTECTED_STRUCTURED_KEYS,
      preserve_assignment_oracle: true
    ).each_with_index do |parsed, index|
      scan_sensitive_structure(parsed, path, "$yaml[#{index}]")
    end
  end

  def structured_document_path?(path)
    path.end_with?(
      ".md",
      ".markdown",
      ".yaml",
      ".yml"
    )
  end

  def parsed_yaml_payloads(
    content,
    path,
    whole_document: true,
    extract_blocks: !path.end_with?(".yaml", ".yml"),
    protected_keys: PROTECTED_PROVIDER_KEYS,
    preserve_assignment_oracle: false
  )
    collection = {
      candidates: [],
      seen: Set.new,
      count: 0,
      bytes: 0
    }
    add_candidate = lambda do |candidate, strict, safety_only = nil|
      append_yaml_payload_candidate!(
        collection,
        candidate,
        strict,
        safety_only,
        path
      )
    end
    markdown_containers = path.end_with?(".md", ".markdown")
    probe = content.gsub(/\r\n?/, "\n").lines.drop_while do |line|
      line.strip.empty? || line.lstrip.start_with?("#")
    end.join.lstrip
    if whole_document && path.end_with?(".yaml", ".yml")
      add_candidate.call(content, true)
    elsif probe.start_with?("---")
      add_candidate.call(content, true)
    elsif !markdown_containers &&
          (
            probe.start_with?("{") ||
            probe.match?(/\A\?(?:[ \t]+|\n)/) ||
            probe.match?(/\A-(?:[ \t]+|\n)/) ||
            leading_protected_yaml_key_candidate?(probe)
          )
      if protected_yaml_key_candidate?(probe)
        if dedicated_sensitive_assignment_start?(probe)
          add_candidate.call(
            content,
            duplicate_protected_yaml_mapping_key?(content),
            true
          )
        else
          strict = probe.start_with?("{") ||
            probe.match?(/\A\?(?:[ \t]+|\n)/) ||
            probe.match?(/\A-(?:[ \t]+|\n)/) ||
            leading_protected_yaml_key_candidate?(probe)
          add_candidate.call(content, strict)
        end
      end
    end
    if extract_blocks
      protected_yaml_blocks(
        content,
        protected_keys,
        markdown_containers: markdown_containers,
        include_node_properties:
          markdown_containers ||
          leading_markdown_image?(probe) ||
          (
            preserve_assignment_oracle &&
            dedicated_sensitive_assignment_start?(probe)
          )
      ).each do |candidate|
        assignment_present = candidate.each_line.any? do |line|
          dedicated_sensitive_assignment_start?(line.lstrip)
        end
        unsafe_assignment_context = candidate.each_line.any? do |line|
          stripped = line.strip
          next false if stripped.empty? || stripped.start_with?("#")

          stripped.match?(
            /\A(?:%|---(?:\s|\z)|\.\.\.(?:\s|\z)|\?|<<\s*:|[\]}])/
          ) ||
            stripped.match?(
              /(?:\A|[\s\[{,:-])(?:&|!|\*)[^* \t\r\n,\[\]{}]+/
            )
        end
        assignment_candidate =
          preserve_assignment_oracle &&
          assignment_present &&
          !unsafe_assignment_context
        add_candidate.call(
          candidate,
          !assignment_candidate,
          assignment_candidate
        )
      end
    end
    unless whole_document && path.end_with?(".yaml", ".yml")
      bounded_json_fragments(content, path).each do |fragment|
        if protected_yaml_key_candidate?(fragment)
          add_candidate.call(fragment, true)
        end
      end
    end
    fence_content = content.gsub(/\r\n?/, "\n")
    [
      /^[ ]{0,3}(`{3,})[ \t]*(?:yaml|yml)(?:[ \t]+[^`\r\n]*)?[ \t]*\r?\n(.*?)^[ ]{0,3}\1`*[ \t]*\r?$/mi,
      /^[ ]{0,3}(~{3,})[ \t]*(?:yaml|yml)(?:[ \t]+[^\r\n]*)?[ \t]*\r?\n(.*?)^[ ]{0,3}\1~*[ \t]*\r?$/mi
    ].each do |fence_pattern|
      fence_content.scan(fence_pattern) do |match|
        add_candidate.call(match.fetch(1), true)
      end
    end

    collection.fetch(:candidates).each_with_index.map do |(candidate, strict, safety_only), index|
      source = "#{path}#yaml[#{index}]"
      begin
        stream = Psych.parse_stream(candidate, source)
        fail!("YAML payload must contain exactly one document in #{path}") unless
          stream.children.length == 1
        reject_unsafe_yaml(
          stream,
          source,
          extended_string_keys:
            whole_document && path.end_with?(".yaml", ".yml")
        )
        parsed = Psych.safe_load(
          candidate,
          [],
          [],
          false,
          source,
          symbolize_names: false
        )
      rescue Psych::Exception => error
        if strict
          fail!("invalid YAML payload in #{path}: #{error.message}")
        end
        next
      rescue SystemStackError
        fail!("YAML payload parser stack exhausted in #{path}")
      end
      reject_non_string_yaml_keys(parsed, source)
      safety_only ? nil : parsed
    end.compact
  end

  def append_yaml_payload_candidate!(
    collection,
    candidate,
    strict,
    safety_only,
    path
  )
    if collection.fetch(:count) >= MAX_YAML_PAYLOAD_CANDIDATES
      fail!("YAML payload candidate limit exceeded in #{path}")
    end
    bytes = candidate.bytesize
    if bytes > MAX_YAML_PAYLOAD_AGGREGATE_BYTES - collection.fetch(:bytes)
      fail!("YAML payload aggregate byte limit exceeded in #{path}")
    end

    collection[:count] += 1
    collection[:bytes] += bytes
    tuple = [candidate, strict, safety_only]
    collection.fetch(:candidates) << tuple if collection.fetch(:seen).add?(tuple)
  end

  def scan_sensitive_structure(value, path, context = "$", depth = 0)
    fail!("nested structured payload exceeds scan depth in #{path}") if depth > 8

    case value
    when Hash
      value.each do |key, nested|
        normalized = canonical_sensitive_key(key)
        if CANONICAL_CREDENTIAL_KEYS.include?(normalized) &&
           !(
             normalized == "authorization" &&
             nested.is_a?(String) &&
             nested.match?(/\AUSR-\d{3}\z/)
           )
          fail!("credential field #{context}.#{key} found in #{path}")
        end
        if CANONICAL_RESIDENTIAL_KEYS.include?(normalized) &&
           !technical_fixture_value?(nested)
          fail!("residential-data field #{context}.#{key} found in #{path}")
        end
        scan_sensitive_structure(nested, path, "#{context}.#{key}", depth + 1)
      end
    when Array
      value.each_with_index do |nested, index|
        scan_sensitive_structure(nested, path, "#{context}[#{index}]", depth + 1)
      end
    when String
      bounded_json_fragments(value, path).each_with_index do |fragment, index|
        parsed = parse_json(fragment, path, strict: false)
        next unless parsed && parsed != value

        scan_sensitive_structure(
          parsed,
          path,
          "#{context}#json[#{index}]",
          depth + 1
        )
      end
      embedded_yaml_values(
        value,
        path,
        context,
        protected_keys: PROTECTED_STRUCTURED_KEYS
      ).each_with_index do |parsed_yaml, index|
        scan_sensitive_structure(
          parsed_yaml,
          path,
          "#{context}#yaml[#{index}]",
          depth + 1
        )
      end
    end
  end

  def canonical_sensitive_key(key)
    markdown_visible_text(repeatedly_decode_text(key.to_s))
      .downcase
      .gsub(/[^a-z0-9]/, "")
  end

  def protected_yaml_flow_sequence_payload(probe, path)
    return nil unless probe.start_with?("[")

    bounded_json_fragments(probe, path).find do |fragment|
      probe.start_with?(fragment) &&
        fragment.start_with?("[") &&
        protected_yaml_key_candidate?(fragment)
    end
  end

  def leading_markdown_image?(probe)
    return nil unless probe.start_with?("![")

    !matching_markdown_delimiter(
      probe.b,
      1,
      91,
      93,
      quote_aware: false
    ).nil?
  end

  def parse_embedded_yaml(value, path, context)
    probe = value.gsub(/\r\n?/, "\n").lines.drop_while do |line|
      line.strip.empty? || line.lstrip.start_with?("#")
    end.join.lstrip
    return nil if leading_markdown_image?(probe)

    flow_sequence = protected_yaml_flow_sequence_payload(probe, path)
    return nil unless probe.start_with?("---") ||
                      probe.start_with?("{") ||
                      flow_sequence ||
                      probe.match?(/\A[?%&*!|>]/) ||
                      probe.match?(/\A-(?:[ \t]+|\n)/) ||
                      probe.match?(/\A["']?[A-Za-z_][A-Za-z0-9_.\\-]*["']?\s*:/)

    candidate = flow_sequence || value
    stream = Psych.parse_stream(candidate, "#{path}#{context}")
    unless stream.children.length == 1
      fail!("embedded YAML payload must contain exactly one document in #{path}")
    end

    reject_unsafe_yaml(stream, path)
    parsed = Psych.safe_load(
      candidate,
      [],
      [],
      false,
      "#{path}#{context}",
      symbolize_names: false
    )
    reject_non_string_yaml_keys(parsed, path)
    parsed
  rescue Psych::Exception => error
    fail!("invalid embedded YAML payload in #{path}: #{error.class}")
  rescue SystemStackError
    fail!("embedded YAML parser stack exhausted in #{path}")
  end

  def embedded_yaml_values(value, path, context, protected_keys:)
    return [] unless
      protected_yaml_document_key_candidate?(value, path, protected_keys) ||
      protected_key_name_candidate_for?(value, protected_keys)

    values = []
    parsed = parse_embedded_yaml(value, path, context)
    values << parsed if parsed && parsed != value
    parsed_yaml_payloads(
      value,
      path,
      whole_document: false,
      extract_blocks: true,
      protected_keys: protected_keys
    ).each do |candidate|
      values << candidate if candidate != value
    end
    values.uniq
  end

  def technical_fixture_value?(value)
    value.is_a?(String) && value == "FIXTURE_TECNICA"
  end

  def validate_normative_files
    payload = P00_NORMATIVE_FILES.sort.map do |path|
      "#{path}\0".b + read(path, binary: true) + "\0".b
    end.join
    actual = Digest::SHA256.hexdigest(payload)
    unless actual == P00_NORMATIVE_FILES_SHA256
      fail!("P00 normative governance files differ from the frozen digest")
    end
  end

  def validate_p00_path_set
    return unless
      @yaml.fetch("docs/phases/PROJECT-STATUS.md").fetch("current_phase") == "P00"

    unexpected = tracked_paths - REQUIRED_FILES
    fail!("unexpected tracked P00 files: #{unexpected.join(', ')}") unless unexpected.empty?
  end

  def canonical_digest(value)
    Digest::SHA256.hexdigest(JSON.generate(canonical_value(value)))
  end

  def canonical_value(value)
    case value
    when Hash
      unless value.keys.all? { |key| key.is_a?(String) }
        fail!("canonical structured data contains a non-string key")
      end
      value.keys.sort.each_with_object({}) do |key, result|
        result[key] = canonical_value(value.fetch(key))
      end
    when Array
      value.map { |nested| canonical_value(nested) }
    else
      value
    end
  end

  def validate_archive
    archive = Dir.mktmpdir("nlu-governance-archive.") do |temporary|
      clone = File.join(temporary, "repository")
      command(
        GIT_EXECUTABLE,
        "clone",
        "--quiet",
        "--local",
        "--no-hardlinks",
        "--no-tags",
        "--single-branch",
        @root,
        clone,
        chdir: temporary
      )
      clone_head = command(
        GIT_EXECUTABLE,
        "-C",
        clone,
        "rev-parse",
        "HEAD"
      ).strip
      fail!("isolated archive clone resolved a different commit") unless clone_head == @expected_commit
      command(
        GIT_EXECUTABLE,
        "-C",
        clone,
        "archive",
        "--format=tar",
        @expected_commit,
        binary: true
      )
    end
    archive_paths = parse_tar_regular_paths(archive)
    fail!("steering file is present in source archive") if archive_paths.include?(STEERING_PATH)
    unless archive_paths.sort == tracked_paths.sort
      missing = tracked_paths - archive_paths
      extra = archive_paths - tracked_paths
      fail!("archive paths differ from tracked paths (missing: #{missing.inspect}; extra: #{extra.inspect})")
    end
  end

  def parse_tar_regular_paths(data)
    paths = []
    offset = 0
    long_name = nil
    pax_path = nil
    while offset + 512 <= data.bytesize
      header = data.byteslice(offset, 512)
      break if header == ("\0" * 512)

      name = header.byteslice(0, 100).delete("\0")
      prefix = header.byteslice(345, 155).delete("\0")
      name = "#{prefix}/#{name}" unless prefix.empty?
      size_text = header.byteslice(124, 12).delete("\0 ").strip
      size = size_text.empty? ? 0 : size_text.to_i(8)
      type = header.byteslice(156, 1)
      payload = data.byteslice(offset + 512, size)
      fail!("truncated tar archive") unless payload && payload.bytesize == size

      case type
      when "L"
        long_name = payload.delete("\0")
      when "x"
        pax_path = parse_pax_attributes(payload)["path"]
      when "g"
        parse_pax_attributes(payload)
      else
        paths << (pax_path || long_name || name) if type == "\0" || type == "0"
        pax_path = nil
        long_name = nil
      end
      offset += 512 + ((size + 511) / 512 * 512)
    end
    paths
  end

  def parse_pax_attributes(payload)
    attributes = {}
    offset = 0
    while offset < payload.bytesize
      space = payload.index(" ", offset)
      fail!("malformed PAX archive record") unless space
      length_text = payload.byteslice(offset, space - offset)
      fail!("malformed PAX archive record length") unless length_text.match?(/\A\d+\z/)
      length = length_text.to_i
      fail!("invalid PAX archive record length") if length <= 0 || offset + length > payload.bytesize
      record = payload.byteslice(space + 1, offset + length - space - 2)
      fail!("malformed PAX archive record terminator") unless payload.getbyte(offset + length - 1) == 10
      key, value = record.split("=", 2)
      fail!("malformed PAX archive attribute") unless key && value
      attributes[key] = value
      offset += length
    end
    attributes
  end
end

class GovernanceCheckpointValidator
  GIT_EXECUTABLE = GovernanceValidator::GIT_EXECUTABLE
  MAX_REVIEW_REPORT_BYTES = 131_072
  REVIEW_PATHS = {
    "review-requirements" => "docs/reviews/P00/review-requirements.md",
    "review-correctness" => "docs/reviews/P00/review-correctness.md",
    "review-tests" => "docs/reviews/P00/review-tests.md",
    "review-risk" => "docs/reviews/P00/review-risk.md",
    "review-reproducibility" => "docs/reviews/P00/review-reproducibility.md"
  }.freeze
  REQUIRED_CHANGED_PATHS = (
    REVIEW_PATHS.values + %w[
      docs/clean-room/DISTRIBUTION-LICENSES.yaml
      docs/evidence/P00-VALIDATION.md
      docs/evidence/REQUIREMENTS-MANIFEST.yaml
      docs/evidence/REQUIREMENTS-TRACEABILITY.md
      docs/phases/AUTONOMOUS-QUEUE.yaml
      docs/phases/P00-REPORT.md
      docs/phases/PROJECT-STATUS.md
    ]
  ).sort.freeze
  NEXT_ACTION = "run_P01_pre_phase_requirements_architecture_and_adversary_analysis"
  REPORT_HEADINGS = [
    "Scope",
    "Commands",
    "Positive Evidence",
    "Counterexample Attempts",
    "Findings"
  ].freeze
  CHECKPOINT_FILE_MODES = REQUIRED_CHANGED_PATHS.to_h do |path|
    [path, "100644"]
  end.freeze

  def initialize(
    root:,
    expected_commit:,
    expected_tree:,
    subject_commit:,
    subject_tree:,
    expected_normative_rows_sha256:,
    expected_review_file_sha256:,
    expected_review_report_sha256:,
    launcher_path:
  )
    @root = File.expand_path(root)
    @expected_commit = expected_commit
    @expected_tree = expected_tree
    @subject_commit = subject_commit
    @subject_tree = subject_tree
    @expected_normative_rows_sha256 = expected_normative_rows_sha256
    @expected_review_file_sha256 = expected_review_file_sha256
    @expected_review_report_sha256 = expected_review_report_sha256
    @launcher_path = File.expand_path(launcher_path)
  end

  def validate
    validate_arguments
    validate_checkpoint_identity
    validate_checkpoint_subject_phase
    validate_review_report_size_bounds
    validate_checkpoint_subject
    validate_review_file_bindings
    validate_subject_again
    validate_change_scope
    validate_reports
    validate_state_transition
    validate_requirement_transition
    validate_distribution_paths
    validate_evidence_file_deltas

    puts(
      "governance checkpoint validation passed " \
      "(checkpoint #{@expected_commit}, tree #{@expected_tree}, " \
      "subject #{@subject_commit}, subject tree #{@subject_tree})"
    )
  rescue GovernanceError
    raise
  rescue StandardError => error
    fail!("unexpected checkpoint error: #{error.class}")
  end

  private

  def fail!(message)
    raise GovernanceError, message
  end

  def validate_arguments
    fail!("repository root does not exist: #{@root}") unless Dir.exist?(@root)
    {
      "expected commit" => [@expected_commit, 40],
      "expected tree" => [@expected_tree, 40],
      "subject commit" => [@subject_commit, 40],
      "subject tree" => [@subject_tree, 40],
      "normative-row SHA-256" => [@expected_normative_rows_sha256, 64]
    }.each do |name, (value, length)|
      unless value.is_a?(String) &&
             value.match?(/\A[0-9a-f]{#{length}}\z/)
        fail!("#{name} has invalid format")
      end
    end
    unless @expected_review_file_sha256.is_a?(Hash) &&
           @expected_review_file_sha256.keys.sort ==
             GovernanceValidator::REVIEW_FILE_MODES.keys.sort
      fail!("checkpoint review-file SHA-256 tuple is incomplete")
    end
    unless @expected_review_report_sha256.is_a?(Hash) &&
           @expected_review_report_sha256.keys.sort == REVIEW_PATHS.keys.sort
      fail!("checkpoint review-report SHA-256 tuple is incomplete")
    end
    @expected_review_report_sha256.each do |role, digest|
      unless digest.is_a?(String) && digest.match?(/\A[0-9a-f]{64}\z/)
        fail!("checkpoint review-report SHA-256 is invalid for #{role}")
      end
    end
  end

  def command(*argv, allow_failure: false, binary: false, chdir: @root)
    stdout, stderr, status = Open3.capture3(
      {
        "HOME" => "/var/empty",
        "XDG_CONFIG_HOME" => "/var/empty",
        "LC_ALL" => "C",
        "LANG" => "C",
        "TZ" => "UTC",
        "RUBYOPT" => nil,
        "RUBYLIB" => nil,
        "GEM_HOME" => nil,
        "GEM_PATH" => nil,
        "BUNDLE_GEMFILE" => nil,
        "GIT_CONFIG_NOSYSTEM" => "1",
        "GIT_CONFIG_GLOBAL" => "/dev/null",
        "GIT_ATTR_NOSYSTEM" => "1",
        "GIT_OPTIONAL_LOCKS" => "0",
        "GIT_NO_REPLACE_OBJECTS" => "1",
        "GIT_DIR" => nil,
        "GIT_WORK_TREE" => nil,
        "GIT_INDEX_FILE" => nil,
        "GIT_OBJECT_DIRECTORY" => nil,
        "GIT_ALTERNATE_OBJECT_DIRECTORIES" => nil
      },
      *argv,
      chdir: chdir
    )
    stdout = stdout.b if binary
    return [stdout, stderr, status] if allow_failure

    unless status.success?
      detail = stderr.strip
      detail = stdout.strip if detail.empty?
      fail!("checkpoint command failed (#{argv.join(' ')}): #{detail}")
    end
    stdout
  end

  def git(*args, **options)
    command(
      GIT_EXECUTABLE,
      "-c", "core.fsmonitor=false",
      "-c", "core.untrackedCache=false",
      *args,
      **options
    )
  end

  def read(commit, path, binary: false)
    if REVIEW_PATHS.value?(path)
      size = git("cat-file", "-s", "#{commit}:#{path}").strip
      unless size.match?(/\A\d+\z/)
        fail!("checkpoint review report has an invalid blob size: #{path}")
      end
      if size.to_i > MAX_REVIEW_REPORT_BYTES
        fail!("checkpoint review report exceeds byte limit: #{path}")
      end
    end
    content = git("show", "#{commit}:#{path}", binary: true)
    return content if binary

    fail!("checkpoint file contains a NUL byte: #{path}") if content.include?("\0")
    content.force_encoding(Encoding::UTF_8)
    fail!("checkpoint file is not valid UTF-8: #{path}") unless content.valid_encoding?
    content
  end

  def yaml(commit, path)
    content = read(commit, path)
    stream = Psych.parse_stream(content, path)
    unless stream.children.length == 1
      fail!("checkpoint YAML must contain exactly one document: #{path}")
    end
    reject_unsafe_yaml(stream, path)
    value = Psych.safe_load(
      content,
      [],
      [],
      false,
      path,
      symbolize_names: false
    )
    reject_non_string_yaml_keys(value, path)
    value
  rescue Psych::Exception, SystemStackError => error
    fail!("invalid checkpoint YAML in #{path}: #{error.message}")
  end

  def reject_unsafe_yaml(node, path, depth = 0)
    if depth > GovernanceValidator::MAX_YAML_AST_DEPTH
      fail!("checkpoint YAML AST exceeds depth limit in #{path}")
    end
    fail!("checkpoint YAML aliases are prohibited in #{path}") if
      node.is_a?(Psych::Nodes::Alias)
    if node.respond_to?(:anchor) && node.anchor
      fail!("checkpoint YAML anchors are prohibited in #{path}")
    end

    if node.is_a?(Psych::Nodes::Mapping)
      keys = Set.new
      node.children.each_slice(2) do |key, value|
        unless key.is_a?(Psych::Nodes::Scalar)
          fail!("checkpoint YAML has a non-scalar key in #{path}")
        end
        if key.anchor || (key.tag && key.tag != "tag:yaml.org,2002:str")
          fail!("checkpoint YAML has an unsafe mapping key in #{path}")
        end
        fail!("checkpoint YAML merge keys are prohibited in #{path}") if key.value == "<<"
        unless key.value.match?(/\A[A-Za-z_][A-Za-z0-9_.-]*\z/)
          fail!("checkpoint YAML has a non-string-safe key in #{path}")
        end
        unless keys.add?(key.value)
          fail!("duplicate checkpoint YAML key #{key.value.inspect} in #{path}")
        end
        reject_unsafe_yaml(value, path, depth + 1)
      end
    elsif node.respond_to?(:children)
      Array(node.children).each do |child|
        reject_unsafe_yaml(child, path, depth + 1)
      end
    end
  end

  def reject_non_string_yaml_keys(value, path, context = "$", depth = 0)
    if depth > GovernanceValidator::MAX_YAML_AST_DEPTH
      fail!("checkpoint YAML value exceeds depth limit in #{path}")
    end
    case value
    when Hash
      value.each do |key, nested|
        unless key.is_a?(String)
          fail!("checkpoint YAML has a non-string key at #{context} in #{path}")
        end
        reject_non_string_yaml_keys(nested, path, "#{context}.#{key}", depth + 1)
      end
    when Array
      value.each_with_index do |nested, index|
        reject_non_string_yaml_keys(
          nested,
          path,
          "#{context}[#{index}]",
          depth + 1
        )
      end
    end
  end

  def validate_checkpoint_subject
    fail!("checkpoint worktree is not clean") unless
      git("status", "--porcelain=v1", "--untracked-files=all").empty?
    index_entries = git("ls-files", "-v", "-z", binary: true)
      .split("\0")
      .reject(&:empty?)
    concealed = index_entries.reject { |entry| entry.start_with?("H ") }
    unless concealed.empty?
      fail!("checkpoint has concealed or unsupported index flags")
    end
    validate_checkpoint_worktree_bytes
    parents = git("show", "-s", "--format=%P", @expected_commit).split
    unless parents == [@subject_commit]
      fail!("checkpoint must have the reviewed subject as its sole parent")
    end
    actual_subject_tree = git("rev-parse", "#{@subject_commit}^{tree}").strip
    fail!("checkpoint subject tree differs") unless actual_subject_tree == @subject_tree
    git("show", "--check", "--format=", "--no-renames", @expected_commit)
  end

  def validate_checkpoint_identity
    head = git("rev-parse", "HEAD").strip
    tree = git("rev-parse", "HEAD^{tree}").strip
    fail!("checkpoint HEAD differs from expected commit") unless
      head == @expected_commit
    fail!("checkpoint tree differs from expected tree") unless
      tree == @expected_tree
  end

  def validate_checkpoint_subject_phase
    status = yaml(@subject_commit, "docs/phases/PROJECT-STATUS.md")
    unless status.is_a?(Hash) &&
           status.fetch("current_phase", nil) == "P00"
      fail!("checkpoint subject phase must be P00")
    end
  end

  def validate_review_report_size_bounds
    REVIEW_PATHS.each_value do |path|
      entry = git("ls-tree", @expected_commit, "--", path).strip
      match = entry.match(/\A\d{6} blob ([0-9a-f]{40})\t(.+)\z/)
      unless match && match[2] == path
        fail!("checkpoint evidence file mode differs: #{path}")
      end
      size = git("cat-file", "-s", match[1]).strip
      unless size.match?(/\A\d+\z/)
        fail!("checkpoint review report has an invalid blob size: #{path}")
      end
      if size.to_i > MAX_REVIEW_REPORT_BYTES
        fail!("checkpoint review report exceeds byte limit: #{path}")
      end

      stat = File.lstat(File.join(@root, path))
      if stat.size > MAX_REVIEW_REPORT_BYTES
        fail!("checkpoint review report exceeds byte limit: #{path}")
      end
    end
  rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
    fail!("checkpoint review report cannot be sized safely")
  end

  def validate_checkpoint_worktree_bytes
    canonical_root = File.realpath(@root)
    entries = git(
      "ls-tree",
      "-r",
      "-z",
      "--full-tree",
      @expected_commit,
      binary: true
    ).split("\0").reject(&:empty?)
    entries.each do |raw_entry|
      metadata, path = raw_entry.split("\t", 2)
      mode, type, _object = metadata.to_s.split(" ", 3)
      next unless path && type == "blob" && %w[100644 100755].include?(mode)

      worktree_path = File.join(@root, path)
      stat = File.lstat(worktree_path)
      expected_executable = mode == "100755"
      actual_executable = (stat.mode & 0o111).positive?
      unless stat.file? && !stat.symlink? &&
             File.realpath(worktree_path) == File.join(canonical_root, path) &&
             actual_executable == expected_executable &&
             File.binread(worktree_path) ==
               read(@expected_commit, path, binary: true)
        fail!("checkpoint worktree file differs from committed bytes or mode: #{path}")
      end
    end
  rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
    fail!("checkpoint worktree file cannot be read safely")
  end

  def validate_review_file_bindings
    GovernanceValidator::REVIEW_FILE_MODES.each do |path, expected_mode|
      subject_entry = git("ls-tree", @subject_commit, "--", path).strip
      checkpoint_entry = git("ls-tree", @expected_commit, "--", path).strip
      unless subject_entry == checkpoint_entry &&
             subject_entry.start_with?("#{expected_mode} blob ")
        fail!("checkpoint changed a pinned review tool: #{path}")
      end
      expected_hash = @expected_review_file_sha256.fetch(path)
      committed = read(@expected_commit, path, binary: true)
      unless Digest::SHA256.hexdigest(committed) == expected_hash
        fail!("checkpoint review tool differs from tuple: #{path}")
      end
      worktree_path = File.join(@root, path)
      stat = File.lstat(worktree_path)
      unless stat.file? && !stat.symlink? &&
             File.binread(worktree_path) == committed
        fail!("checkpoint worktree review tool differs: #{path}")
      end
    end
    unless File.realpath(@launcher_path) ==
           File.realpath(File.join(@root, "tools/validate-governance"))
      fail!("checkpoint launcher path is not canonical")
    end
  end

  def subject_validation_arguments(root)
    [
      File.join(root, "tools/validate-governance"),
      "--root", root,
      "--expected-commit", @subject_commit,
      "--expected-tree", @subject_tree,
      "--expected-normative-rows-sha256", @expected_normative_rows_sha256,
      "--expected-validate-launcher-sha256",
      @expected_review_file_sha256.fetch("tools/validate-governance"),
      "--expected-validator-source-sha256",
      @expected_review_file_sha256.fetch("tools/validate-governance.rb"),
      "--expected-test-launcher-sha256",
      @expected_review_file_sha256.fetch("tools/test-validate-governance"),
      "--expected-test-source-sha256",
      @expected_review_file_sha256.fetch("tools/test-validate-governance.rb")
    ]
  end

  def checkpoint_ref_map(root, prefix = nil)
    arguments = [
      GIT_EXECUTABLE,
      "-C", root,
      "for-each-ref",
      "--format=%(objectname) %(refname)"
    ]
    arguments << prefix if prefix
    output = command(*arguments, binary: true)
    output.each_line.with_object({}) do |line, refs|
      match = line.match(/\A([0-9a-f]{40}) (refs\/[^\n]+)\n\z/)
      fail!("checkpoint source contains a malformed Git ref") unless match
      fail!("checkpoint source contains duplicate Git refs") if refs.key?(match[2])
      refs[match[2]] = match[1]
    end
  end

  def validate_subject_again
    Dir.mktmpdir("nlu-governance-checkpoint.") do |temporary|
      clone = File.join(temporary, "subject")
      source_refs = checkpoint_ref_map(@root)
      command(
        GIT_EXECUTABLE,
        "clone",
        "--quiet",
        "--local",
        "--no-hardlinks",
        "--no-tags",
        @root,
        clone,
        chdir: temporary
      )
      unless source_refs.empty?
        command(
          GIT_EXECUTABLE,
          "-C", clone,
          "fetch",
          "--quiet",
          "--no-tags",
          @root,
          "+refs/*:refs/p00-source/*"
        )
      end
      expected_refs = source_refs.to_h do |ref, object|
        ["refs/p00-source/#{ref.delete_prefix('refs/')}", object]
      end
      copied_refs = checkpoint_ref_map(clone, "refs/p00-source")
      unless copied_refs == expected_refs
        fail!("checkpoint private clone did not preserve every project ref")
      end
      command(GIT_EXECUTABLE, "-C", clone, "checkout", "--quiet", "--detach", @subject_commit)
      output = command(*subject_validation_arguments(clone), chdir: clone)
      unless output.start_with?("governance validation passed ")
        fail!("review subject did not reproduce its governance PASS")
      end
    end
  end

  def validate_change_scope
    changed = git(
      "diff",
      "--name-only",
      "--no-renames",
      @subject_commit,
      @expected_commit
    ).lines.map(&:strip).reject(&:empty?).sort
    unless changed == REQUIRED_CHANGED_PATHS
      fail!("checkpoint changed paths differ from the evidence-only set")
    end
    CHECKPOINT_FILE_MODES.each do |path, expected_mode|
      entry = git("ls-tree", @expected_commit, "--", path).strip
      match = entry.match(/\A(\d{6}) blob [0-9a-f]{40}\t(.+)\z/)
      unless match && match[1] == expected_mode && match[2] == path
        fail!("checkpoint evidence file mode differs: #{path}")
      end

      worktree_path = File.join(@root, path)
      stat = File.lstat(worktree_path)
      canonical = File.join(File.realpath(@root), path)
      if REVIEW_PATHS.value?(path) &&
         stat.size > MAX_REVIEW_REPORT_BYTES
        fail!("checkpoint review report exceeds byte limit: #{path}")
      end
      unless stat.file? && !stat.symlink? &&
             File.realpath(worktree_path) == canonical &&
             File.binread(worktree_path) == read(@expected_commit, path, binary: true)
        fail!("checkpoint evidence worktree file differs: #{path}")
      end
    rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
      fail!("checkpoint evidence worktree file cannot be read safely: #{path}")
    end
  end

  def validate_reports
    reviewer_instances = Set.new
    REVIEW_PATHS.each do |role, path|
      content = read(@expected_commit, path)
      expected_hash = @expected_review_report_sha256.fetch(role)
      unless Digest::SHA256.hexdigest(content.b) == expected_hash
        fail!("checkpoint review report differs from the external tuple: #{role}")
      end
      required_lines = [
        "Role: `#{role}`",
        "Independent context: `true`",
        "Report conclusion ignored: `true`",
        "Primary evidence inspected: `true`",
        "Read-only review: `true`",
        "Subject commit: `#{@subject_commit}`",
        "Subject tree: `#{@subject_tree}`",
        "Verdict: `PASS`"
      ]
      required_lines.each do |line|
        fail!("checkpoint report #{path} lacks #{line}") unless content.lines.map(&:chomp).count(line) == 1
      end
      expected_title = "# P00 #{role} review"
      unless content.lines.first&.chomp == expected_title
        fail!("checkpoint report #{path} has a noncanonical title")
      end

      instance_lines = content.lines.map(&:chomp).grep(/\AReviewer instance: /)
      unless instance_lines.length == 1
        fail!("checkpoint report #{path} lacks one reviewer instance")
      end
      instance = instance_lines.first[
        /\AReviewer instance: `([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})`\z/,
        1
      ]
      fail!("checkpoint report #{path} has an invalid reviewer instance") unless instance
      unless reviewer_instances.add?(instance)
        fail!("checkpoint reports reuse reviewer instance #{instance}")
      end
      canonical_header = [
        expected_title,
        "",
        "Role: `#{role}`",
        instance_lines.first,
        "Independent context: `true`",
        "Report conclusion ignored: `true`",
        "Primary evidence inspected: `true`",
        "Read-only review: `true`",
        "Subject commit: `#{@subject_commit}`",
        "Subject tree: `#{@subject_tree}`",
        "",
        "## Scope",
        ""
      ].join("\n")
      unless content.start_with?(canonical_header)
        fail!("checkpoint report #{path} has a noncanonical prefix")
      end
      unless content.end_with?("\nVerdict: `PASS`\n")
        fail!("checkpoint report #{path} has a noncanonical suffix")
      end
      scan_checkpoint_report(path, content)

      verdicts = content.lines.map(&:chomp).grep(/\AVerdict:/)
      content_without_final_verdict =
        content.sub(/\nVerdict: `PASS`\n\z/, "\n")
      normalized_without_final_verdict =
        normalized_report_control_text(content_without_final_verdict)
      if normalized_without_final_verdict.match?(
        /(?<![A-Za-z0-9])Verdict(?![A-Za-z0-9])/i
      )
        fail!("checkpoint report #{path} has a contradictory verdict")
      end
      unless verdicts == ["Verdict: `PASS`"]
        fail!("checkpoint report #{path} has a contradictory verdict")
      end
      sections = content.scan(
        /^## ([^\n]+)\n\n(.*?)(?=^## |^Verdict: |\z)/m
      )
      unless sections.map(&:first) == REPORT_HEADINGS
        fail!("checkpoint report #{path} sections differ")
      end
      section_bodies = sections.to_h do |heading, body|
        [heading, body.strip]
      end
      REPORT_HEADINGS.each do |heading|
        if section_bodies.fetch(heading).empty?
          fail!("checkpoint report #{path} has an empty #{heading} section")
        end
      end
      unless section_bodies.fetch("Commands").match?(/`[^`\n]+`/)
        fail!("checkpoint report #{path} lacks an executed command")
      end
      scope_lines = section_bodies.fetch("Scope").lines.map(&:chomp)
      decoded_scope_line = checkpoint_scanner.send(
        :repeatedly_decode_text,
        scope_lines.first.to_s
      )
      unless decoded_scope_line.match?(/\APaths: `[^`\r\n]+`\z/)
        fail!("checkpoint report #{path} lacks an inspected path")
      end
      unless section_bodies.fetch("Positive Evidence").match?(/^Inputs: \S.+$/)
        fail!("checkpoint report #{path} lacks cited inputs")
      end
      unless section_bodies.fetch("Positive Evidence").match?(/^Results: \S.+$/)
        fail!("checkpoint report #{path} lacks reproducible results")
      end
      evidence_lines = section_bodies.fetch("Positive Evidence")
        .lines.map(&:chomp).reject(&:empty?)
      unless evidence_lines[0]&.start_with?("Inputs: ") &&
             evidence_lines[1]&.start_with?("Results: ")
        fail!("checkpoint report #{path} has out-of-order evidence fields")
      end
      normalized_content = normalized_report_control_text(content)
      if normalized_content.match?(
        /(?<![A-Za-z0-9])P[0-3](?![A-Za-z0-9])/i
      )
        fail!("checkpoint report #{path} contains unresolved findings")
      end
      unless section_bodies.fetch("Findings") == "None."
        fail!("checkpoint report #{path} contains unresolved findings")
      end
    end
  end

  def normalized_report_control_text(content)
    decoded = checkpoint_scanner.send(:repeatedly_decode_text, content)
    visible = checkpoint_scanner.send(:markdown_visible_text, decoded)
    decoded == visible ? decoded : "#{decoded}\n#{visible}"
  end

  def checkpoint_scanner
    @checkpoint_scanner ||= GovernanceValidator.new(
      root: @root,
      expected_commit: @subject_commit,
      expected_tree: @subject_tree,
      expected_normative_rows_sha256: @expected_normative_rows_sha256,
      expected_review_file_sha256: @expected_review_file_sha256,
      launcher_path: @launcher_path
    )
  end

  def scan_checkpoint_report(path, content)
    scanner = checkpoint_scanner
    scanner.send(:scan_sensitive_content, path, content)
    scanner.send(:scan_amazon_content, path, content)
  end

  def substitute_once(content, before, after, path)
    unless content.scan(Regexp.new(Regexp.escape(before))).length == 1
      fail!("checkpoint subject has a noncanonical transform anchor in #{path}")
    end
    content.sub(before, after)
  end

  def expected_status_content
    path = "docs/phases/PROJECT-STATUS.md"
    content = read(@subject_commit, path)
    {
      "current_phase: P00" => "current_phase: P01",
      "state: REVIEWING" => "state: IMPLEMENTING",
      "subject_baseline: SELF_AT_CANDIDATE_COMMIT" => "subject_baseline: null",
      "evidence_checkpoint: null" => "evidence_checkpoint: SELF_AT_CHECKPOINT_COMMIT",
      "completed_phases: []" => "completed_phases:\n  - P00"
    }.each do |before, after|
      content = substitute_once(content, before, after, path)
    end
    content
  end

  def expected_queue_content
    path = "docs/phases/AUTONOMOUS-QUEUE.yaml"
    content = read(@subject_commit, path)
    content = substitute_once(content, "active_item: P00", "active_item: P01", path)
    content = substitute_once(
      content,
      "next_action: #{GovernanceValidator::P00_NEXT_ACTION}",
      "next_action: #{NEXT_ACTION}",
      path
    )
    content = substitute_once(content, "  - P01\n", "", path)
    content.sub!(
      /^last_checkpoint: .+$/,
      "last_checkpoint: P00_EVIDENCE_SELF_AT_CHECKPOINT_COMMIT"
    )
    content
  end

  def expected_traceability_content
    read(@subject_commit, "docs/evidence/REQUIREMENTS-TRACEABILITY.md")
      .lines
      .map do |line|
        columns = line.chomp.split("|", -1)[1..7]&.map(&:strip)
        p00_review_pending = columns&.fetch(3, nil) == "P00" &&
          columns&.fetch(6, nil) == "REVIEW_PENDING"
        if p00_review_pending ||
           (line.start_with?("| `P00-REV-") && line.end_with?("| PENDING |\n"))
          line.sub(/\| (?:REVIEW_PENDING|PENDING) \|\n\z/, "| SATISFIED |\n")
        else
          line
        end
      end
      .join
  end

  def status_digest(content)
    rows = content.each_line.each_with_object([]) do |line, result|
      next unless line.start_with?("| `")

      columns = line.chomp.split("|", -1)[1..7].map(&:strip)
      id = columns.fetch(0).match(/\A`(.+)`\z/)&.captures&.first
      fail!("checkpoint traceability contains a malformed row") unless id
      result << "#{id}\t#{columns.fetch(6)}"
    end
    payload = rows.join("\n") + "\n"
    Digest::SHA256.hexdigest(payload)
  end

  def expected_manifest_content(traceability)
    path = "docs/evidence/REQUIREMENTS-MANIFEST.yaml"
    content = read(@subject_commit, path)
    replacement = "p00_statuses_sha256: #{status_digest(traceability)}"
    unless content.scan(/^p00_statuses_sha256: [0-9a-f]{64}$/).length == 1
      fail!("checkpoint subject has a noncanonical status digest")
    end
    content.sub(/^p00_statuses_sha256: [0-9a-f]{64}$/, replacement)
  end

  def expected_distribution_content
    path = "docs/clean-room/DISTRIBUTION-LICENSES.yaml"
    content = read(@subject_commit, path)
    review_paths = REVIEW_PATHS.values.map { |review_path| "      - #{review_path}\n" }.join
    anchor = "      - docs/reviews/P00/pre-phase-requirements.md\n"
    substitute_once(content, anchor, "#{anchor}#{review_paths}", path)
  end

  def expected_report_content
    path = "docs/phases/P00-REPORT.md"
    content = read(@subject_commit, path)
    content = substitute_once(
      content,
      "Status: `REVIEWING`",
      "Status: `PHASE_PASSED`",
      path
    )
    content +
      "\nReviewed subject commit: `#{@subject_commit}`\n" \
      "Reviewed subject tree: `#{@subject_tree}`\n"
  end

  def checkpoint_validation_append
    hashes = REVIEW_PATHS.keys.map do |role|
      "- `#{role}`: `#{@expected_review_report_sha256.fetch(role)}`"
    end.join("\n")
    "\n## P00 Evidence Checkpoint\n\n" \
      "Reviewed subject commit: `#{@subject_commit}`\n" \
      "Reviewed subject tree: `#{@subject_tree}`\n\n" \
      "Reviewer-owned report SHA-256 values:\n\n#{hashes}\n"
  end

  def validate_evidence_file_deltas
    traceability = expected_traceability_content
    expected = {
      "docs/phases/PROJECT-STATUS.md" => expected_status_content,
      "docs/phases/AUTONOMOUS-QUEUE.yaml" => expected_queue_content,
      "docs/evidence/REQUIREMENTS-TRACEABILITY.md" => traceability,
      "docs/evidence/REQUIREMENTS-MANIFEST.yaml" =>
        expected_manifest_content(traceability),
      "docs/clean-room/DISTRIBUTION-LICENSES.yaml" =>
        expected_distribution_content,
      "docs/phases/P00-REPORT.md" => expected_report_content,
      "docs/evidence/P00-VALIDATION.md" =>
        read(@subject_commit, "docs/evidence/P00-VALIDATION.md") +
        checkpoint_validation_append
    }
    expected.each do |path, bytes|
      unless read(@expected_commit, path, binary: true) == bytes.b
        fail!("checkpoint changed #{path} beyond the canonical evidence delta")
      end
    end
  end

  def validate_state_transition
    subject_status = yaml(@subject_commit, "docs/phases/PROJECT-STATUS.md")
    subject_queue = yaml(@subject_commit, "docs/phases/AUTONOMOUS-QUEUE.yaml")
    status = yaml(@expected_commit, "docs/phases/PROJECT-STATUS.md")
    queue = yaml(@expected_commit, "docs/phases/AUTONOMOUS-QUEUE.yaml")
    expected_status = subject_status.merge(
      "current_phase" => "P01",
      "state" => "IMPLEMENTING",
      "subject_baseline" => nil,
      "evidence_checkpoint" => "SELF_AT_CHECKPOINT_COMMIT",
      "completed_phases" => ["P00"]
    )
    expected_queue = subject_queue.merge(
      "active_item" => "P01",
      "next_action" => NEXT_ACTION,
      "queued_items" =>
        GovernanceValidator::PHASES.drop(2) +
        [GovernanceValidator::TERMINAL_PHASE],
      "last_checkpoint" => "P00_EVIDENCE_SELF_AT_CHECKPOINT_COMMIT"
    )
    fail!("checkpoint project status differs from the exact transition") unless
      status == expected_status
    fail!("checkpoint queue differs from the exact transition") unless
      queue == expected_queue
    report = read(@expected_commit, "docs/phases/P00-REPORT.md")
    fail!("checkpoint P00 report is not phase-passed") unless report.scan(/^Status: `PHASE_PASSED`$/).length == 1
    fail!("checkpoint P00 report lacks subject commit") unless report.include?(@subject_commit)
    fail!("checkpoint P00 report lacks subject tree") unless report.include?(@subject_tree)
  end

  def requirement_rows(commit)
    rows = {}
    read(commit, "docs/evidence/REQUIREMENTS-TRACEABILITY.md")
      .each_line.with_index(1) do |line, number|
      next unless line.start_with?("| `")

      columns = line.chomp.split("|", -1)
      unless columns.length == 9
        fail!("malformed checkpoint requirement row at line #{number}")
      end
      values = columns[1..7].map(&:strip)
      match = values.fetch(0).match(/\A`([A-Z][A-Z0-9-]*-\d{3})`\z/)
      unless match
        fail!("malformed checkpoint requirement ID at line #{number}")
      end
      id = match[1]
      fail!("duplicate checkpoint requirement ID #{id}") if rows.key?(id)
      rows[id] = values[1..6]
    end
    rows
  end

  def validate_requirement_transition
    subject = requirement_rows(@subject_commit)
    checkpoint = requirement_rows(@expected_commit)
    fail!("checkpoint requirement identities differ") unless subject.keys == checkpoint.keys
    checkpoint.each do |id, columns|
      subject_columns = subject.fetch(id)
      unless columns[0, 5] == subject_columns[0, 5]
        fail!("checkpoint changed normative requirement columns for #{id}")
      end
      expected_status = if (subject_columns[5] == "REVIEW_PENDING" &&
                            subject_columns[2] == "P00") ||
                           id.start_with?("P00-REV-")
                          "SATISFIED"
                        else
                          subject_columns[5]
                        end
      fail!("checkpoint requirement status differs for #{id}") unless columns[5] == expected_status
    end

    manifest = yaml(@expected_commit, "docs/evidence/REQUIREMENTS-MANIFEST.yaml")
    fail!("checkpoint manifest IDs differ") unless manifest["required_ids"] == checkpoint.keys
    unless manifest["normative_rows_sha256"] == @expected_normative_rows_sha256
      fail!("checkpoint normative-row digest differs")
    end
    status_payload = checkpoint.map do |id, columns|
      "#{id}\t#{columns.fetch(5)}"
    end.join("\n") + "\n"
    unless manifest["p00_statuses_sha256"] == Digest::SHA256.hexdigest(status_payload)
      fail!("checkpoint status digest differs")
    end
  end

  def validate_distribution_paths
    licenses = yaml(@expected_commit, "docs/clean-room/DISTRIBUTION-LICENSES.yaml")
    covered = licenses.fetch("path_rules").flat_map do |rule|
      fail!("checkpoint distributed path is not Apache-2.0") unless
        rule["license"] == "Apache-2.0"
      rule.fetch("paths")
    end
    tracked = git("ls-tree", "-r", "--name-only", @expected_commit).lines.map(&:strip)
    fail!("checkpoint distribution paths contain duplicates") unless covered.uniq.length == covered.length
    fail!("checkpoint distribution paths differ from tree") unless covered.sort == tracked.sort
    REVIEW_PATHS.each_value do |path|
      fail!("checkpoint report lacks distribution license: #{path}") unless covered.include?(path)
    end
  end
end

module GovernanceCLI
  REQUIRED_ENVIRONMENT = {
    "HOME" => "/var/empty",
    "PATH" => "/usr/bin:/bin",
    "LC_ALL" => "C",
    "LANG" => "C",
    "TZ" => "UTC"
  }.freeze
  FORBIDDEN_ENVIRONMENT_KEYS = %w[
    BUNDLE_GEMFILE
    GEM_HOME
    GEM_PATH
    RUBYLIB
    RUBYOPT
  ].freeze
  DOCUMENTED_RUNTIME_ENVIRONMENT_KEYS = %w[
    __CF_USER_TEXT_ENCODING
  ].freeze

  REVIEW_HASH_OPTIONS = {
    expected_validate_launcher_sha256: "tools/validate-governance",
    expected_validator_source_sha256: "tools/validate-governance.rb",
    expected_test_launcher_sha256: "tools/test-validate-governance",
    expected_test_source_sha256: "tools/test-validate-governance.rb"
  }.freeze
  CHECKPOINT_REPORT_HASH_OPTIONS = {
    expected_review_requirements_sha256: "review-requirements",
    expected_review_correctness_sha256: "review-correctness",
    expected_review_tests_sha256: "review-tests",
    expected_review_risk_sha256: "review-risk",
    expected_review_reproducibility_sha256: "review-reproducibility"
  }.freeze

  def self.run(arguments, launcher_path:)
    unless REQUIRED_ENVIRONMENT.all? { |key, value| ENV[key] == value } &&
           FORBIDDEN_ENVIRONMENT_KEYS.none? { |key| ENV.key?(key) }
      raise GovernanceError, "required sanitized launcher environment is absent"
    end
    unexpected_environment = ENV.keys - REQUIRED_ENVIRONMENT.keys -
      DOCUMENTED_RUNTIME_ENVIRONMENT_KEYS
    unless unexpected_environment.empty?
      raise GovernanceError,
            "unexpected launcher environment keys: #{unexpected_environment.sort.join(', ')}"
    end
    DOCUMENTED_RUNTIME_ENVIRONMENT_KEYS.each { |key| ENV.delete(key) }

    options = { root: Dir.pwd }
    seen_options = Set.new
    assign_option = lambda do |key, value, option|
      unless seen_options.add?(key)
        raise GovernanceError, "--#{option} specified more than once"
      end
      options[key] = value
    end
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: tools/validate-governance --expected-commit SHA --expected-tree SHA --expected-normative-rows-sha256 SHA --expected-validate-launcher-sha256 SHA --expected-validator-source-sha256 SHA --expected-test-launcher-sha256 SHA --expected-test-source-sha256 SHA [--root PATH]"
      opts.on("--root PATH", "Repository root") do |value|
        assign_option.call(:root, value, "root")
      end
      opts.on("--expected-commit SHA", "Exact subject commit") do |value|
        assign_option.call(:expected_commit, value, "expected-commit")
      end
      opts.on("--expected-tree SHA", "Exact subject tree") do |value|
        assign_option.call(:expected_tree, value, "expected-tree")
      end
      opts.on("--expected-normative-rows-sha256 SHA", "Frozen normative rows") do |value|
        assign_option.call(
          :expected_normative_rows_sha256,
          value,
          "expected-normative-rows-sha256"
        )
      end
      opts.on("--expected-validate-launcher-sha256 SHA", "Frozen validation launcher") do |value|
        assign_option.call(
          :expected_validate_launcher_sha256,
          value,
          "expected-validate-launcher-sha256"
        )
      end
      opts.on("--expected-validator-source-sha256 SHA", "Frozen validator source") do |value|
        assign_option.call(
          :expected_validator_source_sha256,
          value,
          "expected-validator-source-sha256"
        )
      end
      opts.on("--expected-test-launcher-sha256 SHA", "Frozen test launcher") do |value|
        assign_option.call(
          :expected_test_launcher_sha256,
          value,
          "expected-test-launcher-sha256"
        )
      end
      opts.on("--expected-test-source-sha256 SHA", "Frozen test source") do |value|
        assign_option.call(
          :expected_test_source_sha256,
          value,
          "expected-test-source-sha256"
        )
      end
      opts.on("--checkpoint-subject-commit SHA", "Reviewed subject for an evidence checkpoint") do |value|
        assign_option.call(
          :checkpoint_subject_commit,
          value,
          "checkpoint-subject-commit"
        )
      end
      opts.on("--checkpoint-subject-tree SHA", "Reviewed subject tree for an evidence checkpoint") do |value|
        assign_option.call(
          :checkpoint_subject_tree,
          value,
          "checkpoint-subject-tree"
        )
      end
      CHECKPOINT_REPORT_HASH_OPTIONS.each_key do |key|
        option = key.to_s.tr("_", "-")
        opts.on("--#{option} SHA", "Reviewer-owned checkpoint report hash") do |value|
          assign_option.call(key, value, option)
        end
      end
    end

    parser.parse!(arguments)
    raise GovernanceError, "unexpected positional arguments" unless arguments.empty?
    raise GovernanceError, "--expected-commit is required" unless options[:expected_commit]
    raise GovernanceError, "--expected-tree is required" unless options[:expected_tree]
    raise GovernanceError, "--expected-normative-rows-sha256 is required" unless options[:expected_normative_rows_sha256]
    REVIEW_HASH_OPTIONS.each_key do |key|
      option = key.to_s.tr("_", "-")
      raise GovernanceError, "--#{option} is required" unless options[key]
    end
    checkpoint_values = [
      options[:checkpoint_subject_commit],
      options[:checkpoint_subject_tree]
    ]
    if checkpoint_values.compact.length == 1
      raise GovernanceError,
            "--checkpoint-subject-commit and --checkpoint-subject-tree must be used together"
    end
    report_hash_values = CHECKPOINT_REPORT_HASH_OPTIONS.keys.map { |key| options[key] }
    if options[:checkpoint_subject_commit]
      CHECKPOINT_REPORT_HASH_OPTIONS.each_key do |key|
        option = key.to_s.tr("_", "-")
        raise GovernanceError, "--#{option} is required for checkpoint validation" unless
          options[key]
      end
    elsif report_hash_values.compact.any?
      raise GovernanceError,
            "checkpoint report hashes require checkpoint subject arguments"
    end
    common = {
      root: options[:root],
      expected_commit: options[:expected_commit],
      expected_tree: options[:expected_tree],
      expected_normative_rows_sha256: options[:expected_normative_rows_sha256],
      expected_review_file_sha256: REVIEW_HASH_OPTIONS.to_h do |key, path|
        [path, options.fetch(key)]
      end,
      launcher_path: launcher_path
    }
    if options[:checkpoint_subject_commit]
      GovernanceCheckpointValidator.new(
        **common,
        subject_commit: options[:checkpoint_subject_commit],
        subject_tree: options[:checkpoint_subject_tree],
        expected_review_report_sha256:
          CHECKPOINT_REPORT_HASH_OPTIONS.to_h do |key, role|
            [role, options.fetch(key)]
          end
      ).validate
    else
      GovernanceValidator.new(**common).validate
    end
  rescue GovernanceError, OptionParser::ParseError => error
    warn("governance validation failed: #{error.message}")
    exit(1)
  end
end

if __FILE__ == $PROGRAM_NAME
  warn("governance validation failed: invoke tools/validate-governance")
  exit(1)
end
