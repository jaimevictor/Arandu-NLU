# Política de Proveniência de Dados e Vocabulário

Data da política: 2026-08-12

Status:

- `DECISÃO PROPOSTA` para este projeto;
- obrigatória para qualquer fase posterior que toque em dados linguísticos.

## Objetivo

Garantir que nenhuma entrada lexical, regra linguística observacional, dataset de treino, dataset de validação ou conjunto de avaliação entre no projeto sem origem verificável, licença registrada e trilha de transformação auditável.

## Regras mandatórias

### DECISÃO PROPOSTA

- nenhuma palavra entra no projeto sem proveniência;
- nenhuma fonte “lembrada pelo modelo” é aceitável;
- nenhuma lista gerada automaticamente por LLM é aceitável como vocabulário de produção;
- nenhum dado gerado pelo próprio sistema pode virar evidência linguística primária;
- treino, validação e avaliação devem permanecer separados;
- dados sem licença clara ou com licença incompatível devem ser rejeitados;
- toda transformação deve ser reprodutível e registrada.

## Classes de dados

Estas classes devem permanecer separadas física e logicamente:

1. léxico geral do português;
2. léxico especializado de automação residencial;
3. entidades importadas dinamicamente do Home Assistant;
4. aliases definidos pelo usuário;
5. formas observadas em erros reais de STT;
6. dados usados para treino;
7. dados usados para validação;
8. conjunto oculto de avaliação.

### DECISÃO PROPOSTA

- nenhuma classe pode ser implicitamente fundida com outra;
- aliases do usuário nunca devem contaminar o léxico geral;
- entidades dinâmicas do HA nunca devem ser promovidas automaticamente a vocabulário global;
- erros observados de STT devem ser armazenados como observações, não como verdade lexical.

## Manifesto mínimo por entrada lexical

Cada entrada lexical futura deve carregar, no mínimo:

| Campo | Obrigatório | Observação |
| --- | --- | --- |
| `entry_id` | sim | identificador estável interno |
| `surface_original` | sim | forma exatamente como veio da fonte |
| `surface_normalized` | sim | forma normalizada conforme pipeline aprovado |
| `language` | sim | ex. `pt` |
| `variant` | sim | ex. `pt-BR` |
| `source_name` | sim | nome da fonte |
| `source_version` | sim | versão, edição ou data da fonte |
| `source_location` | sim | URL, DOI, caminho ou identificador oficial |
| `source_license` | sim | SPDX ou descrição rastreável |
| `extraction_method` | sim | manual, script, parser, importador etc. |
| `grammatical_category` | sim | conforme schema do projeto |
| `confidence` | sim | confiança da importação/rotulação |
| `imported_at_utc` | sim | timestamp UTC |
| `transformations_applied` | sim | lista ordenada de transformações |
| `review_status` | sim | pendente, aprovado, rejeitado |
| `reviewer` | sim | humano responsável |
| `notes` | não | observações adicionais |

## Manifesto mínimo por dataset

Cada dataset, corpus, inventário ou dump deve carregar:

- nome;
- versão;
- origem oficial;
- licença;
- hash do arquivo bruto;
- hash do arquivo normalizado;
- data de obtenção;
- método de obtenção;
- particionamento pretendido (`train`, `validation`, `test`, `hidden-eval`, `entities`, `aliases`, `stt-observed`);
- exclusões e filtros aplicados;
- revisão humana responsável.

## Licenças

### DECISÃO PROPOSTA

Regras:

- registrar a licença por fonte e por subcomponente, não apenas por “dataset” genérico;
- se a fonte mistura licenças, separar fisicamente os subconjuntos antes da importação;
- se a licença não puder ser confirmada, a fonte deve ser bloqueada;
- se a licença permitir leitura, mas não distribuição comercial ou obras derivadas, a fonte não entra em artefato distribuível do produto.

Observação:

- este projeto não trata esta política como parecer jurídico;
- dúvidas jurídicas devem virar bloqueio explícito, não “assunção razoável”.

## Hashes e integridade

### DECISÃO PROPOSTA

Requisitos:

- todo arquivo bruto recebido deve ter hash criptográfico;
- toda transformação relevante gera novo hash;
- manifestos devem armazenar a cadeia `raw_hash -> normalized_hash -> compiled_hash`;
- o compilador offline deve falhar se o hash de entrada divergente não estiver registrado;
- nenhum artefato binário entra no runtime sem hash verificado.

## Deduplicação

### DECISÃO PROPOSTA

Deduplicação deve ocorrer em níveis distintos:

