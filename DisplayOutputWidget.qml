import QtQuick
import Quickshell.Io
import qs.Modules.Plugins

PluginComponent {
    id: root

    property var popoutService: null

    DisplayOutputModal {
        id: modal
    }

    IpcHandler {
        function open(): string {
            modal.shouldBeVisible = true;
            modal.openCentered();
            DisplayOutputService.setDisplays();
            return "DISPLAY_OUTPUT_OPEN_SUCCESS";
        }

        function close(): string {
            modal.shouldBeVisible = false;
            modal.close();
            return "DISPLAY_OUTPUT_CLOSE_SUCCESS";
        }

        function toggle(): string {
            if (modal.shouldBeVisible) {
                return close();
            }
            return open();
        }

        target: "displayOutput"
    }

    Process {
        id: hyprlandSocketWatcher
        command: ["sh", "-c", "socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"]
        running: true

        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("monitorremoved>>") || line.startsWith("monitoradded>>")) {
                    console.log("Hardware display change detected!");
                    
                    Qt.callLater(() => {
                        DisplayOutputService.checkAndFallback();
                    });
                }
            }
        }
        
        stderr: SplitParser {
            onRead: line => {
                if (line.trim() && !line.includes("socat")) {
                    console.error("Socket Watcher Error:", line);
                }
            }
        }

        onExited: exitCode => {
            console.warn("Hyprland socket watcher exited with code:", exitCode);
            if (exitCode !== 0) {
                Qt.callLater(() => { hyprlandSocketWatcher.running = true; });
            }
        }
    }
}
