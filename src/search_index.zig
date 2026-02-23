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

        /// normaliser splits and normalises keywords, storing the results
        /// in an internal temporary buffer
        normaliser: Normaliser,

        pub const empty: Self = .{
            .index = .empty,
            .normaliser = .empty,
        };

        /// `deinit` is required if do not use an arena allocator.
        pub fn deinit(self: *Self, allocator: Allocator) void {
            var i = self.index.iterator();
            while (i.next()) |item| {
                allocator.free(item.key_ptr.*);
                item.value_ptr.*.destroy(allocator);
            }
            self.normaliser.deinit(allocator);
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

            const info = try self.normaliser.keywords(allocator, word);

            var result = try self.getOrCreateSearchResult(
                allocator,
                info.accented,
            );
            try result.exact_accented.append(allocator, form);

            if (!std.mem.eql(u8, info.accented, info.unaccented)) {
                result = try self.getOrCreateSearchResult(
                    allocator,
                    info.unaccented,
                );
                try result.exact_unaccented.append(allocator, form);
            }

            for (self.normaliser.slices.items) |substring| {
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

        // Returns all records that exactly match (accents included). If no
        // records exactly match. Returns all records that match with accents
        // removed.
        pub fn lookup(self: *Self, word: []const u8) (error{NormalisationFailed})!?*SearchResult {
            if (word.len >= max_word_size) {
                // If search word is too long, it definitely
                // is not in the search result.
                return null;
            }

            var n: Normaliser = .empty;
            const info = n.normalise(word) catch |e| {
                // If normalisation fails due to invalid utf8 encoding
                // then we know this query has no results.
                //
                // Theoretically strange unicode issues could cause an
                // out of memory error, but again this is an invalid
                // search query.
                std.log.err("normalisation failed: {any}", .{e});
                return error.NormalisationFailed;
            };

            const result = self.index.get(info.accented);
            if (result != null) return result;

            return self.index.get(info.unaccented);
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

const std = @import("std");
const log = std.log;
const is_stopword = @import("gloss_tokens.zig").is_stopword;

const Normaliser = @import("normaliser.zig").Normaliser;

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
    const gpa = std.testing.allocator;
    var n: Normaliser = .empty;
    defer n.deinit(gpa);

    {
        const info = try n.keywords(gpa, "περιπατεῖτε");
        try eq(11, info.keywords.len);
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
