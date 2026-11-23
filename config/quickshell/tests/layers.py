#!/usr/bin/env python3
"""Layer rules of the shell (ARCHITECTURE.md §4 and §11).

Checks config/quickshell/src against the dependency rules of the target
architecture. Violations listed in tests/layers-allowlist.txt are known debt
that #111 removes step by step; anything else is new.

Usage:
  tests/layers.py              report; exit 0 (warn mode, until #117)
  tests/layers.py --strict     exit 1 on a violation that isn't allowlisted
  tests/layers.py --update     rewrite the allowlist from the current tree

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
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC = HERE.parent / "src"
ALLOWLIST = HERE / "layers-allowlist.txt"

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


def main() -> int:
    args = set(sys.argv[1:])
    found = check()
    if "--update" in args:
        ALLOWLIST.write_text("# Known layer violations (tests/layers.py --update). #111 empties this file.\n"
                             + "".join(f"{rule}\t{path}\n" for rule, path in found))
        print(f"layers: allowlist rewritten ({len(found)} entries)")
        return 0

    allowed = set()
    if ALLOWLIST.exists():
        for line in ALLOWLIST.read_text().splitlines():
            if line and not line.startswith("#"):
                rule, path = line.split("\t")
                allowed.add((rule, path))

    new = [v for v in found if v not in allowed]
    stale = sorted(allowed - set(found))
    counts = {}
    for rule, _ in found:
        counts[rule] = counts.get(rule, 0) + 1

    print("layers: " + (", ".join(f"{k} {v}" for k, v in sorted(counts.items())) or "no violation"))
    for rule, path in new:
        print(f"  NEW      {rule:10} {path}")
    for rule, path in stale:
        print(f"  FIXED    {rule:10} {path} (remove it from the allowlist: tests/layers.py --update)")
    warnings = size_warnings()
    if warnings:
        print(f"  {len(warnings)} file(s) over their size budget (warning): " + ", ".join(warnings))
    return 1 if ("--strict" in args and new) else 0


if __name__ == "__main__":
    sys.exit(main())
