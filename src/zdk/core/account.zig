const abi = @import("../abi.zig");

pub const Account = struct {
    balance: f64,

    pub fn init(balance: f64) Account {
        return .{ .balance = balance };
    }
};

pub const AccountManager = struct {
    account: Account,

    pub fn init(acc: Account) AccountManager {
        return .{ .account = acc };
    }

    pub fn toABI(self: *const AccountManager) abi.AccountABI {
        return .{ .balance = self.account.balance };
    }
};
