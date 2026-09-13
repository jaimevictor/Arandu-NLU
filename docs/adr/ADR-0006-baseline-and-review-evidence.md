# ADR-0006: Immutable baselines and review evidence

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-24
- Owners: all phases

## Context

Review reports must be tracked, but committing them changes the repository tree
after the reviewed implementation was frozen. A self-referential requirement
that the report already exist inside its own subject commit is impossible.

## Decision

A phase review subject is an immutable Git commit and tree containing the
implementation, tests, decisions, and pre-review evidence. Its status is
`REVIEWING`. Reviewers inspect that exact commit, preferably in a detached
worktree, and produce reports outside the tracked subject tree.

For P00, the reviewer also receives an out-of-tree review tuple containing the
subject commit, tree, normative-row SHA-256, and SHA-256 values for both
validator launchers and sources. Before executing repository code, the
reviewer uses the attested absolute Git and Ruby tools to compare that tuple
with committed modes and blobs and with regular worktree files in a private
no-hardlink clone. The in-repository validator repeats those checks, but is
only defense in depth: candidate-controlled code cannot be its own trust
anchor. Tuple authenticity, the attested tools, and SHA-256 remain explicit
review assumptions. No external supervisor script is introduced.

The out-of-tree reviewer instruction also defines the normative-row digest
algorithm independently of candidate code. In document order, each requirement
row contributes exactly six UTF-8 fields: ID without backticks, Source,
Requirement, Owner, Verification, and Evidence. Fields are joined by one byte
`0x09`; rows are joined and terminated by one byte `0x0a`; the digest is
SHA-256 of those bytes. Status is deliberately excluded and has a separate
lifecycle digest. A candidate description of this algorithm is corroborating
documentation, not the reviewer's trust source.

After all required reviewers agree:

1. reports are copied into `docs/reviews/<phase>/`;
2. phase status and queue are updated;
3. an evidence-only checkpoint commit is created.

For P00, each report names one distinct independent reviewer instance and
declares its independent context. The coordinator freezes each report's
SHA-256 outside the candidate and supplies all five hashes to checkpoint mode.
Report-hash authenticity and reviewer-instance authenticity are external
review assumptions, just like the subject tuple.

The checkpoint records both the subject commit/tree and its own commit. Changes
outside review reports, phase state, queue, and evidence indexes are not
evidence-only and require a new subject baseline plus affected re-reviews.
The candidate's unchanged validator runs in evidence-checkpoint mode against
the subject, checkpoint, tool, and report tuples. It revalidates the subject,
requires the checkpoint to have the subject as its sole parent, requires
regular-file modes, validates each report hash and distinct reviewer identity,
rejects binary, noncanonical, empty, contradictory, or out-of-schema reports,
and limits every non-report file to a canonical byte transformation. Structured
payload scanning is fail-closed when its bounded nesting or fragment limits are
exceeded, and assignment-like sensitive keys are normalized across snake,
kebab, dotted, camel, escaped, and acronym case. Markdown control prefixes
cannot hide findings or verdicts. Percent encoding, JSON Unicode escapes, HTML
entities, and rendered Markdown constructs are normalized before verdict and
severity checks. The first decoded Scope line contains `Paths:` and exactly
one nonempty code span; report evidence fields have canonical positions.
Encoded text is decoded to a stable form or rejected at a bounded limit, and
malformed checkpoint rows produce explicit errors. It then checks the exact
P00-to-P01 state, queue, status, license-index, and requirement-status
transitions.

Each reviewer ignores report conclusions, inspects primary evidence, remains
read-only, and classifies every finding as P0, P1, P2, or P3. Each report names
its role, distinct reviewer instance, independent context, subject commit,
subject tree, scope, cited paths, executed commands, inputs, reproducible
results, positive evidence, attempted counterexample, findings, and exactly
`PASS` or `FAIL`. A report generated against a dirty tree or different subject
is invalid.

### Bounded convergence

Each phase may freeze at most three substantive review candidates: the initial
candidate and at most two replacements that remediate reproduced blockers. A
candidate counts when it is committed and designated as the review subject.
An external platform failure before any valid review starts does not consume a
round.

Pre-candidate convergence is independently capped at three passes. The
pre-phase or active phase record defines what constitutes one integrated pass
and its minimum acceptance before the pass starts. Selecting and then
freezing, dispositioning, or rejecting an implementation approach or
required-source portfolio consumes one pass. Routine retries and external
platform failures do not. If pass three cannot produce a candidate that can
meet minimum acceptance, the phase becomes blocked pending an explicit scope
decision instead of beginning another search or redesign cycle.

The minimum acceptable phase contract is:

1. every phase-owned mandatory requirement and required check passes;
2. every mandatory review role reports `PASS` on the same immutable baseline;
3. no P0, P1, or P2 finding remains open;
4. every residual P3 is recorded and cannot affect correctness, security,
   operation, licensing, provenance, clean-room integrity, or a requirement;
5. the evidence checkpoint validates.

The first baseline meeting this contract is checkpointed immediately. Unused
rounds are not a refinement budget. Eligible P3 improvements are deferred to a
later owning phase or backlog. If the third round still has a P0 through P2
blocker, the phase becomes blocked pending an explicit user scope decision;
hard safety, correctness, licensing, provenance, and clean-room requirements
are not weakened to force passage.

This rule applies prospectively from 2026-08-26. Because P00 predates the cap,
its remaining budget is the current candidate plus at most one blocker-only
replacement.

## Alternatives

1. Review a mutable working tree. Rejected because findings cannot be
   reproduced against a unique subject.
2. Commit reports first and ask them to validate themselves. Rejected as
   circular.
3. Keep reviews permanently untracked. Rejected because release evidence would
   be lost.
4. Refine while any reviewer can suggest an improvement. Rejected because it
   has no convergence bound and makes a passing phase vulnerable to indefinite
   polish.

## Consequences

- The approved product baseline and evidence checkpoint have different commit
  IDs, explicitly linked.
- Evidence-only paths need a mechanical change-scope check.
- Any substantive remediation creates a fresh candidate.

## Rollback

Delete an invalid evidence checkpoint only by a new corrective commit; never
rewrite an approved history. Re-run reviews against the last substantive
candidate.
