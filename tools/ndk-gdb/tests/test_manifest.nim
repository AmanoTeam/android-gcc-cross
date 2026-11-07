import std/sequtils
import std/os
import ../src/ndkgdb

let root = parseManifestFile(currentSourcePath().parentDir / "fixtures/AndroidManifest.xml")

doAssert extractPackageName(root) == "com.example.ndkgdbtest"

let launchable = extractLaunchable(root)

doAssert launchable == @[".MainActivity", "com.example.ndkgdbtest.OtherActivity"]

let canonicalized = launchable.mapIt(canonicalizeActivity("com.example.ndkgdbtest", it))

doAssert canonicalized == @[
    "com.example.ndkgdbtest.MainActivity",
    "com.example.ndkgdbtest.OtherActivity"
]

doAssert canonicalizeActivity("com.example.ndkgdbtest", ".MainActivity") ==
    "com.example.ndkgdbtest.MainActivity"

doAssert canonicalizeActivity(
    "com.example.ndkgdbtest",
    "com.otherpkg.Activity"
) == "com.otherpkg.Activity"

echo "All manifest tests passed"
