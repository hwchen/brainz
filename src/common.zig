// Each program will have it's own `interpret` fn. This module holds all the other setup
// for running a bf program.

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const MEMORY_SIZE = 30000;

pub fn runInterpreter(parse: anytype, interpret: anytype) anyerror!void {
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

    try interpret(program, &memory, stdin.reader(), stdout.writer(), alloc);
}

pub fn parseProgram(src: []const u8, alloc: std.mem.Allocator) !Program {
    var instructions = ArrayList(u8).init(alloc);

    for (src) |c| {
        switch (c) {
            '>', '<', '+', '-', '.', ',', '[', ']' => try instructions.append(c),
            else => {},
        }
    }
    return .{ .instructions = instructions.toOwnedSlice(), .alloc = alloc };
}

pub const Program = struct {
    alloc: Allocator,
    instructions: []const u8,

    fn deinit(self: Program) void {
        self.alloc.free(self.instructions);
    }
};

pub fn testHelloWorld(parse: anytype, interpret: anytype) anyerror!void {
    const expectEqualSlices = std.testing.expectEqualSlices;

    const hello_world = "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.";

    var list = ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    var in_buf: [0]u8 = undefined;
    var empty_in = std.io.fixedBufferStream(&in_buf);

    var memory = [_]u8{0} ** 30000;
    var rdr = empty_in.reader();
    var wtr = list.writer();

    const program = try parse(hello_world, std.testing.allocator);
    defer program.deinit();

    try interpret(program, &memory, rdr, wtr, std.testing.allocator);
    try expectEqualSlices(u8, "Hello World!\n", list.items);
}
