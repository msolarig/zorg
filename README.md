<div align="center">

# *Zorg*

</div>

![Static Badge](https://img.shields.io/badge/Zig-0.15.2-orange)
![Static Badge](https://img.shields.io/badge/Python-3.13-blue) 
![Static Badge](https://img.shields.io/badge/Support_For_macOS-26-purple)

(Zorg & ZDK v1.0.0 in active development)

A blazing fast, modular environment for designing, testing, and executing algorithmic trading models (in Zig!). Zorg brings a different approach to the space of financial development environments, one in which the user has full control of every process, all from one file!

Features:
  - Design custom Engines with the specialized Engine-Map system.
  - Build algorithms with the Zorg Development Kit (ZDK), leveraging Zig's speed and control
  - Save input databases or connect a to a live API (soon)

With Zorg, all you need to do is pass one file, a single Engine-Map.json containing the adress to your auto (algorithm) and database, alongside all the settings you require in order to assemble your custom ready-to-work Engine.

![Alt text](/assets/readme/gifs/interface.gif?raw=true "Interface Gif")

## The Engine Map

All you need to do is pass one file, a single Engine-Map.json containing the adress to your auto and database, alongside all the settings you require in order to assemble your custom ready-to-work Engine.

Sample Engine-Map.json:

```jsonc
{
  "auto": "test_auto",          // Auto address (usr/auto/)
  "feed_mode": "SQLite3",       // Database? Live?
  "db": "market.db",            // DB address (usr/data/)
  "table": "AJG_1D",            // Table name (usr/data/DB.db/)
  "t0": 0,                      // First data point to load
  "tn": 2000000000,             // Last data point to load
  "trail_size": 10,             // Auto Look-Back-Period
  "exec_mode": "Backtest"       // Backest? Optimize? Route?
}
```
Zorg will read this file and assemble a full-on engine, with direct connection to the specified inputs and configurations. Do not worry about paths! He knows where your files are, just make sure to drop them on the usr/ directory, in their respective groups.

## Self Contained Algorithms

With ROBlang and a custom C ABI, each auto is its own small project with a an entry point, an abi key matching the engine's, and support for any helper indicators, scripts, and any other extra dependencies.

```
ANY_GIVEN_AUTO/
│
├─ auto.zig                     Entry Point 
├─ abi.zig                      ABI - Engine Key!
│
├─ ind/                         Self Contained Indicators
│   ├─ vwap.zig
│   ├─ ts.zig
│   └─ ...
│
├─ sup/                         Supporting Functions 
│   ├─ calc_risk.zig
│   └─ ...
├─ dep/                         Extra dependencies
    ├─ fun_interpreter.zig
    └─ ...
```
Once you have a working auto, you can compile it independently. Just call the custom compiler utility.

```zsh
python3 src/utils/compile_auto.py
```
Ready! the usr/auto/AUTO will be compiled automatically. The best part is, you only need to pass the name of the auto dir/ and he will know where to find the compiled binary when assembling a new Engine. 

## Simple Interface

For now, Zorg has a straightforward, script like ui. Simply answer the prompt with a map.json and the engine will be assembled automatically and provide some details. 

Here is an example with a basic auto that prints to the screen when it finds a specific pattern in the data:

```zsh
┌─────────────────────────────────────────────────────────────┐
│ Zorg 
└─────────────────────────────────────────────────────────────┘
  ENGINE MAP › map.json  <- ONLY USER INPUT

  ENGINE ASSEMBLED | 219ms |
    exec: .Backtest
    auto: /zorg/zig-out/bin/auto/test_auto.dylib
    feed: /zorg/usr/data/market.db

  EXECUTING PROCESS…
  LONG INITIATED @ iter 090 | close=247.71
  LONG INITIATED @ iter 135 | close=269.12
  LONG INITIATED @ iter 142 | close=280.74
  LONG INITIATED @ iter 144 | close=282.14
  LONG INITIATED @ iter 182 | close=279.77
  LONG INITIATED @ iter 191 | close=287.30
  DONE
```

## Contribution

if you are interested in this project, please take a look at the source code and feel free to suggest ideas, fork and PR.

## License

This project is licensed under the terms of the GNU General Public Licens v3.0
