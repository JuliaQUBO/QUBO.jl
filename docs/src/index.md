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
        <p>Expose samplers and annealers through a consistent `MOI`-compatible
        interface that can be used directly from JuMP and `QUBO.jl`.</p>
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
</div>
```
