# Package

version = "0.1"
author = "james"
description = "Native debugger launcher for Android NDK projects, rewritten in Nim"
license = "LGPL-3.0"
srcDir = "src"
namedBin["ndkgdbpkg/main"] = "ndkgdb"
installExt = @["nim"]

# Dependencies

requires "nim >= 1.6.0"
