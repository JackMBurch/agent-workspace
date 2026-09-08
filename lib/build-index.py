#!/usr/bin/env python3
"""Generate INDEX.md from the frontmatter of every .md in an agent-workspace.

Usage:
    python3 bin/build-index.py            # rewrite INDEX.md
    python3 bin/build-index.py --check    # validate only; non-zero exit on a problem

Standard library only, on purpose. This is most needed when a project is unfamiliar or
half-configured, which is exactly when a dependency install is most likely to fail.

Implements section 7 of SPEC.md. --check fails on:
  1. missing or malformed frontmatter, or a missing/unknown required field   (7.1)
  2. `status: active` whose `updated:` is more than stale_days old           (7.2)
  3. an epic whose tracker is older than a live plan beneath it              (7.3)
  4. `status: blocked` with no `blocked-on:`                                 (7.1)
  5. a live status inside archive/, or a closed one outside it              (7.4)
  6. any unresolved `needs-triage`                                           (7.5)
  7. two live trackers claiming the same epic                                (7.3)
  8. a sub-workspace declared in config.toml that does not exist             (3.6)

The workspace root is derived from this file's location (../ from bin/), so the directory
may be named anything - `.workspace`, `workspace`, `notes`. Nothing here hardcodes it.
Symlinks are resolved first: a sub-workspace's `bin/` is a link to the root's, so running
this through that link still finds the real root and indexes the whole tree (SPEC 3.6).
"""

import argparse
import datetime
import os
import sys

try:
    import tomllib
except ImportError:  # Python < 3.11
    tomllib = None

ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
INDEX = os.path.join(ROOT, "INDEX.md")
CONFIG = os.path.join(ROOT, "config.toml")

TYPES = {"plan", "tracker", "session", "doc"}
LIVE = ["active", "blocked", "review", "paused", "needs-triage"]
CLOSED = ["done", "abandoned"]
STATUSES = LIVE + CLOSED

DEFAULTS = {
    "stale_days": 21,
    "scope_label": "scope",
    # `templates` is skipped because template files carry placeholder frontmatter
    # (`<YYYY-MM-DD>`) that is not meant to validate. Configurable, like the rest.
    "skip_dirs": [".git", ".claude", "node_modules", "__pycache__", "templates"],
    # Sub-workspaces (SPEC 3.6): paths relative to the root, mirroring sub-project paths.
    # Declared rather than discovered, so `plans/checkout-v2/` is never mistaken for one.
    "subworkspaces": [],
}

SKIP_FILES = {"INDEX.md"}


def load_config():
    """Read config.toml if present. Absent config means defaults, so a hand-created
    workspace still validates without one."""
    cfg = dict(DEFAULTS)
    if not os.path.exists(CONFIG) or tomllib is None:
        return cfg
    with open(CONFIG, "rb") as fh:
        data = tomllib.load(fh)
    for key in DEFAULTS:
        if key in data:
            cfg[key] = data[key]
    cfg["subworkspaces"] = [normalise_sub(p) for p in cfg["subworkspaces"]]
    return cfg


def normalise_sub(path):
    return path.strip().strip("/").replace(os.sep, "/")


def sub_of(rel, subs):
    """The sub-workspace a path belongs to, or None for the root. Longest prefix wins, so
    a sub-workspace nested in another resolves to the inner one."""
    best = None
    for sub in subs:
        if rel.startswith(sub + "/") and (best is None or len(sub) > len(best)):
            best = sub
    return best


class Doc:
    def __init__(self, path, meta, sub=None):
        self.path = path                      # relative to ROOT, forward slashes
        self.sub = sub                        # sub-workspace path, or None for the root
        self.meta = meta
        self.type = meta.get("type")
        self.status = meta.get("status")
        self.epic = meta.get("epic")
        self.updated = meta.get("updated")
        self.blocked_on = meta.get("blocked-on")
        self.superseded_by = meta.get("superseded-by")
        # `repos` is the deprecated alias for `scope` (SPEC 4.1).
        self.scope = meta.get("scope", meta.get("repos"))

    @property
    def archived(self):
        return "/archive/" in "/" + self.path

    @property
    def name(self):
        return os.path.basename(self.path)

    def age_days(self, today):
        try:
            d = datetime.date.fromisoformat(self.updated)
        except (TypeError, ValueError):
            return None
        return (today - d).days


