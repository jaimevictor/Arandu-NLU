# P13 Source Provenance Review

- Role: `source-provenance`
- Subject commit: `0c29e26914a022a10a9bca717cd17fa83d018a9d`
- Subject tree: `557298c5641459b8ea5ad254f80192bc9c774755`
- Archive SHA-256: `4bf355124160b38d58bebc153d02b4af41810c17ec4f66ae42765ec25db8ecf0`
- Mode: independent read-only
- Verdict: `FAIL`

## Scope And Commands

The reviewer traced the dated channel manifest through the exact Rust source
archive, source commit, selected members, SPDX objects, toolchain provenance,
and material ledger. It reproduced `tools/p13-noise-evidence --skip-runtime`,
`tools/test-p13-noise-evidence`, exact Git/archive identity, and
`git diff --check`.

## Counterexample

Changing `active_source_closure.llvm_license` from
`Apache-2.0 WITH LLVM-exception` to `BUSL-1.1` did not affect
`validate_toolchain_source_provenance`; the field was recorded but unread.

## Findings

P0: none. P1: unbound LLVM license field in the toolchain provenance
relation. P2: none. P3: none.

`FAIL`
