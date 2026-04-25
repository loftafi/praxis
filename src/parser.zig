/// Read fields from a text based data file.
pub const Parser = @This();

data: []const u8,
index: usize,
limit: usize,
line: u32,
column: u32,

/// Wrap a string of bytes with a parser. This wrapper does not need
/// `deinit()`. Use `next_element()` to fetch items.
pub fn init(d: []const u8) Parser {
    return Parser{
        .data = d,
        .index = 0,
        .limit = d.len,
        .line = 0,
        .column = 0,
    };
}

/// Read next ascii character from text data. See also `nextUnicode()`.
pub inline fn next(self: *Parser) u8 {
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

/// Read next unicode character from the text data. See also 'next()`.
pub inline fn nextUnicode(self: *Parser) error{InvalidUtf8}!u21 {
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

/// Preview the next ascii character in the file.
pub inline fn peek(self: *Parser) u8 {
    if (self.eof()) {
        return 0;
    }
    return self.data[self.index];
}

pub inline fn consume_if(self: *Parser, p: u8) bool {
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

pub fn skip_whitespace_and_lines(self: *Parser) []const u8 {
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

pub fn readUntilEol(self: *Parser) []const u8 {
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

pub inline fn eof(self: *Parser) bool {
    return self.index >= self.limit or self.index >= self.data.len;
}

pub fn readLang(t: *Parser) error{InvalidLanguage}!Lang {
    const lang = Lang.parse_code(t.readField());
    if (lang == .unknown) {
        return error.InvalidLanguage;
    }
    return lang;
}

/// Read a slice of a bytes from the source data, ending in a newline, tab, pipe, or zero.
pub fn readField(t: *Parser) []const u8 {
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

pub inline fn readPos(t: *Parser) Parsing {
    return parse_pos(t.readField());
}

pub inline fn readArticle(t: *Parser) error{InvalidGender}!Gender {
    return Gender.parse(t.readField());
}

pub inline fn readStrongs(
    t: *Parser,
    allocator: Allocator,
    numbers: *std.ArrayListUnmanaged(u16),
) error{ OutOfMemory, InvalidU16 }!void {
    try t.readU16s(allocator, numbers);
}

pub inline fn readU16s(
    self: *Parser,
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

pub fn readU16(self: *Parser) error{InvalidU16}!?u16 {
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

pub fn readU24(t: *Parser) error{InvalidU24}!u24 {
    const field = t.readField();
    const value = std.fmt.parseInt(u24, field, 10) catch {
        return error.InvalidU24;
    };
    return value;
}

pub fn readBool(t: *Parser) error{InvalidBooleanField}!bool {
    const field = t.readField();
    if (std.ascii.eqlIgnoreCase(field, "true") or std.ascii.eqlIgnoreCase(field, "yes")) {
        return true;
    }
    if (std.ascii.eqlIgnoreCase(field, "false") or std.ascii.eqlIgnoreCase(field, "no")) {
        return false;
    }
    return error.InvalidBooleanField;
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const Lang = @import("lang.zig").Lang;
const parsing = @import("parsing.zig");
const Parsing = parsing.Parsing;
const Gender = Parsing.Gender;
const parse_pos = @import("part_of_speech.zig").parse_pos;
const expectEqual = std.testing.expectEqual;

test "next and peek" {
    var data = Parser.init("ab.");
    try expectEqual('a', data.next());
    try expectEqual('b', data.peek());
    try expectEqual('b', data.next());
    try expectEqual('.', data.next());
    try expectEqual(0, data.next());
}
test "next unicode" {
    var data = Parser.init("aα.");
    try expectEqual('a', data.nextUnicode());
    try expectEqual('α', data.nextUnicode());
    try expectEqual('.', data.nextUnicode());
    try expectEqual(0, data.nextUnicode());
}
