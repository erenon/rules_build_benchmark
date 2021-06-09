# Benchmark compilation

Rules that benchmark compilation.
Right now, this is for C and C++ only.

## Requirements

  - Bazel 4.0 or newer
  - /usr/bin/time

## Example

Copy `cc_compile_benchmark.bzl` into your workspace, then:

    load("cc_compile_benchmark.bzl", "cc_compile_benchmark")

    cc_compile_benchmark(
        name = "benchmark_example_compilation",
        main = "example.cpp",
        deps = [...], # if needed
        copts = [...], # if needed
    )

If gcc is used, `cc_compile_benchmark` produces a `.time` file,
written by `time`, measuring the compilation (not the linking)
of the given source file:

    $ bazel build benchmark_example_compilation
    Target //:benchmark_example_compilation up-to-date:
      bazel-bin/example.cpp.time
      bazel-bin/example.cpp.o
    INFO: Build completed successfully, 1 total action

    $ cat bazel-bin/example.cpp.time
    Wall 0:00.70
    User 0.65
    Sys  0.04
    Mem  112780 kB

If clang is used, the result of `-ftime-trace` is also saved:

    $ CC=clang CXX=clang++ ~/bin/bazel build benchmark_example_compilation
    Target //:benchmark_example_compilation up-to-date:
      bazel-bin/example.cpp.time
      bazel-bin/example.cpp.o
      bazel-bin/example.cpp.json
    INFO: Build completed successfully, 1 total action

The json file can be loaded into chrome://tracing.
