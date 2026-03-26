pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property bool inhibit: false
    readonly property int screenOffTimeout: Config.options?.idle?.screenOffTimeout ?? 300
    readonly property int lockTimeout: Config.options?.idle?.lockTimeout ?? 600
    // Устанавливаем 15 минут (900 сек) по умолчанию
    readonly property int suspendTimeout: Config.options?.idle?.suspendTimeout ?? 900

    onScreenOffTimeoutChanged: _restartSwayidle()
    onLockTimeoutChanged: _restartSwayidle()
    onSuspendTimeoutChanged: _restartSwayidle()
    onInhibitChanged: _restartSwayidle()

    function toggleInhibit(active = null): void {
        if (active !== null) {
            inhibit = active;
        } else {
            inhibit = !inhibit;
        }
        Persistent.states.idle.inhibit = inhibit;
    }

    function _restartSwayidle() {
        _stopSwayidle()
        if (!inhibit) _startSwayidleDelayed.start()
    }

    function _stopSwayidle() {
        Quickshell.execDetached(["/usr/bin/pkill", "-x", "swayidle"])
    }

    function _startSwayidle() {
        if (inhibit) return

        // Добавляем -C /dev/null чтобы избежать ошибки BlockInhibited в Void Linux
        const cmd = ["/usr/bin/swayidle", "-w", "-C", "/dev/null"]
        const lockBeforeSleep = Config.options?.idle?.lockBeforeSleep !== false

        if (screenOffTimeout > 0) {
            cmd.push("timeout", screenOffTimeout.toString(), "/usr/bin/niri msg action power-off-monitors", "resume", "/usr/bin/niri msg action power-on-monitors")
        }

        let effectiveLockTimeout = lockTimeout
        if (suspendTimeout > 0 && lockBeforeSleep) {
            const lockBeforeSuspendTime = Math.max(1, suspendTimeout - 5)
            if (lockTimeout <= 0 || lockTimeout > lockBeforeSuspendTime) {
                effectiveLockTimeout = lockBeforeSuspendTime
            }
        }

        if (effectiveLockTimeout > 0) {
            cmd.push("timeout", effectiveLockTimeout.toString(), "/usr/bin/qs -c ii ipc call lock activate")
        }

        if (suspendTimeout > 0) {
            // Используем проверенный loginctl
            cmd.push("timeout", suspendTimeout.toString(), "/usr/bin/loginctl suspend")
        }

        if (lockBeforeSleep) {
            cmd.push("before-sleep", "/usr/bin/qs -c ii ipc call lock activate")
        }

        console.log("[Idle] Starting swayidle with Void fixes")
        Quickshell.execDetached(cmd)
    }

    Timer {
        id: _startSwayidleDelayed
        interval: 200
        onTriggered: root._startSwayidle()
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) root._restartSwayidle()
        }
    }

    Connections {
        target: Persistent
        function onReadyChanged() {
            if (Persistent.ready && Persistent.states?.idle?.inhibit)
                root.inhibit = true
        }
    }

    Component.onDestruction: _stopSwayidle()
}
