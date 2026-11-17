const std = @import("std");
const io = std.io;

// Position + Weight
const Pair = struct {u32, f32};


pub const Tokenizer = struct {

    // string -> (position, weight) in Tokenizer
    lookup: std.StringHashMap(Pair),
    
    pub fn init(allocator: std.mem.Allocator) !Tokenizer {
        return .{
            .lookup = std.StringHashMap(Pair).init(allocator)
        };
    }

    pub fn deinit(self: *Tokenizer) void {
        self.lookup.deinit();
    }

    
    pub fn fromBin(allocator: std.mem.Allocator, io: std.Io, file: std.Io.File) error{InvalidHeader}!Tokenizer {
        // i32 max_token_length
        // {f32 scroe, i32 len, u8[len] bytes}
        const file_size: u32 = std.math.cast(u32, try file.length(io))
            orelse return error.FileTooBig;

        const buffer = try allocator.alloc(u8, file_size);
        defer allocator.free(buffer);

        const count = file.readStreaming(io, &.{buffer[0..]}) catch |err|
            switch (err) {
                error.EndOfStream => break,
                else              => return err,
            };

        if (count != file_size) return error.UnexpectedEndOfFile;
        
        var pos: u32 = 0;  // Position of the token in tokenizer
        var idx: u32 = 4;  // Jump i32 max_token_length
        while (i < file_size) {
            const score: f32 = @bitCast(std.mem.readInt(u32, buffer[idx..][0..4], .little));
            const len: i32 = std.mem.readInt(i32, buffer[idx+4..][0..4], .little);
            const bytes = buffer[idx+8][0..len];
            try self.lookup.put(bytes, .{pos, score});
            idx = idx + 4 + 4 + len;
            pos += 1;
        }
    }

    pub fn encode() []const f32 {

    }

    // pub fn decode() 
};
