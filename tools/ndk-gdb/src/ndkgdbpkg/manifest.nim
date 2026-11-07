import std/[os, xmltree, xmlparser, streams, strutils, strformat]

const androidNameAttribute*: string = "android:name"

proc parseManifestFile*(manifestPath: string): XmlNode =
    if not fileExists(manifestPath):
        raise newException(IOError, &"could not open '{manifestPath}'")

    let manifestStream = newFileStream(manifestPath, mode = fmRead)
    defer:
        manifestStream.close()

    result = parseXml(manifestStream)

proc collectDescendants(node: XmlNode, tag: string, collected: var seq[XmlNode]) =
    if node.kind == xnElement and node.tag == tag:
        collected.add(node)

    for child in node:
        collectDescendants(child, tag, collected)

iterator descendants*(node: XmlNode, tag: string): XmlNode =
    var collected: seq[XmlNode] = @[]
    collectDescendants(node, tag, collected)

    for descendant in collected:
        yield descendant

proc extractPackageName*(xmlroot: XmlNode): string =
    let packageName = xmlroot.attr("package")

    if packageName.len == 0:
        raise newException(ValueError, "Failed to find package name in AndroidManifest.xml")

    result = packageName

proc extractLaunchable*(xmlroot: XmlNode): seq[string] =
    result = @[]

    var application: XmlNode = nil

    for child in xmlroot:
        if child.kind == xnElement and child.tag == "application":
            application = child
            break

    if application.isNil():
        raise newException(
            ValueError,
            "Failed to find application node in AndroidManifest.xml"
        )

    const mainAction = "android.intent.action.MAIN"
    const launcherCategory = "android.intent.category.LAUNCHER"

    for activity in descendants(application, "activity"):
        let activityName = activity.attr(androidNameAttribute)

        if activityName.len == 0:
            continue

        for intentFilter in descendants(activity, "intent-filter"):
            var foundAction = false
            var foundCategory = false

            for filterChild in intentFilter:
                if filterChild.kind != xnElement:
                    continue

                if filterChild.tag == "action":
                    let name = filterChild.attr(androidNameAttribute)
                    if not foundAction and name.len > 0 and name == mainAction:
                        foundAction = true

                if filterChild.tag == "category":
                    let name = filterChild.attr(androidNameAttribute)
                    if not foundCategory and name.len > 0 and name == launcherCategory:
                        foundCategory = true

            if foundAction and foundCategory:
                result.add(activityName)

proc canonicalizeActivity*(packageName: string, activityName: string): string =
    if activityName.startsWith("."):
        return &"{packageName}{activityName}"

    result = activityName
