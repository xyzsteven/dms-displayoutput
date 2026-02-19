pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.Common

Singleton {
    id: root

    property var monitors: []
    property var internalDisplay: null
    property var externalDisplay: null
    
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.setDisplays()
    }

    Component.onCompleted: setDisplays()

    function setDisplays() {
        Proc.runCommand("displayOutput:getMonitors", ["hyprctl", "monitors", "all", "-j"], (output, exitCode) => {
            if (exitCode !== 0) return;
            try {
                var allMonitors = JSON.parse(output);
                root.monitors = allMonitors;
                root.internalDisplay = allMonitors.find(m => m.name.startsWith("eDP")) || allMonitors[0];
                root.externalDisplay = allMonitors.find(m => m.name !== root.internalDisplay?.name);

                if (!root.externalDisplay && root.internalDisplay && root.internalDisplay.disabled) {
                    runShell(`hyprctl keyword monitor ${root.internalDisplay.name},preferred,auto,1`);
                }
            } catch (e) {}
        });
    }

    function runShell(shellCmd) {
        console.log("Executing: " + shellCmd);
        Proc.runCommand("displayOutput:shell", ["bash", "-c", shellCmd], (o, e) => {
            Qt.callLater(root.setDisplays); 
        });
    }

    function applyMode(mode, position) {
        if (!root.internalDisplay) return;

        let intName = root.internalDisplay.name;
        if (mode !== "pc_only" && !root.externalDisplay) return;
        
        let extName = root.externalDisplay ? root.externalDisplay.name : "";
        let refreshCmd = `sleep 0.5 && hyprctl dispatch workspace +1 && hyprctl dispatch workspace -1`;

        let cmd = "";

        if (mode === "pc_only") {
            cmd = `hyprctl keyword monitor ${intName},preferred,auto,1 && hyprctl keyword monitor ${extName},disable`;

        } else if (mode === "second_only") {
            cmd = `hyprctl keyword monitor ${extName},preferred,auto,1 && sleep 0.5 && hyprctl dispatch movecurrentworkspacetomonitor ${extName} && hyprctl keyword monitor ${intName},disable && ${refreshCmd}`;

        } else if (mode === "mirror") {
            cmd = `hyprctl keyword monitor ${extName},disable && sleep 1 && hyprctl keyword monitor ${intName},preferred,auto,1 && hyprctl dispatch focusmonitor ${intName} && hyprctl keyword monitor ${extName},preferred,auto,1,mirror,${intName}`;

        } else if (mode === "extend") {
            let resetCmd = `hyprctl keyword monitor ${extName},disable && sleep 0.5`;
            
            if (position === "left") {
                cmd = `${resetCmd} && hyprctl keyword monitor ${extName},preferred,0x0,1 && hyprctl keyword monitor ${intName},preferred,auto-right,1 && ${refreshCmd}`;
            } else {
                cmd = `${resetCmd} && hyprctl keyword monitor ${intName},preferred,0x0,1 && hyprctl keyword monitor ${extName},preferred,auto-right,1 && ${refreshCmd}`;
            }
        }

        runShell(cmd);
    }
}