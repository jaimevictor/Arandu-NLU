# Pacote de especificação clean-room

- `package_version`: `1.0.0`
- data do pacote: `2026-08-12`
- idioma normativo: PT-BR
- situação: especificação para implementação independente

## Finalidade

Este pacote define requisitos, contratos, limites de segurança, requisitos de dados, critérios de aceite e decisões abertas para uma implementação independente de um motor determinístico de interpretação de linguagem natural em PT-BR, inicialmente destinado ao domínio Home Assistant por meio de um adaptador separado.

O pacote é autossuficiente por intenção. Seu conteúdo descreve o comportamento esperado sem fornecer código, dados linguísticos de produção, material de pesquisa sobre outra implementação ou decisões que ainda dependam do responsável pelo produto.

## Limite de entrega

**POLÍTICA DO PACOTE.** Somente esta pasta deve ser entregue à próxima sessão de implementação. Nenhum arquivo externo, diretório irmão, histórico de conversa, histórico de repositório ou material auxiliar acompanha a entrega.

**POLÍTICA DO PACOTE.** Dentro desta pasta, a próxima sessão só pode receber e usar os arquivos declarados em `allowed_files` no `HANDOFF-MANIFEST.json`. Um arquivo presente, mas não autorizado pelo manifesto, deve ser tratado como externo ao pacote.

## Conteúdo previsto

O pacote completo contém exatamente estes doze arquivos previstos:

1. `README.md`
2. `01-product-scope.md`
3. `02-functional-requirements.md`
4. `03-non-functional-requirements.md`
5. `04-domain-model.md`
6. `05-pipeline-contracts.md`
7. `06-external-contracts.md`
8. `07-security-boundaries.md`
9. `08-data-requirements.md`
10. `09-acceptance-test-plan.md`
11. `10-open-decisions.md`
12. `HANDOFF-MANIFEST.json`

Esta lista descreve o conjunto esperado. A autorização efetiva de leitura continua sendo a lista `allowed_files` do manifesto entregue.

## Uso isolado

**POLÍTICA DO PACOTE.** O destinatário deve iniciar o trabalho em ambiente novo e isolado, validar o manifesto antes de usar o pacote e manter rastreabilidade entre requisito, decisão, implementação e teste.

**POLÍTICA DO PACOTE.** O pacote não autoriza preencher lacunas com conhecimento prévio, memória do modelo, pesquisa externa, comportamento observado em outra implementação ou material não incluído em `allowed_files`.

**CONVENÇÃO DOCUMENTAL.** As marcações normativas têm estes significados:

- `REQUISITO APROVADO`: obrigação que pode orientar implementação e teste;
- `DECISÃO PENDENTE`: escolha ainda não autorizada;
- `OPEN-nnn`: identificador rastreável de uma decisão pendente.

**CONVENÇÃO DOCUMENTAL.** Os únicos requisitos independentes contados na cobertura e testados como unidades próprias são as definições canônicas identificadas por `FR-nnn`, `NFR-nnn`, `API-nnn`, `SEC-nnn`, `DATA-nnn` e `TEST-nnn`. Textos de escopo, modelo, contratos, fronteiras, invariantes, falha segura e evidências elaboram esses IDs; não criam requisitos autônomos nem dispensam o vínculo com um ID canônico.

Se uma obrigação aparentemente nova não puder ser ligada a um desses IDs, ela é uma lacuna documental e deve seguir o procedimento abaixo, em vez de ser implementada como requisito órfão.

## Procedimento para requisito ausente

Se um requisito necessário não estiver no pacote autorizado, a próxima sessão deve:

1. registrar a lacuna como `DESCONHECIDO`;
2. criar ou referenciar um item `OPEN` sem propor uma resposta como se estivesse aprovada;
3. indicar qual etapa, camada ou critério de aceite ficou bloqueado;
4. interromper o trabalho afetado;
5. solicitar uma decisão ao responsável pelo produto.

É proibido consultar material de auditoria ou pesquisa para completar a lacuna. Uma resposta somente pode entrar no pacote como requisito aprovado após decisão explícita e atualização rastreável dos documentos e do manifesto.

## Sete regras obrigatórias da próxima sessão

1. Iniciar em conversa nova, sem histórico, resumo, memória compartilhada ou anexos anteriores.
2. Usar repositório e diretório novos que nunca tenham contido código da implementação externa tomada apenas como contexto de negócio.
3. Receber, abrir e usar somente os arquivos autorizados em `allowed_files` no `HANDOFF-MANIFEST.json`.
4. Não receber nem consultar `docs/architecture`, `docs/clean-room-audit`, o ADR original, outros documentos de arquitetura anterior, relatórios de auditoria ou pesquisa, endereços externos do produto anteriormente analisado ou registros de decisão produzidos fora deste pacote.
5. Não pesquisar, localizar, baixar, inspecionar ou comparar o produto ou a implementação externa que motivou a especificação.
6. Registrar a origem de cada entrada, decisão e artefato desde o primeiro commit da nova implementação.
7. Parar a etapa afetada quando faltar informação essencial; registrar a lacuna e aguardar decisão, sem inferir, importar ou inventar a resposta.

## Condição de início

### POLÍTICA DO PACOTE

A implementação só pode começar depois que:

- os doze arquivos previstos estiverem presentes e autorizados pelo manifesto;
- a integridade do conjunto tiver sido validada pelo procedimento declarado no manifesto;
- os bloqueios globais identificados em `01-product-scope.md` e `10-open-decisions.md` tiverem decisões aprovadas;
- o repositório isolado e o registro de proveniência estiverem preparados.

### Falha segura

**POLÍTICA DO PACOTE.** Qualquer divergência entre arquivos, arquivo ausente, falha de integridade ou requisito essencial incompleto exige o procedimento de lacuna deste README. A próxima sessão interrompe o trabalho afetado, não escolhe silenciosamente uma versão e não procura uma resposta fora do pacote.
