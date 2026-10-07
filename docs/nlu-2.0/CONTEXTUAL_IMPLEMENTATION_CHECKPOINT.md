# Checkpoint — Arandu NLU contextual

- Data: 2026-10-07. Branch: `fix/unify-distribution-0.3.2`.
- HEAD inicial: `904de44367a36b21925ac0bc5309c0627a078830`.
- Versões iniciais: add-on/integração 0.3.2; protocolos v1–v4.
- Alterações preexistentes preservadas: `docs/codex/`, `tools/codex-skill-check.ps1`, `docs/nlu-2.0/ARANDU_NLU_CONTEXTUAL_CAPABILITIES_SPEC.md` (não rastreados).
- Especificação: o arquivo encontrado foi copiado integralmente para `CONTEXTUAL_CAPABILITIES_IMPLEMENTATION.md`; somente seu checklist final foi atualizado. Original do usuário preservado.
- Fase atual: F7 concluída. Fases concluídas: F0, F1, F2, F3, F4, F5, F6 e F7.
- Arquitetura: Rust passivo em `addon/engine/src/contextual`; Python autoriza, revalida, executa e renderiza em `custom_components/local_nlu`.
- Lacunas iniciais corrigidas: resolução composicional/comparação de conjuntos, agregação informativa, consumidor de localização dinâmica, motivos específicos e diagnóstico do binário.
- Funcionalidades existentes preservadas: cache v4, contratos v1–v3, preflight completo, política sensível, confirmação, execução parcial sem retry automático, medições climate separadas de setpoints.
- Baseline host: `python -m unittest discover -s tests/mlp -p 'test_*.py'`: 100 testes, 11 falhas, 6 erros, 9 skips. Python 3.10 sem `asyncio.timeout`/`tomllib`; resultado não é baseline do ambiente suportado.
- Baseline e gate final concluídos no container `arandu-context-dev`, Python 3.12/Rust 1.98; `tools/mlp-check` PASS. Evidências detalhadas abaixo.
- Ambiente: Docker Linux disponível e imagens de desenvolvimento/add-on locais; HA residencial e hardware BLE não fornecidos. Nenhuma validação física presumida.
- Próxima ação: finalizar commit seletivo/push autorizado e verificar igualdade HEAD ↔ origin/master. Não há requisito contextual implementável pendente.
- Retomada: `docker exec arandu-context-dev sh -c 'cd /workspace && ./tools/mlp-check'`; código montado read-only em `/source`, staging Linux em `/workspace`, artefatos em `target/`.
- Push direto para master explicitamente autorizado pela última instrução do usuário; somente após F7 validada, sem force push.

## F0 concluída

- Implementado: inventário, especificação no destino normativo, matriz inicial e checkpoint.
- Arquivos: `CONTEXTUAL_CAPABILITIES_IMPLEMENTATION.md`, `CONTEXTUAL_GAP_COVERAGE.md`, este checkpoint.
- Baseline suportado real: 108 testes Python OK (9 HTTP skips antes do build); fmt/clippy OK; 90 testes Rust OK (51 unitários + 39 integração), corpus e HTTP v1–v3 incluídos. Pacote/vendor/versões/corpus reproduzível OK.
- Build release e smoke HTTP final seguem no mesmo comando de baseline; registrar resultado quando terminar.
- Problemas: nome original da especificação difere do solicitado; Python host 3.10 incompatível. Resolvido usando a especificação encontrada e o ambiente oficial Docker.
- Pendências: F1–F7, hardware residencial ausente.
- Próxima ação exata: adicionar `/diagnostics` em `server.rs`, client Python e renderer de motivos; criar testes específicos F1.
- Comando: `docker exec arandu-context-dev sh -c 'cd /workspace && cargo test --test http --locked --offline'` e testes Python após sincronizar arquivos de `/source`.

## F1 concluída

