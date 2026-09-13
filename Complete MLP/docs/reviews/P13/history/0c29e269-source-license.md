# P13 Source License Review

- Role: `source-license`
- Subject commit: `0c29e26914a022a10a9bca717cd17fa83d018a9d`
- Subject tree: `557298c5641459b8ea5ad254f80192bc9c774755`
- Archive SHA-256: `4bf355124160b38d58bebc153d02b4af41810c17ec4f66ae42765ec25db8ecf0`
- Mode: independent read-only
- Verdict: `PASS`

## Scope And Commands

The reviewer inspected the Rust channel manifest and source archive, selected
license roots, both registry inventories, SPDX approval evidence, complete
Rust notices, and excluded `notify 8.2.0`. It reproduced
`tools/p13-noise-evidence --skip-runtime`,
`tools/test-p13-noise-evidence`, and exact Git/archive identity.

## Counterexample

A BUSL Cargo-license mutation and a Rust-notice non-OSI addition were rejected.
No selected CC0 or otherwise ineligible license branch was reproduced.

## Findings

P0: none. P1: none. P2: none. P3: none.

`PASS`
