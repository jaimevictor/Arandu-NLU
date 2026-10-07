# Implantação 0.4.1 — motor contextual 2.0

## Instalação pelo HACS

Motor Rust: **Home Assistant Add-on Store**. Integração Python: **HACS**.
Adicione https://github.com/jaimevictor/Arandu-NLU aos repositórios personalizados
HACS, categoria Integration; baixe ARANDU NLU e reinicie o HA. Depois configure
a integração em Dispositivos e serviços e selecione o agente no Assist.
Para instalação manual existente, baixe no mesmo domínio `local_nlu` e reinicie;
preserve config entry/options/.storage, sem excluir/recriar a entrada.
[Instalação nova, migração, atualização e checklist residencial](../../INSTALL.md#instalação-pelo-hacs).

HA mínimo declarado 2025.3.0; HACS 2.0.5. Até a primeira release, instale
`master`; releases posteriores podem ser escolhidas pelo HACS. O método atual
baixa apenas o componente Python da fonte; o ZIP plano fixo também é gerado,
mas não consumido automaticamente pelo HACS. [Motivo e releases](RELEASES.md).

## Capacidades contextuais 0.4.0

Atualize o add-on pela Store e a integração Python pelo HACS conforme INSTALL.md.
Faça backup do componente e das opções; para rollback, restaure ambos os
componentes da mesma versão e reinicie o HA. Nenhum deploy residencial faz
parte da validação desta entrega.

Os diagnósticos baixáveis do HA informam as versões reais, protocolos,
contextual_enabled, rota e último code/reason, sem catálogo ou transcrições.
`GET /diagnostics` no endpoint privado identifica o Rust; `/health` mantém
seu JSON v1. Build ID ausente é explicitamente `unknown`.

Opções declarativas (IDs abaixo são exemplos técnicos, substitua pelos reais):

```yaml
excluded_from_bulk_actions:
  - switch.infraestrutura
bulk_domains: [light, switch, fan, climate, media_player, humidifier]
low_battery_threshold: 20
person_device_bindings:
  telefone de Pessoa A: [device_id_real]
  meu celular: [device_id_real]
device_sensor_bindings:
  device_id_real:
    battery: sensor.carga_do_aparelho
    location: sensor.area_dinamica
    observed_at_entity: sensor.ultima_observacao
    area_attribute: area_id
    max_age_seconds: 300
entity_preferences:
  sensor.temperatura_ambiente:
    preferred: true
  switch.outro_equipamento:
    excluded_from_bulk_actions: true
```

`person_device_bindings` associa aliases a IDs de dispositivos; não atribui
permissão nem afirma propriedade. `meu celular` só funciona com alias explícito,
e respeita a exposição/permissão do usuário. A bateria normalmente é descoberta
pelo device_id e device_class=battery; o binding serve para sensores externos ou
metadados incompletos. Unidade percentual e faixa 0–100 são obrigatórias.

Localização usa exclusivamente fonte dinâmica. O sensor de timestamp deve ter
device_class=timestamp, estar exposto e ter permissão de leitura. Como alternativa,
use `observed_at_attribute: last_seen` para um timestamp ISO com timezone ou epoch
publicado pela própria fonte. Nunca configure last_changed/last_updated como
frescor. Bermuda Area é descoberto por metadados; o contrato consultado publica
area_id, mas não garante last_seen. O sensor Area Last Seen representa um cômodo,
não um timestamp; vincule uma observação temporal confiável se necessária.
[Contrato primário Bermuda](https://github.com/agittins/bermuda/blob/main/custom_components/bermuda/sensor.py).

Sem provider, timestamp recente ou área inequívoca, o Arandu informa a ausência.
Não usa RSSI, MAC ou área estática para estimar posição. Os testes usam fixtures;
localização física depende de provider/hardware configurado na residência.

Desligamento coletivo limita-se aos domínios da whitelist acima e a serviços
turn_off disponíveis. Fechaduras, alarmes, sensores e controles de acesso ficam
fora. Mais de 32 alvos gera recusa explícita sem efeito, não truncamento.
Mudança de inventário/permissão/exposição/opções invalida o plano. Falha após
efeito parcial interrompe o restante; timeout de efeito não é repetido.

Quando nome e cômodo identificam conjuntos diferentes, a pergunta explicita
sim=todos do cômodo e não=somente os correspondentes por nome. Também aceita
quantidade ou escopo válidos. Pendência dura até 30 segundos (limitada pelo
session_ttl), depende de conversation_id/usuário/origem e desaparece após
reinício do HA/integração. Novo comando substitui a pergunta anterior.

O guia atual de distribuição é [INSTALL.md](../../INSTALL.md): uma única
fonte `addon/`, slug `ptbr_nlu` preservado, atualização do catálogo e build
pelo Supervisor, integração atualizada pelo HACS e pacotes separados.
O pacote combinado antigo citado em evidências não substitui esses ZIPs.

1. Faça backup da integração atual e da configuração do Assist. Instale/atualize ARANDU NLU pelo HACS; reinicie o HA.
2. Instale o add-on deste repositório, versão 0.4.1, e inicie-o. O Rust é estático, sem root, sem credenciais e sem acesso de saída necessário. Configure a integração com o endpoint privado do add-on (o slug continua `ptbr_nlu`).
3. Selecione ARANDU NLU como agente de conversa no pipeline Assist. Exponha as entidades desejadas em Assist, atribua áreas aos dispositivos/satélites e confira aliases e nomes reais.
4. Em opções, mantenha `contextual_enabled=true`. Configure área padrão somente se quiser usá-la quando não existe origem identificável. Ajuste preferências, incrementos e políticas abaixo.
5. Teste primeiro uma consulta, depois uma ação simples e um esclarecimento: “Qual a temperatura aqui?”, “Liga o ar”, “Coloca o ventilador em 50 por cento”. Confira o histórico HA antes de habilitar ações sensíveis.

Não há requisito de modificar STT. O áudio continua no pipeline existente; o NLU recebe o texto final. Não há necessidade de editar o STT, substituir Wyoming ou enviar credenciais ao Rust.

## Instalar o pacote local — avançado/desenvolvimento

Extraia `arandu-nlu-addon-0.4.1.zip` e confira seu SHA-256 com o `.zip.sha256`. Para uma nova instalação local com Supervisor, copie a pasta `addon` inteira para `/addons/arandu_nlu`, preservando seus arquivos internos; recarregue a loja e instale a entrada local Arandu NLU. Para atualizar uma instalação existente de loja, mantenha o mesmo repositório e siga INSTALL.md, preservando a identidade. Esse é o [fluxo oficial de apps locais do Home Assistant](https://developers.home-assistant.io/docs/apps/tutorial/). O pacote é código-fonte e o Supervisor compila a imagem.

A validação da versão 0.4.0, incluindo builds amd64/aarch64 e pacotes independentes, consta em [CONTEXTUAL_IMPLEMENTATION_REPORT.md](CONTEXTUAL_IMPLEMENTATION_REPORT.md). Evidências de versões anteriores permanecem históricas.

Em desenvolvimento offline, extraia `arandu-nlu-integration-0.4.1.zip` no diretório de configuração HA para obter `/config/custom_components/local_nlu`, reinicie o HA e adicione a integração em Dispositivos e serviços. Se ela já existe, preserve sua entrada e opções. Para usuários normais, use HACS. Use o hostname privado exibido pelo Supervisor para esse app e a porta interna 11555. O add-on não publica uma porta no host. Em HA Container, compile a imagem e conecte-a à mesma rede privada do HA, com o endpoint configurado para o nome desse container; use a integração da mesma forma.

O pipeline precisa fornecer `context.user_id` de um usuário ativo. Se a instalação/satélite não o fornecer, a integração nega a solicitação: valide isso com uma consulta antes de habilitar o agente no pipeline principal. O motor não presume autorização administrativa de um satélite.

## Opções

As áreas e entidades são selecionadas pela UI. Objetos avançados usam o seletor de objeto nativo. Use IDs reais da sua instalação nos exemplos abaixo; os IDs são configuração do usuário, nunca IDs embutidos no motor.

```yaml
increments:
  temperature: 1
  percentage: 10
  brightness: 10
  volume: 5
entity_preferences:
  climate.seu_ar:
    preferred: true
  sensor.seu_nivel:
    semantic_category: tank_level
  person.sua_pessoa:
    indoor_tracker: sensor.seu_tracker_de_comodo
sensitive_entities:
  - lock.sua_porta
energy_sources:
  - sensor.circuito_a
  - sensor.circuito_b
```

Soma só é permitida para fontes disjuntas com unidades iguais e dispositivos distintos. Não combine medidor total com submedidores. `semantic_category` admite necessidades cuja semântica não vem da classe HA, como `tank_level`, `people_count` e `remaining_time`.

`indoor_tracker` deve apontar para sensor/device_tracker real que informe nome ou ID de área registrada, com leitura permitida e exposição ao Assist. A área cadastral da entidade person não é sua posição atual. Sem tracker interno explícito, localização usa a zona nativa da pessoa; perguntas sobre cômodo abstêm. Valor desconhecido, cômodo ambíguo ou tracker oculto nunca viram localização inventada.

`sensitive_entities` apenas autoriza solicitar confirmação. Não elimina código/PIN exigido pela entidade. Destrancar, desarmar e abrir acesso físico continuam sujeitos à confirmação vinculada ao mesmo usuário/origem/conversa.

## Adaptadores explícitos

Serviços de canais, contatos, anúncios, alarmes de relógio e impressão 3D não são universais no HA. Configure um script/botão exposto e autorizado por intenção. Parâmetros nunca são descartados silenciosamente: configure o mapa `variables` para scripts que precisam deles. O script recebe valores semânticos e deve resolver suas próprias referências reais e limites.

```yaml
intent_bindings:
  alarm.set:
    entity_id: script.seu_alarme
    sensitive: false
    variables:
      time: horario
  call.contact:
    entity_id: script.sua_chamada
    sensitive: true
    variables:
      contact: contato
```

Chamadas, anúncios e remoção de evento devem usar scripts com autorização e resolução inequívoca de contato/destino/UID. Sem adaptador ou variável mapeada, o executor abstém. Os bindings não fazem esses serviços existirem.

```yaml
device_mappings:
  media_player.sua_tv:
    remote_key:
      back:
        entity_id: remote.seu_controle
        command: KEY_BACK
      channel_up:
        entity_id: remote.seu_controle
        command: KEY_CHANNELUP
    channel:
      entity_id: remote.seu_controle
      digits:
        "0": KEY_0
        "1": KEY_1
        "2": KEY_2
      enter: KEY_ENTER
```

Mapeie todos os dígitos necessários. A TV e o backend precisam estar expostos/autorizados. Não se assume que volume ou next_track troquem canais. Os comandos do controle são valores fixos da configuração.

Music Assistant precisa estar instalado e configurado, com players reais expostos. “Abre o Spotify” pergunta o que ouvir. Busca retorna URI real e único; resultado ambíguo ou provider ausente abstém. Transferência exige player de origem recente na mesma sessão.

Calendário precisa suportar create_event para criação. O diálogo coleta título/dia/horário/duração, constrói início e fim no timezone do HA e valida o serviço antes de executar. Ausência de dados nunca usa uma duração inventada.

## Build, verificações e rollback

Pré-requisitos: HA com Conversation/Assist e um usuário ativo identificado no contexto; Supervisor para o app local ou Docker em rede privada para HA Container. Build requer o builder Rust pinado; o gate usa Python 3.11+ (tomllib), Ruby e Rust 1.98.0. Em Windows, Docker Linux e `tools/mlp-dev.ps1` fornecem as versões registradas em tools/dev/DEPENDENCIES.md. Somente serviços/integradores realmente instalados ficam disponíveis.

Windows: `./tools/mlp-dev.ps1 -Task check`. Linux com Rust 1.98.0: `./tools/mlp-check` (fontes vendorizadas, build offline). Imagem: `docker build --build-arg BUILD_ARCH=amd64 --build-arg BUILD_VERSION=0.4.1 -t arandu-nlu:0.4.1 addon`.

Para reproduzir cobertura: importe/valide o corpus com `tools/import-stt-corpus.py --stt-root <repo-stt> --check`; use `ARANDU_NLU_BINARY=<binário-release> python3 tools/contextual-evaluate.py --stt-root <repo-stt> --output <resultado.json>`. O teste usa executor real com HA simulado. Benchmark puro: `cargo run --release --locked --offline -p local-nlu --example contextual_bench`.

Rollback reversível: desative contextual_enabled; v1/v2/v3 permanecem. Para rollback completo, restaure o backup da integração e a imagem anterior. Não há migração de banco ou histórico persistente a desfazer. Consulte REPORT.md e os resultados JSON antes de tratar qualquer intenção como validada operacionalmente.

Logs: consulte a página do app no Supervisor para falhas de inicialização e Configurações → Sistema → Logs para erros da integração. Em Docker, use `docker logs <container-nlu>`. O runtime não persiste transcrições nem inclui credenciais em erros por padrão; não habilite dumps de requests para diagnosticar uma residência. Resultados `stale`/`denied`/`unavailable` são abstenções, não confirmações de sucesso.
