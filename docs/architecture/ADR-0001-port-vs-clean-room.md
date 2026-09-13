# ADR-0001: Port Direto vs Clean-Room

Status: aceito

Data: 2026-08-12

## Contexto

O objetivo futuro é um motor NLU determinístico em PT-BR, distribuível e potencialmente comercializável, inicialmente voltado a comandos para Home Assistant.

Evidências relevantes:

- o workspace local não contém o motor nem checkout do repositório original `[E-001] [E-002]`;
- o artefato público mais recente `cicero-sophia 0.6.5` usa `PolyForm-Noncommercial-1.0.0` `[E-004] [E-006]`;
- o histórico de versões mostra mudanças de licença ao longo de 2025 `[E-007]`;
- o crate `sophia-interfaces 0.6.0` está sob `GPL-3.0` `[E-033]`;
- o código público inspecionado está fortemente acoplado ao inglês `[E-017] [E-018] [E-019] [E-020] [E-022] [E-023]`.

## Drivers de decisão

1. viabilidade legal para distribuição comercial;
2. risco de acoplamento estrutural ao inglês;
3. mantenabilidade de longo prazo;
4. previsibilidade de performance;
5. esforço de migração;
6. auditabilidade e reprodutibilidade.

## Opções avaliadas

### Opção A. Port direto do núcleo atual

Descrição:

- tomar o núcleo público como base principal e adaptá-lo para PT-BR.

### Opção B. Fork não comercial

Descrição:

- derivar de versões ou componentes source-available / não comerciais para uso interno ou não comercial.

### Opção C. Reimplementação clean-room

Descrição:

- usar apenas a arquitetura documentada e evidências públicas como referência de requisitos, sem copiar código.

### Opção D. Arquitetura híbrida

Descrição:

- clean-room nas camadas linguísticas e de runtime; possível reaproveitamento apenas de formatos, ideias ou futuros componentes cuja licença comercial permissiva venha a ser comprovada.

## Comparação

| Critério | Port direto | Fork não comercial | Clean-room | Híbrida |
| --- | --- | --- | --- | --- |
| compatibilidade com distribuição comercial | Fraca | Muito fraca | Forte | Média a forte |
| risco jurídico atual | Alto | Muito alto | Mais baixo | Médio |
| risco de arrastar acoplamento ao inglês | Muito alto | Muito alto | Baixo | Médio |
| velocidade inicial | Alta aparente | Alta aparente | Média | Média |
| custo de manutenção futura | Alto | Alto | Médio | Médio |
| previsibilidade de performance | Média | Média | Média a alta | Média a alta |
| auditabilidade da origem | Fraca | Fraca | Forte | Média |
| adequação ao roadmap PT-BR | Fraca | Fraca | Forte | Forte |

## Análise por opção

### A. Port direto

Pontos favoráveis:

- aproveitaria rapidamente estruturas já existentes como HMM, `Token`, `Phrase` e carga de artefatos.

Pontos contrários:

- licença atual do artefato público mais recente é não comercial `[E-006]`;
- o repositório referenciado não pôde ser confirmado publicamente nesta fase `[E-009]`;
- o código público atual remove não ASCII e embute muitas listas e heurísticas inglesas `[E-017] [E-019] [E-022] [E-023]`.

Conclusão:

- tecnicamente possível em tese;
- juridicamente e arquiteturalmente inadequado como recomendação principal nesta fase.

### B. Fork não comercial

Pontos favoráveis:

- menor esforço inicial aparente.

Pontos contrários:

- incompatível com a possibilidade explicitamente declarada de distribuição/comercialização do produto;
- mantém forte acoplamento ao inglês;
- não resolve a necessidade de clean-room para dados linguísticos PT-BR.

Conclusão:

- não recomendado.

### C. Clean-room

Pontos favoráveis:

- melhor alinhamento com comercialização potencial;
- permite arquitetura realmente multilíngue e PT-BR-first;
- reduz risco de carregar bugs/documentação divergente do artefato atual.

Pontos contrários:

- maior esforço inicial;
- exige disciplina alta de especificação, testes e proveniência de dados.

Conclusão:

- opção tecnicamente mais sólida e juridicamente mais prudente.

### D. Híbrida

Pontos favoráveis:

- preserva a disciplina clean-room onde o risco é alto;
- permite reutilizar apenas conceitos, formatos ou componentes futuros comprovadamente permissivos;
- pode reduzir custo em áreas não linguísticas, como DTOs ou protocolos, se um componente permissivo surgir depois.

Pontos contrários:

- exige governança forte para não contaminar a implementação com código/licença inadequados;
- pode criar ambiguidade se os limites não forem documentados desde o início.

Conclusão:

- boa estratégia operacional, desde que o núcleo linguístico permaneça clean-room.

## Recomendação

### DECISÃO PROPOSTA

Recomendação preliminar:

- adotar `arquitetura híbrida com núcleo linguístico clean-room`.

Interpretação prática:

- clean-room obrigatório para normalização, tokenização, morfologia, POS, multi-intent, coreferência, sessão e integração HA;
- adaptação apenas conceitual de estruturas públicas observadas (`Token`, `Phrase`, `artefatos compilados`, `DTOs`);
- nenhum código do crate público deve ser copiado para o produto até que uma base legal mais permissiva seja confirmada por componente.

## Consequências

### Positivas

- melhor encaixe com distribuição comercial;
- melhor controle de acoplamento ao inglês;
- melhor capacidade de definir contratos explícitos por camada;
- maior auditabilidade de dados e decisões.

### Negativas

- cronograma inicial maior;
- necessidade de corpus/fontes licenciadas adequadamente;
- maior investimento em harnesses e manifests de proveniência.

## Questões jurídicas pendentes

### DESCONHECIDO

- se existe checkout público atual do repositório `https://github.com/cicero-ai/cicero` com licença consistente com o pacote publicado `[E-009]`;
- se alguma versão anterior GPL pode ser usada de forma útil sem contaminar o produto pretendido, considerando as metas comerciais `[E-007]`;
- se há componentes separados, permissivos e tecnicamente relevantes fora dos crates inspecionados.

## Regra operacional derivada deste ADR

### DECISÃO PROPOSTA

- até resolução jurídica explícita, toda implementação futura do motor PT-BR deve ser tratada como clean-room nas camadas linguísticas e de runtime.
