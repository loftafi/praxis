/// A `Lexeme` is a collection of `Form` objects that represent the same
/// underlying fundamental meaning.
///
/// For example, "jump" is a lexeme, and forms of this word include "jump," "jumps,", "jumping," etc...
uid: u24 = 0,
word: []const u8,
lang: Lang = Lang.unknown,
article: Gender = .unknown,
pos: Parsing = .{ .part_of_speech = .unknown },
forms: std.ArrayList(*Form),
strongs: std.ArrayList(u16),
glosses: std.ArrayList(*Gloss) = undefined,
tags: ?[][]const u8 = null,
root: []const u8 = undefined,
genitiveSuffix: []const u8 = undefined,
adjective: []const u8 = undefined,
alt: []const u8 = undefined,
note: []const u8 = undefined,

const Self = @This();

pub fn create(allocator: std.mem.Allocator) !*Self {
    var s = try allocator.create(Self);
    errdefer allocator.destroy(Self);
    try s.init(allocator);
    return s;
}

pub fn destroy(self: *Self, allocator: Allocator) void {
    self.deinit();
    allocator.destroy(self);
}

pub fn init(self: *Self, allocator: std.mem.Allocator) !void {
    self.uid = 0;
    self.word = "";
    self.lang = .unknown;
    self.article = .unknown;
    self.pos = .{ .part_of_speech = .unknown };
    self.forms = std.ArrayList(*Form).init(allocator);
    self.glosses = std.ArrayList(*Gloss).init(allocator);
    self.strongs = std.ArrayList(u16).init(allocator);
    self.tags = null;
    self.root = "";
    self.genitiveSuffix = "";
    self.adjective = "";
    self.alt = "";
}

pub fn deinit(self: *Self) void {
    if (self.word.len > 0) {
        self.glosses.allocator.free(self.word);
    }
    for (self.glosses.items) |gloss| {
        gloss.destroy();
    }
    if (self.tags) |tags| {
        for (tags) |*tag| {
            self.forms.allocator.free(tag.*);
        }
        self.forms.allocator.free(tags);
        self.tags = null;
    }
    if (self.root.len > 0) {
        self.forms.allocator.free(self.root);
    }
    if (self.alt.len > 0) {
        self.forms.allocator.free(self.alt);
    }
    if (self.adjective.len > 0) {
        self.forms.allocator.free(self.adjective);
    }
    if (self.genitiveSuffix.len > 0) {
        self.forms.allocator.free(self.genitiveSuffix);
    }
    self.strongs.deinit();
    self.glosses.deinit();
    self.forms.deinit();
}

pub fn glosses_by_lang(self: *const Self, lang: Lang) ?*Gloss {
    for (self.glosses.items) |gloss| {
        if (gloss.*.lang == lang) {
            return gloss;
        }
    }
    return null;
}

pub const VERB_PRIMARY = [_]Parsing{
    parse("V-PAI-1S") catch unreachable,
    parse("V-PEI-1S") catch unreachable,
    parse("V-PMI-1S") catch unreachable,
    parse("V-PPI-1S") catch unreachable,
    parse("V-FAI-1S") catch unreachable,
    parse("V-AAI-1S") catch unreachable,
    parse("V-IAI-1S") catch unreachable,
};
pub const NOUN_PRIMARY = [_]Parsing{
    parse("N-NSM") catch unreachable,
    parse("N-NSF") catch unreachable,
    parse("N-NSN") catch unreachable,
};
pub const ADJECTIVE_PRIMARY = [_]Parsing{
    parse("A-NSM") catch unreachable,
    parse("A-NSF") catch unreachable,
    parse("A-NSN") catch unreachable,
};

pub fn form_by_parsing(self: *const Self, parsing: Parsing) ?*Form {
    for (self.forms.items) |item| {
        if (item.parsing == parsing) {
            return item;
        }
    }
    return null;
}

pub fn primary_form(self: *const Self) ?*Form {
    if (self.forms.items.len == 0) {
        return null;
    }

    switch (self.pos.part_of_speech) {
        .verb => {
            for (VERB_PRIMARY) |parsing| {
                if (self.form_by_parsing(parsing)) |found| {
                    return found;
                }
            }
        },
        .noun => {
            for (NOUN_PRIMARY) |parsing| {
                if (self.form_by_parsing(parsing)) |found| {
                    return found;
                }
            }
        },
        .adjective => {
            for (ADJECTIVE_PRIMARY) |parsing| {
                if (self.form_by_parsing(parsing)) |found| {
                    return found;
                }
            }
        },
        else => {},
    }

    return self.forms.items[0];
}

