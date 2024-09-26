using Test
using Printf
using QUBOTools

# ~*~ Include test functions ~*~
include("library/library.jl")
include("models/models.jl")
include("bridges/bridges.jl")
include("interface/interface.jl")

function test_main(path::String, n::Integer)
    @testset "~*~*~ QUBOTools.jl ~*~*~" verbose = true begin
        test_library()
        test_interface()
        test_models(path, n)
        test_bridges(path, n)
    end
end

test_main(@__DIR__, 2) # Here we go!