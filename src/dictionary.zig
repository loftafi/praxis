//! Contain a set of `Lexeme` and lexeme `Form` objects. Search
//! for forms and glosses that start with a desired string.

/// It is recommended to use an arena allocator to store the dictionary
/// information.
///
///      var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
///      defer arena.deinit();
///      dictionary = Dictionary.create(arena);
///      defer dictionary.deinit(arena);
///
pub const Dictionary = struct {
    by_lexeme: SearchIndex(*Lexeme, Lexeme.lessThan),
    by_form: SearchIndex(*Form, Form.autocompleteLessThan),
    by_gloss: SearchIndex(*Form, Form.autocompleteLessThan),
    by_transliteration: SearchIndex(*Form, Form.autocompleteLessThan),
    lexemes: ArrayListUnmanaged(*Lexeme),
    forms: ArrayListUnmanaged(*Form),

    pub fn create(allocator: Allocator) error{OutOfMemory}!*Dictionary {
        const dictionary: *Dictionary = try allocator.create(Dictionary);
        seed();
        dictionary.* = .{
            .by_lexeme = SearchIndex(*Lexeme, Lexeme.lessThan).init(),
            .by_form = SearchIndex(*Form, Form.autocompleteLessThan).init(),
            .by_gloss = SearchIndex(*Form, Form.autocompleteLessThan).init(),
            .by_transliteration = SearchIndex(*Form, Form.autocompleteLessThan).init(),
            .lexemes = try ArrayListUnmanaged(*Lexeme).initCapacity(allocator, 180000),
            .forms = try ArrayListUnmanaged(*Form).initCapacity(allocator, 180000),
        };
        return dictionary;
    }

    pub fn destroy(self: *Dictionary, allocator: Allocator) void {
        self.by_lexeme.deinit(allocator);
        for (self.lexemes.items) |*item| {
            item.*.destroy(allocator);
        }
        self.lexemes.deinit(allocator);

        self.by_form.deinit(allocator);
        for (self.forms.items) |*item| {
            item.*.destroy(allocator);
        }
        self.forms.deinit(allocator);

        self.by_gloss.deinit(allocator);
        self.by_transliteration.deinit(allocator);
        allocator.destroy(self);
    }

    /// Load dictionary data. Detect if the data is text or binary format.
    /// See `loadTextData()` and `loadBinaryData()` for details.
    pub fn loadFile(
        self: *Dictionary,
        arena: Allocator,
        filename: []const u8,
    ) !void {
        var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer temp_arena.deinit();

        const data = read_bytes_from_file(filename, temp_arena.allocator()) catch {
            err("Could not read {s}", .{filename});
            return;
        };

        if (data.len > 10 and data[0] == 99 and data[1] == 1) {
            try self.loadBinaryData(arena, temp_arena.allocator(), data);
        } else {
            try self.loadTextData(arena, temp_arena.allocator(), data);
        }
    }

    /// Load dictionary data that has been stored in a
    /// user readable text format. The `arena` allocator stores
    /// data for the lifetime of the dictionary and the `temp_allocator`
    /// stores trandient data used while loading the dictionary.
    pub fn loadTextData(
        self: *Dictionary,
        arena: Allocator,
        temp_allocator: Allocator,
        content: []const u8,
    ) !void {

        // Keep a cache of seen lexemes, and track which lexemes need a uid.
        var lexeme_uid = std.AutoHashMap(u24, *Lexeme).init(temp_allocator);
        defer lexeme_uid.deinit();
        var max_lexeme_uid: u24 = 0;
        var lexeme_needs_uid = std.ArrayList(*Lexeme).init(temp_allocator);
        defer lexeme_needs_uid.deinit();

        // Keep a cache of seen forms, and track which forms need a uid.
        var form_uid = std.AutoHashMap(u24, *Form).init(temp_allocator);
        defer form_uid.deinit();
        var max_form_uid: u24 = 0;
        var form_needs_uid = std.ArrayList(*Form).init(temp_allocator);
        defer form_needs_uid.deinit();

        var data = Parser.init(content);
        _ = data.skip_whitespace_and_lines();

        var line: usize = 0;
        var current_lexeme: ?*Lexeme = null;
        while (!data.eof()) {
            const c = data.peek();
            if (c == CR or c == LF) {
                _ = data.next();
                continue;
            }
            line += 1;
            if (!(c == SPACE or c == TAB)) {
                var lexeme = try Lexeme.create(arena);
                errdefer lexeme.destroy(arena);
                lexeme.readText(arena, &data) catch |e| {
                    err("Failed reading line: {d}. Error: {any}", .{ line, e });
                    lexeme.destroy(arena);
                    return e;
                };
                if (lexeme.word.len == 0) {
                    err("missing lexeme word field on line: {d}", .{line});
                    lexeme.destroy(arena);
                    break;
                }
                current_lexeme = lexeme;
                try self.lexemes.append(arena, lexeme);
                try self.by_lexeme.add(arena, lexeme.word, lexeme);
                if (lexeme.uid == 0) {
                    try lexeme_needs_uid.append(lexeme);
                } else {
                    try lexeme_uid.put(lexeme.uid, lexeme);
                    if (lexeme.uid > max_lexeme_uid) {
                        max_lexeme_uid = lexeme.uid;
                    }
                }
            } else {
                var form = try Form.create(arena);
                errdefer form.destroy(arena);
                form.readText(arena, &data) catch |e| {
                    err("Failed reading line: {any}. Error: {any}", .{ line, e });
                    return e;
                };
                if (form.word.len == 0) {
                    err("Missing form word field on line: {any}\n", .{line});
                    form.destroy(arena);
                    break;
                }
                try self.forms.append(arena, form);
                try self.by_form.add(arena, form.word, form);
                if (current_lexeme != null) {
                    form.lexeme = current_lexeme.?;
                    try current_lexeme.?.forms.append(arena, form);
                }
                if (form.uid == 0) {
                    try form_needs_uid.append(form);
                } else {
                    try form_uid.put(form.uid, form);
                    if (form.uid > max_lexeme_uid) {
                        max_form_uid = form.uid;
                    }
                }
            }
            //debug("reading line: {d} lexemes={d} forms={d}\n", .{ data.line, self.lexemes.items.len, self.forms.items.len });
        }

        // Build a search index of transliterated version of the words.
        var buffer: [500]u8 = undefined;
        for (self.forms.items) |form| {
            if (form.word.len == 0) {
                continue;
            }
            const transliterated = transliterate_word(form.word, false, &buffer) catch |e| {
                log.warn("Transliterate {s} failed: {any}", .{ form.word, e });
                continue;
            };
            if (transliterated.len == 0) {
                log.warn("Transliteration of {s} returned {s}", .{
                    form.word,
                    transliterated,
                });
            }
            try self.by_gloss.add(arena, transliterated, form);
        }

        // Build a search index of the glosses for each word.
        var seen = StringSet.init(temp_allocator);
        defer seen.deinit();
        for (self.lexemes.items) |lexeme| {
            if (lexeme.forms.items.len == 0) {
                continue;
            }
            // Add the primary glosses
            seen.clear();
            if (lexeme.forms.items[0].glosses_by_lang(.english)) |gloss| {
                for (gloss.entries.items) |entry| {
                    var i = GlossTokens{ .data = entry };
                    while (i.next()) |text| {
                        var buff: [@import("search_index.zig").MAX_WORD_SIZE * 2]u8 = undefined;
                        const lower = std.ascii.lowerString(&buff, text);
                        if (lower.len == entry.len or !is_stopword(lower)) {
                            try self.by_gloss.add(arena, lower, lexeme.forms.items[0]);
                            _ = try seen.add(lower);
                        }
                    }
                }
            }
            // Add addtional glosses from alternate forms
            for (lexeme.forms.items, 0..) |form, x| {
                if (x == 0) {
                    continue;
                }
                for (form.*.glosses.items) |entry| {
                    if (entry.lang != .english) {
                        continue;
                    }
                    for (entry.entries.items) |item| {
                        var i = GlossTokens{ .data = item };
                        while (i.next()) |text| {
                            if (text.len == item.len or !is_stopword(text)) {
                                if (try seen.add(text)) {
                                    try self.by_gloss.add(arena, text, form);
                                }
                            }
                        }
                    }
                }
            }
        }

        try self.sort_search_results();

        if (lexeme_needs_uid.items.len > 0) {
            info("{d} lexemes need uid.", .{lexeme_needs_uid.items.len});
            for (lexeme_needs_uid.items) |item| {
                item.uid = self.generateUniqueUid(&lexeme_uid, &form_uid);
                info("assign uid {s}={d}", .{ item.word, item.uid });
            }
            lexeme_needs_uid.clearAndFree();
        }
        if (form_needs_uid.items.len > 0) {
            info("{d} forms need uid.", .{form_needs_uid.items.len});
            for (form_needs_uid.items) |item| {
                item.uid = self.generateUniqueUid(&lexeme_uid, &form_uid);
                info("assign uid {s}={d}", .{ item.word, item.uid });
            }
            form_needs_uid.clearAndFree();
        }

        debug("Loaded dictionary.", .{});
        return;
    }

    fn generateUniqueUid(
        _: *Dictionary,
        lexeme_uid: *std.AutoHashMap(u24, *Lexeme),
        form_uid: *std.AutoHashMap(u24, *Form),
    ) u24 {
        while (true) {
            const next = random_u24();
            if (next < 100000) continue;
            if (lexeme_uid.get(next) != null) continue;
            if (form_uid.get(next) != null) continue;
            return next;
        }
    }

    /// Save all dictionary data, along with a pre-built
    /// search index into an on disk data file.
    pub fn saveBinaryFile(
        self: *const Dictionary,
        filename: []const u8,
    ) !void {
        var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer temp_arena.deinit();
        var data: std.ArrayListUnmanaged(u8) = .empty;
        defer data.deinit(temp_arena);
        try self.writeBinaryData(temp_arena, &data);
        debug("binary data size: {any}\n", .{data.items.len});
        try write_bytes_to_file(data.items, filename);
    }

    /// Save all dictionary data, along with a pre-built
    /// search index into a byte array.
    pub fn writeBinaryData(
        self: *const Dictionary,
        allocator: Allocator,
        data: *std.ArrayListUnmanaged(u8),
    ) error{ OutOfMemory, IndexTooLarge }!void {
        try data.append(allocator, 99);
        try data.append(allocator, 1);

        // Placeholder for word count. We don't yet know how many
        // words have data for inclusion.
        var include_words: u32 = 0;
        try data.append(allocator, 0);
        try data.append(allocator, 0);
        try data.append(allocator, 0);
        try data.append(allocator, 0);
        //try append_u32(data, @intCast(self.lexemes.items.len));

        for (self.lexemes.items) |*lexeme| {
            include_words += 1;
            try lexeme.*.writeBinary(allocator, data);
            try append_u16(allocator, data, @intCast(lexeme.*.forms.items.len));
            for (lexeme.*.forms.items) |*form| {
                try form.*.writeBinary(allocator, data);
            }
        }
        try data.append(allocator, FS);
        data.items[2] = (@intCast(include_words & 0xff));
        data.items[3] = (@intCast((include_words >> 8) & 0xff));
        data.items[4] = (@intCast((include_words >> 16) & 0xff));
        data.items[5] = (@intCast((include_words >> 24) & 0xff));

        // Now output the search indexes
        try self.by_form.writeBinaryBytes(allocator, data);
        try data.append(allocator, FS);

        try self.by_gloss.writeBinaryBytes(allocator, data);
        try data.append(allocator, FS);

        try self.by_transliteration.writeBinaryBytes(allocator, data);
        try data.append(allocator, FS);
    }

    /// Load dictionary data that has been stored in
    /// condensed binary format along with a pre-built
    /// search index.
    pub fn loadBinaryData(
        self: *Dictionary,
        arena: Allocator,
        temp_allocator: Allocator,
        content: []const u8,
    ) !void {
        var data = BinaryReader.init(content);
        if (try data.u8() != 99) {
            return error.InvalidDictionaryFile;
        }
        if (try data.u8() != 1) {
            return error.InvalidDictionaryFile;
        }
        const count = data.u32() catch {
            return error.InvalidDictionaryFile;
        };

        // Keep a cache of seen forms for index loading
        var form_uid = std.AutoHashMap(u24, *Form).init(temp_allocator);
        defer form_uid.deinit();
        try form_uid.ensureTotalCapacity(count);
        try self.lexemes.ensureTotalCapacity(arena, count);
        try self.forms.ensureTotalCapacity(arena, count);

        // Read all lexemes with associated forms
        for (0..count) |i| {
            var lexeme = try Lexeme.create(arena);
            errdefer lexeme.destroy(arena);
            lexeme.readBinary(arena, &data) catch |e| {
                debug("failed reading word {any} at byte index: {any}. Error: {any}\n", .{ i, data.index, e });
                if (i > 0) {
                    debug("previous word had uid {d}\n", .{self.lexemes.items[i - 1].uid});
                    debug("processing word {d} of {d}\n", .{ i, count });
                }
                debug(" buffer: {any} -{d}- {any}\n", .{
                    data.leading_slice(10),
                    data.peek(),
                    data.following_slice(10),
                });
                return e;
            };
            try self.lexemes.append(arena, lexeme);

            // Any forms discovered while reading lexeme should
            // appear in the form index.
            for (lexeme.forms.items) |*f| {
                try form_uid.put(f.*.uid, f.*);
                try self.forms.append(arena, f.*);
            }
            //if (data.next() != RS) {
            //    return error.InvalidDictionaryFile;
            //}
        }
        if (try data.u8() != FS) {
            return error.InvalidDictionaryFile;
        }

        // Read all search index data
        try self.by_form.loadBinaryData(arena, &data, &form_uid);
        if (try data.u8() != FS) {
            return error.InvalidDictionaryFile;
        }

        try self.by_gloss.loadBinaryData(arena, &data, &form_uid);
        if (try data.u8() != FS) {
            return error.InvalidDictionaryFile;
        }

        try self.by_transliteration.loadBinaryData(arena, &data, &form_uid);
        if (try data.u8() != FS) {
            return error.InvalidDictionaryFile;
        }

        log.debug(
            "Loaded binary dictionary ({d} words, {d} forms).",
            .{ self.lexemes.items.len, self.forms.items.len },
        );
        return;
    }

    pub fn sort_search_results(self: *Dictionary) !void {
        log.debug("Sorting dictionary indexes.", .{});
        try self.by_form.sort();
        try self.by_lexeme.sort();
        try self.by_gloss.sort();
        try self.by_transliteration.sort();
    }

    /// Export the entire dictionary contents into a user
    /// readable text file on disk.
    pub fn saveTextFile(
        self: *const Dictionary,
        allocator: Allocator,
        filename: []const u8,
    ) !void {
        var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer temp_arena.deinit();
        var data: std.ArrayListUnmanaged(u8) = .empty;
        defer data.deinit(allocator);
        try self.writeTextData(allocator, &data);
        std.debug.print("text data size: {any}\n", .{data.items.len});
        try write_bytes_to_file(data.items, filename);
    }

    /// Export the entire dictionary contents into a byte arra
    /// that can then be saved to disk or another location.
    pub fn writeTextData(
        self: *const Dictionary,
        allocator: Allocator,
        data: *ArrayListUnmanaged(u8),
    ) !void {
        var unsorted: ArrayListUnmanaged(*Lexeme) = .empty;
        defer unsorted.deinit(allocator);
        for (self.lexemes.items) |lexeme| {
            try unsorted.append(allocator, lexeme);
        }
        std.mem.sort(*Lexeme, unsorted.items, {}, Lexeme.lessThan);

        for (unsorted.items) |lexeme| {
            try lexeme.writeText(data.writer(allocator));

            for (lexeme.forms.items) |form| {
                try data.append(allocator, LF);
                try data.appendSlice(allocator, "  ");
                try form.writeText(data.writer(allocator));
                // References into linked modules
                for (form.references.items, 0..) |*reference, i| {
                    if (i > 0) {
                        try data.append(allocator, ',');
                    }
                    try data.appendSlice(allocator, reference.*.module.info().code);
                    try data.append(allocator, '#');
                    try data.appendSlice(allocator, reference.*.book.info().english);
                    try data.append(allocator, ' ');
                    try data.writer(allocator).print("{}", .{reference.*.chapter});
                    try data.append(allocator, ':');
                    try data.writer(allocator).print("{}", .{reference.*.verse});
                    if (reference.word > 0) {
                        try data.append(allocator, ' ');
                        try data.writer(allocator).print("{}", .{reference.*.word});
                    }
                }
            }
            try data.append(allocator, LF);
        }
    }
};

