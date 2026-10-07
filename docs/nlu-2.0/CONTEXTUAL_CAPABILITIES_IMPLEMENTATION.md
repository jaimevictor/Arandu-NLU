# Arandu NLU — Especificação de implementação: resolução contextual, consultas e diálogo

> **Documento de execução, teste e retomada**  
> **Destino no repositório:** `docs/nlu-2.0/CONTEXTUAL_CAPABILITIES_IMPLEMENTATION.md`  
> **Referência de inspeção:** `jaimevictor/Arandu-NLU`, `master`, commit `a443e8f` (distribuição 0.3.2, observado em 07/10/2026).  
> **Prioridade:** implementação funcional completa, não apenas proposta ou protótipo.  
> **Âmbito:** motor Rust contextual, integração Home Assistant Python, testes, distribuição, observabilidade e documentação. **Arandu-STT não deve ser alterado.**

## 0. Mandato e definição de sucesso

Implementar **todas as capacidades descritas neste documento** de forma **genérica, orientada ao catálogo real do Home Assistant, local, determinística, segura e independente de nomes particulares**. O objetivo não é adicionar quatro exceções para frases isoladas; é corrigir as regras que fazem famílias inteiras de comandos fracassarem.

O Arandu deve compreender expressões como:

- “Qual a temperatura no escritório de Jaime?” / “Qual a temperatura do escritório de Bruna?”
- “Desliga tudo no escritório de Jaime.” / “Desliga o escritório de Jaime.”
- “Desliga todos os ventiladores de Jaime.” / “Desliga os ventiladores do escritório de Jaime.”
- “Qual a umidade do quarto?” / “Quanto está a temperatura aqui?”
- “Tem alguma luz ligada em algum cômodo?” / “Quais luzes estão acesas?”
- “Qual a bateria do telefone de Jaime?” / “Quanto de bateria está o celular de Bruna?”
- “Onde está o telefone de Jaime?” / “Em qual cômodo está o celular de Bruna?”
- “Tem algum dispositivo com a bateria acabando?”

O reconhecimento de uma intenção não é, por si só, sucesso. Uma resposta correta depende de:

1. interpretar o tipo de operação;
2. resolver a entidade, área, grupo e relações reais no catálogo HA;
3. identificar a capacidade executável ou métrica consultável;
4. decidir entre executar, perguntar ou informar indisponibilidade;
5. respeitar exposição, autenticação, permissões e estado atual;
6. produzir resposta falada específica e verdadeira;
7. preservar o contexto para eventuais turnos seguintes.

**Condições obrigatórias:** não usar serviços HA arbitrários derivados de texto; não inventar entidade, área, proprietário, medição, presença, localização nem sucesso; não introduzir LLM obrigatório, cloud, embeddings ou alterações no STT. Usar aliases, registros, relações e adaptadores locais.

## 1. Estado conhecido e limites da evidência

No commit de referência, existem `addon/engine/src/contextual/{grammar,resolver,slots,mod,contract}.rs`, `addon/engine/data/grammar.json`, `custom_components/local_nlu/{contextual_catalog,contextual_runtime,contextual_protocol,conversation,queries,capabilities}.py` e testes correspondentes. O corpus compilado possui 165 intenções, mas **o corpus é referência lexical, não uma ontologia completa nem prova de funcionamento em HA residencial**.

Lacunas observadas em revisão de código:

- `conversation.py` devolve “Não entendi esse comando.” para `no_match`, `invalid_request` e `unsupported_intent`, perdendo motivo detalhado da falha.
- `contextual_runtime.py` trata explicitamente `status == "clarification"`, mas `no_match` não possui recuperação equivalente; afirmações “sim” e “não” não resolvem, por si, todas as desambiguações de **conjuntos**.
- `grammar.json` contempla consulta de temperatura (`... da {area}`), comando global `desliga tudo` e variantes de grupos, mas não apresenta cobertura robusta das formas `... no {area}` ou `desliga {area}` como ação coletiva.
- `resolver.rs` indexa nomes completos, aliases, área e tipo sem um comparador explícito entre **conjunto por nome** e **conjunto por cômodo**, nem busca composicional por tokens que respeite categoria + modificadores pessoais.
- `queries.py` pode devolver apenas “Sim”/“Não” para `any`; consultas que pedem identificação de luzes devem devolver nomes e áreas.
- `contextual_catalog.py` possui `device_id`, área, nome, classe e capacidades, mas ainda falta uma relação geral e configurável pessoa ↔ telefone ↔ bateria ↔ localização dinâmica.
- `contextual_runtime.py` tem mecanismo de `indoor_tracker` para pessoas; ele não deve ser confundido com localização dinâmica geral de dispositivos móveis.
- A distribuição do add-on foi corrigida na 0.3.2; **a integração Python continua um componente com atualização independente**.

**Antes de modificar:** ler `AGENTS.md`; comparar o estado real da branch e as alterações locais com esta referência. Se o código já corrigiu algo, demonstrar por testes e atualizar o checkpoint; não revertê-lo. Os logs de uma instalação residencial, catálogo de entidades e dados Bluetooth não estão disponíveis aqui: a validação real nessas condições será explicitamente classificada, nunca presumida.

