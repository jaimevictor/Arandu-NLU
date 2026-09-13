# P13 Source Discovery Review

- Role: `source-discovery`
- Subject commit: `0c29e26914a022a10a9bca717cd17fa83d018a9d`
- Subject tree: `557298c5641459b8ea5ad254f80192bc9c774755`
- Archive SHA-256: `4bf355124160b38d58bebc153d02b4af41810c17ec4f66ae42765ec25db8ecf0`
- Mode: independent read-only
- Verdict: `FAIL`

## Scope And Commands

The reviewer enumerated every checksum-metadata path in the 535-package
compiler/Clippy registry universe and compared a basename-prefix inventory
with nested legal-directory and legal-keyword discovery. It reproduced
`tools/p13-noise-evidence --skip-runtime`,
`tools/test-p13-noise-evidence`, exact source-archive identity, and checksum
hashes.

## Counterexample

The basename-prefix predicate omitted five checksum-bound files:
`Apache_2.0_License.txt`, three files below `curl/LICENSES`, and
`git.git-authors`. The complete inventory was 986 files and 5,307,974 bytes,
while the gate accepted 981 files and 5,289,737 bytes.

## Findings

P0: none. P1: none. P2: incomplete nested/nonstandard registry legal-file
discovery. P3: none.

`FAIL`