/// Helper function to read file contents.
fn read_bytes_from_file(filename: []const u8, temp_allocator: Allocator) ![]u8 {
    const file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();
    const stat = try file.stat();
    return try file.readToEndAllocOptions(temp_allocator, stat.size, stat.size, 1, null);
}

/// Helper function to write file contents.
fn write_bytes_to_file(data: []const u8, filename: []const u8) !void {
    const file = try std.fs.cwd().createFile(filename, .{ .truncate = true });
    defer file.close();
    return file.writeAll(data);
}

pub inline fn append_u64(data: *std.ArrayList(u8), value: u64) !void {
    try data.append(@intCast(value & 0xff));
    try data.append(@intCast((value >> 8) & 0xff));
    try data.append(@intCast((value >> 16) & 0xff));
    try data.append(@intCast((value >> 24) & 0xff));
    try data.append(@intCast((value >> 32) & 0xff));
    try data.append(@intCast((value >> 40) & 0xff));
    try data.append(@intCast((value >> 48) & 0xff));
    try data.append(@intCast((value >> 56) & 0xff));
}

pub inline fn append_u32(data: *std.ArrayList(u8), value: u32) !void {
    try data.append(@intCast(value & 0xff));
    try data.append(@intCast((value >> 8) & 0xff));
    try data.append(@intCast((value >> 16) & 0xff));
    try data.append(@intCast((value >> 24) & 0xff));
}

