// opt1: use jump table

const std = @import("std");
const common = @import("common.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Program = common.Program;
const JumpTable = ArrayList(usize);

pub fn main() anyerror!void {
    try common.runInterpreter(interpret);
}

test "og: interpret hello world" {
    try common.testHelloWorld(interpret);
}

fn interpret(program: Program, memory: []u8, rdr: anytype, wtr: anytype, alloc: Allocator) !void {
    const jumptable = try computeJumptable(program, alloc);
    defer jumptable.deinit();

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
            '[' => if (memory[dataptr] == 0) {
                pc = jumptable.items[pc];
            },
            // jumps to previous matching ']' if curr data != 0
            ']' => if (memory[dataptr] != 0) {
                pc = jumptable.items[pc];
            },
            else => {
                return error.unreachableChar;
            },
        }

        pc += 1;
    }
}

// jump from idx to jmp[idx]. Any non-jump is mapped jmp[idx] = 0
fn computeJumptable(program: Program, alloc: Allocator) !JumpTable {
    var jumptable = try JumpTable.initCapacity(alloc, program.instructions.len);
    jumptable.appendNTimesAssumeCapacity(0, program.instructions.len);

    const instructions = program.instructions;
    var pc: usize = 0;

    // for each bracket, seek the matching bracket
    // and then write both into jumptable
    while (pc < instructions.len) {
        const instruction = instructions[pc];

        if (instruction == '[') {
            var bracket_nesting: usize = 1;
            var seek: usize = pc;

            while (bracket_nesting != 0 and seek < instructions.len - 1) {
                seek += 1;

                const seek_instruction = instructions[seek];
                if (seek_instruction == ']') {
                    bracket_nesting -= 1;
                } else if (seek_instruction == '[') {
                    bracket_nesting += 1;
                }
            }

            if (bracket_nesting == 0) {
                jumptable.items[pc] = seek;
                jumptable.items[seek] = pc;
            } else {
                std.debug.print("unmatched ']' at pc={}", .{pc});
            }
        }
        pc += 1;
    }

    return jumptable;
}
