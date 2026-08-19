const config_file = ".dialogos.conf";

/// Configuration information for the dialogos command line tool. Place a
/// file named `.dialogos.conf` into the zig project folder, or into your
/// $HOME or %USERPROFILE% folder.
///
///    {
///        "dict":          "/Volumes/drive/myapp/data/dict.txt",
///        "dict_bin":      "/Volumes/drive/polla/data/dict.bin",
///    }
///
pub const Config = @This();

dict: []const u8,
dict_bin: []const u8,

parsed: std.json.Parsed(Info),

const Info = struct {
    dict: []const u8,
    dict_bin: []const u8,
};

// Load the contents of the app config file. By default this will search
// the `cwd`, `HOME`, then `USERPROFILE`. Specify the `override_path` to
// search in only one specific custom local folder.
pub fn init(
    allocator: Allocator,
    io: std.Io,
    env: *std.process.Environ.Map,
    override_path: ?[]const u8,
) !Config {
    var dir = std.Io.Dir.cwd();

    if (override_path != null and override_path.?.len > 0) {
        dir = dir.openDir(io, override_path.?, .{}) catch {
            log.err("No config in {s}.", .{override_path.?});
            return error.FileNotFound;
        };
        _ = dir.openFile(io, config_file, .{}) catch {
            log.err("No config in {s}.", .{override_path.?});
            return error.FileNotFound;
        };
    } else {
        if (env.get("HOME")) |home| {
            if (dir.openDir(io, home, .{})) |d| {
                dir = d;
            } else |_| {}
        } else if (env.get("USERPROFILE")) |home| {
            if (dir.openDir(io, home, .{})) |d| {
                dir = d;
            } else |_| {}
        }
    }

    const f = dir.openFile(io, config_file, .{}) catch {
        log.err("No config in $HOME or %USERPROFILE% or current folder.", .{});
        return error.FileNotFound;
    };
    defer f.close(io);

    // Read the file contents. Up to 10k sized file.
    const data = dir.readFileAlloc(io, config_file, allocator, .unlimited) catch {
        log.err("Error reading config file.", .{});
        return error.FileNotFound;
    };
    defer allocator.free(data);
    return loadTextConfig(allocator, data);
}

fn loadTextConfig(allocator: Allocator, data: []const u8) !Config {
    // Parse fields
    const parsed = std.json.parseFromSlice(Info, allocator, data, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch |e| {
        if (e == error.MissingField) {
            std.log.err("Error reading {s}. {any}", .{ config_file, e });
        }
        return e;
    };

    return Config{
        .parsed = parsed,
        .dict = parsed.value.dict,
        .dict_bin = parsed.value.dict_bin,
    };
}

pub fn deinit(config: *const Config, _: Allocator) void {
    config.parsed.deinit();
}

const std = @import("std");
const log = std.log;
const Allocator = std.mem.Allocator;
