# Modelo conceitual do domínio

## Estatuto e limites

**MODELO APROVADO.** Este modelo define conceitos próprios, necessários aos contratos do produto. Ele não define classes, formatos de serialização, estruturas de memória ou algoritmos.

**MODELO APROVADO.** Interpretação textual, estado de diálogo, estado do Home Assistant, execução de ações e realização de resposta são responsabilidades distintas. O núcleo de interpretação não possui credenciais e não executa serviços.

## Rastreabilidade normativa

Este modelo elabora os conceitos e invariantes dos requisitos numerados abaixo sem criar requisitos autônomos. Em caso de divergência, prevalecem os IDs numerados; falha, aceite e evidência de teste vêm das respectivas tabelas de requisitos e dos IDs `TEST`.

| Seção do modelo | IDs elaborados |
| --- | --- |
| Solicitação, texto e Resultado de Interpretação | `FR-001` a `FR-005`, `FR-009`, `FR-016`, `NFR-001`, `NFR-005`, `NFR-006`, `API-001` a `API-004`, `API-013` |
| Hipótese, intenção, slot e ambiguidade | `FR-006` a `FR-012`, `FR-015`, `FR-016`, `API-002` a `API-005` |
| Snapshot e Referência de Entidade | `FR-013` a `FR-015`, `API-008`, `API-009`, `SEC-006`, `SEC-008`, `DATA-001`, `DATA-013` |
| Sessão e esclarecimento | `FR-017` a `FR-020`, `API-005` a `API-007`, `SEC-010` |
| Proposta, execução e resposta | `FR-021` a `FR-023`, `API-009` a `API-011`, `SEC-001`, `SEC-003` a `SEC-014` |
| Invariantes transversais | `NFR-001`, `NFR-004`, `NFR-006`, `NFR-007`, `NFR-010`, `DATA-001`, `DATA-013` |

## Conceitos

**MODELO APROVADO.** A tabela a seguir estabelece as definições, invariantes e ciclos de vida normativos do modelo.

