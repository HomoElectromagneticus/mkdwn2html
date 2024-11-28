const std = @import("std");

// the types of possible markdown objects i care about tokenizing
const Type = enum {
    newline,
    text,
    header,
    bold,
    italics,
    linebreak,
    link,
    image,
};

// a markdown node
const Node = struct {
    kind: Type,
    level: u8 = 0,
    resource: []const u8 = "",

    fn init_text(raw_text: []const u8) Node {
        return Node{
            .kind = Type.text,
            .level = 0,
            .resource = raw_text,
        };
    }
};

fn appendTextNode(raw_text: []const u8, nodes: *std.ArrayListAligned(Node, null)) !void {
    try nodes.append(.{
        .kind = Type.text,
        .level = 0,
        .resource = raw_text,
    });
}

fn parseMarkdown(markdown: []const u8, nodes: *std.ArrayListAligned(Node, null)) !void {
    // handle empty input
    if (markdown.len == 0) return; 

    var kind: Type = Type.text;
    var header_depth: u8 = 0;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var text_buffer = std.ArrayList(u8).init(gpa.allocator());
    defer text_buffer.deinit();

    // go through the source character-by-character
    for (markdown, 0..) |character, index| {
        // BOLD AND ITALICS
        // if we hit a '*' or a '_', we need to insert either an italics node
        // or a bold node depending on the previous character
        if (character == '*' or character == '_') {
            // if the '*' or the '_' is repeated, then we need to remove the 
            // italics node we've made just before and add a bold node
            if (character == markdown[index - 1]) {
                _ = nodes.pop();
                try nodes.append(.{
                    .kind = Type.bold,
                    .level = 0,
                    .resource = "",
                });
            // if it's not repeated, then we save all the text up until now 
            // (if there is any) and create an italics node
            } else {
                if (text_buffer.items.len > 0) {
                    try nodes.append(Node.init_text(try text_buffer.toOwnedSlice()));
                }
                try nodes.append(.{
                    .kind = Type.italics,
                    .level = 0,
                    .resource = "",
                });
            }
            continue;
        }

        // NEWLINE
        // if we hit a newline, then we need to make the right node
        if (character == '\n') {
            if (text_buffer.items.len > 0) {
               try nodes.append(Node.init_text(try text_buffer.toOwnedSlice()));
            }
            // and we need to append a newline node
            try nodes.append(.{
                .kind = Type.newline,
                .level = 0,
                .resource = "",
            });
            // reset the parameters for the next node (we don't need to do this
            // for the text, since `toOwnedSlice()` takes care of that)
            kind = Type.text;
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

pub fn main() !void {
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // we'll hardcode the file path and max size for now (path is relative to
    // where the program is run from, and not this file)
    const path = "src/test.md";
    const max_bytes : u16 = 32768;      //32 kB ish
    // open the markdown file
    const input_file = try std.fs.cwd().openFile(path, .{});
    defer input_file.close();

    // we will need to allocate memory in order to read and handle the markdown
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    // store the markdown file contents in this variable
    const markdown = try input_file.readToEndAlloc(gpa.allocator(), max_bytes);
    defer gpa.allocator().free(markdown);

    // print a copy of the markdown for debugging
    try stdout.print("Markdown input:\n{s}", .{markdown});

    // we'll need to allocate more memory to build the list of markdown nodes
    var nodes = std.ArrayList(Node).init(gpa.allocator());
    defer nodes.deinit();

    // parse markdown into nodes
    try parseMarkdown(markdown, &nodes);

    for (nodes.items) |node| {
        if (node.kind == Type.newline) try stdout.print("\n", .{});
        try stdout.print("{s} ", .{@tagName(node.kind)});
    }
    
    try bw.flush(); // don't forget to flush!
}

