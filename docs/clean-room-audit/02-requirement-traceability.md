# Rastreabilidade dos requisitos do handoff

Data: 2026-08-12

## Convenções

Este arquivo pertence à auditoria e não integra o handoff. A coluna “Evidência da Fase 1” registra somente evidência real ou, quando não existe fato positivo sobre o produto analisado, declara explicitamente que o requisito é decisão própria. Ausência observada nunca é usada como prova de que uma solução específica existe ou deve ser copiada.

Situações usadas:

- **APROVADO / NÃO IMPLEMENTADO**: requisito próprio aceito no handoff; execução pertence a fase futura;
- **ESPECIFICADO / EXECUÇÃO FUTURA**: critério de teste definido, ainda sem implementação, corpus ou resultado;
- **PENDENTE**: escolha humana `OPEN`, fora da contagem dos requisitos.

## Requisitos funcionais

| Requisito do handoff | Decisão arquitetural de origem | Evidência da Fase 1 | Transformação aplicada | Situação |
| --- | --- | --- | --- | --- |
| FR-001 | `03-ptbr-target-architecture.md`: protocolo local e resultados tipados; `06-roadmap.md`, fase de protocolo | `E-035` confirma apenas uma superfície local documentada, não o contrato novo | Generalizado para uma solicitação textual com exatamente um resultado terminal correlacionado; comandos e protocolo observados excluídos | APROVADO / NÃO IMPLEMENTADO |
| FR-002 | `03-ptbr-target-architecture.md`: texto como entrada; separação entre planos | Não há evidência positiva de STT no núcleo auditado; decisão própria de fronteira | Modalidade reduzida a texto recebido, com origem declarada e sem captura de áudio | APROVADO / NÃO IMPLEMENTADO |
| FR-003 | `03-ptbr-target-architecture.md`: preservação Unicode e offsets | `E-017` confirma descarte de não ASCII no produto analisado e justifica não repetir essa falha | Convertido em obrigação positiva de preservar integralmente o original, sem copiar rotina de limpeza | APROVADO / NÃO IMPLEMENTADO |
| FR-004 | `03-ptbr-target-architecture.md` e `06-roadmap.md`: normalização Unicode rastreável | `E-017` confirma risco crítico para caracteres PT-BR | Especificado por saída e rastreabilidade; política concreta mantida em `OPEN-002` | APROVADO / NÃO IMPLEMENTADO |
| FR-005 | `03-ptbr-target-architecture.md` e `06-roadmap.md`: unidades com spans/offsets | `E-017` evidencia perda textual; não há contrato de offsets reutilizável confirmado | Criado contrato próprio de Unidade Textual; unidade/convenção ficam em `OPEN-003` | APROVADO / NÃO IMPLEMENTADO |
| FR-006 | `03-ptbr-target-architecture.md`: múltiplas leituras e fallback explícito | `E-021` confirma pontuações/candidatas em técnica observada; `E-024` confirma estrutura rica, sem autorizar reuso | Preservadas apenas cardinalidade, rastreabilidade e ordem determinística; modelos e campos excluídos | APROVADO / NÃO IMPLEMENTADO |
| FR-007 | `03-ptbr-target-architecture.md`: correção contextual auditável | `E-023` confirma correção e heurísticas inglesas observadas | Reescrito com preservação incondicional do original e capacidade desabilitada até decisão de `OPEN-006`; se aprovada, toda correção será apenas sugestão rastreável; heurísticas e léxico foram removidos | APROVADO / NÃO IMPLEMENTADO |
| FR-008 | `03-ptbr-target-architecture.md`: segmentação abstrata | `E-025` e `E-026` confirmam interpretação frasal observada, não um contrato reutilizável | Criado contrato neutro de segmentos com cobertura e offsets; decomposição por frase/tipo excluída | APROVADO / NÃO IMPLEMENTADO |
| FR-009 | `03-ptbr-target-architecture.md`: IR com múltiplas hipóteses e abstinência | `E-027` confirma limitação observada a um intent por frase | Redesenhado como coleção zero/uma/várias hipóteses cuja cardinalidade é ortogonal à situação global; nenhum shape, score ou acoplamento automático entre vazio e abstinência foi transportado | APROVADO / NÃO IMPLEMENTADO |
| FR-010 | `03-ptbr-target-architecture.md`: IR e schemas declarativos | `E-025` a `E-027` confirmam interpretação/intents observados, sem autorizar nomes ou estrutura | “Intenção Normalizada” própria, versionada e com situação explícita; taxonomia fica em `OPEN-001` | APROVADO / NÃO IMPLEMENTADO |
| FR-011 | `03-ptbr-target-architecture.md`: schemas, slots e constraints | `E-024` a `E-026` mostram dados sintático-semânticos observados, não contrato de slot aprovado | Slot próprio tipado com estados resolvido/ausente/ambíguo/inaplicável; campos observados excluídos | APROVADO / NÃO IMPLEMENTADO |
| FR-012 | `03-ptbr-target-architecture.md` e `05-port-gap-analysis.md`: multi-intent novo | `E-027` confirma que o resultado observado colapsa para um intent por frase | Definido comportamento próprio para múltiplas intenções, conflitos e dependências; política parcial fica em `OPEN-008` | APROVADO / NÃO IMPLEMENTADO |
| FR-013 | `03-ptbr-target-architecture.md`: catálogo dinâmico separado e somente leitura | `E-037` confirma ausência de adaptador HA nos artefatos públicos; não é prova de implementação | Criado contrato de snapshot local imutável, sem formato, endpoint ou inventário real | APROVADO / NÃO IMPLEMENTADO |
| FR-014 | `03-ptbr-target-architecture.md` e `04-data-provenance-policy.md`: separar evidência linguística, entidades e aliases | `E-024` confirma informação lexical/NER observada; `E-037` confirma que integração não estava presente | Menção e referência foram modeladas como conceitos diferentes; campos e taxonomias da origem removidos | APROVADO / NÃO IMPLEMENTADO |
| FR-015 | `03-ptbr-target-architecture.md`: entidade ambígua deve esclarecer, nunca executar | Não há resolvedor HA positivo confirmado (`E-037`); regra é decisão própria do alvo | Resultado limitado a correspondência única, ambiguidade ou ausência, com fail-closed | APROVADO / NÃO IMPLEMENTADO |
| FR-016 | `03-ptbr-target-architecture.md`: fallbacks e erros explícitos; `06-roadmap.md`: critérios negativos | `E-030` registra ausência de testes públicos no pacote, não comportamento terminal | Criada taxonomia própria entre malformado, fora de escopo, insuficiente e ambíguo | APROVADO / NÃO IMPLEMENTADO |
| FR-017 | `03-ptbr-target-architecture.md`: sessão curta separada do estado externo | `E-030` e `E-035` não confirmam sessão pública implementada | Estado entre turnos transformado em Contexto de Sessão explícito, isolado e versionado | APROVADO / NÃO IMPLEMENTADO |
| FR-018 | `03-ptbr-target-architecture.md`: resolução contextual curta e abstinência | `E-029` confirma correferência limitada observada | Preservado apenas o objetivo geral; inventário pronominal, tipos e algoritmo removidos; exige antecedente suficiente e único | APROVADO / NÃO IMPLEMENTADO |
| FR-019 | `03-ptbr-target-architecture.md` e `06-roadmap.md`: esclarecimento determinístico | `E-030` confirma ausência de pedidos de esclarecimento no pacote público | Criado Pedido de Esclarecimento próprio, ligado a pendência e sessão, sem copiar conteúdo | APROVADO / NÃO IMPLEMENTADO |
| FR-020 | `03-ptbr-target-architecture.md` e `06-roadmap.md`: expiração/reset de sessão | Não há política confirmada na origem (`E-030`); decisão própria | Contrato exige transições determinísticas; duração e persistência ficam em `OPEN-010` | APROVADO / NÃO IMPLEMENTADO |
| FR-021 | `03-ptbr-target-architecture.md`: núcleo sem credenciais e adaptador separado | `E-037` confirma ausência de adaptador no código público; não define o novo | Limite reescrito com autoria explícita: o núcleo emite Resultado de Interpretação, o gestor de diálogo e política separado cria eventual Proposta de Execução sem efeito e o adaptador a revalida; nenhuma chamada ou DTO observado foi incluído | APROVADO / NÃO IMPLEMENTADO |
| FR-022 | `03-ptbr-target-architecture.md`: execução em plano separado e resposta posterior | `E-037` não confirma integração existente | Resultado externo criado como contrato próprio, imutável em relação à interpretação | APROVADO / NÃO IMPLEMENTADO |
| FR-023 | `03-ptbr-target-architecture.md`: templates determinísticos em plano de resposta | `E-030` não confirma implementação pública de resposta | Obrigação limitada a texto fiel ao estado; TTS excluído e conteúdo concreto reservado a `OPEN-020` | APROVADO / NÃO IMPLEMENTADO |
| FR-024 | `03-ptbr-target-architecture.md`: artefatos versionados, hashes e fail-fast | `E-013` e `E-014` confirmam carga e metadados de artefato observados | Refeito como contrato genérico de identidade, integridade e compatibilidade; formato e campos observados excluídos | APROVADO / NÃO IMPLEMENTADO |
| FR-025 | `03-ptbr-target-architecture.md`, `04-data-provenance-policy.md`, `06-roadmap.md`: compilação offline | `E-013` e `E-014` confirmam artefato compilado; `E-030` registra ausência de pipeline público | Especificada compilação própria só para fontes manifestadas; nenhum importador, formato ou fonte foi escolhido | APROVADO / NÃO IMPLEMENTADO |
| FR-026 | `03-ptbr-target-architecture.md`: observabilidade e fallbacks auditáveis | `E-030` registra ausência de testes/benchmarks públicos; não há trilha reutilizável confirmada | Criado contrato de eventos próprios com minimização por padrão e independência do sink | APROVADO / NÃO IMPLEMENTADO |

