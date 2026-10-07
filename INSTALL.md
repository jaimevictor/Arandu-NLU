# Arandu NLU — instalação e atualização

Versão atual: `0.4.0` (motor contextual 2.0).

O add-on e a integração Python precisam ser atualizados independentemente.
Após substituir `custom_components/local_nlu/`, reinicie o Home Assistant.
Baixe os diagnósticos da integração em Configurações → Dispositivos e serviços
e confira `integration_version`, `service_version`, `protocol=4`,
`contextual_enabled=true`, `route=/v4/interpret` e `compatible=true`.
Uma etiqueta do Supervisor sozinha não comprova qual protocolo o Assist usa.

Configuração de exclusões, associações de aparelhos e localização com timestamp:
[guia contextual](docs/nlu-2.0/DEPLOYMENT.md#capacidades-contextuais-040).

São dois componentes: o add-on Rust em `addon/` e a integração Python em
`custom_components/local_nlu/`. A loja instala e atualiza somente o add-on.
Instalar o repositório não instala a integração. Ambos compartilham a versão do produto.

## Instalação

1. Em Configurações → Apps/Add-ons → Loja → ⋮ → Repositórios, adicione
   `https://github.com/jaimevictor/Arandu-NLU`. Instale **ARANDU NLU** e inicie.
   O Supervisor compila diretamente `addon/Dockerfile`, sem imagem remota.
2. Extraia `arandu-nlu-integration-0.4.0.zip` no diretório de configuração HA.
   O resultado deve ser `/config/custom_components/local_nlu/manifest.json`.
   Alternativamente copie essa pasta do mesmo commit. Reinicie o Home Assistant.
3. Adicione Local NLU em Dispositivos e serviços. Configure o endpoint privado
   indicado pelo Supervisor e selecione ARANDU NLU no pipeline Assist.

Somente `addon/` é publicado. Nome **ARANDU NLU**, slug `ptbr_nlu` e URL do
repositório permanecem. A identidade usa hash do repositório + slug, não o nome da pasta.
Assim, a mudança de pasta não exige reinstalar ou apagar configurações.
[Implementação do Supervisor](https://github.com/home-assistant/supervisor/blob/main/supervisor/store/data.py).

O hostname de loja para a URL acima é `http://18b0d50a-ptbr-nlu:11555`;
confirme o hostname na sua instalação. Para instalação local, copie apenas
`addon/` para `/addons/arandu_nlu`: o hostname é `http://local-ptbr-nlu:11555`.
Não crie uma segunda cópia com o mesmo slug no mesmo repositório local.
Trocar uma instalação de loja por local altera o hash da identidade; esse caminho
é para novas instalações, não é o procedimento de migração abaixo.
Sem Supervisor, compile `addon/` e conecte o container à rede privada do HA.
Nenhuma porta é publicada no host pela configuração do add-on.

## Migrar do add-on antigo / atualizar

Se a instalação existente for **local**, substitua o conteúdo da pasta já
usada em `/addons/` pelo conteúdo de `addon/`, mesmo que a pasta antiga se
chame `ptbr_nlu`. Não mantenha dois manifestos locais com esse slug. Preserve
os dados/configurações do app e siga refresh, atualização/rebuild e restart
abaixo; não troque para o repositório GitHub durante essa migração.

1. Faça backup completo do HA e guarde as opções da integração e do add-on.
2. Na loja, use ⋮ → Verificar atualizações (Check for updates). Espere o catálogo
   atualizar. Confira que **ARANDU NLU** oferece **0.4.0**, mantendo o mesmo identificador.
   Não remova e adicione o repositório a cada atualização.
3. Na página do add-on, execute **Atualizar**. Como não existe campo `image`,
   o Supervisor reconstrói a imagem a partir da pasta publicada. Espere o build terminar;
   confira os logs do Supervisor e a versão instalada, não apenas a versão disponível.
4. Inicie/reinicie o add-on e confira seus logs. `GET /health` deve responder
   `{"status":"ok","version":1}`. Esse 1 é a versão do protocolo de saúde,
   não a versão do release.
5. Atualize manualmente `/config/custom_components/local_nlu/` com o ZIP da
   integração **0.4.0**. Preserve `/config/.storage/` e as opções existentes;
   não apague nem recrie a entrada da integração.
6. Reinicie o Home Assistant. Confira `manifest.json` com versão **0.4.0**,
   o endpoint e a opção `contextual_enabled=true`. Verifique exposição ao Assist,
   permissões do usuário e área do satélite.
7. Teste uma consulta e uma ação contextual com entidades reais configuradas,
   por exemplo “Qual é a temperatura aqui?” e “Liga o ar”.
   Confira resposta e histórico dos serviços. Esse passo exige a instalação real.

Publicação em GitHub, atualização do catálogo, instalação/build e reinicialização
são passos separados. Um push não altera o container que já está rodando.
Se o catálogo continuar antigo, confira URL/branch padrão `master`, conexão e logs
do Supervisor. Se a versão disponível estiver correta mas a instalada estiver antiga,
resolva o erro do build antes de tentar novamente. Não apague configurações.
[Atualização do repositório no Supervisor](https://github.com/home-assistant/supervisor/blob/main/supervisor/store/repository.py).

## Rollback

Restaure o backup do add-on e da configuração HA anterior à atualização,
ou reinstale explicitamente o pacote/imagem anterior junto com a integração
da mesma versão e reinicie ambos. Desativar `contextual_enabled` retorna ao
fluxo anterior de interpretação. A integração mantém suas configurações em
HA; o Rust não mantém um banco persistente. Não reinstale o Home Assistant.

## Build e pacotes reproduzíveis

Em Windows com Docker Linux, execute `./tools/mlp-dev.ps1 -Task check`.
Em Linux com as ferramentas pinadas, execute `./tools/mlp-check`.
Para a imagem amd64: `./tools/mlp-dev.ps1 -Task image`.
Build manual: `docker build --network none --platform linux/amd64 --build-arg
BUILD_ARCH=amd64 --build-arg BUILD_VERSION=0.4.0 -t local-nlu:0.4.0-amd64 addon`.
Para ARM64 use `--platform linux/arm64` e `BUILD_ARCH=aarch64`.
O builder usa digest OCI multi-arquitetura pinado e crates vendorizados.

Com Python 3.11+ e Ruby instalados:
`python3 tools/release-package.py` produz em `target/dist/0.4.0/`:

- `arandu-nlu-addon-0.4.0.zip`: `repository.yaml` e a pasta `addon/` completa.
- `arandu-nlu-integration-0.4.0.zip`: somente `custom_components/local_nlu/`.
- Checksums SHA-256 e `packages.json`.

O empacotador verifica CRC, lista de arquivos, bytes extraídos e versões.
Datas ZIP, ordem, modos Unix e conteúdo textual são normalizados.
`python3 tools/make-store-repo.py --output target/dist/store-0.4.0`
gera uma estrutura de loja isolada com `addon/`, incluindo avisos de licença;
recusa sobrescrever saída não vazia. O GitHub principal já tem essa estrutura.

## Procedimento de versionamento

Atualize os manifestos do add-on/integração, Cargo.toml e ambas as entradas
`local-nlu` dos lockfiles, README e a linha “Versão atual” deste guia.
Após preparar uma versão maior que a registrada, execute
`python3 tools/distribution.py --record`. Isso registra em `release.json`
o hash dos arquivos distribuídos e dos scripts de empacotamento.
Mudanças nesses arquivos sem nova versão falham no gate. Dependências não são
atualizadas por esse comando. Relatórios e números históricos ficam preservados.

Execute gate completo, build e smoke HTTP contextual, gere/verifique os dois ZIPs,
revise o diff e abra PR para `master`. Nenhum script publica GitHub Release
ou altera uma instalação residencial. HACS pode ser avaliado futuramente,
sem fazer parte deste fluxo.
