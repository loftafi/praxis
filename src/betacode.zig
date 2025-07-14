//! Convert betacode to Greek Unicode. Supports standard betacode and
//! TLG betacode.
//!
//! # Examples
//!
//! Convert Robinson-Pierpont style betacode into unicode Greek:
//!
//! ```
//! const betacode_to_greek = @import("praxis").betacode_to_greek;
//!
//! const word = "Qeo/v".to_greek(Default);
//! try expectEqualStrings("Θεός", word);
//! ```
//!
//! Convert TLG style betacode into unicode Greek:
//!
//! ```
//! const betacode_to_greek = @import("praxis").betacode_to_greek;
//!
//! const let word = "*QEO/S".to_greek(TLG);
//! try expectEqualStrings("Θεός", word);
//! ```
//!
//! The default converter assumes lowercase ascii letters are lowercase Greek
//! letters and uppercase ascii letters are uppercase Greek letters. The TLG
//! converter assumes all letters are always lowercase unless an asterix appears
//! before the letter.

/// Choose which betacode format to convert.
pub const Type = enum(u2) {
    default = 0,
    tlg = 1,
};

pub const ErrorType = enum(u3) {
    unknown = 0,
    unexpected_character = 1,
    unexpected_accent = 2,
};

/// Conversion fails when an unexpected character is found.
pub const ConversionError = struct {
    type: ErrorType,
    character: u21,
};

