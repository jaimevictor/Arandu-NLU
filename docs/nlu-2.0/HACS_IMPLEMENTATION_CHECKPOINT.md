# Checkpoint HACS — 0.4.1

## Estado

Implementação e validação local concluídas em 2026-10-07. Alterações
preexistentes não rastreadas preservadas: docs/codex/, especificação contextual
original e tools/codex-skill-check.ps1. Não ler/modificar Arandu-STT.

## Decisão de distribuição

Monorepo preservado. HACS instala custom_components/local_nlu; Store instala
addon/ com slug ptbr_nlu. Domínio, config flow e identificadores não mudam.
Versão única 0.4.1. Mínimos declarados HA 2025.3.0 (AddConfigEntryEntitiesCallback,
importado pelo componente; ausente em 2025.2.0) e HACS 2.0.5. Estes mínimos não
equivalem a um ensaio residencial dessas versões.

HACS por fonte oficial, zip_release=false, branch visível. Não há releases
publicadas no repositório na inspeção. No HACS 2.0.5 e no main consultado,
async_install_repository usa incondicionalmente download_zip_files quando
zip_release=true: a branch master tentaria baixar um asset de release inexistente.
Como publicar release é proibido nesta missão, fonte mantém instalação imediata
e atualizações por commits/release tags. O ZIP fixo plano é produzido e validado
para releases/instalação avançada; HACS não o consome na configuração atual.
Ativar zip_release requer decisão futura após publicar um primeiro asset válido.

## Fontes primárias consultadas

- https://www.hacs.xyz/docs/publish/integration/
- https://www.hacs.xyz/docs/publish/start/
- https://www.hacs.xyz/docs/publish/action/
- https://www.hacs.xyz/docs/faq/custom_repositories/
- https://github.com/hacs/integration/tree/adb7d83e33d24325535fb43b8226572405143757
  (repositórios integration.py/base.py, utils/validate.py, validate/brands.py,
  utils/backup.py; comparar tag 2.0.5).
- https://github.com/hacs/action/tree/1ebf01c408f29afcb6406bd431bc98fd8cbb15aa
  (Action recomenda container; referência main é mutável mesmo com action SHA).
- https://developers.home-assistant.io/blog/2024/04/30/store-runtime-data-inside-config-entry/
- https://github.com/home-assistant/core/blob/2025.3.0/homeassistant/helpers/entity_platform.py
- https://github.com/home-assistant/core/blob/2025.2.0/homeassistant/helpers/entity_platform.py

Contrato ZIP: HACS chama extractall diretamente no diretório local da integração;
manifest.json fica na raiz do ZIP, não custom_components/local_nlu/manifest.json.
Migração: instalação inicial sobrepõe arquivos no mesmo domínio; atualizações
gerenciadas fazem backup/substituição apenas do diretório do componente.
Config entries/options residem em HA .storage, fora desse diretório.

## Arquivos implementados

