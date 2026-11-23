// Unit tests for src/services/system/sysinfo.js. Run: config/quickshell/tests/unit.sh
import { createRequire } from "node:module"
import { test } from "node:test"
import assert from "node:assert/strict"
const require = createRequire(import.meta.url)
const S = require("../../src/services/system/sysinfo.js")

test("cpu usage between two /proc/stat samples", () => {
    const a = S.parseCpuStat("cpu  100 0 100 700 100 0 0 0 0 0\ncpu0 1 2 3 4 5 6 7\n")
    const b = S.parseCpuStat("cpu  150 0 150 750 100 0 0 0 0 0\n")
    assert.deepEqual(a, { idle: 800, total: 1000 })
    assert.equal(S.cpuPercent(a, b), 67)
    assert.equal(S.cpuPercent(a, a), null)
    assert.equal(S.parseCpuStat("intr 1 2 3"), null)
})

test("meminfo", () => {
    assert.deepEqual(S.parseMeminfo("MemTotal:       16384000 kB\nMemFree: 1 kB\nMemAvailable:    8192000 kB\n"),
                     { percent: 50, usedGb: 7.8, totalGb: 15.6 })
    assert.equal(S.parseMeminfo(""), null)
})

test("df: block devices only", () => {
    const out = [
        "Filesystem     1M-blocks   Used Use% Mounted on",
        "/dev/nvme0n1p2   476000M 180000M  38% /",
        "tmpfs              7800M     12M   1% /tmp",
        "/dev/loop0          100M    100M 100% /snap/x",
        "/dev/sda1           512M     30M   6% /boot",
    ].join("\n")
    assert.deepEqual(S.parseDf(out), [
        { source: "nvme0n1p2", mount: "/", usedPct: 38, usedStr: "176 GB", totalStr: "465 GB" },
        { source: "sda1", mount: "/boot", usedPct: 6, usedStr: "30 MB", totalStr: "512 MB" },
    ])
})

test("net: route interface, counters, rate format", () => {
    assert.equal(S.parseRouteIface("1.1.1.1 via 192.168.1.1 dev wlan0 src 192.168.1.20 uid 1000\n"), "wlan0")
    assert.equal(S.parseRouteIface(""), "")
    const dev = "Inter-|   Receive\n face |bytes\n  wlan0: 1000 10 0 0 0 0 0 0 2000 20 0 0 0 0 0 0\n    lo: 5 0 0 0 0 0 0 0 5 0 0 0 0 0 0 0\n"
    assert.deepEqual(S.parseNetDev(dev, "wlan0"), { rx: 1000, tx: 2000 })
    assert.equal(S.parseNetDev(dev, "eth0"), null)
    assert.equal(S.formatRate(500), "500 B/s")
    assert.equal(S.formatRate(2048), "2 KB/s")
    assert.equal(S.formatRate(3.5 * 1024 * 1024), "3.5 MB/s")
})

test("sensors: package temp and fans", () => {
    const out = "coretemp-isa-0000\nPackage id 0:  +52.0°C  (high = +100.0°C)\nCore 0: +50.0°C\n\nthinkpad-isa-0000\nfan1:        2400 RPM\nfan2:           0 RPM\n"
    assert.deepEqual(S.parseSensors(out), { cpuTemp: 52, fans: [2400, 0] })
    assert.deepEqual(S.parseSensors(""), { cpuTemp: -1, fans: [] })
})

test("nvidia-smi usage", () => {
    assert.deepEqual(S.parseNvidiaUsage("12, 2048, 4096\n"), { usage: 12, usedMb: "2048", totalMb: "4096" })
    assert.equal(S.parseNvidiaUsage(""), null)
})

test("governor and frequency", () => {
    assert.equal(S.dominantGovernor("powersave\nperformance\npowersave\n"), "powersave")
    assert.equal(S.dominantGovernor(""), "")
    assert.equal(S.averageFreqGhz("2400000\n1600000\n"), "2.00 GHz")
    assert.equal(S.averageFreqGhz(""), "")
})
