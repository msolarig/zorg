pub const VERSION: u32 = 1_000_000;

pub const OrderDirection = enum(c_int) { Buy = 1, Sell = -1 };
pub const OrderType = enum(c_int) { Market = 0, Limit = 1, Stop = 2 };

pub const TrailABI = extern struct {
    ts: [*]const u64,
    op: [*]const f64,
    hi: [*]const f64,
    lo: [*]const f64,
    cl: [*]const f64,
    vo: [*]const u64,
};

pub const AccountABI = extern struct {
    balance: f64,
};

pub const FillEntryABI = extern struct {
    iter: u64,
    timestamp: u64,
    side: OrderDirection,
    price: f64,
    volume: f64,
};

pub const FillABI = extern struct {
    ptr: [*]const FillEntryABI,
    count: u64,
};

pub const OrderRequest = extern struct {
    iter: u64,
    timestamp: u64,
    direction: OrderDirection,
    order_type: OrderType,
    price: f64,
    volume: f64,
};

pub const CancelRequest = extern struct {
    order_id: u64,
};

pub const CommandType = enum(c_int) {
    PlaceOrder = 0,
    CancelOrder = 1,
};

pub const CommandPayload = extern union {
    order_request: OrderRequest,
    cancel_request: CancelRequest,
};

pub const Command = extern struct {
    command_type: CommandType,
    payload: CommandPayload,
};

// Input namespace
pub const Input = struct {
    pub const Packet = extern struct {
        iter: u64,
        trail: *const TrailABI,
        account: *const AccountABI,
        exposure: *f64,
    };
};

// Output namespace
pub const Output = struct {
    pub const Packet = extern struct {
        count: u64,
        commands: [*]Command,

        pub fn submitOrder(self: *Packet, request: OrderRequest) void {
            self.commands[self.count] = Command{
                .command_type = .PlaceOrder,
                .payload = .{ .order_request = request },
            };
            self.count += 1;
        }

        pub fn cancelOrder(self: *Packet, order_id: u64) void {
            self.commands[self.count] = Command{
                .command_type = .CancelOrder,
                .payload = .{ .cancel_request = .{ .order_id = order_id } },
            };
            self.count += 1;
        }
    };
};

// Order namespace for order submission wrappers
pub const Order = struct {
    pub fn buyMarket(input: *const Input.Packet, output: *Output.Packet, volume: f64) void {
        output.submitOrder(.{
            .iter = input.iter,
            .timestamp = input.trail.ts[0],
            .direction = .Buy,
            .order_type = .Market,
            .price = 0,
            .volume = volume,
        });
    }

    pub fn sellMarket(input: *const Input.Packet, output: *Output.Packet, volume: f64) void {
        output.submitOrder(.{
            .iter = input.iter,
            .timestamp = input.trail.ts[0],
            .direction = .Sell,
            .order_type = .Market,
            .price = 0,
            .volume = volume,
        });
    }

    pub fn buyStop(input: *const Input.Packet, output: *Output.Packet, price: f64, volume: f64) void {
        output.submitOrder(.{
            .iter = input.iter,
            .timestamp = input.trail.ts[0],
            .direction = .Buy,
            .order_type = .Stop,
            .price = price,
            .volume = volume,
        });
    }

    pub fn sellStop(input: *const Input.Packet, output: *Output.Packet, price: f64, volume: f64) void {
        output.submitOrder(.{
            .iter = input.iter,
            .timestamp = input.trail.ts[0],
            .direction = .Sell,
            .order_type = .Stop,
            .price = price,
            .volume = volume,
        });
    }

    pub fn buyLimit(input: *const Input.Packet, output: *Output.Packet, price: f64, volume: f64) void {
        output.submitOrder(.{
            .iter = input.iter,
            .timestamp = input.trail.ts[0],
            .direction = .Buy,
            .order_type = .Limit,
            .price = price,
            .volume = volume,
        });
    }

    pub fn sellLimit(input: *const Input.Packet, output: *Output.Packet, price: f64, volume: f64) void {
        output.submitOrder(.{
            .iter = input.iter,
            .timestamp = input.trail.ts[0],
            .direction = .Sell,
            .order_type = .Limit,
            .price = price,
            .volume = volume,
        });
    }
};

pub const AutoLogicFn = *const fn (
    input: *const Input.Packet,
    output: *Output.Packet,
) callconv(.c) void;

pub const AutoDeinitFn = *const fn () callconv(.c) void;

pub const ABI = extern struct {
    version: u32,
    name: [*:0]const u8,
    desc: [*:0]const u8,
    logic: AutoLogicFn,
    deinit: AutoDeinitFn,
};

pub const GetABIFn = *const fn () callconv(.c) *const ABI;
pub const ENTRY_SYMBOL = "getABI";

