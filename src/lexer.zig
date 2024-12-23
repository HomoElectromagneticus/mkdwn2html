const std = @import("std");
const Symbol = @import("main.zig").Symbol;
const Kind = @import("main.zig").Kind;

pub fn lexMarkdown(markdown: []const u8, symbols: *std.ArrayList(Symbol)) !void {
    // handle empty input
    if (markdown.len == 0) return;

    var header_depth: u8 = 0;
    var last_pos: usize = 0;

    // go through the source character-by-character
    for (markdown, 0..) |character, current_pos| {
        // HEADERS
        // if we hit a '#' and one of the following is true:
        if (character == '#') {
            // we're at the first character of a file
            if (current_pos == 0) {
                header_depth = 1;
                try symbols.append(.{
                    .kind = Kind.header,
                    .level = header_depth,
                    .resource = markdown[last_pos..current_pos],
                });
                last_pos = current_pos + 1;
                continue;
            }
            // the previous character was a newline
            if (markdown[current_pos - 1] == '\n') {
                header_depth = 1;
                try symbols.append(.{
                    .kind = Kind.header,
                    .level = header_depth,
                });
                last_pos = current_pos + 1;
                continue;
            }
            // previous character was a '#' and we are already in "header mode"
            if (markdown[current_pos - 1] == '#' and header_depth > 0) {
                header_depth += 1;
                symbols.items[symbols.items.len - 1].level = header_depth;
                last_pos = current_pos + 1;
                continue;
            }
        }

        // BOLD AND ITALICS
        // if we hit a '*' or a '_', we need to insert either an italics symbol
        // or a bold symbol depending on the previous character
        if (character == '*' or character == '_') {
            // if the character is the first one in the input, we know we need
            // to make an italics symbol
            if (current_pos == 0) {
                try symbols.append(.{
                    .kind = Kind.italics,
                    .level = header_depth,
                });
                last_pos = current_pos + 1;
                continue;
            }
            // if the '*' or the '_' is repeated, then we need to remove the
            // italics symbol we've made just before and add a bold symbol
            if (character == markdown[current_pos - 1]) {
                _ = symbols.pop();
                try symbols.append(.{
                    .kind = Kind.bold,
                    .level = header_depth,
                });
                // if it's not repeated, then we save all the text up until now
                // (if there is any) and create an italics symbol
            } else {
                if (last_pos != current_pos) {
                    try symbols.append(.{
                        .kind = Kind.text,
                        .level = header_depth,
                        .resource = markdown[last_pos..current_pos],
                    });
                }
                try symbols.append(.{
                    .kind = Kind.italics,
                    .level = header_depth,
                });
            }
            last_pos = current_pos + 1;
            continue;
        }

        // NEWLINE
        // if we hit a newline, then we need to make the right symbols
        if (character == '\n') {
            // make a text symbol if there is one to make (the minus 1 term comes
            // from the fact that the '\n' character is itself a position in
            // the input)
            if (last_pos < (current_pos - 1)) {
                try symbols.append(.{
                    .kind = Kind.text,
                    .level = header_depth,
                    .resource = markdown[last_pos..current_pos],
                });
                last_pos = current_pos;
            }
            // add a header symbol and reset the header depth if this line has
            // a header symbol
            if (header_depth > 0) {
                try symbols.append(.{
                    .kind = Kind.header,
                    .level = header_depth,
                });
                header_depth = 0;
            }
            // and we need to append a newline symbol
            try symbols.append(.{
                .kind = Kind.newline,
                .level = header_depth,
            });
            // move on to the next character
            continue;
        }
    }
    // EOF
    if (last_pos != (markdown.len - 1)) {
        try symbols.append(.{
            .kind = Kind.text,
            .level = header_depth,
            .resource = markdown[last_pos..],
        });
    }
}

test "empty input" {
    var list_symbols = std.ArrayList(Symbol).init(std.testing.allocator);
    defer list_symbols.deinit();
    try lexMarkdown("", &list_symbols);
    try std.testing.expectEqual(0, list_symbols.items.len);
}

