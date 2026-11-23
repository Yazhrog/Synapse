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

test("readVersion / parseVersions: plain X.Y.Z only, missing side is empty", () => {
    assert.equal(U.readVersion("0.7.0\n"), "0.7.0")
    assert.equal(U.readVersion(""), "")
    assert.equal(U.readVersion("v0.7.0"), "")
    assert.equal(U.readVersion("fatal: path 'VERSION' does not exist"), "")
    assert.deepEqual(U.parseVersions("0.6.3\n0.7.0\n"), { installed: "0.6.3", incoming: "0.7.0" })
    assert.deepEqual(U.parseVersions("\n0.7.0\n"), { installed: "", incoming: "0.7.0" })
    assert.deepEqual(U.parseVersions(""), { installed: "", incoming: "" })
})

test("availableSummary: version change, else the commit count", () => {
    assert.equal(U.availableSummary(42, "0.6.3", "0.7.0"), "v0.6.3 → v0.7.0")
    assert.equal(U.availableSummary(42, "", "0.7.0"), "42 new commits on main")
    assert.equal(U.availableSummary(1, "0.6.3", ""), "1 new commit on main")
    // commits on main without a bump: the version alone would say nothing
    assert.equal(U.availableSummary(3, "0.7.0", "0.7.0"), "3 new commits on main")
})

test("versionScript: reads HEAD's and origin/main's VERSION from a real clone", () => {
    const { execFileSync } = require("node:child_process")
    const { mkdtempSync, writeFileSync, rmSync } = require("node:fs")
    const { join } = require("node:path")
    const tmp = mkdtempSync(join(require("node:os").tmpdir(), "synapse-version-"))
    const git = (dir, ...a) => execFileSync("git", ["-C", dir, "-c", "user.name=t", "-c", "user.email=t@t",
                                                    "-c", "init.defaultBranch=main", ...a], { stdio: "pipe" })
    const run = dir => execFileSync("bash", ["-c", U.versionScript, "--", dir]).toString()
    try {
        const up = join(tmp, "up"), clone = join(tmp, "clone")
        execFileSync("git", ["-c", "init.defaultBranch=main", "init", "-q", up])
        writeFileSync(join(up, "README"), "x\n")
        git(up, "add", "."); git(up, "commit", "-qm", "before VERSION")
        execFileSync("git", ["clone", "-q", up, clone])
        writeFileSync(join(up, "VERSION"), "0.7.0\n")
        git(up, "add", "."); git(up, "commit", "-qm", "add VERSION")
        git(clone, "fetch", "-q", "origin", "main")
        assert.deepEqual(U.parseVersions(run(clone)), { installed: "", incoming: "0.7.0" })
        git(clone, "pull", "-q", "--ff-only", "origin", "main")
        writeFileSync(join(up, "VERSION"), "0.7.1\n")
        git(up, "commit", "-qam", "bump")
        git(clone, "fetch", "-q", "origin", "main")
        assert.deepEqual(U.parseVersions(run(clone)), { installed: "0.7.0", incoming: "0.7.1" })
        assert.deepEqual(U.parseVersions(run(join(tmp, "missing"))), { installed: "", incoming: "" })
    } finally {
        rmSync(tmp, { recursive: true, force: true })
    }
})