## Requisitos não funcionais

| Requisito do handoff | Decisão arquitetural de origem | Evidência da Fase 1 | Transformação aplicada | Situação |
| --- | --- | --- | --- | --- |
| NFR-001 | `03-ptbr-target-architecture.md`: runtime determinístico; `06-roadmap.md`: testes reproduzíveis | `E-021` confirma técnica determinística observada, mas algoritmo não foi transportado | Determinismo definido semanticamente por entradas efetivas e resultados, sem prescrever algoritmo | APROVADO / NÃO IMPLEMENTADO |
| NFR-002 | `03-ptbr-target-architecture.md`: execução local e separação do executor | `E-035` documenta interface local no produto analisado, sem fornecer contrato interno | Localidade e isolamento convertidos em propriedade testável; CLI/RPC observado excluído | APROVADO / NÃO IMPLEMENTADO |
| NFR-003 | `03-ptbr-target-architecture.md`: runtime sem rede | `E-035` menciona acesso local, mas não prova ausência de rede interna; requisito é próprio | Proibição absoluta de dependência de rede na interpretação, verificável por instrumentação | APROVADO / NÃO IMPLEMENTADO |
| NFR-004 | `03-ptbr-target-architecture.md`: decisões e fallbacks observáveis | `E-030` registra ausência de testes/benchmarks públicos, não uma solução de auditoria | Auditabilidade descrita por correlação e eventos neutros, sem campos ou logger observados | APROVADO / NÃO IMPLEMENTADO |
| NFR-005 | `02-english-coupling.md`, `03-ptbr-target-architecture.md`, `06-roadmap.md`: Unicode PT-BR | `E-017` confirma descarte de não ASCII | Risco convertido em preservação e offsets verificáveis; detalhes em `OPEN-002/003` | APROVADO / NÃO IMPLEMENTADO |
| NFR-006 | `03-ptbr-target-architecture.md`: versionamento/compatibilidade de artefatos | `E-014` confirma metadados de versão/hash observados | Generalizado para todos os contratos, schemas, configurações e artefatos; schema observado removido | APROVADO / NÃO IMPLEMENTADO |
| NFR-007 | `03-ptbr-target-architecture.md`: observabilidade sem PII desnecessária; `AGENTS.md`: preservação e segurança | Não há evidência positiva de política de logs na origem | Criada regra própria de minimização por padrão, sem supor retenção (`OPEN-019`) | APROVADO / NÃO IMPLEMENTADO |
| NFR-008 | `03-ptbr-target-architecture.md` e `04-data-provenance-policy.md`: builds reproduzíveis | `E-013/E-014` confirmam artefato, mas `E-030` não confirma compilador público | Reprodutibilidade definida por entradas, ferramentas, parâmetros, hashes e ambiente próprios | APROVADO / NÃO IMPLEMENTADO |
| NFR-009 | `06-roadmap.md`: medir desempenho com corpus controlado | `E-008` registra números sem proveniência e `E-030` ausência de benchmarks públicos | Números excluídos; definido método mínimo e baseline antes de meta (`OPEN-018`) | APROVADO / NÃO IMPLEMENTADO |
| NFR-010 | `03-ptbr-target-architecture.md`: observabilidade transversal e fallback do sink | Não há comportamento observado suficiente; decisão própria | Falha de observabilidade separada de semântica e segurança | APROVADO / NÃO IMPLEMENTADO |
| NFR-011 | `06-roadmap.md`: empacotamento/plataformas somente após decisão | `E-038` confirma limitação do ambiente de auditoria, não suporte de produto | Portabilidade proibida até matriz aprovada em `OPEN-014`; nenhuma plataforma presumida | APROVADO / NÃO IMPLEMENTADO |
| NFR-012 | `02-english-coupling.md` e `03-ptbr-target-architecture.md`: arquitetura por idioma, PT-BR inicial | `E-017` a `E-023` confirmam acoplamento executável ao inglês | Substituição definida por contrato e invariantes; idioma ou variante não suportado é erro tipado, nunca fallback ou abstinência; listas, tagset e heurísticas inglesas excluídos | APROVADO / NÃO IMPLEMENTADO |

