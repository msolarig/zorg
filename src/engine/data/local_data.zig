const std = @import("std");
const db = @import("sql_wrap.zig");
const abi = @import("../../zdk/abi.zig");

pub const Track = struct {
    size: u64,
    ts: std.ArrayListUnmanaged(u64),
    op: std.ArrayListUnmanaged(f64),
    hi: std.ArrayListUnmanaged(f64),
    lo: std.ArrayListUnmanaged(f64),
    cl: std.ArrayListUnmanaged(f64),
    vo: std.ArrayListUnmanaged(u64),

    pub fn init() Track {
        return Track{
            .size = 0,
            .ts = .{},
            .op = .{},
            .hi = .{},
            .lo = .{},
            .cl = .{},
            .vo = .{},
        };
    }

    pub fn load(self: *Track, alloc: std.mem.Allocator, db_handle: *anyopaque, table: []const u8, t0: u64, tn: u64) !void {
        const query: []const u8 = "SELECT timestamp, open, high, low, close, volume FROM {s} ORDER BY timestamp DESC";
        const command: []const u8 = try std.fmt.allocPrint(alloc, query, .{table});
        const c_command = try std.heap.c_allocator.dupeZ(u8, command);
        defer std.heap.c_allocator.free(c_command);
        defer alloc.free(command);

        var stmt: ?*anyopaque = null;
        var tail: ?*[*:0]const u8 = null;
        const prepare = db.sqlite3_prepare_v2(db_handle, c_command, -1, &stmt, &tail);

        if (prepare != 0) {
            const errmsg = db.sqlite3_errmsg(db_handle);
            const msg = std.mem.span(errmsg);
            std.debug.print("SQLite prepare error: {s}\n", .{msg});
            return error.PrepareFailed;
        }

        while (db.sqlite3_step(stmt.?) == 100) {
            const ts: u64 = @intFromFloat(db.sqlite3_column_double(stmt.?, 0));
            if (ts > t0 and ts < tn) { // Non-inclusive
                const op = db.sqlite3_column_double(stmt.?, 1);
                const hi = db.sqlite3_column_double(stmt.?, 2);
                const lo = db.sqlite3_column_double(stmt.?, 3);
                const cl = db.sqlite3_column_double(stmt.?, 4);
                const vo: u64 = @intFromFloat(db.sqlite3_column_double(stmt.?, 5));

                try self.ts.append(alloc, ts);
                try self.op.append(alloc, op);
                try self.hi.append(alloc, hi);
                try self.lo.append(alloc, lo);
                try self.cl.append(alloc, cl);
                try self.vo.append(alloc, vo);
                self.size += 1;
            }
        }
        _ = db.sqlite3_finalize(stmt.?);
    }

    pub fn deinit(self: *Track, alloc: std.mem.Allocator) void {
        self.ts.deinit(alloc);
        self.op.deinit(alloc);
        self.hi.deinit(alloc);
        self.lo.deinit(alloc);
        self.cl.deinit(alloc);
        self.vo.deinit(alloc);
    }
};

pub const Trail = struct {
    size: usize,
    ts: []u64,
    op: []f64,
    hi: []f64,
    lo: []f64,
    cl: []f64,
    vo: []u64,

    pub fn init(alloc: std.mem.Allocator, size: usize) !Trail {
        return Trail{
            .size = size,
            .ts = try alloc.alloc(u64, size),
            .op = try alloc.alloc(f64, size),
            .hi = try alloc.alloc(f64, size),
            .lo = try alloc.alloc(f64, size),
            .cl = try alloc.alloc(f64, size),
            .vo = try alloc.alloc(u64, size),
        };
    }

    pub fn load(self: *Trail, track: Track, steps: u64) !void {
        var trail_index: u64 = 0;
        var track_index: u64 = track.ts.items.len - (steps + 1);
        while (trail_index < self.size) : (track_index -= 1) {
            self.ts[trail_index] = track.ts.items[track_index];
            self.op[trail_index] = track.op.items[track_index];
            self.hi[trail_index] = track.hi.items[track_index];
            self.lo[trail_index] = track.lo.items[track_index];
            self.cl[trail_index] = track.cl.items[track_index];
            self.vo[trail_index] = track.vo.items[track_index];
            trail_index += 1;

            if (track_index == 0)
                break;
        }
    }

    pub fn toABI(self: *Trail) abi.TrailABI {
        return abi.TrailABI{
            .ts = self.ts.ptr,
            .op = self.op.ptr,
            .hi = self.hi.ptr,
            .lo = self.lo.ptr,
            .cl = self.cl.ptr,
            .vo = self.vo.ptr,
        };
    }

    pub fn deinit(self: *Trail, alloc: std.mem.Allocator) void {
        alloc.free(self.ts);
        alloc.free(self.op);
        alloc.free(self.hi);
        alloc.free(self.lo);
        alloc.free(self.cl);
        alloc.free(self.vo);
    }
};
