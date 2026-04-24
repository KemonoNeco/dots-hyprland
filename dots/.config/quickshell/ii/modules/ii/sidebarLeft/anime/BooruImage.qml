import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.utils
import qs.modules.common.widgets
import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets

Button {
    id: root
    // Click anywhere on the thumbnail to start video playback; click again to toggle play/pause.
    onClicked: {
        if (!isVideo) return
        if (!(videoCached && videoPlayRequested)) {
            videoPlayRequested = true
            startVideoDownload()
            return
        }
        if (mediaLoader.item && mediaLoader.item.togglePlay) mediaLoader.item.togglePlay()
    }
    property var imageData
    property var rowHeight
    property bool manualDownload: false
    property string previewDownloadPath
    property string downloadPath
    property string nsfwPath
    property string fileName: {
        const url = imageData.file_url ?? ""
        if (!url) return `${imageData.id ?? "unknown"}.${imageData.file_ext ?? "bin"}`
        return decodeURIComponent(url.substring(url.lastIndexOf('/') + 1))
    }
    property string filePath: `${root.previewDownloadPath}/${root.fileName}`
    property int maxTagStringLineLength: 50
    property int maxTooltipTags: 30
    property string tooltipTagText: {
        const all = (imageData.tags ?? "").split(" ").filter(t => t.length > 0)
        if (all.length <= maxTooltipTags) return StringUtils.wordWrap(all.join(" "), maxTagStringLineLength)
        const shown = all.slice(0, maxTooltipTags).join(" ")
        const extra = all.length - maxTooltipTags
        return StringUtils.wordWrap(shown, maxTagStringLineLength) + `\n…(+${extra} more tags)`
    }
    property real imageRadius: Appearance.rounding.small

    property string fileExt: (imageData.file_ext ?? "").toLowerCase()
    // For videos/GIFs, sample_url is often a static JPEG preview — always use file_url for playback.
    property bool _isVideoExt: ["webm", "mp4", "mov", "m4v"].includes(fileExt)
    property bool _isGifExt: fileExt === "gif"
    property string playableUrl: (_isVideoExt || _isGifExt)
        ? (imageData.file_url || "")
        : (imageData.sample_url || imageData.file_url || "")
    property bool isVideo: _isVideoExt && playableUrl.length > 0
    property bool isGif: _isGifExt && playableUrl.length > 0
    property bool isBlacklisted: !!imageData.is_blacklisted
    // Reactive binding: re-evaluates when Config or KeyringStorage data changes.
    property bool isE621Provider: Booru.currentProvider === "e621"
    property bool e621AuthConfigured: {
        if (Booru.currentProvider !== "e621") return false
        const username = Config.options?.sidebar?.booru?.e621?.username
        const apiKey = KeyringStorage.keyringData?.apiKeys?.e621
        return !!(username && username !== "[unset]" && apiKey && apiKey.length > 0)
    }

    // Inline video cache: QtMultimedia struggles with some remote streams (e621 CDN),
    // so we cache the file locally first and play from disk.
    property string videoCacheDir: "/tmp/quickshell/booru-videos"
    property string videoCacheName: `${imageData.md5 || imageData.id || Qt.md5(playableUrl)}.${fileExt || "bin"}`
    property string videoCachePath: `${videoCacheDir}/${videoCacheName}`
    property bool videoPlayRequested: false
    property bool videoCached: false
    property bool videoDownloading: false
    property bool videoMuted: false

    property bool showActions: false
    ImageDownloaderProcess {
        id: imageDownloader
        running: root.manualDownload
        filePath: root.filePath
        sourceUrl: root.imageData.preview_url ?? root.imageData.sample_url
        onDone: (path, width, height) => {
            if (stillLoader.item && stillLoader.item.resetSource) {
                stillLoader.item.resetSource(path)
            }
            if (!modelData.width || !modelData.height) {
                modelData.width = width
                modelData.height = height
                modelData.aspect_ratio = width / height
            }
        }
    }

    Process {
        id: videoDownloader
        running: false
        command: ["bash", "-c",
            `set -e; `
            + `mkdir -p '${root.videoCacheDir}'; `
            + `if [ ! -s '${root.videoCachePath}' ]; then `
            + `  curl -fsSL -A 'illogical-impulse-sidebar/1.0' '${root.playableUrl}' -o '${root.videoCachePath}.part' && `
            + `  mv '${root.videoCachePath}.part' '${root.videoCachePath}'; `
            + `fi; `
            + `[ -s '${root.videoCachePath}' ] && echo DONE || echo FAIL`
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.videoDownloading = false
                const result = text.trim()
                if (result === "DONE") {
                    console.log("[BooruImage] video cached:", root.videoCachePath)
                    root.videoCached = true
                } else {
                    console.log("[BooruImage] video download failed:", result, "url:", root.playableUrl)
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim()
                if (err.length > 0) console.log("[BooruImage] video download stderr:", err)
            }
        }
    }

    function startVideoDownload() {
        if (root.videoDownloading || root.videoCached || !root.playableUrl) return
        root.videoDownloading = true
        videoDownloader.running = true
    }

    StyledToolTip {
        text: root.tooltipTagText
    }

    padding: 0
    // Blacklisted posts are hidden entirely (zero width so the flow layout skips them).
    visible: !isBlacklisted
    implicitWidth: isBlacklisted ? 0 : (root.rowHeight * modelData.aspect_ratio)
    implicitHeight: isBlacklisted ? 0 : root.rowHeight

    background: Rectangle {
        implicitWidth: root.rowHeight * modelData.aspect_ratio
        implicitHeight: root.rowHeight
        radius: imageRadius
        color: Appearance.colors.colLayer2
    }

    contentItem: ClippingRectangle {
        anchors.fill: parent
        color: "transparent"
        radius: root.imageRadius
        opacity: root.isBlacklisted ? 0.3 : 1.0
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
            }
        }

        // Still preview — always shown underneath (acts as a poster for video/gif until hover).
        Loader {
            id: stillLoader
            anchors.fill: parent
            active: true
            sourceComponent: Component {
                StyledImage {
                    id: imageObject
                    anchors.fill: parent
                    width: root.rowHeight * modelData.aspect_ratio
                    height: root.rowHeight
                    fillMode: Image.PreserveAspectFit
                    source: modelData.preview_url ?? ""
                    sourceSize.width: root.rowHeight * modelData.aspect_ratio
                    sourceSize.height: root.rowHeight

                    function resetSource(newSource) {
                        source = ""
                        source = newSource
                    }

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: root.rowHeight * modelData.aspect_ratio
                            height: root.rowHeight
                            radius: imageRadius
                        }
                    }
                }
            }
        }

        // GIFs autoplay; videos play once cached + requested.
        Loader {
            id: mediaLoader
            anchors.fill: parent
            active: root.isGif || (root.isVideo && root.videoCached && root.videoPlayRequested)
            sourceComponent: root.isVideo ? videoComponent : gifComponent
        }

        Component {
            id: gifComponent
            AnimatedImage {
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                playing: true
                source: root.playableUrl
                sourceSize.width: root.rowHeight * modelData.aspect_ratio
                sourceSize.height: root.rowHeight
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: root.rowHeight * modelData.aspect_ratio
                        height: root.rowHeight
                        radius: imageRadius
                    }
                }
            }
        }

        Component {
            id: videoComponent
            Item {
                id: videoRoot
                anchors.fill: parent
                property bool controlsVisible: root.hovered
                property bool isPlaying: mediaPlayer.playbackState === MediaPlayer.PlayingState
                property bool userSeeking: false
                property real seekValue: 0

                function togglePlay() {
                    if (mediaPlayer.playbackState === MediaPlayer.PlayingState) mediaPlayer.pause()
                    else mediaPlayer.play()
                }

                // Actual VideoOutput — kept off-screen / visible: false so Qt's hardware
                // video path renders into it, then ShaderEffectSource mirrors it into a
                // normal QQuickItem texture that CAN be clipped to rounded corners.
                VideoOutput {
                    id: videoOut
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectFit
                    visible: false
                    layer.enabled: true
                }
                ShaderEffectSource {
                    id: videoMirror
                    anchors.fill: parent
                    sourceItem: videoOut
                    hideSource: true
                    live: true
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: videoMirror.width
                            height: videoMirror.height
                            radius: root.imageRadius
                        }
                    }
                }
                MediaPlayer {
                    id: mediaPlayer
                    videoOutput: videoOut
                    audioOutput: AudioOutput { id: videoAudio; muted: root.videoMuted }
                    loops: MediaPlayer.Infinite
                    source: root.videoCached ? `file://${root.videoCachePath}` : root.playableUrl
                    Component.onCompleted: if (source.toString().length > 0) play()
                    onErrorOccurred: (error, errorString) => {
                        console.log("[BooruImage] video error:", error, errorString, "src:", source)
                    }
                }

                // Controls overlay — fades in on hover.
                Item {
                    id: controlsOverlay
                    anchors.fill: parent
                    opacity: videoRoot.controlsVisible ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                        }
                    }

                    // Center play/pause button
                    RippleButton {
                        id: playPauseButton
                        anchors.centerIn: parent
                        implicitWidth: 56
                        implicitHeight: 56
                        padding: 0
                        buttonRadius: Appearance.rounding.full
                        colBackground: Qt.rgba(0, 0, 0, 0.55)
                        colBackgroundHover: Qt.rgba(0, 0, 0, 0.75)
                        colRipple: Qt.rgba(1, 1, 1, 0.2)
                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: videoRoot.isPlaying ? "pause" : "play_arrow"
                                iconSize: Appearance.font.pixelSize.huge
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        onClicked: {
                            if (videoRoot.isPlaying) mediaPlayer.pause()
                            else mediaPlayer.play()
                        }
                    }

                    // Mute toggle — matches menuButton sizing/margins for alignment
                    RippleButton {
                        property real buttonSize: 30
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 8
                        implicitWidth: buttonSize
                        implicitHeight: buttonSize
                        buttonRadius: Appearance.rounding.full
                        colBackground: Qt.rgba(0, 0, 0, 0.55)
                        colBackgroundHover: Qt.rgba(0, 0, 0, 0.75)
                        colRipple: Qt.rgba(1, 1, 1, 0.2)
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.videoMuted ? "volume_off" : "volume_up"
                            iconSize: Appearance.font.pixelSize.large
                            color: "white"
                        }
                        onClicked: root.videoMuted = !root.videoMuted
                    }

                    // Bottom bar: timestamps + custom scrubber — inset from card edges so
                    // its rounded corners aren't clipped by the card's rounded shape.
                    Rectangle {
                        id: scrubberBar
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.bottomMargin: 6
                        height: 30
                        radius: height / 2
                        color: Qt.rgba(0, 0, 0, 0.85)

                        property real scrubProgress: mediaPlayer.duration > 0
                            ? (videoRoot.userSeeking ? videoRoot.seekValue : mediaPlayer.position) / mediaPlayer.duration
                            : 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                color: "white"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                text: controlsOverlay.formatMs(videoRoot.userSeeking
                                    ? videoRoot.seekValue
                                    : mediaPlayer.position)
                            }

                            // Track
                            Item {
                                id: scrubberTrack
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                implicitHeight: 14

                                Rectangle { // track background
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 4
                                    radius: height / 2
                                    color: Qt.rgba(1, 1, 1, 0.25)
                                }
                                Rectangle { // progress fill
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(0, Math.min(parent.width, parent.width * scrubberBar.scrubProgress))
                                    height: 4
                                    radius: height / 2
                                    color: Appearance.m3colors.m3primary
                                }
                                Rectangle { // handle
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.max(0, Math.min(parent.width - width, parent.width * scrubberBar.scrubProgress - width / 2))
                                    width: 12
                                    height: 12
                                    radius: width / 2
                                    color: Appearance.m3colors.m3primary
                                    border.color: "white"
                                    border.width: 1
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onPressed: (mouse) => {
                                        videoRoot.userSeeking = true
                                        videoRoot.seekValue = Math.max(0,
                                            Math.min(mediaPlayer.duration,
                                                (mouse.x / width) * mediaPlayer.duration))
                                    }
                                    onPositionChanged: (mouse) => {
                                        if (!pressed) return
                                        videoRoot.seekValue = Math.max(0,
                                            Math.min(mediaPlayer.duration,
                                                (mouse.x / width) * mediaPlayer.duration))
                                    }
                                    onReleased: {
                                        mediaPlayer.position = videoRoot.seekValue
                                        videoRoot.userSeeking = false
                                    }
                                }
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                color: "white"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                text: controlsOverlay.formatMs(mediaPlayer.duration)
                            }
                        }
                    }

                    function formatMs(ms) {
                        if (!ms || ms <= 0) return "0:00"
                        const total = Math.floor(ms / 1000)
                        const m = Math.floor(total / 60)
                        const s = total % 60
                        return m + ":" + (s < 10 ? "0" : "") + s
                    }
                }
            }
        }

        // Clickable play badge for videos — triggers inline playback (downloads to cache first if needed).
        RippleButton {
            id: playBadge
            visible: root.isVideo && !(root.videoCached && root.videoPlayRequested)
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 6
            implicitWidth: 36
            implicitHeight: 36
            buttonRadius: Appearance.rounding.full
            colBackground: Qt.rgba(0, 0, 0, 0.55)
            colBackgroundHover: Qt.rgba(0, 0, 0, 0.75)
            colRipple: Qt.rgba(1, 1, 1, 0.2)
            contentItem: Item {
                anchors.fill: parent
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "play_arrow"
                    iconSize: Appearance.font.pixelSize.larger
                    color: "white"
                    visible: !root.videoDownloading
                }
                BusyIndicator {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    running: root.videoDownloading
                    visible: root.videoDownloading
                }
            }
            onClicked: {
                if (!root.playableUrl) return
                root.videoPlayRequested = true
                root.startVideoDownload()
            }
        }

        // Blacklisted badge.
        Rectangle {
            visible: root.isBlacklisted
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 6
            radius: 4
            color: Qt.rgba(0.6, 0, 0, 0.75)
            implicitWidth: blBadgeLabel.implicitWidth + 10
            implicitHeight: blBadgeLabel.implicitHeight + 4
            StyledText {
                id: blBadgeLabel
                anchors.centerIn: parent
                text: Translation.tr("blacklisted")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: "white"
            }
        }

        RippleButton {
            id: menuButton
            anchors.top: parent.top
            anchors.right: parent.right
            property real buttonSize: 30
            anchors.margins: 8
            implicitHeight: buttonSize
            implicitWidth: buttonSize

            // Hide when a video is playing inline and the user isn't hovering (controls fade out).
            opacity: (root.isVideo && root.videoCached && root.videoPlayRequested && !root.hovered) ? 0 : 1
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                }
            }

            buttonRadius: Appearance.rounding.full
            colBackground: ColorUtils.transparentize(Appearance.m3colors.m3surface, 0.3)
            colBackgroundHover: ColorUtils.transparentize(ColorUtils.mix(Appearance.m3colors.m3surface, Appearance.m3colors.m3onSurface, 0.8), 0.2)
            colRipple: ColorUtils.transparentize(ColorUtils.mix(Appearance.m3colors.m3surface, Appearance.m3colors.m3onSurface, 0.6), 0.1)

            contentItem: MaterialSymbol {
                horizontalAlignment: Text.AlignHCenter
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.m3colors.m3onSurface
                text: "more_vert"
            }

            onClicked: {
                root.showActions = !root.showActions
            }
        }

    }

    // Context menu rendered as a Popup so it escapes all parent clipping
    // (the card's ClippingRectangle, the response row container, etc.).
    Popup {
        id: contextMenuPopup
        parent: menuButton
        x: menuButton.width - width
        y: menuButton.height + 6
        padding: 0
        modal: false
        visible: root.showActions
        onClosed: root.showActions = false
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

        background: Rectangle {
            radius: Appearance.rounding.small
            color: Appearance.m3colors.m3surfaceContainer
        }

        contentItem: ColumnLayout {
            spacing: 0
            MenuButton {
                id: openFileLinkButton
                Layout.fillWidth: true
                buttonText: Translation.tr("Open file link")
                onClicked: {
                    root.showActions = false
                    Hyprland.dispatch("keyword cursor:no_warps true")
                    Qt.openUrlExternally(root.imageData.file_url)
                    Hyprland.dispatch("keyword cursor:no_warps false")
                }
            }
            MenuButton {
                id: sourceButton
                visible: root.imageData.source && root.imageData.source.length > 0
                Layout.fillWidth: true
                buttonText: Translation.tr("Go to source (%1)").arg(StringUtils.getDomain(root.imageData.source))
                enabled: root.imageData.source && root.imageData.source.length > 0
                onClicked: {
                    root.showActions = false
                    Hyprland.dispatch("keyword cursor:no_warps true")
                    Qt.openUrlExternally(root.imageData.source)
                    Hyprland.dispatch("keyword cursor:no_warps false")
                }
            }
            MenuButton {
                id: openInMpvButton
                visible: root.isVideo || root.isGif
                Layout.fillWidth: true
                buttonText: Translation.tr("Open in mpv")
                onClicked: {
                    root.showActions = false
                    if (!root.playableUrl) return
                    Quickshell.execDetached(["mpv", "--loop", "--force-window", root.playableUrl])
                }
            }
            MenuButton {
                id: downloadButton
                Layout.fillWidth: true
                buttonText: Translation.tr("Download")
                onClicked: {
                    root.showActions = false;
                    const targetPath = root.imageData.is_nsfw ? root.nsfwPath : root.downloadPath;
                    Quickshell.execDetached(["bash", "-c",
                        `mkdir -p '${targetPath}' && curl '${root.imageData.file_url}' -o '${targetPath}/${root.fileName}' && notify-send '${Translation.tr("Download complete")}' '${root.downloadPath}/${root.fileName}' -a 'Shell'`
                    ])
                }
            }
            MenuButton {
                id: favButton
                visible: root.isE621Provider
                Layout.fillWidth: true
                buttonText: root.imageData.is_favorited ? Translation.tr("Remove from favorites")
                                                         : Translation.tr("Add to favorites")
                onClicked: {
                    root.showActions = false
                    if (root.imageData.is_favorited) Booru.e621Unfavorite(root.imageData.id)
                    else Booru.e621Favorite(root.imageData.id)
                    root.imageData.is_favorited = !root.imageData.is_favorited
                }
            }
            MenuButton {
                id: upvoteButton
                visible: root.isE621Provider
                Layout.fillWidth: true
                buttonText: Translation.tr("Upvote")
                onClicked: {
                    root.showActions = false
                    Booru.e621Vote(root.imageData.id, 1)
                }
            }
            MenuButton {
                id: downvoteButton
                visible: root.isE621Provider
                Layout.fillWidth: true
                buttonText: Translation.tr("Downvote")
                onClicked: {
                    root.showActions = false
                    Booru.e621Vote(root.imageData.id, -1)
                }
            }
        }
    }
}
