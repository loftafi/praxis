//! Contain a set of `Lexeme` and lexeme `Form` objects. Search
//! for forms and glosses that start with a desired string.

pub const Dictionary = struct {
    by_lexeme: SearchIndex(*Lexeme, Lexeme.lessThan),
    by_form: SearchIndex(*Form, Form.autocompleteLessThan),
    by_gloss: SearchIndex(*Form, Form.autocompleteLessThan),
    by_transliteration: SearchIndex(*Form, Form.autocompleteLessThan),
    lexemes: ArrayList(*Lexeme),
    forms: ArrayList(*Form),
    arena: ?std.heap.ArenaAllocator = null,
    allocator: Allocator,

    pub fn create(allocator: ?Allocator) !*Dictionary {
        var dictionary: *Dictionary = undefined;

        if (allocator) |optional_allocator| {
            dictionary = try optional_allocator.create(Dictionary);
            dictionary.arena = null;
            dictionary.allocator = allocator.?;
        } else {
            var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            dictionary = try arena.allocator().create(Dictionary);
            dictionary.arena = arena;
            dictionary.allocator = dictionary.arena.?.allocator();
        }

        dictionary.by_lexeme = SearchIndex(*Lexeme, Lexeme.lessThan).init(dictionary.allocator);
        dictionary.by_form = SearchIndex(*Form, Form.autocompleteLessThan).init(dictionary.allocator);
        dictionary.by_gloss = SearchIndex(*Form, Form.autocompleteLessThan).init(dictionary.allocator);
        dictionary.by_transliteration = SearchIndex(*Form, Form.autocompleteLessThan).init(dictionary.allocator);
        dictionary.lexemes = try ArrayList(*Lexeme).initCapacity(dictionary.allocator, 180000);
        dictionary.forms = try ArrayList(*Form).initCapacity(dictionary.allocator, 180000);
        return dictionary;
    }

    pub fn destroy(self: *Dictionary) void {
        if (self.arena) |arena| {
            arena.deinit();
            return;
        }

        self.by_lexeme.deinit();
        for (self.lexemes.items) |*item| {
            item.*.destroy();
        }
        self.lexemes.deinit();

        self.by_form.deinit();
        for (self.forms.items) |*item| {
            item.*.destroy();
        }
        self.forms.deinit();

        self.by_gloss.deinit();
        self.by_transliteration.deinit();
        self.allocator.destroy(self);
    }

    /// Load dictionary data. Detect if the data is text or binary format.
    /// See `load_text_data()` and `load_binary_data()` for details.
    pub fn load_file(self: *Dictionary, filename: []const u8) !void {
        var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer temp_arena.deinit();

        const data = read_bytes_from_file(filename, temp_arena.allocator()) catch {
            std.debug.print("Could not read {s}\n", .{filename});
            return;
        };

        if (data.len > 10 and data[0] == 99 and data[1] == 1) {
            try self.load_binary_data(data, temp_arena.allocator());
        } else {
            try self.load_text_data(data, temp_arena.allocator());
        }
    }

    /// Load dictionary data that has been stored in a
    /// user readable text format.
    pub fn load_text_data(self: *Dictionary, content: []const u8, temp_allocator: std.mem.Allocator) !void {

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
                var lexeme = try Lexeme.create(self.allocator);
                errdefer lexeme.destroy();
                lexeme.read_text(&data) catch |e| {
                    std.debug.print("failed reading line: {any}. Error: {any}\n", .{ line, e });
                    lexeme.destroy();
                    return e;
                };
                if (lexeme.word.len == 0) {
                    std.debug.print("missing lexeme word field on line: {any}\n", .{line});
                    lexeme.destroy();
                    break;
                }
                current_lexeme = lexeme;
                try self.lexemes.append(lexeme);
                try self.by_lexeme.add(lexeme.word, lexeme);
                if (lexeme.uid == 0) {
                    try lexeme_needs_uid.append(lexeme);
                } else {
                    try lexeme_uid.put(lexeme.uid, lexeme);
                    if (lexeme.uid > max_lexeme_uid) {
                        max_lexeme_uid = lexeme.uid;
                    }
                }
            } else {
                var form = try Form.create(self.allocator);
                errdefer form.destroy();
                form.read_text(&data) catch |e| {
                    std.debug.print("failed reading line: {any}. Error: {any}\n", .{ line, e });
                    return e;
                };
                if (form.word.len == 0) {
                    std.debug.print("missing form word field on line: {any}\n", .{line});
                    form.destroy();
                    break;
                }
                try self.forms.append(form);
                try self.by_form.add(form.word, form);
                if (current_lexeme != null) {
                    form.lexeme = current_lexeme.?;
                    try current_lexeme.?.forms.append(form);
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
            //std.debug.print("reading line: {d} lexemes={d} forms={d}\n", .{ data.line, self.lexemes.items.len, self.forms.items.len });
        }

        // Build a search index of transliterated version of the words.
        var buffer: [500]u8 = undefined;
        for (self.forms.items) |form| {
            if (form.word.len == 0) {
                continue;
            }
            const transliterated = transliterate_word(form.word, false, &buffer) catch |e| {
                log.warn("Transliteration of {s} failed: {any}", .{
                    form.word,
                    e,
                });
                continue;
            };
            if (transliterated.len == 0) {
                log.warn("Transliteration of {s} returned {s}", .{
                    form.word,
                    transliterated,
                });
            }
            try self.by_gloss.add(transliterated, form);
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
                            try self.by_gloss.add(lower, lexeme.forms.items[0]);
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
                                    try self.by_gloss.add(text, form);
                                }
                            }
                        }
                    }
                }
            }
        }

        try self.sort_search_results();

        if (lexeme_needs_uid.items.len > 0) {
            log.debug("{d} lexemes need uid.", .{lexeme_needs_uid.items.len});
            //TODO fix
        }
        if (form_needs_uid.items.len > 0) {
            log.debug("{d} forms need uid.", .{form_needs_uid.items.len});
            //TODO fix
        }

        log.debug("Loaded dictionary.", .{});
        return;
    }

    /// Save all dictionary data, along with a pre-built
    /// search index into an on disk data file.
    pub fn save_binary_file(self: *const Dictionary, filename: []const u8, temp_allocator: std.mem.Allocator) !void {
        var data = ArrayList(u8).init(temp_allocator);
        defer data.deinit();
        try self.save_binary_data(&data);
        std.debug.print("binary data size: {any}\n", .{data.items.len});
        try write_bytes_to_file(data.items, filename);
    }

    /// Save all dictionary data, along with a pre-built
    /// search index into a byte array.
    pub fn save_binary_data(self: *const Dictionary, data: *std.ArrayList(u8)) !void {
        try data.append(99);
        try data.append(1);

        // Placeholder for word count. We don't yet know how many
        // words have data for inclusion.
        var include_words: u32 = 0;
        try data.append(0);
        try data.append(0);
        try data.append(0);
        try data.append(0);
        //try append_u32(data, @intCast(self.lexemes.items.len));

        for (self.lexemes.items) |*lexeme| {
            //if (lexeme.forms.items.len == 0) {
            //    continue;
            //}
            //if (lexeme.glosses.items.len == 0) {
            //    continue;
            //}
            include_words += 1;
            try lexeme.*.write_binary(data);
            try append_u16(data, @intCast(lexeme.*.forms.items.len));
            for (lexeme.*.forms.items) |*form| {
                try form.*.write_binary(data);
            }
        }
        try data.append(FS);
        data.items[2] = (@intCast(include_words & 0xff));
        data.items[3] = (@intCast((include_words >> 8) & 0xff));
        data.items[4] = (@intCast((include_words >> 16) & 0xff));
        data.items[5] = (@intCast((include_words >> 24) & 0xff));

        // Now output the search indexes
        try self.by_form.write_binary_bytes(data);
        try data.append(FS);

        try self.by_gloss.write_binary_bytes(data);
        try data.append(FS);

        try self.by_transliteration.write_binary_bytes(data);
        try data.append(FS);
    }

    /// Load dictionary data that has been stored in
    /// condensed binary format along with a pre-built
    /// search index.
    pub fn load_binary_data(self: *Dictionary, content: []const u8, temp_allocator: std.mem.Allocator) !void {
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
        try self.lexemes.ensureTotalCapacity(count);
        try self.forms.ensureTotalCapacity(count);

        // Read all lexemes with associated forms
        for (0..count) |i| {
            var lexeme = try Lexeme.create(self.allocator);
            errdefer lexeme.destroy();
            lexeme.read_binary(&data) catch |e| {
                std.debug.print("failed reading word {any} at byte index: {any}. Error: {any}\n", .{ i, data.index, e });
                if (i > 0) {
                    std.debug.print("previous word had uid {d}\n", .{self.lexemes.items[i - 1].uid});
                    std.debug.print("processing word {d} of {d}\n", .{ i, count });
                }
                std.debug.print(" buffer: {any} -{d}- {any}\n", .{
                    data.leading_slice(10),
                    data.peek(),
                    data.following_slice(10),
                });
                return e;
            };
            try self.lexemes.append(lexeme);

            // Any forms discovered while reading lexeme should
            // appear in the form index.
            for (lexeme.forms.items) |*f| {
                try form_uid.put(f.*.uid, f.*);
                try self.forms.append(f.*);
            }
            //if (data.next() != RS) {
            //    return error.InvalidDictionaryFile;
            //}
        }
        if (try data.u8() != FS) {
            return error.InvalidDictionaryFile;
        }

        // Read all search index data
        try self.by_form.load_binary_data(&data, &form_uid);
        if (try data.u8() != FS) {
            return error.InvalidDictionaryFile;
        }

        try self.by_gloss.load_binary_data(&data, &form_uid);
        if (try data.u8() != FS) {
            return error.InvalidDictionaryFile;
        }

        try self.by_transliteration.load_binary_data(&data, &form_uid);
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
    pub fn save_text_file(self: *const Dictionary, filename: []const u8, temp_allocator: std.mem.Allocator) !void {
        var data = ArrayList(u8).init(temp_allocator);
        defer data.deinit();
        try self.save_text_data(&data);
        std.debug.print("text data size: {any}\n", .{data.items.len});
        try write_bytes_to_file(data.items, filename);
    }

    /// Export the entire dictionary contents into a byte arra
    /// that can then be saved to disk or another location.
    pub fn save_text_data(self: *const Dictionary, data: *ArrayList(u8)) !void {
        var buf: [50]u8 = undefined;
        for (self.lexemes.items) |lexeme| {
            const uid = try std.fmt.bufPrint(&buf, "{}", .{lexeme.uid});
            try data.appendSlice(lexeme.word);
            try data.append('|');
            try data.appendSlice(lexeme.lang.to_code());
            try data.append('|');
            try data.appendSlice(lexeme.alt);
            try data.append('|');
            try data.appendSlice(uid);
            try data.append('|');
            for (lexeme.strongs.items, 0..) |sn, i| {
                if (i > 0) {
                    try data.append(',');
                }
                const value = try std.fmt.bufPrint(&buf, "{}", .{sn});
                try data.appendSlice(value);
            }
            try data.append('|');
            try data.appendSlice(lexeme.article.articles()); // M, F, M/F...
            try data.append('|');
            try data.appendSlice(pos.english_camel_case(lexeme.pos));
            try data.append('|');
            try data.appendSlice(lexeme.genitiveSuffix);
            try data.append('|');
            try data.appendSlice(lexeme.root);
            // root
            try data.append('|');
            for (lexeme.glosses.items, 0..) |gloss, i| {
                if (i > 0) {
                    try data.append('#');
                }
                try data.appendSlice(gloss.lang.to_code());
                for (gloss.glosses()) |item| {
                    try data.append(':');
                    try data.appendSlice(item);
                }
            }
            try data.append('|');
            try data.appendSlice(lexeme.adjective);
            try data.append('|');
            if (lexeme.tags) |tags| {
                for (tags, 0..) |tag, i| {
                    if (i > 0) {
                        try data.appendSlice(", ");
                    }
                    try data.appendSlice(tag);
                }
            }
            try data.append('|');
            for (lexeme.forms.items) |form| {
                try data.append(LF);
                try data.appendSlice("  ");
                try data.appendSlice(form.word);
                try data.append('|');
                try form.parsing.string(data);
                try data.append('|');
                if (form.preferred) {
                    try data.appendSlice("true");
                } else {
                    try data.appendSlice("false");
                }
                try data.append('|');
                const formUid = try std.fmt.bufPrint(&buf, "{}", .{form.uid});
                try data.appendSlice(formUid);
                try data.append('|');
                for (form.glosses.items, 0..) |*gloss, i| {
                    if (i > 0) {
                        try data.append('#');
                    }
                    try data.appendSlice(gloss.*.lang.to_code());
                    for (gloss.*.glosses()) |item| {
                        try data.append(':');
                        try data.appendSlice(item);
                    }
                }
                try data.append('|');
                // References into linked modules
                for (form.references.items, 0..) |*reference, i| {
                    if (i > 0) {
                        try data.append(',');
                    }
                    try data.appendSlice(reference.*.module.info().code);
                    try data.append('#');
                    try data.appendSlice(reference.*.book.info().english);
                    try data.append(' ');
                    try data.appendSlice(try std.fmt.bufPrint(&buf, "{}", .{reference.*.chapter}));
                    try data.append(':');
                    try data.appendSlice(try std.fmt.bufPrint(&buf, "{}", .{reference.*.verse}));
                    if (reference.word > 0) {
                        try data.append(' ');
                        try data.appendSlice(try std.fmt.bufPrint(&buf, "{}", .{reference.*.word}));
                    }
                }
            }
            try data.append(LF);
        }
    }
};

