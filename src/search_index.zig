//! Hold a collection of `lexeme` or `form` objects keyed to a
//! string. Searching for a `lexeme` or `form` using an exact or partial string match.

pub const max_word_size = 500;
const max_index_keyword_size = 50;
const max_search_results = 60;

pub const IndexError = error{ WordTooLong, EmptyWord };

/// A wrapper for a HashMap that allows searching for prefixes of the key.
pub fn SearchIndex(comptime T: type, cmp: fn (?[]const u8, T, T) bool) type {
    return struct {
        const Self = @This();

        /// Map a search `keyword` string to a `SearchResult` record.
        index: std.HashMapUnmanaged([]const u8, *SearchResult, farmhash.FarmHashContext, std.hash_map.default_max_load_percentage) = .empty,

        /// Holds allocated copies of each `keyword` in the `index`.
        slices: ArrayListUnmanaged([]const u8),

        pub const empty: Self = .{
            .index = .empty,
            .slices = .empty,
        };

        /// `deinit` is required if do not use an arena allocator.
        pub fn deinit(self: *Self, allocator: Allocator) void {
            var i = self.index.iterator();
            while (i.next()) |item| {
                allocator.free(item.key_ptr.*);
                item.value_ptr.*.destroy(allocator);
            }
            self.slices.deinit(allocator);
            self.index.deinit(allocator);
        }

        /// The key is cloned and owned, the value is neither cloned nor owned.
        pub fn add(
            self: *Self,
            allocator: Allocator,
            word: []const u8,
            form: T,
        ) error{
            OutOfMemory,
            WordTooLong,
            EmptyWord,
            InvalidUtf8,
        }!void {
            if (word.len >= max_word_size) {
                std.debug.print("Word {s} too long for index.", .{word});
                return IndexError.WordTooLong;
            }
            if (word.len == 0) {
                return IndexError.EmptyWord;
            }

            self.slices.clearRetainingCapacity();
            var unaccented_word = BoundedArray(u8, max_word_size){};
            var normalised_word = BoundedArray(u8, max_word_size){};
            try keywordify(allocator, word, &unaccented_word, &normalised_word, &self.slices);

            var result = try self.getOrCreateSearchResult(
                allocator,
                normalised_word.slice(),
            );
            try result.exact_accented.append(allocator, form);

            if (!std.mem.eql(u8, normalised_word.slice(), unaccented_word.slice())) {
                result = try self.getOrCreateSearchResult(
                    allocator,
                    unaccented_word.slice(),
                );
                try result.exact_unaccented.append(allocator, form);
            }

            for (self.slices.items) |substring| {
                if (is_stopword(substring)) {
                    continue;
                }
                result = try self.getOrCreateSearchResult(allocator, substring);
                try result.partial_match.append(allocator, form);
            }
        }

        /// Return a `SearchResult` record corresponding to a search `keyword`.
        inline fn getOrCreateSearchResult(
            self: *Self,
            allocator: Allocator,
            keyword: []const u8,
        ) error{OutOfMemory}!*SearchResult {
            const result = try self.index.getOrPut(allocator, keyword);
            if (result.found_existing) {
                return result.value_ptr.*;
            }
            const key = try allocator.dupe(u8, keyword);
            errdefer allocator.free(key);
            result.key_ptr.* = key; // Is this right?
            result.value_ptr.* = try SearchResult.create(allocator, key);
            return result.value_ptr.*;
        }

        pub fn lookup(self: *Self, word: []const u8) (error{NormalisationFailed})!?*SearchResult {
            if (word.len >= max_word_size) {
                // If search word is too long, it definitely
                // is not in the search result.
                return null;
            }

            var unaccented_word = BoundedArray(u8, max_word_size){};
            var normalised_word = BoundedArray(u8, max_word_size){};
            normalise_word(word, &unaccented_word, &normalised_word) catch |e| {
                // If normalisation fails due to invalid utf8 encoding
                // then we know this query has no results.
                //
                // Theoretically strange unicode issues could cause an
                // out of memory error, but again this is an invalid
                // search query.
                std.log.err("normalisation failed: {any}", .{e});
                return error.NormalisationFailed;
            };

            const result = self.index.get(normalised_word.slice());
            if (result != null) {
                return result;
            }

            return self.index.get(unaccented_word.slice());
        }

        /// Sort search results to most likely matches and throw
        /// away anything over max_search_results search results.
        pub fn sort(self: *Self) !void {
            var i = self.index.valueIterator();
            while (i.next()) |sr| {
                std.mem.sort(T, sr.*.exact_accented.items, @as(?[]const u8, sr.*.keyword), cmp);
                std.mem.sort(T, sr.*.exact_unaccented.items, @as(?[]const u8, sr.*.keyword), cmp);
                std.mem.sort(T, sr.*.partial_match.items, @as(?[]const u8, sr.*.keyword), cmp);
            }
        }

        /// Write out each search index in alphabetical order. Alphabetical order
        /// results in a stable order of data in the binary file.
        ///
        /// Each search index entry must be sorted with `sort()` before saving index data.
        pub fn writeBinaryBytes(
            self: *const Self,
            allocator: Allocator,
            data: *std.Io.Writer,
        ) (std.Io.Writer.Error || error{ OutOfMemory, IndexTooLarge })!void {
            var unsorted: std.ArrayListUnmanaged([]const u8) = .empty;
            defer unsorted.deinit(allocator);
            try unsorted.ensureTotalCapacityPrecise(allocator, self.index.size);

            // Create a sorted list of the indexes
            var walk = self.index.iterator();
            while (walk.next()) |i| {
                try unsorted.append(allocator, i.key_ptr.*);
            }
            std.mem.sort([]const u8, unsorted.items, {}, stringLessThan);

            // Output the sorted list
            try append_u32(data, self.index.count());
            for (unsorted.items) |key| {
                try self.index.get(key).?.writeBinaryBytes(data);
            }
        }

        pub fn loadBinaryData(
            self: *Self,
            allocator: Allocator,
            data: *BinaryReader,
            uids: *std.AutoHashMap(u24, T),
        ) error{ OutOfMemory, InvalidIndexFile, unexpected_eof }!void {
            const indexes = try data.u32();
            for (0..indexes) |_| {
                const keyword = data.string() catch return error.InvalidIndexFile;
                const value = try allocator.alloc(u8, keyword.len);
                @memcpy(value, keyword);
                const results = try SearchResult.create(allocator, value);
                try self.index.put(allocator, value, results);
                var size = try data.u8();
                try results.exact_accented.ensureTotalCapacityPrecise(allocator, size);
                for (0..size) |_| {
                    const uid = try data.u24();
                    if (uids.get(uid)) |item| {
                        results.exact_accented.appendAssumeCapacity(item);
                    } else {
                        std.debug.print("Missing record search index uid {d}\n", .{uid});
                    }
                }
                size = try data.u8();
                try results.exact_unaccented.ensureTotalCapacityPrecise(allocator, size);
                for (0..size) |_| {
                    const uid = try data.u24();
                    if (uids.get(uid)) |item| {
                        results.exact_unaccented.appendAssumeCapacity(item);
                    } else {
                        std.debug.print("Missing record search index uid {d}\n", .{uid});
                    }
                }
                size = try data.u8();
                try results.partial_match.ensureTotalCapacityPrecise(allocator, size);
                for (0..size) |_| {
                    const uid = try data.u24();
                    if (uids.get(uid)) |item| {
                        results.partial_match.appendAssumeCapacity(item);
                    } else {
                        std.debug.print("Missing record search index uid {d}\n", .{uid});
                    }
                }
            }
        }

        pub const SearchResult = struct {
            keyword: []const u8,

            /// Exact matches with accents.
            exact_accented: ArrayListUnmanaged(T),

            /// Exact matches without accents.
            exact_unaccented: ArrayListUnmanaged(T),

            /// Unaccented prefix matches, most common words first.
            partial_match: ArrayListUnmanaged(T),

            pub const Iterator = struct {
                const SI = @This();
                results: *SearchResult,
                i: usize,
                j: usize,
                k: usize,

                pub fn next(si: *SI) ?T {
                    if (si.i < si.results.exact_accented.items.len) {
                        const entry = si.results.exact_accented.items[si.i];
                        si.i += 1;
                        return entry;
                    }
                    if (si.j < si.results.exact_unaccented.items.len) {
                        const entry = si.results.exact_unaccented.items[si.j];
                        si.j += 1;
                        return entry;
                    }
                    if (si.k < si.results.partial_match.items.len) {
                        const entry = si.results.partial_match.items[si.k];
                        si.k += 1;
                        return entry;
                    }
                    return null;
                }
            };

            pub fn iterator(self: *SearchResult) Iterator {
                return .{
                    .results = self,
                    .i = 0,
                    .j = 0,
                    .k = 0,
                };
            }

            pub fn create(allocator: Allocator, word: []const u8) error{OutOfMemory}!*SearchResult {
                const sr = try allocator.create(SearchResult);
                sr.* = SearchResult.init(word);
                return sr;
            }

            pub fn init(word: []const u8) SearchResult {
                return .{
                    .keyword = word,
                    .exact_accented = .empty,
                    .exact_unaccented = .empty,
                    .partial_match = .empty,
                };
            }

            pub fn destroy(self: *SearchResult, allocator: Allocator) void {
                self.exact_accented.deinit(allocator);
                self.exact_unaccented.deinit(allocator);
                self.partial_match.deinit(allocator);
                allocator.destroy(self);
            }

            /// Write contents of this `SearchIndex` to the `data`
            /// array. Use `sort()` before saving index data.
            pub fn writeBinaryBytes(
                self: *SearchResult,
                data: *std.Io.Writer,
            ) (std.Io.Writer.Error || error{ OutOfMemory, IndexTooLarge })!void {
                std.debug.assert(max_search_results <= 0xff);

                try data.writeAll(self.keyword);
                try data.writeByte(US);

                var count: usize = @min(self.exact_accented.items.len, max_search_results);
                if (count > 0xff) {
                    log.err("Keyword {s} has too many results. {d} > 256", .{ self.keyword, self.exact_accented.items.len });
                    return error.IndexTooLarge;
                }
                try data.writeByte(@intCast(count));
                for (self.exact_accented.items, 0..) |g, i| {
                    if (i == count) break;
                    if (g.uid > 0xffffff) return error.UidTooLarge;
                    try append_u24(data, @intCast(g.uid));
                }

                count = @min(self.exact_unaccented.items.len, max_search_results);
                if (count > 0xff) {
                    log.err("Keyword {s} has too many results. {d} > 256", .{ self.keyword, self.exact_unaccented.items.len });
                    return error.IndexTooLarge;
                }
                try data.writeByte(@intCast(count));
                for (self.exact_unaccented.items, 0..) |g, i| {
                    if (i == count) break;
                    if (g.uid > 0xffffff) return error.UidTooLarge;
                    try append_u24(data, @intCast(g.uid));
                }

                count = @min(self.partial_match.items.len, max_search_results);
                if (count > 0xff) {
                    log.err("Keyword {s} has too many results. {d} > 256", .{ self.keyword, self.partial_match.items.len });
                    return error.IndexTooLarge;
                }
                try data.writeByte(@intCast(count));
                for (self.partial_match.items, 0..) |g, i| {
                    if (i == count) break;
                    if (g.uid > 0xffffff) return error.UidTooLarge;
                    try append_u24(data, @intCast(g.uid));
                }
            }
        };
    };
}

