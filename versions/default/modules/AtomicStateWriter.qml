import QtQuick
import Quickshell.Io

QtObject {
    id: writer

    required property string path
    property bool validateJson: false
    readonly property string bundledWriterPath: Qt.resolvedUrl("../../../scripts/qs-state-write")
        .toString().replace(/^file:\/\//, "")
    property var writerCommand: [bundledWriterPath]
    property string pending: ""
    property string inFlight: ""

    signal saved(string state)
    signal failed(string state, int exitCode)

    function write(state) {
        pending = state
        if (!writeProcess.running) startWrite()
    }

    function startWrite() {
        inFlight = pending
        writeProcess.running = true
    }

    property Process writeProcess: Process {
        command: writer.writerCommand.concat(writer.validateJson
            ? ["--json", writer.path]
            : [writer.path])
        stdinEnabled: true
        onStarted: writeProcess.write(JSON.stringify({ data: writer.inFlight }) + "\n")
        onExited: function(exitCode) {
            if (exitCode === 0) writer.saved(writer.inFlight)
            else writer.failed(writer.inFlight, exitCode)
            if (writer.pending !== writer.inFlight) Qt.callLater(writer.startWrite)
        }
    }
}
