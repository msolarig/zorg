const std = @import("std");
const data = @import("../engine/assembly/data.zig");

test "Assembly: Track initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var track = data.Track.init();
    defer track.deinit(alloc);
    
    try std.testing.expectEqual(@as(u64, 0), track.size);
    try std.testing.expectEqual(@as(usize, 0), track.ts.items.len);
    try std.testing.expectEqual(@as(usize, 0), track.op.items.len);
}

test "Assembly: Trail initialization and size" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const trail_size: usize = 50;
    var trail = try data.Trail.init(alloc, trail_size);
    defer trail.deinit(alloc);
    
    try std.testing.expectEqual(trail_size, trail.size);
    try std.testing.expectEqual(trail_size, trail.ts.len);
    try std.testing.expectEqual(trail_size, trail.op.len);
    try std.testing.expectEqual(trail_size, trail.hi.len);
    try std.testing.expectEqual(trail_size, trail.lo.len);
    try std.testing.expectEqual(trail_size, trail.cl.len);
    try std.testing.expectEqual(trail_size, trail.vo.len);
}

test "Assembly: Trail toABI conversion" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var trail = try data.Trail.init(alloc, 10);
    defer trail.deinit(alloc);
    
    // Set some test data
    trail.ts[0] = 1000;
    trail.op[0] = 100.0;
    trail.hi[0] = 105.0;
    trail.lo[0] = 95.0;
    trail.cl[0] = 102.0;
    trail.vo[0] = 1000;
    
    const abi_trail = trail.toABI();
    
    try std.testing.expectEqual(@as(u64, 1000), abi_trail.ts[0]);
    try std.testing.expectEqual(@as(f64, 100.0), abi_trail.op[0]);
    try std.testing.expectEqual(@as(f64, 105.0), abi_trail.hi[0]);
    try std.testing.expectEqual(@as(f64, 95.0), abi_trail.lo[0]);
    try std.testing.expectEqual(@as(f64, 102.0), abi_trail.cl[0]);
    try std.testing.expectEqual(@as(u64, 1000), abi_trail.vo[0]);
}

test "Assembly: Multiple trail sizes" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Test various trail sizes
    const sizes = [_]usize{ 1, 10, 50, 100, 500 };
    
    for (sizes) |size| {
        var trail = try data.Trail.init(alloc, size);
        defer trail.deinit(alloc);
        
        try std.testing.expectEqual(size, trail.size);
        try std.testing.expectEqual(size, trail.ts.len);
    }
}

