const std = @import("std");
const abi = @import("../zdk/abi.zig");

test "TrailABI has correct extern layout" {
    try std.testing.expectEqual(@sizeOf(abi.TrailABI), 48);
    try std.testing.expectEqual(@alignOf(abi.TrailABI), 8);
}

test "AccountABI has correct extern layout" {
    try std.testing.expectEqual(@sizeOf(abi.AccountABI), 8);
    try std.testing.expectEqual(@alignOf(abi.AccountABI), 8);
}

test "FillEntryABI has correct extern layout" {
    try std.testing.expectEqual(@sizeOf(abi.FillEntryABI), 40);
    try std.testing.expectEqual(@alignOf(abi.FillEntryABI), 8);
}

test "OrderRequest has correct extern layout" {
    try std.testing.expectEqual(@sizeOf(abi.OrderRequest), 40);
    try std.testing.expectEqual(@alignOf(abi.OrderRequest), 8);
}

test "Command has correct extern layout" {
    try std.testing.expectEqual(@sizeOf(abi.Command), 48);
    try std.testing.expectEqual(@alignOf(abi.Command), 8);
}

test "Output.Packet has correct extern layout" {
    try std.testing.expectEqual(@sizeOf(abi.Output.Packet), 56);
    try std.testing.expectEqual(@alignOf(abi.Output.Packet), 8);
}

test "Input.Packet has correct extern layout" {
    try std.testing.expectEqual(@sizeOf(abi.Input.Packet), 40);
    try std.testing.expectEqual(@alignOf(abi.Input.Packet), 8);
}

test "ABI has correct extern layout" {
    try std.testing.expectEqual(@sizeOf(abi.ABI), 48);
    try std.testing.expectEqual(@alignOf(abi.ABI), 8);
}

test "ABI VERSION is defined" {
    try std.testing.expectEqual(abi.VERSION, 1_000_000);
}

test "CommandType enum values match C ABI" {
    try std.testing.expectEqual(@intFromEnum(abi.CommandType.PlaceOrder), 0);
    try std.testing.expectEqual(@intFromEnum(abi.CommandType.CancelOrder), 1);
}

test "ENTRY_SYMBOL is correct" {
    try std.testing.expectEqualStrings(abi.ENTRY_SYMBOL, "getABI");
}
