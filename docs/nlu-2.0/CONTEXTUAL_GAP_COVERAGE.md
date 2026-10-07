# Cobertura contextual — requisitos e evidências

Os dados de teste são FIXTURE_TECNICA. Não representam validação residencial.

| Seção / fase | Baseline verificado no código | Implementação concluída | Evidência de aceitação |
| --- | --- | --- | --- |
| 7 / F1 | health v1 fechado; v4 disponível | diagnóstico Rust/Python, motivos e fala específica | HTTP health/diagnóstico, renderer HA |
| 2.1–2.4 / F2 | nomes/aliases exatos, área e domínio | índice de tokens, relações, alternativas de conjuntos | Rust e executor HTTP com nomes variantes |
| 2.5, 8 / F3 | limite 32, preflight e falha parcial existentes | desligamento de área implícita, exclusões configuráveis, recusa explícita >32 | executor de 1/3/33 alvos, locks/sensores/permissões |
| 3–4 / F4 | métricas e agregados existentes | variações espaciais, fontes, unidades, resposta informativa | consultas HTTP, valores vivos, ambiguidades e ausência |
| 5 / F5 | pendência de alvo e confirmação sensível separadas parcialmente | seleção de conjunto, invalidação completa e sim/não específico | multi-turno HTTP e ConversationResult |
| 6 / F6 | device_id e indoor_tracker de pessoa | bindings pessoais, bateria e consumidor de localização dinâmica com frescor | fixtures HA autorizadas, stale, homônimos, sem provider |
| 8–13 / F7 | gate e distribuição única existentes | corpus, benchmarks, imagens, pacote, docs e revisões | comandos reais registrados no relatório final |

## Evidências funcionais

Testes Python abaixo: `tests/mlp/test_contextual_capabilities.py` (Rust HTTP real,
executor Python real, HA simulado). Testes Rust: `addon/engine/tests/contextual.rs`.

