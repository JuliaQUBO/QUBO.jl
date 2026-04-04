# Knapsack

The [Knapsack Problem](https://en.wikipedia.org/wiki/Knapsack_problem) is a
standard benchmark for QUBO workflows because it starts from an ordinary
constrained binary model and ends with a compact compiled QUBO.

We will solve the small instance

```math
\begin{array}{r l}
    \max        & x_{1} + 2 x_{2} + 3 x_{3} \\
    \text{s.t.} & 0.3 x_{1} + 0.5 x_{2} + x_{3} \le 1.6 \\
    ~           & \mathbf{x} \in \mathbb{B}^{3}
\end{array}
```

## Build and Solve the JuMP Model

```@example knapsack
using JuMP
using QUBO
using QUBOTools

model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

@variable(model, x[1:3], Bin)
@objective(model, Max, x[1] + 2 * x[2] + 3 * x[3])
@constraint(model, 0.3 * x[1] + 0.5 * x[2] + x[3] <= 1.6)

optimize!(model)
```

The exact sampler is enough for this toy model, so we can inspect the optimal
selection directly.

```@example knapsack
value.(x), objective_value(model)
```

## Inspect the Compiled QUBO

Because `QUBO.jl` exposes the compiler and tooling stack together, we can also
inspect the compiled QUBO representation after solving. The compiled form lives
on the optimizer backend, so we retrieve it through `JuMP.unsafe_backend(model)`.

```@example knapsack
n, l, q, α, β = QUBOTools.qubo(JuMP.unsafe_backend(model), :dense)

(n = n, alpha = α, beta = β, nonzero_quadratic_terms = count(!iszero, q))
```

For larger instances you would typically switch to a heuristic or hardware
backend, but the modeling surface remains the same.
