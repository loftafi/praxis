/// Glosses are a list of words that might be used to translate
/// a word in one language into another language.
///
/// For example: περιπατῶ might be translated into English as
/// "I walk," or "I live."
const Self = @This();

lang: Lang,
entries: std.ArrayList([]const u8),

pub fn create(allocator: std.mem.Allocator) !*Self {
    var gloss = try allocator.create(Self);
    errdefer allocator.destroy(gloss);
    try gloss.init(allocator);
    return gloss;
}

pub fn add_gloss(self: *Self, gloss: []const u8) !void {
    try self.entries.append(try self.entries.allocator.dupe(u8, gloss));
}

pub fn glosses(self: *Self) []const []const u8 {
    return self.entries.items;
}

pub fn destroy(self: *Self) void {
    const current_allocator = self.entries.allocator;
    self.deinit();
    current_allocator.destroy(self);
}

pub fn init(self: *Self, allocator: std.mem.Allocator) !void {
    self.lang = Lang.unknown;
    self.entries = std.ArrayList([]const u8).init(allocator);
}

pub fn deinit(self: *Self) void {
    for (self.entries.items) |*gloss| {
        self.entries.allocator.free(gloss.*);
    }
    self.entries.deinit();
}

pub fn string(self: *const Self, out: anytype) !void {
    var last: u8 = 0;
    for (self.entries.items, 0..) |gloss, i| {
        if (i == 0) {} else {
            try out.writeAll(", ");
        }
        try out.writeAll(gloss);
        if (gloss.len == 0) {
            last = 0;
        } else {
            last = gloss[gloss.len - 1];
        }
    }
    if (last != 0 and last != '.' and last != ';' and last != ')' and last != ',' and last != '?') {
        try out.writeByte('.');
    }
}

pub fn write_binary(self: *const Self, out: *std.ArrayList(u8)) !void {
    try out.append(@intFromEnum(self.lang));
    for (self.entries.items) |g| {
        try out.appendSlice(g);
        try out.append(0);
    }
    try out.append(0);
}

/// Read fields separated by : until an ending character.
/// Example: en:untie:release:loose#ru:развязывать:освобождать:разрушать
pub fn read_text(self: *Self, t: *Parser) !void {
    var start = t.index;
    while (true) {
        const c = t.peek();
        if (c == '\n' or c == '\t' or c == '|' or c == 0 or c == '#' or c == ':') {
            const field = t.data[start..t.index];
            if (self.lang == .unknown) {
                self.lang = Lang.parse_code(field);
            } else if (field.len > 0) {
                try self.add_gloss(field);
            }
            if (c != ':') {
                // The : means continue reading another field,
                // but anything else ends the loop.
                return;
            }
            _ = t.next(); // Consume the :
            start = t.index; // Start at the next item
            continue;
        }
        _ = t.next();
    }
}

pub fn write_text(self: *const Self, w: *std.ArrayList(u8)) !void {
    try w.writer().writeAll(self.lang.to_code());
    try w.writer().writeByte(':');
    for (self.entries.items, 0..) |token, i| {
        if (i > 0) {
            try w.writer().writeByte(':');
        }
        try w.writer().writeAll(token);
    }
}

pub fn read_text_glosses(t: *Parser, entries: *std.ArrayList(*Self)) !void {
    var c = t.peek();
    var loc = t.index;
    while (c != '|' and c != 0) {
        const gloss = try Self.create(entries.allocator);
        errdefer gloss.destroy();
        try gloss.read_text(t);
        try entries.append(gloss);
        c = t.peek();
        if (t.index == loc) {
            break;
        }
        if (c == '#') {
            c = t.next();
            c = t.peek();
        }
        loc = t.index;
    }
}

pub fn read_binary_glosses(t: *BinaryReader, entries: *std.ArrayList(*Self)) !void {
    const gloss_count = try t.u16();
    for (0..gloss_count) |_| {
        const gloss = try Self.create(entries.allocator);
        errdefer gloss.destroy();
        gloss.lang = Lang.from_u8(try t.u8()) catch |e| {
            std.debug.print("invalid language {d} at {d}\n", .{ t.data[t.index - 1], t.index - 1 });
            return e;
        };
        while (true) {
            if (t.peek() == RS or t.peek() == 0) {
                break;
            }
            const entry = try t.string();
            try gloss.add_gloss(entry);
        }
        if (t.peek() != RS) {
            std.debug.print("expected RS, found: {}", .{t.peek()});
            return error.InvalidDictionaryFile;
        }
        _ = try t.u8();
        try entries.append(gloss);
    }
}

const std = @import("std");
const Lang = @import("lang.zig").Lang;
const Parser = @import("parser.zig");
const BinaryReader = @import("binary_reader.zig");
const BinaryWriter = @import("binary_writer.zig");
const RS = BinaryWriter.RS;
const US = BinaryWriter.US;

const eql = @import("std").mem.eql;
const expect = std.testing.expect;
const expectEqualDeep = std.testing.expectEqualDeep;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

test "read_gloss" {
    var data = Parser.init("en:fish:cat#ko:apple|");
    var gloss = try Self.create(std.testing.allocator);
    defer gloss.destroy();
    try gloss.read_text(&data);
    try expectEqual(Lang.english, gloss.lang);
    try expectEqual(2, gloss.glosses().len);
    try expectEqualStrings("fish", gloss.glosses()[0]);
    try expectEqualStrings("cat", gloss.glosses()[1]);
    try expect(data.consume_if('#'));

    var gloss2 = try Self.create(std.testing.allocator);
    defer gloss2.destroy();
    try gloss2.read_text(&data);
    try expectEqual(Lang.korean, gloss2.lang);
    try expectEqual(1, gloss2.glosses().len);
    try expectEqualStrings("apple", gloss2.glosses()[0]);
    try expect(data.consume_if('|'));
}

