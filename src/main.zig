const std = @import("std");
const ArrayList = std.ArrayList;

const MEMORY_SIZE = 30000;

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
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

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
            ',' => memory[dataptr] = try stdin.reader().readByte(),
            '.' => try stdout.writer().writeByte(memory[dataptr]),
            // jumps to next matching ']' if curr_data == 0
            '[' => blk: {
                if (memory[dataptr] != 0) {
                    break :blk;
                }

                var bracket_nesting: usize = 1;
                var saved_pc = pc; // used for error message only

                while (bracket_nesting != 0 and pc < src.len - 1) {
                    pc += 1;

                    if (src[pc] == ']') {
                        bracket_nesting -= 1;
                    } else if (src[pc] == '[') {
                        bracket_nesting += 1;
                    }
                }

                if (bracket_nesting != 0) {
                    std.debug.print("unmatched '[' at pc={}", .{saved_pc});
                }
            },
            // jumps to previous matching ']' if curr data != 0
            ']' => blk: {
                if (memory[dataptr] == 0) {
                    break :blk;
                }

                var bracket_nesting: usize = 1;
                var saved_pc = pc; // used for error message only

                while (bracket_nesting != 0 and pc > 0) {
                    pc -= 1;

                    if (src[pc] == '[') {
                        bracket_nesting -= 1;
                    } else if (src[pc] == ']') {
                        bracket_nesting += 1;
                    }
                }

                if (bracket_nesting != 0) {
                    std.debug.print("unmatched ']' at pc={}", .{saved_pc});
                }
            },
            else => {},
        }

        pc += 1;
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
