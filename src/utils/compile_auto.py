import subprocess as sp

src_file_name = input("auto/: ")

cmd = [
    "zig", "build-lib",
    "-dynamic",
    "-O", 
    "ReleaseSafe",
    "-fPIC",
    f"usr/auto/{src_file_name}/auto.zig",
    f"-femit-bin=zig-out/bin/auto/{src_file_name}.dylib",
]

sp.run(cmd)

print(f"Succesfully Compiled Auto: robert/zig-out/bin/auto/{src_file_name}.dylib")
