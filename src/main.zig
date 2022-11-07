const std = @import("std");
const ArrayList = std.ArrayList;
const expectEqualSlices = std.testing.expectEqualSlices;

const MEMORY_SIZE = 30000;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var args = std.process.args();
    _ = args.skip();
    const source_path = args.next() orelse return error.MissingSourcePathArg;
    const f = try std.fs.cwd().openFile(source_path, .{});
    defer f.close();

    const src = try f.readToEndAlloc(alloc, 1024 * 20);

    var stdin = std.io.getStdIn();
    var stdout = std.io.getStdOut();
    var memory = [_]u8{0} ** MEMORY_SIZE;

    const program = try parse(src, alloc);
    defer program.deinit();
    try interpret(program, &memory, stdin.reader(), stdout.writer());
}

fn parse(src: []const u8, alloc: std.mem.Allocator) !Program {
    var instructions = ArrayList(u8).init(alloc);

    for (src) |c| {
        switch (c) {
            '>', '<', '+', '-', '.', ',', '[', ']' => try instructions.append(c),
            else => {},
        }
    }
    return .{ .instructions = instructions.toOwnedSlice(), .alloc = alloc };
}

fn interpret(program: Program, memory: []u8, rdr: anytype, wtr: anytype) !void {
    var pc: usize = 0;
    var dataptr: usize = 0;

    while (pc < program.instructions.len) {
        const instructions = program.instructions;
        const instruction = instructions[pc];

        switch (instruction) {
            '>' => dataptr += 1,
            '<' => dataptr -= 1,
            '+' => memory[dataptr] += 1,
            '-' => memory[dataptr] -= 1,
            ',' => memory[dataptr] = try rdr.readByte(),
            '.' => try wtr.writeByte(memory[dataptr]),
            // jumps to next matching ']' if curr_data == 0
            '[' => blk: {
                if (memory[dataptr] != 0) {
                    break :blk;
                }

                var bracket_nesting: usize = 1;
                var saved_pc = pc; // used for error message only

                while (bracket_nesting != 0 and pc < instructions.len - 1) {
                    pc += 1;

                    if (instructions[pc] == ']') {
                        bracket_nesting -= 1;
                    } else if (instructions[pc] == '[') {
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

                    if (instructions[pc] == '[') {
                        bracket_nesting -= 1;
                    } else if (instructions[pc] == ']') {
                        bracket_nesting += 1;
                    }
                }

                if (bracket_nesting != 0) {
                    std.debug.print("unmatched ']' at pc={}", .{saved_pc});
                }
            },
            else => {
                return error.unreachableChar;
            },
        }

        pc += 1;
    }
}

const Program = struct {
    alloc: std.mem.Allocator,
    instructions: []const u8,

    fn deinit(self: Program) void {
        self.alloc.free(self.instructions);
    }
};

test "interpret hello world" {
    // Doesn't test parsing stage (so this input cannot have comments)

    const hello_world = "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.";

    var list = ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    var in_buf: [0]u8 = undefined;
    var empty_in = std.io.fixedBufferStream(&in_buf);

    var memory = [_]u8{0} ** 30000;
    var rdr = empty_in.reader();
    var wtr = list.writer();

    const program = Program{ .instructions = hello_world, .alloc = std.testing.allocator };
    try interpret(program, &memory, rdr, wtr);
    try expectEqualSlices(u8, "Hello World!\n", list.items);
}