## 2. Semântica normativa de resolução

### 2.1 A intenção e o escopo são objetos distintos

O resultado semântico deve separar **ação**, **classe/capacidade**, **escopo espacial**, **seletor lexical**, **agregação**, **qualificadores** e **evidência**. Exemplo conceitual:

```text
“desliga os ventiladores de Jaime”
  action = turn_off
  category = fan
  lexical_qualifier = Jaime
  area_candidate = Escritório de Jaime (se existir associação inequívoca no HA)
  selection_mode = compare_name_and_area_sets

“desliga o escritório de Jaime”
  action = turn_off
  scope = area(Escritório de Jaime)
  selection_mode = all_bulk_controllable_in_area

“qual a temperatura no escritório de Jaime”
  action = query
  metric = measured_temperature
  scope = area(Escritório de Jaime)
```

O código pode usar contrato interno diferente, mas precisa preservar essa informação ao longo do pipeline. Não basta reter apenas uma string `mention` genérica quando isso torna indistinguíveis área, nome e proprietários possíveis.

### 2.2 Precedência do escopo

1. Área **explicitamente citada e resolvida** prevalece sobre cômodo de satélite e contexto anterior.
2. Referência espacial deíctica (“aqui”, “nesse cômodo”) só usa `satellite_id`/`device_id` e registros HA válidos; `default_area` é fallback configurado, jamais geolocalização presumida.
3. “Escritório de Jaime” é **nome/alias de área real**, não inferência de localização pessoal.
4. “De Jaime” isoladamente é um qualificador relacional/nominal potencial; não é autorização automática para assumir propriedade real nem transformar qualquer entidade da pessoa em alvo.
5. Alias explícito do usuário e associações configuradas são evidência mais forte que coincidências parciais.
6. Nunca tratar área estática de um telefone no registro de dispositivos como sua localização física atual.

### 2.3 Seleção composicional por nome

Permitir resolver **categoria + palavras discriminativas + aliases** sem exigir nome idêntico à transcrição. Normalizar acentos/artigos/plural com limites explícitos e preservando os nomes originais para resposta. Exemplo:

- “ventiladores de Jaime” encontra `Ventilador de Jaime` e `Ventilador da mesa de Jaime`;
- `Ventilador do teto` não passa no filtro **por nome**, embora possa passar no filtro **por área**;
- “ventiladores do escritório de Jaime” aplica categoria `fan` + área `Escritório de Jaime`, sem exigir “Jaime” no nome do ventilador;
- “ventiladores de Bruna” não deve selecionar ventiladores de Jaime nem todos os ventiladores da casa por aproximação.

Aplicar correspondência por tokens **com categoria/domínio/capacidade compatíveis**, não `substring` sem controle (por exemplo, “ar” não deve selecionar “armário”). Incluir nomes de entidade, aliases cadastrados, nome de dispositivo vinculado e eventuais relações explícitas configuradas. Normalizar plurais de forma criteriosa, evitando colisões e homônimos.

### 2.4 Comparação de conjuntos: cenário de Jaime

Considere área `Escritório de Jaime`:

- A = `fan.ventilador_jaime` — “Ventilador de Jaime”
- B = `fan.ventilador_mesa_jaime` — “Ventilador da mesa de Jaime”
- C = `fan.ventilador_teto` — “Ventilador do teto”

Pedido: **“Desliga os ventiladores de Jaime.”**

- `S_nome = {A, B}` (classe `fan`, nomes/aliases qualificados por Jaime)
- `S_area = {A, B, C}` (classe `fan`, área `Escritório de Jaime`, se essa correspondência de área estiver fundamentada)
- Como os conjuntos diferem e ambas as leituras são plausíveis, **não executar ainda**. Perguntar: “Quer desligar apenas os dois ventiladores de Jaime ou todos os três ventiladores do escritório de Jaime?”
- O usuário responde “todos do escritório”, “os três”, “só os dois” ou “sim” **depois de pergunta binária inequivocamente formulada**; executar somente a alternativa escolhida.

Se C não existir e `S_nome == S_area == {A, B}`, executar os dois automaticamente, sem pergunta.

Se o usuário disser **“Desliga os ventiladores do escritório de Jaime”**, a referência à área é explícita e prevalece: executar `{A, B, C}`, sem essa comparação ambígua.

Se houver entidades qualificadas por Jaime em outros cômodos, ou várias áreas com aliases conflitantes, o resolvedor precisa avaliar a evidência real e esclarecer quando necessário. **Não criar associações residenciais baseadas em nomes específicos de teste.** Se só houver correspondência de área segura, é permitido agir sobre a área; se só houver correspondência nominal segura, é permitido agir sobre nomes. Não inventar uma relação fraca para evitar uma pergunta.

### 2.5 Ação coletiva implícita sobre áreas

As frases abaixo devem convergir à **mesma intenção coletiva** com área explícita:

- “Desliga o escritório de Jaime.”
- “Desliga tudo no escritório de Jaime.”
- “Desliga todos os aparelhos do escritório de Jaime.”
- “Desliga a sala.”
- “Apaga o quarto.” (quando a linguagem indicar claramente desligamento coletivo; não trocar por apenas luzes sem evidência)