/// Convert a betacode ascii string into a Greek unicode string.
///
/// Space or punctuation characters should not appear at the start or end of
/// the string. Unrecognised punctuation, ascii or unicode character cause
/// an error to be returned.
///
/// # Examples
///
/// Convert Robinson-Pierpont style betacode into unicode Greek:
///
/// ```
/// const word = betacode_to_greek("qeo/v", .default);
/// try expectEqualStrings(word, "θεός");
/// ```
///
/// Convert TLG style betacode into unicode Greek:
///
/// ```
/// const word = betacode_to_greek("qeo/s", .tlg);
/// try expectEqualStrings(word, "θεός");
/// ```
///
/// The default converter assumes lowercase ascii letters are lowercase Greek
/// letters and uppercase ascii letters are uppercase Greek letters. The TLG
/// converter assumes all letters are always lowercase unless an asterix appears
/// before the letter.
pub fn betacode_to_greek(
    word: []const u8,
    version: Type,
    buffer: *std.BoundedArray(u8, MAX_WORD_SIZE),
) error{
    UnexpectedError,
    UnexpectedAccent,
    UnexpectedCharacter,
    Overflow,
    Utf8CannotEncodeSurrogateHalf,
    CodepointTooLarge,
}![]const u8 {
    var text = word;
    buffer.clear();

    // Trim whitespace from start
    while (text.len > 0 and is_ascii_whitespace(text[0])) {
        text.ptr += 1;
        text.len -= 1;
    }

    // A character may be deferred until the next iteration
    // of the loop.
    var carryover: u21 = 0;

    // The first character may be an accent and carry over onto
    // the next letter. Normally its after the character.
    var accents: u16 = 0;

    // Next letter was requested to be uppercase
    var uppercase: bool = false;

    while (text.len > 0) {
        var c = text[0];
        text.ptr += 1;
        text.len -= 1;

        if (c == 0) {
            std.log.err("unexpected 0 char", .{});
            break;
        }
        if (c > 127) {
            // Unicode sequences should not appear
            // in ASCII betacode sequences
            return error.UnexpectedCharacter;
        }

        if (c == '*') {
            if (version == .tlg) {
                uppercase = true;
                continue;
            }
            return error.UnexpectedCharacter;
        }

        if (version == .tlg) {
            if (uppercase == true) {
                if (c >= 'a' and c <= 'z')
                    c -= 'a' - 'A';
                uppercase = false;
            } else {
                if (c >= 'A' and c <= 'Z')
                    c += 'a' - 'A';
            }
        }

        if (is_ascii_whitespace(c)) {
            // Only read betacode characters up until a whitespace or ol.
            // TODO: This is unexpected behaviour?
            break;
        }

        // Is this recognised letter of the alphabet (not an accent)
        const letter = lookup_greek_letter(c, version);

        if (letter != 0) {
            // This is a recognised Greek letter.
            if (accents != 0 and carryover == 0) {
                // There is a hanging accent to apply to it.
                const e = try apply_accent(letter, accents);
                try buffer.appendSlice(e);
                accents = 0;
                continue;
            }

            // There is a hanging letter to go before this new letter.
            if (carryover != 0) {
                // Found a Greek letter, no accent waiting to go on it.
                // We encountered the next letter, if we just read a previous
                // letter, push it onto the return string.
                if (accents != 0) {
                    const e = try apply_accent(carryover, accents);
                    try buffer.appendSlice(e);
                } else {
                    var buff: [10]u8 = undefined;
                    const len = try std.unicode.utf8Encode(carryover, &buff);
                    try buffer.appendSlice(buff[0..len]);
                }
            }
            carryover = letter;
            accents = 0;
            continue;
        }

        if (is_ascii_whitespace(c)) {
            break;
        }

        // What we saw wasn't a Greek letter, was it a Greek accent?
        const valid = is_valid_betacode_symbol(c);
        if (valid > 0) {
            if (buffer.len == 0) {
                // Accent appears at first character, carry
                // it over to the next letter.
                accents = valid;
                continue;
            }

            // We see a betacode accent character, but
            // not a Greek letter just before it.
            if (carryover == 0)
                return error.UnexpectedCharacter;

            accents = accents | valid;
            continue;
        }
        // This character is not an alphabetic letter, not a
        // whitespace, and not a valid betacode symbol.
        if (c == '\'') {
            text.len += 1;
            text.ptr -= 1;
        } else {
            std.log.err("breaking on {d}", .{c});
        }
        break;
    }
    // End of reading loop

    // When the end of string is reached, a final character
    // may be waiting to be pushed onto the result string.
    if (carryover != 0) {
        if (accents == 0 and carryover == 'σ') {
            try buffer.appendSlice(comptime &ue('ς'));
        } else if (accents != 0) {
            const e = try apply_accent(carryover, accents);
            try buffer.appendSlice(e);
        } else {
            var buff: [10]u8 = undefined;
            const len = try std.unicode.utf8Encode(carryover, &buff);
            try buffer.appendSlice(buff[0..len]);
        }
    }

    if (text.len > 0 and text[0] == '\'') {
        try buffer.appendSlice(comptime &ue('᾽'));
        text.ptr += 1;
        text.len -= 1;
    }

    while (text.len > 0) {
        if (is_ascii_whitespace(text[0])) {
            text.ptr += 1;
            text.len -= 1;
            continue;
        }
        // Unexpected character
        return error.UnexpectedCharacter;
    }

    return buffer.slice();
}

// test if a character is a valid accentuation for a Greek character.
//
// See: https://stephanus.tlg.uci.edu/encoding/BCM.pdf
inline fn is_valid_betacode_symbol(c: u8) u16 {
    return switch (c) {
        '/' => ASCII_ACUTE,
        '\\' => ASCII_GRAVE,
        '(' => ASCII_ROUGH,
        ')' => ASCII_SMOOTH,
        '|' => ASCII_IOTA,
        '+' => ASCII_DIAERESIS,
        '=' => ASCII_CIRCUMFLEX,
        '^' => ASCII_CIRCUMFLEX,
        '1' => ASCII_SIGMA1,
        '2' => ASCII_SIGMA2,
        '3' => ASCII_SIGMA3,
        else => 0,
    };
}

const ASCII_ACUTE: u16 = 0x1;
const ASCII_GRAVE: u16 = 0x2;
const ASCII_CIRCUMFLEX: u16 = 0x4;
const ASCII_DIAERESIS: u16 = 0x8;
const ASCII_ROUGH: u16 = 0x10;
const ASCII_SMOOTH: u16 = 0x20;
const ASCII_IOTA: u16 = 0x40;
const ASCII_SIGMA1: u16 = 0x80;
const ASCII_SIGMA2: u16 = 0x100;
const ASCII_SIGMA3: u16 = 0x200;

