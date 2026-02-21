///! Praxis is a zig library supporting the collection of Biblical Greek
///! and Biblical Hebrew vocabulary. The `Dictionary` reads and writes
///! dictinary data, and supports `lookup`, `search` and `autocomplete`
///! functions.
///!
pub const Dictionary = @import("dictionary.zig").Dictionary;
pub const SearchIndex = @import("search_index.zig").SearchIndex;
pub const normalise_word = @import("search_index.zig").normalise_word;
pub const lowercase = @import("search_index.zig").lowercase;
pub const remove_accent = @import("search_index.zig").remove_accent;
pub const max_word_size = @import("search_index.zig").max_word_size;

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

const parsing = @import("parsing.zig");

/// Contains word tagging/parsing information.
pub const Parsing = parsing.Parsing;

/// Use the parsing information in a `Parsing` to generate an English
/// language part of speech string.
pub const pos_to_english = @import("part_of_speech.zig").english;

/// Load a `Parsing` struct with parsing in the Byz format.
pub const byz = @import("byz.zig");

/// Load a `Parsing` struct with parsing in the CCAT format.
pub const ccat = @import("ccat.zig");

/// Load a `Parsing` struct with parsing in the CNTR format.
pub const cntr = @import("cntr.zig");

/// Load a `Parsing` struct with parsing in the CCAT format.
pub const morphgnt = @import("morphgnt.zig");

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

pub const random = @import("random.zig");

/// Deprecated. Was used to share a standard way to read a sequence of
/// ascii or unicode characters from a string. Will be removed in the future.
pub const Parser = @import("parser.zig");

/// BoundedArray was removed in 0.15.1, this os provided as a
/// temporary workaround.
pub const BoundedArray = @import("bounded_array.zig").BoundedArray;

/// A slightly faster hash for HashMaps that use strings.
pub const FarmHashContext = @import("farmhash64.zig").FarmHashContext;

/// Hash a string into a 64 bit u64 value.
pub const farmhash64 = @import("farmhash64.zig").farmhash64;

/// Return a placeholder dictionary for testing.
pub const test_dictionary = @import("dictionary.zig").test_dictionary;
