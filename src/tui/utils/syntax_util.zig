const dep = @import("../dep.zig");

const std = dep.Stdlib.std;

const vaxis = dep.External.vaxis;

pub const TokenKind = enum {
    keyword,
    string,
    comment,
    number,
    type,
    function,
    operator,
    normal,
};

pub const Token = struct {
    kind: TokenKind,
    text: []const u8,
    style: vaxis.Style,
};

const Theme = struct {
    const fg_keyword = vaxis.Color{ .index = 24 }; // very dark blue
    const fg_string = vaxis.Color{ .index = 22 }; // very dark green
    const fg_comment = vaxis.Color{ .index = 240 }; // very dark gray
    const fg_number = vaxis.Color{ .index = 58 }; // very dark orange
    const fg_type = vaxis.Color{ .index = 24 }; // very dark blue
    const fg_function = vaxis.Color{ .index = 255 }; // white
    const fg_operator = vaxis.Color{ .index = 240 }; // very dark gray
    const fg_normal = vaxis.Color{ .index = 255 }; // white
};

// Zig keywords
const zig_keywords = [_][]const u8{
    "const", "var", "fn", "pub", "comptime", "inline", "noinline",
    "extern", "export", "usingnamespace", "test", "defer", "errdefer",
    "if", "else", "switch", "while", "for", "break", "continue",
    "return", "try", "catch", "orelse", "async", "await", "suspend",
    "resume", "nosuspend", "noasync", "anyframe", "anytype", "type",
    "struct", "enum", "union", "error", "packed", "align", "linksection",
    "callconv", "addrspace", "asm", "volatile", "allowzero", "undefined",
    "null", "true", "false", "and", "or", "orelse", "catch",
};

// Zig types
const zig_types = [_][]const u8{
    "u8", "u16", "u32", "u64", "u128", "usize",
    "i8", "i16", "i32", "i64", "i128", "isize",
    "f16", "f32", "f64", "f128", "bool", "void", "noreturn",
    "anyopaque", "comptime_int", "comptime_float",
};

// JSON keywords
const json_keywords = [_][]const u8{
    "true", "false", "null",
};

pub fn highlightZig(alloc: std.mem.Allocator, line: []const u8) ![]Token {
    var tokens = std.ArrayListUnmanaged(Token){};
    errdefer tokens.deinit(alloc);

    var i: usize = 0;
    var in_string = false;
    var in_comment = false;
    var string_start: usize = 0;
    var comment_start: usize = 0;

    while (i < line.len) {
        if (in_comment) {
            // Single-line comment - consume rest of line
            const comment_text = line[comment_start..];
            try tokens.append(alloc, Token{
                .kind = .comment,
                .text = comment_text,
                .style = .{ .fg = Theme.fg_comment, .dim = true },
            });
            break;
        }

        if (in_string) {
            // Check for string end
            if (line[i] == '"' and (i == 0 or line[i - 1] != '\\')) {
                const string_text = line[string_start..i + 1];
                try tokens.append(alloc, Token{
                    .kind = .string,
                    .text = string_text,
                    .style = .{ .fg = Theme.fg_string },
                });
                in_string = false;
                i += 1;
                continue;
            }
            i += 1;
            continue;
        }

        // Check for string start
        if (line[i] == '"') {
            string_start = i;
            in_string = true;
            i += 1;
            continue;
        }

        // Check for comment start
        if (i + 1 < line.len and line[i] == '/' and line[i + 1] == '/') {
            comment_start = i;
            in_comment = true;
            i += 2;
            continue;
        }

        // Skip whitespace
        if (std.ascii.isWhitespace(line[i])) {
            i += 1;
            continue;
        }

        // Find word boundary
        var word_end = i;
        while (word_end < line.len and !std.ascii.isWhitespace(line[word_end]) and
            line[word_end] != '"' and line[word_end] != '/' and
            !isOperator(line[word_end]))
        {
            word_end += 1;
        }

        if (word_end > i) {
            const word = line[i..word_end];
            const kind = classifyZigWord(word);
            const style = getStyleForKind(kind);
            
            try tokens.append(alloc, Token{
                .kind = kind,
                .text = word,
                .style = style,
            });
            i = word_end;
        } else {
            // Single character operator
            if (isOperator(line[i])) {
                try tokens.append(alloc, Token{
                    .kind = .operator,
                    .text = line[i..i+1],
                    .style = .{ .fg = Theme.fg_operator },
                });
            } else {
                try tokens.append(alloc, Token{
                    .kind = .normal,
                    .text = line[i..i+1],
                    .style = .{ .fg = Theme.fg_normal },
                });
            }
            i += 1;
        }
    }

    // Handle unterminated string/comment
    if (in_string) {
        const string_text = line[string_start..];
        try tokens.append(alloc, Token{
            .kind = .string,
            .text = string_text,
            .style = .{ .fg = Theme.fg_string },
        });
    } else if (in_comment) {
        const comment_text = line[comment_start..];
        try tokens.append(alloc, Token{
            .kind = .comment,
            .text = comment_text,
            .style = .{ .fg = Theme.fg_comment, .dim = true },
        });
    }

    return tokens.toOwnedSlice(alloc);
}