/// Sort by the `word` field. If word field matches, compare
/// the `glosses` count.
pub fn lessThan(_: void, self: *Self, other: *Self) bool {
    const x = @import("sort.zig").order(self.word, other.word);
    if (x == .lt) {
        return true;
    } else if (x == .gt) {
        return false;
    }
    // Fallback to compare gloss count
    return self.glosses.items.len < other.glosses.items.len;
}

/// Read all binary lexeme information along
/// with any child form records that appear
/// immediately after it.
pub fn read_binary(self: *Self, t: *BinaryReader) !void {
    self.uid = try t.u24();
    const word = try t.string();
    self.word = try self.forms.allocator.dupe(u8, word);
    self.lang = try Lang.from_u8(try t.u8());
    self.pos = @bitCast(try t.u32());
    self.article = try Gender.from_u8(try t.u8());
    try read_binary_glosses(t, &self.glosses);
    self.tags = null;
    const tag_count = try t.u8();
    if (tag_count > 0) {
        self.tags = try self.forms.allocator.alloc([]const u8, tag_count);
        for (0..tag_count) |i| {
            const value = t.string() catch {
                return error.InvalidDictionaryFile;
            };
            self.tags.?[i] = try self.forms.allocator.dupe(u8, value);
        }
    }
    const strongs_count = try t.u8();
    for (0..strongs_count) |_| {
        const number = try t.u16();
        try self.strongs.append(number);
    }

    const form_count = try t.u16();
    for (0..form_count) |_| {
        const form_entry = try Form.create(self.forms.allocator);
        errdefer form_entry.destroy(self.forms.allocator);
        try form_entry.read_binary(t);
        form_entry.lexeme = self;
        try self.forms.append(form_entry);
    }
}

/// Write all fields from a lexeme in binary format. No child
/// form records are output.
pub fn writeBinary(self: *Self, allocator: Allocator, data: *std.ArrayListUnmanaged(u8)) !void {
    try append_u24(allocator, data, self.uid);
    try data.appendSlice(allocator, self.word);
    try data.append(allocator, US);
    try data.append(allocator, @intFromEnum(self.lang));
    try append_u32(allocator, data, @bitCast(self.pos));
    try data.append(allocator, @intFromEnum(self.article)); // M, F, M/F...
    try append_u16(allocator, data, @intCast(self.glosses.items.len));
    for (self.glosses.items) |gloss| {
        try data.append(allocator, @intFromEnum(gloss.lang));
        for (gloss.glosses()) |item| {
            try data.appendSlice(allocator, item);
            try data.append(allocator, US);
        }
        try data.append(allocator, RS);
    }
    if (self.tags) |tags| {
        try append_u8(allocator, data, @intCast(tags.len));
        for (tags) |tag| {
            try data.appendSlice(allocator, tag);
            try data.append(allocator, US);
        }
    } else {
        try append_u8(allocator, data, 0);
    }
    try append_u8(allocator, data, @as(u8, @intCast(self.strongs.items.len)));
    for (self.strongs.items) |number| {
        try append_u16(allocator, data, number);
    }
}

/// Read a text string representing the basic information
/// about a lexeme. Reads one line only. Does not read
/// form entries on the following lines.
///
/// Ἀαρών|el||17|2|ὁ|IndeclinableProperNoun||Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|
/// Ἀαρών|el||17|2|ὁ|ProperNoun||Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|
pub fn read_text(self: *Self, t: *Parser) !void {
    _ = t.skip_whitespace_and_lines();
    //const start = t.index;
    const word_field = try form.read_field(t);
    if (word_field.len == 0) {
        self.word = "";
    } else {
        self.word = try self.forms.allocator.dupe(u8, word_field);
    }
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    self.lang = try t.read_lang();
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    const alt = try form.read_field(t);
    if (alt.len > 0) {
        self.alt = try self.glosses.allocator.dupe(u8, alt);
    }
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    self.uid = try form.read_u24(t); // Lexeme UID
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    _ = try t.read_strongs(&self.strongs);
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    self.article = try t.read_article();
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    self.pos = t.read_pos();
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    const suffix = try form.read_field(t); // Genitive suffix
    if (suffix.len > 0) {
        self.genitiveSuffix = try self.glosses.allocator.dupe(u8, suffix);
    }
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    const root = try form.read_field(t); // Lexeme root
    if (root.len > 0) {
        self.root = try self.glosses.allocator.dupe(u8, root);
    }
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    try read_text_glosses(t, &self.glosses); // Glosses
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    const adjectives = try form.read_field(t); // Adjective forms
    if (adjectives.len > 0) {
        self.adjective = try self.glosses.allocator.dupe(u8, adjectives);
    }
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    const tag_set = try form.read_field(t); // Tags
    var i = std.mem.tokenizeAny(u8, tag_set, " ,\n\r\t");
    var buffer = std.BoundedArray([]const u8, 10){};
    while (i.next()) |tag| {
        if (tag.len == 0) continue;
        if (buffer.len == buffer.capacity()) break;
        buffer.appendAssumeCapacity(tag);
    }
    self.tags = try self.forms.allocator.alloc([]const u8, buffer.len);
    for (buffer.slice(), 0..) |tag, x| {
        self.tags.?[x] = try self.forms.allocator.dupe(u8, tag);
    }
    _ = try form.read_field(t); // ??
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    _ = try form.read_field(t); // ??
    _ = t.read_until_eol();
}

