# P00 — bloqueios de validação clean-room

Data da verificação: 2026-08-22

## CONFIRMADO

- O manifesto `docs/clean-room/HANDOFF-MANIFEST.json` existe e declara os
  doze arquivos esperados.
- Os hashes SHA-256 dos onze arquivos com hash declarado no manifesto foram
  conferidos com `Get-FileHash -Algorithm SHA256` e correspondem aos valores
  declarados.
- `git status --short` falhou porque `E:\Pycharm Projects\Sophia NLU` não é
  atualmente uma raiz de repositório Git.
- A árvore de trabalho contém `docs/architecture/` e
  `docs/clean-room-audit/`. O manifesto e o `docs/clean-room/README.md`
  proíbem a sessão de implementação de receber, abrir ou usar esses
  materiais.

## DESCONHECIDO

- Não há evidência verificável de que este diretório nunca conteve material
  ou código da implementação externa mencionada nas regras do handoff.
- Não está definido se o responsável pelo produto autoriza preparar uma nova
  raiz Git isolada contendo somente o steering, `AGENTS.md` e o pacote
  `docs/clean-room/` autorizado.

## IMPACTO

O handoff clean-room não pode ser validado para este diretório. Portanto, a
P00 não pode declarar que a árvore está livre de material proibido conhecido,
nem estabelecer a rastreabilidade exigida desde o primeiro commit. Nenhuma
implementação, dependência, dado linguístico ou fase posterior foi iniciada.

## DECISÃO NECESSÁRIA

O responsável pelo produto deve fornecer ou autorizar uma raiz de repositório
nova e isolada, inicializada como Git, que contenha somente os arquivos
permitidos para a sessão de implementação. Depois disso, a P00 deve ser
reiniciada e todos os hashes devem ser conferidos novamente.

## Comandos executados

```text
git status --short
Get-FileHash -Algorithm SHA256 para cada entrada de file_hashes_sha256
Get-ChildItem -Force -Recurse
```

## Resultados

- `git status --short`: `fatal: not a git repository (or any of the parent directories): .git`
- Verificação de hashes: `MANIFEST_HASHES_OK`
- Inventário: identificou os diretórios proibidos descritos acima.

---

## Verificação independente desta sessão — 2026-08-22

### CONFIRMADO

- A raiz efetiva é `E:\Pycharm Projects\Sophia NLU`; `git status --short`
  retornou código `128`, pois não há repositório Git nessa raiz nem em seus
  ancestrais.
- O manifest é JSON válido, enumera exatamente os doze arquivos existentes em
  `docs/clean-room/` e os onze hashes SHA-256 declarados correspondem aos
  arquivos autorizados.
- Os documentos autorizados foram lidos integralmente. A verificação
  estrutural encontrou todas as faixas canônicas `FR-001..026`,
  `NFR-001..012`, `API-001..013`, `SEC-001..014`, `DATA-001..016`,
  `TEST-001..018` e `OPEN-001..026`; não foram encontrados URLs externos no
  pacote autorizado.
- O inventário por nome, sem abrir o conteúdo excluído, confirma a presença
  de `docs/architecture/` e `docs/clean-room-audit/`. Ambas as pastas são
  vedadas pelas regras de sessão do manifest. Há também artefato prévio em
  `docs/phases/`, fora do pacote permitido.
- Não foram encontrados código de implementação, dependências, nem arquivos
  de dados linguísticos pelos padrões de extensão verificados.
- `docs/phases/PROJECT-STATUS.md` e `docs/phases/P00-REPORT.md` não existem;
  `AGENTS.md` não referencia `STEERING-NLU-PTBR.md`.

### DESCONHECIDO

- Não há evidência verificável de que esta pasta nunca tenha contido material
  de implementação externa. A ausência de Git também impede estabelecer o
  primeiro baseline e revisar um diff.
- `markdownlint` não está disponível no ambiente. Foi executada a verificação
  estrutural reproduzível acima; não foi afirmada validação por essa ferramenta.

### DECISÃO PROPOSTA

- Manter P00 bloqueada e não criar código, dependências, dados linguísticos,
  Cargo workspace, ADRs de arquitetura ou artefatos de P01 nesta raiz.
- O responsável pelo produto deve fornecer ou autorizar uma raiz Git nova e
  isolada, contendo somente `AGENTS.md`, `STEERING-NLU-PTBR.md` e os doze
  arquivos autorizados em `docs/clean-room/`. A P00 deve ser reiniciada nessa
  raiz, com nova conferência de hashes antes de qualquer edição.

### GATE P00

`BLOCKED` — as condições de sucesso “repositório e handoff íntegros” e
“árvore livre de material proibido conhecido” não foram atendidas. Não há
autorização para P01.

### Comandos executados nesta verificação

```text
git rev-parse --show-toplevel
git status --short --branch
Get-Content -Raw dos doze arquivos autorizados
Get-FileHash -Algorithm SHA256 para cada arquivo declarado no manifest
Get-ChildItem -Force -Recurse para inventário por nomes
Validação PowerShell de JSON, conjunto de arquivos, hashes, IDs e URLs
```
