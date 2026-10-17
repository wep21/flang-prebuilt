# flang-prebuilt

Static, self-contained [LLVM Flang](https://flang.llvm.org) drivers, built
from source with the [hermetic-llvm](https://github.com/hermeticbuild/hermetic-llvm)
toolchain and published as GitHub releases. They are what rules_ft (Bazel
rules for Fortran on top of hermetic-llvm, not published yet) uses to compile
Fortran, the way rules_qemu uses qemu-prebuilt.

> **Experimental.** This repository is a trial of building Flang on standard
> GitHub runners; see [Status](#status).

The official LLVM release archives ship Flang only inside the full LLVM
distribution (~2 GB), dynamically linked against the host's glibc, libstdc++
and libquadmath, and not at all for macOS. These archives contain just the
driver:

| Archive | Runs on |
| --- | --- |
| `flang-linux-amd64-<version>.tar.zst` | Linux x86_64, any distribution (static, musl) |
| `flang-linux-arm64-<version>.tar.zst` | Linux aarch64, any distribution (static, musl) |
| `flang-darwin-arm64-<version>.tar.zst` | macOS arm64 |
| `flang-darwin-amd64-<version>.tar.zst` | macOS x86_64 |

Each holds `flang-<os>-<arch>-<version>/bin/flang` and LLVM's `LICENSE.TXT`,
and comes with a `<archive>.sha256` file and a GitHub build attestation.
`<version>` is `<LLVM version>.<serial>`, e.g. `23.1.2.1`. The driver targets
every architecture LLVM was built for; pass `--target=`. Fortran runtimes and
intrinsic modules are not included: they are target-specific, and rules_ft
builds them for the target platform.

## Building

This is a Bazel module that builds the upstream Bazel overlay's
`@llvm-project//flang/tools/flang-driver:flang` with hermetic-llvm (`-c opt`,
then `llvm-strip --strip-all`). It asks hermetic-llvm for the Flang sources with
`llvm.configure(flang = True)`, which no hermetic-llvm release has yet, so
`MODULE.bazel` pins a hermetic-llvm commit that adds it (`git_override`). To
build against a local checkout instead:

```sh
echo "common --override_module=llvm=$HOME/src/hermetic-llvm" >> user.bazelrc
bazel build --jobs=6 //:linux-amd64      # or //:all
ls bazel-bin/flang-*.tar.zst
```

Each archive builds LLVM, MLIR and Flang (~10k actions); budget 2-3 GB of
memory per job.

## Releasing

1. Update `llvm` in `MODULE.bazel`; the LLVM version comes from it. Set
   `SERIAL` in `version.bzl` (1 for a new LLVM version, +1 to rebuild the same
   one).
2. Push a tag equal to `VERSION` (e.g. `23.1.2.1`).
   `.github/workflows/release.yaml` builds every archive, checks that the tag
   matches, and publishes the release with checksums and attestations.
   Standard runners may be too slow; use larger runners or remote execution
   if jobs time out.

Verify an archive with:

```sh
gh attestation verify flang-linux-amd64-23.1.2.1.tar.zst --repo wep21/flang-prebuilt
```

## Status

`linux-amd64` has been built locally (a static, stripped 197 MB `bin/flang`,
45 MB compressed) and passes rules_ft's test suite as its compiler. The other
archives build the same targets for other platforms and analyze, but have not
been built yet. Nothing has been released.

Before the first release, add the license of musl (MIT), which the Linux
drivers link statically, next to LLVM's `LICENSE.TXT`; hermetic-llvm does not
export musl's `COPYRIGHT` file yet.

## License

The build files are Apache-2.0 (see [LICENSE](LICENSE)). Flang is part of the
LLVM project, Apache-2.0 WITH LLVM-exception.