const std = @import("std");
const Allocator = std.mem.Allocator;
pub const Parser = @import("parser.zig");
const is_eol = @import("parser.zig").is_eol;
const is_whitespace = @import("parser.zig").is_whitespace;
const form = @import("form.zig");
const Form = @import("form.zig");
const is_whitespace_or_eol = @import("parser.zig").is_whitespace_or_eol;
pub const PartOfSpeech = @import("part_of_speech.zig").PartOfSpeech;
const parse_pos = @import("part_of_speech.zig").parse_pos;
pub const Parsing = @import("parsing.zig").Parsing;
pub const parse = @import("parsing.zig").parse;
pub const Gender = @import("parsing.zig").Gender;
pub const Gloss = @import("gloss.zig");
pub const Lang = @import("lang.zig").Lang;

const BinaryReader = @import("binary_reader.zig");
const BinaryWriter = @import("binary_writer.zig");
const append_u8 = BinaryWriter.append_u8;
const append_u16 = BinaryWriter.append_u16;
const append_u24 = BinaryWriter.append_u24;
const append_u32 = BinaryWriter.append_u32;
const RS = BinaryWriter.RS;
const US = BinaryWriter.US;

const read_text_glosses = @import("gloss.zig").read_text_glosses;
pub const read_binary_glosses = @import("gloss.zig").read_binary_glosses;

const eql = @import("std").mem.eql;
const expect = std.testing.expect;
const expectEqualDeep = std.testing.expectEqualDeep;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

//Ἀαρών|el||17|2|ὁ|IndeclinableProperNoun||Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|
//   Ἀαρών|N-NSM|false|17||
test "read_lexeme" {
    var data = Parser.init("Ἀαρών|el||17|2|ὁ|IndeclinableProperNoun||Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|");
    var lexeme = try Self.create(std.testing.allocator);
    defer lexeme.destroy(std.testing.allocator);
    try lexeme.read_text(&data);
    try expectEqualStrings("Ἀαρών", lexeme.word);
    try expectEqual(17, lexeme.uid);
    try expectEqual(Lang.greek, lexeme.lang);
    //try expect(data.consume_if('\n'));
    try expectEqual(3, lexeme.glosses.items.len);
    try expectEqual(Gender.masculine, lexeme.article);
    try expectEqual(Lang.english, lexeme.glosses.items[0].lang);
    try expectEqual(Lang.chinese, lexeme.glosses.items[1].lang);
    try expectEqual(Lang.spanish, lexeme.glosses.items[2].lang);
    try expect(lexeme.glosses_by_lang(.hebrew) == null);
    try expect(lexeme.glosses_by_lang(.english) != null);
    try expectEqual(1, lexeme.glosses_by_lang(.spanish).?.glosses().len);
    try expectEqualStrings("Aarón", lexeme.glosses_by_lang(.spanish).?.glosses()[0]);
}

test "read_lexeme2" {
    var data = Parser.init(
        \\ἀγγεῖον|el|ἀγγεῖο|388|30,55|τό|Noun|-ου|ἀγγεῖ|en:vessel:flask:container:can|a b c|tag|
    );
    var lexeme = try Self.create(std.testing.allocator);
    defer lexeme.destroy(std.testing.allocator);
    try lexeme.read_text(&data);
    try expectEqual(Lang.greek, lexeme.lang);
    try expectEqual(388, lexeme.uid);
    try expectEqual(2, lexeme.strongs.items.len);
    try expectEqual(55, lexeme.strongs.items[1]);
    try expectEqual(1, lexeme.glosses.items.len);
    try expectEqualStrings("ἀγγεῖο", lexeme.alt);
    try expectEqualStrings("a b c", lexeme.adjective);
    try expectEqualStrings("-ου", lexeme.genitiveSuffix);
}

