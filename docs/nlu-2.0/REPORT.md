# Relatório NLU 2.0.0

Registro histórico do build validado antes da alteração de versionamento. A versão atual do release é **0.3.0**, com motor contextual 2.0. Os hashes, benchmarks e artefatos abaixo continuam identificando o build original 2.0.0; não representam uma nova validação completa da versão 0.3.0.

Implementação contextual aditiva em Rust/Python, versões anteriores preservadas e STT inalterado. Fingerprint normalizado das fontes executáveis: `18909fef2fd43649bb6412f63b40a36309c73634d5f41ecf64956505ff1ef02f`. Trabalho no checkout local; nenhum commit, push ou implantação numa residência foi efetuado.

## A. Implementação

Motor contextual determinístico, aliases semânticos e capacidades dinâmicas; números PT-BR, cores, modos, parâmetros relativos, planos compostos, consultas e agregações. Sessões limitadas, esclarecimentos, confirmação e cancelamento. Adaptadores fechados para os domínios HA inventariados; Music Assistant, remotes e scripts exigem backend/configuração reais.

## B. Arquitetura

STT/texto → normalização e intenção/slots Rust → contexto → resolução entidade/capacidade → plano leitura/controle → executor Python HA → resposta. O catálogo autorizado é compilado no Python e indexado no Rust; a validação e execução ficam exclusivamente no Python. v4 é aditivo a v1/v2/v3; `contextual_enabled=false` restaura a seleção anterior.

## C. Cobertura


Fonte MIT STT `cd3cac0be30050b6899555f83eba0e74da984c6f`: 1.946 registros CSV, 165 intenções e 26 valores de família (`dominio`), em vez da estimativa de 45. As quatro entradas CSV têm SHA-256 no arquivo de proveniência. Templates são parte do motor; esta avaliação é conformidade interna, não acurácia independente.

| Camada | Casos | Percentual |
|---|---:|---:|
| Reconhecimento linguístico/abstenção tipada | 1942 / 1946 | 99.79% |
| Semântica, slots/alvos conferidos quando há oracle independente | 1911 / 1946 | 98.20% |
| Planos v4 tipados válidos | 1902 / 1946 | 97.74% |
| Execução com executor real e HA simulado | 1894 / 1946 | 97.33% |

`coverage.json` guarda resultados por caso e intenção, ações, parâmetros, slots verificados e motivos. `coverage.csv` conecta todas as 165 intenções a família, parâmetros, domínios, dependência e estado medido. Não se considera esclarecimento uma execução. O cenário tem entidades relevantes e recursos simulados; catálogos mistos/ambiguidade/permissões são testados separadamente. Bindings usam script simulado com variáveis explicitamente mapeadas. Transferência usa origem distinta recente; localização interna usa tracker explícito. Confirmação isolada sem pendência e pronome sem contexto abstêm.

Calendário e Spotify possuem testes de múltiplos turnos que executam após obter duração ou conteúdo; suas frases incompletas do corpus continuam marcadas sem execução. Previsões ausentes no retorno simulado não são fabricadas. Rótulos do corpus também podem conflitar com a semântica: “alguém” não identifica uma pessoa para localização individual.

Resumo por intenção: 165 inventariadas; 165 reconhecidas em ao menos um caso; 158 com plano em ao menos um caso; 161 com fluxo concluído em simulação; 24 com dependência condicional explícita; 4 sem conclusão isolada; 1 com falha real de interpretação. Esses conjuntos se sobrepõem, não são categorias mutuamente exclusivas. Todos exigem entidades/serviços disponíveis e autorização no destino.

Conformidade operacional inclui cancelamentos corretos, que não são chamadas de controle. Semântica também inclui controles de conversa sem plano; por isso sua contagem pode exceder a de planos. O código não considera reconhecimento textual suficiente para execução.

| Categoria dos casos restantes | Casos |
|---|---:|
| 1. Exige continuação de conversa | 22 |
| 2. Exige contexto ausente | 6 |
| 3. Exige hardware/integração/configuração | 0 |
| 4. Exige confirmação | 0 |
| 5. Ambíguo por natureza | 2 |
| 6. Recusa por segurança | 2 |
| 7. Falha de interpretação | 2 |
| 8. Falha de planejamento | 0 |
| 9. Falha do executor | 0 |
| 10. Falha/limitação do teste ou rótulo do corpus | 18 |

