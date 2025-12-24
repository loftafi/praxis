/// A form is a string of letters that form an individual word as
/// it would be written or spoken in real life such as "jump,"
/// "jumping" or "jumps". Related form of a word are collected into
/// a `Lexeme` object.
uid: u24 = 0,
word: []const u8,
parsing: Parsing = .{},
preferred: bool = false,
incorrect: bool = false,
references: std.ArrayListUnmanaged(Reference) = .empty,
glosses: std.ArrayListUnmanaged(*Gloss) = .empty,
lexeme: ?*Lexeme = null,

const Form = @This();

pub fn create(allocator: Allocator) error{OutOfMemory}!*Form {
    var s = try allocator.create(Form);
    errdefer allocator.destroy(Form);
    s.init();
    return s;
}

pub fn destroy(self: *Form, allocator: Allocator) void {
    self.deinit(allocator);
    allocator.destroy(self);
}

pub const empty = Form{
    .uid = 0,
    .word = "",
    .parsing = .{},
    .lexeme = null,
    .preferred = false,
    .incorrect = false,
    .glosses = .empty,
    .references = .empty,
};

pub fn init(self: *Form) void {
    self.* = .empty;
}

pub fn deinit(self: *Form, allocator: Allocator) void {
    if (self.word.len > 0)
        allocator.free(self.word);

    for (self.glosses.items) |gloss| {
        gloss.destroy(allocator);
    }
    self.glosses.deinit(allocator);
    self.references.deinit(allocator);
}

/// Output the bytes representing the form. No terminator at
/// end of record.
pub fn writeBinary(self: *const Form, allocator: Allocator, data: *std.ArrayListUnmanaged(u8)) error{OutOfMemory}!void {
    try append_u24(allocator, data, self.uid);
    try append_u32(allocator, data, @bitCast(self.parsing));

    var flags: u8 = 0;
    if (self.preferred) flags |= 0x1;
    if (self.incorrect) flags |= 0x10;

    try append_u8(allocator, data, flags);
    try data.appendSlice(allocator, self.word);
    try data.append(allocator, US);
    try append_u16(allocator, data, @intCast(self.glosses.items.len));
    for (self.glosses.items) |gloss| {
        try data.append(allocator, @intFromEnum(gloss.lang));
        for (gloss.entries.items) |item| {
            try data.appendSlice(allocator, item);
            try data.append(allocator, US);
        }
        try data.append(allocator, RS);
    }
    // References into linked modules
    try append_u32(allocator, data, @intCast(self.references.items.len));
    for (self.references.items) |reference| {
        try append_u16(allocator, data, @intFromEnum(reference.module));
        try append_u16(allocator, data, @intFromEnum(reference.book));
        try append_u16(allocator, data, reference.chapter);
        try append_u16(allocator, data, reference.verse);
        try append_u16(allocator, data, reference.word);
    }
    //try data.append(0xff);
}

pub fn glosses_by_lang(self: *const Form, lang: Lang) ?*Gloss {
    for (self.glosses.items) |gloss| {
        if (gloss.*.lang == lang) {
            return gloss;
        }
    }
    if (self.lexeme) |l| {
        for (l.glosses.items) |gloss| {
            if (gloss.*.lang == lang) {
                return gloss;
            }
        }
    }
    return null;
}

/// Sort on the `word` field in ascii alphabetical. Fall back
/// to sort by `preferred` value and `glosses` count.
pub fn lessThan(_: void, self: *const Form, other: *const Form) bool {
    const x = @import("sort.zig").order(self.word, other.word);
    if (x == .lt) {
        return true;
    } else if (x == .gt) {
        return false;
    }

    if (!self.preferred and other.preferred) {
        return false;
    }
    if (self.preferred and !other.preferred) {
        return true;
    }

    // Fallback to compare another field
    return self.glosses.items.len > other.glosses.items.len;
}

