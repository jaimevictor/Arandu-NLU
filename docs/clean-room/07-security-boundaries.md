# Fronteiras de segurança

Data: 2026-08-12

Status: requisitos de segurança clean-room aprovados no nível conceitual

## Classificação normativa

### LIMITES APROVADOS

- Toda entrada que cruza uma fronteira de confiança é não confiável até ser validada no processo receptor.
- O runtime de interpretação não possui credenciais nem capacidade direta de produzir efeitos externos.
- Somente o adaptador Home Assistant pode manter credenciais e solicitar efeitos ao Home Assistant.
- Uma Proposta de Execução determinística continua sendo apenas uma proposta; autorização é uma decisão independente, tomada na fronteira de execução com estado corrente.
- Falha de validação, falta de contexto confiável ou estado externo inconclusivo resulta em bloqueio, abstinência ou resultado indeterminado explícito.

Somente as linhas `SEC-001` a `SEC-014` da tabela de requisitos de segurança são requisitos independentes contados e testados como unidades próprias. Os limites, o modelo de fronteiras, a ordem de validação e as evidências deste documento elaboram esses IDs e outros IDs canônicos do pacote; não criam requisitos autônomos.

### DECISÃO PENDENTE

- `OPEN-012` e `OPEN-014` — mecanismo concreto de isolamento entre processos, condicionado às plataformas aprovadas;
- `OPEN-021` — identidade operacional, autenticação, autorização, permissões e regras de comunicação de clientes e processos;
- `OPEN-022` — armazenamento, provisão, rotação e revogação de credenciais;
- `OPEN-011` — taxonomia de operações sensíveis, autoridade, política de confirmação, validade e prova da confirmação;
- `OPEN-010` e `OPEN-019` — proteção, acesso, retenção e descarte de sessões, logs e trilhas;
- `OPEN-015` — limites de payload, consumo de recursos e contenção de abuso;
- `OPEN-009` e `OPEN-021` — atualidade, integridade, origem e autenticação de snapshots de catálogo;
- `OPEN-023` — idempotência, repetição, reconciliação, compensação e transações após indisponibilidade;
- `OPEN-024` — taxonomia de erros, correlação e divulgação segura de diagnósticos.

Nenhuma política quantitativa está aprovada por este documento.

## Modelo de fronteiras

Fluxo conceitual aprovado:

1. o cliente entrega conteúdo e contexto ao processo de interpretação;
2. o processo de interpretação produz um Resultado de Interpretação, sem credenciais e sem Proposta de Execução;
3. o gestor de diálogo e a política consomem esse resultado e produzem, quando permitido, uma Proposta de Execução sem efeito próprio;
4. o adaptador Home Assistant revalida a Proposta de Execução com política e catálogo correntes;
5. somente esse adaptador usa credenciais para solicitar um efeito ao Home Assistant;
6. o adaptador relata o que pôde observar, inclusive rejeição, parcialidade ou indeterminação.

O snapshot do catálogo atravessa a fronteira no sentido adaptador → resolução. Ele descreve recursos e capacidades observados, mas não concede autoridade para usá-los.

## Requisitos de segurança

