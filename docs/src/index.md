# QUBO.jl Documentation

`QUBO.jl` is the ecosystem entrypoint for building, solving, and inspecting
Quadratic Unconstrained Binary Optimization models in [JuMP](https://jump.dev).
It combines three complementary packages:

- [`ToQUBO.jl`](https://github.com/JuliaQUBO/ToQUBO.jl) to reformulate
  constrained JuMP models into QUBO form
- [`QUBODrivers.jl`](https://github.com/JuliaQUBO/QUBODrivers.jl) to connect
  samplers and annealers through an `MOI`-compatible API
- [`QUBOTools.jl`](https://github.com/JuliaQUBO/QUBOTools.jl) to inspect,
  convert, and manipulate compiled QUBO instances

The ecosystem also includes the standalone
[`QUBODecomposition.jl`](https://github.com/JuliaQUBO/QUBODecomposition.jl)
composite optimizer, maintained by [@bernalde](https://github.com/bernalde).
It uses public QUBODrivers interfaces for fitting whole models, disconnected
components and conditioned serial sweeps with explicit logical-variable budgets.
Complete states are reconstructed and scored against the original model; coupled
sweeps are heuristic, with conservative public statuses and cooperative limits.
Direct JuMP and released ToQUBO 0.7.1 integration are covered by its
[acceptance evidence](https://juliaqubo.github.io/QUBODecomposition.jl/stable/acceptance/).

QUBODecomposition is registered in General and released, with verified
fresh installation and stable documentation. Install it separately:

```julia
import Pkg
Pkg.add("QUBODecomposition")
using QUBODecomposition
```

Follow its [installation manual](https://juliaqubo.github.io/QUBODecomposition.jl/stable/start/)
for usage and deliberate development checkouts. Ecosystem membership does not
add it to QUBO's bundled dependencies: `Pkg.add("QUBO")` and `using QUBO` do
not install or re-export it.

The standalone [QUBOPreprocessing.jl](https://github.com/JuliaQUBO/QUBOPreprocessing.jl)
package provides certified strict-dominance reductions, independently verifiable
proofs, original-state reconstruction and reusable branch workspaces. Install it
separately with `Pkg.add("QUBOPreprocessing")`; QUBO does not bundle or re-export it.
Without caller assumptions, a globally solved certified residual reconstructs an
original global optimum. Caller assumptions restrict that guarantee to their
scope, and preprocessing does not upgrade a heuristic solver or certify ToQUBO
source feasibility under inadequate penalties. Numerical energies retain Float64
limitations even when stored-value reduction proofs are exact.

Use its [manual](https://juliaqubo.github.io/QUBOPreprocessing.jl/stable/) for the
API and examples, and its [measured operating envelope](https://juliaqubo.github.io/QUBOPreprocessing.jl/stable/performance/)
for complete costs and no-benefit cases. QUBODecomposition **0.1.5 or later**
provides an [opt-in root adapter](https://juliaqubo.github.io/QUBODecomposition.jl/stable/preprocessing/)
using this package. It remains off by default; follow the guide for supported
routes and budgets.

## QUBO in Brief

A QUBO model has a binary decision vector, a linear-or-quadratic objective, and
no explicit constraints:

```math
\begin{array}{rl}
   \min          & \mathbf{x}' Q\,\mathbf{x} \\
   \textrm{s.t.} & \mathbf{x} \in \mathbb{B}^{n}
\end{array}
```

This form is useful because many annealing, sampling, and Ising-style solvers
operate most naturally on binary quadratic models.

## Quick Start

### Installation

```julia
julia> import Pkg

julia> Pkg.add("QUBO")
```

### Example

```julia
using JuMP
using QUBO

model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

@variable(model, x[1:3], Bin)
@constraint(model, 0.3 * x[1] + 0.5 * x[2] + x[3] <= 1.6)
@objective(model, Max, x[1] + 2 * x[2] + 3 * x[3])

optimize!(model)

value.(x)
objective_value(model)
```

## End-to-End Examples

The application examples live here in `QUBO.jl`, where they can show the full
workflow across the compiler, solver, and tooling layers:

- [Knapsack](@ref)
- [Prime Factorization](@ref)
- [Portfolio Optimization](@ref)

## Analysis & Visualization

After solving, use QUBOTools plotting recipes to inspect the compiled QUBO
matrix, interaction graph, and solution energy landscape.
See [Analysis & Visualization](@ref analysis-visualization) for details.

## Constraint Penalty Hints

To set a custom penalty for a constraint, create the constraint first and then
set `ToQUBO.Attributes.ConstraintEncodingPenaltyHint()` on the returned
constraint reference before `optimize!`.
There is no combined `@constraint` syntax for this in JuMP, so the usual
pattern is to define the constraint and immediately attach the hint.

```julia
using JuMP
using QUBO

model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

@variable(model, x[1:3], Bin)

c = @constraint(model, x[1] + x[2] + x[3] <= 2)
set_attribute(c, ToQUBO.Attributes.ConstraintEncodingPenaltyHint(), 20.0)

@objective(model, Max, x[1] + 2 * x[2] + 3 * x[3])

optimize!(model)

rho = get_attribute(c, ToQUBO.Attributes.ConstraintEncodingPenalty())
```

For many constraints, broadcast `set_attribute` across the constraint
container. This lets you assign either the same penalty to all constraints or a
different penalty to each one.

```julia
c = @constraint(model, [i in 1:3], x[i] <= 1)

set_attribute.(c, Ref(ToQUBO.Attributes.ConstraintEncodingPenaltyHint()), 5.0)

rho = [5.0, 10.0, 20.0]
set_attribute.(c, Ref(ToQUBO.Attributes.ConstraintEncodingPenaltyHint()), rho)
```

## Ecosystem Packages

```@raw html
<div class="qubo-package-grid">
    <div class="qubo-package-card">
        <h3>ToQUBO.jl</h3>
        <a href="https://juliaqubo.github.io/QUBO.jl/ToQUBO.jl/dev/">
            <img src="assets/logo-toqubo.svg" alt="ToQUBO.jl logo" />
        </a>
        <p>Compile constrained JuMP models into QUBO form, including variable
        encodings, constraint penalties, and reformulation settings.</p>
        <div class="qubo-package-links">
            <a href="https://juliaqubo.github.io/QUBO.jl/ToQUBO.jl/dev/">Docs</a>
            <a href="https://github.com/JuliaQUBO/ToQUBO.jl">Repository</a>
        </div>
    </div>
    <div class="qubo-package-card">
        <h3>QUBODrivers.jl</h3>
        <a href="https://juliaqubo.github.io/QUBO.jl/QUBODrivers.jl/dev/">
            <img src="assets/logo-qubodrivers.svg" alt="QUBODrivers.jl logo" />
        </a>
        <p>Expose samplers and annealers through a consistent <code>MOI</code>-compatible
        interface that can be used directly from JuMP and <code>QUBO.jl</code>.</p>
        <div class="qubo-package-links">
            <a href="https://juliaqubo.github.io/QUBO.jl/QUBODrivers.jl/dev/">Docs</a>
            <a href="https://github.com/JuliaQUBO/QUBODrivers.jl">Repository</a>
        </div>
    </div>
    <div class="qubo-package-card">
        <h3>QUBOTools.jl</h3>
        <a href="https://juliaqubo.github.io/QUBO.jl/QUBOTools.jl/dev/">
            <img src="assets/logo-qubotools.svg" alt="QUBOTools.jl logo" />
        </a>
        <p>Inspect compiled QUBO instances, convert between representations, and
        work with reusable model and result abstractions.</p>
        <div class="qubo-package-links">
            <a href="https://juliaqubo.github.io/QUBO.jl/QUBOTools.jl/dev/">Docs</a>
            <a href="https://github.com/JuliaQUBO/QUBOTools.jl">Repository</a>
        </div>
    </div>
    <div class="qubo-package-card">
        <h3>QUBODecomposition.jl</h3>
        <p>Compose QUBODrivers children through whole-model calls, independent
        components and budgeted conditioned sweeps. Reconstruct full states and
        evaluate original energies; coupled sweeps remain heuristic.</p>
        <div class="qubo-package-links">
            <a href="https://juliaqubo.github.io/QUBO.jl/QUBODecomposition.jl/stable/">Docs</a>
            <a href="https://github.com/JuliaQUBO/QUBODecomposition.jl">Repository</a>
        </div>
    </div>
</div>
```

## Citing QUBO.jl
<!-- citation-policy:start -->
For general use of `QUBO.jl` and the broader `JuliaQUBO` ecosystem, cite the
[published journal article](https://doi.org/10.1080/10556788.2026.2702926). The
earlier [arXiv preprint](https://arxiv.org/abs/2307.02577) remains available,
but the journal article is the version of record.

For a direct software citation, use the
[Zenodo concept DOI](https://doi.org/10.5281/zenodo.7909165). The concept DOI
is the evergreen identifier for `QUBO.jl`, resolves to the latest archived
release, and is the DOI recorded in `CITATION.cff`. When reproducibility
requires an exact release, cite the matching Zenodo version DOI instead; the
latest publicly archived Zenodo record under this concept is `v0.2.0` at
[10.5281/zenodo.7954543](https://doi.org/10.5281/zenodo.7954543).

The BibTeX entries below cite the ecosystem article and the `v0.2.0` software
archive. Replace the `@software` entry's `doi` and `url` with the concept DOI
when an evergreen software citation is preferred:

```bibtex
@article{qubojl:2026,
  author       = {Maciel Xavier, Pedro and Ripper, Pedro and Andrade, Tiago and Dias Garcia, Joaquim and Maculan, Nelson and Bernal Neira, David E.},
  title        = {{QUBO.jl: A Julia Ecosystem for Quadratic Unconstrained Binary Optimization}},
  journal      = {Optimization Methods and Software},
  year         = {2026},
  pages        = {1--24},
  doi          = {10.1080/10556788.2026.2702926},
  url          = {https://doi.org/10.1080/10556788.2026.2702926}
}

@software{qubo:2023,
  author       = {Maciel Xavier, Pedro and Ripper, Pedro and Andrade, Tiago and Dias Garcia, Joaquim and Maculan, Nelson and Bernal Neira, David E.},
  title        = {{QUBO.jl}},
  year         = {2023},
  publisher    = {Zenodo},
  version      = {v0.2.0},
  doi          = {10.5281/zenodo.7954543},
  url          = {https://doi.org/10.5281/zenodo.7954543},
  note         = {Evergreen concept DOI: 10.5281/zenodo.7909165}
}
```

Machine-readable metadata is in
[`CITATION.cff`](https://github.com/JuliaQUBO/QUBO.jl/blob/main/CITATION.cff),
with BibTeX in
[`CITATION.bib`](https://github.com/JuliaQUBO/QUBO.jl/blob/main/CITATION.bib).
<!-- citation-policy:end -->
