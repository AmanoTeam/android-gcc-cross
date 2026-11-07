import std/[os, osproc, strutils, options, strformat, sequtils, terminal]
import std/streams

import ./config
import ./exceptions
import ./types
import ./adb
import ./gdbrunner
import ./manifest

var verboseMode: bool = false
var ndkRoot: string = ""

proc log*(msg: string): void =
    if verboseMode:
        stdout.writeLine(&"INFO:ndkgdb: {msg}")

proc writeFatal*(msg: string, exitCode: int = 1): void {.noreturn.} =
    if stdout.isatty():
        stderr.styledWriteLine(fgRed, "ERROR: ", fgWhite, msg)
    else:
        stderr.writeLine(&"ERROR: {msg}")

    quit(exitCode)

proc writeStdout*(msg: string, exitCode: int = 0): void {.noreturn.} =
    stdout.writeLine(msg)
    quit(exitCode)

proc pyJoinPath(head: string, tail: string): string =
    if isAbsolute(tail):
        return tail

    result = joinPath(head, tail)

proc realpathSafe(path: string): string =
    try:
        result = expandFilename(path)
    except OSError:
        result = normalizedPath(absolutePath(path))

proc adviseApkDebugging(): void =
    stdout.writeLine("**Android Studio's debugger can be used for non-Studio projects.**")
    stdout.writeLine("See https://developer.android.com/studio/debug/apk-debugger")
    stdout.writeLine("")
    stdout.writeLine(
        "ndk-lldb is still usable for debugging command line Android tools or"
    )
    stdout.writeLine("ANT-based app builds, but it was never meant to handle other use")
    stdout.writeLine("cases. Android Studio can debug your APK even if Android Studio")
    stdout.writeLine("wasn't used to build the project, and this will be *much* easier")
    stdout.writeLine("than using ndk-lldb in most circumstances.")
    stdout.writeLine("")

proc pythonRepr*(arguments: openArray[string]): string =
    var parts: seq[string] = @[]

    for argument in arguments:
        parts.add("'" & argument.replace("\\", "\\\\").replace("'", "\\'") & "'")

    result = "[" & join(parts, ", ") & "]"

proc optionLike(token: string): bool =
    result = len(token) > 1 and token.startsWith("-")

proc looksLikeNegativeNumber(token: string): bool =
    if len(token) < 2 or token[0] != '-':
        return false

    try:
        discard parseFloat(token)
        result = true
    except ValueError:
        result = false

