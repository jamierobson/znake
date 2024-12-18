const std = @import("std");
const game = @import("root.zig");

pub fn main() !void {
    try game.run();
}
