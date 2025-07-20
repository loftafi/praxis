//! Reads the parsing/tagging fields of the CCAT data files (characters
//! 26-36) into the standardised `Parsing` struct.
//!
//! Actual CCAT data not included in this repository due to licensing
//! restrictions.
//!
//! https://ccat.sas.upenn.edu/gopher/text/religion/biblical/lxxmorph/

pub fn parse(tag: []const u8) !Parsing {
    var data = tag;
    while (data.len > 0 and (data[0] == ' ' or data[0] == '-')) {
        data = data[1..];
    }

    if (data.len == 0) {
        return error.Incomplete;
    }

    var pi = data;
    pi.len = 0;
    while (data.len > 0 and (data[0] != ' ' and data[0] != '-' and data[0] != '+')) {
        pi.len += 1;
        data = data[1..];
    }

    if (pi[0] == 'V' and pi.len > 1) {
        pi = pi[0..2];
    }

    var parsing: Parsing = .default;

    const sw = svc(pi);
    switch (sw) {
        sv("N1"), sv("N1A"), sv("N1S") => {
            parsing.part_of_speech = .noun;
            parsing.gender = .feminine;
        },
        sv("N1M"), sv("N1T"), sv("N2") => {
            parsing.part_of_speech = .noun;
            parsing.gender = .masculine;
        },
        sv("N2N") => {
            parsing.part_of_speech = .noun;
            parsing.gender = .neuter;
        },
        sv("N3"), sv("N3D"), sv("N3E"), sv("N3G"), sv("N3H"), sv("N3I"), sv("N3K"), sv("N3M"), sv("N3N"), sv("N3P"), sv("N3R"), sv("N3S"), sv("N3T"), sv("N3U"), sv("N3V"), sv("N3W") => {
            parsing.part_of_speech = .noun;
        },
        sv("N"), sv("N3X") => {
            parsing.part_of_speech = .noun;
        },
        sv("A"),
        sv("A1"),
        sv("A1A"),
        sv("A1B"),
        sv("A1C"),
        sv("A1S"),
        sv("A1P"),
        sv("A3"),
        sv("A3P"),
        => parsing.part_of_speech = .adjective,
        sv("A3E"), sv("A3H"), sv("A3N"), sv("A3U"), sv("A3C") => {
            parsing.part_of_speech = .adjective;
        },
        sv("RA") => parsing.part_of_speech = .article,
        sv("RD") => parsing.part_of_speech = .demonstrative_pronoun,
        sv("RI") => {
            parsing.part_of_speech = .pronoun;
            // "RI" doesn't distinguish between these two.
            //parsing.interrogative = true;
            //parsing.indefinite = true;
        },
        sv("RP") => parsing.part_of_speech = .possessive_pronoun,
        sv("RR") => {
            parsing.part_of_speech = .relative_pronoun;
        },
        sv("RX") => {
            parsing.part_of_speech = .relative_pronoun; //Check
            parsing.indefinite = true; // RX  = ὅστις in original ccat.
        },
        sv("C") => parsing.part_of_speech = .conjunction,
        sv("X") => parsing.part_of_speech = .particle,
        sv("I") => parsing.part_of_speech = .interjection,
        sv("M") => {
            parsing.part_of_speech = .numeral;
        },
        sv("P") => parsing.part_of_speech = .preposition,
        sv("D") => parsing.part_of_speech = .adverb,
        sv("V"), sv("V1"), sv("V2"), sv("V3"), sv("V4"), sv("V5") => {
            parsing.part_of_speech = .verb;
        },
        sv("V6"), sv("V7"), sv("V8"), sv("V9"), sv("VA"), sv("VB") => {
            parsing.part_of_speech = .verb;
        },
        sv("VZ"), sv("VC"), sv("VD"), sv("VV"), sv("VS"), sv("VQ") => {
            parsing.part_of_speech = .verb;
        },
        sv("VX"), sv("VM"), sv("VP"), sv("VT"), sv("VK"), sv("VF") => {
            parsing.part_of_speech = .verb;
        },
        sv("VF2"), sv("VF3"), sv("VFX"), sv("VE"), sv("VH"), sv("VO") => {
            parsing.part_of_speech = .verb;
        },
        else => {
            err("{s} is an unrecognised part of speech.", .{pi});
            return error.UnknownPartOfSpeech;
        },
    }

    if (data.len > 0 and data[0] == '+') {
        return parsing;
    }
    while (data.len > 0 and (data[0] == ' ' or data[0] == '-')) {
        data = data[1..];
    }
    if (data.len == 0) {
        return parsing;
    }

    switch (parsing.part_of_speech) {
        .noun,
        .demonstrative_pronoun,
        .pronoun, // .interrogativeOrIndefinitePronoun,
        .possessive_pronoun,
        .relative_pronoun,
        .article,
        => {
            parsing = try caseNumberGender(data[0..], parsing);
        },
        .adjective => parsing = try caseNumberGender(data[0..], parsing),
        .verb => {
            parsing = try verbParsing(data[0..], parsing);
            if (parsing.tense_form == .aorist and (sw == sv("VB") or sw == sv("VZ"))) {
                parsing.tense_form = .second_aorist;
            }
        },
        else => {},
    }

    return parsing;
}

