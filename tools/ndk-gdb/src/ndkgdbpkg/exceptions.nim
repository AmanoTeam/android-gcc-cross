type
    FindDeviceError* {.pure, inheritable.} = object of CatchableError
    DeviceNotFoundError* {.final.} = object of FindDeviceError
        serial*: string
    NoUniqueDeviceError* {.final.} = object of FindDeviceError
    ShellError* {.final.} = object of CatchableError
        cmd*: seq[string]
        output*: string
        errors*: string
        exitCode*: int
    CalledProcessError* {.final.} = object of CatchableError
        cmd*: seq[string]
        exitCode*: int
        output*: string
