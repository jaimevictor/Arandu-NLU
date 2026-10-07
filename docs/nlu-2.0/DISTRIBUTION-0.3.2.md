# Distribuição 0.3.2

## Causa e correção

O GitHub continha dois manifestos com slug `ptbr_nlu`: `addon/` em 0.3.1
e uma cópia antiga em 0.2.0. O Supervisor descobre `config.yaml`, `config.yml`
e `config.json` recursivamente e guarda os apps por hash do repositório + slug.
Uma duplicata pode sobrescrever a outra no catálogo; esse mecanismo explica
a distribuição inconsistente, sem provar qual manifesto venceu numa residência.

Foram conferidos os 597 caminhos da cópia antiga antes de removê-la.
Todos existem em `addon/`, que também inclui os módulos contextuais e avisos
de licença atuais. A URL pública e o slug foram preservados; mover a pasta
não muda a identidade do app. O gerador de loja agora usa `addon/` e inclui
`licenses/`, antes omitido apesar de constar no Dockerfile.

Fontes primárias consultadas em 2026-10-06:
[repositórios](https://developers.home-assistant.io/docs/apps/repository/),
[manifesto e build args](https://developers.home-assistant.io/docs/apps/configuration/),
[descoberta/identidade](https://github.com/home-assistant/supervisor/blob/main/supervisor/store/data.py),
[atualização Git do catálogo](https://github.com/home-assistant/supervisor/blob/main/supervisor/store/repository.py).

## Verificações

`tools/distribution.py` integra o gate oficial: valida YAML usando o Ruby já
pinado, descobre manifestos do checkout publicado, rejeita duplicatas inclusive
em pastas aninhadas, verifica Dockerfile/recursos/módulos/arquiteturas e compara
manifestos, crate, os dois lockfiles e âncoras explícitas de documentação atual.
Não compara números históricos em relatórios. `release.json` registra versão e
digest normalizado dos arquivos distribuídos e scripts de empacotamento;
alterar esses inputs sem versão nova impede registrar a distribuição.

O gate final é registrado em `target/distribution-0.3.2-final-check.log`.
Resultado: **MLP CHECK PASS**; 108 testes Python (9 de distribuição),
90 testes Rust e passe contextual de 32 testes incluindo 9 E2E Rust HTTP.
Fingerprint do gate: `3bac346365a590e54b3a5e726eaab83111b2bf024f7f662d6a0fbc368a9a0c2a`.
Inclui testes Python de segurança/protocolo/contexto e distribuição, Rust,
fmt/clippy/build offline e E2E Rust HTTP com executor Python real e HA simulado.
O parser e o executor não foram alterados; dependências e STT permanecem.

Builds Docker `amd64` e `aarch64` passaram com labels `io.hass.version=0.3.2`,
arquitetura correspondente e usuário `65534:65534`. Ambas as imagens iniciaram
sem rede externa e passaram `/health` e o smoke contextual:
ação, consulta de temperatura e cancelamento, via `/v4/catalog` e `/v4/interpret`,
com contagem de serviços executados no HA simulado. ARM64 foi executado sob
emulação, não em hardware físico. A imagem construída do ZIP extraído também
passou esse smoke. Logs locais: `target/distribution-0.3.2-{amd64,aarch64,zip-build}.log`.

## Pacotes

`python3 tools/release-package.py` gera dois ZIPs separados, sem código legado,
cache, artefatos de build ou dados residenciais. As saídas existentes são
preservadas; o empacotador recusa colisões antes de escrever. Testes verificam
reprodutibilidade byte a byte, CRC, lista de arquivos, conteúdo extraído e versões.

| Arquivo em target/dist/0.3.2 | Arquivos | SHA-256 |
|---|---:|---|
| arandu-nlu-addon-0.3.2.zip | 612 | 4d1e5225ce6d2afdb0a310f596b920393f22eb94fd10a44eb9bd93d19aed4cd7 |
| arandu-nlu-integration-0.3.2.zip | 19 | 69861df975f310838c973b9caeccdced6d141ca831cf5589b93c4b26409b0f19 |

A loja gerada em `target/dist/store-0.3.2` foi inspecionada pelo mesmo verificador:
um único add-on em `addon/`, versão 0.3.2 e recursos Docker presentes.

## Revisões e limites

Duas revisões read-only da distribuição foram concluídas: produto e
segurança/licenciamento/limite de pacote. A revisão de segurança encontrou
sobrescrita de saídas; foi corrigida com preflight e teste de preservação,
e a revisora confirmou o fechamento. Produto também tentou manifestos JSON
aninhados e confirmou a rejeição. Sem achados materiais restantes no escopo.
Digest revisado: `58a8700b0cc449bd01f726cd25a0293c182cde6486781eaa7b88fc13449138d9`.

Não há Supervisor/HA residencial disponível. Refresh real da loja, atualização
de uma instalação existente, persistência de opções e execução em Assist real
não foram ensaiados; o comportamento de identidade foi conferido no código
oficial. [INSTALL.md](../../INSTALL.md) descreve o procedimento e rollback.
Nenhuma GitHub Release ou implantação residencial foi realizada. As evidências
anteriores do build 2.0.0 continuam históricas, sem reetiquetar seus resultados.
