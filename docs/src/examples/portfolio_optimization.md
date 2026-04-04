# Portfolio Optimization

Portfolio optimization is a natural QUBO example because expected return is a
linear term while risk appears as a quadratic term.

We use a tiny three-asset instance and solve it with `ExactSampler` after
choosing a coarse encoding tolerance. That keeps the compiled QUBO small enough
for an exact docs example while still showing the full workflow.

## Market Data

```@example portfolio-optimization
assets = [:IBM, :WMT, :SEHI]

prices = [
     93.043  51.826  1.063
     84.585  52.823  0.938
    111.453  56.477  1.000
     99.525  49.805  0.938
     95.819  50.287  1.438
    114.708  51.521  1.700
    111.515  51.531  2.540
    113.211  48.664  2.390
    104.942  55.744  3.120
     99.827  47.916  2.980
     91.607  49.438  1.900
    107.937  51.336  1.750
    115.590  55.081  1.800
]
```

## Build and Solve the Model

```@example portfolio-optimization
using JuMP
using QUBO
using QUBOTools
using Statistics

function solve_portfolio(prices; λ::Float64 = 10.0, atol::Float64 = 0.25)
    n = size(prices, 2)

    returns = [
        prices[t + 1, i] / prices[t, i] - 1
        for t in 1:(size(prices, 1) - 1), i in 1:n
    ]

    μ = vec(mean(returns; dims = 1))
    Σ = cov(returns)

    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

    @variable(model, 0 <= x[1:n] <= 1)
    @objective(
        model,
        Max,
        sum(μ[i] * x[i] for i in 1:n) -
        λ * sum(Σ[i, j] * x[i] * x[j] for i in 1:n, j in 1:n),
    )
    @constraint(model, sum(x) == 1)

    set_attribute(model, ToQUBO.Attributes.DefaultVariableEncodingATol(), atol)

    optimize!(model)

    return model, value.(x)
end
```

```@example portfolio-optimization
model, allocation = solve_portfolio(prices)

[(; asset = assets[i], weight = round(allocation[i]; digits = 2)) for i in eachindex(assets)]
```

## Check the Compiled QUBO Size

The compiled QUBO is available on the optimizer backend, which we inspect
through `JuMP.unsafe_backend(model)`.

```@example portfolio-optimization
n, l, qmat, α, β = QUBOTools.qubo(JuMP.unsafe_backend(model), :dense)

(n = n, alpha = α, beta = β, sum_allocation = sum(allocation))
```

For real portfolios you would usually use a richer dataset, a tighter encoding,
and a scalable backend instead of exact enumeration.
