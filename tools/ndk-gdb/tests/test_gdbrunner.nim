import std/[tables, options]
import ../src/ndkgdb

let output = """USER     PID   PPID  VSIZE  RSS     WCHAN    PC        NAME
root      1     0     9236   556   c02cb444 0806cd30 S /init
u0_a1     42    1     99999  999   00000000 b766f026 S com.example.application
u0_a1     43    1     99999  999   00000000 b766f026 S com.example.application
system 7   2    1234  12   0                 0 S some very long package name that exceeds busybox

u0_a1 99  1    99999 999  0                 0 S com.exampleisverylongtoolongbyfar.plasma"""

let processes = parsePsOutput(output)

doAssert processes["/init"] == @[1]
doAssert processes["com.example.application"] == @[43, 42]
doAssert processes["busybox"] == @[7]
doAssert processes["com.exampleisverylongtoolongbyfar.plasma"] == @[99]
doAssert processes.len == 4

doAssert processes.getOrDefault("com.example.application") == @[43, 42]
doAssert processes.getOrDefault("missing.entry") == @[]

let headerless = parsePsOutput("PID NAME\n3 four")
doAssert headerless["four"] == @[3]

echo "All gdbrunner tests passed"

doAssert extractRequestedInterpreter(
    "      [Requesting program interpreter: /system/bin/linker]\n"
).get() == "/system/bin/linker"

doAssert extractRequestedInterpreter("no interpreter here").isNone()

echo "All interp tests passed"
