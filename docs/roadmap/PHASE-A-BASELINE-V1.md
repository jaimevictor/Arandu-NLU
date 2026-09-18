# Fase A — Baseline do parser antes da semântica de entidade principal

## Estado

Baseline registrado antes de alterar `addon/engine/src/`.

- Freeze avaliado: `ptbr-independent-v1`
- Corpus: 144 casos; 120 pontuados; 24 `known-gap-future`
- Resultado: 134 `exact_pass`, 10 `semantic_mismatch`
- Nenhuma falha de protocolo
- Nenhum baseline promovido

## Divergência conhecida

As 10 divergências usam `luz da sala` ou `luz do quarto`. O parser atual trata essas expressões como seleção de área e retorna todas as entidades `light` da área. O corpus v1 esperava somente a entidade principal.

Essa divergência registra o comportamento anterior. Não é usada como justificativa única para alterar o parser.

## Contrato semântico aprovado para v2

1. `luz da sala` resolve entidade principal da sala quando catálogo marca essa entidade explicitamente.
2. `luzes da sala` resolve todas as entidades `light` da sala.
3. `abajur da sala` resolve somente alias do abajur.
4. `todas as luzes da sala` e `iluminação da sala` continuam comandos de área.
5. Sem entidade principal explícita e com múltiplas candidatas, resposta é `ambiguous`.
6. Regra vale para qualquer área e para `turn_on`, `turn_off` e `get_state`.
7. Nenhuma regra usa nome fixo de sala ou quarto.

## Gate

O dataset v1 permanece imutável. A implementação usa catálogo e corpus v2, com novo freeze. O baseline v1 continua evidência do comportamento anterior.
