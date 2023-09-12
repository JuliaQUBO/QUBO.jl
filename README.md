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

*A Julia ecosystem for Quadratic Unconstrained Binary Optimization*

</div>

[QUBO.jl](https://github.com/psrenergy/QUBO.jl) is an all-in-one package for working with QUBO models in [JuMP](https://github.com/jump-dev/JuMP.jl) and interfacing with their solvers.
This project aggregates and extends functionality from its complementary packages [ToQUBO.jl](https://github.com/psrenergy/ToQUBO.jl), [QUBODrivers.jl](https://github.com/psrenergy/QUBODrivers.jl) and [QUBOTools.jl](https://github.com/psrenergy/QUBOTools.jl).

## QUBO? 🟦

QUBO is an acronym for **Quadratic Unconstrained Binary Optimization**, a notorious family of Combinatorial Optimization problems.
Recently, significant advances in computing systems and algorithms specialized for sampling QUBO solutions have contributed to its increasing popularity.

These novel tools include Quantum Annealing, Quantum Gate-Circuit Optimization Algorithms (Quantum Optimization Alternating Ansatz, Variational Quantum Eigensolver), other hardware-accelerated platforms, such as Coherent Ising Machines and Simulated Bifurcation Machines, not to mention traditional methods such as Simulated Annealing and Parallel Tempering.

### Mathematical Model

Conceptually speaking, it is an optimization model with a **quadratic objective function** on **binary variables** and **no constraints**.
Despite being very simple, these models are capable of representing other nonconvex global optimization problems.

```math
\begin{array}{rl}
  \min & \alpha \left[\mathbf{x}' \mathbf{Q}\,\mathbf{x} + \mathbf{\ell}' \mathbf{x} + \beta \right] \\
  \textrm{s.t.} & \mathbf{x} \in \lbrace{0, 1}\rbrace^{n}
\end{array}
```

<details>
    <summary><strong>Show Description</strong></summary>

Analizing the model attentively, let $\mathbf{x}$ be a **vector of boolean (zero-one) variables**.
Take also the **vector of linear terms** $\mathbf{\ell} \in \mathbb{R}^{n}$ and the **strictly upper triangular matrix of quadratic terms** $\mathbf{Q} \in \mathbb{R}^{n \times n}$.
Last but not least, consider $\alpha, \beta \in \mathbb{R}$ as the **scaling** and **offset** parameters, respectively.

Note that in this kind of problem, $\min$ and $\max$ are interchangeable under sign inversion.
Also, spin variables $\mathbf{s} \in \lbrace{\pm 1}\rbrace^{n}$ may be employed instead, assuming that $s = 2x - 1$ by convention.

</details>

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
    <summary><strong>Show Code</strong></summary>

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

## Overview 🗺️

<div align="left">
<a href="https://github.com/psrenergy/ToQUBO.jl">
<img width="200px" src="https://raw.githubusercontent.com/psrenergy/ToQUBO.jl/master/docs/src/assets/logo.svg" alt="ToQUBO.jl" align="right" />
</a>

<div align="left">

### ToQUBO.jl

[ToQUBO.jl](https://github.com/psrenergy/ToQUBO.jl) is a Julia package to reformulate general optimization problems into QUBO (Quadratic Unconstrained Binary Optimization) instances.
This tool aims to convert a broad range of JuMP problems for straightforward application in many physics and physics-inspired solution methods whose normal optimization form is equivalent to the QUBO.
Not only it is has the [**widest constraint coverage**](https://github.com/psrenergy/ToQUBO.jl#list-of-interpretable-constraints) but also is the [**most performant**](https://github.com/psrenergy/ToQUBO-benchmark) QUBO reformulation tool available.

During execution, [ToQUBO.jl](https://github.com/psrenergy/ToQUBO.jl) encodes both discrete and continuous variables, maps constraints, and computes their penalties, performing a few model optimization steps along the process.
[ToQUBO.jl](https://github.com/psrenergy/ToQUBO.jl) was written as a [MathOptInterface](https://github.com/jump-dev/MathOptInterface.jl) (MOI) layer that automatically maps between input and output models, thus providing a smooth JuMP modeling experience.

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

It was designed to allow algorithm developers and hardware manufacturers to easily connect their products to the [JuMP](https://jump.dev) ecosystem.
Its simple interface paves the path for the rapid integration of heterogeneous QUBO solvers, including cloud-based Quantum Computing services ([DWave.jl](https://github.com/psrenergy/DWave.jl), [QiskitOpt.jl](https://github.com/psrenergy/QiskitOpt.jl)); Quantum Simulation software ([QuantumAnnealingInterface.jl](https://github.com/psrenergy/QuantumAnnealingInterface.jl); [CIMOptimizer.jl](https://github.com/pedromxavier/CIMOptimizer.jl)) and Heuristic solvers ([MQLib.jl](https://github.com/psrenergy/MQLib.jl), [DWaveNeal.jl](https://github.com/psrenergy/DWaveNeal.jl)).

<div>
</div>

<div align="left">
<a href="https://github.com/psrenergy/QUBOTools.jl">
    <img width="200px" src="https://raw.githubusercontent.com/psrenergy/QUBOTools.jl/main/docs/src/assets/logo.svg" alt="QUBOTools.jl" align="right" />
</a>
</a>

<div align="left">

### QUBOTools.jl

The [QUBOTools.jl](https://github.com/psrenergy/QUBOTools.jl) package implements a broad set of utilities for working with QUBO instances.
It defines the abstract interfaces for representing both QUBO models and their solutions.
Besides that, its library contains reference implementations for the proposed interface, making it ready to power other applications.

One of its main purposes is to provide fast and reliable conversion mechanism between common file formats for storing such problems.
With [QUBOTools.jl](https://github.com/psrenergy/QUBOTools.jl) it is possible to read models from various benchmarking databases and also write models in specifications that most devices will directly handle.

<div>
</div>

## Citing [QUBO.jl](https://github.com/psrenergy/QUBO.jl) 📑

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

This project is part of a collaboration involving [PSR Energy Consulting & Analytics](https://psr-inc.com), the [Federal University of Rio de Janeiro](https://ufrj.br) (UFRJ), [Purdue University](https://purdue.edu) and the [Universities Space Research Association](https://usra.edu) (USRA).

<div align="center">
    <picture>
        <source media="(prefers-color-scheme: dark)" srcset="/docs/src/assets/collaboration-dark.svg">
        <img alt="PSR; UFRJ; Purdue; USRA" src="/docs/src/assets/collaboration-light.svg">
    </picture>
</div>
