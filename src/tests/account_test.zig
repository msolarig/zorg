const std = @import("std");
const core = @import("../zdk/core.zig");
const abi = @import("../zdk/abi.zig");
const Account = core.Account;
const AccountManager = core.AccountManager;

test "Account.init creates account with correct balance" {
    const acc = Account.init(10000.0);

    try std.testing.expectEqual(acc.balance, 10000.0);
}

test "Account.init handles zero balance" {
    const acc = Account.init(0);

    try std.testing.expectEqual(acc.balance, 0);
}

test "Account.init handles negative balance" {
    const acc = Account.init(-500.0);

    try std.testing.expectEqual(acc.balance, -500.0);
}

test "AccountManager.init wraps Account correctly" {
    const acc = Account.init(5000.0);
    const am = AccountManager.init(acc);

    try std.testing.expectEqual(am.account.balance, 5000.0);
}

test "AccountManager.toABI returns correct ABI struct" {
    const acc = Account.init(7500.0);
    const am = AccountManager.init(acc);
    const abi_result = am.toABI();

    try std.testing.expectEqual(abi_result.balance, 7500.0);
    try std.testing.expectEqual(@TypeOf(abi_result), abi.AccountABI);
}

test "AccountABI struct layout matches Account balance" {
    const acc = Account.init(1234.56);
    const am = AccountManager.init(acc);
    const abi_result = am.toABI();

    try std.testing.expectEqual(abi_result.balance, acc.balance);
}
