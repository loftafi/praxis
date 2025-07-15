const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const test_filters = b.option([]const []const u8, "test-filter", "Skip tests that do not match any filter") orelse &[0][]const u8{};

    const lib_mod = b.addModule("praxis", .{
        .root_source_file = b.path("src/praxis.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "praxis",
        .root_module = lib_mod,
    });

    b.installArtifact(lib);
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .filters = test_filters,
    });
    lib_unit_tests.root_module.addAnonymousImport("byz_parsing", .{
        .root_source_file = b.path("./test/byz-parsing.txt"),
    });
    lib_unit_tests.root_module.addAnonymousImport("other_parsing", .{
        .root_source_file = b.path("./test/other-parsing.txt"),
    });
    lib_unit_tests.root_module.addAnonymousImport("small_dict", .{
        .root_source_file = b.path("./test/small_dict.txt"),
    });
    lib_unit_tests.root_module.addAnonymousImport("larger_dict", .{
        .root_source_file = b.path("./test/larger_dict.txt"),
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
