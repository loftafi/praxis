/// A tokenizer for strings that contain glosses for words. This tokenizer removes
/// all forms of punctuation that don't belong in a gloss list. It theoretically
/// allows for future more advanced tokenization logic.
pub const GlossToken = struct {
    data: []const u8,

    pub fn next(self: *GlossToken) ?[]const u8 {
        var start: usize = 0;
        while (true) {
            if (start >= self.data.len) {
                return null;
            }
            switch (self.data[start]) {
                ' ', '\t', '\r', '\n', '(', ')', '[', ']', ',', '.', '-', ';', ':', '{', '}', '?', '!', '/', '\\', '&', '%', '+', '=' => {
                    start += 1;
                },
                else => {
                    break;
                },
            }
        }
        var end = start;
        while (true) {
            if (end >= self.data.len) {
                break;
            }
            switch (self.data[end]) {
                ' ', '\t', '\r', '\n', '(', ')', '[', ']', ',', '.', '-', ';', ':', '{', '}', '?', '!', '/', '\\', '&', '%', '+', '=' => {
                    break;
                },
                else => {
                    end += 1;
                },
            }
        }
        const result = self.data[start..end];
        self.data = self.data[end..];
        return result;
    }
};

const stopwords = std.StaticStringMap(void).initComptime(.{
    .{ "a", void },
    .{ "a", void },
    .{ "an", void },
    .{ "as", void },
    .{ "at", void },
    .{ "and", void },
    .{ "are", void },
    .{ "be", void },
    .{ "but", void },
    .{ "by", void },
    .{ "for", void },
    .{ "i", void },
    .{ "if", void },
    .{ "in", void },
    .{ "is", void },
    .{ "it", void },
    .{ "into", void },
    .{ "no", void },
    .{ "not", void },
    .{ "of", void },
    .{ "on", void },
    .{ "or", void },
    .{ "such", void },
    .{ "to", void },
    .{ "the", void },
    .{ "that", void },
    .{ "then", void },
    .{ "they", void },
    .{ "this", void },
    .{ "their", void },
    .{ "there", void },
    .{ "these", void },
    .{ "was", void },
    .{ "will", void },
    .{ "with", void },
});

pub fn is_stopword(word: []const u8) bool {
    if (word.len > 5) return false;
    if (word.len == 0) return true;
    var buffer:[5]u8 = undefined;
    const value = std.ascii.lowerString(&buffer, word);
    return stopwords.get(value) != null;
}

test "is_stopword" {
    try eq(true, is_stopword("no"));
    try eq(true, is_stopword("No"));
    try eq(true, is_stopword("NO"));
    try eq(false, is_stopword("nope"));
}

const std = @import("std");
const seq = std.testing.expectEqualStrings;
const eq = std.testing.expectEqual;

test "gloss_tokenize" {
    var i = GlossToken{ .data = " apple fish " };
    try seq("apple", i.next().?);
    try seq("fish", i.next().?);
    try eq(null, i.next());

    i = GlossToken{ .data = "apple.fish? " };
    try seq("apple", i.next().?);
    try seq("fish", i.next().?);
    try eq(null, i.next());

    i = GlossToken{ .data = ",  , apple,,fish, ,  " };
    try seq("apple", i.next().?);
    try seq("fish", i.next().?);
    try eq(null, i.next());

    i = GlossToken{ .data = "apple\n\t\tfish\t " };
    try seq("apple", i.next().?);
    try seq("fish", i.next().?);
    try eq(null, i.next());
}
