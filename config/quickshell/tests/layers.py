#!/usr/bin/env python3
"""Layer rules of the shell (ARCHITECTURE.md §4 and §11).

Checks config/quickshell/src against the dependency rules of the
architecture. Enforced in CI: there is no allowlist, a violation is fixed
(or the rule is changed here, with a reason) before the PR merges.

Usage:
  tests/layers.py              check; exit 1 on any violation
  tests/layers.py --report     print the same, always exit 0
  tests/layers.py --self-test  plant one violation per rule in a copy of src/
                               and check that each rule catches its own

Rules:
  io          no Process / FileView / Socket / SplitParser / StdioCollector
              outside core/ (services use Exec and JsonStore)
  visual      no visual root item in services/, state/, actions/, core/
              (core/specs excepted)
  service-ui  services/ never imports state/, actions/, features/, surface/,
              dialogs/, nor names Popups or SurfaceState
  component   components/ uses no singleton outside theme/ and core/, and
              imports nothing but theme/ and core/
  host        surface/ and dialogs/ never import features/
  relative    no relative directory import (import "../…"); a .js file in
              the same folder is fine
  shell-c     no "-c" command element followed by string concatenation in
              the same array (data must go in as arguments; see #133)
  size        files over budget: views 300 lines, services/state and pure
              .js modules 350 (warning), any file over 500 (violation)
"""
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC = HERE.parent / "src"

IO_TYPES = re.compile(r"\b(Process|FileView|Socket|SplitParser|StdioCollector)\s*\{")
VISUAL_ROOT = re.compile(r"^(Item|Rectangle|Text|Column|Row|Grid|Flow|Flickable|ListView|GridView|"
                         r"FocusScope|MouseArea|Image|Loader|StatCard|PanelWindow|FloatingWindow)\s*\{", re.M)
IMPORT = re.compile(r'^import\s+"([^"]+)"', re.M)
QS_IMPORT = re.compile(r'^import\s+qs\.src\.([\w.]+)', re.M)
SERVICE_UI_NAMES = re.compile(r"\b(Popups|SurfaceState)\.")
UI_LAYERS = ("state", "actions", "features", "surface", "dialogs", "popups", "windows", "modules")


def rel(p: Path) -> str:
    return p.relative_to(SRC).as_posix()


def top(p: Path) -> str:
    return rel(p).split("/")[0]


def singletons() -> dict:
    """Singleton name -> top-level folder of its file."""
    out = {}
    for f in SRC.rglob("*.qml"):
        if "pragma Singleton" in f.read_text(errors="replace"):
            out[f.stem] = top(f)
    return out


def import_targets(f: Path, text: str):
    """Resolved src-relative folders of a file's directory imports."""
    for m in QS_IMPORT.finditer(text):
        yield m.group(1).replace(".", "/")
    for m in IMPORT.finditer(text):
        spec = m.group(1)
        if spec.endswith(".js"):
            continue
        target = (f.parent / spec).resolve()
        try:
            yield target.relative_to(SRC).as_posix()
        except ValueError:
            yield spec


def command_arrays(text: str):
    """Yield the text of each JS array literal that contains a "-c" element."""
    for m in re.finditer(r'"-c"\s*,', text):
        start = text.rfind("[", 0, m.start())
        depth, i = 0, start
        while i < len(text):
            if text[i] == "[":
                depth += 1
            elif text[i] == "]":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        yield text[m.end():i]


def check() -> list:
    found = []
    single = singletons()
    for f in sorted(SRC.rglob("*")):
        if f.suffix not in (".qml", ".js") or not f.is_file():
            continue
        text = f.read_text(errors="replace")
        r, layer = rel(f), top(f)
        lines = len(text.splitlines())

        if f.suffix == ".qml":
            if layer != "core" and IO_TYPES.search(text):
                found.append(("io", r))
            if layer in ("services", "state", "actions") or (layer == "core" and "/specs/" not in r):
                if VISUAL_ROOT.search(text):
                    found.append(("visual", r))
            targets = list(import_targets(f, text))
            if layer == "services":
                if any(t.split("/")[0] in UI_LAYERS for t in targets) or SERVICE_UI_NAMES.search(text):
                    found.append(("service-ui", r))
            if layer == "components":
                used = {n for n, where in single.items()
                        if where not in ("theme", "core") and re.search(r"\b" + n + r"\b", text)}
                bad_imports = [t for t in targets if t.split("/")[0] not in ("theme", "core", "components", ".")
                               and t not in ("", ".")]
                if used or bad_imports:
                    found.append(("component", r))
            if layer in ("surface", "dialogs") and any(t.startswith("features") for t in targets):
                found.append(("host", r))
            if re.search(r'^import\s+"\.\./', text, re.M):
                found.append(("relative", r))
        for arr in command_arrays(text):
            # Only the script itself (the element after "-c") matters: joining
            # string literals across lines is fine, a value (an identifier or
            # a call) concatenated into the script is not. Arguments after it
            # ("--", path, …) may be built freely.
            code = re.sub(r'"(?:[^"\\]|\\.)*"', '""', arr)
            code = re.sub(r"'(?:[^'\\]|\\.)*'", "''", code)
            script, depth = "", 0
            for ch in code:
                if ch in "([{": depth += 1
                elif ch in ")]}": depth -= 1
                elif ch == "," and depth == 0: break
                script += ch
            if re.search(r"\+\s*\(?\s*[A-Za-z_]|[A-Za-z_\])]\s*\+", script):
                found.append(("shell-c", r))
                break
        if lines > 500:
            found.append(("size", r))
    return sorted(set(found))