const ASCII_SMOOTH_ACUTE: u16 = ASCII_SMOOTH + ASCII_ACUTE;
const ASCII_SMOOTH_GRAVE: u16 = ASCII_SMOOTH + ASCII_GRAVE;
const ASCII_ROUGH_ACUTE: u16 = ASCII_ROUGH + ASCII_ACUTE;
const ASCII_ROUGH_GRAVE: u16 = ASCII_ROUGH + ASCII_GRAVE;
const ASCII_CIRCUMFLEX_ROUGH: u16 = ASCII_ROUGH + ASCII_CIRCUMFLEX;
const ASCII_CIRCUMFLEX_SMOOTH: u16 = ASCII_SMOOTH + ASCII_CIRCUMFLEX;
const ASCII_DIAERESIS_ACUTE: u16 = ASCII_DIAERESIS + ASCII_ACUTE;
const ASCII_DIAERESIS_GRAVE: u16 = ASCII_DIAERESIS + ASCII_GRAVE;

inline fn is_ascii_whitespace(c: u8) bool {
    return (c == ' ' or c == '\r' or c == '\n' or c == '\t' or c == 0);
}

inline fn lookup_greek_letter(c: u8, version: Type) u21 {
    switch (c) {
        'a' => return 'α',
        'b' => return 'β',
        'd' => return 'δ',
        'e' => return 'ε',
        'f' => return 'φ',
        'g' => return 'γ',
        'h' => return 'η',
        'i' => return 'ι',
        'k' => return 'κ',
        'l' => return 'λ',
        'm' => return 'μ',
        'n' => return 'ν',
        'o' => return 'ο',
        'p' => return 'π',
        'q' => return 'θ',
        'r' => return 'ρ',
        's' => return 'σ',
        't' => return 'τ',
        'u' => return 'υ',
        'w' => return 'ω',
        'x' => return 'χ',
        'y' => return 'ψ',
        'z' => return 'ζ',
        'A' => return 'Α',
        'B' => return 'Β',
        'D' => return 'Δ',
        'E' => return 'Ε',
        'F' => return 'Φ',
        'G' => return 'Γ',
        'H' => return 'Η',
        'I' => return 'Ι',
        'K' => return 'Κ',
        'L' => return 'Λ',
        'M' => return 'Μ',
        'N' => return 'Ν',
        'O' => return 'Ο',
        'P' => return 'Π',
        'Q' => return 'Θ',
        'R' => return 'Ρ',
        'S' => return 'Σ',
        'T' => return 'Τ',
        'U' => return 'Υ',
        'W' => return 'Ω',
        'X' => return 'Χ',
        'Y' => return 'Ψ',
        'Z' => return 'Ζ',
        else => {},
    }

    // Who uses these mpapings
    switch (version) {
        .default => switch (c) {
            'v' => return 'σ',
            'V' => return 'Σ',
            'j' => return 'ς', // Some betacode systems use j for final sigma
            'J' => return 'Σ', // Some betacode systems use j for final sigma
            'c' => return 'χ',
            'C' => return 'χ',
            else => {},
        },
        .tlg => switch (c) {
            'v' => return 'ϝ',
            'V' => return 'Ϝ',
            'c' => return 'ξ',
            'C' => return 'Ξ',
            'x' => return 'χ',
            'X' => return 'Χ',
            else => {},
        },
    }

    return 0;
}

