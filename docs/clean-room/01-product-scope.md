# Escopo do produto — primeira versão

Data: 2026-08-12

Status: escopo clean-room aprovado, condicionado às decisões abertas indicadas neste documento

## Objetivo da primeira versão

### ESCOPO APROVADO

A primeira versão deve interpretar solicitações textuais em PT-BR de modo determinístico e auditável, representar zero, uma ou várias hipóteses, resolver referências do domínio Home Assistant por meio de snapshots locais e encerrar o núcleo com um Resultado de Interpretação tipado. Em componente separado, o gestor de diálogo e a política consomem esse resultado, conduzem esclarecimento por sessão explícita e, quando houver base aprovada, constroem uma Proposta de Execução sem efeito próprio. O adaptador Home Assistant revalida a Proposta de Execução, solicita o efeito quando autorizado, devolve o Resultado de Execução por contrato distinto e permite produzir uma resposta textual coerente com o estado efetivamente observado.

O núcleo de interpretação permanece sem credenciais e sem capacidade de executar ações externas. A primeira versão prioriza comportamento reproduzível, abstinência explícita, separação de responsabilidades, segurança por validação independente e proveniência integral dos artefatos linguísticos.

O objetivo não autoriza a criação de vocabulário, corpus, regras linguísticas, limiares, plataformas suportadas ou políticas operacionais que não estejam aprovados no pacote.

## Atores e consumidores

| Ator ou consumidor | Relação com a primeira versão | Limite aprovado |
| --- | --- | --- |
| Cliente textual | Envia uma solicitação textual, origem declarada e contexto permitido; recebe um resultado correlacionado. | Não entrega áudio, credenciais nem autoridade implícita para produzir efeitos. |
| Operador da sessão | Inicia, continua, consulta ou encerra contexto de diálogo por contrato. | Uma sessão não representa o estado corrente do ambiente externo. |
| Provedor de catálogo | Publica snapshots imutáveis das entidades dinâmicas do Home Assistant e seus metadados. | O catálogo descreve candidatos e capacidades; não concede autorização e não se torna léxico geral. |
| Núcleo de interpretação | Processa texto e contexto permitido, preserva alternativas e encerra cada solicitação com um Resultado de Interpretação. | Não constrói Proposta de Execução, não consulta serviços externos autenticados, não possui credenciais e não executa ações. |
| Gestor de diálogo e política | Consome o Resultado de Interpretação, mantém pendências e transições explícitas da sessão, produz esclarecimento e, quando permitido, constrói a Proposta de Execução. | Permanece separado do núcleo e do adaptador; prontidão semântica não equivale a autorização nem produz efeito. |
| Adaptador Home Assistant | Recebe a Proposta de Execução, revalida catálogo, estrutura, política e autorização correntes e solicita o efeito quando permitido. | Não confia na validação a montante; somente o adaptador mantém credenciais e pode solicitar o efeito externo. |
| Consumidor de resposta | Recebe texto final e a classe de resultado correlacionada. | A primeira versão não produz áudio nem transforma resultado inconclusivo em sucesso. |
| Compilação offline e governança de dados | Transformam somente fontes aprovadas em artefatos locais, versionados e verificáveis. | Não participam do caminho online nem admitem fonte sem origem, licença, hash, método e revisão exigidos. |
| Operação e auditoria do produto | Verificam integridade, versões, decisões, fallbacks, segurança e métricas. | Observabilidade deve minimizar dados sensíveis e não pode alterar o resultado semântico. |

## Casos incluídos

### ESCOPO APROVADO