def size_warnings() -> list:
    out = []
    for f in sorted(SRC.rglob("*")):
        if f.suffix not in (".qml", ".js") or not f.is_file():
            continue
        n = len(f.read_text(errors="replace").splitlines())
        # Pure .js modules are logic, not views: they get the service budget.
        logic = f.suffix == ".js" or top(f) in ("services", "state", "core", "actions", "theme")
        budget = 350 if logic else 300
        if budget < n <= 500:
            out.append(f"{rel(f)} ({n} > {budget})")
    return out


# One planted violation per rule: (rule, path under src/, content). The
# self-test copies src/, adds these and expects each rule on its own file.
PLANTED = [
    ("io",         "features/zz/IoBad.qml",
     "import QtQuick\nimport Quickshell.Io\nItem { Process { command: [\"true\"] } }\n"),
    ("visual",     "services/zz/VisualBad.qml",
     "import QtQuick\nItem {}\n"),
    ("service-ui", "services/zz/ServiceUiBad.qml",
     "import QtQuick\nimport qs.src.state\nQtObject { function f() { Popups.close(\"x\") } }\n"),
    ("component",  "components/zz/ComponentBad.qml",
     "import QtQuick\nimport qs.src.services.data\nItem { opacity: Prefs.data.backgroundOpacity / 100 }\n"),
    ("host",       "surface/HostBad.qml",
     "import QtQuick\nimport qs.src.features.power\nItem { PowerMenu {} }\n"),
    ("relative",   "features/zz/RelativeBad.qml",
     "import QtQuick\nimport \"../power\"\nItem {}\n"),
    ("shell-c",    "services/zz/ShellBad.qml",
     "import QtQuick\nQtObject { function cmd(n) { return [\"bash\", \"-c\", \"echo \" + n] } }\n"),
    ("size",       "features/zz/HugeBad.qml",
     "import QtQuick\nItem {\n" + "    // filler\n" * 500 + "}\n"),
]
BUDGET_PLANT = ("features/zz/LongView.qml", "import QtQuick\nItem {\n" + "    // filler\n" * 300 + "}\n")


def self_test() -> int:
    global SRC
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "src"
        shutil.copytree(SRC, src)
        SRC = src
        if check():
            failures.append("the tree itself has violations")
        for rule, path, text in PLANTED + [("budget",) + BUDGET_PLANT]:
            (src / path).parent.mkdir(parents=True, exist_ok=True)
            (src / path).write_text(text)
        found = set(check())
        for rule, path, _ in PLANTED:
            got = sorted(r for r, p in found if p == path)
            ok = got == [rule]
            print(f"  {'PASS' if ok else 'FAIL'}  {rule:10} {path}" + ("" if ok else f" (got {got or 'nothing'})"))
            if not ok:
                failures.append(rule)
        extra = sorted(v for v in found if v[1] not in {p for _, p, _ in PLANTED})
        if extra:
            failures.append(f"unexpected {extra}")
        warned = any(w.startswith(BUDGET_PLANT[0] + " ") for w in size_warnings())
        print(f"  {'PASS' if warned else 'FAIL'}  {'budget':10} {BUDGET_PLANT[0]} (warning)")
        if not warned:
            failures.append("budget")
    print("layers self-test: " + ("every rule catches its violation" if not failures
                                  else "FAILED: " + ", ".join(map(str, failures))))
    return 1 if failures else 0


def main() -> int:
    args = set(sys.argv[1:])
    if "--self-test" in args:
        return self_test()
    found = check()
    counts = {}
    for rule, _ in found:
        counts[rule] = counts.get(rule, 0) + 1
    print("layers: " + (", ".join(f"{k} {v}" for k, v in sorted(counts.items())) or "no violation"))
    ci = os.environ.get("GITHUB_ACTIONS") == "true"
    for rule, path in found:
        print(f"  {rule:10} {path}")
        if ci:
            print(f"::error file=config/quickshell/src/{path}::layer rule '{rule}' (tests/layers.py, ARCHITECTURE.md §11)")
    for w in size_warnings():
        print(f"  over budget (warning): {w}")
        if ci:
            print(f"::warning file=config/quickshell/src/{w.split(' ')[0]}::over its size budget {w.split(' ', 1)[1]} (ARCHITECTURE.md §9)")
    return 1 if (found and "--report" not in args) else 0


if __name__ == "__main__":
    sys.exit(main())
