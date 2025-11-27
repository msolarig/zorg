pub const Stdlib = struct {
    pub const std = @import("std");
    pub const builtin = @import("builtin");
};

pub const External = struct {
    pub const vaxis = @import("vaxis");
};

pub const Types = struct {
    const state_module = @import("state.zig");
    pub const State = state_module.State;
    pub const Entry = state_module.Entry;
    pub const EntryKind = state_module.EntryKind;
    pub const ExecutionResult = state_module.ExecutionResult;
    pub const LogEntry = state_module.LogEntry;
};

pub const Panes = struct {
    pub const Shared = struct {
        pub const border = @import("panes/shared/border.zig");
        pub const footer = @import("panes/shared/footer.zig");
        pub const prompt = @import("panes/shared/prompt.zig");
        pub const EventLog = @import("panes/shared/event_log.zig");
    };
    
    pub const WSMain = struct {
        pub const FileList = @import("panes/ws_main/file_list.zig");
        pub const FilePreview = @import("panes/ws_main/file_preview.zig");
        pub const BinTree = @import("panes/ws_main/bin_tree.zig");
    };
    
    pub const WSBt = struct {
        pub const Output = @import("panes/ws_bt/output.zig");
        pub const EngineSpecs = @import("panes/ws_bt/engine_specs.zig");
        pub const DatasetSample = @import("panes/ws_bt/dataset_sample.zig");
    };
};

pub const Engine = struct {
    pub const Engine = @import("../engine/engine.zig").Engine;
    pub const abi = @import("../zdk/abi.zig");
    pub const execution_result = @import("../engine/output/result_builder.zig");
    pub const Track = @import("../engine/assembly/data.zig").Track;
    pub const Trail = @import("../engine/assembly/data.zig").Trail;
    pub const sql_wrap = @import("../engine/assembly/sql_wrap.zig");
};

pub const ProjectUtils = struct {
    pub const path_util = @import("../utils/path_utility.zig");
};

pub const TUIUtils = struct {
    pub const tree_util = @import("utils/tree_util.zig");
    pub const syntax_util = @import("utils/syntax_util.zig");
    pub const render_util = @import("utils/render_util.zig");
    pub const format_util = @import("utils/format_util.zig");
    pub const path_util = @import("utils/path_util.zig");
    pub const auto_gen_util = @import("utils/auto_gen_util.zig");
};