proc parseCommandLine*(args: Args): void =
    let params = commandLineParams()
    var index: int = 0

    proc valueFollows(): bool =
        if index + 1 >= len(params):
            return false

        let candidate = params[index + 1]

        result = candidate == "-" or
            looksLikeNegativeNumber(candidate) or
            not optionLike(candidate)

    proc takeValue(key: string, optional: bool = false): Option[string] =
        if valueFollows():
            index += 1
            return some(params[index])

        if optional:
            return none(string)

        writeFatal(&"argument {key}: expected one argument")

    proc valueFor(
        inlineValue: Option[string],
        key: string,
        optional: bool = false
    ): Option[string] =

        if inlineValue.isSome():
            return inlineValue

        result = takeValue(key, optional)

    while index < len(params):
        let token = params[index]

        if token.startsWith("--"):
            var key: string = token[2 .. ^1]
            var inlineValue: Option[string] = none(string)

            let equalsIndex = find(key, '=')
            if equalsIndex >= 0:
                inlineValue = some(key[equalsIndex + 1 .. ^1])
                key = key[0 ..< equalsIndex]

            case key
            of "help":
                writeStdout(helpMessage, exitCode = 0)
            of "version":
                writeStdout(versionInfo, exitCode = 0)
            of "verbose":
                args.verbose = true
            of "force":
                args.force = true
            of "port":
                let value = valueFor(inlineValue, "--port", optional = true)
                if value.isSome():
                    try:
                        args.port = parseInt(value.get())
                    except ValueError:
                        writeFatal(&"argument --port: invalid int value: '{value.get()}'")
            of "delay":
                let value = valueFor(inlineValue, "--delay")
                try:
                    args.delay = parseFloat(value.get())
                except ValueError:
                    writeFatal(&"argument --delay: invalid float value: '{value.get()}'")
            of "project":
                args.projectOption = valueFor(inlineValue, "--project")
            of "lldb":
                args.lldbOption = true
            of "no-lldb":
                args.noLldbOption = true
            of "attach":
                args.attachOption = true
                args.packageNameOption = valueFor(inlineValue, "--attach", optional = true)
            of "launch":
                let value = valueFor(inlineValue, "--launch", optional = true)
                if value.isNone():
                    args.launchMode = lmLaunchAuto
                else:
                    args.launchMode = lmLaunchActivity
                    args.launchActivity = value.get()
            of "launch-list":
                args.launchList = true
            of "exec":
                args.execFileOption = valueFor(inlineValue, "--exec")
            of "nowait":
                args.nowait = true
            of "tui":
                args.tui = true
            of "adb":
                args.adbPathOption = valueFor(inlineValue, "--adb")
            else:
                writeFatal(&"unrecognized argument: {token}")
        elif optionLike(token):
            var bundleIndex: int = 1

            while bundleIndex < len(token):
                let flag: char = token[bundleIndex]
                let rest: string = if bundleIndex + 1 < len(token):
                        token[bundleIndex + 1 .. ^1]
                    else:
                        ""

                case flag
                of 'a', 'd', 'e':
                    if args.deviceOption.isSome() or args.serialOption.isSome():
                        writeFatal(&"argument -{flag}: not allowed with other device arguments")
                    args.deviceOption = some($flag)
                of 'v':
                    args.verbose = true
                of 'f':
                    args.force = true
                of 'h':
                    writeStdout(helpMessage, exitCode = 0)
                of 't':
                    args.tui = true
                of 'p':
                    if rest.len > 0:
                        args.projectOption = some(rest)
                        bundleIndex = len(token)
                    else:
                        args.projectOption = takeValue("-p")
                of 'x':
                    if rest.len > 0:
                        args.execFileOption = some(rest)
                        bundleIndex = len(token)
                    else:
                        args.execFileOption = takeValue("-x")
                of 's':
                    if args.deviceOption.isSome() or args.serialOption.isSome():
                        writeFatal("argument -s: not allowed with other device arguments")
                    if rest.len > 0:
                        args.serialOption = some(rest)
                        bundleIndex = len(token)
                    else:
                        args.serialOption = takeValue("-s")
                else:
                    writeFatal(&"unrecognized argument: -{flag}")

                bundleIndex += 1
        else:
            writeFatal(&"unrecognized argument: {token}")

        index += 1

    if args.lldbOption and args.noLldbOption:
        writeFatal("argument --no-lldb: not allowed with argument --lldb")

    if args.attachOption and args.launchMode != lmAttach:
        writeFatal("argument --launch: not allowed with argument --attach")

proc findProgram(program: string, paths: seq[string]): Option[string] =
    var extensions: seq[string] = @[""]

    when defined(windows):
        extensions.add(@[".exe", ".bat", ".cmd"])

    for path in paths:
        if dirExists(path):
            for extension in extensions:
                let candidate = path & DirSep & program & extension
                if fileExists(candidate):
                    return some(candidate)

    result = none(string)

proc resolveDevice(args: Args): Option[AndroidDevice] =
    let adbPath = if args.adbPathOption.isSome(): args.adbPathOption.get() else: "adb"

    try:
        discard checkOutput(@[adbPath, "version"], mergeStderr = true)
    except OSError, CalledProcessError:
        var message = &"Unable to run adb executable (tried '{adbPath}')."
        if args.adbPathOption.isNone():
            message.add("\n       Try specifying its location with --adb.")
        writeFatal(message)

    try:
        if args.deviceOption.isSome():
            case args.deviceOption.get()
            of "-a":
                result = some(adb.getDevice(none(string), adbPath = adbPath))
            of "-d":
                result = some(adb.getDeviceByAdbFlag("-d", adbPath))
            of "-e":
                result = some(adb.getDeviceByAdbFlag("-e", adbPath))
            else:
                discard
        elif args.serialOption.isSome():
            result = some(adb.getDevice(some(args.serialOption.get()), adbPath = adbPath))
        else:
            result = some(adb.getDevice(none(string), adbPath = adbPath))
    except FindDeviceError:
        result = none(AndroidDevice)

