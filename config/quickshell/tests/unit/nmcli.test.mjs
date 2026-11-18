// Unit tests for src/services/network/nmcli.js. Run: config/quickshell/tests/unit.sh
import { createRequire } from "node:module"
import { test } from "node:test"
import assert from "node:assert/strict"
const require = createRequire(import.meta.url)
const N = require("../../src/services/network/nmcli.js")

test("radio", () => {
    assert.equal(N.parseRadio("enabled\n"), true)
    assert.equal(N.parseRadio("disabled\n"), false)
    assert.equal(N.parseRadio(""), false)
})

test("active network, with an escaped colon in the SSID", () => {
    assert.deepEqual(N.parseActive("no:40:Other\nyes:72:Home\\:5G\n"), { ssid: "Home:5G", signal: 72 })
    assert.deepEqual(N.parseActive("no:40:Other\n"), { ssid: "", signal: 0 })
    assert.deepEqual(N.parseActive(""), { ssid: "", signal: 0 })
})

test("ethernet", () => {
    assert.equal(N.parseEthernet("wifi:connected:Home\nethernet:connected:Wired connection 1\n"), "Wired connection 1")
    assert.equal(N.parseEthernet("ethernet:unavailable:\nwifi:connected:Home\n"), null)
    assert.equal(N.parseEthernet("ethernet:connected:Lab\\:A\n"), "Lab:A")
})

test("connectivity", () => {
    assert.equal(N.parseConnectivity("FULL\n"), "full")
    assert.equal(N.parseConnectivity(""), "")
})

test("scan list: one entry per SSID, the strongest; hidden skipped; escaped colons", () => {
    const out = [
        " :Cafe:40:WPA2",
        " :Home\\:5G:50:WPA2",
        " :Cafe:70:WPA2",
        " ::55:WPA2",
        " :--:30:",
        " :Open:20:",
        "*:Home\\:5G:62:WPA2 WPA3",
    ].join("\n")
    assert.deepEqual(N.parseWifiList(out), [
        { ssid: "Cafe",    signal: 70, secured: true,  inUse: false },
        { ssid: "Home:5G", signal: 62, secured: true,  inUse: true  },
        { ssid: "Open",    signal: 20, secured: false, inUse: false },
    ])
})

// Current behaviour, kept as is by #142 (no behaviour change in the stack):
// a stronger access point of the same SSID listed *after* the one in use
// replaces it, so a mesh network can show as "not connected".
test("scan list: a later, stronger AP of the network in use replaces it (known issue)", () => {
    assert.deepEqual(N.parseWifiList("*:Home:62:WPA2\n :Home:90:WPA2\n"),
                     [{ ssid: "Home", signal: 90, secured: true, inUse: false }])
})

test("wireguard connections: only wireguard, sorted, escaped colons", () => {
    const out = "Home:802-11-wireless:yes\nwork\\:vpn:wireguard:no\nalpha:wireguard:yes\n"
    assert.deepEqual(N.parseWireguard(out), [
        { name: "alpha",    active: true  },
        { name: "work:vpn", active: false },
    ])
    assert.deepEqual(N.parseWireguard(""), [])
})
