# MLP Requirements

| ID | Requirement | Evidence |
| --- | --- | --- |
| MLP-001 | Core returns zero or one typed plan of at most four ordered operations and never executes it. | Rust unit and protocol tests |
| MLP-002 | Only `turn_on`, `turn_off`, `set_fan_percentage`, and `get_state` are accepted. | Parser tests |
| MLP-003 | Effects are limited to `light`, `switch`, and `fan`; reads may also target `sensor` and `binary_sensor`. | Parser and integration tests |
| MLP-004 | A plan has at most four operations and each has at most four exact entity or area clauses. | Resolution tests |
| MLP-005 | Coordinated area ellipsis such as `da sala e do quarto` is supported deterministically. | Corpus tests |
| MLP-006 | Fan percentage accepts only an integer from 0 through 100. | Parser and integration tests |
| MLP-007 | Ordered effect chains such as `apague X e ligue Y` preserve spoken order. | Corpus and integration tests |
| MLP-008 | Ambiguity, contradiction, mixed query/effect chains, and unsupported syntax produce no plan. | Negative corpus |
| MLP-009 | Matching and output are stable under catalog reordering. | Determinism tests |
| MLP-010 | Original Unicode text is retained unchanged in the request model. | Protocol round-trip test |
| MLP-011 | Requests, text, catalog, aliases, operations, clauses, targets, and responses are bounded. | Limit tests |
| MLP-012 | Add-on receives no Home Assistant credential and calls no HA API. | Package and source check |
| MLP-013 | Integration re-resolves registry IDs and preflights the complete plan before the first effect. | Integration tests |
| MLP-014 | Integration rejects disabled, missing, unavailable, or unexposed targets. | Integration tests |
| MLP-015 | Integration rejects changed domain, unsupported fan features, or missing services. | Integration tests |
| MLP-016 | Effectful operations require caller control permission. | Integration tests |
| MLP-017 | Integration forwards the original Home Assistant context. | Integration tests |
| MLP-018 | Query operations do not call a service and preserve units. | Integration tests |
| MLP-019 | Transport is local, bounded, timeout-limited, and fail-closed. | Client/server tests |
| MLP-020 | Runtime stores no utterance or catalog and logs neither. | Source review |
| MLP-021 | Active dependencies are pinned, FOSS, and documented. | `DEPENDENCIES.md` |
| MLP-022 | Home Assistant add-on and custom integration package structures are present. | Package check |
| MLP-023 | `./tools/mlp-check` passes from the repository root. | Final gate transcript |
