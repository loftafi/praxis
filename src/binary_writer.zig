pub inline fn append_u64(allocator: Allocator, data: *ArrayListUnmanaged(u8), value: u64) !void {
    var buffer: [8]u8 = undefined;
    std.mem.writeInt(u64, &buffer, value, .little);
    try data.appendSlice(allocator, buffer[0..8]);
}

pub inline fn append_u32(allocator: Allocator, data: *ArrayListUnmanaged(u8), value: u32) !void {
    var buffer: [4]u8 = undefined;
    std.mem.writeInt(u32, &buffer, value, .little);
    try data.appendSlice(allocator, buffer[0..4]);
}

pub inline fn append_u24(allocator: Allocator, data: *ArrayListUnmanaged(u8), value: u24) !void {
    var buffer: [3]u8 = undefined;
    std.mem.writeInt(u24, &buffer, value, .little);
    try data.appendSlice(allocator, buffer[0..3]);
}

pub inline fn append_u16(allocator: Allocator, data: *ArrayListUnmanaged(u8), value: u32) !void {
    std.debug.assert(value <= 0xffff);
    var buffer: [2]u8 = undefined;
    std.mem.writeInt(u16, &buffer, @as(u16, @intCast(value)), .little);
    try data.appendSlice(allocator, buffer[0..2]);
}

pub inline fn append_u8(allocator: Allocator, data: *ArrayListUnmanaged(u8), value: u32) !void {
    std.debug.assert(value <= 0xff);
    try data.append(allocator, @intCast(value));
}

pub const SPACE = ' ';
pub const TAB = '\t';
pub const CR = '\r';
pub const LF = '\n';
pub const FS = 28; // File separator
pub const GS = 29; // Group (table) separator
pub const RS = 30; // Record separator
pub const US = 31; // Field (record) separator

const std = @import("std");
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;
