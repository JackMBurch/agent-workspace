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
    -h|--help)      usage; exit 0 ;;
    *)              echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$LAYOUT" in auto|multi-repo|monorepo) ;; *)
  echo "--layout must be auto, multi-repo or monorepo" >&2; exit 2 ;; esac
case "$IGNORE_MODE" in exclude|gitignore) ;; *)
  echo "--ignore-mode must be exclude or gitignore" >&2; exit 2 ;; esac

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

if [ "$LAYOUT" = "monorepo" ]; then
  GITDIR="$(git -C "$TARGET" rev-parse --git-dir 2>/dev/null || true)"
  case "$GITDIR" in /*) ;; *) GITDIR="$TARGET/$GITDIR" ;; esac

  if [ "$IGNORE_MODE" = "exclude" ]; then
    EXCLUDE="$GITDIR/info/exclude"
    mkdir -p "$(dirname "$EXCLUDE")"
    if ! grep -qxF "/$DIR/" "$EXCLUDE" 2>/dev/null; then
      printf '\n# agent-workspace: nested notes repo, local to this clone\n/%s/\n' \
        "$DIR" >> "$EXCLUDE"
      echo "excluded /$DIR/ via .git/info/exclude (local, commits nothing)"
    else
      echo "/$DIR/ already excluded"
    fi
  else
    if ! grep -qxF "/$DIR/" "$TARGET/.gitignore" 2>/dev/null; then
      printf '\n# agent-workspace notes repo\n/%s/\n' "$DIR" >> "$TARGET/.gitignore"
      echo "added /$DIR/ to the shared .gitignore (opt-in - this is a committed change)"
    else
      echo "/$DIR/ already in .gitignore"
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
  echo "next: write a tracker for your current epic - cp $DIR/templates/tracker.md $DIR/trackers/<epic>.md"
else
  echo "workspace created, but validation reported problems (see above)."
  if [ -n "$ADOPT" ]; then
    echo "That is expected after --adopt: an adopted file that did not already declare a"
    echo "type is needs-triage until someone reads it and sets a real type and status."
  fi
fi
exit "$status"
