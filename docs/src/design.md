# Design & Architecture

QUBO.jl is the entrypoint package for the JuliaQUBO ecosystem. It bundles the
compiler, solver interface, and model tooling packages used to move from
ordinary JuMP models to QUBO instances, solver calls, and post-solve analysis.

The architecture below follows Figure 1 of the QUBO.jl paper. Model I/O is the
optimization-model path, while data I/O covers file conversion, model data, and
solution data handled by QUBOTools.jl.

```@raw html
<pre class="mermaid">
flowchart LR
    subgraph legend["Legend"]
        direction LR
        l1[" "] -->|"Model I/O"| l2[" "]
        l3[" "] -.->|"Data I/O"| l4[" "]
        style l1 height:0px
        style l2 height:0px
        style l3 height:0px
        style l4 height:0px
    end

    jump["JuMP MINLP model&lt;br/&gt;opt f(y,z)&lt;br/&gt;s.t. g(y,z) &lt;= 0&lt;br/&gt;h(y,z) = 0"]
    file["File"]

    subgraph qubo["QUBO.jl"]
        toqubo["ToQUBO.jl"]
        moi["MOI QUBO model&lt;br/&gt;opt x' Q x&lt;br/&gt;s.t. x in B^n"]
        drivers["QUBODrivers.jl"]
        tools["QUBOTools.jl"]
    end

    miqp["MIQP solver"]
    qsolver["QUBO solver"]
    analysis["Analysis"]
    modeldata["Model data"]
    solutiondata["Solution data"]

    jump --> toqubo --> moi
    moi --> miqp
    moi --> drivers --> qsolver

    file <-.->|"Data I/O"| tools
    moi <-.->|"Model I/O"| tools
    drivers -.->|"Solution data"| tools
    tools --> analysis
    tools -.-> modeldata
    tools -.-> solutiondata
</pre>
```

## Ecosystem Layers

`ToQUBO.jl` is the reformulation layer. It receives a JuMP model through
MathOptInterface (MOI), applies the compilation steps needed by the QUBO
formalism, and caches the resulting QUBO as another MOI model. That output can
be forwarded to a QUBO sampler or to a classical MIQP solver that supports
binary variables and nonconvex quadratic objectives.

`QUBODrivers.jl` provides the solver-facing interface. Solver wrappers subtype
MOI optimizer abstractions, validate QUBO-compatible models, expose solver
attributes, submit models to sampling or annealing backends, and return solution
sets for analysis.

`QUBOTools.jl` provides the model and result tooling layer. It handles QUBO and
Ising file conversion, defines reusable model and solution abstractions, and
backs analysis utilities such as conditioning queries, density metrics, and
plotting recipes.

## Compilation Through PBO

The QUBO.jl paper describes compilation as a lowering process from a general
optimization model to a binary, unconstrained polynomial of degree at most two.
After the original JuMP/MOI model is available, ToQUBO.jl applies variable
encoding and constraint penalization so the problem can be represented over
binary variables.

The intermediate mathematical representation is a pseudo-Boolean function
(Boros and Hammer, 2002): a real polynomial over binary variables,

```math
f(x) = \sum_{\omega \in \mathcal{P}([n])} c_{\omega}
       \prod_{j \in \omega} x_j,
```

where ``x \in \{0, 1\}^n``. This representation is natural for QUBO
compilation because optimizing a degree-two pseudo-Boolean function over binary
variables is equivalent to optimizing a QUBO, up to the constant term.

Some constraint mappings produce higher-degree pseudo-Boolean terms. Those terms
must be quadratized before they can be sent to QUBO-compatible solvers.
Quadratization introduces auxiliary binary variables so that the reduced
degree-two problem has the same minimum value as the higher-degree expression.
The paper cites Dattani for a survey of quadratization methods and Boros-Gruber
for positive-term quadratization. ToQUBO.jl exposes this step through Julia
multiple dispatch so new degree-reduction methods can be added without changing
the rest of the modeling flow.

In summary, the compilation path is:

```text
JuMP/MOI model
  -> variable encoding and constraint penalization
  -> pseudo-Boolean representation
  -> quadratization when degree > 2
  -> MOI QUBO model
```