## Contratos externos

| Requisito do handoff | Decisão arquitetural de origem | Evidência da Fase 1 | Transformação aplicada | Situação |
| --- | --- | --- | --- | --- |
| API-001 | `03-ptbr-target-architecture.md`: protocolo local e IR estável; `06-roadmap.md`: contrato antes da integração | `E-035` documenta operação de interpretação local observada | Criada requisição neutra e correlacionada; nomes de comando, transporte e wire format excluídos | APROVADO / NÃO IMPLEMENTADO |
| API-002 | `03-ptbr-target-architecture.md`: abstinência explícita e IR plural | `E-025` confirma retorno de interpretação observado, mas não cardinalidade zero contratual | Resposta vazia própria com situação global tipada e sem proposta; cardinalidade zero não foi equiparada automaticamente a abstinência, erro ou fora de escopo | APROVADO / NÃO IMPLEMENTADO |
| API-003 | `03-ptbr-target-architecture.md`: hipótese/intent tipado | `E-025` a `E-027` confirmam interpretação e intent observados | Cardinalidade um expressa sem reproduzir DTO, campos ou score da origem | APROVADO / NÃO IMPLEMENTADO |
| API-004 | `03-ptbr-target-architecture.md`: múltiplas hipóteses/intents | `E-027` confirma limitação observada a um intent por frase | Contrato novo preserva várias hipóteses, composição/conflito e ordem determinística | APROVADO / NÃO IMPLEMENTADO |
| API-005 | `03-ptbr-target-architecture.md` e `06-roadmap.md`: esclarecimento por sessão | `E-030` não confirma esclarecimento no pacote público | Criada solicitação de esclarecimento ligada a pendência, sem conteúdo linguístico | APROVADO / NÃO IMPLEMENTADO |
| API-006 | `03-ptbr-target-architecture.md`: gestor de sessão e clarificação | `E-030` não confirma resposta de esclarecimento implementada | Transição própria correlacionada e isolada por sessão | APROVADO / NÃO IMPLEMENTADO |
| API-007 | `03-ptbr-target-architecture.md` e `06-roadmap.md`: estado curto de diálogo | `E-030/E-035` não confirmam protocolo de sessão público | Operações conceituais próprias; persistência, transporte e concorrência ficam em `OPEN-010/012` | APROVADO / NÃO IMPLEMENTADO |
| API-008 | `03-ptbr-target-architecture.md`: importação separada de inventário dinâmico | `E-037` confirma ausência de integração HA nos artefatos públicos | Snapshot imutável e atômico definido sem inventário real, endpoint ou formato observado | APROVADO / NÃO IMPLEMENTADO |
| API-009 | `03-ptbr-target-architecture.md`: IR/proposta passa por política e adaptador | `E-037` confirma ausência de adaptador público; não define o contrato | Proposta própria não autoritativa, revalidável e sem efeito | APROVADO / NÃO IMPLEMENTADO |
| API-010 | `03-ptbr-target-architecture.md`: execução em plano separado | `E-037` não oferece resultado de integração reutilizável | Resultado próprio distingue efeito, recusa, ausência, indeterminação e parcialidade quando aprovada | APROVADO / NÃO IMPLEMENTADO |
| API-011 | `03-ptbr-target-architecture.md`: geração determinística de respostas | `E-030` não confirma implementação pública de templates | Contrato de resposta final por classe, sanitizado e sem conteúdo/template específico | APROVADO / NÃO IMPLEMENTADO |
| API-012 | `03-ptbr-target-architecture.md`: compatibilidade de artefatos e protocolo versionado | `E-014` confirma metadados de versão observados; `E-035` confirma interface local documentada | Versões/capacidades generalizadas; campos e negociação concreta ficam em `OPEN-013` | APROVADO / NÃO IMPLEMENTADO |
| API-013 | `03-ptbr-target-architecture.md`: erros tipados e observabilidade | `E-031/E-032` registram divergências públicas de comportamento/documentação; `E-038` limita validação por build | Criada representação externa estável e sanitizada para erros, preservando Resultado de Interpretação como único tipo semântico emitido pelo núcleo; divergências observadas não foram copiadas | APROVADO / NÃO IMPLEMENTADO |

