import QtQuick
import Quickshell
import Quickshell.Io
import "../versions/rise" as RiseComponents

Item {
    id: root

    property string omarchyPath: ""
    property var shell: null
    property var manifest: null
    property var barWidgetRegistry: null
    property var pluginRegistry: null
    property var barConfig: null

    property bool componentCreated: false
    property bool initialized: false
    property string initializationError: ""
    property int generation: 1

    readonly property bool hostReady: omarchyPath !== ""
        && shell !== null
        && manifest !== null
        && barConfig !== null
    readonly property var rise: riseLoader.item
    readonly property int screenCount: rise && rise.barScreens ? rise.barScreens.length : 0
    readonly property int windowCount: rise && rise.createdWindowCount !== undefined
        ? rise.createdWindowCount : 0

    function tryInitialize() {
        if (initialized || initializationError !== "" || !hostReady) return
        if (typeof barConfig !== "object") {
            initializationError = "barConfig is not an object"
        }
    }

    function finishInitialization() {
        if (!riseLoader.item) {
            initializationError = "Rise component did not create"
            return
        }
        initialized = riseLoader.item.initialized === true
        initializationError = String(riseLoader.item.initializationError || "")
    }

    function healthObject() {
        var fatal = initializationError
        if (!fatal && rise && rise.initializationError) fatal = String(rise.initializationError)
        var ready = initialized && rise && rise.initialized === true && windowCount > 0 && fatal === ""
        return {
            ok: ready,
            plugin: "io.github.sanjyay.quickshell-rise",
            componentCreated: componentCreated,
            hostReady: hostReady,
            shellInjected: shell !== null,
            manifestInjected: manifest !== null,
            barConfigInjected: barConfig !== null,
            initialized: initialized,
            fatalError: fatal,
            screens: screenCount,
            windows: windowCount,
            degradedFeatures: [],
            gpu: rise && rise.gpuDiagnostics ? rise.gpuDiagnostics() : {},
            idle: rise && rise.idleDiagnostics ? rise.idleDiagnostics() : {},
            network: rise && rise.networkDiagnostics ? rise.networkDiagnostics() : {},
            history: rise && rise.historyDiagnostics ? rise.historyDiagnostics() : {},
            generation: generation,
            timestamp: Date.now()
        }
    }

    function debugBarGeometry() {
        if (!rise || !rise.debugBarGeometry) return []
        return rise.debugBarGeometry()
    }

    onOmarchyPathChanged: tryInitialize()
    onShellChanged: tryInitialize()
    onManifestChanged: tryInitialize()
    onBarConfigChanged: tryInitialize()
    Component.onCompleted: {
        componentCreated = true
        tryInitialize()
    }

    IpcHandler {
        target: "quickshell-rise-health"
        function ping(): string { return JSON.stringify(root.healthObject()) }
        function refreshAiUsage(): bool {
            return root.rise ? root.rise.refreshAiUsage() : false
        }
        function refreshNetwork(): bool {
            return root.rise ? root.rise.refreshNetwork() : false
        }
        function aiUsageDiagnostics(): string {
            return JSON.stringify(root.rise ? root.rise.aiUsageDiagnostics() : {
                initialized: false,
                collectorRunning: false,
                providers: {}
            })
        }
        function openAiUsage(provider: string): void {
            if (root.rise) root.rise.openAiUsage(provider)
        }
        function closeAiUsage(): void {
            if (root.rise) root.rise.closeAiUsage()
        }
        function openSystemMetrics(): void {
            if (root.rise) root.rise.openSystemMetrics()
        }
        function closeSystemMetrics(): void {
            if (root.rise) root.rise.closeSystemMetrics()
        }
        function openCalendar(): void {
            if (root.rise) root.rise.openCalendar()
        }
        function showCalendarMonth(year: int, month: int): bool {
            return root.rise ? root.rise.showCalendarMonth(year, month) : false
        }
        function closeCalendar(): void {
            if (root.rise) root.rise.closeCalendar()
        }
        function holidayDiagnostics(): string {
            return JSON.stringify(root.rise ? root.rise.holidayDiagnostics() : {
                status: "unavailable",
                records: []
            })
        }
    }

    Loader {
        id: riseLoader
        active: root.hostReady && root.initializationError === ""
        asynchronous: false

        sourceComponent: Component {
            RiseComponents.Bar {
                omarchyPath: root.omarchyPath
                shell: root.shell
                manifest: root.manifest
                barWidgetRegistry: root.barWidgetRegistry
                pluginRegistry: root.pluginRegistry
                barConfig: root.barConfig
            }
        }

        onLoaded: Qt.callLater(root.finishInitialization)
        onStatusChanged: {
            if (status === Loader.Error)
                root.initializationError = "Rise component loader error"
        }
    }
}