- receber texto digitado ou texto declarado como transcrição, preservando a origem como metadado quando informada;
- preservar o texto original e produzir representação de trabalho rastreável;
- segmentar e analisar o texto por estágios determinísticos com artefatos locais e versionados;
- representar análises alternativas e resultados com zero, uma ou várias hipóteses;
- representar intenções, slots, evidências, pendências, conflitos e relações entre múltiplas intenções;
- resolver menções contra um snapshot local e imutável do catálogo dinâmico do Home Assistant, mantendo candidatos, ausência e ambiguidade distintos;
- manter aliases fornecidos pelo usuário separados do léxico geral, do léxico de domínio e do catálogo dinâmico;
- usar contexto de sessão explícito para continuidade, correferência e esclarecimento delimitado;
- distinguir solicitação malformada, fora de escopo, insuficiente e ambígua;
- emitir pelo núcleo um Resultado de Interpretação tipado, sem proposta nem efeito externo;
- construir no gestor de diálogo e política, a partir desse resultado, uma Proposta de Execução tipada e sem efeito próprio;
- revalidar a Proposta de Execução no adaptador Home Assistant antes de qualquer solicitação de efeito;
- receber e correlacionar resultado de execução sem reescrever a interpretação original;
- produzir resposta textual determinística para interpretação, esclarecimento, abstinência, bloqueio, falha e resultado de execução;
- emitir trilha de decisão, versão, fallback e erro suficiente para testes e auditoria, com minimização de dados;
- compilar offline apenas dados linguísticos aprovados e carregar no runtime apenas artefatos íntegros e compatíveis.

## Fora de escopo

### ESCOPO APROVADO

- capturar áudio ou executar reconhecimento de fala;
- sintetizar voz ou entregar áudio;
- permitir ao núcleo construir Proposta de Execução, armazenar credenciais, autorizar ou executar diretamente uma ação externa;
- consultar ou executar serviços do Home Assistant diretamente a partir do núcleo de interpretação;
- tratar estado de sessão como estado autoritativo do ambiente externo;
- incorporar automaticamente nomes do catálogo dinâmico, aliases do usuário ou observações de erro ao léxico geral;
- inventar ou completar dados linguísticos, conjuntos de treino, validação ou avaliação;
- treinar em dados reservados para validação ou avaliação, ou usar esses resultados como evidência independente;
- definir nesta etapa interface gráfica, dispositivo cliente ou experiência por voz;
- fixar transporte, serialização, plataformas, limites quantitativos ou metas de desempenho antes das decisões correspondentes;
- executar operação fora dos esquemas, capacidades e políticas explicitamente aprovados.

Um item fora de escopo não deve receber uma hipótese genérica, fallback executável ou promessa implícita de suporte.

## Fronteiras obrigatórias

### Texto versus reconhecimento de fala

**FRONTEIRA APROVADA.** A entrada do produto é texto. Ela pode declarar que o texto veio de uma transcrição, mas a captura de áudio e a conversão de áudio em texto pertencem a outro sistema. Origem ausente não pode ser inferida a partir do conteúdo.

### Interpretação versus execução

**FRONTEIRA APROVADA.** O núcleo de interpretação termina exclusivamente em um Resultado de Interpretação, que pode transportar hipóteses, pendências, abstinência ou erro tipado e nunca contém uma Proposta de Execução. O gestor de diálogo e a política, em componente separado, consomem esse resultado e podem construir uma Proposta de Execução sem efeito próprio. O adaptador Home Assistant recebe a Proposta de Execução e revalida estrutura, domínio, serviço, entidade, parâmetros, política, confirmação e autorização antes de solicitar qualquer efeito. O Resultado de Execução é uma observação posterior e não altera retroativamente o Resultado de Interpretação.

### Núcleo linguístico versus domínio Home Assistant

**FRONTEIRA APROVADA.** Normalização, unidades textuais, análises linguísticas, segmentação, representação semântica, coordenação de hipóteses e emissão do Resultado de Interpretação pertencem ao núcleo. Sessão, diálogo e preparação da Proposta de Execução sob política pertencem a um componente de orquestração separado. Esquemas do domínio Home Assistant, catálogo dinâmico, capacidades, revalidação de política e tradução para serviços pertencem à camada de domínio ou ao adaptador. O núcleo não embute conectividade, proposta executável nem autoridade do domínio.

### Entidades linguísticas versus entidades dinâmicas do Home Assistant

**FRONTEIRA APROVADA.** Uma menção e sua análise linguística são evidência derivada do texto. Uma entidade dinâmica é um item identificado em snapshot fornecido por contrato. A ligação entre ambas é uma resolução rastreável, não fusão de dados. Mudança de catálogo ou alias pode mudar a resolução, mas não pode reescrever o texto, a menção nem os artefatos linguísticos.

### Sessão versus estado do Home Assistant