fn verbParsing(tag: []const u8, parsing_: Parsing) !Parsing {
    var parsing = parsing_;
    if (tag.len == 0) return parsing;

    parsing.tense_form = switch (tag[0]) {
        'P' => .present,
        'I' => .imperfect,
        'F' => .future,
        'A' => .aorist,
        'X' => .perfect,
        'Y' => .pluperfect,
        else => {
            err("invalid tense form: {c} (Parsing={any})", .{ tag[0], parsing });
            return error.InvalidTenseForm;
        },
    };

    if (tag.len == 1) return parsing;

    parsing.voice = switch (tag[1]) {
        'A' => .active,
        'M' => .middle,
        'P' => .passive,
        'E' => .middle_or_passive,
        'D' => .middle_deponent,
        'O' => .passive_deponent,
        'N' => .middle_or_passive_deponent,
        else => return error.InvalidVoice,
    };

    if (tag.len == 2) return parsing;

    parsing.mood = switch (tag[2]) {
        'I' => .indicative,
        'S' => .subjunctive,
        'O' => .optative,
        'M', 'D' => .imperative,
        'N' => .infinitive,
        'P' => .participle,
        else => return error.InvalidMood,
    };

    if (parsing.mood == .participle and tag.len > 5)
        parsing = try caseNumberGender(tag[3..], parsing);

    if (tag.len > 3)
        parsing.person = fst(tag[3]);

    if (tag.len > 4)
        parsing.number = n(tag[4]);

    return parsing;
}

// Convert a short 3 character parsing string to a u64 for
// the switch statement.
fn svc(tag: []const u8) usize {
    if (tag.len > 8) {
        @panic("tag too long");
    }
    var u: usize = 0;
    var data = tag;
    while (data.len > 0) {
        u = u * 256;
        u += data[0];
        data = data[1..];
    }
    return u;
}

// Switch statement values an be calculated at comptime
fn sv(comptime tag: []const u8) usize {
    if (tag.len > 8) {
        @compileError("tag too long");
    }
    return svc(tag);
}

fn fst(c: u8) Person {
    return switch (c) {
        '1' => .first,
        '2' => .second,
        '3' => .third,
        else => .unknown,
    };
}

fn n(c: u8) Number {
    return switch (c) {
        'S', '1' => .singular,
        'P', '2' => .plural,
        else => .unknown,
    };
}

// CCAT format allows C/N/G to be blank. So initial characters
// may have been trimed off.
fn caseNumberGender(tag_: []const u8, parsing_: Parsing) error{
    UnknownCase,
    UnknownNumber,
    UnknownGender,
}!Parsing {
    var parsing = parsing_;
    var tag = tag_;

    if (tag.len == 0) return parsing;

    if (!(tag[0] == 'S' or tag[0] == 'P' or tag[0] == '1' or tag[0] == '2')) {
        parsing.case = switch (tag[0]) {
            'N' => .nominative,
            'A' => .accusative,
            'G' => .genitive,
            'D' => .dative,
            'V' => .vocative,
            ' ', '-' => .unknown,
            else => return error.UnknownCase,
        };
        tag = tag[1..];
    }

    if (tag.len > 0) {
        parsing.number = switch (tag[0]) {
            'S', '1' => .singular,
            'P', '2' => .plural,
            ' ', '-' => .plural,
            else => return error.UnknownNumber,
        };
        tag = tag[1..];
    }

    if (tag.len > 0)
        parsing.gender = switch (tag[0]) {
            'M' => .masculine,
            'F' => .feminine,
            'N' => .neuter,
            ' ', '-' => .unknown,
            else => return error.UnknownGender,
        };

    return parsing;
}

test "basic lxx parsing" {
    {
        const p = try parse("VF  FMI3S");
        try ee(.verb, p.part_of_speech);
        try ee(.future, p.tense_form);
        try ee(.middle, p.voice);
        try ee(.indicative, p.mood);
        try ee(.third, p.person);
        try ee(.singular, p.number);
    }
    {
        const p = try parse("N1T NSM");
        try ee(.noun, p.part_of_speech);
        try ee(.nominative, p.case);
        try ee(.singular, p.number);
        try ee(.masculine, p.gender);
    }
    {
        const p = try parse(" N1T-- NSM-- ");
        try ee(.noun, p.part_of_speech);
        try ee(.nominative, p.case);
        try ee(.singular, p.number);
        try ee(.masculine, p.gender);
    }
}

test "ccat data test" {
    var out = std.ArrayList(u8).init(std.testing.allocator);
    defer out.deinit();

    const ccat_data = @embedFile("ccat_parsing");
    var items = std.mem.tokenizeAny(u8, ccat_data, "\r\n");
    var line: usize = 0;
    while (items.next()) |item| {
        {
            // Simple test that this sample data does not fail.
            const x = parse(item) catch |e| {
                std.debug.print("Failed: {s} {any} on line {d}\n", .{ item, e, line });
                _ = try parse(item);
                return;
            };
            out.clearRetainingCapacity();
            try std.testing.expect(x.part_of_speech != .unknown);
            try x.string(out.writer());
            line += 1;
        }
    }
}

const std = @import("std");
const err = std.log.err;
const debug = std.log.debug;
const ee = std.testing.expectEqual;

const Parsing = @import("parsing.zig").Parsing;
const Number = @import("parsing.zig").Number;
const Person = @import("parsing.zig").Person;
const Case = @import("parsing.zig").Case;
const Gender = @import("parsing.zig").Gender;
