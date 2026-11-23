// Unit tests for src/services/data/cliphist.js. Run: config/quickshell/tests/unit.sh
import { createRequire } from "node:module"
import { test } from "node:test"
import assert from "node:assert/strict"
const require = createRequire(import.meta.url)
const C = require("../../src/services/data/cliphist.js")

test("cliphist list: text and images, junk skipped", () => {
    const out = "12\thello world\n11\t[[ binary data 24 KiB png 800x600 ]]\n\nbad line\n10\t \n9\tsecond\ttab\n"
    assert.deepEqual(C.parseList(out), [
        { id: "12", preview: "hello world", isImage: false },
        { id: "11", preview: "[[ binary data 24 KiB png 800x600 ]]", isImage: true },
        { id: "9",  preview: "second\ttab", isImage: false },
    ])
})
