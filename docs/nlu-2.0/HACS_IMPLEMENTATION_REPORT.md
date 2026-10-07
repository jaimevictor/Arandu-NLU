# Distribuição HACS — ARANDU NLU 0.4.2

Data: 2026-10-07. Escopo exclusivo: instalação/atualização da integração Python.
Motor, executor, permissões, exposição, protocolo v4, STT/TTS e identificadores
não foram reimplementados. Não foi acessado/modificado Arandu-STT.

## Resultado técnico

O mesmo repositório serve a Add-on Store e o HACS, com versões sincronizadas.
HACS reconhece uma única Integration, domínio `local_nlu`, nome ARANDU NLU,
HA mínimo 2025.3.0 e HACS 2.0.5. O mínimo HA foi corrigido em revisão:
AddConfigEntryEntitiesCallback já é importado pelo componente e não existe em
2025.2.0. Config flow VERSION=1 e unique_id baseado em entry_id são preservados.

HACS instala a subárvore Python por fonte oficial, com branch master visível;
releases publicadas futuramente oferecem versões etiquetadas. O método funciona
antes da primeira release e continua atualizável por HACS depois dela. O ZIP
fixo **arandu-nlu-integration.zip** também é gerado, mas não é consumido pelo
HACS com zip_release=false. Isso é deliberado: o instalador oficial consultado
não oferece fallback de ZIP para fonte, inclusive ao instalar master. Como
publicar release é proibido nesta missão, habilitar ZIP agora impediria instalar.
Fonte é um método oficial completo, não uma instalação manual temporária.

## Arquivos alterados

| Grupo | Arquivos | Motivo |
| --- | --- | --- |
| Metadados | hacs.json; custom_components/local_nlu/manifest.json | HACS, mínimo HA/HACS, documentação/issues/codeowner |
| Versão | addon/config.yaml; addon/engine/Cargo.toml; addon/engine/Cargo.lock; Cargo.lock; release.json | versão única 0.4.2 e fingerprint |
| Pacote | tools/hacs.py; tools/release-package.py; tools/check-mlp-package.py | allowlist, segredo/symlink/ZIP, formato plano adicional |
| CI | .github/workflows/hacs.yml; .github/workflows/release-integration.yml | validação oficial/read-only e upload somente release published |
| Testes | tests/mlp/test_distribution.py; tests/mlp/test_hacs.py; tests/mlp/hacs_official_probe.py | versões, arquivos hostis, reprodução, migração e consumidor oficial |
| Ambiente | tools/dev/run.py; tools/dev/DEPENDENCIES.md | staging de hacs.json/.github, pin/licença do ambiente oficial |
| Branding | custom_components/local_nlu/brand/icon.png; tools/generate-brand.py | ícone original Apache-2.0 reproduzível, sem dependência |
| Guias | README.md; INSTALL.md; docs/nlu-2.0/DEPLOYMENT.md; RELEASES.md | dois canais, migração, diagnóstico, release e checklist HA |
| Evidências | HACS_IMPLEMENTATION_CHECKPOINT.md; HACS_IMPLEMENTATION_REPORT.md; nota no CONTEXTUAL_IMPLEMENTATION_REPORT.md | retomada e resultados atuais sem reescrever evidências históricas |

## Processo de release

O mantenedor prepara e valida uma versão única antes de publicar. O evento
**release published**, estável, dispara checkout da tag, validação `v<versão>`,
testes de distribuição, empacotamento/ZIP/hash e upload de ZIP fixo + SHA-256
para aquela release. O workflow não cria tag/release, não sobrescreve assets,
não publica em push comum e não faz deploy. O job de upload tem contents:write;
validação tem somente contents:read. Referências são fixadas por SHA/digest.
[Procedimento detalhado](RELEASES.md).

## Migração e operação

Faça backup HA, adicione o custom repository do tipo Integration no HACS, baixe
ARANDU NLU e reinicie o HA. A primeira instalação sobrepõe o mesmo diretório;
updates gerenciados fazem backup/substituição somente do componente. Não remova
a config entry, options, entidade de conversa ou `.storage`. Não é necessário
recriar a integração. O HACS cuida do Python; a Store cuida do Rust.

