# Roadmap Incremental

Data do roadmap: 2026-08-12

Observação:

- a fase atual de auditoria/documentação precede as fases de entrega abaixo;
- a numeração a seguir é o roadmap de implementação, não a fase já executada nesta auditoria.

## Fase 1. Baseline reproduzível do sistema atual

- Objetivo: congelar o baseline público realmente auditado e registrar o que é reproduzível.
- Entradas: artefatos desta auditoria, URLs oficiais, checksums do `crates.io`, dúvidas legais abertas.
- Alterações permitidas: documentação, tooling de inspeção, manifesto de baseline, nenhum port PT-BR.
- Entregáveis: manifesto de artefatos, checklist legal preliminar, instruções de reprodução estática.
- Testes: conferência de checksum, presença de arquivos, consistência dos metadados.
- Critérios objetivos de aceite: cada artefato público referenciado possui origem, versão, checksum e licença registradas.
- Bloqueios: origem oficial indisponível, checksum divergente, licença inconclusiva.
- Condições para não avançar: qualquer artefato central sem proveniência ou com licença incerta para o uso pretendido.

## Fase 2. Fundação multilíngue e Unicode

- Objetivo: estabelecer contratos de normalização e tokenização independentes do inglês.
- Entradas: ADRs, política de dados, inventário de acoplamento ao inglês.
- Alterações permitidas: somente camadas de infraestrutura textual e testes correlatos.
- Entregáveis: normalizador Unicode, contrato de offsets, config de idioma, tokenizer base.
- Testes: round-trip, offsets, diacríticos, pontuação, entradas STT ruidosas.
- Critérios objetivos de aceite: nenhum caractere PT-BR válido é descartado silenciosamente; offsets permanecem rastreáveis.
- Bloqueios: ausência de política Unicode ou contrato de spans.
- Condições para não avançar: se ainda existir descarte ASCII-style ou se a tokenização não for reproduzível.

## Fase 3. Auditoria e seleção das fontes linguísticas

- Objetivo: selecionar fontes lícitas e rastreáveis para PT-BR.
- Entradas: política de proveniência, requisitos linguísticos, lista de riscos PT-BR.
- Alterações permitidas: documentação, manifestos de fontes, scripts de validação de licença.
- Entregáveis: catálogo de fontes candidatas, parecer técnico de compatibilidade, matriz de risco por fonte.
- Testes: verificação de licença, hash, disponibilidade e formato.
- Critérios objetivos de aceite: nenhuma fonte aprovada sem licença, versão, hash e classe de uso registrada.
- Bloqueios: fonte desejada sem licença clara, dataset inacessível ou termos incompatíveis.
- Condições para não avançar: se qualquer fonte crítica ainda estiver em `DESCONHECIDO`.

## Fase 4. Pipeline de importação lexical

- Objetivo: criar compilador offline reproduzível para artefatos lexicais.
- Entradas: fontes aprovadas, política de proveniência, schema de artefato.
- Alterações permitidas: compilador offline, manifestos, validações, sem runtime semântico ainda.
- Entregáveis: importadores, deduplicação, hashing, manifesto de build.
- Testes: rebuild idempotente, hashes estáveis, rejeição de entrada sem origem.
- Critérios objetivos de aceite: duas execuções com a mesma entrada geram hashes idênticos.
- Bloqueios: fontes heterogêneas sem mapeamento de schema, dados sem licença.
- Condições para não avançar: se o artefato compilado não puder ser reconstruído bit a bit ou com hash semanticamente estável.

## Fase 5. Tokenização e morfologia PT-BR

- Objetivo: produzir análise lexical e morfológica utilizável para comando em PT-BR.
- Entradas: artefatos lexicais, contratos Unicode, casos de teste.
- Alterações permitidas: tokenizer PT-BR, analisador morfológico, testes dessa camada.
- Entregáveis: segmentador PT-BR, análise de flexão, suporte a contrações controladas.
- Testes: goldens morfológicos, frases telegráficas, contrações e nomes próprios.
- Critérios objetivos de aceite: comandos-alvo cobrem diacríticos, flexão básica e contrações sem regra inventada fora das fontes aprovadas.
- Bloqueios: léxico insuficiente, ambiguidades sem representação.
- Condições para não avançar: se ainda houver perda de informação morfológica essencial ou regras ad hoc sem fonte.

## Fase 6. POS tagging

- Objetivo: etiquetar tokens PT-BR de forma determinística e auditável.
- Entradas: morfologia PT-BR, fontes rotuladas aprovadas, contrato de tagset.
- Alterações permitidas: tagset, modelos POS, features, testes POS.
- Entregáveis: tagger PT-BR, explicabilidade mínima, harness de avaliação POS.
- Testes: accuracy estratificada, ambiguidades comuns, OOVs controlados.
- Critérios objetivos de aceite: baseline POS definido e reexecutável; erros conhecidos documentados.
- Bloqueios: falta de dados rotulados ou tagset indefinido.
- Condições para não avançar: se o tagger não expuser decisões reprodutíveis ou se o tagset estiver mudando junto com outras camadas.

