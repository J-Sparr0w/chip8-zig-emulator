const std = @import("std");

const Fonts = struct {
    const FONTSET_SIZE = 80;
    const FONTSET_START_ADDRESS = 0x50;
    const fontset: [FONTSET_SIZE]u8 =
        .{
        0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
        0x20, 0x60, 0x20, 0x20, 0x70, // 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
        0x90, 0x90, 0xF0, 0x10, 0x10, // 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
        0xF0, 0x10, 0x20, 0x40, 0x40, // 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, // A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
        0xF0, 0x80, 0x80, 0x80, 0xF0, // C
        0xE0, 0x90, 0x90, 0x90, 0xE0, // D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
        0xF0, 0x80, 0xF0, 0x80, 0x80, // F
    };
};

pub const Chip8 = struct {
    const Self = @This();
    const MEM_START_ADDR = 0x200;
    pub const VIDEO_WIDTH = 64;
    pub const VIDEO_HEIGHT = 32;

    registers: [16]u8, //V0 to VF
    // 0x000 to 0xFFF -> 4096B memory
    // 0x050-0x0A0: Storage space for the 16 built-in characters (0 through F), which we will need to manually put into our memory because ROMs will be looking for those characters.
    // 0x200-0xFFF: Instructions from the ROM will be stored starting at 0x200, and anything left after the ROM’s space is free to use.
    memory: [4096]u8,
    index_register: u16,
    pc: u16,
    stack: [16]u16,
    sp: u8,
    delay_timer: u8,
    sound_timer: u8,
    keypad: [16]u8,
    //video array => [row0, row1, row2...row31].
    //                   where rown -> col0, col1, col2, ..., col63
    video: [64 * 32]u32,
    opcode: u16,

    pub inline fn init() Chip8 {
        var chip8 = Chip8{
            .registers = [_]u8{0} ** 16,
            .memory = [_]u8{0} ** 4096,
            .index_register = 0,
            .pc = MEM_START_ADDR,
            .stack = [_]u16{0} ** 16,
            .sp = 0,
            .delay_timer = 0,
            .sound_timer = 0,
            .keypad = [_]u8{0} ** 16,
            .video = undefined,
            .opcode = undefined,
        };
        chip8.loadFonts();
        return chip8;
    }

    pub inline fn loadRoam(self: *Self, file_name: []const u8) !void {
        const file = try std.fs.cwd().openFile(file_name, .{});
        defer file.close();
        const size = try std.fs.File.read(file, self.memory[MEM_START_ADDR..]);
        _ = size;
        // std.debug.print("memory: {any}", .{self.memory[MEM_START_ADDR..size]});
        // std.debug.print("\n memory: {x}\n", .{std.fmt.fmtSliceHexUpper(self.memory[0 .. MEM_START_ADDR + size])});
        // std.debug.print("instr at 0x200 => {X}{X}", .{ self.memory[0x200], self.memory[0x201] });

        // std.debug.print("\n\nOpcode", .{});
        // for (0..size) |i| {
        //     std.debug.print("\t{X}{X}\n", .{ self.memory[MEM_START_ADDR + i], self.memory[MEM_START_ADDR + i + 1] });
        // }
        // std.debug.print("\nOpcode ended\n", .{});
    }

    inline fn loadFonts(self: *Self) void {
        var i: u8 = 0;
        while (i < Fonts.FONTSET_SIZE) : (i += 1) {
            self.memory[Fonts.FONTSET_START_ADDRESS + i] = Fonts.fontset[i];
        }
    }

    pub inline fn cycle(self: *Self) void {
        //Fetch instruction (2 bytes from memory)
        self.opcode = std.math.shl(u16, self.memory[self.pc], 8) | self.memory[self.pc + 1];

        //Increment PC before execution
        self.pc += 2;

        //Decode
        self.decode();

        if (self.delay_timer > 0) {
            self.delay_timer -= 1;
        }

        if (self.sound_timer > 0) {
            self.sound_timer -= 1;
        }
    }

    inline fn decode(self: *Self) void {
        const msb_opcode = self.opcode & 0xF000;
        switch (msb_opcode) {
            0x0 => {
                switch (self.opcode) {
                    0xE0 => self.op_cls(),
                    0xEE => self.op_ret(),
                    else => self.OP_NULL(),
                }
            },
            0x1000 => {
                self.op_jpAddr();
            },
            0x2000 => {
                self.op_call();
            },
            0x3000 => {
                self.op_seVx();
            },
            0x4000 => {
                self.op_sneVx();
            },
            0x5000 => {
                self.op_seVxVy();
            },
            0x6000 => {
                self.op_ldByteToReg();
            },
            0x7000 => {
                self.op_addVxByte();
            },
            0x8000 => {
                switch (self.opcode & 0x000F) {
                    0x0 => self.op_setXAsY(),
                    0x1 => self.op_orVxVy(),

                    0x2 => self.op_andVxVy(),
                    0x3 => self.op_xorVxVy(),
                    0x4 => self.op_addVxVy(),
                    0x5 => self.op_subVxVy(),
                    0x6 => self.op_shrVx(),
                    0x7 => self.op_subNVxVy(),
                    0xE => self.op_shlVx(),
                    else => self.OP_NULL(),
                }
            },
            0x9000 => {
                self.op_sneVxVy();
            },
            0xA000 => {
                self.op_loadIndex();
            },
            0xB000 => {
                self.op_jumpToAddr();
            },
            0xC000 => {
                self.op_rndAndVx();
            },
            0xD000 => {
                self.op_displaySprite();
            },
            0xE000 => {
                switch (self.opcode & 0x000F) {
                    0x1 => self.op_skipIfVxPressed(),
                    0xE => self.op_skipIfVxNotPressed(),
                    else => self.OP_NULL(),
                }
            },

            0xF000 => {
                switch (self.opcode & 0x00FF) {
                    0x07 => self.op_setVxDT(),
                    0x0A => self.op_setVxK(),
                    0x15 => self.op_setDtVx(),
                    0x18 => self.op_setStVx(),
                    0x1E => self.op_addIVx(),
                    0x29 => self.op_setIndexToFont(),
                    0x33 => self.op_storeBCD(),
                    0x55 => self.op_storeUptoVx(),
                    0x65 => self.op_readUptoVx(),
                    else => self.OP_NULL(),
                }
            },
            else => self.OP_NULL(),
        }
    }

    inline fn OP_NULL(self: Self) void {
        _ = self;
    }
    //cls: 00E0
    inline fn op_cls(self: *Self) void {
        @memset(&self.video, 0);
    }
    //ret: 00EE
    inline fn op_ret(self: *Self) void {
        self.sp -= 1;
        self.pc = self.stack[self.sp];
    }
    //JP addr: 1nnn
    inline fn op_jpAddr(self: *Self) void {
        self.pc = self.opcode & 0x0FFF;
    }

    //call: 2nnn
    inline fn op_call(self: *Self) void {
        const addr = self.opcode & 0x0FFF;

        self.stack[self.sp] = self.pc;
        self.sp += 1;
        self.pc = addr;
    }

    //SE Vx, byte: 3xkk, Skip next instruction if Vx = kk.
    inline fn op_seVx(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        const kk = self.opcode & 0x00FF;
        if (self.registers[vx] == kk) {
            self.pc += 2;
        }
    }

    //SNE Vx, byte: 4xkk, Skip next instruction if Vx != kk.
    inline fn op_sneVx(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        const kk = self.opcode & 0x00FF;
        if (self.registers[vx] != kk) {
            self.pc += 2;
        }
    }

    //SE Vx, Vy: 5xy0, Skip next instruction if Vx = Vy.
    inline fn op_seVxVy(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        const vy = std.math.shr(u16, self.opcode & 0x00F0, 4);
        if (self.registers[vx] == self.registers[vy]) {
            self.pc += 2;
        }
    }

    // LD Vx, byte: 6xkk, Set Vx = kk.
    inline fn op_ldByteToReg(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        const byte = self.opcode & 0x00FF;
        self.registers[vx] = @truncate(byte);
        // std.debug.print("\n\tvx=> {X}, byte=> {X}", .{ vx, byte });
        // std.debug.print("\n\tregisters: {}\n", .{std.fmt.fmtSliceHexUpper(&self.registers)});
    }

    // ADD Vx, byte: 7xkk, Set Vx = Vx + kk.
    inline fn op_addVxByte(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        const byte = self.opcode & 0x00FF;
        self.registers[vx] = @addWithOverflow(self.registers[vx], @as(u8, @truncate(byte)))[0];
    }
    // LD Vx, Vy: 8xy0, Set Vx = Vy.
    inline fn op_setXAsY(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        const vy = std.math.shr(u16, self.opcode & 0x00F0, 4);
        self.registers[vx] = self.registers[vy];
    }

    //OR Vx, Vy: 8xy1, Set Vx = Vx OR Vy.
    inline fn op_orVxVy(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        const vy = std.math.shr(u16, self.opcode & 0x00F0, 4);
        self.registers[vx] = self.registers[vx] | self.registers[vy];
    }
    //AND Vx, Vy: 8xy2, Set Vx = Vx AND Vy.
    inline fn op_andVxVy(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        const vy = std.math.shr(u16, self.opcode & 0x00F0, 4);
        self.registers[vx] = self.registers[vx] & self.registers[vy];
    }
    //XOR Vx, Vy: 8xy3, Set Vx = Vx XOR Vy.
    inline fn op_xorVxVy(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        const vy = std.math.shr(u16, self.opcode & 0x00F0, 4);
        self.registers[vx] = self.registers[vx] ^ self.registers[vy];
    }

    //ADD Vx, Vy: 8xy4, Set Vx = Vx + Vy, Set VF = carry.
    inline fn op_addVxVy(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        const vy = std.math.shr(u16, self.opcode & 0x00F0, 4);
        // const sum: u8 = self.registers[vx] + self.registers[vy];
        const sum = @addWithOverflow(self.registers[vx], self.registers[vy]);

        if (sum[1] == 1) {
            //set carry
            self.registers[0xF] = 1;
        } else {
            self.registers[0xF] = 0;
        }

        self.registers[vx] = sum[0] & 0xFF;
    }

    //SUB Vx, Vy: 8xy5, Set Vx = Vx - Vy, If Vx > Vy, then VF is set to 1, otherwise 0. Then Vy is subtracted from Vx, and the results stored in Vx.
    inline fn op_subVxVy(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        const vy = std.math.shr(u16, self.opcode & 0x00F0, 4);

        if (vx > vy) {
            self.registers[0xF] = 1;
        } else {
            self.registers[0xF] = 0;
        }

        self.registers[vx] = @subWithOverflow(self.registers[vx], self.registers[vy])[0];
    }

    //SHR Vx: 8xy6, Set Vx = Vx SHR 1, If the least-significant bit of Vx is 1, then VF is set to 1, otherwise 0. Then Vx is divided by 2.
    inline fn op_shrVx(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);

        self.registers[0xF] = self.registers[vx] & 0x1;
        self.registers[vx] = self.registers[vx] >> 1;
    }

    //SUBN Vx,Vy: 8xy7, Set Vx = Vx - Vy, If Vy > Vx, then VF is set to 1, otherwise 0. Then Vx is subtracted from Vy, and the results stored in Vx.
    inline fn op_subNVxVy(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        const vy = std.math.shr(u16, self.opcode & 0x00F0, 4);

        if (vy > vx) {
            self.registers[0xF] = 1;
        } else {
            self.registers[0xF] = 0;
        }

        self.registers[vx] = @subWithOverflow(self.registers[vy], self.registers[vx])[0];
    }

    //SHL Vx:8xyE, Set Vx = Vx SHL 1. If the most-significant bit of Vx is 1, then VF is set to 1, otherwise to 0. Then Vx is multiplied by 2.
    inline fn op_shlVx(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);

        self.registers[0xF] = std.math.shr(u8, self.registers[vx] & 0x8, 7);
        self.registers[vx] = std.math.shl(u8, self.registers[vx], 1);
    }

    //SNE Vx, Vy: 9xy0
    inline fn op_sneVxVy(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        const vy = std.math.shr(u16, self.opcode & 0x00F0, 4);

        if (self.registers[vx] != self.registers[vy]) {
            self.pc += 2;
        }
    }

    //LD I, addr: Annn. Set I = nnn.
    inline fn op_loadIndex(self: *Self) void {
        self.index_register = self.opcode & 0x0FFF;
    }

    //JP V0, addr: Bnnn. Jump to location nnn + V0.
    inline fn op_jumpToAddr(self: *Self) void {
        const addr = self.opcode & 0x0FFF;
        self.pc = self.registers[0] + addr;
        std.debug.print("\n\tNext PC: {}", .{self.pc});
    }

    //RND Vx, byte: Cxkk. Set Vx = random byte AND Vx
    inline fn op_rndAndVx(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        const byte = self.opcode & 0x00FF;
        var rand_gen = std.rand.DefaultPrng.init(0);
        self.registers[vx] = rand_gen.random().int(u8) & @as(u8, @truncate(byte));
    }

    //DRW Vx,Vy,nibble :Dxyn. Display n-byte sprite starting at memory location I at (Vx,Vy), set VF=collision.
    inline fn op_displaySprite(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        const vy = std.math.shr(u16, self.opcode & 0x00F0, 4);
        const height = self.opcode & 0x000F;

        // std.debug.print("\nGoing to draw => {}, op: {X}, memory[pc]: {X}{X}", .{ std.fmt.fmtSliceHexUpper(self.memory[self.index_register..(self.index_register + height)]), self.opcode, self.memory[self.pc], self.memory[self.pc + 1] });

        //wrap if it goes beyond screen
        var xPos = self.registers[vx] % VIDEO_WIDTH;
        var yPos = self.registers[vy] % VIDEO_HEIGHT;

        // Vf is used as collision flag
        self.registers[0xf] = 0;

        for (0..height) |row| {
            const spriteByte: u8 = self.memory[self.index_register + row];

            for (0..8) |col| {
                const sprite_pixel: u8 = spriteByte & std.math.shr(u8, 0x80, col);
                const screen_pixel: *u32 = &self.video[(yPos + row) * VIDEO_WIDTH + (xPos + col)];

                if (sprite_pixel > 0) {
                    if (screen_pixel.* == 0xFFFFFFFF) {
                        self.registers[0xf] = 1;
                    }
                    screen_pixel.* ^= 0xFFFFFFFF;
                }
            }
        }
    }

    //SKP Vx: Ex9E. Skip next instruction if key with the value registers[vx] is pressed.
    inline fn op_skipIfVxPressed(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        // std.debug.print("\n\t!skip if {} is pressed, keys=> {}", .{ self.registers[vx], std.fmt.fmtSliceHexUpper(&self.keypad) });
        if (self.keypad[self.registers[vx]] > 0) {
            self.pc += 2;
        }
    }

    //SKNP Vx: ExA1. Skip next instruction if key with the value registers[vx] is not pressed.
    inline fn op_skipIfVxNotPressed(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        if (self.keypad[self.registers[vx]] <= 0) {
            self.pc += 2;
        }
    }

    //LD Vx, DT: Fx07. Set Vx = delay timer value
    inline fn op_setVxDT(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        self.registers[vx] = self.delay_timer;
    }

    //LD Vx, K: Fx0A. Wait for a key press, store the value of the key in Vx.
    inline fn op_setVxK(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);

        std.debug.print("\n\t!wait for keypress", .{});

        if (self.keypad[0] == 1) {
            self.registers[vx] = 0;
        } else if (self.keypad[1] == 1) {
            self.registers[vx] = 1;
        } else if (self.keypad[2] == 1) {
            self.registers[vx] = 2;
        } else if (self.keypad[3] == 1) {
            self.registers[vx] = 3;
        } else if (self.keypad[4] == 1) {
            self.registers[vx] = 4;
        } else if (self.keypad[5] == 1) {
            self.registers[vx] = 5;
        } else if (self.keypad[6] == 1) {
            self.registers[vx] = 6;
        } else if (self.keypad[7] == 1) {
            self.registers[vx] = 7;
        } else if (self.keypad[8] == 1) {
            self.registers[vx] = 8;
        } else if (self.keypad[9] == 1) {
            self.registers[vx] = 9;
        } else if (self.keypad[10] == 1) {
            self.registers[vx] = 10;
        } else if (self.keypad[11] == 1) {
            self.registers[vx] = 11;
        } else if (self.keypad[12] == 1) {
            self.registers[vx] = 12;
        } else if (self.keypad[13] == 1) {
            self.registers[vx] = 13;
        } else if (self.keypad[14] == 1) {
            self.registers[vx] = 14;
        } else if (self.keypad[15] == 1) {
            self.registers[vx] = 15;
        } else {
            //decrement pc by 2 if key is not pressed.
            self.pc -= 2;
        }
    }

    //LD DT, Vx: Fx15. Set delay timer value = Vx
    fn op_setDtVx(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        self.delay_timer = self.registers[vx];
    }

    //LD ST, Vx: Fx18. Set sound timer value = Vx
    inline fn op_setStVx(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        self.sound_timer = self.registers[vx];
    }

    //ADD I, Vx: Fx1E. Set I = I + vx.
    inline fn op_addIVx(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        self.index_register += self.registers[vx];
    }

    //LD F, Vx: Fx29. Vx is a font value between 0-F. Load the address of the font into index_register.
    inline fn op_setIndexToFont(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        self.index_register = Fonts.FONTSET_START_ADDRESS + (5 * self.registers[vx]);
    }

    //LD B, Vx: Fx33. Store BCD representation of Vx in memory locations I, I+1, and I+2.
    inline fn op_storeBCD(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);
        var value = self.registers[vx];

        inline for (0..3) |i| {
            const idx = 2 - i;
            const mod = value % 10;
            self.memory[self.index_register + idx] = mod;
            value /= 10;
        }
    }

    //LD [I], Vx: Fx55. Store registers V0 through Vx in memory starting at location I.
    inline fn op_storeUptoVx(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);

        for (0..vx + 1) |i| {
            self.memory[self.index_register + i] = self.registers[vx];
        }
    }

    //LD  Vx,[I]: Fx65. Read registers V0 through Vx in memory starting at location I.
    inline fn op_readUptoVx(self: *Self) void {
        const vx = std.math.shr(u16, self.opcode & 0x0F00, 8);

        for (0..vx + 1) |i| {
            self.registers[vx] = self.memory[self.index_register + i];
        }
    }
};
