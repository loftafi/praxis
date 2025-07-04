const std = @import("std");

test {
    const praxis = @import("praxis.zig");
    std.testing.refAllDecls(praxis);
}
