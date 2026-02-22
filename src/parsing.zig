const std = @import("std");

/// Packs parsing information about a biblical
/// greek word into a u32.
pub const Parsing = packed struct(u32) {
    part_of_speech: PartOfSpeech = .unknown,
    tense_form: TenseForm = .unknown,
    mood: Mood = .unknown,
    gender: Gender = .unknown,
    voice: Voice = .unknown,
    case: Case = .unknown,
    person: Person = .unknown,
    number: Number = .unknown,
    interrogative: bool = false,
    negative: bool = false,
    correlative: bool = false,
    indefinite: bool = false,
    indeclinable: bool = false,
    crasis: bool = false,
    unused: bool = false,

    pub const default: Parsing = @bitCast(@as(u32, 0));

    pub fn format(
        parsing: Parsing,
        writer: *std.Io.Writer,
    ) (std.Io.Writer.Error)!void {
        parsing.string(writer) catch |e| {
            if (e == error.Incomplete)
                try writer.writeAll("[incomplete]");
        };
    }

    pub fn string(
        p: Parsing,
        b: *std.Io.Writer,
    ) (std.Io.Writer.Error || error{Incomplete})!void {
        switch (p.part_of_speech) {
            .unknown => {
                return;
            },
            .adverb => {
                try b.writeAll("ADV");
                try append_flag(p, b);
                return;
            },
            .comparative_adverb => {
                try b.writeAll("ADV-C");
                return;
            },
            .superlative_adverb => {
                try b.writeAll("ADV-S");
                return;
            },
            .conjunction => {
                try b.writeAll("CONJ");
                try append_flag(p, b);
                return;
            },
            .conditional => {
                try b.writeAll("COND");
                try append_flag(p, b);
                return;
            },
            .particle => {
                try b.writeAll("PRT");
                try append_flag(p, b);
                return;
            },
            .preposition => {
                try b.writeAll("PREP");
                try append_flag(p, b);
                return;
            },
            .interjection => {
                try b.writeAll("INJ");
                try append_flag(p, b);
                return;
            },
            .aramaic_transliteration => {
                try b.writeAll("ARAM");
                return;
            },
            .hebrew_transliteration => {
                try b.writeAll("HEB");
                return;
            },
            .proper_noun => {
                if (p.indeclinable) {
                    try b.writeAll("N-PRI");
                    return;
                }
            },
            .numeral => {
                if (p.indeclinable) {
                    try b.writeAll("A-NUI");
                    return;
                }
            },
            .letter => {
                if (p.indeclinable) {
                    try b.writeAll("N-LI");
                    return;
                }
            },
            .noun => {
                if (p.indeclinable) {
                    try b.writeAll("N-OI");
                    return;
                }
            },
            else => {},
        }

        switch (p.part_of_speech) {
            .verb => {
                try b.writeByte('V');
                try append_vp(p, b);
                return;
            },
            .noun => {
                try b.writeByte('N');
                try append_cng(p, b);
                try append_flag(p, b);
                return;
            },
            .article => {
                try b.writeByte('T');
                try append_cng(p, b);
                try append_flag(p, b);
                return;
            },
            .adjective => {
                try b.writeByte('A');
                try append_cng(p, b);
                try append_flag(p, b);
                return;
            },
            .relative_pronoun => {
                try b.writeByte('R');
                try append_cng(p, b);
                return;
            },
            .reciprocal_pronoun => {
                try b.writeByte('C');
                try append_cng(p, b);
                return;
            },
            .demonstrative_pronoun => {
                try b.writeByte('D');
                try append_cng(p, b);
                try append_flag(p, b);
                return;
            },
            .reflexive_pronoun => {
                try b.writeByte('F');
                try append_fcng(p, b);
                return;
            },
            .possessive_pronoun => {
                try b.writeByte('S');
                try append_ref(p, b);
                return;
            },
            .personal_pronoun => {
                try b.writeByte('P');
                try append_personal_pronoun(p, b);
                try append_flag(p, b);
                return;
            },
            .proper_noun => {
                if (p.indeclinable) {
                    try b.writeAll("IPN");
                    try append_cng(p, b);
                    return;
                }
                try b.writeAll("PN");
                try append_cng(p, b);
                return;
            },
            .pronoun => {
                if (p.correlative and p.interrogative) {
                    try b.writeAll("Q");
                    try append_cng(p, b);
                    return;
                }
                if (p.correlative) {
                    try b.writeAll("K");
                    try append_cng(p, b);
                    return;
                }
                if (p.interrogative) {
                    try b.writeAll("I");
                    try append_cng(p, b);
                    return;
                }
                if (p.indefinite) {
                    try b.writeAll("X");
                    try append_cng(p, b);
                    return;
                }
                try b.writeAll("O");
                try append_cng(p, b);
                return;
            },
            .superlative_adverb => {
                try b.writeAll("ADV-S");
                try append_flag(p, b);
                return;
            },
            .superlative_noun => {
                try b.writeAll("N");
                try append_cng(p, b);
                try b.writeAll("-S");
                return;
            },
            .superlative_adjective => {
                try b.writeAll("A");
                try append_cng(p, b);
                try b.writeAll("-S");
                return;
            },
            .comparative_adverb => {
                try b.writeAll("ADV-C");
                try append_flag(p, b);
                return;
            },
            .comparative_noun => {
                try b.writeByte('N');
                try append_cng(p, b);
                try b.writeAll("-C");
                return;
            },
            .comparative_adjective => {
                try b.writeByte('A');
                try append_cng(p, b);
                try b.writeAll("-C");
                return;
            },
            else => {},
        }

        return;
    }

    pub const PartOfSpeech = @import("part_of_speech.zig").PartOfSpeech;

    pub const TenseForm = enum(u4) {
        unknown = 0,
        present = 1,
        future = 2,
        aorist = 3,
        imperfect = 4,
        perfect = 5,
        pluperfect = 6,
        second_future = 7,
        second_aorist = 8,
        second_perfect = 9,
        second_pluperfect = 10,
        // Pack in some non verb field data
        ref_singular = 11,
        ref_plural = 12,
    };

    pub const Voice = enum(u3) {
        unknown = 0,
        active = 1,
        middle = 2,
        passive = 3,
        middle_or_passive = 4,
        middle_deponent = 5,
        passive_deponent = 6,
        middle_or_passive_deponent = 7,
    };

    pub const Mood = enum(u3) {
        unknown = 0,
        indicative = 1,
        subjunctive = 2,
        optative = 3,
        imperative = 4,
        infinitive = 5,
        participle = 6,
    };

    pub const Person = enum(u2) {
        unknown = 0,
        first = 1,
        second = 2,
        third = 3,
    };

    pub const Number = enum(u2) {
        unknown = 0,
        singular = 1,
        dual = 2,
        plural = 3,
    };

    pub const Case = enum(u3) {
        unknown = 0,
        nominative = 1,
        accusative = 2,
        genitive = 3,
        dative = 4,
        vocative = 5,
    };

    pub const Gender = enum(u3) {
        unknown = 0,
        masculine = 1,
        feminine = 2,
        masculine_feminine = 3,
        neuter = 4,
        masculine_neuter = 5,
        masculine_feminine_neuter = 7,

        pub fn from_u8(gender: u8) !Gender {
            return switch (gender) {
                0 => .unknown,
                1 => .masculine,
                2 => .feminine,
                3 => .masculine_feminine,
                4 => .neuter,
                5 => .masculine_neuter,
                7 => .masculine_feminine_neuter,
                else => error.InvalidGender,
            };
        }

        pub fn articles(self: Gender) []const u8 {
            return switch (self) {
                .unknown => "",
                .masculine => "ὁ",
                .feminine => "ἡ",
                .masculine_feminine => "ὁ ἡ",
                .neuter => "τό",
                .masculine_neuter => "ὁ τό",
                .masculine_feminine_neuter => "ὁ ἡ τό",
            };
        }

        pub fn parse(value: []const u8) error{InvalidGender}!Gender {
            if (std.mem.eql(u8, value, "")) {
                return .unknown;
            }
            if (std.mem.eql(u8, value, "ὁ")) {
                return .masculine;
            }
            if (std.mem.eql(u8, value, "ἡ")) {
                return .feminine;
            }
            if (std.mem.eql(u8, value, "τό")) {
                return .neuter;
            }
            if (std.mem.eql(u8, value, "τὸ")) {
                return .neuter;
            }
            if (std.mem.eql(u8, value, "ὁ ἡ") or std.mem.eql(u8, value, "ὁ,ἡ")) {
                return .masculine_feminine;
            }
            if (std.mem.eql(u8, value, "ὁ τό") or std.mem.eql(u8, value, "ὁ,τό")) {
                return .masculine_neuter;
            }
            if (std.mem.eql(u8, value, "ὁ ἡ τό") or std.mem.eql(u8, value, "ὁ,ἡ,τό")) {
                return .masculine_feminine_neuter;
            }
            return error.InvalidGender;
        }

        pub fn english(self: Gender) []const u8 {
            switch (self) {
                .masculine => "masculine",
                .feminine => "feminine",
                .masculine_feminine => "masculine_feminine",
                .masculine_feminine_neuter => "masculine_feminine_neuter",
                .neuter => "neuter",
                .masculine_neuter => "masculine_neuter",
                .unknown => "",
            }
        }
    };

    // Return the capitalised English name for the part of
    // speech. i.e. "Proper Noun"
    pub fn english_part_of_speech(parsing: Parsing) []const u8 {
        return switch (parsing.part_of_speech) {
            .unknown => "",
            .particle => {
                if (parsing.interrogative) {
                    return "Interrogative Particle";
                }
                return "Particle";
            },
            .verb => "Verb",
            .noun => "Noun",
            .adjective => "Adjective",
            .adverb => "Adverb",
            .conjunction => "Conjunction",
            .proper_noun => {
                if (parsing.interrogative) {
                    return "Interrogative Proper Noun";
                }
                if (parsing.indeclinable) {
                    return "Indeclinable Proper Noun";
                }
                return "Proper Noun";
            },
            .preposition => "Preposition",
            .conditional => "Conditional",
            .article => "Definite Article",
            .interjection => "Interjection",
            .pronoun => {
                if (parsing.interrogative) {
                    return "Interrogative Pronoun";
                }
                if (parsing.indefinite) {
                    return "Indefinite Pronoun";
                }
                return "Pronoun";
            },
            .personal_pronoun => "Personal Pronoun",
            .relative_pronoun => "Relative Pronoun",
            .reciprocal_pronoun => "Reciprocal Pronoun",
            .demonstrative_pronoun => "Demonstrative Pronoun",
            .reflexive_pronoun => "Reflexive Pronoun",
            .possessive_pronoun => "Possessive Pronoun",
            .transliteration => "Transliteration",
            .hebrew_transliteration => "Hebrew Transliteration",
            .aramaic_transliteration => "Aramaic Transliteration",
            .numeral => "Numeral",
            .letter => "Letter",
            .superlative_noun => "Superlative Noun",
            .superlative_adverb => "Superlative Adverb",
            .superlative_adjective => "Superlative Adjective",
            .comparative_noun => "Comparative Noun",
            .comparative_adverb => "Comparative Adverb",
            .comparative_adjective => "Comparative Adjective",
        };
    }

    // Return a capitalised English name for the part of
    // speech with without spaces. i.e. ProperNoun"
    pub fn english_part_of_speech_label(parsing: Parsing) []const u8 {
        return switch (parsing.part_of_speech) {
            .unknown => "Unknown",
            .particle => {
                if (parsing.interrogative) {
                    return "InterrogativeParticle";
                }
                return "Particle";
            },
            .verb => "Verb",
            .noun => "Noun",
            .adjective => "Adjective",
            .article => "DefiniteArticle",
            .adverb => "Adverb",
            .pronoun => {
                if (parsing.interrogative) {
                    return "InterrogativePronoun";
                }
                if (parsing.indefinite) {
                    return "IndefinitePronoun";
                }
                return "Pronoun";
            },
            .preposition => "Preposition",
            .conjunction => "Conjunction",
            .conditional => "Conditional",
            .interjection => "Interjection",
            .relative_pronoun => "RelativePronoun",
            .reciprocal_pronoun => "ReciprocalPronoun",
            .demonstrative_pronoun => "DemonstrativePronoun",
            .reflexive_pronoun => "ReflexivePronoun",
            .possessive_pronoun => "PosessivePronoun",
            .personal_pronoun => "PersonalPronoun",
            .proper_noun => {
                if (parsing.interrogative) {
                    return "InterrogativeProperNoun";
                }
                if (parsing.indeclinable) {
                    return "IndeclinableProperNoun";
                }
                return "ProperNoun";
            },
            .superlative_noun => "SuperlativeNoun",
            .superlative_adjective => "SuperlativeAdjective",
            .comparative_noun => "ComparativeNoun",
            .comparative_adjective => "ComparativeAdjective",
            .transliteration => "HebrewTransliteration",
            .hebrew_transliteration => "HebrewTransliteration",
            .aramaic_transliteration => "AramaicTransliteration",
            .numeral => "Numeral",
            .letter => "Letter",
            else => "",
        };
    }

    pub const Error = error{
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
    };
};

