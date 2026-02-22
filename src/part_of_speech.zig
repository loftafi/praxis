const std = @import("std");
const Parsing = @import("parsing.zig").Parsing;

pub const PartOfSpeech = enum(u5) {
    unknown = 0,
    particle = 1,
    verb = 2,
    noun = 3,
    adjective = 4,
    adverb = 5,
    conjunction = 6,
    proper_noun = 7,
    preposition = 8,
    conditional = 9,
    article = 10,
    interjection = 11,
    pronoun = 12,
    personal_pronoun = 13,
    possessive_pronoun = 14,
    relative_pronoun = 15,
    demonstrative_pronoun = 16,
    reciprocal_pronoun = 17,
    reflexive_pronoun = 18,
    transliteration = 19,
    hebrew_transliteration = 20,
    aramaic_transliteration = 21,
    letter = 22,
    numeral = 23,
    superlative_adjective = 24,
    superlative_adverb = 25,
    superlative_noun = 26,
    comparative_adjective = 27,
    comparative_adverb = 28,
    comparative_noun = 29,
};

pub fn parse_pos(text: []const u8) Parsing {
    if (text.len > 40) {
        return Parsing{ .part_of_speech = .unknown };
    }
    var buffer: [40]u8 = undefined;
    const value = std.ascii.lowerString(&buffer, text);

    const hashmap = std.StaticStringMap(Parsing).initComptime(.{
        .{ "verb", Parsing{ .part_of_speech = .verb } },
        .{ "noun", Parsing{ .part_of_speech = .noun } },
        .{ "article", Parsing{ .part_of_speech = .article } },
        .{ "definitearticle", Parsing{ .part_of_speech = .article } },
        .{ "definite article", Parsing{ .part_of_speech = .article } },
        .{ "definite-article", Parsing{ .part_of_speech = .article } },
        .{ "definite_article", Parsing{ .part_of_speech = .article } },
        .{ "adverb", Parsing{ .part_of_speech = .adverb } },
        .{ "adjective", Parsing{ .part_of_speech = .adjective } },
        .{ "pronoun", Parsing{ .part_of_speech = .pronoun } },
        .{ "particle", Parsing{ .part_of_speech = .particle } },
        .{ "preposition", Parsing{ .part_of_speech = .preposition } },
        .{ "conjunction", Parsing{ .part_of_speech = .conjunction } },
        .{ "conditional", Parsing{ .part_of_speech = .conditional } },
        .{ "interjection", Parsing{ .part_of_speech = .interjection } },
        .{ "relativepronoun", Parsing{ .part_of_speech = .relative_pronoun } },
        .{ "relative pronoun", Parsing{ .part_of_speech = .relative_pronoun } },
        .{ "relative-pronoun", Parsing{ .part_of_speech = .relative_pronoun } },
        .{ "relative_pronoun", Parsing{ .part_of_speech = .relative_pronoun } },
        .{ "interrogativepronoun", Parsing{ .part_of_speech = .pronoun, .interrogative = true } },
        .{ "interrogative pronoun", Parsing{ .part_of_speech = .pronoun, .interrogative = true } },
        .{ "interrogative-pronoun", Parsing{ .part_of_speech = .pronoun, .interrogative = true } },
        .{ "interrogative_pronoun", Parsing{ .part_of_speech = .pronoun, .interrogative = true } },
        .{ "indefinitepronoun", Parsing{ .part_of_speech = .pronoun, .indefinite = true } },
        .{ "indefinite pronoun", Parsing{ .part_of_speech = .pronoun, .indefinite = true } },
        .{ "indefinite-pronoun", Parsing{ .part_of_speech = .pronoun, .indefinite = true } },
        .{ "indefinite_pronoun", Parsing{ .part_of_speech = .pronoun, .indefinite = true } },
        .{ "reciprocalpronoun", Parsing{ .part_of_speech = .reciprocal_pronoun } },
        .{ "reciprocal pronoun", Parsing{ .part_of_speech = .reciprocal_pronoun } },
        .{ "reciprocal-pronoun", Parsing{ .part_of_speech = .reciprocal_pronoun } },
        .{ "reciprocal_pronoun", Parsing{ .part_of_speech = .reciprocal_pronoun } },
        .{ "demonstrativepronoun", Parsing{ .part_of_speech = .demonstrative_pronoun } },
        .{ "demonstrative pronoun", Parsing{ .part_of_speech = .demonstrative_pronoun } },
        .{ "demonstrative-pronoun", Parsing{ .part_of_speech = .demonstrative_pronoun } },
        .{ "demonstrative_pronoun", Parsing{ .part_of_speech = .demonstrative_pronoun } },
        .{ "reflexivepronoun", Parsing{ .part_of_speech = .reflexive_pronoun } },
        .{ "reflexive pronoun", Parsing{ .part_of_speech = .reflexive_pronoun } },
        .{ "reflexive-pronoun", Parsing{ .part_of_speech = .reflexive_pronoun } },
        .{ "reflexive_pronoun", Parsing{ .part_of_speech = .reflexive_pronoun } },
        .{ "possessivepronoun", Parsing{ .part_of_speech = .possessive_pronoun } },
        .{ "possessive pronoun", Parsing{ .part_of_speech = .possessive_pronoun } },
        .{ "possessive-pronoun", Parsing{ .part_of_speech = .possessive_pronoun } },
        .{ "possessive_pronoun", Parsing{ .part_of_speech = .possessive_pronoun } },
        .{ "personalpronoun", Parsing{ .part_of_speech = .personal_pronoun } },
        .{ "personal pronoun", Parsing{ .part_of_speech = .personal_pronoun } },
        .{ "personal-pronoun", Parsing{ .part_of_speech = .personal_pronoun } },
        .{ "personal_pronoun", Parsing{ .part_of_speech = .personal_pronoun } },
        .{ "propernoun", Parsing{ .part_of_speech = .proper_noun } },
        .{ "proper noun", Parsing{ .part_of_speech = .proper_noun } },
        .{ "proper-noun", Parsing{ .part_of_speech = .proper_noun } },
        .{ "proper_noun", Parsing{ .part_of_speech = .proper_noun } },
        .{ "interrogativeparticle", Parsing{ .part_of_speech = .particle, .interrogative = true } },
        .{ "interrogative particle", Parsing{ .part_of_speech = .particle, .interrogative = true } },
        .{ "interrogative_particle", Parsing{ .part_of_speech = .particle, .interrogative = true } },
        //.{ "interrogativepropernoun", .{ .part_of_speech = .proper_noun, .interrogative = true } },
        //.{ "interrogative_proper_noun", .{ .part_of_speech = .proper_noun, .interrogative = true } },
        //.{ "interrogative proper noun", .{ .part_of_speech = .proper_noun, .interrogative = true } },
        //.{ "interrogative-proper-noun", .{ .part_of_speech = .proper_noun, .interrogative = true } },
        .{ "indeclinablepropernoun", Parsing{ .part_of_speech = .proper_noun, .indeclinable = true } },
        .{ "indeclinable_proper_noun", Parsing{ .part_of_speech = .proper_noun, .indeclinable = true } },
        .{ "indeclinable proper noun", Parsing{ .part_of_speech = .proper_noun, .indeclinable = true } },
        .{ "indeclinable-proper-noun", Parsing{ .part_of_speech = .proper_noun, .indeclinable = true } },
        .{ "transliteration", Parsing{ .part_of_speech = .transliteration } },
        .{ "aramaic_transliteration", Parsing{ .part_of_speech = .aramaic_transliteration } },
        .{ "aramaic-transliteration", Parsing{ .part_of_speech = .aramaic_transliteration } },
        .{ "aramaic transliteration", Parsing{ .part_of_speech = .aramaic_transliteration } },
        .{ "aramaictransliteration", Parsing{ .part_of_speech = .aramaic_transliteration } },
        .{ "hebrewtransliteration", Parsing{ .part_of_speech = .hebrew_transliteration } },
        .{ "hebrew_transliteration", Parsing{ .part_of_speech = .hebrew_transliteration } },
        .{ "hebrew-transliteration", Parsing{ .part_of_speech = .hebrew_transliteration } },
        .{ "hebrew transliteration", Parsing{ .part_of_speech = .hebrew_transliteration } },
        .{ "superlativeadjective", Parsing{ .part_of_speech = .superlative_adjective } },
        .{ "superlative adjective", Parsing{ .part_of_speech = .superlative_adjective } },
        .{ "superlative-adjective", Parsing{ .part_of_speech = .superlative_adjective } },
        .{ "superlative_adjective", Parsing{ .part_of_speech = .superlative_adjective } },
        .{ "superlativenoun", Parsing{ .part_of_speech = .superlative_noun } },
        .{ "superlative_noun", Parsing{ .part_of_speech = .superlative_noun } },
        .{ "superlative-noun", Parsing{ .part_of_speech = .superlative_noun } },
        .{ "superlative noun", Parsing{ .part_of_speech = .superlative_noun } },
        .{ "superlativeadverb", Parsing{ .part_of_speech = .superlative_adverb } },
        .{ "superlative_adverb", Parsing{ .part_of_speech = .superlative_adverb } },
        .{ "superlative-adverb", Parsing{ .part_of_speech = .superlative_adverb } },
        .{ "superlative adverb", Parsing{ .part_of_speech = .superlative_adverb } },
        .{ "superlativeadjective", Parsing{ .part_of_speech = .superlative_adjective } },
        .{ "comparative adjective", Parsing{ .part_of_speech = .comparative_adjective } },
        .{ "comparative-adjective", Parsing{ .part_of_speech = .comparative_adjective } },
        .{ "comparative_adjective", Parsing{ .part_of_speech = .comparative_adjective } },
        .{ "comparativenoun", Parsing{ .part_of_speech = .comparative_noun } },
        .{ "comparative_noun", Parsing{ .part_of_speech = .comparative_noun } },
        .{ "comparative-noun", Parsing{ .part_of_speech = .comparative_noun } },
        .{ "comparative noun", Parsing{ .part_of_speech = .comparative_noun } },
        .{ "comparativeadverb", Parsing{ .part_of_speech = .comparative_adverb } },
        .{ "comparative_adverb", Parsing{ .part_of_speech = .comparative_adverb } },
        .{ "comparative-adverb", Parsing{ .part_of_speech = .comparative_adverb } },
        .{ "comparative adverb", Parsing{ .part_of_speech = .comparative_adverb } },
        .{ "numeral", Parsing{ .part_of_speech = .numeral } },
        .{ "letter", Parsing{ .part_of_speech = .letter } },
        .{ "unknown", Parsing{ .part_of_speech = .unknown } },
    });
    const result = hashmap.get(value);
    if (result == null) {
        return .{};
    }
    return result.?;
}

//const expectEqual = std.testing.expectEqual;
const eq = @import("std").testing.expectEqual;
const seq = @import("std").testing.expectEqualStrings;

test "pos_to_string" {
    try seq("Numeral", english(Parsing{ .part_of_speech = .numeral }));
    try seq("Noun", english(Parsing{ .part_of_speech = .noun }));
    try eq(Parsing{ .part_of_speech = .proper_noun }, parse_pos("Proper Noun"));
    try eq(Parsing{ .part_of_speech = .proper_noun }, parse_pos("proper_noun"));
    try eq(Parsing{ .part_of_speech = .letter }, parse_pos("letter"));
    try eq(Parsing{ .part_of_speech = .unknown }, parse_pos("fishing"));

    inline for (comptime std.enums.values(PartOfSpeech)) |f| {
        const value = english(.{ .part_of_speech = f });
        const reverse = parse_pos(value);
        //std.debug.print("check {any} {any} {any}\n", .{ f, value, reverse.part_of_speech });
        try eq(f, reverse.part_of_speech);
    }
}