| Conceito | Definição | Invariantes | Ciclo de vida |
| --- | --- | --- | --- |
| **Solicitação Textual** | Unidade de entrada de um turno, composta de texto original, identidade de processamento e metadados explicitamente fornecidos. | O texto original é imutável; a origem é texto, nunca áudio; idioma e variante são declarados; a identidade não é reutilizada para outra solicitação. | É criada na admissão, validada antes da análise e retida pelo tempo necessário à rastreabilidade e à política de sessão. Termina aceita, rejeitada ou correlacionada a um resultado. |
| **Unidade Textual** | Trecho delimitado da solicitação usado como evidência por análises posteriores. | Pertence a exatamente uma solicitação; seus offsets são válidos na convenção declarada; não contém caracteres inventados; transformações mantêm vínculo com o trecho original. | É criada durante a preparação textual, pode receber anotações imutáveis ou versionadas e deixa de ser necessária quando expira a solicitação ou sua trilha permitida. |
| **Hipótese de Interpretação** | Leitura candidata e autocontida da solicitação, composta de uma ou mais intenções. | Vincula-se a uma solicitação e à versão dos artefatos usados; contém pelo menos uma intenção; não é tratada como fato; mantém evidências e pendências; sua posição entre candidatas obedece a uma política determinística. | Surge como candidata, só é emitida depois de receber ao menos uma intenção, é enriquecida sem perder rastreabilidade e termina pronta, pendente, bloqueada, abstida ou descartada por regra explícita. |
| **Intenção Normalizada** | Representação de um objetivo interpretado segundo um conceito de esquema versionado, independente da forma textual superficial. | Pertence a uma hipótese; referencia um conceito existente no esquema; mantém vínculo com evidência textual; tem situação própria; nunca equivale por si só a autorização ou execução. | É criada incompleta ou candidata, recebe slots e referências e termina pronta, pendente, bloqueada ou descartada. Depois de emitida, não é reescrita por um resultado de execução. |
| **Slot Semântico** | Papel tipado previsto pelo esquema de uma intenção, que pode receber um valor ou registrar por que ele não está resolvido. | Pertence a uma intenção; respeita tipo e cardinalidade do esquema; distingue resolvido, ausente, ambíguo e inaplicável; valor resolvido possui origem rastreável ou origem contextual declarada. | É instanciado com a intenção, pode passar de pendente a resolvido por evidência ou esclarecimento e é congelado quando a hipótese é emitida. |
| **Snapshot de Catálogo** | Visão local e imutável do catálogo dinâmico do Home Assistant, fornecida por contrato para uma execução. | Possui identidade, versão, integridade e proveniência verificáveis; não é artefato linguístico nem autorização; uma interpretação não mistura snapshots. | É publicado pelo provedor, aceito ou rejeitado integralmente, consultado sem mutação e substituído apenas fora de uma interpretação em andamento. |
| **Referência de Entidade** | Vínculo entre uma menção ou valor semântico e um item de um Snapshot de Catálogo. | Mantém separadas a menção textual, a identidade externa e os aliases do usuário; registra o snapshot consultado; não promove entidades dinâmicas a dado linguístico; candidato não é entidade resolvida. | É criada durante a resolução, permanece candidata ou ambígua enquanto houver concorrência e termina resolvida, não encontrada, indisponível ou descartada. |
| **Ambiguidade Declarada** | Registro de duas ou mais alternativas ainda viáveis cuja escolha altera a interpretação ou a segurança do resultado. | Contém alternativas distintas e motivo tipado; nenhuma alternativa é escolhida silenciosamente; ambiguidade relevante impede prontidão; sua ordem é determinística. | É aberta quando a concorrência é detectada, pode gerar pedido de esclarecimento e termina resolvida, expirada, descartada ou convertida em abstinência. |
| **Pedido de Esclarecimento** | Saída estruturada e textual que solicita somente a informação necessária para tratar uma pendência identificada. | Pertence a uma sessão e a uma ou mais pendências; não declara execução; não amplia o domínio da hipótese; sua resposta só pode afetar pendências compatíveis da mesma sessão. | É criado a partir de hipótese pendente, fica ativo até resposta, substituição, cancelamento ou expiração e então é encerrado com resultado auditável. |
| **Contexto de Sessão** | Estado curto do diálogo, contendo somente informações permitidas para relacionar turnos e pendências. | Tem identidade e versão; é isolado entre sessões; distingue dado fornecido, decisão derivada e pendência; não contém credenciais; não é o estado do Home Assistant; uso contextual fica rastreável. | É iniciado por contrato, atualizado por transições válidas, pode ser reduzido ou reiniciado e expira segundo política definida. Dados expirados não voltam a influenciar interpretações. |
| **Resultado de Interpretação** | Envelope terminal e único tipo de saída semântica do núcleo para uma solicitação, contendo zero, uma ou várias hipóteses e uma situação global explícita. | Cardinalidade de hipóteses e situação global são dimensões separadas; coleção vazia não determina abstinência; falha técnica permanece distinta; identifica versões efetivas; não contém Proposta de Execução nem alegação de efeito externo. | É emitido ao concluir ou interromper controladamente a interpretação, permanece imutável e pode ser consumido pelo gestor de diálogo e política e por outros consumidores autorizados. |
| **Proposta de Execução** | Envelope imutável criado pelo gestor de diálogo e política separado a partir de intenções prontas de um Resultado de Interpretação. | Mantém correlação com resultado, hipótese, intenções, sessão, política e snapshot aplicáveis; não é produzida pelo núcleo; não constitui autorização, execução nem evidência de efeito; só o adaptador pode aceitá-la para revalidação. | É criada depois da interpretação, pode ser bloqueada ou descartada antes do envio, permanece imutável ao atravessar a fronteira e termina rejeitada ou correlacionada a um Resultado de Execução. |
| **Resultado de Execução** | Relato tipado recebido do adaptador Home Assistant sobre uma Proposta de Execução revalidada fora do núcleo. | Possui correlação válida com a proposta; distingue sucesso, falha, recusa, indisponibilidade e situação desconhecida; não altera o Resultado de Interpretação nem é produzido pelo núcleo. | Nasce no adaptador separado, é validado na recepção, correlacionado conforme o contrato aplicável e então disponibilizado à realização de resposta. |
| **Resposta Textual** | Texto final destinado ao consumidor, derivado de uma situação tipada de interpretação, diálogo, política ou execução. | Não é áudio; não inventa sucesso nem detalhe ausente; corresponde à situação de origem; sob entradas efetivas iguais, sua realização é determinística; mantém correlação com o turno. | É criada depois que há situação comunicável, entregue ao consumidor e retida ou descartada segundo política de minimização. Não modifica a situação que descreve. |

