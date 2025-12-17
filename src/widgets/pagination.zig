// Pagination widget for navigating through multiple pages of content.
// Supports various display modes and customizable page sizes.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;
const Event = @import("../event/events.zig").Event;

pub const PaginationMode = enum {
    simple,
    full,
    compact,
};

pub const Pagination = struct {
    current_page: usize = 1,
    total_pages: usize = 1,
    mode: PaginationMode = .full,
    base: widget.StatefulWidget = .{},
    style: Style = Style.default,
    on_change: ?*const fn (usize) void = null,

    pub fn init(total_pages: usize) Pagination {
        return .{ .total_pages = total_pages };
    }

    pub fn withMode(self: Pagination, mode: PaginationMode) Pagination {
        var result = self;
        result.mode = mode;
        return result;
    }

    pub fn withOnChange(self: Pagination, callback: *const fn (usize) void) Pagination {
        var result = self;
        result.on_change = callback;
        return result;
    }

    pub fn render(self: *Pagination, ctx: *widget.RenderContext) void {
        var sub = ctx.getSubScreen();

        switch (self.mode) {
            .simple => self.renderSimple(&sub),
            .full => self.renderFull(&sub),
            .compact => self.renderCompact(&sub),
        }
    }

    fn renderSimple(self: *Pagination, sub: anytype) void {
        var buf: [64]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "Page {d} of {d}", .{ self.current_page, self.total_pages }) catch "Page ? of ?";

        sub.setStyle(self.style);
        sub.moveCursor(0, 0);
        sub.putString(text);

        // Navigation
        sub.moveCursor(20, 0);
        if (self.current_page > 1) {
            sub.setStyle(self.style.setFg(Color.cyan));
            sub.putString("◀ Prev");
        } else {
            sub.setStyle(self.style.dim());
            sub.putString("◀ Prev");
        }

        sub.moveCursor(30, 0);
        if (self.current_page < self.total_pages) {
            sub.setStyle(self.style.setFg(Color.cyan));
            sub.putString("Next ▶");
        } else {
            sub.setStyle(self.style.dim());
            sub.putString("Next ▶");
        }
    }

    fn renderFull(self: *Pagination, sub: anytype) void {
        var x: u16 = 0;

        // Previous button
        sub.moveCursor(x, 0);
        if (self.current_page > 1) {
            sub.setStyle(self.style.setFg(Color.cyan));
            sub.putString("◀");
        } else {
            sub.setStyle(self.style.dim());
            sub.putString("◀");
        }
        x += 2;

        // Page numbers
        const max_visible: usize = 7;
        var start_page: usize = 1;
        var end_page: usize = self.total_pages;

        if (self.total_pages > max_visible) {
            if (self.current_page <= max_visible / 2) {
                end_page = max_visible;
            } else if (self.current_page >= self.total_pages - max_visible / 2) {
                start_page = self.total_pages - max_visible + 1;
            } else {
                start_page = self.current_page - max_visible / 2;
                end_page = self.current_page + max_visible / 2;
            }
        }

        if (start_page > 1) {
            sub.moveCursor(x, 0);
            sub.setStyle(self.style.dim());
            sub.putString("...");
            x += 4;
        }

        for (start_page..end_page + 1) |page| {
            sub.moveCursor(x, 0);
            if (page == self.current_page) {
                sub.setStyle(self.style.bold().setFg(Color.yellow));
            } else {
                sub.setStyle(self.style.setFg(Color.fromRGB(150, 150, 170)));
            }

            var buf: [8]u8 = undefined;
            const page_str = std.fmt.bufPrint(&buf, "{d}", .{page}) catch "?";
            sub.putString(page_str);
            x += @intCast(page_str.len + 2);
        }

        if (end_page < self.total_pages) {
            sub.moveCursor(x, 0);
            sub.setStyle(self.style.dim());
            sub.putString("...");
            x += 4;
        }

        // Next button
        sub.moveCursor(x, 0);
        if (self.current_page < self.total_pages) {
            sub.setStyle(self.style.setFg(Color.cyan));
            sub.putString("▶");
        } else {
            sub.setStyle(self.style.dim());
            sub.putString("▶");
        }
    }

    fn renderCompact(self: *Pagination, sub: anytype) void {
        var buf: [32]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "{d}/{d}", .{ self.current_page, self.total_pages }) catch "?/?";

        sub.setStyle(self.style);
        sub.moveCursor(0, 0);
        sub.putString(text);
    }

    pub fn handleEvent(self: *Pagination, event: Event) widget.EventResult {
        if (event == .key) {
            switch (event.key.key) {
                .left => {
                    if (self.current_page > 1) {
                        self.current_page -= 1;
                        if (self.on_change) |cb| cb(self.current_page);
                        return .needs_redraw;
                    }
                },
                .right => {
                    if (self.current_page < self.total_pages) {
                        self.current_page += 1;
                        if (self.on_change) |cb| cb(self.current_page);
                        return .needs_redraw;
                    }
                },
                .home => {
                    if (self.current_page != 1) {
                        self.current_page = 1;
                        if (self.on_change) |cb| cb(self.current_page);
                        return .needs_redraw;
                    }
                },
                .end => {
                    if (self.current_page != self.total_pages) {
                        self.current_page = self.total_pages;
                        if (self.on_change) |cb| cb(self.current_page);
                        return .needs_redraw;
                    }
                },
                else => {},
            }
        }
        return .ignored;
    }

    pub fn setPage(self: *Pagination, page: usize) void {
        if (page >= 1 and page <= self.total_pages) {
            self.current_page = page;
            if (self.on_change) |cb| cb(self.current_page);
        }
    }

    pub fn nextPage(self: *Pagination) bool {
        if (self.current_page < self.total_pages) {
            self.current_page += 1;
            if (self.on_change) |cb| cb(self.current_page);
            return true;
        }
        return false;
    }

    pub fn previousPage(self: *Pagination) bool {
        if (self.current_page > 1) {
            self.current_page -= 1;
            if (self.on_change) |cb| cb(self.current_page);
            return true;
        }
        return false;
    }
};

test "Pagination creation" {
    const pagination = Pagination.init(10);
    try std.testing.expectEqual(@as(usize, 1), pagination.current_page);
    try std.testing.expectEqual(@as(usize, 10), pagination.total_pages);
}

test "Pagination navigation" {
    var pagination = Pagination.init(5);
    
    try std.testing.expect(pagination.nextPage());
    try std.testing.expectEqual(@as(usize, 2), pagination.current_page);
    
    try std.testing.expect(pagination.previousPage());
    try std.testing.expectEqual(@as(usize, 1), pagination.current_page);
    
    try std.testing.expect(!pagination.previousPage());
}

test "Pagination set page" {
    var pagination = Pagination.init(10);
    pagination.setPage(5);
    try std.testing.expectEqual(@as(usize, 5), pagination.current_page);
    
    pagination.setPage(20);
    try std.testing.expectEqual(@as(usize, 5), pagination.current_page);
}
