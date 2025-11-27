pub const Stdlib = struct {
    pub const std = @import("std");
};

pub const Assembly = struct {
    pub const Map = @import("assembly/map.zig").Map;
    pub const auto_loader = @import("assembly/auto_loader.zig");
    pub const LoadedAuto = auto_loader.LoadedAuto;
    pub const Track = @import("assembly/data.zig").Track;
    pub const Trail = @import("assembly/data.zig").Trail;
    pub const sql_wrap = @import("assembly/sql_wrap.zig");
};

pub const Execution = struct {
    pub const backtest = @import("execution/backtest.zig");
};

pub const Output = struct {
    pub const OutputManager = @import("output/output_manager.zig").OutputManager;
    pub const sqlite_writer = @import("output/sqlite_writer.zig");
    pub const logger = @import("output/logger.zig");
    pub const html_report = @import("output/html_report.zig");
    pub const result_builder = @import("output/result_builder.zig");
};

pub const ZDK = struct {
    pub const Account = @import("../zdk/core.zig").Account;
    pub const abi = @import("../zdk/abi.zig");
    pub const core = @import("../zdk/core.zig");
    pub const controller = @import("../zdk/controller.zig");
};

pub const ProjectUtils = struct {
    pub const path_util = @import("../utils/path_utility.zig");
};

