# Contratos externos conceituais

Data: 2026-08-12

Status: especificação clean-room aprovada no nível conceitual

## Classificação normativa

### CONTRATOS APROVADOS

- Os contratos deste documento definem comportamento observável nas fronteiras do sistema.
- Cada resultado deve ser tipado e correlacionável com a solicitação que o originou.
- Abstinência é um resultado de domínio válido: não deve ser convertida em hipótese, ação ou sucesso presumido.
- Uma falha de contrato deve ser distinguível de um resultado válido sem hipóteses.
- Propostas de Execução não são autorizações nem evidência de que ocorreu um efeito externo.
- Referências a sessão, catálogo, versão e capacidades devem ser explícitas sempre que afetarem o significado do resultado.

Somente as linhas `API-001` a `API-013` da tabela de contratos são requisitos independentes contados e testados como unidades próprias. O modelo estrutural, os exemplos e as invariantes deste documento elaboram esses IDs e outros IDs canônicos do pacote; não criam requisitos autônomos.

Os nomes de campos usados abaixo são apenas rótulos conceituais. Eles não prescrevem protocolo, serialização, transporte, linguagem de programação nem formato de armazenamento.

### DECISÃO PENDENTE

- `OPEN-012` — transporte, serialização, isolamento e caráter síncrono, assíncrono ou consultável dos contratos;
- `OPEN-021` — identidade, autenticação e autorização dos clientes e processos participantes;
- `OPEN-024` — formato de correlação, taxonomia concreta de erros, códigos e subcódigos e divulgação segura de diagnósticos;
- `OPEN-013` — regras de compatibilidade entre versões e negociação de capacidades;
- `OPEN-007` — forma de expressar pontuação, ordenação, empates e eventuais limiares de decisão;
- `OPEN-010` — identidade, persistência, concorrência, expiração e retenção de sessões;
- `OPEN-009` — identidade, atualização, integridade, retenção e política de atualidade dos catálogos;
- `OPEN-020` — formato, governança e localização das respostas apresentadas ao cliente;
- `OPEN-015` — limites de tamanho, tempo, tentativas e recursos.

Nenhuma decisão pendente pode ser inferida a partir dos exemplos estruturais deste documento.

## Modelo estrutural mínimo

Sem representar uma mensagem em nível de transporte:

- solicitação de interpretação = conteúdo do turno + contexto permitido + referência opcional de sessão + referência opcional de catálogo;
- resultado de interpretação = situação global tipada + coleção com zero, uma ou várias hipóteses; uma falha de interpretação controladamente representável ocupa a situação global do mesmo envelope e permanece distinta das situações de domínio;
- pedido de esclarecimento = Resultado de Interpretação + estado de sessão aplicável → gestor de diálogo e política → Pedido de Esclarecimento externo;
- continuidade = resposta de esclarecimento + referência ao estado pendente;
- fronteira de efeito = Resultado de Interpretação → gestor de diálogo e política → Proposta de Execução validável → adaptador Home Assistant → Resultado de Execução observado;
- apresentação = resultado de domínio + metadados seguros → resposta final.

## Contratos

