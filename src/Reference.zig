/// Describe a reference to an individual verse and/or word inside that verse.
const Reference = @This();

module: Module = .unknown,
book: Book = .unknown,
chapter: u16 = 0,
verse: u16 = 0,
word: u16 = 0,

pub const unknown: Reference = .{
    .module = .unknown,
    .book = .unknown,
    .chapter = 0,
    .verse = 0,
    .word = 0,
};

pub fn eql(self: *const Reference, other: *const Reference) bool {
    return (self.word == other.word and
        self.verse == other.verse and
        self.chapter == other.chapter and
        self.book == other.book and
        self.module == other.module);
}

pub fn clear(self: *Reference) void {
    self.* = .unknown;
}

/// Read a bible reference in standard English format.
///
/// i.e. "Acts 7:40", "1 John 2:4", "Mk. 1", "Rev 1:2 3"
pub inline fn parse(text: []const u8) error{
    OutOfMemory,
    InvalidReference,
    InvalidU16,
}!Reference {
    var p = Parser.init(text);
    return readReference(&p);
}

test parse {
    const verse = try Reference.parse("Acts 7:40");
    try expectEqual(.acts, verse.book);
    try expectEqual(7, verse.chapter);
    try expectEqual(40, verse.verse);

    const other = try Reference.parse("1 John 2:4");
    try expectEqual(.first_john, other.book);
    try expectEqual(2, other.chapter);
    try expectEqual(4, other.verse);

    const chapter = try Reference.parse("Rev. 5");
    try expectEqual(.revelation, chapter.book);
    try expectEqual(5, chapter.chapter);
    try expectEqual(0, chapter.verse);

    const alt = try Reference.parse("1 Jn. 3.5");
    try expectEqual(.first_john, alt.book);
    try expectEqual(3, alt.chapter);
    try expectEqual(5, alt.verse);

    const short = try Reference.parse("Mark ");
    try expectEqual(.mark, short.book);
    try expectEqual(0, short.chapter);
    try expectEqual(0, short.verse);

    const ot = try Reference.parse("Luke.");
    try expectEqual(.luke, ot.book);
    try expectEqual(0, ot.chapter);
    try expectEqual(0, ot.verse);

    const word = try Reference.parse("Col 1:2 3");
    try expectEqual(.colossians, word.book);
    try expectEqual(1, word.chapter);
    try expectEqual(2, word.verse);
    try expectEqual(3, word.word);
}

const expectEqual = std.testing.expectEqual;

/// Read a bible reference, i.e. "Acts 7:40", "1 John 2:4"
pub inline fn readReference(
    t: *Parser,
) error{ OutOfMemory, InvalidReference, InvalidU16 }!Reference {
    var reference: Reference = .{};

    // Because a book name can contain multiple words,
    // read until the chapter number.
    var c = t.peek();
    const start = t.index;
    while (c >= '0' and c <= '9') {
        _ = t.next();
        c = t.peek();
    }
    var end = t.index;
    if (c == ' ') {
        _ = t.next();
        c = t.peek();
    }
    while (true) {
        if (c == '\n' or c == '\t' or c == ' ' or c == '|' or c == 0 or c == '#' or c == ',' or c == '.' or (c >= '0' and c <= '9')) {
            end = t.index;
            reference.book = Book.parse(t.data[start..end]);
            break;
        }
        end = t.index;
        _ = t.next();
        c = t.peek();
    }
    if (reference.book == .unknown) {
        return error.InvalidReference;
    }
    if (c == '.') {
        _ = t.next();
        c = t.peek();
    }
    while (c == ' ') {
        _ = t.next();
        c = t.peek();
    }

    if (try t.readU16()) |chapter| {
        reference.chapter = chapter;
    } else {
        return reference;
    }
    c = t.peek();
    if (c != ':' and c != '.') {
        if (c == 0) return reference;
        return error.InvalidReference;
    }
    _ = t.next();

    if (try t.readU16()) |verse| {
        reference.verse = verse;
    }

    while (c == ' ') {
        _ = t.next();
        c = t.peek();
    }
    if (try t.readU16()) |word_ref| {
        reference.word = word_ref;
    }

    return reference;
}

