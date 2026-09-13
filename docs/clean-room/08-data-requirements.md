# Requisitos de dados e proveniência

## Finalidade

Este documento define contratos de admissão, transformação, separação, revisão, versionamento e remoção de dados. Ele não aprova fontes específicas, não seleciona datasets e não contém vocabulário.

As expressões **deve**, **não deve** e **deve rejeitar** são normativas. Uma falha de governança de dados é bloqueante: o fluxo offline não pode converter a entrada rejeitada em artefato consumível pelo runtime.

## Perfis de governança

Esta especificação distingue dois perfis que não podem ser fundidos implicitamente:

- **Perfil L — linguístico/offline e avaliação:** conteúdo candidato a léxico, regra linguística, treino, desenvolvimento, validação, avaliação ou avaliação oculta. `DATA-002` a `DATA-012` e `DATA-014` a `DATA-016` regem sua admissão, transformação, uso e remoção.
- **Perfil O — operacional:** snapshots de entidades dinâmicas do Home Assistant, aliases do usuário e observações operacionais de STT. Esses itens permanecem fora do pipeline linguístico/offline e dos conjuntos de treino e avaliação. Sua governança mínima é definida por `DATA-001` e `DATA-013`.

Um item do Perfil O não se torna evidência linguística por frequência, uso, correção, confirmação operacional ou saída do sistema. Se houver proposta de promovê-lo a dado linguístico, treino, desenvolvimento, validação ou avaliação, a promoção cria uma **nova admissão no Perfil L** e deve satisfazer integralmente `DATA-002` a `DATA-016`, sem herdar aprovação do uso operacional.

## Matriz de aplicabilidade por classe

| Classe | Perfil normal | Fluxo permitido | Requisitos aplicáveis no perfil normal | Comportamento proibido ou de falha |
| --- | --- | --- | --- | --- |
| Léxico linguístico geral | L | admissão e compilação offline aprovadas | `DATA-001` a `DATA-012` e `DATA-014` a `DATA-016` | entrada sem admissão completa ou mistura com outra classe é rejeitada |
| Léxico especializado de automação residencial | L | admissão e compilação offline aprovadas | `DATA-001` a `DATA-012` e `DATA-014` a `DATA-016` | entrada sem admissão completa ou promoção automática de dado operacional é rejeitada |
| Dados de treino | L | pipeline offline de treino aprovado | `DATA-001` a `DATA-012` e `DATA-014` a `DATA-016` | mistura com desenvolvimento, validação ou avaliação bloqueia uso e métricas afetadas |
| Dados de desenvolvimento | L | ajuste e diagnóstico durante desenvolvimento | `DATA-001` a `DATA-012` e `DATA-014` a `DATA-016` | mistura com treino, validação ou avaliação é rejeitada conforme a política de partição |
| Dados de validação | L | seleção e verificação durante desenvolvimento conforme custódia aprovada | `DATA-001` a `DATA-012` e `DATA-014` a `DATA-016` | uso para treino ou sobreposição direta/derivada invalida a avaliação afetada |
| Dados de avaliação | L | avaliação controlada de versão identificada | `DATA-001` a `DATA-012` e `DATA-014` a `DATA-016` | uso para ajuste do sistema avaliado ou sobreposição proibida invalida a métrica |
| Conjunto oculto de avaliação | L | avaliação sob custódia e acesso aprovados | `DATA-001` a `DATA-012` e `DATA-014` a `DATA-016` | acesso pelo fluxo de desenvolvimento, material sintético ou derivado do sistema bloqueia a avaliação |
| Snapshot de entidades dinâmicas do Home Assistant | O | catálogo operacional recebido por contrato, com escopo e vigência próprios | `DATA-001` e `DATA-013` | não entra no compilador linguístico, léxico, treino ou avaliação; promoção exige nova admissão completa no Perfil L |
| Alias definido pelo usuário | O | resolução no escopo autorizado do usuário | `DATA-001` e `DATA-013` | não vira alias global, léxico, regra ou dado de treino; promoção exige nova admissão completa no Perfil L |
| Observação operacional de STT | O | registro operacional no escopo e finalidade autorizados | `DATA-001` e `DATA-013` | não é verdade lexical, correção ou dado de treino; promoção exige nova admissão completa no Perfil L |

## Classes de fontes admissíveis

### Perfil L

