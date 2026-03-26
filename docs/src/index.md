# QUBO.jl Documentation


## Introduction

`QUBO.jl` is an all-in-one package for working with QUBO formulations in [JuMP](https://github.com/jump-dev/JuMP.jl) and interfacing with QUBO solvers. This project aggregates three complementary packages: [`ToQUBO.jl`](https://github.com/JuliaQUBO/ToQUBO.jl), [`QUBODrivers.jl`](https://github.com/JuliaQUBO/QUBODrivers.jl) and [`QUBOTools.jl`](https://github.com/JuliaQUBO/QUBOTools.jl).

## QUBO?

QUBO is an acronym for *Quadratic Unconstrained Binary Optimization*. So every QUBO problem is comprised of:
- a linear or quadratic objective function
- no constraints
- binary variables

We can represent such problem as follows:

```math
\begin{array}{rl}
   \min          & \mathbf{x}' Q\,\mathbf{x} \\
   \textrm{s.t.} & \mathbf{x} \in \mathbb{B}^{n}
\end{array}
```

QUBOs are suited for representing non-convex global optimization problems.
With that said, the significant advances in computing systems and algorithms specialized for sampling QUBOs have contributed to their popularity.

Some of the paradigms that stand out for running QUBOs are quantum gate-based optimization algorithms (QAOA and VQE), quantum annealers and hardware-accelerated platforms (Coherent Ising Machines and Simulated Bifurcation Machines).

## `QUBO.jl` features

`QUBO.Jl` main features are spreaded into its three subpackages:

- `ToQUBO.jl`:  reformulate general JuMP problems into the QUBO format. 

- `QUBODrivers.jl`: define a simple interface to connect with these solvers using a [MOI](https://github.com/jump-dev/MathOptInterface.jl)-compliant API.  

- `QUBOTools.jl`:   a set of methods to work with different formats for QUBO.

More features are available in the documentation.

## Quick Start

### Instalation
```julia
julia> ]add https://github.com/JuliaQUBO/QUBO.jl#main
```
### Example

```julia
using JuMP
using QUBO

model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

@variable(model, x[1:3], Bin)
@constraint(model, 0.3*x[1] + 0.5*x[2] + 1.0*x[3] <= 1.6)
@objective(model, Max, 1.0*x[1] + 2.0*x[2] + 3.0*x[3])

optimize!(model)

for i = 1:result_count(model)
    xi = value.(x, result = i)
    yi = objective_value(model, result = i)

    println("f($xi) = $yi")
end

```

## Constraint Penalties

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

```@raw html
<div align="center">
    <h2>QUBO.jl Packages</h2>

    <a href="https://github.com/JuliaQUBO/ToQUBO.jl">
        <img width="200px" src="./logo.svg" alt="ToQUBO.jl" />
    </a>
    <a href="https://github.com/JuliaQUBO/QUBODrivers.jl">
        <img width="200px" src="./logo.svg" alt="QUBODrivers.jl" />
    </a>
    <a href="https://github.com/JuliaQUBO/QUBOTools.jl">
        <img width="200px" src="./logo.svg" alt="QUBOTools.jl" />
    </a>
</div>
```