/// Normalise is used to standardize a keyword into the format
/// it would appear if it exists inside the search index.
///
///  - The unaccented version removes all accents and breathings.
///  - The normalised removes only excess accents and standarises the final letter.
///
pub fn normalise_word(
    word: []const u8,
    unaccented: *BoundedArray(u8, max_word_size),
    normalised: *BoundedArray(u8, max_word_size),
) (error{ InvalidUtf8, Overflow } || Allocator.Error || IndexError)!void {
    if (word.len >= max_word_size) return IndexError.WordTooLong;

    var view = std.unicode.Utf8View.init(word) catch |e| {
        if (e == error.InvalidUtf8) {
            std.debug.print("normalise_word on invalid unicode. {s} -- {any}\n", .{ word, word });
        }
        return e;
    };

    // Only one accent per normalised word
    var saw_accent = false;
    var i = view.iterator();

    while (i.nextCodepointSlice()) |slice| {
        const c = std.unicode.utf8Decode(slice) catch {
            return error.InvalidUtf8;
        };
        if (c == ' ' or c == '\t') saw_accent = false;

        // Build unaccented version
        const d = unaccent(c);
        if (d) |s| {
            try unaccented.appendSlice(s);
        } else if (lowercase(c)) |lc| {
            try unaccented.appendSlice(lc);
        } else {
            try unaccented.appendSlice(slice);
        }

        // Build normalised version
        if (remove_accent(c)) |rm| {
            if (saw_accent) {
                try normalised.appendSlice(rm);
            } else if (lowercase(c)) |lc| {
                try normalised.appendSlice(lc);
            } else {
                saw_accent = true;
                if (fix_grave(c)) |fixed|
                    try normalised.appendSlice(fixed)
                else
                    try normalised.appendSlice(slice);
            }
            continue;
        }

        // Special cases for end of normalised version
        if ((c == 'σ' or c == 'Σ' or c == 'ς') and (i.i == word.len)) {
            try normalised.appendSlice(comptime &ue('ς'));
        } else if (lowercase(c)) |lc| {
            try normalised.appendSlice(lc);
        } else {
            try normalised.appendSlice(slice);
        }
    }
}