As duas consultas afirmativas `device.status` não reconhecidas são falhas de interpretação registradas, não recusas esperadas. Os três casos com “alguém” rotulados como localização individual usam fixture incompatível; os quinze forecasts futuros não existem no backend simulado: são limitações do teste, não demonstrações de funcionamento real. “Para de tocar” é ambíguo entre mídia e alarme. CSV/JSON preservam classificação por caso e intenção.

## D. Qualidade

- Baseline: 67 testes Python e 83 testes Rust passaram antes da extensão. O gate completo inicial encontrou CRLF e catálogos Phase B ausentes no staging; ambos foram corrigidos.
- Gate final: PASS. Testes únicos Python: 99; testes Rust: 90. O segundo passe contextual usa Rust release real via HTTP e o executor Python. Os 20 exemplos congelados da missão são exercitados no Rust, além das contraprovas de segurança e diálogo.
- O pacote inclui build offline e fontes vendorizadas. Imagem scratch amd64 é verificada separadamente. ARM64 não foi executado neste host.
- APIs: fonte pública HA Core `2ee7b99063feb4b48e4faa0a9dece14998d0876f` e documentação oficial. Nenhuma instância residencial HA estava disponível: execução física, frontend e integrações reais continuam pendentes de ensaio no destino.

| Verificação | Resultado |
|---|---|
| Python tests | 99 únicos |
| Rust tests | 90 |
| Integration tests | 9 E2E Rust HTTP + Python, incluídos na suíte |
| Security tests | Contraprovas/regressões incluídas; ver REVIEWS.md |
| Corpus evaluation | 1946 casos reavaliados |
| Formatting / Lint | PASS: cargo fmt / clippy -D warnings |
| Docker build / smoke | PASS; amd64 real; ver image-validation.json |
| ZIP validation | PASS; extraído e testes executados; ver package-validation.json |

## E. Performance

CPU observada: : AMD Ryzen 7 5700X 8-Core Processor. Ambiente: Linux-6.18.33.2-microsoft-standard-WSL2-x86_64-with; Python 3.12.15; Rust 1.98.0 release/musl. Sem downloads na execução. Números não incluem rede doméstica ou latência física de dispositivos.

| Entidades | Rust P50 ms | Rust P95 ms | Rust P99 ms | HTTP + executor P50 ms | HTTP + executor P95 ms | HTTP + executor P99 ms | Catálogo Rust P50 ms | RSS observado |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 64 | 0.0303 | 0.0681 | 0.1258 | 0.8414 | 0.9937 | 1.0969 | 0.89 | VmRSS:	    1716 kB |
| 512 | 0.1066 | 0.1427 | 0.1943 | 0.8533 | 1.0143 | 1.0821 | 5.01 | VmRSS:	    3516 kB |
| 4096 | 1.8122 | 2.1157 | 2.5986 | 0.8630 | 1.0344 | 1.1256 | 43.70 | VmRSS:	   15296 kB |

Rust: 100 aquecimentos + 1.000 medições por tamanho; comandos genéricos com preferência explícita. HTTP/executor: 20 aquecimentos + 200 medições, alvo nominal exato e consultas, serviço HA instantâneo simulado. Os workloads são diferentes e não devem ser subtraídos entre si. RSS é do processo ao final de cada tamanho, com catálogos anteriores presentes; não é pico nem previsão para Raspberry Pi. JSONs preservam P50/P95 por normalização, contexto, intenção/slots, resolução, planejamento, validação e execução simulada, além de compilação dos snapshots. Inicialização da gramática/indexação é amortizada; a primeira compilação pode ser mais lenta.

As medições HTTP incluem `rust_http_roundtrip_ms`, que mede a chamada completa com transporte e interpretação, e `validation_executor_response_ms`, separado do total observado. Intenção/slots e execução/resposta são etapas instrumentadas juntas; não se inventa uma separação de custo dentro dessas etapas. P99 também está nos JSONs. STT não está incluído.

## F. Segurança

