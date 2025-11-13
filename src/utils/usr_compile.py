import subprocess as sp

src_file_name = input("src: ")
bin_file_name = input("bin: ")

cmd = [
    "zig", "build-lib",
    "-dynamic",
    "-O", 
    "ReleaseSafe",
    "-fPIC",
    f"usr/autos/{src_file_name}",
    f"-femit-bin=zig-out/bin/usr/autos/{bin_file_name}",
]

sp.run(cmd)
