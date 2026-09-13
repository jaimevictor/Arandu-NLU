# P00 Environment Evidence

- Date: 2026-08-26
- OS/kernel: macOS 26.6.2 build 25G83, Darwin 25.6.0, arm64
- Environment launcher: `/usr/bin/env`, SHA-256
  `75690864f0e7397db05bcc0f4439915559ce24c2d834d530e4e619c14b938556`,
  shell_cmds-329 source commit
  `298787009e5432c5e4c378a077f98267077e3495`,
  `BSD-2-Clause AND BSD-3-Clause`. The required executable scripts clear the
  inherited environment before Ruby starts. macOS may inject
  `__CF_USER_TEXT_ENCODING`; it is the only documented ambient key admitted by
  the CLI and is deleted before validation logic runs.
- Git implementation:
  `/Library/Developer/CommandLineTools/usr/bin/git`, SHA-256
  `be4afb2b003904725826250de9fb76567bbacf82323457b5a1ec26706b66bcae`,
  version 2.50.1 (Apple Git-155), public distribution commit
  `6b2f9bfe72d6d4b5c9bcc1c2d0236c026d321cba`, GPL-2.0-only
- Git dispatch shim: `/usr/bin/git`, SHA-256
  `b8763cf250e607a778bb4603cecb5b90338814d0a3dfcba0d57b1de242f610e9`;
  the validator bypasses this shim.
- Ruby: 2.6.10p210 (Apple ruby-175), public distribution commit
  `4b150aa904ded9fa254bb353bd1feec3c1b72c39`, `Ruby OR BSD-2-Clause`
- Psych: 3.1.0, upstream commit
  `8726508191a91377fa7c4b3f39352e319aa0e390`, MIT
- Embedded libyaml: 0.2.1, upstream commit
  `f6e09f829b606ca0d0adf774236fa8cdd5e2a7d1`, MIT

The macOS 26.6.2 host update changed the bytes of the OS-supplied environment
launcher, Ruby executables, Psych/libyaml bundle, and Git dispatch shim. Their
recorded versions and open-source identity markers remain unchanged; the
toolchain ledger binds the newly observed bytes. The selected Command Line
Tools Git executable did not change.
- Python and `shasum` were observed during exploration but are not required by
  the checked-in P00 validator.

The following required future tools were absent at bootstrap:

- `rustc`, `cargo`, Clippy, and rustfmt;
- `cargo-deny`, `cargo-audit`, and `cargo-cyclonedx`;
- Docker and Podman.

P00 does not compile runtime code, so this is not a P00 product failure. Before
P01 code is created, Rust 1.98.0 must be installed from the immutable,
hash-verified standalone archive into a workspace-local tool home. Rustup 1.29.0
was rejected because its selected source graph contains Amazon-specific
components. Before add-on packaging, a FOSS container path such as Podman with
Lima/Colima must be selected; Docker Desktop is not eligible.

CPU brand and memory queries were blocked by the current sandbox. No performance
claim will use this host until hardware is documented through an approved
measurement environment.

Env, Ruby, and Git dynamically link platform libraries supplied by the
validation host. They are neither shipped nor project dependencies. P00
attests every intentionally selected validator executable and its open-source
program provenance; it does not claim that the complete host OS is open source
or that Apple's host binaries are reproducible from the cited source commits.
Product build and runtime closure must be independently locked and audited in
P01-P15.

No Amazon-specific or Amazon-internal tool, source, endpoint, or credential was
used as a project input. Public
repositories were downloaded only to `/private/tmp` for contract, license, and
source-candidate research.
