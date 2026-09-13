# Contratos do fluxo de processamento

## Estatuto

**CONTRATO APROVADO.** Este documento especifica estágios abstratos por entradas, saídas e invariantes observáveis. A decomposição não prescreve quantidade de módulos, estrutura de código ou algoritmo.

**CONTRATO APROVADO.** O fluxo de runtime recebe texto e artefatos locais já aprovados. Ele não captura áudio, não sintetiza voz, não possui credenciais e não executa serviços do Home Assistant.

## Rastreabilidade normativa

Este documento elabora fronteiras e invariantes dos requisitos numerados abaixo sem criar requisitos autônomos. Em caso de divergência, prevalecem os IDs numerados; falha, aceite e evidência de teste vêm das respectivas tabelas de requisitos e dos IDs `TEST`.

| Seção do fluxo | IDs elaborados |
| --- | --- |
| Entradas efetivas e determinismo | `FR-001`, `FR-002`, `NFR-001` a `NFR-003`, `API-001`, `API-012`, `API-013` |
| Estágios abstratos do runtime | `FR-001` a `FR-020`, `FR-024`, `NFR-001`, `NFR-005`, `NFR-006`, `NFR-012`, `API-001` a `API-008`, `API-012`, `API-013`, `DATA-013` |
| Fluxos posteriores e separados | `FR-021` a `FR-023`, `API-009` a `API-011`, `SEC-001` a `SEC-014` |
| Estado, idioma e processamento offline | `FR-017` a `FR-020`, `FR-024` a `FR-026`, `NFR-003`, `NFR-006`, `NFR-008`, `NFR-010`, `NFR-012`, `DATA-001` a `DATA-016` |
| Propagação e classificação de erros | `FR-016`, `FR-022`, `FR-023`, `API-002`, `API-005`, `API-010`, `API-011`, `API-013`, `SEC-012`, `SEC-013` |

## Entradas efetivas e determinismo

**CONTRATO APROVADO.** As entradas efetivas de uma execução compreendem, conforme o estágio: solicitação textual; idioma e variante; configuração; versões e conteúdo verificado dos artefatos somente leitura; esquema semântico; snapshot identificado do catálogo dinâmico; contexto de sessão explicitamente fornecido; e capacidades negociadas.

**CONTRATO APROVADO.** Para entradas efetivas iguais, o runtime deve produzir saídas semanticamente iguais, inclusive cardinalidade e ordem de hipóteses, situações, erros, pendências e resposta textual. Relógio, ordem de iteração, concorrência, endereço de memória, localidade do processo e disponibilidade de rede não podem decidir o conteúdo sem aparecer como entrada contratual.

**CONTRATO APROVADO.** Identificadores de correlação e metadados operacionais podem variar quando declarados não semânticos. Essa variação não pode alterar interpretação, resolução, abstinência ou decisão de esclarecimento.

## Estágios abstratos do runtime

**CONTRATO APROVADO.** Os estágios abaixo formam fronteiras lógicas verificáveis e podem ser agrupados ou separados fisicamente desde que seus contratos permaneçam observáveis.

