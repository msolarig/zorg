import subprocess as sp
import os

src_file_name = input("auto/: ")

auto_dir = f"usr/auto/{src_file_name}"
auto_file = f"{auto_dir}/auto.zig"

if not os.path.isfile(auto_file):
    print(f"ERROR: {auto_file} does not exist")
    exit(1)

cmd = [
  "zig", "build-lib",
  "-dynamic",
  "-O", "ReleaseSafe",
  "-fPIC",
  f"usr/auto/{src_file_name}/auto.zig",
  f"-femit-bin=zig-out/bin/auto/{src_file_name}.dylib",
]

sp.run(cmd)

print(f"Successfully Compiled Auto: zig-out/bin/auto/{src_file_name}.dylib")
