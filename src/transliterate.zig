/// Copy the contents of a word into a buffer, converting Greek
/// codepoints into English equivalents.
pub fn transliterateSyllables(
    word: []const u8,
    allow_unicode: bool,
    divider: []const u8,
    buffer: []u8,
) error{ NoSpace, InvalidUtf8 }![]const u8 {
    var n: usize = 0;
    var syllable_buffer: [30][]const u8 = undefined;
    for (try syllables(word, &syllable_buffer)) |slice| {
        if (n > 0) {
            @memcpy(buffer[n .. n + divider.len], divider);
            n += divider.len;
        }
        var i = (try unicode.Utf8View.init(slice)).iterator();
        while (i.nextCodepoint()) |codepoint| {
            const entry = transliterateChar(codepoint, allow_unicode);
            @memcpy(buffer[n .. n + entry.len], entry);
            n += entry.len;
        }
    }
    return buffer[0..n];
}

test "transliterateSyllables" {
    var buffer: [praxis.max_word_size]u8 = undefined;
    try eq("ar-tos", try transliterateSyllables("αρτος", false, "-", &buffer));
    try eq("pa·tēr", try transliterateSyllables("πατήρ", true, "·", &buffer));
    try eq("pa·ter", try transliterateSyllables("πατήρ", false, "·", &buffer));
    try eq("pe-ri-pa-tei", try transliterateSyllables("περιπατει", true, "-", &buffer));
    try eq("en", try transliterateSyllables("ἔν", true, "-", &buffer));
    try eq("a", try transliterateSyllables("ἇ", true, "-", &buffer));
    try eq("to", try transliterateSyllables("τὸ", true, "-", &buffer));
    try eq("ru-o-mai", try transliterateSyllables("ῥυομαι", true, "-", &buffer));
    try eq("Ru、o、mai", try transliterateSyllables("Ῥυομαι", true, "、", &buffer));
    try eq("Tre|chei", try transliterateSyllables("Τρεχει", true, "|", &buffer));
}

/// Copy the contents of a word into a buffer, converting Greek
/// codepoints into English equivalents.
pub fn transliterateWord(
    word: []const u8,
    allow_unicode: bool,
    buffer: []u8,
) error{InvalidUtf8}![]const u8 {
    var i = (try unicode.Utf8View.init(word)).iterator();
    var n: usize = 0;
    while (i.nextCodepoint()) |codepoint| {
        const entry = transliterateChar(codepoint, allow_unicode);
        @memcpy(buffer[n .. n + entry.len], entry);
        n += entry.len;
    }
    return buffer[0..n];
}

test "transliterateWord" {
    var buffer: [praxis.max_word_size]u8 = undefined;
    try eq("artos", try transliterateWord("αρτος", false, &buffer));
    try eq("patēr", try transliterateWord("πατήρ", true, &buffer));
    try eq("pater", try transliterateWord("πατήρ", false, &buffer));
    try eq("en", try transliterateWord("ἔν", true, &buffer));
    try eq("a", try transliterateWord("ἀ", true, &buffer));
    try eq("a", try transliterateWord("ἇ", true, &buffer));
    try eq("to", try transliterateWord("το", true, &buffer));
    try eq("to", try transliterateWord("τό", true, &buffer));
    try eq("to", try transliterateWord("τὸ", true, &buffer));
    try eq("ruomai", try transliterateWord("ῥυομαι", true, &buffer));
    try eq("ruomai", try transliterateWord("ῤυομαι", true, &buffer));
    try eq("Ruomai", try transliterateWord("Ῥυομαι", true, &buffer));
    try eq("peripatei", try transliterateWord("περιπατει", true, &buffer));
    try eq("Trechei", try transliterateWord("Τρεχει", true, &buffer));
}

pub const ACUTE: u21 = '\u{0301}';
pub const GRAVE: u21 = '\u{0300}';
pub const CIRCUMFLEX: u21 = '\u{0302}';
pub const MACRON: u21 = '\u{0304}';
pub const IOTA_SUBSCRIPT: u21 = '\u{0345}';
pub const SMOOTH: u21 = '\u{0313}';
pub const ROUGH: u21 = '\u{0314}';
pub const ACUTE_ALT: u21 = '\u{0341}';
pub const GRAVE_ALT: u21 = '\u{0340}';
pub const CIRCUMFLEX_ALT: u21 = '\u{0342}';
pub const DIAERESIS: u21 = '\u{0308}'; // i.e. ϊ
pub const BREVE: u21 = '\u{0306}'; // i.e. ῐ

