import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

/**
 * Inline player for video booru posts. QtMultimedia streams the remote file
 * directly (checked against e621's CDN), so there is nothing to download first.
 * Rounded corners come from the ClippingRectangle this sits inside.
 */
Item {
    id: root
    required property string url
    property bool controlsShown: false
    property bool muted: false
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState

    function togglePlay() {
        if (root.playing) player.pause()
        else player.play()
    }

    VideoOutput {
        id: videoOut
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
    }

    MediaPlayer {
        id: player
        videoOutput: videoOut
        audioOutput: AudioOutput {
            muted: root.muted
        }
        loops: MediaPlayer.Infinite
        source: root.url
        Component.onCompleted: play()
        onErrorOccurred: (error, errorString) => {
            console.log("[BooruVideo] playback failed:", errorString, root.url)
        }
    }

    Item { // Controls, faded in while the card is hovered
        anchors.fill: parent
        opacity: root.controlsShown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
            }
        }

        component OverlayButton: RippleButton {
            buttonRadius: Appearance.rounding.full
            colBackground: Qt.rgba(0, 0, 0, 0.55)
            colBackgroundHover: Qt.rgba(0, 0, 0, 0.75)
            colRipple: Qt.rgba(1, 1, 1, 0.2)
        }

        OverlayButton {
            anchors.centerIn: parent
            padding: 0
            implicitWidth: 56
            implicitHeight: 56
            contentItem: MaterialSymbol {
                horizontalAlignment: Text.AlignHCenter
                iconSize: Appearance.font.pixelSize.huge
                color: "white"
                text: root.playing ? "pause" : "play_arrow"
            }
            onClicked: root.togglePlay()
        }

        OverlayButton {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 8
            implicitWidth: 30
            implicitHeight: 30
            contentItem: MaterialSymbol {
                horizontalAlignment: Text.AlignHCenter
                iconSize: Appearance.font.pixelSize.large
                color: "white"
                text: root.muted ? "volume_off" : "volume_up"
            }
            onClicked: root.muted = !root.muted
        }

        Rectangle { // Seek bar, inset so its corners aren't cut by the card's rounding
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.bottomMargin: 6
            implicitHeight: 34
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.85)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    color: "white"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    text: StringUtils.friendlyTimeForSeconds(player.position / 1000)
                }

                StyledSlider {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    configuration: StyledSlider.Configuration.Wavy
                    wavy: false
                    usePercentTooltip: false
                    tooltipContent: StringUtils.friendlyTimeForSeconds(value / 1000)
                    from: 0
                    to: Math.max(1, player.duration)
                    value: player.position
                    onMoved: player.position = value
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    color: "white"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    text: StringUtils.friendlyTimeForSeconds(player.duration / 1000)
                }
            }
        }
    }
}
