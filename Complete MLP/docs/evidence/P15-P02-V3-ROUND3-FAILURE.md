# P15 P02-v3 Round-Three Failure

- Date: `2026-09-11`
- Parent commit: `d2c34476f660f6bcaf0f193fca67d084b4b4a0b2`
- Parent tree: `d16c656666e4d46d653479e86e16e8a94079f2cf`
- Failed candidate stash: `p15-v3-round3-failed-before-usr047`
- Result: `FAIL`
- Governing continuation: `USR-047`, ADR-0049

## Reproduced blocker

The final independent review proved that the source-I/O baseline used
authorization-parent path membership but discarded each path's Git blob
identity. Replacing the bytes at a parent-existing pathname with a numeric
sealed-path reconstruction was therefore accepted even though lexical release
reference detection returned false.

The review classified this as P1. It also classified the freeze evidence's
stronger confinement claim as P2. No P0 or P3 finding was reported.

## Disposition

No P02-v3 lineage was committed and no behavior remediation was reapplied.
The failed bytes were preserved reversibly. The user authorized one
blob-bound blocker-only replacement and autonomous continuation through
P15, P16, and FINAL without weakening any hard qualification requirement.
