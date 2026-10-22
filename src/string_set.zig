/// Container for a set of strings that need to be
/// copied and retained using an allocator.
const StringSet = @This();

values: std.StringHashMap(void),
allocator: Allocator,

pub fn init(allocator: Allocator) StringSet {
    return .{
        .allocator = allocator,
        .values = std.StringHashMap(void).init(allocator),
    };
}

pub fn deinit(self: *StringSet) void {
    self.clear();
    self.values.deinit();
}

pub fn clear(self: *StringSet) void {
    var i = self.values.iterator();
    while (i.next()) |x| {
        self.allocator.free(x.key_ptr.*);
    }
    self.values.clearRetainingCapacity();
}

pub fn add(self: *StringSet, text: []const u8) Allocator.Error!bool {
    if (text.len == 0) return false;
    if (self.values.contains(text)) return false;

    try self.values.put(try self.allocator.dupe(u8, text), {});
    return true;
}

pub fn contains(self: *StringSet, text: []const u8) bool {
    return self.values.contains(text);
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const expectEqual = std.testing.expectEqual;

test "simple_string_set" {
    var set = StringSet.init(std.testing.allocator);
    defer set.deinit();
    try expectEqual(true, set.add("apple"));
    try expectEqual(true, set.add("pear"));
    try expectEqual(false, set.add("apple"));
    try expectEqual(true, set.contains("apple"));
    try expectEqual(true, set.contains("pear"));
    try expectEqual(false, set.contains("banana"));
}

test "clear_string_set" {
    var set = StringSet.init(std.testing.allocator);
    defer set.deinit();
    try expectEqual(true, set.add("apple"));
    try expectEqual(true, set.add("pear"));
    try expectEqual(false, set.add("apple"));
    set.clear();
    try expectEqual(false, set.contains("apple"));
}

test "clear_add_clear" {
    var set = StringSet.init(std.testing.allocator);
    defer set.deinit();
    try expectEqual(true, set.add("apple"));
    try expectEqual(true, set.add("pear"));
    try expectEqual(false, set.add("apple"));
    set.clear();
    try expectEqual(false, set.contains("apple"));
    try expectEqual(true, set.add("apple"));
    try expectEqual(true, set.contains("apple"));
}
