//! Read fields from a data file.

data: []const u8,
index: usize,
limit: usize,
line: u32,
column: u32,

pub const Self = @This();

/// Wrap a string of bytes with a parser. This wrapper does not need
/// `deinit()`. Use `next_element()` to fetch items.
pub fn init(d: []const u8) Self {
    return Self{
        .data = d,
        .index = 0,
        .limit = d.len,
        .line = 0,
        .column = 0,
    };
}

pub inline fn next(self: *Self) u8 {
    if (self.eof()) {
        return 0;
    }
    const c = self.data[self.index];
    if (c == '\n') {
        if (self.line == 0xffffffff) {
            @panic("Input has an unexpectedly long number of lines.");
            //return error.TextFileLineLimit;
        }
        self.line += 1;
        self.column = 0;
    }
    self.index += 1;
    return c;
}

pub inline fn next_unicode(self: *Self) error{InvalidUtf8}!u21 {
    if (self.eof()) {
        return 0;
    }
    const x: u8 = self.data[self.index];
    const l = @as(usize, std.unicode.utf8ByteSequenceLength(x) catch |e| {
        std.debug.print("invalid utf8. ({any})\n", .{e});
        std.debug.print("  {any} {any}\n", .{ self.index, self.data });
        std.debug.print("  {s}\n", .{self.data});
        return error.InvalidUtf8;
    });
    const c: u21 = std.unicode.utf8Decode(self.data[self.index..(self.index + l)]) catch |e| {
        std.debug.print("invalid utf8. ({any})\n", .{e});
        std.debug.print("  {any} {any}\n", .{ self.index, self.data });
        std.debug.print("  {s}\n", .{self.data});
        return error.InvalidUtf8;
    };
    if (c == '\n') {
        self.line += 1;
        self.column = 0;
    }
    self.index += l;
    return c;
}

pub inline fn peek(self: *Self) u8 {
    if (self.eof()) {
        return 0;
    }
    return self.data[self.index];
}

pub inline fn consume_if(self: *Self, p: u8) bool {
    if (self.eof()) {
        return false;
    }
    const c = self.data[self.index];
    if (c != p) {
        return false;
    }
    if (c == '\n') {
        self.line += 1;
        self.column = 0;
    }
    self.index += 1;
    return true;
}

pub fn skip_whitespace_and_lines(self: *Self) []const u8 {
    const start = self.index;
    while (!self.eof()) {
        const c = self.peek();
        if (!is_whitespace_or_eol(c)) {
            break;
        }
        _ = self.next();
    }
    return self.data[start..self.index];
}

pub fn read_until_eol(self: *Self) []const u8 {
    const start = self.index;
    var last_character = start;
    while (!self.eof()) {
        const c = self.peek();
        if (c == '~') {
            break;
        }
        if (is_eol(c)) {
            break;
        }
        if (!is_whitespace(c)) {
            last_character = self.index + 1;
        }
        _ = self.next();
    }
    return self.data[start..last_character];
}

pub inline fn is_eol(c: u8) bool {
    return c == '\n' or c == '\r' or c == 0;
}

pub inline fn is_whitespace(c: u8) bool {
    return c == ' ' or c == '\t';
}

pub inline fn is_whitespace_or_eol(c: u8) bool {
    return c == ' ' or c == '\n' or c == '\r' or c == '\t' or c == 0;
}

pub inline fn eof(self: *Self) bool {
    return self.index >= self.limit or self.index >= self.data.len;
}

pub fn read_lang(t: *Self) error{InvalidLanguage}!Lang {
    const lang = Lang.parse_code(t.read_field());
    if (lang == .unknown) {
        return error.InvalidLanguage;
    }
    return lang;
}

pub inline fn read_pos(t: *Self) Parsing {
    const pos = parse_pos(t.read_field());
    return pos;
}

pub inline fn read_article(t: *Self) error{InvalidGender}!Gender {
    return Gender.parse(t.read_field());
}

pub inline fn readStrongs(
    t: *Self,
    allocator: Allocator,
    numbers: *std.ArrayListUnmanaged(u16),
) error{ OutOfMemory, InvalidU16 }!void {
    try t.read_u16s(allocator, numbers);
}

pub inline fn read_u16s(
    self: *Self,
    allocator: Allocator,
    numbers: *std.ArrayListUnmanaged(u16),
) error{ OutOfMemory, InvalidU16 }!void {
    while (true) {
        if (self.eof()) {
            return;
        }
        var p = self.peek();
        if (p == ' ' or p == ',') {
            _ = self.next();
            continue;
        }
        if (p < '0' or p > '9') {
            break;
        }
        var value: u32 = 0;
        while (p >= '0' and p <= '9') {
            value = (value * 10) + (p - '0');
            if (value > 0xffff) {
                return error.InvalidU16;
            }
            _ = self.next();
            p = self.peek();
        }
        try numbers.append(allocator, @intCast(value));
    }
}

pub fn read_u16(self: *Self) error{InvalidU16}!?u16 {
    if (self.eof()) {
        return null;
    }
    var p = self.peek();
    while (p == ' ' or p == ',') {
        _ = self.next();
        p = self.peek();
        continue;
    }
    if (p < '0' or p > '9') {
        return null;
    }
    // There is a number, read it
    var value: u32 = 0;
    while (p >= '0' and p <= '9') {
        value = (value * 10) + (p - '0');
        if (value > 0xffff) {
            return error.InvalidU16;
        }
        _ = self.next();
        p = self.peek();
    }
    return @intCast(value);
}

pub fn read_u24(t: *Self) error{InvalidU24}!u24 {
    const field = t.read_field();
    const value = std.fmt.parseInt(u24, field, 10) catch {
        return error.InvalidU24;
    };
    return value;
}

pub fn read_bool(t: *Self) error{InvalidBooleanField}!bool {
    const field = t.read_field();
    if (std.ascii.eqlIgnoreCase(field, "true") or std.ascii.eqlIgnoreCase(field, "yes")) {
        return true;
    }
    if (std.ascii.eqlIgnoreCase(field, "false") or std.ascii.eqlIgnoreCase(field, "no")) {
        return false;
    }
    return error.InvalidBooleanField;
}

/// Read a slice of a bytes from the source data, ending in a newline, tab, pipe, or zero.
pub fn read_field(t: *Self) []const u8 {
    const start = t.index;
    while (true) {
        const c = t.peek();
        if (c == '\n' or c == '\r' or c == '\t' or c == '|' or c == 0) {
            const field = t.data[start..t.index];
            return field;
        }
        _ = t.next();
    }
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Lang = @import("lang.zig").Lang;
const parsing = @import("parsing.zig");
const Parsing = parsing.Parsing;
const Gender = Parsing.Gender;
const parse_pos = @import("part_of_speech.zig").parse_pos;
const expectEqual = std.testing.expectEqual;

test "next and peek" {
    var data = Self.init("ab.");
    try expectEqual('a', data.next());
    try expectEqual('b', data.peek());
    try expectEqual('b', data.next());
    try expectEqual('.', data.next());
    try expectEqual(0, data.next());
}
test "next unicode" {
    var data = Self.init("aα.");
    try expectEqual('a', data.next_unicode());
    try expectEqual('α', data.next_unicode());
    try expectEqual('.', data.next_unicode());
    try expectEqual(0, data.next_unicode());
}