pub fn highlightJson(alloc: std.mem.Allocator, line: []const u8) ![]Token {
    var tokens = std.ArrayListUnmanaged(Token){};
    errdefer tokens.deinit(alloc);

    var i: usize = 0;
    var in_string = false;
    var in_comment = false;
    var string_start: usize = 0;
    var comment_start: usize = 0;

    while (i < line.len) {
        if (in_comment) {
            // Single-line comment - consume rest of line (for JSONC)
            const comment_text = line[comment_start..];
            try tokens.append(alloc, Token{
                .kind = .comment,
                .text = comment_text,
                .style = .{ .fg = Theme.fg_comment, .dim = true },
            });
            break;
        }

        if (in_string) {
            if (line[i] == '"' and (i == 0 or line[i - 1] != '\\')) {
                const string_text = line[string_start..i + 1];
                try tokens.append(alloc, Token{
                    .kind = .string,
                    .text = string_text,
                    .style = .{ .fg = Theme.fg_string },
                });
                in_string = false;
                i += 1;
                continue;
            }
            i += 1;
            continue;
        }

        if (line[i] == '"') {
            string_start = i;
            in_string = true;
            i += 1;
            continue;
        }

        // Check for comment start (//) - for JSONC files
        if (i + 1 < line.len and line[i] == '/' and line[i + 1] == '/') {
            comment_start = i;
            in_comment = true;
            i += 2;
            continue;
        }

        if (std.ascii.isWhitespace(line[i])) {
            i += 1;
            continue;
        }

        // Find word boundary
        var word_end = i;
        while (word_end < line.len and !std.ascii.isWhitespace(line[word_end]) and
            line[word_end] != '"' and line[word_end] != ':' and
            line[word_end] != ',' and line[word_end] != '{' and
            line[word_end] != '}' and line[word_end] != '[' and
            line[word_end] != ']')
        {
            word_end += 1;
        }

        if (word_end > i) {
            const word = line[i..word_end];
            const kind = classifyJsonWord(word);
            const style = getStyleForKind(kind);
            
            try tokens.append(alloc, Token{
                .kind = kind,
                .text = word,
                .style = style,
            });
            i = word_end;
        } else {
            // Single character
            const ch = line[i..i+1];
            try tokens.append(alloc, Token{
                .kind = .normal,
                .text = ch,
                .style = .{ .fg = Theme.fg_normal },
            });
            i += 1;
        }
    }

    if (in_string) {
        const string_text = line[string_start..];
        try tokens.append(alloc, Token{
            .kind = .string,
            .text = string_text,
            .style = .{ .fg = Theme.fg_string },
        });
    } else if (in_comment) {
        const comment_text = line[comment_start..];
        try tokens.append(alloc, Token{
            .kind = .comment,
            .text = comment_text,
            .style = .{ .fg = Theme.fg_comment, .dim = true },
        });
    }

    return tokens.toOwnedSlice(alloc);
}

fn classifyZigWord(word: []const u8) TokenKind {
    // Check keywords
    for (zig_keywords) |kw| {
        if (std.mem.eql(u8, word, kw)) {
            return .keyword;
        }
    }

    // Check types
    for (zig_types) |t| {
        if (std.mem.eql(u8, word, t)) {
            return .type;
        }
    }

    // Check if number
    if (isNumber(word)) {
        return .number;
    }

    // Check if function (word followed by '(' - but we can't see that here)
    // For now, assume it's normal
    return .normal;
}

fn classifyJsonWord(word: []const u8) TokenKind {
    for (json_keywords) |kw| {
        if (std.mem.eql(u8, word, kw)) {
            return .keyword;
        }
    }

    if (isNumber(word)) {
        return .number;
    }

    return .normal;
}

fn isNumber(word: []const u8) bool {
    if (word.len == 0) return false;
    var i: usize = 0;
    if (word[0] == '-' or word[0] == '+') {
        i += 1;
        if (i >= word.len) return false;
    }
    var has_digit = false;
    while (i < word.len) {
        if (std.ascii.isDigit(word[i])) {
            has_digit = true;
            i += 1;
        } else if (word[i] == '.' or word[i] == 'e' or word[i] == 'E') {
            i += 1;
        } else {
            return false;
        }
    }
    return has_digit;
}

fn isOperator(ch: u8) bool {
    return switch (ch) {
        '+', '-', '*', '/', '%', '=', '!', '<', '>', '&', '|', '^', '~', '?', ':', '.', ',', ';', '(', ')', '[', ']', '{', '}' => true,
        else => false,
    };
}

fn getStyleForKind(kind: TokenKind) vaxis.Style {
    return switch (kind) {
        .keyword => .{ .fg = Theme.fg_keyword },
        .string => .{ .fg = Theme.fg_string },
        .comment => .{ .fg = Theme.fg_comment, .dim = true },
        .number => .{ .fg = Theme.fg_number },
        .type => .{ .fg = Theme.fg_type },
        .function => .{ .fg = Theme.fg_function },
        .operator => .{ .fg = Theme.fg_operator },
        .normal => .{ .fg = Theme.fg_normal },
    };
}

