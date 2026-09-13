# P13 Exact-Source Compatibility And Transport Evidence

- Phase: `P13`
- Convergence pass: 3 of 3
- Evidence track result: `PASS`
- Transport portfolio: `REJECTED_NO_FUTURE_PRODUCT_USE`
- Technical fixture label: `FIXTURE_TECNICA`
- Language outputs used as gold: no

## Scope And Result

This track validates the exact admitted Home Assistant 2026.8.3 and Wyoming
1.10.0 reference contracts, records exact rejection evidence for the CPython
3.14.6 and OpenSSL 3.6.3 portfolio, and executes a bounded TLS 1.3
external-PSK capability probe. It does not admit any part of that portfolio
for product selection, build, runtime, packaging, distribution, or P14 reuse.

The exact-source verifier passes. All four compatibility properties are lost
on the Home Assistant Wyoming bridge and therefore have the disposition
`companion_required_or_abstain`. Both exact arm64 macOS runtimes pass the local
capability probe. They remain rejected: both source archives contain known
non-OSI or public-domain-dedication witnesses, the witness list is
non-exhaustive, the controlled build compiled all four recorded witnesses, and
the exact source-to-distributable-runtime mapping is not established.

## Exact Sources

| Source | Immutable identity | License |
| --- | --- | --- |
| CPython 3.14.6 | archive 23,921,184 bytes; SHA-256 `143b1dddefaec3bd2e21e3b839b34a2b7fb9842272883c576420d605e9f30c63`; clean 5,100-file tree SHA-256 `b7e662cf62918c5746d04f6e26103a3ba185502b468cfc8c5218f970c96949e5` | Primary license is PSF-2.0; the complete archive is rejected after recording CC0 witnesses in bundled Expat SipHash and BLAKE2 |
| OpenSSL 3.6.3 | archive 54,953,005 bytes; SHA-256 `243a86649cf6f23eeb6a2ff2456e09e5d77dd9018a54d3d96b0c6bdd6ba6c7f1`; deterministic tree SHA-256 `ea06723083780b098e038e955cfdb1113eb38d8da833c3a84624937ede12b6ea` | Primary license is Apache-2.0; the complete archive is rejected after recording CC0 SipHash and public-domain-dedicated AES witnesses |
| Home Assistant 2026.8.3 | commit `759e4658f40b3ccb671d418b8a0ed95224bf4561`; tree `f4a72534bb33abf8b5d183910a0c134b968af2f8`; selected archive 501,760 bytes; SHA-256 `e91f94715eee2ed7771b59bcb4aa68fda3722720d817211a0db541c5fe34c799` | Apache-2.0; `LICENSE.md` SHA-256 `c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4` |
| Wyoming 1.10.0 | commit `bf65f4e645770909a87c0e59010e0cc71631e4a5`; tree `21d7ab51abc067576675ccbe8d48d0c8d17ae7c8`; deterministic Git archive 245,760 bytes; SHA-256 `96d5967140a99bd859fdc604fcd7346304560eb219f0a589b8ddefabf903ffa9` | MIT; `LICENSE.md` SHA-256 `13746d509d74e55ea2265fbef204bb7cdbf84a8315b0207e988326cb54387028` |

The deterministic extracted-tree algorithm is recorded exactly in
`P13-EXACT-SOURCES.yaml`. The verifier recomputes every archive, clean tree,
license, and selected path hash and requires the CPython and OpenSSL extracted
file sets to equal their archive file sets. It also computes Git blob IDs for
every Home Assistant selected path and compares them with the exact commit
tree without fetching missing objects. It regenerates the Wyoming archive
from the exact local Git commit and requires byte-for-byte equality.

All four archive-to-tree mode transitions are recorded and verifier-enforced.
CPython's 4,993 regular and 107 executable file modes are unchanged. OpenSSL
normalizes 5,697 regular and 159 executable files, Home Assistant normalizes
14 regular files, and Wyoming normalizes 55 regular and five executable files
by clearing group-write under the recorded `0022` umask. No path or content
changed. Each resulting mode is part of the recorded tree identity.

