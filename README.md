bf interpreter.

following: https://eli.thegreenplace.net/2017/adventures-in-jit-compilation-part-1-an-interpreter/

using: zig nightly (0.11.0-dev.48+678f3f6e6), download zig at https://ziglang.org/download/ . Other versions may work, no guarantees.

Note: to run `fixtures/factor.bf`, overflow must be allowed, so build w/ `-Drelease-fast`.

## usage

stages:
- og (original)
- opt1 (optimized 1)
- ...

```
zig build <stage> -Drelease-fast -- <bf-source-file>
```

There's also a flag to enable tracing of instructions `-Dtrace`, and some fixtures to try in `./fixtures`. So one example run would be:

```
zig build opt1 -Drelease-fast -Dtrace -- fixtures/mandelbrot.bf
```

## Notes

### Tracing

Tracing is enabled/disabled at compile time.

In `build.zig`:

```zig
// Build option for tracing instructions
const trace_value = b.option(bool, "trace", "enable tracing instructions for interpreter") orelse false;
const trace_step = b.addOptions();
trace_step.addOption(bool, "TRACE", trace_value);
```

creates an option with the flag `-Dtrace`, then assigns it to the variable `TRACE`.

Then, for each executable generated, the option is assigned to a package which can be imported.

`build.zig`:
```zig
exe.addOptions("build_with_trace", trace_step);
```

`main.zig`:
```zig
const TRACE = @import("build_with_trace").TRACE;

pub fn main() anyerror!void {
    if (TRACE) {
        std.debug.print("Building with TRACE enabled\n", .{});
    }
```
Branches will be automatically eliminated if trace.TRACE is false.

A comment on discord:
https://discord.com/channels/605571803288698900/605572581046747136/950032936399429662

>there is also aggressive dead-code elimination on comptime-chosen paths. That is to say, if the condition of an if statement/expression is known at comptime (even if the resulting expression is a runtime one), the code of the expression on false will be eliminated, and the contents of the expression of the else clause will be eliminated on true.

There's probably doc for it, will link if found.

## Porting zig to c3

```
brainz lynt| ❯ c3c --version
C3 Compiler Version:       0.6.7 (Pre-release, Feb 13 2025 09:30:57)
Installed directory:       /home/hwchen/c3dev/c3c/build/
Git Hash:                  27f09ca8884f852fa331c94c9d326c23e3597128
Backends:                  LLVM
LLVM version:              18.1.8
LLVM default target:       x86_64-pc-linux-gnu
```

Currently ported just the unoptimized version, but already have some notes
.

- using turnt for snapshot testing, this is already simpler for setting up tests (you don't have to set up writers and readers in unit test framework, or worry about setting up stubs to try to get almost-e2e-testing), but it's also better because you can use the same test suit across different implementations easily.
- `anytype` in Zig is really unhelpful, it requires more descriptive arg names to have any idea what kind of type it is at all.
- I guess I do find `const` and `var` to be line-noise. I'm uncertain how important having these are, but definitely doesn't matter for small hobby projects.
- Zig tendency to chain is actually pretty annoying. I guess this happens in Rust too. Plus the tendency to use a full module prefix, starting from std (probably in part because importing names is such a pain. And I remember shadowing from module names being a pain too).
- I guess that this means that recursive imports in c3 are pretty convenient, but I still have a lot of mixed feelings about them, not sure how it'd work out in a larger project.
- named params with defaults in c3 feel much better.