/// Keywordify returns an unaccented, and normalised version
/// of a word. It also returns substrings of the unaccented and
/// normalised word for search indexing.
///
///  - The unaccented version removes all accents and breathings.
///  - The normalised removes only excess accents and standarises the final letter.
///
/// The substrings are slices of the `unaccented` and `normalised`
/// string buffer.
pub fn keywordify(
    allocator: Allocator,
    word: []const u8,
    unaccented: *BoundedArray(u8, max_word_size),
    normalised: *BoundedArray(u8, max_word_size),
    substrings: *ArrayListUnmanaged([]const u8),
) error{ OutOfMemory, WordTooLong, InvalidUtf8 }!void {
    if (word.len >= max_word_size) {
        return IndexError.WordTooLong;
    }
    var view = std.unicode.Utf8View.init(word) catch |e| {
        if (e == error.InvalidUtf8) {
            std.debug.print("keywordify on invalid unicode. {s} -- {any}\n", .{ word, word });
        }
        return e;
    };

    // Only one accent per normalised word
    var saw_accent = false;

    var i = view.iterator();
    var character_count: usize = 0;

    while (i.nextCodepointSlice()) |character_slice| {
        const c = std.unicode.utf8Decode(character_slice) catch {
            return error.InvalidUtf8;
        };
        if (c == ' ' or c == '\t') saw_accent = false;
        character_count += 1;

        // Removes accents and capitalisation
        if (unaccent(c)) |s| {
            unaccented.appendSlice(s) catch return error.WordTooLong;
        } else if (lowercase(c)) |lc| {
            unaccented.appendSlice(lc) catch return error.WordTooLong;
        } else {
            unaccented.appendSlice(character_slice) catch return error.WordTooLong;
        }

        // Normalisation processing
        if (remove_accent(c)) |rm| {
            if (saw_accent) {
                normalised.appendSlice(rm) catch return error.WordTooLong;
            } else if (lowercase(c)) |lc| {
                normalised.appendSlice(lc) catch return error.WordTooLong;
            } else {
                saw_accent = true;
                normalised.appendSlice(character_slice) catch return error.WordTooLong;
            }
        } else {
            if ((c == 'σ' or c == 'Σ' or c == 'ς') and (i.i == word.len)) {
                normalised.appendSlice(comptime &ue('ς')) catch return error.WordTooLong;
            } else if (lowercase(c)) |lc| {
                normalised.appendSlice(lc) catch return error.WordTooLong;
            } else {
                normalised.appendSlice(character_slice) catch return error.WordTooLong;
            }
        }

        if (i.i == word.len) {
            // The full length version is not a substring
            //try substrings.append(normalised.slice());
            //try substrings.append(unaccented.slice());
        } else if (character_count == 1 and character_slice.len < word.len) {
            // If we have only seen one unicode character, and there are more
            // characters to read, don't keep a one character slice
            continue;
        } else if (character_count < max_index_keyword_size) {
            const k1 = normalised.slice();
            const k2 = unaccented.slice();
            try substrings.append(allocator, k1);
            if (!std.mem.eql(u8, k1, k2)) {
                try substrings.append(allocator, unaccented.slice());
            }
        }
    }
}

const ue = std.unicode.utf8EncodeComptime;