Sem aprovar uma fonte específica, somente podem ser submetidos à admissão linguística/offline:

- artefatos publicados por origem oficial e acompanhados de licença verificável;
- dados próprios ou encomendados cuja titularidade, URL de origem e autorização de uso estejam documentadas;
- conteúdo operacional proposto para promoção, tratado como nova fonte candidata e sem aproveitar a autorização do Perfil O.

Pertencer a uma dessas classes não basta para admissão. Toda fonte ou conteúdo do Perfil L deve satisfazer `DATA-002` a `DATA-016`; origem, URL, versão, licença, hash bruto, método de extração, transformações, justificativa, partição ou revisão inconclusiva implica rejeição.

### Perfil O

Podem existir, sem admissão no pipeline linguístico:

- snapshots do Home Assistant recebidos pelo contrato de catálogo dinâmico;
- aliases fornecidos pelo usuário para seu escopo autorizado;
- observações operacionais de STT cuja coleta e finalidade estejam autorizadas.

Esses itens devem cumprir `DATA-013`. URL pública, licença de dataset e partição de treino/avaliação não devem ser inventadas quando não forem aplicáveis ao uso operacional. A ausência justificada desses campos não autoriza promoção ao Perfil L.

## Requisitos normativos

A aplicabilidade desta tabela é normativa: `DATA-002` a `DATA-012` e `DATA-014` a `DATA-016` referem-se somente ao Perfil L. Nesses requisitos, “fonte”, “snapshot”, “registro”, “dataset” ou “artefato” não inclui automaticamente um item operacional do Perfil O. `DATA-013` rege o Perfil O e a fronteira de promoção; `DATA-001` rege ambos os perfis.

