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
#   setup.sh ../my-app --sub services/api      # add a sub-workspace for services/api
#
# --sub also appends the sub-workspace guidance block to the sub-project's CLAUDE.md, so
# an agent working inside that directory knows which files belong there and which belong
# at the root. Run it once per sub-project; everything else is skipped when already done.
#
# Requires: git, python3. Nothing else.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

usage() {
  sed -n '3,30p' "${BASH_SOURCE[0]}" | sed 's|^# \{0,1\}||'
}

TARGET=""
DIR=".workspace"
SUB=""
BOOTSTRAP_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    # --dir is both passed through and read here, because the placeholder substitution
    # in steps 2 and 3 has to use the same name bootstrap was given.
    --dir)     DIR="$2"; BOOTSTRAP_ARGS+=("$1" "$2"); shift 2 ;;
    --sub)     SUB="${2%/}"; SUB="${SUB#./}"; BOOTSTRAP_ARGS+=("$1" "$2"); shift 2 ;;
    --*=*)     BOOTSTRAP_ARGS+=("$1"); shift ;;
    # Every other option takes a value; keep it with its flag.
    --layout|--ignore-mode|--adopt) BOOTSTRAP_ARGS+=("$1" "$2"); shift 2 ;;
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

# ---------------------------------------------------------------- 4. sub-workspace guidance

# The root block says where files go in general; this one, in the sub-project's own
# CLAUDE.md, says which of those places is *here*. Without it an agent started inside the
# sub-project sees a `.workspace/` and files everything there, including project-wide work.
if [ -n "$SUB" ]; then
  if [ -f "$TARGET/$SUB/.claude/CLAUDE.md" ]; then
    SUB_GUIDE="$TARGET/$SUB/.claude/CLAUDE.md"
  else
    SUB_GUIDE="$TARGET/$SUB/CLAUDE.md"
  fi
  UP="$(printf '%s\n' "$SUB" | awk -F/ '{ for (i = 1; i <= NF; i++) printf "../" }')"
  if grep -q "^## Knowledge base: this directory's sub-workspace" "$SUB_GUIDE" 2>/dev/null; then
    echo "sub-workspace guidance already present in ${SUB_GUIDE#"$TARGET"/}, left alone"
  else
    {
      [ -s "$SUB_GUIDE" ] && printf '\n'
      sed -n '/^## Knowledge base/,$p' "$SRC/adapters/claude-code/CLAUDE-sub-block.md" \
        | sed -e "s|<WORKSPACE_DIR>|$DIR|g" -e "s|<SUB_PATH>|$SUB|g" -e "s|<UP>|$UP|g"
    } >> "$SUB_GUIDE"
    echo "appended sub-workspace guidance to ${SUB_GUIDE#"$TARGET"/}"
  fi
fi

echo
if [ -n "$SUB" ]; then
  echo "done. next: write a tracker for the epic $SUB is on"
  echo "  cp $DIR/templates/tracker.md $DIR/$SUB/trackers/<epic>.md"
else
  echo "done. next: write a tracker for the epic you are starting"
  echo "  cp $DIR/templates/tracker.md $DIR/trackers/<epic>.md"
fi
