# Implementação contextual Arandu NLU 0.4.0

Relatório histórico da implementação funcional 0.4.0. A distribuição atual
0.4.1 usa HACS para a integração Python e Add-on Store para o Rust; siga
[INSTALL.md](../../INSTALL.md) e [RELEASES.md](RELEASES.md). Evidências abaixo
permanecem da versão/contexto em que foram medidas.

Data: 2026-10-07. Escopo: F0–F7 da especificação contextual. Rust continua
passivo; Python continua a única fronteira de autorização/execução HA.
Não foi alterado o projeto Arandu-STT nem adicionado serviço externo obrigatório.

## Resultado funcional

Resolução composicional por categoria e tokens, comparação de conjuntos por
nome e cômodo, desligamento coletivo com exclusões, consultas ambientais,
agregações informativas, diálogo vinculado a contexto e dispositivos pessoais
estão implementados. A matriz detalhada de requisito/arquivo/teste está em
[CONTEXTUAL_GAP_COVERAGE.md](CONTEXTUAL_GAP_COVERAGE.md).

Para conjunto maior que 32, o produto recusa todo o pedido e informa o limite.
Essa é uma alternativa explicitamente permitida pela especificação. Não há
truncamento nem execução parcial silenciosa por excesso de alvos.

## Evidências por fase

- F0: gate baseline completo PASS; 108 testes Python (9 skips antes do build),
  90 Rust, 32 contextual com HTTP e smoke release. Python host 3.10 é inadequado;
  execução suportada usou container Python 3.12/Rust 1.98.
- F1: cinco testes HTTP Rust, três testes específicos de diagnóstico/fala HA.
- F2: nove testes Rust contextual e cinco Python específicos; clippy PASS.
- F3: dez testes acceptance com Rust HTTP e executor real sobre HA simulado.
- F4: 14 acceptance (incluindo matriz parametrizada) e 32 regressões PASS.
- F5: 20 acceptance, 32 regressões e clippy PASS.
- F6: 27 acceptance, 32 regressões e clippy PASS. Fontes BLE foram fixtures.
- F7: gate oficial PASS, 93 testes Rust, 146 testes Python únicos; 70 testes
  contextual/HTTP repetidos após build. Os 42 skips do primeiro passe são
  testes HTTP executados no segundo passe, não ensaios omitidos. Duas revisões
  read-only aprovaram o mesmo código final após corrigir suas contraprovas.
  Builds/smokes amd64, aarch64 emulado e amd64 do ZIP extraído passaram.
  Os dois ZIPs foram gerados duas vezes com bytes idênticos; integração extraída
  passou 70 testes com fixtures do repositório e Rust HTTP real.

Os checkpoints registram falhas encontradas e correções, inclusive ambiente host,
colisão entre gerações de fixtures e whitelist do pacote. Alterações preexistentes
do usuário em docs/codex, ferramenta de skills e especificação original foram
preservadas.

## Reprodução

No Windows, `pwsh -File tools/mlp-dev.ps1 -Task check` executa `tools/mlp-check`
no ambiente oficial Docker. O gate inclui lint/formatação, Rust, Python, corpus,
pacote/versões, HTTP real e smoke. Testes contextual*.py são repetidos após o
build com `ARANDU_NLU_BINARY` definido para não deixar os ensaios HTTP skipped.

O corpus externo é o CSV congelado no commit e SHA-256 descritos em
`data/contextual/provenance.json`; foi obtido por URL imutável e verificado,
sem ler/modificar o checkout Arandu-STT. `contextual-evaluate.py --corpus-csv`
permite esse fluxo sem dependência de diretório irmão. Métricas são conformidade
interna, não acurácia independente nem sucesso residencial.

## Atualização

Instale o ZIP/add-on 0.4.0 mantendo o slug ptbr_nlu. Substitua separadamente
`custom_components/local_nlu/` pelo ZIP da integração 0.4.0 e reinicie o HA.
Selecione o agente no Assist e confira diagnóstico de versão/protocolo/rota.
[INSTALL.md](../../INSTALL.md) e [DEPLOYMENT.md](DEPLOYMENT.md) trazem opções,
bindings, exposição, backup e rollback. Nenhum deploy residencial foi realizado.

## Limitações reais

Não há HA residencial nem hardware BLE nesta validação. O adaptador usa fonte
de área dinâmica e timestamp autorizado; não estima localização, e jamais usa
área cadastrada como posição atual. Timestamp ausente/antigo/futuro ou área
desconhecida gera resposta de indisponibilidade.

