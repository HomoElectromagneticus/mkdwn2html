const std = @import("std");
const Node = @import("main.zig").Node;
const Kind = @import("main.zig").Kind;

pub fn parseMarkdown(markdown: []const u8, nodes: *std.ArrayListAligned(Node, null)) !void {
    // handle empty input
    if (markdown.len == 0) return; 

    var header_depth: u8 = 0;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var text_buffer = std.ArrayList(u8).init(gpa.allocator());
    defer text_buffer.deinit();

    // go through the source character-by-character
    for (markdown, 0..) |character, index| {
        // HEADERS
        // if we hit a '#' and one of the following is true:
        if (character == '#') {
            // we're at the first character of a file
            if (index == 0) {
                header_depth = 1;
                try nodes.append(.{
                    .kind = Kind.header,
                    .level = header_depth,
                    .resource = "",
                });
                continue;
            }
            // the previous character was a newline
            if (markdown[index - 1] == '\n') {
                header_depth = 1;
                try nodes.append(.{
                    .kind = Kind.header,
                    .level = header_depth,
                    .resource = "",
                });
                continue;
            }
            // previous character was a '#' and we are already in "header mode"
            if (markdown[index - 1] == '#' and header_depth > 0) {
                header_depth += 1;
                nodes.items[nodes.items.len - 1].level = header_depth;
                continue;
            } 
        }

        // BOLD AND ITALICS
        // if we hit a '*' or a '_', we need to insert either an italics node
        // or a bold node depending on the previous character
        if (character == '*' or character == '_') {
            // if the '*' or the '_' is repeated, then we need to remove the 
            // italics node we've made just before and add a bold node
            // TODO: will panic if '*' or '_' is the first char in a file!
            if (character == markdown[index - 1]) {
                _ = nodes.pop();
                try nodes.append(.{
                    .kind = Kind.bold,
                    .level = header_depth,
                    .resource = "",
                });
            // if it's not repeated, then we save all the text up until now 
            // (if there is any) and create an italics node
            } else {
                if (text_buffer.items.len > 0) {
                    try nodes.append(Node.init_text(try text_buffer.toOwnedSlice()));
                }
                try nodes.append(.{
                    .kind = Kind.italics,
                    .level = header_depth,
                    .resource = "",
                });
            }
            continue;
        }

        // NEWLINE
        // if we hit a newline or the end of the file, then we need to make 
        // the right nodes (files must end in a newline, damn it)
        if (character == '\n' or (index + 1 == markdown.len)) {
            if (text_buffer.items.len > 0) {
               try nodes.append(Node.init_text(try text_buffer.toOwnedSlice()));
            }
            // add a header node if this line has a header node
            if (header_depth > 0) {
                try nodes.append(.{
                    .kind = Kind.header,
                    .level = header_depth,
                    .resource = "",
                });
            } 
            // and we need to append a newline node
            try nodes.append(.{
                .kind = Kind.newline,
                .level = header_depth,
                .resource = "",
            });
            // reset the parameters for the next node (we don't need to do this
            // for the text, since `toOwnedSlice()` takes care of that)
            header_depth = 0;
            // move on to the next character
            continue;
        }

        // REGULAR TEXT
        try text_buffer.append(character);
    }
}

test "empty input" {
    var test_html = std.ArrayList(Node).init(std.testing.allocator);
    defer test_html.deinit();
    try parseMarkdown("", &test_html);
    try std.testing.expectEqual(0, test_html.items.len);
}

test "two nodes from simple text (text + newline)"{
    var list_nodes = std.ArrayList(Node).init(std.testing.allocator);
    defer list_nodes.deinit();
    try parseMarkdown("Lorem ipsum dolor, consectetur", &list_nodes);
    try std.testing.expectEqual(2, list_nodes.items.len);
}

