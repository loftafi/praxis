/// A `Lexeme` describes a dictionary entry.
///
/// A `Lexeme` contain a collection of `Form` objects that describe the
/// range of ways this lexeme appears
/// underlying fundamental meaning.
///
/// For example, "jump" is a lexeme, and forms of this word include "jump," "jumps,", "jumping," etc...
uid: u24 = 0,
word: []const u8,
lang: Lang = Lang.unknown,
article: Gender = .unknown,
pos: Parsing = .{ .part_of_speech = .unknown },
forms: std.ArrayListUnmanaged(*Form),
strongs: std.ArrayListUnmanaged(u16),
glosses: std.ArrayListUnmanaged(*Gloss) = undefined,
tags: ?[][]const u8 = null,
root: []const u8 = undefined,
genitiveSuffix: []const u8 = undefined,
adjective: []const u8 = undefined,
note: []const u8 = undefined,

const Lexeme = @This();

/// Create this structure then use `init` to set up the fields.
pub fn create(allocator: std.mem.Allocator) error{OutOfMemory}!*Lexeme {
    var s = try allocator.create(Lexeme);
    s.init();
    return s;
}

/// Deinit this structure and destroy it.
pub fn destroy(self: *Lexeme, allocator: Allocator) void {
    self.deinit(allocator);
    allocator.destroy(self);
}

/// Initialise all fields to reasonable defaults.
pub fn init(self: *Lexeme) void {
    self.* = .empty;
}

/// A placeholder lexeme which contains no data.
pub const empty: Lexeme = .{
    .uid = 0,
    .word = "",
    .lang = .unknown,
    .article = .unknown,
    .pos = .{ .part_of_speech = .unknown },
    .forms = .empty,
    .glosses = .empty,
    .strongs = .empty,
    .tags = null,
    .root = "",
    .genitiveSuffix = "",
    .adjective = "",
};

/// Release any memory under the control of this struct. The `forms` do not
/// belong to this struct so are not released.
pub fn deinit(self: *Lexeme, allocator: Allocator) void {
    if (self.word.len > 0)
        allocator.free(self.word);

    for (self.glosses.items) |gloss| {
        gloss.destroy(allocator);
    }
    self.glosses.deinit(allocator);

    if (self.tags) |tags| {
        for (tags) |*tag| {
            allocator.free(tag.*);
        }
        allocator.free(tags);
        self.tags = null;
    }
    if (self.root.len > 0)
        allocator.free(self.root);

    if (self.adjective.len > 0)
        allocator.free(self.adjective);

    if (self.genitiveSuffix.len > 0)
        allocator.free(self.genitiveSuffix);

    self.strongs.deinit(allocator);
    self.forms.deinit(allocator);
}

/// Lookup the glosses according to the users preferred language
/// with no fallback to a default language such as English.
pub fn glosses_by_lang(self: *const Lexeme, lang: Lang) ?*Gloss {
    for (self.glosses.items) |gloss| {
        if (gloss.*.lang == lang) return gloss;
    }
    return null;
}

