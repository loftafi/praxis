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
    var cleanup: bool = false;

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
        if (std.mem.eql(u8, arg, "-c")) {
            cleanup = true;
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

    var dictionary = try Dictionary.create(init.arena.allocator());
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

    if (cleanup) {
        try dataCleanup(init.arena.allocator(), dictionary);
    }

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

/// Add/update/validate forms of a lexeme.
fn dataCleanup(allocator: Allocator, dictionary: *Dictionary) error{OutOfMemory}!void {
    var iter = dictionary.lexemes.iterator();
    while (iter.next()) |lexeme| {
        if (lexeme.pos.part_of_speech != .verb) continue;
        if (lexeme.strongs.items.len == 0) continue;
        if (lexeme.lang != .greek) continue;

        // Present middle/passive/middle-passive duplicate to each other.
        // i.e. V-PPI-1S duplicates to V-PMI-1S
        var new_forms: std.ArrayListUnmanaged(*Form) = .empty;
        for (lexeme.forms.items) |form| {
            if (form.parsing.part_of_speech != .verb) continue;
            if (form.parsing.tense_form != .present) continue;
            if (form.parsing.mood != .indicative) continue;
            if (form.parsing.voice == .middle) {
                try duplicatePresentPassiveForms(allocator, &dictionary.forms, form, .passive, &new_forms);
                try duplicatePresentPassiveForms(allocator, &dictionary.forms, form, .middle_or_passive, &new_forms);
            }
            if (form.parsing.voice == .passive) {
                try duplicatePresentPassiveForms(allocator, &dictionary.forms, form, .middle, &new_forms);
                try duplicatePresentPassiveForms(allocator, &dictionary.forms, form, .middle_or_passive, &new_forms);
            }
            if (form.parsing.voice == .middle_or_passive) {
                try duplicatePresentPassiveForms(allocator, &dictionary.forms, form, .middle, &new_forms);
                try duplicatePresentPassiveForms(allocator, &dictionary.forms, form, .passive, &new_forms);
            }
        }
        for (new_forms.items) |form| {
            form.uid = dictionary.generateUniqueUid();
            // Add this form to the lexeme it belongs to.
            try lexeme.forms.append(dictionary.allocator, form);
            dictionary.by_form.add(dictionary.allocator, form.word, form) catch |e| {
                switch (e) {
                    error.OutOfMemory => |f| return f,
                    error.WordTooLong, error.EmptyWord, error.InvalidUtf8 => {
                        unreachable; // Invalid word was loaded into index.
                    },
                }
            };
            try dictionary.by_form_uid.put(dictionary.allocator, form.uid, form);
        }
    }
}

/// Present middle/passive/middle-passive endings should be the same. Duplicate
/// from one voice to the other when possible.
fn duplicatePresentPassiveForms(
    allocator: Allocator,
    pool: *@FieldType(Dictionary, "forms"),
    form: *const Form,
    add_voice: praxis.Parsing.Voice,
    new_forms: *std.ArrayListUnmanaged(*Form),
) Allocator.Error!void {
    std.debug.assert(form.lexeme != null);
    for (form.lexeme.?.forms.items) |item| {
        if (item.parsing.part_of_speech != .verb) continue;
        if (item.parsing.tense_form != .present) continue;
        if (item.parsing.mood != .indicative) continue;
        if (item.parsing.person != form.parsing.person) continue;
        if (item.parsing.number != form.parsing.number) continue;
        if (item.parsing.voice == add_voice) return;
    }
    for (new_forms.items) |item| {
        if (item.parsing.part_of_speech != .verb) continue;
        if (item.parsing.tense_form != .present) continue;
        if (item.parsing.mood != .indicative) continue;
        if (item.parsing.person != form.parsing.person) continue;
        if (item.parsing.number != form.parsing.number) continue;
        if (item.parsing.voice == add_voice) return;
    }

    info("would add form: {s} {s}: {t} -> {t}", .{
        form.lexeme.?.word,
        form.word,
        form.parsing.voice,
        add_voice,
    });
    var new_form = try pool.alloc();
    try form.clone(allocator, new_form);
    new_form.parsing.voice = add_voice;
    try new_forms.append(allocator, new_form);
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
const Dictionary = praxis.Dictionary;
const Form = praxis.Form;