/// Remove accent and breathing marks. Returns an array that is equal or
/// shorter in length to the original array used to build the character
/// to prevent memory overrun.
pub fn unaccent(c: u21) ?[]const u8 {
    return switch (c) {
        'Α', 'Ἀ', 'Ἁ', 'Ἄ', 'Ἅ', 'ἄ', 'ἅ', 'ἀ', 'ᾶ', 'ᾷ', 'ἁ', 'ά', 'ὰ', 'ἂ', 'ἃ', 'Ά', 'Ὰ' => comptime &ue('α'),
        'Β' => comptime &ue('β'),
        'Γ' => comptime &ue('γ'),
        'Δ' => comptime &ue('δ'),
        'Ε', 'Ἑ', 'Ἐ', 'ἔ', 'Ἕ', 'ἕ', 'ἐ', 'ἑ', 'ὲ', 'έ', 'ἒ', 'ἓ', 'Έ', 'Ὲ' => comptime &ue('ε'),
        'Ζ' => comptime &ue('ζ'),
        'Η', 'Ἡ', 'Ἠ', 'ἤ', 'ἥ', 'ἡ', 'ἠ', 'ή', 'ὴ', 'ἢ', 'ἣ', 'ῆ', 'ἦ', 'ἧ', 'Ή', 'Ὴ', 'ᾖ', 'ᾗ', 'ῃ', 'ᾑ', 'ᾐ', 'ῇ', 'ῄ', 'ῂ', 'ᾔ', 'ᾕ', 'ᾓ', 'ᾒ', 'ᾞ', 'ῌ', 'ᾙ', 'ᾘ', 'ᾜ', 'ᾝ', 'ᾛ', 'ᾚ' => comptime &ue('η'),
        'Θ' => comptime &ue('θ'),
        'Ἰ', 'Ἱ', 'ἴ', 'ἵ', 'ἰ', 'ἱ', 'ί', 'ὶ', 'ἲ', 'ἳ', 'ῖ', 'ἷ', 'ἶ', 'Ὶ', 'Ί' => comptime &ue('ι'),
        'Κ' => comptime &ue('κ'),
        'Λ' => comptime &ue('λ'),
        'Ν' => comptime &ue('ν'),
        'Μ' => comptime &ue('μ'),
        'Ξ' => comptime &ue('ξ'),
        'Ο', 'Ὀ', 'Ὁ', 'ό', 'ὸ', 'ὂ', 'ὃ', 'ὄ', 'ὅ', 'ὁ', 'ὀ', 'Ό', 'Ὸ' => comptime &ue('ο'),
        'Π' => comptime &ue('π'),
        'Ρ', 'Ῥ', 'ῤ', 'ῥ' => comptime &ue('ρ'),
        'Σ', 'ς' => comptime &ue('σ'),
        'Τ' => comptime &ue('τ'),
        'Υ', 'Ὑ', 'Ύ', 'Ὺ', 'ὔ', 'ὕ', 'ὐ', 'ὑ', 'ύ', 'ὺ', 'ὒ', 'ὓ', 'ῦ', 'ϋ', 'ὖ', 'ὗ' => comptime &ue('υ'),
        'Φ' => comptime &ue('φ'),
        'Χ' => comptime &ue('χ'),
        'Ψ' => comptime &ue('ψ'),
        'Ω', 'ώ', 'ὼ', 'Ώ', 'Ὼ', 'ὠ', 'ῶ', 'ὡ', 'ὦ', 'ὧ', 'ὤ', 'ὢ', 'ὣ', 'ὥ', 'ῷ' => comptime &ue('ω'),
        else => null,
    };
}

/// Return a deaccented, lowercased, normalised version of a character.
///
/// - Α Ἄ ἀ all become α
/// - Σ σ ς all become σ
/// - D d all become d
///
pub fn normalise_char(c: u21) u21 {
    return switch (c) {
        'Α', 'Ἀ', 'Ἁ', 'Ἄ', 'Ἅ', 'Ἂ', 'Ἃ', 'ἄ', 'ἅ', 'ἀ', 'ᾶ', 'ᾷ', 'ἁ', 'ά', 'ὰ', 'ἂ', 'ἃ', 'Ά', 'Ὰ' => 'α',
        'Β' => 'β',
        'Γ' => 'γ',
        'Δ' => 'δ',
        'Ε', 'Ἑ', 'Ἐ', 'ἔ', 'Ἕ', 'Ἔ', 'Ἒ', 'Ἓ', 'ἕ', 'ἐ', 'ἑ', 'ὲ', 'έ', 'ἒ', 'ἓ', 'Έ', 'Ὲ' => 'ε',
        'Ζ' => 'ζ',
        'Η', 'Ἡ', 'Ἠ', 'Ἢ', 'Ἣ', 'Ἤ', 'Ἥ', 'ἤ', 'ἥ', 'ἡ', 'ἠ', 'ή', 'ὴ', 'ἢ', 'ἣ', 'ῆ', 'ἦ', 'ἧ', 'Ή', 'Ὴ', 'ᾖ', 'ᾗ', 'ῃ', 'ᾑ', 'ᾐ', 'ῇ', 'ῄ', 'ῂ', 'ᾔ', 'ᾕ', 'ᾓ', 'ᾒ', 'ᾞ', 'ῌ', 'ᾙ', 'ᾘ', 'ᾜ', 'ᾝ', 'ᾛ', 'ᾚ' => 'η',
        'Θ' => 'θ',
        'Ι', 'Ἰ', 'Ἱ', 'Ἴ', 'Ἵ', 'Ἲ', 'Ἳ', 'ἴ', 'ἵ', 'ἰ', 'ἱ', 'ί', 'ὶ', 'ἲ', 'ἳ', 'ῖ', 'ἷ', 'ἶ', 'Ὶ', 'Ί' => 'ι',
        'Ϊ' => 'ϊ',
        'Κ' => 'κ',
        'Λ' => 'λ',
        'Ν' => 'ν',
        'Μ' => 'μ',
        'Ξ' => 'ξ',
        'Ο', 'Ὀ', 'Ὁ', 'ό', 'Ὄ', 'Ὅ', 'Ὃ', 'Ὂ', 'ὸ', 'ὂ', 'ὃ', 'ὄ', 'ὅ', 'ὁ', 'ὀ', 'Ό', 'Ὸ' => 'ο',
        'Π' => 'π',
        'Ρ', 'Ῥ', 'ῤ', 'ῥ' => 'ρ',
        'Σ', 'ς' => 'σ',
        'Τ' => 'τ',
        'Υ', 'Ὑ', 'Ύ', 'Ὺ', 'Ὕ', 'Ὓ', 'ὔ', 'ὕ', 'ὐ', 'ὑ', 'ύ', 'ὺ', 'ὒ', 'ὓ', 'ῦ', 'ϋ', 'ὖ', 'ὗ' => 'υ',
        'Ϋ' => 'ϋ',
        'Φ' => 'φ',
        'Χ' => 'χ',
        'Ψ' => 'ψ',
        'Ω', 'ώ', 'ὼ', 'Ώ', 'Ὼ', 'Ὤ', 'Ὥ', 'Ὣ', 'ὠ', 'ῶ', 'ὡ', 'ὦ', 'ὧ', 'ὤ', 'ὢ', 'ὣ', 'ὥ', 'ῷ', 'ᾦ', 'ᾧ', 'ῳ' => 'ω',
        else => {
            if (c >= 'A' and c <= 'Z') return c + ('a' - 'A');
            return c;
        },
    };
}