/// Returns true if this `Lexeme` if the `tags` list contains this `tag`.
pub fn has_tag(self: *const Lexeme, tag: []const u8) bool {
    if (self.tags) |tags|
        for (tags) |i|
            if (std.ascii.eqlIgnoreCase(i, tag))
                return true;
    return false;
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

/// Get the _first_ form matching the specified parsing.
pub fn formByParsing(self: *const Lexeme, parsing: Parsing) ?*Form {
    var found: ?*Form = null;

    // Loop until we fined the group of forms that have this
    // parsing, then choose the preferred item.
    for (self.forms.items) |current| {
        if (current.parsing == parsing) {
            if (found) |other| {
                // Pick preferred option if one exists.
                if (current.preferred) {
                    found = current;
                    continue;
                }
                // Pick form with glosses if the other does not.
                if (current.glosses.items.len > 0 and other.glosses.items.len == 0) {
                    found = current;
                    continue;
                }
                if (current.glosses.items.len == 0 and other.glosses.items.len > 0) {
                    continue;
                }
                if (other.references.items.len > current.references.items.len) {
                    found = current;
                }
                continue;
            }
            found = current;
            continue;
        }
        // The loop has moved past the items with the requested parsing.
        if (found != null) {
            return found;
        }
    }
    return found;
}

/// Returns the form that would usually appear at the top of
/// a list of forms in a table.
pub fn primaryForm(self: *const Lexeme) ?*Form {
    if (self.forms.items.len == 0)
        return null;

    switch (self.pos.part_of_speech) {
        .verb => {
            for (VERB_PRIMARY) |parsing| {
                if (self.formByParsing(parsing)) |found| {
                    return found;
                }
            }
        },
        .noun => {
            for (NOUN_PRIMARY) |parsing| {
                if (self.formByParsing(parsing)) |found| {
                    return found;
                }
            }
        },
        .adjective => {
            for (ADJECTIVE_PRIMARY) |parsing| {
                if (self.formByParsing(parsing)) |found| {
                    return found;
                }
            }
        },
        else => {},
    }

    return self.forms.items[0];
}

/// Compare two `Lexeme` entries by the `word` field. If both `word` values
/// match, compare the `glosses` count.
pub fn lessThan(_: ?[]const u8, self: *Lexeme, other: *Lexeme) bool {
    const x = @import("sort.zig").order(self.word, other.word);
    if (x == .lt) {
        return true;
    } else if (x == .gt) {
        return false;
    }
    // Fallback to compare gloss count
    return self.glosses.items.len < other.glosses.items.len;
}

/// Read binary `Lexeme` information along with any child `Form` binary
/// records attached to the lexeme.
pub fn readBinary(self: *Lexeme, arena: Allocator, t: *BinaryReader) !void {
    self.uid = try t.u24();
    const word = try t.string();
    self.word = try arena.dupe(u8, word);
    self.lang = try Lang.from_u8(try t.u8());
    self.pos = @bitCast(try t.u32());
    self.article = try Gender.from_u8(try t.u8());
    try readBinaryGlosses(arena, t, &self.glosses);
    self.tags = null;
    const tag_count = try t.u8();
    if (tag_count > 0) {
        self.tags = try arena.alloc([]const u8, tag_count);
        for (0..tag_count) |i| {
            const value = t.string() catch {
                return error.InvalidDictionaryFile;
            };
            self.tags.?[i] = try arena.dupe(u8, value);
        }
    }
    const strongs_count = try t.u8();
    for (0..strongs_count) |_| {
        const number = try t.u16();
        try self.strongs.append(arena, number);
    }

    const form_count = try t.u16();
    try self.forms.ensureTotalCapacity(arena, form_count);
    for (0..form_count) |_| {
        const form_entry = try Form.create(arena);
        errdefer form_entry.destroy(arena);
        try form_entry.readBinary(arena, t);
        form_entry.lexeme = self;
        try self.forms.append(arena, form_entry);
    }
}

/// Write lexeme data in binary format to a `writer`. Child `Form` records
/// are not exported. See `Form.writeBinary`.
pub fn writeBinary(
    self: *const Lexeme,
    data: *std.Io.Writer,
) std.Io.Writer.Error!void {
    try append_u24(data, self.uid);
    try data.writeAll(self.word);
    try data.writeByte(US);
    try data.writeByte(@intFromEnum(self.lang));
    try append_u32(data, @bitCast(self.pos));
    try data.writeByte(@intFromEnum(self.article)); // M, F, M/F...
    try append_u16(data, @intCast(self.glosses.items.len));
    for (self.glosses.items) |gloss| {
        try data.writeByte(@intFromEnum(gloss.lang));
        for (gloss.glosses()) |item| {
            try data.writeAll(item);
            try data.writeByte(US);
        }
        try data.writeByte(RS);
    }
    if (self.tags) |tags| {
        try append_u8(data, @intCast(tags.len));
        for (tags) |tag| {
            try data.writeAll(tag);
            try data.writeByte(US);
        }
    } else {
        try append_u8(data, 0);
    }
    try append_u8(data, @as(u8, @intCast(self.strongs.items.len)));
    for (self.strongs.items) |number| {
        try append_u16(data, number);
    }
}

/// Read text `Lexeme` information representing  basic information about a
/// lexeme. Reads one line only. Does not read form entries on the
/// following lines.
///
/// Ἀαρών|el|17|IndeclinableProperNoun|ὁ||2|Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|
/// Ἀαρών|el|17|ProperNoun|ὁ||2|Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|
pub fn readText(self: *Lexeme, arena: Allocator, t: *Parser) !void {
    _ = t.skip_whitespace_and_lines();

    const word_field = t.read_field();
    if (word_field.len == 0) return error.EmptyField;
    self.word = try arena.dupe(u8, word_field);
    if (!t.consume_if('|')) {
        // Extra warning on first field to highlight where problem is
        err("expected |, found {d} while reading line {d} (word={s})", .{ t.peek(), t.line, word_field });
        return error.MissingField;
    }

    self.lang = try t.read_lang();

    if (!t.consume_if('|')) return error.MissingField;
    self.uid = try t.read_u24(); // Lexeme UID

    if (!t.consume_if('|')) return error.MissingField;
    self.pos = t.read_pos();

    if (!t.consume_if('|')) return error.MissingField;
    self.article = try t.read_article();

    if (!t.consume_if('|')) return error.MissingField;
    const suffix = t.read_field(); // Genitive suffix
    if (suffix.len > 0) {
        self.genitiveSuffix = try arena.dupe(u8, suffix);
    }

    if (!t.consume_if('|')) return error.MissingField;
    _ = try t.readStrongs(arena, &self.strongs);

    if (!t.consume_if('|')) return error.MissingField;
    const root = t.read_field(); // Lexeme root
    if (root.len > 0) {
        self.root = try arena.dupe(u8, root);
    }
    if (!t.consume_if('|')) {
        return error.MissingField;
    }

    try readTextGlosses(arena, t, &self.glosses); // Glosses
    if (!t.consume_if('|')) {
        return error.MissingField;
    }
    const adjectives = t.read_field(); // Adjective forms
    if (adjectives.len > 0) {
        self.adjective = try arena.dupe(u8, adjectives);
    }

    if (!t.consume_if('|')) return error.MissingField;
    const tag_set = t.read_field(); // Tags
    var i = std.mem.tokenizeAny(u8, tag_set, " ,\n\r\t");
    var tags: [10][]const u8 = undefined;
    var ti: usize = 0;
    while (i.next()) |tag| {
        if (ti == tags.len) break;
        if (tag.len == 0) continue;
        tags[ti] = tag;
        ti += 1;
    }
    self.tags = try arena.alloc([]const u8, ti);
    for (0..ti) |x| {
        self.tags.?[x] = try arena.dupe(u8, tags[x]);
    }
    _ = t.read_field(); // ??

    if (!t.consume_if('|')) return error.MissingField;
    self.note = t.read_field();
    _ = t.read_until_eol();
}

/// Write lexeme data in text format to a `writer`.
pub fn writeText(
    self: *const Lexeme,
    writer: *std.Io.Writer,
) (std.Io.Writer.Error)!void {
    try writer.writeAll(self.word);
    try writer.writeByte('|');
    try writer.writeAll(self.lang.to_code());
    try writer.writeByte('|');
    try writer.print("{d}", .{self.uid});
    try writer.writeByte('|');
    try writer.writeAll(english_camel_case(self.pos));
    try writer.writeByte('|');
    try writer.writeAll(self.article.articles()); // M, F, M/F...
    try writer.writeByte('|');
    try writer.writeAll(self.genitiveSuffix);
    try writer.writeByte('|');
    for (self.strongs.items, 0..) |sn, i| {
        if (i > 0) try writer.writeByte(',');
        try writer.print("{d}", .{sn});
    }
    try writer.writeByte('|');
    try writer.writeAll(self.root);
    // root
    try writer.writeByte('|');
    try writeTextGlosses(writer, &self.glosses);
    try writer.writeByte('|');
    try writer.writeAll(self.adjective);
    try writer.writeByte('|');
    if (self.tags) |tags| {
        for (tags, 0..) |tag, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.writeAll(tag);
        }
    }
    try writer.writeByte('|');
    try writer.writeAll(self.note);
}

