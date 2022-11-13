benchmark-factor bin:
    zig build -Drelease-fast && \
    hyperfine 'echo 179424691 | zig-out/bin/og fixtures/factor.bf' 'echo 179424691 | zig-out/bin/{{bin}} fixtures/factor.bf'