proc handleArgs*(args: Args): Option[AndroidDevice] =
    ndkRoot = findNdkRoot()

    if ndkRoot.len == 0:
        writeFatal(
            "could not locate the Android NDK.\n" &
            "       Set ANDROID_NDK_ROOT, or place this binary in" &
            " <ndk>/prebuilt/<host-tag>/bin."
        )

    when defined(windows):
        if args.tui:
            writeFatal("TUI is unsupported on Windows.")

    let ndkBin = ndkBinDir(ndkRoot)
    let pathDirs = getEnv("PATH").replace("\"", "").split(PathSep)

    args.makeCmd = findProgram("make", @[ndkBin])
    args.jdbCmdOption = findProgram("jdb", pathDirs)

    if args.makeCmd.isNone():
        writeFatal(&"Failed to find make in '{ndkBin}'")

    if args.jdbCmdOption.isNone():
        stdout.writeLine("WARNING: Failed to find jdb on your path, defaulting to --nowait")
        args.nowait = true
        args.nowaitForced = true

    verboseMode = args.verbose

    result = resolveDevice(args)

proc findProject*(args: Args): string =
    const manifestName = "AndroidManifest.xml"

    if args.projectOption.isSome():
        log(&"Using project directory: {args.projectOption.get()}")
        let project = realpathSafe(absolutePath(expandTilde(args.projectOption.get())))
        if not fileExists(joinPath(project, manifestName)):
            writeFatal(&"could not find AndroidManifest.xml in '{project}'")
        args.project = project
        args.manifestPath = joinPath(project, manifestName)
        result = project
    else:
        var currentDir = getCurrentDir()
        while not fileExists(joinPath(currentDir, manifestName)):
            let parentDirectory = parentDir(currentDir)
            if parentDirectory == currentDir:
                writeFatal(
                    "Could not find AndroidManifest.xml in current directory or a" &
                    " parent directory.\n" &
                    "       Launch this script from inside a project, or use --project=<path>."
                )
            currentDir = parentDirectory
        log(&"Using project directory: {currentDir} ")
        args.project = currentDir
        args.manifestPath = joinPath(currentDir, manifestName)
        result = currentDir

proc parseManifest*(args: Args): void =
    let manifestRoot = parseManifestFile(args.manifestPath)
    let packageName = extractPackageName(manifestRoot)

    log(&"Found package name: {packageName}")

    let activities = extractLaunchable(manifestRoot).mapIt(
        canonicalizeActivity(packageName, it)
    )

    if args.launchList:
        writeStdout(&"Launchable activities: {join(activities, \", \")}", exitCode = 0)

    args.activities = activities
    args.packageName = packageName

proc selectTarget*(args: Args): string =
    if len(args.activities) == 0:
        writeFatal("No launchable activities found.")

    if args.launchMode == lmLaunchAuto:
        result = args.activities[0]

        if len(args.activities) > 1:
            stdout.writeLine(
                &"WARNING: Multiple launchable activities found, choosing '{args.activities[0]}'."
            )
    else:
        let activityName = canonicalizeActivity(args.packageName, args.launchActivity)

        if activityName notin args.activities:
            writeFatal(&"Could not find launchable activity: '{activityName}'.")

        result = activityName

