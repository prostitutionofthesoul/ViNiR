pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool hasRun: false
    property bool _unitsRefreshRequested: false
    readonly property bool globalEnabled: Config.options?.autostart?.enable ?? false

    readonly property var entries: (Config.options?.autostart && Config.options?.autostart?.entries)
        ? Config.options.autostart.entries
        : []

    property var systemdUnits: []

    function load() {
        if (hasRun)
            return;
        hasRun = true;

        if (Config.ready) {
            startFromConfig();
        }
    }

    function startFromConfig() {
        if (!globalEnabled)
            return;
        const cfg = Config.options?.autostart;
        if (!cfg || !cfg.entries)
            return;
        for (let i = 0; i < cfg.entries.length; ++i) {
            const entry = cfg.entries[i];
            if (!entry || entry.enabled !== true)
                continue;
            startEntry(entry);
        }
    }

    function startEntry(entry) {
        if (!entry)
            return;
        if (entry.type === "desktop" && entry.desktopId) {
            startDesktop(entry.desktopId);
        } else if (entry.type === "command" && entry.command) {
            startCommand(entry.command);
        }
    }

    function startDesktop(desktopId) {
        if (!desktopId)
            return;
        const id = String(desktopId).trim();
        if (id.length === 0)
            return;
        startDesktopProc.desktopId = id
        startDesktopProc.running = true
    }

    Process {
        id: startDesktopProc
        property string desktopId: ""
        command: ["/usr/bin/gtk-launch", startDesktopProc.desktopId]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && startDesktopProc.desktopId.length > 0) {
                Quickshell.execDetached([startDesktopProc.desktopId])
            }
            startDesktopProc.desktopId = ""
        }
    }

    function startCommand(command) {
        if (!command)
            return;
        const cmd = String(command).trim();
        if (cmd.length === 0)
            return;
        Quickshell.execDetached(["/usr/bin/bash", "-lc", cmd]);
    }

    Process {
        id: systemdListProc
        property var buffer: []
        command: [
            "/usr/bin/bash", "-lc",
            "dir=\"$HOME/.config/autostart\"; "
            + "[ -d \"$dir\" ] || exit 0; "
            + "for f in \"$dir\"/*.desktop; do "
            + "[ -e \"$f\" ] || continue; "
            + "name=$(basename \"$f\"); "
            + "enabled=enabled; "
            + "desc=$(grep -m1 '^Comment=' \"$f\" | cut -d= -f2-); "
            + "ii_managed=no; "
            + "grep -q 'ii-autostart' \"$f\" 2>/dev/null && ii_managed=yes; "
            + "echo \"$name|$enabled|session|$desc|none|$ii_managed\"; "
            + "done"
        ]
        stdout: SplitParser {
            onRead: (line) => {
                systemdListProc.buffer.push(line)
            }
        }
        onExited: (exitCode, exitStatus) => {
            const units = []
            if (exitCode !== 0) {
                root.systemdUnits = units
                systemdListProc.buffer = []
                return;
            }

            for (let i = 0; i < systemdListProc.buffer.length; ++i) {
                const raw = systemdListProc.buffer[i].trim()
                if (raw.length === 0)
                    continue;
                const parts = raw.split("|")
                if (parts.length < 6)
                    continue;
                units.push({
                    name: parts[0],
                    state: parts[1],
                    description: parts[3],
                    enabled: true,
                    isTray: false,
                    iiManaged: parts[5] === "yes"
                })
            }
            root.systemdUnits = units
            systemdListProc.buffer = []
        }
    }

    function refreshSystemdUnits() {
        systemdListProc.buffer = []
        systemdListProc.running = true
    }

    function requestRefreshSystemdUnits(): void {
        root._unitsRefreshRequested = true
        refreshTimer.restart()
    }

    Timer {
        id: refreshTimer
        interval: 1200
        repeat: false
        onTriggered: {
            if (!root._unitsRefreshRequested)
                return;
            root._unitsRefreshRequested = false
            root.refreshSystemdUnits()
        }
    }

    function setServiceEnabled(name, enabled) {
    }

    function deleteUserService(name) {
        if (!name || name.length === 0)
            return;
        Quickshell.execDetached(["/usr/bin/rm", "-f", Directories.home + "/.config/autostart/" + name])
        refreshSystemdUnits()
    }

    function createUserService(name, description, command, kind) {
        if (!name)
            return;
        const trimmedName = String(name).trim()
        if (trimmedName.length === 0)
            return;
        const execLine = String(command || "").trim()
        if (execLine.length === 0)
            return;
        const safeName = trimmedName.replace(/\s+/g, "-")
        const desc = String(description || safeName)
        const homePath = FileUtils.trimFileProtocol(Directories.home)
        const dir = `${homePath}/.config/autostart`
        const filePath = `${dir}/${safeName}.desktop`
        const text = "[Desktop Entry]\n"
            + "Type=Application\n"
            + "Name=" + safeName + "\n"
            + "Comment=" + desc + " (ii-autostart)\n"
            + "Exec=" + execLine + "\n"
            + "X-GNOME-Autostart-enabled=true\n"
        Quickshell.execDetached(["/usr/bin/mkdir", "-p", dir])
        userServiceWriter.path = Qt.resolvedUrl(filePath)
        userServiceWriter.setText(text)
        refreshSystemdUnits()
    }

    FileView {
        id: userServiceWriter
    }

    Component.onCompleted: {
        load()
        root.requestRefreshSystemdUnits()
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready && !root.hasRun) {
                root.startFromConfig();
                root.hasRun = true;
            }
            if (Config.ready) {
                root.requestRefreshSystemdUnits()
            }
        }
    }
}