| Estágio | Entrada contratual | Saída contratual | Invariantes e abstinência |
| --- | --- | --- | --- |
| **1. Admissão textual** | Solicitação textual e capacidades declaradas pelo consumidor. | Solicitação aceita e identificada, ou erro de contrato. | Preserva o texto original; aceita somente modalidade textual; rejeita forma, tamanho ou versão fora do contrato; não tenta corrigir payload malformado. |
| **2. Preparação rastreável** | Solicitação aceita e política textual da variante selecionada. | Representação de trabalho e mapa para o texto original, ou erro textual tipado. | Nenhum caractere válido é descartado silenciosamente; toda transformação é rastreável; a entrada original permanece imutável. |
| **3. Delimitação textual** | Representação rastreável e recursos da variante linguística. | Unidades textuais ordenadas com offsets, ou trecho explicitamente não resolvido. | Limites pertencem à solicitação; unidades não inventam conteúdo; incerteza de delimitação pode conservar alternativas ou causar abstinência localizada. |
| **4. Formação de candidatas** | Unidades textuais, artefatos linguísticos compatíveis e configuração selecionada. | Zero, uma ou várias leituras candidatas com evidências e pendências. | Uma candidata não é decisão final; alternativas viáveis podem coexistir; ausência de leitura é resultado válido e distinto de falha técnica. |
| **5. Composição semântica** | Leituras candidatas e esquemas semânticos versionados. | Zero, uma ou várias hipóteses; cada hipótese contém uma ou mais intenções e seus slots. | Toda hipótese emitida contém pelo menos uma intenção; toda intenção pertence ao esquema efetivo; slots incompletos permanecem tipados; múltiplas intenções não são achatadas; dados ausentes não são inventados. |
| **6. Resolução dinâmica** | Hipóteses semânticas e snapshot identificado do catálogo do Home Assistant fornecido. | Referências resolvidas, não encontradas ou ambíguas, sempre ligadas ao snapshot. | O catálogo não vira artefato linguístico; aliases permanecem separados; colisão não é resolvida silenciosamente; falta de catálogo não é entrada fora do escopo. |
| **7. Consolidação de hipóteses** | Hipóteses enriquecidas, pendências, restrições e política de ordenação. | Coleção determinística de hipóteses prontas, pendentes, bloqueadas, abstidas ou descartadas. | Preserva rastros e múltiplas candidatas quando necessário; empate declarado não vira escolha implícita; prontidão não equivale a autorização. |
| **8. Emissão da interpretação** | Situação consolidada, contexto explicitamente fornecido ao núcleo, versões efetivas e capacidades negociadas. | Resultado de Interpretação terminal com zero, uma ou várias hipóteses e situação global separada; uma falha técnica controladamente representável é uma situação global tipada desse mesmo resultado. | É o único tipo de saída semântica do núcleo; cardinalidade não determina a situação global e coleção vazia não implica automaticamente abstinência; falha técnica permanece separada das situações de domínio; não contém atualização autoritativa de sessão, Proposta de Execução, alegação de execução nem efeito externo. Falha anterior à admissão no núcleo ou impossibilidade de produzir o envelope é erro da fronteira externa. |

## Fluxos posteriores e separados

**CONTRATO APROVADO.** Os fluxos seguintes não fazem parte do núcleo de interpretação e se comunicam com ele somente por contratos explícitos.

| Fluxo | Entrada contratual | Saída contratual | Limite obrigatório |
| --- | --- | --- | --- |
| **Gestão de diálogo e esclarecimento** | Resultado de Interpretação imutável e Contexto de Sessão explícito, quando fornecido. | Contexto atualizado permitido, pedido de esclarecimento ou situação terminal de diálogo. | Ocorre fora do núcleo; estado só muda por transição válida; sessões são isoladas; contexto expirado não influencia o turno; estado do Home Assistant não é tratado como estado de diálogo. |
| **Preparação de proposta** | Resultado de Interpretação imutável, contexto de diálogo permitido e política aplicável. | Proposta de Execução correlacionada, ou situação pendente, bloqueada ou abstida sem proposta. | Ocorre no gestor de diálogo e política separado, nunca no núcleo; somente intenções prontas podem originar proposta; a proposta não autoriza nem produz efeito e não contém credenciais. |
| **Validação e execução no Home Assistant** | Proposta de Execução imutável e contexto corrente necessário à revalidação. | Resultado de Execução tipado e correlacionado, ou rejeição tipada sem efeito. | O adaptador Home Assistant revalida independentemente estrutura, domínio, serviço, entidade, parâmetros, política e confirmação aplicável; somente ele possui credenciais e pode solicitar efeito externo. |
| **Recepção do resultado externo** | Resultado de execução, correlação e contexto permitido. | Situação operacional validada para realização de resposta, ou erro operacional. | Não reescreve hipóteses; distingue recusa, indisponibilidade e falha; resultado sem correlação não é aceito como sucesso. |
| **Realização textual** | Situação de interpretação, diálogo, política ou execução e recursos textuais versionados. | Resposta textual correlacionada, ou erro de realização. | Não produz áudio; não inventa efeito externo; entradas efetivas iguais produzem conteúdo semanticamente igual. |

