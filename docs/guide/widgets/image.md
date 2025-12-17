# Image

Image display widget with multiple protocol support.

## Basic Usage

```zig
const image_data = try loadImage("photo.png");

var image = tui.Image.init(image_data, 100, 100)
    .withProtocol(.kitty);
```

## Features

- Kitty graphics protocol
- iTerm2 inline images
- Sixel graphics
- ASCII art fallback
- Automatic protocol detection

## API

```zig
pub fn init(data: []const u8, width: u16, height: u16) Image
pub fn withProtocol(self: Image, protocol: ImageProtocol) Image

pub const ImageProtocol = enum {
    kitty,
    iterm2,
    sixel,
    ascii,
};
```

## Example

```zig
const ImageViewer = struct {
    image: tui.Image,
    data: []const u8,

    pub fn init(data: []const u8) ImageViewer {
        return .{
            .data = data,
            .image = tui.Image.init(data, 80, 40).withProtocol(.ascii),
        };
    }

    pub fn render(self: *ImageViewer, ctx: *tui.RenderContext) void {
        const rect = tui.Rect{ .x = 5, .y = 5, .width = 80, .height = 40 };
        var img_ctx = ctx.child(rect);
        self.image.render(&img_ctx);
    }
};
```

## Protocol Support

- **Kitty**: Best quality, modern terminals
- **iTerm2**: macOS iTerm2 terminal
- **Sixel**: Legacy graphics protocol
- **ASCII**: Universal fallback