proc dumpVar*(args: Args, variable: string, abi: Option[string] = none(string)): string =
    var makeArgs: seq[string] = @[
        args.makeCmd.get(),
        "--no-print-dir",
        "-f",
        joinPath(ndkRoot, "build/core/build-local.mk"),
        "-C",
        args.project,
        &"DUMP_{variable}"
    ]

    if abi.isSome():
        makeArgs.add(&"APP_ABI={abi.get()}")

    let previousDir = getCurrentDir()
    let previousPwd = getEnv("PWD")

    setCurrentDir(args.project)
    putEnv("PWD", args.project)

    var captured: tuple[output: string, errors: string, exitCode: int]

    try:
        captured = execCapture(makeArgs, workingDir = args.project, mergeStderr = false)
    finally:
        putEnv("PWD", previousPwd)
        setCurrentDir(previousDir)

    if captured.exitCode != 0 or captured.errors.len > 0:
        stderr.write(captured.errors)

    if captured.exitCode != 0:
        writeFatal("Failed to retrieve application ABI from Android.mk.")

    let lines = adb.splitLines(captured.output)

    if lines.len == 0:
        writeFatal("Failed to retrieve application ABI from Android.mk.")

    result = lines[^1]

proc getApiLevel*(device: AndroidDevice): int =
    let apiText = device.getProp("ro.build.version.sdk")

    if apiText.isNone():
        writeFatal(
            "Failed to find target device's supported API level.\n" &
            "ndk-gdb only supports devices running Android 2.2 or higher."
        )

    try:
        result = parseInt(apiText.get())
    except ValueError:
        writeFatal(
            "Failed to find target device's supported API level.\n" &
            "ndk-gdb only supports devices running Android 2.2 or higher."
        )

    if result < 8:
        writeFatal(
            &"ndk-gdb only supports devices running Android 2.2 or higher.\n" &
            &"(expected API level 8, actual: {result})"
        )

proc fetchAbi*(args: Args, device: AndroidDevice): string =
    var appAbis = split(dumpVar(args, "APP_ABI"), " ")

    if "all" in appAbis:
        appAbis = split(dumpVar(args, "NDK_ALL_ABIS"), " ")

    let appAbisMessage = &"Application ABIs: {join(appAbis, \", \")}"
    log(appAbisMessage)

    var abiProps: seq[string] = @["ro.product.cpu.abilist"]

    if device.getProp("ro.product.cpu.abilist").isNone():
        abiProps = @["ro.product.cpu.abi", "ro.product.cpu.abi2"]

    var deviceAbis: seq[string] = @[]

    for key in abiProps:
        let value = device.getProp(key)
        if value.isSome():
            deviceAbis.add(split(value.get(), ","))

    let deviceAbisMessage = &"Device ABIs: {join(deviceAbis, \", \")}"
    log(deviceAbisMessage)

    for abi in deviceAbis:
        if abi in appAbis:
            log(&"Selecting ABI: {abi}")
            return abi

    var message = "Application cannot run on the selected device."

    if not args.verbose:
        message.add(&"\n{appAbisMessage}\n{deviceAbisMessage}")

    writeFatal(message)

proc getAppDataDir*(device: AndroidDevice, packageName: string): string =
    let pwdResult = device.shellNocheck(
        @["run-as", packageName, "/system/bin/sh", "-c", "pwd", "2>/dev/null"]
    )

    if pwdResult.exitCode != 0:
        writeFatal(
            "Could not find application's data directory. Are you sure that " &
            "the application is installed and debuggable?"
        )

    result = pwdResult.output.strip()

    if getApiLevel(device) >= 24:
        let chmodResult = device.shellNocheck(
            @["run-as", packageName, "/system/bin/chmod", "a+x", result]
        )

        if chmodResult.exitCode != 0:
            writeFatal("Failed to make application data directory world executable")

    log(&"Found application data directory: {result}")

proc abiToArch(abi: string): string =
    if abi.startsWith("armeabi"):
        return "arm"
    if abi == "arm64-v8a":
        return "arm64"
    result = abi

proc abiToLlvmArch(abi: string): string =
    if abi.startsWith("armeabi"):
        return "arm"
    if abi == "arm64-v8a":
        return "aarch64"
    if abi == "x86":
        return "i386"
    result = "x86_64"

proc getLldbPath(toolchainPath: string): Option[string] =
    for lldbName in ["lldb.sh", "lldb.cmd", "lldb", "lldb.exe"]:
        let debuggerPath = joinPath(toolchainPath, "bin", lldbName)
        if fileExists(debuggerPath):
            return some(debuggerPath)

    result = none(string)

