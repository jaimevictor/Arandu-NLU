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
| Actions | `turn_on`, `turn_off`, `set_fan_percentage`, `get_state` |
| Plan | up to four ordered operations |
| Target | up to four exact entity or area clauses per operation |
| Chaining | coordinated targets and mixed ordered effect actions |
| Matching | case/diacritic-insensitive exact aliases |
| State | request-local catalog only |
| Network | local integration-to-add-on HTTP only |
| Execution | companion integration inside Home Assistant |

One operation may affect multiple eligible entities selected by the bounded
target chain. Operations preserve spoken order; target IDs and query results
are stably sorted. The integration preflights the complete plan before the
first effect.

## Explicit non-goals

No mixed query/effect chains, contradictory target reuse, timers, follow-ups,
sessions, toggle, fuzzy matching, whole-home broadcast, arbitrary service
calls, external cloud, speech recognition, climate, cover, media, lock, scene,
or automation creation.

## Failure behavior

Malformed or oversized input returns `invalid_request`. Unknown language or
unsupported syntax returns `no_match`. Multiple exact candidates return
`ambiguous`. The integration performs no Home Assistant operation for any of
those outcomes.
