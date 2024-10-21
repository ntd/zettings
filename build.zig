const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = b.addOptions();
    // TODO: autodetect open62541 by default instead of `orelse false`
    const opcua = b.option(bool, "opcua", "Enable OPC/UA server support") orelse false;
    options.addOption(bool, "opcua", opcua);

    const demo = b.addExecutable(.{
        .name = "zettings-demo",
        .root_source_file = b.path("src/demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    demo.root_module.addOptions("config", options);
    if (opcua) {
        demo.linkLibC();
        demo.linkSystemLibrary("open62541");
    }
    b.installArtifact(demo);

    const launch_demo = b.addRunArtifact(demo);
    launch_demo.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        launch_demo.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&launch_demo.step);

    const zettings_tests = b.addTest(.{
        .root_source_file = b.path("src/Zettings.zig"),
        .target = target,
        .optimize = optimize,
    });
    zettings_tests.root_module.addOptions("config", options);

    const run_zettings_tests = b.addRunArtifact(zettings_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_zettings_tests.step);

    if (opcua) {
        const opcuatypes = b.addExecutable(.{
            .name = "opcuatypes",
            .target = target,
            .optimize = optimize,
        });
        opcuatypes.addCSourceFile(.{ .file = b.path("tools/opcuatypes.c") });
        opcuatypes.linkLibC();
        opcuatypes.linkSystemLibrary("open62541");
        b.installArtifact(opcuatypes);

        const launch_opcuatypes = b.addRunArtifact(opcuatypes);
        launch_opcuatypes.step.dependOn(b.getInstallStep());
        const opcuatypes_step = b.step("opcuatypes", "Run opcuatypes app");
        opcuatypes_step.dependOn(&launch_opcuatypes.step);

        const opcua_tests = b.addTest(.{
            .root_source_file = b.path("src/OpcUa.zig"),
            .target = target,
            .optimize = optimize,
        });
        opcua_tests.linkLibC();
        opcua_tests.linkSystemLibrary("open62541");
        const run_opcua_tests = b.addRunArtifact(opcua_tests);
        test_step.dependOn(&run_opcua_tests.step);
    }
}
