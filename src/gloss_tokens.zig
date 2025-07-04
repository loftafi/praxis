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

const stopwords = [_][]const u8{ "i", "a", "an", "and", "are", "as", "at", "be", "but", "by", "for", "if", "in", "into", "is", "it", "no", "not", "of", "on", "or", "such", "that", "the", "their", "then", "there", "these", "they", "this", "to", "was", "will", "with" };

pub fn is_stopword(word: []const u8) bool {
    for (stopwords) |stopword| {
        if (std.ascii.eqlIgnoreCase(word, stopword)) {
            return true;
        }
    }
    return false;
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
