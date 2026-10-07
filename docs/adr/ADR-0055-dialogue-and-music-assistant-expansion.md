# ADR-0055: Dialogue and Music Assistant expansion

- Status: `ACCEPTED`
- Date: 2026-09-23
- Owners: MLP
- Supersedes: ADR-0050 only where it lists sessions, follow-ups, clarification,
  and media as non-goals

## Context

Real PT-BR home commands now require heterogeneous compound clauses,
clarification for unresolved or ambiguous targets, and music playback. The old
one-shot MLP collapsed several failures into `no_match`, routed conjunctions
conservatively to v1, and had no media contract.

## Decision

Arandu adds a versioned protocol surface for richer outcomes:

- `plan`
- `unsupported_intent`
- `unresolved_target`
- `ambiguous_target`
- `missing_slot`
- `invalid_request`

Clarification is bounded, in-memory, scoped to one pending slot, and does not
carry execution authority. A completed follow-up must be revalidated against
fresh Home Assistant state, exposure, capabilities, services, and permissions
before any effect.

Music is a separate typed intent family. Spotify, Deezer, and other services
are provider hints or constraints only. Arandu never calls provider APIs,
stores provider credentials, or treats a provider as a backend/player.

All music search and playback goes through Music Assistant. The companion
integration may call `music_assistant.search` and `music_assistant.play_media`
and may control Music Assistant-managed `media_player` entities with standard
media controls. A player is accepted only when Home Assistant state metadata
identifies it as Music Assistant-managed; provider-named generic players are
rejected fail-closed.

## Consequences

The protocol and integration now accept music plans and missing-slot outcomes.
The Rust NLU and session engine still need further expansion to generate every
new case directly; until then unsupported or incomplete output remains
fail-closed.