| ID | Contrato conceitual | Entrada e saída conceituais | Requisito observável — REQUISITO APROVADO | Falha ou abstinência segura — REQUISITO APROVADO | Critério de aceite — REQUISITO APROVADO |
| --- | --- | --- | --- | --- | --- |
| API-001 | Solicitar interpretação | Entrada: conteúdo do turno, contexto permitido e referências aplicáveis. Saída: exatamente API-002, API-003, API-004, API-005 ou API-013. | A resposta preserva correlação com a solicitação e declara as versões de artefatos, sessão e catálogo que influenciaram o resultado. Sob as mesmas entradas e o mesmo estado referenciado, o resultado semântico é determinístico. | Entrada ausente, malformada, incompatível ou não suportada produz API-013. Conteúdo não interpretável produz API-002; nunca uma intenção ou ação sintética. | Testes de contrato demonstram exclusividade da classe de saída, correlação, rastreabilidade das versões e equivalência semântica em repetições com estado idêntico. |
| API-002 | Responder com zero hipóteses | Entrada: conclusão válida da interpretação com coleção vazia. Saída: coleção vazia, situação global tipada e motivo quando aplicável. | Cardinalidade e situação global são dimensões ortogonais: zero hipóteses não significa automaticamente abstinência. O cliente consegue distinguir ausência de interpretação suportada, fora de escopo, insuficiência e abstinência conforme as categorias canônicas aplicáveis. O resultado não contém Proposta de Execução. | A situação global correspondente à causa é preservada sem fabricar hipótese, ação padrão ou sucesso. Falha de contrato ou falha técnica permanece distinguível e não é convertida em cardinalidade zero. | Fixtures de situações globais distintas com cardinalidade zero preservam suas categorias e motivos, sem hipótese e sem passagem à fronteira de execução. |
| API-003 | Responder com uma hipótese | Entrada: conclusão válida com uma hipótese. Saída: uma hipótese tipada, seus slots resolvidos ou pendentes e sua proveniência decisória. | A cardinalidade é exatamente uma; slots ausentes, ambíguos ou não resolvidos são marcados, não preenchidos por suposição. | Se a hipótese não puder ser sustentada ou estiver incompleta para o próximo passo, o sistema retorna API-002, API-005 ou API-013 conforme a natureza do caso; não promove incerteza a certeza. | Fixtures de hipótese única confirmam cardinalidade, marcação de slots pendentes e ausência de valores fabricados. |
| API-004 | Responder com várias hipóteses | Entrada: conclusão válida com mais de uma hipótese. Saída: coleção não vazia com pluralidade explícita e relações de conflito ou composição quando conhecidas. | Todos os candidatos preservados são observáveis; eventual ordenação é determinística e sua base é versionada. A resposta não oculta uma escolha como se fosse única. | Quando a pluralidade impedir uma decisão segura, o sistema solicita esclarecimento ou se abstém. Nenhuma alternativa é executada apenas por ocupar a primeira posição. | Fixtures ambíguas e compostas demonstram preservação dos candidatos, ordenação reproduzível e bloqueio de execução quando não há decisão segura. |
| API-005 | Solicitar esclarecimento | Entrada: hipótese ou estado cuja continuação depende de informação adicional. Saída: referência ao estado pendente, dimensão a resolver e opções tipadas quando existirem. | A solicitação identifica somente a lacuna necessária e fica vinculada à sessão, ao turno e às versões relevantes. Opções apresentadas correspondem aos candidatos efetivamente disponíveis. | Se não houver base segura para formular esclarecimento, o sistema se abstém. Se o estado necessário não puder ser preservado, retorna erro tipado sem abrir uma continuidade órfã. | Testes confirmam que a referência recupera apenas o estado correspondente, que as opções não introduzem candidatos e que nenhuma ação é proposta antes da resolução exigida. |
| API-006 | Receber resposta de esclarecimento | Entrada: referência ao esclarecimento pendente e resposta estruturada do cliente. Saída: API-002, API-003, API-004, novo API-005 ou API-013. | A resposta é aplicada somente ao estado ao qual está vinculada; a transição resultante é correlacionável e não altera sessões ou turnos alheios. | Referência ausente, incompatível, encerrada ou conflitante não é incorporada silenciosamente. O sistema se abstém ou retorna erro tipado, sem recuperar contexto de outra sessão. | Testes de continuidade válida, referência trocada e resposta incompatível demonstram transição correta, isolamento e ausência de efeitos externos prematuros. |
| API-007 | Gerir sessão | Entrada: operação conceitual de iniciar, consultar, continuar ou encerrar e a referência de estado aplicável. Saída: referência e estado público mínimo da sessão. | Mudanças de sessão são explícitas, ordenáveis e isoladas por identidade de sessão. O cliente consegue detectar conflito entre o estado esperado e o estado corrente. | Estado ausente, encerrado ou conflitante não é recriado nem sobrescrito de forma silenciosa; a operação falha de modo tipado ou inicia novo contexto somente por solicitação explícita. | Testes com sessões intercaladas, continuidade concorrente e encerramento comprovam isolamento, detecção de conflito e impossibilidade de reutilização implícita. |
| API-008 | Publicar snapshot do catálogo do Home Assistant | Entrada: snapshot imutável com identidade, versão, proveniência, integridade e elementos tipados. Saída: aceite ou rejeição e referência ao snapshot aceito. | Cada interpretação ou Proposta de Execução dependente do catálogo aponta para um snapshot específico. Substituir o snapshot corrente não modifica resultados históricos nem o conteúdo do snapshot anterior. | Snapshot incompleto, inconsistente, incompatível ou sem proveniência verificável é rejeitado integralmente. Na ausência de snapshot aceitável, o sistema se abstém das resoluções que dele dependem. | Testes de publicação, rejeição e substituição demonstram atomicidade, imutabilidade, rastreabilidade e ausência de mistura entre versões. |
| API-009 | Entregar Proposta de Execução ao adaptador Home Assistant | Entrada: Proposta de Execução imutável, preparada pelo gestor de diálogo e política a partir de um Resultado de Interpretação correlacionado, com operações tipadas, alvos, parâmetros e referências aplicáveis. Saída: aceite para revalidação pelo adaptador ou rejeição tipada. | O núcleo produz somente o Resultado de Interpretação e nunca a Proposta de Execução. A Proposta de Execução descreve intenção de efeito, mas não declara autorização nem sucesso; cada operação mantém correlação com o resultado que a fundamenta e contém informação suficiente para revalidação independente. | Proposta de Execução atribuída diretamente ao núcleo, sem Resultado de Interpretação correlacionado, incompleta, ambígua, incompatível, alterada ou sem evidência requerida é rejeitada sem efeito. | Testes provam a cadeia Resultado de Interpretação → gestor de diálogo e política → Proposta de Execução → adaptador, que receber a Proposta de Execução não executa por si só e que mudanças em alvo ou parâmetro invalidam a proposta correspondente. |
| API-010 | Informar Resultado de Execução | Entrada: observação do adaptador Home Assistant para uma Proposta de Execução aceita. Saída: resultado global e por operação, com estados tipados e diagnóstico seguro. | O Resultado de Execução distingue efeito confirmado, rejeição, ausência de execução, resultado indeterminado e execução parcial quando aplicável. Ele preserva correlação com a Proposta de Execução e não fabrica sucesso. | Falha, interrupção ou resposta inconclusiva do Home Assistant é representada como tal. O sistema não converte ausência de confirmação em êxito e não oculta resultados parciais. | Simulações de aceite, rejeição, interrupção e resultado parcial confirmam o mapeamento correto, a correlação e a impossibilidade de emitir sucesso sem observação correspondente. |
| API-011 | Produzir resposta final | Entrada: resultado de interpretação, esclarecimento ou execução e metadados permitidos. Saída: resposta apresentável, classe de resultado e correlação. | A classe comunicada corresponde ao estado real: abstinência, esclarecimento, rejeição, falha, resultado indeterminado ou sucesso. Diagnósticos internos e dados sensíveis não atravessam essa fronteira. | Falha de apresentação gera resposta mínima segura da mesma classe ou erro tipado; jamais transforma falha ou incerteza em confirmação de efeito. | Testes de correspondência percorrem todas as classes de resultado e verificam consistência semântica, correlação e ausência de segredos ou detalhes internos. |
| API-012 | Consultar versão e capacidades | Entrada: consulta de compatibilidade ou conjunto de capacidades requerido. Saída: versões dos contratos e artefatos relevantes, capacidades suportadas e incompatibilidades detectadas. | O cliente consegue decidir compatibilidade antes de depender de uma capacidade. Capacidades ausentes são declaradas, não simuladas, e qualquer negociação preserva o significado do contrato. | Versão ou capacidade incompatível gera rejeição tipada. Não há rebaixamento silencioso que altere cardinalidade, segurança ou semântica. | Testes com combinações compatíveis e incompatíveis demonstram declaração completa, rejeição explícita e ausência de degradação sem consentimento. |
| API-013 | Representar erros de contrato | Entrada: falha detectada em qualquer fronteira, inclusive rejeição anterior à admissão no núcleo, impossibilidade de produzir seu envelope ou Resultado de Interpretação cuja situação global seja falha técnica. Saída: categoria estável, estágio, correlação, condição de possibilidade de nova tentativa e detalhes seguros quando disponíveis. | O núcleo continua emitindo somente Resultado de Interpretação quando consegue representar controladamente sua conclusão; API-013 é a representação externa uniforme da falha, não um segundo tipo de saída semântica do núcleo. Erros são distinguíveis de abstinência e de resultados de domínio. A representação é consistente entre contratos e não expõe credenciais, conteúdo protegido, rastros internos ou detalhes desnecessários. | Se a própria produção do Resultado de Interpretação ou da representação externa falhar, a fronteira retorna a forma mínima segura e não continua para execução. Possibilidade de nova tentativa não implica repetição automática. | Testes negativos e de robustez verificam classificação estável, correlação, sanitização, nenhuma ação subsequente, distinção inequívoca entre erro e API-002 e autoria correta do Resultado de Interpretação pelo núcleo e de API-013 pela fronteira externa. |

