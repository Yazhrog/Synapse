// Unit tests for src/services/system/update.js. Run: config/quickshell/tests/unit.sh
import { createRequire } from "node:module"
import { test } from "node:test"
import assert from "node:assert/strict"
const require = createRequire(import.meta.url)
const U = require("../../src/services/system/update.js")

test("applyScript: repo as $1, stash only when asked, fast-forward only", () => {
    const plain = U.applyScript(false), stash = U.applyScript(true)
    assert.ok(plain.startsWith('repo="$1";\n'))
    assert.ok(!plain.includes("stash push"))
    assert.ok(stash.includes("stash push -m 'synapse-pre-update'"))
    assert.ok(plain.includes("pull --ff-only origin main"))
    assert.ok(plain.endsWith("printf 'OK\\n'"))
})

test("parseApplyResult: success markers", () => {
    assert.deepEqual(U.parseApplyResult("NEW_PKGS:a,b\nREMOVED_PKGS:\nNEEDS_INSTALL\nOK\n"),
        { ok: true, needsFullInstall: true, newPackages: ["a", "b"], removedPackages: [], linkFailed: false })
    assert.deepEqual(U.parseApplyResult("LINK_FAILED\nOK\n"),
        { ok: true, needsFullInstall: false, newPackages: [], removedPackages: [], linkFailed: true })
})

test("parseApplyResult: failed pulls by cause", () => {
    const r = t => U.parseApplyResult("PULL_FAILED\n" + t)
    assert.deepEqual(r("error: Your local changes would be overwritten by merge"), { ok: false, conflict: true, error: "" })
    assert.match(r("fatal: Not possible to fast-forward, aborting.").error, /aren't on origin\/main/)
    assert.equal(r("fatal: unable to access 'https://…': Could not resolve host").error,
                 "Could not reach the remote. Check your connection.")
    assert.equal(r("a\nb\nc\nd\ne").error, "Update failed:\na\nb\nc\nd")
})