inline fn apply_accent(c: u21, accents: u21) error{UnexpectedAccent}![]const u8 {
    @setEvalBranchQuota(5000);
    if (accents == ASCII_SMOOTH) return switch (c) {
        'α' => comptime &ue('ἀ'),
        'ε' => comptime &ue('ἐ'),
        'ι' => comptime &ue('ἰ'),
        'η' => comptime &ue('ἠ'),
        'ο' => comptime &ue('ὀ'),
        'ω' => comptime &ue('ὠ'),
        'υ' => comptime &ue('ὐ'),
        'Α' => comptime &ue('Ἀ'),
        'Ε' => comptime &ue('Ἐ'),
        'Ι' => comptime &ue('Ἰ'),
        'Η' => comptime &ue('Ἠ'),
        'Ο' => comptime &ue('Ὀ'),
        'Ω' => comptime &ue('Ὠ'),
        'Υ' => comptime &ue('ὐ'),
        else => error.UnexpectedAccent,
    };

    if (accents == ASCII_ROUGH) return switch (c) {
        'α' => comptime &ue('ἁ'),
        'ε' => comptime &ue('ἑ'),
        'ι' => comptime &ue('ἱ'),
        'η' => comptime &ue('ἡ'),
        'ο' => comptime &ue('ὁ'),
        'ω' => comptime &ue('ὡ'),
        'υ' => comptime &ue('ὑ'),
        'ρ' => comptime &ue('ῥ'),
        'Α' => comptime &ue('Ἁ'),
        'Ε' => comptime &ue('Ἑ'),
        'Ι' => comptime &ue('Ἱ'),
        'Η' => comptime &ue('Ἡ'),
        'Ο' => comptime &ue('Ὁ'),
        'Ω' => comptime &ue('Ὡ'),
        'Υ' => comptime &ue('Ὑ'),
        'Ρ' => comptime &ue('Ῥ'),
        else => error.UnexpectedAccent,
    };

    if (accents == ASCII_ACUTE) return switch (c) {
        'α' => comptime &ue('ά'),
        'ε' => comptime &ue('έ'),
        'ι' => comptime &ue('ί'),
        'η' => comptime &ue('ή'),
        'ο' => comptime &ue('ό'),
        'ω' => comptime &ue('ώ'),
        'υ' => comptime &ue('ύ'),
        'Α' => comptime &ue('Ά'),
        'Ε' => comptime &ue('Έ'),
        'Ι' => comptime &ue('Ί'),
        'Η' => comptime &ue('Ή'),
        'Ο' => comptime &ue('Ό'),
        'Ω' => comptime &ue('Ώ'),
        'Υ' => comptime &ue('Ύ'),
        else => error.UnexpectedAccent,
    };

    if (accents == ASCII_GRAVE) return switch (c) {
        'α' => comptime &ue('ὰ'),
        'ε' => comptime &ue('ὲ'),
        'ι' => comptime &ue('ὶ'),
        'η' => comptime &ue('ὴ'),
        'ο' => comptime &ue('ὸ'),
        'ω' => comptime &ue('ὼ'),
        'υ' => comptime &ue('ὺ'),
        'Α' => comptime &ue('Ὰ'),
        'Ε' => comptime &ue('Ὲ'),
        'Ι' => comptime &ue('Ὶ'),
        'Η' => comptime &ue('Ὴ'),
        'Ο' => comptime &ue('Ὸ'),
        'Ω' => comptime &ue('Ὼ'),
        'Υ' => comptime &ue('Ὺ'),
        else => error.UnexpectedAccent,
    };

    if (accents == ASCII_CIRCUMFLEX) return switch (c) {
        'α' => comptime &ue('ᾶ'),
        'ι' => comptime &ue('ῖ'),
        'η' => comptime &ue('ῆ'),
        'ω' => comptime &ue('ῶ'),
        'υ' => comptime &ue('ῦ'),
        else => error.UnexpectedAccent,
    };

    if (accents == ASCII_IOTA) return switch (c) {
        'α' => comptime &ue('ᾳ'),
        'η' => comptime &ue('ῃ'),
        'ω' => comptime &ue('ῳ'),
        else => error.UnexpectedAccent,
    };

    if (accents == ASCII_SMOOTH_GRAVE) return switch (c) {
        'α' => comptime &ue('ἂ'),
        'ε' => comptime &ue('ἔ'),
        'ι' => comptime &ue('ἲ'),
        'η' => comptime &ue('ἢ'),
        'ο' => comptime &ue('ὂ'),
        'ω' => comptime &ue('ὢ'),
        'υ' => comptime &ue('ὒ'),
        'Α' => comptime &ue('Ἂ'),
        'Ε' => comptime &ue('Ἒ'),
        'Ι' => comptime &ue('Ἲ'),
        'Η' => comptime &ue('Ἢ'),
        'Ο' => comptime &ue('Ὂ'),
        'Ω' => comptime &ue('Ὤ'),
        //('Υ'=> '῍Υ', // Not possible to type on OS/X
        else => error.UnexpectedAccent,
    };

    if (accents == ASCII_ROUGH_GRAVE) return switch (c) {
        'α' => comptime &ue('ἃ'),
        'ε' => comptime &ue('ἓ'),
        'ι' => comptime &ue('ἳ'),
        'η' => comptime &ue('ἣ'),
        'ο' => comptime &ue('ὃ'),
        'ω' => comptime &ue('ὣ'),
        'υ' => comptime &ue('ὓ'),
        'Α' => comptime &ue('Ἃ'),
        'Ε' => comptime &ue('Ἒ'),
        'Ι' => comptime &ue('Ἳ'),
        'Η' => comptime &ue('Ἣ'),
        'Ο' => comptime &ue('Ὃ'),
        'Ω' => comptime &ue('Ὣ'),
        'Υ' => comptime &ue('Ὓ'),
        else => error.UnexpectedAccent,
    };

    if (accents == ASCII_SMOOTH_ACUTE) return switch (c) {
        'α' => comptime &ue('ἄ'),
        'ε' => comptime &ue('ἔ'),
        'ι' => comptime &ue('ἴ'),
        'η' => comptime &ue('ἤ'),
        'ο' => comptime &ue('ὄ'),
        'ω' => comptime &ue('ὤ'),
        'υ' => comptime &ue('ὔ'),
        'Α' => comptime &ue('Ἄ'),
        'Ε' => comptime &ue('Ἔ'),
        'Ι' => comptime &ue('Ἴ'),
        'Η' => comptime &ue('Ἤ'),
        'Ο' => comptime &ue('Ὄ'),
        'Ω' => comptime &ue('Ὤ'),
        //('Υ'=> '῎Υ', // Seems not possible to compose
        else => error.UnexpectedAccent,
    };

    if (accents == ASCII_ROUGH_ACUTE) return switch (c) {
        'α' => comptime &ue('ἅ'),
        'ε' => comptime &ue('ἕ'),
        'ι' => comptime &ue('ἵ'),
        'η' => comptime &ue('ἥ'),
        'ο' => comptime &ue('ὅ'),
        'ω' => comptime &ue('ὥ'),
        'υ' => comptime &ue('ὕ'),
        'Α' => comptime &ue('Ἅ'),
        'Ε' => comptime &ue('Ἕ'),
        'Ι' => comptime &ue('Ἵ'),
        'Η' => comptime &ue('Ἥ'),
        'Ο' => comptime &ue('Ὅ'),
        'Ω' => comptime &ue('Ὥ'),
        'Υ' => comptime &ue('Ὕ'),
        else => error.UnexpectedAccent,
    };

    if (accents == ASCII_DIAERESIS) return switch (c) {
        'ι' => comptime &ue('ϊ'),
        'υ' => comptime &ue('ϋ'),
        'Ι' => comptime &ue('Ϊ'),
        'Υ' => comptime &ue('Ϋ'),
        else => error.UnexpectedAccent,
    };

    if (accents == ASCII_DIAERESIS_GRAVE) return switch (c) {
        'ι' => comptime &ue('ῒ'),
        'Ι' => comptime &ue('ῒ'),
        'Υ' => comptime &ue('ῢ'),
        'υ' => comptime &ue('ῢ'),
        else => error.UnexpectedAccent,
    };

    if (accents == ASCII_DIAERESIS_ACUTE) return switch (c) {
        'ι' => comptime &ue('ΐ'),
        'Ι' => comptime &ue('ΐ'),
        'υ' => comptime &ue('ΰ'),
        'Υ' => comptime &ue('ΰ'),
        else => error.UnexpectedAccent,
    };

    if (accents == ASCII_CIRCUMFLEX_SMOOTH) return switch (c) {
        'α' => comptime &ue('ἆ'),
        'η' => comptime &ue('ἦ'),
        'ι' => comptime &ue('ἶ'),
        'ω' => comptime &ue('ὦ'),
        'υ' => comptime &ue('ὖ'),
        'Α' => comptime &ue('Ἆ'),
        'Η' => comptime &ue('Ἦ'),
        'Ι' => comptime &ue('Ἶ'),
        'Ω' => comptime &ue('Ὦ'),
        'Υ' => comptime &ue('ὖ'),
        else => error.UnexpectedAccent,
    };

    if (accents == ASCII_CIRCUMFLEX_ROUGH) return switch (c) {
        'α' => comptime &ue('ἇ'),
        'η' => comptime &ue('ἧ'),
        'ι' => comptime &ue('ἷ'),
        'ω' => comptime &ue('ὧ'),
        'υ' => comptime &ue('ὗ'),
        'Α' => comptime &ue('Ἇ'),
        'Η' => comptime &ue('Ἧ'),
        'Ι' => comptime &ue('Ἷ'),
        'Ω' => comptime &ue('Ὧ'),
        'Υ' => comptime &ue('Ὗ'),
        else => error.UnexpectedAccent,
    };

    if (accents == ASCII_SIGMA1) return switch (c) {
        'σ' => comptime &ue('σ'),
        'Σ' => comptime &ue('Σ'),
        else => error.UnexpectedAccent,
    };

    if (accents == ASCII_SIGMA2) return switch (c) {
        'σ' => comptime &ue('ς'),
        'Σ' => comptime &ue('Σ'),
        else => error.UnexpectedAccent,
    };
    if (accents == ASCII_SIGMA3) return switch (c) {
        'σ' => comptime &ue('ϲ'),
        'Σ' => comptime &ue('Ϲ'),
        else => error.UnexpectedAccent,
    };

    return error.UnexpectedAccent;
}

