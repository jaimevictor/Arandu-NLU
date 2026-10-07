# Checkpoint HACS — 0.4.2

## Estado

Implementação e gate local final concluídos em 2026-10-07. Pronto para commit
seletivo e push master autorizado. Não publicar release/tag nem fazer deploy.
Arquivos preexistentes preservados e fora dos commits: docs/codex/,
docs/nlu-2.0/ARANDU_NLU_CONTEXTUAL_CAPABILITIES_SPEC.md e tools/codex-skill-check.ps1.
Não foi lido/modificado Arandu-STT ou conteúdo do gitlink legado.

## Distribuição implementada

Monorepo preservado: HACS custom Integration em custom_components/local_nlu/;
Store em addon/, slug ptbr_nlu. Domínio/config flow VERSION=1/entry_id/options/
unique_id de conversa preservados. Produto único 0.4.2; mínimo HA2025.3.0
(AddConfigEntryEntitiesCallback ausente em2025.2.0) e HACS2.0.5.
Esses mínimos não equivalem a ensaio residencial nessas versões.

HACS por fonte oficial: content_in_root=false, zip_release=false, branch visível.
Não existiam releases publicadas na inspeção. No HACS2.0.5 e main consultado,
zip_release=true chama download_zip_files sem fallback, inclusive master;
habilitá-lo impediria instalar antes de asset publicado, e publicar é proibido.
Fonte oferece instalação/atualização agora e versões de releases futuras.
ZIP fixo plano também é gerado; HACS atual não consome esse asset. É uma escolha
funcional completa, sem obrigação de mudar de método depois da primeira release.

Contrato ZIP: extractall diretamente no diretório da integração, portanto
manifest.json na raiz, nunca custom_components/local_nlu/manifest.json.
Allowlist23 arquivos de runtime/licenças/traduções/ícone, CRC/versões/modos/hash,
recusa traversal, duplicatas, symlinks, arquivos extras e credenciais conhecidas.
Pacotes addon/versionado e integração/versionada continuam disponíveis.

Workflow release published estável: checkout público da tag explícita refs/tags,
validação semver/versões/digest/tests/ZIP/hash, upload apenas ZIPfixo/SHA à release
existente. Não cria tag/release, não sobrescreve asset nem roda upload em push.
Validação read-only; contents:write somente no job de release. SetupPython e
container oficial HACS são fixados por SHA/digest; checkout Git não usa token.

## Arquivos alterados

Metadados/versionamento: hacs.json, manifest.json, addon/config.yaml, Cargo.toml
do engine, ambos Cargo.lock, release.json.
Ferramentas/CI/testes: tools/hacs.py, release-package.py, distribution.py,
check-mlp-package.py, dev/run.py, dev/DEPENDENCIES.md, generate-brand.py;
.github/workflows/hacs.yml e release-integration.yml; tests/mlp/test_distribution.py,
test_hacs.py, hacs_official_probe.py; custom_components/local_nlu/brand/icon.png.
Guias: README, INSTALL, DEPLOYMENT, RELEASES, este checkpoint/relatórioHACS e
nota histórica em CONTEXTUAL_IMPLEMENTATION_REPORT.
Lista completa/matriz de aceitação: HACS_IMPLEMENTATION_REPORT.md.
Nenhum Rustsrc/Pythonruntime/configflow/diagnostics modificado.

## Fontes oficiais consultadas

- https://www.hacs.xyz/docs/publish/integration/
- https://www.hacs.xyz/docs/publish/start/
- https://www.hacs.xyz/docs/publish/action/
- https://www.hacs.xyz/docs/faq/custom_repositories/
- https://github.com/hacs/integration/tree/adb7d83e33d24325535fb43b8226572405143757
  (integration.py/base.py, schema, brands e backup); comparar tag2.0.5.
- https://github.com/hacs/action/tree/1ebf01c408f29afcb6406bd431bc98fd8cbb15aa
  (wrapper usa imagem main mutável; congelamos diretamente o digest).
- https://github.com/home-assistant/core/blob/2025.3.0/homeassistant/helpers/entity_platform.py
  e versão2025.2.0 (contraprova do mínimo API).
- https://developers.home-assistant.io/blog/2024/04/30/store-runtime-data-inside-config-entry/
- https://github.com/actions/checkout/blob/main/src/git-auth-helper.ts
  e https://github.com/actions/checkout/issues/610 (falha de gitlink semURL).

## Testes reais concluídos

Gate0.4.1 completo PASS. Após correções CI/revisão, gate0.4.2 final PASS em
target/hacs-0.4.2-qualified-gate.log:158 Python únicos,93 Rust,70 contextual/HTTP
pós-build; fmt/clippy/corpus/vendor/pacote/versões/buildrelease/smokePASS.
42skips HTTP pré-build foram executados no passe pós-build, não omitidos.
Ambiente DockerLinux Python3.12.15/Ruby3.4.4/Rust1.98.0; hostPython3.10 inadequado.