## Requisitos de segurança

| Requisito do handoff | Decisão arquitetural de origem | Evidência da Fase 1 | Transformação aplicada | Situação |
| --- | --- | --- | --- | --- |
| SEC-001 | `03-ptbr-target-architecture.md`: planos separados de interpretação e execução | `E-035` confirma interface local documentada, mas não a separação interna proposta | Criada fronteira própria entre processos por contratos tipados, sem copiar RPC/CLI | APROVADO / NÃO IMPLEMENTADO |
| SEC-002 | `03-ptbr-target-architecture.md`: menor privilégio e credenciais isoladas | Não há prova positiva de privilégios na origem; decisão própria | Privilégios negados por padrão e limitados por responsabilidade | APROVADO / NÃO IMPLEMENTADO |
| SEC-003 | `03-ptbr-target-architecture.md`: credenciais só no adaptador | `E-037` confirma ausência de adaptador público, não política de segredos | Confinamento e sanitização próprios; nenhum segredo ou mecanismo observado incluído | APROVADO / NÃO IMPLEMENTADO |
| SEC-004 | `03-ptbr-target-architecture.md`: validar domínio no adaptador | `E-037` não confirma implementação existente | Validação positiva própria e fail-closed, sem lista de domínios | APROVADO / NÃO IMPLEMENTADO |
| SEC-005 | `03-ptbr-target-architecture.md`: validar serviço | `E-037` não confirma implementação existente | Contrato genérico sem nomes de serviço ou fallback padrão | APROVADO / NÃO IMPLEMENTADO |
| SEC-006 | `03-ptbr-target-architecture.md`: validar entidade e catálogo | `E-037` não confirma integração; `E-024` mostra conceitos lexicais/NER distintos | Identidade, snapshot e capacidade revalidados; modelos observados excluídos | APROVADO / NÃO IMPLEMENTADO |
| SEC-007 | `03-ptbr-target-architecture.md`: validar parâmetros | `E-037` não confirma implementação existente | Schema próprio obrigatório e rejeição de campo extra; nenhum parâmetro real criado | APROVADO / NÃO IMPLEMENTADO |
| SEC-008 | `03-ptbr-target-architecture.md`: ambiguidade de entidade exige clarificação | `E-029` confirma resolução limitada observada; `E-037` ausência de domínio HA | Generalizado para colisão de aliases/snapshots, sem algoritmo nem inventário | APROVADO / NÃO IMPLEMENTADO |
| SEC-009 | `03-ptbr-target-architecture.md`: política de confirmação no adaptador | Não há confirmação positiva observada; decisão própria | Confirmação vinculada à proposta exata e invalidada por mudança; taxonomia fica em `OPEN-011` | APROVADO / NÃO IMPLEMENTADO |
| SEC-010 | `03-ptbr-target-architecture.md`: sessão versionada e isolada | `E-030` não confirma sessão pública | Isolamento próprio e rejeição de referência cruzada | APROVADO / NÃO IMPLEMENTADO |
| SEC-011 | `03-ptbr-target-architecture.md`: logs/métricas sem PII desnecessária | Não há política positiva observada | Criado contrato próprio de minimização, correlação e tolerância a falha do sink | APROVADO / NÃO IMPLEMENTADO |
| SEC-012 | `03-ptbr-target-architecture.md`: falhas explícitas; `06-roadmap.md`: testes negativos | `E-032` registra divergência entre exemplos e assinaturas; não define tratamento seguro | Revalidação em cada fronteira, dados nunca tratados como código e exaustão controlada | APROVADO / NÃO IMPLEMENTADO |
| SEC-013 | `03-ptbr-target-architecture.md`: erro controlado quando integração indisponível | `E-037` confirma ausência de adaptador público | Estados próprios não executado/parcial/indeterminado; sem repetição automática presumida | APROVADO / NÃO IMPLEMENTADO |
| SEC-014 | `ADR-0001` e `03-ptbr-target-architecture.md`: decisão linguística separada de política/execução | Não há evidência positiva de autorização na origem; decisão própria | Determinismo explicitamente não concede autoridade; revalidação no momento do efeito | APROVADO / NÃO IMPLEMENTADO |