def parse_frontmatter(path):
    """Return (meta, error). Deliberately tiny: `key: value`, one per line, no nesting.

    A full YAML parser is not in the standard library, and the schema in SPEC section 4 is
    flat by design so that it does not need one.
    """
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    if not text.startswith("---\n"):
        return None, "no frontmatter block"
    end = text.find("\n---", 4)
    if end == -1:
        return None, "unterminated frontmatter block"
    meta = {}
    for line in text[4:end].splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            return None, f"malformed frontmatter line: {line!r}"
        k, v = line.split(":", 1)
        v = v.strip()
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
            v = v[1:-1]
        if v.startswith("[") and v.endswith("]"):
            v = [x.strip() for x in v[1:-1].split(",") if x.strip()]
        meta[k.strip()] = v
    return meta, None


def collect(cfg):
    docs, errors = [], []
    skip = set(cfg["skip_dirs"])
    subs = cfg["subworkspaces"]
    for sub in subs:
        if not os.path.isdir(os.path.join(ROOT, sub)):
            errors.append(f"config.toml declares sub-workspace `{sub}` but {sub}/ does not exist")
    # followlinks stays False: a sub-workspace's bin/ and templates/ are links back to the
    # root's, and following them would index the templates twice.
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in skip]
        for fn in sorted(filenames):
            if not fn.endswith(".md") or fn in SKIP_FILES:
                continue
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, ROOT).replace(os.sep, "/")
            meta, err = parse_frontmatter(full)
            if err:
                errors.append(f"{rel}: {err}")
                continue
            for field in ("type", "status", "updated"):
                if field not in meta:
                    errors.append(f"{rel}: missing required `{field}:`")
            if "type" in meta and meta.get("type") not in TYPES:
                errors.append(f"{rel}: unknown type {meta['type']!r}")
            if "status" in meta and meta.get("status") not in STATUSES:
                errors.append(f"{rel}: unknown status {meta['status']!r}")
            docs.append(Doc(rel, meta, sub_of(rel, subs)))
    return docs, errors


def check(docs, errors, today, cfg):
    problems = list(errors)
    stale_days = cfg["stale_days"]

    for d in docs:
        # 7.5 - triage is never a resting state.
        if d.status == "needs-triage":
            problems.append(
                f"{d.path}: `needs-triage` - classify it (type + status) and set a real "
                f"`updated:` date")
        # 7.4 - archive correspondence, with the doc exemption from 5.2.
        if d.status in CLOSED and not d.archived and d.type != "doc":
            problems.append(
                f"{d.path}: status `{d.status}` but not under an archive/ directory")
        if d.archived and d.status in LIVE:
            problems.append(
                f"{d.path}: lives in archive/ but has live status `{d.status}`")
        # 7.1 - blocked must say what it is blocked on.
        if d.status == "blocked" and not d.blocked_on:
            problems.append(f"{d.path}: status `blocked` with no `blocked-on:`")
        if d.updated and d.age_days(today) is None:
            problems.append(f"{d.path}: `updated:` is not an ISO date ({d.updated!r})")
        # 7.2 - staleness.
        if d.status == "active":
            age = d.age_days(today)
            if age is not None and age > stale_days:
                problems.append(
                    f"{d.path}: status `active` but untouched for {age} days "
                    f"(limit {stale_days}) - update it or change its status")

    # 7.3 - an epic's tracker must be at least as fresh as the newest live plan beneath it.
    # This is the check for F2: it catches the moment a child moved and the summary above
    # it did not.
    #
    # Epics are global across the root and every sub-workspace (SPEC 3.6): a plan in
    # `servers/jellyfin/plans/` may hang off a tracker at the root, or the reverse. The
    # price of that is that two live trackers for one epic would be two answers to one
    # question, so it is refused rather than silently letting the last one win.
    trackers = {}
    for d in docs:
        if d.type == "tracker" and not d.archived and d.epic:
            if d.epic in trackers:
                problems.append(
                    f"{d.path}: second live tracker for epic `{d.epic}` - "
                    f"{trackers[d.epic].path} already tracks it")
                continue
            trackers[d.epic] = d
    for epic, tracker in trackers.items():
        children = [d for d in docs
                    if d.epic == epic and d.type == "plan" and not d.archived]
        for c in children:
            ca, ta = c.age_days(today), tracker.age_days(today)
            if ca is None or ta is None:
                continue
            if ca < ta:  # child is more recently updated than its tracker
                problems.append(
                    f"{tracker.path}: tracker (updated {tracker.updated}) is older than "
                    f"its child {c.path} (updated {c.updated}) - the tracker went stale "
                    f"when the child moved")

    for epic in {d.epic for d in docs if d.epic and not d.archived}:
        if epic not in trackers:
            live = [d for d in docs
                    if d.epic == epic and not d.archived and d.status in LIVE]
            if live:
                problems.append(
                    f"epic `{epic}` has {len(live)} live file(s) but no tracker anywhere "
                    f"in the workspace")
    return problems