Implementar conceito funcional `area.turn_off` (nome interno livre) e selecionar **todos os dispositivos elegíveis com capacidade real de desligamento** da área, para os domínios configurados como participantes. Não tratar área como entidade física nem escolher um único aparelho como substituto.

Por padrão, distinguir operações coletivas gerais de comandos específicos a iluminação (“apaga todas as luzes da sala”), que devem limitar-se ao domínio `light`.

Criar política configurável de exclusões de grupos/entidades críticas (`excluded_from_bulk_actions`, ou nome equivalente). Excluir por padrão ações de fechaduras, alarmes, segurança, controles de acesso, sensores, rastreadores e serviços cuja semântica não seja simples `turn_off`. Não desligar infraestrutura crítica por inferência; registrar exclusões sem revelar entidades não autorizadas.

Antes de executar, enumerar alvos e validar **exposição, autorização, capability e estado**. Resolver limites atuais de **32 targets por operação** sem truncamento silencioso: usar planejamento limitado com agrupamento/chunks auditáveis e preflight do conjunto completo quando seguro, ou negar com motivo preciso quando exceder capacidade suportada. Jamais executar parte de um grupo sem informar, e nunca repetir ações de efeito incerto. Confirmar a ação coletiva somente quando política de risco configurada ou a ambiguidade exigir; **não solicitar esclarecimento meramente porque a frase não usou a palavra “tudo”**.

## 3. Consultas ambientais e seleção de fonte

### 3.1 Operador genérico `query(metric, area/device)`

Aplicar a mesma arquitetura às métricas disponíveis no HA:

- Temperatura ambiente medida (`sensor` `device_class=temperature`; `climate.current_temperature` apenas quando medida e disponível).
- Umidade (`humidity`).
- Luminosidade (`illuminance`).
- CO₂ / qualidade do ar, conforme classes e unidades realmente publicadas.
- Estado de luzes, ventiladores e outros equipamentos autorizados.
- Bateria (`device_class=battery` e fontes vinculadas a aparelho).
- Presença e aberturas onde existirem entidades semânticas confiáveis.

Consultar **valor vivo**, validar unidade e nunca confundir temperatura ambiente com setpoint do climatizador. Dar preferência à fonte `entity_preferences.preferred` quando explicitamente configurada; na ausência, estabelecer política estável de prioridade por qualidade/semântica. Se duas fontes competirem e não houver preferência segura (temperatura interna vs externa, valores incompatíveis etc.), explicar a ambiguidade e pedir fonte; não escolher arbitrariamente.

Cobrir pelo mesmo mecanismo variações **“no/na/do/da/de/em”**, artigo, acento, plural, apelidos e ordens flexíveis (“quanto está a umidade do escritório?”, “escritório de Bruna, qual a umidade?”) sem codificar nomes próprios.

### 3.2 Estados de erro específicos e verdadeiros

**Separar ao menos:** `unknown_area`, `ambiguous_area`, `no_accessible_sensor`, `sensor_unavailable`, `ambiguous_source`, `invalid_measurement`, `no_compatible_capability`, `permission_denied`, `invalid_request`, `unsupported_intent`, `no_match`, `backend_unavailable`, `stale` e `partial_failure`, com mapeamento adequado para resultado do HA.

Respostas exemplares:

- **Sem fonte acessível:** “Não encontrei um sensor de temperatura acessível no escritório de Jaime.”
- **Fonte conhecida indisponível:** “O sensor de temperatura do escritório de Jaime está indisponível no momento.”
- **Área inexistente:** “Não encontrei um cômodo chamado escritório de Jaime.”
- **Fonte ambígua:** “Há dois sensores de temperatura no escritório. Você quer a temperatura ambiente ou a do equipamento?”
- **Sucesso:** “A temperatura do escritório de Jaime está em 25,3 graus.”

Não informar existência de sensores **não expostos** ao usuário: tratar falta de acesso com formulação segura. Não retornar “Não entendi esse comando” para uma intenção compreendida com erro de resolução ou execução. A mensagem falada do `ConversationResult` deve ser a mesma registrada no resultado final da integração e recebida pelo TTS, respeitando `continue_conversation` quando uma resposta é esperada.

## 4. Consultas globais, filtros e respostas informativas

Distinguir consulta de **existência**, **listagem**, **contagem**, **todos/nenhum** e **comparação**:

- “Tem alguma luz ligada em algum cômodo?” → buscar em todas as áreas autorizadas, sem restringir ao satélite. Responder “Sim. A luz da cozinha está ligada.” ou enumerar as correspondentes; quando nenhuma, “Não, não encontrei luzes ligadas.”
- “Quais luzes estão acesas?” → listar nomes e áreas, com limite de comprimento e resumo se houver muitas.
- “Quantas luzes estão ligadas na sala?” → contar somente as elegíveis na sala.
- “Todas as luzes daqui estão apagadas?” → agregar apenas no cômodo identificado.
- “Tem alguma coisa ligada?” → informar classes de equipamentos realmente interpretáveis como on/off e seus nomes, não sensores binários indiscriminadamente.
- “Tem alguma bateria acabando?” → consulta **determinística**, sem necessidade de LLM, com limiar configurável (ex.: 20%), enumeração dos dispositivos elegíveis e estado de ausência de sensores.

