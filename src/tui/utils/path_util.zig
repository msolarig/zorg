const dep = @import("../dep.zig");

const std = dep.Stdlib.std;

pub fn isAutoDir(path: []const u8) bool {
    return std.mem.indexOf(u8, path, "/usr/auto/") != null or
        std.mem.indexOf(u8, path, "usr/auto/") != null;
}

pub fn extractRelPathFromUsr(path: []const u8) []const u8 {
    if (std.mem.indexOf(u8, path, "usr/")) |idx| {
        const rel = path[idx..];
        if (rel.len > 0 and rel[0] == '/') {
            return rel[1..];
        }
        return rel;
    }
    return std.fs.path.basename(path);
}

pub fn getFileExtension(name: []const u8) []const u8 {
    if (std.mem.lastIndexOfScalar(u8, name, '.')) |dot_idx| {
        if (dot_idx + 1 < name.len) {
            return name[dot_idx + 1 ..];
        }
    }
    return "";
}

