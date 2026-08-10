#!/usr/bin/env python3
"""Tests for lib/build-index.py.

Each rule in SPEC section 7 gets a passing fixture and a failing one.

The script is exercised as a subprocess rather than imported, for two reasons: it derives
its workspace root from its own location, so it has to actually live in a bin/ directory to
behave correctly, and the exit code is part of its contract.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, "lib", "build-index.py")
TODAY = "2026-08-10"


def fm(type_, status, updated, **extra):
    """Build a frontmatter block plus a token line of body."""
    lines = [f"type: {type_}", f"status: {status}", f"updated: {updated}"]
    for k, v in extra.items():
        lines.append(f"{k.replace('_', '-')}: {v}")
    return "---\n" + "\n".join(lines) + "\n---\n\n# Test file\n"


class WorkspaceCase(unittest.TestCase):
    """Builds a throwaway workspace, copies the real script into bin/, and runs it."""

    def build(self, files, config=None):
        root = tempfile.mkdtemp(prefix="aw-test-")
        self.addCleanup(shutil.rmtree, root, ignore_errors=True)
        os.makedirs(os.path.join(root, "bin"))
        shutil.copy(SCRIPT, os.path.join(root, "bin", "build-index.py"))
        if config is not None:
            with open(os.path.join(root, "config.toml"), "w", encoding="utf-8") as fh:
                fh.write(config)
        for rel, content in files.items():
            full = os.path.join(root, rel)
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "w", encoding="utf-8") as fh:
                fh.write(content)
        return root

    def run_check(self, root, extra_args=()):
        proc = subprocess.run(
            [sys.executable, os.path.join(root, "bin", "build-index.py"),
             "--check", "--today", TODAY, *extra_args],
            capture_output=True, text=True)
        return proc.returncode, proc.stdout + proc.stderr

    def assertClean(self, files, config=None):
        code, out = self.run_check(self.build(files, config))
        self.assertEqual(code, 0, f"expected clean, got:\n{out}")
        return out

    def assertFails(self, files, needle, config=None):
        code, out = self.run_check(self.build(files, config))
        self.assertEqual(code, 1, f"expected failure, got clean:\n{out}")
        self.assertIn(needle, out)
        return out


# A minimal valid workspace, reused as the base for negative cases.
VALID = {
    "trackers/checkout-v2.md": fm("tracker", "active", TODAY, epic="checkout-v2"),
    "plans/checkout-v2/c0-payment-intents.md": fm(
        "plan", "active", TODAY, epic="checkout-v2", scope="[api, web]"),
}


class TestSchema(WorkspaceCase):
    """SPEC 7.1 and 4.3."""

    def test_valid_workspace_passes(self):
        self.assertClean(VALID)

    def test_missing_frontmatter_is_an_error_not_a_skip(self):
        # 4.3: a skipped file is invisible, which is the failure the spec replaces.
        files = dict(VALID, **{"docs/notes.md": "# Just a heading\n"})
        self.assertFails(files, "no frontmatter block")

    def test_unterminated_frontmatter(self):
        files = dict(VALID, **{"docs/notes.md": "---\ntype: doc\n"})
        self.assertFails(files, "unterminated frontmatter block")

    def test_missing_required_field(self):
        files = dict(VALID, **{"docs/notes.md": "---\ntype: doc\nstatus: done\n---\n"})
        self.assertFails(files, "missing required `updated:`")

    def test_unknown_type(self):
        files = dict(VALID, **{"docs/notes.md": fm("memo", "done", TODAY)})
        self.assertFails(files, "unknown type")

    def test_unknown_status(self):
        files = dict(VALID, **{"docs/notes.md": fm("doc", "wip", TODAY)})
        self.assertFails(files, "unknown status")

    def test_non_iso_date(self):
        files = dict(VALID, **{"docs/notes.md": fm("doc", "done", "last Tuesday")})
        self.assertFails(files, "not an ISO date")

    def test_blocked_requires_blocked_on(self):
        files = dict(VALID, **{
            "plans/checkout-v2/c1-refunds.md": fm(
                "plan", "blocked", TODAY, epic="checkout-v2")})
        self.assertFails(files, "status `blocked` with no `blocked-on:`")

    def test_blocked_with_blocked_on_passes(self):
        files = dict(VALID, **{
            "plans/checkout-v2/c1-refunds.md": fm(
                "plan", "blocked", TODAY, epic="checkout-v2",
                blocked_on='"a sandbox credential from the payments provider"')})
        self.assertClean(files)


class TestStaleness(WorkspaceCase):
    """SPEC 7.2."""

    def test_active_file_past_the_limit_fails(self):
        files = dict(VALID, **{
            "plans/checkout-v2/c1-refunds.md": fm(
                "plan", "active", "2026-06-01", epic="checkout-v2")})
        self.assertFails(files, "untouched for")

    def test_paused_file_past_the_limit_passes(self):
        # Only `active` asserts current work, so only `active` can go stale.
        files = dict(VALID, **{
            "plans/checkout-v2/c1-refunds.md": fm(
                "plan", "paused", "2026-01-01", epic="checkout-v2")})
        self.assertClean(files)

    def test_stale_days_is_configurable(self):
        files = dict(VALID, **{
            "plans/checkout-v2/c1-refunds.md": fm(
                "plan", "active", "2026-08-01", epic="checkout-v2")})
        self.assertClean(files)                       # 9 days, under the default 21
        self.assertFails(files, "untouched for", config="stale_days = 3\n")


class TestTrackerFreshness(WorkspaceCase):
    """SPEC 7.3 - the check for failure F2, the reason trackers exist as a type."""

    def test_tracker_older_than_its_child_fails(self):
        # The regression case: a child moved and the summary above it did not.
        files = {
            "trackers/checkout-v2.md": fm(
                "tracker", "active", "2026-08-01", epic="checkout-v2"),
            "plans/checkout-v2/c0-payment-intents.md": fm(
                "plan", "active", TODAY, epic="checkout-v2"),
        }
        out = self.assertFails(files, "went stale when the child moved")
        self.assertIn("trackers/checkout-v2.md", out)

    def test_tracker_newer_than_its_child_passes(self):
        files = {
            "trackers/checkout-v2.md": fm("tracker", "active", TODAY, epic="checkout-v2"),
            "plans/checkout-v2/c0-payment-intents.md": fm(
                "plan", "paused", "2026-08-01", epic="checkout-v2"),
        }
        self.assertClean(files)

    def test_archived_child_does_not_hold_the_tracker_to_account(self):
        files = {
            "trackers/checkout-v2.md": fm(
                "tracker", "active", "2026-08-01", epic="checkout-v2"),
            "plans/archive/c0-payment-intents.md": fm(
                "plan", "done", TODAY, epic="checkout-v2"),
        }
        self.assertClean(files)

    def test_live_epic_with_no_tracker_is_reported(self):
        files = {"plans/checkout-v2/c0-payment-intents.md": fm(
            "plan", "active", TODAY, epic="checkout-v2")}
        self.assertFails(files, "no tracker in trackers/")


class TestArchiveCorrespondence(WorkspaceCase):
    """SPEC 7.4 and 5.2."""

    def test_done_outside_archive_fails(self):
        files = dict(VALID, **{
            "plans/checkout-v2/c1-refunds.md": fm(
                "plan", "done", TODAY, epic="checkout-v2")})
        self.assertFails(files, "not under an archive/ directory")

    def test_live_status_inside_archive_fails(self):
        files = dict(VALID, **{
            "plans/archive/c1-refunds.md": fm("plan", "active", TODAY)})
        self.assertFails(files, "lives in archive/ but has live status")

    def test_done_doc_outside_archive_passes(self):
        # 5.2: reference material is read, not worked, so archiving it only hides it.
        files = dict(VALID, **{"docs/how-billing-works.md": fm("doc", "done", TODAY)})
        self.assertClean(files)

    def test_abandoned_plan_in_archive_passes(self):
        files = dict(VALID, **{
            "plans/archive/legacy-cart.md": fm("plan", "abandoned", "2026-02-01")})
        self.assertClean(files)


class TestTriage(WorkspaceCase):
    """SPEC 7.5 and 5.3 - a migration cannot be quietly abandoned half-done."""

    def test_needs_triage_always_fails(self):
        files = dict(VALID, **{"plans/old-notes.md": fm("plan", "needs-triage", TODAY)})
        self.assertFails(files, "needs-triage")


class TestScopeField(WorkspaceCase):
    """SPEC 4.1 - `scope` with `repos` accepted as a deprecated alias."""

    def test_repos_alias_is_accepted(self):
        files = dict(VALID, **{
            "docs/how-billing-works.md": fm("doc", "done", TODAY, repos="[api]")})
        self.assertClean(files)


class TestIndexGeneration(WorkspaceCase):
    """SPEC 7.6."""

    def test_index_is_written_and_marked_generated(self):
        root = self.build(VALID)
        proc = subprocess.run(
            [sys.executable, os.path.join(root, "bin", "build-index.py"),
             "--today", TODAY],
            capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        with open(os.path.join(root, "INDEX.md"), encoding="utf-8") as fh:
            index = fh.read()
        self.assertIn("GENERATED", index)
        self.assertIn("do not hand-edit", index)
        self.assertIn("c0-payment-intents.md", index)
        self.assertIn("## active (2)", index)

    def test_index_is_excluded_from_its_own_validation(self):
        # INDEX.md has no frontmatter by design; it must not fail 4.3 against itself.
        root = self.build(VALID)
        subprocess.run([sys.executable, os.path.join(root, "bin", "build-index.py"),
                        "--today", TODAY], capture_output=True, text=True)
        code, out = self.run_check(root)
        self.assertEqual(code, 0, out)

    def test_archived_files_are_summarised_by_count(self):
        files = dict(VALID, **{
            "plans/archive/legacy-cart.md": fm("plan", "abandoned", "2026-02-01")})
        root = self.build(files)
        subprocess.run([sys.executable, os.path.join(root, "bin", "build-index.py"),
                        "--today", TODAY], capture_output=True, text=True)
        with open(os.path.join(root, "INDEX.md"), encoding="utf-8") as fh:
            index = fh.read()
        self.assertIn("## archive (1)", index)
        self.assertIn("`plans/archive/` - 1 files", index)
        # Summarised, not listed: the archive must not crowd out the live section.
        self.assertNotIn("[`legacy-cart.md`]", index)


class TestDirectoryNameAgnostic(WorkspaceCase):
    """SPEC 3.1 - the workspace directory may be named anything."""

    def test_root_is_derived_from_script_location(self):
        # The fixture root is a random temp name, nothing like `.workspace`. If the script
        # hardcoded a directory name this would not resolve at all.
        root = self.build(VALID)
        self.assertNotIn(".workspace", root)
        code, out = self.run_check(root)
        self.assertEqual(code, 0, out)


class TestShippedExamples(unittest.TestCase):
    """The examples in examples/ must validate under the rules they illustrate.

    Without this they rot silently: an example that fails --check teaches the wrong thing to
    everybody who copies it.
    """

    def check_example(self, name):
        src = os.path.join(REPO, "examples", name, ".workspace")
        self.assertTrue(os.path.isdir(src), f"missing example: {name}")
        root = tempfile.mkdtemp(prefix=f"aw-example-{name}-")
        self.addCleanup(shutil.rmtree, root, ignore_errors=True)
        dest = os.path.join(root, ".workspace")
        shutil.copytree(src, dest)
        os.makedirs(os.path.join(dest, "bin"), exist_ok=True)
        shutil.copy(SCRIPT, os.path.join(dest, "bin", "build-index.py"))
        proc = subprocess.run(
            [sys.executable, os.path.join(dest, "bin", "build-index.py"), "--check"],
            capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0,
                         f"example {name} does not validate:\n{proc.stdout}{proc.stderr}")
        return dest

    def test_multi_repo_example_validates(self):
        self.check_example("multi-repo")

    def test_monorepo_example_validates(self):
        self.check_example("monorepo")

    def test_multi_repo_example_demonstrates_the_tracker_check(self):
        # The README tells the reader to break it this way. If that stopped failing, the
        # example's headline lesson would be wrong.
        dest = self.check_example("multi-repo")
        tracker = os.path.join(dest, "trackers", "checkout-v2.md")
        with open(tracker, encoding="utf-8") as fh:
            text = fh.read()
        with open(tracker, "w", encoding="utf-8") as fh:
            fh.write(text.replace("updated: 2026-08-10", "updated: 2026-08-01", 1))
        proc = subprocess.run(
            [sys.executable, os.path.join(dest, "bin", "build-index.py"), "--check"],
            capture_output=True, text=True)
        self.assertEqual(proc.returncode, 1)
        self.assertIn("went stale when the child moved", proc.stdout + proc.stderr)


if __name__ == "__main__":
    unittest.main()