proc getLlvmPackageVersion(llvmToolchainDir: string): string =
    let versionFilePath = joinPath(llvmToolchainDir, "AndroidVersion.txt")

    try:
        result = adb.splitLines(readFile(versionFilePath))[0].strip()
    except IOError:
        writeFatal(&"Failed to open llvm package version file: '{versionFilePath}'.")

proc getLldbServerLocalPath(llvmToolchainDir: string, packageVersion: string, llvmArch: string): string =
    let majorVersion = packageVersion.split(".")[0]

    let candidates = @[
        joinPath(llvmToolchainDir, "lib64", "clang", packageVersion, "lib", "linux", llvmArch, "lldb-server"),
        joinPath(llvmToolchainDir, "lib", "clang", packageVersion, "lib", "linux", llvmArch, "lldb-server"),
        joinPath(llvmToolchainDir, "lib", "clang", majorVersion, "lib", "linux", llvmArch, "lldb-server"),
        joinPath(llvmToolchainDir, "lib64", "clang", majorVersion, "lib", "linux", llvmArch, "lldb-server")
    ]

    for candidate in candidates:
        if fileExists(candidate):
            return candidate

    result = candidates[0]

proc getDebuggerServerPath*(
    device: AndroidDevice,
    packageName: string,
    appDataDir: string,
    arch: string,
    serverName: string,
    localPath: string
): string =

    let appDebuggerServerPath = &"{appDataDir}/lib/{serverName}"

    let lsResult = device.shellNocheck(
        @["run-as", packageName, "ls", appDebuggerServerPath, "2>/dev/null"]
    )

    if lsResult.exitCode == 0:
        log(&"Found app {serverName}: {appDebuggerServerPath}")
        return appDebuggerServerPath

    log(&"App {serverName} not found at {appDebuggerServerPath}, uploading.")

    var remotePath = &"/data/local/tmp/{arch}-{serverName}"

    discard device.push(localPath, remotePath)

    if getApiLevel(device) >= 23:
        let destination = &"{appDataDir}/{arch}-{serverName}"
        log(&"Copying {serverName} to {destination}.")

        let copyResult = device.shellNocheck(
            @["cat", remotePath, "|", "run-as", packageName,
              "sh", "-c", &"'cat > {destination}'"]
        )

        if copyResult.exitCode != 0:
            writeFatal(&"Failed to copy {serverName} to {destination}.")

        let chmodResult = device.shellNocheck(
            @["run-as", packageName, "chmod", "700", destination]
        )

        if chmodResult.exitCode != 0:
            writeFatal(&"Failed to chmod {serverName} at {destination}.")

        remotePath = destination

    log(&"Uploaded {serverName} to {remotePath}")
    result = remotePath

proc pullBinaries*(device: AndroidDevice, outDir: string, app64bit: bool): void =
    let libraries = ["libc.so", "libm.so", "libdl.so"]
    let libraryPath = if app64bit: "/system/lib64" else: "/system/lib"

    var requiredFiles: seq[string] = @[]

    if app64bit:
        requiredFiles = @["/system/bin/app_process64", "/system/bin/linker64"]
    else:
        requiredFiles = @["/system/bin/linker"]

    for library in libraries:
        requiredFiles.add(&"{libraryPath}/{library}")

    for requiredFile in requiredFiles:
        let localPath = realpathSafe(outDir & requiredFile)
        let localDirname = parentDir(localPath)

        if not dirExists(localDirname):
            createDir(localDirname)

        log(&"Pulling '{requiredFile}' to '{localPath}'")
        discard device.pull(requiredFile, localPath)

    if not app64bit:
        let destination = realpathSafe(outDir & "/system/bin/app_process")
        try:
            discard device.pull("/system/bin/app_process32", destination)
        except CalledProcessError:
            discard device.pull("/system/bin/app_process", destination)

proc jdbReinvokeCommand(device: AndroidDevice, args: Args, pid: int): string =
    result = pythonRepr(@[
        getAppFilename(),
        "--internal-wakeup-pid-with-jdb",
        device.adbPath,
        device.serial,
        args.jdbCmdOption.get(""),
        $pid,
        if args.verbose: "True" else: "False"
    ])