pub const MAX_WORD_SIZE = @import("search_index.zig").MAX_WORD_SIZE;

const std = @import("std");

const eq = std.testing.expectEqualStrings;
const ee = std.testing.expectEqual;
const expect = std.testing.expect;
const ue = std.unicode.utf8EncodeComptime;

test "test_traits" {
    var buffer = try std.BoundedArray(u8, MAX_WORD_SIZE).init(0);
    try eq("", try betacode_to_greek("", .default, &buffer));
    try eq("αβ", try betacode_to_greek("ab", .default, &buffer));
    try eq("αβ", try betacode_to_greek(" ab ", .default, &buffer));
    try eq("σα", try betacode_to_greek("sa", .default, &buffer));
}

test "valid_default_encoding" {
    var buffer = try std.BoundedArray(u8, MAX_WORD_SIZE).init(0);
    try eq(try betacode_to_greek("", .default, &buffer), "");
    try eq(try betacode_to_greek(" ", .default, &buffer), "");
    try eq(try betacode_to_greek("  ", .default, &buffer), "");
    try eq(try betacode_to_greek("a", .default, &buffer), "α");
    try eq(try betacode_to_greek("s", .default, &buffer), "ς");
    try eq(try betacode_to_greek("es", .default, &buffer), "ες");
    try eq(try betacode_to_greek("es1", .default, &buffer), "εσ");
    try eq(try betacode_to_greek("es2", .default, &buffer), "ες");
    try eq(try betacode_to_greek("es3", .default, &buffer), "εϲ");
    try eq(try betacode_to_greek("sos", .default, &buffer), "σος");
    try eq(try betacode_to_greek("a)bba", .default, &buffer), "ἀββα");
    try eq(try betacode_to_greek("a)p'", .default, &buffer), "ἀπ᾽");
    try eq(try betacode_to_greek(" d' ", .default, &buffer), "δ᾽");
    try eq(try betacode_to_greek(" a(ll", .default, &buffer), "ἁλλ");
    try eq(try betacode_to_greek("cri", .default, &buffer), "χρι");
    try eq(try betacode_to_greek("criv", .default, &buffer), "χρις");
    try eq(try betacode_to_greek("Qeo/v", .default, &buffer), "Θεός");
    try eq(try betacode_to_greek("qeo/s3", .default, &buffer), "θεόϲ");
    try eq(try betacode_to_greek("u(mw^n", .default, &buffer), "ὑμῶν");
    try eq(try betacode_to_greek("U(mw^n", .default, &buffer), "Ὑμῶν");
    try eq(try betacode_to_greek("Pau^los", .default, &buffer), "Παῦλος");
    try eq(try betacode_to_greek("klhto/s", .default, &buffer), "κλητός");
    try eq(try betacode_to_greek("klhto\\s", .default, &buffer), "κλητὸς");
    try eq(try betacode_to_greek("xristou^", .default, &buffer), "χριστοῦ");
}

