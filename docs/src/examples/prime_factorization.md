# Prime Factorization

Factorization is a useful example because it starts from a nonlinear-looking
integer relation and lets `ToQUBO.jl` handle the binary encoding and
reformulation details behind the scenes.

We seek integer factors `p` and `q` such that

```math
\begin{array}{rl}
\text{s.t.} & p q = R \\
            & p, q \in \mathbb{Z}
\end{array}
```

For a small toy instance, exact enumeration is practical and keeps the example
deterministic.

## Encode the Model

```@example prime-factorization
using JuMP
using QUBO
using QUBOTools

function factor(R::Integer)
    a = ceil(Int, √R)
    b = R ÷ 2

    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

    @variable(model, 2 <= p <= a, Int)
    @variable(model, a <= q <= b, Int)
    @constraint(model, p * q == R)

    optimize!(model)

    return model, round(Int, value(p)), round(Int, value(q))
end
```

## Solve a Toy Instance

```@example prime-factorization
model, p, q = factor(15)

(p, q)
```

## Inspect the Reformulated Model Size

As in the other examples, the compiled form is stored on the optimizer backend,
so inspection goes through `JuMP.unsafe_backend(model)`.

```@example prime-factorization
n, l, qmat, α, β = QUBOTools.qubo(JuMP.unsafe_backend(model), :dense)

(n = n, alpha = α, beta = β, quadratic_size = size(qmat))
```

This formulation is mainly educational: exact solving is reasonable only for
small instances, but the example shows how integer structure is funneled into a
QUBO workflow.
