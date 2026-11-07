import std/strutils except splitLines
import std/[os, osproc, options, strformat, re, posix]
import std/streams
import std/exitprocs

import ./exceptions
import ./types

const
    returnCodeDelimiter*: string = "x"
    returnCodeProbe*: seq[string] = @[";", "echo", "x$?"]
    returnCodeSearchLength: int = len("x255\r\r\n")

var processesToKill: seq[Pid] = @[]

proc rawExit(code: cint) {.importc: "_exit", header: "<unistd.h>".}

proc stdioFileDescriptor(file: File): cint {.importc: "fileno", header: "<stdio.h>".}

proc killSpawnedProcesses() {.noconv.} =
    for pid in processesToKill:
        try:
            discard posix.kill(pid, posix.SIGKILL)
        except OSError:
            discard

exitprocs.addExitProc(killSpawnedProcesses)

proc splitLines*(s: string): seq[string] =
    let text = s.strip(leading = false, trailing = true)

    if text.len == 0:
        return @[""]

    result = split(text, re"[\r\n]+")

proc execCapture*(
    cmd: seq[string],
    workingDir: string = "",
    mergeStderr: bool = true
): tuple[output: string, errors: string, exitCode: int] =

    var processOptions = {poUsePath}

    if mergeStderr:
        processOptions.incl(poStdErrToStdOut)

    let process = startProcess(
        command = cmd[0],
        workingDir = workingDir,
        args = cmd[1 .. ^1],
        options = processOptions
    )

    result.output = streams.readAll(process.outputStream)

    if not mergeStderr:
        result.errors = streams.readAll(process.errorStream)

    result.exitCode = process.waitForExit()
    process.close()

proc checkOutput*(
    cmd: seq[string],
    workingDir: string = "",
    mergeStderr: bool = true
): string =

    let captured = execCapture(cmd, workingDir, mergeStderr)

    if captured.exitCode != 0:
        raise (ref CalledProcessError)(
            cmd: cmd,
            exitCode: captured.exitCode,
            output: captured.output
        )

    result = captured.output

proc checkCall*(cmd: seq[string]): void =

    let captured = execCapture(cmd)

    if captured.exitCode != 0:
        raise (ref CalledProcessError)(
            cmd: cmd,
            exitCode: captured.exitCode,
            output: captured.output
        )

proc adbVersion*(adbCmd: seq[string]): int =
    result = 0

    let versionOutput = checkOutput(adbCmd & @["version"])
    let firstLine = versionOutput.splitLines()[0]

    const marker = "Android Debug Bridge version 1.0."
    if firstLine.startsWith(marker):
        let digits = firstLine[marker.len .. ^1]
        if digits.len > 0 and allCharsInSet(digits, Digits):
            result = parseInt(digits)

type AndroidDevice* {.final, pure.} = ref object
    serial*: string
    product*: string
    adbPath*: string
    adbCmd*: seq[string]
    linesepCache*: Option[string]
    featuresCache*: Option[seq[string]]

proc initAndroidDevice*(
    serial: string,
    product: string = "",
    adbPath: string = "adb"
): AndroidDevice =

    result = AndroidDevice(
        serial: serial,
        product: product,
        adbPath: adbPath,
        adbCmd: @[adbPath]
    )

    if serial.len > 0:
        result.adbCmd.add(@["-s", serial])

    if product.len > 0:
        result.adbCmd.add(@["-p", product])

proc linesep*(device: AndroidDevice): string =
    if device.linesepCache.isNone():
        device.linesepCache = some(checkOutput(device.adbCmd & @["shell", "echo"]))

    result = device.linesepCache.get()

proc simpleCall*(device: AndroidDevice, cmd: seq[string]): string =
    result = checkOutput(device.adbCmd & cmd, mergeStderr = true)

proc features*(device: AndroidDevice): seq[string] =
    if device.featuresCache.isNone():
        try:
            device.featuresCache = some(splitLines(device.simpleCall(@["features"])))
        except CalledProcessError:
            device.featuresCache = some(newSeq[string]())

    result = device.featuresCache.get()

proc hasShellProtocol*(device: AndroidDevice): bool =
    result = adbVersion(device.adbCmd) >= 35 and "shell_v2" in device.features()

proc makeShellCmd*(device: AndroidDevice, userCmd: seq[string]): seq[string] =
    result = device.adbCmd & @["shell"] & userCmd

    if not device.hasShellProtocol():
        result.add(returnCodeProbe)

