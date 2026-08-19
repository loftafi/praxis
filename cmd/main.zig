/// Reformat and validate the contents of a quiz data file and optionally
/// generate a resource bundle or html vocab summary files.
pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    const config = try Config.init(arena, init.io, init.environ_map, null);
    defer config.deinit(arena);

    var filename: ?[]const u8 = null;
    var output: ?[]const u8 = null;
    var word: ?[]const u8 = null;
    var mode: praxis.Dictionary.SaveMode = .all_words;

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
        if (std.mem.eql(u8, arg, "-o")) {
            output = args.next() orelse {
                help();
                return;
            };
            continue;
        }
        if (word != null) {
            help();
            return;
        }
        word = arg;
    }

    if (filename == null)
        filename = config.dict_bin;

    if (output == null and word == null) {
        help();
        return;
    }

    if (word != null) {
        std.log.info("lookup {s} in {s}", .{ word.?, filename.? });
    }

    const dictionary = try praxis.Dictionary.create(init.arena.allocator());
    defer dictionary.destroy(init.arena.allocator());

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

    try dictionary.loadData(init.arena.allocator(), init.gpa, data);

    std.log.info("{d} lexemes, {d} forms, dictionary.name={s} dictionary.size={d}", .{
        dictionary.lexemes.count(),
        dictionary.forms.count(),
        filename.?,
        data.len,
    });

    if (word != null) {
        const result = dictionary.by_lexeme.lookup(word.?) catch {
            std.log.info("invalid utf8", .{});
            return;
        };
        if (result == null) {
            std.log.info("{s} lexeme not found", .{word.?});
        } else {
            std.log.info("found lexeme {s}", .{result.?.keyword});
        }

        const result2 = dictionary.by_form.lookup(word.?) catch {
            std.log.info("invalid utf8", .{});
            return;
        };
        if (result2 == null) {
            std.log.info("{s} form not found", .{word.?});
        } else {
            std.log.info("found form {s}", .{result2.?.keyword});
        }
        return;
    }

    if (output != null) {
        try dictionary.saveBinaryFile(init.gpa, io, std.Io.Dir.cwd(), output.?, mode);
    }
}

fn help() void {
    print("Specify a valid command.\n", .{});
    print("  praxis word \n", .{});
    print("  praxis -d [dictionary] word \n", .{});
    print("\n", .{});
}

const builtin = @import("builtin");

const std = @import("std");
const Allocator = std.mem.Allocator;

const err = std.log.err;
const warn = std.log.warn;
const info = std.log.info;
const debug = std.log.debug;
const print = std.debug.print;

const praxis = @import("praxis");
const Config = @import("Config.zig");
