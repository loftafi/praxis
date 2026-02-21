/// convert a byzantine text style parsing string into
/// a u32 by reading from a u8 string, or return an
/// error if it is inavlid.
pub fn parse(data: []const u8) Parsing.Error!Parsing {
    if (data.len == 0) {
        return Parsing.Error.Incomplete;
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
inline fn parse_data(t: *Tokenizer) Parsing.Error!Parsing {
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
                return error.UnknownPartOfSpeech;
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
        return error.UnknownPartOfSpeech;
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

inline fn parse_personal_pronoun(t: *Tokenizer) !void {
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
fn parse_cng(t: *Tokenizer) !void {
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

pub const Tokenizer = struct {
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

    try expectError(error.UnknownPartOfSpeech, parse("M-GSF"));
    try expectError(error.Incomplete, parse("A-GS"));
    try expectError(error.Incomplete, parse("V"));
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

const std = @import("std");
const err = std.log.err;
const debug = std.log.debug;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectError = std.testing.expectError;

const Parsing = @import("parsing.zig").Parsing;
const Number = Parsing.Number;
const Person = Parsing.Person;
const Case = Parsing.Case;
const Gender = Parsing.Gender;