inline fn append_person(
    p: Parsing,
    b: *std.Io.Writer,
) (std.Io.Writer.Error || error{Incomplete})!void {
    switch (p.person) {
        .first => try b.writeByte('1'),
        .second => try b.writeByte('2'),
        .third => try b.writeByte('3'),
        .unknown => return error.Incomplete,
    }
}

inline fn append_personal_pronoun(p: Parsing, b: *std.Io.Writer) std.Io.Writer.Error!void {
    switch (p.person) {
        .first => try b.writeAll("-1"),
        .second => try b.writeAll("-2"),
        else => {
            try append_cng(p, b);
            return;
        },
    }
    switch (p.case) {
        .nominative => try b.writeByte('N'),
        .accusative => try b.writeByte('A'),
        .genitive => try b.writeByte('G'),
        .dative => try b.writeByte('D'),
        .vocative => try b.writeByte('V'),
        else => return,
    }
    switch (p.tense_form) {
        .ref_singular => try b.writeByte('S'),
        .ref_plural => try b.writeByte('P'),
        else => return,
    }
    return;
}

inline fn append_ref(p: Parsing, b: *std.Io.Writer) !void {
    switch (p.person) {
        .first => try b.writeAll("-1"),
        .second => try b.writeAll("-2"),
        .third => try b.writeAll("-3"),
        else => return,
    }
    switch (p.tense_form) {
        .ref_singular => try b.writeAll("S"),
        .ref_plural => try b.writeAll("P"),
        else => return,
    }
    switch (p.case) {
        .nominative => try b.writeAll("N"),
        .accusative => try b.writeAll("A"),
        .genitive => try b.writeAll("G"),
        .dative => try b.writeAll("D"),
        .vocative => try b.writeAll("V"),
        else => return,
    }
    switch (p.number) {
        .singular => try b.writeByte('S'),
        .plural => try b.writeByte('P'),
        else => return,
    }
    switch (p.gender) {
        .masculine => try b.writeByte('M'),
        .feminine => try b.writeByte('F'),
        .neuter => try b.writeByte('N'),
        .masculine_feminine => try b.writeByte('C'),
        .masculine_neuter => try b.writeByte('C'),
        .masculine_feminine_neuter => try b.writeByte('C'),
        .unknown => try b.writeByte('U'),
    }
}

