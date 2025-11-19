const std = @import("std");

pub const cleanJSON = struct {
    pub fn stripComments(gpa: std.mem.Allocator, input: []const u8) ![]u8 {
        var out: std.ArrayList(u8) = .{};
        errdefer out.deinit(gpa);

        var i: usize = 0;
        var in_string = false;
        var escaped = false;

        while (i < input.len) {
            const c = input[i];

            if (in_string) {
                try out.append(gpa, c);
                if (escaped) {
                    escaped = false;
                } else if (c == '\\') {
                    escaped = true;
                } else if (c == '"') {
                    in_string = false;
                }
                i += 1;
                continue;
            }

            if (c == '"') {
                in_string = true;
                try out.append(gpa, c);
                i += 1;
                continue;
            }

            if (c == '/' and i + 1 < input.len and input[i + 1] == '/') {
                i += 2;
                while (i < input.len and input[i] != '\n') : (i += 1) {}
                continue;
            }

            if (c == '/' and i + 1 < input.len and input[i + 1] == '*') {
                i += 2;
                while (i + 1 < input.len) : (i += 1) {
                    if (input[i] == '*' and input[i + 1] == '/') {
                        i += 2;
                        break;
                    }
                }
                continue;
            }

            try out.append(gpa, c);
            i += 1;
        }

        return out.toOwnedSlice(gpa);
    }

    pub fn parse(allocator: std.mem.Allocator, input: []const u8) !std.json.Value {
        const cleaned = try stripComments(allocator, input);
        defer allocator.free(cleaned);

        const tree = std.json.parseFromSlice(std.json.Value, allocator, cleaned, .{}) catch |err| {
            std.debug.print("JSON parse failed. Cleaned JSON:\n{s}\n", .{cleaned});
            return err;
        };

        return tree;
    }
};
