/// A form is a string of letters that form an individual word as
/// it would be written or spoken in real life such as "jump,"
/// "jumping" or "jumps". Related form of a word are collected into
/// a `Lexeme` object.
const Form = @This();

uid: u24 = 0,
word: []const u8,
parsing: Parsing = .{},
preferred: bool = false,
incorrect: bool = false,
references: std.ArrayListUnmanaged(Reference) = .empty,
glosses: std.ArrayListUnmanaged(*Gloss) = .empty,
lexeme: ?*Lexeme = null,

/// Describes an empty `Form` record.
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

/// Deinitialise any memory associated with this `Form`.
pub fn deinit(self: *Form, allocator: Allocator) void {
    if (self.word.len > 0)
        allocator.free(self.word);

    for (self.glosses.items) |gloss|
        gloss.destroy(allocator);

    self.glosses.deinit(allocator);
    self.references.deinit(allocator);
    self.* = undefined;
}

/// Output the bytes representing the form. No terminator at
/// end of record.
pub fn writeBinary(
    self: *const Form,
    data: *std.Io.Writer,
) std.Io.Writer.Error!void {
    try append_u24(data, self.uid);
    try append_u32(data, @bitCast(self.parsing));

    var flags: u8 = 0;
    if (self.preferred) flags |= 0x1;
    if (self.incorrect) flags |= 0x10;

    try append_u8(data, flags);
    try data.writeAll(self.word);
    try data.writeByte(US);
    try append_u16(data, @intCast(self.glosses.items.len));
    for (self.glosses.items) |gloss| {
        try data.writeByte(@intFromEnum(gloss.lang));
        for (gloss.entries.items) |item| {
            try data.writeAll(item);
            try data.writeByte(US);
        }
        try data.writeByte(RS);
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
}

/// Return the gloss set for a particular language. Returns null if
/// no gloss set exists for the requested `lang`.
pub fn glosses_by_lang(self: *const Form, lang: Lang) ?*Gloss {
    for (self.glosses.items) |gloss| {
        if (gloss.*.lang == lang) return gloss;
    }
    if (self.lexeme) |l| {
        for (l.glosses.items) |gloss| {
            if (gloss.*.lang == lang) return gloss;
        }
    }
    return null;
}

/// Sort on the `word` field in ascii alphabetical. Fall back
/// to sort by `preferred` value and `glosses` count.
pub fn lessThan(_: void, self: *const Form, other: *const Form) bool {
    const x = @import("sort.zig").order(self.word, other.word);
    if (x == .lt)
        return true
    else if (x == .gt)
        return false;

    if (!self.preferred and other.preferred) return false;
    if (self.preferred and !other.preferred) return true;

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

pub fn read_byz_parsing(t: *Parser) !Parsing {
    const field = t.readField();
    if (field.len == 0) {
        return Parsing{ .part_of_speech = .unknown };
    }
    return Byzantine.parse(field);
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
pub fn initBinary(self: *Form, arena: Allocator, t: *BinaryReader) !void {
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
    self.glosses = .empty;
    self.references = .empty;
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

pub fn writeText(
    self: *Form,
    writer: *std.Io.Writer,
) (std.Io.Writer.Error || error{Incomplete})!void {
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
pub fn initText(self: *Form, allocator: Allocator, t: *Parser) error{
    MissingField,
    Incomplete,
    UnknownPartOfSpeech,
    UnknownCase,
    UnknownNumber,
    UnknownGender,
    UnknownPerson,
    UnknownTenseForm,
    UnknownVoice,
    UnknownMood,
    UnrecognisedValue,
    InvalidParsing,
    InvalidBooleanField,
    InvalidU16,
    InvalidU24,
    InvalidReference,
    OutOfMemory,
}!void {
    self.* = .empty;

    _ = t.skip_whitespace_and_lines();
    //const start = t.index;
    const word_field = t.readField();
    if (word_field.len == 0)
        self.word = ""
    else
        self.word = try allocator.dupe(u8, word_field);
    errdefer if (self.word.len > 0) allocator.free(self.word);

    if (!t.consume_if('|')) return error.MissingField;

    self.parsing = try read_byz_parsing(t); // parsing
    if (!t.consume_if('|')) return error.MissingField;

    self.preferred = try t.readBool();
    if (!t.consume_if('|')) return error.MissingField;

    self.uid = try t.readU24(); // uid
    if (!t.consume_if('|')) return error.MissingField;

    _ = try readTextGlosses(allocator, t, &self.glosses); // Glosses
    if (!t.consume_if('|')) return error.MissingField;

    try Reference.readReferenceList(allocator, t, &self.references); // References
}

test "read_text_form" {
    const gpa = std.testing.allocator;
    var tp = try make_test_pool(gpa);

    {
        var data = Parser.init("ἄρτος|N-NSM|false|20||\nποῦ|N-NSM|true|21|en:fish|byz#Revelation 20:2 3,kjtr#Revelation 20:2 3\n");

        var form = try tp.form_pool.alloc();
        defer tp.form_pool.free(form);
        try form.initText(std.testing.allocator, &data);
        defer form.deinit(gpa);

        try expectEqualStrings("ἄρτος", form.word);
        try expectEqual(20, form.uid);
        try expectEqual(false, form.preferred);
        try expectEqual(0, form.glosses.items.len);
        try expect(data.consume_if('\n'));

        var form2 = try tp.form_pool.alloc();
        defer tp.form_pool.free(form2);
        try form2.initText(gpa, &data);
        defer form2.deinit(gpa);

        try expectEqualStrings("ποῦ", form2.word);
        try expectEqual(21, form2.uid);
        try expectEqual(true, form2.preferred);
        try expect(data.consume_if('\n'));
        try expectEqual(1, form2.glosses.items.len);
    }

    try tp.deinit(.leak_check);
}

pub const std_options = struct {
    pub const log_level: std.log.Level = .debug;
};

test "read_write_text" {
    const gpa = std.testing.allocator;
    var tp = try make_test_pool(gpa);

    {
        const in = "fish|N-NSM|true|20|en:swim:to arch#zh:你好|sbl#Mark 11:22 33,sr#Luke 1:2 3\n";
        var t = Parser.init(in);
        var form = try tp.form_pool.alloc();
        defer tp.form_pool.free(form);
        try form.initText(gpa, &t);
        defer form.deinit(gpa);

        var out = std.Io.Writer.Allocating.init(gpa);
        defer out.deinit();
        try form.writeText(&out.writer);
        const text = "fish|N-NSM|true|20|en:swim:to arch#zh:你好|";
        try expectEqualStrings(text, out.written());
    }

    try tp.deinit(.leak_check);
}

test "read_write_bytes" {
    const gpa = std.testing.allocator;
    var tp = try make_test_pool(gpa);

    {
        var t = Parser.init("fish|N-NSM|true|7700|en:swim:to arch#zh:你好|sbl#Mark 11:22 33,sr#Luke 1:2 3\n");
        var form = try tp.form_pool.alloc();
        defer tp.form_pool.free(form);
        try form.initText(gpa, &t);
        defer form.deinit(gpa);

        var writer = std.Io.Writer.Allocating.init(gpa);
        defer writer.deinit();
        try form.writeBinary(&writer.writer);
        const out = writer.written();

        try expectEqual(2, form.glosses.items.len);
        try expectEqual(2, form.references.items.len);

        try expectEqualSlices(
            u8,
            &.{
                20, 30, 0, 3, 16, 132, 0, 1, 'f', 'i', 's', 'h', 31, 2, 0, 4, 's',
            },
            out[0..17],
        );
        try expectEqual(63, out.len);

        var form_loaded = try tp.form_pool.alloc();
        defer tp.form_pool.free(form_loaded);
        var p = BinaryReader.init(out);
        try form_loaded.initBinary(gpa, &p);
        defer form_loaded.deinit(gpa);

        try expectEqual(7700, form_loaded.uid);
        try expectEqualStrings("fish", form_loaded.word);
        try expectEqual(2, form_loaded.references.items.len);
    }
    try tp.deinit(.leak_check);
}

test "form_read_write_two_items" {
    const gpa = std.testing.allocator;
    var tp = try make_test_pool(gpa);

    var out = std.Io.Writer.Allocating.init(gpa);
    defer out.deinit();
    {
        var t = Parser.init(
            \\fish|N-NSM|true|79920|en:swim|
            \\cars|N-NSM|true|21|en:to arch|sr#Luke 1:2 3,byz#Mark 11:22 33
        );
        var form1 = try tp.form_pool.alloc();
        defer tp.form_pool.free(form1);
        try form1.initText(gpa, &t);
        defer form1.deinit(gpa);

        var form2 = try tp.form_pool.alloc();
        defer tp.form_pool.free(form2);
        try form2.initText(gpa, &t);
        defer form2.deinit(gpa);

        try form1.writeBinary(&out.writer);
        try form2.writeBinary(&out.writer);
    }

    {
        var data = BinaryReader.init(out.written());
        //try expectEqualSlices(u8, &.{0}, out.items);

        var form3 = try tp.form_pool.alloc();
        defer tp.form_pool.free(form3);
        try form3.initBinary(gpa, &data);
        defer form3.deinit(gpa);

        var form4 = try tp.form_pool.alloc();
        defer tp.form_pool.free(form4);
        try form4.initBinary(gpa, &data);
        defer form4.deinit(gpa);

        try expectEqual(79920, form3.uid);
        try expectEqual(21, form4.uid);
        try expectEqual(2, form4.references.items.len);
    }
    try tp.deinit(.leak_check);
}

test "init_release" {
    const gpa = std.testing.allocator;
    var tp = try make_test_pool(gpa);

    {
        const form1 = try tp.new_form("hal", "hal");
        defer {
            form1.lexeme.?.deinit(gpa);
            tp.lexeme_pool.free(form1.lexeme.?);
            form1.deinit(gpa);
            tp.form_pool.free(form1);
        }
    }

    {
        const form2 = try tp.new_form("car", "ant");
        defer tp.form_pool.free(form2);
        defer form2.deinit(gpa);
        defer tp.lexeme_pool.free(form2.lexeme.?);
        defer form2.lexeme.?.deinit(gpa);
    }

    try tp.deinit(.leak_check);
}

test "form_autocomplete" {
    const gpa = std.testing.allocator;
    var tp = try make_test_pool(gpa);

    {
        const f1 = try tp.new_form("hal", "hal");
        defer tp.form_pool.free(f1);
        defer f1.deinit(gpa);
        defer tp.lexeme_pool.free(f1.lexeme.?);
        defer f1.lexeme.?.deinit(gpa);

        const f2 = try tp.new_form("ant", "ant");
        defer tp.form_pool.free(f2);
        defer f2.deinit(gpa);
        defer tp.lexeme_pool.free(f2.lexeme.?);
        defer f2.lexeme.?.deinit(gpa);

        var items = [_]*Form{ f1, f2 };

        // Normal autocomplete order
        try expect(!autocompleteLessThan(null, f1, f2));
        try expect(autocompleteLessThan(null, f2, f1));
        std.mem.sort(*Form, &items, @as(?[]const u8, null), autocompleteLessThan);
        try expectEqualStrings("ant", items[0].word);
        try expectEqualStrings("hal", items[1].word);

        // Prefer ant in the lexeme
        try expect(!autocompleteLessThan("ant", f1, f2));
        try expect(autocompleteLessThan("ant", f2, f1));
        std.mem.sort(*Form, &items, @as(?[]const u8, "ant"), autocompleteLessThan);
        try expectEqualStrings("ant", items[0].word);
        try expectEqualStrings("hal", items[1].word);

        const g1 = try tp.new_form("car", "car");
        defer tp.form_pool.free(g1);
        defer g1.deinit(gpa);
        defer tp.lexeme_pool.free(g1.lexeme.?);
        defer g1.lexeme.?.deinit(gpa);

        const g2 = try tp.new_form("car", "ant");
        defer tp.form_pool.free(g2);
        defer g2.deinit(gpa);
        defer tp.lexeme_pool.free(g2.lexeme.?);
        defer g2.lexeme.?.deinit(gpa);

        var items1 = [_]*Form{ g1, g2 };
        var items2 = [_]*Form{ g1, g2 };

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
    try tp.deinit(.leak_check);
}

test "compare_form" {
    const gpa = std.testing.allocator;
    var tp = try make_test_pool(gpa);
    defer tp.deinit(.leak) catch {};

    {
        var data = Parser.init(
            \\ἄρτ|N-NSM|false|20|en:fish|
            \\ἄρτο|N-NSM|false|21|en:fish|
            \\ἄρτος|N-NSM|false|22|en:fish|
        );
        var form1 = try tp.form_pool.alloc();
        try form1.initText(gpa, &data);
        defer form1.deinit(gpa);

        var form2 = try tp.form_pool.alloc();
        try form2.initText(gpa, &data);
        defer form2.deinit(gpa);

        var form3 = try tp.form_pool.alloc();
        try form3.initText(gpa, &data);
        defer form3.deinit(gpa);

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
        var form1 = try tp.form_pool.alloc();
        try form1.initText(gpa, &data);
        defer form1.deinit(gpa);
        var form2 = try tp.form_pool.alloc();
        try form2.initText(gpa, &data);
        defer form2.deinit(gpa);
        var form3 = try tp.form_pool.alloc();
        try form3.initText(gpa, &data);
        defer form3.deinit(gpa);
    }
    {
        var data = Parser.init(
            \\ἄρτος|N-NSM|false|20|en:fish|
            \\ἄρτος|N-NSM|true|21|en:fish#zh:fish|
            \\ἄρτος|N-NSM|false|22|en:fish#zh:fishing#es:fishes|
        );
        var form1 = try tp.form_pool.alloc();
        try form1.initText(gpa, &data);
        defer form1.deinit(gpa);
        var form2 = try tp.form_pool.alloc();
        try form2.initText(gpa, &data);
        defer form2.deinit(gpa);
        var form3 = try tp.form_pool.alloc();
        try form3.initText(gpa, &data);
        defer form3.deinit(gpa);

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
    const gpa = std.testing.allocator;
    var tp = try make_test_pool(gpa);

    {
        var data = Parser.init("ἄρτος|N-NZ|false|29||\nποῦ|N-NSM|true|21||\n");
        var form = try tp.form_pool.alloc();
        defer tp.form_pool.free(form);
        const e = form.initText(gpa, &data);
        try expectEqual(ParsingError.InvalidParsing, e);
    }

    try tp.deinit(.leak_check);
}

test "read_incomplete_form_parsing" {
    const gpa = std.testing.allocator;
    var tp = try make_test_pool(gpa);

    {
        var data = Parser.init("ἄρτος|N-NA|false|20||\nποῦ|N-NSM|true|21||\n");
        var form = try tp.form_pool.alloc();
        defer tp.form_pool.free(form);
        const e = form.initText(gpa, &data);
        try expectEqual(ParsingError.InvalidParsing, e);
    }

    try tp.deinit(.leak_check);
}

fn make_test_pool(gpa: Allocator) !struct {
    allocator: Allocator,
    lexeme_pool: Pool(Lexeme, 20),
    form_pool: Pool(Form, 20),

    fn new_form(
        self: *@This(),
        form: []const u8,
        lexeme: []const u8,
    ) error{OutOfMemory}!*Form {
        var f = try self.form_pool.alloc();
        errdefer self.form_pool.free(f);
        f.* = .empty;
        f.word = try self.allocator.dupe(u8, form);

        f.lexeme = try self.lexeme_pool.alloc();
        errdefer self.lexeme_pool.free(f.lexeme.?);
        f.lexeme.?.* = .empty;
        f.lexeme.?.word = try self.allocator.dupe(u8, lexeme);

        return f;
    }

    fn deinit(self: *@This(), leak: enum { leak_check, leak }) !void {
        if (leak == .leak_check) try expectEqual(0, self.form_pool.count());
        if (leak == .leak_check) try expectEqual(0, self.lexeme_pool.count());
        self.form_pool.deinit();
        self.lexeme_pool.deinit();
    }
} {
    return .{
        .allocator = gpa,
        .form_pool = try .init(gpa),
        .lexeme_pool = try .init(gpa),
    };
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const Parser = @import("parser.zig");
const Lexeme = @import("Lexeme.zig");
const Gloss = @import("Gloss.zig");
const Lang = @import("lang.zig").Lang;
const ParsingError = @import("parsing.zig").Parsing.Error;
const Parsing = @import("parsing.zig").Parsing;
const Gender = Parsing.Gender;
const Reference = @import("Reference.zig");
const BinaryReader = @import("binary_reader.zig");
const Book = @import("book.zig").Book;
const Module = @import("module.zig").Module;
const is_eol = @import("parser.zig").is_eol;
const is_whitespace = @import("parser.zig").is_whitespace;
const is_whitespace_or_eol = @import("parser.zig").is_whitespace_or_eol;
const readTextGlosses = Gloss.readTextGlosses;
const writeTextGlosses = Gloss.writeTextGlosses;
const readBinaryGlosses = Gloss.readBinaryGlosses;
const Byzantine = @import("Byzantine.zig");

const Pool = @import("Pool.zig").Pool;

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
