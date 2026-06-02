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
