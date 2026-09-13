# P14 USR-047 Replacement Reproducibility Review

- Role: `reproducibility`
- Review instance: `01a08fb6-a625-7b51-899e-b7fe3f8efe92`
- Subject commit: `ba739823ffa7d55abc9042a62f4d5241108d1c49`
- Subject tree: `50a695d7cd0d81522d8d468fb0446fb857fee5df`
- Mode: independent read-only primary-evidence review
- Verdict: `PASS`

Commands included `git rev-parse`, `git status`, `git ls-files -v`,
`git replace -l`, independent Git-object digest reconstruction, safe subgate
replays, `shasum -a 256`, `wc -l -c`, and `cmp`.

The reviewer reproduced:

- the exact commit, tree, parent, clean worktree, 1,576 ordinary index
  entries, and no replacement objects;
- exactly 12 authorized base-to-candidate paths;
- 1,518 normative rows with SHA-256
  `b31121a383ffa6c2a45841c6e4c94066cbbf7174047cfa1fbd2737bb0fb5e7da`;
- 39 normative files with SHA-256
  `ca70c76e08b1f20fa8db1cbe0e1b76012a5d89e59ea04e8f1ff17fb6a50445c0`;
- all pinned governance and host-tool identities; and
- two distinct regular transcript files, each 246 lines and 21,209 bytes,
  byte-identical at SHA-256
  `bf53eb0e10e4054d069913022050bf74efa353fa0b5c3cd51180dec3279d57e4`.

Warning, metadata-order, governance-hash, and authorization-parent
substitutions failed closed.

- P0: none.
- P1: none.
- P2: none.
- P3: none.

`PASS`
