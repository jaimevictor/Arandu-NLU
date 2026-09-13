# P13 Defensive Adversarial Source Review

- Role: `source-defensive-adversarial`
- Subject commit: `0c29e26914a022a10a9bca717cd17fa83d018a9d`
- Subject tree: `557298c5641459b8ea5ad254f80192bc9c774755`
- Archive SHA-256: `4bf355124160b38d58bebc153d02b4af41810c17ec4f66ae42765ec25db8ecf0`
- Mode: independent read-only
- Verdict: `FAIL`

## Scope And Commands

The reviewer compared exclusion counts with installed paths and selected tool
sets, then ran source archive, lock, legal-file, and notice mutations. It
reproduced `tools/p13-noise-evidence`, `tools/test-p13-noise-evidence`,
`tools/validate-p13 --no-cargo --review-candidate`, and exact subject identity.

## Counterexample

The evidence claimed `excluded_component_installed_path_count: 0` while the
same record bound the installed helper
`.tools/rust-1.98.0/libexec/rust-analyzer-proc-macro-srv`. The helper was
correctly unselected and unexecuted, but the contradictory count remained
accepted.

## Findings

P0: none. P1: none. P2: contradictory excluded-component installed-path
evidence. P3: none.

`FAIL`
