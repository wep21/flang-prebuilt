"""Release version: `<LLVM version>.<SERIAL>`, also the git tag to push."""

load("@llvm-project//:vars.bzl", "PACKAGE_VERSION")

# Bump when re-releasing the same LLVM version; reset to 1 for a new one.
SERIAL = 1

VERSION = "{}.{}".format(PACKAGE_VERSION, SERIAL)
