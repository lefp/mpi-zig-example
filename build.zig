const std = @import("std");
const Allocator = std.mem.Allocator;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zmpi",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addCSourceFile("src/zmpi-cwrapper.c", &[_][]u8{});

    // mpi include paths
    const mpi_include_dirs = MpiPaths.init(.IncludeDirs, b.allocator) catch @panic("Failed to get MPI include dirs");
    defer mpi_include_dirs.deinit(b.allocator);
    for (mpi_include_dirs.paths) |path| exe.addIncludePath(path); // @todo addSystemIncludePath?

    // mpi library paths
    const mpi_lib_dirs = MpiPaths.init(.LibraryDirs, b.allocator) catch @panic("Failed to get MPI library dirs");
    defer mpi_lib_dirs.deinit(b.allocator);
    for (mpi_lib_dirs.paths) |path| exe.addLibraryPath(path);

    // @todo we need to parse the rest of the output of `mpicc -showme`.
    // Like the -Wl flags. How do we get Zig to accept the -Wl flags?

    exe.linkSystemLibraryNeeded("c");
    exe.linkSystemLibraryNeeded("mpi");

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a RunStep in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

const MpiPaths = struct {
    paths: [][]u8,
    _mpi_stdout: []u8, // `paths` slices point to substrings of _mpi_stdout

    const Type = enum { IncludeDirs, LibraryDirs };

    /// Iff there are no include paths, `paths` will simply be empty.
    /// Iff no error is returned, caller must call `deinit()` to free memory the memory.
    fn init(path_type: Type, allocator: Allocator) !MpiPaths {
        const result = try std.ChildProcess.exec(.{
            .allocator = allocator,
            .argv = &[_][]const u8 {
                "mpicc",
                switch (path_type) { .IncludeDirs => "-showme:incdirs", .LibraryDirs => "-showme:libdirs" }
            },
            // @todo max_output_bytes?
        });
        errdefer allocator.free(result.stdout);
        allocator.free(result.stderr); // we don't use this
        std.log.debug("Unparsed paths: `{s}`", .{result.stdout});

        // from `man 1 mpicc`:
        //     --showme:incdirs
        //         Outputs a space-delimited (but otherwise undecorated) list of directories that the
        //         wrapper compiler would have provided to the underlying C compiler to indicate where
        //         relevant header files are located.
        //      --showme:libdirs
        //         Outputs a space-delimited (but otherwise undecorated) list of directories that the
        //         wrapper compiler would have provided to the underlying linker to indicate where relevant
        //         libraries are located.


        // get number of dirs, treating all contiguous whitespace as a single separator
        const n_paths = get_n_paths: {
            var n: usize = 0;
            var prev_char_was_whitespace = true;
            for (result.stdout) |char| {
                const is_whitespace = std.ascii.isWhitespace(char);
                if (!is_whitespace and prev_char_was_whitespace) n += 1;
                prev_char_was_whitespace = is_whitespace;
            }
            break :get_n_paths n;
        };

        // get paths
        const paths = try allocator.alloc([]u8, n_paths);
        errdefer allocator.free(paths);
        {
            var current_path: usize = 0;
            var prev_char_was_whitespace = true;
            var path_start: usize = undefined;
            for (result.stdout, 0..) |char, i| {
                const is_whitespace = std.ascii.isWhitespace(char);
                // detect start of path
                if (!is_whitespace and prev_char_was_whitespace) path_start = i
                // detect end of path
                else if (is_whitespace and !prev_char_was_whitespace) {
                    paths[current_path] = result.stdout[path_start..i];
                    current_path += 1;
                }
                prev_char_was_whitespace = is_whitespace;
            }
        }
        std.log.debug("Parsed paths:", .{});
        for (paths) |path| std.log.debug("    `{s}`", .{path});

        return MpiPaths { .paths = paths, ._mpi_stdout = result.stdout };
    }
    fn deinit(self: MpiPaths, allocator: Allocator) void {
        allocator.free(self.paths);
        allocator.free(self._mpi_stdout);
    }
};