| ID | Limite protegido | Requisito — REQUISITO APROVADO | Falha segura — REQUISITO APROVADO | Critério de aceite — REQUISITO APROVADO |
| --- | --- | --- | --- | --- |
| SEC-001 | Fronteiras de confiança e processos | Interpretação e execução no Home Assistant ficam em processos separados por uma fronteira explícita. Apenas contratos tipados atravessam a fronteira; estruturas internas, autoridade implícita e objetos executáveis não atravessam. | Se a separação ou a validação do contrato não puder ser demonstrada, a execução permanece desabilitada. Falha de um processo não concede capacidades adicionais ao outro. | Teste de implantação demonstra processos distintos, comunicação apenas pelo contrato aprovado e impossibilidade de o processo de interpretação invocar diretamente o conector do Home Assistant. |
| SEC-002 | Menor privilégio | Cada processo recebe somente arquivos, armazenamento, identidade, rede e operações necessários à sua responsabilidade declarada. Permissões são negadas por padrão e ampliadas apenas por decisão explícita. | Permissão ausente bloqueia a operação correspondente; o sistema não amplia privilégios automaticamente nem transfere privilégios entre processos. | Revisão de privilégios e testes negativos comprovam que retirar cada permissão não essencial mantém a função prevista e que acessos fora do escopo são negados. |
| SEC-003 | Credenciais | Credenciais do Home Assistant existem e são usadas somente no adaptador. Não aparecem em solicitações de interpretação, hipóteses, sessões, snapshots, Propostas de Execução, respostas finais, métricas ou logs. | Material com aparência ou marcação de credencial em uma fronteira não autorizada é rejeitado e não é persistido nem encaminhado. Ausência de credencial no adaptador impede o efeito externo. | Varredura de artefatos e testes com marcadores secretos comprovam confinamento ao adaptador, sanitização das saídas e falha sem efeito quando a credencial não está disponível. |
| SEC-004 | Validação de domínio | O adaptador verifica, contra catálogo e política correntes, que o domínio da operação é conhecido, permitido e compatível com a Proposta de Execução. | Domínio ausente, desconhecido, proibido ou divergente é negado antes de qualquer efeito. Não há substituição automática por domínio aproximado. | Testes positivos e negativos demonstram aceite apenas da combinação permitida e ausência de chamada externa para domínio inválido. |
| SEC-005 | Validação de serviço | O adaptador verifica que o serviço existe, é permitido para o domínio e é compatível com o tipo de operação da Proposta de Execução. | Serviço ausente, desconhecido, proibido ou incompatível é negado; nenhum serviço padrão é escolhido como fallback. | Matriz de contrato cobre combinações válidas e inválidas e comprova que somente as válidas alcançam o conector externo. |
| SEC-006 | Validação de entidade | O adaptador verifica identidade, existência, domínio, capacidade e vínculo da entidade com o snapshot e o contexto autorizados. | Entidade inexistente, incompatível, fora do snapshot ou alterada de modo relevante é negada ou devolvida para nova resolução; não há retargeting silencioso. | Testes com entidade válida, removida, incompatível e pertencente a outro snapshot demonstram validação corrente e ausência de efeito no alvo incorreto. |
| SEC-007 | Validação de parâmetros | Todo parâmetro é validado por presença, tipo, nome, compatibilidade e restrições declaradas para o serviço e a entidade. Campos inesperados não são repassados. | Parâmetro ausente, extra, malformado, fora das restrições ou incompatível causa rejeição integral da operação afetada, sem coerção insegura. | Testes de schema, limites declarados e campos adicionais comprovam rejeição antes do conector e ausência de execução parcial causada por validação tardia. |
| SEC-008 | Confusão de entidades | Colisões de alias, referências ambíguas, mudanças de catálogo e candidatos visualmente ou semanticamente confundíveis são tratados como ambiguidade, não como equivalência. | Sem identidade inequívoca, o sistema solicita esclarecimento ou se abstém. Ordenação, proximidade ou histórico não autorizam escolha silenciosa. | Fixtures com candidatos colidentes e troca de snapshot comprovam que nenhum deles é executado sem resolução explícita e validada. |
| SEC-009 | Confirmação de operação sensível | Operação classificada como sensível exige evidência de confirmação válida segundo política aprovada, vinculada à Proposta de Execução exata, sessão, alvo e parâmetros. Alterar qualquer elemento relevante exige nova decisão. | Evidência ausente, inválida, incompatível ou não verificável bloqueia a execução. O sistema não interpreta repetição, determinismo ou contexto anterior como confirmação. | Testes mostram bloqueio sem evidência, aceite com evidência correspondente e invalidação após alteração de alvo, serviço ou parâmetro. |
| SEC-010 | Estado de sessão | Estado e esclarecimentos são isolados por sessão, vinculados ao turno correto e protegidos contra confusão, sobrescrita silenciosa e reutilização indevida. | Referência ausente, conflitante, encerrada ou de outra sessão é rejeitada ou leva a reinício explícito; contexto não é importado de sessão vizinha. | Testes concorrentes e intercalados comprovam isolamento, detecção de estado conflitante e impossibilidade de aplicar resposta ao esclarecimento errado. |
| SEC-011 | Logs e observabilidade | Logs registram decisões de segurança e correlação suficientes para auditoria, com minimização e sanitização. Credenciais nunca são registradas; outros dados sensíveis dependem de política explícita de acesso e retenção. | Falha do sink de logs não desabilita validações nem provoca despejo de estruturas internas. Campos não sanitizáveis são omitidos ou substituídos por marcadores seguros. | Testes com marcadores sensíveis, erros internos e sink indisponível comprovam ausência de segredos, manutenção das decisões de segurança e correlação auditável. |
| SEC-012 | Entradas malformadas e hostis | Cada processo valida novamente toda entrada recebida, incluindo estrutura, tipos, referências, versão e integridade. Dados não são tratados como código nem como instrução para alterar política. | Entrada inválida é rejeitada antes de efeitos ou persistência indevida; falha de um item não autoriza execução parcial dos demais. Exaustão detectada encerra o trabalho afetado de forma controlada. | Testes negativos, geração de entradas e fuzzing nas fronteiras comprovam rejeição determinística, ausência de efeitos e recuperação controlada do processo. |
| SEC-013 | Indisponibilidade do Home Assistant | Timeout, desconexão, erro remoto e resposta inconclusiva do Home Assistant são estados explícitos. Repetição ou reconciliação somente ocorre por política aprovada e preserva correlação com a Proposta de Execução original. | O sistema nunca comunica sucesso sem confirmação. Quando não puder determinar se houve efeito, retorna resultado indeterminado e não repete automaticamente por mera suposição de falha. | Simulações de indisponibilidade antes, durante e depois da solicitação comprovam distinção entre não executado, parcial, falha e indeterminado, sem sucesso fabricado nem duplicação automática. |
| SEC-014 | Separação entre determinismo e autorização | Reproduzir o mesmo Resultado de Interpretação ou a mesma Proposta de Execução não concede autoridade. Toda Proposta de Execução é revalidada no momento da execução contra política, confirmação, sessão, catálogo e capacidades correntes. | Contexto de autorização ausente, desatualizado ou incompatível bloqueia a execução, mesmo que a Proposta de Execução seja idêntica a outra anteriormente permitida. | Um teste reproduz a mesma Proposta de Execução sob estados de autorização permitido e negado e comprova decisões distintas na fronteira, sem alteração da saída determinística da interpretação. |

