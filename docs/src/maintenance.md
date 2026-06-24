# Dependency Maintenance

QUBO.jl package repositories should use GitHub Dependabot for routine
dependency compatibility maintenance when the repository depends only on the
public Julia General registry.

Do not add new CompatHelper workflows by default. CompatHelper remains useful
for repositories that need custom or private registries, but CompatHelper is in
maintenance mode and its own project recommends migrating to Dependabot for
Julia packages.

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
package release. The release preflight belongs in the package repository, for
example `scripts/release_check.jl`, and should catch release-sensitive metadata
that normal unit tests can miss:

- root, docs, and test `Project.toml` version and compatibility drift;
- release-note sections needed by General registry AutoMerge, especially
  `Breaking changes` and `Changelog` wording for pre-1.0 minor releases;
- TagBot, Registrator, General pull request, and fresh `Pkg.add` verification
  checklist items.

Use the QUBO.jl ecosystem canary after release work reaches the registry, or
whenever a coordinated release wave changes cross-package compatibility. The
canary composes the latest registered package versions in fresh environments
and prints the registered compatibility matrix on every run, then again on
resolution failure. It is the
post-release coordination check: it verifies that the ecosystem still installs
and imports together, but it is not a substitute for package-local preflight
before Registrator is triggered.

When a release wave changes shared bounds such as `QUBODrivers` or
`QUBOTools`, check the canary or run `scripts/compat_matrix.jl` from this
repository after the package registrations land. Track any stale downstream
bounds in the downstream package repository rather than weakening the canary.

The QUBO.jl v0.6.2 compatibility refresh follows the registered stack with
`ToQUBO` v0.5.1, `QUBOTools` v0.15.1, `QUBODrivers` v0.6.4, and
`PseudoBooleanOptimization` v0.3.0. Keep executable documentation examples on
`QUBODrivers.ExactSampler` or another dependency that supports `QUBOTools`
0.15. While `PySA` v0.4.1 still caps `QUBOTools` at 0.14, PySA examples should
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