O campo `aggregate=any` atual responde somente `Sim/Não`: adicionar renderização informativa com entidades efetivamente selecionadas; preservar a verdade do agregado. Não interpretar `unavailable/unknown` como `off`, inclusive em `all`; não somar fontes de potência/energia sobrepostas. Evitar expor entidades fora de permissões e nomes demais (truncamento informativo).

## 5. Conversação e clarificações como capacidade de primeira classe

### 5.1 Classificação do resultado

A resposta interna deve distinguir:

1. **Plan** — ação/consulta resolvida.
2. **Clarification** — intenção reconhecida, mas falta informação recuperável; contém razão tipada, opções e plano sem efeitos.
3. **Cannot fulfill** — intenção reconhecida, mas recurso não disponível, fonte indisponível ou sem autorização; motivo específico e resposta final.
4. **Unsupported/no match** — pedido realmente não compreendido; não inventar candidatos.

A clarificação não deve ser acionada para toda falha; somente quando existe uma pergunta específica e potencialmente resolutiva. Onde seguro, permitir recuperar casos de `no_match` com **intenção parcialmente identificável**, sem converter pedidos obscuros em ações perigosas.

### 5.2 Perguntas específicas

- Área não resolvida: “Em qual cômodo?”
- Dispositivo do mesmo tipo ambíguo: “Você quer o ventilador da mesa ou o do teto?”
- Conjuntos por nome vs área diferentes: “Você quer desligar só os dois ventiladores de Jaime ou todos os três do escritório de Jaime?”
- Sensor com duas fontes válidas: “Qual sensor de temperatura você quer consultar?”
- Nenhum sensor compatível: **informar ausência**, não perguntar por um dispositivo que inexiste.
- Área coletiva explícita: **executar**, não pedir confirmação sem motivo.

### 5.3 Continuidade real: SIM/NÃO e seleção de conjunto

Adicionar um tipo de pendência adequado à seleção de conjunto com `options`, `targets`, `scope`, `question`, `confirmation_semantics` e evidências. Não utilizar o `sim` de confirmação de **ação sensível** automaticamente para uma pergunta de **desambiguação de conjunto**. Pergunta com “sim” só deve ser feita quando a proposição for inequívoca (“Quer desligar **todos os três do escritório**?”); preferir perguntas com alternativas rotuladas quando ambos os conjuntos são legítimos.

Exigir:

- Continuidade por `conversation_id` com identidade de usuário e origem/satélite, TTL e invalidação.
- Novo comando independente cancela/descarta a pendência anterior de modo controlado.
- Respostas curtas “sim”, “não”, “os dois”, “todos”, “da mesa”, “do escritório”, “só os que têm Jaime no nome” resolvem a pendência adequada.
- Reconstruir/revalidar catálogo, exposição, permissões, áreas e capabilities antes de qualquer chamada HA.
- `continue_conversation=True` quando houver pergunta; integração HA deve manter e devolver ID da conversa.
- Não executar no turno de clarificação inicial; executar somente após escolha válida.
- Mudar permissões, área, inventário ou sessão deve invalidar a pendência com mensagem específica.

Garantir que o texto falado corresponde ao `speech` efetivo final e que erros de HA no trace sejam distinguíveis do resultado final de `conversation.arandu_nlu`. Não forçar error `no_intent_match` como resposta para uma clarificação válida; usar contrato de resposta apropriado do HA.

## 6. Aparelhos pessoais e seus sensores

### 6.1 Relações explícitas e inferíveis com evidência

Adicionar modelo local de associação:

`pessoa / alias → aparelho → device_id → entidades (battery, tracker, etc.)`

Usar primeiro dados reais do Home Assistant: dispositivo, entidade, aliases, área, classe e metadados de integração. Onde ownership não for dado pelo HA, permitir **configuração explícita** em `entity_preferences`/opções validadas (por exemplo, `person_device_bindings`, `device_sensor_bindings`) sem codificar Jaime, Bruna, Galaxy ou marcas no motor.

Token no nome (“de Jaime”) é **evidência linguística de referência**, não prova de propriedade ou permissão. Ações/consultas são sempre limitadas ao catálogo autorizado e a vínculos auditáveis. Se dois telefones corresponderem a “telefone de Jaime”, pedir qual deles.

### 6.2 Bateria do telefone

“Qual a bateria do telefone de Jaime?” deve:

1. resolver qual aparelho é “telefone de Jaime”;
2. localizar sensores de bateria vinculados ao `device_id` (ou binding explícito), independentemente do nome bruto do sensor;
3. conferir classe, unidade, exposição, permissões, atualidade e estado;
4. selecionar sensor correto e responder com percentual;
5. caso ausente, indicar ausência de sensor **acessível**; caso indisponível, indicar indisponibilidade.

Estender a mesma regra a tablet, notebook e outros dispositivos com sensores equivalentes, sem privilegiar smartphones.

### 6.3 Localização interna de telefones via Bluetooth

