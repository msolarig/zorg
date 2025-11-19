// AUTO INPUT ABI -------------------------------------------------------------

pub const TrailABI = extern struct {
    ts: [*]const u64,
    op: [*]const f64,
    hi: [*]const f64,
    lo: [*]const f64,
    cl: [*]const f64,
    vo: [*]const u64,
};

pub const AccountABI = extern struct {};
pub const PositionABI = extern struct {};

pub const Inputs = extern struct {
    trail: *const TrailABI,
    account: *const AccountABI,
    position: *const PositionABI,
};

// AUTO OUTPUT ABI ------------------------------------------------------------

pub const OrderDirection = enum(c_int) { Buy = 1, Sell = -1 };
pub const OrderType = enum(c_int) { Market = 0, Limit = 1, Stop = 2 };

pub const PlaceOrder = extern struct {
    direction: OrderDirection,
    order_type: OrderType,
    price: f64,
    volume: f64,
};

pub const CancelOrder = extern struct {
    order_id: u64,
};

pub const CommandType = enum(c_int) {
    PlaceOrder = 0,
    CancelOrder = 1,
};

pub const Command = extern struct {
    type: CommandType,
    payload: extern union {
        place: PlaceOrder,
        cancel: CancelOrder,
    },
};

pub const InstructionPacket = extern struct {
    count: u64,
    commands: [*]Command,

    pub fn init(buffer: [*]Command) InstructionPacket {
        return .{
            .count = 0,
            .commands = buffer,
        };
    }

    pub fn add(self: *InstructionPacket, cmd: Command) void {
        self.commands[self.count] = cmd;
        self.count += 1;
    }
};

// AUTO HANDLE ---------------------------------------------------------------

pub const AutoABI = extern struct {
    name: [*:0]const u8,
    desc: [*:0]const u8,
    logic: *const fn (u64, Inputs) callconv(.c) InstructionPacket,
    deinit: *const fn () callconv(.c) void,
};

pub const GetAutoABIFn = *const fn () callconv(.c) *const AutoABI;
pub const ENTRY_SYMBOL: [*:0]const u8 = "getAutoABI";
