# frozen_string_literal: true

require "digest"
require "json"
require "open3"

module P13Validation
  class Failure < StandardError; end
  class DuplicateKey < StandardError; end

  class DuplicateRejectingHash < Hash
    def []=(key, value)
      raise DuplicateKey, key if key?(key)

      super
    end
  end

  ROOT = File.expand_path("..", __dir__)

  POLICY_FILES = %w[
    crates/policy-engine/Cargo.toml
    crates/policy-engine/src/engine.rs
    crates/policy-engine/src/error.rs
    crates/policy-engine/src/lib.rs
    crates/policy-engine/src/table.rs
    crates/policy-engine/tests/policy_contract.rs
  ].freeze

  SERVER_FILES = %w[
    crates/nlu-server/Cargo.toml
    crates/nlu-server/src/config.rs
    crates/nlu-server/src/error.rs
    crates/nlu-server/src/framing.rs
    crates/nlu-server/src/health.rs
    crates/nlu-server/src/lib.rs
    crates/nlu-server/src/runtime.rs
    crates/nlu-server/src/server.rs
    crates/nlu-server/src/snapshot.rs
    crates/nlu-server/tests/runtime_contract.rs
  ].freeze

  PROTOCOL_FILES = %w[
    crates/protocol/Cargo.toml
    crates/protocol/src/error.rs
    crates/protocol/src/lib.rs
    crates/protocol/src/preflight.rs
    crates/protocol/src/v1.rs
    crates/protocol/src/v2.rs
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_request-cancel-v2.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_request-confirm-v2.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_request-continue-v2.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_request-health-v2.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_request-interpret-v2.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_request-v1.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-abstention-v1.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-abstention-v2.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-cancellation-v2.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-clarification-v1.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-complete-plan-v2.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-confirmation-required-v2.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-entity-clarification-v2.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-health-v2.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-plan-v1.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-policy-accepted-v2.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-policy-denial-v2.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-protocol-error-v1.json
    crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-protocol-error-v2.json
    crates/protocol/tests/schema_contract.rs
    crates/protocol/tests/v1_regression.rs
    crates/protocol/tests/v2_hostile_corpus.rs
    crates/protocol/tests/v2_schema_contract.rs
    crates/protocol/tests/v2_wire_contract.rs
    crates/protocol/tests/wire_contract.rs
  ].freeze

  SCHEMA_FILES = %w[
    schemas/protocol-v1-request.schema.json
    schemas/protocol-v1-response.schema.json
    schemas/protocol-v2-request.schema.json
    schemas/protocol-v2-response.schema.json
  ].freeze

  V1_HASHES = {
    "crates/protocol/src/v1.rs" =>
      "dc30a3849e11f9a0edd3a72fb3d7e09df5daa51b1f7b50d13d978b1a38ffe9b4",
    "schemas/protocol-v1-request.schema.json" =>
      "5d6c8574c57ac9a8df4c1a3aec7e023d794be1c61b3aa9d8e82810e39d5e5231",
    "schemas/protocol-v1-response.schema.json" =>
      "6d45b099513cf1b57d42fc5f71e1a942fe56149fc7fac3cf6293829f5cd8c644",
    "crates/protocol/tests/fixtures/FIXTURE_TECNICA_request-v1.json" =>
      "f917a791d68e59704ccbbf4da4121748fe36e325743e5ef367547217a51e2d17",
    "crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-abstention-v1.json" =>
      "5099b10ea68d3a931e220a5ef2db560e17272129f3ada44349ee8a50abc33cad",
    "crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-clarification-v1.json" =>
      "4d523580b4e177871d69f0ff28d4e873ae1a6401c69d01bed9fbf32505b7d4c6",
    "crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-plan-v1.json" =>
      "0bb6bd07357cec66db156042194e667d59f83b5469013835a0cd97a715637572",
    "crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-protocol-error-v1.json" =>
      "541511bdf75add75af3a5c0ae3eeb7d1aaeba2aebff8bf8d56c30a4ad362d4e2"
  }.freeze

  REQUIREMENTS = (
    %w[
      GLB-SEC-001
      ARC-LANG-002
      ARC-POLICY-001
      ARC-PROTO-001
      ARC-SERVER-001
      P10-HA-024
    ] +
    (1..5).map { |number| format("P12-COMPAT-%03d", number) } +
    (1..4).map { |number| format("P13-POL-%03d", number) } +
    (1..6).map { |number| format("P13-PROTO-%03d", number) } +
    (1..6).map { |number| format("P13-SRV-%03d", number) } +
    %w[P13-GATE-001]
  ).freeze

  FINAL_REVIEW_FILES = {
    "correctness" => "docs/reviews/P13/final-correctness.md",
    "risk" => "docs/reviews/P13/final-risk.md",
    "test-oracle" => "docs/reviews/P13/final-test-oracle.md",
    "reproducibility" => "docs/reviews/P13/final-reproducibility.md",
    "runtime-adversarial" => "docs/reviews/P13/final-runtime-adversarial.md",
    "requirements" => "docs/reviews/P13/final-requirements.md",
    "linguistics" => "docs/reviews/P13/final-linguistics.md"
  }.freeze

  EXPECTED_POLICY_CELLS = [
    %w[ha:broadcast ha:broadcast Sensitive BROADCAST PARTIAL CONFIRM],
    %w[ha:timer_control ha:cancel_all_timers Sensitive AREA PARTIAL CONFIRM],
    %w[ha:timer_control ha:cancel_timer StateChange TIMER PARTIAL CONFIRM],
    %w[ha:temperature_query ha:get_temperature Observation ENTITY PARTIAL ALLOW],
    %w[ha:timer_control ha:decrease_timer StateChange TIMER_DELTA PARTIAL CONFIRM],
    %w[ha:date_query ha:get_current_date Observation ENTITY PARTIAL ALLOW],
    %w[ha:time_query ha:get_current_time Observation ENTITY PARTIAL ALLOW],
    %w[ha:state_query ha:get_state Observation ENTITY PARTIAL ALLOW],
    %w[ha:timer_control ha:increase_timer StateChange TIMER_DELTA PARTIAL CONFIRM],
    %w[ha:conversation_control ha:nevermind LocalControl PENDING_ACTION PARTIAL ALLOW],
    %w[ha:timer_control ha:pause_timer StateChange TIMER PARTIAL CONFIRM],
    %w[ha:response ha:respond LocalControl RESPONSE_TEXT PARTIAL ALLOW],
    %w[ha:cover_control ha:set_position StateChange POSITION PARTIAL CONFIRM],
    %w[ha:timer_control ha:start_timer StateChange START_TIMER PARTIAL CONFIRM],
    %w[ha:cover_control ha:stop_moving StateChange ENTITY PARTIAL CONFIRM],
    %w[ha:timer_query ha:timer_status Observation TIMER PARTIAL ALLOW],
    %w[ha:fan_control ha:toggle StateChange ENTITY PARTIAL CONFIRM],
    %w[ha:switch_control ha:turn_off StateChange ENTITY PARTIAL CONFIRM],
    %w[ha:light_control ha:turn_on StateChange ENTITY PARTIAL_OR_ATOMIC CONFIRM],
    %w[ha:timer_control ha:unpause_timer StateChange TIMER PARTIAL CONFIRM],
    %w[ha:timer_control ha:timer_status Observation TIMER PARTIAL ALLOW]
  ].freeze

  POLICY_TESTS = {
    "exhaustive policy matrix" =>
      /fn standard_matrix_is_exact_exhaustive_and_evaluable\s*\(/,
    "generated operation cell" =>
      /fn ordered_timer_graph_uses_the_generated_policy_cell\s*\(/,
    "malformed policy rejection" =>
      /fn configuration_rejects_malformed_duplicate_incomplete_unknown_and_unsafe_rows\s*\(/,
    "whole-graph denial" =>
      /fn evaluation_denies_the_complete_graph_and_every_invalid_contract\s*\(/,
    "one-time non-authorizing confirmation" =>
      /fn confirmation_consumes_once_and_returns_only_non_authorizing_acceptance\s*\(/,
    "stored exact plan" =>
      /fn stored_confirmation_returns_the_original_evaluated_plan_and_acceptance\s*\(/,
    "stale confirmation instance" =>
      /fn stale_confirmation_id_cannot_accept_a_same_session_replacement\s*\(/,
    "successor confirmation sequence" =>
      /fn successor_engine_inherits_one_monotonic_confirmation_sequence\s*\(/,
    "concurrent successor confirmation sequence" =>
      /fn shared_confirmation_sequence_is_monotonic_under_predecessor_successor_race\s*\(/,
    "fresh-engine confirmation collision" =>
      /fn fresh_engine_id_collision_rejects_a_different_addressed_plan\s*\(/,
    "unknown-session isolation" =>
      /fn unknown_stored_confirmation_session_preserves_unrelated_entries\s*\(/,
    "stored generation substitution" =>
      /fn stored_confirmation_expiry_and_generation_substitutions_are_terminal\s*\(/,
    "stored cancellation reload rollback" =>
      /fn stored_confirmation_cancel_reload_and_rollback_are_terminal\s*\(/,
    "stored concurrent consumption" =>
      /fn concurrent_stored_confirmation_consumption_accepts_at_most_once\s*\(/,
    "all confirmation substitutions" =>
      /fn every_confirmation_binding_substitution_is_terminal\s*\(/,
    "source-backed confirmation substitution" =>
      /fn confirmation_rejects_source_text_substitution_with_equal_canonical_offsets\s*\(/,
    "confirmation bounds" =>
      /fn confirmation_limits_expiry_cancel_reload_and_rollback_are_terminal\s*\(/,
    "capacity and deadline failure" =>
      /fn capacity_deadline_and_re_evaluation_fail_closed\s*\(/,
    "concurrent double consumption" =>
      /fn concurrent_double_consumption_accepts_at_most_once\s*\(/,
    "policy privacy" =>
      /fn debug_display_and_errors_do_not_expose_private_inputs\s*\(/
  }.freeze

  PROTOCOL_TESTS = {
    "five request fixtures" =>
      /fn canonical_request_fixtures_cover_every_closed_variant\s*\(/,
    "nine response fixtures" =>
      /fn canonical_response_fixtures_cover_every_closed_variant\s*\(/,
    "complete composed plan" =>
      /fn round_trips_every_composed_plan_field_without_semantic_loss\s*\(/,
    "exact source-bound plan outcomes" =>
      /fn rejects_equal_length_source_substitution_for_every_plan_outcome\s*\(/,
    "hostile request fields" =>
      /fn rejects_unknown_duplicate_escaped_duplicate_missing_and_prohibited_request_fields\s*\(/,
    "hostile response fields" =>
      /fn rejects_unknown_duplicate_and_escaped_duplicate_response_fields_at_every_layer\s*\(/,
    "version UTF-8 and trailing rejection" =>
      /fn rejects_bad_versions_tags_utf8_trailing_input_and_opaque_ids\s*\(/,
    "bounded version probe" =>
      /fn request_version_probe_is_structural_bounded_and_closed\s*\(/,
    "wire string number depth limits" =>
      /fn enforces_v2_wire_string_number_and_depth_limits\s*\(/,
    "bounded diagnostics" =>
      /fn diagnostics_are_closed_canonical_bounded_and_use_fixed_limits\s*\(/,
    "clarification bound" =>
      /fn entity_clarification_is_typed_generation_bound_and_limited_to_sixteen\s*\(/,
    "invalid graph rejection" =>
      /fn rejects_invalid_spans_graphs_and_incompatible_response_constants\s*\(/,
    "core collection limits" =>
      /fn enforces_every_core_collection_limit_before_accepting_a_graph\s*\(/,
    "composed-plan invariants" =>
      /fn rejects_dangling_or_incomplete_composed_plan_semantics\s*\(/,
    "closed enum round trips" =>
      /fn round_trips_every_closed_policy_health_and_diagnostic_enum_value\s*\(/,
    "non-executable semantics" =>
      /fn round_trips_non_executable_negated_evidence\s*\(/,
    "bounded protocol errors" =>
      /fn protocol_errors_are_bounded_closed_and_use_v2_limits\s*\(/,
    "hostile-input redaction" =>
      /fn errors_debug_and_wire_output_never_echo_hostile_or_residential_text\s*\(/,
    "fixed hostile fuzz and exhaustion corpus" =>
      /fn fixed_hostile_byte_and_structural_corpus_is_bounded_and_panic_free\s*\(/,
    "v1 exact bytes" =>
      /fn v1_fixture_bytes_are_frozen_exactly\s*\(/,
    "v1 exact hashes" =>
      /fn v1_source_schema_and_fixture_sha256_values_are_frozen\s*\(/
  }.freeze

  SERVER_TESTS = {
    "environment allowlist" =>
      /fn environment_is_an_exact_value_allowlist_and_retains_no_values\s*\(/,
    "configuration bounds" => /fn configuration_limits_are_exact\s*\(/,
    "socket path bound" => /fn socket_path_is_absolute_and_bounded\s*\(/,
    "fragmented and coalesced frames" =>
      /fn fragmented_reads_and_coalesced_frames_are_bounded\s*\(/,
    "pre-allocation frame bound" =>
      /fn frame_boundaries_reject_before_payload_allocation\s*\(/,
    "truncated framing" => /fn truncated_header_and_payload_fail_closed\s*\(/,
    "bounded health" => /fn health_contains_only_closed_bounded_metadata\s*\(/,
    "owner-only fragmented local listener and outbound canary" =>
      /fn binds_one_owner_only_unix_listener_serves_fragmented_frames_and_stays_outbound_free\s*\(/,
    "live environment rejection" =>
      /fn bind_rejects_the_actual_process_environment_when_a_canary_is_present\s*\(/,
    "admitted overrun fatal containment" =>
      /fn admitted_handler_overrun_exits_the_dedicated_process_without_late_mutation\s*\(/,
    "shutdown fatal containment" =>
      /fn blocked_handler_shutdown_exits_the_dedicated_process_without_late_mutation\s*\(/,
    "handler panic fatal containment" =>
      /fn handler_panic_exits_the_dedicated_process_and_retains_its_socket\s*\(/,
    "monitor admitted-state discrimination" =>
      /fn request_monitor_expires_only_an_admitted_active_request\s*\(/,
    "queued timeout state isolation" =>
      /fn queued_request_timeout_skips_state_mutation_after_worker_drains\s*\(/,
    "absolute fragmented frame deadline" =>
      /fn slow_fragmented_frame_obeys_one_absolute_deadline\s*\(/,
    "request storage erasure" =>
      /fn request_storage_is_explicitly_erased_after_handling\s*\(/,
    "occupied socket path" =>
      /fn occupied_paths_are_never_removed_or_replaced\s*\(/,
    "race-free socket retention" =>
      /fn socket_retirement_never_removes_a_replacement_path\s*\(/,
    "private socket parent" => /fn shared_socket_parent_is_rejected\s*\(/,
    "failed reload retention" =>
      /fn invalid_replacement_retains_the_prior_snapshot\s*\(/,
    "retained snapshot invalidation" =>
      /fn retained_lease_is_invalidated_before_complete_generation_exchange\s*\(/,
    "concurrent atomic reload" =>
      /fn competing_reload_is_atomic_under_real_concurrency\s*\(/,
    "real v1/v2 policy dispatch" =>
      /fn v2_interpret_confirm_replay_health_and_v1_share_the_plan_semantics\s*\(/,
    "stale wire confirmation instance" =>
      /fn stale_confirmation_prompt_cannot_accept_a_same_session_replacement\s*\(/,
    "stale pre-reload confirmation instance" =>
      /fn stale_pre_reload_prompt_cannot_confirm_a_post_reload_plan\s*\(/,
    "credential state non-retention" =>
      /fn credential_canary_is_rejected_without_runtime_state_retention\s*\(/,
    "engine-owned continuation dispatch" =>
      /fn continuation_uses_only_the_addressed_engine_state_and_selection\s*\(/,
    "cross-engine cancellation" =>
      /fn cancellation_removes_pending_continuations_and_confirmations\s*\(/,
    "closed malformed dispatch" =>
      /fn malformed_requests_are_closed_and_snapshot_substitution_fails_before_dispatch\s*\(/,
    "deterministic runtime bytes" =>
      /fn fresh_runtimes_replay_identical_wire_bytes_for_identical_explicit_inputs\s*\(/,
    "cross-engine rollback invalidation" =>
      /fn clock_rollback_invalidates_both_session_and_confirmation_state\s*\(/
  }.freeze

  EXPECTED_TEST_SLOT_SCHEMAS = {
    "EXPECTED_ENTITY_SLOTS" => [["ha:entity", "Entity"]],
    "EXPECTED_TIMER_SLOTS" => [["ha:timer", "Entity"]],
    "EXPECTED_AREA_SLOTS" => [["ha:area", "EvidenceText"]],
    "EXPECTED_PENDING_ACTION_SLOTS" => [["ha:pending_action", "EvidenceText"]],
    "EXPECTED_RESPONSE_TEXT_SLOTS" => [["ha:response_text", "EvidenceText"]],
    "EXPECTED_BROADCAST_SLOTS" => [
      ["ha:entity", "Entity"],
      ["ha:message", "EvidenceText"]
    ],
    "EXPECTED_POSITION_SLOTS" => [
      ["ha:entity", "Entity"],
      ["ha:position", "Integer"]
    ],
    "EXPECTED_START_TIMER_SLOTS" => [
      ["ha:duration_seconds", "Integer"],
      ["ha:timer", "Entity"]
    ],
    "EXPECTED_TIMER_DELTA_SLOTS" => [
      ["ha:duration_delta_seconds", "Integer"],
      ["ha:timer", "Entity"]
    ]
  }.freeze

  TEST_BODY_EVIDENCE = {
    "policy" => {
      "standard_matrix_is_exact_exhaustive_and_evaluable" => [
        /assert_eq!\s*\(\s*descriptor\.capability\(\)\.as_str\(\),\s*\*capability\s*\)/
      ],
      "confirmation_rejects_source_text_substitution_with_equal_canonical_offsets" => [
        /assert_ne!\s*\(\s*original,\s*substituted\s*\)/,
        /ConfirmationRejectionReason::BindingMismatch/
      ]
    },
    "protocol" => {
      "round_trips_every_composed_plan_field_without_semantic_loss" => [
        /assert_eq!\s*\(/,
        /decode_response\s*\(/
      ]
    },
    "server" => {
      "invalid_replacement_retains_the_prior_snapshot" => [
        /ServerErrorCode::RuntimeState/,
        /Arc::ptr_eq\s*\(/
      ],
      "binds_one_owner_only_unix_listener_serves_fragmented_frames_and_stays_outbound_free" => [
        /outbound_canary\s*\.local_addr\s*\(\)/,
        /FIXTURE_TECNICA_A_\{outbound_address\}/,
        /write_all\s*\(\s*&header\[\.\.1\]\s*\)/,
        /outbound_canary\s*\.accept\s*\(\).*expect_err/m
      ],
      "admitted_handler_overrun_exits_the_dedicated_process_without_late_mutation" => [
        /admitted_handler_overrun_fatal_child/,
        /assert_eq!\s*\(result\.exit_code,\s*Some\(FATAL_HANDLER_EXIT_CODE\)\)/,
        /!result\.marker_was_written/
      ],
      "blocked_handler_shutdown_exits_the_dedicated_process_without_late_mutation" => [
        /blocked_handler_shutdown_fatal_child/,
        /assert_eq!\s*\(result\.exit_code,\s*Some\(FATAL_HANDLER_EXIT_CODE\)\)/,
        /!result\.marker_was_written/,
        /result\.socket_was_retained/
      ],
      "handler_panic_exits_the_dedicated_process_and_retains_its_socket" => [
        /handler_panic_fatal_child/,
        /assert_eq!\s*\(result\.exit_code,\s*Some\(FATAL_HANDLER_EXIT_CODE\)\)/,
        /result\.socket_was_retained/
      ],
      "request_monitor_expires_only_an_admitted_active_request" => [
        /completed\.try_complete\(\)/,
        /!monitor_requires_fatal\(\s*&completed_slot/m,
        /admitted_slot\.finished\s*=\s*true/,
        /monitor_requires_fatal\(&admitted_slot,\s*Instant::now\(\)\)/,
        /monitor_requires_fatal\(&admitted_slot,\s*admitted\.deadline\)/
      ],
      "queued_request_timeout_skips_state_mutation_after_worker_drains" => [
        /Barrier::new\s*\(\s*2\s*\)/,
        /FIXTURE_TECNICA_BLOCKER/,
        /FIXTURE_TECNICA_MUTATE/,
        /ServerErrorCode::RequestTimeout/,
        /FIXTURE_TECNICA_DRAIN/,
        /assert!\s*\(\s*!snapshot\.state\(\)\.mutated\.load\(Ordering::Acquire\)\s*\)/,
        /worker\.join\s*\(/
      ],
      "bind_rejects_the_actual_process_environment_when_a_canary_is_present" => [
        /FIXTURE_TECNICA_TOKEN/,
        /ServerErrorCode::UnsanitizedEnvironment/
      ],
      "clock_rollback_invalidates_both_session_and_confirmation_state" => [
        /malformed_rollback/,
        /v1_rollback/,
        /unsupported_version_rollback/,
        /LogicalTime::from_ticks\(9\)/,
        /DiagnosticCode::ConfirmationUnavailable/,
        /DiagnosticCode::SessionUnavailable/
      ],
      "v2_interpret_confirm_replay_health_and_v1_share_the_plan_semantics" => [
        /v1::decode_outcome\s*\(/,
        /v1::Outcome::Abstention\(nlu_core::AbstentionReason::Unsupported\)/
      ],
      "credential_canary_is_rejected_without_runtime_state_retention" => [
        /let make_canary\s*=/,
        /UnixServer::bind\s*\(/,
        /write_frame\s*\(\s*&mut client,\s*&request\s*\)/,
        /request\.fill\s*\(\s*0\s*\)/,
        /pending_state_counts\s*\(\s*\)/
      ]
    }
  }.freeze

  CODE_ONLY_TEST_BODY_EVIDENCE = {
    "policy" => {
      "concurrent_stored_confirmation_consumption_accepts_at_most_once" => [
        /Barrier::new\s*\(\s*3\s*\)/,
        /for _ in 0\.\.2/,
        /thread::spawn\s*\(/,
        /\.confirm_stored\s*\(\s*&session,\s*confirmation_id,/m,
        /StoredConfirmationOutcome::Accepted\(_\).*?\.count\(\),\s*1/m,
        /StoredConfirmationOutcome::Rejected\(_\).*?\.count\(\),\s*1/m,
        /\.pending_confirmations\(\),\s*0/m
      ],
      "stale_confirmation_id_cannot_accept_a_same_session_replacement" => [
        /assert_ne!\s*\(\s*stale_id,\s*replacement_id\s*\)/,
        /\.confirm_stored\s*\(\s*&addressed,\s*stale_id,/m,
        /ConfirmationRejectionReason::BindingMismatch/,
        /\.confirm_stored\s*\(\s*&addressed,\s*replacement_id,/m,
        /ConfirmationRejectionReason::Unavailable/
      ],
      "successor_engine_inherits_one_monotonic_confirmation_sequence" => [
        /\.inherit_confirmation_sequence\s*\(\s*&predecessor\s*\)/,
        /assert!\s*\(\s*successor_id\s*>\s*predecessor_id\s*\)/,
        /\.expect_err\s*\(/,
        /PolicyErrorCode::PlanContract/
      ],
      "shared_confirmation_sequence_is_monotonic_under_predecessor_successor_race" => [
        /Barrier::new\s*\(\s*3\s*\)/,
        /Arc::clone\s*\(\s*&predecessor\s*\)/,
        /Arc::clone\s*\(\s*&successor\s*\)/,
        /thread::spawn\s*\(/,
        /assert_eq!\s*\(\s*issued,\s*vec!\[1,\s*2\]\s*\)/,
        /assert_eq!\s*\(\s*next\.get\(\),\s*3\s*\)/
      ],
      "fresh_engine_id_collision_rejects_a_different_addressed_plan" => [
        /let stale_engine = test_engine\s*\(/,
        /let current_engine = test_engine\s*\(/,
        /assert_eq!\s*\(\s*stale_id,\s*current_id\s*\)/,
        /\.confirm_stored\s*\(\s*&addressed,\s*stale_id,\s*&stale_plan,/m,
        /ConfirmationRejectionReason::BindingMismatch/,
        /ConfirmationRejectionReason::Unavailable/
      ]
    },
    "protocol" => {
      "fixed_hostile_byte_and_structural_corpus_is_bounded_and_panic_free" => [
        /for byte in 0_u8\.\.=u8::MAX/,
        /for end in 0\.\.=valid\.len\(\)/,
        /for index in 0\.\.valid\.len\(\)/,
        /v2::MAX_WIRE_BYTES\s*\+\s*1/,
        /Err\s*\(\s*ProtocolError::InputTooLarge\s*\)/,
        /v2::MAX_NESTING_DEPTH\s*-\s*1/,
        /Err\s*\(\s*ProtocolError::NestingTooDeep\s*\)/
      ],
      "rejects_equal_length_source_substitution_for_every_plan_outcome" => [
        /Outcome::CompletePlan\s*\(/,
        /Outcome::ConfirmationRequired\s*\(/,
        /Outcome::PolicyAccepted\s*\(/,
        /v2::decode_response\s*\(\s*&encoded,\s*&substituted\s*\)/m,
        /Err\s*\(\s*ProtocolError::InvalidOutcome\s*\)/,
        /Request::Confirm\s*\{.*plan,/m
      ]
    },
    "server" => {
      "retained_lease_is_invalidated_before_complete_generation_exchange" => [
        /\.replace_at\s*\(/,
        /\.invalidated\.load\s*\(\s*Ordering::Acquire\s*\)/,
        /\.ensure_active\s*\(\)/,
        /ServerErrorCode::RuntimeState/
      ],
      "stale_confirmation_prompt_cannot_accept_a_same_session_replacement" => [
        /assert_ne!\s*\(\s*stale_id,\s*replacement_id\s*\)/,
        /confirmation_id:\s*stale_id/,
        /DiagnosticCode::PolicyDenied/,
        /confirmation_id:\s*replacement_id/,
        /DiagnosticCode::ConfirmationUnavailable/
      ],
      "stale_pre_reload_prompt_cannot_confirm_a_post_reload_plan" => [
        /SnapshotStore::new/,
        /\.replace_at\s*\(/,
        /assert_ne!\s*\(\s*stale_id,\s*replacement_id\s*\)/,
        /confirmation_id:\s*stale_id/,
        /DiagnosticCode::PolicyDenied/,
        /confirmation_id:\s*replacement_id/,
        /DiagnosticCode::ConfirmationUnavailable/
      ],
      "credential_canary_is_rejected_without_runtime_state_retention" => [
        /ProtocolError::MalformedJson/,
        /String::from_utf8_lossy\s*\(\s*&response\s*\).*?\.contains\s*\(\s*&canary\s*\)/m,
        /runtime\.state\(\).*?\.contains\s*\(\s*&canary\s*\)/m,
        /request\.fill\s*\(\s*0\s*\)/,
        /pending_state_counts\s*\(\s*\).*?before/m,
        /Outcome::Health\(_\)/
      ],
      "slow_fragmented_frame_obeys_one_absolute_deadline" => [
        /ServerConfig::with_limits\s*\([^;]*100\s*\)/m,
        /thread::sleep\s*\(\s*Duration::from_millis\(35\)\s*\)/,
        /ServerErrorCode::FrameIo/,
        /started\.elapsed\(\)\s*<\s*Duration::from_millis\(250\)/
      ],
      "request_storage_is_explicitly_erased_after_handling" => [
        /RequestBytes::with_erase_audit\s*\(/,
        /response_receiver\s*\.recv\s*\(\s*\)/m,
        /vec!\[0;\s*canary\.len\(\)\]/
      ]
    }
  }.freeze

  EXTERNAL_GATES = {
    "tools/p13-evidence" => %w[
      P13_EXACT_SOURCE_COMPATIBILITY_PASS
      P13_LOCAL_RUNTIME_PASS
      P13_TRANSPORT_PORTFOLIO_REJECTED
    ],
    "tools/p13-noise-evidence" => %w[
      P13_NOISE_SOURCE_EVIDENCE_PASS
      P13_NOISE_PROJECTION_PASS
      P13_NOISE_ADVISORY_PASS
      P13_NOISE_PROBE_TEST_PASS
      P13_NOISE_PROBE_CLIPPY_PASS
      P13_NOISE_CAPABILITY_ONLY_PASS
    ],
    "tools/p13-transport-probe" => %w[
      P13_TRANSPORT_PROBE_PASS
      P13_SECRET_MEMORY_CONDITIONAL
    ]
  }.freeze

  INHERITED_GATES = {
    "tools/validate-p01" => [%w[--no-cargo], "P01_GATE_PASS"],
    "tools/validate-p02" => [[], "P02_VALIDATION_PASS"],
    "tools/validate-p04" => [%w[--no-cargo], "P04_GATE_PASS"],
    "tools/validate-p05" => [%w[--no-cargo], "P05_GATE_PASS"],
    "tools/validate-p06" => [%w[--no-cargo], "P06_GATE_PASS"],
    "tools/validate-p07" => [%w[--no-cargo --no-evaluator], "P07_GATE_PASS"],
    "tools/validate-p08" => [%w[--no-cargo], "P08_GATE_PASS"],
    "tools/validate-p09" => [%w[--no-cargo --no-reproduction], "P09_GATE_PASS"],
    "tools/validate-p10" => [%w[--no-cargo], "P10_GATE_PASS"],
    "tools/validate-p11" => [%w[--no-cargo], "P11_GATE_PASS"],
    "tools/validate-p12" => [%w[--no-cargo], "P12_GATE_PASS"]
  }.freeze

  CRITICAL_TESTS = [
    %w[
      policy-engine
      policy_contract
      fresh_engine_id_collision_rejects_a_different_addressed_plan
    ],
    %w[
      policy-engine
      policy_contract
      shared_confirmation_sequence_is_monotonic_under_predecessor_successor_race
    ],
    %w[
      policy-engine
      policy_contract
      confirmation_rejects_source_text_substitution_with_equal_canonical_offsets
    ],
    %w[
      protocol
      v2_wire_contract
      rejects_equal_length_source_substitution_for_every_plan_outcome
    ],
    [
      "nlu-server",
      nil,
      "server::tests::slow_fragmented_frame_obeys_one_absolute_deadline"
    ],
    [
      "nlu-server",
      nil,
      "server::tests::request_storage_is_explicitly_erased_after_handling"
    ],
    %w[
      nlu-server
      runtime_contract
      credential_canary_is_rejected_without_runtime_state_retention
    ]
  ].freeze

  EXPECTED_LOCK_CLOSURE = %w[
    ha-catalog
    intent-engine
    itoa
    lang-ptbr
    memchr
    nlu-core
    nlu-data
    nlu-server
    plan-engine
    policy-engine
    proc-macro2
    protocol
    quote
    ryu
    serde
    serde_core
    serde_derive
    serde_json
    session-engine
    syn
    tinyvec
    tinyvec_macros
    unicode-ident
    unicode-normalization
    unicode-segmentation
  ].freeze

  module_function

  def run(arguments)
    options = parse_arguments(arguments)
    review_candidate = options.fetch(:review_candidate)

    validate(
      ROOT,
      run_cargo: false,
      require_satisfied: !review_candidate,
      external_mode: :required
    )
    puts(review_candidate ? "P13_REVIEW_CANDIDATE_PASS" : "P13_GATE_PASS")
  rescue Failure => error
    warn "P13_GATE_FAIL: #{error.message}"
    exit 1
  end

  def parse_arguments(arguments)
    remaining = arguments.dup
    no_cargo = remaining.delete("--no-cargo")
    review_candidate = remaining.delete("--review-candidate")
    unless remaining.empty?
      raise Failure,
            "usage: tools/validate-p13 --no-cargo [--review-candidate]"
    end
    raise Failure, "P13 Cargo execution is prohibited; --no-cargo is required" unless
      no_cargo

    {review_candidate: !review_candidate.nil?}
  end

  def validate(root, run_cargo:, require_satisfied:, external_mode: :required)
    raise Failure, "P13 Cargo execution is prohibited" if run_cargo

    validate_inventory(root)
    validate_dependencies(root)
    validate_v1_freeze(root)

    policy = production_files(root, POLICY_FILES)
    server = production_files(root, SERVER_FILES)
    protocol = production_files(root, PROTOCOL_FILES)
    validate_policy_contract(
      policy.fetch("crates/policy-engine/src/table.rs"),
      policy.fetch("crates/policy-engine/src/engine.rs"),
      policy.fetch("crates/policy-engine/src/lib.rs")
    )
    validate_protocol_contract(
      protocol.fetch("crates/protocol/src/lib.rs"),
      protocol.fetch("crates/protocol/src/preflight.rs"),
      protocol.fetch("crates/protocol/src/v2.rs"),
      File.binread(File.join(root, "schemas/protocol-v2-request.schema.json")),
      File.binread(File.join(root, "schemas/protocol-v2-response.schema.json"))
    )
    validate_server_contract(
      server.fetch("crates/nlu-server/src/config.rs"),
      server.fetch("crates/nlu-server/src/framing.rs"),
      server.fetch("crates/nlu-server/src/health.rs"),
      server.fetch("crates/nlu-server/src/server.rs"),
      server.fetch("crates/nlu-server/src/snapshot.rs"),
      server.fetch("crates/nlu-server/src/runtime.rs")
    )
    validate_engine_owned_integration(
      File.binread(File.join(root, "crates/session-engine/src/store.rs")),
      policy.fetch("crates/policy-engine/src/engine.rs"),
      server.fetch("crates/nlu-server/src/runtime.rs")
    )
    validate_network_and_privacy(root, policy, protocol, server)
    validate_test_contracts(
      policy.fetch("crates/policy-engine/tests/policy_contract.rs"),
      protocol_test_bytes(protocol),
      server_test_bytes(server)
    )
    validate_requirements(root, require_satisfied: require_satisfied)
    validate_cargo_command_contract(cargo_commands)
    run_external_gates(root, allow_missing: external_mode == :unit) if
      external_mode == :required
    true
  rescue Errno::ENOENT, Errno::EISDIR => error
    raise Failure, "P13 required file is missing or unreadable: #{error.message}"
  end

  def validate_inventory(root)
    {
      "policy-engine inventory" => POLICY_FILES,
      "nlu-server inventory" => SERVER_FILES,
      "protocol inventory" => PROTOCOL_FILES
    }.each do |context, expected|
      base = expected.fetch(0).split("/")[0, 2].join("/")
      validate_inventory_paths(inventory(root, base), expected, context)
      validate_regular_files(root, expected, context)
    end
    validate_regular_files(root, SCHEMA_FILES, "protocol schema inventory")
    true
  end

  def inventory(root, relative)
    base = File.join(root, relative)
    return [] unless Dir.exist?(base)

    Dir.glob(File.join(base, "**", "*"), File::FNM_DOTMATCH)
      .select { |path| File.file?(path) || File.symlink?(path) }
      .map { |path| path.delete_prefix("#{root}/") }
      .sort
  end

  def validate_inventory_paths(actual, expected, context)
    raise Failure, "#{context} differs" unless actual.sort == expected.sort

    true
  end

  def validate_regular_files(root, paths, context)
    paths.each do |relative|
      path = File.join(root, relative)
      raise Failure, "#{context} contains a symlink: #{relative}" if File.symlink?(path)
      raise Failure, "#{context} entry is not a regular file: #{relative}" unless File.file?(path)
    end
    true
  end

  def production_files(root, paths)
    paths.to_h do |relative|
      [relative, File.binread(File.join(root, relative))]
    end
  end

  def validate_dependencies(root)
    workspace = File.binread(File.join(root, "Cargo.toml"))
    %w[policy-engine nlu-server].each do |package|
      member = "\"crates/#{package}\""
      raise Failure, "#{package} workspace registration differs" unless
        workspace.scan(member).length == 1
    end

    manifests = Dir[File.join(root, "crates/*/Cargo.toml")].sort.to_h do |path|
      bytes = File.binread(path)
      [manifest_package_name(bytes), bytes]
    end
    validate_dependency_bytes(
      workspace,
      manifests,
      File.binread(File.join(root, "Cargo.lock"))
    )
  end

  def validate_dependency_bytes(workspace, manifests, lock_bytes)
    release_profile = workspace[
      /^\[profile\.release\]\s*\n(.*?)(?=^\[|\z)/m,
      1
    ]
    raise Failure, "release panic strategy must unwind" unless
      release_profile&.scan(/^panic = "unwind"$/)&.length == 1 &&
      workspace.scan(/^panic = "([^"]+)"$/).flatten == ["unwind"]

    expected = {
      "policy-engine" => %w[nlu-core session-engine],
      "protocol" => %w[nlu-core serde serde_json],
      "nlu-server" => %w[
        ha-catalog
        intent-engine
        nlu-core
        plan-engine
        policy-engine
        protocol
        session-engine
      ]
    }
    expected.each do |package, dependencies|
      manifest = manifests.fetch(package) do
        raise Failure, "manifest is missing: #{package}"
      end
      actual = manifest_dependencies(manifest, "dependencies")
      raise Failure, "#{package} production dependency set differs" unless
        actual == dependencies.sort
      unsupported = dependency_sections(manifest) - %w[dependencies dev-dependencies]
      raise Failure, "#{package} has unsupported dependency sections" unless
        unsupported.empty?
      raise Failure, "#{package} defines a build script" if
        manifest.match?(/^build\s*=/) || manifest.match?(/^links\s*=/)
    end

    lower = %w[
      ha-catalog
      intent-engine
      lang-ptbr
      nlu-core
      plan-engine
      policy-engine
      session-engine
    ]
    lower.each do |package|
      dependencies = manifest_dependencies(manifests.fetch(package), "dependencies")
      if dependencies.any? { |name| %w[nlu-server protocol].include?(name) }
        raise Failure, "dependency direction is inverted: #{package}"
      end
    end
    manifests.each do |package, manifest|
      next if package == "nlu-server"

      if manifest_dependencies(manifest, "dependencies").include?("nlu-server")
        raise Failure, "only nlu-server may depend on nlu-server: #{package}"
      end
    end

    packages = parse_lock_packages(lock_bytes)
    closure = lock_closure(packages, "nlu-server")
    raise Failure, "nlu-server locked dependency closure differs" unless
      closure.sort == EXPECTED_LOCK_CLOSURE
    forbidden = closure.grep(
      /(?:reqwest|hyper|tokio|mio|socket2|curl|openssl|rustls|native-tls|ureq|websocket|quinn|tonic|tracing|metrics|opentelemetry)/i
    )
    raise Failure, "network-capable dependency in nlu-server closure: #{forbidden.join(', ')}" unless
      forbidden.empty?
    true
  end

  def manifest_package_name(bytes)
    name = bytes[/^name = "([^"]+)"$/, 1]
    raise Failure, "manifest package identity is missing" unless name

    name
  end

  def dependency_sections(bytes)
    bytes.scan(/^\[([^\]]*dependencies[^\]]*)\]$/).flatten
  end

  def manifest_dependencies(bytes, section)
    body = bytes[/^\[#{Regexp.escape(section)}\]\s*\n(.*?)(?=^\[|\z)/m, 1]
    return [] unless body

    body.lines.each_with_object([]) do |line, dependencies|
      stripped = line.sub(/#.*/, "").strip
      next if stripped.empty?

      name = stripped.split("=", 2).fetch(0).strip.sub(/\.workspace\z/, "")
      dependencies << name
    end.sort
  end

  def parse_lock_packages(bytes)
    packages = {}
    bytes.split(/^\[\[package\]\]\s*$/).drop(1).each do |body|
      name = body[/^name = "([^"]+)"$/, 1]
      next unless name

      dependencies = []
      dependency_body = body[/^dependencies = \[\s*\n(.*?)^\]$/m, 1]
      if dependency_body
        dependency_body.scan(/^\s*"([^"]+)"/).flatten.each do |entry|
          dependencies << entry.split(" ", 2).fetch(0)
        end
      end
      raise Failure, "duplicate Cargo.lock package name: #{name}" if packages.key?(name)

      packages[name] = dependencies.sort
    end
    packages
  end

  def lock_closure(packages, root)
    raise Failure, "Cargo.lock root package is missing: #{root}" unless packages.key?(root)

    pending = [root]
    seen = {}
    until pending.empty?
      package = pending.pop
      next if seen[package]

      raise Failure, "Cargo.lock dependency is missing: #{package}" unless packages.key?(package)

      seen[package] = true
      pending.concat(packages.fetch(package))
    end
    seen.keys.sort
  end

  def validate_v1_freeze(root)
    V1_HASHES.each do |relative, expected|
      actual = Digest::SHA256.file(File.join(root, relative)).hexdigest
      raise Failure, "protocol v1 bytes changed: #{relative}" unless actual == expected
    end
    true
  end

  def validate_v1_hash_bytes(subjects)
    V1_HASHES.each do |relative, expected|
      bytes = subjects.fetch(relative)
      raise Failure, "protocol v1 bytes changed: #{relative}" unless
        Digest::SHA256.hexdigest(bytes) == expected
    end
    true
  end

  def validate_policy_contract(table, engine, library)
    raise Failure, "policy-engine must forbid unsafe code" unless
      library.start_with?("#![forbid(unsafe_code)]\n")
    raise Failure, "policy plan-operation count differs" unless
      integer_constant(table, "PLAN_OPERATION_COUNT") == 20
    raise Failure, "policy descriptor count differs" unless
      integer_constant(table, "STANDARD_DESCRIPTOR_COUNT") == 21
    raise Failure, "pending-confirmation capacity differs" unless
      integer_constant(engine, "MAX_PENDING_CONFIRMATIONS") == 64
    raise Failure, "confirmation TTL differs" unless
      integer_constant(engine, "MAX_TTL_TICKS") == 300_000

    required_table = {
      "immutable generation-tagged table" =>
        /pub struct PolicyTable\s*\{[^}]*generation:\s*PolicyGeneration,[^}]*descriptors:\s*BTreeMap<\s*\(CapabilityId,\s*OperationId\),\s*PolicyDescriptor\s*>/m,
      "duplicate descriptor rejection" => /accepted\.contains_key\s*\(\s*&key\s*\)/,
      "unknown descriptor rejection" => /PolicyErrorCode::UnknownDescriptor/,
      "incomplete descriptor rejection" => /PolicyErrorCode::IncompleteConfiguration/,
      "no-more-permissive rule" => /disposition_is_no_more_permissive/,
      "missing-key lookup" =>
        /\.get\s*\(\s*&\(capability\.clone\(\),\s*operation\.clone\(\)\)\s*\)/
    }
    required_table.each do |name, pattern|
      raise Failure, "policy table lacks #{name}" unless table.match?(pattern)
    end
    validate_policy_cells(table)

    required_engine = {
      "deterministic confirmation map" =>
        /confirmations:\s*BTreeMap<SessionId,\s*Box<PendingConfirmation>>/,
      "synchronized confirmation state" => /state:\s*Mutex<ConfirmationState>/,
      "stored exact plan" => /plan:\s*ComposedPlan/,
      "stored confirmation instance" => /confirmation_id:\s*ConfirmationId/,
      "stored canonical plan" => /canonical_plan:\s*Vec<u8>/,
      "stored capabilities" => /capabilities:\s*Vec<CapabilityId>/,
      "checked deadline" => /\.checked_add\s*\(/,
      "exact deadline expiry" => /now\s*>=\s*pending\.deadline/,
      "missing rule denies" =>
        /return Evaluation::Denied\(PolicyDenialReason::MissingRule\)/,
      "explicit deny denies whole graph" =>
        /PolicyDisposition::Deny\s*=>\s*\{\s*return Evaluation::Denied\(PolicyDenialReason::ExplicitDeny\)/m,
      "non-executable denial" =>
        /GraphExecutionClass::NonExecutable\s*=>\s*\{\s*return Evaluation::Denied\(PolicyDenialReason::NonExecutable\)/m,
      "atomic-only denial" =>
        /GraphExecutionClass::AtomicOnly\s*=>\s*\{\s*return Evaluation::Denied\(PolicyDenialReason::AtomicOnly\)/m,
      "non-mutating assessment API" => /pub fn assess\s*\(/,
      "stored confirmation API" => /pub fn confirm_stored\s*\(/,
      "atomic confirmation sequence" => /last_issued:\s*Arc<AtomicU64>/,
      "checked monotonic confirmation instances" =>
        /\.fetch_update\(Ordering::SeqCst,\s*Ordering::SeqCst,.*value\.checked_add\(1\)/m,
      "successor sequence inheritance" =>
        /pub fn inherit_confirmation_sequence\s*\(&self,\s*predecessor:\s*&Self\)/,
      "reload invalidation" => /pub fn invalidate_for_reload\s*\(/
    }
    required_engine.each do |name, pattern|
      raise Failure, "policy engine lacks #{name}" unless engine.match?(pattern)
    end
    validate_non_authorizing_methods(engine)

    take = method_block(engine, "fn take_confirmation")
    assess = method_block(engine, "pub fn assess")
    raise Failure, "policy assessment does not evaluate the complete plan" unless
      assess.match?(/self\.evaluate_plan\(plan,\s*context\)/)
    if assess.match?(
      /begin_confirmation|discard_for_new_evaluation|take_confirmation|confirmations\.(?:insert|remove|clear)/
    )
      raise Failure, "policy assessment mutates confirmation state"
    end

    raise Failure, "public confirmation API omits the confirmation instance" if
      engine.match?(/pub fn confirm\s*\(/)
    removal = take.index("state.confirmations.remove(session)")
    evaluation = engine.index("self.evaluate_plan(&pending.plan, context)")
    confirm = engine.index("pub fn confirm_stored")
    raise Failure, "confirmation is not removed atomically before validation" unless
      removal && evaluation && confirm && confirm < evaluation
    raise Failure, "unknown confirmation clears unrelated sessions" if
      take.match?(/confirmations\.clear\s*\(/)
    stored = method_block(engine, "pub fn confirm_stored")
    raise Failure, "stored confirmation is not exact-plan addressed" unless
      stored.match?(/addressed_plan:\s*&ComposedPlan/) &&
        stored.match?(/pending\.plan\s*!=\s*\*addressed_plan/)
    true
  end

  def validate_policy_cells(table)
    body = table[
      /const STANDARD_SPECS:[^=]+=\s*\[(.*?)^\];$/m,
      1
    ]
    raise Failure, "standard policy matrix is missing" unless body

    cells = body.scan(/DescriptorSpec\s*\{(.*?)^\s*\},$/m).map do |cell|
      bytes = cell.fetch(0)
      [
        bytes[/capability:\s*"([^"]+)"/, 1],
        bytes[/operation:\s*"([^"]+)"/, 1],
        bytes[/risk:\s*RiskClass::([A-Za-z]+)/, 1],
        bytes[/slots:\s*([A-Z_]+)/, 1],
        bytes[/graph_classes:\s*([A-Z_]+)/, 1],
        bytes[/disposition:\s*([A-Z_]+)/, 1]
      ]
    end
    raise Failure, "standard policy matrix cells differ" unless
      cells == EXPECTED_POLICY_CELLS
    raise Failure, "standard policy matrix contains duplicate keys" unless
      cells.map { |cell| cell.first(2) }.uniq.length == cells.length
    true
  end

  def validate_non_authorizing_methods(bytes)
    bodies = bytes.scan(
      /pub const fn authorizes_execution\s*\([^)]*\)\s*->\s*bool\s*\{\s*([^}]*)\}/m
    ).flatten
    raise Failure, "policy outputs lack explicit non-authorizing methods" unless bodies.length == 5
    raise Failure, "a policy output can authorize execution" unless
      bodies.all? { |body| body.strip == "false" }
    fields = struct_fields(bytes, "PolicyAcceptance")
    raise Failure, "policy acceptance carries executable authority" unless
      fields.sort == %w[capability_count catalog_generation policy_generation risk]
    true
  end

  def validate_protocol_contract(library, preflight, v2, request_schema, response_schema)
    raise Failure, "protocol must forbid unsafe code" unless
      library.start_with?("#![forbid(unsafe_code)]\n")
    raise Failure, "protocol does not expose independent v1 and v2 modules" unless
      library.match?(/^pub mod v1;$/) && library.match?(/^pub mod v2;$/)
    raise Failure, "version dispatch enum differs" unless
      enum_variants(library, "RequestVersion") == %w[V1 V2]
    raise Failure, "v2 request variants differ" unless
      enum_variants(v2, "Request") == %w[Interpret Continue Confirm Cancel Health]
    expected_outcomes = %w[
      CompletePlan
      EntityClarification
      Abstention
      PolicyDenial
      ConfirmationRequired
      PolicyAccepted
      Cancellation
      Health
      ProtocolError
    ]
    raise Failure, "v2 response variants differ" unless
      enum_variants(v2, "Outcome") == expected_outcomes

    {
      "VERSION" => 2,
      "MAX_WIRE_BYTES" => 131_072,
      "MAX_DECODED_STRING_BYTES" => 16_384,
      "MAX_NESTING_DEPTH" => 32,
      "MAX_STRUCTURAL_ITEMS" => 4_096,
      "MAX_NUMERIC_TOKEN_BYTES" => 20,
      "MAX_DIAGNOSTICS" => 8,
      "SESSION_ID_BYTES" => 32
    }.each do |name, expected|
      raise Failure, "protocol v2 constant differs: #{name}" unless
        integer_constant(v2, name) == expected
    end

    composed_fields = %w[
      source
      catalog_generation
      execution_class
      nodes
      relations
      clauses
      relation_evidence
      independent_pairs
      argument_shares
    ]
    raise Failure, "v2 composed-plan DTO fields differ" unless
      struct_fields(v2, "ComposedPlanDto") == composed_fields
    raise Failure, "v2 diagnostic DTO is not closed and bounded" unless
      struct_fields(v2, "Diagnostic") == %w[code node] &&
        v2.match?(/diagnostics\.len\(\)\s*>\s*MAX_DIAGNOSTICS/) &&
        v2.match?(/pub const fn limit\(&self\).*fixed_limit/m)
    raise Failure, "v2 policy acceptance is not explicitly non-authorizing" unless
      v2.match?(
        /pub const fn authorizes_execution\(&self\)\s*->\s*bool\s*\{\s*false\s*\}/m
      ) &&
        v2.match?(/if authorizes_execution\s*\{\s*return Err\(ProtocolError::InvalidOutcome\)/m)
    raise Failure, "v2 confirmation instance binding differs" unless
      v2.match?(
        /Confirm\s*\{\s*session_id:\s*SessionId,\s*confirmation_id:\s*ConfirmationId,\s*plan:\s*ComposedPlan,\s*\}/m
      ) &&
        struct_fields(v2, "ConfirmationRequired") ==
          %w[session_id confirmation_id risk plan]
    raise Failure, "v2 plan source is not exact-bound" unless
      v2.match?(/source:\s*composed\.source\(\)\.as_str\(\)\.into\(\)/) &&
        v2.match?(
          /if self\.source\.as_bytes\(\)\s*!=\s*source\.as_bytes\(\)\s*\{\s*return Err\(ProtocolError::InvalidOutcome\)/m
        ) &&
        v2.match?(/fn into_core_embedded\s*\(/)

    request_block = item_block(v2, /pub enum Request\s*/)
    if request_block.match?(
      /\b(?:caller|permission|authorization|credential|password|access_token|api_key|service_name|payload)\b/i
    )
      raise Failure, "v2 request carries authority or credential material"
    end
    raise Failure, "v2 DTOs do not reject unknown fields" if
      v2.scan(/deny_unknown_fields/).length < 14
    raise Failure, "v2 decoding does not reject trailing input" unless
      v2.match?(/deserializer\s*\.end\(\)/m)
    raise Failure, "v2 preflight does not use its strict profile" unless
      v2.match?(/preflight::Limits::strict\s*\(/) &&
        preflight.match?(/count_object_members:\s*true/) &&
        preflight.match?(/count_numeric_sign:\s*true/)

    validate_v2_schemas(request_schema, response_schema)
    true
  end

  def validate_v2_schemas(request_bytes, response_bytes)
    request = parse_json(request_bytes, "protocol v2 request schema")
    response = parse_json(response_bytes, "protocol v2 response schema")
    [request, response].each do |schema|
      raise Failure, "protocol v2 schema version differs" unless
        schema["x-protocolVersion"] == 2
      raise Failure, "protocol v2 schema wire limit differs" unless
        schema["x-maxWireBytes"] == 131_072
      raise Failure, "protocol v2 schema is open" unless
        schema["additionalProperties"] == false
    end
    request_refs = request.dig("properties", "request", "oneOf")
    response_refs = response.dig("properties", "outcome", "oneOf")
    raise Failure, "protocol v2 request schema variant count differs" unless
      request_refs.is_a?(Array) && request_refs.length == 5
    raise Failure, "protocol v2 response schema variant count differs" unless
      response_refs.is_a?(Array) && response_refs.length == 9
    raise Failure, "protocol v2 response diagnostic bound differs" unless
      response.dig("properties", "diagnostics", "maxItems") == 8
    request_confirmation = request.dig("$defs", "confirmRequest")
    response_confirmation = response.dig("$defs", "confirmationRequiredOutcome")
    [request_confirmation, response_confirmation].each do |definition|
      raise Failure, "protocol v2 confirmation ID schema differs" unless
        definition.fetch("required").include?("confirmation_id") &&
          definition.dig("properties", "confirmation_id", "$ref") ==
            "#/$defs/confirmationId"
      raise Failure, "protocol v2 confirmation plan schema differs" unless
        definition.fetch("required").include?("plan")
    end
    raise Failure, "protocol v2 confirmation request plan reference differs" unless
      request_confirmation.dig("properties", "plan", "$ref") ==
        "urn:nlu-ptbr:protocol:v2:response#/$defs/composedPlan"
    raise Failure, "protocol v2 confirmation response plan reference differs" unless
      response_confirmation.dig("properties", "plan", "$ref") ==
        "#/$defs/composedPlan"
    composed = response.dig("$defs", "composedPlan")
    raise Failure, "protocol v2 composed-plan source schema differs" unless
      composed.fetch("required").first == "source" &&
        composed.dig("properties", "source") == {
          "type" => "string",
          "maxLength" => 16_384,
          "x-maxUtf8Bytes" => 16_384
        }
    confirmation_id = request.dig("$defs", "confirmationId")
    raise Failure, "protocol v2 confirmation ID bound differs" unless
      confirmation_id == {
        "type" => "integer",
        "minimum" => 1,
        "maximum" => 18_446_744_073_709_551_615
      } &&
        response.dig("$defs", "confirmationId") == confirmation_id
    true
  end

  def parse_json(bytes, context)
    JSON.parse(
      bytes,
      object_class: DuplicateRejectingHash,
      max_nesting: 64
    )
  rescue JSON::ParserError, JSON::NestingError, DuplicateKey => error
    raise Failure, "invalid JSON in #{context}: #{error.class}"
  end

  def validate_server_contract(config, framing, health, server, snapshot, runtime)
    {
      "MAX_WORKERS" => 8,
      "MAX_CONNECTION_QUEUE" => 64,
      "MAX_FRAMES_PER_CONNECTION" => 8,
      "MAX_SOCKET_PATH_BYTES" => 96,
      "MIN_FRAME_TIMEOUT_MILLIS" => 10,
      "MAX_FRAME_TIMEOUT_MILLIS" => 30_000
    }.each do |name, expected|
      raise Failure, "server limit differs: #{name}" unless
        integer_constant(config, name) == expected
    end
    raise Failure, "server frame limit differs" unless
      integer_constant(framing, "MAX_FRAME_BYTES") == 131_072

    validate_environment_allowlist(config)
    required_framing = {
      "four-byte big-endian header" =>
        /const HEADER_BYTES:\s*usize\s*=\s*4;.*u32::from_be_bytes/m,
      "length check before allocation" =>
        /if length > MAX_FRAME_BYTES.*vec!\[0_u8;\s*length\]/m,
      "bounded response" => /if payload\.len\(\)\s*>\s*MAX_FRAME_BYTES/,
      "complete reads" => /\.read_exact\s*\(/,
      "complete writes" => /\.write_all\s*\(/,
      "deadline-aware socket reads" =>
        /fn read_frame_until\s*\(.*read_exact_until\(stream,\s*&mut header,\s*deadline\).*read_exact_until\(stream,\s*&mut payload,\s*deadline\)/m,
      "deadline-aware socket writes" =>
        /fn write_frame_until\s*\(.*write_all_until\(stream,\s*&length\.to_be_bytes\(\),\s*deadline\).*write_all_until\(stream,\s*payload,\s*deadline\)/m,
      "remaining-time recalculation" =>
        /fn remaining\s*\(deadline:\s*Instant\).*checked_duration_since\(Instant::now\(\)\)/m
    }
    required_framing.each do |name, pattern|
      raise Failure, "server framing lacks #{name}" unless framing.match?(pattern)
    end

    required_socket = {
      "Unix listener and stream only" =>
        /use std::os::unix::net::\{UnixListener,\s*UnixStream\};/,
      "local bind" => /UnixListener::bind\s*\(\s*config\.socket_path\(\)\s*\)/,
      "owner-only socket" => /Permissions::from_mode\(0o600\)/,
      "owner-only parent" => /permissions\(\)\.mode\(\)\s*&\s*0o077\s*!=\s*0/,
      "symlink parent rejection" => /metadata\.file_type\(\)\.is_symlink\(\)/,
      "bounded worker queue capacity" =>
        /let capacity = usize::from\(self\.config\.queue_capacity\(\)\)/,
      "nonblocking bounded acceptance" => /listener\s*\.set_nonblocking\(true\)/m,
      "blocking accepted streams" =>
        /Ok\(\(stream,\s*_address\)\).*stream\s*\.set_nonblocking\(false\).*sender\.try_send\(stream\)/m,
      "bounded frames per connection" =>
        /for _ in 0\.\.config\.frames_per_connection\(\)/,
      "bounded request submission" =>
        /request_sender\.try_send\(job\).*TrySendError::Full.*RequestQueueFull/m,
      "bounded request deadline" =>
        /fn execute_request_until.*checked_duration_since\(Instant::now\(\)\).*receiver\.recv_timeout\(remaining\).*settle_expired_request/m,
      "single absolute frame deadline" =>
        /for _ in 0\.\.config\.frames_per_connection\(\).*let deadline = Instant::now\(\).*read_frame_until\(stream,\s*deadline\).*execute_request_until\(\s*request_sender,\s*snapshot,\s*request,\s*deadline,\s*Arc::clone\(&shutdown\),\s*Arc::clone\(&fatal\),?\s*\).*write_frame_until\(stream,\s*&response,\s*deadline\)/m,
      "fixed request workers and monitors" =>
        /fn spawn_request_workers.*0\.\.self\.config\.workers\(\).*request_worker_loop.*request_monitor_loop/m,
      "worker retirement guard installed" =>
        /fn spawn_request_workers.*WorkerFinished::new.*request_worker_loop/m,
      "deadline-expiring active completion" =>
        /fn try_complete.*if self\.deadline_elapsed\(\).*self\.expire\(\).*return false;.*REQUEST_ADMITTED,\s*REQUEST_COMPLETED/m,
      "failed admitted completion is fatal" =>
        /fn request_worker_loop.*let completed = complete_active_request.*if completed.*else\s*\{\s*admission\.fatal\.exit\(\)/m,
      "deadline-bearing request admission" =>
        /struct RequestAdmission\s*\{\s*deadline:\s*Instant,\s*state:\s*AtomicU8,\s*shutdown:\s*Arc<AtomicBool>,\s*fatal:\s*Arc<FatalProcess>,\s*\}/m,
      "shared request admission token" =>
        /fn execute_request_until.*RequestAdmission::new\(deadline,\s*shutdown,\s*fatal\).*admission:\s*Arc::clone\(&admission\).*settle_expired_request\(admission\.as_ref\(\)\)/m,
      "worker admission before handling" =>
        /fn request_worker_loop.*Arc::clone\(&job\.admission\).*admission\.try_admit\(\).*install_active_request.*handler\.handle.*complete_active_request/m,
      "lock-serialized active completion" =>
        /fn complete_active_request.*active\s*\.lock\(\).*admission\.try_complete\(\).*if completed\s*\{\s*slot\.admission\.take\(\);?\s*\}/m,
      "mutex-bound worker retirement" =>
        /impl Drop for WorkerFinished.*active.*lock\(\).*slot\.finished\s*=\s*true/m,
      "expired-active deadline monitor" =>
        /fn monitor_requires_fatal.*state\s*==\s*REQUEST_EXPIRED_ACTIVE\s*\|\|\s*\(state\s*==\s*REQUEST_ADMITTED\s*&&\s*\(now\s*>=\s*admission\.deadline\s*\|\|\s*slot\.finished\)\).*fn request_monitor_loop.*let slot = active\.lock\(\).*monitor_requires_fatal\(&slot,\s*Instant::now\(\)\).*admission\.fatal\.exit\(\)/m,
      "fatal admitted-timeout settlement" =>
        /fn settle_expired_request.*if admission\.expire\(\).*admission\.fatal\.exit\(\).*RequestTimeout/m,
      "deadline-triggered fatal shutdown" =>
        /shutdown\.store\(true,\s*Ordering::Release\).*drop\(connection_sender\).*drop\(request_sender\).*connection_workers\.append\(&mut request_workers\).*connection_workers\.append\(&mut request_monitors\).*join_workers_until\(&mut connection_workers,\s*shutdown_deadline,\s*fatal\.as_ref\(\)\)/m,
      "fatal process containment" =>
        /struct FatalProcess;.*fn exit\(&self\)\s*->\s*!.*std::process::exit\(FATAL_HANDLER_EXIT_CODE\).*const FATAL_HANDLER_EXIT_CODE:\s*i32\s*=\s*70;/m,
      "cancelled worker disconnect is a timeout" =>
        /Err\(RecvTimeoutError::Disconnected\)\s*if admission\.is_cancelled\(\)\s*=>\s*\{\s*Err\(ServerError::new\(ServerErrorCode::RequestTimeout\)\)\s*\}/m,
      "single-run worker bound" =>
        /self\.started\.swap\(true,\s*Ordering::AcqRel\)/
    }
    required_socket.each do |name, pattern|
      raise Failure, "server socket contract lacks #{name}" unless server.match?(pattern)
    end
    production_server = server.split("#[cfg(test)]", 2).fetch(0)
    raise Failure, "server runtime attempts unsafe socket path retirement" if
      production_server.match?(/fs::(?:remove_file|rename)\s*\(/) ||
      production_server.match?(/impl<.*Drop for UnixServer/m)

    request_worker_spawn = method_block(server, "fn spawn_request_workers")
    raise Failure, "server socket contract lacks worker retirement guard installed" unless
      request_worker_spawn.match?(
        /let _finished = WorkerFinished::new\(.*request_worker_loop/m
      )

    monitor_predicate = method_block(server, "fn monitor_requires_fatal")
    request_monitor = method_block(server, "fn request_monitor_loop")
    raise Failure, "server socket contract lacks expired-active deadline monitor" unless
      monitor_predicate.match?(
        /let state = admission\.state\.load\(Ordering::Acquire\);.*state\s*==\s*REQUEST_EXPIRED_ACTIVE\s*\|\|\s*\(state\s*==\s*REQUEST_ADMITTED\s*&&\s*\(now\s*>=\s*admission\.deadline\s*\|\|\s*slot\.finished\)\)/m
      ) &&
      request_monitor.match?(
        /monitor_requires_fatal\(&slot,\s*Instant::now\(\)\).*admission\.fatal\.exit\(\)/m
      )

    raise Failure, "server does not have exactly two bounded work queues" unless
      server.scan(/sync_channel\(capacity\)/).length == 2
    request_admission = method_block(server, "fn try_admit")
    raise Failure, "request admission is not deadline checked before handling" unless
      request_admission.match?(
        /if self\.is_expired\(\).*self\.cancel\(\).*return false;.*compare_exchange\s*\(\s*REQUEST_QUEUED,\s*REQUEST_ADMITTED,\s*Ordering::AcqRel,\s*Ordering::Acquire\s*,?\s*\)\s*\.is_err\(\).*return false;.*if self\.is_expired\(\).*self\.cancel\(\).*return false;.*true/m
      )
    request_expiration = method_block(server, "fn expire")
    raise Failure, "request expiration does not retain fatal-visible admitted work" unless
      request_expiration.match?(
        /REQUEST_QUEUED\s*=>.*REQUEST_QUEUED,\s*REQUEST_CANCELLED.*Ok\(_\)\s*=>\s*return false.*REQUEST_ADMITTED\s*=>.*REQUEST_ADMITTED,\s*REQUEST_EXPIRED_ACTIVE.*Ok\(_\)\s*=>\s*return true.*REQUEST_EXPIRED_ACTIVE\s*=>\s*return true.*REQUEST_CANCELLED\s*\|\s*REQUEST_COMPLETED\s*=>\s*return false/m
      )
    active_completion = method_block(server, "fn complete_active_request")
    complete = active_completion.index("admission.try_complete()")
    conditional_clear = active_completion.index("if completed {")
    clear = active_completion.index("slot.admission.take()")
    raise Failure, "active completion is not serialized before success-only slot clearing" unless
      active_completion.match?(/active\s*\.lock\(\)/) &&
      complete && conditional_clear && clear &&
      complete < conditional_clear && conditional_clear < clear
    request_settlement = method_block(server, "fn settle_expired_request")
    raise Failure, "request expiration does not fatally contain admitted work" unless
      request_settlement.match?(
        /if admission\.expire\(\).*admission\.fatal\.exit\(\).*ServerErrorCode::RequestTimeout/m
      )
    shutdown_join = method_block(server, "fn join_workers_until")
    raise Failure, "shutdown can leave admitted workers alive" unless
      shutdown_join.match?(
        /Instant::now\(\)\s*>=\s*deadline.*if !workers\.is_empty\(\)\s*\{\s*fatal\.exit\(\)/m
      )
    request_worker = method_block(server, "fn request_worker_loop")
    handle = request_worker.index("handler.handle")
    erase = request_worker.index("job.request.erase();")
    complete = request_worker.index("complete_active_request(active, &admission)")
    publish = request_worker.index("job.response.send(response)")
    raise Failure, "request is not erased and completed before response publication" unless
      handle && erase && complete && publish &&
      handle < erase && erase < complete && complete < publish
    raise Failure, "request worker retains request-derived storage" if
      request_worker.match?(
        /\.to_vec\s*\(|\.to_owned\s*\(|\.clone\s*\(|\.push\s*\(|\.extend(?:_from_slice)?\s*\(|\b(?:Box::leak|mem::forget|ManuallyDrop)\b/
      )
    raise Failure, "server bind does not validate the live process environment" unless
      method_block(server, "pub fn bind").match?(
        /SanitizedEnvironment::validate_current\(\)\?;.*UnixListener::bind/m
      )

    raise Failure, "health protocol versions differ" unless
      health.match?(/SUPPORTED_PROTOCOL_VERSIONS:\s*\[u16;\s*2\]\s*=\s*\[1,\s*2\]/)
    raise Failure, "health fields are not closed and bounded" unless
      struct_fields(health, "HealthSnapshot") ==
        %w[
          readiness
          protocol_versions
          runtime_generation
          catalog_generation
          policy_generation
        ]
    validate_snapshot_contract(snapshot)
    validate_runtime_contract(runtime)
    true
  end

  def validate_environment_allowlist(config)
    body = config[
      /const ALLOWED_ENVIRONMENT:\s*\[\(&str,\s*&str\);\s*7\]\s*=\s*\[(.*?)^\];$/m,
      1
    ]
    raise Failure, "server environment allowlist declaration differs" unless body

    pairs = body.scan(/\("([^"]+)",\s*"([^"]+)"\)/)
    expected = [
      ["HOME", "/nonexistent"],
      ["LANG", "C.UTF-8"],
      ["LC_ALL", "C.UTF-8"],
      ["PATH", "/usr/bin:/bin"],
      ["RUST_BACKTRACE", "0"],
      ["TMPDIR", "/tmp"],
      ["TZ", "UTC"]
    ]
    raise Failure, "server environment allowlist differs" unless pairs == expected
    raise Failure, "server environment attestation is externally forgeable" unless
      config.match?(
        /pub\(crate\) struct SanitizedEnvironment\s*\{\s*_private:\s*\(\),\s*\}/m
      ) &&
        config.match?(
          /impl SanitizedEnvironment\s*\{\s*fn validate<.*pub\(crate\) fn validate_current\(\)/m
        ) &&
        config.match?(/Self::validate\(std::env::vars_os\(\)\)/)
    raise Failure, "server environment permits unknown or duplicate keys" unless
      config.match?(/else\s*\{\s*return Err\(ServerError::new\(ServerErrorCode::UnsanitizedEnvironment\)\)/m) &&
        config.match?(/value\s*!=\s*OsStr::new\(expected\)\s*\|\|\s*seen\.contains\(&key\)/m)
    true
  end

  def validate_snapshot_contract(snapshot)
    required = {
      "immutable runtime snapshot" =>
        /pub struct RuntimeSnapshot<T>\s*\{\s*metadata:\s*SnapshotMetadata,\s*state:\s*T,\s*active:\s*AtomicBool,\s*\}/m,
      "atomic Arc snapshot cell" =>
        /current:\s*RwLock<Arc<RuntimeSnapshot<T>>>/,
      "semantic snapshot-state contract" =>
        /pub trait SnapshotState\s*\{.*fn validate_snapshot_metadata\(&self,\s*metadata:\s*SnapshotMetadata\)\s*->\s*Result<\(\)>;.*fn prepare_successor\(&self,\s*_successor:\s*&Self\)\s*->\s*Result<\(\)>.*fn invalidate_for_reload\(&self,\s*now:\s*LogicalTime\)\s*->\s*Result<\(\)>;/m,
      "bounded snapshot store type" => /pub struct SnapshotStore<T:\s*SnapshotState>/,
      "leased immutable Arc" =>
        /\.read\(\).*Arc::clone\(&snapshot\)/m,
      "time-bound exclusive replacement" =>
        /pub fn replace_at\([^)]*now:\s*LogicalTime\).*\.write\(\).*validate_successor/m,
      "checked runtime generation" => /\.checked_add\(1\)/,
      "retired snapshot rejection" =>
        /if !self\.active\.load\(Ordering::Acquire\).*ServerErrorCode::RuntimeState/m,
      "single Arc exchange" => /\*current\s*=\s*next\s*;/,
      "successor preparation and old state invalidation before exchange" =>
        /validate_successor\(current\.metadata\(\),\s*next\.metadata\(\)\)\?;\s*current\.state\(\)\.prepare_successor\(next\.state\(\)\)\?;\s*current\.state\(\)\.invalidate_for_reload\(now\)\?;\s*current\.retire\(\);\s*\*current\s*=\s*next/m
    }
    required.each do |name, pattern|
      raise Failure, "snapshot contract lacks #{name}" unless snapshot.match?(pattern)
    end
    store = item_block(
      snapshot,
      /impl<T:\s*SnapshotState>\s*SnapshotStore<T>\s*/
    )
    constructor = method_block(store, "pub fn new")
    replacement = method_block(store, "pub fn replace_at")
    raise Failure, "initial snapshot state is not semantically validated" unless
      constructor.match?(
        /initial\s*\.state\(\)\s*\.validate_snapshot_metadata\(initial\.metadata\(\)\)\?/
      )
    state_validation = replacement.index(
      "next.state().validate_snapshot_metadata(next.metadata())?"
    )
    write_lock = replacement.index(".write()")
    preparation = replacement.index("current.state().prepare_successor(next.state())?")
    invalidation = replacement.index("current.state().invalidate_for_reload(now)?")
    retirement = replacement.index("current.retire();")
    exchange = replacement.index("*current = next;")
    raise Failure, "replacement state is not validated before lock or old state invalidation is not ordered before exchange" unless
      state_validation && write_lock && preparation && invalidation && retirement && exchange &&
        state_validation < write_lock &&
        write_lock < preparation &&
        preparation < invalidation &&
        invalidation < retirement &&
        retirement < exchange
    true
  end

  def validate_runtime_contract(runtime)
    runtime_struct = item_block(runtime, /pub struct NluRuntime\s*/)
    fields = struct_fields(runtime, "NluRuntime")
    raise Failure, "real NLU runtime component set differs" unless
      fields == %w[metadata catalog intents plans sessions policy]
    required = {
      "version detection" => /match detect_request_version\(request\)/,
      "v1 dispatch" => /RequestVersion::V1.*dispatch_v1/m,
      "v2 dispatch" => /RequestVersion::V2.*dispatch_v2/m,
      "all five v2 requests" =>
        /Request::Interpret.*Request::Continue.*Request::Confirm.*Request::Cancel.*Request::Health/m,
      "complete resumable planning" => /\.compose_resumable\s*\(/,
      "policy evaluation" => /\.policy\s*\.evaluate\s*\(/m,
      "v1 policy assessment" => /\.policy\s*\.assess\(&plan,\s*self\.policy_context\(\)\)/m,
      "v1 confirmation-required abstention" =>
        /PolicyDecision::Denied\(_\)\s*\|\s*PolicyDecision::ConfirmationRequired\(_\).*v1::Outcome::Abstention/m,
      "injected logical clock" => /C:\s*LogicalClock\s*\+\s*Send\s*\+\s*Sync/,
      "non-authorizing wire acceptance" => /PolicyAccepted::new\(plan,\s*map_risk/
    }
    required.each do |name, pattern|
      raise Failure, "real server runtime lacks #{name}" unless runtime.match?(pattern)
    end
    raise Failure, "request handler ordering state differs" unless
      struct_fields(runtime, "NluRequestHandler") == %w[clock request_order] &&
      runtime.match?(/request_order:\s*Mutex<\(\)>/) &&
      runtime.match?(/request_order:\s*Mutex::new\(\(\)\)/)
    request_handle = method_block(runtime, "fn handle")
    order_lock = request_handle.index(".request_order")
    lock = request_handle.index(".lock()")
    poison = request_handle.index("ServerErrorCode::LockPoisoned")
    dispatch = request_handle.index("NluRuntime::dispatch_at")
    clock_sample = request_handle.index("self.clock.now()")
    raise Failure, "clock sample and stateful dispatch are not request-order serialized" unless
      order_lock && lock && poison && dispatch && clock_sample &&
      order_lock < lock && lock < poison && poison < dispatch &&
      dispatch < clock_sample
    dispatch = method_block(runtime, "pub fn dispatch_at")
    active_validation = dispatch.index("snapshot.ensure_active()?;")
    snapshot_validation = dispatch.index("validate_snapshot(snapshot)?;")
    time_observation = dispatch.index("snapshot.state().observe_time(now)?;")
    version_detection = dispatch.index("match detect_request_version(request)")
    raise Failure, "all-request logical-time observation is not before version detection" unless
      active_validation && snapshot_validation && time_observation && version_detection &&
        active_validation < snapshot_validation &&
        snapshot_validation < time_observation &&
        time_observation < version_detection
    dispatch_v2 = method_block(runtime, "fn dispatch_v2")
    raise Failure, "v2 retains a version-specific logical-time observation" if
      dispatch_v2.include?("observe_time(now)")
    {
      "catalog snapshot" => /catalog:\s*CatalogSnapshot/,
      "intent engine" => /intents:\s*IntentEngine/,
      "plan engine" => /plans:\s*PlanEngine/,
      "session store" => /sessions:\s*SessionStore/,
      "policy engine" => /policy:\s*PolicyEngine/
    }.each do |name, pattern|
      raise Failure, "real server runtime lacks #{name}" unless
        runtime_struct.match?(pattern)
    end
    snapshot_validation = method_block(runtime, "fn validate_snapshot_metadata")
    raise Failure, "runtime does not bind exact metadata and component generations" unless
      snapshot_validation.match?(/self\.metadata\s*!=\s*metadata/) &&
        snapshot_validation.match?(
          /self\.catalog\.generation\(\)\.get\(\)\s*!=\s*metadata\.catalog_generation\(\)/
        ) &&
        snapshot_validation.match?(
          /self\.policy\.table\(\)\.generation\(\)\.get\(\)\s*!=\s*metadata\.policy_generation\(\)/
        )
    preparation = method_block(runtime, "fn prepare_successor")
    raise Failure, "runtime does not inherit the confirmation sequence" unless
      preparation.match?(
        /successor\s*\.policy\s*\.inherit_confirmation_sequence\(&self\.policy\)/m
      )
    invalidation = method_block(runtime, "fn invalidate_for_reload")
    raise Failure, "runtime reload does not invalidate both state engines" unless
      invalidation.match?(/self\.sessions\.invalidate_for_reload\(now\)/) &&
        invalidation.match?(/self\.policy\.invalidate_for_reload\(now\)/)
    observe_time = method_block(runtime, "fn observe_time")
    session_observe = observe_time.index("self.sessions.purge_expired(now)")
    policy_observe = observe_time.index("self.policy.purge_expired(now)")
    first_propagation = observe_time.index(".map_err")
    raise Failure, "runtime does not observe both clocks before propagating rollback" unless
      session_observe && policy_observe && first_propagation &&
      session_observe < first_propagation && policy_observe < first_propagation
    dispatch_v1 = method_block(runtime, "fn dispatch_v1")
    raise Failure, "v1 can emit a plan without an explicit allow decision" unless
      dispatch_v1.match?(
        /PolicyDecision::AllowedWithoutConfirmation\(_\)\s*=>\s*\{\s*v1::Outcome::Plan/m
      ) &&
        dispatch_v1.match?(
          /PolicyDecision::Denied\(_\)\s*\|\s*PolicyDecision::ConfirmationRequired\(_\)\s*=>\s*\{\s*v1::Outcome::Abstention\(AbstentionReason::Unsupported\)/m
        )
    true
  end

  def validate_engine_owned_integration(session, policy, runtime)
    continuation = method_block(session, "pub fn continue_with_selection")
    raise Failure, "engine-owned continuation API differs" unless
      continuation.match?(/session:\s*&SessionId/) &&
        continuation.match?(/selection:\s*EntityRef/) &&
        continuation.match?(/current_generation:\s*CatalogGeneration/) &&
        continuation.match?(/state\.sessions\.remove\(session\)/) &&
        continuation.match?(/pending\s*\.pending\s*\.complete\(selection\)/m)
    if continuation.match?(/\borigin:\s*&InvocationId|\bcapability:\s*CapabilityId|\bendpoint:/)
      raise Failure, "continuation requires server-resupplied stored bindings"
    end

    stored = method_block(policy, "pub fn confirm_stored")
    raise Failure, "engine-owned confirmation API differs" unless
      stored.match?(/session:\s*&SessionId/) &&
        stored.match?(/confirmation_id:\s*ConfirmationId/) &&
        stored.match?(/addressed_plan:\s*&ComposedPlan/) &&
        stored.match?(/context:\s*PolicyContext/) &&
        stored.match?(/self\.take_confirmation\(session,\s*now\)/) &&
        stored.match?(/pending\.confirmation_id\s*!=\s*confirmation_id/) &&
        stored.match?(/pending\.plan\s*!=\s*\*addressed_plan/) &&
        stored.match?(/self\.evaluate_plan\(&pending\.plan,\s*context\)/) &&
        stored.match?(/plan:\s*pending\.plan/)
    raise Failure, "server does not use engine-owned continuation" unless
      runtime.match?(
        /\.continue_with_selection\(&session,\s*selection,\s*self\.catalog\.generation\(\),\s*now\)/m
      )
    raise Failure, "server does not use engine-owned stored confirmation" unless
      runtime.match?(
        /\.confirm_stored\(\s*&session,\s*confirmation_id,\s*addressed_plan,\s*self\.policy_context\(\),\s*now,\s*\)/m
      )
    true
  end

  def validate_network_and_privacy(root, policy, protocol, server)
    server_production = server.select { |path, _| path.include?("/src/") }
      .transform_values { |bytes| strip_cfg_tests(bytes) }
    other_production = policy.merge(protocol)
      .select { |path, _| path.include?("/src/") }
      .transform_values { |bytes| strip_cfg_tests(bytes) }

    server_joined = server_production.values.join("\n")
    server_production.each do |path, bytes|
      if bytes.match?(/^\s*(?:pub(?:\([^)]*\))?\s+)?static\b/m) ||
         bytes.match?(/\bthread_local!\s*\(|\b(?:OnceLock|LazyLock)\b/)
        raise Failure, "process-global server state in #{path}"
      end
      if bytes.match?(
        /\b(?:Box::leak|mem::forget|ManuallyDrop|into_raw|from_raw|as_mut_ptr)\b|\*const\s|\*mut\s/
      )
        raise Failure, "request-retention primitive in #{path}"
      end
    end
    raise Failure, "server production thread count differs" unless
      server_joined.scan(/\bthread::spawn\s*\(/).length == 3
    runtime_bytes = server_production.fetch("crates/nlu-server/src/runtime.rs")
    if runtime_bytes.match?(
      /\brequest\s*\.(?:to_vec|to_owned|clone)\s*\(|Vec::from\s*\(\s*request\s*\)|extend_from_slice\s*\(\s*request\s*\)/
    )
      raise Failure, "runtime retains request-derived bytes"
    end
    raise Failure, "server has outbound network API" if
      server_joined.match?(
        /\bstd::net\b|\b(?:Tcp|Udp)(?:Listener|Socket|Stream)\b|\bUnixDatagram\b|\bUnixStream::connect\b|\bconnect(?:_timeout)?\s*\(|\b(?:reqwest|hyper|tokio|socket2|curl|rustls|openssl)::/
      )
    raise Failure, "server listener import count differs" unless
      server_joined.scan(/std::os::unix::net::\{UnixListener,\s*UnixStream\}/).length == 1
    raise Failure, "server bind path differs" unless
      server_joined.scan(/UnixListener::bind\s*\(/).length == 1
    server_without_fatal_containment = server_joined.sub(
      "std::process::exit(FATAL_HANDLER_EXIT_CODE)",
      ""
    )
    if rust_process_api?(server_without_fatal_containment) ||
       server_joined.match?(/\/(?:usr\/)?bin\/(?:nc|netcat|socat)\b/)
      raise Failure, "server has subprocess or external outbound client path"
    end
    raise Failure, "server has an unbounded work queue" if
      server_joined.match?(/\bmpsc::channel\s*\(|\bchannel::<[^>]+>\s*\(/)
    execute_request = method_block(
      server.fetch("crates/nlu-server/src/server.rs"),
      "fn execute_request_until"
    )
    raise Failure, "server creates a thread per request" if
      execute_request.match?(/\bthread::spawn\s*\(/)

    other_production.each do |path, bytes|
      if bytes.match?(
        /\bstd::(?:os::unix::)?net\b|\b(?:Tcp|Udp|Unix)(?:Listener|Datagram|Socket|Stream)\b|\b(?:reqwest|hyper|tokio|socket2|curl|rustls|openssl)::/
      )
        raise Failure, "network API below nlu-server: #{path}"
      end
      if rust_process_api?(bytes)
        raise Failure, "subprocess API below nlu-server: #{path}"
      end
    end

    lang_sources = Dir[File.join(root, "crates/lang-ptbr/src/**/*.rs")].sort
    lang_sources.each do |path|
      bytes = strip_cfg_tests(File.binread(path))
      if bytes.match?(/\bstd::(?:os::unix::)?net\b|\bconnect\s*\(|\b(?:reqwest|hyper|tokio|socket2)::/)
        raise Failure, "network API in lang-ptbr: #{path.delete_prefix("#{root}/")}"
      end
    end

    logging = /\b(?:println|eprintln|dbg)!\s*\(|\b(?:tracing|log|metrics|opentelemetry|telemetry)::/
    (server_production.merge(policy.select { |path, _| path.include?("/src/") })).each do |path, bytes|
      raise Failure, "logging or telemetry API in #{path}" if bytes.match?(logging)
    end
    if server_joined.match?(
      /\b(?:credential|password|secret|access_token|api_key|supervisor_token|pairing_key)\b/i
    )
      raise Failure, "credential material in nlu-server production source"
    end
    residential = server_joined.scan(/residential(?:_data)?/i)
    raise Failure, "residential data can enter server output" unless
      residential.length == 1 &&
        server_joined.include?('.field("residential_data", &"redacted")')
    true
  end

  def rust_process_api?(bytes)
    compact = rust_code_only(bytes).gsub(/\s+/, "")
    direct = /(?:\A|[^A-Za-z0-9_])(?:::)?std::process(?:[^A-Za-z0-9_]|\z)/
    direct_import = /use(?:::)?std::process(?:[^A-Za-z0-9_]|\z)/
    grouped = /use(?:::)?std::\{[^;]*\bprocess\b[^;]*\}/
    std_alias = /use(?:::)?stdas[A-Za-z_][A-Za-z0-9_]*;|externcratestdas/
    invocation = /\b(?:process::)?Command::new\(|\bChild::spawn\(/
    compact.match?(direct) ||
      compact.match?(direct_import) ||
      compact.match?(grouped) ||
      compact.match?(std_alias) ||
      compact.match?(invocation)
  end

  def strip_cfg_tests(bytes)
    stripped = bytes.dup
    pattern = /^\#\[cfg\(test\)\]\s*\nmod tests\s*\{/
    loop do
      marker = stripped.match(pattern)
      break unless marker

      tail = stripped.byteslice(marker.begin(0), stripped.bytesize - marker.begin(0))
      block = item_block(tail, /\A\#\[cfg\(test\)\]\s*\nmod tests\s*/)
      stripped = stripped.byteslice(0, marker.begin(0)) +
        stripped.byteslice(
          marker.begin(0) + block.bytesize,
          stripped.bytesize - marker.begin(0) - block.bytesize
        )
    end
    stripped
  end

  def protocol_test_bytes(protocol)
    protocol.select { |path, _| path.include?("/tests/") && path.end_with?(".rs") }
      .sort
      .map { |_, bytes| bytes }
      .join("\n")
  end

  def server_test_bytes(server)
    server.select { |path, _| path.end_with?(".rs") }
      .sort
      .map { |_, bytes| bytes }
      .join("\n")
  end

  def validate_test_contracts(policy, protocol, server)
    {
      "policy" => [policy, POLICY_TESTS],
      "protocol" => [protocol, PROTOCOL_TESTS],
      "server" => [server, SERVER_TESTS]
    }.each do |component, pair|
      bytes, tests = pair
      raise Failure, "#{component} tests lack FIXTURE_TECNICA labels" unless
        bytes.include?("FIXTURE_TECNICA")
      tests.each do |name, pattern|
        matches = bytes.enum_for(:scan, pattern).map { Regexp.last_match.begin(0) }
        raise Failure, "#{component} tests lack #{name}" unless matches.length == 1
        function = pattern.source[/fn ([a-z0-9_]+)/, 1]
        raise Failure, "#{component} test identity is malformed: #{name}" unless function
        test_body = required_test_body(bytes, function)
        validate_required_test_reachability(bytes, function, test_body)
        if test_body.bytesize < 256
          raise Failure, "#{component} test body is not substantive: #{name}"
        end
        unless test_body.match?(
          /\b(?:assert(?:_eq|_ne)?|debug_assert(?:_eq|_ne)?|matches|panic)!\s*\(|\.(?:expect|expect_err|unwrap|unwrap_err)\s*\(/
        )
          raise Failure, "#{component} test body lacks semantic checks: #{name}"
        end
      end
      TEST_BODY_EVIDENCE.fetch(component).each do |function, patterns|
        body = required_test_body(bytes, function)
        patterns.each do |pattern|
          raise Failure, "#{component} test body lacks #{function} evidence" unless
            body.match?(pattern)
        end
      end
      CODE_ONLY_TEST_BODY_EVIDENCE.fetch(component).each do |function, patterns|
        body = rust_code_only(required_test_body(bytes, function))
        patterns.each do |pattern|
          raise Failure, "#{component} executable test body lacks #{function} evidence" unless
            body.match?(pattern)
        end
      end
      if component == "policy"
        body = rust_code_only(
          required_test_body(
            bytes,
            "confirmation_rejects_source_text_substitution_with_equal_canonical_offsets"
          )
        )
        [
          /assert_ne!\s*\(\s*original,\s*substituted\s*\)/,
          /ConfirmationRejectionReason::BindingMismatch/
        ].each do |pattern|
          raise Failure, "policy critical test evidence exists only in padding" unless
            body.match?(pattern)
        end
      end
    end
    raise Failure, "protocol tests use arbitrary serde_json::Value" if
      protocol.match?(/\bValue\b/)
    validate_independent_policy_slot_schemas(policy)
    true
  end

  def required_test_body(bytes, function)
    signature = /\bfn\s+#{Regexp.escape(function)}\s*\([^)]*\)\s*/
    matches = bytes.enum_for(:scan, signature).map { Regexp.last_match.begin(0) }
    raise Failure, "required test is missing or duplicated: #{function}" unless
      matches.length == 1

    block = item_block(bytes, signature)
    opening = block.index("{")
    block.byteslice(opening + 1, block.bytesize - opening - 2)
  end

  def validate_required_test_reachability(bytes, function, body)
    function_match = bytes.match(
      /\bfn\s+#{Regexp.escape(function)}\s*\([^)]*\)\s*/
    )
    raise Failure, "required test function is missing: #{function}" unless function_match

    lines = bytes.byteslice(0, function_match.begin(0)).lines
    lines.pop while !lines.empty? && lines.last.strip.empty?
    attributes = []
    until lines.empty?
      line = lines.pop.strip
      break unless line.start_with?("#[")

      attributes.unshift(line)
    end
    raise Failure, "required test has disabled or noncanonical attributes: #{function}" unless
      attributes == ["#[test]"]

    code = rust_code_only(body)
    if code.match?(
      /\b(?:std::hint::)?black_box\s*\(|\b(?:if|while)\s+false\b|\bcfg!\s*\(\s*(?:false|any\s*\(\s*\))\s*\)|#\[(?:cfg|ignore|should_panic|allow\s*\(\s*unreachable_code)/
    )
      raise Failure, "required test contains unreachable evidence: #{function}"
    end
    early_return_tests = %w[
      bind_rejects_the_actual_process_environment_when_a_canary_is_present
      credential_canary_is_rejected_without_runtime_state_retention
    ]
    if code.match?(/\breturn\b/) && !early_return_tests.include?(function)
      raise Failure, "required test contains an early return: #{function}"
    end
    code.scan(/\blet\s+([a-z][a-z0-9_]*)\s*=\s*(?:move\s*)?\|[^|]*\|\s*\{/)
      .flatten
      .each do |closure|
        unless code.match?(/\b#{Regexp.escape(closure)}\s*\(/)
          raise Failure, "required test contains an uncalled closure: #{function}"
        end
      end
    true
  end

  def rust_code_only(bytes)
    output = bytes.dup
    index = 0
    state = :code
    escaped = false
    raw_hashes = 0
    comment_depth = 0
    while index < bytes.bytesize
      character = bytes.getbyte(index)
      following = bytes.getbyte(index + 1)
      if state == :string
        output.setbyte(index, 32) unless character == 10
        if escaped
          escaped = false
        elsif character == 92
          escaped = true
        elsif character == 34
          state = :code
        end
      elsif state == :raw_string
        output.setbyte(index, 32) unless character == 10
        if character == 34 &&
           bytes.byteslice(index + 1, raw_hashes) == ("#" * raw_hashes)
          raw_hashes.times { |offset| output.setbyte(index + 1 + offset, 32) }
          index += raw_hashes
          state = :code
        end
      elsif state == :line_comment
        output.setbyte(index, 32) unless character == 10
        state = :code if character == 10
      elsif state == :block_comment
        output.setbyte(index, 32) unless character == 10
        if character == 47 && following == 42
          output.setbyte(index + 1, 32)
          comment_depth += 1
          index += 1
        elsif character == 42 && following == 47
          output.setbyte(index + 1, 32)
          comment_depth -= 1
          index += 1
          state = :code if comment_depth.zero?
        end
      elsif character == 47 && following == 47
        output.setbyte(index, 32)
        output.setbyte(index + 1, 32)
        state = :line_comment
        index += 1
      elsif character == 47 && following == 42
        output.setbyte(index, 32)
        output.setbyte(index + 1, 32)
        state = :block_comment
        comment_depth = 1
        index += 1
      elsif character == 114
        raw_open = index + 1
        raw_open += 1 while bytes.getbyte(raw_open) == 35
        if bytes.getbyte(raw_open) == 34
          (index..raw_open).each { |position| output.setbyte(position, 32) }
          raw_hashes = raw_open - index - 1
          state = :raw_string
          index = raw_open
        end
      elsif character == 34
        output.setbyte(index, 32)
        state = :string
      elsif character == 39
        character_end = rust_character_literal_end(bytes, index)
        if character_end
          (index..character_end).each { |position| output.setbyte(position, 32) }
          index = character_end
        end
      end
      index += 1
    end
    output
  end

  def validate_independent_policy_slot_schemas(policy)
    EXPECTED_TEST_SLOT_SCHEMAS.each do |name, expected|
      body = policy[
        /const #{Regexp.escape(name)}:\s*&\[\(&str,\s*SlotKind\)\]\s*=\s*&\[(.*?)\];/m,
        1
      ]
      raise Failure, "policy test slot oracle is missing: #{name}" unless body
      actual = body.scan(/\("([^"]+)",\s*SlotKind::([A-Za-z]+)\)/)
      raise Failure, "policy test slot oracle differs: #{name}" unless actual == expected
    end
    matrix = required_test_body(
      policy,
      "standard_matrix_is_exact_exhaustive_and_evaluable"
    )
    if matrix.match?(/\bfixture_slots\s*\(/)
      raise Failure, "policy matrix test derives slot expectations from production"
    end
    raise Failure, "policy matrix test does not use its independent slot oracle" unless
      matrix.match?(/fixture_slots_from_schema\s*\(\s*slots,/)
    true
  end

  def validate_requirements(root, require_satisfied:)
    bytes = File.binread(
      File.join(root, "docs/evidence/REQUIREMENTS-TRACEABILITY.md")
    )
    statuses = validate_requirement_rows(
      bytes,
      require_satisfied: require_satisfied
    )
    validate_closeout(root) if statuses.values.all? { |status| status == "SATISFIED" }
    true
  end

  def validate_requirement_rows(bytes, require_satisfied:)
    raise Failure, "P13 owned requirement count differs" unless REQUIREMENTS.length == 28
    statuses = {}
    REQUIREMENTS.each do |id|
      rows = bytes.lines.select { |line| line.start_with?("| `#{id}` |") }
      raise Failure, "requirement row count differs: #{id}" unless rows.length == 1
      status = rows.fetch(0)[/\| (PENDING|SATISFIED) \|\n\z/, 1]
      raise Failure, "requirement status is malformed: #{id}" unless status
      statuses[id] = status
      next unless require_satisfied

      raise Failure, "requirement remains pending: #{id}" unless status == "SATISFIED"
    end
    statuses
  end

  def validate_closeout(root)
    validation = read_closeout_file(
      root,
      "docs/evidence/P13-VALIDATION.md"
    )
    report = read_closeout_file(root, "docs/phases/P13-REPORT.md")
    subject = validation[
      /^- Candidate: `([0-9a-f]{40})`$/,
      1
    ]
    tree = validation[
      /^- Candidate tree: `([0-9a-f]{40})`$/,
      1
    ]
    archive = validation[
      /^- Archive SHA-256: `([0-9a-f]{64})`$/,
      1
    ]
    raise Failure, "P13 validation lacks exact candidate identity" unless
      subject && tree && archive &&
        validation.include?("- Result: `PASS`") &&
        validation.include?(
          "tools/validate-p13 --no-cargo --review-candidate"
        ) &&
        validation.include?("tools/test-validate-p13") &&
        validation.include?("tools/test-p13-evidence") &&
        validation.include?("tools/p13-noise-evidence") &&
        validation.include?("tools/test-p13-noise-evidence")

    git = "/Library/Developer/CommandLineTools/usr/bin/git"
    actual_tree = run_checked(
      root,
      [git, "rev-parse", "#{subject}^{tree}"],
      "P13 closeout subject tree"
    ).strip
    raise Failure, "P13 closeout subject tree differs" unless actual_tree == tree
    archive_bytes = run_checked(
      root,
      [git, "archive", "--format=tar", subject],
      "P13 closeout subject archive"
    )
    raise Failure, "P13 closeout subject archive differs" unless
      Digest::SHA256.hexdigest(archive_bytes) == archive

    raise Failure, "P13 report identity or result differs" unless
      report.include?("- State: `COMPLETE`") &&
        report.include?("- Subject: `#{subject}`") &&
        report.include?("- Subject tree: `#{tree}`") &&
        report.include?("- Archive SHA-256: `#{archive}`") &&
        report.include?("- Result: `MINIMUM_ACCEPTABLE_PASS`")

    instances = []
    FINAL_REVIEW_FILES.each do |role, relative|
      review = read_closeout_file(root, relative)
      instance = review[/^- Review instance: `([^`\n]+)`$/, 1]
      raise Failure, "P13 #{role} review identity or verdict differs" unless
        review.include?("- Role: `#{role}`") &&
          instance &&
          review.include?("- Subject commit: `#{subject}`") &&
          review.include?("- Subject tree: `#{tree}`") &&
          review.include?("- Archive SHA-256: `#{archive}`") &&
          review.include?("- Mode: independent read-only") &&
          review.include?("- Verdict: `PASS`") &&
          review.match?(/^## .*Commands/m) &&
          review.match?(/^## Counterexample/m) &&
          review.include?("## Findings") &&
          review.include?("P0: none. P1: none. P2: none. P3: none.") &&
          review.rstrip.end_with?("`PASS`")
      instances << instance
    end
    raise Failure, "P13 final review instances are not distinct" unless
      instances.uniq.length == FINAL_REVIEW_FILES.length
    true
  end

  def read_closeout_file(root, relative)
    path = File.join(root, relative)
    raise Failure, "P13 closeout file is missing: #{relative}" unless
      File.file?(path) && !File.symlink?(path)

    File.binread(path)
  end

  def run_external_gates(root, allow_missing:)
    EXTERNAL_GATES.each do |relative, markers|
      path = File.join(root, relative)
      unless File.file?(path) && File.executable?(path) && !File.symlink?(path)
        next if allow_missing

        raise Failure, "required P13 subprocess gate is missing or not executable: #{relative}"
      end
      output = run_checked(root, [path], "P13 subprocess #{relative}")
      markers.each do |marker|
        raise Failure, "#{relative} omitted required result: #{marker}" unless
          output.lines.any? { |line| line.chomp == marker }
      end
    end
    INHERITED_GATES.each do |relative, contract|
      arguments, marker = contract
      path = File.join(root, relative)
      unless File.file?(path) && File.executable?(path) && !File.symlink?(path)
        next if allow_missing

        raise Failure, "required inherited gate is missing or not executable: #{relative}"
      end
      output = run_checked(
        root,
        [path, *arguments],
        "P13 inherited subprocess #{relative}"
      )
      raise Failure, "#{relative} omitted required result: #{marker}" unless
        output.lines.any? { |line| line.chomp == marker }
    end
    true
  end

  def cargo_commands
    [
      [
        "focused format",
        %w[
          fmt
          --package nlu-core
          --package ha-catalog
          --package intent-engine
          --package plan-engine
          --package session-engine
          --package policy-engine
          --package protocol
          --package nlu-server
          --
          --check
        ]
      ],
      [
        "strict clippy",
        %w[
          clippy
          --locked
          --offline
          -p session-engine
          -p policy-engine
          -p protocol
          -p nlu-server
          --all-targets
          --all-features
          --
          -D warnings
        ]
      ],
      [
        "locked tests",
        %w[
          test
          --locked
          --offline
          -p session-engine
          -p policy-engine
          -p protocol
          -p nlu-server
          --all-features
        ]
      ],
      [
        "locked builds",
        %w[
          build
          --locked
          --offline
          -p session-engine
          -p policy-engine
          -p protocol
          -p nlu-server
          --all-targets
          --all-features
        ]
      ]
    ]
  end

  def validate_cargo_command_contract(commands)
    raise Failure, "P13 Cargo command set differs" unless commands.length == 4
    labels = commands.map(&:first)
    raise Failure, "P13 Cargo command labels differ" unless
      labels == ["focused format", "strict clippy", "locked tests", "locked builds"]
    commands.drop(1).each do |label, arguments|
      raise Failure, "P13 #{label} is not locked and offline" unless
        arguments.include?("--locked") && arguments.include?("--offline")
    end
    clippy = commands.fetch(1).fetch(1)
    raise Failure, "P13 clippy is not strict" unless
      clippy.each_cons(2).any? { |pair| pair == ["-D", "warnings"] }
    tests = commands.fetch(2).fetch(1)
    raise Failure, "P13 test command does not execute tests" unless
      tests.first == "test" && !tests.include?("--no-run")
    builds = commands.fetch(3).fetch(1)
    raise Failure, "P13 build command differs" unless builds.first == "build"
    required = %w[session-engine policy-engine protocol nlu-server]
    commands.drop(1).each do |label, arguments|
      packages = arguments.each_index.each_with_object([]) do |index, selected|
        selected << arguments[index + 1] if arguments[index] == "-p"
      end
      raise Failure, "P13 #{label} package set differs" unless packages == required
    end
    true
  end

  def run_cargo_checks(_root)
    raise Failure, "P13 Cargo execution is prohibited"
  end

  def run_checked(root, command, context)
    output, status = Open3.capture2e(
      deterministic_environment(root),
      *command,
      chdir: root,
      unsetenv_others: true
    )
    return output if status.success?

    warn output
    raise Failure, "#{context} failed: #{command.drop(1).join(' ')}"
  end

  def deterministic_environment(root)
    tool_bin = File.join(root, ".tools/rust-1.98.0/bin")
    {
      "HOME" => "/var/empty",
      "PATH" => "#{tool_bin}:/opt/homebrew/bin:/usr/bin:/bin",
      "LC_ALL" => "C",
      "LANG" => "C",
      "TZ" => "UTC",
      "SOURCE_DATE_EPOCH" => "0",
      "CARGO_NET_OFFLINE" => "true",
      "CARGO_INCREMENTAL" => "0",
      "CARGO_TARGET_DIR" => File.join(root, "target/p13-gate"),
      "RUSTC" => File.join(tool_bin, "rustc"),
      "RUSTDOC" => File.join(tool_bin, "rustdoc"),
      "GIT_TERMINAL_PROMPT" => "0",
      "GIT_NO_LAZY_FETCH" => "1"
    }
  end

  def integer_constant(bytes, name)
    expression = bytes[
      /^\s*pub const #{Regexp.escape(name)}:\s*[A-Za-z0-9_:<>]+\s*=\s*([^;]+);$/,
      1
    ]
    raise Failure, "constant is missing or malformed: #{name}" unless expression
    raise Failure, "constant is not a literal integer: #{name}" unless
      expression.strip.match?(/\A[0-9][0-9_]*\z/)

    Integer(expression.delete("_"), 10)
  end

  def enum_variants(bytes, name)
    block = item_block(bytes, /pub enum #{Regexp.escape(name)}\s*/)
    body = block[(block.index("{") + 1)...-1]
    body.lines.each_with_object([]) do |line, variants|
      match = line.match(/^\s{4}([A-Z][A-Za-z0-9_]*)\b/)
      variants << match[1] if match
    end
  end

  def struct_fields(bytes, name)
    block = item_block(bytes, /(?:pub\s+)?struct #{Regexp.escape(name)}(?:<[^>]+>)?\s*/)
    body = block[(block.index("{") + 1)...-1]
    body.lines.each_with_object([]) do |line, fields|
      match = line.match(/^\s{4}(?:pub(?:\([^)]*\))?\s+)?([a-z][a-z0-9_]*):/)
      fields << match[1] if match
    end
  end

  def method_block(bytes, signature)
    item_block(bytes, /#{Regexp.escape(signature)}\s*/)
  end

  def item_block(bytes, start_pattern)
    match = bytes.match(start_pattern)
    raise Failure, "Rust contract item is missing: #{start_pattern.inspect}" unless match

    opening = bytes.index("{", match.end(0))
    raise Failure, "Rust contract item has no body: #{start_pattern.inspect}" unless opening

    depth = 0
    index = opening
    state = :code
    escaped = false
    raw_hashes = 0
    comment_depth = 0
    while index < bytes.length
      character = bytes.getbyte(index)
      following = bytes.getbyte(index + 1)
      if state == :string
        if escaped
          escaped = false
        elsif character == 92
          escaped = true
        elsif character == 34
          state = :code
        end
      elsif state == :raw_string
        if character == 34 &&
           bytes.byteslice(index + 1, raw_hashes) == ("#" * raw_hashes)
          index += raw_hashes
          state = :code
        end
      elsif state == :line_comment
        state = :code if character == 10
      elsif state == :block_comment
        if character == 47 && following == 42
          comment_depth += 1
          index += 1
        elsif character == 42 && following == 47
          comment_depth -= 1
          index += 1
          state = :code if comment_depth.zero?
        end
      elsif character == 47 && following == 47
        state = :line_comment
        index += 1
      elsif character == 47 && following == 42
        state = :block_comment
        comment_depth = 1
        index += 1
      elsif character == 114
        raw_open = index + 1
        raw_open += 1 while bytes.getbyte(raw_open) == 35
        if bytes.getbyte(raw_open) == 34
          raw_hashes = raw_open - index - 1
          state = :raw_string
          index = raw_open
        end
      elsif character == 34
        state = :string
      elsif character == 39
        character_end = rust_character_literal_end(bytes, index)
        index = character_end if character_end
      elsif character == 123
        depth += 1
      elsif character == 125
        depth -= 1
        return bytes.byteslice(match.begin(0), index - match.begin(0) + 1) if
          depth.zero?
      end
      index += 1
    end
    raise Failure, "Rust contract item is unterminated: #{start_pattern.inspect}"
  end

  def rust_character_literal_end(bytes, opening)
    index = opening + 1
    first = bytes.getbyte(index)
    return nil unless first

    if first == 92
      index += 2
      if bytes.getbyte(index - 1) == 117 && bytes.getbyte(index) == 123
        closing_escape = bytes.index("}", index + 1)
        return nil unless closing_escape

        index = closing_escape + 1
      end
    else
      width = if first < 0x80
                1
              elsif first < 0xE0
                2
              elsif first < 0xF0
                3
              else
                4
              end
      index += width
    end
    bytes.getbyte(index) == 39 ? index : nil
  end
end