**Não implementar triangulação no NLU.** Bluetooth proxies fornecem observações; localização por cômodo depende de uma integração/provedor que estime localizações, como Bermuda BLE Trilateration (ou outra fonte compatível). Não presumir que o telefone anuncia BLE de forma rastreável, nem inferir pessoa por MAC rotativo ou sinal RSSI isolado.

“Onde está o telefone de Jaime?” deve:

1. resolver o dispositivo identificado e autorizado;
2. localizar **sensor/entidade de área dinâmica** ligado ao aparelho, descoberto por metadados compatíveis ou binding explícito;
3. reconhecer valores que identifiquem uma área real do HA;
4. conferir a **atualidade** com sinal confiável de observação (`last_seen` do provedor, timestamp/atributo apropriado), evitando interpretar `last_changed` como garantia universal de frescor;
5. responder com cômodo e informação temporal quando disponível;
6. diferenciar “sem integração de localização”, “nenhuma observação recente”, “telefone não identificado”, “área desconhecida” e “localização ambígua”.

Se o aparelho possuir apenas `area_id` estática do registro HA, **não** apresentá-la como localização física atual. Pode oferecer a informação de cadastro separadamente e identificada como tal.

A solução deve funcionar para “telefone de Bruna”, “meu celular” quando houver contexto/alias explícito, e outros aparelhos com fonte de localização compatível. Não expor localização de pessoa/dispositivo sem autorização correspondente.

## 7. Observabilidade e verificação da versão realmente executada

O caminho `STT → conversation.arandu_nlu → Python → Rust` precisa informar, em diagnóstico seguro:

- versão da integração Python;
- versão do serviço/binário Rust;
- protocolo efetivamente utilizado (v1/v2/v3/v4);
- `contextual_enabled` efetivo;
- caminho de execução e códigos de desfecho com `reason` tipado;
- identificação de build/commit ou fingerprint quando disponível.

**Não quebrar** contrato existente `GET /health` (`{"status":"ok","version":1}` nos clientes atuais). Preferir endpoint de diagnóstico adicional, restrito à rede local interna, ou metadados compatíveis; sem transcrições, segredos, endereço residencial ou inventário privado nos logs. Usar logs sanitizados e, quando possível, correlação por ID sem identificar pessoas.

Criar teste de emparelhamento **integração 0.x ↔ add-on 0.x**, alerta de incompatibilidade e smoke que comprove uso de `/v4/catalog` e `/v4/interpret`; o funcionamento real não pode ser inferido somente pela etiqueta 0.3.2 no Supervisor. Documentar a atualização manual independente de `custom_components/local_nlu` e reinício HA.

## 8. Regras transversais de segurança, desempenho e compatibilidade

- **Autorização:** consultar somente catálogo autorizado pelo usuário, exposto ao Assist; revalidar antes de executar, inclusive em follow-ups.
- **Operações sensíveis:** jamais estender o controle coletivo a fechaduras/alarmes/acesso físico e nunca confundir confirmação com esclarecimento.
- **Conjuntos:** operações compostas por muitos destinos exigem preflight completo, resultado explícito, limites e política de falha parcial; não executar `turn_off` indiscriminado em todas as entidades de área sem checar domínio/capability.
- **Nenhuma ação por aproximação insegura:** matching lexical fraco não autoriza ação. Em disputa de conjuntos, esclarecer.
- **Nenhuma leitura inventada:** unavailable/unknown, unidades incompatíveis, catálogo vencido e stale devem ser propagados honestamente.
- **Compatibilidade:** preservar contratos e comportamento dos caminhos v1/v2/v3 existentes. Evoluir v4 de forma aditiva e sincronizar parsers Rust/Python; documentar eventual migração.
- **Latência:** manter NLU local eficiente; medir Rust puro, HTTP e Python separadamente com catálogo nominal e 4.096 entidades; não prometer números antes de medir. A meta histórica P95 <50 ms para o NLU não inclui STT, TTS nem latência de serviços HA.
- **Dados pessoais:** evitar logar transcrições completas, nomes reais, identificadores BLE e localização sem necessidade.
- **STT:** não modificar STT. Texto corrigido pelo STT basta; metadados STT adicionais não são garantidos no `ConversationInput`.

## 9. Fases obrigatórias e entregáveis

Execute **em ordem**, encerrando cada fase com testes, commit local opcional não destrutivo (se permitido por `AGENTS.md`) e atualização de checkpoint. Não deixar fases seguintes dependentes de contexto de chat. **Nenhum push, merge, release ou deploy residencial sem aprovação explícita do usuário.**

