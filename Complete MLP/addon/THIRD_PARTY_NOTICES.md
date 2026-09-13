# Third-party notices

The app is Apache-2.0 licensed. Its Rust dependency source is included under
`vendor/` with upstream license files and exact Cargo checksum manifests.

For the compiled app image, this distribution selects the Apache-2.0 option
where an upstream package offers it, except:

- `memchr` 2.8.3: MIT; copyright © 2015 Andrew Gallant.
- `unicode-ident` 1.0.24: Apache-2.0 plus the required Unicode-3.0 license;
  Unicode data and software copyright © 1991-2023 Unicode, Inc.

The image contains the complete Apache-2.0, selected MIT, and Unicode-3.0
license texts under `/licenses`.