//Ἀαρών|el||17|2|ὁ|IndeclinableProperNoun||Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|
//   Ἀαρών|N-NSM|false|17||
test "read_lexeme" {
    var data = Parser.init("Ἀαρών|el|17|IndeclinableProperNoun|ὁ||2|Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|");
    var lexeme = try Lexeme.create(std.testing.allocator);
    defer lexeme.destroy(std.testing.allocator);
    try lexeme.readText(std.testing.allocator, &data);
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
    try expectEqual(false, lexeme.has_tag("nothing"));
    try expectEqual(true, lexeme.has_tag("person"));
}

test "read_lexeme_short" {
    var data = Parser.init("α|el|123123|Letter|||||en:alpha||alphabet|");
    var lexeme = try Lexeme.create(std.testing.allocator);
    defer lexeme.destroy(std.testing.allocator);
    try lexeme.readText(std.testing.allocator, &data);
    try expectEqualStrings("α", lexeme.word);
    try expectEqual(123123, lexeme.uid);
}

test "read_lexeme2" {
    var data = Parser.init(
        \\ἀγγεῖον|el|388|Noun|τό|-ου|30,55|ἀγγεῖ|en:vessel:flask:container:can|a b c|tag|
    );
    var lexeme = try Lexeme.create(std.testing.allocator);
    defer lexeme.destroy(std.testing.allocator);
    try lexeme.readText(std.testing.allocator, &data);
    try expectEqual(Lang.greek, lexeme.lang);
    try expectEqual(388, lexeme.uid);
    try expectEqual(2, lexeme.strongs.items.len);
    try expectEqual(55, lexeme.strongs.items[1]);
    try expectEqual(1, lexeme.glosses.items.len);
    try expectEqualStrings("a b c", lexeme.adjective);
    try expectEqualStrings("-ου", lexeme.genitiveSuffix);
}