27 arquivos de produto/distribuição/testes/guias, listados integralmente no
[relatório](HACS_IMPLEMENTATION_REPORT.md#arquivos-alterados). Incluem metadados
HACS/manifest, versões/locks, allowlist e ZIP fixo, dois workflows, testes/probe,
staging Linux, ícone original reproduzível e documentação de migração/releases.
Nenhum src Rust ou Python runtime/config flow/diagnostics foi modificado.

## Validação concluída

- 11 testes HACS PASS no staging Linux Python 3.12.15; schemas oficiais PASS.
- Probe em container oficial HACS, sem rede: validators HACS/manifest/brand,
  reconhecimento Integration/domínio/destino, fonte master, reinstalação com
  backup real HACS e extração ZIP release PASS, usando fixtures de GitHub/HA.
  Não é instalação de frontend HACS nem validação residencial.
- Gate inicial PASS em target/hacs-full-gate.log. Gate final após correções PASS
  em target/hacs-final-gate.log: 157 Python únicos (42 skips pré-build executados
  no passe pós-build de 70 contextual/HTTP), 93 Rust, fmt/clippy/corpus/vendor/
  estrutura/versões/build release/smoke PASS. Ambiente Python 3.12.15/Rust 1.98.
- Revisões acharam mínimo HA incorreto, scanner sem recusa de credenciais curtas
  e versão de teste hardcoded. Corrigidos sem mudar runtime; gate final repetido
  e dois revisores independentes confirmaram PASS na mesma árvore final.
- Falha inicial no teste YAML: Ruby interpreta on não quoted como bool; workflows
  usam 'on' quoted agora. Falha inicial probe: script fora /hacs não importava
  pacote oficial; usar PYTHONPATH=/hacs no comando Docker.

Comando probe (Python no container oficial): docker run --rm --network none
--entrypoint python3 -e PYTHONPATH=/hacs --mount type=bind,source=<repo>,target=/repo,readonly
ghcr.io/hacs/action@sha256:dc92fdad2f6ffbe74bffb7269d781ea8e064f52d9bb486cdf3925d74e7ab6ebf
/repo/tests/mlp/hacs_official_probe.py --root /repo
--zip /repo/target/dist/0.4.1/arandu-nlu-integration.zip.

Pacotes finais gerados duas vezes, mesmos bytes/hashes/metadata; CRC/versões/
allowlist/symlinks/traversal/segredos conhecidos/colisões validados. ZIP plano
23 arquivos, SHA-256 07a8e1324d15cf55779e95130348a4309606416860f51cec3802c8c3609dd04b.
Demais hashes em HACS_IMPLEMENTATION_REPORT.md. Hash distribuição final
3b606880fa32fbe5b06811edc76932512c71b5501f222196cec256248753765c;
fingerprint gate 7b81e98074fe0d12705061ebcb7740b20ecf0a55f47b03f66069c05316e9a6c6.

Durante correções pré-commit, release.json gerado foi restaurado ao baseline
0.4.0 de HEAD para record final da nova candidata 0.4.1; a guarda não foi
afrouxada. Após entrega, mudanças distribuídas exigem próxima versão maior.

## Pendências externas e próxima ação exata

Implementação local completa; falta validar frontend HACS/HA residencial e
aparecimento de próxima versão, pois não há residência neste ambiente. Upload
release está automatizado mas não disparado: nenhuma tag/release/publicação
autorizada nesta missão. Description/topics faltam apenas para futura submissão
pública, com duas exceções explicitadas no CI; nenhum PR hacs/default enviado.

Entrega: commit seletivo e push fast-forward HEAD:master (autorização explícita
prévia na sessão), preservando arquivos preexistentes não rastreados. Conferir
Actions HACS após push e registrar resultado. Não publicar release/deploy.
Comandos: git status --short; git diff --cached --check; git push origin HEAD:master;
gh run list --workflow hacs.yml; git ls-remote origin refs/heads/master.

## Procedimento exato em HA real

1. Fazer backup HA completo com options/.storage e atualizar add-on 0.4.1 pela
   mesma Store/repositório, sem trocar identidade/slug; aguardar build/iniciar.
2. No HACS instalado, Custom repositories → URL jaimevictor/Arandu-NLU →
   Integration. Reconhecer ARANDU NLU, baixar master ou release estável disponível.
3. Verificar manifesto /config/custom_components/local_nlu/manifest.json,
   domain=local_nlu/version=0.4.1, sem caminho custom_components aninhado.
4. Reiniciar HA; conferir logs/setup, entrada antiga/entry_id/options e agente
   Assist preservados. Não excluir entrada nem .storage.
5. Baixar diagnósticos e conferir integration_version=service_version=0.4.1,
   compatible=true/contextual_enabled=true/protocol=4/route=/v4/interpret.
6. Consultar entidade exposta/autorizada; verificar fala e ausência de serviço.
7. Na próxima publicação autorizada, conferir update HACS; baixar/reiniciar,
   diagnosticar versão nova e verificar que Store continua independente.

Todos esses passos residenciais permanecem NÃO EXECUTADOS. A checklist completa
está em INSTALL.md; fixtures/probe não equivalem à instalação física.