12testes HACS PASS, incluindo Git real com gitlinksemURL, ausência de credentials,
tag ausente+branch presente recusada e tag escolhida quando branch diverge.
Duas revisões independentes confirmaram PASS no digest final.
Probe no container oficial, sem rede, PASS: schemas/validators HACS/manifest/
brand; reconhecimento Integration/domínio/destino; sourceinstall; reinstall/
backup real HACS; consumidor ZIP plano. TransporteGitHub e executorHA são
fixtures. Não é frontend HACS/instalação residencial.

Pacotes0.4.2 gerados duas vezes com mesmos bytes/hashes/metadata:
- addon612 arquivos:2866052c4691d53f8cdecf465fbd92e0d64700af239c3a4e349f0f7739faff31
- integração versionada23:2b7ef30bf5305eef754b7bd0dccd73f4a51db344e6afa5eb85b94a4278c8668c
- ZIPfixo23:f8851a4ed35afc64bd5e5d7c6f4c7858d3aa7112215ed988eed2d833f685e645

Digest distribuição dcb5ec263e7b57f8c5e15640311bb72bdc08688b99cd92afa60e6695075d38b6.
Fingerprint executável d9aaa213c6b1e659374ec577e1331aca6e7a529752f81f6d0ef1a6ed87ec5ab2;
host e staging comparados iguais antes de executar o gate final.

## Problemas encontrados/resolvidos

MínimoHA inicial baixo; scanner permitia credenciais curtas/JSON; teste fixava
0.4.1. Corrigidos com contraprovas. YAML on não quoted virou bool no Ruby:
quoted nos workflows. Probe fora /hacs exigiu PYTHONPATH=/hacs.

Primeiro push6b11213 (0.4.1) confirmado em master. Run37625912914:
official-hacsPASS, distributionfalhou antes dos testes no cleanup actions/checkout
por gitlink legado semURL. Git checkout anônimo elimina foreach sem tocar legado;
sparsecone ainda materializava gitlink e falhou no teste. Sparse não-cone com
exclusão final passou. Staging antigo falhou no teste de workflow até sincronizar.
Fetch de release foi qualificado refs/tags para impedir fallback a branch.
Nova versão0.4.2 respeita guarda após commit0.4.1. Durante candidata não commitada,
release.json gerado foi restaurado somente ao baselineHEAD antes do record final;
não afrouxar a guarda, próxima mudança distribuída exige próxima versão maior.

## Comandos para reproduzir

- Windows completo:ferramentas via pwsh -File tools/mlp-dev.ps1 -Task check.
- Linux ambiente pinado:./tools/mlp-check.
- Distribuição:python3 tools/hacs.py --tag v0.4.2 --zip target/dist/0.4.2/arandu-nlu-integration.zip.
- Empacotar em saída nova:python3 tools/release-package.py --output target/dist/reproduction-new.
- Probe:docker run --rm --network none --entrypoint python3 -e PYTHONPATH=/hacs
  --mount type=bind,source=<repo>,target=/repo,readonly
  ghcr.io/hacs/action@sha256:dc92fdad2f6ffbe74bffb7269d781ea8e064f52d9bb486cdf3925d74e7ab6ebf
  /repo/tests/mlp/hacs_official_probe.py --root /repo
  --zip /repo/target/dist/0.4.2/arandu-nlu-integration.zip.
- Entrega:git diff --check; git add somente arquivos acima; git commit;
  git push origin HEAD:master; gh run list --workflow hacs.yml;
  git ls-remote origin refs/heads/master. Sem force/tag/release/deploy.

## Próxima ação exata e pendências

Enviar commit seletivo0.4.2 para master e conferir ambos jobs no CI.
Registrar resultado remoto aqui e no relatório. Implementação local completa.
Upload release não foi disparado (publicação proibida). Description/topics faltam
somente para catálogo público: exceções explicitadas no job oficial, nenhum
check técnico desabilitado, nenhum PR hacs/default enviado.
HA físico/frontendHACS/próxima atualização dependem da instalação do proprietário.

## Procedimento exato no HA real — NÃO EXECUTADO

1. Backup completo com options/.storage; atualizar add-on0.4.2 no mesmo repositório/
   slug pela Store, aguardar build e iniciar.
2. HACS → Custom repositories → URLhttps://github.com/jaimevictor/Arandu-NLU →
   categoriaIntegration. Reconhecer ARANDU NLU instalável e baixar master ou
   release estável disponível.
3. Conferir /config/custom_components/local_nlu/manifest.json:domainlocal_nlu/
   version0.4.2, sem custom_components aninhado.
4. ReiniciarHA sem erros de setup/import; preservar entrada antiga/entry_id/options,
   entidade e agenteAssist. Não excluir configentry nem .storage.
5. Baixar diagnósticos:integration_version=service_version=0.4.2, compatible=true,
   contextual_enabled=true, protocol=4 e route=/v4/interpret.
6. Consultar entidade exposta/autorizada, conferir fala e nenhuma chamada de serviço.
7. Na próxima publicação autorizada, conferir updateHACS; baixar/reiniciar e
   diagnosticar versão nova. Motor continua atualizável pela Store independente.

Checklist completa em INSTALL.md. Fixtures/probe não equivalem à prova física.
