# Maintenance Policy

QUBO.jl package repositories should use GitHub Dependabot for routine
dependency compatibility maintenance when the repository depends only on the
public Julia General registry.

Do not add new CompatHelper workflows by default. CompatHelper remains useful
for repositories that need custom or private registries, but CompatHelper is in
maintenance mode and its own project recommends migrating to Dependabot for
Julia packages.

## Standard Package CI

Active JuliaQUBO package repositories should keep a small, stable CI baseline
that every pull request can run without private credentials or external
hardware:

- a package CI workflow named `CI`;
- Julia `1` and the minimum supported Julia line on `ubuntu-latest`;
- `windows-latest` jobs when the package supports Windows or already requires
  Windows as part of normal correctness checks;
- dependency caching through the standard Julia GitHub Actions cache support;
- documentation builds in a separate workflow when the repository has docs;
- workflow and job names that stay stable unless branch protection is updated
  in the same maintenance pass.

Repository-specific checks may be part of the package baseline when they are
deterministic, fast enough for routine PR review, and validate package
correctness for all contributors. For example, a workflow syntax or workflow
test job can be required when it guards the repository's normal CI contract.

Do not make a workflow a required merge gate only because it is useful. A check
should be required only when all of these are true:

- it runs on ordinary pull requests without secrets, hardware, or service
  credentials;
- it is deterministic enough that a failure usually means the PR needs action;
- it validates package correctness or repository infrastructure needed for
  package correctness;
- its check name is stable enough to maintain in branch protection.

Useful checks that do not meet those criteria should stay optional and visible.

## Standard Workflow

Each active package repository should keep a `.github/dependabot.yml` file with
these update entries:

- `julia` for the root package project, scheduled weekly.
- Extra `julia` entries for subdirectory environments that keep their own
  compatibility bounds, scheduled weekly.
- `github-actions` for workflow action pins, scheduled monthly.

Group Julia dependency updates by environment so routine compatibility bumps
arrive in a small number of pull requests instead of one pull request per
dependency.

The Julia update should target the repository root unless the package lives in
a subdirectory. Repositories with extra Julia environments, such as `docs/` or
`test/`, should add additional `julia` entries after the root package entry
when their compatibility bounds are maintained separately. The QUBO.jl
reference configuration includes `docs/` because it has its own `[compat]`
bounds, and omits `test/` because `test/Project.toml` has no `[compat]`.

The standard QUBO.jl entrypoint configuration is:

```yaml
version: 2
updates:
  - package-ecosystem: "julia"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      root-julia-dependencies:
        patterns:
          - "*"

  - package-ecosystem: "julia"
    directory: "/docs"
    schedule:
      interval: "weekly"
    groups:
      docs-julia-dependencies:
        patterns:
          - "*"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "monthly"
```

## Branch Protection

Protect `main` on active package repositories with review and strict required
status checks. Required checks should match the current check names emitted by
the repository's package CI workflow.

Keep these checks out of branch protection unless the team intentionally
records a repository-specific exception:

- documentation deployment and preview cleanup;
- hardware or API smoke tests;
- scheduled dependency drift checks;
- benchmarks and scale tests;
- ecosystem canaries;
- optional solver or service integrations.

Documentation builds may run on every pull request and should be fixed when
they fail, but deployment statuses and preview cleanup jobs are operational
signals rather than package-correctness gates. Hardware, API, benchmark,
scheduled, and ecosystem checks are valuable diagnostics, but they can fail
because of external service availability, credentials, runtime variance, or
temporary cross-package release ordering.

When a workflow job is renamed, first merge the workflow change with the old
required contexts still valid where possible, then update branch protection to
the new check names after the new checks have passed on `main`. If that is not
possible, document the stale required contexts and update only the affected
branch-protection entries.

## Scope Exceptions

The first-pass package CI baseline applies to active JuliaQUBO packages. These
repositories and workflows are intentional exceptions:

- `QUBONotebooks` is notebook and tutorial infrastructure. It should keep
  notebook-specific verification instead of inheriting the package CI baseline.
- `QUBOBenchmarks.jl` and `ToQUBO-benchmark` are benchmark-oriented. Their
  performance and long-running checks are useful for regression analysis, but
  should not become ordinary package merge gates.
- Archived repositories should not receive routine CI or Dependabot churn
  unless they are unarchived and returned to active maintenance.
- Hardware and API smoke jobs should stay optional unless a repository
  explicitly decides that external-service availability must block merges.
- Scheduled dependency drift jobs are monitoring tools. Convert actionable
  drift into a normal issue or PR before treating it as merge-blocking work.
- Package-specific ecosystem canaries, scale tests, and benchmarks should
  remain diagnostics unless the repository explicitly records why the check is
  deterministic, cheap enough, and required for package correctness.

