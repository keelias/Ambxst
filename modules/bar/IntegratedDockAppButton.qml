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
import qs.modules.globals
import qs.config

Button {
    id: root

    required property var appToplevel
    property int lastFocused: -1
    property real iconSize: 18
    property string orientation: "horizontal"

    property int dockIndex: -1

    readonly property real magnificationFactor: {
        if (!(Config.dock?.magnificationEnabled ?? false) || root.isSeparator ||
                root.dockIndex < 0 || !root.dragLayer ||
                TaskbarApps.dockHoveredGroup !== root.dragLayer ||
                TaskbarApps.dockHoveredIndex < 0)
            return 1.0;

        const maxScale = Math.max(1.1, Math.min(Config.dock?.magnificationScale ?? 1.6, 2.4));
        const pointerIndex = TaskbarApps.dockHoveredIndex + TaskbarApps.dockHoverOffset;
        const distance = Math.abs(root.dockIndex - pointerIndex);
        const influence = Math.max(0, 1 - distance / 2.25);
        return 1 + (maxScale - 1) * influence;
    }

    function updateMagnificationHover() {
        if (!magnificationHover.hovered || !(Config.dock?.magnificationEnabled ?? false) ||
                root.dockIndex < 0 || !root.dragLayer)
            return;

        const extent = root.isVertical ? root.height : root.width;
        const position = root.isVertical
                ? magnificationHover.point.position.y
                : magnificationHover.point.position.x;
        const offset = position / Math.max(extent, 1) - 0.5;
        TaskbarApps.setDockHover(root.dragLayer, root.dockIndex, offset);

        if (root.magnificationFactor <= 1.001)
            console.log("[Ambxst dock] hover tracked but scale inactive", root.appToplevel?.appId,
                        "enabled:", Config.dock?.magnificationEnabled,
                        "group:", root.dragLayer !== null, "index:", root.dockIndex);
    }

    HoverHandler {
        id: magnificationHover
        acceptedDevices: PointerDevice.Mouse
        onPointChanged: root.updateMagnificationHover()
        onHoveredChanged: {
            if (hovered) {
                root.updateMagnificationHover();
                console.log("[Ambxst dock] magnification hover", root.appToplevel?.appId,
                            "enabled:", Config.dock?.magnificationEnabled,
                            "index:", root.dockIndex);
            } else {
                TaskbarApps.clearDockHover(root.dragLayer, root.dockIndex);
            }
        }
    }

    readonly property bool isVertical: orientation === "vertical"
    readonly property bool isSeparator: appToplevel?.appId === "SEPARATOR"
    readonly property var desktopEntry: (isSeparator || !appToplevel) ? null : DesktopEntries.heuristicLookup(appToplevel.appId)
    readonly property bool appIsActive: !isSeparator && (appToplevel?.toplevels?.some(t => t.activated === true) ?? false)
    readonly property bool appIsRunning: !isSeparator && (appToplevel?.toplevelCount ?? 0) > 0

    readonly property bool showIndicators: !isSeparator && (Config.dock?.showRunningIndicators ?? true) && appIsRunning
    readonly property int instanceCount: (isSeparator || !appToplevel) ? 0 : appToplevel.toplevelCount
    readonly property real indicatorDotSize: 4


    property Item dragLayer: null
    property point lastDragPoint: Qt.point(0, 0)

    Component.onCompleted: TaskbarApps.registerDockButton(root)
    Component.onDestruction: TaskbarApps.unregisterDockButton(root)

    DragHandler {
        id: dockDragHandler
        target: null
        enabled: !root.isSeparator && (root.appToplevel?.pinned ?? false)
        acceptedButtons: Qt.LeftButton
        grabPermissions: PointerHandler.CanTakeOverFromAnything

        onCentroidChanged: {
            if (active)
                root.lastDragPoint = centroid.position;
        }

        onActiveChanged: {
            if (active) {
                root.lastDragPoint = centroid.position;
                TaskbarApps.beginPinnedDrag(root.appToplevel?.appId ?? "");
            } else if (TaskbarApps.pinnedDragAppId === (root.appToplevel?.appId ?? "")) {
                const p = root.mapToItem(root.dragLayer, root.lastDragPoint.x, root.lastDragPoint.y);
                TaskbarApps.finishPinnedDrag(root.dragLayer, p.x, p.y, root.isVertical);
            }
        }
    }

    enabled: !isSeparator
    implicitWidth: isSeparator ? (isVertical ? iconSize : 2) : iconSize + 8
    implicitHeight: isSeparator ? (isVertical ? 2 : iconSize) : iconSize + 8

    padding: 0
    topPadding: 0
    bottomPadding: 0
    leftPadding: 0
    rightPadding: 0

    background: Item {
        Rectangle {
            anchors.fill: parent
            radius: Styling.radius(-3)
            color: root.appIsActive ? Styling.srItem("overprimary") : (root.hovered || root.pressed) ? Qt.rgba(Styling.srItem("overprimary").r, Styling.srItem("overprimary").g, Styling.srItem("overprimary").b, 0.15) : "transparent"
            opacity: root.pressed ? 1 : (root.appIsActive ? 0.3 : 0.7)

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration / 2
                }
            }
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }
    }

    contentItem: Item {
        // Separator
        Loader {
            active: root.isSeparator
            anchors.centerIn: parent
            sourceComponent: Separator {
                vert: !root.isVertical
                implicitWidth: root.isVertical ? root.iconSize : 2
                implicitHeight: root.isVertical ? 2 : root.iconSize
            }
        }

        // App icon and indicators
        Loader {
            active: !root.isSeparator
            anchors.fill: parent
            sourceComponent: Item {
                anchors.fill: parent


                // App icon container
                Item {
                    id: appIconContainer
                    anchors.centerIn: parent
                    width: root.iconSize
                    height: root.iconSize
                    scale: root.magnificationFactor
                    transformOrigin: Item.Center
                    Behavior on scale {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Math.max(80, Config.animDuration / 3)
                            easing.type: Easing.OutCubic
                        }
                    }

                    readonly property string iconName: {
                        if (root.desktopEntry && root.desktopEntry.icon) {
                            return root.desktopEntry.icon;
                        }
                        return AppSearch.guessIcon(root.appToplevel?.appId ?? "");
                    }

                    Image {
                        mipmap: true
                        id: appIcon
                        anchors.fill: parent
                        source: "image://icon/" + appIconContainer.iconName
                        sourceSize.width: root.iconSize * 2
                        sourceSize.height: root.iconSize * 2
                        fillMode: Image.PreserveAspectFit
                    }

                    Tinted {
                        sourceItem: appIcon
                        anchors.fill: appIcon
                    }
                }

                // Running indicators - horizontal (for horizontal bar)
                Row {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -2
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    visible: root.showIndicators && !root.isVertical

                    Repeater {
                        model: Math.min(root.instanceCount, 3)
                        delegate: Rectangle {
                            required property int index
                            width: root.instanceCount <= 3 ? 6 : root.indicatorDotSize
                            height: root.indicatorDotSize
                            radius: height / 2
                            color: root.appIsActive ? Styling.srItem("overprimary") : Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.4)

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                }
                            }
                        }
                    }
                }

                // Running indicators - vertical (for vertical bar)
                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: -2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    visible: root.showIndicators && root.isVertical

                    Repeater {
                        model: Math.min(root.instanceCount, 3)
                        delegate: Rectangle {
                            required property int index
                            width: root.indicatorDotSize
                            height: root.instanceCount <= 3 ? 6 : root.indicatorDotSize
                            radius: width / 2
                            color: root.appIsActive ? Styling.srItem("overprimary") : Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.4)

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Left click: launch or cycle through windows
    onClicked: {
        if (isSeparator)
            return;

        if (appToplevel.toplevelCount === 0) {
            // Launch the app
            if (desktopEntry) {
                AppSearch.launchApp(desktopEntry);
            }
            return;
        }

        // Cycle through running windows
        lastFocused = (lastFocused + 1) % appToplevel.toplevelCount;
        appToplevel.toplevels[lastFocused].activate();
    }

    function showAppContextMenu() {
        const appId = root.appToplevel?.appId ?? "";
        const items = [{
            text: (root.appToplevel?.pinned ?? false) ? "Unpin from Dock" : "Pin to Dock",
            onTriggered: function() {
                TaskbarApps.togglePin(appId);
            }
        }];

        if (root.desktopEntry) {
            items.push({
                text: "Launch New Instance",
                onTriggered: function() {
                    AppSearch.launchApp(root.desktopEntry);
                }
            });
        }

        if (root.appIsRunning) {
            items.push({ isSeparator: true });
            items.push({
                text: root.instanceCount === 1 ? "Close Window" : "Close All Windows",
                onTriggered: function() {
                    const windows = (root.appToplevel?.toplevels ?? []).slice();
                    windows.forEach(window => {
                        if (window && typeof window.close === "function")
                            window.close();
                    });
                }
            });
        }

        Visibilities.contextMenu?.openCustomMenu(items, 190, 32, "dock");
    }

    // Middle click: always launch new instance
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.RightButton

        onClicked: mouse => {
            if (root.isSeparator)
                return;

            if (mouse.button === Qt.MiddleButton) {
                // Launch new instance
                if (root.desktopEntry) {
                    AppSearch.launchApp(root.desktopEntry);
                }
            } else if (mouse.button === Qt.RightButton) {
                root.showAppContextMenu();
            }
        }
    }


    // Tooltip
    StyledToolTip {
        show: root.hovered && !root.isSeparator
        tooltipText: root.desktopEntry?.name ?? root.appToplevel?.appId ?? ""
    }
}
