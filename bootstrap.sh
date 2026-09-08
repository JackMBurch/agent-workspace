#!/usr/bin/env bash
#
# agent-workspace bootstrap. Creates a conforming workspace in the current project,
# or adopts an existing notes directory into one.
#
# Idempotent: safe to re-run. Existing files are never overwritten except the tooling
# in bin/, which is refreshed on purpose.
#
# Requires: git, python3. Nothing else.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(pwd)"

DIR=".workspace"
LAYOUT="auto"
IGNORE_MODE="exclude"
ADOPT=""
SUB=""
TODAY="$(date +%F)"

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [options]

  --dir NAME             workspace directory name (default: .workspace)
  --layout MODE          auto | multi-repo | monorepo   (default: auto)
  --ignore-mode MODE     exclude | gitignore            (default: exclude)
                         Monorepo only. `exclude` writes .git/info/exclude, which is
                         local and commits nothing. `gitignore` writes the shared root
                         .gitignore, which tells everyone with repo access that you keep
                         notes at that path - opt in deliberately.
  --adopt PATH           move an existing notes directory in and mark every file
                         `status: needs-triage` for classification
  --sub PATH             add a sub-workspace for the sub-project at PATH (relative to the
                         project root): creates DIR/PATH/{plans,trackers,sessions,docs},
                         links PATH/DIR to it, registers it in config.toml and excludes
                         the link from PATH's repository. Re-run once per sub-project.
  -h, --help             this message

Run from the root of the project you want the workspace in.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)          DIR="$2"; shift 2 ;;
    --layout)       LAYOUT="$2"; shift 2 ;;
    --ignore-mode)  IGNORE_MODE="$2"; shift 2 ;;
    --adopt)        ADOPT="$2"; shift 2 ;;
    --sub)          SUB="$2"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *)              echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$LAYOUT" in auto|multi-repo|monorepo) ;; *)
  echo "--layout must be auto, multi-repo or monorepo" >&2; exit 2 ;; esac
case "$IGNORE_MODE" in exclude|gitignore) ;; *)
  echo "--ignore-mode must be exclude or gitignore" >&2; exit 2 ;; esac

