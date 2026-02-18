const std = @import("std");
pub const PartOfSpeech = @import("part_of_speech.zig").PartOfSpeech;

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
};

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

pub const Error = error{ InvalidParsing, Incomplete, InvalidGender };

/// convert a byzantine text style parsing string into
/// a u32 by reading from a u8 string, or return an
/// error if it is inavlid.
pub fn parse(data: []const u8) !Parsing {
    if (data.len == 0) {
        return Error.Incomplete;
    }
    var t: Tokenizer = .{
        .data = data,
        .index = 0,
        .limit = data.len,
        .parsing = .{},
    };
    return parse_data(&t);
}

/// convert a byzantine text style parsing string into
/// a u32 by reading from a tokenizer object, or return
/// an error if it is inavlid.
pub fn parse_data(t: *Tokenizer) !Parsing {
    t.skip();
    const c = t.next();
    const p = t.peek();
    if (p == '-' or p == 0) {
        _ = t.next();
        switch (c) {
            'V', 'v' => {
                t.parsing.part_of_speech = .verb;
                try parse_vp(t);
                return t.parsing;
            },
            'N', 'n' => {
                t.parsing.part_of_speech = .noun;
                try parse_cng(t);
                return t.parsing;
            },
            'A', 'a' => {
                t.parsing.part_of_speech = .adjective;
                try parse_cng(t);
                return t.parsing;
            },
            'R', 'r' => {
                t.parsing.part_of_speech = .relative_pronoun;
                try parse_cng(t);
                return t.parsing;
            },
            'C', 'c' => {
                t.parsing.part_of_speech = .reciprocal_pronoun;
                try parse_cng(t);
                return t.parsing;
            },
            'D', 'd' => {
                t.parsing.part_of_speech = .demonstrative_pronoun;
                try parse_cng(t);
                return t.parsing;
            },
            'T', 't' => {
                t.parsing.part_of_speech = .article;
                try parse_cng(t);
                return t.parsing;
            },
            'O', 'o' => {
                t.parsing.part_of_speech = .pronoun;
                try parse_cng(t);
                return t.parsing;
            },
            'K', 'k' => {
                t.parsing.part_of_speech = .pronoun;
                t.parsing.correlative = true;
                try parse_cng(t);
                return t.parsing;
            },
            'I', 'i' => {
                t.parsing.part_of_speech = .pronoun;
                t.parsing.interrogative = true;
                try parse_cng(t);
                return t.parsing;
            },
            'X', 'x' => {
                t.parsing.part_of_speech = .pronoun;
                t.parsing.indefinite = true;
                try parse_cng(t);
                return t.parsing;
            },
            'Q', 'q' => {
                t.parsing.part_of_speech = .pronoun;
                t.parsing.interrogative = true;
                t.parsing.correlative = true;
                try parse_cng(t);
                return t.parsing;
            },
            'F', 'f' => {
                t.parsing.part_of_speech = .reflexive_pronoun;
                if (p == '-') {
                    try parse_person(t);
                }
                try parse_cng(t);
                return t.parsing;
            },
            'S', 's' => {
                t.parsing.part_of_speech = .possessive_pronoun;
                // What is the meaning of the character data[3]?
                // See https://github.com/byztxt/byzantine-majority-text/issues/10
                //_ = t.next();
                try parse_ref(t);
                try parse_cng(t);
                return t.parsing;
            },
            'P', 'p' => {
                t.parsing.part_of_speech = .personal_pronoun;
                try parse_personal_pronoun(t);
                return t.parsing;
            },
            else => {
                return error.InvalidParsing;
            },
        }
    }

    // Two letter pos
    if (c == 'P' and p == 'N') {
        _ = t.next(); // Consume the N
        const x = t.peek();
        if (x == '-' or x == 0) {
            _ = t.next(); // Consume the -
            t.parsing.part_of_speech = .proper_noun;
            try parse_cng(t);
            return t.parsing;
        }
        return error.InvalidParsing;
    }

    // Three letter pos
    const d = t.next();
    const e = t.next();
    if ((c == 'A' or c == 'a') and (d == 'D' or d == 'd') and (e == 'V' or e == 'v')) {
        t.parsing.part_of_speech = .adverb;
        try parse_flag(t);
        return t.parsing;
    }
    if ((c == 'P' or c == 'p') and (d == 'R' or d == 'r') and (e == 'T' or e == 't')) {
        t.parsing.part_of_speech = .particle;
        try parse_flag(t);
        return t.parsing;
    }
    if ((c == 'I' or c == 'i') and (d == 'N' or d == 'n') and (e == 'J' or e == 'j')) {
        t.parsing.part_of_speech = .interjection;
        try parse_flag(t);
        return t.parsing;
    }
    if ((c == 'H' or c == 'h') and (d == 'E' or d == 'e') and (e == 'B' or e == 'b')) {
        t.parsing.part_of_speech = .hebrew_transliteration;
        try parse_flag(t);
        return t.parsing;
    }
    // Four letter pos
    const f = t.next();
    if ((c == 'C' or c == 'c') and (d == 'O' or d == 'o') and (e == 'N' or e == 'n')) {
        if (f == 'D' or f == 'd') {
            t.parsing.part_of_speech = .conditional;
            try parse_flag(t);
            return t.parsing;
        }
        if (f == 'J' or f == 'j') {
            t.parsing.part_of_speech = .conjunction;
            try parse_flag(t);
            return t.parsing;
        }
    }
    if ((c == 'A' or c == 'a') and (d == 'R' or d == 'r') and (e == 'A' or e == 'a') and (f == 'M' or f == 'm')) {
        t.parsing.part_of_speech = .aramaic_transliteration;
        try parse_flag(t);
        return t.parsing;
    }
    if ((c == 'P' or c == 'p') and (d == 'R' or d == 'r') and (e == 'E' or e == 'e') and (f == 'P' or f == 'p')) {
        t.parsing.part_of_speech = .preposition;
        try parse_flag(t);
        return t.parsing;
    }

    return error.InvalidParsing;
}

