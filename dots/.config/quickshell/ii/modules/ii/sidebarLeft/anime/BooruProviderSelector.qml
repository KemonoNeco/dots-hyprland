import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Picks the booru API provider. `/mode PROVIDER` still does the same thing
 * from the input field; this just makes it a visible, one-click choice.
 */
RippleButton {
    id: root

    readonly property var provider: Booru.providers[Booru.currentProvider]

    horizontalPadding: 8
    verticalPadding: 4
    buttonRadius: Appearance.rounding.small
    colBackground: Appearance.colors.colLayer2
    colBackgroundHover: Appearance.colors.colLayer2Hover

    onClicked: providerMenu.opened ? providerMenu.close() : providerMenu.open()

    contentItem: RowLayout {
        spacing: 2

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnLayer2
            text: "api"
        }
        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 3
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer2
            elide: Text.ElideRight
            animateChange: true
            text: root.provider.name
        }
        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer2
            text: providerMenu.opened ? "arrow_drop_up" : "arrow_drop_down"
        }
    }

    StyledToolTip {
        extraVisibleCondition: !providerMenu.opened
        text: Translation.tr("Current API endpoint: %1").arg(root.provider.url)
    }

    // The control row sits at the bottom of the sidebar, so the menu opens
    // upwards; a Popup is what lets it escape the input box's clipping.
    Popup {
        id: providerMenu
        parent: root
        padding: 0
        width: 280
        x: 0
        y: -height - 6
        // Not CloseOnPressOutside: that fires on the press and onClicked would
        // then immediately reopen the menu.
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        background: Rectangle {
            radius: Appearance.rounding.small
            color: Appearance.m3colors.m3surfaceContainer
        }

        contentItem: ColumnLayout {
            spacing: 0

            Repeater {
                model: Booru.providerList

                delegate: RippleButton {
                    id: providerItem
                    required property var modelData
                    readonly property bool isCurrent: modelData === Booru.currentProvider

                    Layout.fillWidth: true
                    buttonRadius: 0
                    horizontalPadding: 12
                    verticalPadding: 8
                    toggled: isCurrent
                    colBackgroundToggled: Appearance.colors.colSecondaryContainer
                    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover

                    onClicked: {
                        Booru.setProvider(providerItem.modelData);
                        providerMenu.close();
                    }

                    contentItem: RowLayout {
                        spacing: 8

                        MaterialSymbol { // Kept in layout when hidden, so the names stay aligned
                            Layout.alignment: Qt.AlignVCenter
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnSecondaryContainer
                            opacity: providerItem.isCurrent ? 1 : 0
                            text: "check"
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: providerItem.isCurrent ? Appearance.colors.colOnSecondaryContainer : Appearance.m3colors.m3onSurface
                                elide: Text.ElideRight
                                text: Booru.providers[providerItem.modelData].name
                            }
                            StyledText {
                                Layout.fillWidth: true
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                                wrapMode: Text.Wrap
                                text: Booru.providers[providerItem.modelData].description
                            }
                        }
                    }
                }
            }
        }
    }
}
