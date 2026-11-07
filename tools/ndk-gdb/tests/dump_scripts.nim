import std/[os, options]
import ../src/ndkgdbpkg/[types, config, exceptions, adb, gdbrunner]
import ../src/ndkgdbpkg/main

let args: Args = initArgs()
args.port = 5039
args.verbose = false
args.tui = false
args.execFileOption = none(string)
args.jdbCmdOption = some("/usr/bin/jdb")

let device = initAndroidDevice(serial = "emulator-5554", adbPath = "/fake/adb")

stdout.write("=== GDB SCRIPT ===")
stdout.write(generateGdbScript(device, args, "/tmp/sysroot", "/tmp/out/system/bin/app_process64", true, some(4242)))
stdout.write("=== LLDB SCRIPT ===")
stdout.writeLine(generateLldbScript(device, args, "/tmp/sysroot", "/tmp/out/system/bin/app_process64", true, some(4242)))
stdout.writeLine("=== GDB SCRIPT NOWAIT ===")
stdout.write(generateGdbScript(device, args, "/tmp/sysroot", "/tmp/out/system/bin/app_process", false, none(int), connectTimeout = 3))
stdout.write("=== LLDB SCRIPT NOWAIT ===")
stdout.writeLine(generateLldbScript(device, args, "/tmp/sysroot", "/tmp/out/system/bin/app_process", false, none(int)))

args.execFileOption = some("/tmp/opencode/sample_exec.gdb")
stdout.write("=== GDB SCRIPT EXEC ===")
stdout.write(generateGdbScript(device, args, "/tmp/sysroot", "/tmp/out/system/bin/app_process", false, none(int)))
stdout.write("=== LLDB SCRIPT EXEC ===")
stdout.writeLine(generateLldbScript(device, args, "/tmp/sysroot", "/tmp/out/system/bin/app_process", false, none(int)))
