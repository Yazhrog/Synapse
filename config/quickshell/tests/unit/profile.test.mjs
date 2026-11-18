// Unit tests for src/services/desktop/profile.js. Run: config/quickshell/tests/unit.sh
import { createRequire } from "node:module"
import { test } from "node:test"
import assert from "node:assert/strict"
const require = createRequire(import.meta.url)
const P = require("../../src/services/desktop/profile.js")

test("uptime -p, shortened", () => {
    assert.equal(P.formatUptime("up 1 day, 2 hours, 5 minutes\n"), "1d 2h 5m")
    assert.equal(P.formatUptime("up 3 days, 1 hour, 1 minute"), "3d 1h 1m")
    assert.equal(P.formatUptime("up 7 minutes"), "7m")
    assert.equal(P.formatUptime("up 2 weeks, 4 hours"), "2 weeks 4h")
    assert.equal(P.formatUptime(""), "")
})
