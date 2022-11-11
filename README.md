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
