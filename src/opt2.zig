// opt1: use instructions

const std = @import("std");
const common = @import("common.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const JumpTable = ArrayList(usize);

// comptime known build option, -Dtrace and -Ddebug-opts
const build_options = @import("build_options");
const TRACE = build_options.TRACE;
const DEBUG_OPS = build_options.DEBUG_OPS;

pub fn main() anyerror!void {
    if (TRACE) {
        std.debug.print("Building with TRACE enabled\n", .{});
    }

    try common.runInterpreter(parse, interpret);
}

test "og: interpret hello world" {
    try common.testHelloWorld(parse, interpret);
}

const Program = struct {
    alloc: Allocator,
    ops: []const Op,

    pub fn deinit(self: Program) void {
        self.alloc.free(self.ops);
    }
};

const Op = struct {
    tag: Tag = .invalid,
    value: usize = 0,

    const Tag = enum {
        invalid,
        inc_ptr,
        dec_ptr,
        inc_data,
        dec_data,
        read_stdin,
        write_stdout,
        jump_if_data_zero,
        jump_if_data_not_zero,

        fn is_jump(self: Tag) bool {
            return switch (self) {
                .jump_if_data_zero, .jump_if_data_not_zero => true,
                else => false,
            };
        }

        pub fn format(value: Tag, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;

            switch (value) {
                .invalid => try writer.writeAll("INVALID"),
                .inc_ptr => try writer.writeByte('>'),
                .dec_ptr => try writer.writeByte('<'),
                .inc_data => try writer.writeByte('+'),
                .dec_data => try writer.writeByte('-'),
                .read_stdin => try writer.writeByte(','),
                .write_stdout => try writer.writeByte('.'),
                .jump_if_data_zero => try writer.writeByte('['),
                .jump_if_data_not_zero => try writer.writeByte(']'),
            }
        }
    };
};

fn opsDebug(ops: []const Op) void {
    std.debug.print("\n# Ops\n", .{});
    for (ops) |item, idx| {
        std.debug.print("{d:0>2}: {any} {d}\n", .{ idx, item.tag, item.value });
    }
}

fn parse(src: []const u8, alloc: Allocator) !Program {
    var ops = ArrayList(Op).init(alloc);
    var jump_stack = ArrayList(usize).init(alloc);
    var last_nonjump_tag: Op.Tag = .invalid;
    var last_nonjump_tag_repeat: u8 = 0;
    defer {
        ops.deinit();
        jump_stack.deinit();
    }

    for (src) |c| {
        switch (c) {
            '[', ']' => {
                // jump Ops use a stack to hold state on opening/closing brackets

                // First push the staged Op to `ops`
                if (last_nonjump_tag != .invalid) {
                    try ops.append(Op{
                        .tag = last_nonjump_tag,
                        .value = last_nonjump_tag_repeat,
                    });
                    last_nonjump_tag = .invalid;
                    last_nonjump_tag_repeat = 0;
                }

                // Then handle jump-specific logic, including writing the jump Op to `ops` and
                // pushing/popping stack
                switch (c) {
                    '[' => {
                        // 0 will be rewritten once matching bracket found
                        try ops.append(Op{ .tag = .jump_if_data_zero, .value = 0 });
                        // push the location of the LBracket
                        try jump_stack.append(ops.items.len - 1);
                    },
                    ']' => {
                        if (jump_stack.popOrNull()) |l_bracket_pc| {
                            try ops.append(Op{ .tag = .jump_if_data_not_zero, .value = l_bracket_pc });
                            ops.items[l_bracket_pc].value = ops.items.len - 1;
                        } else {
                            return error.UnmatchedBracket;
                        }
                    },
                    else => unreachable,
                }
            },
            else => {
                // all non-jump Ops can be repeated

                const tag = switch (c) {
                    '>' => Op.Tag.inc_ptr,
                    '<' => Op.Tag.dec_ptr,
                    '+' => Op.Tag.inc_data,
                    '-' => Op.Tag.dec_data,
                    ',' => Op.Tag.read_stdin,
                    '.' => Op.Tag.write_stdout,
                    else => {
                        // Ignore comments
                        continue;
                    },
                };

                if (last_nonjump_tag == .invalid) {
                    last_nonjump_tag = tag;
                    last_nonjump_tag_repeat = 1;
                } else if (tag == last_nonjump_tag) {
                    last_nonjump_tag_repeat += 1;
                } else {
                    try ops.append(Op{
                        .tag = last_nonjump_tag,
                        .value = last_nonjump_tag_repeat,
                    });
                    last_nonjump_tag = tag;
                    last_nonjump_tag_repeat = 1;
                }
            },
        }
        std.log.debug("\n{any}: {d}\n", .{ last_nonjump_tag, last_nonjump_tag_repeat });
        std.log.debug("{any}\n", .{ops.items});
    }

    if (last_nonjump_tag != .invalid) {
        try ops.append(Op{
            .tag = last_nonjump_tag,
            .value = last_nonjump_tag_repeat,
        });
    }

    if (DEBUG_OPS) {
        opsDebug(ops.items);
    }

    return .{ .ops = ops.toOwnedSlice(), .alloc = alloc };
}

test "opt2: parse basic 0" {
    // checks both repeated and jump ops.
    // - jump op ag beginning
    // - nested jump ops
    // - repeated run
    // should also test w/out jump op at beginning.

    const src = "[>>[>]>]>";
    const program = try parse(src, std.testing.allocator);
    defer program.deinit();
    try std.testing.expectEqualSlices(
        Op,
        &.{ Op{
            .tag = .jump_if_data_zero,
            .value = 6,
        }, Op{
            .tag = .inc_ptr,
            .value = 2,
        }, Op{
            .tag = .jump_if_data_zero,
            .value = 4,
        }, Op{
            .tag = .inc_ptr,
            .value = 1,
        }, Op{
            .tag = .jump_if_data_not_zero,
            .value = 2,
        }, Op{
            .tag = .inc_ptr,
            .value = 1,
        }, Op{
            .tag = .jump_if_data_not_zero,
            .value = 0,
        }, Op{
            .tag = .inc_ptr,
            .value = 1,
        } },
        program.ops,
    );
}

test "opt2: parse basic 1" {
    // checking for missing `-`
    // Also for `[` not at beginning, and `]` at end

    const src = ">[--]";
    const program = try parse(src, std.testing.allocator);
    defer program.deinit();
    try std.testing.expectEqualSlices(
        Op,
        &.{ Op{
            .tag = .inc_ptr,
            .value = 1,
        }, Op{
            .tag = .jump_if_data_zero,
            .value = 3,
        }, Op{
            .tag = .dec_data,
            .value = 2,
        }, Op{
            .tag = .jump_if_data_not_zero,
            .value = 1,
        } },
        program.ops,
    );
}

fn interpret(program: Program, memory: []u8, rdr: anytype, wtr: anytype, alloc: Allocator) !void {
    var instruction_count = if (TRACE) std.AutoHashMap(Op.Tag, usize).init(alloc);
    if (TRACE) {
        defer instruction_count.deinit();
    }

    const ops = program.ops;
    var pc: usize = 0;
    var dataptr: usize = 0;

    while (pc < ops.len) {
        const op = ops[pc];

        if (TRACE) {
            var entry = try instruction_count.getOrPut(op.tag);
            if (entry.found_existing) {
                entry.value_ptr.* += 1;
            } else {
                entry.value_ptr.* = 1;
            }
        }

        switch (op.tag) {
            .inc_ptr => dataptr += op.value,
            .dec_ptr => dataptr -= op.value,
            .inc_data => memory[dataptr] += @intCast(u8, op.value),
            .dec_data => memory[dataptr] -= @intCast(u8, op.value),
            .read_stdin => {
                var i: usize = 0;
                while (i < op.value) : (i += 1) {
                    memory[dataptr] = try rdr.readByte();
                }
            },
            .write_stdout => {
                var i: usize = 0;
                while (i < op.value) : (i += 1) {
                    try wtr.writeByte(memory[dataptr]);
                }
            },
            // jumps to next matching ']' if curr_data == 0
            .jump_if_data_zero => if (memory[dataptr] == 0) {
                pc = op.value;
            },
            // jumps to previous matching ']' if curr data != 0
            .jump_if_data_not_zero => if (memory[dataptr] != 0) {
                pc = op.value;
            },
            else => {
                return error.unreachableChar;
            },
        }

        pc += 1;
    }

    if (TRACE) {
        var kv = instruction_count.iterator();
        std.debug.print("\n# Ops Count\n", .{});
        while (kv.next()) |entry| {
            std.debug.print("{c}: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }
}
