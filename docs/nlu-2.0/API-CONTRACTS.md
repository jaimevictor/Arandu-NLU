# Contratos verificados

Fontes públicas do Home Assistant Core foram inspecionadas no commit `2ee7b99063feb4b48e4faa0a9dece14998d0876f`; o registro dos arquivos consultados fica no relatório. A inspeção de fonte não equivale a um ensaio numa residência.

- [ConversationInput](https://github.com/home-assistant/core/blob/2ee7b99063feb4b48e4faa0a9dece14998d0876f/homeassistant/components/conversation/models.py): `text`, `context`, `conversation_id`, `device_id`, `satellite_id`, `language`, `agent_id`.
- [Wyoming STT](https://github.com/home-assistant/core/blob/2ee7b99063feb4b48e4faa0a9dece14998d0876f/homeassistant/components/wyoming/stt.py): entrega `transcript.text` no SpeechResult. Metadados adicionais do Arandu STT não foram presumidos como disponíveis no NLU.
- [Options flow](https://developers.home-assistant.io/docs/core/integration/options_flow/): factory estática no ConfigFlow, OptionsFlow sem argumento e seletores nativos para área/entidade/objeto.

## Serviços

Os adaptadores usam `hass.services.has_service`, features da entidade e revalidação; flags referem-se à fonte acima.

| Domínio | Serviço e dados usados | Evidência adicional |
|---|---|---|
| light | turn_on: brightness_pct, rgb_color, color_temp_kelvin, effect; turn_off | supported_color_modes e effect_list |
| fan | set_percentage: percentage; oscillate: oscillating; set_direction: direction; set_preset_mode | SET_SPEED=1, OSCILLATE=2, DIRECTION=4, PRESET=8, TURN_OFF=16, TURN_ON=32 |
| climate | set_temperature: temperature; set_hvac_mode; set_fan_mode; set_swing_mode; set_preset_mode | TARGET_TEMPERATURE=1, FAN_MODE=8, PRESET=16, SWING=32, TURN_OFF=128, TURN_ON=256; listas e limites atuais |
| media_player | volume_set: volume_level 0–1; media_seek: seek_position; play/pause/stop/next/previous; select_source; mute/repeat/shuffle | flags reais e source_list |
| cover | open_cover, close_cover, stop_cover, set_cover_position: position | OPEN=1, CLOSE=2, SET_POSITION=4, STOP=8; gate/garage exigem política e confirmação |
| vacuum | start, stop, pause, return_to_base, clean_area: cleaning_area_id=[area_id] | START=8192, CLEAN_AREA=16384; destino é ID de área real |
| lawn_mower | start_mowing, pause, dock | START_MOWING=1, PAUSE=2, DOCK=4 |
| humidifier | set_humidity, set_mode | MODES=1, limites e available_modes |
| water_heater | set_temperature, set_operation_mode | TARGET_TEMPERATURE=1, OPERATION_MODE=2 |
| lock | lock, unlock | unlock exige política/confirmar; code_format impede ação sem autenticação |
| alarm_control_panel | alarm_arm_home, alarm_disarm | requisitos de código respeitados; desarmar exige confirmar |
| timer | start, pause, cancel, finish, change | duração inteira em segundos, limite de sete dias |
| calendar | get_events e create_event | datas locais com timezone, título/início/fim; duração pedida no diálogo |
| weather | get_forecasts: type=daily | resposta real do serviço; não se inventa previsão ausente |
| todo | add_item, update_item: status=completed, get_items | feature e retorno real |
| remote | send_command | comandos vêm somente do mapeamento configurado, nunca do texto livre |

Arquivos primários de cada domínio: `homeassistant/components/<domain>/{__init__.py,const.py,services.yaml}` no commit fixado. Não existe serviço genérico `calendar.delete_event` na fonte inspecionada: remoção só funciona com adaptador explícito que resolva o UID real.

## Music Assistant

[Contrato de serviços](https://github.com/home-assistant/core/blob/2ee7b99063feb4b48e4faa0a9dece14998d0876f/homeassistant/components/music_assistant/services.yaml): search exige `config_entry_id`, `name`, `media_type` e aceita `search_options.limit`. Não possui campo `provider`. O executor filtra o URI retornado pelo provider solicitado, exige resultado único com nome exato normalizado e chama play_media com `media_id` real, tipo e enqueue. Transferência usa destino no target e `source_player` real. A integração exige plataforma music_assistant no registro; qualquer media_player não vira player MA.

## Wire v4

`POST /v4/catalog`: `{version:4,generation:<sha256>,entities:[...],areas:[...]}` → catalog_ready ou invalid_request. `POST /v4/interpret`: `{version:4,generation,text,origin_area,last_area,last_targets,pending}`.

O catálogo admite `groups:[{group_id,names,area_ids}]` para andares registrados; ausência equivale a lista vazia. [Floor registry](https://github.com/home-assistant/core/blob/2ee7b99063feb4b48e4faa0a9dece14998d0876f/homeassistant/helpers/floor_registry.py) fornece ID/nome/aliases e as áreas fornecem floor_id. Uma operação de andar inclui `scope=floor_group` e `area=<floor_id>`; o executor valida associação atual. Qualitativos numéricos usam enums minimum/maximum/half/low/medium/high no campo value; modos nativos continuam usando os rótulos reais da entidade.

Resposta plan contém `operations` com `intent`, `action`, `targets` (IDs de registro ordenados), `parameters`, `evidence` e `depends_on` (somente operações anteriores). Respostas alternativas: clarification, unavailable, invalid_request, no_match, stale, cancel, confirm, repeat_response. Campos desconhecidos são rejeitados. IDs HA e serviços não são fornecidos pelo texto. Tempos medidos ficam separados dos resultados semânticos determinísticos.

Rust não recebe token/contexto de autenticação do HA. O contexto original fica no Python e acompanha cada chamada de serviço. Use a rede privada do add-on; não publique a porta do interpretador na internet.
