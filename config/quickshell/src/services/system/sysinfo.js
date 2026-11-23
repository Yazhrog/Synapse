// sysinfo.js — parsers for /proc, /sys, df, sensors and nvidia-smi output,
// used by the system services (CpuService, MemService, DiskService,
// NetService, ThermalService, GpuService, CpuFreqService).
//
// Pure JS, no QML: tests/unit/sysinfo.test.mjs runs it under node.

// /proc/stat → { idle, total } jiffies of the aggregate "cpu" line, or null.
function parseCpuStat(text) {
    const parts = String(text).split("\n")[0].trim().split(/\s+/)
    if (parts.length < 8 || parts[0] !== "cpu") return null
    const n = i => parseFloat(parts[i])
    const idle = n(4) + n(5)                         // idle + iowait
    const total = n(1) + n(2) + n(3) + idle + n(6) + n(7) + (parts.length > 8 ? n(8) : 0)
    return { idle: idle, total: total }
}

// Usage % between two parseCpuStat() samples, rounded; null when no time passed.
function cpuPercent(prev, cur) {
    const dTotal = cur.total - prev.total
    if (!(dTotal > 0)) return null
    return Math.round((1 - (cur.idle - prev.idle) / dTotal) * 100)
}

// /proc/meminfo → { percent, usedGb, totalGb } (GB to one decimal), or null.
function parseMeminfo(text) {
    let total = 0, avail = 0
    for (const line of String(text).split("\n")) {
        const p = line.trim().split(/\s+/)
        if (p[0] === "MemTotal:")     total = parseFloat(p[1])
        if (p[0] === "MemAvailable:") avail = parseFloat(p[1])
    }
    if (total <= 0) return null
    const used = total - avail
    return {
        percent: Math.round(used / total * 100),
        usedGb:  Math.round(used  / 1024 / 1024 * 10) / 10,
        totalGb: Math.round(total / 1024 / 1024 * 10) / 10,
    }
}

// "180000M" → "176 GB" (or "512 MB" below a GiB).
function formatMib(mibStr) {
    const n = parseInt(mibStr)
    if (isNaN(n)) return mibStr
    return n >= 1024 ? (n / 1024).toFixed(0) + " GB" : n + " MB"
}

// `df -BM --output=source,size,used,pcent,target` → real block devices
// [{ source, mount, usedPct, usedStr, totalStr }] (/dev/* only, no tmpfs/loop).
function parseDf(text) {
    const out = []
    for (const line of String(text).trim().split("\n")) {
        const p = line.trim().split(/\s+/)
        if (p.length < 5 || !p[0].startsWith("/dev/") || /tmpfs|loop/.test(p[0])) continue
        out.push({
            source:   p[0].replace("/dev/", ""),
            mount:    p[4],
            usedPct:  parseInt(p[3]) || 0,
            usedStr:  formatMib(p[2]),
            totalStr: formatMib(p[1]),
        })
    }
    return out
}

// `ip route get 1.1.1.1` → the outgoing interface ("wlan0"), or "".
function parseRouteIface(text) {
    const m = String(text).match(/\bdev\s+(\S+)/)
    return m ? m[1] : ""
}

// /proc/net/dev → { rx, tx } byte counters of `iface`, or null.
function parseNetDev(text, iface) {
    for (const raw of String(text).split("\n")) {
        const line = raw.trim()
        if (!line.startsWith(iface + ":")) continue
        const p = line.split(":")[1].trim().split(/\s+/)
        return { rx: parseFloat(p[0]), tx: parseFloat(p[8]) }
    }
    return null
}

// Bytes per second → "1.2 MB/s" | "340 KB/s" | "12 B/s".
function formatRate(bps) {
    if (bps >= 1024 * 1024) return (Math.round(bps / 1024 / 1024 * 10) / 10) + " MB/s"
    if (bps >= 1024) return Math.round(bps / 1024) + " KB/s"
    return Math.round(bps) + " B/s"
}

// `sensors` → { cpuTemp (package °C, or -1), fans: [rpm, …] }.
function parseSensors(text) {
    let pkg = -1
    const fans = []
    for (const line of String(text).split("\n")) {
        if (/Package id 0:/i.test(line)) {
            const m = line.match(/\+([0-9.]+)°C/)
            if (m) pkg = parseFloat(m[1])
            continue
        }
        const fm = line.match(/fan\d\s*:\s+([0-9]+)\s+RPM/i)
        if (fm) fans.push(parseInt(fm[1]))
    }
    return { cpuTemp: pkg, fans: fans }
}

// `nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total
// --format=csv,noheader,nounits` → { usage, usedMb, totalMb }, or null.
function parseNvidiaUsage(text) {
    const line = String(text).trim()
    if (line === "") return null
    const p = line.split(",").map(s => s.trim())
    if (p.length < 3) return null
    return { usage: parseFloat(p[0]) || 0, usedMb: p[1], totalMb: p[2] }
}

// One governor per line (all cores) → the most common one, or "".
function dominantGovernor(text) {
    const lines = String(text).trim().split("\n").map(l => l.trim()).filter(l => l !== "")
    if (lines.length === 0) return ""
    const counts = {}
    let best = lines[0], max = 0
    for (const g of lines) counts[g] = (counts[g] || 0) + 1
    for (const g of Object.keys(counts)) if (counts[g] > max) { max = counts[g]; best = g }
    return best
}

// scaling_cur_freq of every core (kHz, one per line) → "2.40 GHz", or "".
function averageFreqGhz(text) {
    const lines = String(text).trim().split("\n").filter(l => l.trim() !== "")
    if (lines.length === 0) return ""
    const sum = lines.reduce((s, l) => s + parseFloat(l.trim()), 0)
    return (sum / lines.length / 1e6).toFixed(2) + " GHz"
}

// `fastfetch -c systemstats` output ("Key: Value" per line, maybe with ANSI
// colours) → [{ key, value }]; lines without ": " are skipped.
function parseFastfetch(raw) {
    const out = []
    for (const l of String(raw).replace(/\x1B\[[0-9;]*[mGKHF]/g, "").split("\n")) {
        const line = l.trim()
        if (line === "") continue
        const sep = line.indexOf(": ")
        if (sep === -1) continue
        out.push({ key: line.substring(0, sep).trim(), value: line.substring(sep + 2).trim() })
    }
    return out
}

if (typeof module !== "undefined")
    module.exports = { parseCpuStat, cpuPercent, parseMeminfo, formatMib, parseDf, parseRouteIface,
                       parseNetDev, formatRate, parseSensors, parseNvidiaUsage, dominantGovernor, averageFreqGhz,
                       parseFastfetch }
