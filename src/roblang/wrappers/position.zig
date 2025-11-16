pub const PositionABI = extern struct {
    instrument: [*:0]const u8,
    qty: f64,
    avg_price: f64,
    unrealized_pnl: f64,
};
