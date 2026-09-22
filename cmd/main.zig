/// Reformat and validate the contents of a quiz data file and optionally
/// generate a resource bundle or html vocab summary files.
pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    const config = try Config.init(arena, init.io, init.environ_map, null);
    defer config.deinit(arena);

    var filename: ?[]const u8 = null;
    var output: ?[]const u8 = null;
    var search_word: ?[]const u8 = null;
    var mode: praxis.Dictionary.SaveMode = .all_words;
    var output_binary: bool = false;

    var args = init.minimal.args.iterate();
    _ = args.skip();

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-d")) {
            filename = args.next() orelse {
                help();
                return;
            };
            continue;
        }
        if (std.mem.eql(u8, arg, "-gnt")) {
            mode = .gnt_words;
            continue;
        }
        if (std.mem.eql(u8, arg, "-ot")) {
            output = args.next() orelse {
                help();
                return;
            };
            output_binary = false;
            continue;
        }
        if (std.mem.eql(u8, arg, "-ob")) {
            output = args.next() orelse {
                help();
                return;
            };
            output_binary = true;
            continue;
        }
        if (search_word != null) {
            help();
            return;
        }
        search_word = arg;
    }

    if (filename == null)
        filename = config.dict_bin;

    if (output == null and search_word == null) {
        help();
        return;
    }

    if (search_word) |keyword| {
        info("lookup {s} in {s}", .{ keyword, filename.? });
    }

    const dictionary = try praxis.Dictionary.create(init.arena.allocator());
    defer dictionary.destroy();

    const data = std.Io.Dir.cwd().readFileAlloc(
        io,
        filename.?,
        init.gpa,
        .unlimited,
    ) catch {
        std.log.err("Failed to load {s}", .{filename.?});
        return;
    };
    defer init.gpa.free(data);

    try dictionary.loadData(init.gpa, data);

    info("{d} lexemes, {d} forms, dictionary.name={s} dictionary.size={d}", .{
        dictionary.lexemes.count(),
        dictionary.forms.count(),
        filename.?,
        data.len,
    });

    if (output) |dest| {
        info("Write binary dictionary to {s}. mode={t} ", .{ dest, mode });
        if (output_binary)
            try dictionary.saveBinaryFile(init.gpa, io, std.Io.Dir.cwd(), dest, mode)
        else
            try dictionary.saveTextFile(init.gpa, io, std.Io.Dir.cwd(), dest, mode);
        return;
    }

    if (search_word) |keyword| {
        const result = dictionary.by_lexeme.lookup(keyword) catch {
            info("invalid utf8", .{});
            return;
        };
        if (result == null) {
            info("{s} lexeme not found", .{keyword});
        } else {
            info("found lexeme {s}", .{result.?.keyword});
        }

        const result2 = dictionary.by_form.lookup(keyword) catch {
            info("invalid utf8", .{});
            return;
        };
        if (result2 == null) {
            info("{s} form not found", .{keyword});
        } else {
            info("found form {s}", .{result2.?.keyword});
        }
        return;
    }
}

fn help() void {
    print("Specify a valid command:\n\n", .{});
    print("  praxis word \n", .{});
    print("  praxis -d [dictionary] word \n", .{});
    print("  praxis -d [dictionary] -ob output.bin [-gnt] \n", .{});
    print("  praxis -d [dictionary] -ot output.txt [-gnt] \n", .{});
    print("\n", .{});
}

/// Redirect all log messages to the engine log handler.
pub const std_options: std.Options = .{
    .log_level = if (builtin.mode == .debug) .debug else .info,
};

const builtin = @import("builtin");

const std = @import("std");
const Allocator = std.mem.Allocator;

const err = std.log.err;
const info = std.log.info;
const debug = std.log.debug;
const print = std.debug.print;

const praxis = @import("praxis");
const Config = @import("Config.zig");
