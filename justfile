bench-factor:
    werk build -Dprofile=release && \
    zig build -Doptimize=ReleaseFast && \
    hyperfine \
    'echo 179424691 | zig-out/bin/opt2 fixtures/factor.bf' \
    'echo 179424691 | target/brainz-c3 fixtures/factor.bf'
