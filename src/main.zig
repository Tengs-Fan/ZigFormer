const std = @import("std");

const usage =
    \\Usage: zigformer <checkpoint> [options]
    \\
    \\Example: zigformer models/stories260K.bin -n 256 -i "Once upon a time"
    \\
    \\Options:
    \\  -t <float>   temperature in [0, inf), default 1.0
    \\  -p <float>   top-p in [0, 1], default 0.9
    \\  -s <int>     random seed, default time-based
    \\  -n <int>     number of steps to run, default 256
    \\  -i <string>  input prompt
    \\  -z <path>    tokenizer, default models/tok512.bin
    \\  -h, --help   show this help
    \\
;

pub const Options = struct {
    checkpoint: []const u8,
    tokenizer: []const u8 = "models/tok512.bin",
    temperature: f32 = 1.0,
    topp: f32 = 0.9,
    /// null means derive the seed from the current time.
    seed: ?u64 = null,
    steps: u32 = 256,
    prompt: ?[]const u8 = null,
};

pub const ParseError = error{ Help, MissingCheckpoint, MissingValue, UnknownFlag, BadValue };

/// `it` is anything with `next() ?[]const u8` and `skip() bool`, so tests can
/// feed a fixed argument list instead of the real process arguments.
pub fn parseArgs(it: anytype) ParseError!Options {
    _ = it.skip(); // program name
    var checkpoint: ?[]const u8 = null;
    var o: Options = .{ .checkpoint = undefined };
    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) return error.Help;
        if (arg.len != 2 or arg[0] != '-') {
            if (arg.len > 0 and arg[0] == '-') return error.UnknownFlag;
            if (checkpoint != null) return error.UnknownFlag;
            checkpoint = arg;
            continue;
        }
        const val = it.next() orelse return error.MissingValue;
        switch (arg[1]) {
            't' => o.temperature = std.fmt.parseFloat(f32, val) catch return error.BadValue,
            'p' => o.topp = std.fmt.parseFloat(f32, val) catch return error.BadValue,
            's' => o.seed = std.fmt.parseInt(u64, val, 10) catch return error.BadValue,
            'n' => o.steps = std.fmt.parseInt(u32, val, 10) catch return error.BadValue,
            'i' => o.prompt = val,
            'z' => o.tokenizer = val,
            else => return error.UnknownFlag,
        }
    }
    o.checkpoint = checkpoint orelse return error.MissingCheckpoint;
    if (!(o.temperature >= 0) or !(o.topp >= 0 and o.topp <= 1)) return error.BadValue;
    return o;
}

fn describe(err: ParseError) []const u8 {
    return switch (err) {
        error.Help => unreachable,
        error.MissingCheckpoint => "missing checkpoint path",
        error.MissingValue => "flag is missing its value",
        error.UnknownFlag => "unknown flag or extra argument",
        error.BadValue => "invalid flag value",
    };
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var it = init.minimal.args.iterate();
    const opts = parseArgs(&it) catch |err| {
        if (err == error.Help) {
            var hbuf: [1024]u8 = undefined;
            var hw = std.Io.File.stdout().writer(io, &hbuf);
            try hw.interface.writeAll(usage);
            try hw.interface.flush();
            return;
        }
        var ebuf: [1024]u8 = undefined;
        var ew = std.Io.File.stderr().writer(io, &ebuf);
        try ew.interface.print("error: {s}\n\n", .{describe(err)});
        try ew.interface.writeAll(usage);
        try ew.interface.flush();
        std.process.exit(1);
    };

    var buf: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writer(io, &buf);
    defer out.interface.flush() catch {};

    // Inference is not implemented yet; echo the parsed options.
    try out.interface.print("checkpoint:  {s}\n", .{opts.checkpoint});
    try out.interface.print("tokenizer:   {s}\n", .{opts.tokenizer});
    try out.interface.print("temperature: {d}\n", .{opts.temperature});
    try out.interface.print("topp:        {d}\n", .{opts.topp});
    if (opts.seed) |s| {
        try out.interface.print("seed:        {d}\n", .{s});
    } else {
        try out.interface.writeAll("seed:        (time-based)\n");
    }
    try out.interface.print("steps:       {d}\n", .{opts.steps});
    try out.interface.print("prompt:      {s}\n", .{opts.prompt orelse "(none)"});
}

const TestArgs = struct {
    items: []const []const u8,
    i: usize = 0,

    fn next(s: *TestArgs) ?[]const u8 {
        if (s.i == s.items.len) return null;
        defer s.i += 1;
        return s.items[s.i];
    }

    fn skip(s: *TestArgs) bool {
        return s.next() != null;
    }
};

fn parse(items: []const []const u8) ParseError!Options {
    var it: TestArgs = .{ .items = items };
    return parseArgs(&it);
}

test "defaults" {
    const o = try parse(&.{ "zigformer", "m.bin" });
    try std.testing.expectEqualStrings("m.bin", o.checkpoint);
    try std.testing.expectEqualStrings("models/tok512.bin", o.tokenizer);
    try std.testing.expectEqual(@as(f32, 1.0), o.temperature);
    try std.testing.expectEqual(@as(?u64, null), o.seed);
    try std.testing.expectEqual(@as(u32, 256), o.steps);
}

test "all flags, checkpoint after flags" {
    const o = try parse(&.{ "zigformer", "-t", "0.5", "-p", "0.8", "-s", "42", "-n", "10", "-i", "Once", "-z", "t.bin", "m.bin" });
    try std.testing.expectEqualStrings("m.bin", o.checkpoint);
    try std.testing.expectEqual(@as(f32, 0.5), o.temperature);
    try std.testing.expectEqual(@as(f32, 0.8), o.topp);
    try std.testing.expectEqual(@as(?u64, 42), o.seed);
    try std.testing.expectEqual(@as(u32, 10), o.steps);
    try std.testing.expectEqualStrings("Once", o.prompt.?);
    try std.testing.expectEqualStrings("t.bin", o.tokenizer);
}

test "errors" {
    try std.testing.expectError(error.Help, parse(&.{ "zigformer", "--help" }));
    try std.testing.expectError(error.MissingCheckpoint, parse(&.{ "zigformer", "-t", "1" }));
    try std.testing.expectError(error.MissingValue, parse(&.{ "zigformer", "m.bin", "-t" }));
    try std.testing.expectError(error.UnknownFlag, parse(&.{ "zigformer", "m.bin", "-x", "1" }));
    try std.testing.expectError(error.UnknownFlag, parse(&.{ "zigformer", "m.bin", "--temp", "1" }));
    try std.testing.expectError(error.UnknownFlag, parse(&.{ "zigformer", "a.bin", "b.bin" }));
    try std.testing.expectError(error.BadValue, parse(&.{ "zigformer", "m.bin", "-n", "abc" }));
    try std.testing.expectError(error.BadValue, parse(&.{ "zigformer", "m.bin", "-t", "-1" }));
    try std.testing.expectError(error.BadValue, parse(&.{ "zigformer", "m.bin", "-p", "1.5" }));
    try std.testing.expectError(error.BadValue, parse(&.{ "zigformer", "m.bin", "-t", "nan" }));
}