## Requisitos de dados e proveniência

Os requisitos `DATA-001..DATA-016` derivam diretamente das regras atuais do usuário e do `AGENTS.md`, usando os documentos da Fase 1 apenas para contexto de risco e governança. Eles foram reautorizados e redigidos como contratos próprios, com falha e aceite observáveis. Essa origem normativa atual e a remoção de conteúdo, formato e algoritmo identificáveis mitigam o risco de semelhança com o produto analisado.

| Requisito do handoff | Decisão arquitetural de origem | Evidência da Fase 1 | Transformação aplicada | Situação |
| --- | --- | --- | --- | --- |
| DATA-001 | Regras atuais do usuário e `AGENTS.md`: classes física e logicamente separadas; `04-data-provenance-policy.md` como contexto | `E-037` confirma ausência de inventário HA no código público; as classes do novo produto são decisão própria | Classes reautorizadas como contrato próprio, sem conteúdo, fonte ou vocabulário concreto; Perfis L e O não se fundem implicitamente | APROVADO / NÃO IMPLEMENTADO |
| DATA-002 | Regras atuais do usuário e `AGENTS.md`: metadados completos para dado linguístico; `04-data-provenance-policy.md` como contexto | `E-013/E-014` confirmam artefato/metadados observados, mas não proveniência suficiente | Contrato novo e exclusivo do Perfil L consolida ID, URL, snapshot, licença, hash, extração, transformações, justificativa, partição e revisão | APROVADO / NÃO IMPLEMENTADO |
| DATA-003 | `04-data-provenance-policy.md` e `03-ptbr-target-architecture.md`: manifestos versionados | `E-014` confirma metadados de artefato observados, sem cadeia completa confirmada | Criada cadeia genérica fonte-transformação-artefato-revisão, independente do schema observado | APROVADO / NÃO IMPLEMENTADO |
| DATA-004 | `04-data-provenance-policy.md`: licença compatível e revisão humana | `E-006/E-007/E-033/E-036` confirmam riscos e divergências reais de licença | Risco jurídico transformado em bloqueio de admissão; licenças específicas da origem excluídas do handoff | APROVADO / NÃO IMPLEMENTADO |
| DATA-005 | `04-data-provenance-policy.md`: cadeia de hashes | `E-003/E-005/E-013/E-014` confirmam checksums/VCS/metadados observados | Cadeia própria por entrada/intermediário/saída; algoritmo deve ser declarado, sem formato copiado | APROVADO / NÃO IMPLEMENTADO |
| DATA-006 | `04-data-provenance-policy.md`, `03-ptbr-target-architecture.md`, `06-roadmap.md`: pipeline offline reproduzível | `E-030` registra ausência de pipeline público confirmado | Pipeline descrito por propriedades e etapas de governança, sem código/importador da origem | APROVADO / NÃO IMPLEMENTADO |
| DATA-007 | `04-data-provenance-policy.md`: normalização separada do original | `E-017` confirma perda não ASCII observada | Convertido em preservação obrigatória, política versionada e vínculo original-derivado | APROVADO / NÃO IMPLEMENTADO |
| DATA-008 | Regras atuais do usuário e `04-data-provenance-policy.md`: deduplicação com preservação das origens | Não há implementação de deduplicação confirmada; decisão própria | Exigência abstrata por classe, sem algoritmo ou exemplo lexical; equivalência concreta permanece em `OPEN-025` | APROVADO / NÃO IMPLEMENTADO |
| DATA-009 | `04-data-provenance-policy.md`: conflitos não podem apagar proveniência | Não há comportamento positivo confirmado; decisão própria | Conflito exige alternativas e resolução humana registrada, nunca precedência tácita | APROVADO / NÃO IMPLEMENTADO |
| DATA-010 | `04-data-provenance-policy.md`: treino, desenvolvimento, validação e avaliação separados | `E-030` confirma ausência de testes/benchmarks no pacote público, não partições | Criado contrato próprio de manifestos, armazenamento, acesso e atribuição reproduzível | APROVADO / NÃO IMPLEMENTADO |
| DATA-011 | `04-data-provenance-policy.md`: prevenção de contaminação | Não há dataset público avaliado; decisão própria | Linhagem ampliada a ocorrência e derivados; avaliação contaminada é invalidada | APROVADO / NÃO IMPLEMENTADO |
| DATA-012 | `04-data-provenance-policy.md`: saída do próprio sistema não é evidência independente | Não depende de fato do produto; regra epistemológica própria | Material sintético rotulado e proibido na avaliação oculta | APROVADO / NÃO IMPLEMENTADO |
| DATA-013 | Regras atuais do usuário e `AGENTS.md`: catálogo, aliases e observações STT separados do pipeline linguístico; `04-data-provenance-policy.md` como contexto | `E-037` confirma ausência de integração HA pública; não há dados reais usados | Perfil O recebe somente metadados operacionais aplicáveis, sem URL/licença/partição fictícias; promoção a Perfil L exige nova admissão integral por `DATA-002..DATA-016` | APROVADO / NÃO IMPLEMENTADO |
| DATA-014 | `04-data-provenance-policy.md`: revisão humana em inclusão/alteração/remoção | Não há processo de revisão confirmado na origem | Criado histórico próprio de decisão e impacto, sem nomes de revisores reais | APROVADO / NÃO IMPLEMENTADO |
| DATA-015 | `04-data-provenance-policy.md`: remoção auditável e hashes; `06-roadmap.md`: versionamento | `E-014` confirma metadados de versão/hash observados | Adicionada remoção transitiva por fonte e rebuild, sem schema ou formato observado | APROVADO / NÃO IMPLEMENTADO |
| DATA-016 | Regras atuais do usuário e `AGENTS.md`: proibição de vocabulário sem origem e de LLM como fonte; `04-data-provenance-policy.md` como contexto | `E-019/E-022/E-023` confirmam listas/heurísticas inglesas observadas e excluídas | Regra negativa própria impede importar, lembrar ou gerar substitutos PT-BR sem proveniência; nenhuma lista foi criada | APROVADO / NÃO IMPLEMENTADO |