// lowercase returns a unicode array containing the lowercase equivalent
// of the requested letter. It is assumed that the array returned is equal
// or shoter in length to the original array used to build the character.
pub fn lowercase(c: u21) ?[]const u8 {
    return switch (c) {
        'Α' => comptime &ue('α'),
        'Ἀ' => comptime &ue('ἀ'),
        'Ἁ' => comptime &ue('ἁ'),
        'Ἄ' => comptime &ue('ἄ'),
        'Ἅ' => comptime &ue('ἅ'),
        'Ἂ' => comptime &ue('ἂ'),
        'Ἃ' => comptime &ue('ἃ'),
        'Ά' => comptime &ue('ά'),
        'Ὰ' => comptime &ue('ὰ'),
        'Β' => comptime &ue('β'),
        'Γ' => comptime &ue('γ'),
        'Δ' => comptime &ue('δ'),
        'Ε' => comptime &ue('ε'),
        'Ἑ' => comptime &ue('ἑ'),
        'Ἐ' => comptime &ue('ἐ'),
        'Ὲ' => comptime &ue('ὲ'),
        'Έ' => comptime &ue('έ'),
        'Ἕ' => comptime &ue('ἕ'),
        'Ἔ' => comptime &ue('ἔ'),
        'Ἒ' => comptime &ue('ἒ'),
        'Ἓ' => comptime &ue('ἓ'),
        'Ζ' => comptime &ue('ζ'),
        'Η' => comptime &ue('η'),
        'Ἡ' => comptime &ue('ἡ'),
        'Ἠ' => comptime &ue('ἠ'),
        'Ή' => comptime &ue('ή'),
        'Ὴ' => comptime &ue('ὴ'),
        'Ἢ' => comptime &ue('ἢ'),
        'Ἣ' => comptime &ue('ἣ'),
        'Ἤ' => comptime &ue('ἤ'),
        'Ἥ' => comptime &ue('ἥ'),
        'Θ' => comptime &ue('θ'),
        'Ι' => comptime &ue('ι'),
        'Ἰ' => comptime &ue('ἰ'),
        'Ἱ' => comptime &ue('ἱ'),
        'Ἳ' => comptime &ue('ἳ'),
        'Ἲ' => comptime &ue('ἲ'),
        'Ἵ' => comptime &ue('ἵ'),
        'Ἴ' => comptime &ue('ἴ'),
        'Ὶ' => comptime &ue('ὶ'),
        'Ί' => comptime &ue('ί'),
        'Ϊ' => comptime &ue('ϊ'),
        'Κ' => comptime &ue('κ'),
        'Λ' => comptime &ue('λ'),
        'Μ' => comptime &ue('μ'),
        'Ν' => comptime &ue('ν'),
        'Ξ' => comptime &ue('ξ'),
        'Ο' => comptime &ue('ο'),
        'Ὀ' => comptime &ue('ὀ'),
        'Ὁ' => comptime &ue('ὁ'),
        'Ό' => comptime &ue('ό'),
        'Ὸ' => comptime &ue('ὸ'),
        'Ὂ' => comptime &ue('ὂ'),
        'Ὃ' => comptime &ue('ὃ'),
        'Ὄ' => comptime &ue('ὄ'),
        'Ὅ' => comptime &ue('ὅ'),
        'Π' => comptime &ue('π'),
        'Ρ' => comptime &ue('ρ'),
        'Ῥ' => comptime &ue('ῥ'),
        'Σ' => comptime &ue('σ'),
        'Τ' => comptime &ue('τ'),
        'Υ' => comptime &ue('υ'),
        'Ὑ' => comptime &ue('ὑ'),
        'Ύ' => comptime &ue('ύ'),
        'Ὺ' => comptime &ue('ὺ'),
        'Ὕ' => comptime &ue('ὕ'),
        'Ὓ' => comptime &ue('ὓ'),
        'Ϋ' => comptime &ue('ϋ'),
        'Φ' => comptime &ue('φ'),
        'Χ' => comptime &ue('χ'),
        'Ψ' => comptime &ue('ψ'),
        'Ω' => comptime &ue('ω'),
        'Ὠ' => comptime &ue('ὠ'),
        'Ὡ' => comptime &ue('ὡ'),
        'Ὼ' => comptime &ue('ὼ'),
        'Ώ' => comptime &ue('ώ'),
        'Ὤ' => comptime &ue('ὤ'),
        'Ὥ' => comptime &ue('ὥ'),
        'Ὣ' => comptime &ue('ὣ'),
        'A' => comptime &ue('a'),
        'B' => comptime &ue('b'),
        'C' => comptime &ue('c'),
        'D' => comptime &ue('d'),
        'E' => comptime &ue('e'),
        'F' => comptime &ue('f'),
        'G' => comptime &ue('g'),
        'H' => comptime &ue('h'),
        'I' => comptime &ue('i'),
        'J' => comptime &ue('j'),
        'K' => comptime &ue('k'),
        'L' => comptime &ue('l'),
        'M' => comptime &ue('m'),
        'N' => comptime &ue('n'),
        'O' => comptime &ue('o'),
        'P' => comptime &ue('p'),
        'Q' => comptime &ue('q'),
        'R' => comptime &ue('r'),
        'S' => comptime &ue('s'),
        'T' => comptime &ue('t'),
        'U' => comptime &ue('u'),
        'V' => comptime &ue('v'),
        'W' => comptime &ue('w'),
        'X' => comptime &ue('x'),
        'Y' => comptime &ue('y'),
        'Z' => comptime &ue('z'),
        else => null,
    };
}