## Múltiplas hipóteses e abstinência

**CONTRATO APROVADO.** A coleção de hipóteses pode ter cardinalidade zero, um ou maior que um em todos os contratos externos que a transportem. A cardinalidade é ortogonal à situação global: coleção vazia não determina abstinência, e nenhum estágio pode presumir que o primeiro item seja verdadeiro apenas por posição.

**CONTRATO APROVADO.** Um estágio pode reduzir, manter ou ampliar o conjunto de candidatas somente por regra versionada e auditável, preservando o vínculo entre entrada, transformação e motivo. Uma candidata removida não pode desaparecer sem situação ou rastro conforme a política de observabilidade.

**CONTRATO APROVADO.** A abstinência é uma saída deliberada quando a evidência ou o contrato não sustentam interpretação segura. Ela pode ser global ou restrita a uma hipótese ou intenção, desde que a granularidade seja explícita.

**CONTRATO APROVADO.** Entrada fora do escopo, ambiguidade, falta de informação, bloqueio de política e falha técnica possuem significados distintos. Nenhum deles pode ser comunicado como execução bem-sucedida.

## Estado permitido

**CONTRATO APROVADO.** Os estágios de interpretação são funcionalmente sem estado entre solicitações, exceto por caches semanticamente transparentes. Remover, esvaziar ou alterar a ordem de preenchimento de um cache não pode mudar o resultado semântico.

**CONTRATO APROVADO.** O único estado conversacional permitido é o Contexto de Sessão recebido e devolvido por contrato. Ele é versionado, limitado, isolado e não contém credenciais nem estado autoritativo do Home Assistant.

**CONTRATO APROVADO.** Artefatos linguísticos, esquemas e snapshots de catálogo são somente leitura durante uma interpretação. Atualizações ficam disponíveis apenas a uma nova execução ou em uma fronteira de troca explicitamente definida; uma solicitação não mistura versões.

**CONTRATO APROVADO.** Eventos de observabilidade não são entrada implícita e não alteram decisões. Falha ao registrar um evento pode ser reportada de modo tipado, mas não cria hipótese diferente.

## Substituição por idioma e variante

**CONTRATO APROVADO.** Preparação rastreável, delimitação textual e formação de candidatas aceitam componentes e artefatos selecionados explicitamente por idioma e variante. Composição semântica pode receber esquemas localizados ou independentes de idioma, desde que a versão efetiva permaneça identificável.

**CONTRATO APROVADO.** Trocar um componente linguístico exige contrato equivalente de offsets, proveniência, determinismo, erros e versionamento. Uma variante não pode recorrer silenciosamente a recursos de outra variante.

**CONTRATO APROVADO.** Idioma ausente, inválido ou variante não suportada resulta em erro tipado de contrato ou capacidade antes de produzir intenção pronta; não é abstinência. Suporte futuro a outros idiomas é possibilidade arquitetural, não capacidade prometida pela primeira versão.

## Separação entre processamento offline e runtime

**CONTRATO APROVADO.** O processamento offline recebe somente fontes aprovadas com proveniência completa e produz artefatos imutáveis, manifestos de origem, versões, hashes e diagnósticos. Falha de origem, licença, validação ou reprodutibilidade impede a publicação do artefato.

**CONTRATO APROVADO.** O runtime apenas carrega artefatos publicados compatíveis e verifica identidade e integridade antes do uso. Ele não baixa fontes, treina, compila dados, altera artefatos nem depende de rede para interpretar.

**CONTRATO APROVADO.** Dados dinâmicos fornecidos em runtime permanecem catálogos de domínio ou contexto do usuário e não entram no ciclo de compilação linguística automaticamente. Observações produzidas pelo próprio sistema não constituem evidência independente.

**CONTRATO APROVADO.** Um artefato obrigatório ausente, incompatível ou com integridade divergente causa falha explícita de inicialização. Não há degradação silenciosa nem substituição por recurso sem proveniência.