**FRONTEIRA APROVADA.** A sessão contém somente contexto de diálogo permitido, referências, pendências e transições versionadas. O estado do Home Assistant pertence ao sistema executor e só pode chegar por snapshot ou resultado contratual identificado. Uma lembrança de sessão não comprova que um recurso ainda existe, mantém estado anterior ou continua autorizado.

### Resposta textual versus síntese de voz

**FRONTEIRA APROVADA.** A saída de apresentação desta versão é texto e metadados correlacionados. Produção de áudio pertence a consumidor externo. Nenhuma falha de síntese externa pode ser reclassificada como erro de interpretação.

### Falha ou insuficiência de interpretação versus falha de execução

**FRONTEIRA APROVADA.** Falha de interpretação pertence à produção do Resultado de Interpretação e descreve falha técnica no processamento textual, em artefatos ou no contexto permitido. Interpretação insuficiente é uma situação de domínio distinta, representada como pendência ou abstinência por insuficiência, e não como erro de contrato ou falha técnica. Falha de preparação ou validação da Proposta de Execução pertence ao diálogo, à política ou ao adaptador conforme a fronteira que a detectou. Falha de execução ocorre depois da proposta validada e descreve autorização, indisponibilidade do Home Assistant ou outro resultado externo. As categorias, correlações e trilhas permanecem separadas; uma não mascara a outra.

### Ambiguidade versus fora de escopo

**FRONTEIRA APROVADA.** Ambiguidade significa que existem múltiplas leituras ou referências ainda viáveis dentro do escopo aprovado; pode produzir candidatos ou esclarecimento delimitado. Fora de escopo significa que nenhuma interpretação suportada é aplicável; produz abstinência explícita. Ordenação, histórico ou proximidade não convertem nenhum dos casos em escolha executável silenciosa.

## Pressupostos aprovados

### PRESSUPOSTOS APROVADOS

- a primeira versão tem PT-BR como idioma-alvo;
- o comportamento semântico é determinístico para entradas efetivas, artefatos, versões e estado idênticos;
- o runtime do núcleo opera offline com artefatos locais verificados antes de aceitar solicitações;
- compilação de dados e execução do runtime são processos distintos;
- interpretação, diálogo e política, execução externa e apresentação mantêm contratos separados na sequência Resultado de Interpretação → Proposta de Execução → Resultado de Execução;
- ausência de interpretação e abstinência são resultados válidos e observáveis;
- hipóteses e candidatos permanecem plurais enquanto não houver base aprovada para resolver a pluralidade;
- o catálogo dinâmico do Home Assistant é recebido como snapshot identificado e não como consulta direta do núcleo ao ambiente externo;
- toda influência entre turnos passa por contexto de sessão explícito e isolado;
- credenciais ficam exclusivamente no adaptador de execução;
- autorização e confirmação são avaliadas separadamente do determinismo da interpretação;
- dados linguísticos exigem proveniência, versão, licença, hash, método de extração e revisão humana aplicável;
- treino, validação e avaliação reservada permanecem física e logicamente separados;
- comportamento novo exige requisito, critério de aceite e decisão rastreáveis antes da implementação.

## Questões pendentes e bloqueios

### Bloqueios globais imediatos

As três decisões abaixo impedem o início da fundação de implementação. Não devem ser supridas por suposição:

| ID | DECISÃO PENDENTE | Impacto bloqueado |
| --- | --- | --- |
| OPEN-002 | Definir a política Unicode, inclusive tratamento de caixa, diacríticos e transformações permitidas. | Representação de trabalho, rastreabilidade, testes textuais e contratos entre estágios. |
| OPEN-003 | Definir unidade, origem, convenção de intervalos e mapeamento entre texto original e transformado para offsets. | Modelo de unidades textuais, evidências, spans e critérios de aceite compartilhados. |
| OPEN-014 | Definir quais sistemas operacionais e arquiteturas serão oficialmente suportados na primeira versão. | Toolchain, integração contínua, empacotamento e promessa de portabilidade; nenhuma plataforma pode ser presumida. |

### Portas por camada

As decisões seguintes bloqueiam a implementação ou o aceite da camada indicada, ainda que trabalho independente em outra camada venha a ser autorizado:

