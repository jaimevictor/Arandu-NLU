# P12 Final Reproducibility Review

- Role: `reproducibility`
- Review instance: `01a04bf5-3e35-7721-94be-b45095216a98`
- Subject commit: `77c2cb08d9871a808fe4fa32b4df96a7d47093f8`
- Subject tree: `4b1e5461b2b6497bc78fe945504d1881e6dd8fba`
- Archive SHA-256: `e71fac40f32c2a34bd065b71f6155e21108e410bdc83508c0ae6058de2c0db6a`
- Tree-list SHA-256: `09dcbc34cb122748a9e177b832d8657f81d06e4ca2196d862475616b372971e4`
- Mode: independent read-only primary-evidence review
- Verdict: `PASS`

## Reproduction

Two detached `--no-hardlinks --no-local` clones reproduced the exact
commit/tree with no alternates. Each ran the P12 candidate and mutation gates,
focused and workspace format, strict clippy, locked offline tests, all-target
builds, two clean release builds, and inherited P01-P11 static gates using
Rust 1.98.0, vendored dependencies, empty `HOME`, `LC_ALL=C`,
`SOURCE_DATE_EPOCH=0`, and root remapping.

The focused suite passed 62 tests and the workspace passed 277. The release
libraries were byte-identical across roots:

- `libnlu_core.rlib`: `767daa266c73e7fc8dc6a21117e1fd97ddbe147bfc2ff96530cc210fb943eeea`;
- `libplan_engine.rlib`: `f16effd7ecc61044a5e88be98ef3696a7606ba555c3f07b9c41b0bcc03cccc9c`;
- `libprotocol.rlib`: `8beb610a67ab495586a36ffd499d6f7cf00ceb845399f401a63eed08830e27b7`;
- `libsession_engine.rlib`: `38d7d5faa09afa4839c2efbe3385829c91d124934854b4d645af537a2456b4da`.

## Counterexample

Unshipped debug test executables differed because Mach-O metadata retained
absolute build paths. Their semantic results matched, and the claimed
release-library artifact envelope remained byte-identical.

## Findings

P0: none. P1: none. P2: none. P3: none.

`PASS`
