const std = @import("std");
const ray = @import("raylib");
const rand = std.crypto.random;

const BOARD_COLOR = 0x2E2E2EFF; // Jet Black
const SNAKE_COLOR = 0x81D4FAFF; // Light Blue Pastel
const FOOD_COLOR = 0xFFCDD2FF; // Soft Coral

const Vector2 = struct {
    x: i16,
    y: i16,
};

const Snake = struct {
    size: u16 = 10,
    segments: [1024]Vector2 = .{.{ .x = 0, .y = 0 }} ** 1024,
    pos: Vector2,
    bounds: Vector2,

    pub fn init(pos: Vector2, bounds: Vector2) Snake {
        return .{
            .pos = pos,
            .bounds = bounds,
        };
    }

    pub fn move(self: *Snake, delta: Vector2) void {
        self.pos.x += delta.x;
        self.pos.y += delta.y;

        if (self.pos.x >= self.bounds.x) {
            self.pos.x = 0;
        } else if (self.pos.x < 0) {
            self.pos.x = self.bounds.x - 1;
        }

        if (self.pos.y >= self.bounds.y) {
            self.pos.y = 0;
        } else if (self.pos.y < 0) {
            self.pos.y = self.bounds.y - 1;
        }
        //std.debug.print("x: {}, y:{}\n", .{ self.pos.x, self.pos.y });
        self.shift();
    }

    fn shift(self: *Snake) void {
        var i = self.size - 1;
        while (i > 0) : (i -= 1) {
            self.segments[i] = self.segments[i - 1];
        }
        self.segments[0] = self.pos;
    }
};

const Rect = struct {
    pos: Vector2,
    size: Vector2 = .{ .x = 8, .y = 8 },
    color: u32,
};

const PlayerDirection = enum(u8) {
    LEFT,
    RIGHT,
    TOP,
    BOTTOM,
};

const GameBoard = struct {
    height: u16 = 400,
    width: u16 = 400,
    cols: u16 = 0,
    rows: u16 = 0,
    rect_buffer: std.ArrayList(Rect),
    player: Snake,
    player_direction: PlayerDirection,
    food: Rect,

    pub fn init(alloc: std.mem.Allocator, width: u16, height: u16) GameBoard {
        const cols = width / 10;
        const rows = height / 10;

        return .{
            .height = height,
            .width = width,
            .cols = cols,
            .rows = rows,
            .player = Snake.init(.{ .x = 10, .y = 10 }, .{ .x = @as(i16, @intCast(cols)), .y = @as(i16, @intCast(rows)) }),
            .player_direction = .RIGHT,
            .rect_buffer = std.ArrayList(Rect).init(alloc),
            .food = .{
                .pos = .{
                    .x = @as(i16, @intCast(rand.intRangeAtMost(u16, 0, cols - 1))),
                    .y = @as(i16, @intCast(rand.intRangeAtMost(u16, 0, rows - 1))),
                },
                .color = FOOD_COLOR,
            },
        };
    }

    pub fn deinit(self: *GameBoard) void {
        self.rect_buffer.deinit();
    }

    pub fn predraw(self: *GameBoard) !void {
        std.debug.assert(self.rect_buffer.items.len == 0);
        for (0..self.rows) |i| for (0..self.cols) |j| {
            try self.rect_buffer.append(
                .{
                    .size = .{ .x = 8, .y = 8 },
                    .pos = .{ .x = @as(i16, @intCast(j)), .y = @as(i16, @intCast(i)) },
                    .color = BOARD_COLOR,
                },
            );
        };
    }

    pub fn draw(self: *GameBoard) void {
        //Draw food
        const food_coord: u16 = (@as(u16, @intCast(self.food.pos.y)) * self.cols) + @as(u16, @intCast(self.food.pos.x));
        self.rect_buffer.items[food_coord].color = FOOD_COLOR;

        //Draw player
        for (self.player.segments[0..self.player.size], 0..) |seg, n| {
            const flat_coord: u16 = (@as(u16, @intCast(seg.y)) * self.cols) + @as(u16, @intCast(seg.x));
            std.debug.assert(flat_coord < self.rect_buffer.items.len);
            self.rect_buffer.items[flat_coord].color = SNAKE_COLOR;

            if (n > 0 and self.player.segments[0].x == seg.x and self.player.segments[0].y == seg.y) {
                self.player.size = 3;
            }
            //std.debug.print("Segment: {}, pos: {any}\n", .{ n, seg });
        }

        //Draw board
        for (self.rect_buffer.items) |*rect| {
            ray.drawRectangle(rect.pos.x * 10, rect.pos.y * 10, rect.size.x, rect.size.y, ray.getColor(rect.color));
            rect.color = BOARD_COLOR;
        }
    }
};

export fn _start() void {
    run() catch |err| std.debug.print("Error: {}\n", .{err});
}

pub fn run() !void {
    const screen_width = 800;
    const screen_height = 450;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("Memory leak!");

    var gb = GameBoard.init(gpa.allocator(), screen_width, screen_height);
    defer gb.deinit();

    try gb.predraw();

    ray.initWindow(screen_width, screen_height, "znake");
    errdefer ray.closeWindow();
    defer ray.closeWindow(); // Close window and OpenGL context

    ray.setTargetFPS(10); // Set our game to run at 60 frames-per-second

    while (!ray.windowShouldClose()) {
        ray.beginDrawing();
        defer ray.endDrawing();

        gb.draw();

        switch (gb.player_direction) {
            .RIGHT => gb.player.move(.{ .x = 1, .y = 0 }),
            .LEFT => gb.player.move(.{ .x = -1, .y = 0 }),
            .TOP => gb.player.move(.{ .x = 0, .y = -1 }),
            .BOTTOM => gb.player.move(.{ .x = 0, .y = 1 }),
        }

        ray.clearBackground(ray.getColor(0x000000FF));

        pollKeyEvents(&gb);
        pollPlayerEvents(&gb);
    }
}

fn pollKeyEvents(board: *GameBoard) void {
    const ky = ray.getKeyPressed();
    switch (ky) {
        .key_left => board.player_direction = .LEFT,
        .key_right => board.player_direction = .RIGHT,
        .key_up => board.player_direction = .TOP,
        .key_down => board.player_direction = .BOTTOM,
        else => {},
    }
}

fn pollPlayerEvents(board: *GameBoard) void {
    if (board.player.pos.x == board.food.pos.x and board.player.pos.y == board.food.pos.y) {
        board.player.size += 1;
        board.food.pos = .{
            .x = @as(i16, @intCast(rand.intRangeAtMost(u16, 0, board.cols - 1))),
            .y = @as(i16, @intCast(rand.intRangeAtMost(u16, 0, board.rows - 1))),
        };
    }
}