| Camada | ID | DECISÃO PENDENTE | Bloqueia |
| --- | --- | --- | --- |
| escopo semântico | OPEN-001 | Fixar o catálogo mínimo de intenções, slots e casos de uso da primeira versão. | Schemas do domínio, cobertura funcional e casos positivos de aceite. |
| representação linguística | OPEN-004 | Escolher representação linguística e conjunto de categorias. | Contratos de análise, artefatos e anotação de referência. |
| análise contextual | OPEN-005 | Definir estratégia de contexto e desempate. | Resolução entre análises concorrentes e testes de decisão. |
| correção contextual | OPEN-006 | Decidir se a correção integra a primeira versão e, se integrar, sua política. | Contrato do estágio, dados de validação e fallbacks correspondentes. |
| hipóteses | OPEN-007 | Definir medida técnica, ordenação e regra de empate sem tratá-las como probabilidade não demonstrada. | Ordenação reproduzível, exposição de candidatos e critérios de abstinência. |
| múltiplas intenções | OPEN-008 | Definir conflitos, dependências e política de execução parcial. | Composição de Propostas de Execução, bloqueios por item e semântica do resultado parcial. |
| entidades dinâmicas | OPEN-009 | Definir identidade de entidades, precedência de aliases, conflitos e validade do snapshot. | Resolução, atualização de catálogo e revalidação pelo adaptador. |
| sessão | OPEN-010 | Definir identidade, duração, armazenamento, expiração e reinicialização de sessão. | Persistência, concorrência, continuidade e descarte do contexto. |
| segurança | OPEN-011 | Classificar operações sensíveis e definir autoridade e prova de confirmação. | Política de autorização e execução de operações sensíveis. |
| contratos externos | OPEN-012 | Definir transporte, serialização, sincronismo e isolamento entre processos. | Implementação física das APIs e isolamento operacional. |
| compatibilidade | OPEN-013 | Definir versões, compatibilidade e negociação de capacidades. | Evolução dos contratos, artefatos e clientes. |
| capacidade operacional | OPEN-015 | Definir limites quantitativos com base em medições e política aprovada. | Proteção de recursos, testes de sobrecarga e comportamento nos limites. |
| dados linguísticos | OPEN-016 | Aprovar fontes, licenças, método de extração e revisão. | Importação, compilação e distribuição de cada conjunto linguístico. |
| avaliação | OPEN-017 | Definir particionamento e custódia da avaliação reservada. | Construção dos conjuntos, acesso, prevenção de vazamento e validade das métricas. |
| desempenho | OPEN-018 | Fixar metas somente depois de uma linha de base reproduzível. | Critérios quantitativos de latência, vazão, memória e tamanho. |
| observabilidade | OPEN-019 | Definir retenção, armazenamento e acesso aos logs. | Implantação do sink, governança de dados e operação auditável. |
| respostas | OPEN-020 | Definir templates, governança e localização das respostas textuais. | Conteúdo final, cobertura de situações e processo de mudança. |
| identidade e acesso | OPEN-021 | Definir identidade, autenticação e autorização dos clientes e processos. | Confiança entre processos, admissão de clientes e atribuição de permissões. |
| credenciais | OPEN-022 | Definir armazenamento, provisão, rotação e revogação de credenciais. | Operação segura do adaptador e ciclo de vida dos segredos. |
| confiabilidade de efeitos | OPEN-023 | Definir idempotência, repetição, reconciliação, compensação e transações. | Retomada após incerteza, prevenção de duplicação e semântica de operações compostas. |
| erros externos | OPEN-024 | Definir taxonomia de erros, correlação e divulgação segura de diagnósticos. | Contratos de falha, observabilidade e informação exposta ao cliente. |
| deduplicação de dados | OPEN-025 | Definir equivalência, agrupamento, conflito e preservação de proveniência por classe de dados. | Deduplicação, fusão e agrupamento no pipeline offline e no armazenamento operacional. |
| qualidade e cobertura | OPEN-026 | Fixar metas quantitativas somente depois de escopo, conjuntos e baseline próprios aprovados. | Portas quantitativas de liberação por capacidade e classe de falha. |

### Regra de parada

**REGRA DE PARADA.** Uma decisão `OPEN` não pode ser resolvida pela implementação. Ao alcançar uma porta pendente, a equipe deve registrar a lacuna, interromper a camada afetada e obter decisão explícita. A decisão aprovada deve atualizar este pacote, seus critérios de aceite e o manifesto antes da retomada.
