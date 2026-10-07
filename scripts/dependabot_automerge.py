"""Merge green Dependabot PRs and dispatch the workflows token merges suppress."""

import json
import subprocess
import time
from datetime import datetime, timedelta, timezone

REPOSITORY = "JuliaQUBO/QUBO.jl"
REQUIRED_CHECKS = {
    "Julia 1.10 - ubuntu-latest - x64 - pull_request",
    "Julia 1 - ubuntu-latest - x64 - pull_request",
    "Julia 1 - windows-latest - x64 - pull_request",
    "build-docs",
}


class GitHub:
    """Use GitHub CLI argument lists rather than executing PR text in a shell."""

    def command(self, *arguments):
        """Execute one CLI operation and propagate authentication/API failures."""
        return subprocess.check_output(["gh", *arguments], text=True)

    def api(self, path):
        """Read one repository-scoped API object."""
        return json.loads(self.command("api", f"repos/{REPOSITORY}/{path}"))

    def pages(self, path, key=None):
        """Read a complete paginated list, including wrapped workflow runs."""
        pages = json.loads(self.command(
            "api", f"repos/{REPOSITORY}/{path}", "--paginate", "--slurp"
        ))
        return [item for page in pages for item in (page[key] if key else page)]

    def checks(self, number):
        """Return checks together with the SHA they actually describe."""
        return json.loads(self.command(
            "pr", "view", str(number), "--repo", REPOSITORY,
            "--json", "headRefOid,statusCheckRollup"
        ))

    def merge(self, pull):
        """Merge the verified head without enabling a deferred or admin bypass."""
        self.command(
            "pr", "merge", str(pull["number"]), "--repo", REPOSITORY,
            "--squash", "--match-head-commit", pull["head"]["sha"]
        )

    def dispatch(self, workflow, field, number):
        """Dispatch a trusted-main workflow and attach a reconciliation marker."""
        self.command(
            "workflow", "run", workflow, "--repo", REPOSITORY, "--ref", "main",
            "--raw-field", f"{field}={number}"
        )


def dependabot_pull(pull):
    """Limit automatic writes to real, same-repository Dependabot PRs to main."""
    return (
        pull["user"]["login"] == "dependabot[bot]"
        and pull["base"]["ref"] == "main"
        and (pull["head"].get("repo") or {}).get("full_name") == REPOSITORY
    )


def green_checks(snapshot, head):
    """Require every expected lane and reject failed or unfinished extra checks."""
    if snapshot["headRefOid"] != head:
        return False
    successful = set()
    for check in snapshot["statusCheckRollup"]:
        if check["__typename"] == "CheckRun":
            if (check["status"] != "COMPLETED"
                    or check["conclusion"] not in {"SUCCESS", "NEUTRAL", "SKIPPED"}):
                return False
            if check["conclusion"] == "SUCCESS":
                successful.add(check["name"])
        elif check["__typename"] == "StatusContext":
            if check["state"] != "SUCCESS":
                return False
        else:
            return False
    return REQUIRED_CHECKS <= successful


def merge_green_pulls(github):
    """Re-read live identity, SHA and merge gates immediately before merging."""
    for candidate in github.pages("pulls?state=open&base=main&per_page=100"):
        if not dependabot_pull(candidate) or candidate["draft"]:
            continue
        number = candidate["number"]
        pull = github.api(f"pulls/{number}")
        if pull["state"] != "open" or pull["draft"] or not dependabot_pull(pull):
            continue
        head = pull["head"]["sha"]
        if not green_checks(github.checks(number), head):
            print(f"PR #{number}: waiting for successful current-head checks")
            continue
        fresh = github.api(f"pulls/{number}")
        if (fresh["state"] != "open" or fresh["draft"]
                or not dependabot_pull(fresh) or fresh["head"]["sha"] != head
                or fresh.get("mergeable") is not True
                or fresh.get("mergeable_state") != "clean"):
            print(f"PR #{number}: head changed or merge gates are not satisfied")
            continue
        github.merge(fresh)
        merged = github.api(f"pulls/{number}")
        if not merged["merged"]:
            raise RuntimeError(f"PR #{number}: merge was not confirmed")
        print(f"PR #{number}: merged {head}")


def dispatched_run(github, pull, workflow, title):
    """Find an existing dispatch for this PR made after its merge."""
    runs = github.pages(
        f"actions/workflows/{workflow}/runs?event=workflow_dispatch&per_page=100",
        key="workflow_runs",
    )
    matches = [run for run in runs if run["display_title"] == title
               and run["head_branch"] == "main"
               and run["created_at"] >= pull["merged_at"]]
    return max(matches, key=lambda run: run["id"]) if matches else None


def ensure_dispatch(github, pull, workflow, field, title, sleep=time.sleep):
    """Dispatch once, verify acceptance, and never hide a failed publication."""
    run = dispatched_run(github, pull, workflow, title)
    if run is None:
        # Refresh the exact closed PR before an externally visible dispatch.
        fresh = github.api(f"pulls/{pull['number']}")
        if not fresh["merged"] or fresh["merge_commit_sha"] != pull["merge_commit_sha"]:
            raise RuntimeError("Merged PR changed before publication dispatch")
        github.dispatch(workflow, field, pull["number"])
        for _ in range(6):
            run = dispatched_run(github, pull, workflow, title)
            if run is not None:
                break
            sleep(2)
        if run is None:
            raise RuntimeError(f"{workflow}: dispatch acceptance is unverified")
    if run["status"] != "completed":
        return False
    if run["conclusion"] != "success":
        raise RuntimeError(
            f"{workflow} run {run['id']} failed; inspect and rerun it manually"
        )
    return True


def reconcile_publication(github, now=None):
    """Recover token-merged PR publication for seven days without duplicate runs."""
    now = now or datetime.now(timezone.utc)
    cutoff = (now - timedelta(days=7)).isoformat(timespec="seconds").replace("+00:00", "Z")
    closed = github.pages(
        "pulls?state=closed&base=main&sort=updated&direction=desc&per_page=100"
    )
    for candidate in closed:
        if (not dependabot_pull(candidate) or not candidate["merged_at"]
                or candidate["merged_at"] < cutoff):
            continue
        pull = github.api(f"pulls/{candidate['number']}")
        if (not pull["merged"]
                or (pull.get("merged_by") or {}).get("login") != "github-actions[bot]"):
            continue
        number = pull["number"]
        if ensure_dispatch(
            github, pull, "doccleanup.yml", "pr_number",
            f"Doc Preview Cleanup PR #{number}",
        ):
            ensure_dispatch(
                github, pull, "docs.yml", "dependabot_pr",
                f"Dependabot documentation PR #{number}",
            )


def main():
    """Handle completion events, scheduled reconciliation and manual invocations."""
    github = GitHub()
    merge_green_pulls(github)
    reconcile_publication(github)


if __name__ == "__main__":
    main()
