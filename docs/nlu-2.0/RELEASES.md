# Releases do produto e distribuição HACS

Cada produto possui uma versão única: add-on/config, crate/lockfiles, manifest
Python, release.json e tag de release `vX.Y.Z`. hacs.json declara mínimos HA/HACS,
não uma versão do produto: `version` não é um campo suportado nesse manifesto.

## Dois canais

| Componente | Canal | Destino | Identidade preservada |
| --- | --- | --- | --- |
| Rust | Add-on Store | addon/ | slug ptbr_nlu/repositório atual |
| Python | HACS custom Integration | custom_components/local_nlu/ | domínio/entry_id/options/unique_id |

HACS instala por fonte, `content_in_root=false`, `zip_release=false`, branch
visível. Antes da primeira release, master fornece instalação/atualizações por
commit. A release estável [v0.4.3](https://github.com/jaimevictor/Arandu-NLU/releases/tag/v0.4.3)
oferece versão etiquetada: o HACS extrai
somente custom_components/local_nlu do arquivo GitHub, não instala o add-on.

Na preparação de 0.4.2, a API pública GitHub não mostrou releases publicadas.
O instalador HACS 2.0.5 e main consultado chama
download_zip_files incondicionalmente com esse campo, inclusive para master.
Isso quebraria a instalação antes de um asset existir. A missão de suporte HACS
0.4.2 não autorizava publicação. A preferência por ZIP não supera instalação funcional.
Fonte é um método oficialmente suportado; não exige migração posterior.

## ZIP fixo e workflow

tools/release-package.py gera três ZIPs: add-on/versionado, integração/versionada
com caminhos completos, e **arandu-nlu-integration.zip** plano (manifest.json na
raiz). Datas, ordem, bytes textuais e modos são determinísticos; os arquivos
runtime/licenças/traduções/ícone são allowlisted. Não há testes, fixtures,
credenciais, vendor ou Rust no pacote Python. Cada ZIP tem SHA-256/metadata.
O ícone original Apache-2.0 é reproduzível com tools/generate-brand.py.

`.github/workflows/release-integration.yml` só roda em release estável publicada.
Faz checkout da tag, valida `v<versão>`, versões/hash de distribuição, testes,
gera os pacotes e verifica ZIP/CRC/allowlist/SHA. Anexa somente ZIP fixo/hash à
release correspondente, sem sobrescrever assets existentes. Não cria tag nem
release, não publica imagem e não executa deploy. Push comum roda validação,
jamais upload. Job de upload tem contents:write; os demais, contents:read.
Setup Python e imagem oficial HACS são fixados por SHA/digest. Checkout usa Git
anônimo no repositório público e commit SHA/tag validado, com sparse checkout
da árvore necessária; não grava credenciais nem executa operações de submódulos.
O gitlink legado sem URL é preservado no repositório e fica fora dos arquivos
materializados. Isso evita a falha de cleanup de actions/checkout sem modificar
conteúdo histórico ou relaxar permissões. Não há secrets customizados necessários:
só GITHUB_TOKEN para validador e upload, nos respectivos passos.

## Preparar a próxima release (mantenedor)

1. Atualize versões dos dois componentes/ambos lockfiles e documentos atuais.
   Preserve domínio, flow VERSION, entry_id e unique_id. Não atualize dependências
   incidentalmente. Confira mínimos HACS/HA se usar uma API nova.
2. Rode `python3 tools/distribution.py --record` após terminar arquivos distribuídos.
   Rode `./tools/mlp-check` (Windows: `pwsh -File tools/mlp-dev.ps1 -Task check`).
   Execute as duas revisões previstas em AGENTS.md e corrija achados materiais.
3. Gere pacotes: `python3 tools/release-package.py --output target/dist/X.Y.Z`.
   Confira `python3 tools/hacs.py --tag vX.Y.Z --zip target/dist/X.Y.Z/arandu-nlu-integration.zip`.
   Após autorização do proprietário, envie o commit e publique uma release estável
   com tag `vX.Y.Z` no commit validado. O workflow anexa ZIP/hash automaticamente.
4. Espere os checks/upload e execute checklist real em INSTALL.md. HACS e Store
   atualizam independentemente; reinicie HA e confirme versões efetivas/rota v4.

O workflow não cria uma release; o mantenedor publica após autorização da missão
e validação do commit. A correção de identidade 0.4.3 requer entrega instalável;
seu checkpoint registra o resultado real de tag/release/assets, separadamente
da validação residencial. Confira [MISSING_USER_RESIDENTIAL_FIX.md](MISSING_USER_RESIDENTIAL_FIX.md).
Não habilite zip_release sem primeiro assegurar asset compatível em toda release
oferecida. Uma mudança futura para ZIP deve manter filename fixo acima, conservar
o domínio e explicar que master deixa de ser instalável nesse modo no HACS atual.

## Validação oficial e futuro catálogo

O workflow HACS usa o container oficial da Action, digest congelado, sem permissão
de escrita/comentários. Apenas `description` e `topics` são ignorados: esses
metadados de catálogo ainda não existem no repositório GitHub; schema HACS,
manifesto, estrutura, branding local, licença e demais checks seguem ativos.
Essas exceções não substituem validação técnica nem concedem autorização HA.

Para candidatura futura a hacs/default: preencher descrição/topics úteis nas
configurações GitHub, retirar essas duas exceções, obter checks oficiais completos,
publicar/manter releases e documentação e cumprir os requisitos vigentes do
catálogo. HACS 2.0.5 exige branding no catálogo brands antigo; o validador atual
aceita brand/icon.png local. Não há PR automático a hacs/default nesta entrega.

Fontes: [integrações HACS](https://www.hacs.xyz/docs/publish/integration/),
[campos/requisitos](https://www.hacs.xyz/docs/publish/start/),
[Action oficial](https://www.hacs.xyz/docs/publish/action/),
[instalador/consumidor ZIP](https://github.com/hacs/integration/blob/adb7d83e33d24325535fb43b8226572405143757/custom_components/hacs/repositories/base.py),
[schema atual](https://github.com/hacs/integration/blob/adb7d83e33d24325535fb43b8226572405143757/custom_components/hacs/utils/validate.py).
