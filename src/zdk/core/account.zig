const std = @import("std");

pub const Account = struct {
    ACCOUNT_BALANCE: f64,

    pub fn init(balance: f64) Account {
        return .{ .ACCOUNT_BALANCE = balance };
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
            .ACCOUNT_BALANCE = self.account.ACCOUNT_BALANCE,
        };
    }
};