## Requisitos de teste e avaliação

| Requisito do handoff | Decisão arquitetural de origem | Evidência da Fase 1 | Transformação aplicada | Situação |
| --- | --- | --- | --- | --- |
| TEST-001 | `03-ptbr-target-architecture.md` e `06-roadmap.md`: teste por camada e critérios objetivos | `E-030` confirma ausência de testes públicos no pacote analisado | Criada matriz bidirecional própria entre todos os IDs e casos executáveis; o plano já apresenta linha explícita de cobertura para cada `NFR-001..NFR-012` | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-002 | `03-ptbr-target-architecture.md`: contract tests para protocolo e camadas | `E-032` registra divergência entre exemplos e assinaturas públicas | Teste genérico de campos, tipos, cardinalidades, versões e falhas; exemplos observados excluídos | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-003 | `03-ptbr-target-architecture.md`: snapshots determinísticos; `06-roadmap.md`: reproduzibilidade | `E-021` confirma técnica determinística observada, sem reutilização do algoritmo | Comparação semântica entre repetições/processos, com campos voláteis declarados | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-004 | `03-ptbr-target-architecture.md` e `06-roadmap.md`: round-trip, diacríticos e offsets | `E-017` confirma descarte de não ASCII observado | Fixtures técnicas opacas e não linguísticas; nenhum exemplo lexical extraído ou gerado | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-005 | `03-ptbr-target-architecture.md`: ambiguidades carregadas até resolução | `E-027/E-029` confirmam limitações/antecedentes observados | Teste próprio com candidatos opacos, permutação e zero efeito externo | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-006 | `03-ptbr-target-architecture.md`: abstinência/fallback explícito | Não há contrato público positivo confirmado; decisão própria | Oráculos estruturais distinguem coleção vazia, insuficiência, ambiguidade e abstinência | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-007 | `06-roadmap.md`: casos negativos por camada | `E-030` confirma ausência de suíte pública; `E-032` registra inconsistência documental | Matriz própria de malformado, incompatível, fora de escopo e insuficiente, sem frases | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-008 | `03-ptbr-target-architecture.md`: testes multi-intent | `E-027` confirma colapso observado para um intent por frase | Fixture estrutural com identidades opacas, dependências e conflitos; nenhum intent de produção criado | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-009 | `03-ptbr-target-architecture.md` e `06-roadmap.md`: testes stateful de sessão | `E-030` não confirma sessão pública | Máquina de estados própria com relógio controlado e sessões opacas | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-010 | `03-ptbr-target-architecture.md`: núcleo sem credenciais/rede/execução | `E-035` documenta interface local e `E-037` ausência de adaptador público | Teste de isolamento por rede bloqueada, espião e inspeção de credenciais, sem protocolo copiado | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-011 | `03-ptbr-target-architecture.md`: erros controlados do adaptador | `E-037` confirma que integração não estava presente nos artefatos públicos | Dublê próprio cobre sucesso, recusa, falha, indisponibilidade e correlação | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-012 | `03-ptbr-target-architecture.md`: política negativa e validação de domínio/serviço/entidade/parâmetros | `E-037` não fornece implementação | Mutações estruturais opacas testam fail-closed sem criar nomes ou parâmetros reais | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-013 | Regras atuais do usuário, `AGENTS.md` e `04-data-provenance-policy.md`: rejeição de metadado aplicável ausente | `E-006/E-007/E-033/E-036` demonstram risco de licença; `E-013/E-014` artefatos observados | Validação negativa separa Perfil L e Perfil O: exige metadados linguísticos completos no primeiro e somente metadados operacionais aplicáveis no segundo, sem fabricar campos | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-014 | `03-ptbr-target-architecture.md`, `04-data-provenance-policy.md`, `06-roadmap.md`: rebuild e hashes | `E-030` não confirma compilador público; `E-013/E-014` confirmam artefato/metadados | Rebuild próprio em ambientes limpos, corrupção e incompatibilidade, sem formato observado | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-015 | `04-data-provenance-policy.md`: remoção de fonte e impacto downstream | Não há função de remoção confirmada na origem | Grafo estrutural opaco verifica remoção transitiva e invalidação | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-016 | `06-roadmap.md`: benchmarks controlados e metas futuras | `E-008` registra métricas sem proveniência; `E-030` ausência de benchmark público | Método próprio de baseline; todos os números do produto foram excluídos | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-017 | `04-data-provenance-policy.md`: separação e prevenção de vazamento | Não há conjuntos confirmados para reutilizar | Auditoria própria de hashes, linhagem, derivados e acesso, sem corpus criado | ESPECIFICADO / EXECUÇÃO FUTURA |
| TEST-018 | regras da Fase 2, `ADR-0001` e `00-evidence-register.md`: handoff isolado e verificável | `E-001/E-002` registram ausência inicial de Git/código; `E-006/E-007/E-033/E-036` sustentam cautela clean-room | Teste documental próprio de IDs, critérios, manifest, hashes, termos proibidos, código e dados | ESPECIFICADO / VERIFICADO NA FASE 2 |

