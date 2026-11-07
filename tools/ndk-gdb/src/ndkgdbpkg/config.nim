import std/[os, strformat, strutils]

const
    NDKGDB_VERSION*: string = "0.1"
    DEFAULT_CONNECT_TIMEOUT*: int = 5
    helpMessage*: string = staticRead(filename = "../../external/help_message.txt").strip()
    versionInfo*: string = &"ndkgdb v{NDKGDB_VERSION} (ndk-gdb port)" &
        "\n" &
        &"Compiled for {hostOS} ({hostCPU}) using Nim {NimVersion} " &
        &"({CompileDate}, {CompileTime})"

proc getLlvmHostName*(): string =
    when defined(windows):
        result = "windows-x86_64"
    elif defined(macosx):
        result = "darwin-x86_64"
    else:
        result = "linux-x86_64"

proc fileExistsAtNdkRoot*(candidate: string): bool =
    result = fileExists(candidate / "build/core/build-local.mk")

proc findNdkRoot*(): string =
    if existsEnv("ANDROID_NDK_ROOT"):
        let candidate: string = getEnv("ANDROID_NDK_ROOT")
        if fileExistsAtNdkRoot(candidate):
            return candidate

    let exeRelative: string = getAppDir() / "../../.."
    if fileExistsAtNdkRoot(exeRelative):
        return expandFilename(exeRelative)

    result = ""

proc ndkBinDir*(ndkRoot: string): string =
    result = ndkRoot / "prebuilt" / getLlvmHostName() / "bin"
