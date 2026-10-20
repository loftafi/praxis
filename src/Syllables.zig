/// Split a sequence of unicode Greek characters into syllables.
/// Characters can be accented. Characters can be composed as NFD or NFC.
pub fn syllables(word: []const u8, buffer: [][]const u8) error{ NoSpace, InvalidUtf8 }![][]const u8 {
    var index: usize = buffer.len;
    var state: enum { ending, starting, restarting } = .ending;
    var end = word.len;
    var last = end;
    var i = end;
    var prev: u21 = 0;
    var prev_prev: u21 = 0;

    var slices: [max_word_size][]const u8 = undefined;
    for (try reverseUnicodeSlices(word, &slices)) |element| {
        i -= element.len;
        const info = categorise(element);
        if (info.char == 0) {
            state = .ending;
            if (last == end) {
                if (index == 0) return error.NoSpace;
                index -= 1;
                buffer[index] = word[i..end];
            } else {
                if (index == 0) return error.NoSpace;
                index -= 1;
                buffer[index] = word[last..end];
                if (last > i) {
                    if (index == 0) return error.NoSpace;
                    index -= 1;
                    buffer[index] = word[i..last];
                }
            }
            end = i;
            last = i;
            prev = info.char;
            continue;
        }
        switch (state) {
            .ending => {
                // Consume consonants until we consume a vowel.
                if (info.vowel) {
                    if (info.diaeresis) {
                        if (index == 0) return error.NoSpace;
                        index -= 1;
                        buffer[index] = word[i..end];
                        end = i;
                    }
                    state = .starting;
                }
            },
            .starting => {
                // Complete syllable with dipthong or preceeding consonant.
                if (isDipthong(info.char, prev)) {
                    // Keep reading
                } else if (info.vowel) {
                    if (index == 0) return error.NoSpace;
                    index -= 1;
                    buffer[index] = word[last..end];
                    end = last;
                } else {
                    state = .restarting;
                }
            },
            .restarting => {
                // Probably start of a new syllable, but some consonant
                // clusters have special rules for splitting.
                if (info.vowel) {
                    if (index == 0) return error.NoSpace;
                    index -= 1;
                    buffer[index] = word[last..end];
                    end = last;
                    state = .starting;
                } else if (info.char == 'σ' and prev == 'τ' and prev_prev == 'ρ') {
                    if (index == 0) return error.NoSpace;
                    index -= 1;
                    buffer[index] = word[i..end];
                    end = i;
                    state = .ending;
                } else if (joinableConsonant(info.char, prev)) {
                    prev_prev = prev;
                } else {
                    if (index == 0) return error.NoSpace;
                    index -= 1;
                    buffer[index] = word[last..end];
                    end = last;
                    state = .ending;
                }
            },
        }
        prev = info.char;
        last = i;
    }
    if (end != 0) {
        if (index == 0) return error.NoSpace;
        index -= 1;
        buffer[index] = word[0..end];
    }
    return buffer[index..buffer.len];
}