def render(docs, today, cfg, base=None):
    """Render an index. `base` None renders the root index over every file; a sub-workspace
    path renders that sub-workspace's own index, with links relative to it and a pointer
    back up. Same shape either way, so a reader learns one layout."""
    subs = cfg["subworkspaces"]
    if base is not None:
        docs = [d for d in docs if d.sub == base]
    live = [d for d in docs if not d.archived and d.status in LIVE]
    archived = [d for d in docs if d.archived]
    refs = [d for d in docs if not d.archived and d.status in CLOSED]
    label = cfg["scope_label"]
    # The workspace column only appears once there is more than one place a file can be.
    ws_col = base is None and bool(subs)

    def rel(path):
        return path if base is None else os.path.relpath(path, base).replace(os.sep, "/")

    up = "" if base is None else "../" * (base.count("/") + 1)

    out = [
        "<!-- GENERATED by bin/build-index.py - do not hand-edit. -->",
        "",
        "# Workspace index" if base is None else f"# Workspace index: `{base}`",
        "",
        f"_Generated {today.isoformat()} - "
        f"{len(live)} live, {len(refs)} reference, {len(archived)} archived._",
        "",
    ]
    if base is not None:
        out += [f"Sub-workspace of the root workspace, which indexes everything: "
                f"[`{up}INDEX.md`]({up}INDEX.md).", ""]

    def table(rows):
        head = f"| File | Type | Epic | {label.title()} | Updated | Note |"
        sep = "|---|---|---|---|---|---|"
        if ws_col:
            head = head.replace("| Type |", "| Workspace | Type |", 1)
            sep += "---|"
        out.append(head)
        out.append(sep)
        for d in rows:
            note = d.blocked_on or d.superseded_by or ""
            if len(note) > 90:
                note = note[:87] + "..."
            scope = ", ".join(d.scope) if isinstance(d.scope, list) else (d.scope or "-")
            ws = f" {d.sub or 'root'} |" if ws_col else ""
            out.append(f"| [`{d.name}`]({rel(d.path)}) |{ws} {d.type} | {d.epic or '-'} | "
                       f"{scope or '-'} | {d.updated} | {note} |")
        out.append("")

    for status in LIVE:
        rows = sorted([d for d in live if d.status == status],
                      key=lambda d: (d.epic or "", d.path))
        if not rows:
            continue
        out.append(f"## {status} ({len(rows)})")
        out.append("")
        table(rows)

    if refs:
        out.append(f"## reference ({len(refs)})")
        out.append("")
        out.append("Closed material kept live because it is read, not worked: docs and "
                   "investigations.")
        out.append("")
        table(sorted(refs, key=lambda d: d.path))

    if base is None and subs:
        out.append(f"## sub-workspaces ({len(subs)})")
        out.append("")
        out.append("Each has its own index over just its files. Epics are shared across all "
                   "of them.")
        out.append("")
        for sub in sorted(subs):
            n = sum(1 for d in live if d.sub == sub)
            out.append(f"- [`{sub}/`]({sub}/INDEX.md) - {n} live")
        out.append("")

    out.append(f"## archive ({len(archived)})")
    out.append("")
    if archived:
        by_dir = {}
        for d in archived:
            by_dir.setdefault(os.path.dirname(rel(d.path)), []).append(d)
        for dirname in sorted(by_dir):
            out.append(f"- `{dirname}/` - {len(by_dir[dirname])} files")
    else:
        out.append("_Nothing archived yet._")
    out.append("")
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="validate only; do not write INDEX.md")
    ap.add_argument("--today", help="override today's date (ISO), for testing")
    args = ap.parse_args()

    today = (datetime.date.fromisoformat(args.today) if args.today
             else datetime.date.today())

    cfg = load_config()
    docs, errors = collect(cfg)
    problems = check(docs, errors, today, cfg)

    if problems:
        print(f"{len(problems)} problem(s):", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
    else:
        print(f"ok - {len(docs)} files, no problems")

    if args.check:
        return 1 if problems else 0

    with open(INDEX, "w", encoding="utf-8") as fh:
        fh.write(render(docs, today, cfg))
    print(f"wrote {os.path.relpath(INDEX, ROOT)}")
    for sub in cfg["subworkspaces"]:
        if not os.path.isdir(os.path.join(ROOT, sub)):
            continue  # already reported by collect()
        sub_index = os.path.join(ROOT, sub, "INDEX.md")
        with open(sub_index, "w", encoding="utf-8") as fh:
            fh.write(render(docs, today, cfg, base=sub))
        print(f"wrote {os.path.relpath(sub_index, ROOT)}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