- textual: mesma forma normalizada;
- lexical: mesmo lema + mesma classe gramatical;
- origem: mesma fonte e mesmo trecho;
- observacional: mesmo erro de STT repetido por múltiplos usuários.

Regras:

- deduplicação não pode apagar a proveniência;
- ao fundir entradas, preservar todas as origens;
- aliases do usuário não devem ser deduplicados contra nomes oficiais sem revisão humana.

## Normalização

### DECISÃO PROPOSTA

Toda normalização deve ser:

- reversível quando aplicável;
- registrada por etapa;
- específica por idioma/variante;
- separada da forma original.

Exemplos de metadados de transformação:

- forma Unicode canônica aplicada;
- mapeamento de caixa;
- remoção ou preservação de pontuação;
- tratamento de diacríticos;
- segmentação de contrações;
- expansão controlada de abreviações.

Regra:

- a forma normalizada nunca substitui a forma original no armazenamento.

## Separação entre treino, validação e avaliação

### DECISÃO PROPOSTA

Obrigatório:

- conjuntos de treino, validação e hidden evaluation devem ter manifestos separados;
- uma mesma ocorrência bruta não pode aparecer em mais de um conjunto;
- exemplos produzidos pelo próprio sistema não entram em nenhum conjunto independente de avaliação;
- feedback de produção só pode migrar para treino após curadoria e particionamento formal.

Condições de bloqueio:

- ausência de partição formal;
- partição feita manualmente sem registro;
- mistura de aliases do usuário com conjunto oculto de avaliação.

## Prevenção de contaminação

### DECISÃO PROPOSTA

Fontes proibidas como evidência primária:

- palavras inventadas manualmente sem fonte;
- listas “sugeridas” por LLM;
- exemplos sintéticos sem rotulagem de sintético;
- outputs anteriores do próprio motor;
- textos de benchmark reutilizados em treino após sua criação como benchmark.

Mitigações:

- marcar todo dado sintético como sintético;
- bloquear uso de dados sintéticos em hidden evaluation;
- exigir revisão humana para promover dado de observação a dado de treino.

## Revisão humana

### DECISÃO PROPOSTA

Nenhuma entrada lexical vai a produção sem:

- revisão humana identificada;
- checagem de licença;
- checagem de categoria gramatical;
- checagem de transformação aplicada;
- justificativa para adição.

Alterações também exigem revisão humana para:

- mudança de categoria gramatical;
- alteração de forma normalizada;
- remoção de entrada;
- fusão de entradas;
- alteração de licença/origem registrada.

## Rejeição de dados sem origem

### DECISÃO PROPOSTA

O sistema de importação deve rejeitar automaticamente qualquer registro sem:

- origem;
- licença;
- hash bruto;
- responsável pela revisão;
- classe de dados;
- timestamp de importação.

## Critérios para adicionar, alterar ou remover uma palavra

### Adicionar

- existe fonte identificada;
- a licença é compatível com o uso pretendido;
- a classe gramatical foi revisada;
- há justificativa de produto;
- a entrada não contamina conjuntos de avaliação.

### Alterar

- a mudança é motivada por evidência melhor ou correção de erro;
- a versão anterior permanece auditável;
- há revisão humana;
- os impactos em treino/validação/eval são reavaliados.

### Remover

- a entrada é inválida, duplicada, legalmente problemática ou obsoleta;
- a remoção registra motivo;
- dependências downstream são reavaliadas;
- benchmarks afetados são marcados para rerun.

## Entidades dinâmicas do Home Assistant

### DECISÃO PROPOSTA

Dados vindos do HA devem ser armazenados separadamente do léxico geral:

- origem: inventário HA;
- timestamp de sincronização;
- instância ou ambiente de origem;
- tipo de entidade;
- nome canônico;
- aliases do usuário;
- hash do snapshot de inventário.

Regra:

- entidades do HA não devem ser promovidas automaticamente a dados de treino.

## Observações de STT

### DECISÃO PROPOSTA

Erros observados de STT devem ser mantidos como:

- forma observada;
- forma pretendida confirmada;
- contexto;
- frequência;
- origem da observação;
- grau de confirmação humana.

Regra:

- observação de STT não é sinônimo automático nem regra ortográfica automática.

## Conclusão

- `DECISÃO PROPOSTA`: proveniência é requisito de arquitetura, não tarefa opcional de curadoria.
- `DECISÃO PROPOSTA`: qualquer fase posterior que toque em léxico, corpus, treino ou avaliação deve implementar esta política antes de gerar artefatos executáveis.
