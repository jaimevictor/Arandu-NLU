# Auditoria de comandos espaciais — preparação local 0.4.4

Data: 2026-10-13. Base local e `master` remoto verificados em
`32eeaaf25d05498aa9e9b27163cd333de8f4c8fc`, versão 0.4.3.
Trabalho no checkout `fix/unify-distribution-0.3.2`; os arquivos previamente
não rastreados foram preservados. A auditoria foi concluída sem push, tag,
release ou comando residencial. O envio posterior das correções para `master`
foi autorizado pelo usuário; criação de tag e publicação de release permanecem pendentes.

## Comportamento implementado

`liga a sala`, `liga todos os dispositivos da sala` e `liga tudo na sala`
produzem a mesma seleção espacial. `desliga` aplica a mesma política à sua
capacidade inversa. O conjunto pode diferir quando um dispositivo oferece
somente uma das capacidades: a simetria é de política, não de recursos inventados.

Categorias plurais, comandos de andar e esclarecimentos de conjuntos aplicam
exclusões, `critical`, `bulk_eligible=false`, `bulk_domains`, exposição e
permissões. Domínios coletivos: light, switch, fan, climate, media_player e
humidifier. Sensores, proteção, covers, automações, cenas e scripts não entram
no acionamento de cômodo. Serviços e features reais determinam capacidades.
Alvos são ordenados; o limite permanece 32, sem truncamento. Um membro elegível
indisponível invalida a operação completa antes de qualquer efeito.

`luz`, `luzes`, `iluminação` e `lâmpadas` significam `light.turn_on` de todas
as luzes elegíveis no cômodo de origem. `ventilador` e `ventiladores` usam fan.
A lista é fechada na gramática Rust; nomes livres não criam ações. Comandos
implícitos exigem satélite registrado habilitado com área válida ou dispositivo
registrado com área válida. `default_area` e origem desconhecida não autorizam
esses comandos. A resposta é “Em qual cômodo?”, sem serviços; uma resposta
explícita de cômodo pode completar o pedido. A ativação sempre usa turn_on,
nunca toggle. A repetição recente continua sendo suprimida pelo executor.

`liga as luzes` e `desliga as luzes` preferem a área de origem quando a frase
não traz área explícita. `liga as luzes do quarto` prevalece sobre o satélite
da sala. “aqui”, “desse cômodo” e “onde estou” ficam limitados à área contextual.
Não foi acrescentada política de ativação global: ativação coletiva exige
área ou grupo espacial resolvido. O desligamento global existente permanece
submetido às suas exclusões e capacidades; não é reduzido silenciosamente à
área do satélite.

## Causas e gaps auditados

