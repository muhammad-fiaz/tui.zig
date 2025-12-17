const tui = @import("tui");

pub const ImgApp = struct {
    img: tui.Image,

    pub fn init() ImgApp {
        var data: [100]u8 = undefined;
        for (0..data.len) |i| {
            data[i] = @as(u8, (i * 7) % 256);
        }
        return ImgApp{ .img = tui.Image.init(data[0..], 10, 10).withProtocol(.ascii) };
    }

    pub fn render(self: *ImgApp, ctx: *tui.RenderContext) void {
        self.img.base.bounds = ctx.bounds;
        self.img.render(ctx);
    }
};

pub fn main() !void {
    var app = try tui.App.init(.{});
    defer app.deinit();

    var root = ImgApp.init();
    try app.setRoot(&root);

    try app.run();
}