test "test_basic_words" {
    var b: [100][]const u8 = undefined;
    // NFC
    try expectEqualDeep(try syllables("αα", &b), &[_][]const u8{ "α", "α" });
    try expectEqualDeep(try syllables("καα", &b), &[_][]const u8{ "κα", "α" });
    try expectEqualDeep(try syllables("αλα", &b), &[_][]const u8{ "α", "λα" });
    try expectEqualDeep(try syllables("ἄμα", &b), &[_][]const u8{ "ἄ", "μα" });
    try expectEqualDeep(try syllables("ἀλά", &b), &[_][]const u8{ "ἀ", "λά" });
    try expectEqualDeep(try syllables("ἀλὰ", &b), &[_][]const u8{ "ἀ", "λὰ" });
    try expectEqualDeep(try syllables("ἈΛΆ", &b), &[_][]const u8{ "Ἀ", "ΛΆ" });
    try expectEqualDeep(try syllables("χριστος", &b), &[_][]const u8{ "χρι", "στος" });
    try expectEqualDeep(try syllables("χρίστος", &b), &[_][]const u8{ "χρί", "στος" });
    try expectEqualDeep(try syllables("περιπα", &b), &[_][]const u8{ "πε", "ρι", "πα" });
    try expectEqualDeep(try syllables("τραγος", &b), &[_][]const u8{ "τρα", "γος" });
    try expectEqualDeep(try syllables("στρατιοτης", &b), &[_][]const u8{ "στρα", "τι", "ο", "της" });
    try expectEqualDeep(try syllables("πιστευω", &b), &[_][]const u8{ "πι", "στευ", "ω" });
    try expectEqualDeep(try syllables("γυναικός", &b), &[_][]const u8{ "γυ", "ναι", "κός" });
    try expectEqualDeep(try syllables("φυω", &b), &[_][]const u8{ "φυ", "ω" });
    try expectEqualDeep(try syllables("σσσ", &b), &[_][]const u8{"σσσ"});
    try expectEqualDeep(try syllables("μωϋσῆν", &b), &[_][]const u8{ "μω", "ϋ", "σῆν" });
    try expectEqualDeep(try syllables("ὄσπριον", &b), &[_][]const u8{ "ὄ", "σπρι", "ον" });
    try expectEqualDeep(try syllables("ὁσία", &b), &[_][]const u8{ "ὁ", "σί", "α" });
    try expectEqualDeep(try syllables("ὅτου", &b), &[_][]const u8{ "ὅ", "του" });
    try expectEqualDeep(try syllables("ἥτις", &b), &[_][]const u8{ "ἥ", "τις" });
    try expectEqualDeep(try syllables("αἵτινες", &b), &[_][]const u8{ "αἵ", "τι", "νες" });
    try expectEqualDeep(try syllables("οἵτινες", &b), &[_][]const u8{ "οἵ", "τι", "νες" });
    try expectEqualDeep(try syllables("περιεπατήσαμεν", &b), &[_][]const u8{ "πε", "ρι", "ε", "πα", "τή", "σα", "μεν" });

    // NFD
    try expectEqualDeep(try syllables("ε\u{313}\u{301}χει", &b), &[_][]const u8{ "ἔ", "χει" });
    try expectEqualDeep(try syllables("ε\u{301}\u{313}χει", &b), &[_][]const u8{ "ε\u{301}\u{313}", "χει" });
    try expectEqualDeep(try syllables("α\u{313}ετο\u{301}ς", &b), &[_][]const u8{ "ἀ", "ε", "τός" });
    try expectEqualDeep(try syllables("ἀετός", &b), &[_][]const u8{ "ἀ", "ε", "τός" });
    try expectEqualDeep(try syllables("ἀετὸν", &b), &[_][]const u8{ "ἀ", "ε", "τὸν" });
    try expectEqualDeep(try syllables("ὥσπερ", &b), &[_][]const u8{ "ὥ", "σπερ" }); // TODO: Is this correct?
    try expectEqualDeep(try syllables("ἔχει", &b), &[_][]const u8{ "ἔ", "χει" });
}

test "test_invalid_characters" {
    var b: [100][]const u8 = undefined;
    try expectEqualDeep(try syllables("σaσ", &b), &[_][]const u8{ "σ", "a", "σ" });
    try expectEqualDeep(try syllables("eχει", &b), &[_][]const u8{ "e", "χει" });
    try expectEqualDeep(try syllables("ἔχεi", &b), &[_][]const u8{ "ἔ", "χε", "i" });
    try expectEqualDeep(try syllables("ἔχeι", &b), &[_][]const u8{ "ἔχ", "e", "ι" });
}

/// Return a reversed array of unicode character slices, including accents
/// and breathings grouped with the correct character.
fn reverseUnicodeSlices(string: []const u8, buffer: [][]const u8) error{ NoSpace, InvalidUtf8 }![][]const u8 {
    var index = buffer.len;
    var utf8 = (try std.unicode.Utf8View.init(string)).iterator();
    var last: usize = 0;
    while (utf8.nextCodepoint()) |c| {
        defer last = utf8.i;
        if (index == 0) return error.NoSpace;
        switch (c) {
            0x300, // grave
            0x301, // acute
            0x313, // smooth
            0x314, // rough
            0x342, // circumflex
            0x345, // iota subscript
            => {
                buffer[index].len += (utf8.i - last);
                continue;
            },
            else => {
                index -= 1;
                buffer[index] = string[last..utf8.i];
            },
        }
    }
    return buffer[index..buffer.len];
}

