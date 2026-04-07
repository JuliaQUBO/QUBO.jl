# [Analysis & Visualization](@id analysis-visualization)

After solving a QUBO model you can inspect the compiled problem and its
solutions with the plotting recipes provided by
[QUBOTools.jl](https://github.com/JuliaQUBO/QUBOTools.jl).
These recipes work with [Plots.jl](https://github.com/JuliaPlots/Plots.jl) and
any backend it supports (GR, Plotly, etc.).

QUBO.jl defines `QUBOTools.backend` for `JuMP.Model`, so every QUBOTools
visualization accepts a JuMP model directly — no need to unwrap the optimizer
manually.

## Setup

Add Plots.jl to your environment if you haven't already:

```julia
import Pkg; Pkg.add("Plots")
```

## Model Density

`QUBOTools.ModelDensityPlot` shows the sparsity pattern and coefficient
magnitudes of the QUBO matrix.

```julia
using JuMP, QUBO, Plots

model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

@variable(model, x[1:3], Bin)
@objective(model, Min, x[1]*x[2] + x[2]*x[3] - x[1] - x[3])

optimize!(model)

plot(QUBOTools.ModelDensityPlot(model))
```

## System Layout

`QUBOTools.SystemLayoutPlot` renders the interaction graph of the QUBO problem,
where nodes are variables and edges represent non-zero quadratic couplings.

```julia
plot(QUBOTools.SystemLayoutPlot(model))
```

## Energy Frequency

`QUBOTools.EnergyFrequencyPlot` displays a bar chart of objective values
across the returned samples, giving a quick view of solution quality
distribution.

```julia
plot(QUBOTools.EnergyFrequencyPlot(model))
```

## Energy Distribution

`QUBOTools.EnergyDistributionPlot` shows the cumulative or density view of the
energy landscape sampled by the solver.

```julia
plot(QUBOTools.EnergyDistributionPlot(model))
```

## Working with the Target Model Directly

If you need finer control, you can access the underlying `QUBOTools.Model`
directly:

```julia
backend = QUBOTools.backend(model)

# Query model properties
QUBOTools.dimension(backend)
QUBOTools.density(backend)
QUBOTools.linear_density(backend)
QUBOTools.quadratic_density(backend)
```