| Fase | Escopo | Entregável objetivo | Gate de conclusão |
|---|---|---|---|
| **F0 — Baseline e inventário** | Ler AGENTS, mapear módulo atual, testes, protocolos, alterações locais e distribuição | Matriz `atual vs especificado`, baseline verificável, checkpoint | Comandos/testes de baseline registrados; mudanças preexistentes preservadas |
| **F1 — Diagnóstico e erros tipados** | Identificação do motor/protocolo executado, classificação dos motivos e resposta HA/TTS | Diagnóstico read-only; `reason` tipado e renderização específica | Testes de resposta final, protocolo, `continue_conversation`, regressão `/health` |
| **F2 — Resolvedor relacional** | Normalização, nomes parciais, aliases, área, categoria, `device_id`, bindings explícitos, comparação de conjuntos | Modelo semântico e seleção de conjuntos evidenciada | Fixtures com pessoas/cômodos genéricos, conjuntos iguais/diferentes e nomes conflitantes |
| **F3 — Operações coletivas por área** | `area.turn_off`, filtros de categoria, política de exclusões, preflight, chunking/falha parcial | Desligar cômodo inteiro em todas as formulações equivalentes | E2E de 1/3/>32 alvos, sensores e locks ignorados, autorização revalidada |
| **F4 — Consultas e agregações** | Temperatura, umidade, luminosidade, CO₂, estado, bateria baixa, existência/listagem e renderização rica | Consulta genérica por área e entidade, respostas com nomes/valores e ausência tipada | Testes de fontes múltiplas/indisponíveis, unidades e consultas globais/locais |
| **F5 — Diálogo e recuperação** | Clarificações por motivo, opções e sets, sim/não, turnos, TTL, transições | Diálogo completo que retoma operação original | Testes Rust HTTP + Python `ConversationResult`, nenhum efeito antes da decisão |
| **F6 — Dispositivos pessoais** | Pessoa↔telefone↔sensores; bateria por device_id; adaptadores de localização BLE externa | Consultas a bateria e localização dinâmica com atualização/falha segura | Fixtures sem provider, com provider, stale, binding explícito, homônimos |
| **F7 — Integração e validação** | Corpus inteiro, testes novos, benchmark, build, distribuição e docs | Evidências reprodutíveis, manuais, changelog, release preparada | Gate oficial passa; ZIP/Docker verificados; limitações reais registradas |

### F0 — Inventário detalhado

Inspecionar `AGENTS.md`, `addon/engine/src/contextual`, `addon/engine/data/grammar.json`, `custom_components/local_nlu`, `tests/mlp`, `tools/mlp-check`, `tools/distribution.py`, `INSTALL.md` e `docs/nlu-2.0`. Confirmar versão, branch, dirty files e identidades das cópias do add-on. Registrar baseline Rust/Python e fixture real ausente. **Não reescrever motor nem pacote por conjectura.**

### F1 — Mensagens e versão

Primeiro tornar diagnosticável se o v4 está ativado no HA. Introduzir enumeração de falhas por estágio (intent / area / entity / capability / read / execution / dialogue). Contratos e renderer entregam linguagem específica; exceções inesperadas não expõem dados pessoais. Validar com `conversation.py` e teste real do `ConversationResult`. Não mudar `/health` incompatibilmente.

### F2 — Relações e seleção

Criar índice invertido leve para tokens discriminativos, tipos de dispositivo, área, aliases e relações explícitas; disponibilizar enumeração de `S_nome`, `S_area`, `S_dispositivo` e sua origem. A semântica de área explícita tem precedência. Incluir exemplos com nomes alternativos (João/Ana, Estúdio de Ana, laboratório, ventiladores diferentes) para evitar overfitting a Jaime/Bruna.

### F3 — Área inteira

Implementar controle por área como plano de múltiplas ações HA autorizadas; **não interpretar** `desliga o escritório` como escolha de um único dispositivo. Respeitar `turn_off` disponível, exposições, exceções e limites. Permitir grupos grandes com lote seguro ou falha explícita; detalhar sucesso parcial quando ocorrer. Confirmar que não desliga `lock` ou sensores, que não ignora 33º alvo e que plano foi recalculado após mudanças de permissões.

### F4 — Consultas

Desacoplar padrão linguístico de seletor de métrica/área. Suportar “no” e “do” e sinônimos, sem depender da enumeração literal. Selecionar fonte por atributos e relações, unidade correta, `preferred`; renderizar entidades e áreas em agregações. Diferenciar nenhum sensor, não autorizado sem vazamento, indisponível, ambiguidade, valor inválido e erro de integração. Filtros de bateria baixa são determinísticos.

### F5 — Diálogo

Adicionar distinção formal **seleção de alternativa** vs **confirmação de ação sensível**. `sim/não` deve funcionar conforme a pergunta ativa e vinculada ao contexto; `sim` solto não pode disparar ações inesperadas. Retestar continuidade em duas ou três requisições do Assist com `conversation_id` estável, inclusive após reinicialização da pipeline se a integração suportar tal contexto; caso não suporte, documentar o limite exato.

### F6 — Telefones

Criar relações descobertas pelo HA (`device_id`, sensor class) e configurações declarativas para falta de metadados. Localização interior deve consumir entidade/atributo publicamente observável por Bermuda ou outra integração; **não criar medidor BLE/estimativa no NLU**. Detectar dados antigos e fonte ausente sem fabricar resposta. Telefone de Jaime/Bruna são fixtures exemplares, não aliases embutidos.

### F7 — Release

