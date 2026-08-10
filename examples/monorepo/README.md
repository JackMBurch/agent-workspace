# Example: monorepo layout

A fictional monorepo. The project root **is** a git repository, and the workspace is a second,
nested repository inside it.

```
shop-monorepo/          (git repo)
  packages/search-core/
  apps/web/
  .workspace/           (git repo, nested)  <- this example
```

## The only real difference

**The structure, schema, vocabulary and tooling are identical to the multi-repo layout.** Two
things change:

**1. The nested repository must be excluded.** Git sees `.workspace/` as an untracked directory.
A `git add -A` at the root can commit it as a stray gitlink, producing a broken pseudo-submodule
that nobody can clone. Bootstrap writes this to `.git/info/exclude`:

```
# agent-workspace: nested notes repo, local to this clone
/.workspace/
```

`.git/info/exclude` is used rather than the root `.gitignore` because it is local to your clone
and commits nothing. Writing the path into a shared `.gitignore` announces to everyone with
repository access that you keep private notes there. If your team has adopted the convention
together, opt in with `--ignore-mode gitignore`.

The exclude file cannot be committed as part of this example, since it lives inside `.git/`.
Bootstrap creates it, and you can verify it worked: with the workspace in place,
`git status --porcelain` at the monorepo root should print **nothing**.

**2. `scope:` names packages rather than repositories,** and `scope_label = "packages"` in
`config.toml` makes the generated index say so. This is cosmetic; nothing depends on it.

## What this example demonstrates

| File | Shows |
|---|---|
| `trackers/search-relevance.md` | An epic tracker scoped to packages rather than repos |
| `plans/search-relevance/s1-semantic-reranking.md` | `paused`, and why that is not `blocked` - the decision belongs to the team, so nobody external is holding it |

## Try it

```
cp -r examples/monorepo /tmp/mono-example
mkdir -p /tmp/mono-example/.workspace/bin
cp lib/build-index.py /tmp/mono-example/.workspace/bin/
python3 /tmp/mono-example/.workspace/bin/build-index.py --check
```

For the full monorepo experience including the exclude wiring, run bootstrap against a real
repository instead:

```
cd /path/to/your/monorepo
/path/to/agent-workspace/bootstrap.sh
git status --porcelain      # must print nothing
```

## A note on `stale_days`

As in the multi-repo example, this sets `stale_days = 36500` so that frozen example dates do not
fail the staleness check later. **Do not copy that into a real workspace.**
