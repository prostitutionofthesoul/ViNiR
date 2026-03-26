pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * System updates service. Customized for Void Linux (XBPS).
 */
Singleton {
    id: root

    property bool available: false
    property int count: 0
    
    readonly property bool updateAdvised: available && count > (Config.options?.updates?.adviseUpdateThreshold ?? 75)
    readonly property bool updateStronglyAdvised: available && count > (Config.options?.updates?.stronglyAdviseUpdateThreshold ?? 200)

    function load() {}
    function refresh() {
        if (!available) return;
        // print("[Updates] Checking for system updates via xbps")
        checkUpdatesProc.running = true;
    }

    Timer {
        interval: (Config.options?.updates?.checkInterval ?? 120) * 60 * 1000
        repeat: true
        running: Config.ready
        onTriggered: {
            // print("[Updates] Periodic update check due")
            root.refresh();
        }
    }

    Timer {
        id: availabilityDefer
        interval: 1500
        repeat: false
        onTriggered: checkAvailabilityProc.running = true
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) availabilityDefer.start()
        }
    }

    // Проверяем наличие xbps-install вместо checkupdates
    Process {
        id: checkAvailabilityProc
        running: false
        command: ["which", "xbps-install"]
        onExited: (exitCode, exitStatus) => {
            root.available = (exitCode === 0);
            if (root.available) root.refresh();
        }
    }

    // Логика для Void Linux
    Process {
        id: checkUpdatesProc
        // -u (update), -n (dry-run/dry-mode) - показывает что будет обновлено без скачивания
        command: ["sh", "-c", "xbps-install -un"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = (text ?? "").trim();
                // Если вывод пустой, значит обновлений 0. Иначе считаем строки.
                root.count = t.length > 0 ? t.split("\n").length : 0;
                // print("[Updates] Found " + root.count + " updates")
            }
        }
        onExited: (exitCode, exitStatus) => {
            // В xbps-install выход 0 означает успех, даже если обновлений 0
            if (exitCode !== 0) {
                console.error("[Updates] xbps-install -un failed", exitCode, exitStatus)
            }
        }
    }
}
