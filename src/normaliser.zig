pub const max_word_size = 500;
const max_index_keyword_size = 50;

/// normaliser splits and normalises keywords, storing the results
/// in an internal temporary buffer
pub const Normaliser = struct {
    accented_buffer: [max_word_size]u8,
    unaccented_buffer: [max_word_size]u8,
    slices: std.ArrayListUnmanaged([]const u8),

    pub const empty: Normaliser = .{
        .accented_buffer = undefined,
        .unaccented_buffer = undefined,
        .slices = .empty,
    };

    pub fn deinit(self: *Normaliser, gpa: Allocator) void {
        self.slices.deinit(gpa);
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
    pub fn keywords(
        self: *Normaliser,
        allocator: Allocator,
        word: []const u8,
    ) error{ OutOfMemory, WordTooLong, InvalidUtf8 }!struct {
        accented: []const u8,
        unaccented: []const u8,
        keywords: [][]const u8,
    } {
        if (word.len >= max_word_size) return error.WordTooLong;

        self.slices.clearRetainingCapacity();
        try self.slices.ensureUnusedCapacity(allocator, word.len * 2);

        var accented = std.Io.Writer.fixed(&self.accented_buffer);
        var unaccented = std.Io.Writer.fixed(&self.unaccented_buffer);

        var view = std.unicode.Utf8View.init(word) catch |e| {
            if (e == error.InvalidUtf8) {
                std.log.err("keywordify on invalid unicode. {s} -- {any}\n", .{ word, word });
            }
            return e;
        };

        // Only one accent per normalised word
        var saw_accent = false;

        var i = view.iterator();
        var character_count: usize = 0;

        while (i.nextCodepointSlice()) |slice| {
            if (character_count > 1 and character_count < max_index_keyword_size) {
                const k1 = accented.buffer[0..accented.end];
                const k2 = unaccented.buffer[0..unaccented.end];
                try self.slices.append(allocator, k1);
                if (!std.mem.eql(u8, k1, k2)) {
                    try self.slices.append(allocator, k2);
                }
            }

            const c = std.unicode.utf8Decode(slice) catch return error.InvalidUtf8;
            if (c == ' ' or c == '\t') saw_accent = false;
            character_count += 1;

            // Removes accents and capitalisation
            const out = if (unaccent(c)) |s|
                s
            else if (lowercase(c)) |lc|
                lc
            else
                slice;
            unaccented.writeAll(out) catch return error.WordTooLong;

            // Normalisation processing
            if (remove_accent(c)) |rm| {
                var out2: []const u8 = undefined;
                if (saw_accent) {
                    out2 = rm;
                } else if (lowercase(c)) |lc| {
                    out2 = lc;
                } else {
                    saw_accent = true;
                    out2 = if (fix_grave(c)) |fixed|
                        fixed
                    else
                        slice;
                }
                accented.writeAll(out2) catch return error.WordTooLong;
            } else {
                const out2 = if ((c == 'σ' or c == 'Σ' or c == 'ς') and (i.i == word.len))
                    comptime &ue('ς')
                else if (lowercase(c)) |lc|
                    lc
                else
                    slice;
                accented.writeAll(out2) catch return error.WordTooLong;
            }
        }

        return .{
            .accented = accented.buffer[0..accented.end],
            .unaccented = unaccented.buffer[0..unaccented.end],
            .keywords = self.slices.items,
        };
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
    pub fn normalise(
        self: *Normaliser,
        word: []const u8,
    ) error{ OutOfMemory, WordTooLong, InvalidUtf8 }!struct {
        accented: []const u8,
        unaccented: []const u8,
    } {
        if (word.len >= max_word_size) return error.WordTooLong;

        var accented = std.Io.Writer.fixed(&self.accented_buffer);
        var unaccented = std.Io.Writer.fixed(&self.unaccented_buffer);

        var view = std.unicode.Utf8View.init(word) catch |e| {
            if (e == error.InvalidUtf8) {
                std.log.err("keywordify on invalid unicode. {s} -- {any}\n", .{ word, word });
            }
            return e;
        };

        // Only one accent per normalised word
        var saw_accent = false;

        var i = view.iterator();
        var character_count: usize = 0;

        while (i.nextCodepointSlice()) |slice| {
            const c = std.unicode.utf8Decode(slice) catch return error.InvalidUtf8;
            if (c == ' ' or c == '\t') saw_accent = false;
            character_count += 1;

            // Removes accents and capitalisation
            const out = if (unaccent(c)) |s|
                s
            else if (lowercase(c)) |lc|
                lc
            else
                slice;
            unaccented.writeAll(out) catch return error.WordTooLong;

            // Normalisation processing
            if (remove_accent(c)) |rm| {
                var out2: []const u8 = undefined;
                if (saw_accent) {
                    out2 = rm;
                } else if (lowercase(c)) |lc| {
                    out2 = lc;
                } else {
                    saw_accent = true;
                    out2 = if (fix_grave(c)) |fixed|
                        fixed
                    else
                        slice;
                }
                accented.writeAll(out2) catch return error.WordTooLong;
            } else {
                const out2 = if ((c == 'σ' or c == 'Σ' or c == 'ς') and (i.i == word.len))
                    comptime &ue('ς')
                else if (lowercase(c)) |lc|
                    lc
                else
                    slice;
                accented.writeAll(out2) catch return error.WordTooLong;
            }
        }

        return .{
            .accented = accented.buffer[0..accented.end],
            .unaccented = unaccented.buffer[0..unaccented.end],
        };
    }
};

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

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const ue = std.unicode.utf8EncodeComptime;
const eq = std.testing.expectEqual;
const se = std.testing.expectEqualStrings;

test "unaccent" {
    try eq(null, unaccent('a'));
    try std.testing.expectEqualStrings("α", unaccent('ἀ').?);
    try std.testing.expectEqualStrings("ω", unaccent('ῷ').?);
    try std.testing.expectEqualStrings("ω", unaccent('ὢ').?);
}

test "keywordify_simple" {
    const gpa = std.testing.allocator;
    var n: Normaliser = .empty;
    defer n.deinit(gpa);

    var i = try n.keywords(gpa, "abc");
    try se("abc", i.accented);
    try se("abc", i.unaccented);

    i = try n.keywords(gpa, "AbC");
    try se("abc", i.accented);
    try se("abc", i.unaccented);

    i = try n.keywords(gpa, "Kenan");
    try se("kenan", i.accented);
    try se("kenan", i.unaccented);

    i = try n.keywords(gpa, "αβγ");
    try se("αβγ", i.accented);
    try se("αβγ", i.unaccented);

    i = try n.keywords(gpa, "ἀρτος");
    try se("αρτοσ", i.unaccented);
    try se("ἀρτος", i.accented);

    i = try n.keywords(gpa, "ἄρτος");
    try se("ἄρτος", i.accented);
    try se("αρτοσ", i.unaccented);

    i = try n.keywords(gpa, "ἌΡΤΟΣ");
    try se("ἄρτος", i.accented);
    try se("αρτοσ", i.unaccented);

    i = try n.keywords(gpa, "ἄρτόσ");
    try se("ἄρτος", i.accented);
    try se("αρτοσ", i.unaccented);

    i = try n.keywords(gpa, "ὥρα");
    try se("ὥρα", i.accented);
    try se("ωρα", i.unaccented);

    i = try n.keywords(gpa, "τὸ");
    try se("τό", i.accented);
    try se("το", i.unaccented);

    i = try n.keywords(gpa, "οἶκός");
    try se("οἶκος", i.accented);
    try se("οικοσ", i.unaccented);

    i = try n.keywords(gpa, "οὗτός");
    try se("οὗτος", i.accented);
    try se("ουτοσ", i.unaccented);
}

test "normalise sentence" {
    const gpa = std.testing.allocator;
    var n: Normaliser = .empty;
    defer n.deinit(gpa);

    const i = try n.keywords(gpa, "ὁ Πέτρος λέγει·");
    try se("ο πετροσ λεγει·", i.unaccented);
    try se("ὁ πέτρος λέγει·", i.accented);
}

test "keywordify simple" {
    const gpa = std.testing.allocator;
    var n: Normaliser = .empty;
    defer n.deinit(gpa);

    {
        const word = "ἄρτός";
        const i = try n.keywords(gpa, word);
        try std.testing.expectEqual(6, i.keywords.len);
        try se("ἄρ", i.keywords[0]);
        try se("αρ", i.keywords[1]);
        try se("ἄρτ", i.keywords[2]);
        try se("αρτ", i.keywords[3]);
        try se("ἄρτο", i.keywords[4]);
        try se("αρτο", i.keywords[5]);
        try se("ἄρτος", i.accented);
        try se("αρτοσ", i.unaccented);
    }

    {
        const word = "ΜΩϋσῆς";
        const i = try n.keywords(gpa, word);
        try std.testing.expectEqual(7, i.keywords.len);
        try se("μω", i.keywords[0]);
        try se("μωϋ", i.keywords[1]);
        try se("μωυ", i.keywords[2]);
        try se("μωϋσ", i.keywords[3]);
        try se("μωυσ", i.keywords[4]);
        try se("μωϋσῆ", i.keywords[5]);
        try se("μωυση", i.keywords[6]);
        try se("μωϋσῆς", i.accented);
        try se("μωυσησ", i.unaccented);
    }

    {
        const word = "serpent";
        const i = try n.keywords(gpa, word);
        try std.testing.expectEqual(5, i.keywords.len);
        try se("se", i.keywords[0]);
        try se("ser", i.keywords[1]);
        try se("serp", i.keywords[2]);
        try se("serpe", i.keywords[3]);
        try se("serpen", i.keywords[4]);
        try se("serpent", i.accented);
        try se("serpent", i.unaccented);
    }
}

test "keywordify phrase" {
    const gpa = std.testing.allocator;
    var n: Normaliser = .empty;
    defer n.deinit(gpa);

    const phrase = "ὁ μικρὸς οἶκος";
    const keyworded = "ὁ μικρός οἶκος";

    {
        const i = try n.keywords(gpa, phrase);
        try std.testing.expectEqual(24, i.keywords.len);
        try se(keyworded, i.accented);
        try se("ο μικροσ οικοσ", i.unaccented);
    }
}
