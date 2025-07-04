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
            .unknown => "",
        };
    }

    pub fn parse_code(code: []const u8) Lang {
        if (std.mem.eql(u8, code, "he")) {
            return .hebrew;
        }
        if (std.mem.eql(u8, code, "el")) {
            return .greek;
        }
        if (std.mem.eql(u8, code, "aaa")) {
            return .aramaic;
        }
        if (std.mem.eql(u8, code, "en")) {
            return .english;
        }
        if (std.mem.eql(u8, code, "zh")) {
            return .chinese;
        }
        if (std.mem.eql(u8, code, "es")) {
            return .spanish;
        }
        if (std.mem.eql(u8, code, "ru")) {
            return .russian;
        }
        if (std.mem.eql(u8, code, "ko")) {
            return .korean;
        }
        return .unknown;
    }
};

const std = @import("std");
