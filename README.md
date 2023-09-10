# QUBO.jl

<div align="center">
<a href="/docs/src/assets/">
    <img src="/docs/src/assets/logo.svg" width=400px alt="QUBO.jl" />
</a>

[![Code Coverage](https://codecov.io/gh/psrenergy/QUBO.jl/branch/master/graph/badge.svg?token=ECM5OQ9T67")](https://codecov.io/gh/psrenergy/QUBO.jl)
[![CI](https://github.com/psrenergy/QUBO.jl/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/psrenergy/QUBO.jl/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://psrenergy.github.io/QUBO.jl/QUBO.jl/dev)
[![Zenodo/DOI](https://zenodo.org/badge/614041491.svg)](https://zenodo.org/badge/latestdoi/614041491)
[![JuliaCon 2022](https://img.shields.io/badge/JuliaCon-2022-9558b2)](https://www.youtube.com/watch?v=OTmzlTbqdNo)
[![arXiv](https://img.shields.io/badge/arXiv-2307.02577-b31b1b.svg)](https://arxiv.org/abs/2307.02577)
</div>

## Introduction

[QUBO.jl](https://github.com/psrenergy/QUBO.jl) is an all-in-one package for working with QUBO formulations in [JuMP](https://github.com/jump-dev/JuMP.jl) and interfacing with QUBO solvers. This project aggregates three complementary packages: [ToQUBO.jl](https://github.com/psrenergy/ToQUBO.jl), [QUBODrivers.jl](https://github.com/psrenergy/QUBODrivers.jl) and [QUBOTools.jl](https://github.com/psrenergy/QUBOTools.jl).

## QUBO?

QUBO is an acronym for *Quadratic Unconstrained Binary Optimization*. So every QUBO problem is comprised of:

- a linear or quadratic objective function
- no constraints
- binary variables

We can represent such problem as follows:

```math
\begin{array}{rl}
   \min | \max & \alpha \left[\mathbf{\ell}' \mathbf{x} \mathbf{x}' Q\,\mathbf{x} + \beta \right] \\
   \textrm{s.t.} & \mathbf{x} \in \mathbb{B}^{n}
\end{array}
```

QUBOs are suited for representing non-convex global optimization problems.
With that said, the significant advances in computing systems and algorithms specialized for sampling QUBOs have contributed to their popularity.

Some of the paradigms that stand out for running QUBOs are quantum gate-based optimization algorithms (QAOA and VQE), quantum annealers and hardware-accelerated platforms (Coherent Ising Machines and Simulated Bifurcation Machines).

## Quick Start 🚀

### Instalation

```julia
import Pkg

Pkg.add("QUBO")
```

### Example

Given the following binary Knapsack Problem

```math
\begin{array}{rl}
\max          & x_{1} + 2 x_{2} + 3 x_{3} \\
\textrm{s.t.} & 0.3 x_{1} + 0.5 x_{2} + x_{3} \leq 1.6 \\
              & \mathbf{x} \in \mathbb{B}^{3}
\end{array}
```

one could write a simple [JuMP](https://jump.dev) model and have its constraint automatically encoded by [ToQUBO.jl](https://github.com/psrenergy/ToQUBO.jl).

<details>
    <summary>Show Code</summary>

```julia
using JuMP
using QUBO

model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

@variable(model, x[1:3], Bin)
@objective(model, Max, x[1] + 2 * x[2] + 3 * x[3])
@constraint(model, 0.3 * x[1] + 0.5 * x[2] + x[3] <= 1.6)

optimize!(model)

for i = 1:result_count(model)
    xi = value.(x, result = i)
    yi = objective_value(model, result = i)

    println("x: ", xi, "; cost = ", yi)
end
```

</details>

## Overview

<div align="left">
<a href="https://github.com/psrenergy/ToQUBO.jl">
<img width="200px" src="https://raw.githubusercontent.com/psrenergy/ToQUBO.jl/master/docs/src/assets/logo.svg" alt="ToQUBO.jl" align="right" />
</a>
<div align="left">

### ToQUBO.jl

[ToQUBO.jl](https://github.com/psrenergy/ToQUBO.jl) is a Julia package to reformulate general optimization problems into QUBO (Quadratic Unconstrained Binary Optimization) instances.
This tool aims to convert a broad range of JuMP problems for straightforward application in many physics and physics-inspired solution methods whose normal optimization form is equivalent to the QUBO.
These methods include quantum annealing, quantum gate-circuit optimization algorithms (Quantum Optimization Alternating Ansatz, Variational Quantum Eigensolver), other hardware-accelerated platforms, such as Coherent Ising Machines and Simulated Bifurcation Machines, and more traditional methods such as simulated annealing.
During execution, [ToQUBO.jl](https://github.com/psrenergy/ToQUBO.jl) encodes both discrete and continuous variables, maps constraints, and computes their penalties, performing a few model optimization steps along the process.
[ToQUBO.jl](https://github.com/psrenergy/ToQUBO.jl) was written as a MathOptInterface (MOI) layer that automatically maps between input and output models, thus providing a smooth JuMP modeling experience.

<div>
</div>

<div align="right">
<a href="https://github.com/psrenergy/QUBODrivers.jl">
    <img width="200px" src="https://raw.githubusercontent.com/psrenergy/QUBODrivers.jl/master/docs/src/assets/logo.svg" alt="QUBODrivers.jl" align="left" />
</a>
<div align="left">

### QUBODrivers.jl

This package aims to provide a common [MOI](https://github.com/jump-dev/MathOptInterface.jl)-compliant API for QUBO Sampling and Annealing machines.
It also contains testing tools, including utility samplers for performance comparison and sanity checks.
*Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec sit amet urna risus. Proin molestie urna ex, non ullamcorper est varius id. Sed tempus purus quis tempus placerat. Praesent sit amet venenatis libero. Aliquam feugiat, ex sed feugiat imperdiet, tortor leo pellentesque nulla, in pellentesque quam augue non velit. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Nunc porta dolor lorem, et placerat sem venenatis ac. Vivamus suscipit finibus blandit. Nullam non semper massa.*

<div>
</div>

<div align="left">
<a href="https://github.com/psrenergy/QUBOTools.jl">
    <img width="200px" src="https://raw.githubusercontent.com/psrenergy/QUBOTools.jl/main/docs/src/assets/logo.svg" alt="QUBOTools.jl" align="right" />
</a>
</a>
<div align="left">

### QUBOTools.jl

The QUBOTools.jl package implements codecs for QUBO (Quadratic Unconstrained Binary Optimization) instances. Its purpose is to provide fast and reliable conversion between common formats used to represent such problems. This allows for rapid leverage of many emergent computing architectures whose job is to solve this kind of optimization problem.
*Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec sit amet urna risus. Proin molestie urna ex, non ullamcorper est varius id. Sed tempus purus quis tempus placerat. Praesent sit amet venenatis libero. Aliquam feugiat, ex sed feugiat imperdiet, tortor leo pellentesque nulla, in pellentesque quam augue non velit. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Nunc porta dolor lorem, et placerat sem venenatis ac. Vivamus suscipit finibus blandit. Nullam non semper massa.*

<div>
</div>

## Citing [QUBO.jl](https://github.com/psrenergy/QUBO.jl)

If you find [QUBO.jl](https://github.com/psrenergy/QUBO.jl) and its packages useful in your work, we kindly request that you cite the following paper (preprint):

```tex
@misc{qubojl:2023,
  title         = {QUBO.jl: A Julia Ecosystem for Quadratic Unconstrained Binary Optimization}, 
  author        = {Pedro {Maciel Xavier} and Pedro Ripper and Tiago Andrade and Joaquim {Dias Garcia} and Nelson Maculan and David E. {Bernal Neira}},
  year          = {2023},
  doi           = {10.48550/arXiv.2307.02577},
  eprint        = {2307.02577},
  archivePrefix = {arXiv},
  primaryClass  = {math.OC},
}
```

---

<div align="center">
    <source media="(prefers-color-scheme: dark)" srcset="/docs/src/assets/collaboration-dark.svg">
      <img alt="PSR; UFRJ; Purdue; USRA" src="/docs/src/assets/collaboration-light.svg">
    </picture>
</div>