/// Remove accent marks, but retain breathing marks. Returns an array that is
/// equal or shoter in length to the original array used to build the character
/// to prevent memory overrun.
pub fn remove_accent(c: u21) ?[]const u8 {
    return switch (c) {
        'ά', 'ὰ', 'Ά', 'Ὰ', 'ᾶ' => comptime &ue('α'),
        'Ἄ', 'Ἂ', 'ἄ', 'ἂ', 'ἆ', 'Ἆ' => comptime &ue('ἀ'),
        'Ἅ', 'Ἃ', 'ἅ', 'ἃ', 'ἇ', 'Ἇ' => comptime &ue('ἁ'),
        'έ', 'ὲ', 'Έ', 'Ὲ' => comptime &ue('ε'),
        'ἔ', 'ἒ', 'Ἔ', 'Ἒ' => comptime &ue('ἐ'),
        'ἕ', 'ἓ', 'Ἕ', 'Ἓ' => comptime &ue('ἑ'),
        'ή', 'ὴ', 'Ή', 'Ὴ', 'ῆ' => comptime &ue('η'),
        'ἤ', 'ἢ', 'Ἤ', 'Ἢ', 'ἦ', 'Ἦ' => comptime &ue('ἠ'),
        'ἥ', 'ἣ', 'Ἥ', 'Ἣ', 'ἧ', 'Ἧ' => comptime &ue('ἡ'),
        'ί', 'ὶ', 'Ί', 'Ὶ', 'ῖ' => comptime &ue('ι'),
        'ἴ', 'ἲ', 'Ἴ', 'Ἲ', 'ἶ', 'Ἶ' => comptime &ue('ἰ'),
        'ἵ', 'ἳ', 'Ἵ', 'Ἳ', 'ἷ', 'Ἷ' => comptime &ue('ἱ'),
        'ό', 'ὸ', 'Ό', 'Ὸ' => comptime &ue('ο'),
        'ὄ', 'ὂ', 'Ὄ', 'Ὂ' => comptime &ue('ὀ'),
        'ὅ', 'ὃ', 'Ὅ', 'Ὃ' => comptime &ue('ὁ'),
        'ύ', 'ὺ', 'Ύ', 'Ὺ', 'ῦ' => comptime &ue('υ'),
        'ὔ', 'ὒ', 'ὖ' => comptime &ue('ὐ'),
        'ὕ', 'ὓ', 'Ὕ', 'Ὓ', 'ὗ', 'Ὗ' => comptime &ue('ὑ'),
        'ώ', 'ὼ', 'Ώ', 'Ὼ', 'ῶ', 'ῷ', 'ῳ' => comptime &ue('ω'),
        'ὥ', 'ὣ', 'ὧ', 'ᾧ', 'Ὥ', 'Ὣ', 'Ὧ', 'ᾯ' => comptime &ue('ὡ'),
        'ὦ', 'ὤ', 'ὢ', 'ᾦ', 'Ὦ', 'Ὤ', 'Ὢ', 'ᾮ' => comptime &ue('ὠ'),
        else => null,
    };
}

/// Converte any grave to acute
pub fn fix_grave(c: u21) ?[]const u8 {
    return switch (c) {
        'ὰ' => comptime &ue('ά'),
        'Ὰ' => comptime &ue('Ά'),
        'ἂ' => comptime &ue('ἄ'),
        'Ἂ' => comptime &ue('Ἄ'),
        'ἃ' => comptime &ue('ἅ'),
        'Ἃ' => comptime &ue('Ἅ'),
        'ὲ' => comptime &ue('έ'),
        'Ὲ' => comptime &ue('Έ'),
        'ἒ' => comptime &ue('ἔ'),
        'Ἒ' => comptime &ue('Ἔ'),
        'ἓ' => comptime &ue('ἕ'),
        'Ἓ' => comptime &ue('Ἕ'),
        'ὴ' => comptime &ue('ή'),
        'Ὴ' => comptime &ue('Ή'),
        'ἢ' => comptime &ue('ἤ'),
        'Ἢ' => comptime &ue('Ἤ'),
        'ἣ' => comptime &ue('ἥ'),
        'Ἣ' => comptime &ue('Ἥ'),
        'ὶ' => comptime &ue('ί'),
        'Ὶ' => comptime &ue('Ί'),
        'ἲ' => comptime &ue('ἴ'),
        'Ἲ' => comptime &ue('Ἴ'),
        'ἳ' => comptime &ue('ἵ'),
        'Ἳ' => comptime &ue('Ἵ'),
        'ὸ' => comptime &ue('ό'),
        'Ὸ' => comptime &ue('Ό'),
        'ὂ' => comptime &ue('ὄ'),
        'Ὂ' => comptime &ue('Ὄ'),
        'ὃ' => comptime &ue('ὅ'),
        'Ὃ' => comptime &ue('Ὅ'),
        'ὺ' => comptime &ue('ύ'),
        'Ὺ' => comptime &ue('Ύ'),
        'ὒ' => comptime &ue('ὔ'),
        'ὓ' => comptime &ue('ὕ'),
        'Ὓ' => comptime &ue('Ὕ'),
        'ὼ' => comptime &ue('ώ'),
        'Ὼ' => comptime &ue('Ώ'),
        'ὣ' => comptime &ue('ὥ'),
        'Ὣ' => comptime &ue('Ὥ'),
        else => null,
    };
}

const std = @import("std");
const log = std.log;
const is_stopword = @import("gloss_tokens.zig").is_stopword;

