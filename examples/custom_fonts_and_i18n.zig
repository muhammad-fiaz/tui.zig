const std = @import("std");
const tui = @import("tui");

// Client-supplied 5x7 custom bitmap font glyphs extending ASCII & Greek/Arabic banners cleanly.
const custom_glyphs = [_]tui.BitmapGlyph{
    .{
        .codepoint = '★',
        .width = 5,
        .height = 7,
        .rows = &.{ 0b00100, 0b00100, 0b11111, 0b01110, 0b01110, 0b11011, 0b10001 },
    },
    .{
        .codepoint = 'Ω',
        .width = 5,
        .height = 7,
        .rows = &.{ 0b01110, 0b10001, 0b10001, 0b10001, 0b01010, 0b01010, 0b11011 },
    },
    // Arabic sample word glyphs ('ز', 'ي', 'ج') for RTL BigText rendering
    .{
        .codepoint = 'ز',
        .width = 5,
        .height = 7,
        .rows = &.{ 0b00100, 0b00000, 0b00010, 0b00010, 0b00100, 0b01000, 0b10000 },
    },
    .{
        .codepoint = 'ي',
        .width = 5,
        .height = 7,
        .rows = &.{ 0b00000, 0b00001, 0b00001, 0b11111, 0b00000, 0b01010, 0b00000 },
    },
    .{
        .codepoint = 'ج',
        .width = 5,
        .height = 7,
        .rows = &.{ 0b01110, 0b00001, 0b00110, 0b01000, 0b10100, 0b01110, 0b00000 },
    },
};

const client_font = tui.BitmapFont{
    .name = "client_brand",
    .default_width = 5,
    .height = 7,
    .glyphs = &custom_glyphs,
    .fallback = &tui.BitmapFont.sans_5x7,
};

const loc_en = tui.Locale{
    .code = "en",
    .direction = .ltr,
    .months = .{
        "January",   "February", "March",    "April",
        "May",       "June",     "July",     "August",
        "September", "October",  "November", "December",
    },
    .weekdays = .{ "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" },
    .entries = &.{
        .{ .key = "heading", .value = "Custom Fonts, Languages & Symbols" },
        .{ .key = "banner", .value = "★ ZIG Ω" },
        .{ .key = "greeting", .value = "Welcome to multi-script terminal rendering!" },
        .{ .key = "confirm", .value = "Confirm" },
        .{ .key = "cal_title", .value = "Calendar (EN)" },
    },
};

// Non-English locales are explicitly defined on the client side:
const loc_es = tui.Locale{
    .code = "es",
    .direction = .ltr,
    .decimal_separator = ',',
    .months = .{
        "Enero",      "Febrero", "Marzo",     "Abril",
        "Mayo",       "Junio",   "Julio",     "Agosto",
        "Septiembre", "Octubre", "Noviembre", "Diciembre",
    },
    .weekdays = .{ "Do", "Lu", "Ma", "Mi", "Ju", "Vi", "Sa" },
    .entries = &.{
        .{ .key = "heading", .value = "Fuentes Personalizadas e Idiomas" },
        .{ .key = "banner", .value = "★ ESPAÑOL Ω" },
        .{ .key = "greeting", .value = "¡Renderizado UTF-8 y calendario español!" },
        .{ .key = "confirm", .value = "Confirmar" },
        .{ .key = "cal_title", .value = "Calendario (ES)" },
    },
};

const loc_ar = tui.Locale{
    .code = "ar",
    .direction = .rtl,
    .months = .{
        "يناير",
        "فبراير",
        "مارس",
        "أبريل",
        "مايو",
        "يونيو",
        "يوليو",
        "أغسطس",
        "سبتمبر",
        "أكتوبر",
        "نوفمبر",
        "ديسمبر",
    },
    .weekdays = .{ "أح", "إث", "ثل", "أر", "خم", "جم", "سب" },
    .entries = &.{
        .{ .key = "heading", .value = "نظام الخطوط واللغات المتعددة" },
        .{ .key = "banner", .value = "★ زيج Ω" },
        .{ .key = "greeting", .value = "مرحبا بكم في مكتبة زيج السريعة!" },
        .{ .key = "confirm", .value = "تأكيد" },
        .{ .key = "cal_title", .value = "التقويم (AR)" },
    },
};

