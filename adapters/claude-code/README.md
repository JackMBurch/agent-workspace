# Claude Code adapter

Three pieces: guidance so the agent uses the workspace, a `/park` skill so stopping points get
written down, and a `setup.sh` that installs both alongside the scaffold in one command.

## Quick setup

```
./adapters/claude-code/setup.sh /path/to/repo
```

That runs `bootstrap.sh` in the target, installs the `/park` skill with the workspace directory
name substituted in, and appends the guidance block to the project's `CLAUDE.md`. Options are
passed through to `bootstrap.sh` (`--dir`, `--adopt`, `--ignore-mode`, `--layout`), and
`--help` lists them.

It is idempotent: re-running refreshes the copied tooling and leaves everything already wired
alone, so upgrading is just running it again.

For a sub-project that should keep its own trackers (spec 3.6):

```
./adapters/claude-code/setup.sh /path/to/repo --sub servers/jellyfin
```

That runs `bootstrap.sh --sub`, then appends [`CLAUDE-sub-block.md`](CLAUDE-sub-block.md) to
the sub-project's `CLAUDE.md`. The root block says where files go in general; the sub-block
says which of those places is *here*, because an agent started inside the sub-project sees a
`.workspace/` and would otherwise file project-wide work in it. Once per sub-project.

**`git init` the target first** if it is meant to be a single repo. Layout detection asks
whether the target is inside a git work tree, so a repo that has not been initialised yet
detects as multi-repo, which is almost never what was meant. The script warns and asks before
continuing.

The rest of this file describes the same three steps done by hand, which is worth reading
before running the script on a repo that matters.

## 1. Guidance

Paste the block from [`CLAUDE-block.md`](CLAUDE-block.md) into your project's `CLAUDE.md`,
replacing `<WORKSPACE_DIR>` with your workspace directory name.

Put it in the `CLAUDE.md` that is **highest in scope** for the project. In a multi-repo
workspace that is the one at the workspace root, not one inside a product repo: the rule that
plans never go into a product repo has to be visible from every repo, and guidance inside one
repo is not read while working in another.

If a child repository's own guidance conflicts (some ship a rule pointing plans at a repo-local
directory), state explicitly in your top-level file that it wins. Do not edit the child's
guidance if it is shared with a wider team.

Within a single repo, `setup.sh` appends to `.claude/CLAUDE.md` when that file already exists
and to `CLAUDE.md` at the root otherwise, following whichever convention the repo already uses.

## 2. The `/park` skill

```
cp -r park /path/to/project/.claude/skills/park
```

Then edit `SKILL.md` and replace `<WORKSPACE_DIR>` with your directory name. The skill reads
`config.toml` for the layout, so the state-gathering commands work in both multi-repo and
monorepo projects without further editing.

Verify it registered by running `/skills` in a session. If it does not appear, check that the
file is at `.claude/skills/park/SKILL.md` and that its frontmatter `name:` is `park`.

**`/park` is per-project, not global.** The `<WORKSPACE_DIR>` substitution is what makes it
per-project: one copy in `~/.claude/skills/` would have to bake in a single directory name and
would then write session files to a path that does not exist in any project that named its
workspace something else.

## 3. The `/setup-workspace` skill (global)

For setting up *future* repos, [`setup-workspace/`](setup-workspace/) is a skill that drives
the whole flow: it locates this clone, settles the layout question, runs `setup.sh`, handles
triage after `--adopt`, and writes the first tracker. Unlike `/park` it has no placeholder to
substitute, so it installs once, globally:

```
mkdir -p ~/.claude/skills/setup-workspace
cp adapters/claude-code/setup-workspace/SKILL.md ~/.claude/skills/setup-workspace/SKILL.md
```

Then `/setup-workspace` is available in every project. Per the Claude Code docs, personal
skills live at `~/.claude/skills/<name>/SKILL.md`, project skills at
`.claude/skills/<name>/SKILL.md`, and the directory name becomes the command.

## 4. Optional: make validation automatic

The index goes stale between runs of `build-index.py`. If that becomes a nuisance, a `Stop`
hook in `.claude/settings.json` regenerates it at the end of every session:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 .workspace/bin/build-index.py >/dev/null 2>&1 || true"
          }
        ]
      }
    ]
  }
}
```

The `|| true` is deliberate: a validation failure should surface when someone runs `--check`,
not by making a session appear to fail.

The path is relative, so this can go in `~/.claude/settings.json` to apply everywhere - in a
project with no workspace the command simply finds no file and the `|| true` swallows it.