Confira diagnósticos: integration_version=service_version=0.4.2,
contextual_enabled=true, protocol=4, route=/v4/interpret e compatible=true.
Mismatch continua produzindo integration_addon_version_mismatch; backend
indisponível continua produzindo backend_diagnostics_unavailable. Nenhuma
atualização automática do add-on foi adicionada ao Python.

## Testes e comandos executados

Ambiente offline principal: Docker Linux, Python 3.12.15, Ruby 3.4.4,
Rust 1.98.0. O host Python 3.10 não é usado no gate. Logs locais em target/.

| Validação | Comando | Resultado observado |
| --- | --- | --- |
| HACS específico | python3 -m unittest discover -s tests/mlp -p test_hacs.py | 12 PASS; nova execução independente diretamente no checkout após correções PASS |
| Distribuição | python3 tools/distribution.py --record; python3 tools/hacs.py --tag v0.4.2 --zip target/dist/0.4.2/arandu-nlu-integration.zip | PASS |
| Gates anteriores | pwsh -NoProfile -File tools/mlp-dev.ps1 -Task check | 0.4.1 PASS: 157 Python/93 Rust/70 pós-build; 0.4.2 pré-qualificação de tag também PASS |
| Gate final 0.4.2 | docker exec -w /workspace -e PYTHONDONTWRITEBYTECODE=1 arandu-context-dev sh ./tools/mlp-check; log target/hacs-0.4.2-qualified-gate.log | PASS: 158 Python únicos, 93 Rust, 70 contextual/HTTP pós-build, fmt/clippy/corpus/vendor/pacote/versões/build/smoke |
| Official probe | container oficial por digest, PYTHONPATH=/hacs, tests/mlp/hacs_official_probe.py | PASS com validators HACS/manifest/brand, registro Integration, source install, reinstall/backup e release ZIP |
| Pacotes | python3 tools/release-package.py --output target/dist/0.4.2; novamente em target/dist/hacs-0.4.2-reproduction | três ZIPs e metadata idênticos |
| Diff | git diff --check; comparação de runtime | PASS; nenhum Rust src/Python runtime/flow/diagnostics modificado |
| Revisões | produto; segurança/privacidade/licenças/pacote | duas revisões independentes PASS na árvore final |

O official probe usa o código real do HACS no container congelado
ghcr.io/hacs/action@sha256:dc92fdad2f6ffbe74bffb7269d781ea8e064f52d9bb486cdf3925d74e7ab6ebf,
revisão OCI 3f3080cbf909b8f51488e227be73f62902b4ef6c. Apenas transportes GitHub
e acesso executor HA são fixtures. Registro/schema/extração/backup usam funções
oficiais, sem rede. Isso não comprova frontend HACS nem HA residencial.

O job oficial GitHub usa o mesmo container, mantendo ativos todos os checks
técnicos. Description/topics são as únicas exceções de catálogo, pois esses
metadados ainda estão vazios no GitHub. Runs remotos são verificáveis em
https://github.com/jaimevictor/Arandu-NLU/actions/workflows/hacs.yml.

