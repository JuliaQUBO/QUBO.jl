import pathlib
import unittest

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]

# Minimum set of glob patterns the documentation label must cover.
# This is a contract floor — removing a pattern here is a deliberate
# decision to relax the labeler; adding one to labeler.yml without
# adding it here is allowed.
REQUIRED_DOC_PATTERNS = (
    "docs/**",
    "**/*.md",
    "**/*.rst",
    "README*",
    "CHANGELOG*",
    "NEWS*",
    "CITATION.cff",
    "LICENSE*",
    "papers/**",
    ".github/ISSUE_TEMPLATE/**",
    ".github/pull_request_template.md",
)


class LabelAutomationContractTests(unittest.TestCase):
    def read_text(self, relative_path: str) -> str:
        return (ROOT / relative_path).read_text(encoding="utf-8")

    def load_yaml(self, relative_path: str):
        return yaml.safe_load(self.read_text(relative_path))

    def test_documentation_labeler_uses_any_glob_to_all_files(self) -> None:
        labeler = self.load_yaml(".github/labeler.yml")

        self.assertIn("documentation", labeler)

        all_glob_patterns: list = []
        for rule in labeler["documentation"]:
            for entry in rule.get("changed-files", []):
                self.assertNotIn(
                    "all-globs-to-all-files",
                    entry,
                    "documentation label uses all-globs-to-all-files — this requires every "
                    "pattern to match every changed file, so a PR touching only docs/ would "
                    "never receive the label. Use any-glob-to-all-files instead.",
                )
                all_glob_patterns.extend(entry.get("any-glob-to-all-files", []))

        self.assertTrue(
            all_glob_patterns,
            "documentation label has no any-glob-to-all-files entries",
        )

        for pattern in REQUIRED_DOC_PATTERNS:
            self.assertIn(
                pattern,
                all_glob_patterns,
                f"Required pattern {pattern!r} is missing from the documentation label's "
                "any-glob-to-all-files list",
            )

    def test_sync_permissions_use_issues_only(self) -> None:
        header = self.read_text(".github/workflows/label-sync.yml").split("jobs:", 1)[0]

        self.assertIn("permissions:\n  contents: read\n  issues: write\n", header)
        self.assertNotIn("pull-requests:", header)

    def test_backfill_permissions_use_pull_request_read(self) -> None:
        header = self.read_text(".github/workflows/label-backfill.yml").split("jobs:", 1)[0]

        self.assertIn(
            "permissions:\n  contents: read\n  issues: write\n  pull-requests: read\n",
            header,
        )

    def test_pr_labeler_keeps_pull_request_write(self) -> None:
        header = self.read_text(".github/workflows/pr-labeler.yml").split("jobs:", 1)[0]

        self.assertIn(
            "permissions:\n  contents: read\n  pull-requests: write\n",
            header,
        )


if __name__ == "__main__":
    unittest.main()
