# P15 P02-v3 USR-047 review remediation

- Date — `2026-09-11`
- Authorization — `USR-047`, ADR-0049
- Result — `PASS`
- Product remediation before final PASS — none
- P02-v3 lineage committed before final PASS — none

## Review chronology

The first valid independent review of the exceptional replacement found two
P1 defects:

- parent blob comparison occurred only after I/O syntax recognition, so
  aliased recognized readers could evade the comparison; and
- repository-local `core.worktree` could redirect untracked-source
  inventory.

That subject was identified independently as
`5aef14e685cd5cb98267910eba11431b3f34e2e2207d4739a5f1d08fc9c792f4`.

The corrected second valid review found two further P1 defects:

- only a syntax-classified subset of predeclared mutable paths was treated as
  I/O-capable; and
- extensionless project paths were omitted from source classification.

That subject was identified independently as
`cecc5d7450494ea6f3620eeb5c803346857a7858c845afbe5f4ed3c81863b45b`.

One intervening reviewer launch was rejected by the external platform safety
filter before review execution. It changed no repository state and did not
consume a substantive review round.

## Integrated correction

The final correction:

- blob-compares every inventoried project path before content
  classification;
- treats every one of the 40 exact future mutable paths as potentially
  I/O-capable, with no syntax-derived subset;
- inventories paths independently of extension or basename;
- binds Git to the explicit root `.git` directory and root worktree;
- fixes the exact non-source exclusion set in the generated specification;
  and
- retains direct regressions for aliased readers, `core.worktree`, ignored
  paths, extensionless sources, bounded capture, and symlink containment.

## Final independent result

The final reviewer independently identified the 17-file subject as
`851d7e9be8647b1cf7b0be9a98e7a6c7d3b7cf886cb704dc1cd1384e594f1b0`,
reproduced all required checks and counterexamples, reported zero P0 through
P3 findings, and emitted `PASS`.

The complete report is
`docs/reviews/P15/p02-v3-freeze-final.md`.

Exact governance subsequently identified the superseded Markdown metadata blob
`9cb4e46d0d809171091ebbdc93cf9b39fdc540cd` as ambiguous YAML. Manual
whole-blob inspection confirmed that it contains no credential, personal
state, residential data, or user utterance. The governance validator therefore
binds that historical-only exception to SHA-256
`413ff6530828361f8f81deed06a71612709620c4bead2e3a9327783d61c8cb58`;
the corrected current blob remains subject to the normal scanner.