test reverseUnicodeSlices {
    var b: [max_word_size][]const u8 = undefined;
    try expectEqualDeep(try reverseUnicodeSlices("", &b), &[_][]const u8{});
    try expectEqualDeep(try reverseUnicodeSlices("abcd", &b), &[_][]const u8{ "d", "c", "b", "a" });
    try expectEqualDeep(try reverseUnicodeSlices("αβγδ", &b), &[_][]const u8{ "δ", "γ", "β", "α" });
    try expectEqualDeep(try reverseUnicodeSlices("你好嗎？", &b), &[_][]const u8{ "？", "嗎", "好", "你" });
    try expectEqualDeep(try reverseUnicodeSlices("ι", &b), &[_][]const u8{"ι"});
    try expectEqualDeep(try reverseUnicodeSlices("α\u{345}ι", &b), &[_][]const u8{ "ι", "α\u{345}" });
    try expectEqualDeep(try reverseUnicodeSlices("α\u{342}\u{345}ι", &b), &[_][]const u8{ "ι", "α\u{342}\u{345}" });
    try expectEqualDeep(try reverseUnicodeSlices("ᾳι", &b), &[_][]const u8{ "ι", "ᾳ" });
    try expectEqualDeep(try reverseUnicodeSlices("ᾷι", &b), &[_][]const u8{ "ι", "ᾷ" });
    try expectEqualDeep(try reverseUnicodeSlices("ᾷ", &b), &[_][]const u8{"ᾷ"});
    try expectEqualDeep(try reverseUnicodeSlices("α\u{342}\u{345}ι", &b), &[_][]const u8{ "ι", "α\u{342}\u{345}" });
    try expectEqualDeep(try reverseUnicodeSlices("α\u{301}βγε\u{313}\u{301}", &b), &[_][]const u8{ "ε\u{313}\u{301}", "γ", "β", "α\u{301}" });
    //for (try reverseUnicodeSlices("α\u{301}βγε\u{313}\u{301}", &b)) |value| {
    //    std.log.err(" ==> {s} {any}", .{ value, value });
    //}
}

fn isDipthong(a: u21, b: u21) bool {
    //if (b != 'ι' and b != 'υ') return false;
    return switch (duple(a, b)) {
        duple('α', 'ι') => true,
        duple('ε', 'ι') => true,
        duple('ο', 'ι') => true,
        duple('υ', 'ι') => true,
        duple('α', 'υ') => true,
        duple('ε', 'υ') => true,
        duple('ο', 'υ') => true,
        duple('η', 'υ') => true,
        else => false,
    };
}

fn joinableConsonant(a: u21, b: u21) bool {
    if (a == b) return false;

    return switch (duple(a, b)) {
        duple('β', 'δ') => true,
        duple('β', 'λ') => true,
        duple('β', 'ρ') => true,
        duple('γ', 'λ') => true,
        duple('γ', 'ν') => true,
        duple('γ', 'ρ') => true,
        duple('δ', 'ρ') => true,
        duple('θ', 'λ') => true,
        duple('θ', 'ν') => true,
        duple('θ', 'ρ') => true,
        duple('κ', 'λ') => true,
        duple('κ', 'ν') => true,
        duple('κ', 'ρ') => true,
        duple('κ', 'τ') => true,
        duple('μ', 'ν') => true,
        duple('π', 'λ') => true,
        duple('π', 'ν') => true,
        duple('π', 'ρ') => true,
        duple('π', 'τ') => true,
        duple('σ', 'β') => true,
        duple('σ', 'θ') => true,
        duple('σ', 'κ') => true,
        duple('σ', 'μ') => true,
        duple('σ', 'π') => true,
        duple('σ', 'τ') => true,
        duple('σ', 'φ') => true,
        duple('σ', 'χ') => true,
        duple('τ', 'ρ') => true,
        duple('φ', 'θ') => true,
        duple('φ', 'λ') => true,
        duple('φ', 'ρ') => true,
        duple('χ', 'λ') => true,
        duple('χ', 'ρ') => true,
        else => false,
    };
}

