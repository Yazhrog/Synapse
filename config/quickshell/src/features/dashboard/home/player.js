// player.js — labels for PlayerCard. Pure JS, tested by tests/unit/player.test.mjs.

// Seconds → "m:ss".
function formatTime(sec) {
    const s = Math.floor(sec)
    return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60)
}

// The glyph for an MPRIS player ("♪" when unknown or none).
function playerIcon(player) {
    if (!player) return "♪"
    var id = (player.identity || "").toLowerCase()
    if (id.indexOf("spotify")  !== -1) return ""
    if (id.indexOf("firefox")  !== -1) return ""
    if (id.indexOf("chromium") !== -1) return ""
    if (id.indexOf("chrome")   !== -1) return ""
    if (id.indexOf("brave")    !== -1) return ""
    if (id.indexOf("youtube")  !== -1) return ""
    return "♪"
}

// A short name for an MPRIS player ("—" for none).
function playerLabel(player) {
    if (!player) return "—"
    var id = (player.identity || "").toLowerCase()
    if (id.indexOf("spotify")  !== -1) return "Spotify"
    if (id.indexOf("firefox")  !== -1) return "Firefox"
    if (id.indexOf("chromium") !== -1) return "Chromium"
    if (id.indexOf("chrome")   !== -1) return "Chrome"
    if (id.indexOf("brave")    !== -1) return "Brave"
    if (id.indexOf("youtube")  !== -1) return "YouTube"
    if (id.indexOf("edge")     !== -1) return "Edge"
    if (id.indexOf("opera")    !== -1) return "Opera"
    if (id.indexOf("vivaldi")  !== -1) return "Vivaldi"
    return player.identity || "Player"
}

if (typeof module !== "undefined") module.exports = { formatTime, playerIcon, playerLabel }
