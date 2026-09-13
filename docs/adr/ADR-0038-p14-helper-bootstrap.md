# ADR-0038: P14 companion-helper bootstrap

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-09-01
- Owners: P14-P15

## Context

ADR-0037 requires a dedicated Rust helper whose pairing credential enters
through one inherited pipe and never through arguments, environment, files, or
Python protocol objects. The initial Rust helper expected adapter address and
epoch arguments, while the initial Python launcher expected a pairing-ID
argument and a long-lived local Unix endpoint. Those contracts could not form
one product path.

The Home Assistant integration and add-on run in separate containers. A local
Unix socket therefore cannot be their shared transport, and the integration
cannot safely discover an installation-specific add-on DNS name without
another authority-bearing API.

## Decision

The helper has no command arguments and an empty environment. It hardens and
locks its process before reading exactly one 32-byte credential from stdin.
Two non-secret bindings are derived with distinct, length-delimited SHA-256
domains:

- the pairing ID is the first 16 bytes of the pairing-ID digest; and
- the epoch is the complete nonzero pairing-epoch digest.

The Python config flow derives the same pairing ID before handing the
credential view to the helper. It retains neither the credential nor the
epoch.

For initial pairing, the helper owns a bounded TCP listener reachable only
during the pending transaction. The add-on ingress receives the displayed
credential, derives the same bindings, and initiates the selected Noise
profile to the helper through Home Assistant's fixed internal host route. An
authenticated, closed pairing offer supplies the add-on peer identity and its
companion relay port. The helper accepts exactly one matching offer, records
only the authenticated in-memory peer address, and then emits its bounded
stdout proof.

After pairing, the helper exposes a private per-pairing Unix socket to Python.
Each local request uses a fresh Noise connection to the authenticated add-on
peer. The private socket directory is mode `0700`, the socket is mode `0600`,
and Python verifies the helper UID on every connection. Restart, process exit,
or explicit revocation destroys the credential, epoch, peer address, and
socket.

## Consequences

- No credential, pairing ID, epoch, address, or endpoint enters helper argv or
  environment.
- The config flow cannot activate before an add-on proves possession of the
  same credential.
- Every interpretation request receives a fresh connection nonce while stable
  operation identity remains derived from the epoch and request bindings.
- The add-on ingress and helper pairing listeners are bounded bootstrap
  surfaces, not generic HTTP or plaintext execution APIs.

## Rollback

Disable companion execution and terminate both pairing listeners. The
credential-free versioned recognition interface remains available. No
plaintext or argument-bearing helper mode is permitted as a fallback.
