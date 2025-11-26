<div align="center">

# *Zorg*
![Static Badge](https://img.shields.io/badge/Zig-0.15.2-orange)
![Static Badge](https://img.shields.io/badge/Python-3.13-blue) 
![Static Badge](https://img.shields.io/badge/Support_For_macOS-26-purple)

</div>

(Zorg & ZDK v1.0.0 in active development)

A blazing fast, modular environment for designing, testing, and executing algorithmic trading models in Zig. Zorg provides a complete development environment where users have full control over every process through a unified interface and configuration system.

## Features

- **Engine-Map System**: Configure complete trading engines through a single JSON configuration file
- **Zorg Development Kit (ZDK)**: Build algorithms with Zig's speed and memory safety
- **Terminal User Interface**: Interactive TUI for managing autos, maps, and execution
- **Backtest Execution**: Full backtesting engine with CSV output for orders, fills, and positions
- **SQLite3 Data Feed**: Load historical market data from SQLite databases
- **Self-Contained Autos**: Each algorithm is an independent, compilable module

## Quick Start

### Installation

Zorg can be installed via Homebrew (coming soon) or built from source:

```bash
zig build
```

This creates the `zorg` executable in `zig-out/bin/`.

### Running Zorg

Simply run:

```bash
zorg
```

This launches the Terminal User Interface (TUI), which is the primary interface for all Zorg operations.

[SCREENSHOT: TUI interface showing workspace 1]

### Creating Your First Auto

From within the TUI, use the command prompt (press `:` to enter command mode) and type:

```
:touch -auto my_strategy
```

This will:
1. Create `usr/auto/my_strategy/` directory
2. Copy a template file to `auto.zig`
3. Copy the current ZDK to `zdk.zig` (snapshot)

The auto source files are created but not compiled. Compilation happens automatically when the engine loads the auto, or can be done manually using Zig's build-lib command.

[SCREENSHOT: Auto creation process in TUI]

## The Engine Map

The Engine Map is a JSON configuration file that defines how to assemble a complete trading engine. It specifies the algorithm, data source, execution mode, and all runtime parameters.

Create a map file in `usr/map/` with the following structure:

```jsonc
{
  "ENGINE_EXECUTION_MODE": "Backtest",
  "ENGINE_AUTO_TO_ATTACH": "my_strategy",
  "ENGINE_DATA_FEED_MODE": "SQLite3",
  "ENGINE_DB_FILE_NAME": "market.db",
  "ENGINE_DB_TABLE_NAME": "AJG_1D",
  "ENGINE_TIMESTAMP_0": 0,
  "ENGINE_TIMESTAMP_n": 2000000000,
  "ENGINE_TRAIL_LENGTH": 10,
  "ENGINE_ACCOUNT_CONFIG": {
    "balance": 10000.0
  },
  "ENGINE_OUTPUT_CONFIG": {
    "OUTPUT_DIR_NAME": "my_backtest"
  }
}
```

Zorg automatically resolves paths relative to the `usr/` directory structure. Simply place your files in the appropriate subdirectories:

- `usr/auto/` - Your trading algorithms
- `usr/data/` - SQLite database files
- `usr/map/` - Engine map configurations
- `usr/out/` - Execution output (CSV files)

[SCREENSHOT: Engine map configuration view in TUI]

## Self-Contained Algorithms

Each auto (algorithm) is a self-contained Zig project that compiles to a dynamic library. The structure is simple and modular:

```
usr/auto/my_strategy/
│
├─ auto.zig          # Entry point - your trading logic
├─ zdk.zig           # ZDK snapshot (copied at creation)
│
├─ ind/              # Optional: Custom indicators
│   ├─ vwap.zig
│   └─ moving_average.zig
│
├─ sup/              # Optional: Supporting functions
│   ├─ risk_calculator.zig
│   └─ position_sizer.zig
│
└─ dep/              # Optional: External dependencies
    └─ custom_lib.zig
```

### Writing Your Auto

The `auto.zig` file contains your trading strategy. Here's the basic structure:

```zig
const zdk = @import("zdk.zig");

const NAME: [*:0]const u8 = "My Strategy";
const DESC: [*:0]const u8 = "Strategy description";

fn logic(input: *const zdk.Input.Packet, output: *zdk.Output.Packet) callconv(.c) void {
    // Access market data
    const current_close = input.trail.cl[0];
    const previous_close = input.trail.cl[1];
    
    // Access account information
    const balance = input.account.balance;
    const exposure = input.exposure.*;
    
    // Implement your trading logic
    if (current_close > previous_close) {
        zdk.Order.buyMarket(input, output, 10.0);
    }
}

fn deinit() callconv(.c) void {
    // Cleanup if needed
}

var abi = zdk.ABI{
    .version = zdk.VERSION,
    .name = NAME,
    .desc = DESC,
    .logic = logic,
    .deinit = deinit,
};

export fn getABI() callconv(.c) *const zdk.ABI {
    return &abi;
}
```

### Available Order Functions

The ZDK provides helper functions for order submission:

- `zdk.Order.buyMarket(input, output, volume)` - Market buy order
- `zdk.Order.sellMarket(input, output, volume)` - Market sell order
- `zdk.Order.buyLimit(input, output, price, volume)` - Limit buy order
- `zdk.Order.sellLimit(input, output, price, volume)` - Limit sell order
- `zdk.Order.buyStop(input, output, price, volume)` - Stop buy order
- `zdk.Order.sellStop(input, output, price, volume)` - Stop sell order

Note: Currently, only Market orders are fully implemented. Limit and Stop orders are accepted but not yet executed in the backtest engine.

### Compiling Your Auto

After editing your auto, recompile it from the TUI. Navigate to the auto directory and use the build command, or re-run the create-auto command which will recompile if the directory already exists.

## ZDK Organization

The Zorg Development Kit (ZDK) is organized as a single source of truth:

- **Source**: `zdk/zdk.zig` - The one file that defines the ZDK API
- **Engine Integration**: Engine always uses the latest `zdk/zdk.zig` directly
- **Auto Integration**: Each auto gets a snapshot copy of `zdk/zdk.zig` at creation time

This design ensures:
- Engine always has the latest ZDK features
- Autos are self-contained and version-stable
- No version conflicts between engine and autos
- Simple update process: edit `zdk/zdk.zig` and rebuild engine

When you update `zdk/zdk.zig`, the engine automatically uses the new version. Existing autos continue to work with their snapshot copies. To update an auto to use the latest ZDK, manually copy `zdk/zdk.zig` to the auto's directory and recompile.

## Terminal User Interface

Zorg's TUI is the primary interface for all operations. Launch it by running `zorg` from the terminal.

### Workspace 1: File Browser

The file browser provides navigation through your `usr/` directory structure:
- Browse autos, maps, data files, and output directories
- Preview file contents with syntax highlighting
- View binary tree structure
- Event log for system messages

[SCREENSHOT: File browser interface]

### Workspace 2: Backtest Execution

The execution workspace provides:
- Engine map configuration view
- Assembly status and engine details
- Real-time execution progress
- Output file locations (orders, fills, positions CSV)

[SCREENSHOT: Execution workspace]

### TUI Commands

All operations are performed through the TUI command prompt (press `:` to enter command mode):

- `:touch -auto <name>` - Create a new trading algorithm
- `:touch <filename>` - Create a new file
- `:assemble <map_file>` - Assemble an engine from a map file
- `:engine run` - Execute the assembled engine
- `:mkdir <dirname>` - Create a new directory
- `:rename <old> <new>` - Rename a file or directory
- `:rm <filename>` - Delete a file or directory
- `:mv <source> <dest>` - Move or rename files

### Navigation

- Switch workspaces: `1` or `2`
- Navigate files: Arrow keys or `j`/`k`
- Enter directory: `Enter`
- Go up: `Backspace` or `h`
- Enter command mode: `:`
- Quit: `q`

## Execution Modes

### Backtest (Implemented)

Full backtesting with historical data:
- Loads data from SQLite database
- Executes strategy logic on each data point
- Generates CSV outputs for analysis
- Tracks orders, fills, and positions

Output files are written to `usr/out/{OUTPUT_DIR_NAME}/`:
- `orders.csv` - All placed orders
- `fills.csv` - All executed fills
- `positions.csv` - Position history

[SCREENSHOT: Backtest execution results]

### Live Execution (Planned)

Live trading execution with real-time data feeds. Not yet implemented.

### Optimization (Planned)

Parameter optimization and strategy testing. Not yet implemented.

## Project Structure

```
zorg/
├── src/
│   ├── engine/          # Engine core (assembly, execution)
│   ├── tui/             # Terminal user interface
│   ├── zdk/             # ZDK engine implementation
│   ├── utils/           # Utilities (path resolution, auto creation)
│   └── tests/           # Test suite
├── zdk/
│   └── zdk.zig          # ZDK API (single source of truth)
├── templates/
│   └── basic_auto.zig   # Auto creation template
├── usr/                 # User workspace
│   ├── auto/            # Trading algorithms
│   ├── data/            # Market data databases
│   ├── map/             # Engine maps
│   └── out/             # Execution outputs
└── build.zig            # Build configuration
```

## Development Status

### Implemented Features

- Engine assembly from map files
- SQLite3 data loading
- Backtest execution
- Market order execution
- CSV output generation
- Terminal user interface
- Auto creation tool
- ZDK single-source organization

### Planned Features

- Limit and Stop order execution
- Order cancellation
- Live execution mode
- Optimization mode
- Live data feed integration

## Building and Testing

### Build Commands

```bash
# Build main executable
zig build

# Build and run (launches TUI)
zig build run

# Run tests
zig build test
```

### Requirements

- Zig 0.15.2 or later
- SQLite3 development libraries
- macOS 26+ (current support)

### Installation via Homebrew

Once available, Zorg can be installed via Homebrew:

```bash
brew install zorg
```

After installation, simply run `zorg` from any terminal to launch the TUI.

## License

This project is licensed under the terms of the GNU General Public License v3.0

## Contribution

If you are interested in this project, please take a look at the source code and feel free to suggest ideas, fork and submit pull requests.