const farmhash = @import("farmhash64.zig");
const StringHashMapUnmanaged = std.StringHashMapUnmanaged;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;
const BinaryReader = @import("binary_reader.zig");
const BinaryWriter = @import("binary_writer.zig");
const stringLessThan = @import("sort.zig").lessThan;
const append_u32 = BinaryWriter.append_u32;
const append_u24 = BinaryWriter.append_u24;
const US = BinaryReader.US;

const BoundedArray = @import("bounded_array.zig").BoundedArray;

const eq = std.testing.expectEqual;
const se = std.testing.expectEqualStrings;

test "unaccent" {
    try eq(null, unaccent('a'));
    try std.testing.expectEqualStrings("α", unaccent('ἀ').?);
    try std.testing.expectEqualStrings("ω", unaccent('ῷ').?);
    try std.testing.expectEqualStrings("ω", unaccent('ὢ').?);
}

test "normalise simple" {
    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        const word = "abc";
        try normalise_word(word, &unaccented_word, &normalised_word);
        try se("abc", unaccented_word.slice());
        try se("abc", normalised_word.slice());
    }
    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        const word = "AbC";
        try normalise_word(word, &unaccented_word, &normalised_word);
        try se("abc", unaccented_word.slice());
        try se("abc", normalised_word.slice());
    }
    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        const word = "Kenan";
        try normalise_word(word, &unaccented_word, &normalised_word);
        try se("kenan", unaccented_word.slice());
        try se("kenan", normalised_word.slice());
    }

    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        const word = "αβγ";
        try normalise_word(word, &unaccented_word, &normalised_word);
        try se("αβγ", unaccented_word.slice());
        try se("αβγ", normalised_word.slice());
    }
    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        const word = "ἀρτος";
        try normalise_word(word, &unaccented_word, &normalised_word);
        try se("αρτοσ", unaccented_word.slice());
        try se("ἀρτος", normalised_word.slice());
    }
    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        const word = "ἄρτος";
        try normalise_word(word, &unaccented_word, &normalised_word);
        try se("αρτοσ", unaccented_word.slice());
        try se("ἄρτος", normalised_word.slice());
    }
    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        const word = "ἌΡΤΟΣ";
        try normalise_word(word, &unaccented_word, &normalised_word);
        try se("αρτοσ", unaccented_word.slice());
        try se("ἄρτος", normalised_word.slice());
    }
    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        const word = "ἄρτόσ";
        try normalise_word(word, &unaccented_word, &normalised_word);
        try se("αρτοσ", unaccented_word.slice());
        try se("ἄρτος", normalised_word.slice());
    }
    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        const word = "ὥρα";
        try normalise_word(word, &unaccented_word, &normalised_word);
        try se("ωρα", unaccented_word.slice());
        try se("ὥρα", normalised_word.slice());
    }
    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        const word = "τὸ";
        try normalise_word(word, &unaccented_word, &normalised_word);
        try se("το", unaccented_word.slice());
        try se("τό", normalised_word.slice());
    }
    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        const word = "οἶκός";
        try normalise_word(word, &unaccented_word, &normalised_word);
        try se("οικοσ", unaccented_word.slice());
        try se("οἶκος", normalised_word.slice());
    }
    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        const word = "οὗτός";
        try normalise_word(word, &unaccented_word, &normalised_word);
        try se("ουτοσ", unaccented_word.slice());
        try se("οὗτος", normalised_word.slice());
    }
}

test "normalise sentence" {
    {
        var unaccented_sentence = BoundedArray(u8, max_word_size){};
        var normalised_sentence = BoundedArray(u8, max_word_size){};
        const word = "ὁ Πέτρος λέγει·";
        try normalise_word(word, &unaccented_sentence, &normalised_sentence);
        try se("ο πετροσ λεγει·", unaccented_sentence.slice());
        try se("ὁ πέτρος λέγει·", normalised_sentence.slice());
    }
}

test "keywordify simple" {
    const allocator = std.testing.allocator;
    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        const word = "ἄρτός";
        var slices: ArrayListUnmanaged([]const u8) = .empty;
        defer slices.deinit(allocator);
        try keywordify(allocator, word, &unaccented_word, &normalised_word, &slices);
        try std.testing.expectEqual(6, slices.items.len);
        try se("ἄρ", slices.items[0]);
        try se("αρ", slices.items[1]);
        try se("ἄρτ", slices.items[2]);
        try se("αρτ", slices.items[3]);
        try se("ἄρτο", slices.items[4]);
        try se("αρτο", slices.items[5]);
        try se("ἄρτος", normalised_word.slice());
        try se("αρτοσ", unaccented_word.slice());
    }
    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        const word = "ΜΩϋσῆς";
        var slices: ArrayListUnmanaged([]const u8) = .empty;
        defer slices.deinit(allocator);
        try keywordify(allocator, word, &unaccented_word, &normalised_word, &slices);
        try std.testing.expectEqual(7, slices.items.len);
        try se("μω", slices.items[0]);
        try se("μωϋ", slices.items[1]);
        try se("μωυ", slices.items[2]);
        try se("μωϋσ", slices.items[3]);
        try se("μωυσ", slices.items[4]);
        try se("μωϋσῆ", slices.items[5]);
        try se("μωυση", slices.items[6]);
        try se("μωϋσῆς", normalised_word.slice());
        try se("μωυσησ", unaccented_word.slice());
    }
    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        const word = "serpent";
        var slices: ArrayListUnmanaged([]const u8) = .empty;
        defer slices.deinit(allocator);
        try keywordify(
            allocator,
            word,
            &unaccented_word,
            &normalised_word,
            &slices,
        );
        try std.testing.expectEqual(5, slices.items.len);
        try se("se", slices.items[0]);
        try se("ser", slices.items[1]);
        try se("serp", slices.items[2]);
        try se("serpe", slices.items[3]);
        try se("serpen", slices.items[4]);
        try se("serpent", normalised_word.slice());
        try se("serpent", unaccented_word.slice());
    }
}

