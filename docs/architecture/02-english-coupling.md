# Inventário de Acoplamento ao Inglês

Data da análise: 2026-08-12

## Critério desta análise

Classificações usadas por componente:

- `reutilizável sem alterações`: a estrutura observada não carrega hipótese forte sobre inglês.
- `reutilizável com abstração`: a ideia arquitetural é aproveitável, mas o código atual embute premissas linguísticas.
- `requer substituição parcial`: parte da estrutura pode inspirar a nova implementação, porém regras centrais precisam mudar.
- `requer reimplementação`: o comportamento atual está fortemente ancorado em inglês ou em uma representação insuficiente para PT-BR.
- `ainda desconhecido`: não foi possível confirmar na fase atual.

Importante:

- esta classificação trata de adequação técnica para PT-BR;
- ela não revoga as restrições legais levantadas em `[E-006] [E-007] [E-033] [E-036]`;
- mesmo itens “reutilizáveis” não devem ser copiados para o produto sem base legal adequada.

## Resumo

`CONFIRMADO`: os principais acoplamentos ao inglês estão em:

- remoção de não ASCII;
- posse por apóstrofo `"'s"`;
- listas fixas de palavras inglesas para tempo, negação, auxiliares e advérbios;
- heurísticas morfológicas por prefixo e sufixo ingleses;
- tagset POS baseado em Penn Treebank;
- heurísticas de pessoa centradas em `you`;
- documentação e exemplos apenas em inglês;
- banco lexical padrão `language = "en"` no schema default.

## Matriz principal

| Componente | Evidência | Acoplamento | Estratégia | Risco |
| --- | --- | --- | --- | --- |
| limpeza inicial Unicode | `tokenizer::Tokenizer::initial_clean` remove `[^\x20-\x7E]` `[E-017]` | descarte de diacríticos, cedilha e qualquer caractere fora de ASCII imprimível | requer reimplementação com normalização Unicode preservando grafemas e mapeamentos controlados | Muito alto |
| posse por apóstrofo | `TokenCleaner::scan_chars` trata `"'s"` como posse `[E-018]` | regra específica do inglês; não cobre contrações/preposições+artigos do PT-BR | requer reimplementação | Alto |
| décadas e horários | `TokenCleaner::is_decade` e `is_time` `[E-018]` | décadas com sufixo `s`; horários só em formatos ingleses simples | requer substituição parcial | Médio |
| pré-processamento lexical de datas/períodos | listas `last`, `next`, `ago`, `later` etc. `[E-019]` | vocabulário fixo em inglês para tempo relativo | requer reimplementação | Alto |
| negação e auxiliares por forma de superfície | lógica de `not`, `have`, `has`, `had` no tokenizador `[E-019]` | verbos auxiliares e negação codificados em inglês | requer reimplementação | Alto |
| future verb phrases | `future_verb_prefixes` e `check_future_verb` `[E-019]` | modelagem explícita de futuro perifrástico do inglês | requer reimplementação | Alto |
| tagset POS | `POSTag` baseado em Penn Treebank `[E-020]` | granularidade e nomes de tags orientados ao inglês | reutilizável com abstração | Alto |
| contexto POS por listas léxicas | `MODAL_VERBS`, `AUXILLARY_VERBS`, `TEMPORAL_ADVERBS`, `COMMON_ADVERBS` `[E-022]` | listas fixas de inglês, inclusive modal system e adverb inventory | requer reimplementação | Muito alto |
| heurísticas por sufixo | `ing`, `ly`, `tion`, `ness`, `ward`, `wise` etc. `[E-023]` | morfologia derivacional do inglês | requer reimplementação | Muito alto |
| heurísticas por prefixo | `un`, `re`, `mis`, `anti`, `de`, `pre`, `fore` etc. `[E-023]` | morfologia prefixal centrada em inglês | requer reimplementação | Alto |
| inferência de pessoa | `you` fixa segunda pessoa e ausência de pronome implica segunda pessoa `[E-028]` | acoplamento direto à forma inglesa e à pragmática imperativa atual | requer substituição parcial | Alto |
| coreferência de pronome | enums de gênero/pessoa/número + resolução por antecedente `[E-029]` | a estrutura é genérica, mas depende de inventário pronominal do léxico atual | reutilizável com abstração | Médio |
| named entities por capitalização | lógica de capitalização em HMM/token `[E-021] [E-024]` | heurística frágil para PT-BR coloquial e STT | requer substituição parcial | Médio |
| intent phrase trie | `PhraseIntents` sobre IDs de token `[E-027]` | estruturalmente genérico, mas depende do léxico e da tokenização do inglês | reutilizável com abstração | Médio |
| scores de classificação | `classification_scores` por token/MWE `[E-024] [E-025]` | estrutura genérica, sem acoplamento lexical intrínseco | reutilizável com abstração | Médio |
| DTOs da edição premium | `OutputToken`, `OutputPhrase`, `SelectorResponse` `[E-034]` | nomes de campos em inglês; interface conceitualmente genérica | reutilizável com abstração | Baixo |
| documentação e exemplos | README e examples usam apenas inglês e ainda divergem da API `[E-008] [E-032]` | baixa utilidade como especificação de PT-BR | requer substituição parcial | Médio |
| default do banco lexical | `VocabDatabaseMeta::default().language = "en"` `[E-014]` | idioma default fixado em inglês | requer substituição parcial | Baixo |

