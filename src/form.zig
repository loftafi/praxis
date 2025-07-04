/// A form is a string of letters that form an individual word as
/// it would be written or spoken in real life such as "jump,"
/// "jumping" or "jumps". Related form of a word are collected into
/// a `Lexeme` object.
uid: u24 = 0,
word: []const u8,
parsing: Parsing = .{},
preferred: bool = false,
incorrect: bool = false,
references: std.ArrayList(Reference) = undefined,
glosses: std.ArrayList(*Gloss) = undefined,
lexeme: ?*Lexeme = null,

const Self = @This();

pub fn create(allocator: std.mem.Allocator) !*Self {
    var s = try allocator.create(Self);
    errdefer allocator.destroy(Self);
    try s.init(allocator);
    return s;
}

pub fn destroy(self: *Self) void {
    const current_allocator = self.glosses.allocator;
    self.deinit();
    current_allocator.destroy(self);
}

pub fn init(self: *Self, allocator: std.mem.Allocator) !void {
    self.uid = 0;
    self.word = "";
    self.parsing = .{};
    self.lexeme = null;
    self.preferred = false;
    self.incorrect = false;
    self.glosses = std.ArrayList(*Gloss).init(allocator);
    self.references = std.ArrayList(Reference).init(allocator);
}

pub fn deinit(self: *Self) void {
    if (self.word.len > 0) {
        self.glosses.allocator.free(self.word);
    }
    for (self.glosses.items) |gloss| {
        gloss.destroy();
    }
    self.glosses.deinit();
    self.references.deinit();
}

/// Output the bytes representing the form. No terminator at
/// end of record.
pub fn write_binary(self: *Self, data: *std.ArrayList(u8)) !void {
    try append_u24(data, self.uid);
    try append_u32(data, @bitCast(self.parsing));
    var flags: u8 = 0;
    if (self.preferred) {
        flags |= 0x1;
    }
    if (self.incorrect) {
        flags |= 0x10;
    }
    try append_u8(data, flags);
    try data.appendSlice(self.word);
    try data.append(US);
    try append_u16(data, @intCast(self.glosses.items.len));
    for (self.glosses.items) |gloss| {
        try data.append(@intFromEnum(gloss.lang));
        for (gloss.entries.items) |item| {
            try data.appendSlice(item);
            try data.append(US);
        }
        try data.append(RS);
    }
    // References into linked modules
    try append_u32(data, @intCast(self.references.items.len));
    for (self.references.items) |reference| {
        try append_u16(data, @intFromEnum(reference.module));
        try append_u16(data, @intFromEnum(reference.book));
        try append_u16(data, reference.chapter);
        try append_u16(data, reference.verse);
        try append_u16(data, reference.word);
    }
    //try data.append(0xff);
}

