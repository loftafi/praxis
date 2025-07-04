//! Container for a set of strings that need to be
//! copied and retained using an allocator.

const Self = @This();

values: std.StringHashMap(void),
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) Self {
    return Self{
        .allocator = allocator,
        .values = std.StringHashMap(void).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.clear();
    self.values.deinit();
}

pub fn clear(self: *Self) void {
    var i = self.values.iterator();
    while (i.next()) |x| {
        self.allocator.free(x.key_ptr.*);
    }
    self.values.clearAndFree();
}

pub fn add(self: *Self, text: []const u8) !bool {
    if (self.values.contains(text)) {
        return false;
    }
    try self.values.put(try self.allocator.dupe(u8, text), {});
    return true;
}

pub fn contains(self: *Self, text: []const u8) bool {
    return self.values.contains(text);
}

const std = @import("std");
const expectEqual = std.testing.expectEqual;

test "simple string set" {
    var set = Self.init(std.testing.allocator);
    defer set.deinit();
    try expectEqual(true, set.add("apple"));
    try expectEqual(true, set.add("pear"));
    try expectEqual(false, set.add("apple"));
    try expectEqual(true, set.contains("apple"));
    try expectEqual(true, set.contains("pear"));
    try expectEqual(false, set.contains("banana"));
}