Revisões e severidades: [REVIEWS.md](REVIEWS.md). Problemas de escopo global, respostas ausentes, opção revogada, parâmetros relativos multialvo e repetição após efeito incerto foram corrigidos com regressões. Entidades indisponíveis permanecem desconhecidas. Avisos musl/biblioteca padrão Rust estão na imagem/pacote. Nenhum CRITICAL/HIGH ou MEDIUM de execução conhecido pendente após as verificações finais; a revisão secundária foi interrompida por limite de uso depois da última lacuna de licença, encerrada pelo executor.

## G. Implantação

[DEPLOYMENT.md](DEPLOYMENT.md) contém pré-requisitos, instalação local, integração, agente Assist, opções, adaptadores, validação, logs e rollback. Nenhum deploy/push foi feito.

## H. Limitações

Não se declara 100% de compreensão de linguagem livre ou execução real das 165 intenções. Condições e exceções abstêm; PIN/código nunca é contornado. Nomes iguais pedem esclarecimento. Não há endpoint genérico para cloud providers, chamada telefônica, canal, impressão 3D ou remoção de calendário. Esses casos exigem adaptadores configurados e contratos reais. Expressões ambíguas como “para de tocar” podem precisar de nome/alias/contexto explícito. Unidades de energia incompatíveis abstêm; conversões implementadas incluem porcentagem/volume, brilho, duração e Kelvin, sem conversão geral de unidades físicas.

Usuário ativo autenticado é obrigatório; contexto sem user_id é negado, inclusive em pipelines que não o forneçam. Origem espacial é obtida dos campos reais ConversationInput; metadados STT adicionais não atravessam o Wyoming inspecionado. Vínculo a tracker interno não é inferido da área cadastral da pessoa.

Casos que ainda não completam a execução simulada isolada:

- `assistant.confirm`: 0/2 execuções simuladas; motivos: abstenção/ambiguidade/checagem semântica; veja cases_detail.
- `calendar.add_event`: 0/16 execuções simuladas; motivos: missing_calendar_duration.
- `clock_alarm.dismiss`: 3/4 execuções simuladas; motivos: abstenção/ambiguidade/checagem semântica; veja cases_detail.
- `device.status`: 18/20 execuções simuladas; motivos: abstenção/ambiguidade/checagem semântica; veja cases_detail.
- `home.all_off`: 4/5 execuções simuladas; motivos: abstenção/ambiguidade/checagem semântica; veja cases_detail.
- `media.repeat_off`: 3/4 execuções simuladas; motivos: abstenção/ambiguidade/checagem semântica; veja cases_detail.
- `media.spotify_play`: 0/6 execuções simuladas; motivos: missing_media_query.
- `media.stop`: 4/5 execuções simuladas; motivos: abstenção/ambiguidade/checagem semântica; veja cases_detail.
- `presence.person_area.query`: 17/20 execuções simuladas; motivos: no_compatible_capability.
- `satellite.device_here_off`: 0/4 execuções simuladas; motivos: missing_context_target.
- `weather.forecast`: 5/20 execuções simuladas; motivos: forecast_date_unavailable.

## I. Alterações

Rust: `addon/engine/src/contextual`, rotas em server/lib e testes/exemplo de benchmark. Python: catálogo/protocolo/executor contextual, capabilities/queries, runtime/conversation/config_flow/init e traduções. Build: versões 2.0.0, Docker, avisos de licença e staging LF. Dados: inventário/proveniência/cobertura/benchmarks. Ferramentas: importação, avaliação, medição, smoke e pacote. Documentos: arquitetura/contratos/implantação/revisões/relatório/checkpoint. Modificações locais anteriores foram preservadas.

## J. Pronto para implantação?

READY WITH KNOWN LIMITATIONS

Gate, imagem e pacote extraído aprovados; implantação deve ser controlada. HA residencial, hardware físico, frontend HA e ARM64 não foram validados; resultados operacionais são de simulador. Recursos condicionais precisam de configuração e identidade do usuário.

## Matriz por intenção

L = linguístico; S = semântica/slots/alvos; P = plano válido; E = executor simulado. Adaptador, dependências e categorias estão no CSV/JSON.

