# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "psych"
require "set"
require "stringio"
require "thread"
require "tmpdir"
require "zlib"
require_relative "p13-rustc-driver"
require_relative "p13-source-fetch"

module P13NoiseEvidence
  class Failure < StandardError; end
  class DuplicateKey < StandardError; end

  class DuplicateRejectingHash < Hash
    def []=(key, value)
      raise DuplicateKey, key if key?(key)

      super
    end
  end

  ROOT = File.expand_path("..", __dir__)
  EVIDENCE = "docs/evidence/P13-NOISE-SOURCES.yaml"
  MATERIALS = "docs/clean-room/MATERIALS.yaml"
  DISTRIBUTION = "docs/clean-room/DISTRIBUTION-LICENSES.yaml"
  USER_DECISIONS = "docs/clean-room/USER-DECISIONS.md"
  REQUIREMENTS_TRACEABILITY =
    "docs/evidence/REQUIREMENTS-TRACEABILITY.md"
  REQUIREMENTS_MANIFEST = "docs/evidence/REQUIREMENTS-MANIFEST.yaml"
  TOOLCHAIN_PROVENANCE = "docs/evidence/TOOLCHAIN-PROVENANCE.yaml"
  PROBE_ROOT = "tools/p13-noise-probe"
  PROJECT_POLY1305_SOURCE =
    "tools/p13-noise-probe/projected/poly1305-soft.rs"
  POLY1305_ARCHIVE_LICENSE_LINE = "license = \"Apache-2.0 OR MIT\"\n"
  POLY1305_PROJECTED_LICENSE_BLOCK = <<~NOTICE.freeze
    license = "Apache-2.0"
    # NLU P13 modification notice: this projected Cargo.toml was changed to elect
    # Apache-2.0 after src/backend/soft.rs was replaced by project-authored source.
  NOTICE
  GENERIC_ARRAY_NOTICE_PATH = "LICENSE-RUST-MIT"
  TYPENUM_NOTICE_PATH = "LICENSE-RUST-NUM-MIT"
  ORIGIN_STATEMENT_MAX_LINES = 16
  RUST_ARCHIVE_LISTING_MAX_BYTES = 8 * 1024 * 1024
  GIT_ENVIRONMENT = {
    "GIT_NO_LAZY_FETCH" => "1",
    "GIT_TERMINAL_PROMPT" => "0"
  }.freeze

  EVIDENCE_SEMANTIC_SHA256 =
    "0c870bc3c9175cc810bdeaade88d49521fd7fd4c892c1ac2ea72aed581906e5f"
  MATERIAL_RECORD_SEMANTIC_SHA256 = {
    "noise-protocol-revision-34-p13-transport" =>
      "f699966981cbb5339b50783785b14726ed8b4439b0d4c923cbbbb4569ec66c5d",
    "snow-0.10.0-p13-transport-closure" =>
      "f0fa84ca99928c32245dc0c58d3d0e782e95c6b74458552b58c77a7ec338949d",
    "cacophony-vector-p13-snow-projection-removal" =>
      "38ac5951e5321958b1ad53d7bf0b452ef207c37b70fe1bd4004e9cd659a17ddb",
    "project-poly1305-soft-p13" =>
      "e6ff8f33fff40d321cdd22bb7e14ccdd6b0b08486c9258df04273ef5863d41f7",
    "rust-num-pow-origin-p13" =>
      "f786df136411052bcff58aab110310fe2c0537be41a99a524e48cf55e203a592",
    "rust-pr49000-array-origin-p13" =>
      "3c653d498dcda9af0ea17e42985b78ca34e49cb70cc85e839042b37076990083",
    "pulldown-redwood-relicense-origin-p13" =>
      "bdaafacdfdd2b6a0af472800ba1c072155c978d230e11bd9e00fa606a19ba149",
    "tracing-hyperium-origin-p13" =>
      "dc5cdb43f6330a34b521643d30b14030d15c15ec77d265eca4758794820d83aa",
    "rustc-1.98.0-source-p13" =>
      "45fd5d9beed7a1699c85df6e9cf01798e3c895e0e0d61f1ca6b4a78ac42f0a92",
    "spdx-license-list-xml-p13" =>
      "b52097148eb552ac38f04b2520658ed5f592fe9d324c550dedbc68fdfb62baec",
    "chacha20-0.9.1-p13-source-projection" =>
      "a71363348afdeb6520ab5258bb02b319bddbb2332b44e956db112ed7d6469a37",
    "rustsec-advisory-db-p01" =>
      "c1808ecd4a92c4dcd2d401eba6c67f07fe96592edf37ae7a1ba81291520de9d1",
    "creative-commons-by-4.0-legalcode-p13" =>
      "f7d6eb0b47d49141c22434b8a25d4763e1f06108d02cf11b66ffff30f64ff2ad",
    "cpython-3.14.6-p13-transport" =>
      "dd6de7e79b5643c66fb20bdb6227730b9ea4ab1ebf1b1e2a2571568930055bba",
    "openssl-3.6.3-p13-transport" =>
      "e557058196a692bb74b090552f37e05d7c0fd4a498fbb7bc09bb4ee08f6b8aa2"
  }.freeze

  PROFILE = "Noise_NNpsk0_25519_ChaChaPoly_BLAKE2s"
  SNOW_FEATURES = %w[
    use-chacha20poly1305
    use-blake2
    use-curve25519
  ].freeze
  APPROVED_LICENSE_EXPRESSIONS = [
    "Apache-2.0 OR MIT",
    "MIT OR Apache-2.0",
    "MIT/Apache-2.0",
    "BSD-3-Clause",
    "MIT OR Apache-2.0 OR BSD-1-Clause",
    "MIT",
    "(MIT OR Apache-2.0) AND Unicode-3.0"
  ].freeze
  COMPILE_PROJECTION_PATHS = {
    "aead" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      src/lib.rs
    ],
    "blake2" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      src/as_bytes.rs
      src/consts.rs
      src/lib.rs
      src/macros.rs
      src/simd.rs
      src/simd/simd_opt.rs
      src/simd/simdint.rs
      src/simd/simdop.rs
      src/simd/simdty.rs
    ],
    "block-buffer" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      src/lib.rs
      src/sealed.rs
    ],
    "cfg-if" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      src/lib.rs
    ],
    "chacha20" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      src/backends.rs
      src/backends/soft.rs
      src/legacy.rs
      src/lib.rs
      src/xchacha.rs
    ],
    "chacha20poly1305" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      README.md
      src/cipher.rs
      src/lib.rs
    ],
    "cipher" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      src/block.rs
      src/errors.rs
      src/lib.rs
      src/stream.rs
      src/stream_core.rs
      src/stream_wrapper.rs
    ],
    "cpufeatures" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      src/lib.rs
      src/x86.rs
    ],
    "crypto-common" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      src/lib.rs
    ],
    "curve25519-dalek" => %w[
      Cargo.toml
      LICENSE
      README.md
      build.rs
      src/backend/mod.rs
      src/backend/serial/curve_models/mod.rs
      src/backend/serial/mod.rs
      src/backend/serial/scalar_mul/mod.rs
      src/backend/serial/scalar_mul/variable_base.rs
      src/backend/serial/scalar_mul/vartime_double_base.rs
      src/backend/serial/u64/constants.rs
      src/backend/serial/u64/field.rs
      src/backend/serial/u64/mod.rs
      src/backend/serial/u64/scalar.rs
      src/constants.rs
      src/edwards.rs
      src/field.rs
      src/lib.rs
      src/macros.rs
      src/montgomery.rs
      src/ristretto.rs
      src/scalar.rs
      src/traits.rs
      src/window.rs
    ],
    "digest" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      src/core_api.rs
      src/core_api/ct_variable.rs
      src/core_api/rt_variable.rs
      src/core_api/wrapper.rs
      src/core_api/xof_reader.rs
      src/digest.rs
      src/lib.rs
      src/mac.rs
    ],
    "generic-array" => %w[
      Cargo.toml
      LICENSE
      build.rs
      src/arr.rs
      src/functional.rs
      src/hex.rs
      src/impls.rs
      src/iter.rs
      src/lib.rs
      src/sequence.rs
    ],
    "inout" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      src/errors.rs
      src/inout.rs
      src/inout_buf.rs
      src/lib.rs
      src/reserved.rs
    ],
    "opaque-debug" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      src/lib.rs
    ],
    "poly1305" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      src/backend.rs
      src/backend/soft.rs
      src/lib.rs
    ],
    "rustc_version" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      src/lib.rs
    ],
    "semver" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      build.rs
      src/backport.rs
      src/display.rs
      src/error.rs
      src/eval.rs
      src/identifier.rs
      src/impls.rs
      src/lib.rs
      src/parse.rs
    ],
    "snow" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      build.rs
      src/builder.rs
      src/cipherstate.rs
      src/constants.rs
      src/error.rs
      src/handshakestate.rs
      src/lib.rs
      src/params/mod.rs
      src/params/patterns.rs
      src/resolvers/default.rs
      src/resolvers/mod.rs
      src/stateless_transportstate.rs
      src/symmetricstate.rs
      src/transportstate.rs
      src/types.rs
      src/utils.rs
    ],
    "subtle" => %w[
      Cargo.toml
      LICENSE
      src/lib.rs
    ],
    "typenum" => %w[
      Cargo.toml
      LICENSE
      LICENSE-APACHE
      LICENSE-MIT
      build.rs
      src/array.rs
      src/bit.rs
      src/gen.rs
      src/gen/consts.rs
      src/gen/op.rs
      src/int.rs
      src/lib.rs
      src/marker_traits.rs
      src/operator_aliases.rs
      src/private.rs
      src/type_operators.rs
      src/uint.rs
    ],
    "universal-hash" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      src/lib.rs
    ],
    "version_check" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      src/channel.rs
      src/date.rs
      src/lib.rs
      src/version.rs
    ],
    "zeroize" => %w[
      Cargo.toml
      LICENSE-APACHE
      LICENSE-MIT
      src/aarch64.rs
      src/lib.rs
      src/x86.rs
    ]
  }.transform_values { |paths| paths.sort.freeze }.freeze
  ORIGIN_NOTICE_PATTERN = /
    (?:
      \A(?:Portions\s+)?Copyright\b
      | \AProject-authored\b
      | Based\ on\ the\ \[[^\]]+\]\[[^\]]+\]\ crate
      | Based\ on\ the\ `[^`]+`\ crate
      | \bbased\ (?:on|off\ of|upon)\ [^\n]*
        (?:work|implementation|BoringSSL|rust-lang\/rust\#)
      | \bbased\ on\ the\ \[ChaCha20\]\[[^\]]+\]
      | \bthanks\ to\ work\ by\b
      | \breference\ implementation\ of\b[^\n]*\bby\b
      | \b(?:was\ |code\ was\ )?originally\ derived\ from\b
      | \b(?:code|implementation|test\ vectors?)\s+derived\ from\b
      | \boriginally\ (?:a\ )?port\ of\b
      | \b(?:code|implementation|test\ vectors?)?\s*ported\ from\b
      | \b(?:code|implementation|test\ vectors?)?\s*extracted\ from\b
      | \b(?:code|implementation|test\ vectors?)?\s*(?:taken|borrowed)\ from\b
      | \binspired\ by\b
      | \b(?:a|an)\ adaptation\ of\b
      | \bimplementation\ strategy\ derived\ from\b
      | \bcopied\ from\b
      | \badapted\ from\b
      | \boriginates\ from\b
      | \bknown\ occurrence\ of\ this\ optimization\b
      | \bWraps\ `[^`]+`[^\n]*\ implementation\b
      | \bis\ authored\ by\b
      | \bwas\ (?:implemented|provided|contributed)\ by\b
      | \bcontributed\ by\b
      | \AThanks\ also\ to\b
      | \bfollows\ the\ implementation\ choices\ made\ by\b
    )
  /ix
  REPRODUCED_ORIGIN_NOTICE_PATTERN = /
    (?:
      \bfunction:\s+adapts\ the\b
      | \bon\ which\ [^\n]+\ is\ based\b
      | \ATest\ vectors\ from:
      | \bfunction\ from\ the\ Elligator2\ spec\b
      | \bcomputation\ uses\ [^\n]*algorithm,\ as\ described\b
      | \bknown\ scalar\ multiple\ from\ ed25519\.py\b
      | \bSignal\ tests\ from\b
      | \bfollows\ the\ one-way\ map\ construction\ from\b
      | \AThese\ inputs\ are\ from\b
      | \AUses\ the\ addition\ chain\ from\b
      | \AFrom\ the\ HFS\ spec,\ Section\ 5:
      | \AWraps\ (?:x25519-dalek\.|p256)\z
      | \ATest\ vector\ from\ RFC\ 5903,\ section\ 8\.1\z
      | \AFrom:\s+https:\/\/github\.com\/RustCrypto\/utils\/pull\/759
        \#issuecomment-1087976570\z
    )
  /ix
  ORIGIN_LEGAL_FILE_PATTERN =
    /\A(?:AUTHORS|CONTRIBUTORS|COPYING|COPYRIGHT|LICENCE|LICENSE|NOTICE|UNLICENSE)/i
  RUST_REGISTRY_LEGAL_BASENAME_PATTERN =
    /(?:\A|[^A-Z0-9])(?:AUTHORS|CONTRIBUTORS|COPYING|COPYRIGHT|LICENCES?|LICENSES?|NOTICES?|UNLICENSE)(?=\z|[^A-Z0-9])/i
  RUST_REGISTRY_ADDITIONAL_LEGAL_BASENAME_PATTERN =
    /
      \A(?:
        ACKNOWLEDG(?:E)?MENTS?
        | ATTRIBUTIONS?
        | COPYLEFT
        | CREDITS?
        | LEGAL
        | PACKAGERS?
        | PATENTS?
        | RIGHTS
        | THANKS
        | THIRD(?:[_ -]?PARTY)
      )(?:\.[^\/]+)?\z
    /ix
  RUST_REGISTRY_LEGAL_DIRECTORY_PATTERN = /\ALICEN[CS]ES?\z/i
  RUST_REGISTRY_CONTENT_DISCOVERY_VERSION =
    "rust-registry-license-origin-witness-v8"
  RUST_REGISTRY_CONTENT_DISCOVERY_SCOPE =
    "BOUNDED_MULTILINE_ASCII_WITNESS_VOCABULARY_NOT_UNIVERSAL_LEGAL_CLASSIFICATION"
  RUST_ORIGIN_COMMENT_PREFIX =
    /(?:(?:\/\/[\/!]?)|(?:\/?\*)|\#|--|;)/n
  RUST_ORIGIN_WORD_SEPARATOR =
    /(?:[ \t]+|[ \t]*\r?\n[ \t]*(?:#{RUST_ORIGIN_COMMENT_PREFIX.source})?[ \t]*)/n
  RUST_ORIGIN_COMMENT_LINE_BREAK =
    /[ \t]*\r?\n[ \t]*(?:#{RUST_ORIGIN_COMMENT_PREFIX.source})?[ \t]*/n
  RUST_ORIGIN_LINE_START = /(?:\A|(?<=\n))[ \t]*/n
  RUST_ORIGIN_TARGET_EVIDENCE =
    /(?=[^\r\n]{0,160}(?:https?:\/\/|[A-Za-z0-9_.-]+\/[A-Za-z0-9_.\/-]+|[A-Za-z0-9_.+-]+\.(?:c|cc|cpp|h|hpp|md|rs|txt)\b|`[A-Za-z_][A-Za-z0-9_:\/.-]{2,}`|::|\b(?:source|code|implementation|impl|library|crate|project|repository|rustc|stdarch|llvm|linux|trait)\b))/in
  RUST_ORIGIN_TARGET_LEAD =
    /[ \t]*(?::[ \t]*)?(?:\r?\n[ \t]*(?:#{RUST_ORIGIN_COMMENT_PREFIX.source})?[ \t]*)?/n
  RUST_ORIGIN_TARGET =
    /
      (?:
        <?(?i:https?):\/\/[^\s)>]+>?
        | \[[A-Za-z0-9_.:\/ -]{1,80}\]
        | `[^`\r\n]{0,80}(?:\/|\\|\.(?i:[A-Za-z0-9]{1,8}))[^`\r\n]{0,80}`
        | [A-Za-z0-9_.+-]+(?:\/[A-Za-z0-9_.+-]+)+
        | [A-Za-z0-9_.+-]+\.(?i:c|cc|cpp|h|hpp|md|rs|txt)
        | (?:(?i:the)[ \t]+)?[A-Z][A-Za-z0-9_.+-]{1,63}(?:'s)?
        | [a-z][a-z0-9_.+-]{1,63}'s#{RUST_ORIGIN_WORD_SEPARATOR.source}
          [A-Za-z0-9_.+-]+\.(?i:c|cc|cpp|h|hpp|md|rs|txt)
        | [a-z][a-z0-9_.+-]{2,63}
          (?:#{RUST_ORIGIN_WORD_SEPARATOR.source}(?i:and|or)
          #{RUST_ORIGIN_WORD_SEPARATOR.source}[a-z][a-z0-9_.+-]{2,63})?
          [ \t]*\(\s*(?i:https?):\/\/
      )
    /nx
  RUST_ORIGIN_REJECTION_PATTERNS = {
    "ORIGIN_DERIVED_OR_COPIED" =>
      /
        \b(?:
          (?:copied|derived)\s+from\s+
          (?:
            it\b
            | (?:src|source)\s+to\s+(?:dst|destination)\b
          )
          | copied\s+from\s+`[a-z_][a-z0-9_]*`\s*,?\s+but\b
          | compound\s+derived\s+from\s+another\s+compound\b
        )
      /ix,
    "ORIGIN_BASED_OR_INSPIRED" =>
      /\bbased\s+on\s+(?:whether\b|binary\s+size\b)/i
  }.freeze
  RUST_ARCHIVE_CHILD_DEADLINE_SECONDS = 900
  RUST_ARCHIVE_SILENT_OUTPUT_MAX_BYTES = 0
  RUST_REGISTRY_CONTENT_LIMITS = {
    "max_packages_per_closure" => 1_024,
    "max_files_per_package" => 8_192,
    "max_files_per_closure" => 32_768,
    "max_bytes_per_file" => 64 * 1024 * 1024,
    "max_bytes_per_closure" => 768 * 1024 * 1024,
    "max_witnesses_per_file" => 256,
    "max_witnesses_per_closure" => 16_384,
    "max_extraction_list_bytes" => 4 * 1024 * 1024,
    "max_archive_listing_bytes" => RUST_ARCHIVE_LISTING_MAX_BYTES,
    "max_archive_path_depth" => P13SourceFetch::MAX_ARCHIVE_PATH_DEPTH,
    "max_witness_span_lines" => ORIGIN_STATEMENT_MAX_LINES
  }.freeze
  RUST_REGISTRY_CONTENT_WITNESS_RULES = [
    {
      "id" => "PERMISSIVE_MIT_OR_UNICODE_GRANT",
      "classification" => "PERMISSIVE_LICENSE_GRANT_REVIEW_REQUIRED",
      "pattern" =>
        /\bPermission\s+is\s+hereby\s+granted,\s+free\s+of\s+charge\b/in
    },
    {
      "id" => "PERMISSIVE_ISC_GRANT",
      "classification" => "PERMISSIVE_LICENSE_GRANT_REVIEW_REQUIRED",
      "pattern" =>
        /\bPermission\s+to\s+use,\s+copy,\s+modify,\s+and(?:\/or|\s+or)\s+distribute\s+this\s+software\b/in
    },
    {
      "id" => "PERMISSIVE_BSD_GRANT",
      "classification" => "PERMISSIVE_LICENSE_GRANT_REVIEW_REQUIRED",
      "pattern" =>
        /\bRedistribution\s+and\s+use\s+in\s+source\s+and\s+binary\s+forms\b/in
    },
    {
      "id" => "PERMISSIVE_APACHE_2_0_GRANT",
      "classification" => "PERMISSIVE_LICENSE_GRANT_REVIEW_REQUIRED",
      "pattern" =>
        /\bLicensed\s+under\s+the\s+Apache\s+License,\s+Version\s+2\.0\b/in
    },
    {
      "id" => "PERMISSIVE_ZLIB_GRANT",
      "classification" => "PERMISSIVE_LICENSE_GRANT_REVIEW_REQUIRED",
      "pattern" =>
        /\bPermission\s+is\s+granted\s+to\s+anyone\s+to\s+use\s+this\s+software\s+for\s+any\s+purpose\b/in
    },
    {
      "id" => "ALTERNATIVE_MPL_2_0",
      "classification" => "ALTERNATIVE_OR_EXCEPTION_REVIEW_REQUIRED",
      "pattern" =>
        /\b(?:MPL-2\.0|Mozilla\s+Public\s+License(?:,?\s+Version\s+2\.0)?)\b/in
    },
    {
      "id" => "RESTRICTIVE_BUSL",
      "classification" => "RESTRICTIVE_LICENSE_IDENTIFIER_REVIEW_REQUIRED",
      "pattern" =>
        /\b(?:BUSL(?:-1\.1)?|Business\s+Source\s+License)\b/in
    },
    {
      "id" => "RESTRICTIVE_SSPL",
      "classification" => "RESTRICTIVE_LICENSE_IDENTIFIER_REVIEW_REQUIRED",
      "pattern" =>
        /\b(?:SSPL(?:-1\.0)?|Server\s+Side\s+Public\s+License)\b/in
    },
    {
      "id" => "RESTRICTIVE_COMMONS_CLAUSE",
      "classification" => "RESTRICTIVE_LICENSE_IDENTIFIER_REVIEW_REQUIRED",
      "pattern" => /\bCommons\s+Clause\b/in
    },
    {
      "id" => "RESTRICTIVE_NONCOMMERCIAL",
      "classification" => "RESTRICTIVE_USE_LIMIT_REVIEW_REQUIRED",
      "pattern" =>
        /\b(?:non[\s-]?commercial|not\s+for\s+commercial\s+use|commercial\s+use\s+(?:is\s+)?prohibited)\b/in
    },
    {
      "id" => "RESTRICTIVE_NO_DERIVATIVES",
      "classification" => "RESTRICTIVE_MODIFICATION_LIMIT_REVIEW_REQUIRED",
      "pattern" =>
        /\b(?:no[\s-]?derivatives|no[\s-]?derivative\s+works?|modification\s+(?:is\s+)?prohibited)\b/in
    },
    {
      "id" => "RESTRICTIVE_RESEARCH_ONLY",
      "classification" => "RESTRICTIVE_USE_LIMIT_REVIEW_REQUIRED",
      "pattern" =>
        /\b(?:research[\s-]?only|for\s+research\s+purposes?\s+only)\b/in
    },
    {
      "id" => "RESTRICTIVE_PRIOR_WRITTEN_PERMISSION",
      "classification" => "RESTRICTIVE_USE_MODIFICATION_DISTRIBUTION_REVIEW_REQUIRED",
      "pattern" =>
        /\byou[\s#*\/;-]+may[\s#*\/;-]+not[\s#*\/;-]+use,[\s#*\/;-]+modify,[\s#*\/;-]+copy,[\s#*\/;-]+publish,[\s#*\/;-]+distribute,[\s#*\/;-]+disclose[\s#*\/;-]+or[\s#*\/;-]+transmit\b[\s\S]{0,400}\bprior[\s#*\/;-]+written[\s#*\/;-]+permission\b/in
    },
    {
      "id" => "NONSTANDARD_CC0",
      "classification" => "NON_OSI_ORIGIN_OR_ALTERNATIVE_REVIEW_REQUIRED",
      "pattern" =>
        /\b(?:(?<!\\u\{)CC0(?:-1\.0)?|Creative\s+Commons\s+Zero)\b/in
    },
    {
      "id" => "NONSTANDARD_PUBLIC_DOMAIN",
      "classification" => "NON_OSI_ORIGIN_OR_ALTERNATIVE_REVIEW_REQUIRED",
      "pattern" =>
        /(?:\b(?:dedicated|licensed|placed|released|waived)\b.{0,120}\bpublic\s+domain\b|\bpublic\s+domain\b.{0,120}\b(?:dedication|license|waiver)\b)/in
    },
    {
      "id" => "ALTERNATIVE_GPL_FAMILY",
      "classification" => "ALTERNATIVE_OR_EXCEPTION_REVIEW_REQUIRED",
      "pattern" =>
        /(?:SPDX-License-Identifier:.{0,160}\b(?:A?GPL|LGPL)-|\bGNU\s+(?:Affero\s+|Lesser\s+)?General\s+Public\s+License\b|\bauthori[sz]ed.{0,120}\bGPL\b)/in
    },
    {
      "id" => "ALTERNATIVE_GPL_3_OR_LATER_WITH_GCC_EXCEPTION_3_1",
      "classification" => "ALTERNATIVE_OR_EXCEPTION_REVIEW_REQUIRED",
      "pattern" =>
        /\bGNU\s+General\s+Public\s+License\b[\s\S]{0,600}\beither\s+version\s+3,\s+or\s+\(at\s+your\s+option\)\s+any\s+later\s+version\b[\s\S]{0,600}\bGCC\s+Runtime\s+Library\s+Exception,\s+version\s+3\.1\b/in
    },
    {
      "id" => "ALTERNATIVE_BOOST_LICENSE",
      "classification" => "ALTERNATIVE_OR_EXCEPTION_REVIEW_REQUIRED",
      "pattern" => /\bBoost\s+Software\s+License\b/in
    },
    {
      "id" => "ORIGIN_TRANSLATED_OR_PORTED",
      "classification" => "EXTERNAL_SOURCE_ORIGIN_REVIEW_REQUIRED",
      "pattern" =>
        /(?:(?:\A|(?<=\n))[ \t]*(?:(?:\/\/[\/!]?)|(?:\/?\*)|\#|--|;)[ \t]*[^\r\n]{0,120}\b(?:translated|transliterated|ported)\b[^\r\n]{0,160}\bfrom\b|\b(?:algorithm|code|file|function|implementation|module|routine|software|source|table|test)s?\b[^\r\n]{0,120}\b(?:translated|transliterated|ported)\b[^\r\n]{0,160}\bfrom\b)/in
    },
    {
      "id" => "ORIGIN_DERIVED_OR_COPIED",
      "classification" => "EXTERNAL_SOURCE_ORIGIN_REVIEW_REQUIRED",
      "pattern" =>
        /(?:
          #{RUST_ORIGIN_LINE_START.source}
          #{RUST_ORIGIN_COMMENT_PREFIX.source}[ \t]*
          (?:(?i:this)[ \t]+(?i:is)[ \t]+)?
          (?:adapted|borrowed|copied|derived|extracted|taken)\b
          [^\r\n]{0,160}\bfrom\b
          #{RUST_ORIGIN_TARGET_EVIDENCE.source}
          |
          \b(?:algorithm|code|context|file|function|implementation|module|
          routine|software|source|table|test)s?\b[^\r\n]{0,120}
          \b(?:adapted|borrowed|copied|derived|extracted|taken)\b
          [^\r\n]{0,160}\bfrom\b
          |
          #{RUST_ORIGIN_LINE_START.source}
          (?i:The)#{RUST_ORIGIN_WORD_SEPARATOR.source}(?i:following)
          #{RUST_ORIGIN_WORD_SEPARATOR.source}(?i:context)
          #{RUST_ORIGIN_WORD_SEPARATOR.source}(?i:is)
          #{RUST_ORIGIN_WORD_SEPARATOR.source}(?i:extracted)
          #{RUST_ORIGIN_WORD_SEPARATOR.source}(?i:from)\b
          [\s\S]{0,160}?
          #{RUST_ORIGIN_WORD_SEPARATOR.source}(?i:from)
          #{RUST_ORIGIN_WORD_SEPARATOR.source}[a-z][a-z0-9_.+-]{2,63}\b
          |
          #{RUST_ORIGIN_LINE_START.source}
          #{RUST_ORIGIN_COMMENT_PREFIX.source}[ \t]*
          (?i:heavily)[ \t]+(?i:copied)[ \t]+(?i:from):?
          #{RUST_ORIGIN_COMMENT_LINE_BREAK.source}#{RUST_ORIGIN_TARGET.source}
          |
          #{RUST_ORIGIN_LINE_START.source}
          #{RUST_ORIGIN_COMMENT_PREFIX.source}[ \t]*
          (?i:adapted|borrowed|copied|derived|extracted|taken)\b
          #{RUST_ORIGIN_WORD_SEPARATOR.source}(?i:from)\b
          #{RUST_ORIGIN_TARGET_LEAD.source}
          (?-i:#{RUST_ORIGIN_TARGET.source})
          |
          #{RUST_ORIGIN_LINE_START.source}
          #{RUST_ORIGIN_COMMENT_PREFIX.source}[ \t]*
          (?i:the)[ \t]+(?i:following)[ \t]+(?i:is)[ \t]+(?i:derived)
          #{RUST_ORIGIN_WORD_SEPARATOR.source}(?i:from)\b
          #{RUST_ORIGIN_TARGET_LEAD.source}
          (?-i:#{RUST_ORIGIN_TARGET.source})
          |
          #{RUST_ORIGIN_LINE_START.source}
          #{RUST_ORIGIN_COMMENT_PREFIX.source}[ \t]*
          [A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z_][A-Za-z0-9_]*)+
          [ \t]+(?i:arm)[ \t]+(?i:copied)
          #{RUST_ORIGIN_WORD_SEPARATOR.source}(?i:from)\b
          #{RUST_ORIGIN_TARGET_LEAD.source}
          (?-i:[a-z][a-z0-9_.+-]{2,63})\b
          |
          #{RUST_ORIGIN_LINE_START.source}
          #{RUST_ORIGIN_COMMENT_PREFIX.source}[ \t]*(?i:copied)
          #{RUST_ORIGIN_COMMENT_LINE_BREAK.source}(?i:from)\b
          #{RUST_ORIGIN_TARGET_LEAD.source}#{RUST_ORIGIN_TARGET.source}
          |
          #{RUST_ORIGIN_LINE_START.source}
          #{RUST_ORIGIN_COMMENT_PREFIX.source}[ \t]*
          (?i:copied)[ \t]+(?i:from)\b
          #{RUST_ORIGIN_COMMENT_LINE_BREAK.source}#{RUST_ORIGIN_TARGET.source}
          |
          #{RUST_ORIGIN_LINE_START.source}
          #{RUST_ORIGIN_COMMENT_PREFIX.source}[ \t]*
          (?i:copied)[ \t]+(?i:from)[ \t]+OpenBSD\b
          |
          #{RUST_ORIGIN_LINE_START.source}
          #{RUST_ORIGIN_COMMENT_PREFIX.source}[^\r\n]{0,120}
          \b(?i:content)\b[^\r\n]{0,80}\b(?i:derived)\b
          #{RUST_ORIGIN_WORD_SEPARATOR.source}(?i:from)\b
          #{RUST_ORIGIN_TARGET_LEAD.source}#{RUST_ORIGIN_TARGET.source}
        )/inx
    },
    {
      "id" => "ORIGIN_BASED_OR_INSPIRED",
      "classification" => "EXTERNAL_SOURCE_ORIGIN_REVIEW_REQUIRED",
      "pattern" =>
        /(?:(?:\A|(?<=\n))[ \t]*(?:(?:\/\/[\/!]?)|(?:\/?\*)|\#|--|;)[ \t]*(?:[^\r\n]{0,120}\binspired#{RUST_ORIGIN_WORD_SEPARATOR.source}by|based#{RUST_ORIGIN_WORD_SEPARATOR.source}(?:on|off#{RUST_ORIGIN_WORD_SEPARATOR.source}of|upon)|[^\r\n]{0,120}\b(?:algorithm|code|file|implementation|implementations|module|routine|script|software|source|test)s?\b[^\r\n]{0,80}\bbased#{RUST_ORIGIN_WORD_SEPARATOR.source}(?:on|off#{RUST_ORIGIN_WORD_SEPARATOR.source}of|upon))\b[^\r\n]{0,160}|\b(?:algorithm|code|file|implementation|implementations|module|routine|script|software|source|test)s?\b[^\r\n]{0,80}\b(?:inspired#{RUST_ORIGIN_WORD_SEPARATOR.source}by|based#{RUST_ORIGIN_WORD_SEPARATOR.source}(?:on|off#{RUST_ORIGIN_WORD_SEPARATOR.source}of|upon))\b[^\r\n]{0,160}|(?:\A|(?<=\n))[ \t]*#{RUST_ORIGIN_COMMENT_PREFIX.source}[^\r\n]{0,120}\b(?i:inspired)#{RUST_ORIGIN_COMMENT_LINE_BREAK.source}(?i:by)\b[^\r\n]{0,120}https?:\/\/)/inx
    }
  ].freeze
  RUST_REGISTRY_CONTENT_PREFILTERS = {
    "PERMISSIVE_MIT_OR_UNICODE_GRANT" => %w[permission],
    "PERMISSIVE_ISC_GRANT" => %w[permission],
    "PERMISSIVE_BSD_GRANT" => %w[redistribution],
    "PERMISSIVE_APACHE_2_0_GRANT" => %w[apache],
    "PERMISSIVE_ZLIB_GRANT" => %w[permission],
    "ALTERNATIVE_MPL_2_0" => ["mpl-2.0", "mozilla"],
    "RESTRICTIVE_BUSL" => ["busl", "business source"],
    "RESTRICTIVE_SSPL" => ["sspl", "server side public"],
    "RESTRICTIVE_COMMONS_CLAUSE" => %w[commons],
    "RESTRICTIVE_NONCOMMERCIAL" => %w[commercial],
    "RESTRICTIVE_NO_DERIVATIVES" => %w[derivative modification],
    "RESTRICTIVE_RESEARCH_ONLY" => %w[research],
    "RESTRICTIVE_PRIOR_WRITTEN_PERMISSION" => %w[prior],
    "NONSTANDARD_CC0" => %w[cc0 creative],
    "NONSTANDARD_PUBLIC_DOMAIN" => %w[public],
    "ALTERNATIVE_GPL_FAMILY" => ["gpl", "general public"],
    "ALTERNATIVE_GPL_3_OR_LATER_WITH_GCC_EXCEPTION_3_1" =>
      ["general public"],
    "ALTERNATIVE_BOOST_LICENSE" => %w[boost],
    "ORIGIN_TRANSLATED_OR_PORTED" =>
      %w[translated transliterated ported],
    "ORIGIN_DERIVED_OR_COPIED" =>
      %w[adapted borrowed copied derived extracted taken],
    "ORIGIN_BASED_OR_INSPIRED" => %w[based inspired]
  }.transform_values { |needles| needles.map(&:b).freeze }.freeze
  RUST_REGISTRY_CONTENT_DISPOSITION_TUPLES = [
    %w[
      PERMISSIVE_GRANT_IN_CHECKSUM_BOUND_PACKAGE
      OSI_COMPATIBLE_GRANT_REVIEWED
      ACTIVE_LOCK_GRAPH_ONLY_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14
      PERMISSIVE_GRANT_RETAINED_AND_ELECTION_BOUND
    ],
    %w[
      PERMISSIVE_GRANT_IN_CHECKSUM_BOUND_PACKAGE
      OSI_COMPATIBLE_GRANT_REVIEWED
      UNREACHABLE_FROM_SELECTED_LOCK_GRAPH
      PERMISSIVE_GRANT_RETAINED_AND_ELECTION_BOUND
    ],
    %w[
      PACKAGE_OSI_ELECTION_OR_EXCLUDED_PATH
      REVIEWED_NO_NON_OSI_P13_LICENSE_ELECTION
      ACTIVE_LOCK_GRAPH_ONLY_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14
      NON_OSI_WITNESS_RETAINED_WITH_NATIVE_FILE_ADMISSION_DEFERRED
    ],
    %w[
      PACKAGE_OSI_ELECTION_OR_EXCLUDED_PATH
      REVIEWED_NO_NON_OSI_P13_LICENSE_ELECTION
      UNREACHABLE_FROM_SELECTED_LOCK_GRAPH
      NON_OSI_WITNESS_RETAINED_WITH_NATIVE_FILE_ADMISSION_DEFERRED
    ],
    %w[
      PACKAGE_GRANT_AND_RETAINED_ORIGIN_NOTICE
      REVIEWED_PACKAGE_RIGHTS_WITH_EXACT_FILE_WITNESS
      ACTIVE_LOCK_GRAPH_ONLY_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14
      ORIGIN_STATEMENT_RETAINED_UNDER_PACKAGE_GRANT
    ],
    %w[
      PACKAGE_GRANT_AND_RETAINED_ORIGIN_NOTICE
      REVIEWED_PACKAGE_RIGHTS_WITH_EXACT_FILE_WITNESS
      UNREACHABLE_FROM_SELECTED_LOCK_GRAPH
      ORIGIN_STATEMENT_RETAINED_UNDER_PACKAGE_GRANT
    ],
    %w[
      PACKAGE_OSI_LICENSE_ELECTION
      REVIEWED_OSI_ELECTION_RETAINED
      ACTIVE_LOCK_GRAPH_ONLY_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14
      ALTERNATIVE_GRANT_NOT_USED_AS_P13_LICENSE_ELECTION
    ],
    %w[
      PACKAGE_OSI_LICENSE_ELECTION
      REVIEWED_OSI_ELECTION_RETAINED
      UNREACHABLE_FROM_SELECTED_LOCK_GRAPH
      ALTERNATIVE_GRANT_NOT_USED_AS_P13_LICENSE_ELECTION
    ],
    %w[
      PACKAGE_OSI_LICENSE_ELECTION
      REVIEWED_OSI_ELECTION_RETAINED
      ACTIVE_LOCK_GRAPH_ONLY_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14
      ALTERNATIVE_GRANT_MATCHES_PACKAGE_LICENSE_ELECTION
    ],
    %w[
      PACKAGE_OSI_LICENSE_ELECTION
      REVIEWED_OSI_ELECTION_RETAINED
      UNREACHABLE_FROM_SELECTED_LOCK_GRAPH
      ALTERNATIVE_GRANT_MATCHES_PACKAGE_LICENSE_ELECTION
    ],
    %w[
      IMMUTABLE_REDWOOD_GPL_SOURCE_AND_AUTHOR_RELICENSE_GRANT
      EXACT_ORIGIN_AND_UNRESTRICTED_RELICENSE_PERMISSION_VERIFIED
      ACTIVE_LOCK_GRAPH_ONLY_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14
      COPIED_SOURCE_BOUND_TO_EXACT_ORIGIN_AND_SEPARATE_AUTHOR_PERMISSION
    ],
    %w[
      IMMUTABLE_HYPERIUM_HTTP_MIT_OR_APACHE_2_0_ORIGIN
      EXACT_ORIGIN_AND_OSI_GRANTS_VERIFIED
      ACTIVE_LOCK_GRAPH_ONLY_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14
      COPIED_SOURCE_BOUND_TO_EXACT_DUAL_LICENSED_ORIGIN
    ],
    %w[
      RUST_SOURCE_ROOT_AND_BUNDLED_OSI_GRANTS
      SELECTED_PATH_SOURCE_RIGHTS_REVIEWED
      PATH_PACKAGE_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14
      PERMISSIVE_GRANT_RETAINED_UNDER_RUST_SOURCE_CLOSURE
    ],
    %w[
      RUST_SOURCE_LICENSE_METADATA_AND_RETAINED_ORIGIN_NOTICE
      SELECTED_PATH_SOURCE_RIGHTS_REVIEWED
      PATH_PACKAGE_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14
      ORIGIN_STATEMENT_RETAINED_UNDER_RUST_SOURCE_CLOSURE
    ],
    %w[
      RUST_SOURCE_OSI_ELECTION_OR_EXCEPTION
      SELECTED_PATH_SOURCE_RIGHTS_REVIEWED
      PATH_PACKAGE_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14
      ALTERNATIVE_GRANT_RETAINED_UNDER_RUST_SOURCE_CLOSURE
    ],
    %w[
      RUST_SOURCE_GPL_3_OR_LATER_WITH_GCC_EXCEPTION_3_1
      EXACT_GPL_AND_GCC_RUNTIME_EXCEPTION_TEXTS_BOUND
      PATH_PACKAGE_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14
      GPL_3_OR_LATER_WITH_GCC_EXCEPTION_3_1_RETAINED
    ],
    %w[
      RUST_SOURCE_INTEL_CPUID_RESTRICTIVE_TERMS
      REJECTED_NOT_LICENSED_FOR_PROJECT_USE
      P13_NOT_ADMITTED_P14_NATIVE_REACHABILITY_MUST_EXCLUDE
      RESTRICTIVE_FILE_REJECTED_FROM_PRODUCT_SOURCE_CLOSURE
    ]
  ].map(&:freeze).freeze
  RUST_PATH_SOURCE_CLOSURES = {
    "compiler_and_clippy" => {
      "prefixes" => %w[compiler src/tools/clippy],
      "excluded_prefixes" => [],
      "path_package_count" => 125
    },
    "sysroot" => {
      "prefixes" => %w[library],
      "excluded_prefixes" => %w[library/vendor],
      "path_package_count" => 19
    }
  }.freeze
  RUST_PATH_SOURCE_SYMLINKS = {
    "compiler_and_clippy" => [
      {
        "path" => "src/tools/clippy/rustc_tools_util/LICENSE-APACHE",
        "target" => "../LICENSE-APACHE"
      },
      {
        "path" => "src/tools/clippy/rustc_tools_util/LICENSE-MIT",
        "target" => "../LICENSE-MIT"
      }
    ],
    "sysroot" => []
  }.freeze
  RUST_PATH_SOURCE_INTEL_REJECTION = {
    "path" => "library/stdarch/ci/docker/x86_64-unknown-linux-gnu/cpuid.def",
    "bytes" => 3_737,
    "sha256" =>
      "d94d3493cbcfc5d07acc5c315e4b2b3c340e292325bbab41a172f285b0eb6371",
    "rights" => "RUST_SOURCE_INTEL_CPUID_RESTRICTIVE_TERMS",
    "rights_status" => "REJECTED_NOT_LICENSED_FOR_PROJECT_USE",
    "reachability" => "P13_NOT_ADMITTED_P14_NATIVE_REACHABILITY_MUST_EXCLUDE",
    "disposition" => "RESTRICTIVE_FILE_REJECTED_FROM_PRODUCT_SOURCE_CLOSURE"
  }.freeze
  RUST_PATH_SOURCE_LOONGARCH_HEADERS = [
    {
      "path" =>
        "library/stdarch/crates/stdarch-gen-loongarch/lasxintrin.h",
      "bytes" => 227_555,
      "sha256" =>
        "1ca80c0dc7b3b7d8b228b9a4ea4dc8bb4bf410dc0411ff61ac09c1de42b93c61"
    },
    {
      "path" =>
        "library/stdarch/crates/stdarch-gen-loongarch/lsxintrin.h",
      "bytes" => 212_057,
      "sha256" =>
        "d519a8cb8536f0f1c4487056457879af0446eed1ab13704d87bfae5e6fb2e92d"
    }
  ].map(&:freeze).freeze
  RUST_PATH_SOURCE_LOONGARCH_DISPOSITION = {
    "rights" => "RUST_SOURCE_GPL_3_OR_LATER_WITH_GCC_EXCEPTION_3_1",
    "rights_status" => "EXACT_GPL_AND_GCC_RUNTIME_EXCEPTION_TEXTS_BOUND",
    "reachability" => "PATH_PACKAGE_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14",
    "disposition" => "GPL_3_OR_LATER_WITH_GCC_EXCEPTION_3_1_RETAINED"
  }.freeze
  RUST_COPIED_SOURCE_FILES = {
    "pulldown-cmark" => "src/utils.rs",
    "tracing-subscriber" => "src/registry/extensions.rs"
  }.freeze
  RUST_COPIED_SOURCE_DISPOSITIONS = {
    "vendor/pulldown-cmark-0.11.3/src/utils.rs" => %w[
      IMMUTABLE_REDWOOD_GPL_SOURCE_AND_AUTHOR_RELICENSE_GRANT
      EXACT_ORIGIN_AND_UNRESTRICTED_RELICENSE_PERMISSION_VERIFIED
      ACTIVE_LOCK_GRAPH_ONLY_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14
      COPIED_SOURCE_BOUND_TO_EXACT_ORIGIN_AND_SEPARATE_AUTHOR_PERMISSION
    ],
    "vendor/tracing-subscriber-0.3.20/src/registry/extensions.rs" => %w[
      IMMUTABLE_HYPERIUM_HTTP_MIT_OR_APACHE_2_0_ORIGIN
      EXACT_ORIGIN_AND_OSI_GRANTS_VERIFIED
      ACTIVE_LOCK_GRAPH_ONLY_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14
      COPIED_SOURCE_BOUND_TO_EXACT_DUAL_LICENSED_ORIGIN
    ]
  }.transform_values(&:freeze).freeze
  ORIGIN_LEGAL_DERIVATION_PATTERN =
    /\A(?:Portions\s+of\s+.+\s+)?(?:were\s+)?originally\s+derived\s+from\b/i
  ORIGIN_NOTICE_DISPOSITIONS = %w[
    CONTRIBUTOR_ATTRIBUTION_RETAINED_UNDER_PACKAGE_GRANT
    DEPENDENCY_WRAPPER_REFERENCE_CURRENT_BYTES_DUAL_LICENSED
    GO_BSD_GRANT_EMBEDDED_IN_PACKAGE_LICENSE
    HISTORICAL_ALGORITHM_REFERENCE_CURRENT_BYTES_DUAL_LICENSED
    ORIGIN_NOTICE_RETAINED_UNDER_MIT
    ORIGIN_RIGHTS_BOUND_IN_PACKAGE_BSD_3_CLAUSE
    ORIGIN_RIGHTS_BOUND_IN_PACKAGE_DUAL_LICENSE
    PROJECT_AUTHORED_NO_EXTERNAL_IMPLEMENTATION_BYTES
    VERIFIED_RUST_ARRAY_MIT_ORIGIN_AND_NOTICE
    SAME_PACKAGE_COPY_CURRENT_BYTES_BSD_3_CLAUSE
    SAME_PACKAGE_COPY_CURRENT_BYTES_DUAL_LICENSED
    SOURCE_COPYRIGHT_NOTICE_RETAINED_UNDER_PACKAGE_GRANT
    TECHNICAL_BEHAVIOR_REFERENCE_NO_SOURCE_BYTE_IMPORT_CLAIM
    TECHNICAL_CONSTRUCTION_REFERENCE_NO_SOURCE_BYTE_IMPORT_CLAIM
    TECHNICAL_DESIGN_REFERENCE_CURRENT_BYTES_BSD_3_CLAUSE
    TECHNICAL_FORMULA_REFERENCE_NO_SOURCE_BYTE_IMPORT_CLAIM
    UNSELECTED_OPTIONAL_REFERENCE_NO_SOURCE_BYTE_IMPORT_CLAIM
    UNSELECTED_DEV_TEST_REFERENCE_CURRENT_BYTES_DUAL_LICENSED
    VERIFIED_RUST_NUM_MIT_ORIGIN_AND_NOTICE
    ACKNOWLEDGMENT_NO_SOURCE_BYTE_IMPORT_CLAIM
  ].freeze
  ORIGIN_WITNESSES = {
    "BLAKE2_PACKAGE_GRANT" => {
      "packages" => %w[blake2],
      "dispositions" => %w[
        ORIGIN_RIGHTS_BOUND_IN_PACKAGE_DUAL_LICENSE
        SOURCE_COPYRIGHT_NOTICE_RETAINED_UNDER_PACKAGE_GRANT
      ]
    },
    "CHACHA20_PACKAGE_AND_SAME_SOURCE" => {
      "packages" => %w[chacha20],
      "dispositions" => %w[
        ORIGIN_RIGHTS_BOUND_IN_PACKAGE_DUAL_LICENSE
        SAME_PACKAGE_COPY_CURRENT_BYTES_DUAL_LICENSED
        TECHNICAL_CONSTRUCTION_REFERENCE_NO_SOURCE_BYTE_IMPORT_CLAIM
      ]
    },
    "CHACHA20POLY1305_PACKAGE_GRANT" => {
      "packages" => %w[chacha20poly1305],
      "dispositions" => %w[
        TECHNICAL_CONSTRUCTION_REFERENCE_NO_SOURCE_BYTE_IMPORT_CLAIM
      ]
    },
    "CURVE25519_BSD_AND_EMBEDDED_GO_GRANT" => {
      "packages" => %w[curve25519-dalek],
      "dispositions" => %w[
        CONTRIBUTOR_ATTRIBUTION_RETAINED_UNDER_PACKAGE_GRANT
        GO_BSD_GRANT_EMBEDDED_IN_PACKAGE_LICENSE
        ORIGIN_RIGHTS_BOUND_IN_PACKAGE_BSD_3_CLAUSE
        SOURCE_COPYRIGHT_NOTICE_RETAINED_UNDER_PACKAGE_GRANT
        SAME_PACKAGE_COPY_CURRENT_BYTES_BSD_3_CLAUSE
        TECHNICAL_FORMULA_REFERENCE_NO_SOURCE_BYTE_IMPORT_CLAIM
        UNSELECTED_OPTIONAL_REFERENCE_NO_SOURCE_BYTE_IMPORT_CLAIM
      ]
    },
    "GENERIC_ARRAY_RUST_PR49000_IMMUTABLE_ORIGIN" => {
      "packages" => %w[generic-array],
      "dispositions" => %w[
        ORIGIN_NOTICE_RETAINED_UNDER_MIT
        VERIFIED_RUST_ARRAY_MIT_ORIGIN_AND_NOTICE
      ]
    },
    "PROJECT_POLY1305_APACHE_2_0_SOURCE" => {
      "packages" => %w[poly1305],
      "dispositions" => %w[PROJECT_AUTHORED_NO_EXTERNAL_IMPLEMENTATION_BYTES]
    },
    "RUSTC_VERSION_PACKAGE_GRANT" => {
      "packages" => %w[rustc_version],
      "dispositions" => %w[
        SOURCE_COPYRIGHT_NOTICE_RETAINED_UNDER_PACKAGE_GRANT
      ]
    },
    "SEMVER_PACKAGE_GRANT" => {
      "packages" => %w[semver],
      "dispositions" => %w[
        TECHNICAL_BEHAVIOR_REFERENCE_NO_SOURCE_BYTE_IMPORT_CLAIM
      ]
    },
    "SNOW_PACKAGE_AND_DEPENDENCY_GRAPH" => {
      "packages" => %w[snow],
      "dispositions" => %w[
        DEPENDENCY_WRAPPER_REFERENCE_CURRENT_BYTES_DUAL_LICENSED
        UNSELECTED_DEV_TEST_REFERENCE_CURRENT_BYTES_DUAL_LICENSED
        UNSELECTED_OPTIONAL_REFERENCE_NO_SOURCE_BYTE_IMPORT_CLAIM
      ]
    },
    "SUBTLE_BSD_PACKAGE_GRANT" => {
      "packages" => %w[subtle],
      "dispositions" => %w[
        CONTRIBUTOR_ATTRIBUTION_RETAINED_UNDER_PACKAGE_GRANT
        SOURCE_COPYRIGHT_NOTICE_RETAINED_UNDER_PACKAGE_GRANT
        TECHNICAL_DESIGN_REFERENCE_CURRENT_BYTES_BSD_3_CLAUSE
      ]
    },
    "TYPENUM_RUST_NUM_IMMUTABLE_ORIGIN" => {
      "packages" => %w[typenum],
      "dispositions" => %w[
        ORIGIN_NOTICE_RETAINED_UNDER_MIT
        VERIFIED_RUST_NUM_MIT_ORIGIN_AND_NOTICE
      ]
    },
    "ZEROIZE_PACKAGE_GRANT" => {
      "packages" => %w[zeroize],
      "dispositions" => %w[ACKNOWLEDGMENT_NO_SOURCE_BYTE_IMPORT_CLAIM]
    }
  }.freeze

  COMMAND_WINDOW_FILES = [
    {
      "name" => "clippy-driver",
      "kind" => "executable",
      "path" => ".tools/rust-1.98.0/bin/clippy-driver",
      "bytes" => 13_067_504,
      "sha256" =>
        "6a1ccc398ad5466587424fd97625bad2a9296d4ef031a853b99eb80362f6e1e9",
      "source" => "Rust_1.98.0_admitted_archive",
      "license" => "MIT OR Apache-2.0",
      "purpose" => "strict_probe_lint_driver"
    },
    {
      "name" => "ld64.lld",
      "kind" => "executable",
      "path" =>
        ".tools/rust-1.98.0/lib/rustlib/aarch64-apple-darwin/bin/gcc-ld/ld64.lld",
      "bytes" => 377_072,
      "sha256" =>
        "910ef9bb07e4f137121da153c4267ebc3d3f30f88a9ee1e397f117402ec96640",
      "source" => "Rust_1.98.0_admitted_archive",
      "license" => "Apache-2.0 WITH LLVM-exception",
      "purpose" => "direct_linker"
    },
    {
      "name" => "libLLVM.dylib",
      "kind" => "runtime_library",
      "path" => ".tools/rust-1.98.0/lib/libLLVM.dylib",
      "bytes" => 139_564_208,
      "sha256" =>
        "6da171ecd17bbe20b57b2e2d2e324b8fb2267117b504e864eb8b3012a71a6fec",
      "source" => "Rust_1.98.0_admitted_archive",
      "license" => "Apache-2.0 WITH LLVM-exception",
      "purpose" => "compiler_and_linker_runtime"
    },
    {
      "name" => "librustc_driver",
      "kind" => "runtime_library",
      "path" =>
        ".tools/rust-1.98.0/lib/librustc_driver-4031c0ff8e88f5d1.dylib",
      "bytes" => 83_036_200,
      "sha256" =>
        "275171d3d528b7f78bcad812a84658ec3bd756ce9792a329b6edefdf70884c63",
      "source" => "Rust_1.98.0_admitted_archive",
      "license" => "MIT OR Apache-2.0",
      "purpose" => "rustc_and_clippy_runtime"
    },
    {
      "name" => "rustc",
      "kind" => "executable",
      "path" => ".tools/rust-1.98.0/bin/rustc",
      "bytes" => 412_504,
      "sha256" =>
        "a11618eca0956a8aa4372c2bc898690b513cbdfa2cb9125b2a5301e360ed5b49",
      "source" => "Rust_1.98.0_admitted_archive",
      "license" => "MIT OR Apache-2.0",
      "purpose" => "direct_compiler"
    }
  ].freeze
  COMMAND_WINDOW_TREES = [
    {
      "name" => "aarch64-apple-darwin-sysroot",
      "path" => ".tools/rust-1.98.0/lib/rustlib/aarch64-apple-darwin/lib",
      "file_count" => 59,
      "total_bytes" => 146_749_407,
      "inventory_sha256" =>
        "62ea43763461da5143769d101709c0f5dfa19b1407fc345c0b2070fc183bc7b6",
      "source" => "Rust_1.98.0_admitted_archive",
      "purpose" => "direct_compiler_linker_and_test_harness_inputs"
    }
  ].freeze
  TOOLCHAIN_NOTICE_FILES = [
    {
      "path" => ".tools/rust-1.98.0/share/doc/clippy/LICENSE-APACHE",
      "bytes" => 10_848,
      "sha256" =>
        "d8b56cd45661bfc7ccf4ce5722388cab275f9dabb9e471c922cc80e36bbf9caa"
    },
    {
      "path" => ".tools/rust-1.98.0/share/doc/clippy/LICENSE-MIT",
      "bytes" => 1_081,
      "sha256" =>
        "8d07f0c9c9966be0aaec4196d7863b56ade114e9714dbc31ebba576c0446d2fc"
    },
    {
      "path" => ".tools/rust-1.98.0/share/doc/rust/COPYRIGHT-library.html",
      "bytes" => 1_512_520,
      "sha256" =>
        "68129500b616d5838629e68f55ff3aed5e096dacf60ce9eb41bbe599a563afa6"
    },
    {
      "path" => ".tools/rust-1.98.0/share/doc/rust/COPYRIGHT.html",
      "bytes" => 15_380_909,
      "sha256" =>
        "5b0c93fc4e6d4b072eaa521b1762d1e746f4c368f65e81a0e5308e2772dac85e"
    }
  ].freeze
  RUST_SOURCE_MEMBERS = [
    {
      "path" => "Cargo.toml",
      "bytes" => 3_039,
      "sha256" =>
        "d77ef539b48dad3cba76b8d17badf7b5c7ebdbd6ca2b42e52b206e9d03c9fe39"
    },
    {
      "path" => "Cargo.lock",
      "bytes" => 158_714,
      "sha256" =>
        "5bbfba572a048bae0e33baa6686b8042da328607ba1a057b82d6236ef87ec09b"
    },
    {
      "path" => "compiler/rustc/Cargo.toml",
      "bytes" => 1_559,
      "sha256" =>
        "c22846585c8894afc754aa954ccada979cb9a101180a94d41b08388bbab05f7d"
    },
    {
      "path" => "compiler/rustc_driver/Cargo.toml",
      "bytes" => 341,
      "sha256" =>
        "0c96042c5217436d66af922d8fdf4d468159f22638c9199659f32ae8b8b1aab1"
    },
    {
      "path" => "compiler/rustc_driver_impl/Cargo.toml",
      "bytes" => 2_318,
      "sha256" =>
        "fa4925af7b47658ceaa8524348649731374be1a54e72a204cc0d134ca5c4a275"
    },
    {
      "path" => "src/tools/clippy/Cargo.toml",
      "bytes" => 1_986,
      "sha256" =>
        "17019be2bc8ac2a0c2920ff382222a6520f1775167a74ab2a986cbae4372b023"
    },
    {
      "path" => "library/Cargo.lock",
      "bytes" => 9_834,
      "sha256" =>
        "d1c5dbdf53bfebd7de60f26a171819db3b28ebfd75f3fa99c3286893a5a7b7a6"
    },
    {
      "path" => "library/sysroot/Cargo.toml",
      "bytes" => 1_132,
      "sha256" =>
        "a741ab496665cbe08f49ba759d6049d80a15b1eec1cce4eb3b48eb26e639bd5a"
    },
    {
      "path" => "library/std/Cargo.toml",
      "bytes" => 5_587,
      "sha256" =>
        "ff5272b18cb16a9e67256a1045dc35d9d08ae38916a218f684a2ae2f4360f078"
    },
    {
      "path" => "src/tools/rust-analyzer/Cargo.lock",
      "bytes" => 92_178,
      "sha256" =>
        "fad2ba1bf5035457b33fa83cac5a8edad65e8caa7d0e22ca1f0ba3cfdf7b6404"
    },
    {
      "path" => "LICENSE-APACHE",
      "bytes" => 9_723,
      "sha256" =>
        "62c7a1e35f56406896d7aa7ca52d0cc0d272ac022b5d2796e7d6905db8a3636a"
    },
    {
      "path" => "LICENSE-MIT",
      "bytes" => 1_068,
      "sha256" =>
        "b71bd43a069ca0641a9ecfe585ca7b3c53b5cc1608f8b68321168698e28b5ea1"
    },
    {
      "path" => "COPYRIGHT",
      "bytes" => 1_571,
      "sha256" =>
        "172020dbfd5b53a226dfde77616190a48dcff519b0bc0e6deb91a8450782c4af"
    },
    {
      "path" => "src/etc/third-party/COPYING3",
      "bytes" => 35_147,
      "sha256" =>
        "8ceb4b9ee5adedde47b31e975c1d90c73ad27b6b165a1dcd80c7c545eb65b903"
    },
    {
      "path" => "src/etc/third-party/COPYING.RUNTIME",
      "bytes" => 3_323,
      "sha256" =>
        "28e85c5aa4af9b4f1dfe6b4817aa3eefb3eaaee7fd735045016f29ccf50276a1"
    },
    {
      "path" => "license-metadata.json",
      "bytes" => 9_198,
      "sha256" =>
        "7bed295fb8d5ddc54ef9e7c795b18207d8da747513ae83fce9748e840200b40c"
    },
    {
      "path" => "src/llvm-project/llvm/LICENSE.TXT",
      "bytes" => 15_141,
      "sha256" =>
        "8d85c1057d742e597985c7d4e6320b015a9139385cff4cbae06ffc0ebe89afee"
    },
    {
      "path" => "src/llvm-project/lld/LICENSE.TXT",
      "bytes" => 15_138,
      "sha256" =>
        "f7891568956e34643eb6a0db1462db30820d40d7266e2a78063f2fe233ece5a0"
    }
  ].freeze
  RUST_SOURCE_SELECTED_TOOLS = %w[
    clippy-driver
    ld64.lld
    libLLVM.dylib
    librustc_driver
    rustc
    aarch64-apple-darwin-sysroot
  ].freeze
  RUST_LICENSE_ELECTIONS = {
    "(MIT OR Apache-2.0) AND Unicode-3.0" =>
      %w[MIT Unicode-3.0],
    "0BSD OR MIT OR Apache-2.0" => %w[MIT],
    "Apache-2.0" => %w[Apache-2.0],
    "Apache-2.0 / MIT" => %w[Apache-2.0],
    "Apache-2.0 OR BSL-1.0" => %w[Apache-2.0],
    "Apache-2.0 OR GPL-2.0-only" => %w[Apache-2.0],
    "Apache-2.0 OR MIT" => %w[Apache-2.0],
    "Apache-2.0 WITH LLVM-exception" =>
      %w[Apache-2.0 LLVM-exception],
    "Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT" =>
      %w[Apache-2.0],
    "Apache-2.0/MIT" => %w[Apache-2.0],
    "BSD-2-Clause" => %w[BSD-2-Clause],
    "BSD-2-Clause OR Apache-2.0 OR MIT" => %w[Apache-2.0],
    "CC0-1.0 OR Apache-2.0 OR Apache-2.0 WITH LLVM-exception" =>
      %w[Apache-2.0],
    "CC0-1.0 OR MIT-0 OR Apache-2.0" => %w[Apache-2.0],
    "ISC" => %w[ISC],
    "MIT" => %w[MIT],
    "MIT OR Apache-2.0" => %w[MIT],
    "MIT OR Apache-2.0 OR LGPL-2.1-or-later" => %w[MIT],
    "MIT OR Apache-2.0 OR Zlib" => %w[MIT],
    "MIT OR Zlib OR Apache-2.0" => %w[MIT],
    "MIT/Apache-2.0" => %w[MIT],
    "MPL-2.0" => %w[MPL-2.0],
    "Unicode-3.0" => %w[Unicode-3.0],
    "Unlicense OR MIT" => %w[MIT],
    "Unlicense/MIT" => %w[MIT],
    "Zlib" => %w[Zlib],
    "Zlib OR Apache-2.0 OR MIT" => %w[Apache-2.0],
    "Apache-2.0 WITH LLVM-exception AND (Apache-2.0 OR MIT)" =>
      %w[Apache-2.0 LLVM-exception],
    "Apache-2.0 WITH LLVM-exception AND NCSA" =>
      %w[Apache-2.0 LLVM-exception NCSA],
    "BSD-2-Clause AND (Apache-2.0 OR MIT)" =>
      %w[Apache-2.0 BSD-2-Clause]
  }.freeze
  RUST_REGISTRY_SOURCE =
    "registry+https://github.com/rust-lang/crates.io-index"
  RUST_REGISTRY_ROOTS = {
    "compiler_and_clippy" => "vendor",
    "sysroot" => "library/vendor"
  }.freeze
  RUST_NOTICE_ALLOWED_EXPRESSIONS = [
    "(Apache-2.0 OR MIT) AND BSD-3-Clause",
    "(MIT OR Apache-2.0) AND Unicode-3.0",
    "(MIT OR Apache-2.0) AND Unicode-DFS-2016",
    "0BSD",
    "0BSD OR MIT OR Apache-2.0",
    "Apache-2.0",
    "Apache-2.0 / MIT",
    "Apache-2.0 AND ISC",
    "Apache-2.0 OR BSL-1.0",
    "Apache-2.0 OR CC-BY-SA-4.0 OR MIT",
    "Apache-2.0 OR GPL-2.0-only",
    "Apache-2.0 OR ISC OR MIT",
    "Apache-2.0 OR MIT",
    "Apache-2.0 WITH LLVM-exception",
    "Apache-2.0 WITH LLVM-exception AND (Apache-2.0 OR MIT)",
    "Apache-2.0 WITH LLVM-exception AND NCSA",
    "Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT",
    "Apache-2.0/MIT",
    "BSD-2-Clause",
    "BSD-2-Clause AND (Apache-2.0 OR MIT)",
    "BSD-2-Clause OR Apache-2.0 OR MIT",
    "BSD-3-Clause",
    "BSD-3-Clause/MIT",
    "CC-BY-4.0 AND MIT",
    "CC0-1.0",
    "CC0-1.0 OR Apache-2.0 OR Apache-2.0 WITH LLVM-exception",
    "CC0-1.0 OR MIT-0 OR Apache-2.0",
    "CDDL-1.0",
    "GCC-exception-3.1",
    "GPL-2.0-only",
    "GPL-3.0",
    "GPL-3.0-or-later",
    "ISC",
    "MIT",
    "MIT / Apache-2.0",
    "MIT OR Apache-2.0",
    "MIT OR Apache-2.0 OR BSD-1-Clause",
    "MIT OR Apache-2.0 OR LGPL-2.1-or-later",
    "MIT OR Apache-2.0 OR Zlib",
    "MIT OR Zlib OR Apache-2.0",
    "MIT/Apache-2.0",
    "MPL-2.0",
    "MPL-2.0+",
    "OFL-1.1",
    "Unicode-3.0",
    "Unlicense OR MIT",
    "Unlicense/MIT",
    "Zlib",
    "Zlib OR Apache-2.0 OR MIT"
  ].freeze
  SPDX_LICENSE_FILES = [
    {
      "id" => "Apache-2.0",
      "kind" => "license",
      "path" => "src/Apache-2.0.xml",
      "bytes" => 14_396,
      "git_blob" => "765bb70b5afc9b30bfcc8f9f0c58c6106b4d7101",
      "sha256" =>
        "57850edd97cb7a3d1df0684b4e36dcfb8738e2514cfd868e5fa930b4fa52a0e2"
    },
    {
      "id" => "BSD-2-Clause",
      "kind" => "license",
      "path" => "src/BSD-2-Clause.xml",
      "bytes" => 2_265,
      "git_blob" => "b8a0db67d28088363a619ce7749b655f86b5a876",
      "sha256" =>
        "7cd71e9f918b24003a6f7528577025e41bc770d2835e3b93c6192c124d2b826f"
    },
    {
      "id" => "ISC",
      "kind" => "license",
      "path" => "src/ISC.xml",
      "bytes" => 1_695,
      "git_blob" => "6ecc37c9d8d4c2839a33fedae9eda7bf4e5fc90b",
      "sha256" =>
        "375eb99572f487240dad9f36a243151e23f6021e4ce668d364eb73406dde579c"
    },
    {
      "id" => "MIT",
      "kind" => "license",
      "path" => "src/MIT.xml",
      "bytes" => 2_680,
      "git_blob" => "5dc73b3949af9dc6af055a16c119f324fe891ea4",
      "sha256" =>
        "9d646d5c8d55ff45967a7ebb2cc7f075560f23fb1462ee1cd58616460b6cc18f"
    },
    {
      "id" => "MPL-2.0",
      "kind" => "license",
      "path" => "src/MPL-2.0.xml",
      "bytes" => 25_585,
      "git_blob" => "254ba7368378065884ae25cbfc294945e8960213",
      "sha256" =>
        "aa68201ebf2c48ea366456310cee9e96853c2dd86861c0f9193dffdf10f41968"
    },
    {
      "id" => "NCSA",
      "kind" => "license",
      "path" => "src/NCSA.xml",
      "bytes" => 2_849,
      "git_blob" => "2981375cb61f26efdf8982f6ca41fec3a18c73b4",
      "sha256" =>
        "9e28d2f5255918341fd702218d3fac132d2ce213d7de5a5fdd21c71d12723a14"
    },
    {
      "id" => "GPL-3.0-or-later",
      "kind" => "license",
      "path" => "src/GPL-3.0-or-later.xml",
      "bytes" => 44_795,
      "git_blob" => "9a06954483076d9e1fb2da584ee1c848dc250187",
      "sha256" =>
        "3efff8db39da65e1f4d12429081abc86d106a40ad4079a466bba23f855402a30"
    },
    {
      "id" => "Unicode-3.0",
      "kind" => "license",
      "path" => "src/Unicode-3.0.xml",
      "bytes" => 3_225,
      "git_blob" => "5a8189df36a681c2ef005e7d079cbef06ac8772a",
      "sha256" =>
        "5f863aa9350f9c2f49ea455b19327b407f4d1f5ec822f6d29b9c5231043039ae"
    },
    {
      "id" => "Zlib",
      "kind" => "license",
      "path" => "src/Zlib.xml",
      "bytes" => 1_706,
      "git_blob" => "8e001be8b6f56b2b56eb76f256f12db6f9cc2cde",
      "sha256" =>
        "733fa86f0080acfd4f4b52fa09c88495e92a3e1e106e07bf0dad124ff1e027d6"
    },
    {
      "id" => "LLVM-exception",
      "kind" => "exception",
      "path" => "src/exceptions/LLVM-exception.xml",
      "bytes" => 1_654,
      "git_blob" => "da62a12780acaebc081ae01a490c571ac83b9031",
      "sha256" =>
        "27768e13fd5b9fda8975fef14fa186df2b91a72ed548722293c7782f8313b583"
    },
    {
      "id" => "GCC-exception-3.1",
      "kind" => "exception",
      "path" => "src/exceptions/GCC-exception-3.1.xml",
      "bytes" => 4_947,
      "git_blob" => "c192fe8196b19ba37ea9349973c3617b0f04ffaa",
      "sha256" =>
        "057d5f7810fd10b7619db9d3d9e0571623752ba27bb65812539540dee79ad6c9"
    }
  ].freeze
  SPDX_REJECTED_LICENSE_FILES = [
    {
      "id" => "BSD-4-Clause-UC",
      "kind" => "license",
      "path" => "src/BSD-4-Clause-UC.xml",
      "bytes" => 3_160,
      "git_blob" => "68c0d1fd11df0927e350a0f675809220dfb75ef0",
      "sha256" =>
        "ac320e064c15cbbd5b11cb4f068a3b8fe10d155ac3777efd8dd98dfb9de40b40"
    },
    {
      "id" => "curl",
      "kind" => "license",
      "path" => "src/curl.xml",
      "bytes" => 1_664,
      "git_blob" => "f9f37245461bbdb22c7e4776bc7fd9bff6055d62",
      "sha256" =>
        "383bad4d56cc6107393287d09bd1a5478d470e99bec5ba073266cf59a733c62d"
    }
  ].freeze
  RUST_ACTIVE_LOCK_ROOTS = %w[
    rustc-main
    rustc_driver
    rustc_driver_impl
    clippy
  ].freeze
  RUST_REVIEWED_INACTIVE_PACKAGES = [
    {
      "name" => "capstone",
      "version" => "0.14.0",
      "source" => RUST_REGISTRY_SOURCE,
      "checksum" =>
        "f442ae0f2f3f1b923334b4a5386c95c69c1cfa072bafa23d6fae6d9682eb1dd4"
    },
    {
      "name" => "capstone-sys",
      "version" => "0.18.0",
      "source" => RUST_REGISTRY_SOURCE,
      "checksum" =>
        "a4e8087cab6731295f5a2a2bd82989ba4f41d3a428aab2e7c98d8f4db38aac05"
    },
    {
      "name" => "curl-sys",
      "version" => "0.4.87+curl-8.19.0",
      "source" => RUST_REGISTRY_SOURCE,
      "checksum" =>
        "61a460380f0ef783703dcbe909107f39c162adeac050d73c850055118b5b6327"
    },
    {
      "name" => "libgit2-sys",
      "version" => "0.18.2+1.9.1",
      "source" => RUST_REGISTRY_SOURCE,
      "checksum" =>
        "1c42fe03df2bd3c53a3a9c7317ad91d80c81cd1fb0caec8d7cc4cd2bfa10c222"
    },
    {
      "name" => "lzma-sys",
      "version" => "0.1.20",
      "source" => RUST_REGISTRY_SOURCE,
      "checksum" =>
        "5fda04ab3764e6cde78b9974eec4f779acaba7c4e84b36eca3cf77c581b85d27"
    }
  ].freeze
  RUST_REVIEWED_LEGAL_FILE_DISPOSITIONS = [
    {
      "path" => "vendor/capstone-0.14.0/THIRD_PARTY.txt",
      "bytes" => 1_752,
      "sha256" =>
        "c4489e73a9f2ec47bbb76ea770480e77c4446cfb801ae6c739bca91ae4ff3656",
      "rights" => "BSD-3-Clause",
      "rights_status" => "OSI_APPROVED",
      "reachability" => "UNREACHABLE_FROM_SELECTED_RUSTC_CLIPPY_LOCK_GRAPH",
      "disposition" => "UNSELECTED_CAPSTONE_THIRD_PARTY_LEGAL_EVIDENCE_ONLY"
    },
    {
      "path" =>
        "vendor/capstone-sys-0.18.0/capstone/CREDITS.TXT",
      "bytes" => 3_144,
      "sha256" =>
        "b4baaceb3ad09b94b0925c5bab1238562f8fc202343141e1e0618db51d21a535",
      "rights" => "ATTRIBUTION_PROVENANCE_NOT_LICENSE_GRANT",
      "rights_status" => "NOT_APPLICABLE",
      "reachability" => "UNREACHABLE_FROM_SELECTED_RUSTC_CLIPPY_LOCK_GRAPH",
      "disposition" => "UNSELECTED_CAPSTONE_CREDITS_EVIDENCE_ONLY"
    },
    {
      "path" =>
        "vendor/capstone-sys-0.18.0/capstone/bindings/vb6/" \
          "Apache_2.0_License.txt",
      "bytes" => 11_560,
      "sha256" =>
        "3ddf9be5c28fe27dad143a5dc76eea25222ad1dd68934a047064e56ed2fa40c5",
      "rights" => "Apache-2.0",
      "rights_status" => "OSI_APPROVED",
      "reachability" => "UNREACHABLE_FROM_SELECTED_RUSTC_CLIPPY_LOCK_GRAPH",
      "disposition" => "UNSELECTED_VB6_BINDING_LEGAL_EVIDENCE_ONLY"
    },
    {
      "path" =>
        "vendor/curl-sys-0.4.87+curl-8.19.0/curl/LICENSES/" \
          "BSD-4-Clause-UC.txt",
      "bytes" => 1_771,
      "sha256" =>
        "c82a5eb55679a3fd483d992c2428e66ee4b9b05b5b78b4ac916692368955b526",
      "rights" => "BSD-4-Clause-UC",
      "rights_status" => "SPDX_NOT_OSI_APPROVED",
      "reachability" => "UNREACHABLE_FROM_SELECTED_RUSTC_CLIPPY_LOCK_GRAPH",
      "disposition" => "NON_OSI_LICENSE_TEXT_REJECTED_FROM_SELECTED_SOURCE"
    },
    {
      "path" =>
        "vendor/curl-sys-0.4.87+curl-8.19.0/curl/LICENSES/ISC.txt",
      "bytes" => 730,
      "sha256" =>
        "2a9993525c6c65ac944dfea5fbf24a093d61cfaf69039cab1ff471c6aed821cb",
      "rights" => "ISC",
      "rights_status" => "OSI_APPROVED",
      "reachability" => "UNREACHABLE_FROM_SELECTED_RUSTC_CLIPPY_LOCK_GRAPH",
      "disposition" => "UNSELECTED_CURL_LEGAL_EVIDENCE_ONLY"
    },
    {
      "path" =>
        "vendor/curl-sys-0.4.87+curl-8.19.0/curl/LICENSES/curl.txt",
      "bytes" => 1_075,
      "sha256" =>
        "8c93cc9b95bc7d8e37c87fe3645a21d88871e791ef2fec43317f30b649078525",
      "rights" => "curl",
      "rights_status" => "SPDX_NOT_OSI_APPROVED",
      "reachability" => "UNREACHABLE_FROM_SELECTED_RUSTC_CLIPPY_LOCK_GRAPH",
      "disposition" => "NON_OSI_BUNDLED_SOURCE_REJECTED_FROM_SELECTED_SOURCE"
    },
    {
      "path" =>
        "vendor/libgit2-sys-0.18.2+1.9.1/libgit2/git.git-authors",
      "bytes" => 3_101,
      "sha256" =>
        "807ee76d5d1f87f87bb4deff8196b7854530521ebe52bde5d52b9e2bb82a75e4",
      "rights" => "RELICENSING_PROVENANCE_NOT_LICENSE_GRANT",
      "rights_status" => "NOT_APPLICABLE",
      "reachability" => "UNREACHABLE_FROM_SELECTED_RUSTC_CLIPPY_LOCK_GRAPH",
      "disposition" => "UNSELECTED_PROVENANCE_EVIDENCE_NOT_USED_AS_RIGHTS_GRANT"
    },
    {
      "path" =>
        "vendor/lzma-sys-0.1.20/xz-5.2/PACKAGERS",
      "bytes" => 8_595,
      "sha256" =>
        "8ab0db1c1bf19383b6fd4e7f3fc1a627f7e4d44119fb019469644131df99c0e2",
      "rights" => "GPL-2.0-or-later_AND_PUBLIC_DOMAIN_GUIDANCE",
      "rights_status" => "OSI_APPROVED_AND_PUBLIC_DOMAIN",
      "reachability" => "UNREACHABLE_FROM_SELECTED_RUSTC_CLIPPY_LOCK_GRAPH",
      "disposition" => "UNSELECTED_XZ_PACKAGING_LEGAL_GUIDANCE_ONLY"
    },
    {
      "path" =>
        "vendor/lzma-sys-0.1.20/xz-5.2/THANKS",
      "bytes" => 2_673,
      "sha256" =>
        "bcb2f3d036e823232e43706850e07bf8a493c49798354c4c97b2f2b15bf64a68",
      "rights" => "ATTRIBUTION_PROVENANCE_NOT_LICENSE_GRANT",
      "rights_status" => "NOT_APPLICABLE",
      "reachability" => "UNREACHABLE_FROM_SELECTED_RUSTC_CLIPPY_LOCK_GRAPH",
      "disposition" => "UNSELECTED_XZ_ATTRIBUTION_EVIDENCE_ONLY"
    }
  ].freeze
  RUST_UNSELECTED_HELPERS = [
    {
      "path" => ".tools/rust-1.98.0/libexec/rust-analyzer-proc-macro-srv",
      "bytes" => 1_463_088,
      "sha256" =>
        "6dc28cb7d8bccc8af3047f2f174e750c97a2c6ca966fa23ab93e266743ddc054",
      "selected" => false,
      "executed" => false
    }
  ].freeze
  EXPECTED_GENERATED_FILES = [
    {path: "libaead.rlib", bytes: 39_600, sha256: "590834f72fa8d47119ef85ddc1a489cf58d8f390d507535921b51c51600aaa40"},
    {path: "libblake2.rlib", bytes: 655_192, sha256: "63dc90deefce62d3217201f387c37deccd5d8bc86bd9cf48dbe65ab923094bc4"},
    {path: "libblock_buffer.rlib", bytes: 55_952, sha256: "ac7afde3eb2b52d4678091c8b6d0119ec2a186730ae6c2cdb91f959a7dd676c2"},
    {path: "libcfg_if.rlib", bytes: 9_224, sha256: "ad67f5aa835ee3281db1e72d30285ca73b4a19f02f86279d467adf78f1822345"},
    {path: "libchacha20.rlib", bytes: 97_904, sha256: "821f431e9275438e34fe3721f039a0ad2827e60ea780211e1e1e75c8eeccb4b4"},
    {path: "libchacha20poly1305.rlib", bytes: 44_720, sha256: "2d5d4621584fc5e4918aadd9a0307711e69571ddf7fdfb2dbaf9f17af8ea7ef6"},
    {path: "libcipher.rlib", bytes: 205_920, sha256: "6e7ed7025c1c1e71aece8c0ad5b7d4245e136ecb76b497bff68ef766e026185c"},
    {path: "libcrypto_common.rlib", bytes: 32_256, sha256: "9ce3c8f8ca69e4eff32588595a2540f26fa5e200375088262f0bb00c152a1fa8"},
    {path: "libcurve25519_dalek.rlib", bytes: 1_074_744, sha256: "529f4dcfbb4877007b00c24e4bff40fd8ca60eced75e6fac422e5fd3e0dff63c"},
    {path: "libdigest.rlib", bytes: 194_816, sha256: "4462be62319d79a7b9a46b0150f415f7c1268c053de7a99b605d47be34a7e9ab"},
    {path: "libgeneric_array.rlib", bytes: 814_520, sha256: "7f71944828b65e36703f79bc889c7e19724490dcf360866328e7dd38f31a24a1"},
    {path: "libinout.rlib", bytes: 73_464, sha256: "acef84a126a52ca42061f7c36abf2001ce322b2d3e13c06b2376537f82bedf95"},
    {path: "libopaque_debug.rlib", bytes: 9_360, sha256: "d53c3cd55411fbd15d20b9d129d13216c76ece8f9f65d249ca2db1bde2bc5294"},
    {path: "libpoly1305.rlib", bytes: 122_424, sha256: "0eaa949116b701309586347770f8dbe6057693a1a23cdbbbb6c6891b9d1ccc16"},
    {path: "libsnow.rlib", bytes: 1_521_320, sha256: "7bf043079a605c4a0decd8b706d3366fd8392e18c840e7df6c60cba2cb59b6fe"},
    {path: "libsubtle.rlib", bytes: 125_984, sha256: "dfaceb5937fd6b192e8bf1da53095173c13db45708a00d9b728e7854903e8ae2"},
    {path: "libtypenum.rlib", bytes: 2_171_000, sha256: "39d461759b4b1d0fa53ed113b69c0ae3b4acb82d7bf641ef8d675156a9affa8f"},
    {path: "libuniversal_hash.rlib", bytes: 28_152, sha256: "b90c28f5857396a216b346f63e58de58297a75d5a3c93b4a2926367bd590f7f7"},
    {path: "libzeroize.rlib", bytes: 514_224, sha256: "5ababc0d4265a9e66970cdbb2ae2405e9011bba1f7a6077d74b7bab6449a7c77"},
    {path: "p13-noise-probe-clippy", bytes: 0, sha256: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},
    {path: "p13-noise-probe-tests", bytes: 1_698_544, sha256: "9f3226e540c569f45aa1a0aa67feed3ab508b7cfefc404c935afc1305ab5f160"}
  ].map { |record| record.transform_keys(&:to_s).freeze }.freeze
  REJECTED_RUNTIME_TOOL_HASHES = {
    "cargo" => "1de2e84c15443b70444eecfa959ff9099dd8c1a5606b6d9ef5bc0ea9c25bc7f9"
  }.freeze

  REQUIRED_DISTRIBUTION_PATHS = %w[
    docs/adr/ADR-0023-compile-only-transport-source-projection.md
    docs/adr/ADR-0024-projected-origin-notice-closure.md
    docs/adr/ADR-0025-p13-source-evidence-closeout-boundary.md
    docs/adr/ADR-0028-exact-rust-toolchain-source-closure.md
    docs/adr/ADR-0022-noise-snow-transport-portfolio.md
    docs/adr/ADR-0032-bounded-p13-archive-and-copied-source-closure.md
    docs/adr/ADR-0033-exact-path-source-rights-and-governance-closure.md
    docs/adr/ADR-0034-bounded-source-review-closeout.md
    docs/adr/ADR-0035-terminal-validator-and-evidence-closeout.md
    docs/adr/ADR-0036-final-p13-source-and-governance-closeout.md
    docs/clean-room/USER-DECISIONS.md
    docs/evidence/P13-NOISE-SOURCES.yaml
    docs/evidence/P13-SOURCE-ACQUISITION.md
    docs/evidence/P13-NOISE-TRANSPORT.md
    docs/evidence/REQUIREMENTS-MANIFEST.yaml
    docs/evidence/REQUIREMENTS-TRACEABILITY.md
    tools/p13-source-fetch
    tools/p13-source-fetch.rb
    tools/test-p13-source-fetch
    tools/test-p13-source-fetch.rb
    tools/p13-noise-evidence
    tools/p13-noise-evidence.rb
    tools/p13-rustc-driver
    tools/p13-rustc-driver.rb
    tools/p13-noise-probe/.cargo/config.toml
    tools/p13-noise-probe/Cargo.lock
    tools/p13-noise-probe/Cargo.toml
    tools/p13-noise-probe/projected/poly1305-soft.rs
    tools/p13-noise-probe/src/lib.rs
    tools/test-p13-noise-evidence
    tools/test-p13-noise-evidence.rb
    tools/test-p13-rustc-driver
    tools/test-p13-rustc-driver.rb
  ].freeze

  module_function

  def run(arguments)
    arguments = arguments.dup
    skip_runtime = arguments.delete("--skip-runtime")
    raise Failure, "usage: tools/p13-noise-evidence [--skip-runtime]" unless
      arguments.empty?

    validate(runtime: !skip_runtime)
    puts "P13_NOISE_SOURCE_EVIDENCE_PASS"
    puts "P13_NOISE_PROJECTION_PASS"
    puts "P13_NOISE_ADVISORY_PASS"
    if skip_runtime
      puts "P13_NOISE_RUNTIME_SKIPPED"
    else
      puts "P13_NOISE_PROBE_TEST_PASS"
      puts "P13_NOISE_PROBE_CLIPPY_PASS"
    end
    puts "P13_NOISE_CAPABILITY_ONLY_PASS"
    true
  rescue Failure => error
    warn "P13_NOISE_EVIDENCE_FAIL: #{error.message}"
    exit 1
  end

  def validate(runtime:)
    validate_user_decision_traceability
    evidence = read_yaml(File.join(ROOT, EVIDENCE))
    validate_evidence(evidence)
    validate_acquisition(evidence)
    validate_toolchain_source_closure(evidence)
    materials = read_yaml(File.join(ROOT, MATERIALS))
    validate_materials(materials)
    validate_material_closure_binding(materials, evidence)
    validate_distribution(read_yaml(File.join(ROOT, DISTRIBUTION)))
    validate_probe_files(evidence)
    validate_lock(evidence)
    validate_direct_compile_contract(evidence)
    validate_static_target_graphs(evidence)
    paths = source_paths(evidence)
    validate_noise_specification(evidence, paths)
    validated_sources = validate_source_closure(evidence, paths)
    validate_cacophony_origin(evidence, materials, validated_sources, paths)
    validate_source_origin_review(evidence, validated_sources)
    validate_advisories(evidence, paths)
    validate_runtime(evidence, validated_sources) if runtime
    true
  end

  def validate_user_decision_traceability
    validate_user_decision_traceability_bytes(
      File.binread(File.join(ROOT, USER_DECISIONS)),
      File.binread(File.join(ROOT, REQUIREMENTS_TRACEABILITY)),
      read_yaml(File.join(ROOT, REQUIREMENTS_MANIFEST))
    )
  rescue Errno::ENOENT => error
    raise Failure, "P13 governance trace input missing: #{error.message}"
  end

  def validate_user_decision_traceability_bytes(
    decision_bytes,
    traceability_bytes,
    manifest
  )
    decisions = user_requirement_ids(
      decision_bytes,
      expected_columns: 5,
      context: "P13 user decision ledger"
    )
    traced = user_requirement_ids(
      traceability_bytes,
      expected_columns: 7,
      context: "P13 requirement traceability"
    )
    manifest_ids = manifest.fetch("required_ids").grep(/\AUSR-\d{3}\z/)
    expected = (1..decisions.length).map do |number|
      format("USR-%03d", number)
    end
    raise Failure, "P13 user decision IDs are not contiguous or omit USR-039" unless
      decisions == expected &&
      decisions.include?("USR-039")
    raise Failure, "P13 user decision traceability set differs" unless
      traced == decisions
    raise Failure, "P13 user decision manifest set differs" unless
      manifest_ids == decisions
    true
  rescue KeyError => error
    raise Failure, "P13 requirement manifest field missing: #{error.key}"
  end

  def user_requirement_ids(bytes, expected_columns:, context:)
    ids = bytes.each_line.each_with_object([]) do |line, result|
      candidate_cell = user_requirement_candidate_cell(line)
      next unless candidate_cell&.match?(
        /\A(?:(?:`+|\*+|_+|~+|<code(?:[ \t][^>]*)?>)[ \t]*)*USR(?=[-_0-9])/i
      )

      columns = markdown_table_columns(line)
      first = columns&.first&.strip
      match = first&.match(/\A`(USR-\d{3})`\z/)
      raise Failure, "#{context} contains malformed ID row" unless match
      raise Failure, "#{context} contains malformed ID row" unless
        columns.length == expected_columns &&
        columns.all? { |column| !column.strip.empty? }
      result << match[1]
    end
    raise Failure, "#{context} contains duplicate IDs" unless
      ids.uniq.length == ids.length
    ids
  end

  def user_requirement_candidate_cell(line)
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

  def validate_evidence(evidence)
    raise Failure, "P13 Noise evidence semantic digest differs" unless
      semantic_digest(evidence) == EVIDENCE_SEMANTIC_SHA256

    raise Failure, "P13 Noise evidence phase differs" unless
      evidence.fetch("phase") == "P13"
    raise Failure, "P13 Noise candidate scope differs" unless
      evidence.fetch("status") ==
        "QUARANTINED_P13_CAPABILITY_CANDIDATE_PENDING_REVIEWS"
    scope = evidence.fetch("scope")
    raise Failure, "P13 Noise runtime admission overclaim" unless
      scope.fetch("runtime_admission") == "NOT_GRANTED" &&
      scope.fetch("product_dependency_admission") == "NOT_GRANTED" &&
      scope.fetch("packaging_admission") == "NOT_GRANTED"

    convergence = evidence.fetch("bounded_convergence")
    raise Failure, "P13 Noise convergence budget differs" unless
      convergence.fetch("pass") == 3 &&
      convergence.fetch("maximum_passes") == 3 &&
      convergence.fetch("selection_frozen") == true &&
      convergence.fetch("further_transport_comparison_permitted") == false

    selection = evidence.fetch("selection")
    raise Failure, "P13 Noise profile differs" unless
      selection.fetch("protocol_profile") == PROFILE
    raise Failure, "P13 Snow feature surface differs" unless
      selection.fetch("snow_default_features") == false &&
      selection.fetch("snow_features") == SNOW_FEATURES
    raise Failure, "P13 forced backend set differs" unless
      selection.fetch("forced_cfg") == [
        "chacha20_force_soft",
        "poly1305_force_soft",
        "curve25519_dalek_backend=\"serial\""
      ]

    review = evidence.fetch("review_state")
    expected_review = {
      "discovery" => "PENDING_INDEPENDENT_REVIEW",
      "license" => "PENDING_INDEPENDENT_REVIEW",
      "provenance" => "PENDING_INDEPENDENT_REVIEW",
      "quality_security" => "PENDING_INDEPENDENT_REVIEW",
      "defensive_adversarial" => "PENDING_INDEPENDENT_REVIEW"
    }
    raise Failure, "P13 source review state overclaims completion" unless
      review == expected_review

    expected_rejections = [
      "CPython_3.14.6",
      "OpenSSL_3.6.3",
      "controlled_CPython_OpenSSL_build",
      "Homebrew_CPython_OpenSSL_runtime",
      "every_projection_derived_from_that_portfolio"
    ]
    raise Failure, "permanent CPython/OpenSSL rejection differs" unless
      evidence.fetch("permanent_rejections") == expected_rejections
    true
  rescue KeyError => error
    raise Failure, "P13 Noise evidence field missing: #{error.key}"
  end

  def validate_acquisition(evidence)
    record = evidence.fetch("acquisition")
    recipe = verify_file(
      File.join(ROOT, record.fetch("recipe_path")),
      bytes: record.fetch("recipe_bytes"),
      sha256: record.fetch("recipe_sha256"),
      context: "P13 source acquisition recipe"
    )
    fetcher = verify_file(
      File.join(ROOT, record.fetch("fetch_tool_path")),
      bytes: record.fetch("fetch_tool_bytes"),
      sha256: record.fetch("fetch_tool_sha256"),
      context: "P13 source acquisition fetch tool"
    )
    wrapper = verify_file(
      File.join(ROOT, record.fetch("fetch_wrapper_path")),
      bytes: record.fetch("fetch_wrapper_bytes"),
      sha256: record.fetch("fetch_wrapper_sha256"),
      context: "P13 source acquisition wrapper"
    )
    tests = verify_file(
      File.join(ROOT, record.fetch("test_tool_path")),
      bytes: record.fetch("test_tool_bytes"),
      sha256: record.fetch("test_tool_sha256"),
      context: "P13 source acquisition tests"
    )
    test_wrapper = verify_file(
      File.join(ROOT, record.fetch("test_wrapper_path")),
      bytes: record.fetch("test_wrapper_bytes"),
      sha256: record.fetch("test_wrapper_sha256"),
      context: "P13 source acquisition test wrapper"
    )
    verify_file(
      record.fetch("ruby_path"),
      sha256: record.fetch("ruby_sha256"),
      context: "P13 source acquisition Ruby"
    )
    verify_file(
      record.fetch("git_path"),
      sha256: record.fetch("git_sha256"),
      context: "P13 source acquisition Git"
    )

    closure = evidence.fetch("closure")
    raise Failure, "P13 source acquisition contract differs" unless
      record.fetch("archive_url_template") ==
        closure.fetch("registry_archive_url_template") &&
      record.fetch("archive_count") ==
        closure.fetch("external_package_count") &&
      record.fetch("rust_source_artifact_count") == 2 &&
      record.fetch("maximum_fetch_bytes") == 268_435_456 &&
      record.fetch("allowed_https_hosts") ==
        %w[
          creativecommons.org
          static.crates.io
          static.rust-lang.org
        ] &&
      record.fetch("https_redirect_policy") == "REJECT" &&
      record.fetch("existing_destination_policy") ==
        "ACCEPT_ONLY_EXACT_SIZE_AND_SHA256" &&
      record.fetch("destination_creation_policy") ==
        "DESCRIPTOR_RELATIVE_ATOMIC_EXCLUSIVE_RENAME_NO_CLOBBER" &&
      record.fetch("crate_extraction_command") == "extract-crate" &&
      record.fetch("crate_extraction_policy") ==
        "SAFE_USTAR_EXACT_PATH_TYPE_MODE_AND_BYTES" &&
      record.fetch("extraction_publication_policy") ==
        "DESCRIPTOR_RELATIVE_ATOMIC_EXCLUSIVE_DIRECTORY_RENAME_NO_CLOBBER" &&
      record.fetch("cargo_marker_bytes") == 7 &&
      record.fetch("cargo_marker_sha256") ==
        Digest::SHA256.hexdigest("{\"v\":1}") &&
      record.fetch("real_archive_replay_count") ==
        closure.fetch("external_package_count") &&
      record.fetch("existing_cargo_extraction_comparison_count") == 22 &&
      record.fetch("git_object_policy") ==
        "EXACT_COMMIT_TREE_PATH_BLOB_WITH_GIT_NO_LAZY_FETCH" &&
      record.fetch("result") ==
        "VERSIONED_ACQUISITION_AND_OFFLINE_REPLAY_RECIPE_BOUND"

    required_markers = [
      closure.fetch("registry_archive_url_template"),
      evidence.fetch("noise_specification").fetch("canonical_url"),
      evidence.fetch("noise_specification").fetch("git_commit"),
      evidence.fetch("removed_cacophony_vector").fetch("canonical_url"),
      evidence.fetch("removed_cacophony_vector").fetch("commit"),
      evidence.fetch("typenum_origin_review").fetch("package_repository"),
      evidence.fetch("typenum_origin_review").fetch("package_commit"),
      evidence.fetch("typenum_origin_review").fetch("origin_repository"),
      evidence.fetch("typenum_origin_review").fetch("origin_commit"),
      evidence.fetch("generic_array_origin_review").fetch("origin_repository"),
      evidence.fetch("generic_array_origin_review").fetch("origin_commit"),
      evidence.fetch("toolchain_source_closure")
        .fetch("copied_source_origins")
        .fetch("pulldown_cmark_redwood")
        .fetch("origin").fetch("repository"),
      evidence.fetch("toolchain_source_closure")
        .fetch("copied_source_origins")
        .fetch("pulldown_cmark_redwood")
        .fetch("origin").fetch("commit"),
      evidence.fetch("toolchain_source_closure")
        .fetch("copied_source_origins")
        .fetch("pulldown_cmark_redwood")
        .fetch("author_permission").fetch("sha256"),
      evidence.fetch("toolchain_source_closure")
        .fetch("copied_source_origins")
        .fetch("pulldown_cmark_redwood")
        .fetch("author_permission").fetch("request_url"),
      evidence.fetch("toolchain_source_closure")
        .fetch("copied_source_origins")
        .fetch("tracing_subscriber_hyperium")
        .fetch("origin").fetch("repository"),
      evidence.fetch("toolchain_source_closure")
        .fetch("copied_source_origins")
        .fetch("tracing_subscriber_hyperium")
        .fetch("origin").fetch("commit"),
      evidence.fetch("advisory_review").fetch("commit"),
      evidence.fetch("advisory_review").fetch("authoritative_cc_by_url"),
      evidence.fetch("toolchain_source_closure")
        .fetch("channel_manifest").fetch("canonical_url"),
      evidence.fetch("toolchain_source_closure")
        .fetch("source_archive").fetch("canonical_url"),
      evidence.fetch("toolchain_source_closure")
        .fetch("source_archive").fetch("sha256"),
      "GIT_NO_LAZY_FETCH=1",
      "tools/p13-source-fetch",
      "extract-crate",
      "{\"v\":1}",
      "tools/test-p13-source-fetch"
    ]
    required_markers.each do |marker|
      require_include(recipe, marker, "P13 source acquisition recipe #{marker}")
    end
    require_include(fetcher, "Net::HTTP", "P13 source acquisition HTTPS client")
    require_include(fetcher, "Digest::SHA256", "P13 source acquisition digest")
    require_include(
      fetcher,
      "static.rust-lang.org",
      "P13 Rust source acquisition host"
    )
    require_include(
      fetcher,
      "MAX_FETCH_BYTES",
      "P13 source acquisition byte limit"
    )
    require_include(fetcher, ".cargo-ok", "P13 source acquisition Cargo marker")
    require_include(
      fetcher,
      "atomic_publish_directory",
      "P13 source acquisition exclusive directory publication"
    )
    require_include(
      tests,
      "test_real_ledger_crates_replay_exactly",
      "P13 source acquisition real archive replay"
    )
    require_include(wrapper, "--disable-gems", "P13 source acquisition wrapper")
    require_include(
      test_wrapper,
      "--disable-gems",
      "P13 source acquisition test wrapper"
    )
    true
  rescue KeyError => error
    raise Failure, "P13 source acquisition field missing: #{error.key}"
  end

  def validate_toolchain_source_closure(evidence, member_contents: nil)
    record = evidence.fetch("toolchain_source_closure")
    manifest = record.fetch("channel_manifest")
    archive = record.fetch("source_archive")
    extraction = record.fetch("extraction_tool")

    raise Failure, "P13 Rust channel manifest evidence differs" unless
      manifest == {
        "canonical_url" =>
          "https://static.rust-lang.org/dist/2026-08-20/" \
          "channel-rust-1.98.0.toml",
        "local_path" =>
          "/private/tmp/p13-rust-source/channel-rust-1.98.0.toml",
        "bytes" => 898_637,
        "sha256" =>
          "3f7d139b73bbbd0004ef6e58b430831c68cdad2b1f64ee2eb35d54c09199489a",
        "source_commit" => "88d9e12ae178fab0fb5cc050a94da85685d449ea"
      }
    raise Failure, "P13 Rust source archive evidence differs" unless
      archive == {
        "canonical_url" =>
          "https://static.rust-lang.org/dist/2026-08-20/" \
          "rustc-1.98.0-src.tar.xz",
        "local_path" =>
          "/private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz",
        "bytes" => 244_440_040,
        "sha256" =>
          "271fa73d8174f53d713c46a8310da7bf7cfdcfb8b7cfd1c2b74b84a83ae9fb1e",
        "archive_root" => "rustc-1.98.0-src",
        "transformations" => "exact_allowlisted_member_extraction_only",
        "redistributed" => false
      }
    raise Failure, "P13 Rust source extraction tool differs" unless
      extraction == {
        "path" => "/usr/bin/bsdtar",
        "dispatch_path" => "/usr/bin/tar",
        "dispatch_target" => "bsdtar",
        "version" => "bsdtar_3_5_3_libarchive_3_7_4",
        "sha256" =>
          "f96200d5be4a3f99cdbc88892a2e26f14d501d354c72b224472462cc67fa271d",
        "source_and_license_evidence" => "docs/evidence/P01-TOOLCHAIN.md",
        "purpose" => "offline_exact_allowlisted_source_member_extraction"
      }
    raise Failure, "P13 Rust source member inventory differs" unless
      record.fetch("selected_members") == RUST_SOURCE_MEMBERS
    raise Failure, "P13 Rust active source roots differ" unless
      record.fetch("active_roots") == {
        "rustc" => "compiler/rustc",
        "rustc_driver" => "compiler/rustc_driver",
        "rustc_driver_impl" => "compiler/rustc_driver_impl",
        "clippy_driver" => "src/tools/clippy",
        "sysroot" => "library/sysroot",
        "standard_library" => "library/std",
        "llvm" => "src/llvm-project/llvm",
        "lld" => "src/llvm-project/lld"
      }
    raise Failure, "P13 Rust source closure disposition differs" unless
      record.fetch("compiler_and_clippy_lock_package_count") == 660 &&
      record.fetch("compiler_and_clippy_path_package_count") == 125 &&
      record.fetch("compiler_and_clippy_registry_package_count") == 535 &&
      record.fetch("sysroot_lock_package_count") == 49 &&
      record.fetch("sysroot_path_package_count") == 19 &&
      record.fetch("sysroot_registry_package_count") == 30 &&
      record.fetch("compiler_and_clippy_notify_count") == 0 &&
      record.fetch("sysroot_notify_count") == 0 &&
      record.fetch("excluded_rust_analyzer_notify_count") == 1 &&
      record.fetch("complete_notice_sole_cc0_only_package") ==
        "notify-8.2.0" &&
      record.fetch("complete_library_notice_cc0_only_package_count") == 0 &&
      record.fetch("excluded_component") == "rust-analyzer" &&
      record.fetch("installed_notify_path_count") == 0 &&
      record.fetch("installed_unselected_helpers") ==
        RUST_UNSELECTED_HELPERS &&
      record.fetch("selected_tools") == RUST_SOURCE_SELECTED_TOOLS &&
      record.fetch("license_elections") == RUST_LICENSE_ELECTIONS &&
      record.fetch("excluded_registry_package") == {
        "component" => "rust-analyzer",
        "name" => "notify",
        "version" => "8.2.0",
        "source" => RUST_REGISTRY_SOURCE,
        "checksum" =>
          "4d3d07927151ff8575b7087f245456e549fea62edf0ec4e565a5ee50c8402bc3",
        "selected" => false,
        "installed" => false
      } &&
      record.fetch("license_result") ==
        "CAPABILITY_SOURCE_REVIEW_WITH_RESTRICTED_INTEL_FILE_REJECTED" &&
      record.fetch("unselected_cc0_software_admitted") == false

    manifest_path = ENV.fetch("P13_RUST_CHANNEL_MANIFEST", manifest.fetch("local_path"))
    archive_path = ENV.fetch("P13_RUST_SOURCE_ARCHIVE", archive.fetch("local_path"))
    manifest_bytes = verify_file(
      manifest_path,
      bytes: manifest.fetch("bytes"),
      sha256: manifest.fetch("sha256"),
      context: "P13 Rust channel manifest"
    )
    verify_large_file(
      extraction.fetch("path"),
      sha256: extraction.fetch("sha256"),
      context: "P13 Rust source extraction tool"
    )
    dispatch = File.lstat(extraction.fetch("dispatch_path"))
    raise Failure, "P13 Rust source extraction dispatch differs" unless
      dispatch.symlink? &&
      File.readlink(extraction.fetch("dispatch_path")) ==
        extraction.fetch("dispatch_target") &&
      File.realpath(extraction.fetch("dispatch_path")) ==
        extraction.fetch("path")
    require_include(
      manifest_bytes,
      archive.fetch("canonical_url"),
      "P13 Rust source archive URL"
    )
    require_include(
      manifest_bytes,
      "hash-sha256 = \"#{archive.fetch('sha256')}\"",
      "P13 Rust source archive hash"
    )
    require_include(
      manifest_bytes,
      manifest.fetch("source_commit"),
      "P13 Rust source commit"
    )

    with_verified_large_file(
      archive_path,
      bytes: archive.fetch("bytes"),
      sha256: archive.fetch("sha256"),
      context: "P13 Rust source archive"
    ) do |archive_handle|
      contents = member_contents || extract_rust_source_members(
        record,
        archive_handle
      )
      approved = validate_spdx_license_evidence(record)
      validate_rust_source_member_contents(
        record,
        contents,
        archive_handle: archive_handle,
        approved_license_ids: approved
      )
    end
    validate_toolchain_source_provenance(record)
    true
  rescue KeyError => error
    raise Failure, "P13 Rust source closure field missing: #{error.key}"
  end

  def extract_rust_source_members(record, archive_handle)
    extraction = record.fetch("extraction_tool")
    root = record.fetch("source_archive").fetch("archive_root")
    members = record.fetch("selected_members").map do |member|
      "#{root}/#{member.fetch('path')}"
    end
    relative_members = record.fetch("selected_members").map do |member|
      member.fetch("path")
    end
    preflight = rust_archive_verbose_entries(
      record,
      archive_handle,
      members: relative_members,
      context: "P13 Rust source members preflight"
    )
    validate_rust_archive_regular_preflight(
      preflight,
      relative_members,
      "P13 Rust source members"
    )
    result = nil
    Dir.mktmpdir("p13-rust-source-") do |directory|
      environment = {
        "COPYFILE_DISABLE" => "1",
        "LANG" => "C",
        "LC_ALL" => "C",
        "PATH" => "/usr/bin:/bin",
        "TZ" => "UTC"
      }
      stdout, stderr, status = capture3_bounded(
        environment,
        [
          extraction.fetch("path"),
          "-xJf",
          rust_archive_descriptor_path(archive_handle),
          "-C",
          directory,
          *members
        ],
        {
          archive_handle.fetch("io").fileno => archive_handle.fetch("io"),
          close_others: true,
          unsetenv_others: true
        },
        stdin_data: nil,
        stdout_limit: RUST_ARCHIVE_SILENT_OUTPUT_MAX_BYTES,
        stderr_limit: RUST_ARCHIVE_SILENT_OUTPUT_MAX_BYTES,
        context: "P13 Rust source extraction",
        prohibit_descendants: true
      )
      archive_handle.fetch("io").rewind
      validate_open_large_file_identity(
        archive_handle,
        "P13 Rust source archive"
      )
      raise Failure, "P13 Rust source extraction failed" unless
        status.success? && stdout.empty? && stderr.empty?

      expected = members.sort_by(&:b)
      actual = []
      extracted_bytes = 0
      Dir.glob(
        File.join(directory, "**", "*"),
        File::FNM_DOTMATCH
      ).sort_by(&:b).each do |path|
        next if [".", ".."].include?(File.basename(path))

        stat = File.lstat(path)
        raise Failure, "P13 Rust source extraction produced a symlink" if
          stat.symlink?
        next if stat.directory?
        raise Failure, "P13 Rust source extraction produced a non-file" unless
          stat.file? && stat.nlink == 1

        extracted_bytes = bounded_rust_extraction_bytes(
          extracted_bytes,
          stat.size,
          "P13 Rust source members"
        )
        actual << path.delete_prefix("#{directory}/")
      end
      raise Failure, "P13 Rust source extracted path set differs" unless
        actual == expected

      result = record.fetch("selected_members").to_h do |member|
        relative = member.fetch("path")
        [relative, File.binread(File.join(directory, root, relative))]
      end
    end
    result
  rescue Errno::ENOENT => error
    raise Failure, "P13 Rust source extraction input missing: #{error.class}"
  end

  def validate_rust_source_member_contents(
    record,
    contents,
    archive_handle: nil,
    approved_license_ids: nil,
    registry_entries: nil
  )
    expected_paths = record.fetch("selected_members").map { |item| item.fetch("path") }
    raise Failure, "P13 Rust source member content set differs" unless
      contents.keys.sort_by(&:b) == expected_paths.sort_by(&:b)
    record.fetch("selected_members").each do |member|
      bytes = contents.fetch(member.fetch("path"))
      raise Failure, "P13 Rust source member size differs: #{member.fetch('path')}" unless
        bytes.bytesize == member.fetch("bytes")
      raise Failure, "P13 Rust source member hash differs: #{member.fetch('path')}" unless
        Digest::SHA256.hexdigest(bytes) == member.fetch("sha256")
    end

    workspace = contents.fetch("Cargo.toml")
    require_exact_count(
      workspace,
      '"compiler/rustc",',
      1,
      "P13 Rust compiler workspace member"
    )
    require_exact_count(
      workspace,
      '"src/tools/clippy",',
      1,
      "P13 Clippy workspace member"
    )
    require_exclude(
      workspace,
      '"src/tools/rust-analyzer",',
      "P13 excluded rust-analyzer workspace member"
    )
    require_include(
      contents.fetch("compiler/rustc/Cargo.toml"),
      'name = "rustc-main"',
      "P13 rustc source root"
    )
    require_include(
      contents.fetch("compiler/rustc/Cargo.toml"),
      'rustc_driver = { path = "../rustc_driver" }',
      "P13 rustc driver dependency"
    )
    require_include(
      contents.fetch("compiler/rustc_driver/Cargo.toml"),
      'name = "rustc_driver"',
      "P13 rustc_driver source root"
    )
    require_include(
      contents.fetch("compiler/rustc_driver_impl/Cargo.toml"),
      'name = "rustc_driver_impl"',
      "P13 rustc_driver_impl source root"
    )
    require_include(
      contents.fetch("src/tools/clippy/Cargo.toml"),
      'name = "clippy-driver"',
      "P13 Clippy driver source root"
    )
    require_include(
      contents.fetch("library/sysroot/Cargo.toml"),
      'name = "sysroot"',
      "P13 sysroot source root"
    )
    require_include(
      contents.fetch("library/std/Cargo.toml"),
      'name = "std"',
      "P13 standard library source root"
    )

    compiler_packages = rust_lock_packages(
      contents.fetch("Cargo.lock"),
      "P13 compiler and Clippy lock"
    )
    sysroot_packages = rust_lock_packages(
      contents.fetch("library/Cargo.lock"),
      "P13 sysroot lock"
    )
    analyzer_packages = rust_lock_packages(
      contents.fetch("src/tools/rust-analyzer/Cargo.lock"),
      "P13 excluded rust-analyzer lock"
    )
    compiler_names = compiler_packages.map { |package| package.fetch("name") }
    sysroot_names = sysroot_packages.map { |package| package.fetch("name") }
    raise Failure, "P13 compiler and Clippy lock package count differs" unless
      compiler_names.length ==
        record.fetch("compiler_and_clippy_lock_package_count")
    raise Failure, "P13 sysroot lock package count differs" unless
      sysroot_names.length == record.fetch("sysroot_lock_package_count")
    %w[clippy rustc-main rustc_driver rustc_driver_impl].each do |name|
      raise Failure, "P13 selected compiler package is absent: #{name}" unless
        compiler_names.count(name) == 1
    end
    raise Failure, "P13 sysroot package is absent" unless
      sysroot_names.count("sysroot") == 1 && sysroot_names.count("std") == 1
    raise Failure, "P13 CC0 package reached compiler or Clippy lock" unless
      compiler_names.count("notify") ==
        record.fetch("compiler_and_clippy_notify_count")
    raise Failure, "P13 CC0 package reached sysroot lock" unless
      sysroot_names.count("notify") == record.fetch("sysroot_notify_count")
    validate_excluded_rust_analyzer_package(record, analyzer_packages)
    validate_rust_active_lock_graph(
      record,
      compiler_packages,
      sysroot_packages
    )

    copyright = contents.fetch("COPYRIGHT")
    require_include(
      copyright,
      "The Rust Project is dual-licensed under Apache 2.0 and MIT",
      "P13 Rust source root license"
    )
    %w[
      src/llvm-project/llvm/LICENSE.TXT
      src/llvm-project/lld/LICENSE.TXT
    ].each do |path|
      require_include(
        contents.fetch(path),
        "Apache License v2.0 with LLVM Exceptions",
        "P13 LLVM license root #{path}"
      )
    end
    require_include(
      contents.fetch("src/etc/third-party/COPYING3"),
      "GNU GENERAL PUBLIC LICENSE\n                       Version 3",
      "P13 GCC GPL-3.0-or-later legal text"
    )
    require_include(
      contents.fetch("src/etc/third-party/COPYING.RUNTIME"),
      "GCC RUNTIME LIBRARY EXCEPTION\n\nVersion 3.1",
      "P13 GCC Runtime Library Exception 3.1 legal text"
    )

    direct = read_yaml(File.join(ROOT, EVIDENCE))
      .fetch("runtime_isolation").fetch("direct_compile")
    notices = direct.fetch("toolchain_notice_files").to_h do |notice|
      [notice.fetch("path"), notice]
    end
    whole_notice = verify_file(
      File.join(
        ROOT,
        ".tools/rust-1.98.0/share/doc/rust/COPYRIGHT.html"
      ),
      **symbolize_file_identity(
        notices.fetch(".tools/rust-1.98.0/share/doc/rust/COPYRIGHT.html")
      ),
      context: "P13 complete Rust notice"
    )
    library_notice = verify_file(
      File.join(
        ROOT,
        ".tools/rust-1.98.0/share/doc/rust/COPYRIGHT-library.html"
      ),
      **symbolize_file_identity(
        notices.fetch(
          ".tools/rust-1.98.0/share/doc/rust/COPYRIGHT-library.html"
        )
      ),
      context: "P13 complete Rust library notice"
    )
    cc0_only = "<p><b>License:</b> CC0-1.0</p>"
    raise Failure, "P13 complete Rust notice CC0-only inventory differs" unless
      whole_notice.scan(cc0_only).length == 1 &&
      whole_notice.match?(
        /<h3>[^<]*notify-8\.2\.0<\/h3>.*?#{Regexp.escape(cc0_only)}/m
      )
    raise Failure, "P13 library notice contains CC0-only software" unless
      library_notice.scan(cc0_only).empty?
    validate_rust_notice_inventories(record, whole_notice, library_notice)

    validate_installed_rust_exclusions(record)

    selected = COMMAND_WINDOW_FILES.map { |item| item.fetch("name") } +
      COMMAND_WINDOW_TREES.map { |item| item.fetch("name") }
    raise Failure, "P13 Rust source selected tool set differs" unless
      selected == record.fetch("selected_tools")
    approved_license_ids ||= validate_spdx_license_evidence(record)
    raise Failure, "P13 LoongArch SPDX license evidence differs" unless
      approved_license_ids.fetch("GPL-3.0-or-later") == "OSI_APPROVED" &&
      approved_license_ids.fetch("GCC-exception-3.1") == "SPDX_EXCEPTION"
    validate_rust_in_tree_licenses(
      record,
      contents.fetch("license-metadata.json"),
      approved_license_ids
    )
    packages = {
      "compiler_and_clippy" => compiler_packages,
      "sysroot" => sysroot_packages
    }
    validate_rust_path_source_closures(record, archive_handle) if archive_handle
    registry_entries ||= extract_rust_registry_license_entries(
      record,
      archive_handle,
      packages
    )
    validate_rust_registry_licenses(
      record,
      packages,
      registry_entries,
      approved_license_ids
    )
    validate_toolchain_copied_source_origins(record, registry_entries)
    true
  rescue KeyError => error
    raise Failure, "P13 Rust source member field missing: #{error.key}"
  end

  def rust_lock_packages(bytes, context)
    blocks = bytes.split(/^\[\[package\]\]\s*$\n/)
    blocks.shift
    raise Failure, "#{context} contains no packages" if blocks.empty?

    packages = blocks.map do |block|
      {
        "name" => required_toml_string(block, "name", context),
        "version" => required_toml_string(block, "version", context),
        "source" => optional_toml_string(block, "source", context),
        "checksum" => optional_toml_string(block, "checksum", context),
        "dependencies" => rust_lock_dependencies(block, context)
      }
    end
    identities = packages.map do |package|
      package.values_at("name", "version", "source")
    end
    raise Failure, "#{context} contains a duplicate source identity" unless
      identities.uniq.length == identities.length
    packages
  end

  def rust_lock_dependencies(block, context)
    marker_count = block.scan(/^dependencies = \[/).length
    return [] if marker_count.zero?

    match = block.match(/^dependencies = \[\r?\n(.*?)^\]\r?\n/m)
    raise Failure, "#{context} dependency array differs" unless
      marker_count == 1 && match

    dependencies = match[1].lines.map do |line|
      reference = line.match(/\A "([^"\r\n]+)",\r?\n?\z/)
      raise Failure, "#{context} dependency reference differs" unless reference

      reference[1]
    end
    raise Failure, "#{context} contains a duplicate dependency reference" unless
      dependencies.uniq.length == dependencies.length
    dependencies
  end

  def rust_lock_dependency_package(reference, packages, context)
    match = reference.match(
      /\A([A-Za-z0-9_-]+)(?: ([0-9A-Za-z.+-]+)(?: \(([^()\r\n]+)\))?)?\z/
    )
    raise Failure, "#{context} dependency identity is malformed: #{reference}" unless
      match

    name, version, source = match.captures
    matches = packages.select { |package| package.fetch("name") == name }
    matches.select! { |package| package.fetch("version") == version } if version
    matches.select! { |package| package.fetch("source") == source } if source
    if source.nil? && version && matches.length > 1
      path_matches = matches.select { |package| package.fetch("source").nil? }
      matches = path_matches if path_matches.length == 1
    end
    raise Failure, "#{context} dependency identity is ambiguous: #{reference}" unless
      matches.length == 1
    matches.first
  end

  def rust_lock_reachable_packages(packages, root_names, context)
    roots = root_names.map do |name|
      matches = packages.select { |package| package.fetch("name") == name }
      raise Failure, "#{context} root identity differs: #{name}" unless
        matches.length == 1
      matches.first
    end

    reachable = {}
    queue = roots.dup
    until queue.empty?
      package = queue.shift
      identity = package.values_at("name", "version", "source")
      next if reachable.key?(identity)

      reachable[identity] = package
      package.fetch("dependencies").each do |reference|
        queue << rust_lock_dependency_package(reference, packages, context)
      end
    end
    reachable.values
  rescue KeyError => error
    raise Failure, "#{context} dependency field missing: #{error.key}"
  end

  def validate_rust_active_lock_graph(record, compiler_packages, sysroot_packages)
    graph = record.fetch("active_lock_graph")
    raise Failure, "P13 Rust active lock roots differ" unless
      graph.fetch("roots") == RUST_ACTIVE_LOCK_ROOTS

    active = rust_lock_reachable_packages(
      compiler_packages,
      RUST_ACTIVE_LOCK_ROOTS,
      "P13 Rust active lock graph"
    )
    registry = active.select { |package| package.fetch("source") }
    tuple_rows = registry.map do |package|
      package.values_at("name", "version", "source", "checksum")
    end.sort_by { |row| row.map(&:b) }
    raise Failure, "P13 Rust active lock graph inventory differs" unless
      graph.fetch("package_count") == active.length &&
      graph.fetch("registry_package_count") == registry.length &&
      graph.fetch("registry_tuple_inventory_sha256") ==
        Digest::SHA256.hexdigest(
          tuple_rows.map { |row| row.join("\0") }.join("\n") + "\n"
        )

    raise Failure, "P13 Rust reviewed inactive package evidence differs" unless
      graph.fetch("reviewed_inactive_packages") ==
        RUST_REVIEWED_INACTIVE_PACKAGES
    RUST_REVIEWED_INACTIVE_PACKAGES.each do |expected|
      compiler_matches = compiler_packages.select do |package|
        package.values_at("name", "version", "source", "checksum") ==
          expected.values_at("name", "version", "source", "checksum")
      end
      raise Failure, "P13 Rust reviewed inactive package lock tuple differs" unless
        compiler_matches.length == 1
      raise Failure, "P13 Rust reviewed inactive package reached active graph" if
        active.any? do |package|
          package.values_at("name", "version", "source", "checksum") ==
            expected.values_at("name", "version", "source", "checksum")
        end
      raise Failure, "P13 Rust reviewed inactive package reached sysroot lock" if
        sysroot_packages.any? do |package|
          package.values_at("name", "version", "source", "checksum") ==
            expected.values_at("name", "version", "source", "checksum")
        end
    end
    raise Failure, "P13 Rust active lock graph result differs" unless
      graph.fetch("result") ==
        "REVIEWED_NON_OSI_BUNDLED_SOURCE_UNREACHABLE_FROM_SELECTED_ROOTS"
    true
  rescue KeyError => error
    raise Failure, "P13 Rust active lock graph field missing: #{error.key}"
  end

  def rust_lock_package_names(bytes, context)
    rust_lock_packages(bytes, context).map { |package| package.fetch("name") }
  end

  def validate_excluded_rust_analyzer_package(record, packages)
    excluded = record.fetch("excluded_registry_package")
    notify = packages.select { |package| package.fetch("name") == "notify" }
    raise Failure, "P13 excluded CC0 package segregation differs" unless
      notify.length == record.fetch("excluded_rust_analyzer_notify_count") &&
      notify.all? do |package|
        package.values_at("name", "version", "source", "checksum") ==
          excluded.values_at("name", "version", "source", "checksum")
      end &&
      packages.count { |package| package.fetch("name") == "rust-analyzer" } == 1
    true
  rescue KeyError => error
    raise Failure, "P13 excluded Rust package field missing: #{error.key}"
  end

  def extract_rust_registry_license_entries(
    record,
    archive_handle,
    package_sets
  )
    first_members = []
    package_sets.each do |closure, packages|
      vendor_root = RUST_REGISTRY_ROOTS.fetch(closure)
      rust_registry_packages(packages, closure).each do |package|
        directory = rust_registry_package_directory(vendor_root, package)
        first_members << "#{directory}/Cargo.toml"
        first_members << "#{directory}/.cargo-checksum.json"
      end
    end
    first = extract_rust_archive_files(
      record,
      archive_handle,
      first_members,
      "P13 Rust registry metadata"
    )

    result = {}
    package_sets.each do |closure, packages|
      vendor_root = RUST_REGISTRY_ROOTS.fetch(closure)
      entries = {}
      content_members = []
      rust_registry_packages(packages, closure).each do |package|
        identity = rust_registry_identity(package)
        raise Failure, "P13 Rust registry vendor identity is duplicated" if
          entries.key?(identity)

        directory = rust_registry_package_directory(vendor_root, package)
        manifest_path = "#{directory}/Cargo.toml"
        checksum_path = "#{directory}/.cargo-checksum.json"
        checksum = first.fetch(checksum_path)
        checksum_document = rust_checksum_document(
          checksum,
          "#{closure} #{package.fetch('name')} #{package.fetch('version')}"
        )
        content_paths = checksum_document.fetch("files").keys.sort_by(&:b)
        legal_paths = content_paths.select do |path|
          rust_registry_legal_file_path?(path)
        end
        content_paths.each do |path|
          content_members << "#{directory}/#{path}"
        end
        entries[identity] = {
          "directory" => directory,
          "manifest" => first.fetch(manifest_path),
          "checksum" => checksum,
          "content_paths" => content_paths,
          "content_scan" => nil,
          "legal_paths" => legal_paths,
          "legal_files" => {},
          "origin_review_files" => {}
        }
      end

      content = extract_rust_archive_files(
        record,
        archive_handle,
        content_members,
        "P13 Rust registry checksum-bound files: #{closure}"
      )
      entries.each_value do |entry|
        files = entry.fetch("content_paths").to_h do |path|
          [path, content.fetch("#{entry.fetch('directory')}/#{path}")]
        end
        checksums = rust_checksum_document(
          entry.fetch("checksum"),
          "#{closure} #{entry.fetch('directory')}"
        ).fetch("files")
        entry["content_scan"] = rust_registry_content_scan(
          entry.fetch("directory"),
          files,
          checksums
        )
        entry.fetch("legal_paths").each do |path|
          entry.fetch("legal_files")[path] =
            files.fetch(path)
        end
        package_name = entry.fetch("directory").split("/").last
        RUST_COPIED_SOURCE_FILES.each do |name, path|
          next unless package_name.start_with?("#{name}-") && files.key?(path)

          entry.fetch("origin_review_files")[path] = files.fetch(path)
        end
      end
      result[closure] = entries
    end
    result
  rescue KeyError => error
    raise Failure, "P13 Rust registry extraction field missing: #{error.key}"
  end

  def validate_rust_path_source_closures(record, archive_handle)
    expected = record.fetch("path_source_closures")
    raise Failure, "P13 Rust path-source closure set differs" unless
      expected.keys == RUST_PATH_SOURCE_CLOSURES.keys

    RUST_PATH_SOURCE_CLOSURES.each_key do |closure|
      observed = observe_rust_path_source_closure(
        record,
        archive_handle,
        closure
      )
      evidence = expected.fetch(closure)
      raise Failure, "P13 Rust path-source fields differ: #{closure}" unless
        evidence.keys.sort_by(&:b) == %w[
          directory_count
          entry_count
          entry_inventory_sha256
          excluded_prefixes
          file_bytes
          file_count
          file_inventory_sha256
          limits
          max_path_depth
          path_package_count
          prefixes
          symlink_count
          symlinks
          witness_count
          witness_dispositions
          witness_file_count
          witness_file_inventory_sha256
          witness_inventory_sha256
        ].sort_by(&:b)
      identity = evidence.reject { |key, _value| key == "witness_dispositions" }
      raise Failure, "P13 Rust path-source inventory differs: #{closure}" unless
        identity == observed.fetch("evidence")
      validate_rust_registry_content_dispositions(
        evidence.fetch("witness_dispositions"),
        observed.fetch("witness_rows"),
        "path-source #{closure}"
      )
      validate_rust_path_source_dispositions(
        evidence.fetch("witness_dispositions"),
        observed.fetch("witness_rows"),
        closure
      )
    end
    true
  rescue KeyError => error
    raise Failure, "P13 Rust path-source field missing: #{error.key}"
  end

  def validate_rust_path_source_dispositions(dispositions, witness_rows, closure)
    restrictive = witness_rows.select do |row|
      row.fetch(5).start_with?("RESTRICTIVE_")
    end
    restrictive_rules = restrictive.group_by { |row| row.fetch(0) }
      .transform_values do |rows|
        rows.map { |row| row.fetch(5) }.uniq.sort_by(&:b)
      end
    expected_restrictive =
      closure == "sysroot" ?
        {
          RUST_PATH_SOURCE_INTEL_REJECTION.fetch("path") =>
            ["RESTRICTIVE_PRIOR_WRITTEN_PERMISSION"]
        } :
        {}
    raise Failure, "P13 Rust path-source restrictive grant differs: #{closure}" unless
      restrictive_rules == expected_restrictive

    cc0_paths = witness_rows.select do |row|
      row.fetch(5) == "NONSTANDARD_CC0"
    end.map { |row| row.fetch(0) }.uniq
    raise Failure, "P13 Rust path-source CC0 data inventory differs: #{closure}" unless
      cc0_paths.empty?

    by_path = dispositions.to_h { |record| [record.fetch("path"), record] }
    if closure == "sysroot"
      intel = by_path.fetch(RUST_PATH_SOURCE_INTEL_REJECTION.fetch("path"))
      raise Failure, "P13 Intel CPUID rejection disposition differs" unless
        intel.values_at("path", "bytes", "sha256") ==
          RUST_PATH_SOURCE_INTEL_REJECTION.values_at(
            "path",
            "bytes",
            "sha256"
          ) &&
        intel.fetch("witness_rule_ids").include?(
          "RESTRICTIVE_PRIOR_WRITTEN_PERMISSION"
        ) &&
        intel.values_at(
          "rights",
          "rights_status",
          "reachability",
          "disposition"
        ) == RUST_PATH_SOURCE_INTEL_REJECTION.values_at(
          "rights",
          "rights_status",
          "reachability",
          "disposition"
        )

      RUST_PATH_SOURCE_LOONGARCH_HEADERS.each do |expected_header|
        path = expected_header.fetch("path")
        header = by_path.fetch(path)
        raise Failure, "P13 LoongArch GCC exception disposition differs: #{path}" unless
          header.values_at("path", "bytes", "sha256") ==
            expected_header.values_at("path", "bytes", "sha256") &&
          header.fetch("witness_rule_ids").include?("ALTERNATIVE_GPL_FAMILY") &&
          header.fetch("witness_rule_ids").include?(
            "ALTERNATIVE_GPL_3_OR_LATER_WITH_GCC_EXCEPTION_3_1"
          ) &&
          header.values_at(
            "rights",
            "rights_status",
            "reachability",
            "disposition"
          ) == RUST_PATH_SOURCE_LOONGARCH_DISPOSITION.values_at(
            "rights",
            "rights_status",
            "reachability",
            "disposition"
          )
      end
    end
    true
  rescue KeyError => error
    raise Failure, "P13 Rust path-source disposition field missing: #{error.key}"
  end

  def validate_toolchain_copied_source_origins(record, registry_entries)
    reviews = record.fetch("copied_source_origins")
    raise Failure, "P13 toolchain copied-source review set differs" unless
      reviews.keys == %w[pulldown_cmark_redwood tracing_subscriber_hyperium]
    compiler = registry_entries.fetch("compiler_and_clippy")
    validate_pulldown_redwood_origin(
      reviews.fetch("pulldown_cmark_redwood"),
      compiler.fetch(["pulldown-cmark", "0.11.3"])
    )
    validate_tracing_hyperium_origin(
      reviews.fetch("tracing_subscriber_hyperium"),
      compiler.fetch(["tracing-subscriber", "0.3.20"])
    )
    true
  rescue KeyError => error
    raise Failure, "P13 toolchain copied-source field missing: #{error.key}"
  end

  def validate_pulldown_redwood_origin(review, entry)
    package = review.fetch("package")
    source = entry.fetch("origin_review_files").fetch("src/utils.rs")
    license = entry.fetch("legal_files").fetch("LICENSE")
    checksum = rust_checksum_document(
      entry.fetch("checksum"),
      "P13 pulldown-cmark copied source"
    )
    raise Failure, "P13 pulldown-cmark package binding differs" unless
      package.fetch("name") == "pulldown-cmark" &&
      package.fetch("version") == "0.11.3" &&
      package.fetch("checksum") ==
        "679341d22c78c6c649893cbd6c3278dcbe9fc4faa62fea3a9296ae2b50c14625" &&
      package.fetch("checksum") == checksum.fetch("package") &&
      package.fetch("archive_path") ==
        "vendor/pulldown-cmark-0.11.3/src/utils.rs" &&
      package.fetch("source_path") == "src/utils.rs" &&
      source.bytesize == package.fetch("bytes") &&
      Digest::SHA256.hexdigest(source) == package.fetch("sha256") &&
      package.fetch("license_expression") == "MIT" &&
      package.fetch("license_path") == "LICENSE" &&
      Digest::SHA256.hexdigest(license) ==
        package.fetch("license_sha256")
    require_include(license, "Permission is hereby granted", "pulldown MIT grant")

    package_git = package.fetch("git")
    raise Failure, "P13 pulldown-cmark Git source identity differs" unless
      package_git.fetch("repository") ==
        "https://github.com/pulldown-cmark/pulldown-cmark.git" &&
      package_git.fetch("local_repository") ==
        "data/quarantine/pulldown-cmark-upstream"
    exact_package_source = git_evidence_file(
      root: File.join(ROOT, package_git.fetch("local_repository")),
      commit: package_git.fetch("commit"),
      tree: package_git.fetch("tree"),
      path: package_git.fetch("path"),
      blob: package_git.fetch("blob"),
      bytes: package.fetch("bytes"),
      sha256: package.fetch("sha256"),
      label: "pulldown-cmark copied source"
    )
    raise Failure, "P13 pulldown-cmark archive and Git source differ" unless
      exact_package_source == source
    package_git_license = git_evidence_file(
      root: File.join(ROOT, package_git.fetch("local_repository")),
      commit: package_git.fetch("commit"),
      tree: package_git.fetch("tree"),
      path: package_git.fetch("license_path"),
      blob: package_git.fetch("license_blob"),
      bytes: package_git.fetch("license_bytes"),
      sha256: package.fetch("license_sha256"),
      label: "pulldown-cmark MIT license"
    )
    raise Failure, "P13 pulldown-cmark archive and Git license differ" unless
      package_git_license == license

    origin_record = review.fetch("origin")
    origin = git_evidence_file(
      root: File.join(ROOT, origin_record.fetch("local_repository")),
      commit: origin_record.fetch("commit"),
      tree: origin_record.fetch("tree"),
      path: origin_record.fetch("path"),
      blob: origin_record.fetch("blob"),
      bytes: origin_record.fetch("bytes"),
      sha256: origin_record.fetch("sha256"),
      label: "Redwood markdown utility origin"
    )
    origin_license_record = origin_record.fetch("license")
    origin_license = git_evidence_file(
      root: File.join(ROOT, origin_record.fetch("local_repository")),
      commit: origin_record.fetch("commit"),
      tree: origin_record.fetch("tree"),
      path: origin_license_record.fetch("path"),
      blob: origin_license_record.fetch("blob"),
      bytes: origin_license_record.fetch("bytes"),
      sha256: origin_license_record.fetch("sha256"),
      label: "Redwood GPL license"
    )
    require_include(
      origin_license,
      "GNU GENERAL PUBLIC LICENSE",
      "Redwood original GPL grant"
    )
    raise Failure, "P13 Redwood origin identity differs" unless
      origin_record.fetch("repository") ==
        "https://github.com/BenjaminRi/Redwood-Wiki.git" &&
      origin_record.fetch("local_repository") ==
        "data/quarantine/redwood-wiki-upstream" &&
      origin_record.fetch("license_expression") == "GPL-3.0-only"

    marker = validate_exact_byte_region(
      source,
      review.fetch("marker"),
      "pulldown-cmark Redwood marker"
    )
    require_include(
      marker,
      "BenjaminRi/Redwood-Wiki",
      "pulldown-cmark Redwood marker"
    )
    package_region = validate_exact_byte_region(
      source,
      review.fetch("copied_region").fetch("package"),
      "pulldown-cmark copied region"
    )
    origin_region = validate_exact_byte_region(
      origin,
      review.fetch("copied_region").fetch("origin"),
      "Redwood copied region"
    )
    normalized_package = package_region.delete(" \t\r\n\f\v")
    normalized_origin = origin_region.delete(" \t\r\n\f\v")
    normalized = review.fetch("copied_region").fetch("normalized")
    raise Failure, "P13 pulldown-cmark copied region differs" unless
      normalized.fetch("transformation") == "DELETE_ASCII_WHITESPACE_ONLY" &&
      normalized_package == normalized_origin &&
      normalized_package.bytesize == normalized.fetch("bytes") &&
      Digest::SHA256.hexdigest(normalized_package) ==
        normalized.fetch("sha256")

    validate_redwood_relicense_grant(review.fetch("author_permission"))
    raise Failure, "P13 pulldown-cmark copied-source disposition differs" unless
      review.fetch("elected_license") == "MIT" &&
      review.fetch("disposition") == [
        "IMMUTABLE_REDWOOD_GPL_SOURCE_AND_AUTHOR_RELICENSE_GRANT",
        "EXACT_ORIGIN_AND_UNRESTRICTED_RELICENSE_PERMISSION_VERIFIED",
        "ACTIVE_LOCK_GRAPH_ONLY_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14",
        "COPIED_SOURCE_BOUND_TO_EXACT_ORIGIN_AND_SEPARATE_AUTHOR_PERMISSION"
      ]
    true
  rescue KeyError => error
    raise Failure, "P13 pulldown-cmark copied-source field missing: #{error.key}"
  end

  def validate_tracing_hyperium_origin(review, entry)
    package = review.fetch("package")
    source = entry.fetch("origin_review_files")
      .fetch("src/registry/extensions.rs")
    license = entry.fetch("legal_files").fetch("LICENSE")
    checksum = rust_checksum_document(
      entry.fetch("checksum"),
      "P13 tracing-subscriber copied source"
    )
    raise Failure, "P13 tracing-subscriber package binding differs" unless
      package.fetch("name") == "tracing-subscriber" &&
      package.fetch("version") == "0.3.20" &&
      package.fetch("checksum") ==
        "2054a14f5307d601f88daf0553e1cbf472acc4f2c51afab632431cdcd72124d5" &&
      package.fetch("checksum") == checksum.fetch("package") &&
      package.fetch("archive_path") ==
        "vendor/tracing-subscriber-0.3.20/src/registry/extensions.rs" &&
      package.fetch("source_path") == "src/registry/extensions.rs" &&
      source.bytesize == package.fetch("bytes") &&
      Digest::SHA256.hexdigest(source) == package.fetch("sha256") &&
      package.fetch("license_expression") == "MIT" &&
      package.fetch("license_path") == "LICENSE" &&
      Digest::SHA256.hexdigest(license) ==
        package.fetch("license_sha256")
    require_include(license, "Permission is hereby granted", "tracing MIT grant")

    origin_record = review.fetch("origin")
    origin = git_evidence_file(
      root: File.join(ROOT, origin_record.fetch("local_repository")),
      commit: origin_record.fetch("commit"),
      tree: origin_record.fetch("tree"),
      path: origin_record.fetch("path"),
      blob: origin_record.fetch("blob"),
      bytes: origin_record.fetch("bytes"),
      sha256: origin_record.fetch("sha256"),
      label: "Hyperium HTTP extensions origin"
    )
    licenses = origin_record.fetch("licenses")
    mit = copied_source_origin_license(
      origin_record,
      licenses.fetch("MIT"),
      "Hyperium MIT license"
    )
    apache = copied_source_origin_license(
      origin_record,
      licenses.fetch("Apache-2.0"),
      "Hyperium Apache license"
    )
    require_include(mit, "Permission is hereby granted", "Hyperium MIT grant")
    require_include(apache, "Apache License", "Hyperium Apache grant")
    raise Failure, "P13 Hyperium origin identity differs" unless
      origin_record.fetch("repository") == "https://github.com/hyperium/http.git" &&
      origin_record.fetch("local_repository") ==
        "data/quarantine/hyperium-http-upstream" &&
      origin_record.fetch("license_expression") == "MIT OR Apache-2.0"

    marker = validate_exact_byte_region(
      source,
      review.fetch("marker"),
      "tracing-subscriber Hyperium marker"
    )
    require_include(
      marker,
      "github.com/hyperium/http",
      "tracing-subscriber Hyperium marker"
    )
    package_region = validate_exact_byte_region(
      source,
      review.fetch("copied_region").fetch("package"),
      "tracing-subscriber copied region"
    )
    origin_region = validate_exact_byte_region(
      origin,
      review.fetch("copied_region").fetch("origin"),
      "Hyperium copied region"
    )
    raise Failure, "P13 tracing-subscriber copied region differs" unless
      package_region == origin_region
    raise Failure, "P13 tracing-subscriber copied-source disposition differs" unless
      review.fetch("elected_license") == "MIT" &&
      review.fetch("disposition") == [
        "IMMUTABLE_HYPERIUM_HTTP_MIT_OR_APACHE_2_0_ORIGIN",
        "EXACT_ORIGIN_AND_OSI_GRANTS_VERIFIED",
        "ACTIVE_LOCK_GRAPH_ONLY_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14",
        "COPIED_SOURCE_BOUND_TO_EXACT_DUAL_LICENSED_ORIGIN"
      ]
    true
  rescue KeyError => error
    raise Failure, "P13 tracing copied-source field missing: #{error.key}"
  end

  def copied_source_origin_license(origin, record, label)
    git_evidence_file(
      root: File.join(ROOT, origin.fetch("local_repository")),
      commit: origin.fetch("commit"),
      tree: origin.fetch("tree"),
      path: record.fetch("path"),
      blob: record.fetch("blob"),
      bytes: record.fetch("bytes"),
      sha256: record.fetch("sha256"),
      label: label
    )
  end

  def validate_exact_byte_region(source, record, label)
    start_byte = record.fetch("start_byte")
    end_byte = record.fetch("end_byte")
    raise Failure, "#{label} coordinates differ" unless
      start_byte.is_a?(Integer) &&
      end_byte.is_a?(Integer) &&
      start_byte >= 0 &&
      end_byte > start_byte &&
      end_byte <= source.bytesize
    region = source.byteslice(start_byte, end_byte - start_byte)
    raise Failure, "#{label} identity differs" unless
      region.bytesize == record.fetch("bytes") &&
      Digest::SHA256.hexdigest(region) == record.fetch("sha256")
    region
  rescue KeyError => error
    raise Failure, "#{label} field missing: #{error.key}"
  end

  def validate_redwood_relicense_grant(record)
    artifact = verify_file(
      File.join(ROOT, record.fetch("local_path")),
      bytes: record.fetch("bytes"),
      sha256: record.fetch("sha256"),
      context: "Redwood author permission artifact"
    )
    scripts = artifact.scan(
      /<script type="application\/json" data-target="react-app\.embeddedData">(.*?)<\/script>/m
    )
    raise Failure, "Redwood author permission JSON artifact differs" unless
      scripts.length == 1
    document = parse_json(
      scripts.first.first,
      "Redwood author permission JSON"
    )
    comments = []
    collect_json_records(document, comments) do |value|
      value.is_a?(Hash) &&
        value["__typename"] == "IssueComment" &&
        value["databaseId"] == record.fetch("comment_database_id")
    end
    raise Failure, "Redwood author permission comment identity differs" unless
      comments.length == 1
    comment = comments.first
    author = comment.fetch("author")
    body = comment.fetch("body").b
    target =
      "https://github.com/BenjaminRi/Redwood-Wiki/blob/" \
      "dfa58152b41d7eb5bcdd7563e30e5373692f8a3b/src/markdown_utils.rs"
    raise Failure, "Redwood author permission fields differ" unless
      record.fetch("canonical_url") ==
        "https://github.com/pulldown-cmark/pulldown-cmark/issues/507" &&
      record.fetch("request_url") ==
        "https://github.com/pulldown-cmark/pulldown-cmark/issues/507?timeline_page=1" &&
      record.fetch("acquired_at_utc") == "2026-08-30T19:46:38Z" &&
      record.fetch("request_authentication") == "NONE" &&
      record.fetch("artifact_provenance") ==
        "HASH_PINNED_MUTABLE_UPSTREAM_RESPONSE" &&
      record.fetch("comment_database_id") == 1_596_190_824 &&
      comment.fetch("id") == record.fetch("comment_node_id") &&
      comment.fetch("url") == record.fetch("comment_url") &&
      comment.fetch("createdAt") == record.fetch("created_at") &&
      author.values_at("login", "id", "name") ==
        record.values_at("author_login", "author_id", "author_name") &&
      body.bytesize == record.fetch("body_bytes") &&
      Digest::SHA256.hexdigest(body) == record.fetch("body_sha256") &&
      body.include?(target) &&
      body.include?("you may use, modify and/or redistribute the code") &&
      body.include?("under any license you want") &&
      record.fetch("granted_actions") ==
        %w[use modify redistribute relicense] &&
      record.fetch("selected_license") == "MIT"
    true
  rescue KeyError => error
    raise Failure, "Redwood author permission field missing: #{error.key}"
  end

  def collect_json_records(value, matches, depth = 0, &predicate)
    raise Failure, "JSON evidence nesting is excessive" if depth > 64
    matches << value if predicate.call(value)
    case value
    when Hash
      value.each_value do |child|
        collect_json_records(child, matches, depth + 1, &predicate)
      end
    when Array
      value.each do |child|
        collect_json_records(child, matches, depth + 1, &predicate)
      end
    end
    matches
  end

  def observe_rust_path_source_closure(record, archive_handle, closure)
    definition = RUST_PATH_SOURCE_CLOSURES.fetch(closure)
    entries = rust_archive_verbose_entries(
      record,
      archive_handle,
      prefixes: definition.fetch("prefixes"),
      context: "P13 Rust path source: #{closure}"
    )
    selected = entries.select do |entry|
      path = entry.fetch("path")
      definition.fetch("prefixes").any? do |prefix|
        path == prefix || path.start_with?("#{prefix}/")
      end
    end.reject do |entry|
      path = entry.fetch("path")
      definition.fetch("excluded_prefixes").any? do |prefix|
        path == prefix || path.start_with?("#{prefix}/")
      end
    end
    raise Failure, "P13 Rust path-source prefix selection differs: #{closure}" if
      selected.empty?

    files = selected.select { |entry| entry.fetch("type") == "file" }
    directories = selected.select { |entry| entry.fetch("type") == "directory" }
    symlinks = selected.select { |entry| entry.fetch("type") == "symlink" }
    unsupported = selected.reject do |entry|
      %w[file directory symlink].include?(entry.fetch("type"))
    end
    raise Failure, "P13 Rust path-source archive type is unsupported: #{closure}" unless
      unsupported.empty?

    file_bytes = 0
    files.each do |entry|
      file_bytes = bounded_rust_extraction_bytes(
        file_bytes,
        entry.fetch("bytes"),
        "P13 Rust path source: #{closure}"
      )
    end
    raise Failure, "P13 Rust path-source file count is excessive: #{closure}" if
      files.length >
        RUST_REGISTRY_CONTENT_LIMITS.fetch("max_files_per_closure")

    symlink_rows = symlinks.map do |entry|
      entry.slice("path", "target")
    end.sort_by { |entry| entry.fetch("path").b }
    raise Failure, "P13 Rust path-source symlink inventory differs: #{closure}" unless
      symlink_rows == RUST_PATH_SOURCE_SYMLINKS.fetch(closure)

    paths = files.map { |entry| entry.fetch("path") }
    contents = extract_rust_archive_files(
      record,
      archive_handle,
      paths,
      "P13 Rust path-source files: #{closure}"
    )
    file_entries = files.to_h { |entry| [entry.fetch("path"), entry] }
    file_rows = []
    witness_rows = []
    observed_bytes = 0
    paths.sort_by(&:b).each do |path|
      bytes = contents.fetch(path)
      archive_entry = file_entries.fetch(path)
      raise Failure, "P13 Rust path-source extracted size differs: #{path}" unless
        bytes.bytesize == archive_entry.fetch("bytes")
      observed_bytes = bounded_rust_extraction_bytes(
        observed_bytes,
        bytes.bytesize,
        "P13 Rust path source: #{closure}"
      )
      sha256 = Digest::SHA256.hexdigest(bytes)
      file_rows << [path, bytes.bytesize, sha256]
      file_witnesses = rust_registry_content_witness_rows(
        path,
        bytes,
        bytes.bytesize,
        sha256
      )
      raise Failure, "P13 Rust path-source witness count is excessive: #{closure}" if
        witness_rows.length + file_witnesses.length >
          RUST_REGISTRY_CONTENT_LIMITS.fetch("max_witnesses_per_closure")
      witness_rows.concat(file_witnesses)
    end
    raise Failure, "P13 Rust path-source byte preflight differs: #{closure}" unless
      observed_bytes == file_bytes

    witness_files = witness_rows.map { |row| row.values_at(0, 1, 2) }.uniq
    max_depth = selected.map do |entry|
      entry.fetch("path").split("/").length
    end.max
    {
      "evidence" => {
        "prefixes" => definition.fetch("prefixes"),
        "excluded_prefixes" => definition.fetch("excluded_prefixes"),
        "path_package_count" => definition.fetch("path_package_count"),
        "limits" => RUST_REGISTRY_CONTENT_LIMITS,
        "entry_count" => selected.length,
        "directory_count" => directories.length,
        "file_count" => file_rows.length,
        "symlink_count" => symlink_rows.length,
        "file_bytes" => observed_bytes,
        "max_path_depth" => max_depth,
        "entry_inventory_sha256" =>
          rust_archive_entry_inventory_digest(selected),
        "file_inventory_sha256" => rust_file_inventory_digest(file_rows),
        "symlinks" => symlink_rows,
        "witness_count" => witness_rows.length,
        "witness_inventory_sha256" =>
          rust_registry_content_witness_inventory_digest(witness_rows),
        "witness_file_count" => witness_files.length,
        "witness_file_inventory_sha256" =>
          rust_file_inventory_digest(witness_files)
      },
      "file_rows" => file_rows,
      "witness_rows" => witness_rows
    }
  rescue KeyError => error
    raise Failure, "P13 Rust path-source observation field missing: #{error.key}"
  end

  def rust_archive_verbose_entries(
    record,
    archive_handle,
    members: nil,
    prefixes: nil,
    context:
  )
    raise Failure, "#{context} archive listing selector differs" unless
      [members.nil?, prefixes.nil?].count(true) == 1

    root = record.fetch("source_archive").fetch("archive_root")
    extractor = record.fetch("extraction_tool").fetch("path")
    environment = {
      "COPYFILE_DISABLE" => "1",
      "LANG" => "C",
      "LC_ALL" => "C",
      "PATH" => "/usr/bin:/bin",
      "TZ" => "UTC"
    }
    arguments = [
      extractor,
      "-tvJf",
      rust_archive_descriptor_path(archive_handle)
    ]
    input = nil
    if members
      full_members = members.map do |path|
        validate_relative_path(path, context)
        "#{root}/#{path}"
      end
      input = rust_archive_member_list(full_members, context)
      arguments.concat(["--null", "-T", "/dev/stdin"])
    else
      raise Failure, "#{context} archive prefix inventory is empty" if
        prefixes.empty?
      arguments.concat(prefixes.map do |prefix|
        validate_relative_path(prefix, context)
        "#{root}/#{prefix}"
      end)
    end

    options = {
      close_others: true,
      unsetenv_others: true,
      archive_handle.fetch("io").fileno => archive_handle.fetch("io")
    }
    stdout, stderr, status = capture3_bounded(
      environment,
      arguments,
      options,
      stdin_data: input,
      stdout_limit:
        RUST_REGISTRY_CONTENT_LIMITS.fetch("max_archive_listing_bytes"),
      stderr_limit:
        RUST_ARCHIVE_SILENT_OUTPUT_MAX_BYTES,
      context: context,
      prohibit_descendants: true
    )
    archive_handle.fetch("io").rewind
    validate_open_large_file_identity(archive_handle, context)
    raise Failure, "#{context} archive listing failed" unless
      status.success? && stderr.empty?
    entries = stdout.lines.map do |line|
      rust_archive_verbose_entry(line, root, context)
    end
    raise Failure, "#{context} archive listing is empty" if entries.empty?
    paths = entries.map { |entry| entry.fetch("path") }
    raise Failure, "#{context} archive listing contains duplicates" unless
      paths.uniq.length == paths.length
    entries
  rescue Errno::ENOENT => error
    raise Failure, "#{context} archive listing input missing: #{error.class}"
  end

  def capture3_bounded(
    environment,
    arguments,
    options,
    stdin_data:,
    stdout_limit:,
    stderr_limit:,
    context:,
    prohibit_descendants:,
    deadline_seconds: RUST_ARCHIVE_CHILD_DEADLINE_SECONDS
  )
    raise Failure, "#{context} deadline is invalid" unless
      deadline_seconds.is_a?(Numeric) && deadline_seconds.positive?
    raise Failure, "#{context} argument vector is invalid" unless
      arguments.is_a?(Array) && arguments.first.is_a?(String)

    stdin_reader = stdin_writer = nil
    stdout_reader = stdout_writer = nil
    stderr_reader = stderr_writer = nil
    pid = nil
    reaped = false
    writer = nil
    readers = []
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) +
      deadline_seconds
    spawn_options = options.merge(pgroup: true)
    if prohibit_descendants
      executable = File.stat(arguments.first)
      safe_identity =
        Process.const_defined?(:RLIMIT_NPROC) &&
        Process.uid == Process.euid &&
        Process.gid == Process.egid &&
        !Process.euid.zero? &&
        executable.file? &&
        (executable.mode & 0o6000).zero?
      raise Failure, "#{context} descendant prohibition is unavailable" unless
        safe_identity

      spawn_options[:rlimit_nproc] = [0, 0]
    end

    stdin_reader, stdin_writer = IO.pipe
    stdout_reader, stdout_writer = IO.pipe
    stderr_reader, stderr_writer = IO.pipe
    spawn_options[:in] = stdin_reader
    spawn_options[:out] = stdout_writer
    spawn_options[:err] = stderr_writer
    pid = Process.spawn(environment, *arguments, spawn_options)
    [stdin_reader, stdout_writer, stderr_writer].each(&:close)

    results = Queue.new
    readers = {
      stdout: [stdout_reader, stdout_limit],
      stderr: [stderr_reader, stderr_limit]
    }.map do |name, (stream, limit)|
      Thread.new do
        begin
          value = bounded_stream_read(
            stream,
            limit,
            "#{context} #{name}"
          )
          results << [name, value]
        rescue StandardError => error
          results << [name, error]
        ensure
          stream.close unless stream.closed?
        end
      end
    end
    writer = Thread.new do
      begin
        stdin_writer.write(stdin_data) if stdin_data
        results << [:stdin, nil]
      rescue Errno::EPIPE
        results << [:stdin, nil]
      rescue StandardError => error
        results << [:stdin, error]
      ensure
        stdin_writer.close unless stdin_writer.closed?
      end
    end

    captured = {}
    stdin_complete = false
    pending_error = nil
    status = nil
    until captured.length == 2 && stdin_complete
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        pending_error = Failure.new("#{context} deadline exceeded")
        break
      end
      begin
        name, value = results.pop(true)
      rescue ThreadError
        sleep 0.01
        next
      end
      pending_error ||= value if value.is_a?(StandardError)
      if name == :stdin
        stdin_complete = true
      else
        captured[name] = value
      end
      break if pending_error
    end

    unless pending_error
      loop do
        waited = Process.waitpid2(pid, Process::WNOHANG)
        if waited
          status = waited.fetch(1)
          reaped = true
          break
        end
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          pending_error = Failure.new("#{context} deadline exceeded")
          break
        end
        sleep 0.01
      end
    end

    if pending_error
      terminate_child_process_group(pid) unless reaped
      unless reaped
        _waited_pid, status = Process.waitpid2(pid)
        reaped = true
      end
      raise pending_error
    end

    [captured.fetch(:stdout), captured.fetch(:stderr), status]
  ensure
    [
      stdin_reader,
      stdin_writer,
      stdout_reader,
      stdout_writer,
      stderr_reader,
      stderr_writer
    ].compact.each do |stream|
      stream.close unless stream.closed?
    rescue IOError
      nil
    end
    if pid && !reaped
      terminate_child_process_group(pid)
      begin
        Process.waitpid(pid)
      rescue Errno::ECHILD
        nil
      end
    end
    Array(readers).each do |reader|
      reader.join(1)
      reader.kill if reader.alive?
    end
    if writer
      writer.join(1)
      writer.kill if writer.alive?
    end
  end

  def bounded_stream_read(stream, limit, context)
    raise Failure, "#{context} limit is invalid" unless
      limit.is_a?(Integer) && limit >= 0

    bytes = +"".b
    loop do
      remaining = limit - bytes.bytesize
      chunk = stream.readpartial([16 * 1024, remaining + 1].min)
      raise Failure, "#{context} is excessive" if chunk.bytesize > remaining

      bytes << chunk
    end
  rescue EOFError
    bytes
  end

  def terminate_child_process_group(pid)
    Process.kill("KILL", -pid)
  rescue Errno::ESRCH
    nil
  rescue Errno::EPERM
    Process.kill("KILL", pid)
  rescue Errno::ESRCH
    nil
  end

  def rust_archive_verbose_entry(line, root, context)
    match = line.match(
      /\A([bcdhlprw-])[rwxStTs-]{9}\s+\d+\s+\S+\s+\S+\s+(\d+)\s+[A-Z][a-z]{2}\s+\d{1,2}\s+(?:\d{2}:\d{2}|\d{4})\s+([^\r\n]+)\n\z/
    )
    raise Failure, "#{context} archive listing line is malformed" unless match

    type_character, size_text, path_and_target = match.captures
    type = {
      "-" => "file",
      "d" => "directory",
      "l" => "symlink"
    }.fetch(type_character, "unsupported")
    target = nil
    full_path = path_and_target
    if type == "symlink"
      link = path_and_target.match(/\A(.+) -> ([^\r\n]+)\z/)
      raise Failure, "#{context} archive symlink line is malformed" unless link
      full_path, target = link.captures
    end
    prefix = "#{root}/"
    raise Failure, "#{context} archive root differs" unless
      full_path.start_with?(prefix)
    path = full_path.delete_prefix(prefix)
    validate_relative_path(path, context)
    raise Failure, "#{context} archive path contains a control byte" if
      path.each_byte.any? { |byte| byte < 32 || byte == 127 }
    raise Failure, "#{context} archive link target contains a control byte" if
      target&.each_byte&.any? { |byte| byte < 32 || byte == 127 }
    bytes = Integer(size_text, 10)
    raise Failure, "#{context} archive non-file has payload bytes" if
      type != "file" && bytes != 0
    {
      "path" => path,
      "type" => type,
      "bytes" => bytes,
      "target" => target
    }
  rescue ArgumentError
    raise Failure, "#{context} archive listing size is malformed"
  end

  def rust_archive_entry_inventory_digest(entries)
    rows = entries.sort_by { |entry| entry.fetch("path").b }.map do |entry|
      [
        entry.fetch("path"),
        entry.fetch("type"),
        entry.fetch("bytes").to_s,
        entry.fetch("target") || ""
      ].join("\0")
    end
    Digest::SHA256.hexdigest(rows.join("\n") + "\n")
  end

  def validate_rust_archive_regular_preflight(entries, members, context)
    expected = members.sort_by(&:b)
    observed = entries.map { |entry| entry.fetch("path") }.sort_by(&:b)
    raise Failure, "#{context} archive preflight path set differs" unless
      observed == expected
    total = 0
    entries.each do |entry|
      raise Failure, "#{context} archive member type is unsupported" unless
        entry.fetch("type") == "file" && entry.fetch("target").nil?
      total = bounded_rust_extraction_bytes(
        total,
        entry.fetch("bytes"),
        context
      )
    end
    total
  rescue KeyError => error
    raise Failure, "#{context} archive preflight field missing: #{error.key}"
  end

  def extract_rust_archive_files(
    record,
    archive_handle,
    relative_members,
    context
  )
    root = record.fetch("source_archive").fetch("archive_root")
    extractor = record.fetch("extraction_tool").fetch("path")
    members = relative_members.map do |path|
      validate_relative_path(path, context)
      "#{root}/#{path}"
    end
    member_list = rust_archive_member_list(members, context)
    preflight = rust_archive_verbose_entries(
      record,
      archive_handle,
      members: relative_members,
      context: "#{context} preflight"
    )
    validate_rust_archive_regular_preflight(
      preflight,
      relative_members,
      context
    )

    contents = nil
    Dir.mktmpdir("p13-rust-registry-") do |directory|
      environment = {
        "COPYFILE_DISABLE" => "1",
        "LANG" => "C",
        "LC_ALL" => "C",
        "PATH" => "/usr/bin:/bin",
        "TZ" => "UTC"
      }
      stdout, stderr, status = capture3_bounded(
        environment,
        [
          extractor,
          "-xJf",
          rust_archive_descriptor_path(archive_handle),
          "-C",
          directory,
          "--null",
          "-T",
          "/dev/stdin"
        ],
        {
          archive_handle.fetch("io").fileno => archive_handle.fetch("io"),
          close_others: true,
          unsetenv_others: true
        },
        stdin_data: member_list,
        stdout_limit: RUST_ARCHIVE_SILENT_OUTPUT_MAX_BYTES,
        stderr_limit: RUST_ARCHIVE_SILENT_OUTPUT_MAX_BYTES,
        context: context,
        prohibit_descendants: true
      )
      archive_handle.fetch("io").rewind
      validate_open_large_file_identity(archive_handle, context)
      raise Failure, "#{context} extraction failed" unless
        status.success? && stdout.empty? && stderr.empty?

      actual = []
      extracted_bytes = 0
      Dir.glob(
        File.join(directory, "**", "*"),
        File::FNM_DOTMATCH
      ).sort_by(&:b).each do |path|
        next if [".", ".."].include?(File.basename(path))

        stat = File.lstat(path)
        raise Failure, "#{context} extraction produced a symlink" if
          stat.symlink?
        next if stat.directory?
        raise Failure, "#{context} extraction produced a non-file" unless
          stat.file? && stat.nlink == 1
        extracted_bytes = bounded_rust_extraction_bytes(
          extracted_bytes,
          stat.size,
          context
        )
        actual << path.delete_prefix("#{directory}/")
      end
      raise Failure, "#{context} extracted path set differs" unless
        actual == members.sort_by(&:b)

      contents = relative_members.to_h do |path|
        [path, File.binread(File.join(directory, root, path))]
      end
    end
    contents
  rescue Errno::ENOENT => error
    raise Failure, "#{context} extraction input missing: #{error.class}"
  end

  def rust_archive_member_list(members, context)
    raise Failure, "#{context} member inventory is empty" if members.empty?
    raise Failure, "#{context} member inventory contains duplicates" unless
      members.uniq.length == members.length
    raise Failure, "#{context} member inventory is excessive" if
      members.length >
        RUST_REGISTRY_CONTENT_LIMITS.fetch("max_files_per_closure")
    members.each do |member|
      validate_relative_path(member, context)
      raise Failure, "#{context} member path is too deeply nested" if
        member.split("/").length >
          RUST_REGISTRY_CONTENT_LIMITS.fetch("max_archive_path_depth")
    end

    list = members.sort_by(&:b).join("\0") + "\0"
    raise Failure, "#{context} extraction list is excessive" if
      list.bytesize >
        RUST_REGISTRY_CONTENT_LIMITS.fetch("max_extraction_list_bytes")
    list
  end

  def bounded_rust_extraction_bytes(total, file_bytes, context)
    raise Failure, "#{context} extraction produced an excessive file" if
      file_bytes >
        RUST_REGISTRY_CONTENT_LIMITS.fetch("max_bytes_per_file")
    next_total = total + file_bytes
    raise Failure, "#{context} extraction is excessive" if
      next_total >
        RUST_REGISTRY_CONTENT_LIMITS.fetch("max_bytes_per_closure")
    next_total
  end

  def rust_registry_content_vocabulary_sha256
    rows = RUST_REGISTRY_CONTENT_WITNESS_RULES.map do |rule|
      rejection = RUST_ORIGIN_REJECTION_PATTERNS[rule.fetch("id")]
      [
        rule.fetch("id"),
        rule.fetch("classification"),
        rule.fetch("pattern").source,
        rule.fetch("pattern").options,
        RUST_REGISTRY_CONTENT_PREFILTERS.fetch(rule.fetch("id")),
        rejection&.source,
        rejection&.options
      ]
    end
    semantic_digest(rows)
  end

  def rust_registry_content_scan(directory, files, checksums)
    raise Failure, "P13 Rust registry content file set differs: #{directory}" unless
      files.keys.sort_by(&:b) == checksums.keys.sort_by(&:b)
    raise Failure, "P13 Rust registry package file count is excessive: #{directory}" if
      files.length >
        RUST_REGISTRY_CONTENT_LIMITS.fetch("max_files_per_package")

    file_rows = []
    witness_rows = []
    file_bytes = 0
    files.keys.sort_by(&:b).each do |path|
      bytes = files.fetch(path)
      full_path = "#{directory}/#{path}"
      raise Failure, "P13 Rust registry content file is excessive: #{full_path}" if
        bytes.bytesize >
          RUST_REGISTRY_CONTENT_LIMITS.fetch("max_bytes_per_file")
      sha256 = Digest::SHA256.hexdigest(bytes)
      raise Failure, "P13 Rust registry content checksum differs: #{full_path}" unless
        sha256 == checksums.fetch(path)
      file_bytes = bounded_rust_extraction_bytes(
        file_bytes,
        bytes.bytesize,
        "P13 Rust registry content: #{directory}"
      )
      file_rows << [full_path, bytes.bytesize, sha256]

      file_witnesses = rust_registry_content_witness_rows(
        full_path,
        bytes,
        bytes.bytesize,
        sha256
      )
      raise Failure, "P13 Rust registry witness count is excessive: #{directory}" if
        witness_rows.length + file_witnesses.length >
          RUST_REGISTRY_CONTENT_LIMITS.fetch("max_witnesses_per_closure")
      witness_rows.concat(file_witnesses)
    end
    {
      "file_rows" => file_rows,
      "witness_rows" => witness_rows
    }
  rescue KeyError => error
    raise Failure, "P13 Rust registry content scan field missing: #{error.key}"
  end

  def rust_registry_content_witness_rows(path, bytes, file_bytes, file_sha256)
    max_witnesses =
      RUST_REGISTRY_CONTENT_LIMITS.fetch("max_witnesses_per_file")
    max_span_lines =
      RUST_REGISTRY_CONTENT_LIMITS.fetch("max_witness_span_lines")
    line_starts = [0]
    bytes.each_byte.with_index do |byte, index|
      line_starts << index + 1 if byte == 10 && index + 1 < bytes.bytesize
    end
    rows = []
    observed = {}
    folded = bytes.downcase
    RUST_REGISTRY_CONTENT_WITNESS_RULES.each do |rule|
      next unless
        RUST_REGISTRY_CONTENT_PREFILTERS.fetch(rule.fetch("id")).any? do |needle|
          folded.include?(needle)
        end

      offset = 0
      while (match = rule.fetch("pattern").match(bytes, offset))
        if rust_origin_witness_rejected?(rule.fetch("id"), bytes, match)
          offset = match.end(0)
          offset += 1 if offset == match.begin(0)
          next
        end
        start_index = line_index_for_offset(line_starts, match.begin(0))
        end_index = line_index_for_offset(
          line_starts,
          [match.end(0) - 1, match.begin(0)].max
        )
        raise Failure, "P13 Rust registry witness span is excessive: #{path}" if
          end_index - start_index + 1 > max_span_lines
        key = [start_index, rule.fetch("id")]
        unless observed[key]
          raise Failure, "P13 Rust registry file witness count is excessive: #{path}" if
            rows.length >= max_witnesses
          statement_end =
            line_starts.fetch(end_index + 1, bytes.bytesize)
          statement = bytes.byteslice(
            line_starts.fetch(start_index),
            statement_end - line_starts.fetch(start_index)
          )
          observed[key] = true
          rows << [
            path,
            file_bytes,
            file_sha256,
            start_index + 1,
            Digest::SHA256.hexdigest(statement),
            rule.fetch("id")
          ]
        end
        offset = match.end(0)
        offset += 1 if offset == match.begin(0)
      end
    end
    rows.sort_by { |row| [row.fetch(3), row.fetch(5).b] }
  end

  def rust_origin_witness_rejected?(rule_id, bytes, match)
    pattern = RUST_ORIGIN_REJECTION_PATTERNS[rule_id]
    return false unless pattern

    line_end = bytes.index("\n", match.end(0)) || bytes.bytesize
    finish = [line_end, match.end(0) + 192].min
    if match[0].match?(/[.!?;][ \t]*\z/n)
      finish = match.end(0)
    else
      statement_end = bytes.index(/[.!?;]/n, match.end(0))
      finish = [finish, statement_end + 1].min if
        statement_end && statement_end < finish
    end
    window = bytes.byteslice(
      match.begin(0),
      finish - match.begin(0)
    )
    normalized = window.gsub(
      /\r?\n[ \t]*(?:(?:\/\/[\/!]?)|(?:\/?\*)|\#|--|;)?[ \t]*/,
      " "
    )
    normalized.match?(pattern)
  end

  def line_index_for_offset(line_starts, offset)
    following = line_starts.bsearch_index { |line_start| line_start > offset }
    following ? following - 1 : line_starts.length - 1
  end

  def rust_registry_content_witness_inventory_digest(rows)
    canonical = rows.sort_by do |row|
      [row.fetch(0).b, row.fetch(3), row.fetch(5).b]
    end.map do |path, bytes, sha256, line, line_sha256, rule|
      [
        path,
        bytes.to_s,
        sha256,
        line.to_s,
        line_sha256,
        rule
      ].join("\0")
    end
    Digest::SHA256.hexdigest(canonical.join("\n") + "\n")
  end

  def validate_rust_registry_licenses(
    record,
    package_sets,
    registry_entries,
    approved_license_ids
  )
    closures = record.fetch("registry_closures")
    raise Failure, "P13 Rust registry closure set differs" unless
      closures.keys == RUST_REGISTRY_ROOTS.keys
    raise Failure, "P13 Rust registry extracted closure set differs" unless
      registry_entries.keys == RUST_REGISTRY_ROOTS.keys

    package_sets.each do |closure, packages|
      expected = closures.fetch(closure)
      vendor_root = RUST_REGISTRY_ROOTS.fetch(closure)
      registry_packages = rust_registry_packages(packages, closure)
      path_packages = packages.reject { |package| package.fetch("source") }
      raise Failure, "P13 Rust registry closure counts differ: #{closure}" unless
        expected.fetch("lock_path") ==
          (closure == "compiler_and_clippy" ? "Cargo.lock" : "library/Cargo.lock") &&
        expected.fetch("vendor_root") == vendor_root &&
        expected.fetch("package_count") == packages.length &&
        expected.fetch("path_package_count") == path_packages.length &&
        expected.fetch("registry_package_count") == registry_packages.length
      raise Failure, "P13 Rust registry package count is excessive: #{closure}" if
        registry_packages.length >
          RUST_REGISTRY_CONTENT_LIMITS.fetch("max_packages_per_closure")

      expected_identities = registry_packages.map do |package|
        rust_registry_identity(package)
      end
      entries = registry_entries.fetch(closure)
      raise Failure, "P13 Rust registry entry set differs: #{closure}" unless
        entries.keys.sort_by { |identity| identity.join("\0").b } ==
          expected_identities.sort_by { |identity| identity.join("\0").b }

      tuple_rows = registry_packages.map do |package|
        package.values_at("name", "version", "source", "checksum")
      end.sort_by { |row| row.map(&:b) }
      tuple_digest = Digest::SHA256.hexdigest(
        tuple_rows.map { |row| row.join("\0") }.join("\n") + "\n"
      )
      raise Failure, "P13 Rust registry tuple inventory differs: #{closure}" unless
        tuple_digest == expected.fetch("lock_tuple_inventory_sha256")

      manifest_rows = []
      checksum_rows = []
      legal_rows = []
      legacy_legal_rows = []
      reviewed_legal_delta_rows = []
      content_file_rows = []
      content_witness_rows = []
      expression_counts = Hash.new(0)
      registry_packages.each do |package|
        entry = entries.fetch(rust_registry_identity(package))
        directory = rust_registry_package_directory(vendor_root, package)
        manifest = entry.fetch("manifest")
        checksum = entry.fetch("checksum")
        context = "#{closure} #{package.fetch('name')} #{package.fetch('version')}"
        raise Failure, "P13 Rust registry directory differs: #{context}" unless
          entry.fetch("directory") == directory

        manifest_name = package_toml_string(manifest, "name", context)
        manifest_version = package_toml_string(manifest, "version", context)
        license = package_toml_string(manifest, "license", context)
        raise Failure, "P13 Rust registry manifest identity differs: #{context}" unless
          manifest_name == package.fetch("name") &&
          manifest_version == package.fetch("version")
        raise Failure, "P13 Rust registry license-file is unsupported: #{context}" if
          package_toml_optional_string(manifest, "license-file", context)
        validate_rust_license_election(license, approved_license_ids)
        expression_counts[license] += 1

        checksum_document = rust_checksum_document(checksum, context)
        raise Failure, "P13 Rust registry package checksum differs: #{context}" unless
          checksum_document.fetch("package") == package.fetch("checksum")
        file_checksums = checksum_document.fetch("files")
        raise Failure, "P13 Rust registry manifest checksum differs: #{context}" unless
          file_checksums.fetch("Cargo.toml") ==
            Digest::SHA256.hexdigest(manifest)
        content_scan = validate_rust_registry_content_observation(
          entry.fetch("content_scan"),
          directory,
          file_checksums,
          context
        )
        content_file_rows.concat(content_scan.fetch("file_rows"))
        content_witness_rows.concat(content_scan.fetch("witness_rows"))

        legal_paths = file_checksums.keys.select do |path|
          rust_registry_legal_file_path?(path)
        end.sort_by(&:b)
        legacy_legal_paths = file_checksums.keys.select do |path|
          File.basename(path).match?(ORIGIN_LEGAL_FILE_PATTERN)
        end
        legal_files = entry.fetch("legal_files")
        raise Failure, "P13 Rust registry legal file set differs: #{context}" unless
          entry.fetch("legal_paths") == legal_paths &&
          legal_files.keys.sort_by(&:b) == legal_paths
        legal_paths.each do |path|
          bytes = legal_files.fetch(path)
          raise Failure, "P13 Rust registry legal checksum differs: #{context}" unless
            Digest::SHA256.hexdigest(bytes) == file_checksums.fetch(path)
          row = [
            "#{directory}/#{path}",
            bytes.bytesize,
            Digest::SHA256.hexdigest(bytes)
          ]
          legal_rows << row
          if legacy_legal_paths.include?(path)
            legacy_legal_rows << row
          else
            reviewed_legal_delta_rows << row
          end
        end
        manifest_rows << [
          "#{directory}/Cargo.toml",
          manifest.bytesize,
          Digest::SHA256.hexdigest(manifest)
        ]
        checksum_rows << [
          "#{directory}/.cargo-checksum.json",
          checksum.bytesize,
          Digest::SHA256.hexdigest(checksum)
        ]
      end

      raise Failure, "P13 Rust registry manifest inventory differs: #{closure}" unless
        rust_file_inventory_digest(manifest_rows) ==
          expected.fetch("cargo_manifest_inventory_sha256")
      raise Failure, "P13 Rust registry checksum inventory differs: #{closure}" unless
        rust_file_inventory_digest(checksum_rows) ==
          expected.fetch("cargo_checksum_inventory_sha256")
      raise Failure, "P13 Rust registry legal count differs: #{closure}" unless
        legal_rows.length == expected.fetch("legal_file_count")
      raise Failure, "P13 Rust registry legal bytes differ: #{closure}" unless
        legal_rows.inject(0) { |sum, row| sum + row.fetch(1) } ==
          expected.fetch("legal_file_bytes")
      raise Failure, "P13 Rust registry legal inventory differs: #{closure}" unless
        rust_file_inventory_digest(legal_rows) ==
          expected.fetch("legal_file_inventory_sha256")
      validate_rust_registry_legal_dispositions(
        expected,
        legacy_legal_rows,
        reviewed_legal_delta_rows,
        closure
      )
      validate_rust_registry_content_discovery(
        expected.fetch("content_discovery"),
        content_file_rows,
        content_witness_rows,
        closure,
        expected_reachability: rust_registry_reachability(
          record,
          packages,
          registry_packages,
          vendor_root,
          closure
        )
      )
      raise Failure, "P13 Rust registry license counts differ: #{closure}" unless
        expression_counts == expected.fetch("license_expression_counts")
    end
    true
  rescue KeyError => error
    raise Failure, "P13 Rust registry license field missing: #{error.key}"
  end

  def validate_rust_registry_content_observation(
    scan,
    directory,
    checksums,
    context
  )
    raise Failure, "P13 Rust registry content observation fields differ: #{context}" unless
      scan.keys.sort_by(&:b) == %w[file_rows witness_rows]
    file_rows = scan.fetch("file_rows")
    witness_rows = scan.fetch("witness_rows")
    expected_paths = checksums.keys.map { |path| "#{directory}/#{path}" }.sort_by(&:b)
    raise Failure, "P13 Rust registry content observation count differs: #{context}" if
      file_rows.length >
        RUST_REGISTRY_CONTENT_LIMITS.fetch("max_files_per_package")
    raise Failure, "P13 Rust registry content observation set differs: #{context}" unless
      file_rows.map { |row| row.fetch(0) }.sort_by(&:b) == expected_paths

    identities = {}
    file_rows.each do |path, bytes, sha256|
      relative = path.delete_prefix("#{directory}/")
      raise Failure, "P13 Rust registry content observation path differs: #{context}" unless
        path.start_with?("#{directory}/") && checksums.key?(relative)
      raise Failure, "P13 Rust registry content observation size differs: #{context}" unless
        bytes.is_a?(Integer) && bytes >= 0 &&
        bytes <= RUST_REGISTRY_CONTENT_LIMITS.fetch("max_bytes_per_file")
      raise Failure, "P13 Rust registry content observation hash differs: #{context}" unless
        sha256 == checksums.fetch(relative)
      raise Failure, "P13 Rust registry content observation is duplicated: #{context}" if
        identities.key?(path)
      identities[path] = [bytes, sha256]
    end

    rule_ids = RUST_REGISTRY_CONTENT_WITNESS_RULES.map { |rule| rule.fetch("id") }
    raise Failure, "P13 Rust registry witness count is excessive: #{context}" if
      witness_rows.length >
        RUST_REGISTRY_CONTENT_LIMITS.fetch("max_witnesses_per_file") *
          file_rows.length
    witness_rows.each do |path, bytes, sha256, line, line_sha256, rule|
      raise Failure, "P13 Rust registry witness file differs: #{context}" unless
        identities.fetch(path) == [bytes, sha256]
      raise Failure, "P13 Rust registry witness line differs: #{context}" unless
        line.is_a?(Integer) && line.positive? &&
        line_sha256.is_a?(String) &&
        line_sha256.match?(/\A[0-9a-f]{64}\z/)
      raise Failure, "P13 Rust registry witness rule differs: #{context}" unless
        rule_ids.include?(rule)
    end
    raise Failure, "P13 Rust registry witness observation is duplicated: #{context}" unless
      witness_rows.uniq.length == witness_rows.length
    scan
  rescue KeyError => error
    raise Failure, "P13 Rust registry content observation field missing: #{error.key}"
  end

  def validate_rust_registry_content_discovery(
    expected,
    file_rows,
    witness_rows,
    closure,
    expected_reachability: nil
  )
    raise Failure, "P13 Rust registry content discovery fields differ: #{closure}" unless
      expected.keys.sort_by(&:b) == %w[
        file_bytes
        file_count
        file_inventory_sha256
        limits
        scope
        vocabulary_sha256
        vocabulary_version
        witness_count
        witness_dispositions
        witness_file_count
        witness_file_inventory_sha256
        witness_inventory_sha256
      ].sort_by(&:b)
    raise Failure, "P13 Rust registry content discovery contract differs: #{closure}" unless
      expected.fetch("vocabulary_version") ==
        RUST_REGISTRY_CONTENT_DISCOVERY_VERSION &&
      expected.fetch("vocabulary_sha256") ==
        rust_registry_content_vocabulary_sha256 &&
      expected.fetch("scope") == RUST_REGISTRY_CONTENT_DISCOVERY_SCOPE &&
      expected.fetch("limits") == RUST_REGISTRY_CONTENT_LIMITS
    raise Failure, "P13 Rust registry content file count is excessive: #{closure}" if
      file_rows.length >
        RUST_REGISTRY_CONTENT_LIMITS.fetch("max_files_per_closure")
    file_bytes = file_rows.sum { |row| row.fetch(1) }
    raise Failure, "P13 Rust registry content bytes are excessive: #{closure}" if
      file_bytes >
        RUST_REGISTRY_CONTENT_LIMITS.fetch("max_bytes_per_closure")
    raise Failure, "P13 Rust registry content inventory differs: #{closure}" unless
      expected.fetch("file_count") == file_rows.length &&
      expected.fetch("file_bytes") == file_bytes &&
      expected.fetch("file_inventory_sha256") ==
        rust_file_inventory_digest(file_rows)
    raise Failure, "P13 Rust registry content witness count is excessive: #{closure}" if
      witness_rows.length >
        RUST_REGISTRY_CONTENT_LIMITS.fetch("max_witnesses_per_closure")

    witness_files = witness_rows.map do |row|
      row.values_at(0, 1, 2)
    end.uniq
    raise Failure, "P13 Rust registry content witness inventory differs: #{closure}" unless
      expected.fetch("witness_count") == witness_rows.length &&
      expected.fetch("witness_inventory_sha256") ==
        rust_registry_content_witness_inventory_digest(witness_rows) &&
      expected.fetch("witness_file_count") == witness_files.length &&
      expected.fetch("witness_file_inventory_sha256") ==
        rust_file_inventory_digest(witness_files)
    validate_rust_registry_content_dispositions(
      expected.fetch("witness_dispositions"),
      witness_rows,
      closure,
      expected_reachability: expected_reachability
    )
    true
  rescue KeyError => error
    raise Failure, "P13 Rust registry content discovery field missing: #{error.key}"
  end

  def validate_rust_registry_content_dispositions(
    dispositions,
    witness_rows,
    closure,
    expected_reachability: nil
  )
    grouped = witness_rows.group_by { |row| row.fetch(0) }
    observed = grouped.map do |path, rows|
      {
        "path" => path,
        "bytes" => rows.first.fetch(1),
        "sha256" => rows.first.fetch(2),
        "witness_rule_ids" =>
          rows.map { |row| row.fetch(5) }.uniq.sort_by(&:b)
      }
    end.sort_by { |record| record.fetch("path").b }
    raise Failure, "P13 Rust registry content disposition count differs: #{closure}" unless
      dispositions.length == observed.length

    identities = dispositions.map do |record|
      raise Failure, "P13 Rust registry content disposition fields differ: #{closure}" unless
        record.keys.sort_by(&:b) == %w[
          bytes
          disposition
          path
          reachability
          rights
          rights_status
          sha256
          witness_rule_ids
        ].sort_by(&:b)
      %w[rights rights_status reachability disposition].each do |field|
        value = record.fetch(field)
        raise Failure, "P13 Rust registry content disposition is unresolved: #{closure}" unless
          value.is_a?(String) &&
          value.match?(/\A[A-Z0-9][A-Z0-9_.+-]*(?:_[A-Z0-9_.+-]+)*\z/) &&
          !value.match?(/(?:PENDING|UNKNOWN|UNRESOLVED)/)
      end
      semantic_tuple = record.values_at(
        "rights",
        "rights_status",
        "reachability",
        "disposition"
      )
      raise Failure, "P13 Rust registry content disposition is unsupported: #{closure}" unless
        RUST_REGISTRY_CONTENT_DISPOSITION_TUPLES.include?(semantic_tuple)
      copied_source = RUST_COPIED_SOURCE_DISPOSITIONS[record.fetch("path")]
      raise Failure, "P13 copied-source disposition differs: #{record.fetch('path')}" if
        copied_source && semantic_tuple != copied_source
      if expected_reachability
        directories = expected_reachability.keys.select do |directory|
          record.fetch("path").start_with?("#{directory}/")
        end
        raise Failure, "P13 Rust disposition package identity differs: #{closure}" unless
          directories.length == 1
        raise Failure, "P13 Rust disposition reachability differs: #{closure}" unless
          record.fetch("reachability") ==
            expected_reachability.fetch(directories.fetch(0))
      end
      validate_rust_content_disposition_rules(
        record.fetch("rights"),
        record.fetch("witness_rule_ids"),
        closure
      )
      record.slice("path", "bytes", "sha256", "witness_rule_ids")
    end.sort_by { |record| record.fetch("path").b }
    raise Failure, "P13 Rust registry content disposition set differs: #{closure}" unless
      identities == observed
    true
  rescue KeyError => error
    raise Failure, "P13 Rust registry content disposition field missing: #{error.key}"
  end

  def rust_registry_reachability(
    record,
    packages,
    registry_packages,
    vendor_root,
    closure
  )
    active =
      if closure == "compiler_and_clippy" &&
          record.key?("active_lock_graph")
        roots = record.fetch("active_lock_graph").fetch("roots")
        rust_lock_reachable_packages(
          packages,
          roots,
          "P13 Rust registry reachability"
        ).select { |package| package.fetch("source") }
      else
        registry_packages
      end
    active_identities = active.map do |package|
      rust_registry_identity(package)
    end.to_set
    registry_packages.to_h do |package|
      directory = rust_registry_package_directory(vendor_root, package)
      reachability =
        if active_identities.include?(rust_registry_identity(package))
          "ACTIVE_LOCK_GRAPH_ONLY_NATIVE_FILE_REACHABILITY_DEFERRED_TO_P14"
        else
          "UNREACHABLE_FROM_SELECTED_LOCK_GRAPH"
        end
      [directory, reachability]
    end
  end

  def validate_rust_content_disposition_rules(rights, rules, closure)
    witness_class =
      if rules.any? do |rule|
        rule.start_with?("RESTRICTIVE_") ||
          rule.start_with?("NONSTANDARD_")
      end
        "RESTRICTIVE_OR_NONSTANDARD"
      elsif rules.any? { |rule| rule.start_with?("ORIGIN_") }
        "ORIGIN"
      elsif rules.any? { |rule| rule.start_with?("ALTERNATIVE_") }
        "ALTERNATIVE"
      else
        "PERMISSIVE"
      end
    rights_by_class = {
      "RESTRICTIVE_OR_NONSTANDARD" => %w[
        PACKAGE_OSI_ELECTION_OR_EXCLUDED_PATH
        RUST_SOURCE_INTEL_CPUID_RESTRICTIVE_TERMS
      ],
      "ORIGIN" => %w[
        IMMUTABLE_HYPERIUM_HTTP_MIT_OR_APACHE_2_0_ORIGIN
        PACKAGE_GRANT_AND_RETAINED_ORIGIN_NOTICE
        RUST_SOURCE_LICENSE_METADATA_AND_RETAINED_ORIGIN_NOTICE
      ],
      "ALTERNATIVE" => %w[
        IMMUTABLE_REDWOOD_GPL_SOURCE_AND_AUTHOR_RELICENSE_GRANT
        PACKAGE_OSI_LICENSE_ELECTION
        RUST_SOURCE_GPL_3_OR_LATER_WITH_GCC_EXCEPTION_3_1
        RUST_SOURCE_OSI_ELECTION_OR_EXCEPTION
      ],
      "PERMISSIVE" => %w[
        PERMISSIVE_GRANT_IN_CHECKSUM_BOUND_PACKAGE
        RUST_SOURCE_ROOT_AND_BUNDLED_OSI_GRANTS
      ]
    }
    raise Failure, "P13 Rust content disposition precedence differs: #{closure}" unless
      rights_by_class.fetch(witness_class).include?(rights)

    compatible = case rights
    when "PERMISSIVE_GRANT_IN_CHECKSUM_BOUND_PACKAGE",
         "RUST_SOURCE_ROOT_AND_BUNDLED_OSI_GRANTS"
      rules.all? { |rule| rule.start_with?("PERMISSIVE_") }
    when "PACKAGE_GRANT_AND_RETAINED_ORIGIN_NOTICE",
         "RUST_SOURCE_LICENSE_METADATA_AND_RETAINED_ORIGIN_NOTICE",
         "IMMUTABLE_HYPERIUM_HTTP_MIT_OR_APACHE_2_0_ORIGIN"
      rules.any? { |rule| rule.start_with?("ORIGIN_") }
    when "PACKAGE_OSI_LICENSE_ELECTION",
         "RUST_SOURCE_OSI_ELECTION_OR_EXCEPTION",
         "IMMUTABLE_REDWOOD_GPL_SOURCE_AND_AUTHOR_RELICENSE_GRANT"
      rules.any? { |rule| rule.start_with?("ALTERNATIVE_") }
    when "RUST_SOURCE_GPL_3_OR_LATER_WITH_GCC_EXCEPTION_3_1"
      rules.include?(
        "ALTERNATIVE_GPL_3_OR_LATER_WITH_GCC_EXCEPTION_3_1"
      )
    when "RUST_SOURCE_INTEL_CPUID_RESTRICTIVE_TERMS"
      rules.include?("RESTRICTIVE_PRIOR_WRITTEN_PERMISSION")
    when "PACKAGE_OSI_ELECTION_OR_EXCLUDED_PATH"
      rules.any? do |rule|
        rule.start_with?("NONSTANDARD_") ||
          rule.start_with?("RESTRICTIVE_")
      end
    else
      false
    end
    raise Failure, "P13 Rust content disposition rules differ: #{closure}" unless
      compatible
    true
  end

  def rust_registry_packages(packages, context)
    registry = []
    packages.each do |package|
      name = package.fetch("name")
      version = package.fetch("version")
      source = package.fetch("source")
      checksum = package.fetch("checksum")
      raise Failure, "P13 Rust package name is malformed: #{context}" unless
        name.match?(/\A[A-Za-z0-9_-]+\z/)
      raise Failure, "P13 Rust package version is malformed: #{context}" unless
        version.match?(/\A[0-9A-Za-z.+-]+\z/)
      if source.nil?
        raise Failure, "P13 Rust path package has a checksum: #{context}" if checksum
      else
        raise Failure, "P13 Rust registry source differs: #{context}" unless
          source == RUST_REGISTRY_SOURCE
        raise Failure, "P13 Rust registry checksum is malformed: #{context}" unless
          checksum&.match?(/\A[0-9a-f]{64}\z/)
        registry << package
      end
    end
    identities = registry.map { |package| rust_registry_identity(package) }
    raise Failure, "P13 Rust registry identity is duplicated: #{context}" unless
      identities.uniq.length == identities.length
    registry
  rescue KeyError => error
    raise Failure, "P13 Rust lock package field missing: #{error.key}"
  end

  def rust_registry_identity(package)
    package.values_at("name", "version")
  end

  def rust_registry_legal_file_path?(path)
    components = path.split("/", -1)
    return false if
      components.empty? ||
      components.any?(&:empty?) ||
      components.any? { |component| [".", ".."].include?(component) }

    basename = components.pop
    basename.match?(ORIGIN_LEGAL_FILE_PATTERN) ||
      basename.match?(RUST_REGISTRY_LEGAL_BASENAME_PATTERN) ||
      basename.match?(RUST_REGISTRY_ADDITIONAL_LEGAL_BASENAME_PATTERN) ||
      components.any? do |component|
        component.match?(RUST_REGISTRY_LEGAL_DIRECTORY_PATTERN)
      end
  end

  def validate_rust_registry_legal_dispositions(
    expected,
    legacy_rows,
    delta_rows,
    closure
  )
    dispositions = if expected.key?("reviewed_legal_file_dispositions")
      raise Failure, "P13 Rust registry legal disposition scope differs" unless
        closure == "compiler_and_clippy"
      expected.fetch("reviewed_legal_file_dispositions")
    else
      []
    end
    raise Failure, "P13 Rust registry legal disposition set differs: #{closure}" unless
      dispositions.empty? ||
      dispositions == RUST_REVIEWED_LEGAL_FILE_DISPOSITIONS

    disposition_rows = dispositions.map do |record|
      record.values_at("path", "bytes", "sha256")
    end.sort_by { |row| row.fetch(0).b }
    rows = delta_rows.sort_by { |row| row.fetch(0).b }
    raise Failure, "P13 Rust registry reviewed legal delta differs: #{closure}" unless
      rows == disposition_rows

    if expected.key?("legacy_legal_file_count")
      raise Failure, "P13 Rust registry legacy legal inventory differs: #{closure}" unless
        expected.fetch("legacy_legal_file_count") == legacy_rows.length &&
        expected.fetch("legacy_legal_file_bytes") ==
          legacy_rows.sum { |row| row.fetch(1) } &&
        expected.fetch("legacy_legal_file_inventory_sha256") ==
          rust_file_inventory_digest(legacy_rows)
    end
    return true if dispositions.empty?

    raise Failure, "P13 Rust registry legal discovery evidence differs" unless
      expected.fetch("legacy_legal_file_count") == 981 &&
      expected.fetch("legacy_legal_file_bytes") == 5_289_737 &&
      expected.fetch("legacy_legal_file_inventory_sha256") ==
        "df0bc08bc587156189639b7fb3d546333825fc594032c83cb9d23afd27b63cd0" &&
      expected.fetch("reviewed_legal_delta_count") == dispositions.length &&
      expected.fetch("reviewed_legal_delta_bytes") ==
        disposition_rows.sum { |row| row.fetch(1) } &&
      expected.fetch("reviewed_legal_delta_inventory_sha256") ==
        rust_file_inventory_digest(disposition_rows)
    true
  rescue KeyError => error
    raise Failure, "P13 Rust registry legal disposition field missing: #{error.key}"
  end

  def rust_registry_package_directory(vendor_root, package)
    path = "#{vendor_root}/#{package.fetch('name')}-#{package.fetch('version')}"
    validate_relative_path(path, "P13 Rust registry package")
    path
  end

  def rust_checksum_document(bytes, context)
    document = parse_json(bytes, "P13 Rust registry checksum #{context}")
    raise Failure, "P13 Rust checksum fields differ: #{context}" unless
      document.keys.sort_by(&:b) == %w[$comment files package].sort_by(&:b) &&
      document.fetch("$comment") ==
        "This file only protects against accidental modifications. " \
        "It is not a security mechanism and does not protect against " \
        "malicious changes."
    files = document.fetch("files")
    package = document.fetch("package")
    raise Failure, "P13 Rust checksum file map is malformed: #{context}" unless
      files.is_a?(Hash) && !files.empty?
    raise Failure, "P13 Rust checksum package hash is malformed: #{context}" unless
      package.is_a?(String) && package.match?(/\A[0-9a-f]{64}\z/)
    files.each do |path, checksum|
      raise Failure, "P13 Rust checksum path is malformed: #{context}" unless
        path.is_a?(String) &&
        strict_text?(path) &&
        !path.match?(/[\x00-\x1f\x7f\\]/) &&
        validate_relative_path(path, "P13 Rust checksum #{context}")
      raise Failure, "P13 Rust file checksum is malformed: #{context}" unless
        checksum.is_a?(String) && checksum.match?(/\A[0-9a-f]{64}\z/)
    end
    raise Failure, "P13 Rust checksum lacks Cargo.toml: #{context}" unless
      files.key?("Cargo.toml")
    document
  rescue KeyError => error
    raise Failure, "P13 Rust checksum field missing: #{error.key}"
  end

  def rust_file_inventory_digest(rows)
    canonical = rows.sort_by { |row| row.fetch(0).b }.map do |path, bytes, sha256|
      raise Failure, "P13 Rust inventory path is malformed" unless
        validate_relative_path(path, "P13 Rust inventory")
      raise Failure, "P13 Rust inventory byte count is malformed" unless
        bytes.is_a?(Integer) && bytes >= 0
      raise Failure, "P13 Rust inventory hash is malformed" unless
        sha256.match?(/\A[0-9a-f]{64}\z/)
      [path, bytes.to_s, sha256].join("\0")
    end
    Digest::SHA256.hexdigest(canonical.join("\n") + "\n")
  end

  def validate_rust_notice_inventories(record, whole_notice, library_notice)
    inventories = record.fetch("notice_inventories")
    expected = {
      "complete_toolchain" => whole_notice,
      "standard_library" => library_notice
    }
    raise Failure, "P13 Rust notice inventory set differs" unless
      inventories.keys == expected.keys

    expected.each do |name, bytes|
      evidence = inventories.fetch(name)
      records = rust_notice_records(bytes, "P13 Rust notice #{name}")
      expressions = Hash.new(0)
      records.each do |row|
        expression = row.fetch(2)
        raise Failure, "P13 Rust notice license is unsupported: #{expression}" unless
          RUST_NOTICE_ALLOWED_EXPRESSIONS.include?(expression)
        expressions[expression] += 1
      end
      canonical = records.map { |row| row.join("\0") }.join("\n") + "\n"
      raise Failure, "P13 Rust notice record count differs: #{name}" unless
        records.length == evidence.fetch("record_count")
      raise Failure, "P13 Rust notice inventory differs: #{name}" unless
        Digest::SHA256.hexdigest(canonical) ==
          evidence.fetch("inventory_sha256")
      raise Failure, "P13 Rust notice expression counts differ: #{name}" unless
        expressions == evidence.fetch("license_expression_counts")
    end

    cc0 = rust_notice_records(
      whole_notice,
      "P13 complete Rust notice"
    ).select { |row| row.fetch(2) == "CC0-1.0" }
    raise Failure, "P13 Rust CC0-only notice allowlist differs" unless
      cc0.length == 1 &&
      cc0.first.fetch(0) == "out_of_tree" &&
      cc0.first.fetch(1).end_with?("notify-8.2.0") &&
      inventories.fetch("complete_toolchain")
        .fetch("sole_cc0_only_identity") == "notify-8.2.0" &&
      inventories.fetch("standard_library")
        .fetch("sole_cc0_only_identity").nil?
    true
  rescue KeyError => error
    raise Failure, "P13 Rust notice inventory field missing: #{error.key}"
  end

  def rust_notice_records(bytes, context)
    raise Failure, "#{context} is not strict UTF-8 text" unless strict_text?(bytes)
    current = nil
    records = []
    pattern = /
      <b>File\/Directory:<\/b>\s*<code>([^<]+)<\/code>
      | <h3>([^<]+)<\/h3>
      | <p><b>License:<\/b>\s*([^<]+)<\/p>
    /mx
    bytes.scan(pattern) do |file, package, license|
      if file || package
        raise Failure, "#{context} identity lacks a license" if current
        current = [file ? "in_tree" : "out_of_tree", (file || package).strip]
      else
        raise Failure, "#{context} license lacks an identity" unless current
        expression = license.strip
        raise Failure, "#{context} license expression is malformed" if
          expression.empty? || expression.match?(/[\x00-\x1f\x7f]/)
        records << [current.fetch(0), current.fetch(1), expression]
        current = nil
      end
    end
    raise Failure, "#{context} trailing identity lacks a license" if current
    raise Failure, "#{context} contains no license records" if records.empty?
    records
  end

  def validate_spdx_license_evidence(record, contents: nil)
    evidence = record.fetch("spdx_license_evidence")
    raise Failure, "P13 SPDX source evidence differs" unless
      evidence.fetch("provider") == "SPDX_Legal_Team" &&
      evidence.fetch("repository") ==
        "https://github.com/spdx/license-list-XML" &&
      evidence.fetch("local_origin_repository") ==
        "/private/tmp/p13-spdx-license-list-XML" &&
      evidence.fetch("commit") ==
        "24b4ed8996b5f8d3f91e51961b46803e9e356814" &&
      evidence.fetch("tree") ==
        "b96913f1e33b03c3da8666514f67452c657e0a17" &&
      evidence.fetch("license") == "CC0-1.0" &&
      evidence.fetch("files") == SPDX_LICENSE_FILES &&
      evidence.fetch("rejected_files") == SPDX_REJECTED_LICENSE_FILES &&
      evidence.fetch("result") ==
        "EXACT_OSI_APPROVAL_EXCEPTION_AND_REJECTION_METADATA_BOUND"

    rights_files = [
      {
        "path" => "schema/ListedLicense.xsd",
        "bytes" => 36_615,
        "git_blob" => "42990464bb8e5e94619288e6750ec3289dc4788f",
        "sha256" =>
          "14cb0133bdf26c6c16944e44ae3da2d7dcb3b5ed20d2ce75d21e7c9cea546531"
      },
      {
        "path" => "RELEASE-NOTES.md",
        "bytes" => 22_780,
        "git_blob" => "57d9f3f6a3c5fe42264fab4a4a639518fc710e84",
        "sha256" =>
          "fd21abfb8907ad04fcfc52ab1077717f17aa9b8a0c8224c5ad963324e436f0ed"
      }
    ]
    raise Failure, "P13 SPDX rights evidence differs" unless
      evidence.fetch("rights_files") == rights_files

    source_contents = contents || {}
    unless contents
      (
        SPDX_LICENSE_FILES +
        SPDX_REJECTED_LICENSE_FILES +
        rights_files
      ).each do |file|
        source_contents[file.fetch("path")] = git_evidence_file(
          root: evidence.fetch("local_origin_repository"),
          commit: evidence.fetch("commit"),
          tree: evidence.fetch("tree"),
          path: file.fetch("path"),
          blob: file.fetch("git_blob"),
          bytes: file.fetch("bytes"),
          sha256: file.fetch("sha256"),
          label: "P13 SPDX #{file.fetch('path')}"
        )
      end
    end
    schema = source_contents.fetch("schema/ListedLicense.xsd")
    notes = source_contents.fetch("RELEASE-NOTES.md")
    require_include(
      schema,
      "SPDX-License-Identifier: CC0-1.0",
      "P13 SPDX XML schema rights"
    )
    require_include(
      notes,
      "source files associated with SPDX License List " \
        "(.json, scheme, .js files) with CC0-1.0",
      "P13 SPDX source-data rights"
    )
    approved = validate_spdx_approval_fields(
      SPDX_LICENSE_FILES,
      source_contents
    )
    validate_spdx_rejection_fields(
      SPDX_REJECTED_LICENSE_FILES,
      source_contents
    )
    approved
  rescue KeyError => error
    raise Failure, "P13 SPDX source field missing: #{error.key}"
  end

  def validate_spdx_approval_fields(files, contents)
    expected_paths = files.map { |file| file.fetch("path") }
    missing = expected_paths.reject { |path| contents.key?(path) }
    raise Failure, "P13 SPDX selected file content is missing" unless
      missing.empty?

    files.to_h do |file|
      path = file.fetch("path")
      bytes = contents.fetch(path)
      if file.fetch("kind") == "license"
        tags = bytes.scan(/<license\b([^>]*)>/m)
        raise Failure, "P13 SPDX license root differs: #{path}" unless
          tags.length == 1
        attributes = xml_attributes(tags.first.first, path)
        raise Failure, "P13 SPDX license ID differs: #{path}" unless
          attributes.fetch("licenseId") == file.fetch("id")
        raise Failure, "P13 SPDX OSI approval differs: #{path}" unless
          attributes.fetch("isOsiApproved") == "true"
        [file.fetch("id"), "OSI_APPROVED"]
      elsif file.fetch("kind") == "exception"
        tags = bytes.scan(/<exception\b([^>]*)>/m)
        raise Failure, "P13 SPDX exception root differs: #{path}" unless
          tags.length == 1
        attributes = xml_attributes(tags.first.first, path)
        raise Failure, "P13 SPDX exception ID differs: #{path}" unless
          attributes.fetch("licenseId") == file.fetch("id") &&
          !attributes.key?("isOsiApproved")
        [file.fetch("id"), "SPDX_EXCEPTION"]
      else
        raise Failure, "P13 SPDX selected file kind differs: #{path}"
      end
    end
  rescue KeyError => error
    raise Failure, "P13 SPDX approval field missing: #{error.key}"
  end

  def validate_spdx_rejection_fields(files, contents)
    files.each do |file|
      path = file.fetch("path")
      bytes = contents.fetch(path)
      tags = bytes.scan(/<license\b([^>]*)>/m)
      raise Failure, "P13 SPDX rejected license root differs: #{path}" unless
        tags.length == 1
      attributes = xml_attributes(tags.first.first, path)
      raise Failure, "P13 SPDX rejected license evidence differs: #{path}" unless
        file.fetch("kind") == "license" &&
        attributes.fetch("licenseId") == file.fetch("id") &&
        attributes.fetch("isOsiApproved") == "false"
    end
    true
  rescue KeyError => error
    raise Failure, "P13 SPDX rejected license field missing: #{error.key}"
  end

  def xml_attributes(bytes, context)
    pairs = bytes.scan(/([A-Za-z][A-Za-z0-9:_-]*)="([^"]*)"/m)
    raise Failure, "P13 SPDX XML attribute syntax differs: #{context}" if
      pairs.empty? || pairs.map(&:first).uniq.length != pairs.length
    pairs.to_h
  end

  def validate_installed_rust_exclusions(record)
    installed = File.join(ROOT, ".tools/rust-1.98.0")
    paths = Dir.glob(
      File.join(installed, "**", "*"),
      File::FNM_DOTMATCH
    ).reject { |path| [".", ".."].include?(File.basename(path)) }
    notify_paths = paths.select do |path|
      path.delete_prefix("#{installed}/").downcase.split("/").any? do |part|
        part == "notify" || part.start_with?("notify-")
      end
    end
    raise Failure, "P13 notify software is installed" unless
      notify_paths.empty? && record.fetch("installed_notify_path_count") == 0

    analyzer_paths = paths.select do |path|
      path.delete_prefix("#{installed}/").downcase.include?("rust-analyzer")
    end
    expected_paths = RUST_UNSELECTED_HELPERS.map do |helper|
      File.join(ROOT, helper.fetch("path"))
    end
    raise Failure, "P13 installed rust-analyzer helper set differs" unless
      analyzer_paths == expected_paths
    RUST_UNSELECTED_HELPERS.each do |helper|
      verify_file(
        File.join(ROOT, helper.fetch("path")),
        bytes: helper.fetch("bytes"),
        sha256: helper.fetch("sha256"),
        context: "P13 unselected rust-analyzer helper"
      )
    end
    selected_paths = COMMAND_WINDOW_FILES.map { |item| item.fetch("path") } +
      COMMAND_WINDOW_TREES.map { |item| item.fetch("path") }
    raise Failure, "P13 rust-analyzer helper reached selected tool set" unless
      (selected_paths & RUST_UNSELECTED_HELPERS.map { |item| item.fetch("path") })
        .empty?
    true
  rescue KeyError => error
    raise Failure, "P13 installed Rust exclusion field missing: #{error.key}"
  end

  def validate_rust_in_tree_licenses(record, bytes, approved_license_ids)
    metadata = record.fetch("license_metadata")
    raise Failure, "P13 Rust license-metadata evidence differs" unless
      metadata.fetch("path") == "license-metadata.json" &&
      metadata.fetch("bytes") == 9_198 &&
      metadata.fetch("sha256") ==
        "7bed295fb8d5ddc54ef9e7c795b18207d8da747513ae83fce9748e840200b40c" &&
      metadata.fetch("selected_prefixes") ==
        %w[compiler/ library/ src/tools/clippy/ src/llvm-project/] &&
      metadata.fetch("selected_record_count") == 8 &&
      metadata.fetch("selected_inventory_sha256") ==
        "a184c5e66602e82270313a975b24be4c5fad1e09dadd37e94c03370c275b57d7"

    document = parse_json(bytes, "P13 Rust license-metadata")
    rows = []
    Array(document.fetch("files").fetch("children")).each do |node|
      rust_license_metadata_rows(node, nil, rows)
    end
    selected = rows.select do |row|
      path = row.fetch("path")
      path == "." ||
        metadata.fetch("selected_prefixes").any? do |prefix|
          path == prefix.chomp("/") || path.start_with?(prefix)
        end
    end
    canonical = selected.map do |row|
      row.values_at("type", "path", "spdx").join("\0")
    end.sort_by(&:b)
    raise Failure, "P13 Rust selected license-metadata closure differs" unless
      selected.length == metadata.fetch("selected_record_count") &&
      Digest::SHA256.hexdigest(canonical.join("\n") + "\n") ==
        metadata.fetch("selected_inventory_sha256")
    selected.each do |row|
      validate_rust_license_election(row.fetch("spdx"), approved_license_ids)
    end
    true
  rescue KeyError => error
    raise Failure, "P13 Rust license-metadata field missing: #{error.key}"
  end

  def rust_license_metadata_rows(node, parent, rows)
    raise Failure, "P13 Rust license-metadata node is not a mapping" unless
      node.is_a?(Hash)
    name = node["name"]
    path = if name == "."
      "."
    elsif parent.nil? || parent == "." || name.to_s.include?("/")
      name
    else
      "#{parent}/#{name}"
    end
    if node.key?("license")
      raise Failure, "P13 Rust license-metadata path is malformed" unless
        path.is_a?(String) && (path == "." || validate_relative_path(
          path,
          "P13 Rust license-metadata"
        ))
      rows << {
        "type" => node.fetch("type"),
        "path" => path,
        "spdx" => node.fetch("license").fetch("spdx")
      }
    end
    Array(node["children"]).each do |child|
      rust_license_metadata_rows(child, path, rows)
    end
    rows
  end

  def validate_rust_license_election(expression, approved_license_ids)
    selected = RUST_LICENSE_ELECTIONS[expression]
    raise Failure, "P13 Rust license expression is not approved: #{expression}" unless
      selected
    selected.each do |identifier|
      expected = identifier == "LLVM-exception" ?
        "SPDX_EXCEPTION" : "OSI_APPROVED"
      raise Failure, "P13 Rust elected license is not approved: #{identifier}" unless
        approved_license_ids.fetch(identifier) == expected
    end
    raise Failure, "P13 Rust elected CC0 software" if selected.include?("CC0-1.0")
    selected
  rescue KeyError => error
    raise Failure, "P13 Rust elected license evidence missing: #{error.key}"
  end

  def symbolize_file_identity(record)
    {
      bytes: record.fetch("bytes"),
      sha256: record.fetch("sha256")
    }
  end

  def validate_toolchain_source_provenance(record, provenance: nil)
    provenance ||= read_yaml(File.join(ROOT, TOOLCHAIN_PROVENANCE))
      .fetch("selected_build_toolchain_candidate")
    material_records = read_yaml(File.join(ROOT, MATERIALS)).fetch("materials")
    manifest_material = material_records.find do |item|
      item.fetch("id") == "rust-1.98.0-manifest"
    end
    source_review_material = material_records.find do |item|
      item.fetch("id") == "rust-source-license-review"
    end
    raise Failure, "P13 Rust source provenance material binding is missing" unless
      manifest_material && source_review_material

    manifest = record.fetch("channel_manifest")
    archive = record.fetch("source_archive")
    source = provenance.fetch("source_archive")
    active = provenance.fetch("active_source_closure")
    active_graph = record.fetch("active_lock_graph")
    compiler = record.fetch("registry_closures")
      .fetch("compiler_and_clippy")
    sysroot = record.fetch("registry_closures").fetch("sysroot")
    raise Failure, "P13 Rust top-level source provenance differs" unless
      provenance.fetch("name") == "rust" &&
      provenance.fetch("version") == manifest_material.fetch("version") &&
      provenance.fetch("provider") == manifest_material.fetch("provider") &&
      provenance.fetch("license") == manifest_material.fetch("license") &&
      provenance.fetch("source_url") ==
        source_review_material.fetch("canonical_url") &&
      provenance.fetch("source_commit") == manifest.fetch("source_commit") &&
      provenance.fetch("source_commit") ==
        manifest_material.fetch("source_commit") &&
      provenance.fetch("manifest_url") == manifest.fetch("canonical_url") &&
      provenance.fetch("manifest_url") ==
        manifest_material.fetch("canonical_url") &&
      provenance.fetch("manifest_size") == manifest.fetch("bytes") &&
      provenance.fetch("manifest_size") ==
        manifest_material.fetch("artifact_size") &&
      provenance.fetch("manifest_sha256") == manifest.fetch("sha256") &&
      provenance.fetch("manifest_sha256") ==
        manifest_material.fetch("artifact_sha256") &&
      provenance.fetch("target") == manifest_material.fetch("target") &&
      provenance.fetch("archive_url") ==
        manifest_material.fetch("target_archive_url") &&
      provenance.fetch("archive_sha256") ==
        manifest_material.fetch("target_archive_sha256") &&
      provenance.fetch("manifest_verified") == {
        "observed_size" => manifest.fetch("bytes"),
        "observed_sha256" => manifest.fetch("sha256")
      } &&
      provenance.fetch("archive_verified") == {
        "observed_sha256" =>
          manifest_material.fetch("target_archive_sha256")
      }
    raise Failure, "P13 Rust source provenance archive differs" unless
      source.fetch("url") == archive.fetch("canonical_url") &&
      source.fetch("size") == archive.fetch("bytes") &&
      source.fetch("sha256") == archive.fetch("sha256") &&
      source.fetch("source_commit") ==
        manifest.fetch("source_commit") &&
      source.fetch("manifest_relation") ==
        "exact_artifacts_source_code_entry_in_bound_channel_manifest" &&
      source.fetch("local_path") == archive.fetch("local_path") &&
      source.fetch("shipped") == false
    raise Failure, "P13 Rust active source provenance differs" unless
      active.fetch("compiler_and_clippy_lock_sha256") ==
        RUST_SOURCE_MEMBERS.find { |item| item.fetch("path") == "Cargo.lock" }
          .fetch("sha256") &&
      active.fetch("sysroot_lock_sha256") ==
        RUST_SOURCE_MEMBERS.find do |item|
          item.fetch("path") == "library/Cargo.lock"
        end.fetch("sha256") &&
      active.fetch("excluded_rust_analyzer_lock_sha256") ==
        RUST_SOURCE_MEMBERS.find do |item|
          item.fetch("path") == "src/tools/rust-analyzer/Cargo.lock"
        end.fetch("sha256") &&
      active.fetch("compiler_and_clippy_package_count") ==
        compiler.fetch("package_count") &&
      active.fetch("compiler_and_clippy_path_package_count") ==
        compiler.fetch("path_package_count") &&
      active.fetch("compiler_and_clippy_registry_package_count") ==
        compiler.fetch("registry_package_count") &&
      active.fetch("compiler_and_clippy_registry_tuple_sha256") ==
        compiler.fetch("lock_tuple_inventory_sha256") &&
      active.fetch("selected_root_lock_graph_package_count") ==
        active_graph.fetch("package_count") &&
      active.fetch("selected_root_lock_graph_registry_package_count") ==
        active_graph.fetch("registry_package_count") &&
      active.fetch("selected_root_lock_graph_registry_tuple_sha256") ==
        active_graph.fetch("registry_tuple_inventory_sha256") &&
      active.fetch("reviewed_inactive_package_count") ==
        RUST_REVIEWED_INACTIVE_PACKAGES.length &&
      active.fetch("compiler_and_clippy_manifest_inventory_sha256") ==
        compiler.fetch("cargo_manifest_inventory_sha256") &&
      active.fetch("compiler_and_clippy_checksum_inventory_sha256") ==
        compiler.fetch("cargo_checksum_inventory_sha256") &&
      active.fetch("compiler_and_clippy_legal_file_count") ==
        compiler.fetch("legal_file_count") &&
      active.fetch("compiler_and_clippy_legal_file_bytes") ==
        compiler.fetch("legal_file_bytes") &&
      active.fetch("compiler_and_clippy_legal_file_inventory_sha256") ==
        compiler.fetch("legal_file_inventory_sha256") &&
      active.fetch("sysroot_package_count") == sysroot.fetch("package_count") &&
      active.fetch("sysroot_path_package_count") ==
        sysroot.fetch("path_package_count") &&
      active.fetch("sysroot_registry_package_count") ==
        sysroot.fetch("registry_package_count") &&
      active.fetch("sysroot_registry_tuple_sha256") ==
        sysroot.fetch("lock_tuple_inventory_sha256") &&
      active.fetch("sysroot_manifest_inventory_sha256") ==
        sysroot.fetch("cargo_manifest_inventory_sha256") &&
      active.fetch("sysroot_checksum_inventory_sha256") ==
        sysroot.fetch("cargo_checksum_inventory_sha256") &&
      active.fetch("sysroot_legal_file_count") ==
        sysroot.fetch("legal_file_count") &&
      active.fetch("sysroot_legal_file_bytes") ==
        sysroot.fetch("legal_file_bytes") &&
      active.fetch("sysroot_legal_file_inventory_sha256") ==
        sysroot.fetch("legal_file_inventory_sha256") &&
      active.fetch("compiler_and_clippy_notify_count") == 0 &&
      active.fetch("sysroot_notify_count") == 0 &&
      active.fetch("excluded_rust_analyzer_notify_count") == 1 &&
      active.fetch("installed_notify_path_count") == 0 &&
      active.fetch("installed_unselected_rust_analyzer_helper_count") ==
        RUST_UNSELECTED_HELPERS.length &&
      active.fetch("license_metadata_sha256") ==
        record.fetch("license_metadata").fetch("sha256") &&
      active.fetch("spdx_license_list_commit") ==
        record.fetch("spdx_license_evidence").fetch("commit") &&
      active.fetch("spdx_license_list_tree") ==
        record.fetch("spdx_license_evidence").fetch("tree") &&
      active.fetch("spdx_rejected_license_ids") ==
        SPDX_REJECTED_LICENSE_FILES.map { |file| file.fetch("id") } &&
      active.fetch("llvm_license") ==
        "Apache-2.0 WITH LLVM-exception" &&
      active.fetch("sole_cc0_only_package") == "notify-8.2.0" &&
      active.fetch("result") == "SELECTED_SOURCE_LICENSE_CLOSURE_OSI_ONLY"
    true
  rescue KeyError => error
    raise Failure, "P13 Rust source provenance field missing: #{error.key}"
  end

  def validate_materials(materials)
    records = materials.fetch("materials")
    raise Failure, "materials ledger is not a sequence" unless records.is_a?(Array)

    ids = records.map { |record| record.fetch("id") }
    raise Failure, "materials ledger contains duplicate IDs" unless
      ids.uniq.length == ids.length
    MATERIAL_RECORD_SEMANTIC_SHA256.each do |id, expected|
      record = records.find { |candidate| candidate.fetch("id") == id }
      raise Failure, "P13 Noise material missing: #{id}" unless record
      raise Failure, "P13 Noise material differs: #{id}" unless
        semantic_digest(record) == expected
    end
    true
  rescue KeyError => error
    raise Failure, "materials field missing: #{error.key}"
  end

  def validate_material_closure_binding(materials, evidence)
    records = materials.fetch("materials")
    noise = records.find do |record|
      record.fetch("id") == "noise-protocol-revision-34-p13-transport"
    end
    snow = records.find do |record|
      record.fetch("id") == "snow-0.10.0-p13-transport-closure"
    end
    legal_code = records.find do |record|
      record.fetch("id") == "creative-commons-by-4.0-legalcode-p13"
    end
    poly1305 = records.find do |record|
      record.fetch("id") == "project-poly1305-soft-p13"
    end
    rust_num = records.find do |record|
      record.fetch("id") == "rust-num-pow-origin-p13"
    end
    rust_array = records.find do |record|
      record.fetch("id") == "rust-pr49000-array-origin-p13"
    end
    cacophony = records.find do |record|
      record.fetch("id") == "cacophony-vector-p13-snow-projection-removal"
    end
    rust_source = records.find do |record|
      record.fetch("id") == "rustc-1.98.0-source-p13"
    end
    spdx = records.find do |record|
      record.fetch("id") == "spdx-license-list-xml-p13"
    end
    pulldown_origin = records.find do |record|
      record.fetch("id") == "pulldown-redwood-relicense-origin-p13"
    end
    tracing_origin = records.find do |record|
      record.fetch("id") == "tracing-hyperium-origin-p13"
    end
    raise Failure, "P13 Noise material binding is missing" unless noise
    raise Failure, "P13 Snow material binding is missing" unless snow
    raise Failure, "P13 CC-BY legal-code material binding is missing" unless
      legal_code
    raise Failure, "P13 Poly1305 material binding is missing" unless poly1305
    raise Failure, "P13 rust-num material binding is missing" unless rust_num
    raise Failure, "P13 Rust array material binding is missing" unless rust_array
    raise Failure, "P13 Cacophony material binding is missing" unless cacophony
    raise Failure, "P13 Rust source material binding is missing" unless
      rust_source
    raise Failure, "P13 SPDX material binding is missing" unless spdx
    raise Failure, "P13 pulldown origin material binding is missing" unless
      pulldown_origin
    raise Failure, "P13 tracing origin material binding is missing" unless
      tracing_origin

    specification = evidence.fetch("noise_specification")
    {
      "canonical_url" => specification.fetch("canonical_url"),
      "commit" => specification.fetch("git_commit"),
      "tree" => specification.fetch("git_tree"),
      "selected_blob" => specification.fetch("git_blob"),
      "selected_path" => specification.fetch("path"),
      "selected_path_bytes" => specification.fetch("bytes"),
      "selected_path_sha256" => specification.fetch("sha256")
    }.each do |key, value|
      raise Failure, "P13 Noise material evidence differs: #{key}" unless
        noise.fetch(key) == value
    end

    toolchain_source = evidence.fetch("toolchain_source_closure")
    copied_origins = toolchain_source.fetch("copied_source_origins")
    pulldown_review = copied_origins.fetch("pulldown_cmark_redwood")
    tracing_review = copied_origins.fetch("tracing_subscriber_hyperium")
    pulldown_package = pulldown_review.fetch("package")
    pulldown_source = pulldown_review.fetch("origin")
    pulldown_grant = pulldown_review.fetch("author_permission")
    tracing_package = tracing_review.fetch("package")
    tracing_source = tracing_review.fetch("origin")
    raise Failure, "P13 pulldown origin material evidence differs" unless
      pulldown_origin.fetch("canonical_url") ==
        pulldown_source.fetch("repository") &&
      pulldown_origin.fetch("commit") == pulldown_source.fetch("commit") &&
      pulldown_origin.fetch("tree") == pulldown_source.fetch("tree") &&
      pulldown_origin.fetch("source_path") == pulldown_source.fetch("path") &&
      pulldown_origin.fetch("source_git_blob") ==
        pulldown_source.fetch("blob") &&
      pulldown_origin.fetch("source_sha256") ==
        pulldown_source.fetch("sha256") &&
      pulldown_origin.fetch("permission_artifact_sha256") ==
        pulldown_grant.fetch("sha256") &&
      pulldown_origin.fetch("permission_url") ==
        pulldown_grant.fetch("comment_url") &&
      pulldown_origin.fetch("permission_request_url") ==
        pulldown_grant.fetch("request_url") &&
      pulldown_origin.fetch("permission_acquired_at_utc") ==
        pulldown_grant.fetch("acquired_at_utc") &&
      pulldown_origin.fetch("permission_request_authentication") ==
        pulldown_grant.fetch("request_authentication") &&
      pulldown_origin.fetch("permission_artifact_provenance") ==
        pulldown_grant.fetch("artifact_provenance") &&
      pulldown_origin.fetch("copied_into_path") ==
        pulldown_package.fetch("archive_path") &&
      pulldown_origin.fetch("elected_license") ==
        pulldown_review.fetch("elected_license")
    raise Failure, "P13 tracing origin material evidence differs" unless
      tracing_origin.fetch("canonical_url") ==
        tracing_source.fetch("repository") &&
      tracing_origin.fetch("commit") == tracing_source.fetch("commit") &&
      tracing_origin.fetch("tree") == tracing_source.fetch("tree") &&
      tracing_origin.fetch("source_path") == tracing_source.fetch("path") &&
      tracing_origin.fetch("source_git_blob") ==
        tracing_source.fetch("blob") &&
      tracing_origin.fetch("source_sha256") ==
        tracing_source.fetch("sha256") &&
      tracing_origin.fetch("copied_into_path") ==
        tracing_package.fetch("archive_path") &&
      tracing_origin.fetch("elected_license") ==
        tracing_review.fetch("elected_license")
    source_archive = toolchain_source.fetch("source_archive")
    source_manifest = toolchain_source.fetch("channel_manifest")
    compiler_registry = toolchain_source.fetch("registry_closures")
      .fetch("compiler_and_clippy")
    sysroot_registry = toolchain_source.fetch("registry_closures")
      .fetch("sysroot")
    active_graph = toolchain_source.fetch("active_lock_graph")
    spdx_evidence = toolchain_source.fetch("spdx_license_evidence")
    raise Failure, "P13 Rust source material evidence differs" unless
      rust_source.fetch("status") == "QUARANTINED_CANDIDATE" &&
      rust_source.fetch("canonical_url") ==
        source_archive.fetch("canonical_url") &&
      rust_source.fetch("source_commit") ==
        source_manifest.fetch("source_commit") &&
      rust_source.fetch("artifact_size") == source_archive.fetch("bytes") &&
      rust_source.fetch("artifact_sha256") == source_archive.fetch("sha256") &&
      rust_source.fetch("local_path") == source_archive.fetch("local_path") &&
      rust_source.fetch("license") ==
        "MULTIPLE_OSI_APPROVED_WITH_EXPLICIT_REJECTED_FILE" &&
      rust_source.fetch("root_license") == "MIT OR Apache-2.0" &&
      rust_source.fetch("license_metadata_sha256") ==
        toolchain_source.fetch("license_metadata").fetch("sha256") &&
      rust_source.fetch("llvm_license") ==
        "Apache-2.0 WITH LLVM-exception" &&
      rust_source.fetch("loongarch_license") ==
        "GPL-3.0-or-later WITH GCC-exception-3.1" &&
      rust_source.fetch("loongarch_gpl_path") ==
        "src/etc/third-party/COPYING3" &&
      rust_source.fetch("loongarch_gpl_sha256") ==
        RUST_SOURCE_MEMBERS.find { |member|
          member.fetch("path") == "src/etc/third-party/COPYING3"
        }.fetch("sha256") &&
      rust_source.fetch("loongarch_exception_path") ==
        "src/etc/third-party/COPYING.RUNTIME" &&
      rust_source.fetch("loongarch_exception_sha256") ==
        RUST_SOURCE_MEMBERS.find { |member|
          member.fetch("path") == "src/etc/third-party/COPYING.RUNTIME"
        }.fetch("sha256") &&
      rust_source.fetch("compiler_and_clippy_registry_package_count") ==
        compiler_registry.fetch("registry_package_count") &&
      rust_source.fetch("compiler_and_clippy_registry_tuple_sha256") ==
        compiler_registry.fetch("lock_tuple_inventory_sha256") &&
      rust_source.fetch("compiler_and_clippy_legal_file_count") ==
        compiler_registry.fetch("legal_file_count") &&
      rust_source.fetch("compiler_and_clippy_legal_file_inventory_sha256") ==
        compiler_registry.fetch("legal_file_inventory_sha256") &&
      rust_source.fetch("selected_root_lock_graph_package_count") ==
        active_graph.fetch("package_count") &&
      rust_source.fetch("selected_root_lock_graph_registry_package_count") ==
        active_graph.fetch("registry_package_count") &&
      rust_source.fetch("selected_root_lock_graph_registry_tuple_sha256") ==
        active_graph.fetch("registry_tuple_inventory_sha256") &&
      rust_source.fetch("reviewed_inactive_packages") ==
        RUST_REVIEWED_INACTIVE_PACKAGES.map do |package|
          "#{package.fetch('name')}-#{package.fetch('version')}"
        end &&
      rust_source.fetch("reviewed_non_osi_legal_identifiers") ==
        SPDX_REJECTED_LICENSE_FILES.map { |file| file.fetch("id") } &&
      rust_source.fetch("reviewed_non_osi_disposition") ==
        "UNREACHABLE_FROM_SELECTED_ROOTS_AND_REJECTED_FROM_SELECTED_SOURCE" &&
      rust_source.fetch("rejected_path_source_files") == [
        RUST_PATH_SOURCE_INTEL_REJECTION.slice(
          "path",
          "bytes",
          "sha256"
        ).merge(
          "owner" => "Intel_Corporation",
          "license_status" =>
            "RESTRICTIVE_TERMS_WITHOUT_ELIGIBLE_LICENSE",
          "disposition" =>
            "REJECTED_FROM_PRODUCT_SOURCE_CLOSURE_P14_MUST_PROVE_UNREACHABLE"
        )
      ] &&
      rust_source.fetch("sysroot_registry_package_count") ==
        sysroot_registry.fetch("registry_package_count") &&
      rust_source.fetch("sysroot_registry_tuple_sha256") ==
        sysroot_registry.fetch("lock_tuple_inventory_sha256") &&
      rust_source.fetch("sysroot_legal_file_count") ==
        sysroot_registry.fetch("legal_file_count") &&
      rust_source.fetch("sysroot_legal_file_inventory_sha256") ==
        sysroot_registry.fetch("legal_file_inventory_sha256") &&
      rust_source.fetch("osi_approval_material_id") ==
        "spdx-license-list-xml-p13" &&
      rust_source.fetch("sole_cc0_only_package") == "notify-8.2.0" &&
      rust_source.fetch("sole_cc0_only_package_disposition") ==
        "EXCLUDED_RUST_ANALYZER_LOCK_PACKAGE_NOT_SELECTED_INSTALLED_OR_EXECUTED" &&
      rust_source.fetch("commercial_use_and_modification") ==
        "permitted_for_selected_eligible_source_only_Intel_cpuid_file_rejected" &&
      rust_source.fetch("prohibited_use").include?(
        "Intel_cpuid_notify_rust_analyzer"
      )
    raise Failure, "P13 SPDX material evidence differs" unless
      spdx.fetch("status") == "QUARANTINED_CANDIDATE" &&
      spdx.fetch("canonical_url") == spdx_evidence.fetch("repository") &&
      spdx.fetch("commit") == spdx_evidence.fetch("commit") &&
      spdx.fetch("tree") == spdx_evidence.fetch("tree") &&
      spdx.fetch("local_origin_repository") ==
        spdx_evidence.fetch("local_origin_repository") &&
      spdx.fetch("selected_license_record_count") ==
        spdx_evidence.fetch("files").count do |item|
          item.fetch("kind") == "license"
        end &&
      spdx.fetch("selected_exception_record_count") ==
        spdx_evidence.fetch("files").count do |item|
          item.fetch("kind") == "exception"
        end &&
      spdx.fetch("rejected_non_osi_license_record_count") ==
        spdx_evidence.fetch("rejected_files").length &&
      spdx.fetch("rejected_non_osi_license_ids") ==
        spdx_evidence.fetch("rejected_files").map do |item|
          item.fetch("id")
        end &&
      spdx.fetch("selected_rights_file_count") ==
        spdx_evidence.fetch("rights_files").length &&
      spdx.fetch("license") == spdx_evidence.fetch("license") &&
      spdx.fetch("commercial_use_and_modification") == "permitted"

    closure = evidence.fetch("closure")
    including_probe = closure.fetch("lock_package_count_including_probe")
    external = closure.fetch("external_package_count")
    fixtures = closure.fetch("resolver_only_technical_fixture_count")
    raise Failure, "P13 material lock identity differs from source ledger" unless
      snow.fetch("lock_sha256") == closure.fetch("lock_sha256") &&
      snow.fetch("lock_package_count_including_probe") == including_probe &&
      snow.fetch("lock_package_count_excluding_probe") == including_probe - 1 &&
      snow.fetch("external_package_count") == external &&
      snow.fetch("resolver_only_technical_fixture_count") == fixtures &&
      including_probe - 1 == external + fixtures
    compile_projection = evidence.fetch("compile_projection")
    raise Failure, "P13 material projection identity differs from source ledger" unless
      snow.fetch("compile_projection_selected_package_count") ==
        compile_projection.fetch("selected_package_count") &&
      snow.fetch("compile_projection_archive_file_count") ==
        compile_projection.fetch("archive_file_count") &&
      snow.fetch("compile_projection_projected_file_count") ==
        compile_projection.fetch("projected_file_count") &&
      snow.fetch("compile_projection_deleted_file_count") ==
        compile_projection.fetch("deleted_file_count") &&
      snow.fetch("compile_projection_replacement_file_count") ==
        compile_projection.fetch("replacement_file_count") &&
      snow.fetch("compile_projection_added_notice_file_count") ==
        compile_projection.fetch("added_notice_file_count") &&
      snow.fetch("compile_projection_inventory_sha256") ==
        compile_projection.fetch("inventory_sha256") &&
      snow.fetch("compile_projection_mixed_file_byte_range_edits") == 0

    review_states = evidence.fetch("review_state").values
    expected_status =
      if review_states.all? { |state| state == "PENDING_INDEPENDENT_REVIEW" }
        "QUARANTINED_CANDIDATE"
      elsif review_states.all? { |state| state == "PASS" }
        "ADMITTED_AUTONOMOUS"
      else
        raise Failure, "P13 source review state is mixed"
      end
    raise Failure, "P13 CC-BY legal-code admission state differs" unless
      legal_code.fetch("status") == expected_status

    projection = evidence.fetch("compile_projection").fetch("packages").find do |record|
      record.fetch("name") == "poly1305"
    end
    active = evidence.fetch("project_poly1305_source_review")
    poly_package = closure.fetch("packages").find do |record|
      record.fetch("name") == "poly1305"
    end
    raise Failure, "P13 Poly1305 source package binding is missing" unless
      poly_package
    raise Failure, "P13 Poly1305 material binding differs" unless
      poly1305.fetch("replaces_package") == poly_package.fetch("name") &&
      poly1305.fetch("replaces_version") == poly_package.fetch("version") &&
      poly1305.fetch("source_path") == active.fetch("path") &&
      poly1305.fetch("source_bytes") == active.fetch("bytes") &&
      poly1305.fetch("source_sha256") == active.fetch("sha256") &&
      poly1305.fetch("replacement_input_sha256") ==
        projection.fetch("replacement_input_sha256") &&
      poly1305.fetch("license_replacement_input_sha256") ==
        projection.fetch("license_replacement_input_sha256") &&
      poly1305.fetch("license_replacement_sha256") ==
        projection.fetch("license_replacement_sha256") &&
      poly1305.fetch("projected_file_count") ==
        projection.fetch("retained_file_count") &&
      poly1305.fetch("projected_tree_sha256") ==
        projection.fetch("projected_tree_sha256") &&
      poly1305.fetch("license") == "Apache-2.0" &&
      poly1305.fetch("external_implementation_bytes_used") == false

    typenum = evidence.fetch("typenum_origin_review")
    raise Failure, "P13 rust-num material binding differs" unless
      rust_num.fetch("commit") == typenum.fetch("origin_commit") &&
      rust_num.fetch("tree") == typenum.fetch("origin_tree") &&
      rust_num.fetch("source_path") == typenum.fetch("origin_path") &&
      rust_num.fetch("source_git_blob") == typenum.fetch("origin_git_blob") &&
      rust_num.fetch("source_bytes") == typenum.fetch("origin_source_bytes") &&
      rust_num.fetch("source_sha256") == typenum.fetch("origin_source_sha256") &&
      rust_num.fetch("origin_function") == typenum.fetch("origin_function") &&
      rust_num.fetch("copied_into_package") ==
        "typenum-#{typenum.fetch('version')}" &&
      rust_num.fetch("copied_into_commit") == typenum.fetch("package_commit") &&
      rust_num.fetch("copied_into_path") == typenum.fetch("package_path") &&
      rust_num.fetch("license") == typenum.fetch("license") &&
      rust_num.fetch("license_apache_sha256") ==
        typenum.fetch("license_files").fetch("LICENSE-APACHE").fetch("sha256") &&
      rust_num.fetch("license_mit_sha256") ==
        typenum.fetch("license_files").fetch("LICENSE-MIT").fetch("sha256") &&
      rust_num.fetch("projected_notice_path") ==
        typenum.fetch("projected_notice").fetch("path") &&
      rust_num.fetch("projected_notice_bytes") ==
        typenum.fetch("projected_notice").fetch("bytes") &&
      rust_num.fetch("projected_notice_sha256") ==
        typenum.fetch("projected_notice").fetch("sha256")
    generic_array = evidence.fetch("generic_array_origin_review")
    raise Failure, "P13 Rust array material binding differs" unless
      rust_array.fetch("commit") == generic_array.fetch("origin_commit") &&
      rust_array.fetch("tree") == generic_array.fetch("origin_tree") &&
      rust_array.fetch("source_path") == generic_array.fetch("origin_path") &&
      rust_array.fetch("source_git_blob") ==
        generic_array.fetch("origin_git_blob") &&
      rust_array.fetch("source_bytes") ==
        generic_array.fetch("origin_source_bytes") &&
      rust_array.fetch("source_sha256") ==
        generic_array.fetch("origin_source_sha256") &&
      rust_array.fetch("license_apache_sha256") ==
        generic_array.fetch("license_files").fetch("LICENSE-APACHE").fetch("sha256") &&
      rust_array.fetch("license_mit_sha256") ==
        generic_array.fetch("license_files").fetch("LICENSE-MIT").fetch("sha256") &&
      rust_array.fetch("copyright_git_blob") ==
        generic_array.fetch("copyright_file").fetch("git_blob") &&
      rust_array.fetch("copyright_bytes") ==
        generic_array.fetch("copyright_file").fetch("bytes") &&
      rust_array.fetch("copyright_sha256") ==
        generic_array.fetch("copyright_file").fetch("sha256") &&
      rust_array.fetch("origin_region_start_line") ==
        generic_array.fetch("adapted_regions").fetch("origin").fetch("start_line") &&
      rust_array.fetch("origin_region_end_line") ==
        generic_array.fetch("adapted_regions").fetch("origin").fetch("end_line") &&
      rust_array.fetch("origin_region_sha256") ==
        generic_array.fetch("adapted_regions").fetch("origin").fetch("sha256") &&
      rust_array.fetch("package_region_start_line") ==
        generic_array.fetch("adapted_regions").fetch("package").fetch("start_line") &&
      rust_array.fetch("package_region_end_line") ==
        generic_array.fetch("adapted_regions").fetch("package").fetch("end_line") &&
      rust_array.fetch("package_region_sha256") ==
        generic_array.fetch("adapted_regions").fetch("package").fetch("sha256") &&
      rust_array.fetch("projected_notice_sha256") ==
        generic_array.fetch("projected_notice").fetch("sha256")
    true
  rescue KeyError => error
    raise Failure, "P13 material closure binding field missing: #{error.key}"
  end

  def validate_distribution(distribution)
    rules = distribution.fetch("path_rules")
    REQUIRED_DISTRIBUTION_PATHS.each do |path|
      matches = rules.select do |rule|
        rule.fetch("paths").include?(path) ||
          rule.fetch("path_prefixes").any? { |prefix| path.start_with?(prefix) }
      end
      raise Failure, "distribution path is unclassified: #{path}" if matches.empty?
      raise Failure, "distribution path is multiply classified: #{path}" unless
        matches.length == 1
      rule = matches.first
      raise Failure, "P13 Noise path has wrong origin: #{path}" unless
        rule.fetch("origin_id") == "project-authored" &&
        rule.fetch("license") == "Apache-2.0" &&
        rule.fetch("license_files").include?("LICENSE")
    end
    true
  rescue KeyError => error
    raise Failure, "distribution field missing: #{error.key}"
  end

  def source_paths(evidence)
    closure = evidence.fetch("closure")
    specification = evidence.fetch("noise_specification")
    advisory = evidence.fetch("advisory_review")
    {
      "archive_root" => ENV.fetch(
        "P13_NOISE_ARCHIVE_ROOT",
        closure.fetch("local_archive_root")
      ),
      "registry_source_root" => ENV.fetch(
        "P13_NOISE_REGISTRY_SOURCE_ROOT",
        closure.fetch("local_registry_source_root")
      ),
      "noise_spec" => ENV.fetch(
        "P13_NOISE_SPEC",
        specification.fetch("local_path")
      ),
      "noise_spec_origin" => ENV.fetch(
        "P13_NOISE_SPEC_ORIGIN",
        specification.fetch("local_origin_repository")
      ),
      "cacophony_origin" => ENV.fetch(
        "P13_CACOPHONY_ORIGIN",
        evidence.fetch("removed_cacophony_vector")
          .fetch("local_origin_repository")
      ),
      "rustsec" => ENV.fetch(
        "P13_NOISE_RUSTSEC",
        advisory.fetch("local_path")
      )
    }
  end

  def validate_probe_files(evidence, root: File.join(ROOT, PROBE_ROOT))
    probe = evidence.fetch("probe")
    validate_probe_execution_contract(probe)
    records = probe.fetch("files")
    expected = records.map { |record| record.fetch("path") }.sort
    actual = tree_entries(root).keys.sort
    raise Failure, "P13 Noise probe path set differs" unless actual == expected

    records.each do |record|
      verify_file(
        File.join(root, record.fetch("path")),
        bytes: record.fetch("bytes"),
        sha256: record.fetch("sha256"),
        context: "P13 Noise probe #{record.fetch('path')}"
      )
    end

    manifest = File.binread(File.join(root, "Cargo.toml"))
    require_include(
      manifest,
      'snow = { path = "sources/snow", ' \
      "default-features = false, features = [",
      "Snow exact projection and default feature"
    )
    SNOW_FEATURES.each do |feature|
      require_include(manifest, "\"#{feature}\"", "Snow feature #{feature}")
    end
    require_exclude(manifest, "use-getrandom", "Snow getrandom feature")
    require_include(
      manifest,
      'chacha20 = { path = "sources/chacha20" }',
      "ChaCha20 exact projection"
    )
    require_include(
      manifest,
      'poly1305 = { path = "sources/poly1305" }',
      "Poly1305 exact projection"
    )
    require_exclude(manifest, "/private/tmp", "mutable absolute source path")

    config = File.binread(File.join(root, ".cargo/config.toml"))
    require_include(config, "offline = true", "offline Cargo configuration")
    require_include(
      config,
      'replace-with = "p13-exact-archives"',
      "exact Cargo source replacement"
    )
    require_include(
      config,
      'directory = "vendor"',
      "private materialized Cargo source"
    )
    require_include(config, '"chacha20_force_soft"', "forced ChaCha20 backend")
    require_include(config, '"poly1305_force_soft"', "forced Poly1305 backend")
    require_include(
      config,
      '"curve25519_dalek_backend=\\"serial\\"',
      "forced Curve25519 backend"
    )
    require_include(config, '"linker-flavor=ld"', "admitted linker flavor")
    require_exclude(config, '"--cfg",\n    "chacha20_force_neon"', "forced NEON backend")

    source = File.binread(File.join(root, "src/lib.rs"))
    required_tests = [
      "exact_profile_completes_and_exchanges_both_directions",
      "wrong_psk_fails_closed",
      "every_prologue_binding_substitution_fails_closed",
      "tampered_handshake_fails_closed",
      "replayed_transport_ciphertext_fails_closed",
      "unavailable_entropy_device_prevents_state_construction",
      "project_poly1305_matches_fixture_tecnica_reference"
    ]
    raise Failure, "P13 Noise required test inventory differs" unless
      probe.fetch("required_tests") == required_tests
    [
      PROFILE,
      "/dev/urandom",
      "protocol_version",
      "epoch",
      "initiator_role",
      "responder_role",
      "direction",
      "connection_nonce",
      "requires the ChaCha20 software backend",
      "prohibits accelerated ChaCha20 backends",
      "requires the Poly1305 software backend",
      "requires the Curve25519 serial backend",
      "prohibits alternate Curve25519 backends",
      *required_tests,
      "FIXTURE_TECNICA_CASES",
      "reference_poly1305"
    ].each do |predicate|
      require_include(source, predicate, "probe predicate #{predicate}")
    end
    require_exclude(source, "std::net", "probe network API")
    true
  end

  def validate_probe_execution_contract(probe)
    expected_keys = %w[
      capability_result
      direct_clippy
      direct_test
      files
      required_tests
      root
      runtime_result
    ]
    raise Failure, "P13 probe evidence field set differs" unless
      probe.keys.sort == expected_keys
    raise Failure, "P13 probe retains stale Cargo execution fields" if
      probe.key?("cargo_test") || probe.key?("cargo_clippy")
    raise Failure, "P13 direct probe execution evidence differs" unless
      probe.fetch("direct_test") ==
        "rustc_test_harness_executed_single_thread" &&
      probe.fetch("direct_clippy") ==
        "clippy_driver_metadata_emit_with_D_warnings" &&
      probe.fetch("capability_result") == "PASS" &&
      probe.fetch("runtime_result") == "NOT_A_PRODUCT_RUNTIME_ADMISSION"
    true
  rescue KeyError => error
    raise Failure, "P13 direct probe execution field missing: #{error.key}"
  end

  def validate_lock(evidence, bytes: nil)
    closure = evidence.fetch("closure")
    path = File.join(ROOT, closure.fetch("lock_path"))
    bytes ||= File.binread(path)
    raise Failure, "P13 Noise lock size differs" unless
      bytes.bytesize == closure.fetch("lock_bytes")
    raise Failure, "P13 Noise lock hash differs" unless
      Digest::SHA256.hexdigest(bytes) == closure.fetch("lock_sha256")

    packages = parse_lock_packages(bytes)
    raise Failure, "P13 Noise lock package count differs" unless
      packages.length == closure.fetch("lock_package_count_including_probe")
    probe = packages.find { |package| package.fetch("name") == "p13-snow-final-probe" }
    raise Failure, "P13 Noise lock probe package differs" unless
      probe && probe.fetch("version") == "0.1.0" &&
      probe["source"].nil? && probe["checksum"].nil?

    records = closure.fetch("packages")
    raise Failure, "P13 Noise external package count differs" unless
      records.length == closure.fetch("external_package_count")
    fixtures = evidence.fetch("runtime_isolation")
      .fetch("resolver_only_technical_fixtures")
    raise Failure, "P13 Noise resolver fixture count differs" unless
      fixtures.length == closure.fetch("resolver_only_technical_fixture_count")
    order = records.map { |record| [record.fetch("name"), record.fetch("version")] }
    raise Failure, "P13 Noise package ledger order differs" unless
      order == order.sort

    lock_external = packages.reject { |package| package.equal?(probe) }
    actual = lock_external.to_h do |package|
      [[package.fetch("name"), package.fetch("version")], package]
    end
    expected_keys = records.map { |record| [record.fetch("name"), record.fetch("version")] }
    fixture_keys = fixtures.map do |record|
      [record.fetch("name"), record.fetch("version")]
    end
    raise Failure, "P13 Noise lock closure differs" unless
      actual.keys.sort == (expected_keys + fixture_keys).sort

    records.each do |record|
      package = actual.fetch([record.fetch("name"), record.fetch("version")])
      if record.fetch("source_mode") == "registry_archive"
        raise Failure, "registry lock source differs: #{record.fetch('name')}" unless
          package.fetch("source") ==
            "registry+https://github.com/rust-lang/crates.io-index"
        raise Failure, "registry lock checksum differs: #{record.fetch('name')}" unless
          package.fetch("checksum") == record.fetch("archive_sha256")
      else
        raise Failure, "path lock source differs: #{record.fetch('name')}" unless
          package["source"].nil? && package["checksum"].nil?
      end
    end
    fixtures.each do |record|
      package = actual.fetch([record.fetch("name"), record.fetch("version")])
      raise Failure, "resolver fixture lock source differs" unless
        package.fetch("source") ==
          "registry+https://github.com/rust-lang/crates.io-index" &&
        package["checksum"].nil?
    end
    true
  rescue Errno::ENOENT
    raise Failure, "P13 Noise lock missing: #{path}"
  rescue KeyError => error
    raise Failure, "P13 Noise lock evidence field missing: #{error.key}"
  end

  def parse_lock_packages(bytes)
    blocks = bytes.split(/^\[\[package\]\]\s*$\n/)
    blocks.shift
    packages = blocks.map do |block|
      {
        "name" => required_toml_string(block, "name", "Cargo.lock package"),
        "version" => required_toml_string(block, "version", "Cargo.lock package"),
        "source" => optional_toml_string(block, "source", "Cargo.lock package"),
        "checksum" => optional_toml_string(block, "checksum", "Cargo.lock package")
      }
    end
    identities = packages.map { |package| [package.fetch("name"), package.fetch("version")] }
    raise Failure, "Cargo.lock contains duplicate package identity" unless
      identities.uniq.length == identities.length
    packages
  end

  def validate_noise_specification(evidence, paths)
    record = evidence.fetch("noise_specification")
    detached = verify_file(
      paths.fetch("noise_spec"),
      bytes: record.fetch("bytes"),
      sha256: record.fetch("sha256"),
      context: "Noise revision 34 specification"
    )
    bytes = git_evidence_file(
      root: paths.fetch("noise_spec_origin"),
      commit: record.fetch("git_commit"),
      tree: record.fetch("git_tree"),
      path: record.fetch("path"),
      blob: record.fetch("git_blob"),
      bytes: record.fetch("bytes"),
      sha256: record.fetch("sha256"),
      label: "Noise revision 34 specification"
    )
    raise Failure, "detached Noise specification differs from Git object" unless
      detached == bytes
    require_include(bytes, "revision:   '34'", "Noise revision")
    require_include(
      bytes,
      "The Noise specification (this document) is hereby placed in the public domain.",
      "Noise rights statement"
    )
    require_include(bytes, "NN:", "Noise NN pattern")
    require_include(bytes, "psk0", "Noise PSK modifier")
    true
  end

  def validate_cacophony_origin(evidence, materials, validated_sources, paths)
    record = evidence.fetch("removed_cacophony_vector")
    material = materials.fetch("materials").find do |candidate|
      candidate.fetch("id") == "cacophony-vector-p13-snow-projection-removal"
    end
    raise Failure, "P13 Cacophony material binding is missing" unless material

    expected = {
      "canonical_url" => material.fetch("canonical_url"),
      "commit" => material.fetch("commit"),
      "tree" => material.fetch("tree"),
      "path" => material.fetch("path"),
      "git_blob" => material.fetch("git_blob"),
      "bytes" => material.fetch("bytes"),
      "sha256" => material.fetch("sha256"),
      "license" => material.fetch("license"),
      "license_path" => material.fetch("license_file"),
      "license_git_blob" => material.fetch("license_git_blob"),
      "license_bytes" => material.fetch("license_file_bytes"),
      "license_sha256" => material.fetch("license_file_sha256")
    }
    expected.each do |key, value|
      raise Failure, "P13 Cacophony evidence differs: #{key}" unless
        record.fetch(key) == value
    end

    vector = git_evidence_file(
      root: paths.fetch("cacophony_origin"),
      commit: record.fetch("commit"),
      tree: record.fetch("tree"),
      path: record.fetch("path"),
      blob: record.fetch("git_blob"),
      bytes: record.fetch("bytes"),
      sha256: record.fetch("sha256"),
      label: "Cacophony vector origin"
    )
    license = git_evidence_file(
      root: paths.fetch("cacophony_origin"),
      commit: record.fetch("commit"),
      tree: record.fetch("tree"),
      path: record.fetch("license_path"),
      blob: record.fetch("license_git_blob"),
      bytes: record.fetch("license_bytes"),
      sha256: record.fetch("license_sha256"),
      label: "Cacophony license"
    )
    require_include(
      license,
      "This is free and unencumbered software released into the public domain.",
      "Cacophony Unlicense grant"
    )

    snow_archive = validated_sources.fetch("archive_sources").fetch("snow")
    snow_projected = validated_sources.fetch("origin_sources").fetch("snow")
    snow_path = record.fetch("snow_archive_path")
    raise Failure, "Snow Cacophony vector bytes differ from primary origin" unless
      snow_archive.fetch(snow_path).fetch("contents") == vector
    raise Failure, "Snow Cacophony vector remains in compile projection" if
      snow_projected.key?(snow_path)
    raise Failure, "Snow Cacophony projection disposition differs" unless
      record.fetch("projection_action") == "DELETE_WHOLE_FILE"
    true
  rescue KeyError => error
    raise Failure, "P13 Cacophony field missing: #{error.key}"
  end

  def validate_source_closure(evidence, paths)
    packages = evidence.fetch("closure").fetch("packages")
    projection = evidence.fetch("compile_projection")
    projection_records = projection.fetch("packages")
      .to_h { |record| [record.fetch("name"), record] }
    package_names = packages.map { |record| record.fetch("name") }
    raise Failure, "compile projection package set differs" unless
      COMPILE_PROJECTION_PATHS.keys.sort == package_names.sort &&
      projection_records.keys.sort == package_names.sort

    registry_sources = {}
    origin_sources = {}
    archive_sources = {}
    path_sources = {}
    archive_file_count = 0
    projected_file_count = 0
    deleted_file_count = 0
    snow_archive_lock = nil

    packages.each do |record|
      name = record.fetch("name")
      version = record.fetch("version")
      archive = File.join(
        paths.fetch("archive_root"),
        "#{name}-#{version}.crate"
      )
      archive_bytes = verify_file(
        archive,
        bytes: record.fetch("archive_bytes"),
        sha256: record.fetch("archive_sha256"),
        context: "#{name} #{version} crate archive"
      )
      entries = crate_entries_bytes(archive_bytes, "#{name}-#{version}")
      archive_sources[name] = entries
      validate_package_archive(record, entries)
      snow_archive_lock = entries.fetch("Cargo.lock").fetch("contents") if
        name == "snow"
      archive_file_count += entries.length
      if record.key?("archive_file_count")
        raise Failure, "#{name} archive file count differs" unless
          entries.length == record.fetch("archive_file_count")
      end
      projected, deleted = validate_compile_projection(
        record,
        entries,
        projection_records.fetch(name),
        evidence
      )
      projected_file_count += projected.length
      deleted_file_count += deleted.length
      origin_sources[name] = projected

      case record.fetch("source_mode")
      when "registry_archive"
        extracted = File.join(
          paths.fetch("registry_source_root"),
          "#{name}-#{version}"
        )
        validate_exact_extraction(
          entries,
          tree_entries(extracted),
          context: "#{name} #{version} Cargo extraction",
          allow_cargo_ok: true
        )
        registry_sources["#{name}-#{version}"] = {
          "archive_sha256" => record.fetch("archive_sha256"),
          "entries" => projected
        }
      when "exact_projected_path_dependency"
        raise Failure, "unexpected projected package: #{name}" unless
          %w[chacha20 poly1305 snow].include?(name)
        path_sources[name] = projected
      else
        raise Failure, "unknown P13 Noise source mode: #{name}"
      end
    end

    raise Failure, "path source projection set differs" unless
      path_sources.keys.sort == %w[chacha20 poly1305 snow]
    validate_compile_projection_inventory(
      projection,
      origin_sources,
      archive_file_count,
      projected_file_count,
      deleted_file_count
    )
    validate_project_poly1305_source(evidence, origin_sources.fetch("poly1305"))
    {
      "registry" => registry_sources,
      "snow" => path_sources.fetch("snow"),
      "chacha20" => path_sources.fetch("chacha20"),
      "poly1305" => path_sources.fetch("poly1305"),
      "snow_archive_lock" => snow_archive_lock,
      "origin_sources" => origin_sources,
      "archive_sources" => archive_sources
    }
  rescue KeyError => error
    raise Failure, "P13 Noise source field missing: #{error.key}"
  end

  def validate_compile_projection(package, archive, record, evidence = nil)
    name = package.fetch("name")
    retained_paths = COMPILE_PROJECTION_PATHS.fetch(name)
    raise Failure, "#{name} projection path order differs" unless
      retained_paths == retained_paths.sort &&
      retained_paths.uniq.length == retained_paths.length
    missing = retained_paths - archive.keys
    raise Failure, "#{name} projection path is absent from archive" unless
      missing.empty?
    raise Failure, "#{name} projection omitted a legal file" unless
      (package.fetch("license_files").keys - retained_paths).empty?

    projected = archive.select { |path, _entry| retained_paths.include?(path) }
    deleted = archive.reject { |path, _entry| retained_paths.include?(path) }
    additions = evidence ? projection_notice_entries(evidence, name) : {}
    raise Failure, "#{name} added notice collides with archive" unless
      (additions.keys & archive.keys).empty?
    projected.merge!(additions)
    replacement_actions = {}
    if name == "poly1305"
      source_path = "src/backend/soft.rs"
      original = projected.fetch(source_path)
      replacement = verify_file(
        File.join(ROOT, PROJECT_POLY1305_SOURCE),
        bytes: record.fetch("replacement_bytes"),
        sha256: record.fetch("replacement_sha256"),
        context: "project-authored Poly1305 backend"
      )
      raise Failure, "Poly1305 replacement input size differs" unless
        original.fetch("contents").bytesize == record.fetch("replacement_input_bytes")
      raise Failure, "Poly1305 replacement input hash differs" unless
        Digest::SHA256.hexdigest(original.fetch("contents")) ==
          record.fetch("replacement_input_sha256")
      projected[source_path] = {"mode" => "644", "contents" => replacement}
      replacement_actions[source_path] = "REPLACE_PROJECT_SOURCE"

      manifest_path = record.fetch("license_replacement_path")
      manifest = projected.fetch(manifest_path)
      projected_manifest = project_poly1305_manifest(
        manifest.fetch("contents"),
        record
      )
      projected[manifest_path] = {
        "mode" => manifest.fetch("mode"),
        "contents" => projected_manifest
      }
      replacement_actions[manifest_path] = "REPLACE_LICENSE_DECLARATION"
      raise Failure, "Poly1305 projected Cargo license differs" unless
        package_toml_string(
          projected_manifest,
          "license",
          "projected Poly1305 Cargo manifest"
        ) == "Apache-2.0"
    end

    canonical_paths = retained_paths.join("\n") + "\n"
    deleted_paths = deleted.keys.sort_by(&:b)
    action_rows = archive.keys.sort_by(&:b).map do |path|
      input = archive.fetch(path)
      input_fields = [
        input.fetch("mode"),
        input.fetch("contents").bytesize.to_s,
        Digest::SHA256.hexdigest(input.fetch("contents"))
      ]
      if deleted.key?(path)
        [path, "DELETE_WHOLE_FILE", *input_fields, "-", "-", "-"].join("\0")
      elsif replacement_actions.key?(path)
        output = projected.fetch(path)
        [
          path,
          replacement_actions.fetch(path),
          *input_fields,
          output.fetch("mode"),
          output.fetch("contents").bytesize.to_s,
          Digest::SHA256.hexdigest(output.fetch("contents"))
        ].join("\0")
      else
        [path, "RETAIN_EXACT", *input_fields, *input_fields].join("\0")
      end
    end
    action_rows.concat(additions.keys.sort_by(&:b).map do |path|
      output = additions.fetch(path)
      [
        path,
        "ADD_ORIGIN_NOTICE",
        "-",
        "-",
        "-",
        output.fetch("mode"),
        output.fetch("contents").bytesize.to_s,
        Digest::SHA256.hexdigest(output.fetch("contents"))
      ].join("\0")
    end)
    action_rows.sort_by! { |row| row.split("\0", 2).first.b }
    added_paths = additions.keys.sort_by(&:b)
    raise Failure, "#{name} compile projection record differs" unless
      record.fetch("archive_file_count") == archive.length &&
      record.fetch("retained_file_count") == projected.length &&
      record.fetch("deleted_file_count") == deleted.length &&
      record.fetch("replacement_file_count") == replacement_actions.length &&
      record.fetch("retained_paths_sha256") ==
        Digest::SHA256.hexdigest(canonical_paths) &&
      record.fetch("deleted_paths_sha256") ==
        canonical_path_digest(deleted_paths) &&
      record.fetch("action_inventory_sha256") ==
        Digest::SHA256.hexdigest(action_rows.join("\n") + "\n") &&
      record.fetch("added_notice_file_count", 0) == additions.length &&
      record.fetch(
        "added_notice_paths_sha256",
        canonical_path_digest([])
      ) == canonical_path_digest(added_paths) &&
      record.fetch("projected_tree_sha256") == entry_tree_digest(projected) &&
      record.fetch("deleted_tree_sha256") == entry_tree_digest(deleted) &&
      record.fetch("mixed_file_byte_range_edits") == 0 &&
      record.fetch("license_election") == projection_license_election(package)
    raise Failure, "#{name} compile projection action count differs" unless
      archive.length + additions.length ==
        projected.length + deleted.length
    [projected, deleted]
  rescue KeyError => error
    raise Failure, "#{name} compile projection field missing: #{error.key}"
  end

  def projection_license_election(package)
    return "Apache-2.0" if package.fetch("name") == "poly1305"
    return "BSD-3-Clause" if package.fetch("declared_license") == "BSD-3-Clause"

    "MIT"
  end

  def project_poly1305_manifest(contents, record)
    raise Failure, "Poly1305 license replacement input size differs" unless
      contents.bytesize == record.fetch("license_replacement_input_bytes")
    raise Failure, "Poly1305 license replacement input hash differs" unless
      Digest::SHA256.hexdigest(contents) ==
        record.fetch("license_replacement_input_sha256")
    raise Failure, "Poly1305 license declaration match count differs" unless
      contents.scan(POLY1305_ARCHIVE_LICENSE_LINE).length == 1

    projected = contents.sub(
      POLY1305_ARCHIVE_LICENSE_LINE,
      POLY1305_PROJECTED_LICENSE_BLOCK
    )
    raise Failure, "Poly1305 license replacement output differs" unless
      projected.bytesize == record.fetch("license_replacement_bytes") &&
      Digest::SHA256.hexdigest(projected) ==
        record.fetch("license_replacement_sha256")
    projected
  rescue KeyError => error
    raise Failure, "Poly1305 license replacement field missing: #{error.key}"
  end

  def projection_notice_entries(evidence, name)
    case name
    when "generic-array"
      record = evidence.fetch("generic_array_origin_review")
      source = generic_array_origin_source(record)
      mit = origin_license_file(record, "LICENSE-MIT", "Rust array")
      header_lines = record.fetch("projected_notice").fetch("source_header_lines")
      notice = source.lines.first(header_lines).join + "\n" + mit
      validate_projected_notice(
        record.fetch("projected_notice"),
        GENERIC_ARRAY_NOTICE_PATH,
        notice,
        "generic-array Rust"
      )
    when "typenum"
      record = evidence.fetch("typenum_origin_review")
      source = typenum_origin_source(record)
      mit = origin_license_file(record, "LICENSE-MIT", "rust-num")
      header_lines = record.fetch("projected_notice").fetch("source_header_lines")
      notice = source.lines.first(header_lines).join + "\n" + mit
      validate_projected_notice(
        record.fetch("projected_notice"),
        TYPENUM_NOTICE_PATH,
        notice,
        "typenum rust-num"
      )
    else
      {}
    end
  rescue KeyError => error
    raise Failure, "#{name} projected notice field missing: #{error.key}"
  end

  def validate_projected_notice(record, expected_path, contents, label)
    raise Failure, "#{label} projected notice differs" unless
      record.fetch("path") == expected_path &&
      record.fetch("bytes") == contents.bytesize &&
      record.fetch("sha256") == Digest::SHA256.hexdigest(contents)
    {expected_path => {"mode" => "644", "contents" => contents}}
  end

  def validate_compile_projection_inventory(
    record,
    sources,
    archive_file_count,
    projected_file_count,
    deleted_file_count
  )
    rows = sources.keys.sort_by(&:b).flat_map do |package|
      sources.fetch(package).keys.sort_by(&:b).map do |path|
        entry = sources.fetch(package).fetch(path)
        [
          package,
          path,
          entry.fetch("mode"),
          entry.fetch("contents").bytesize.to_s,
          Digest::SHA256.hexdigest(entry.fetch("contents"))
        ].join("\0")
      end
    end
    canonical = rows.join("\n") + "\n"
    text_paths = []
    binary_paths = []
    sources.each do |package, entries|
      entries.each do |path, entry|
        bytes = entry.fetch("contents")
        qualified = "#{package}/#{path}"
        if strict_text?(bytes)
          text_paths << qualified
        else
          binary_paths << qualified
        end
      end
    end
    text_paths.sort_by!(&:b)
    binary_paths.sort_by!(&:b)
    raise Failure, "compile projection aggregate differs" unless
      record.fetch("action_types") == %w[
        ADD_ORIGIN_NOTICE
        DELETE_WHOLE_FILE
        REPLACE_LICENSE_DECLARATION
        REPLACE_PROJECT_SOURCE
        RETAIN_EXACT
      ] &&
      record.fetch("selected_package_count") == sources.length &&
      record.fetch("archive_file_count") == archive_file_count &&
      record.fetch("projected_file_count") == projected_file_count &&
      record.fetch("deleted_file_count") == deleted_file_count &&
      record.fetch("replacement_file_count") == 2 &&
      record.fetch("added_notice_file_count") == 2 &&
      record.fetch("text_file_count") == text_paths.length &&
      record.fetch("binary_file_count") == binary_paths.length &&
      record.fetch("text_paths_sha256") == canonical_path_digest(text_paths) &&
      record.fetch("binary_paths_sha256") == canonical_path_digest(binary_paths) &&
      record.fetch("inventory_sha256") == Digest::SHA256.hexdigest(canonical) &&
      record.fetch("result") ==
        "EXACT_ADMITTED_PROJECTION_AND_CONSERVATIVE_INTENDED_LINUX_SOURCE_SET" &&
      record.fetch("native_linux_file_reachability") ==
        "DEFERRED_TO_P14_READ_ONLY_SNAPSHOT_BUILDS"
    true
  rescue KeyError => error
    raise Failure, "compile projection aggregate field missing: #{error.key}"
  end

  def validate_package_archive(record, entries)
    context = "#{record.fetch('name')} #{record.fetch('version')}"
    cargo_toml = entries.fetch("Cargo.toml").fetch("contents")
    raise Failure, "#{context} Cargo package name differs" unless
      package_toml_string(cargo_toml, "name", context) == record.fetch("name")
    raise Failure, "#{context} Cargo package version differs" unless
      package_toml_string(cargo_toml, "version", context) == record.fetch("version")
    declared_license = package_toml_string(cargo_toml, "license", context)
    raise Failure, "#{context} Cargo license differs" unless
      declared_license == record.fetch("declared_license")
    raise Failure, "#{context} license expression is not approved" unless
      APPROVED_LICENSE_EXPRESSIONS.include?(declared_license)
    raise Failure, "#{context} Cargo repository differs" unless
      package_toml_string(cargo_toml, "repository", context) ==
        record.fetch("repository")
    validate_license_inventory(record, entries)

    return true unless record.key?("vcs_commit")

    vcs = parse_json(
      entries.fetch(".cargo_vcs_info.json").fetch("contents"),
      "#{context} Cargo VCS metadata"
    )
    raise Failure, "#{context} VCS commit differs" unless
      vcs.fetch("git").fetch("sha1") == record.fetch("vcs_commit")
    true
  rescue KeyError => error
    raise Failure, "#{context} archive field missing: #{error.key}"
  end

  def validate_license_inventory(record, entries)
    actual = entries.each_with_object({}) do |(path, entry), inventory|
      basename = File.basename(path)
      next unless basename.match?(
        /\A(?:LICENSE|LICENCE|COPYING|UNLICENSE|NOTICE|COPYRIGHT|AUTHORS|CONTRIBUTORS)/i
      )

      inventory[path] = Digest::SHA256.hexdigest(entry.fetch("contents"))
    end
    expected = record.fetch("license_files")
    raise Failure, "#{record.fetch('name')} license file inventory differs" unless
      actual == expected
    true
  end

  def validate_exact_extraction(archive, extracted, context:, allow_cargo_ok:)
    extracted = extracted.dup
    cargo_ok = extracted.delete(".cargo-ok")
    if allow_cargo_ok
      raise Failure, "#{context} Cargo marker differs" unless
        cargo_ok &&
        cargo_ok.fetch("contents") == "{\"v\":1}" &&
        cargo_ok.fetch("mode") == "644"
    elsif cargo_ok
      raise Failure, "#{context} has an unrecorded Cargo marker"
    end
    compare_entry_maps(archive, extracted, context)
  end

  def validate_git_tree_binding(output, path, blob)
    expected = "100644 blob #{blob}\t#{path}\n"
    raise Failure, "Git tree binding differs: #{path}" unless output == expected
    true
  end

  def validate_project_poly1305_source(evidence, entries)
    record = evidence.fetch("project_poly1305_source_review")
    source = entries.fetch("src/backend/soft.rs").fetch("contents")
    tracked = verify_file(
      File.join(ROOT, PROJECT_POLY1305_SOURCE),
      bytes: record.fetch("bytes"),
      sha256: record.fetch("sha256"),
      context: "project-authored Poly1305 backend"
    )
    raise Failure, "project Poly1305 materialized source differs" unless
      source == tracked
    [
      "Project-authored 64-bit Poly1305 backend",
      "const R_CLAMP",
      "fn compute_block",
      "fn finalize_mut",
      "impl UniversalHash for State"
    ].each do |marker|
      require_include(source, marker, "project Poly1305 #{marker}")
    end
    [
      "poly1305-donna",
      "rust-crypto project",
      "unsafe",
      "std::",
      "extern crate"
    ].each do |marker|
      require_exclude(source, marker, "project Poly1305 prohibited marker")
    end
    raise Failure, "project Poly1305 source review differs" unless
      record.fetch("path") == PROJECT_POLY1305_SOURCE &&
      record.fetch("license") == "Apache-2.0" &&
      record.fetch("authorship") ==
        "PROJECT_AUTHORED_CLEAN_ROOM_TECHNICAL_SOFTWARE" &&
      record.fetch("external_implementation_bytes_used") == false &&
      record.fetch("selected_backend") == "poly1305_force_soft" &&
      record.fetch("arithmetic") == "three_radix_limbs_44_44_42" &&
      record.fetch("validation") == [
        "project_authored_FIXTURE_TECNICA_independent_32_bit_reference_20_cases",
        "six_authenticated_channel_tests"
      ] &&
      record.fetch("result") ==
        "PROJECT_SOURCE_BOUND_WITH_NO_EXTERNAL_IMPLEMENTATION_BYTES"
    true
  rescue KeyError => error
    raise Failure, "project Poly1305 field missing: #{error.key}"
  end

  def validate_source_origin_review(evidence, validated_sources)
    record = evidence.fetch("source_origin_review")
    sources = validated_sources.fetch("origin_sources")
    packages = evidence.fetch("closure").fetch("packages")
      .map { |package| package.fetch("name") }
      .sort
    raise Failure, "source origin package inventory differs" unless
      record.fetch("packages") == packages &&
      sources.keys.sort == packages &&
      record.fetch("package_count") == packages.length

    scan = record.fetch("scan")
    raise Failure, "source origin scan scope differs" unless
      scan.fetch("scope") ==
        "every_strict_UTF_8_no_NUL_projected_file_without_extension_filter" &&
      scan.fetch("pattern_version") == "P13_ORIGIN_STATEMENTS_V5" &&
      scan.fetch("text_file_count") ==
        evidence.fetch("compile_projection").fetch("text_file_count") &&
      scan.fetch("binary_file_count") ==
        evidence.fetch("compile_projection").fetch("binary_file_count")

    rows = source_origin_notice_rows(sources)
    expected = record.fetch("notices").map do |notice|
      [
        notice.fetch("package"),
        notice.fetch("path"),
        notice.fetch("start_line"),
        notice.fetch("end_line"),
        notice.fetch("statement_sha256")
      ]
    end
    raise Failure, "source origin notice order or identity differs" unless
      expected == expected.sort_by { |row| [row[0].b, row[1].b, row[2], row[3]] } &&
      expected.uniq.length == expected.length
    raise Failure, "source origin notice inventory differs" unless rows == expected
    canonical = rows.map do |package, path, start_line, end_line, statement_sha256|
      [
        package,
        path,
        start_line.to_s,
        end_line.to_s,
        statement_sha256
      ].join("\0")
    end.join("\n") + "\n"
    raise Failure, "source origin scan digest differs" unless
      rows.length == scan.fetch("statement_count") &&
      Digest::SHA256.hexdigest(canonical) ==
        scan.fetch("canonical_rows_sha256")

    record.fetch("notices").each do |notice|
      disposition = notice.fetch("disposition")
      witness = notice.fetch("witness")
      raise Failure, "source origin notice disposition is unsupported" unless
        ORIGIN_NOTICE_DISPOSITIONS.include?(disposition)
      witness_record = ORIGIN_WITNESSES.fetch(witness) do
        raise Failure, "source origin witness is unsupported"
      end
      raise Failure, "source origin witness package differs" unless
        witness_record.fetch("packages").include?(notice.fetch("package"))
      raise Failure, "source origin witness disposition differs" unless
        witness_record.fetch("dispositions").include?(disposition)
    end
    validate_origin_rights_predicates(evidence, sources, record.fetch("notices"))
    validate_curve25519_vector_origin(
      record.fetch("curve25519_ristretto_vector"),
      validated_sources,
      record.fetch("notices")
    )
    validate_typenum_origin(evidence, sources.fetch("typenum"))
    validate_generic_array_origin(evidence, sources.fetch("generic-array"))
    raise Failure, "source origin review result differs" unless
      record.fetch("result") ==
        "ALL_CURRENT_PROJECTED_ORIGIN_STATEMENTS_MATCHING_V5_REVIEW_VOCABULARY_WITNESSED"
    true
  rescue KeyError => error
    raise Failure, "source origin review field missing: #{error.key}"
  end

  def validate_curve25519_vector_origin(record, validated_sources, notices)
    package = "curve25519-dalek"
    retained_path = record.fetch("retained_path")
    source_path = record.fetch("source_path")
    archive = validated_sources.fetch("archive_sources").fetch(package)
    projected = validated_sources.fetch("origin_sources").fetch(package)
    retained = projected.fetch(retained_path).fetch("contents")
    source = archive.fetch(source_path).fetch("contents")
    lines = retained.lines
    start_line = record.fetch("start_line")
    end_line = record.fetch("end_line")
    statement = lines[(start_line - 1)..(end_line - 1)].join.b
    notice = notices.find do |candidate|
      candidate.fetch("package") == package &&
        candidate.fetch("path") == retained_path &&
        candidate.fetch("start_line") == start_line &&
        candidate.fetch("end_line") == end_line
    end
    license = archive.fetch(record.fetch("license_path")).fetch("contents")

    raise Failure, "Curve25519 extracted-vector origin binding differs" unless
      record.fetch("source_projection_action") == "DELETE_WHOLE_FILE" &&
      !projected.key?(source_path) &&
      statement.bytesize == record.fetch("statement_bytes") &&
      Digest::SHA256.hexdigest(statement) ==
        record.fetch("statement_sha256") &&
      source.bytesize == record.fetch("source_bytes") &&
      Digest::SHA256.hexdigest(source) == record.fetch("source_sha256") &&
      Digest::SHA256.hexdigest(license) == record.fetch("license_sha256") &&
      notice &&
      notice.fetch("statement_sha256") == record.fetch("statement_sha256") &&
      notice.fetch("disposition") ==
        "SAME_PACKAGE_COPY_CURRENT_BYTES_BSD_3_CLAUSE" &&
      notice.fetch("witness") ==
        "CURVE25519_BSD_AND_EMBEDDED_GO_GRANT" &&
      record.fetch("result") ==
        "RETAINED_TEST_VECTOR_BYTES_BOUND_TO_DELETED_SAME_PACKAGE_BSD_SOURCE"
    true
  rescue KeyError => error
    raise Failure, "Curve25519 extracted-vector field missing: #{error.key}"
  end

  def source_origin_notice_rows(sources)
    rows = source_origin_notice_rows_v4(sources)
    rows.concat(reproduced_source_origin_notice_rows(sources))
    rows.sort_by { |row| [row[0].b, row[1].b, row[2], row[3]] }
  end

  def source_origin_notice_rows_v4(sources)
    sources.keys.sort_by(&:b).flat_map do |package|
      sources.fetch(package).keys.sort_by(&:b).flat_map do |path|
        bytes = sources.fetch(package).fetch(path).fetch("contents")
        next [] unless strict_text?(bytes)

        lines = bytes.dup.force_encoding(Encoding::UTF_8).lines
        covered_through = -1
        lines.each_index.each_with_object([]) do |index, rows|
          next if index <= covered_through
          normalized = normalized_origin_line(lines.fetch(index))
          final = origin_statement_end(lines, index, path, normalized)
          paragraph = lines[index..final].map do |line|
            normalized_origin_line(line)
          end.join(" ")
          next unless origin_notice_start?(path, normalized, paragraph)

          statement = lines[index..final].join.b
          rows << [
            package,
            path,
            index + 1,
            final + 1,
            Digest::SHA256.hexdigest(statement)
          ]
          covered_through = final
        end
      end
    end
  end

  def reproduced_source_origin_notice_rows(sources)
    sources.keys.sort_by(&:b).flat_map do |package|
      sources.fetch(package).keys.sort_by(&:b).flat_map do |path|
        bytes = sources.fetch(package).fetch(path).fetch("contents")
        next [] unless strict_text?(bytes)

        lines = bytes.dup.force_encoding(Encoding::UTF_8).lines
        covered_through = -1
        lines.each_index.each_with_object([]) do |index, rows|
          next if index <= covered_through
          normalized = normalized_origin_line(lines.fetch(index))
          next if origin_comment_separator?(normalized)

          final = reproduced_origin_statement_end(lines, index, path, normalized)
          paragraph = lines[index..final].map do |line|
            normalized_origin_line(line)
          end.join(" ")
          next unless paragraph.match?(REPRODUCED_ORIGIN_NOTICE_PATTERN)

          statement = lines[index..final].join.b
          rows << [
            package,
            path,
            index + 1,
            final + 1,
            Digest::SHA256.hexdigest(statement)
          ]
          covered_through = final
        end
      end
    end
  end

  def origin_notice_start?(path, normalized, paragraph = normalized)
    if File.basename(path).match?(ORIGIN_LEGAL_FILE_PATTERN)
      return normalized.match?(ORIGIN_LEGAL_DERIVATION_PATTERN)
    end

    paragraph.match?(ORIGIN_NOTICE_PATTERN)
  end

  def normalized_origin_line(line)
    line.sub(
      /\A\s*(?:(?:\/\/(?:\/|!)?)|(?:\/\*+)|(?:\*+)|#)\s?/,
      ""
    ).strip
  end

  def origin_statement_end(lines, index, path, normalized)
    return index if
      normalized.match?(/\A(?:Portions\s+)?Copyright\b/i) ||
      normalized.match?(/\AProject-authored\b/i)

    source_comment = lines.fetch(index).match?(/\A\s*(?:\/\/|\/\*|\*)/)
    final = index
    while final - index < ORIGIN_STATEMENT_MAX_LINES - 1 &&
          final + 1 < lines.length
      break if normalized_origin_line(lines.fetch(final)).match?(/[.!?]\z/)

      candidate = lines.fetch(final + 1)
      candidate_normalized = normalized_origin_line(candidate)
      break if candidate_normalized.empty?
      break if
        source_comment &&
        !candidate.match?(/\A\s*(?:\/\/|\/\*|\*)/)
      break if !source_comment && path.end_with?(".rs")

      final += 1
    end
    final
  end

  def reproduced_origin_statement_end(lines, index, path, normalized)
    unless normalized.match?(
      /\A(?:
        For\ more\ information\ on\ HSalsa
        | From\ the\ HFS\ spec,\ Section\ 5:
      )/ix
    )
      return origin_statement_end(lines, index, path, normalized)
    end

    final = index
    while final - index < ORIGIN_STATEMENT_MAX_LINES - 1 &&
          final + 1 < lines.length &&
          lines.fetch(final + 1).match?(/\A\s*(?:\/\/|\/\*|\*)/)
      final += 1
    end
    final
  end

  def origin_comment_separator?(normalized)
    normalized.empty? || normalized.match?(/\A[\/\-*_=]+\z/)
  end

  def validate_origin_rights_predicates(evidence, sources, notices)
    by_package = notices.group_by { |notice| notice.fetch("package") }
    expected_packages = %w[
      blake2
      chacha20
      chacha20poly1305
      curve25519-dalek
      generic-array
      poly1305
      rustc_version
      semver
      snow
      subtle
      typenum
      zeroize
    ]
    raise Failure, "source origin notice package set differs" unless
      by_package.keys.sort == expected_packages

    blake_license = sources.fetch("blake2").fetch("LICENSE-MIT").fetch("contents")
    require_include(
      blake_license,
      "Copyright (c) 2015-2016 The blake2-rfc Developers",
      "BLAKE2 origin copyright"
    )
    require_include(
      sources.fetch("blake2").fetch("src/simd.rs").fetch("contents"),
      "Licensed under the Apache License",
      "BLAKE2 copied-file Apache grant"
    )

    curve_license = sources.fetch("curve25519-dalek").fetch("LICENSE").fetch("contents")
    require_include(
      curve_license,
      "Portions of curve25519-dalek were originally derived from Adam Langley's",
      "Curve25519 origin notice"
    )
    require_include(
      curve_license,
      "Copyright (c) 2012 The Go Authors",
      "Curve25519 embedded Go BSD grant"
    )

    require_include(
      sources.fetch("generic-array").fetch(GENERIC_ARRAY_NOTICE_PATH).fetch("contents"),
      "Copyright 2014 The Rust Project Developers",
      "generic-array Rust origin notice"
    )
    require_include(
      sources.fetch("chacha20").fetch("src/backends/soft.rs").fetch("contents"),
      "ChaCha",
      "ChaCha20 same-package software backend"
    )
    require_include(
      sources.fetch("subtle").fetch("LICENSE").fetch("contents"),
      "Redistribution and use in source and binary forms",
      "subtle BSD grant"
    )
    require_include(
      sources.fetch("rustc_version").fetch("LICENSE-MIT").fetch("contents"),
      "Permission is hereby granted",
      "rustc_version MIT grant"
    )
    require_include(
      sources.fetch("semver").fetch("LICENSE-MIT").fetch("contents"),
      "Permission is hereby granted",
      "semver MIT grant"
    )
    require_include(
      sources.fetch("typenum").fetch(TYPENUM_NOTICE_PATH).fetch("contents"),
      "Copyright 2014-2016 The Rust Project Developers",
      "typenum rust-num origin notice"
    )
    require_include(
      sources.fetch("zeroize").fetch("LICENSE-MIT").fetch("contents"),
      "Permission is hereby granted",
      "zeroize package grant"
    )
    require_include(
      sources.fetch("snow").fetch("Cargo.toml").fetch("contents"),
      "[dependencies.chacha20poly1305]",
      "Snow dependency graph witness"
    )
    raise Failure, "Poly1305 projection retained prohibited upstream backends" unless
      sources.fetch("poly1305").keys.sort ==
        COMPILE_PROJECTION_PATHS.fetch("poly1305")
    raise Failure, "project Poly1305 witness differs" unless
      evidence.fetch("project_poly1305_source_review").fetch("result") ==
        "PROJECT_SOURCE_BOUND_WITH_NO_EXTERNAL_IMPLEMENTATION_BYTES"
    raise Failure, "source origin witness set differs" unless
      notices.map { |notice| notice.fetch("witness") }.uniq.sort ==
        ORIGIN_WITNESSES.keys.sort
    true
  end

  def validate_typenum_origin(evidence, typenum_entries)
    record = evidence.fetch("typenum_origin_review")
    package = evidence.fetch("closure").fetch("packages")
      .find { |candidate| candidate.fetch("name") == "typenum" }
    raise Failure, "typenum package ledger record is missing" unless
      package && package.fetch("version") == record.fetch("version") &&
      package.fetch("vcs_commit") == record.fetch("package_commit")

    package_source = git_evidence_file(
      root: record.fetch("local_package_repository"),
      commit: record.fetch("package_commit"),
      tree: record.fetch("package_tree"),
      path: record.fetch("package_path"),
      blob: record.fetch("package_git_blob"),
      bytes: record.fetch("package_source_bytes"),
      sha256: record.fetch("package_source_sha256"),
      label: "typenum package origin"
    )
    raise Failure, "typenum archive source differs from exact Git source" unless
      package_source ==
        typenum_entries.fetch(record.fetch("package_path")).fetch("contents")
    record.fetch("copied_function_markers").each do |marker|
      require_include(package_source, marker, "typenum copied pow marker")
    end

    origin = typenum_origin_source(record)
    require_include(origin, "pub fn pow<", "rust-num pow function")
    require_include(origin, "while exp & 1 == 0", "rust-num pow algorithm")
    require_include(origin, "let mut acc = base.clone()", "rust-num pow accumulator")

    record.fetch("license_files").each_key do |path|
      license = origin_license_file(record, path, "rust-num")
      if path == "LICENSE-APACHE"
        require_include(license, "Apache License", "rust-num Apache grant")
      else
        require_include(license, "Permission is hereby granted", "rust-num MIT grant")
      end
    end
    raise Failure, "typenum origin result differs" unless
      record.fetch("license") == "MIT OR Apache-2.0" &&
      record.fetch("origin_function") == "num::pow" &&
      record.fetch("result") ==
        "COPIED_POW_IMPLEMENTATION_HAS_IMMUTABLE_ORIGIN_AND_RETAINED_MIT_NOTICE"
    true
  rescue KeyError => error
    raise Failure, "typenum origin field missing: #{error.key}"
  end

  def validate_generic_array_origin(evidence, generic_array_entries)
    record = evidence.fetch("generic_array_origin_review")
    package = evidence.fetch("closure").fetch("packages")
      .find { |candidate| candidate.fetch("name") == "generic-array" }
    raise Failure, "generic-array package ledger record is missing" unless
      package && package.fetch("version") == record.fetch("version")
    package_source = generic_array_entries.fetch(record.fetch("package_path"))
      .fetch("contents")
    record.fetch("package_origin_markers").each do |marker|
      require_include(package_source, marker, "generic-array Rust origin marker")
    end

    origin = generic_array_origin_source(record)
    record.fetch("origin_markers").each do |marker|
      require_include(origin, marker, "Rust array origin marker")
    end
    regions = record.fetch("adapted_regions")
    validate_exact_line_region(
      origin,
      regions.fetch("origin"),
      record.fetch("origin_path"),
      "Rust array adapted origin"
    )
    validate_exact_line_region(
      package_source,
      regions.fetch("package"),
      record.fetch("package_path"),
      "generic-array adapted package region"
    )
    copyright = generic_array_origin_copyright(record)
    require_include(
      copyright,
      "Copyrights in the Rust project are retained by their contributors.",
      "Rust array COPYRIGHT ownership"
    )
    record.fetch("license_files").each_key do |path|
      license = origin_license_file(record, path, "Rust array")
      if path == "LICENSE-APACHE"
        require_include(license, "Apache License", "Rust array Apache grant")
      else
        require_include(license, "Permission is hereby granted", "Rust array MIT grant")
      end
    end
    notice = generic_array_entries.fetch(GENERIC_ARRAY_NOTICE_PATH).fetch("contents")
    expected_notice = projection_notice_entries(evidence, "generic-array")
      .fetch(GENERIC_ARRAY_NOTICE_PATH).fetch("contents")
    raise Failure, "generic-array projected Rust notice differs" unless
      notice == expected_notice
    raise Failure, "generic-array origin result differs" unless
      record.fetch("license") == "MIT OR Apache-2.0" &&
      record.fetch("result") ==
        "RUST_ARRAY_ORIGIN_IMMUTABLE_AND_MIT_NOTICE_RETAINED"
    true
  rescue KeyError => error
    raise Failure, "generic-array origin field missing: #{error.key}"
  end

  def generic_array_origin_source(record)
    git_evidence_file(
      root: record.fetch("local_origin_repository"),
      commit: record.fetch("origin_commit"),
      tree: record.fetch("origin_tree"),
      path: record.fetch("origin_path"),
      blob: record.fetch("origin_git_blob"),
      bytes: record.fetch("origin_source_bytes"),
      sha256: record.fetch("origin_source_sha256"),
      label: "Rust array origin"
    )
  end

  def generic_array_origin_copyright(record)
    copyright = record.fetch("copyright_file")
    git_evidence_file(
      root: record.fetch("local_origin_repository"),
      commit: record.fetch("origin_commit"),
      tree: record.fetch("origin_tree"),
      path: copyright.fetch("path"),
      blob: copyright.fetch("git_blob"),
      bytes: copyright.fetch("bytes"),
      sha256: copyright.fetch("sha256"),
      label: "Rust array COPYRIGHT"
    )
  end

  def typenum_origin_source(record)
    git_evidence_file(
      root: record.fetch("local_origin_repository"),
      commit: record.fetch("origin_commit"),
      tree: record.fetch("origin_tree"),
      path: record.fetch("origin_path"),
      blob: record.fetch("origin_git_blob"),
      bytes: record.fetch("origin_source_bytes"),
      sha256: record.fetch("origin_source_sha256"),
      label: "rust-num pow origin"
    )
  end

  def validate_exact_line_region(source, record, expected_path, label)
    start_line = record.fetch("start_line")
    end_line = record.fetch("end_line")
    lines = source.lines
    raise Failure, "#{label} coordinates differ" unless
      record.fetch("path") == expected_path &&
      start_line.is_a?(Integer) &&
      end_line.is_a?(Integer) &&
      start_line.positive? &&
      end_line >= start_line &&
      end_line <= lines.length

    region = lines[(start_line - 1)..(end_line - 1)].join.b
    raise Failure, "#{label} identity differs" unless
      region.bytesize == record.fetch("bytes") &&
      Digest::SHA256.hexdigest(region) == record.fetch("sha256")
    region
  rescue KeyError => error
    raise Failure, "#{label} field missing: #{error.key}"
  end

  def origin_license_file(record, path, label)
    license_record = record.fetch("license_files").fetch(path)
    git_evidence_file(
      root: record.fetch("local_origin_repository"),
      commit: record.fetch("origin_commit"),
      tree: record.fetch("origin_tree"),
      path: path,
      blob: license_record.fetch("git_blob"),
      bytes: license_record.fetch("bytes"),
      sha256: license_record.fetch("sha256"),
      label: "#{label} #{path}"
    )
  end

  def git_evidence_file(root:, commit:, tree:, path:, blob:, bytes:, sha256:, label:)
    git = "/Library/Developer/CommandLineTools/usr/bin/git"
    actual_commit = command(
      git, "-C", root, "rev-parse", "#{commit}^{commit}",
      env: GIT_ENVIRONMENT,
      label: "#{label} commit"
    ).strip
    actual_tree = command(
      git, "-C", root, "rev-parse", "#{commit}^{tree}",
      env: GIT_ENVIRONMENT,
      label: "#{label} tree"
    ).strip
    raise Failure, "#{label} commit identity differs" unless actual_commit == commit
    raise Failure, "#{label} tree identity differs" unless actual_tree == tree
    binding = command(
      git, "-C", root, "ls-tree", commit, "--", path,
      env: GIT_ENVIRONMENT,
      label: "#{label} path"
    )
    validate_git_tree_binding(binding, path, blob)
    contents = command(
      git, "-C", root, "show", "#{commit}:#{path}",
      env: GIT_ENVIRONMENT,
      label: "#{label} bytes"
    )
    raise Failure, "#{label} size differs" unless contents.bytesize == bytes
    raise Failure, "#{label} hash differs" unless
      Digest::SHA256.hexdigest(contents) == sha256
    raise Failure, "#{label} Git blob differs" unless git_blob_sha1(contents) == blob
    contents
  end

  def compare_entry_maps(expected, actual, context)
    raise Failure, "#{context} path set differs" unless
      expected.keys.sort == actual.keys.sort
    expected.each do |path, expected_entry|
      actual_entry = actual.fetch(path)
      raise Failure, "#{context} mode differs: #{path}" unless
        actual_entry.fetch("mode") == expected_entry.fetch("mode")
      raise Failure, "#{context} bytes differ: #{path}" unless
        actual_entry.fetch("contents") == expected_entry.fetch("contents")
    end
    true
  end

  def validate_advisories(evidence, paths)
    review = evidence.fetch("advisory_review")
    root = paths.fetch("rustsec")
    git = "/Library/Developer/CommandLineTools/usr/bin/git"
    identities = command(
      git, "-C", root, "rev-parse",
      "#{review.fetch('commit')}^{commit}",
      "#{review.fetch('commit')}^{tree}",
      env: GIT_ENVIRONMENT,
      label: "RustSec identity"
    ).lines.map(&:strip)
    raise Failure, "RustSec commit or tree differs" unless
      identities == [review.fetch("commit"), review.fetch("tree")]

    selected = evidence.fetch("closure").fetch("packages").to_h do |record|
      [record.fetch("name"), record.fetch("version")]
    end
    raise Failure, "RustSec selected package path is unsafe" unless
      selected.keys.all? { |name| name.match?(/\A[a-z0-9][a-z0-9_-]*\z/) }
    selected_directories = selected.keys.sort.map { |name| "crates/#{name}" }
    inventory = command(
      git, "-C", root, "ls-tree", "-r", review.fetch("commit"), "--",
      *selected_directories,
      env: GIT_ENVIRONMENT,
      label: "RustSec selected-package inventory"
    ).lines.to_h do |line|
      match = line.match(/\A100644 blob ([0-9a-f]{40})\t([^\n]+)\n\z/)
      raise Failure, "RustSec selected-package tree entry differs" unless match

      [match[2], match[1]]
    end
    actual_paths = inventory.keys.select { |path| path.end_with?(".md") }.sort
    records = review.fetch("matching_advisories")
    validate_advisory_match_set(actual_paths, records)

    advisory_bytes = {}
    records.each do |record|
      path = record.fetch("path")
      raise Failure, "RustSec advisory blob differs" unless
        inventory.fetch(path) == record.fetch("git_blob")
      bytes = git_object_file(
        root: root,
        commit: review.fetch("commit"),
        path: path,
        blob: record.fetch("git_blob"),
        sha256: record.fetch("sha256"),
        context: "RustSec #{record.fetch('id')}"
      )
      advisory_bytes[path] = bytes
      require_include(bytes, "id = \"#{record.fetch('id')}\"", "RustSec ID")
      require_include(
        bytes,
        "package = \"#{record.fetch('package')}\"",
        "RustSec package"
      )
      require_include(bytes, "\"#{record.fetch('patched')}\"", "RustSec patched range")
      raise Failure, "RustSec selected version differs" unless
        selected.fetch(record.fetch("package")) == record.fetch("selected_version")
      threshold = record.fetch("patched").delete_prefix(">= ")
      raise Failure, "RustSec patched expression is unsupported" if
        threshold == record.fetch("patched")
      raise Failure, "selected package does not meet patched threshold" unless
        version_at_least?(record.fetch("selected_version"), threshold)
      raise Failure, "RustSec result overclaims patch state" unless
        record.fetch("result") == "patched"
    end
    validate_advisory_licenses(review, root, advisory_bytes)
    true
  rescue KeyError => error
    raise Failure, "P13 Noise advisory field missing: #{error.key}"
  end

  def validate_advisory_licenses(review, root, advisory_bytes)
    root_license = git_object_file(
      root: root,
      commit: review.fetch("commit"),
      path: review.fetch("root_license_path"),
      blob: review.fetch("root_license_git_blob"),
      sha256: review.fetch("root_license_sha256"),
      context: "RustSec root license"
    )
    require_include(
      root_license,
      "Creative Commons Attribution 4.0 International",
      "RustSec CC-BY-4.0 grant"
    )
    require_include(
      root_license,
      '"license" and "url"',
      "RustSec imported-advisory marking"
    )
    cc0 = git_object_file(
      root: root,
      commit: review.fetch("commit"),
      path: review.fetch("cc0_license_path"),
      blob: review.fetch("cc0_license_git_blob"),
      sha256: review.fetch("cc0_license_sha256"),
      context: "RustSec CC0 legal code"
    )
    require_include(cc0, "CC0 1.0 Universal", "RustSec CC0 legal code")

    bundled = git_object_file(
      root: root,
      commit: review.fetch("commit"),
      path: review.fetch("bundled_cc_by_path"),
      blob: review.fetch("bundled_cc_by_git_blob"),
      sha256: review.fetch("bundled_cc_by_sha256"),
      context: "RustSec mislabelled bundled CC license"
    )
    require_include(
      bundled,
      "Attribution-ShareAlike 4.0 International",
      "RustSec bundled license conflict"
    )
    raise Failure, "RustSec bundled CC license disposition differs" unless
      review.fetch("bundled_cc_by_disposition") ==
        "REJECTED_MISLABELLED_CC_BY_SA_4_0_TEXT"

    authoritative = verify_file(
      review.fetch("authoritative_cc_by_local_path"),
      bytes: review.fetch("authoritative_cc_by_bytes"),
      sha256: review.fetch("authoritative_cc_by_sha256"),
      context: "authoritative Creative Commons BY 4.0 legal code"
    )
    require_include(
      authoritative,
      "Creative Commons Attribution 4.0 International Public License",
      "authoritative CC-BY-4.0 legal code"
    )
    require_exclude(
      authoritative,
      "Attribution-ShareAlike",
      "authoritative CC-BY-4.0 legal code"
    )

    explicit = advisory_bytes.values.flat_map do |bytes|
      bytes.scan(/^license = "([^"]+)"$/).flatten
    end
    raise Failure, "RustSec selected advisory license marking differs" unless
      explicit.all? { |license| %w[CC0-1.0 CC-BY-4.0].include?(license) } &&
      explicit.length == review.fetch("selected_explicit_license_mark_count")
    raise Failure, "RustSec advisory license resolution differs" unless
      review.fetch(
        "database_explicit_cc_by_advisory_count_from_admitted_material"
      ) == 21 &&
      review.fetch("authoritative_cc_by_material_id") ==
        "creative-commons-by-4.0-legalcode-p13" &&
      review.fetch("authoritative_cc_by_url") ==
        "https://creativecommons.org/licenses/by/4.0/legalcode.txt" &&
      review.fetch("license_result") ==
        "ROOT_CC_BY_4_0_GRANT_BOUND_TO_AUTHORITATIVE_LEGAL_CODE"
    true
  end

  def git_object_file(root:, commit:, path:, blob:, sha256:, context:)
    git = "/Library/Developer/CommandLineTools/usr/bin/git"
    binding = command(
      git, "-C", root, "ls-tree", commit, "--", path,
      env: GIT_ENVIRONMENT,
      label: "#{context} tree binding"
    )
    validate_git_tree_binding(binding, path, blob)
    contents = command(
      git, "-C", root, "show", "#{commit}:#{path}",
      env: GIT_ENVIRONMENT,
      label: "#{context} bytes"
    )
    raise Failure, "#{context} hash differs" unless
      Digest::SHA256.hexdigest(contents) == sha256
    raise Failure, "#{context} Git blob differs" unless
      git_blob_sha1(contents) == blob
    contents
  end

  def validate_advisory_match_set(actual_paths, records)
    expected_paths = records.map { |record| record.fetch("path") }.sort
    raise Failure, "RustSec matching advisory set differs" unless
      actual_paths == expected_paths
    identities = records.map { |record| [record.fetch("package"), record.fetch("id")] }
    raise Failure, "RustSec advisory records are duplicated" unless
      identities.uniq.length == identities.length
    true
  end

  def version_at_least?(selected, minimum)
    selected_parts = selected.split(".").map { |part| Integer(part, 10) }
    minimum_parts = minimum.split(".").map { |part| Integer(part, 10) }
    length = [selected_parts.length, minimum_parts.length].max
    selected_parts += [0] * (length - selected_parts.length)
    minimum_parts += [0] * (length - minimum_parts.length)
    (selected_parts <=> minimum_parts) >= 0
  rescue ArgumentError
    raise Failure, "unsupported semantic version"
  end

  def validate_runtime(evidence, validated_sources)
    tools = validate_tools(evidence)
    runtime_parent = File.join(ROOT, "target")
    validate_runtime_parent(runtime_parent)
    Dir.mktmpdir("p13-noise-runtime-", runtime_parent) do |directory|
      File.chmod(0o700, directory)
      source_parent = File.join(directory, "source")
      isolated = File.join(source_parent, "probe")
      output = File.join(directory, "output")
      begin
        expected_private_tree = private_tree_entries(evidence, validated_sources)
        FileUtils.mkdir_p(source_parent, mode: 0o700)
        materialize_probe(evidence, isolated)
        materialize_sources(evidence, validated_sources, isolated)
        seal_private_tree(isolated)
        File.chmod(0o555, source_parent)
        FileUtils.mkdir_p(output, mode: 0o700)
        P13RustcDriver.prepare_output_layout(output)
        private_identity = private_tree_identity(source_parent)
        validate_private_tree(
          expected_private_tree,
          isolated,
          identity: private_identity,
          identity_root: source_parent
        )

        environment = {
          "HOME" => "/var/empty",
          "PATH" => "/usr/bin:/bin",
          "LC_ALL" => "C",
          "LANG" => "C",
          "TZ" => "UTC",
          "SOURCE_DATE_EPOCH" => "0",
          "DYLD_LIBRARY_PATH" => File.join(ROOT, ".tools/rust-1.98.0/lib"),
          "SDKROOT" => "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk",
          "CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER" => tools.fetch("ld64.lld")
        }
        source_guard = lambda do
          validate_private_tree(
            expected_private_tree,
            isolated,
            identity: private_identity,
            identity_root: source_parent
          )
        end
        guard = P13RustcDriver::CommandWindowGuard.new(
          invariant: source_guard,
          immutable_files: command_window_files(evidence),
          immutable_trees: command_window_trees(evidence),
          output_root: output,
          ancestor_anchors: [directory],
          expected_generated_files: expected_generated_files(evidence)
        )

        validate_effective_rustc_cfg(
          evidence,
          tools,
          environment,
          guard: guard
        )
        P13RustcDriver.compile_and_test(
          isolated,
          output,
          guard: guard,
          output_prepared: true
        )
        guard.validate_now
      ensure
        unseal_private_tree(source_parent) if File.exist?(source_parent)
      end
    end
    true
  end

  def validate_runtime_parent(path)
    FileUtils.mkdir_p(path)
    stat = File.lstat(path)
    raise Failure, "P13 runtime parent is not a private owned directory" unless
      stat.directory? && !stat.symlink? &&
      stat.uid == Process.euid && (stat.mode & 0o022).zero?
    true
  end

  def materialize_probe(evidence, destination)
    source = File.join(ROOT, evidence.fetch("probe").fetch("root"))
    record = evidence.fetch("probe").fetch("files").find do |candidate|
      candidate.fetch("path") == "src/lib.rs"
    end
    raise Failure, "P13 direct probe source record is missing" unless record

    relative = record.fetch("path")
    target = File.join(destination, relative)
    FileUtils.mkdir_p(File.dirname(target))
    File.binwrite(target, File.binread(File.join(source, relative)))
    File.chmod(0o444, target)
    true
  end

  def materialize_sources(_evidence, validated_sources, isolated)
    sources = validated_sources.fetch("origin_sources")
    P13RustcDriver::PACKAGES.each do |package|
      name = package.fetch(:name)
      version = package.fetch(:version)
      relative = package.fetch(:source, "vendor/#{name}-#{version}")
      materialize_entry_map(
        sources.fetch(name),
        File.join(isolated, relative)
      )
    end
    true
  end

  def materialize_resolver_fixtures(evidence, validated_sources, isolated)
    fixtures = evidence.fetch("runtime_isolation")
      .fetch("resolver_only_technical_fixtures")
    identities = fixtures.map { |record| [record.fetch("name"), record.fetch("version")] }
    raise Failure, "resolver fixture order or identity differs" unless
      identities == identities.sort && identities.uniq.length == identities.length
    selected = evidence.fetch("closure").fetch("packages")
      .map { |record| [record.fetch("name"), record.fetch("version")] }
    raise Failure, "resolver fixture entered selected source closure" unless
      (identities & selected).empty?
    fixtures.each do |record|
      dependencies = record.fetch("required_dependencies", []).map do |dependency|
        [dependency.fetch("name"), dependency.fetch("version")]
      end
      raise Failure, "resolver fixture dependency is not another fixture" unless
        dependencies.all? { |dependency| identities.include?(dependency) }
    end

    snow_lock = parse_lock_packages(
      validated_sources.fetch("snow_archive_lock")
    ).map { |package| [package.fetch("name"), package.fetch("version")] }
    non_snow_identities = identities.reject { |identity| snow_lock.include?(identity) }
    raise Failure, "resolver fixture requirement witness set differs" unless
      non_snow_identities == [["hex-literal", "0.3.4"]]
    hex_literal = fixtures.find { |record| record.fetch("name") == "hex-literal" }
    raise Failure, "hex-literal resolver fixture witness is missing" unless hex_literal
    raise Failure, "hex-literal resolver fixture witness differs" unless
      hex_literal.fetch("requirement_witness") == {
        "selected_package" => "poly1305",
        "manifest_path" => "Cargo.toml",
        "manifest_section" => "dev-dependencies.hex-literal",
        "version_requirement" => "0.3"
      }
    poly1305_manifest = validated_sources.fetch("poly1305")
      .fetch("Cargo.toml").fetch("contents")
    require_include(
      poly1305_manifest,
      "[dev-dependencies.hex-literal]\nversion = \"0.3\"",
      "Poly1305 hex-literal resolver requirement"
    )
    raise Failure, "resolver fixture contract differs" unless
      evidence.fetch("runtime_isolation").fetch("resolver_fixture_contract") ==
        "project_authored_Apache_2_0_FIXTURE_TECNICA_historical_lock_resolution_only_not_materialized_or_executed"

    fixtures.each do |record|
      entries = resolver_fixture_entries(record)
      entries[".cargo-checksum.json"] = {
        "mode" => "644",
        "contents" => cargo_checksum_manifest(entries, nil)
      }
      identity = "#{record.fetch('name')}-#{record.fetch('version')}"
      materialize_entry_map(entries, File.join(isolated, "vendor", identity))
    end
    true
  end

  def resolver_fixture_entries(record)
    name = record.fetch("name")
    version = record.fetch("version")
    features = record.fetch("required_features")
    dependencies = record.fetch("required_dependencies", [])
    raise Failure, "resolver fixture name is unsafe" unless
      name.match?(/\A[a-z0-9][a-z0-9_-]*\z/)
    raise Failure, "resolver fixture version is unsafe" unless
      version.match?(/\A[0-9]+\.[0-9]+\.[0-9]+\z/)
    raise Failure, "resolver fixture feature is unsafe" unless
      features.is_a?(Array) &&
      features.all? { |feature| feature.match?(/\A[a-z0-9][a-z0-9_-]*\z/) }
    raise Failure, "resolver fixture dependency set is malformed" unless
      dependencies.is_a?(Array)
    dependency_identities = dependencies.map do |dependency|
      dependency_name = dependency.fetch("name")
      dependency_version = dependency.fetch("version")
      raise Failure, "resolver fixture dependency name is unsafe" unless
        dependency_name.match?(/\A[a-z0-9][a-z0-9_-]*\z/)
      raise Failure, "resolver fixture dependency version is unsafe" unless
        dependency_version.match?(/\A[0-9]+\.[0-9]+\.[0-9]+\z/)
      [dependency_name, dependency_version]
    end
    raise Failure, "resolver fixture dependency order or identity differs" unless
      dependency_identities == dependency_identities.sort &&
      dependency_identities.uniq.length == dependency_identities.length

    feature_block = if features.empty?
                      ""
                    else
                      "\n[features]\n" +
                        features.map { |feature| "#{feature} = []\n" }.join
                    end
    dependency_block = if dependency_identities.empty?
                         ""
                       else
                         "\n[dependencies]\n" +
                           dependency_identities.map do |dependency_name,
                                                          dependency_version|
                             "#{dependency_name} = \"=#{dependency_version}\"\n"
                           end.join
                       end
    manifest = <<~TOML
      [package]
      name = "#{name}"
      version = "#{version}"
      edition = "2024"
      publish = false
      license = "Apache-2.0"
      description = "FIXTURE_TECNICA resolver-only package; compilation is prohibited"

      [lib]
      path = "src/lib.rs"
      #{feature_block}#{dependency_block}
    TOML
    source = <<~RUST
      compile_error!("FIXTURE_TECNICA resolver-only package entered the compiled graph");
    RUST
    {
      "Cargo.toml" => {"mode" => "644", "contents" => manifest.b},
      "src/lib.rs" => {"mode" => "644", "contents" => source.b}
    }
  rescue KeyError => error
    raise Failure, "resolver fixture field missing: #{error.key}"
  end

  def cargo_checksum_manifest(entries, archive_sha256)
    files = entries.keys.sort_by(&:b).to_h do |path|
      [path, Digest::SHA256.hexdigest(entries.fetch(path).fetch("contents"))]
    end
    JSON.generate("files" => files, "package" => archive_sha256)
  end

  def private_tree_entries(evidence, validated_sources)
    entries = {}
    probe_root = File.join(ROOT, evidence.fetch("probe").fetch("root"))
    record = evidence.fetch("probe").fetch("files").find do |candidate|
      candidate.fetch("path") == "src/lib.rs"
    end
    raise Failure, "P13 direct probe source record is missing" unless record
    relative = record.fetch("path")
    contents = verify_file(
      File.join(probe_root, relative),
      bytes: record.fetch("bytes"),
      sha256: record.fetch("sha256"),
      context: "P13 private probe expected source"
    )
    add_private_entries(
      entries,
      "",
      relative => {"mode" => "444", "contents" => contents}
    )

    sources = validated_sources.fetch("origin_sources")
    P13RustcDriver::PACKAGES.each do |package|
      name = package.fetch(:name)
      version = package.fetch(:version)
      prefix = package.fetch(:source, "vendor/#{name}-#{version}")
      add_private_entries(entries, prefix, sources.fetch(name))
    end
    entries
  end

  def add_private_entries(destination, prefix, source)
    source.each do |relative, entry|
      path = prefix.empty? ? relative : File.join(prefix, relative)
      validate_relative_path(path, "private expected source")
      raise Failure, "private expected source path is duplicated: #{path}" if
        destination.key?(path)

      destination[path] = {
        "mode" => (Integer(entry.fetch("mode"), 8) & 0o555).to_s(8),
        "contents" => entry.fetch("contents")
      }
    end
    true
  rescue KeyError, ArgumentError => error
    raise Failure, "private expected source entry is malformed: #{error.class}"
  end

  def materialize_entry_map(entries, root)
    raise Failure, "private source destination already exists: #{root}" if
      File.exist?(root)
    entries.keys.sort_by(&:b).each do |relative|
      validate_relative_path(relative, "private source materialization")
      entry = entries.fetch(relative)
      path = File.join(root, relative)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, entry.fetch("contents"))
      File.chmod(Integer(entry.fetch("mode"), 8), path)
    end
    compare_entry_maps(entries, tree_entries(root), "private source materialization")
    entries.each_key do |relative|
      path = File.join(root, relative)
      File.chmod(File.stat(path).mode & 0o555, path)
    end
    true
  end

  def seal_private_tree(root)
    paths = Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH)
      .reject { |path| [".", ".."].include?(File.basename(path)) }
    paths.reject { |path| File.directory?(path) }.each do |path|
      raise Failure, "private source tree contains a symlink" if File.symlink?(path)

      File.chmod(File.stat(path).mode & 0o555, path)
    end
    ([root] + paths.select { |path| File.directory?(path) })
      .sort_by { |path| -path.bytesize }
      .each { |path| File.chmod(0o555, path) }
    true
  end

  def private_tree_identity(root)
    paths = [root] + Dir.glob(
      File.join(root, "**", "*"),
      File::FNM_DOTMATCH
    ).reject { |path| [".", ".."].include?(File.basename(path)) }
    paths.sort_by(&:b).to_h do |path|
      stat = File.lstat(path)
      relative = path == root ? "." : path.delete_prefix("#{root}/")
      [
        relative,
        [
          stat.dev,
          stat.ino,
          stat.mode,
          stat.uid,
          stat.gid,
          stat.nlink,
          stat.size,
          stat.ctime.to_i,
          stat.ctime.nsec
        ]
      ]
    end
  end

  def validate_private_tree(expected, root, identity: nil, identity_root: root)
    compare_entry_maps(expected, tree_entries(root), "private source tree")
    paths = [root] + Dir.glob(
      File.join(root, "**", "*"),
      File::FNM_DOTMATCH
    ).reject { |path| [".", ".."].include?(File.basename(path)) }
    paths.each do |path|
      stat = File.lstat(path)
      raise Failure, "private source tree contains a symlink" if stat.symlink?
      raise Failure, "private source tree ownership differs" unless
        stat.uid == Process.euid
      raise Failure, "private source tree remains writable" unless
        (stat.mode & 0o222).zero?
      next unless stat.file?

      raise Failure, "private source file has another hard link" unless
        stat.nlink == 1
    end
    if identity && private_tree_identity(identity_root) != identity
      raise Failure, "private source tree or containing directory identity changed"
    end
    true
  end

  def unseal_private_tree(root)
    paths = [root] + Dir.glob(
      File.join(root, "**", "*"),
      File::FNM_DOTMATCH
    ).reject { |path| [".", ".."].include?(File.basename(path)) }
    paths.each do |path|
      stat = File.lstat(path)
      File.chmod(0o700, path) if stat.directory? && !stat.symlink?
    end
    true
  end

  def validate_effective_rustc_cfg(evidence, tools, environment, guard:)
    output = P13RustcDriver.invoke(
      tools.fetch("rustc"),
      ["--print", "cfg"],
      environment,
      "P13 effective direct rustc cfg",
      guard: guard
    )
    cfg = output.lines.map(&:strip)
    record = evidence.fetch("runtime_isolation")
    required = record.fetch("effective_cfg_required")
    prohibited = record.fetch("effective_cfg_prohibited")
    raise Failure, "P13 required rustc cfg differs" unless
      required.all? { |value| cfg.include?(value) }
    raise Failure, "P13 prohibited rustc cfg is active" unless
      prohibited.none? { |value| cfg.include?(value) }
    raise Failure, "P13 rustflags transport differs" unless
      record.fetch("rustflags_transport") == "DIRECT_RUSTC_ARGUMENT_VECTOR"
    true
  end

  def validate_target_graph_record(evidence, observed)
    record = evidence.fetch("intended_linux_target_graphs")
    expected_targets = [
      "x86_64-unknown-linux-gnu",
      "aarch64-unknown-linux-gnu"
    ]
    raise Failure, "P13 intended Linux target set differs" unless
      record.fetch("targets") == expected_targets &&
      observed.keys == expected_targets
    raise Failure, "P13 intended Linux target edge set differs" unless
      record.fetch("cargo_edges") == %w[normal build]
    expected = record.fetch("selected_external_packages")
    raise Failure, "P13 intended target package order or count differs" unless
      expected == expected.sort &&
      expected.length == record.fetch("selected_external_package_union_count")
    expected_by_target = record.fetch("selected_external_packages_by_target")
    observed.each do |target, packages|
      raise Failure, "P13 Noise #{target} target graph differs" unless
        packages == expected_by_target.fetch(target)
    end
    union = observed.values.flatten.uniq.sort
    raise Failure, "P13 Noise target graph union differs" unless union == expected
    raise Failure, "P13 Noise target-specific package disposition differs" unless
      record.fetch("x86_64_only_packages") ==
        observed.fetch("x86_64-unknown-linux-gnu") -
          observed.fetch("aarch64-unknown-linux-gnu") &&
      record.fetch("aarch64_only_packages") ==
        observed.fetch("aarch64-unknown-linux-gnu") -
          observed.fetch("x86_64-unknown-linux-gnu")
    locked = evidence.fetch("closure").fetch("packages")
      .map { |package| package.fetch("name") }
      .uniq
      .sort
    lock_only = record.fetch("lock_resolution_only_packages")
    raise Failure, "P13 Noise lock-only package disposition differs" unless
      lock_only == lock_only.sort &&
      locked - expected == lock_only &&
      expected - locked == []
    raise Failure, "P13 Snow vector target disposition differs" unless
      record.fetch("selected_feature_vector_tests") == false &&
      record.fetch("deleted_snow_vector_reachable") == false &&
      record.fetch("evidence_scope") ==
        "PACKAGE_GRAPH_ONLY_NOT_NATIVE_FILE_REACHABILITY" &&
      record.fetch("result") ==
        "BOTH_INTENDED_LINUX_PACKAGE_GRAPHS_CLOSED_AND_VECTOR_FREE"
    true
  end

  def validate_static_target_graphs(evidence)
    record = evidence.fetch("intended_linux_target_graphs")
    observed = record.fetch("targets").to_h do |target|
      [
        target,
        record.fetch("selected_external_packages_by_target").fetch(target)
      ]
    end
    validate_target_graph_record(evidence, observed)
    raise Failure, "P13 static target graph evidence disposition differs" unless
      record.fetch("observation_status") ==
        "FROZEN_PREVIOUS_CARGO_OBSERVATION_NOT_REEXECUTED" &&
      record.fetch("validation_role") ==
        "SOURCE_SELECTION_SUPPORT_ONLY_NATIVE_REVALIDATION_REQUIRED_P14"
    true
  rescue KeyError => error
    raise Failure, "P13 static target graph field missing: #{error.key}"
  end

  def validate_direct_compile_contract(evidence)
    record = evidence.fetch("runtime_isolation").fetch("direct_compile")
    driver = verify_file(
      File.join(ROOT, record.fetch("driver_path")),
      bytes: record.fetch("driver_bytes"),
      sha256: record.fetch("driver_sha256"),
      context: "P13 direct rustc driver"
    )
    wrapper = verify_file(
      File.join(ROOT, record.fetch("wrapper_path")),
      bytes: record.fetch("wrapper_bytes"),
      sha256: record.fetch("wrapper_sha256"),
      context: "P13 direct rustc wrapper"
    )
    require_include(driver, "P13RustcDriver", "P13 direct rustc driver module")
    require_include(wrapper, "--disable-gems", "P13 direct rustc wrapper")

    P13RustcDriver.validate_package_plan
    names = P13RustcDriver::PACKAGES.map { |package| package.fetch(:name) }.sort
    raise Failure, "P13 direct compile contract differs" unless
      record.fetch("package_count") == names.length &&
      record.fetch("packages") == names &&
      record.fetch("package_plan_sha256") == direct_package_plan_digest &&
      record.fetch("probe_source_paths") == ["src/lib.rs"] &&
      record.fetch("build_scripts_executed") == false &&
      record.fetch("cargo_executed") == false &&
      record.fetch("network_permitted") == false &&
      record.fetch("command_sequence") == [
        "rustc_rlib_topological_plan",
        "rustc_probe_test_compile",
        "probe_test_execute_single_thread",
        "clippy_driver_probe_metadata_deny_warnings"
      ] &&
      record.fetch("result") ==
        "DIRECT_RUSTC_TEST_AND_CLIPPY_WITHOUT_CARGO"

    command_window = record.fetch("command_window_guard")
    raise Failure, "P13 command-window guard contract differs" unless
      command_window.fetch("before_and_after_every_process") == true &&
      command_window.fetch("continuous_post_command_output_identity") == true &&
      command_window.fetch("first_creation_expected_bytes_bound") == true &&
      command_window.fetch("precreated_output_directory_layout") == true &&
      command_window.fetch("full_ancestor_chain") ==
        "LEXICAL_AND_RESOLVED_COMPONENTS_TO_FILESYSTEM_ROOT" &&
      command_window.fetch("source_tree_and_container_identity_bound") == true &&
      command_window.fetch("output_root_parent_identity_bound") == true &&
      command_window.fetch("preexisting_generated_artifacts_bound") == true &&
      command_window.fetch("identity_fields") == %w[
        file_type
        device
        inode
        mode
        owner
        group
        link_count
        size
        ctime_seconds
        ctime_nanoseconds
        sha256_for_regular_files
      ] &&
      command_window.fetch("immutable_files") == COMMAND_WINDOW_FILES &&
      command_window.fetch("immutable_trees") == COMMAND_WINDOW_TREES &&
      command_window.fetch("generated_files") == EXPECTED_GENERATED_FILES

    validate_toolchain_notices(record)

    rejected = record.fetch("rejected_runtime_tool")
    raise Failure, "P13 rejected Cargo runtime tool record differs" unless
      rejected == {
        "name" => "cargo",
        "path" => ".tools/rust-1.98.0/bin/cargo",
        "sha256" => REJECTED_RUNTIME_TOOL_HASHES.fetch("cargo"),
        "reason" =>
          "STATICALLY_EMBEDS_BYTES_FROM_PERMANENTLY_REJECTED_OPENSSL_3_6_3_PORTFOLIO",
        "disposition" => "NOT_EXECUTED_BY_P13_NOISE_VALIDATION"
      }
    true
  rescue KeyError => error
    raise Failure, "P13 direct compile field missing: #{error.key}"
  end

  def direct_package_plan_digest
    rows = P13RustcDriver::PACKAGES.map do |package|
      {
        "cfg" => Array(package[:cfg]),
        "dependencies" => package.fetch(:dependencies),
        "edition" => package.fetch(:edition),
        "features" => Array(package[:features]),
        "name" => package.fetch(:name),
        "source" => package.fetch(
          :source,
          "vendor/#{package.fetch(:name)}-#{package.fetch(:version)}"
        ),
        "version" => package.fetch(:version)
      }
    end
    Digest::SHA256.hexdigest(JSON.generate(rows))
  end

  def validate_toolchain_notices(record)
    notices = record.fetch("toolchain_notice_files")
    raise Failure, "P13 toolchain notice inventory differs" unless
      notices == TOOLCHAIN_NOTICE_FILES
    contents = notices.to_h do |notice|
      [
        notice.fetch("path"),
        verify_file(
          File.join(ROOT, notice.fetch("path")),
          bytes: notice.fetch("bytes"),
          sha256: notice.fetch("sha256"),
          context: "P13 toolchain notice #{notice.fetch('path')}"
        )
      ]
    end
    rust = contents.fetch(
      ".tools/rust-1.98.0/share/doc/rust/COPYRIGHT.html"
    )
    rust_library = contents.fetch(
      ".tools/rust-1.98.0/share/doc/rust/COPYRIGHT-library.html"
    )
    require_include(
      rust,
      "Copyrights in the Rust project are retained by their contributors.",
      "Rust toolchain rightsholders"
    )
    require_include(
      rust_library,
      "Copyrights in the Rust Standard Library are retained by their contributors.",
      "Rust standard-library rightsholders"
    )
    raise Failure, "P13 toolchain rights and obligations differ" unless
      record.fetch("toolchain_rights") == {
        "rightsholders" => [
          "Rust_Project_contributors",
          "Rust_Standard_Library_contributors",
          "Clippy_contributors",
          "third_party_rightsholders_enumerated_in_bound_Rust_notice_files"
        ],
        "source_closure_evidence" => "toolchain_source_closure",
        "license_scope" =>
          "exact_selected_Rust_1_98_0_compiler_Clippy_LLVM_and_sysroot_source_closure",
        "broad_notice_scope" =>
          "conservative_whole_distribution_attribution_not_active_dependency_proof",
        "excluded_cc0_package" =>
          "notify-8.2.0_in_uninstalled_rust_analyzer_only",
        "obligations" =>
          "retain_applicable_bound_license_and_third_party_notices_if_redistributed",
        "commercial_use_modification_and_redistribution" => "PERMITTED",
        "shipped_with_product" => false
      }
    true
  rescue KeyError => error
    raise Failure, "P13 toolchain notice field missing: #{error.key}"
  end

  def validate_toolchain_tree(records)
    raise Failure, "P13 command-window tree inventory differs" unless
      records == COMMAND_WINDOW_TREES
    records.each do |record|
      root = File.join(ROOT, record.fetch("path"))
      paths = Dir.glob(
        File.join(root, "**", "*"),
        File::FNM_DOTMATCH
      ).reject { |path| [".", ".."].include?(File.basename(path)) }
        .sort_by(&:b)
      raise Failure, "P13 toolchain input tree contains a symlink" if
        paths.any? { |path| File.symlink?(path) }
      files = paths.select { |path| File.file?(path) }
      raise Failure, "P13 toolchain input tree contains an unsupported path" unless
        paths.all? { |path| File.file?(path) || File.directory?(path) }
      rows = files.map do |path|
        relative = path.delete_prefix("#{root}/")
        [
          relative,
          File.size(path).to_s,
          Digest::SHA256.file(path).hexdigest
        ].join("\0")
      end
      raise Failure, "P13 toolchain input tree file count differs" unless
        files.length == record.fetch("file_count")
      raise Failure, "P13 toolchain input tree byte count differs" unless
        files.sum { |path| File.size(path) } == record.fetch("total_bytes")
      raise Failure, "P13 toolchain input tree manifest differs" unless
        Digest::SHA256.hexdigest(rows.join("\n") + "\n") ==
          record.fetch("inventory_sha256")
    end
    true
  rescue Errno::ENOENT
    raise Failure, "P13 toolchain input tree is missing"
  rescue KeyError => error
    raise Failure, "P13 toolchain input tree field missing: #{error.key}"
  end

  def validate_tools(evidence)
    records = evidence.fetch("runtime_isolation").fetch("direct_compile")
      .fetch("command_window_guard").fetch("immutable_files")
    raise Failure, "P13 command-window file inventory differs" unless
      records == COMMAND_WINDOW_FILES
    tools = {}
    records.each do |record|
      name = record.fetch("name")
      path = File.join(ROOT, record.fetch("path"))
      verify_file(
        path,
        bytes: record.fetch("bytes"),
        sha256: record.fetch("sha256"),
        context: "admitted #{name}"
      )
      tools[name] = path
    end
    validate_toolchain_tree(
      evidence.fetch("runtime_isolation").fetch("direct_compile")
        .fetch("command_window_guard").fetch("immutable_trees")
    )
    raise Failure, "P13 direct tool path differs" unless
      tools.fetch("rustc") == P13RustcDriver::RUSTC &&
      tools.fetch("clippy-driver") == P13RustcDriver::CLIPPY &&
      tools.fetch("ld64.lld") == P13RustcDriver::LINKER
    rejected = evidence.fetch("runtime_isolation").fetch("direct_compile")
      .fetch("rejected_runtime_tool")
    verify_file(
      File.join(ROOT, rejected.fetch("path")),
      sha256: REJECTED_RUNTIME_TOOL_HASHES.fetch("cargo"),
      context: "rejected non-executed P13 Cargo"
    )
    tools
  rescue KeyError => error
    raise Failure, "P13 runtime tool field missing: #{error.key}"
  end

  def command_window_files(evidence)
    records = evidence.fetch("runtime_isolation").fetch("direct_compile")
      .fetch("command_window_guard").fetch("immutable_files")
    records.to_h do |record|
      [
        record.fetch("name"),
        {
          path: File.join(ROOT, record.fetch("path")),
          bytes: record.fetch("bytes"),
          sha256: record.fetch("sha256")
        }
      ]
    end
  rescue KeyError => error
    raise Failure, "P13 command-window file field missing: #{error.key}"
  end

  def command_window_trees(evidence)
    records = evidence.fetch("runtime_isolation").fetch("direct_compile")
      .fetch("command_window_guard").fetch("immutable_trees")
    records.to_h do |record|
      [
        record.fetch("name"),
        {
          root: File.join(ROOT, record.fetch("path")),
          file_count: record.fetch("file_count"),
          total_bytes: record.fetch("total_bytes"),
          inventory_sha256: record.fetch("inventory_sha256")
        }
      ]
    end
  rescue KeyError => error
    raise Failure, "P13 command-window tree field missing: #{error.key}"
  end

  def expected_generated_files(evidence)
    records = evidence.fetch("runtime_isolation").fetch("direct_compile")
      .fetch("command_window_guard").fetch("generated_files")
    records.to_h do |record|
      [
        record.fetch("path"),
        {
          bytes: record.fetch("bytes"),
          sha256: record.fetch("sha256")
        }
      ]
    end
  rescue KeyError => error
    raise Failure, "P13 generated artifact field missing: #{error.key}"
  end

  def crate_entries(path, identity)
    crate_entries_bytes(File.binread(path), identity)
  rescue Errno::ENOENT
    raise Failure, "invalid #{identity} crate archive: missing path"
  end

  def crate_entries_bytes(compressed, identity)
    raise Failure, "invalid #{identity} crate archive: compressed bytes exceed limit" if
      compressed.bytesize > P13SourceFetch::MAX_ARCHIVE_BYTES

    manifest = P13SourceFetch.parse_crate_archive(compressed, identity)
    entries = {}
    manifest.fetch("entries").each do |relative, entry|
      next if relative == ".cargo-ok" || entry.fetch("type") == :directory

      entries[relative] = {
        "mode" => (entry.fetch("mode") & 0o7777).to_s(8),
        "contents" => entry.fetch("contents").b
      }
    end
    raise Failure, "#{identity} archive is empty" if entries.empty?
    entries
  rescue Failure
    raise
  rescue P13SourceFetch::Failure => error
    raise Failure, "invalid #{identity} crate archive: #{error.message}"
  rescue StandardError => error
    raise Failure, "invalid #{identity} crate archive: #{error.class}"
  end

  def validate_tar_checksum(header, identity)
    expected = parse_tar_octal(header.byteslice(148, 8), identity, "checksum")
    checksum_header = header.dup
    checksum_header[148, 8] = " " * 8
    actual = checksum_header.bytes.reduce(0, :+)
    raise Failure, "#{identity} archive header checksum differs" unless
      actual == expected
    true
  end

  def parse_tar_octal(field, identity, context)
    raise Failure, "#{identity} archive uses unsupported base-256 #{context}" if
      (field.getbyte(0) & 0x80).positive?
    value = field.delete("\0 ").strip
    raise Failure, "#{identity} archive has malformed #{context}" unless
      value.match?(/\A[0-7]*\z/)
    value.empty? ? 0 : Integer(value, 8)
  end

  def tar_string(field)
    field.split("\0", 2).first
  end

  def tree_entries(root)
    raise Failure, "source tree missing: #{root}" unless File.directory?(root)

    root = File.expand_path(root)
    entries = {}
    Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH).each do |path|
      next if [".", ".."].include?(File.basename(path))
      relative = path.sub("#{root}/", "")
      validate_relative_path(relative, "source tree")
      raise Failure, "source tree contains symlink: #{relative}" if File.symlink?(path)
      next if File.directory?(path)
      raise Failure, "source tree contains unsupported path: #{relative}" unless
        File.file?(path)

      entries[relative] = {
        "mode" => (File.stat(path).mode & 0o7777).to_s(8),
        "contents" => File.binread(path)
      }
    end
    entries
  end

  def entry_tree_digest(entries)
    digest = Digest::SHA256.new
    entries.keys.sort_by(&:b).each do |path|
      entry = entries.fetch(path)
      bytes = entry.fetch("contents")
      digest << "F\0" << path.b << "\0" << entry.fetch("mode") << "\0"
      digest << bytes.bytesize.to_s << "\0" << bytes << "\0"
    end
    digest.hexdigest
  end

  def strict_text?(bytes)
    !bytes.include?("\0") &&
      bytes.dup.force_encoding(Encoding::UTF_8).valid_encoding?
  end

  def canonical_path_digest(paths)
    canonical = paths.empty? ? "" : paths.join("\n") + "\n"
    Digest::SHA256.hexdigest(canonical)
  end

  def validate_archive_path(path, identity)
    raise Failure, "#{identity} archive path is unsafe" if
      path.empty? || path.start_with?("/") || path.include?("\0") ||
      path.split("/").any? { |component| component == ".." }
    raise Failure, "#{identity} archive path is too deeply nested" if
      path.split("/").length >
        RUST_REGISTRY_CONTENT_LIMITS.fetch("max_archive_path_depth")
    true
  end

  def validate_relative_path(path, context)
    components = path.split("/")
    raise Failure, "#{context} path is unsafe" if
      path.empty? || path.start_with?("/") || path.include?("\0") ||
      components.any? { |component| component.empty? || component == "." ||
        component == ".." }
    raise Failure, "#{context} path is too deeply nested" if
      components.length >
        RUST_REGISTRY_CONTENT_LIMITS.fetch("max_archive_path_depth")
    true
  end

  def package_toml_string(bytes, key, context)
    value = package_toml_optional_string(bytes, key, context)
    raise Failure, "#{context} Cargo package #{key} is missing" if value.nil?
    value
  end

  def package_toml_optional_string(bytes, key, context)
    match = bytes.match(/(?:\A|\n)\[package\]\r?\n(.*?)(?=\n\[|\z)/m)
    raise Failure, "#{context} Cargo package section missing" unless match
    optional_toml_string(match[1], key, "#{context} Cargo package")
  end

  def required_toml_string(bytes, key, context)
    value = optional_toml_string(bytes, key, context)
    raise Failure, "#{context} #{key} is missing" if value.nil?
    value
  end

  def optional_toml_string(bytes, key, context)
    matches = bytes.scan(/^#{Regexp.escape(key)} = "([^"\r\n]*)"\r?$/)
    raise Failure, "#{context} #{key} is duplicated" if matches.length > 1
    matches.empty? ? nil : matches.first.first
  end

  def verify_file(path, bytes: nil, sha256:, context:)
    raise Failure, "#{context} missing: #{path}" unless File.file?(path)
    raise Failure, "#{context} is a symlink" if File.symlink?(path)

    contents = File.binread(path)
    raise Failure, "#{context} size differs" if bytes && contents.bytesize != bytes
    raise Failure, "#{context} hash differs" unless
      Digest::SHA256.hexdigest(contents) == sha256
    contents
  end

  def verify_large_file(path, bytes: nil, sha256:, context:)
    stat = File.lstat(path)
    raise Failure, "#{context} is not a regular file" unless stat.file?
    raise Failure, "#{context} is a symlink" if stat.symlink?
    raise Failure, "#{context} size differs" if bytes && stat.size != bytes
    raise Failure, "#{context} hash differs" unless
      Digest::SHA256.file(path).hexdigest == sha256
    true
  rescue Errno::ENOENT
    raise Failure, "#{context} missing: #{path}"
  end

  def with_verified_large_file(path, bytes:, sha256:, context:)
    flags = File::RDONLY | File::NOFOLLOW | File::NONBLOCK
    File.open(path, flags) do |source_io|
      source_io.binmode
      stat = source_io.stat
      raise Failure, "#{context} is not a regular file" unless
        stat.file? && stat.nlink == 1
      source_identity = open_file_identity(stat)
      verify_open_file_bytes(
        source_io,
        bytes: bytes,
        sha256: sha256,
        context: context
      )

      Dir.mktmpdir("p13-verified-archive-") do |directory|
        snapshot_path = File.join(directory, "archive")
        snapshot_flags = File::RDWR | File::CREAT | File::EXCL
        File.open(snapshot_path, snapshot_flags, 0o600) do |snapshot_io|
          snapshot_io.binmode
          source_io.rewind
          while (chunk = source_io.read(1024 * 1024))
            snapshot_io.write(chunk)
          end
          snapshot_io.flush
          File.unlink(snapshot_path)
          snapshot_io.rewind
          source_io.rewind

          handle = {
            "io" => snapshot_io,
            "identity" => open_file_identity(snapshot_io.stat),
            "path" => path,
            "source_io" => source_io,
            "source_identity" => source_identity,
            "bytes" => bytes,
            "sha256" => sha256
          }
          validate_open_large_file_identity(handle, context)
          verify_open_large_file_bytes(handle, context)
          verify_source_large_file_bytes(handle, context)
          result = yield handle
          validate_open_large_file_identity(handle, context)
          verify_open_large_file_bytes(handle, context)
          verify_source_large_file_bytes(handle, context)
          result
        end
      end
    end
  rescue Errno::ELOOP
    raise Failure, "#{context} is a symlink"
  rescue Errno::ENOENT
    raise Failure, "#{context} missing: #{path}"
  end

  def rust_archive_descriptor_path(handle)
    validate_open_large_file_identity(handle, "P13 Rust source archive")
    "/dev/fd/#{handle.fetch('io').fileno}"
  rescue KeyError => error
    raise Failure, "P13 Rust archive descriptor field missing: #{error.key}"
  end

  def validate_open_large_file_identity(handle, context)
    io = handle.fetch("io")
    expected = handle.fetch("identity")
    stat = io.stat
    raise Failure, "#{context} descriptor identity differs" unless
      stat.file? &&
      stat.nlink.zero? &&
      open_file_identity(stat) == expected

    source_io = handle.fetch("source_io")
    source_expected = handle.fetch("source_identity")
    source_stat = source_io.stat
    raise Failure, "#{context} source descriptor identity differs" unless
      source_stat.file? &&
      source_stat.nlink == 1 &&
      open_file_identity(source_stat) == source_expected

    path_stat = File.lstat(handle.fetch("path"))
    raise Failure, "#{context} path identity differs" unless
      path_stat.file? &&
      !path_stat.symlink? &&
      open_file_identity(path_stat) == source_expected
    true
  rescue Errno::ENOENT
    raise Failure, "#{context} path identity differs"
  rescue KeyError => error
    raise Failure, "#{context} descriptor field missing: #{error.key}"
  end

  def verify_open_large_file_bytes(handle, context)
    verify_open_file_bytes(
      handle.fetch("io"),
      bytes: handle.fetch("bytes"),
      sha256: handle.fetch("sha256"),
      context: "#{context} snapshot"
    )
  rescue KeyError => error
    raise Failure, "#{context} descriptor field missing: #{error.key}"
  end

  def verify_source_large_file_bytes(handle, context)
    verify_open_file_bytes(
      handle.fetch("source_io"),
      bytes: handle.fetch("bytes"),
      sha256: handle.fetch("sha256"),
      context: context
    )
  rescue KeyError => error
    raise Failure, "#{context} descriptor field missing: #{error.key}"
  end

  def verify_open_file_bytes(io, bytes:, sha256:, context:)
    raise Failure, "#{context} size differs" unless io.stat.size == bytes
    raise Failure, "#{context} hash differs" unless
      sha256_open_file(io) == sha256
    true
  end

  def sha256_open_file(io)
    digest = Digest::SHA256.new
    io.rewind
    while (chunk = io.read(1024 * 1024))
      digest.update(chunk)
    end
    digest.hexdigest
  ensure
    io.rewind unless io.closed?
  end

  def open_file_identity(stat)
    [
      stat.dev,
      stat.ino,
      stat.mode,
      stat.nlink,
      stat.size
    ]
  end

  def git_blob_sha1(bytes)
    Digest::SHA1.hexdigest("blob #{bytes.bytesize}\0#{bytes}")
  end

  def semantic_digest(value)
    Digest::SHA256.hexdigest(semantic_encoding(value))
  end

  def semantic_encoding(value, depth = 0)
    raise Failure, "semantic value nesting is excessive" if depth > 64

    case value
    when Hash
      raise Failure, "semantic mapping key is not a string" unless
        value.keys.all? { |key| key.is_a?(String) }
      encoded = +"M#{value.length}:".b
      value.keys.sort_by(&:b).each do |key|
        encoded << semantic_encoding(key, depth + 1)
        encoded << semantic_encoding(value.fetch(key), depth + 1)
      end
      encoded << "E"
    when Array
      encoded = +"A#{value.length}:".b
      value.each { |item| encoded << semantic_encoding(item, depth + 1) }
      encoded << "E"
    when String
      bytes = value.b
      +"S#{bytes.bytesize}:".b << bytes
    when Integer
      "I#{value};".b
    when TrueClass
      "T".b
    when FalseClass
      "F".b
    when NilClass
      "N".b
    else
      raise Failure, "unsupported semantic value type: #{value.class}"
    end
  end

  def read_yaml(path)
    parse_yaml(File.binread(path), path)
  rescue Errno::ENOENT
    raise Failure, "missing YAML: #{path}"
  end

  def parse_yaml(bytes, context)
    stream = Psych.parse_stream(bytes, context)
    raise Failure, "YAML document count differs: #{context}" unless
      stream.children.length == 1
    reject_yaml_aliases_and_duplicates(stream, context)
    value = Psych.safe_load(
      bytes,
      permitted_classes: [],
      permitted_symbols: [],
      aliases: false,
      filename: context
    )
    raise Failure, "YAML root is not a mapping: #{context}" unless value.is_a?(Hash)
    value
  rescue Psych::Exception, SystemStackError => error
    raise Failure, "invalid YAML in #{context}: #{error.class}"
  end

  def reject_yaml_aliases_and_duplicates(node, context, depth = 0)
    raise Failure, "YAML nesting is excessive: #{context}" if depth > 64
    raise Failure, "YAML aliases are prohibited: #{context}" if
      node.is_a?(Psych::Nodes::Alias)
    if node.is_a?(Psych::Nodes::Mapping)
      keys = {}
      node.children.each_slice(2) do |key, value|
        raise Failure, "non-scalar YAML key: #{context}" unless
          key.is_a?(Psych::Nodes::Scalar)
        raise Failure, "duplicate YAML key: #{context}" if keys.key?(key.value)
        keys[key.value] = true
        reject_yaml_aliases_and_duplicates(value, context, depth + 1)
      end
    elsif node.respond_to?(:children)
      Array(node.children).each do |child|
        reject_yaml_aliases_and_duplicates(child, context, depth + 1)
      end
    end
    true
  end

  def parse_json(bytes, context)
    value = JSON.parse(
      bytes,
      object_class: DuplicateRejectingHash,
      max_nesting: 64
    )
    raise Failure, "JSON root is not a mapping: #{context}" unless value.is_a?(Hash)
    value
  rescue JSON::ParserError, JSON::NestingError, DuplicateKey => error
    raise Failure, "invalid JSON in #{context}: #{error.class}"
  end

  def command(
    *arguments,
    env: {},
    chdir: nil,
    unsetenv_others: false,
    label: nil
  )
    if arguments.first ==
        "/Library/Developer/CommandLineTools/usr/bin/git"
      env = GIT_ENVIRONMENT.merge(env)
    end
    options = { unsetenv_others: unsetenv_others }
    options[:chdir] = chdir if chdir
    stdout, stderr, status = Open3.capture3(env, *arguments, options)
    return stdout.b if status.success?

    detail = (stdout + stderr).lines.last(20).join.strip
    raise Failure, "#{label || arguments.first} failed: #{detail}"
  end

  def require_include(bytes, needle, context)
    raise Failure, "#{context} predicate missing" unless bytes.include?(needle)
    true
  end

  def require_exact_count(bytes, needle, count, context)
    raise Failure, "#{context} count differs" unless bytes.scan(needle).length == count
    true
  end

  def require_exclude(bytes, needle, context)
    raise Failure, "#{context} predicate unexpectedly present" if bytes.include?(needle)
    true
  end
end

P13NoiseEvidence.run(ARGV) if $PROGRAM_NAME == __FILE__
