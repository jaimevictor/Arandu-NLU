# frozen_string_literal: true
# P02V3_FUTURE_MUTABLE_SOURCE_BOUNDARY_V1

require "digest"
require "digest/sha1"
require "fileutils"
require "json"
require "open3"
require "psych"
require "tmpdir"
require_relative "p14-rustc-driver"

module P14Validation
  class Failure < StandardError; end
  class DuplicateJsonKey < StandardError; end

  class UniqueJsonObject < Hash
    def []=(key, value)
      raise DuplicateJsonKey, key if key?(key)

      super
    end
  end

  ROOT = File.expand_path("..", __dir__)
  HOST_TOOL_EVIDENCE =
    File.join(ROOT, "docs/evidence/P14-HOST-TOOLS.yaml")
  NOISE_PROMOTION_EVIDENCE =
    File.join(ROOT, "docs/evidence/P14-NOISE-SOURCE-PROMOTION.md")
  HA_LAUNCHER = File.join(ROOT, "tools/validate-p14-ha")
  HA_LAUNCHER_SHEBANG =
    "#!/usr/bin/env -S -i HOME=/var/empty PATH=/usr/bin:/bin " \
    "LC_ALL=C LANG=C TZ=UTC /usr/bin/ruby --disable-gems"
  GOVERNANCE_NORMATIVE_ROWS_SHA256 =
    "b31121a383ffa6c2a45841c6e4c94066cbbf7174047cfa1fbd2737bb0fb5e7da"
  GOVERNANCE_FILE_SHA256 = {
    "tools/validate-governance" =>
      "2211303db7dbc83c6dc42f7aa1b88b902e532d9b3a1dd1bdc7c8d8d3c7d2b863",
    "tools/validate-governance.rb" =>
      "07146021b7c23019f733d4110e84ba08abbfcadaec9117be523e331f6bb4f618",
    "tools/test-validate-governance" =>
      "0173861b25173f617b43c9325a03129d0cd68a617f48d5194abc2a522c925334",
    "tools/test-validate-governance.rb" =>
      "c93fd96c357e91ff062dc602ebedc883fc9e538260c61dde4c763d7a0909dc4c"
  }.freeze
  HOST_REVIEW_ROLES =
    %w[review-requirements review-risk review-repro].freeze
  EXPECTED_PYTHON_SOURCE = {
    "owner" => "Python_Software_Foundation",
    "canonical_url" =>
      "https://www.python.org/ftp/python/3.9.6/Python-3.9.6.tgz",
    "version" => "3.9.6",
    "bytes" => 25_640_094,
    "sha256" =>
      "d0a35182e19e416fc8eae25a3dcd4d02d4997333e4ad1f2eee6010aadc3fe866",
    "license" => "PSF-2.0",
    "license_file" => "Python-3.9.6/LICENSE",
    "installed_license_path" =>
      "/Library/Developer/CommandLineTools/Library/Frameworks/" \
      "Python3.framework/Versions/3.9/lib/python3.9/LICENSE.txt",
    "installed_license_bytes" => 13_925,
    "installed_license_sha256" =>
      "599826df92bfdcd2702eac691072498bb096c55af04ee984cf90f70ed77b5a70",
    "installed_license_matches_source_archive" => true,
    "rights_evidence" => {
      "upstream_owner" => "Python_Software_Foundation",
      "rightsholders" => [
        "Python_Software_Foundation",
        "BeOpen.com",
        "Corporation_for_National_Research_Initiatives",
        "Stichting_Mathematisch_Centrum"
      ],
      "rightsholder_basis" =>
        "complete_license_in_the_hash_bound_CPython_3_9_6_source_archive",
      "license_scope" =>
        "exact_CPython_3_9_6_source_archive_with_observed_host_runtime_" \
        "separately_version_identified_without_binary_correspondence_claim",
      "obligations" =>
        "retain_complete_license_and_copyright_notices_and_summarize_" \
        "modifications_if_redistributed",
      "commercial_use_and_modification" => "permitted",
      "redistribution_rights" => "permitted"
    },
    "independent_review_roles" => HOST_REVIEW_ROLES
  }.freeze
  EXPECTED_RUBY_COMPONENTS = {
    "status" => "ADMITTED_HOST_VALIDATION_COMPONENTS",
    "purpose" => "strict_P14_host_tool_YAML_parsing",
    "shipped" => false,
    "parent_runtime" => "/usr/bin/ruby",
    "components" => {
      "psych" => {
        "type" => "ruby_standard_library",
        "version" => "3.1.0",
        "source_owner" =>
          "Ruby_Psych_project_via_Apple_open_source_distribution",
        "source_url" => "https://github.com/ruby/psych",
        "source_commit" =>
          "8726508191a91377fa7c4b3f39352e319aa0e390",
        "license" => "MIT",
        "extension_path" =>
          "/System/Library/Frameworks/Ruby.framework/Versions/2.6/" \
          "usr/lib/ruby/2.6.0/universal-darwin25/psych.bundle",
        "extension_sha256" =>
          "9ce0fabbf13addb5b2138549274451e1c3e57a10ce662339a40b51c82ac76010",
        "rights_evidence" => {
          "upstream_owner" => "ruby",
          "rightsholders" => [
            "Aaron_Patterson",
            "Psych_contributors"
          ],
          "rightsholder_basis" =>
            "pinned_full_license_and_repository_history",
          "license_scope" =>
            "pinned_Psych_source_embedded_in_the_attested_Ruby_runtime",
          "obligations" =>
            "retain_copyright_and_permission_notice_if_redistributed",
          "commercial_use_and_modification" => "permitted",
          "redistribution_rights" => "permitted"
        },
        "independent_review_roles" => HOST_REVIEW_ROLES
      },
      "libyaml" => {
        "type" => "embedded_native_library",
        "version" => "0.2.1",
        "source_owner" => "LibYAML_Project_via_Psych",
        "source_url" => "https://github.com/yaml/libyaml",
        "source_commit" =>
          "f6e09f829b606ca0d0adf774236fa8cdd5e2a7d1",
        "license" => "MIT",
        "embedded_binary_path" =>
          "/System/Library/Frameworks/Ruby.framework/Versions/2.6/" \
          "usr/lib/ruby/2.6.0/universal-darwin25/psych.bundle",
        "embedded_binary_sha256" =>
          "9ce0fabbf13addb5b2138549274451e1c3e57a10ce662339a40b51c82ac76010",
        "rights_evidence" => {
          "upstream_owner" => "yaml",
          "rightsholders" => [
            "Kirill_Simonov",
            "LibYAML_contributors"
          ],
          "rightsholder_basis" =>
            "pinned_vendored_license_and_repository_history",
          "license_scope" =>
            "pinned_LibYAML_source_embedded_in_the_attested_Psych_extension",
          "obligations" =>
            "retain_copyright_and_permission_notice_if_redistributed",
          "commercial_use_and_modification" => "permitted",
          "redistribution_rights" => "permitted"
        },
        "independent_review_roles" => HOST_REVIEW_ROLES
      }
    }
  }.freeze
  EXPECTED_HA_GATE_TOOLS = {
    "env" => {
      "executable_path" => "/usr/bin/env",
      "executable_sha256" =>
        "75690864f0e7397db05bcc0f4439915559ce24c2d834d530e4e619c14b938556",
      "version" => "shell_cmds-329",
      "source_owner" => "apple-oss-distributions",
      "source_url" =>
        "https://github.com/apple-oss-distributions/shell_cmds",
      "source_commit" => "298787009e5432c5e4c378a077f98267077e3495",
      "license" => "BSD-2-Clause AND BSD-3-Clause",
      "rights_evidence" => {
        "upstream_owner" => "apple-oss-distributions",
        "rightsholders" => [
          "Apple_Inc",
          "FreeBSD_source_header_rightsholders"
        ],
        "rightsholder_basis" =>
          "exact_copyright_headers_in_the_pinned_env_source_paths",
        "license_scope" =>
          "exact_pinned_env_source_files_and_observed_host_executable",
        "obligations" =>
          "preserve_applicable_source_headers_if_redistributed",
        "commercial_use_and_modification" => "permitted",
        "redistribution_rights" => "permitted"
      },
      "independent_review_roles" => HOST_REVIEW_ROLES
    },
    "ruby" => {
      "executable_path" => "/usr/bin/ruby",
      "executable_sha256" =>
        "4d57327e7abe67e1c3f84a0869f4239b3324a3d7ea20a70077450e688282fe4f",
      "configured_runtime_path" =>
        "/System/Library/Frameworks/Ruby.framework/Versions/2.6/usr/bin/ruby",
      "configured_runtime_sha256" =>
        "5bfbea92fc5650cd28eb4bdbcf9b8eae654e61760673684c3c6293ad155ced5d",
      "version" => "2.6.10p210",
      "source_owner" => "apple-oss-distributions_and_Ruby_Project",
      "source_url" => "https://github.com/apple-oss-distributions/ruby",
      "source_commit" => "4b150aa904ded9fa254bb353bd1feec3c1b72c39",
      "license" => "Ruby OR BSD-2-Clause",
      "standard_library_modules" => %w[digest json open3],
      "rights_evidence" => {
        "upstream_owner" =>
          "apple-oss-distributions_and_Ruby_Project",
        "rightsholders" => [
          "Yukihiro_Matsumoto",
          "Ruby_contributors",
          "Apple_distribution_contributors"
        ],
        "rightsholder_basis" =>
          "pinned_full_license_and_repository_history",
        "license_scope" =>
          "pinned_Ruby_source_distribution_standard_library_and_" \
          "observed_host_executable",
        "obligations" =>
          "retain_Ruby_or_BSD_license_notices_if_redistributed",
        "commercial_use_and_modification" => "permitted",
        "redistribution_rights" => "permitted"
      },
      "independent_review_roles" => HOST_REVIEW_ROLES
    },
    "git" => {
      "executable_path" =>
        "/Library/Developer/CommandLineTools/usr/bin/git",
      "executable_sha256" =>
        "be4afb2b003904725826250de9fb76567bbacf82323457b5a1ec26706b66bcae",
      "version" => "2.50.1_Apple_Git-155",
      "source_owner" => "apple-oss-distributions_and_Git_Project",
      "source_url" => "https://github.com/apple-oss-distributions/Git",
      "source_commit" => "6b2f9bfe72d6d4b5c9bcc1c2d0236c026d321cba",
      "license" => "GPL-2.0-only",
      "rights_evidence" => {
        "upstream_owner" =>
          "apple-oss-distributions_and_Git_Project",
        "rightsholders" => [
          "Git_contributors_identified_by_pinned_history",
          "Apple_distribution_contributors"
        ],
        "rightsholder_basis" =>
          "pinned_full_GPL_text_file_headers_and_repository_history",
        "license_scope" =>
          "pinned_Git_source_distribution_and_observed_host_executable",
        "obligations" =>
          "GPL_source_and_notice_obligations_apply_only_if_the_tool_is_" \
          "redistributed",
        "commercial_use_and_modification" => "permitted",
        "redistribution_rights" => "permitted"
      },
      "independent_review_roles" => HOST_REVIEW_ROLES
    }
  }.freeze
  EXPECTED_HA_SOURCE = {
    "owner" => "Home_Assistant_project",
    "canonical_url" => "https://github.com/home-assistant/core",
    "tag" => "2026.8.3",
    "commit" => "759e4658f40b3ccb671d418b8a0ed95224bf4561",
    "tree" => "f4a72534bb33abf8b5d183910a0c134b968af2f8",
    "license" => "Apache-2.0",
    "license_file" => "LICENSE.md",
    "license_file_bytes" => 11_357,
    "license_file_sha256" =>
      "c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4",
    "rights_evidence" => {
      "upstream_owner" => "home-assistant",
      "rightsholders" => ["Home_Assistant_project_contributors"],
      "rightsholder_basis" =>
        "pinned_Apache_2_0_license_and_exact_repository_history",
      "license_scope" =>
        "exact_tag_commit_tree_and_selected_public_contract_paths",
      "obligations" =>
        "retain_Apache_2_0_license_and_applicable_notices_if_redistributed",
      "commercial_use_and_modification" => "permitted",
      "redistribution_rights" => "permitted"
    },
    "independent_review_roles" => HOST_REVIEW_ROLES
  }.freeze
  HISTORICAL_NOISE_IDENTITY = {
    "aggregate_package_tree_sha256" =>
      "f2856930555547530c12b316856f2bd3e29407b12c63117a35fa65318c6067e6",
    "commit" => "52f0f36ec79ffa30317ca9b8ec8efc6b695bb885",
    "manifest_blob" => "270f5fa44b7276a880fd77eb35dbdaa4edc65dcd",
    "schema_version" => 1,
    "tree" => "379992ee8f96263677e825def2bdfbe245640302"
  }.freeze
  CURRENT_NOISE_IDENTITY = {
    "aggregate_package_tree_sha256" =>
      "e769386d042e9ea34223c30f357d5a41fc0052a65dcf7279dc0f51c842de4a84",
    "manifest_blob" => "7fa0ca965ea6dd3ea9a840f42d35ef1524855501",
    "schema_version" => 3,
    "tree_digest_domain" => "P14_NOISE_TREE_V3"
  }.freeze
  EXPECTED_NOISE_IDENTITY = {
    "current" => CURRENT_NOISE_IDENTITY,
    "historical" => HISTORICAL_NOISE_IDENTITY
  }.freeze
  PYTHON = "/usr/bin/python3"
  PYTHON_RUNTIME = "/Library/Developer/CommandLineTools/usr/bin/python3"
  PYTHON_FRAMEWORK =
    "/Library/Developer/CommandLineTools/Library/Frameworks/" \
    "Python3.framework/Versions/3.9/Python3"
  PYTHON_LICENSE =
    "/Library/Developer/CommandLineTools/Library/Frameworks/" \
    "Python3.framework/Versions/3.9/lib/python3.9/LICENSE.txt"
  PYTHON_SOURCE_ARCHIVE = "/private/tmp/Python-3.9.6.tgz"
  HA_SOURCE = "/private/tmp/p14-ha-core-2026.8.3"
  HA_VERSION = "2026.8.3"
  HA_COMMIT = "759e4658f40b3ccb671d418b8a0ed95224bf4561"
  HA_TREE = "f4a72534bb33abf8b5d183910a0c134b968af2f8"
  FROZEN_HA_GATE_SUBJECT = "ba78fad6c7909c91efe32b5f11d221ae2a498a00"
  FROZEN_HA_GATE_TREE = "b61829855e60b967e1ec7ae53409e3903f4e78d1"
  FROZEN_HA_BLOBS = {
    "docs/evidence/P14-HOST-TOOLS.yaml" =>
      "864332d4e8829aa9b8f8afbc7355d458e2dafd6c",
    "tools/validate-p14-ha" =>
      "a974e808b3c8eb943c20a28ccc3881f20e56ab05"
  }.freeze
  FROZEN_HA_VALIDATION_BLOB =
    "f527e14c929efdf19e929dace3f7675c2a79ad22"
  FROZEN_HA_RESPONSE_FAILURES = [
    "P14_HA_GATE_FAIL: missing frozen latest-release response",
    "P14_HA_GATE_FAIL: latest-release byte count mismatch",
    "P14_HA_GATE_FAIL: latest-release SHA-256 mismatch"
  ].freeze
  TOOLCHAIN = File.join(ROOT, ".tools/rust-1.98.0")
  FINAL_REMEDIATION_BASE =
    "24be5d64282cc2226b870709f960110656cee008"
  FINAL_REMEDIATION_PARENT =
    "24be5d64282cc2226b870709f960110656cee008"
  FINAL_REMEDIATION_PATHS = %w[
    custom_components/local_nlu/__init__.py
    custom_components/local_nlu/executor.py
    custom_components/local_nlu/restart_journal.py
    custom_components/local_nlu/runtime.py
    tests/p14_companion/test_ha_runtime.py
    tests/p14_companion/test_setup_lifecycle.py
    tools/test-validate-p14.rb
    tools/validate-p14.rb
  ].freeze

  EXPECTED_COMPANION_TEST_IDENTITIES = %w[
    test_catalog_generation.CatalogGenerationTests.test_generation_is_stable_order_independent_and_bounded
    test_catalog_generation.CatalogGenerationTests.test_open_duplicate_or_unsorted_values_fail_closed
    test_catalog_generation.CatalogGenerationTests.test_semantic_change_changes_generation
    test_catalog_generation.CatalogGenerationTests.test_topology_is_cross_language_stable_and_semantic
    test_execution.ExecutionTests.test_admin_revocation_stops_before_second_effect
    test_execution.ExecutionTests.test_atomic_snapshot_authorizes_all_targets_before_read
    test_execution.ExecutionTests.test_atomic_snapshot_failure_exposes_no_partial_state
    test_execution.ExecutionTests.test_atomic_snapshot_returns_every_state_from_one_callback
    test_execution.ExecutionTests.test_authorization_is_rechecked_after_durable_ack
    test_execution.ExecutionTests.test_caller_binding_uses_trusted_context_not_request_field
    test_execution.ExecutionTests.test_cancelled_close_finishes_retirement_and_remains_idempotent
    test_execution.ExecutionTests.test_clock_rollback_after_effect_latches_without_raw_error
    test_execution.ExecutionTests.test_close_during_durable_ack_is_indeterminate_without_effect
    test_execution.ExecutionTests.test_close_failure_still_revokes_paused_dispatch
    test_execution.ExecutionTests.test_completed_connections_retire_without_nonce_reuse
    test_execution.ExecutionTests.test_completed_effect_does_not_latch_same_runtime
    test_execution.ExecutionTests.test_completed_read_only_operation_history_reclaims_capacity
    test_execution.ExecutionTests.test_completed_runtime_replacement_reconciles_before_fresh_effect
    test_execution.ExecutionTests.test_current_catalog_and_capability_are_rechecked_at_dispatch
    test_execution.ExecutionTests.test_durable_restart_acknowledgement_precedes_service_call
    test_execution.ExecutionTests.test_epoch_rotation_reconciles_late_effect_without_redispatch
    test_execution.ExecutionTests.test_expired_sessions_reclaim_capacity_with_tombstones
    test_execution.ExecutionTests.test_failed_durable_restart_write_blocks_effect
    test_execution.ExecutionTests.test_inactive_user_and_runtime_close_revoke_without_effect
    test_execution.ExecutionTests.test_inflight_duplicate_returns_indeterminate_without_dispatch
    test_execution.ExecutionTests.test_operation_tombstone_rejects_changed_node_attempt
    test_execution.ExecutionTests.test_partial_safe_graph_stops_after_indeterminate_node
    test_execution.ExecutionTests.test_queued_user_revocation_wins_before_service_dispatch
    test_execution.ExecutionTests.test_rejected_sequences_retire_without_connection_leak
    test_execution.ExecutionTests.test_replay_rejected_and_completed_retry_is_cached
    test_execution.ExecutionTests.test_restart_revokes_epoch_sessions_and_old_retries
    test_execution.ExecutionTests.test_same_operation_identity_with_changed_plan_is_tamper
    test_execution.ExecutionTests.test_stale_catalog_and_permission_revocation_cause_no_effect
    test_execution.ExecutionTests.test_target_expansion_stops_before_second_effect
    test_execution.ExecutionTests.test_timeout_is_indeterminate_and_never_blindly_retried
    test_execution.ExecutionTests.test_unknown_restart_marker_blocks_state_changing_dispatch
    test_execution.ExecutionTests.test_unresolved_effect_requires_exact_live_snapshot_evidence
    test_execution.ExecutionTests.test_unresolved_effect_survives_fresh_engine_reauthentication
    test_ha_runtime.HomeAssistantRuntimeTests.test_catalog_generation_preserves_canonical_explicit_entity_aliases
    test_ha_runtime.HomeAssistantRuntimeTests.test_fixed_service_mapping_preserves_context_and_closes_unknowns
    test_ha_runtime.HomeAssistantRuntimeTests.test_live_catalog_membership_rechecks_exposure_and_capability
    test_ha_runtime.HomeAssistantRuntimeTests.test_live_user_permission_wrapper_uses_exact_control_policy
    test_ha_runtime.HomeAssistantRuntimeTests.test_registry_target_expansion_and_atomic_state_snapshot
    test_ha_runtime.HomeAssistantRuntimeTests.test_restart_reconciliation_snapshot_is_complete_stable_and_closed
    test_helper.HelperExchangeTests.test_close_cleans_endpoint_only_after_child_exit
    test_helper.HelperExchangeTests.test_close_is_idempotent_and_prevents_reuse
    test_helper.HelperExchangeTests.test_close_refuses_endpoint_symlink
    test_helper.HelperExchangeTests.test_close_refuses_non_socket_endpoint
    test_helper.HelperExchangeTests.test_close_refuses_wrong_private_modes
    test_helper.HelperExchangeTests.test_framing_rejects_zero_oversized_and_truncated_replies
    test_helper.HelperExchangeTests.test_peer_rejection_precedes_every_write
    test_helper.HelperExchangeTests.test_rejected_reply_maps_to_one_closed_error
    test_helper.HelperExchangeTests.test_request_is_canonical_framed_authenticated_and_redacted
    test_helper.HelperReplyTests.test_reply_parser_rejects_duplicate_open_wrong_type_and_bounds
    test_helper.HelperReplyTests.test_reply_representation_hides_authenticated_wire
    test_helper.ValidationTests.test_all_submission_kinds_use_exact_canonical_rust_schemas
    test_helper.ValidationTests.test_endpoint_and_submission_validation_are_closed
    test_helper.ValidationTests.test_linux_peer_verifier_requires_exact_so_peercred_uid
    test_helper_process.BridgeTests.test_activation_failure_revokes_helper_and_reports_closed_code
    test_helper_process.BridgeTests.test_contract_rejects_bad_secret_duplicate_and_capacity
    test_helper_process.BridgeTests.test_explicit_revoke_wins_active_exit_monitor_race
    test_helper_process.BridgeTests.test_failed_shutdown_retries_without_losing_ownership
    test_helper_process.BridgeTests.test_invalid_proof_fails_closed_before_exchange_construction
    test_helper_process.BridgeTests.test_monitor_submit_failure_fails_closed_without_delivery
    test_helper_process.BridgeTests.test_popen_race_publishes_child_until_ordered_cleanup
    test_helper_process.BridgeTests.test_preproof_cleanup_requires_proven_child_exit
    test_helper_process.BridgeTests.test_preproof_timeout_cleans_bound_endpoint_after_proven_exit
    test_helper_process.BridgeTests.test_promoted_peer_can_be_revoked_without_epoch_storage
    test_helper_process.BridgeTests.test_provision_is_off_loop_and_writes_only_exact_credential
    test_helper_process.BridgeTests.test_quarantined_helper_reaps_after_late_exit_without_revoke
    test_helper_process.BridgeTests.test_revoke_during_proof_prevents_delivery_and_stops_process
    test_helper_process.BridgeTests.test_shutdown_wins_active_exit_monitor_race
    test_helper_process.BridgeTests.test_unexpected_active_exits_release_capacity_for_reuse
    test_helper_process.BridgeTests.test_unexpected_process_failure_retains_retryable_ownership
    test_helper_process.ProofTests.test_closed_proof_accepts_only_expected_nonsecret_bindings
    test_helper_process.ProofTests.test_proof_frame_requires_one_bounded_frame
    test_helper_process.ProofTests.test_proof_frame_timeout_is_bounded
    test_helper_process.ProofTests.test_proof_rejects_open_mismatched_and_malformed_values
    test_integration_contract.IntegrationContractTests.test_config_flow_displays_once_and_persists_only_metadata
    test_integration_contract.IntegrationContractTests.test_config_flow_prepares_helper_before_initial_pairing
    test_integration_contract.IntegrationContractTests.test_manifest_is_dependency_free_and_conversation_only
    test_integration_contract.IntegrationContractTests.test_no_generic_home_assistant_gateway_is_registered
    test_integration_contract.IntegrationContractTests.test_pure_contract_modules_use_only_standard_library_imports
    test_integration_contract.IntegrationContractTests.test_reauth_requires_snapshot_reconciliation_and_preserves_handoff
    test_integration_contract.IntegrationContractTests.test_sensitive_representations_and_metadata_are_redacted
    test_ledger.ExecutionSafetyStateTests.test_completed_effect_requires_reconciliation_after_runtime_retirement
    test_ledger.ExecutionSafetyStateTests.test_completed_effect_marker_survives_later_predispatch_release
    test_ledger.ExecutionSafetyStateTests.test_completed_operation_history_expires_without_becoming_a_retry
    test_ledger.ExecutionSafetyStateTests.test_concurrent_effect_preparations_are_serialized
    test_ledger.ExecutionSafetyStateTests.test_explicit_unknown_resolution_requires_authorizer
    test_ledger.ExecutionSafetyStateTests.test_high_water_rejects_initial_after_multiple_tombstone_cohorts
    test_ledger.ExecutionSafetyStateTests.test_indeterminate_effect_history_never_expires
    test_ledger.ExecutionSafetyStateTests.test_live_evidence_reconciles_only_exact_quiescent_effect
    test_ledger.ExecutionSafetyStateTests.test_multi_effect_retirement_reconciles_every_exact_effect
    test_ledger.ExecutionSafetyStateTests.test_operation_history_clock_failure_and_deadline_overflow_close
    test_ledger.ExecutionSafetyStateTests.test_operation_reservation_binds_complete_effect_attempt_set
    test_ledger.ExecutionSafetyStateTests.test_opposing_completed_effects_supersede_on_exact_live_state
    test_ledger.ExecutionSafetyStateTests.test_persisted_marker_precedes_effect_and_survives_retirement
    test_ledger.ExecutionSafetyStateTests.test_persisted_restart_barrier_is_monotonic
    test_ledger.ExecutionSafetyStateTests.test_reconciliation_release_capacity_spans_adjacent_clock_cohorts
    test_ledger.ExecutionSafetyStateTests.test_unknown_restart_barrier_never_authorizes_fresh_dispatch
    test_ledger.LedgerTests.test_clock_rollback_preserves_identities_and_latches_failure
    test_ledger.LedgerTests.test_expiration_tombstones_rotate_across_multiple_cohorts
    test_ledger.LedgerTests.test_inflight_tampered_unknown_expired_and_capacity_fail_closed
    test_ledger.LedgerTests.test_reserves_before_effect_and_returns_completed_cache
    test_pairing.PairingLifecycleTests.test_active_metadata_excludes_credential_and_epoch
    test_pairing.PairingLifecycleTests.test_all_retired_epochs_are_rejected_and_history_is_bounded
    test_pairing.PairingLifecycleTests.test_broker_cancel_revokes_verified_promoted_and_claimed_handoffs
    test_pairing.PairingLifecycleTests.test_broker_promotes_only_verified_memory_handoff
    test_pairing.PairingLifecycleTests.test_credential_uses_injected_csprng_and_displays_once
    test_pairing.PairingLifecycleTests.test_duplicate_promoted_peer_is_rejected_without_orphaning_first
    test_pairing.PairingLifecycleTests.test_interrupted_rotation_keeps_only_previous_active_epoch
    test_pairing.PairingLifecycleTests.test_restart_and_remove_revoke_memory_only_epoch
    test_pairing.PairingLifecycleTests.test_same_peer_reauthentication_preserves_new_promoted_handoff
    test_privacy_sinks.PrivacySinkTests.test_backup_round_trip_contains_only_nonsecret_peer_metadata
    test_privacy_sinks.PrivacySinkTests.test_component_has_no_log_metric_diagnostic_or_crash_export_sink
    test_privacy_sinks.PrivacySinkTests.test_errors_and_unhandled_crash_output_do_not_echo_canaries
    test_protocol.ProtocolContractTests.test_complete_request_round_trips_all_authenticated_bindings
    test_protocol.ProtocolContractTests.test_debug_and_errors_do_not_echo_residential_values
    test_protocol.ProtocolContractTests.test_duplicate_json_field_and_noncanonical_whitespace_fail
    test_protocol.ProtocolContractTests.test_every_outer_binding_is_mandatory
    test_protocol.ProtocolContractTests.test_every_typed_outcome_has_exact_variant_fields
    test_protocol.ProtocolContractTests.test_exact_typed_outcome_envelope_preserves_closed_v2_semantics
    test_protocol.ProtocolContractTests.test_json_depth_preflight_has_exact_and_closed_boundaries
    test_protocol.ProtocolContractTests.test_numeric_token_preflight_matches_v2_twenty_byte_bound
    test_protocol.ProtocolContractTests.test_plan_tamper_fails_digest_revalidation
    test_protocol.ProtocolContractTests.test_typed_outcome_rejects_smuggling_and_executable_bypass
    test_protocol.ProtocolContractTests.test_unknown_generic_gateway_fields_are_rejected
    test_protocol.ProtocolContractTests.test_unknown_operation_and_payload_smuggling_are_closed
    test_protocol.ProtocolContractTests.test_v2_plan_rejects_rust_constructor_counterexamples
    test_runtime.RuntimeTests.test_authenticated_caller_substitution_has_no_effect
    test_runtime.RuntimeTests.test_cancel_routes_bound_session_and_retires_it_locally
    test_runtime.RuntimeTests.test_cancelled_close_finishes_engine_and_exchange_cleanup
    test_runtime.RuntimeTests.test_close_prevents_inflight_reply_from_repopulating_sessions
    test_runtime.RuntimeTests.test_continue_and_confirm_route_exact_typed_session_values
    test_runtime.RuntimeTests.test_conversation_entity_routes_typed_continuation_flag
    test_runtime.RuntimeTests.test_deep_authenticated_json_returns_closed_runtime_result
    test_runtime.RuntimeTests.test_epoch_rotation_rejects_delayed_typed_session_reply
    test_runtime.RuntimeTests.test_expired_route_allows_text_and_rejects_numeric_work
    test_runtime.RuntimeTests.test_expired_typed_sessions_release_capacity_and_contexts
    test_runtime.RuntimeTests.test_identity_and_native_context_come_only_from_context
    test_runtime.RuntimeTests.test_missing_system_and_unbounded_contexts_fail_before_helper
    test_runtime.RuntimeTests.test_none_conversation_numeric_continuation_is_isolated
    test_runtime.RuntimeTests.test_pending_text_never_falls_back_to_interpretation
    test_runtime.RuntimeTests.test_production_entrypoint_reaches_continue_confirm_and_execution
    test_runtime.RuntimeTests.test_production_entrypoint_zero_cancels_each_pending_kind
    test_runtime.RuntimeTests.test_shared_clock_latches_cross_consumer_rollback_and_exception
    test_runtime.RuntimeTests.test_typed_outcomes_route_without_reaching_execution
    test_runtime.RuntimeTests.test_typed_session_clock_rollback_and_overflow_erase_state
    test_runtime.RuntimeTests.test_typed_session_routing_rejects_cross_caller_and_values
    test_runtime.RuntimeTests.test_typed_session_timer_erases_without_followup_request
    test_runtime.RuntimeTests.test_typed_session_ttl_exact_boundary_erases_and_stales
    test_runtime.RuntimeTests.test_unpaired_runtime_is_closed_and_redacted
    test_setup_lifecycle.SetupLifecycleTests.test_atomic_journal_write_fsyncs_file_and_parent
    test_setup_lifecycle.SetupLifecycleTests.test_changed_repair_snapshot_stays_blocked_and_reauths
    test_setup_lifecycle.SetupLifecycleTests.test_certificate_validation_waits_for_bound_entry_order
    test_setup_lifecycle.SetupLifecycleTests.test_clean_remove_does_not_taint_distinct_new_entry
    test_setup_lifecycle.SetupLifecycleTests.test_clean_reauth_reuses_state_without_unknown_barrier
    test_setup_lifecycle.SetupLifecycleTests.test_completed_effect_response_loss_blocks_restart_redispatch
    test_setup_lifecycle.SetupLifecycleTests.test_concurrent_journal_initialization_shares_one_owner
    test_setup_lifecycle.SetupLifecycleTests.test_distinct_readd_inherits_unresolved_orphan_barrier
    test_setup_lifecycle.SetupLifecycleTests.test_durable_journal_restart_blocks_redispatch
    test_setup_lifecycle.SetupLifecycleTests.test_explicit_snapshot_reconciliation_durably_clears_unknown
    test_setup_lifecycle.SetupLifecycleTests.test_journal_finishes_durable_transition_before_cancellation
    test_setup_lifecycle.SetupLifecycleTests.test_journal_record_contains_only_version_and_barrier
    test_setup_lifecycle.SetupLifecycleTests.test_journal_rejects_nonawaitable_executor_result
    test_setup_lifecycle.SetupLifecycleTests.test_metadata_predicates_reject_owner_mode_link_and_inode_changes
    test_setup_lifecycle.SetupLifecycleTests.test_matching_repair_snapshot_recovers_unknown_barrier
    test_setup_lifecycle.SetupLifecycleTests.test_missing_journal_bootstraps_only_for_first_pairing
    test_setup_lifecycle.SetupLifecycleTests.test_missing_malformed_and_legacy_journals_fail_closed
    test_setup_lifecycle.SetupLifecycleTests.test_new_state_inherits_durable_unknown_barrier
    test_setup_lifecycle.SetupLifecycleTests.test_platform_forward_cancellation_finishes_atomic_rollback
    test_setup_lifecycle.SetupLifecycleTests.test_platform_forward_failure_rolls_back_reused_runtime
    test_setup_lifecycle.SetupLifecycleTests.test_post_replace_inode_substitution_rejects_write
    test_setup_lifecycle.SetupLifecycleTests.test_prepublication_cancellation_revokes_consumed_handoff
    test_setup_lifecycle.SetupLifecycleTests.test_read_side_inode_substitution_normalizes_to_barrier
    test_setup_lifecycle.SetupLifecycleTests.test_reauth_preserves_known_pending_reconciliation
    test_setup_lifecycle.SetupLifecycleTests.test_reconciliation_clear_failure_remains_indeterminate_and_latched
    test_setup_lifecycle.SetupLifecycleTests.test_reconciliation_certificate_binds_endpoint_and_peer
    test_setup_lifecycle.SetupLifecycleTests.test_reconciliation_certificate_waits_for_last_owner
    test_setup_lifecycle.SetupLifecycleTests.test_reconciliation_durably_clears_journal
    test_setup_lifecycle.SetupLifecycleTests.test_reconciliation_proof_binds_endpoint_and_peer
    test_setup_lifecycle.SetupLifecycleTests.test_reconciliation_proof_is_single_use
    test_setup_lifecycle.SetupLifecycleTests.test_restart_journal_write_failure_aborts_setup
    test_setup_lifecycle.SetupLifecycleTests.test_runtime_build_failure_revokes_consumed_handoff
    test_setup_lifecycle.SetupLifecycleTests.test_runtime_replacement_reuses_process_local_safety_state
    test_setup_lifecycle.SetupLifecycleTests.test_setup_verification_handoff_and_shutdown_are_wired
    test_setup_lifecycle.SetupLifecycleTests.test_shutdown_cancellation_finishes_runtime_and_helper_cleanup
    test_setup_lifecycle.SetupLifecycleTests.test_snapshot_change_during_clear_stays_blocked
    test_setup_lifecycle.SetupLifecycleTests.test_snapshot_change_during_certificate_validation_stays_blocked
    test_setup_lifecycle.SetupLifecycleTests.test_stop_during_platform_forward_rolls_back_closed_runtime
    test_setup_lifecycle.SetupLifecycleTests.test_stop_during_prepublication_setup_never_publishes_runtime
    test_setup_lifecycle.SetupLifecycleTests.test_stop_revokes_epoch_before_paused_dispatch_resumes
    test_setup_lifecycle.SetupLifecycleTests.test_successful_effect_keeps_barrier_until_reconciliation
    test_setup_lifecycle.SetupLifecycleTests.test_two_entries_have_isolated_execution_safety_states
    test_setup_lifecycle.SetupLifecycleTests.test_unload_revokes_helper_peer_before_runtime_close
    test_setup_lifecycle.SetupLifecycleTests.test_unload_uses_owned_peer_when_entry_data_is_malformed
    test_setup_lifecycle.SetupLifecycleTests.test_unsafe_file_mode_and_hard_link_normalize_to_barrier
    test_setup_lifecycle.SetupLifecycleTests.test_unsafe_parent_and_preexisting_temporary_fail_closed
  ].freeze
  EXPECTED_COMPANION_TESTS = EXPECTED_COMPANION_TEST_IDENTITIES.length
  EXPECTED_COMPANION_IDENTITIES_SHA256 = begin
    digest = Digest::SHA256.new
    digest.update("P14_COMPANION_TEST_IDENTITIES_V1\0")
    EXPECTED_COMPANION_TEST_IDENTITIES.sort.each do |identity|
      digest.update(identity)
      digest.update("\0")
    end
    digest.hexdigest
  end
  EXPECTED_METADATA_TESTS = %w[
    test_adapter_api_allowlist_is_read_only_and_closed
    test_addon_manifest
    test_build_fails_closed_without_admitted_container_inputs
    test_credentials_are_absent_from_arguments_and_server_environment
    test_dedicated_ipc_layout_and_identities
    test_runtime_roles_and_product_boundary
    test_wyoming_pairing_and_rollback_flags
    test_z_all_metadata_is_canonical
  ].freeze
  EXPECTED_RUST_PASSED = 222
  EXPECTED_RUST_IGNORED = 3
  EXPECTED_RUST_BINARIES = 28
  EXPECTED_RUST_HARNESS_BINARIES = 27
  EXPECTED_RUST_HARNESSLESS = 1
  EXPECTED_CLIPPY_TARGETS = 38
  EXPECTED_NOISE_PACKAGES = 23
  CREDENTIAL_CANARY = "FIXTURE_TECNICA_CREDENTIAL_00000"
  DIRECT_SUMMARY_FIELDS = %w[
    binaries harness_binaries tests passed ignored measured filtered_out
    harnessless failed_binaries
  ].freeze

  BASE_ENVIRONMENT = {
    "HOME" => "/var/empty",
    "LANG" => "C",
    "LC_ALL" => "C",
    "PATH" => "/usr/bin:/bin",
    "TZ" => "UTC"
  }.freeze

  PYTHON_FILES = {
    PYTHON => ["b8763cf250e607a778bb4603cecb5b90338814d0a3dfcba0d57b1de242f610e9", 118_640],
    PYTHON_RUNTIME => ["bdea59019a38eb6600cc9e71e984a97fedadc406448431281e7657030f54987e", nil],
    PYTHON_FRAMEWORK => ["26422f0b21cb1e07236384afa4043c7401d39d09358c91df8bf3f5496f14712f", 5_864_880],
    PYTHON_LICENSE => ["599826df92bfdcd2702eac691072498bb096c55af04ee984cf90f70ed77b5a70", 13_925],
    PYTHON_SOURCE_ARCHIVE => ["d0a35182e19e416fc8eae25a3dcd4d02d4997333e4ad1f2eee6010aadc3fe866", 25_640_094]
  }.freeze

  module_function

  def run(arguments)
    subject = parse_subject_arguments(arguments)
    validate_invocation
    validate_python_import_roots
    validate_git_subject(
      root: ROOT,
      expected_commit: subject.fetch(:commit),
      expected_tree: subject.fetch(:tree)
    )
    scope = validate_final_remediation_scope(
      root: ROOT,
      candidate_commit: subject.fetch(:commit)
    )

    run_governance_gate(subject)
    host_tool_evidence = load_host_tool_evidence
    validate_host_tool_evidence(host_tool_evidence)
    validate_host_tool_files(host_tool_evidence)
    validate_ha_launcher_source(File.binread(HA_LAUNCHER))
    validate_host_python
    run_validator_self_tests
    companion_count = run_companion_tests
    run_home_assistant_identity_gate(
      candidate_commit: subject.fetch(:commit)
    )
    metadata_count = run_metadata_tests
    noise_count = run_noise_source_gate(
      candidate_commit: subject.fetch(:commit)
    )
    rust_summary = run_direct_rust_gate
    run_command(
      ["/usr/bin/git", "diff", "--check"],
      "Git whitespace validation"
    )
    validate_python_import_roots
    validate_git_subject(
      root: ROOT,
      expected_commit: subject.fetch(:commit),
      expected_tree: subject.fetch(:tree)
    )
    unless validate_final_remediation_scope(
      root: ROOT,
      candidate_commit: subject.fetch(:commit)
    ) == scope
      raise Failure, "P14 final remediation scope changed during validation"
    end

    puts(
      "P14_GIT_SUBJECT_PASS " \
      "commit=#{subject.fetch(:commit)} tree=#{subject.fetch(:tree)} " \
      "clean=tracked_and_untracked invocation=tools/validate-p14"
    )
    puts(
      "P14_FINAL_REMEDIATION_SCOPE_PASS " \
      "base=#{scope.fetch(:base)} parent=#{scope.fetch(:parent)} " \
      "changed_paths=#{scope.fetch(:changed_paths).length}"
    )
    puts(
      "P14_GOVERNANCE_PASS " \
      "rows_sha256=#{GOVERNANCE_NORMATIVE_ROWS_SHA256}"
    )
    puts "P14_COMPANION_TESTS_PASS count=#{companion_count}"
    puts(
      "P14_COMPANION_TEST_IDENTITIES_SHA256=" \
      "#{EXPECTED_COMPANION_IDENTITIES_SHA256}"
    )
    puts "P14_ADDON_METADATA_TESTS_PASS count=#{metadata_count}"
    puts "P14_NOISE_SOURCE_PACKAGES_PASS count=#{noise_count}"
    puts(
      "P14_DIRECT_RUST_PASS " \
      "passed=#{rust_summary.fetch(:passed)} " \
      "ignored=#{rust_summary.fetch(:ignored)} " \
      "clippy_targets=#{rust_summary.fetch(:clippy_targets)}"
    )
    puts "P14_REAL_HA_RUNTIME=DEFERRED_TO_P15_UNADMITTED_RUNTIME"
    puts "P14_NATIVE_LINUX_GATE=DEFERRED_TO_P15_ARTIFACTS_DISABLED"
    puts "P14_GATE_PASS_WITH_ACCEPTED_TRANSFERS"
    true
  end

  def parse_subject_arguments(arguments)
    values = {}
    pending = arguments.dup
    until pending.empty?
      option = pending.shift
      key = {
        "--expected-commit" => :commit,
        "--expected-tree" => :tree
      }.fetch(option, nil)
      raise Failure, subject_usage unless key && !pending.empty?
      raise Failure, "#{option} specified more than once" if values.key?(key)

      values[key] = pending.shift
    end
    raise Failure, "--expected-commit is required" unless values.key?(:commit)
    raise Failure, "--expected-tree is required" unless values.key?(:tree)
    values.each do |key, value|
      unless value.match?(/\A[0-9a-f]{40}\z/)
        raise Failure, "expected #{key} must be full lowercase 40-hex"
      end
    end
    values
  end

  def subject_usage
    "usage: tools/validate-p14 --expected-commit COMMIT --expected-tree TREE"
  end

  def validate_governance_bindings(
    normative_rows_sha256,
    file_sha256
  )
    unless normative_rows_sha256 == GOVERNANCE_NORMATIVE_ROWS_SHA256
      raise Failure, "governance normative-row SHA-256 differs"
    end
    unless file_sha256.is_a?(Hash) &&
           file_sha256.keys.sort == GOVERNANCE_FILE_SHA256.keys.sort
      raise Failure, "governance file SHA-256 tuple is incomplete"
    end
    unless file_sha256 == GOVERNANCE_FILE_SHA256
      raise Failure, "governance file SHA-256 tuple differs"
    end
    true
  end

  def validate_governance_local_tuple(root = ROOT)
    GOVERNANCE_FILE_SHA256.each do |path, expected_sha256|
      absolute = File.join(root, path)
      stat = File.lstat(absolute)
      unless stat.file? && !stat.symlink? && stat.nlink == 1 &&
             Digest::SHA256.file(absolute).hexdigest == expected_sha256
        raise Failure, "governance review tuple file differs: #{path}"
      end
    end
    validator = File.binread(
      File.join(root, "tools/validate-governance.rb")
    )
    matches = validator.scan(
      /^\s{2}NORMATIVE_ROWS_SHA256\s*=\s*"([0-9a-f]{64})"/m
    )
    unless matches == [[GOVERNANCE_NORMATIVE_ROWS_SHA256]]
      raise Failure, "governance normative-row contract differs"
    end
    true
  rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
    raise Failure, "governance review tuple file cannot be read safely"
  end

  def governance_validation_command(subject)
    validate_governance_bindings(
      GOVERNANCE_NORMATIVE_ROWS_SHA256,
      GOVERNANCE_FILE_SHA256
    )
    validate_governance_local_tuple
    [
      File.join(ROOT, "tools/validate-governance"),
      "--root", ROOT,
      "--expected-commit", subject.fetch(:commit),
      "--expected-tree", subject.fetch(:tree),
      "--expected-normative-rows-sha256",
      GOVERNANCE_NORMATIVE_ROWS_SHA256,
      "--expected-validate-launcher-sha256",
      GOVERNANCE_FILE_SHA256.fetch("tools/validate-governance"),
      "--expected-validator-source-sha256",
      GOVERNANCE_FILE_SHA256.fetch("tools/validate-governance.rb"),
      "--expected-test-launcher-sha256",
      GOVERNANCE_FILE_SHA256.fetch("tools/test-validate-governance"),
      "--expected-test-source-sha256",
      GOVERNANCE_FILE_SHA256.fetch("tools/test-validate-governance.rb")
    ]
  rescue KeyError
    raise Failure, "governance subject identity is incomplete"
  end

  def run_governance_gate(subject)
    output = run_command(
      governance_validation_command(subject),
      "exact governance validation",
      emit: false
    )
    validate_governance_output(output, subject)
    $stdout.write(output)
    true
  end

  def validate_governance_output(output, subject)
    pattern = Regexp.new(
      "\\Agovernance validation passed " \
      "\\(commit #{Regexp.escape(subject.fetch(:commit))}, " \
      "tree #{Regexp.escape(subject.fetch(:tree))}, " \
      "rows #{GOVERNANCE_NORMATIVE_ROWS_SHA256}, " \
      "[1-9][0-9]* requirements\\)\\n\\z"
    )
    unless output.match?(pattern)
      raise Failure, "exact governance validation marker differs"
    end
    true
  end

  def reject_duplicate_yaml_keys(node, label)
    case node
    when Psych::Nodes::Mapping
      keys = {}
      node.children.each_slice(2) do |key, value|
        unless key.is_a?(Psych::Nodes::Scalar)
          raise Failure, "#{label} contains a non-scalar YAML key"
        end
        raise Failure, "#{label} contains duplicate YAML keys" if
          keys.key?(key.value)

        keys[key.value] = true
        reject_duplicate_yaml_keys(value, label)
      end
    when Psych::Nodes::Alias
      raise Failure, "#{label} contains a YAML alias"
    else
      Array(node.children).each do |child|
        reject_duplicate_yaml_keys(child, label)
      end if node.respond_to?(:children)
    end
    true
  end

  def load_yaml_document(path, label)
    stat = File.lstat(path)
    unless stat.file? && !stat.symlink? && stat.nlink == 1
      raise Failure, "#{label} is not one regular file"
    end
    bytes = File.binread(path)
    stream = Psych.parse_stream(bytes, path)
    unless stream.children.length == 1 &&
           stream.children.fetch(0).root
      raise Failure, "#{label} must contain exactly one YAML document"
    end
    reject_duplicate_yaml_keys(stream, label)
    document = Psych.safe_load(bytes, [], [], false)
    raise Failure, "#{label} root is not a mapping" unless
      document.is_a?(Hash)

    document
  rescue Failure
    raise
  rescue Psych::Exception, ArgumentError, TypeError,
         Errno::ENOENT, Errno::EACCES, Errno::ELOOP
    raise Failure, "#{label} cannot be parsed safely"
  end

  def load_host_tool_evidence(path = HOST_TOOL_EVIDENCE)
    load_yaml_document(path, "P14 host-tool evidence")
  end

  def validate_host_tool_evidence(evidence)
    expected_root_keys = %w[
      schema_version
      observed_at
      companion_test_runtime
      validation_ruby_components
      home_assistant_gate_runtime
      home_assistant_identity
      independent_review
    ]
    unless evidence.is_a?(Hash) &&
           evidence.keys == expected_root_keys &&
           evidence.fetch("schema_version") == 2 &&
           evidence.fetch("observed_at") == "2026-09-01"
      raise Failure, "P14 host-tool evidence envelope differs"
    end

    companion = evidence.fetch("companion_test_runtime")
    unless companion.fetch("source") == EXPECTED_PYTHON_SOURCE
      raise Failure, "companion Python rights evidence differs"
    end
    unless companion.fetch("status") == "ADMITTED_HOST_VALIDATION_TOOL" &&
           companion.fetch("purpose") ==
             "dependency_free_P14_companion_contract_tests_only" &&
           companion.fetch("shipped") == false &&
           companion.fetch("site_initialization") ==
             "disabled_with_dash_S"
      raise Failure, "companion Python admission evidence differs"
    end

    unless evidence.fetch("validation_ruby_components") ==
           EXPECTED_RUBY_COMPONENTS
      raise Failure, "P14 Ruby component rights evidence differs"
    end

    gate = evidence.fetch("home_assistant_gate_runtime")
    unless gate.keys.sort == %w[
      host_boundary
      launcher
      purpose
      restrictions
      shipped
      status
      tools
    ]
      raise Failure, "Home Assistant gate evidence fields differ"
    end
    expected_launcher = {
      "path" => "tools/validate-p14-ha",
      "language" => "Ruby",
      "environment_sanitization" => "/usr/bin/env_-S_-i",
      "shell_invoked" => false,
      "dirname_invoked" => false
    }
    expected_host_boundary = {
      "exact_binary_source_correspondence_claimed" => false,
      "identified_foss_source_versions_and_complete_licenses" => true,
      "dynamic_components" => %w[CoreFoundation libSystem libruby],
      "statement" =>
        "selected_host_tools_are_not_shipped_and_ambient_host_libraries_" \
        "are_not_project_dependencies"
    }
    unless gate.fetch("status") == "ADMITTED_HOST_VALIDATION_TOOL_SET" &&
           gate.fetch("purpose") ==
             "exact_Home_Assistant_source_identity_and_disabled_artifact_gate" &&
           gate.fetch("shipped") == false &&
           gate.fetch("launcher") == expected_launcher &&
           gate.fetch("host_boundary") == expected_host_boundary &&
           gate.fetch("restrictions") ==
             %w[no_network no_shell no_product_runtime_use no_distribution]
      raise Failure, "Home Assistant gate admission evidence differs"
    end
    tools = gate.fetch("tools")
    unless tools.is_a?(Hash) &&
           tools.keys.sort == EXPECTED_HA_GATE_TOOLS.keys.sort
      raise Failure, "Home Assistant gate tool set differs"
    end
    EXPECTED_HA_GATE_TOOLS.each do |name, expected|
      unless tools.fetch(name) == expected
        display = name == "ruby" ? "Ruby" : name
        raise Failure, "Home Assistant gate #{display} evidence differs"
      end
    end

    identity = evidence.fetch("home_assistant_identity")
    unless identity.fetch("source") == EXPECTED_HA_SOURCE
      raise Failure, "Home Assistant source rights evidence differs"
    end
    review = evidence.fetch("independent_review")
    expected_review = {
      "required_roles" => HOST_REVIEW_ROLES,
      "prior_subject" => "e2ab301bad38caeaa2f32664bf442501eb8804df",
      "prior_result" => "FAIL_HOST_VALIDATION_TOOL_ADMISSION_INCOMPLETE",
      "remediation_status" => "REQUIRES_NEW_EXACT_SUBJECT_REVIEW"
    }
    unless review == expected_review
      raise Failure, "P14 host-tool independent-review evidence differs"
    end
    true
  rescue KeyError, TypeError
    raise Failure, "P14 host-tool evidence is incomplete"
  end

  def validate_ha_launcher_source(source)
    unless source.is_a?(String) &&
           source.lines.first&.chomp == HA_LAUNCHER_SHEBANG
      raise Failure, "Home Assistant launcher must use the admitted Ruby shebang"
    end
    prohibited = ["/bin/sh", "/usr/bin/dirname", "%x(", "%x[", "`"]
    if prohibited.any? { |token| source.include?(token) }
      raise Failure, "Home Assistant launcher selects a prohibited shell helper"
    end
    required = [
      "require \"open3\"",
      "GIT = \"/Library/Developer/CommandLineTools/usr/bin/git\"",
      "Open3.capture3(",
      "P14HomeAssistantValidation.run(ARGV)"
    ]
    unless required.all? { |token| source.scan(token).length == 1 }
      raise Failure, "Home Assistant Ruby launcher contract differs"
    end
    true
  end

  def validate_host_tool_files(evidence)
    tools = evidence.fetch("home_assistant_gate_runtime").fetch("tools")
    tools.each_value do |tool|
      validate_file(
        tool.fetch("executable_path"),
        tool.fetch("executable_sha256"),
        nil
      )
    end
    ruby = tools.fetch("ruby")
    validate_file(
      ruby.fetch("configured_runtime_path"),
      ruby.fetch("configured_runtime_sha256"),
      nil
    )
    components = evidence.fetch("validation_ruby_components")
      .fetch("components")
    psych = components.fetch("psych")
    validate_file(
      psych.fetch("extension_path"),
      psych.fetch("extension_sha256"),
      nil
    )
    libyaml = components.fetch("libyaml")
    validate_file(
      libyaml.fetch("embedded_binary_path"),
      libyaml.fetch("embedded_binary_sha256"),
      nil
    )
    true
  rescue KeyError, TypeError
    raise Failure, "P14 host-tool executable identity is incomplete"
  end

  def parse_unique_json(bytes, label)
    document = JSON.parse(
      bytes,
      object_class: UniqueJsonObject,
      max_nesting: 32
    )
    raise Failure, "#{label} root is not an object" unless
      document.is_a?(Hash)

    normalize_json(document)
  rescue DuplicateJsonKey
    raise Failure, "#{label} contains duplicate JSON keys"
  rescue JSON::ParserError, TypeError
    raise Failure, "#{label} is not strict JSON"
  end

  def normalize_json(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, member), normalized|
        normalized[key] = normalize_json(member)
      end
    when Array
      value.map { |member| normalize_json(member) }
    else
      value
    end
  end

  def load_noise_identity_evidence(path = NOISE_PROMOTION_EVIDENCE)
    bytes = File.binread(path)
    pattern = /
      <!--[ ]P14_NOISE_IDENTITY_JSON_BEGIN[ ]-->\n
      ```json\n
      (.*?)
      \n```\n
      <!--[ ]P14_NOISE_IDENTITY_JSON_END[ ]-->
    /mx
    matches = bytes.scan(pattern)
    unless matches.length == 1
      raise Failure, "P14 Noise identity JSON block is not unique"
    end
    parse_unique_json(matches.fetch(0).fetch(0), "P14 Noise identity evidence")
  rescue Failure
    raise
  rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
    raise Failure, "P14 Noise identity evidence cannot be read"
  end

  def validate_noise_identity_evidence(evidence)
    unless evidence.is_a?(Hash) &&
           evidence.keys.sort == %w[current historical]
      raise Failure, "P14 Noise identity evidence envelope differs"
    end
    unless evidence.fetch("historical") == HISTORICAL_NOISE_IDENTITY
      raise Failure, "historical Noise identity tuple differs"
    end
    unless evidence.fetch("current") == CURRENT_NOISE_IDENTITY
      raise Failure, "current Noise identity tuple differs"
    end
    true
  rescue KeyError, TypeError
    raise Failure, "P14 Noise identity evidence is incomplete"
  end

  def validate_invocation(
    program_name = $PROGRAM_NAME,
    validator_file = __FILE__
  )
    launcher = File.join(ROOT, "tools/validate-p14")
    source = File.join(ROOT, "tools/validate-p14.rb")
    unless File.realpath(program_name) == File.realpath(launcher)
      raise Failure, "P14 validator launcher invocation is not canonical"
    end
    unless File.realpath(validator_file) == File.realpath(source)
      raise Failure, "P14 validator source invocation is not canonical"
    end
    true
  rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
    raise Failure, "P14 validator invocation cannot be resolved"
  end

  def validate_git_subject(root:, expected_commit:, expected_tree:)
    unless expected_commit.match?(/\A[0-9a-f]{40}\z/) &&
           expected_tree.match?(/\A[0-9a-f]{40}\z/)
      raise Failure, "Git subject identities must be full lowercase 40-hex"
    end

    canonical_root = File.realpath(root)
    inside = git_output(root, "rev-parse", "--is-inside-work-tree").strip
    raise Failure, "P14 subject is not a Git worktree" unless inside == "true"
    top_level = git_output(root, "rev-parse", "--show-toplevel").strip
    unless File.realpath(top_level) == canonical_root
      raise Failure, "P14 validator root differs from the invocation subject"
    end

    head = git_output(root, "rev-parse", "--verify", "HEAD^{commit}").strip
    tree = git_output(root, "rev-parse", "--verify", "HEAD^{tree}").strip
    unless head == expected_commit
      raise Failure, "P14 subject commit differs from expected commit"
    end
    unless tree == expected_tree
      raise Failure, "P14 subject tree differs from expected tree"
    end
    commit_tree = git_output(
      root,
      "rev-parse",
      "--verify",
      "#{expected_commit}^{tree}"
    ).strip
    unless commit_tree == expected_tree
      raise Failure, "expected commit does not identify the expected tree"
    end

    status = git_output(
      root,
      "status",
      "--porcelain=v1",
      "-z",
      "--untracked-files=all",
      binary: true
    )
    unless status.empty?
      raise Failure, "P14 subject has staged, unstaged, or untracked changes"
    end
    index_entries = git_output(
      root,
      "ls-files",
      "-v",
      "-z",
      binary: true
    ).split("\0").reject(&:empty?)
    unless index_entries.all? { |entry| entry.start_with?("H ") }
      raise Failure, "P14 subject has concealed or unsupported index flags"
    end
    validate_subject_worktree_files(root, expected_commit)
    { commit: head, tree: tree }
  rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
    raise Failure, "P14 Git subject cannot be read safely"
  end

  def validate_subject_worktree_files(root, expected_commit)
    canonical_root = File.realpath(root)
    entries = git_output(
      root,
      "ls-tree",
      "-r",
      "-z",
      "--full-tree",
      expected_commit,
      binary: true
    ).split("\0").reject(&:empty?)
    entries.each do |entry|
      metadata, path = entry.split("\t", 2)
      mode, type, object = metadata.to_s.split(" ", 3)
      unless path && type == "blob" && %w[100644 100755].include?(mode) &&
             object&.match?(/\A[0-9a-f]{40}\z/)
        raise Failure, "P14 subject contains an unsupported tracked entry"
      end
      absolute = File.join(canonical_root, path)
      stat = File.lstat(absolute)
      expected_executable = mode == "100755"
      actual_executable = (stat.mode & 0o100).positive?
      unless stat.file? && !stat.symlink? && stat.nlink == 1 &&
             File.realpath(absolute) == absolute &&
             actual_executable == expected_executable
        raise Failure, "P14 subject worktree mode or type differs: #{path}"
      end

      bytes = File.binread(absolute)
      digest = Digest::SHA1.new
      digest.update("blob #{bytes.bytesize}\0")
      digest.update(bytes)
      unless digest.hexdigest == object
        raise Failure, "P14 subject worktree bytes differ: #{path}"
      end
    end
    true
  end

  def validate_final_remediation_scope(
    root:,
    candidate_commit:,
    authorized_base: FINAL_REMEDIATION_BASE,
    authorized_parent: FINAL_REMEDIATION_PARENT,
    allowed_paths: FINAL_REMEDIATION_PATHS
  )
    parents = git_output(
      root,
      "show",
      "-s",
      "--format=%P",
      candidate_commit
    ).split
    unless parents == [authorized_parent]
      raise Failure, "P14 final candidate parent differs from authorization"
    end
    changed_paths = git_output(
      root,
      "diff-tree",
      "--no-commit-id",
      "--name-only",
      "--no-renames",
      "-r",
      "-z",
      authorized_base,
      candidate_commit,
      binary: true
    ).split("\0").reject(&:empty?)
    if changed_paths.empty?
      raise Failure, "P14 final candidate has no remediation changes"
    end
    unless changed_paths.uniq.length == changed_paths.length
      raise Failure, "P14 final candidate changed-path evidence is duplicate"
    end
    unauthorized = changed_paths.reject { |path| allowed_paths.include?(path) }
    unless unauthorized.empty?
      raise Failure, "P14 final candidate changed paths exceed authorization"
    end
    {
      base: authorized_base,
      parent: authorized_parent,
      changed_paths: changed_paths.sort.freeze
    }.freeze
  end

  def git_output(root, *arguments, binary: false)
    stdout, _stderr, status = Open3.capture3(
      BASE_ENVIRONMENT.merge("GIT_NO_REPLACE_OBJECTS" => "1"),
      "/usr/bin/git",
      "-c",
      "core.fsmonitor=false",
      "-c",
      "core.untrackedCache=false",
      *arguments,
      unsetenv_others: true,
      chdir: root
    )
    unless status.success?
      raise Failure, "P14 Git subject command failed: #{arguments.first}"
    end
    binary ? stdout.b : stdout
  rescue SystemCallError
    raise Failure, "P14 Git subject command could not execute"
  end

  def validate_host_python
    PYTHON_FILES.each do |path, identity|
      validate_file(path, identity.fetch(0), identity.fetch(1))
    end
    raise Failure, "system Python is not executable" unless File.executable?(PYTHON)

    probe = run_command(
      [
        PYTHON,
        "-S",
        "-c",
        "import sys; print(sys.version_info[:3]); print(sys.executable); " \
        "print(sys.base_prefix)"
      ],
      "system Python identity",
      python_environment
    )
    validate_host_python_identity_output(probe)
    puts(
      "P14_HOST_PYTHON_PASS version=3.9.6 " \
      "site_initialization=disabled shipped=false"
    )
    true
  end

  def validate_host_python_identity_output(probe)
    expected = [
      "(3, 9, 6)",
      PYTHON_RUNTIME,
      File.dirname(PYTHON_FRAMEWORK)
    ]
    unless probe == expected.join("\n") + "\n"
      raise Failure, "system Python runtime identity differs"
    end
    true
  end

  def validate_file(path, expected_sha256, expected_size)
    raise Failure, "missing required file #{path}" unless File.file?(path)
    if expected_size && File.size(path) != expected_size
      raise Failure, "size differs for #{path}"
    end
    unless Digest::SHA256.file(path).hexdigest == expected_sha256
      raise Failure, "SHA-256 differs for #{path}"
    end
    true
  end

  def run_validator_self_tests
    output = run_command(
      [File.join(ROOT, "tools/test-validate-p14")],
      "P14 validator self-tests"
    )
    unless output == "P14_VALIDATOR_TESTS_PASS\n"
      raise Failure, "P14 validator self-test output differs"
    end
  end

  def run_companion_tests
    output = nil
    Dir.mktmpdir("p14-python-cache-", "/private/tmp") do |directory|
      output = run_command(
        companion_test_command(directory),
        "P14 companion tests",
        python_environment,
        emit: false
      )
      unless Dir.children(directory).empty?
        raise Failure, "P14 companion tests wrote bytecode cache state"
      end
    end
    identities = parse_unittest_evidence(output)
    count = validate_companion_evidence(identities)
    puts companion_execution_marker(identities)
    count
  end

  def companion_execution_marker(identities)
    unless identities.is_a?(Array) &&
           identities.sort == EXPECTED_COMPANION_TEST_IDENTITIES.sort
      raise Failure, "companion test identities differ"
    end
    "P14_COMPANION_EXECUTION_PASS " \
      "count=#{identities.length} " \
      "identities_sha256=#{EXPECTED_COMPANION_IDENTITIES_SHA256}"
  end

  def companion_test_command(bytecode_prefix)
    root = ROOT.dump
    tests = File.join(ROOT, "tests/p14_companion").dump
    runner = [
      "import sys, unittest",
      "root = #{root}",
      "tests = #{tests}",
      "sys.path.extend((root, tests))",
      "suite = unittest.defaultTestLoader.discover(" \
        "start_dir=tests, pattern='test_*.py')",
      "result = unittest.TextTestRunner(verbosity=2).run(suite)",
      "raise SystemExit(0 if result.wasSuccessful() else 1)"
    ].join("\n")
    [
      PYTHON,
      "-I",
      "-S",
      "-B",
      "-X",
      "pycache_prefix=#{bytecode_prefix}",
      "-c",
      runner
    ]
  end

  def validate_python_import_roots(root = ROOT)
    patterns = [
      File.join(root, "*.py[cod]"),
      File.join(root, "__pycache__", "**", "*.py[cod]"),
      File.join(root, "custom_components", "**", "*.py[cod]"),
      File.join(root, "tests/p14_companion", "**", "*.py[cod]")
    ]
    residue = patterns.flat_map do |pattern|
      Dir.glob(pattern, File::FNM_DOTMATCH)
    end.uniq
    unless residue.empty?
      raise Failure, "P14 Python import roots contain ignored bytecode"
    end
    true
  rescue SystemCallError
    raise Failure, "P14 Python import roots cannot be inspected"
  end

  def run_home_assistant_identity_gate(candidate_commit:)
    stdout, stderr, status = Open3.capture3(
      BASE_ENVIRONMENT,
      File.join(ROOT, "tools/validate-p14-ha"),
      unsetenv_others: true,
      chdir: ROOT
    )
    validate_command_output(
      stdout,
      stderr,
      "P14 Home Assistant identity gate"
    )
    if status.success?
      validate_home_assistant_success_output(stdout, stderr)
      $stdout.write(stdout)
      return true
    end

    validate_home_assistant_fallback_failure(stdout, stderr)
    validate_frozen_ha_history(
      root: ROOT,
      candidate_commit: candidate_commit
    )
    validate_pinned_ha_checkout
    puts(
      "P14_HA_SOURCE_IDENTITY_PASS version=#{HA_VERSION} " \
      "commit=#{HA_COMMIT} tree=#{HA_TREE} " \
      "latest_stable=frozen_historical_evidence"
    )
    puts "P14_REAL_HA_RUNTIME=DEFERRED_TO_P15_UNADMITTED_RUNTIME"
    true
  rescue SystemCallError => error
    raise Failure, "P14 Home Assistant identity gate could not execute: #{error.message}"
  end

  def home_assistant_success_output
    "P14_HA_SOURCE_IDENTITY_PASS version=#{HA_VERSION} " \
      "commit=#{HA_COMMIT} tree=#{HA_TREE} " \
      "latest_stable=same_identity\n" \
      "P14_REAL_HA_RUNTIME=DEFERRED_TO_P15_UNADMITTED_RUNTIME\n"
  end

  def validate_home_assistant_success_output(stdout, stderr)
    unless stdout == home_assistant_success_output && stderr.empty?
      raise Failure, "P14 Home Assistant identity gate output differs"
    end
    true
  end

  def validate_home_assistant_fallback_failure(stdout, stderr)
    admitted = FROZEN_HA_RESPONSE_FAILURES.any? do |failure|
      stderr == "#{failure}\n"
    end
    unless stdout.empty? && admitted
      raise Failure, "P14 Home Assistant identity gate failed"
    end
    true
  end

  def validate_frozen_ha_history(
    root:,
    candidate_commit:,
    historical_commit: FROZEN_HA_GATE_SUBJECT,
    historical_tree: FROZEN_HA_GATE_TREE,
    expected_blobs: FROZEN_HA_BLOBS,
    validation_blob: FROZEN_HA_VALIDATION_BLOB
  )
    tree = git_output(
      root,
      "rev-parse",
      "#{historical_commit}^{tree}"
    ).strip
    unless tree == historical_tree
      raise Failure, "frozen Home Assistant evidence tree differs"
    end
    git_output(
      root,
      "merge-base",
      "--is-ancestor",
      historical_commit,
      candidate_commit
    )
    expected_blobs.each do |path, expected_blob|
      historical_blob = git_output(
        root,
        "rev-parse",
        "#{historical_commit}:#{path}"
      ).strip
      unless historical_blob == expected_blob
        raise Failure, "frozen Home Assistant evidence blob differs: #{path}"
      end
    end
    actual_validation_blob = git_output(
      root,
      "rev-parse",
      "#{historical_commit}:docs/evidence/P14-VALIDATION.md"
    ).strip
    unless actual_validation_blob == validation_blob
      raise Failure, "frozen Home Assistant validation blob differs"
    end
    true
  end

  def validate_pinned_ha_checkout
    unless File.directory?(File.join(HA_SOURCE, ".git"))
      raise Failure, "pinned Home Assistant checkout is missing"
    end
    commit = git_output(
      HA_SOURCE, "rev-parse", "HEAD^{commit}"
    ).strip
    tree = git_output(
      HA_SOURCE, "rev-parse", "HEAD^{tree}"
    ).strip
    tag = git_output(
      HA_SOURCE, "describe", "--tags", "--exact-match", "HEAD"
    ).strip
    status = git_output(HA_SOURCE, "status", "--porcelain")
    unless commit == HA_COMMIT && tree == HA_TREE &&
           tag == HA_VERSION && status.empty?
      raise Failure, "pinned Home Assistant checkout identity differs"
    end

    project = File.join(HA_SOURCE, "pyproject.toml")
    project_stat = File.lstat(project)
    unless project_stat.file? && !project_stat.symlink?
      raise Failure, "pinned Home Assistant project metadata is invalid"
    end
    version_lines = File.readlines(project, chomp: true).select do |line|
      line.start_with?("version = ")
    end
    unless version_lines == ["version = \"#{HA_VERSION}\""]
      raise Failure, "pinned Home Assistant version differs"
    end

    build = JSON.parse(
      File.binread(File.join(ROOT, "addon/build-contract.json"))
    )
    architectures = build.fetch("architectures")
    disabled = architectures.all? do |architecture|
      architecture.fetch("status") == "disabled_pending_admission"
    end
    unless build.fetch("artifact_build_allowed") == false && disabled
      raise Failure, "P15 transfer disablement contract differs"
    end
    true
  rescue Errno::ENOENT, Errno::EACCES, JSON::ParserError, KeyError
    raise Failure, "pinned Home Assistant evidence cannot be read"
  end

  def run_metadata_tests
    output = run_command(
      ["/usr/bin/ruby", "--disable-gems", "tests/p14_addon/test_metadata.rb"],
      "P14 add-on metadata tests"
    )
    parse_metadata_count(output)
  end

  def validate_noise_manifest_identity(bytes, identity, label)
    manifest = parse_unique_json(bytes, label)
    unless manifest.fetch("schema_version") ==
             identity.fetch("schema_version") &&
           manifest.fetch("aggregate_package_tree_sha256") ==
             identity.fetch("aggregate_package_tree_sha256") &&
           manifest.fetch("package_count") == EXPECTED_NOISE_PACKAGES &&
           manifest.fetch("packages").is_a?(Array) &&
           manifest.fetch("packages").length == EXPECTED_NOISE_PACKAGES
      raise Failure, "#{label} semantic identity differs"
    end
    true
  rescue KeyError, TypeError
    raise Failure, "#{label} is incomplete"
  end

  def validate_noise_identity_history(
    root:,
    candidate_commit:,
    evidence: load_noise_identity_evidence
  )
    validate_noise_identity_evidence(evidence)
    historical = evidence.fetch("historical")
    current = evidence.fetch("current")
    historical_commit = historical.fetch("commit")
    resolved_commit = git_output(
      root,
      "rev-parse",
      "#{historical_commit}^{commit}"
    ).strip
    historical_tree = git_output(
      root,
      "rev-parse",
      "#{historical_commit}^{tree}"
    ).strip
    historical_blob = git_output(
      root,
      "rev-parse",
      "#{historical_commit}:vendor/p14-noise-source-manifest.json"
    ).strip
    unless resolved_commit == historical_commit &&
           historical_tree == historical.fetch("tree") &&
           historical_blob == historical.fetch("manifest_blob")
      raise Failure, "historical Noise Git identity differs"
    end
    git_output(
      root,
      "merge-base",
      "--is-ancestor",
      historical_commit,
      candidate_commit
    )
    historical_manifest = git_output(
      root,
      "show",
      "#{historical_commit}:vendor/p14-noise-source-manifest.json",
      binary: true
    )
    validate_noise_manifest_identity(
      historical_manifest,
      historical,
      "historical Noise manifest"
    )

    current_blob = git_output(
      root,
      "rev-parse",
      "#{candidate_commit}:vendor/p14-noise-source-manifest.json"
    ).strip
    unless current_blob == current.fetch("manifest_blob")
      raise Failure, "current Noise manifest blob differs"
    end
    current_manifest = git_output(
      root,
      "show",
      "#{candidate_commit}:vendor/p14-noise-source-manifest.json",
      binary: true
    )
    validate_noise_manifest_identity(
      current_manifest,
      current,
      "current Noise manifest"
    )
    promotion_source = git_output(
      root,
      "show",
      "#{candidate_commit}:tools/promote-p14-noise-sources.rb",
      binary: true
    )
    domain_binding =
      "digest_field(digest, \"#{current.fetch('tree_digest_domain')}\")"
    unless promotion_source.scan(domain_binding).length == 1
      raise Failure, "current Noise tree digest domain differs"
    end
    true
  rescue KeyError, TypeError
    raise Failure, "P14 Noise Git identity evidence is incomplete"
  end

  def run_noise_source_gate(candidate_commit:)
    validate_noise_identity_history(
      root: ROOT,
      candidate_commit: candidate_commit
    )
    output = run_command(
      [File.join(ROOT, "tools/promote-p14-noise-sources"), "--check"],
      "P14 Noise source promotion check",
      emit: false
    )
    count = parse_noise_source_output(output)
    $stdout.write(output)
    count
  end

  def parse_noise_source_output(output)
    expected =
      "P14_NOISE_SOURCE_PROMOTION_PASS\n" \
      "P14_NOISE_SOURCE_PACKAGE_COUNT=#{EXPECTED_NOISE_PACKAGES}\n"
    unless output == expected
      raise Failure, "Noise source promotion output differs"
    end
    EXPECTED_NOISE_PACKAGES
  end

  def run_direct_rust_gate
    output = nil
    Dir.mktmpdir("p14-direct-", "/private/tmp") do |directory|
      output_root = File.join(directory, "output")
      output = run_command(
        [
          File.join(ROOT, "tools/p14-rustc-driver"),
          ROOT,
          output_root,
          TOOLCHAIN
        ],
        "P14 direct Rust validation"
      )
    end
    parse_direct_summary(output)
  end

  def parse_unittest_evidence(output)
    matches = output.scan(/^Ran (\d+) tests? in /)
    completion_count = output.lines.count { |line| line.strip == "OK" }
    unless matches.length == 1 && completion_count == 1
      raise Failure, "unittest result is not one machine-verifiable PASS"
    end
    evidence = output.lines.map do |line|
      match = line.strip.match(
        /\A(test_[A-Za-z0-9_]+) \(([A-Za-z_][A-Za-z0-9_.]*)\) \.\.\. (.+)\z/
      )
      next unless match

      {
        identity: "#{match[2]}.#{match[1]}",
        status: match[3]
      }
    end.compact
    count = Integer(matches.fetch(0).fetch(0), 10)
    identities = evidence.map { |result| result.fetch(:identity) }
    raise Failure, "unittest evidence contains duplicate tests" unless
      identities.uniq.length == identities.length
    unless evidence.length == count
      raise Failure, "unittest evidence count differs from its summary"
    end
    unless evidence.all? { |result| result.fetch(:status) == "ok" }
      raise Failure, "unittest evidence contains a skipped or failed test"
    end
    output.each_line do |line|
      stripped = line.chomp
      next if stripped.empty? || stripped == "-" * 70 || stripped == "OK"
      next if stripped.match?(
        /\ARan (?:0|[1-9][0-9]*) tests? in [0-9]+(?:\.[0-9]+)?s\z/
      )
      next if stripped.match?(
        /\Atest_[A-Za-z0-9_]+ \([A-Za-z_][A-Za-z0-9_.]*\) \.\.\. ok\z/
      )

      raise Failure, "unittest output contains diagnostic text"
    end
    identities
  end

  def parse_unittest_count(output)
    parse_unittest_evidence(output).length
  end

  def validate_companion_evidence(identities)
    unless identities.sort == EXPECTED_COMPANION_TEST_IDENTITIES.sort
      raise Failure, "companion test identities differ"
    end
    identities.length
  end

  def parse_metadata_count(output)
    lines = output.lines.map(&:strip).reject(&:empty?)
    markers = lines.count { |line| line == "P14_ADDON_METADATA_TESTS_PASS" }
    raise Failure, "add-on metadata completion marker is not unique" unless
      markers == 1
    if lines.any? { |line| line.match?(/\A(?:SKIP|SKIPPED)\b/i) }
      raise Failure, "add-on metadata evidence contains a skipped test"
    end
    tests = lines.map do |line|
      match = line.match(/\APASS (test_[a-z0-9_]+)\z/)
      match && match[1]
    end.compact
    raise Failure, "add-on metadata evidence contains duplicate tests" unless
      tests.uniq.length == tests.length
    unless tests.sort == EXPECTED_METADATA_TESTS.sort
      raise Failure, "add-on metadata test identities differ"
    end
    expected_lines = EXPECTED_METADATA_TESTS.sort.map do |name|
      "PASS #{name}"
    end + ["P14_ADDON_METADATA_TESTS_PASS"]
    unless lines == expected_lines &&
           output == expected_lines.join("\n") + "\n"
      raise Failure, "add-on metadata output differs"
    end
    tests.length
  end

  def parse_direct_summary(output)
    summary_lines = output.lines.select do |line|
      line.start_with?("P14_DIRECT_RUST_TEST_SUMMARY ")
    end
    raise Failure, "direct Rust test summary is not unique" unless
      summary_lines.length == 1
    fields = parse_direct_fields(summary_lines.fetch(0))
    evidence = P14RustcDriver.validate_result_evidence(output, ROOT)
    rust_evidence = evidence.fetch(:rust)
    unless DIRECT_SUMMARY_FIELDS.all? do |field|
      fields.fetch(field) == rust_evidence.fetch(field.to_sym)
    end
      raise Failure, "direct Rust summary differs from target evidence"
    end
    unless fields.fetch("failed_binaries").zero?
      raise Failure, "direct Rust test binaries failed"
    end
    unless fields.fetch("binaries") == EXPECTED_RUST_BINARIES &&
           fields.fetch("harness_binaries") == EXPECTED_RUST_HARNESS_BINARIES &&
           fields.fetch("harnessless") == EXPECTED_RUST_HARNESSLESS &&
           fields.fetch("binaries") ==
             fields.fetch("harness_binaries") + fields.fetch("harnessless")
      raise Failure, "direct Rust binary accounting differs"
    end
    unless fields.fetch("passed") == EXPECTED_RUST_PASSED
      raise Failure, "direct Rust pass count differs"
    end
    unless fields.fetch("ignored") == EXPECTED_RUST_IGNORED
      raise Failure, "direct Rust ignored count differs"
    end
    unless fields.fetch("measured").zero? && fields.fetch("filtered_out").zero?
      raise Failure, "direct Rust selected-test accounting differs"
    end
    unless fields.fetch("tests") ==
           fields.fetch("passed") + fields.fetch("ignored") + fields.fetch("measured")
      raise Failure, "direct Rust test accounting differs"
    end

    clippy = output.scan(/^P14_DIRECT_CLIPPY_PASS targets=(\d+)$/)
    raise Failure, "direct Clippy summary is not unique" unless clippy.length == 1
    clippy_targets = Integer(clippy.fetch(0).fetch(0), 10)
    unless clippy_targets == EXPECTED_CLIPPY_TARGETS
      raise Failure, "direct Clippy target count differs"
    end
    unless clippy_targets == evidence.fetch(:clippy_targets)
      raise Failure, "direct Clippy summary differs from target evidence"
    end
    completion_count = output.lines.count do |line|
      line.strip == "P14_DIRECT_RUSTC_BUILD_PASS"
    end
    unless completion_count == 1
      raise Failure, "direct Rust completion marker is not unique"
    end
    {
      passed: fields.fetch("passed"),
      ignored: fields.fetch("ignored"),
      clippy_targets: clippy_targets
    }
  rescue P14RustcDriver::Failure => error
    raise Failure, error.message
  rescue ArgumentError
    raise Failure, "direct Rust summary is malformed"
  end

  def parse_direct_fields(summary_line)
    tokens = summary_line.strip.split
    unless tokens.shift == "P14_DIRECT_RUST_TEST_SUMMARY"
      raise Failure, "direct Rust summary fields differ"
    end
    pairs = tokens.map do |token|
      match = token.match(/\A([a-z_]+)=(0|[1-9][0-9]*)\z/)
      raise Failure, "direct Rust summary is malformed" unless match

      [match[1], Integer(match[2], 10)]
    end
    keys = pairs.map(&:first)
    raise Failure, "direct Rust summary contains duplicate keys" unless
      keys.uniq.length == keys.length
    raise Failure, "direct Rust summary fields differ" unless
      keys == DIRECT_SUMMARY_FIELDS
    pairs.to_h
  end

  def run_command(
    command,
    label,
    environment = BASE_ENVIRONMENT,
    emit: true
  )
    stdout, stderr, status = Open3.capture3(
      environment,
      *command,
      unsetenv_others: true,
      chdir: ROOT
    )
    output = stdout + stderr
    validate_command_output(stdout, stderr, label)
    unless status.success?
      $stdout.write(output) if emit
      raise Failure, "#{label} failed"
    end
    $stdout.write(output) if emit

    output
  rescue SystemCallError => error
    raise Failure, "#{label} could not execute: #{error.message}"
  end

  def python_environment
    BASE_ENVIRONMENT.merge(
      "HOME" => "/private/tmp",
      "TMPDIR" => "/private/tmp",
      "PYTHONDONTWRITEBYTECODE" => "1",
      "PYTHONNOUSERSITE" => "1",
      "PYTHONPATH" => ROOT
    )
  end

  def validate_no_credential_canary(output, label, stream)
    return true unless output.include?(CREDENTIAL_CANARY)

    raise Failure, "#{label} emitted a credential canary on #{stream}"
  end

  def validate_command_output(stdout, stderr, label)
    validate_no_credential_canary(stdout, label, "stdout")
    validate_no_credential_canary(stderr, label, "stderr")
    true
  end
end
