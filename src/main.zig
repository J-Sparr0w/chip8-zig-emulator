const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});

const str = @import("string.zig");
const Chip8 = @import("Chip8.zig").Chip8;
const Platform = @import("platform.zig").Platform;

// Scale: The CHIP-8 video buffer is only 64x32, so we’ll need an integer scale factor to be able to play on our big modern monitors.
// Delay: The CHIP-8 had no specified clock speed, so we’ll use a delay to determine the time in milliseconds between cycles. Different games run best at different speeds, so we can control it here.
// ROM: The ROM file to load.
const Args = struct {
    scale: u8 = 1,
    delay: u16 = 100,
    rom: []const u8,
};

fn usage() void {
    const usage_str =
        \\Usage: chip8 [-params] file_name
        \\
        \\eg:    chip8 -s=2 -d=500 abc.txt OR
        \\       chip8 -scale=2 -delay=500 abc.txt 
        \\
        \\-s, --scale => Scale Factor: The CHIP-8 video buffer is only 64x32,.
        \\-d, --delay => Delay in milliseconds: The CHIP-8 had no specified clock speed. Different games run best at different speeds.
        \\file_name =>  The ROM file to load.
    ;
    std.debug.print("\n{s}\n", .{usage_str});
}

//make the parser generic to reuse it with any argument types
const ArgsParser = struct {
    arg_iter: std.process.ArgIterator,
    args: Args,
    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;

    pub fn init(allocator: std.mem.Allocator) !ArgsParser {
        var parser = ArgsParser{
            .arg_iter = try std.process.argsWithAllocator(allocator),
            .args = undefined,
        };

        return parser;
    }

    pub fn parse(self: *ArgsParser) !void {
        _ = self.arg_iter.skip();
        var iter_count: u8 = 1;
        while (self.arg_iter.next()) |arg| {
            if (iter_count > 3) {
                return error.tooManyArguments;
            }

            if (str.startsWith(arg, "-")) {
                //scale
                if (str.startsWith(arg, "-s=")) {
                    self.args.scale = std.fmt.parseUnsigned(u8, arg[3..], 10) catch |err| {
                        std.debug.print("\nERROR: scale factor could not be parsed. Tried to parse value = '{s}'\n", .{arg[3..]});
                        usage();
                        return err;
                    };
                } else if (str.startsWith(arg, "--scale=")) {
                    self.args.scale = std.fmt.parseUnsigned(u8, arg[str.len("--scale=")..], 10) catch |err| {
                        std.debug.print("\nERROR: scale factor could not be parsed. Tried to parse value = '{s}'\n", .{arg[str.len("--scale=")..]});
                        usage();
                        return err;
                    };
                }
                //delay
                if (str.startsWith(arg, "-d=")) {
                    self.args.delay = std.fmt.parseUnsigned(u16, arg[3..], 10) catch |err| {
                        std.debug.print("\nERROR: delay could not be parsed. Tried to parse value = '{s}'\n", .{arg[3..]});
                        usage();
                        return err;
                    };
                } else if (str.startsWith(arg, "--delay=")) {
                    self.args.delay = std.fmt.parseUnsigned(u16, arg[str.len("--delay=")..], 10) catch |err| {
                        std.debug.print("\nERROR: delay could not be parsed. Tried to parse value = '{s}'\n", .{arg[str.len("--delay=")..]});
                        usage();
                        return err;
                    };
                }
            } else {
                // filename => it is not checked whether it is a valid file.

                var absolute_path = std.fs.realpath(arg, &path_buffer) catch |err| {
                    std.debug.print("\n\nERROR [{s}] => file: {s}\n\n", .{ @errorName(err), arg });
                    // std.debug.print("\ncwd: {s}\n", .{try std.os.getcwd(&out_buffer)});
                    return;
                };
                self.args.rom = absolute_path;
                // std.debug.print("\n\n\npath: {s}\n\n", .{absolute_path});
            }
            iter_count += 1;
        }
    }

    pub fn initAndParse(allocator: std.mem.Allocator) !ArgsParser {
        var parser = ArgsParser.init(allocator) catch |e| {
            std.debug.print("\nERROR: {s}\n", .{@errorName(e)});
            return e;
        };
        parser.parse() catch |e| {
            std.debug.print("\nERROR: {s}\n", .{@errorName(e)});
            return e;
        };
        return parser;
    }

    //calling deinit will deallocate all arguments and that means all string type and similar referenced types will be deallocated.
    pub fn deinit(self: *ArgsParser) void {
        self.arg_iter.deinit();
    }
};

pub inline fn main() !void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa_impl.deinit();
        if (check == .leak) {
            std.debug.print("\n[LEAK] There was a memory leak with the gpa allocator\n", .{});
        }
    }
    const gpa = gpa_impl.allocator();

    //arguments
    var parser = ArgsParser.initAndParse(gpa) catch |e| {
        std.debug.print("\nERROR: {s}\n", .{@errorName(e)});
        return e;
    };
    defer parser.deinit();

    const window_width: i32 = Chip8.VIDEO_WIDTH * @as(i32, @intCast(parser.args.scale));
    const window_height: i32 = Chip8.VIDEO_HEIGHT * @as(i32, @intCast(parser.args.scale));

    var platform = Platform.init("Chip8", window_width, window_height, Chip8.VIDEO_WIDTH, Chip8.VIDEO_HEIGHT) catch |e| {
        std.debug.print("\nERROR: {s}\n\n", .{@errorName(e)});
        return e;
    };

    //Chip8
    var chip = Chip8.init();
    chip.loadRoam(parser.args.rom) catch |e| {
        std.debug.print("\nERROR: {s}\n", .{@errorName(e)});
        return e;
    };

    const cycle_delay: u64 = parser.args.delay;

    const videoPitch = @sizeOf(u32) * Chip8.VIDEO_WIDTH;

    var lastCycleTime = std.time.Instant.now() catch |e| {
        std.debug.print("\nERROR: {s}\n", .{@errorName(e)});
        return e;
    };
    var quit = false;

    while (!quit) {
        quit = Platform.processInput(&chip.keypad);
        // std.debug.print("\n\n!processInput done for current iter: {}\n\n", .{quit});

        const current_time = std.time.Instant.now() catch |e| {
            std.debug.print("\nERROR: {s}\n", .{@errorName(e)});
            return e;
        };
        const elapsed_time_ms: u64 = current_time.since(lastCycleTime) / 1_000_000;

        if (elapsed_time_ms > cycle_delay) {
            lastCycleTime = current_time;

            chip.cycle();

            platform.update(&chip.video, videoPitch);
        }
    }
}
