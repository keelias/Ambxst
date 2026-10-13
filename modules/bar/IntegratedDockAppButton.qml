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
    property string dockEdge: "top"

    property int dockIndex: -1

    function updateDockMagnificationHover() {
        if (!magnificationHover.hovered || !(Config.dock?.magnificationEnabled ?? false) ||
                root.isSeparator || root.dockIndex < 0 || !root.dragLayer)
            return;

        const extent = root.isVertical ? root.height : root.width;
        const position = root.isVertical
                ? magnificationHover.point.position.y
                : magnificationHover.point.position.x;
        const offset = position / Math.max(extent, 1) - 0.5;
        const pointer = root.mapToItem(root.dragLayer,
                                       magnificationHover.point.position.x,
                                       magnificationHover.point.position.y);
        TaskbarApps.setDockHover(root.dragLayer, root.dockIndex, offset,
                                 root.isVertical ? pointer.y : pointer.x,
                                 root.isVertical);
    }


    // Use the Button's own hover state as a reliable baseline. HoverHandler
    // refines the pointer offset when available, but cannot be the only trigger.
    onHoveredChanged: {
        if (hovered && (Config.dock?.magnificationEnabled ?? false) &&
                !root.isSeparator && root.dockIndex >= 0 && root.dragLayer) {
            if (magnificationHover.hovered) {
                root.updateDockMagnificationHover();
            } else {
                const center = root.mapToItem(root.dragLayer, root.width / 2, root.height / 2);
                TaskbarApps.setDockPointer(root.dragLayer, center.x, center.y, root.isVertical);
            }
        } else {
            Qt.callLater(() => {
                if (!root.hovered && !magnificationHover.hovered)
                    TaskbarApps.clearDockHover(root.dragLayer, root.dockIndex);
            });
        }
    }

    HoverHandler {
        id: magnificationHover
        acceptedDevices: PointerDevice.Mouse
        onPointChanged: root.updateDockMagnificationHover()
        onHoveredChanged: {
            if (hovered) {
                root.updateDockMagnificationHover();
            } else {
                // Let an adjacent icon claim hover first; don't briefly collapse
                // the magnification wave while crossing the gap between buttons.
                Qt.callLater(() => {
                    if (!magnificationHover.hovered && !root.hovered)
                        TaskbarApps.clearDockHover(root.dragLayer, root.dockIndex);
                });
            }
        }
    }

    readonly property real magnificationFactor: {
        if (!(Config.dock?.magnificationEnabled ?? false) || root.isSeparator ||
                root.dockIndex < 0 || !root.dragLayer ||
                TaskbarApps.dockHoveredGroup !== root.dragLayer ||
                !TaskbarApps.dockPointerActive ||
                TaskbarApps.dockHoverVertical !== root.isVertical)
            return 1.0;

        const maxScale = Math.max(1.1, Math.min(Config.dock?.magnificationScale ?? 1.6, 2.4));
        const influenceRadius = Math.max(root.iconSize * 3.25, root.iconSize + 16);
        const distance = Math.abs(root.dockCenterAlongAxis - TaskbarApps.dockHoverPosition);
        const normalizedDistance = Math.min(distance / influenceRadius, 1);
        const influence = distance < influenceRadius
                ? (1 + Math.cos(Math.PI * normalizedDistance)) / 2
                : 0;
        return 1 + (maxScale - 1) * influence;
    }


    // Extra layout space gives enlarged icons room to spread their neighbours.
    readonly property real magnificationSpread: root.iconSize * Math.max(0, root.magnificationFactor - 1) * 0.2

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
    property var dragPreview: null
    property real dockCenterAlongAxis: 0

    function updateDockCenterAlongAxis() {
        if (!root.dragLayer) {
            root.dockCenterAlongAxis = 0;
            return;
        }
        const center = root.mapToItem(root.dragLayer, root.width / 2, root.height / 2);
        root.dockCenterAlongAxis = root.isVertical ? center.y : center.x;
    }

    onXChanged: root.updateDockCenterAlongAxis()
    onYChanged: root.updateDockCenterAlongAxis()
    onWidthChanged: root.updateDockCenterAlongAxis()
    onHeightChanged: root.updateDockCenterAlongAxis()
    onDragLayerChanged: root.updateDockCenterAlongAxis()
    onParentChanged: root.updateDockCenterAlongAxis()

    Connections {
        target: root.parent
        function onXChanged() { root.updateDockCenterAlongAxis(); }
        function onYChanged() { root.updateDockCenterAlongAxis(); }
        function onWidthChanged() { root.updateDockCenterAlongAxis(); }
        function onHeightChanged() { root.updateDockCenterAlongAxis(); }
    }

    Component.onCompleted: {
        TaskbarApps.registerDockButton(root);
        root.updateDockCenterAlongAxis();
    }
    Component.onDestruction: {
        TaskbarApps.unregisterDockButton(root);
        if (root.dragPreview)
            root.dragPreview.destroy();
    }

    function updateDragPreview() {
        if (!root.dragPreview || !root.dragLayer)
            return;

        const pointer = root.mapToItem(root.dragLayer,
                                       dockDragHandler.centroid.position.x,
                                       dockDragHandler.centroid.position.y);
        root.dragPreview.x = pointer.x - root.dragPreview.width / 2;
        root.dragPreview.y = pointer.y - root.dragPreview.height / 2;
    }

    function destroyDragPreview() {
        if (root.dragPreview) {
            root.dragPreview.destroy();
            root.dragPreview = null;
        }
    }

    Behavior on x {
        enabled: Config.animDuration > 0 && !dockDragHandler.active
        NumberAnimation {
            duration: Math.max(140, Math.min(Config.animDuration, 240))
            easing.type: Easing.OutCubic
        }
    }

    Behavior on y {
        enabled: Config.animDuration > 0 && !dockDragHandler.active
        NumberAnimation {
            duration: Math.max(140, Math.min(Config.animDuration, 240))
            easing.type: Easing.OutCubic
        }
    }

    opacity: dockDragHandler.active ? 0.28 : 1
    z: dockDragHandler.active ? 10 : 0

    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutCubic
        }
    }

    DragHandler {
        id: dockDragHandler
        target: null
        enabled: !root.isSeparator && (root.appToplevel?.pinned ?? false)
        acceptedButtons: Qt.LeftButton
        grabPermissions: PointerHandler.CanTakeOverFromAnything

        onCentroidChanged: {
            if (active) {
                root.lastDragPoint = centroid.position;
                root.updateDragPreview();
            }
        }

        onActiveChanged: {
            if (active) {
                root.lastDragPoint = centroid.position;
                TaskbarApps.beginPinnedDrag(root.appToplevel?.appId ?? "");
                if (root.dragLayer)
                    root.dragPreview = dragPreviewComponent.createObject(root.dragLayer);
                root.updateDragPreview();
            } else {
                if (TaskbarApps.pinnedDragAppId === (root.appToplevel?.appId ?? "")) {
                    const p = root.mapToItem(root.dragLayer, root.lastDragPoint.x, root.lastDragPoint.y);
                    TaskbarApps.finishPinnedDrag(root.dragLayer, p.x, p.y, root.isVertical);
                }
                root.destroyDragPreview();
            }
        }
    }

    Component {
        id: dragPreviewComponent

        Item {
            id: preview
            width: root.iconSize + 14
            height: root.iconSize + 14
            z: 10000
            opacity: 0.96
            scale: 1.04

            StyledRect {
                anchors.fill: parent
                variant: "popup"
                radius: Styling.radius(5)
                enableShadow: true
                enableBorder: true
            }

            Image {
                id: previewIcon
                anchors.centerIn: parent
                width: root.iconSize
                height: root.iconSize
                source: "image://icon/" + (root.desktopEntry?.icon ?? AppSearch.guessIcon(root.appToplevel?.appId ?? ""))
                sourceSize.width: root.iconSize * 2
                sourceSize.height: root.iconSize * 2
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }

            Tinted {
                sourceItem: previewIcon
                anchors.fill: previewIcon
            }

        }
    }

    enabled: !isSeparator
    implicitWidth: isSeparator ? (isVertical ? iconSize : 2) : iconSize + 8 + magnificationSpread
    implicitHeight: isSeparator ? (isVertical ? 2 : iconSize) : iconSize + 8 + magnificationSpread

    Behavior on implicitWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: 110
            easing.type: Easing.OutCubic
        }
    }
    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: 110
            easing.type: Easing.OutCubic
        }
    }

    padding: 0
    topPadding: 0
    bottomPadding: 0
    leftPadding: 0
    rightPadding: 0

    background: Item {
        Rectangle {
            anchors.fill: parent
            radius: Styling.radius(-3)
            color: root.appIsActive ? Styling.srItem("overprimary") : (root.pressed || (root.hovered && !(Config.dock?.magnificationEnabled ?? false))) ? Qt.rgba(Styling.srItem("overprimary").r, Styling.srItem("overprimary").g, Styling.srItem("overprimary").b, 0.15) : "transparent"
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

                    readonly property real edgeLift: root.iconSize * Math.max(0, scale - 1) / 2

                    transform: Translate {
                        x: root.dockEdge === "left" ? appIconContainer.edgeLift
                           : root.dockEdge === "right" ? -appIconContainer.edgeLift : 0
                        y: root.dockEdge === "bottom" ? -appIconContainer.edgeLift
                           : root.dockEdge === "top" ? appIconContainer.edgeLift : 0
                    }

                    Behavior on scale {
                        enabled: Config.animDuration > 0
                        SmoothedAnimation {
                            velocity: 3.5
                            duration: 180
                            reversingMode: SmoothedAnimation.Immediate
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
            icon: (root.appToplevel?.pinned ?? false) ? Icons.unpin : Icons.pin,
            onTriggered: function() {
                TaskbarApps.togglePin(appId);
            }
        }];

        if (root.desktopEntry) {
            items.push({
                text: "Launch New Instance",
                icon: Icons.launch,
                onTriggered: function() {
                    AppSearch.launchApp(root.desktopEntry);
                }
            });
        }

        if (root.appIsRunning) {
            items.push({ isSeparator: true });
            items.push({
                text: root.instanceCount === 1 ? "Close Window" : "Close All Windows",
                icon: Icons.stop,
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
