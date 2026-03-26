pragma Singleton

import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland

Singleton {
    id: root

    property bool _xembedProxyStartRequested: false
    property bool _xembedProxyCheckedOnce: false

    property bool smartTray: Config.options?.tray?.filterPassive ?? true
    
    // Apps that don't implement DBus Activate properly (libappindicator issue)
    readonly property var problematicApps: [
        { matches: ["spotify"], launch: "spotify-launcher" },
        { matches: ["discord canary", "canary"], launch: "discord-canary", focusOnly: true, fixedIcon: "discord-canary" },
        { matches: ["discord ptb", "ptb"], launch: "discord-ptb", focusOnly: true, fixedIcon: "discord-ptb" },
        { matches: ["discord", "com.discordapp.discord"], launch: "discord", focusOnly: true, fixedIcon: "discord" },
        { matches: ["vesktop", "Vesktop"], launch: "vesktop" },
        { matches: ["armcord", "ArmCord"], launch: "armcord" },
        { matches: ["slack", "Slack"], launch: "slack" },
        { matches: ["teams", "Teams"], launch: "teams-for-linux" },
        { matches: ["telegram", "Telegram", "org.telegram"], launch: "org.telegram.desktop" },
        { matches: ["signal", "Signal"], launch: "signal-desktop" },
        { matches: ["element", "Element"], launch: "element-desktop" },
        { matches: ["steam", "Steam"], launch: "steam" },
        { matches: ["skype", "Skype"], launch: "skypeforlinux" },
        { matches: ["viber", "Viber"], launch: "viber" },
        { matches: ["zoom", "Zoom"], launch: "zoom" },
        { matches: ["easyeffects", "EasyEffects", "com.github.wwmm.easyeffects"], launch: "easyeffects" },
    ]
    
    function getProblematicAppInfo(item): var {
        if (!item) return null;
        const id = (item.id ?? "").toLowerCase();
        const title = (item.title ?? "").toLowerCase();
        const tooltipTitle = (item.tooltipTitle ?? "").toLowerCase();

        root._log(`[TrayService] Checking problematic app: ID='${id}' Title='${title}' Tooltip='${tooltipTitle}'`);

        for (const app of problematicApps) {
            for (const pattern of app.matches) {
                const p = pattern.toLowerCase();
                if (id.includes(p) || title.includes(p) || tooltipTitle.includes(p)) {
                    return app;
                }
            }
        }
        return null;
    }
    
    function matchesApp(str, app): bool {
        if (!str || !app?.matches) return false;
        const s = str.toLowerCase();
        for (const pattern of app.matches) {
            if (s.includes(pattern.toLowerCase())) return true;
        }
        return false;
    }
    
    function smartActivate(item): bool {
        if (!item) return false;
        
        const appInfo = getProblematicAppInfo(item);
        if (!appInfo) return false;
        
        let toplevel = null;
        for (const tl of ToplevelManager.toplevels.values) {
            const appId = (tl.appId ?? "").toLowerCase();
            const tlTitle = (tl.title ?? "").toLowerCase();
            if (matchesApp(appId, appInfo) || matchesApp(tlTitle, appInfo)) {
                toplevel = tl;
                break;
            }
        }
        
        if (toplevel) {
            toplevel.activate();
            return true;
        }
        
        Quickshell.execDetached(["/usr/bin/bash", "-lc", appInfo.launch]);
        return true;
    }
    
    function smartToggle(item): bool {
        if (!item) return false;
        
        const id = (item.id ?? "").toLowerCase();
        root._log(`[TrayService] smartToggle called for: ${id}`);
        const appInfo = getProblematicAppInfo(item);
        
        let toplevel = null;
        for (const tl of ToplevelManager.toplevels.values) {
            const appId = (tl.appId ?? "").toLowerCase();
            const tlTitle = (tl.title ?? "").toLowerCase();
            
            let isMatch = false;
            if (appInfo) {
                isMatch = matchesApp(appId, appInfo) || matchesApp(tlTitle, appInfo);
            } else {
                isMatch = appId.includes(id) || id.includes(appId) || 
                          tlTitle.includes(id) || appId === id;
            }
            
            if (isMatch) {
                root._log(`[TrayService] Match found for ${id}: ${appId} / ${tlTitle}`);
                toplevel = tl;
                break;
            }
        }
        
        if (toplevel) {
            toplevel.activate();
            return true;
        }
        
        if (appInfo) {
            if (appInfo.focusOnly) {
                root._log(`[TrayService] Window not found for ${id}, but focusOnly is true. Falling back to item.activate().`);
                return false;
            }
            
            root._log(`[TrayService] Window not found for ${id}, executing launch: ${appInfo.launch}`);
            Quickshell.execDetached(["/usr/bin/bash", "-lc", appInfo.launch]);
            return true;
        }
        
        return false;
    }
    
    function isValidItem(item) {
        return item && item.id;
    }
    
    property var _pinnedItems: Config.options?.tray?.pinnedItems ?? []
    property list<var> itemsInUserList: SystemTray.items.values.filter(i => (isValidItem(i) && _pinnedItems.includes(i.id)))
    property list<var> itemsNotInUserList: SystemTray.items.values.filter(i => (isValidItem(i) && !_pinnedItems.includes(i.id) && (!smartTray || i.status !== Status.Passive)))

    property bool invertPins: Config.options?.tray?.invertPinnedItems ?? false
    property list<var> pinnedItems: invertPins ? itemsNotInUserList : itemsInUserList
    property list<var> unpinnedItems: invertPins ? itemsInUserList : itemsNotInUserList

    function getSafeIcon(item): string {
        if (!item) return "";
        const app = getProblematicAppInfo(item);
        if (app && app.fixedIcon) return app.fixedIcon;
        return item.icon ?? "";
    }

    function getTooltipForItem(item) {
        if (!item) return "";
        const tooltipTitle = item.tooltipTitle ?? "";
        const title = item.title ?? "";
        const id = item.id ?? "";
        const tooltipDescription = item.tooltipDescription ?? "";
        
        var result = tooltipTitle.length > 0 ? tooltipTitle
                : (title.length > 0 ? title : id);
        if (tooltipDescription.length > 0) result += " • " + tooltipDescription;
        if (Config.options?.tray?.showItemId) result += "\n[" + id + "]";
        return result;
    }

    function pin(itemId) {
        var pins = Config.options?.tray?.pinnedItems ?? [];
        if (pins.includes(itemId)) return;
        pins.push(itemId);
        Config.setNestedValue("tray.pinnedItems", pins);
    }
    function unpin(itemId) {
        var pins = Config.options?.tray?.pinnedItems ?? [];
        Config.setNestedValue("tray.pinnedItems", pins.filter(id => id !== itemId));
    }
    function togglePin(itemId) {
        var pins = Config.options?.tray?.pinnedItems ?? [];
        if (pins.includes(itemId)) {
            unpin(itemId)
        } else {
            pin(itemId)
        }
    }

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    function requestXembedProxyIfNeeded(): void {
        if (!CompositorService.isNiri)
            return;
        root.ensureXembedSniProxy();
    }

    function ensureXembedSniProxy(): void {
        if (!CompositorService.isNiri)
            return;
        if (root._xembedProxyStartRequested)
            return;
        root._xembedProxyStartRequested = true;
        xembedProxyDelayedStartTimer.restart();
    }

    Timer {
        id: xembedProxyDelayedStartTimer
        interval: 600
        repeat: false
        onTriggered: {
            xembedProxyCheckProc.running = false;
            xembedProxyCheckProc.running = true;
        }
    }

    Process {
        id: xembedProxyCheckProc
        command: ["pgrep", "-x", "snixembed"]
        onExited: (exitCode, exitStatus) => {
            root._xembedProxyCheckedOnce = true;
            if (exitCode !== 0) {
                xembedProxyStartProc.running = false;
                xembedProxyStartProc.running = true;
            }
        }
    }

    Process {
        id: xembedProxyStartProc
        stdout: SplitParser {
            onRead: (line) => root._log("[snixembed]", line)
        }
        stderr: SplitParser {
            onRead: (line) => root._log("[snixembed]", line)
        }
        command: ["snixembed"]
        onExited: (exitCode, exitStatus) => {
            root._log("[snixembed] exited", exitCode, exitStatus)
        }
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                root.requestXembedProxyIfNeeded();
            }
        }
    }

    Connections {
        target: CompositorService
        function onIsNiriChanged() {
            root.requestXembedProxyIfNeeded();
        }
    }
}
