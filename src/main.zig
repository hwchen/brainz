const std = @import("std");
const ArrayList = std.ArrayList;

const MEMORY_SIZE = 10; //30000;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var args = std.process.args();
    _ = args.skip();
    const source_path = args.next() orelse return error.MissingSourcePathArg;
    std.debug.print("source path: {s}\n", .{source_path});
    const f = try std.fs.cwd().openFile(source_path, .{});
    defer f.close();

    const src = try f.readToEndAlloc(alloc, 2048);
    std.debug.print("{s}", .{src});

    try interpret(src);
}

fn interpret(src: []const u8) !void {
    var memory = [_]u8{0} ** MEMORY_SIZE;

    var pc: usize = 0;
    var dataptr: usize = 0;

    while (pc < src.len) {
        const instruction = src[pc];

        switch (instruction) {
            '>' => dataptr += 1,
            '<' => dataptr -= 1,
            '+' => memory[dataptr] += 1,
            '-' => memory[dataptr] -= 1,
            else => {},
        }
        std.debug.print("{any}\n", .{memory});

        pc += 1;
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
