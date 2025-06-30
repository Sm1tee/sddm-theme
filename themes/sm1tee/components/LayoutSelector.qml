import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ColumnLayout {
    id: selector
    width: Config.layoutPopupWidth - (Config.menuAreaPopupsPadding * 2)

    signal layoutChanged(layoutIndex: int)
    signal close

    property int currentLayoutIndex: (keyboard && keyboard.layouts && keyboard.layouts.length > 0) ? keyboard.currentLayout : 0
    property string layoutName: ""
    property string layoutShortName: ""
    
    // FIX: Добавляем функцию принудительного обновления
    function forceUpdate() {
        console.log("LayoutSelector: Force updating layouts");
        if (keyboard && keyboard.layouts) {
            console.log("LayoutSelector: Found", keyboard.layouts.length, "layouts");
            // Принудительно обновляем модель
            layoutList.model = null;
            layoutList.model = keyboard.layouts;
            
            // Обновляем текущий индекс
            selector.currentLayoutIndex = keyboard.currentLayout;
            updateLayout();
        } else {
            console.log("LayoutSelector: No keyboard or layouts found");
        }
    }

    function updateLayout() {
        if (keyboard && keyboard.layouts && selector.currentLayoutIndex >= 0 && selector.currentLayoutIndex < keyboard.layouts.length) {
            keyboard.currentLayout = selector.currentLayoutIndex;
            selector.layoutName = keyboard.layouts[selector.currentLayoutIndex].longName;
            selector.layoutShortName = keyboard.layouts[selector.currentLayoutIndex].shortName;
            console.log("LayoutSelector: Updated to layout", selector.currentLayoutIndex, ":", selector.layoutShortName);
        }
        selector.layoutChanged(selector.currentLayoutIndex);
    }

    Component.onCompleted: {
        console.log("LayoutSelector: Component completed");
        // FIX: Принудительное обновление при создании компонента
        Qt.callLater(function() {
            forceUpdate();
        });
        
        selector.layoutName = keyboard && keyboard.layouts && keyboard.layouts.length > 0 ? keyboard.layouts[selector.currentLayoutIndex].longName : "";
        selector.layoutShortName = keyboard && keyboard.layouts && keyboard.layouts.length > 0 ? keyboard.layouts[selector.currentLayoutIndex].shortName : "";
        selector.layoutChanged(selector.currentLayoutIndex);
    }

    // FIX: Добавляем связь для отслеживания изменений раскладок
    Connections {
        target: keyboard
        function onLayoutsChanged() {
            console.log("LayoutSelector: Keyboard layouts changed");
            forceUpdate();
        }
        function onCurrentLayoutChanged() {
            console.log("LayoutSelector: Current layout changed to", keyboard.currentLayout);
            selector.currentLayoutIndex = keyboard.currentLayout;
            updateLayout();
        }
    }

    Text {
        id: noLayoutMessage
        Layout.preferredWidth: parent.width - 5
        text: "No keyboard layout could be found. This is a known issue with Wayland."
        visible: keyboard == undefined || !keyboard.layouts || keyboard.layouts.length === 0
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        color: Config.menuAreaPopupsContentColor
        font.pixelSize: Config.menuAreaPopupsFontSize
        font.family: Config.menuAreaPopupsFontFamily
        padding: 10
    }

    ListView {
        id: layoutList
        visible: !noLayoutMessage.visible
        Layout.preferredWidth: parent.width
        Layout.preferredHeight: Math.min((keyboard && keyboard.layouts ? keyboard.layouts.length : 0) * (Config.menuAreaPopupsItemHeight + 5 + spacing) - spacing, Config.menuAreaPopupsMaxHeight)
        orientation: ListView.Vertical
        interactive: true
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: Config.menuAreaPopupsSpacing
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 0

        contentHeight: (keyboard && keyboard.layouts ? keyboard.layouts.length : 0) * (Config.menuAreaPopupsItemHeight + 5 + spacing) - spacing

        ScrollBar.vertical: ScrollBar {
            id: scrollbar
            policy: Config.menuAreaPopupsDisplayScrollbar && layoutList.contentHeight > layoutList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            contentItem: Rectangle {
                implicitWidth: 5
                radius: 5
                color: Config.menuAreaPopupsContentColor
                opacity: Config.menuAreaPopupsActiveOptionBackgroundOpacity
            }
        }

        model: keyboard && keyboard.layouts ? keyboard.layouts : []

        delegate: Rectangle {
            width: scrollbar.visible ? selector.width - Config.menuAreaPopupsPadding - scrollbar.width : selector.width
            height: childrenRect.height
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                color: Config.menuAreaPopupsActiveOptionBackgroundColor
                opacity: index === currentLayoutIndex ? Config.menuAreaPopupsActiveOptionBackgroundOpacity : (mouseArea.containsMouse ? Config.menuAreaPopupsActiveOptionBackgroundOpacity : 0.0)
                radius: 5
            }

            RowLayout {
                width: parent.width
                height: Config.menuAreaPopupsItemHeight + 5
                spacing: 0

                Rectangle {
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    Layout.preferredHeight: parent.height
                    Layout.preferredWidth: Layout.preferredHeight
                    color: "transparent"

                    Image {
                        anchors.centerIn: parent
                        // FIX: Улучшаем путь к флагам и добавляем fallback
                        source: {
                            var flagPath = `/usr/share/sddm/flags/${shortName}.png`;
                            // Альтернативные пути для флагов
                            if (!Qt.resolvedUrl(flagPath)) {
                                flagPath = `/usr/share/flags/${shortName}.png`;
                            }
                            if (!Qt.resolvedUrl(flagPath)) {
                                flagPath = `/usr/share/pixmaps/flags/${shortName}.png`;
                            }
                            return flagPath;
                        }
                        width: Config.menuAreaPopupsIconSize
                        height: width
                        sourceSize: Qt.size(width, height)
                        fillMode: Image.PreserveAspectFit
                        // FIX: Добавляем fallback для случая, когда флаг не найден
                        onStatusChanged: {
                            if (status === Image.Error) {
                                // Используем текстовую замену, если изображение не найдено
                                visible = false;
                            }
                        }
                    }
                    
                    // FIX: Текстовая замена для флага, если изображение не найдено
                    Text {
                        anchors.centerIn: parent
                        text: shortName ? shortName.toUpperCase() : ""
                        visible: parent.children[0].status === Image.Error
                        color: index === currentLayoutIndex || mouseArea.containsMouse ? Config.menuAreaPopupsActiveContentColor : Config.menuAreaPopupsContentColor
                        font.pixelSize: Config.menuAreaPopupsFontSize - 4
                        font.family: Config.menuAreaPopupsFontFamily
                        font.weight: Font.Bold
                    }
                }

                Column {
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    Layout.fillWidth: true

                    Text {
                        width: parent.width
                        // FIX: Улучшаем получение имени языка
                        text: {
                            var label = Languages.getLabelFor(shortName);
                            if (!label || label.length === 0) {
                                // Fallback к короткому имени, если нет перевода
                                return shortName ? shortName.toUpperCase() : "";
                            }
                            return label;
                        }
                        visible: text && text.length > 0
                        color: index === currentLayoutIndex || mouseArea.containsMouse ? Config.menuAreaPopupsActiveContentColor : Config.menuAreaPopupsContentColor
                        font.pixelSize: Config.menuAreaPopupsFontSize
                        font.family: Config.menuAreaPopupsFontFamily
                        elide: Text.ElideRight
                        rightPadding: 10
                    }

                    Text {
                        width: parent.width
                        text: longName || shortName || "Unknown Layout"
                        color: index === currentLayoutIndex || mouseArea.containsMouse ? Config.menuAreaPopupsActiveContentColor : Config.menuAreaPopupsContentColor
                        opacity: 0.75
                        font.pixelSize: Config.menuAreaPopupsFontSize - 2
                        font.family: Config.menuAreaPopupsFontFamily
                        elide: Text.ElideRight
                        rightPadding: 10
                    }
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                enabled: index !== selector.currentLayoutIndex
                hoverEnabled: index !== selector.currentLayoutIndex
                z: 2
                cursorShape: hoverEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    console.log("LayoutSelector: Clicked layout", index, ":", shortName);
                    selector.currentLayoutIndex = index;
                    selector.updateLayout();
                }
            }
        }
    }
    
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Down) {
            if (keyboard && keyboard.layouts && keyboard.layouts.length > 0) {
                selector.currentLayoutIndex = (selector.currentLayoutIndex + keyboard.layouts.length + 1) % keyboard.layouts.length;
                selector.updateLayout();
            }
        } else if (event.key === Qt.Key_Up) {
            if (keyboard && keyboard.layouts && keyboard.layouts.length > 0) {
                selector.currentLayoutIndex = (selector.currentLayoutIndex + keyboard.layouts.length - 1) % keyboard.layouts.length;
                selector.updateLayout();
            }
        } else if (event.key == Qt.Key_Return || event.key == Qt.Key_Enter || event.key === Qt.Key_Space) {
            selector.close();
        } else if (event.key === Qt.Key_CapsLock) {
            root.capsLockOn = !root.capsLockOn;
        }
    }
}