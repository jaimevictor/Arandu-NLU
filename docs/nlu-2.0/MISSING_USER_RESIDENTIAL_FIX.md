# Correção de missing_user no Assist — implementação 0.4.3

## Resultado e checkpoint

Correção implementada e validada em **0.4.3**, integração Python e add-on Rust.
Baseline auditado: master **260115282fee7df2cfd265018801f7729e526ab6**, versão **0.4.2**.
**previous_identity_fix_present=false**.

Gate completo, artefatos extraídos e duas revisões independentes PASS.
Release estável [v0.4.3](https://github.com/jaimevictor/Arandu-NLU/releases/tag/v0.4.3)
publicada no commit testado **369d2a4b0aef8dead765b7746e04202d418c0a44**,
enviado diretamente para master, sem force push. Todos os assets remotos
baixados/conferidos; hashes iguais aos artefatos testados. Próxima ação residencial abaixo.
Nenhum deploy ou teste residencial foi realizado. Arandu STT não foi acessado ou alterado.
Os arquivos locais anteriores não relacionados à missão foram preservados.

## Causa raiz e auditoria F0

ContextualRuntime.user(context) exigia context.user_id string e usuário ativo.
Context(user_id=None) produzia denied/missing_user antes do catálogo e do Rust.
A versão 0.4.2 auditada não continha fallback, binding funcional, seletor de
identidade ou diagnóstico de origem. Assim, nenhuma correção anterior presente
nesse commit podia resolver o caso. Não se atribui o resultado a uma mudança
de código que não existia. Incompatibilidade entre versões é outro problema:
0.4.3 deve ser instalada nos dois componentes, com compatible=true.

Sete chamadas de self.user no contextual_runtime.py original:

| Local original | Responsabilidade | Implementação final |
| --- | --- | --- |
| linha 130 | entrada | resolve_request_identity recebe ConversationInput inteiro |
| linha 211 | clarificação/seleção | revalida identidade efetiva |
| linha 508 | preflight | revalida mesmo ID e opções |
| linha 532 | operação | revalida mesmo ID e permissões atuais |
| linha 550 | serviço individual | revalida antes do efeito |
| linha 676 | consulta por serviço | revalida após await |
| linha 742 | Music Assistant | revalida após busca e antes da reprodução |

Não restam chamadas self.user(user_input.context) no runtime contextual.
ConversationEntity e LocalNluRuntime encaminham device_id e satellite_id.
origin_area usa os registros HA desses identificadores. O catálogo é por usuário;
sessões são por (effective_user_id, origem, conversation_id), com os limites/TTL existentes.

## Pesquisa oficial HA 2026.9.4 — F1

[ConversationInput](https://github.com/home-assistant/core/blob/2026.9.4/homeassistant/components/conversation/models.py)
possui context, device_id e satellite_id. device_id é ID do device registry;
satellite_id é entity_id assist_satellite.*, não ID do entity registry.

[WebSocket autenticado](https://github.com/home-assistant/core/blob/2026.9.4/homeassistant/components/websocket_api/connection.py)
cria Context(user_id=self.user.id).
[Assist WebSocket](https://github.com/home-assistant/core/blob/2026.9.4/homeassistant/components/assist_pipeline/websocket_api.py)
usa connection.context(msg).
[PipelineRun/PipelineInput](https://github.com/home-assistant/core/blob/2026.9.4/homeassistant/components/assist_pipeline/pipeline.py)
propagam contexto e IDs recebidos.

[Satélites](https://github.com/home-assistant/core/blob/2026.9.4/homeassistant/components/assist_satellite/entity.py)
podem criar Context() quando o chamador não passa contexto.
[Automações](https://github.com/home-assistant/core/blob/2026.9.4/homeassistant/components/automation/__init__.py)
contêm caminhos que criam Context(parent_id=...) sem user_id.
[Conversation service](https://github.com/home-assistant/core/blob/2026.9.4/homeassistant/components/conversation/__init__.py)
encaminha service.context; chamadas internas, testes ou integrações podem fornecê-lo
sem usuário. REST autenticado normalmente usa o usuário da requisição via
[HomeAssistantView.context](https://github.com/home-assistant/core/blob/2026.9.4/homeassistant/helpers/http.py).
Isso não significa que toda API ou toda automação opere sem identidade.

Não há UserSelector no [selector oficial](https://github.com/home-assistant/core/blob/2026.9.4/homeassistant/helpers/selector.py).
A UI usa SelectSelector com usuários ativos de
[hass.auth.async_get_users()](https://github.com/home-assistant/core/blob/2026.9.4/homeassistant/auth/__init__.py).
O ID estável é salvo; nomes aparecem apenas na UI autenticada.
Não são serializados objetos User ou tokens. Nenhuma alteração no HA Core.

## Arquitetura e configuração — F3–F10

identity.py fornece ResolvedIdentity imutável (user_id, user, source).
Precedência obrigatória:

1. context.user_id presente;
2. voice_identity_bindings[satellite_id];
3. device_identity_bindings[device_id];
4. fallback_user_id explícito;
5. denied/missing_user.

Usuário selecionado inválido, ausente ou inativo recusa; nunca desce para uma
identidade com privilégios maiores. Não há inferência por fala, pessoa, área,
admin ou owner. Bindings exigem origem real registrada e habilitada no HA.
Os mapas são limitados e tipos/identificadores validados.

A resolução ocorre uma vez por requisição. Depois, consulta-se novamente o
**mesmo ID** para validar atividade e permissões. Mudança do Context autenticado,
opções, binding ou revisão salva invalida o turno; não seleciona outro usuário.
O contexto de serviço configurado é Context(user_id=effective_user_id,
parent_id=original.id), preservando o contexto recebido.

Continuam obrigatórios read/control, exposição ao Assist, entity_permission,
bulk_policy, sensitive_policy e authentication_required/PIN. Preflight integral
e revalidação por chamada permanecem ativos. Revogação após um efeito interrompe
os restantes e informa falha parcial; não promete rollback de serviço já executado.

A UI em **Configurações → Dispositivos e serviços → ARANDU NLU → Configurar**
oferece **Usuário para pipelines sem identidade**, com descrição:
“Usuário cujas permissões serão utilizadas quando o Home Assistant não informar
a identidade da pipeline de voz.” A opção vazia desativa o fallback.
Também permite adicionar, substituir e remover bindings usando EntitySelector
de satélite ou DeviceSelector e dropdown de usuário ativo. É possível cadastrar
vários bindings, inclusive remover um cuja origem deixou de existir.
Não exige JSON, YAML ou edição de .storage.

Salvar opções invalida imediatamente catálogo, sessões e diálogos antigos,
incluindo mudança seguida de restauração durante I/O. Fontes diferentes com
mesmo ID não reaproveitam confirmação pendente.
Fallback/bindings atendem o caminho **contextual v4**.
Rollback com contextual_enabled=false preserva o comportamento legado de
exigir contexto autenticado; os protocolos antigos não foram redesenhados.

## Cobertura das fases

| Fase | Implementação/evidência | Resultado |
| --- | --- | --- |
| F0 | baseline real, sete chamadas, IDs/sessões e ausência de correção | concluída |
| F1 | fontes oficiais HA 2026.9.4 e probe de classes reais | PASS |
| F2 | reprodução antes da correção, zero Rust/HA sem identidade | red comprovado |
| F3 | identidade imutável recebendo entrada completa | PASS |
| F4 | quatro fontes e precedência sem fallback em erro | PASS |
| F5 | fallback e bindings pela UI oficial | PASS |
| F6 | sete chamadas substituídas; consulta, execução, música e diálogos | PASS |
| F7 | ID fixo/revalidação e rejeição de mutações durante await | PASS |
| F8 | autorização atual, exposição, bulk, sensível/PIN | PASS |
| F9 | isolamento efetivo por usuário/origem/conversa e invalidação | PASS |
| F10 | diálogo de conjuntos com sim/não sob fallback | PASS |
| F11 | ConversationEntity → LocalNluRuntime → v4 real → executor simulado | PASS |
| F12 | conjuntos nominais/área iguais executam; diferentes clarificam | PASS |
| F13 | controle nominal, área inteira, métrica e consulta global | PASS |
| F14 | inexistência, inatividade, revogação, remoção de origem | PASS |
| F15 | origem e booleanos sem IDs privados; motivo preservado | PASS |
| F16 | mensagem específica para missing_user | PASS |
| F17 | debug apenas fonte/authenticated/rota | PASS |
| F18 | versões/locks/release.json sincronizados em 0.4.3 | PASS |
| F19 | release/tag no commit testado, assets remotos idênticos; HACS oficial detecta upgrade em fixture | PASS |
| F20 | Store anuncia 0.4.3, pacote compilável e instruções abaixo | PASS local |
| F21 | runtime de ambos ZIPs, Rust compilado do ZIP add-on | PASS |
| F22 | relatório/checkpoint, hashes e retomada | atualizado |
| F23 | procedimento exato de atualização residencial abaixo | entregue |
| F24 | comandos e observações de smoke abaixo | entregue; execução pelo proprietário pendente |

## Testes e resultados reais

F2 antes do fix: dois testes, sem configuração PASS com denied/missing_user e
**zero catálogo, zero Rust e zero HA**; fallback configurado FAIL, observado
denied/missing_user em vez de success. A falha estabeleceu a regressão real.

test_contextual_identity.py: **23 testes únicos PASS**, cinco com transporte HTTP
ao Rust real. Entradas de fallback usam explicitamente Context(user_id=None).
Comprova chamada /v4/interpret, alvo correto, resposta falada e serviço HA com
contexto do usuário autorizado. Queries leem estado atual sem inventar efeitos.
Fixture nominal usa área Estúdio de Ana e ventiladores genéricos: sim/não
executam conjuntos diferentes corretos; conjuntos iguais executam diretamente.
Também cobre slots, confirmação/PIN, satélites isolados, falta de permissão
de fan, exposição, política coletiva, usuário inativo/ausente, mudança de opções
e revogação entre serviços.

Primeiro gate falhou apenas na antiga contagem HACS de 23 arquivos.
identity.py é o 24º: expectativa ajustada para 24 **e presença explícita do módulo**,
mantendo allowlist estrita. Não houve alteração de teste para aceitar falha funcional.

Gate final completo **PASS**: 181 testes Python, 93 Rust, 93 contextual/HTTP após build.
Os 47 skips HTTP pré-build foram executados no passe pós-build.
Formatting, clippy, corpus, vendor, estrutura/versões, build release e smoke PASS.
Log: target/missing-user-0.4.3-final-gate.log.
Fingerprint do código/testes/ferramentas conferido igual ao gate:
eecb7d202f2e5e8d9f913335b3f98be808ed031f6cfd37767b3a4691a48b778e.

Artefatos extraídos: **23 testes PASS para cada ZIP Python**, sem skips,
usando binário Rust compilado offline exclusivamente do ZIP add-on/vendor/lock.
Assert das origens dos módulos comprova uso dos arquivos instaláveis.
Log: target/missing-user-0.4.3-artifacts.log.
Staging: target/identity-0.4.3-staging.

Probe oficial HA **2026.9.4 PASS** com classes reais Context/ConversationInput/
ConversationEntity/OptionsFlow/SelectSelector/DeviceSelector/EntitySelector,
integração extraída do ZIP plano e Rust construído do ZIP add-on.
Usuários, registros, permissões e serviços HA são simulados.
Imagem: ghcr.io/home-assistant/home-assistant@sha256:3e6710a7ab2a61311d9d899b719f6c3657791c63e8f4942cec4ebc42401d6b76.

Probe HACS oficial PASS: schemas, validators, registration, instalação fonte,
reinstalação, pending_update 0.4.2→0.4.3, instalação por tag e extração ZIP,
com polling/download GitHub em fixture. Config entry/options preservados.
Imagem: ghcr.io/hacs/action@sha256:dc92fdad2f6ffbe74bffb7269d781ea8e064f52d9bb486cdf3925d74e7ab6ebf.
Essa imagem congelada contém HA 2026.7.4; não foi apresentada como HA 2026.9.4.

Duas revisões independentes read-only: **produto PASS**, **segurança PASS**,
sem achado material. Cada uma rodou os 23 testes; contraprovas adicionais
recusaram binding inativo com fallback admin, mudança de fonte na confirmação,
revogação de read, usuário retornado com outro ID, satélite desabilitado durante
inferência e desativação após primeiro serviço.
Digest distribuído revisado:
02a9f093a9f69f9aac527377fbb5981ec34183cce4e8399727337bbb8ed21855.
Nenhuma dependência obrigatória nova, nenhum LLM/cloud e nenhuma mudança no parser Rust.
Não se reivindica benchmark novo ou validação residencial.

Publicação remota em 2026-10-07: [CI HACS/distribution](https://github.com/jaimevictor/Arandu-NLU/actions/runs/37643122825)
**PASS** e [workflow da release/upload](https://github.com/jaimevictor/Arandu-NLU/actions/runs/37643354625)
**PASS**, ambos no commit 369d2a4b0aef8dead765b7746e04202d418c0a44.
A API GitHub confirmou release não draft/não prerelease e tag apontando para
esse commit. Os sete assets (três ZIPs, três hashes e packages.json) foram
baixados; SHA/CRC/contagem conferidos e idênticos aos arquivos testados.

O arquivo de fonte GitHub da tag também foi baixado. Foram lidos somente os
24 arquivos da integração e metadata ativa HACS/Store/release; bytes textuais
normalizados e binários íntegros correspondem ao produto testado. Confirmados
manifesto 0.4.3, identity.py, UI fallback, runtime sem antigas chamadas e
addon/config.yaml 0.4.3. Não foram inspecionadas implementações legadas/gitlinks.

Probes oficiais repetidos usando **a fonte baixada da tag pública** e o ZIP
baixado da release: HACS instalação/reinstalação/decisão de upgrade/extrator
**PASS**; HA 2026.9.4 com Rust real do pacote add-on e serviço simulado **PASS**.
Os clientes externos do probe HACS continuam em fixture: não se afirma que a
instância residencial do proprietário já detectou a atualização. A release e
fonte públicas necessárias para essa detecção estão presentes e verificadas.
Evidência local remota: target/remote-identity-0.4.3 e
target/verify-remote-identity.py. A primeira execução desse verificador tratou
erroneamente PNG como texto e recusou comparação do ícone; verificação corrigida
preserva bytes binários e passou. Nenhum produto/asset foi alterado por isso.

## Pacotes 0.4.3 e hashes SHA-256

Saída: target/dist/0.4.3. Segunda geração independente em
target/dist/identity-0.4.3-reproduction produziu os mesmos três hashes.

| Pacote | Arquivos | SHA-256 |
| --- | ---: | --- |
| arandu-nlu-addon-0.4.3.zip | 612 | 3d3b7889d3d0679d49eedf1062dc985a0d6a0e94ea6222127e24816c1101f958 |
| arandu-nlu-integration-0.4.3.zip | 24 | 08beee97fe20d55463f263c7b17112cf35286e600cf61cdf7a11560be94c8549 |
| arandu-nlu-integration.zip | 24 | f6418df9447c3107f8275f42d6094de96bf8228d3129284462ff20dcfb7b442b |

O pacote add-on contém fontes/build offline, não imagem já instalada.
O ZIP Python versionado tem custom_components/local_nlu; o fixo é plano.
HACS está configurado para fonte oficialmente suportada: instala apenas o
componente da tag GitHub. A release também fornece ZIP fixo verificável.
hacs.json declara mínimos HA/HACS; não possui campo de versão de produto.

## Arquivos modificados

- Identidade/runtime: novo identity.py; contextual_runtime.py, __init__.py,
  contextual_errors.py, diagnostics.py e const.py.
- UI: config_flow.py, strings.json, translations/en.json e pt-BR.json.
- Versão: manifest.json, addon/config.yaml, addon/engine/Cargo.toml,
  Cargo.lock, addon/engine/Cargo.lock e release.json.
- Pacotes: tools/hacs.py, tools/check-mlp-package.py e test_hacs.py.
- Evidência: novo test_contextual_identity.py, identity_ha_probe.py,
  tools/identity-artifact-check.py e extensão do hacs_official_probe.py.
- Guias: README.md, INSTALL.md, API-CONTRACTS.md, ARCHITECTURE.md,
  DEPLOYMENT.md, RELEASES.md, tools/dev/DEPENDENCIES.md e este relatório.

## Atualização residencial — F23

1. Faça backup HA/add-on. Em HACS → ARANDU NLU, procure atualizações e instale
   **0.4.3 / v0.4.3**. Se necessário abra o menu do repositório e use atualizar
   informações/download da versão. Não remova a entrada da integração.
2. Reinicie **Home Assistant** para carregar o Python novo.
3. Configurações → Add-ons → Loja de add-ons → menu → **Verificar atualizações**.
   Confirme o repositório https://github.com/jaimevictor/Arandu-NLU.
   Abra ARANDU NLU e atualize para **0.4.3**.
4. Reinicie o add-on. Se a loja ainda mostrar versão antiga, atualize as
   informações da loja/repositório. Se o manifesto já for 0.4.3 mas o serviço
   carregado for antigo, use **Reconstruir/Rebuild** no menu do add-on e reinicie.
   Preserve a configuração/endpoint; não abra sua porta para a internet.
5. Configurações → Dispositivos e serviços → ARANDU NLU → **Configurar**.
   Em **Usuário para pipelines sem identidade**, escolha explicitamente seu
   usuário ativo cujas permissões devem valer para a voz. Salve.
6. Mantenha **contextual_enabled=true**. Os bindings específicos por satélite/
   dispositivo são opcionais e têm precedência sobre o fallback.
   Salvar opções invalida sessões e aplica a configuração imediatamente;
   não requer nova reinicialização após essa seleção.
7. Confirme que o Assist usa **conversation.arandu_nlu**.
8. Envie um comando de teste. Só depois baixe diagnósticos da integração.
9. Verifique o objeto abaixo. Caso o Context já seja autenticado ou exista
   binding, last_source será context/satellite_binding/device_binding,
   respectivamente; isso é correto pela precedência.

~~~json
{
  "integration_version": "0.4.3",
  "service_version": "0.4.3",
  "compatible": true,
  "contextual_enabled": true,
  "protocol": 4,
  "route": "/v4/interpret",
  "identity": {
    "last_source": "fallback",
    "fallback_configured": true,
    "origin_binding_configured": false
  }
}
~~~

last_outcome.reason não deve ser missing_user com identidade configurada válida.
Erro de permissão real permanece entity_permission/not_exposed/etc.; identidade
explícita não torna toda entidade executável. Sem identidade configurada,
missing_user continua correto e a fala será:
“Este dispositivo de voz ainda não está associado a um usuário.”

## Smoke residencial solicitado — F24

Execute estes quatro comandos no Assist real:

1. “Desliga os ventiladores de Jaime”
2. “Desliga o Escritório de Jaime”
3. “qual a temperatura do Escritório de Jaime”
4. “tem alguma luz ligada”

No trace da pipeline, confirme o agente conversation.arandu_nlu, texto recebido,
resposta e continuidade da conversa. No diagnóstico/debug ARANDU confirme rota
/v4/interpret, protocol=4, versões iguais e origem efetiva; os logs de debug
mostram apenas fonte/authenticated/rota e **não** transcrição ou IDs.

No primeiro comando, conjuntos nome/área iguais devem executar os ventiladores
corretos; diferentes devem perguntar, sem efeito antes da resposta. Responda
sim/não e confirme que só o conjunto escolhido foi executado.
No segundo, confira os alvos controláveis/expostos/autorizados da área e eventos
de serviço HA. No terceiro, confira leitura real de temperatura ou pergunta/
abstenção adequada quando não há métrica única disponível. No quarto, confira
o estado real das luzes expostas/autorizadas, sem efeitos.
Não se espera status=plan como aprovação final de controle: deve haver serviço
efetivamente executado e estado atualizado, ou recusa/clarificação justificável.
Queries podem responder sem chamar serviço quando o estado HA já basta.

O trace residencial não foi coletado por esta missão. Se houver falha, reúna
diagnóstico, versão efetivamente carregada e motivo tipado; remova dados pessoais
antes de compartilhar. Não compartilhe tokens ou dumps de .storage.

## Retomada exata e pendências

Código, testes, revisões, push direto master, release/tag, CI e verificação
remota concluídos. Este registro final é um commit apenas documental posterior
ao commit da tag; não muda os ZIPs ou o digest distribuído.
Não restam requisitos implementáveis desta correção.
Próxima ação exata é do proprietário: executar atualização F23 e smoke F24
na residência e conferir diagnósticos/trace. Isso não foi substituído por simulação.

Limitações reais: fallback/bindings somente no modo contextual v4; políticas
HA podem legitimamente impedir controle; resultados dependem do catálogo,
estados e integrações locais disponíveis. Não foi realizada observação da UI
HACS/Supervisor na residência, deploy físico ou leitura de hardware Bluetooth.
As fixtures não atestam localização ou resultado de equipamentos indisponíveis.
Nenhum serviço executado é automaticamente revertido após falha parcial.

Comandos de validação, no diretório Arandu NLU:

~~~powershell
pwsh -NoProfile -File tools/mlp-dev.ps1 -Task check
docker exec -w /source -e PYTHONDONTWRITEBYTECODE=1 arandu-context-dev python3 -m unittest discover -s tests/mlp -p test_contextual_identity.py
docker exec -w /source arandu-context-dev python3 tools/hacs.py --tag v0.4.3 --zip /output/dist/0.4.3/arandu-nlu-integration.zip
docker exec -w /source arandu-context-dev python3 tools/identity-artifact-check.py --packages /output/dist/0.4.3 --staging /output/identity-0.4.3-new-staging
gh run list --repo jaimevictor/Arandu-NLU --limit 5
gh release view v0.4.3 --repo jaimevictor/Arandu-NLU
git ls-remote --heads --tags origin master v0.4.3
~~~

Não reexecute gate sem mudança executável ou falha nova. Staging deve ser novo;
a ferramenta recusa sobrescrever. Use release.json/source_digest para conferir
que uma revisão ainda corresponde ao produto. Não force push.
Não inclua docs/codex/, a especificação local não rastreada ou
tools/codex-skill-check.ps1 em commits desta missão.
