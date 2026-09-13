# ADR-0029: Dedicated-process deadline containment

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-29
- Owners: P13-P14
- Supersedes: ADR-0019 only for admitted-handler deadline and shutdown behavior

## Context

Independent review of P13 subject
`06157fd4d42fcbad06c1418eb27cfb1514d81931` reproduced three P2 blockers.
Verified crate archives were reopened by path before parsing, source
acquisition and extraction could publish through a replaced destination
ancestor, and an admitted arbitrary handler could continue mutating after its
request deadline or block successful shutdown indefinitely.

Rust cannot revoke memory access from an uncooperative in-process handler, and
detaching that thread would violate the fail-closed state boundary. Waiting
without a bound would violate the server deadline and shutdown contracts.
Therefore containment must occur at a process boundary.

## Decision

### Exact verified source consumption

The Noise verifier MUST parse the exact byte string returned by archive
verification. It MUST NOT reopen the archive path between verification and
parsing. The source fetcher MUST traverse destination ancestors with held
directory descriptors and perform creation, materialization, verification,
exclusive publication, and cleanup relative to those descriptors. A changed
lexical ancestor identity fails closed.

### Server process boundary

`UnixServer::run_until` MUST run only in a dedicated credential-free server
process. It MUST NOT be embedded in the Home Assistant integration process, an
adapter process holding transport credentials, or another process whose
unrelated work must survive a request-handler failure. This process boundary
is part of the P14 packaging contract and is not an external supervisor
script.

The server creates a fixed request-worker set and one fixed monitor for each
request worker. An active slot contains only the admission owned by that
worker. Completion and active-slot clearing are serialized under the same
mutex used by the monitor, and clearing occurs before response publication.
The monitor treats only `REQUEST_ADMITTED` as fatal after its absolute
deadline; queued, cancelled, and completed requests are not fatal.

If an admitted handler reaches its deadline, the process exits normally with
code 70. If shutdown cannot join every connection worker, request worker, and
monitor within the fixed 100 ms shutdown bound, the same exit occurs. Normal
`std::process::exit` is used instead of abort or panic so this containment path
does not create a core dump. The Home Assistant-managed product process model
may restart a fresh server, but no request or confirmation state is recovered
from the terminated process.

Queued requests are cancelled without handler entry when their deadline or
shutdown is observed. A completed handler is linearized before its response;
therefore a monitor cannot terminate the process merely because publication
crosses the deadline after completed state was committed.

## Minimum Acceptance And Pass Limit

This is the consolidated blocker correction authorized by `USR-032`. Exact
same-inode rewrite, destination-ancestor replacement, admitted overrun,
blocked shutdown, completed-monitor, validator-mutation, and existing runtime
tests must pass. One immutable replacement receives only the mandatory five
source reviews and seven phase reviews. The first same-subject PASS
checkpoints immediately; no optional refinement or post-pass review follows.

## Consequences

An arbitrary handler bug can reduce availability by terminating the local
server, but cannot remain live past the containment boundary in a successful
process. The fixed monitor count preserves the worker bound. Product,
protocol, transport source, dependency, cryptographic, and linguistic bytes
remain unchanged.

## Rollback

Do not run `UnixServer` with arbitrary handlers outside the dedicated process.
Keep the P13 server disabled until P14 can package that boundary if fixed fatal
containment or descriptor-relative source replay cannot be reproduced.
