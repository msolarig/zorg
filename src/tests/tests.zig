const std = @import("std");

// Core unit tests
pub const abi_tests = @import("abi_test.zig");
pub const order_tests = @import("order_test.zig");
pub const fill_tests = @import("fill_test.zig");
pub const position_tests = @import("position_test.zig");
pub const account_tests = @import("account_test.zig");
pub const data_tests = @import("data_test.zig");
pub const engine_tests = @import("engine_test.zig");

// New comprehensive tests
pub const integration_tests = @import("integration_test.zig");
pub const edge_case_tests = @import("edge_case_test.zig");
pub const error_path_tests = @import("error_path_test.zig");
pub const controller_tests = @import("controller_test.zig");
pub const output_tests = @import("output_test.zig");
pub const assembly_tests = @import("assembly_test.zig");

test {
    std.testing.refAllDecls(@This());
}