## Origem das decisões pendentes

Os itens abaixo não são requisitos e não entram na contagem de 99. Eles registram escolhas que os documentos da Fase 1 deixaram propostas, desconhecidas ou dependentes de evidência futura.

| Pendência | Origem na Fase 1 | Por que permaneceu aberta | Situação |
| --- | --- | --- | --- |
| OPEN-001 | `03-ptbr-target-architecture.md` e `06-roadmap.md`, fase de schemas | Nenhum catálogo mínimo de intents/slots Home Assistant foi aprovado e não se pode inventar vocabulário/casos | PENDENTE |
| OPEN-002 | `02-english-coupling.md`, `03-ptbr-target-architecture.md`, `06-roadmap.md` | `E-017` prova o risco, mas não escolhe política Unicode para o novo produto | PENDENTE — bloqueio imediato |
| OPEN-003 | `03-ptbr-target-architecture.md` e `06-roadmap.md` | offsets são obrigatórios, porém unidade, origem e intervalos não foram decididos | PENDENTE — bloqueio imediato |
| OPEN-004 | `02-english-coupling.md`, `05-port-gap-analysis.md`, `06-roadmap.md` | `E-020/E-022/E-023` mostram que a taxonomia observada é inadequada; nenhuma nova foi aprovada | PENDENTE |
| OPEN-005 | `03-ptbr-target-architecture.md` e `06-roadmap.md` | alternativas e determinismo foram aprovados, não a estratégia de desempate | PENDENTE |
| OPEN-006 | `03-ptbr-target-architecture.md` e `05-port-gap-analysis.md` | `E-023` confirma abordagem inglesa observada; inclusão/política própria não foi aprovada | PENDENTE |
| OPEN-007 | `03-ptbr-target-architecture.md` e `06-roadmap.md` | não há escala, calibração, semântica de score ou empate aprovada | PENDENTE |
| OPEN-008 | `03-ptbr-target-architecture.md` e `06-roadmap.md` | multi-intent foi aprovado como capacidade, mas atomicidade/parcialidade não | PENDENTE |
| OPEN-009 | `03-ptbr-target-architecture.md`, `04-data-provenance-policy.md`, `06-roadmap.md` | identidade, precedência de aliases e vigência do catálogo Home Assistant não foram definidas | PENDENTE |
| OPEN-010 | `03-ptbr-target-architecture.md` e `06-roadmap.md` | sessão é decisão própria; armazenamento, duração, expiração e concorrência faltam | PENDENTE |
| OPEN-011 | `03-ptbr-target-architecture.md` | confirmação é mandatória quando aplicável, mas ações sensíveis e autoridade não foram classificadas | PENDENTE |
| OPEN-012 | `03-ptbr-target-architecture.md` e `06-roadmap.md` | a semântica é própria; transporte, serialização e autenticação não podem ser copiados de `E-035` | PENDENTE |
| OPEN-013 | `03-ptbr-target-architecture.md` | versionamento é obrigatório, mas regra de compatibilidade/negociação não foi aprovada | PENDENTE |
| OPEN-014 | `06-roadmap.md`; limitação de ambiente em `E-038` | nenhuma plataforma-alvo foi explicitamente aprovada | PENDENTE — bloqueio imediato |
| OPEN-015 | `03-ptbr-target-architecture.md` e `06-roadmap.md` | não existe baseline que sustente limites de recursos ou cardinalidade | PENDENTE |
| OPEN-016 | `04-data-provenance-policy.md` e `06-roadmap.md` | classes/regras foram aprovadas, mas nenhuma fonte ou licença concreta | PENDENTE |
| OPEN-017 | `04-data-provenance-policy.md` e `06-roadmap.md` | separação foi aprovada, mas particionamento, custódia e acesso não | PENDENTE |
| OPEN-018 | `06-roadmap.md`; divergência de métricas em `E-008` e ausência de bench em `E-030` | alvo só pode nascer de baseline reproduzível próprio | PENDENTE |
| OPEN-019 | `03-ptbr-target-architecture.md` | minimização foi aprovada, mas retenção, armazenamento e papéis de acesso não | PENDENTE |
| OPEN-020 | `03-ptbr-target-architecture.md`; ausência pública em `E-030` | resposta textual é requisito, mas conteúdo e governança são dados futuros | PENDENTE |
| OPEN-021 | `03-ptbr-target-architecture.md` e revisão integrada das fronteiras `API/SEC` | processos e menor privilégio foram aprovados, mas identidade, autenticação e autorização dos clientes e processos não possuem solução confirmada na origem nem decisão própria aprovada | PENDENTE |
| OPEN-022 | `03-ptbr-target-architecture.md` e regras atuais do `AGENTS.md` sobre confinamento de credenciais | `E-037` não oferece integração reutilizável; armazenamento, provisão, rotação e revogação de credenciais não foram definidos | PENDENTE |
| OPEN-023 | `03-ptbr-target-architecture.md`, `06-roadmap.md` e revisão de `SEC-013` | correlação e resultado indeterminado são necessários, mas idempotência, retry, reconciliação, compensação e transações não possuem política aprovada | PENDENTE |
| OPEN-024 | `03-ptbr-target-architecture.md` e revisão integrada de `API-013`, observabilidade e segurança | erros tipados e sanitização foram aprovados, mas códigos, correlação concreta e divulgação por classe de consumidor não foram definidos | PENDENTE |
| OPEN-025 | Regras atuais do usuário e `AGENTS.md`; `04-data-provenance-policy.md` como contexto | não há algoritmo de deduplicação confirmado ou autorizado; equivalência e conflito variam por classe | PENDENTE |
| OPEN-026 | Regras atuais do usuário, `06-roadmap.md` e ausência de baseline em `E-030` | qualidade e cobertura devem ser medidas, mas não há catálogo fechado, conjunto aprovado ou baseline que sustente uma meta | PENDENTE |

