# Claude Code adapter

Two pieces: guidance so the agent uses the workspace, and a `/park` skill so stopping points
get written down.

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

## 2. The `/park` skill

```
cp -r park /path/to/project/.claude/skills/park
```

Then edit `SKILL.md` and replace `<WORKSPACE_DIR>` with your directory name. The skill reads
`config.toml` for the layout, so the state-gathering commands work in both multi-repo and
monorepo projects without further editing.

Verify it registered by running `/park` in a session. If it does not appear, check that the
file is at `.claude/skills/park/SKILL.md` and that its frontmatter `name:` is `park`.

## 3. Optional: make validation automatic

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
