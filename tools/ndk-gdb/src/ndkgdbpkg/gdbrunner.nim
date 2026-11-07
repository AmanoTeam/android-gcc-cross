import std/[os, osproc, strutils, algorithm, tables, options, strformat, tempfiles, re, terminal, posix]
import std/exitprocs

import ./adb
import ./exceptions

const psScript: string =
    "if $(ls /system/bin/readlink >/dev/null 2>&1); then" &
    " if [ $(readlink /system/bin/ps) == \"busybox\" ]; then ps -w;" &
    " elif [ $(readlink /system/bin/ps) == \"toybox\" ]; then ps -A; else ps; fi" &
    " else ps; fi"

var pendingForwardRemovals: seq[tuple[device: AndroidDevice, local: string]] = @[]

proc removePendingForwards() {.noconv.} =
    for entry in pendingForwardRemovals:
        try:
            discard entry.device.forwardRemove(entry.local)
        except CatchableError:
            discard

exitprocs.addExitProc(removePendingForwards)

proc getUid*(device: AndroidDevice): int =
    let output = device.shell(@["id", "-u"]).output.strip()

    if len(output) > 0 and allCharsInSet(output, Digits + {'-'}):
        result = parseInt(output)
    else:
        let uidMatches = findAll(output, re"uid=([0-9]+)")
        if len(uidMatches) == 0:
            raise newException(ValueError, "Could not determine adbd uid from: " & output)
        result = parseInt(uidMatches[0][4 .. ^1])

proc forwardGdbserverPort*(device: AndroidDevice, local: int, remote: string): void =
    if getUid(device) != 0:
        let warningText = "Port forwarding may not work because adbd is not running" &
            " as root.  Run `adb root` to fix."

        if stdout.isatty():
            stdout.styledWriteLine(fgYellow, warningText)
        else:
            stdout.writeLine(warningText)

    discard device.forward(&"tcp:{local}", remote)
    pendingForwardRemovals.add((device, &"tcp:{local}"))

proc parsePsOutput*(output: string): Table[string, seq[int]] =
    let lines = adb.splitLines(output.replace("\r", ""))

    if lines.len == 0:
        return

    let header = lines[0].splitWhitespace()

    var pidColumn: int = 1

    for index, column in header:
        if column == "PID":
            pidColumn = index
            break

    for line in reversed(lines[1 .. ^1]):
        let columns = line.splitWhitespace()

        if columns.len == 0:
            continue

        let processName = columns[^1]
        let pid = parseInt(columns[pidColumn])

        if not result.hasKey(processName):
            result[processName] = @[]

        result[processName].add(pid)

proc getProcesses*(device: AndroidDevice): Table[string, seq[int]] =
    result = parsePsOutput(device.shell(@[psScript]).output)

proc getPids*(device: AndroidDevice, processName: string): seq[int] =
    result = getProcesses(device).getOrDefault(processName)

proc startGdbserver*(
    device: AndroidDevice,
    gdbserverLocalPath: Option[string] = none(string),
    gdbserverRemotePath: string,
    targetPid: Option[int] = none(int),
    runCmd: Option[seq[string]] = none(seq[string]),
    debugSocket: string,
    port: int,
    runAsCmd: seq[string] = @[],
    lldb: bool = false,
    chroot: string = "",
    cwd: string = ""
): Pid =

    doAssert not (targetPid.isSome() and runCmd.isSome())

    var runAsPrefix = runAsCmd

    if chroot.len > 0:
        if cwd.len > 0:
            raise newException(ValueError, "chroot and cwd cannot be set together")
        runAsPrefix = @["chroot", chroot] & runAsPrefix

    discard device.shellNocheck(runAsPrefix & @["rm", debugSocket])

    if gdbserverLocalPath.isSome():
        try:
            discard device.push(gdbserverLocalPath.get(), chroot & gdbserverRemotePath)
            discard device.shell(@["chmod", "+x", gdbserverRemotePath])
        except CalledProcessError as processError:
            stdout.writeLine("Command failed:")
            stdout.writeLine(quoteShellCommand(processError.cmd))
            stdout.writeLine("Output:")
            stdout.writeLine(processError.output)
            raise

    var gdbserverCmd: seq[string] = @[gdbserverRemotePath]

    if lldb:
        gdbserverCmd.add(@["gdbserver", &"unix://{debugSocket}"])
    else:
        gdbserverCmd.add(@["--once", &"+{debugSocket}"])

    if targetPid.isSome():
        gdbserverCmd.add(@["--attach", $targetPid.get()])
    else:
        gdbserverCmd.add("--")
        gdbserverCmd.add(runCmd.get())

    forwardGdbserverPort(
        device = device,
        local = port,
        remote = &"localfilesystem:{chroot}{debugSocket}"
    )

    gdbserverCmd = runAsPrefix & gdbserverCmd

    let logName = if lldb: "lldb-client.log" else: "gdbclient.log"
    let serverLabel = if lldb: "lldb-server" else: "gdbserver"

    let gdbserverOutputPath = getTempDir() / logName
    stdout.writeLine(&"Redirecting {serverLabel} output to {gdbserverOutputPath}")

    let logFile = open(gdbserverOutputPath, mode = fmWrite)
    defer:
        logFile.close()

    result = device.shellPopen(gdbserverCmd, logFile, cwd = cwd)

