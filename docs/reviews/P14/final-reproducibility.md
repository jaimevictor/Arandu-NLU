# P14 Final Reproducibility And Supply-Chain Review

- Role: `reproducibility`
- Review instance: `01a0879a-13b9-79b2-852b-d0b5e9dddd6f`
- Subject commit: `e2ab301bad38caeaa2f32664bf442501eb8804df`
- Subject tree: `a5b7e7958304040ae72932f6d9dd1e7800acce70`
- Comparison: `2c44119a1a2f3ddc77d08ceea3e504f1e3bbcd7f`
- Comparison tree: `2a2d6a8bd8e519388f2f2f86b6009097324343df`
- Mode: independent read-only primary-evidence review
- Verdict: `FAIL`

## Scope And Commands

The reviewer inspected exact-subject binding, governance, host-tool admission,
Home Assistant identity, direct-rustc coverage, Noise reconstruction,
distribution licensing, P13 immutability, and the disabled P15 gates.

A detached local clone, `git fsck`, validator and Rust-driver self-tests,
Git-archive Noise reconstruction, distribution/source/license subvalidators,
and the exact P14 gate passed. The gate reported 132 unique companion
identities with SHA-256
`bbacd5461eeaae30c1abf9b78aa6bf91793b2195dd11494897b7a84287ce338f`.
Wrong tree, omitted test identity, file-mode, checksum, and manifest-digest
substitutions were rejected.

## Counterexamples

- Exact-subject governance validation computed normative digest
  `bab3aafa...`, while the frozen validator expected `bdcdef0d...`, and failed
  after the P14-specific gate had reported success.
- The host-tool record did not contain the complete rights and independent
  review fields required by the source-admission contract, and the invoked
  `/bin/sh` was not admitted by the P14 tool ledger.
- The Noise promotion report retained aggregate `f2856930...` without naming
  its historical subject or schema, while the schema-v3 manifest records
  `e769386d...`.

## Findings

- P0: none.
- P1: Exact-subject normative governance binding is stale.
- P1: Host validation-tool admission is incomplete.
- P2: Noise promotion evidence is not bound to its historical digest schema.
- P3: none.

`FAIL`
