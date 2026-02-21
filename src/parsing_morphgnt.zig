//! Reads the parsing/tagging fields of the SBL data files in the morphgnt
//! GIT repol
//!
//! https://ccat.sas.upenn.edu/gopher/text/religion/biblical/lxxmorph/
//!
//!    RP ----DP--
//!    RA ----DSF-
//!    V- -PMN----
//!    D- --------
//!    RA ----DPM-
//!    A- ----DPM-
//!    N- ----DSF-
//!    V- 1AAI-S--
//!    V- 1AAI-S--
//!    V- -AAN----
//!    V- -PAPNSM-
//!    V- -APPDSF-
//!    V- 3AAI-P--

/// Read a two part parsing field in the SBL MorphGNT tag format.
pub fn parse(tag: []const u8) Parsing.Error!Parsing {
    var data = tag;
    while (data.len > 0 and (data[0] == ' ' or data[0] == '-')) {
        data = data[1..];
    }

    if (data.len == 0) return error.Incomplete;

    var pi = data;
    pi.len = 0;
    while (data.len > 0 and (data[0] != ' ' and data[0] != '-' and data[0] != '+')) {
        pi.len += 1;
        data = data[1..];
    }

    if (data[0] == '-') data = data[1..];

    var parsing: Parsing = .default;

    const sw = svc(pi);
    switch (sw) {
        sv("N1") => {
            parsing.part_of_speech = .noun;
            parsing.gender = .feminine;
        },
        sv("N2") => {
            parsing.part_of_speech = .noun;
            parsing.gender = .masculine;
        },
        sv("N3") => {
            parsing.part_of_speech = .noun;
        },
        sv("N") => {
            parsing.part_of_speech = .noun;
        },
        sv("A"), sv("A1"), sv("A3") => parsing.part_of_speech = .adjective,
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
        sv("VE"), sv("VH"), sv("VO") => {
            parsing.part_of_speech = .verb;
        },
        else => {
            err("{s} is an unrecognised part of speech.", .{pi});
            return error.UnknownPartOfSpeech;
        },
    }

    while (data.len > 0 and (data[0] == ' ')) {
        data = data[1..];
    }
    if (data.len == 0) {
        return parsing;
    }

    if (data.len < 8) {
        return parsing;
    }

    parsing.person = switch (data[0]) {
        '1' => .first,
        '2' => .second,
        '3' => .third,
        ' ', '-', '.' => .unknown,
        else => {
            err("Unknown person: {c}", .{data[0]});
            return error.UnknownPerson;
        },
    };

    parsing.tense_form = switch (data[1]) {
        'P' => .present,
        'F' => .future,
        'A' => .aorist,
        'I' => .imperfect,
        'E', 'X' => .perfect,
        'L', 'Y' => .pluperfect,
        'U', ' ', '-', '.' => .unknown,
        else => return error.UnknownTenseForm,
    };

    parsing.voice = switch (data[2]) {
        'A' => .active,
        'M' => .middle,
        'P' => .passive,
        ' ', '-', '.' => .unknown,
        else => {
            err("Morph parsing character voice unrecognised: {c} in {s}", .{ data[2], data });
            return error.UnknownVoice;
        },
    };

    switch (data[3]) {
        'I' => {
            if (parsing.part_of_speech == .verb) {
                parsing.mood = .indicative;
            } else {
                parsing.indeclinable = true;
            }
        },
        'S' => {
            if (parsing.part_of_speech == .verb) {
                parsing.mood = .subjunctive;
            } else if (parsing.part_of_speech == .noun) {
                parsing.part_of_speech = .superlative_noun;
            } else if (parsing.part_of_speech == .adverb) {
                parsing.part_of_speech = .superlative_adverb;
            } else if (parsing.part_of_speech == .adjective) {
                parsing.part_of_speech = .superlative_adjective;
            }
        },
        'O' => {
            parsing.mood = .optative;
        },
        'M' => {
            parsing.mood = .imperative;
        },
        'N' => {
            parsing.mood = .infinitive;
        },
        'P' => {
            parsing.mood = .participle;
        },
        'C' => {
            if (parsing.part_of_speech == .noun) {
                parsing.part_of_speech = .comparative_noun;
            } else if (parsing.part_of_speech == .adjective) {
                parsing.part_of_speech = .comparative_adjective;
            } else if (parsing.part_of_speech == .adverb) {
                parsing.part_of_speech = .comparative_adverb;
            }
        },
        'D' => {
            // p = Parsing(uint32(p) | DIMINUTIVE)
        },
        ' ', '-', '.' => {},
        else => {
            err("Morph parsing character unrecognised: {c}", .{data[3]});
            return error.UnrecognisedValue;
        },
    }

    //err("Morph parsing case {c} in {s}", .{ data[4], data });
    parsing.case = switch (data[4]) {
        'N' => .nominative,
        'G' => .genitive,
        'D' => .dative,
        'A' => .accusative,
        'V' => .vocative,
        ' ', '-', '.' => .unknown,
        else => {
            err("Morph parsing case unrecognised: {c} in {s}", .{ data[4], data });
            return error.UnknownCase;
        },
    };

    parsing.number = switch (data[5]) {
        'S' => .singular,
        'P' => .plural,
        'A' => .unknown, // A=Any. Is this useful?
        ' ', '-', '.' => .unknown,
        else => return error.UnknownNumber,
    };

    parsing.gender = switch (data[6]) {
        'M' => .masculine,
        'F' => .feminine,
        'N' => .neuter,
        ' ', '-', '.' => .unknown,
        else => {
            err("Morph parsing gender unrecognised: {c} in {s}", .{ data[4], data });
            return error.UnknownGender;
        },
    };

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

test "basic morphgnt_sbl parsing" {
    {
        const p = try parse("V- 1AAI-S--");
        try ee(.verb, p.part_of_speech);
        try ee(.aorist, p.tense_form);
        try ee(.active, p.voice);
        try ee(.indicative, p.mood);
        try ee(.first, p.person);
        try ee(.singular, p.number);
    }
    {
        const p = try parse("A- ----DPM-");
        try ee(.adjective, p.part_of_speech);
        try ee(.plural, p.number);
        try ee(.masculine, p.gender);
        try ee(.dative, p.case);
    }
    {
        const p = try parse("V- -PAPNSM-");
        try ee(.verb, p.part_of_speech);
        try ee(.present, p.tense_form);
        try ee(.active, p.voice);
        try ee(.participle, p.mood);
        try ee(.nominative, p.case);
        try ee(.singular, p.number);
        try ee(.masculine, p.gender);
    }
}

test "morphgnt_sbl data test" {
    const gpa = std.testing.allocator;

    var out = std.Io.Writer.Allocating.init(gpa);
    defer out.deinit();

    const morph_data = @embedFile("sbl_parsing");
    var items = std.mem.tokenizeAny(u8, morph_data, "\r\n");
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
            try x.string(&out.writer);
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
