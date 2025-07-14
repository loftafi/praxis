pub const Dictionary = @import("dictionary.zig").Dictionary;
pub const SearchIndex = @import("search_index.zig").SearchIndex;
pub const normalise_word = @import("search_index.zig").normalise_word;
pub const MAX_WORD_SIZE = @import("search_index.zig").MAX_WORD_SIZE;

pub const Lexeme = @import("lexeme.zig");
pub const Form = @import("form.zig");
pub const Lang = @import("lang.zig").Lang;
pub const Gloss = @import("gloss.zig");
pub const Panels = @import("panels.zig");

pub const lexemeLessThan = Lexeme.lessThan;
pub const formLessThan = Form.lessThan;
pub const stringLessThan = @import("sort.zig").lessThan;

pub const parsing = @import("parsing.zig");
pub const Parsing = parsing.Parsing;
pub const parse = parsing.parse;
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
pub const pos_to_english = @import("part_of_speech.zig").english;

pub const transliterate = @import("transliterate.zig").transliterate_word;