test "trailing accents" {
    var buffer = try std.BoundedArray(u8, MAX_WORD_SIZE).init(0);
    try eq(try betacode_to_greek("a)", .default, &buffer), "ἀ");
    try eq(try betacode_to_greek("kai\\ ", .default, &buffer), "καὶ");
}

test "leading accents" {
    var buffer = try std.BoundedArray(u8, MAX_WORD_SIZE).init(0);
    try eq(try betacode_to_greek(")Ihsou^", .default, &buffer), "Ἰησοῦ");
    try eq(try betacode_to_greek(")a", .default, &buffer), "ἀ");
    try eq(try betacode_to_greek("(a", .default, &buffer), "ἁ");
    try eq(try betacode_to_greek("\\a", .default, &buffer), "ὰ");
}

test "invalid_default_encoding" {
    var buffer = try std.BoundedArray(u8, MAX_WORD_SIZE).init(0);
    try std.testing.expectError(error.UnexpectedCharacter, betacode_to_greek("a\\b'a", .default, &buffer));
    try std.testing.expectError(error.UnexpectedCharacter, betacode_to_greek("dε", .default, &buffer));
    try std.testing.expectError(error.UnexpectedCharacter, betacode_to_greek("dε ", .default, &buffer));
    try std.testing.expectError(error.UnexpectedCharacter, betacode_to_greek(" dε", .default, &buffer));
    try std.testing.expectError(error.UnexpectedCharacter, betacode_to_greek("*a", .default, &buffer));
}

test "valid_tlg_encoding" {
    var buffer = try std.BoundedArray(u8, MAX_WORD_SIZE).init(0);
    try eq(try betacode_to_greek("*qeo/s", .tlg, &buffer), "Θεός");
    try eq(try betacode_to_greek("*QEO/S", .tlg, &buffer), "Θεός");
    try eq(try betacode_to_greek("xri", .tlg, &buffer), "χρι");
    try eq(try betacode_to_greek("XRI", .tlg, &buffer), "χρι");
    try eq(try betacode_to_greek("*XRI", .tlg, &buffer), "Χρι");
    try eq(try betacode_to_greek("qeo/s1", .tlg, &buffer), "θεόσ");
    try eq(try betacode_to_greek("qeo/s2", .tlg, &buffer), "θεός");
    try eq(try betacode_to_greek("qeo/s3", .tlg, &buffer), "θεόϲ");
}

test "invalid_tlg_encoding" {
    var buffer = try std.BoundedArray(u8, MAX_WORD_SIZE).init(0);
    try std.testing.expectError(error.UnexpectedCharacter, betacode_to_greek("a\\b'a", .tlg, &buffer));
    try std.testing.expectError(error.UnexpectedCharacter, betacode_to_greek("dε", .tlg, &buffer));
}