/// Parse the verb part of a verb parsing string
fn parse_vp(t: *Tokenizer) !void {
    // tense-form
    const c = t.next();
    if (c == '2') {
        switch (t.next()) {
            'F', 'f' => {
                t.parsing.tense_form = .second_future;
            },
            'A', 'a' => {
                t.parsing.tense_form = .second_aorist;
            },
            'R', 'r' => {
                t.parsing.tense_form = .second_perfect;
            },
            'L', 'l' => {
                t.parsing.tense_form = .second_pluperfect;
            },
            0 => {
                return error.Incomplete;
            },
            else => {
                return error.InvalidParsing;
            },
        }
    } else {
        switch (c) {
            'P', 'p' => {
                t.parsing.tense_form = .present;
            },
            'I', 'i' => {
                t.parsing.tense_form = .imperfect;
            },
            'F', 'f' => {
                t.parsing.tense_form = .future;
            },
            'A', 'a' => {
                t.parsing.tense_form = .aorist;
            },
            'R', 'r' => {
                t.parsing.tense_form = .perfect;
            },
            'L', 'l' => {
                t.parsing.tense_form = .pluperfect;
            },
            0 => {
                return error.Incomplete;
            },
            else => {
                return error.InvalidParsing;
            },
        }
    }
    switch (t.next()) {
        'A', 'a' => {
            t.parsing.voice = .active;
        },
        'M', 'm' => {
            t.parsing.voice = .middle;
        },
        'P', 'p' => {
            t.parsing.voice = .passive;
        },
        'E', 'e' => {
            t.parsing.voice = .middle_or_passive;
        },
        'D', 'd' => {
            t.parsing.voice = .middle_deponent;
        },
        'O', 'o' => {
            t.parsing.voice = .passive_deponent;
        },
        'N', 'n' => {
            t.parsing.voice = .middle_or_passive_deponent;
        },
        0 => {
            return error.Incomplete;
        },
        else => {
            return error.InvalidParsing;
        },
    }
    switch (t.next()) {
        'I', 'i' => {
            t.parsing.mood = .indicative;
        },
        'M', 'm' => {
            t.parsing.mood = .imperative;
        },
        'O', 'o' => {
            t.parsing.mood = .optative;
        },
        'N', 'n' => {
            t.parsing.mood = .infinitive;
            try parse_flag(t);
            return;
        },
        'P', 'p' => {
            t.parsing.mood = .participle;
        },
        'S', 's' => {
            t.parsing.mood = .subjunctive;
        },
        0 => {
            return error.Incomplete;
        },
        else => {
            return error.InvalidParsing;
        },
    }

    if (t.next() != '-') {
        return error.Incomplete;
    }
    if (t.parsing.mood == .participle) {
        try parse_cng(t);
        return;
    }

    switch (t.next()) {
        '1' => {
            t.parsing.person = .first;
        },
        '2' => {
            t.parsing.person = .second;
        },
        '3' => {
            t.parsing.person = .third;
        },
        0 => {
            return error.Incomplete;
        },
        else => {
            return error.InvalidParsing;
        },
    }

    switch (t.next()) {
        'S', 's' => {
            t.parsing.number = .singular;
        },
        'P', 'p' => {
            t.parsing.number = .plural;
        },
        'D', 'd' => {
            t.parsing.number = .dual;
        },
        0 => {
            return error.Incomplete;
        },
        else => {
            return error.InvalidParsing;
        },
    }

    try parse_flag(t);
}