proc generateLldbScript*(
    device: AndroidDevice,
    args: Args,
    sysroot: string,
    binaryPath: string,
    app64bit: bool,
    jdbPid: Option[int]
): string =

    var commands: seq[string] = @[]

    let libSuffix = if app64bit: "64" else: ""

    commands.add(
        &"settings append target.exec-search-paths {sysroot}/system/bin {sysroot}/system/lib{libSuffix}"
    )
    commands.add(&"target create '{binaryPath}'")
    commands.add(&"target modules search-paths add / {sysroot}/")
    commands.add(&"gdb-remote {args.port}")

    if jdbPid.isSome():
        commands.add("")
        commands.add(
            "script\n" &
            "def start_jdb_to_unblock_app():\n" &
            "  import subprocess\n" &
            &"  subprocess.Popen({jdbReinvokeCommand(device, args, jdbPid.get())})\n" &
            "\n" &
            "start_jdb_to_unblock_app()\n" &
            "exit()\n"
        )

    if args.tui:
        commands.add("gui")

    if args.execFileOption.isSome():
        var content: string
        try:
            content = readFile(args.execFileOption.get())
        except IOError:
            writeFatal(&"Failed to open lldb exec file: '{args.execFileOption.get()}'.")

        commands.add(content)

    result = join(commands, "\n")

proc generateGdbScript*(
    device: AndroidDevice,
    args: Args,
    sysroot: string,
    binaryPath: string,
    app64bit: bool,
    jdbPid: Option[int],
    connectTimeout: int = 5
): string =

    var scriptSysroot = sysroot
    var scriptBinaryPath = binaryPath

    when defined(windows):
        scriptSysroot = scriptSysroot.replace("\\", "/")
        scriptBinaryPath = scriptBinaryPath.replace("\\", "/")

    var gdbCommands: string = ""

    gdbCommands.add("set osabi GNU/Linux\n")
    gdbCommands.add(&"file '{scriptBinaryPath}'\n")

    var solibSearchPaths: seq[string] = @[scriptSysroot, &"{scriptSysroot}/system/bin"]

    if app64bit:
        solibSearchPaths.add(&"{scriptSysroot}/system/lib64")
    else:
        solibSearchPaths.add(&"{scriptSysroot}/system/lib")

    gdbCommands.add(&"set solib-absolute-prefix {scriptSysroot}\n")
    gdbCommands.add(&"set solib-search-path {join(solibSearchPaths, $PathSep)}\n")

    gdbCommands.add("\n" & join([
        "python",
        "",
        "def target_remote_with_retry(target, timeout_seconds):",
        "  import time",
        "  end_time = time.time() + timeout_seconds",
        "  while True:",
        "    try:",
        "      gdb.execute('target remote ' + target)",
        "      return True",
        "    except gdb.error as e:",
        "      time_left = end_time - time.time()",
        "      if time_left < 0 or time_left > timeout_seconds:",
        "        print(\"Error: unable to connect to device.\")",
        "        print(e)",
        "        return False",
        "      time.sleep(min(0.25, time_left))",
        "",
        &"target_remote_with_retry(':{args.port}', {connectTimeout})",
        "",
        "end",
        ""
    ], "\n"))

    if jdbPid.isSome():
        gdbCommands.add(
            "\npython\n" &
            "def start_jdb_to_unblock_app():\n" &
            "  import subprocess\n" &
            &"  subprocess.Popen({jdbReinvokeCommand(device, args, jdbPid.get())})\n" &
            "start_jdb_to_unblock_app()\n" &
            "end\n"
        )

    if args.execFileOption.isSome():
        var content: string
        try:
            content = readFile(args.execFileOption.get())
        except IOError:
            writeFatal(&"Failed to open GDB exec file: '{args.execFileOption.get()}'.")

        gdbCommands.add(content)

    result = gdbCommands

