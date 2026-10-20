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
        const info = characterInfo(element);
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

pub const t = @import("transliterate.zig");

/// Return a reversed array of unicode character slices, including accents
/// and breathings grouped with the correct character.
fn reverseUnicodeSlices(string: []const u8, buffer: [][]const u8) error{ NoSpace, InvalidUtf8 }![][]const u8 {
    var index = buffer.len;
    var utf8 = try readUtf8Slices(string);
    while (try utf8.next()) |c| {
        if (index == 0) return error.NoSpace;
        index -= 1;
        buffer[index] = c;
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
    try expectEqualDeep(&[_][]const u8{ "ε\u{313}\u{301}", "γ", "β", "α\u{301}" }, try reverseUnicodeSlices("α\u{301}βγε\u{313}\u{301}", &b));
    try expectEqualDeep(&[_][]const u8{ "᾽", "δ" }, try reverseUnicodeSlices("δ᾽", &b));
    try expectEqualDeep(&[_][]const u8{ "᾽", "λ", "λ", "ἀ" }, try reverseUnicodeSlices("ἀλλ᾽", &b));
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

const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expectEqualDeep = std.testing.expectEqualDeep;

const praxis = @import("praxis.zig");
const max_word_size = praxis.max_word_size;
const characterInfo = @import("CharacterInfo.zig").characterInfo;
const readUtf8Slices = @import("CharacterInfo.zig").readUtf8Slices;
