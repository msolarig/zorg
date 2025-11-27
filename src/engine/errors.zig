const std = @import("std");

/// Engine-wide error definitions for better error handling and diagnostics
pub const EngineError = error{
    // Assembly errors
    MapFileNotFound,
    MapFileInvalid,
    MapFieldMissing,
    AutoLibraryNotFound,
    AutoLibraryInvalid,
    AutoABIMissing,
    AutoABIInvalid,
    DataFileNotFound,
    DataFileInvalid,
    DataEmpty,
    DatabaseOpenFailed,
    DatabaseQueryFailed,
    InvalidDataFormat,
    InsufficientData,
    
    // Execution errors
    ExecutionSetupFailed,
    ARFInitFailed,
    ARFAllocationFailed,
    AutoLogicFailed,
    OrderPlacementFailed,
    OrderCancellationFailed,
    OrderModificationFailed,
    PositionUpdateFailed,
    FillExecutionFailed,
    
    // Output errors
    OutputDirectoryCreation,
    DatabaseWriteFailed,
    LogWriteFailed,
    ReportGenerationFailed,
    FileWriteFailed,
    
    // Data validation errors
    InvalidPrice,
    InvalidVolume,
    InvalidTimestamp,
    InvalidOrderID,
    InvalidOrderType,
    InvalidSide,
    
    // Resource errors
    OutOfMemory,
    AllocationFailed,
    DeallocationFailed,
    
    // Configuration errors
    InvalidConfiguration,
    MissingRequiredField,
    InvalidFieldValue,
};

/// Convert standard library errors to EngineError where appropriate
pub fn mapStdError(err: anyerror) EngineError {
    return switch (err) {
        error.OutOfMemory => EngineError.OutOfMemory,
        error.FileNotFound => EngineError.MapFileNotFound,
        error.AccessDenied => EngineError.FileWriteFailed,
        error.IsDir => EngineError.MapFileInvalid,
        else => EngineError.InvalidConfiguration,
    };
}

/// Format error with context for user-friendly messages
pub fn formatError(err: EngineError, context: []const u8, writer: anytype) !void {
    try writer.print("Error: {s}\n", .{@errorName(err)});
    if (context.len > 0) {
        try writer.print("Context: {s}\n", .{context});
    }
    
    // Provide helpful hints
    const hint = switch (err) {
        .MapFileNotFound => "Ensure the map file exists in usr/map/",
        .MapFileInvalid => "Check map file JSON syntax and required fields",
        .AutoLibraryNotFound => "Run 'zig build' to compile autos",
        .DataFileNotFound => "Verify database path in map file",
        .DataEmpty => "Database contains no data points",
        .InvalidPrice => "Price must be positive and finite",
        .InvalidVolume => "Volume must be positive",
        .OutputDirectoryCreation => "Check write permissions for output directory",
        else => "Check logs for more details",
    };
    try writer.print("Hint: {s}\n", .{hint});
}

test "error mapping" {
    const mapped = mapStdError(error.OutOfMemory);
    try std.testing.expectEqual(EngineError.OutOfMemory, mapped);
}