Aliases pessoais e bindings não concedem permissão nem comprovam propriedade.
`meu celular` exige alias explícito. A bateria sem política temporal específica
usa o valor vivo do HA e não afirma data de observação.

Sessões são efêmeras: reinício de HA/integração invalida pendências. Recomeçar
pipeline com o mesmo conversation_id/usuário/origem pode continuar durante TTL.
Uma falha física após efeito não pode ser revertida atomicamente; executor para
o restante, informa parcial/incerto e não repete automaticamente.

Benchmarks excluem STT/TTS e latência real de serviços HA. ARM em Docker neste
host Windows é emulado; não é prova de desempenho ARM nativo.

## Gate, cobertura e recusas

Fingerprint normalizado de código, testes e ferramentas executados:
`04165cf4af8fc290edd7ff015dfd5358c24f0dd6cc9c99b242a2f0ec61fbb87c`.
O hash de distribuição em release.json é separado:
`d7abcb62ed457fe6ad38ec3a6467a227fb978d6dd0142a5c33e1bec9ce32a7f5`.
Host e staging Linux tiveram o mesmo fingerprint. Nenhuma dependência foi
atualizada; manifests, lockfiles, ZIPs e diagnóstico informam 0.4.0.

| Validação | Resultado real |
| --- | --- |
| fmt / clippy -D warnings / corpus determinístico / vendor | PASS |
| Rust workspace | 93 PASS |
| Python | 146 únicos, todos executados entre pré/pós-build |
| Contextual HTTP Rust + Python | 70 PASS, incluindo 38 novos testes |
| Smoke release / health antigo / diagnostics / v4 | PASS |
| Produto / segurança, privacidade, licenciamento e pacote | duas revisões PASS |
| Corpus externo completo | 1.946 frases, 165 intents |
| Reconhecimento linguístico | 1.942/1.946 (99,79%) |
| Semântica, parâmetros e alvos checados | 1.910/1.946 (98,15%) |
| Planos válidos | 1.901/1.946 (97,69%) |
| Conclusão simulada: ação, consulta ou cancelamento esperado | 1.908/1.946 (98,05%) |
| Intents com algum caso reconhecido / concluído | 165/165 e 161/165 |

As métricas não são acurácia independente: o corpus é referência interna,
parte de seus templates participa da gramática, e os serviços HA são simulados.
Planos não são considerados execução. Conclusão também inclui cancelamentos
corretos; por isso pode superar a quantidade de planos.

Dos 38 casos sem conclusão no turno isolado: 22 pedem continuação (duração
do calendário ou mídia), seis carecem de confirmação/referência anterior,
quatro dependem de fonte/configuração, dois são ambíguos (`para de tocar`
aparece para mídia e alarme), dois recusam frases com negação e dois permanecem
no_match na família de declarações de estado. Estas duas frases declarativas
sem pergunta explícita são uma limitação linguística existente, documentada
como interpretation_failure, sem inflar o resultado. A expressão legacy
`onde está meu telefone` consulta localização no v4: sem alias/aparelho/provider
deve informar ausência, não acionar ringtone arbitrariamente.

Fixtures de previsão agora oferecem horizonte real de oito dias a partir do
relógio HA, e andares usam floor_registry/floor_id simulados. Essas correções
não derivam resultados esperados da saída do motor. As novas capacidades têm
contraprovas de autorização, alvos, ausência, ambiguidades, resposta falada e
efeitos/zero efeitos no executor. Veja [REVIEWS.md](REVIEWS.md).

Resultados por frase/intenção e classificação estão em
[coverage.json](../../data/contextual/coverage.json) e
[coverage.csv](../../data/contextual/coverage.csv). O inventário de requisitos
contextuais está na matriz; não se afirma suporte a linguagem livre irrestrita.

## Benchmarks medidos

Linux WSL2 x86_64, AMD Ryzen 7 5700X, Python 3.12.15, Rust 1.98.0 release.
Medição sem builds concorrentes. Rust puro: 1.000 amostras após 100 warmups,
cinco formas de comando, todas produzindo planos. HTTP/Python: 200 amostras
após 20 warmups, alternando consulta e controle de uma entidade exata. São
workloads distintos: não comparar diretamente seus tempos nem somar percentis.

