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
}
