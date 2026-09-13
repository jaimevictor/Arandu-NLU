# P15 P02-v3 freeze final review

- Date: `2026-09-11`
- Role: independent source-confinement and freeze reviewer
- Mode: read-only
- Authorization commit:
  `68f004eded59b5f223a218516bf38b9cbd36872c`
- Authorization tree:
  `2c64dd1e4a85618fb59bc2d55aa125907970ce80`
- Source-I/O baseline commit:
  `d2c34476f660f6bcaf0f193fca67d084b4b4a0b2`
- Review subject:
  authorization baseline plus the current 17-file P02-v3 freeze candidate
- Independently computed subject SHA-256:
  `851d7e9be8647b1cf7b0be9a98e7a6c7d3b7cf886cb704dc1cd1384e594f1b0`

## Primary evidence

The reviewer inspected:

- `tools/generate-p02-v3-corpus.rb`;
- `tools/test-generate-p02-v3-corpus.rb`;
- `tools/validate-p02-v3.rb`;
- `tools/test-validate-p02-v3.rb`;
- `tools/validate-governance.rb`;
- `docs/evidence/P15-P02-V3-FREEZE.md`; and
- aggregate identities for all eleven files under
  `data/project-authored/p02-v3/`.

No held-out, performance, or suite record contents were inspected. JSONL
leaves entered the review identity only through aggregate validator output.
All six expected tool/specification/manifest sizes and SHA-256 values matched.
The nine JSONL files total `22,068,822` bytes and the complete eleven-file
lineage totals `22,140,384` bytes.

## Reproduced commands

The following checks passed:

```text
ruby -c tools/generate-p02-v3-corpus.rb
ruby -c tools/test-generate-p02-v3-corpus.rb
ruby -c tools/validate-p02-v3.rb
ruby -c tools/test-validate-p02-v3.rb
ruby -w tools/test-generate-p02-v3-corpus.rb
ruby -w tools/test-validate-p02-v3.rb
ruby tools/generate-p02-v3-corpus.rb --check
ruby tools/validate-p02-v3.rb --aggregate-report
git diff --check
```

The warning-enabled suites passed 13 generator tests and 32 validator tests.
The deterministic generation check and sealed aggregate validator passed.

## Counterexample attempts

Reviewer-owned temporary repositories and files attempted to disprove the
source-change contract. The reviewer confirmed:

- an authorization-parent source replaced by numeric path construction and
  aliased bounded readers is rejected by blob identity even when
  `IO_OPERATION_PATTERN` is false;
- extensionless, unknown-extension, and invalid-UTF-8 changed or new project
  paths are inventoried and rejected;
- repository-local `core.worktree`, `core.excludesFile`, and
  `.git/info/exclude` cannot redirect or hide ordinary untracked project
  paths;
- markerless exact mutable and release changes are rejected;
- embedded-repository and inherited Git pathspec cases fail closed; and
- unchanged authorization-parent blobs remain accepted.

The whole-worktree audit contained 1,265 inventoried paths. Five differed from
the authorization parent; all five were predeclared and correctly marked.
There were no unauthorized changed paths.

## Contract assessment

Every inventoried project path is blob-compared before classification.
Repository discovery is bound to the explicit root `.git` directory and root
worktree. All 40 future mutable paths are exact, unique, disjoint from the
release boundaries, and uniformly treated as potentially I/O-capable without
syntax classification. The exact exclusion set matches the documented
ambient, generated, evidence, data, and build-output boundaries.

## Findings

- P0: none
- P1: none
- P2: none
- P3: none

PASS
