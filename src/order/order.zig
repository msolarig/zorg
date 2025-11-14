const OrderDirection = enum { Buy, Sell };
const OrderType = enum { Market, Stop, Limit };
const OrderTimeInForce = enum { Day, GoodTillCancel };
const OrderTimeCondition = enum { ImmediateOrCancel, FillOrKill };
const OrderStatus = enum { Inactive, Submitted, Working, Filled, Canceled, Rejected, Expired };

const Order = struct {
  instrument: []const u8,
  type: OrderType,
  direction: OrderDirection,
  price: f64,
  volume: u64,
  time_in_force: OrderTimeInForce,
  time_condition: OrderTimeCondition,
  status: OrderStatus,

  pub fn init(
    instrument: []const u8, 
    order_type: OrderType, 
    direction: OrderDirection, 
    price: f64,
    volume: u64, 
    time_in_force: OrderTimeInForce, 
    time_condition: OrderTimeCondition) Order {
    return Order{  
      .instrument = instrument,
      .type = order_type,
      .direction = direction,
      .price = price,
      .volume = volume,
      .time_in_force = time_in_force,
      .time_condition = time_condition,
      .status = .Inactive,
    };
  }
};
