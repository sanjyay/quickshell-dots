import QtQuick
import Quickshell
import Quickshell.Io
import "ImagePickerModel.js" as Model

QtObject {
    id: controller

    required property var root
    required property bool active
    required property var focusTarget
    property bool squareThumbnails: false

    readonly property bool isThemeMode: root.imagePickerMode === "theme"
    readonly property bool ready: root.imagePickerVisible && active && imagesLoaded && layoutSettled
    property bool imagesLoaded: false
    property bool layoutSettled: false
    property bool scanDone: false
    property var imageArray: []
    property int selFilt: 0
    property string filterText: ""
    property string currentImage: ""

    readonly property var filtered: {
        var out = []
        for (var i = 0; i < imageArray.length; i++) {
            if (!Model.itemMatches(imageArray, i, filterText)) continue
            out.push({
                idx: i,
                filePath: imageArray[i].filePath,
                thumb: "file://" + imageArray[i].thumbnailPath,
                label: Model.labelForPath(imageArray[i].filePath),
                dir: imageArray[i].dir || "",
                current: imageArray[i].filePath === currentImage
            })
        }
        return out
    }
    onFilteredChanged: if (selFilt >= filtered.length) selFilt = Math.max(0, filtered.length - 1)

    readonly property string currentLabel:
        (filtered.length > 0 && selFilt >= 0 && selFilt < filtered.length)
            ? filtered[selFilt].label
            : (filterText ? "No matches" : "")
    readonly property var sel: (filtered.length > 0 && selFilt >= 0 && selFilt < filtered.length)
                               ? filtered[selFilt] : null

    function syncOpen() {
        if (root.imagePickerVisible && active) {
            if (!imagesLoaded) {
                layoutSettled = false
                filterText = ""
                imageArray = []
                selFilt = 0
                currentProc.running = false
                currentProc.running = true
            }
        } else {
            imagesLoaded = false
            scanDone = false
            layoutSettled = false
        }
    }

    Component.onCompleted: syncOpen()
    property Connections rootConnections: Connections {
        target: controller.root
        function onImagePickerVisibleChanged() { controller.syncOpen() }
        function onPickerStyleChanged() { controller.syncOpen() }
    }

    property Process currentProc: Process {
        command: controller.isThemeMode
            ? ["bash", "-c",
               "CACHE=$HOME/.cache/quickshell-theme-picker; " +
               "name=$(cat ~/.config/omarchy/current/theme.name 2>/dev/null || true); " +
               "for ext in png jpg jpeg webp; do f=\"$CACHE/$name.$ext\"; [ -L \"$f\" ] && echo \"$f\" && exit 0; done; echo ''"]
            : ["bash", "-c", "readlink -f ~/.config/omarchy/current/background 2>/dev/null || true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                controller.currentImage = this.text.trim()
                cacheProc.running = false
                cacheProc.running = true
                var cmd = controller.buildScanCmd()
                cmd[2] += " | tee " + controller.shq(controller.scanCachePath)
                scanProc.command = cmd
                scanProc.running = false
                scanProc.running = true
            }
        }
    }

    property Process scanProc: Process {
        command: []
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: controller.applyScan(text, false)
        }
    }

    readonly property string scanCachePath: Quickshell.env("HOME") + "/.cache/quickshell-scan-" + (isThemeMode ? "theme" : "wallpaper")
    property string _lastScan: ""
    property Process cacheProc: Process {
        command: ["cat", controller.scanCachePath]
        stdout: StdioCollector { onStreamFinished: controller.applyScan(this.text, true) }
    }

    function applyScan(text, fromCache) {
        var value = String(text || "")
        if (fromCache && !value.trim()) return
        if (fromCache && imagesLoaded) return
        if (!fromCache && value.trim() === _lastScan.trim() && imagesLoaded) return
        _lastScan = value
        var images = Model.loadRows(value)
        imageArray = images
        selFilt = Model.indexForSelectedImage(images, currentImage)
        imagesLoaded = images.length > 0
        scanDone = true
        Qt.callLater(function() {
            if (!root.imagePickerVisible || !active) return
            layoutSettled = true
            if (imageArray.length > 0 && focusTarget) focusTarget.forceActiveFocus()
            fetchMeta()
            if (!fromCache) {
                warmMeta()
                warmTimer.restart()
            }
        })
    }

    function buildScanCmd() {
        if (isThemeMode) {
            return ["bash", "-c", [
                "shopt -s nullglob nocaseglob;",
                "CACHE=$HOME/.cache/quickshell-theme-picker; mkdir -p \"$CACHE\";",
                "for d in ~/.local/share/omarchy/themes/* ~/.config/omarchy/themes/*; do",
                "  [ -d \"$d\" ] || continue;",
                "  name=$(basename \"$d\");",
                "  prev=\"\";",
                "  for c in \"$d\"/preview.png \"$d\"/preview.jpg \"$d\"/preview.jpeg; do [ -f \"$c\" ] && { prev=\"$c\"; break; }; done;",
                "  if [ -z \"$prev\" ]; then bgs=(\"$d\"/backgrounds/*.jpg \"$d\"/backgrounds/*.jpeg \"$d\"/backgrounds/*.png \"$d\"/backgrounds/*.webp); prev=\"${bgs[0]}\"; fi;",
                "  [ -z \"$prev\" ] && continue;",
                "  ext=\"${prev##*.}\"; link=\"$CACHE/$name.$ext\";",
                "  [ -L \"$link\" ] || ln -sf \"$prev\" \"$link\";",
                "  printf '%s\\t%s\\t%s\\n' \"$link\" \"$prev\" \"$d\";",
                "done | sort -u"
            ].join(" ")]
        }
        return ["bash", "-c",
            "find -L ~/.config/omarchy/current/theme/backgrounds -maxdepth 1 -type f " +
            "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) " +
            "2>/dev/null | sort | while read f; do printf '%s\\t%s\\n' \"$f\" \"$f\"; done"]
    }

    property Process applyThemeProc: Process { command: [] }
    property Process applyBgProc: Process { command: [] }

    function applySelected() {
        if (!imagesLoaded || filtered.length === 0 || selFilt < 0 || selFilt >= filtered.length) return
        var path = filtered[selFilt].filePath
        if (!path) return
        if (isThemeMode) {
            var name = Model.nameForPath(path)
            applyThemeProc.command = ["bash", "-c", "omarchy-theme-set '" + name.replace(/'/g, "'\\''") + "'"]
            applyThemeProc.running = false
            applyThemeProc.running = true
        } else {
            applyBgProc.command = ["bash", "-c", "omarchy-theme-bg-set '" + path.replace(/'/g, "'\\''") + "'"]
            applyBgProc.running = false
            applyBgProc.running = true
        }
        root.imagePickerVisible = false
    }

    function moveSel(delta) {
        if (filtered.length === 0) return
        selFilt = Math.max(0, Math.min(filtered.length - 1, selFilt + delta))
    }

    function shq(value) { return "'" + String(value).replace(/'/g, "'\\''") + "'" }

    property Process warmProc: Process { command: [] }
    property Timer warmTimer: Timer { interval: 450; onTriggered: controller.warmAll() }
    function warmAll() {
        var srcs = []
        for (var i = 0; i < imageArray.length; i++)
            if (imageArray[i].filePath) srcs.push(imageArray[i].filePath)
        if (srcs.length === 0) return
        var suffix = squareThumbnails ? "-512" : ""
        var size = squareThumbnails ? "512x512^" : "480x270^"
        warmProc.command = ["bash", "-c",
            "D=$HOME/.cache/quickshell-img-thumbs; mkdir -p \"$D\"; command -v magick >/dev/null 2>&1 || exit 0; " +
            "for s in \"$@\"; do k=$(printf '%s' \"$s\" | md5sum | cut -d' ' -f1); m=$(stat -c %Y \"$s\" 2>/dev/null); " +
            "o=\"$D/$k-$m" + suffix + ".jpg\"; [ -f \"$o\" ] && continue; printf '%s\\n%s\\n' \"$s\" \"$o\"; done | " +
            "nice -n 19 xargs -d '\\n' -P 3 -n 2 sh -c 'magick \"$0\" -auto-orient -strip -thumbnail " + size + " -quality 82 \"$1\" >/dev/null 2>&1'",
            "warm"].concat(srcs)
        warmProc.running = false
        warmProc.running = true
    }

    property var metaCache: ({})
    property string _metaDir: ""
    readonly property var selMeta: (sel && sel.dir && metaCache[sel.dir]) ? metaCache[sel.dir] : null
    property Timer metaTimer: Timer { interval: 60; onTriggered: controller.fetchMeta() }
    onSelChanged: if (isThemeMode && sel && sel.dir && !metaCache[sel.dir]) metaTimer.restart()

    function fetchMeta() {
        if (!isThemeMode || !sel || !sel.dir || metaCache[sel.dir]) return
        _metaDir = sel.dir
        metaProc.command = ["bash", "-c",
            "d=" + shq(sel.dir) + "; repo=''; author='';" +
            "if [ -f \"$d/.git/config\" ]; then " +
            "  repo=$(sed -nE 's#^[[:space:]]*url = (.*)$#\\1#p' \"$d/.git/config\" | head -1);" +
            "  author=$(printf '%s' \"$repo\" | sed -nE 's#.*github\\.com[:/]+([^/]+)/.*#\\1#p');" +
            "fi;" +
            "pal=$(awk -F'\"' '/^color[1-6][[:space:]]*=/{print $2}' \"$d/colors.toml\" 2>/dev/null | paste -sd,);" +
            "printf '%s\\t%s\\t%s\\n' \"$author\" \"$repo\" \"$pal\""]
        metaProc.running = false
        metaProc.running = true
    }

    property Process metaProc: Process {
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = String(this.text || "").replace(/\n+$/, "").split("\t")
                var metadata = controller.metaCache
                metadata[controller._metaDir] = { author: parts[0] || "", repo: parts[1] || "", palette: parts[2] || "" }
                controller.metaCache = metadata
            }
        }
    }

    function openRepo() {
        if (!selMeta || !selMeta.repo) return
        var url = String(selMeta.repo).replace(/^git@github\.com:/, "https://github.com/").replace(/\.git$/, "")
        Quickshell.execDetached(["xdg-open", url])
    }

    property Process metaWarmProc: Process {
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(this.text || "").split("\n")
                var metadata = controller.metaCache
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue
                    var parts = lines[i].split("\t")
                    if (parts[0] && !metadata[parts[0]])
                        metadata[parts[0]] = { author: parts[1] || "", repo: parts[2] || "", palette: parts[3] || "" }
                }
                controller.metaCache = metadata
            }
        }
    }

    function warmMeta() {
        if (!isThemeMode) return
        var dirs = []
        for (var i = 0; i < imageArray.length; i++)
            if (imageArray[i].dir) dirs.push(imageArray[i].dir)
        if (dirs.length === 0) return
        metaWarmProc.command = ["bash", "-c",
            "for d in \"$@\"; do repo=''; author='';" +
            "if [ -f \"$d/.git/config\" ]; then repo=$(sed -nE 's#^[[:space:]]*url = (.*)$#\\1#p' \"$d/.git/config\" | head -1);" +
            "author=$(printf '%s' \"$repo\" | sed -nE 's#.*github\\.com[:/]+([^/]+)/.*#\\1#p'); fi;" +
            "pal=$(awk -F'\"' '/^color[1-6][[:space:]]*=/{print $2}' \"$d/colors.toml\" 2>/dev/null | paste -sd,);" +
            "printf '%s\\t%s\\t%s\\t%s\\n' \"$d\" \"$author\" \"$repo\" \"$pal\"; done",
            "warm"].concat(dirs)
        metaWarmProc.running = false
        metaWarmProc.running = true
    }
}