/// Helper function to read file contents.
fn read_bytes_from_file(filename: []const u8, temp_allocator: std.mem.Allocator) ![]u8 {
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

pub inline fn append_u16(data: *std.ArrayList(u8), value: u32) !void {
    std.debug.assert(value <= 0xffff);
    try data.append(@intCast(value & 0xff));
    try data.append(@intCast((value >> 8) & 0xff));
}

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
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
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

const eql = @import("std").mem.eql;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualDeep = std.testing.expectEqualDeep;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqualSlices = std.testing.expectEqualSlices;

test "basic_dictionary" {
    // Do some basic black box testing on a short simple dictionary file.
    const dictionary = try Dictionary.create(std.testing.allocator);
    defer dictionary.destroy();

    const data =
        \\δράκων|el||80000|1404|ὁ|Noun|-οντος|δράκ|en:dragon:large serpent#ru:дракон:большой змей#zh:龍:大蛇#es:dragón:serpiente grande||animal|
        \\  δράκων|N-NSM|false|70000||byz#Revelation 12:3 11,kjtr#Revelation 12:3 10,sbl#Revelation 12:3 10
        \\  δράκοντα|N-ASM|false|70001|en:the sneaky|byz#Revelation 20:2 3,kjtr#Revelation 20:2 3
        \\λύω|el||80001|3089||Verb||λύ|en:untie:release:loose#ru:развязывать:освобождать:разрушать#zh:解開:釋放:放開#es:desato:suelto|||
        \\  λύω|V-PAI-1S|false|70002|en:I untie:I release:I loose|
        \\  λύεις|V-PAI-2S|false|70003|en:You untie:You release|
        \\  λύει|V-PAI-3S|false|70004|en:You untie:You release|
        \\
    ;

    try dictionary.load_text_data(data, std.testing.allocator);

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
        var out = std.ArrayList(u8).init(std.testing.allocator);
        defer out.deinit();
        try dictionary.save_text_data(&out);
        try expectEqualDeep(data, out.items);
    }

    // Test basic binary saving works correctly
    {
        var out = std.ArrayList(u8).init(std.testing.allocator);
        defer out.deinit();
        try dictionary.save_binary_data(&out);

        const header: []const u8 = &.{ 99, 1, 2, 0, 0, 0 };
        try expect(out.items.len > 50);
        try expectEqualSlices(u8, header, out.items[0..header.len]);

        const dictionary2 = try Dictionary.create(std.testing.allocator);
        defer dictionary2.destroy();
        //try expectEqualSlices(u8, &[_]u8{}, out.items);
        try dictionary2.load_binary_data(out.items, std.testing.allocator);

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
    // Test that unaccented searches return the correct result
    const dictionary = try Dictionary.create(std.testing.allocator);
    defer dictionary.destroy();
    const data =
        \\λύω|el||63667|3089||Verb||λύ|en:untie:release:loose#ru:развязывать:освобождать:разрушать#zh:解開:釋放:放開#es:desato:suelto|||
        \\  λύω|V-PAI-1S|false|85589|en:I untie:I release:I loose|
        \\  λύεις|V-PAI-2S|false|85590|en:You untie:You release|
        \\δράκων|el||27959|1404|ὁ|Noun|-οντος|δράκ|en:dragon:large serpent#ru:дракон:большой змей#zh:龍:大蛇#es:dragón:serpiente grande||animal|
        \\  δράκων|N-NSM|false|37627||byz#Revelation 12:3 11,kjtr#Revelation 12:3 10,sbl#Revelation 12:3 10
        \\  δράκοντα|N-ASM|false|37628||byz#Revelation 20:2 3,kjtr#Revelation 20:2 3
    ;
    try dictionary.load_text_data(data, std.testing.allocator);
    const results = dictionary.by_form.lookup("δρακων");
    try expect(results != null);
    try expectEqual(0, results.?.exact_accented.items.len);
    try expectEqual(1, results.?.exact_unaccented.items.len);
    try expectEqual(0, results.?.partial_match.items.len);
}

test "load_count" {
    const dictionary = try Dictionary.create(std.testing.allocator);
    defer dictionary.destroy();
    const data =
        \\στόμαχος|el||96019|4751|ὁ|Noun|-ου|στόμαχ|en:stomach|||
        \\  στόμαχος|N-NSM|false|128624||
        \\  στόμαχον|N-ASM|false|128625||byz#1 Timothy 5:23 10,kjtr#1 Timothy 5:23 9,sbl#1 Timothy 5:23 9,sr#1 Timothy 5:23 10
    ;
    try dictionary.load_text_data(data, std.testing.allocator);
    try expectEqual(1, dictionary.lexemes.items.len);
    try expectEqual(2, dictionary.forms.items.len);
    try expectEqual(2, dictionary.lexemes.items[0].forms.items.len);
}

test "gloss_fallback" {
    const dictionary = try Dictionary.create(std.testing.allocator);
    defer dictionary.destroy();
    const data =
        \\λύω|el||90|3089||Verb||λύ|en:untie:release:loose#ru:развязывать:освобождать:разрушать#zh:解開:釋放:放開#es:desato:suelto|||
        \\  λύω|V-PAI-1S|false|50|en:I untie:I release:I loose|
        \\  λύεις|V-PAI-2S|false|51|en:You untie:You release|
        \\  λύει|V-PAI-3S|false|52||
        \\δράκων|el||27959|91|ὁ|Noun|-οντος|δράκ|en:dragon:large serpent#ru:дракон:большой змей#zh:龍:大蛇#es:dragón:serpiente grande||animal|
        \\  δράκων|N-NSM|false|150||byz#Revelation 12:3 11,kjtr#Revelation 12:3 10,sbl#Revelation 12:3 10
        \\  δράκοντα|N-ASM|false|151||byz#Revelation 20:2 3,kjtr#Revelation 20:2 3
    ;
    try dictionary.load_text_data(data, std.testing.allocator);

    try gloss_fallback_checker(dictionary);

    // Check for memory leaks in binary loader
    var bin1 = std.ArrayList(u8).init(std.testing.allocator);
    defer bin1.deinit();
    var bin2 = std.ArrayList(u8).init(std.testing.allocator);
    defer bin2.deinit();
    {
        try dictionary.save_binary_data(&bin1);
        const dictionary2 = try Dictionary.create(std.testing.allocator);
        defer dictionary2.destroy();
        //try expectEqualSlices(u8, &[_]u8{}, out.items);
        try dictionary2.load_binary_data(bin1.items, std.testing.allocator);
        try dictionary2.save_binary_data(&bin2);
    }
    try expectEqualSlices(u8, bin1.items, bin2.items);

    try gloss_fallback_checker(dictionary);
}

test "arena_check" {
    // Test that unaccented searches return the correct result
    const dictionary = try Dictionary.create(null);
    defer dictionary.destroy();
    const data =
        \\λύω|el||90|3089||Verb||λύ|en:untie:release:loose#ru:развязывать:освобождать:разрушать#zh:解開:釋放:放開#es:desato:suelto|||
        \\  λύω|V-PAI-1S|false|50|en:I untie:I release:I loose|
        \\  λύεις|V-PAI-2S|false|51|en:You untie:You release|
        \\  λύει|V-PAI-3S|false|52||
        \\δράκων|el||27959|91|ὁ|Noun|-οντος|δράκ|en:dragon:large serpent#ru:дракон:большой змей#zh:龍:大蛇#es:dragón:serpiente grande||animal|
        \\  δράκων|N-NSM|false|150||byz#Revelation 12:3 11,kjtr#Revelation 12:3 10,sbl#Revelation 12:3 10
        \\  δράκοντα|N-ASM|false|151||byz#Revelation 20:2 3,kjtr#Revelation 20:2 3
    ;
    try dictionary.load_text_data(data, std.testing.allocator);

    try gloss_fallback_checker(dictionary);

    // Check for memory leaks in binary loader
    var out = std.ArrayList(u8).init(std.testing.allocator);
    defer out.deinit();
    var out2 = std.ArrayList(u8).init(std.testing.allocator);
    defer out2.deinit();
    {
        try dictionary.save_binary_data(&out);
        const dictionary2 = try Dictionary.create(null);
        defer dictionary2.destroy();
        //try expectEqualSlices(u8, &[_]u8{}, out.items);
        try dictionary2.load_binary_data(out.items, std.testing.allocator);
        try dictionary2.save_binary_data(&out2);
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
    // Check for memory leaks in text loader
    const dictionary = try Dictionary.create(std.testing.allocator);
    defer dictionary.destroy();
    const data =
        \\λύω|el||63667|3089||Verb||λύ|en:untie:release:loose#ru:развязывать:освобождать:разрушать#zh:解開:釋放:放開#es:desato:suelto|||
        \\  λύω|V-PAI-1S|false|85589|en:I untie:I release:I loose|
        \\  λύεις|V-PAI-2S|false|85590|en:You untie:You release|
        \\δράκων|el||27959|1404|ὁ|Noun|-οντος|δράκ|en:dragon:large serpent#ru:дракон:большой змей#zh:龍:大蛇#es:dragón:serpiente grande||animal|
        \\  δράκων|N-NSM|false|37627||byz#Revelation 12:3 11,kjtr#Revelation 12:3 10,sbl#Revelation 12:3 10
        \\  δράκοντα|N-ASM|false|37628||byz#Revelation 20:2 3,kjtr#Revelation 20:2 3
    ;
    try dictionary.load_text_data(data, std.testing.allocator);

    // Check for memory leaks in binary loader
    var out = std.ArrayList(u8).init(std.testing.allocator);
    defer out.deinit();
    try dictionary.save_binary_data(&out);
    const dictionary2 = try Dictionary.create(std.testing.allocator);
    defer dictionary2.destroy();
    //try expectEqualSlices(u8, &[_]u8{}, out.items);
    try dictionary2.load_binary_data(out.items, std.testing.allocator);
}

test "dictionary_destroy1" {
    // Another check for memory leaks
    const dictionary = try Dictionary.create(std.testing.allocator);
    defer dictionary.destroy();
    const data =
        \\λύω|el||63667|3089||Verb||λύ|en:untie:hi|||
    ;
    try dictionary.load_text_data(data, std.testing.allocator);
}

test "dictionary_destroy2" {
    // Another check for memory leaks
    const dictionary = try Dictionary.create(std.testing.allocator);
    defer dictionary.destroy();
    const data =
        \\λύω|el||63667|3089||Verb||λύ||||
    ;
    try dictionary.load_text_data(data, std.testing.allocator);
}

test "partial dictionary search" {
    const dictionary = try Dictionary.create(std.testing.allocator);
    defer dictionary.destroy();
    const data =
        \\λύω|el||63667|3089||Verb||λύ|en:untie:release:loose#ru:развязывать:освобождать:разрушать#zh:解開:釋放:放開#es:desato:suelto|||
        \\  λύω|V-PAI-1S|false|85589|en:I untie:I release:I loose|
        \\  λύεις|V-PAI-2S|false|85590|en:You untie:You release|
        \\δράκων|el||27959|1404|ὁ|Noun|-οντος|δράκ|en:dragon:large serpent#ru:дракон:большой змей#zh:龍:大蛇#es:dragón:serpiente grande||animal|
        \\  δράκων|N-NSM|false|37627||byz#Revelation 12:3 11,kjtr#Revelation 12:3 10,sbl#Revelation 12:3 10
        \\  δράκοντα|N-ASM|false|37628||byz#Revelation 20:2 3,kjtr#Revelation 20:2 3
    ;
    try dictionary.load_text_data(data, std.testing.allocator);
    const results = dictionary.by_form.lookup("δρα");
    try expect(results != null);
    try expectEqual(0, results.?.exact_accented.items.len);
    try expectEqual(0, results.?.exact_unaccented.items.len);
    try expectEqual(2, results.?.partial_match.items.len);
}

test "dictionary_file" {
    const dictionary = try Dictionary.create(std.testing.allocator);
    defer dictionary.destroy();
    try dictionary.load_file("./test/small_dict.txt");
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
    try expectEqual(61577, results.?.exact_unaccented.items[0].uid);
    try expectEqual(61580, results.?.exact_unaccented.items[1].uid);
    try expectEqual(61583, results.?.exact_unaccented.items[2].uid);
    results = dictionary.by_form.lookup("εγω");
    try expect(results != null);
    try expectEqual(0, results.?.exact_accented.items.len);
    try expectEqual(2, results.?.exact_unaccented.items.len);
    try expectEqual(0, results.?.partial_match.items.len);
}

test "search" {
    const dict = try Dictionary.create(std.testing.allocator);
    defer dict.destroy();
    try dict.load_file("./test/small_dict.txt");
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
    const dict = try test_dictionary();
    defer dict.destroy();
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
fn test_dictionary() !*Dictionary {
    if (local_test_dictionary == null) {
        const larger_dict = @embedFile("larger_dict");
        local_test_dictionary = try Dictionary.create(std.testing.allocator);
        local_test_dictionary.?.load_text_data(larger_dict, std.testing.allocator) catch |e| {
            std.debug.print("dictionary load failed: {any}", .{e});
            @panic("load test dictionary failed");
        };
    }
    if (local_test_dictionary == null) {
        @panic("load test dictionary failed");
    }
    return local_test_dictionary.?;
}
