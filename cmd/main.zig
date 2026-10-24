/// Exit with success error code.
const success = 0;

/// Exit and report input cmd string was invalid.
const invalid_data = 1;

/// Exit and report that a lookup/search found no data.
const not_found = 2;

/// Exit and report that writing output data file failed.
const save_failed = 3;

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
    var cmd: enum { search, info } = .search;
    var mode: praxis.Dictionary.SaveMode = .all_words;
    var output_binary: bool = false;
    var cleanup: bool = false;

    var args = init.minimal.args.iterate();
    _ = args.skip();

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-d")) {
            filename = args.next() orelse {
                help();
                std.process.exit(invalid_data);
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
                std.process.exit(invalid_data);
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
                std.process.exit(invalid_data);
            };
            output_binary = true;
            continue;
        }
        if (std.ascii.eqlIgnoreCase("search", arg)) {
            cmd = .search;
            continue;
        }
        if (std.ascii.eqlIgnoreCase("info", arg)) {
            cmd = .info;
            continue;
        }
        if (search_word != null) {
            help();
            std.process.exit(invalid_data);
        }
        search_word = arg;
    }

    if (filename == null)
        filename = config.dict_bin;

    if (output == null and search_word == null) {
        help();
        std.process.exit(invalid_data);
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
        std.process.exit(invalid_data);
    };
    defer init.gpa.free(data);

    try dictionary.loadData(init.gpa, data);

    debug("{d} lexemes, {d} forms, dictionary.name={s} dictionary.size={d}", .{
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
            dictionary.saveBinaryFile(init.gpa, io, std.Io.Dir.cwd(), dest, mode) catch |e| {
                err("Save binary dictionary failed. {t}", .{e});
                std.process.exit(save_failed);
            }
        else
            dictionary.saveTextFile(init.gpa, io, std.Io.Dir.cwd(), dest, mode) catch |e| {
                err("Save text dictionary failed. {t}", .{e});
                std.process.exit(save_failed);
            };
        std.process.exit(success);
    }

    if (search_word) |keyword| {
        switch (cmd) {
            .search => search(dictionary, keyword),
            .info => try wordInfo(init.gpa, dictionary, keyword),
        }
        unreachable;
    }
    std.process.exit(invalid_data);
}

/// Find the single best matching dicitonary entry and
/// display extended information about that word.
fn wordInfo(
    gpa: Allocator,
    dictionary: *Dictionary,
    keyword: []const u8,
) Allocator.Error!void {
    debug("info {s}", .{keyword});

    const result = dictionary.by_form.lookup(keyword) catch {
        info("invalid utf8", .{});
        std.process.exit(1);
    };
    if (result) |value| {
        debug("found form {s}", .{value.keyword});
        if (value.first()) |form| {
            try printInfoBlock(gpa, form);
            std.process.exit(0);
        }
    }
    info("{s} form not found", .{keyword});
    std.process.exit(2);
}

/// Search and display a list of search results line by line.
fn search(dictionary: *Dictionary, keyword: []const u8) void {
    debug("search {s}", .{keyword});

    var result = dictionary.by_form.lookup(keyword) catch {
        info("invalid utf8", .{});
        std.process.exit(invalid_data);
    };

    if (result == null) {
        debug("{s} lookup by form failed", .{keyword});
        result = dictionary.by_gloss.lookup(keyword) catch {
            info("invalid utf8", .{});
            std.process.exit(invalid_data);
        };
        if (result == null) {
            debug("lookup {s} by gloss failed.", .{keyword});
        }
    }
    if (result) |value| {
        var gloss_iter = value.iterator();
        while (gloss_iter.next()) |form| {
            printInfoRow(form);
        }
        std.process.exit(success);
    } else {
        info("{s} keyword not found", .{keyword});
        std.process.exit(not_found);
    }
}

/// Display one line of information about a word.
fn printInfoRow(form: *Form) void {
    var buffer: [praxis.max_word_size * 2]u8 = undefined;
    std.debug.print("{s} ({s}) {f}\n", .{
        form.word,
        praxis.transliterateSyllables(form.word, true, "·", &buffer) catch "",
        form.parsing,
    });
}