| Entidades | Rust puro P50/P95/P99 ms | HTTP roundtrip P95 ms | Validação + executor Python P95 ms | Fluxo quente observado P50/P95/P99 ms | RSS Rust kB |
| --- | --- | --- | --- | --- | --- |
| 64 | 0,0307 / 0,0550 / 0,0882 | 0,8259 | 0,2156 | 0,9286 / 1,1537 / 1,3611 | 1.796 |
| 512 | 0,1067 / 0,1558 / 0,2251 | 0,7888 | 0,1881 | 0,8813 / 1,0877 / 1,1761 | 3.880 |
| 4.096 | 1,8023 / 2,1624 / 2,9431 | 0,7677 | 0,1735 | 0,8779 / 1,0580 / 1,1652 | 17.484 |

| Entidades | Compile catálogo Rust P50 ms | Snapshot Python frio P50/P95 ms | Registro catálogo por HTTP ms |
| --- | --- | --- | --- |
| 64 | 0,7594 | 1,9152 / 2,1355 | 7,8394 |
| 512 | 7,5918 | 15,2278 / 15,2797 | 11,0178 |
| 4.096 | 67,5873 | 107,1801 / 116,0444 | 83,5136 |

A meta histórica P95 <50 ms foi atendida para interpretação quente nesta
máquina. Construção/registro de catálogo frio de 4.096 entidades supera 50 ms;
o cache evita esse custo em pedidos normais. Não extrapolar para STT/TTS,
serviços HA físicos, reconstruções de catálogo, Bluetooth ou ARM nativo.
Dados de cada fase e ambiente: [benchmark-core.json](../../data/contextual/benchmark-core.json)
e [benchmark-http.json](../../data/contextual/benchmark-http.json).

## Artefatos e atualização independente

| ZIP local | Arquivos | SHA-256 |
| --- | --- | --- |
| target/dist/0.4.0/arandu-nlu-addon-0.4.0.zip | 612 | d159da2485a8f5530487dba0421bb13b6f25d7525440103e16cdc43c229b1561 |
| target/dist/0.4.0/arandu-nlu-integration-0.4.0.zip | 22 | 197d0cb94bf73bf429b6571a6117b48c9c2d6f2aa0205d12243ad069a44659a3 |

Os ZIPs ficam em target, fora do Git, e podem ser reproduzidos com
tools/release-package.py. CRC, bytes extraídos, modos Unix, versões e duas
gerações independentes foram verificados. Testes da integração extraída usaram
fixtures do repositório: os ZIPs de instalação não incluem todo o suporte de
testes. Não se declara gate standalone inexistente dentro de um ZIP.

1. Faça backup das opções HA e do componente Python.
2. Atualize o add-on para 0.4.0 no mesmo repositório/slug ptbr_nlu; Supervisor
   compila a imagem. Para instalação local nova, extraia addon/ em /addons/arandu_nlu.
3. Substitua separadamente /config/custom_components/local_nlu/ pelo componente
   Python 0.4.0 e reinicie o Home Assistant, preservando entrada e opções.
4. Selecione o agente no Assist; confira versões efetivas, protocolo 4,
   contextual_enabled e /v4/interpret nos diagnósticos; teste consulta simples
   antes de controle. Configure aliases/bindings e timestamp BLE conforme DEPLOYMENT.md.
5. Rollback: restaure add-on e componente Python da mesma versão de backup,
   reinicie e confira diagnósticos; contextual_enabled=false retoma o fluxo anterior.

Imagens scratch reais amd64 e aarch64 emulada, usuário 65534:65534, sem porta
publicada no host, passaram diagnóstico + health + consulta + controle coletivo.
Imagem amd64 compilada do ZIP extraído também passou. Notices de runtime foram
extraídos das três imagens e comparados às fontes. IDs/tamanhos, ZIPs, hashes de
logs e resumo do gate estão em [image-validation.json](../../data/contextual/image-validation.json),
[package-validation.json](../../data/contextual/package-validation.json) e
[contextual-validation.json](../../data/contextual/contextual-validation.json).

## Entrega Git

O usuário autorizou expressamente push direto para master ao final. A branch
local foi avançada por fast-forward para origin/master a443e8f, cuja árvore era
idêntica ao ponto inicial, preservando todas as alterações. A entrega usa commit
seletivo e `git push origin HEAD:master`, sem force push. Código entregue no commit
`477d028235347838cbdd5bde272ec376cbdd8fd8`, com push e igualdade HEAD/master remoto
confirmados. Esta atualização documental não altera o fingerprint executável.
O último commit é verificável por `git log -1` e `git ls-remote origin refs/heads/master`. Nenhum release,
deploy residencial, alteração de STT ou publicação de imagens foi solicitado.
