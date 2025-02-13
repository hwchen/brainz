const std = @import("std");
const common = @import("common.zig");
const Program = common.Program;

pub fn main() anyerror!void {
    try common.runInterpreter(common.parseProgram, interpret);
}

test "og: interpret hello world" {
    try common.testHelloWorld(common.parseProgram, interpret);
}

fn interpret(program: Program, memory: []u8, rdr: anytype, wtr: anytype, alloc: std.mem.Allocator) !void {
    _ = alloc;

    const instructions = program.instructions;
    var pc: usize = 0;
    var dataptr: usize = 0;

    while (pc < instructions.len) {
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
                const saved_pc = pc; // used for error message only

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
                const saved_pc = pc; // used for error message only

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