## Fase 7. Schemas de intents do Home Assistant

- Objetivo: definir intents e slots declarativos sem executar ações.
- Entradas: requisitos de automação residencial, catálogo conceitual do HA, IR proposta.
- Alterações permitidas: schemas declarativos, compilador de schema, fixtures.
- Entregáveis: schemas de intents, validador, exemplos de IR.
- Testes: validação de schema, snapshots de parsing, casos negativos.
- Critérios objetivos de aceite: cada intent possui slots, constraints e exemplos auditáveis.
- Bloqueios: IR instável, falta de política de segurança.
- Condições para não avançar: se intents ainda dependerem de lógica embutida não declarativa.

## Fase 8. Resolução de entidades

- Objetivo: resolver dispositivos, áreas, andares, cenas e scripts sem executar HA ainda.
- Entradas: schemas, catálogo de entidade modelado, política de aliases.
- Alterações permitidas: resolvedor, índices, fixtures de inventário.
- Entregáveis: resolvedor determinístico, representação de ambiguidades, regras de alias.
- Testes: fixtures sintéticas aprovadas e dumps controlados de inventário real com hash.
- Critérios objetivos de aceite: ambiguidades são detectadas explicitamente; nenhuma ação é inferida silenciosamente.
- Bloqueios: inventário sem normalização, aliases sem política.
- Condições para não avançar: se o resolvedor “adivinhar” entidade sem evidência textual rastreável.

## Fase 9. Múltiplos intents e correferência

- Objetivo: suportar múltiplos intents por sentença e referências internas entre menções.
- Entradas: IR, tagger, resolvedor de entidades.
- Alterações permitidas: coordenador de intents, correferência, testes correspondentes.
- Entregáveis: IR multi-intent, resolvedor de anáfora de curto alcance, conflitos tipados.
- Testes: comandos compostos, elipses controladas, referências pronominais.
- Critérios objetivos de aceite: o sistema representa intent principal e secundários separadamente e não perde rastreabilidade.
- Bloqueios: IR monolítica ou sessões instáveis.
- Condições para não avançar: se múltiplos intents forem apenas “flattened” num único frame.

## Fase 10. Sessão e esclarecimentos

- Objetivo: manter estado curto e produzir perguntas de clarificação determinísticas.
- Entradas: multi-intent, entidades, política de segurança.
- Alterações permitidas: somente camada de sessão, persistência curta e response planning.
- Entregáveis: session manager, slots pendentes, prompts de clarificação tipados.
- Testes: diálogos curtos, expiração, reset, ambiguidades frequentes.
- Critérios objetivos de aceite: o sistema nunca executa ação quando deveria pedir clarificação.
- Bloqueios: ausência de política de segurança ou de semântica de estado.
- Condições para não avançar: se a sessão modificar interpretação linguística sem trilha de decisão.

## Fase 11. Protocolo e integração

- Objetivo: expor API local e integrar com Home Assistant por adaptador separado.
- Entradas: runtime NLU estável, session manager, schemas aprovados.
- Alterações permitidas: protocolo local, adaptador HA, validações de domínio/serviço.
- Entregáveis: contrato de API, adaptador HA, política de credenciais, mapeamento de erros.
- Testes: contract tests, testes de segurança, fixtures HA.
- Critérios objetivos de aceite: o runtime NLU opera sem credenciais e o adaptador rejeita chamadas inválidas.
- Bloqueios: IR instável ou inventário HA não controlado.
- Condições para não avançar: se o processo NLU precisar chamar serviços externos diretamente.

## Fase 12. Avaliação, otimização e empacotamento

- Objetivo: medir qualidade, custo computacional e preparar distribuição.
- Entradas: sistema integrado, conjuntos de validação e hidden eval, metas de performance.
- Alterações permitidas: otimização, observabilidade, empacotamento, documentação final.
- Entregáveis: benchmark suite, perfil de memória/CPU, pacote distribuível, guia operacional.
- Testes: regressão completa, hidden evaluation, benchmarks offline, soak tests locais.
- Critérios objetivos de aceite: resultados reproduzíveis, orçamento de CPU/memória dentro da meta e pacote sem dependência de corpora não aprovados.
- Bloqueios: regressões não explicadas, licenças pendentes, métricas instáveis.
- Condições para não avançar: se a distribuição ainda depender de fonte legalmente não resolvida ou de dados sem proveniência.

## Regras transversais do roadmap

### DECISÃO PROPOSTA

- não alterar mais de uma camada linguística principal por fase;
- cada fase deve ter harness de teste próprio antes da próxima;
- toda decisão arquitetural relevante gera ADR;
- nenhuma fase posterior começa com dúvidas jurídicas críticas em aberto;
- qualquer desvio da política de proveniência bloqueia a entrega.
