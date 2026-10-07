# Checkpoint HACS — 0.4.2

## Estado

Implementação concluída em 2026-10-07. Código validado e enviado diretamente
para master no commit 321e717a5fc4a99d4f5bf90148f6c1295e9bb235.
A [CI desse commit](https://github.com/jaimevictor/Arandu-NLU/actions/runs/37629182830)
passou nos jobs distribution e official-hacs. Este registro posterior altera
somente documentação; o código e os fingerprints abaixo permanecem iguais.

Não foi publicada release/tag nem executado deploy residencial.
Arquivos preexistentes preservados, fora dos commits: docs/codex/,
docs/nlu-2.0/ARANDU_NLU_CONTEXTUAL_CAPABILITIES_SPEC.md e tools/codex-skill-check.ps1.
Arandu-STT e o conteúdo do gitlink legado não foram acessados/modificados.

## Distribuição implementada

Monorepo preservado: HACS custom Integration em custom_components/local_nlu/;
Add-on Store em addon/, slug ptbr_nlu. Domínio, config flow VERSION=1,
entry_id, options e unique_id de conversa preservados. Versão única 0.4.2.
Mínimos: HA 2025.3.0 e HACS 2.0.5. A API AddConfigEntryEntitiesCallback já usada
pelo componente não existe no HA 2025.2.0. Esses mínimos não equivalem a
validação residencial nessas versões.

HACS instala por fonte oficial: content_in_root=false, zip_release=false,
branch master visível. Não existiam releases publicadas na inspeção. No
HACS 2.0.5 e main consultado, zip_release=true chama download_zip_files sem
fallback, inclusive ao instalar master. Habilitá-lo impediria instalar antes
de publicar um asset, e essa publicação é proibida nesta missão. Fonte permite
instalação/atualização agora e seleção de versões publicadas futuramente.

Também é gerado arandu-nlu-integration.zip, mas HACS não consome esse asset
com o método atual. Fonte permanece um método completo; não requer troca
posterior. O consumidor oficial de ZIP foi validado separadamente.

Contrato ZIP: extração diretamente no diretório da integração; manifest.json
na raiz, sem prefixo custom_components/local_nlu/. Allowlist de 23 arquivos de
runtime, licenças, traduções e ícone. Valida CRC, versões, modos e hash; recusa
traversal, duplicatas, symlinks, extras e padrões conhecidos de credenciais.
Pacotes versionados do add-on e da integração permanecem disponíveis.

Workflow de release estável published: checkout público de refs/tags/<tag>,
validação semver/versões/digest/testes/ZIP/hash e upload do ZIP fixo + SHA-256
à release existente. Não cria tag/release, não sobrescreve assets e não publica
em push comum. contents:write somente no job de release; validação somente
contents:read. Setup Python e container oficial HACS fixados por SHA/digest.
Checkout Git anônimo, sem token nem operações de submódulos.

## Arquivos alterados

- Metadados/versões: hacs.json; custom_components/local_nlu/manifest.json;
  addon/config.yaml; addon/engine/Cargo.toml; addon/engine/Cargo.lock;
  Cargo.lock; release.json.
- Ferramentas: tools/hacs.py; tools/release-package.py; tools/distribution.py;
  tools/check-mlp-package.py; tools/dev/run.py; tools/dev/DEPENDENCIES.md;
  tools/generate-brand.py.
- CI: .github/workflows/hacs.yml; .github/workflows/release-integration.yml.
- Testes: tests/mlp/test_distribution.py; tests/mlp/test_hacs.py;
  tests/mlp/hacs_official_probe.py.
- Ícone: custom_components/local_nlu/brand/icon.png.
- Guias: README.md; INSTALL.md; docs/nlu-2.0/DEPLOYMENT.md; RELEASES.md;
  HACS_IMPLEMENTATION_CHECKPOINT.md; HACS_IMPLEMENTATION_REPORT.md;
  nota histórica em CONTEXTUAL_IMPLEMENTATION_REPORT.md.

Lista e matriz de aceitação: [relatório](HACS_IMPLEMENTATION_REPORT.md).
Nenhum código Rust src, Python runtime, config flow ou diagnostics foi alterado.

## Fontes oficiais consultadas

- https://www.hacs.xyz/docs/publish/integration/
- https://www.hacs.xyz/docs/publish/start/
- https://www.hacs.xyz/docs/publish/action/
- https://www.hacs.xyz/docs/faq/custom_repositories/
- https://github.com/hacs/integration/tree/adb7d83e33d24325535fb43b8226572405143757
  — integration.py/base.py, schema, brands e backup; comparados com tag 2.0.5.
- https://github.com/hacs/action/tree/1ebf01c408f29afcb6406bd431bc98fd8cbb15aa
  — wrapper usa imagem main mutável; congelado diretamente o digest oficial.
- https://github.com/home-assistant/core/blob/2025.3.0/homeassistant/helpers/entity_platform.py
  — comparação com 2025.2.0 para o mínimo de API.
- https://developers.home-assistant.io/blog/2024/04/30/store-runtime-data-inside-config-entry/
- https://github.com/actions/checkout/blob/main/src/git-auth-helper.ts
  e https://github.com/actions/checkout/issues/610 — falha de gitlink sem URL.

## Testes realizados e resultados reais

Gate completo 0.4.1 PASS. Após correções de CI/revisão, gate final 0.4.2 PASS,
log target/hacs-0.4.2-qualified-gate.log: 158 Python únicos, 93 Rust,
70 contextual/HTTP pós-build; fmt, clippy, corpus, vendor, pacote, versões,
build release e smoke PASS. Os 42 skips HTTP pré-build foram executados no
passe pós-build. Ambiente Docker Linux: Python 3.12.15, Ruby 3.4.4,
Rust 1.98.0; host Python 3.10 inadequado para esse gate.

12 testes HACS PASS: incluem Git real com gitlink sem URL, ausência de
credenciais, recusa de tag ausente com branch homônima e preferência pela tag
explícita quando uma branch diverge. Duas revisões independentes PASS no digest
final: produto e segurança/privacidade/licenças/pacote.

Probe no container oficial, sem rede, PASS: schemas e validators
HACS/manifest/brand; reconhecimento Integration/domínio/destino; instalação
por fonte; reinstalação/backup reais do HACS; consumidor de ZIP plano.
Somente transporte GitHub e acesso executor HA usam fixtures. Esse resultado
não comprova frontend HACS nem instalação residencial.

CI remota do código final PASS:
https://github.com/jaimevictor/Arandu-NLU/actions/runs/37629182830
Jobs distribution e official-hacs concluídos com success.

Pacotes 0.4.2 gerados duas vezes com mesmos bytes, hashes e metadados:

| Pacote | Arquivos | SHA-256 |
| --- | --- | --- |
| arandu-nlu-addon-0.4.2.zip | 612 | 2866052c4691d53f8cdecf465fbd92e0d64700af239c3a4e349f0f7739faff31 |
| arandu-nlu-integration-0.4.2.zip | 23 | 2b7ef30bf5305eef754b7bd0dccd73f4a51db344e6afa5eb85b94a4278c8668c |
| arandu-nlu-integration.zip | 23 | f8851a4ed35afc64bd5e5d7c6f4c7858d3aa7112215ed988eed2d833f685e645 |

Digest de distribuição:
dcb5ec263e7b57f8c5e15640311bb72bdc08688b99cd92afa60e6695075d38b6.
Fingerprint executável:
d9aaa213c6b1e659374ec577e1331aca6e7a529752f81f6d0ef1a6ed87ec5ab2.
Host e staging comparados iguais antes do gate final.

## Problemas encontrados e resolvidos

Mínimo HA inicial baixo; scanner permitia credenciais curtas/JSON; teste fixava
0.4.1. Corrigidos com contraprovas. Chave YAML on sem aspas virou bool no Ruby:
agora entre aspas nos workflows. Probe fora de /hacs exige PYTHONPATH=/hacs.

Primeiro push 6b11213 (0.4.1): run 37625912914 teve official-hacs PASS e
distribution falhou antes dos testes no cleanup de actions/checkout, devido
ao gitlink legado sem URL. Checkout Git anônimo elimina foreach sem tocar no
legado. Sparse cone ainda materializava o gitlink e falhou no teste; sparse
não-cone com exclusão explícita passou. Staging antigo falhou no teste de
workflow até ser sincronizado. Fetch de release usa refs/tags explicitamente
para impedir fallback à branch. A CI final confirmou a correção.

Versão 0.4.2 respeita a guarda após commit 0.4.1. Durante a candidata ainda
não commitada, somente release.json gerado foi restaurado ao baseline HEAD
antes do record final. Não afrouxar essa guarda: próxima mudança distribuída
exige versão maior. Alteração apenas destes relatórios não muda o digest.

## Comandos para reproduzir

Executar na raiz de Arandu NLU; não no repositório irmão Arandu STT.
Em Windows, o gate prepara o ambiente Docker pinado:

```powershell
pwsh -NoProfile -File tools/mlp-dev.ps1 -Task check
git diff --check
gh run view 37629182830 --json status,conclusion,jobs,url
git ls-remote origin refs/heads/master
```

No ambiente Linux pinado:

```sh
./tools/mlp-check
python3 -m unittest discover -s tests/mlp -p test_hacs.py
python3 tools/release-package.py --output target/dist/reproduction-new
python3 tools/hacs.py --tag v0.4.2 --zip target/dist/reproduction-new/arandu-nlu-integration.zip
docker run --rm --network none --entrypoint python3 -e PYTHONPATH=/hacs \
  --mount "type=bind,source=<caminho-absoluto-do-repo>,target=/repo,readonly" \
  ghcr.io/hacs/action@sha256:dc92fdad2f6ffbe74bffb7269d781ea8e064f52d9bb486cdf3925d74e7ab6ebf \
  /repo/tests/mlp/hacs_official_probe.py --root /repo \
  --zip /repo/target/dist/reproduction-new/arandu-nlu-integration.zip
```

Use diretório de saída novo; colisões são recusadas. Git push foi autorizado
no contexto e realizado sem force. Não criar tag/release nem deploy nesta missão.

## Próxima ação exata e pendências

Nenhum requisito implementável pendente. Próxima ação do proprietário: executar
a checklist abaixo em HA real e registrar o resultado, sem repetir a auditoria
ou alterar o runtime. Publicação/upload de release não disparados por proibição
expressa. Description/topics faltam somente para catálogo público: duas exceções
explicitadas no job oficial, nenhum check técnico desabilitado e nenhum PR
para hacs/default enviado. Frontend HACS, HA físico e próxima atualização não
foram validados neste ambiente.

## Procedimento exato no HA real — NÃO EXECUTADO

1. Faça backup completo incluindo options/.storage; atualize o add-on para
   0.4.2 pela Store, mantendo repositório e slug; aguarde build e inicie.
2. HACS → Custom repositories → URL https://github.com/jaimevictor/Arandu-NLU
   → categoria Integration. Confira ARANDU NLU instalável e baixe master ou
   release estável disponível.
3. Confira /config/custom_components/local_nlu/manifest.json:
   domain=local_nlu e version=0.4.2, sem custom_components aninhado.
4. Reinicie HA; confirme ausência de erros de setup/import e preservação da
   entrada antiga, entry_id, options, entidade e agente Assist. Não exclua
   config entry nem .storage.
5. Baixe diagnósticos: integration_version=service_version=0.4.2,
   compatible=true, contextual_enabled=true, protocol=4 e route=/v4/interpret.
6. Consulte entidade exposta/autorizada; confira a fala e nenhuma chamada de serviço.
7. Na próxima publicação autorizada, confira a atualização no HACS; baixe,
   reinicie e diagnostique a nova versão. Motor continua pela Store independente.

Checklist completa em [INSTALL.md](../../INSTALL.md#checklist-de-validação-em-ha-real).
Fixtures/probe não equivalem à validação residencial.
