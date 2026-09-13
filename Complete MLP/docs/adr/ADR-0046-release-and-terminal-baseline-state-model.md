# ADR-0046: Release and terminal baseline state model

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-09-10
- Owners: P15-P16, FINAL

## Context

The current governance state machine represents active phases and immutable
phase candidates, but its terminal path accepts only nonterminal states and
requires `terminal_state` to remain null. P16 and FINAL require additional
immutable identities for attack chronology, release artifacts, final reviews,
release-chair evidence, and terminal authorization.

Treating an evidence commit, review subject, release artifact tree, or final
state transition as the same baseline would permit stale reports or
post-review artifact substitution.

## Decision

Use four distinct identities:

1. a phase candidate is the immutable source subject reviewed for one phase;
2. an evidence checkpoint is a later commit that records results against that
   unchanged subject;
3. a release candidate is the immutable tree from which every distributable
   artifact is reproduced and against which P16 and FINAL reviews run; and
4. the terminal baseline is the evidence commit that contains all same-release
   reports and release metadata while identifying the unchanged release
   candidate and artifact digests.

Evidence commits may add reports and state records but may not alter the
subject source or release artifacts they describe.

P16 attacks one frozen release candidate before remediation. A true P0
through P2 correction creates a new release candidate and consumes one of the
phase's bounded replacement rounds.

FINAL permits these success transitions only:

`FINAL/REVIEWING -> FINAL/RELEASE_READY -> DEVELOPMENT_COMPLETE`

`RELEASE_READY` requires:

- P00 through P16 passing in verifiable history;
- every mandatory requirement satisfied;
- no open P0 through P2 finding or remediation;
- complete release artifacts, checksums, SBOM, notices, installation,
  upgrade, and rollback evidence;
- seven isolated final reviewer PASS reports and one release-chair PASS on
  the same release candidate; and
- a terminal baseline that corresponds exactly to those artifacts and
  reports.

The terminal guard then sets `terminal_state: TERMINAL_ALLOWED`, disarms
itself, empties the queue, and permits `DEVELOPMENT_COMPLETE`. Any negative
guard answer returns `CONTINUE` and leaves the guard armed.

If the bounded review budget is exhausted with a blocker, the terminal
tribunal may record only `BLOCKED_CONFIRMED`. It cannot authorize release or
manufacture missing evidence.

## Consequences

- Governance validation must gain explicit positive and blocked terminal
  paths before FINAL.
- Final reports cannot point at an evidence-only tree as though it were the
  release source tree.
- Artifact replacement after review invalidates the terminal baseline.
- `DEVELOPMENT_COMPLETE` cannot coexist with queued work, a retained `FAIL`,
  unresolved P14 debt, or disabled release architectures.

## Rollback

Before terminal authorization, return to the owning active phase and freeze a
new candidate under its remaining bounded round. After terminal authorization,
any source or artifact change starts a new release cycle; it cannot amend the
terminal baseline in place.