- Funcionalidades: `/diagnostics` Rust read-only (versão, protocolos, build_id opcional, execução passiva), cliente local validado, diagnóstico HA com rota/protocolo/versão efetiva e alerta de incompatibilidade; renderer comum de motivos; preservação da fala e ID em ConversationResult.
- Arquivos: `addon/engine/src/server.rs`, `addon/engine/tests/http.rs`, Python `client.py`, `contextual_runtime.py`, `contextual_errors.py`, `diagnostics.py`, `conversation.py`; `tests/mlp/test_contextual_capabilities.py`.
- Testes reais: `cargo test --test http --locked --offline`: 5/5 OK; testes específicos Python: 3/3 OK (9 HTTP importados ainda skipped antes do rebuild). Regressão `/health` OK. Baseline completo F0 terminou com MLP CHECK PASS e 32 testes contextual/HTTP OK.
- Problemas: Python host permanece inadequado; usa-se container oficial. Build fingerprint ausente é declarado `unknown`, não inventado.
- Pendências: F2–F7, testes físicos externos ausentes.
- Próxima ação: índice composicional e alternativas de conjuntos no resolvedor Rust, contratos v4 aditivos e fixtures F2.
- Comando: `docker exec arandu-context-dev sh -c 'cd /workspace && cargo test --test contextual --locked --offline'`.

### Evidência adicional F1/F2 em andamento

- Suíte Python ampla após F1: 120 testes, 4 erros de distribuição e 18 skips; os erros são o digest/versionamento esperado após mudanças de produto, a fechar com nova versão e `distribution.py --record` na F7. Não registrados como PASS.
- F2 testes específicos isolados: 2 novos Rust e 2 novos Python passaram. Execução concorrente identificou colisão de gerações entre fixtures novas e antigas; corrigidos identificadores das fixtures novas (sem mudar os resultados esperados).

## F2 concluída

- Funcionalidades: índice invertido de tokens normalizados (plurais controlados, sem substring); seleção por nome/alias/device_name, domínio e capacidade; área explícita prevalente; comparação de conjuntos por nomes vs área real; alternativas v4 aditivas com alvos, escopo e evidências; aliases configurados e `person_device_bindings` limitados ao catálogo autorizado.
- Arquivos: Rust `contextual/{contract,resolver,mod}.rs`, `tests/contextual.rs`; Python `contextual_catalog.py`, `contextual_protocol.py`, `config_flow.py`, `tests/mlp/test_contextual_capabilities.py`.
- Testes: 9/9 Rust contextual OK; clippy workspace/all-targets -D warnings OK; 5 testes Python específicos OK (3 F1 + 2 F2; 9 HTTP skips importados).
- Problemas resolvidos: colisões entre gerações das fixtures. Resultados esperados preservados.
- Pendências: renderização/seleção conversacional das alternativas será concluída na F5; F3–F7.
- Próxima ação: controle coletivo de área e exclusões no resolvedor/catalog/runtime, testes executor HTTP com 1/3/33 alvos.

## F3 concluída

- Funcionalidades: área implícita e explícita convergem a desligamento coletivo; categoria luz preservada; whitelist de domínios e exclusões configuráveis por entidade; preflight integral e comparação de inventário vivo antes de efeitos e entre chamadas; indisponível recusa todo conjunto; >32 recusa explícita, sem truncamento (alternativa permitida pela especificação).
- Arquivos: Rust `resolver.rs`, `mod.rs`; Python catálogo/protocolo/runtime/errors/config_flow; testes HTTP em `test_contextual_capabilities.py`.
- Testes reais: rebuild release OK; 10/10 testes F1–F3 Python com Rust HTTP OK, incluindo 1/3/33 alvos, locks/sensores, luzes específicas, revogação de exposição e novo membro entre planejamento e execução. Zero efeitos em todas as recusas.
- Problemas resolvidos: seletor residual `aparelhos` causava recusa de uma variante; normalizado genericamente.
- Pendências: F4–F7. Política de parcial/retry já existente será novamente incluída no gate completo F7.
- Próxima ação: consultas métricas genéricas, prioridade/ambiguidade das fontes, unidades e agregação informativa em grammar/resolver/queries/runtime.
- Comando: rebuild release e `ARANDU_NLU_BINARY=/workspace/target/release/local-nlu python3 -m unittest discover -s tests/mlp -p test_contextual_capabilities.py`.

## F4 concluída

- Funcionalidades: consultas ambientais genéricas com no/na/do/da/de/em/aqui e área antes da pergunta; temperatura medida (não setpoint), umidade/luminosidade/CO2; fonte preferred, preferência estável por sensor ambiental e esclarecimento de fontes múltiplas; unidades/faixas validadas; ausência/indisponibilidade/medição inválida tipadas; listagens/existência com nomes e áreas, limite informativo; bateria baixa com limiar configurável.
- Arquivos: Rust grammar/resolver; Python queries/runtime; testes parametrizados `test_contextual_capabilities.py`.
- Testes reais: 14/14 F1–F4 com Rust HTTP/executor simulado OK (matriz interna com dois nomes/cômodos fictícios e quatro métricas); 32/32 regressões contextual existentes OK; clippy completo OK. Build release OK.
- Problemas: nenhum erro aberto nesta fase. Não interpreta unknown/unavailable como off; não revela sensores ocultos.
- Pendências: F5–F7; diálogos com fontes e conjuntos serão finalizados na F5.
- Próxima ação: implementar pendência tipada de seleção de conjuntos, revalidação e resposta sim/não inequívoca; testes multi-turno e expiração.

