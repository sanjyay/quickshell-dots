import QtQuick
import Quickshell.Io

QtObject {
    id: writer

    required property string path
    property bool validateJson: false
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
        command: writer.validateJson
            ? ["qs-state-write", "--json", writer.path]
            : ["qs-state-write", writer.path]
        stdinEnabled: true
        onStarted: writeProcess.write(JSON.stringify({ data: writer.inFlight }) + "\n")
        onExited: function(exitCode) {
            if (exitCode === 0) writer.saved(writer.inFlight)
            else writer.failed(writer.inFlight, exitCode)
            if (writer.pending !== writer.inFlight) Qt.callLater(writer.startWrite)
        }
    }
}
