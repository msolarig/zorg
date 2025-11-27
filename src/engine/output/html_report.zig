const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});

// Chart.js 4.4.1 embedded for offline use
const CHARTJS_MIN = @embedFile("chartjs.min.js");
const OutputManager = @import("output_manager.zig").OutputManager;

pub const HTMLReportError = error{
    DatabaseOpenFailed,
    QueryFailed,
    FileCreationFailed,
    WriteError,
    PathResolutionFailed,
    SourceFileReadFailed,
    CalculationError,
    NoData,
    PrepareStatementFailed,
} || std.mem.Allocator.Error || std.fs.File.WriteError || std.fs.File.OpenError;

const TradeStats = struct {
    total_trades: u32,
    winning_trades: u32,
    losing_trades: u32,
    even_trades: u32,
    total_pnl: f64,
    gross_profit: f64,
    gross_loss: f64,
    win_rate: f64,
    profit_factor: f64,
    avg_win: f64,
    avg_loss: f64,
    avg_trade: f64,
    largest_win: f64,
    largest_loss: f64,
    max_consec_wins: u32,
    max_consec_losses: u32,
};

const PerformanceMetrics = struct {
    all: TradeStats,
    long: TradeStats,
    short: TradeStats,
    sharpe_ratio: f64,
    sortino_ratio: f64,
    max_drawdown: f64,
    max_drawdown_pct: f64,
    expectancy: f64,
    risk_reward_ratio: f64,
    ulcer_index: f64,
    r_squared: f64,
    start_date: i64,
    end_date: i64,
};

const EquityPoint = struct {
    timestamp: i64,
    equity: f64,
};

pub fn generateHTMLReport(out: *OutputManager, db_filename: []const u8, html_filename: []const u8, auto_name: []const u8, auto_source_path: []const u8, zdk_version: []const u8) HTMLReportError!void {
    const db_path = out.filePath(std.heap.page_allocator, db_filename) catch |err| {
        std.debug.print("Error: Failed to resolve database path: {s}\n", .{@errorName(err)});
        return HTMLReportError.PathResolutionFailed;
    };
    defer std.heap.page_allocator.free(db_path);

    // Open database
    var db: ?*c.sqlite3 = null;
    const result = c.sqlite3_open(db_path.ptr, &db);
    if (result != c.SQLITE_OK) {
        std.debug.print("Error: Failed to open backtest database: {s}\n", .{db_path});
        if (db) |d| {
            const errmsg = c.sqlite3_errmsg(d);
            std.debug.print("SQLite error: {s}\n", .{std.mem.span(errmsg)});
        }
        return HTMLReportError.DatabaseOpenFailed;
    }
    defer _ = c.sqlite3_close(db);

    // Calculate metrics
    const metrics = calculateMetrics(db.?) catch |err| {
        std.debug.print("Error: Failed to calculate performance metrics: {s}\n", .{@errorName(err)});
        return HTMLReportError.CalculationError;
    };
    
    // Get equity curve data
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var equity_points: std.ArrayList(EquityPoint) = .{};
    defer equity_points.deinit(allocator);
    calculateEquityCurve(db.?, &equity_points, allocator) catch |err| {
        std.debug.print("Error: Failed to calculate equity curve: {s}\n", .{@errorName(err)});
        return HTMLReportError.CalculationError;
    };
    
    if (equity_points.items.len == 0) {
        std.debug.print("Warning: No equity data available for report\n", .{});
    }

    // Generate HTML
    const html_path = out.filePath(std.heap.page_allocator, html_filename) catch |err| {
        std.debug.print("Error: Failed to resolve HTML file path: {s}\n", .{@errorName(err)});
        return HTMLReportError.PathResolutionFailed;
    };
    defer std.heap.page_allocator.free(html_path);

    // Read auto source code
    const auto_code = std.fs.cwd().readFileAlloc(std.heap.page_allocator, auto_source_path, 1024 * 1024) catch "";
    defer if (auto_code.len > 0) std.heap.page_allocator.free(auto_code);

    var file = try std.fs.cwd().createFile(html_path, .{ .truncate = true });
    defer file.close();

    var buf: [81192]u8 = undefined;
    var bw = file.writer(&buf);
    try writeHTMLReport(&bw, metrics, equity_points.items, db.?, auto_name, auto_code, zdk_version);
    try file.sync();
}

fn calculateMetrics(db: *c.sqlite3) !PerformanceMetrics {
    var all_stats = TradeStats{
        .total_trades = 0,
        .winning_trades = 0,
        .losing_trades = 0,
        .even_trades = 0,
        .total_pnl = 0,
        .gross_profit = 0,
        .gross_loss = 0,
        .win_rate = 0,
        .profit_factor = 0,
        .avg_win = 0,
        .avg_loss = 0,
        .avg_trade = 0,
        .largest_win = 0,
        .largest_loss = 0,
        .max_consec_wins = 0,
        .max_consec_losses = 0,
    };
    
    var long_stats = all_stats;
    var short_stats = all_stats;
    
    var metrics = PerformanceMetrics{
        .all = all_stats,
        .long = long_stats,
        .short = short_stats,
        .sharpe_ratio = 0,
        .sortino_ratio = 0,
        .max_drawdown = 0,
        .max_drawdown_pct = 0,
        .expectancy = 0,
        .risk_reward_ratio = 0,
        .ulcer_index = 0,
        .r_squared = 0,
        .start_date = 0,
        .end_date = 0,
    };

    // Query positions to calculate P&L
    const query =
        \\SELECT side, open_timestamp, close_timestamp, avg_entry_price, volume
        \\FROM positions
        \\ORDER BY open_timestamp;
    ;

    var stmt: ?*c.sqlite3_stmt = null;
    if (c.sqlite3_prepare_v2(db, query.ptr, -1, &stmt, null) != c.SQLITE_OK) {
        return error.PrepareStatementFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    var consec_wins: u32 = 0;
    var consec_losses: u32 = 0;
    var first_ts: ?i64 = null;
    var last_ts: i64 = 0;

    while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
        const side_str = c.sqlite3_column_text(stmt, 0);
        const open_ts = c.sqlite3_column_int64(stmt, 1);
        const close_ts_type = c.sqlite3_column_type(stmt, 2);
        const entry_price = c.sqlite3_column_double(stmt, 3);
        
        if (first_ts == null) first_ts = open_ts;
        
        const close_timestamp = if (close_ts_type == c.SQLITE_NULL) null else c.sqlite3_column_int64(stmt, 2);
        
        if (close_timestamp) |close_ts| {
            last_ts = close_ts;
            const exit_price = try getExitPrice(db, close_ts);
            const is_long = std.mem.eql(u8, std.mem.span(side_str), "Long");
            
            const pnl = if (is_long) exit_price - entry_price else entry_price - exit_price;
            
            // Update all stats
            all_stats.total_trades += 1;
            all_stats.total_pnl += pnl;
            
            // Update long/short stats
            var stats = if (is_long) &long_stats else &short_stats;
            stats.total_trades += 1;
            stats.total_pnl += pnl;
            
            if (pnl > 0.001) {
                all_stats.winning_trades += 1;
                all_stats.gross_profit += pnl;
                stats.winning_trades += 1;
                stats.gross_profit += pnl;
                if (pnl > all_stats.largest_win) all_stats.largest_win = pnl;
                if (pnl > stats.largest_win) stats.largest_win = pnl;
                
                consec_wins += 1;
                if (consec_wins > all_stats.max_consec_wins) all_stats.max_consec_wins = consec_wins;
                if (consec_wins > stats.max_consec_wins) stats.max_consec_wins = consec_wins;
                consec_losses = 0;
            } else if (pnl < -0.001) {
                all_stats.losing_trades += 1;
                all_stats.gross_loss += @abs(pnl);
                stats.losing_trades += 1;
                stats.gross_loss += @abs(pnl);
                if (pnl < all_stats.largest_loss) all_stats.largest_loss = pnl;
                if (pnl < stats.largest_loss) stats.largest_loss = pnl;
                
                consec_losses += 1;
                if (consec_losses > all_stats.max_consec_losses) all_stats.max_consec_losses = consec_losses;
                if (consec_losses > stats.max_consec_losses) stats.max_consec_losses = consec_losses;
                consec_wins = 0;
            } else {
                all_stats.even_trades += 1;
                stats.even_trades += 1;
                consec_wins = 0;
                consec_losses = 0;
            }
        }
    }
    
    metrics.all = all_stats;
    metrics.long = long_stats;
    metrics.short = short_stats;
    metrics.start_date = first_ts orelse 0;
    metrics.end_date = last_ts;
    
    // Calculate derived metrics for all trades
    calculateDerivedStats(&metrics.all);
    calculateDerivedStats(&metrics.long);
    calculateDerivedStats(&metrics.short);
    
    // Overall expectancy and risk/reward
    if (metrics.all.avg_loss > 0) {
        metrics.risk_reward_ratio = metrics.all.avg_win / metrics.all.avg_loss;
    }
    if (metrics.all.total_trades > 0) {
        metrics.expectancy = (metrics.all.win_rate / 100.0 * metrics.all.avg_win) - ((100.0 - metrics.all.win_rate) / 100.0 * metrics.all.avg_loss);
    }
    
    // Calculate Sharpe and Sortino
    try calculateRiskMetrics(db, &metrics);

    return metrics;
}