inline fn append_cng(p: Parsing, b: *std.Io.Writer) !void {
    switch (p.case) {
        .nominative => try b.writeAll("-N"),
        .accusative => try b.writeAll("-A"),
        .genitive => try b.writeAll("-G"),
        .dative => try b.writeAll("-D"),
        .vocative => try b.writeAll("-V"),
        else => return,
    }
    switch (p.number) {
        .singular => try b.writeByte('S'),
        .plural => try b.writeByte('P'),
        else => return,
    }
    switch (p.gender) {
        .masculine => try b.writeByte('M'),
        .feminine => try b.writeByte('F'),
        .neuter => try b.writeByte('N'),
        .masculine_feminine => try b.writeByte('C'),
        .masculine_neuter => try b.writeByte('C'),
        .masculine_feminine_neuter => try b.writeByte('C'),
        .unknown => {},
        //.unknown => try b.writeByte('U'),
    }
}

inline fn append_fcng(
    p: Parsing,
    b: *std.Io.Writer,
) (std.Io.Writer.Error || error{Incomplete})!void {
    if (p.person != .unknown) {
        try b.writeByte('-');
    }
    try append_person(p, b);
    switch (p.case) {
        .nominative => try b.writeByte('N'),
        .accusative => try b.writeByte('A'),
        .genitive => try b.writeByte('G'),
        .dative => try b.writeByte('D'),
        .vocative => try b.writeByte('V'),
        else => return,
    }
    switch (p.number) {
        .singular => try b.writeByte('S'),
        .plural => try b.writeByte('P'),
        else => return,
    }
    switch (p.gender) {
        .masculine => try b.writeByte('M'),
        .feminine => try b.writeByte('F'),
        .neuter => try b.writeByte('N'),
        .masculine_feminine => try b.writeByte('C'),
        .masculine_neuter => try b.writeByte('C'),
        .masculine_feminine_neuter => try b.writeByte('C'),
        .unknown => try b.writeByte('U'),
    }
}

