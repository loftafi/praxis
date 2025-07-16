module: Module = .unknown,
book: Book = .unknown,
chapter: u16 = 0,
verse: u16 = 0,
word: u16 = 0,

const Self = @This();

pub fn clear(self: *Self) void {
    self.module = .unknown;
    self.book = .unknown;
    self.chapter = 0;
    self.verse = 0;
    self.word = 0;
}

/// Read a bible reference, i.e. "Acts 7:40", "1 John 2:4"
pub inline fn parse(text: []const u8) error{
    OutOfMemory,
    invalid_reference,
    InvalidU16,
}!Self {
    return readReference(Parser.init(text));
}

/// Read a bible reference, i.e. "Acts 7:40", "1 John 2:4"
pub fn readReference(
    t: *Parser,
) error{ OutOfMemory, invalid_reference, InvalidU16 }!Self {
    var reference: Self = .{};

    // Because a book name can contain multiple words,
    // read until the chapter number.
    var c = t.peek();
    const start = t.index;
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
            reference.book = Book.parse(t.data[start..end]).value;
            //std.debug.print("aargh {any} {any} `{s}` \n", .{ c, reference.book, t.data[start..end] });
            break;
        }
        _ = t.next();
        c = t.peek();
    }
    if (reference.book == .unknown) {
        return error.invalid_reference;
    }

    if (try t.read_u16()) |chapter| {
        reference.chapter = chapter;
    }
    c = t.peek();
    if (c != ':') {
        return error.invalid_reference;
    }
    _ = t.next();

    if (try t.read_u16()) |verse| {
        reference.verse = verse;
    }

    return reference;
}

/// Read a list of references to this word, i.e. "kjtr#Acts 7:40 2,sr#Acts 7:40 2"
pub fn readReferenceList(
    arena: Allocator,
    t: *Parser,
    references: *std.ArrayListUnmanaged(Self),
) error{ OutOfMemory, invalid_reference, InvalidU16 }!void {
    var reference: Self = .{}; // Parse into a temporary variable

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
            return error.invalid_reference;
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
                reference.book = Book.parse(t.data[start..end]).value;
                //std.debug.print("aargh {any} {any} `{s}` \n", .{ c, reference.book, t.data[start..end] });
                break;
            }
            _ = t.next();
            c = t.peek();
        }
        if (reference.book == .unknown) {
            return error.invalid_reference;
        }

        if (try t.read_u16()) |chapter| {
            reference.chapter = chapter;
        }
        c = t.peek();
        if (c != ':') {
            return error.invalid_reference;
        }
        _ = t.next();

        if (try t.read_u16()) |verse| {
            reference.verse = verse;
        }
        c = t.peek();
        if (c == ' ') {
            _ = t.next();

            if (try t.read_u16()) |word| {
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

const Module = @import("module.zig").Module;
const Book = @import("book.zig").Book;
const Parser = @import("parser.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;

test "read verse" {
    {
        var p = Parser.init("Mark 1:2");
        const reference = try Self.readReference(&p);
        try std.testing.expectEqual(.mark, reference.book);
        try std.testing.expectEqual(1, reference.chapter);
        try std.testing.expectEqual(2, reference.verse);
    }
    {
        var p = Parser.init("Rev 19:28");
        const reference = try Self.readReference(&p);
        try std.testing.expectEqual(.revelation, reference.book);
        try std.testing.expectEqual(19, reference.chapter);
        try std.testing.expectEqual(28, reference.verse);
    }
    {
        var p = Parser.init("1 John 123:456");
        const reference = try Self.readReference(&p);
        try std.testing.expectEqual(.first_john, reference.book);
        try std.testing.expectEqual(123, reference.chapter);
        try std.testing.expectEqual(456, reference.verse);
    }
    {
        var p = Parser.init("1Th 3:4");
        const reference = try Self.readReference(&p);
        try std.testing.expectEqual(.first_thessalonians, reference.book);
        try std.testing.expectEqual(3, reference.chapter);
        try std.testing.expectEqual(4, reference.verse);
    }
}

test "read reference list" {
    const allocator = std.testing.allocator;
    {
        var p = Parser.init("byz#Mark 1:2 3");
        var references: std.ArrayListUnmanaged(Self) = .empty;
        defer references.deinit(allocator);
        try Self.readReferenceList(allocator, &p, &references);
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
        var references: std.ArrayListUnmanaged(Self) = .empty;
        defer references.deinit(allocator);
        try Self.readReferenceList(allocator, &p, &references);
        try std.testing.expectEqual(2, references.items.len);
        try std.testing.expectEqual(10, references.items[0].chapter);
        try std.testing.expectEqual(20, references.items[0].verse);
        try std.testing.expectEqual(30, references.items[0].word);
        try std.testing.expectEqual(11, references.items[1].chapter);
        try std.testing.expectEqual(22, references.items[1].verse);
        try std.testing.expectEqual(33, references.items[1].word);
    }
}
