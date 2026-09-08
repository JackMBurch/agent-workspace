<!--
  Paste the block below into the CLAUDE.md of a sub-project that has a sub-workspace
  (bootstrap.sh --sub). Replace <WORKSPACE_DIR> with the workspace directory name,
  <SUB_PATH> with the sub-project's path relative to the project root, and <UP> with the
  `../` prefix that reaches the project root from the sub-project (`../../` for
  `servers/jellyfin`). setup.sh --sub does all three.

  Everything above the horizontal rule is instructions to you and should not be pasted.
-->

---

## Knowledge base: this directory's sub-workspace

`<SUB_PATH>/` has its own slice of the project workspace. `<WORKSPACE_DIR>/` **here** is a
symlink to `<UP><WORKSPACE_DIR>/<SUB_PATH>/`, so the four types, the frontmatter, and every
rule in the root `CLAUDE.md` "Knowledge base" section apply unchanged. The only question
this block answers is *where a file goes*:

- **Scoped to this directory** - a tracker, session or doc about `<SUB_PATH>` alone: here,
  under `<WORKSPACE_DIR>/trackers/`, `<WORKSPACE_DIR>/sessions/`, `<WORKSPACE_DIR>/docs/`.
- **Spanning the project** - shared tooling, or work touching more than one sub-project:
  the root workspace, `<UP><WORKSPACE_DIR>/`.
- **`epic:` is global.** A plan here may point at a tracker at the root and the reverse; the
  validator resolves epics across the whole tree and refuses two live trackers for one epic.
  Link across with a relative path (`<UP><WORKSPACE_DIR>/trackers/<epic>.md`).
- **`<WORKSPACE_DIR>/INDEX.md` here** lists only this sub-workspace;
  `<UP><WORKSPACE_DIR>/INDEX.md` lists everything and says which sub-workspace each file is
  in. `python3 <WORKSPACE_DIR>/bin/build-index.py` from here regenerates both.
- **One git repository**, the root workspace. Commit there; there is nothing to commit here.