## Correções de consistência rastreadas

| Tema | Requisitos e contratos alinhados | Transformação confirmada |
| --- | --- | --- |
| Autoria da proposta | `FR-021`, modelo, pipeline, `API-009`, `SEC-001`, `TEST-010` | O núcleo termina no Resultado de Interpretação; gestão de diálogo/política cria eventual Proposta de Execução; o adaptador a revalida. |
| Zero hipóteses versus abstinência | `FR-009`, modelo, pipeline, `API-002`, `TEST-006` | Cardinalidade e situação global são ortogonais; coleção vazia não recebe classificação automática. |
| Aplicabilidade de dados | `DATA-001`, `DATA-002..DATA-016`, `TEST-013` | Perfil L recebe governança linguística completa; Perfil O recebe metadados operacionais aplicáveis e só entra no Perfil L por nova admissão integral. |
| Cobertura não funcional | `NFR-001..NFR-012`, matriz de `09-acceptance-test-plan.md`, `TEST-001` | Cada NFR tem linha explícita de cobertura planejada, sem transformar a matriz resumida em nova definição normativa. |
| Gestão de diálogo | `FR-017..FR-021`, modelo, pipeline, `API-005..API-009` | Sessão, esclarecimento e preparação da proposta permanecem fora do núcleo de interpretação e atravessam contratos explícitos. |

## Conferência de cobertura

| Prefixo | Intervalo rastreado | Quantidade |
| --- | --- | ---: |
| FR | `FR-001..FR-026` | 26 |
| NFR | `NFR-001..NFR-012` | 12 |
| API | `API-001..API-013` | 13 |
| SEC | `SEC-001..SEC-014` | 14 |
| DATA | `DATA-001..DATA-016` | 16 |
| TEST | `TEST-001..TEST-018` | 18 |

Total rastreado: **99 requisitos**, cada um em linha individual.

As matrizes de cobertura e as referências cruzadas dos demais documentos não são novas definições. A conferência estrutural usa as seis tabelas normativas como fonte canônica e distingue suas 99 linhas de definição das citações de rastreabilidade.

As decisões `OPEN-001..OPEN-026` foram rastreadas separadamente e permanecem fora dessa contagem. Somente `OPEN-002`, `OPEN-003` e `OPEN-014` são bloqueios imediatos da futura fundação.

## Observação de domínio permitido

O nome **Home Assistant** foi mantido no handoff por ser o domínio-alvo explicitamente aprovado. Isso não constitui transporte de detalhe do produto analisado: `E-037` confirma justamente que os artefatos públicos inspecionados não continham adaptador Home Assistant. O handoff preserva apenas a fronteira própria do novo produto, sem endpoint, protocolo, inventário, credencial, serviço ou parâmetro concreto.