Executar `./tools/mlp-check` e scripts oficiais confirmados na F0; conferir regressões Rust, Python, HTTP real, política, corpus de 1.946 frases/165 intenções e medir benchmarks com 4.096 entidades. Separar percentuais de reconhecimento, plano, execução simulada, recusas corretas e funcionalidades condicionais. Verificar Docker `amd64`/`aarch64` quando possível, distribuição única do add-on, lockfile/versionamento e ZIP extraído. Atualizar `README.md`, `INSTALL.md`, `docs/nlu-2.0/DEPLOYMENT.md` e relatório de resultados. Se versão mudar, aplicar política já existente de versões sincronizadas, sem atualizar dependências indevidamente.

## 10. Testes de aceitação: famílias, não frases decoradas

Construir matriz parametrizada de variações lexicais, áreas, permissões e configurações. Para cada cenário, verificar **intenção, targets, reason, operações HA, fala final e continuidade**, não somente `status=plan`.

| Família | Exemplo mínimo | Esperado |
|---|---|---|
| Temperatura área | “qual a temperatura no escritório de Jaime” | leitura real do sensor da área ou falha específica por inexistência/indisponibilidade |
| Temperatura variações | “qual a temperatura do escritório de Bruna”; “quanto tá de temperatura aqui?” | mesma semântica, alterando somente área/origem |
| Umidade | “quanto está a umidade do quarto?” | sensor humidity elegível; valor e unidade |
| Área coletiva | “desliga o escritório de Jaime”; “desliga tudo no escritório de Jaime” | mesmo conjunto elegível, sem clarificação desnecessária |
| Luzes específicas | “desliga todas as luzes do escritório” | só luzes da área |
| Conjuntos iguais | 2 fans Jaime = todos os fans da área | desliga os 2 sem perguntar |
| Conjuntos diferentes | 2 fans Jaime, 3 fans na área | pergunta qual conjunto; zero serviços inicialmente |
| Área explícita | “desliga os ventiladores do escritório de Jaime” | desliga todos os 3 sem perguntar |
| Multi-turno | “desliga os ventiladores de Jaime” → “os três do escritório” | executa exatamente os 3 e expira pendência |
| Confirmação binária | pergunta “Quer todos os três do escritório?” → “sim” | executa alternativa explicitada, após revalidação |
| Luz ligada global | “tem luz ligada em algum cômodo?” | sim + nomes/áreas das luzes autorizadas acesas |
| Quais luzes | “quais luzes estão ligadas?” | listar somente correspondências, não apenas “Sim” |
| Nenhuma luz | todas off | “Não, não encontrei luzes ligadas” |
| Leitura indisponível | sensor existe, `unavailable` | informar indisponibilidade, não “não entendi” |
| Falta de fonte | área existe sem sensor de temperatura acessível | informar ausência específica |
| Áreas homônimas | 2 áreas com alias equivalente | pedir esclarecimento, nunca selecionar primeira |
| Bateria por dispositivo | “qual a bateria do telefone de Bruna?” | resolver dispositivo → sensor vinculado e ler percentual |
| Bateria baixa | “tem algum dispositivo com bateria acabando?” | aplicar limiar, citar nomes e valores, sem LLM |
| Telefone localizável | provider informa `Escritório` fresco | informar escritório e atualidade sem confundir área cadastrada |
| Telefone não localizável | provider ausente ou dado stale | informar impossibilidade, sem inventar localização |
| Autorização | entidade não exposta ou sem permissão | não consultar nem executar; não vazar o nome |
| >32 aparelhos | controle coletivo com 33+ elegíveis | tratar todos com política segura ou negar explicitamente; sem truncamento |
| Retry incerto | chamada HA com efeito possivelmente aplicado e timeout | não repetir automaticamente |
| Compatibilidade | v1/v2/v3 existentes; `/health` | contratos preservados |
| TTS/HA | resultado final de clarificação | fala definida pela integração, `continue_conversation=True`, sessão correta |

Gerar variações automáticas sobre **cômodos fictícios diferentes**, singular/plural, posições de preposição, nomes sobrepostos, sensores com várias fontes, aparelhos que mudam de cômodo e permissões alteradas entre planejamento e execução. Incluir negativos, comandos sem intenção clara e colisões. Não elevar artificialmente a taxa de sucesso executando comandos não autorizados.

**Critério de cobertura:** todos os requisitos funcionais das seções 2–8 precisam de teste correspondente e demonstração, não apenas de documentação. Para integração externa (Bermuda, proxy BLE real), validar adaptador com fixtures e declarar que operação física requer provider configurado; uma ausência legítima não equivale a falha do NLU.

## 11. Entregas documentais

Atualizar ou criar no repositório:

1. `docs/nlu-2.0/CONTEXTUAL_CAPABILITIES_IMPLEMENTATION.md` — esta especificação, mantida com checklist de conformidade atualizado.
2. `docs/nlu-2.0/CONTEXTUAL_IMPLEMENTATION_CHECKPOINT.md` — checkpoint persistente de fases e próxima ação.
3. `docs/nlu-2.0/CONTEXTUAL_GAP_COVERAGE.md` — requisitos ↔ arquivos implementados ↔ testes ↔ resultado ↔ limitações.
4. `docs/nlu-2.0/CONTEXTUAL_IMPLEMENTATION_REPORT.md` — evidências finais, cobertura, benchmarks, riscos e passos de atualização.
5. `README.md`, `INSTALL.md`, `DEPLOYMENT.md` — ajustes necessários, sem duplicação desnecessária.