inline fn append_vp(p: Parsing, b: *std.Io.Writer) !void {
    switch (p.tense_form) {
        .present => try b.writeAll("-P"),
        .imperfect => try b.writeAll("-I"),
        .future => try b.writeAll("-F"),
        .aorist => try b.writeAll("-A"),
        .perfect => try b.writeAll("-R"),
        .pluperfect => try b.writeAll("-L"),
        .second_aorist => try b.writeAll("-2A"),
        .second_future => try b.writeAll("-2F"),
        .second_perfect => try b.writeAll("-2R"),
        .second_pluperfect => try b.writeAll("-2L"),
        else => return,
    }
    switch (p.voice) {
        .active => try b.writeByte('A'),
        .middle => try b.writeByte('M'),
        .passive => try b.writeByte('P'),
        .middle_or_passive => try b.writeByte('E'),
        .middle_deponent => try b.writeByte('D'),
        .passive_deponent => try b.writeByte('O'),
        .middle_or_passive_deponent => try b.writeByte('N'),
        else => return,
    }
    switch (p.mood) {
        .indicative => try b.writeByte('I'),
        .subjunctive => try b.writeByte('S'),
        .optative => try b.writeByte('O'),
        .imperative => try b.writeByte('M'),
        .infinitive => {
            try b.writeByte('N');
            return;
        },
        .participle => {
            try b.writeByte('P');
            try append_cng(p, b);
            return;
        },
        else => return,
    }

    switch (p.person) {
        .first => try b.writeAll("-1"),
        .second => try b.writeAll("-2"),
        .third => try b.writeAll("-3"),
        else => return,
    }
    switch (p.number) {
        .singular => try b.writeByte('S'),
        .plural => try b.writeByte('P'),
        else => return,
    }
}

