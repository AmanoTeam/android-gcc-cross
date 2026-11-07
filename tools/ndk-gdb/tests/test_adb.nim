import std/strutils
import ../src/ndkgdb

doAssert adb.splitLines("a\r\nb\nc\r\r\n") == @["a", "b", "c"]
doAssert adb.splitLines("  x  \n\n") == @["  x"]
doAssert adb.splitLines("no newlines") == @["no newlines"]
doAssert adb.splitLines("") == @[""]
doAssert adb.splitLines(" \r\n \r\n ") == @[""]
doAssert adb.splitLines("\n") == @[""]

doAssert parseShellOutput("hello\nx0\n") == (0, "hello\n")
doAssert parseShellOutput("x255\r\r\n") == (255, "")

var parsed = parseShellOutput("plugdev\nx1\r\n")
doAssert parsed.exitCode == 1
doAssert parsed.output == "plugdev\n"

parsed = parseShellOutput(repeat("storm" & "x", 400) & "\nx9\n")
doAssert parsed.exitCode == 9
doAssert parsed.output.endsWith("\n")

try:
    discard parseShellOutput("no delimiter here")
    doAssert false
except ValueError:
    discard

echo "All adb tests passed"
