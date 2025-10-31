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

    pub fn to_code(self: Lang) []const u8 {
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

    pub fn parse_code(code: []const u8) Lang {
        if (std.ascii.eqlIgnoreCase(code, "he")) return .hebrew;
        if (std.ascii.eqlIgnoreCase(code, "el")) return .greek;
        if (std.ascii.eqlIgnoreCase(code, "aaa")) return .aramaic;
        if (std.ascii.eqlIgnoreCase(code, "en")) return .english;
        if (std.ascii.eqlIgnoreCase(code, "zh")) return .chinese;
        if (std.ascii.eqlIgnoreCase(code, "es")) return .spanish;
        if (std.ascii.eqlIgnoreCase(code, "ru")) return .russian;
        if (std.ascii.eqlIgnoreCase(code, "uk")) return .russian;
        if (std.ascii.eqlIgnoreCase(code, "ko")) return .korean;
        if (std.ascii.eqlIgnoreCase(code, "zh_tw")) return .chinese;
        if (std.ascii.eqlIgnoreCase(code, "zh_hanst")) return .chinese;
        return .unknown;
    }
};

const std = @import("std");
