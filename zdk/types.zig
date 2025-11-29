/// Basic types and enums for ZDK

pub const OrderDirection = enum(c_int) { Buy = 1, Sell = -1 };
pub const OrderType = enum(c_int) { Market = 0, Limit = 1, Stop = 2 };

// Logging types
pub const LogLevel = enum(c_int) {
    Debug = 0,
    Info = 1,
    Warn = 2,
    Error = 3,
};

pub const LogEntry = extern struct {
    level: LogLevel,
    message: [256]u8,
    length: u32,
};