/// Read a list of references to this word, i.e. "kjtr#Acts 7:40 2,sr#Acts 7:40 2"
pub fn readReferenceList(
    arena: Allocator,
    t: *Parser,
    references: *std.ArrayList(Reference),
) error{ OutOfMemory, InvalidReference, InvalidU16 }!void {
    var reference: Reference = .{}; // Parse into a temporary variable

    while (true) {
        // expect a module name then a hash
        var start = t.index;
        var c = t.peek();
        while (true) {
            if (c == '\n' or c == '\t' or c == '|' or c == 0 or c == '#' or c == ',' or c == '.' or c == ' ') {
                reference.module = Module.parse(t.data[start..t.index]).value;
                break;
            }
            _ = t.next();
            c = t.peek();
        }
        if (c == 0 or c == '|' or c == '\r' or c == '\n') {
            break;
        }
        if (c != '#' or reference.module == .unknown) {
            return error.InvalidReference;
        }

        // expect a book name then a space. Because a book name can
        // contain multiple words, read until the chapter number.
        _ = t.next();
        c = t.peek();
        start = t.index;
        while (c >= '0' and c <= '9') {
            _ = t.next();
            c = t.peek();
        }
        var end = t.index;
        while (true) {
            if (c == ' ') {
                end = t.index;
            }
            if (c == '\n' or c == '\t' or c == '|' or c == 0 or c == '#' or c == ',' or c == '.' or (c >= '0' and c <= '9')) {
                reference.book = Book.parse(t.data[start..end]);
                break;
            }
            _ = t.next();
            c = t.peek();
        }
        if (reference.book == .unknown) {
            return error.InvalidReference;
        }

        if (try t.readU16()) |chapter| {
            reference.chapter = chapter;
        }
        c = t.peek();
        if (c != ':') {
            return error.InvalidReference;
        }
        _ = t.next();

        if (try t.readU16()) |verse| {
            reference.verse = verse;
        }
        c = t.peek();
        if (c == ' ') {
            _ = t.next();

            if (try t.readU16()) |word| {
                reference.word = word;
            }
        }

        // Copy local variable onto ArrayList
        try references.append(arena, .{
            .module = reference.module,
            .book = reference.book,
            .chapter = reference.chapter,
            .verse = reference.verse,
            .word = reference.word,
        });

        c = t.peek();
        if (c != ',' or c == 0) {
            break;
        }
        reference.clear();
        _ = t.next();
    }
}

test "read verse" {
    {
        var p = Parser.init("Mark 1:2");
        const reference = try Reference.readReference(&p);
        try std.testing.expectEqual(.mark, reference.book);
        try std.testing.expectEqual(1, reference.chapter);
        try std.testing.expectEqual(2, reference.verse);
    }
    {
        var p = Parser.init("Rev 19:28");
        const reference = try Reference.readReference(&p);
        try std.testing.expectEqual(.revelation, reference.book);
        try std.testing.expectEqual(19, reference.chapter);
        try std.testing.expectEqual(28, reference.verse);
    }
    {
        var p = Parser.init("1 John 123:456");
        const reference = try Reference.readReference(&p);
        try std.testing.expectEqual(.first_john, reference.book);
        try std.testing.expectEqual(123, reference.chapter);
        try std.testing.expectEqual(456, reference.verse);
    }
    {
        var p = Parser.init("1Th 3:4");
        const reference = try Reference.readReference(&p);
        try std.testing.expectEqual(.first_thessalonians, reference.book);
        try std.testing.expectEqual(3, reference.chapter);
        try std.testing.expectEqual(4, reference.verse);
    }
    {
        var p1 = Parser.init("1Th 3:4");
        const r1 = try Reference.readReference(&p1);
        var p2 = Parser.init("1Th 3:4");
        var r2 = try Reference.readReference(&p2);
        try std.testing.expect(r1.eql(&r2));

        p2 = Parser.init("1Th 3:5");
        r2 = try Reference.readReference(&p2);
        try std.testing.expect(!r1.eql(&r2));

        p2 = Parser.init("1Th 2:4");
        r2 = try Reference.readReference(&p2);
        try std.testing.expect(!r1.eql(&r2));

        p2 = Parser.init("Mark 3:4");
        r2 = try Reference.readReference(&p2);
        try std.testing.expect(!r1.eql(&r2));
    }
}

test "read reference list" {
    const allocator = std.testing.allocator;
    {
        var p = Parser.init("byz#Mark 1:2 3");
        var references: std.ArrayList(Reference) = .empty;
        defer references.deinit(allocator);
        try Reference.readReferenceList(allocator, &p, &references);
        try std.testing.expectEqual(1, references.items.len);
        try std.testing.expectEqual(Module.byzantine, references.items[0].module);
        try std.testing.expectEqual(Book.mark, references.items[0].book);
        try std.testing.expectEqual(1, references.items[0].chapter);
        try std.testing.expectEqual(2, references.items[0].verse);
        try std.testing.expectEqual(3, references.items[0].word);
    }
    {
        //var p = Parser.init("byz#John 10:20 30");
        var p = Parser.init("byz#John 10:20 30,sr#mark 11:22 33");
        var references: std.ArrayList(Reference) = .empty;
        defer references.deinit(allocator);
        try Reference.readReferenceList(allocator, &p, &references);
        try std.testing.expectEqual(2, references.items.len);
        try std.testing.expectEqual(10, references.items[0].chapter);
        try std.testing.expectEqual(20, references.items[0].verse);
        try std.testing.expectEqual(30, references.items[0].word);
        try std.testing.expectEqual(11, references.items[1].chapter);
        try std.testing.expectEqual(22, references.items[1].verse);
        try std.testing.expectEqual(33, references.items[1].word);
    }
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const Module = @import("module.zig").Module;
const Book = @import("book.zig").Book;
const Parser = @import("parser.zig");
