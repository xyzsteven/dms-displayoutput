pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.Common
import qs.Services

Singleton {
    id: root

    property var monitors: []
    property var primaryDisplay: null
    property var secondaryDisplay: null
    
    signal monitorsUpdated()
    
    Component.onCompleted: setDisplays()

    function setDisplays() {
        Proc.runCommand("displayOutput:getMonitors", ["hyprctl", "monitors", "all", "-j"], (output, exitCode) => {
            if (exitCode !== 0) {
                ToastService.showError("Display Output", "Failed to fetch monitor data.");
                return;
            }
            try {
                var allMonitors = JSON.parse(output);
                if (allMonitors.length === 0) return;

                root.monitors = allMonitors;
                
                root.primaryDisplay = allMonitors.find(m => m.focused) || allMonitors[0];
                root.secondaryDisplay = allMonitors.find(m => m.name !== root.primaryDisplay?.name);

                if (!root.secondaryDisplay && root.primaryDisplay && root.primaryDisplay.disabled) {
                    runShell(`hyprctl keyword monitor ${root.primaryDisplay.name},preferred,auto,1`);
                }
                
                root.monitorsUpdated();
            } catch (e) {
                console.error("Failed to parse hyprctl output", e);
            }
        });
    }

    function runShell(shellCmd) {
        console.log("Executing: " + shellCmd);
        Proc.runCommand("displayOutput:shell", ["bash", "-c", shellCmd], (o, e) => {
            Qt.callLater(root.setDisplays); 
        });
    }

    function applySingleMode(targetMonitorName) {
        let cmd = "";
        let hasDisable = false;
        
        for (let i = 0; i < root.monitors.length; i++) {
            let mName = root.monitors[i].name;
            if (mName === targetMonitorName) {
                cmd += (cmd === "" ? "" : " && ") + `hyprctl keyword monitor ${mName},preferred,auto,1`;
            } else {
                cmd += (cmd === "" ? "" : " && ") + `hyprctl keyword monitor ${mName},disable`;
                hasDisable = true;
            }
        }
        
        if (hasDisable) {
            cmd += ` && sleep 0.5 && hyprctl dispatch workspace +1 && hyprctl dispatch workspace -1`;
        }
        
        ToastService.showInfo("Display Output", `Single Display (${targetMonitorName})`);
        if (cmd !== "") runShell(cmd);
    }

    function applyMode(mode, position) {
        if (!root.primaryDisplay) {
            ToastService.showError("Display Output", "Primary display not detected!");
            return;
        }

        let primaryName = root.primaryDisplay.name;
        let secondaryName = root.secondaryDisplay ? root.secondaryDisplay.name : "";

        if (secondaryName === "") {
            ToastService.showError("Display Output", "Secondary display not connected!");
            return;
        }
        
        let refreshCmd = `sleep 0.5 && hyprctl dispatch workspace +1 && hyprctl dispatch workspace -1`;
        let cmd = "";

        if (mode === "mirror") {
            cmd = `hyprctl keyword monitor ${secondaryName},disable && sleep 1 && hyprctl keyword monitor ${primaryName},preferred,auto,1 && hyprctl dispatch focusmonitor ${primaryName} && hyprctl keyword monitor ${secondaryName},preferred,auto,1,mirror,${primaryName}`;
            ToastService.showInfo("Display Output", "Mode: Duplicate / Mirror");
        } else if (mode === "extend") {
            let resetCmd = `hyprctl keyword monitor ${secondaryName},disable && sleep 0.5`;
            if (position === "left") {
                cmd = `${resetCmd} && hyprctl keyword monitor ${secondaryName},preferred,0x0,1 && hyprctl keyword monitor ${primaryName},preferred,auto-right,1 && ${refreshCmd}`;
                ToastService.showInfo("Display Output", "Mode: Extend Left");
            } else {
                cmd = `${resetCmd} && hyprctl keyword monitor ${primaryName},preferred,0x0,1 && hyprctl keyword monitor ${secondaryName},preferred,auto-right,1 && ${refreshCmd}`;
                ToastService.showInfo("Display Output", "Mode: Extend Right");
            }
        }

        if (cmd !== "") {
            runShell(cmd);
        }
    }

    function checkAndFallback() {
        console.log("Checking monitor states for auto-fallback...");
        Proc.runCommand("displayOutput:fallback", ["hyprctl", "monitors", "all", "-j"], (output, exitCode) => {
            if (exitCode !== 0) return;
            
            try {
                var allMonitors = JSON.parse(output);
                if (allMonitors.length === 0) return;

                var activeMonitors = allMonitors.filter(m => !m.disabled);
                
                if (activeMonitors.length === 0 && allMonitors.length > 0) {
                    let fallbackMon = allMonitors[0].name;
                    runShell(`hyprctl keyword monitor ${fallbackMon},preferred,auto,1`);
                    ToastService.showInfo("Display Output", `Auto-fallback: Mengaktifkan ${fallbackMon}`);
                } 
                else if (allMonitors.length === 1 && allMonitors[0].disabled) {
                    let monName = allMonitors[0].name;
                    runShell(`hyprctl keyword monitor ${monName},preferred,auto,1`);
                    ToastService.showInfo("Display Output", `Auto-fallback: Kembali ke ${monName}`);
                }

                setDisplays();
            } catch (e) {
                console.error("Failed to process auto-fallback data", e);
            }
        });
    }
}