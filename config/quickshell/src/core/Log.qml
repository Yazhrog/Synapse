pragma Singleton
import QtQuick
import Quickshell

// Log — one prefix and one place for the shell's own messages.
//
//   Log.warn("WifiService", "scan failed: " + err)   →  "Synapse/WifiService: scan failed: …"
Singleton {
    function info(tag: string, msg: string)  { console.info("Synapse/" + tag + ": " + msg) }
    function warn(tag: string, msg: string)  { console.warn("Synapse/" + tag + ": " + msg) }
    function error(tag: string, msg: string) { console.error("Synapse/" + tag + ": " + msg) }
}
