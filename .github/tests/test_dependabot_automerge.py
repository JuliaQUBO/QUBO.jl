"""Verify bot-only merge gates and idempotent post-merge publication."""

import copy
import importlib.util
import json
import pathlib
import subprocess
import unittest
from datetime import datetime, timezone
from unittest.mock import patch

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "dependabot_automerge", ROOT / "scripts" / "dependabot_automerge.py"
)
automation = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(automation)


def make_pull():
    """Return an eligible PR whose exact head has finished all mandatory lanes."""
    return {
        "number": 72, "user": {"login": "dependabot[bot]"}, "draft": False,
        "state": "open", "base": {"ref": "main"},
        "head": {"sha": "verified-head", "repo": {"full_name": automation.REPOSITORY}},
        "mergeable": True, "mergeable_state": "clean", "merged": False,
        "merged_at": None, "merge_commit_sha": None, "merged_by": None,
    }


def make_snapshot():
    """Provide successes for every mandatory lane without using live GitHub."""
    return {"headRefOid": "verified-head", "statusCheckRollup": [
        {"__typename": "CheckRun", "name": name, "status": "COMPLETED",
         "conclusion": "SUCCESS"}
        for name in automation.REQUIRED_CHECKS
    ]}


class FakeGitHub:
    """Record writes and expose deterministic current-head/reconciliation state."""

    def __init__(self):
        self.pull = make_pull()
        self.snapshot = make_snapshot()
        self.writes = []
        self.runs = {"doccleanup.yml": [], "docs.yml": []}
        self.reads = 0
        self.move_head_before_merge = False

    def api(self, path):
        assert path == "pulls/72", path
        self.reads += 1
        if self.move_head_before_merge and self.reads == 2:
            self.pull["head"]["sha"] = "new-head"
        return copy.deepcopy(self.pull)

    def pages(self, path, key=None):
        if path.startswith("actions/workflows/"):
            workflow = path.split("/")[2]
            return copy.deepcopy(self.runs[workflow])
        state = "open" if "state=open" in path else "closed"
        return [copy.deepcopy(self.pull)] if self.pull["state"] == state else []

    def checks(self, number):
        assert number == 72
        return copy.deepcopy(self.snapshot)

    def merge(self, pull):
        self.writes.append(("merge", pull["head"]["sha"]))
        self.pull.update(
            state="closed", merged=True, merged_at="2026-10-07T20:00:00Z",
            merge_commit_sha="merged-head", merged_by={"login": "github-actions[bot]"},
        )

    def dispatch(self, workflow, field, number):
        self.writes.append(("dispatch", workflow, field, number))
        title = ("Doc Preview Cleanup" if workflow == "doccleanup.yml"
                 else "Dependabot documentation")
        self.runs[workflow].append({
            "id": len(self.runs[workflow]) + 1, "display_title": f"{title} PR #{number}",
            "head_branch": "main", "created_at": "2026-10-07T20:01:00Z",
            "status": "queued", "conclusion": None,
        })


class MultiplePullsGitHub(FakeGitHub):
    """Expose an earlier failing PR and a later healthy PR in the same pass."""

    def __init__(self):
        super().__init__()
        self.pulls = {number: make_pull() for number in (90, 72)}
        for number, pull in self.pulls.items():
            pull["number"] = number
            pull["head"]["sha"] = f"head-{number}"
        self.fail_merge = set()

    def api(self, path):
        return copy.deepcopy(self.pulls[int(path.split("/")[-1])])

    def pages(self, path, key=None):
        if path.startswith("actions/"):
            return super().pages(path, key)
        state = "open" if "state=open" in path else "closed"
        return [copy.deepcopy(pull) for pull in self.pulls.values() if pull["state"] == state]

    def checks(self, number):
        snapshot = make_snapshot()
        snapshot["headRefOid"] = self.pulls[number]["head"]["sha"]
        return snapshot

    def merge(self, pull):
        number = pull["number"]
        if number in self.fail_merge:
            raise subprocess.CalledProcessError(1, ["gh", "pr", "merge", str(number)])
        self.writes.append(("merge", number))
        self.pulls[number].update(
            state="closed", merged=True, merged_at="2026-10-07T20:00:00Z",
            merge_commit_sha=f"merged-{number}", merged_by={"login": "github-actions[bot]"},
        )


