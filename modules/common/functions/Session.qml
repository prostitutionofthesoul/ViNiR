pragma Singleton
import Quickshell
import QtQuick
import qs.services
import qs.modules.common

Singleton {
    id: root

    Timer {
        id: _hibernateMonitorsOffTimer
        interval: 450
        repeat: false
        onTriggered: {
            if (CompositorService.isNiri) {
                Quickshell.execDetached(["/usr/bin/niri", "msg", "action", "power-off-monitors"])
            } else if (CompositorService.isHyprland) {
                Quickshell.execDetached(["/usr/bin/hyprctl", "dispatch", "dpms", "off"])
            }
        }
    }

    Timer {
        id: _hibernateTimer
        interval: 900
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["/usr/bin/loginctl", "hibernate"])
        }
    }

    Timer {
        id: _suspendTimer
        interval: 1000 
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["/usr/bin/loginctl", "suspend"])
        }
    }

    function closeAllWindows() {
        if (!CompositorService.isHyprland)
            return;

        HyprlandData.windowList.map(w => w.pid).forEach(pid => {
            Quickshell.execDetached(["/usr/bin/kill", pid]);
        });
    }

    function lock() {
        Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "lock", "activate"]);
    }

    function suspend() {
        lock();
        _suspendTimer.interval = 1000; 
        _suspendTimer.restart();
    }

    function logout() {
        if (CompositorService.isNiri) {
            NiriService.quit();
            return;
        }

        closeAllWindows();
        Quickshell.execDetached(["/usr/bin/pkill", "-i", "Hyprland"]);
    }

    function launchTaskManager() {
        const cmd = Config.options?.apps?.taskManager ?? "missioncenter"
        Quickshell.execDetached([cmd]) 
    }

    function hibernate() {
        lock();
        _hibernateMonitorsOffTimer.restart()
        _hibernateTimer.restart()
    }

    function poweroff() {
        closeAllWindows();
        Quickshell.execDetached(["/usr/bin/loginctl", "poweroff"])
    }

    function reboot() {
        closeAllWindows();
        Quickshell.execDetached(["/usr/bin/loginctl", "reboot"])
    }

    function rebootToFirmware() {
        closeAllWindows();
        Quickshell.execDetached(["/usr/bin/loginctl", "reboot", "--firmware-setup"])
    }
}
