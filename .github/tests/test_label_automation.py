import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
DOC_PATTERNS = (
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

    def test_documentation_labeler_uses_any_glob_to_all_files(self) -> None:
        contents = self.read_text(".github/labeler.yml")

        self.assertIn("any-glob-to-all-files:", contents)
        self.assertNotIn("all-globs-to-all-files:", contents)

        for pattern in DOC_PATTERNS:
            self.assertIn(f'          - "{pattern}"', contents)

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