class MergeGateTests(unittest.TestCase):
    def test_green_bot_merges_exact_head(self):
        github = FakeGitHub()
        automation.merge_green_pulls(github)
        self.assertEqual(github.writes, [("merge", "verified-head")])
        self.assertTrue(github.pull["merged"])
        self.assertEqual(github.reads, 3)  # Identity, fresh precondition, readback.

    def test_humans_forks_other_bases_and_drafts_never_merge(self):
        for variant in ("human", "fork", "other-base", "draft"):
            with self.subTest(variant=variant):
                github = FakeGitHub()
                if variant == "human":
                    github.pull["user"]["login"] = "maintainer"
                elif variant == "fork":
                    github.pull["head"]["repo"]["full_name"] = "fork/QUBO.jl"
                elif variant == "other-base":
                    github.pull["base"]["ref"] = "release"
                else:
                    github.pull["draft"] = True
                automation.merge_green_pulls(github)
                self.assertEqual(github.writes, [])

    def test_missing_failed_pending_and_skipped_required_checks_block(self):
        for variant in ("missing", "failure", "pending", "skipped"):
            with self.subTest(variant=variant):
                github = FakeGitHub()
                checks = github.snapshot["statusCheckRollup"]
                if variant == "missing":
                    checks.pop()
                elif variant == "failure":
                    checks[0]["conclusion"] = "FAILURE"
                elif variant == "pending":
                    checks[0]["status"] = "IN_PROGRESS"
                else:
                    checks[0]["conclusion"] = "SKIPPED"
                automation.merge_green_pulls(github)
                self.assertEqual(github.writes, [])

    def test_red_or_pending_extra_checks_block(self):
        for check in (
            {"__typename": "StatusContext", "state": "ERROR"},
            {"__typename": "StatusContext", "state": "PENDING"},
            {"__typename": "CheckRun", "name": "Canary", "status": "COMPLETED",
             "conclusion": "FAILURE"},
        ):
            with self.subTest(check=check):
                github = FakeGitHub()
                github.snapshot["statusCheckRollup"].append(check)
                automation.merge_green_pulls(github)
                self.assertEqual(github.writes, [])

    def test_changed_head_and_stale_check_snapshot_block(self):
        for variant in ("moved-head", "stale-checks"):
            with self.subTest(variant=variant):
                github = FakeGitHub()
                if variant == "moved-head":
                    github.move_head_before_merge = True
                else:
                    github.snapshot["headRefOid"] = "old-head"
                automation.merge_green_pulls(github)
                self.assertEqual(github.writes, [])

    def test_blocked_and_unknown_mergeability_block(self):
        for state in ("blocked", "behind", "unknown"):
            with self.subTest(state=state):
                github = FakeGitHub()
                github.pull["mergeable_state"] = state
                automation.merge_green_pulls(github)
                self.assertEqual(github.writes, [])

    def test_cli_merge_pins_head_without_admin_or_deferred_merge(self):
        with patch.object(automation.subprocess, "check_output", return_value="") as run:
            automation.GitHub().merge(make_pull())
        self.assertEqual(run.call_args.args[0], [
            "gh", "pr", "merge", "72", "--repo", automation.REPOSITORY,
            "--squash", "--match-head-commit", "verified-head",
        ])