inline fn parse_person(t: *Tokenizer) !void {
    switch (t.next()) {
        '1' => {
            t.parsing.person = .first;
        },
        '2' => {
            t.parsing.person = .second;
        },
        '3' => {
            t.parsing.person = .third;
        },
        0 => {
            return error.Incomplete;
        },
        else => {
            return error.InvalidParsing;
        },
    }
}

inline fn parse_ref(t: *Tokenizer) !void {
    switch (t.next()) {
        '1' => {
            t.parsing.person = .first;
        },
        '2' => {
            t.parsing.person = .second;
        },
        0 => {
            return error.Incomplete;
        },
        else => {
            return error.InvalidParsing;
        },
    }

    switch (t.next()) {
        'S', 's', '1' => {
            t.parsing.tense_form = .ref_singular;
        },
        'P', 'p', '2' => {
            t.parsing.tense_form = .ref_plural;
        },
        0 => {
            return error.Incomplete;
        },
        else => {
            return error.InvalidParsing;
        },
    }
}

pub fn parse_personal_pronoun(t: *Tokenizer) !void {
    switch (t.peek()) {
        '1' => {
            t.parsing.person = .first;
        },
        '2' => {
            t.parsing.person = .second;
        },
        0 => {
            return error.Incomplete;
        },
        else => {
            try parse_cng(t);
            return;
        },
    }
    _ = t.next();

    switch (t.next()) {
        'N', 'n' => {
            t.parsing.case = .nominative;
        },
        'A', 'a' => {
            t.parsing.case = .accusative;
        },
        'G', 'g' => {
            t.parsing.case = .genitive;
        },
        'D', 'd' => {
            t.parsing.case = .dative;
        },
        'V', 'v' => {
            t.parsing.case = .vocative;
        },
        0 => {
            return error.Incomplete;
        },
        else => {
            return error.InvalidParsing;
        },
    }

    switch (t.next()) {
        'S', 's', '1' => {
            t.parsing.tense_form = .ref_singular;
        },
        'P', 'p', '2' => {
            t.parsing.tense_form = .ref_plural;
        },
        0 => {
            return error.Incomplete;
        },
        else => {
            return error.InvalidParsing;
        },
    }

    try parse_flag(t);
}

