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
    
    pub fn fromBin(allocator: std.mem.Allocator, file_io: std.Io, file: std.Io.File) !Tokenizer {
        var tokenizer = try Tokenizer.init(allocator);
        // i32 max_token_length
        // {f32 scroe, i32 len, u8[len] bytes}
        const file_size: u32 = std.math.cast(u32, try file.length(file_io))
            orelse return error.FileTooBig;

        const buffer = try allocator.alloc(u8, file_size);
        defer allocator.free(buffer);

        const count = try file.readPositionalAll(file_io, buffer, 0);
        if (count != file_size) return error.UnexpectedEndOfFile;
        if (count <= 4) return error.InvalidHeader;
        
        var pos: u32 = 0;  // Position of the token in tokenizer
        var idx: u32 = 4;  // Jump i32 max_token_length
        while (idx < file_size) {
            const score: f32 = @bitCast(std.mem.readInt(u32, buffer[idx..][0..4], .little));
            const len: u32 = std.mem.readInt(u32, buffer[idx+4..][0..4], .little);
            const bytes = buffer[idx+8..][0..len];
            try tokenizer.lookup.put(bytes, .{pos, score});
            errdefer tokenizer.deinit();
            idx = idx + 4 + 4 + len;
            pos += 1;
        }
        return tokenizer;
    }

    pub fn encode() []const f32 {

    }

    // pub fn decode() 
};
