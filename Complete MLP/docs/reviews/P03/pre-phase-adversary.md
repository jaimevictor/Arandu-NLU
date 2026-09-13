# P03 Pre-phase Adversarial Analysis

- Role: `executor-adversarial-synthesis`
- Analysis instance: `p03-executor-adversary-20260828`
- Input baseline: `fb1d88b`
- Mode: read-only repository analysis
- Independence: `PENDING_ELIGIBLE_REVIEWER`
- Result: `PROVISIONAL_ANALYSIS_COMPLETE`

## Threat Model

| Severity | Hypothesis | Required control |
| --- | --- | --- |
| P0 | Import accepts bytes before their identity or license is verified. | Make verification a mandatory in-process precondition and test no output on failure. |
| P0 | A path escapes the declared root through `..`, absolute paths, symlinks, or special files. | Accept canonical relative paths only and require every component and leaf to be a regular non-symlink path. |
| P0 | Project-authored data is represented as independently admitted or used for external accuracy. | Enforce the exact synthetic state, `USR-016`, and internal-conformance claim. |
| P1 | Missing source fields are silently defaulted. | Strict DTOs, explicit project-authored dispositions, and one deletion mutation per field group. |
| P1 | A hash, size, license, version, or source ID changes between verification and import. | Read verified bytes once per operation and bind stage manifests to all input hashes. |
| P1 | Duplicate JSON keys or malformed UTF-8 gain parser-dependent meaning. | Reject before semantic parsing with a bounded duplicate-key preflight. |
| P1 | Record or filesystem order changes compiled bytes. | Recursive key canonicalization, stable identity sort, and permutation tests. |
| P1 | One family crosses train, development, held-out, or performance. | Maintain a global family-to-split map and fail on a second assignment. |
| P1 | Removal deletes direct records but leaves normalized, split, or compiled derivatives. | Run source-ID absence checks over every rewritten stage and package index. |
| P1 | A failed command leaves a valid-looking partial destination. | Refuse existing destinations and atomically rename a complete temporary output. |
| P2 | Diagnostics reveal held-out utterances or expected semantics. | Emit bounded identifiers, paths, counts, and typed errors only. |
| P2 | `fetch` happens during build/test or without explicit consent. | Keep it outside build scripts and require `--allow-fetch`. |

## Required Negative Tests

Tests must cover missing and unknown manifest fields; bad schema version;
restricted or unknown license; wrong status or authorization; mutable or
missing source identity; path traversal, absolute path, symlink, directory,
and duplicate path; wrong size and SHA-256; malformed UTF-8/JSON/JSONL;
duplicate JSON keys; unauthorized AI origin; `FIXTURE_TECNICA`; duplicate
record identity; family leakage; output destination reuse; input permutation;
and selective removal.

Boundary tests cover empty files, maximum path and record sizes, maximum record
count and nesting, one-over-limit failures, and length-prefix overflow.

## Failure Policy

All malformed, ambiguous, stale, unsupported, or insufficiently proven input
fails closed before output promotion. A failed stage removes only its own
temporary path. It never rewrites source data, previous stages, or the P02
freeze.

No fourth pre-candidate approach or fourth frozen candidate is allowed.
Routine command retries do not consume a pass; selecting a different package
format or manifest model does.

## Counterexample

Checking `path.starts_with(source_root)` after joining an untrusted relative
path is insufficient when a source component is a symlink. The lexical path
can remain inside the root while file resolution escapes it. Every source path
component must be checked without following a symlink.

Evidence inspected: `AGENTS.md`, source policy negative requirements, trust
boundaries, P02 corpus paths and manifests, ADR-0008, and existing protocol
preflight patterns.