## Drift Handling

Handle future CI and Dependabot drift with a small repository-local PR unless
the change needs ecosystem coordination.

1. Let Dependabot open the routine PR and require the normal package CI to pass.
2. If a Dependabot PR exposes stale compatibility bounds, open the follow-up in
   the package that owns those bounds instead of weakening downstream checks.
3. After merging workflow or Dependabot changes, verify the post-merge `main`
   CI before closing the issue or updating a tracker.
4. If a workflow rename changes check names, compare branch protection with the
   latest successful checks and update only stale required contexts.
5. Record deliberate exceptions in the issue or PR so later cleanup does not
   reinterpret them as accidental drift.

Infrastructure-only changes do not require Julia package releases. Release a
new package version only when package code, public behavior, compatibility
bounds, or registered metadata changes require users to receive a new version
through the registry.

## Permissions And Secrets

Dependabot does not require a repository secret for public GitHub repositories
that use the public Julia General registry. Pull requests opened by Dependabot
should run the normal CI and documentation checks before merging.

Repositories that need custom or private registries should not migrate from
CompatHelper yet. For those repositories, keep or add a CompatHelper workflow
with explicit `contents: write` and `pull-requests: write` permissions and a
dedicated secret such as `COMPATHELPER_PRIV` when the workflow must push
branches that trigger CI.

## Release Guardrails

Use package-local release checks before tagging or registering an individual
package release. The release preflight belongs in that package's repository;
see the
[`ToQUBO.jl` preflight](https://github.com/JuliaQUBO/ToQUBO.jl/blob/main/scripts/release_check.jl)
and
[`QUBOTools.jl` preflight](https://github.com/JuliaQUBO/QUBOTools.jl/blob/main/scripts/release_check.jl)
for concrete examples. These checks should catch release-sensitive metadata
that normal unit tests can miss:

- root, docs, and test `Project.toml` version and compatibility drift;
- release-note sections needed by General registry AutoMerge, especially
  `Breaking changes` and `Changelog` wording for pre-1.0 minor releases;
- TagBot, Registrator, General pull request, and fresh `Pkg.add` verification
  checklist items.

QUBO.jl does not keep a separate `scripts/release_check.jl`. Its
package-specific version and compatibility invariants run with the normal test
suite in `test/package_metadata.jl`; the compatibility matrix and ecosystem
canary below provide the post-release coordination layer.

Use the QUBO.jl ecosystem canary after release work reaches the registry, or
whenever a coordinated release wave changes cross-package compatibility. The
canary composes the latest registered package versions in fresh environments
and prints the registered compatibility matrix on every run, then again on
resolution failure. It also verifies that the resolved
`PseudoBooleanOptimization`, `QUBOTools`, `ToQUBO`, and `QUBODrivers` versions
are the latest stable, unyanked registered releases compatible with the Julia
version running the canary, so stale downstream bounds are caught even when the
resolver can still find an older compatible solution. The core freshness gate
is intentionally global: custom runs should include the core packages in the
package list, because a missing core package is treated as stale. It is the
post-release coordination check: it verifies that the ecosystem still installs
and imports together, but it is not a substitute for package-local preflight
before Registrator is triggered.

When a release wave changes shared bounds such as `QUBODrivers` or
`QUBOTools`, check the canary or run `scripts/compat_matrix.jl` from this
repository after the package registrations land. Track any stale downstream
bounds in the downstream package repository rather than weakening the canary.

The QUBO.jl v0.6.2 compatibility refresh follows the registered stack with
`ToQUBO` v0.6.0, `QUBOTools` v0.16.0, `QUBODrivers` v0.6.5, and
`PseudoBooleanOptimization` v0.3.0. Keep executable documentation examples on
`QUBODrivers.ExactSampler` or another dependency that supports `QUBOTools`
0.16. While `PySA` v0.4.1 still caps `QUBOTools` at 0.14, PySA examples should
remain plain `julia` snippets rather than Documenter `@example` blocks.

## Rollout Order

Apply the policy to package repositories before solver or adapter repositories
so the shared compiler and tooling layers stabilize first:

1. `QUBOTools.jl`
2. `QUBODrivers.jl`
3. `ToQUBO.jl`
4. `QUBOLib.jl`
5. `PseudoBooleanOptimization.jl`
6. `QuantumAnnealingInterface.jl`
7. `DWave.jl`
8. `MQLib.jl`
9. `CIMOptimizer.jl`
10. `PySA.jl`
11. `QiskitOpt.jl`

For each package-level issue, update the issue with the Dependabot decision,
whether a repository-specific exception applies, and the pull request that adds
or confirms the repository's `.github/dependabot.yml`.