fn calculateDerivedStats(stats: *TradeStats) void {
    if (stats.total_trades > 0) {
        stats.win_rate = @as(f64, @floatFromInt(stats.winning_trades)) / @as(f64, @floatFromInt(stats.total_trades)) * 100.0;
        stats.avg_trade = stats.total_pnl / @as(f64, @floatFromInt(stats.total_trades));
    }
    
    if (stats.gross_loss > 0) {
        stats.profit_factor = stats.gross_profit / stats.gross_loss;
    }
    
    if (stats.winning_trades > 0) {
        stats.avg_win = stats.gross_profit / @as(f64, @floatFromInt(stats.winning_trades));
    }
    
    if (stats.losing_trades > 0) {
        stats.avg_loss = stats.gross_loss / @as(f64, @floatFromInt(stats.losing_trades));
    }
}

fn calculateRiskMetrics(db: *c.sqlite3, metrics: *PerformanceMetrics) !void {
    const query =
        \\SELECT p.side, p.avg_entry_price, p.close_timestamp
        \\FROM positions p
        \\WHERE p.close_timestamp IS NOT NULL
        \\ORDER BY p.close_timestamp;
    ;

    var stmt: ?*c.sqlite3_stmt = null;
    if (c.sqlite3_prepare_v2(db, query.ptr, -1, &stmt, null) != c.SQLITE_OK) {
        return error.PrepareStatementFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    var returns: std.ArrayList(f64) = .{};
    defer returns.deinit(std.heap.page_allocator);
    
    var equity: f64 = 10000;
    var peak_equity: f64 = 10000;
    var max_dd: f64 = 0;

    while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
        const side_str = c.sqlite3_column_text(stmt, 0);
        const entry_price = c.sqlite3_column_double(stmt, 1);
        const close_ts = c.sqlite3_column_int64(stmt, 2);
        const exit_price = try getExitPrice(db, close_ts);
        
        const is_long = std.mem.eql(u8, std.mem.span(side_str), "Long");
        const pnl = if (is_long) exit_price - entry_price else entry_price - exit_price;
        
        equity += pnl;
        if (equity > peak_equity) {
            peak_equity = equity;
        }
        
        const drawdown = peak_equity - equity;
        if (drawdown > max_dd) {
            max_dd = drawdown;
        }
        
        const trade_return = pnl / entry_price;
        try returns.append(std.heap.page_allocator, trade_return);
    }
    
    metrics.max_drawdown = max_dd;
    metrics.max_drawdown_pct = if (peak_equity > 0) (max_dd / peak_equity) * 100.0 else 0;
    
    // Calculate mean and std dev of returns
    if (returns.items.len > 1) {
        var sum: f64 = 0;
        for (returns.items) |ret| {
            sum += ret;
        }
        const mean = sum / @as(f64, @floatFromInt(returns.items.len));
        
        var variance: f64 = 0;
        var downside_variance: f64 = 0;
        for (returns.items) |ret| {
            const diff = ret - mean;
            variance += diff * diff;
            if (ret < 0) {
                downside_variance += ret * ret;
            }
        }
        
        const std_dev = @sqrt(variance / @as(f64, @floatFromInt(returns.items.len)));
        const downside_std = @sqrt(downside_variance / @as(f64, @floatFromInt(returns.items.len)));
        
        // Sharpe ratio (simplified, assuming risk-free rate = 0)
        if (std_dev > 0) {
            metrics.sharpe_ratio = mean / std_dev * @sqrt(@as(f64, @floatFromInt(returns.items.len)));
        }
        
        // Sortino ratio
        if (downside_std > 0) {
            metrics.sortino_ratio = mean / downside_std * @sqrt(@as(f64, @floatFromInt(returns.items.len)));
        }
    }
}

fn getExitPrice(db: *c.sqlite3, close_timestamp: i64) !f64 {
    const query =
        \\SELECT price FROM fills WHERE timestamp = ? ORDER BY fill_id DESC LIMIT 1;
    ;
    
    var stmt: ?*c.sqlite3_stmt = null;
    if (c.sqlite3_prepare_v2(db, query.ptr, -1, &stmt, null) != c.SQLITE_OK) {
        return error.PrepareStatementFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);
    
    _ = c.sqlite3_bind_int64(stmt, 1, close_timestamp);
    
    if (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
        return c.sqlite3_column_double(stmt, 0);
    }
    
    return 0;
}

fn calculateEquityCurve(db: *c.sqlite3, equity_points: *std.ArrayList(EquityPoint), allocator: std.mem.Allocator) !void {
    var running_equity: f64 = 10000; // Starting capital
    var first_timestamp: ?i64 = null;
    
    const query =
        \\SELECT p.side, p.open_timestamp, p.close_timestamp, p.avg_entry_price
        \\FROM positions p
        \\WHERE p.close_timestamp IS NOT NULL
        \\ORDER BY p.close_timestamp;
    ;

    var stmt: ?*c.sqlite3_stmt = null;
    if (c.sqlite3_prepare_v2(db, query.ptr, -1, &stmt, null) != c.SQLITE_OK) {
        return error.PrepareStatementFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    // Add starting point
    try equity_points.append(allocator, .{ .timestamp = 0, .equity = running_equity });

    while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
        const side_str = c.sqlite3_column_text(stmt, 0);
        const close_ts = c.sqlite3_column_int64(stmt, 2);
        const entry_price = c.sqlite3_column_double(stmt, 3);
        const exit_price = try getExitPrice(db, close_ts);
        
        // Set first timestamp for normalization
        if (first_timestamp == null) {
            first_timestamp = close_ts;
        }
        
        const is_long = std.mem.eql(u8, std.mem.span(side_str), "Long");
        const pnl = if (is_long)
            exit_price - entry_price
        else
            entry_price - exit_price;
        
        running_equity += pnl;
        
        // Normalize timestamp relative to first trade
        const normalized_ts = close_ts - (first_timestamp orelse 0);
        try equity_points.append(allocator, .{ .timestamp = normalized_ts, .equity = running_equity });
    }
}

