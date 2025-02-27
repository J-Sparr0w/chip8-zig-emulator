// const std = @import("std");

// pub fn build(b: *std.Build) void {
//     const target = b.standardTargetOptions(.{});
//     const optimize = b.standardOptimizeOption(.{});

//     const exe = b.addExecutable(.{
//         .name = "chip8",
//         .root_source_file = .{ .path = "src/main.zig" },
//         .target = target,
//         .optimize = optimize,
//     });

//     const sdl_path = "SDL2";

//     exe.addIncludePath(std.Build.LazyPath{ .path = sdl_path ++ "include" });
//     exe.addLibraryPath(std.Build.LazyPath{ .path = sdl_path ++ "lib\\x64" });
//     b.installBinFile(sdl_path ++ "lib\\x64\\SDL2.dll", "SDL2.dll");
//     exe.linkSystemLibrary("SDL2");
//     exe.linkLibC();
//     b.installArtifact(exe);
// }

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "chip8",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath(.{ .path = "D:\\Coding_Projects\\zig\\chip8\\SDL2\\include" });
    exe.addLibraryPath(.{ .path = "D:\\Coding_Projects\\zig\\chip8\\SDL2\\lib\\x64" });
    b.installBinFile("D:\\Coding_Projects\\zig\\chip8\\SDL2\\lib\\x64\\SDL2.dll", "SDL2.dll");
    exe.linkSystemLibrary("SDL2");
    exe.linkLibC();
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