test "keywordify phrase" {
    const allocator = std.testing.allocator;
    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        const phrase = "ὁ μικρὸς οἶκος";
        var slices: ArrayListUnmanaged([]const u8) = .empty;
        defer slices.deinit(allocator);
        try keywordify(allocator, phrase, &unaccented_word, &normalised_word, &slices);
        try std.testing.expectEqual(24, slices.items.len);
        try se("ὁ μικρὸς οἶκος", normalised_word.slice());
        try se("ο μικροσ οικοσ", unaccented_word.slice());
    }
}

test "search_index basics" {
    const allocator = std.testing.allocator;

    const Thing = struct {
        word: []const u8,
        const Self = @This();
        pub fn lessThan(_: ?[]const u8, a: *Self, b: *Self) bool {
            return std.mem.lessThan(u8, a.word, b.word);
        }
    };
    var index: SearchIndex(*Thing, Thing.lessThan) = .empty;
    defer index.deinit(allocator);

    var f1 = Thing{ .word = "ἄρτος" };
    try index.add(allocator, f1.word, &f1);
    var f2 = Thing{ .word = "ἔχω" };
    try index.add(allocator, f2.word, &f2);
    var f3 = Thing{ .word = "ἄγγελος" };
    try index.add(allocator, f3.word, &f3);
    var f4 = Thing{ .word = "ἄρτον" };
    try index.add(allocator, f4.word, &f4);

    try eq(null, try index.lookup(""));
    try eq(null, try index.lookup("εις"));

    {
        const sr = try index.lookup("ἄ");
        try std.testing.expect(sr == null);
    }

    {
        const sr = try index.lookup("ἄρ");
        try std.testing.expect(sr != null);
        try se("ἄρ", sr.?.keyword);
        try eq(0, sr.?.exact_accented.items.len);
        try eq(0, sr.?.exact_unaccented.items.len);
        try eq(2, sr.?.partial_match.items.len);
    }

    {
        const sr = try index.lookup("ἄρτ");
        try std.testing.expect(sr != null);
        try se("ἄρτ", sr.?.keyword);
        try eq(0, sr.?.exact_accented.items.len);
        try eq(0, sr.?.exact_unaccented.items.len);
        try eq(2, sr.?.partial_match.items.len);
    }

    {
        const sr = try index.lookup("ἄρτος");
        try std.testing.expect(sr != null);
        try se("ἄρτος", sr.?.keyword);
        try eq(1, sr.?.exact_accented.items.len);
        try eq(0, sr.?.exact_unaccented.items.len);
        try eq(0, sr.?.partial_match.items.len);
    }

    {
        const sr = try index.lookup("αρτ");
        try std.testing.expect(sr != null);
        try se("αρτ", sr.?.keyword);
        try eq(0, sr.?.exact_accented.items.len);
        try eq(0, sr.?.exact_unaccented.items.len);
        try eq(2, sr.?.partial_match.items.len);
    }
}

test "search_index_duplicates" {
    {
        var unaccented_word = BoundedArray(u8, max_word_size){};
        var normalised_word = BoundedArray(u8, max_word_size){};
        var substrings: std.ArrayListUnmanaged([]const u8) = .empty;
        defer substrings.deinit(std.testing.allocator);
        try keywordify(
            std.testing.allocator,
            "περιπατεῖτε",
            &unaccented_word,
            &normalised_word,
            &substrings,
        );
        try eq(11, substrings.items.len);
    }

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Thing = struct {
        word: []const u8,
        const Self = @This();
        pub fn lessThan(_: ?[]const u8, a: *Self, b: *Self) bool {
            return std.mem.lessThan(u8, a.word, b.word);
        }
    };
    var index: SearchIndex(*Thing, Thing.lessThan) = .empty;
    defer index.deinit(allocator);

    var f1 = Thing{ .word = "περιπατεῖτε" };
    try index.add(allocator, f1.word, &f1);

    try std.testing.expectEqual(13, index.index.count());

    try eq(null, try index.lookup("π"));
    try eq(null, try index.lookup("εις"));

    {
        const sr = try index.lookup("περιπατεῖτε");
        try std.testing.expect(sr != null);
        try se("περιπατεῖτε", sr.?.keyword);
        try eq(1, sr.?.exact_accented.items.len);
        try eq(0, sr.?.exact_unaccented.items.len);
        try eq(0, sr.?.partial_match.items.len);
    }
}

test "search_index arena" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Thing = struct {
        word: []const u8,
        const Self = @This();
        pub fn lessThan(_: ?[]const u8, a: *Self, b: *Self) bool {
            return std.mem.lessThan(u8, a.word, b.word);
        }
    };
    var index: SearchIndex(*Thing, Thing.lessThan) = .empty;
    defer index.deinit(allocator);

    var f1 = Thing{ .word = "ἄρτος" };
    try index.add(allocator, f1.word, &f1);
    var f2 = Thing{ .word = "ἔχω" };
    try index.add(allocator, f2.word, &f2);
    var f3 = Thing{ .word = "ἄγγελος" };
    try index.add(allocator, f3.word, &f3);
    var f4 = Thing{ .word = "ἄρτον" };
    try index.add(allocator, f4.word, &f4);

    //var ti = index.index.iterator();
    //while (ti.next()) |i| {
    //    std.debug.print(" - {s}\n", .{i.key_ptr.*});
    //}
    try std.testing.expectEqual(26, index.index.count());

    try eq(null, try index.lookup(""));
    try eq(null, try index.lookup("εις"));

    {
        const sr = try index.lookup("ἄρ");
        try std.testing.expect(sr != null);
        try se("ἄρ", sr.?.keyword);
        try eq(0, sr.?.exact_accented.items.len);
        try eq(0, sr.?.exact_unaccented.items.len);
        try eq(2, sr.?.partial_match.items.len);
    }
}
