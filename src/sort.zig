/// Less than compares two strings ignoring capitalisation
/// and accents. Only normalise as many characters as needed
/// to complete the comparison.
pub fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    var x = Utf8View.initUnchecked(a);
    var y = Utf8View.initUnchecked(b);

    var i = x.iterator();
    var j = y.iterator();

    while (true) {
        const c = i.nextCodepoint();
        const d = j.nextCodepoint();
        if (c == null and d == null) {
            return std.mem.order(u8, a, b) == .lt;
        }
        if (c == null or d == null) {
            return c == null;
        }
        const c1 = normalise_char(c.?);
        const d1 = normalise_char(d.?);
        if (c1 == d1) {
            continue;
        }
        return c1 < d1;
    }
    return false;
}

/// Less than compares two strings ignoring capitalisation
/// and accents. Only normalise as many characters as needed
/// to complete the comparison.
pub fn order(a: []const u8, b: []const u8) math.Order {
    var x = Utf8View.initUnchecked(a);
    var y = Utf8View.initUnchecked(b);

    var i = x.iterator();
    var j = y.iterator();

    while (true) {
        const c = i.nextCodepoint();
        const d = j.nextCodepoint();
        if (c == null and d == null) {
            return std.mem.order(u8, a, b);
        }
        if (c == null) {
            return .lt;
        }
        if (d == null) {
            return .gt;
        }
        const c1 = normalise_char(c.?);
        const d1 = normalise_char(d.?);
        if (c1 == d1) {
            continue;
        }
        if (c1 < d1) return .lt;
        return .gt;
    }
    return .eq;
}

pub fn normalise_char(c: u21) u21 {
    return switch (c) {
        'Α', 'Ἀ', 'Ἁ', 'Ἆ', 'Ἄ', 'Ἅ', 'ᾆ', 'ᾀ', 'ἆ', 'ᾰ', 'ἄ', 'ἅ', 'ἀ', 'ἇ', 'ᾴ', 'ᾲ', 'ᾄ', 'ᾶ', 'ᾷ', 'ᾳ', 'ἁ', 'ά', 'ὰ', 'ἂ', 'ἃ', 'ᾍ', 'Ά', 'Ὰ' => 'α',
        'Β' => 'β',
        'Γ' => 'γ',
        'Δ' => 'δ',
        'Ε', 'Ἑ', 'Ἐ', 'Ἕ', 'ἔ', 'ἕ', 'ἐ', 'ἑ', 'ὲ', 'έ', 'ἒ', 'ἓ', 'Έ', 'Ὲ', 'Ἔ' => 'ε',
        'Ζ' => 'ζ',
        'Η', 'Ἡ', 'Ἠ', 'Ἤ', 'ἤ', 'ἥ', 'ἡ', 'ἠ', 'ή', 'ὴ', 'ἢ', 'ἣ', 'ῆ', 'ἦ', 'ἧ', 'Ή', 'Ὴ', 'ᾖ', 'ᾗ', 'ῃ', 'ᾑ', 'ᾐ', 'ῇ', 'ῄ', 'ῂ', 'ᾔ', 'ᾕ', 'ᾓ', 'ᾒ', 'ᾞ', 'ῌ', 'ᾙ', 'ᾘ', 'ᾜ', 'ᾝ', 'ᾛ', 'ᾚ' => 'η',
        'Θ' => 'θ',
        'Ἰ', 'Ἱ', 'Ἴ', 'ἴ', 'ϊ', 'ΐ', 'ἵ', 'ἰ', 'ἱ', 'ῐ', 'ί', 'ὶ', 'ἲ', 'ἳ', 'ῖ', 'ἷ', 'ἶ', 'Ὶ', 'Ί' => 'ι',
        'Κ' => 'κ',
        'Λ' => 'λ',
        'Ν' => 'ν',
        'Μ' => 'μ',
        'Ξ' => 'ξ',
        'Ο', 'Ὀ', 'Ὁ', 'ό', 'ὸ', 'ὂ', 'ὃ', 'ὄ', 'ὅ', 'ὁ', 'ὀ', 'Ό', 'Ὸ' => 'ο',
        'Π' => 'π',
        'Ρ', 'Ῥ', 'ῤ', 'ῥ' => 'ρ',
        'Σ', 'ς' => 'σ',
        'Τ' => 'τ',
        'Υ', 'Ὑ', 'Ύ', 'Ὺ', 'ῠ', 'ὔ', 'ὕ', 'ὐ', 'ὑ', 'ύ', 'ὺ', 'ὒ', 'ὓ', 'ῦ', 'ϋ', 'ὖ', 'ὗ' => 'υ',
        'Φ' => 'φ',
        'Χ' => 'χ',
        'Ψ' => 'ψ',
        'Ω', 'Ὡ', 'ώ', 'ὼ', 'ᾤ', 'Ὠ', 'Ώ', 'Ὼ', 'ᾠ', 'ὠ', 'ῶ', 'ὡ', 'ὦ', 'ὧ', 'ὤ', 'ὢ', 'ὣ', 'ῴ', 'ῲ', 'ὥ', 'ῷ', 'ᾦ', 'ᾧ', 'ῳ' => 'ω',
        else => {
            if (c >= 'A' and c <= 'Z') return c + ('a' - 'A');
            return c;
        },
    };
}

const std = @import("std");
const math = std.math;
const Utf8View = std.unicode.Utf8View;
const eq = std.testing.expectEqual;

test "sort testing" {
    try eq(true, lessThan({}, "αβγ", "δεζ"));
    try eq(true, lessThan({}, "ΑΒΓ", "δεζ"));
    try eq(true, lessThan({}, "αβγ", "ΔΕΖ"));
    try eq(true, lessThan({}, "abc", "def"));
    try eq(true, lessThan({}, "ABC", "def"));
    try eq(true, lessThan({}, "abc", "DEF"));

    try eq(true, lessThan({}, "αβ", "αβγ"));
    try eq(true, lessThan({}, "ΑΒ", "αβγ"));
    try eq(true, lessThan({}, "αβ", "ΑΒΓ"));
    try eq(true, lessThan({}, "ΑΒ", "ΑΒΓ"));

    try eq(false, lessThan({}, "δεζ", "αβγ"));
    try eq(false, lessThan({}, "δεζ", "ΑΒΓ"));
    try eq(false, lessThan({}, "ΔΕΖ", "αβγ"));
    try eq(false, lessThan({}, "def", "abc"));
    try eq(false, lessThan({}, "def", "ABC"));
    try eq(false, lessThan({}, "DEF", "abc"));

    try eq(true, lessThan({}, "ᾷβγ", "αβο"));
    try eq(false, lessThan({}, "αβο", "ᾷβγ"));

    try eq(true, lessThan({}, "αβγ", "ᾷβγ"));
    try eq(false, lessThan({}, "ᾷβγ", "αβγ"));

    try eq(true, lessThan({}, "Ἀννα", "Μᾶρκος"));
    try eq(true, lessThan({}, "Αννα", "Μᾶρκος"));
    try eq(true, lessThan({}, "Αννα", "μᾶρκος"));
    try eq(true, lessThan({}, "αννα", "Μᾶρκος"));

    try eq(.lt, order("αβ", "αβγ"));
    try eq(.gt, order("αβγ", "αβ"));
    try eq(.lt, order("αβγ", "δεζ"));
    try eq(.gt, order("δεζ", "αβγ"));
    try eq(.eq, order("δεζ", "δεζ"));
}
