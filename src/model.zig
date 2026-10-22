const std = @import("std");
const Io = std.Io;

const binModel = extern struct {
    dim:        i32,
    hidden_dim: i32,
    n_layers:   i32,
    n_heads:    i32,
    n_kv_heads: i32,
    vocab_size: i32,
    seq_len:    i32,
};

comptime {
    std.debug.assert(@sizeOf(binModel) == 28);
}

pub const Config = struct {
    dimension:          usize,
    hidden_dimension:   usize,
    layers:             usize,
    heads:              usize,
    kv_heads:           usize,
    vocab_size:         usize,
    shared_weight:      bool,
    seq_len:            usize,

    pub fn fromHeader(h: binModel) error{InvalidHeader}!Config {
        inline for (.{ h.dim, h.hidden_dim, h.n_layers, h.n_heads, h.n_kv_heads, h.seq_len }) |v| {
            if (v <= 0) return error.InvalidHeader;
        }
        // Vocab size < 0, means output use different vocab, this should be a separate field, they fixed later
        if (h.vocab_size == 0) return error.InvalidHeader;
        return .{
            .dimension          = @intCast(h.dim),
            .hidden_dimension   = @intCast(h.hidden_dim),
            .layers             = @intCast(h.n_layers),
            .heads              = @intCast(h.n_heads),
            .kv_heads           = @intCast(h.n_kv_heads),
            .shared_weight      = if (h.vocab_size > 0) true else false,
            .vocab_size         = @abs(h.vocab_size),
            .seq_len            = @intCast(h.seq_len),
        };
    }
};
