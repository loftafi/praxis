pub const Dictionary = @import("dictionary.zig").Dictionary;
pub const SearchIndex = @import("search_index.zig").SearchIndex;
pub const normalise_word = @import("search_index.zig").normalise_word;
pub const MAX_WORD_SIZE = @import("search_index.zig").MAX_WORD_SIZE;

/// Contains information about a lexeme and its associated forms
pub const Lexeme = @import("lexeme.zig");

/// Contains information about an individual form of a lexeme.
pub const Form = @import("form.zig");

/// A lexeme belongs to a language, and a gloss is provided in a language.
pub const Lang = @import("lang.zig").Lang;

/// Short glosses to explain the meaning of a lexeme or form.
pub const Gloss = @import("gloss.zig");

/// Collate forms of a lexeme into tables that can be displayed to the user.
/// `init()` or `create()` a `Panel` then use `setLexeme()` to fill the
/// `panel.tables` array.
pub const Panels = @import("panels.zig");

/// Sort lexemes `std.mem.sort(Lexeme, lexemes, {}, stringLessThan);`
pub const lexemeLessThan = Lexeme.lessThan;

/// Sort lexeme forms `std.mem.sort(Form, forms, {}, formLessThan);`
pub const formLessThan = Form.lessThan;

/// Sort Koine Greek words ignoring case, accents and word ending
/// variations `std.mem.sort([]const u8, words, {}, stringLessThan);`
pub const stringLessThan = @import("sort.zig").lessThan;

/// Convert betacode strings into unicode strings.
pub const betacode_to_greek = @import("betacode.zig").betacode_to_greek;
pub const BetacodeType = @import("betacode.zig").Type;

pub const parsing = @import("parsing.zig");

/// Contains word tagging/parsing information.
pub const Parsing = parsing.Parsing;

pub const PartOfSpeech = parsing.PartOfSpeech;
pub const Gender = parsing.Gender;
pub const Number = parsing.Number;
pub const Mood = parsing.Mood;
pub const Case = parsing.Case;
pub const Voice = parsing.Voice;
pub const Person = parsing.Person;
pub const TenseForm = parsing.TenseForm;

/// Use the parsing information in a `Parsing` to generate an English
/// language part of speech string.
pub const pos_to_english = @import("part_of_speech.zig").english;

/// Load a `Parsing` struct with parsing in the `N-NSM` format.
pub const parse = parsing.parse;

/// Load a `Parsing` struct with parsing in the CCAT format.
pub const parsing_ccat = @import("parsing_ccat.zig");
pub const parse_ccat = parsing_ccat.parse;

/// Load a `Parsing` struct with parsing in the CNTR format.
pub const parsing_cntr = @import("parsing_cntr.zig");
pub const parse_cntr = parsing_cntr.parse;

/// Load a `Parsing` struct with parsing in the CCAT format.
pub const parsing_morphgnt = @import("parsing_morphgnt.zig");
pub const parse_morphgnt = parsing_morphgnt.parse;

/// The `Module` enum represnts names of common modules.
pub const Module = @import("module.zig").Module;

/// The `Book` enum describes names of all commonly used books.
pub const Book = @import("book.zig").Book;

/// A reference is a book, chapter, verse tag into a paragraph of a `Book`.
pub const Reference = @import("reference.zig");

/// Parse a string reprentation of a reference into a `Reference` struct,
/// i.e. `parse_reference("Matt 3:4")` or `parse_reference("Mk 3.4")`.
pub const parse_reference = Reference.parse;

/// Convert a Greek word into a standardised roman character version of
/// the Greek word.
pub const transliterate = @import("transliterate.zig").transliterate_word;

/// A `Lexeme` and `Form` is assigned randim uid when it is first seen.
/// This is exported to allow other modules to also use the uid generator.
/// `seed()` can be called multiple times, but only acts on the first call.
pub const seed = @import("random.zig").seed;

/// This is exported to allow other modules to also use the uid generator.
/// Generate a predictable random number sequence. Use `seed()` if you don't
/// want the same sequence of numbers each time.
pub const random = @import("random.zig").random;

/// Generate a u24 uid for a `Lexeme` or `Form`. You do not need to use this,
/// but it is exported to allow other modules to reuse the uid generator.
/// Generate a predictable random number sequence. Use `seed()` if you don't
/// want the same sequence of numbers each time.
pub const random_u24 = @import("random.zig").random_u24;

/// Generate a predictable random number sequence. Use `seed()` if you don't
/// want the same sequence of numbers each time. Not used by this library
/// but exported for convenience.
pub const random_u64 = @import("random.zig").random_u64;

/// Deprecated. Was used to share a standard way to read a sequence of
/// ascii or unicode characters from a string. Will be removed in the future.
pub const Parser = @import("parser.zig");

/// Return a placeholder dictionary for testing.
pub const test_dictionary = @import("dictionary.zig").test_dictionary;