proc findFile*(
    device: AndroidDevice,
    executablePath: string,
    sysroot: string,
    runAsCmd: Option[seq[string]] = none(seq[string])
): tuple[path: string, foundLocally: bool] =

    if not isAbsolute(executablePath):
        raise newException(ValueError, &"'{executablePath}' is not an absolute path")

    if fileExists(sysroot & executablePath):
        return (sysroot & executablePath, true)

    var readlinkTarget: string = ""

    try:
        readlinkTarget = device.shell(@["readlink", "-e", "-n", executablePath]).output
    except ShellError:
        discard

    if fileExists(sysroot & readlinkTarget):
        return (sysroot & readlinkTarget, true)

    let fileName = &"gdbclient-binary-{getppid()}"
    let remoteTempPath = &"/data/local/tmp/{fileName}"
    let localPath = getTempDir() / fileName

    var copyCmd: seq[string] = @["cat", executablePath, ">", remoteTempPath]

    if runAsCmd.isSome():
        copyCmd = runAsCmd.get() & copyCmd

    try:
        discard device.shell(copyCmd)
    except ShellError:
        raise newException(
            CatchableError,
            &"Failed to copy '{executablePath}' to temporary folder on device"
        )

    discard device.pull(remoteTempPath, localPath)

    if fileExists(localPath):
        return (localPath, false)

    raise newException(CatchableError, &"Could not find executable {executablePath}")

proc findExecutablePath*(
    device: AndroidDevice,
    executableName: string,
    runAsCmd: Option[seq[string]] = none(seq[string])
): string =

    var cmd: seq[string] = @["which", executableName]

    if runAsCmd.isSome():
        cmd = runAsCmd.get() & cmd

    try:
        result = adb.splitLines(device.shell(cmd).output)[0]
    except ShellError:
        raise newException(
            CatchableError,
            &"Could not find executable '{executableName}' on device"
        )

proc findBinary*(
    device: AndroidDevice,
    pid: int,
    sysroot: string,
    runAsCmd: Option[seq[string]] = none(seq[string])
): tuple[path: string, foundLocally: bool] =

    result = findFile(device, &"/proc/{pid}/exe", sysroot, runAsCmd)

proc getBinaryArch*(binaryPath: string): string =
    var buffer: string = newString(0x14)

    try:
        let binaryFile = open(binaryPath, mode = fmRead)
        defer:
            binaryFile.close()
        if readBuffer(binaryFile, addr buffer[0], 0x14) != 0x14:
            raise newException(CatchableError, "failed to read binary file")
    except IOError, OSError:
        raise newException(CatchableError, "failed to read binary file")

    let eiClass = buffer[4].ord
    let eiData = buffer[5].ord

    if eiData != 1:
        raise newException(CatchableError, "binary isn't little-endian?")

    let eMachine = buffer[0x13].ord shl 8 or buffer[0x12].ord

    if eMachine == 0x28 and eiClass == 1:
        result = "arm"
    elif eMachine == 0xB7 and eiClass == 2:
        result = "arm64"
    elif eMachine == 0x03 and eiClass == 1:
        result = "x86"
    elif eMachine == 0x3E and eiClass == 2:
        result = "x86_64"
    elif eMachine == 0xF3 and eiClass == 2:
        result = "riscv64"
    else:
        raise newException(CatchableError, &"unknown architecture: 0x{eMachine:x}")

proc extractRequestedInterpreter*(output: string): Option[string] =
    let found = findAll(output, re"\[Requesting program interpreter: (.*?)\]")

    if len(found) == 0:
        return none(string)

    let text = found[0]
    result = some(text[33 ..< len(text) - 1])

proc getBinaryInterp*(binaryPath: string, llvmReadobjPath: string): Option[string] =
    let output = checkOutput(@[llvmReadobjPath, "--elf-output-style=GNU", "-l", binaryPath])

    result = extractRequestedInterpreter(output)

proc startGdb*(
    gdbPath: string,
    gdbCommands: string,
    gdbFlags: seq[string] = @[],
    lldb: bool = false
): void =

    let (scriptFile, scriptPath) = createTempFile(prefix = "ndkgdb-", suffix = ".gdb")
    write(scriptFile, gdbCommands)
    close(scriptFile)

    let scriptParameter = if lldb: "--source" else: "-x"

    var gdbArgs: seq[string] = @[gdbPath, scriptParameter, scriptPath]
    gdbArgs.add(gdbFlags)

    setControlCHook(proc(): void {.noconv.} = discard)

    let process = startProcess(
        command = gdbArgs[0],
        args = gdbArgs[1 .. ^1],
        options = {poUsePath, poParentStreams}
    )

    discard process.waitForExit()
    process.close()

    try:
        removeFile(scriptPath)
    except OSError:
        discard
