# Design & Architecture

QUBO.jl is the entrypoint package for the JuliaQUBO ecosystem. The package code
is intentionally thin: it imports and re-exports the compiler, sampler, and
tooling packages, then adds small JuMP and QUBOTools integrations for common
workflows.

The architecture below follows the package boundaries in the current source
code. The QUBO.jl paper provides useful background, but the code is the source
of truth for this diagram.

```@raw html
<pre class="mermaid">
flowchart TB
    user["User code&lt;br/&gt;using QUBO&lt;br/&gt;JuMP.Model"]

    subgraph qubo["QUBO.jl entrypoint package"]
        direction LR
        reexports["Imports and re-exports&lt;br/&gt;ToQUBO.jl / QUBODrivers.jl&lt;br/&gt;/ QUBOTools.jl"]
        integrations["Local integrations&lt;br/&gt;Spin, NumberOfReads,&lt;br/&gt;reads(model)&lt;br/&gt;source_model / target_model&lt;br/&gt;QUBOTools.backend(::JuMP.Model)"]
    end

    subgraph toqubo["ToQUBO.jl compiler"]
        direction TB
        source["source_model&lt;br/&gt;PreQUBO / MOI"]
        ir["PBO/PBF compiler state&lt;br/&gt;encodings + penalties&lt;br/&gt;quadratization when needed"]
        target["target_model&lt;br/&gt;QUBOTools_MOI.QUBOModel&lt;br/&gt;binary quadratic MOI model"]
    end

    subgraph drivers["QUBODrivers.jl sampler layer"]
        direction TB
        samplers["MOI sampler optimizers&lt;br/&gt;Exact / Random / Identity / others"]
        resultattrs["MOI result attributes&lt;br/&gt;objective values / primals&lt;br/&gt;/ reads"]
    end

    subgraph tools["QUBOTools.jl model and analysis layer"]
        direction TB
        qmodel["QUBOTools.Model&lt;br/&gt;QUBO / Ising forms"]
        solution["Sample / SampleSet&lt;br/&gt;solution data"]
        files["read/write model and solution files"]
        analysis["metrics and plotting recipes"]
    end

    user --> reexports --> source
    integrations -.-> qmodel

    source --> ir --> target
    target --> samplers --> resultattrs --> solution
    target -.->|"backend"| qmodel
    qmodel --> files
    solution --> files
    qmodel --> analysis
    solution --> analysis
</pre>
```

## Ecosystem Layers

`QUBO.jl` is the entrypoint layer. Its source imports and exports
`ToQUBO.jl`, `QUBODrivers.jl`, and `QUBOTools.jl`, exports the built-in
samplers from QUBODrivers, and exposes QUBOTools' `Spin`, `NumberOfReads`, and
`reads` APIs. It also defines the JuMP-facing convenience functions
`source_model`, `target_model`, and `QUBOTools.backend(::JuMP.Model)`.

`ToQUBO.jl` is the compiler layer. Its optimizer is a virtual MOI optimizer
with a `source_model`, a `target_model`, and compiler state for variables,
constraints, pseudo-Boolean functions, penalties, and the final compiled
objective. During `MOI.optimize!`, ToQUBO compiles the source model and writes a
binary quadratic target model.

`QUBODrivers.jl` is the sampler layer. Sampler optimizers subtype an MOI
optimizer abstraction, accept QUBO or Ising models, store a `QUBOTools.Model`,
and expose results through MOI attributes. Built-in samplers such as
`ExactSampler`, `RandomSampler`, and `IdentitySampler` are re-exported by
QUBO.jl.

`QUBOTools.jl` is the model, solution, file I/O, and analysis layer. It defines
the model and solution abstractions used by the compiler and samplers, handles
QUBO and Ising forms, reads and writes model and solution files, and backs
analysis utilities such as density metrics and plotting recipes.

## Compilation Through PBO

PBO is part of the ToQUBO.jl compiler internals, not a separate implementation
inside the QUBO.jl entrypoint package. The ToQUBO source imports
`PseudoBooleanOptimization` as `PBO` and stores pseudo-Boolean function state in
the virtual model while compiling the source MOI model into a binary quadratic
target model.

After the original JuMP/MOI model is available, ToQUBO.jl applies variable
encoding and constraint penalization so the problem can be represented over
binary variables.

The intermediate mathematical representation is a pseudo-Boolean function
(Boros and Hammer, 2002): a real polynomial over binary variables,

```math
f(x) = \sum_{\omega \in \mathcal{P}([n])} c_{\omega}
       \prod_{j \in \omega} x_j,
```

where ``x \in \{0, 1\}^n``. This representation is natural for ToQUBO's
compiler because optimizing a degree-two pseudo-Boolean function over binary
variables is equivalent to optimizing a QUBO, up to the constant term.

Some constraint mappings produce higher-degree pseudo-Boolean terms. Those terms
must be quadratized before they can be written to the binary quadratic target
model. In the current ToQUBO code, compiler routines set a `Quadratize` flag
when they generate high-order pseudo-Boolean terms, then the build step calls
`PBO.quadratize!` before writing the target MOI objective. The paper cites
Dattani for a survey of quadratization methods and Boros-Gruber for
positive-term quadratization.

In summary, the compilation path is:

```text
JuMP/MOI model
  -> variable encoding and constraint penalization
  -> ToQUBO pseudo-Boolean compiler state
  -> quadratization when high-order terms are generated
  -> binary quadratic MOI target model
```