class PublicationTests(unittest.TestCase):
    now = datetime(2026, 10, 7, 21, tzinfo=timezone.utc)

    def merged_github(self):
        github = FakeGitHub()
        github.merge(github.pull)
        github.writes.clear()
        return github

    def test_cleanup_precedes_docs_and_events_do_not_duplicate_dispatches(self):
        github = self.merged_github()
        automation.reconcile_publication(github, self.now)
        self.assertEqual(github.writes, [("dispatch", "doccleanup.yml", "pr_number", 72)])
        automation.reconcile_publication(github, self.now)
        self.assertEqual(len(github.writes), 1)
        github.runs["doccleanup.yml"][0].update(status="completed", conclusion="success")
        automation.reconcile_publication(github, self.now)
        self.assertEqual(github.writes[-1], ("dispatch", "docs.yml", "dependabot_pr", 72))
        automation.reconcile_publication(github, self.now)
        self.assertEqual(len(github.writes), 2)
        github.runs["docs.yml"][0].update(status="completed", conclusion="success")
        automation.reconcile_publication(github, self.now)
        self.assertEqual(len(github.writes), 2)

    def test_failed_cleanup_stops_docs_and_is_not_repeated(self):
        github = self.merged_github()
        automation.reconcile_publication(github, self.now)
        github.runs["doccleanup.yml"][0].update(status="completed", conclusion="failure")
        errors = automation.reconcile_publication(github, self.now)
        self.assertEqual(len(errors), 1)
        self.assertIn("failed; inspect and rerun", errors[0])
        self.assertEqual(len(github.writes), 1)

    def test_failed_merge_does_not_starve_other_merges_or_publication(self):
        github = MultiplePullsGitHub()
        github.fail_merge.add(90)
        with patch.object(automation, "datetime", wraps=datetime) as clock:
            clock.now.return_value = self.now
            with self.assertRaisesRegex(RuntimeError, "PR #90 merge"):
                automation.main(github)
        self.assertEqual(github.writes, [
            ("merge", 72), ("dispatch", "doccleanup.yml", "pr_number", 72),
        ])

    def test_failed_publication_does_not_starve_other_pr_publication(self):
        github = MultiplePullsGitHub()
        for pull in list(github.pulls.values()):
            github.merge(pull)
        github.dispatch("doccleanup.yml", "pr_number", 90)
        github.runs["doccleanup.yml"][0].update(status="completed", conclusion="failure")
        github.writes.clear()
        errors = automation.reconcile_publication(github, self.now)
        self.assertEqual(len(errors), 1)
        self.assertIn("PR #90 publication", errors[0])
        self.assertEqual(github.writes, [("dispatch", "doccleanup.yml", "pr_number", 72)])
        github.runs["doccleanup.yml"][1].update(status="completed", conclusion="success")
        errors = automation.reconcile_publication(github, self.now)
        self.assertEqual(len(errors), 1)
        self.assertEqual(github.writes[-1], ("dispatch", "docs.yml", "dependabot_pr", 72))

    def test_failed_merge_list_read_still_reconciles_and_reports_failure(self):
        github = self.merged_github()
        with patch.object(automation, "merge_green_pulls", side_effect=RuntimeError("API unavailable")):
            with patch.object(automation, "datetime", wraps=datetime) as clock:
                clock.now.return_value = self.now
                with self.assertRaisesRegex(RuntimeError, "API unavailable"):
                    automation.main(github)
        self.assertEqual(github.writes, [("dispatch", "doccleanup.yml", "pr_number", 72)])

    def test_only_recent_action_bot_merges_are_reconciled(self):
        for variant in ("human-merge", "old-merge", "closed-unmerged"):
            with self.subTest(variant=variant):
                github = self.merged_github()
                if variant == "human-merge":
                    github.pull["merged_by"]["login"] = "maintainer"
                elif variant == "old-merge":
                    github.pull["merged_at"] = "2026-09-01T20:00:00Z"
                else:
                    github.pull.update(merged=False, merged_at=None)
                automation.reconcile_publication(github, self.now)
                self.assertEqual(github.writes, [])

    def test_old_dispatch_does_not_satisfy_current_merge(self):
        github = self.merged_github()
        github.dispatch("doccleanup.yml", "pr_number", 72)
        github.runs["doccleanup.yml"][0].update(
            created_at="2026-10-01T00:00:00Z", status="completed", conclusion="success"
        )
        github.writes.clear()
        automation.reconcile_publication(github, self.now)
        self.assertEqual(github.writes, [("dispatch", "doccleanup.yml", "pr_number", 72)])

    def test_paginated_cli_reads_are_complete(self):
        pages = [{"workflow_runs": [{"id": 1}]}, {"workflow_runs": [{"id": 2}]}]
        with patch.object(automation.subprocess, "check_output", return_value=json.dumps(pages)):
            self.assertEqual(automation.GitHub().pages("runs", "workflow_runs"),
                             [{"id": 1}, {"id": 2}])


class WorkflowTests(unittest.TestCase):
    def workflow(self, name):
        return yaml.load((ROOT / ".github/workflows" / name).read_text(), Loader=yaml.BaseLoader)

    def test_privileged_automation_only_executes_trusted_main(self):
        workflow = self.workflow("dependabot-automerge.yml")
        self.assertEqual(set(workflow["on"]), {"workflow_run", "schedule", "workflow_dispatch"})
        checkout = workflow["jobs"]["merge"]["steps"][0]
        self.assertEqual(checkout["with"], {"ref": "main", "persist-credentials": "false"})
        self.assertEqual(workflow["permissions"], {
            "contents": "write", "pull-requests": "write", "actions": "write",
        })

    def test_dispatches_keep_documentation_queue_and_publication_restrictions(self):
        docs = self.workflow("docs.yml")
        cleanup = self.workflow("doccleanup.yml")
        self.assertEqual(docs["concurrency"], cleanup["concurrency"])
        self.assertEqual(docs["concurrency"]["queue"], "max")
        self.assertIn("dependabot_pr", docs["on"]["workflow_dispatch"]["inputs"])
        self.assertIn("pr_number", cleanup["on"]["workflow_dispatch"]["inputs"])
        verify = cleanup["jobs"]["doc-preview-cleanup"]["steps"][0]["run"]
        self.assertIn('test "$pr_state" = closed', verify)
        steps = docs["jobs"]["build-docs"]["steps"]
        self.assertTrue(any("dependabot[bot]" in step.get("if", "")
                            and "--skip-deploy" in step.get("run", "") for step in steps))
        self.assertIn("--skip-deploy", steps[-1]["run"])


if __name__ == "__main__":
    unittest.main()
