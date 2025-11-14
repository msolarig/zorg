# *ROBERT*

![Static Badge](https://img.shields.io/badge/Zig-0.15.2-orange)
![Static Badge](https://img.shields.io/badge/Python-3.13-blue)


## All in One Config

Specify every aspect of your custom process into a single JSON file. From input paths to execution modes
and output type (Soon).

![Alt text](/assets/readme/screenshots/ss_map.png?raw=true "ss_map")

## Fast Algorithms

ROBERT's Autos allow the use of a fast set of functions and tools to build performing, self-contained 
market execution algorithms. Here is a common template in the current (early) dev stage.

```zig

const std = @import("std");
const abi = @import("abi.zig");

/// Auto Export Function
///   Provides ROBERT with an interface to access the compiled AUTO.
///   Update name & description. Do not modify ABI struct insance declaration. 
pub export fn getAutoABI() callconv(.c) *const abi.AutoABI {
  const NAME: [*:0]const u8 = "TEST_AUTO";
  const DESC: [*:0]const u8 = "TEST_AUTO_DESCRIPTION";

  const ABI = abi.AutoABI{
    .name = NAME,
    .desc = DESC,
    .logic_function = autoLogicFunction,
    .deinit = deinit,
  };
  return &ABI;
}

// Custom Auto variables & methods ------------------------
const minimum_required_data_points: u64 = 2;
// --------------------------------------------------------

/// Execution Function
///   Called once per update in data feed.
fn autoLogicFunction(iter_index: u64, trail: *const abi.TrailABI) callconv(.c) void {
  // Basic auto logic
  if (iter_index >= minimum_required_data_points) {
    if (trail.op[0] < trail.op[1] and trail.cl[0] > trail.cl[1] and trail.cl[1] < trail.op[0])
      std.debug.print("  SAMPLE AUTO LOG: {d:03}|{d}: BUY @ {d:.2}\n", .{iter_index, trail.ts[0], trail.cl[0]});
      return;
  }
} 

/// Deinitialization Function
///  Called once by the engine at the end of the process. 
///  Include any allocated variables inside to avoid memory leak errors.
fn deinit() callconv(.c) void {
  //std.debug.print("Auto Deinitialized\n", .{});
  return;
}

```

## Compile Autos

Through a custom ABI and with the help of a custom python utility, you can compile you auto projects 
independent from the main program by simply typing the auto dir name.

![Alt text](/assets/readme/screenshots/ss_autocomp.png?raw=true "ss_autocomp")

## Simple Interface

Just provide a map (config file) and the engine will assemble itself! loading into memory the desired auto, 
database, and required configs to run a custom process.

![Alt text](/assets/readme/screenshots/ss_tui.png?raw=true "ss_tui")

## Contributions

if you are interested in this project, take a look at the source code and feel free to suggest ideas, fork and PR.

## License

This project is licensed under the terms of the GNU General Public Licens v3.0