fn duple(a: u21, b: u21) u64 {
    return @as(u64, a) << 32 | @as(u64, b);
}

fn sample_joinable_consonant(a: u21, b: u21) bool {
    return switch (duple(a, b)) {
        duple('β', 'δ'),
        duple('β', 'λ'),
        duple('β', 'ρ'),
        duple('γ', 'λ'),
        duple('γ', 'ν'),
        duple('γ', 'ρ'),
        => true,
        else => false,
    };
}

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
pub fn categorise(c: []const u8) *const Info {
    return switch (fh(c)) {
        fh("Α"), fh("α") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ά"), fh("Α\u{301}"), fh("ά"), fh("α\u{301}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ὰ"), fh("Α\u{300}"), fh("ὰ"), fh("α\u{300}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Ἁ"), fh("ἁ") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .rough, .accent = .unaccented, .diaeresis = false },
        fh("Ἀ"), fh("Α\u{313}"), fh("ἀ"), fh("α\u{313}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .smooth, .accent = .unaccented, .diaeresis = false },
        fh("Ἄ"), fh("ἄ") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ἂ"), fh("ἂ") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Ἃ"), fh("ἃ") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .rough, .accent = .grave, .diaeresis = false },
        fh("ἅ"), fh("α\u{301}\u{314}"), fh("α\u{314}\u{301}"), fh("Ἅ"), fh("Α\u{301}\u{314}"), fh("Α\u{314}\u{301}") => &.{ .char = 'α', .utf8 = "a", .vowel = true, .breathing = .rough, .accent = .acute, .diaeresis = false },
        fh("ᾶ") => &.{ .char = 'ᾶ', .utf8 = "a", .vowel = true, .breathing = .none, .accent = .circumflex, .diaeresis = false },
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
        fh("Ἡ"), fh("ἡ") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .rough, .accent = .unaccented, .diaeresis = false },
        fh("Ἢ"), fh("ἢ") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Ὴ"), fh("Η\u{300}"), fh("ὴ"), fh("η\u{300}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Ή"), fh("Η\u{301}"), fh("ή"), fh("η\u{301}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ἤ"), fh("ἤ"), fh("η\u{313}\u{301}"), fh("η\u{301}\u{313}"), fh("Η\u{313}\u{301}"), fh("Η\u{301}\u{313}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ἠ"), fh("Η\u{313}"), fh("ἠ"), fh("η\u{313}") => &.{ .char = 'η', .utf8 = "e", .vowel = true, .breathing = .smooth, .accent = .unaccented, .diaeresis = false },
        fh("Θ"), fh("θ") => &.{ .char = 'θ', .utf8 = "th", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ι"), fh("ι") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ϊ"), fh("ϊ") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = true },
        fh("ῖ") => &.{ .char = 'ῖ', .utf8 = "i", .vowel = true, .breathing = .none, .accent = .circumflex, .diaeresis = false },
        fh("Ί"), fh("Ι\u{301}"), fh("ί"), fh("ι\u{301}") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ὶ"), fh("Ι\u{300}"), fh("ὶ"), fh("ι\u{300}") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Ἱ"), fh("ἱ") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .rough, .accent = .unaccented, .diaeresis = false },
        fh("Ἴ"), fh("ἴ"), fh("ι\u{313}\u{301}"), fh("ι\u{301}\u{313}"), fh("Ι\u{313}\u{301}"), fh("Ι\u{301}\u{313}") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ἲ"), fh("ἲ") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("ἵ"), fh("ι\u{301}\u{314}"), fh("ι\u{314}\u{301}"), fh("Ἵ"), fh("Ι\u{301}\u{314}"), fh("Ι\u{314}\u{301}") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .rough, .accent = .acute, .diaeresis = false },
        fh("Ἳ"), fh("ἳ") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .rough, .accent = .grave, .diaeresis = false },
        fh("Ἰ"), fh("Ι\u{313}"), fh("ἰ"), fh("ι\u{313}") => &.{ .char = 'ι', .utf8 = "i", .vowel = true, .breathing = .smooth, .accent = .unaccented, .diaeresis = false },
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
        fh("Σ"), fh("σ"), fh("ς") => &.{ .char = 'σ', .utf8 = "s", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Τ"), fh("τ") => &.{ .char = 'τ', .utf8 = "t", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Ὑ"), fh("ὑ") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .rough, .accent = .unaccented, .diaeresis = false },
        fh("Υ"), fh("υ") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = false },
        fh("Υ\u{313}"), fh("ὐ"), fh("υ\u{313}") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .smooth, .accent = .unaccented, .diaeresis = false },
        fh("Ὺ"), fh("Υ\u{300}"), fh("ὺ"), fh("υ\u{300}") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("ὔ"), fh("υ\u{313}\u{301}"), fh("υ\u{301}\u{313}") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("ὕ"), fh("υ\u{301}\u{314}"), fh("υ\u{314}\u{301}"), fh("Ὕ"), fh("Υ\u{301}\u{314}"), fh("Υ\u{314}\u{301}") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .rough, .accent = .acute, .diaeresis = false },
        fh("ὒ") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .smooth, .accent = .grave, .diaeresis = false },
        fh("Ύ"), fh("Υ\u{301}"), fh("ύ"), fh("υ\u{301}") => &.{ .char = 'υ', .utf8 = "u", .vowel = true, .breathing = .smooth, .accent = .acute, .diaeresis = false },
        fh("Ϋ"), fh("ϋ") => &.{ .char = 'υ', .utf8 = "υ", .vowel = true, .breathing = .none, .accent = .unaccented, .diaeresis = true },
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
        fh("ῶ") => &.{ .char = 'ῶ', .utf8 = "o", .vowel = true, .breathing = .none, .accent = .circumflex, .diaeresis = false },
        fh("ὥ"), fh("ω\u{301}\u{314}"), fh("ω\u{314}\u{301}"), fh("Ὥ"), fh("Ω\u{301}\u{314}"), fh("Ω\u{314}\u{301}") => &.{ .char = 'ω', .utf8 = "o", .vowel = true, .breathing = .rough, .accent = .acute, .diaeresis = false },
        else => &.{ .char = 0, .utf8 = "", .vowel = false, .breathing = .none, .accent = .unaccented, .diaeresis = false },
    };
}

