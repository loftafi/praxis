/// Copy the contents of a word into a buffer, converting Greek
/// codepoints into English equivalents.
pub fn transliterate_word(
    word: []const u8,
    allow_unicode: bool,
    buffer: []u8,
) error{InvalidUtf8}![]const u8 {
    var i = (try unicode.Utf8View.init(word)).iterator();
    var n: usize = 0;
    while (i.nextCodepoint()) |codepoint| {
        const entry = transliterate_char(codepoint, allow_unicode);
        @memcpy(buffer[n .. n + entry.len], entry);
        n += entry.len;
    }
    return buffer[0..n];
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
pub const DIAERESIS: u21 = '\u{0308}';

/// Return a romanised equivalent of the specified codepoint.
/// if the character does not belong in a romanised version
/// of a word then an empty string is returned.
inline fn transliterate_char(codepoint: u21, allow_unicode: bool) []const u8 {
    return switch (codepoint) {
        ' ' => "",
        '\n' => "",
        '\r' => "",
        '\t' => "",
        ACUTE, ACUTE_ALT, CIRCUMFLEX, CIRCUMFLEX_ALT, MACRON => "",
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

test "transliterate" {
    var buffer: [100]u8 = undefined;
    try eq("artos", try transliterate_word("αρτος", false, &buffer));
    try eq("patēr", try transliterate_word("πατήρ", true, &buffer));
    try eq("pater", try transliterate_word("πατήρ", false, &buffer));
    try eq("en", try transliterate_word("ἔν", true, &buffer));
    try eq("a", try transliterate_word("ἀ", true, &buffer));
    try eq("a", try transliterate_word("ἇ", true, &buffer));
    try eq("to", try transliterate_word("το", true, &buffer));
    try eq("to", try transliterate_word("τό", true, &buffer));
    try eq("to", try transliterate_word("τὸ", true, &buffer));
    try eq("ruomai", try transliterate_word("ῥυομαι", true, &buffer));
    try eq("ruomai", try transliterate_word("ῤυομαι", true, &buffer));
    try eq("Ruomai", try transliterate_word("Ῥυομαι", true, &buffer));
    try eq("peripatei", try transliterate_word("περιπατει", true, &buffer));
    try eq("Trechei", try transliterate_word("Τρεχει", true, &buffer));
}
