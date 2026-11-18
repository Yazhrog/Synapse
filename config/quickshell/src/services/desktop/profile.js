// profile.js — parsers for ProfileService. Pure JS, tested by tests/unit/profile.test.mjs.

// `uptime -p` ("up 1 day, 2 hours, 5 minutes") → "1d 2h 5m"; "" for no output.
function formatUptime(raw) {
    const line = String(raw).split("\n").map(l => l.trim()).filter(l => l !== "").pop() ?? ""
    return line.replace("up ", "")
               .replace(/ hours?/, "h")
               .replace(/ minutes?/, "m")
               .replace(/ days?/, "d")
               .replace(/, /g, " ")
               .trim()
}

if (typeof module !== "undefined") module.exports = { formatUptime }