## F5 concluída

- Funcionalidades: pendência de seleção com opções/alvos/escopo/evidências/pergunta e semântica sim=área/não=nome explicitada na fala; confirmação sensível independente; escolhas por quantidade/área/nome; reinterpretação Rust original e rebuild autorizado antes do efeito; pendências vinculadas a geração/origem/opções/usuário/conversa/TTL; novo comando cancela pendência; intenção parcial `desliga` pede alvo sem efeito; fontes e nomes aceitam resposta curta.
- Arquivos: Python `contextual_runtime.py`, testes capabilities; Rust grammar/mod.
- Testes reais: 20/20 acceptance HTTP/Python OK; 32/32 regressões contextual OK; clippy completo OK. Matriz inclui sim/não, conjuntos iguais/diferentes, nome/área conflitantes, mudança de inventário/permissão/origem/opções, TTL, outra sessão/satélite, três turnos e resposta curta `da mesa`.
- Problemas resolvidos: respostas de escolha não podem citar outro cômodo/proprietário para executar; inválidas repetem pergunta e mantêm zero efeitos.
- Limite real: sessão em memória se perde após reinício da integração/HA; reiniciar somente a pipeline mantendo conversation_id/usuário/origem continua enquanto TTL válido. Não há autorização persistente.
- Pendências: F6–F7.
- Próxima ação: bindings pessoa/dispositivo/sensores, consulta battery por device_id, consumidor de área dinâmica e timestamp last_seen configurável, fixtures freshness/provider/permissões.

## F6 concluída

- Funcionalidades: relações HA device_id/device_name e bindings declarativos (inclusive sensor em outro dispositivo); bateria com nome bruto independente, unidade/faixa/estado/permissões e frescor configurado; localização de telefone/celular/tablet/notebook por entidade HA dinâmica, descoberta Bermuda Area ou binding explícito; timestamps ISO com timezone/epoch ou entidade timestamp autorizada; rejeita last_changed, valores futuros, antigos ou inexistentes; nunca usa área estática como localização física.
- Arquivos: Rust grammar/resolver; Python `device_location.py`, catálogo/protocolo/runtime/queries/errors/config_flow; fixtures capabilities.
- Testes reais: 27/27 acceptance F1–F6 Rust HTTP/executor simulado OK; 32/32 contextual existentes OK; clippy completo OK após corrigir collapsible_if. Bateria, homônimos, meus aliases explícitos, cross-device, provider ausente/oculto, fonte timestamp oculta, movimento entre cômodos, fonte ambígua, unidade/faixa e timestamps inválidos cobertos.
- Referência primária conferida: `https://github.com/agittins/bermuda/blob/main/custom_components/bermuda/sensor.py`: Area publica área; timestamp last_seen não garantido. Adapter exige timestamp real configurado quando não publicado, sem usar Area Last Seen como timestamp.
- Limitações reais: HA residencial/BLE físico não disponível; fixtures validam consumo, não triangulação física. Fonte de bateria sem política temporal explícita usa valor vivo HA e não afirma horário de observação.
- Pendências: F7 (gate/corpus/benchmarks/build/pacotes/docs/revisões/push autorizado).
- Próxima ação: sincronizar versão 0.4.0, registrar distribuição e executar gate oficial; corpus 1.946/165 e benchmark 4.096; produzir artefatos/documentação e revisar o mesmo tree.

## F7 em andamento — fechamento das contraprovas