| Gap | Causa e disposição |
|---|---|
| Cômodo liga/desliga assimétrico | Normalização, seleção bulk e executor limitavam bulk a turn_off. Corrigido nos três pontos. |
| Plurais e andares ignoravam exclusões | Nem toda seleção plural recebia metadados bulk. Política Rust compartilhada e verificação Python agora cobrem os caminhos. |
| Esclarecimento perdia política | A reconstrução Python de uma escolha perdia o escopo coletivo, principalmente com um alvo. Corrigido, com categoria e evidência conservadas. |
| Área confundida com scene/script homônimo | Hint nominal podia escolher templates de ativação antes de resolver o cômodo. Hint espacial precede nomes para controle de cômodo, inclusive pedidos educados e infinitivos. “liga a cena X” conserva ativação explícita de cena. |
| Cômodo marcado como andar | Template de andar também podia capturar um nome de área. O escopo do plano agora depende do ID espacial realmente resolvido. |
| Palavra curta sem verbo | Faltava intenção determinística fechada. Adicionada infraestrutura de categorias implícitas light/fan. |
| Origem sem procedência | Um único string mesclava satélite, dispositivo e default. Contrato v4 recebe procedência e Python revalida área e fonte. |
| Compatibilidade HA 2025.3 | Input tem device_id, mas não satellite_id; resultado não tem continue_conversation. A origem por dispositivo é aceita e o construtor de resposta passa continuação apenas quando o contrato suporta. Não há continuação automática de pipeline naquela versão. |
| Membro indisponível omitido | Política aplica a recusa tanto ao cômodo quanto à categoria. Exclusões explícitas não causam recusa por indisponibilidade de membros excluídos. |
| Plano incompleto na fronteira | Evidência de conjunto espacial completo é preservada; Python calcula o conjunto esperado e rejeita divergência antes dos serviços. |
| Prefixo de ativação na transcrição | Assist encaminha texto STT sem remoção textual garantida. Limpeza opcional, exata e limitada no transporte, descrita abaixo. |
| Singular/plural e artigos | Formas existentes permanecem; plurais de categoria selecionam o conjunto, nomes individuais explícitos mantêm seleção nominal. Testes incluem IDs individuais excluídos de bulk. |
| Ligar/desligar, acender/apagar, ativar/desativar | Mesma resolução de potência quando linguisticamente equivalentes; infinitivos acender/apagar/ativar/desativar acrescentados à canonicalização. |
| Abrir/fechar | Já coberto por adapters de capacidade de cover e regras de proteção. Não transformado em liga/desliga nem incluído em bulk de cômodo. |
| Aumentar/diminuir | Já coberto por parâmetros relativos tipados; valores atuais, limites, units/features e revalidação continuam no Python. Não geradas inversas para ações irreversíveis. |
| Compostos e elipse com preposição | Cobertura existente mantida: até quatro operações, ordem falada, elipse “e do quarto” e recusa de reutilização contraditória. “liga sala e quarto” sem ação/preposição na segunda cláusula não ganhou interpretação permissiva; usar “liga sala e liga quarto”. |
| Grupos espaciais | Rust admite grupos tipados; Python materializa andares reais do HA. Grupos arbitrários de áreas por nova configuração permanecem fora deste patch: não existe contrato de configuração/lifecycle equivalente no catálogo atual. |
| Casa inteira ativada | Deliberadamente sem nova autorização global. Pedido sem delimitação espacial esclarece ou recusa. |
| Categorias sensíveis implícitas | Fora de escopo por política. Palavras de fechadura, portão, alarme, câmera e outras categorias não autorizadas não produzem efeito. |
| Intenções sem serviço universal | Bindings explícitos, Music Assistant, consultas e autenticação de proteção continuam condicionais. Reconhecimento não equivale a serviço disponível ou autorização. |

## API Assist e extensão v4

