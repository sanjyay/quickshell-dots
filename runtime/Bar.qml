import QtQuick
import Quickshell
import Quickshell.Io
import "../versions/astra" as AstraComponents

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
    readonly property var astra: astraLoader.item
    readonly property int screenCount: astra && astra.barScreens ? astra.barScreens.length : 0
    readonly property int windowCount: astra && astra.createdWindowCount !== undefined
        ? astra.createdWindowCount : 0

    function tryInitialize() {
        if (initialized || initializationError !== "" || !hostReady) return
        if (typeof barConfig !== "object") {
            initializationError = "barConfig is not an object"
        }
    }

    function finishInitialization() {
        if (!astraLoader.item) {
            initializationError = "Astra component did not create"
            return
        }
        initialized = astraLoader.item.initialized === true
        initializationError = String(astraLoader.item.initializationError || "")
    }

    function healthObject() {
        var fatal = initializationError
        if (!fatal && astra && astra.initializationError) fatal = String(astra.initializationError)
        var ready = initialized && astra && astra.initialized === true && windowCount > 0 && fatal === ""
        return {
            ok: ready,
            plugin: "io.github.sanjyay.quickshell-astra",
            componentCreated: componentCreated,
            hostReady: hostReady,
            shellInjected: shell !== null,
            manifestInjected: manifest !== null,
            barConfigInjected: barConfig !== null,
            initialized: initialized,
            fatalError: fatal,
            screens: screenCount,
            windows: windowCount,
            degradedFeatures: astra && astra.capabilityDiagnostics
                ? Object.keys(astra.capabilityDiagnostics().capabilities || {}).filter(function(name) {
                    return astra.capabilityDiagnostics().capabilities[name].available !== true
                }) : [],
            capabilities: astra && astra.capabilityDiagnostics ? astra.capabilityDiagnostics() : {},
            gpu: astra && astra.gpuDiagnostics ? astra.gpuDiagnostics() : {},
            idle: astra && astra.idleDiagnostics ? astra.idleDiagnostics() : {},
            network: astra && astra.networkDiagnostics ? astra.networkDiagnostics() : {},
            history: astra && astra.historyDiagnostics ? astra.historyDiagnostics() : {},
            generation: generation,
            timestamp: Date.now()
        }
    }

    function debugBarGeometry() {
        if (!astra || !astra.debugBarGeometry) return []
        return astra.debugBarGeometry()
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
        target: "quickshell-astra-health"
        function ping(): string { return JSON.stringify(root.healthObject()) }
        function refreshAiUsage(): bool {
            return root.astra ? root.astra.refreshAiUsage() : false
        }
        function refreshNetwork(): bool {
            return root.astra ? root.astra.refreshNetwork() : false
        }
        function aiUsageDiagnostics(): string {
            return JSON.stringify(root.astra ? root.astra.aiUsageDiagnostics() : {
                initialized: false,
                collectorRunning: false,
                providers: {}
            })
        }
        function openAiUsage(provider: string): void {
            if (root.astra) root.astra.openAiUsage(provider)
        }
        function closeAiUsage(): void {
            if (root.astra) root.astra.closeAiUsage()
        }
        function openSystemMetrics(): void {
            if (root.astra) root.astra.openSystemMetrics()
        }
        function closeSystemMetrics(): void {
            if (root.astra) root.astra.closeSystemMetrics()
        }
        function openCalendar(): void {
            if (root.astra) root.astra.openCalendar()
        }
        function showCalendarMonth(year: int, month: int): bool {
            return root.astra ? root.astra.showCalendarMonth(year, month) : false
        }
        function closeCalendar(): void {
            if (root.astra) root.astra.closeCalendar()
        }
        function holidayDiagnostics(): string {
            return JSON.stringify(root.astra ? root.astra.holidayDiagnostics() : {
                status: "unavailable",
                records: []
            })
        }
        function capabilityDiagnostics(): string {
            return JSON.stringify(root.astra ? root.astra.capabilityDiagnostics() : {})
        }
    }

    // Deprecated Rise alias. It delegates to this same component and state;
    // no second bar or provider is created.
    IpcHandler {
        target: "quickshell-rise-health"
        function ping(): string { return JSON.stringify(root.healthObject()) }
        function refreshAiUsage(): bool { return root.astra ? root.astra.refreshAiUsage() : false }
        function refreshNetwork(): bool { return root.astra ? root.astra.refreshNetwork() : false }
        function aiUsageDiagnostics(): string { return JSON.stringify(root.astra ? root.astra.aiUsageDiagnostics() : {}) }
        function openAiUsage(provider: string): void { if (root.astra) root.astra.openAiUsage(provider) }
        function closeAiUsage(): void { if (root.astra) root.astra.closeAiUsage() }
        function openSystemMetrics(): void { if (root.astra) root.astra.openSystemMetrics() }
        function closeSystemMetrics(): void { if (root.astra) root.astra.closeSystemMetrics() }
        function openCalendar(): void { if (root.astra) root.astra.openCalendar() }
        function showCalendarMonth(year: int, month: int): bool { return root.astra ? root.astra.showCalendarMonth(year, month) : false }
        function closeCalendar(): void { if (root.astra) root.astra.closeCalendar() }
        function holidayDiagnostics(): string { return JSON.stringify(root.astra ? root.astra.holidayDiagnostics() : {}) }
    }

    Loader {
        id: astraLoader
        active: root.hostReady && root.initializationError === ""
        asynchronous: false

        sourceComponent: Component {
            AstraComponents.Bar {
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
                root.initializationError = "Astra component loader error"
        }
    }
}
