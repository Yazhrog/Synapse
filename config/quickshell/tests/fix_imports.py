#!/usr/bin/env python3
"""Recomputes every file's `import qs.src.*` lines from the types it uses.

Usage: config/quickshell/tests/fix_imports.py

For each QML file under src/ (and the test entry files), finds the project
types and singletons it names (file stems under src/), and writes one
`import qs.src.<folder>` per folder they live in, minus its own folder; other
imports (QtQuick, Quickshell, same-folder .js) are left alone. Run it after
moving files or using a type from a new folder; it is idempotent.
"""
import re
from pathlib import Path

QS = Path(__file__).resolve().parent.parent
SRC = QS / "src"
TEST_ENTRIES = ["shell.qml", "tests/smoke.qml", "tests/smoke-imports.qml", "tests/contracts.qml",
                "tests/core.qml", "tests/smoke-registries.qml", "tests/lib/SceneList.qml"]

types = {f.stem: f.parent.relative_to(QS).as_posix() for f in SRC.rglob("*.qml")}
OLD = re.compile(r'^import\s+(qs\.src[\w.]*|"(?![^"]*\.js")[^"]*")\s*\n', re.M)


def code_only(t):
    t = re.sub(r"/\*.*?\*/", "", t, flags=re.S)
    t = re.sub(r"//[^\n]*", "", t)
    t = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', t)
    return re.sub(r"'(?:[^'\\\n]|\\.)*'", "''", t)


def fix(f: Path, own: str) -> bool:
    text = f.read_text()
    m = OLD.search(text)
    body = code_only(OLD.sub("", text))
    used = {w for w in re.findall(r"\b[A-Z][A-Za-z0-9_]*\b", body) if w in types and w != f.stem}
    block = "".join(f"import qs.{d.replace('/', '.')}\n" for d in sorted({types[w] for w in used} - {own}))
    if m:
        new = text[:m.start()] + block + OLD.sub("", text[m.start():])
    else:
        if not block:
            return False
        last = list(re.finditer(r"^import [^\n]*\n", text, re.M))
        pos = last[-1].end() if last else 0
        new = text[:pos] + block + text[pos:]
    if new == text:
        return False
    f.write_text(new)
    return True


n = sum(fix(f, f.parent.relative_to(QS).as_posix()) for f in sorted(SRC.rglob("*.qml")))
n += sum(fix(QS / e, "") for e in TEST_ENTRIES if (QS / e).exists())
print(f"fix_imports: {n} file(s) updated")