# A sub-workspace path mirrors a real sub-project path, so it is validated against the
# code tree, not invented: no absolute paths, no `..`, and the directory must exist.
if [ -n "$SUB" ]; then
  SUB="${SUB%/}"; SUB="${SUB#./}"
  case "$SUB" in
    ""|/*|../*|*/../*|*/..|..) echo "--sub must be a relative path inside the project" >&2; exit 2 ;;
  esac
  [ -d "$TARGET/$SUB" ] || { echo "--sub: no such directory: $TARGET/$SUB" >&2; exit 1; }
  case "$SUB" in bin|templates|plans|trackers|sessions|docs|bin/*|templates/*|plans/*|trackers/*|sessions/*|docs/*)
    echo "--sub: $SUB collides with a workspace directory name" >&2; exit 2 ;; esac
fi

command -v git >/dev/null || { echo "git is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }

WS="$TARGET/$DIR"

# ---------------------------------------------------------------- layout detection
#
# The distinction is whether the project root is itself inside a git work tree. If it is,
# the workspace repo will be NESTED and must be excluded (SPEC 3.4). If it is not, there
# is no enclosing repo and nothing to exclude (SPEC 3.3).
#
# `git rev-parse` is run from the target, and any workspace repo created by an earlier run
# is stepped over by asking about the target directory itself, not $WS.

detect_layout() {
  if git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "monorepo"
  else
    echo "multi-repo"
  fi
}

if [ "$LAYOUT" = "auto" ]; then
  LAYOUT="$(detect_layout)"
  echo "detected layout: $LAYOUT"
fi

if [ "$LAYOUT" = "monorepo" ]; then
  SCOPE_LABEL="packages"
else
  SCOPE_LABEL="repos"
fi

# ---------------------------------------------------------------- scaffold

echo "creating $DIR/ in $TARGET"
mkdir -p \
  "$WS/bin" \
  "$WS/templates" \
  "$WS/plans/archive" \
  "$WS/trackers/archive" \
  "$WS/sessions/archive" \
  "$WS/docs/investigations"

# Keep the empty directories in git. Removed automatically once a directory has content.
for d in plans/archive trackers/archive sessions/archive docs/investigations; do
  [ -z "$(ls -A "$WS/$d" 2>/dev/null)" ] && touch "$WS/$d/.gitkeep"
done

# Tooling is COPIED, not linked: once bootstrapped, the project has no dependency on this
# repo. Refreshed on re-run so an upgrade is just re-running bootstrap.
cp "$SRC/lib/build-index.py" "$WS/bin/build-index.py"
chmod +x "$WS/bin/build-index.py"
cp "$SRC"/templates/*.md "$WS/templates/"

if [ ! -f "$WS/config.toml" ]; then
  sed -e "s|__WORKSPACE_DIR__|$DIR|" \
      -e "s|__LAYOUT__|$LAYOUT|" \
      -e "s|__SCOPE_LABEL__|$SCOPE_LABEL|" \
      "$SRC/templates/config.toml" > "$WS/config.toml"
else
  echo "config.toml exists, left alone"
fi

if [ ! -f "$WS/.gitignore" ]; then
  cat > "$WS/.gitignore" <<'EOF'
.claude/
.DS_Store
__pycache__/
EOF
fi

if [ ! -f "$WS/README.md" ]; then
  cat > "$WS/README.md" <<EOF
---
type: doc
status: done
updated: $TODAY
---

# Workspace

Plans, epic trackers, parked session state and reference docs for this project.
Structured per the agent-workspace spec: https://github.com/JackMBurch/agent-workspace

- **INDEX.md** - what is live, grouped by status. Generated; do not hand-edit.
- **trackers/** - one file per epic. To know where something is up to, read the tracker,
  not the plans.

## The four types

| Type | Answers | Lifecycle |
|---|---|---|
| plan | how will this be built? | frozen once work starts |
| tracker | where is this epic up to? | updated in the same turn as the work |
| session | what was I doing when I stopped? | write-once, archived on resume |
| doc | how does this work / what did we find? | reference; superseded, not edited |

If a file has checkboxes or a per-item status column, it is a **tracker**, not a plan.

## Commands

\`\`\`
python3 $DIR/bin/build-index.py            # regenerate INDEX.md
python3 $DIR/bin/build-index.py --check    # validate; non-zero exit on a problem
\`\`\`

Templates for each type are in \`templates/\`.
EOF
fi

# ---------------------------------------------------------------- adoption

if [ -n "$ADOPT" ]; then
  ADOPT_ABS="$(cd "$ADOPT" && pwd)"
  echo "adopting $ADOPT_ABS"
  count=0
  triaged=0
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"

    # Type guess from the filename. DELIBERATELY WEAK - see SPEC 5.3. It exists to give
    # triage a starting point, never to stand in for a decision, which is why every
    # adopted file also gets `status: needs-triage` and fails --check until reclassified.
    lower="$(echo "$base" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
      *todo*|*tracker*|*progress*|*checklist*) t="tracker" ;;
      *handoff*|*session*|*park*)              t="session" ;;
      *investigation*|*research*|*findings*|*guide*|*onboarding*|*roadmap*) t="doc" ;;
      *)                                        t="plan" ;;
    esac

    # A file that already declares a type is trusted and filed where it belongs. Only
    # guessed files are staged in plans/ for triage to sort.
    tagged=""
    if head -c 4 "$f" | grep -q '^---'; then
      tagged="$(sed -n '2,20p' "$f" | grep -m1 '^type:' | cut -d: -f2- | tr -d ' ' || true)"
    fi

    case "${tagged:-$t}" in
      tracker) subdir="trackers" ;;
      session) subdir="sessions" ;;
      doc)     subdir="docs" ;;
      *)       subdir="plans" ;;
    esac
    # Guessed files always stage in plans/, whatever the guess: the guess picks the `type:`
    # field, not the destination, so triage has one place to look.
    [ -z "$tagged" ] && subdir="plans"

    dest="$WS/$subdir/$base"
    [ -e "$dest" ] && dest="$WS/$subdir/${base%.md}-adopted.md"

    if [ -n "$tagged" ]; then
      echo "  $base: already typed as $tagged, filed under $subdir/"
      mv "$f" "$dest"
    else
      { printf -- '---\ntype: %s\nstatus: needs-triage\nupdated: %s\n---\n\n' "$t" "$TODAY"
        cat "$f"; } > "$dest"
      rm "$f"
    fi
    count=$((count + 1))
    [ -z "$tagged" ] && triaged=$((triaged + 1))
  done < <(find "$ADOPT_ABS" -type f -name '*.md' -print0)
  echo "adopted $count file(s); $triaged marked needs-triage, $((count - triaged)) already typed"
  find "$ADOPT_ABS" -type d -empty -delete 2>/dev/null || true
fi

# ---------------------------------------------------------------- git

if [ ! -d "$WS/.git" ]; then
  git -C "$WS" init -q
  git -C "$WS" symbolic-ref HEAD refs/heads/main 2>/dev/null || true
  echo "initialised git repo in $DIR/ (no remote, by design - see SPEC 3.5)"
else
  echo "git repo already present in $DIR/"
fi

# ---------------------------------------------------------------- ignore wiring

# exclude_path REPO_DIR PATTERN LABEL - keep PATTERN out of the repository whose work tree
# holds REPO_DIR, via .git/info/exclude (local) or the shared .gitignore (opt-in).
exclude_path() {
  local repo="$1" pattern="$2" label="$3" gitdir top exclude
  top="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$top" ] || return 0
  if [ "$IGNORE_MODE" = "exclude" ]; then
    gitdir="$(git -C "$repo" rev-parse --git-dir)"
    case "$gitdir" in /*) ;; *) gitdir="$repo/$gitdir" ;; esac
    exclude="$gitdir/info/exclude"
    mkdir -p "$(dirname "$exclude")"
    if ! grep -qxF "$pattern" "$exclude" 2>/dev/null; then
      printf '\n# agent-workspace: %s, local to this clone\n%s\n' "$label" "$pattern" >> "$exclude"
      echo "excluded $pattern via ${exclude#"$top"/} (local, commits nothing)"
    else
      echo "$pattern already excluded"
    fi
  else
    if ! grep -qxF "$pattern" "$top/.gitignore" 2>/dev/null; then
      printf '\n# agent-workspace: %s\n%s\n' "$label" "$pattern" >> "$top/.gitignore"
      echo "added $pattern to the shared .gitignore (opt-in - this is a committed change)"
    else
      echo "$pattern already in .gitignore"
    fi
  fi
}

if [ "$LAYOUT" = "monorepo" ]; then
  exclude_path "$TARGET" "/$DIR/" "nested notes repo"
fi

# ---------------------------------------------------------------- sub-workspace
#
# One workspace repository, with a slice of it for a sub-project (SPEC 3.6). The slice
# lives at $WS/$SUB - the same path the sub-project has in the code tree - and the
# sub-project gets a symlink named $DIR pointing at it, so `$DIR/trackers/` means the
# right thing from either directory. bin/ and templates/ inside the slice are links to
# the root's: there is one tool and one set of templates, and build-index.py resolves
# symlinks so that running it through the link still indexes the whole tree.

if [ -n "$SUB" ]; then
  SUBWS="$WS/$SUB"
  echo "creating sub-workspace $DIR/$SUB/ for $SUB/"
  mkdir -p "$SUBWS/plans/archive" "$SUBWS/trackers/archive" \
           "$SUBWS/sessions/archive" "$SUBWS/docs/investigations"
  for d in plans/archive trackers/archive sessions/archive docs/investigations; do
    [ -z "$(ls -A "$SUBWS/$d" 2>/dev/null)" ] && touch "$SUBWS/$d/.gitkeep"
  done
  relpath() { python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$1" "$2"; }
  for d in bin templates; do
    if [ -e "$SUBWS/$d" ] && [ ! -L "$SUBWS/$d" ]; then
      echo "  $DIR/$SUB/$d exists and is not a symlink, left alone"
    else
      ln -sfn "$(relpath "$WS/$d" "$SUBWS")" "$SUBWS/$d"
    fi
  done

  if [ ! -f "$SUBWS/README.md" ]; then
    UP="$(relpath "$WS" "$SUBWS")"
    cat > "$SUBWS/README.md" <<EOF
---
type: doc
status: done
updated: $TODAY
---

# Sub-workspace: \`$SUB\`

The slice of the project workspace for work scoped to \`$SUB/\`. Same four types, same
rules, same repository as the root workspace at [\`$UP/\`]($UP/README.md); only the
scope differs. Work that spans the project belongs at the root, not here.

- **INDEX.md** here lists only this sub-workspace. The root \`INDEX.md\` lists everything.
- \`epic:\` names are shared with the root: a plan here may hang off a root tracker, and
  the validator refuses two live trackers for one epic wherever they live.
- \`bin/\` and \`templates/\` are links to the root's. \`python3 $DIR/bin/build-index.py\`
  from \`$SUB/\` regenerates every index, not just this one.
EOF
  fi

  # Register it. config.toml is hand-editable, so this rewrites one line rather than the
  # file: the existing `subworkspaces = [...]` line if there is one, else appended.
  python3 - "$WS/config.toml" "$SUB" <<'PY'
import re, sys
path, sub = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read() if __import__("os").path.exists(path) else ""
m = re.search(r'^subworkspaces\s*=\s*\[(.*?)\]\s*$', text, re.M)
if m:
    items = [x.strip().strip('"\'') for x in m.group(1).split(",") if x.strip()]
    if sub in items:
        print(f"  {sub} already registered in config.toml"); sys.exit(0)
    items.append(sub)
    line = "subworkspaces = [" + ", ".join(f'"{i}"' for i in items) + "]"
    text = text[:m.start()] + line + text[m.end():]
else:
    text = text.rstrip("\n") + "\n\n# Sub-workspaces (SPEC 3.6), mirroring sub-project paths.\n" \
           + f'subworkspaces = ["{sub}"]\n'
open(path, "w", encoding="utf-8").write(text)
print(f"  registered {sub} in config.toml")
PY

  # The link the sub-project sees. Refuse to replace a real directory: that would be
  # someone's notes, and --adopt is the path for those.
  LINK="$TARGET/$SUB/$DIR"
  LINK_TARGET="$(relpath "$SUBWS" "$TARGET/$SUB")"
  if [ -L "$LINK" ]; then
    [ "$(readlink "$LINK")" = "$LINK_TARGET" ] || ln -sfn "$LINK_TARGET" "$LINK"
    echo "  $SUB/$DIR -> $LINK_TARGET"
  elif [ -e "$LINK" ]; then
    echo "  $SUB/$DIR already exists and is not a symlink - not touching it." >&2
    echo "  If it holds notes, move them into $DIR/$SUB/ (or use --adopt) and re-run." >&2
    exit 1
  else
    ln -s "$LINK_TARGET" "$LINK"
    echo "  $SUB/$DIR -> $LINK_TARGET"
  fi

  # The link sits inside whichever repository owns $SUB (the monorepo, or a sibling repo
  # in a multi-repo layout). No trailing slash: to git a symlink is a file, and a
  # directory-only pattern would not match it.
  SUB_TOP="$(git -C "$TARGET/$SUB" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$SUB_TOP" ]; then
    LINK_REL="${LINK#"$SUB_TOP"/}"
    exclude_path "$TARGET/$SUB" "/$LINK_REL" "link to the $SUB sub-workspace"
    if [ -n "$(git -C "$SUB_TOP" status --porcelain -- "$LINK_REL" 2>/dev/null)" ]; then
      echo "  WARNING: git still reports $LINK_REL as untracked - check the exclude" >&2
    fi
  fi
fi

# ---------------------------------------------------------------- verify

echo
echo "validating..."
if python3 "$WS/bin/build-index.py"; then
  status=0
else
  status=$?
fi

echo
if [ "$status" -eq 0 ]; then
  echo "workspace ready at $DIR/"
  if [ -n "$SUB" ]; then
    echo "next: write a tracker for the sub-project's current epic - cp $DIR/templates/tracker.md $DIR/$SUB/trackers/<epic>.md"
  else
    echo "next: write a tracker for your current epic - cp $DIR/templates/tracker.md $DIR/trackers/<epic>.md"
  fi
else
  echo "workspace created, but validation reported problems (see above)."
  if [ -n "$ADOPT" ]; then
    echo "That is expected after --adopt: an adopted file that did not already declare a"
    echo "type is needs-triage until someone reads it and sets a real type and status."
  fi
fi
exit "$status"
