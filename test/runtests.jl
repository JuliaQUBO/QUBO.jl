using Test
using JuMP
using QUBO

include("spin_model.jl")
include("multimake_utils.jl")

function main()
    test_spin_model()
    test_multimake_utils()

    return nothing
end

main() # Here we go!