proc parseShellOutput*(outputText: string): tuple[exitCode: int, output: string] =
    var searchText: string = outputText

    if searchText.len > returnCodeSearchLength:
        searchText = searchText[^returnCodeSearchLength .. ^1]

    let delimiterIndex: int = rfind(searchText, returnCodeDelimiter)

    if delimiterIndex < 0:
        raise newException(ValueError, "Could not find exit status in shell output.")

    let codeText: string = searchText[delimiterIndex + 1 .. ^1]

    result.exitCode = parseInt(codeText.strip())

    let consumed: int = 1 + codeText.len

    if consumed >= outputText.len:
        result.output = ""
    else:
        result.output = outputText[0 ..< outputText.len - consumed]

proc shellNocheck*(device: AndroidDevice, cmd: seq[string]): ShellResult =
    let fullCmd = device.makeShellCmd(cmd)

    let process = startProcess(
        command = fullCmd[0],
        args = fullCmd[1 .. ^1],
        options = {poUsePath}
    )

    result.output = streams.readAll(process.outputStream)
    result.errors = streams.readAll(process.errorStream)

    let rawExitCode: int = process.waitForExit()
    process.close()

    if device.hasShellProtocol():
        result.exitCode = rawExitCode
    else:
        let parsed = parseShellOutput(result.output)
        result.exitCode = parsed.exitCode
        result.output = parsed.output

proc shell*(device: AndroidDevice, cmd: seq[string]): tuple[output: string, errors: string] =
    let unchecked: ShellResult = device.shellNocheck(cmd)

    if unchecked.exitCode != 0:
        raise (ref ShellError)(
            cmd: cmd,
            output: unchecked.output,
            errors: unchecked.errors,
            exitCode: unchecked.exitCode
        )

    result = (unchecked.output, unchecked.errors)

proc shellPopen*(
    device: AndroidDevice,
    cmd: seq[string],
    logFile: File,
    cwd: string = "",
    killAtExit: bool = true
): Pid =

    let command: seq[string] = device.makeShellCmd(cmd)
    let logFd: cint = stdioFileDescriptor(logFile)

    when defined(posix):
        let pid: Pid = fork()

        if pid == 0:
            discard setsid()

            if dup2(logFd, 1) != 1 or dup2(logFd, 2) != 2:
                rawExit(127.cint)

            if cwd.len > 0:
                if chdir(cwd) != 0:
                    rawExit(127.cint)

            let argv: cstringArray = allocCStringArray(command)

            try:
                discard execvp(argv[0], argv)
            except OSError:
                discard

            rawExit(127.cint)

        if pid < 0:
            raiseOSError(osLastError())

        if killAtExit:
            processesToKill.add(pid)

        result = pid
    else:
        raise newException(OSError, "shellPopen requires a POSIX host")

proc getDevices*(adbPath: string = "adb"): seq[string] =
    checkCall(@[adbPath, "start-server"])

    let lines = splitLines(checkOutput(@[adbPath, "devices"]))

    if lines.len <= 1:
        return

    for line in lines[1 .. ^1]:
        if line.isEmptyOrWhitespace():
            continue
        if "offline" in line:
            continue
        result.add(line.splitWhitespace()[0])

proc getDeviceBySerial*(
    serial: string,
    product: string = "",
    adbPath: string = "adb"
): AndroidDevice =

    for device in getDevices(adbPath):
        if device == serial:
            return initAndroidDevice(serial, product, adbPath)

    raise (ref DeviceNotFoundError)(
        serial: serial,
        msg: &"No device with serial {serial}"
    )

proc getUniqueDevice*(
    product: string = "",
    adbPath: string = "adb"
): AndroidDevice =

    let devices = getDevices(adbPath)

    if len(devices) != 1:
        raise (ref NoUniqueDeviceError)(msg: "No unique device")

    result = initAndroidDevice(devices[0], product, adbPath)

proc getDevice*(
    serialOption: Option[string] = none(string),
    product: string = "",
    adbPath: string = "adb"
): AndroidDevice =

    if serialOption.isSome():
        return getDeviceBySerial(serialOption.get(), product, adbPath)

    if existsEnv("ANDROID_SERIAL"):
        return getDeviceBySerial(getEnv("ANDROID_SERIAL"), product, adbPath)

    result = getUniqueDevice(product, adbPath)

proc getDeviceByType(flag: string, adbPath: string): AndroidDevice =
    checkCall(@[adbPath, "start-server"])

    let serial: string = try:
        checkOutput(@[adbPath, flag, "get-serialno"]).strip()
    except CalledProcessError:
        raise newException(FindDeviceError, "adb unexpectedly returned nonzero")

    if serial == "unknown":
        raise (ref NoUniqueDeviceError)(msg: "No unique device")

    result = getDeviceBySerial(serial, adbPath = adbPath)

