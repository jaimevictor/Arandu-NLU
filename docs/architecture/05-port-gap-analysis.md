# Gap Analysis: Port vs Reimplementação

Data da análise: 2026-08-12

Legenda:

- `Reusar`: reusar código diretamente no produto alvo.
- `Adaptar`: reaproveitar conceito/shape com nova implementação.
- `Reimplementar`: implementar novamente no projeto alvo.
- `Clean-room`: a reimplementação deve ocorrer sem copiar código/licença do artefato inspecionado.

Observação legal:

- devido a `[E-006] [E-007] [E-033] [E-036]`, esta matriz assume postura conservadora para um produto potencialmente distribuído/comercializado.

| Componente | Reusar | Adaptar | Reimplementar | Clean-room | Evidência | Dependências | Esforço relativo | Risco | Ordem |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| manifesto de baseline do sistema público | Não | Sim | Sim | Não | `[E-003] [E-004] [E-005]` | acesso a artefatos públicos | Baixo | Baixo | 1 |
| loader de artefato lexical | Não | Sim | Sim | Sim | `[E-013] [E-014]` | schema de artefato definido | Médio | Médio | 2 |
| cache de typos | Não | Sim | Sim | Sim | `[E-015]` | política de cache | Baixo | Baixo | 9 |
| normalização Unicode | Não | Parcial | Sim | Sim | `[E-017]` | política Unicode | Médio | Muito alto | 3 |
| tokenização PT-BR | Não | Parcial | Sim | Sim | `[E-018] [E-019]` | normalização Unicode | Alto | Muito alto | 4 |
| reconhecedor de MWEs | Não | Sim | Sim | Sim | `[E-019]` | tokenização + léxico compilado | Médio | Alto | 7 |
| parser de números/datas/unidades | Não | Parcial | Sim | Sim | `[E-018] [E-019]` | tokenização + schemas temporais | Médio | Alto | 8 |
| spell checker contextual | Não | Sim | Sim | Sim | `[E-023]` | tokenização, léxico, morfologia | Médio | Alto | 10 |
| morfologia PT-BR | Não | Parcial | Sim | Sim | `[E-023] [E-024]` | léxico + política de dados | Alto | Muito alto | 11 |
| infraestrutura HMM/Viterbi | Não | Sim | Sim | Sim | `[E-021]` | tagset definido, corpus/licenças | Médio | Médio | 12 |
| tagset POS | Não | Sim | Sim | Sim | `[E-020]` | decisão de schema linguístico | Médio | Alto | 5 |
| features e modelos POS | Não | Parcial | Sim | Sim | `[E-022] [E-023]` | morfologia + dados rotulados | Alto | Muito alto | 13 |
| IR sintático-semântica | Não | Sim | Sim | Sim | `[E-024] [E-025] [E-026]` | schemas declarativos | Médio | Médio | 6 |
| phrase intents atuais | Não | Parcial | Sim | Sim | `[E-027]` | tokenização + léxico | Médio | Alto | 14 |
| múltiplos intents por sentença | Não | Não | Sim | Sim | `[E-027]` | IR nova + schemas | Alto | Alto | 15 |
| coreferência básica | Não | Sim | Sim | Sim | `[E-029]` | morfologia + sessão curta | Médio | Alto | 16 |
| sessão e esclarecimentos | Não | Não | Sim | Sim | `[E-030] [E-035]` | IR + política de segurança | Alto | Alto | 17 |
| templates de resposta | Não | Sim | Sim | Não | ausência de implementação pública confirmada `[E-030]` | session manager + action results | Médio | Médio | 18 |
| protocolo local aberto | Não | Parcial | Sim | Sim | `[E-035]` | IR estável + segurança | Médio | Alto | 19 |
| adaptador Home Assistant | Não | Não | Sim | Sim | `[E-037]` | catálogo de entidades + política | Alto | Alto | 20 |
| importador de inventário HA | Não | Sim | Sim | Sim | `[E-037]` | adaptador HA, política de proveniência | Médio | Alto | 21 |
| compilador offline de dados | Não | Não | Sim | Sim | ausência pública de pipeline `[E-030]` | política de proveniência | Alto | Muito alto | 22 |
| versionamento de artefatos | Não | Sim | Sim | Não | `[E-014]` | compilador offline | Médio | Médio | 23 |
| harness de avaliação e benchmarks | Não | Não | Sim | Não | ausência pública de testes/bench `[E-030]` | datasets e critérios de aceite | Médio | Alto | 24 |
| wrappers/shared library da edição premium | Não | Sim | Sim | Sim | `[E-033] [E-034]` | protocolo local + DTOs | Médio | Médio | 25 |
| documentação técnica de uso | Não | Parcial | Sim | Não | `[E-008] [E-032]` | baseline reproduzível | Baixo | Médio | 26 |

## Leitura da matriz

### Itens com maior potencial de adaptação conceitual

- loader de artefato lexical;
- cache de typos;
- infraestrutura HMM/Viterbi;
- shape geral da IR `Token -> Phrase -> Intent`;
- resolvedor de coreferência como responsabilidade separada;
- interfaces DTO de tokenização/interpretação.

### Itens que exigem clean-room com maior prioridade

- normalização Unicode;
- tokenização;
- morfologia;
- features POS;
- regras temporais;
- múltiplos intents;
- sessão e clarificação;
- adaptador Home Assistant.

## Dependências de ordem

### DECISÃO PROPOSTA

Ordem macro:

1. baseline reproduzível e legal;
2. Unicode + tokenização;
3. política de dados + importação lexical;
4. morfologia;
5. POS;
6. IR/schemas;
7. entidades;
8. multi-intent e coreferência;
9. sessão/clarificação;
10. protocolo;
11. adaptador HA;
12. avaliação e empacotamento.

## Conclusão

- `DECISÃO PROPOSTA`: para um produto potencialmente comercial, o caminho seguro é `adaptar conceitos` e `reimplementar em clean-room` quase todas as camadas linguísticas críticas.
- `DECISÃO PROPOSTA`: reuso direto de código não deve ser assumido como opção viável sem esclarecimento jurídico e sem uma origem pública estável do repositório.