- Versão sincronizada: 0.4.0; protocolos 1–4. Push direto para master autorizado explicitamente pelo usuário; não fazer force push nem deploy.
- Dois reviews read-only detectaram quatro falhas de produto (colisão área/vacuum; infinitivo conserva pendência; preferred escolhe telefone homônimo; plurais de switches) e uma de privacidade (clarification renderiza snapshot cuja exposição foi revogada). Corrigidas com testes reais HTTP/Python. A reavaliação final ainda será solicitada após congelar o tree.
- Implementações adicionais: área coletiva normalizada antes de adaptação do domínio; identidade do aparelho antes de preferred/availability; plurais interruptores/tomadas; sinônimo luz acesa; novo comando sem verbo confirmado pelo Rust descarta pendência; rebuild autorizado antes de renderizar clarificação, inclusive cache antigo; bulk_global aplica exclusões/preflight; intenção parcial não bloqueia tomada/casa explícitas.
- Corpus completo executado: 1.946 casos/165 intents. Último resultado provisório: linguistic=1942, semantic=1905, planning=1896, operational_simulated=1903. Diagnóstico encontrou consultas de floor interceptadas como consultas de room; correção específica em validação. Uma frase legacy phone_find agora consulta localização: sem alias/provider deve recusar, não disparar ringtone arbitrariamente.
- Fixtures do avaliador corrigidas: get_forecasts retorna horizonte de oito dias a partir do relógio HA; andares são floor_registry/floor_id reais simulados, não uma área com nome de andar. Nenhum resultado esperado é derivado da saída do NLU.
- Testes após reviews: 68 contextual/HTTP PASS; clippy PASS. Novo teste floor aguardando o rebuild atual. Gate final deverá ser repetido após essa correção, pois o fingerprint anterior não representa o tree final.
- Builds preliminares amd64/aarch64 PASS, porém anteriores às últimas correções: não são a evidência de entrega final. Benchmarks preliminares executados, também serão substituídos pela medição do tree final.
- Arquivos F7: versões/lockfiles/manifest/README/INSTALL/DEPLOYMENT/CHANGELOG/labels; tools/mlp-check/check-mlp-package/contextual-evaluate/contextual-image-smoke; testes e correções Rust/Python mencionadas; docs de checkpoint/matriz/relatório/especificação copiada intacta.
- Próxima ação exata: aguardar comandos Docker ativos, copiar Rust formatado ao host, validar 69 testes contextual, rerodar corpus e gate; congelar tree para os dois reviews; medir benchmarks sem build concorrente; rebuild amd64/aarch64 e smoke; gerar ZIPs; registrar evidência JSON/docs; commit seletivo e push normal HEAD:master.
- Comandos: `docker exec arandu-context-dev sh -c 'cargo fmt --all && cargo clippy --workspace --all-targets --locked --offline -- -D warnings && cargo build --release --locked --offline'`; testes com `ARANDU_NLU_BINARY=/workspace/target/release/local-nlu`; corpus via `tools/contextual-evaluate.py --corpus-csv /output/contextual-corpus.csv --output /output/contextual-coverage.json`; gate `./tools/mlp-check`. Logs em `target/contextual-0.4.0-*.log`.
- Retomada: container `arandu-context-dev` usa /source readonly e /workspace staging; copiar arquivos alterados antes de testar. Para registrar digest desta versão ainda não commitada, restaurar SOMENTE `/workspace/release.json` usando `git show HEAD:release.json > release.json` no container, depois `python3 tools/distribution.py --record`; copiar release.json final ao host. Não reverter arquivos de produto.
- Git: origin/master foi fetched e possui um commit merge acima de HEAD, com árvore idêntica. Antes de commit, `git merge --ff-only origin/master` é possível sem alterar conteúdo. Preservar untracked originais docs/codex, tools/codex-skill-check.ps1 e ARANDU_NLU_CONTEXTUAL_CAPABILITIES_SPEC.md; nunca `git add .`.

## F7 concluída — evidência final

