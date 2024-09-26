# QUBOTools.jl

<div align="center">
    <a href="/docs/src/assets/">
        <img src="/docs/src/assets/logo.svg" width=400px alt="QUBOTools.jl" />
    </a>
    <br>
    <a href="https://codecov.io/gh/psrenergy/QUBOTools.jl" > 
        <img src="https://codecov.io/gh/psrenergy/QUBOTools.jl/branch/main/graph/badge.svg?token=W7QJWS5HI4"/> 
    </a>
    <a href="/actions/workflows/ci.yml">
        <img src="https://github.com/psrenergy/QUBOTools.jl/actions/workflows/ci.yml/badge.svg?branch=main" alt="CI" />
    </a>
    <br>
    <i>Tools for Quadratic Unconstrained Binary Optimization models in Julia</i>
</div>

## Introduction
The `QUBOTools.jl` package implements codecs for QUBO (*Quadratic Unconstrained Binary Optimization*) instances.
Its purpose is to provide fast and reliable conversion between common formats used to represent such problems.
This allows for rapid leverage of many emergent computing architectures whose job is to solve this kind of optimization problem.

The term QUBO is widely used when referring to *boolean* problems of the form

$$\begin{array}{rl}
       \min & \vec{x}'\ Q\ \vec{x} \\
\text{s.t.} & \vec{x} \in \mathbb{B}^{n}
\end{array}$$

with symmetric $Q \in \mathbb{R}^{n \times n}$. Nevertheless, this package also fully supports *Ising Models*, given by

$$\begin{array}{rl}
       \min & \vec{s}'\ J\ \vec{s} + \vec{h}'\ \vec{s} \\
\text{s.t.} & \vec{s} \in \left\lbrace-1, 1\right\rbrace^{n}
\end{array}$$

where $J \in \mathbb{R}^{n \times n}$ is triangular and $\vec{h} \in \mathbb{R}^{n}$.

## Getting Started

### Installation
```julia
julia> import Pkg; Pkg.add("QUBOTools")

julia> using QUBOTools
```

### Basic Usage
```julia
julia> model = read("problem.json", BQPJSON)

julia> model = convert(QUBO, model)

julia> write("problem.qubo", model)
```

## Supported Formats
It is possible to read file formats marked with `r` and write in those stamped with a `w`.

### [BQPJSON](/docs/models/BQPJSON.md) `rw`
The [BQPJSON](https://bqpjson.readthedocs.io) format was designed at [LANL-ANSI](https://github.com/lanl-ansi) to represent Binary Quadratic Programs in a platform-independet fashion.
This is accomplished by using `.json` files validated using a well-defined [JSON Schema](/src/models/bqpjson.schema.json).

### [QUBO](/docs/models/QUBOTools.md) `rw`
The QUBO specification appears as the input format in many of D-Wave's applications.
A brief explanation about it can be found in [qbsolv](https://github.com/arcondello/qbsolv#qbsolv-qubo-input-file-format)'s repository README. 

### [Qubist](/docs/models/Qubist.md) `rw`
This is the simplest of all current supported formats.

### [MiniZinc](/docs/models/MiniZinc.md) `w`
[MiniZinc](https://www.minizinc.org) is a constraint modelling language that can be used as input for many solvers.

### [HFS](/docs/models/HFS.md) `w`
HFS is a very low-level mapping of weights to D-Wave's chimera graph.

### Conversion Flowchart
**Bold arrows** indicate that a bijective (modulo rounding erros) conversion is available.
**Regular arrows** indicate that some non-critical information might get lost in the process, such as problem metadata.
**Dashed arrows** tell that even though a format conversion exists, important information such as scale and offset factors will be neglected.

```mermaid
flowchart TD;
    BQPJSON-BOOL["BQPJSON<br><code>Bool</code>"];
    BQPJSON-SPIN["BQPJSON<br><code>Spin</code>"];
    QUBO["QUBO<br><code>Bool</code>"];
    QUBIST["Qubist<br><code>Spin</code>"];
    MINIZINC-BOOL(["MiniZinc<br><code>Bool</code>"]);
    MINIZINC-SPIN(["MiniZinc<br><code>Spin</code>"]);
    HFS(["HFS<br><code>Bool</code>"]);

    BQPJSON-BOOL  <==> BQPJSON-SPIN;
    MINIZINC-BOOL <==> MINIZINC-SPIN;

    BQPJSON-BOOL <--->  MINIZINC-BOOL;
    BQPJSON-BOOL <----> QUBO;
    BQPJSON-BOOL ---->  HFS;

    BQPJSON-SPIN <---> MINIZINC-SPIN;
    BQPJSON-SPIN  ---> QUBIST;
    QUBIST       -..-> BQPJSON-SPIN;
```

## Backend
The `AbstractQUBOModel{D}` abstract type is defined, where `D <: VariableDomain`.
Available variable domains are `BoolDomain` and `SpinDomain`, respectively, $x \in \mathbb{B} = \lbrace 0, 1 \rbrace$ and $s \in \lbrace -1, 1 \rbrace$.
Conversion between domains follows the identity

$$s = 2x - 1$$

**QUBOTools.jl** also exports the ``StandardQUBOModel{S, U, T, D} <: AbstractQUBOModel{D}`` type, designed to work as a powerful standard backend for all other models.
Here, `S <: Any` plays the role of variable indexing type and usually defaults to `Int`.
It is followed by `U <: Integer`, used to store sampled states of type `Vector{U}`.

When `D <: SpinDomain`, it is necessary that `U <: Signed`.
`T <: Real` is the type used to represent all coefficients.
It is also the choice for the energy values corresponding to each solution.
It's commonly set as `Float64`.

This package's mathematical formulation was inspired by **BQPJSON**'s, and is given by

$$\min f(\vec{x}) = \alpha \left[{ \sum_{i < j} q_{i, j}\,x_{i}\,x_{j} +\sum_{i} l_{i}\,x_{i} + \beta }\right]$$

where $\alpha$ is a scaling factor, $\beta$ a constant offset, $l_{i}\,x_{i}$ are the linear terms and $q_{i, j}\,x_{i}\,x_{j}$ the quadratic ones.

We defined our problems to follow a minimization sense by default.
While the scaling factor $\alpha$ is strictly positive in **BQPJSON**, $\alpha < 0$ can be used to indicate _maximixation_ problems using **QUBOTools**.

### [JuMP](https://jump.dev) Integration

One of the main ideas was to make JuMP / MathOptInterface integration easy and, in fact, the implemented backend does a lot of the the data crunching.
When `S` is set to `MOI.VariableIndex` and `T` matches `Optimzer{T}`, we can say that most of the hard work is done.

<div align="center">
    <h2>PSR Quantum Optimization Toolchain</h2>
    <a href="https://github.com/psrenergy/ToQUBO.jl">
        <img width="200px" src="https://raw.githubusercontent.com/psrenergy/ToQUBO.jl/master/docs/src/assets/logo.svg" alt="ToQUBO.jl" />
    </a>
    <a href="https://github.com/psrenergy/Anneal.jl">
        <img width="200px" src="https://raw.githubusercontent.com/psrenergy/Anneal.jl/master/docs/src/assets/logo.svg" alt="Anneal.jl" />
    </a>
    <a href="https://github.com/psrenergy/QUBOTools.jl">
        <img width="200px" src="https://raw.githubusercontent.com/psrenergy/QUBOTools.jl/main/docs/src/assets/logo.svg" alt="QUBOTools.jl" />
    </a>
</div>
