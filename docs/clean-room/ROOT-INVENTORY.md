# Fresh Root Inventory

- Inspection date: 2026-08-24
- Workspace: repository root only
- Sibling directories inspected: no
- Symlinks present: no

Before Git initialization, the root contained one file:

| Path | SHA-256 | Classification | Permitted use |
| --- | --- | --- | --- |
| `STEERING-NLU-PTBR-SOL-MAX.md` | `15196e479bee08f117cdf92094381bf8423546a251c5c67e47c76c0a3dbf5539` | User-provided project specification | Requirements and process only; never linguistic data |

No code, compiled artifacts, datasets, prior reports, or implementation
materials were present.

Before the distributable lineage was created, the complete prior local history
and dirty remediation state were backed up outside the repository:

- Git bundle:
  `/private/tmp/nlu-pre-clean-history-20260824.bundle`, SHA-256
  `cdfedb1e7ef0a196a2fb3ffe0a035789162570ead41778e1fe81084770c550b3`;
- steering backup:
  `/private/tmp/STEERING-NLU-PTBR-SOL-MAX.20260824.backup.md`, SHA-256
  `15196e479bee08f117cdf92094381bf8423546a251c5c67e47c76c0a3dbf5539`;
- worktree patch:
  `/private/tmp/nlu-pre-clean-worktree-20260824.patch`, SHA-256
  `ff936d0cd56092ba4cdac46cbbfba3333da57d177277b64839cc156798bc91ab`.

The same three bytes are also retained persistently in the workspace-adjacent
directory `../NLU-pre-clean-backup-20260824/` under descriptive filenames. That
directory is outside the repository, is not a Git alternate, and is excluded
from release archives.

The distributable Git lineage has one project-authored clean root:

- commit: `fc80e5075c6fcd471ddea5ef6e0ba0a32c7829cd`
- tree: `aa621b4243c472beb1e88619537f320596d9b08f`

The immediate child records those non-self-referential IDs. The known steering
blob ID `b817259579808ce7f62291f6ab34cc5c7dda849d` is unreachable from the clean
root and every candidate descendant. The user's local copy stays ignored and
untracked; `git archive` excludes it. Project-owned Apache-2.0 requirements and
ADRs are the distributed normative records.
