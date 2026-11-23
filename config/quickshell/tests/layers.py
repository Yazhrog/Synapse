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
  visual      the root of a file in services/, state/, actions/, core/ (core/specs
              excepted) is non-visual: Singleton, QtObject, Scope, Timer, … or a
              shell type whose own root is non-visual
  service-ui  services/ never imports state/, actions/, features/, surface/,
              dialogs/, nor names Popups or SurfaceState
  component   components/ uses no singleton outside theme/ and core/, and
              imports nothing but theme/, core/ and other components/ folders
  host        surface/ and dialogs/ never import features/
  relative    no relative import except a .js file in the same folder
              (import "keynames.js" as KeyNames)
  shell-c     no shell script element (after "-c", '-c', "-lc", …) with a value
              concatenated or interpolated into it (data goes in as arguments;
              see #133)
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
ROOT = re.compile(r"^(?:[A-Za-z_]\w*\.)?([A-Z]\w*)\s*\{", re.M)   # root object, optional "Alias." prefix
NON_VISUAL = {"Singleton", "QtObject", "Scope", "Timer", "Connections", "NotificationServer",
              "IpcHandler", "Variants", "LazyLoader", "Instantiator", "Binding"}
IMPORT = re.compile(r'^import\s+"([^"]+)"', re.M)
QS_IMPORT = re.compile(r'^import\s+qs\.src\.([\w.]+)', re.M)
SERVICE_UI_NAMES = re.compile(r"\b(Popups|SurfaceState)\.")
UI_LAYERS = ("state", "actions", "features", "surface", "dialogs", "popups", "windows", "modules")
LOGIC_LAYERS = ("services", "state", "core", "actions", "theme")
SHELL_FLAG = re.compile(r"""["'](-[a-zA-Z]*c)["']\s*,""")           # "-c", '-c', "-lc", "-ec"…


def top(rel: str) -> str:
    return rel.split("/")[0]


def read_tree(root: Path) -> dict:
    """src-relative path -> text, for every .qml and .js file (each read once)."""
    return {f.relative_to(root).as_posix(): f.read_text(errors="replace")
            for f in sorted(root.rglob("*")) if f.suffix in (".qml", ".js") and f.is_file()}


def singletons(files: dict) -> dict:
    """Singleton name -> top-level folder of its file."""
    return {Path(r).stem: top(r) for r, text in files.items()
            if r.endswith(".qml") and "pragma Singleton" in text}


def root_type(text: str):
    m = ROOT.search(text)
    return m.group(1) if m else None


def non_visual(type_name, files: dict, seen=()) -> bool:
    """A root type is non-visual if it's a known non-visual type, or a shell
    type (a .qml file of that name) whose own root is non-visual."""
    if type_name in NON_VISUAL:
        return True
    if type_name in seen:
        return False
    for r, text in files.items():
        if Path(r).stem == type_name and r.endswith(".qml"):
            return non_visual(root_type(text), files, seen + (type_name,))
    return False


def import_targets(rel: str, text: str):
    """Resolved src-relative folders of a file's directory imports."""
    for m in QS_IMPORT.finditer(text):
        yield m.group(1).replace(".", "/")
    for m in IMPORT.finditer(text):
        spec = m.group(1)
        if not spec.endswith(".js"):
            yield os.path.normpath(os.path.join(os.path.dirname(rel), spec)).replace(os.sep, "/")


def shell_scripts(text: str):
    """The script element (the one after a shell's -c flag) of every command
    array, as source text."""
    for m in SHELL_FLAG.finditer(text):
        i, depth, quote, out = m.end(), 0, None, ""
        while i < len(text):
            ch = text[i]
            if quote:
                if ch == "\\":
                    out += text[i:i + 2]; i += 2; continue
                if ch == quote:
                    quote = None
            elif ch in "\"'`":
                quote = ch
            elif ch in "([{":
                depth += 1
            elif ch in ")]}":
                if depth == 0:
                    break
                depth -= 1
            elif ch == "," and depth == 0:
                break
            out += ch
            i += 1
        yield out


def unsafe_script(script: str) -> bool:
    """True if a value is concatenated or interpolated into the script.
    Joining string literals across lines is fine."""
    if re.search(r"`(?:[^`\\]|\\.)*\$\{", script):          # template literal with ${…}
        return True
    code = re.sub(r'"(?:[^"\\]|\\.)*"', '""', script)
    code = re.sub(r"'(?:[^'\\]|\\.)*'", "''", code)
    code = re.sub(r"`(?:[^`\\]|\\.)*`", "``", code)
    return bool(re.search(r"\+\s*\(?\s*[A-Za-z_]|[A-Za-z_\])]\s*\+", code))


def check(files: dict) -> list:
    found = []
    single = singletons(files)
    for r, text in files.items():
        layer = top(r)
        if r.endswith(".qml"):
            if layer != "core" and IO_TYPES.search(text):
                found.append(("io", r))
            if layer in ("services", "state", "actions") or (layer == "core" and "/specs/" not in r):
                if not non_visual(root_type(text), files):
                    found.append(("visual", r))
            targets = list(import_targets(r, text))
            if layer == "services":
                if any(top(t) in UI_LAYERS for t in targets) or SERVICE_UI_NAMES.search(text):
                    found.append(("service-ui", r))
            if layer == "components":
                used = {n for n, where in single.items()
                        if where not in ("theme", "core") and re.search(r"\b" + n + r"\b", text)}
                if used or any(top(t) not in ("theme", "core", "components") for t in targets):
                    found.append(("component", r))
            if layer in ("surface", "dialogs") and any(top(t) == "features" for t in targets):
                found.append(("host", r))
            if any(not re.fullmatch(r"[\w.-]+\.js", spec) for spec in IMPORT.findall(text)):
                found.append(("relative", r))
        if any(unsafe_script(s) for s in shell_scripts(text)):
            found.append(("shell-c", r))
        if len(text.splitlines()) > 500:
            found.append(("size", r))
    return sorted(set(found))


def size_warnings(files: dict) -> list:
    """(path, lines, budget) of every file over its budget but under 500."""
    out = []
    for r, text in files.items():
        n = len(text.splitlines())
        # Pure .js modules are logic, not views: they get the service budget.
        budget = 350 if r.endswith(".js") or top(r) in LOGIC_LAYERS else 300
        if budget < n <= 500:
            out.append((r, n, budget))
    return out


# One planted violation per rule: (rule, path under src/, content). The
# self-test adds these to a copy of the tree and expects each rule on its own
# file, and nothing else.
FILLER = "    // filler\n"
PLANTED = [
    ("io",         "features/zz/IoBad.qml",
     'import QtQuick\nimport Quickshell.Io\nItem { Process { command: ["true"] } }\n'),
    ("visual",     "services/zz/VisualBad.qml",
     "import QtQuick\nItem {}\n"),
    ("visual",     "state/zz/AliasBad.qml",
     "import QtQuick as QQ\nQQ.Item {}\n"),
    ("visual",     "actions/zz/WindowBad.qml",
     "import QtQuick\nimport Quickshell\nPopupWindow {}\n"),
    ("service-ui", "services/zz/ServiceUiBad.qml",
     'import QtQuick\nimport qs.src.state\nQtObject { function f() { Popups.close("x") } }\n'),
    ("component",  "components/zz/ComponentBad.qml",
     "import QtQuick\nimport qs.src.services.data\nItem { opacity: Prefs.data.backgroundOpacity / 100 }\n"),
    ("host",       "surface/HostBad.qml",
     "import QtQuick\nimport qs.src.features.power\nItem { PowerMenu {} }\n"),
    ("relative",   "features/zz/RelativeBad.qml",
     'import QtQuick\nimport "../power"\nItem {}\n'),
    ("relative",   "features/zz/RelativeHereBad.qml",
     'import QtQuick\nimport "./sub"\nItem {}\n'),
    ("shell-c",    "services/zz/ShellBad.qml",
     'import QtQuick\nQtObject { function cmd(n) { return ["bash", "-c", "echo " + n] } }\n'),
    ("shell-c",    "services/zz/ShellQuoteBad.qml",
     "import QtQuick\nQtObject { function cmd(p) { return [\"sh\", '-lc', 'rm ' + p] } }\n"),
    ("shell-c",    "services/zz/ShellTemplateBad.qml",
     'import QtQuick\nQtObject { function cmd(n) { return ["bash", "-c", `echo ${n}`] } }\n'),
    ("size",       "features/zz/HugeBad.qml",
     "import QtQuick\nItem {\n" + FILLER * 500 + "}\n"),
]
# Must stay clean: a .js import next to the file, joined literals after -c,
# a shell type with a non-visual root, components importing components.
CLEAN = [
    ("features/zz/JsImportOk.qml", 'import QtQuick\nimport "helper.js" as H\nItem {}\n'),
    ("services/zz/ShellOk.qml",
     'import QtQuick\nQtObject { function cmd(n) { return ["bash", "-c", "echo " +\n "$1", "--", n] } }\n'),
    ("services/zz/BackendOk.qml", "import QtQuick\nimport qs.src.services.media.recorders\nRecorderBackend {}\n"),
    ("components/zz/ComponentOk.qml", "import QtQuick\nimport qs.src.components.base\nItem {}\n"),
]
BUDGET_PLANT = ("features/zz/LongView.qml", "import QtQuick\nItem {\n" + FILLER * 300 + "}\n")


def self_test() -> int:
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "src"
        shutil.copytree(SRC, src, ignore=lambda d, names: [
            n for n in names if not (Path(d, n).is_dir() or n.endswith((".qml", ".js")))])
        if check(read_tree(src)):
            failures.append("the tree itself has violations")
        for path, text in [(p, t) for _, p, t in PLANTED] + CLEAN + [BUDGET_PLANT]:
            (src / path).parent.mkdir(parents=True, exist_ok=True)
            (src / path).write_text(text)
        files = read_tree(src)
        found = set(check(files))
        for rule, path, _ in PLANTED:
            got = sorted(r for r, p in found if p == path)
            ok = got == [rule]
            print(f"  {'PASS' if ok else 'FAIL'}  {rule:10} {path}" + ("" if ok else f" (got {got or 'nothing'})"))
            if not ok:
                failures.append(f"{rule} ({path})")
        for path, _ in CLEAN:
            got = sorted(r for r, p in found if p == path)
            print(f"  {'PASS' if not got else 'FAIL'}  {'clean':10} {path}" + (f" (got {got})" if got else ""))
            if got:
                failures.append(f"false positive {got} ({path})")
        warned = any(p == BUDGET_PLANT[0] for p, _, _ in size_warnings(files))
        print(f"  {'PASS' if warned else 'FAIL'}  {'budget':10} {BUDGET_PLANT[0]} (warning)")
        if not warned:
            failures.append("budget")
    print("layers self-test: " + ("every rule catches its violation" if not failures
                                  else "FAILED: " + ", ".join(failures)))
    return 1 if failures else 0


def main(argv) -> int:
    known = {"--report", "--self-test"}
    unknown = [a for a in argv if a not in known]
    if unknown:
        print(f"layers.py: unknown argument {' '.join(unknown)} (--strict and --update are gone: "
              "the check is always strict and there is no allowlist)\n"
              "usage: tests/layers.py [--report | --self-test]", file=sys.stderr)
        return 2
    if "--self-test" in argv:
        return self_test()
    files = read_tree(SRC)
    found = check(files)
    counts = {}
    for rule, _ in found:
        counts[rule] = counts.get(rule, 0) + 1
    print("layers: " + (", ".join(f"{k} {v}" for k, v in sorted(counts.items())) or "no violation"))
    ci = os.environ.get("GITHUB_ACTIONS") == "true"
    for rule, path in found:
        print(f"  {rule:10} {path}")
        if ci:
            print(f"::error file=config/quickshell/src/{path}::layer rule '{rule}' (tests/layers.py, ARCHITECTURE.md §11)")
    for path, n, budget in size_warnings(files):
        print(f"  over budget (warning): {path} ({n} > {budget})")
        if ci:
            print(f"::warning file=config/quickshell/src/{path}::{n} lines, over its budget of {budget} (ARCHITECTURE.md §9)")
    return 1 if (found and "--report" not in argv) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