test "lexeme_bytes" {
    const allocator = std.testing.allocator;
    var data = Parser.init("cat|el|17|IndeclinableProperNoun|ὁ||2|cat|en:cat#zh:ara#es:nat||person|");
    var lexeme = try Lexeme.create(allocator);
    defer lexeme.destroy(allocator);
    try lexeme.readText(std.testing.allocator, &data);

    var buffer: std.Io.Writer.Allocating = .init(allocator);
    defer buffer.deinit();
    try lexeme.writeBinary(&buffer.writer);
    const out = buffer.written();

    //try expectEqual(41, out.items.len);
    try expectEqual(17, out[0]);
    try expectEqual(0, out[1]);
    try expectEqual(0, out[2]);

    try expectEqual('c', out[3]);
    try expectEqual('a', out[4]);
    try expectEqual('t', out[5]);
    try expectEqual(US, out[6]);

    try expectEqual(@intFromEnum(Lang.greek), out[7]);
    try expectEqual(@intFromEnum(PartOfSpeech.proper_noun), out[8]);
    try expectEqual(@intFromEnum(Gender.masculine), out[12]);
    try expectEqual(3, out[13]);
    try expectEqual(0, out[14]);
    try expectEqual(@intFromEnum(Lang.english), out[15]);
    try expectEqual('c', out[16]);
}