O primeiro push foi 6b11213 (produto 0.4.1). Nesse
[run](https://github.com/jaimevictor/Arandu-NLU/actions/runs/37625912914), o job
official-hacs PASS, mas distribution falhou em actions/checkout removeAuth,
antes dos testes, devido ao gitlink legado sem URL/.gitmodules. O checkout agora
usa Git público anônimo, referência validada, sparse não-cone e nenhuma operação
de submódulos. Não alterou/removou o gitlink. A correção exige produto 0.4.2 pela
guarda de versionamento; o gate final foi repetido nessa versão. Source e staging
tiveram fingerprint executável idêntico antes de executar o gate final.

Contraprova intermediária: sparse cone materializa gitlinks da raiz, então a
primeira tentativa falhou corretamente no teste Git. Sparse não-cone com exclusão
explícita passou. Uma cópia de staging ainda antiga também falhou no teste de
workflow, depois foi sincronizada. O fluxo de release busca `refs/tags/<tag>`
explicitamente; teste prova que tag removida + branch homônima falha e que uma
tag real é escolhida mesmo quando a branch homônima aponta a outro commit.

Contraprovas novas: tag divergente/injeção; versão/domain/manifest inválidos;
fields/tipos HACS desconhecidos; múltiplos componentes; arquivos .env/secrets/
tests/fixtures/addon; credenciais longas/curtas/JSON/JWT/chaves privadas; symlinks
de arquivo/diretório/raiz; traversal/paths Windows/absolutos; duplicatas; modo
symlink; ZIP excessivo; colisão preservando artefato; config entry/options/registry
inalterados. Achados de revisão foram corrigidos sem enfraquecer testes.

Os 42 skips HTTP pré-build são executados no segundo passe contextual de 70
testes. Não são ensaios omitidos. Diagnóstico pareado, mismatch, ausência de
dados privados e falhas de backend pertencem aos testes funcionais existentes.
As regressões de executor/permissões/entidades/contexto continuam no gate.

## Artefatos reproduzidos

| Pacote em target/dist/0.4.2 | Arquivos | SHA-256 |
| --- | --- | --- |
| arandu-nlu-addon-0.4.2.zip | 612 | 2866052c4691d53f8cdecf465fbd92e0d64700af239c3a4e349f0f7739faff31 |
| arandu-nlu-integration-0.4.2.zip | 23 | 2b7ef30bf5305eef754b7bd0dccd73f4a51db344e6afa5eb85b94a4278c8668c |
| arandu-nlu-integration.zip | 23 | f8851a4ed35afc64bd5e5d7c6f4c7858d3aa7112215ed988eed2d833f685e645 |

Fingerprint de distribuição release.json:
dcb5ec263e7b57f8c5e15640311bb72bdc08688b99cd92afa60e6695075d38b6.
Fingerprint de código/testes/ferramentas do gate final:
d9aaa213c6b1e659374ec577e1331aca6e7a529752f81f6d0ef1a6ed87ec5ab2.
Reprodução comprovada no ambiente registrado; não se afirma compressão bit a bit
idêntica em toda versão possível de Python/zlib. CRC/bytes/modos/lista/versões
foram verificados. Artefatos locais não são incluídos no Git.

## Matriz de aceitação

| Requisito | Evidência |
| --- | --- |
| hacs.json válido | schema oficial + check/test local |
| custom Integration reconhecível | HacsIntegrationRepository real/fixtures + CI oficial preparado |
| domínio local_nlu | manifest e registro oficiais; testes negativos |
| componente Python válido | gate/allowlist/manifest/licenses |
| pacote HACS reproduzível | duas gerações, hash/lista/CRC e consumidor oficial |
| release carrega ZIP automaticamente | workflow release published com versões/ZIP/hash/tests; upload remoto não disparado |
| versões sincronizadas | check_versions, record, tag equality e mutations negativas |
| instalação normal sem cópia manual | HACS na README/INSTALL/DEPLOYMENT |
| migração manual segura | guia + storage/entry/options fixture + backup HACS real |
| atualização HACS documentada | passos por commits/releases e restart; Store independente |
| diagnóstico preservado | testes funcionais existentes + campos/erros no guia |
| Add-on Store independente | check_store, slug/arquiteturas/build/licenças/pacote preservados |
| gate completo | inicial e final PASS; log final/hashes acima |
| capacidades sem regressão | mesmos testes parser/contexto/executor/HTTP; runtime intacto |

## Limites e próximos passos do proprietário

Não há HA residencial ou frontend HACS disponível neste ambiente. Não foi
publicada release/tag nem executado upload/deploy. O cenário de uma próxima
versão aparecer no HACS depende de uma próxima publicação autorizada; há
checklist explícita em [INSTALL.md](../../INSTALL.md#checklist-de-validação-em-ha-real).
O scanner bloqueia padrões conhecidos e literals de credenciais, junto à
allowlist; não constitui prova universal de ausência de qualquer segredo possível.

Para catálogo público futuro, preencher description/topics, remover as duas
exceções e cumprir regras oficiais então vigentes. Não foi enviado PR hacs/default.
Ícone local atende ao validador atual; HACS/HA antigos podem usar ícone genérico
até haver branding global, sem afetar domínio/instalação. Fontes e decisões em
[checkpoint](HACS_IMPLEMENTATION_CHECKPOINT.md) e [RELEASES.md](RELEASES.md).

1. Faça backup e atualize o motor para 0.4.2 pela Store.
2. No HACS, adicione o repositório como Integration; instale ARANDU NLU/master.
3. Reinicie HA e confira a entrada antiga e diagnósticos pareados/v4.
4. Teste consulta simples antes de controle; registre a checklist real.
