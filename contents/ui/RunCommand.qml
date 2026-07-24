import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Plasma5Support.DataSource {
    id: dataSource

    property var callbacks: ({})

    signal exited(string command, int exitCode, string stdout, string stderr)

    function exec(command, callback) {
        if (callback && typeof callback === "function") {
            callbacks[command] = callback
        }
        connectSource(command)
    }

    engine: "executable"
    connectedSources: []

    onNewData: function(source, data) {
        exited(source, data["exit code"], data["stdout"] || "", data["stderr"] || "")
        disconnectSource(source)
    }

    onExited: function(command, exitCode, stdout, stderr) {
        if (command in callbacks) {
            callbacks[command]({
                exitCode: exitCode,
                stdout: stdout,
                stderr: stderr
            })
            delete callbacks[command]
        }
    }
}