### Conteúdo obrigatório do checkpoint

```markdown
# Checkpoint — Arandu NLU contextual

- Branch / HEAD / data:
- Versão add-on / integração / protocolo:
- Estado inicial do git (dirty files preservados):
- Fase atual: F0/F1/F2/F3/F4/F5/F6/F7
- Fases concluídas (com commit/teste/evidência):
- Arquivos alterados nesta fase:
- Testes executados (com comandos e resultados reais):
- Erros ainda abertos (severidade e reproduções):
- Decisões técnicas tomadas e justificativa:
- Requisitos ainda não implementados:
- Bloqueios de ambiente (HA real, Bermuda real, ARM etc.):
- Próxima ação exata (arquivo/função/comando):
- Comando de retomada:
```

Atualizar após **cada fase** e antes de interrupção por limite de contexto/uso. Não gravar segredos, arquivos de HA residencial ou dados pessoais desnecessários. Um segundo agente deve conseguir continuar usando apenas `AGENTS.md`, este documento e o checkpoint.

## 12. Regras operacionais para o Codex

- **Executar**, não apenas sugerir plano. Não encerrar após documentação se ainda existir código pendente.
- Ler `AGENTS.md` e instruções do repositório antes de editar; preservar toda modificação local existente. Nunca `git reset --hard`, `git clean -fd` ou reescrita destrutiva.
- Priorizar correções nos módulos existentes; mudanças ao contrato v4 devem ser aditivas e refletidas no Rust, Python e testes.
- Trabalhar em uma fase de cada vez, com mudanças pequenas e verificáveis; atualizar checkpoint antes de iniciar a fase seguinte.
- Se limite de tempo/uso se aproximar, terminar operação segura, executar teste local relevante, escrever próxima ação e parar sem prometer conclusão posterior.
- Não solicitar confirmação para escolhas técnicas comuns. Se dados de uma residência real forem essenciais, implementar adaptador genérico/configurável e registrar o teste físico como pendência, em vez de inventar mapeamentos.
- Não mascarar exceções e testes falhos, nem apresentar testes simulados como validação HA residencial.
- Não enviar push, abrir PR, publicar release, instalar no HA real ou alterar STT sem autorização específica.
- Ao terminar, entregar relatório por fase com referências a testes e demonstrar funcionamento em Rust HTTP + executor Python simulado; informar a versão exata e as instruções independentes de atualização do add-on e da integração.

## 13. Checklist final — conclusão da missão

- [x] Identificado, via diagnóstico, o motor Rust/versão/protocolo realmente acionados pela integração.
- [x] Erros e ausências de sensores têm resposta falada específica; não são mascarados como `no_intent_match`.
- [x] Consultas ambientais genéricas por área funcionam em variações `no/do/da/em/aqui`.
- [x] Consultas globais e locais retornam informação de nomes, cômodos, estado e/ou métricas corretas.
- [x] Seleção nominal composicional funciona por categoria + modificadores + aliases.
- [x] Comparação de conjunto por nome vs conjunto por cômodo implementada com clarificação só quando necessário.
- [x] “Desliga o cômodo” e “desliga tudo no cômodo” produzem a mesma ação coletiva correta.
- [x] Ações coletivas têm autorização, exclusões e suporte seguro a conjuntos grandes.
- [x] Clarificação contextual funciona em diálogo realista multi-turno, inclusive seleção de conjuntos e sim/não contextual.
- [x] Resposta final HA/TTS e `continue_conversation` refletem a operação correta.
- [x] Pessoa/telefone/sensor de bateria são vinculados por dados reais/associações explícitas.
- [x] Localização indoor por integração BLE externa é consultável com validade temporal e indisponibilidade segura.
- [x] Consulta de bateria baixa determinística retorna entidades e valores elegíveis.
- [x] Segurança, exposições, permissões e contratos antigos preservados.
- [x] Cada família tem testes com nomes/áreas variantes e casos negativos.
- [x] Gate oficial Rust/Python/HTTP passa sem mascarar erros.
- [x] Corpus 1.946/165 reavaliado com métricas diferenciadas.
- [x] Benchmarks e build/distribuição validados conforme possibilidades do ambiente.
- [x] Documentação, matriz de cobertura, relatório e checkpoint concluídos.
- [x] Limitações de HA residencial/integrações externas registradas honestamente.
- [x] Nenhum push, release, deploy residencial ou mudança no STT foi feito sem autorização.

Verificação em 2026-10-07: F0–F7 concluídas conforme checkpoint, matriz e
relatório contextual 0.4.0. Bluetooth/HA são simulados; aarch64 é emulada.
Push final para master foi expressamente autorizado pelo usuário.

**Condição de parada:** todas as caixas implementáveis em workspace e testes foram verificadas. Funcionalidade dependente de hardware/integrador externo deve estar implementada como consumidor configurável e testada com mocks/fixtures; não pode ser marcada como validada fisicamente sem dispositivo/HA real.
