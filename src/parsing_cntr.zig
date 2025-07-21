//! Read parsing information as described by the greek
//! cntr. See: https://greekcntr.org/resources/NTGRG.pdf

// Provide the two parsing fields as one string with
// spaces or tabs separating the two fields.

//     const parsing = parse("V       IAA3..S");
pub fn parse(value: []const u8) !Parsing {
    var parsing: Parsing = .default;
    var tag: []const u8 = value;

    if (tag.len == 0) return error.Incomplete;

    // See page 3 of the PDF.
    parsing.part_of_speech = switch (tag[0]) {
        'N' => .noun,
        'R' => .pronoun,
        'A' => .adjective,
        'V' => .verb,
        'D' => .adverb,
        'P' => .preposition,
        'C' => .conjunction,
        'I' => .interjection,
        'X' => .particle,
        'E' => .article, // Not in PDF, seen in SR.tsv
        'S' => .adjective, // Not in PDF, seen in SR.tsv
        'T' => .particle, // Mostly conditionals and negative particles.
        else => return error.UnknownPartOfSpeech,
    };

    // Skip the separating characters
    tag = tag[1..];
    while (tag.len > 0 and tag[0] == ' ' or tag[0] == '\t') {
        tag = tag[1..];
    }

    if (tag.len < 7) {
        return parsing;
    }

    switch (tag[0]) {
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
            err("CNTR parsing character unrecognised: {c}", .{tag[0]});
            return error.UnrecognisedValue;
        },
    }

    parsing.tense_form = switch (tag[1]) {
        'P' => .present,
        'F' => .future,
        'A' => .aorist,
        'I' => .imperfect,
        'E' => .perfect,
        'L' => .pluperfect,
        'U', ' ', '-', '.' => .unknown,
        else => return error.UnknownTenseForm,
    };

    parsing.voice = switch (tag[2]) {
        'A' => .active,
        'M' => .middle,
        'P' => .passive,
        ' ', '-', '.' => .unknown,
        else => return error.UnknownVoice,
    };

    parsing.person = switch (tag[3]) {
        '1' => .first,
        '2' => .second,
        '3' => .third,
        ' ', '-', '.' => .unknown,
        else => return error.UnknownPerson,
    };

    parsing.case = switch (tag[4]) {
        'N' => .nominative,
        'G' => .genitive,
        'D' => .dative,
        'A' => .accusative,
        'V' => .vocative,
        ' ', '-', '.' => .unknown,
        else => return error.UnknownCase,
    };

    parsing.gender = switch (tag[5]) {
        'M' => .masculine,
        'F' => .feminine,
        'N' => .neuter,
        ' ', '-', '.' => .unknown,
        else => return error.UnknownGender,
    };

    parsing.number = switch (tag[6]) {
        'S' => .singular,
        'P' => .plural,
        'A' => .unknown, // A=Any. Is this useful?
        ' ', '-', '.' => .unknown,
        else => return error.UnknownNumber,
    };

    return parsing;
}

test "basic cntr parsing" {
    {
        const p = try parse("V       IAA3..S");
        try ee(.verb, p.part_of_speech);
        try ee(.aorist, p.tense_form);
        try ee(.active, p.voice);
        try ee(.indicative, p.mood);
        try ee(.third, p.person);
        try ee(.singular, p.number);
    }
    {
        const p = try parse("R       ....GFS");
        try ee(.pronoun, p.part_of_speech);
        try ee(.genitive, p.case);
        try ee(.singular, p.number);
        try ee(.feminine, p.gender);
    }
    {
        const p = try parse("N       ....AMS");
        try ee(.noun, p.part_of_speech);
        try ee(.accusative, p.case);
        try ee(.singular, p.number);
        try ee(.masculine, p.gender);
    }
}

const Parsing = @import("parsing.zig").Parsing;
const std = @import("std");
const err = std.log.err;
const ee = std.testing.expectEqual;