pub fn glosses_by_lang(self: *const Self, lang: Lang) ?*Gloss {
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
pub fn lessThan(_: void, self: *Self, other: *Self) bool {
    const x = std.mem.order(u8, self.word, other.word);
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
pub fn autocompleteLessThan(_: void, self: *Self, other: *Self) bool {
    if (self.references.items.len + other.references.items.len > 0) {
        return self.references.items.len > other.references.items.len;
    }

    if (self.glosses.items.len + other.glosses.items.len > 0) {
        return self.glosses.items.len > other.glosses.items.len;
    }

    if (self.word.len < other.word.len) {
        return true;
    }
    if (self.word.len > other.word.len) {
        return false;
    }

    if (!self.preferred and other.preferred) {
        return false;
    }
    if (self.preferred and !other.preferred) {
        return true;
    }

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
pub fn read_binary(self: *Self, t: *BinaryReader) !void {
    self.uid = try t.u24();
    self.parsing = @bitCast(try t.u32());
    const flags = try t.u8();
    self.preferred = flags & 0x1 == 0x1;
    self.incorrect = flags & 0x10 == 0x10;
    const word = t.string() catch return error.InvalidDictionaryFile;
    if (word.len > 0) {
        self.word = try self.references.allocator.dupe(u8, word);
    } else {
        self.word = "";
    }
    try read_binary_glosses(t, &self.glosses);
    const references_count = try t.u32();
    for (0..references_count) |_| {
        const module = try t.u16();
        const book = try t.u16();
        const chapter = try t.u16();
        const verse = try t.u16();
        const word_no = try t.u16();
        try self.references.append(Reference{
            .module = try Module.from_u16(@intCast(module)),
            .book = try Book.from_u16(book),
            .chapter = chapter,
            .verse = verse,
            .word = word_no,
        });
    }
}

/// Read a single text line that contains a human readable description of a word form.
///
/// Examples of this format:
///
/// `Ἀαρών|N-NSM|false|17||`
/// `δράκοντα|N-ASM|false|37628||byz#Revelation 20:2 3,kjtr#Revelation 20:2 3`
pub fn read_text(self: *Self, t: *Parser) !void {
    _ = t.skip_whitespace_and_lines();
    //const start = t.index;
    const word_field = try read_field(t);
    if (word_field.len == 0) {
        self.word = "";
    } else {
        self.word = try self.glosses.allocator.dupe(u8, word_field);
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
    _ = try read_text_glosses(t, &self.glosses); // Glosses
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    try Reference.read_reference_list(t, &self.references); // References
}

const std = @import("std");
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
const read_text_glosses = @import("gloss.zig").read_text_glosses;
const read_binary_glosses = @import("gloss.zig").read_binary_glosses;

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
    var form = try Self.create(std.testing.allocator);
    defer form.destroy();
    try form.read_text(&data);
    try expectEqualStrings("ἄρτος", form.word);
    try expectEqual(20, form.uid);
    try expectEqual(false, form.preferred);
    try expectEqual(0, form.glosses.items.len);
    try expect(data.consume_if('\n'));

    var form2 = try Self.create(std.testing.allocator);
    defer form2.destroy();
    try form2.read_text(&data);
    try expectEqualStrings("ποῦ", form2.word);
    try expectEqual(21, form2.uid);
    try expectEqual(true, form2.preferred);
    try expect(data.consume_if('\n'));
    try expectEqual(1, form2.glosses.items.len);
}

pub const std_options = struct {
    pub const log_level: std.log.Level = .debug;
};

test "form_read_write_bytes" {
    var t = Parser.init("fish|N-NSM|true|20|en:swim:to arch#zh:你好|sbl#Mark 11:22 33,sr#Luke 1:2 3\n");
    var form = try Self.create(std.testing.allocator);
    defer form.destroy();
    try form.read_text(&t);

    var out = std.ArrayList(u8).init(std.testing.allocator);
    defer out.deinit();
    try form.write_binary(&out);

    try expectEqual(2, form.glosses.items.len);
    try expectEqual(2, form.references.items.len);

    try expectEqualSlices(
        u8,
        &.{
            20,
            0,
            0,
            3,
            16,
            132,
            0,
            1,
            'f',
            'i',
            's',
            'h',
            31,
            2,
            0,
            4,
            's',
        },
        out.items[0..17],
    );
    try expectEqual(63, out.items.len);

    var form_loaded = try Self.create(std.testing.allocator);
    defer form_loaded.destroy();
    var p = BinaryReader.init(out.items);
    try form_loaded.read_binary(&p);

    try expectEqual(20, form_loaded.uid);
    try expectEqualStrings("fish", form_loaded.word);
    try expectEqual(2, form_loaded.references.items.len);
}

test "form_read_write_two_items" {
    var t = Parser.init(
        \\fish|N-NSM|true|20|en:swim|
        \\cars|N-NSM|true|21|en:to arch|sr#Luke 1:2 3,byz#Mark 11:22 33
    );
    var form1 = try Self.create(std.testing.allocator);
    defer form1.destroy();
    var form2 = try Self.create(std.testing.allocator);
    defer form2.destroy();
    try form1.read_text(&t);
    try form2.read_text(&t);

    var out = std.ArrayList(u8).init(std.testing.allocator);
    defer out.deinit();
    try form1.write_binary(&out);
    try form2.write_binary(&out);

    //try expectEqualSlices(u8, &.{0}, out.items);
    var form3 = try Self.create(std.testing.allocator);
    defer form3.destroy();
    var form4 = try Self.create(std.testing.allocator);
    defer form4.destroy();
    var data = BinaryReader.init(out.items);
    try form3.read_binary(&data);
    try form4.read_binary(&data);
    try expectEqual(20, form3.uid);
    try expectEqual(21, form4.uid);
    try expectEqual(2, form4.references.items.len);
    //try expectEqualSlices(u8, &.{0}, out.items);
}

test "compare_form" {
    {
        var data = Parser.init(
            \\ἄρτ|N-NSM|false|20|en:fish|
            \\ἄρτο|N-NSM|false|21|en:fish|
            \\ἄρτος|N-NSM|false|22|en:fish|
        );
        var form1 = try Self.create(std.testing.allocator);
        defer form1.destroy();
        try form1.read_text(&data);
        var form2 = try Self.create(std.testing.allocator);
        defer form2.destroy();
        try form2.read_text(&data);
        var form3 = try Self.create(std.testing.allocator);
        defer form3.destroy();
        try form3.read_text(&data);
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
        var form1 = try Self.create(std.testing.allocator);
        defer form1.destroy();
        try form1.read_text(&data);
        var form2 = try Self.create(std.testing.allocator);
        defer form2.destroy();
        try form2.read_text(&data);
        var form3 = try Self.create(std.testing.allocator);
        defer form3.destroy();
        try form3.read_text(&data);
    }
    {
        var data = Parser.init(
            \\ἄρτος|N-NSM|false|20|en:fish|
            \\ἄρτος|N-NSM|true|21|en:fish#zh:fish|
            \\ἄρτος|N-NSM|false|22|en:fish#zh:fishing#es:fishes|
        );
        var form1 = try Self.create(std.testing.allocator);
        defer form1.destroy();
        try form1.read_text(&data);
        var form2 = try Self.create(std.testing.allocator);
        defer form2.destroy();
        try form2.read_text(&data);
        var form3 = try Self.create(std.testing.allocator);
        defer form3.destroy();
        try form3.read_text(&data);

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
    var form = try Self.create(std.testing.allocator);
    defer form.destroy();
    const e = form.read_text(&data);
    try expectEqual(ParsingError.InvalidParsing, e);
}

test "read_incomplete_form_parsing" {
    var data = Parser.init("ἄρτος|N-NA|false|20||\nποῦ|N-NSM|true|21||\n");
    var form = try Self.create(std.testing.allocator);
    defer form.destroy();
    const e = form.read_text(&data);
    try expectEqual(ParsingError.InvalidParsing, e);
}
