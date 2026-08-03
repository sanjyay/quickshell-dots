import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    property string omarchyPath: ""
    property var shell: null
    property var manifest: null
    property var barWidgetRegistry: null
    property var pluginRegistry: null
    property var barConfig: null
    property bool componentCreated: false
    property int generation: 1

    readonly property bool hostReady: omarchyPath !== ""
        && shell !== null
        && manifest !== null
        && barConfig !== null
    readonly property var validScreens: Quickshell.screens.filter(function(screen) {
        return screen && screen.name !== "" && screen.width > 0 && screen.height > 0
    })

    function health() {
        return {
            ok: componentCreated && hostReady && validScreens.length > 0,
            plugin: "io.github.sanjyay.quickshell-astra",
            componentCreated: componentCreated,
            shellInjected: shell !== null,
            manifestInjected: manifest !== null,
            barConfigInjected: barConfig !== null,
            initialized: hostReady,
            fatalError: "",
            screens: validScreens.length,
            windows: validScreens.length,
            generation: generation,
            timestamp: Date.now()
        }
    }

    function debugBarGeometry() {
        var geometry = []
        for (var i = 0; i < validScreens.length; i++) {
            geometry.push({
                id: "quickshell-astra-smoke",
                screen: validScreens[i].name,
                x: 0,
                y: 0,
                width: validScreens[i].width,
                height: 8,
                visible: true
            })
        }
        return geometry
    }

    onOmarchyPathChanged: console.log("Astra smoke omarchyPath injected=" + (omarchyPath !== ""))
    onShellChanged: console.log("Astra smoke shell injected=" + (shell !== null))
    onManifestChanged: console.log("Astra smoke manifest injected=" + (manifest !== null))
    onBarWidgetRegistryChanged: console.log("Astra smoke barWidgetRegistry injected=" + (barWidgetRegistry !== null))
    onPluginRegistryChanged: console.log("Astra smoke pluginRegistry injected=" + (pluginRegistry !== null))
    onBarConfigChanged: console.log("Astra smoke barConfig injected=" + (barConfig !== null))
    Component.onCompleted: {
        componentCreated = true
        console.log("Astra smoke component created before injection")
    }

    IpcHandler {
        target: "quickshell-astra-health"
        function ping(): string { return JSON.stringify(root.health()) }
    }

    Variants {
        model: root.validScreens

        delegate: Component {
            PanelWindow {
                required property var modelData

                screen: modelData
                color: "#c4746e"
                implicitHeight: 8
                anchors {
                    top: true
                    left: true
                    right: true
                }
                WlrLayershell.namespace: "quickshell-astra-smoke"
                WlrLayershell.layer: WlrLayer.Top
            }
        }
    }
}
