import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../modules"
import "DisplayModel.js" as DisplayModel

QtObject {
    id: service

    property bool panelVisible: false
    property string outputName: ""
    property var monitors: []
    property var monitor: null
    property string monitorStatus: "idle"
    property string monitorError: ""

    property bool brightnessAvailable: false
    property int brightnessPercent: 1
    property int pendingBrightnessPercent: 1
    property int inFlightBrightnessPercent: 1
    property bool brightnessApplying: false
    property string brightnessError: ""
    property string unsupportedBrightnessOutput: ""

    readonly property var scalePresets: ["1", "1.25", "1.6", "2", "3", "4"]
    property bool scaleApplying: false
    property string scaleError: ""
    property string scaleBeforeApply: ""

    readonly property var textSizeSteps: [10, 12, 14, 16, 18, 20]
    readonly property int defaultTextSize: 12
    property int textSize: defaultTextSize
    property int confirmedTextSize: defaultTextSize
    property int pendingTextSize: defaultTextSize
    property int inFlightTextSize: defaultTextSize
    property bool textSizeApplying: false
    property bool settingsLoaded: true
    property string settingsError: ""

    readonly property string scaleHelperPath: resolvedScript("../../../scripts/astra-display-scale")

    function resolvedScript(relativePath) {
        var value = String(Qt.resolvedUrl(relativePath))
        return value.indexOf("file://") === 0 ? value.substring(7) : value
    }

    function refresh() {
        if (!panelVisible || monitorProcess.running) return
        monitorStatus = "loading"
        monitorProcess.running = true
    }

    function acceptMonitors(raw, exitCode) {
        if (exitCode !== 0) {
            monitors = []
            monitor = null
            monitorStatus = "unavailable"
            monitorError = "Hyprland monitor state unavailable"
            brightnessAvailable = false
            return
        }
        var result = DisplayModel.parseMonitors(raw, outputName)
        monitors = result.monitors
        monitor = result.selected
        monitorStatus = result.selected ? "ready" : "unavailable"
        monitorError = result.error === "output-not-found" ? "Display disconnected"
            : (result.error ? "Monitor state unavailable" : "")
        if (!result.selected) {
            brightnessAvailable = false
            return
        }
        if (unsupportedBrightnessOutput !== outputName && !brightnessReadProcess.running)
            brightnessReadProcess.running = true
    }

    function previewBrightness(value) {
        if (!brightnessAvailable) return
        brightnessPercent = DisplayModel.clampBrightness(value)
        pendingBrightnessPercent = brightnessPercent
        brightnessDebounce.restart()
    }

    function applyBrightness(value) {
        if (!brightnessAvailable || !monitor || !outputName) return
        pendingBrightnessPercent = DisplayModel.clampBrightness(value)
        brightnessPercent = pendingBrightnessPercent
        if (brightnessWriteProcess.running) return
        brightnessApplying = true
        brightnessError = ""
        inFlightBrightnessPercent = pendingBrightnessPercent
        brightnessWriteProcess.command = ["omarchy-brightness-display", "--no-osd",
            "--monitor", outputName, inFlightBrightnessPercent + "%"]
        brightnessWriteProcess.running = true
    }

    function applyScale(scale) {
        if (!monitor || scaleApplying || scalePresets.indexOf(String(scale)) < 0) return
        scaleBeforeApply = String(monitor.scale || "")
        scaleError = ""
        scaleApplying = true
        scaleProcess.command = [scaleHelperPath, outputName, String(scale)]
        scaleProcess.running = true
    }

    function setTextSize(value) {
        var next = DisplayModel.validTextSize(value, textSizeSteps, defaultTextSize)
        textSize = next
        pendingTextSize = next
        if (textSizeProcess.running) return
        applySystemTextSize()
    }

    function applySystemTextSize() {
        inFlightTextSize = pendingTextSize
        textSizeApplying = true
        settingsError = ""
        textSizeProcess.command = ["omarchy-display-text-size", String(inFlightTextSize)]
        textSizeProcess.running = true
    }

    onPanelVisibleChanged: {
        if (panelVisible) refresh()
        else {
            refreshTimer.stop()
            brightnessDebounce.stop()
        }
    }
    onOutputNameChanged: {
        unsupportedBrightnessOutput = ""
        brightnessAvailable = false
        monitor = null
        if (panelVisible) refresh()
    }

    property string monitorOutput: ""
    property Process monitorProcess: Process {
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: service.monitorOutput = text }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(exitCode) { service.acceptMonitors(service.monitorOutput, exitCode) }
    }

    property string brightnessOutput: ""
    property Process brightnessReadProcess: Process {
        command: ["omarchy-brightness-display", "--monitor", service.outputName]
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: service.brightnessOutput = text }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(exitCode) {
            var value = Number(String(service.brightnessOutput || "").trim())
            if (exitCode !== 0 || !isFinite(value)) {
                service.brightnessAvailable = false
                service.unsupportedBrightnessOutput = service.outputName
                service.brightnessError = "Unavailable"
                return
            }
            service.brightnessAvailable = true
            service.brightnessError = ""
            if (!service.brightnessApplying) {
                service.brightnessPercent = DisplayModel.clampBrightness(value)
                service.pendingBrightnessPercent = service.brightnessPercent
            }
        }
    }

    property string brightnessWriteError: ""
    property Process brightnessWriteProcess: Process {
        stderr: StdioCollector { waitForEnd: true; onStreamFinished: service.brightnessWriteError = text }
        onExited: function(exitCode) {
            if (service.pendingBrightnessPercent !== service.inFlightBrightnessPercent) {
                service.applyBrightness(service.pendingBrightnessPercent)
                return
            }
            service.brightnessApplying = false
            if (exitCode !== 0) {
                service.brightnessError = "Brightness change failed"
                console.warn("Quickshell Astra Display: brightness command failed for "
                    + service.outputName + ": " + String(service.brightnessWriteError || "").trim())
                service.unsupportedBrightnessOutput = ""
                service.brightnessReadProcess.running = true
            }
        }
    }

    property string scaleOutput: ""
    property string scaleStderr: ""
    property Process scaleProcess: Process {
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: service.scaleOutput = text }
        stderr: StdioCollector { waitForEnd: true; onStreamFinished: service.scaleStderr = text }
        onExited: function(exitCode) {
            service.scaleApplying = false
            if (exitCode !== 0) {
                service.scaleError = "Scale change failed"
                console.warn("Quickshell Astra Display: scale command failed for "
                    + service.outputName + ": " + String(service.scaleStderr || "").trim())
            }
            service.refresh()
        }
    }

    property string textSizeStderr: ""
    property Process textSizeProcess: Process {
        stderr: StdioCollector { waitForEnd: true; onStreamFinished: service.textSizeStderr = text }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                service.textSizeApplying = false
                service.textSize = service.confirmedTextSize
                service.pendingTextSize = service.confirmedTextSize
                service.settingsError = "System text-size change failed"
                console.warn("Quickshell Astra Display: system text-size command failed: "
                    + String(service.textSizeStderr || "").trim())
                return
            }
            service.confirmedTextSize = service.inFlightTextSize
            if (service.pendingTextSize !== service.inFlightTextSize) {
                service.applySystemTextSize()
                return
            }
            service.textSizeApplying = false
        }
    }

    property Timer brightnessDebounce: Timer {
        interval: 180
        repeat: false
        onTriggered: service.applyBrightness(service.pendingBrightnessPercent)
    }

    property Timer refreshTimer: Timer {
        interval: 5000
        repeat: true
        running: service.panelVisible
        onTriggered: service.refresh()
    }

    function acceptSystemTextSize(value) {
        var next = DisplayModel.validTextSize(value, textSizeSteps, defaultTextSize)
        textSize = next
        confirmedTextSize = next
        if (!textSizeApplying) pendingTextSize = next
    }

    property Connections styleConnections: Connections {
        target: Style
        function onFontBaseSizeChanged() {
            service.acceptSystemTextSize(Style.font.baseSize)
        }
    }

    Component.onCompleted: acceptSystemTextSize(Style.font.baseSize)
}
