const std = @import("std");
const builtin = @import("builtin");
const abi = @import("../../zdk/abi/abi.zig");
const InstructionPacket = @import("../../zdk/abi/command.zig").InstructionPacket;

pub const LoadedAuto = struct {
    allocator: std.mem.Allocator,
    lib_path: []const u8,
    lib: std.DynLib,
    api: *const abi.AutoABI,

    pub const AutoLogicFn = *const fn (
        inputs: *const abi.Inputs,
        packet: *InstructionPacket,
    ) callconv(.C) void;

    pub fn deinit(self: *LoadedAuto) void {
        self.api.deinit();
        self.lib.close();
        self.allocator.free(self.lib_path);
    }
};

pub fn load_from_file(gpa: std.mem.Allocator, auto_file_path: []const u8) !LoadedAuto {
    const base = std.fs.path.basename(auto_file_path);
    if (!std.mem.endsWith(u8, base, ".dylib")) return error.NotADynamicLibraryName;

    // Open the library
    var lib = try std.DynLib.open(auto_file_path);
    errdefer lib.close();

    // Lookup the single entrypoint
    const get_api = lib.lookup(abi.GetAutoABIFn, abi.ENTRY_SYMBOL) orelse
        return error.MissingEntrySymbol;

    // Zig 0.15.1: function returns non-optional pointer
    const api = get_api();

    // Own a copy of the file path
    const lib_copy = try std.mem.Allocator.dupe(gpa, u8, auto_file_path);
    errdefer gpa.free(lib_copy);

    return .{ .allocator = gpa, .lib_path = lib_copy, .lib = lib, .api = api };
}