proc startJdb*(
    adbPath: string,
    serial: string,
    jdbCmd: string,
    pidText: string,
    verboseText: string
): void =

    let pid = parseInt(pidText)

    verboseMode = verboseText == "True"

    setControlCHook(proc(): void {.noconv.} = discard)

    log("Starting jdb to unblock application.")

    let device = adb.getDevice(
        serialOption = if serial.len > 0: some(serial) else: none(string),
        adbPath = adbPath
    )

    const jdbPort = 65534

    discard device.forward(&"tcp:{jdbPort}", &"jdwp:{pid}")

    let jdbProcess = startProcess(
        command = jdbCmd,
        args = ["-connect", &"com.sun.jdi.SocketAttach:hostname=localhost,port={jdbPort}"],
        options = {poUsePath, poStdErrToStdOut, poDaemon}
    )

    const jdbMagic = "__verify_jdb_has_started__"

    jdbProcess.inputStream.writeLine(&"print \"{jdbMagic}\"")
    jdbProcess.inputStream.flush()

    var sawMagicString = false
    var line: string = ""

    while readLine(jdbProcess.outputStream, line):
        log(&"jdb output: {line}")

        if jdbMagic in line and not sawMagicString:
            sawMagicString = true
            sleep(300)
            jdbProcess.inputStream.writeLine("exit")
            jdbProcess.inputStream.flush()

    discard jdbProcess.waitForExit()
    jdbProcess.close()

    if sawMagicString:
        log("JDB finished unblocking application.")
    else:
        log("error: did not find magic string in JDB output.")

