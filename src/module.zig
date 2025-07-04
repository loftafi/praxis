/// A module represents the short name/code/acronym for a
/// public domain or commonly used scripture resource.
pub const Module = enum(u16) {
    unknown = 0,
    byzantine = 1,
    nestle = 2,
    sbl = 3,
    sr = 4,
    kjtr = 5,
    ccat = 6,
    berean_gnt = 7,
    brenton = 8,

    pub fn from_u8(module: u8) !Module {
        return switch (module) {
            0 => .unknown,
            1 => .byzantine,
            2 => .nestle,
            3 => .sbl,
            4 => .sr,
            5 => .kjtr,
            6 => .ccat,
            7 => .berean_gnt,
            8 => .brenton,
            else => error.InvalidModule,
        };
    }

    pub fn from_u16(module: u16) !Module {
        return switch (module) {
            0 => .unknown,
            1 => .byzantine,
            2 => .nestle,
            3 => .sbl,
            4 => .sr,
            5 => .kjtr,
            6 => .ccat,
            7 => .berean_gnt,
            8 => .brenton,
            else => error.InvalidModule,
        };
    }

    pub fn parse(value: []const u8) *const ModuleInfo {
        for (&NAMES) |*module| {
            for (module.*.variations) |name| {
                if (std.ascii.eqlIgnoreCase(value, name)) {
                    return module;
                }
            }
        }
        return &NAMES[0];
    }

    pub fn info(self: Module) *const ModuleInfo {
        const index = @intFromEnum(self);
        if (index < NAMES.len) {
            return &NAMES[index];
        }
        std.debug.print("Module.info({d}) is an invalid module number.\n", .{index});
        @panic("Module Enum contains invalid module id");
    }
};

pub const ModuleInfo = struct {
    name: []const u8,
    value: Module,
    code: []const u8,
    variations: []const []const u8,
};

pub const NAMES = [_]ModuleInfo{
    .{
        .name = "Unknown",
        .value = .unknown,
        .code = "unknown",
        .variations = &.{ "unknown", "unk", "un" },
    },
    .{
        .name = "Byzantine GNT",
        .value = .byzantine,
        .code = "byz",
        .variations = &.{ "byz", "byzantine" },
    },
    .{
        .name = "Nestle 1904",
        .value = .nestle,
        .code = "nestle",
        .variations = &.{
            "nestle",
            "nest",
            "nestle 1904",
            "nestle1904",
        },
    },
    .{
        .name = "SBL GNT",
        .value = .sbl,
        .code = "sbl",
        .variations = &.{ "sbl", "sbl gnt", "sblgnt" },
    },
    .{
        .name = "Statistical Restoration GNT",
        .value = .sr,
        .code = "sr",
        .variations = &.{ "sr", "sr gnt", "srgnt" },
    },
    .{
        .name = "King James Textus Receptus",
        .value = .kjtr,
        .code = "kjtr",
        .variations = &.{ "kjtr", "kjvtr" },
    },
    .{
        .name = "CCAT",
        .value = .ccat,
        .code = "ccat",
        .variations = &.{"ccat"},
    },
    .{
        .name = "Berean GNT",
        .value = .berean_gnt,
        .code = "berean",
        .variations = &.{
            "berean",
            "ber",
            "ber gnt",
            "bergnt",
            "berean gnt",
            "bereangnt",
        },
    },
    .{
        .name = "Brenton LXX",
        .value = .brenton,
        .code = "brenton",
        .variations = &.{
            "bren",
            "brent",
            "brenton",
            "brentons",
            "brenton lxx",
            "brentons lxx",
        },
    },
};

const std = @import("std");