| Requisito | Implementação | Teste / resultado verificável |
| --- | --- | --- |
| 2.1 ação/categoria/escopo/qualificador/evidência separados | Command, Parameters, SelectionOption, Index | compositional_sets_compare_real_room_and_name_without_overfitting |
| 2.2 área explícita prevalece sobre origem | grammar contextual_query, resolver área | test_metric_families_prepositions_aliases_and_explicit_scope |
| 2.2 origem válida / fallback configurado | origin_area; ID HA validado | mesma matriz + regressões contextual existentes |
| 2.2 sem propriedade presumida | bindings apenas aliases; build filtra usuário | test_explicit_person_binding_only_enriches_authorized_device_rows |
| 2.3 categoria + tokens / plural / aliases / dispositivo | Index.tokens, lexical_tokens, exact name ranking | compositional_tokens_do_not_match_substrings_or_override_aliases |
| 2.4 conjuntos iguais/diferentes e nomes variantes | resolve nominal/spatial com opções | Rust Ana/João + test_set_choices_yes_no_counts_and_scope_have_no_initial_effect |
| 2.4 ambiguidade de área | área homônima não seleciona primeira | test_area_alias_collisions_climate_measured_fallback_and_setpoint_separation |
| 2.5 cômodo inteiro e formulações equivalentes | bulk_area, bulk_floor_group | test_area_family_controls_all_eligible_devices_and_never_locks_or_sensors |
| 2.5 luzes específicas não expandem aparelhos | domínio explícito | test_light_category_never_expands_to_all_appliances |
| 2.5 exclusões entidades/grupos/infraestrutura | bulk_eligible, _bulk_exclusions, critical, whitelist | test_excluded_group_and_critical_metadata_never_enter_collective_set |
| 2.5 >32 sem truncamento | target_limit: recusa inteira (alternativa normativa) | test_large_area_refuses_entire_set_explicitly_and_exclusions_are_honored |
| 2.5 preflight/inventário/estado/exposição | prepare + validate_bulk_snapshot + per-call live | test_bulk_unavailable_and_permission_revocation_prevent_any_effect; test_new_bulk_member_after_planning_invalidates_whole_plan |
| 3.1 metric query / no-na-do-da-de-em / área antes / aqui | contextual_query e seleção por classe | test_metric_families_prepositions_aliases_and_explicit_scope (nomes fictícios e quatro métricas) |
| 3.1 medição climate separada de setpoint | ambient_temperature, current_temperature, unidades | test_area_alias_collisions_climate_measured_fallback_and_setpoint_separation |
| 3.1 preferred e fontes concorrentes | Index ranking e ambiguous_source | test_measurement_sources_unavailable_invalid_and_preferred |
| 3.1 semântica equipamento/exterior configurável | measurement_kind; device_temperature preservado | test_none_aggregate_and_explicit_measurement_semantics_are_truthful |
| 3.2 ausência/indisponível/valor/unidade específicos | contextual_errors, read e exceções tipadas | test_specific_failure_speech_and_backend_failure; test_measurement_sources_unavailable_invalid_and_preferred |
| 3.2 TTS/fala final / ID | conversation._render / ConversationResult | test_conversation_result_preserves_final_speech_and_id |
| 4 globais/locais, any/list/count/all/none | grammar, render, render_list (até seis nomes + resumo) | test_global_and_local_lists_include_only_authorized_matches; test_none_aggregate_and_explicit_measurement_semantics_are_truthful; regressões global/local de test_contextual.py |
| 4 desconhecido não equivale a off | live falha antes de agregação | teste global/local + test_unavailable_exposed_fan_prevents_false_all_off_answer |
| 4 bateria baixa / limiar | render filtro percentual local | test_low_battery_threshold_is_local_configurable_and_unit_safe |
| 4 fontes energia sem sobreposição | política energy_sources preservada | test_energy_sum_requires_non_overlapping_explicit_sources |
| 5 classificação / perguntas resolutivas | clarification vs unavailable/no_match; motivos | source/partial recovery + testes de fala e ausência |
| 5 seleção vs confirmação sensível | Session.selection e confirmation independentes | test_set_choices_yes_no_counts_and_scope_have_no_initial_effect; test_sensitive_policy_authentication_and_retry |
| 5 seleção por sim/não/quantidade/nome/cômodo | pergunta com proposição explícita; choose_set | mesmo teste, zero chamada antes da escolha |
| 5 TTL/identidade/origem/opções/inventário/permissões | rebuild + reinterpretação do pedido original | test_set_pending_invalidated_by_inventory_permissions_origin_options_and_ttl; test_invalid_set_choice_and_cross_session_never_execute |
| 5 novo comando e resposta curta | _independent_command, pending command | test_new_independent_command_discards_set_pending; test_named_device_short_answer_and_permission_change_during_source_dialogue |
| 5 recuperação parcial segura | bare action pede alvo, não age | test_source_dialogue_and_partial_command_recovery |
| 6.1 pessoa/aparelho/sensores e homônimos | aliases, device_id, reference_device_id/name, bindings | test_homonymous_personal_devices_ask_and_source_choice_is_revalidated |
| 6.2 bateria por device e binding | classe/unit/faixa/live + freshness opcional | test_personal_battery_uses_device_relationship_not_sensor_name; test_battery_freshness_policy_and_invalid_percent_never_invent_reading |
| 6.3 área dinâmica, não área cadastral | device_location.read_location | test_dynamic_location_never_uses_registered_area_and_requires_observation |
| 6.3 provider ausente/oculto/desconhecido | no_location_provider/device_not_identified | test_missing_location_provider_unknown_device_and_hidden_provider |
| 6.3 binding externo e timestamp autorizado | observed_at_entity/attribute, freshness obrigatória | test_explicit_cross_device_binding_and_timestamp_entity |
| 6.3 stale/futuro/sem timezone/ambiguidade | observation_age, área real inequívoca | test_location_sources_ambiguous_and_observation_invalid_or_future |
| 7 versões/rota efetiva/emparelhamento | /diagnostics, client protocol tracking, diagnostics HA | diagnostic_endpoint_identifies_passive_service_without_private_data; test_version_pairing_and_private_data_absent |
| 7 health compatível | /health inalterado | health_endpoint_is_bounded_json |
| 8 falha parcial e retry incerto | executor preserva assinatura mesmo em timeout; não repete | test_partial_failure_inside_one_multi_target_operation; test_sensitive_policy_authentication_and_retry |
| 8 protocolos v1–v3 / Unicode / limites | contratos antigos preservados; v4 aditivo | gate oficial com corpus/HTTP/protocol/UTF-8 regressions |
| 8 desempenho e dados privados | benchmarks locais; diagnóstico sem catálogo/texto | artefatos de F7 e relatórios; nenhum ensaio residencial declarado |
| 2 área/dispositivo com nomes conflitantes | normalização espacial antes de adaptação de domínio | test_switch_plural_qualified_sets_and_same_named_room_device |
| 2 plurais de switches e conjuntos qualificados | lexical_tokens + semantic_domain | mesmo teste: interruptores e tomadas |
| 4 consultas agregadas em andares reais | grupos do catálogo + floor_id revalidado | test_aggregate_floor_questions_keep_real_membership_scope |
| 5 infinitivos/polidez/consulta sem verbo substituem pendência | detector Python + reconhecimento Rust passivo | test_infinitive_and_polite_new_commands_replace_old_selection; test_verb_free_query_discards_old_selection_and_acesa_synonym |
| 6 identidade antes de preferência/disponibilidade | device_id/reference_device_id vencedor delimita fontes | test_preferred_source_never_selects_between_homonymous_devices; test_personal_alias_identity_is_not_replaced_by_preferred_or_available_other_device |
| 8 não vazar clarificação de snapshot revogado | reautenticação + catálogo autorizado fresco | test_clarification_revalidates_names_and_sets_after_inference_or_cached_snapshot |
| Compatibilidade de famílias existentes | intenção parcial restrita; bulk_global seguro | test_existing_humidity_global_and_outlet_families_keep_operational_behavior |

Resultados numéricos finais, hashes, gate e benchmarks estão no
[relatório](CONTEXTUAL_IMPLEMENTATION_REPORT.md). Os nomes de teste acima
referem-se ao código real; nenhuma capacidade é aprovada somente por plano.

Limites explícitos: 32 alvos/operação, quatro operações/pedido; nenhuma sessão
persistente após reinício da integração; dependências de hardware/provedor
validadas com fixtures, não com Bluetooth residencial. Permissões HA continuam
obrigatórias inclusive para leitura de timestamp e localização.