proc getDeviceByAdbFlag*(flag: string, adbPath: string = "adb"): AndroidDevice =
    result = getDeviceByType(flag, adbPath)

proc install*(device: AndroidDevice, filename: string, replace: bool = false): string =
    var cmd: seq[string] = @["install"]

    if replace:
        cmd.add("-r")

    cmd.add(filename)

    result = device.simpleCall(cmd)

proc push*(
    device: AndroidDevice,
    localFilename: string,
    remote: string,
    sync: bool = false,
    parameters: seq[string] = @[]
): string =

    var cmd: seq[string] = @["push"] & parameters

    if sync:
        cmd.add("--sync")

    cmd.add(localFilename)
    cmd.add(remote)

    result = device.simpleCall(cmd)

proc pushMany*(
    device: AndroidDevice,
    localFilenames: seq[string],
    remote: string,
    sync: bool = false,
    parameters: seq[string] = @[]
): string =

    var cmd: seq[string] = @["push"] & parameters

    if sync:
        cmd.add("--sync")

    cmd.add(localFilenames)
    cmd.add(remote)

    result = device.simpleCall(cmd)

proc pull*(device: AndroidDevice, remote: string, localFilename: string): string =
    result = device.simpleCall(@["pull", remote, localFilename])

proc sync*(device: AndroidDevice, directory: Option[string] = none(string)): string =
    var cmd: seq[string] = @["sync"]

    if directory.isSome():
        cmd.add(directory.get())

    result = device.simpleCall(cmd)

proc tcpip*(device: AndroidDevice, port: string): string =
    result = device.simpleCall(@["tcpip", port])

proc usb*(device: AndroidDevice): string =
    result = device.simpleCall(@["usb"])

proc reboot*(device: AndroidDevice): string =
    result = device.simpleCall(@["reboot"])

proc remount*(device: AndroidDevice): string =
    result = device.simpleCall(@["remount"])

proc root*(device: AndroidDevice): string =
    result = device.simpleCall(@["root"])

proc unroot*(device: AndroidDevice): string =
    result = device.simpleCall(@["unroot"])

proc connectAdb*(device: AndroidDevice, host: string): string =
    result = device.simpleCall(@["connect", host])

proc disconnect*(device: AndroidDevice, host: string): string =
    result = device.simpleCall(@["disconnect", host])

proc forward*(device: AndroidDevice, local: string, remote: string): string =
    result = device.simpleCall(@["forward", local, remote])

proc forwardList*(device: AndroidDevice): string =
    result = device.simpleCall(@["forward", "--list"])

proc forwardNoRebind*(device: AndroidDevice, local: string, remote: string): string =
    result = device.simpleCall(@["forward", "--no-rebind", local, remote])

proc forwardRemove*(device: AndroidDevice, local: string): string =
    result = device.simpleCall(@["forward", "--remove", local])

proc forwardRemoveAll*(device: AndroidDevice): string =
    result = device.simpleCall(@["forward", "--remove-all"])

proc reverse*(device: AndroidDevice, remote: string, local: string): string =
    result = device.simpleCall(@["reverse", remote, local])

proc reverseList*(device: AndroidDevice): string =
    result = device.simpleCall(@["reverse", "--list"])

proc reverseNoRebind*(device: AndroidDevice, local: string, remote: string): string =
    result = device.simpleCall(@["reverse", "--no-rebind", local, remote])

proc reverseRemoveAll*(device: AndroidDevice): string =
    result = device.simpleCall(@["reverse", "--remove-all"])

proc reverseRemove*(device: AndroidDevice, remote: string): string =
    result = device.simpleCall(@["reverse", "--remove", remote])

proc waitForDevice*(device: AndroidDevice): string =
    result = device.simpleCall(@["wait-for-device"])

proc getProp*(device: AndroidDevice, propName: string): Option[string] =
    let outputLines = splitLines(device.shell(@["getprop", propName]).output)

    if len(outputLines) != 1:
        let joinedOutputLines = join(outputLines, "\n")
        raise newException(
            ValueError,
            &"Too many lines in getprop output:\n{joinedOutputLines}"
        )

    let value = outputLines[0]

    if value.strip().len == 0:
        return none(string)

    result = some(value)

proc setProp*(device: AndroidDevice, propName: string, value: string): void =
    discard device.shell(@["setprop", propName, value])

proc logcat*(device: AndroidDevice): string =
    result = device.simpleCall(@["logcat", "-d"])

proc clearLogcat*(device: AndroidDevice): void =
    discard device.simpleCall(@["logcat", "-c"])