| Intenção | Casos | L | S | P | E |
|---|---:|---:|---:|---:|---:|
| alarm.arm | 5 | 5 | 5 | 5 | 5 |
| alarm.cancel | 4 | 4 | 4 | 4 | 4 |
| alarm.disarm | 4 | 4 | 4 | 4 | 4 |
| alarm.set | 16 | 16 | 16 | 16 | 16 |
| alarm.status | 4 | 4 | 4 | 4 | 4 |
| announce.area | 16 | 16 | 16 | 16 | 16 |
| appliance.status | 20 | 20 | 20 | 20 | 20 |
| area.devices_query | 16 | 16 | 16 | 16 | 16 |
| assistant.cancel | 3 | 3 | 3 | 0 | 3 |
| assistant.confirm | 2 | 2 | 2 | 0 | 0 |
| assistant.deny | 2 | 2 | 2 | 0 | 2 |
| assistant.repeat | 2 | 2 | 2 | 0 | 2 |
| battery.device_query | 16 | 16 | 16 | 16 | 16 |
| battery.low_query | 4 | 4 | 4 | 4 | 4 |
| calendar.add_event | 16 | 16 | 0 | 0 | 0 |
| calendar.date_query | 20 | 20 | 20 | 20 | 20 |
| calendar.event_time_query | 16 | 16 | 16 | 16 | 16 |
| calendar.next_event_query | 6 | 6 | 6 | 6 | 6 |
| calendar.remove_event | 16 | 16 | 16 | 16 | 16 |
| calendar.today_query | 6 | 6 | 6 | 6 | 6 |
| call.contact | 16 | 16 | 16 | 16 | 16 |
| camera.show | 20 | 20 | 20 | 20 | 20 |
| climate.fan_speed_set | 12 | 12 | 12 | 12 | 12 |
| climate.mode_set | 16 | 16 | 16 | 16 | 16 |
| climate.status | 12 | 12 | 12 | 12 | 12 |
| climate.swing_set | 12 | 12 | 12 | 12 | 12 |
| climate.temperature_set | 20 | 20 | 20 | 20 | 20 |
| climate.turn_off | 15 | 15 | 15 | 15 | 15 |
| climate.turn_on | 15 | 15 | 15 | 15 | 15 |
| clock_alarm.cancel_all | 3 | 3 | 3 | 3 | 3 |
| clock_alarm.dismiss | 4 | 3 | 3 | 3 | 3 |
| clock_alarm.query | 5 | 5 | 5 | 5 | 5 |
| clock_alarm.snooze | 16 | 16 | 16 | 16 | 16 |
| cover.close | 20 | 20 | 20 | 20 | 20 |
| cover.open | 20 | 20 | 20 | 20 | 20 |
| cover.position_percent | 16 | 16 | 16 | 16 | 16 |
| cover.position_set | 12 | 12 | 12 | 12 | 12 |
| cover.status | 16 | 16 | 16 | 16 | 16 |
| date.current | 4 | 4 | 4 | 4 | 4 |
| dehumidifier.humidity_set | 12 | 12 | 12 | 12 | 12 |
| dehumidifier.status | 6 | 6 | 6 | 6 | 6 |
| dehumidifier.turn_off | 6 | 6 | 6 | 6 | 6 |
| dehumidifier.turn_on | 6 | 6 | 6 | 6 | 6 |
| device.phone_find | 11 | 11 | 11 | 11 | 11 |
| device.status | 20 | 18 | 18 | 18 | 18 |
| device.turn_off | 20 | 20 | 20 | 20 | 20 |
| device.turn_on | 20 | 20 | 20 | 20 | 20 |
| dishwasher.remaining_time | 3 | 3 | 3 | 3 | 3 |
| door.status | 16 | 16 | 16 | 16 | 16 |
| energy.device_query | 16 | 16 | 16 | 16 | 16 |
| energy.home_query | 4 | 4 | 4 | 4 | 4 |
| entity.where_query | 16 | 16 | 16 | 16 | 16 |
| fan.speed_down | 16 | 16 | 16 | 16 | 16 |
| fan.speed_set | 16 | 16 | 16 | 16 | 16 |
| fan.speed_up | 16 | 16 | 16 | 16 | 16 |
| fan.turn_off | 20 | 20 | 20 | 20 | 20 |
| fan.turn_on | 20 | 20 | 20 | 20 | 20 |
| gate.close | 9 | 9 | 9 | 9 | 9 |
| gate.open | 10 | 10 | 10 | 10 | 10 |
| gate.status | 12 | 12 | 12 | 12 | 12 |
| group.status | 12 | 12 | 12 | 12 | 12 |
| group.turn_off | 12 | 12 | 12 | 12 | 12 |
| group.turn_on | 12 | 12 | 12 | 12 | 12 |
| home.all_off | 5 | 5 | 4 | 4 | 4 |
| home.any_device_on | 4 | 4 | 4 | 4 | 4 |
| home.status_summary | 5 | 5 | 5 | 5 | 5 |
| humidifier.humidity_set | 12 | 12 | 12 | 12 | 12 |
| humidifier.status | 6 | 6 | 6 | 6 | 6 |
| humidifier.turn_off | 6 | 6 | 6 | 6 | 6 |
| humidifier.turn_on | 6 | 6 | 6 | 6 | 6 |
| light.all_off | 16 | 16 | 16 | 16 | 16 |
| light.all_on | 16 | 16 | 16 | 16 | 16 |
| light.brightness_down | 16 | 16 | 16 | 16 | 16 |
| light.brightness_set | 16 | 16 | 16 | 16 | 16 |
| light.brightness_up | 16 | 16 | 16 | 16 | 16 |
| light.color_set | 16 | 16 | 16 | 16 | 16 |
| light.color_temperature_cooler | 16 | 16 | 16 | 16 | 16 |
| light.color_temperature_set | 12 | 12 | 12 | 12 | 12 |
| light.color_temperature_warmer | 16 | 16 | 16 | 16 | 16 |
| light.status | 16 | 16 | 16 | 16 | 16 |
| light.turn_off | 24 | 24 | 24 | 24 | 24 |
| light.turn_on | 28 | 28 | 28 | 28 | 28 |
| lock.lock | 15 | 15 | 15 | 15 | 15 |
| lock.status | 12 | 12 | 12 | 12 | 12 |
| lock.unlock | 12 | 12 | 12 | 12 | 12 |
| media.mute | 5 | 5 | 5 | 5 | 5 |
| media.next | 6 | 6 | 6 | 6 | 6 |
| media.now_playing | 5 | 5 | 5 | 5 | 5 |
| media.pause | 6 | 6 | 6 | 6 | 6 |
| media.play_artist | 20 | 20 | 20 | 20 | 20 |
| media.play_generic | 28 | 28 | 28 | 28 | 28 |
| media.play_on_destination | 16 | 16 | 16 | 16 | 16 |
| media.play_playlist | 20 | 20 | 20 | 20 | 20 |
| media.previous | 5 | 5 | 5 | 5 | 5 |
| media.repeat_all | 4 | 4 | 4 | 4 | 4 |
| media.repeat_off | 4 | 4 | 3 | 3 | 3 |
| media.repeat_one | 4 | 4 | 4 | 4 | 4 |
| media.resume | 6 | 6 | 6 | 6 | 6 |
| media.seek_backward | 16 | 16 | 16 | 16 | 16 |
| media.seek_forward | 16 | 16 | 16 | 16 | 16 |
| media.shuffle_off | 4 | 4 | 4 | 4 | 4 |
| media.shuffle_on | 4 | 4 | 4 | 4 | 4 |
| media.spotify_play | 6 | 6 | 0 | 0 | 0 |
| media.stop | 5 | 4 | 4 | 4 | 4 |
| media.transfer | 16 | 16 | 16 | 16 | 16 |
| media.transfer_destination | 16 | 16 | 16 | 16 | 16 |
| media.unmute | 5 | 5 | 5 | 5 | 5 |
| media.volume_down | 5 | 5 | 5 | 5 | 5 |
| media.volume_set | 16 | 16 | 16 | 16 | 16 |
| media.volume_up | 5 | 5 | 5 | 5 | 5 |
| media.whole_home | 16 | 16 | 16 | 16 | 16 |
| mower.dock | 7 | 7 | 7 | 7 | 7 |
| mower.pause | 9 | 9 | 9 | 9 | 9 |
| mower.start | 10 | 10 | 10 | 10 | 10 |
| mower.status | 10 | 10 | 10 | 10 | 10 |
| plug.turn_off | 13 | 13 | 13 | 13 | 13 |
| plug.turn_on | 13 | 13 | 13 | 13 | 13 |
| presence.area.query | 40 | 40 | 40 | 40 | 40 |
| presence.count.query | 16 | 16 | 16 | 16 | 16 |
| presence.person_area.query | 20 | 20 | 17 | 17 | 17 |
| presence.person_location.query | 21 | 21 | 21 | 21 | 21 |
| printer3d.pause | 3 | 3 | 3 | 3 | 3 |
| printer3d.resume | 3 | 3 | 3 | 3 | 3 |
| printer3d.status | 6 | 6 | 6 | 6 | 6 |
| routine.activate | 20 | 20 | 20 | 20 | 20 |
| satellite.device_here_off | 4 | 4 | 0 | 0 | 0 |
| satellite.light_here_off | 4 | 4 | 4 | 4 | 4 |
| satellite.light_here_on | 4 | 4 | 4 | 4 | 4 |
| satellite.media_here | 16 | 16 | 16 | 16 | 16 |
| satellite.mute | 4 | 4 | 4 | 4 | 4 |
| satellite.unmute | 4 | 4 | 4 | 4 | 4 |
| satellite.volume_down | 5 | 5 | 5 | 5 | 5 |
| satellite.volume_set | 12 | 12 | 12 | 12 | 12 |
| satellite.volume_up | 5 | 5 | 5 | 5 | 5 |
| scene.activate | 20 | 20 | 20 | 20 | 20 |
| security.openings_any_open | 5 | 5 | 5 | 5 | 5 |
| sensor.air_quality.query | 24 | 24 | 24 | 24 | 24 |
| sensor.co2.query | 20 | 20 | 20 | 20 | 20 |
| sensor.humidity.query | 36 | 36 | 36 | 36 | 36 |
| sensor.illuminance.query | 20 | 20 | 20 | 20 | 20 |
| sensor.noise.query | 16 | 16 | 16 | 16 | 16 |
| sensor.temperature.query | 48 | 48 | 48 | 48 | 48 |
| sunrise.query | 3 | 3 | 3 | 3 | 3 |
| sunset.query | 3 | 3 | 3 | 3 | 3 |
| time.current | 5 | 5 | 5 | 5 | 5 |
| timer.add_time | 16 | 16 | 16 | 16 | 16 |
| timer.cancel | 4 | 4 | 4 | 4 | 4 |
| timer.cancel_all | 4 | 4 | 4 | 4 | 4 |
| timer.finish | 4 | 4 | 4 | 4 | 4 |
| timer.pause | 4 | 4 | 4 | 4 | 4 |
| timer.query | 4 | 4 | 4 | 4 | 4 |
| timer.remove_time | 16 | 16 | 16 | 16 | 16 |
| timer.resume | 4 | 4 | 4 | 4 | 4 |
| timer.set | 20 | 20 | 20 | 20 | 20 |
| timer.start | 20 | 20 | 20 | 20 | 20 |
| vacuum.clean_area | 16 | 16 | 16 | 16 | 16 |
| vacuum.dock | 7 | 7 | 7 | 7 | 7 |
| vacuum.start | 8 | 8 | 8 | 8 | 8 |
| vacuum.stop | 6 | 6 | 6 | 6 | 6 |
| washer.remaining_time | 4 | 4 | 4 | 4 | 4 |
| water.leak_query | 5 | 5 | 5 | 5 | 5 |
| water.tank_level_query | 4 | 4 | 4 | 4 | 4 |
| weather.current | 6 | 6 | 6 | 6 | 6 |
| weather.forecast | 20 | 20 | 20 | 20 | 5 |
| window.status | 16 | 16 | 16 | 16 | 16 |

Reprodução e rollback: [DEPLOYMENT.md](DEPLOYMENT.md). Contratos e fontes: [API-CONTRACTS.md](API-CONTRACTS.md).
