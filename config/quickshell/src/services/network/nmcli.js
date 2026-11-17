// nmcli.js — parsers for `nmcli -t` (terse) output, used by WifiService.
//
// Pure JS, no QML: tests/unit/nmcli.test.mjs runs it under node. In terse
// mode nmcli separates fields with ":" and escapes a ":" inside a value as
// "\:" (SSIDs and connection names can contain colons).

function _unescape(s) { return s.replace(/\\:/g, ":") }

// `nmcli radio wifi` → true when "enabled".
function parseRadio(out) {
    return String(out).trim() === "enabled"
}

// `nmcli -t -f ACTIVE,SIGNAL,SSID dev wifi` → the active network
// { ssid, signal }, or { ssid: "", signal: 0 } when none is active.
function parseActive(out) {
    const line = String(out).split("\n").find(l => l.startsWith("yes:"))
    if (!line) return { ssid: "", signal: 0 }
    const rest = line.substring(4)
    const c = rest.indexOf(":")
    const s = parseInt(rest.substring(0, c))
    return { ssid: _unescape(rest.substring(c + 1)), signal: isNaN(s) ? 0 : s }
}

// `nmcli -t -f TYPE,STATE,CONNECTION dev` → the connection name of the first
// connected ethernet device, or null.
function parseEthernet(out) {
    const line = String(out).split("\n").find(l => l.startsWith("ethernet:connected:"))
    return line === undefined ? null : _unescape(line.substring(19))
}

// `nmcli -t -f CONNECTIVITY general` → "full" | "limited" | "portal" |
// "none" | "unknown", or "" when nothing was printed.
function parseConnectivity(out) {
    return (String(out).split("\n")[0] || "").trim().toLowerCase()
}

// `nmcli -t -f IN-USE,SIGNAL... ` scan list (IN-USE:SSID:SIGNAL:SECURITY) →
// [{ ssid, signal, secured, inUse }], one entry per SSID (the one in use,
// else the strongest), hidden networks ("" / "--") left out, in nmcli's order.
function parseWifiList(out) {
    const nets = []
    for (const raw of String(out).split("\n")) {
        const t = raw.trim()
        if (t === "") continue
        const lastC = t.lastIndexOf(":")
        if (lastC < 0) continue
        const security = t.substring(lastC + 1)
        const t2 = t.substring(0, lastC)
        const secC = t2.lastIndexOf(":")
        if (secC < 0) continue
        const signalStr = t2.substring(secC + 1)
        const t3 = t2.substring(0, secC)
        const firstC = t3.indexOf(":")
        if (firstC < 0) continue
        const ssid = _unescape(t3.substring(firstC + 1))
        if (ssid === "" || ssid === "--") continue
        const inUse = t3.substring(0, firstC).trim() === "*"
        const signal = parseInt(signalStr.trim()) || 0
        const secured = security.trim() !== "" && security.trim() !== "--"
        const i = nets.findIndex(n => n.ssid === ssid)
        const net = { ssid: ssid, signal: signal, secured: secured, inUse: inUse }
        if (i < 0) nets.push(net)
        else if (inUse || signal > nets[i].signal) nets[i] = net
    }
    return nets
}

// Splits one terse line on the ":" that aren't escaped.
function _fields(line) {
    const out = []
    let cur = ""
    for (let i = 0; i < line.length; i++) {
        const ch = line[i]
        if (ch === "\\" && i + 1 < line.length) { cur += line[++i]; continue }
        if (ch === ":") { out.push(cur); cur = ""; continue }
        cur += ch
    }
    out.push(cur)
    return out
}

// `nmcli -t -f NAME,TYPE,ACTIVE con show` → the WireGuard connections
// [{ name, active }], sorted by name.
function parseWireguard(out) {
    return String(out).split("\n")
        .map(l => l.trim()).filter(l => l !== "")
        .map(_fields)
        .filter(f => f.length >= 3 && f[1] === "wireguard")
        .map(f => ({ name: f[0], active: f[2] === "yes" }))
        .sort((a, b) => a.name.localeCompare(b.name))
}

if (typeof module !== "undefined")
    module.exports = { parseRadio, parseActive, parseEthernet, parseConnectivity, parseWifiList, parseWireguard }
