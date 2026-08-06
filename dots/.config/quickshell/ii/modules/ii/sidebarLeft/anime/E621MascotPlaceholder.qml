import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

/**
 * Empty-state art for the e621 provider: one of the mascots from e621's own front
 * page, credited to its artist.
 */
Item {
    id: root

    // The view this stands in for is empty. Kept separate from `shown` so a mascot
    // arriving (or being swapped) never re-triggers the reroll below.
    property bool viewEmpty: true
    readonly property var mascot: Booru.e621Mascot
    readonly property bool mascotReady: mascot !== null && mascotImage.status === Image.Ready
    // Latched: the generic placeholder holds the spot until the first mascot decodes,
    // and later shuffles then swap art inside the card instead of collapsing it.
    property bool hasArt: false
    readonly property bool hasArtistLink: (mascot?.artist_url ?? "").startsWith("http")
    // The art has e621's own backdrop baked in, so the card wears the matching color:
    // non-square mascots then letterbox invisibly instead of showing bars.
    readonly property color mascotBackground: mascot?.background_color ?? Appearance.colors.colLayer2

    readonly property bool shown: viewEmpty && hasArt
    opacity: shown ? 1 : 0
    visible: opacity > 0
    anchors {
        fill: parent
        topMargin: -30 * (1 - opacity)
        bottomMargin: 30 * (1 - opacity)
    }

    Behavior on opacity {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }

    onMascotReadyChanged: if (root.mascotReady) root.hasArt = true

    // Nothing is fetched while there are results to look at, and every trip back to an
    // empty view brings a fresh mascot rather than one per session.
    function requestMascot() {
        if (!root.viewEmpty) return;
        Booru.fetchE621Mascots();
        Booru.shuffleE621Mascot();
    }
    Component.onCompleted: root.requestMascot()
    onViewEmptyChanged: root.requestMascot()

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        Item { // Mascot card
            id: mascotCard
            Layout.alignment: Qt.AlignHCenter
            // Bounded on both axes so the card can never outgrow the panel.
            implicitWidth: Math.max(0, Math.min(root.width - 80, root.height - 160, 260))
            implicitHeight: implicitWidth

            HoverHandler {
                id: cardHover
            }

            StyledRectangularShadow {
                target: cardBackground
            }

            ClippingRectangle {
                id: cardBackground
                anchors.fill: parent
                radius: Appearance.rounding.large
                color: root.mascotBackground

                StyledImage {
                    id: mascotImage
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    source: root.mascot?.url_path ?? ""
                }
            }

            RippleButton { // Another one, please
                id: shuffleButton
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    margins: 8
                }
                implicitWidth: 34
                implicitHeight: 34
                buttonRadius: Appearance.rounding.full
                colBackground: Qt.rgba(0, 0, 0, 0.45)
                colBackgroundHover: Qt.rgba(0, 0, 0, 0.65)
                colRipple: Qt.rgba(1, 1, 1, 0.2)

                // Discoverable on hover, out of the way otherwise.
                opacity: (cardHover.hovered || shuffleButton.hovered) ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.font.pixelSize.large
                    color: "white"
                    text: "casino"
                }

                StyledToolTip {
                    text: Translation.tr("Show another mascot")
                }

                onClicked: Booru.shuffleE621Mascot()
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            font {
                family: Appearance.font.family.title
                pixelSize: Appearance.font.pixelSize.larger
                variableAxes: Appearance.font.variableAxes.title
            }
            color: Appearance.m3colors.m3outline
            horizontalAlignment: Text.AlignHCenter
            text: "e621"
        }

        MouseArea { // Artist credit
            id: creditArea
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: creditRow.implicitWidth
            implicitHeight: creditRow.implicitHeight
            visible: (root.mascot?.artist_name ?? "").length > 0

            hoverEnabled: true
            cursorShape: root.hasArtistLink ? Qt.PointingHandCursor : Qt.ArrowCursor
            // StyledToolTip looks for this on its parent.
            readonly property bool hovered: containsMouse

            // Without the dispatches the cursor gets warped to whatever window opens.
            onClicked: {
                if (!root.hasArtistLink) return;
                Hyprland.dispatch("hl.config({cursor = {no_warps = true}})");
                Qt.openUrlExternally(root.mascot.artist_url);
                Hyprland.dispatch("hl.config({cursor = {no_warps = false}})");
            }

            RowLayout {
                id: creditRow
                anchors.centerIn: parent
                spacing: 4

                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: (creditArea.containsMouse && root.hasArtistLink)
                        ? Appearance.colors.colOnLayer1 : Appearance.m3colors.m3outline
                    text: Translation.tr("Art by %1").arg(root.mascot?.artist_name ?? "")
                }
                MaterialSymbol {
                    visible: root.hasArtistLink
                    iconSize: Appearance.font.pixelSize.normal
                    color: creditArea.containsMouse ? Appearance.colors.colOnLayer1 : Appearance.m3colors.m3outline
                    text: "open_in_new"
                }
            }

            StyledToolTip {
                extraVisibleCondition: root.hasArtistLink
                text: root.mascot?.artist_url ?? ""
            }
        }
    }
}