/// Autocompletion works by preferring shorter words over
/// longer words, and subsorting by popularity of the word.
/// Provide a `key` if you wish two identical form text strings
/// to fall back to preferring a parent lexeme text string `key`.
pub fn autocompleteLessThan(key: ?[]const u8, self: *const Form, other: *const Form) bool {
    if (self.word.len < other.word.len) return true;
    if (self.word.len > other.word.len) return false;

    // If both forms have the same text value, prefer the parent lexeme text
    // value if it matches.
    const o = @import("sort.zig").order(self.word, other.word);
    if (key) |k| {
        if (o == .eq) {
            var l: ?[]const u8 = null;
            var r: ?[]const u8 = null;
            if (self.lexeme) |i| l = i.word;
            if (other.lexeme) |i| r = i.word;
            if (l != null and r == null) return true;
            if (l == null and r != null) return false;
            if (l != null and r != null) {
                const le = std.mem.eql(u8, k, l.?);
                const re = std.mem.eql(u8, k, r.?);
                if (le and !re) return true;
                if (!le and re) return false;
            }
        }
    }

    if (self.references.items.len + other.references.items.len > 0)
        return self.references.items.len > other.references.items.len;

    if (self.glosses.items.len + other.glosses.items.len > 0)
        return self.glosses.items.len > other.glosses.items.len;

    if (!self.preferred and other.preferred) return false;
    if (self.preferred and !other.preferred) return true;
    if (o != .eq) return o == .lt;

    // If forms are basically the same, use the uid to provide
    // a stable sort order response.
    return self.uid < other.uid;
}

pub fn read_string(t: *Parser, out: *std.ArrayList(u8)) !void {
    const value = try read_field(t);
    try out.appendSlice(value);
}

/// Read a slice of a bytes contining a utf8 string without memory allocations
pub fn read_field(t: *Parser) ![]const u8 {
    const start = t.index;
    while (true) {
        const c = t.peek();
        if (c == '\n' or c == '\t' or c == '|' or c == 0) {
            const field = t.data[start..t.index];
            return field;
        }
        _ = t.next();
    }
}

pub fn read_bool(t: *Parser) error{InvalidBooleanField}!bool {
    const field = try read_field(t);
    if (std.ascii.eqlIgnoreCase(field, "true") or std.ascii.eqlIgnoreCase(field, "yes")) {
        return true;
    }
    if (std.ascii.eqlIgnoreCase(field, "false") or std.ascii.eqlIgnoreCase(field, "no")) {
        return false;
    }
    return error.InvalidBooleanField;
}

pub fn read_parsing(t: *Parser) !Parsing {
    const field = try read_field(t);
    if (field.len == 0) {
        return Parsing{ .part_of_speech = .unknown };
    }
    return parse(field);
}

pub fn read_u32(t: *Parser) error{InvalidU24}!u32 {
    const field = try read_field(t);
    const value = std.fmt.parseInt(u32, field, 10) catch {
        return error.InvalidU32;
    };
    return value;
}

pub fn read_u24(t: *Parser) error{InvalidU24}!u24 {
    const field = try read_field(t);
    const value = std.fmt.parseInt(u24, field, 10) catch {
        return error.InvalidU24;
    };
    return value;
}

/// Read all fields for a form. No final terminmating RS is consumed.
/// Output fields:
///
///  - uid (3)
///  - parsing (4)
///  - flags (1)
///  - word (len + US)
///  - gloss count (2)
///  - lang (1), entry* (len + US)
///  - gloss end RS (1)
///  - reference count (4)
///  - module, book, chapter, verse, word (2,2,2,2,2)
pub fn readBinary(self: *Form, arena: Allocator, t: *BinaryReader) !void {
    self.uid = try t.u24();
    self.parsing = @bitCast(try t.u32());
    const flags = try t.u8();
    self.preferred = flags & 0x1 == 0x1;
    self.incorrect = flags & 0x10 == 0x10;
    const word = t.string() catch return error.InvalidDictionaryFile;
    if (word.len > 0) {
        self.word = try arena.dupe(u8, word);
    } else {
        self.word = "";
    }
    try readBinaryGlosses(arena, t, &self.glosses);
    const references_count = try t.u32();
    for (0..references_count) |_| {
        const module = try t.u16();
        const book = try t.u16();
        const chapter = try t.u16();
        const verse = try t.u16();
        const word_no = try t.u16();
        try self.references.append(arena, Reference{
            .module = try Module.from_u16(@intCast(module)),
            .book = try Book.from_u16(book),
            .chapter = chapter,
            .verse = verse,
            .word = word_no,
        });
    }
}

pub fn writeText(self: *Form, writer: anytype) error{ OutOfMemory, Incomplete }!void {
    try writer.writeAll(self.word);
    try writer.writeByte('|');
    try self.parsing.string(writer);
    try writer.writeByte('|');
    if (self.preferred) {
        try writer.writeAll("true");
    } else {
        try writer.writeAll("false");
    }
    try writer.writeByte('|');
    try writer.print("{d}", .{self.uid});
    try writer.writeByte('|');
    try writeTextGlosses(writer, &self.glosses);
    try writer.writeByte('|');
}