test "compare_lexeme" {
    const allocator = std.testing.allocator;
    {
        var data = Parser.init(
            \\Ἀαρώ|el|17|IndeclinableProperNoun|ὁ||2|Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|
            \\Ἀαρών|el|18|IndeclinableProperNoun|ὁ||2|Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|
            \\Ἀαρώνα|el|19|IndeclinableProperNoun|ὁ||2|Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|
        );
        var lexeme1 = try Lexeme.create(allocator);
        defer lexeme1.destroy(allocator);
        try lexeme1.readText(allocator, &data);
        var lexeme2 = try Lexeme.create(allocator);
        defer lexeme2.destroy(allocator);
        try lexeme2.readText(allocator, &data);
        var lexeme3 = try Lexeme.create(allocator);
        defer lexeme3.destroy(allocator);
        try lexeme3.readText(std.testing.allocator, &data);
        try expectEqual(true, lessThan(null, lexeme1, lexeme2));
        try expectEqual(true, lessThan(null, lexeme1, lexeme3));
        try expectEqual(false, lessThan(null, lexeme3, lexeme2));
        try expectEqual(false, lessThan(null, lexeme3, lexeme1));
    }
    {
        var data = Parser.init(
            \\Ἀαρών|el|17|IndeclinableProperNoun||ὁ|3|Ἀαρών|||person|
            \\Ἀαρών|el|18|IndeclinableProperNoun||ὁ|3|Ἀαρών|en:Aaron#zh:亞倫||person|
            \\Ἀαρών|el|19|IndeclinableProperNoun||ὁ|3|Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|
        );
        var lexeme1 = try Lexeme.create(allocator);
        defer lexeme1.destroy(allocator);
        try lexeme1.readText(allocator, &data);
        var lexeme2 = try Lexeme.create(allocator);
        defer lexeme2.destroy(allocator);
        try lexeme2.readText(allocator, &data);
        var lexeme3 = try Lexeme.create(allocator);
        defer lexeme3.destroy(allocator);
        try lexeme3.readText(allocator, &data);
        try expectEqual(true, lessThan(null, lexeme1, lexeme2));
        try expectEqual(true, lessThan(null, lexeme1, lexeme3));
        try expectEqual(false, lessThan(null, lexeme3, lexeme2));
        try expectEqual(false, lessThan(null, lexeme3, lexeme1));
    }
}

test "return_correct_preferred_form" {
    const allocator = std.testing.allocator;

    {
        const dictionary = try Dictionary.create(allocator);
        defer dictionary.destroy(allocator);

        const data =
            \\δράκων|el|180000|Noun|ὁ|-οντος|1404|δράκ|en:dragon:large serpent#ru:дракон:большой змей#zh:龍:大蛇#es:dragón:serpiente grande||animal|
            \\  δράκων|N-NSM|false|170000||byz#Revelation 12:3 11,kjtr#Revelation 12:3 10,sbl#Revelation 12:3 10
            \\  δράκοντα|N-ASM|false|170001|en:the sneaky|byz#Revelation 20:2 3,kjtr#Revelation 20:2 3
            \\λύω|el|180001|Verb|||3089|λύ|en:untie:release:loose#ru:развязывать:освобождать:разрушать#zh:解開:釋放:放開#es:desato:suelto|||
            \\  λύω|V-PAI-1S|false|170002|en:I untie:I release:I loose|
            \\  λύω|V-PAI-1S|false|170003||
            \\  λύεις|V-PAI-2S|false|170004||
            \\  λύεις|V-PAI-2S|false|170005|en:You untie:You release|
            \\  λύει|V-PAI-3S|true|170006|en:You untie:You release|
            \\  λύει|V-PAI-3S|false|170007|en:You untie:You release|
            \\  λύετε|V-PAI-2P|false|170008||
            \\  λύετε|V-PAI-2P|true|170009||
            \\
        ;
        try dictionary.loadTextData(allocator, allocator, data);

        try expectEqual(2, dictionary.lexemes.items.len);
        try expectEqual(10, dictionary.forms.items.len);

        var results = dictionary.by_form.lookup("λύω");
        try expect(results != null);
        try expectEqual(2, results.?.exact_accented.items.len);
        try expectEqual(170002, results.?.exact_accented.items[0].uid);

        results = dictionary.by_form.lookup("λύεις");
        try expect(results != null);
        try expectEqual(2, results.?.exact_accented.items.len);
        try expectEqual(170005, results.?.exact_accented.items[0].uid);

        results = dictionary.by_form.lookup("λύει");
        try expect(results != null);
        try expectEqual(2, results.?.exact_accented.items.len);
        try expectEqual(170006, results.?.exact_accented.items[0].uid);

        results = dictionary.by_form.lookup("λύετε");
        try expect(results != null);
        try expectEqual(2, results.?.exact_accented.items.len);
        try expectEqual(170009, results.?.exact_accented.items[0].uid);

        const words = dictionary.by_lexeme.lookup("λύω");
        try expect(words != null);
        try expectEqual(1, words.?.exact_accented.items.len);
        var f = words.?.exact_accented.items[0].primaryForm();
        try expectEqual(170002, f.?.uid);

        try expect(words != null);
        try expectEqual(1, words.?.exact_accented.items.len);
        f = words.?.exact_accented.items[0].formByParsing(try parse("V-PAI-2S"));
        try expectEqual(170005, f.?.uid);

        try expect(words != null);
        try expectEqual(1, words.?.exact_accented.items.len);
        f = words.?.exact_accented.items[0].formByParsing(try parse("V-PAI-3S"));
        try expectEqual(170006, f.?.uid);

        try expect(words != null);
        try expectEqual(1, words.?.exact_accented.items.len);
        f = words.?.exact_accented.items[0].formByParsing(try parse("V-PAI-2P"));
        try expectEqual(170009, f.?.uid);
    }
}