| ID | Requisito | Falha ou rejeição | Critério de aceite |
| --- | --- | --- | --- |
| DATA-001 | Cada registro e artefato **deve** pertencer a uma única classe de dados declarada. As classes devem permanecer separadas física e logicamente, inclusive em armazenamento, manifestos, permissões e tarefas de processamento. | Registro sem classe, com múltiplas classes incompatíveis ou armazenado em área de outra classe deve ser rejeitado. Nenhum fluxo pode fundir classes implicitamente. | Uma inspeção do layout, dos manifestos e das permissões identifica inequivocamente a classe de cada item; testes negativos comprovam que um item não atravessa classes sem uma transformação explícita, revisada e registrada. |
| DATA-002 | Toda fonte ou conteúdo candidato ao Perfil L **deve** registrar, no mínimo: identificador estável, URL de origem, versão ou data de snapshot, licença, algoritmo e valor do hash do artefato bruto, método de obtenção e extração, transformações ordenadas e reproduzíveis, justificativa de inclusão, classe, partição pretendida, estado de revisão humana e responsável pela revisão. | A ausência, invalidade ou inconsistência de qualquer metadado obrigatório deve bloquear a admissão no pipeline linguístico/offline e na avaliação. Campo vazio ou valor genérico que não permita verificação deve ser tratado como ausente. | O validador aceita um registro estrutural completo do Perfil L e rejeita, individualmente, a omissão ou invalidação de cada campo obrigatório. A URL, a versão, a licença e o hash permanecem recuperáveis pelo identificador estável. |
| DATA-003 | Cada fonte, snapshot, transformação e artefato compilado **deve** participar de um manifesto de proveniência versionado. O manifesto deve ligar entradas brutas, etapas executadas, ferramentas e versões utilizadas, saídas, hashes e revisões. | Saída sem cadeia completa até a fonte bruta, manifesto divergente do conteúdo ou etapa não registrada deve ser rejeitada e não pode ser publicada. | Partindo de qualquer artefato publicado, uma verificação automática percorre o manifesto até todas as entradas brutas, confere os hashes e identifica cada transformação e revisão aplicável. |
| DATA-004 | A admissão **deve** exigir licença identificada e compatível com o uso pretendido, além de revisão humana identificada da origem, classificação, transformações e justificativa. Dúvida jurídica ou técnica deve permanecer como bloqueio explícito. | Fonte com licença ausente, ambígua, incompatível ou sem revisão humana aprovada deve ser rejeitada. Aprovação automática ou atribuída a agente não humano não satisfaz o requisito. | Testes de admissão rejeitam todos os estados não aprovados. Para cada fonte admitida, o manifesto permite identificar licença, escopo de uso, decisão de revisão, responsável e data. |
| DATA-005 | O pipeline **deve** verificar a integridade do artefato bruto antes de qualquer transformação e manter uma cadeia de hashes para cada saída intermediária e compilada. O algoritmo de hash deve ser registrado. | Divergência de hash, algoritmo não declarado ou saída sem vínculo criptográfico com suas entradas deve interromper a etapa e invalidar seus derivados. | Alterar qualquer entrada ou saída de uma fixture estrutural faz a verificação falhar; entradas inalteradas confirmam toda a cadeia registrada no manifesto. |
| DATA-006 | Obtenção, extração, filtragem, conversão, normalização, deduplicação, particionamento e compilação **devem** ser executáveis por um pipeline offline, declarativo e reproduzível, com versões e parâmetros registrados. | Passo manual não registrado, dependência mutável não fixada ou transformação impossível de repetir deve bloquear a publicação do artefato. | Duas execuções isoladas com as mesmas entradas, versões, parâmetros e ambiente declarado produzem manifestos semanticamente idênticos e saídas com os mesmos hashes, excetuando apenas metadados voláteis explicitamente excluídos do hash. |
| DATA-007 | A forma original **deve** ser armazenada separadamente de qualquer forma normalizada. Cada normalização deve indicar política e versão, sequência de transformações e vínculo rastreável com o original; a política não pode substituir ou apagar a origem. | Normalização destrutiva sem preservação do original, transformação não registrada ou mistura entre forma original e derivada deve ser rejeitada. | Para toda fixture técnica de estrutura, é possível recuperar o valor original, identificar a política aplicada e verificar o vínculo com cada forma derivada sem depender de conhecimento lexical. |
| DATA-008 | A deduplicação **deve** usar regra documentada e específica para a classe de dados. A fusão deve preservar todas as fontes, licenças, hashes, revisões e relações com os registros anteriores; classes distintas não podem ser deduplicadas entre si implicitamente. | Duplicata resolvida por descarte silencioso, perda de proveniência ou fusão entre classes deve invalidar a saída. | Fixtures estruturais duplicadas geram o resultado previsto pela regra declarada, mantendo todas as proveniências; uma tentativa de fusão entre classes é rejeitada. |
| DATA-009 | Conflitos entre fontes ou revisões **devem** permanecer explícitos até resolução humana documentada. O registro deve preservar alternativas, proveniência, natureza do conflito, decisão, justificativa e responsável; nenhuma precedência tácita é permitida. | Seleção silenciosa da alternativa mais recente, mais frequente ou mais conveniente deve ser rejeitada. Conflito não resolvido não pode alimentar artefato de produção quando afetar seu significado. | Um conflito estrutural introduzido em teste aparece no relatório de validação e bloqueia a publicação; após decisão humana registrada, o histórico completo continua auditável. |
| DATA-010 | Treino, desenvolvimento, validação, avaliação e avaliação oculta **devem** ter manifestos, armazenamento e controles de acesso separados. A regra de atribuição de partição deve ser registrada e reproduzível. | Item sem partição, presente em mais de uma partição incompatível ou movido sem novo registro de decisão deve ser rejeitado. | A auditoria de partições confirma pertencimento único, reproduz a atribuição a partir dos parâmetros registrados e detecta qualquer sobreposição deliberadamente inserida em fixture estrutural. |
| DATA-011 | O controle de contaminação **deve** considerar a ocorrência bruta e seus derivados, agrupamentos ou variantes produzidos pela mesma origem. Conteúdo reservado para avaliação não pode ser usado para ajustar regras, artefatos ou parâmetros avaliados por esse conteúdo. | Sobreposição direta ou derivada entre treino e avaliação, acesso indevido ao conjunto oculto ou reutilização de benchmark para ajuste deve bloquear a avaliação e invalidar a métrica afetada. | Uma verificação automatizada de linhagem e partições detecta relações proibidas; o relatório identifica origem, derivados e avaliações que precisam ser invalidadas ou refeitas. |
| DATA-012 | Saídas, hipóteses, correções ou exemplos produzidos pelo próprio sistema **não devem** ser tratados como evidência linguística independente. Material sintético, quando autorizado para testes estruturais, deve ser rotulado como sintético e não pode entrar na avaliação oculta. | Derivado do sistema sem rótulo, promovido automaticamente a treino ou usado como evidência independente deve ser rejeitado. | A validação de linhagem bloqueia material cuja única origem seja o próprio sistema e confirma que todo item sintético autorizado possui rótulo e partição compatíveis. |
| DATA-013 | Snapshots de entidades dinâmicas do Home Assistant, aliases do usuário e observações operacionais de STT **devem** permanecer no Perfil O e separados do pipeline linguístico, do léxico e de todos os conjuntos de treino e avaliação. Cada item deve registrar, conforme sua classe: origem e instância ou responsável; escopo; timestamp ou identidade do snapshot; integridade quando serializado; e consentimento ou base de autorização aplicável. Campos linguísticos como URL pública, licença de dataset e partição não devem ser fabricados quando não se aplicarem. Qualquer promoção cria nova admissão no Perfil L e deve cumprir integralmente `DATA-002` a `DATA-016`. | Mistura, promoção automática, perda de escopo/autorização, ausência de metadado operacional aplicável ou uso de observação de STT como verdade lexical deve ser rejeitado. A falta legítima de metadado exclusivo do Perfil L não pode ser preenchida com valor fictício. | Testes confirmam armazenamento e manifestos operacionais separados, presença dos metadados aplicáveis por classe, ausência de campos inventados e impossibilidade de alcançar compilação, treino ou avaliação sem nova admissão completa conforme `DATA-002` a `DATA-016`. |
| DATA-014 | Toda inclusão, alteração, fusão, reclassificação e remoção de dado de produção **deve** passar por revisão humana identificada. O histórico anterior deve permanecer auditável e os impactos nas partições e artefatos derivados devem ser avaliados. | Mudança sem responsável, justificativa, data ou avaliação de impacto deve ser rejeitada. A revisão não pode apagar a versão anterior. | O histórico de uma alteração estrutural mostra estado anterior, proposta, decisão humana e artefatos ou avaliações afetados; tentativas sem qualquer elemento obrigatório falham. |
| DATA-015 | O sistema de proveniência **deve** permitir localizar e remover uma fonte e todos os seus derivados. A remoção deve gerar registro de motivo, invalidar artefatos afetados e permitir reconstrução sem a fonte. Artefatos e manifestos devem ter versão de schema, versão de conteúdo e compatibilidade declaradas. | Derivado órfão, artefato ainda marcado como válido após remoção ou versão incompatível aceita silenciosamente deve bloquear distribuição e carga. | Uma remoção simulada identifica todos os derivados, invalida as versões afetadas e produz rebuild sem referências à fonte; teste de compatibilidade rejeita versão não suportada. |
| DATA-016 | É proibido admitir vocabulário, regra linguística, corpus ou lista de produção sem origem verificável, licença, hash, método de extração e revisão humana. Memória de modelo, sugestão de LLM e saída anterior do sistema não constituem fonte. | Qualquer item sem proveniência completa ou apresentado apenas como geração automática deve ser rejeitado antes de armazenamento de produção ou compilação. | Testes negativos para cada forma de origem proibida falham de modo explícito; a inspeção do release comprova que todo item publicado possui cadeia de proveniência válida e revisão humana. |

## Invariantes do fluxo de dados

- O runtime consome somente artefatos publicados e imutáveis; ele não importa fontes nem altera dados linguísticos.
- O catálogo dinâmico e o contexto do usuário não alteram artefatos linguísticos globais.
- Uma transformação nunca converte ausência de evidência em decisão linguística.
- Aprovação de uma fonte não aprova automaticamente versões futuras dessa fonte.
- Métricas só são publicáveis junto ao manifesto do conjunto e à versão exata do sistema avaliado.

## Decisões deliberadamente não tomadas

| Tema ainda não decidido | Registro obrigatório |
| --- | --- |
| política linguística de normalização e tratamento do original/derivado | `OPEN-002` |
| seleção de fontes linguísticas, compatibilidade de licença e nível de revisão | `OPEN-016` |
| regra de particionamento, custódia e acesso à avaliação oculta | `OPEN-017` |
| regra ou algoritmo de deduplicação específico para cada classe | `OPEN-025` |
| metas quantitativas de qualidade e cobertura, somente após baseline aprovado | `OPEN-026` |

Nenhum desses temas possui padrão implícito neste documento. Se surgir outra escolha necessária, ela deve receber ID `OPEN` e decisão humana antes da implementação afetada.
