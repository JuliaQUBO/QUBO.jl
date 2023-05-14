using Test
using JuMP
using QUBO

include("spin_model.jl")

function main()
    test_spin_model()

    return nothing
end
