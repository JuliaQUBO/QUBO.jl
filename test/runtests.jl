using Test
using JuMP
using QUBO

include("spin_model.jl")
include("multimake_utils.jl")
include("docs_assets.jl")

function main()
    test_docs_assets()
    test_spin_model()
    test_multimake_utils()

    return nothing
end

main() # Here we go!
