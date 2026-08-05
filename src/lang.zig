/// Valid language options that are permitted inside the dictionary file.
pub const Lang = enum(u8) {
    unknown = 0,
    hebrew = 1,
    greek = 2,
    aramaic = 3,
    english = 4,
    chinese = 5,
    spanish = 6,
    korean = 7,
    russian = 8,
    ukranian = 9,

    pub fn from_u8(lang: u8) !Lang {
        return switch (lang) {
            0 => .unknown,
            1 => .hebrew,
            2 => .greek,
            3 => .aramaic,
            4 => .english,
            5 => .chinese,
            6 => .spanish,
            7 => .korean,
            8 => .russian,
            9 => .ukranian,
            else => error.InvalidLanguage,
        };
    }

    pub fn code(self: Lang) []const u8 {
        return switch (self) {
            .hebrew => "he",
            .greek => "el",
            .aramaic => "aaa",
            .chinese => "zh",
            .english => "en",
            .spanish => "es",
            .korean => "ko",
            .russian => "ru",
            .ukranian => "uk",
            .unknown => "",
        };
    }

    pub fn parseCode(value: []const u8) Lang {
        if (std.ascii.eqlIgnoreCase(value, "he")) return .hebrew;
        if (std.ascii.eqlIgnoreCase(value, "el")) return .greek;
        if (std.ascii.eqlIgnoreCase(value, "aaa")) return .aramaic;
        if (std.ascii.eqlIgnoreCase(value, "en")) return .english;
        if (std.ascii.eqlIgnoreCase(value, "zh")) return .chinese;
        if (std.ascii.eqlIgnoreCase(value, "es")) return .spanish;
        if (std.ascii.eqlIgnoreCase(value, "ru")) return .russian;
        if (std.ascii.eqlIgnoreCase(value, "uk")) return .russian;
        if (std.ascii.eqlIgnoreCase(value, "ko")) return .korean;
        if (std.ascii.eqlIgnoreCase(value, "zh_tw")) return .chinese;
        if (std.ascii.eqlIgnoreCase(value, "zh_hanst")) return .chinese;
        return .unknown;
    }
};

test "parseCode" {
    try std.testing.expectEqual(.chinese, Lang.parseCode("zh"));
}

test "code" {
    try std.testing.expectEqual("zh", Lang.chinese.code());
}

const std = @import("std");
