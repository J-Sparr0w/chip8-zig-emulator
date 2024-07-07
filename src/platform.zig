const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});

pub const Platform = struct {
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    texture: *c.SDL_Texture,

    pub fn init(title: []const u8, windowWidth: i32, windowHeight: i32, textureWidth: i32, textureHeight: i32) !Platform {
        if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
            std.debug.print("\nERROR: could not initialize SDL.\n", .{});

            return error.SdlLibraryInitError;
        }

        var window = c.SDL_CreateWindow(title.ptr, c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, @intCast(windowWidth), @intCast(windowHeight), c.SDL_WINDOW_SHOWN) orelse {
            std.debug.print("\nERROR: could not initialize SDL window.\n", .{});
            return error.SdlWindowInitError;
        };

        var renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
            std.debug.print("\nERROR: could not initialize SDL renderer.\n", .{});
            return error.SdlRendererInitError;
        };

        var texture = c.SDL_CreateTexture(renderer, c.SDL_PIXELFORMAT_RGBA8888, c.SDL_TEXTUREACCESS_STREAMING, @intCast(textureWidth), @intCast(textureHeight)) orelse {
            std.debug.print("\nERROR: could not create SDL Texture.\n", .{});
            return error.SdlTextureCreationError;
        };
        return Platform{ .window = window, .renderer = renderer, .texture = texture };
    }

    pub fn deinit(self: *Platform) void {
        c.SDL_DestroyTexture(self.texture);
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    pub fn update(self: *Platform, pixels: *const anyopaque, pitch: i32) void {
        _ = c.SDL_UpdateTexture(self.texture, null, pixels, pitch);
        _ = c.SDL_RenderClear(self.renderer);
        _ = c.SDL_RenderCopy(self.renderer, self.texture, null, null);
        _ = c.SDL_RenderPresent(self.renderer);
    }

    pub fn processInput(keys: []u8) bool {
        var quit = false;
        var event: c.SDL_Event = undefined;

        while (c.SDL_PollEvent(&event) == 1) {
            switch (event.type) {
                c.SDL_QUIT => quit = true,
                c.SDL_KEYDOWN => {
                    // std.debug.print("\nKEY DOWN EVENT: {}\n", .{event.key.keysym.sym});
                    switch (event.key.keysym.sym) {
                        c.SDLK_ESCAPE => quit = true,
                        c.SDLK_x => keys[0] = 1,
                        c.SDLK_1 => keys[1] = 1,
                        c.SDLK_2 => keys[2] = 1,
                        c.SDLK_3 => keys[3] = 1,
                        c.SDLK_q => keys[4] = 1,
                        c.SDLK_w => keys[5] = 1,
                        c.SDLK_e => keys[6] = 1,
                        c.SDLK_a => keys[7] = 1,
                        c.SDLK_s => keys[8] = 1,
                        c.SDLK_d => keys[9] = 1,
                        c.SDLK_z => keys[0xA] = 1,
                        c.SDLK_c => keys[0xB] = 1,
                        c.SDLK_4 => keys[0xC] = 1,
                        c.SDLK_r => keys[0xD] = 1,
                        c.SDLK_f => keys[0xE] = 1,
                        c.SDLK_v => keys[0xF] = 1,
                        else => {},
                    }
                },
                c.SDL_KEYUP => {
                    switch (event.key.keysym.sym) {
                        c.SDLK_x => keys[0] = 0,
                        c.SDLK_1 => keys[1] = 0,
                        c.SDLK_2 => keys[2] = 0,
                        c.SDLK_3 => keys[3] = 0,
                        c.SDLK_q => keys[4] = 0,
                        c.SDLK_w => keys[5] = 0,
                        c.SDLK_e => keys[6] = 0,
                        c.SDLK_a => keys[7] = 0,
                        c.SDLK_s => keys[8] = 0,
                        c.SDLK_d => keys[9] = 0,
                        c.SDLK_z => keys[0xA] = 0,
                        c.SDLK_c => keys[0xB] = 0,
                        c.SDLK_4 => keys[0xC] = 0,
                        c.SDLK_r => keys[0xD] = 0,
                        c.SDLK_f => keys[0xE] = 0,
                        c.SDLK_v => keys[0xF] = 0,
                        else => {},
                    }
                },
                else => {},
            }
        }
        return quit;
    }
};