test "binary_lexeme_load_save" {
    const allocator = std.testing.allocator;
    var data = Parser.init("ἅγιος|el|519|Adjective|||40,39|ἅγι|en:holy:set apart:sacred#zh:聖潔的:至聖所:聖所:聖徒:聖:聖潔#es:santo:apartado:sagrado|ἅγιος,-α,-ον|worship, church|\n");
    var lexeme = try Lexeme.create(allocator);
    defer lexeme.destroy(allocator);
    try lexeme.readText(allocator, &data);
    try expectEqual(2, lexeme.strongs.items.len);
    try expectEqual(40, lexeme.strongs.items[0]);
    try expectEqual(39, lexeme.strongs.items[1]);
    try expectEqual(2, lexeme.tags.?.len);

    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    try lexeme.writeBinary(&out.writer);
    try append_u16(&out.writer, 0); // no forms

    var lexeme2 = try Lexeme.create(allocator);
    defer lexeme2.destroy(allocator);
    var r = BinaryReader.init(out.written());
    try lexeme2.readBinary(allocator, &r);
    try expectEqual(2, lexeme.strongs.items.len);
    try expectEqual(40, lexeme.strongs.items[0]);
    try expectEqual(39, lexeme.strongs.items[1]);
}

test "read_invalid_lexeme_id" {
    var data = Parser.init("Ἀαρών|el|nana|IndeclinableProperNoun|ὁ||2|Ἀαρών|en:Aaron#zh:亞倫#es:Aarón||person|\n");
    var lexeme = try Lexeme.create(std.testing.allocator);
    defer lexeme.destroy(std.testing.allocator);
    const e = lexeme.readText(std.testing.allocator, &data);
    try expectEqual(e, error.InvalidU24);
}

const std = @import("std");
const err = std.log.err;
const Allocator = std.mem.Allocator;
const BoundedArray = @import("bounded_array.zig").BoundedArray;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

pub const Parser = @import("parser.zig");
const is_eol = @import("parser.zig").is_eol;
const is_whitespace = @import("parser.zig").is_whitespace;
const form = @import("form.zig");
const Form = @import("form.zig");
const is_whitespace_or_eol = @import("parser.zig").is_whitespace_or_eol;
const english_camel_case = @import("part_of_speech.zig").english_camel_case;
pub const PartOfSpeech = @import("part_of_speech.zig").PartOfSpeech;
const parse_pos = @import("part_of_speech.zig").parse_pos;
pub const Parsing = @import("parsing.zig").Parsing;
pub const Gender = Parsing.Gender;
pub const parse = @import("byz.zig").parse;
pub const Gloss = @import("gloss.zig");
pub const Lang = @import("lang.zig").Lang;
pub const writeTextGlosses = @import("gloss.zig").writeTextGlosses;

const BinaryReader = @import("binary_reader.zig");
const BinaryWriter = @import("binary_writer.zig");
const append_u8 = BinaryWriter.append_u8;
const append_u16 = BinaryWriter.append_u16;
const append_u24 = BinaryWriter.append_u24;
const append_u32 = BinaryWriter.append_u32;
const RS = BinaryWriter.RS;
const US = BinaryWriter.US;

const Dictionary = @import("dictionary.zig").Dictionary;

const readTextGlosses = @import("gloss.zig").readTextGlosses;
const readBinaryGlosses = @import("gloss.zig").readBinaryGlosses;

const eql = @import("std").mem.eql;
const expect = std.testing.expect;
const expectEqualDeep = std.testing.expectEqualDeep;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