test "read_bad_gloss1" {
    var data = Parser.init("en:fish,cat|");
    var gloss = try Self.create(std.testing.allocator);
    defer gloss.destroy();
    try gloss.read_text(&data);
    try expectEqual(Lang.english, gloss.lang);
    try expectEqual(1, gloss.glosses().len);
    try expectEqualStrings("fish,cat", gloss.glosses()[0]);
    try expect(data.consume_if('|'));
}

test "read_bad_gloss2" {
    var data = Parser.init("en:fish,cat#|");
    var gloss = try Self.create(std.testing.allocator);
    defer gloss.destroy();
    try gloss.read_text(&data);
    try expectEqual(Lang.english, gloss.lang);
    try expectEqual(1, gloss.glosses().len);
    try expectEqualStrings("fish,cat", gloss.glosses()[0]);
    try expect(data.consume_if('#'));
}

test "read_bad_gloss3" {
    var data = Parser.init("en:|");
    var gloss = try Self.create(std.testing.allocator);
    defer gloss.destroy();
    try gloss.read_text(&data);
    try expectEqual(Lang.english, gloss.lang);
    try expectEqual(0, gloss.glosses().len);
    try expect(data.consume_if('|'));
}

test "read_bad_gloss4" {
    var data = Parser.init("en|");
    var gloss = try Self.create(std.testing.allocator);
    defer gloss.destroy();
    try gloss.read_text(&data);
    try expectEqual(Lang.english, gloss.lang);
    try expectEqual(0, gloss.glosses().len);
    try expect(data.consume_if('|'));
}

test "read_bad_gloss5" {
    var data = Parser.init("true|");
    var gloss = try Self.create(std.testing.allocator);
    defer gloss.destroy();
    try gloss.read_text(&data);
    try expectEqual(Lang.unknown, gloss.lang);
    try expectEqual(0, gloss.glosses().len);
    try expect(data.consume_if('|'));
}

test "read_bad_gloss6" {
    var data = Parser.init("en:fish,cat::a|");
    var gloss = try Self.create(std.testing.allocator);
    defer gloss.destroy();
    try gloss.read_text(&data);
    try expectEqual(Lang.english, gloss.lang);
    try expectEqual(2, gloss.glosses().len);
    try expectEqualStrings("fish,cat", gloss.glosses()[0]);
    try expectEqualStrings("a", gloss.glosses()[1]);
    try expect(data.consume_if('|'));
}

test "gloss_alloc" {
    var data = Parser.init("en:fish:cat#ko:apple|");
    var gloss = try Self.create(std.testing.allocator);
    defer gloss.destroy();
    try gloss.read_text(&data);
    try expectEqual(2, gloss.glosses().len);
    try expectEqualStrings("fish", gloss.glosses()[0]);
    try expectEqualStrings("cat", gloss.glosses()[1]);
}

test "read_text_glosses" {
    var data = Parser.init("en:Aaron#zh:亞倫#es:Aarón||person|");
    var list = std.ArrayList(*Self).init(std.testing.allocator);
    errdefer list.deinit();
    try read_text_glosses(&data, &list);
    try expectEqual(3, list.items.len);
    try expectEqual(Lang.english, list.items[0].lang);
    try expectEqual(Lang.chinese, list.items[1].lang);
    try expectEqual(Lang.spanish, list.items[2].lang);
    for (list.items) |i| {
        i.destroy();
    }
    list.deinit();
}

test "gloss_read_write_bytes" {
    var gloss = try Self.create(std.testing.allocator);
    defer gloss.destroy();
    gloss.lang = .hebrew;
    try gloss.add_gloss("ar");
    try gloss.add_gloss("ci");

    var out = std.ArrayList(u8).init(std.testing.allocator);
    defer out.deinit();
    try gloss.write_binary(&out);

    try expectEqual(8, out.items.len);
    try expectEqual(@intFromEnum(Lang.hebrew), out.items[0]);
    try expectEqual('a', out.items[1]);
    try expectEqual('r', out.items[2]);
    try expectEqual(0, out.items[3]);
    try expectEqual('c', out.items[4]);
    try expectEqual('i', out.items[5]);
    try expectEqual(0, out.items[6]);
    try expectEqual(0, out.items[7]);
}

test "test_gloss_string" {
    var out = std.ArrayList(u8).init(std.testing.allocator);
    defer out.deinit();
    var gloss = try Self.create(std.testing.allocator);
    defer gloss.destroy();
    gloss.lang = .hebrew;
    try gloss.add_gloss("ar");
    try gloss.add_gloss("ci");
    try gloss.string(out.writer());
    try expectEqualStrings("ar, ci.", out.items);
    out.clearRetainingCapacity();

    try gloss.add_gloss("art.");
    try gloss.string(out.writer());
    try expectEqualStrings("ar, ci, art.", out.items);
    out.clearRetainingCapacity();

    try gloss.add_gloss("(small)");
    try gloss.string(out.writer());
    try expectEqualStrings("ar, ci, art., (small)", out.items);
    out.clearRetainingCapacity();
}