test "lexeme_bytes" {
    const allocator = std.testing.allocator;
    var data = Parser.init("cat|el||17|2|ὁ|IndeclinableProperNoun||cat|en:cat#zh:ara#es:nat||person|");
    var lexeme = try Self.create(allocator);
    defer lexeme.destroy(allocator);
    try lexeme.read_text(&data);

    var out: std.ArrayListUnmanaged(u8) = .empty;
    defer out.deinit(allocator);
    try lexeme.writeBinary(allocator, &out);

    //try expectEqual(41, out.items.len);
    try expectEqual(17, out.items[0]);
    try expectEqual(0, out.items[1]);
    try expectEqual(0, out.items[2]);

    try expectEqual('c', out.items[3]);
    try expectEqual('a', out.items[4]);
    try expectEqual('t', out.items[5]);
    try expectEqual(US, out.items[6]);

    try expectEqual(@intFromEnum(Lang.greek), out.items[7]);
    try expectEqual(@intFromEnum(PartOfSpeech.proper_noun), out.items[8]);
    try expectEqual(@intFromEnum(Gender.masculine), out.items[12]);
    try expectEqual(3, out.items[13]);
    try expectEqual(0, out.items[14]);
    try expectEqual(@intFromEnum(Lang.english), out.items[15]);
    try expectEqual('c', out.items[16]);

    //try std.testing.expectEqualSlices(u8, &[_]u8{}, out.items);
}

test "compare_lexeme" {
    const allocator = std.testing.allocator;
    {
        var data = Parser.init(
            \\Ἀαρώ|el||17|2|ὁ|IndeclinableProperNoun||Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|
            \\Ἀαρών|el||18|2|ὁ|IndeclinableProperNoun||Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|
            \\Ἀαρώνα|el||19|2|ὁ|IndeclinableProperNoun||Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|
        );
        var lexeme1 = try Self.create(allocator);
        defer lexeme1.destroy(allocator);
        try lexeme1.read_text(&data);
        var lexeme2 = try Self.create(allocator);
        defer lexeme2.destroy(allocator);
        try lexeme2.read_text(&data);
        var lexeme3 = try Self.create(allocator);
        defer lexeme3.destroy(allocator);
        try lexeme3.read_text(&data);
        try expectEqual(true, lessThan({}, lexeme1, lexeme2));
        try expectEqual(true, lessThan({}, lexeme1, lexeme3));
        try expectEqual(false, lessThan({}, lexeme3, lexeme2));
        try expectEqual(false, lessThan({}, lexeme3, lexeme1));
    }
    {
        var data = Parser.init(
            \\Ἀαρών|el||17|2|ὁ|IndeclinableProperNoun||Ἀαρών|||person|
            \\Ἀαρών|el||18|2|ὁ|IndeclinableProperNoun||Ἀαρών|en:Aaron#zh:亞倫||person|
            \\Ἀαρών|el||19|2|ὁ|IndeclinableProperNoun||Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|
        );
        var lexeme1 = try Self.create(allocator);
        defer lexeme1.destroy(allocator);
        try lexeme1.read_text(&data);
        var lexeme2 = try Self.create(allocator);
        defer lexeme2.destroy(allocator);
        try lexeme2.read_text(&data);
        var lexeme3 = try Self.create(allocator);
        defer lexeme3.destroy(allocator);
        try lexeme3.read_text(&data);
        try expectEqual(true, lessThan({}, lexeme1, lexeme2));
        try expectEqual(true, lessThan({}, lexeme1, lexeme3));
        try expectEqual(false, lessThan({}, lexeme3, lexeme2));
        try expectEqual(false, lessThan({}, lexeme3, lexeme1));
    }
}

test "binary_lexeme_load_save" {
    const allocator = std.testing.allocator;
    var data = Parser.init("ἅγιος|el||519|40,39||Adjective||ἅγι|en:holy:set apart:sacred#zh:聖潔的:至聖所:聖所:聖徒:聖:聖潔#es:santo:apartado:sagrado|ἅγιος,-α,-ον|worship, church|\n");
    var lexeme = try Self.create(allocator);
    defer lexeme.destroy(allocator);
    try lexeme.read_text(&data);
    try expectEqual(2, lexeme.strongs.items.len);
    try expectEqual(40, lexeme.strongs.items[0]);
    try expectEqual(39, lexeme.strongs.items[1]);
    try expectEqual(2, lexeme.tags.?.len);
    var out: std.ArrayListUnmanaged(u8) = .empty;
    defer out.deinit(allocator);
    try lexeme.writeBinary(allocator, &out);
    try append_u16(allocator, &out, 0); // no forms

    var lexeme2 = try Self.create(allocator);
    defer lexeme2.destroy(allocator);
    var r = BinaryReader.init(out.items);
    try lexeme2.read_binary(&r);
    try expectEqual(2, lexeme.strongs.items.len);
    try expectEqual(40, lexeme.strongs.items[0]);
    try expectEqual(39, lexeme.strongs.items[1]);
}

test "read_invalid_lexeme_id" {
    var data = Parser.init("Ἀαρών|el||nana|2|ὁ|IndeclinableProperNoun||Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|\n");
    var lexeme = try Self.create(std.testing.allocator);
    defer lexeme.destroy(std.testing.allocator);
    const e = lexeme.read_text(&data);
    try expectEqual(e, error.InvalidU24);
}
