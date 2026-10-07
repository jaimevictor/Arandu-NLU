# Arandu NLU 2.0 — Execution Checkpoint

## Estado
Data: 2026-10-06
Branch: chore/cleanup-store-20260918-233959
Commit base: cd1014770763cac29135b98db2c83b5e0bba996f
Workspace contém mudanças locais: sim; inclui modificações anteriores preservadas.
Workspace: E:/Pycharm Projects/Arandu NLU

## Etapas
- [x] Recuperação do workspace
- [x] Segurança: contraprovas corrigidas; notices musl/Rust incluídos e verificados na imagem
- [x] Regressões: A–J conferidos; 99 testes Python, 9 E2E Rust HTTP
- [x] Gate completo: PASS a partir do ZIP fonte 18909fef2fd43649bb6412f63b40a36309c73634d5f41ecf64956505ff1ef02f
- [x] Corpus: 1.946 casos avaliados novamente
- [x] Performance: benchmarks novamente executados
- [x] Produto: revisão read-only concluída e contraprovas reexecutadas
- [x] Docker/ZIP: imagem atual iniciou/smoke PASS; ZIP extraído com gate completo PASS
- [x] Documentação: README atual, arquitetura, compatibilidade, implantação/logs/rollback e revisões por severidade
- [x] Relatório final: docs/nlu-2.0/REPORT.md, estrutura A–J, READY WITH KNOWN LIMITATIONS

## Últimos resultados confirmados
Rust: 90 testes; fmt/clippy/release/smoke PASS no gate.
Python: 99 testes únicos; segundo passe contextual 32 incluindo 9 E2E Rust HTTP.
Integração: Rust real HTTP + executor real Python com HA simulado PASS.
Corpus: 1.942 reconhecidos, 1.911 resultados semânticos, 1.902 planos válidos, 1.894 fluxos concluídos / 1.946. Restantes: continuação22, contexto6, ambiguidade2, segurança2, falha de interpretação2, limitação de teste18.
Performance: nova medição de 4.096 entidades: Rust P95 2,116 ms/P99 2,599 ms; HTTP + executor nominal P95 1,034 ms/P99 1,126 ms. JSONs incluem RSS e etapas separadas.
Docker: scratch amd64 build e smoke PASS; usuário 65534:65534; rede isolada. ARM64 não executado.
ZIP: target/arandu-nlu-2.0.0.zip, versão 2.0.0; fontes extraídas, hashes/referências/modos/estrutura/vendor e gate completo PASS. `unzip` nativo preserva executáveis. Manifesto por arquivo e checksum do ZIP estão no artefato/arquivo .zip.sha256. package-validation.json preserva a prova do gate; documentação final foi conferida na extração final sem alterar código.

## Arquivos alterados nesta execução
Motor addon/engine/src/contextual e testes; integração contextual/capabilities/queries e testes/mlp/test_contextual.py; scripts de importação/evidência/build; docs/nlu-2.0; inventário/data/contextual; versões 2.0.0. Mudanças legadas preexistentes não foram revertidas.

## Pendências concretas
Nenhuma pendência de estabilização local. Duas frases de device.status continuam sem interpretação e estão classificadas no relatório. Fluxos condicionais/continuações/contexto ausente não foram forçados a executar. Instalação residencial, frontend e ARM64 permanecem sem ensaio.

## Bloqueadores
Nenhum para estabilização local. Não existe HA residencial neste ambiente; não alterar instalação real. Revisão secundária de segurança encerrou por limite de uso depois de informar a lacuna de aviso musl; executor deve fechar essa pendência e registrar verificação.

## Próxima ação exata
Entrega local concluída. Solicitação posterior do usuário autorizou commit, push e PR via GitHub no branch feat/nlu-2.0-contextual. Publicação de release e alteração de HA real continuam sem autorização. Para implantação, seguir DEPLOYMENT.md em ambiente controlado.

## Comandos necessários para retomar
`./tools/mlp-dev.ps1 -Task check` — gate oficial em Docker/Linux, log target/nlu-2.0-check.log.
`python tools/contextual-record.py --gate-pass --package target/arandu-nlu-2.0.0.zip` — somente após gate com o fingerprint atual e avaliação/benchmarks atualizados.
`python tools/import-stt-corpus.py --stt-root "E:/Pycharm Projects/Arandu STT/arandu-stt-github" --check` — proveniência/inventário reproduzível.
Critérios finais: segurança sem CRITICAL/HIGH/MEDIUM de execução pendentes; gate, corpus, benchmarks, Docker e ZIP extraído aprovados; relatório READY WITH KNOWN LIMITATIONS se HA real/ARM continuarem sem teste; nenhum push/deploy.
