const std = @import("std");

pub const Account = struct {
    balance: f64,

    pub fn init(balance: f64) Account {
        return .{ .balance = balance };
    }
};

/// AccountManager handles the state and loading logic.
/// More fields will be added in later versions.
pub const AccountManager = struct {
    account: Account,

    pub fn init(acc: Account) AccountManager {
        return .{
            .account = acc,
        };
    }

    pub fn toABI(self: *const AccountManager) @import("../abi/account.zig").AccountABI {
        return .{
            .balance = self.account.balance,
        };
    }
};
