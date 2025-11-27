const std = @import("std");
const abi = @import("../../zdk/abi.zig");

pub const LoadError = error{
    NotADynamicLibraryName,
    MissingEntrySymbol,
    ABIVersionMismatch,
};

pub const LoadedAuto = struct {
    allocator: std.mem.Allocator,
    lib_path: []const u8,
    lib: std.DynLib,
    api: *const abi.ABI,

    pub fn deinit(self: *LoadedAuto) void {
        self.api.adf();
        self.lib.close();
        self.allocator.free(self.lib_path);
    }
};

pub fn loadFromFile(gpa: std.mem.Allocator, path: []const u8) (LoadError || std.DynLib.Error || std.mem.Allocator.Error)!LoadedAuto {
    const base = std.fs.path.basename(path);
    if (!std.mem.endsWith(u8, base, ".dylib")) return LoadError.NotADynamicLibraryName;

    var lib = try std.DynLib.open(path);
    errdefer lib.close();

    const get_api = lib.lookup(abi.GetABIFn, abi.ENTRY_SYMBOL) orelse
        return LoadError.MissingEntrySymbol;

    const api = get_api();

    if (api.version != abi.VERSION) {
        std.debug.print(
            "\n  ERROR: ABI version mismatch!\n" ++
                "    Engine expects: {d}\n" ++
                "    Auto provides:  {d}\n" ++
                "    Please update your auto's ZDK to match the engine version.\n\n",
            .{ abi.VERSION, api.version },
        );
        return LoadError.ABIVersionMismatch;
    }

    const lib_copy = try std.mem.Allocator.dupe(gpa, u8, path);
    errdefer gpa.free(lib_copy);

    return .{ .allocator = gpa, .lib_path = lib_copy, .lib = lib, .api = api };
}
