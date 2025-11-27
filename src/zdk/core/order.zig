const std = @import("std");
const abi = @import("../abi.zig");

pub const OrderDirection = abi.OrderDirection;
pub const OrderType = abi.OrderType;

pub const OrderError = error{
    InvalidPrice,
    InvalidVolume,
    InvalidOrderID,
    OrderNotFound,
    OrderAlreadyFilled,
};

pub const Order = struct {
    id: u64,
    iter: u64,
    timestamp: u64,
    type: OrderType,
    side: OrderDirection,
    price: f64,
    volume: f64,

    pub fn init(id: u64, iter: u64, timestamp: u64, order_type: OrderType, side: OrderDirection, price: f64, volume: f64) Order {
        // Note: Validation moved to OrderManager.placeOrder for better error handling
        return Order{
            .id = id,
            .iter = iter,
            .timestamp = timestamp,
            .type = order_type,
            .side = side,
            .price = price,
            .volume = volume,
        };
    }
    
    /// Validate order data
    pub fn validate(self: *const Order) OrderError!void {
        // Market orders don't need price validation (price is set to 0)
        if (self.type != .Market) {
            if (self.price <= 0 or !std.math.isFinite(self.price)) {
                if (@import("builtin").is_test == false) {
                    std.debug.print("Error: Invalid order price: {d} (must be positive and finite for {s} orders)\n", .{self.price, @tagName(self.type)});
                }
                return OrderError.InvalidPrice;
            }
        }
        if (self.volume <= 0 or !std.math.isFinite(self.volume)) {
            if (@import("builtin").is_test == false) {
                std.debug.print("Error: Invalid order volume: {d} (must be positive and finite)\n", .{self.volume});
            }
            return OrderError.InvalidVolume;
        }
    }
};

pub const OrderManager = struct {
    orders: std.ArrayList(Order),
    orders_working: std.ArrayList(u32),
    orders_canceled: std.ArrayList(u32),
    working_lookup: std.AutoHashMap(u64, u32),
    next_id: u64,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) OrderManager {
        return OrderManager{
            .orders = std.ArrayList(Order){},
            .orders_working = std.ArrayList(u32){},
            .orders_canceled = std.ArrayList(u32){},
            .working_lookup = std.AutoHashMap(u64, u32).init(alloc),
            .next_id = 1,
            .alloc = alloc,
        };
    }

    pub fn placeOrder(self: *OrderManager, alloc: std.mem.Allocator, order: Order) (OrderError || std.mem.Allocator.Error)!u64 {
        _ = alloc; // Use stored allocator instead
        
        // Validate order before placing
        try order.validate();
        
        try self.orders.append(self.alloc, order);
        const idx: u32 = @intCast(self.orders.items.len - 1);
        try self.orders_working.append(self.alloc, idx);
        try self.working_lookup.put(order.id, idx);
        return order.id;
    }

    pub fn cancelOrder(self: *OrderManager, alloc: std.mem.Allocator, order_id: u64) !void {
        _ = alloc; // Use stored allocator instead
        // Look up the order index using HashMap
        const idx = self.working_lookup.get(order_id) orelse return; // Order not found or already filled/canceled
        
        // Remove from working lookup
        _ = self.working_lookup.remove(order_id);
        
        // Find and remove from working list
        for (self.orders_working.items, 0..) |working_idx, i| {
            if (working_idx == idx) {
                _ = self.orders_working.orderedRemove(i);
                break;
            }
        }
        
        // Add to canceled list
        try self.orders_canceled.append(self.alloc, idx);
    }

    /// Modify the price of a working order (only for pending orders)
    pub fn modifyOrder(self: *OrderManager, alloc: std.mem.Allocator, order_id: u64, new_price: f64) OrderError!void {
        _ = alloc; // Use stored allocator instead
        
        // Validate new price
        if (new_price <= 0 or !std.math.isFinite(new_price)) {
            if (@import("builtin").is_test == false) {
                std.debug.print("Error: Invalid modified price: {d}\n", .{new_price});
            }
            return OrderError.InvalidPrice;
        }
        
        // Look up the order index using HashMap
        const idx = self.working_lookup.get(order_id) orelse {
            if (@import("builtin").is_test == false) {
                std.debug.print("Warning: Attempt to modify non-existent order ID: {d}\n", .{order_id});
            }
            return OrderError.OrderNotFound;
        };
        
        // Update the order price
        self.orders.items[idx].price = new_price;
    }

    pub fn deinit(self: *OrderManager) void {
        self.orders.deinit(self.alloc);
        self.orders_working.deinit(self.alloc);
        self.orders_canceled.deinit(self.alloc);
        self.working_lookup.deinit();
    }
};
