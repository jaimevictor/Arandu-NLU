mode: MLP
current_phase: MLP
state: FINAL_MLP_DELIVERED
superseding_decision: USR-048
active_adr: ADR-0050
historical_baseline: d1654dede675fe49d37f0671f6160761ea33448d
release_subject_commit: 86e19910481c4d0b3b008002728938b3ad3a9fd3
release_subject_tree: 624dd3cc70d13280deb37ab189bd9923e6104632
scope:
  effect_domains: [light, switch, fan]
  read_domains: [light, switch, fan, sensor, binary_sensor]
  actions: [turn_on, turn_off, set_fan_percentage, get_state]
  plan: up_to_four_ordered_operations
  target: up_to_four_entity_or_area_clauses_per_operation
  matching: deterministic_exact_alias
gate: ./tools/mlp-check
last_validation: MLP_CHECK_PASS_2026-09-12
release_reviews:
  - correctness_and_fail_closed: PASS
  - security_privacy_licensing_package: PASS
accepted_limitations:
  - OCI_IMAGE_NOT_EXECUTED_NO_LOCAL_CONTAINER_ENGINE
goal: FINAL_MLP_DELIVERED
terminal_guard: RETIRED_BY_USR_048