test "simple text" {
    const test_text: []const u8 = "Lorem ipsum dolor, consectetur";
    const allocator = std.testing.allocator;

    var list_symbols = std.ArrayList(Symbol).init(allocator);
    defer list_symbols.deinit();

    try lexMarkdown(test_text, &list_symbols);

    var strings = std.ArrayList(u8).init(allocator);
    defer strings.deinit();

    for (list_symbols.items) |symbol| try strings.appendSlice(symbol.resource);

    const concatenated = try strings.toOwnedSlice();
    defer allocator.free(concatenated);

    try std.testing.expectEqualStrings(test_text, concatenated);
}

test "confirm swallows '*' around italics" {
    const test_text: []const u8 = "some *italics*";
    const allocator = std.testing.allocator;

    var list_symbols = std.ArrayList(Symbol).init(allocator);
    defer list_symbols.deinit();

    try lexMarkdown(test_text, &list_symbols);

    var strings = std.ArrayList(u8).init(allocator);
    defer strings.deinit();

    for (list_symbols.items) |symbol| try strings.appendSlice(symbol.resource);

    const concatenated = try strings.toOwnedSlice();
    defer allocator.free(concatenated);

    try std.testing.expectEqualStrings("some italics", concatenated);
}

test "confirm swallows '**' around bold" {
    const test_text: []const u8 = "some **bold**";
    const allocator = std.testing.allocator;

    var list_symbols = std.ArrayList(Symbol).init(allocator);
    defer list_symbols.deinit();

    try lexMarkdown(test_text, &list_symbols);

    var strings = std.ArrayList(u8).init(allocator);
    defer strings.deinit();

    for (list_symbols.items) |symbol| try strings.appendSlice(symbol.resource);

    const concatenated = try strings.toOwnedSlice();
    defer allocator.free(concatenated);

    try std.testing.expectEqualStrings("some bold", concatenated);
}

test "confirm swallows '#' at first character of a line" {
    const test_text: []const u8 = "# Header 1";
    const allocator = std.testing.allocator;

    var list_symbols = std.ArrayList(Symbol).init(allocator);
    defer list_symbols.deinit();

    try lexMarkdown(test_text, &list_symbols);

    var strings = std.ArrayList(u8).init(allocator);
    defer strings.deinit();

    for (list_symbols.items) |symbol| try strings.appendSlice(symbol.resource);

    const concatenated = try strings.toOwnedSlice();
    defer allocator.free(concatenated);

    try std.testing.expectEqualStrings(" Header 1", concatenated);
}

test "confirm swallows multiple '#' characters at beginning of line" {
    const test_text: []const u8 = "### Header 3";
    const allocator = std.testing.allocator;

    var list_symbols = std.ArrayList(Symbol).init(allocator);
    defer list_symbols.deinit();

    try lexMarkdown(test_text, &list_symbols);

    var strings = std.ArrayList(u8).init(allocator);
    defer strings.deinit();

    for (list_symbols.items) |symbol| try strings.appendSlice(symbol.resource);

    const concatenated = try strings.toOwnedSlice();
    defer allocator.free(concatenated);

    try std.testing.expectEqualStrings(" Header 3", concatenated);
}

test "handles newlines" {
    const test_text: []const u8 = "line 1\nline 2";
    const allocator = std.testing.allocator;

    var list_symbols = std.ArrayList(Symbol).init(allocator);
    defer list_symbols.deinit();

    try lexMarkdown(test_text, &list_symbols);

    var strings = std.ArrayList(u8).init(allocator);
    defer strings.deinit();

    for (list_symbols.items) |symbol| try strings.appendSlice(symbol.resource);

    const concatenated = try strings.toOwnedSlice();
    defer allocator.free(concatenated);

    try std.testing.expectEqualStrings("line 1\nline 2", concatenated);
}

test "* is the first character" {
    const test_text: []const u8 = "*italics*";
    const allocator = std.testing.allocator;

    var list_symbols = std.ArrayList(Symbol).init(allocator);
    defer list_symbols.deinit();

    try lexMarkdown(test_text, &list_symbols);

    var strings = std.ArrayList(u8).init(allocator);
    defer strings.deinit();

    for (list_symbols.items) |symbol| try strings.appendSlice(symbol.resource);

    const concatenated = try strings.toOwnedSlice();
    defer allocator.free(concatenated);

    try std.testing.expectEqualStrings("italics", concatenated);
}
