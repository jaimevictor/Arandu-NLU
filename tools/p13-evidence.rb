# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "psych"

module P13Evidence
  class Failure < StandardError; end
  class DuplicateKey < StandardError; end

  class DuplicateRejectingHash < Hash
    def []=(key, value)
      raise DuplicateKey, key if key?(key)

      super
    end
  end

  ROOT = File.expand_path("..", __dir__)
  EVIDENCE = "docs/evidence/P13-EXACT-SOURCES.yaml"
  MATERIALS = "docs/clean-room/MATERIALS.yaml"
  EVIDENCE_SEMANTIC_SHA256 =
    "cbbe690cdf2200fc82a38a0e68139c4eef462811dcbfcc0fe7bb1fd7c051ac1e"
  MATERIAL_RECORD_SEMANTIC_SHA256 = {
    "cpython-3.14.6-p13-transport" =>
      "dd6de7e79b5643c66fb20bdb6227730b9ea4ab1ebf1b1e2a2571568930055bba",
    "openssl-3.6.3-p13-transport" =>
      "e557058196a692bb74b090552f37e05d7c0fd4a498fbb7bc09bb4ee08f6b8aa2",
    "home-assistant-core-2026.8.3" =>
      "f364a66f310d1586bbeeeea5e093a3e6a2c3195a1f535fad3d15c3427a55bae1",
    "wyoming-protocol" =>
      "8254175a967d9f316bf1b3c835214c3654573cb0e300f656f47cc87fe6422587"
  }.freeze

  TREE_ALGORITHM =
    "sha256(concat(sorted(F NUL path NUL mode NUL bytes NUL content NUL)))"

  SOURCE_PATHS = {
    "cpython_archive" => "/private/tmp/Python-3.14.6.tar.xz",
    "cpython_tree" => "/private/tmp/p13-cpython-clean",
    "openssl_archive" => "/private/tmp/openssl-3.6.3.tar.gz",
    "openssl_tree" => "/private/tmp/openssl-3.6.3",
    "ha_archive" => "/private/tmp/nlu-p13-ha-contract-759e465.tar",
    "ha_tree" => "/private/tmp/nlu-p13-ha-contract-759e465",
    "ha_git" => "/private/tmp/nlu-p10-ha-core-2026.8.3",
    "wyoming_archive" => "/private/tmp/nlu-p13-wyoming-bf65f4e.tar",
    "wyoming_tree" => "/private/tmp/nlu-p13-wyoming-bf65f4e"
  }.freeze

  ARCHIVES = {
    "cpython" => {
      "path_key" => "cpython_archive",
      "bytes" => 23_921_184,
      "sha256" =>
        "143b1dddefaec3bd2e21e3b839b34a2b7fb9842272883c576420d605e9f30c63"
    },
    "openssl" => {
      "path_key" => "openssl_archive",
      "bytes" => 54_953_005,
      "sha256" =>
        "243a86649cf6f23eeb6a2ff2456e09e5d77dd9018a54d3d96b0c6bdd6ba6c7f1"
    },
    "home_assistant" => {
      "path_key" => "ha_archive",
      "bytes" => 501_760,
      "sha256" =>
        "e91f94715eee2ed7771b59bcb4aa68fda3722720d817211a0db541c5fe34c799"
    },
    "wyoming" => {
      "path_key" => "wyoming_archive",
      "bytes" => 245_760,
      "sha256" =>
        "96d5967140a99bd859fdc604fcd7346304560eb219f0a589b8ddefabf903ffa9"
    }
  }.freeze

  TREES = {
    "cpython" => {
      "path_key" => "cpython_tree",
      "files" => 5_100,
      "sha256" =>
        "b7e662cf62918c5746d04f6e26103a3ba185502b468cfc8c5218f970c96949e5"
    },
    "openssl" => {
      "path_key" => "openssl_tree",
      "files" => 5_856,
      "sha256" =>
        "ea06723083780b098e038e955cfdb1113eb38d8da833c3a84624937ede12b6ea"
    },
    "home_assistant" => {
      "path_key" => "ha_tree",
      "files" => 14,
      "sha256" =>
        "5b0e681f35d2cc8a7d6d07f7f529960c5f657e10e666f9e9b1753e1815560439"
    },
    "wyoming" => {
      "path_key" => "wyoming_tree",
      "files" => 60,
      "sha256" =>
        "5accaa10af11a646d0b9714d76b770cac95fce60f7cbb5ba2829a3794eae26de",
      "exclude" => [".git"]
    }
  }.freeze

  ARCHIVE_TREE_BINDINGS = {
    "cpython" => {
      "archive_path_key" => "cpython_archive",
      "tree_path_key" => "cpython_tree",
      "archive_prefix" => "Python-3.14.6/",
      "archive_modes" => {"644" => 4_993, "755" => 107},
      "tree_modes" => {"644" => 4_993, "755" => 107}
    },
    "openssl" => {
      "archive_path_key" => "openssl_archive",
      "tree_path_key" => "openssl_tree",
      "archive_prefix" => "openssl-3.6.3/",
      "archive_modes" => {"664" => 5_697, "775" => 159},
      "tree_modes" => {"644" => 5_697, "755" => 159}
    },
    "home_assistant" => {
      "archive_path_key" => "ha_archive",
      "tree_path_key" => "ha_tree",
      "archive_prefix" => "",
      "archive_modes" => {"664" => 14},
      "tree_modes" => {"644" => 14}
    },
    "wyoming" => {
      "archive_path_key" => "wyoming_archive",
      "tree_path_key" => "wyoming_tree",
      "archive_prefix" => "",
      "archive_modes" => {"664" => 55, "775" => 5},
      "tree_modes" => {"644" => 55, "755" => 5},
      "exclude" => [".git"]
    }
  }.freeze

  CPYTHON_FILES = {
    "LICENSE" =>
      "b0e25a78cffb43f4d92de8b61ccfa1f1f98ecbc22330b54b5251e7b6ba010231",
    "Include/patchlevel.h" =>
      "1c61b149e1ce72a7f6328c58057970d37fcafb02bec805be071dc0ed4cf39a95",
    "Modules/_ssl.c" =>
      "026bcc1316d67aea68d9e052633cb3b1b0fef9fe766eed66a41ad67bfbba24d9",
    "Doc/library/ssl.rst" =>
      "4bd9ddc27cbe2818d79dd9785dd9a24d7d31accec6187e59de4fd868eab2bb74",
    "Modules/expat/siphash.h" =>
      "f537add526ecda8389503b7ef45fb52b6217e4dc171dcc3a8dc6903ff6134726",
    "Modules/blake2module.c" =>
      "e471acd6c8317fe31ef56d129f6e3426ebd6a4c9cd6d64a09d39bc558a491f10",
    "Doc/library/hashlib.rst" =>
      "f30f991cc0f66142bb346f8af365a0b7f4c460cc8993bae184efaca0bf6b6764"
  }.freeze
  CPYTHON_COMMIT = "c63aec69bd59c55314c06c23f4c22c03de76fe45"

  OPENSSL_FILES = {
    "LICENSE.txt" =>
      "7d5450cb2d142651b8afa315b5f238efc805dad827d91ba367d8516bc9d49e7a",
    "VERSION.dat" =>
      "13996b257fa122047907c75bb6605cf9b18859099e555d8091dfc95df6344470",
    "ssl/statem/extensions_clnt.c" =>
      "06ee8001691c8f2b0e4dec2e18a9ae91cf581cc4f99351695910543535637690",
    "ssl/statem/extensions_srvr.c" =>
      "1975c4fdaea88890b0c7664f58589ac539e60f25909b974520ec656067f35326",
    "ssl/ssl_lib.c" =>
      "bbd87e2e8ee57c901ff7ca8c0aa5445c9988d2f9a90e4576ed34a0616ea1ac5e",
    "ssl/ssl_sess.c" =>
      "e0b76efb617edf3bd883a29d997cb4d5f78687e4c3094a5d8e5c849d3265a85d",
    "ssl/ssl_local.h" =>
      "7661e11795892ce9492482b6bae17848f173724b2191f2a870f873f0995024dd",
    "ssl/tls13_enc.c" =>
      "6e44896fcb9ffbc3f11d582e6a6419b222bed95fdc1487fa39a35babdd3c4048",
    "crypto/mem_sec.c" =>
      "d0b7a02f0bb599f0ac606129f22f1ebfea468615f4e8e260a76fddc71f65d7b6",
    "crypto/siphash/siphash.c" =>
      "67b99076c867bc014fcdad96f50c9195dec1971d0b41a59606fcee38844a2c3a",
    "crypto/aes/aes_core.c" =>
      "a70bf52702b68dbd07c7ef376e88c5b926b1a99ccfb43bef1225a59e3ab98287",
    "doc/man3/SSL_CTX_set_psk_client_callback.pod" =>
      "ae5f7b9ab967c320cabcfa9a98b5b4556aa72ea8b6526e353821febe7b75fee4",
    "doc/man3/SSL_CTX_use_psk_identity_hint.pod" =>
      "bb5a0ae5f4ed2a64df65545e3a94bdcdcf613c7f055c4834a73a32f6b99d5fee"
  }.freeze
  OPENSSL_COMMIT = "aae016bfd52fcad2bc9657c2c782cfdf73b1ed5f"

  HA_COMMIT = "759e4658f40b3ccb671d418b8a0ed95224bf4561"
  HA_TREE = "f4a72534bb33abf8b5d183910a0c134b968af2f8"
  HA_FILES = {
    "LICENSE.md" =>
      "c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4",
    "homeassistant/components/wyoming/conversation.py" =>
      "77cf453fc91691389834f32b51b9fbad4a9c60dce51cd869f696e843a0baaf10",
    "homeassistant/components/wyoming/manifest.json" =>
      "ca7ce74b695d45c98ebf8adc0020597a1861eff624de80b728955757bd30670e",
    "homeassistant/components/conversation/models.py" =>
      "ab01f362b6e218ab64a1b170d505cdc2c6e9832254d5fc8236b85df639223e71",
    "homeassistant/helpers/intent.py" =>
      "8a62d1ab08d66a60a6c397bbb4d0b0ef12770c924ef8fd4ecffd690143703f9f",
    "homeassistant/core.py" =>
      "2d92d136433488735db82b7fea044908c9689e7f3b87f5f43aac6fce319473bc",
    "homeassistant/config_entries.py" =>
      "8748b55770005a478467b7c1250e6525ba8d44725a38f0b9c3a37804d78de859",
    "homeassistant/auth/__init__.py" =>
      "a1299485606914b48ad58d2f5cae41ce1a2896f7d8303c70ab01ead05e364987",
    "homeassistant/auth/models.py" =>
      "976466cf9db1c7de4899444e21840edee9e1d03120a246e4200ac77984cb37bc",
    "homeassistant/auth/permissions/const.py" =>
      "3e442c30f9cbb03ad968af90168205e06178593324bc260dbf01174a1e6be773",
    "homeassistant/auth/permissions/models.py" =>
      "386731d5e857fd67f567eacfcc9d9a5a13c75b622d5341457e82de0c5b76fe35",
    "homeassistant/helpers/service.py" =>
      "ead719bd2e68445013f5ffa4d0dee83175df2683ec806fe983397e641f793438",
    "homeassistant/loader.py" =>
      "ba9c2cf5e1312c2428587e87ad6ee50e71bb5eee70bb65f42b7d2de4d190e12c",
    "homeassistant/backup_restore.py" =>
      "f53cf5626321e99b39e1b5ceb6bd408d0a30e1e2735ef3965f3625701d98b496"
  }.freeze

  WYOMING_COMMIT = "bf65f4e645770909a87c0e59010e0cc71631e4a5"
  WYOMING_TREE = "21d7ab51abc067576675ccbe8d48d0c8d17ae7c8"
  WYOMING_FILES = {
    "LICENSE.md" =>
      "13746d509d74e55ea2265fbef204bb7cdbf84a8315b0207e988326cb54387028",
    "wyoming/event.py" =>
      "bb7955ac580116f44b0526bc17c2d1a4a55f5d67283798879cf6b65bc6711c7b",
    "wyoming/info.py" =>
      "1c2d8aa9d4b5ad9a61c6979cb8de7c32c04c81019a68331291bf711c2ffd538b",
    "wyoming/intent.py" =>
      "f4f1f571c4830380b14aa89bd84dc949d2bbceedee007d8a26abd77306f51cdb",
    "wyoming/handle.py" =>
      "a9464d80806cb54733d3eec5aa80ccfc9d895e79b9cd2d69c7bced4146754248"
  }.freeze

  HOMEBREW_RUNTIME_FILES = {
    "/opt/homebrew/bin/python3.14" =>
      "4f00ea2ad53d62437a6a3946b73c73614a97e8accdc5b96dc095ea1a0d9c6a56",
    "/opt/homebrew/Cellar/python@3.14/3.14.6/Frameworks/Python.framework/" \
      "Versions/3.14/Python" =>
      "15436055aa2c02ed0218ac0e02b3a27a92102f88cd59ab5094896b9306317336",
    "/opt/homebrew/Cellar/python@3.14/3.14.6/Frameworks/Python.framework/" \
      "Versions/3.14/lib/python3.14/lib-dynload/_ssl.cpython-314-darwin.so" =>
      "791e62e4a25231581b1ac0f1ac4cb66b64da1ec3ed13959b177c2422856fe8de",
    "/opt/homebrew/bin/openssl" =>
      "103fc7706cf6646f226d96f29242d81890363499afc730e7ef1fadd64b3a123c",
    "/opt/homebrew/Cellar/openssl@3/3.6.3/lib/libssl.3.dylib" =>
      "ffd8ac6981000def0928367924b6cb1e7a98712efbc06e2a2f3f750138bd89ca",
    "/opt/homebrew/Cellar/openssl@3/3.6.3/lib/libcrypto.3.dylib" =>
      "a12805a18cd5e4f733fa8727b91afa08b587f9da5a760517cd79cb508a3a3f71",
    "/opt/homebrew/Cellar/python@3.14/3.14.6/LICENSE" =>
      "b0e25a78cffb43f4d92de8b61ccfa1f1f98ecbc22330b54b5251e7b6ba010231",
    "/opt/homebrew/Cellar/openssl@3/3.6.3/LICENSE.txt" =>
      "7d5450cb2d142651b8afa315b5f238efc805dad827d91ba367d8516bc9d49e7a",
    "/opt/homebrew/Cellar/python@3.14/3.14.6/INSTALL_RECEIPT.json" =>
      "bf10fe865fe8d4ce48d8d972aebcfbaaf12717206b1d192f4ea0fabe84ec6871",
    "/opt/homebrew/Cellar/openssl@3/3.6.3/INSTALL_RECEIPT.json" =>
      "b3c10708295bd841b8a4e8e6061917cc7c59fbee372db3342caeda059ed966d1"
  }.freeze

  SOURCE_BUILD_FILES = {
    "/private/tmp/p13-python-install/bin/python3.14" =>
      "f7147fb3d4be5bfe55816013a05f9b206a9ad440b7084d56957a40372aa0d7a1",
    "/private/tmp/p13-python-install/lib/python3.14/lib-dynload/" \
      "_ssl.cpython-314-darwin.so" =>
      "8e266297d8811b2bfb6cafe7cfb31deed6aac3af4d3ece71efed5e09ffc6fbef",
    "/private/tmp/p13-openssl-install/bin/openssl" =>
      "0646d01d529b38bbb96290d615a51188446a3ca9c147825e2ef6213af67967a6",
    "/private/tmp/p13-openssl-install/lib/libssl.3.dylib" =>
      "489ea0e86d8eb1be81919ec12cd15ca8de8d10942a0a91d7eb520bbbbce7aa05",
    "/private/tmp/p13-openssl-install/lib/libcrypto.3.dylib" =>
      "567bddef1ceb4deb1ba222bc5e105cbd20820dd71030ce108e04c94a5b4b0f22",
    "/private/tmp/p13-python-build/config.log" =>
      "cc467c2de94cd46be71c636264351075235c904ec326217cbc657b1bd07373d0",
    "/private/tmp/p13-openssl-build/configdata.pm" =>
      "27ecbe649c6c8e5299c311d86550bb90e712684f5094a89320f0cf5b2298ac73",
    "/private/tmp/p13-python-build/Modules/pyexpat.o" =>
      "ff7e20c3afa9819915a7c7a0e68a7b0b1cd52a947fb8ac34b68ff75882fcf058",
    "/private/tmp/p13-python-build/Modules/blake2module.o" =>
      "a10f9ccd8b79bc33462c2c6af348e3361edf5ff645641fae10f7d8f5f481a9a6",
    "/private/tmp/p13-python-install/lib/python3.14/lib-dynload/" \
      "pyexpat.cpython-314-darwin.so" =>
      "0c0348f1b139bef5a3e7161efb02e0a6f093449b0b7e43e27300164e7bd4bc37",
    "/private/tmp/p13-python-install/lib/python3.14/lib-dynload/" \
      "_blake2.cpython-314-darwin.so" =>
      "a5bbcd8b258fc821df05707da9cccb582555a2fbe6be30b358ccf1aad7e8dc54",
    "/private/tmp/p13-openssl-build/crypto/siphash/" \
      "libcrypto-lib-siphash.o" =>
      "faec93441e9e87f1952cc860a07b76600b7a2e90b8c54834fbb34d0e9bb43318",
    "/private/tmp/p13-openssl-build/crypto/siphash/" \
      "libcrypto-shlib-siphash.o" =>
      "faec93441e9e87f1952cc860a07b76600b7a2e90b8c54834fbb34d0e9bb43318",
    "/private/tmp/p13-openssl-build/crypto/aes/" \
      "libcrypto-lib-aes_core.o" =>
      "a4cdb48e020041ad0f02e0c43b91bd6b38d69fabb74bbe9c1ec287a0a4ca04b6",
    "/private/tmp/p13-openssl-build/crypto/aes/" \
      "libcrypto-shlib-aes_core.o" =>
      "a4cdb48e020041ad0f02e0c43b91bd6b38d69fabb74bbe9c1ec287a0a4ca04b6"
  }.freeze

  LICENSE_FILES = {
    "cpython" => {
      "path" => "LICENSE",
      "bytes" => 13_804,
      "sha256" => CPYTHON_FILES.fetch("LICENSE")
    },
    "openssl" => {
      "path" => "LICENSE.txt",
      "bytes" => 10_175,
      "sha256" => OPENSSL_FILES.fetch("LICENSE.txt")
    },
    "home_assistant" => {
      "path" => "LICENSE.md",
      "bytes" => 11_357,
      "sha256" => HA_FILES.fetch("LICENSE.md")
    },
    "wyoming" => {
      "path" => "LICENSE.md",
      "bytes" => 1_071,
      "sha256" => WYOMING_FILES.fetch("LICENSE.md")
    }
  }.freeze

  CPYTHON_REJECTION_WITNESSES = [
    {
      "path" => "Modules/expat/siphash.h",
      "license" => "CC0-1.0",
      "rightsholders" => [
        "William_Ahern",
        "Jean-Philippe_Aumasson",
        "Daniel_J_Bernstein"
      ],
      "sha256" => CPYTHON_FILES.fetch("Modules/expat/siphash.h"),
      "controlled_build_object" =>
        "/private/tmp/p13-python-build/Modules/pyexpat.o",
      "controlled_build_object_sha256" => SOURCE_BUILD_FILES.fetch(
        "/private/tmp/p13-python-build/Modules/pyexpat.o"
      ),
      "installed_artifact" =>
        "/private/tmp/p13-python-install/lib/python3.14/lib-dynload/" \
        "pyexpat.cpython-314-darwin.so",
      "installed_artifact_sha256" => SOURCE_BUILD_FILES.fetch(
        "/private/tmp/p13-python-install/lib/python3.14/lib-dynload/" \
        "pyexpat.cpython-314-darwin.so"
      )
    },
    {
      "path" => "Modules/blake2module.c",
      "license" => "CC0-1.0",
      "rightsholders" => [
        "Dmitry_Chestnykh",
        "Christian_Heimes",
        "Jonathan_Protzenko"
      ],
      "sha256" => CPYTHON_FILES.fetch("Modules/blake2module.c"),
      "license_notice_path" => "Doc/library/hashlib.rst",
      "license_notice_sha256" => CPYTHON_FILES.fetch("Doc/library/hashlib.rst"),
      "controlled_build_object" =>
        "/private/tmp/p13-python-build/Modules/blake2module.o",
      "controlled_build_object_sha256" => SOURCE_BUILD_FILES.fetch(
        "/private/tmp/p13-python-build/Modules/blake2module.o"
      ),
      "installed_artifact" =>
        "/private/tmp/p13-python-install/lib/python3.14/lib-dynload/" \
        "_blake2.cpython-314-darwin.so",
      "installed_artifact_sha256" => SOURCE_BUILD_FILES.fetch(
        "/private/tmp/p13-python-install/lib/python3.14/lib-dynload/" \
        "_blake2.cpython-314-darwin.so"
      )
    }
  ].freeze

  OPENSSL_REJECTION_WITNESSES = [
    {
      "path" => "crypto/siphash/siphash.c",
      "license" => "CC0-1.0",
      "rightsholders" => [
        "Jean-Philippe_Aumasson",
        "Daniel_J_Bernstein"
      ],
      "sha256" => OPENSSL_FILES.fetch("crypto/siphash/siphash.c"),
      "controlled_build_objects" => [
        {
          "path" =>
            "/private/tmp/p13-openssl-build/crypto/siphash/" \
            "libcrypto-lib-siphash.o",
          "sha256" => SOURCE_BUILD_FILES.fetch(
            "/private/tmp/p13-openssl-build/crypto/siphash/" \
            "libcrypto-lib-siphash.o"
          )
        },
        {
          "path" =>
            "/private/tmp/p13-openssl-build/crypto/siphash/" \
            "libcrypto-shlib-siphash.o",
          "sha256" => SOURCE_BUILD_FILES.fetch(
            "/private/tmp/p13-openssl-build/crypto/siphash/" \
            "libcrypto-shlib-siphash.o"
          )
        }
      ],
      "installed_artifact" =>
        "/private/tmp/p13-openssl-install/lib/libcrypto.3.dylib",
      "installed_artifact_sha256" => SOURCE_BUILD_FILES.fetch(
        "/private/tmp/p13-openssl-install/lib/libcrypto.3.dylib"
      )
    },
    {
      "path" => "crypto/aes/aes_core.c",
      "license" => "PUBLIC_DOMAIN_DEDICATION_NOT_OSI_LICENSE",
      "rightsholders" => [
        "Vincent_Rijmen",
        "Antoon_Bosselaers",
        "Paulo_Barreto"
      ],
      "sha256" => OPENSSL_FILES.fetch("crypto/aes/aes_core.c"),
      "controlled_build_objects" => [
        {
          "path" =>
            "/private/tmp/p13-openssl-build/crypto/aes/" \
            "libcrypto-lib-aes_core.o",
          "sha256" => SOURCE_BUILD_FILES.fetch(
            "/private/tmp/p13-openssl-build/crypto/aes/" \
            "libcrypto-lib-aes_core.o"
          )
        },
        {
          "path" =>
            "/private/tmp/p13-openssl-build/crypto/aes/" \
            "libcrypto-shlib-aes_core.o",
          "sha256" => SOURCE_BUILD_FILES.fetch(
            "/private/tmp/p13-openssl-build/crypto/aes/" \
            "libcrypto-shlib-aes_core.o"
          )
        }
      ],
      "installed_artifact" =>
        "/private/tmp/p13-openssl-install/lib/libcrypto.3.dylib",
      "installed_artifact_sha256" => SOURCE_BUILD_FILES.fetch(
        "/private/tmp/p13-openssl-install/lib/libcrypto.3.dylib"
      )
    }
  ].freeze

  CPYTHON_API_FACTS = {
    "source_path" => "Modules/_ssl.c",
    "source_sha256" => CPYTHON_FILES.fetch("Modules/_ssl.c"),
    "client_psk_callback" => "present",
    "server_psk_callback" => "present",
    "callback_secret_copy_to_openssl_buffer" => "present",
    "callback_copy_individually_locked" => "not_proven",
    "callback_copy_immediate_zeroization" => "not_proven"
  }.freeze

  OPENSSL_API_FACTS = {
    "tls13_external_psk_legacy_callbacks" => "present",
    "default_psk_exchange_mode" => "psk_dhe_ke",
    "legacy_callback_digest" => "SHA256",
    "legacy_callback_early_data" => "unavailable",
    "stack_psk_buffers" => "present",
    "session_master_key_copy" => "present",
    "temporary_stack_cleanse" => "present",
    "session_master_key_cleanup" => "present",
    "derived_secret_storage" => "present",
    "callback_and_session_copies_individually_locked" => "not_proven",
    "all_secret_copies_immediately_zeroized" => "not_proven"
  }.freeze

  REJECTION_REASONS = %w[
    non_osi_and_public_domain_dedication_witnesses_in_both_source_archives
    complete_bundle_license_and_rightsholder_inventory_not_established
    controlled_build_compiled_multiple_prohibited_witnesses
    exact_source_to_distributable_runtime_mapping_not_established
  ].freeze

  PROBE_REQUIREMENTS = %w[
    TLS1.3_only
    mutual_external_PSK
    PSK_DHE
    fixed_identity
    fixed_ALPN
    no_cert_fallback
    no_TLS1.2
    no_tickets
    no_resumption
    no_early_data
    bounded_handshake
    absent_wrong_identity_key_and_ALPN_rejection
  ].freeze

  module_function

  def run(arguments)
    arguments = arguments.dup
    skip_runtime = arguments.delete("--skip-runtime")
    raise Failure, "usage: tools/p13-evidence [--skip-runtime]" unless
      arguments.empty?

    validate(paths: source_paths, runtime: !skip_runtime)
    puts "P13_EXACT_SOURCE_COMPATIBILITY_PASS"
    puts(skip_runtime ? "P13_RUNTIME_SKIPPED" : "P13_LOCAL_RUNTIME_PASS")
    puts "P13_TRANSPORT_PORTFOLIO_REJECTED"
    true
  rescue Failure => error
    warn "P13_EVIDENCE_FAIL: #{error.message}"
    exit 1
  end

  def validate(paths:, runtime:)
    validate_evidence(read_yaml(File.join(ROOT, EVIDENCE)))
    validate_materials(read_yaml(File.join(ROOT, MATERIALS)))
    archive_bytes = validate_archives(paths)
    validate_trees(paths, archive_bytes)
    validate_selected_files(paths)
    validate_git_identities(paths)
    validate_source_contracts(paths)
    validate_compatibility_contracts(paths)
    if runtime
      validate_homebrew_runtime
      validate_source_build
    end
    true
  end

  def source_paths
    SOURCE_PATHS.to_h do |key, default|
      environment_key = "P13_#{key.upcase}"
      [key, ENV.fetch(environment_key, default)]
    end
  end

  def validate_archives(paths)
    ARCHIVES.to_h do |name, expected|
      bytes = read_verified_file(
        paths.fetch(expected.fetch("path_key")),
        bytes: expected.fetch("bytes"),
        sha256: expected.fetch("sha256"),
        context: "#{name} archive"
      )
      [name, bytes]
    end
  end

  def validate_trees(paths, archive_bytes)
    TREES.each do |name, expected|
      root = paths.fetch(expected.fetch("path_key"))
      actual = tree_digest(root, exclude: expected.fetch("exclude", []))
      raise Failure, "#{name} tree file count differs" unless
        actual.fetch("files") == expected.fetch("files")
      raise Failure, "#{name} deterministic tree hash differs" unless
        actual.fetch("sha256") == expected.fetch("sha256")
    end
    ARCHIVE_TREE_BINDINGS.each do |name, binding|
      expected_paths = archive_file_paths(
        archive_bytes.fetch(name),
        binding.fetch("archive_prefix"),
        "#{name} archive"
      )
      validate_tree_path_set(
        paths.fetch(binding.fetch("tree_path_key")),
        expected_paths,
        context: name,
        exclude: binding.fetch("exclude", [])
      )
      validate_mode_transition(
        archive_mode_inventory(
          archive_bytes.fetch(name),
          "#{name} archive"
        ),
        tree_mode_inventory(
          paths.fetch(binding.fetch("tree_path_key")),
          exclude: binding.fetch("exclude", [])
        ),
        binding.fetch("archive_modes"),
        binding.fetch("tree_modes"),
        context: name
      )
    end
    true
  end

  def archive_file_paths(archive_bytes, prefix, context)
    output = command(
      "/usr/bin/tar", "-tf", "-",
      stdin_data: archive_bytes
    )
    paths = output.lines.each_with_object([]) do |line, collected|
      entry = line.delete_suffix("\n").delete_suffix("\r")
      raise Failure, "#{context} contains an empty path" if entry.empty?
      next if entry.end_with?("/")
      raise Failure, "#{context} path lacks the exact root" unless
        entry.start_with?(prefix)

      relative = entry.delete_prefix(prefix)
      raise Failure, "#{context} contains an unsafe path" if
        relative.empty? ||
        relative.start_with?("/") ||
        relative.split("/").include?("..") ||
        relative.include?("\0")
      collected << relative
    end
    raise Failure, "#{context} contains duplicate file paths" unless
      paths.uniq.length == paths.length
    paths.sort_by(&:b)
  end

  def validate_tree_path_set(root, expected_paths, context:, exclude: [])
    raise Failure, "tree missing: #{root}" unless File.directory?(root)

    root = File.expand_path(root)
    excluded = exclude.map { |entry| File.join(root, entry) }
    entries = Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH)
      .reject { |path| [".", ".."].include?(File.basename(path)) }
      .reject do |path|
        excluded.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }
      end
    symlink = entries.find { |path| File.symlink?(path) }
    raise Failure, "#{context} tree contains unsupported symlink" if symlink

    actual_paths = entries.select { |path| File.file?(path) }
      .map { |path| relative_path(root, path) }
      .sort_by(&:b)
    return true if actual_paths == expected_paths

    missing = expected_paths - actual_paths
    extra = actual_paths - expected_paths
    detail = if !extra.empty?
               "unexpected path #{extra.first}"
             else
               "missing path #{missing.first}"
             end
    raise Failure, "#{context} archive/tree path set differs: #{detail}"
  end

  def archive_mode_inventory(archive_bytes, context)
    permissions = {
      "-rw-r--r--" => "644",
      "-rwxr-xr-x" => "755",
      "-rw-rw-r--" => "664",
      "-rwxrwxr-x" => "775"
    }
    command(
      "/usr/bin/tar", "-tvf", "-",
      stdin_data: archive_bytes
    ).lines.each_with_object(Hash.new(0)) do |line, modes|
      token = line.byteslice(0, 10)
      next if token&.start_with?("d")

      mode = permissions[token]
      raise Failure, "#{context} contains an unsupported entry mode" unless mode

      modes[mode] += 1
    end.sort.to_h
  end

  def tree_mode_inventory(root, exclude: [])
    raise Failure, "tree missing: #{root}" unless File.directory?(root)

    root = File.expand_path(root)
    excluded = exclude.map { |entry| File.join(root, entry) }
    entries = Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH)
      .reject { |path| [".", ".."].include?(File.basename(path)) }
      .reject do |path|
        excluded.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }
      end
    unsupported = entries.find do |path|
      !File.directory?(path) && !File.file?(path)
    end
    raise Failure, "tree contains an unsupported entry: #{unsupported}" if unsupported

    entries.select { |path| File.file?(path) }
      .each_with_object(Hash.new(0)) do |path, modes|
        modes[(File.stat(path).mode & 0o7777).to_s(8)] += 1
      end.sort.to_h
  end

  def validate_mode_transition(
    archive_modes,
    tree_modes,
    expected_archive_modes,
    expected_tree_modes,
    context:
  )
    raise Failure, "#{context} archive mode inventory differs" unless
      archive_modes == expected_archive_modes
    raise Failure, "#{context} tree mode inventory differs" unless
      tree_modes == expected_tree_modes

    true
  end

  def tree_digest(root, exclude: [])
    raise Failure, "tree missing: #{root}" unless File.directory?(root)

    root = File.expand_path(root)
    excluded = exclude.map { |entry| File.join(root, entry) }
    entries = Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH)
      .reject { |path| [".", ".."].include?(File.basename(path)) }
      .reject do |path|
        excluded.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }
      end

    symlink = entries.find { |path| File.symlink?(path) }
    raise Failure, "tree contains unsupported symlink: #{symlink}" if symlink

    files = entries.select { |path| File.file?(path) }
      .sort_by { |path| relative_path(root, path).b }
    digest = Digest::SHA256.new
    files.each do |path|
      bytes = File.binread(path)
      relative = relative_path(root, path)
      mode = (File.stat(path).mode & 0o7777).to_s(8)
      digest << "F\0" << relative.b << "\0" << mode << "\0"
      digest << bytes.bytesize.to_s << "\0" << bytes << "\0"
    end
    {"files" => files.length, "sha256" => digest.hexdigest}
  end

  def validate_selected_files(paths)
    verify_tree_files(paths.fetch("cpython_tree"), CPYTHON_FILES, "CPython")
    verify_tree_files(paths.fetch("openssl_tree"), OPENSSL_FILES, "OpenSSL")
    verify_tree_files(paths.fetch("ha_tree"), HA_FILES, "Home Assistant")
    verify_tree_files(paths.fetch("wyoming_tree"), WYOMING_FILES, "Wyoming")
    true
  end

  def verify_tree_files(root, records, context)
    records.each do |relative, sha256|
      verify_file(
        File.join(root, relative),
        sha256: sha256,
        context: "#{context} #{relative}"
      )
    end
  end

  def validate_git_identities(paths)
    ha_git = paths.fetch("ha_git")
    ha_values = command(
      "git", "-C", ha_git, "rev-parse",
      "HEAD^{commit}", "HEAD^{tree}",
      "refs/tags/2026.8.3^{commit}", "refs/tags/2026.8.3^{tree}"
    ).lines.map(&:strip)
    raise Failure, "Home Assistant commit, tree, or tag differs" unless
      ha_values == [HA_COMMIT, HA_TREE, HA_COMMIT, HA_TREE]
    validate_ha_git_blobs(ha_git, paths.fetch("ha_tree"))

    wyoming = paths.fetch("wyoming_tree")
    values = command(
      "git", "-C", wyoming, "rev-parse", "HEAD^{commit}", "HEAD^{tree}"
    ).lines.map(&:strip)
    raise Failure, "Wyoming commit or tree differs" unless
      values == [WYOMING_COMMIT, WYOMING_TREE]

    archive = command(
      "git", "-C", wyoming, "archive", "--format=tar", WYOMING_COMMIT
    )
    expected = ARCHIVES.fetch("wyoming")
    raise Failure, "Wyoming git archive size differs" unless
      archive.bytesize == expected.fetch("bytes")
    raise Failure, "Wyoming git archive hash differs" unless
      Digest::SHA256.hexdigest(archive) == expected.fetch("sha256")

    pyproject = File.binread(File.join(wyoming, "pyproject.toml"))
    require_include(pyproject, 'version = "1.10.0"', "Wyoming 1.10 version")
    true
  end

  def validate_ha_git_blobs(git_root, selected_root)
    output = command(
      "git", "-C", git_root, "ls-tree", "-r", HA_COMMIT, "--", *HA_FILES.keys,
      env: {"GIT_NO_LAZY_FETCH" => "1"}
    )
    blobs = output.lines.to_h do |line|
      match = line.match(/\A100644 blob ([0-9a-f]{40})\t(.+)\n?\z/)
      raise Failure, "unexpected Home Assistant ls-tree record" unless match

      [match[2], match[1]]
    end
    raise Failure, "Home Assistant Git path set differs" unless
      blobs.keys.sort == HA_FILES.keys.sort

    HA_FILES.each_key do |relative|
      bytes = File.binread(File.join(selected_root, relative))
      git_blob = Digest::SHA1.hexdigest("blob #{bytes.bytesize}\0#{bytes}")
      raise Failure, "Home Assistant Git blob differs: #{relative}" unless
        blobs.fetch(relative) == git_blob
    end
    true
  end

  def validate_source_contracts(paths)
    cpython = paths.fetch("cpython_tree")
    patchlevel = File.binread(File.join(cpython, "Include/patchlevel.h"))
    require_include(patchlevel, '#define PY_VERSION              "3.14.6"',
                    "CPython version")
    ssl_source = File.binread(File.join(cpython, "Modules/_ssl.c"))
    %w[set_psk_client_callback set_psk_server_callback].each do |api|
      require_include(ssl_source, api, "CPython PSK API")
    end
    raise Failure, "CPython client PSK copy contract differs" unless
      ssl_source.scan("memcpy(psk, psk_, psk_len_);").length == 2
    require_exclude(ssl_source, "mlock(", "CPython PSK callback locking")
    expat_siphash = File.binread(
      File.join(cpython, "Modules/expat/siphash.h")
    )
    require_include(
      expat_siphash,
      "Licensed under the CC0 Public Domain Dedication license.",
      "CPython bundled Expat SipHash license"
    )
    %w[William\ Ahern Jean-Philippe\ Aumasson Daniel\ J.\ Berstein].each do |name|
      require_include(
        expat_siphash,
        name.tr("\\", ""),
        "CPython bundled Expat SipHash attribution"
      )
    end
    blake2 = File.binread(File.join(cpython, "Modules/blake2module.c"))
    %w[Dmitry\ Chestnykh Christian\ Heimes Jonathan\ Protzenko].each do |name|
      require_include(
        blake2,
        name.tr("\\", ""),
        "CPython bundled BLAKE2 attribution"
      )
    end
    require_include(
      blake2,
      "dedicated all\n * copyright and related and neighboring rights",
      "CPython bundled BLAKE2 public-domain dedication"
    )
    blake2_notice = File.binread(File.join(cpython, "Doc/library/hashlib.rst"))
    require_include(
      blake2_notice,
      "CC0 Public Domain Dedication",
      "CPython bundled BLAKE2 license notice"
    )

    openssl = paths.fetch("openssl_tree")
    version = File.binread(File.join(openssl, "VERSION.dat"))
    %w[MAJOR=3 MINOR=6 PATCH=3].each do |fact|
      require_include(version, fact, "OpenSSL version")
    end
    client = File.binread(File.join(openssl, "ssl/statem/extensions_clnt.c"))
    server = File.binread(File.join(openssl, "ssl/statem/extensions_srvr.c"))
    require_include(client, "TLSEXT_KEX_MODE_KE_DHE", "OpenSSL PSK-DHE offer")
    require_include(client, "unsigned char psk[PSK_MAX_PSK_LEN];",
                    "OpenSSL client stack PSK")
    require_include(server, "unsigned char pskdata[PSK_MAX_PSK_LEN];",
                    "OpenSSL server stack PSK")
    [client, server].each do |source|
      require_include(
        source,
        "the digest so we default to SHA256 as per the TLSv1.3 spec",
        "OpenSSL legacy callback digest"
      )
    end
    [client, server].each do |source|
      require_include(source, "SSL_SESSION_set1_master_key",
                      "OpenSSL session PSK copy")
      require_include(source, "OPENSSL_cleanse", "OpenSSL temporary PSK cleanse")
      require_exclude(source, "OPENSSL_secure_malloc",
                      "OpenSSL PSK callback secure allocation")
      require_exclude(source, "mlock(", "OpenSSL PSK callback locking")
    end

    ssl_lib = File.binread(File.join(openssl, "ssl/ssl_lib.c"))
    require_include(ssl_lib, "SSL_SESSION_set1_master_key",
                    "OpenSSL master-key setter")
    require_include(ssl_lib, "memcpy(sess->master_key, in, len);",
                    "OpenSSL session master-key copy")
    require_exclude(ssl_lib, "mlock(", "OpenSSL session-key locking")
    ssl_session = File.binread(File.join(openssl, "ssl/ssl_sess.c"))
    require_include(ssl_session, "OPENSSL_cleanse(ss->master_key",
                    "OpenSSL session cleanup")
    ssl_local = File.binread(File.join(openssl, "ssl/ssl_local.h"))
    %w[early_secret handshake_secret master_secret
       resumption_master_secret].each do |secret|
      require_include(ssl_local, "unsigned char #{secret}[EVP_MAX_MD_SIZE];",
                      "OpenSSL derived secret storage")
    end
    siphash = File.binread(File.join(openssl, "crypto/siphash/siphash.c"))
    require_include(
      siphash,
      "dedicated all copyright\n   and related and neighboring rights",
      "OpenSSL bundled SipHash dedication"
    )
    require_include(siphash, "CC0 Public Domain Dedication",
                    "OpenSSL bundled SipHash license")
    require_include(siphash, "Jean-Philippe Aumasson",
                    "OpenSSL bundled SipHash rightsholder")
    require_include(siphash, "Daniel J. Bernstein",
                    "OpenSSL bundled SipHash rightsholder")
    aes = File.binread(File.join(openssl, "crypto/aes/aes_core.c"))
    %w[Vincent\ Rijmen Antoon\ Bosselaers Paulo\ Barreto].each do |name|
      require_include(
        aes,
        name.tr("\\", ""),
        "OpenSSL bundled AES attribution"
      )
    end
    require_include(
      aes,
      "This code is hereby placed in the public domain.",
      "OpenSSL bundled AES public-domain dedication"
    )

    client_doc = File.binread(
      File.join(openssl, "doc/man3/SSL_CTX_set_psk_client_callback.pod")
    )
    server_doc = File.binread(
      File.join(openssl, "doc/man3/SSL_CTX_use_psk_identity_hint.pod")
    )
    require_include(
      client_doc,
      "are not possible with the\nB<SSL_psk_client_cb_func> callback",
      "OpenSSL client early-data exclusion"
    )
    require_include(
      server_doc,
      "are not possible with the B<SSL_psk_server_cb_func> callback",
      "OpenSSL server early-data exclusion"
    )
    true
  end

  def validate_compatibility_contracts(paths)
    ha_root = paths.fetch("ha_tree")
    bridge = File.binread(
      File.join(ha_root, "homeassistant/components/wyoming/conversation.py")
    )
    models = File.binread(
      File.join(ha_root, "homeassistant/components/conversation/models.py")
    )
    intent_helper = File.binread(
      File.join(ha_root, "homeassistant/helpers/intent.py")
    )
    wyoming_root = paths.fetch("wyoming_tree")
    wyoming_intent = File.binread(File.join(wyoming_root, "wyoming/intent.py"))
    wyoming_handle = File.binread(File.join(wyoming_root, "wyoming/handle.py"))

    require_include(bridge, "async with asyncio.TaskGroup() as task_group:",
                    "HA concurrent multi-intent dispatch")
    require_include(bridge, "task_group.create_task(", "HA concurrent task")
    require_exclude(bridge, "recognized_intent.context",
                    "HA Wyoming result-context consumption")
    require_exclude(bridge, "handled.context", "HA handled-context consumption")
    require_exclude(bridge, "not_recognized.context",
                    "HA not-recognized-context consumption")

    outbound_context = bridge[
      /context = \{"conversation_id": conversation_id\}(.*?)\n\n        try:/m, 1
    ]
    raise Failure, "HA outbound Wyoming context block missing" unless outbound_context
    require_exclude(outbound_context, "user_input.context",
                    "HA caller context forwarding")

    handle_call = bridge[/intent\.async_handle\((.*?)\n\s{32}\)/m, 1]
    raise Failure, "HA intent.async_handle call missing" unless handle_call
    require_exclude(handle_call, "context=", "HA caller context handling")
    require_include(
      intent_helper,
      "if context is None:\n        context = Context()",
      "HA synthesized caller context"
    )

    require_include(models, "continue_conversation: bool = False",
                    "HA continuation default")
    require_exclude(bridge, "continue_conversation=",
                    "HA explicit Wyoming continuation")

    %w[
      class\ Intent\(Eventable\):
      class\ NotRecognized\(Eventable\):
      class\ IntentsStart\(Eventable\):
      class\ IntentsStop\(Eventable\):
    ].each do |escaped|
      require_include(wyoming_intent, escaped.tr("\\", ""),
                      "Wyoming intent event surface")
    end
    %w[Handled NotHandled HandledStart HandledChunk HandledStop].each do |name|
      require_include(wyoming_handle, "class #{name}(Eventable):",
                      "Wyoming handle event surface")
    end
    require_exclude(wyoming_intent.downcase, "clarification",
                    "Wyoming typed clarification")
    require_exclude(wyoming_handle.downcase, "clarification",
                    "Wyoming typed clarification")
    true
  end

  def validate_materials(materials)
    material_list = materials.fetch("materials")
    ids = material_list.map { |record| record.fetch("id") }
    duplicate = ids.group_by(&:itself).find { |_, values| values.length > 1 }
    raise Failure, "duplicate material id: #{duplicate.first}" if duplicate

    records = material_list.to_h do |record|
      [record.fetch("id"), record]
    end
    cpython = records.fetch("cpython-3.14.6-p13-transport")
    raise Failure, "CPython material disposition differs" unless
      cpython["status"] == "REJECTED_SOURCE_PORTFOLIO" &&
        cpython["provider"] == "Python_Software_Foundation" &&
        cpython["upstream_owner"] == "Python_Software_Foundation" &&
        cpython["canonical_url"] ==
          "https://www.python.org/downloads/release/python-3146/" &&
        cpython["version"] == "3.14.6" &&
        cpython["supplied_commit"] == CPYTHON_COMMIT &&
        cpython["source_archive_bytes"] ==
          ARCHIVES.fetch("cpython").fetch("bytes") &&
        cpython["source_archive_sha256"] ==
          ARCHIVES.fetch("cpython").fetch("sha256") &&
        cpython["license"] == "MIXED_INELIGIBLE_NONEXHAUSTIVE" &&
        cpython["license_file"] == "LICENSE" &&
        cpython["license_file_bytes"] ==
          LICENSE_FILES.dig("cpython", "bytes") &&
        cpython["license_file_sha256"] == CPYTHON_FILES.fetch("LICENSE") &&
        cpython["allowed_use"] == "exact_rejection_and_capability_evidence_only" &&
        cpython["prohibited_use"] ==
          "source_projection_build_runtime_dependency_package_distribution_or_transport_selection" &&
        cpython["status_detail"] ==
          "nonexhaustive_rejection_witnesses_recorded_complete_bundle_not_admitted" &&
        cpython["source_evidence"] == EVIDENCE &&
        cpython["extracted_tree_sha256"] ==
          TREES.fetch("cpython").fetch("sha256") &&
        cpython["bundle_admission"] == "REJECTED_NO_FUTURE_PRODUCT_USE"

    openssl = records.fetch("openssl-3.6.3-p13-transport")
    raise Failure, "OpenSSL material disposition differs" unless
      openssl["status"] == "REJECTED_SOURCE_PORTFOLIO" &&
        openssl["provider"] == "OpenSSL_Project" &&
        openssl["upstream_owner"] == "OpenSSL_Project_Authors" &&
        openssl["canonical_url"] == "https://openssl-library.org/source/" &&
        openssl["version"] == "3.6.3" &&
        openssl["supplied_commit"] == OPENSSL_COMMIT &&
        openssl["source_archive_bytes"] ==
          ARCHIVES.fetch("openssl").fetch("bytes") &&
        openssl["source_archive_sha256"] ==
          ARCHIVES.fetch("openssl").fetch("sha256") &&
        openssl["extracted_tree_sha256"] ==
          TREES.fetch("openssl").fetch("sha256") &&
        openssl["license"] == "MIXED_INELIGIBLE_NONEXHAUSTIVE" &&
        openssl["license_file"] == "LICENSE.txt" &&
        openssl["license_file_bytes"] ==
          LICENSE_FILES.dig("openssl", "bytes") &&
        openssl["bundle_licenses"] == [
          "Apache-2.0",
          "GPL-1.0-or-later OR Artistic-1.0-Perl",
          "CC0-1.0"
        ] &&
        openssl["license_file_sha256"] ==
          OPENSSL_FILES.fetch("LICENSE.txt") &&
        openssl["bundle_admission"] == "REJECTED_NO_FUTURE_PRODUCT_USE" &&
        openssl["status_detail"] ==
          "nonexhaustive_rejection_witnesses_recorded_complete_bundle_not_admitted" &&
        openssl["source_evidence"] == EVIDENCE &&
        openssl["allowed_use"] == "exact_rejection_and_capability_evidence_only" &&
        openssl["prohibited_use"] ==
          "source_projection_build_runtime_dependency_package_distribution_or_transport_selection"

    ha = records.fetch("home-assistant-core-2026.8.3")
    raise Failure, "Home Assistant material identity differs" unless
      ha["status"] == "OPEN_REFERENCE" &&
        ha["provider"] == "Home_Assistant_project" &&
        ha["upstream_owner"] == "home-assistant" &&
        ha["canonical_url"] == "https://github.com/home-assistant/core" &&
        ha["tag"] == "2026.8.3" &&
        ha["commit"] == HA_COMMIT &&
        ha["license"] == "Apache-2.0" &&
        ha["license_file"] == LICENSE_FILES.dig("home_assistant", "path") &&
        ha["license_file_bytes"] ==
          LICENSE_FILES.dig("home_assistant", "bytes") &&
        ha["license_file_sha256"] == HA_FILES.fetch("LICENSE.md") &&
        ha["allowed_use"] ==
          "public_contract_research_and_compatibility_tests" &&
        ha["prohibited_use"] ==
          "unlisted_repository_paths_or_linguistic_gold"
    material_paths = ha.fetch("contract_paths").to_h do |record|
      [record.fetch("path"), record.fetch("sha256")]
    end
    raise Failure, "Home Assistant material paths differ" unless
      material_paths == HA_FILES.reject { |path, _| path == "LICENSE.md" }

    wyoming = records.fetch("wyoming-protocol")
    raise Failure, "Wyoming material identity differs" unless
      wyoming["status"] == "OPEN_REFERENCE" &&
        wyoming["provider"] == "Rhasspy_Open_Home_Foundation" &&
        wyoming["upstream_owner"] == "rhasspy" &&
        wyoming["canonical_url"] == "https://github.com/rhasspy/wyoming" &&
        wyoming["commit"] == WYOMING_COMMIT &&
        wyoming["license"] == "MIT" &&
        wyoming["license_rightsholder"] == "Michael_Hansen" &&
        wyoming["license_file"] == LICENSE_FILES.dig("wyoming", "path") &&
        wyoming["license_file_bytes"] ==
          LICENSE_FILES.dig("wyoming", "bytes") &&
        wyoming["license_file_sha256"] == WYOMING_FILES.fetch("LICENSE.md") &&
        wyoming["allowed_use"] == "protocol_contract_research" &&
        wyoming["prohibited_use"] == "dependency_until_dependency_admission"
    material_paths = wyoming.fetch("contract_paths").to_h do |record|
      [record.fetch("path"), record.fetch("sha256")]
    end
    raise Failure, "Wyoming material paths differ" unless
      material_paths == WYOMING_FILES.reject { |path, _| path == "LICENSE.md" }

    MATERIAL_RECORD_SEMANTIC_SHA256.each do |id, expected|
      actual = semantic_digest(records.fetch(id))
      raise Failure, "material record semantic digest differs: #{id}" unless
        actual == expected
    end
    true
  rescue KeyError => error
    raise Failure, "material record missing: #{error.message}"
  end

  def validate_evidence(evidence)
    raise Failure, "P13 evidence identity differs" unless
      evidence["schema_version"] == 1 &&
        evidence["phase"] == "P13" &&
        evidence["status"] ==
          "REJECTED_PRODUCT_TRANSPORT_CAPABILITY_EVIDENCE_ONLY" &&
        evidence["tree_digest_algorithm"] == TREE_ALGORITHM
    expected_policy = {
      "repository_primary_evidence_only" => true,
      "network_used" => false,
      "sibling_repository_used" => false,
      "closed_engine_used" => false,
      "amazon_or_aws_material_used" => false,
      "generated_linguistic_evidence_used" => false,
      "technical_fixture_label" => "FIXTURE_TECNICA",
      "language_outputs_as_gold" => false
    }
    raise Failure, "P13 technical fixture policy differs" unless
      evidence.fetch("evidence_policy") == expected_policy

    sources = evidence.fetch("sources")
    ARCHIVES.each do |name, expected|
      source = sources.fetch(name)
      raise Failure, "#{name} evidence archive differs" unless
        source["archive_bytes"] == expected.fetch("bytes") &&
          source["archive_sha256"] == expected.fetch("sha256")
      tree = TREES.fetch(name)
      raise Failure, "#{name} evidence tree differs" unless
        source["tree_files"] == tree.fetch("files") &&
          source["tree_sha256"] == tree.fetch("sha256")
    end
    validate_evidence_source_facts(sources)
    raise Failure, "CPython reviewed path inventory differs" unless
      path_hash_inventory(sources.fetch("cpython").fetch("reviewed_paths")) ==
        CPYTHON_FILES
    raise Failure, "OpenSSL reviewed path inventory differs" unless
      path_hash_inventory(sources.fetch("openssl").fetch("reviewed_paths")) ==
        OPENSSL_FILES
    raise Failure, "Home Assistant evidence path inventory differs" unless
      path_hash_inventory(
        sources.fetch("home_assistant").fetch("contract_paths")
      ) == HA_FILES.reject { |path, _| path == "LICENSE.md" }
    raise Failure, "Wyoming evidence path inventory differs" unless
      path_hash_inventory(sources.fetch("wyoming").fetch("contract_paths")) ==
        WYOMING_FILES.reject { |path, _| path == "LICENSE.md" }

    compatibility = evidence.fetch("compatibility")
    raise Failure, "compatibility provenance differs" unless
      compatibility["exact_contract"] ==
        "Home_Assistant_2026.8.3_plus_Wyoming_1.10.0" &&
        compatibility["result"] == "ALL_FOUR_PROPERTIES_LOST" &&
        compatibility["authority"] ==
          "source_contract_only_not_linguistic_gold_or_runtime_authority"
    expected_properties = [
      {
        "property" => "complete_clarification",
        "observed" => false,
        "disposition" => "companion_required_or_abstain",
        "reason" =>
          "no_typed_clarification_event_or_option_session_result_crosses_bridge"
      },
      {
        "property" => "ordered_execution",
        "observed" => false,
        "disposition" => "companion_required_or_abstain",
        "reason" =>
          "home_assistant_creates_one_task_per_intent_inside_asyncio_TaskGroup"
      },
      {
        "property" => "caller_context",
        "observed" => false,
        "disposition" => "companion_required_or_abstain",
        "reason" =>
          "bridge_omits_ConversationInput_context_and_async_handle_context"
      },
      {
        "property" => "explicit_continuation",
        "observed" => false,
        "disposition" => "companion_required_or_abstain",
        "reason" =>
          "result_default_is_false_and_bridge_ignores_wyoming_response_context"
      }
    ]
    raise Failure, "compatibility dispositions, observations, or reasons differ" unless
      compatibility.fetch("properties") == expected_properties

    transport = evidence.fetch("transport")
    raise Failure, "transport disposition differs" unless
      transport["candidate"] ==
        "CPython_3.14_ssl_plus_OpenSSL_3.6.3_TLS1.3_external_PSK" &&
        transport["disposition"] == "REJECTED_FOR_PRODUCT_SELECTION" &&
        transport["capability_evidence_only"] == true &&
        transport["p14_reuse"] == "PROHIBITED" &&
        transport["probe_required"] == PROBE_REQUIREMENTS &&
        transport["rejection_reasons"] == REJECTION_REASONS &&
        transport.dig("secret_memory", "immutable_python_secret_objects_present") ==
          true &&
        transport.dig("secret_memory", "openssl_stack_and_session_copies_present") ==
          true &&
        transport.dig("secret_memory", "derived_session_secrets_present") ==
          true &&
        transport.dig("secret_memory", "temporary_openssl_stack_cleanse_present") ==
          true &&
        transport.dig("secret_memory", "session_master_key_cleanup_present") ==
          true &&
        transport.dig("secret_memory", "per_copy_locking_proven") == false &&
        transport.dig("secret_memory", "immediate_zeroization_proven") == false &&
        transport.dig("secret_memory", "process_wide_lock_owned_by") == "P14" &&
        transport.dig("secret_memory", "compromise") ==
          "dedicated_peer_process_must_lock_complete_address_space_before_secret"
    validate_evidence_runtime_facts(evidence.fetch("build_and_runtime"))
    raise Failure, "advisory disposition differs" unless
      evidence.fetch("advisory") == {
        "source_versions_pinned" => true,
        "local_network_lookup_performed" => false,
        "current_upstream_advisory_review" => "not_performed",
        "disposition" => "REJECTED_PORTFOLIO_NO_PRODUCT_ADMISSION_CLAIM"
      }
    expected_reviews = {
      "discovery" => "PENDING_INDEPENDENT_REVIEW",
      "license" => "PENDING_INDEPENDENT_REVIEW",
      "provenance" => "PENDING_INDEPENDENT_REVIEW",
      "quality_security" => "PENDING_INDEPENDENT_REVIEW",
      "defensive_adversarial" => "PENDING_INDEPENDENT_REVIEW",
      "product_admission_permanently_prohibited" => true
    }
    raise Failure, "independent review state differs" unless
      evidence.fetch("review_state") == expected_reviews

    raise Failure, "P13 evidence semantic digest differs" unless
      semantic_digest(evidence) == EVIDENCE_SEMANTIC_SHA256
    true
  rescue KeyError => error
    raise Failure, "P13 evidence field missing: #{error.message}"
  end

  def validate_evidence_source_facts(sources)
    cpython = sources.fetch("cpython")
    raise Failure, "CPython evidence source facts differ" unless
      cpython["owner"] == "Python_Software_Foundation" &&
        cpython["canonical_release"] == "CPython_3.14.6" &&
        cpython["archive_path"] == SOURCE_PATHS.fetch("cpython_archive") &&
        cpython["extracted_tree_path"] == SOURCE_PATHS.fetch("cpython_tree") &&
        cpython["supplied_commit"] == CPYTHON_COMMIT &&
        cpython["commit_to_release_archive_mapping"] ==
          "NOT_INDEPENDENTLY_PROVEN" &&
        cpython.fetch("extraction_mode_transform") == {
          "archive_regular_files_0644_to_tree_0644" => 4_993,
          "archive_executable_files_0755_to_tree_0755" => 107,
          "rule" => "none",
          "path_or_content_transformation" => "none"
        } &&
        cpython.dig("version_fact", "path") == "Include/patchlevel.h" &&
        cpython.dig("version_fact", "sha256") ==
          CPYTHON_FILES.fetch("Include/patchlevel.h") &&
        cpython.dig("version_fact", "value") == "3.14.6_final" &&
        cpython.fetch("license") == {
          "spdx" => "PSF-2.0",
          "osi_approved" => true,
          "path" => LICENSE_FILES.dig("cpython", "path"),
          "bytes" => LICENSE_FILES.dig("cpython", "bytes"),
          "sha256" => LICENSE_FILES.dig("cpython", "sha256"),
          "commercial_use" => "permitted",
          "modification" => "permitted",
          "redistribution" => "permitted_with_terms",
          "archive_bundle_license_inventory_complete" => false,
          "archive_bundle_admission" => "REJECTED_NO_FUTURE_PRODUCT_USE",
          "inventory_scope" => "known_rejection_witnesses_only",
          "obligations" => [
            "retain_complete_license_and_copyright_notices",
            "summarize_distributed_modifications"
          ]
        } &&
        cpython.fetch("known_non_osi_rejection_witnesses") ==
          CPYTHON_REJECTION_WITNESSES &&
        cpython.fetch("rightsholders") == [
          "Python_Software_Foundation",
          "BeOpen.com",
          "Corporation_for_National_Research_Initiatives",
          "Stichting_Mathematisch_Centrum"
        ] &&
        cpython.fetch("api_facts") == CPYTHON_API_FACTS

    openssl = sources.fetch("openssl")
    raise Failure, "OpenSSL evidence source facts differ" unless
      openssl["owner"] == "OpenSSL_Project_Authors" &&
        openssl["canonical_release"] == "OpenSSL_3.6.3" &&
        openssl["archive_path"] == SOURCE_PATHS.fetch("openssl_archive") &&
        openssl["extracted_tree_path"] == SOURCE_PATHS.fetch("openssl_tree") &&
        openssl["supplied_commit"] == OPENSSL_COMMIT &&
        openssl["commit_to_release_archive_mapping"] ==
          "NOT_INDEPENDENTLY_PROVEN" &&
        openssl.dig("version_fact", "path") == "VERSION.dat" &&
        openssl.dig("version_fact", "sha256") ==
          OPENSSL_FILES.fetch("VERSION.dat") &&
        openssl.dig("version_fact", "value") == "3.6.3_2026-06-09" &&
        openssl.fetch("license") == {
          "spdx" => "Apache-2.0",
          "osi_approved" => true,
          "archive_bundle_license" => "MIXED_INCLUDES_CC0-1.0",
          "archive_bundle_osi_approved" => false,
          "archive_bundle_license_inventory_complete" => false,
          "archive_bundle_admission" => "REJECTED_NO_FUTURE_PRODUCT_USE",
          "inventory_scope" => "known_rejection_witnesses_only",
          "path" => LICENSE_FILES.dig("openssl", "path"),
          "bytes" => LICENSE_FILES.dig("openssl", "bytes"),
          "sha256" => LICENSE_FILES.dig("openssl", "sha256"),
          "commercial_use" => "permitted",
          "modification" => "permitted",
          "redistribution" => "permitted_with_terms",
          "obligations" => [
            "include_Apache_2.0_license",
            "mark_modified_files",
            "retain_applicable_notices"
          ]
        } &&
        openssl.fetch("rightsholders") == [
          "OpenSSL_Project_Authors",
          "Eric_Young",
          "Tim_Hudson",
          "Jean-Philippe_Aumasson",
          "Daniel_J_Bernstein"
        ] &&
        openssl.fetch("extraction_mode_transform") == {
          "archive_regular_files_0664_to_tree_0644" => 5_697,
          "archive_executable_files_0775_to_tree_0755" => 159,
          "rule" => "clear_group_write_via_umask_0022",
          "path_or_content_transformation" => "none"
        } &&
        openssl.fetch("bundled_build_tools") == [
          {
            "path" => "external/perl/Text-Template-1.56/LICENSE",
            "rightsholder" => "Mark_Jason_Dominus",
            "license" => "GPL-1.0-or-later OR Artistic-1.0-Perl",
            "selected_license" => "Artistic-1.0-Perl",
            "sha256" =>
              "9837f05336ef3cbacb6a96e1672a0426d81ad01191f214b8d48e22ca62338181"
          }
        ] &&
        openssl.fetch("known_non_osi_rejection_witnesses") ==
          OPENSSL_REJECTION_WITNESSES &&
        openssl.fetch("api_facts") == OPENSSL_API_FACTS

    ha = sources.fetch("home_assistant")
    raise Failure, "Home Assistant evidence source facts differ" unless
      ha["owner"] == "Home_Assistant_project" &&
        ha["version"] == "2026.8.3" &&
        ha["tag"] == "2026.8.3" &&
        ha["commit"] == HA_COMMIT &&
        ha["git_tree"] == HA_TREE &&
        ha["archive_path"] == SOURCE_PATHS.fetch("ha_archive") &&
        ha["extracted_tree_path"] == SOURCE_PATHS.fetch("ha_tree") &&
        ha.fetch("extraction_mode_transform") == {
          "archive_regular_files_0664_to_tree_0644" => 14,
          "rule" => "clear_group_write_via_umask_0022",
          "path_or_content_transformation" => "none"
        } &&
        ha["git_binding"] == "selected_file_git_blob_ids_match_exact_commit_tree" &&
        ha.fetch("license") == {
          "spdx" => "Apache-2.0",
          "osi_approved" => true,
          "path" => LICENSE_FILES.dig("home_assistant", "path"),
          "bytes" => LICENSE_FILES.dig("home_assistant", "bytes"),
          "sha256" => LICENSE_FILES.dig("home_assistant", "sha256")
        } &&
        ha["use"] == "exact_public_contract_compatibility_only" &&
        ha["prohibited_use"] == "linguistic_gold_or_unlisted_repository_paths"

    wyoming = sources.fetch("wyoming")
    raise Failure, "Wyoming evidence source facts differ" unless
      wyoming["provider"] == "Rhasspy_Open_Home_Foundation" &&
        wyoming["rightsholder"] == "Michael_Hansen" &&
        wyoming["version"] == "1.10.0" &&
        wyoming["commit"] == WYOMING_COMMIT &&
        wyoming["git_tree"] == WYOMING_TREE &&
        wyoming["archive_path"] == SOURCE_PATHS.fetch("wyoming_archive") &&
        wyoming["extracted_tree_path"] == SOURCE_PATHS.fetch("wyoming_tree") &&
        wyoming.fetch("extraction_mode_transform") == {
          "archive_regular_files_0664_to_tree_0644" => 55,
          "archive_executable_files_0775_to_tree_0755" => 5,
          "rule" => "clear_group_write_via_umask_0022",
          "path_or_content_transformation" => "none"
        } &&
        wyoming["git_binding"] ==
          "deterministic_git_archive_matches_commit" &&
        wyoming.fetch("license") == {
          "spdx" => "MIT",
          "osi_approved" => true,
          "path" => LICENSE_FILES.dig("wyoming", "path"),
          "bytes" => LICENSE_FILES.dig("wyoming", "bytes"),
          "sha256" => LICENSE_FILES.dig("wyoming", "sha256")
        } &&
        wyoming["use"] == "exact_public_protocol_contract_compatibility_only" &&
        wyoming["prohibited_use"] == "runtime_dependency_until_separate_admission"
    true
  end

  def validate_evidence_runtime_facts(runtime)
    controlled = runtime.fetch("controlled_source_build")
    raise Failure, "controlled source-build evidence differs" unless
      controlled["admission"] == "REJECTED_FOR_PRODUCT_USE" &&
        controlled["rejection_reason"] ==
          "controlled_build_compiled_all_four_recorded_prohibited_witnesses" &&
        controlled["host"] == "macOS_26.6_arm64" &&
        controlled["openssl_configure"] == [
          "darwin64-arm64-cc",
          "--prefix=/private/tmp/p13-openssl-install",
          "--openssldir=/private/tmp/p13-openssl-install/ssl",
          "--libdir=lib",
          "shared",
          "no-tests"
        ] &&
        controlled["cpython_configure"] == [
          "--prefix=/private/tmp/p13-python-install",
          "--with-openssl=/private/tmp/p13-openssl-install",
          "--with-openssl-rpath=auto",
          "--without-ensurepip",
          "--disable-test-modules"
        ] &&
        controlled["architecture"] == "arm64" &&
        controlled["cpython_version"] == "3.14.6" &&
        controlled["openssl_tests"] == "not_built_or_run" &&
        path_hash_inventory(controlled.fetch("exact_artifacts")) ==
          SOURCE_BUILD_FILES

    homebrew = runtime.fetch("exact_homebrew_runtime")
    expected_hashes = {
      "python_executable_sha256" =>
        HOMEBREW_RUNTIME_FILES.fetch("/opt/homebrew/bin/python3.14"),
      "python_framework_sha256" => HOMEBREW_RUNTIME_FILES.fetch(
        "/opt/homebrew/Cellar/python@3.14/3.14.6/Frameworks/Python.framework/" \
        "Versions/3.14/Python"
      ),
      "ssl_extension_sha256" => HOMEBREW_RUNTIME_FILES.fetch(
        "/opt/homebrew/Cellar/python@3.14/3.14.6/Frameworks/Python.framework/" \
        "Versions/3.14/lib/python3.14/lib-dynload/_ssl.cpython-314-darwin.so"
      ),
      "openssl_cli_sha256" =>
        HOMEBREW_RUNTIME_FILES.fetch("/opt/homebrew/bin/openssl"),
      "libssl_sha256" => HOMEBREW_RUNTIME_FILES.fetch(
        "/opt/homebrew/Cellar/openssl@3/3.6.3/lib/libssl.3.dylib"
      ),
      "libcrypto_sha256" => HOMEBREW_RUNTIME_FILES.fetch(
        "/opt/homebrew/Cellar/openssl@3/3.6.3/lib/libcrypto.3.dylib"
      ),
      "cpython_receipt_sha256" => HOMEBREW_RUNTIME_FILES.fetch(
        "/opt/homebrew/Cellar/python@3.14/3.14.6/INSTALL_RECEIPT.json"
      ),
      "openssl_receipt_sha256" => HOMEBREW_RUNTIME_FILES.fetch(
        "/opt/homebrew/Cellar/openssl@3/3.6.3/INSTALL_RECEIPT.json"
      )
    }
    raise Failure, "Homebrew runtime evidence differs" unless
      homebrew["host"] == "macOS_26_arm64" &&
        homebrew["cpython_version"] == "3.14.6" &&
        homebrew["openssl_version"] == "OpenSSL_3.6.3_9_Jun_2026" &&
        homebrew["bottle_architecture"] == "arm64" &&
        homebrew["direct_openssl_dependency"] == "openssl_at_3_3.6.3" &&
        homebrew["psk_client_api"] == "present" &&
        homebrew["psk_server_api"] == "present" &&
        homebrew["exact_source_to_bottle_mapping"] == "not_proven" &&
        expected_hashes.all? { |field, value| homebrew[field] == value }

    architecture = runtime.fetch("architecture_disposition")
    raise Failure, "architecture disposition differs" unless
      architecture == {
        "arm64_macos_local_probe" => "available",
        "linux_aarch64" => "not_proven",
        "linux_amd64" => "not_proven",
        "home_assistant_packaged_runtime" => "not_proven"
      }
    true
  end

  def validate_homebrew_runtime
    HOMEBREW_RUNTIME_FILES.each do |path, sha256|
      verify_file(path, sha256: sha256, context: "Homebrew runtime #{path}")
    end
    python_receipt = parse_json(
      File.binread(
        "/opt/homebrew/Cellar/python@3.14/3.14.6/INSTALL_RECEIPT.json"
      ),
      "CPython Homebrew receipt"
    )
    openssl_receipt = parse_json(
      File.binread("/opt/homebrew/Cellar/openssl@3/3.6.3/INSTALL_RECEIPT.json"),
      "OpenSSL Homebrew receipt"
    )
    dependency = python_receipt.fetch("runtime_dependencies").find do |item|
      item["full_name"] == "openssl@3"
    end
    raise Failure, "CPython Homebrew bottle facts differ" unless
      python_receipt["built_as_bottle"] == true &&
        python_receipt["poured_from_bottle"] == true &&
        python_receipt["arch"] == "arm64" &&
        python_receipt.dig("source", "versions", "stable") == "3.14.6" &&
        dependency &&
        dependency["version"] == "3.6.3" &&
        dependency["declared_directly"] == true
    raise Failure, "OpenSSL Homebrew bottle facts differ" unless
      openssl_receipt["built_as_bottle"] == true &&
        openssl_receipt["poured_from_bottle"] == true &&
        openssl_receipt["arch"] == "arm64" &&
        openssl_receipt.dig("source", "versions", "stable") == "3.6.3"

    facts = parse_json(
      command(
        "/opt/homebrew/bin/python3.14", "-c",
        "import json,platform,ssl,sys,sysconfig;" \
        "print(json.dumps({" \
        "'version':platform.python_version()," \
        "'arch':platform.machine()," \
        "'openssl':ssl.OPENSSL_VERSION," \
        "'has_psk':ssl.HAS_PSK," \
        "'client':hasattr(ssl.SSLContext,'set_psk_client_callback')," \
        "'server':hasattr(ssl.SSLContext,'set_psk_server_callback')," \
        "'config':sysconfig.get_config_var('CONFIG_ARGS')}," \
        "sort_keys=True))"
      ),
      "Homebrew CPython runtime facts"
    )
    raise Failure, "Homebrew CPython runtime facts differ" unless
      facts["version"] == "3.14.6" &&
        facts["arch"] == "arm64" &&
        facts["openssl"] == "OpenSSL 3.6.3 9 Jun 2026" &&
        facts["has_psk"] == true &&
        facts["client"] == true &&
        facts["server"] == true &&
        facts["config"].include?("--with-openssl=/opt/homebrew/opt/openssl@3")

    linkage = command(
      "otool", "-L",
      "/opt/homebrew/Cellar/python@3.14/3.14.6/Frameworks/Python.framework/" \
      "Versions/3.14/lib/python3.14/lib-dynload/_ssl.cpython-314-darwin.so"
    )
    require_include(linkage, "/opt/homebrew/opt/openssl@3/lib/libssl.3.dylib",
                    "Homebrew _ssl libssl linkage")
    require_include(linkage, "/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib",
                    "Homebrew _ssl libcrypto linkage")
    true
  rescue KeyError => error
    raise Failure, "Homebrew receipt field missing: #{error.message}"
  end

  def validate_source_build
    SOURCE_BUILD_FILES.each do |path, sha256|
      verify_file(path, sha256: sha256, context: "source build #{path}")
    end
    config_log = File.binread("/private/tmp/p13-python-build/config.log")
    require_include(
      config_log,
      "--with-openssl=/private/tmp/p13-openssl-install",
      "source CPython OpenSSL configuration"
    )
    configdata = File.binread("/private/tmp/p13-openssl-build/configdata.pm")
    require_include(configdata, '"target" => "darwin64-arm64-cc"',
                    "source OpenSSL architecture")
    require_include(configdata, '"no-tests"', "source OpenSSL test configuration")
    require_include(configdata, "../openssl-3.6.3/crypto/siphash/siphash.c",
                    "source OpenSSL bundled SipHash inclusion")
    require_include(configdata, "../openssl-3.6.3/crypto/aes/aes_core.c",
                    "source OpenSSL bundled AES inclusion")

    facts = command(
      "/private/tmp/p13-python-install/bin/python3.14", "-c",
      "import platform,ssl;" \
      "print(platform.python_version());print(platform.machine());" \
      "print(ssl.OPENSSL_VERSION);print(ssl.HAS_PSK)"
    ).lines.map(&:strip)
    raise Failure, "source build runtime facts differ" unless
      facts == ["3.14.6", "arm64", "OpenSSL 3.6.3 9 Jun 2026", "True"]
    true
  end

  def verify_file(path, bytes: nil, sha256:, context:)
    read_verified_file(path, bytes: bytes, sha256: sha256, context: context)
    true
  end

  def read_verified_file(path, bytes: nil, sha256:, context:)
    raise Failure, "#{context} missing: #{path}" unless File.file?(path)

    contents = File.binread(path)
    raise Failure, "#{context} size differs" if bytes && contents.bytesize != bytes
    raise Failure, "#{context} hash differs" unless
      Digest::SHA256.hexdigest(contents) == sha256
    contents
  end

  def path_hash_inventory(records)
    raise Failure, "path inventory is not a sequence" unless records.is_a?(Array)

    inventory = {}
    records.each do |record|
      raise Failure, "path inventory record differs" unless
        record.is_a?(Hash) && record.keys.sort == %w[path sha256]
      path = record.fetch("path")
      raise Failure, "duplicate path inventory record: #{path}" if
        inventory.key?(path)

      inventory[path] = record.fetch("sha256")
    end
    inventory
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
      value.each do |item|
        encoded << semantic_encoding(item, depth + 1)
      end
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

  def command(*arguments, env: {}, stdin_data: nil)
    base_env = {
      "GIT_NO_LAZY_FETCH" => "1",
      "LC_ALL" => "C",
      "LANG" => "C",
      "TZ" => "UTC",
      "GIT_TERMINAL_PROMPT" => "0"
    }
    stdout, stderr, status = Open3.capture3(
      base_env.merge(env),
      *arguments,
      stdin_data: stdin_data
    )
    raise Failure, "command failed: #{arguments.first}: #{stderr.lines.first}" unless
      status.success?

    stdout.b
  end

  def relative_path(root, path)
    path.delete_prefix("#{root}/")
  end

  def require_include(bytes, needle, context)
    raise Failure, "#{context} predicate missing" unless bytes.include?(needle)

    true
  end

  def require_exclude(bytes, needle, context)
    raise Failure, "#{context} predicate unexpectedly present" if
      bytes.include?(needle)

    true
  end
end

P13Evidence.run(ARGV) if $PROGRAM_NAME == __FILE__