fn writeHTMLReport(bw: anytype, metrics: PerformanceMetrics, equity_curve: []const EquityPoint, db: *c.sqlite3, auto_name: []const u8, auto_code: []const u8, zdk_version: []const u8) !void {
    // Write HTML header
    _ = try bw.file.write(
        \\<!DOCTYPE html>
        \\<html lang="en">
        \\<head>
        \\    <meta charset="UTF-8">
        \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
        \\    <title>Auto Backtest Report - Zorg</title>
        \\    <style>
        \\        @font-face {
        \\            font-family: 'Fira Code';
        \\            font-style: normal;
        \\            font-weight: 400;
        \\            src: local('Fira Code'), local('FiraCode-Regular'), url('data:font/woff2;charset=utf-8;base64,d09GMgABAAAAAB...') format('woff2');
        \\        }
        \\    </style>
        \\    <style>
        \\        * { margin: 0; padding: 0; box-sizing: border-box; }
        \\        body {
        \\            font-family: 'Fira Code', 'Consolas', 'Monaco', 'Courier New', monospace;
        \\            background: #0a0a0a;
        \\            color: #e0e0e0;
        \\            padding: 20px;
        \\            line-height: 1.4;
        \\        }
        \\        .container { max-width: 1400px; margin: 0 auto; }
        \\        h1 {
        \\            font-size: 1.8rem;
        \\            margin-bottom: 5px;
        \\            color: #fff;
        \\            font-weight: bold;
        \\            letter-spacing: 3px;
        \\            border-left: 4px solid #dc2626;
        \\            padding-left: 15px;
        \\            padding-bottom: 10px;
        \\        }
        \\        .subtitle {
        \\            color: #666;
        \\            margin-bottom: 30px;
        \\            margin-left: 19px;
        \\            font-size: 0.8rem;
        \\        }
        \\        .metrics-grid {
        \\            display: grid;
        \\            grid-template-columns: repeat(4, 1fr);
        \\            gap: 2px;
        \\            margin-bottom: 30px;
        \\            background: #1a1a1a;
        \\        }
        \\        .metric-card {
        \\            background: #0a0a0a;
        \\            border: 1px solid #2a2a2a;
        \\            padding: 15px;
        \\        }
        \\        .metric-label {
        \\            font-size: 0.65rem;
        \\            color: #666;
        \\            text-transform: uppercase;
        \\            letter-spacing: 1.5px;
        \\            margin-bottom: 8px;
        \\            font-weight: bold;
        \\        }
        \\        .metric-value {
        \\            font-size: 1.8rem;
        \\            font-weight: 700;
        \\            color: #fff;
        \\            font-family: 'Fira Code', monospace;
        \\        }
        \\        .metric-value.positive { color: #dc2626; }
        \\        .metric-value.negative { color: #e63946; }
        \\        .chart-container {
        \\            background: #0a0a0a;
        \\            border: 1px solid #2a2a2a;
        \\            border-left: 3px solid #dc2626;
        \\            padding: 20px;
        \\            margin-bottom: 30px;
        \\            position: relative;
        \\            height: 450px;
        \\        }
        \\        .analytics-chart {
        \\            height: 520px;
        \\        }
        \\        .chart-wrapper {
        \\            width: 100%;
        \\            height: calc(100% - 35px);
        \\            position: relative;
        \\        }
        \\        canvas {
        \\            -moz-osx-font-smoothing: grayscale;
        \\            -webkit-font-smoothing: antialiased;
        \\            width: 100% !important;
        \\            height: 100% !important;
        \\        }
        \\        .chart-title {
        \\            font-size: 0.9rem;
        \\            margin-bottom: 15px;
        \\            color: #fff;
        \\            text-transform: uppercase;
        \\            letter-spacing: 2px;
        \\            font-weight: bold;
        \\        }
        \\        table {
        \\            width: 100%;
        \\            background: #0a0a0a;
        \\            border: 1px solid #2a2a2a;
        \\            border-collapse: collapse;
        \\        }
        \\        thead {
        \\            background: #1a1a1a;
        \\            border-bottom: 2px solid #dc2626;
        \\        }
        \\        th {
        \\            padding: 12px 10px;
        \\            text-align: left;
        \\            font-weight: bold;
        \\            color: #fff;
        \\            text-transform: uppercase;
        \\            font-size: 0.65rem;
        \\            letter-spacing: 1.5px;
        \\            border-right: 1px solid #2a2a2a;
        \\        }
        \\        th:last-child { border-right: none; }
        \\        td {
        \\            padding: 10px;
        \\            border-top: 1px solid #1a1a1a;
        \\            border-right: 1px solid #1a1a1a;
        \\            font-size: 0.85rem;
        \\            color: #bbb;
        \\        }
        \\        td:last-child { border-right: none; }
        \\        tbody tr:nth-child(even) {
        \\            background: #0f0f0f;
        \\        }
        \\        tbody tr:hover {
        \\            background: #1a1a1a;
        \\        }
        \\        .pnl-positive { color: #dc2626; font-weight: bold; }
        \\        .pnl-negative { color: #e63946; font-weight: bold; }
        \\        .section-title {
        \\            font-size: 0.9rem;
        \\            margin: 40px 0 15px 0;
        \\            color: #fff;
        \\            text-transform: uppercase;
        \\            letter-spacing: 2px;
        \\            border-left: 3px solid #dc2626;
        \\            padding-left: 15px;
        \\            font-weight: bold;
        \\        }
        \\        .badge {
        \\            display: inline-block;
        \\            padding: 3px 10px;
        \\            border: 1px solid;
        \\            font-size: 0.65rem;
        \\            font-weight: bold;
        \\            text-transform: uppercase;
        \\            letter-spacing: 1px;
        \\        }
        \\        .badge.long { border-color: #22c55e; color: #22c55e; background: #0a1a0a; }
        \\        .badge.short { border-color: #dc2626; color: #dc2626; background: #1a0a0a; }
        \\        .code-section {
        \\            background: #0a0a0a;
        \\            border: 1px solid #2a2a2a;
        \\            border-left: 3px solid #dc2626;
        \\            padding: 20px;
        \\            margin-bottom: 30px;
        \\            max-height: 500px;
        \\            overflow-y: auto;
        \\        }
        \\        .code-title {
        \\            font-size: 0.75rem;
        \\            margin-bottom: 15px;
        \\            color: #666;
        \\            text-transform: uppercase;
        \\            letter-spacing: 2px;
        \\            font-weight: bold;
        \\        }
        \\        .code-title .version {
        \\            color: #dc2626;
        \\        }
        \\        pre {
        \\            margin: 0;
        \\            background: #000;
        \\            border: 1px solid #1a1a1a;
        \\            padding: 15px;
        \\        }
        \\        pre code {
        \\            font-family: 'Fira Code', monospace;
        \\            font-size: 0.8rem;
        \\            line-height: 1.6;
        \\            color: #bbb;
        \\            background: #000;
        \\        }
        \\        .auto-name {
        \\            color: #dc2626;
        \\            font-weight: bold;
        \\        }
        \\        .perf-table-container {
        \\            background: #0a0a0a;
        \\            border: 1px solid #2a2a2a;
        \\            border-left: 3px solid #dc2626;
        \\            padding: 20px;
        \\            margin-bottom: 30px;
        \\        }
        \\        .history-table-container {
        \\            background: #0a0a0a;
        \\            border: 1px solid #2a2a2a;
        \\            border-left: 3px solid #dc2626;
        \\            padding: 20px;
        \\            margin-bottom: 20px;
        \\            max-height: 400px;
        \\            overflow-y: auto;
        \\        }
        \\        .table-title {
        \\            font-size: 0.9rem;
        \\            margin-bottom: 15px;
        \\            color: #fff;
        \\            text-transform: uppercase;
        \\            letter-spacing: 2px;
        \\            font-weight: bold;
        \\        }
        \\    </style>
        \\    <script>
        \\
    );
    
    // Embed Chart.js for complete portability
    _ = try bw.file.write(CHARTJS_MIN);
    
    _ = try bw.file.write(
        \\
        \\    </script>
        \\</head>
        \\<body>
        \\    <div class="container">
        \\        <h1>Auto Backtest Report</h1>
        \\        <div class="subtitle">Generated by Zorg | Auto: <span class="auto-name">
    );
    
    _ = try bw.file.write(auto_name);
    
    _ = try bw.file.write(
        \\</span></div>
        \\
    );
    
    // Write auto code section with proper escaping
    if (auto_code.len > 0) {
        _ = try bw.file.write(
        \\        <div class="code-section">
        \\            <div class="code-title">Source Code File - ZDK <span class="version">
        );
        _ = try bw.file.write(zdk_version);
        _ = try bw.file.write(
        \\</span></div>
        \\            <pre><code>
        );
        
        // HTML escape the code
        for (auto_code) |char| {
            switch (char) {
                '<' => _ = try bw.file.write("&lt;"),
                '>' => _ = try bw.file.write("&gt;"),
                '&' => _ = try bw.file.write("&amp;"),
                else => {
                    const c_buf = [_]u8{char};
                    _ = try bw.file.write(&c_buf);
                },
            }
        }
        
        _ = try bw.file.write(
        \\</code></pre>
        \\        </div>
        \\
        );
    }
    
    _ = try bw.file.write(
        \\
    );
    
    // Performance Summary Table (moved here, below code)
    _ = try bw.file.write(
        \\        <h2 class="section-title">Performance Summary</h2>
        \\        <div class="perf-table-container">
        \\            <table>
        \\                <thead>
        \\                    <tr>
        \\                        <th style="width: 30%;">Metric</th>
        \\                        <th style="width: 23%;">All Trades</th>
        \\                        <th style="width: 23%;">Long Trades</th>
        \\                        <th style="width: 24%;">Short Trades</th>
        \\                    </tr>
        \\                </thead>
        \\                <tbody>
        \\
    );
    
    try writePerformanceRows(bw, metrics);
    
    _ = try bw.file.write(
        \\                </tbody>
        \\            </table>
        \\        </div>
        \\
    );
    
    var buf: [256]u8 = undefined;

    // Equity Curve Chart
    _ = try bw.file.write(
        \\        <div class="chart-container">
        \\            <h2 class="chart-title">Equity Curve</h2>
        \\            <canvas id="equityChart"></canvas>
        \\        </div>
        \\
        \\        <script>
        \\            const ctx = document.getElementById('equityChart').getContext('2d');
        \\            const equityData = [
        \\
    );
    
    // Write equity curve data
    for (equity_curve, 0..) |point, i| {
        const equity_point = try std.fmt.bufPrint(&buf, "                {{x: {d}, y: {d:.2}}}", .{ point.timestamp, point.equity });
        _ = try bw.file.write(equity_point);
        if (i < equity_curve.len - 1) {
            _ = try bw.file.write(",\n");
        }
    }
    
    _ = try bw.file.write(
        \\
        \\            ];
        \\            
        \\            new Chart(ctx, {
        \\                type: 'line',
        \\                data: {
        \\                    datasets: [{
        \\                        label: 'EQUITY',
        \\                        data: equityData,
        \\                        borderColor: '#dc2626',
        \\                        backgroundColor: 'rgba(255, 107, 53, 0.08)',
        \\                        borderWidth: 2,
        \\                        fill: true,
        \\                        tension: 0,
        \\                        pointRadius: 0,
        \\                        pointHoverRadius: 5,
        \\                        pointHoverBackgroundColor: '#dc2626',
        \\                        pointHoverBorderColor: '#fff',
        \\                        pointHoverBorderWidth: 2
        \\                    }]
        \\                },
        \\                options: {
        \\                    responsive: true,
        \\                    maintainAspectRatio: false,
        \\                    devicePixelRatio: 2,
        \\                    scales: {
        \\                        x: {
        \\                            type: 'linear',
        \\                            title: { display: true, text: 'TIME (SECONDS FROM START)', color: '#666', font: { family: 'Fira Code', size: 10, weight: '500' } },
        \\                            ticks: { color: '#666', font: { family: 'Fira Code', size: 9 } },
        \\                            grid: { color: '#1a1a1a', lineWidth: 1 }
        \\                        },
        \\                        y: {
        \\                            title: { display: true, text: 'EQUITY ($)', color: '#666', font: { family: 'Fira Code', size: 10, weight: '500' } },
        \\                            ticks: { color: '#666', font: { family: 'Fira Code', size: 9 } },
        \\                            grid: { color: '#1a1a1a', lineWidth: 1 }
        \\                        }
        \\                    },
        \\                    plugins: {
        \\                        legend: { labels: { color: '#fff', font: { family: 'Fira Code', size: 11, weight: '700' } } },
        \\                        tooltip: {
        \\                            backgroundColor: '#1a1a1a',
        \\                            borderColor: '#dc2626',
        \\                            borderWidth: 2,
        \\                            titleColor: '#fff',
        \\                            bodyColor: '#dc2626',
        \\                            titleFont: { family: 'Fira Code', weight: '700' },
        \\                            bodyFont: { family: 'Fira Code', weight: '500' },
        \\                            padding: 12
        \\                        }
        \\                    }
        \\                }
        \\            });
        \\        </script>
        \\
    );
    
    // Advanced Analytics Section
    _ = try bw.file.write(
        \\        <h2 class="section-title">Advanced Analytics</h2>
        \\        
        \\        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 30px;">
        \\            <div class="chart-container analytics-chart">
        \\                <h3 style="color: #888; margin-bottom: 15px; font-size: 0.9rem;">Drawdown Analysis</h3>
        \\                <div class="chart-wrapper">
        \\                    <canvas id="drawdownChart"></canvas>
        \\                </div>
        \\            </div>
        \\            <div class="chart-container analytics-chart">
        \\                <h3 style="color: #888; margin-bottom: 15px; font-size: 0.9rem;">P&L Distribution</h3>
        \\                <div class="chart-wrapper">
        \\                    <canvas id="pnlDistChart"></canvas>
        \\                </div>
        \\            </div>
        \\        </div>
        \\        
        \\        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 30px;">
        \\            <div class="chart-container analytics-chart">
        \\                <h3 style="color: #888; margin-bottom: 15px; font-size: 0.9rem;">Trade P&L Scatter (3D: Trade # × P&L × Volume)</h3>
        \\                <div class="chart-wrapper">
        \\                    <canvas id="pnlScatterChart"></canvas>
        \\                </div>
        \\            </div>
        \\            <div class="chart-container analytics-chart">
        \\                <h3 style="color: #888; margin-bottom: 15px; font-size: 0.9rem;">Risk Metrics Profile</h3>
        \\                <div class="chart-wrapper">
        \\                    <canvas id="riskRadarChart"></canvas>
        \\                </div>
        \\            </div>
        \\        </div>
        \\        
        \\        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 30px;">
        \\            <div class="chart-container analytics-chart">
        \\                <h3 style="color: #888; margin-bottom: 15px; font-size: 0.9rem;">Return Distribution Histogram</h3>
        \\                <div class="chart-wrapper">
        \\                    <canvas id="returnHistChart"></canvas>
        \\                </div>
        \\            </div>
        \\            <div class="chart-container analytics-chart">
        \\                <h3 style="color: #888; margin-bottom: 15px; font-size: 0.9rem;">Risk vs Reward (3D: Avg Gain × Avg Loss × Win Rate)</h3>
        \\                <div class="chart-wrapper">
        \\                    <canvas id="riskRewardChart"></canvas>
        \\                </div>
        \\            </div>
        \\        </div>
        \\
        \\        <script>
        \\        // Drawdown Chart
        \\        const ddCtx = document.getElementById('drawdownChart').getContext('2d');
        \\        let peak = 0;
        \\        const ddData = equityData.map((point, i) => {
        \\            if (i === 0) peak = point.y;
        \\            if (point.y > peak) peak = point.y;
        \\            const drawdown = peak > 0 ? ((point.y - peak) / peak * 100) : 0;
        \\            return { x: point.x, y: drawdown };
        \\        });
        \\        new Chart(ddCtx, {
        \\            type: 'line',
        \\            data: {
        \\                datasets: [{
        \\                    label: 'Drawdown %',
        \\                    data: ddData,
        \\                    borderColor: '#dc2626',
        \\                    backgroundColor: 'rgba(220, 38, 38, 0.1)',
        \\                    borderWidth: 2,
        \\                    fill: true,
        \\                    tension: 0.4,
        \\                    pointRadius: 0
        \\                }]
        \\            },
        \\            options: {
        \\                responsive: true,
        \\                maintainAspectRatio: false,
        \\                devicePixelRatio: 2,
        \\                plugins: {
        \\                    legend: { display: false },
        \\                    tooltip: {
        \\                        backgroundColor: '#000',
        \\                        titleColor: '#fff',
        \\                        bodyColor: '#dc2626',
        \\                        borderColor: '#dc2626',
        \\                        borderWidth: 1,
        \\                        titleFont: { family: 'Fira Code' },
        \\                        bodyFont: { family: 'Fira Code' },
        \\                        callbacks: {
        \\                            label: (ctx) => `Drawdown: ${ctx.parsed.y.toFixed(2)}%`
        \\                        }
        \\                    }
        \\                },
        \\                scales: {
        \\                    x: { 
        \\                        type: 'linear',
        \\                        grid: { color: '#1a1a1a' }, 
        \\                        ticks: { color: '#666', font: { family: 'Fira Code' } } 
        \\                    },
        \\                    y: { 
        \\                        grid: { color: '#1a1a1a' }, 
        \\                        ticks: { 
        \\                            color: '#666', 
        \\                            font: { family: 'Fira Code' }, 
        \\                            callback: (val) => val.toFixed(1) + '%' 
        \\                        },
        \\                        max: 0
        \\                    }
        \\                }
        \\            }
        \\        });
        \\        
        \\        // P&L Distribution Doughnut Chart
        \\        const wlCtx = document.getElementById('pnlDistChart').getContext('2d');
        \\        new Chart(wlCtx, {
        \\            type: 'doughnut',
        \\            data: {
        \\                labels: ['Winning', 'Losing', 'Even'],
        \\                datasets: [{
        \\                    data: [
    );
    
    const chart_data = try std.fmt.bufPrint(&buf, "{d}, {d}, {d}", .{
        metrics.all.winning_trades,
        metrics.all.losing_trades,
        metrics.all.even_trades,
    });
    _ = try bw.file.write(chart_data);
    
    _ = try bw.file.write(
        \\],
        \\                    backgroundColor: ['#22c55e', '#dc2626', '#666'],
        \\                    borderColor: '#0a0a0a',
        \\                    borderWidth: 2
        \\                }]
        \\            },
        \\            options: {
        \\                responsive: true,
        \\                maintainAspectRatio: false,
        \\                devicePixelRatio: 2,
        \\                plugins: {
        \\                    legend: {
        \\                        position: 'right',
        \\                        labels: { 
        \\                            color: '#888', 
        \\                            font: { 
        \\                                family: "'Fira Code', 'Consolas', 'Monaco', 'Courier New', monospace",
        \\                                size: 11,
        \\                                weight: '500'
        \\                            }
        \\                        }
        \\                    },
        \\                    tooltip: {
        \\                        backgroundColor: '#000',
        \\                        titleColor: '#fff',
        \\                        bodyColor: '#fff',
        \\                        borderColor: '#dc2626',
        \\                        borderWidth: 1,
        \\                        titleFont: { family: 'Fira Code' },
        \\                        bodyFont: { family: 'Fira Code' }
        \\                    }
        \\                }
        \\            }
        \\        });
        \\        
        \\        // Trade P&L Scatter (Bubble for 3D effect - size represents volume)
        \\        const pnlCtx = document.getElementById('pnlScatterChart').getContext('2d');
        \\
    );
    
    // Generate P&L scatter data from positions
    _ = try bw.file.write("        let pnlScatterData = [\n");
    try writePnLScatterData(bw, db);
    _ = try bw.file.write("        ];\n");
    _ = try bw.file.write(
        \\        
        \\        // Debug and fallback
        \\        console.log('Scatter data points:', pnlScatterData.length);
        \\        if (pnlScatterData.length > 0) {
        \\            console.log('First point:', pnlScatterData[0]);
        \\            console.log('Last point:', pnlScatterData[pnlScatterData.length - 1]);
        \\        }
        \\        
        \\        // If no data, add sample point
        \\        if (pnlScatterData.length === 0) {
        \\            pnlScatterData = [{ x: 1, y: 0, r: 10 }];
        \\        }
        \\        
        \\
    );
    
    _ = try bw.file.write(
        \\        new Chart(pnlCtx, {
        \\            type: 'bubble',
        \\            data: {
        \\                datasets: [{
        \\                    label: 'Trades',
        \\                    data: pnlScatterData,
        \\                    backgroundColor: (ctx) => {
        \\                        const pnl = ctx.raw.y;
        \\                        return pnl >= 0 ? 'rgba(34, 197, 94, 0.6)' : 'rgba(220, 38, 38, 0.6)';
        \\                    },
        \\                    borderColor: (ctx) => {
        \\                        const pnl = ctx.raw.y;
        \\                        return pnl >= 0 ? '#22c55e' : '#dc2626';
        \\                    },
        \\                    borderWidth: 2
        \\                }]
        \\            },
        \\            options: {
        \\                responsive: true,
        \\                maintainAspectRatio: false,
        \\                devicePixelRatio: 2,
        \\                plugins: {
        \\                    legend: { display: false },
        \\                    tooltip: {
        \\                        backgroundColor: '#000',
        \\                        titleColor: '#fff',
        \\                        bodyColor: '#fff',
        \\                        borderColor: '#dc2626',
        \\                        borderWidth: 1,
        \\                        titleFont: { family: 'Fira Code' },
        \\                        bodyFont: { family: 'Fira Code' },
        \\                        callbacks: {
        \\                            label: (ctx) => {
        \\                                return [
        \\                                    `Trade #${ctx.raw.x}`,
        \\                                    `P&L: $${ctx.raw.y.toFixed(2)}`,
        \\                                    `Volume: ${ctx.raw.r * 2}`
        \\                                ];
        \\                            }
        \\                        }
        \\                    }
        \\                },
        \\                scales: {
        \\                    x: { 
        \\                        type: 'linear',
        \\                        title: { display: true, text: 'Trade Number', color: '#888', font: { family: 'Fira Code' } },
        \\                        grid: { color: '#1a1a1a' }, 
        \\                        ticks: { color: '#666', font: { family: 'Fira Code' }, stepSize: 1 },
        \\                        min: 0
        \\                    },
        \\                    y: { 
        \\                        type: 'linear',
        \\                        title: { display: true, text: 'P&L ($)', color: '#888', font: { family: 'Fira Code' } },
        \\                        grid: { color: '#1a1a1a' }, 
        \\                        ticks: { color: '#666', font: { family: 'Fira Code' } }
        \\                    }
        \\                }
        \\            }
        \\        });
        \\        
        \\        // Risk Radar Chart
        \\        const rrCtx = document.getElementById('riskRadarChart').getContext('2d');
        \\
    );
    
    // Calculate normalized risk metrics (0-100 scale)
    const sharpe_norm = @min(100.0, @max(0.0, (metrics.sharpe_ratio + 2) / 4 * 100));
    const sortino_norm = @min(100.0, @max(0.0, (metrics.sortino_ratio + 2) / 4 * 100));
    const pf_norm = @min(100.0, @max(0.0, metrics.all.profit_factor / 3 * 100));
    const wr_norm = metrics.all.win_rate;
    const exp_norm = @min(100.0, @max(0.0, (metrics.expectancy + 50) / 100 * 100));
    
    const risk_data = try std.fmt.bufPrint(&buf, "{d:.1}, {d:.1}, {d:.1}, {d:.1}, {d:.1}", .{
        sharpe_norm, sortino_norm, pf_norm, wr_norm, exp_norm,
    });
    _ = try bw.file.write("        new Chart(rrCtx, {\n");
    _ = try bw.file.write("            type: 'radar',\n");
    _ = try bw.file.write("            data: {\n");
    _ = try bw.file.write("                labels: ['Sharpe', 'Sortino', 'Profit Factor', 'Win Rate', 'Expectancy'],\n");
    _ = try bw.file.write("                datasets: [{\n");
    _ = try bw.file.write("                    label: 'Risk Profile',\n");
    _ = try bw.file.write("                    data: [");
    _ = try bw.file.write(risk_data);
    _ = try bw.file.write(
        \\],
        \\                    backgroundColor: 'rgba(220, 38, 38, 0.2)',
        \\                    borderColor: '#dc2626',
        \\                    borderWidth: 2,
        \\                    pointBackgroundColor: '#dc2626',
        \\                    pointBorderColor: '#fff',
        \\                    pointHoverBackgroundColor: '#fff',
        \\                    pointHoverBorderColor: '#dc2626'
        \\                }]
        \\            },
        \\            options: {
        \\                responsive: true,
        \\                maintainAspectRatio: false,
        \\                devicePixelRatio: 2,
        \\                scales: {
        \\                    r: {
        \\                        min: 0,
        \\                        max: 100,
        \\                        ticks: { color: '#666', backdropColor: 'transparent', font: { family: 'Fira Code' } },
        \\                        grid: { color: '#1a1a1a' },
        \\                        pointLabels: { color: '#888', font: { family: 'Fira Code' } }
        \\                    }
        \\                },
        \\                plugins: {
        \\                    legend: { display: false },
        \\                    tooltip: {
        \\                        backgroundColor: '#000',
        \\                        titleColor: '#fff',
        \\                        bodyColor: '#dc2626',
        \\                        borderColor: '#dc2626',
        \\                        borderWidth: 1,
        \\                        titleFont: { family: 'Fira Code' },
        \\                        bodyFont: { family: 'Fira Code' }
        \\                    }
        \\                }
        \\            }
        \\        });
        \\        
        \\        // Return Distribution Histogram
        \\        const rhCtx = document.getElementById('returnHistChart').getContext('2d');
        \\
    );
    
    // Generate histogram bins
    _ = try bw.file.write("        const returnBins = [\n");
    try writeReturnHistogram(bw, db);
    _ = try bw.file.write("        ];\n");
    
    _ = try bw.file.write(
        \\        new Chart(rhCtx, {
        \\            type: 'bar',
        \\            data: {
        \\                labels: returnBins.map(b => b.label),
        \\                datasets: [{
        \\                    label: 'Trade Count',
        \\                    data: returnBins.map(b => b.count),
        \\                    backgroundColor: returnBins.map(b => b.color),
        \\                    borderColor: '#0a0a0a',
        \\                    borderWidth: 1
        \\                }]
        \\            },
        \\            options: {
        \\                responsive: true,
        \\                maintainAspectRatio: false,
        \\                devicePixelRatio: 2,
        \\                plugins: {
        \\                    legend: { display: false },
        \\                    tooltip: {
        \\                        backgroundColor: '#000',
        \\                        titleColor: '#fff',
        \\                        bodyColor: '#fff',
        \\                        borderColor: '#dc2626',
        \\                        borderWidth: 1,
        \\                        titleFont: { family: 'Fira Code' },
        \\                        bodyFont: { family: 'Fira Code' }
        \\                    }
        \\                },
        \\                scales: {
        \\                    x: { 
        \\                        title: { display: true, text: 'P&L Range ($)', color: '#888', font: { family: 'Fira Code' } },
        \\                        grid: { color: '#1a1a1a' }, 
        \\                        ticks: { color: '#666', font: { family: 'Fira Code' } } 
        \\                    },
        \\                    y: { 
        \\                        title: { display: true, text: 'Frequency', color: '#888', font: { family: 'Fira Code' } },
        \\                        grid: { color: '#1a1a1a' }, 
        \\                        ticks: { color: '#666', stepSize: 1, font: { family: 'Fira Code' } } 
        \\                    }
        \\                }
        \\            }
        \\        });
        \\        
        \\        // Risk vs Reward Bubble (3D: Avg Gain × Avg Loss × Win Rate as bubble size)
        \\        const rvwCtx = document.getElementById('riskRewardChart').getContext('2d');
        \\
    );
    
    const bubble_data = try std.fmt.bufPrint(&buf,
        \\        const riskRewardData = [
        \\            {{ x: {d:.2}, y: {d:.2}, r: {d:.1} }}
        \\        ];
        \\
    , .{ metrics.all.avg_loss, metrics.all.avg_win, metrics.all.win_rate / 2 });
    _ = try bw.file.write(bubble_data);
    
    _ = try bw.file.write(
        \\        new Chart(rvwCtx, {
        \\            type: 'bubble',
        \\            data: {
        \\                datasets: [{
        \\                    label: 'Overall Performance',
        \\                    data: riskRewardData,
        \\                    backgroundColor: 'rgba(220, 38, 38, 0.6)',
        \\                    borderColor: '#dc2626',
        \\                    borderWidth: 2
        \\                }]
        \\            },
        \\            options: {
        \\                responsive: true,
        \\                maintainAspectRatio: false,
        \\                devicePixelRatio: 2,
        \\                plugins: {
        \\                    legend: { display: false },
        \\                    tooltip: {
        \\                        backgroundColor: '#000',
        \\                        titleColor: '#fff',
        \\                        bodyColor: '#fff',
        \\                        borderColor: '#dc2626',
        \\                        borderWidth: 1,
        \\                        titleFont: { family: 'Fira Code' },
        \\                        bodyFont: { family: 'Fira Code' },
        \\                        callbacks: {
        \\                            label: (ctx) => {
        \\                                return [
        \\                                    `Avg Loss: $${ctx.raw.x.toFixed(2)}`,
        \\                                    `Avg Gain: $${ctx.raw.y.toFixed(2)}`,
        \\                                    `Win Rate: ${(ctx.raw.r * 2).toFixed(1)}%`
        \\                                ];
        \\                            }
        \\                        }
        \\                    }
        \\                },
        \\                scales: {
        \\                    x: { 
        \\                        title: { display: true, text: 'Avg Loss ($)', color: '#888', font: { family: 'Fira Code' } },
        \\                        grid: { color: '#1a1a1a' }, 
        \\                        ticks: { color: '#666', font: { family: 'Fira Code' } } 
        \\                    },
        \\                    y: { 
        \\                        title: { display: true, text: 'Avg Gain ($)', color: '#888', font: { family: 'Fira Code' } },
        \\                        grid: { color: '#1a1a1a' }, 
        \\                        ticks: { color: '#666', font: { family: 'Fira Code' } } 
        \\                    }
        \\                }
        \\            }
        \\        });
        \\        </script>
        \\
    );

    // History Tables
    _ = try bw.file.write(
        \\        <h2 class="section-title">Detailed History</h2>
        \\        <div class="history-table-container">
        \\            <div class="table-title">Orders</div>
        \\            <table>
        \\                <thead>
        \\                    <tr>
        \\                        <th>Order ID</th>
        \\                        <th>Iter</th>
        \\                        <th>Timestamp</th>
        \\                        <th>Type</th>
        \\                        <th>Side</th>
        \\                        <th>Price</th>
        \\                        <th>Volume</th>
        \\                        <th>Status</th>
        \\                    </tr>
        \\                </thead>
        \\                <tbody>
        \\
    );
    try writeOrderRows(bw, db);
    _ = try bw.file.write(
        \\                </tbody>
        \\            </table>
        \\        </div>
        \\
    );
    
    // Fills Table
    _ = try bw.file.write(
        \\        <div class="history-table-container">
        \\            <div class="table-title">Fills</div>
        \\            <table>
        \\                <thead>
        \\                    <tr>
        \\                        <th>Fill ID</th>
        \\                        <th>Order ID</th>
        \\                        <th>Iter</th>
        \\                        <th>Timestamp</th>
        \\                        <th>Side</th>
        \\                        <th>Price</th>
        \\                        <th>Volume</th>
        \\                    </tr>
        \\                </thead>
        \\                <tbody>
        \\
    );
    try writeFillRows(bw, db);
    _ = try bw.file.write(
        \\                </tbody>
        \\            </table>
        \\        </div>
        \\
    );
    
    // Positions Table
    _ = try bw.file.write(
        \\        <div class="history-table-container">
        \\            <div class="table-title">Positions</div>
        \\            <table>
        \\                <thead>
        \\                    <tr>
        \\                        <th>#</th>
        \\                        <th>Side</th>
        \\                        <th>Entry Time</th>
        \\                        <th>Exit Time</th>
        \\                        <th>Entry Price</th>
        \\                        <th>Exit Price</th>
        \\                        <th>Volume</th>
        \\                        <th>P&L</th>
        \\                    </tr>
        \\                </thead>
        \\                <tbody>
        \\
    );
    try writePositionRows(bw, db);
    _ = try bw.file.write(
        \\                </tbody>
        \\            </table>
        \\        </div>
        \\    </div>
        \\</body>
        \\</html>
        \\
    );
}

fn writeOrderRows(bw: anytype, db: *c.sqlite3) !void {
    const query =
        \\SELECT order_id, iter, timestamp, type, side, price, volume, status
        \\FROM orders
        \\ORDER BY order_id;
    ;

    var stmt: ?*c.sqlite3_stmt = null;
    if (c.sqlite3_prepare_v2(db, query.ptr, -1, &stmt, null) != c.SQLITE_OK) {
        return error.PrepareStatementFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    var buf: [512]u8 = undefined;

    while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
        const order_id = c.sqlite3_column_int64(stmt, 0);
        const iter = c.sqlite3_column_int64(stmt, 1);
        const timestamp = c.sqlite3_column_int64(stmt, 2);
        const type_str = c.sqlite3_column_text(stmt, 3);
        const side_str = c.sqlite3_column_text(stmt, 4);
        const price = c.sqlite3_column_double(stmt, 5);
        const volume = c.sqlite3_column_double(stmt, 6);
        const status_str = c.sqlite3_column_text(stmt, 7);
        
        const row = try std.fmt.bufPrint(&buf,
            \\                <tr>
            \\                    <td>{d}</td>
            \\                    <td>{d}</td>
            \\                    <td>{d}</td>
            \\                    <td>{s}</td>
            \\                    <td>{s}</td>
            \\                    <td>${d:.2}</td>
            \\                    <td>{d:.2}</td>
            \\                    <td>{s}</td>
            \\                </tr>
            \\
        , .{ order_id, iter, timestamp, std.mem.span(type_str), std.mem.span(side_str), price, volume, std.mem.span(status_str) });
        
        _ = try bw.file.write(row);
    }
}

fn writeFillRows(bw: anytype, db: *c.sqlite3) !void {
    const query =
        \\SELECT fill_id, order_id, iter, timestamp, side, price, volume
        \\FROM fills
        \\ORDER BY fill_id;
    ;

    var stmt: ?*c.sqlite3_stmt = null;
    if (c.sqlite3_prepare_v2(db, query.ptr, -1, &stmt, null) != c.SQLITE_OK) {
        return error.PrepareStatementFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    var buf: [512]u8 = undefined;

    while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
        const fill_id = c.sqlite3_column_int64(stmt, 0);
        const order_id = c.sqlite3_column_int64(stmt, 1);
        const iter = c.sqlite3_column_int64(stmt, 2);
        const timestamp = c.sqlite3_column_int64(stmt, 3);
        const side_str = c.sqlite3_column_text(stmt, 4);
        const price = c.sqlite3_column_double(stmt, 5);
        const volume = c.sqlite3_column_double(stmt, 6);
        
        const row = try std.fmt.bufPrint(&buf,
            \\                <tr>
            \\                    <td>{d}</td>
            \\                    <td>{d}</td>
            \\                    <td>{d}</td>
            \\                    <td>{d}</td>
            \\                    <td>{s}</td>
            \\                    <td>${d:.2}</td>
            \\                    <td>{d:.2}</td>
            \\                </tr>
            \\
        , .{ fill_id, order_id, iter, timestamp, std.mem.span(side_str), price, volume });
        
        _ = try bw.file.write(row);
    }
}

fn writePerformanceRows(bw: anytype, metrics: PerformanceMetrics) !void {
    // Helper to write a metric row
    const writeMetricRow = struct {
        fn call(writer: anytype, label: []const u8, all_val: []const u8, long_val: []const u8, short_val: []const u8) !void {
            _ = try writer.file.write("                <tr>\n");
            _ = try writer.file.write("                    <td style=\"color: #888; font-weight: bold;\">");
            _ = try writer.file.write(label);
            _ = try writer.file.write("</td>\n");
            _ = try writer.file.write("                    <td>");
            _ = try writer.file.write(all_val);
            _ = try writer.file.write("</td>\n");
            _ = try writer.file.write("                    <td>");
            _ = try writer.file.write(long_val);
            _ = try writer.file.write("</td>\n");
            _ = try writer.file.write("                    <td>");
            _ = try writer.file.write(short_val);
            _ = try writer.file.write("</td>\n");
            _ = try writer.file.write("                </tr>\n");
        }
    }.call;
    
    // Section: Performance
    var val_buf: [3][64]u8 = undefined;
    
    const net_all = try std.fmt.bufPrint(&val_buf[0], "${d:.2}", .{metrics.all.total_pnl});
    const net_long = try std.fmt.bufPrint(&val_buf[1], "${d:.2}", .{metrics.long.total_pnl});
    const net_short = try std.fmt.bufPrint(&val_buf[2], "${d:.2}", .{metrics.short.total_pnl});
    try writeMetricRow(bw, "Total net profit", net_all, net_long, net_short);
    
    const gp_all = try std.fmt.bufPrint(&val_buf[0], "${d:.2}", .{metrics.all.gross_profit});
    const gp_long = try std.fmt.bufPrint(&val_buf[1], "${d:.2}", .{metrics.long.gross_profit});
    const gp_short = try std.fmt.bufPrint(&val_buf[2], "${d:.2}", .{metrics.short.gross_profit});
    try writeMetricRow(bw, "Gross profit", gp_all, gp_long, gp_short);
    
    const gl_all = try std.fmt.bufPrint(&val_buf[0], "${d:.2}", .{metrics.all.gross_loss});
    const gl_long = try std.fmt.bufPrint(&val_buf[1], "${d:.2}", .{metrics.long.gross_loss});
    const gl_short = try std.fmt.bufPrint(&val_buf[2], "${d:.2}", .{metrics.short.gross_loss});
    try writeMetricRow(bw, "Gross loss", gl_all, gl_long, gl_short);
    
    const pf_all = try std.fmt.bufPrint(&val_buf[0], "{d:.2}", .{metrics.all.profit_factor});
    const pf_long = try std.fmt.bufPrint(&val_buf[1], "{d:.2}", .{metrics.long.profit_factor});
    const pf_short = try std.fmt.bufPrint(&val_buf[2], "{d:.2}", .{metrics.short.profit_factor});
    try writeMetricRow(bw, "Profit factor", pf_all, pf_long, pf_short);
    
    const dd_all = try std.fmt.bufPrint(&val_buf[0], "${d:.2}", .{metrics.max_drawdown});
    try writeMetricRow(bw, "Max. drawdown", dd_all, "-", "-");
    
    const sr_all = try std.fmt.bufPrint(&val_buf[0], "{d:.2}", .{metrics.sharpe_ratio});
    try writeMetricRow(bw, "Sharpe ratio", sr_all, "-", "-");
    
    const so_all = try std.fmt.bufPrint(&val_buf[0], "{d:.2}", .{metrics.sortino_ratio});
    try writeMetricRow(bw, "Sortino ratio", so_all, "-", "-");
    
    // Empty row separator
    _ = try bw.file.write("                <tr><td colspan=\"4\" style=\"height: 10px; background: #0a0a0a;\"></td></tr>\n");
    
    // Section: Trade counts
    const tt_all = try std.fmt.bufPrint(&val_buf[0], "{d}", .{metrics.all.total_trades});
    const tt_long = try std.fmt.bufPrint(&val_buf[1], "{d}", .{metrics.long.total_trades});
    const tt_short = try std.fmt.bufPrint(&val_buf[2], "{d}", .{metrics.short.total_trades});
    try writeMetricRow(bw, "Total # of trades", tt_all, tt_long, tt_short);
    
    const pp_all = try std.fmt.bufPrint(&val_buf[0], "{d:.1}%", .{metrics.all.win_rate});
    const pp_long = try std.fmt.bufPrint(&val_buf[1], "{d:.1}%", .{metrics.long.win_rate});
    const pp_short = try std.fmt.bufPrint(&val_buf[2], "{d:.1}%", .{metrics.short.win_rate});
    try writeMetricRow(bw, "Percent profitable", pp_all, pp_long, pp_short);
    
    const wt_all = try std.fmt.bufPrint(&val_buf[0], "{d}", .{metrics.all.winning_trades});
    const wt_long = try std.fmt.bufPrint(&val_buf[1], "{d}", .{metrics.long.winning_trades});
    const wt_short = try std.fmt.bufPrint(&val_buf[2], "{d}", .{metrics.short.winning_trades});
    try writeMetricRow(bw, "# of winning trades", wt_all, wt_long, wt_short);
    
    const lt_all = try std.fmt.bufPrint(&val_buf[0], "{d}", .{metrics.all.losing_trades});
    const lt_long = try std.fmt.bufPrint(&val_buf[1], "{d}", .{metrics.long.losing_trades});
    const lt_short = try std.fmt.bufPrint(&val_buf[2], "{d}", .{metrics.short.losing_trades});
    try writeMetricRow(bw, "# of losing trades", lt_all, lt_long, lt_short);
    
    const et_all = try std.fmt.bufPrint(&val_buf[0], "{d}", .{metrics.all.even_trades});
    const et_long = try std.fmt.bufPrint(&val_buf[1], "{d}", .{metrics.long.even_trades});
    const et_short = try std.fmt.bufPrint(&val_buf[2], "{d}", .{metrics.short.even_trades});
    try writeMetricRow(bw, "# of even trades", et_all, et_long, et_short);
    
    // Empty row separator
    _ = try bw.file.write("                <tr><td colspan=\"4\" style=\"height: 10px; background: #0a0a0a;\"></td></tr>\n");
    
    // Section: Averages
    const at_all = try std.fmt.bufPrint(&val_buf[0], "${d:.2}", .{metrics.all.avg_trade});
    const at_long = try std.fmt.bufPrint(&val_buf[1], "${d:.2}", .{metrics.long.avg_trade});
    const at_short = try std.fmt.bufPrint(&val_buf[2], "${d:.2}", .{metrics.short.avg_trade});
    try writeMetricRow(bw, "Avg. trade", at_all, at_long, at_short);
    
    const aw_all = try std.fmt.bufPrint(&val_buf[0], "${d:.2}", .{metrics.all.avg_win});
    const aw_long = try std.fmt.bufPrint(&val_buf[1], "${d:.2}", .{metrics.long.avg_win});
    const aw_short = try std.fmt.bufPrint(&val_buf[2], "${d:.2}", .{metrics.short.avg_win});
    try writeMetricRow(bw, "Average gain per trade", aw_all, aw_long, aw_short);
    
    const al_all = try std.fmt.bufPrint(&val_buf[0], "${d:.2}", .{metrics.all.avg_loss});
    const al_long = try std.fmt.bufPrint(&val_buf[1], "${d:.2}", .{metrics.long.avg_loss});
    const al_short = try std.fmt.bufPrint(&val_buf[2], "${d:.2}", .{metrics.short.avg_loss});
    try writeMetricRow(bw, "Average loss per trade", al_all, al_long, al_short);
    
    const rr_all = try std.fmt.bufPrint(&val_buf[0], "{d:.2}", .{metrics.risk_reward_ratio});
    const rr_long = try std.fmt.bufPrint(&val_buf[1], "{d:.2}", .{if (metrics.long.avg_loss > 0) metrics.long.avg_win / metrics.long.avg_loss else 0});
    const rr_short = try std.fmt.bufPrint(&val_buf[2], "{d:.2}", .{if (metrics.short.avg_loss > 0) metrics.short.avg_win / metrics.short.avg_loss else 0});
    try writeMetricRow(bw, "Ratio avg. gain / avg. loss", rr_all, rr_long, rr_short);
    
    // Empty row separator
    _ = try bw.file.write("                <tr><td colspan=\"4\" style=\"height: 10px; background: #0a0a0a;\"></td></tr>\n");
    
    // Section: Consecutive
    const cw_all = try std.fmt.bufPrint(&val_buf[0], "{d}", .{metrics.all.max_consec_wins});
    const cw_long = try std.fmt.bufPrint(&val_buf[1], "{d}", .{metrics.long.max_consec_wins});
    const cw_short = try std.fmt.bufPrint(&val_buf[2], "{d}", .{metrics.short.max_consec_wins});
    try writeMetricRow(bw, "Max. consec. winners", cw_all, cw_long, cw_short);
    
    const cl_all = try std.fmt.bufPrint(&val_buf[0], "{d}", .{metrics.all.max_consec_losses});
    const cl_long = try std.fmt.bufPrint(&val_buf[1], "{d}", .{metrics.long.max_consec_losses});
    const cl_short = try std.fmt.bufPrint(&val_buf[2], "{d}", .{metrics.short.max_consec_losses});
    try writeMetricRow(bw, "Max. consec. losers", cl_all, cl_long, cl_short);
    
    const lw_all = try std.fmt.bufPrint(&val_buf[0], "${d:.2}", .{metrics.all.largest_win});
    const lw_long = try std.fmt.bufPrint(&val_buf[1], "${d:.2}", .{metrics.long.largest_win});
    const lw_short = try std.fmt.bufPrint(&val_buf[2], "${d:.2}", .{metrics.short.largest_win});
    try writeMetricRow(bw, "Largest gain", lw_all, lw_long, lw_short);
    
    const ll_all = try std.fmt.bufPrint(&val_buf[0], "${d:.2}", .{metrics.all.largest_loss});
    const ll_long = try std.fmt.bufPrint(&val_buf[1], "${d:.2}", .{metrics.long.largest_loss});
    const ll_short = try std.fmt.bufPrint(&val_buf[2], "${d:.2}", .{metrics.short.largest_loss});
    try writeMetricRow(bw, "Largest loss", ll_all, ll_long, ll_short);
}

fn writePnLScatterData(bw: anytype, db: *c.sqlite3) !void {
    const query =
        \\SELECT p.position_id, p.side, p.open_timestamp, p.close_timestamp, 
        \\       p.avg_entry_price, p.volume
        \\FROM positions p
        \\WHERE p.close_timestamp IS NOT NULL
        \\ORDER BY p.close_timestamp;
    ;

    var stmt: ?*c.sqlite3_stmt = null;
    if (c.sqlite3_prepare_v2(db, query.ptr, -1, &stmt, null) != c.SQLITE_OK) {
        return error.PrepareStatementFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    var buf: [256]u8 = undefined;
    var trade_num: u32 = 1;
    var first = true;

    while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
        const side_str = c.sqlite3_column_text(stmt, 1);
        const close_ts = c.sqlite3_column_int64(stmt, 3);
        const entry_price = c.sqlite3_column_double(stmt, 4);
        const volume = c.sqlite3_column_double(stmt, 5);
        
        const exit_price = try getExitPrice(db, close_ts);
        const is_long = std.mem.eql(u8, std.mem.span(side_str), "Long");
        
        const pnl = if (is_long)
            exit_price - entry_price
        else
            entry_price - exit_price;
        
        if (!first) {
            _ = try bw.file.write(",\n");
        }
        first = false;
        
        const bubble_size = @max(5.0, @min(25.0, volume * 10)); // Ensure visible bubbles, scale 5-25
        const point = try std.fmt.bufPrint(&buf, "            {{ x: {d}, y: {d:.2}, r: {d:.1} }}", .{
            trade_num,
            pnl,
            bubble_size,
        });
        _ = try bw.file.write(point);
        
        trade_num += 1;
    }
}

fn writeReturnHistogram(bw: anytype, db: *c.sqlite3) !void {
    const query =
        \\SELECT p.side, p.open_timestamp, p.close_timestamp, 
        \\       p.avg_entry_price, p.volume
        \\FROM positions p
        \\WHERE p.close_timestamp IS NOT NULL
        \\ORDER BY p.close_timestamp;
    ;

    var stmt: ?*c.sqlite3_stmt = null;
    if (c.sqlite3_prepare_v2(db, query.ptr, -1, &stmt, null) != c.SQLITE_OK) {
        return error.PrepareStatementFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    // Define histogram bins
    const BinRange = struct {
        min: f64,
        max: f64,
        label: []const u8,
        count: u32 = 0,
    };
    
    var bins = [_]BinRange{
        .{ .min = -1000.0, .max = -50.0, .label = "<-$50" },
        .{ .min = -50.0, .max = -20.0, .label = "-$50 to -$20" },
        .{ .min = -20.0, .max = -5.0, .label = "-$20 to -$5" },
        .{ .min = -5.0, .max = 0.0, .label = "-$5 to $0" },
        .{ .min = 0.0, .max = 5.0, .label = "$0 to $5" },
        .{ .min = 5.0, .max = 20.0, .label = "$5 to $20" },
        .{ .min = 20.0, .max = 50.0, .label = "$20 to $50" },
        .{ .min = 50.0, .max = 1000.0, .label = ">$50" },
    };

    // Count P&L in each bin
    while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
        const side_str = c.sqlite3_column_text(stmt, 0);
        const close_ts = c.sqlite3_column_int64(stmt, 2);
        const entry_price = c.sqlite3_column_double(stmt, 3);
        
        const exit_price = try getExitPrice(db, close_ts);
        const is_long = std.mem.eql(u8, std.mem.span(side_str), "Long");
        
        const pnl = if (is_long)
            exit_price - entry_price
        else
            entry_price - exit_price;
        
        for (&bins) |*bin| {
            if (pnl >= bin.min and pnl < bin.max) {
                bin.count += 1;
                break;
            }
        }
    }

    // Write bins as JavaScript objects
    var buf: [256]u8 = undefined;
    var first = true;
    for (bins) |bin| {
        if (!first) {
            _ = try bw.file.write(",\n");
        }
        first = false;
        
        const color = if (bin.min >= 0) "#22c55e" else "#dc2626";
        const bin_obj = try std.fmt.bufPrint(&buf, 
            \\            {{ label: '{s}', count: {d}, color: '{s}' }}
        , .{ bin.label, bin.count, color });
        _ = try bw.file.write(bin_obj);
    }
}

fn writePositionRows(bw: anytype, db: *c.sqlite3) !void {
    const query =
        \\SELECT p.position_id, p.side, p.open_timestamp, p.close_timestamp, 
        \\       p.avg_entry_price, p.volume
        \\FROM positions p
        \\WHERE p.close_timestamp IS NOT NULL
        \\ORDER BY p.close_timestamp;
    ;

    var stmt: ?*c.sqlite3_stmt = null;
    if (c.sqlite3_prepare_v2(db, query.ptr, -1, &stmt, null) != c.SQLITE_OK) {
        return error.PrepareStatementFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    var buf: [512]u8 = undefined;
    var trade_num: u32 = 1;

    while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
        const side_str = c.sqlite3_column_text(stmt, 1);
        const open_ts = c.sqlite3_column_int64(stmt, 2);
        const close_ts = c.sqlite3_column_int64(stmt, 3);
        const entry_price = c.sqlite3_column_double(stmt, 4);
        const volume = c.sqlite3_column_double(stmt, 5);
        
        const exit_price = try getExitPrice(db, close_ts);
        const is_long = std.mem.eql(u8, std.mem.span(side_str), "Long");
        
        const pnl = if (is_long)
            exit_price - entry_price
        else
            entry_price - exit_price;
        
        const pnl_class = if (pnl >= 0) "pnl-positive" else "pnl-negative";
        const side_badge = if (is_long) "long" else "short";
        const side_text = if (is_long) "LONG" else "SHORT";
        
        const row = try std.fmt.bufPrint(&buf,
            \\                <tr>
            \\                    <td>{d}</td>
            \\                    <td><span class="badge {s}">{s}</span></td>
            \\                    <td>{d}</td>
            \\                    <td>{d}</td>
            \\                    <td>${d:.2}</td>
            \\                    <td>${d:.2}</td>
            \\                    <td>{d:.2}</td>
            \\                    <td class="{s}">${d:.2}</td>
            \\                </tr>
            \\
        , .{ trade_num, side_badge, side_text, open_ts, close_ts, entry_price, exit_price, volume, pnl_class, pnl });
        
        _ = try bw.file.write(row);
        trade_num += 1;
    }
}