## Exemplos estruturais mínimos

Os exemplos abaixo ilustram cardinalidade e correlação, não prescrevem campos, serialização ou conteúdo linguístico:

- **FIXTURE TÉCNICA, NÃO DADO LINGUÍSTICO** — uma solicitação opaca identificada por `req-01` termina em API-002 com coleção de hipóteses vazia, situação global opaca `sit-01` e motivo aplicável; o exemplo não classifica a situação como abstinência.
- **FIXTURE TÉCNICA, NÃO DADO LINGUÍSTICO** — uma solicitação opaca `req-02` termina em API-004 com as hipóteses opacas `hyp-01` e `hyp-02`; nenhuma é selecionada apenas pela posição.
- **FIXTURE TÉCNICA, NÃO DADO LINGUÍSTICO** — API-005 cria a pendência opaca `clr-01` na sessão `ses-01`; API-006 só pode responder a essa pendência mediante as mesmas referências válidas.
- **FIXTURE TÉCNICA, NÃO DADO LINGUÍSTICO** — a Proposta de Execução opaca `act-01` referencia o snapshot `cat-01`; um Resultado de Execução relativo a outra Proposta de Execução ou a outro snapshot é rejeitado por correlação incompatível.

## Invariantes entre contratos

### CONTRATOS APROVADOS

- API-001 termina em uma única classe de resultado observável.
- API-002 nunca conduz diretamente a API-009.
- API-005 somente pode ser retomada por API-006 com vínculo de estado válido.
- API-008 fornece contexto descritivo; não concede autorização.
- API-009 inicia validação na fronteira de execução; não comprova efeito.
- Somente API-010 pode fornecer a observação usada para comunicar efeito externo em API-011.
- API-013 interrompe o fluxo afetado, salvo nova operação explícita prevista pelo contrato.

### DECISÃO PENDENTE

- `OPEN-012` — quais resultados serão síncronos, assíncronos ou consultáveis posteriormente;
- `OPEN-008` e `OPEN-023` — como representar operações compostas, atomicidade, execução parcial, transações e compensações;
- `OPEN-013` — se haverá negociação de capacidades ou apenas recusa por incompatibilidade;
- `OPEN-019` e `OPEN-024` — quais diagnósticos seguros serão registrados e expostos a cada classe de cliente.
