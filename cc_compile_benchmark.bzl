load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@rules_cc//cc:action_names.bzl", "CPP_COMPILE_ACTION_NAME")

def _toolchain_flags(ctx, cc_toolchain):
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
    )
    compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        user_compile_flags = ctx.fragments.cpp.cxxopts + ctx.fragments.cpp.copts,
    )
    flags = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = CPP_COMPILE_ACTION_NAME,
        variables = compile_variables,
    )
    return flags

def _cc_compile_benchmark_impl(ctx):
    main_file = ctx.attr.main.files.to_list()[0]

    args = ctx.actions.args()
    outputs = []

    # prepend compiler invocation with `time`
    args.add("-f", "Wall %E\nUser %U\nSys  %S\nMem  %M kB")
    time_file = ctx.actions.declare_file(main_file.basename + ".time")
    args.add("-o", time_file.path)
    outputs.append(time_file)

    # add compiler
    cc_toolchain = find_cpp_toolchain(ctx)
    args.add(cc_toolchain.compiler_executable)

    # add args specified by the toolchain and on the command line
    args.add_all(_toolchain_flags(ctx, cc_toolchain))

    # collect headers, include paths and defines of dependencies
    headers = []
    for dep in ctx.attr.deps:
        if not CcInfo in dep:
            fail("dep arguments must provide CcInfo (e.g: cc_library)")

        # collect exported header files
        compilation_context = dep[CcInfo].compilation_context
        headers.append(compilation_context.headers)

        # add defines
        for define in compilation_context.defines.to_list():
            args.add("-D" + define)

        # add include dirs
        for i in compilation_context.includes.to_list():
            args.add("-I" + i)

        args.add_all(compilation_context.quote_includes.to_list(), before_each = "-iquote")
        args.add_all(compilation_context.system_includes.to_list(), before_each = "-isystem")

    inputs = depset(direct=[main_file], transitive=headers+[cc_toolchain.all_files])

    # add args specified for this rule
    args.add_all(ctx.attr.copts)

    # specify compiler input
    args.add(main_file.path)

    # specify compiler output
    object_file = ctx.actions.declare_file(main_file.basename + ".o")
    args.add("-o", object_file.path)
    outputs.append(object_file)

    # compile only, do not link
    args.add("-c")

    # if compiler is clang, also add -ftime-trace
    if cc_toolchain.compiler_executable.find("clang") != -1:
        args.add("-ftime-trace")
        trace_file = ctx.actions.declare_file(main_file.basename + ".json")
        outputs.append(trace_file)

    ctx.actions.run(
        inputs = inputs,
        outputs = outputs,
        executable = "/usr/bin/time",
        arguments = [args],
        mnemonic = "TimeCppCompile",
        progress_message = "Timed Compiling: " + main_file.basename,
    )

    return [DefaultInfo(files=depset(direct=outputs))]

cc_compile_benchmark = rule(
    implementation = _cc_compile_benchmark_impl,
    attrs = {
        "main": attr.label(allow_files=True, mandatory=True, doc = "Source file to be compiled"),
        "deps": attr.label_list(doc = "Same as cc_binary deps"),
        "copts": attr.string_list(doc = "Same as cc_binary copts"),

        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
    fragments = ["cpp"],
    doc = """Measure the time it takes to compile a single source file.

    Uses /usr/bin/time to measure user/sys/wall time, and peak memory usage.
    If the provided compiler is clang, a time trace report is also provided.
    """
)
