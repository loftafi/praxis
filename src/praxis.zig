pub const Dictionary = @import("dictionary.zig").Dictionary;
pub const SearchIndex = @import("search_index.zig").SearchIndex;
pub const MAX_WORD_SIZE = @import("search_index.zig").MAX_WORD_SIZE;

pub const Lexeme = @import("lexeme.zig");
pub const Form = @import("form.zig");
pub const Lang = @import("lang.zig").Lang;
pub const Gloss = @import("gloss.zig");
pub const Panels = @import("panels.zig");

pub const parsing = @import("parsing.zig");
pub const Parsing = parsing.Parsing;
pub const PartOfSpeech = parsing.PartOfSpeech;
pub const Gender = parsing.Gender;
pub const Number = parsing.Number;
pub const Mood = parsing.Mood;
pub const Case = parsing.Case;
pub const Voice = parsing.Voice;
pub const Person = parsing.Person;
pub const TenseForm = parsing.TenseForm;

pub const Module = @import("module.zig").Module;
pub const Book = @import("book.zig").Book;
pub const Reference = @import("reference.zig");

pub const Parser = @import("parser.zig");

pub const transliterate = @import("transliterate.zig").transliterate_word;
