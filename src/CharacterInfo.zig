pub const Accent = enum {
    acute,
    circumflex,
    grave,
    unaccented,
};

pub const Breathing = enum {
    rough,
    smooth,
    none,
};

const Info = struct {
    /// integer version of the character
    char: u21,
    /// utf8 version of the character
    utf8: []const u8,
    vowel: bool,
    breathing: Breathing,
    accent: Accent,
    diaeresis: bool,
};

const fh = @import("farmhash64.zig").farmhash64;

/// Return greek accent information about a unicode (nfc or nfd) encoded character.
pub fn characterInfo(c: []const u8) *const Info {
    @setEvalBranchQuota(4000);

    return switch (fh(c)) {
        fh("α"), fh("Α"), fh("ᾰ") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("α̈"), fh("Α̈") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = true },
        fh("Ά"), fh("Α\u{301}"), fh("ά"), fh("α\u{301}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("ᾴ"), fh("α\u{345}\u{301}"), fh("α\u{301}\u{345}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ὰ"), fh("Α\u{300}"), fh("ὰ"), fh("α\u{300}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Ἁ"), fh("ἁ") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .rough, .accent = .unaccented, .diaeresis = false },
        fh("Ἀ"), fh("Α\u{313}"), fh("ἀ"), fh("α\u{313}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .smooth, .accent = .unaccented, .diaeresis = false },
        fh("ᾈ"), fh("Α\u{345}\u{313}"), fh("Α\u{313}\u{345}"), fh("ᾀ"), fh("α\u{345}\u{313}"), fh("α\u{313}\u{345}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .smooth, .accent = .unaccented, .diaeresis = false },
        fh("Ἄ"), fh("ἄ") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ἂ"), fh("ἂ") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Ἃ"), fh("ἃ") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .rough, .accent = .grave, .diaeresis = false },
        fh("ᾳ"), fh("α\u{345}"), fh("ᾼ"), fh("Α\u{345}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("ἅ"), fh("α\u{301}\u{314}"), fh("α\u{314}\u{301}"), fh("Ἅ"), fh("Α\u{301}\u{314}"), fh("Α\u{314}\u{301}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .rough, .accent = .acute, .diaeresis = false },
        fh("ᾅ"), fh("α\u{345}\u{301}\u{314}"), fh("α\u{345}\u{314}\u{301}"), fh("ᾍ"), fh("Α\u{345}\u{301}\u{314}"), fh("Α\u{345}\u{314}\u{301}"), fh("α\u{301}\u{314}\u{345}"), fh("α\u{314}\u{301}\u{345}"), fh("Α\u{301}\u{314}\u{345}"), fh("Α\u{314}\u{301}\u{345}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .rough, .accent = .acute, .diaeresis = false },
        fh("ᾄ"), fh("α\u{345}\u{301}\u{313}"), fh("α\u{345}\u{313}\u{301}"), fh("ᾌ"), fh("Α\u{345}\u{301}\u{313}"), fh("Α\u{345}\u{313}\u{301}"), fh("α\u{301}\u{313}\u{345}"), fh("α\u{313}\u{301}\u{345}"), fh("Α\u{301}\u{313}\u{345}"), fh("Α\u{313}\u{301}\u{345}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("ᾶ") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .none, .accent = .circumflex, .diaeresis = false },
        fh("ἇ"), fh("α\u{302}\u{314}"), fh("α\u{314}\u{302}"), fh("Ἇ"), fh("Α\u{302}\u{314}"), fh("Α\u{314}\u{302}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .rough, .accent = .circumflex, .diaeresis = false },
        fh("ἆ"), fh("α\u{302}\u{313}"), fh("α\u{313}\u{302}"), fh("Ἆ"), fh("Α\u{302}\u{313}"), fh("Α\u{313}\u{302}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .smooth, .accent = .circumflex, .diaeresis = false },
        fh("ᾇ"), fh("α\u{302}\u{314}\u{345}"), fh("α\u{314}\u{302}\u{345}"), fh("α\u{345}\u{302}\u{314}"), fh("α\u{345}\u{314}\u{302}"), fh("ᾏ"), fh("Α\u{302}\u{314}\u{345}"), fh("Α\u{314}\u{302}\u{345}"), fh("Α\u{345}\u{302}\u{314}"), fh("Α\u{345}\u{314}\u{302}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .rough, .accent = .circumflex, .diaeresis = false },
        fh("ᾆ"), fh("α\u{302}\u{313}\u{345}"), fh("α\u{313}\u{302}\u{345}"), fh("α\u{345}\u{302}\u{313}"), fh("α\u{345}\u{313}\u{302}"), fh("ᾎ"), fh("Α\u{302}\u{313}\u{345}"), fh("Α\u{313}\u{302}\u{345}"), fh("Α\u{345}\u{302}\u{313}"), fh("Α\u{345}\u{313}\u{302}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .smooth, .accent = .circumflex, .diaeresis = false },
        fh("ᾷ"), fh("α\u{302}\u{345}"), fh("α\u{345}\u{302}"), fh("α\u{342}\u{345}"), fh("α\u{345}\u{342}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .none, .accent = .circumflex, .diaeresis = false },
        fh("Β"), fh("β") => &.{ .char = 'β', .utf8 = "b", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Γ"), fh("γ") => &.{ .char = 'γ', .utf8 = "g", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Δ"), fh("δ") => &.{ .char = 'δ', .utf8 = "d", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ε"), fh("ε") => &.{ .char = 'ε', .utf8 = "e", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ὲ"), fh("Ε\u{300}"), fh("ὲ"), fh("ε\u{300}") => &.{ .char = 'ε', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Ἑ"), fh("ἑ") => &.{ .char = 'ε', .utf8 = "e", .vowel = true, .breathing = .rough, .accent = .unaccented, .diaeresis = false },
        fh("Ἒ"), fh("ἒ") => &.{ .char = 'ε', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Έ"), fh("Ε\u{301}"), fh("έ"), fh("ε\u{301}") => &.{ .char = 'ε', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ἐ"), fh("Ε\u{313}"), fh("ἐ"), fh("ε\u{313}") => &.{ .char = 'ε', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .unaccented, .diaeresis = false },
        fh("Ἔ"), fh("ἔ"), fh("ε\u{313}\u{301}"), fh("ε\u{301}\u{313}"), fh("Ε\u{313}\u{301}"), fh("Ε\u{301}\u{313}") => &.{ .char = 'ε', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("ἕ"), fh("ε\u{301}\u{314}"), fh("ε\u{314}\u{301}"), fh("Ἕ"), fh("Ε\u{301}\u{314}"), fh("Ε\u{314}\u{301}") => &.{ .char = 'ε', .utf8 = "e", .vowel = true, .breathing = .rough, .accent = .acute, .diaeresis = false },
        fh("Ἓ"), fh("ἓ") => &.{ .char = 'ε', .utf8 = "e", .vowel = true, .breathing = .rough, .accent = .grave, .diaeresis = false },
        fh("Ζ"), fh("ζ") => &.{ .char = 'ζ', .utf8 = "z", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("ἥ"), fh("η\u{301}\u{314}"), fh("η\u{314}\u{301}"), fh("Ἥ"), fh("Η\u{301}\u{314}"), fh("Η\u{314}\u{301}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .rough, .accent = .acute, .diaeresis = false },
        fh("ῆ") => &.{ .char = 'ῆ', .utf8 = "e", .vowel = true, .breathing = .none, .accent = .circumflex, .diaeresis = false },
        fh("Ἣ"), fh("ἣ") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .rough, .accent = .grave, .diaeresis = false },
        fh("Η"), fh("η") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ἡ"), fh("Η\u{314}"), fh("ἡ"), fh("η\u{314}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .rough, .accent = .unaccented, .diaeresis = false },
        fh("ᾙ"), fh("Η\u{345}\u{314}"), fh("Η\u{314}\u{345}"), fh("ᾑ"), fh("η\u{345}\u{314}"), fh("η\u{314}\u{345}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .rough, .accent = .unaccented, .diaeresis = false },
        fh("Ἢ"), fh("ἢ") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Ὴ"), fh("Η\u{300}"), fh("ὴ"), fh("η\u{300}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Ή"), fh("Η\u{301}"), fh("ή"), fh("η\u{301}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ἤ"), fh("ἤ"), fh("η\u{313}\u{301}"), fh("η\u{301}\u{313}"), fh("Η\u{313}\u{301}"), fh("Η\u{301}\u{313}"), fh("η\u{313}\u{341}"), fh("η\u{341}\u{313}"), fh("Η\u{313}\u{341}"), fh("Η\u{341}\u{313}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("ᾜ"), fh("ᾔ"), fh("η\u{313}\u{301}\u{345}"), fh("η\u{301}\u{313}\u{345}"), fh("Η\u{313}\u{301}\u{345}"), fh("Η\u{301}\u{313}\u{345}"), fh("η\u{345}\u{313}\u{301}"), fh("η\u{345}\u{301}\u{313}"), fh("Η\u{345}\u{313}\u{301}"), fh("Η\u{345}\u{301}\u{313}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ἠ"), fh("Η\u{313}"), fh("ἠ"), fh("η\u{313}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .unaccented, .diaeresis = false },
        fh("ᾐ"), fh("η\u{345}\u{313}"), fh("η\u{313}\u{345}"), fh("ᾘ"), fh("Η\u{345}\u{313}"), fh("Η\u{313}\u{345}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .unaccented, .diaeresis = false },
        fh("ῃ"), fh("η\u{345}"), fh("ῌ"), fh("Η\u{345}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("ῄ"), fh("η\u{345}\u{301}"), fh("η\u{345}\u{341}"), fh("η\u{301}\u{345}"), fh("η\u{341}\u{345}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .none, .accent = .acute, .diaeresis = false },
        fh("ᾕ"), fh("ᾝ"), fh("η\u{314}\u{345}\u{301}"), fh("η\u{314}\u{345}\u{341}"), fh("η\u{301}\u{345}\u{314}"), fh("η\u{341}\u{345}\u{314}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .rough, .accent = .acute, .diaeresis = false },
        fh("ῂ"), fh("η\u{345}\u{300}"), fh("η\u{345}\u{340}"), fh("η\u{300}\u{345}"), fh("η\u{340}\u{345}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .none, .accent = .grave, .diaeresis = false },
        fh("ῇ"), fh("η\u{302}\u{345}"), fh("η\u{345}\u{302}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .none, .accent = .circumflex, .diaeresis = false },
        fh("ᾗ"), fh("η\u{314}\u{302}\u{345}"), fh("η\u{345}\u{302}\u{314}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .rough, .accent = .circumflex, .diaeresis = false },
        fh("ἦ"), fh("η\u{302}\u{313}"), fh("η\u{313}\u{302}"), fh("η\u{342}\u{313}"), fh("η\u{313}\u{342}"), fh("Ἦ"), fh("Η\u{302}\u{313}"), fh("Η\u{313}\u{302}"), fh("Η\u{342}\u{313}"), fh("Η\u{313}\u{342}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .circumflex, .diaeresis = false },
        fh("ἧ"), fh("η\u{302}\u{314}"), fh("η\u{314}\u{302}"), fh("η\u{342}\u{314}"), fh("η\u{314}\u{342}"), fh("Ἧ"), fh("Η\u{302}\u{314}"), fh("Η\u{314}\u{302}"), fh("Η\u{342}\u{314}"), fh("Η\u{314}\u{342}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .rough, .accent = .circumflex, .diaeresis = false },
        fh("ᾖ"), fh("η\u{345}\u{302}\u{313}"), fh("η\u{345}\u{313}\u{302}"), fh("η\u{345}\u{342}\u{313}"), fh("η\u{345}\u{313}\u{342}"), fh("ᾞ"), fh("Η\u{345}\u{302}\u{313}"), fh("Η\u{345}\u{313}\u{302}"), fh("Η\u{345}\u{342}\u{313}"), fh("Η\u{345}\u{313}\u{342}"), fh("η\u{302}\u{313}\u{345}"), fh("η\u{313}\u{302}\u{345}"), fh("η\u{342}\u{313}\u{345}"), fh("η\u{313}\u{342}\u{345}"), fh("Η\u{302}\u{313}\u{345}"), fh("Η\u{313}\u{302}\u{345}"), fh("Η\u{342}\u{313}\u{345}"), fh("Η\u{313}\u{342}\u{345}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .circumflex, .diaeresis = false },
        fh("Θ"), fh("θ") => &.{ .char = 'θ', .utf8 = "th", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ι"), fh("ι"), fh("Ῐ"), fh("ῐ") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ϊ"), fh("Ι\u{308}"), fh("ϊ"), fh("ι\u{308}") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = true },
        fh("ῖ") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .none, .accent = .circumflex, .diaeresis = false },
        fh("ῗ") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .none, .accent = .circumflex, .diaeresis = true },
        fh("ἶ"), fh("Ἶ") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .smooth, .accent = .circumflex, .diaeresis = false },
        fh("ἷ"), fh("Ἷ") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .rough, .accent = .circumflex, .diaeresis = false },
        fh("Ί"), fh("Ι\u{301}"), fh("ί"), fh("ι\u{301}") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ὶ"), fh("Ι\u{300}"), fh("ὶ"), fh("ι\u{300}") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Ἱ"), fh("ἱ") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .rough, .accent = .unaccented, .diaeresis = false },
        fh("Ἴ"), fh("ἴ"), fh("ι\u{313}\u{301}"), fh("ι\u{301}\u{313}"), fh("Ι\u{313}\u{301}"), fh("Ι\u{301}\u{313}") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ἲ"), fh("ἲ") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("ἵ"), fh("ι\u{301}\u{314}"), fh("ι\u{314}\u{301}"), fh("Ἵ"), fh("Ι\u{301}\u{314}"), fh("Ι\u{314}\u{301}") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .rough, .accent = .acute, .diaeresis = false },
        fh("Ἳ"), fh("ἳ") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .rough, .accent = .grave, .diaeresis = false },
        fh("Ἰ"), fh("Ι\u{313}"), fh("ἰ"), fh("ι\u{313}") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .smooth, .accent = .unaccented, .diaeresis = false },
        fh("ΐ"), fh("ι\u{301}\u{308}"), fh("ι\u{341}\u{308}"), fh("ι\u{308}\u{301}"), fh("ι\u{308}\u{341}"), fh("\u{3af}\u{308}") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .none, .accent = .acute, .diaeresis = true },
        fh("ῒ"), fh("ι\u{300}\u{308}"), fh("ι\u{340}\u{308}"), fh("ι\u{308}\u{300}"), fh("ι\u{308}\u{340}") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .none, .accent = .grave, .diaeresis = true },
        fh("Κ"), fh("κ") => &.{ .char = 'κ', .utf8 = "k", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Λ"), fh("λ") => &.{ .char = 'λ', .utf8 = "l", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Μ"), fh("μ") => &.{ .char = 'μ', .utf8 = "m", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ν"), fh("ν") => &.{ .char = 'ν', .utf8 = "n", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ξ"), fh("ξ") => &.{ .char = 'ξ', .utf8 = "x", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ο"), fh("ο") => &.{ .char = 'ο', .utf8 = "o", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ό"), fh("Ο\u{301}"), fh("ό"), fh("ο\u{301}") => &.{ .char = 'ο', .utf8 = "o", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ὸ"), fh("Ο\u{300}"), fh("ὸ"), fh("ο\u{300}") => &.{ .char = 'ο', .utf8 = "o", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Ὀ"), fh("Ο\u{313}"), fh("ὀ"), fh("ο\u{313}") => &.{ .char = 'ο', .utf8 = "o", .vowel = true, .breathing = .smooth, .accent = .unaccented, .diaeresis = false },
        fh("Ὁ"), fh("ὁ") => &.{ .char = 'ο', .utf8 = "i", .vowel = true, .breathing = .rough, .accent = .unaccented, .diaeresis = false },
        fh("Ὂ"), fh("ὂ") => &.{ .char = 'ο', .utf8 = "o", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("ὅ"), fh("ο\u{301}\u{314}"), fh("ο\u{314}\u{301}"), fh("Ὅ"), fh("Ο\u{301}\u{314}"), fh("Ο\u{314}\u{301}") => &.{ .char = 'ο', .utf8 = "o", .vowel = true, .breathing = .rough, .accent = .acute, .diaeresis = false },
        fh("Ὃ"), fh("ὃ") => &.{ .char = 'ο', .utf8 = "o", .vowel = true, .breathing = .rough, .accent = .grave, .diaeresis = false },
        fh("Ὄ"), fh("ὄ"), fh("ο\u{313}\u{301}"), fh("ο\u{301}\u{313}"), fh("Ο\u{313}\u{301}"), fh("Ο\u{301}\u{313}") => &.{ .char = 'ο', .utf8 = "o", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Π"), fh("π") => &.{ .char = 'π', .utf8 = "p", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ρ"), fh("ρ") => &.{ .char = 'ρ', .utf8 = "r", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("ῤ"), fh("ρ\u{313}") => &.{ .char = 'ρ', .utf8 = "r", .vowel = false, .breathing = .smooth, .accent = .unaccented, .diaeresis = false },
        fh("ῥ"), fh("Ῥ"), fh("ρ\u{314}"), fh("Ρ\u{314}") => &.{ .char = 'ρ', .utf8 = "r", .vowel = false, .breathing = .rough, .accent = .unaccented, .diaeresis = false },
        fh("Σ"), fh("σ"), fh("ς") => &.{ .char = 'σ', .utf8 = "s", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Τ"), fh("τ") => &.{ .char = 'τ', .utf8 = "t", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("ὑ"), fh("Ὑ") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .rough, .accent = .unaccented, .diaeresis = false },
        fh("υ"), fh("Υ"), fh("ῠ") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("ὐ"), fh("Υ\u{313}"), fh("υ\u{313}") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .smooth, .accent = .unaccented, .diaeresis = false },
        fh("ὖ"), fh("Υ\u{313}\u{302}"), fh("Υ\u{313}\u{342}"), fh("υ\u{302}\u{313}"), fh("υ\u{342}\u{313}") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .smooth, .accent = .circumflex, .diaeresis = false },
        fh("ὗ"), fh("Υ\u{314}\u{302}"), fh("Υ\u{314}\u{342}"), fh("υ\u{302}\u{314}"), fh("υ\u{342}\u{314}") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .rough, .accent = .circumflex, .diaeresis = false },
        fh("Ὺ"), fh("Υ\u{300}"), fh("ὺ"), fh("υ\u{300}") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("ῦ"), fh("υ\u{302}"), fh("υ\u{342}") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .none, .accent = .circumflex, .diaeresis = false },
        fh("ὔ"), fh("υ\u{313}\u{301}"), fh("υ\u{301}\u{313}") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("ὕ"), fh("υ\u{301}\u{314}"), fh("υ\u{314}\u{301}"), fh("Ὕ"), fh("Υ\u{301}\u{314}"), fh("Υ\u{314}\u{301}") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .rough, .accent = .acute, .diaeresis = false },
        fh("ὒ") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Ύ"),
        fh("Υ\u{301}"),
        fh("ύ"), // fh("\u{3cd}"),
        fh("υ\u{301}"),
        => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ϋ"), fh("ϋ") => &.{ .char = 'υ', .utf8 = "υ", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = true },
        fh("ύ̈"), // fh("\u{3cd}\u{308}"),
        => &.{ .char = 'υ', .utf8 = "υ", .vowel = true, .breathing = .none, .accent = .acute, .diaeresis = true },
        fh("ὐ̈") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .smooth, .accent = .unaccented, .diaeresis = true },
        fh("ΰ"), fh("υ\u{308}\u{300}"), fh("υ\u{300}\u{308}"), fh("υ\u{308}\u{340}"), fh("υ\u{340}\u{308}") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .none, .accent = .acute, .diaeresis = true },
        fh("Ὓ"), fh("ὓ") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .rough, .accent = .grave, .diaeresis = false },
        fh("Φ"), fh("φ") => &.{ .char = 'φ', .utf8 = "f", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Χ"), fh("χ") => &.{ .char = 'χ', .utf8 = "ch", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ψ"), fh("ψ") => &.{ .char = 'ψ', .utf8 = "ps", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ὼ"), fh("Ω\u{300}"), fh("ὼ"), fh("ω\u{300}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Ὠ"), fh("Ω\u{313}"), fh("ὠ"), fh("ω\u{313}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .smooth, .accent = .unaccented, .diaeresis = false },
        fh("Ὢ"), fh("ὢ") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Ὣ"), fh("ὣ") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .rough, .accent = .grave, .diaeresis = false },
        fh("Ὤ"), fh("ὤ"), fh("Ω\u{313}\u{301}"), fh("Ω\u{301}\u{313}"), fh("ω\u{313}\u{301}"), fh("ω\u{301}\u{313}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ὡ"), fh("ὡ") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .rough, .accent = .unaccented, .diaeresis = false },
        fh("Ω"), fh("ω") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ώ"), fh("Ω\u{301}"), fh("ώ"), fh("ω\u{301}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("ῶ"), fh("ω\u{302}"), fh("ω\u{342}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .none, .accent = .circumflex, .diaeresis = false },
        fh("ὥ"), fh("ω\u{301}\u{314}"), fh("ω\u{314}\u{301}"), fh("Ὥ"), fh("Ω\u{301}\u{314}"), fh("Ω\u{314}\u{301}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .rough, .accent = .acute, .diaeresis = false },
        fh("ῳ"), fh("ω\u{345}"), fh("ῼ"), fh("Ω\u{345}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("ᾠ"), fh("ω\u{313}\u{345}"), fh("ω\u{345}\u{313}"), fh("ᾨ"), fh("Ω\u{313}\u{345}"), fh("Ω\u{345}\u{313}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .smooth, .accent = .unaccented, .diaeresis = false },
        fh("ῴ"), fh("ω\u{345}\u{301}"), fh("ω\u{301}\u{345}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .none, .accent = .acute, .diaeresis = false },
        fh("ῲ"), fh("ω\u{345}\u{300}"), fh("ω\u{300}\u{345}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .none, .accent = .grave, .diaeresis = false },
        fh("ῷ"), fh("ω\u{302}\u{345}"), fh("ω\u{345}\u{302}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .none, .accent = .circumflex, .diaeresis = false },
        fh("ᾦ"), fh("ω\u{313}\u{302}\u{345}"), fh("ω\u{313}\u{345}\u{302}"), fh("ω\u{302}\u{345}\u{313}"), fh("ω\u{345}\u{302}\u{313}"), fh("ᾮ"), fh("Ω\u{313}\u{302}\u{345}"), fh("Ω\u{313}\u{345}\u{302}"), fh("Ω\u{302}\u{345}\u{313}"), fh("Ω\u{345}\u{302}\u{313}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .smooth, .accent = .circumflex, .diaeresis = false },
        fh("ᾧ"), fh("ω\u{314}\u{302}\u{345}"), fh("ω\u{314}\u{345}\u{302}"), fh("ω\u{302}\u{345}\u{314}"), fh("ω\u{345}\u{302}\u{314}"), fh("ᾯ"), fh("Ω\u{314}\u{302}\u{345}"), fh("Ω\u{314}\u{345}\u{302}"), fh("Ω\u{302}\u{345}\u{314}"), fh("Ω\u{345}\u{302}\u{314}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .rough, .accent = .circumflex, .diaeresis = false },
        fh("ὦ"), fh("ω\u{313}\u{302}"), fh("ω\u{302}\u{313}"), fh("Ὦ"), fh("Ω\u{313}\u{302}"), fh("Ω\u{302}\u{313}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .smooth, .accent = .circumflex, .diaeresis = false },
        fh("ᾤ"), fh("ω\u{313}\u{345}\u{301}"), fh("ω\u{301}\u{345}\u{313}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("ὧ"), fh("Ὧ"), fh("ω\u{314}\u{302}"), fh("ω\u{302}\u{314}"), fh("Ω\u{314}\u{302}"), fh("Ω\u{302}\u{314}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .rough, .accent = .circumflex, .diaeresis = false },
        fh("ϝ") => &.{ .char = 'ϝ', .utf8 = "w", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("᾽") => &.{ .char = '᾽', .utf8 = "'", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        else => &.{ .char = 0, .utf8 = "", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
    };
}

test "test_categorise" {
    var info = characterInfo("α");
    try expectEqual(info.utf8, "a");
    try expectEqual(info.char, 'α');
    try expectEqual(info.vowel, true);
    try expectEqual(info.breathing, .none);
    try expectEqual(info.accent, .unaccented);
    try expectEqual(info.diaeresis, false);

    info = characterInfo("β");
    try expectEqual(info.utf8, "b");
    try expectEqual(info.char, 'β');
    try expectEqual(info.vowel, false);
    try expectEqual(info.breathing, .none);
    try expectEqual(info.accent, .unaccented);

    info = characterInfo("ὔ");
    try expectEqual(info.utf8, "u");
    try expectEqual(info.char, 'υ');
    try expectEqual(info.vowel, true);
    try expectEqual(info.breathing, .smooth);
    try expectEqual(info.accent, .acute);

    info = characterInfo("Β");
    try expectEqual(info.utf8, "b");
    try expectEqual(info.char, 'β');
    try expectEqual(info.vowel, false);
    try expectEqual(info.breathing, .none);
    try expectEqual(info.accent, .unaccented);

    try expectEqual('α', characterInfo("Ά").char);
    try expectEqual('α', characterInfo("Α\u{301}").char);
    try expectEqual('α', characterInfo("ά").char);
    try expectEqual('α', characterInfo("α\u{301}").char);

    try expectEqual('ε', characterInfo("ἔ").char);
}

pub const t = @import("transliterate.zig");

/// Returns number of unicode characters, accounting for
/// decomposed accents appearing as seperate utf8 entries.
pub fn unicodeLength(string: []const u8) error{InvalidUtf8}!usize {
    var len: usize = 0;
    var iter = try readUtf8Slices(string);
    while (iter.next()) |_| {
        len += 1;
    }
    return len;
}

test "unicodeLength" {
    try expectEqual(5, unicodeLength("λῦσον"));
    try expectEqual(6, unicodeLength("λύθητι"));
    try expectEqual(6, unicodeLength("λυσάτω"));
    try expectEqual(2, unicodeLength("ab"));
    try expectEqual(0, unicodeLength(""));
}

/// Iterate over unicode characters in a string, accounting for
/// decomposed accents appearing as seperate utf8 entries.
pub fn readUtf8Slices(string: []const u8) error{InvalidUtf8}!struct {
    utf8: std.unicode.Utf8Iterator,

    pub fn next(self: *@This()) ?[]const u8 {
        const last: usize = self.utf8.i;
        while (self.utf8.nextCodepoint()) |_| {
            if (self.utf8.peekCodepoint()) |peek| {
                switch (peek) {
                    t.ACUTE,
                    t.ACUTE_ALT,
                    t.GRAVE,
                    t.GRAVE_ALT,
                    t.SMOOTH,
                    t.ROUGH,
                    t.CIRCUMFLEX,
                    t.CIRCUMFLEX_ALT,
                    t.IOTA_SUBSCRIPT,
                    t.MACRON,
                    t.DIAERESIS,
                    t.BREVE,
                    => continue,
                    else => return self.utf8.bytes[last..self.utf8.i],
                }
            }
        }
        if (last != self.utf8.i) {
            return self.utf8.bytes[last..self.utf8.i];
        }
        return null;
    }
} {
    return .{ .utf8 = (try std.unicode.Utf8View.init(string)).iterator() };
}

test "read_utf8_slices" {
    var utf8 = try readUtf8Slices("βάτΐμῷ");
    try expectEqualStrings("β", (utf8.next()).?);
    try expectEqualStrings("ά", (utf8.next()).?);
    try expectEqualStrings("τ", (utf8.next()).?);
    try expectEqualStrings("ΐ", (utf8.next()).?);
    try expectEqualStrings("μ", (utf8.next()).?);
    try expectEqualStrings("ῷ", (utf8.next()).?);
}

test "real_data_test" {
    const data = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "./test/known_words.txt", std.testing.allocator, .unlimited);
    defer std.testing.allocator.free(data);

    var utf8 = try readUtf8Slices(data);
    var line: usize = 0;
    var previous: []const u8 = "";
    while (utf8.next()) |slice| {
        if (std.mem.eql(u8, "\n", slice)) {
            line += 1;
            continue;
        }
        if (std.mem.eql(u8, "\r", slice)) {
            line += 1;
            continue;
        }
        if (std.mem.eql(u8, "\t", slice)) continue;
        if (std.mem.eql(u8, " ", slice)) continue;
        const c = characterInfo(slice);
        if (c.char == 0) {
            std.log.err("lookup '{s}' {any} failed on line {d}. previous '{s}'", .{ slice, slice, line, previous });
            try expect(c.char != 0);
        }
        previous = slice;
    }
}

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