/// Display extended info about a word form over multiple lines.
fn printInfoBlock(gpa: Allocator, form: *Form) Allocator.Error!void {
    var buffer: [praxis.max_word_size * 2]u8 = undefined;
    std.debug.print("{s}\n{s}\n{f}\n", .{
        form.word,
        praxis.transliterateSyllables(form.word, true, "·", &buffer) catch "",
        form.parsing,
    });
    if (form.glossesByLang(.english)) |gloss| {
        for (gloss.glosses(), 0..) |value, i| {
            if (i == 0)
                std.debug.print("\n", .{})
            else
                std.debug.print(", ", .{});
            std.debug.print("{s}", .{value});
        }
        if (gloss.glosses().len > 0) {
            std.debug.print(".\n", .{});
        }
    }

    if (form.lexeme) |lexeme| {
        var panels: praxis.Panels = .empty;
        const charts = try panels.setup(lexeme, gpa);

        var winsize: std.posix.winsize = .{
            .row = 0,
            .col = 0,
            .xpixel = 0,
            .ypixel = 0,
        };
        if (charts.len > 0) {
            _ = std.posix.system.ioctl(
                std.Io.File.stdout().handle,
                std.posix.T.IOCGWINSZ,
                @intFromPtr(&winsize),
            );
        }
        if (winsize.col < 30) winsize.col = 40;

        var x: usize = 0;
        while (x < charts.len) {
            // Work out how many panels fit in the current terminal width.
            var fits: usize = 0;
            var end = x;
            while (x < charts.len and charts[x].width + 2 + fits < winsize.col) {
                end += 1;
                fits += charts[x].width + 2;
            }
            defer x = end;

            // Print the panels line by line.
            if (end > charts.len) end = charts.len;
            std.debug.print("\n", .{}); // Spacer

            for (charts[x..end]) |panel| {
                spacedPrint(panel.title, panel.width, .left);
            }
            std.debug.print("\n", .{}); // Spacer

            for (charts[x..end]) |panel| {
                spacedPrint(panel.subtitle, panel.width, .left);
            }
            std.debug.print("\n", .{}); // Spacer

            for (charts[x..end]) |panel| {
                spacedDivider(panel.width);
            }
            std.debug.print("\n", .{}); // Spacer

            for (0..4) |row| {
                var has_row = false;
                for (charts[x..end]) |panel| {
                    if (row < panel.count) has_row = true;
                }
                if (!has_row) break;
                for (charts[x..end]) |panel| {
                    const adjust: usize = if (panel.label_width > 0) panel.label_width + 1 else 0;
                    spacedPrint(if (panel.top[row]) |p| p.word else "", panel.width - adjust, .left);
                    spacedPrint(panel.top_label[row], panel.label_width, .right);
                }
                std.debug.print("\n", .{}); // Spacer
            }
            for (charts[x..end]) |panel| {
                spacedDivider(panel.width);
            }
            std.debug.print("\n", .{}); // Spacer

            for (0..4) |row| {
                var has_row = false;
                for (charts[x..end]) |panel| {
                    if (row < panel.count) has_row = true;
                }
                if (!has_row) break;
                for (charts[x..end]) |panel| {
                    const adjust: usize = if (panel.label_width > 0) panel.label_width + 1 else 0;
                    spacedPrint(if (panel.bottom[row]) |p| p.word else "", panel.width - adjust, .left);
                    spacedPrint(panel.bottom_label[row], panel.label_width, .right);
                }
                std.debug.print("\n", .{}); // Spacer
            }
        }
    }
}

const table_divider = " ";
const cell_space = " ";

fn spacedPrint(
    value: []const u8,
    width: usize,
    aligns: enum { left, right },
) void {
    if (aligns == .left)
        std.debug.print("{s}", .{value});

    const len = praxis.unicodeLength(value) catch 0;
    if (len < width) {
        for (0..width - len) |_| {
            std.debug.print(cell_space, .{});
        }
    }

    if (aligns == .right)
        std.debug.print("{s}", .{value});

    std.debug.print(table_divider, .{});
}

fn spacedDivider(width: usize) void {
    for (0..width) |_| {
        std.debug.print("-", .{});
    }
    std.debug.print(table_divider, .{});
}

/// Add/update/validate forms of a lexeme.
fn dataCleanup(allocator: Allocator, dictionary: *Dictionary) error{ OutOfMemory, WordTooLong, InvalidUtf8 }!void {
    var iter = dictionary.lexemes.iterator();
    while (iter.next()) |lexeme| {
        try praxis.extend(dictionary, lexeme);
    }

    while (iter.next()) |lexeme| {
        if (lexeme.pos.part_of_speech != .verb) continue;
        if (lexeme.strongs.items.len == 0) continue;
        if (lexeme.lang != .greek) continue;

        // Present middle/passive/middle-passive duplicate to each other.
        // i.e. V-PPI-1S duplicates to V-PMI-1S
        var new_forms: std.ArrayList(*Form) = .empty;
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
    new_forms: *std.ArrayList(*Form),
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