## Propagação e classificação de erros

**CONTRATO APROVADO.** A tabela seguinte define classes que devem permanecer distinguíveis nas fronteiras do fluxo.

| Classe | Origem | Propagação contratual | Efeito proibido |
| --- | --- | --- | --- |
| **Contrato de entrada** | Tipo, versão, capacidade, tamanho ou codificação inválida. | Encerrar antes da interpretação com erro tipado e correlação disponível. | Tratar como fora de escopo ou tentar executar. |
| **Texto e offsets** | Transformação não rastreável ou limites inválidos. | Interromper o trecho ou a solicitação na menor granularidade segura e preservar diagnóstico. | Descartar caractere ou ajustar offset silenciosamente. |
| **Artefato ou esquema** | Ausência, incompatibilidade, integridade divergente ou configuração incoerente. | Impedir uso do recurso afetado e emitir falha técnica identificável. | Substituir por dado não aprovado ou versão implícita. |
| **Interpretação insuficiente** | Nenhuma leitura sustentada, slot ausente ou evidência insuficiente. | Produzir pendência ou abstinência com motivo de insuficiência, preservando a categoria. A mera insuficiência não autoriza classificá-la como fora de escopo. | Fabricar hipótese ou valor; reclassificar insuficiência como fora de escopo sem avaliação separada. |
| **Fora de escopo** | Avaliação separada conclui que nenhuma interpretação suportada se aplica à entrada. | Produzir situação fora de escopo explícita, sem proposta de execução. | Inferir fora de escopo apenas da ausência de leitura, de slot ou de evidência; convertê-lo em falha técnica. |
| **Ambiguidade** | Mais de uma alternativa relevante permanece viável. | Preservar candidatas e pedir esclarecimento quando delimitável. | Selecionar por acaso, ordem de iteração ou conveniência. |
| **Sessão** | Contexto ausente, expirado, incompatível ou cruzado. | Isolar a solicitação e produzir erro, esclarecimento ou abstinência tipada. | Reutilizar estado de outra sessão ou estado expirado. |
| **Execução no Home Assistant** | Recusa, indisponibilidade, falha ou resultado sem correlação. | Receber pelo fluxo separado e comunicar situação operacional sem alterar a interpretação. | Classificar como erro linguístico ou alegar sucesso. |
| **Realização textual** | Recurso incompatível ou situação sem realização segura. | Emitir erro tipado ou resposta mínima segura aprovada. | Inventar detalhe semântico ou operacional. |

**CONTRATO APROVADO.** Um erro preserva sua classe ao atravessar estágios. Um estágio pode acrescentar contexto seguro e correlação, mas não pode reclassificar silenciosamente falha técnica como abstinência nem falha externa como erro de interpretação.

**CONTRATO APROVADO.** Diagnósticos destinados a observabilidade devem ser minimizados e não incluir o conteúdo textual por padrão. A ausência de detalhe sensível não impede a distinção entre classes de erro.

## Decisões ainda necessárias

**DECISÃO PENDENTE — OPEN-002.** Definir a política Unicode efetiva do estágio de preparação rastreável.

**DECISÃO PENDENTE — OPEN-003.** Definir unidade, origem, intervalos e regras de conversão dos offsets.

**DECISÃO PENDENTE — OPEN-007.** Definir ordenação, empates e representação de eventual medida técnica das hipóteses.

**DECISÃO PENDENTE — OPEN-009.** Definir identidade, vigência e troca atômica de snapshots do catálogo dinâmico.

**DECISÃO PENDENTE — OPEN-010.** Definir transições, expiração, persistência e concorrência do contexto de sessão.

**DECISÃO PENDENTE — OPEN-012.** Definir o transporte local dos contratos sem acoplar o modelo conceitual a uma tecnologia.

**DECISÃO PENDENTE — OPEN-013.** Definir regras de versão, compatibilidade e negociação de capacidades.

**DECISÃO PENDENTE — OPEN-015.** Definir limites quantitativos e comportamento de sobrecarga a partir de medições, sem meta inventada.
