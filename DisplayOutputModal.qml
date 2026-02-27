import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    layerNamespace: "dms:plugins:displayOutput"
    keepPopoutsOpen: true

    HyprlandFocusGrab {
        windows: [root.contentWindow]
        active: root.useHyprlandFocusGrab && root.shouldHaveFocus
    }

    property string currentView: "main"
    property int selectedIndex: 0
    property rect parentBounds: Qt.rect(0, 0, 0, 0)
    
    ListModel {
        id: mainModel
        ListElement { name: "Single Display"; desc: "Choose specific monitor"; icon: "computer"; mode: "single" }
        ListElement { name: "Duplicate / Mirror"; desc: "Clone primary screen"; icon: "content_copy"; mode: "mirror" }
        ListElement { name: "Extend"; desc: "Use multiple screens"; icon: "branding_watermark"; mode: "extend" }
    }

    ListModel {
        id: extendModel
        ListElement { name: "Extend Right"; desc: "Secondary on the right"; icon: "arrow_forward"; pos: "right" }
        ListElement { name: "Extend Left"; desc: "Secondary on the left"; icon: "arrow_back"; pos: "left" }
    }

    ListModel {
        id: singleModel
    }

    Connections {
        target: DisplayOutputService
        function onMonitorsUpdated() {
            singleModel.clear();
            let mons = DisplayOutputService.monitors;
            for (let i = 0; i < mons.length; i++) {
                let m = mons[i];
                let interfaceName = m.name;
                let makeModel = (m.make && m.model) ? (m.make + " " + m.model) : m.description;
                if (!makeModel || makeModel.trim() === "") makeModel = "Generic Display";
                
                singleModel.append({
                    name: interfaceName,
                    desc: makeModel,
                    icon: "monitor",
                    monitorName: interfaceName,
                    mode: "",
                    pos: ""
                });
            }
        }
    }

    property var activeModel: {
        if (currentView === "main") return mainModel;
        if (currentView === "extend") return extendModel;
        return singleModel;
    }
    
    property int optionCount: activeModel.count

    function openCentered() {
        parentBounds = Qt.rect(0, 0, 0, 0);
        backgroundOpacity = 0.5;
        open();
        DisplayOutputService.setDisplays();
    }

    shouldBeVisible: false
    width: 320
    height: contentLoader.item ? contentLoader.item.implicitHeight : 300
    enableShadow: true
    positioning: parentBounds.width > 0 ? "custom" : "center"
    customPosition: {
        if (parentBounds.width > 0) {
            const centerX = parentBounds.x + (parentBounds.width - width) / 2;
            const centerY = parentBounds.y + (parentBounds.height - height) / 2;
            return Qt.point(centerX, centerY);
        }
        return Qt.point(0, 0);
    }
    
    onBackgroundClicked: () => close()
    
    onOpened: () => {
        currentView = "main";
        selectedIndex = 0;
        Qt.callLater(() => modalFocusScope.forceActiveFocus());
    }

    modalFocusScope.Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            selectedIndex = (selectedIndex - 1 + optionCount) % optionCount;
            event.accepted = true;
            break;
        case Qt.Key_Down:
        case Qt.Key_Tab:
            selectedIndex = (selectedIndex + 1) % optionCount;
            event.accepted = true;
            break;
        case Qt.Key_Escape:
            if (currentView === "extend") {
                currentView = "main";
                selectedIndex = 2;
            } else if (currentView === "single") {
                currentView = "main";
                selectedIndex = 0;
            } else {
                close();
            }
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            handleSelection();
            event.accepted = true;
            break;
        }
    }

    function handleSelection() {
        if (currentView === "main") {
            let mode = mainModel.get(selectedIndex).mode;
            if (mode === "extend") {
                currentView = "extend";
                selectedIndex = 0;
            } else if (mode === "single") {
                currentView = "single";
                selectedIndex = 0;
            } else {
                DisplayOutputService.applyMode(mode);
                close();
            }
        } else if (currentView === "extend") {
            let pos = extendModel.get(selectedIndex).pos;
            DisplayOutputService.applyMode("extend", pos);
            close();
        } else if (currentView === "single") {
            let monName = singleModel.get(selectedIndex).monitorName;
            DisplayOutputService.applySingleMode(monName);
            close();
        }
    }

    content: Component {
        Item {
            anchors.fill: parent
            implicitHeight: mainColumn.implicitHeight + Theme.spacingL * 2

            Column {
                id: mainColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                Row {
                    width: parent.width
                    spacing: 10

                    DankIcon {
                        visible: root.currentView === "extend" || root.currentView === "single"
                        name: "arrow_back"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.currentView === "extend") {
                                    root.currentView = "main";
                                    root.selectedIndex = 2;
                                } else if (root.currentView === "single") {
                                    root.currentView = "main";
                                    root.selectedIndex = 0;
                                }
                            }
                        }
                    }

                    StyledText {
                        text: {
                            if (root.currentView === "main") return "Project Display";
                            if (root.currentView === "extend") return "Extend Position";
                            return "Select Monitor";
                        }
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        width: parent.width - (parent.children[0].visible ? 200 : 170) 
                        height: 1
                    }

                    DankActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: () => close()
                    }
                }

                DankListView {
                    width: parent.width
                    spacing: Theme.spacingS
                    height: (60 * root.optionCount) + Theme.spacingS
                    model: root.activeModel

                    delegate: Rectangle {
                        property bool isSelected: root.selectedIndex === index

                        width: parent.width
                        height: 60
                        radius: Theme.cornerRadius

                        color: {
                            if (isSelected) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                            } else if (hoverArea.containsMouse) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08);
                            } else {
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08);
                            }
                        }
                        border.color: isSelected ? Theme.primary : "transparent"
                        border.width: isSelected ? 1 : 0

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingM

                            DankIcon {
                                name: model.icon
                                size: Theme.iconSize
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                StyledText {
                                    text: model.name
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }
                                StyledText {
                                    visible: model.desc !== ""
                                    text: model.desc
                                    font.pixelSize: 11
                                    color: Theme.surfaceVariantText
                                }
                            }
                        }

                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedIndex = index;
                                root.handleSelection();
                            }
                        }
                    }
                }
            }
        }
    }
}