/// Read a single text line that contains a human readable description of a word form.
///
/// Examples of this format:
///
/// `Ἀαρών|N-NSM|false|17||`
/// `δράκοντα|N-ASM|false|37628||byz#Revelation 20:2 3,kjtr#Revelation 20:2 3`
pub fn readText(self: *Form, arena: Allocator, t: *Parser) !void {
    _ = t.skip_whitespace_and_lines();
    //const start = t.index;
    const word_field = try read_field(t);
    if (word_field.len == 0) {
        self.word = "";
    } else {
        self.word = try arena.dupe(u8, word_field);
    }
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    self.parsing = try read_parsing(t); // parsing
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    self.preferred = try read_bool(t);
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    self.uid = try read_u24(t); // uid
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    _ = try readTextGlosses(arena, t, &self.glosses); // Glosses
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    try Reference.readReferenceList(arena, t, &self.references); // References
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const Parser = @import("parser.zig");
const Lexeme = @import("lexeme.zig");
const Gloss = @import("gloss.zig");
const Lang = @import("lang.zig").Lang;
const Gender = @import("parsing.zig").Gender;
const ParsingError = @import("parsing.zig").Error;
const parse = @import("parsing.zig").parse;
const Parsing = @import("parsing.zig").Parsing;
const Reference = @import("reference.zig");
const BinaryReader = @import("binary_reader.zig");
const Book = @import("book.zig").Book;
const Module = @import("module.zig").Module;
const is_eol = @import("parser.zig").is_eol;
const is_whitespace = @import("parser.zig").is_whitespace;
const is_whitespace_or_eol = @import("parser.zig").is_whitespace_or_eol;
const readTextGlosses = @import("gloss.zig").readTextGlosses;
const writeTextGlosses = @import("gloss.zig").writeTextGlosses;
const readBinaryGlosses = @import("gloss.zig").readBinaryGlosses;

const BinaryWriter = @import("binary_writer.zig");
const append_u8 = BinaryWriter.append_u8;
const append_u16 = BinaryWriter.append_u16;
const append_u24 = BinaryWriter.append_u24;
const append_u32 = BinaryWriter.append_u32;
const RS = BinaryWriter.RS;
const US = BinaryWriter.US;

const eql = @import("std").mem.eql;
const expect = std.testing.expect;
const expectEqualDeep = std.testing.expectEqualDeep;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqualSlices = std.testing.expectEqualSlices;

test "read_form" {
    var data = Parser.init("ἄρτος|N-NSM|false|20||\nποῦ|N-NSM|true|21|en:fish|byz#Revelation 20:2 3,kjtr#Revelation 20:2 3\n");
    var form = try Form.create(std.testing.allocator);
    defer form.destroy(std.testing.allocator);
    try form.readText(std.testing.allocator, &data);
    try expectEqualStrings("ἄρτος", form.word);
    try expectEqual(20, form.uid);
    try expectEqual(false, form.preferred);
    try expectEqual(0, form.glosses.items.len);
    try expect(data.consume_if('\n'));

    var form2 = try Form.create(std.testing.allocator);
    defer form2.destroy(std.testing.allocator);
    try form2.readText(std.testing.allocator, &data);
    try expectEqualStrings("ποῦ", form2.word);
    try expectEqual(21, form2.uid);
    try expectEqual(true, form2.preferred);
    try expect(data.consume_if('\n'));
    try expectEqual(1, form2.glosses.items.len);
}

pub const std_options = struct {
    pub const log_level: std.log.Level = .debug;
};

test "form_init" {
    var form = try Form.create(std.testing.allocator);
    defer form.destroy(std.testing.allocator);
    try expectEqual(0, form.word.len);
    try expectEqual(false, form.preferred);
    try expectEqual(false, form.incorrect);
    try expectEqual(0, form.glosses.items.len);
    try expectEqual(0, form.references.items.len);
}

test "form_read_write_text" {
    const allocator = std.testing.allocator;
    const in = "fish|N-NSM|true|20|en:swim:to arch#zh:你好|sbl#Mark 11:22 33,sr#Luke 1:2 3\n";
    var t = Parser.init(in);
    var form = try Form.create(allocator);
    defer form.destroy(allocator);
    try form.readText(allocator, &t);

    var out: std.ArrayListUnmanaged(u8) = .empty;
    defer out.deinit(allocator);
    try form.writeText(out.writer(allocator));
    const text = "fish|N-NSM|true|20|en:swim:to arch#zh:你好|";
    try expectEqualStrings(text, out.items);
}

test "form_read_write_bytes" {
    var t = Parser.init("fish|N-NSM|true|20|en:swim:to arch#zh:你好|sbl#Mark 11:22 33,sr#Luke 1:2 3\n");
    var form = try Form.create(std.testing.allocator);
    defer form.destroy(std.testing.allocator);
    try form.readText(std.testing.allocator, &t);

    var out: std.ArrayListUnmanaged(u8) = .empty;
    defer out.deinit(std.testing.allocator);
    try form.writeBinary(std.testing.allocator, &out);

    try expectEqual(2, form.glosses.items.len);
    try expectEqual(2, form.references.items.len);

    try expectEqualSlices(
        u8,
        &.{
            20, 0, 0, 3, 16, 132, 0, 1, 'f', 'i', 's', 'h', 31, 2, 0, 4, 's',
        },
        out.items[0..17],
    );
    try expectEqual(63, out.items.len);

    var form_loaded = try Form.create(std.testing.allocator);
    defer form_loaded.destroy(std.testing.allocator);
    var p = BinaryReader.init(out.items);
    try form_loaded.readBinary(std.testing.allocator, &p);

    try expectEqual(20, form_loaded.uid);
    try expectEqualStrings("fish", form_loaded.word);
    try expectEqual(2, form_loaded.references.items.len);
}

test "form_read_write_two_items" {
    const allocator = std.testing.allocator;

    var t = Parser.init(
        \\fish|N-NSM|true|20|en:swim|
        \\cars|N-NSM|true|21|en:to arch|sr#Luke 1:2 3,byz#Mark 11:22 33
    );
    var form1 = try Form.create(allocator);
    defer form1.destroy(allocator);
    var form2 = try Form.create(allocator);
    defer form2.destroy(allocator);
    try form1.readText(allocator, &t);
    try form2.readText(allocator, &t);

    var out: std.ArrayListUnmanaged(u8) = .empty;
    defer out.deinit(allocator);
    try form1.writeBinary(allocator, &out);
    try form2.writeBinary(allocator, &out);

    //try expectEqualSlices(u8, &.{0}, out.items);
    var form3 = try Form.create(allocator);
    defer form3.destroy(allocator);
    var form4 = try Form.create(allocator);
    defer form4.destroy(allocator);
    var data = BinaryReader.init(out.items);
    try form3.readBinary(allocator, &data);
    try form4.readBinary(allocator, &data);
    try expectEqual(20, form3.uid);
    try expectEqual(21, form4.uid);
    try expectEqual(2, form4.references.items.len);
    //try expectEqualSlices(u8, &.{0}, out.items);
}

fn make_test_form(
    gpa: Allocator,
    form: []const u8,
    lexeme: []const u8,
) error{OutOfMemory}!*Form {
    const f1 = try Form.create(gpa);
    f1.word = try gpa.dupe(u8, form);
    f1.lexeme = try Lexeme.create(gpa);
    f1.lexeme.?.word = try gpa.dupe(u8, lexeme);
    return f1;
}

test "form_autocomplete" {
    const gpa = std.testing.allocator;

    const f1 = try make_test_form(gpa, "hal", "hal");
    defer f1.destroy(gpa);
    defer f1.lexeme.?.destroy(gpa);

    const f2 = try make_test_form(gpa, "ant", "ant");
    defer f2.destroy(gpa);
    defer f2.lexeme.?.destroy(gpa);

    var items = [_]*Form{ f1, f2 };

    {
        // Normal autocomplete order
        try expect(!autocompleteLessThan(null, f1, f2));
        try expect(autocompleteLessThan(null, f2, f1));

        std.mem.sort(*Form, &items, @as(?[]const u8, null), autocompleteLessThan);
        try expectEqualStrings("ant", items[0].word);
        try expectEqualStrings("hal", items[1].word);
    }

    {
        // Prefer ant in the lexeme
        try expect(!autocompleteLessThan("ant", f1, f2));
        try expect(autocompleteLessThan("ant", f2, f1));

        std.mem.sort(*Form, &items, @as(?[]const u8, "ant"), autocompleteLessThan);
        try expectEqualStrings("ant", items[0].word);
        try expectEqualStrings("hal", items[1].word);
    }

    const g1 = try make_test_form(gpa, "car", "car");
    defer g1.lexeme.?.destroy(gpa);
    defer g1.destroy(gpa);

    const g2 = try make_test_form(gpa, "car", "ant");
    defer g2.lexeme.?.destroy(gpa);
    defer g2.destroy(gpa);

    var items1 = [_]*Form{ g1, g2 };
    var items2 = [_]*Form{ g1, g2 };

    {
        // Hal gets prioritised first as a lexical form
        //try expect(autocompleteLessThan("hal", f1, f2));
        //try expect(!autocompleteLessThan("hal", f2, f1));

        std.mem.sort(*Form, &items1, @as(?[]const u8, "car"), autocompleteLessThan);
        try expectEqualStrings("car", items1[0].lexeme.?.word);
        try expectEqualStrings("ant", items1[1].lexeme.?.word);

        std.mem.sort(*Form, &items2, @as(?[]const u8, "ant"), autocompleteLessThan);
        try expectEqualStrings("ant", items2[0].lexeme.?.word);
        try expectEqualStrings("car", items2[1].lexeme.?.word);
    }
}

test "compare_form" {
    const allocator = std.testing.allocator;

    {
        var data = Parser.init(
            \\ἄρτ|N-NSM|false|20|en:fish|
            \\ἄρτο|N-NSM|false|21|en:fish|
            \\ἄρτος|N-NSM|false|22|en:fish|
        );
        var form1 = try Form.create(allocator);
        defer form1.destroy(allocator);
        try form1.readText(allocator, &data);
        var form2 = try Form.create(allocator);
        defer form2.destroy(allocator);
        try form2.readText(allocator, &data);
        var form3 = try Form.create(allocator);
        defer form3.destroy(allocator);
        try form3.readText(allocator, &data);
        try expectEqual(true, lessThan({}, form1, form2));
        try expectEqual(true, lessThan({}, form1, form3));
        try expectEqual(false, lessThan({}, form3, form2));
        try expectEqual(false, lessThan({}, form3, form1));
    }
    {
        var data = Parser.init(
            \\ἄρτος|N-NSM|false|20|en:fish|
            \\ἄρτος|N-NSM|false|21|en:fish#zh:fish|
            \\ἄρτος|N-NSM|false|22|en:fish#zh:fishing#es:fishes|
        );
        var form1 = try Form.create(allocator);
        defer form1.destroy(allocator);
        try form1.readText(allocator, &data);
        var form2 = try Form.create(allocator);
        defer form2.destroy(allocator);
        try form2.readText(allocator, &data);
        var form3 = try Form.create(allocator);
        defer form3.destroy(allocator);
        try form3.readText(allocator, &data);
    }
    {
        var data = Parser.init(
            \\ἄρτος|N-NSM|false|20|en:fish|
            \\ἄρτος|N-NSM|true|21|en:fish#zh:fish|
            \\ἄρτος|N-NSM|false|22|en:fish#zh:fishing#es:fishes|
        );
        var form1 = try Form.create(allocator);
        defer form1.destroy(allocator);
        try form1.readText(allocator, &data);
        var form2 = try Form.create(allocator);
        defer form2.destroy(allocator);
        try form2.readText(allocator, &data);
        var form3 = try Form.create(allocator);
        defer form3.destroy(allocator);
        try form3.readText(allocator, &data);

        try expectEqual(false, form1.preferred);
        try expectEqual(true, form2.preferred);
        try expectEqual(false, form3.preferred);

        try expectEqual(false, lessThan({}, form1, form2));
        try expectEqual(true, lessThan({}, form2, form1));
        try expectEqual(false, lessThan({}, form1, form3));
        try expectEqual(false, lessThan({}, form3, form2));
        try expectEqual(true, lessThan({}, form3, form1));
    }
}

test "read_invalid_form_parsing" {
    var data = Parser.init("ἄρτος|N-NZ|false|29||\nποῦ|N-NSM|true|21||\n");
    var form = try Form.create(std.testing.allocator);
    defer form.destroy(std.testing.allocator);
    const e = form.readText(std.testing.allocator, &data);
    try expectEqual(ParsingError.InvalidParsing, e);
}

test "read_incomplete_form_parsing" {
    var data = Parser.init("ἄρτος|N-NA|false|20||\nποῦ|N-NSM|true|21||\n");
    var form = try Form.create(std.testing.allocator);
    defer form.destroy(std.testing.allocator);
    const e = form.readText(std.testing.allocator, &data);
    try expectEqual(ParsingError.InvalidParsing, e);
}
