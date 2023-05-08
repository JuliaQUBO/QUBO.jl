# QUBO.jl
<div align="left">
   <a href="https://www.youtube.com/watch?v=OTmzlTbqdNo">
        <img src="https://img.shields.io/badge/JuliaCon-2022-9558b2" alt="JuliaCon 2022">
    </a>
    <a href="https://psrenergy.github.io/ToQUBO.jl/dev">
        <img src="https://img.shields.io/badge/docs-dev-blue.svg" alt="Docs">
    </a>
   <a href="https://zenodo.org/badge/latestdoi/614041491">
      <img src="https://zenodo.org/badge/614041491.svg" alt="DOI">
   </a>
</div>


## Introduction

`QUBO.jl` is an all-in-one package for working with QUBO formulations in [JuMP](https://github.com/jump-dev/JuMP.jl) and interfacing with QUBO solvers. This project aggregates three complementary packages: [`ToQUBO.jl`](https://github.com/psrenergy/ToQUBO.jl), [`QUBODrivers.jl`](https://github.com/psrenergy/QUBODrivers.jl) and [`QUBOTools.jl`](https://github.com/psrenergy/QUBOTools.jl).

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
julia> ]add https://github.com/psrenergy/QUBO.jl#master
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

<div align="center">
    <h2>QUBO.jl Packages</h2>
    <a href="https://github.com/psrenergy/ToQUBO.jl">
        <img width="200px" src="https://raw.githubusercontent.com/psrenergy/ToQUBO.jl/master/docs/src/assets/logo.svg" alt="ToQUBO.jl" />
    </a>
    <a href="https://github.com/psrenergy/QUBODrivers.jl">
        <img width="200px" src="https://raw.githubusercontent.com/psrenergy/QUBODrivers.jl/master/docs/src/assets/logo.svg" alt="QUBODrivers.jl" />
    </a>
    <a href="https://github.com/psrenergy/QUBOTools.jl">
        <img width="200px" src="https://raw.githubusercontent.com/psrenergy/QUBOTools.jl/main/docs/src/assets/logo.svg" alt="QUBOTools.jl" />
    </a>
</div>
