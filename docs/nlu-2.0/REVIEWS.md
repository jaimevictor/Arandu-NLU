# Revisões NLU 2.0

## Revisão contextual 0.4.0 — 2026-10-07

Duas revisões read-only independentes examinaram o mesmo código congelado,
incluindo Rust HTTP real e executor Python com Home Assistant simulado.
Produto e segurança/privacidade/licença/pacote aprovaram a árvore final após
as correções abaixo. Os 70 testes contextual/HTTP passaram. Fingerprint,
gate, benchmarks e artefatos finais constam no relatório contextual; esta
aprovação não representa teste físico de residência ou Bluetooth.

| Severidade | Contraprova | Correção e regressão |
| --- | --- | --- |
| P1 | Aspirador chamado como o cômodo interceptava desligamento coletivo | normalize_area_control antes da adaptação de domínio; test_switch_plural_qualified_sets_and_same_named_room_device |
| P1 | Infinitivo independente conservava seleção antiga, permitindo sim sobre fans anteriores | descarte por verbos/polidez e probe Rust passivo para frases sem verbo; test_infinitive_and_polite_new_commands_replace_old_selection; test_verb_free_query_discards_old_selection_and_acesa_synonym |
| P2 | preferred escolhia aparelho homônimo, ou substituía aparelho identificado por alias por outro disponível | identidade antes da fonte, conjunto limitado ao device vencedor; test_preferred_source_never_selects_between_homonymous_devices; test_personal_alias_identity_is_not_replaced_by_preferred_or_available_other_device |
| P2 | Plurais de interruptores/tomadas não resolviam conjuntos composicionais | tokens/domínios/plural normalizados; test_switch_plural_qualified_sets_and_same_named_room_device |
| P2 | Clarificação vazava nomes cuja exposição fora revogada durante await ou em cache antigo | auth/options/origem e catálogo autorizado reconstruídos antes de guardar/renderizar; test_clarification_revalidates_names_and_sets_after_inference_or_cached_snapshot |
| Lacuna lexical | luz acesa não era aceita pela família any | mesma semântica de luz ligada; test_verb_free_query_discards_old_selection_and_acesa_synonym |

Revisor de segurança repetiu a reprodução original: stale /
clarification_catalog_changed, fala sem nomes, continue_conversation=False,
zero serviços; seis testes direcionados PASS. Revisor de produto repetiu
todos os achados e a variante alias/preferred/unavailable: PASS. Nenhum
arquivo foi editado pelos revisores.

## Evidência histórica anterior à missão contextual

As seções seguintes descrevem a entrega anterior e seus fingerprints. Para
estado e limitações atuais, consulte CONTEXTUAL_IMPLEMENTATION_REPORT.md.

As duas revisões read-only exigidas por AGENTS.md partiram da mesma árvore testada. O revisor de produto concluiu e reexecutou suas contraprovas no fingerprint `a4a9b7b184d6871e3de103ab2a4fafae61fe6f57ffb551e2ff32bfbcfbe2ef61`. O revisor de segurança confirmou as correções de execução e inspecionou os hashes/limites do ZIP; encerrou por limite de uso depois de apontar a licença musl ausente. O executor incorporou os notices musl e da biblioteca padrão Rust, validou novamente a imagem e o pacote e concluiu a estabilização do steering. Não se afirma uma segunda revisão independente integral da árvore final após essa interrupção.

## Achados e correções

