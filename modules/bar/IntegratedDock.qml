pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

StyledRect {
    id: root

    required property var bar
    property string orientation: "horizontal"

    readonly property bool isVertical: orientation === "vertical"
    readonly property bool isIntegrated: (Config.dock?.theme ?? "default") === "integrated"
    readonly property string dockPosition: Config.dock?.position ?? "center"

    // Compact sizing for integrated dock
    readonly property int iconSize: 18
    readonly property int itemSpacing: 2

    readonly property string magnificationEdge: {
        const edge = Config.bar?.position ?? "top";
        return ["top", "bottom", "left", "right"].includes(edge) ? edge : "top";
    }


    visible: (Config.dock?.enabled ?? false) && isIntegrated

    variant: "bg"
    
    // Radius handling from parent
    property real startRadius: radius
    property real endRadius: radius

    topLeftRadius: isVertical ? startRadius : startRadius
    topRightRadius: isVertical ? startRadius : endRadius
    bottomLeftRadius: isVertical ? endRadius : startRadius
    bottomRightRadius: isVertical ? endRadius : endRadius
    
    enableShadow: Config.showBackground

    implicitWidth: isVertical ? 36 : dockLayout.implicitWidth + 8
    implicitHeight: isVertical ? dockLayoutVertical.implicitHeight + 8 : 36
    
    Layout.maximumWidth: isVertical ? 36 : -1
    Layout.maximumHeight: isVertical ? -1 : 36

    Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: isVertical ? parent.width : contentContainerHorizontal.width
        contentHeight: isVertical ? contentContainerVertical.height : parent.height
        clip: true
        interactive: true
        boundsBehavior: Flickable.StopAtBounds

        // Horizontal layout container
        Item {
            id: contentContainerHorizontal
            visible: !root.isVertical
            height: parent.height
            width: Math.max(flickable.width, dockLayout.implicitWidth + 8)

            HoverHandler {
                id: horizontalMagnificationHover
                acceptedDevices: PointerDevice.Mouse
                onPointChanged: TaskbarApps.setDockPointer(
                    contentContainerHorizontal, point.position.x, point.position.y, false)
                onHoveredChanged: {
                    if (hovered) {
                        TaskbarApps.setDockPointer(
                            contentContainerHorizontal, point.position.x, point.position.y, false);
                    } else {
                        Qt.callLater(() => {
                            if (!horizontalMagnificationHover.hovered)
                                TaskbarApps.clearDockPointer(contentContainerHorizontal);
                        });
                    }
                }
            }

            RowLayout {
                id: dockLayout
                anchors.centerIn: parent
                spacing: root.itemSpacing

                // App buttons
                Repeater {
                    model: TaskbarApps.apps

                    IntegratedDockAppButton {
                        required property var modelData
                        required property int index
                        appToplevel: modelData
                        dockIndex: index
                        dockEdge: root.magnificationEdge
                        dragLayer: root.isVertical ? contentContainerVertical : contentContainerHorizontal
                        iconSize: root.iconSize
                        Layout.alignment: Qt.AlignVCenter
                        orientation: root.orientation
                    }
                }
            }
        }

        // Vertical layout container
        Item {
            id: contentContainerVertical
            visible: root.isVertical
            width: parent.width
            height: Math.max(flickable.height, dockLayoutVertical.implicitHeight + 8)

            HoverHandler {
                id: verticalMagnificationHover
                acceptedDevices: PointerDevice.Mouse
                onPointChanged: TaskbarApps.setDockPointer(
                    contentContainerVertical, point.position.x, point.position.y, true)
                onHoveredChanged: {
                    if (hovered) {
                        TaskbarApps.setDockPointer(
                            contentContainerVertical, point.position.x, point.position.y, true);
                    } else {
                        Qt.callLater(() => {
                            if (!verticalMagnificationHover.hovered)
                                TaskbarApps.clearDockPointer(contentContainerVertical);
                        });
                    }
                }
            }

            ColumnLayout {
                id: dockLayoutVertical
                anchors.centerIn: parent
                spacing: root.itemSpacing

                // App buttons
                Repeater {
                    model: TaskbarApps.apps

                    IntegratedDockAppButton {
                        required property var modelData
                        required property int index
                        appToplevel: modelData
                        dockIndex: index
                        dockEdge: root.magnificationEdge
                        dragLayer: root.isVertical ? contentContainerVertical : contentContainerHorizontal
                        iconSize: root.iconSize
                        Layout.alignment: Qt.AlignHCenter
                        orientation: root.orientation
                    }
                }
            }
        }
    }
}