/// Return a romanised equivalent of the specified codepoint.
/// if the character does not belong in a romanised version
/// of a word then an empty string is returned.
pub inline fn transliterateChar(codepoint: u21, allow_unicode: bool) []const u8 {
    return switch (codepoint) {
        ' ' => "",
        '\n' => "",
        '\r' => "",
        '\t' => "",
        ACUTE, ACUTE_ALT, CIRCUMFLEX, CIRCUMFLEX_ALT, MACRON, BREVE => "",
        GRAVE, GRAVE_ALT => "",
        DIAERESIS, IOTA_SUBSCRIPT => "",
        'Α', 'Ἀ', 'Ἁ', 'Ἄ', 'Ἆ', 'Ἇ', 'Ἅ', 'Ά', 'Ὰ' => "A",
        'α', 'ᾶ', 'ᾷ', 'ἆ', 'ἇ', 'ἄ', 'ἅ', 'ἀ', 'ἁ', 'ά', 'ὰ', 'ἂ', 'ἃ' => "a",
        'β', 'b' => "b",
        'Β', 'B' => "B",
        'γ', 'g' => "g",
        'Γ', 'G' => "G",
        'δ', 'd' => "d",
        'Δ', 'D' => "D",
        'Ε', 'Ἕ', 'Ἑ', 'Ἐ', 'Έ', 'Ὲ' => "E",
        'ε', 'ἔ', 'ἕ', 'ἐ', 'ἑ', 'ὲ', 'έ', 'ἒ', 'ἓ' => "e",
        'ζ', 'z' => "z",
        'Ζ', 'Z' => "Z",
        'Η', 'Ἡ', 'Ἠ', 'Ή', 'Ὴ', 'Ἦ', 'Ἧ' => if (allow_unicode) "Ē" else "E",
        'ᾗ', 'ᾖ', 'ῃ', 'ᾑ', 'ᾐ', 'ῇ', 'ῄ', 'ῂ', 'ᾔ', 'ᾕ', 'ᾓ', 'ᾒ', 'η', 'ἤ', 'ἥ', 'ἡ', 'ἠ', 'ή', 'ὴ', 'ἢ', 'ἣ', 'ῆ', 'ἦ', 'ἧ' => if (allow_unicode) "ē" else "e",
        'Θ' => "Th",
        'θ' => "th",
        'Ι', 'Ἰ', 'Ἱ', 'Ὶ', 'Ί', 'Ἶ', 'Ἷ' => "I",
        'ι', 'ἴ', 'ἵ', 'ἰ', 'ἱ', 'ί', 'ὶ', 'ἲ', 'ἳ', 'ῖ', 'ἷ', 'ἶ' => "i",
        'κ', 'k' => "k",
        'Κ', 'K' => "K",
        'λ', 'l' => "l",
        'Λ', 'L' => "L",
        'μ', 'm' => "m",
        'Μ', 'M' => "M",
        'ν', 'n' => "n",
        'Ν', 'N' => "N",
        'ξ', 'x' => "x",
        'Ξ', 'X' => "X",
        'ο', 'ό', 'ὸ', 'ὂ', 'ὃ', 'ὄ', 'ὅ', 'ὁ', 'ὀ' => "o",
        'Ο', 'Ὀ', 'Ὁ', 'Ό', 'Ὸ' => "O",
        'π', 'p' => "p",
        'Π', 'P' => "P",
        'ρ', 'ῤ', 'ῥ', 'r' => "r",
        'Ρ', 'R', 'Ῥ' => "R",
        'ς', 'σ', 's' => "s",
        'Σ', 'S' => "S",
        'τ', 't' => "t",
        'Τ', 'T' => "T",
        'υ', 'ὔ', 'ὕ', 'ὐ', 'ὑ', 'ύ', 'ὺ', 'ὒ', 'ὓ', 'ὖ', 'ὗ', 'ῦ', 'ϋ' => "u",
        'Υ', 'Ὑ', 'Ύ', 'Ὺ', 'Ὗ' => "U",
        'φ' => "ph",
        'Φ' => "Ph",
        'χ' => "ch",
        'Χ' => "Ch",
        'ψ' => "ps",
        'Ψ' => "Ps",
        'Ω', 'Ώ', 'Ὼ', 'Ὦ', 'Ὧ' => if (allow_unicode) "Ō" else "O",
        'ω', 'ώ', 'ὼ', 'ὠ', 'ὥ', 'ὤ', 'ὡ', 'ῶ', 'ὧ', 'ὦ', 'ῷ', 'ᾦ', 'ᾧ' => if (allow_unicode) "ō" else "o",
        'ϝ' => "w",
        'f' => "f",
        'F' => "F",
        'h' => "h",
        'H' => "H",
        '᾽' => "'",
        'א' => "'",
        'ב' => "b",
        'ג' => "g",
        'ד' => "d",
        'ה' => "h",
        'ו' => "w",
        'ז' => "z",
        'ח' => "h",
        'ט' => "t",
        'י' => "y",
        'כ', 'ך' => "k",
        'ל' => "l",
        'מ', 'ם' => "m",
        'נ', 'ן' => "n",
        'ס' => "s",
        'ע' => "ʿ", //'a',
        'פ', 'ף' => "p",
        'צ', 'ץ' => "s",
        'ק' => "q",
        'ר' => "r",
        'ש' => "s",
        'ת' => "t",
        '־' => "-",
        else => "",
    };
}

const std = @import("std");
const unicode = std.unicode;
const eq = std.testing.expectEqualStrings;

const praxis = @import("praxis.zig");
const syllables = praxis.syllables;
