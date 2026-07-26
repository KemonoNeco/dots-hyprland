import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.utils
import qs.modules.common.widgets
import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

Button {
    id: root
    property var imageData
    property var rowHeight
    property bool manualDownload: false
    property string previewDownloadPath
    property string downloadPath
    property string nsfwPath
    property real imageRadius: Appearance.rounding.small

    // e621 withholds file.url on some posts (artists who asked to be removed), so
    // nothing here may assume it exists.
    readonly property string fileUrl: imageData.file_url ?? ""
    readonly property string fileExt: (imageData.file_ext ?? "").toLowerCase()
    property string fileName: fileUrl.length > 0
        ? decodeURIComponent(fileUrl.substring(fileUrl.lastIndexOf('/') + 1))
        : `${imageData.id ?? "unknown"}.${fileExt || "bin"}`
    property string filePath: `${root.previewDownloadPath}/${root.fileName}`

    property int maxTagStringLineLength: 50
    property int maxTooltipTags: 30
    // Posts can carry hundreds of tags, and a tooltip that tall covers the screen.
    property string tooltipTagText: {
        const all = (imageData.tags ?? "").split(" ").filter(tag => tag.length > 0)
        const shown = StringUtils.wordWrap(all.slice(0, root.maxTooltipTags).join(" "), root.maxTagStringLineLength)
        if (all.length <= root.maxTooltipTags) return shown
        return `${shown}\n…(+${all.length - root.maxTooltipTags} more tags)`
    }

    // A post's sample is a still frame even when the post is animated, so playback
    // always uses the original file.
    readonly property bool isVideo: ["webm", "mp4", "mov", "m4v"].includes(fileExt) && fileUrl.length > 0
    readonly property bool isGif: fileExt === "gif" && fileUrl.length > 0
    readonly property bool isAnimated: isVideo || isGif
    property bool playing: false

    readonly property bool isE621: Booru.currentProvider === "e621"
    property bool favorited: !!imageData.is_favorited
    property bool showActions: false

    // Animated posts are heavy, so nothing plays until asked. A GIF has no controls
    // of its own, so clicking the card toggles it; a video hands over to its overlay.
    onClicked: {
        if (root.isGif) root.playing = !root.playing
        else if (root.isVideo) root.playing = true
    }

    ImageDownloaderProcess {
        id: imageDownloader
        running: root.manualDownload
        filePath: root.filePath
        sourceUrl: root.imageData.preview_url ?? root.imageData.sample_url
        onDone: (path, width, height) => {
            imageObject.source = ""
            imageObject.source = path
            if (!root.imageData.width || !root.imageData.height) {
                root.imageData.width = width
                root.imageData.height = height
                root.imageData.aspect_ratio = width / height
            }
        }
    }

    StyledToolTip {
        text: root.tooltipTagText
    }

    padding: 0
    implicitWidth: root.rowHeight * root.imageData.aspect_ratio
    implicitHeight: root.rowHeight

    background: Rectangle {
        radius: root.imageRadius
        color: Appearance.colors.colLayer2
    }

    contentItem: ClippingRectangle {
        anchors.fill: parent
        color: "transparent"
        radius: root.imageRadius

        // This item clips everything below to the rounded rect, so no child needs its
        // own OpacityMask layer — each one of those costs an offscreen buffer.
        StyledImage { // Still preview, and the poster frame for animated posts
            id: imageObject
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            source: root.imageData.preview_url ?? ""
        }

        Loader {
            anchors.fill: parent
            active: root.playing && root.isAnimated
            sourceComponent: root.isVideo ? videoComponent : gifComponent
        }

        Component {
            id: videoComponent
            BooruVideo {
                url: root.fileUrl
                controlsShown: root.hovered
            }
        }

        Component {
            id: gifComponent
            AnimatedImage {
                fillMode: Image.PreserveAspectFit
                source: root.fileUrl
                playing: true
            }
        }

        RippleButton { // Play badge for animated posts
            visible: root.isAnimated && !root.playing
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 6
            implicitWidth: 36
            implicitHeight: 36
            buttonRadius: Appearance.rounding.full
            colBackground: Qt.rgba(0, 0, 0, 0.55)
            colBackgroundHover: Qt.rgba(0, 0, 0, 0.75)
            colRipple: Qt.rgba(1, 1, 1, 0.2)
            contentItem: MaterialSymbol {
                horizontalAlignment: Text.AlignHCenter
                iconSize: Appearance.font.pixelSize.larger
                color: "white"
                text: "play_arrow"
            }
            onClicked: root.playing = true
        }

        RippleButton {
            id: menuButton
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8
            property real buttonSize: 30
            implicitHeight: buttonSize
            implicitWidth: buttonSize

            // Get out of the way of a playing video unless the card is hovered, when
            // the video's own controls are showing anyway.
            opacity: (root.playing && !root.hovered) ? 0 : 1
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

            onClicked: root.showActions = !root.showActions
        }
    }

    // A Popup, so the menu escapes the card's clipping and the response list's.
    Popup {
        id: contextMenuPopup
        parent: menuButton
        padding: 0
        modal: false
        visible: root.showActions
        onClosed: root.showActions = false
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

        // A popup can't leave the window, so open upwards for cards near the bottom.
        readonly property bool openUpward: {
            const overlay = contextMenuPopup.Overlay.overlay
            if (!overlay) return false
            return menuButton.mapToItem(overlay, 0, menuButton.height).y + height + 6 > overlay.height
        }
        x: menuButton.width - width
        y: openUpward ? -height - 6 : menuButton.height + 6

        background: Rectangle {
            radius: Appearance.rounding.small
            color: Appearance.m3colors.m3surfaceContainer
        }

        // Without this the cursor gets warped to whatever window opens.
        function openExternally(url) {
            root.showActions = false
            Hyprland.dispatch("hl.config({cursor = {no_warps = true}})")
            Qt.openUrlExternally(url)
            Hyprland.dispatch("hl.config({cursor = {no_warps = false}})")
        }

        contentItem: ColumnLayout {
            spacing: 0

            MenuButton {
                visible: root.fileUrl.length > 0
                Layout.fillWidth: true
                buttonText: Translation.tr("Open file link")
                onClicked: contextMenuPopup.openExternally(root.fileUrl)
            }
            MenuButton {
                visible: root.imageData.source?.length > 0
                Layout.fillWidth: true
                buttonText: Translation.tr("Go to source (%1)").arg(StringUtils.getDomain(root.imageData.source ?? ""))
                onClicked: contextMenuPopup.openExternally(root.imageData.source)
            }
            MenuButton {
                visible: root.isAnimated
                Layout.fillWidth: true
                buttonText: Translation.tr("Open in mpv")
                onClicked: {
                    root.showActions = false
                    Quickshell.execDetached(["mpv", "--loop", "--force-window", root.fileUrl])
                }
            }
            MenuButton {
                visible: root.fileUrl.length > 0
                Layout.fillWidth: true
                buttonText: Translation.tr("Download")
                onClicked: {
                    root.showActions = false
                    const targetPath = root.imageData.is_nsfw ? root.nsfwPath : root.downloadPath
                    const userAgent = Config.options?.networking?.userAgent ?? ""
                    const userAgentHeader = userAgent ? ` -H 'User-Agent: ${StringUtils.shellSingleQuoteEscape(userAgent)}'` : ""
                    Quickshell.execDetached(["bash", "-c",
                        `mkdir -p '${targetPath}' && curl '${StringUtils.shellSingleQuoteEscape(root.fileUrl)}'${userAgentHeader} -o '${targetPath}/${root.fileName}' && notify-send '${Translation.tr("Download complete")}' '${root.downloadPath}/${root.fileName}' -a 'Shell'`
                    ])
                }
            }
            MenuButton {
                visible: root.isE621
                Layout.fillWidth: true
                buttonText: root.favorited ? Translation.tr("Remove from favorites") : Translation.tr("Add to favorites")
                // Only claim it worked once e621 says it did.
                onClicked: {
                    root.showActions = false
                    const wanted = !root.favorited
                    Booru.e621SetFavorite(root.imageData.id, wanted, () => root.favorited = wanted)
                }
            }
            MenuButton {
                visible: root.isE621
                Layout.fillWidth: true
                buttonText: Translation.tr("Upvote")
                onClicked: {
                    root.showActions = false
                    Booru.e621Vote(root.imageData.id, 1)
                }
            }
            MenuButton {
                visible: root.isE621
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