/// parse a case, number, gender sequence that may appear in
/// a wide variety of different parts of speech.
pub fn parse_cng(t: *Tokenizer) !void {
    // case
    switch (t.next()) {
        'N', 'n' => {
            t.parsing.case = .nominative;
        },
        'A', 'a' => {
            t.parsing.case = .accusative;
        },
        'G', 'g' => {
            t.parsing.case = .genitive;
        },
        'D', 'd' => {
            t.parsing.case = .dative;
        },
        'V', 'v' => {
            t.parsing.case = .vocative;
        },
        'L', 'l' => { // N-LI is letter
            const l = t.next();
            if (l == 'I' or l == 'i') {
                t.parsing.part_of_speech = .letter;
                t.parsing.indeclinable = true;
                try parse_flag(t);
                return;
            }
            return error.InvalidParsing;
        },
        'O', 'o' => { // N-OI is letter
            const l = t.next();
            if (l == 'I' or l == 'i') {
                t.parsing.part_of_speech = .noun;
                t.parsing.indeclinable = true;
                try parse_flag(t);
                return;
            }
            return error.InvalidParsing;
        },
        'P', 'p' => { // N-PRI
            const r = t.next();
            if (r != 'R' and r != 'r') {
                return error.InvalidParsing;
            }
            const l = t.next();
            if (l == 'I' or l == 'i') {
                t.parsing.part_of_speech = .proper_noun;
                t.parsing.indeclinable = true;
                try parse_flag(t);
                return;
            }
            return error.InvalidParsing;
        },
        0 => {
            return error.Incomplete;
        },
        else => {
            return error.InvalidParsing;
        },
    }

    // number
    switch (t.next()) {
        'S', 's', '1' => {
            t.parsing.number = .singular;
        },
        'P', 'p', '2' => {
            t.parsing.number = .plural;
        },
        'U', 'u' => {
            // NUI is a special CNG
            if (t.parsing.case != .nominative) {
                return error.InvalidParsing;
            }
            const p = t.peek();
            if (p == 'I' or p == 'i') {
                t.parsing.case = .unknown;
                t.parsing.part_of_speech = .numeral;
                t.parsing.indeclinable = true;
                _ = t.next();
                try parse_flag(t);
                return;
            }
            return error.InvalidParsing;
        },
        0 => {
            return error.Incomplete;
        },
        else => {
            return error.InvalidParsing;
        },
    }

    // gender
    switch (t.next()) {
        'M', 'm' => {
            t.parsing.gender = .masculine;
        },
        'F', 'f' => {
            t.parsing.gender = .feminine;
        },
        'N', 'n' => {
            t.parsing.gender = .neuter;
        },
        0 => {
            if (t.parsing.part_of_speech != .noun and t.parsing.part_of_speech != .pronoun) {
                return error.Incomplete;
            }
        },
        else => {
            return error.InvalidParsing;
        },
    }

    try parse_flag(t);

    if (!is_breaking(t.next())) {
        return error.InvalidParsing;
    }
}

/// Parse the trailing end component of a parsing string that
/// may or may not appear at the end of the string.
inline fn parse_flag(t: *Tokenizer) !void {
    if (t.peek() == '-') {
        _ = t.next();
        switch (t.next()) {
            'A', 'a' => {
                const x = t.peek();
                if (x == 'T' or x == 't') {
                    _ = t.next();
                    const y = t.peek();
                    if (y != 'T' and y != 't') {
                        return error.InvalidParsing;
                    }
                    _ = t.next();
                } else if (x == 'B' and x == 'B') {
                    _ = t.next();
                    const y = t.peek();
                    if (y != 'B' and y != 'b') {
                        return error.InvalidParsing;
                    }
                    _ = t.next();
                } else {
                    return error.InvalidParsing;
                }
            },
            'I', 'i' => {
                t.parsing.interrogative = true;
            },
            'K', 'k' => {
                if (t.parsing.part_of_speech == .adverb) {
                    t.parsing.correlative = true;
                } else {
                    t.parsing.crasis = true;
                }
            },
            'N', 'n' => {
                t.parsing.negative = true;
            },
            'P', 'p' => {
                // Seen one time in the Nestle parsings in
                // Acts 2:18. It is undocumented what it indicates.
            },
            'C', 'c' => {
                switch (t.parsing.part_of_speech) {
                    .adverb => t.parsing.part_of_speech = .comparative_adverb,
                    .adjective => t.parsing.part_of_speech = .comparative_adjective,
                    .noun => t.parsing.part_of_speech = .comparative_noun,
                    else => return error.InvalidParsing,
                }
            },
            'S', 's' => {
                switch (t.parsing.part_of_speech) {
                    .adverb => t.parsing.part_of_speech = .superlative_adverb,
                    .adjective => t.parsing.part_of_speech = .superlative_adjective,
                    .noun => t.parsing.part_of_speech = .superlative_noun,
                    else => return error.InvalidParsing,
                }
            },
            0 => {
                return error.Incomplete;
            },
            else => {
                return error.InvalidParsing;
            },
        }
    }

    if (!is_breaking(t.next())) {
        return error.InvalidParsing;
    }
}

