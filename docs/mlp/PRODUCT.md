# Local NLU MLP

## User experience

After installing the add-on and companion integration, a Home Assistant user
can select “Local NLU” as a conversation agent and say deterministic PT-BR
commands such as:

- `Acenda o abajur.`
- `Apague a luz da sala e do quarto.`
- `Apague a luz da sala e ligue a luz do quarto.`
- `Ligue o interruptor da cafeteira.`
- `Coloque o ventilador do quarto em 50 por cento.`
- `Qual é o estado do abajur?`
- `Qual é a temperatura da sala?`
- `Toca Queen no Spotify na sala.`
- `Toca no Deezer.`

The result is either an authorized ordered plan, one or more read-only state
values, or a clear request to be more specific. Nothing is executed when the
request is unsupported, contradictory, ambiguous, stale, unauthorized, or
unavailable.

## Supported surface

| Dimension | MLP |
| --- | --- |
| Language | Brazilian Portuguese |
| Effect domains | `light`, `switch`, `fan` |
| Read domains | effect domains plus `sensor`, `binary_sensor` |
| Actions | `turn_on`, `turn_off`, `set_fan_percentage`, `get_state`, bounded music actions |
| Plan | up to four ordered operations |
| Target | up to four exact entity or area clauses per operation |
| Chaining | coordinated targets and mixed ordered effect actions |
| Music | Music Assistant search/play/control only |
| Dialogue | one bounded clarification/follow-up for a pending slot |
| Matching | case/diacritic-insensitive exact aliases |
| State | request-local catalog only |
| Network | local integration-to-add-on HTTP only |
| Execution | companion integration inside Home Assistant |

One operation may affect multiple eligible entities selected by the bounded
target chain. Operations preserve spoken order; target IDs and query results
are stably sorted. The integration preflights the complete plan before the
first effect.

## Music

Spotify, Deezer, and other services are providers of content. The Arandu
integration does not call provider APIs, does not store provider credentials,
and does not treat a Spotify or Deezer entity as the execution backend. Every
music search or playback request is represented as a typed music intent and is
executed through Music Assistant actions such as `music_assistant.search` and
`music_assistant.play_media`, targeting Music Assistant-managed
`media_player` entities.

## Explicit non-goals

No mixed query/effect chains, contradictory target reuse, timers, toggle,
fuzzy matching, whole-home broadcast, arbitrary service calls, external cloud
outside the user's configured Music Assistant providers, speech recognition,
climate, cover control outside music playback, lock, scene, or automation
creation.

## Failure behavior

Malformed or oversized input returns `invalid_request`. Unknown language or
unsupported syntax returns `no_match`. Multiple exact candidates return
`ambiguous`. The integration performs no Home Assistant operation for any of
those outcomes.