- Funcionalidades: todas as capacidades das seções 2–8 implementadas e exercitadas conforme matriz. Área coletiva, conjuntos, consultas, diálogo, diagnóstico e adaptadores pessoais funcionam com Rust HTTP real + executor Python simulado; não dependem de LLM/cloud. Limite >32 recusa todo controle explicitamente, sem truncamento.
- Última variante de review corrigida: identidade do device vencedor por alias limita candidates antes de provider/preferred/availability; uma fonte indisponível não permite trocar aparelho. Dois reviews read-only aprovaram o mesmo código final, sem achados materiais abertos.
- Arquivos finais: Rust contextual contract/grammar/mod/resolver, server e testes; Python client/config_flow/catalog/protocol/runtime/conversation/queries e novos contextual_errors/device_location/diagnostics; test_contextual_capabilities; ferramentas gate/package/evaluate/image-smoke; versões sincronizadas; docs README/INSTALL/DEPLOYMENT/REPORT/REVIEWS/especificação/matriz/relatório/checkpoint; data/contextual coverage/benchmarks/image/package e novo contextual-validation.json.
- Gate real `./tools/mlp-check`: PASS. 93 Rust; 146 Python únicos. Primeiro passe teve 42 skips HTTP; todos foram executados no segundo passe de 70 contextual/HTTP, incluindo 38 novos testes. fmt/clippy -D warnings/vendor/corpus/package/distribution/health/HTTP v1–v4/smoke PASS.
- Fingerprint executável testado, idêntico no host e staging: `04165cf4af8fc290edd7ff015dfd5358c24f0dd6cc9c99b242a2f0ec61fbb87c`. Distribuição release.json: `d7abcb62ed457fe6ad38ec3a6467a227fb978d6dd0142a5c33e1bec9ce32a7f5`.
- Corpus externo congelado/SHA validado: 1946 frases/165 intents; linguistic=1942, semantic=1910, planning=1901, operational_simulated=1908. 38 sem conclusão no turno: 22 continuidade, 6 contexto, 4 configuração/fonte, 2 ambiguidades, 2 recusas seguras, 2 declarações de estado no_match já existentes. Não há claim de acurácia independente/100%/residência real. CSV/JSON guardam todos os casos, parâmetros e categorias.
- Benchmark final sem builds concorrentes: 4096 entidades, Rust puro P50/P95/P99=1.8023/2.1624/2.9431 ms; HTTP/executor quente=0.8779/1.0580/1.1652 ms em workload distinto; RSS Rust 17484 kB. Snapshot Python frio P95=116.0444 ms e registro HTTP=83.5136 ms: custo não incluído no pedido quente. Dados integrais em data/contextual/benchmark-*.json.
- Builds finais amd64 e aarch64 PASS; aarch64 executada por emulação Docker, não ARM nativo. Smokes das duas imagens e da imagem amd64 criada do ZIP PASS, incluindo versão efetiva/health/v4/query/bulk. Runtime licenses extraídas e comparadas PASS; usuário 65534:65534, network isolada sem porta de host.
- ZIP addon (612 arquivos), SHA `d159da2485a8f5530487dba0421bb13b6f25d7525440103e16cdc43c229b1561`; ZIP integração (22 arquivos), SHA `197d0cb94bf73bf429b6571a6117b48c9c2d6f2aa0205d12243ad069a44659a3`. Caminhos: target/dist/0.4.0/. CRC/modos Unix/bytes/versões e duas gerações byte-idênticas PASS. Integração extraída: 70 testes PASS usando fixtures do repositório; não se afirma gate standalone no ZIP. Loja isolada gerada com tools/make-store-repo.py, 611 arquivos em addon/.
- Problemas encontrados: host Python3.10 inadequado, colisão de gerações em fixtures, digests/versionamento durante desenvolvimento, regressões de floor/fixtures temporais e achados dos reviews. Todos os problemas materiais das capacidades contextuais foram corrigidos; detalhes anteriores mantidos para auditoria.
- Limitações reais: sem HA residencial/BLE físico; provider/timestamp precisam existir e estar autorizados. Sessões efêmeras; catálogo frio tem custo; quatro operações/32 alvos; duas declarações de estado do corpus permanecem no_match. Não existe reversão física atômica nem retry de efeito incerto.
- Pendências de implementação: nenhuma nas capacidades solicitadas. Deploy residencial/release/upload de imagem não realizados e não autorizados. Untracked originais do usuário continuam preservados.
- Git base avançada por fast-forward para `a443e8f18a44ba3eb49ef6c5a871fc1e38ddea54`, árvore idêntica ao ponto inicial; não foi preciso merge de conteúdo ou descartar mudanças. Push direto para master autorizado pelo usuário.
- Próxima ação exata de entrega: staging seletivo dos arquivos desta missão, `git commit -m "feat: implement contextual capabilities for NLU 0.4.0"`, `git push origin HEAD:master`, comparar `git rev-parse HEAD` e `git ls-remote origin refs/heads/master`. Se já coincidem, entrega concluída; não repetir implementação/auditorias/gate sem alteração de código.
- Comandos de retomada/verificação: `git status --short`; `git log -1`; `git ls-remote origin refs/heads/master`; `pwsh -File tools/mlp-dev.ps1 -Task check` somente se necessário. Container dev e artefatos target disponíveis; interromper os três containers de smoke antes de reutilizar portas do namespace dev.