pub inline fn append_u24(data: *std.ArrayList(u8), value: u24) !void {
    try data.append(@intCast(value & 0xff));
    try data.append(@intCast((value >> 8) & 0xff));
    try data.append(@intCast((value >> 16) & 0xff));
}

//pub inline fn append_u16(data: *std.ArrayList(u8), value: u32) !void {
//    std.debug.assert(value <= 0xffff);
//    try data.append(@intCast(value & 0xff));
//    try data.append(@intCast((value >> 8) & 0xff));
//}

pub inline fn append_u8(data: *std.ArrayList(u8), value: u32) !void {
    std.debug.assert(value <= 0xff);
    try data.append(@intCast(value));
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
const log = std.log;
const err = std.log.err;
const info = std.log.info;
const debug = std.log.debug;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const Lexeme = @import("lexeme.zig");
const StringSet = @import("string_set.zig");
const Form = @import("form.zig");
const SearchIndex = @import("search_index.zig").SearchIndex;
const Parser = @import("parser.zig");
const parsing = @import("parsing.zig");
const pos = @import("part_of_speech.zig");
const Lang = @import("lang.zig").Lang;
const GlossTokens = @import("gloss_tokens.zig").GlossToken;
const is_stopword = @import("gloss_tokens.zig").is_stopword;
const builtin = @import("builtin");
const transliterate_word = @import("transliterate.zig").transliterate_word;
const BinaryReader = @import("binary_reader.zig");
const append_u16 = @import("binary_writer.zig").append_u16;
const random_u24 = @import("random.zig").random_u24;
const seed = @import("random.zig").seed;

const eql = @import("std").mem.eql;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualDeep = std.testing.expectEqualDeep;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqualSlices = std.testing.expectEqualSlices;

test "basic_dictionary" {
    const allocator = std.testing.allocator;

    // Do some basic black box testing on a short simple dictionary file.
    const dictionary = try Dictionary.create(allocator);
    defer dictionary.destroy(allocator);

    const data =
        \\δράκων|el|800000|Noun|ὁ|-οντος|1404|δράκ|en:dragon:large serpent#ru:дракон:большой змей#zh:龍:大蛇#es:dragón:serpiente grande||animal|
        \\  δράκων|N-NSM|false|700000||byz#Revelation 12:3 11,kjtr#Revelation 12:3 10,sbl#Revelation 12:3 10
        \\  δράκοντα|N-ASM|false|700001|en:the sneaky|byz#Revelation 20:2 3,kjtr#Revelation 20:2 3
        \\λύω|el|800001|Verb|||3089|λύ|en:untie:release:loose#ru:развязывать:освобождать:разрушать#zh:解開:釋放:放開#es:desato:suelto|||
        \\  λύω|V-PAI-1S|false|700002|en:I untie:I release:I loose|
        \\  λύεις|V-PAI-2S|false|700003|en:You untie:You release|
        \\  λύει|V-PAI-3S|false|700004|en:You untie:You release|
        \\
    ;

    try dictionary.loadTextData(allocator, allocator, data);

    try expectEqual(2, dictionary.lexemes.items.len);
    try expectEqual(5, dictionary.forms.items.len);

    try expectEqual(13, dictionary.by_lexeme.index.count());
    try expectEqual(27, dictionary.by_form.index.count());

    {
        const results = dictionary.by_form.lookup("λύω");
        try expect(results != null);
        try expectEqual(1, results.?.exact_accented.items.len);
        try expectEqual(0, results.?.exact_unaccented.items.len);
        try expectEqual(0, results.?.partial_match.items.len);
    }
    {
        const results = dictionary.by_form.lookup("λύει");
        try expect(results != null);
        try expectEqual(1, results.?.exact_accented.items.len);
        try expectEqual(0, results.?.exact_unaccented.items.len);
        try expectEqual(1, results.?.partial_match.items.len);
    }
    {
        const results = dictionary.by_form.lookup("λύεις");
        try expect(results != null);
        try expectEqual(1, results.?.exact_accented.items.len);
        try expectEqual(0, results.?.exact_unaccented.items.len);
        try expectEqual(0, results.?.partial_match.items.len);
    }
    {
        const results = dictionary.by_gloss.lookup("serpent");
        try expect(results != null);
        try expectEqual(1, results.?.exact_accented.items.len);
        try expectEqualStrings("δράκων", results.?.exact_accented.items[0].word);
        try expectEqual(0, results.?.exact_unaccented.items.len);
        try expectEqual(0, results.?.partial_match.items.len);
    }
    {
        const results = dictionary.by_gloss.lookup("sneaky");
        try expect(results != null);
        try expectEqual(1, results.?.exact_accented.items.len);
        try expectEqualStrings("δράκοντα", results.?.exact_accented.items[0].word);
        try expectEqual(0, results.?.exact_unaccented.items.len);
        try expectEqual(0, results.?.partial_match.items.len);
    }
    {
        const results = dictionary.by_gloss.lookup("the");
        try expect(results == null);
    }

    // Test basic text saving works correctly
    {
        var out: std.ArrayListUnmanaged(u8) = .empty;
        defer out.deinit(allocator);
        try dictionary.writeTextData(allocator, &out);
        try expectEqualDeep(data, out.items);
    }

    // Test basic binary saving works correctly
    {
        var out: std.ArrayListUnmanaged(u8) = .empty;
        defer out.deinit(allocator);
        try dictionary.writeBinaryData(allocator, &out);

        const header: []const u8 = &.{ 99, 1, 2, 0, 0, 0 };
        try expect(out.items.len > 50);
        try expectEqualSlices(u8, header, out.items[0..header.len]);

        const dictionary2 = try Dictionary.create(allocator);
        defer dictionary2.destroy(allocator);
        //try expectEqualSlices(u8, &[_]u8{}, out.items);
        try dictionary2.loadBinaryData(allocator, allocator, out.items);

        try expectEqual(2, dictionary.lexemes.items.len);
        try expectEqual(5, dictionary.forms.items.len);

        try expectEqual(13, dictionary.by_lexeme.index.count());
        try expectEqual(27, dictionary.by_form.index.count());

        const results2 = dictionary2.by_form.lookup("λύω");
        try expect(results2 != null);
        try expectEqual(1, results2.?.exact_accented.items.len);
        try expectEqual(0, results2.?.exact_unaccented.items.len);
        try expectEqual(0, results2.?.partial_match.items.len);
        {
            const results = dictionary2.by_gloss.lookup("sneaky");
            try expect(results != null);
            try expectEqual(1, results.?.exact_accented.items.len);
            try expectEqualStrings("δράκοντα", results.?.exact_accented.items[0].word);
            try expectEqual(0, results.?.exact_unaccented.items.len);
            try expectEqual(0, results.?.partial_match.items.len);
        }
    }
}

test "unaccented dictionary search" {
    const allocator = std.testing.allocator;
    // Test that unaccented searches return the correct result
    const dictionary = try Dictionary.create(allocator);
    defer dictionary.destroy(allocator);
    const data =
        \\λύω|el|636670|Verb|||3089|λύ|en:untie:release:loose#ru:развязывать:освобождать:разрушать#zh:解開:釋放:放開#es:desato:suelto|||
        \\  λύω|V-PAI-1S|false|855890|en:I untie:I release:I loose|
        \\  λύεις|V-PAI-2S|false|855900|en:You untie:You release|
        \\δράκων|el|279590|Noun|ὁ|-οντος|1404|δράκ|en:dragon:large serpent#ru:дракон:большой змей#zh:龍:大蛇#es:dragón:serpiente grande||animal|
        \\  δράκων|N-NSM|false|376270||byz#Revelation 12:3 11,kjtr#Revelation 12:3 10,sbl#Revelation 12:3 10
        \\  δράκοντα|N-ASM|false|376280||byz#Revelation 20:2 3,kjtr#Revelation 20:2 3
    ;
    try dictionary.loadTextData(allocator, allocator, data);
    const results = dictionary.by_form.lookup("δρακων");
    try expect(results != null);
    try expectEqual(0, results.?.exact_accented.items.len);
    try expectEqual(1, results.?.exact_unaccented.items.len);
    try expectEqual(0, results.?.partial_match.items.len);
}

test "load_count" {
    const allocator = std.testing.allocator;

    const dictionary = try Dictionary.create(allocator);
    defer dictionary.destroy(allocator);
    const data =
        \\στόμαχος|el|960190|Noun|ὁ|-ου|4751|στόμαχ|en:stomach|||
        \\  στόμαχος|N-NSM|false|1286240||
        \\  στόμαχον|N-ASM|false|1286250||byz#1 Timothy 5:23 10,kjtr#1 Timothy 5:23 9,sbl#1 Timothy 5:23 9,sr#1 Timothy 5:23 10
    ;
    try dictionary.loadTextData(allocator, allocator, data);
    try expectEqual(1, dictionary.lexemes.items.len);
    try expectEqual(2, dictionary.forms.items.len);
    try expectEqual(2, dictionary.lexemes.items[0].forms.items.len);
}

test "gloss_fallback" {
    const allocator = std.testing.allocator;

    const dictionary = try Dictionary.create(allocator);
    defer dictionary.destroy(allocator);
    const data =
        \\λύω|el|900000|Verb|||3089|λύ|en:untie:release:loose#ru:развязывать:освобождать:разрушать#zh:解開:釋放:放開#es:desato:suelto|||
        \\  λύω|V-PAI-1S|false|500000|en:I untie:I release:I loose|
        \\  λύεις|V-PAI-2S|false|500001|en:You untie:You release|
        \\  λύει|V-PAI-3S|false|52||
        \\δράκων|el|2795900|Noun|ὁ|-οντος|91|δράκ|en:dragon:large serpent#ru:дракон:большой змей#zh:龍:大蛇#es:dragón:serpiente grande||animal|
        \\  δράκων|N-NSM|false|1000050||byz#Revelation 12:3 11,kjtr#Revelation 12:3 10,sbl#Revelation 12:3 10
        \\  δράκοντα|N-ASM|false|1000051||byz#Revelation 20:2 3,kjtr#Revelation 20:2 3
    ;
    try dictionary.loadTextData(allocator, allocator, data);

    try gloss_fallback_checker(dictionary);

    // Check for memory leaks in binary loader
    var bin1: std.ArrayListUnmanaged(u8) = .empty;
    defer bin1.deinit(allocator);
    var bin2: std.ArrayListUnmanaged(u8) = .empty;
    defer bin2.deinit(allocator);
    {
        try dictionary.writeBinaryData(allocator, &bin1);
        const dictionary2 = try Dictionary.create(allocator);
        defer dictionary2.destroy(allocator);
        //try expectEqualSlices(u8, &[_]u8{}, out.items);
        try dictionary2.loadBinaryData(allocator, allocator, bin1.items);
        try dictionary2.writeBinaryData(allocator, &bin2);
    }
    try expectEqualSlices(u8, bin1.items, bin2.items);

    try gloss_fallback_checker(dictionary);
}

test "arena_check" {
    const allocator = std.testing.allocator;

    // Test that unaccented searches return the correct result
    const dictionary = try Dictionary.create(allocator);
    defer dictionary.destroy(allocator);
    const data =
        \\λύω|el|900000|Verb|||3089|λύ|en:untie:release:loose#ru:развязывать:освобождать:разрушать#zh:解開:釋放:放開#es:desato:suelto|||
        \\  λύω|V-PAI-1S|false|500000|en:I untie:I release:I loose|
        \\  λύεις|V-PAI-2S|false|500001|en:You untie:You release|
        \\  λύει|V-PAI-3S|false|500002||
        \\δράκων|el|2795900|Noun|ὁ|-οντος|91|δράκ|en:dragon:large serpent#ru:дракон:большой змей#zh:龍:大蛇#es:dragón:serpiente grande||animal|
        \\  δράκων|N-NSM|false|1000050||byz#Revelation 12:3 11,kjtr#Revelation 12:3 10,sbl#Revelation 12:3 10
        \\  δράκοντα|N-ASM|false|1000051||byz#Revelation 20:2 3,kjtr#Revelation 20:2 3
    ;
    try dictionary.loadTextData(allocator, allocator, data);

    try gloss_fallback_checker(dictionary);

    // Check for memory leaks in binary loader
    var out: std.ArrayListUnmanaged(u8) = .empty;
    defer out.deinit(allocator);
    var out2: std.ArrayListUnmanaged(u8) = .empty;
    defer out2.deinit(allocator);
    {
        try dictionary.writeBinaryData(allocator, &out);
        const dictionary2 = try Dictionary.create(allocator);
        defer dictionary2.destroy(allocator);
        //try expectEqualSlices(u8, &[_]u8{}, out.items);
        try dictionary2.loadBinaryData(allocator, allocator, out.items);
        try dictionary2.writeBinaryData(allocator, &out2);
    }
    try expectEqualSlices(u8, out.items, out2.items);

    try gloss_fallback_checker(dictionary);
}

fn gloss_fallback_checker(dictionary: *Dictionary) !void {
    {
        const results = dictionary.by_form.lookup("λυεις");
        try expect(results != null);
        try expectEqual(1, results.?.exact_unaccented.items.len);
        const form = results.?.exact_unaccented.items[0];
        try expectEqual(2, form.glosses_by_lang(Lang.english).?.glosses().len);
        try expectEqualStrings("You untie", form.glosses_by_lang(Lang.english).?.glosses()[0]);
        try expectEqualStrings("You release", form.glosses_by_lang(Lang.english).?.glosses()[1]);
    }
    {
        const results = dictionary.by_form.lookup("λύει");
        try expect(results != null);
        try expectEqual(1, results.?.exact_accented.items.len);
        const form = results.?.exact_accented.items[0];
        try expectEqual(3, form.glosses_by_lang(Lang.english).?.glosses().len);
        try expectEqualStrings("untie", form.glosses_by_lang(Lang.english).?.glosses()[0]);
        try expectEqualStrings("release", form.glosses_by_lang(Lang.english).?.glosses()[1]);
        try expectEqualStrings("loose", form.glosses_by_lang(Lang.english).?.glosses()[2]);
    }
    {
        const results = dictionary.by_form.lookup("δρακων");
        try expect(results != null);
        try expectEqual(1, results.?.exact_unaccented.items.len);
        const form = results.?.exact_unaccented.items[0];
        try expectEqual(2, form.glosses_by_lang(Lang.english).?.glosses().len);
        try expectEqualStrings("dragon", form.glosses_by_lang(Lang.english).?.glosses()[0]);
        try expectEqualStrings("large serpent", form.glosses_by_lang(Lang.english).?.glosses()[1]);
    }
}

test "dictionary_destroy" {
    const allocator = std.testing.allocator;

    // Check for memory leaks in text loader
    const dictionary = try Dictionary.create(allocator);
    defer dictionary.destroy(allocator);
    const data =
        \\λύω|el|636670|Verb|||3089|λύ|en:untie:release:loose#ru:развязывать:освобождать:разрушать#zh:解開:釋放:放開#es:desato:suelto|||
        \\  λύω|V-PAI-1S|false|855890|en:I untie:I release:I loose|
        \\  λύεις|V-PAI-2S|false|855900|en:You untie:You release|
        \\δράκων|el|279509|Noun|ὁ|-οντος|1404|δράκ|en:dragon:large serpent#ru:дракон:большой змей#zh:龍:大蛇#es:dragón:serpiente grande||animal|
        \\  δράκων|N-NSM|false|376027||byz#Revelation 12:3 11,kjtr#Revelation 12:3 10,sbl#Revelation 12:3 10
        \\  δράκοντα|N-ASM|false|376028||byz#Revelation 20:2 3,kjtr#Revelation 20:2 3
    ;
    try dictionary.loadTextData(allocator, allocator, data);

    // Check for memory leaks in binary loader
    var out: std.ArrayListUnmanaged(u8) = .empty;
    defer out.deinit(allocator);
    try dictionary.writeBinaryData(allocator, &out);
    const dictionary2 = try Dictionary.create(allocator);
    defer dictionary2.destroy(allocator);
    //try expectEqualSlices(u8, &[_]u8{}, out.items);
    try dictionary2.loadBinaryData(allocator, allocator, out.items);
}

test "dictionary_destroy1" {
    const allocator = std.testing.allocator;
    // Another check for memory leaks
    const dictionary = try Dictionary.create(allocator);
    defer dictionary.destroy(allocator);
    const data =
        \\λύω|el|636670|Verb|||3089|λύ|en:untie:hi|||
    ;
    try dictionary.loadTextData(allocator, allocator, data);
}

test "dictionary_destroy2" {
    const allocator = std.testing.allocator;
    // Another check for memory leaks
    const dictionary = try Dictionary.create(allocator);
    defer dictionary.destroy(allocator);
    const data =
        \\λύω|el|636607|Verb|||3089|λύ||||
    ;
    try dictionary.loadTextData(allocator, allocator, data);
}

test "partial dictionary search" {
    const allocator = std.testing.allocator;
    const dictionary = try Dictionary.create(allocator);
    defer dictionary.destroy(allocator);
    const data =
        \\λύω|el|636607|Verb|||3089|λύ|en:untie:release:loose#ru:развязывать:освобождать:разрушать#zh:解開:釋放:放開#es:desato:suelto|||
        \\  λύω|V-PAI-1S|false|855809|en:I untie:I release:I loose|
        \\  λύεις|V-PAI-2S|false|855900|en:You untie:You release|
        \\δράκων|el|279509|Noun|ὁ|-οντος|1404|δράκ|en:dragon:large serpent#ru:дракон:большой змей#zh:龍:大蛇#es:dragón:serpiente grande||animal|
        \\  δράκων|N-NSM|false|3760207||byz#Revelation 12:3 11,kjtr#Revelation 12:3 10,sbl#Revelation 12:3 10
        \\  δράκοντα|N-ASM|false|3700628||byz#Revelation 20:2 3,kjtr#Revelation 20:2 3
    ;
    try dictionary.loadTextData(allocator, allocator, data);
    const results = dictionary.by_form.lookup("δρα");
    try expect(results != null);
    try expectEqual(0, results.?.exact_accented.items.len);
    try expectEqual(0, results.?.exact_unaccented.items.len);
    try expectEqual(2, results.?.partial_match.items.len);
}

test "dictionary_file" {
    const allocator = std.testing.allocator;
    const dictionary = try Dictionary.create(allocator);
    defer dictionary.destroy(allocator);
    try dictionary.loadFile(allocator, "./test/small_dict.txt");
    var results = dictionary.by_form.lookup("δρα");
    try expect(results == null);
    results = dictionary.by_form.lookup("αρτο");
    try expect(results != null);
    try expectEqual(0, results.?.exact_accented.items.len);
    try expectEqual(0, results.?.exact_unaccented.items.len);
    try expectEqual(6, results.?.partial_match.items.len);
    results = dictionary.by_form.lookup("η");
    try expect(results != null);
    try expectEqual(0, results.?.exact_accented.items.len);
    try expectEqual(5, results.?.exact_unaccented.items.len);
    try expectEqual(0, results.?.partial_match.items.len);
    //std.debug.print("ordering: {d}", .{results.?.exact_unaccented.items.len});
    //for (results.?.exact_unaccented.items) |i| {
    //    std.debug.print("  {s}-{d}", .{ i.word, i.uid });
    //}
    //std.debug.print("\n", .{});
    // This is the sort order we expect based on the sample dictionary content
    //std.debug.print("order {any}\n", .{results.?.exact_unaccented.items});
    // ἤ-61577  ἤ-61580  ἦ-61583  ἦ-61584  ἤ-61576
    try expectEqual(561577, results.?.exact_unaccented.items[0].uid);
    try expectEqual(761580, results.?.exact_unaccented.items[1].uid);
    try expectEqual(6561583, results.?.exact_unaccented.items[2].uid);
    results = dictionary.by_form.lookup("εγω");
    try expect(results != null);
    try expectEqual(0, results.?.exact_accented.items.len);
    try expectEqual(2, results.?.exact_unaccented.items.len);
    try expectEqual(0, results.?.partial_match.items.len);
}

test "search" {
    const allocator = std.testing.allocator;
    const dict = try Dictionary.create(allocator);
    defer dict.destroy(allocator);
    try dict.loadFile(allocator, "./test/small_dict.txt");
    var results = dict.by_form.lookup("Δαυιδ");
    try expect(results != null);
    try expectEqual(0, results.?.exact_accented.items.len);
    try expectEqual(2, results.?.exact_unaccented.items.len);
    try expectEqual(0, results.?.partial_match.items.len);
    results = dict.by_form.lookup("δαυιδ");
    try expect(results != null);
    try expectEqual(0, results.?.exact_accented.items.len);
    try expectEqual(2, results.?.exact_unaccented.items.len);
    try expectEqual(0, results.?.partial_match.items.len);
    results = dict.by_gloss.lookup("David");
    //for (results.?.exact_accented.items) |a| {
    //    std.debug.print("found {d} {s}\n", .{ a.uid, a.word });
    //}
    try expect(results != null);
    try expectEqual(2, results.?.exact_accented.items.len);
    try expectEqual(0, results.?.exact_unaccented.items.len);
    try expectEqual(0, results.?.partial_match.items.len);
    results = dict.by_gloss.lookup("david");
    try expect(results != null);
    try expectEqual(2, results.?.exact_accented.items.len);
    try expectEqual(0, results.?.exact_unaccented.items.len);
    try expectEqual(0, results.?.partial_match.items.len);
    results = dict.by_gloss.lookup("WATER");
    try expect(results != null);
    try expectEqual(1, results.?.exact_accented.items.len);
    try expectEqual(0, results.?.exact_unaccented.items.len);
    try expectEqual(0, results.?.partial_match.items.len);
    results = dict.by_form.lookup("ὙΔΡΊΑ");
    try expect(results != null);
    try expectEqual(1, results.?.exact_accented.items.len);
    try expectEqual(0, results.?.exact_unaccented.items.len);
    try expectEqual(1, results.?.partial_match.items.len);
    results = dict.by_form.lookup("ὥρα");
    try expect(results != null);
    try expectEqual(1, results.?.exact_accented.items.len);
    try expectEqual(0, results.?.exact_unaccented.items.len);
    try expectEqual(1, results.?.partial_match.items.len);
}

test "accented_vs_unaccented" {
    const allocator = std.testing.allocator;

    const dict = try test_dictionary(allocator);
    defer dict.destroy(allocator);
    const results = dict.by_form.lookup("Δαυιδ");
    try expect(results != null);

    const results1 = dict.by_form.lookup("α");
    try expect(results1 != null);
    try expectEqual(1, results1.?.exact_accented.items.len);
    try expectEqualStrings("α", results1.?.exact_accented.items[0].word);

    const results2 = dict.by_form.lookup("ἅ");
    try expect(results2 != null);
    try expectEqual(1, results2.?.exact_accented.items.len);
    try expectEqualStrings("ἅ", results2.?.exact_accented.items[0].word);

    try expect(results1.?.exact_accented.items[0].uid != results2.?.exact_accented.items[0].uid);
}

var local_test_dictionary: ?*Dictionary = null;

fn test_dictionary(allocator: Allocator) !*Dictionary {
    if (local_test_dictionary == null) {
        const larger_dict = @embedFile("larger_dict");
        local_test_dictionary = try Dictionary.create(allocator);
        local_test_dictionary.?.loadTextData(allocator, allocator, larger_dict) catch |e| {
            debug("dictionary load failed: {any}", .{e});
            @panic("load test dictionary failed");
        };
    }
    if (local_test_dictionary == null) {
        @panic("load test dictionary failed");
    }
    return local_test_dictionary.?;
}