## Ordem mínima de validação

### LIMITES APROVADOS

Antes de solicitar qualquer efeito externo, o adaptador deve concluir, sem confiar na validação feita a montante:

- validação estrutural e de versão;
- validação de sessão, catálogo e correlação;
- validação de domínio, serviço, entidade e parâmetros;
- avaliação da política corrente;
- validação de confirmação quando exigida;
- autorização com os privilégios do próprio adaptador.

Uma rejeição em qualquer etapa impede as etapas com efeito. A ordem interna exata pode variar apenas se preservar essa propriedade e não enfraquecer nenhuma validação.

### DECISÃO PENDENTE

- `OPEN-011` — organização interna do motor de políticas e origem e formato das regras de autorização;
- `OPEN-008` e `OPEN-023` — tratamento transacional de Propostas de Execução com várias operações;
- `OPEN-023` — comportamento de repetição, retomada, reconciliação e compensação depois de resultado indeterminado;
- `OPEN-012`, `OPEN-014` e `OPEN-021` — mecanismo técnico de atestação da separação, identidade e privilégios dos processos;
- `OPEN-024` — classificação, correlação e divulgação dos erros produzidos nas etapas de validação.

## Evidências exigidas para implementação

### LIMITES APROVADOS

Uma implementação somente atende a estas fronteiras quando fornece:

- testes de contrato para cada API consumida na fronteira;
- testes negativos para cada SEC deste documento;
- inventário revisável de processos, credenciais, permissões e canais de comunicação;
- rastreabilidade entre Resultado de Interpretação, decisão de política, Proposta de Execução e Resultado de Execução observado;
- demonstração de que logs e respostas não contêm credenciais;
- registro explícito das decisões pendentes que tenham sido resolvidas durante a implementação.
