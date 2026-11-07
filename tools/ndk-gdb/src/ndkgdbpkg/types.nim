import std/options

type
    LaunchMode* {.pure.} = enum
        lmAttach
        lmLaunchAuto
        lmLaunchActivity
    ShellResult* = tuple[exitCode: int, output: string, errors: string]
    Args* {.final, pure.} = ref object
        verbose*: bool
        force*: bool
        port*: int
        delay*: float
        projectOption*: Option[string]
        lldbOption*: bool
        noLldbOption*: bool
        deviceOption*: Option[string]
        serialOption*: Option[string]
        adbPathOption*: Option[string]
        attachOption*: bool
        packageNameOption*: Option[string]
        launchMode*: LaunchMode
        launchActivity*: string
        launchList*: bool
        execFileOption*: Option[string]
        nowait*: bool
        nowaitForced*: bool
        tui*: bool
        makeCmd*: Option[string]
        jdbCmdOption*: Option[string]
        project*: string
        manifestPath*: string
        packageName*: string
        activities*: seq[string]

proc initArgs*(): Args =
    result = Args()
    result.port = 5039
    result.delay = 0.25
    result.launchMode = lmAttach
    result.activities = @[]