| Severidade | Achado concreto | Correção e regressão |
|---|---|---|
| HIGH | Binding revogado durante await de interpretação ainda usava opções antigas | Snapshot JSON imutável de opções; comparação após await/antes de efeito, hash na confirmação; `test_replaced_binding_policy_during_inference_is_revoked` |
| HIGH | Serviço podia aplicar efeito e lançar timeout; retry repetia a ação | Assinatura da tentativa antes do envio, sem inventar sucesso; retry imediato bloqueado; `test_failed_service_acknowledgement_does_not_repeat_attempt` |
| MEDIUM | Valor relativo do segundo alvo podia mudar depois da primeira chamada, mas receber ajuste antigo | Recalcular e comparar chamada por alvo imediatamente antes do envio; parcial e interrupção; `test_relative_multi_target_rechecks_each_value_after_prior_call` |
| MEDIUM | Consulta global/área explícita usava apenas o cômodo de origem | Queries plurais globais sem redução implícita, cauda de área preservada; `test_global_aggregates_and_explicit_query_area_override_origin` |
| MEDIUM | Indisponível sumia do catálogo, permitindo falso “todos desligados” | Descritor query-only permanece; leitura desconhecida abstém; `test_unavailable_exposed_fan_prevents_false_all_off_answer` e `test_steering_all_lights_global_local_and_unknown` |
| MEDIUM | Resposta ausente de calendário/todo virava lista vazia | Validar entidades exatas, campos/listas/limites, sem expor entidade extra; `test_list_response_requires_requested_entities_and_explicit_empty_list` |
| MEDIUM | “Aumenta dois graus” aplicava incremento padrão de um grau | Extrair magnitude explícita com referência recente; `test_steering_explicit_climate_area_negation_and_recent_relative_target` |
| MEDIUM | Imagem estática não preservava aviso completo musl | Notices upstream intactos em addon/licenses e /licenses/runtime; hashes em THIRD_PARTY_NOTICES.md; inspeção da imagem e ZIP |
| LOW | Forma “Todas as luzes...” não reconhecida, apesar de existir agregação ALL | Forma adicionada ao caminho existente; regressão global/local/indisponível no E2E |
| MEDIUM | ZIP tratava atributos Rust `#![no_std]` como shebang e atribuía modo executável incorreto a arquivos vendorizados | Detectar somente shebang real `#!/`/`#! /`; validação exata das dependências e gate a partir do ZIP extraído |
| LOW | ZIP criado no Windows anunciava FAT apesar de conter modos Unix | Definir create_system=3; verificar modo/creator na extração do pacote final |
| LOW | ZIP omitira seis fixtures sintéticas necessárias aos testes Rust legados | Incluir somente snapshots/corpora usados pelos testes; gate completo a partir do pacote confirma compatibilidade |
| INFORMATIONAL | CRLF em checkout Windows fazia git diff --check apontar linhas inteiras como whitespace | Staging e shebangs normalizados em LF; `git -c core.whitespace=cr-at-eol diff --check` validou o checkout sem descartar modificações |

CRITICAL: nenhum identificado. HIGH e MEDIUM relacionados a autorização/execução/integridade: corrigidos, com regressões. Sem pendência conhecida dessas severidades na entrega local.

## Regressões A–J do steering

- A: “máquina” em `addon/engine/tests/contextual.rs`, corpus regression; “aqui” só é removido como palavra.
- B/C/D: `test_steering_all_lights_global_local_and_unknown`, Rust real HTTP com duas áreas; indisponibilidade permanece desconhecida.
- E: tentativa incerta não repetida e operação_count zero sem confirmação do serviço.
- F: calendário solicita duração e só depois envia start/end reais; E2E de diálogo existente.
- G: confirmação isolada por usuário, origem, conversation_id e TTL; teste ampliado para outra conversa.
- H/I: ar do quarto com origem na sala e negação sem efeitos; E2E de steering.
- J: ambiguidades preservadas nos testes Rust contextual e no E2E de ventiladores; nenhuma seleção arbitrária.

## Limitações de validação

Home Assistant e serviços são simulados nos testes de executor; Rust HTTP e imagem scratch são reais. Não houve alteração de HA residencial. ARM64 e UI real do HA não foram executados. O requisito de usuário ativo identificado pode impedir pipelines/satélites que não fornecem user_id. O corpus incorpora templates usados pelo motor; sua cobertura não é acurácia independente.

Fingerprint final estabilizado: `18909fef2fd43649bb6412f63b40a36309c73634d5f41ecf64956505ff1ef02f`. Após a revisão independente, o steering adicionou duas regressões obrigatórias ao E2E e corrigiu somente suas lacunas, os notices e a ferramenta de empacotamento. O executor fez o read-back final; a limitação da revisão independente posterior permanece explícita.
