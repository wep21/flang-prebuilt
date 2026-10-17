"""Packages a stripped, optimized Flang driver for one execution platform."""

load("@tar.bzl", "tar")
load(":version.bzl", "VERSION")

def _release_transition_impl(_settings, attr):
    return {
        "//command_line_option:compilation_mode": "opt",
        "//command_line_option:platforms": str(attr.platform),
    }

_release_transition = transition(
    implementation = _release_transition_impl,
    inputs = [],
    outputs = [
        "//command_line_option:compilation_mode",
        "//command_line_option:platforms",
    ],
)

def _flang_for_platform_impl(ctx):
    # Strip the symbol table too, as hermetic-llvm's release config does
    # (--stripopt=--strip-all); the cc_binary's .stripped output only drops
    # debug info. Stripping here keeps the build configuration, and with it
    # the compiled LLVM, independent of strip options.
    out = ctx.actions.declare_file(ctx.label.name + "/" + ctx.file.flang.basename)
    ctx.actions.run(
        executable = ctx.executable._strip,
        arguments = ["--strip-all", ctx.file.flang.path, "-o", out.path],
        inputs = [ctx.file.flang],
        outputs = [out],
        mnemonic = "StripFlang",
    )
    return [DefaultInfo(files = depset([out]))]

_flang_for_platform = rule(
    implementation = _flang_for_platform_impl,
    attrs = {
        "flang": attr.label(
            allow_single_file = True,
            cfg = _release_transition,
            default = "@llvm-project//flang/tools/flang-driver:flang",
        ),
        "platform": attr.label(mandatory = True),
        "_strip": attr.label(
            allow_single_file = True,
            cfg = "exec",
            default = "@llvm//tools:llvm-strip",
            executable = True,
        ),
    },
)

def _mtree_impl(ctx):
    lines = [
        "{}/bin/{} uid=0 gid=0 time=1672560000 mode=0755 type=file content={}".format(
            ctx.attr.prefix,
            ctx.file.flang.basename,
            ctx.file.flang.path,
        ),
    ] + [
        "{}/{} uid=0 gid=0 time=1672560000 mode=0644 type=file content={}".format(
            ctx.attr.prefix,
            f.basename,
            f.path,
        )
        for f in ctx.files.docs
    ]
    out = ctx.actions.declare_file(ctx.label.name + ".mtree")
    ctx.actions.write(out, "\n".join(lines) + "\n")
    return [DefaultInfo(files = depset([out]))]

_mtree = rule(
    implementation = _mtree_impl,
    attrs = {
        "docs": attr.label_list(allow_files = True),
        "flang": attr.label(allow_single_file = True),
        "prefix": attr.string(mandatory = True),
    },
)

def flang_release(name, platform):
    """Declares `flang-<name>-<VERSION>.tar.zst` for one execution platform.

    The archive holds `flang-<name>-<VERSION>/bin/flang` (`flang.exe` on
    Windows) and LLVM's license.

    Args:
      name: `<os>-<arch>` of the archive, e.g. `linux-amd64`.
      platform: hermetic-llvm platform the driver runs on.
    """
    stem = "flang-{}-{}".format(name, VERSION)
    docs = ["@llvm-project//flang:LICENSE.TXT"]
    _flang_for_platform(
        name = name + "_flang",
        platform = platform,
    )
    _mtree(
        name = name + "_mtree",
        docs = docs,
        flang = name + "_flang",
        prefix = stem,
    )
    tar(
        name = name,
        srcs = [name + "_flang"] + docs,
        out = stem + ".tar.zst",
        args = ["--options", "zstd:compression-level=19"],
        compress = "zstd",
        mtree = name + "_mtree",
    )
