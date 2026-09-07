#!/usr/bin/env bash
#
# Set up agent-workspace in a target repo, wired for Claude Code.
#
# bootstrap.sh creates the structure. This adds the two Claude Code pieces that turn a
# directory into something an agent actually uses:
#
#   1. bootstrap.sh       -> .workspace/ scaffold, tooling, notes git repo, ignore wiring
#   2. the /park skill    -> .claude/skills/park/SKILL.md, placeholder substituted
#   3. the guidance block -> appended to the repo's CLAUDE.md, placeholder substituted
#
# Steps 2 and 3 are the ones that get skipped, and skipping them is the whole failure:
# the structure exists but nothing tells an agent to use it, so notes keep landing at the
# repo root. Doing all three in one command is the point of this script.
#
# Idempotent. Re-running refreshes the tooling and skips anything already wired.
#
# Usage: setup.sh /path/to/repo [bootstrap.sh options...]
#
#   setup.sh ../my-app
#   setup.sh ../my-app --dir .notes
#   setup.sh ../my-app --adopt ./docs/notes
#   setup.sh ../my-app --ignore-mode gitignore
#
# Requires: git, python3. Nothing else.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

usage() {
  sed -n '3,25p' "${BASH_SOURCE[0]}" | sed 's|^# \{0,1\}||'
}

TARGET=""
DIR=".workspace"
BOOTSTRAP_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    # --dir is both passed through and read here, because the placeholder substitution
    # in steps 2 and 3 has to use the same name bootstrap was given.
    --dir)     DIR="$2"; BOOTSTRAP_ARGS+=("$1" "$2"); shift 2 ;;
    -*)        BOOTSTRAP_ARGS+=("$1"); shift ;;
    *)
      if [ -z "$TARGET" ]; then TARGET="$1"; else BOOTSTRAP_ARGS+=("$1"); fi
      shift ;;
  esac
done

[ -n "$TARGET" ] || { echo "no target repo given" >&2; echo >&2; usage >&2; exit 2; }
[ -d "$TARGET" ] || { echo "no such directory: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

command -v git >/dev/null || { echo "git is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }

# Layout detection keys off whether the target is inside a git work tree (SPEC 3.3/3.4),
# so a repo that has not been `git init`ed yet silently gets the multi-repo layout. That
# is a real choice in a multi-repo workspace and a mistake in a new single repo, and the
# two are indistinguishable from here - so ask rather than guess.
if ! git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "NOTE: $TARGET is not inside a git work tree."
  echo "      bootstrap will pick the multi-repo layout (workspace as its own root,"
  echo "      code in sibling directories). If you meant a single repo, run 'git init'"
  echo "      there first and re-run this."
  if [ -t 0 ]; then
    printf 'continue anyway? [y/N] '
    read -r reply
    case "$reply" in y|Y) ;; *) echo "aborted"; exit 1 ;; esac
  else
    echo "      (not a tty, continuing)"
  fi
fi

# ---------------------------------------------------------------- 1. scaffold

cd "$TARGET"
"$SRC/bootstrap.sh" "${BOOTSTRAP_ARGS[@]}"

# ---------------------------------------------------------------- 2. the /park skill

SKILL="$TARGET/.claude/skills/park/SKILL.md"
mkdir -p "$(dirname "$SKILL")"
sed "s|<WORKSPACE_DIR>|$DIR|g" "$SRC/adapters/claude-code/park/SKILL.md" > "$SKILL"
echo "installed /park skill at .claude/skills/park/SKILL.md"

# ---------------------------------------------------------------- 3. the guidance block

# The block belongs in the CLAUDE.md highest in scope for the project. Within a single
# repo, prefer .claude/CLAUDE.md when the repo already keeps its guidance there; fall
# back to the root. In a multi-repo workspace, run this against the workspace root, not
# a product repo - guidance inside one repo is not read while working in another.
if [ -f "$TARGET/.claude/CLAUDE.md" ]; then
  GUIDE="$TARGET/.claude/CLAUDE.md"
else
  GUIDE="$TARGET/CLAUDE.md"
fi

if grep -q '^## Knowledge base: plans, trackers, sessions, docs' "$GUIDE" 2>/dev/null; then
  echo "guidance block already present in ${GUIDE#"$TARGET"/}, left alone"
else
  # Everything above the horizontal rule in CLAUDE-block.md is instructions to the
  # reader and must not be pasted, so start at the heading.
  {
    [ -s "$GUIDE" ] && printf '\n'
    sed -n '/^## Knowledge base/,$p' "$SRC/adapters/claude-code/CLAUDE-block.md" \
      | sed "s|<WORKSPACE_DIR>|$DIR|g"
  } >> "$GUIDE"
  echo "appended guidance block to ${GUIDE#"$TARGET"/}"
fi

echo
echo "done. next: write a tracker for the epic you are starting"
echo "  cp $DIR/templates/tracker.md $DIR/trackers/<epic>.md"
