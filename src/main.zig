const std = @import("std");
const lexMarkdown = @import("lexer.zig").lexMarkdown;

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

// a markdown symbol
pub const Symbol = struct {
    kind: Kind,
    level: u8 = 0,
    resource: []const u8 = "",

    pub fn init_text(raw_text: []const u8) Symbol {
        return Symbol{
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
    const max_bytes: u16 = 32768; //32 kB ish
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

    // we'll need to allocate more memory to build the list of markdown symbols
    var symbols = std.ArrayList(Symbol).init(gpa.allocator());
    defer symbols.deinit();

    // parse markdown into symbols
    try lexMarkdown(markdown, &symbols);

    try stdout.print("\nParsed output:\n", .{});
    for (symbols.items) |symbol| {
        if (symbol.kind == Kind.newline) {
            try stdout.print("\n", .{});
            continue;
        }
        try stdout.print("{s} ", .{@tagName(symbol.kind)});
    }

    try bw.flush(); // don't forget to flush!
}
