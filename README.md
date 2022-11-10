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

There's also a flag to enable tracing `-Dtrace`, and some fixtures to try in `./fixtures`. So one example run would be:

```
zig build opt1 -Drelease-fast -Dtrace -- fixtures/mandelbrot.bf
```