inline fn append_flag(p: Parsing, b: *std.Io.Writer) !void {
    if (p.correlative) {
        try b.writeAll("-K");
    }
    if (p.crasis) {
        try b.writeAll("-K");
    }
    if (p.negative) {
        try b.writeAll("-N");
    }
    if (p.interrogative) {
        try b.writeAll("-I");
    }
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;
const expectEqualStrings = std.testing.expectEqualStrings;

test "parsing_format" {
    const gpa = std.testing.allocator;
    var out = std.Io.Writer.Allocating.init(gpa);
    defer out.deinit();

    // Some basic sanity checks.
    {
        out.clearRetainingCapacity();
        try (Parsing{
            .part_of_speech = .noun,
            .case = .nominative,
            .number = .singular,
            .gender = .masculine,
        }).string(&out.writer);
        try expectEqualStrings("N-NSM", out.written());
    }

    {
        out.clearRetainingCapacity();
        const ct = try std.fmt.allocPrint(gpa, "{f}", .{Parsing{
            .part_of_speech = .noun,
            .case = .nominative,
            .number = .singular,
            .gender = .masculine,
        }});
        defer gpa.free(ct);
        try expectEqualStrings("N-NSM", ct);
    }
}

test "simple byz string tests" {
    const gpa = std.testing.allocator;
    var out = std.Io.Writer.Allocating.init(gpa);
    defer out.deinit();

    // Some basic sanity checks.
    {
        out.clearRetainingCapacity();
        try (Parsing{
            .part_of_speech = .noun,
            .case = .nominative,
            .number = .singular,
            .gender = .masculine,
        }).string(&out.writer);
        try expectEqualStrings("N-NSM", out.written());
    }

    {
        out.clearRetainingCapacity();
        try (Parsing{
            .part_of_speech = .adjective,
            .case = .genitive,
            .number = .plural,
            .gender = .feminine,
        }).string(&out.writer);
        try expectEqualStrings("A-GPF", out.written());
    }

    {
        out.clearRetainingCapacity();
        const p = Parsing{
            .part_of_speech = .verb,
            .tense_form = .present,
            .voice = .active,
            .mood = .indicative,
            .person = .first,
            .number = .plural,
        };
        try p.string(&out.writer);
        try expectEqualStrings("V-PAI-1P", out.written());
    }

    {
        out.clearRetainingCapacity();
        const p = Parsing{
            .part_of_speech = .personal_pronoun,
            .case = .nominative,
            .person = .first,
            .tense_form = .ref_singular,
        };
        try p.string(&out.writer);
        try expectEqualStrings("P-1NS", out.written());
    }
}

test "packed parsing" {
    var p: Parsing = .{
        .part_of_speech = .noun,
    };
    p.person = .first;
    var p2: Parsing = .{};
    p2.person = .first;
}