proc main(): void =
    let params = commandLineParams()

    if len(params) >= 1 and params[0] == "--internal-wakeup-pid-with-jdb":
        if len(params) != 6:
            quit(1)

        startJdb(
            adbPath = params[1],
            serial = params[2],
            jdbCmd = params[3],
            pidText = params[4],
            verboseText = params[5]
        )

        return

    adviseApkDebugging()

    let args: Args = initArgs()

    parseCommandLine(args)

    let deviceOption: Option[AndroidDevice] = handleArgs(args)

    let useLldb = not args.noLldbOption

    if not useLldb:
        stdout.writeLine("WARNING: --no-lldb was used but GDB is no longer supported.")
        stdout.writeLine("GDB will be used, but will be removed in the next release.")

    if deviceOption.isNone():
        writeFatal("Could not find a unique connected device/emulator.")

    let device = deviceOption.get()

    let yamaCheck: ShellResult = device.shellNocheck(
        @["cat", "/proc/sys/kernel/yama/ptrace_scope", "2>/dev/null"]
    )

    if yamaCheck.exitCode == 0 and
            strip(yamaCheck.output, leading = false) notin ["", "0"] and
            device.getProp("ro.build.product").get("") == "dragon" and
            device.getProp("ro.product.name").get("") == "ryu":
        stdout.writeLine("WARNING: The device uses Yama ptrace_scope to restrict debugging. ndk-gdb will")
        stdout.writeLine("    likely be unable to attach to a process. With root access, the restriction")
        stdout.writeLine("    can be lifted by writing 0 to /proc/sys/kernel/yama/ptrace_scope. Consider")
        stdout.writeLine("    upgrading your Pixel C to MXC89L or newer, where Yama is disabled.")

    let adbVersionText = checkOutput(device.adbCmd & @["version"])

    log(&"ADB command used: '{join(device.adbCmd, \" \")}'")
    log(&"ADB version: {join(adb.splitLines(adbVersionText), \" \")}")

    discard findProject(args)

    if args.packageNameOption.isSome():
        args.packageName = args.packageNameOption.get()
        log(&"Attaching to specified package: {args.packageName}")
    else:
        parseManifest(args)

    var targetActivity: string = ""

    if args.launchMode == lmAttach:
        log("Attaching to existing application process.")
    else:
        targetActivity = selectTarget(args)
        log(&"Selected target activity: '{targetActivity}'")

    let abi = fetchAbi(args, device)
    let arch = abiToArch(abi)

    let outDir = realpathSafe(pyJoinPath(args.project, dumpVar(args, "TARGET_OUT", some(abi))))

    let appDataDir = getAppDataDir(device, args.packageName)

    let llvmToolchainDir = joinPath(ndkRoot, "toolchains", "llvm", "prebuilt", getLlvmHostName())

    let serverName = if useLldb: "lldb-server" else: "gdbserver"

    let serverLocalPath = if useLldb:
            getLldbServerLocalPath(
                llvmToolchainDir,
                getLlvmPackageVersion(llvmToolchainDir),
                abiToLlvmArch(abi)
            )
        else:
            &"{ndkRoot}/prebuilt/android-{arch}/gdbserver/gdbserver"

    if not fileExists(serverLocalPath):
        writeFatal(&"Can not find {serverName}: {serverLocalPath}")

    log(&"Using {serverName}: {serverLocalPath}")

    let debuggerServerPath = getDebuggerServerPath(
        device,
        args.packageName,
        appDataDir,
        arch,
        serverName,
        serverLocalPath
    )

    if args.force:
        var killPids = getPids(device, debuggerServerPath)

        if args.launchMode != lmAttach:
            killPids.add(getPids(device, args.packageName))

        if killPids.len > 0:
            let killPidsText = join(killPids.mapIt($it), ", ")
            log(&"Killing processes: {killPidsText}")
            discard device.shellNocheck(
                @["run-as", args.packageName, "kill", "-9"] & killPids.mapIt($it)
            )

    if args.launchMode != lmAttach:
        var amCmd: seq[string] = @["am", "start"]

        if not args.nowait:
            amCmd.add("-D")

        let componentName = &"{args.packageName}/{targetActivity}"
        amCmd.add(componentName)

        log(&"Launching activity {componentName}...")

        let launchResult = device.shellNocheck(amCmd)

        if launchResult.exitCode != 0:
            writeFatal(&"Failed to start {componentName}")

        if args.delay > 0.0:
            log(&"Sleeping for {args.delay} seconds.")
            sleep(int(args.delay * 1000.0))

    let pids = getPids(device, args.packageName)

    if len(pids) == 0:
        writeFatal(&"Failed to find running process '{args.packageName}'")

    if len(pids) > 1:
        writeFatal(&"Multiple running processes named '{args.packageName}'")

    let pid = pids[0]

    let app64bit = "64" in abi

    pullBinaries(device, outDir, app64bit)

    let zygotePath = if app64bit:
            joinPath(outDir, "system/bin/app_process64")
        else:
            joinPath(outDir, "system/bin/app_process")

    let debugSocket = &"{appDataDir}/debug_socket"

    log(&"Starting {serverName}...")

    discard startGdbserver(
        device = device,
        gdbserverLocalPath = none(string),
        gdbserverRemotePath = debuggerServerPath,
        targetPid = some(pid),
        runCmd = none(seq[string]),
        debugSocket = debugSocket,
        port = args.port,
        runAsCmd = @["run-as", args.packageName],
        lldb = useLldb
    )

    let jdbPid: Option[int] = if args.launchMode != lmAttach and not args.nowait:
            some(pid)
        else:
            none(int)

    var scriptCommands: string
    var debuggerPath: string
    var debuggerFlags: seq[string] = @[]

    if useLldb:
        scriptCommands = generateLldbScript(
            device, args, outDir, zygotePath, app64bit, jdbPid
        )

        let lldbPathOption = getLldbPath(llvmToolchainDir)

        if lldbPathOption.isNone():
            writeFatal(&"Failed to find lldb in '{joinPath(llvmToolchainDir, \"bin\")}'.")

        debuggerPath = lldbPathOption.get()
    else:
        scriptCommands = generateGdbScript(
            device, args, outDir, zygotePath, app64bit, jdbPid
        )
        debuggerPath = joinPath(ndkBinDir(ndkRoot), "gdb")

        if args.tui:
            debuggerFlags = @["--tui"]

    stdout.writeLine(debuggerPath)

    startGdb(
        gdbPath = debuggerPath,
        gdbCommands = scriptCommands,
        gdbFlags = debuggerFlags,
        lldb = useLldb
    )

when isMainModule:
    main()