## Inventário detalhado por área

### 1. Normalização e Unicode

`CONFIRMADO`:

- há remoção explícita de não ASCII antes da tokenização `[E-017]`;
- isso afetaria diretamente `á`, `à`, `ã`, `â`, `ç`, `é`, `ê`, `í`, `ó`, `ô`, `õ`, `ú` e quaisquer sinais similares em PT-BR.

Classificação:

- estado atual: `requer reimplementação`.

Riscos PT-BR:

- perda de contraste lexical;
- colisão indevida entre formas distintas;
- degradação de entidades, marcas e nomes próprios;
- dificuldade para correção controlada de erros de STT.

### 2. Tokenização e contrações

`CONFIRMADO`:

- o código trata posse inglesa por `"'s"` `[E-018]`;
- o pré-processamento depende de `hashes` e listas inglesas de datas/tempos `[E-019]`.

`DESCONHECIDO`:

- o conteúdo efetivo do banco `preprocess.hashes` do inglês, porque não havia `.dat` disponível no workspace.

Classificação:

- estado atual: `requer reimplementação`.

Riscos PT-BR a investigar na Fase 2:

- contrações de preposição+artigo;
- pronomes clíticos;
- mesóclise/próclise/ênclise;
- comandos sem verbo explícito;
- pontuação irregular produzida por STT.

### 3. Números, datas e unidades

`CONFIRMADO`:

- existem regras para `|num|`, `|time|`, `|date_period|`, `|time_period|` e sufixos numéricos `[E-018] [E-019]`.

`INFERIDO`:

- a modelagem conceitual de tags especiais pode ser reaproveitada, mas o inventário lexical e as regras devem ser redesenhados para PT-BR.

Classificação:

- estado atual: `requer substituição parcial`.

### 4. POS tagging

`CONFIRMADO`:

- a infraestrutura HMM/Viterbi é genérica `[E-021]`;
- o tagset e grande parte das features são ingleses `[E-020] [E-022] [E-023]`.

Classificação:

- infraestrutura: `reutilizável com abstração`;
- dados, features e heurísticas: `requer reimplementação`.

### 5. Morfologia e correção ortográfica

`CONFIRMADO`:

- a correção ortográfica usa distância de Levenshtein e bônus por prefixo/sufixo/double letter `[E-023]`;
- prefixos e sufixos são ingleses `[E-023]`.

Classificação:

- arcabouço de ranking contextual: `reutilizável com abstração`;
- regras morfológicas e cohorts atuais: `requer reimplementação`.

Riscos PT-BR:

- flexão verbal extensa;
- gênero e número;
- alternâncias ortográficas legítimas;
- erros reais de STT diferentes de typos de teclado.

### 6. Interpretação, intents e coreferência

`CONFIRMADO`:

- há IR frasal e resolução simples de antecedentes `[E-025] [E-026] [E-029]`;
- há apenas um intent por frase no estado atual `[E-027]`;
- a pessoa pode ser inferida por `you` ou por default de segunda pessoa `[E-028]`.

Classificação:

- IR estrutural: `reutilizável com abstração`;
- heurísticas de pessoa e inventário pronominal atual: `requer substituição parcial`.

### 7. Sessão e esclarecimentos

`CONFIRMADO`:

- não há evidência de sessão persistente, turn memory ou pedidos de esclarecimento no crate público `[E-030] [E-035]`.

Classificação:

- estado atual: `ainda desconhecido` para o sistema premium completo; `ausente` no núcleo público inspecionado.

### 8. Integração externa e Home Assistant

`CONFIRMADO`:

- o site menciona CLI/RPC localhost para a edição premium `[E-035]`;
- o código público inspecionado não traz adaptador Home Assistant `[E-037]`.

Classificação:

- protocolo premium: `ainda desconhecido` em implementação;
- integração HA: `ausente` no código público inspecionado.

## Componentes classificados

| Componente | Classificação atual |
| --- | --- |
| loader do artefato lexical | reutilizável com abstração |
| cache de typos | reutilizável com abstração |
| normalização Unicode | requer reimplementação |
| tokenização | requer reimplementação |
| MWE trie como conceito | reutilizável com abstração |
| regras de tempo/data do tokenizador atual | requer reimplementação |
| HMM/Viterbi como técnica | reutilizável com abstração |
| POS data/features atuais | requer reimplementação |
| spell checker contextual como ideia | reutilizável com abstração |
| morfologia atual por prefixo/sufixo | requer reimplementação |
| IR de frase/noun/verb | reutilizável com abstração |
| multi-intent | requer reimplementação |
| coreferência básica | reutilizável com abstração |
| sessão/clarificação | ainda desconhecido |
| adaptador Home Assistant | ausente no código público |

## Conclusão

- `CONFIRMADO`: o acoplamento ao inglês não está restrito a dados; ele aparece no código executável público em Unicode, léxico, morfologia, tagset e heurísticas pragmáticas `[E-017] [E-018] [E-019] [E-020] [E-022] [E-023] [E-028]`.
- `DECISÃO PROPOSTA`: o port para PT-BR não deve ser tratado como tradução de vocabulário; ele exige uma arquitetura multilíngue explícita, com clean-room para as camadas linguísticas críticas.
