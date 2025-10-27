const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_opts = .{ .target = target, .optimize = optimize };
    const sol_lib_mod = b.addModule("solana_program_library", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Adding it as a module
    const solana_dep = b.dependency("solana_program_sdk", dep_opts);
    const solana_mod = solana_dep.module("solana_program_sdk");
    sol_lib_mod.addImport("solana_program_sdk", solana_mod);

    const bincode_dep = b.dependency("bincode", .{
        .target = target,
        .optimize = optimize,
    });
    const bincode_mod = bincode_dep.module("bincode");
    sol_lib_mod.addImport("bincode", bincode_mod);

    const lib_unit_tests = b.addTest(.{
        .root_module = sol_lib_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
