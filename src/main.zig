const std = @import("std");
const parseMarkdown = @import("parser.zig").parseMarkdown;

// the types of possible markdown objects i care about tokenizing
pub const Kind = enum {
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
pub const Node = struct {
    kind: Kind,
    level: u8 = 0,
    resource: []const u8 = "",

    pub fn init_text(raw_text: []const u8) Node {
        return Node{
            .kind = Kind.text,
            .level = 0,
            .resource = raw_text,
        };
    }
};

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

    // print a copy of the test markdown for debugging
    try stdout.print("Markdown input:\n{s}", .{markdown});

    // we'll need to allocate more memory to build the list of markdown nodes
    var nodes = std.ArrayList(Node).init(gpa.allocator());
    defer nodes.deinit();

    // parse markdown into nodes
    try parseMarkdown(markdown, &nodes);
    
    try stdout.print("\nParsed output:\n", .{});
    for (nodes.items) |node| {
        if (node.kind == Kind.newline) {
            try stdout.print("\n", .{});
            continue;
        }
        try stdout.print("{s} ", .{@tagName(node.kind)});
    }
    
    try bw.flush(); // don't forget to flush!
}