The supplied CPython commit
`c63aec69bd59c55314c06c23f4c22c03de76fe45` and OpenSSL commit
`aae016bfd52fcad2bc9657c2c782cfdf73b1ed5f` are recorded, but the release
archives contain no Git metadata. Their commit-to-release-archive mapping is
therefore not independently proven by these bytes. This is an additional
rejection fact, not a condition under which the portfolio can be promoted.

## Compatibility Findings

| Property | Exact source observation | Disposition |
| --- | --- | --- |
| Complete clarification | Wyoming `intent.py` exposes intent, not-recognized, and list-boundary events; `handle.py` exposes text/context handling events. There is no typed clarification result carrying bounded options and continuation state. The HA bridge maps recognized events directly to `intent.async_handle`. | `companion_required_or_abstain` |
| Ordered execution | HA `conversation.py` lines 242-279 creates one task per recognized intent inside `asyncio.TaskGroup`. Result collection order does not serialize effects. | `companion_required_or_abstain` |
| Caller context | HA `models.py` lines 20-55 contains `ConversationInput.context`. The bridge lines 116-127 sends only conversation, device, and satellite metadata, and lines 268-278 calls `intent.async_handle` without `context`; `helpers/intent.py` lines 99-119 then creates a new `Context`. | `companion_required_or_abstain` |
| Explicit continuation | HA `models.py` line 80 defaults `continue_conversation` to false. The bridge never sets it and never consumes `Intent.context`, `NotRecognized.context`, or `Handled.context`. | `companion_required_or_abstain` |

These are protocol and bridge-contract findings, not language judgments. No
recognized output, response text, or project NLU output is an oracle or gold
record.

## Transport Source Findings

CPython `Modules/_ssl.c` exposes client and server PSK callbacks. Each callback
receives a Python bytes object and copies it with `memcpy` into an OpenSSL
callback buffer. The Python object and callback copy are not individually
locked or immediately zeroized by this path.

OpenSSL `ssl/statem/extensions_clnt.c` and `extensions_srvr.c` place legacy
callback PSKs in stack arrays, copy them into an `SSL_SESSION`, and cleanse the
temporary stack arrays. `ssl/ssl_sess.c` cleanses the session master-key array
when the session is freed. `ssl/ssl_local.h` contains early, handshake, master,
resumption, and exporter secret storage. These exact paths do not establish
per-copy memory locking or immediate destruction.

OpenSSL `crypto/siphash/siphash.c` incorporates a CC0 reference
implementation by Jean-Philippe Aumasson and Daniel J. Bernstein. The
controlled build's `configdata.pm` includes that file in the linked runtime.
Its `crypto/aes/aes_core.c` is placed in the public domain by Vincent Rijmen,
Antoon Bosselaers, and Paulo Barreto and was also compiled into the runtime.
CPython's controlled build compiled the bundled Expat CC0 SipHash and the
CC0-dedicated BLAKE2 module. These four witnesses are sufficient to reject the
portfolio; they are not represented as a complete archive license inventory.

OpenSSL constructs `psk_dhe_ke` by default unless the no-DHE option is enabled.
The probe checks the raw ClientHello contains only PSK mode `1`, plus key-share
and pre-shared-key extensions, and that ServerHello selects both key share and
PSK identity zero.

The legacy PSK callbacks cannot perform TLS 1.3 early data according to the
exact OpenSSL API source documentation. OpenSSL also documents external TLS
1.3 PSK connections as `session_reused = true`; this flag is not evidence of
ticket resumption. The probe instead requires no NewSessionTicket, no early
data extension or message, `num_tickets = 0`, `OP_NO_TICKET`, no session
ticket, fresh contexts, and rejection of a supplied session.

## Build And Runtime

