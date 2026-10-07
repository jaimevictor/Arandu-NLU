# Arandu NLU 2.0

O motor Rust continua local e passivo. A integração Python continua sendo a única fronteira de execução no Home Assistant. As rotas v1, v2 e v3 foram preservadas; o motor contextual usa o contrato v4. `contextual_enabled=false` restaura a seleção anterior da integração.

## Caminho executável

1. A integração identifica o usuário, exposição e permissões; compila descritores de entidades, dispositivos, áreas, aliases, classes, serviços e capacidades.
2. Envia `/v4/catalog` somente quando muda a geração SHA-256. O Rust constrói índices de nomes, áreas, domínios e operações compatíveis.
3. Cada `/v4/interpret` contém texto, geração, origem e contexto mínimo. Normalização Unicode, números PT-BR, gramática compilada, resolução e planejamento produzem operações tipadas.
4. O executor valida o plano inteiro antes do primeiro efeito. Antes de cada chamada, confere novamente usuário, exposição, registro, área, classe, capacidade, serviço e parâmetros relativos no estado atual.
5. Consultas leem valores atuais, não valores armazenados no catálogo. Falha depois de um efeito interrompe o restante e informa execução parcial.

Não há embeddings, LLM, busca aproximada, subprocesso por fala, credenciais do HA no Rust ou execução de serviços escolhidos livremente pelo texto. O vocabulário semântico complementa os nomes reais; não inventa IDs.

## Resolução e contexto

Identidade contextual 0.4.3: identity.py resolve o ConversationInput completo uma
vez, pela ordem contexto, associação de satélite, associação de dispositivo,
fallback explícito. Guarda user_id/user/source imutáveis; revalidação atualiza
somente as permissões do mesmo ID. Sessões usam esse ID efetivo, origem e conversa;
mudança de fonte ou configuração invalida pendências. Um listener de opções
também invalida mudança seguida de restauração durante I/O. [Evidências](MISSING_USER_RESIDENTIAL_FIX.md).

Prioridade: ID explícito, alias do usuário, nome amigável, nome do dispositivo, tipo semântico. Área explícita limita o candidato; uma área desconhecida pede esclarecimento. Se “da TV” faz parte de um nome registrado completo, esse nome pode ser resolvido como unidade. Tipos genéricos podem usar a área de origem e uma preferência configurada. Dois alvos equivalentes pedem esclarecimento.

Origem: `satellite_id` registrado → área efetiva; senão `device_id` → área do dispositivo; senão `default_area` válido. Sem evidência, “aqui” pede o cômodo. A localização de uma pessoa nunca define automaticamente seu quarto.

Sessões em memória são separadas por usuário, origem e `conversation_id`; máximo 128, TTL configurável de 1–600 segundos. Guardam IDs recentes, comando pendente tipado e resposta curta. Confirmações sensíveis expiram em até 30 segundos, dependem da mesma geração e nunca atravessam usuário/origem. Não existe histórico de texto persistente. Reinício apaga contexto.

## Capacidades e consultas

`capabilities.py` mantém adaptadores fechados para luz, ventilador, clima, umidificação, aquecedor, mídia, cover, lock, vacuum, mower, timers, calendário, weather, todo, cenas, scripts, botões e helpers. Serviços, flags e listas de modos filtram as operações disponíveis. `supported_features` sozinho não prova que o serviço existe.

Temperatura ambiental usa sensor de classe adequada ou `current_temperature` medido no clima. O alvo `temperature` nunca substitui uma medição ambiental. Presença humana usa classe occupancy/presence/motion; sensores distintos continuam distintos. Soma de energia/potência exige fontes explicitamente configuradas, unidades iguais e dispositivos não sobrepostos. Sem dados, não há resposta inventada.

Agregadores: contagem, algum, todos, mínimo, máximo, soma, média, comparação e filtro, sobre no máximo 32 resultados. O tipo e a unidade devem ser compatíveis. Os limites de temperatura, helpers e cor são obtidos do estado atual; incrementos relativos são configuráveis e usam o valor atual.

Grupos de andar vêm de floor_registry e da associação area.floor_id. O motor mantém a distinção entre luzes, ventiladores e aparelhos; aliases de áreas colidentes não viram grupos automaticamente. O executor confere a associação atual ao andar antes de cada efeito. Mínimo/máximo usam limites reais; mínimo de ventilador usa percentage_step positivo. Baixo/médio/alto representam 25/50/75% da faixa e metade representa 50%; a porcentagem do ventilador é ajustada ao passo suportado.

## Limites e sincronização

Máximo 2 MiB de catálogo, 8.192 entidades, 256 áreas, oito aliases por entidade; oito gerações no Rust. Texto até 512 caracteres/2.048 bytes; até quatro operações ordenadas e 32 alvos por operação. HTTP possui limite de conexões e timeout; HA possui timeout de dez segundos por operação.

O cache Python usa até 16 catálogos por usuário, TTL de cinco segundos e invalidação por registro, áreas, dispositivos, serviços, exposição e mudanças nos atributos de capacidade. Valores numéricos transitórios não recompilam o catálogo. A autorização e as capacidades são verificadas ao vivo mesmo durante o TTL. O executor serializa os próprios ajustes relativos; automações externas podem concorrer e mudanças detectadas causam abstenção.

Negações cancelam sem efeitos. Condições e exceções não suportadas abstêm. Planos compostos precisam ser completamente resolvidos; não se guarda uma metade executável quando falta alvo. Reutilização contraditória de uma propriedade é rejeitada. Repetição idêntica na mesma sessão em dois segundos não repete efeitos.

## Organização

- `addon/engine/src/contextual/`: contrato, slots, gramática, índices e planejamento.
- `custom_components/local_nlu/contextual_*`: catálogo, contrato e executor.
- `capabilities.py` e `queries.py`: ligação com serviços e consultas.
- `data/contextual/`: inventário, proveniência, especificação e resultados reproduzíveis.
- `tools/import-stt-corpus.py`, `contextual-evaluate.py` e exemplo Rust `contextual_bench`: importação, cobertura e medições.

O corpus STT é referência de conformidade interna e também alimenta templates. Seus resultados não medem generalização independente. A especificação adicional do projeto foi registrada antes da implementação. Consulte REPORT.md para os resultados e limitações exatas.