Fonte primária conferida: [ConversationInput 2025.3.0](https://github.com/home-assistant/core/blob/2025.3.0/homeassistant/components/conversation/models.py)
e [ConversationInput 2026.9.4](https://github.com/home-assistant/core/blob/2026.9.4/homeassistant/components/conversation/models.py),
com confirmação na versão publicada [2026.10.1](https://github.com/home-assistant/core/blob/2026.10.1/homeassistant/components/conversation/models.py).
As três incluem device_id; 2026.9.4 e 2026.10.1 também incluem satellite_id.
2025.3.0 não tem satellite_id nem continuação automática de ConversationResult;
o código usa getattr conservador para origem e verifica campos do resultado.
O [pipeline 2026.9.4](https://github.com/home-assistant/core/blob/2026.9.4/homeassistant/components/assist_pipeline/pipeline.py)
repassa os dois à construção de ConversationInput. A integração já preservava
esses campos, incluindo inputs com slots e a substituição de identidade autorizada.
O [processador padrão 2026.10.1](https://github.com/home-assistant/core/blob/2026.10.1/homeassistant/components/assist_pipeline/default_pipeline.py)
conserva o repasse após a extração do pipeline para módulos separados.
`satellite_id` é entity_id `assist_satellite.*`; `device_id` é ID do device registry.
Área de entidade tem precedência sobre área de dispositivo, conforme HA.

Campo aditivo: `origin_area_source`, com satellite, device, default ou unknown.
Ausência é válida para clientes v4 anteriores; não autoriza comandos implícitos.
Valores desconhecidos invalidam a requisição. Não há alteração aos modelos
ou endpoints v1/v2/v3. Planos preservam ação, intenção, alvos e evidência;
parameters traz área, escopo bulk e categoria quando única. Python valida a
categoria contra o domínio real e o escopo contra a associação atual.

O pipeline distingue wake word de STT, mas retorna `SpeechResult.text` ao agente
sem um filtro textual geral de palavras de ativação. O áudio encaminhado pode
incluir buffer anterior e áudio pendente: não se presume que todo provedor
remova a palavra. ConversationInput não carrega o prefixo detectado.

Por isso `wake_words` é uma lista opcional, inicialmente vazia, nas opções
da integração. Exemplo: `["Alexa"]`. Só remove um prefixo exato no início,
delimitado por espaço, vírgula ou dois-pontos, com origem espacial confiável.
Não remove “Alexandra”, não procura palavras no meio da frase e não repete
a remoção. O input original é preservado. A intenção continua sendo Rust.
Não há leitura de cookies, credenciais ou API de fabricante.

## Matriz de aceitação

Todos os cenários abaixo usam motor Rust real por HTTP e executor Python real,
com serviços/registries/usuários HA simulados, em `test_contextual_spatial.py`.
Os testes são FIXTURE_TECNICA de aceitação; não constituem acurácia linguística
independente ou validação residencial.

| Entrada | Contexto | Verificação |
|---|---|---|
| Liga a sala | Origem cozinha | Lights e fan elegíveis da sala, turn_on |
| Desliga a sala | Origem cozinha | Mesmo escopo, turn_off |
| Liga todos os dispositivos da sala | Origem cozinha | Mesmo conjunto do cômodo |
| Desliga todos os dispositivos da sala | Origem cozinha | Mesmo conjunto do cômodo |
| Liga todas as luzes da sala | Origem cozinha | Somente lights da sala |
| Desliga todas as luzes da sala | Origem cozinha | Somente lights da sala |
| Luz | Satélite sala | Lights da sala, turn_on |
| Luz | Satélite cozinha | Lights da cozinha, turn_on |
| Luzes | Satélite sala | Lights da sala |
| Iluminação | Satélite sala | Lights da sala |
| Ventiladores | Satélite sala | Somente fan da sala |
| Luz | Sem origem confiável, com/sem default | Pergunta cômodo; zero serviços |
| Luz | Satélite sem área | Pergunta cômodo; zero serviços |
| Liga as luzes | Satélite cozinha | Lights da cozinha |
| Desliga as luzes | Satélite cozinha | Lights da cozinha |
| Liga as luzes do quarto | Satélite sala | Somente quarto |
| Liga a sala | Entidade excluída | Excluída não recebe serviço |
| Liga todas as luzes da sala | Entidade excluída | Excluída não recebe serviço |
| Liga a sala | Fan sem turn_on | Fan omitido; lights acionadas |
| Liga a sala | Mais de 32 alvos | target_limit; zero serviços |
| Liga a sala | Área inexistente | Zero serviços |
| Liga a sala | Áreas homônimas | ambiguous_area; zero serviços |
| Liga a sala | Permissão revogada durante inferência | Bloqueio antes do primeiro serviço |
| Liga a sala | Membro do catálogo acrescentado | Plano invalidado antes do primeiro serviço |
| Luz | Satélites sala/cozinha | Cada origem seleciona somente sua área |

Cobertura adicional: lâmpadas, fan singular, origem de dispositivo, satélite
desabilitado, default com mesma área mas procedência alterada, serviços ausentes,
estado unavailable, grupos de exclusão, critical e bulk_eligible, bulk_domains,
usuários diferentes, repetição, colisões scene/script, formas educadas,
infinitivos, seis domínios, categorias sensíveis, andares, comandos compostos,
contradição, plano forjado sem escopo, categoria/área forjada e conjunto truncado.
Os testes existentes continuam cobrindo alterações de configuração e revogação
de identidade/exposição/permissões entre chamadas.

O preflight valida o plano inteiro antes do primeiro efeito. Revogação ou falha
após um serviço já confirmado interrompe o restante e retorna partial_failure
explicitamente. HA não oferece transação ou rollback de dispositivos físicos;
não há promessa de atomicidade depois do primeiro serviço.

## Diagnósticos e arquivos

`last_outcome` conserva code e reason e acrescenta stage: normalization,
intent_recognition, area_resolution, entity_resolution, authorization, planning
ou ha_execution. Timings Rust/Python conservam fases de normalização,
intenção/slots, resolução, planejamento, validação e execução. DEBUG registra
somente rota, etapa, código e motivo; não imprime fala, nomes, usuários,
áreas privadas, tokens ou catálogo. DEBUG é controlado pelo logger HA.

Arquivos de execução: contextual/{contract,grammar,mod,resolver}.rs;
contextual_catalog.py, contextual_protocol.py, contextual_runtime.py,
contextual_errors.py, conversation.py e voice_input.py. Configuração/copy: config_flow.py,
strings.json e translations/{en,pt-BR}.json. Testes: contextual.rs,
test_contextual_spatial.py e ajustes de expectativas de escopo/diagnóstico nos
testes existentes. Distribuição: listas fechadas check-mlp-package.py/hacs.py,
versões sincronizadas, locks e release.json. README/INSTALL apontam este relatório.
Nenhuma dependência adicional, LLM, credencial no Rust ou automatização HA.

## Validação desta árvore

Gate oficial executado em Linux por `./tools/mlp-dev.ps1 -Task check`, que
estagia o checkout Windows e chama exatamente `sh ./tools/mlp-check`.
Resultado final: **MLP CHECK PASS**, exit 0. Rust 1.98.0; Python 3.12.15.

| Verificação | Resultado |
|---|---|
| Corpus determinístico e integridade do vendor | PASS |
| Estrutura, versões, JSON/YAML e distribuição HACS/Store | PASS |
| compileall e Python sem binário | 206 testes, 65 skips condicionais ao binário, zero falhas |
| cargo fmt, clippy com warnings negados | PASS |
| cargo test --workspace --locked --offline | 94 testes aprovados, zero falhas |
| cargo build --workspace --release --locked --offline | PASS |
| Python contextual com Rust release real via HTTP | 118 testes aprovados, zero skips/falhas |
| Smoke do serviço local | PASS |
| Build scratch add-on linux/amd64 0.4.4 | PASS |
| Smoke da imagem real com executor Python simulado | Smoke existente e seis casos espaciais aprovados |
| ZIPs e extração/hash/posição de instalação | Add-on 612 arquivos; integração HACS 25 arquivos; PASS |

Os 65 skips da primeira passagem são condicionais: os testes contextuais rodam
novamente com `ARANDU_NLU_BINARY` e nenhum é omitido na segunda passagem.
Não se somam as passagens como se fossem casos independentes. A tentativa inicial
no Python 3.10 nativo não foi aceita como validação; esse runtime não oferece
asyncio.timeout. A aprovação acima pertence ao ambiente Linux Python 3.12.
Não há falha remanescente no gate final.

Fingerprint normalizado do código/testes efetivamente validados:
`9036acda7bcf73fe708bd4c550b415b20b0aa37e08b507073a40312d860dbb0c`.
Foi conferido contra o checkout final após preservar terminações de linha.
Digest de distribuição em release.json:
`3fc6f839a8f555a35ebcb583f8dba7ee3182821d191656ab78725f31f34b9243`.
As definições de digest são distintas: validação inclui testes; distribuição
inclui os componentes e ferramentas de entrega.

Evidências locais: `target/spatial-mlp-check.log`, `target/spatial-image-build.log`,
`target/spatial-image-smoke.log`, `target/spatial-benchmark.json` e
`target/spatial-packages-final/packages.json`.

`tools/spatial-benchmark.py` mede o binário release pelo HTTP e o executor real,
com HA instantâneo simulado: 64, 512 e 4.096 entidades; cômodo com exatamente
32 alvos e comando implícito com 31 lights. Duas iterações de aquecimento e oito
amostras por comando/tamanho. p95 é o máximo das oito amostras.

| Catálogo | Rust, p50 “liga a sala” | Fluxo completo p50 / p95 “liga a sala” |
|---|---|---|
| 64 entidades | 0,138 ms | 104,5 / 143,5 ms |
| 512 entidades | 0,421 ms | 581,7 / 919,9 ms |
| 4.096 entidades | 2,621 ms | 4.314,5 / 5.823,2 ms |

Limitação medida: o custo dominante é reconstruir/revalidar o catálogo Python
antes de cada serviço, política herdada do bulk anterior e agora compartilhada
pelos escopos equivalentes. Não foi removida essa proteção para melhorar números.
As medições ocorreram em Docker local durante builds; não representam latência
residencial nem comparação controlada com a versão anterior. Estado/capacidade,
permissões e alterações de configuração permanecem revalidados a cada fronteira.
Otimização desse custo permanece fora desta correção semântica.

Os runtimes completos HA 2025.3/2026.9/2026.10 não foram instalados nem executados.
A auditoria da API usa as fontes oficiais e testes de construtores derivados
delas; efeitos HA e áudio real continuam limitados pelo ambiente simulado.
Build verificado somente em amd64; outras arquiteturas não foram declaradas
validadas. Nenhum resultado histórico em data/contextual foi reclassificado
como evidência desta árvore.

Artefatos locais, sem publicação:

| Arquivo | SHA-256 |
|---|---|
| arandu-nlu-addon-0.4.4.zip | b350b13f7f93345c26fb16b93dc5fd1752a0c8580d18493a51e6cb1996c23bea |
| arandu-nlu-integration-0.4.4.zip | 4bb90fb707c3e7683ed1e17c454e69f6fb79b645a0e4723d69e72aef48c70755 |
| arandu-nlu-integration.zip (HACS, layout plano) | aeece61353f7bcdf53d2f9d6907706bfb931750d4b60475e6886b3c25e330c77 |

## Atualizar pelo HACS e Add-on Store sem perder configuração

0.4.4 está preparado localmente; ainda não existe nova release publicada por
este trabalho. A publicação não foi autorizada. Os passos abaixo se aplicam
quando o par testado for disponibilizado nos canais oficiais.

1. Faça backup do HA. Registre endpoint, identidade por dispositivo/satélite,
   default_area, exclusões e entity_preferences. Não remova a integração,
   não apague `.storage` e não reinstale o add-on do zero.
2. Atualize o add-on existente na Store para a versão correspondente e
   reinicie-o. Preserve slug `ptbr_nlu` e suas opções. Atualize a integração
   existente no HACS; preserve domínio `local_nlu` e a config entry.
3. Reinicie o Home Assistant. Confira diagnósticos: service_version e
   integration_version iguais a 0.4.4, protocol=4, contextual_enabled=true,
   route=/v4/interpret e compatible=true. Não opere com apenas um lado atualizado.
4. Confira área do satélite no registro de entidades/dispositivos, exposição
   Assist e usuário autorizado. Configure wake_words somente se a transcrição
   realmente incluir o prefixo. default_area não substitui satélite para “luz”.
5. Execute o checklist abaixo. Para rollback, restaure o par 0.4.3 pelo backup
   ou versões anteriores de ambos os canais, conservando a configuração.

Pacotes locais produzidos pelos tools/release-package.py são artefatos de revisão,
não uploads nem releases. HACS não recebe automaticamente um patch não publicado.

## Checklist no satélite real — execução reservada ao usuário

- [ ] Confira usuário associado, área do satélite e entidades expostas ao Assist.
- [ ] Na sala, diga “luz”: só lights elegíveis da sala devem ligar. Repita com
      lights já ligadas: não devem alternar. Faça o mesmo no satélite da cozinha.
- [ ] Compare “liga a sala” / “desliga a sala”, dispositivos e categorias plurais;
      observe exclusões e dispositivo crítico. “liga as luzes do quarto” deve
      prevalecer sobre o satélite da sala. Verifique fan singular/plural.
- [ ] Com área da origem removida, “luz” deve perguntar cômodo sem efeitos,
      mesmo com default_area. Com entidade indisponível, não deve executar parte
      do conjunto. Palavras de fechadura, portão e alarme não devem acionar serviços.
- [ ] Confira last_outcome e versões nos diagnósticos. Para verificar wake word,
      observe a transcrição somente na interface local do pipeline; não compartilhe
      transcrições ou IDs privados em logs/relatórios. Não habilite DEBUG persistente.

Nenhum item residencial foi marcado como aprovado neste trabalho.