const locales = [_]tui.Locale{ loc_en, loc_es, loc_ar };

const State = struct {
    locale_idx: usize = 0,
    font_mode: tui.FontRenderMode = .half_block,
    cal: tui.CalendarState = .{
        .cursor = tui.Date.init(2026, 11, 27),
        .today = tui.Date.init(2026, 11, 27),
    },
    cal_rect: tui.Rect = tui.Rect.zero,
};

fn buildCalendar(loc: tui.Locale) tui.Calendar {
    return .{
        .month_names = loc.months,
        .weekday_names = loc.weekdays,
        .direction = loc.direction,
        .block = .{ .title = loc.trOr("cal_title", "Calendar"), .focused = true },
    };
}

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    const loc = locales[state.locale_idx];
    if (state.cal.handleEventAt(event, state.cal_rect, buildCalendar(loc), true)) {
        return true;
    }
    if (event == .key and event.key.kind != .release) {
        if (event.key.isChar('l') or event.key.code == .tab) {
            state.locale_idx = (state.locale_idx + 1) % locales.len;
            const next_loc = locales[state.locale_idx];
            try app.setTitle(next_loc.trOr("heading", "Fonts & i18n"));
            return true;
        } else if (event.key.isChar('m')) {
            state.font_mode = switch (state.font_mode) {
                .half_block => .quadrant,
                .quadrant => .braille,
                .braille => .full_block,
                .full_block => .half_block,
            };
            return true;
        }
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const loc = locales[state.locale_idx];
    const banner_h: u16 = if (state.font_mode == .full_block) 9 else 6;

    const layout = ui.rows(4, .{
        .{ .length = 1 },
        .{ .length = banner_h },
        .{ .fill = 1 },
        .{ .length = 1 },
    }, .{});

    var rtl_hdr_buf: [128]u8 = undefined;
    var hdr = layout[0];
    hdr.header(.{
        .title = tui.text.visualOrderInto(loc.trOr("heading", "Custom Fonts & i18n"), loc.direction, &rtl_hdr_buf),
        .subtitle = loc.code,
        .right = "l Language  m Font Mode  Arrows Date",
    }, hdr.area);

    var banner = layout[1].margin(tui.Margin.symmetric(1, 0));
    try banner.panel(.{ .title = "Client Custom 5x7 Font (★ / Ω / ز ي ج + Extended Latin)" }, banner.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            const cur_loc = locales[st.locale_idx];
            try p.bigText(.{
                .text = cur_loc.trOr("banner", "★ ZIG Ω"),
                .font = &client_font,
                .mode = st.font_mode,
                .alignment = .center,
                .direction = cur_loc.direction,
            }, p.area);
        }
    }.draw);

    // Put Calendar on the left when RTL, or on the right when LTR!
    const mid = if (loc.direction == .rtl)
        layout[2].cols(2, .{ .{ .length = 28 }, .{ .fill = 1 } }, .{ .margin = tui.Margin.symmetric(1, 0), .spacing = .{ .space = 1 } })
    else
        layout[2].cols(2, .{ .{ .fill = 1 }, .{ .length = 28 } }, .{ .margin = tui.Margin.symmetric(1, 0), .spacing = .{ .space = 1 } });

    var text_ui = if (loc.direction == .rtl) mid[1] else mid[0];
    var cal_ui = if (loc.direction == .rtl) mid[0] else mid[1];

    const Context = struct { st: *State, loc: tui.Locale };
    try text_ui.panel(.{
        .title = "Scripts, Underlines & Formatting",
        .padding = tui.Padding.symmetric(1, 0),
    }, text_ui.area, Context{ .st = state, .loc = loc }, struct {
        fn draw(ctx: Context, p: *tui.Ui) !void {
            var rtl_buf: [128]u8 = undefined;
            const raw_greet = ctx.loc.trOr("greeting", "");
            const vis_greet = tui.text.visualOrderInto(raw_greet, ctx.loc.direction, &rtl_buf);
            const alignment: tui.Alignment = if (ctx.loc.resolveDirection(raw_greet) == .rtl) .right else .left;
            try p.text(vis_greet, .{ .alignment = alignment, .style = p.theme.accent.patch(.{ .bold = true }) }, null);

            const ul_spans = [_]tui.Span{
                tui.Span.raw("Styles: "),
                tui.Span.styled("Single", p.theme.info.withUnderlineStyle(.single)),
                tui.Span.raw("  "),
                tui.Span.styled("Double", p.theme.warning.withUnderlineStyle(.double)),
                tui.Span.raw("  "),
                tui.Span.styled("Curly", p.theme.err.withUnderlineStyle(.curly)),
                tui.Span.raw("  "),
                tui.Span.styled("Highlight", p.theme.accent.patch(.{ .reverse = true, .bold = true })),
            };
            const ul_lines = [_]tui.Line{tui.Line.fromSpans(&ul_spans)};
            try p.paragraph(.{ .text = tui.Text.fromLines(&ul_lines), .wrap = .word }, null);

            var ar_word: [32]u8 = undefined;
            const ar_vis = tui.text.visualOrderInto("العربية", .rtl, &ar_word);
            const multi = try std.fmt.allocPrint(p.scratchAllocator(), "Scripts: 日本語 한국어 Ελληνικά Кириллица {s} हिन्दी 🚀", .{ar_vis});
            try p.text(multi, .{ .wrap = .word }, null);

            const ic = tui.symbols.icons.unicode;
            var dec_buf: [32]u8 = undefined;
            const num_s = ctx.loc.formatDecimal(98.45, "{d:.2}", &dec_buf);
            var btn_buf: [64]u8 = undefined;
            const vis_btn = tui.text.visualOrderInto(ctx.loc.trOr("confirm", "OK"), ctx.loc.direction, &btn_buf);
            try p.text(try std.fmt.allocPrint(p.scratchAllocator(), "{s} Icons: {s} {s} {s}  Value: {s}  [{s}]", .{
                ic.terminal,
                ic.check,
                ic.star,
                ic.image,
                num_s,
                vis_btn,
            }), .{}, null);
        }
    }.draw);

    state.cal_rect = cal_ui.area;
    try cal_ui.calendar(buildCalendar(loc), &state.cal, cal_ui.area);

    var ft = layout[3];
    ft.statusBar(.{
        .left = &.{
            .{ .text = loc.code, .badge = true },
            .{ .text = @tagName(loc.direction) },
            .{ .text = @tagName(state.font_mode) },
        },
        .right = &.{.{ .text = "l Language  m Font Mode  Arrows Date  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .app = .{ .name = "Fonts & i18n", .version = tui.version, .title = "tui.zig — Custom Fonts & i18n" },
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 96, .height = 24 } } else .auto,
        .settings = .{ .mouse = true, .fps = 24 },
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        // Test English + all font modes, Spanish locale & decimals, and Arabic RTL calendar + custom font
        for ([_]tui.FontRenderMode{ .half_block, .quadrant, .braille, .full_block }) |fm| {
            state.font_mode = fm;
            try app.draw(&state, render);
        }
        state.font_mode = .half_block;

        // 1. Arabic RTL check (RTL month header + reversed columns)
        state.locale_idx = 2;
        try app.draw(&state, render);
        const snap_ar = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap_ar, "2026") != null);

        // 2. Spanish localized calendar + decimal formatting check
        state.locale_idx = 1;
        try app.draw(&state, render);
        const snap_es = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap_es, "Noviembre") != null);
        std.debug.assert(std.mem.indexOf(u8, snap_es, "98,45") != null);
        std.debug.assert(std.mem.indexOf(u8, snap_es, "Highlight") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