## Relações e fronteiras

**MODELO APROVADO.** As relações abaixo limitam como os conceitos podem ser associados; elas não determinam sua representação física.

**MODELO APROVADO.** Uma Solicitação Textual origina zero ou mais Unidades Textuais e exatamente um Resultado de Interpretação terminal. O resultado pode carregar zero, uma ou várias Hipóteses de Interpretação independentemente de sua situação global; cada hipótese carrega uma ou várias Intenções Normalizadas.

**MODELO APROVADO.** Uma Intenção Normalizada reúne Slots Semânticos e pode apontar para Referências de Entidade. Alternativas não resolvidas são registradas como Ambiguidade Declarada, nunca como uma referência definitiva.

**MODELO APROVADO.** Um Pedido de Esclarecimento e sua resposta transitam pelo Contexto de Sessão. O contexto pode influenciar nova interpretação somente com rastro explícito e não pode substituir uma consulta autorizada ao estado externo.

**MODELO APROVADO.** O núcleo entrega somente o Resultado de Interpretação e não cria Proposta de Execução. O gestor de diálogo e política separado pode criar uma proposta somente a partir de intenções prontas; o adaptador Home Assistant a revalida e, se houver tentativa, devolve Resultado de Execução por contrato separado. Esse resultado pode alimentar uma Resposta Textual e não reclassifica retroativamente a interpretação como falha linguística.

## Invariantes transversais

**MODELO APROVADO.** As invariantes seguintes valem em todas as fronteiras que transportem os conceitos deste modelo.

**MODELO APROVADO.** Toda informação derivada mantém vínculo com sua solicitação, sua origem textual ou contextual e as versões dos artefatos efetivamente consultados.

**MODELO APROVADO.** Estados `ausente`, `ambíguo`, `não encontrado`, `fora de escopo`, `abstido`, `bloqueado`, `falha técnica` e `falha de execução` não são intercambiáveis.

**MODELO APROVADO.** Uma hipótese só pode ser marcada como pronta quando suas intenções satisfizerem os esquemas aplicáveis e não houver pendência relevante. Prontidão semântica não implica autorização.

**MODELO APROVADO.** Catálogo dinâmico, aliases do usuário, observações operacionais e artefatos linguísticos são classes diferentes. Nenhuma transição de ciclo de vida promove automaticamente conteúdo entre essas classes.

**MODELO APROVADO.** Atualizações de contexto, resolução por catálogo e recepção de resultado externo são transições explícitas. Nenhuma mutação ambiental oculta pode alterar uma interpretação em andamento.

## Decisões ainda necessárias

**DECISÃO PENDENTE — OPEN-002.** Fixar a política de normalização Unicode preservando texto original e rastreabilidade.

**DECISÃO PENDENTE — OPEN-003.** Fixar a unidade, a origem e a convenção de intervalos dos offsets antes da implementação de Unidade Textual.

**DECISÃO PENDENTE — OPEN-007.** Fixar como hipóteses e alternativas serão ordenadas e como eventual medida técnica será representada.

**DECISÃO PENDENTE — OPEN-009.** Fixar identidade, versão e vigência de cada snapshot do catálogo dinâmico.

**DECISÃO PENDENTE — OPEN-010.** Fixar duração, expiração, persistência e limites do Contexto de Sessão.

**DECISÃO PENDENTE — OPEN-013.** Fixar a negociação de versões e capacidades dos conceitos serializados sem alterar suas invariantes.

**DECISÃO PENDENTE — OPEN-015.** Fixar limites quantitativos de entrada, hipóteses, candidatos, intenções e estado de sessão com base em medições e política operacional.