The exploratory controlled source build used `darwin64-arm64-cc`, shared
OpenSSL, and `no-tests`, installed under `/private/tmp/p13-openssl-install`,
then configured CPython with that exact OpenSSL and an automatic rpath.
CPython built 114 modules with `_ssl` and `_hashlib`; four unrelated optional
modules were missing and test modules were disabled. The resulting arm64
`_ssl` bundle links only the exact private OpenSSL 3.6.3 dylibs and the ambient
host `libSystem`. This build is rejected for product use because it compiled
all four recorded Expat SipHash, CPython BLAKE2, OpenSSL SipHash, and OpenSSL
AES rejection witnesses; its probe is capability evidence only.

The exact Homebrew runtime is CPython 3.14.6 arm64 linked to OpenSSL 3.6.3. Its
`CONFIG_ARGS` selects `/opt/homebrew/opt/openssl@3`; its receipt identifies an
arm64 bottle and OpenSSL 3.6.3 as a direct dependency. The executable,
framework, `_ssl`, OpenSSL CLI, `libssl`, `libcrypto`, receipt, and retained
license hashes are pinned in `P13-EXACT-SOURCES.yaml` and checked by the
verifier. This proves the observed local runtime identity, not the complete
Homebrew source/build closure or a distributable project runtime.
The Homebrew runtime is also not admitted because its exact source-to-binary
mapping is unproven and the reviewed OpenSSL source bundle contains the same
non-OSI component.

## Executable Probe

`tools/p13-transport-probe` uses bounded in-memory BIOs and performs no network
operation. The successful case requires:

- TLS 1.3 on both peers with fixed roles;
- both external-PSK callbacks and the exact `FIXTURE_TECNICA` identity;
- raw ClientHello and ServerHello proof of PSK-DHE;
- the fixed `FIXTURE_TECNICA` ALPN on both peers;
- no certificate, certificate request, or certificate-verify message;
- no TLS 1.2, ticket, resumption input, or early-data extension/message;
- at most 256 handshake steps, 1,048,576 transferred handshake bytes, and two
  monotonic seconds; and
- an encrypted `FIXTURE_TECNICA` application request and acknowledgement only
  after the complete transport profile passes.

The active negatives reject wrong and empty identity, wrong and empty keys,
missing callbacks, and TLS 1.2 during TLS setup. Raw TLS permits a no-overlap
ALPN connection and can use a loaded certificate when PSK is absent. Those two
mutations are therefore rejected by the fixed profile after the cryptographic
handshake but before any application byte. Enabling tickets or supplying a
session is likewise rejected by the profile before application data.

Both exact local runtimes returned `P13_TRANSPORT_PROBE_PASS` and
`P13_SECRET_MEMORY_CONDITIONAL`. The latter is a probe risk marker retained as
historical capability evidence; it does not make product admission
conditional.

## Secret-Memory Compromise

This track does not claim every PSK or derived-secret copy is individually
locked or immediately zeroized. For a separately admitted replacement
runtime, ADR-0019 permits the bounded workaround: persistent active secrets
must exist only in dedicated P14 peer processes, each process must lock its
complete address space before receiving a secret, and startup or pairing must
fail if locking cannot be established.

Linux `mlockall`, lock-limit handling, no-dump configuration, swap controls,
secret lifecycle, crash behavior, diagnostics, persistence, backups, and
restart/revocation behavior are not proven here. P14 must establish them for
its replacement transport on both packaged architectures. The local macOS
probe is rejection and capability evidence only.

## Final Disposition

ADR-0021 permanently rejects the complete archives, controlled build,
Homebrew runtime, and every derived projection. No additional review or
sanitization can promote this portfolio. P14 starts from a different
standardized transport and independently admitted OSI-licensed source set.
Plaintext and project-authored cryptography remain prohibited.

## Commands

```text
tools/p13-evidence
tools/p13-evidence --skip-runtime
tools/p13-transport-probe
P13_PYTHON=/private/tmp/p13-python-install/bin/python3.14 tools/p13-transport-probe
tools/test-p13-evidence
ruby -c tools/p13-evidence.rb
ruby -c tools/test-p13-evidence.rb
/opt/homebrew/bin/python3.14 -c 'import ast, pathlib; ast.parse(pathlib.Path("tools/p13-transport-probe.py").read_text(encoding="utf-8"), filename="tools/p13-transport-probe.py")'
git diff --check
```