test "test_categorise" {
    var info = categorise("α");
    try expectEqual(info.utf8, "a");
    try expectEqual(info.char, 'α');
    try expectEqual(info.vowel, true);
    try expectEqual(info.breathing, .none);
    try expectEqual(info.accent, .unaccented);
    try expectEqual(info.diaeresis, false);

    info = categorise("β");
    try expectEqual(info.utf8, "b");
    try expectEqual(info.char, 'β');
    try expectEqual(info.vowel, false);
    try expectEqual(info.breathing, .none);
    try expectEqual(info.accent, .unaccented);

    info = categorise("ὔ");
    try expectEqual(info.utf8, "u");
    try expectEqual(info.char, 'υ');
    try expectEqual(info.vowel, true);
    try expectEqual(info.breathing, .smooth);
    try expectEqual(info.accent, .acute);

    info = categorise("Β");
    try expectEqual(info.utf8, "b");
    try expectEqual(info.char, 'β');
    try expectEqual(info.vowel, false);
    try expectEqual(info.breathing, .none);
    try expectEqual(info.accent, .unaccented);

    try expectEqual('α', categorise("Ά").char);
    try expectEqual('α', categorise("Α\u{301}").char);
    try expectEqual('α', categorise("ά").char);
    try expectEqual('α', categorise("α\u{301}").char);

    try expectEqual('ε', categorise("ἔ").char);
}

const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expectEqualDeep = std.testing.expectEqualDeep;

const praxis = @import("praxis.zig");
const max_word_size = praxis.max_word_size;