const Tokenizer = struct {
    data: []const u8,
    index: usize,
    limit: usize,
    parsing: Parsing,

    inline fn next(self: *Tokenizer) u8 {
        if (self.index >= self.limit) {
            return 0;
        }
        const c = self.data[self.index];
        if (c != 0) {
            self.index += 1;
        }
        return c;
    }

    inline fn peek(self: *Tokenizer) u8 {
        if (self.index >= self.limit) {
            return 0;
        }
        return self.data[self.index];
    }

    inline fn skip(self: *Tokenizer) void {
        while (self.index < self.limit) {
            const c = self.data[self.index];
            if (is_breaking(c)) {
                // Increment over valid/plausible leading characters
                self.index += 1;
                continue;
            }
            return;
        }
    }
};

/// returns true for any character that starts or ends a parsing code.
inline fn is_breaking(c: u8) bool {
    return (c == ' ' or c == '{' or c == '}' or c == '[' or c == ']' or c == '(' or c == ')' or c == '.' or c == '\"' or c == '\'' or c == 0);
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;
const expectEqualStrings = std.testing.expectEqualStrings;

test "token reader" {
    const data = "abc";
    var t: Tokenizer = .{
        .data = data,
        .index = 0,
        .limit = data.len,
        .parsing = .{},
    };
    t.skip();
    try expectEqual('a', t.next());
    try expectEqual('b', t.peek());
    try expectEqual('b', t.next());
    t.skip();
    try expectEqual('c', t.next());
}

test "empty token reader" {
    const data = "";
    var t: Tokenizer = .{
        .data = data,
        .index = 0,
        .limit = data.len,
        .parsing = .{},
    };
    t.skip();
    try expectEqual(0, t.peek());
    try expectEqual(0, t.next());
    try expectEqual(0, t.peek());
    t.skip();
    try expectEqual(0, t.next());
}

test "simple parsing tests" {
    // Some basic sanity checks.
    try expectEqual(Parsing{
        .part_of_speech = .noun,
        .case = .nominative,
        .number = .singular,
        .gender = .masculine,
    }, try parse("N-NSM"));
    try expectEqual(Parsing{
        .part_of_speech = .proper_noun,
        .case = .accusative,
        .number = .singular,
        .gender = .masculine,
    }, try parse("PN-ASM"));
    try expectEqual(Parsing{
        .part_of_speech = .pronoun,
        .case = .dative,
        .number = .singular,
        .gender = .neuter,
        .interrogative = true,
    }, try parse("I-DSN"));
    try expectEqual(Parsing{
        .part_of_speech = .article,
        .case = .genitive,
        .number = .plural,
        .gender = .feminine,
    }, try parse("T-GPF"));
    try expectEqual(Parsing{
        .part_of_speech = .verb,
        .tense_form = .present,
        .voice = .active,
        .mood = .indicative,
        .person = .second,
        .number = .plural,
    }, try parse("V-PAI-2P"));
    try expectEqual(Parsing{
        .part_of_speech = .conjunction,
        .negative = true,
    }, try parse("CONJ-N"));
    try expectEqual(Parsing{
        .part_of_speech = .conditional,
        .crasis = true,
    }, try parse("COND-K"));
    try expectEqual(Parsing{
        .part_of_speech = .superlative_adverb,
    }, try parse("ADV-S"));
    try expectEqual(Parsing{
        .part_of_speech = .comparative_adverb,
    }, try parse("ADV-C"));
    try expectEqual(Parsing{
        .part_of_speech = .personal_pronoun,
        .case = .nominative,
        .person = .first,
        .tense_form = .ref_singular,
    }, try parse("P-1NS"));

    try expectError(error.InvalidParsing, parse("M-GSF"));
    try expectError(error.Incomplete, parse("A-GS"));
    try expectError(error.Incomplete, parse("V"));
}

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

test "new_parsing" {
    const gpa = std.testing.allocator;

    var out = std.Io.Writer.Allocating.init(gpa);
    defer out.deinit();

    // Test parsing not in byz file
    const data = "I-GSN\nI-DSM\nO-ASN";
    var items = std.mem.tokenizeAny(u8, data, " \r\n");
    while (items.next()) |item| {

        // Test entry exactly as in the file.
        {
            const x = parse(item) catch |e| {
                std.debug.print("Failed: {s} {any}\n", .{ item, e });
                _ = try parse(item);
                return;
            };
            try expect(x.part_of_speech != .unknown);
            out.clearRetainingCapacity();
            try x.string(&out.writer);
            try expectEqualStrings(item, out.written());
        }
    }
}

test "byz data test" {
    const gpa = std.testing.allocator;

    var out = std.Io.Writer.Allocating.init(gpa);
    defer out.deinit();

    const byz_data = @embedFile("byz_parsing");
    var items = std.mem.tokenizeAny(u8, byz_data, " \r\n");
    while (items.next()) |item| {
        // Ignore unhandled types
        if (std.ascii.endsWithIgnoreCase(item, "-att")) {
            continue;
        }
        if (std.ascii.endsWithIgnoreCase(item, "-abb")) {
            continue;
        }
        if (std.ascii.endsWithIgnoreCase(item, "-p")) {
            continue;
        }

        // Test entry exactly as in the file.
        {
            const x = parse(item) catch |e| {
                std.debug.print("Failed: {s} {any}\n", .{ item, e });
                _ = try parse(item);
                return;
            };
            out.clearRetainingCapacity();
            try expect(x.part_of_speech != .unknown);
            try x.string(&out.writer);
            try expectEqualStrings(item, out.written());
        }

        {
            // Test entry when it has brackets
            var item2 = std.Io.Writer.Allocating.init(gpa);
            defer item2.deinit();
            try item2.writer.writeByte(' ');
            try item2.writer.writeByte('[');
            try item2.writer.writeAll(item);
            try item2.writer.writeByte(']');
            const x = parse(item2.written()) catch |e| {
                std.debug.print("Failed: {s} {any}\n", .{ item2.written(), e });
                _ = try parse(item2.written());
                return;
            };
            out.clearRetainingCapacity();
            try x.string(&out.writer);
            try expectEqualStrings(item, out.written());
        }

        {
            // Test entry when it has brackets
            var item2 = std.Io.Writer.Allocating.init(gpa);
            defer item2.deinit();
            try item2.writer.writeAll(item);
            try item2.writer.writeByte('K');
            try expectError(error.InvalidParsing, parse(item2.written()));
        }
    }

    const other_data = @embedFile("other_parsing");
    items = std.mem.tokenizeAny(u8, other_data, " \r\n");
    while (items.next()) |item| {
        // Ignore unhandled types
        if (std.ascii.endsWithIgnoreCase(item, "-att")) continue;
        if (std.ascii.endsWithIgnoreCase(item, "-abb")) continue;
        if (std.ascii.endsWithIgnoreCase(item, "-p")) continue;

        // Test entry exactly as in the file.
        const x = parse(item) catch |e| {
            std.debug.print("Failed: {s} {any}\n", .{ item, e });
            return;
        };
        out.clearRetainingCapacity();
        try x.string(&out.writer);
        try expectEqualStrings(item, out.written());
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
