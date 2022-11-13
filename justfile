benchmark:
    zig build -Drelease-fast && \
    hyperfine zig-out/bin/*
